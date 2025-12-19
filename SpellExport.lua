-- ======================================================================
-- SpellExport v1.4.0
-- Project Lazarus Spell Export Tool
--
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
local SCRIPT_VERSION = "v1.4.0"

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

-----------------------------
-- State
-----------------------------
local scanning, scan_complete, terminate = false, false, false
local currentScanID, scanStartTime = 1, 0
local spellsProcessed, missingCount = 0, 0
local missingSpells = {}

-----------------------------
-- Helpers
-----------------------------
local function safe(fn)
    local ok, r = pcall(fn)
    if ok then return r end
end

local function tonum(v) return tonumber(v) or 0 end

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
        
        ImGui.SameLine()
        
        if ImGui.Button("Close") then terminate = true end
        tooltip("Close SpellExport and save settings")
    end

    if showInGUI and scan_complete then
        ImGui.Separator()
        ImGui.BeginChild("results", 0, 300, true)
        for _, s in ipairs(missingSpells) do
            ImGui.Text(string.format("[%d] Lv%d - %s", s.id, s.level, s.name))
        end
        ImGui.EndChild()
    end

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
    mq.delay(DELAY_MS)
end

saveSettings()
mq.imgui.destroy(SCRIPT_NAME)
print(string.format("[%s] Closed.", SCRIPT_NAME))
