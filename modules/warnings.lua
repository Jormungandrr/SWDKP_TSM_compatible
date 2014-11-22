local mod = SWDKP:NewModule("warnings", "AceHook-3.0")

StaticPopupDialogs["EPGP_OFFICER_NOTE_WARNING"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "Something Wicked DKP is using Officer Notes for data storage. Do you really want to edit the Officer Note by hand?",
  button1 = YES,
  button2 = NO,
  timeout = 0,
  OnAccept = function(self)
               self:Hide()
               mod.hooks[GuildMemberOfficerNoteBackground]["OnMouseUp"]()
             end,
  whileDead = 1,
  hideOnEscape = 1,
  showAlert = 1,
  enterClicksFirstButton = 1,
}
--[[
StaticPopupDialogs["EPGP_MULTIPLE_MASTERS_WARNING"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "Make sure you are the only person changing DKP. If you have multiple people changing DKP at the same time, for example one awarding DKP and another charging DKP, you *are* going to have data loss.",
  button1 = OKAY,
  showAlert = 1,
  enterClicksFirstButton = 1,
  timeout = 15,
}
--]]
mod.dbDefaults = {
  profile = {
    enabled = true,
  }
}

function mod:OnEnable()
  local function officer_note_warning()
    StaticPopup_Show("EPGP_OFFICER_NOTE_WARNING")
  end

  if GuildMemberOfficerNoteBackground and
     GuildMemberOfficerNoteBackground:HasScript("OnMouseUp") then
    self:RawHookScript(GuildMemberOfficerNoteBackground, "OnMouseUp",
                       officer_note_warning)
  end

  local events_for_multiple_masters_warning = {
    "StartRecurringAward",
    "EPAward",
    "GPAward",
  }

  --[[
  -- We want to show this warning just once.
  local function multiple_masters_warning()
    StaticPopup_Show("EPGP_MULTIPLE_MASTERS_WARNING")
    for _, event in pairs(events_for_multiple_masters_warning) do
      SWDKP.UnregisterCallback(self, event)
    end
  end


  for _, event in pairs(events_for_multiple_masters_warning) do
    SWDKP.RegisterCallback(self, event, multiple_masters_warning)
  end
  --]]
end
