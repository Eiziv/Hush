-- Runs Hush outside the game against a small fake of the WoW API, which mimics the
-- real one where it matters (chat box behaviour from 12.1.5, texture alpha, focus).
--   lua5.1 tests/run.lua [path to Hush]
local dir = arg[1] or "."
local frames, filters, overrides, sent, printed = {}, {}, {}, {}, {}

local function Obj(kind)
	local o = { kind = kind, scripts = {}, shown = kind ~= "Frame", text = "", lines = {}, points = 0, events = {}, focus = false }
	return setmetatable(o, { __index = function(_, k)
		return function() end
	end })
end

local methods = {}
local New
function methods.SetScript(o, name, fn) o.scripts[name] = fn end
function methods.GetScript(o, name) return o.scripts[name] end
function methods.Show(o) o.shown = true end
function methods.Hide(o) local was = o.shown; o.shown = false; if was and o.scripts.OnHide then o.scripts.OnHide(o) end end
function methods.SetShown(o, v) if v then o.shown = true else methods.Hide(o) end end
function methods.IsShown(o) return o.shown end
function methods.GetText(o) return o.text end
function methods.SetText(o, t) o.text = t; if o.scripts.OnTextChanged then o.scripts.OnTextChanged(o) end end
function methods.Insert(o, t) o.text = o.text .. t end
function methods.HasFocus(o) return o.focus == true end
function methods.SetFocus(o) o.focus = true; if o.scripts.OnEditFocusGained then o.scripts.OnEditFocusGained(o) end end
function methods.ClearFocus(o) if o.focus then o.focus = false; if o.scripts.OnEditFocusLost then o.scripts.OnEditFocusLost(o) end end end
function methods.AddMessage(o, t) o.lines[#o.lines + 1] = t end
function methods.Clear(o) o.lines = {} end
function methods.GetLeft() return 100 end
function methods.GetTop() return 500 end
function methods.GetSize() return 360, 220 end
function methods.GetFrameLevel() return 1 end
function methods.GetFont(o) return o.fontPath end
function methods.SetFont(o, p) o.fontPath = p; return true end
function methods.RegisterEvent(o, e) o.events[e] = true end
function methods.UnregisterEvent(o, e) o.events[e] = nil end
function methods.CreateTexture() return New("Texture") end
function methods.CreateFontString() return New("FontString") end
function methods.CreateMaskTexture() return New("Mask") end

function New(kind)
	local o = Obj(kind)
	for k, fn in pairs(methods) do rawset(o, k, fn) end
	return o
end

CreateFrame = function(kind, name, parent)
	local f = New(kind); f.parent = parent; f.name = name; frames[#frames + 1] = f
	if name then _G[name] = f end
	return f
end
function methods.GetParent(o) return o.parent end
-- Text measuring: 7 units per character, 14 per line.
function methods.SetWidth(o, w) o.width = w end
function methods.SetSize(o, w, h) o.width, o.height = w, h end
function methods.SetHeight(o, h) o.height = h end
function methods.GetUnboundedStringWidth(o) return #o.text * 7 end
function methods.GetStringHeight(o) return math.max(1, math.ceil(#o.text * 7 / (rawget(o, "width") or 1e9))) * 14 end
function methods.SetScrollChild(o, child) o.child = child end
function methods.GetVerticalScroll(o) return rawget(o, "vscroll") or 0 end
function methods.SetVerticalScroll(o, v) o.vscroll = v end
function methods.SetJustifyH(o, j) o.justify = j end
function methods.SetAlpha(o, a) o.alpha = a end
function methods.SetVertexColor(o, r, g, b, a) o.color = { r, g, b }; o.alpha = a or 1 end
function methods.GetVertexColor(o) local c = rawget(o, "color") or { 1, 1, 1 }; return c[1], c[2], c[3], rawget(o, "alpha") or 1 end
function methods.SetTexture(o, t) o.texture = t end
function methods.GetTexture(o) return rawget(o, "texture") end
function methods.SetText(o, t) o.text = t; local s = rawget(o, "scripts"); if s and s.OnTextChanged then s.OnTextChanged(o) end end
function methods.GetWidth(o) return o.width or 0 end
function methods.GetCenter() return 500, 500 end
function methods.GetEffectiveScale() return 1 end
function methods.SetPoint(o, ...) o.point = { ... } end
UISpecialFrames = {}
tinsert = table.insert
GetMinimapShape = function() return "SQUARE" end
local cursor = { 600, 500 }
GetCursorPosition = function() return cursor[1], cursor[2] end
local menu
MenuUtil = { CreateContextMenu = function(owner, gen)
	menu = { owner = owner, items = {} }
	local root = {}
	function root:CreateTitle(t) menu.items[#menu.items + 1] = { title = t } end
	function root:CreateDivider() menu.items[#menu.items + 1] = { divider = true } end
	function root:CreateButton(t, fn) menu.items[#menu.items + 1] = { text = t, fn = fn } end
	gen(owner, root)
end }
local function MenuItem(textPart)
	for _, item in ipairs(menu.items) do
		if item.text and item.text:find(textPart, 1, true) then return item end
	end
end
local optionsOpened = 0
local settingsShown = true
SettingsPanel = { IsShown = function() return settingsShown end }
local reportedErrors = {}
geterrorhandler = function() return function(err) reportedErrors[#reportedErrors + 1] = err end end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
CreateFont = function() return New("Font") end
UIParent = New("Frame")
Minimap = New("Frame"); Minimap.width = 140
GameTooltip = New("Frame")
DEFAULT_CHAT_FRAME = New("Frame")
PixelUtil = { SetHeight = function() end, SetWidth = function() end }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
CHAT_AFK_GET = "%s is Away From Keyboard: "
CHAT_DND_GET = "%s does not wish to be disturbed: "
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
SOUNDKIT = { TELL_MESSAGE = 3081 }
Enum = { AddOnRestrictionType = { Chat = 5 }, UITextureSliceMode = { Stretched = 0 } }
SlashCmdList = {}
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tremove = table.remove
strlower = string.lower
unpack = unpack or table.unpack
date = os.date
time = os.time
print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end
tDeleteItem = function(t, item) for i = #t, 1, -1 do if t[i] == item then table.remove(t, i) end end end
hooksecurefunc = function(owner, name, fn)
	local orig = owner[name]
	owner[name] = function(...) local r = orig(...); fn(...); return r end
end
Ambiguate = function(name, mode) if mode == "short" then return (name:gsub("%-.*", "")) end return (name:gsub("%-MyRealm$", "")) end
GetNormalizedRealmName = function() return "MyRealm" end
UnitName = function() return "Me" end
GetPlayerInfoByGUID = function() return "Mage", "MAGE" end
local played = {}
PlaySound = function(id, channel) played[#played + 1] = { "kit:" .. id, channel } end
PlaySoundFile = function(path, channel) played[#played + 1] = { path, channel } end
local lsmSounds = { Ding = "Sound\\ding.ogg" }
LibStub = function(name)
	if name == "LibSharedMedia-3.0" then
		return { Fetch = function(_, kind, key) return kind == "sound" and lsmSounds[key] or nil end, List = function() return {} end }
	end
end
FlashClientIcon = function() end
IsShiftKeyDown = function() return false end
GameTooltip_Hide = function() end
SetItemRef = function() end
local combat = false
InCombatLockdown = function() return combat end
local bindings = { REPLY = { "R" }, REPLY2 = { "SHIFT-R" } }
GetBindingKey = function(cmd) return unpack(bindings[cmd] or {}) end
SetOverrideBinding = function(_, _, key, cmd) assert(not combat, "binding in combat"); overrides[key] = cmd end
ClearOverrideBindings = function() assert(not combat, "binding in combat"); wipe(overrides) end
local locked = false
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end
hasanysecretvalues = function(...) for i = 1, select("#", ...) do if select(i, ...) == SECRET then return true end end return false end
local chatLines = {}
C_ChatInfo = {
	InChatMessagingLockdown = function() return locked end,
	SendChatMessage = function(text, kind, _, target) sent[#sent + 1] = kind .. ":" .. target .. ":" .. text end,
	GetChatLineText = function(id) return chatLines[id][1] end,
	GetChatLineSenderName = function(id) return chatLines[id][2] end,
	GetChatLineSenderGUID = function(id) return chatLines[id][3] end,
}
local friends = { { bnetAccountID = 7, battleTag = "Pal#1234", accountName = "|Kq7|k" } }
BNGetNumFriends = function() return #friends end
C_BattleNet = {
	GetFriendAccountInfo = function(i) return friends[i] end,
	GetAccountInfoByID = function(id) for _, f in ipairs(friends) do if f.bnetAccountID == id then return f end end end,
	SendWhisper = function(id, text) sent[#sent + 1] = "BN:" .. id .. ":" .. text end,
}
ChatFrameUtil = {
	ActivateChat = function() end,
	AddMessageEventFilter = function(event, fn) filters[event] = fn end,
	InsertLink = function() return false end,
}
Settings = setmetatable({ OpenToCategory = function() optionsOpened = optionsOpened + 1 end, VarType = { Boolean = "boolean", Number = "number", String = "string" } }, { __index = function() return function()
	return setmetatable({}, { __index = function() return function() return {} end end })
end end })
MinimalSliderWithSteppersMixin = { Label = {} }

-- Fake Blizzard chat box, following ChatFrameEditBox.lua from 12.1.5.
local blizzLastTell
local now = 1
GetTime = function() return now end
NUM_CHAT_WINDOWS = 1
issecurevariable = function() return false end
BNet_GetBNetIDAccount = function(name) if name == "|Kq7|k" then return 7 end end
local eb = { attrs = { chatType = "SAY", stickyType = "SAY" }, text = "", focus = false, shown = false, headerCalls = 0 }
ChatFrame1EditBox = eb
function eb:GetChatType() return self.attrs.chatType end
function eb:SetChatType(v) self.attrs.chatType = v end
function eb:GetTellTarget() return self.attrs.tellTarget end
function eb:SetTellTarget(v) self.attrs.tellTarget = v end
function eb:GetStickyType() return self.attrs.stickyType end
function eb:SetStickyType(v) self.attrs.stickyType = v end
function eb:GetText() return self.text end
function eb:HasFocus() return self.focus end
function eb:UpdateHeader() self.headerCalls = self.headerCalls + 1 end
function eb:Open() self.shown, self.focus = true, true; self:SetChatType(self:GetStickyType()); self:UpdateHeader() end
function eb:ClearChat()
	self:SetChatType(self:GetStickyType())
	self.text, self.shown, self.focus = "", false, false
	self:UpdateHeader() -- the IM chat style resets the header on the way out
end
function eb:ProcessChatType(msg, index, send)
	if index == "WHISPER" then
		local target, rest = msg:match("^(%\S+)%\s*(.*)$")
		self:SetTellTarget(target); self:SetChatType(target:find("^|K") and "BN_WHISPER" or "WHISPER"); self.text = rest; self:UpdateHeader()
	elseif index == "REPLY" then
		if blizzLastTell then
			self:SetChatType("WHISPER"); self:SetTellTarget(blizzLastTell); self.text = msg; self:UpdateHeader()
		end
	end
	return true
end

local ns = {}
for _, file in ipairs({ "Core.lua", "Bubbles.lua", "Window.lua", "Takeover.lua", "Minimap.lua", "Options.lua", "API.lua" }) do
	assert(loadfile(dir .. "/" .. file))("Hush", ns)
end

local core = frames[1]
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
local function Whisper(event, text, sender, lineID, guid, bnID)
	local hidden = filters[event](DEFAULT_CHAT_FRAME, event, text, sender, nil, nil, nil, nil, nil, nil, nil, nil, lineID, guid, bnID)
	Fire(event, text, sender, nil, nil, nil, nil, nil, nil, nil, nil, lineID, guid, bnID)
	return hidden
end
local function Items(f, kind)
	local list = {}
	for _, item in ipairs(f.view.items) do
		if not kind or item.kind == kind then list[#list + 1] = item end
	end
	return list
end
local function LastText(f) local items = f.view.items; return items[#items].text end
local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end io.write("ok  ", msg, "\n") end
local realPrint = io.write

Fire("PLAYER_LOGIN")
local db = HushDB
check(overrides.R == "HUSH_REPLY" and overrides["SHIFT-R"] == "HUSH_REPLY2", "reply keys taken over at login")

check(Whisper("CHAT_MSG_WHISPER", "hey there", "Bob-MyRealm", 1, "Player-1") == true, "whisper hidden from normal chat")
local c = ns.convos["w:bob-myrealm"]
check(c and c.frame and c.frame.shown, "window opened for Bob")
check(#c.h.lines == 1 and c.h.class == "MAGE", "line saved with class")
check(Items(c.frame, "in")[1].text == "hey there" and c.frame.title.text:find("ff3fc7eb", 1, true), "their line is a bubble, title in class colour")
check(c.frame.view.items[1].kind == "time", "a time label opens the conversation")
check(c.frame.dot.shown, "unread dot shown")
check(not c.frame.box:HasFocus(), "incoming whisper does not steal focus")

Hush.Reply()
check(c.frame.box:HasFocus() and not c.frame.dot.shown, "reply focuses Bob and clears unread")
c.frame.box:SetText("hi bob")
c.frame.box.scripts.OnEnterPressed(c.frame.box)
check(sent[1] == "WHISPER:Bob-MyRealm:hi bob", "Enter sends the whisper")
check(c.frame.box.text == "" and not c.frame.box:HasFocus(), "box cleared and focus handed back")
Whisper("CHAT_MSG_WHISPER_INFORM", "hi bob", "Bob-MyRealm", 2)
check(#c.h.lines == 2 and c.h.lines[2][2] == false, "own message logged from the server echo")

check(filters.CHAT_MSG_AFK(nil, "CHAT_MSG_AFK", "brb", "Bob-MyRealm") == true, "AFK reply hidden while window open")
Fire("CHAT_MSG_AFK", "brb", "Bob-MyRealm")
check(LastText(c.frame):find("Away From Keyboard: brb", 1, true) and c.frame.view.items[#c.frame.view.items].kind == "notice", "AFK notice shown in window")
Fire("CHAT_MSG_SYSTEM", "No player named 'Bob' is currently playing.")
check(LastText(c.frame):find("No player named", 1, true), "offline notice shown in window")

-- Battle.net
check(Whisper("CHAT_MSG_BN_WHISPER", "yo", "|Kq7|k", 3, nil, 7) == true, "BN whisper hidden")
local b = ns.convos["bn:pal#1234"]
check(b and b.frame and b.h.target == "Pal#1234", "BN window keyed by BattleTag")
check(filters.CHAT_MSG_BN_WHISPER(nil, "CHAT_MSG_BN_WHISPER", "x", "?", nil, nil, nil, nil, nil, nil, nil, nil, 4, nil, 99) == false, "unknown BN account left in normal chat")
b.bnID = nil
ns.Send(b, "sup")
check(sent[#sent] == "BN:7:sup", "BN send finds the account again by BattleTag")

-- Chat lockdown
combat = true
Fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 2)
check(overrides.R == "HUSH_REPLY" and core.events.PLAYER_REGEN_ENABLED, "binding change waits for combat to end")
combat = false
Fire("PLAYER_REGEN_ENABLED")
check(overrides.R == nil, "reply key back to Blizzard during lockdown")
chatLines[10] = { "during key", "Ann-MyRealm", "Player-2" }
check(Whisper("CHAT_MSG_WHISPER", SECRET, SECRET, 10, SECRET) == false, "secret whisper left in normal chat")
check(ns.convos["w:ann-myrealm"] == nil, "no window during lockdown")
check(ns.Send(c, "blocked") == false, "sending refused during lockdown")
Fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)
local a = ns.convos["w:ann-myrealm"]
check(a and a.h.lines[1][3] == "during key", "deferred whisper replayed after lockdown")
check(overrides.R == "HUSH_REPLY", "reply key taken over again")

-- Closing and reuse
local bobFrame = c.frame
bobFrame.scripts = bobFrame.scripts
ns.Open(c)
for _, f in ipairs(frames) do end
c.frame.box:SetFocus()
c.frame.box:ClearFocus()
-- close via the close button: find it as the Button whose OnClick closes the window
local closed = false
for _, f in ipairs(frames) do
	if f.kind == "Button" and f.scripts.OnClick and not closed and f.parent and f.parent.parent == bobFrame then
		f.scripts.OnClick(f)
		closed = true
	end
end
check(c.frame == nil and not bobFrame.shown, "close hides the window")
Whisper("CHAT_MSG_WHISPER", "again", "Bob-MyRealm", 11, "Player-1")
check(c.frame and #Items(c.frame, "in") + #Items(c.frame, "out") == 3, "reopened window refilled from history")

-- Link insertion
c.frame.box:SetFocus()
ChatFrameUtil.InsertLink("[Item]")
check(c.frame.box.text == "[Item]", "shift-clicked link goes into focused box")

-- Settings off
db.takeOverReply = false
ns.UpdateReplyBinding()
check(overrides.R == nil, "turning the reply option off frees the key")
db.hideInChat = false
check(Whisper("CHAT_MSG_WHISPER", "visible", "Bob-MyRealm", 12, "Player-1") == false, "whispers stay in chat when hiding is off")

db.takeOverReply = true
ns.UpdateReplyBinding()
local calls = 0
local origSet = SetOverrideBinding
SetOverrideBinding = function(...) calls = calls + 1; return origSet(...) end
Fire("UPDATE_BINDINGS")
check(calls == 0, "UPDATE_BINDINGS without key changes does nothing")
bindings.REPLY = { "T" }
Fire("UPDATE_BINDINGS")
check(overrides.T == "HUSH_REPLY" and overrides.R == nil, "a rebound reply key is followed")
SlashCmdList.HUSH("font Interface\\AddOns\\MyFonts\\x.ttf")
check(db.font == "Interface\\AddOns\\MyFonts\\x.ttf", "/hush font sets a file path")
SlashCmdList.HUSH("Carl")
check(ns.convos["w:carl-myrealm"].frame.box:HasFocus(), "/hush Name opens a focused window")

-- Whisper takeover
db.hideInChat = true
eb:Open()
eb.text = "/w Dan "
eb:ProcessChatType("Dan hello there", "WHISPER", 0)
local dan = ns.convos["w:dan-myrealm"]
check(dan and dan.frame and dan.frame.box:HasFocus(), "/w Dan opens Dan's Hush window focused")
check(dan.frame.box.text == "hello there", "text typed after the name moves along")
check(not eb.shown and eb:GetChatType() == "SAY", "Blizzard's chat box is closed and back on Say")

eb:SetStickyType("WHISPER"); eb:SetTellTarget("Dan"); eb:Open()
check(not eb.shown and eb:GetStickyType() == "SAY", "sticky whisper mode is taken over once and reset to Say")
eb:Open()
check(eb.shown and eb:GetChatType() == "SAY", "the next Enter opens normal chat again")
eb:ClearChat()

now = 2
dan.frame.box:ClearFocus()
eb:Open()
eb:ProcessChatType("|Kq7|k yo", "WHISPER", 0)
check(b.frame and b.frame.box:HasFocus() and not eb.shown, "Battle.net whisper from the chat box goes to Hush")

-- /r with Blizzard pointing at an older target
now = 3
Whisper("CHAT_MSG_WHISPER", "ping", "Erin-MyRealm", 20, "Player-3")
blizzLastTell = "Fay-MyRealm"
eb:Open()
eb:ProcessChatType("ok", "REPLY", 0)
local fay = ns.convos["w:fay-myrealm"]
check(fay == nil or fay.frame == nil, "Blizzard's stale reply window is closed again")
local erin = ns.convos["w:erin-myrealm"]
check(erin.frame.box:HasFocus() and erin.frame.box.text == "ok", "/r goes to the last Hush whisper with its text")

-- /r with no Blizzard target
now = 4
blizzLastTell = nil
erin.frame.box:ClearFocus()
eb:Open()
eb.text = "/r "
eb:ProcessChatType("", "REPLY", 0)
check(erin.frame.box:HasFocus() and not eb.shown, "/r without a Blizzard target still opens Hush")

-- Off switches
now = 5
db.takeOverWhispers = false
erin.frame.box:ClearFocus()
eb:Open()
eb:ProcessChatType("Gil hi", "WHISPER", 0)
check(eb.shown and eb:GetChatType() == "WHISPER", "takeover off leaves the chat box alone")
eb:ClearChat()
db.takeOverWhispers = true
Fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 2)
eb:Open()
eb:ProcessChatType("Gil hi", "WHISPER", 0)
check(eb.shown and ns.convos["w:gil-myrealm"] == nil, "no takeover while chat is locked")
eb:ClearChat()
Fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 0)

local before = #printed
Fire("ADDON_ACTION_BLOCKED", "Hush", "SendChatMessage()")
Fire("ADDON_ACTION_BLOCKED", "Hush", "SendChatMessage()")
Fire("ADDON_ACTION_BLOCKED", "OtherAddon", "CastSpell()")
Fire("ADDON_ACTION_BLOCKED", "Hush", "C_SettingsUtil.OpenSettingsPanel()")
check(printed[#printed] == "|cff33ff99Hush|r: The game blocked C_SettingsUtil.OpenSettingsPanel() and blamed Hush.", "other blocks are reported plainly, not blamed on the takeover")
table.remove(printed)
check(#printed == before + 1 and printed[#printed]:find("/reload", 1, true), "a block caused by Hush is explained once")
SlashCmdList.HUSH("check")
io.write("check says: ", printed[#printed], "\n"); check(printed[#printed]:find("took over %d+ whispers") ~= nil, "/hush check reports the takeovers")


-- Bubbles
do
	ns.CloseAll()
	local h = ns.WhisperConvo("Ivy").h
	local t0 = 1700000000
	h.lines = {
		{ t0, true, "hi" },
		{ t0 + 10, true, "are you there?" },
		{ t0 + 20, false, "yes" },
		{ t0 + 900, true, string.rep("long message ", 30) },
	}
	h.t = t0 + 900
	local ivy = ns.convos["w:ivy-myrealm"]
	ns.Open(ivy)
	local v = ivy.frame.view
	local kinds = {}
	for _, item in ipairs(v.items) do kinds[#kinds + 1] = item.kind end
	check(table.concat(kinds, ",") == "time,in,in,out,time,in", "time labels only after a pause")
	local items = v.items
	check(items[2].bg.point[1] == "TOPLEFT" and items[4].bg.point[1] == "TOPRIGHT", "theirs on the left, mine on the right")
	check(items[3].gap == 2 and items[4].gap == 8, "tight gap within a sender, wider between turns")
	local listWidth = 360 - 20
	check(items[2].bg.width == #"hi" * 7 + 1 + 18, "short bubble hugs its text")
	check(items[6].bg.width <= listWidth * 0.78 and items[6].fs.width < #items[6].text * 7, "long bubble wraps at most of the width")
	check(v.scroll.vscroll == v:MaxScroll() and v:MaxScroll() > 0, "opens scrolled to the newest message")
	v:ScrollTo(0)
	ivy.frame:Show()
	Whisper("CHAT_MSG_WHISPER", "new", "Ivy-MyRealm", 40, "Player-9")
	check(v.scroll.vscroll == 0, "reading older lines is not interrupted by a new one")
	v:ScrollToBottom()
	Whisper("CHAT_MSG_WHISPER", "newer", "Ivy-MyRealm", 41, "Player-9")
	check(v.scroll.vscroll == v:MaxScroll(), "at the bottom, new lines keep it scrolled down")
	local before = items[6].fs.width
	ivy.frame.scripts.OnSizeChanged(ivy.frame, 600, 300)
	v:Relayout()
	check(items[6].fs.width > before, "a wider window rewraps the bubbles")
	for i = 1, 160 do ns.AddLine(ivy, i % 2 == 0, "line " .. i) end
	check(#v.items <= 150 and v.items[1].gap == 4, "the list keeps at most 150 items")
end

-- Minimap button, minimizing, Escape and the conversation list
local mm = HushMinimapButton
check(mm and mm.parent == Minimap and mm.point and mm.point[1] == "CENTER", "minimap button created on the minimap")
check(math.abs(mm.point[4]) == 70 or math.abs(mm.point[5]) == 70, "square minimap puts the button on the edge")
mm.scripts.OnDragStart(mm)
cursor = { 500, 600 }
mm.scripts.OnUpdate(mm)
mm.scripts.OnDragStop(mm)
check(db.minimapAngle == 90 and mm.point[4] < 1e-9 and mm.point[5] == 70 and mm.scripts.OnUpdate == nil, "dragging moves it round the edge and stops updating after")

ns.CloseAll()
check(#ns.ActiveConvos() == 0, "close all")
db.hideInChat = true
Whisper("CHAT_MSG_WHISPER", "one", "Bob-MyRealm", 30, "Player-1")
Whisper("CHAT_MSG_WHISPER", "two", "Erin-MyRealm", 31, "Player-3")
local bf = c.frame
local closeBtn, minBtn
for _, f in ipairs(frames) do
	if f.kind == "Button" and f.parent and f.parent.parent == bf then
		if not closeBtn then closeBtn = f else minBtn = f end
	end
end
minBtn.scripts.OnClick(minBtn)
check(ns.IsMinimized(c) and #ns.ActiveConvos() == 2, "minimize hides the window but keeps the conversation")
c.unread = nil; erin.unread = nil; ns.UpdateBadge()
Whisper("CHAT_MSG_WHISPER", "three", "Bob-MyRealm", 32, "Player-1")
check(ns.IsMinimized(c) and c.unread == 1, "a new whisper leaves a minimized window down and counts it")
check(mm.badge.shown and mm.badge.text.text == 1, "minimap badge shows the unread count")
check(LastText(bf) == "three", "the line is in the minimized window for later")

mm.scripts.OnClick(mm, "LeftButton")
check(menu and menu.owner == nil, "click opens the conversation menu at the cursor, not owned by the button")
-- Blizzard closes a menu whose owner is hidden; EllesmereUI's flyout hides the button on the click.
mm:Hide()
check(menu.owner == nil or menu.owner:IsShown(), "the flyout closing does not take the menu with it")
mm:Show()
local item = MenuItem("Bob")
check(item and item.text:find("1 new", 1, true), "menu lists Bob with his unread count")
check(MenuItem("Erin") ~= nil and MenuItem("Close all") and MenuItem("Settings"), "menu lists other windows and actions")
check(MenuItem("Dan") ~= nil, "menu lists recent conversations without a window")
item.fn()
check(bf.shown and bf.box:HasFocus() and c.unread == nil and not mm.badge.shown, "choosing Bob restores and focuses him and clears the badge")

bf.box.scripts.OnEscapePressed(bf.box)
check(ns.IsMinimized(c) and not bf.box:HasFocus(), "Escape while typing minimizes the window")
ns.Open(c)
for _, name in ipairs(UISpecialFrames) do local f = _G[name]; if f:IsShown() then f:Hide() end end
check(ns.IsMinimized(c) and ns.IsMinimized(erin), "Escape in the game minimizes all Hush windows")

db.popMinimized = true
Whisper("CHAT_MSG_WHISPER", "four", "Bob-MyRealm", 33, "Player-1")
check(bf.shown, "with the option on, a whisper reopens a minimized window")
db.popMinimized = false

Hush.Reply()
check(erin.frame.shown or c.frame.shown, "reply restores a minimized window")

mm.scripts.OnClick(mm, "RightButton")
check(optionsOpened == 1, "right-click opens settings")
local printedBefore = #printed
RunTimers()
check(#printed == printedBefore, "no message when the settings panel opened")
settingsShown = false
mm.scripts.OnClick(mm, "RightButton")
RunTimers()
check(printed[#printed]:find("did not open the settings", 1, true), "says so when the game refuses to open settings")
settingsShown = true
optionsOpened = optionsOpened - 1
Hush_OnAddonCompartmentClick("Hush", "LeftButton")
check(menu.owner == nil, "addon compartment opens the menu")
Hush_OnAddonCompartmentClick("Hush", "RightButton")
check(optionsOpened == 2, "addon compartment right-click opens settings")

-- Public API
do
	ns.CloseAll()
	local seen = {}
	Hush.RegisterCallback(function(count) seen[#seen + 1] = count end)
	Hush.RegisterCallback(function() error("broken listener") end)
	Whisper("CHAT_MSG_WHISPER", "api", "Bob-MyRealm", 60, "Player-1")
	check(Hush.GetUnreadCount() == 1 and seen[#seen] == 1, "unread count and callback")
	check(#reportedErrors == 1, "a broken listener is reported, not fatal")
	local list = Hush.GetConversations()
	check(#list == 1 and list[1].name == "Bob" and list[1].nameColor == "ff3fc7eb" and list[1].unread == 1 and list[1].minimized == false, "conversation list")
	local calls = #seen
	ns.UpdateBadge()
	check(#seen == calls, "callback only when the count changes")
	c.frame.box:SetFocus()
	check(seen[#seen] == 0, "callback when read")
	menu = nil
	Hush.ShowMenu()
	check(menu ~= nil, "ShowMenu")
	local opened = optionsOpened
	Hush.OpenSettings()
	check(optionsOpened == opened + 1, "OpenSettings")
end

-- Message sound
do
	ns.CloseAll()
	db.hideInChat = true
	local function Last() return played[#played] end
	local n = #played
	Whisper("CHAT_MSG_WHISPER", "ding", "Bob-MyRealm", 70, "Player-1")
	check(#played == n + 1 and Last()[1]:find("Hush\\media\\message.ogg", 1, true) and Last()[2] == "Master", "a whisper plays Hush's sound on the master channel")
	n = #played
	Whisper("CHAT_MSG_WHISPER_INFORM", "my reply", "Bob-MyRealm", 71)
	check(#played == n, "no sound for your own messages")
	db.messageSound = "whisper"
	Whisper("CHAT_MSG_WHISPER", "ding", "Bob-MyRealm", 72, "Player-1")
	check(Last()[1] == "kit:" .. SOUNDKIT.TELL_MESSAGE and Last()[2] == "Master", "or the game's whisper sound")
	db.messageSound = "Ding"
	Whisper("CHAT_MSG_WHISPER", "ding", "Bob-MyRealm", 73, "Player-1")
	check(Last()[1] == "Sound\\ding.ogg", "or a SharedMedia sound")
	db.messageSound = "none"
	n = #played
	Whisper("CHAT_MSG_WHISPER", "quiet", "Bob-MyRealm", 74, "Player-1")
	check(#played == n, "or none")
	db.messageSound = "hush"
	db.hideInChat = false
	Whisper("CHAT_MSG_WHISPER", "shown in chat", "Bob-MyRealm", 75, "Player-1")
	check(#played == n, "no Hush sound when the normal chat shows the whisper and plays its own")
	db.hideInChat = true
	ns.PlayMessageSound("whisper")
	check(Last()[1] == "kit:" .. SOUNDKIT.TELL_MESSAGE, "picking a sound in settings plays it")
end

db.showMinimap = false
ns.UpdateMinimapButton()
check(not mm.shown, "minimap button can be hidden")

for _, line in ipairs(printed) do realPrint("print: ", line, "\n") end
