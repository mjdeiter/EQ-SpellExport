# SpellExport

[![Support](https://img.shields.io/badge/Support-Buy%20Me%20a%20Coffee-6f4e37)](https://buymeacoffee.com/shablagu)

A comprehensive spell, discipline, and ability scanner for the Project Lazarus EverQuest EMU server.  
SpellExport identifies which abilities your character is missing within a configurable level range and provides a fast spell lookup tool for reference and planning.

---

## Features

### Missing Spell Scanner
- **Comprehensive Scanning**: Scans all spell IDs (1–30000) to identify missing spells, disciplines, and abilities
- **Level Filtering**: Configurable minimum and maximum level range
- **Ability Classification**: Internally distinguishes spells, disciplines, abilities, and hybrids
- **Flexible Output**:
  - GUI display of missing spells
  - CSV export with timestamped filenames
- **Selective Filtering**:
  - Option to hide spellbook spells and show only abilities / disciplines
- **Progress Tracking**:
  - Real-time scan progress
  - ETA calculation
- **Persistent Settings**:
  - All configuration automatically saved between sessions
- **Smart Output Paths**:
  - MacroQuest Logs directory
  - MacroQuest root (script) directory
  - Custom user-defined path

### Spell Lookup Tool (v1.5+)
- **Instant Spell Search** with autocomplete
- **Cached Database** of all spells for lag-free searching
- **Fuzzy Matching**:
  - Prefix matches
  - Substring matches
  - Levenshtein-based fuzzy matching
- **Spell Details View**:
  - Spell ID
  - Spell name
  - Per-class availability
  - Level required per class
- **Non-Invasive**:
  - Lookup is informational only
  - Does not affect scanning or CSV exports

---

## Requirements

- Project Lazarus EverQuest EMU server
- MacroQuest MQNext (MQ2Mono)
- ImGui support enabled

---

## Installation

1. Copy `SpellExport.lua` into your MacroQuest `lua` directory
2. In-game, run:
