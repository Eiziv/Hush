local _, ns = ...

-- Laid out like a LibDBIcon button, and named, so EllesmereUI's minimap button flyout picks
-- it up and restyles it like the others. No library needed for one button.

local ICON = "Interface\\AddOns\\Hush\\media\\minimap.png"

local button

local function Position()
	-- Another addon (EllesmereUI's flyout) may have taken the button in; it places it then.
	if button:GetParent() ~= Minimap then return end
	local angle = math.rad(ns.db.minimapAngle)
	local x, y = math.cos(angle), math.sin(angle)
	local radius = Minimap:GetWidth() / 2
	if (GetMinimapShape and GetMinimapShape() or "ROUND") == "ROUND" then
		radius = radius + 5
	else
		local edge = math.max(math.abs(x), math.abs(y))
		x, y = x / edge, y / edge
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

-- Only runs while the button is being dragged.
local function FollowCursor()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	ns.db.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
	Position()
end

local function Label(c)
	local label = "|c" .. ns.NameColor(c) .. ns.DisplayName(c) .. "|r"
	if c.unread then
		local r, g, b = ns.Accent()
		label = label .. ("  |cff%02x%02x%02x%d new|r"):format(r * 255, g * 255, b * 255, c.unread)
	end
	return label
end

local function AddConvo(root, c)
	root:CreateButton(Label(c), function() ns.Open(c, true) end)
end

function ns.ShowMenu(owner)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Hush")
		local active = ns.ActiveConvos()
		for _, c in ipairs(active) do
			AddConvo(root, c)
		end
		if #active == 0 then
			root:CreateTitle("No open conversations")
		end

		local recent = ns.RecentConvos(8)
		if #recent > 0 then
			root:CreateDivider()
			root:CreateTitle("Recent")
			for _, c in ipairs(recent) do
				AddConvo(root, c)
			end
		end

		root:CreateDivider()
		if #active > 0 then
			root:CreateButton("Minimize all", ns.MinimizeAll)
			root:CreateButton("Close all", ns.CloseAll)
		end
		root:CreateButton("Settings", ns.OpenOptions)
	end)
end

local function ShowTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:SetText("Hush")
	GameTooltip:AddLine("Click: your conversations", 1, 1, 1)
	GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
	if owner == button then
		GameTooltip:AddLine("Drag: move", 1, 1, 1)
	end
	GameTooltip:Show()
end

local function OnClick(owner, mouseButton)
	GameTooltip:Hide()
	if mouseButton == "RightButton" then
		ns.OpenOptions()
	else
		ns.ShowMenu(owner)
	end
end

local function CreateButton()
	button = CreateFrame("Button", "HushMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
	background:SetSize(24, 24)
	background:SetPoint("CENTER")

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(ICON)
	button.icon:SetSize(20, 20)
	button.icon:SetPoint("CENTER")

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT")

	-- Unread count
	local badge = CreateFrame("Frame", nil, button)
	badge:SetSize(14, 14)
	badge:SetPoint("CENTER", button, "TOPRIGHT", -6, -6)
	local dot = badge:CreateTexture(nil, "ARTWORK")
	dot:SetAllPoints()
	dot:SetColorTexture(ns.Accent())
	local mask = badge:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(dot)
	dot:AddMaskTexture(mask)
	badge.text = badge:CreateFontString(nil, "OVERLAY")
	badge.text:SetFont(ns.FontPath(), 9, "")
	badge.text:SetTextColor(0.02, 0.1, 0.08)
	badge.text:SetPoint("CENTER", 0, 0)
	badge:Hide()
	button.badge = badge

	button:SetScript("OnClick", OnClick)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnDragStart", function(self)
		if self:GetParent() ~= Minimap then return end
		GameTooltip:Hide()
		self:SetScript("OnUpdate", FollowCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	Position()
end

function ns.UpdateMinimapButton()
	if ns.db.showMinimap and not button then
		CreateButton()
	end
	if button then
		button:SetShown(ns.db.showMinimap)
		ns.UpdateBadge()
	end
end

function ns.UpdateBadge()
	if not button then return end
	local total = ns.UnreadTotal()
	button.badge:SetShown(total > 0)
	button.badge.text:SetText(total > 9 and "9+" or total)
end

-- The addon compartment, the list under the minimap's addon button.
function Hush_OnAddonCompartmentClick(_, mouseButton, menuButton)
	OnClick(menuButton or UIParent, mouseButton)
end

function Hush_OnAddonCompartmentEnter(_, menuButton)
	ShowTooltip(menuButton)
end

function Hush_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
