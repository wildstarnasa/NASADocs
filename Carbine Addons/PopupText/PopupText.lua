-----------------------------------------------------------------------------------------------
-- Client Lua Script for PopupText
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "PlayerPathLib"
require "PathMission"
require "GameLib"

local PopupText = {}

local knPathDuration = 3.0

local karPathToIcon =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "CRB_PlayerPathSprites:spr_Path_Soldier_Stretch",
	[PlayerPathLib.PlayerPathType_Settler] 		= "CRB_PlayerPathSprites:spr_Path_Settler_Stretch",
	[PlayerPathLib.PlayerPathType_Explorer]		= "CRB_PlayerPathSprites:spr_Path_Explorer_Stretch",
	[PlayerPathLib.PlayerPathType_Scientist]	= "CRB_PlayerPathSprites:spr_Path_Scientist_Stretch",
}

local karPathToString =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("FloatText_SoldierMissionUnlocked"),
	[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("FloatText_SettlerMissionUnlocked"),
	[PlayerPathLib.PlayerPathType_Explorer]		= Apollo.GetString("FloatText_ExplorerMissionUnlocked"),
	[PlayerPathLib.PlayerPathType_Scientist]	= Apollo.GetString("FloatText_ScientistMissionUnlocked"),
}

function PopupText:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function PopupText:Init()
    Apollo.RegisterAddon(self)
end

function PopupText:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PopupText.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PopupText:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CharacterCreated", 								"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("PopupText_ShowPathAlert",							"OnPopupText_ShowPathAlert", self)
	Apollo.RegisterEventHandler("PopupText_ShowEpisodeAlert",						"OnPopupText_ShowEpisodeAlert", self)

	Apollo.RegisterTimerHandler("PopupText_DestroyAnimationStepOne",				"OnPopupText_DestroyAnimationStepOne", self)
	Apollo.RegisterTimerHandler("PopupText_DestroyAnimationStepTwo",				"OnPopupText_DestroyAnimationStepTwo", self)
	Apollo.RegisterTimerHandler("PopupText_DestroyAnimationStepThree_QuestLog",		"OnPopupText_DestroyAnimationStepThree_QuestLog", self)
	Apollo.RegisterTimerHandler("PopupText_DestroyAnimationStepThree_Datachron",	"OnPopupText_DestroyAnimationStepThree_Datachron", self)
	Apollo.StopTimer("PopupText_DestroyAnimationStepOne")
	Apollo.StopTimer("PopupText_DestroyAnimationStepTwo")
	Apollo.StopTimer("PopupText_DestroyAnimationStepThree_QuestLog")
	Apollo.StopTimer("PopupText_DestroyAnimationStepThree_Datachron")

	self.wndMain = nil

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
end

function PopupText:OnCharacterCreated()
	-- This needs to use the unit's path instead of PlayerPathLib in case PlayerPathLib's type hasn't been updated yet
	local unitPlayer = GameLib.GetPlayerUnit()
	self.ePlayerPath = unitPlayer:GetPlayerPathType()
end

function PopupText:OnPopupText_ShowEpisodeAlert(strArgMessage)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
	end

	local strTopText = Apollo.GetString("FloatText_EpisodeUnlocked")
	local strBotText = strArgMessage or ""
	local nTextWidth1 = Apollo.GetTextWidth("CRB_HeaderHuge", strTopText)
	local nTextWidth2 = Apollo.GetTextWidth("CRB_Interface12", strBotText)
	local nFinalWidth = (math.max(nTextWidth1, nTextWidth2) + 50) / 2

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PopupEpisodeCenter", nil, self)
	self.wndMain:FindChild("TopText"):SetText(strTopText)
	self.wndMain:FindChild("BottomText"):SetText(strBotText)

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = { 0.5, 0.5, 0.5, 0.5 }, nOffsets = { nFinalWidth * (-1), nTop, nFinalWidth, nBottom }})
	self.wndMain:TransitionMove(tLoc, 0.25)

	Apollo.CreateTimer("PopupText_DestroyAnimationStepOne", 2.5, false)
	Apollo.CreateTimer("PopupText_DestroyAnimationStepTwo", 3.0, false)
	Apollo.CreateTimer("PopupText_DestroyAnimationStepThree_QuestLog", 3.15, false)
end

function PopupText:OnPopupText_ShowPathAlert(strArgMessage, tContent) -- Arguments are legacy
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	local strTopText = karPathToString[self.ePlayerPath]
	local strBotText = tContent and tContent:GetName() or Apollo.GetString("CRB_Several_New_Missions_Added")
	local nTextWidth1 = Apollo.GetTextWidth("CRB_HeaderHuge", strTopText)
	local nTextWidth2 = Apollo.GetTextWidth("CRB_Interface12", strBotText)
	local nFinalWidth = (math.max(nTextWidth1, nTextWidth2) + 50) / 2

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PopupPathCenter", nil, self)
	self.wndMain:FindChild("Icon"):SetSprite(karPathToIcon[self.ePlayerPath])
	self.wndMain:FindChild("TopText"):SetText(strTopText)
	self.wndMain:FindChild("BottomText"):SetText(strBotText)

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = { 0.5, 0.5, 0.5, 0.5 }, nOffsets = { nFinalWidth * (-1), nTop, nFinalWidth, nBottom }})
	self.wndMain:TransitionMove(tLoc, 0.25)

	Apollo.CreateTimer("PopupText_DestroyAnimationStepOne", 2.5, false)
	Apollo.CreateTimer("PopupText_DestroyAnimationStepTwo", 3.0, false)
	Apollo.CreateTimer("PopupText_DestroyAnimationStepThree_Datachron", 3.15, false)
end

--[[ Old
function PopupText:OnPopupText_DestroyAnimationStepOne()
	if self.wndMain and self.wndMain:IsValid() then
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		local tLoc = WindowLocation.new({ fPoints = {0.5, 0.5, 0.5, 0.5}, nOffsets = { nLeft, nTop, nLeft + 95, nBottom }})
		self.wndMain:TransitionMove(tLoc, 0.5)
	end
end
]]--

function PopupText:OnPopupText_DestroyAnimationStepOne()
	if self.wndMain and self.wndMain:IsValid() then
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		local tLoc = WindowLocation.new({ fPoints = {0.5, 0.5, 0.5, 0.5}, nOffsets = { -30, nTop, 30, nBottom }})
		self.wndMain:TransitionMove(tLoc, 0.5)
	end
end

function PopupText:OnPopupText_DestroyAnimationStepTwo()
	if self.wndMain and self.wndMain:IsValid() then
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		local tLoc = WindowLocation.new({ fPoints = {0.5, 0.5, 0.5, 0.5}, nOffsets = { nLeft - 10, nTop - 10, nRight, nBottom }})
		self.wndMain:TransitionMove(tLoc, 0.15)

		-- Can't transition these
		self.wndMain:FindChild("BG"):Show(false)
		self.wndMain:FindChild("BGAnim"):Show(false)
		self.wndMain:FindChild("TopText"):Show(false)
		self.wndMain:FindChild("BottomText"):Show(false)
	end
end

function PopupText:OnPopupText_DestroyAnimationStepThree_Datachron()
	if self.wndMain and self.wndMain:IsValid() then
		local tLoc = WindowLocation.new({ fPoints = {1, 1, 1, 1}, nOffsets = { 0, 0, 0, 0 }})
		self.wndMain:TransitionMove(tLoc, 0.33)
		self.wndMain:Show(false, false, 0.2) -- 0.5
	end
end

function PopupText:OnPopupText_DestroyAnimationStepThree_QuestLog()
	if self.wndMain and self.wndMain:IsValid() then
		local tLoc = WindowLocation.new({ fPoints = {1, 0.75, 1, 0.75}, nOffsets = { 0, 0, 0, 0 }})
		self.wndMain:TransitionMove(tLoc, 0.33)
		self.wndMain:Show(false, false, 0.2) -- 0.5
	end
end

local PopupTextInst = PopupText:new()
PopupTextInst:Init()
