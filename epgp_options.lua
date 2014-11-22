local GP = LibStub("LibGearPoints-1.0")
local Debug = LibStub("LibDebug-1.0")

local raiddifficultychoices = {
	[1] = "10 player",
	[2] = "25 player",
	[3] = "10 player (Heroic)",
	[4] = "25 player (Heroic)",
}

function SWDKP:SetupOptions()
  local options = {
    name = "Something Wicked DKP",
    type = "group",
    childGroups = "tab",
    handler = self,
    args = {
      help = {
        order = 1,
        type = "description",
        name = "Something Wicked DKP is an in game, relational loot distribution system",
      },
      hint = {
        order = 2,
        type = "description",
        name = "Hint: You can open these options by typing /swdkp config",
      },
	  raidsizecheck = {
		name = "Enable automatic raid difficulty switching",
		order = 3,
		type = "toggle",
		width = "double",
		get = "RaidSizeCheckGet",
		set = "RaidSizeCheckSet",
	  },
	  raidsize = {
		name = "Raid difficulty:",
		order = 4,
		type = "select",
		width = "normal",
		values = raiddifficultychoices,
		get = "RaidSizeGet",
		set = "RaidSizeSet",
		style = "dropdown",
		disabled = "DisableRaidSize",
	  },
	  guildrepair = {
		name = "Enable guild repairs when creating a guild raid group",
		order = 5,
		type = "toggle",
		width = "full",
		get = "GuildRepairGet",
		set = "GuildRepairSet",
		desc = "Turns on guild repairs 15 minutes after the creation of a guild raid.  Only guild masters can enable guild repairs, even if this option is on.",
		hidden = true, --keep hidden until I get time to fix this function
	  },
      list_errors = {
        order = 1000,
        type = "execute",
        name = "List errors",
		width = "normal",
        desc = "Lists errors during officer note parsing to the default chat frame. Examples are members with an invalid officer note.",
        func = function()
                 outputFunc = function(s) DEFAULT_CHAT_FRAME:AddMessage(s) end
                 SWDKP:ReportErrors(outputFunc)
               end,
      },
      reset = {
        order = 1001,
        type = "execute",
		width = "normal",
        name = "Reset DKP",
        desc = "Resets the DKP of all members of the guild. This will set all main toons' DKP values to 0. Use with care!",
        func = function() StaticPopup_Show("EPGP_RESET_EPGP") end,
      },
    },
  }

  local registry = LibStub("AceConfigRegistry-3.0")
  registry:RegisterOptionsTable("SWDKP Options", options)

  local dialog = LibStub("AceConfigDialog-3.0")
  dialog:AddToBlizOptions("SWDKP Options", "SWDKP")

  -- Setup options for each module that defines them.
  for name, m in self:IterateModules() do
    --print(name)
    if m.optionsArgs then
	  --print(name)
      -- Set all options under this module as disabled when the module
      -- is disabled.
      for n, o in pairs(m.optionsArgs) do
        if o.disabled then
		  --print(n)
          local old_disabled = o.disabled
          o.disabled = function(i)
                         return old_disabled(i) or m:IsDisabled()
                       end
        else
		  --print(n)
          o.disabled = "IsDisabled"
        end
      end
      -- Add the enable/disable option.
      m.optionsArgs.enabled = {
        order = 0,
        type = "toggle",
        width = "full",
        name = ENABLE,
        get = "IsEnabled2",
        set = "SetEnabled",
      }
    end
    if m.optionsName then
      registry:RegisterOptionsTable("SWDKP" .. name, {
                                      handler = m,
                                      order = 100,
                                      type = "group",
                                      name = m.optionsName,
                                      desc = m.optionsDesc,
                                      args = m.optionsArgs,
                                      get = "GetDBVar",
                                      set = "SetDBVar",
                                    })
      dialog:AddToBlizOptions("SWDKP" .. name, m.optionsName, "SWDKP")
    end
	if m.db.profile.enabled then
		m:Enable()
	else
		m:Disable()
	end
  end

  SWDKP:RegisterChatCommand("swdkp", "ProcessCommand")
end



function SWDKP:RaidSizeCheckGet(info)
	if SWDKP.db then
		return SWDKP.db.profile.raidsizecheck
	end
end

function SWDKP:RaidSizeCheckSet(info, value)
	if SWDKP.db then
		SWDKP.db.profile.raidsizecheck = not SWDKP.db.profile.raidsizecheck
	end
end

function SWDKP:RaidSizeGet(info)
	if SWDKP.db then
		return SWDKP.db.profile.raidsize
	end
end

function SWDKP:RaidSizeSet(info, value)
	if SWDKP.db then
		SWDKP.db.profile.raidsize = value
	end
end

function SWDKP:DisableRaidSize()
	if SWDKP.db then
		if not SWDKP.db.profile.raidsizecheck then
			return true
		else
			return false
		end
	end
end

function SWDKP:GuildRepairGet(info)
	if SWDKP.db then
		return SWDKP.db.profile.guildrepair
	end
end

function SWDKP:GuildRepairSet(info, value)
	if SWDKP.db then
		SWDKP.db.profile.guildrepair = not SWDKP.db.profile.guildrepair
	end
end

function SWDKP:ProcessCommand(str)
  str = str:gsub("%%t", UnitName("target") or "notarget")
  local command, nextpos = self:GetArgs(str, 1)
  if command == "config" then
    InterfaceOptionsFrame_OpenToCategory("SWDKP")
  elseif command == "debug" then
    Debug:Toggle()
  elseif command == "massaward" then
    local reason, amount = self:GetArgs(str, 2, nextpos)
    amount = tonumber(amount)
    if self:CanIncEPBy(reason, amount) then
      self:IncMassEPBy(reason, amount)
    end
  elseif command == "award" then
    local member, reason, amount = self:GetArgs(str, 3, nextpos)
    amount = tonumber(amount)
    if self:CanIncEPBy(reason, amount) then
      self:IncEPBy(member, reason, amount)
    end
  elseif command == "charge" then
    local member, itemlink, amount = self:GetArgs(str, 3, nextpos)
    self:Print(member, itemlink, amount)
    if amount then
      amount = tonumber(amount)
    else
      local gp1, gp2 = GP:GetValue(itemlink)
      self:Print(gp1, gp2)
      -- Only automatically fill amount if we have a single GP value.
      if gp1 and not gp2 then
        amount = gp1
      end
    end

    if self:CanIncGPBy(itemlink, amount) then
      self:IncGPBy(member, itemlink, amount)
    end
  elseif command == "decay" then
    if SWDKP:CanDecayEPGP() then
      StaticPopup_Show("EPGP_DECAY_EPGP", SWDKP:GetDecayPercent())
    end
  elseif command == "help" then
    local help = {
      self.version,
      "   config - ".."Open the configuration options",
      "   debug - ".."Open the debug window",
      "   massaward <reason> <amount> - ".."Mass DKP Award",
      "   award <name> <reason> <amount> - ".."Award DKP",
      "   charge <name> <itemlink> [<amount>] - ".."Charge DKP",
      "   decay - "..("Decay of DKP by %d%%"):format(SWDKP:GetDecayPercent()),
    }
    SWDKP:Print(table.concat(help, "\n"))
  else
    SWDKP:ToggleUI()
  end
end

function SWDKP:ToggleUI()
  if EPGPFrame and IsInGuild() then
    if EPGPFrame:IsShown() then
      HideUIPanel(EPGPFrame)
    else
      ShowUIPanel(EPGPFrame)
    end
  end
end
