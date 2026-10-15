local _, ns = ...

-- The message list: their messages in bubbles on the left, yours on the right, a centered
-- time when a few minutes pass, and centered notices like "Bob is away". Bubbles are a
-- texture and a font string straight on the content frame, so links in them work with one
-- hyperlink handler. Nothing runs per frame: items are placed when they arrive, and the
-- whole list is laid out again only after a resize or a look change.

local BUBBLE = "Interface\\AddOns\\Hush\\media\\bubble.png"
local CORNER = 10 -- slice margin of the bubble texture
local PAD_X, PAD_Y = 9, 5
local GAP_SAME, GAP_OTHER, EDGE = 2, 8, 4 -- between a sender's lines, between turns, at the ends
local MAX_WIDTH = 0.78 -- of the list width
local TIME_GAP = 300 -- seconds before a new time label
local MAX_ITEMS = 150
local THEIRS = { 1, 1, 1, 0.08 }
local MINE_ALPHA = 0.3
local TEXT_IN = { 0.93, 0.93, 0.93 }
local TEXT_OUT = { 0.96, 0.98, 0.97 }
local TEXT_FAINT = { 0.55, 0.57, 0.6 }
local TOOLTIP_LINKS = { item = true, spell = true, achievement = true, quest = true, currency = true, enchant = true, talent = true, mount = true }

local View = {}
View.__index = View

local function TimeLabel(t)
	local now, d = date("*t"), date("*t", t)
	if d.year == now.year and d.yday == now.yday then
		return date("%H:%M", t)
	end
	return date("%d %b %H:%M", t)
end

function View:AcquireText(fontObject)
	local fs = tremove(self.textPool) or self.content:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(fontObject)
	fs:SetWordWrap(true)
	fs:SetNonSpaceWrap(true)
	fs:Show()
	return fs
end

function View:AcquireBubble()
	local bg = tremove(self.bubblePool)
	if not bg then
		bg = self.content:CreateTexture(nil, "ARTWORK")
		bg:SetTexture(BUBBLE)
		bg:SetTextureSliceMargins(CORNER, CORNER, CORNER, CORNER)
		bg:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
	end
	bg:Show()
	return bg
end

function View:Release(item)
	item.fs:Hide()
	item.fs:ClearAllPoints()
	self.textPool[#self.textPool + 1] = item.fs
	if item.bg then
		item.bg:Hide()
		self.bubblePool[#self.bubblePool + 1] = item.bg
	end
end

function View:Color(item)
	if item.kind == "in" then
		item.bg:SetVertexColor(unpack(THEIRS))
		item.fs:SetTextColor(unpack(TEXT_IN))
	elseif item.kind == "out" then
		local r, g, b = ns.Accent()
		item.bg:SetVertexColor(r, g, b, MINE_ALPHA)
		item.fs:SetTextColor(unpack(TEXT_OUT))
	else
		item.fs:SetTextColor(unpack(TEXT_FAINT))
	end
end

-- Places one item with its top at y and returns its height.
function View:Place(item, y)
	local fs, width = item.fs, self.width
	fs:ClearAllPoints()
	if not item.bg then
		fs:SetJustifyH("CENTER")
		fs:SetWidth(width - 20)
		fs:SetPoint("TOP", self.content, "TOPLEFT", width / 2, -y)
		return math.ceil(fs:GetStringHeight())
	end

	local maxText = math.floor(width * MAX_WIDTH) - 2 * PAD_X
	-- +1: a width exactly at the measured size can still wrap the last word.
	local textWidth = math.min(math.ceil(fs:GetUnboundedStringWidth()) + 1, maxText)
	fs:SetJustifyH("LEFT")
	fs:SetWidth(textWidth)
	local height = math.ceil(fs:GetStringHeight()) + 2 * PAD_Y

	local bg = item.bg
	bg:ClearAllPoints()
	bg:SetSize(textWidth + 2 * PAD_X, height)
	if item.kind == "out" then
		bg:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -y)
	else
		bg:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
	end
	fs:SetPoint("TOPLEFT", bg, "TOPLEFT", PAD_X, -PAD_Y)
	return height
end

function View:MaxScroll()
	return math.max(0, self.height + EDGE - self.viewHeight)
end

function View:IsAtBottom()
	return self.scroll:GetVerticalScroll() >= self:MaxScroll() - 2
end

function View:ScrollTo(offset)
	self.scroll:SetVerticalScroll(math.min(math.max(offset, 0), self:MaxScroll()))
end

function View:ScrollToBottom()
	self:ScrollTo(self:MaxScroll())
end

function View:Push(item, gap)
	local atBottom = self:IsAtBottom()
	local items = self.items
	item.fs = self:AcquireText(item.small and self.smallFont or self.font)
	item.fs:SetText(item.text)
	if item.kind == "in" or item.kind == "out" then
		item.bg = self:AcquireBubble()
	end
	self:Color(item)
	item.gap = #items == 0 and EDGE or gap
	items[#items + 1] = item
	self.lastKind = item.kind

	self.height = self.height + item.gap + self:Place(item, self.height + item.gap)
	if #items > MAX_ITEMS then
		self:Release(tremove(items, 1))
		items[1].gap = EDGE
		self:Relayout()
	else
		self.content:SetHeight(self.height + EDGE)
	end
	if atBottom or item.kind == "out" then
		self:ScrollToBottom()
	end
end

-- line: { time, inbound, text } from the conversation history
function View:AddLine(line)
	if not self.lastTime or line[1] - self.lastTime >= TIME_GAP then
		self:Push({ kind = "time", small = true, text = TimeLabel(line[1]) }, GAP_OTHER)
	end
	self.lastTime = line[1]
	local kind = line[2] and "in" or "out"
	self:Push({ kind = kind, text = line[3] }, self.lastKind == kind and GAP_SAME or GAP_OTHER)
end

function View:AddNotice(text)
	self:Push({ kind = "notice", small = true, text = text }, GAP_OTHER)
end

function View:Clear()
	for _, item in ipairs(self.items) do
		self:Release(item)
	end
	wipe(self.items)
	self.height, self.lastKind, self.lastTime = 0, nil, nil
	self.content:SetHeight(1)
	self.scroll:SetVerticalScroll(0)
end

function View:Relayout()
	local wasAtBottom = self:IsAtBottom()
	local y = 0
	for _, item in ipairs(self.items) do
		y = y + item.gap
		y = y + self:Place(item, y)
	end
	self.height = y
	self.content:SetHeight(y + EDGE)
	if wasAtBottom then self:ScrollToBottom() end
end

-- Font or colour change: everything is measured again.
function View:Refresh()
	for _, item in ipairs(self.items) do
		item.fs:SetFontObject(item.small and self.smallFont or self.font)
		self:Color(item)
	end
	self:Relayout()
end

-- Cheap enough to call on every size change: wrapping is redone by Relayout afterwards.
function View:SetSize(width, height)
	self.width, self.viewHeight = width, height
	self.content:SetWidth(width)
end

function ns.CreateMessageView(parent, font, smallFont, onClick)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)

	local view = setmetatable({
		scroll = scroll, content = content, font = font, smallFont = smallFont,
		items = {}, textPool = {}, bubblePool = {},
		height = 0, width = 1, viewHeight = 1,
	}, View)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		if IsShiftKeyDown() then
			if delta > 0 then view:ScrollTo(0) else view:ScrollToBottom() end
		else
			view:ScrollTo(scroll:GetVerticalScroll() - delta * 40)
		end
	end)

	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseUp", onClick) -- below the last bubble
	content:EnableMouse(true)
	content:SetHyperlinksEnabled(true)
	content:SetScript("OnMouseUp", onClick)
	content:SetScript("OnHyperlinkClick", function(_, link, text, button)
		SetItemRef(link, text, button, DEFAULT_CHAT_FRAME)
	end)
	content:SetScript("OnHyperlinkEnter", function(self, link)
		if TOOLTIP_LINKS[link:match("^(%a+):")] then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(link)
			GameTooltip:Show()
		end
	end)
	content:SetScript("OnHyperlinkLeave", GameTooltip_Hide)

	return view
end
