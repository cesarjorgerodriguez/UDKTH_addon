# Unholy Death Knight Target Helper - Changelog

## [1.0.2] - 2026-03-14

### Changed
- **Enemy Detection System (rewritten)**
  - Replaced per-tick nameplate loop with event-driven table (`NAME_PLATE_UNIT_ADDED/REMOVED`)
  - Real mode also counts enemies with threat (`UnitThreatSituation ~= nil`), not just in-combat ones
  - Current target is always counted even without a visible nameplate
  - Added `UNIT_FLAGS` handler to drop mobs that turn friendly (e.g. Mind Control)

### Fixed
- **WoW 12.0.1 (Midnight) compatibility**
  - Removed `COMBAT_LOG_EVENT_UNFILTERED` — blocked by `ADDON_ACTION_FORBIDDEN`
  - Removed `bit.band()` — deprecated in 12.0.1
  - Replaced `UnitHealth() <= 1` and `UnitThreatSituation() >= 0` comparisons — these return secret numbers that cause taint

---

## [1.0.1] - 2026-03-13

### Added
- **Localization System**
  - Full English translation support
  - Automatic language detection based on WoW client locale
  - Supports English (enUS, enGB) and Spanish (esES, esMX)
  - All UI elements, messages, and options are now localized

### Changed
- Updated TOC version to 1.0.1
- Improved Notes field in TOC to show dual language support

---

## [1.0.0] - 2026-03-12

### Initial Release
- **Core Functionality**
  - Automatic spell suggestion for Unholy Death Knights
  - Displays Death Coil icon for 1-3 targets
  - Displays Epidemic icon for 4+ targets
  - Smart enemy detection using nameplates, threat, and combat status

- **Army of the Dead Integration**
  - Detects Army of the Dead buff
  - Suggests Necrotic Coil for 4+ targets when Army is active
  - Suggests Graveyard for 5+ targets when Army is active

- **Combat Features**
  - Automatically shows/hides icon when entering/leaving combat
  - Real-time enemy count display
  - Spell name displayed below icon
  - Updates every 0.15 seconds for responsive feedback

- **Customization Options**
  - Drag and drop positioning (saved between sessions)
  - Adjustable icon size (32-128 pixels in 8px increments)
  - Icon transparency control (10-100% in 10% steps)
  - Toggle text labels on/off
  - All settings persist across game sessions

- **User Interface**
  - In-game options panel accessible via `/aoedk`
  - Unlock/lock mode for easy repositioning
  - Clean, minimal design that doesn't clutter your screen

- **Detection Modes**
  - Real mode: Counts only enemies in combat or with threat (default)
  - Dummy mode: Counts all enemy nameplates (for testing)

- **Slash Commands**
  - `/aoedk` - Open options panel
  - `/aoedk unlock` - Unlock icon for repositioning
  - `/aoedk lock` - Lock icon in place
  - `/aoedk reset` - Reset position to default
  - `/aoedk test` - Toggle test mode (shows icon without combat checks)
  - `/aoedk debug` - Display debug information
  - `/aoedk mode [real|dummy]` - Switch detection mode
  - `/aoedk auras` - List active player auras

### Technical Details
- Compatible with WoW Interface 12.0.0.1 (The War Within)
- SavedVariables stored in AoeDKDB
- Optimized performance with efficient update intervals
- Clean event-driven architecture
