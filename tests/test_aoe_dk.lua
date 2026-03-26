---------------------------------------------------------------------------
-- test_aoe_dk.lua — Offline test suite for AoE DK addon
--
-- Run:  lua tests/test_aoe_dk.lua          (from the addon root directory)
-- Requires Lua 5.1+ or LuaJIT
---------------------------------------------------------------------------

-- ── Boilerplate ─────────────────────────────────────────────────────────
local root = "."  -- run from addon root

-- Load the WoW API mock first (populates _G)
package.path = root .. "/tests/?.lua;" .. root .. "/?.lua;" .. package.path
dofile(root .. "/tests/wow_api_mock.lua")

-- ── Mini test framework ────────────────────────────────────────────────
local passed, failed, total = 0, 0, 0
local currentSuite = ""

local function suite(name)
    currentSuite = name
    io.write("\n=== " .. name .. " ===\n")
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        io.write("  [PASS]  " .. name .. "\n")
    else
        failed = failed + 1
        io.write("  [FAIL]  " .. name .. "\n")
        io.write("          " .. tostring(err) .. "\n")
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "") .. " expected: " .. tostring(expected) .. ", got: " .. tostring(actual), 2)
    end
end

local function assertTrue(val, msg)
    if not val then error((msg or "assertion failed") .. " (got falsy)", 2) end
end

local function assertFalse(val, msg)
    if val then error((msg or "assertion failed") .. " (got truthy)", 2) end
end

-- ── Load addon source files in TOC order ───────────────────────────────
-- We simulate the `...` vararg that WoW passes: (addonName, namespace)
--
-- Because each file uses `local _, ns = ...`, we wrap dofile in a function
-- that sets the vararg via a loader.

local ns = {}   -- shared namespace
local addonName = "aoe_dk"

local function loadAddonFile(path)
    local fullPath = root .. "/" .. path
    -- Lua 5.1 uses loadfile + setfenv; Lua 5.2+ uses load with env argument.
    -- We simply load & call with vararg since the files only use `local _, ns = ...`
    -- and all WoW API is in _G already.
    local fn, err = loadfile(fullPath)
    if not fn then error("Failed to load " .. path .. ": " .. err) end
    fn(addonName, ns)
end

-- (DON'T load aoe_dk.lua directly — it creates frames and registers events.
-- Instead we extract only the pure logic we need for testing.)

-- Load Config (populates ns with IDs and defaults)
loadAddonFile("Locales.lua")
loadAddonFile("Config.lua")

-- ── Expose the pure decision logic extracted from aoe_dk.lua ───────────
-- We re-implement the testable functions using the exact same algorithm as
-- the addon source, reading from the same ns.* constants and AoeDKDB.

local DEATH_COIL_ID    = ns.DEATH_COIL_ID
local EPIDEMIC_ID      = ns.EPIDEMIC_ID
local NECROTIC_COIL_ID = ns.NECROTIC_COIL_ID
local GRAVEYARD_ID     = ns.GRAVEYARD_ID
local FORBIDDEN_KNOWLEDGE_ID = ns.FORBIDDEN_KNOWLEDGE_ID
local RIDER_CHECK_ID   = ns.RIDER_CHECK_ID
local SANLAYN_CHECK_ID = ns.SANLAYN_CHECK_ID
local HERO_THRESHOLD_MODIFIER = ns.HERO_THRESHOLD_MODIFIER

-- Mirror of IsValidEnemy from aoe_dk.lua
local function IsValidEnemy(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

-- Mirror of IsDummyContext from aoe_dk.lua
-- Returns true when player is not in real combat and has at least one valid
-- enemy nameplate visible (Training Dummy signature).
local function IsDummyContext(npActive)
    if UnitAffectingCombat("player") then return false end
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            return true
        end
    end
    return false
end

-- Mirror of GetEnemyCount from aoe_dk.lua
-- npActive is passed in so tests can control it; forceShow as param.
-- Detection is automatic: dummy context when player is not in combat and
-- visible nameplates are not in combat/no threat (Training Dummy signature).
local function GetEnemyCount(npActive, forceShow)
    local isDummy = IsDummyContext(npActive) or forceShow
    local count = 0
    local targetCounted = false
    local hasTarget = UnitExists("target")

    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if isDummy then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            else
                local inCbt = UnitAffectingCombat(unit)
                local threat = UnitThreatSituation("player", unit)
                if inCbt or (threat ~= nil) then
                    count = count + 1
                    if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                        targetCounted = true
                    end
                end
            end
        end
    end

    if not targetCounted and hasTarget and IsValidEnemy("target") then
        if isDummy then
            count = count + 1
        else
            local inCbt = UnitAffectingCombat("target")
            local threat = UnitThreatSituation("player", "target")
            if inCbt or (threat ~= nil) then
                count = count + 1
            end
        end
    end

    return count
end

-- Mirror of IsForbiddenKnowledgeActive
-- Returns true when buff 1242223 is present = Forbidden Knowledge / Army active.
local function IsForbiddenKnowledgeActive()
    return C_UnitAuras.GetPlayerAuraBySpellID(FORBIDDEN_KNOWLEDGE_ID) ~= nil
end

-- Mirror of RefreshClassSpec
local function RefreshClassSpec()
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    local heroTalent
    if IsPlayerSpell(RIDER_CHECK_ID) then
        heroTalent = "rider"
    elseif IsPlayerSpell(SANLAYN_CHECK_ID) then
        heroTalent = "sanlayn"
    else
        heroTalent = nil
    end
    return classID, specIndex, heroTalent
end

-- Mirror of the spell selection logic inside UpdateIcon
-- Returns: spellID or nil (nil = frame would be hidden)
-- fkActive = true when Forbidden Knowledge buff (1242223) is detected.
-- This means Army is up; unlocks the 4-level rotation using FK threshold.
-- heroTalent = "rider", "sanlayn", or nil (applies threshold modifier)
local function SelectSpell(enemyCount, fkActive, db, heroTalent)
    if enemyCount == 0 then return nil end

    -- Calcular threshold base + modificador de hero talent
    local baseThreshold = fkActive and db.epidemicThresholdFK or db.epidemicThreshold
    local heroMod = (heroTalent and HERO_THRESHOLD_MODIFIER[heroTalent]) or 0
    local threshold = math.max(1, baseThreshold + heroMod)

    if fkActive then
        -- Con Forbidden Knowledge (Army activo): cuatro niveles
        if enemyCount >= (threshold + 1) then
            return GRAVEYARD_ID
        elseif enemyCount >= threshold then
            return NECROTIC_COIL_ID
        elseif enemyCount >= (threshold - 1) then
            return EPIDEMIC_ID
        else
            return DEATH_COIL_ID
        end
    else
        -- Sin Forbidden Knowledge: solo Death Coil o Epidemic
        if enemyCount >= threshold then
            return EPIDEMIC_ID
        else
            return DEATH_COIL_ID
        end
    end
end

-- Mirror of ApplyIconAlpha rounding logic
local function NormalizeAlpha(alpha)
    alpha = math.max(0.1, math.min(1.0, alpha))
    return math.floor(alpha * 10 + 0.5) / 10
end

-- ── Helpers ────────────────────────────────────────────────────────────
-- Build npActive table from mock nameplates
local function BuildNpActive()
    local npa = {}
    -- Simulates NAME_PLATE_UNIT_ADDED filtering: only non-friend units
    for unit, _ in pairs(Mock._getNameplates and Mock._getNameplates() or {}) do
        if not UnitIsFriend("player", unit) then
            npa[unit] = true
        end
    end
    return npa
end

-- Convenience: add N identical enemy nameplates
local function AddEnemies(n, opts)
    opts = opts or {}
    local npa = {}
    for i = 1, n do
        local uid = "nameplate" .. i
        Mock.AddNameplate(uid, {
            dead      = opts.dead or false,
            canAttack = opts.canAttack ~= false,
            friend    = false,
            inCombat  = opts.inCombat ~= false,
            threat    = opts.threat,
            name      = "Mob" .. i,
        })
        npa[uid] = true
    end
    return npa
end

local defaultDB = { epidemicThreshold = 3, epidemicThresholdFK = 6 }

-- ════════════════════════════════════════════════════════════════════════
-- TEST SUITES
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Config / defaults ───────────────────────────────────────────────
suite("Config & Defaults")

test("Spell IDs are defined", function()
    assertTrue(ns.DEATH_COIL_ID, "DEATH_COIL_ID")
    assertTrue(ns.EPIDEMIC_ID, "EPIDEMIC_ID")
    assertTrue(ns.NECROTIC_COIL_ID, "NECROTIC_COIL_ID")
    assertTrue(ns.GRAVEYARD_ID, "GRAVEYARD_ID")
end)

test("Default thresholds", function()
    assertEqual(ns.defaults.epidemicThreshold, 3)
    assertEqual(ns.defaults.epidemicThresholdFK, 6)
end)

test("FORBIDDEN_KNOWLEDGE_ID is defined and correct", function()
    assertTrue(ns.FORBIDDEN_KNOWLEDGE_ID ~= nil)
    assertEqual(ns.FORBIDDEN_KNOWLEDGE_ID, 1242223)
end)

-- ── 2. Spell selection — No FK ────────────────────────────────────────
suite("Spell Selection — No FK (base threshold 3)")

test("0 enemies → nil (hide)", function()
    assertEqual(SelectSpell(0, false, defaultDB), nil)
end)

test("1 enemy → Death Coil", function()
    assertEqual(SelectSpell(1, false, defaultDB), DEATH_COIL_ID)
end)

test("2 enemies → Death Coil (below threshold 3)", function()
    assertEqual(SelectSpell(2, false, defaultDB), DEATH_COIL_ID)
end)

test("3 enemies → Epidemic (= threshold)", function()
    assertEqual(SelectSpell(3, false, defaultDB), EPIDEMIC_ID)
end)

test("5 enemies → Epidemic", function()
    assertEqual(SelectSpell(5, false, defaultDB), EPIDEMIC_ID)
end)

test("10 enemies → Epidemic", function()
    assertEqual(SelectSpell(10, false, defaultDB), EPIDEMIC_ID)
end)

-- ── 3. Spell selection — FK/Army active (FK threshold=6) ─────────────
suite("Spell Selection — FK/Army Active (FK threshold=6)")

test("4 enemies + FK → Death Coil (below threshold-1=5)", function()
    assertEqual(SelectSpell(4, true, defaultDB), DEATH_COIL_ID)
end)

test("5 enemies + FK → Epidemic (= threshold-1)", function()
    assertEqual(SelectSpell(5, true, defaultDB), EPIDEMIC_ID)
end)

test("6 enemies + FK → Necrotic Coil (= threshold)", function()
    assertEqual(SelectSpell(6, true, defaultDB), NECROTIC_COIL_ID)
end)

test("7 enemies + FK → Graveyard (= threshold+1)", function()
    assertEqual(SelectSpell(7, true, defaultDB), GRAVEYARD_ID)
end)

test("10 enemies + FK → Graveyard", function()
    assertEqual(SelectSpell(10, true, defaultDB), GRAVEYARD_ID)
end)

-- ── 4. Custom thresholds ──────────────────────────────────────────────
suite("Custom Thresholds")

test("threshold=5 → 4 enemies = Death Coil", function()
    assertEqual(SelectSpell(4, false, { epidemicThreshold = 5, epidemicThresholdFK = 8 }), DEATH_COIL_ID)
end)

test("threshold=5 → 5 enemies = Epidemic", function()
    assertEqual(SelectSpell(5, false, { epidemicThreshold = 5, epidemicThresholdFK = 8 }), EPIDEMIC_ID)
end)

test("threshold=2 (minimum) → 1 enemy = Death Coil", function()
    assertEqual(SelectSpell(1, false, { epidemicThreshold = 2, epidemicThresholdFK = 2 }), DEATH_COIL_ID)
end)

test("threshold=2 → 2 enemies = Epidemic", function()
    assertEqual(SelectSpell(2, false, { epidemicThreshold = 2, epidemicThresholdFK = 2 }), EPIDEMIC_ID)
end)

test("FK + threshold FK=2 → 1 enemy = Epidemic (threshold-1=1)", function()
    assertEqual(SelectSpell(1, true, { epidemicThreshold = 3, epidemicThresholdFK = 2 }), EPIDEMIC_ID)
end)

test("FK + threshold FK=2 → 2 enemies = Necrotic Coil (= threshold)", function()
    assertEqual(SelectSpell(2, true, { epidemicThreshold = 3, epidemicThresholdFK = 2 }), NECROTIC_COIL_ID)
end)

test("FK + threshold FK=2 → 3 enemies = Graveyard (threshold+1)", function()
    assertEqual(SelectSpell(3, true, { epidemicThreshold = 3, epidemicThresholdFK = 2 }), GRAVEYARD_ID)
end)

test("FK threshold=8 → 6 enemies = Death Coil (below 7=thresh-1)", function()
    assertEqual(SelectSpell(6, true, { epidemicThreshold = 3, epidemicThresholdFK = 8 }), DEATH_COIL_ID)
end)

-- ── 7. Enemy counting — Auto mode (real context) ────────────────────
suite("Enemy Count — Real Mode")

test("No nameplates, no target → 0", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = {}
    assertEqual(GetEnemyCount(npa, false), 0)
end)

test("3 enemy nameplates in combat → 3", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    assertEqual(GetEnemyCount(npa, false), 3)
end)

test("3 enemies, 1 dead → 2", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.AddNameplate("nameplate3", { dead = true, inCombat = true, threat = 1 })
    npa["nameplate3"] = true
    assertEqual(GetEnemyCount(npa, false), 2)
end)

test("3 enemies, 1 not in combat and no threat → 2", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.AddNameplate("nameplate3", { inCombat = false, threat = nil })
    npa["nameplate3"] = true
    assertEqual(GetEnemyCount(npa, false), 2)
end)

test("Enemy with threat but not in combat → counted", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddNameplate("nameplate1", { inCombat = false, threat = 0 })
    local npa = { nameplate1 = true }
    assertEqual(GetEnemyCount(npa, false), 1)
end)

-- ── 8. Enemy counting — Auto mode (dummy context) ───────────────────
suite("Enemy Count — Dummy Mode")

test("5 enemies, none in combat → 5 (auto detects dummy context)", function()
    Mock.Reset()
    Mock.SetInCombat(false)   -- player not in combat → dummy context detected
    Mock.ClearTarget()
    local npa = AddEnemies(5, { inCombat = false, threat = nil })
    assertEqual(GetEnemyCount(npa, false), 5)
end)

-- ── 9. Enemy counting — Target deduplication ────────────────────────
suite("Enemy Count — Target Deduplication")

test("Target already in nameplates → not double-counted", function()
    Mock.Reset()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = "nameplate2" })
    assertEqual(GetEnemyCount(npa, false), 3)
end)

test("Target NOT in nameplates → added as +1", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = nil })
    assertEqual(GetEnemyCount(npa, false), 3)
end)

test("Target not in combat (real mode) → not added", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = false, threat = nil, unit = nil })
    assertEqual(GetEnemyCount(npa, false), 2)
end)

test("Target not in combat (dummy context) → added", function()
    Mock.Reset()
    Mock.SetInCombat(false)   -- player not in combat → auto dummy context
    local npa = AddEnemies(2, { inCombat = false, threat = nil })
    Mock.SetTarget({ exists = true, inCombat = false, threat = nil, unit = nil })
    assertEqual(GetEnemyCount(npa, false), 3)
end)

test("forceShow=true counts like dummy mode", function()
    Mock.Reset()
    local npa = AddEnemies(3, { inCombat = false, threat = nil })
    Mock.ClearTarget()
    assertEqual(GetEnemyCount(npa, true), 3)
end)

-- ── 10. Class/Spec detection ──────────────────────────────────────────
suite("Class & Spec Detection")

test("DK Unholy → classID=6, spec=3", function()
    Mock.Reset()
    Mock.SetClassSpec(6, 3)
    local classID, spec, _ = RefreshClassSpec()
    assertEqual(classID, 6)
    assertEqual(spec, 3)
end)

test("Non-DK → classID != 6", function()
    Mock.Reset()
    Mock.SetClassSpec(1, 1)  -- Warrior
    local classID, _, _ = RefreshClassSpec()
    assertTrue(classID ~= 6)
end)

test("DK but not Unholy → spec != 3", function()
    Mock.Reset()
    Mock.SetClassSpec(6, 1)  -- Blood
    local _, spec, _ = RefreshClassSpec()
    assertTrue(spec ~= 3)
end)

-- ── 11. Hero talent detection ─────────────────────────────────────────
suite("Hero Talent Detection")

test("No hero talent known → nil", function()
    Mock.Reset()
    local _, _, hero = RefreshClassSpec()
    assertEqual(hero, nil)
end)

test("Rider of the Apocalypse → 'rider'", function()
    Mock.Reset()
    Mock.LearnSpell(RIDER_CHECK_ID)
    local _, _, hero = RefreshClassSpec()
    assertEqual(hero, "rider")
end)

test("San'layn → 'sanlayn'", function()
    Mock.Reset()
    Mock.LearnSpell(SANLAYN_CHECK_ID)
    local _, _, hero = RefreshClassSpec()
    assertEqual(hero, "sanlayn")
end)

test("Both spells learned → Rider takes priority", function()
    Mock.Reset()
    Mock.LearnSpell(RIDER_CHECK_ID)
    Mock.LearnSpell(SANLAYN_CHECK_ID)
    local _, _, hero = RefreshClassSpec()
    assertEqual(hero, "rider")
end)

-- ── 12. Aura helpers ──────────────────────────────────────────────────
suite("Aura Helpers")

test("FK not active → false", function()
    Mock.Reset()
    assertFalse(IsForbiddenKnowledgeActive())
end)

test("FK active → true", function()
    Mock.Reset()
    Mock.AddPlayerAura(FORBIDDEN_KNOWLEDGE_ID, "Forbidden Knowledge / Army")
    assertTrue(IsForbiddenKnowledgeActive())
end)

-- ── 13. ApplyIconAlpha normalization ─────────────────────────────────
suite("Alpha Normalization")

test("0.35 rounds to 0.4", function()
    assertEqual(NormalizeAlpha(0.35), 0.4)
end)

test("0.0 clamps to 0.1", function()
    assertEqual(NormalizeAlpha(0.0), 0.1)
end)

test("1.5 clamps to 1.0", function()
    assertEqual(NormalizeAlpha(1.5), 1.0)
end)

test("0.75 rounds to 0.8", function()
    assertEqual(NormalizeAlpha(0.75), 0.8)
end)

test("0.1 stays 0.1", function()
    assertEqual(NormalizeAlpha(0.1), 0.1)
end)

-- ── 14. Edge cases & regressions ─────────────────────────────────────
suite("Edge Cases")

test("FK: 0 enemies still nil", function()
    assertEqual(SelectSpell(0, true, { epidemicThreshold = 2, epidemicThresholdFK = 2 }), nil)
end)

test("Boundary: exactly at each FK breakpoint (FK threshold=4)", function()
    local db = { epidemicThreshold = 3, epidemicThresholdFK = 4 }
    assertEqual(SelectSpell(2, true, db), DEATH_COIL_ID,    "2 < threshold-1=3")
    assertEqual(SelectSpell(3, true, db), EPIDEMIC_ID,      "3 = threshold-1")
    assertEqual(SelectSpell(4, true, db), NECROTIC_COIL_ID, "4 = threshold")
    assertEqual(SelectSpell(5, true, db), GRAVEYARD_ID,     "5 = threshold+1")
end)

test("Massive pull: 30 enemies + FK", function()
    assertEqual(SelectSpell(30, true, defaultDB), GRAVEYARD_ID)
end)

test("All nameplates dead → 0 enemies", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddNameplate("nameplate1", { dead = true, inCombat = true })
    Mock.AddNameplate("nameplate2", { dead = true, inCombat = true })
    local npa = { nameplate1 = true, nameplate2 = true }
    assertEqual(GetEnemyCount(npa, false), 0)
end)

test("Only target, no nameplates, in combat → 1", function()
    Mock.Reset()
    Mock.ClearNameplates()
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1 })
    assertEqual(GetEnemyCount({}, false), 1)
end)

test("Friendly nameplate filtered out", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddNameplate("nameplate1", { friend = true, inCombat = true, threat = 1 })
    -- Friendly units have canAttack = false in IsValidEnemy
    Mock.AddNameplate("nameplate1", { friend = true, canAttack = false, inCombat = true })
    local npa = { nameplate1 = true }
    assertEqual(GetEnemyCount(npa, false), 0)
end)

-- ── 15. Integration: full flow enemy → spell ──────────────────────────
suite("Integration: Enemies → Spell Selection")

test("2 real enemies + target (dedup) → Death Coil (2 < threshold 3)", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = "nameplate1" })
    local count = GetEnemyCount(npa, false)
    local spell = SelectSpell(count, false, defaultDB)
    assertEqual(count, 2)
    assertEqual(spell, DEATH_COIL_ID)
end)

test("3 real enemies → Epidemic", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, false)
    local spell = SelectSpell(count, false, defaultDB)
    assertEqual(count, 3)
    assertEqual(spell, EPIDEMIC_ID)
end)

test("4 enemies, no FK → Epidemic (4 >= base threshold 3)", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(4, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, false)
    local fk = IsForbiddenKnowledgeActive()
    local spell = SelectSpell(count, fk, defaultDB)
    assertEqual(count, 4)
    assertFalse(fk)
    assertEqual(spell, EPIDEMIC_ID)
end)

test("4 enemies + FK → Death Coil (4 < FK threshold-1=5)", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddPlayerAura(FORBIDDEN_KNOWLEDGE_ID, "Forbidden Knowledge")
    local npa = AddEnemies(4, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, false)
    local fk = IsForbiddenKnowledgeActive()
    local spell = SelectSpell(count, fk, defaultDB)
    assertEqual(count, 4)
    assertTrue(fk)
    assertEqual(spell, DEATH_COIL_ID)
end)

test("7 enemies + FK → Graveyard (7 >= FK threshold+1=7)", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddPlayerAura(FORBIDDEN_KNOWLEDGE_ID, "Forbidden Knowledge")
    local npa = AddEnemies(7, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, false)
    local fk = IsForbiddenKnowledgeActive()
    local spell = SelectSpell(count, fk, defaultDB)
    assertEqual(count, 7)
    assertTrue(fk)
    assertEqual(spell, GRAVEYARD_ID)
end)

-- ════════════════════════════════════════════════════════════════════════
-- Hero Talent Threshold Modifiers
-- ════════════════════════════════════════════════════════════════════════
suite("Hero Talent: Rider of the Apocalypse (modifier -1)")
test("Rider, no FK: 1 enemy → Death Coil", function()
    assertEqual(SelectSpell(1, false, defaultDB, "rider"), DEATH_COIL_ID)
end)
test("Rider, no FK: 2 enemies → Epidemic (base 3 → 2 with modifier)", function()
    assertEqual(SelectSpell(2, false, defaultDB, "rider"), EPIDEMIC_ID)
end)
test("Rider, no FK: 3 enemies → Epidemic", function()
    assertEqual(SelectSpell(3, false, defaultDB, "rider"), EPIDEMIC_ID)
end)
test("Rider, FK: 3 enemies → Death Coil (threshold-1=4, so 3 < 4)", function()
    -- Base FK threshold=6, rider modifier=-1 → effective=5
    -- threshold-1=4, so 3 → Death Coil
    assertEqual(SelectSpell(3, true, defaultDB, "rider"), DEATH_COIL_ID)
end)
test("Rider, FK: 4 enemies → Epidemic (threshold-1=4)", function()
    assertEqual(SelectSpell(4, true, defaultDB, "rider"), EPIDEMIC_ID)
end)
test("Rider, FK: 5 enemies → Necrotic Coil (threshold=5)", function()
    assertEqual(SelectSpell(5, true, defaultDB, "rider"), NECROTIC_COIL_ID)
end)
test("Rider, FK: 6 enemies → Graveyard (threshold+1=6)", function()
    assertEqual(SelectSpell(6, true, defaultDB, "rider"), GRAVEYARD_ID)
end)

suite("Hero Talent: San'layn (modifier 0 / no change)")
test("San'layn, no FK: 2 enemies → Death Coil (same as no hero talent)", function()
    assertEqual(SelectSpell(2, false, defaultDB, "sanlayn"), DEATH_COIL_ID)
end)
test("San'layn, no FK: 3 enemies → Epidemic (threshold=3)", function()
    assertEqual(SelectSpell(3, false, defaultDB, "sanlayn"), EPIDEMIC_ID)
end)
test("San'layn, FK: 5 enemies → Epidemic (threshold-1=5, FK threshold=6)", function()
    assertEqual(SelectSpell(5, true, defaultDB, "sanlayn"), EPIDEMIC_ID)
end)
test("San'layn, FK: 6 enemies → Necrotic Coil (threshold=6)", function()
    assertEqual(SelectSpell(6, true, defaultDB, "sanlayn"), NECROTIC_COIL_ID)
end)
test("San'layn, FK: 7 enemies → Graveyard (threshold+1=7)", function()
    assertEqual(SelectSpell(7, true, defaultDB, "sanlayn"), GRAVEYARD_ID)
end)

suite("Hero Talent: Unknown/nil (no modifier)")
test("nil hero talent: 2 enemies → Death Coil (base threshold=3)", function()
    assertEqual(SelectSpell(2, false, defaultDB, nil), DEATH_COIL_ID)
end)
test("nil hero talent: 3 enemies → Epidemic", function()
    assertEqual(SelectSpell(3, false, defaultDB, nil), EPIDEMIC_ID)
end)

-- ════════════════════════════════════════════════════════════════════════
-- Options Panel: Animation & UI Scale
-- ════════════════════════════════════════════════════════════════════════

-- Initialize AoeDKDB with defaults so Options.lua can reference it
AoeDKDB = {}
for k, v in pairs(ns.defaults) do AoeDKDB[k] = v end

-- Expose ns functions that Options.lua expects (normally set by aoe_dk.lua)
ns.IsUnlocked      = function() return false end
ns.ShowAnchor       = function() end
ns.HideAnchor       = function() end
ns.ApplyIconSize    = function(s) AoeDKDB.iconSize = s end
ns.ApplyIconAlpha   = function(a) AoeDKDB.iconAlpha = a end
ns.ApplyBorderSize  = function(s) AoeDKDB.borderSize = s end
ns.ResetCurrentSpell = function() end
ns.ResetPosition    = function() end
ns.frame            = CreateFrame()
ns.icon             = ns.frame:CreateTexture()
ns.countText        = ns.frame:CreateFontString()
ns.spellText        = ns.frame:CreateFontString()

-- Load Options.lua (creates the panel, sections, etc.)
loadAddonFile("Options.lua")

-- ── 16. Ease-out cubic function ────────────────────────────────────────
suite("Animation: Ease-out Cubic Math")

-- The addon uses: p = 1 - (1-p)*(1-p)*(1-p)
local function easeOutCubic(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

test("easeOutCubic(0) = 0 (start)", function()
    assertEqual(easeOutCubic(0), 0)
end)

test("easeOutCubic(1) = 1 (end)", function()
    assertEqual(easeOutCubic(1), 1)
end)

test("easeOutCubic(0.5) = 0.875 (fast start)", function()
    assertEqual(easeOutCubic(0.5), 0.875)
end)

test("easeOutCubic is monotonically increasing", function()
    local prev = 0
    for i = 1, 10 do
        local t = i / 10
        local val = easeOutCubic(t)
        assertTrue(val >= prev, "easeOutCubic("..t..") should be >= "..prev..", got "..val)
        prev = val
    end
end)

test("easeOutCubic accelerates early, decelerates late", function()
    local earlyDelta = easeOutCubic(0.2) - easeOutCubic(0.0)
    local lateDelta  = easeOutCubic(1.0) - easeOutCubic(0.8)
    assertTrue(earlyDelta > lateDelta,
        "early segment should be larger than late segment for ease-out")
end)

-- ── 17. Clip height interpolation ──────────────────────────────────────
suite("Animation: Clip Height Interpolation")

-- Simulates the OnUpdate logic from Options.lua
local function simulateAnimStep(startH, targetH, elapsed, duration)
    if elapsed >= duration then
        return math.max(targetH, 0.1), true  -- finished
    end
    local p = elapsed / duration
    p = 1 - (1 - p) * (1 - p) * (1 - p)
    local h = startH + (targetH - startH) * p
    return math.max(h, 0.1), false
end

test("Opening: t=0 → clip = startH (0.1 min)", function()
    local h, done = simulateAnimStep(0.1, 200, 0, 0.25)
    assertEqual(h, 0.1)
    assertFalse(done)
end)

test("Opening: t=duration → clip = targetH", function()
    local h, done = simulateAnimStep(0.1, 200, 0.25, 0.25)
    assertEqual(h, 200)
    assertTrue(done)
end)

test("Opening: t>duration → clip = targetH (clamped)", function()
    local h, done = simulateAnimStep(0.1, 200, 0.5, 0.25)
    assertEqual(h, 200)
    assertTrue(done)
end)

test("Opening: mid-animation height is between start and target", function()
    local h, done = simulateAnimStep(0.1, 200, 0.125, 0.25)
    assertFalse(done)
    assertTrue(h > 0.1, "mid-anim should be > startH, got " .. h)
    assertTrue(h < 200, "mid-anim should be < targetH, got " .. h)
end)

test("Closing: startH=200, targetH=0 → clips to 0.1 minimum", function()
    local h, done = simulateAnimStep(200, 0, 0.25, 0.25)
    assertEqual(h, 0.1)
    assertTrue(done)
end)

test("Closing: mid-animation height is between 0.1 and startH", function()
    local h, done = simulateAnimStep(200, 0, 0.125, 0.25)
    assertFalse(done)
    assertTrue(h >= 0.1, "should not go below 0.1, got " .. h)
    assertTrue(h < 200,  "should be less than startH, got " .. h)
end)

test("Heights never go below 0.1 (floor)", function()
    for i = 0, 25 do
        local elapsed = i / 100  -- 0 to 0.25
        local h = simulateAnimStep(0.1, 0, elapsed, 0.25)
        assertTrue(h >= 0.1, "at t=" .. elapsed .. " height was " .. h)
    end
end)

-- ── 18. Animation state machine ────────────────────────────────────────
suite("Animation: State Machine")

-- Simulates a full open/close cycle by running multiple steps
local function runAnimation(startH, targetH, duration, stepSize)
    local results = {}
    local h, done
    local t = 0
    repeat
        h, done = simulateAnimStep(startH, targetH, t, duration)
        results[#results + 1] = { t = t, h = h, done = done }
        t = t + stepSize
    until done or t > duration + stepSize
    return results
end

test("Full open animation produces smooth ascending heights", function()
    local frames = runAnimation(0.1, 200, 0.25, 0.05)
    assertTrue(#frames >= 5, "should have multiple frames")
    -- Verify ascending (open)
    for i = 2, #frames do
        assertTrue(frames[i].h >= frames[i-1].h,
            "frame " .. i .. " h=" .. frames[i].h .. " should be >= frame " ..
            (i-1) .. " h=" .. frames[i-1].h)
    end
    -- Last frame should reach target
    assertEqual(frames[#frames].h, 200)
    assertTrue(frames[#frames].done)
end)

test("Full close animation produces smooth descending heights", function()
    local frames = runAnimation(200, 0, 0.25, 0.05)
    assertTrue(#frames >= 5)
    -- Verify descending (close)
    for i = 2, #frames do
        assertTrue(frames[i].h <= frames[i-1].h,
            "frame " .. i .. " h=" .. frames[i].h .. " should be <= frame " ..
            (i-1) .. " h=" .. frames[i-1].h)
    end
    -- Last frame floors at 0.1
    assertEqual(frames[#frames].h, 0.1)
end)

test("Animation completes in exactly ANIM_DURATION", function()
    local frames = runAnimation(0.1, 100, 0.25, 0.01)
    local lastFrame = frames[#frames]
    assertTrue(lastFrame.done)
    assertTrue(lastFrame.t >= 0.25, "should complete at or after 0.25")
    assertTrue(lastFrame.t <= 0.26, "should not overshoot too far")
end)

-- ── 19. Section toggle logic ───────────────────────────────────────────
suite("Animation: Section Toggle Logic")

test("Section starts with open=true if startOpen is true", function()
    -- We check via Options.lua: secIcon (SECTION_ICON) is created with startOpen=true
    -- The panel should exist by now from loadAddonFile("Options.lua")
    assertTrue(AoeDKOptionsPanel ~= nil, "Options panel should exist")
end)

-- ── 20. UI Scale ───────────────────────────────────────────────────────
suite("UI Scale")

-- Mirror of ApplyUIScale from Options.lua
local function NormalizeUIScale(scale)
    scale = math.max(0.5, math.min(2.0, scale))
    return math.floor(scale * 10 + 0.5) / 10
end

test("1.0 stays 1.0", function()
    assertEqual(NormalizeUIScale(1.0), 1.0)
end)

test("0.3 clamps to 0.5", function()
    assertEqual(NormalizeUIScale(0.3), 0.5)
end)

test("2.5 clamps to 2.0", function()
    assertEqual(NormalizeUIScale(2.5), 2.0)
end)

test("0.75 rounds to 0.8", function()
    assertEqual(NormalizeUIScale(0.75), 0.8)
end)

test("1.44 rounds to 1.4", function()
    assertEqual(NormalizeUIScale(1.44), 1.4)
end)

test("1.45 rounds to 1.5", function()
    assertEqual(NormalizeUIScale(1.45), 1.5)
end)

test("0.5 stays 0.5 (lower bound)", function()
    assertEqual(NormalizeUIScale(0.5), 0.5)
end)

test("2.0 stays 2.0 (upper bound)", function()
    assertEqual(NormalizeUIScale(2.0), 2.0)
end)

test("Step increments: 1.0 + 0.1 = 1.1", function()
    assertEqual(NormalizeUIScale(1.0 + 0.1), 1.1)
end)

test("Step decrements: 1.0 - 0.1 = 0.9", function()
    assertEqual(NormalizeUIScale(1.0 - 0.1), 0.9)
end)

-- ── 21. Layout cursor math ────────────────────────────────────────────
suite("Animation: Layout Cursor Math")

-- Simulates the LayoutFromClips cursor accumulation
local function simulateLayout(secs, headerH, padBot)
    local cursor = headerH + 8  -- HEADER_H + 8
    for _, s in ipairs(secs) do
        cursor = cursor + s.headerH
        cursor = cursor + s.clipH + 2
    end
    return cursor + padBot
end

test("1 section open: cursor = header+8 + hdrH + bodyH + 2 + pad", function()
    local totalH = simulateLayout(
        {{ headerH = 30, clipH = 200 }},
        44, 14   -- HEADER_H, PAD_BOT
    )
    -- 44 + 8 + 30 + 200 + 2 + 14 = 298
    assertEqual(totalH, 298)
end)

test("1 section closed: cursor uses clipH=0.1", function()
    local totalH = simulateLayout(
        {{ headerH = 30, clipH = 0.1 }},
        44, 14
    )
    -- 44 + 8 + 30 + 0.1 + 2 + 14 = 98.1
    assertTrue(math.abs(totalH - 98.1) < 0.01)
end)

test("4 sections all closed", function()
    local secs = {}
    for i = 1, 4 do secs[i] = { headerH = 30, clipH = 0.1 } end
    local totalH = simulateLayout(secs, 44, 14)
    -- 44 + 8 + 4*(30 + 0.1 + 2) + 14 = 44+8 + 4*32.1 + 14 = 194.4
    assertTrue(math.abs(totalH - 194.4) < 0.01)
end)

test("4 sections, only first open (body=262)", function()
    local secs = {
        { headerH = 30, clipH = 262 },
        { headerH = 30, clipH = 0.1 },
        { headerH = 30, clipH = 0.1 },
        { headerH = 30, clipH = 0.1 },
    }
    local totalH = simulateLayout(secs, 44, 14)
    -- 44+8 + (30+262+2) + 3*(30+0.1+2) + 14 = 52 + 294 + 96.3 + 14 = 456.3
    assertTrue(math.abs(totalH - 456.3) < 0.01)
end)

-- ── 22. Config defaults include uiScale ────────────────────────────────
suite("Config: uiScale Default")

test("ns.defaults has uiScale = 1.0", function()
    assertTrue(ns.defaults.uiScale ~= nil, "uiScale should be defined in defaults")
    assertEqual(ns.defaults.uiScale, 1.0)
end)

test("AoeDKDB.uiScale initialized from defaults", function()
    assertTrue(AoeDKDB.uiScale ~= nil)
    assertEqual(AoeDKDB.uiScale, 1.0)
end)

-- ── 23. Options panel loading ─────────────────────────────────────────
suite("Options Panel: Loaded Correctly")

test("AoeDKOptionsPanel global frame exists", function()
    assertTrue(AoeDKOptionsPanel ~= nil, "Panel should be created by Options.lua")
end)

test("ns.ToggleOptionsPanel function is exposed", function()
    assertTrue(type(ns.ToggleOptionsPanel) == "function",
        "ToggleOptionsPanel should be a function on ns")
end)

-- ════════════════════════════════════════════════════════════════════════
-- Summary
-- ════════════════════════════════════════════════════════════════════════
Mock.RestorePrint()
print("")
print(string.rep("═", 60))
print(string.format("  TOTAL: %d  |  PASSED: %d  |  FAILED: %d", total, passed, failed))
print(string.rep("═", 60))

if failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
