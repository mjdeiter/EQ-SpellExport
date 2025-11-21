-- Project Lazarus Spell Scanner - LUA VERSION
-- Works with MacroQuest EMU (E3Next) on Project Lazarus


local mq = require('mq')

-- Configuration
local MAX_SPELL_ID = 30000
local PROGRESS_INTERVAL = 1000
local OUTPUT_DIR = "C:/Games/Project_Lazarus/E3NextAndMQNextBinary-main/"

-- Counters
local spellsProcessed = 0
local validSpells = 0
local classLevelSpells = 0
local spellsKnown = 0
local missingSpells = 0
local missingData = {}

-- Get timestamp for filenames
local function getTimestamp()
    return os.date("%Y_%m_%d_%H%M%S")
end

-- Get character info
local charName = mq.TLO.Me.CleanName()
local className = mq.TLO.Me.Class.Name()
local classID = mq.TLO.Me.Class.ID()
local charLevel = mq.TLO.Me.Level()
local timestamp = getTimestamp()

-- Build file paths
local csvFile = string.format("%s%s_%s_Spells_%s.csv", OUTPUT_DIR, charName, className, timestamp)
local logFile = string.format("%s%s_%s_Log_%s.txt", OUTPUT_DIR, charName, className, timestamp)

-- Logging function
local function log(message)
    print(message)
    local f = io.open(logFile, "a")
    if f then
        f:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), message))
        f:close()
    end
end

-- Initialize files
local function initializeFiles()
    -- Create CSV with header
    local f = io.open(csvFile, "w")
    if not f then
        print("ERROR: Could not create CSV file: " .. csvFile)
        return false
    end
    f:write("Spell_ID,Spell_Name,Level,Spell_Type,Target_Type,Mana_Cost,Cast_Time,Duration,Spell_Range,Status\n")
    f:close()
    
    -- Create log file
    f = io.open(logFile, "w")
    if not f then
        print("ERROR: Could not create log file: " .. logFile)
        return false
    end
    f:write("===============================================\n")
    f:write(string.format("Project Lazarus Spell Scanner\n"))
    f:write(string.format("Character: %s (%s Level %d)\n", charName, className, charLevel))
    f:write(string.format("Timestamp: %s\n", timestamp))
    f:write(string.format("Scanning spell IDs 1 to %d\n", MAX_SPELL_ID))
    f:write("===============================================\n")
    f:close()
    
    return true
end

-- Get spell type by ID range
local function getSpellType(spellID)
    if spellID <= 999 then
        return "Original"
    elseif spellID <= 2999 then
        return "Kunark"
    elseif spellID <= 3999 then
        return "Velious"
    elseif spellID <= 4999 then
        return "Luclin"
    else
        return "Later_Expansion"
    end
end

-- Check a single spell
local function checkSpell(spellID)
    spellsProcessed = spellsProcessed + 1
    
    -- Get spell object
    local spell = mq.TLO.Spell(spellID)
    
    -- Check if spell exists
    if not spell or not spell.ID() or spell.ID() == 0 then
        return -- Invalid spell ID
    end
    
    local spellName = spell.Name()
    if not spellName or spellName == "NULL" or spellName == "" then
        return -- Invalid spell
    end
    
    validSpells = validSpells + 1
    
    -- Check if it's for our class and level
    local spellLevel = spell.Level(classID)() or 0
    if spellLevel <= 0 or spellLevel > charLevel then
        return -- Not for our class or too high level
    end
    
    classLevelSpells = classLevelSpells + 1
    
    -- Check if we know this spell
    local isKnown = mq.TLO.Me.Book(spellName)() ~= nil
    
    if isKnown then
        spellsKnown = spellsKnown + 1
    else
        -- We don't know it - add to missing list
        missingSpells = missingSpells + 1
        
        -- Get additional spell info
        local spellType = spell.SpellType() or getSpellType(spellID)
        local targetType = spell.TargetType() or "Unknown"
        local manaCost = spell.Mana() or 0
        local castTime = spell.CastTime() or 0
        local duration = spell.Duration() or 0
        local spellRange = spell.Range() or 0
        
        -- Store data
        table.insert(missingData, {
            id = spellID,
            name = spellName:gsub('"', "'"), -- Replace quotes
            level = spellLevel,
            spellType = spellType,
            targetType = targetType,
            mana = manaCost,
            castTime = castTime,
            duration = duration,
            range = spellRange
        })
    end
end

-- Main scan function
local function scanSpells()
    log("Starting spell scan...")
    print(string.format("Scanning %d spell IDs - this will take 2-5 minutes", MAX_SPELL_ID))
    
    local startTime = os.clock()
    
    for i = 1, MAX_SPELL_ID do
        checkSpell(i)
        
        -- Progress update
        if i % PROGRESS_INTERVAL == 0 then
            local message = string.format("Processed %d/%d | Valid: %d | Class/Level: %d | Known: %d | Missing: %d",
                i, MAX_SPELL_ID, validSpells, classLevelSpells, spellsKnown, missingSpells)
            print(message)
            log(message)
        end
        
        -- Yield periodically to prevent freezing
        if i % 100 == 0 then
            mq.delay(1)
        end
    end
    
    local elapsed = os.clock() - startTime
    log(string.format("Scan complete in %.2f seconds", elapsed))
end

-- Write results to CSV
local function writeResults()
    log("Writing results to CSV...")
    
    local f = io.open(csvFile, "a")
    if not f then
        print("ERROR: Could not open CSV for writing")
        return false
    end
    
    for _, spell in ipairs(missingData) do
        f:write(string.format('%d,"%s",%d,"%s","%s",%d,%d,%d,%d,Missing\n',
            spell.id, spell.name, spell.level, spell.spellType, spell.targetType,
            spell.mana, spell.castTime, spell.duration, spell.range))
    end
    
    f:close()
    return true
end

-- Print summary
local function printSummary()
    local summary = [[
===============================================
SPELL SCAN COMPLETE
===============================================
Total spell IDs processed: %d
Valid spells in database: %d
Spells for your class/level: %d
 - Spells you know: %d
 - Missing spells: %d
===============================================
CSV File: %s
LOG File: %s
===============================================
]]
    
    local message = string.format(summary, spellsProcessed, validSpells, classLevelSpells,
        spellsKnown, missingSpells, csvFile, logFile)
    
    print(message)
    log(message)
end

-- Main execution
print("===============================================")
print("Project Lazarus Spell Scanner (Lua Version)")
print(string.format("Character: %s (%s %d)", charName, className, charLevel))
print("===============================================")
print("CSV: " .. csvFile)
print("LOG: " .. logFile)
print("===============================================")

if not initializeFiles() then
    print("Failed to initialize files. Aborting.")
    return
end

scanSpells()
writeResults()
printSummary()

print("Script complete!")