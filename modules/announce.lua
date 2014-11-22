local mod = SWDKP:NewModule("announce")

local Debug = LibStub("LibDebug-1.0")

local SendChatMessage = _G.SendChatMessage
if ChatThrottleLib then
  SendChatMessage = function(...)
                      ChatThrottleLib:SendChatMessage("NORMAL", "SWDKP", ...)
                    end
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    medium = "GUILD",
    events = {
      EPAward = true,
	  MassEPAward = true,
	  MassCoinAward = true,
	  GPAward = true,
	  BankedItem = false,
	  Decay = false,
	  StartRecurringAward = true,
	  StopRecurringAward = true,
	  ResumeRecurringAward = true,
	  EPGPReset = false,
    },
  },
}

mod.optionsName = "Announce"
mod.optionsDesc = "Announcement of DKP actions"
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = "Announces DKP actions to the specified medium.",
  },
  medium = {
    order = 10,
    type = "select",
    name = "Announce medium",
    desc = "Sets the announce medium Something Wicked DKP will use to announce DKP actions.",
    values = {
      ["GUILD"] = CHAT_MSG_GUILD,
      ["OFFICER"] = CHAT_MSG_OFFICER,
      ["RAID"] = CHAT_MSG_RAID,
      ["PARTY"] = CHAT_MSG_PARTY,
      ["CHANNEL"] = CUSTOM,
    },
  },
  channel = {
    order = 11,
    type = "input",
    name = "Custom announce channel name",
    desc = "Sets the custom announce channel name used to announce DKP actions.",
    disabled = function(i) return mod.db.profile.medium ~= "CHANNEL" end,
  },
  events = {
    order = 12,
    type = "multiselect",
    name = "Announce when:",
    values = {
      EPAward = "A member is awarded DKP",
      MassEPAward = "Guild or Raid are awarded DKP",
	  MassCoinAward = "A member uses a Bonus Coin",
      GPAward = "A member is charged DKP",
      BankedItem = "An item was disenchanted or deposited into the guild bank",
      Decay = "DKP decay",
      StartRecurringAward = "Recurring awards start",
      StopRecurringAward = "Recurring awards stop",
      ResumeRecurringAward = "Recurring awards resume",
      EPGPReset = "DKP reset",
    },
    width = "full",
    get = "GetEvent",
    set = "SetEvent",
  },
}

function mod:AnnounceTo(medium, fmt, ...)
  if not medium then return end

  local channel = GetChannelName(self.db.profile.channel or 0)

  -- Override raid and party if we are not grouped
  if (medium == "RAID" or medium == "GUILD") and not UnitInRaid("player") then
    medium = "GUILD"
  end

  local msg = string.format(fmt, ...)
  local str = "SWDKP:"
  for _,s in pairs({strsplit(" ", msg)}) do
    if #str + #s >= 250 then
      SendChatMessage(str, medium, nil, channel)
      str = "SWDKP:"
    end
    str = str .. " " .. s
  end

  SendChatMessage(str, medium, nil, channel)
end

function mod:Announce(fmt, ...)
  local medium = self.db.profile.medium

  return mod:AnnounceTo(medium, fmt, ...)
end

function mod:EPAward(event_name, name, reason, amount, mass)
  if mass then return end
  mod:Announce("%.3g DKP Awarded (%s) to %s", amount, reason, name)
end

function mod:GPAward(event_name, name, reason, amount, mass)
  if mass or amount == 0 then return end
  mod:Announce("%.3g DKP Charged (%s) to %s", amount, reason, name)
end

function mod:BankedItem(event_name, name, reason, amount, mass)
  mod:Announce("%s to %s", reason, name)
end

local playerRealm = GetRealmName()
local function MakeCommaSeparated(t)
  local first = true
  local awarded = ""

  for name in pairs(t) do
  	--Strip annoying realm names from chat announce when they are not needed
  	local shortName, realm = string.split("-", name)
  	if gsub(playerRealm, "[%s%-]", "") == realm then name = shortName end
    if first then
      awarded = name
      first = false
    else
      awarded = awarded..", "..name
    end
  end

  return awarded
end

function mod:MassEPAward(event_name, names, reason, amount,
                         extras_names, extras_reason, extras_amount)
  local normal = MakeCommaSeparated(names)
  mod:Announce("%.3g DKP Awarded (%s) to %s", amount, reason, normal)

  if extras_names then
    local extras = MakeCommaSeparated(extras_names)
    mod:Announce("%.3g DKP Awarded (%s) to %s", extras_amount, extras_reason, extras)
  end
end

function mod:MassCoinAward(event_name, names, reason, amount)
	local normal = MakeCommaSeparated(names)
	mod:Announce("%.3g DKP Awarded (%s) to %s", amount, reason, normal)
end

function mod:Decay(event_name, decay_p)
  mod:Announce("Decay of DKP by %d%%", decay_p)
end

function mod:StartRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  mod:Announce("Start recurring award (%s) %.3g DKP/%s", reason, amount, fmt:format(val))
end

function mod:ResumeRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  --mod:Announce("Resume recurring award (%s) %d DKP/%s", reason, amount, fmt:format(val))
  DEFAULT_CHAT_FRAME:AddMessage("SWDKP: Resuming recurring award (" .. reason .. ") " .. amount .. " DKP/" .. fmt:format(val))
end

function mod:StopRecurringAward(event_name)
  SWDKP.db.profile.standbybackup = {}
  mod:Announce("Stop recurring award")
end

function mod:EPGPReset(event_name)
  mod:Announce("DKP is reset")
end

function mod:GetEvent(i, e)
  return self.db.profile.events[e]
end

function mod:SetEvent(i, e, v)
  if v then
    Debug("Enabling announce of: %s", e)
    SWDKP.RegisterCallback(self, e)
  else
    Debug("Disabling announce of: %s", e)
    SWDKP.UnregisterCallback(self, e)
  end
  self.db.profile.events[e] = v
end

function mod:OnEnable()
  for e, _ in pairs(mod.optionsArgs.events.values) do
    if self.db.profile.events[e] then
      Debug("Enabling announce of: %s (startup)", e)
      SWDKP.RegisterCallback(self, e)
    end
  end
end

function mod:OnDisable()
  SWDKP.UnregisterAllCallbacks(self)
end
