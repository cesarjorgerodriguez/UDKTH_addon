local _, ns = ...

local L = ns.L

---------------------------------------------------------------------------
-- Panel de opciones
---------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AoeDKOptionsPanel", UIParent, "BackdropTemplate")
optionsPanel:SetSize(240, 460)
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
tinsert(UISpecialFrames, "AoeDKOptionsPanel")

-- Si el panel se cierra mientras el icono esta en modo mover, bloquear automaticamente (guarda posicion)
optionsPanel:SetScript("OnHide", function()
    if ns.IsUnlocked() then
        ns.HideAnchor()
    end
end)

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
    moveBtn:SetText(ns.IsUnlocked() and L.LOCK_ICON or L.MOVE_ICON)
end
UpdateMoveBtnText()

moveBtn:SetScript("OnClick", function()
    if ns.IsUnlocked() then
        ns.HideAnchor()
    else
        ns.ShowAnchor()
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
    sizeValue:SetText(tostring(AoeDKDB.iconSize) .. " px")
end

local sizeDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
sizeDown:SetSize(36, 24)
sizeDown:SetPoint("RIGHT", sizeValue, "LEFT", -10, 0)
sizeDown:SetText("-")
sizeDown:SetScript("OnClick", function()
    local s = math.max(32, AoeDKDB.iconSize - 8)
    ns.ApplyIconSize(s)
    UpdateSizeValue()
end)

local sizeUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
sizeUp:SetSize(36, 24)
sizeUp:SetPoint("LEFT", sizeValue, "RIGHT", 10, 0)
sizeUp:SetText("+")
sizeUp:SetScript("OnClick", function()
    local s = math.min(128, AoeDKDB.iconSize + 8)
    ns.ApplyIconSize(s)
    UpdateSizeValue()
end)

-- Seccion transparencia
local alphaLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
alphaLabel:SetPoint("TOP", sizeValue, "BOTTOM", 0, -14)
alphaLabel:SetText(L.ICON_TRANSPARENCY)

local alphaValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
alphaValue:SetPoint("TOP", alphaLabel, "BOTTOM", 0, -6)

local function UpdateAlphaValue()
    alphaValue:SetText(tostring(math.floor(AoeDKDB.iconAlpha * 100 + 0.5)) .. "%%")
end

local alphaDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
alphaDown:SetSize(36, 24)
alphaDown:SetPoint("RIGHT", alphaValue, "LEFT", -10, 0)
alphaDown:SetText("-")
alphaDown:SetScript("OnClick", function()
    local a = math.max(0.1, AoeDKDB.iconAlpha - 0.1)
    ns.ApplyIconAlpha(a)
    UpdateAlphaValue()
end)

local alphaUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
alphaUp:SetSize(36, 24)
alphaUp:SetPoint("LEFT", alphaValue, "RIGHT", 10, 0)
alphaUp:SetText("+")
alphaUp:SetScript("OnClick", function()
    local a = math.min(1.0, AoeDKDB.iconAlpha + 0.1)
    ns.ApplyIconAlpha(a)
    UpdateAlphaValue()
end)

-- Seccion grosor del borde
local borderLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
borderLabel:SetPoint("TOP", alphaValue, "BOTTOM", 0, -14)
borderLabel:SetText(L.BORDER_SIZE)

local borderValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
borderValue:SetPoint("TOP", borderLabel, "BOTTOM", 0, -6)

local function UpdateBorderValue()
    borderValue:SetText(tostring(AoeDKDB.borderSize) .. " px")
end

local borderDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
borderDown:SetSize(36, 24)
borderDown:SetPoint("RIGHT", borderValue, "LEFT", -10, 0)
borderDown:SetText("-")
borderDown:SetScript("OnClick", function()
    ns.ApplyBorderSize(AoeDKDB.borderSize - 1)
    UpdateBorderValue()
end)

local borderUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
borderUp:SetSize(36, 24)
borderUp:SetPoint("LEFT", borderValue, "RIGHT", 10, 0)
borderUp:SetText("+")
borderUp:SetScript("OnClick", function()
    ns.ApplyBorderSize(AoeDKDB.borderSize + 1)
    UpdateBorderValue()
end)

-- Boton mostrar/ocultar texto
local textBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
textBtn:SetSize(200, 26)
textBtn:SetPoint("TOP", borderValue, "BOTTOM", 0, -14)

local function UpdateTextBtnLabel()
    textBtn:SetText(AoeDKDB.showText and L.HIDE_TEXT or L.SHOW_TEXT)
end

textBtn:SetScript("OnClick", function()
    AoeDKDB.showText = not AoeDKDB.showText
    if AoeDKDB.showText then
        ns.countText:Show()
        ns.spellText:Show()
    else
        ns.countText:Hide()
        ns.spellText:Hide()
    end
    UpdateTextBtnLabel()
end)

-- Seccion umbral de Epidemia (sin Forbidden Knowledge)
local thresholdLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
thresholdLabel:SetPoint("TOP", textBtn, "BOTTOM", 0, -14)
thresholdLabel:SetText(L.EPIDEMIC_THRESHOLD)

local thresholdValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
thresholdValue:SetPoint("TOP", thresholdLabel, "BOTTOM", 0, -6)

local function UpdateThresholdValue()
    thresholdValue:SetText(tostring(AoeDKDB.epidemicThreshold) .. "+ " .. L.ENEMIES)
end

local thresholdDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
thresholdDown:SetSize(36, 24)
thresholdDown:SetPoint("RIGHT", thresholdValue, "LEFT", -10, 0)
thresholdDown:SetText("-")
thresholdDown:SetScript("OnClick", function()
    local t = math.max(2, AoeDKDB.epidemicThreshold - 1)
    AoeDKDB.epidemicThreshold = t
    ns.ResetCurrentSpell()
    UpdateThresholdValue()
end)

local thresholdUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
thresholdUp:SetSize(36, 24)
thresholdUp:SetPoint("LEFT", thresholdValue, "RIGHT", 10, 0)
thresholdUp:SetText("+")
thresholdUp:SetScript("OnClick", function()
    local t = math.min(10, AoeDKDB.epidemicThreshold + 1)
    AoeDKDB.epidemicThreshold = t
    ns.ResetCurrentSpell()
    UpdateThresholdValue()
end)

-- Seccion umbral con Forbidden Knowledge
local thresholdFKLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
thresholdFKLabel:SetPoint("TOP", thresholdValue, "BOTTOM", 0, -14)
thresholdFKLabel:SetText(L.EPIDEMIC_THRESHOLD_FK)

local thresholdFKValue = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
thresholdFKValue:SetPoint("TOP", thresholdFKLabel, "BOTTOM", 0, -6)

local function UpdateThresholdFKValue()
    thresholdFKValue:SetText(tostring(AoeDKDB.epidemicThresholdFK) .. "+ " .. L.ENEMIES)
end

local thresholdFKDown = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
thresholdFKDown:SetSize(36, 24)
thresholdFKDown:SetPoint("RIGHT", thresholdFKValue, "LEFT", -10, 0)
thresholdFKDown:SetText("-")
thresholdFKDown:SetScript("OnClick", function()
    local t = math.max(2, AoeDKDB.epidemicThresholdFK - 1)
    AoeDKDB.epidemicThresholdFK = t
    ns.ResetCurrentSpell()
    UpdateThresholdFKValue()
end)

local thresholdFKUp = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
thresholdFKUp:SetSize(36, 24)
thresholdFKUp:SetPoint("LEFT", thresholdFKValue, "RIGHT", 10, 0)
thresholdFKUp:SetText("+")
thresholdFKUp:SetScript("OnClick", function()
    local t = math.min(10, AoeDKDB.epidemicThresholdFK + 1)
    AoeDKDB.epidemicThresholdFK = t
    ns.ResetCurrentSpell()
    UpdateThresholdFKValue()
end)

-- Boton reset posicion
local resetBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
resetBtn:SetSize(200, 26)
resetBtn:SetPoint("TOP", thresholdFKValue, "BOTTOM", 0, -10)
resetBtn:SetText(L.RESET_POSITION)
resetBtn:SetScript("OnClick", function()
    ns.frame:ClearAllPoints()
    ns.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    AoeDKDB.point    = nil
    AoeDKDB.relPoint = nil
    AoeDKDB.x        = nil
    AoeDKDB.y        = nil
    print("|cff00ccff[AoE DK]|r " .. L.MSG_POSITION_RESET)
end)

---------------------------------------------------------------------------
-- Toggle (expuesto via ns para slash commands)
---------------------------------------------------------------------------
local function ToggleOptionsPanel()
    if optionsPanel:IsShown() then
        optionsPanel:Hide()
    else
        UpdateMoveBtnText()
        UpdateSizeValue()
        UpdateAlphaValue()
        UpdateBorderValue()
        UpdateTextBtnLabel()
        UpdateThresholdValue()
        UpdateThresholdFKValue()
        optionsPanel:Show()
    end
end

ns.ToggleOptionsPanel = ToggleOptionsPanel
