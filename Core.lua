local _, ns = ...

ns.DEFAULTS = {
	font = "eui", -- "eui" follows EllesmereUI's font, otherwise a SharedMedia font name or a file path
	fontSize = 13,
	outline = "",
	shadow = true,
	bgAlpha = 0.85,
	hideInChat = true,
	sound = true,
	takeOverReply = true,
	takeOverWhispers = true,
	keepFocus = false,
	popMinimized = false,
	showMinimap = true,
	minimapAngle = 210,
	width = 360,
	height = 220,
	-- x, y: where the top left corner of the next window goes, saved when a window is moved
}

local HISTORY_LINES = 100
local HISTORY_DAYS = 30
local DEFERRED_MAX = 50

local issecretvalue = issecretvalue or function() return false end
local hasanysecretvalues = hasanysecretvalues or function() return false end

-- value: whether the message was sent to us
local WHISPER_EVENTS = {
	CHAT_MSG_WHISPER = true,
	CHAT_MSG_WHISPER_INFORM = false,
	CHAT_MSG_BN_WHISPER = true,
	CHAT_MSG_BN_WHISPER_INFORM = false,
}
local BN_EVENTS = { CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true }

local db
local convos = {} -- key -> { key, h = saved history entry, frame, unread, bnID, accountName }
ns.convos = convos
local lastIn, lastOut
-- Whispers that arrived while the game hid chat from addons, by chat line ID.
local deferred = {}
-- During encounters, keys and PvP matches the game blocks addon chat and hides message contents.
local chatLocked = false

function ns.Print(text)
	print("|cff33ff99Hush|r: " .. text)
end

function ns.IsChatLocked()
	return chatLocked
end

-------------------------------------------------------------------------------
-- Conversations

local function FullName(name)
	if not name:find("-", 1, true) then
		name = name .. "-" .. GetNormalizedRealmName()
	end
	return name
end

local function Wrap(key, kind, target)
	local c = convos[key]
	if c then return c end
	local h = db.history[key]
	if not h then
		h = { kind = kind, target = target, t = time(), lines = {} }
		db.history[key] = h
	end
	c = { key = key, h = h }
	convos[key] = c
	return c
end

function ns.WhisperConvo(name)
	name = FullName(name)
	local c = Wrap("w:" .. strlower(name), "w", name)
	c.h.target = name -- keep the spelling the server used last
	return c
end

local function FindFriend(field, value)
	for i = 1, BNGetNumFriends() do
		local info = C_BattleNet.GetFriendAccountInfo(i)
		if info and info[field] == value then return info end
	end
end

-- Battle.net account IDs only hold for one session, so conversations are keyed by BattleTag.
function ns.BNConvo(bnID, accountName)
	local info
	if bnID and bnID ~= 0 then
		info = C_BattleNet.GetAccountInfoByID(bnID)
	elseif accountName then
		info = FindFriend("accountName", accountName)
	end
	if not info or not info.battleTag then return end
	local c = Wrap("bn:" .. strlower(info.battleTag), "bn", info.battleTag)
	c.bnID = info.bnetAccountID
	c.accountName = info.accountName
	return c
end

function ns.ResolveBNID(c)
	if c.bnID then
		local info = C_BattleNet.GetAccountInfoByID(c.bnID)
		if info and info.battleTag == c.h.target then return c.bnID end
	end
	local info = FindFriend("battleTag", c.h.target)
	c.bnID = info and info.bnetAccountID
	c.accountName = info and info.accountName or c.accountName
	return c.bnID
end

function ns.DisplayName(c)
	if c.h.kind == "bn" then
		return c.accountName or c.h.target:match("^[^#]+")
	end
	return Ambiguate(c.h.target, "none")
end

function ns.NameColor(c)
	if c.h.kind == "bn" then return "ff82c5ff" end
	local color = c.h.class and RAID_CLASS_COLORS[c.h.class]
	return color and color.colorStr or "ffd8d8d8"
end

function ns.AddLine(c, inbound, text)
	local now = time()
	local lines = c.h.lines
	local line = { now, inbound, text }
	lines[#lines + 1] = line
	if #lines > HISTORY_LINES then
		tremove(lines, 1)
	end
	c.h.t = now
	if c.frame then
		ns.ShowLine(c.frame, line)
	end
end

function ns.Send(c, text)
	if chatLocked then
		ns.Notice(c, "The game blocks addon chat during encounters, keys and PvP matches. Use the normal chat box for now.")
		return false
	end
	if c.h.kind == "bn" then
		local bnID = ns.ResolveBNID(c)
		if not bnID then
			ns.Notice(c, "Not online on Battle.net.")
			return false
		end
		local SendWhisper = C_BattleNet and C_BattleNet.SendWhisper or BNSendWhisper
		SendWhisper(bnID, text)
	else
		C_ChatInfo.SendChatMessage(text, "WHISPER", nil, c.h.target)
	end
	return true
end

local function MostRecent()
	local best
	for key, h in pairs(db.history) do
		if not best or h.t > db.history[best].t then best = key end
	end
	if not best then return end
	local h = db.history[best]
	return convos[best] or Wrap(best, h.kind, h.target)
end

local function Focus(c)
	if not c then
		ns.Print("No whispers yet.")
	elseif chatLocked then
		ns.Print("The game blocks addon chat right now. Use /r in the normal chat box.")
	else
		ns.Open(c, true)
	end
end

-- Saved conversations without a window, newest first.
function ns.RecentConvos(limit)
	local keys = {}
	for key in pairs(db.history) do
		if not (convos[key] and convos[key].frame) then keys[#keys + 1] = key end
	end
	table.sort(keys, function(a, b) return db.history[a].t > db.history[b].t end)
	local list = {}
	for i = 1, math.min(limit, #keys) do
		local h = db.history[keys[i]]
		list[i] = Wrap(keys[i], h.kind, h.target)
	end
	return list
end

function ns.ReplyTarget()
	return lastIn or MostRecent()
end

function ns.Reply()
	Focus(ns.ReplyTarget())
end

function ns.Rewhisper()
	Focus(lastOut or lastIn or MostRecent())
end

-------------------------------------------------------------------------------
-- Incoming and outgoing whispers

local function HandleWhisper(event, text, sender, guid, bnID, replayed)
	local c
	if BN_EVENTS[event] then
		c = ns.BNConvo(bnID, sender)
	else
		c = ns.WhisperConvo(sender)
	end
	if not c then return end

	local inbound = WHISPER_EVENTS[event]
	if inbound then
		if not c.h.class and guid and guid ~= "" then
			local _, class = GetPlayerInfoByGUID(guid)
			c.h.class = class
		end
		lastIn = c
	else
		lastOut = c
	end

	-- A minimized window stays down: the minimap button counts the unread lines.
	if not ns.IsMinimized(c) or db.popMinimized then
		ns.Open(c)
	end
	ns.AddLine(c, inbound, text)
	if inbound then
		ns.MarkUnread(c)
		-- Blizzard only alerts for whispers it shows itself.
		if db.hideInChat and not replayed then
			if db.sound then PlaySound(SOUNDKIT.TELL_MESSAGE) end
			FlashClientIcon()
		end
	end
end

local function Replay()
	if not C_ChatInfo.GetChatLineText then
		wipe(deferred)
		return
	end
	local kept = {}
	for _, d in ipairs(deferred) do
		local text = C_ChatInfo.GetChatLineText(d.lineID)
		local sender = C_ChatInfo.GetChatLineSenderName(d.lineID)
		local guid = C_ChatInfo.GetChatLineSenderGUID(d.lineID)
		if hasanysecretvalues(text, sender, guid) then
			kept[#kept + 1] = d
		elseif text and sender then
			HandleWhisper(d.event, text, sender, guid, nil, true)
		end
	end
	deferred = kept
end

-- Chat frame filters: true hides the message from the normal chat.
local function WhisperFilter(_, event, ...)
	if not db.hideInChat or hasanysecretvalues(...) then return false end
	if BN_EVENTS[event] then
		-- Only hide what HandleWhisper can place in a window.
		local bnID = select(13, ...)
		return bnID ~= nil and C_BattleNet.GetAccountInfoByID(bnID) ~= nil
	end
	return true
end

local function OpenWhisperConvo(name)
	local c = convos["w:" .. strlower(FullName(name))]
	return c and c.frame and c
end

local function AwayFilter(_, _, text, sender)
	if not db.hideInChat or hasanysecretvalues(text, sender) then return false end
	return OpenWhisperConvo(sender) ~= nil
end

local notFoundPattern

local function OnSystemMessage(text)
	if hasanysecretvalues(text) then return end
	local name = text:match(notFoundPattern)
	local c = name and OpenWhisperConvo(name)
	if c then
		ns.Notice(c, text)
	end
end

-------------------------------------------------------------------------------
-- Reply keys: whatever is bound to Blizzard's reply commands opens Hush instead. Override
-- bindings leave the saved key bindings alone, and Blizzard's chat box is never touched,
-- so it stays clean of addon taint when the game locks chat.

local frame = CreateFrame("Frame")
local boundKeys = "" -- what the overrides were made from, so UPDATE_BINDINGS only acts on real changes

local function ReplyKeys()
	return strjoin(",", GetBindingKey("REPLY")) .. ";" .. strjoin(",", GetBindingKey("REPLY2"))
end

function ns.UpdateReplyBinding()
	local keys = db.takeOverReply and not chatLocked and ReplyKeys() or ""
	if keys == boundKeys then return end
	if InCombatLockdown() then
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	ClearOverrideBindings(frame)
	if keys ~= "" then
		for _, command in ipairs({ "REPLY", "REPLY2" }) do
			for _, key in ipairs({ GetBindingKey(command) }) do
				SetOverrideBinding(frame, false, key, "HUSH_" .. command)
			end
		end
	end
	boundKeys = keys
end

-------------------------------------------------------------------------------

BINDING_HEADER_HUSH = "Hush"
BINDING_NAME_HUSH_REPLY = "Reply to the last whisper"
BINDING_NAME_HUSH_REPLY2 = "Whisper the last person you whispered"

local function Init()
	HushDB = HushDB or {}
	db = HushDB
	ns.db = db
	for key, value in pairs(ns.DEFAULTS) do
		if db[key] == nil then db[key] = value end
	end
	db.history = db.history or {}
	db.topBar, db.cleanIcons = nil, nil -- settings from an earlier version
	local cutoff = time() - HISTORY_DAYS * 86400
	for key, h in pairs(db.history) do
		if (h.t or 0) < cutoff then db.history[key] = nil end
	end

	chatLocked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
	notFoundPattern = "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"

	local AddFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
	for event in pairs(WHISPER_EVENTS) do
		frame:RegisterEvent(event)
		AddFilter(event, WhisperFilter)
	end
	for _, event in ipairs({ "CHAT_MSG_AFK", "CHAT_MSG_DND" }) do
		frame:RegisterEvent(event)
		AddFilter(event, AwayFilter)
	end
	frame:RegisterEvent("CHAT_MSG_SYSTEM")
	frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
	frame:RegisterEvent("UPDATE_BINDINGS")
	frame:RegisterEvent("ADDON_ACTION_BLOCKED")
	frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

	ns.UpdateReplyBinding()
	ns.InitTakeover()
	ns.UpdateMinimapButton()
	ns.BuildOptions()
end

local CHAT_RESTRICTION = Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Chat

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...)
	if WHISPER_EVENTS[event] ~= nil then
		if hasanysecretvalues(...) then
			-- Shown in the normal chat for now; inbound ones join their window once chat unlocks.
			local lineID = select(11, ...)
			if WHISPER_EVENTS[event] and lineID and not issecretvalue(lineID) and #deferred < DEFERRED_MAX then
				deferred[#deferred + 1] = { event = event, lineID = lineID }
			end
			return
		end
		local text, sender, _, _, _, _, _, _, _, _, _, guid, bnID = ...
		HandleWhisper(event, text, sender, guid, bnID)
	elseif event == "CHAT_MSG_SYSTEM" then
		OnSystemMessage(...)
	elseif event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" then
		local text, sender = ...
		if hasanysecretvalues(text, sender) then return end
		local c = OpenWhisperConvo(sender)
		if c then
			local prefix = event == "CHAT_MSG_AFK" and CHAT_AFK_GET or CHAT_DND_GET
			ns.Notice(c, prefix:format(ns.DisplayName(c)) .. text)
		end
	elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
		local restriction, state = ...
		if restriction == CHAT_RESTRICTION then
			chatLocked = state ~= 0
			if not chatLocked then Replay() end
			ns.UpdateReplyBinding()
		end
	elseif event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_BINDINGS" then
		ns.UpdateReplyBinding()
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		ns.OnActionBlocked(...)
	elseif event == "PLAYER_LOGIN" then
		Init()
	end
end)

-------------------------------------------------------------------------------

SLASH_HUSH1 = "/hush"
SlashCmdList.HUSH = function(msg)
	local command, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	command = strlower(command)
	if command == "" then
		ns.OpenOptions()
	elseif command == "font" and rest ~= "" then
		db.font = rest
		ns.ApplyLookAll()
		ns.Print("Font set to " .. rest)
	elseif command == "reset" then
		db.x, db.y, db.width, db.height = nil, nil, ns.DEFAULTS.width, ns.DEFAULTS.height
		ns.Print("Window position and size reset. Applies to windows you open next.")
	elseif command == "check" then
		ns.Check()
	elseif command == "help" then
		ns.Print("/hush - settings, /hush Name - whisper someone, /hush font <SharedMedia name or file path>, /hush reset - window position, /hush check - whether Hush has touched the chat box")
	else
		ns.Open(ns.WhisperConvo(msg:match("^%s*(.-)%s*$")), true)
	end
end
