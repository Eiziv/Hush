local addonName, ns = ...

-- Whispers started in Blizzard's chat box (/w Name, /r, right-click Whisper, the friends list,
-- clicking a name) move into Hush: the chat box is closed and the Hush window takes the text.
--
-- Closing Blizzard's chat box from addon code marks its state as touched by an addon. While the
-- game locks chat for addons (encounters, keys, PvP matches), that can block messages typed in
-- the normal chat box until a /reload. Nothing is taken over during a lockdown, the setting can
-- be turned off, and a blocked message caused by Hush is reported straight away.

local hasanysecretvalues = hasanysecretvalues or function() return false end

local WHISPER_TYPES = { WHISPER = true, BN_WHISPER = true }

local busy = false -- set while Hush itself is closing the chat box
local takeovers = 0
local last -- the latest takeover, so /r can undo one aimed at Blizzard's stale reply target

local function Active(editBox)
	return ns.db.takeOverWhispers and not ns.IsChatLocked() and not busy and editBox:HasFocus()
end

local function CloseChatBox(editBox)
	busy = true
	local sticky = editBox:GetStickyType()
	if WHISPER_TYPES[sticky] then
		-- Otherwise the next Enter reopens the chat box as a whisper.
		editBox:SetStickyType("SAY")
	end
	editBox:ClearChat()
	busy = false
	takeovers = takeovers + 1
end

local function MoveInto(editBox, c, text)
	local wasOpen, wasShown = c.frame ~= nil, c.frame ~= nil and c.frame:IsShown()
	CloseChatBox(editBox)
	ns.Open(c, true)
	if text and text ~= "" then
		c.frame.box:SetText(text)
	end
	last = { convo = c, wasOpen = wasOpen, wasShown = wasShown, time = GetTime() }
end

local function OnUpdateHeader(editBox)
	if not Active(editBox) then return end
	local chatType, target = editBox:GetChatType(), editBox:GetTellTarget()
	if hasanysecretvalues(chatType, target) or not WHISPER_TYPES[chatType] or not target or target == "" then return end

	local c
	if chatType == "WHISPER" then
		c = ns.WhisperConvo(target)
	else
		c = ns.BNConvo(BNet_GetBNetIDAccount(target), target)
	end
	if c then
		MoveInto(editBox, c, editBox:GetText())
	end
end

-- /r: Blizzard replies to its own last whisper, which never sees whispers Hush hid from the
-- chat, so it can be someone older or nobody. Hush's own last whisper wins.
local function OnProcessChatType(editBox, msg, index)
	if index ~= "REPLY" or not ns.db.takeOverWhispers or ns.IsChatLocked() or busy then return end
	local c = ns.ReplyTarget()
	if not c then return end

	if editBox:HasFocus() then
		-- Blizzard had no reply target and left "/r " in the box.
		MoveInto(editBox, c, msg)
		return
	end

	-- Blizzard switched to its own target a moment ago and that was taken over already.
	local recent = last and last.time == GetTime() and last
	if not recent or recent.convo == c then return end
	local stale = recent.convo.frame
	local text = stale and stale.box:GetText()
	if not recent.wasOpen then
		ns.Close(recent.convo)
	elseif stale then
		stale.box:SetText("")
		if not recent.wasShown then stale:Hide() end -- back to minimized
	end
	ns.Open(c, true)
	if text and text ~= "" then c.frame.box:SetText(text) end
end

local hooked = {}

local function HookChatBox(editBox)
	if hooked[editBox] or not editBox.UpdateHeader or not editBox.ProcessChatType then return end
	hooked[editBox] = true
	hooksecurefunc(editBox, "UpdateHeader", OnUpdateHeader)
	hooksecurefunc(editBox, "ProcessChatType", OnProcessChatType)
end

function ns.InitTakeover()
	for i = 1, NUM_CHAT_WINDOWS do
		local editBox = _G["ChatFrame" .. i .. "EditBox"]
		if editBox then HookChatBox(editBox) end
	end
	-- Temporary chat windows get their boxes later.
	hooksecurefunc(ChatFrameUtil, "ActivateChat", HookChatBox)
end

local warned = false

function ns.OnActionBlocked(blamed, func)
	if blamed ~= addonName or warned then return end
	warned = true
	ns.Print(("The game blocked %s because Hush took over a whisper from the chat box earlier. /reload fixes it for now. To stop it happening, turn off \"Take over /w and Whisper buttons\" in /hush."):format(func or "a chat message"))
end

function ns.Check()
	if takeovers == 0 then
		ns.Print("Hush has not touched the chat box this session.")
		return
	end
	local clean = issecurevariable("ACTIVE_CHAT_EDIT_BOX")
	ns.Print(("Hush took over %d whisper%s from the chat box this session. The chat box is %s."):format(
		takeovers, takeovers == 1 and "" or "s",
		clean and "still clean" or "marked as touched by an addon. Messages typed in it can be blocked during keys and raid bosses until you /reload"))
end
