--[[
-- This is the core addon. It implements all functions dealing with
-- administering and configuring EPGP. It implements the following
-- functions:
--
-- StandingsSort(order): Sorts the standings list using the specified
-- sort order. Valid values are: NAME, EP, GP, PR. If order is nil it
-- returns the current value.
--
-- StandingsShowEveryone(val): Sets listing everyone or not in the
-- standings when in raid. If val is nil it returns the current
-- value.
--
-- GetNumMembers(): Returns the number of members in the standings.
--
-- GetMember(i): Returns the ith member in the standings based on the
-- current sort.
--
-- GetMain(name): Returns the main character for this member.
--
-- GetNumAlts(name): Returns the number of alts for this member.
--
-- GetAlt(name, i): Returns the ith alt for this member.
--
-- SelectMember(name): Select the member for award. Returns true if
-- the member was added, false otherwise.
--
-- DeSelectMember(name): Deselect member for award. Returns true if
-- the member was added, false otherwise.
--
-- GetNumMembersInAwardList(): Returns the number of members in the
-- award list.
--
-- IsMemberInAwardList(name): Returns true if member is in the award
-- list. When in a raid, this returns true for members in the raid and
-- members selected. When not in raid this returns true for everyone
-- if noone is selected or true if at least one member is selected and
-- the member is selected as well.
--
-- IsMemberInExtrasList(name): Returns true if member is in the award
-- list as an extra. When in a raid, this returns true if the member
-- is not in raid but is selected. When not in raid, this returns
-- false.
--
-- IsAnyMemberInExtrasList(name): Returns true if there is any member
-- in the award list as an extra.
--
-- ResetEPGP(): Resets all EP and GP to 0.
--
-- DecayEPGP(): Decays all EP and GP by the configured decay percent
-- (GetDecayPercent()).
--
-- CanIncEPBy(reason, amount): Return true reason and amount are
-- reasonable values for IncEPBy and the caller can change EPGP.
--
-- IncEPBy(name, reason, amount): Increases the EP of member <name> by
-- <amount>. Returns the member's main character name.
--
-- CanIncGPBy(reason, amount): Return true if reason and amount are
-- reasonable values for IncGPBy and the caller can change EPGP.
--
-- IncGPBy(name, reason, amount): Increases the GP of member <name> by
-- <amount>. Returns the member's main character name.
--
-- IncMassEPBy(reason, amount): Increases the EP of all members
-- in the award list. See description of IsMemberInAwardList.
--
-- RecurringEP(val): Sets recurring EP to true/false. If val is nil it
-- returns the current value.
--
-- RecurringEPPeriodMinutes(val): Sets the recurring EP period in
-- minutes. If val is nil it returns the current value.
--
-- GetDecayPercent(): Returns the decay percent configured in guild info.
--
-- CanDecayEPGP(): Returns true if the caller can decay EPGP.
--
-- GetBaseGP(): Returns the base GP configured in guild info.
--
-- GetMinEP(): Returns the min EP configured in guild info.
--
-- GetEPGP(name): Returns <ep, gp, main> for <name>. <main> will be
-- nil if this is the main toon, otherwise it will be the name of the
-- main toon since this is an alt. If <name> is an invalid name it
-- returns nil.
--
-- GetClass(name): Returns the class of member <name>. It returns nil
-- if the class is unknown.
--
-- ReportErrors(outputFunc): Calls function for each error during
-- initialization, one line at a time.
--
-- The library also fires the following messages, which you can
-- register for through RegisterCallback and unregister through
-- UnregisterCallback. You can also unregister all messages through
-- UnregisterAllCallbacks.
--
-- StandingsChanged: Fired when the standings have changed.
--
-- EPAward(name, reason, amount, mass): Fired when an EP award is
-- made.  mass is set to true if this is a mass award or decay.
--
-- MassEPAward(names, reason, amount,
--             extras_names, extras_reason, extras_amount): Fired
-- when a mass EP award is made.
--
-- GPAward(name, reason, amount, mass): Fired when a GP award is
-- made. mass is set to true if this is a mass award or decay.
--
-- BankedItem(name, reason, amount, mass): Fired when an item is
-- disenchanted or deposited directly to the Guild Bank. Name is
-- always the content of GUILD_BANK, amount is 0 and mass always nil.
--
-- StartRecurringAward(reason, amount, mins): Fired when recurring
-- awards are started.
--
-- StopRecurringAward(): Fired when recurring awards are stopped.
--
-- RecurringAwardUpdate(reason, amount, remainingSecs): Fired
-- periodically between awards with the remaining seconds to award in
-- seconds.
--
-- EPGPReset(): Fired when EPGP are reset.
--
-- Decay(percent): Fired when a decay happens.
--
-- DecayPercentChanged(v): Fired when decay percent changes. v is the
-- new value.
--
-- BaseGPChanged(v): Fired when base gp changes. v is the new value.
--
-- MinEPChanged(v): Fired when min ep changes. v is the new value.
--
-- ExtrasPercentChanged(v): Fired when extras percent changes.  v is
-- the new value.
--
--]]

local Debug = LibStub("LibDebug-1.0")
Debug:EnableDebugging()
local GS = LibStub("LibGuildStorage-1.2")

SWDKP = LibStub("AceAddon-3.0"):NewAddon("SWDKP", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
SWDKP:SetDefaultModuleState(false)
local modulePrototype = {
  IsDisabled = function (self, i) return not self:IsEnabled() end,
  IsEnabled2 = function (self, i) return self:IsEnabled() end,
  SetEnabled = function (self, i, v)
                 if v then
                   Debug("Enabling module: %s", self:GetName())
                   self:Enable()
                 else
                   Debug("Disabling module: %s", self:GetName())
                   self:Disable()
                 end
                 self.db.profile.enabled = v
               end,
  GetDBVar = function (self, i) return self.db.profile[i[#i]] end,
  SetDBVar = function (self, i, v) self.db.profile[i[#i]] = v end,
}
SWDKP:SetDefaultModulePrototype(modulePrototype)

local version = SWLootMaster:GetVersionString() or GetAddOnMetadata('Something_Wicked_DKP', 'Version')--Try to pull better version from loaded SWLootMaster first, if it's not loaded, pull version from toc file (which own't be accurate after an upgrade/reload)

SWDKP.version = version

local CallbackHandler = LibStub("CallbackHandler-1.0")
if not SWDKP.callbacks then
  SWDKP.callbacks = CallbackHandler:New(SWDKP)
end
local callbacks = SWDKP.callbacks

local ep_data = {}
local gp_data = {}
local main_data = {}
local alt_data = {}
local ignored = {}
local standings = {}
local selected = {}
selected._count = 0  -- This is safe since _ is not allowed in names

-- This is a bit of a mess; cross-realm groups will probably break
-- this.  In 5.4.2, guild roster functions began returning
-- PlayerName-Server in all cases, but raid functions don't stick the
-- -Server portion on unless the player is from another realm.  This
-- probably will fix things well enough for now.
function SWDKP:UnitInRaid(name)
	name = Ambiguate(name, "none")
	return UnitInRaid(name)
end

local function DecodeNote(note)
  if note then
    if note == "" then
      return 0, 0
    else
      local ep, gp = string.match(note, "^(%d+%.?%d*),(%d+%.?%d*)$")
      if ep then
        return tonumber(ep), tonumber(gp)
      end
    end
  end
end

local function EncodeNote(ep, gp)
  return string.format("%.2f,%.2f",
                       math.max(ep, 0),
                       math.max(gp - SWDKP.db.profile.base_gp, 0))
end

local function AddEPGP(name, ep, gp, dodebug)
  if dodebug then
    SWDKP:Print("Debug: AddEPGP fired for: "..name)
  end
  local total_ep = ep_data[name]
  local total_gp = gp_data[name]
  assert(total_ep ~= nil and total_gp ~=nil,
         string.format("%s is not a main!", tostring(name)))

  -- Compute the actual amounts we can add/subtract.
  if (total_ep + ep) < 0 then
    ep = -total_ep
  end
  if (total_gp + gp) < 0 then
    gp = -total_gp
  end
  GS:SetNote(name, EncodeNote(total_ep + ep,
                              total_gp + gp + SWDKP.db.profile.base_gp))
  return ep, gp
end

-- A wrapper function to handle sort logic for selected
local function ComparatorWrapper(f)
  return function(a, b)
           local a_in_raid = not not SWDKP:UnitInRaid(a)
           local b_in_raid = not not SWDKP:UnitInRaid(b)
           if a_in_raid ~= b_in_raid then
             return not b_in_raid
           end

           local a_selected = selected[a]
           local b_selected = selected[b]

           if a_selected ~= b_selected then
             return not b_selected
           end

           return f(a, b)
         end
end

local comparators = {
  NAME = function(a, b)
           return a < b
         end,
  EP = function(a, b)
         local a_ep, a_gp = SWDKP:GetEPGP(a)
         local b_ep, b_gp = SWDKP:GetEPGP(b)

         return a_ep > b_ep
       end,
  GP = function(a, b)
         local a_ep, a_gp = SWDKP:GetEPGP(a)
         local b_ep, b_gp = SWDKP:GetEPGP(b)

         return a_gp > b_gp
       end,
  PR = function(a, b)
         local a_ep, a_gp = SWDKP:GetEPGP(a)
         local b_ep, b_gp = SWDKP:GetEPGP(b)
		 
         --local a_qualifies = a_ep >= SWDKP.db.profile.min_ep
         --local b_qualifies = b_ep >= SWDKP.db.profile.min_ep
		 local a_qualifies = false
		 local b_qualifies = false
		 
		-- print(a_qualifies, b_qualifies)

         if (a_qualifies == b_qualifies and a_ep ~= 0 and b_ep ~= 0) then
           return ((a_gp + 1) / a_ep) * 100 < ((b_gp + 1) / b_ep) * 100
         else
           return a_qualifies
         end
       end,
}
for k,f in pairs(comparators) do
  comparators[k] = ComparatorWrapper(f)
end

local function DestroyStandings()
  wipe(standings)
  callbacks:Fire("StandingsChanged")
end

local function RefreshStandings(order, showEveryone)
  Debug("Resorting standings")
  if SWDKP:UnitInRaid("player") then
    -- If we are in raid:
    ---  showEveryone = true: show all in raid (including alts) and
    ---  all leftover mains
    ---  showEveryone = false: show all in raid (including alts) and
    ---  all selected members
    for n in pairs(ep_data) do
      if showEveryone or SWDKP:UnitInRaid(n) or selected[n] then
        table.insert(standings, n)
      end
    end
    for n in pairs(main_data) do
      if SWDKP:UnitInRaid(n) or selected[n] then
        table.insert(standings, n)
      end
    end
  else
    -- If we are not in raid, show all mains
    for n in pairs(ep_data) do
      table.insert(standings, n)
    end
  end

  -- Sort
  table.sort(standings, comparators[order])
end

local function DeleteState(name)
  ignored[name] = nil
  -- If this is was an alt we need to fix the alts state
  local main = main_data[name]
  if main then
    if alt_data[main] then
      for i,alt in ipairs(alt_data[main]) do
        if alt == name then
          table.remove(alt_data[main], i)
          break
        end
      end
    end
    main_data[name] = nil
  end
  -- Delete any existing cached values
  ep_data[name] = nil
  gp_data[name] = nil
end

local function HandleDeletedGuildNote(callback, name)
  DeleteState(name)
  DestroyStandings()
end

local function ParseGuildNote(callback, name, note)
  Debug("Parsing Guild Note for %s [%s]", name, note)
  -- Delete current state about this toon.
  DeleteState(name)

  local ep, gp = DecodeNote(note)
  if ep then
    ep_data[name] = ep
    gp_data[name] = gp
  else
    local main_ep = DecodeNote(GS:GetNote(note))
    if not main_ep then
      -- This member does not point to a valid main, ignore it.
      ignored[name] = note
    else
      -- Otherwise setup the alts state
      main_data[name] = note
      if not alt_data[note] then
        alt_data[note] = {}
      end
      table.insert(alt_data[note], name)
      ep_data[name] = nil
      gp_data[name] = nil
    end
  end
  DestroyStandings()
end

function SWDKP:ExportRoster()
  local base_gp = SWDKP.db.profile.base_gp
  local t = {}
  for name,_ in pairs(ep_data) do
    local ep, gp, main = self:GetEPGP(name)
    if ep ~= 0 or gp ~= base_gp then
      table.insert(t, {name, ep, gp})
    end
  end
  return t
end

function SWDKP:ImportRoster(t, new_base_gp)
  -- This ugly hack is because EncodeNote reads base_gp to encode the
  -- GP properly. So we reset it to what we get passed, and then we
  -- restore it so that the BaseGPChanged event is fired properly when
  -- we parse the guild info text after this function returns.
  local old_base_gp = SWDKP.db.profile.base_gp
  SWDKP.db.profile.base_gp = new_base_gp

  local notes = {}
  for _, entry in pairs(t) do
    local name, ep, gp = unpack(entry)
    notes[name] = EncodeNote(ep, gp)
  end

  local zero_note = EncodeNote(0, 0)
  for name,_ in pairs(ep_data) do
    local note = notes[name] or zero_note
    GS:SetNote(name, note)
  end

  SWDKP.db.profile.base_gp = old_base_gp
end

function SWDKP:StandingsSort(order)
  if not order then
    return self.db.profile.sort_order
  end

  assert(comparators[order], "Unknown sort order")

  self.db.profile.sort_order = order
  DestroyStandings()
end

function SWDKP:StandingsShowEveryone(val)
  if val == nil then
    return self.db.profile.show_everyone
  end

  self.db.profile.show_everyone = not not val
  DestroyStandings()
end

function SWDKP:GetNumMembers()
  if #standings == 0 then
    RefreshStandings(self.db.profile.sort_order, self.db.profile.show_everyone)
  end

  return #standings
end

function SWDKP:GetMember(i)
  if #standings == 0 then
    RefreshStandings(self.db.profile.sort_order, self.db.profile.show_everyone)
  end

  return standings[i]
end

function SWDKP:GetNumAlts(name)
  local alts = alt_data[name]
  if not alts then
    return 0
  else
    return #alts
  end
end

function SWDKP:GetAlt(name, i)
  return alt_data[name][i]
end

function SWDKP:SelectMember(name)
  if SWDKP:UnitInRaid("player") then
    -- Only allow selecting members that are not in raid when in raid.
    if SWDKP:UnitInRaid(name) then
      return false
    end
  end
  selected[name] = true
  selected._count = selected._count + 1
  SWDKP.db.profile.standbybackup[selected._count] = name
  DestroyStandings()
  return true
end

function SWDKP:DeSelectMember(name)
  if SWDKP:UnitInRaid("player") then
    -- Only allow deselecting members that are not in raid when in raid.
    if SWDKP:UnitInRaid(name) then
      return false
    end
  end
  if not selected[name] then
    return false
  end
  selected[name] = nil
  selected._count = selected._count - 1
  for i = 1, #SWDKP.db.profile.standbybackup, 1 do
	if SWDKP.db.profile.standbybackup[i] == name then
		table.remove(SWDKP.db.profile.standbybackup, i)
	end
  end
  DestroyStandings()
  return true
end

function SWDKP:GetNumMembersInAwardList()
  if SWDKP:UnitInRaid("player") then
    return GetNumGroupMembers() + selected._count
  else
    if selected._count == 0 then
      return self:GetNumMembers()
    else
      return selected._count
    end
  end
end

function SWDKP:IsMemberInAwardList(name)
  if SWDKP:UnitInRaid("player") then
    -- If we are in raid the member is in the award list if it is in
    -- the raid or the selected list.
    return SWDKP:UnitInRaid(name) or selected[name]
  else
    -- If we are not in raid and there is noone selected everyone will
    -- get an award.
    if selected._count == 0 then
      return true
    end
    return selected[name]
  end
end

function SWDKP:IsMemberInExtrasList(name)
  return SWDKP:UnitInRaid("player") and selected[name]
end

function SWDKP:IsAnyMemberInExtrasList()
  return selected._count ~= 0
end

function SWDKP:CanResetEPGP()
  return CanEditOfficerNote() and GS:IsCurrentState()
end

function SWDKP:ResetEPGP()
  assert(SWDKP:CanResetEPGP())

  local zero_note = EncodeNote(0, 0)
  for name,_ in pairs(ep_data) do
    GS:SetNote(name, zero_note)
    local ep, gp, main = self:GetEPGP(name)
    assert(main == nil, "Corrupt alt data!")
    if ep > 0 then
      callbacks:Fire("EPAward", name, "Reset", -ep, true)
    end
    if gp > 0 then
      callbacks:Fire("GPAward", name, "Reset", -gp, true)
    end
  end
  callbacks:Fire("EPGPReset")
end

function SWDKP:CanDecayEPGP()
  if not CanEditOfficerNote() or SWDKP.db.profile.decay_p == 0 or not GS:IsCurrentState() then
    return false
  end
  return true
end

function SWDKP:DecayEPGP()
  assert(SWDKP:CanDecayEPGP())

  local decay = SWDKP.db.profile.decay_p  * 0.01
  local reason = string.format("Decay %d%%", SWDKP.db.profile.decay_p)
  for name,_ in pairs(ep_data) do
    local ep, gp, main = self:GetEPGP(name)
    assert(main == nil, "Corrupt alt data!")
    local decay_ep = ep * decay
    local decay_gp = gp * decay
	decay_ep = string.format("%.3g", decay_ep)
	decay_gp = string.format("%.3g", decay_gp)
    decay_ep, decay_gp = AddEPGP(name, -decay_ep, -decay_gp)
    if decay_ep ~= 0 then
      callbacks:Fire("EPAward", name, reason, decay_ep, true)
    end
    if decay_gp ~= 0 then
      callbacks:Fire("GPAward", name, reason, decay_gp, true)
    end
  end
  callbacks:Fire("Decay", SWDKP.db.profile.decay_p)
end

function SWDKP:GetEPGP(name, dodebug)
	--Maybe needs fixing here too?
	--name = Ambiguate(name, "none")
  local main = main_data[name]
  if main then
    name = main
  end
  if ep_data[name] then
  	if dodebug then
  	 self:Print("Debug: GetEPGP fired for "..name.." and returning their EP @"..ep_data[name])
  	end
    return ep_data[name], gp_data[name] + SWDKP.db.profile.base_gp, main
  end
end

function SWDKP:GetClass(name)
  return GS:GetClass(name)
end

function SWDKP:CanIncEPBy(reason, amount)
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    return false
  end
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount ~= math.floor(amount + 0.5) then
    return false
  end
  if amount < -99999 or amount > 99999 then
    return false
  end
  return true
end

function SWDKP:IncEPBy(name, reason, amount, mass, undo)
  -- When we do mass EP or decay we know what we are doing even though
  -- CanIncEPBy returns false
  assert(SWDKP:CanIncEPBy(reason, amount) or mass or undo)
  assert(type(name) == "string")

  local ep, gp, main
  if reason == "Bonus Coin Used" then
	ep, gp, main = self:GetEPGP(name, true)--Debug
  else
	ep, gp, main = self:GetEPGP(name)--No Debug
  end
  if not ep then--It's either failing here, because GetEPGP is failing
    self:Print(("Ignoring DKP change for unknown member %s"):format(name))
    return
  end
  if reason == "Bonus Coin Used" then
  	amount = AddEPGP(main or name, amount, 0, true)--Debug
  else
  	amount = AddEPGP(main or name, amount, 0)--No Debug
  end
  if amount then--Or it is failing here, because AddEPGP is failing
    callbacks:Fire("EPAward", name, reason, amount, mass, undo)
--    self:Print("Debug: "..name.." "..reason.." "..amount.." sent to EPAward")
  else
	self:Print("Coin failed because EP amount was nil for "..name)
  end
  self.db.profile.last_awards[reason] = amount
  return main or name
end

function SWDKP:CanIncGPBy(reason, amount)
  if not CanEditOfficerNote() or not GS:IsCurrentState() then
    --return false
  end
  if type(reason) ~= "string" or type(amount) ~= "number" or #reason == 0 then
    return false
  end
  if amount ~= math.floor(amount + 0.5) then
    --return false
  end
  if amount < -99999 or amount > 99999 then
    return false
  end
  return true
end

function SWDKP:IncGPBy(name, reason, amount, mass, undo)
  -- When we do mass GP or decay we know what we are doing even though
  -- CanIncGPBy returns false
  assert(SWDKP:CanIncGPBy(reason, amount) or mass or undo)
  assert(type(name) == "string")

  local blank = nil
  local ep, gp, main = self:GetEPGP(name)
  if not ep then
    self:Print(("Ignoring DKP change for unknown member %s"):format(name))
    return
  end
  blank, amount = AddEPGP(main or name, 0, amount)
  if amount then
    callbacks:Fire("GPAward", name, reason, amount, mass, undo)
  else
    callbacks:Fire("GPAward", name, reason, 0, mass, undo)
  end

  return main or name
end

function SWDKP:BankItem(reason, undo)
  callbacks:Fire("BankedItem", GUILD_BANK, reason, 0, false, undo)
end

function SWDKP:GetDecayPercent()
  return SWDKP.db.profile.decay_p
end

function SWDKP:GetExtrasPercent()
  return SWDKP.db.profile.extras_p
end

function SWDKP:GetBaseGP()
  return SWDKP.db.profile.base_gp
end

function SWDKP:GetMinEP()
  return SWDKP.db.profile.min_ep
end

function SWDKP:SetGlobalConfiguration(decay_p, extras_p, base_gp, min_ep)
  local guild_info = GS:GetGuildInfo()
  epgp_stanza = string.format(
    "-SWDKP-\n@DECAY_P:%d\n@EXTRAS_P:%s\n@MIN_EP:%d\n@BASE_GP:%d\n-SWDKP-",
    decay_p or DEFAULT_DECAY_P,
    extras_p or DEFAULT_EXTRAS_P,
    min_ep or DEFAULT_MIN_EP,
    base_gp or DEFAULT_BASE_GP)

  -- If we have a global configuration stanza we need to replace it
  Debug("epgp_stanza:\n%s", epgp_stanza)
  if guild_info:match("%-SWDKP%-.*%-SWDKP%-") then
    guild_info = guild_info:gsub("%-SWDKP%-.*%-SWDKP%-", epgp_stanza)
  else
    guild_info = epgp_stanza.."\n"..guild_info
  end
  Debug("guild_info:\n%s", guild_info)
  SetGuildInfoText(guild_info)
  GuildRoster()
end

function SWDKP:GetMain(name)
  return main_data[name] or name
end

function SWDKP:IncMassEPBy(reason, amount)
  local awarded = {}
  local extras_awarded = {}
  local extras_amount = math.floor(SWDKP.db.profile.extras_p * 0.01 * amount)
  local extras_reason = reason .. " - " .. "Standby"

  for i=1,SWDKP:GetNumMembers() do
    local name = SWDKP:GetMember(i)
    if SWDKP:IsMemberInAwardList(name) then
      -- EPGP:GetMain() will return the input name if it doesn't find a main,
      -- so we can't use it to validate that this actually is a character who
      -- can recieve EP.
      --
      -- EPGP:GetEPGP() returns nil for ep and gp, if it can't find a
      -- valid member based on the name however.
      local ep, gp, main = SWDKP:GetEPGP(name)
      local main = main or name
      if ep and not awarded[main] and not extras_awarded[main] then
        if SWDKP:IsMemberInExtrasList(name) then
          SWDKP:IncEPBy(name, extras_reason, extras_amount, true)
          extras_awarded[name] = true
        else
          SWDKP:IncEPBy(name, reason, amount, true)
          awarded[name] = true
        end
      end
    end
  end
  if next(awarded) then
    if next(extras_awarded) then
      callbacks:Fire("MassEPAward", awarded, reason, amount,
                     extras_awarded, extras_reason, extras_amount)
    else
      callbacks:Fire("MassEPAward", awarded, reason, amount)
    end
  end
end

function SWDKP:IncMassCoinEPBy(names, reason, amount)
	local awarded = {}
	for i = 1, #names do
		local name = names[i]
		if name then
			local ep, gp, main = SWDKP:GetEPGP(name)
			main = main or name
			if ep and not awarded[main] then
				SWDKP:IncEPBy(name, reason, amount, true)
				awarded[name] = true
			end
		end
	end
	if next(awarded) then
		callbacks:Fire("MassCoinAward", awarded, reason, amount)
	end
end

function SWDKP:ReportErrors(outputFunc)
  for name, note in pairs(ignored) do
    outputFunc(("Invalid officer note [%s] for %s (ignored)"):format(
                 note, name))
  end
end

local db
function SWDKP:LoadTheModules()
	--print("Loading modules")
	--store original function
	local original_ToggleGuildFrame = ToggleGuildFrame;
	
	--asign new function
	ToggleGuildFrame = function(...)
	--new function


	--Object has not yet been created, so just set need to disable showing offline
	SHOWOFFLINE = false;
	SetGuildRosterShowOffline(false)


	--Open the guild frame
	original_ToggleGuildFrame()


	--Guild frame hide handler
	GuildFrame:SetScript("OnHide",function() 
		PlaySoundFile("Sound\\interface\\uCharacterSheetClose.wav")
		SHOWOFFLINE = true 
	end )


	--Guild frame show handler
	GuildFrame:SetScript("OnShow",function() 
		SHOWOFFLINE = false;
		SetGuildRosterShowOffline(false)
		if GuildRosterShowOfflineButton then
			GuildRosterShowOfflineButton:SetChecked(false)
			GuildRosterShowOfflineButton:Enable()
		end
		PlaySoundFile("Sound\\interface\\uCharacterSheetOpen.wav")
	end )


	--restore ToggleGuildFrame function
	ToggleGuildFrame = original_ToggleGuildFrame
	end


  -- Setup the DB. The DB will NOT be ready until after OnEnable is
  -- called on EPGP. We do not call OnEnable on modules until after
  -- the DB is ready to use.
  
  
  local defaults = {
    profile = {
      last_awards = {},
      show_everyone = true,
      sort_order = "PR",
      recurring_ep_period_mins = 60,
      decay_p = 0,
      extras_p = 100,
      min_ep = 0,
      base_gp = 1,
	  standbybackup = {},
	  raidsizecheck = true,
	  raidsize = 2,
	  guildrepair = false,
	  guildRepairToggle = false,
	  GuildRepairTimer = nil,
    }
  }
  
  db = LibStub("AceDB-3.0"):New("SWDKP_DB", defaults, "Default")
  self.db = db
  
  for name, module in self:IterateModules() do
    -- Each module gets its own namespace. If a module needs to set
    -- defaults, module.dbDefaults needs to be a table with
    -- defaults. Otherwise we initialize it to be enabled by default.
    if not module.dbDefaults then
        module.dbDefaults = {
          profile = {
            enabled = true
          }
        }
    end
    module.db = db:RegisterNamespace(name, module.dbDefaults)
  end
  -- After the database objects are created, we setup the
  -- options. Each module can inject its own options by defining:
  --
  -- * module.optionsName: The name of the options group for this module
  -- * module.optionsDesc: The description for this options group [short]
  -- * module.optionsArgs: The definition of this option group
  --
  -- In addition to the above EPGP will add an Enable checkbox for
  -- this module. It is also guaranteed that the name of the node this
  -- group will be in, is the same as the name of the module. This
  -- means you can get the name of the module from the info table
  -- passed to the callback functions by doing info[#info-1].
  --
  self:SetupOptions()

  SWDKP:GUILD_ROSTER_UPDATE()
  if SWDKP:UnitInRaid("player") then
	SWDKP:GROUP_ROSTER_UPDATE()
  end
end

function SWDKP:OnInitialize()
	self:RegisterEvent("PLAYER_LOGIN")
	self:ScheduleTimer("LoadTheModules", 1)
end

function SWDKP:GROUP_ROSTER_UPDATE()
  --print("GROUP_ROSTER_UPDATE")
  if db == nil then
    return
  end
  if SWDKP:UnitInRaid("player") then
    -- If we are in a raid, make sure no member of the raid is
    -- selected
    for name,_ in pairs(selected) do
      if SWDKP:UnitInRaid(name) then
        selected[name] = nil
        selected._count = selected._count - 1
		for i = 1, #SWDKP.db.profile.standbybackup, 1 do
			if SWDKP.db.profile.standbybackup[i] == name then
				table.remove(SWDKP.db.profile.standbybackup, i)
			end
		end
      end
    end
	if not SWDKP.db then
		SWDKP:GUILD_ROSTER_UPDATE()
	end
  else
    -- If we are not in a raid, this means we just left so remove
    -- everyone from the selected list.
    wipe(selected)
	SWDKP.db.profile.standbybackup = {}
    selected._count = 0
    -- We also need to stop any recurring EP since they should stop
    -- once a raid stops.
    if self:RunningRecurringEP() then
	  --print("STOPPING RECURRING EP")
      self:StopRecurringEP()
    end
  end
  DestroyStandings()
end

function SWDKP:GUILD_ROSTER_UPDATE()
  if db == nil then
    return
  end
  if IsInGuild() then
    local guild = GetGuildInfo("player") or ""
    if #guild == 0 then
      GuildRoster()
    else
      if db:GetCurrentProfile() ~= guild then
        Debug("Setting DB profile to: %s", guild)
        db:SetProfile(guild)
      end
      -- This means we didn't initialize the db yet.
      if not SWDKP.db then --I'M NOT SURE THE CODE CAN EVEN GET INTO THIS IF STATEMENT ANYMORE
        SWDKP.db = db
	  
        -- Enable all modules that are supposed to be enabled
        for name, module in SWDKP:IterateModules() do
          if module.db.profile.enabled or not module.dbDefaults then
            Debug("Enabling module (startup): %s", name)
            module:Enable()
          end
        end
		
		--If there are people listed in the backup of the standby list, re-select them if we're in a raid
		if SWDKP:UnitInRaid("player") and #SWDKP.db.profile.standbybackup > 0 then
			for i = 1, #SWDKP.db.profile.standbybackup, 1 do
				SWDKP:SelectMember(SWDKP.db.profile.standbybackup[i])
			end
			selected._count = #SWDKP.db.profile.standbybackup
		end
		--[[
        -- Check if we have a recurring award we can resume
		MOVED TO PLAYER_LOGIN()
        if SWDKP:CanResumeRecurringEP() then
          SWDKP:ResumeRecurringEP()
        else
          SWDKP:CancelRecurringEP()
        end
		--]]
	  end
    end
  end
end

function SWDKP:PLAYER_LOGIN()
	--print("Player login detected")
	SWDKP.recurringTimer = self:ScheduleRepeatingTimer("CheckRecurringTimer", 1)
end

function SWDKP:CheckRecurringTimer()
	if not SWDKP.db then
		--print("SWDKP: Database not yet loaded!")
		return
	else
		self:CancelTimer(SWDKP.recurringTimer)
		--print("SWDKP: Database loaded.  Checking for active DKP timer values...")
	end
	if SWDKP:CanResumeRecurringEP() then
	  --If there are people listed in the backup of the standby list, re-select them if we're in a raid
		if SWDKP:UnitInRaid("player") and #SWDKP.db.profile.standbybackup > 0 then
			for i = 1, #SWDKP.db.profile.standbybackup, 1 do
				SWDKP:SelectMember(SWDKP.db.profile.standbybackup[i])
			end
			selected._count = #SWDKP.db.profile.standbybackup
		end
		--print("SWDKP: DKP timer values found, able to resume recurring DKP awards.")
		SWDKP:ResumeRecurringEP()
	else
	  --print("SWDKP: No timer data found.  Unable to resume recurring DKP (if a timer was active).")
	  SWDKP:CancelRecurringEP()
	end
end

function SWDKP:PARTY_CONVERTED_TO_RAID()
	if not SWDKP.db then
		SWDKP:GUILD_ROSTER_UPDATE()
	end
	if UnitIsGroupLeader("player") and SWDKP.db.profile.raidsizecheck then
		if SWDKP.db.profile.raidsize == 1 then
			SetRaidDifficulty(1)
		elseif SWDKP.db.profile.raidsize == 2 then
			SetRaidDifficulty(2)
		elseif SWDKP.db.profile.raidsize == 3 then
			SetRaidDifficulty(3)
		elseif SWDKP.db.profile.raidsize == 4 then
			SetRaidDifficulty(4)
		else
			print("SWDKP Error: Cannot determine selection for automatic raid difficulty switching!")
		end
	end
end

function SWDKP:OnEnable()
  GS.RegisterCallback(self, "GuildNoteChanged", ParseGuildNote)
  GS.RegisterCallback(self, "GuildNoteDeleted", HandleDeletedGuildNote)

  SWDKP.RegisterCallback(self, "BaseGPChanged", DestroyStandings)

  self:RegisterEvent("GROUP_ROSTER_UPDATE")
  self:RegisterEvent("GUILD_ROSTER_UPDATE")
  self:RegisterEvent("PARTY_CONVERTED_TO_RAID")
  
  GuildRoster()
end