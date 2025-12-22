# SpellExport

[![Support](https://img.shields.io/badge/Support-Buy%20Me%20a%20Coffee-6f4e37)](https://buymeacoffee.com/shablagu)

A comprehensive spell, discipline, and ability auditing tool for the **Project Lazarus EverQuest EMU server**.

SpellExport identifies which abilities your character is missing within a configurable level range and provides a fast, non-invasive spell lookup tool for reference and planning.

---

## Overview

SpellExport was originally designed as a lightweight on-demand scanner.  
As of **v1.6.x**, it has been internally modernized while **preserving all v1.5.1 user-facing behavior**.

The tool now uses a **persistent spell cache** and explicit state management to dramatically improve performance, responsiveness, and long-term maintainability — without changing results or gameplay interaction.

---

## Features

### Missing Spell Scanner
- **Comprehensive Scanning**  
  Scans all spell IDs (default: 1–30000) to identify missing spells, disciplines, and abilities for your class

- **Level Filtering**  
  Configurable minimum and maximum level range

- **Ability Classification**  
  Internally distinguishes:
  - Spells  
  - Disciplines  
  - Abilities  
  - Hybrid abilities  

- **Flexible Output**
  - GUI display of missing spells
  - CSV export with timestamped filenames

- **Selective Filtering**
  - Option to hide spellbook spells and show only abilities / disciplines

- **Progress Tracking**
  - Real-time scan progress
  - ETA calculation

- **Persistent Settings**
  - All configuration options are automatically saved between sessions

- **Smart Output Paths**
  - MacroQuest Logs directory
  - MacroQuest root (script) directory
  - Custom user-defined path

---

### Spell Lookup Tool (v1.5+)
- **Instant Spell Search** with autocomplete
- **Cached Spell Database** for lag-free searching
- **Fuzzy Matching**
  - Prefix matches
  - Substring matches
  - Fuzzy (edit-distance–based) matching
- **Spell Details View**
  - Spell ID
  - Spell name
  - Per-class availability
  - Required level per class
- **Non-Invasive**
  - Lookup is informational only
  - Does not affect scanning or CSV exports

---

## Cache System (v1.6+)

SpellExport now maintains a **persistent on-disk spell cache** to avoid repeated live scanning.

### Key Points
- Cache is built once and reused across sessions
- Cache automatically resumes if interrupted
- Cache schema is versioned for forward compatibility
- Optional background cache building
- Cache can be safely rebuilt at any time

### Why This Matters
- Faster startup after first run
- Instant spell lookup
- Reduced MQ TLO usage
- More predictable performance on large scans

> **Important:**  
> The cache only stores spell metadata (IDs, names, class levels).  
> Character state is always evaluated live.

---

## Requirements

- Project Lazarus EverQuest EMU server
- MacroQuest MQNext (MQ2Mono)
- **ImGui support enabled**

> Note: ImGui must be present and loaded in your MQNext build.  
> SpellExport will not function without ImGui support.

---

## Installation

1. Copy `SpellExport.lua` into your MacroQuest `lua` directory
2. In-game, run:
