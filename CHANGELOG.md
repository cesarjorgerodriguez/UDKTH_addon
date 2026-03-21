# Unholy Death Knight Target Helper - Changelog

## [1.1.0] - 2026-03-21

### Added
- **Configurable Epidemic threshold**
  - New options panel section: ± buttons to set the enemy breakpoint for Epidemic (range 2–6, default 4)
  - Army of the Dead breakpoints (Epidemic / Necrotic Coil / Graveyard) scale relative to the configured threshold
  - Setting persists across sessions via `AoeDKDB.epidemicThreshold`
  - Localized label: English `"Epidemic threshold"` / Spanish `"Umbral de Epidemia"`
- **Combat fade animations**
  - Fade-in (0.3s) when entering combat (`PLAYER_REGEN_DISABLED`)
  - Fade-out (0.4s) when leaving combat (`PLAYER_REGEN_ENABLED`); frame hidden only after fade completes
  - Re-entering combat mid-fade cancels the hide gracefully
- **Icon tooltip**
  - Hovering the icon shows the suggested spell name (or drag hint when unlocked)
  - Works in both locked and unlocked states

### Fixed
- **Variable scoping bug** — `currentSpellID`, `forceShow` and `detectionMode` were declared after `ShowAnchor`/`HideAnchor`, causing those functions to read/write a different global instead of the intended local. Declarations moved before both functions.
- **Reset wiped all settings** — `/aoedk reset` and the Reset button now only clear position fields (`point`, `relPoint`, `x`, `y`); icon size, alpha, text visibility and detection mode are preserved.
- **`detectionMode` not persisted** — Mode is now saved to `AoeDKDB.detectionMode` on every change and restored on `ADDON_LOADED`.
- **Drag guard** — `OnDragStart` now checks `isUnlocked` before calling `StartMoving`; the frame can no longer be accidentally dragged while locked.
- **`frame:EnableMouse(false)` after lock removed** — Mouse input stays enabled at all times so the tooltip works regardless of lock state. Dragging is gated by the `isUnlocked` check instead.
- **`/aoedk auras` iteration** — Replaced hardcoded `for i = 1, 40` loops with `AuraUtil.ForEachAura()` to correctly iterate all auras without an arbitrary cap.
- **Redundant `AoeDKDB = AoeDKDB or {}`** — Removed ~10 duplicate guards from button callbacks and `OnDragStop`; `AoeDKDB` is guaranteed to be initialized by `ADDON_LOADED` before any interaction is possible.

### Performance
- **`UNIT_AURA` scope** — Changed from `RegisterEvent` to `RegisterUnitEvent("UNIT_AURA", "player")`. The event no longer fires for every unit in range, only for the player's own auras.
- **Class/spec cache** — `UnitClass("player")` and `GetSpecialization()` results are cached in `cachedClassID`/`cachedSpecIndex` and refreshed only on `PLAYER_SPECIALIZATION_CHANGED` and `PLAYER_ENTERING_WORLD`. `UpdateIcon()` no longer calls these APIs on every tick.
- **`UnitExists("target")` deduplicated** — Called once at the top of `GetEnemyCount()` and reused via a local `hasTarget` variable instead of three separate calls.
- **Options panel height** — Increased from 310 to 360 px to accommodate the new threshold controls.

---

## [1.0.2] - 2026-03-14

### Changed
- **Enemy Detection System (rewritten)**
  - Replaced `for i = 1, 40` nameplate loop with an event-driven system (`NAME_PLATE_UNIT_ADDED/REMOVED`)
  - Only active nameplates are stored at any given time, removing unnecessary iterations
  - Current target is always counted even without a visible nameplate
  - Added `UNIT_FLAGS` handler to drop mobs that turn friendly (e.g. Mind Control)
  - Registered `PLAYER_TARGET_CHANGED` to update the icon immediately on target switch
  - Real mode: fixed threat check to `~= nil` (previously `>= 0` caused taint)

### Fixed
- **Instance compatibility in WoW 12.0.1**
  - Removed all `UnitGUID()` usage — returns tainted/secret values for nameplate units inside instances
  - Replaced GUID-based deduplication (`counted[guid]`) with `UnitIsUnit()` for target matching
  - `npGUIDs`/`npUnits` tables replaced by `npActive[unit] = true` (no secret values as table keys)

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
