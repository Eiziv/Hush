local _, ns = ...

-- Hush's public API, for other addons: a data bar, a top bar button, a broker display.
-- Everything else in Hush is private and may change between versions; this will not.
--
--   Hush.GetUnreadCount()         unread whisper lines across all conversations
--   Hush.GetConversations()       open and minimized conversations, newest first, as
--                                 { name = "Bob", nameColor = "ffRRGGBB", unread = 2, minimized = false }
--   Hush.ShowMenu()               the conversation menu at the cursor, as on the minimap button
--   Hush.OpenSettings()           Hush's settings page
--   Hush.RegisterCallback(func)   func(unreadCount) runs whenever the unread count changes
--   Hush.Reply(), Hush.Rewhisper() what the reply key bindings do

local callbacks = {}
local lastCount = 0

Hush = {
	GetUnreadCount = function()
		return ns.UnreadTotal()
	end,

	GetConversations = function()
		local list = {}
		for _, c in ipairs(ns.ActiveConvos()) do
			list[#list + 1] = {
				name = ns.DisplayName(c),
				nameColor = ns.NameColor(c),
				unread = c.unread or 0,
				minimized = ns.IsMinimized(c),
			}
		end
		return list
	end,

	ShowMenu = function()
		ns.ShowMenu()
	end,

	OpenSettings = function()
		ns.OpenOptions()
	end,

	RegisterCallback = function(func)
		callbacks[#callbacks + 1] = func
	end,

	Reply = function()
		ns.Reply()
	end,

	Rewhisper = function()
		ns.Rewhisper()
	end,
}

-- A listener that errors is reported, but doesn't stop Hush or the other listeners.
function ns.FireUnreadChanged(count)
	if count == lastCount then return end
	lastCount = count
	for _, func in ipairs(callbacks) do
		xpcall(function() func(count) end, geterrorhandler())
	end
end
