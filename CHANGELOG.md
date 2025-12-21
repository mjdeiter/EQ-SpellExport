Changelog — SpellExport
Unreleased → v1.5.1
Major Additions

Added spell lookup system with live autocomplete search.

Implemented a persistent spell cache to eliminate lag from repeated TLO spell queries.

Cache builds incrementally in batches and can be triggered automatically or manually.

Lookup results include:

Spell ID

Spell name

Minimum usable level

Per-class availability and level requirements

Performance Improvements

Replaced repeated mq.TLO.Spell(id) lookup loops during search with a prebuilt cache.

Cache-based searching prevents UI stalls and input lag during typing.

Incremental cache building avoids long blocking operations.

UI Enhancements

Added a dedicated Spell Lookup section to the ImGui interface.

Visual cache status indicators:

Not built

Building (with percentage)

Ready (spell count shown)

Autocomplete dropdown with:

Prefix matches

Substring matches

Fuzzy matching (Levenshtein distance)

Clear button resets lookup state cleanly.

Behavioral Changes

Spell lookup is read-only and does not affect scanning or CSV export.

Cache automatically begins building on first lookup if not already initialized.

Lookup results are capped to prevent UI overload.

Internal Refactors

Introduced centralized spell cache structure storing:

ID

Name

Lowercase name for fast matching

Minimum class level

Added query de-duplication to avoid redundant searches when input hasn’t changed.

Clean separation between:

Spell scanning logic

Spell lookup logic

Cache building logic

No Changes To

Existing missing-spell scanning logic

CSV export format and behavior

Ability / discipline classification rules

Saved settings format

EMU-safe MacroQuest usage
