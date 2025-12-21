-- ======================================================================
-- SpellExport v1.5.1
-- Project Lazarus Spell Export Tool
--
-- v1.5.1
--  • Added spell cache for instant lookup (no lag)
--  • Cache builds on first search or via manual button
-- v1.5.0
--  • Added spell lookup feature with active fuzzy search
--  • Display class levels for looked-up spells
-- v1.4.0
--  • Removed ability type labels feature (non-functional)
-- v1.3.0
--  • Added tooltips for all buttons and checkboxes
-- v1.2.0
--  • Removed Type column from CSV export
-- v1.1.0
--  • Ability type labeling (Spell / Discipline / Ability / Hybrid)
--  • Type column always included in CSV
--  • Hide spellbook spells filter
--  • Filters apply to GUI and CSV consistently
--  • Clear, locked checkbox labels
-- ======================================================================

-----------------------------
-- Script Identity
-----------------------------
local SCRIPT_NAME    = "SpellExport"
local SCRIPT_VERSION = "v1.5.1"

-----------------------------
-- Libraries
-----------------------------
local mq    = require('mq')
local ImGui = require('ImGui')

-----------------------------
-- Constants
-----------------------------
local MAX_SPELL_ID  = 30000
local SCAN_BATCH    = 150
local DELAY_MS      = 1
local SETTINGS_FILE = "SpellExport_settings.lua"
local MAX_LOOKUP_RESULTS = 20
local CACHE_BATCH_SIZE = 500

-----------------------------
-- Class Names
-----------------------------
local CLASS_NAMES = {
    [1]  = "Warrior",
    [2]  = "Cleric",
    [3]  = "Paladin",
    [4]  = "Ranger",
    [5]  = "Shadow Knight",
    [6]  = "Druid",
    [7]  = "Monk",
    [8]  = "Bard",
    [9]  = "Rogue",
    [10] = "Shaman",
    [11] = "Necromancer",
    [12] = "Wizard",
    [13] = "Magician",
    [14] = "Enchanter",
    [15] = "Beastlord",
    [16] = "Berserker"
}

-----------------------------
-- State
-----------------------------
local scanning, scan_complete, terminate = false, false, false
local currentScanID, scanStartTime = 1, 0
local spellsProcessed, missingCount = 0, 0
local missingSpells = {}

-- Spell Lookup State
local lookupQuery = ""
local lookupSuggestions = {}
local selectedSpellID = 0
local selectedSpellData = nil
local lastLookupChoice = nil
local lastProcessedQuery = ""

-- Spell Cache
local spellCache = {}
local cacheBuilt = false
local cacheBuilding = false
local cacheProgress = 0

-----------------------------
-- Helpers
-----------------------------
local function safe(fn)
    local ok, r = pcall(fn)
    if ok then return r end
end

local function tonum(v) return tonumber(v) or 0 end

local function trim(s)
    if not s then return '' end
    return s:gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizePath(p)
    if not p then return nil end
    p = tostring(p):gsub("\\","/"):gsub("%s+$","")
    if not p:match("/$") then p = p .. "/" end
    return p
end

local function mqLogs()
    return tostring(mq.TLO.MacroQuest.Path() or ".") .. "/Logs/"
end

local function scriptDir()
    return tostring(mq.TLO.MacroQuest.Path() or ".") .. "/"
end

local function getCharName()
    return safe(function() return mq.TLO.Me.CleanName() end)
        or safe(function() return mq.TLO.Me.Name() end)
        or "Unknown"
end

local function tooltip(text)
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip(text)
    end
end

-----------------------------
-- Dynamic Character State
-----------------------------
local classID, charLevel = 0, 1

local function refreshCharacterState()
    classID   = tonum(safe(function() return mq.TLO.Me.Class.ID() end))
    charLevel = tonum(safe(function() return mq.TLO.Me.Level() end))
end

-----------------------------
-- UI / Persisted State
-----------------------------
local filterMinLevel = 0
local filterMaxLevel = 1

local showInGUI      = true
local exportCSV      = true
local hideSpellbook  = false

local outputDir = mqLogs()

-----------------------------
-- Settings
-----------------------------
local function settingsPath()
    return normalizePath(outputDir) .. SETTINGS_FILE
end

local function loadSettings()
    local f = loadfile(settingsPath())
    if not f then return end
    local ok, d = pcall(f)
    if ok and type(d) == "table" then
        filterMinLevel = tonum(d.minLevel)
        filterMaxLevel = tonum(d.maxLevel)
        showInGUI      = d.showInGUI ~= false
        exportCSV      = d.exportCSV ~= false
        hideSpellbook  = d.hideSpellbook == true
        outputDir      = d.outputDir or outputDir
    end
end

local function saveSettings()
    local f = io.open(settingsPath(), "w")
    if not f then return end
    f:write("return {\n")
    f:write(string.format(" minLevel=%d,\n", filterMinLevel))
    f:write(string.format(" maxLevel=%d,\n", filterMaxLevel))
    f:write(string.format(" showInGUI=%s,\n", tostring(showInGUI)))
    f:write(string.format(" exportCSV=%s,\n", tostring(exportCSV)))
    f:write(string.format(" hideSpellbook=%s,\n", tostring(hideSpellbook)))
    f:write(string.format(" outputDir=%q,\n", normalizePath(outputDir)))
    f:write("}\n")
    f:close()
end

-----------------------------
-- Ability Type Classification
-----------------------------
local function classify(spell)
    local name = spell.Name()
    local id   = spell.ID()

    local isBook   = safe(function() return mq.TLO.Me.Book(name)() end)
    local isSpell  = safe(function() return mq.TLO.Me.Spell(id)() end)
    local isAbil   = safe(function() return mq.TLO.Me.Ability(name)() end)
    local isCombat = safe(function() return mq.TLO.Me.CombatAbility(name)() end)

    local hits = 0
    for _, v in pairs({isBook, isSpell, isAbil, isCombat}) do
        if v then hits = hits + 1 end
    end

    if hits > 1 then return "Hybrid" end
    if isCombat then return "Discipline" end
    if isAbil then return "Ability" end
    if isBook or isSpell then return "Spell" end
    return "Unknown"
end

local function isKnown(spell)
    return
        safe(function() return mq.TLO.Me.Book(spell.Name())() end) or
        safe(function() return mq.TLO.Me.Book(spell.ID())() end) or
        safe(function() return mq.TLO.Me.Spell(spell.ID())() end) or
        safe(function() return mq.TLO.Me.Ability(spell.Name())() end) or
        safe(function() return mq.TLO.Me.CombatAbility(spell.Name())() end) or
        false
end

-----------------------------
-- Spell Cache Building
-----------------------------
local currentCacheID = 1

local function startCacheBuilding()
    if cacheBuilding or cacheBuilt then return end
    
    spellCache = {}
    cacheBuilding = true
    cacheBuilt = false
    currentCacheID = 1
    cacheProgress = 0
    
    print(string.format("[%s] Building spell cache...", SCRIPT_NAME))
end

local function buildCacheBatch()
    if not cacheBuilding then return end
    
    local endID = math.min(currentCacheID + CACHE_BATCH_SIZE - 1, MAX_SPELL_ID)
    
    for id = currentCacheID, endID do
        local sp = safe(function() return mq.TLO.Spell(id) end)
        if sp and sp.ID() and sp.ID() ~= 0 then
            local name = sp.Name()
            if name and name ~= "" then
                -- Get minimum level across all classes
                local minLevel = 255
                for cid = 1, 16 do
                    local lvl = tonum(sp.Level(cid)())
                    if lvl > 0 and lvl < minLevel and lvl < 255 then
                        minLevel = lvl
                    end
                end
                
                table.insert(spellCache, {
                    id = id,
                    name = name,
                    nameLower = name:lower(),
                    minLevel = minLevel < 255 and minLevel or nil
                })
            end
        end
    end
    
    currentCacheID = endID + 1
    cacheProgress = math.floor((currentCacheID / MAX_SPELL_ID) * 100)
    
    if currentCacheID > MAX_SPELL_ID then
        cacheBuilding = false
        cacheBuilt = true
        print(string.format("[%s] Spell cache built: %d spells", SCRIPT_NAME, #spellCache))
    end
end

-----------------------------
-- Fuzzy Matching (from itempass)
-----------------------------
local function levenshtein(a, b)
    a = a or ''
    b = b or ''
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end

    local prev = {}
    local curr = {}

    for j = 0, lb do
        prev[j] = j
    end

    for i = 1, la do
        curr[0] = i
        local ca = a:sub(i, i)
        for j = 1, lb do
            local cb = b:sub(j, j)
            local cost = (ca == cb) and 0 or 1
            local del  = prev[j]   + 1
            local ins  = curr[j-1] + 1
            local sub  = prev[j-1] + cost
            local v    = del
            if ins < v then v = ins end
            if sub < v then v = sub end
            curr[j] = v
        end
        prev, curr = curr, prev
    end

    return prev[lb]
end

local function getSpellSuggestions(prefix)
    prefix = trim(prefix)
    if prefix == '' or #prefix < 2 then return {} end
    
    -- Auto-start cache building on first search
    if not cacheBuilt and not cacheBuilding then
        startCacheBuilding()
    end
    
    -- Don't search until cache is ready
    if not cacheBuilt then return {} end
    
    -- Skip if query hasn't changed
    if prefix == lastProcessedQuery then
        return lookupSuggestions
    end
    lastProcessedQuery = prefix

    local search = prefix:lower()
    local matches = {}

    -- Search the cache instead of live TLO queries
    for _, entry in ipairs(spellCache) do
        local key = entry.nameLower
        
        -- Scoring
        local score
        local startPos = key:find(search, 1, true)
        if startPos == 1 then
            score = 0  -- starts with
        elseif startPos ~= nil then
            score = 1  -- contains
        else
            local slice = key:sub(1, #search)
            score = 2 + levenshtein(search, slice)  -- fuzzy
        end
        
        -- Only include reasonable matches
        if score <= 10 then
            local display = entry.name
            if score == 0 then
                display = '★ ' .. entry.name
            elseif score == 1 then
                display = '• ' .. entry.name
            end
            
            table.insert(matches, {
                id = entry.id,
                name = entry.name,
                display = display,
                score = score,
                minLevel = entry.minLevel
            })
        end
    end

    -- Sort by score, then level, then name
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.minLevel and b.minLevel and a.minLevel ~= b.minLevel then
            return a.minLevel < b.minLevel
        end
        return a.name:lower() < b.name:lower()
    end)

    -- Limit results
    local results = {}
    for i = 1, math.min(#matches, MAX_LOOKUP_RESULTS) do
        results[i] = matches[i]
    end

    return results
end

-----------------------------
-- Spell Selection
-----------------------------
local function selectSpell(spellID)
    selectedSpellID = spellID
    selectedSpellData = {}
    
    local sp = safe(function() return mq.TLO.Spell(spellID) end)
    if not sp or not sp.ID() or sp.ID() == 0 then
        selectedSpellData = nil
        return
    end
    
    selectedSpellData.name = sp.Name()
    selectedSpellData.id = spellID
    selectedSpellData.classes = {}
    
    for cid = 1, 16 do
        local lvl = tonum(sp.Level(cid)())
        -- Filter out level 255 (not available) and level 0 (invalid)
        if lvl > 0 and lvl < 255 then
            table.insert(selectedSpellData.classes, {
                name = CLASS_NAMES[cid] or "Unknown",
                level = lvl
            })
        end
    end
    
    -- Sort by level
    table.sort(selectedSpellData.classes, function(a, b)
        return a.level < b.level
    end)
end

-----------------------------
-- Scan Logic
-----------------------------
local function resetScan()
    spellsProcessed, missingCount = 0, 0
    missingSpells = {}
    currentScanID = 1
    scanning, scan_complete = false, false
end

local function startScan()
    resetScan()
    refreshCharacterState()

    filterMinLevel = math.max(0, math.min(filterMinLevel, charLevel))
    filterMaxLevel = math.max(filterMinLevel, math.min(filterMaxLevel, charLevel))

    scanning = true
    scanStartTime = os.clock()

    print(string.format(
        "[%s] Scan started for %s (%d–%d)",
        SCRIPT_NAME, getCharName(), filterMinLevel, filterMaxLevel
    ))
end

local function processBatch()
    local endID = math.min(currentScanID + SCAN_BATCH - 1, MAX_SPELL_ID)

    for id = currentScanID, endID do
        spellsProcessed = spellsProcessed + 1
        local sp = safe(function() return mq.TLO.Spell(id) end)
        if sp and sp.ID() and sp.ID() ~= 0 then
            local lvl = tonum(sp.Level(classID)())
            if lvl >= filterMinLevel and lvl <= filterMaxLevel then
                if not isKnown(sp) then
                    local t = classify(sp)
                    if not (hideSpellbook and t == "Spell") then
                        missingCount = missingCount + 1
                        table.insert(missingSpells, {
                            id=id, name=sp.Name(), level=lvl, type=t
                        })
                    end
                end
            end
        end
    end

    if spellsProcessed % 1000 == 0 then
        print(string.format(
            "[%s] %d/%d scanned | Missing: %d",
            SCRIPT_NAME, spellsProcessed, MAX_SPELL_ID, missingCount
        ))
    end

    currentScanID = endID + 1

    if currentScanID > MAX_SPELL_ID then
        scanning = false
        scan_complete = true
        print(string.format(
            "[%s] Scan complete for %s. Missing: %d",
            SCRIPT_NAME, getCharName(), missingCount
        ))
        if exportCSV then exportToCSV() end
    end
end

-----------------------------
-- CSV Export
-----------------------------
function exportToCSV()
    local charName = getCharName()
    local base = normalizePath(outputDir) or mqLogs()

    local path = string.format(
        "%s%s_MissingSpells_%s.csv",
        base,
        charName:gsub("%s+","_"),
        os.date("%Y-%m-%d_%H%M")
    )

    local f = io.open(path, "w")
    if not f then
        print(string.format("[%s] ERROR: Failed to write CSV", SCRIPT_NAME))
        return
    end

    f:write("ID,Name,Level\n")
    for _, s in ipairs(missingSpells) do
        f:write(string.format(
            '%d,"%s",%d\n',
            s.id,
            s.name:gsub('"','""'),
            s.level
        ))
    end
    f:close()

    print(string.format("[%s] CSV written: %s", SCRIPT_NAME, path))
end

-----------------------------
-- ETA
-----------------------------
local function ETA()
    if not scanning or spellsProcessed == 0 then return "Calculating..." end
    local avg = (os.clock() - scanStartTime) / spellsProcessed
    local remain = math.max(0, MAX_SPELL_ID - currentScanID)
    local sec = math.floor(avg * remain)
    return string.format("~%dm %ds", math.floor(sec / 60), sec % 60)
end

-----------------------------
-- GUI
-----------------------------
local function drawGUI()
    local _, open = ImGui.Begin(SCRIPT_NAME .. " " .. SCRIPT_VERSION, true)
    if type(open) == "boolean" and not open then terminate = true end

    -- Spell Lookup Section
    if ImGui.CollapsingHeader("Spell Lookup", ImGuiTreeNodeFlags.DefaultOpen) then
        ImGui.Text("Search for spell:")
        
        -- Cache status
        if cacheBuilding then
            ImGui.TextColored(1, 1, 0, 1, string.format("Building cache... %d%%", cacheProgress))
        elseif not cacheBuilt then
            ImGui.TextColored(1, 0.5, 0, 1, "Cache not built")
            ImGui.SameLine()
            if ImGui.Button("Build Cache##buildcache") then
                startCacheBuilding()
            end
            tooltip("Build spell database cache for instant search")
        else
            ImGui.TextColored(0, 1, 0, 1, string.format("Cache ready (%d spells)", #spellCache))
        end
        
        local query = ImGui.InputText("##lookup", lookupQuery, 256)
        if type(query) == "string" then
            lookupQuery = query
        end
        tooltip("Type spell name (e.g., 'sow' or 'spirit of wolf')")
        
        ImGui.SameLine()
        if ImGui.Button("Clear##lookup") then
            lookupQuery = ""
            lookupSuggestions = {}
            selectedSpellID = 0
            selectedSpellData = nil
            lastLookupChoice = nil
            lastProcessedQuery = ""
        end
        tooltip("Clear search and selection")
        
        -- Generate suggestions as user types (from cache)
        if cacheBuilt then
            lookupSuggestions = getSpellSuggestions(lookupQuery)
        end
        
        -- Active autocomplete dropdown
        local chosen = nil
        if #lookupSuggestions > 0 then
            local hint = string.format('%d match%s', 
                #lookupSuggestions, 
                #lookupSuggestions ~= 1 and 'es' or '')
            ImGui.TextDisabled('(%s)', hint)
            
            if ImGui.BeginCombo('##spell_autocomplete', 'Select spell...') then
                for _, entry in ipairs(lookupSuggestions) do
                    local labelText = entry.display
                    if entry.minLevel then
                        labelText = string.format('%s (Lv%d)', labelText, entry.minLevel)
                    end
                    labelText = string.format('[%d] %s', entry.id, labelText)
                    
                    local sel = (entry.id == selectedSpellID)
                    
                    if ImGui.Selectable(labelText, sel) then
                        chosen = entry.id
                    end
                    
                    if sel then
                        ImGui.SetItemDefaultFocus()
                    end
                end
                ImGui.EndCombo()
            end
        elseif lookupQuery ~= "" and #lookupQuery >= 2 and cacheBuilt then
            ImGui.TextDisabled('(no matches)')
        end
        
        -- Apply choice once
        if chosen and chosen ~= lastLookupChoice then
            selectSpell(chosen)
            lastLookupChoice = chosen
        elseif not chosen then
            lastLookupChoice = nil
        end
        
        -- Display selected spell details
        if selectedSpellData and selectedSpellData.classes then
            ImGui.Separator()
            ImGui.Text(string.format(
                "Spell: %s [%d]",
                selectedSpellData.name,
                selectedSpellData.id
            ))
            
            if #selectedSpellData.classes > 0 then
                ImGui.Text("Available to:")
                ImGui.BeginChild("classLevels", 0, 150, true)
                for _, cls in ipairs(selectedSpellData.classes) do
                    ImGui.Text(string.format("  %s (Level %d)", cls.name, cls.level))
                end
                ImGui.EndChild()
            else
                ImGui.Text("No classes can use this spell")
            end
        end
    end
    
    ImGui.Separator()

    -- Existing Missing Spells Scanner Section
    if ImGui.CollapsingHeader("Missing Spells Scanner", ImGuiTreeNodeFlags.DefaultOpen) then
        ImGui.Text("Output Directory:")
        local od = ImGui.InputText("##outdir", outputDir, 512)
        if type(od) == "string" then outputDir = od; saveSettings() end
        
        if ImGui.Button("Use MQ Logs") then outputDir = mqLogs(); saveSettings() end
        tooltip("Set output directory to MacroQuest Logs folder")
        
        ImGui.SameLine()
        
        if ImGui.Button("Use Script Dir") then outputDir = scriptDir(); saveSettings() end
        tooltip("Set output directory to MacroQuest root folder")

        ImGui.Separator()
        ImGui.Text("Level Range")
        local mn = ImGui.SliderInt("Min Level", filterMinLevel, 0, charLevel)
        if type(mn) == "number" then filterMinLevel = mn; saveSettings() end
        local mx = ImGui.SliderInt("Max Level", filterMaxLevel, 0, charLevel)
        if type(mx) == "number" then filterMaxLevel = mx; saveSettings() end

        local g = ImGui.Checkbox("Display missing spells in GUI", showInGUI)
        if type(g) == "boolean" then showInGUI = g; saveSettings() end
        tooltip("Show the list of missing spells in the window below after scanning")

        local c = ImGui.Checkbox("Export missing spells to CSV", exportCSV)
        if type(c) == "boolean" then exportCSV = c; saveSettings() end
        tooltip("Automatically export results to a CSV file when scan completes")

        local h = ImGui.Checkbox("Hide spellbook spells (show abilities / disciplines)", hideSpellbook)
        if type(h) == "boolean" then hideSpellbook = h; saveSettings() end
        tooltip("Filter out regular spellbook spells, showing only abilities and disciplines")

        ImGui.Separator()

        if scanning then
            ImGui.Text("Scanning... ETA: " .. ETA())
        elseif scan_complete then
            ImGui.Text(string.format(
                "Scan complete for %s. Missing: %d",
                getCharName(), missingCount
            ))
            if ImGui.Button("Re-Export CSV") then exportToCSV() end
            tooltip("Export the current results to a new CSV file")
        else
            if ImGui.Button("Find Missing Spells") then startScan() end
            tooltip("Begin scanning all spells to find missing abilities and spells")
        end

        if showInGUI and scan_complete then
            ImGui.Separator()
            ImGui.BeginChild("results", 0, 200, true)
            for _, s in ipairs(missingSpells) do
                ImGui.Text(string.format("[%d] Lv%d - %s", s.id, s.level, s.name))
            end
            ImGui.EndChild()
        end
    end
    
    ImGui.Separator()
    if ImGui.Button("Close") then terminate = true end
    tooltip("Close SpellExport and save settings")

    ImGui.End()
end

-----------------------------
-- Main
-----------------------------
loadSettings()
refreshCharacterState()

mq.imgui.init(SCRIPT_NAME, drawGUI)

while mq.TLO.MacroQuest.GameState() == "INGAME" and not terminate do
    if scanning then processBatch() end
    if cacheBuilding then buildCacheBatch() end
    mq.delay(DELAY_MS)
end

saveSettings()
mq.imgui.destroy(SCRIPT_NAME)
print(string.format("[%s] Closed.", SCRIPT_NAME))
