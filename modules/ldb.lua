local mod = SWDKP:NewModule("ldb")

function mod:StopRecurringAward()
  self.ldb.text = "Idle"
  self.ldb.icon = [[Interface\Addons\Something_Wicked_DKP\Images\SW Tabard Red.tga]]
end

function mod:RecurringAwardUpdate(event_type, reason, amount, time_left)
  local fmt, val = SecondsToTimeAbbrev(time_left)
  self.ldb.text = string.format("Next award in " .. fmt, val)
  self.ldb.icon = [[Interface\Addons\Something_Wicked_DKP\Images\SW Tabard Green.tga]]
end

function mod:OnEnable()
  local LDB = LibStub("LibDataBroker-1.1")
  if not LDB then return end
  if self.ldb then return end

  self.ldb = LDB:NewDataObject(
    "SWDKP",
    {
      type = "data source",
      text = "Idle",
      label = "SWDKP",
	  icon = [[Interface\Addons\Something_Wicked_DKP\Images\SW Tabard.tga]],
      OnClick =
        function(self, button)
          if button == "LeftButton" then
            SWDKP:ToggleUI()
          else
            InterfaceOptionsFrame_OpenToCategory("SWDKP")
          end
        end,
      OnTooltipShow =
        function(tooltip)
          tooltip:AddLine("Something Wicked DKP")
          tooltip:AddLine(" ")
          tooltip:AddLine("Left-click to toggle the Something Wicked DKP standings", 0, 1, 0)
          tooltip:AddLine("Right-click to open the Something Wicked DKP config", 0, 1, 0)
          tooltip:AddLine(" ")
          local status = string.format(
            "Decay=%s%% BaseDKP=%s MinDKP=%s Extras=%s%%",
            "|cFFFFFFFF"..SWDKP:GetDecayPercent().."|r",
            "|cFFFFFFFF"..SWDKP:GetBaseGP().."|r",
            "|cFFFFFFFF"..SWDKP:GetMinEP().."|r",
            "|cFFFFFFFF"..SWDKP:GetExtrasPercent().."|r")
          local lines = {strsplit(" ", status)}
          for _, line in pairs(lines) do
            tooltip:AddLine(line)
          end
        end,
    })

  SWDKP.RegisterCallback(mod, "StopRecurringAward")
  SWDKP.RegisterCallback(mod, "RecurringAwardUpdate")
end
