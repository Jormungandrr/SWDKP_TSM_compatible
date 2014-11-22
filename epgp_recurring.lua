local GS = LibStub("LibGuildStorage-1.2")
local Debug = LibStub("LibDebug-1.0")

local callbacks = SWDKP.callbacks

local frame = CreateFrame("Frame", "EPGP_RecurringAwardFrame")
local timeout = 0
local function RecurringTicker(self, elapsed)
  -- SWDKP's db is available after GUILD_ROSTER_UPDATE. So we have a
  -- guard.
  if not SWDKP.db then return end
  

  local vars = SWDKP.db.profile
  local now = time()
  --print(timeout, "timeout")
  --print(now, "now")
  if now > vars.next_award and GS:IsCurrentState() then
    SWDKP:IncMassEPBy(vars.next_award_reason, vars.next_award_amount)
    vars.next_award =
      vars.next_award + vars.recurring_ep_period_mins * 60
  end
  timeout = timeout + elapsed
  --print(vars.next_award_reason)
  --print(vars.next_award_amount)
  --print(vars.next_award - now)
  if timeout > 0.5 then
    callbacks:Fire("RecurringAwardUpdate",
                   vars.next_award_reason,
                   vars.next_award_amount,
                   vars.next_award - now)
    timeout = 0
  end
end
frame:SetScript("OnUpdate", RecurringTicker)
frame:Hide()

function SWDKP:StartRecurringEP(reason, amount)
  --print("StartRecurringEP")
  local vars = SWDKP.db.profile
  if vars.next_award then
    return false
  end

  vars.next_award_reason = reason
  vars.next_award_amount = amount
  vars.next_award = time() + vars.recurring_ep_period_mins * 60
  frame:Show()

  callbacks:Fire("StartRecurringAward",
                 vars.next_award_reason,
                 vars.next_award_amount,
                 vars.recurring_ep_period_mins)
  return true
end

StaticPopupDialogs["EPGP_RECURRING_RESUME"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS,
  text = "%s",
  button1 = YES,
  button2 = NO,
  timeout = 0,
  hideOnEscape = 1,
  whileDead = 1,
  OnAccept = function()
               callbacks:Fire("ResumeRecurringAward",
                              SWDKP.db.profile.next_award_reason,
                              SWDKP.db.profile.next_award_amount,
                              SWDKP.db.profile.recurring_ep_period_mins)
               frame:Show()
             end,
  OnCancel = function(self, data, reason)
               if reason ~= "override" then
                 SWDKP:StopRecurringEP()
               end
             end,
}

function SWDKP:ResumeRecurringEP()
  --print("ResumeRecurringEP")
  local vars = SWDKP.db.profile

  local period_secs = vars.recurring_ep_period_mins * 60
  local timeout = vars.next_award + period_secs - time()
  StaticPopupDialogs["EPGP_RECURRING_RESUME"].timeout = timeout

  StaticPopup_Show(
    "EPGP_RECURRING_RESUME",
    -- We need to do the formatting here because static popups do
    -- not allow for 3 arguments to the formatting function.
    ("Do you want to resume recurring award (%s) %d DKP/%s?"):format(
      vars.next_award_reason,
      vars.next_award_amount,
      SWDKP:RecurringEPPeriodString()))
end

function SWDKP:CanResumeRecurringEP()
  local vars = SWDKP.db.profile
  local now = time()
  --print("vars.next_award", vars.next_award)
  --print("now", now)
  if not vars.next_award then return false end

  local period_secs = vars.recurring_ep_period_mins * 60
  local last_award = vars.next_award - period_secs
  local next_next_award = vars.next_award + period_secs
  --print("last_award", last_award)
  --print("next_next_award", next_next_award)
  if last_award < now and now < next_next_award then
    return true
  end
  return false
end

function SWDKP:CancelRecurringEP()
  StaticPopup_Hide("EPGP_RECURRING_RESUME")
  local vars = SWDKP.db.profile
  vars.next_award_reason = nil
  vars.next_award_amount = nil
  vars.next_award = nil
  
  frame:Hide()
end

function SWDKP:StopRecurringEP()
  self:CancelRecurringEP()
  
  callbacks:Fire("StopRecurringAward")
  return true
end

function SWDKP:RunningRecurringEP()
  --print("RunningRecurringEP")
  local vars = SWDKP.db.profile
  return not not vars.next_award
end

function SWDKP:RecurringEPPeriodMinutes(val)
  local vars = SWDKP.db.profile
  if val == nil then
    return vars.recurring_ep_period_mins
  end
  vars.recurring_ep_period_mins = val
end

function SWDKP:RecurringEPPeriodString()
  --print("RecurringEPPeriiodString")
  local vars = SWDKP.db.profile
  local fmt, val = SecondsToTimeAbbrev(vars.recurring_ep_period_mins * 60)
  return fmt:format(val)
end
