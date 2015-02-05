-- Util.lua
-- Carbine Studios, LLC


function FixXMLString(str)
	str = str:gsub("&", "&amp;")	-- must do this first!
	str = str:gsub("<", "&lt;")
	str = str:gsub(">", "&gt;")
	str = str:gsub("'", "&apos;")
	str = str:gsub('"', "&quot;")
	return str
end

--------------------------------------------------------------------------------------------------

function GetUnicodeStringLength(str)
	local _, count = string.gsub(str, "[^\128-\193]", "")
	
	return count
end

--------------------------------------------------------------------------------------------------

function GetPluralizeActor(strSingularPlural, nCount)
	if strSingularPlural and nCount then
		local tActor = 
		{
			["count"] = nCount, 
			["name"] = strSingularPlural
		}
		return tActor
	end
	return {}
end

---------------------------------------------------------------------------------------------------
-- TableUtil:Copy
---------------------------------------------------------------------------------------------------
TableUtil = {}
function TableUtil:Copy(t)
  local t2 = {}
  if type(t) ~= "table" then
    return t
  end
  for k,v in pairs(t) do
    t2[k] = TableUtil:Copy(v)
  end
  return t2
end

---------------------------------------------------------------------------------------------------
-- fifo queue implementation
---------------------------------------------------------------------------------------------------
Queue = {}

function Queue:new(o)
  	o = o or {tItems={}}
	setmetatable(o, self)
	self.__index = self
	o.iFirst = 1
	o.iLast = 0
	return o
end
---------------------------------------------------------------------------------------------------
function Queue:Push( oValue )
    local iNewIndex = self.iLast + 1
	self.iLast = iNewIndex
	self.tItems[iNewIndex] = oValue
	return iNewIndex
end
---------------------------------------------------------------------------------------------------
function Queue:Pop()
	local iNewFront = self.iFirst
	if self:Empty() then
		return
	end
	
	local oValue = self.tItems[iNewFront]
	self.tItems[iNewFront] = nil
	self.iFirst = iNewFront + 1
	
	return oValue
end
---------------------------------------------------------------------------------------------------
function Queue:InsertAbsolute( iPos, item )
	if iPos < self.iFirst or iPos > self.iLast + 1 then
		return 0
	end
    table.insert( self.tItems, iPos, item )
	self.iLast = self.iLast + 1
	return iPos
end
---------------------------------------------------------------------------------------------------
function Queue:RemoveAbsolute( iPos )
	if iPos < self.iFirst or iPos > self.iLast then
		return 0
	end
    table.remove( self.tItems, iPos )
	self.iLast = self.iLast - 1
	return iPos
end
---------------------------------------------------------------------------------------------------
function Queue:Insert( iPos, item )
	return self:InsertAbsolute( self.iFirst + iPos - 1, item )
end
---------------------------------------------------------------------------------------------------
function Queue:Remove( iPos )
    return self:RemoveAbsolute( self.iFirst + iPos - 1, item )
end
---------------------------------------------------------------------------------------------------
function Queue:GetItems()
    return self.tItems
end
---------------------------------------------------------------------------------------------------
function Queue:GetSize()
    return self.iLast - self.iFirst + 1
end
---------------------------------------------------------------------------------------------------
function Queue:Empty()
	return self.iFirst > self.iLast
end
---------------------------------------------------------------------------------------------------
 

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local UtilLib = {}

function UtilLib:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function UtilLib:Init()
	Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- Rover OnLoad
-----------------------------------------------------------------------------------------------
function UtilLib:OnLoad()
end


-----------------------------------------------------------------------------------------------
-- Rover Instance
-----------------------------------------------------------------------------------------------
local UtilLibInst = UtilLib:new()
UtilLibInst:Init()
UtilLibInst = nil



alent.bActive then
					bPicked = true
					strIcon = "ClientSprites:Icon_Windows_UI_CRB_Checkmark"
				elseif string.len(strIcon) == 0 then
					strIcon = "ClientSprites:Icon_ItemMisc_UI_Item_Gears"
				end
				wndTalent:FindChild("TalentItemIcon"):SetSprite(strIcon)

				local strName = Apollo.GetString("Tradeskills_TalentPlaceholder")
				if string.len(tTalent.strName) > 0 then
					strName = tTalent.strName
				end
				wndTalent:FindChild("TalentItemIcon"):SetTooltip(
					string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff9aaea3\">%s</P><P Font=\"CRB_InterfaceSmall_O\">%s</P>", strName, tTalent.strTooltip))
			end
		end

		if bPicked then
			for idx, wndTalent in pairs(wndTier:FindChild("TalentItemContainer"):GetChildren()) do
				wndTalent:FindChild("TalentItemBtn"):Enable(false)
			end
		end
		wndTier:FindChild("TalentItemContainer"):ArrangeChildrenHorz(0)
	end
	wndParent:FindChild("TierItemContainer"):ArrangeChildrenVert(0)

	-- Points available
	local strHeaderText = tCurrInfo.strName
	if tCurrInfo.nTalentPoints > 0 and nNextLevelCost > 0 then
		strHeaderText = String_GetWeaselString(Apollo.GetString("Tradeskills_ToLevel"), tCurrInfo.strName, tCurrInfo.nTalentPoints, nNextLevelCost, nNextLevelTier)
	end
	wndParent:FindChild("HeaderTitle"):SetText(strHeaderText)

	-- Reset Points
	local monRespecCost = CraftingLib.GetTradeskillTalentRespecCost(tCurrTradeskill.eId)
	local eMoneyType = monRespecCost:GetMoneyType()
	local monPlayerCurrencyAmount = GameLib.GetPlayerCurrency(eMoneyType):GetAmount()
	local bCanAffordReset = monRespecCost:GetAmount() <= monPlayerCurrencyAmount
	wndParent:FindChild("ResetPoints"):Show(true)
	wndParent:FindChild("ResetPointsConfirmYes"):SetData(tCurrTradeskill.eId)
	wndParent:FindChild("ResetPointsConfirmNo"):SetData(wndParent:FindChild("ResetPointsConfirmBubble"))
	wndParent:FindChild("ResetPointsConfirmYes"):Enable(bCanAffordReset)
	wndParent:FindChild("ResetPointsCostCashWindow"):SetMoneySystem(eMoneyType)
	wndParent:FindChild("ResetPointsCostCashWindow"):SetAmount(monRespecCost, true)
	wndParent:FindChild("ResetPointsHaveCashWindow"):SetMoneySystem(eMoneyType)
	wndParent:FindChild("ResetPointsHaveCashWindow"):SetAmount(monPlayerCurrencyAmount, true)
	wndParent:FindChild("ResetPointsBtn"):AttachWindow(wndParent:FindChild("ResetPointsConfirmBubble"))
	if bCanAffordReset then
		wndParent:FindChild("ResetPointsCostCashWindow"):SetTextColor(ApolloColor.new("white"))
	else
		wndParent:FindChild("ResetPointsCostCashWindow"):SetTextColor(ApolloColor.new("red"))
	end
end

-----------------------------------------------------------------------------------------------
-- Reset Points
-----------------------------------------------------------------------------------------------

function TradeskillTalents:OnResetPointsConfirmYes(wndHandler, wndControl) -- Parent can be 3 buttons, but data will be tradeskill id
	if wndHandler ~= wndControl or not wndHandler:GetData() then return end
	CraftingLib.ResetTradeskillTalents(wndHandler:GetData())
	Apollo.StartTimer("TradeskillTalents_DelayedRedraw")
end

function TradeskillTalents:OnResetPointsConfirmNo(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:GetData() then
		wndHandler:GetData():Show(false)
	end
end

----------------------------------------------------------