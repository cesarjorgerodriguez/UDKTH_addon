local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------
local A   = { r=0.380, g=0.949, b=0.659 }
local W   = { r=0.910, g=0.925, b=0.940 }
local LBL = { r=0.430, g=0.450, b=0.470 }
local BG  = { r=0.065, g=0.075, b=0.085 }
local BH  = { r=0.100, g=0.115, b=0.140 }
local BB  = { r=0.115, g=0.130, b=0.155 }
local BBH = { r=0.150, g=0.170, b=0.205 }
local BD  = { r=0.170, g=0.190, b=0.215 }
local SH  = { r=0.090, g=0.103, b=0.125 }

local BD_FLAT = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left=0, right=0, top=0, bottom=0 },
}

---------------------------------------------------------------------------
-- Layout constants
---------------------------------------------------------------------------
local PANEL_W  = 258
local HEADER_H = 44
local PAD_BOT  = 14
local INDENT   = 14

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local optionsPanel = CreateFrame("Frame", "AoeDKOptionsPanel", UIParent, "BackdropTemplate")
optionsPanel:SetSize(PANEL_W, 500)
optionsPanel:SetPoint("CENTER")
optionsPanel:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left=1, right=1, top=1, bottom=1 },
})
optionsPanel:SetBackdropColor(BG.r, BG.g, BG.b, 0.98)
optionsPanel:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.7)
optionsPanel:SetFrameStrata("DIALOG")
optionsPanel:SetMovable(true)
optionsPanel:EnableMouse(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", optionsPanel.StartMoving)
optionsPanel:SetScript("OnDragStop", optionsPanel.StopMovingOrSizing)
optionsPanel:Hide()
tinsert(UISpecialFrames, "AoeDKOptionsPanel")

optionsPanel:SetScript("OnHide", function()
    if ns.IsUnlocked() then ns.HideAnchor() end
end)

-- Header
local headerBg = optionsPanel:CreateTexture(nil, "BACKGROUND")
headerBg:SetPoint("TOPLEFT", 1, -1)
headerBg:SetPoint("TOPRIGHT", -1, -1)
headerBg:SetHeight(HEADER_H)
headerBg:SetColorTexture(BH.r, BH.g, BH.b, 1)

local headerLine = optionsPanel:CreateTexture(nil, "ARTWORK")
headerLine:SetPoint("TOPLEFT", 1, -(HEADER_H + 1))
headerLine:SetPoint("TOPRIGHT", -1, -(HEADER_H + 1))
headerLine:SetHeight(1)
headerLine:SetColorTexture(A.r, A.g, A.b, 0.35)

local headerIcon = optionsPanel:CreateTexture(nil, "OVERLAY")
headerIcon:SetSize(22, 22)
headerIcon:SetPoint("TOPLEFT", 10, -11)
headerIcon:SetTexture("Interface\\Icons\\Spell_DeathKnight_FesteringStrike")
headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local panelTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
panelTitle:SetPoint("TOP", 0, -14)
panelTitle:SetText(L.OPTIONS_TITLE)

local closeBtn = CreateFrame("Button", nil, optionsPanel)
closeBtn:SetSize(20, 20)
closeBtn:SetPoint("TOPRIGHT", -8, -12)
local closeTex = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeTex:SetAllPoints()
closeTex:SetText("X")
closeTex:SetTextColor(LBL.r, LBL.g, LBL.b)
closeBtn:SetScript("OnEnter", function() closeTex:SetTextColor(0.95, 0.28, 0.22) end)
closeBtn:SetScript("OnLeave", function() closeTex:SetTextColor(LBL.r, LBL.g, LBL.b) end)
closeBtn:SetScript("OnClick", function() optionsPanel:Hide() end)

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------
local function MakeStepButton(parent, label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(28, 24)
    btn:SetBackdrop(BD_FLAT)
    btn:SetBackdropColor(BB.r, BB.g, BB.b, 1)
    btn:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.4)
    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetAllPoints()
    t:SetText(label)
    t:SetTextColor(W.r, W.g, W.b)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(BBH.r, BBH.g, BBH.b, 1)
        self:SetBackdropBorderColor(A.r, A.g, A.b, 0.85)
        t:SetTextColor(A.r, A.g, A.b)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(BB.r, BB.g, BB.b, 1)
        self:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.4)
        t:SetTextColor(W.r, W.g, W.b)
    end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(0.07, 0.08, 0.10, 1) end)
    btn:SetScript("OnMouseUp",   function(self) self:SetBackdropColor(BBH.r, BBH.g, BBH.b, 1) end)
    return btn
end

local function MakeWideButton(parent, text, anchorAbove, gap)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(28)
    btn:SetPoint("TOPLEFT",  anchorAbove, "BOTTOMLEFT",  0, -(gap or 10))
    btn:SetPoint("TOPRIGHT", anchorAbove, "BOTTOMRIGHT", 0, -(gap or 10))
    btn:SetBackdrop(BD_FLAT)
    btn:SetBackdropColor(BB.r, BB.g, BB.b, 1)
    btn:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.4)
    local bar = btn:CreateTexture(nil, "OVERLAY")
    bar:SetSize(2, 18)
    bar:SetPoint("LEFT", 0, 0)
    bar:SetColorTexture(A.r, A.g, A.b, 0)
    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", 1, 0)
    t:SetPoint("BOTTOMRIGHT", -1, 0)
    t:SetJustifyH("CENTER")
    t:SetText(text)
    t:SetTextColor(W.r, W.g, W.b)
    btn._label = t
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(BBH.r, BBH.g, BBH.b, 1)
        self:SetBackdropBorderColor(A.r, A.g, A.b, 0.4)
        bar:SetColorTexture(A.r, A.g, A.b, 1)
        t:SetTextColor(A.r, A.g, A.b)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(BB.r, BB.g, BB.b, 1)
        self:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.4)
        bar:SetColorTexture(A.r, A.g, A.b, 0)
        t:SetTextColor(W.r, W.g, W.b)
    end)
    btn:SetScript("OnMouseDown", function(self) self:SetBackdropColor(0.07, 0.08, 0.10, 1) end)
    btn:SetScript("OnMouseUp",   function(self) self:SetBackdropColor(BBH.r, BBH.g, BBH.b, 1) end)
    btn.SetText = function(self, txt) self._label:SetText(txt) end
    btn.GetText = function(self)      return self._label:GetText() end
    return btn
end

local function MakeSeparator(parent, anchorAbove, gap)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  anchorAbove, "BOTTOMLEFT",  0, -(gap or 10))
    line:SetPoint("TOPRIGHT", anchorAbove, "BOTTOMRIGHT", 0, -(gap or 10))
    line:SetColorTexture(BD.r, BD.g, BD.b, 0.35)
    return line
end

---------------------------------------------------------------------------
-- Row: label + value + step buttons + separator
-- Anchors BELOW anchorAbove with `gap` px spacing.
-- Returns: container (invisible frame, height = total row), val, dn, up
-- Container is used as anchor for the next element.
---------------------------------------------------------------------------
local function MakeRow(parent, anchorAbove, gap, labelText)
    -- Fixed-height container so we can chain anchors reliably
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(52)
    row:SetPoint("TOPLEFT",  anchorAbove, "BOTTOMLEFT",  0, -(gap or 10))
    row:SetPoint("TOPRIGHT", anchorAbove, "BOTTOMRIGHT", 0, -(gap or 10))

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOP", row, "TOP", 0, -2)
    lbl:SetText(labelText)
    lbl:SetTextColor(LBL.r, LBL.g, LBL.b)

    local val = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("TOP", lbl, "BOTTOM", 0, -6)
    val:SetTextColor(A.r, A.g, A.b)

    local dn = MakeStepButton(row, "-")
    dn:SetPoint("RIGHT", val, "LEFT", -14, 0)

    local up = MakeStepButton(row, "+")
    up:SetPoint("LEFT", val, "RIGHT", 14, 0)

    -- Separator at bottom of the row
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    sep:SetColorTexture(BD.r, BD.g, BD.b, 0.35)

    return row, val, dn, up
end

---------------------------------------------------------------------------
-- Collapsible sections
---------------------------------------------------------------------------
local sections = {}

local function RecalcLayout()
    local cursor = HEADER_H + 8
    for _, sec in ipairs(sections) do
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT",  optionsPanel, "TOPLEFT",  1, -cursor)
        sec.header:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -1, -cursor)
        cursor = cursor + sec.header:GetHeight()
        if sec.open then
            sec.body:Show()
            sec.body:ClearAllPoints()
            sec.body:SetPoint("TOPLEFT",  optionsPanel, "TOPLEFT",  0, -cursor)
            sec.body:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", 0, -cursor)
            cursor = cursor + sec.body:GetHeight()
        else
            sec.body:Hide()
        end
        cursor = cursor + 2
    end
    optionsPanel:SetHeight(cursor + PAD_BOT)
end

local function MakeSection(labelText, startOpen)
    local sec = { open = startOpen == true }

    local hdr = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
    hdr:SetHeight(30)
    hdr:SetBackdrop(BD_FLAT)
    hdr:SetBackdropColor(SH.r, SH.g, SH.b, 1)
    hdr:SetBackdropBorderColor(BD.r, BD.g, BD.b, 0.5)

    local accent = hdr:CreateTexture(nil, "OVERLAY")
    accent:SetSize(2, 16)
    accent:SetPoint("LEFT", 0, 0)
    accent:SetColorTexture(A.r, A.g, A.b, 0.7)

    local arrow = hdr:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", 10, 0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Down")

    local function UpdateArrow()
        arrow:SetRotation(sec.open and 0 or -math.rad(90))
        arrow:SetVertexColor(A.r, A.g, A.b, 1)
    end
    UpdateArrow()

    local lbl = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", 28, 0)
    lbl:SetText(labelText)
    lbl:SetTextColor(W.r, W.g, W.b)

    hdr:SetScript("OnEnter", function(self)
        self:SetBackdropColor(BBH.r, BBH.g, BBH.b, 1)
        lbl:SetTextColor(A.r, A.g, A.b)
    end)
    hdr:SetScript("OnLeave", function(self)
        self:SetBackdropColor(SH.r, SH.g, SH.b, 1)
        lbl:SetTextColor(W.r, W.g, W.b)
    end)
    hdr:SetScript("OnClick", function()
        sec.open = not sec.open
        UpdateArrow()
        RecalcLayout()
    end)

    sec.header = hdr

    local body = CreateFrame("Frame", nil, optionsPanel)
    body:SetHeight(10)
    sec.body = body
    sections[#sections + 1] = sec
    return sec
end

---------------------------------------------------------------------------
-- Helper: invisible anchor at the top of a body for chaining
---------------------------------------------------------------------------
local function MakeTopAnchor(body)
    local anchor = CreateFrame("Frame", nil, body)
    anchor:SetHeight(1)
    anchor:SetPoint("TOPLEFT",  body, "TOPLEFT",  INDENT, 0)
    anchor:SetPoint("TOPRIGHT", body, "TOPRIGHT", -INDENT, 0)
    return anchor
end

---------------------------------------------------------------------------
-- SECTION 1: Icono y Posicion  (OPEN)
---------------------------------------------------------------------------
local secIcon = MakeSection(L.SECTION_ICON, true)
local bodyIcon = secIcon.body
local topAnchor1 = MakeTopAnchor(bodyIcon)

local moveBtn = MakeWideButton(bodyIcon, "", topAnchor1, 10)
local function UpdateMoveBtnText()
    moveBtn:SetText(ns.IsUnlocked() and L.LOCK_ICON or L.MOVE_ICON)
end
UpdateMoveBtnText()
moveBtn:SetScript("OnClick", function()
    if ns.IsUnlocked() then ns.HideAnchor() else ns.ShowAnchor() end
    UpdateMoveBtnText()
end)

local resetBtn = MakeWideButton(bodyIcon, L.RESET_POSITION, moveBtn, 8)
resetBtn:SetScript("OnClick", function()
    ns.frame:ClearAllPoints()
    ns.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    AoeDKDB.point = nil; AoeDKDB.relPoint = nil; AoeDKDB.x = nil; AoeDKDB.y = nil
    print("|cff61F2A8[AoE DK]|r " .. L.MSG_POSITION_RESET)
end)

local sizeRow, sizeValue, sizeDown, sizeUp = MakeRow(bodyIcon, resetBtn, 10, L.ICON_SIZE)
local function UpdateSizeValue()
    sizeValue:SetText(tostring(AoeDKDB.iconSize) .. " px")
end
sizeDown:SetScript("OnClick", function()
    ns.ApplyIconSize(math.max(32, AoeDKDB.iconSize - 8)); UpdateSizeValue()
end)
sizeUp:SetScript("OnClick", function()
    ns.ApplyIconSize(math.min(128, AoeDKDB.iconSize + 8)); UpdateSizeValue()
end)

local alphaRow, alphaValue, alphaDown, alphaUp = MakeRow(bodyIcon, sizeRow, 6, L.ICON_TRANSPARENCY)
local function UpdateAlphaValue()
    alphaValue:SetText(tostring(math.floor(AoeDKDB.iconAlpha * 100 + 0.5)) .. "%%")
end
alphaDown:SetScript("OnClick", function()
    ns.ApplyIconAlpha(math.max(0.1, AoeDKDB.iconAlpha - 0.1)); UpdateAlphaValue()
end)
alphaUp:SetScript("OnClick", function()
    ns.ApplyIconAlpha(math.min(1.0, AoeDKDB.iconAlpha + 0.1)); UpdateAlphaValue()
end)

local borderRow, borderValue, borderDown, borderUp = MakeRow(bodyIcon, alphaRow, 6, L.BORDER_SIZE)
local function UpdateBorderValue()
    borderValue:SetText(tostring(AoeDKDB.borderSize) .. " px")
end
borderDown:SetScript("OnClick", function()
    ns.ApplyBorderSize(AoeDKDB.borderSize - 1); UpdateBorderValue()
end)
borderUp:SetScript("OnClick", function()
    ns.ApplyBorderSize(AoeDKDB.borderSize + 1); UpdateBorderValue()
end)

-- Body height: 10(top) + 28(moveBtn) + 8 + 28(resetBtn) + 10 + 52*3(rows) + 6*2(gaps) + 10(bot)
bodyIcon:SetHeight(10 + 28 + 8 + 28 + 10 + 52 + 6 + 52 + 6 + 52 + 10)

---------------------------------------------------------------------------
-- SECTION 2: Visualizacion  (CLOSED)
---------------------------------------------------------------------------
local secCfg = MakeSection(L.SECTION_CONFIG, false)
local bodyCfg = secCfg.body
local topAnchor2 = MakeTopAnchor(bodyCfg)

local textBtn = MakeWideButton(bodyCfg, "", topAnchor2, 10)
local function UpdateTextBtnLabel()
    textBtn:SetText(AoeDKDB.showText and L.HIDE_TEXT or L.SHOW_TEXT)
end
textBtn:SetScript("OnClick", function()
    AoeDKDB.showText = not AoeDKDB.showText
    if AoeDKDB.showText then ns.countText:Show(); ns.spellText:Show()
    else ns.countText:Hide(); ns.spellText:Hide() end
    UpdateTextBtnLabel()
end)

bodyCfg:SetHeight(10 + 28 + 12)

---------------------------------------------------------------------------
-- SECTION 3: Umbrales  (CLOSED)
---------------------------------------------------------------------------
local secThr = MakeSection(L.SECTION_THRESHOLDS, false)
local bodyThr = secThr.body
local topAnchor3 = MakeTopAnchor(bodyThr)

local thrRow, thresholdValue, thresholdDown, thresholdUp = MakeRow(bodyThr, topAnchor3, 8, L.EPIDEMIC_THRESHOLD)
local function UpdateThresholdValue()
    thresholdValue:SetText(tostring(AoeDKDB.epidemicThreshold) .. "+ " .. L.ENEMIES)
end
thresholdDown:SetScript("OnClick", function()
    AoeDKDB.epidemicThreshold = math.max(2, AoeDKDB.epidemicThreshold - 1)
    ns.ResetCurrentSpell(); UpdateThresholdValue()
end)
thresholdUp:SetScript("OnClick", function()
    AoeDKDB.epidemicThreshold = math.min(10, AoeDKDB.epidemicThreshold + 1)
    ns.ResetCurrentSpell(); UpdateThresholdValue()
end)

local thrFKRow, thresholdFKValue, thresholdFKDown, thresholdFKUp = MakeRow(bodyThr, thrRow, 6, L.EPIDEMIC_THRESHOLD_FK)
local function UpdateThresholdFKValue()
    thresholdFKValue:SetText(tostring(AoeDKDB.epidemicThresholdFK) .. "+ " .. L.ENEMIES)
end
thresholdFKDown:SetScript("OnClick", function()
    AoeDKDB.epidemicThresholdFK = math.max(2, AoeDKDB.epidemicThresholdFK - 1)
    ns.ResetCurrentSpell(); UpdateThresholdFKValue()
end)
thresholdFKUp:SetScript("OnClick", function()
    AoeDKDB.epidemicThresholdFK = math.min(10, AoeDKDB.epidemicThresholdFK + 1)
    ns.ResetCurrentSpell(); UpdateThresholdFKValue()
end)

bodyThr:SetHeight(8 + 52 + 6 + 52 + 10)

---------------------------------------------------------------------------
RecalcLayout()

---------------------------------------------------------------------------
-- Toggle
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