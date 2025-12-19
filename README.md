# SpellExport

[![Support](https://img.shields.io/badge/Support-Buy%20Me%20a%20Coffee-6f4e37)](https://buymeacoffee.com/shablagu)

A comprehensive spell and ability scanner for Project Lazarus (EverQuest EMU). SpellExport identifies all spells, disciplines, and abilities your character is missing within a configurable level range.

## Features

- **Comprehensive Scanning**: Scans all 30,000 spell IDs to find missing content
- **Level Filtering**: Set minimum and maximum level ranges to focus your search
- **Ability Classification**: Automatically distinguishes between spells, disciplines, and abilities
- **Flexible Output**: 
  - Real-time GUI display of results
  - CSV export with timestamp for external analysis
- **Configurable Filtering**: Option to hide regular spellbook spells and show only abilities/disciplines
- **Progress Tracking**: Real-time scan progress with ETA calculation
- **Persistent Settings**: All preferences saved automatically between sessions
- **Smart Output**: Choose between MacroQuest Logs folder or script directory

## Requirements

- Project Lazarus EverQuest EMU server
- MacroQuest MQNext (MQ2Mono)
- ImGui support

## Installation

1. Copy `SpellExport.lua` to your MacroQuest `lua` folder
2. In-game, run: `/lua run SpellExport`

## Usage

### Basic Workflow

1. Launch the script: `/lua run SpellExport`
2. Configure your level range using the Min/Max sliders
3. (Optional) Adjust output directory and display settings
4. Click **Find Missing Spells** to begin scanning
5. Results appear in the GUI and/or export to CSV automatically

### Configuration Options

**Output Directory**
- Manually enter a custom path, or
- Click **Use MQ Logs** for MacroQuest Logs folder
- Click **Use Script Dir** for MacroQuest root directory

**Level Range**
- **Min Level**: Lowest level spells to include (0 to your level)
- **Max Level**: Highest level spells to include (0 to your level)

**Display Options**
- **Display missing spells in GUI**: Show results in the window after scanning
- **Export missing spells to CSV**: Automatically export results when scan completes
- **Hide spellbook spells**: Filter out regular spells, showing only abilities and disciplines

### CSV Output

CSV files are named: `CharacterName_MissingSpells_YYYY-MM-DD_HHMM.csv`

Format:
```
ID,Name,Level
1234,"Spell Name",50
5678,"Another Spell",55
```

### Re-Exporting Results

After a scan completes, click **Re-Export CSV** to generate a new CSV file with the current results without re-scanning.

## Technical Details

### Architecture

- **Batch Processing**: Scans 150 spells per batch to maintain responsiveness
- **Safe TLO Usage**: EMU-compatible spell detection using multiple validation methods
- **Persistent Settings**: Stored in `SpellExport_settings.lua` in output directory
- **Fail-Safe I/O**: Graceful handling of missing files and malformed data

### Spell Detection

The scanner validates spells using multiple TLO queries:
- `Me.Book(name)` - Spellbook entries
- `Me.Book(id)` - Spellbook by ID
- `Me.Spell(id)` - Known spells
- `Me.Ability(name)` - Class abilities
- `Me.CombatAbility(name)` - Disciplines

### Performance

- Typical scan time: 2-5 minutes for all 30,000 spell IDs
- Progress updates every 1,000 spells processed
- Non-blocking batch processing prevents client freezing

## Settings File

Settings are automatically saved to `SpellExport_settings.lua`:
```lua
return {
 minLevel=1,
 maxLevel=60,
 showInGUI=true,
 exportCSV=true,
 hideSpellbook=false,
 outputDir="C:/Path/To/Output/",
}
```

## Tooltips

Hover over any button or checkbox for detailed explanations of functionality.

## Troubleshooting

**Script won't start**
- Ensure you're in-game (not at character select)
- Verify MacroQuest is loaded properly

**CSV file not created**
- Check output directory exists and is writable
- Verify path format uses forward slashes: `C:/Path/To/Folder/`

**Missing expected spells**
- Verify level range includes the spell's level
- Check if "Hide spellbook spells" filter is enabled
- Some spells may be learned automatically and not appear as "missing"

**Settings not saving**
- Ensure output directory is writable
- Check for file permission issues

# SpellExport Changelog

## [v1.4.0] - 2025-12-19

### Removed
- Removed ability type labels feature (non-functional in GUI display)
- Removed `showTypeLabels` checkbox and associated UI controls
- Removed type labels from GUI spell list display

### Notes
- Type classification still used internally for "Hide spellbook spells" filter
- GUI now displays clean format: `[ID] LvLevel - Name`

---

## [v1.3.0] - 2025-12-19

### Added
- Tooltips for all buttons and checkboxes
- Hover text explains functionality of each control

### Changed
- Improved user experience with contextual help text

---

## [v1.2.0] - 2025-12-19

### Removed
- Removed `Type` column from CSV export
- CSV now exports only: `ID,Name,Level`

### Notes
- Type classification preserved internally for filtering
- GUI display still supports type-based filtering

---

## [v1.1.0] - Initial Release

### Added
- Ability type classification (Spell / Discipline / Ability / Hybrid)
- Type column included in CSV export
- "Hide spellbook spells" filter
- Display type labels toggle
- Persistent settings across sessions

### Features
- Scan all spell IDs (1-30000) for missing spells and abilities
- Filter by level range (Min/Max)
- Real-time progress display with ETA calculation
- Configurable output directory (MQ Logs or Script Dir)
- CSV export with timestamp
- GUI display of missing spells
- Settings persistence in `SpellExport_settings.lua`

### Technical
- Deterministic batch scanning (150 spells per batch)
- Safe file I/O with error handling
- EMU-safe TLO usage
- Project Lazarus MQNext compatible
- ImGui interface with Lazarus-safe patterns

## Current Version

**v1.4.0** - 2025-12-19
- Removed non-functional ability type labels feature
- Streamlined GUI display
- Added comprehensive tooltips

## License

This script is provided as-is for use on Project Lazarus.

## Credits

Developed for the Project Lazarus community.
