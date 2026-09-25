--[[
  Options window styled after EllesmereUI, with a Tiny Threat-style designer.
]]

local MP = _G.MissingPower
if not MP then
	return
end

local UIFont = "Fonts\\ARIALN.TTF"
local openMenu

local function Accent()
	if EllesmereUI then
		if EllesmereUI.GetAccentColor then
			local r, g, b = EllesmereUI.GetAccentColor()
			if r then
				return r, g, b
			end
		end
		if EllesmereUI.DEFAULT_ACCENT_R then
			return EllesmereUI.DEFAULT_ACCENT_R, EllesmereUI.DEFAULT_ACCENT_G, EllesmereUI.DEFAULT_ACCENT_B
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

local function HideMenu()
	if openMenu then
		openMenu:Hide()
		openMenu = nil
	end
end

local function Fill(frame, r, g, b, a)
	local tex = frame:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetColorTexture(r, g, b, a or 1)
	return tex
end

local function Border(frame, r, g, b, a)
	local texs = {}
	local function edge(p1, rp1, p2, rp2, w, h)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(r, g, b, a or 1)
		t:SetPoint(p1, frame, rp1)
		t:SetPoint(p2, frame, rp2)
		if w then
			t:SetWidth(w)
		end
		if h then
			t:SetHeight(h)
		end
		texs[#texs + 1] = t
	end
	edge("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
	edge("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
	edge("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
	edge("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)
	return {
		SetColor = function(_, cr, cg, cb, ca)
			for i = 1, #texs do
				texs[i]:SetColorTexture(cr, cg, cb, ca or 1)
			end
		end,
	}
end

local function Font(parent, size, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	pcall(fs.SetFont, fs, UIFont, size or 13, "")
	fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
	return fs
end

local function Tooltip(frame, title, body)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then
			GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
		end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function Notify()
	if MP.OnOptionChanged then
		MP.OnOptionChanged()
	end
end

local optionsFrame

local function MakeCheck(parent, label, key, tooltip)
	local db = MP.db
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(24)
	local box = CreateFrame("Frame", nil, row)
	box:SetSize(14, 14)
	box:SetPoint("LEFT", row, "LEFT", 0, 0)
	Fill(box, 0.075, 0.113, 0.141, 1)
	local brd = Border(box, 1, 1, 1, 0.25)
	local ar, ag, ab = Accent()
	local check = box:CreateTexture(nil, "ARTWORK")
	check:SetPoint("TOPLEFT", 3, -3)
	check:SetPoint("BOTTOMRIGHT", -3, 3)
	check:SetColorTexture(ar, ag, ab, 1)
	local lbl = Font(row, 13, 1, 1, 1, 0.86)
	lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
	lbl:SetText(label)
	row:SetWidth(14 + 8 + (lbl:GetStringWidth() or 120) + 8)

	local function Paint()
		local on = db[key] and true or false
		check:SetShown(on)
		if on then
			brd:SetColor(ar, ag, ab, 0.85)
		else
			brd:SetColor(1, 1, 1, 0.25)
		end
	end
	Paint()
	row:SetScript("OnClick", function()
		db[key] = not (db[key] and true or false)
		Paint()
		Notify()
	end)
	Tooltip(row, label, tooltip)
	row.Paint = Paint
	return row
end

local function MakeButton(parent, label, width)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width or 120, 26)
	local bg = Fill(btn, 0.10, 0.12, 0.14, 1)
	local brd = Border(btn, ar, ag, ab, 0.35)
	local fs = Font(btn, 12, 1, 1, 1, 0.9)
	fs:SetPoint("CENTER")
	fs:SetText(label)
	btn.label = fs
	btn:SetScript("OnEnter", function()
		bg:SetColorTexture(0.14, 0.16, 0.18, 1)
		brd:SetColor(ar, ag, ab, 0.9)
		fs:SetTextColor(ar, ag, ab, 1)
	end)
	btn:SetScript("OnLeave", function()
		bg:SetColorTexture(0.10, 0.12, 0.14, 1)
		brd:SetColor(ar, ag, ab, 0.35)
		fs:SetTextColor(1, 1, 1, 0.9)
	end)
	btn.SetLabel = function(_, text)
		fs:SetText(text)
	end
	return btn
end

local function MakeDropdown(parent, width, items, getValue, setValue)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(width, 26)
	local bg = Fill(btn, 0.07, 0.09, 0.11, 1)
	local brd = Border(btn, 1, 1, 1, 0.10)
	local lbl = Font(btn, 13, 1, 1, 1, 0.86)
	lbl:SetPoint("LEFT", 12, 0)
	lbl:SetPoint("RIGHT", -22, 0)
	lbl:SetJustifyH("LEFT")
	lbl:SetWordWrap(false)
	local arrow = Font(btn, 10, 1, 1, 1, 0.45)
	arrow:SetPoint("RIGHT", -8, 0)
	arrow:SetText("▼")

	local function CurrentLabel()
		local value = getValue()
		for i = 1, #items do
			if items[i][2] == value then
				return items[i][1]
			end
		end
		return items[1][1]
	end
	lbl:SetText(CurrentLabel())

	local menu = CreateFrame("Frame", nil, UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetToplevel(true)
	menu:SetClampedToScreen(true)
	menu:SetSize(width, 8 + #items * 24)
	Fill(menu, 0.06, 0.08, 0.10, 0.98)
	Border(menu, 1, 1, 1, 0.12)
	menu:Hide()
	menu:EnableMouse(true)

	for i, info in ipairs(items) do
		local item = CreateFrame("Button", nil, menu)
		item:SetHeight(24)
		item:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 24)
		item:SetPoint("TOPRIGHT", -1, -4 - (i - 1) * 24)
		local hl = item:CreateTexture(nil, "ARTWORK")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0)
		local ifs = Font(item, 13, 1, 1, 1, 0.53)
		ifs:SetPoint("LEFT", 10, 0)
		if info[3] then
			pcall(ifs.SetFont, ifs, info[3], 13, "")
		end
		ifs:SetText(info[1])
		item:SetScript("OnEnter", function()
			hl:SetColorTexture(1, 1, 1, 0.06)
			ifs:SetTextColor(1, 1, 1, 1)
		end)
		item:SetScript("OnLeave", function()
			hl:SetColorTexture(1, 1, 1, 0)
			ifs:SetTextColor(1, 1, 1, 0.53)
		end)
		item:SetScript("OnClick", function()
			setValue(info[2])
			lbl:SetText(info[1])
			menu:Hide()
			if openMenu == menu then
				openMenu = nil
			end
		end)
	end

	menu:SetScript("OnUpdate", function(self)
		if not self:IsShown() then
			return
		end
		if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
			if not self:IsMouseOver() and not btn:IsMouseOver() then
				self:Hide()
				if openMenu == self then
					openMenu = nil
				end
			end
		end
	end)

	btn:SetScript("OnEnter", function()
		brd:SetColor(ar, ag, ab, 0.7)
		lbl:SetTextColor(1, 1, 1, 1)
	end)
	btn:SetScript("OnLeave", function()
		brd:SetColor(1, 1, 1, 0.10)
		lbl:SetTextColor(1, 1, 1, 0.86)
	end)
	btn:SetScript("OnClick", function()
		if menu:IsShown() then
			menu:Hide()
			if openMenu == menu then
				openMenu = nil
			end
			return
		end
		HideMenu()
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
		menu:Show()
		openMenu = menu
	end)

	btn.menu = menu
	btn.Refresh = function()
		lbl:SetText(CurrentLabel())
	end
	return btn
end

local function MakeLabeledRow(parent, label)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(34)
	row:SetPoint("LEFT", parent, "LEFT", 20, 0)
	row:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
	local fs = Font(row, 13, 1, 1, 1, 0.9)
	fs:SetPoint("LEFT", 10, 0)
	fs:SetPoint("RIGHT", row, "CENTER", -40, 0)
	fs:SetJustifyH("RIGHT")
	fs:SetText(label)
	row.label = fs
	return row
end

local function OpenColorPicker(r, g, b, a, callback)
	r, g, b, a = r or 1, g or 1, b or 1, a or 1
	HideMenu()
	if not ColorPickerFrame then
		return
	end
	local function apply()
		local nr, ng, nb = r, g, b
		local na = a
		if ColorPickerFrame.GetColorRGB then
			nr, ng, nb = ColorPickerFrame:GetColorRGB()
		end
		if ColorPickerFrame.GetColorAlpha then
			na = ColorPickerFrame:GetColorAlpha()
		elseif OpacitySliderFrame then
			na = 1 - (OpacitySliderFrame:GetValue() or 0)
		end
		callback(nr, ng, nb, na)
	end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r,
			g = g,
			b = b,
			opacity = a,
			hasOpacity = true,
			swatchFunc = apply,
			opacityFunc = apply,
			cancelFunc = function()
				callback(r, g, b, a)
			end,
		})
	else
		ColorPickerFrame.hasOpacity = true
		ColorPickerFrame.opacity = 1 - a
		ColorPickerFrame.func = apply
		ColorPickerFrame.opacityFunc = apply
		ColorPickerFrame.cancelFunc = function()
			callback(r, g, b, a)
		end
		pcall(ColorPickerFrame.SetColorRGB, ColorPickerFrame, r, g, b)
		ColorPickerFrame:Show()
	end
end

local function MakeSwatch(parent, size, getter, setter, tooltip)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(size or 18, size or 18)
	local bg = Fill(btn, 1, 1, 1, 1)
	local brd = Border(btn, 1, 1, 1, 0.28)
	btn:SetScript("OnEnter", function()
		brd:SetColor(ar, ag, ab, 0.95)
		if tooltip then
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			GameTooltip:SetText(tooltip, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	btn:SetScript("OnLeave", function()
		brd:SetColor(1, 1, 1, 0.28)
		GameTooltip:Hide()
	end)
	btn.Paint = function()
		local r, g, b, a = getter()
		bg:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
	end
	btn:SetScript("OnClick", function()
		local r, g, b, a = getter()
		OpenColorPicker(r, g, b, a, function(nr, ng, nb, na)
			setter(nr, ng, nb, na)
			btn:Paint()
		end)
	end)
	btn:Paint()
	return btn
end

local function MakeChip(parent, r, g, b, onClick)
	local ar, ag, ab = Accent()
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(16, 16)
	Fill(btn, r, g, b, 1)
	local brd = Border(btn, 1, 1, 1, 0.22)
	btn:SetScript("OnEnter", function()
		brd:SetColor(ar, ag, ab, 1)
	end)
	btn:SetScript("OnLeave", function()
		brd:SetColor(1, 1, 1, 0.22)
	end)
	btn:SetScript("OnClick", onClick)
	return btn
end

local function CreateOptions()
	if optionsFrame then
		return optionsFrame
	end
	local ar, ag, ab = Accent()
	local selR, selG, selB = 78 / 255, 165 / 255, 252 / 255
	local f = CreateFrame("Frame", "MissingPowerOptions", UIParent)
	f:Hide()
	f:SetSize(560, 800)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	Fill(f, 0.05, 0.07, 0.09, 0.97)
	Border(f, ar, ag, ab, 0.45)
	tinsert(UISpecialFrames, "MissingPowerOptions")
	optionsFrame = f
	MP.optionsFrame = f

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(58)
	Fill(header, 0.055, 0.07, 0.09, 1)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
	end)
	local accentLine = header:CreateTexture(nil, "ARTWORK")
	accentLine:SetPoint("BOTTOMLEFT")
	accentLine:SetPoint("BOTTOMRIGHT")
	accentLine:SetHeight(2)
	accentLine:SetColorTexture(ar, ag, ab, 1)

	local title = Font(header, 18, ar, ag, ab, 1)
	title:SetPoint("TOPLEFT", 18, -12)
	title:SetText("MissingPowerForever")

	local sub = Font(header, 12, 1, 1, 1, 0.45)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetText("Cast count, pulse, mana spark")

	local close = CreateFrame("Button", nil, header)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -12, -14)
	local closeFs = Font(close, 18, 1, 1, 1, 0.45)
	closeFs:SetPoint("CENTER", 0, 1)
	closeFs:SetText("×")
	close:SetScript("OnEnter", function()
		closeFs:SetTextColor(ar, ag, ab, 1)
	end)
	close:SetScript("OnLeave", function()
		closeFs:SetTextColor(1, 1, 1, 0.45)
	end)
	close:SetScript("OnClick", function()
		HideMenu()
		f:Hide()
	end)

	local body = CreateFrame("Frame", nil, f)
	body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 18, -12)
	body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)

	local designer = CreateFrame("Frame", nil, body)
	designer:SetAllPoints()

	local opts = {
		{ "Enable addon", "enabled", "Master toggle." },
		{ "Cast count", "showCount", "How many times you can cast, on each action button." },
		{ "Decimal cast counts", "showDecimals", "Show tenths (2.5, 2.7) that update as your mana regenerates, not only whole casts." },
		{ "Pulse when almost ready", "pulse", "Flashes the spell overlay on your action buttons when regen is about to make that spell affordable." },
		{ "Spark on player mana bar", "fiveSecondRule", "A tick that slides across YOUR PORTRAIT mana bar for 5 seconds after you spend mana." },
		{ "Countdown 4,2", "showCountdown", "Seconds left on the mana delay, next to your player frame. One decimal, comma format." },
	}

	local checkHost = CreateFrame("Frame", nil, designer)
	checkHost:SetPoint("TOPLEFT", designer, "TOPLEFT", 0, 0)
	checkHost:SetPoint("TOPRIGHT", designer, "TOPRIGHT", 0, 0)
	checkHost:SetHeight(96)
	for i, info in ipairs(opts) do
		local row = MakeCheck(checkHost, info[1], info[2], info[3])
		local col = (i - 1) % 2
		local r = math.floor((i - 1) / 2)
		row:SetPoint("TOPLEFT", checkHost, "TOPLEFT", col * 260, -r * 28)
	end

	local db = MP.db
	local function CountSampleText()
		return (db and db.showDecimals) and "2.7" or "12"
	end
	local RefreshPreview
	local selectedWidget

	local previewInset
	local insetOk = pcall(function()
		previewInset = CreateFrame("Frame", nil, designer, "InsetFrameTemplate")
	end)
	if not insetOk or not previewInset then
		previewInset = CreateFrame("Frame", nil, designer)
		Fill(previewInset, 0.10, 0.10, 0.10, 1)
		Border(previewInset, 0, 0, 0, 0.55)
	end
	previewInset:SetPoint("TOP", checkHost, "BOTTOM", 0, -10)
	previewInset:SetPoint("LEFT", designer, "LEFT", 20, 0)
	previewInset:SetPoint("RIGHT", designer, "RIGHT", -20, 0)
	previewInset:SetHeight(188)
	previewInset:EnableMouse(true)
	if previewInset.SetClipsChildren then
		previewInset:SetClipsChildren(true)
	end

	local preview = CreateFrame("Frame", nil, previewInset)
	preview:SetAllPoints()
	preview:EnableMouse(true)

	local plate = CreateFrame("Frame", nil, preview)
	plate:SetSize(188, 52)
	plate:SetPoint("CENTER", preview, "CENTER", -110, 6)
	plate:EnableMouse(false)
	local plateBg = Fill(plate, 0.06, 0.07, 0.08, 0.9)
	Border(plate, 1, 1, 1, 0.12)
	local portrait = plate:CreateTexture(nil, "ARTWORK")
	portrait:SetSize(40, 40)
	portrait:SetPoint("LEFT", 6, 0)
	portrait:SetColorTexture(0.42, 0.32, 0.18, 1)
	local plateName = Font(plate, 12, 1, 0.82, 0, 0.95)
	plateName:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 8, 2)
	plateName:SetText("Player")
	local hpBar = CreateFrame("StatusBar", nil, plate)
	hpBar:SetSize(124, 10)
	hpBar:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 8, -14)
	hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	hpBar:SetStatusBarColor(0.12, 0.75, 0.18, 1)
	hpBar:SetMinMaxValues(0, 1)
	hpBar:SetValue(0.82)
	Fill(hpBar, 0.08, 0.08, 0.08, 0.8)
	local mockMana = CreateFrame("StatusBar", nil, plate)
	mockMana:SetSize(124, 8)
	mockMana:SetPoint("TOPLEFT", hpBar, "BOTTOMLEFT", 0, -3)
	mockMana:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	mockMana:SetStatusBarColor(0.20, 0.40, 1.00, 1)
	mockMana:SetMinMaxValues(0, 1)
	mockMana:SetValue(0.55)
	Fill(mockMana, 0.08, 0.08, 0.08, 0.8)

	local mock = CreateFrame("Frame", nil, preview)
	mock:SetSize(40, 40)
	mock:SetPoint("CENTER", preview, "CENTER", 130, 10)
	mock:EnableMouse(false)

	local icon = mock:CreateTexture(nil, "BACKGROUND")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local slot = mock:CreateTexture(nil, "OVERLAY")
	slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	slot:SetPoint("TOPLEFT", -15, 15)
	slot:SetPoint("BOTTOMRIGHT", 15, -15)

	local hotkey = Font(mock, 11, 1, 1, 1, 0.9)
	hotkey:SetPoint("TOPRIGHT", -1, -1)
	hotkey:SetText("2")

	local spellName = Font(preview, 12, 1, 1, 1, 0.55)
	spellName:SetPoint("TOP", mock, "BOTTOM", 0, -18)
	spellName:SetText("Frostbolt")

	local function MakeOutline()
		local holder = CreateFrame("Frame", nil, previewInset)
		holder:SetFrameLevel((preview:GetFrameLevel() or 1) + 10)
		local tex = holder:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetColorTexture(0, 0, 0, 0)
		local edges = Border(holder, selR, selG, selB, 0.9)
		holder.SetShownColor = function(_, shown, hover)
			holder:SetShown(shown and true or false)
			edges:SetColor(selR, selG, selB, hover and 0.45 or 0.9)
		end
		holder.Attach = function(_, widget)
			holder:ClearAllPoints()
			holder:SetPoint("TOPLEFT", widget, "TOPLEFT", -2, 2)
			holder:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", 2, -2)
		end
		holder:Hide()
		return holder
	end

	local countDrag = CreateFrame("Button", nil, preview)
	countDrag:SetSize(28, 16)
	countDrag:SetFrameLevel(preview:GetFrameLevel() + 6)
	local countSample = countDrag:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	countSample:SetPoint("CENTER")
	countSample:SetText(CountSampleText())
	countSample:SetTextColor(1, 1, 1, 1)
	local countOutline = MakeOutline()

	local timerDrag = CreateFrame("Button", nil, preview)
	timerDrag:SetSize(36, 18)
	timerDrag:SetFrameLevel(preview:GetFrameLevel() + 6)
	local timerSample = timerDrag:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	timerSample:SetPoint("CENTER")
	timerSample:SetText("4,2")
	timerSample:SetTextColor(0.55, 0.90, 1, 1)
	local timerOutline = MakeOutline()

	local fonts = {
		{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF" },
		{ "Arial Narrow", "Fonts\\ARIALN.TTF", "Fonts\\ARIALN.TTF" },
		{ "Arial Bold", "Fonts\\ARIALNB.TTF", "Fonts\\ARIALNB.TTF" },
		{ "Morpheus", "Fonts\\MORPHEUS.TTF", "Fonts\\MORPHEUS.TTF" },
		{ "Skurri", "Fonts\\SKURRI.TTF", "Fonts\\SKURRI.TTF" },
	}
	local outlines = {
		{ "Outline", "OUTLINE" },
		{ "Thick outline", "THICKOUTLINE" },
		{ "None", "" },
	}

	local applyingStyle = false
	local function NotifyStyle()
		if not applyingStyle then
			db.activeStyle = "custom"
		end
		Notify()
	end

	local styleRow = CreateFrame("Frame", nil, designer)
	styleRow:SetPoint("TOP", previewInset, "BOTTOM", 0, -12)
	styleRow:SetPoint("LEFT", designer, "LEFT", 8, 0)
	styleRow:SetPoint("RIGHT", designer, "RIGHT", -8, 0)
	styleRow:SetHeight(72)
	local styleLabel = Font(styleRow, 11, 1, 1, 1, 0.4)
	styleLabel:SetPoint("TOPLEFT", 4, 2)
	styleLabel:SetText("STYLE PRESETS")
	local styleCards = {}
	local function PaintStyleCards()
		local active = db.activeStyle or "classic"
		for i = 1, #styleCards do
			local card = styleCards[i]
			if card.sample then
				card.sample:SetText(CountSampleText())
			end
			if card.id == active then
				card.brd:SetColor(ar, ag, ab, 0.95)
				card.bg:SetColorTexture(ar, ag, ab, 0.12)
			else
				card.brd:SetColor(1, 1, 1, 0.10)
				card.bg:SetColorTexture(0.07, 0.08, 0.10, 1)
			end
		end
	end
	do
		local styles = MP.STYLES or {}
		local n = #styles
		local gap = 8
		local width = 96
		if n > 0 then
			width = math.floor((520 - gap * (n - 1)) / n)
		end
		for i, style in ipairs(styles) do
			local card = CreateFrame("Button", nil, styleRow)
			card:SetSize(width, 54)
			card:SetPoint("BOTTOMLEFT", (i - 1) * (width + gap), 0)
			card.id = style.id
			card.bg = Fill(card, 0.07, 0.08, 0.10, 1)
			card.brd = Border(card, 1, 1, 1, 0.10)
			local sample = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			sample:SetPoint("TOP", 0, -6)
			sample:SetText(CountSampleText())
			card.sample = sample
			local saved = {}
			for k, v in pairs(style) do
				if k ~= "id" and k ~= "name" then
					saved[k] = db[k]
					db[k] = v
				end
			end
			if MP.ApplyCountStyle then
				MP.ApplyCountStyle(sample)
			end
			for k, v in pairs(saved) do
				db[k] = v
			end
			local nameFs = Font(card, 11, 1, 1, 1, 0.7)
			nameFs:SetPoint("BOTTOM", 0, 6)
			nameFs:SetText(style.name)
			card:SetScript("OnEnter", function()
				if db.activeStyle ~= style.id then
					card.brd:SetColor(ar, ag, ab, 0.45)
				end
			end)
			card:SetScript("OnLeave", function()
				PaintStyleCards()
			end)
			card:SetScript("OnClick", function()
				applyingStyle = true
				if MP.ApplyStylePreset then
					MP.ApplyStylePreset(style.id)
				end
				applyingStyle = false
				PaintStyleCards()
			end)
			styleCards[#styleCards + 1] = card
		end
	end
	PaintStyleCards()

	local hint = designer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pcall(hint.SetFont, hint, UIFont, 15, "")
	hint:SetTextColor(1, 1, 1, 0.85)
	hint:SetPoint("TOP", styleRow, "BOTTOM", 0, -12)
	hint:SetText("Drag the number on the button")

	local widgetTitle = designer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pcall(widgetTitle.SetFont, widgetTitle, UIFont, 15, "")
	widgetTitle:SetTextColor(1, 1, 1, 0.95)
	widgetTitle:SetPoint("TOP", styleRow, "BOTTOM", 0, -12)
	widgetTitle:SetPoint("RIGHT", designer, "RIGHT", -20, 0)
	widgetTitle:SetJustifyH("RIGHT")
	widgetTitle:Hide()

	local settings = CreateFrame("Frame", nil, designer)
	settings:SetPoint("TOP", styleRow, "BOTTOM", 0, -36)
	settings:SetPoint("LEFT", designer, "LEFT", 0, 0)
	settings:SetPoint("RIGHT", designer, "RIGHT", 0, 0)
	settings:SetHeight(246)
	settings:Show()

	local countSettings = CreateFrame("Frame", nil, settings)
	countSettings:SetAllPoints()

	local fontRow = MakeLabeledRow(countSettings, "Font")
	fontRow:SetPoint("TOP", settings, "TOP", 0, 0)
	local fontDrop = MakeDropdown(fontRow, 200, fonts, function()
		return db.countFont
	end, function(path)
		db.countFont = path
		NotifyStyle()
	end)
	fontDrop:SetPoint("LEFT", fontRow, "CENTER", -32, 0)

	local outlineRow = MakeLabeledRow(countSettings, "Border")
	outlineRow:SetPoint("TOP", fontRow, "BOTTOM", 0, 0)
	local outlineDrop = MakeDropdown(outlineRow, 200, outlines, function()
		return db.countOutline
	end, function(value)
		db.countOutline = value
		NotifyStyle()
	end)
	outlineDrop:SetPoint("LEFT", outlineRow, "CENTER", -32, 0)

	local sizeRow = MakeLabeledRow(countSettings, "Size")
	sizeRow:SetPoint("TOP", outlineRow, "BOTTOM", 0, 0)
	local minus = MakeButton(sizeRow, "−", 28)
	minus:SetPoint("LEFT", sizeRow, "CENTER", -32, 0)
	local sizeText = Font(sizeRow, 13, 1, 1, 1, 0.95)
	sizeText:SetPoint("LEFT", minus, "RIGHT", 10, 0)
	sizeText:SetWidth(28)
	sizeText:SetJustifyH("CENTER")
	sizeText:SetText(tostring(db.countSize or 12))
	local plus = MakeButton(sizeRow, "+", 28)
	plus:SetPoint("LEFT", sizeText, "RIGHT", 10, 0)

	local colorRow = MakeLabeledRow(countSettings, "Color")
	colorRow:SetPoint("TOP", sizeRow, "BOTTOM", 0, 0)
	local colorChips = {
		{ 1, 1, 1 },
		{ 1, 0.82, 0.22 },
		{ 1, 0.94, 0.28 },
		{ 0.55, 0.90, 1 },
		{ 1, 0.45, 0.18 },
		{ 0.45, 1, 0.42 },
		{ 1, 0.38, 0.42 },
		{ 0.92, 0.55, 1 },
	}
	local lastChip
	for i, c in ipairs(colorChips) do
		local chip = MakeChip(colorRow, c[1], c[2], c[3], function()
			db.countColorR, db.countColorG, db.countColorB, db.countColorA = c[1], c[2], c[3], 1
			NotifyStyle()
		end)
		if lastChip then
			chip:SetPoint("LEFT", lastChip, "RIGHT", 5, 0)
		else
			chip:SetPoint("LEFT", colorRow, "CENTER", -32, 0)
		end
		lastChip = chip
	end
	local colorSwatch = MakeSwatch(colorRow, 18, function()
		return db.countColorR or 1, db.countColorG or 1, db.countColorB or 1, db.countColorA or 1
	end, function(r, g, b, a)
		db.countColorR, db.countColorG, db.countColorB, db.countColorA = r, g, b, a
		NotifyStyle()
	end, "Custom color")
	colorSwatch:SetPoint("LEFT", lastChip, "RIGHT", 8, 0)

	local shadowRow = MakeLabeledRow(countSettings, "Shadow")
	shadowRow:SetPoint("TOP", colorRow, "BOTTOM", 0, 0)
	local shadowChips = {
		{ 0, 0, 0, 1 },
		{ 0, 0.12, 0.28, 0.95 },
		{ 0.18, 0.08, 0, 1 },
		{ 0, 0, 0, 0 },
	}
	local lastShadow
	for i, c in ipairs(shadowChips) do
		local chip = MakeChip(shadowRow, c[1], c[2], c[3], function()
			db.countShadowR, db.countShadowG, db.countShadowB, db.countShadowA = c[1], c[2], c[3], c[4]
			NotifyStyle()
		end)
		if lastShadow then
			chip:SetPoint("LEFT", lastShadow, "RIGHT", 5, 0)
		else
			chip:SetPoint("LEFT", shadowRow, "CENTER", -32, 0)
		end
		lastShadow = chip
	end
	local shadowSwatch = MakeSwatch(shadowRow, 18, function()
		return db.countShadowR or 0, db.countShadowG or 0, db.countShadowB or 0, db.countShadowA or 1
	end, function(r, g, b, a)
		db.countShadowR, db.countShadowG, db.countShadowB, db.countShadowA = r, g, b, a
		NotifyStyle()
	end, "Custom shadow")
	shadowSwatch:SetPoint("LEFT", lastShadow, "RIGHT", 8, 0)
	local shMinus = MakeButton(shadowRow, "−", 22)
	shMinus:SetPoint("LEFT", shadowSwatch, "RIGHT", 10, 0)
	local shText = Font(shadowRow, 12, 1, 1, 1, 0.9)
	shText:SetPoint("LEFT", shMinus, "RIGHT", 6, 0)
	shText:SetWidth(16)
	shText:SetJustifyH("CENTER")
	shText:SetText(tostring(db.countShadowSize or 1))
	local shPlus = MakeButton(shadowRow, "+", 22)
	shPlus:SetPoint("LEFT", shText, "RIGHT", 6, 0)
	local function bumpShadow(delta)
		local v = (db.countShadowSize or 1) + delta
		if v < 0 then
			v = 0
		end
		if v > 3 then
			v = 3
		end
		db.countShadowSize = v
		shText:SetText(tostring(v))
		NotifyStyle()
	end
	shMinus:SetScript("OnClick", function()
		bumpShadow(-1)
	end)
	shPlus:SetScript("OnClick", function()
		bumpShadow(1)
	end)

	local weightRow = MakeLabeledRow(countSettings, "Weight")
	weightRow:SetPoint("TOP", shadowRow, "BOTTOM", 0, 0)
	local boldCheck = MakeCheck(weightRow, "Bold", "countBold", "Heavier outline and a stronger shadow.")
	boldCheck:SetPoint("LEFT", weightRow, "CENTER", -32, 0)
	boldCheck:SetScript("OnClick", function()
		db.countBold = not (db.countBold and true or false)
		if boldCheck.Paint then
			boldCheck:Paint()
		end
		NotifyStyle()
	end)

	local lockRow = MakeLabeledRow(countSettings, "Locked")
	lockRow:SetPoint("TOP", weightRow, "BOTTOM", 0, 0)
	local lockCount = MakeCheck(lockRow, "", "countLocked", "Prevent dragging the cast count.")
	lockCount:SetPoint("LEFT", lockRow, "CENTER", -32, 0)

	local timerSettings = CreateFrame("Frame", nil, settings)
	timerSettings:SetAllPoints()
	timerSettings:Hide()

	local cdSizeRow = MakeLabeledRow(timerSettings, "Size")
	cdSizeRow:SetPoint("TOP", settings, "TOP", 0, 0)
	local cdMinus = MakeButton(cdSizeRow, "−", 28)
	cdMinus:SetPoint("LEFT", cdSizeRow, "CENTER", -32, 0)
	local cdSizeText = Font(cdSizeRow, 13, 1, 1, 1, 0.95)
	cdSizeText:SetPoint("LEFT", cdMinus, "RIGHT", 10, 0)
	cdSizeText:SetWidth(28)
	cdSizeText:SetJustifyH("CENTER")
	cdSizeText:SetText(tostring(db.cdSize or 12))
	local cdPlus = MakeButton(cdSizeRow, "+", 28)
	cdPlus:SetPoint("LEFT", cdSizeText, "RIGHT", 10, 0)

	local cdLockRow = MakeLabeledRow(timerSettings, "Locked")
	cdLockRow:SetPoint("TOP", cdSizeRow, "BOTTOM", 0, 0)
	local lockTimer = MakeCheck(cdLockRow, "", "cdLocked", "Prevent dragging the mana countdown.")
	lockTimer:SetPoint("LEFT", cdLockRow, "CENTER", -32, 0)

	local resetBtn = MakeButton(designer, "Reset layout", 120)
	resetBtn:SetPoint("BOTTOMLEFT", designer, "BOTTOMLEFT", 0, 0)

	local function SyncLocks()
		if lockCount.Paint then
			lockCount:Paint()
		end
		if lockTimer and lockTimer.Paint then
			lockTimer:Paint()
		end
		if boldCheck and boldCheck.Paint then
			boldCheck:Paint()
		end
	end

	local function SelectWidget(kind)
		selectedWidget = kind
		countOutline:SetShownColor(false, false)
		timerOutline:SetShownColor(false, false)
		if kind == "count" then
			countOutline:Attach(countDrag)
			countOutline:SetShownColor(true, false)
			countSettings:Show()
			timerSettings:Hide()
			widgetTitle:SetText("Cast count")
		elseif kind == "timer" then
			timerOutline:Attach(timerDrag)
			timerOutline:SetShownColor(true, false)
			countSettings:Hide()
			timerSettings:Show()
			widgetTitle:SetText("Mana countdown")
		else
			countSettings:Show()
			timerSettings:Hide()
			widgetTitle:SetText("Cast count")
		end
		settings:Show()
		hint:Hide()
		widgetTitle:Show()
	end

	local function bumpCount(delta)
		local v = (db.countSize or 12) + delta
		if v < 8 then
			v = 8
		end
		if v > 28 then
			v = 28
		end
		db.countSize = v
		sizeText:SetText(tostring(v))
		NotifyStyle()
	end
	minus:SetScript("OnClick", function()
		bumpCount(-1)
	end)
	plus:SetScript("OnClick", function()
		bumpCount(1)
	end)

	local function bumpCd(delta)
		local v = (db.cdSize or 12) + delta
		if v < 8 then
			v = 8
		end
		if v > 28 then
			v = 28
		end
		db.cdSize = v
		cdSizeText:SetText(tostring(v))
		Notify()
	end
	cdMinus:SetScript("OnClick", function()
		bumpCd(-1)
	end)
	cdPlus:SetScript("OnClick", function()
		bumpCd(1)
	end)
	SyncLocks()

	local function OffsetFromAnchor(frame, anchor)
		local mx, my = anchor:GetCenter()
		local fx, fy = frame:GetCenter()
		if not mx or not fx then
			return 0, 0
		end
		return math.floor(fx - mx + 0.5), math.floor(fy - my + 0.5)
	end

	local function ClampN(dx, dy, n)
		n = n or 28
		dx = math.floor((dx or 0) + 0.5)
		dy = math.floor((dy or 0) + 0.5)
		if dx > n then
			dx = n
		end
		if dx < -n then
			dx = -n
		end
		if dy > n then
			dy = n
		end
		if dy < -n then
			dy = -n
		end
		return dx, dy
	end

	local function MakeDraggable(frame, kind, lockedKey, xKey, yKey, outline, anchor, clampN)
		anchor = anchor or mock
		clampN = clampN or 28
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnEnter", function()
			if selectedWidget ~= kind then
				outline:Attach(frame)
				outline:SetShownColor(true, true)
			end
		end)
		frame:SetScript("OnLeave", function()
			if selectedWidget ~= kind then
				outline:SetShownColor(false, false)
			end
		end)
		frame:SetScript("OnMouseDown", function()
			SelectWidget(kind)
			HideMenu()
		end)
		frame:SetScript("OnDragStart", function(self)
			SelectWidget(kind)
			if db[lockedKey] then
				return
			end
			HideMenu()
			self.dragging = true
		end)
		frame:SetScript("OnDragStop", function(self)
			self.dragging = false
			local ox, oy = OffsetFromAnchor(self, anchor)
			local dx, dy = ClampN(ox, oy, clampN)
			db[xKey] = dx
			db[yKey] = dy
			self:ClearAllPoints()
			self:SetPoint("CENTER", anchor, "CENTER", dx, dy)
			outline:Attach(self)
			Notify()
		end)
		frame:SetScript("OnUpdate", function(self)
			if not self.dragging or db[lockedKey] then
				return
			end
			local scale = self:GetEffectiveScale() or 1
			local cx, cy = GetCursorPosition()
			cx, cy = cx / scale, cy / scale
			local mx, my = anchor:GetCenter()
			if not mx then
				return
			end
			local dx, dy = ClampN(cx - mx, cy - my, clampN)
			db[xKey] = dx
			db[yKey] = dy
			self:ClearAllPoints()
			self:SetPoint("CENTER", anchor, "CENTER", dx, dy)
			outline:Attach(self)
		end)
		frame:SetScript("OnMouseWheel", function(_, delta)
			SelectWidget(kind)
			if kind == "count" then
				bumpCount(delta > 0 and 1 or -1)
			elseif kind == "timer" then
				bumpCd(delta > 0 and 1 or -1)
			end
		end)
		if frame.EnableMouseWheel then
			frame:EnableMouseWheel(true)
		end
	end
	MakeDraggable(countDrag, "count", "countLocked", "countOffsetX", "countOffsetY", countOutline, mock, 28)
	MakeDraggable(timerDrag, "timer", "cdLocked", "cdOffsetX", "cdOffsetY", timerOutline, mockMana, 64)

	local function Deselect()
		HideMenu()
		SelectWidget(nil)
	end
	preview:SetScript("OnMouseDown", Deselect)
	previewInset:SetScript("OnMouseDown", Deselect)

	RefreshPreview = function()
		local cx, cy = ClampN(db.countOffsetX or 1, db.countOffsetY or -1, 28)
		db.countOffsetX, db.countOffsetY = cx, cy
		if not countDrag.dragging then
			countDrag:ClearAllPoints()
			countDrag:SetPoint("CENTER", mock, "CENTER", cx, cy)
		end
		pcall(countSample.SetFont, countSample, db.countFont or "Fonts\\FRIZQT__.TTF", db.countSize or 12, db.countOutline or "OUTLINE")
		if MP.ApplyCountStyle then
			MP.ApplyCountStyle(countSample)
		end
		countSample:SetJustifyH("CENTER")
		countSample:SetText(CountSampleText())
		local fs = db.countSize or 12
		local tw = countSample:GetStringWidth() or 20
		countDrag:SetSize(math.max(24, tw + 8), math.max(14, fs + 4))
		local tx, ty = ClampN(db.cdOffsetX or 54, db.cdOffsetY or -17, 64)
		db.cdOffsetX, db.cdOffsetY = tx, ty
		if not timerDrag.dragging then
			timerDrag:ClearAllPoints()
			timerDrag:SetPoint("CENTER", mockMana, "CENTER", tx, ty)
		end
		if MP.ApplyCountStyle then
			MP.ApplyCountStyle(timerSample, db.cdSize or 12)
		end
		timerSample:SetText("4,2")
		timerSample:SetJustifyH("CENTER")
		local tfs = db.cdSize or 12
		local ttw = timerSample:GetStringWidth() or 24
		timerDrag:SetSize(math.max(28, ttw + 8), math.max(16, tfs + 4))
		if selectedWidget == "count" then
			countOutline:Attach(countDrag)
		elseif selectedWidget == "timer" then
			timerOutline:Attach(timerDrag)
		end
		local cLock = db.countLocked and true or false
		local tLock = db.cdLocked and true or false
		countDrag:SetAlpha(cLock and 0.7 or 1)
		timerDrag:SetAlpha(tLock and 0.7 or 1)
		sizeText:SetText(tostring(db.countSize or 12))
		cdSizeText:SetText(tostring(db.cdSize or 12))
		if fontDrop.Refresh then
			fontDrop:Refresh()
		end
		if outlineDrop.Refresh then
			outlineDrop:Refresh()
		end
		if colorSwatch and colorSwatch.Paint then
			colorSwatch:Paint()
		end
		if shadowSwatch and shadowSwatch.Paint then
			shadowSwatch:Paint()
		end
		if shText then
			shText:SetText(tostring(db.countShadowSize or 1))
		end
		if boldCheck and boldCheck.Paint then
			boldCheck:Paint()
		end
		if PaintStyleCards then
			PaintStyleCards()
		end
		SyncLocks()
	end
	MP.RefreshDesigner = RefreshPreview

	resetBtn:SetScript("OnClick", function()
		applyingStyle = true
		if MP.ApplyStylePreset then
			MP.ApplyStylePreset("ice")
		end
		db.countLocked = false
		db.cdOffsetX = 54
		db.cdOffsetY = -17
		db.cdSize = 12
		db.cdLocked = false
		applyingStyle = false
		SelectWidget("count")
		Notify()
	end)

	SelectWidget("count")

	f:SetScript("OnHide", HideMenu)
	f:SetScript("OnShow", function()
		if RefreshPreview then
			RefreshPreview()
		end
	end)
	C_Timer.After(0, function()
		if RefreshPreview then
			RefreshPreview()
		end
	end)
	return f
end

function MP.CreateOptions()
	return CreateOptions()
end

function MP.ToggleOptions()
	CreateOptions()
	if optionsFrame:IsShown() then
		HideMenu()
		optionsFrame:Hide()
	else
		optionsFrame:ClearAllPoints()
		optionsFrame:SetPoint("CENTER")
		optionsFrame:Show()
	end
end
