local _, ns = ...

-- NaowhUI's top bar: Hush takes the guild button's place, showing your unread whispers, and
-- gives the other buttons simpler icons (only the picture changes; the buttons stay NaowhUI's).
--
-- The guild button is a secure button, so Hush leaves it where it is, unmoved and unwired.
-- A plain button sits on top of it and takes the mouse, and the guild icon and count
-- underneath are faded out. Hush's button follows the guild button wherever NaowhUI lays it
-- out, and hides with the bar.

local MEDIA = "Interface\\AddOns\\Hush\\media\\"
local ICON = MEDIA .. "topbar-hush.png"
local CLEAN_ICONS = { friends = "topbar-friends.png", hearth = "topbar-hearth.png", mplus = "topbar-mplus.png" }

local slot
local originalIcons = {} -- NaowhUI's own pictures, to put back when the option is off

local function GuildButton()
	local guild = _G.NaowhUITopBar_guild
	return guild and guild._icon and guild
end

local function Tint(hover)
	if hover then
		slot.icon:SetVertexColor(ns.Accent())
	else
		-- NaowhUI's icon colour setting. Not its alpha: the guild icon underneath is faded to 0.
		local r, g, b = GuildButton()._icon:GetVertexColor()
		slot.icon:SetVertexColor(r, g, b, 1)
	end
end

local function ShowTooltip(self)
	local ar, ag, ab = ns.Accent()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("Hush", 1, 1, 1)
	GameTooltip:AddDoubleLine("Unread", tostring(ns.UnreadTotal()), 0.7, 0.7, 0.7, ar, ag, ab)
	local active = ns.ActiveConvos()
	if #active > 0 then
		GameTooltip:AddLine(" ")
		for _, c in ipairs(active) do
			local name = "|c" .. ns.NameColor(c) .. ns.DisplayName(c) .. "|r"
			GameTooltip:AddDoubleLine(name, c.unread and (c.unread .. " new") or " ", 1, 1, 1, ar, ag, ab)
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: your conversations", ar, ag, ab)
	GameTooltip:AddLine("Right-click: settings", ar, ag, ab)
	GameTooltip:Show()
end

local function Create(guild)
	slot = CreateFrame("Button", "HushTopBarButton", guild)
	slot:SetAllPoints(guild)
	slot:SetFrameLevel(guild:GetFrameLevel() + 5)
	slot:RegisterForClicks("AnyUp")

	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetTexture(ICON)
	slot.icon:SetAllPoints(guild._icon) -- NaowhUI sizes the guild icon; this one follows

	-- Placed like NaowhUI's own counts: centred on the icon's bottom edge.
	slot.count = slot:CreateFontString(nil, "OVERLAY")
	local NaowhUI = _G.NaowhUIEUI
	slot.count:SetFont(NaowhUI and NaowhUI.FontPath and NaowhUI.FontPath() or ns.FontPath(), 10, "OUTLINE")
	slot.count:SetJustifyH("CENTER")
	slot.count:SetPoint("CENTER", slot.icon, "BOTTOM", 0, 1)
	slot.count:SetTextColor(ns.Accent())

	slot:SetScript("OnClick", function(_, mouseButton)
		GameTooltip:Hide()
		if mouseButton == "RightButton" then
			ns.OpenOptions()
		else
			ns.ShowMenu()
		end
	end)
	slot:SetScript("OnEnter", function(self)
		Tint(true)
		ShowTooltip(self)
	end)
	slot:SetScript("OnLeave", function()
		Tint(false)
		GameTooltip:Hide()
	end)
end

local function ApplyCleanIcons()
	for key, file in pairs(CLEAN_ICONS) do
		local button = _G["NaowhUITopBar_" .. key]
		local icon = button and button._icon
		if icon then
			if not originalIcons[key] then originalIcons[key] = icon:GetTexture() end
			icon:SetTexture(ns.db.cleanIcons and MEDIA .. file or originalIcons[key])
		end
	end
end

-- Called at login and on every loading screen; also when a setting changes.
function ns.UpdateTopBar()
	local guild = GuildButton()
	if not guild then return end -- no NaowhUI, or its top bar is off
	ApplyCleanIcons()
	local on = ns.db.topBar
	if on and not slot then Create(guild) end
	if not slot then return end
	slot:SetShown(on)
	guild._icon:SetAlpha(on and 0 or 1)
	if guild._badge then guild._badge:SetAlpha(on and 0 or 1) end
	if on then Tint(false) end
	ns.UpdateBadge()
end

function ns.UpdateTopBarCount(total)
	if slot then
		slot.count:SetText(total > 0 and total or "")
	end
end
