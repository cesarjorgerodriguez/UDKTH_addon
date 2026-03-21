-- AoE DK: Sugiere Espiral de la Muerte (1-3 targets) o Epidemia (4+ targets)
local addonName, ns = ...

---------------------------------------------------------------------------
-- Localization
---------------------------------------------------------------------------
local L = {}
local locale = GetLocale()

-- English (default)
L.DRAG_TO_MOVE = "Drag to move"
L.ENEMY = "enemy"
L.ENEMIES = "enemies"
L.OPTIONS_TITLE = "|cff00ccffAoE DK|r Options"
L.LOCK_ICON = "Lock icon"
L.UNLOCK_ICON = "Unlock icon"
L.MOVE_ICON = "Move icon"
L.ICON_SIZE = "Icon size"
L.ICON_TRANSPARENCY = "Icon transparency"
L.HIDE_TEXT = "Hide text"
L.SHOW_TEXT = "Show text"
L.RESET_POSITION = "Reset position"
L.MSG_LOCKED = "Icon locked."
L.MSG_UNLOCKED = "Icon unlocked. Drag to move."
L.MSG_POSITION_RESET = "Position reset."
L.MSG_TEST_ON = "TEST mode enabled (shows without checks)."
L.MSG_TEST_OFF = "TEST mode disabled."
L.MSG_MODE_DUMMY = "DUMMY mode: counts all enemies with visible nameplate."
L.MSG_MODE_REAL = "REAL mode: counts only enemies in combat/with threat."
L.MSG_MODE_CURRENT = "Current mode:"
L.MSG_MODE_USAGE = "Use: /aoedk mode dummy  or  /aoedk mode real"
L.DEBUG_CLASS = "Class ID"
L.DEBUG_SPEC = "Spec Index"
L.DEBUG_COMBAT = "In combat"
L.DEBUG_ARMY = "Army active"
L.DEBUG_ENEMIES = "Enemies detected"
L.DEBUG_MODE = "Mode"
L.DEBUG_VISIBLE = "Frame visible"
L.BUFFS_ACTIVE = "Active BUFFS:"
L.DEBUFFS_ACTIVE = "Active DEBUFFS:"

-- Spanish
if locale == "esES" or locale == "esMX" then
    L.DRAG_TO_MOVE = "Arrastra para mover"
    L.ENEMY = "enemigo"
    L.ENEMIES = "enemigos"
    L.OPTIONS_TITLE = "|cff00ccffAoE DK|r Opciones"
    L.LOCK_ICON = "Bloquear icono"
    L.UNLOCK_ICON = "Desbloquear icono"
    L.MOVE_ICON = "Mover icono"
    L.ICON_SIZE = "Tamaño del icono"
    L.ICON_TRANSPARENCY = "Transparencia del icono"
    L.HIDE_TEXT = "Ocultar texto"
    L.SHOW_TEXT = "Mostrar texto"
    L.RESET_POSITION = "Reiniciar posicion"
    L.MSG_LOCKED = "Icono bloqueado."
    L.MSG_UNLOCKED = "Icono desbloqueado. Arrastra para mover."
    L.MSG_POSITION_RESET = "Posicion reiniciada."
    L.MSG_TEST_ON = "Modo TEST activado (se muestra sin checks)."
    L.MSG_TEST_OFF = "Modo TEST desactivado."
    L.MSG_MODE_DUMMY = "Modo DUMMY: cuenta todos los enemigos con nameplate visible."
    L.MSG_MODE_REAL = "Modo REAL: cuenta solo enemigos en combate/con threat."
    L.MSG_MODE_CURRENT = "Modo actual:"
    L.MSG_MODE_USAGE = "Usa: /aoedk mode dummy  o  /aoedk mode real"
    L.DEBUG_CLASS = "Class ID"
    L.DEBUG_SPEC = "Spec Index"
    L.DEBUG_COMBAT = "En combate"
    L.DEBUG_ARMY = "Ejercito activo"
    L.DEBUG_ENEMIES = "Enemigos detectados"
    L.DEBUG_MODE = "Modo"
    L.DEBUG_VISIBLE = "Frame visible"
    L.BUFFS_ACTIVE = "BUFFS activos:"
    L.DEBUFFS_ACTIVE = "DEBUFFS activos:"
end

-- Spell IDs
local DEATH_COIL_ID   = 47541       -- Espiral de la Muerte
local EPIDEMIC_ID     = 207317      -- Epidemia
local NECROTIC_COIL_ID = 434179     -- Necrotic Coil (mejorado con Ejercito)
local GRAVEYARD_ID    = 458714      -- Graveyard (mejorado con Ejercito)

-- Army of the Dead - ID del buff
local ARMY_BUFF_ID = 1242223

-- Config
local UPDATE_INTERVAL = 0.15      -- Segundos entre actualizaciones
local ICON_SIZE = 64              -- Tamaño del icono en pixeles
local ICON_ALPHA = 1.0            -- Transparencia del icono (0.1 a 1.0)

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
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Guardar posicion
    local point, _, relPoint, x, y = self:GetPoint()
    AoeDKDB = AoeDKDB or {}
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

-- Estado de unlock (ancla visible para localizar y mover)
local isUnlocked = false

-- Declaradas antes de ShowAnchor/HideAnchor para que ambas funciones capturen los locales correctos
local currentSpellID = nil
local forceShow = false       -- para /aoedk test
local detectionMode = "real"  -- "real" o "dummy"

-- Cache de clase/spec: no cambian durante combate, se actualizan via PLAYER_SPECIALIZATION_CHANGED
local cachedClassID   = nil
local cachedSpecIndex = nil
local function RefreshClassSpec()
    local _, _, classID = UnitClass("player")
    cachedClassID   = classID
    cachedSpecIndex = GetSpecialization()
end

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
    frame:EnableMouse(true)
    frame:Show()
end

local function HideAnchor()
    isUnlocked = false
    AoeDKDB = AoeDKDB or {}
    icon:SetAlpha(AoeDKDB.iconAlpha or ICON_ALPHA)
    countText:SetText("")
    spellText:SetText("")
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
    currentSpellID = nil
    if AoeDKDB and AoeDKDB.showText == false then
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
    AoeDKDB = AoeDKDB or {}
    AoeDKDB.iconSize = size
end

local function ApplyIconAlpha(alpha)
    alpha = math.max(0.1, math.min(1.0, alpha))
    -- Redondear a 1 decimal
    alpha = math.floor(alpha * 10 + 0.5) / 10
    AoeDKDB = AoeDKDB or {}
    AoeDKDB.iconAlpha = alpha
    if not isUnlocked then
        icon:SetAlpha(alpha)
    end
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
-- Detectar si Ejercito de los Muertos esta activo
---------------------------------------------------------------------------
local function IsArmyActive()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(ARMY_BUFF_ID)
    return aura ~= nil
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
    local armyUp = IsArmyActive()

    if armyUp then
        -- Con Ejercito de los Muertos: habilidades mejoradas
        if enemyCount >= 5 then
            spellID = GRAVEYARD_ID
        elseif enemyCount >= 4 then
            spellID = NECROTIC_COIL_ID
        elseif enemyCount >= 3 then
            spellID = EPIDEMIC_ID
        else
            spellID = DEATH_COIL_ID
        end
    else
        -- Sin Ejercito: normal
        if enemyCount >= 4 then
            spellID = EPIDEMIC_ID
        else
            spellID = DEATH_COIL_ID
        end
    end

    -- Actualizar textura solo si cambio
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

    if not AoeDKDB or AoeDKDB.showText ~= false then
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
        -- Restaurar posicion guardada
        AoeDKDB = AoeDKDB or {}
        if AoeDKDB.point then
            frame:ClearAllPoints()
            frame:SetPoint(AoeDKDB.point, UIParent, AoeDKDB.relPoint, AoeDKDB.x, AoeDKDB.y)
        end
        if AoeDKDB.iconSize then
            frame:SetSize(AoeDKDB.iconSize, AoeDKDB.iconSize)
        end
        if AoeDKDB.iconAlpha then
            icon:SetAlpha(AoeDKDB.iconAlpha)
        end
        if AoeDKDB.showText == false then
            countText:Hide()
            spellText:Hide()
        end
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
        -- Salir de combate: ocultar (salvo si forceShow o unlock)
        if not forceShow and not isUnlocked then
            StopTicker()
            frame:Hide()
            currentSpellID = nil
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entrar en combate: iniciar ticker
        StartTicker()
        UpdateIcon()
    else
        -- Cubre PLAYER_SPECIALIZATION_CHANGED y PLAYER_ENTERING_WORLD
        RefreshClassSpec()
        UpdateIcon()
    end
end)

frame:Hide()

---------------------------------------------------------------------------
-- Panel de opciones
---------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AoeDKOptionsPanel", UIParent, "BackdropTemplate")
optionsPanel:SetSize(240, 310)
optionsPanel:SetPoint("CENTER")
optionsPanel:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
optionsPanel:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
optionsPanel:SetBackdropBorderColor(0, 0.6, 0.8, 1)
optionsPanel:SetFrameStrata("DIALOG")
optionsPanel:SetMovable(true)
optionsPanel:EnableMouse(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", optionsPanel.StartMoving)
optionsPanel:SetScript("OnDragStop", optionsPanel.StopMovingOrSizing)
optionsPanel:Hide()

local panelTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOP", 0, -12)
panelTitle:SetText(L.OPTIONS_TITLE)

local closeBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

-- Boton mover icono
local moveBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
moveBtn:SetSize(200, 26)
moveBtn:SetPoint("TOP", 0, -42)

local function UpdateMoveBtnText()
    moveBtn:SetText(isUnlocked and L.LOCK_ICON or L.MOVE_ICON)
end
UpdateMoveBtnText()

moveBtn:SetScript("OnClick", function()
    if isUnlocked then
        HideAnchor()
        frame:EnableMouse(false)
    else
        ShowAnchor()
    end
    UpdateMoveBtnText()
end)

-- Seccion tamano
local sizeLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sizeLabel:SetPoint("TOP", moveBtn, "BOTTOM", 0, -14)
sizeLabel:SetText(L.ICON_SIZE)

local sizeValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sizeValue:SetPoint("TOP", sizeLabel, "BOTTOM", 0, -6)

local function UpdateSizeValue()
    AoeDKDB = AoeDKDB or {}
    sizeValue:SetText(tostring(AoeDKDB.iconSize or ICON_SIZE) .. " px")
end
UpdateSizeValue()

local sizeDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
sizeDown:SetSize(36, 24)
sizeDown:SetPoint("RIGHT", sizeValue, "LEFT", -10, 0)
sizeDown:SetText("-")
sizeDown:SetScript("OnClick", function()
    AoeDKDB = AoeDKDB or {}
    local s = math.max(32, (AoeDKDB.iconSize or ICON_SIZE) - 8)
    ApplyIconSize(s)
    UpdateSizeValue()
end)

local sizeUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
sizeUp:SetSize(36, 24)
sizeUp:SetPoint("LEFT", sizeValue, "RIGHT", 10, 0)
sizeUp:SetText("+")
sizeUp:SetScript("OnClick", function()
    AoeDKDB = AoeDKDB or {}
    local s = math.min(128, (AoeDKDB.iconSize or ICON_SIZE) + 8)
    ApplyIconSize(s)
    UpdateSizeValue()
end)

-- Seccion transparencia
local alphaLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
alphaLabel:SetPoint("TOP", sizeValue, "BOTTOM", 0, -14)
alphaLabel:SetText(L.ICON_TRANSPARENCY)

local alphaValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
alphaValue:SetPoint("TOP", alphaLabel, "BOTTOM", 0, -6)

local function UpdateAlphaValue()
    AoeDKDB = AoeDKDB or {}
    local a = AoeDKDB.iconAlpha or ICON_ALPHA
    alphaValue:SetText(tostring(math.floor(a * 100 + 0.5)) .. "%%")
end
UpdateAlphaValue()

local alphaDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
alphaDown:SetSize(36, 24)
alphaDown:SetPoint("RIGHT", alphaValue, "LEFT", -10, 0)
alphaDown:SetText("-")
alphaDown:SetScript("OnClick", function()
    AoeDKDB = AoeDKDB or {}
    local a = math.max(0.1, (AoeDKDB.iconAlpha or ICON_ALPHA) - 0.1)
    ApplyIconAlpha(a)
    UpdateAlphaValue()
end)

local alphaUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
alphaUp:SetSize(36, 24)
alphaUp:SetPoint("LEFT", alphaValue, "RIGHT", 10, 0)
alphaUp:SetText("+")
alphaUp:SetScript("OnClick", function()
    AoeDKDB = AoeDKDB or {}
    local a = math.min(1.0, (AoeDKDB.iconAlpha or ICON_ALPHA) + 0.1)
    ApplyIconAlpha(a)
    UpdateAlphaValue()
end)

-- Boton mostrar/ocultar texto
local textBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
textBtn:SetSize(200, 26)
textBtn:SetPoint("TOP", alphaValue, "BOTTOM", 0, -14)

local function UpdateTextBtnLabel()
    AoeDKDB = AoeDKDB or {}
    local show = AoeDKDB.showText ~= false
    textBtn:SetText(show and L.HIDE_TEXT or L.SHOW_TEXT)
end
UpdateTextBtnLabel()

textBtn:SetScript("OnClick", function()
    AoeDKDB = AoeDKDB or {}
    local show = AoeDKDB.showText ~= false
    AoeDKDB.showText = not show
    if AoeDKDB.showText then
        countText:Show()
        spellText:Show()
    else
        countText:Hide()
        spellText:Hide()
    end
    UpdateTextBtnLabel()
end)

-- Boton reset posicion
local resetBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
resetBtn:SetSize(200, 26)
resetBtn:SetPoint("TOP", textBtn, "BOTTOM", 0, -10)
resetBtn:SetText(L.RESET_POSITION)
resetBtn:SetScript("OnClick", function()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    AoeDKDB = {}
    print("|cff00ccff[AoE DK]|r " .. L.MSG_POSITION_RESET)
end)

local function ToggleOptionsPanel()
    if optionsPanel:IsShown() then
        optionsPanel:Hide()
    else
        UpdateMoveBtnText()
        UpdateSizeValue()
        UpdateAlphaValue()
        UpdateTextBtnLabel()
        optionsPanel:Show()
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_AOEDK1 = "/aoedk"
SlashCmdList["AOEDK"] = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg), 2)
    cmd = strlower(cmd or "")

    if cmd == "lock" then
        HideAnchor()
        frame:EnableMouse(false)
        print("|cff00ccff[AoE DK]|r " .. L.MSG_LOCKED)
    elseif cmd == "unlock" then
        ShowAnchor()
        print("|cff00ccff[AoE DK]|r " .. L.MSG_UNLOCKED)
    elseif cmd == "reset" then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        AoeDKDB = {}
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
        local armyUp = IsArmyActive()
        print("|cff00ccff[AoE DK] DEBUG:|r")
        print("  " .. L.DEBUG_CLASS .. ": " .. tostring(classID) .. " (necesita 6=DK)")
        print("  " .. L.DEBUG_SPEC .. ": " .. tostring(specIndex) .. " (necesita 3=Unholy)")
        print("  " .. L.DEBUG_COMBAT .. ": " .. tostring(inCombat))
        print("  " .. L.DEBUG_ARMY .. ": " .. tostring(armyUp))
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
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            print("  [" .. (aura.spellId or "?") .. "] " .. (aura.name or "?") .. " (quedan " .. string.format("%.1f", (aura.expirationTime or 0) - GetTime()) .. "s)")
        end
        print("|cff00ccff[AoE DK] " .. L.DEBUFFS_ACTIVE .. "|r")
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL")
            if not aura then break end
            print("  [" .. (aura.spellId or "?") .. "] " .. (aura.name or "?"))
        end
    elseif cmd == "mode" then
        if arg == "dummy" then
            detectionMode = "dummy"
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_DUMMY)
        elseif arg == "real" then
            detectionMode = "real"
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_REAL)
        else
            print("|cff00ccff[AoE DK]|r " .. L.MSG_MODE_CURRENT .. " |cffffff00" .. detectionMode .. "|r")
            print("  " .. L.MSG_MODE_USAGE)
        end
    else
        ToggleOptionsPanel()
    end
end
