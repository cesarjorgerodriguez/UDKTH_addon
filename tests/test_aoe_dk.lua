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

-- Mirror of IsValidEnemy from aoe_dk.lua
local function IsValidEnemy(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

-- Mirror of GetEnemyCount from aoe_dk.lua
-- npActive is passed in so tests can control it; detectionMode/forceShow as params
local function GetEnemyCount(npActive, detectionMode, forceShow)
    local count = 0
    local targetCounted = false
    local hasTarget = UnitExists("target")

    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if detectionMode == "dummy" or forceShow then
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
        if detectionMode == "dummy" or forceShow then
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
local function SelectSpell(enemyCount, fkActive, db)
    if enemyCount == 0 then return nil end

    local threshold
    if fkActive then
        threshold = db.epidemicThresholdFK
    else
        threshold = db.epidemicThreshold
    end

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

-- ── 7. Enemy counting — Real mode ────────────────────────────────────
suite("Enemy Count — Real Mode")

test("No nameplates, no target → 0", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = {}
    assertEqual(GetEnemyCount(npa, "real", false), 0)
end)

test("3 enemy nameplates in combat → 3", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    assertEqual(GetEnemyCount(npa, "real", false), 3)
end)

test("3 enemies, 1 dead → 2", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.AddNameplate("nameplate3", { dead = true, inCombat = true, threat = 1 })
    npa["nameplate3"] = true
    assertEqual(GetEnemyCount(npa, "real", false), 2)
end)

test("3 enemies, 1 not in combat and no threat → 2", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.AddNameplate("nameplate3", { inCombat = false, threat = nil })
    npa["nameplate3"] = true
    assertEqual(GetEnemyCount(npa, "real", false), 2)
end)

test("Enemy with threat but not in combat → counted", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddNameplate("nameplate1", { inCombat = false, threat = 0 })
    local npa = { nameplate1 = true }
    assertEqual(GetEnemyCount(npa, "real", false), 1)
end)

-- ── 8. Enemy counting — Dummy mode ──────────────────────────────────
suite("Enemy Count — Dummy Mode")

test("5 enemies, none in combat → 5 (dummy counts all)", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(5, { inCombat = false, threat = nil })
    assertEqual(GetEnemyCount(npa, "dummy", false), 5)
end)

-- ── 9. Enemy counting — Target deduplication ────────────────────────
suite("Enemy Count — Target Deduplication")

test("Target already in nameplates → not double-counted", function()
    Mock.Reset()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = "nameplate2" })
    assertEqual(GetEnemyCount(npa, "real", false), 3)
end)

test("Target NOT in nameplates → added as +1", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = nil })
    assertEqual(GetEnemyCount(npa, "real", false), 3)
end)

test("Target not in combat (real mode) → not added", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = false, threat = nil, unit = nil })
    assertEqual(GetEnemyCount(npa, "real", false), 2)
end)

test("Target not in combat (dummy mode) → added", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = false, threat = nil })
    Mock.SetTarget({ exists = true, inCombat = false, threat = nil, unit = nil })
    assertEqual(GetEnemyCount(npa, "dummy", false), 3)
end)

test("forceShow=true counts like dummy mode", function()
    Mock.Reset()
    local npa = AddEnemies(3, { inCombat = false, threat = nil })
    Mock.ClearTarget()
    assertEqual(GetEnemyCount(npa, "real", true), 3)
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
    assertEqual(GetEnemyCount(npa, "real", false), 0)
end)

test("Only target, no nameplates, in combat → 1", function()
    Mock.Reset()
    Mock.ClearNameplates()
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1 })
    assertEqual(GetEnemyCount({}, "real", false), 1)
end)

test("Friendly nameplate filtered out", function()
    Mock.Reset()
    Mock.ClearTarget()
    Mock.AddNameplate("nameplate1", { friend = true, inCombat = true, threat = 1 })
    -- Friendly units have canAttack = false in IsValidEnemy
    Mock.AddNameplate("nameplate1", { friend = true, canAttack = false, inCombat = true })
    local npa = { nameplate1 = true }
    assertEqual(GetEnemyCount(npa, "real", false), 0)
end)

-- ── 15. Integration: full flow enemy → spell ──────────────────────────
suite("Integration: Enemies → Spell Selection")

test("2 real enemies + target (dedup) → Death Coil (2 < threshold 3)", function()
    Mock.Reset()
    local npa = AddEnemies(2, { inCombat = true, threat = 1 })
    Mock.SetTarget({ exists = true, inCombat = true, threat = 1, unit = "nameplate1" })
    local count = GetEnemyCount(npa, "real", false)
    local spell = SelectSpell(count, false, defaultDB)
    assertEqual(count, 2)
    assertEqual(spell, DEATH_COIL_ID)
end)

test("3 real enemies → Epidemic", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(3, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, "real", false)
    local spell = SelectSpell(count, false, defaultDB)
    assertEqual(count, 3)
    assertEqual(spell, EPIDEMIC_ID)
end)

test("4 enemies, no FK → Epidemic (4 >= base threshold 3)", function()
    Mock.Reset()
    Mock.ClearTarget()
    local npa = AddEnemies(4, { inCombat = true, threat = 1 })
    local count = GetEnemyCount(npa, "real", false)
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
    local count = GetEnemyCount(npa, "real", false)
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
    local count = GetEnemyCount(npa, "real", false)
    local fk = IsForbiddenKnowledgeActive()
    local spell = SelectSpell(count, fk, defaultDB)
    assertEqual(count, 7)
    assertTrue(fk)
    assertEqual(spell, GRAVEYARD_ID)
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
