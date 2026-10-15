local _, ns = ...

local category
local VAR_TYPES = { boolean = Settings.VarType.Boolean, number = Settings.VarType.Number, string = Settings.VarType.String }

local function FontOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("eui", EllesmereUI and "EllesmereUI font" or "Game font")
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM then
		for _, name in ipairs(LSM:List("font")) do
			container:Add(name, name)
		end
	end
	local current = ns.db.font
	if current:find("[\\/]") then
		container:Add(current, "Custom: " .. current:match("([^\\/]+)$"))
	end
	return container:GetData()
end

local function OutlineOptions()
	local container = Settings.CreateControlTextContainer()
	container:Add("", "None")
	container:Add("OUTLINE", "Thin")
	container:Add("THICKOUTLINE", "Thick")
	return container:GetData()
end

function ns.BuildOptions()
	category = Settings.RegisterVerticalLayoutCategory("Hush")
	local db = ns.db

	local function Setting(key, name, onChange)
		local default = ns.DEFAULTS[key]
		local setting = Settings.RegisterAddOnSetting(category, "HUSH_" .. key:upper(), key, db, VAR_TYPES[type(default)], name, default)
		if onChange then setting:SetValueChangedCallback(onChange) end
		return setting
	end

	local function Slider(setting, min, max, step, format, tooltip)
		local options = Settings.CreateSliderOptions(min, max, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
		Settings.CreateSlider(category, setting, options, tooltip)
	end

	local look = ns.ApplyLookAll
	Settings.CreateDropdown(category, Setting("font", "Font", look), FontOptions,
		"EllesmereUI font follows the font you picked in EllesmereUI. Any SharedMedia font works too, or /hush font <file path> for your own file.")
	Slider(Setting("fontSize", "Font size", look), 8, 24, 1, function(value)
		return ("%d"):format(value)
	end)
	Settings.CreateDropdown(category, Setting("outline", "Outline", look), OutlineOptions)
	Settings.CreateCheckbox(category, Setting("shadow", "Text shadow", look))
	Slider(Setting("bgAlpha", "Background opacity", look), 0, 1, 0.05, function(value)
		return ("%d%%"):format(value * 100 + 0.5)
	end)

	Settings.CreateCheckbox(category, Setting("showMinimap", "Minimap button", ns.UpdateMinimapButton), "Click for your conversations, right-click for these settings. Hush is also in the addon list under the minimap.")
	Settings.CreateCheckbox(category, Setting("popMinimized", "New whispers reopen minimized windows"), "Off: a minimized window stays down and the minimap button counts its new lines.")
	Settings.CreateCheckbox(category, Setting("hideInChat", "Hide whispers from the normal chat"), "While the game locks chat for addons (encounters, keys, PvP matches) whispers show in the normal chat anyway, and move into their window afterwards.")
	Settings.CreateCheckbox(category, Setting("sound", "Whisper sound"))
	Settings.CreateCheckbox(category, Setting("takeOverReply", "Reply key opens Hush", ns.UpdateReplyBinding), "Your reply key (R by default) opens the last whisper window instead of the chat box. It goes back to the normal reply while the game locks chat for addons.")
	Settings.CreateCheckbox(category, Setting("takeOverWhispers", "Take over /w and Whisper buttons"), "/w Name, /r, right-click Whisper, the friends list and clicking names open Hush instead of the chat box, like WIM.\n\nThis closes Blizzard's chat box from addon code. During keys and raid bosses the game may then block messages typed in the normal chat box until you /reload. Hush tells you if that happens, and /hush check shows whether the chat box has been touched.")
	Settings.CreateCheckbox(category, Setting("keepFocus", "Keep typing after sending"), "Off: Enter sends and hands the keyboard back to the game, like the normal chat.")

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	if not category then
		ns.Print("The settings page did not load. BugSack should have the error.")
		return
	end
	Settings.OpenToCategory(category:GetID())
	-- If the game refuses, say so rather than doing nothing. One check, a frame later.
	C_Timer.After(0, function()
		if SettingsPanel and not SettingsPanel:IsShown() then
			ns.Print("The game did not open the settings. Esc > Options > AddOns > Hush gets there too.")
		end
	end)
end
