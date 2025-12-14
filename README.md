[![Support](https://img.shields.io/badge/Support-Buy%20Me%20a%20Coffee-6f4e37)](https://buymeacoffee.com/shablagu)

# Project Lazarus Spell Scanner

A comprehensive spell scanning and export tool for Project Lazarus EverQuest that identifies missing spells from a character’s spellbook and exports the results to CSV.

---

## Credits
**Original author:** Unknown  
**Improvements and Lua implementation:** Alektra  
**For:** Project Lazarus EverQuest EMU Server  

---

## Description
Project Lazarus Spell Scanner is a Lua-based utility that scans the Project Lazarus spell database and determines which spells are available—but not yet learned—by your character.

The script evaluates all spell IDs in the database (up to 30,000), filters them by class and level eligibility, compares them against your spellbook, and exports a detailed CSV report listing all missing spells.

This tool replaces earlier macro-based attempts that were limited by MacroQuest EMU’s lack of file I/O support. By using Lua, the scanner safely generates files using standard Lua file operations.

---

## Key Features
- **Full database scan**  
  Scans all 30,000+ spell IDs in approximately 35–60 seconds.

- **Class and level filtering**  
  Identifies only spells usable by your class and current level.

- **CSV export**  
  Generates a detailed spreadsheet of missing spells for easy reference.

- **Progress reporting**  
  Displays real-time progress updates every configurable interval.

- **Automatic character detection**  
  No manual configuration required for class or level.

- **Comprehensive logging**  
  Writes a timestamped log file documenting scan progress and results.

---

## Output Data

The generated CSV includes the following columns:

- Spell ID
- Spell Name
- Required Level
- Spell Type (Expansion)
- Target Type
- Mana Cost
- Cast Time (ms)
- Duration
- Spell Range
- Status (always `Missing`)

---

## Requirements
- Project Lazarus EverQuest EMU server
- MacroQuest (EMU build) with Lua support
- MQNext / E3Next binary

---

## Installation
1. Download `spellscanner.lua` (or `SpellExport.lua`, depending on filename).
2. Place the file in your MacroQuest Lua directory:
