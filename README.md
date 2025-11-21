# Project Lazarus Spell Scanner

A comprehensive spell scanning tool for **Project Lazarus EverQuest** that identifies missing spells from your character's spellbook and exports them to a CSV file for easy reference.

##  Overview

This Lua script scans all spell IDs in the Project Lazarus database (up to 30,000), identifies which spells are available for your class and level, and generates a detailed CSV report of spells you haven't learned yet. 

##  Features

-  Scans all 30,000+ spell IDs in ~35-60 seconds
-  Identifies spells available for your class and level
-  Exports missing spells to CSV with detailed information
-  Generates comprehensive log file with scan progress
-  Real-time progress updates every 1,000 spells
-  No manual configuration required - automatically detects character info

##  Output Data

The CSV file includes the following information for each missing spell:

- **Spell ID** - Database identifier
- **Spell Name** - Full spell name
- **Level** - Required level for your class
- **Spell Type** - Expansion (Original/Kunark/Velious/Luclin/etc.)
- **Target Type** - Who/what the spell targets
- **Mana Cost** - Mana required to cast
- **Cast Time** - Time to cast in seconds
- **Duration** - Spell duration
- **Spell Range** - Maximum casting range
- **Status** - Always "Missing" in the output

##  Requirements

- **Project Lazarus EverQuest** server
- **MacroQuest (EMU version)** with Lua support
- **E3Next** (MQNext binary)

##  Installation

1. Download `SpellExport.lua` from this repository

2. Place the file in your MacroQuest `lua` folder:
   ```
   <Your_Project_Lazarus_Path>/E3NextAndMQNextBinary-main/lua/spellscanner.lua
   ```

3. If the `lua` folder doesn't exist, create it

##  Usage

1. Log in to your character in Project Lazarus

2. In the EverQuest chat window, type:
   ```
   /lua run SpellExport
   ```

3. Wait for the scan to complete (typically 35-60 seconds)

4. Find your output files in the E3NextAndMQNextBinary-main folder:
   - `<CharName>_<Class>_Spells_<Timestamp>.csv`
   - `<CharName>_<Class>_Log_<Timestamp>.txt`

##  Example Output

### Console Output:
```
===============================================
Project Lazarus Spell Scanner (Lua Version)
Character: Gimok (Shaman 70)
===============================================
CSV: C:/Games/Project_Lazarus/E3NextAndMQNextBinary-main/Gimok_Shaman_Spells_2025_11_20_233521.csv
LOG: C:/Games/Project_Lazarus/E3NextAndMQNextBinary-main/Gimok_Shaman_Log_2025_11_20_233521.txt
===============================================

Scanning 30000 spell IDs - this will take 2-5 minutes
Processed 1000/30000 | Valid: 998 | Class/Level: 132 | Known: 37 | Missing: 95
Processed 2000/30000 | Valid: 1997 | Class/Level: 187 | Known: 56 | Missing: 131
...
Processed 30000/30000 | Valid: 29663 | Class/Level: 339 | Known: 122 | Missing: 217

===============================================
SPELL SCAN COMPLETE
===============================================
Total spell IDs processed: 30000
Valid spells in database: 29663
Spells for your class/level: 339
 - Spells you know: 122
 - Missing spells: 217
===============================================
```

### CSV Output:
```csv
Spell_ID,Spell_Name,Level,Spell_Type,Target_Type,Mana_Cost,Cast_Time,Duration,Spell_Range,Status
11545,"Spirit of the Wolf",9,"Original","Single",40,4500,360,100,Missing
...
```

##  Configuration

The script includes a few configurable options at the top of the file:

```lua
local MAX_SPELL_ID = 30000        -- Maximum spell ID to scan
local PROGRESS_INTERVAL = 1000    -- Show progress every N spells
local OUTPUT_DIR = "C:/Games/Project_Lazarus/E3NextAndMQNextBinary-main/"
```

**Note:** If your Project Lazarus installation is in a different location, update the `OUTPUT_DIR` path accordingly.

##  Troubleshooting

### "Lua not found" error
- Ensure you have MacroQuest with Lua support installed
- Verify the file is in the `lua` subfolder
- Check that the filename is exactly `SpellExport.lua`

### No files generated
- Check the `OUTPUT_DIR` path in the script matches your installation
- Ensure you have write permissions to the output folder
- Look for error messages in the MacroQuest console

### Script runs but shows 0 spells
- Make sure you're logged in to a character (not at character select)
- Verify your character is fully loaded in-game before running

### Progress seems stuck
- The script processes 100 spell IDs per second - this is normal
- Wait for the full scan to complete (30-60 seconds)
- Check the log file for detailed progress

### Performance

The script processes approximately:
- 100 spell IDs per second
- 30,000 total IDs in ~35-60 seconds
- Includes small delays to prevent server lag

##  Contributing

Contributions are welcome! If you'd like to improve the script:

1. Fork this repository
2. Create a feature branch
3. Submit a pull request with your changes

Suggestions for improvements:
- Add filtering options (by level range, spell type, etc.)
- Support for custom spell ID ranges
- Integration with vendor locations
- Spell cost information from vendors

##  License

This project is provided as-is for use with Project Lazarus EverQuest. Feel free to modify and distribute.

##  Acknowledgments

- **Project Lazarus** team for the amazing EverQuest server
- **MacroQuest** developers for the EMU toolkit
- **E3Next** contributors for the enhanced MacroQuest binary
- Community members who helped test and debug
- This is originally not my work. I just improved on it. Author unknown. The original versions of this script attempted to use MacroQuest's macro scripting language, but encountered a critical limitation: **MacroQuest EMU does not support file I/O operations** in its macro language. Commands like `/fileprint` and `/logfile` don't exist, and shell redirection (`/echo > file`) is not supported. **Lua**, however, has full file I/O support through standard Lua libraries (`io.open()`, `file:write()`, etc.), making it the ideal solution for this tool.
