-----------------------------------------------------------------------------------------------
-- Client Lua Script for Contracts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Contract"
require "ContractsLib"
require "RewardTrack"
require "RewardTrackLib"
require "Quest"

local Contracts = {}

local ktContractQualityArt =
{
	[ContractsLib.ContractQuality.None]			= { strActive = "",											strAvailable = "Contracts:sprContracts_Difficulty01",		strOverview = Apollo.GetString("Contract_Level1Repeatable"), },
	[ContractsLib.ContractQuality.Good]			= { strActive = "Contracts:sprContracts_Difficulty01",		strAvailable = "Contracts:sprContracts_Difficulty01",		strOverview = Apollo.GetString("Contract_Level1Repeatable"), },
	[ContractsLib.ContractQuality.Excellent]	= { strActive = "Contracts:sprContracts_Difficulty02",		strAvailable = "Contracts:sprContracts_Difficulty02",		strOverview = Apollo.GetString("CRB_2"), },
	[ContractsLib.ContractQuality.Superb]		= { strActive = "Contracts:sprContracts_Difficulty03",		strAvailable = "Contracts:sprContracts_Difficulty03",		strOverview = Apollo.GetString("CRB_3"), },
	[ContractsLib.ContractQuality.Legendary]	= { strActive = "",											strAvailable = "Contracts:sprContracts_Difficulty03",		strOverview = Apollo.GetString("CRB_4"), },
}

local ktContractTypeArt =
{
	[0]		= { strActive = "Contracts:sprContracts_Type01",		strAvailable = "Contracts:sprContracts_Type01",		strOverview = Apollo.GetString("CombatLogOptions_General"), },
	[122]	= { strActive = "Contracts:sprContracts_Type01",		strAvailable = "Contracts:sprContracts_Type01",		strOverview = Apollo.GetString("CombatLogOptions_General"), },
	[123]	= { strActive = "Contracts:sprContracts_Type02",		strAvailable = "Contracts:sprContracts_Type02",		strOverview = Apollo.GetString("CRB_Kill"), },
	[124]	= { strActive = "Contracts:sprContracts_Type03",		strAvailable = "Contracts:sprContracts_Type03",		strOverview = Apollo.GetString("CRB_Collection"), },
	[125]	= { strActive = "Contracts:sprContracts_Type04",		strAvailable = "Contracts:sprContracts_Type04",		strOverview = Apollo.GetString("CRB_Completion"), },
}

local knSaveVersion = 2

function Contracts:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.nCurrentRewardTrackProgress = 0
	o.nCurrentRewardTrackGoal = 0
	o.nCurrentRewardTrackPossibleProgress = 0
	o.nCurrentRewardTrackPossibleGoal = 0
	o.contractViewed = nil
	o.tWndRefs = {}

    return o
end

function Contracts:Init()
    Apollo.RegisterAddon(self)
end

function Contracts:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Contracts.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function Contracts:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		Apollo.RegisterSlashCommand("contracts", "ToggleContracts", self)

		Apollo.RegisterEventHandler("ContractBoardOpen", 							"OpenContracts", self)
		Apollo.RegisterEventHandler("ContractBoardClose", 							"CloseContracts", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 					"OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("GenericEvent_InterfaceMenu_OpenContracts", 	"ToggleContracts", self)
		Apollo.RegisterEventHandler("LevelUpUnlock_PvE_Contracts", 	"OpenContracts", self)

		Apollo.RegisterEventHandler("ContractStateChanged", 						"OnContractStateChanged", self)
		Apollo.RegisterEventHandler("ContractGoodQualityChanged", 					"RedrawAll", self)
		Apollo.RegisterEventHandler("RewardTrackUpdated",							"OnRewardTrackUpdated", self)
		Apollo.RegisterEventHandler("RewardTrackActive",							"RedrawAll", self)
	
		-- Toast
		Apollo.RegisterEventHandler("ContractObjectiveUpdated", 					"OnContractObjectiveUpdated", self)
		
		-- Defaults
		local wndTemp		
		wndTemp = Apollo.LoadForm(self.xmlDoc, "Contract", nil, self)
		self.nDefaultContractOverviewSummaryHeight = wndTemp:FindChild("ContractOverview:ContractSelected:Summary"):GetHeight()
		wndTemp:Destroy()
	end
end

function Contracts:OnInterfaceMenuListHasLoaded()
	local tData = { "GenericEvent_InterfaceMenu_OpenContracts", "", "Icon_Windows32_UI_CRB_InterfaceMenu_Contracts"
 }
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("CRB_Contracts"), tData)
end

function Contracts:OpenContracts()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		return
	end
	
	self.wndAbandonConfirm = nil
	local wndMain = Apollo.LoadForm(self.xmlDoc, "ContractsForm", nil, self)
	wndMain:Invoke()

	local wndContractContainer = wndMain:FindChild("ContractContainer")
	local wndPvEContracts = Apollo.LoadForm(self.xmlDoc, "Contract", wndContractContainer, self)
	local wndPvPContracts = Apollo.LoadForm(self.xmlDoc, "Contract", wndContractContainer, self)
	
	local fnContractWindowSetup = function(wndContract, strContractType, sprContractSectionIcon)
		-- Put coloring and string setting specific to pve vs pvp in here
	
		wndContract:FindChild("AvailableContracts:SectionTitle"):SetText(strContractType)
		wndContract:FindChild("RewardTrack:FinalRewardPoint:FinalHeaderIcon"):SetSprite(sprContractSectionIcon)
		
		local wndRewardListOpenBtn = wndContract:FindChild("RewardListOpenBtn")
		
		local wndRewardList = wndRewardListOpenBtn:FindChild("RewardList")
		wndRewardListOpenBtn:AttachWindow(wndRewardList)
		
		local wndRewardListCloseBtn = wndRewardList:FindChild("RewardListCloseBtn")
		wndRewardListCloseBtn:SetData(wndRewardList)
		wndRewardListCloseBtn:SetCheck(true)
		
		local wndActiveContractContainer = wndContract:FindChild("ActiveContractContainer")
		for idx = 1, ContractsLib.kMaxActiveContracts do
			local wndActive = Apollo.LoadForm(self.xmlDoc, "ActiveContract", wndActiveContractContainer, self)
			wndActive:SetTooltip(Apollo.GetString("Contracts_EmptyActiveContractTooltip"))
			wndActive:FindChild("QualityIcon"):Show(false)
			wndActive:FindChild("TypeIcon"):Show(false)
			wndActive:FindChild("AchievedGlow"):Show(false)
			wndActive:FindChild("SelectBtn"):Show(false)
		end
	end
	
	fnContractWindowSetup(wndPvEContracts, Apollo.GetString("Contracts_AvailableContractPve"), "Contracts:sprContracts_PvE")
	fnContractWindowSetup(wndPvPContracts, Apollo.GetString("Contracts_AvailableContractPvp"), "Contracts:sprContracts_PvP")
	
	self.tWndRefs =
	{
		["wndMain"]								= wndMain,
		["wndPvEContracts"]						= wndPvEContracts,
		["wndPvPContracts"]						= wndPvPContracts,
		["wndPvEContractsBtn"]					= wndMain:FindChild("PveContractsBtn"),
		["wndPvPContractsBtn"]					= wndMain:FindChild("PvpContractsBtn"),
		["wndContractContainer"]				= wndContractContainer,
		["wndRefreshFlash"]						= wndMain:FindChild("RefreshFlash"),
	}

	self.nDefaultActiveContractsHeight = wndMain:FindChild("ContractContainer"):GetHeight()

	self:RedrawAll()
	
	if self.contractViewed ~= nil then
		if self.contractViewed:GetType() == ContractsLib.ContractType.Pvp then
			self.tWndRefs.wndPvPContractsBtn:SetCheck(true)
			self.tWndRefs.wndPvEContractsBtn:SetCheck(false)
			wndPvEContracts:Show(false)
			wndPvPContracts:Show(true)
			
		elseif self.contractViewed:GetType() == ContractsLib.ContractType.Pve then
			self.tWndRefs.wndPvPContractsBtn:SetCheck(false)
			self.tWndRefs.wndPvEContractsBtn:SetCheck(true)			
			wndPvEContracts:Show(true)
			wndPvPContracts:Show(false)
		end
	else
		self.tWndRefs.wndPvEContractsBtn:SetCheck(true)
		wndPvEContracts:Show(true)
		wndPvPContracts:Show(false)
	end
end

function Contracts:CloseContracts()
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	self.tWndRefs.wndMain:Close()
end

function Contracts:ToggleContracts()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		self:CloseContracts()
	else
		self:OpenContracts()
	end
	
end

function Contracts:OnClose(wndHandler, wndControl)
	if self.tWndRefs.wndMain and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Destroy()
		self.tWndRefs = {}
		Event_CancelContractBoard()
	end
end

function Contracts:OnContractStateChanged(contract, eState)
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		return
	end
	
	for idx, wndContract in pairs(self.tWndRefs.wndContractContainer:GetChildren()) do
		local tData = wndContract:GetData()
		if tData.eContractType == contract:GetType() then
			local tBothAvailableContracts = ContractsLib.GetPeriodicContracts()
			local tBothActiveContracts = ContractsLib.GetActiveContracts()
			
			self:DrawActiveContracts(wndContract, tData.eContractType, tData.eRewardType, tBothActiveContracts[tData.eContractType])
			self:DrawPeriodicContracts(wndContract, tBothAvailableContracts[tData.eContractType], #tBothActiveContracts[tData.eContractType])
			self:DrawRewards(wndContract, tData.eContractType, tData.eRewardType, tBothActiveContracts[tData.eContractType])
			
			local wndContractSelected = wndContract:FindChild("ContractSelected")
			
			local contractSelected = wndContractSelected:GetData()
			if wndContractSelected:IsShown() and contract:GetId() == contractSelected:GetId() then
				if eState == Quest.QuestState_Abandoned then
					self:DrawContractOverview(wndContract, nil)
				else
					self:DrawContractOverview(wndContract, contract)
				end
			end
			
			if eState == Quest.QuestState_Accepted then
				for idx, wndContract in pairs(wndContract:FindChild("AvailableContracts:ContractContainer"):GetChildren()) do
					if contract == wndContract:GetData() then
						local wndActivatedContractFlash = wndContract:FindChild("Container:ActivatedContractFlash")
						wndActivatedContractFlash:Show(true)
						wndContract:FindChild("Container:SelectBtn"):SetCheck(true)
						break
					end
				end
				
				for idx, wndContract in pairs(wndContract:FindChild("ActiveContracts:ActiveContractContainer"):GetChildren()) do
					if contract == wndContract:GetData() then
						local wndActivatedContractFlash = wndContract:FindChild("ActivatedContractFlash")
						wndActivatedContractFlash:Show(true)
						wndActivatedContractFlash:SetSprite("Contracts:sprContracts_SlottedAnim")
						wndContract:FindChild("SelectBtn"):SetCheck(true)
						break
					end
				end
			elseif eState == Quest.QuestState_Abandoned then
				for idx, wndContract in pairs(wndContract:FindChild("AvailableContracts:ContractContainer"):GetChildren()) do
					if contract == wndContract:GetData() then
						local wndAbandonedContractFlash = wndContract:FindChild("Container:AbandonedContractFlash")
						wndAbandonedContractFlash:Show(true)
						wndContract:FindChild("Container:SelectBtn"):SetCheck(false)
						break
					end
				end
			elseif eState == Quest.QuestState_Completed then
				for idx, wndContract in pairs(wndContract:FindChild("AvailableContracts:ContractContainer"):GetChildren()) do
					if contract == wndContract:GetData() then
						local wndTurnInContractFlash = wndContract:FindChild("Container:TurnInContractFlash")
						wndTurnInContractFlash:Show(true)
						break
					end
				end
			end
			
			return
		end
	end
end

function Contracts:OnRewardTrackUpdated(rewardTrack)
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		return
	end

	for idx, wndContract in pairs(self.tWndRefs.wndContractContainer:GetChildren()) do
		local tData = wndContract:GetData()
		if tData.eRewardType == rewardTrack:GetType() then
		
			local rtRewardTrack = RewardTrackLib.GetActiveRewardTrackByType(tData.eRewardType)
			local arRewards = rtRewardTrack:GetAllRewards()
			local nRewardMax = arRewards[#arRewards].nCost
			local nRewardProgress = rtRewardTrack:GetRewardPointsEarned()
			local nCurrentRewardProgress = wndContract:FindChild("RewardTrack:Progress"):GetProgress()
		
			if nCurrentRewardProgress < nRewardMax and nCurrentRewardProgress < nRewardProgress then
				for idx = #arRewards, 1, -1 do
					local tReward = arRewards[idx]
					if tReward.nCost <= nRewardProgress then
						if idx == #arRewards then
							Sound.Play(Sound.PlayUIContractGoldMilestoneAchieved)
							break
						else
							Sound.Play(Sound.PlayUIContractMilestoneAchieved)
							break
						end
					end
				end
			end
		
			local tBothActiveContracts = ContractsLib.GetActiveContracts()
			self:DrawRewards(wndContract, tData.eContractType, tData.eRewardType, tBothActiveContracts[tData.eContractType])
			return
		end
	end
end

function Contracts:RedrawAll()
	if not self.tWndRefs.wndMain or not self.tWndRefs.wndMain:IsValid() or not self.tWndRefs.wndMain:IsVisible() then
		return
	end

	-- Contracts
	local tBothAvailableContracts = ContractsLib.GetPeriodicContracts()
	local tBothActiveContracts = ContractsLib.GetActiveContracts()
	
	-- pvp
	self:RedrawContract(self.tWndRefs.wndPvPContracts, ContractsLib.ContractType.Pvp, RewardTrackLib.RewardTrackType.Contract_Pvp, tBothActiveContracts[ContractsLib.ContractType.Pvp], tBothAvailableContracts[ContractsLib.ContractType.Pvp])
	
	-- pve
	self:RedrawContract(self.tWndRefs.wndPvEContracts, ContractsLib.ContractType.Pve, RewardTrackLib.RewardTrackType.Contract_Pve, tBothActiveContracts[ContractsLib.ContractType.Pve], tBothAvailableContracts[ContractsLib.ContractType.Pve])
	
end

function Contracts:RedrawContract(wndContract, eContractType, eRewardType, tActiveContractList, tAvailableContracts)
	wndContract:SetData({ ["eContractType"] = eContractType, ["eRewardType"] = eRewardType })

	self:DrawActiveContracts(wndContract, eContractType, eRewardType, tActiveContractList)
	self:DrawRewards(wndContract, eContractType, eRewardType, tActiveContractList)
	self:DrawPeriodicContracts(wndContract, tAvailableContracts, #tActiveContractList)
	
	local contract = self.contractViewed
	if contract ~= nil and contract:GetType() ~= eContractType then
		self:DrawContractOverview(wndContract, nil)
		self.contractViewed = contract -- Prevent DrawContractOverview from overwriting the saved contract
	else
		self:DrawContractOverview(wndContract, contract)
	end
	
end

function Contracts:DrawActiveContracts(wndContainer, eContractType, eRewardType, tActiveContractList)
	local wndActiveContractContainer = wndContainer:FindChild("ActiveContractContainer")
	
	local tActiveContractsById = {}
	local tActiveContractsOnWindowsById = {}
	
	for idx, contractActive in pairs(tActiveContractList) do
		tActiveContractsById[contractActive:GetId()] = contractActive
	end
	
	for idx, wndActiveCandidate in pairs(wndActiveContractContainer:GetChildren()) do
		local contractOnWindow = wndActiveCandidate:GetData()
		if contractOnWindow ~= nil then
			if tActiveContractsById[contractOnWindow:GetId()] ~= nil then
				tActiveContractsOnWindowsById[contractOnWindow:GetId()] = contractOnWindow
			end
		end
	end
	
	for idx, wndActive in pairs(wndActiveContractContainer:GetChildren()) do
		local contractActive
		
		local contractOnWindow = wndActive:GetData()
		if contractOnWindow == nil then
			for idContract, contractCandidate in pairs(tActiveContractsById) do
				if tActiveContractsOnWindowsById[contractCandidate:GetId()] == nil then
					contractActive = contractCandidate
					tActiveContractsOnWindowsById[contractCandidate:GetId()] = contractCandidate
					break
				end
			end
		else
			if tActiveContractsById[contractOnWindow:GetId()] ~= nil then
				contractActive = contractOnWindow
			end
		end
		
		if contractActive == nil then
			if contractOnWindow ~= nil then
				if contractOnWindow:GetQuest():GetState() == Quest.QuestState_Completed then
					local wndActivatedContractFlash = wndActive:FindChild("TurnInContractFlash")
					wndActivatedContractFlash:Show(true)
					wndActivatedContractFlash:SetSprite("Contracts:sprContracts_SlottedTurnIn")
				else
					local wndAbandonedContractFlash = wndActive:FindChild("AbandonedContractFlash")
					wndAbandonedContractFlash:Show(true)
					wndAbandonedContractFlash:SetSprite("Contracts:sprContracts_SlottedReverse")
				end
				
				local strCallbackFunctionName = "Contracts_ActiveCloseTimerCallback" .. contractOnWindow:GetId()
				self[strCallbackFunctionName] = function()
					if wndActive ~= nil and wndActive:IsValid() then
						wndActive:SetData(nil)
						wndActive:SetTooltip(Apollo.GetString("Contracts_EmptyActiveContractTooltip"))
						wndActive:FindChild("QualityIcon"):Show(false)
						wndActive:FindChild("TypeIcon"):Show(false)
						wndActive:FindChild("AchievedGlow"):Show(false)
						wndActive:FindChild("SelectBtn"):Show(false)
						wndActive:FindChild("ActivatedContractFlash"):Show(false)
					end
					
					self[strCallbackFunctionName] = nil
				end
				
				wndActive:SetData(ApolloTimer.Create(0.5, false, strCallbackFunctionName, self))
			else
				wndActive:SetData(nil)
				wndActive:SetTooltip(Apollo.GetString("Contracts_EmptyActiveContractTooltip"))
				wndActive:FindChild("QualityIcon"):Show(false)
				wndActive:FindChild("TypeIcon"):Show(false)
				wndActive:FindChild("AchievedGlow"):Show(false)
				wndActive:FindChild("SelectBtn"):Show(false)
				wndActive:FindChild("ActivatedContractFlash"):Show(false)
			end
			
		else
			wndActive:SetData(contractActive)
			
			local wndQualityIcon = wndActive:FindChild("QualityIcon")
			wndQualityIcon:Show(true)
			wndQualityIcon:SetSprite(ktContractQualityArt[contractActive:GetQuality()].strActive)
			
			local wndTypeIcon = wndActive:FindChild("TypeIcon")
			wndTypeIcon:Show(true)
			wndTypeIcon:SetSprite(ktContractTypeArt[contractActive:GetQuest():GetSubType()].strActive)

			local wndSelectBtn = wndActive:FindChild("SelectBtn")
			wndSelectBtn:SetData({ ["wndContainer"] = wndContainer, ["contract"] = contractActive })
			wndSelectBtn:Show(true)
			wndSelectBtn:SetCheck(contractActive == self.contractViewed)
			
			-- Tooltip			
			wndActive:SetTooltip(self:BuildContractTooltip(contractActive, #tActiveContractList))
			
			if contractActive:IsAchieved() then
				wndActive:FindChild("AchievedGlow"):Show(true)
			end

		end
	end
	
	wndActiveContractContainer:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.Middle)
end

function Contracts:DrawRewards(wndContainer, eContractType, eRewardType, tActiveContractList)
	local wndRewardTrack = wndContainer:FindChild("RewardTrack")
	local wndRewardList = wndContainer:FindChild("RewardListOpenBtn:RewardList")

	local rtRewardTrack = RewardTrackLib.GetActiveRewardTrackByType(eRewardType)
	local arRewards = rtRewardTrack:GetAllRewards()
	
	local nTotalReward = 0
	for idx, contractActive in pairs(tActiveContractList or {}) do
		local eActiveType = contractActive:GetType()
		if eActiveType == eContractType then
			nTotalReward = nTotalReward + contractActive:GetRewardTrackValue()
		end
	end
	
	local wndRewardPointContainer = wndRewardTrack:FindChild("Container")
	wndRewardPointContainer:DestroyChildren()
	
	local nRewardMax = arRewards[#arRewards].nCost
	local nRewardProgress = rtRewardTrack:GetRewardPointsEarned()
	
	local wndRewardProgressBar = wndRewardTrack:FindChild("Progress")
	wndRewardProgressBar:SetMax(nRewardMax)
	if wndContainer:IsShown() then
		wndRewardProgressBar:SetProgress(nRewardProgress, nRewardMax)
	else
		wndRewardProgressBar:SetProgress(nRewardProgress)
	end
	wndRewardProgressBar:SetData(nRewardProgress)
	wndRewardProgressBar:SetTooltip(String_GetWeaselString(Apollo.GetString("Contracts_RewardBarProgressTooltip"), nRewardProgress, Apollo.FormatNumber(nRewardMax)))
	
	self.nCurrentRewardTrackProgress = nRewardProgress
	self.nCurrentRewardTrackGoal = nRewardMax
	
	local wndRewardTeaserBar = wndRewardTrack:FindChild("ActiveProgress")
	wndRewardTeaserBar:SetMax(nRewardMax)
	local nPossibleProgress = nRewardProgress + nTotalReward
	if wndContainer:IsShown() then
		wndRewardTeaserBar:SetProgress(nPossibleProgress, nRewardMax)
	else
		wndRewardTeaserBar:SetProgress(nPossibleProgress)
	end
	wndRewardTeaserBar:SetData(nPossibleProgress)
	wndRewardTeaserBar:Show(nTotalReward > 0)
	
	self.nCurrentRewardTrackPossibleProgress = nPossibleProgress
	self.nCurrentRewardTrackPossibleGoal = nRewardMax
	
	local wndRewardListContainer = wndRewardList:FindChild("Container")
	local nScrollPos = wndRewardListContainer:GetVScrollPos()
	wndRewardListContainer:DestroyChildren()
	
	local arReverse = {}
	
	for idx, tReward in pairs(arRewards) do
		if idx ~= #arRewards then
			local wndRewardPoint = Apollo.LoadForm(self.xmlDoc, "RewardPoint", wndRewardPointContainer, self)
			self:DrawRewardPoint(wndContainer, wndRewardPoint, rtRewardTrack, tReward, wndRewardProgressBar, wndRewardList, true)
		else
			self:DrawRewardPoint(wndContainer, wndRewardTrack:FindChild("FinalRewardPoint"), rtRewardTrack, tReward, wndRewardProgressBar, wndRewardList, false)
		end
		table.insert(arReverse, 1, tReward)
	end
	
	for idx, tReward in pairs(arReverse) do
		local wndEntry = Apollo.LoadForm(self.xmlDoc, "RewardListEntry", wndRewardListContainer, self)
		self:DrawRewardListEntry(wndEntry, rtRewardTrack, tReward)
	end

	wndRewardListContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	wndRewardListContainer:SetVScrollPos(nScrollPos)
end

function Contracts:DrawRewardPoint(wndContainer, wndRewardPoint, rtRewardTrack, tReward, wndRewardProgressBar, wndRewardList, bMoveIntoPlace)
	local arRewards = rtRewardTrack:GetAllRewards()
	local nRewardMax = arRewards[#arRewards].nCost

	local nDisplayRewardIdx = tReward.nRewardIdx + 1

	local wndTooltip = wndRewardPoint:FindChild("RewardPointTooltip")
	
	wndRewardPoint:FindChild("ActionBtn"):SetData({ ["tReward"] = tReward, ["rtRewardTrack"] = rtRewardTrack, ["wndRewardList"] = wndRewardList, ["wndTooltip"] = wndTooltip })
	
	if bMoveIntoPlace then
		local nBottom = -wndRewardProgressBar:GetHeight() * (tReward.nCost / nRewardMax)
		local nHalfWidth = wndRewardPoint:GetWidth() / 2.0
		local nHalfHeight = wndRewardPoint:GetHeight() / 2.0
		wndRewardPoint:SetAnchorOffsets(-nHalfWidth, nBottom - nHalfHeight, nHalfWidth, nBottom + nHalfHeight)
	end
	
	-- Tooltip
	if tReward.bIsClaimed then
		if bMoveIntoPlace then
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerComplete")
			wndRewardPoint:FindChild("AchievedBG"):SetSprite("")
		else
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerFinal")
			if self.tWndRefs.wndPvPContracts == wndContainer then
				wndRewardPoint:FindChild("HighlightBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvP")
				wndRewardPoint:FindChild("AchievedBG"):SetSprite("")
			else 
				wndRewardPoint:FindChild("HighlightBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvE")
				wndRewardPoint:FindChild("AchievedBG"):SetSprite("")
			end
		end
		wndTooltip:FindChild("ClickAction"):SetText(Apollo.GetString("Contracts_ClickToExpand"))
		wndTooltip:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardAlreadyClaimed"), nDisplayRewardIdx))
		wndTooltip:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
		wndTooltip:FindChild("ItemHeader"):SetText(Apollo.GetString("Contracts_RewardChosenFrom"))
	elseif tReward.bCanClaim then
		if bMoveIntoPlace then
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerReady")
			wndRewardPoint:FindChild("AchievedBG"):SetSprite("Contracts:sprContracts_MilestoneMarkerReadyAnim")
		else
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerFinalReady")
			if self.tWndRefs.wndPvPContracts == wndContainer then
				wndRewardPoint:FindChild("HighlightBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvP")
				wndRewardPoint:FindChild("AchievedBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvPFlash")
			else 
				wndRewardPoint:FindChild("HighlightBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvE")
				wndRewardPoint:FindChild("AchievedBG"):SetSprite("Contracts:sprContracts_MilestoneFinalCapPvEFlash")
			end
		end
		wndTooltip:FindChild("ClickAction"):SetText(Apollo.GetString("Contracts_ClickToChooseReward"))
		wndTooltip:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardsReadyToClaim"), nDisplayRewardIdx))
		wndTooltip:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
		wndTooltip:FindChild("ItemHeader"):SetText(Apollo.GetString("Contracts_RewardChoices"))
	else
		if bMoveIntoPlace then
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerStart")
			wndRewardPoint:FindChild("AchievedBG"):SetSprite("")
		else
			wndRewardPoint:FindChild("ActionBtn"):ChangeArt("Contracts:btnContracts_MilestoneMarkerFinal")
			wndRewardPoint:FindChild("HighlightBG"):SetSprite("")
		end
		wndTooltip:FindChild("ClickAction"):SetText(Apollo.GetString("Contracts_ClickForDetails"))
		local strRewardNeeded = Apollo.FormatNumber(tReward.nCost - rtRewardTrack:GetRewardPointsEarned())
		wndTooltip:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardRequiresMorePoints"), nDisplayRewardIdx, strRewardNeeded))
		wndTooltip:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("white"))
		wndTooltip:FindChild("ItemHeader"):SetText(Apollo.GetString("Contracts_RewardChoices"))
	end
	
	-- tooltip Cash
	wndTooltip:FindChild("CashReward"):Show(tReward.monReward:GetAmount() > 0)
	wndTooltip:FindChild("CashReward"):SetAmount(tReward.monReward, true)
	
	-- Tooltip items
	local wndItemContainer = wndTooltip:FindChild("ItemRewards")
	wndItemContainer:DestroyChildren()
	for idx, tItemChoice in pairs(tReward.tItemChoices) do
		local wndItem = Apollo.LoadForm(self.xmlDoc, "RewardPointTooltipItem", wndItemContainer, self)
		
		wndItem:FindChild("ItemCantUse"):Show(tItemChoice.itemReward:IsEquippable() and not tItemChoice.itemReward:CanEquip())
		wndItem:FindChild("ItemIcon"):GetWindowSubclass():SetItem(tItemChoice.itemReward)
		if tItemChoice.nItemAmount > 1 then
			wndItem:FindChild("ItemStackCount"):SetText(tItemChoice.nItemAmount)
		end
	end
	wndItemContainer:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
end

function Contracts:DrawRewardListEntry(wndEntry, rtRewardTrack, tReward)
	local wndEntryContainer = wndEntry:FindChild("Container")

	local nDisplayRewardIdx = tReward.nRewardIdx + 1

	wndEntry:SetData({ ["tReward"] = tReward, ["rtRewardTrack"] = rtRewardTrack })
	
	local wndRewardListClaimBtn = wndEntryContainer:FindChild("RewardListClaimBtn")
	wndRewardListClaimBtn:SetData({ ["tReward"] = tReward, ["rtRewardTrack"] = rtRewardTrack })
	
	wndRewardListClaimBtn:Show(tReward.bCanClaim and not tReward.bIsClaimed)
	wndRewardListClaimBtn:Enable(#tReward.tItemChoices == 0)
	
	if tReward.bIsClaimed then
		wndEntryContainer:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardAlreadyClaimed"), nDisplayRewardIdx))
		wndEntryContainer:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
		wndEntryContainer:FindChild("ItemRewardContainer:ItemHeader"):SetText(Apollo.GetString("Contracts_RewardChosenFrom"))
	elseif tReward.bCanClaim then
		wndEntryContainer:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardsReadyToClaim"), nDisplayRewardIdx))
		wndEntryContainer:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
		wndEntryContainer:FindChild("ItemRewardContainer:ItemHeader"):SetText(Apollo.GetString("Contracts_PleaseChooseReward"))
	else
		local strRewardNeeded = Apollo.FormatNumber(tReward.nCost - rtRewardTrack:GetRewardPointsEarned())
		wndEntryContainer:FindChild("RewardLabel"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_RewardRequiresMorePoints"), nDisplayRewardIdx, strRewardNeeded))
		wndEntryContainer:FindChild("RewardLabel"):SetTextColor(ApolloColor.new("white"))
		wndEntryContainer:FindChild("ItemRewardContainer:ItemHeader"):SetText(Apollo.GetString("Contracts_RewardChoices"))
	end
	
	-- Cash
	wndEntryContainer:FindChild("CashReward"):Show(tReward.monReward:GetAmount() > 0)
	wndEntryContainer:FindChild("CashReward"):SetAmount(tReward.monReward, true)
	
	-- Items
	local wndItemRewardContainer = wndEntryContainer:FindChild("ItemRewardContainer")
	local wndItemContainer = wndItemRewardContainer:FindChild("ItemRewards")
	wndItemContainer:DestroyChildren()
	for idx, tItemChoice in pairs(tReward.tItemChoices) do
		local wndItem = Apollo.LoadForm(self.xmlDoc, "RewardSelectionItem", wndItemContainer, self)
		
		wndItem:FindChild("ItemCantUse"):Show(tItemChoice.itemReward:IsEquippable() and not tItemChoice.itemReward:CanEquip())
		wndItem:FindChild("ItemIcon"):GetWindowSubclass():SetItem(tItemChoice.itemReward)
		if tItemChoice.nItemAmount > 1 then
			wndItem:FindChild("ItemStackCount"):SetText(tItemChoice.nItemAmount)
		end
		wndItem:FindChild("ItemIcon"):SetData(tItemChoice)
		local wndSelectionBtn = wndItem:FindChild("SelectionBtn")
		wndSelectionBtn:SetData({ ["tItemChoice"] = tItemChoice, ["wndRewardListClaimBtn"] = wndRewardListClaimBtn })
		wndSelectionBtn:Enable(tReward.bCanClaim and not tReward.bIsClaimed)
	end
	wndItemContainer:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	wndItemRewardContainer:Show(#tReward.tItemChoices > 0)
	
	local nHeight = wndEntryContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
	wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)
end

function Contracts:DrawPeriodicContracts(wndContainer, tAvailableContracts, nActiveContractCount)
	local wndContractContainer = wndContainer:FindChild("AvailableContracts:ContractContainer")
	wndContractContainer:DestroyChildren()
	
	for idx, contractAvailable in pairs(tAvailableContracts or {}) do
		local queQuest = contractAvailable:GetQuest()
		if queQuest then
			local wndContract = Apollo.LoadForm(self.xmlDoc, "AvailableContract", wndContractContainer, self)
			wndContract:SetData(contractAvailable)
			
			local tObjectives = queQuest:GetVisibleObjectiveData()
			local wndSelectBtn = wndContract:FindChild("Container:SelectBtn")
			wndSelectBtn:SetData({ ["wndContainer"] = wndContainer, ["contract"] = contractAvailable })
			wndSelectBtn:SetCheck(contractAvailable == self.contractViewed)
			
			if contractAvailable:IsAchieved() then
				wndSelectBtn:ChangeArt("Contracts:btnContracts_CheckBoxSlotted")
			elseif contractAvailable:IsAccepted() then
				wndSelectBtn:ChangeArt("Contracts:btnContracts_CheckBoxSlotted")
			elseif contractAvailable:IsCompleted() then
				wndSelectBtn:ChangeArt("Contracts:btnContracts_CheckBoxLocked")
			elseif nActiveContractCount == ContractsLib.kMaxActiveContracts then
				wndSelectBtn:ChangeArt("Contracts:btnContracts_CheckBoxLocked")
			else
				wndSelectBtn:ChangeArt("Contracts:btnContracts_CheckBox")
			end
			
			wndContract:SetTooltip(self:BuildContractTooltip(contractAvailable, nActiveContractCount))
			
			local wndQualityIcon = wndContract:FindChild("Container:QualityIcon")
			wndQualityIcon:SetSprite(ktContractQualityArt[contractAvailable:GetQuality()].strAvailable)
			
			local wndTypeIcon = wndContract:FindChild("Container:TypeIcon")
			wndTypeIcon:SetSprite(ktContractTypeArt[contractAvailable:GetQuest():GetSubType()].strAvailable)
		end
	end
	
	wndContractContainer:ArrangeChildrenTiles(Window.CodeEnumArrangeOrigin.Middle)
end

function Contracts:DrawContractOverview(wndContainer, contract)
	local wndNoContractSelected = wndContainer:FindChild("NoContractSelected")
	local wndContractSelected = wndContainer:FindChild("ContractSelected")
	
	wndContractSelected:SetData(contract)
	self.contractViewed = contract
	
	if contract ~= nil then
		local queQuest = contract:GetQuest()
		
		wndContractSelected:FindChild("SectionContractTitle"):SetText(queQuest:GetTitle())
		wndContractSelected:FindChild("SectionContractClassification"):SetText(String_GetWeaselString(Apollo.GetString("Contracts_OverviewClassification"), ktContractQualityArt[contract:GetQuality()].strOverview, ktContractTypeArt[contract:GetQuest():GetSubType()].strOverview, contract:GetRewardTrackValue()))
		
		local wndSummary = wndContractSelected:FindChild("Summary")
		wndSummary:SetVScrollPos(0)
		
		local strSummary
		
		local tObjectives = queQuest:GetVisibleObjectiveData()
		if tObjectives and tObjectives[1] then
			strSummary = '<P Align="Center" Font="CRB_InterfaceSmall"><T TextColor="UI_TextHoloTitle">' .. Apollo.GetString("Contracts_ObjectiveSummary") .. '</T><T TextColor="ff56b381">' .. tObjectives[1].strDescription .. ". " .. '</T>'
		end
		
		if queQuest:GetSummary() then
			strSummary = strSummary .. '<T TextColor="UI_TextHoloBody">' .. queQuest:GetSummary().. '</T>'
		end
		
		strSummary = strSummary .. '</P>'
		
		local wndSummaryText = wndSummary:FindChild("SummaryText")
		wndSummaryText:SetAML(strSummary)
		wndSummaryText:SetHeightToContentHeight()
		wndSummary:RecalculateContentExtents()
		
		local wndCompletionRewards = wndContractSelected:FindChild("CompletionRewards")
		wndCompletionRewards:DestroyChildren()
		
		local wndRewardPoints = Apollo.LoadForm(self.xmlDoc, "ContractOverviewRewardItem", wndCompletionRewards, self)
		wndRewardPoints:FindChild("ItemCantUse"):Show(false)
		local wndRewardPointsItemIcon = wndRewardPoints:FindChild("ItemIcon")
		wndRewardPointsItemIcon:SetSprite("IconSprites:Icon_ItemMisc_ContractPoints")
		wndRewardPointsItemIcon:SetTooltip(String_GetWeaselString(Apollo.GetString("Contracts_RewardPointsRewarded"), contract:GetRewardTrackValue()))
		
		for idx, tRewardData in pairs(queQuest:GetRewardData().arFixedRewards) do
			local wndReward = Apollo.LoadForm(self.xmlDoc, "ContractOverviewRewardItem", wndCompletionRewards, self)
			
			if tRewardData.eType == Quest.Quest2RewardType_Item then			
				local wndItemIcon = wndReward:FindChild("ItemIcon")
				wndItemIcon:GetWindowSubclass():SetItem(tRewardData.itemReward)
				wndItemIcon:SetData({ itemReward = tRewardData.itemReward, nStackCount = tRewardData.nAmount})
				wndItemIcon:AddEventHandler("GenerateTooltip", "OnGenerateRewardItemTooltip")			
				wndReward:FindChild("ItemCantUse"):Show(tRewardData.itemReward:IsEquippable() and not tRewardData.itemReward:CanEquip())
				if tRewardData.nAmount > 1 then
					wndReward:FindChild("ItemStackCount"):SetText(tRewardData.nAmount)
				end
			elseif tRewardData.eType == Quest.Quest2RewardType_Reputation then
				wndReward:FindChild("ItemCantUse"):Show(false)
				local wndItemIcon = wndReward:FindChild("ItemIcon")
				wndItemIcon:SetSprite("Icon_ItemMisc_UI_Item_Parchment")
				wndItemIcon:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tRewardData.nAmount, tRewardData.strFactionName))
			elseif tRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
				wndReward:FindChild("ItemCantUse"):Show(false)
				local wndItemIcon = wndReward:FindChild("ItemIcon")
				wndItemIcon:SetSprite("Icon_ItemMisc_tool_0001")
				wndItemIcon:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tRewardData.nXP, tRewardData.strTradeskill))
			elseif tRewardData.eType == Quest.Quest2RewardType_Money then
				if tRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then					
					local monAmount = Money.new()
					monAmount:SetAmount(tRewardData.nAmount)
					
					wndReward:FindChild("ItemCantUse"):Show(false)
					local wndItemIcon = wndReward:FindChild("ItemIcon")
					wndItemIcon:SetSprite("ClientSprites:Icon_ItemMisc_bag_0001")
					wndItemIcon:SetTooltip(monAmount:GetMoneyString())
				else
					local tDenomInfo = GameLib.GetPlayerCurrency(tRewardData.eCurrencyType or tRewardData.idObject):GetDenomInfo()
					if tDenomInfo ~= nil then
						wndReward:FindChild("ItemCantUse"):Show(false)
						local wndItemIcon = wndReward:FindChild("ItemIcon")
						wndItemIcon:SetSprite("ClientSprites:Icon_ItemMisc_bag_0001")
						wndItemIcon:SetTooltip(tRewardData.nAmount .. " " .. tDenomInfo[1].strName)
					end
				end
			end
		end
		
		wndCompletionRewards:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		
		local bIsAtContractBoard = ContractsLib.IsAtContractBoard()
		local wndAcceptBtn = wndContractSelected:FindChild("AcceptBtn")
		wndAcceptBtn:Show(bIsAtContractBoard and contract:IsAvailable())
		wndAcceptBtn:SetData(contract)
		
		local wndAbandonBtn = wndContractSelected:FindChild("AbandonBtn")
		wndAbandonBtn:Show(contract:IsAccepted())
		wndAbandonBtn:SetData(queQuest)
		
		local wndTurnInBtn = wndContractSelected:FindChild("TurnInBtn")
		wndTurnInBtn:Show(bIsAtContractBoard and contract:IsAchieved())
		wndTurnInBtn:SetData(contract)
		
		wndContractSelected:FindChild("AcceptReminder"):Show(not bIsAtContractBoard and contract:IsAvailable())
		wndContractSelected:FindChild("TurnInReminder"):Show(not bIsAtContractBoard and contract:IsAchieved())
		wndContractSelected:FindChild("MaxActiveReminder"):Show(not contract:IsAvailable() and not contract:IsAccepted() and not contract:IsAchieved() and not contract:IsCompleted())
		wndContractSelected:FindChild("DoneReminder"):Show(contract:IsCompleted())

	end
	
	wndNoContractSelected:Show(contract == nil)
	wndContractSelected:Show(contract ~= nil)
end

function Contracts:BuildContractTooltip(contract, nActiveContractCount)
	local queQuest = contract:GetQuest()
	local strTooltip = ""
	
	if contract:IsAchieved() then
		strTooltip = String_GetWeaselString(Apollo.GetString("Contracts_CompletedTooltip"), String_GetWeaselString(Apollo.GetString("Contracts_ContractTitlePoints"), queQuest:GetTitle(), contract:GetRewardTrackValue()))
	elseif contract:IsAccepted() then
		strTooltip = String_GetWeaselString(Apollo.GetString("Contracts_ActivePrefix"), String_GetWeaselString(Apollo.GetString("Contracts_ContractTitlePoints"), queQuest:GetTitle(), contract:GetRewardTrackValue()))
	elseif contract:IsCompleted() then
		strTooltip = String_GetWeaselString(Apollo.GetString("Contracts_DonePrefix"), queQuest:GetTitle())
	elseif nActiveContractCount == ContractsLib.kMaxActiveContracts then
		strTooltip = String_GetWeaselString(Apollo.GetString("Contracts_ContractTitlePoints"), queQuest:GetTitle(), contract:GetRewardTrackValue())
	else
		strTooltip = String_GetWeaselString(Apollo.GetString("Contracts_ContractTitlePoints"), queQuest:GetTitle(), contract:GetRewardTrackValue())
	end
	
	return strTooltip
end

-----------------------------------------------------------------------------------------------
-- UI Interaction
-----------------------------------------------------------------------------------------------

function Contracts:OnAbandonBtnSignal(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local contract = wndHandler:GetData()
	local bHasProgress = false
	
	local tQuestObjectives = contract:GetVisibleObjectiveData()
	for idx, tObjective in pairs(tQuestObjectives) do
		bHasProgress = bHasProgress or tObjective.nCompleted > 0
	end
	
	if bHasProgress then
		self:OnAbandonConfirmClose()
		self.wndAbandonConfirm = Apollo.LoadForm(self.xmlDoc, "AbandonConfirm", self.tWndRefs.wndMain:FindChild("AbandonConfirmContainer"), self)
		self.wndAbandonConfirm:FindChild("YesBtn"):SetData(contract)		
		self.wndAbandonConfirm:Invoke()
	else
		self:OnAbandonConfirmYesBtn(wndHandler, wndControl)
	end
end

function Contracts:OnAbandonConfirmYesBtn(wndHandler, wndControl)
	wndHandler:GetData():Abandon()
	Sound.Play(Sound.PlayUIContractAbandonContract)
	self:OnAbandonConfirmClose()
end

function Contracts:OnAbandonConfirmClose(wndHandler, wndControl)
	if self.wndAbandonConfirm and self.wndAbandonConfirm:IsValid() then
		self.wndAbandonConfirm:Close()
		self.wndAbandonConfirm = nil
	end
end

function Contracts:OnRankLineItemMouseUp(wndHandler, wndControl)
	if wndHandler == wndControl and not wndHandler:FindChild("RankLineItemBtn"):IsEnabled() then
		local tContract = wndHandler:FindChild("RankLineItemBtn"):GetData()
		if tContract:IsAccepted() or tContract:IsCompleted() or tContract:IsAchieved() then
			return
		end
	end
end

function Contracts:OnAcceptBtnSignal(wndHandler, wndControl, eMouseButton)
	wndHandler:GetData():Accept()
	Sound.Play(Sound.PlayUIContractAcceptContract)
end

function Contracts:OnActiveContractTurnInBtn(wndHandler, wndControl)
	local contract = wndHandler:GetData()
	
	if contract:IsAchieved() then
		contract:Complete()
		Sound.Play(Sound.PlayUIContractTurnInContract)
	end

	self:RedrawAll()
end

-----------------------------------------------------------------------------------------------
-- Toast
-----------------------------------------------------------------------------------------------

function Contracts:OnContractObjectiveUpdated(contract)
	if contract:IsAchieved() then
		local queQuest = contract:GetQuest()
		self:DrawToast(contract, queQuest, tObjective)
		Sound.Play(Sound.PlayUIContractProgressComplete)
		self:RedrawAll()
		return
	end

	local queQuest = contract:GetQuest()
	for idObjective, tObjective in pairs(queQuest and queQuest:GetVisibleObjectiveData() or {}) do
		if tObjective.nNeeded > 0 then
			local nRatio = math.floor(tObjective.nCompleted / tObjective.nNeeded * 100)
			for idx, tCurr in pairs({ {1, 3}, {9, 11}, {23, 27}, {31, 34}, {48, 52}, {64, 68}, {73, 77}, {88, 92} }) do
				if nRatio >= tCurr[1] and nRatio <= tCurr[2] then
					self:DrawToast(contract, queQuest, tObjective)
					return
				end
			end
		end
	end
end

function Contracts:DrawToast(contract, queQuest, tObjective)
	if self.wndToast and self.wndToast:IsValid() then
		self.wndToast:Destroy()
	end

	local strSubtitle = ""
	if contract:IsAchieved() then
		strSubtitle = Apollo.GetString("Contracts_CompleteSubtitle")
	else
		strSubtitle = String_GetWeaselString("$1c%", math.max(1, math.min(100, math.floor(tObjective.nCompleted / tObjective.nNeeded * 100))))
	end

	self.wndToast = Apollo.LoadForm(self.xmlDoc, "ToastForm", nil, self)
	self.wndToast:SetData(contract)
	self.wndToast:FindChild("ToastQualityIcon"):SetSprite(ktContractQualityArt[contract:GetQuality()].strActive)
	self.wndToast:FindChild("ToastTypeIcon"):SetSprite(ktContractTypeArt[contract:GetQuest():GetSubType()].strActive)
	self.wndToast:FindChild("ToastComplete"):Show(contract:IsAchieved())
	self.wndToast:FindChild("ToastTitle"):SetText(queQuest:GetTitle())
	self.wndToast:FindChild("ToastSubtitle"):SetText(strSubtitle)
	self.wndToast:Invoke()

	local nTextWidth = (Apollo.GetTextWidth("CRB_Header9", queQuest:GetTitle()) + 250) / 2
	local nLeft, nTop, nRight, nBottom = self.wndToast:GetAnchorOffsets()
	local tLoc = WindowLocation.new({ fPoints = { 0.5, 0.5, 0.5, 0.5 }, nOffsets = { nTextWidth * (-1), nTop, nTextWidth, nBottom }})
	self.wndToast:TransitionMove(tLoc, 0.2)

	-- Timers
	self.timerToastAnim1 = ApolloTimer.Create(contract:IsAchieved() and 6 or 3, false, "OnToastAnim1", self)
	self.timerToastAnim1:Start()
end

function Contracts:OnToastAnim1()
	if not self.wndToast then
		return
	end
	self.wndToast:Show(false, 2)
end

function Contracts:OnToastFormMouseUp(wndHandler, wndControl)
	if wndHandler == wndControl and self.wndToast and self.wndToast:IsValid() then
		self.wndToast:Show(false)
		self:OpenContracts()
		
		local contract = wndControl:GetData()
		if contract:GetType() == ContractsLib.ContractType.Pvp then
			self.tWndRefs.wndPvPContractsBtn:SetCheck(true)
			self.tWndRefs.wndPvEContractsBtn:SetCheck(false)
			self:ShowPvPContracts(self.tWndRefs.wndPvPContractsBtn, self.tWndRefs.wndPvPContractsBtn)
			self:DrawContractOverview(self.tWndRefs.wndPvPContracts, contract)
		elseif contract:GetType() == ContractsLib.ContractType.Pve then
			self.tWndRefs.wndPvPContractsBtn:SetCheck(false)
			self.tWndRefs.wndPvEContractsBtn:SetCheck(true)
			self:ShowPvEContracts(self.tWndRefs.wndPvEContractsBtn, self.tWndRefs.wndPvEContractsBtn)
			self:DrawContractOverview(self.tWndRefs.wndPvEContracts, contract)
		end
		
	end
end

function Contracts:OnToastFormMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("ToastTitle") then
		wndHandler:FindChild("ToastTitle"):SetTextColor("UI_BtnTextBlueFlyby")
	end
end

function Contracts:OnToastFormMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("ToastTitle") then
		wndHandler:FindChild("ToastTitle"):SetTextColor("UI_BtnTextBlueNormal")
	end
end

function Contracts:ShowPvPContracts(wndHandler, wndControl, eMouseButton)
	if self.tWndRefs.wndPvPContractsBtn:IsChecked() then
		self.tWndRefs.wndPvPContracts:Show(true)
		self.tWndRefs.wndPvEContracts:Show(false)
		self.tWndRefs.wndPvEContracts:FindChild("RewardListOpenBtn:RewardList"):Show(false)
		self.tWndRefs.wndRefreshFlash:SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")

		local nProgressUnit = self.nCurrentRewardTrackProgress / self.nCurrentRewardTrackGoal
		local nProgressPossibleUnit = self.nCurrentRewardTrackPossibleProgress / self.nCurrentRewardTrackPossibleGoal
		
		local wndProgress = self.tWndRefs.wndPvPContracts:FindChild("RewardTrack:Progress")
		wndProgress:SetProgress(nProgressUnit * wndProgress:GetMax())
		wndProgress:SetProgress(wndProgress:GetData(), wndProgress:GetMax())
		
		self.nCurrentRewardTrackProgress = wndProgress:GetData()
		self.nCurrentRewardTrackGoal = wndProgress:GetMax()
		
		local wndActiveProgress = self.tWndRefs.wndPvPContracts:FindChild("RewardTrack:ActiveProgress")
		wndActiveProgress:SetProgress(nProgressPossibleUnit * wndActiveProgress:GetMax())
		wndActiveProgress:SetProgress(wndActiveProgress:GetData(), wndProgress:GetMax())
		
		self.nCurrentRewardTrackPossibleProgress = wndActiveProgress:GetData()
		self.nCurrentRewardTrackPossibleGoal = wndActiveProgress:GetMax()
	else
		return
	end
end

function Contracts:ShowPvEContracts(wndHandler, wndControl, eMouseButton)
	if self.tWndRefs.wndPvEContractsBtn:IsChecked() then
		self.tWndRefs.wndPvPContracts:Show(false)
		self.tWndRefs.wndPvEContracts:Show(true)
		self.tWndRefs.wndPvPContracts:FindChild("RewardListOpenBtn:RewardList"):Show(false)
		self.tWndRefs.wndRefreshFlash:SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
		
		local nProgressUnit = self.nCurrentRewardTrackProgress / self.nCurrentRewardTrackGoal
		local nProgressPossibleUnit = self.nCurrentRewardTrackPossibleProgress / self.nCurrentRewardTrackPossibleGoal
		
		local wndProgress = self.tWndRefs.wndPvEContracts:FindChild("RewardTrack:Progress")
		wndProgress:SetProgress(nProgressUnit * wndProgress:GetMax())
		wndProgress:SetProgress(wndProgress:GetData(), wndProgress:GetHeight() * 10)
		
		self.nCurrentRewardTrackProgress = wndProgress:GetData()
		self.nCurrentRewardTrackGoal = wndProgress:GetMax()
		
		local wndActiveProgress = self.tWndRefs.wndPvEContracts:FindChild("RewardTrack:ActiveProgress")
		wndActiveProgress:SetProgress(nProgressPossibleUnit * wndActiveProgress:GetMax())
		wndActiveProgress:SetProgress(wndActiveProgress:GetData(), wndActiveProgress:GetHeight() * 10)
		
		self.nCurrentRewardTrackPossibleProgress = wndActiveProgress:GetData()
		self.nCurrentRewardTrackPossibleGoal = wndActiveProgress:GetMax()
	else
		return
	end
end

function Contracts:OnRewardPointBtnSignal(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	tData.wndRewardList:Show(true)	
	tData.wndTooltip:Show(false)
	Sound.Play(Sound.PlayUIButtonHoloSmall)
	local wndContainer = tData.wndRewardList:FindChild("Container")
	for idx, wndRewardEntry in pairs(wndContainer:GetChildren()) do
		if tData.tReward.idReward == wndRewardEntry:GetData().tReward.idReward then
			wndRewardEntry:FindChild("SelectedHighlight"):Show(true)
			wndRewardEntry:FindChild("Flasher"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
			wndContainer:EnsureChildVisible(wndRewardEntry)
		else
			wndRewardEntry:FindChild("SelectedHighlight"):Show(false)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Reward confirm
---------------------------------------------------------------------------------------------------

function Contracts:OnRewardConfirmTakeBtnSignal(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	local tReward = tData.tReward
	local rtRewardTrack = tData.rtRewardTrack
	local nRewardIdx = tReward.nRewardIdx
	local nRewardItemChoiceIdx = tData.nChoiceIdx
	
	if nRewardIdx == rtRewardTrack:GetNumRewards() - 1 then
		Sound.Play(Sound.PlayUIContractGoldMilestoneTurnIn)
	else
		Sound.Play(Sound.PlayUIContractMilestoneTurnIn)
	end
	
	rtRewardTrack:ClaimRewardPoint(nRewardIdx, nRewardItemChoiceIdx)
end

function Contracts:OnRewardItemSelectionBtnCheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	local tClaimData = tData.wndRewardListClaimBtn:GetData()
	local tReward = tClaimData.tReward
	
	tClaimData.nChoiceIdx = tData.tItemChoice.nChoiceIdx
	tData.wndRewardListClaimBtn:SetData(tClaimData)
	tData.wndRewardListClaimBtn:Enable(tReward.bCanClaim and not tReward.bIsClaimed)
end

function Contracts:OnRewardItemSelectionBtnUncheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	tData.wndRewardListClaimBtn:Enable(false)
end

function Contracts:OnRewardListClose(wndHandler, wndControl)
	return true
end

---------------------------------------------------------------------------------------------------
-- Reward cash and item tooltips
---------------------------------------------------------------------------------------------------

function Contracts:OnGenerateRewardItemTooltip(wndHandler, wndControl, eToolTipType, x, y)
	local tData = wndControl:GetData()
	
	local tPrimaryTooltipOpts =
	{
		bPrimary = true,
		nStackCount = tData.nItemAmount,
		itemCompare = tData.itemReward:GetEquippedItemForItemType()
	}
	
	if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, tData.itemReward, tPrimaryTooltipOpts)
	end
end

function Contracts:OnGenerateCashRewardTooltip(wndHandler, wndControl, eToolTipType, monA, monB)
	if eToolTipType == Tooltip.TooltipGenerateType_Money then
		local xml = nil
		
		if monA:GetAmount() > 0 then
			if xml == nil then
				xml = XmlDoc.new()
			end
			xml:AddLine("<P>".. monA:GetMoneyString() .."</P>")
		end
		
		if monB:GetAmount() > 0 then
			if xml == nil then
				xml = XmlDoc.new()
			end
			xml:AddLine("<P>".. monB:GetMoneyString() .."</P>")
		end
		
		wndControl:SetTooltipDoc(xml)
	end
end


---------------------------------------------------------------------------------------------------
-- ActiveContract Functions
---------------------------------------------------------------------------------------------------

function Contracts:OnSelectBtnCheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	
	for idx, wndContract in pairs(tData.wndContainer:FindChild("AvailableContracts:ContractContainer"):GetChildren()) do	
		wndContract:FindChild("Container:SelectBtn"):SetCheck(tData.contract == wndContract:GetData())
	end
	
	for idx, wndContract in pairs(tData.wndContainer:FindChild("ActiveContracts:ActiveContractContainer"):GetChildren()) do		
		wndContract:FindChild("SelectBtn"):SetCheck(tData.contract == wndContract:GetData())
	end
	
	local wndContractOverview = tData.wndContainer:FindChild("ContractOverview")
	self:DrawContractOverview(wndContractOverview, tData.contract)
	wndContractOverview:FindChild("ContractSelected:RefreshFlash"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
	
	Sound.Play(Sound.PlayUIContractClickContract)
end

function Contracts:OnSelectBtnUncheck(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	
	for idx, wndContract in pairs(tData.wndContainer:FindChild("AvailableContracts:ContractContainer"):GetChildren()) do
		if tData.contract == wndContract:GetData() then
			wndContract:FindChild("Container:SelectBtn"):SetCheck(false)
			break
		end
	end
	
	for idx, wndContract in pairs(tData.wndContainer:FindChild("ActiveContracts:ActiveContractContainer"):GetChildren()) do
		if tData.contract == wndContract:GetData() then
			wndContract:FindChild("SelectBtn"):SetCheck(false)
			break
		end
	end
	
	local wndContractOverview = tData.wndContainer:FindChild("ContractOverview")
	self:DrawContractOverview(wndContractOverview, nil)
	wndContractOverview:FindChild("NoContractSelected:RefreshFlash"):SetSprite("BK3:UI_BK3_Holo_RefreshReflectionSquare_anim")
end

function Contracts:OnRewardListCloseBtnUncheck(wndHandler, wndControl, eMouseButton)
	wndControl:SetCheck(true)
	wndControl:GetData():Show(false)
	Sound.Play(Sound.PlayUIButtonMetalLarge)

end

---------------------------------------------------------------------------------------------------
-- RewardPoint Functions
---------------------------------------------------------------------------------------------------

function Contracts:OnRewardPointMouseEnter(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then
		return
	end

	local tActionData = wndControl:FindChild("ActionBtn"):GetData()
	
	local wndHighlightBG = wndControl:FindChild("RewardPointTooltip")
	wndHighlightBG:Show(not tActionData.wndRewardList:IsShown())
end


function Contracts:OnRewardPointMouseExit(wndHandler, wndControl, x, y)
	if wndHandler ~= wndControl then
		return
	end

	local wndHighlightBG = wndControl:FindChild("RewardPointTooltip")
	wndHighlightBG:Show(false)
end

local ContractsInst = Contracts:new()
ContractsInst:Init()

