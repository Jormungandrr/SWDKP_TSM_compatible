local mod = SWDKP:NewModule("whisper", "AceEvent-3.0")

local senderMap = {}

local SendChatMessage = _G.SendChatMessage
if ChatThrottleLib then
  SendChatMessage = function(...)
                      ChatThrottleLib:SendChatMessage("NORMAL", "SWDKP", ...)
                    end
end

local function MakeStandbyCommaSeparated(t)
  local first = true
  local awarded = ""

  for _, name in pairs(t) do
    if first then
      awarded = name
      first = false
    else
      awarded = awarded..", "..name
    end
  end

  return awarded
end

function mod:CHAT_MSG_WHISPER(event_name, msg, sender)
  if not UnitInRaid("player") then return end

  if msg:sub(1, 5):lower() ~= 'swdkp' then return end
  sender = Ambiguate(sender, "none")

  local member = msg:sub(13):match("([^ ]+)")
  if member then
    -- http://lua-users.org/wiki/LuaUnicode
    local firstChar, offset = member:match("([%z\1-\127\194-\244][\128-\191]*)()")
    member = firstChar:upper()..member:sub(offset):lower()
  else
    member = sender
  end

  senderMap[member] = sender
  
  msg = msg:lower()
  
  if msg == 'swdkp add' then

	  if not SWDKP:GetEPGP(member) then
		SendChatMessage(("%s is not eligible for DKP awards"):format(member),
						"WHISPER", nil, sender)
	  elseif SWDKP:IsMemberInAwardList(member) then
		SendChatMessage(("%s is already in the award list"):format(member),
						"WHISPER", nil, sender)
	  else
		SWDKP:SelectMember(member)
		SendChatMessage(("%s is added to the award list"):format(member),
						"WHISPER", nil, sender)
	  end
  elseif msg == 'swdkp remove' then
	  if UnitInRaid(member) then
		SendChatMessage(("%s is currently in the raid can cannot be removed from the award list"):format(member), "WHISPER", nil, sender)
	  elseif SWDKP:DeSelectMember(member) then
		SendChatMessage(("%s is removed from the award list"):format(member), "WHISPER", nil, sender)
	  else
		SendChatMessage(("%s is not on the award list and cannot be removed"):format(member), "WHISPER", nil, sender)
	  end
  elseif msg == 'swdkp who' then
	  if #SWDKP.db.profile.standbybackup > 0 then
		SendChatMessage((MakeStandbyCommaSeparated(SWDKP.db.profile.standbybackup)):format(member), "WHISPER", nil, sender)
	  else
	    SendChatMessage(("There is no one on the standby list"), "WHISPER", nil, sender)
	  end
  else
	  SendChatMessage(("Whisper me 'swdkp add' to add yourself to the award list, 'swdkp remove' to remove yourself from the award list, or 'swdkp who' to see who is currently on the award list"):format(member), "WHISPER", nil, sender)
  end
end

local function AnnounceMedium()
  local medium = mod.db.profile.medium
  if medium ~= "NONE" then
    return medium
  end
end

local function SendNotifiesAndClearExtras(
    event_name, names, reason, amount,
    extras_awarded, extras_reason, extras_amount)
  local medium = AnnounceMedium()
  if medium then
    SWDKP:GetModule("announce"):AnnounceTo(medium, "Whisper me: 'swdkp add' to add yourself to the standby list")
  end

  if extras_awarded then
    for member,_ in pairs(extras_awarded) do
      local sender = senderMap[member]
      if sender then
        SendChatMessage(("%+d DKP (%s) to %s"):format(
                          extras_amount, extras_reason, member),
                        "WHISPER", nil, sender)
        --EPGP:DeSelectMember(member)
        --SendChatMessage(
        --  L["%s is now removed from the award list"]:format(member),
        --  "WHISPER", nil, sender)
      end
      --senderMap[member] = nil
    end
  end
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    medium = "GUILD",
  }
}

mod.optionsName = "Whisper"
mod.optionsDesc = "Standby whispers in raid"
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = "Automatic handling of the standby list through whispers when in raid. When this is enabled, the standby list is cleared after each reward.",
  },
  medium = {
    order = 10,
    type = "select",
    name = "Announce medium",
    desc = "Sets the announce medium Something Wicked DKP will use to announce DKP actions.",
    values = {
      ["GUILD"] = CHAT_MSG_GUILD,
      ["CHANNEL"] = CUSTOM,
      ["NONE"] = NONE,
    },
  },
}

function mod:OnEnable()
  self:RegisterEvent("CHAT_MSG_WHISPER")
  SWDKP.RegisterCallback(self, "MassEPAward", SendNotifiesAndClearExtras)
  SWDKP.RegisterCallback(self, "StartRecurringAward", SendNotifiesAndClearExtras)
end

function mod:OnDisable()
  SWDKP.UnregisterAllCallbacks(self)
end
