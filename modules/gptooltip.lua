local mod = SWDKP:NewModule("gptooltip", "AceHook-3.0")

local GP = LibStub("LibGearPoints-1.0")

function OnTooltipSetItem(tooltip, ...)
  local itemName, itemlink = tooltip:GetItem()
  
  if itemlink == nil then
	return
  end
  
  local tempName = GetItemInfo(itemlink)
 
  if tempName == nil then
	return
  end
  
  local gp1, gp2, ilvl = GP:GetValue(itemlink)

  if gp1 then
    if gp2 then
      tooltip:AddLine(
        "DKP: " .. gp1 .. " or " .. gp2,
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    else
      tooltip:AddLine(
        "DKP: " .. gp1,
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
  end
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    threshold = 4, -- Epic
  }
}

mod.optionsName = "Tooltip"
mod.optionsDesc = "DKP on tooltips"
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = "Provide the DKP value of armor on tooltips. Quest items or tokens that can be traded for armor will also have the DKP value.",
  },
  threshold = {
    order = 10,
    type = "select",
    name = "Quality threshold",
    desc = "Only display DKP values for items at or above this quality.",
    values = {
      [0] = ITEM_QUALITY0_DESC, -- Poor
      [1] = ITEM_QUALITY1_DESC, -- Common
      [2] = ITEM_QUALITY2_DESC, -- Uncommon
      [3] = ITEM_QUALITY3_DESC, -- Rare
      [4] = ITEM_QUALITY4_DESC, -- Epic
      [5] = ITEM_QUALITY5_DESC, -- Legendary
      [6] = ITEM_QUALITY6_DESC, -- Artifact
    },
    get = function() return GP:GetQualityThreshold() end,
    set = function(info, itemQuality)
      info.handler.db.profile.threshold = itemQuality
      GP:SetQualityThreshold(itemQuality)
    end,
  },
}

function mod:OnEnable()
  GP:SetQualityThreshold(self.db.profile.threshold)

  local obj = EnumerateFrames()
  while obj do
    if obj:IsObjectType("GameTooltip") then
      assert(obj:HasScript("OnTooltipSetItem"))
      self:HookScript(obj, "OnTooltipSetItem", OnTooltipSetItem)
    end
    obj = EnumerateFrames(obj)
  end
end
