-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "ChallengesLib"

local ChallengeLog = {}

function ChallengeLog:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ChallengeLog:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- ChallengeLog OnLoad
-----------------------------------------------------------------------------------------------

function ChallengeLog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ChallengeLog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ChallengeLog:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)

	Apollo.RegisterEventHandler("PL_ToggleChallengesWindow", 	"ToggleWindow", self)
	Apollo.RegisterEventHandler("PL_TabChanged", 				"OnCloseChallengeLogTab", self)
	Apollo.RegisterEventHandler("ChallengeShared", 				"OnChallengeShared", self)
	Apollo.RegisterEventHandler("ChallengeReward_SpinBegin", 	"OnChallengeReward_SpinBegin", self)
	Apollo.RegisterEventHandler("ChallengeReward_SpinEnd", 		"OnChallengeReward_SpinEnd", self) -- Track challenge reward wheel even if it hasn't been loaded yet
	
	self.tTimerAreaRestriction =
	{	
		[ChallengesLib.ChallengeType_Combat] 				= ApolloTimer.Create(1.0, false, "OnAreaRestrictionTimer", self),
		[ChallengesLib.ChallengeType_Ability] 				= ApolloTimer.Create(1.0, false, "OnAreaRestrictionTimer", self),
		[ChallengesLib.ChallengeType_General] 				= ApolloTimer.Create(1.0, false, "OnAreaRestrictionTimer", self),
		[ChallengesLib.ChallengeType_Item] 					= ApolloTimer.Create(1.0, false, "OnAreaRestrictionTimer", self),
		[ChallengesLib.ChallengeType_ChecklistActivate] 	= ApolloTimer.Create(1.0, false, "OnAreaRestrictionTimer", self)	
	}
	
	for idx, timerCur in pairs(self.tTimerAreaRestriction) do 
		timerCur:Stop()
	end

	self.timerChallengeLogDestroyWindows = ApolloTimer.Create(120.0, false, "ChallengeLogDestroyWindows", self)
	self.timerChallengeLogDestroyWindows:Stop()

	self.timerChallengeLogRedraw = ApolloTimer.Create(1.0, true, "Redraw", self)
	self.timerChallengeLogRedraw:Stop()

	self.timerMaxChallengeReward = ApolloTimer.Create(10.0, false, "OnChallengeReward_SpinEnd", self)	
	self.timerMaxChallengeReward:Stop()
	
	local wndTEMP1 = Apollo.LoadForm(self.xmlDoc, "ListItem", nil, self)
	self.knOrigItemLeft, self.knOrigItemTop, self.knOrigItemRight, self.knOrigItemBottom = wndTEMP1:GetAnchorOffsets()
	wndTEMP1:Destroy()

	local wndTEMP2 = Apollo.LoadForm(self.xmlDoc, "HeaderItem", nil, self)
	local nLeft, nTop, nRight, nBottom = wndTEMP2:GetAnchorOffsets()
    local nLeft2, nTop2, nRight2, nBottom2 = wndTEMP2:FindChild("HeaderContainer"):GetAnchorOffsets()

	self.knHeaderTopHeight = nBottom - nTop - (nBottom2 - nTop2) - 20
	wndTEMP2:Destroy()

	self.tFailMessagesList 		= {}
	self.bRewardWheelSpinning 	= false
	self.nSelectedBigZone 		= nil
	self.wndShowAllBigZone 		= nil
	self.nSelectedListItem 		= -1           -- keep track of which list item is currently selected

	self.wndMain = nil
	self.wndChallengeShare = nil
end

function ChallengeLog:OnInterfaceMenuListHasLoaded()
	local tData = { "ToggleChallengesWindow", "Challenges", "Icon_Windows32_UI_CRB_InterfaceMenu_ChallengeLog" }
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_ChallengeLog"), tData)
end

function ChallengeLog:ToggleWindow()
	self.timerChallengeLogDestroyWindows:Stop()
	if self.wndMain == nil then
		self:Initialize()
	end
	self.wndMain:Show(true)
	self.timerChallengeLogRedraw:Start()

end

function ChallengeLog:Initialize()
	Apollo.RegisterEventHandler("ChallengeCompleted", 			"OnChallengeCompleted", self)
	Apollo.RegisterEventHandler("ChallengeFailArea", 			"OnChallengeFail", self)
    Apollo.RegisterEventHandler("ChallengeFailTime", 			"OnChallengeFail", self)
	Apollo.RegisterEventHandler("ChallengeActivate", 			"OnChallengeActivate", self) -- This fires every time a challenge starts
	Apollo.RegisterEventHandler("ChallengeUpdate",				"Redraw", self)
	Apollo.RegisterEventHandler("ChallengeAreaRestriction", 	"OnChallengeAreaRestriction", self)

	self.timerChallengeLogRedraw:Start()

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ChallengeLogForm", g_wndProgressLog:FindChild("ContentWnd_3"), self)
    self.wndTopLevel = self.wndMain:FindChild("RightSide:ItemList")

	self.wndMain:FindChild("SortByDropdownBtn"):AttachWindow(self.wndMain:FindChild("SortByDropdownContainer"))

	local wndTopHeader = self.wndMain:FindChild("TopHeader")
	local wndSortByDropdownContainer = self.wndMain:FindChild("SortByDropdownContainer")
	self.strRewardsTabText = wndTopHeader:FindChild("ToggleRewardsBtn"):GetText()

    wndSortByDropdownContainer:FindChild("btnToggleType"):SetCheck(true)
    wndTopHeader:FindChild("ToggleShowAllBtn"):SetCheck(true)

	local wndInteractArea = self.wndMain:FindChild("RightSide:BGRightFooter:InteractArea")
	wndInteractArea:FindChild("StartChallengeBtn"):Enable(false)
	wndInteractArea:FindChild("RewardChallengeBtn"):Enable(false)
	wndInteractArea:FindChild("AbandonChallengeBtn"):Enable(false)

	self:Redraw()
end

function ChallengeLog:OnCloseChallengeLogTab()
	self.timerChallengeLogRedraw:Stop()
	self.timerChallengeLogDestroyWindows:Stop()
	self.timerChallengeLogDestroyWindows:Start()
end

function ChallengeLog:ChallengeLogDestroyWindows()
	self.timerChallengeLogDestroyWindows:Stop()
	self.tFailMessagesList = nil
	self:DestroyHeaderWindows()
	if self.wndMain ~= nil then
		self.wndMain:Show(false)
	end
end

function ChallengeLog:OnEditBoxChanged()
	--removes link to the last checked challenge
	self:DestroyHeaderWindows()
	self:Redraw()
end
-----------------------------------------------------------------------------------------------
-- ChallengeLog Main Redraw Method
-----------------------------------------------------------------------------------------------

-- Clicking a Header button and the timer also routes here
function ChallengeLog:Redraw()
    if not self.wndMain:IsShown() then
		return
	end

    -- Build Challenge List filtered by active vs cooldown vs completed
	local tFilteredChallenges = {}
	local tAllChallenges = ChallengesLib.GetActiveChallengeList()
	local wndTopHeader = self.wndMain:FindChild("TopHeader")

	-- This can be pulled out of redraw, this should happen on editboxchanging.
	-- Text searching
	wndTopHeader:FindChild("ClearSearchBtn"):Show(wndTopHeader:FindChild("HeaderSearchBox"):GetText() ~= "")

	local strSearchString = wndTopHeader:FindChild("HeaderSearchBox"):GetText():lower()
	if strSearchString and strSearchString ~= "" then

		for idx, clgCurrent in pairs(tAllChallenges) do
			local strChallengeName = clgCurrent:GetName():lower()
			local bResult = strChallengeName:find(" "..strSearchString, 1, true) or string.sub(strChallengeName, 0, string.len(strSearchString)) == strSearchString
			if bResult then
				tFilteredChallenges[idx] = clgCurrent
			end
        end
		tAllChallenges = tFilteredChallenges
		tFilteredChallenges = {}
	end


	self:AddShowAllToBigZoneList()
	if wndTopHeader:FindChild("ToggleShowAllBtn"):IsChecked() then
		for idx, clgCurrent in pairs(tAllChallenges) do
			local tZoneInfo = clgCurrent:GetZoneInfo()
			if self:BigZoneFilter(tZoneInfo) then
                tFilteredChallenges[idx] = clgCurrent
            end
			self:HandleBigZoneList(tAllChallenges, tZoneInfo)
        end
	elseif wndTopHeader:FindChild("ToggleRewardsBtn"):IsChecked() then
        for idx, clgCurrent in pairs(tAllChallenges) do
			local tZoneInfo = clgCurrent:GetZoneInfo()
			if clgCurrent:ShouldCollectReward() and self:BigZoneFilter(tZoneInfo) then
                tFilteredChallenges[idx] = clgCurrent
            end
			self:HandleBigZoneList(tAllChallenges, tZoneInfo)
        end
	elseif wndTopHeader:FindChild("ToggleCooldownBtn"):IsChecked() then
        for idx, clgCurrent in pairs(tAllChallenges) do
			local tZoneInfo = clgCurrent:GetZoneInfo()
            if clgCurrent:IsInCooldown() and self:BigZoneFilter(tZoneInfo) then
                tFilteredChallenges[idx] = clgCurrent
            end
			self:HandleBigZoneList(tAllChallenges, tZoneInfo)
        end
	elseif wndTopHeader:FindChild("ToggleReadyBtn"):IsChecked() then
		for idx, clgCurrent in pairs(tAllChallenges) do
			local tZoneInfo = clgCurrent:GetZoneInfo()
			if self:BigZoneFilter(tZoneInfo) then
				local bIsReady = false

				-- Show activated or challenges with rewards
				bIsReady = clgCurrent:IsActivated() or clgCurrent:ShouldCollectReward()
				-- or show challenges that can be started.
				bIsReady = bIsReady or (self:IsStartable(clgCurrent) and self:HelperIsInZone(clgCurrent:GetZoneRestrictionInfo()))
				-- filter out challenges that are on cooldown
				bIsReady = bIsReady and not clgCurrent:IsInCooldown()

				if bIsReady then
	                tFilteredChallenges[idx] = clgCurrent
				end
            end
			self:HandleBigZoneList(tAllChallenges, tZoneInfo)
        end
    end

	 -- If we weren't able to set the selection based on current zone then just pick "Show All"
	if self.nSelectedBigZone == nil then
		self.nSelectedBigZone = -1
		self:HelperPickBigZone(self.wndShowAllBigZone:FindChild("BigZoneBtn"))
	end

	self:DrawLeftPanelUI(tAllChallenges)
	self:DrawRightPanelUI(tFilteredChallenges)

	-- Deselect if nothing is selected
	if self.nSelectedListItem and self.nSelectedListItem == -1 then
		local wndWarningWindow = self.wndMain:FindChild("RightSide:WarningWindow")
		local wndInteractArea = self.wndMain:FindChild("RightSide:BGRightFooter:InteractArea")
		wndWarningWindow:Show(false)
		wndWarningWindow:FindChild("WarningTypeText"):Show(false)
		wndWarningWindow:FindChild("WarningZoneText"):Show(false)
		wndWarningWindow:FindChild("WarningEventText"):Show(false)
		wndInteractArea:FindChild("LocateChallengeBtn"):Show(false)
		wndInteractArea:FindChild("StartChallengeBtn"):Enable(false)
		wndInteractArea:FindChild("RewardChallengeBtn"):Enable(false)
		wndInteractArea:FindChild("AbandonChallengeBtn"):Enable(false)
	end

	-- Just exit if we have 0 challenges, we've already drawn the empty messages
    if tFilteredChallenges == nil or self:GetTableSize(tFilteredChallenges) == 0 then
		self:DestroyHeaderWindows()
	else
		self:BuildChallengeList(tFilteredChallenges)
	end
end

function ChallengeLog:BuildChallengeList(tFilteredChallenges)
	-- This is essentially step 2 of the Redraw() method, if we do have valid data to show
    local tChallengeListOfList = nil
    if self.wndMain:FindChild("SortByDropdownContainer:btnToggleZone"):IsChecked() then
        tChallengeListOfList = self:SetUpZoneList(tFilteredChallenges)
    elseif self.wndMain:FindChild("SortByDropdownContainer:btnToggleType"):IsChecked() then
        tChallengeListOfList = self:SetUpTypeList(tFilteredChallenges)
    end

    if not tChallengeListOfList or self:GetTableSize(tChallengeListOfList) == 0 then
		return
	end

	-- Draw headers in challenge list
    for strCurrId, value in pairs(tChallengeListOfList) do
		self:DrawHeader(strCurrId, tChallengeListOfList)
    end

    local nVScrollPos = self.wndTopLevel:GetVScrollPos() -- TODO: Refactor to not constantly destroy windows

	-- Draw items in headers
    for key, wndCurrHeader in pairs(self.wndTopLevel:GetChildren()) do
		local nHeight = 0
		local bDrawItemsInHeader = wndCurrHeader:FindChild("HeaderBtn"):IsChecked() and tChallengeListOfList[wndCurrHeader:GetData()]
		if bDrawItemsInHeader then
			nHeight = self:InsertHeaderChildren(wndCurrHeader:GetData(), wndCurrHeader, tChallengeListOfList)
        end
		wndCurrHeader:FindChild("HeaderContainer"):Show(bDrawItemsInHeader)
		self:SetHeaderSize(wndCurrHeader, nHeight, true)
    end

    self.wndTopLevel:ArrangeChildrenVert()
    self.wndTopLevel:SetVScrollPos(nVScrollPos)
end

function ChallengeLog:InsertHeaderChildren(nCurrTypeOrZoneId, wndCurrHeader, tList)
    local nTotalChildHeight = 0
	for key, clgCurrent in pairs(tList[nCurrTypeOrZoneId]) do
        if self:ShouldDraw(clgCurrent, nCurrTypeOrZoneId, wndCurrHeader) then
            local wndPanel = self:FetchPanel(clgCurrent, wndCurrHeader)
            if wndPanel == nil then
                wndPanel = self:NewPanel(wndCurrHeader:FindChild("HeaderContainer"), clgCurrent)
            end

            -- Draw contents, now that panel is found or created if nil
            nTotalChildHeight = nTotalChildHeight + self:DrawPanelContents(wndPanel, clgCurrent, tList)
        end
    end

	-- now all the header children are added, call ArrangeChildrenVert to list out the list items vertically
    self:SetHeaderSize(wndCurrHeader:FindChild("HeaderContainer"), nTotalChildHeight, false)
    wndCurrHeader:FindChild("HeaderContainer"):ArrangeChildrenVert()

    return nTotalChildHeight
end

function ChallengeLog:OnClearSearchBtn(wndHandler, wndControl)
	local wndTopHeader = self.wndMain:FindChild("TopHeader")
	wndTopHeader:FindChild("ClearSearchBtn"):Show(false)
	wndTopHeader:FindChild("HeaderSearchBox"):SetText("")
	wndTopHeader:FindChild("HeaderSearchBox"):ClearFocus()
	self:Redraw()
end

-----------------------------------------------------------------------------------------------
-- Our big main draw function for panel contents
-----------------------------------------------------------------------------------------------

-- Static
function ChallengeLog:DrawPanelContents(wndParent, clgBeingDrawn, tList)
	local idChallenge = clgBeingDrawn:GetId()
	local eChallengeType = clgBeingDrawn:GetType()
	local bActivated = clgBeingDrawn:IsActivated()
	local bIsInCooldown = clgBeingDrawn:IsInCooldown()
	local bCollectReward = clgBeingDrawn:ShouldCollectReward()
	local nCompletionCount = clgBeingDrawn:GetCompletionCount()
	local tZoneRestrictionInfo = clgBeingDrawn:GetZoneRestrictionInfo()
	local tStartLocationRestrictionId = clgBeingDrawn:GetStartLocationRestrictionId()

	local wndListItemBtn = wndParent:FindChild("ListItemBtn")
	local wndListItemLocation = wndListItemBtn:FindChild("ListItemLocation")
	local wndListItemTitle = wndListItemBtn:FindChild("ListItemTitle")
	wndListItemBtn:SetData(clgBeingDrawn)
	wndListItemLocation:SetText("")
	wndListItemTitle:SetText(clgBeingDrawn:GetName())
	wndListItemBtn:FindChild("ListItemTimerText"):SetText(clgBeingDrawn:GetTimeStr())
	wndListItemBtn:FindChild("ListItemTypeIcon"):SetSprite(self:CalculateIconPath(eChallengeType))

	-- Draw location if possible
	if tZoneRestrictionInfo.strSubZoneName and tZoneRestrictionInfo.strSubZoneName ~= "" and self.wndMain:FindChild("SortByDropdownContainer:btnToggleType"):IsChecked()then
		if tZoneRestrictionInfo.strLocationName and tZoneRestrictionInfo.strLocationName ~= "" then
			wndListItemLocation:SetText(tZoneRestrictionInfo.strSubZoneName .. " : " .. tZoneRestrictionInfo.strLocationName)
		else
			wndListItemLocation:SetText(tZoneRestrictionInfo.strSubZoneName)
		end
	end

	-- Change color if activated
	if self.tFailMessagesList and self.tFailMessagesList[idChallenge] then
		wndListItemTitle:SetTextColor(ApolloColor.new("ffff0000"))
		wndListItemTitle:SetText(self.tFailMessagesList[idChallenge])
	elseif bActivated then
        wndListItemTitle:SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
	else
		wndListItemTitle:SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
    end

	self:DrawTierInfo(wndParent, clgBeingDrawn)
	self:DrawWarningWindow(tList, clgBeingDrawn, idChallenge, eChallengeType, bActivated, bCollectReward, tZoneRestrictionInfo, tStartLocationRestrictionId)

	-- Should be redundant
	if self.nSelectedListItem and self.nSelectedListItem == idChallenge then
		wndListItemBtn:SetCheck(true)
	end

    -- Completed Challenges are disabled, unless lootable
    if not self:IsStartable(clgBeingDrawn) and not bCollectReward then
        wndListItemBtn:Enable(false)
    end

	-- Determine Status Icon
	-- Priority: Loot -> In Progress -> Failed -> Complete -> New
	local strStatusIconSprite = "kitIcon_New"
	if bCollectReward then
		strStatusIconSprite = "kitIcon_Loot"
	elseif bActivated then
		strStatusIconSprite = "kitIcon_InProgress"
	elseif self.tFailMessagesList and self.tFailMessagesList[idChallenge] then
		strStatusIconSprite = "kitIcon_NewDisabled"
	elseif nCompletionCount > 0 then
		strStatusIconSprite = "kitIcon_Complete"
	elseif bIsInCooldown then
		strStatusIconSprite = "kitIcon_NewDisabled" -- Repeated icon
	end
	wndListItemBtn:FindChild("ListItemStatusIconFrame:ListItemStatusPicture"):SetSprite(strStatusIconSprite)
	wndListItemBtn:FindChild("ListItemStatusExtraOrangeFrame"):Show(bCollectReward)

    -- Return the height. We sum this as we build.
    local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
	local nHeight = nBottom - nTop
    return nHeight
end

-- Draw tier info for the main panel
function ChallengeLog:DrawTierInfo(wndContainer, clgBeingDrawn)
	local strFontPathToUse = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\">"
	local strFontPathToUseRight = "<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\" Align=\"Right\">"
	local wndListItemDescription = wndContainer:FindChild("ListItemBtn:ListItemDescription")
	local wndDescriptionTieredObjective = wndContainer:FindChild("TierContainer:DescriptionTieredObjective")
	wndListItemDescription:SetAML(strFontPathToUse..clgBeingDrawn:GetDescription().."</P>")

	local tTierInfo = clgBeingDrawn:GetAllTierCounts()
	local nCurrentTier = clgBeingDrawn:GetDisplayTier()
	local nCurrentCount = clgBeingDrawn:GetCurrentCount()
	local nTotalCount = clgBeingDrawn:GetTotalCount()
	local bIsTimeTiered = clgBeingDrawn:IsTimeTiered()

	if tTierInfo == 0 or self:GetTableSize(tTierInfo) <= 1 then -- Not Tiered
		local strCurrentCount = nCurrentCount
		if clgBeingDrawn:GetCompletionCount() > 0 and not bActivated then
			strCurrentCount = nTotalCount
		end
		if nTotalCount == 100 then
			wndDescriptionTieredObjective:SetAML(string.format("%s0%%", strFontPathToUseRight))
		else
			wndDescriptionTieredObjective:SetAML(string.format("%s[%s/%s]", strFontPathToUseRight, strCurrentCount, nTotalCount))
		end

		-- Resize
		local nContentX, nContentY = wndListItemDescription:GetContentSize()
		local nOffsetY = 0
		if nContentY > 20 then
			nOffsetY = nContentY - 20 + 2 -- The +2 is for lower g-height
		end
        wndContainer:SetAnchorOffsets(self.knOrigItemLeft, self.knOrigItemTop, self.knOrigItemRight, self.knOrigItemBottom + math.min(900, nOffsetY))

		-- Move Objectives to where TierIcons would've been
		wndDescriptionTieredObjective:SetAnchorOffsets(-85, 34, -8, 0) -- TODO TEMP HACK: Super hardcoded formatting, replace with arrangehorz

	elseif self:GetTableSize(tTierInfo) > 1 then -- Tiered
        local strAppend = ""
		local nNumOfTiers = 0
        local nNumCompletedTiers = 0
		local bIsActivated = clgBeingDrawn:IsActivated()

		local wndTierIcons = wndContainer:FindChild("TierContainer:TierIcons")
		local wndBronzeIcon = wndTierIcons:FindChild("BronzeIcon")
		local wndSilverIcon = wndTierIcons:FindChild("SilverIcon")
		local wndGoldIcon = wndTierIcons:FindChild("GoldIcon")

		local nLastSize = 0
        for idx, tCurrTier in pairs(tTierInfo) do
            nNumOfTiers = nNumOfTiers + 1
			if nCurrentTier >= nNumOfTiers then
				nNumCompletedTiers = nNumCompletedTiers + 1
			end

			local nTierGoal = tCurrTier.nGoalCount
			if bIsTimeTiered then
				strNewLine = self:HelperConvertToTime(nTierGoal)
			elseif nTierGoal == 100 and idx == nNumCompletedTiers and not bIsActivated then
				strNewLine = String_GetWeaselString(Apollo.GetString("CRB_Percent"), nTierGoal)
			elseif nTierGoal == 100 and (idx - 1) == nNumCompletedTiers and bIsActivated then
				strNewLine = String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.min(nCurrentCount, nTierGoal))
			elseif nTierGoal == 100 then
				strNewLine = "<T TextColor=\"0\">.</T>"
			else
				strNewLine = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), math.min(nCurrentCount, nTierGoal), nTierGoal)
			end
			--each is a new line, so no need for string weasel
			strAppend = strAppend..strFontPathToUseRight..strNewLine.."</P>"
			wndDescriptionTieredObjective:SetAML(strAppend)

			-- Resize for medals -- TODO Refactor, can just load these as forms instead of moving them around
			local nTextWidth, nTextHeight = wndDescriptionTieredObjective:SetHeightToContentHeight()
			if idx == 1 then -- Bronze, we don't need to move
				nLastSize = nTextHeight -- don't need to subtract nLastSize here if it's lined up in xml
			elseif idx == 2 then -- Silver, go down 14 from the top from the bottom of the bronze
				local nBottomOfBronze = nLastSize
				wndSilverIcon:SetAnchorOffsets(0, nBottomOfBronze, 14, nBottomOfBronze + 14) -- TODO: Hardcode Medal Size at 14px
				nLastSize = nTextHeight - nLastSize
			elseif idx == 3 then -- Gold, go down 14 from the top from the bottom of the silver
				local nBottomOfSilver = nTextHeight - nLastSize
				wndGoldIcon:SetAnchorOffsets(0, nBottomOfSilver, 14, nBottomOfSilver + 14)
			end
        end

        wndBronzeIcon:Show(nNumOfTiers >= 1)
        wndSilverIcon:Show(nNumOfTiers >= 2)
        wndGoldIcon:Show(nNumOfTiers >= 3)
        wndBronzeIcon:FindChild("TierIconCheckmark"):Show(nNumCompletedTiers >= 1)
        wndSilverIcon:FindChild("TierIconCheckmark"):Show(nNumCompletedTiers >= 2)
        wndGoldIcon:FindChild("TierIconCheckmark"):Show(nNumCompletedTiers >= 3)

		-- Resize
		local nContentX, nContentY = wndDescriptionTieredObjective:GetContentSize()
		local nOffsetY = 0
		if nContentY > 20 then
			nOffsetY = nContentY - 20 + 2 -- The +2 is for lower g-height
		end
        wndContainer:SetAnchorOffsets(self.knOrigItemLeft, self.knOrigItemTop, self.knOrigItemRight, self.knOrigItemBottom + math.min(900, nOffsetY))
    end
end

function ChallengeLog:DrawWarningWindow(tList, clgCurrent, idChallenge, eChallengeType, bActivated, bCollectReward, tZoneRestrictionInfo, tStartLocation)
	local wndWarningWindow = self.wndMain:FindChild("RightSide:WarningWindow")
    if self.nSelectedListItem and self.nSelectedListItem == idChallenge then
		local wndInteractArea = self.wndMain:FindChild("RightSide:BGRightFooter:InteractArea")

		wndInteractArea:FindChild("AbandonChallengeBtn"):Enable(bActivated)
		-- Highest Priority is warning event text, don't overwride this until it fades naturally
		if not wndWarningWindow:FindChild("WarningEventText"):IsShown() then
			local bInZone = self:HelperIsInZone(tZoneRestrictionInfo)
			wndWarningWindow:FindChild("WarningZoneText"):Show(not bInZone)
			wndWarningWindow:FindChild("WarningTypeText"):Show(bInZone and self:HelperCurrentTypeAlreadyActive(tList, eChallengeType, idChallenge))
		end

		local bStartLocateValid = not bActivated and not clgCurrent:IsInCooldown() and not bCollectReward and self:IsStartable(clgCurrent)

		wndInteractArea:FindChild("RewardChallengeBtn"):Enable(bCollectReward and not self.bRewardWheelSpinning)
        wndInteractArea:FindChild("StartChallengeBtn"):Enable(bStartLocateValid and self:HelperIsInZone(tZoneRestrictionInfo))
		wndInteractArea:FindChild("LocateChallengeBtn"):Show(bStartLocateValid and (not self:HelperIsInZone(tZoneRestrictionInfo) or not self:HelperIsInLocation(tStartLocation)))
    end
	wndWarningWindow:Show(wndWarningWindow:FindChild("WarningTypeText"):IsShown()
												or wndWarningWindow:FindChild("WarningZoneText"):IsShown() or wndWarningWindow:FindChild("WarningEventText"):IsShown())
end

-----------------------------------------------------------------------------------------------
-- ChallengeLog List Drawing Functions
-----------------------------------------------------------------------------------------------

function ChallengeLog:DrawLeftPanelUI(tChallengeList)
	local tTempBZLoot = {}
	for key, clgCurrent in pairs(tChallengeList) do
		local tZoneInfo = clgCurrent:GetZoneInfo()
		if tZoneInfo and clgCurrent:ShouldCollectReward() then
			if tTempBZLoot[tZoneInfo.idZone] == nil then tTempBZLoot[tZoneInfo.idZone] = 0 end
			tTempBZLoot[tZoneInfo.idZone] = tTempBZLoot[tZoneInfo.idZone] + 1
		end
	end

	-- Show count of lootable challenges for the selected big zone, even if we have 0 challenges
	local nLootCount = 0
	local strRewardsText = self.strRewardsTabText
	for idx, clgCurrent in pairs(tChallengeList) do
		if clgCurrent:ShouldCollectReward() and (clgCurrent:GetZoneInfo().idZone == self.nSelectedBigZone or self.nSelectedBigZone == -1) then
			nLootCount = nLootCount + 1
			strRewardsText = String_GetWeaselString(Apollo.GetString("Vendor_TabLabelMultiple"), self.strRewardsTabText, nLootCount)
		end
	end
	self.wndMain:FindChild("TopHeader:ToggleRewardsBtn"):SetText(strRewardsText)
	self.wndMain:FindChild("LeftSide:BigZoneListContainer"):ArrangeChildrenVert(0)
end

function ChallengeLog:DrawRightPanelUI(tFilteredChallenges)
	local strEmptyListNotification = ""
	local bShowEmptyListWarning = tFilteredChallenges == nil or self:GetTableSize(tFilteredChallenges) == 0 and self.nSelectedBigZone ~= nil
	local wndTopHeader = self.wndMain:FindChild("TopHeader")
	local wndRightSide = self.wndMain:FindChild("RightSide")

	if bShowEmptyListWarning then
		if wndTopHeader:FindChild("ToggleShowAllBtn"):IsChecked() or wndTopHeader:FindChild("ToggleReadyBtn"):IsChecked() then
			strEmptyListNotification = Apollo.GetString("Challenges_FindNewChallenges")
		elseif wndTopHeader:FindChild("ToggleRewardsBtn"):IsChecked() and self.nSelectedBigZone == -1 then
			strEmptyListNotification = Apollo.GetString("Challenges_AllLooted")
		elseif wndTopHeader:FindChild("ToggleRewardsBtn"):IsChecked() then
			strEmptyListNotification = String_GetWeaselString(Apollo.GetString("Challenges_ZoneLooted"), wndRightSide:FindChild("ItemListZoneName"):GetText())
		elseif wndTopHeader:FindChild("ToggleCooldownBtn"):IsChecked() and self.nSelectedBigZone == -1 then
			strEmptyListNotification = Apollo.GetString("Challenges_NoCooldown")
		elseif wndTopHeader:FindChild("ToggleCooldownBtn"):IsChecked() then
			strEmptyListNotification = String_GetWeaselString(Apollo.GetString("Challenges_NoCDZone"), wndRightSide:FindChild("ItemListZoneName"):GetText())
		end
	end

	local wndEmptyListNotification = wndRightSide:FindChild("EmptyListNotification")
	wndEmptyListNotification:SetText(strEmptyListNotification)
	wndEmptyListNotification:FindChild("EmptyListNotificationBtn"):Show(bShowEmptyListWarning and not wndTopHeader:FindChild("ToggleShowAllBtn"):IsChecked())
	--wndRightSide:FindChild("ItemListZoneName"):Show(not bShowEmptyListWarning) -- Removed for now
end

-- Static
function ChallengeLog:DrawHeader(strCurrId, tChallengeListOfList)
	local wndResult = self.wndTopLevel:FindChildByUserData(strCurrId)
	if not wndResult then
		wndResult = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndTopLevel, self)
		wndResult:FindChild("HeaderBtn"):SetCheck(true)
	end
	wndResult:SetData(strCurrId)

	local strDesc = ""
	for key, clgCurrent in pairs(tChallengeListOfList[strCurrId]) do
        if self.wndMain:FindChild("SortByDropdownContainer:btnToggleZone"):IsChecked() then
			local strLocalHeader = clgCurrent:GetZoneRestrictionInfo().strSubZoneName
            if strLocalHeader == "" then
                strDesc = Apollo.GetString("Challenges_UnspecifiedArea")
            else
                strDesc = strLocalHeader
            end
            break
        else

			local tInfo =
			{
				["name"] = "",
				["count"] = 2  --Want "Combat Challenges", not "Combat Challenge"
			}

			local eChallengeType = clgCurrent:GetType()
            if eChallengeType == ChallengesLib.ChallengeType_Combat then
				tInfo["name"] = Apollo.GetString("Challenges_CombatChallenge")
            elseif eChallengeType == ChallengesLib.ChallengeType_Ability then
				tInfo["name"] = Apollo.GetString("Challenges_AbilityChallenge")
            elseif eChallengeType == ChallengesLib.ChallengeType_General then
				tInfo["name"] = Apollo.GetString("Challenges_GeneralChallenge")
            elseif eChallengeType == ChallengesLib.ChallengeType_Item then
				tInfo["name"] = Apollo.GetString("Challenges_ItemChallenge")
			elseif eChallengeType == ChallengesLib.ChallengeType_ChecklistActivate then
				tInfo["name"] = Apollo.GetString("Challenges_ActivateChallenge")
			end
			if tInfo["name"] ~= "" then
				strDesc = String_GetWeaselString(Apollo.GetString("CRB_MultipleNoNumber"), tInfo)
			end
			break
        end
    end
	wndResult:FindChild("HeaderBtnText"):SetText(strDesc)
end

-----------------------------------------------------------------------------------------------
-- ChallengeLog Simple UI Interaction
-----------------------------------------------------------------------------------------------

function ChallengeLog:OnBigZoneBtnPress(wndHandler, wndControl)
	if wndHandler ~= wndControl or not wndHandler then
		return
	end
	if wndHandler:GetData() ~= nil then
		self.nSelectedBigZone = wndHandler:GetData()
		self:DestroyHeaderWindows()
	end

	self:HelperPickBigZone(wndHandler)
end

function ChallengeLog:OnListItemClick(wndHandler, wndControl)
    if wndHandler ~= wndControl or not wndHandler:GetData() then
		return
	end
    if self.nSelectedListItem ~= nil and self.nSelectedListItem == wndHandler:GetData():GetId() then
        self.nSelectedListItem = -1 -- deselect
    else
        self.nSelectedListItem = wndHandler:GetData():GetId()
    end
end

function ChallengeLog:OnAbandonChallengeBtn()
	if self.nSelectedListItem ~= nil then
		ChallengesLib.AbandonChallenge(self.nSelectedListItem)
	end
end

function ChallengeLog:OnStartChallengeBtn()
	if not self.nSelectedListItem or self.nSelectedListItem == -1 then return end

	ChallengesLib.ShowHintArrow(self.nSelectedListItem)
	ChallengesLib.ActivateChallenge(self.nSelectedListItem)
	Event_FireGenericEvent("ChallengeLogStartBtn", self.nSelectedListItem)
end

function ChallengeLog:OnLocateChallengeBtn()
	if not self.nSelectedListItem or self.nSelectedListItem == -1 then return end
	ChallengesLib.ShowHintArrow(self.nSelectedListItem)
end

function ChallengeLog:OnRewardChallengeBtn() -- We need a generic event to get the tracker to close a loot window
    if self.nSelectedListItem ~= nil then
		Event_FireGenericEvent("ChallengeRewardShow", self.nSelectedListItem)
		-- Hackish. Loading from log in screen has the logic+ui slightly out of sync in terms of events, so simulate the events.
		self:OnChallengeCompleted(self.nSelectedListItem, nil, nil, nil)
		self:Redraw()
    end
end

function ChallengeLog:OnEmptyListNotificationBtn()
	local wndTopHeader = self.wndMain:FindChild("TopHeader")
	wndTopHeader:FindChild("ToggleShowAllBtn"):SetCheck(true)
	wndTopHeader:FindChild("ToggleRewardsBtn"):SetCheck(false)
	wndTopHeader:FindChild("ToggleCooldownBtn"):SetCheck(false)
	wndTopHeader:FindChild("ToggleReadyBtn"):SetCheck(false)


	-- Pick "Show All"
	self.nSelectedBigZone = -1
	self:HelperPickBigZone(self.wndShowAllBigZone:FindChild("BigZoneBtn"))
end

-----------------------------------------------------------------------------------------------
-- Events from Reward Wheel
-----------------------------------------------------------------------------------------------

function ChallengeLog:OnChallengeReward_SpinEnd()
	self.timerMaxChallengeReward:Stop()
	self.bRewardWheelSpinning = false
end

function ChallengeLog:OnChallengeReward_SpinBegin()
	self.timerMaxChallengeReward:Start()
	self.bRewardWheelSpinning = true
end

-----------------------------------------------------------------------------------------------
-- Events From Code
-----------------------------------------------------------------------------------------------

function ChallengeLog:OnChallengeActivate(clgChallenge)
	local nChallengeId = clgChallenge:GetId()
    if self.tFailMessagesList ~= nil and self.tFailMessagesList[nChallengeId] ~= nil then
		self.tFailMessagesList[nChallengeId] = nil -- Remove from red fail text list
    end
	self.tTimerAreaRestriction[clgChallenge:GetType()]:Stop()
end

function ChallengeLog:OnChallengeFail(clgFailed, strHeader, strDesc)
	local idChallenge = clgFailed:GetId()

	-- If the challenge completed with at least 1 tier complete, don't consider it a failure
	if clgFailed:GetDisplayTier() > 0 then
		return
	end

	if self.tFailMessagesList == nil then
		self.tFailMessagesList = {}
	end

	self.tFailMessagesList[idChallenge] = strHeader
end

function ChallengeLog:OnChallengeCompleted(idChallenge, strHeader, strDescription, fDuration)
	-- Destroy a victory (we don't want to redraw all headers as we'll lose scroll position, but self:Redraw() doesn't seem to work)
	for key, wndCurrHeader in pairs(self.wndTopLevel:GetChildren()) do
		if wndCurrHeader ~= nil then
			local wndPanel = wndCurrHeader:FindChild("HeaderContainer"):FindChild(idChallenge)
			if wndPanel ~= nil then
				wndPanel:Destroy()
			end
		end
	end
end

function ChallengeLog:OnChallengeAreaRestriction(idChallenge, strHeader, strDescription, fDuration)
	local wndWarningText = self.wndMain:FindChild("RightSide:WarningWindow:WarningEventText")
	wndWarningText:Show(true)
	wndWarningText:SetText(strDescription)
	for idx, clgCurrent in pairs(ChallengesLib.GetActiveChallengeList()) do
		if clgCurrent:GetId() == idChallenge then
			--can only have one active challenge per type
			local eType = clgCurrent:GetType()
			self.tTimerAreaRestriction[eType]:Set(fDuration, false)
			self.tTimerAreaRestriction[eType]:Start()
		end
	end
end

function ChallengeLog:OnAreaRestrictionTimer()
	self.wndMain:FindChild("RightSide:WarningWindow:WarningEventText"):Show(false)
end

-- The Top 3 Tabs and Type/Zone Btns Route Here
function ChallengeLog:DestroyAndRedraw()
	self:DestroyHeaderWindows()
	self:Redraw()
end

-----------------------------------------------------------------------------------------------
-- Challenge Sharing
-----------------------------------------------------------------------------------------------

function ChallengeLog:OnChallengeShared(nChallengeId)
	-- This event will not happen if auto accept is on (instead it'll just auto start a challenge)
	if self.wndChallengeShare and self.wndChallengeShare:IsValid() then
		return
	end

	self.wndChallengeShare =  Apollo.LoadForm(self.xmlDoc, "ShareChallengeNotice", nil, self)
	self.wndChallengeShare:SetData(nChallengeId)
	self.wndChallengeShare:Invoke()
end

function ChallengeLog:OnShareChallengeAccept(wndHandler, wndControl)
	ChallengesLib.AcceptSharedChallenge(self.wndChallengeShare:GetData())
	if self.wndChallengeShare:FindChild("AlwaysRejectCheck"):IsChecked() then
		Event_FireGenericEvent("ChallengeLog_UpdateShareChallengePreference", GameLib.SharedChallengePreference.AutoReject)
	end
	self.wndChallengeShare:Destroy()
	self.wndChallengeShare = nil
end

function ChallengeLog:OnShareChallengeClose() -- Can come from a variety of places
	if self.wndChallengeShare and self.wndChallengeShare:IsValid() then
		ChallengesLib.RejectSharedChallenge(self.wndChallengeShare:GetData())
		if self.wndChallengeShare:FindChild("AlwaysRejectCheck"):IsChecked() then
			Event_FireGenericEvent("ChallengeLog_UpdateShareChallengePreference", GameLib.SharedChallengePreference.AutoReject)
		end
		self.wndChallengeShare:Destroy()
		self.wndChallengeShare = nil
	end
end

-----------------------------------------------------------------------------------------------
-- ChallengeLog List Building Functions
-----------------------------------------------------------------------------------------------

function ChallengeLog:SetUpZoneList(tChalList)
    local tNewZoneList = {}
    for idx, clgCurrent in pairs(tChalList) do
		local tZoneRestrictionInfo = clgCurrent:GetZoneRestrictionInfo()
		if tZoneRestrictionInfo then
			if tNewZoneList[tZoneRestrictionInfo.idSubZone] == nil then
				-- Build the Deep Table
				local tNewTable = {}
				tNewTable[idx] = clgCurrent

				-- Insert the Table into the Top Table
				tNewZoneList[tZoneRestrictionInfo.idSubZone] = tNewTable
			else
				-- Open the Table within the Table, and set the deep value to Challenge
				local tOldTable = tNewZoneList[tZoneRestrictionInfo.idSubZone]
				tOldTable[idx] = clgCurrent
			end
		end
    end

    return tNewZoneList
end

-- Top List [Key: TypeId , Value: A Table]
-- Deep List [Key: ChallengeId , Value: A Challenge ]

function ChallengeLog:SetUpTypeList(tChallengeList)
    local tNewTypeList = {}
    for idx, clgCurrent in pairs(tChallengeList) do
		local eCurrentType = clgCurrent:GetType()
		if eCurrentType then
			if tNewTypeList[eCurrentType] == nil then
				-- Build the Deep Table
				local tNewTable = {}
				tNewTable[idx] = clgCurrent

				-- Insert the Table into the Top Table
				tNewTypeList[eCurrentType] = tNewTable
			else
				-- Open the Table within the Table, and set the deep value to Challenge
				local tOldTable = tNewTypeList[eCurrentType]
				tOldTable[idx] = clgCurrent
			end
		end
    end

    return tNewTypeList
end

-- Not Static, does logical manipulations that rely on UI states
function ChallengeLog:ShouldDraw(clgCurrent, nCurrTypeOrZoneId, wndCurrHeader)
    if not clgCurrent or not wndCurrHeader:FindChild("HeaderBtn"):IsChecked() then
		return false
	end

	local bResult = false
    if nCurrTypeOrZoneId == clgCurrent:GetType() and self.wndMain:FindChild("SortByDropdownContainer:btnToggleType"):IsChecked() then
        bResult = true
    elseif nCurrTypeOrZoneId == clgCurrent:GetZoneRestrictionInfo().idSubZone and self.wndMain:FindChild("SortByDropdownContainer:btnToggleZone"):IsChecked() then
        bResult = true
    end
    return bResult
end

function ChallengeLog:AddShowAllToBigZoneList()
	if not self.wndShowAllBigZone then
		self.wndShowAllBigZone = Apollo.LoadForm(self.xmlDoc, "BigZoneItem", self.wndMain:FindChild("LeftSide:BigZoneListContainer"), self)
		self.wndShowAllBigZone:SetName("-1")
		self.wndShowAllBigZone:SetData("All Zones")

		local wndBigZoneBtn = self.wndShowAllBigZone:FindChild("BigZoneBtn")
		wndBigZoneBtn:SetData(-1)
		wndBigZoneBtn:SetText(Apollo.GetString("Challenges_AllZones"))
	end
end

-- This is called for every challenge in a loop, so exit asap
function ChallengeLog:HandleBigZoneList(tTemp, tChallengeZoneInfo)
	if not tChallengeZoneInfo then
		return
	end

	local wndContainer = self.wndMain:FindChild("LeftSide:BigZoneListContainer")
	local wndNew = wndContainer:FindChildByUserData(tChallengeZoneInfo.idZone)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, "BigZoneItem", wndContainer, self)
	end

	-- Draw window
	wndNew:SetData(tChallengeZoneInfo.idZone)
	wndNew:SetName(tChallengeZoneInfo.idZone) -- We set the Name of Parent to ID, but the Data of the button to ID (for button click)

	local wndBigZoneBtn = wndNew:FindChild("BigZoneBtn")
	wndBigZoneBtn:SetData(tChallengeZoneInfo.idZone)
	wndBigZoneBtn:SetText(tChallengeZoneInfo.strZoneName)

	-- Click the big zone for the player if nothing is selected.
	if self.nSelectedBigZone == nil and GameLib.IsZoneInZone(GameLib.GetCurrentZoneId(), tChallengeZoneInfo.idZone) then
		self.nSelectedBigZone = tChallengeZoneInfo.idZone
		self:HelperPickBigZone(wndBigZoneBtn)
	end
end

-----------------------------------------------------------------------------------------------
-- ChallengeLogForm Helper Methods
-----------------------------------------------------------------------------------------------

function ChallengeLog:FetchPanel(clgCurrent, wndCurrHeader)
    local wndPanel = wndCurrHeader:FindChild("HeaderContainer"):FindChild(clgCurrent:GetId())
    return wndPanel
end

function ChallengeLog:HelperIsInZone(tZoneRestrictionInfo)
	return tZoneRestrictionInfo.idSubZone == 0 or GameLib.IsInWorldZone(tZoneRestrictionInfo.idSubZone)
end

function ChallengeLog:HelperIsInLocation(idLocation)
	return idLocation == 0 or GameLib.IsInLocation(idLocation)
end

function ChallengeLog:IsStartable(clgCurrent)
    return clgCurrent:GetCompletionCount() < clgCurrent:GetCompletionTotal() or clgCurrent:GetCompletionTotal() == -1
end

-- This method is only allowed to destroy header windows for a redraw (e.g. tab swap)
function ChallengeLog:DestroyHeaderWindows()
	if self.wndTopLevel ~= nil then
		self.wndTopLevel:DestroyChildren()
		self.wndTopLevel:RecalculateContentExtents()
	end

	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("SortByDropdownContainer"):Show(false)
	end

    self.nSelectedListItem = -1
end

-- This method is only allowed to do a loadform
function ChallengeLog:NewPanel(wndNew, clgCurrent)
    local wndParent = wndNew
    if wndParent == nil then
		wndParent = self.wndTopLevel
	end

    local wndResult = Apollo.LoadForm(self.xmlDoc, "ListItem", wndParent, self)
    wndResult:SetName(clgCurrent:GetId()) -- Hackish to help find challenge windows later
    wndResult:SetData(clgCurrent)
    return wndResult
end

-- This method is only allowed to set the height of a header with its children
function ChallengeLog:SetHeaderSize(wndHeader, nChildrenSize, bFactorHeaderTopHeight)
    -- nChildrenSize can be 0
    if self.knHeaderTopHeight == nil or nChildrenSize == nil then
		return
	end

    local nLeft, nTop, nRight, nBottom = wndHeader:GetAnchorOffsets()
    local nTopOfContainer = nTop
    if bFactorHeaderTopHeight == true then
        nTopOfContainer = nTopOfContainer + self.knHeaderTopHeight
    end
    local nBottomOfContainer = nTopOfContainer + nChildrenSize

    wndHeader:SetAnchorOffsets(nLeft, nTop, nRight, nBottomOfContainer)
    self.wndTopLevel:ArrangeChildrenVert()

    return nBottomOfContainer -- optional to use this
end

function ChallengeLog:GetTableSize(tArg)
    local nCounter = 0
    if tArg ~= nil then
        for key, value in pairs(tArg) do
            nCounter = nCounter + 1
        end
    end
    return nCounter
end

function ChallengeLog:CalculateIconPath(eType)
    local strIconPath = "CRB_GuildSprites:sprChallengeTypeGenericLarge"
	if eType == 0 then     -- Combat
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeKillLarge"
	elseif eType == 1 then -- Ability
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeSkillLarge"
	elseif eType == 2 then -- General
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeGenericLarge"
	elseif eType == 4 then -- Items
		strIconPath = "CRB_ChallengeTrackerSprites:sprChallengeTypeLootLarge"
	end
    return strIconPath
end

function ChallengeLog:HelperConvertToTime(nMilliseconds) -- nArg is passed in as 20000 for 20 seconds
	local strResult = ""
	local nInSeconds = math.floor(nMilliseconds / 1000)
	local nHours = string.format("%02.f", math.floor(nInSeconds / 3600))
	local nMins = string.format("%02.f", math.floor(nInSeconds / 60 - (nHours * 60)))
	local nSecs = string.format("%02.f", math.floor(nInSeconds - (nHours * 3600) - (nMins * 60)))

	if nHours ~= "00" then
		strResult = nHours .. ":"
	end
	return strResult .. nMins .. ":" .. nSecs -- Always show minutes and seconds
end

function ChallengeLog:BigZoneFilter(tArg)
	return (tArg and tArg.idZone == self.nSelectedBigZone) or self.nSelectedBigZone == -1
end

function ChallengeLog:HelperPickBigZone(wndArg) -- wndArg is a "BigZoneBtn"
	for key, wndCurr in pairs(self.wndMain:FindChild("LeftSide:BigZoneListContainer"):GetChildren()) do
		local wndBigZoneBtn = wndCurr:FindChild("BigZoneBtn")
		wndBigZoneBtn:SetCheck(false)
	end
	wndArg:SetCheck(true)
	self.wndMain:FindChild("RightSide:ItemListZoneName"):SetText(wndArg:GetText())
end

function ChallengeLog:HelperCurrentTypeAlreadyActive(tList, eChallengeType, idChallenge)
	local bResult = false
	for key, value in pairs(tList) do -- TODO Quick Hack. Expensive?
		for key2, clgCurrent in pairs(tList[key]) do
			if clgCurrent:IsActivated() and clgCurrent:GetType() == eChallengeType and clgCurrent:GetId() ~= idChallenge then
				return true
			end
		end
	end
end

local ChallengeLogInst = ChallengeLog:new()
ChallengeLogInst:Init()
