-- AoE DK: Core logic
local addonName, ns = ...

---------------------------------------------------------------------------
-- Import from namespace (populated by Locales.lua & Config.lua)
---------------------------------------------------------------------------
local L = ns.L

local DEATH_COIL_ID          = ns.DEATH_COIL_ID
local EPIDEMIC_ID            = ns.EPIDEMIC_ID
local NECROTIC_COIL_ID       = ns.NECROTIC_COIL_ID
local GRAVEYARD_ID           = ns.GRAVEYARD_ID
local FORBIDDEN_KNOWLEDGE_ID = ns.FORBIDDEN_KNOWLEDGE_ID
local RIDER_CHECK_ID         = ns.RIDER_CHECK_ID
local SANLAYN_CHECK_ID       = ns.SANLAYN_CHECK_ID
local HERO_THRESHOLD_MODIFIER = ns.HERO_THRESHOLD_MODIFIER
local UPDATE_INTERVAL        = ns.UPDATE_INTERVAL
local ICON_SIZE              = ns.ICON_SIZE
local ICON_ALPHA             = ns.ICON_ALPHA

---------------------------------------------------------------------------
-- Frame principal
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "AoeDKFrame", UIParent, "BackdropTemplate")
frame:SetSize(ICON_SIZE, ICON_SIZE)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
local isUnlocked = false
frame:SetScript("OnDragStart", function(self)
    if isUnlocked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not isUnlocked then return end
    -- Guardar posicion
    local point, _, relPoint, x, y = self:GetPoint()
    AoeDKDB.point    = point
    AoeDKDB.relPoint = relPoint
    AoeDKDB.x        = x
    AoeDKDB.y        = y
end)

frame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true, tileSize = 16, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
frame:SetBackdropColor(0, 0, 0, 0)
frame:SetBackdropBorderColor(0, 0, 0, 1)

-- Icono del hechizo sugerido
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 2, -2)
icon:SetPoint("BOTTOMRIGHT", -2, 2)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

-- Texto con la cuenta de enemigos
local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
countText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
countText:SetTextColor(1, 0.8, 0)

-- Texto del nombre del hechizo
local spellText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spellText:SetPoint("TOP", frame, "BOTTOM", 0, -4)
spellText:SetTextColor(1, 1, 1)

-- Declaradas antes de ShowAnchor/HideAnchor para que ambas funciones capturen los locales correctos
local currentSpellID = nil
local forceShow = false       -- para /aoedk test
local fadeOutPending = false  -- guard contra race condition fade-out/fade-in
local detectionMode = "real"  -- "real" o "dummy"

-- Cache de clase/spec: no cambian durante combate, se actualizan via PLAYER_SPECIALIZATION_CHANGED
local cachedClassID   = nil
local cachedSpecIndex = nil
local cachedHeroTalent = nil
local function RefreshClassSpec()
    local _, _, classID = UnitClass("player")
    cachedClassID   = classID
    cachedSpecIndex = GetSpecialization()
    if IsPlayerSpell(RIDER_CHECK_ID) then
        cachedHeroTalent = "rider"
    elseif IsPlayerSpell(SANLAYN_CHECK_ID) then
        cachedHeroTalent = "sanlayn"
    else
        cachedHeroTalent = nil
    end
end

-- Tooltip: muestra nombre del spell actual (bloqueado) o instruccion de mover (desbloqueado)
frame:SetScript("OnEnter", function()
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cff00ccffAoE DK|r")
    if isUnlocked then
        GameTooltip:AddLine(L.DRAG_TO_MOVE, 0.8, 0.8, 0.8)
    elseif currentSpellID then
        local spellInfo = C_Spell.GetSpellInfo(currentSpellID)
        if spellInfo then GameTooltip:AddLine(spellInfo.name, 1, 1, 1) end
    end
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function ShowAnchor()
    isUnlocked = true
    icon:SetTexture("Interface\\Icons\\Spell_DeathKnight_Explode_Ghoul")
    icon:SetAlpha(0.5)
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    countText:SetText("AoE DK")
    countText:SetTextColor(0, 0.8, 1)
    countText:Show()
    spellText:SetText(L.DRAG_TO_MOVE)
    spellText:SetTextColor(0, 0.8, 1)
    spellText:Show()
    frame:Show()
end

local function HideAnchor()
    isUnlocked = false
    icon:SetAlpha(AoeDKDB.iconAlpha)
    countText:SetText("")
    spellText:SetText("")
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    currentSpellID = nil
    if not AoeDKDB.showText then
        countText:Hide()
        spellText:Hide()
    end
    -- Si no esta en combate, ocultar
    if not UnitAffectingCombat("player") then
        frame:Hide()
    end
end

---------------------------------------------------------------------------
-- Funciones de configuracion
---------------------------------------------------------------------------
local function ApplyIconSize(size)
    frame:SetSize(size, size)
    AoeDKDB.iconSize = size
end

local function ApplyIconAlpha(alpha)
    alpha = math.max(0.1, math.min(1.0, alpha))
    -- Redondear a 1 decimal
    alpha = math.floor(alpha * 10 + 0.5) / 10
    AoeDKDB.iconAlpha = alpha
    if not isUnlocked then
        icon:SetAlpha(alpha)
    end
end

local function ApplyBorderSize(size)
    size = math.max(1, math.min(8, size))
    AoeDKDB.borderSize = size
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = size,
        insets = { left = size, right = size, top = size, bottom = size },
    })
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    -- Ajustar el icono para respetar el nuevo grosor del borde
    icon:SetPoint("TOPLEFT", size, -size)
    icon:SetPoint("BOTTOMRIGHT", -size, size)
end

---------------------------------------------------------------------------
-- Sistema de deteccion de enemigos
-- 1) Nameplates via eventos NAME_PLATE_UNIT_ADDED/REMOVED
-- 2) Target actual siempre se cuenta si es valido
---------------------------------------------------------------------------
local npActive = {}   -- [unit] = true  (nameplates activas de enemigos)

-- Tracking de nameplates via eventos
local npTracker = CreateFrame("Frame")
npTracker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
npTracker:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
npTracker:RegisterEvent("UNIT_FLAGS")
npTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
npTracker:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if UnitIsFriend("player", unit) then return end
        npActive[unit] = true
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npActive[unit] = nil
    elseif event == "UNIT_FLAGS" then
        if npActive[unit] and UnitIsFriend("player", unit) then
            npActive[unit] = nil
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(npActive)
    end
end)

-- Verificar si una unidad es un enemigo valido para contar
local function IsValidEnemy(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDead(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

local function GetEnemyCount()
    local count = 0
    local targetCounted = false
    local hasTarget = UnitExists("target")  -- cacheado: evita 3 llamadas separadas

    -- Paso 1: Nameplates activas (fuente principal, via eventos)
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if detectionMode == "dummy" or forceShow then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            else
                -- Real mode: solo mobs en combate o con threat
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

    -- Paso 2: Siempre contar target actual si es valido y no fue contado
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

---------------------------------------------------------------------------
-- Detectar si Forbidden Knowledge (Army of the Dead) esta activo.
-- El buff 1242223 indica que el Ejercito esta en juego; activa las
-- habilidades mejoradas y el umbral FK.
---------------------------------------------------------------------------
local function IsForbiddenKnowledgeActive()
    return C_UnitAuras.GetPlayerAuraBySpellID(FORBIDDEN_KNOWLEDGE_ID) ~= nil
end

---------------------------------------------------------------------------
-- Actualizar icono segun cantidad de enemigos
---------------------------------------------------------------------------

local function UpdateIcon()
    -- Solo para DK Profano (Unholy = spec index 3, class ID 6)
    -- Usa valores cacheados: UnitClass/GetSpecialization no cambian durante combate
    if not forceShow then
        if cachedClassID ~= 6 then
            frame:Hide()
            return
        end
        if not cachedSpecIndex or cachedSpecIndex ~= 3 then
            frame:Hide()
            return
        end
    end

    -- Si esta en modo unlock, no sobreescribir el ancla
    if isUnlocked then return end

    -- Solo en combate (o forceShow)
    if not forceShow and not UnitAffectingCombat("player") then
        frame:Hide()
        return
    end

    local enemyCount = GetEnemyCount()

    if enemyCount == 0 then
        frame:Hide()
        return
    end

    -- Determinar hechizo sugerido
    local spellID
    local fkActive = IsForbiddenKnowledgeActive()
    
    -- Calcular threshold base + modificador de hero talent
    local baseThreshold = fkActive and AoeDKDB.epidemicThresholdFK or AoeDKDB.epidemicThreshold
    local heroMod = (cachedHeroTalent and HERO_THRESHOLD_MODIFIER[cachedHeroTalent]) or 0
    local threshold = math.max(1, baseThreshold + heroMod)  -- Minimo 1

    if fkActive then
        -- Con Forbidden Knowledge (Army activo): cuatro niveles de hechizos.
        -- DC < (threshold-1) <= Epidemic < threshold <= Necrotic <= (threshold+1) <= Graveyard
        if enemyCount >= (threshold + 1) then
            spellID = GRAVEYARD_ID
        elseif enemyCount >= threshold then
            spellID = NECROTIC_COIL_ID
        elseif enemyCount >= (threshold - 1) then
            spellID = EPIDEMIC_ID
        else
            spellID = DEATH_COIL_ID
        end
    else
        -- Sin Forbidden Knowledge: Death Coil o Epidemic segun umbral base
        if enemyCount >= threshold then
            spellID = EPIDEMIC_ID
        else
            spellID = DEATH_COIL_ID
        end
    end

    -- Actualizar textura solo si cambio (swap instantaneo, sin fade)
    if spellID ~= currentSpellID then
        currentSpellID = spellID
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        if spellTexture then
            icon:SetTexture(spellTexture)
        end
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            spellText:SetText(spellInfo.name)
        end
    end

    if AoeDKDB.showText then
        countText:SetText(enemyCount .. (enemyCount == 1 and (" " .. L.ENEMY) or (" " .. L.ENEMIES)))
        countText:Show()
        spellText:Show()
    else
        countText:Hide()
        spellText:Hide()
    end

    -- Borde negro siempre
    frame:SetBackdropBorderColor(0, 0, 0, 1)

    frame:Show()
end

---------------------------------------------------------------------------
-- Timer frame separado (siempre activo durante combate)
---------------------------------------------------------------------------
local ticker = CreateFrame("Frame", "AoeDKTicker", UIParent)
local elapsed = 0
local tickerRunning = false

local function StartTicker()
    if not tickerRunning then
        tickerRunning = true
        ticker:Show()
    end
end

local function StopTicker()
    tickerRunning = false
    ticker:Hide()
end

ticker:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= UPDATE_INTERVAL then
        elapsed = 0
        UpdateIcon()
    end
end)
ticker:Hide()

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterUnitEvent("UNIT_AURA", "player")  -- solo auras del jugador, no de todas las unidades
frame:RegisterEvent("PLAYER_TARGET_CHANGED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Merge defaults: garantiza que todos los campos existen en AoeDKDB
        AoeDKDB = AoeDKDB or {}
        for k, v in pairs(ns.defaults) do
            if AoeDKDB[k] == nil then AoeDKDB[k] = v end
        end
        -- Restaurar posicion guardada
        if AoeDKDB.point then
            frame:ClearAllPoints()
            frame:SetPoint(AoeDKDB.point, UIParent, AoeDKDB.relPoint, AoeDKDB.x, AoeDKDB.y)
        end
        frame:SetSize(AoeDKDB.iconSize, AoeDKDB.iconSize)
        icon:SetAlpha(AoeDKDB.iconAlpha)
        ApplyBorderSize(AoeDKDB.borderSize)
        if not AoeDKDB.showText then
            countText:Hide()
            spellText:Hide()
        end
        detectionMode = AoeDKDB.detectionMode
        RefreshClassSpec()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "UNIT_AURA" and arg1 == "player" then
        if UnitAffectingCombat("player") or forceShow then
            currentSpellID = nil
            UpdateIcon()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") or forceShow then
            UpdateIcon()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Salir de combate: fade-out y ocultar (salvo si forceShow o unlock)
        if not forceShow and not isUnlocked then
            StopTicker()
            currentSpellID = nil
            local alpha = AoeDKDB.iconAlpha
            fadeOutPending = true
            UIFrameFadeOut(frame, 0.4, alpha, 0)
            C_Timer.After(0.4, function()
                if not fadeOutPending then return end
                fadeOutPending = false
                if not forceShow and not isUnlocked then
                    frame:Hide()
                    frame:SetAlpha(alpha)  -- restaurar alpha para la proxima vez
                end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entrar en combate: cancelar fade-out pendiente, fade-in y arrancar ticker
        fadeOutPending = false
        StartTicker()
        UpdateIcon()
        local alpha = AoeDKDB.iconAlpha
        UIFrameFadeIn(frame, 0.3, 0, alpha)
    else
        -- Cubre PLAYER_SPECIALIZATION_CHANGED y PLAYER_ENTERING_WORLD
        RefreshClassSpec()
        UpdateIcon()
    end
end)

frame:Hide()

---------------------------------------------------------------------------
-- Expose to namespace (used by Options.lua)
---------------------------------------------------------------------------
ns.frame     = frame
ns.icon      = icon
ns.countText = countText
ns.spellText = spellText
ns.ShowAnchor       = ShowAnchor
ns.HideAnchor       = HideAnchor
ns.ApplyIconSize    = ApplyIconSize
ns.ApplyIconAlpha   = ApplyIconAlpha
ns.ApplyBorderSize  = ApplyBorderSize
ns.IsUnlocked       = function() return isUnlocked end
ns.ResetCurrentSpell = function() currentSpellID = nil end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_AOEDK1 = "/aoedk"
SlashCmdList["AOEDK"] = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg), 2)
    cmd = strlower(cmd or "")

    if cmd == "lock" then
        HideAnchor()
        print("|cff00ccff[AoE DK]|r " .. L.MSG_LOCKED)
    elseif cmd == "unlock" then
        ShowAnchor()
        print("|cff00ccff[AoE DK]|r " .. L.MSG_UNLOCKED)
    elseif cmd == "reset" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        AoeDKDB.point    = nil
        AoeDKDB.relPoint = nil
        AoeDKDB.x        = nil
        AoeDKDB.y        = nil
        print("|cff00ccff[AoE DK]|r " .. L.MSG_POSITION_RESET)
    elseif cmd == "test" then
        forceShow = not forceShow
        if forceShow then
            print("|cff00ccff[AoE DK]|r " .. L.MSG_TEST_ON)
            StartTicker()
            UpdateIcon()
        else
            print("|cff00ccff[AoE DK]|r " .. L.MSG_TEST_OFF)
            currentSpellID = nil
            if not UnitAffectingCombat("player") then
                StopTicker()
                frame:Hide()
            end
        end
    elseif cmd == "debug" then
        local _, _, classID = UnitClass("player")
        local specIndex = GetSpecialization() or 0
        local inCombat = UnitAffectingCombat("player")
        local enemyCount = GetEnemyCount()
        local fkActive = IsForbiddenKnowledgeActive()
        
        -- Calcular threshold efectivo
        local baseThreshold = fkActive and AoeDKDB.epidemicThresholdFK or AoeDKDB.epidemicThreshold
        local heroMod = (cachedHeroTalent and HERO_THRESHOLD_MODIFIER[cachedHeroTalent]) or 0
        local effectiveThreshold = math.max(1, baseThreshold + heroMod)
        
        print("|cff00ccff[AoE DK] DEBUG:|r")
        print("  " .. L.DEBUG_CLASS .. ": " .. tostring(classID) .. " (necesita 6=DK)")
        print("  " .. L.DEBUG_SPEC .. ": " .. tostring(specIndex) .. " (necesita 3=Unholy)")
        print("  " .. L.DEBUG_COMBAT .. ": " .. tostring(inCombat))
        print("  " .. L.DEBUG_ARMY .. " / Forbidden Knowledge: " .. tostring(fkActive))
        print("  Hero talent: " .. (cachedHeroTalent or "unknown") .. 
               " (modifier: " .. (heroMod >= 0 and "+" or "") .. heroMod .. ")")
        print("  Threshold: " .. baseThreshold .. " => " .. effectiveThreshold .. 
               " (base " .. (fkActive and "FK" or "normal") .. " + hero modifier)")
        print("  " .. L.DEBUG_ENEMIES .. ": " .. enemyCount)
        print("  " .. L.DEBUG_MODE .. ": " .. detectionMode)
        print("  " .. L.DEBUG_VISIBLE .. ": " .. tostring(frame:IsShown()))
        print("  isUnlocked: " .. tostring(isUnlocked))
        print("  forceShow: " .. tostring(forceShow))
        local npCount = 0
        for _ in pairs(npActive) do npCount = npCount + 1 end
        print("  Tracked nameplates: " .. npCount)
        for unit in pairs(npActive) do
            local name = UnitName(unit) or "?"
            local dead = UnitIsDead(unit)
            local canAtk = UnitCanAttack("player", unit)
            local inCbt = UnitAffectingCombat(unit)
            local threat = UnitThreatSituation("player", unit)
            print("    " .. unit .. ": " .. name .. " canAttack=" .. tostring(canAtk) .. " dead=" .. tostring(dead) .. " combat=" .. tostring(inCbt) .. " threat=" .. tostring(threat))
        end
    elseif cmd == "auras" then
        print("|cff00ccff[AoE DK] " .. L.BUFFS_ACTIVE .. "|r")
        AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
            print("  [" .. (aura.spellId or "?") .. "] " .. (aura.name or "?") .. " (quedan " .. string.format("%.1f", (aura.expirationTime or 0) - GetTime()) .. "s)")
        end)
        print("|cff00ccff[AoE DK] " .. L.DEBUFFS_ACTIVE .. "|r")
        AuraUtil.ForEachAura("player", "HARMFUL", nil, function(aura)
            print("  [" .. (aura.spellId or "?") .. "] " .. (aura.name or "?"))
        end)
    elseif cmd == "mode" then
        if arg == "dummy" then
            detectionMode = "dummy"
            AoeDKDB.detectionMode = "dummy"
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_DUMMY)
        elseif arg == "real" then
            detectionMode = "real"
            AoeDKDB.detectionMode = "real"
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_REAL)
        else
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_CURRENT .. " |cffffff00" .. detectionMode .. "|r")
            print("  " .. L.MSG_MODE_USAGE)
        end
    else
        ns.ToggleOptionsPanel()
    end
end
