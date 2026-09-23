--[[
  MissingPowerForever for WoW Classic Forever

  Action-button overlays: how many times you can cast a spell, and a
  pulse when regen is about to make it affordable. Optional spark on the
  player mana bar for the 5-second spirit delay after spending mana.

  Forever hands addons secret UnitPower values. Lua math and comparisons
  on those throw and hide the overlay, so counts go through native
  formatters / curves.

  Original idea: MissingPower by D4KiR. This is a new Forever-safe
  implementation, not a copy of that addon.
]]

local ADDON_NAME = ...

local MP = {}
_G.MissingPower = MP

local GetTime = GetTime
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local GetActionInfo = GetActionInfo
local HasAction = HasAction
local GetMacroSpell = GetMacroSpell
local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local pi = math.pi

local POWER_MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local POWER_RAGE = Enum and Enum.PowerType and Enum.PowerType.Rage or 1
local POWER_FOCUS = Enum and Enum.PowerType and Enum.PowerType.Focus or 2
local POWER_ENERGY = Enum and Enum.PowerType and Enum.PowerType.Energy or 3

local TOKEN_TO_TYPE = {
	MANA = POWER_MANA,
	RAGE = POWER_RAGE,
	FOCUS = POWER_FOCUS,
	ENERGY = POWER_ENERGY,
}

local TYPE_TO_TOKEN = {
	[POWER_MANA] = "MANA",
	[POWER_RAGE] = "RAGE",
	[POWER_FOCUS] = "FOCUS",
	[POWER_ENERGY] = "ENERGY",
}

local defaults = {
	enabled = true,
	showBar = false,
	showCount = true,
	pulse = true,
	fiveSecondRule = true,
	energyTick = false,
	healthTick = false,
	countSize = 19,
	countOffsetX = -12,
	countOffsetY = 12,
	countFont = "Fonts\\ARIALN.TTF",
	countOutline = "THICKOUTLINE",
	countBold = false,
	countColorR = 0.55,
	countColorG = 0.90,
	countColorB = 1,
	countColorA = 1,
	countShadowR = 0,
	countShadowG = 0,
	countShadowB = 0,
	countShadowA = 1,
	countShadowSize = 2,
	countLocked = false,
	activeStyle = "ice",
}

local db
local overlays = {}
local sparks = {}
local lastPower = {}
local fsrUntil = 0
local SPARK_DUR = 5
local ticker
local harvested = 0
local hookedMixin
local curveCache = {}

local function IsSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function SafeNum(v)
	if v == nil or IsSecret(v) then
		return nil
	end
	if type(v) ~= "number" then
		return nil
	end
	return v
end

local function SafeStr(v)
	if v == nil or IsSecret(v) then
		return nil
	end
	if type(v) ~= "string" then
		return nil
	end
	return v
end

-- Secret booleans cannot be tested; treat them as present so we still query the slot.
local function ExistsMaybe(v)
	if v == nil then
		return false
	end
	if IsSecret(v) then
		return true
	end
	return not not v
end

local function CopyDefaults(src, dest)
	dest = dest or {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			dest[k] = CopyDefaults(v, dest[k])
		elseif dest[k] == nil then
			dest[k] = v
		end
	end
	return dest
end

local function RawPower(unit, powerType)
	unit = unit or "player"
	local ok, v = pcall(UnitPower, unit, powerType)
	if ok then
		return v
	end
	ok, v = pcall(UnitPower, unit)
	if ok then
		return v
	end
	return nil
end

local function RawPowerMax(unit, powerType)
	unit = unit or "player"
	local ok, v = pcall(UnitPowerMax, unit, powerType)
	if ok then
		return v
	end
	return nil
end

local function PowerNow(unit, powerType)
	return SafeNum(RawPower(unit, powerType))
end

local function PowerMax(unit, powerType)
	return SafeNum(RawPowerMax(unit, powerType))
end

local function CostFromRow(row)
	if type(row) ~= "table" then
		return nil, nil
	end
	local pt = row.type
	if pt == nil and row.name then
		local name = SafeStr(row.name)
		if name then
			pt = TOKEN_TO_TYPE[name]
		end
	end
	local cost = row.minCost
	if cost == nil then
		cost = row.cost
	end
	local pubCost = SafeNum(cost)
	if pubCost then
		if pubCost <= 0 then
			local pct = SafeNum(row.costPercent)
			if pct and pct > 0 then
				local mx = PowerMax("player", SafeNum(pt) or pt)
				if mx and mx > 0 then
					cost = mx * pct / 100
					pubCost = cost
				end
			end
		end
		if pubCost <= 0 then
			return nil, nil
		end
	elseif cost == nil then
		return nil, nil
	end
	if pt == nil then
		return nil, nil
	end
	return cost, pt
end

local function SpellCost(spellId)
	if not spellId then
		return nil, nil
	end
	local function tryGet(getter, arg)
		if not getter or arg == nil then
			return nil
		end
		local ok, v = pcall(getter, arg)
		if ok and type(v) == "table" then
			return v
		end
		return nil
	end
	local costs = tryGet(C_Spell and C_Spell.GetSpellPowerCost, spellId)
	if not costs and C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellId)
		if ok and name then
			costs = tryGet(C_Spell.GetSpellPowerCost, name)
		end
	end
	if not costs then
		costs = tryGet(GetSpellPowerCost, spellId)
	end
	if type(costs) ~= "table" then
		return nil, nil
	end
	-- Avoid # on a possibly secret table; 8 cost entries is more than any spell uses.
	for i = 1, 8 do
		local row = costs[i]
		if row == nil then
			break
		end
		local cost, pt = CostFromRow(row)
		if cost then
			return cost, pt
		end
	end
	return nil, nil
end

local function SlotHasAction(slot)
	if C_ActionBar and C_ActionBar.HasAction then
		local ok, has = pcall(C_ActionBar.HasAction, slot)
		if ok then
			if IsSecret(has) then
				return true
			end
			return not not has
		end
	end
	if HasAction then
		local ok, has = pcall(HasAction, slot)
		if ok then
			if IsSecret(has) then
				return true
			end
			return not not has
		end
	end
	return true
end

local function SlotSpell(slot)
	if not slot then
		return nil
	end
	if not SlotHasAction(slot) then
		return nil
	end
	if C_ActionBar and C_ActionBar.GetSpell then
		local ok, spell = pcall(C_ActionBar.GetSpell, slot)
		if ok and ExistsMaybe(spell) then
			local pub = SafeNum(spell)
			if not pub or pub > 0 then
				return spell
			end
		end
	end
	if not GetActionInfo then
		return nil
	end
	local ok, actionType, id = pcall(GetActionInfo, slot)
	if not ok or id == nil then
		return nil
	end
	local pubType = SafeStr(actionType)
	if pubType == "macro" and GetMacroSpell then
		local okm, spell = pcall(GetMacroSpell, id)
		if okm and ExistsMaybe(spell) then
			return spell
		end
	end
	if pubType == "spell" or pubType == "companion" or pubType == nil then
		local pubId = SafeNum(id)
		if pubId and pubId <= 0 then
			return nil
		end
		return id
	end
	if pubType ~= "item" and pubType ~= "equipmentset" and pubType ~= "flyout" then
		return id
	end
	return nil
end

local function ButtonSlot(btn)
	if not btn then
		return nil
	end
	local a = btn.action
	a = SafeNum(a)
	if a and a > 0 then
		return a
	end
	if btn._state_action then
		a = SafeNum(btn._state_action)
		if a and a > 0 then
			return a
		end
	end
	if btn.GetAttribute then
		local ok, v = pcall(btn.GetAttribute, btn, "action")
		if ok then
			v = SafeNum(v)
			if v and v > 0 then
				return v
			end
		end
	end
	if ActionButton_CalculateAction then
		local ok, v = pcall(ActionButton_CalculateAction, btn)
		if ok then
			v = SafeNum(v)
			if v and v > 0 then
				return v
			end
		end
	end
	if ActionButton_GetPagedID then
		local ok, v = pcall(ActionButton_GetPagedID, btn)
		if ok then
			v = SafeNum(v)
			if v and v > 0 then
				return v
			end
		end
	end
	if btn.GetID then
		local ok, v = pcall(btn.GetID, btn)
		if ok then
			v = SafeNum(v)
			if v and v > 0 and v <= 180 then
				return v
			end
		end
	end
	return nil
end

local function ButtonUnit(btn)
	if btn and btn.header and type(btn.header.unit) == "string" then
		return btn.header.unit
	end
	local name = btn and btn.GetName and btn:GetName()
	if type(name) == "string" and name:find("Pet", 1, true) then
		return "pet"
	end
	return "player"
end

local function RegenPerSecond(powerType)
	if GetPowerRegenForPowerType then
		local ok, inactive, active = pcall(GetPowerRegenForPowerType, powerType)
		if ok then
			inactive = SafeNum(inactive)
			active = SafeNum(active)
			if powerType == POWER_MANA and GetTime() < fsrUntil then
				return active or 0
			end
			return inactive or active or 0
		end
	end
	if powerType == POWER_MANA and GetPowerRegen then
		local ok, inactive, active = pcall(GetPowerRegen)
		if ok then
			inactive = SafeNum(inactive)
			active = SafeNum(active)
			if GetTime() < fsrUntil then
				return active or 0
			end
			return inactive or active or 0
		end
	end
	if powerType == POWER_ENERGY or powerType == POWER_FOCUS then
		return 10
	end
	return 0
end

local function RegenSoon(powerType)
	local perSec = RegenPerSecond(powerType)
	if not perSec or perSec <= 0 then
		return 0
	end
	return perSec * 0.45
end

local function CountFontPath()
	local path = (db and db.countFont) or "Fonts\\FRIZQT__.TTF"
	if db and db.countBold and path == "Fonts\\ARIALN.TTF" then
		return "Fonts\\ARIALNB.TTF"
	end
	return path
end

local function CountFontFlags()
	local flags = (db and db.countOutline) or "OUTLINE"
	if db and db.countBold then
		if flags == "" then
			flags = "OUTLINE"
		elseif flags == "OUTLINE" then
			flags = "THICKOUTLINE"
		end
	end
	return flags
end

local function ApplyCountStyle(fs)
	if not fs then
		return
	end
	local size = (db and db.countSize) or 12
	local path = CountFontPath()
	local flags = CountFontFlags()
	if not pcall(fs.SetFont, fs, path, size, flags) then
		if db and db.countBold then
			if not pcall(fs.SetFont, fs, path, size, "THICKOUTLINE") then
				pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
			end
		else
			pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags ~= "" and flags or "OUTLINE")
		end
	end
	local r = (db and db.countColorR) or 1
	local g = (db and db.countColorG) or 1
	local b = (db and db.countColorB) or 1
	local a = (db and db.countColorA) or 1
	fs:SetTextColor(r, g, b, a)
	local sr = (db and db.countShadowR) or 0
	local sg = (db and db.countShadowG) or 0
	local sb = (db and db.countShadowB) or 0
	local sa = (db and db.countShadowA) or 1
	fs:SetShadowColor(sr, sg, sb, sa)
	local sh = (db and db.countShadowSize) or 1
	if db and db.countBold and sh < 1 then
		sh = 1
	end
	fs:SetShadowOffset(sh, -sh)
end

MP.ApplyCountStyle = function(fs)
	ApplyCountStyle(fs)
end

MP.STYLES = {
	{
		id = "classic",
		name = "Classic",
		countFont = "Fonts\\FRIZQT__.TTF",
		countSize = 12,
		countOutline = "OUTLINE",
		countBold = false,
		countColorR = 1,
		countColorG = 1,
		countColorB = 1,
		countColorA = 1,
		countShadowR = 0,
		countShadowG = 0,
		countShadowB = 0,
		countShadowA = 1,
		countShadowSize = 1,
		countOffsetX = -12,
		countOffsetY = 12,
	},
	{
		id = "goldleaf",
		name = "Goldleaf",
		countFont = "Fonts\\SKURRI.TTF",
		countSize = 14,
		countOutline = "THICKOUTLINE",
		countBold = false,
		countColorR = 1,
		countColorG = 0.82,
		countColorB = 0.22,
		countColorA = 1,
		countShadowR = 0.18,
		countShadowG = 0.08,
		countShadowB = 0,
		countShadowA = 1,
		countShadowSize = 1,
		countOffsetX = -12,
		countOffsetY = 12,
	},
	{
		id = "ice",
		name = "Ice",
		countFont = "Fonts\\ARIALN.TTF",
		countSize = 19,
		countOutline = "THICKOUTLINE",
		countBold = false,
		countColorR = 0.55,
		countColorG = 0.90,
		countColorB = 1,
		countColorA = 1,
		countShadowR = 0,
		countShadowG = 0,
		countShadowB = 0,
		countShadowA = 1,
		countShadowSize = 2,
		countOffsetX = -12,
		countOffsetY = 12,
	},
	{
		id = "night",
		name = "Night",
		countFont = "Fonts\\MORPHEUS.TTF",
		countSize = 15,
		countOutline = "",
		countBold = false,
		countColorR = 0.92,
		countColorG = 0.94,
		countColorB = 1,
		countColorA = 1,
		countShadowR = 0,
		countShadowG = 0,
		countShadowB = 0,
		countShadowA = 1,
		countShadowSize = 2,
		countOffsetX = -11,
		countOffsetY = 12,
	},
	{
		id = "punch",
		name = "Punch",
		countFont = "Fonts\\SKURRI.TTF",
		countSize = 16,
		countOutline = "THICKOUTLINE",
		countBold = true,
		countColorR = 1,
		countColorG = 0.94,
		countColorB = 0.28,
		countColorA = 1,
		countShadowR = 0,
		countShadowG = 0,
		countShadowB = 0,
		countShadowA = 1,
		countShadowSize = 2,
		countOffsetX = -12,
		countOffsetY = 13,
	},
}

function MP.ApplyStylePreset(id)
	if not db or not MP.STYLES then
		return
	end
	for i = 1, #MP.STYLES do
		local style = MP.STYLES[i]
		if style.id == id then
			for k, v in pairs(style) do
				if k ~= "id" and k ~= "name" then
					db[k] = v
				end
			end
			db.activeStyle = id
			if MP.OnOptionChanged then
				MP.OnOptionChanged()
			end
			return
		end
	end
end

local function ApplyCountFont(fs)
	ApplyCountStyle(fs)
end

local function LayoutOverlay(rec)
	if not rec or not rec.frame or not db then
		return
	end
	ApplyCountStyle(rec.count)
	rec.count:ClearAllPoints()
	rec.count:SetPoint("CENTER", rec.frame, "CENTER", db.countOffsetX or -12, db.countOffsetY or 12)
	rec.count:SetJustifyH("CENTER")
	rec.count:SetJustifyV("MIDDLE")
	if rec.bar then
		rec.bar:Hide()
	end
end

local function RaiseOverlay(rec, btn)
	if not rec or not rec.frame or not btn then
		return
	end
	local strata
	if btn.GetFrameStrata then
		local ok, v = pcall(btn.GetFrameStrata, btn)
		if ok and type(v) == "string" then
			strata = v
		end
	end
	if strata then
		pcall(rec.frame.SetFrameStrata, rec.frame, strata)
	end
	local lvl = 20
	if btn.GetFrameLevel then
		local ok, v = pcall(btn.GetFrameLevel, btn)
		v = SafeNum(v)
		if ok and v then
			lvl = v + 20
		end
	end
	local cd = btn.cooldown or btn.Cooldown
	if cd and cd.GetFrameLevel then
		local ok, v = pcall(cd.GetFrameLevel, cd)
		v = SafeNum(v)
		if ok and v and v + 5 > lvl then
			lvl = v + 5
		end
	end
	pcall(rec.frame.SetFrameLevel, rec.frame, lvl)
end

local function EnsureOverlay(btn)
	local rec = overlays[btn]
	if rec then
		return rec
	end
	local f = CreateFrame("Frame", nil, btn)
	f:SetAllPoints(btn)
	f:EnableMouse(false)
	pcall(f.SetClipsChildren, f, false)
	local count = f:CreateFontString(nil, "OVERLAY")
	count:SetDrawLayer("OVERLAY", 7)
	ApplyCountFont(count)
	count:SetJustifyH("CENTER")
	count:SetTextColor(1, 1, 1, 1)
	count:SetShadowOffset(1, -1)
	count:SetShadowColor(0, 0, 0, 1)
	rec = { frame = f, count = count, pulse = false }
	overlays[btn] = rec
	LayoutOverlay(rec)
	return rec
end

local function HideOverlay(rec)
	if not rec then
		return
	end
	if rec.bar then
		rec.bar:Hide()
	end
	rec.count:SetText("")
	rec.frame:SetAlpha(1)
	rec.pulse = false
end

local function CastsViaCurve(unit, powerType, cost)
	local pubCost = SafeNum(cost)
	local pubMax = PowerMax(unit, powerType)
	if not pubCost or not pubMax or pubCost <= 0 or pubMax <= 0 then
		return nil
	end
	if UnitPowerPercent then
		if CurveConstants and CurveConstants.ScaleTo100 then
			local ok, pct = pcall(UnitPowerPercent, unit, powerType, false, CurveConstants.ScaleTo100)
			pct = ok and SafeNum(pct)
			if pct then
				return (pct / 100) * pubMax / pubCost
			end
		end
		local ok, pct = pcall(UnitPowerPercent, unit, powerType)
		pct = ok and SafeNum(pct)
		if pct then
			if pct > 1.5 then
				pct = pct / 100
			end
			return pct * pubMax / pubCost
		end
	end
	if not UnitPowerPercent or not C_CurveUtil or not C_CurveUtil.CreateCurve then
		return nil
	end
	local key = pubCost .. ":" .. pubMax
	local curve = curveCache[key]
	if not curve then
		curve = C_CurveUtil.CreateCurve()
		if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
			pcall(curve.SetType, curve, Enum.LuaCurveType.Linear)
		end
		-- UnitPowerPercent evaluates the 0-1 power fraction through this curve.
		-- y = power / cost, then %d truncates toward zero (= floor for positives).
		pcall(curve.AddPoint, curve, 0, 0)
		pcall(curve.AddPoint, curve, 1, pubMax / pubCost)
		curveCache[key] = curve
	end
	local ok, y = pcall(UnitPowerPercent, unit, powerType, false, curve)
	if ok then
		return y
	end
	return nil
end

local function DisplayCount(slot, spellId)
	if C_ActionBar and C_ActionBar.GetActionDisplayCount and slot then
		local ok, text = pcall(C_ActionBar.GetActionDisplayCount, slot)
		if ok and text ~= nil then
			return text
		end
	end
	if C_Spell and C_Spell.GetSpellDisplayCount and spellId then
		local ok, text = pcall(C_Spell.GetSpellDisplayCount, spellId)
		if ok and text ~= nil then
			return text
		end
	end
	return nil
end

local function SetCountText(fs, value)
	if value == nil then
		fs:SetText("")
		return
	end
	if IsSecret(value) then
		if not pcall(fs.SetFormattedText, fs, "%d", value) then
			pcall(fs.SetText, fs, value)
		end
		return
	end
	if type(value) == "number" then
		if value < 1 then
			fs:SetText("")
			return
		end
		if value > 99 then
			fs:SetText("99+")
			return
		end
		fs:SetText(tostring(floor(value)))
		return
	end
	if type(value) == "string" then
		if value == "" or value == "0" then
			fs:SetText("")
			return
		end
		fs:SetText(value)
		return
	end
	pcall(fs.SetText, fs, value)
end

local function UpdateButtonInner(btn)
	if not db or not db.enabled then
		local rec = overlays[btn]
		if rec then
			HideOverlay(rec)
		end
		return
	end
	if not btn then
		return
	end
	if btn.IsShown then
		local ok, shown = pcall(btn.IsShown, btn)
		if ok and shown == false then
			local rec = overlays[btn]
			if rec then
				HideOverlay(rec)
			end
			return
		end
	end
	local rec = EnsureOverlay(btn)
	RaiseOverlay(rec, btn)
	LayoutOverlay(rec)

	local slot = ButtonSlot(btn)
	local spellId = slot and SlotSpell(slot)
	if not spellId and btn.spellID then
		spellId = btn.spellID
	end
	if not spellId and btn.spellId then
		spellId = btn.spellId
	end
	local unit = ButtonUnit(btn)
	local cost, powerType = SpellCost(spellId)
	if not cost or powerType == nil then
		HideOverlay(rec)
		return
	end
	local cur = RawPower(unit, powerType)
	if cur == nil then
		HideOverlay(rec)
		return
	end

	local pubCur = SafeNum(cur)
	local pubCost = SafeNum(cost)
	local pubType = SafeNum(powerType) or powerType

	if db.showCount then
		local shown = false
		if pubCur and pubCost and pubCost > 0 then
			SetCountText(rec.count, floor(pubCur / pubCost))
			shown = true
		else
			local viaCurve = CastsViaCurve(unit, pubType, cost)
			if viaCurve ~= nil then
				SetCountText(rec.count, viaCurve)
				shown = true
			else
				local native = DisplayCount(slot, spellId)
				if native ~= nil then
					SetCountText(rec.count, native)
					shown = true
				end
			end
		end
		if not shown then
			rec.count:SetText("")
		end
	else
		rec.count:SetText("")
	end

	local pulse = false
	if db.pulse and pubCur and pubCost and pubCur < pubCost then
		local gain = RegenSoon(pubType)
		if gain and gain > 0 and pubCur + gain >= pubCost then
			pulse = true
		end
	end
	rec.pulse = pulse
	if not pulse then
		rec.frame:SetAlpha(1)
	end
end

local function UpdateButton(btn)
	pcall(UpdateButtonInner, btn)
end

local function UpdateAllButtons()
	if not db or not db.enabled then
		for _, rec in pairs(overlays) do
			HideOverlay(rec)
		end
		return
	end
	for btn in pairs(overlays) do
		UpdateButton(btn)
	end
end

local function PulseOnUpdate()
	if not db or not db.enabled or not db.pulse then
		return
	end
	local a = 0.42 + 0.58 * (0.5 + 0.5 * sin(GetTime() * 14))
	for _, rec in pairs(overlays) do
		if rec.pulse then
			rec.frame:SetAlpha(a)
		end
	end
end

local function IsActionButton(btn)
	if not btn or not btn.IsObjectType then
		return false
	end
	local ok, isBtn = pcall(btn.IsObjectType, btn, "Button")
	return ok and isBtn
end

local function Consider(btn)
	if not IsActionButton(btn) then
		return
	end
	EnsureOverlay(btn)
	UpdateButton(btn)
end

local function HarvestLAB()
	if not LibStub then
		return
	end
	local names = { "LibActionButton-1.0", "LibActionButton-1.0-ElvUI" }
	for i = 1, #names do
		local LAB = LibStub(names[i], true)
		if LAB then
			if LAB.GetAllButtons then
				local ok, buttons = pcall(LAB.GetAllButtons, LAB)
				if ok and type(buttons) == "table" then
					for btn in pairs(buttons) do
						Consider(btn)
					end
				end
			end
			if LAB.IterateButtons then
				local ok, iter = pcall(LAB.IterateButtons, LAB)
				if ok and type(iter) == "function" then
					for btn in iter do
						Consider(btn)
					end
				end
			end
		end
	end
end

local function HarvestButtons()
	local prefixes = {
		{ "ActionButton", 12 },
		{ "BonusActionButton", 12 },
		{ "MultiBarBottomLeftButton", 12 },
		{ "MultiBarBottomRightButton", 12 },
		{ "MultiBarRightButton", 12 },
		{ "MultiBarLeftButton", 12 },
		{ "MultiBar5Button", 12 },
		{ "MultiBar6Button", 12 },
		{ "MultiBar7Button", 12 },
		{ "OverrideActionBarButton", 6 },
		{ "ExtraActionButton", 1 },
		{ "PetActionButton", 10 },
		{ "StanceButton", 10 },
		{ "PossessButton", 10 },
		{ "BT4Button", 120 },
		{ "BT4PetButton", 10 },
		{ "DominosActionButton", 120 },
		{ "DominosPetButton", 10 },
	}
	for i = 1, #prefixes do
		local prefix, n = prefixes[i][1], prefixes[i][2]
		for j = 1, n do
			Consider(_G[prefix .. j])
		end
	end
	for bar = 1, 15 do
		for j = 1, 12 do
			Consider(_G["ElvUI_Bar" .. bar .. "Button" .. j])
		end
	end
	HarvestLAB()
	harvested = GetTime()
end

local function HookButtonMixin()
	if hookedMixin then
		return
	end
	if ActionBarActionButtonMixin then
		if ActionBarActionButtonMixin.Update then
			hooksecurefunc(ActionBarActionButtonMixin, "Update", function(self)
				Consider(self)
			end)
			hookedMixin = true
		end
		if ActionBarActionButtonMixin.UpdateUsable then
			hooksecurefunc(ActionBarActionButtonMixin, "UpdateUsable", function(self)
				UpdateButton(self)
			end)
		end
		if ActionBarActionButtonMixin.UpdateCount then
			hooksecurefunc(ActionBarActionButtonMixin, "UpdateCount", function(self)
				UpdateButton(self)
			end)
		end
	end
	if ActionButton_Update then
		hooksecurefunc("ActionButton_Update", function(self)
			Consider(self)
		end)
		hookedMixin = true
	end
end

local function HookLAB()
	if not LibStub then
		return
	end
	local names = { "LibActionButton-1.0", "LibActionButton-1.0-ElvUI" }
	for i = 1, #names do
		local LAB = LibStub(names[i], true)
		if LAB and LAB.RegisterCallback then
			LAB.RegisterCallback(MP, "OnButtonCreated", function(_, btn)
				Consider(btn)
			end)
			LAB.RegisterCallback(MP, "OnButtonUpdate", function(_, btn)
				UpdateButton(btn)
			end)
		end
	end
end

local function IsStatusBar(f)
	if not f or type(f) ~= "table" then
		return false
	end
	return f.GetStatusBarTexture ~= nil or f.SetMinMaxValues ~= nil
end

local function FirstStatusBar(list)
	for i = 1, #list do
		local f = list[i]
		if IsStatusBar(f) then
			return f
		end
	end
end

local function CallBar(fn)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, bar = pcall(fn)
	if ok then
		return bar
	end
end

local function PlayerManaBar()
	local elv = _G.ElvUF_Player
	local suf = _G.SUFUnitplayer
	local pf = _G.PlayerFrame
	local midnight
	if pf and pf.PlayerFrameContent then
		local main = pf.PlayerFrameContent.PlayerFrameContentMain
		if main and main.ManaBarArea then
			midnight = main.ManaBarArea.ManaBar
		end
	end
	return FirstStatusBar({
		CallBar(_G.PlayerFrame_GetManaBar),
		midnight,
		pf and (pf.manabar or pf.manaBar or pf.powerBar),
		_G.PlayerFrameManaBar,
		elv and (elv.Power or elv.PowerBar),
		suf and suf.powerBar,
		_G.oUF_Player and _G.oUF_Player.Power,
		_G.MSUF_Player and _G.MSUF_Player.Power,
	})
end

local function PlayerUsesMana()
	local ok, _, token = pcall(UnitPowerType, "player")
	if not ok then
		return true
	end
	token = SafeStr(token)
	if token == nil then
		return true
	end
	return token == "MANA"
end

local function HideManaSpark()
	local rec = sparks.mana
	if not rec then
		return
	end
	if rec.holder then
		rec.holder:Hide()
	end
end

local function EnsureManaSpark(bar)
	local rec = sparks.mana
	if rec and rec.bar ~= bar then
		HideManaSpark()
		if rec.holder then
			rec.holder:SetParent(nil)
			rec.holder:SetScript("OnUpdate", nil)
		end
		sparks.mana = nil
		rec = nil
	end
	if not bar then
		return nil
	end
	if rec then
		return rec
	end

	local holder = CreateFrame("Frame", nil, bar)
	holder:EnableMouse(false)
	holder:SetAllPoints(bar)
	local lvl = 12
	if bar.GetFrameLevel then
		local ok, v = pcall(bar.GetFrameLevel, bar)
		v = ok and SafeNum(v)
		if v then
			lvl = v + 8
		end
	end
	pcall(holder.SetFrameLevel, holder, lvl)

	local track = CreateFrame("StatusBar", nil, holder)
	track:SetAllPoints(holder)
	track:SetMinMaxValues(0, 1)
	track:SetValue(0)
	track:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	track:SetStatusBarColor(1, 1, 1, 0.001)
	track:EnableMouse(false)
	local fill = track:GetStatusBarTexture()

	local tick = holder:CreateTexture(nil, "OVERLAY")
	tick:SetTexture("Interface\\Buttons\\WHITE8X8")
	tick:SetBlendMode("ADD")
	tick:SetVertexColor(0.85, 0.95, 1, 1)
	tick:SetWidth(2)
	tick:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
	tick:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)

	local spark = holder:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	spark:SetVertexColor(0.75, 0.92, 1, 0.9)
	spark:SetWidth(8)
	spark:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
	spark:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)

	holder:SetScript("OnUpdate", function(self)
		if not db or not db.enabled or not db.fiveSecondRule then
			self:Hide()
			return
		end
		local remain = fsrUntil - GetTime()
		if remain <= 0 then
			self:Hide()
			return
		end
		self:SetAllPoints(bar)
		local p = 1 - (remain / SPARK_DUR)
		if p < 0 then
			p = 0
		elseif p > 1 then
			p = 1
		end
		track:SetValue(p)
	end)
	holder:Hide()
	rec = { bar = bar, holder = holder, track = track }
	sparks.mana = rec
	return rec
end

local function StartManaSpark()
	if not db or not db.enabled or not db.fiveSecondRule or not PlayerUsesMana() then
		HideManaSpark()
		return
	end
	fsrUntil = GetTime() + SPARK_DUR
	local rec = EnsureManaSpark(PlayerManaBar())
	if rec and rec.holder then
		rec.holder:Show()
	end
end

local function OnPower(unit, token)
	if unit ~= "player" then
		return
	end
	if type(token) == "number" then
		token = TYPE_TO_TOKEN[token] or token
	end
	token = SafeStr(token) or (not IsSecret(token) and token) or nil
	if not token then
		return
	end
	local pt = TOKEN_TO_TYPE[token]
	if not pt then
		return
	end
	local cur = PowerNow("player", pt)
	local old = lastPower[token]
	lastPower[token] = cur
	if not cur or not old then
		return
	end
	if cur < old - 0.5 then
		if token == "MANA" then
			StartManaSpark()
		end
	end
end

local function OnPlayerCast()
	StartManaSpark()
end

local function StartTicker()
	if ticker then
		return
	end
	ticker = C_Timer.NewTicker(0.05, function()
		pcall(function()
			if GetTime() - harvested > 1.5 then
				HarvestButtons()
			end
			PulseOnUpdate()
		end)
	end)
end

function MP.OnOptionChanged()
	if not db or not db.enabled then
		for _, rec in pairs(overlays) do
			HideOverlay(rec)
		end
		HideManaSpark()
		return
	end
	HarvestButtons()
	UpdateAllButtons()
	if db.fiveSecondRule then
		StartManaSpark()
	else
		HideManaSpark()
	end
	if MP.RefreshDesigner then
		MP.RefreshDesigner()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_POWER_FREQUENT")
pcall(eventFrame.RegisterEvent, eventFrame, "UPDATE_VEHICLE_ACTIONBAR")
pcall(eventFrame.RegisterEvent, eventFrame, "PET_BAR_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "SPELLS_CHANGED")

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			MissingPowerDB = CopyDefaults(defaults, MissingPowerDB)
			db = MissingPowerDB
			if not db.foreverRegen then
				db.foreverRegen = true
				db.energyTick = false
			end
			db.showBar = false
			db.healthTick = false
			if not db.togglesDefaultOn then
				db.togglesDefaultOn = true
				db.enabled = true
				db.showCount = true
				db.pulse = true
				db.fiveSecondRule = true
			end
			if not db.castCountLook then
				db.castCountLook = true
				db.countFont = defaults.countFont
				db.countSize = defaults.countSize
				db.countOutline = defaults.countOutline
				db.countBold = defaults.countBold
				db.countColorR = defaults.countColorR
				db.countColorG = defaults.countColorG
				db.countColorB = defaults.countColorB
				db.countColorA = defaults.countColorA
				db.countShadowR = defaults.countShadowR
				db.countShadowG = defaults.countShadowG
				db.countShadowB = defaults.countShadowB
				db.countShadowA = defaults.countShadowA
				db.countShadowSize = defaults.countShadowSize
				db.countLocked = false
				db.activeStyle = "ice"
			end
			MP.db = db
			return
		end
		if db and (arg1 == "Bartender4" or arg1 == "Dominos" or arg1 == "ElvUI") then
			HookLAB()
			HookButtonMixin()
			HarvestButtons()
		end
		return
	end
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		if MP.CreateOptions then
			MP.CreateOptions()
		end
		HookLAB()
		HookButtonMixin()
		HarvestButtons()
		StartTicker()
		lastPower.MANA = PowerNow("player", POWER_MANA)
		lastPower.RAGE = PowerNow("player", POWER_RAGE)
		lastPower.ENERGY = PowerNow("player", POWER_ENERGY)
		lastPower.FOCUS = PowerNow("player", POWER_FOCUS)
		if db.fiveSecondRule then
			StartManaSpark()
		end
		UpdateAllButtons()
		return
	end
	if not db or not db.enabled then
		return
	end
	if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
		OnPower(arg1, arg2)
		UpdateAllButtons()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" then
			OnPlayerCast()
		end
		UpdateAllButtons()
	elseif event == "UNIT_MAXPOWER" or event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_SLOT_CHANGED"
		or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR"
		or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_VEHICLE_ACTIONBAR"
		or event == "PET_BAR_UPDATE" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
		or event == "SPELLS_CHANGED" then
		UpdateAllButtons()
	end
end)

local function Print(msg)
	print("|cff0cd29dMissingPowerForever|r: " .. msg)
end

SLASH_MISSINGPOWER1 = "/mp"
SLASH_MISSINGPOWER2 = "/missingpower"

SlashCmdList.MISSINGPOWER = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "help" then
		Print("commands:")
		print("  |cffffff00/mp|r - open options")
		print("  |cffffff00/mp toggle|r - enable or disable")
	elseif msg == "toggle" then
		db.enabled = not db.enabled
		MP.OnOptionChanged()
		Print(db.enabled and "on." or "off.")
	else
		if MP.ToggleOptions then
			MP.ToggleOptions()
		end
	end
end
