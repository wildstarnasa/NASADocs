-----------------------------------------------------------------------------------------------
-- Client Lua Script for HousingAlerts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChatSystemLib"
require "HousingLib"
require "ChatChannelLib"

local HousingAlerts = {}

local ktHousingSimpleResultStrings =
{
	[HousingLib.HousingResult_Decor_PrereqNotMet] 		= Apollo.GetString("HousingDecorate_NeedPrereq"),
	[HousingLib.HousingResult_Decor_CannotCreateDecor] 	= Apollo.GetString("HousingDecorate_FailedToCreate"),
	[HousingLib.HousingResult_Decor_CannotModifyDecor] 	= Apollo.GetString("HousingDecorate_FailedToModify"),
	[HousingLib.HousingResult_Decor_CannotDeleteDecor] 	= Apollo.GetString("HousingDecorate_FailedToDestroy"),
	[HousingLib.HousingResult_Decor_InvalidDecor] 		= Apollo.GetString("HousingDecorate_InvalidDecor"),
	[HousingLib.HousingResult_Decor_InvalidPosition] 	= Apollo.GetString("HousingDecorate_InvalidPosition"),
	[HousingLib.HousingResult_Decor_CannotAfford]		= Apollo.GetString("HousingDecorate_NotEnoughResources"),
	[HousingLib.HousingResult_Decor_ExceedsDecorLimit] 	= Apollo.GetString("HousingDecorate_LimitReached"),
	[HousingLib.HousingResult_Decor_CouldNotValidate] 	= Apollo.GetString("HousingDecorate_ActionFailed"),
	[HousingLib.HousingResult_Decor_MustBeUnique] 		= Apollo.GetString("HousingDecorate_UniqueDecor"),
	[HousingLib.HousingResult_Decor_CannotOwnMore] 		= Apollo.GetString("HousingDecorate_CannotOwnMore"),

    [HousingLib.HousingResult_InvalidPermissions]		= Apollo.GetString("HousingLandscape_NoPermissions"),
    [HousingLib.HousingResult_InvalidResidence]			= Apollo.GetString("HousingLandscape_UnknownResidence"),
    [HousingLib.HousingResult_Failed]					= Apollo.GetString("HousingLandscape_ActionFailed"),
	[HousingLib.HousingResult_Plug_PrereqNotMet] 		= Apollo.GetString("HousingLandscape_PrereqNotMet"),
	[HousingLib.HousingResult_Plug_InvalidPlug] 		= Apollo.GetString("HousingLandscape_InvalidPlug"),
    [HousingLib.HousingResult_Plug_CannotAfford]		= Apollo.GetString("HousingLandscape_NeedMoreResources"),
    [HousingLib.HousingResult_Plug_ModifyFailed]		= Apollo.GetString("HousingLandscape_ModifyFail"),
    [HousingLib.HousingResult_Plug_MustBeUnique]		= Apollo.GetString("HousingLandscape_UniqueFail"),
    [HousingLib.HousingResult_Plug_NotActive]			= Apollo.GetString("HousingLandscape_NotActive"),
    [HousingLib.HousingResult_Plug_CannotRotate]		= Apollo.GetString("HousingLandscape_ActionFailed"),
    [HousingLib.HousingResult_InvalidResidenceName] 	= Apollo.GetString("HousingLandscape_ActionFailed"), 		   
	[HousingLib.HousingResult_MustHaveResidenceName] 	= Apollo.GetString("Housing_MustHaveResidenceName"), 

	[HousingLib.HousingResult_Neighbor_NoPendingInvite] 	= Apollo.GetString("Neighbors_NoPendingInvites"),
	[HousingLib.HousingResult_Neighbor_RequestAccepted] 	= Apollo.GetString("Neighbors_RequestAcceptedSelf"),
	[HousingLib.HousingResult_Neighbor_RequestDeclined] 	= Apollo.GetString("Neighbors_RequestDeclinedSelf"),
	[HousingLib.HousingResult_Neighbor_PlayerNotAHomeowner]	= Apollo.GetString("Neighbors_NotAHomeownerSelf"), 	
	[HousingLib.HousingResult_Neighbor_InvalidNeighbor] 	= Apollo.GetString("Neighbors_InvalidPlayer"), 		
	[HousingLib.HousingResult_Neighbor_Full] 				= Apollo.GetString("Neighbors_YourNeighborListFull"),
	[HousingLib.HousingResult_Neighbor_PlayerIsIgnored] 	= Apollo.GetString("Neighbors_PlayerIsIgnored"), 		   
	[HousingLib.HousingResult_Neighbor_IgnoredByPlayer] 	= Apollo.GetString("Neighbors_IgnoredByPlayer"),
}
 
local ktHousingComplexResultStringIds =
{
	[HousingLib.HousingResult_Neighbor_Success] 			= Apollo.GetString("Neighbors_SuccessMsg"),
	[HousingLib.HousingResult_Neighbor_RequestTimedOut] 	= Apollo.GetString("Neighbors_RequestTimedOut"), 	
	[HousingLib.HousingResult_Neighbor_RequestAccepted] 	= Apollo.GetString("Neighbors_RequestAccepted"),
	[HousingLib.HousingResult_Neighbor_RequestDeclined] 	= Apollo.GetString("Neighbors_RequestDeclined"), 	
	[HousingLib.HousingResult_Neighbor_PlayerNotFound] 		= Apollo.GetString("Neighbors_PlayerNotFound"), 	
	[HousingLib.HousingResult_Neighbor_PlayerNotOnline] 	= Apollo.GetString("Neighbors_PlayerNotOnline"), 	
	[HousingLib.HousingResult_Neighbor_PlayerNotAHomeowner] = Apollo.GetString("Neighbors_NotAHomeowner"), 	
	[HousingLib.HousingResult_Neighbor_PlayerDoesntExist] 	= Apollo.GetString("Neighbors_PlayerDoesntExist"), 
	[HousingLib.HousingResult_Neighbor_InvalidNeighbor] 	= Apollo.GetString("Neighbors_InvalidNeighbor"), 	
	[HousingLib.HousingResult_Neighbor_AlreadyNeighbors] 	= Apollo.GetString("Neighbors_AlreadyNeighbors"),  
	[HousingLib.HousingResult_Neighbor_InvitePending] 		= Apollo.GetString("Neighbors_InvitePending"), 	
	[HousingLib.HousingResult_Neighbor_PlayerWrongFaction] 	= Apollo.GetString("Neighbors_DifferentFaction"), 
	[HousingLib.HousingResult_Neighbor_Full] 				= Apollo.GetString("Neighbors_NeighborListFull"), 
	[HousingLib.HousingResult_Neighbor_PlayerIsIgnored] 	= Apollo.GetString("Neighbors_PlayerIsIgnored"), 	
	[HousingLib.HousingResult_Neighbor_IgnoredByPlayer] 	= Apollo.GetString("Neighbors_IgnoredByPlayer"), 	
	[HousingLib.HousingResult_Visit_Private] 				= Apollo.GetString("Neighbors_PrivateResidence"), 
	[HousingLib.HousingResult_Visit_Ignored] 				= Apollo.GetString("Neighbors_IgnoredByHost"), 	
	[HousingLib.HousingResult_Visit_InvalidWorld] 			= Apollo.GetString("Neighbors_InvalidWorld"), 	
	[HousingLib.HousingResult_Visit_Failed] 				= Apollo.GetString("Neighbors_VisitFailed"), 		
}

function HousingAlerts:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function HousingAlerts:Init()
    Apollo.RegisterAddon(self)
end

function HousingAlerts:OnLoad()
	self.tIntercept = {}
	Apollo.RegisterEventHandler("HousingResult", "OnHousingResult", self) -- game client initiated events
	Apollo.RegisterEventHandler("HousingResultInterceptRequest", "OnHousingResultInterceptRequest", self) -- lua initiated events
end

-----------------------------------------------------------------------------------------------
-- HousingAlerts Event Handlers
-----------------------------------------------------------------------------------------------

function HousingAlerts:OnHousingResultInterceptRequest( wndIntercept, arResultSet )
	if arResultSet == nil and self.tIntercept.wndIntercept == wndIntercept then
		self.tIntercept = {}
		return
	end
	
	self.tIntercept.wndIntercept = wndIntercept
	self.tIntercept.arResultSet = arResultSet
end

function HousingAlerts:OnHousingResult( strName, eResult )
	local strAlertMessage = self:GenerateAlert( strName, eResult )

	if self:IsIntercepted( eResult ) then
		local wndIntercept = self.tIntercept.wndIntercept
		self.tIntercept = {}
		Event_FireGenericEvent("HousingResultInterceptResponse", eResult, wndIntercept, strAlertMessage )
	else
		local strWrapperId = "HousingList_Error"
		if HousingLib.IsWarplotResidence() then
			strWrapperId = "Warplot_Error"
		end
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, String_GetWeaselString(Apollo.GetString(strWrapperId), strAlertMessage), "")
	end
end

-----------------------------------------------------------------------------------------------
-- HousingAlerts Functions
-----------------------------------------------------------------------------------------------

function HousingAlerts:IsIntercepted( eResult )
	if self.tIntercept == {} then
		return false
	end

	if self.tIntercept.arResultSet then
		for nIdx,eFilterResult in pairs(self.tIntercept.arResultSet) do
			if eFilterResult == eResult then
				-- match found
				return true
			end
		end
		-- match not found
		return false
	end

	-- no need to filter
	return false
end

function HousingAlerts:GenerateAlert( strName, eResult )
	local strResult = ktHousingSimpleResultStrings[eResult]
	local strComplexResult = ktHousingComplexResultStringIds[eResult]
	
	if not strResult then
		strResult = String_GetWeaselString(Apollo.GetString("Neighbors_UndefinedResult"), eResult) -- just in case
	end

	strName = tostring(strName or '') -- just in case.

	if string.len(strName) >= 1 and strComplexResult then
		strResult = String_GetWeaselString(strComplexResult, strName)
	end
	
	return strResult
end

-----------------------------------------------------------------------------------------------
-- HousingAlerts Instance
-----------------------------------------------------------------------------------------------
local HousingAlertsInst = HousingAlerts:new()
HousingAlertsInst:Init()
