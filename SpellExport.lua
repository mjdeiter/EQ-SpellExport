-- ======================================================================
-- SpellExport v1.6.0
-- Project Lazarus Spell Export Tool
--
-- v1.6.0
--  • Persistent spell cache (builds once, saves forever)
--  • Background cache building with progress bar
--  • Cache stats panel
--  • Schema migrator for cache versioning
--  • Dual window close behavior (hide vs exit)
-- v1.5.1
--  • Spell lookup with fuzzy search
--  • Missing spells scanner with level filters
--  • CSV export capability
-- ======================================================================

-----------------------------
-- Script Identity
-----------------------------
local SCRIPT_NAME    = "SpellExport"
local SCRIPT_VERSION = "v1.6.0"

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
local CACHE_BATCH   = 500
local DELAY_MS      = 1
local MAX_LOOKUP_RESULTS = 20

local CACHE_SCHEMA_VERSION = 1

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
-- Cache FSM States
-----------------------------
local CACHE_STATE = {
    IDLE = "IDLE",
    BUILDING = "BUILDING",
    COMPLETE = "COMPLETE",
    ERROR = "ERROR"
}

-----------------------------
-- State
-----------------------------
local showUI = true
local terminate = false

-- Missing Spells Scanner State
local scanning = false
local scan_complete = false
local currentScanID = 1
local scanStartTime = 0
local spellsProcessed = 0
local missingCount = 0
local missingSpells = {}

-- Spell Lookup State
local lookupQuery = ""
local lookupSuggestions = {}
local selectedSpellID = 0
local selectedSpellData = nil
local lastLookupChoice = nil
local lastProcessedQuery = ""

-- Spell Cache State
local cacheState = CACHE_STATE.IDLE
local cacheProgress = 0
local currentCacheID = 1
local spellCache = {}
local cacheStats = {
    totalSpells = 0,
    lastBuildTime = "Never",
    schemaVersion = 0
}

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

local function getConfigDir()
    if mq.configDir then return mq.configDir end
    local p = mq.TLO.MacroQuest.Path('config')
    if p and p() and p() ~= '' then return p() end
    return '.'
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
-- File Paths
-----------------------------
local CONFIG_DIR = getConfigDir()
local CACHE_FILE = CONFIG_DIR .. "/SpellExport_cache.lua"
local SETTINGS_FILE = CONFIG_DIR .. "/SpellExport_settings.lua"

-----------------------------
-- Dynamic Character State
-----------------------------
local classID = 0
local charLevel = 1

local function refreshCharacterState()
    classID   = tonum(safe(function() return mq.TLO.Me.Class.ID() end))
    charLevel = tonum(safe(function() return mq.TLO.Me.Level() end))
end

-----------------------------
-- UI / Persisted State
-----------------------------
local filterMinLevel = 0
local filterMaxLevel = 1
local showInGUI = true
local exportCSV = true
local hideSpellbook = false
local outputDir = mqLogs()
local allowBackgroundCache = true

-----------------------------
-- Safe File I/O
-----------------------------
local function loadLuaTable(path)
    local f = loadfile(path)
    if not f then return nil end
    local ok, data = pcall(f)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function writeLuaTable(path, tbl)
    local f = io.open(path, "w")
    if not f then return false end
    
    local function serialize(v, indent)
        indent = indent or 0
        local istr = string.rep("  ", indent)
        
        if type(v) == "number" or type(v) == "boolean" then
            return tostring(v)
        elseif type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "table" then
            local lines = {"{"}
            for k, val in pairs(v) do
                local key
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key = k
                else
                    key = "[" .. serialize(k) .. "]"
                end
                table.insert(lines, istr .. "  " .. key .. " = " .. serialize(val, indent + 1) .. ",")
            end
            table.insert(lines, istr .. "}")
            return table.concat(lines, "\n")
        end
        return "nil"
    end
    
    f:write("return ")
    f:write(serialize(tbl))
    f:write("\n")
    f:close()
    return true
end

-----------------------------
-- Settings Persistence
-----------------------------
local function loadSettings()
    local data = loadLuaTable(SETTINGS_FILE)
    if not data then return end
    
    filterMinLevel = tonum(data.minLevel or filterMinLevel)
    filterMaxLevel = tonum(data.maxLevel or filterMaxLevel)
    showInGUI = (data.showInGUI ~= false)
    exportCSV = (data.exportCSV ~= false)
    hideSpellbook = (data.hideSpellbook == true)
    allowBackgroundCache = (data.allowBackgroundCache ~= false)
    
    if data.outputDir then
        outputDir = data.outputDir
    end
end

local function saveSettings()
    local data = {
        minLevel = filterMinLevel,
        maxLevel = filterMaxLevel,
        showInGUI = showInGUI,
        exportCSV = exportCSV,
        hideSpellbook = hideSpellbook,
        allowBackgroundCache = allowBackgroundCache,
        outputDir = normalizePath(outputDir)
    }
    
    writeLuaTable(SETTINGS_FILE, data)
end

-----------------------------
-- Cache Persistence
-----------------------------
local function loadCache()
    local data = loadLuaTable(CACHE_FILE)
    if not data then return false end
    
    -- Schema migration
    if not data.schemaVersion or data.schemaVersion < CACHE_SCHEMA_VERSION then
        print(string.format("[%s] Cache schema outdated, rebuilding...", SCRIPT_NAME))
        return false
    end
    
    if not data.spells or type(data.spells) ~= "table" then
        return false
    end
    
    spellCache = data.spells
    cacheStats.totalSpells = #spellCache
    cacheStats.lastBuildTime = data.buildTime or "Unknown"
    cacheStats.schemaVersion = data.schemaVersion or 0
    
    cacheState = CACHE_STATE.COMPLETE
    
    print(string.format("[%s] Loaded spell cache: %d spells", SCRIPT_NAME, #spellCache))
    return true
end

local function saveCache()
    local data = {
        schemaVersion = CACHE_SCHEMA_VERSION,
        buildTime = os.date("%Y-%m-%d %H:%M:%S"),
        spells = spellCache
    }
    
    if writeLuaTable(CACHE_FILE, data) then
        cacheStats.lastBuildTime = data.buildTime
        cacheStats.schemaVersion = CACHE_SCHEMA_VERSION
        print(string.format("[%s] Spell cache saved: %d spells", SCRIPT_NAME, #spellCache))
        return true
    end
    
    return false
end

-----------------------------
-- Cache Building FSM
-----------------------------
local function startCacheBuilding()
    if cacheState == CACHE_STATE.BUILDING or cacheState == CACHE_STATE.COMPLETE then
        return
    end
    
    spellCache = {}
    currentCacheID = 1
    cacheProgress = 0
    cacheState = CACHE_STATE.BUILDING
    
    print(string.format("[%s] Building spell cache...", SCRIPT_NAME))
end

local function buildCacheBatch()
    if cacheState ~= CACHE_STATE.BUILDING then return end
    
    local endID = math.min(currentCacheID + CACHE_BATCH - 1, MAX_SPELL_ID)
    
    for id = currentCacheID, endID do
        local sp = safe(function() return mq.TLO.Spell(id) end)
        if sp and sp.ID() and sp.ID() ~= 0 then
            local name = sp.Name()
            if name and name ~= "" then
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
        cacheState = CACHE_STATE.COMPLETE
        cacheStats.totalSpells = #spellCache
        
        print(string.format("[%s] Cache build complete: %d spells", SCRIPT_NAME, #spellCache))
        
        if not saveCache() then
            print(string.format("[%s] WARNING: Failed to save cache to disk", SCRIPT_NAME))
        end
    end
end

local function resetCache()
    spellCache = {}
    currentCacheID = 1
    cacheProgress = 0
    cacheState = CACHE_STATE.IDLE
    cacheStats.totalSpells = 0
    
    -- Delete cache file
    os.remove(CACHE_FILE)
    
    print(string.format("[%s] Cache cleared", SCRIPT_NAME))
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
-- Fuzzy Matching
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
    
    if cacheState ~= CACHE_STATE.COMPLETE then
        return {}
    end
    
    if prefix == lastProcessedQuery then
        return lookupSuggestions
    end
    lastProcessedQuery = prefix

    local search = prefix:lower()
    local matches = {}

    for _, entry in ipairs(spellCache) do
        local key = entry.nameLower
        
        local score
        local startPos = key:find(search, 1, true)
        if startPos == 1 then
            score = 0
        elseif startPos ~= nil then
            score = 1
        else
            local slice = key:sub(1, #search)
            score = 2 + levenshtein(search, slice)
        end
        
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

    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        if a.minLevel and b.minLevel and a.minLevel ~= b.minLevel then
            return a.minLevel < b.minLevel
        end
        return a.name:lower() < b.name:lower()
    end)

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
        if lvl > 0 and lvl < 255 then
            table.insert(selectedSpellData.classes, {
                name = CLASS_NAMES[cid] or "Unknown",
                level = lvl
            })
        end
    end
    
    table.sort(selectedSpellData.classes, function(a, b)
        return a.level < b.level
    end)
end

-----------------------------
-- Missing Spells Scanner
-----------------------------
local function resetScan()
    spellsProcessed = 0
    missingCount = 0
    missingSpells = {}
    currentScanID = 1
    scanning = false
    scan_complete = false
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
                            id = id,
                            name = sp.Name(),
                            level = lvl,
                            type = t
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
-- ETA Calculation
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
    if not showUI then return end
    
    local open = ImGui.Begin(SCRIPT_NAME .. " " .. SCRIPT_VERSION, true)
    if not open then
        showUI = false
        ImGui.End()
        return
    end

    -- Cache Stats Panel
    if ImGui.CollapsingHeader("Cache Status", ImGuiTreeNodeFlags.DefaultOpen) then
        local stateColor = {1, 1, 1, 1}
        local stateText = "Unknown"
        
        if cacheState == CACHE_STATE.IDLE then
            stateColor = {1, 0.5, 0, 1}
            stateText = "Not Built"
        elseif cacheState == CACHE_STATE.BUILDING then
            stateColor = {1, 1, 0, 1}
            stateText = string.format("Building... %d%%", cacheProgress)
        elseif cacheState == CACHE_STATE.COMPLETE then
            stateColor = {0, 1, 0, 1}
            stateText = "Ready"
        elseif cacheState == CACHE_STATE.ERROR then
            stateColor = {1, 0, 0, 1}
            stateText = "Error"
        end
        
        ImGui.Text("Status:")
        ImGui.SameLine()
        ImGui.TextColored(stateColor[1], stateColor[2], stateColor[3], stateColor[4], stateText)
        
        ImGui.Text(string.format("Total Spells: %d", cacheStats.totalSpells))
        ImGui.Text(string.format("Last Build: %s", cacheStats.lastBuildTime))
        ImGui.Text(string.format("Schema: v%d", cacheStats.schemaVersion))
        
        if cacheState == CACHE_STATE.IDLE or cacheState == CACHE_STATE.ERROR then
            if ImGui.Button("Build Cache##build") then
                startCacheBuilding()
            end
            tooltip("Build spell database cache for instant search")
        elseif cacheState == CACHE_STATE.COMPLETE then
            if ImGui.Button("Rebuild Cache##rebuild") then
                resetCache()
                startCacheBuilding()
            end
            tooltip("Clear and rebuild spell cache from scratch")
        end
        
        ImGui.SameLine()
        
        local bg = ImGui.Checkbox("Background Build##bgcache", allowBackgroundCache)
        if type(bg) == "boolean" then
            allowBackgroundCache = bg
            saveSettings()
        end
        tooltip("Allow cache to build while window is hidden")
    end
    
    ImGui.Separator()

    -- Spell Lookup Section
    if ImGui.CollapsingHeader("Spell Lookup", ImGuiTreeNodeFlags.DefaultOpen) then
        ImGui.Text("Search for spell:")
        
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
        
        if cacheState == CACHE_STATE.COMPLETE then
            lookupSuggestions = getSpellSuggestions(lookupQuery)
        end
        
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
        elseif lookupQuery ~= "" and #lookupQuery >= 2 and cacheState == CACHE_STATE.COMPLETE then
            ImGui.TextDisabled('(no matches)')
        elseif cacheState ~= CACHE_STATE.COMPLETE and lookupQuery ~= "" then
            ImGui.TextColored(1, 0.5, 0, 1, "Cache not ready - build cache first")
        end
        
        if chosen and chosen ~= lastLookupChoice then
            selectSpell(chosen)
            lastLookupChoice = chosen
        elseif not chosen then
            lastLookupChoice = nil
        end
        
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

    -- Missing Spells Scanner Section
    if ImGui.CollapsingHeader("Missing Spells Scanner", ImGuiTreeNodeFlags.DefaultOpen) then
        ImGui.Text("Output Directory:")
        local od = ImGui.InputText("##outdir", outputDir, 512)
        if type(od) == "string" then
            outputDir = od
            saveSettings()
        end
        
        if ImGui.Button("Use MQ Logs") then
            outputDir = mqLogs()
            saveSettings()
        end
        tooltip("Set output directory to MacroQuest Logs folder")
        
        ImGui.SameLine()
        
        if ImGui.Button("Use Script Dir") then
            outputDir = scriptDir()
            saveSettings()
        end
        tooltip("Set output directory to MacroQuest root folder")

        ImGui.Separator()
        ImGui.Text("Level Range")
        
        local mn = ImGui.SliderInt("Min Level", filterMinLevel, 0, charLevel)
        if type(mn) == "number" then
            filterMinLevel = mn
            saveSettings()
        end
        
        local mx = ImGui.SliderInt("Max Level", filterMaxLevel, 0, charLevel)
        if type(mx) == "number" then
            filterMaxLevel = mx
            saveSettings()
        end

        local g = ImGui.Checkbox("Display missing spells in GUI", showInGUI)
        if type(g) == "boolean" then
            showInGUI = g
            saveSettings()
        end
        tooltip("Show the list of missing spells in the window below after scanning")

        local c = ImGui.Checkbox("Export missing spells to CSV", exportCSV)
        if type(c) == "boolean" then
            exportCSV = c
            saveSettings()
        end
        tooltip("Automatically export results to a CSV file when scan completes")

        local h = ImGui.Checkbox("Hide spellbook spells (show abilities / disciplines)", hideSpellbook)
        if type(h) == "boolean" then
            hideSpellbook = h
            saveSettings()
        end
        tooltip("Filter out regular spellbook spells, showing only abilities and disciplines")

        ImGui.Separator()

        if scanning then
            ImGui.Text("Scanning... ETA: " .. ETA())
        elseif scan_complete then
            ImGui.Text(string.format(
                "Scan complete for %s. Missing: %d",
                getCharName(), missingCount
            ))
            if ImGui.Button("Re-Export CSV") then
                exportToCSV()
            end
            tooltip("Export the current results to a new CSV file")
        else
            if ImGui.Button("Find Missing Spells") then
                startScan()
            end
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
    
    if ImGui.Button("Exit Script") then
        terminate = true
    end
    tooltip("Close SpellExport completely and save settings")

    ImGui.End()
end

-----------------------------
-- Command Handler
-----------------------------
local function handleCommand(...)
    local args = {...}
    local cmd = args[1] and args[1]:lower() or ""
    
    if cmd == "gui" or cmd == "show" then
        showUI = true
        print(string.format("[%s] GUI shown", SCRIPT_NAME))
    elseif cmd == "hide" then
        showUI = false
        print(string.format("[%s] GUI hidden", SCRIPT_NAME))
    elseif cmd == "exit" or cmd == "quit" then
        terminate = true
        print(string.format("[%s] Exiting...", SCRIPT_NAME))
    elseif cmd == "buildcache" then
        startCacheBuilding()
    elseif cmd == "resetcache" then
        resetCache()
    else
        print(string.format("[%s] Commands: gui, hide, exit, buildcache, resetcache", SCRIPT_NAME))
    end
end

mq.bind('/spellexport', handleCommand)

-----------------------------
-- Initialization
-----------------------------
print(string.format("[%s] %s starting...", SCRIPT_NAME, SCRIPT_VERSION))

loadSettings()
refreshCharacterState()

if not loadCache() then
    print(string.format("[%s] No cache found - build cache for spell lookup", SCRIPT_NAME))
end

mq.imgui.init(SCRIPT_NAME, drawGUI)

-----------------------------
-- Main Loop
-----------------------------
while mq.TLO.MacroQuest.GameState() == "INGAME" and not terminate do
    if scanning then
        processBatch()
    end
    
    if cacheState == CACHE_STATE.BUILDING and (showUI or allowBackgroundCache) then
        buildCacheBatch()
    end
    
    mq.delay(DELAY_MS)
end

-----------------------------
-- Shutdown
-----------------------------
saveSettings()
mq.imgui.destroy(SCRIPT_NAME)
print(string.format("[%s] Closed.", SCRIPT_NAME))
