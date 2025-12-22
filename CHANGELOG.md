# Changelog — SpellExport

All notable changes to this project are documented in this file.  
SpellExport follows a **behavior-first versioning philosophy**: internal refactors do not change results unless explicitly stated.

---

## v1.6.x — Internal Modernization (Behavior-Preserving)

This release modernizes SpellExport’s internal architecture while **preserving all v1.5.1 user-facing behavior and results**.

### Architectural Improvements

- Introduced a **persistent, on-disk spell cache** reused across sessions
- Added an explicit cache state machine:
  - Idle
  - Building
  - Complete
  - Error
- Cache automatically resumes if interrupted
- Cache schema versioning added for forward compatibility
- Optional background cache building without blocking the UI

### Performance & Stability

- Spell lookup and missing-spell scanning now operate on cached metadata
- Eliminates repeated full spell-table traversal on every run
- Reduced MacroQuest TLO calls during UI rendering
- More predictable performance on large scans
- Improved ImGui lifecycle handling to prevent state corruption

### Settings & Persistence

- All UI options now persist reliably between sessions:
  - Level filters
  - Output directory selection
  - Hide spellbook spells toggle
  - Background cache build toggle
- Safe load/save logic retained to avoid breaking existing configs

### New Operational Features

- Cache statistics and progress reporting
- Manual cache rebuild / reset options
- Explicit cache status indicators
- Background cache build toggle
- Slash-command support for common actions (where supported)

### No Changes To

- Missing-spell scan results
- Spell classification rules (spell / discipline / ability / hybrid)
- `isKnown()` logic
- CSV export format and behavior
- EMU-safe MacroQuest usage patterns
- SpellExport v1.5.1 user workflow

---

## v1.5.1 — Feature Expansion & Lookup System

### Major Additions

- Added spell lookup system with live autocomplete search
- Implemented a persistent spell cache to eliminate lag from repeated TLO spell queries
- Cache builds incrementally in batches and can be triggered automatically or manually

Lookup results include:
- Spell ID
- Spell name
- Minimum usable level
- Per-class availability and level requirements

### Performance Improvements

- Replaced repeated `mq.TLO.Spell(id)` lookup loops during search with a prebuilt cache
- Cache-based searching prevents UI stalls and input lag during typing
- Incremental cache building avoids long blocking operations

### UI Enhancements

- Added a dedicated Spell Lookup section to the ImGui interface
- Visual cache status indicators:
  - Not built
  - Building (with percentage)
  - Ready (spell count shown)
- Autocomplete dropdown with:
  - Prefix matches
  - Substring matches
  - Fuzzy matching (Levenshtein distance)
- Clear button resets lookup state cleanly

### Behavioral Changes

- Spell lookup is read-only and does not affect scanning or CSV export
- Cache automatically begins building on first lookup if not already initialized
- Lookup results are capped to prevent UI overload

### Internal Refactors

- Introduced centralized spell cache structure storing:
  - ID
  - Name
  - Lowercase name for fast matching
  - Minimum class level
- Added query de-duplication to avoid redundant searches when input hasn’t changed
- Clean separation between:
  - Spell scanning logic
  - Spell lookup logic
  - Cache building logic

### No Changes To

- Existing missing-spell scanning logic
- CSV export format and behavior
- Ability / discipline classification rules
- Saved settings format
- EMU-safe MacroQuest usage

---
