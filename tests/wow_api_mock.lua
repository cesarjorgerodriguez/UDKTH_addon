---------------------------------------------------------------------------
-- wow_api_mock.lua — Lightweight mock of the WoW Lua API consumed by AoE DK
--
-- Usage:  require("tests.wow_api_mock")
-- Every public symbol is injected into _G so the addon code runs unmodified.
-- Call Mock.Reset() between tests to restore a clean state.
---------------------------------------------------------------------------

local Mock = {}
_G.Mock = Mock

---------------------------------------------------------------------------
-- Internal state (manipulated by tests via Mock helpers)
---------------------------------------------------------------------------
local state = {}

local function DefaultState()
    return {
        -- Player info
        playerClass   = "DEATHKNIGHT",
        playerClassID = 6,
        specIndex     = 3,   -- Unholy
        inCombat      = true,
        playerSpells  = {},   -- [spellID] = true

        -- Target
        targetExists     = false,
        targetDead       = false,
        targetCanAttack  = true,
        targetFriend     = false,
        targetInCombat   = true,
        targetThreat     = 1,       -- nil = no threat
        targetUnit       = nil,     -- nameplate unitID the target maps to (for UnitIsUnit)

        -- Nameplates:  { unitID = { dead, canAttack, friend, inCombat, threat, name } }
        nameplates = {},

        -- Player auras:  { [spellID] = { name, spellId, expirationTime } | true }
        playerAuras = {},

        -- Detection mode forwarded into the addon
        detectionMode = "real",
        forceShow     = false,
    }
end

function Mock.Reset()
    state = DefaultState()
end
Mock.Reset()  -- initialize

---------------------------------------------------------------------------
-- Helpers for tests
---------------------------------------------------------------------------

--- Configure the player's class and spec.
function Mock.SetClassSpec(classID, specIndex)
    state.playerClassID = classID
    state.specIndex     = specIndex
end

--- Set whether the player is in combat.
function Mock.SetInCombat(inCombat)
    state.inCombat = inCombat
end

--- Mark a spell as known (IsPlayerSpell).
function Mock.LearnSpell(spellID)
    state.playerSpells[spellID] = true
end

function Mock.UnlearnSpell(spellID)
    state.playerSpells[spellID] = nil
end

--- Add a player aura (buff/debuff).
function Mock.AddPlayerAura(spellID, name)
    state.playerAuras[spellID] = {
        name           = name or ("Aura-" .. spellID),
        spellId        = spellID,
        expirationTime = 99999,
    }
end

function Mock.RemovePlayerAura(spellID)
    state.playerAuras[spellID] = nil
end

--- Configure the current target.
function Mock.SetTarget(opts)
    -- opts = { exists, dead, canAttack, friend, inCombat, threat, unit }
    opts = opts or {}
    state.targetExists    = opts.exists ~= false
    state.targetDead      = opts.dead or false
    state.targetCanAttack = opts.canAttack ~= false
    state.targetFriend    = opts.friend or false
    state.targetInCombat  = opts.inCombat ~= false
    state.targetThreat    = opts.threat           -- nil = no threat
    state.targetUnit      = opts.unit or nil      -- matches a nameplate unitID
end

function Mock.ClearTarget()
    state.targetExists = false
    state.targetUnit   = nil
end

--- Add/remove enemy nameplates.
function Mock.AddNameplate(unitID, opts)
    opts = opts or {}
    state.nameplates[unitID] = {
        dead      = opts.dead or false,
        canAttack = opts.canAttack ~= false,
        friend    = opts.friend or false,
        inCombat  = opts.inCombat ~= false,
        threat    = opts.threat,            -- nil = no threat
        name      = opts.name or unitID,
    }
end

function Mock.RemoveNameplate(unitID)
    state.nameplates[unitID] = nil
end

function Mock.ClearNameplates()
    state.nameplates = {}
end

---------------------------------------------------------------------------
-- Resolve a unitID to its backing data table (nameplate or target)
---------------------------------------------------------------------------
local function Resolve(unit)
    if unit == "player" then return "player" end
    if unit == "target" then return "target" end
    return state.nameplates[unit] and unit or nil
end

---------------------------------------------------------------------------
-- WoW global API mocks
---------------------------------------------------------------------------

function UnitClass(unit)
    if unit == "player" then
        return state.playerClass, state.playerClass, state.playerClassID
    end
    return "Unknown", "UNKNOWN", 0
end

function GetSpecialization()
    return state.specIndex
end

function IsPlayerSpell(spellID)
    return state.playerSpells[spellID] == true
end

function UnitExists(unit)
    if unit == "player" then return true end
    if unit == "target" then return state.targetExists end
    return state.nameplates[unit] ~= nil
end

function UnitIsDead(unit)
    if unit == "player" then return false end
    if unit == "target" then return state.targetDead end
    local np = state.nameplates[unit]
    return np and np.dead or false
end

function UnitCanAttack(_, unit)
    if unit == "player" then return false end
    if unit == "target" then return state.targetCanAttack end
    local np = state.nameplates[unit]
    return np and np.canAttack or false
end

function UnitIsFriend(_, unit)
    if unit == "player" then return true end
    if unit == "target" then return state.targetFriend end
    local np = state.nameplates[unit]
    return np and np.friend or false
end

function UnitAffectingCombat(unit)
    if unit == "player" then return state.inCombat end
    if unit == "target" then return state.targetInCombat end
    local np = state.nameplates[unit]
    return np and np.inCombat or false
end

function UnitThreatSituation(_, unit)
    if unit == "target" then return state.targetThreat end
    local np = state.nameplates[unit]
    return np and np.threat or nil
end

function UnitIsUnit(a, b)
    if a == b then return true end
    -- target == nameplate mapping
    if b == "target" and state.targetUnit == a then return true end
    if a == "target" and state.targetUnit == b then return true end
    return false
end

function UnitName(unit)
    if unit == "player" then return "TestPlayer" end
    if unit == "target" then return "TargetMob" end
    local np = state.nameplates[unit]
    return np and np.name or nil
end

---------------------------------------------------------------------------
-- C_Spell
---------------------------------------------------------------------------
C_Spell = C_Spell or {}

function C_Spell.GetSpellInfo(spellID)
    return { name = "Spell-" .. tostring(spellID), spellID = spellID }
end

function C_Spell.GetSpellTexture(spellID)
    return "Interface\\Icons\\Spell_" .. tostring(spellID)
end

---------------------------------------------------------------------------
-- C_UnitAuras
---------------------------------------------------------------------------
C_UnitAuras = C_UnitAuras or {}

function C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    local aura = state.playerAuras[spellID]
    if aura then return aura end
    return nil
end

---------------------------------------------------------------------------
-- Frame stubs (stateful: tracks height, show/hide, scripts, alpha, scale)
---------------------------------------------------------------------------
UIParent = UIParent or {}

local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:SetSize(w, h) self._width = w; self._height = h end
function FrameMethods:SetHeight(h) self._height = h end
function FrameMethods:GetHeight() return self._height or 0 end
function FrameMethods:SetWidth(w) self._width = w end
function FrameMethods:GetWidth() return self._width or 0 end
function FrameMethods:SetPoint() end
function FrameMethods:ClearAllPoints() end
function FrameMethods:SetMovable() end
function FrameMethods:SetClampedToScreen() end
function FrameMethods:EnableMouse() end
function FrameMethods:RegisterForDrag() end
function FrameMethods:SetScript(name, fn) self._scripts = self._scripts or {}; self._scripts[name] = fn end
function FrameMethods:GetScript(name) return self._scripts and self._scripts[name] end
function FrameMethods:SetBackdrop() end
function FrameMethods:SetBackdropColor() end
function FrameMethods:SetBackdropBorderColor() end
function FrameMethods:RegisterEvent() end
function FrameMethods:RegisterUnitEvent() end
function FrameMethods:UnregisterEvent() end
function FrameMethods:UnregisterAllEvents() end
function FrameMethods:Show() self._shown = true end
function FrameMethods:Hide() self._shown = false end
function FrameMethods:IsShown() return self._shown == true end
function FrameMethods:SetAlpha(a) self._alpha = a end
function FrameMethods:GetAlpha() return self._alpha or 1 end
function FrameMethods:SetScale(s) self._scale = s end
function FrameMethods:GetScale() return self._scale or 1 end
function FrameMethods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function FrameMethods:StartMoving() end
function FrameMethods:StopMovingOrSizing() end
function FrameMethods:SetFrameStrata() end
function FrameMethods:SetClipsChildren() end

function FrameMethods:CreateTexture(...)
    local tex = {}
    function tex:SetPoint() end
    function tex:SetAllPoints() end
    function tex:SetTexCoord() end
    function tex:SetAlpha() end
    function tex:SetTexture() end
    function tex:SetColorTexture() end
    function tex:SetSize() end
    function tex:SetHeight() end
    function tex:SetVertexColor() end
    function tex:SetRotation() end
    function tex:Show() end
    function tex:Hide() end
    return tex
end

function FrameMethods:CreateFontString(...)
    local fs = {}
    function fs:SetPoint() end
    function fs:SetAllPoints() end
    function fs:SetTextColor() end
    function fs:SetText(_, t) fs._text = t end
    function fs:GetText() return fs._text or "" end
    function fs:SetJustifyH() end
    function fs:Show() end
    function fs:Hide() end
    return fs
end

function CreateFrame(_, name, ...)
    local f = setmetatable({ _shown = false, _height = 0, _width = 0, _alpha = 1, _scale = 1 }, FrameMethods)
    if name then _G[name] = f end
    return f
end

---------------------------------------------------------------------------
-- Misc globals used by the addon
---------------------------------------------------------------------------
GameTooltip = GameTooltip or { SetOwner = function() end, ClearLines = function() end,
    AddLine = function() end, Show = function() end, Hide = function() end }

AuraUtil = AuraUtil or { ForEachAura = function() end }

function UIFrameFadeIn() end
function UIFrameFadeOut() end
C_Timer = C_Timer or {
    After = function(_, cb) if cb then cb() end end,
    NewTicker = function(_, cb) return { Cancel = function() end } end,
}
function GetTime() return 0 end
function GetLocale() return "enUS" end
function PlaySoundFile() end
SlashCmdList = SlashCmdList or {}
UISpecialFrames = UISpecialFrames or {}

-- math.pow may not exist in Lua 5.3+; the addon uses it (Lua 5.1/LuaJIT)
if not math.pow then math.pow = function(b, e) return b ^ e end end

function strsplit(delim, str, max)
    local t = {}
    local n = 0
    for part in string.gmatch(str, "([^" .. delim .. "]+)") do
        n = n + 1
        if max and n >= max then
            t[n] = str:sub(str:find(part, 1, true))
            break
        end
        t[n] = part
    end
    return unpack(t)
end

function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strlower(s) return s:lower() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tinsert(...) table.insert(...) end

-- Dummy print capture (optional: tests can inspect)
Mock._prints = {}
local _realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    Mock._prints[#Mock._prints + 1] = table.concat(parts, " ")
end

--- Restore real print (call once after tests if you want console output).
function Mock.RestorePrint()
    print = _realPrint
end

---------------------------------------------------------------------------
-- Global saved variable placeholder
---------------------------------------------------------------------------
AoeDKDB = nil   -- will be initialized by ADDON_LOADED handler

return Mock
