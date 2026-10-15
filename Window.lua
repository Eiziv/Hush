local _, ns = ...

local HEADER_HEIGHT = 26
local INPUT_HEIGHT = 28
local BG = { 0.03, 0.045, 0.05 } -- EllesmereUI's chat background
local BORDER = { 1, 1, 1, 0.12 }
local DIVIDER = { 1, 1, 1, 0.06 }
local TEXT_IN = { 0.93, 0.93, 0.93 }
local TEXT_OUT = { 0.66, 0.68, 0.7 }
local TEXT_NOTICE = { 0.55, 0.57, 0.6 }
local TIME_COLOR = "ff5f6468"
local OWN_NAME_COLOR = "ff8a8f94"
local TOOLTIP_LINKS = { item = true, spell = true, achievement = true, quest = true, currency = true, enchant = true, talent = true, mount = true }

local font = CreateFont("HushFont")
local pool, active = {}, {} -- active: windows with a conversation, open or minimized
local windowCount = 0

local function Accent()
	if EllesmereUI and EllesmereUI.GetAccentColor then
		return EllesmereUI.GetAccentColor()
	end
	return 12 / 255, 210 / 255, 157 / 255
end
ns.Accent = Accent

local function FontPath()
	local name = ns.db.font
	if name == "eui" then
		if EllesmereUI and EllesmereUI.GetFontPath then
			return EllesmereUI.GetFontPath()
		end
	elseif name:find("[\\/]") then
		return name
	else
		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
		local path = LSM and LSM:Fetch("font", name, true)
		if path then return path end
	end
	return STANDARD_TEXT_FONT
end
ns.FontPath = FontPath

local function UpdateFont()
	local db = ns.db
	if font:SetFont(FontPath(), db.fontSize, db.outline) == false then
		font:SetFont(STANDARD_TEXT_FONT, db.fontSize, db.outline)
	end
	font:SetShadowOffset(1, -1)
	font:SetShadowColor(0, 0, 0, db.shadow and 0.8 or 0)
end

local function SetBorderColor(f, r, g, b, a)
	for _, edge in ipairs(f.border) do
		edge:SetColorTexture(r, g, b, a)
	end
end

local function ShortName(c)
	if c.h.kind == "bn" then return ns.DisplayName(c) end
	return Ambiguate(c.h.target, "short")
end

function ns.ShowLine(f, line)
	local stamp = date("%H:%M", line[1])
	local name, color
	if line[2] then
		name, color = "|c" .. ns.NameColor(f.convo) .. ShortName(f.convo) .. "|r", TEXT_IN
	else
		name, color = "|c" .. OWN_NAME_COLOR .. UnitName("player") .. "|r", TEXT_OUT
	end
	f.messages:AddMessage(("|c%s%s|r  %s  %s"):format(TIME_COLOR, stamp, name, line[3]), color[1], color[2], color[3])
end

-- A line that is shown but not kept in history, like "Bob is away".
function ns.Notice(c, text)
	if not c.frame then return end
	c.frame.messages:AddMessage(("|c%s%s|r  %s"):format(TIME_COLOR, date("%H:%M"), text), TEXT_NOTICE[1], TEXT_NOTICE[2], TEXT_NOTICE[3])
end

function ns.MarkUnread(c)
	local f = c.frame
	if f and not f.box:HasFocus() then
		c.unread = (c.unread or 0) + 1
		f.dot:Show()
		ns.UpdateBadge()
	end
end

function ns.IsMinimized(c)
	return c.frame ~= nil and not c.frame:IsShown()
end

function ns.UnreadTotal()
	local total = 0
	for _, f in ipairs(active) do
		total = total + (f.convo.unread or 0)
	end
	return total
end

-- Conversations with a window, open or minimized, newest message first.
function ns.ActiveConvos()
	local list = {}
	for _, f in ipairs(active) do
		list[#list + 1] = f.convo
	end
	table.sort(list, function(a, b) return a.h.t > b.h.t end)
	return list
end

local function Style(f)
	f.bg:SetColorTexture(BG[1], BG[2], BG[3], ns.db.bgAlpha)
	f.dot:SetColorTexture(Accent())
	if f.box:HasFocus() then
		local r, g, b = Accent()
		SetBorderColor(f, r, g, b, 0.5)
	else
		SetBorderColor(f, unpack(BORDER))
	end
	-- Setting the font object again makes the message frame lay its lines out with the new size.
	f.messages:SetFontObject(font)
	f.box:SetFontObject(font)
	f.title:SetFontObject(font)
	f.hint:SetFontObject(font)
end

local function SavePosition(f)
	ns.db.x, ns.db.y = f:GetLeft(), f:GetTop()
end

local function Close(f)
	f.box:SetText("")
	f:Hide()
	local c = f.convo
	c.frame, c.unread = nil, nil
	f.convo = nil
	tDeleteItem(active, f)
	pool[#pool + 1] = f
	ns.UpdateBadge()
end

local function Edge(f, from, to)
	local t = f:CreateTexture(nil, "BORDER")
	t:SetPoint(from)
	t:SetPoint(to)
	f.border[#f.border + 1] = t
	return t
end

local function Divider(parent, point, relativePoint)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(unpack(DIVIDER))
	t:SetPoint(point .. "LEFT", parent, relativePoint .. "LEFT")
	t:SetPoint(point .. "RIGHT", parent, relativePoint .. "RIGHT")
	PixelUtil.SetHeight(t, 1)
end

local function CreateWindow()
	-- Named, because Escape closes the frames listed in UISpecialFrames by name. For Hush
	-- windows that means minimizing: hidden, but the conversation stays in the list.
	windowCount = windowCount + 1
	local name = "HushWindow" .. windowCount
	local f = CreateFrame("Frame", name, UIParent)
	tinsert(UISpecialFrames, name)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetResizeBounds(220, 120)
	f:EnableMouse(true)
	f:Hide()

	f:SetScript("OnHide", function()
		f.box:ClearFocus()
		ns.UpdateBadge()
	end)

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()

	f.border = {}
	PixelUtil.SetHeight(Edge(f, "TOPLEFT", "TOPRIGHT"), 1)
	PixelUtil.SetHeight(Edge(f, "BOTTOMLEFT", "BOTTOMRIGHT"), 1)
	PixelUtil.SetWidth(Edge(f, "TOPLEFT", "BOTTOMLEFT"), 1)
	PixelUtil.SetWidth(Edge(f, "TOPRIGHT", "BOTTOMRIGHT"), 1)

	-- Header: name, unread dot, minimize and close buttons. Dragging it moves the window.
	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() f:StartMoving() end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		SavePosition(f)
	end)
	Divider(header, "BOTTOM", "BOTTOM")

	f.title = header:CreateFontString(nil, "OVERLAY")
	f.title:SetPoint("LEFT", 10, 0)
	f.title:SetWordWrap(false)

	f.dot = header:CreateTexture(nil, "OVERLAY")
	f.dot:SetSize(6, 6)
	f.dot:SetPoint("LEFT", f.title, "RIGHT", 7, 0)
	local mask = header:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(f.dot)
	f.dot:AddMaskTexture(mask)
	f.dot:Hide()

	local close = CreateFrame("Button", nil, header)
	close:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
	close:SetPoint("RIGHT")
	close:SetAlpha(0.45)
	for _, angle in ipairs({ 45, -45 }) do
		local line = close:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(1, 1, 1)
		line:SetSize(10, 1.5)
		line:SetPoint("CENTER")
		line:SetRotation(math.rad(angle))
	end
	close:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
	close:SetScript("OnLeave", function(self) self:SetAlpha(0.45) end)
	close:SetScript("OnClick", function() Close(f) end)

	local minimize = CreateFrame("Button", nil, header)
	minimize:SetSize(HEADER_HEIGHT, HEADER_HEIGHT)
	minimize:SetPoint("RIGHT", close, "LEFT", 4, 0)
	minimize:SetAlpha(0.45)
	local bar = minimize:CreateTexture(nil, "ARTWORK")
	bar:SetColorTexture(1, 1, 1)
	bar:SetSize(10, 1.5)
	bar:SetPoint("CENTER", 0, -4)
	minimize:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
	minimize:SetScript("OnLeave", function(self) self:SetAlpha(0.45) end)
	minimize:SetScript("OnClick", function() f:Hide() end)

	-- Input
	local box = CreateFrame("EditBox", nil, f)
	box:SetPoint("BOTTOMLEFT", 1, 1)
	box:SetPoint("BOTTOMRIGHT", -1, 1)
	box:SetHeight(INPUT_HEIGHT)
	box:SetAutoFocus(false)
	box:SetMaxLetters(255)
	box:SetAltArrowKeyMode(false)
	box:SetHistoryLines(32)
	box:SetTextInsets(10, 18, 0, 0)
	local boxBg = box:CreateTexture(nil, "BACKGROUND")
	boxBg:SetAllPoints()
	boxBg:SetColorTexture(0, 0, 0, 0.25)
	Divider(box, "TOP", "TOP")
	f.box = box

	f.hint = box:CreateFontString(nil, "ARTWORK")
	f.hint:SetPoint("LEFT", 10, 0)
	f.hint:SetAlpha(0.3)

	box:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		if text:find("%S") and ns.Send(f.convo, text) then
			self:AddHistoryLine(text)
			self:SetText("")
		end
		if not ns.db.keepFocus then self:ClearFocus() end
	end)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	box:SetScript("OnTextChanged", function(self) f.hint:SetShown(self:GetText() == "") end)
	box:SetScript("OnEditFocusGained", function()
		ns.focusedBox = box
		f.convo.unread = nil
		f.dot:Hide()
		ns.UpdateBadge()
		local r, g, b = Accent()
		SetBorderColor(f, r, g, b, 0.5)
	end)
	box:SetScript("OnEditFocusLost", function()
		if ns.focusedBox == box then ns.focusedBox = nil end
		SetBorderColor(f, unpack(BORDER))
	end)

	-- Messages
	local messages = CreateFrame("ScrollingMessageFrame", nil, f)
	messages:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -6)
	messages:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -10, 6)
	messages:SetFading(false)
	messages:SetMaxLines(200)
	messages:SetJustifyH("LEFT")
	messages:SetSpacing(2)
	if messages.SetIndentedWordWrap then messages:SetIndentedWordWrap(true) end
	messages:SetHyperlinksEnabled(true)
	messages:EnableMouse(true)
	messages:EnableMouseWheel(true)
	messages:SetScript("OnMouseWheel", function(self, delta)
		if IsShiftKeyDown() then
			if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
		else
			for _ = 1, 3 do
				if delta > 0 then self:ScrollUp() else self:ScrollDown() end
			end
		end
	end)
	messages:SetScript("OnMouseUp", function() box:SetFocus() end)
	messages:SetScript("OnHyperlinkClick", function(_, link, text, button)
		SetItemRef(link, text, button, DEFAULT_CHAT_FRAME)
	end)
	messages:SetScript("OnHyperlinkEnter", function(self, link)
		if TOOLTIP_LINKS[link:match("^(%a+):")] then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)
	messages:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
	f.messages = messages

	-- Resize grip: a small triangle of dots in the corner.
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetFrameLevel(box:GetFrameLevel() + 2)
	grip:SetAlpha(0.25)
	for _, xy in ipairs({ { 3, 3 }, { 7, 3 }, { 11, 3 }, { 3, 7 }, { 7, 7 }, { 3, 11 } }) do
		local d = grip:CreateTexture(nil, "OVERLAY")
		d:SetColorTexture(1, 1, 1)
		d:SetSize(2, 2)
		d:SetPoint("BOTTOMRIGHT", -xy[1] + 1, xy[2] - 1)
	end
	grip:SetScript("OnEnter", function(self) self:SetAlpha(0.8) end)
	grip:SetScript("OnLeave", function(self) self:SetAlpha(0.25) end)
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		ns.db.width, ns.db.height = f:GetSize()
		SavePosition(f)
	end)

	return f
end

function ns.Close(c)
	if c.frame then Close(c.frame) end
end

function ns.MinimizeAll()
	for _, f in ipairs(active) do
		f:Hide()
	end
end

function ns.CloseAll()
	for i = #active, 1, -1 do
		Close(active[i])
	end
end

-- New windows open where the last one was moved to, stepped so they don't cover each other.
local function Place(f)
	local db = ns.db
	local step = 24 * #active
	f:SetSize(db.width, db.height)
	f:ClearAllPoints()
	if db.x then
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x + step, db.y - step)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", step, -step)
	end
end

function ns.Open(c, focus)
	local f = c.frame
	if not f then
		f = tremove(pool) or CreateWindow()
		UpdateFont() -- picks up a font changed in EllesmereUI since the last window opened
		Place(f)
		active[#active + 1] = f
		f.convo, c.frame = c, f
		Style(f)
		f.hint:SetText("Whisper " .. ShortName(c))
		f.messages:Clear()
		for _, line in ipairs(c.h.lines) do
			ns.ShowLine(f, line)
		end
		f.messages:ScrollToBottom()
		f:Show()
	elseif not f:IsShown() then
		f:Show() -- restore a minimized window where it was
	end
	f.title:SetText("|c" .. ns.NameColor(c) .. ns.DisplayName(c) .. "|r")
	f:Raise()
	if focus then f.box:SetFocus() end
end

function ns.ApplyLookAll()
	UpdateFont()
	for _, f in ipairs(active) do
		Style(f)
	end
end

-- Shift-clicked links go into a focused Hush box. A hook after the fact keeps Blizzard's chat code untainted.
local insertOwner = ChatFrameUtil and ChatFrameUtil.InsertLink and ChatFrameUtil or _G
local insertName = insertOwner == _G and "ChatEdit_InsertLink" or "InsertLink"
if insertOwner[insertName] then
	hooksecurefunc(insertOwner, insertName, function(text)
		if ns.focusedBox and text then
			ns.focusedBox:Insert(text)
		end
	end)
end
