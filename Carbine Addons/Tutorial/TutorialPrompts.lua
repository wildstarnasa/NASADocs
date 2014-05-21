-----------------------------------------------------------------------------------------------
-- Client Lua Script for TutorialPrompts
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local TutorialPrompts = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- table of tutorial enums; values are the name of the component in the display, the anchor orientation, hOffset, vOffset, special
local kTutorialComponents =
{
	[GameLib.CodeEnumTutorialAnchor.None] 						= {"None", 					1,    0,   0},
	[GameLib.CodeEnumTutorialAnchor.Abilities] 					= {"Abilities", 			4, 	 30, 190},
	[GameLib.CodeEnumTutorialAnchor.Character] 					= {"Character Panel", 		8, -560,-450},
	[GameLib.CodeEnumTutorialAnchor.Mail] 						= {"Mail", 					4, 	 50,  65},
	[GameLib.CodeEnumTutorialAnchor.GalacticArchive] 			= {"Galactic Archive", 		8,  -40,-590},
	[GameLib.CodeEnumTutorialAnchor.Social] 					= {"Social Panel", 			4,  340,  20},
	[GameLib.CodeEnumTutorialAnchor.GroupFinder] 				= {"Group Finder", 			8, -50, -480},
	[GameLib.CodeEnumTutorialAnchor.AbilityBar] 				= {"Action Bar", 			4,  208, -10},
	[GameLib.CodeEnumTutorialAnchor.Codex] 						= {"Codex", 				8,  18,   22},
	[GameLib.CodeEnumTutorialAnchor.Challenge] 					= {"Challenges", 			2,  370,  -4},
	[GameLib.CodeEnumTutorialAnchor.Datachron] 					= {"Datachron", 			4,  -20, -30},
	[GameLib.CodeEnumTutorialAnchor.Inventory] 					= {"Inventory", 			4,   -2, -25},
	[GameLib.CodeEnumTutorialAnchor.MiniMap] 					= {"MiniMap", 				3,  -40,  -2},
	[GameLib.CodeEnumTutorialAnchor.QuestTracker] 				= {"Quest Tracker", 		4,   10,  -95, true},
	[GameLib.CodeEnumTutorialAnchor.HUDAlert] 					= {"HUD Alerts", 			5, -122, -20},
	[GameLib.CodeEnumTutorialAnchor.PressAndHold] 				= {"CSI: Press & Hold", 	5, -112, -24},
	[GameLib.CodeEnumTutorialAnchor.RapidTapping] 				= {"CSI: Rapid Tap", 		5, -112, -24},
	[GameLib.CodeEnumTutorialAnchor.PrecisionTapping] 			= {"CSI: Precision Tap",	5, -118, -20},
	[GameLib.CodeEnumTutorialAnchor.Memory] 					= {"CSI: Memory", 			5,    0,   0},
	[GameLib.CodeEnumTutorialAnchor.Keypad] 					= {"CSI: Keypad", 			5,    0,   0},
	[GameLib.CodeEnumTutorialAnchor.Metronome] 					= {"CSI: Metronome", 		5, -118, -20},
	[GameLib.CodeEnumTutorialAnchor.SprintMeter]				= {"Sprint Meter", 			4,    0,  20},
	[GameLib.CodeEnumTutorialAnchor.DashMeter]					= {"Dash Meter", 			4,    50, 10},
	[GameLib.CodeEnumTutorialAnchor.InnateAbility]				= {"Innate Ability", 		4,  138, -10},
	[GameLib.CodeEnumTutorialAnchor.ClassResource]				= {"Class Mechanic", 		5,  -40, 330},
	[GameLib.CodeEnumTutorialAnchor.BuffFrame]					= {"Buff Frame", 			4,  220, -30},
	[GameLib.CodeEnumTutorialAnchor.QuestCommunicatorReceived]	= {"Communicator Turn In", 	4,  -15,  -80, true},
	[GameLib.CodeEnumTutorialAnchor.HealthBar]					= {"Health Bar", 			4,   75, -10},
	[GameLib.CodeEnumTutorialAnchor.ShieldBar]					= {"Shield Bar", 			6,  -75, -10},
	[GameLib.CodeEnumTutorialAnchor.Recall]						= {"Recall", 				5,    7, -20},
}

local kstrDefaultLabel = Apollo.GetString("Tutorials_DefaultLabel")

function TutorialPrompts:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TutorialPrompts:Init()
    Apollo.RegisterAddon(self)
end


-----------------------------------------------------------------------------------------------
-- TutorialPrompts OnLoad
-----------------------------------------------------------------------------------------------
function TutorialPrompts:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TutorialPrompts.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TutorialPrompts:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	Apollo.RegisterSlashCommand("showtutorial", 					"OnSlashShowTutorial", self)
	Apollo.RegisterSlashCommand("TutorialPromptTest", 				"OnTutorialPromptTest", self)
	
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchorResponse", "DrawHintWindow", self)
	Apollo.RegisterEventHandler("ShowTutorial", 					"OnShowTutorial", self)
	Apollo.RegisterEventHandler("TutorialPlaybackEnded", 			"OnTutorialPlaybackEnded", self)

	-- Stun Events
	Apollo.RegisterEventHandler("ActivateCCStateStun", "OnActivateCCStateStun", self)
	Apollo.RegisterEventHandler("RemoveCCStateStun", "OnRemoveCCStateStun", self)

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "TutorialTesterForm", nil, self)
    self.wndMain:Show(false)

	self.wndAlertContainer = Apollo.LoadForm(self.xmlDoc, "AlertContainer", "FixedHudStratum", self)

	self.tComponentList = {}
	for keyEnum, valueTable in pairs(kTutorialComponents) do
		local wnd = Apollo.LoadForm(self.xmlDoc, "ComponentSelectBtn", self.wndMain:FindChild("TutorialComponentList"), self)
		wnd:SetData(keyEnum)
		wnd:SetText("    " .. valueTable[1])
		table.insert(self.tComponentList, wnd)
	end

	self.bAllViewSetting = false
	self.bTypeViewSetting = false

	--set up a default/min size
	local wndTempHint = Apollo.LoadForm(self.xmlDoc, "HintWindow", nil, self)
	self.tDefHintRec = {}
	self.tDefHintRec.l, self.tDefHintRec.t, self.tDefHintRec.r, self.tDefHintRec.b = wndTempHint:GetRect()
	self.tDefHintTextOffsets = {}
	self.tDefHintTextOffsets.l, self.tDefHintTextOffsets.t, self.tDefHintTextOffsets.r, self.tDefHintTextOffsets.b = wndTempHint:FindChild("HintTextWnd"):GetAnchorOffsets()
	wndTempHint:Destroy()

	self.wndMain:FindChild("TutorialComponentList"):ArrangeChildrenVert()

	-- TODO: Dangerous. This requires exact form naming.
	self.wndForms = {}
	for idx, tCurrLayout in ipairs(GameLib.GetTutorialLayouts()) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, tCurrLayout.strForm, nil, self)
		if wndCurr ~= nil then
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			local tData = 
			{
				nLeft = nLeft, 
				nTop = nTop, 
				nWidth = nRight - nLeft, 
				nHeight = nBottom - nTop
			}
			wndCurr:SetData(tData)
			wndCurr:Show(false, true)
			self.wndForms[tCurrLayout.nId] = wndCurr --8
		end
	end
	
	self.tAutoCloseTutorials = {}
	Apollo.RegisterTimerHandler("AutoCloseTutorial", "OnAutoCloseTutorialInterval", self)
	Apollo.CreateTimer("AutoCloseTutorial", 1.0, true)
	Apollo.StopTimer("AutoCloseTutorial")

	self.wndTransparentTutorial = nil
	self.tDisplayedPrompts = {}
	self.tPendingTutorials = {}

	self:OnResetAll()
	self:UpdatePending()
end

function TutorialPrompts:OnActivateCCStateStun()
	self.wndAlertContainer:Show(false)
end

function TutorialPrompts:OnRemoveCCStateStun()
	self.wndAlertContainer:Show(true)
end

function TutorialPrompts:UpdatePending()
	local tPending = GameLib.GetPendingTutorials()
	if tPending then
		for idx, tTutorial in pairs(tPending) do
			self:OnShowTutorial(tTutorial.nTutorialId)
		end
	end
end

function TutorialPrompts:OnSlashShowTutorial(strCommand, strArg1) -- TODO TEMP: Testing method until a Tutorial Shower window gets put in, for nroth
	if not strArg1 or string.len(strArg1) == 0 then return end

	self:OnShowTutorial(strArg1)
end

function TutorialPrompts:OnTutorialPlaybackEnded()
	-- audio playback ended; if the transparent type is shown, destroy it
	if self.wndTransparentTutorial ~= nil then
		self.wndTransparentTutorial:Close()
	end
end

-----------------------------------------------------------------------------------------------
-- TutorialPromptsForm Functions
-----------------------------------------------------------------------------------------------

function TutorialPrompts:OnShowTutorial(nTutorialId, bInstantPopUp, strPopupText, eAnchor)
	if nTutorialId == nil then
		return 
	end

	if GameLib.IsTutorialNoPageAlert(nTutorialId) == true then -- is it a no-page alert?
		if eAnchor ~= nil and eAnchor ~= GameLib.CodeEnumTutorialAnchor.None then  -- Hint Window check; it will draw on the return event
			Event_FireGenericEvent("Tutorial_RequestUIAnchor", eAnchor, nTutorialId, strPopupText)
		end
		return
	else
		if eAnchor ~= nil and eAnchor ~= GameLib.CodeEnumTutorialAnchor.None and strPopupText ~= nil then
			Event_FireGenericEvent("Tutorial_RequestUIAnchor", eAnchor, nTutorialId, strPopupText)
		end
	end

	local tTutorial = GameLib.GetTutorial(nTutorialId)  -- tTutorial is an array of tutorial tables. Whee!
	if tTutorial == nil then
		return
	end

	-- Instant, don't queue
	if bInstantPopUp == true or tTutorial[1].nLayoutId == 8 then
		GameLib.MarkTutorialViewed(nTutorialId, true)
		self:DrawTutorialPage(nTutorialId)
		return
	end

	table.insert(self.tPendingTutorials, nTutorialId)

	self:UpdateAlerts()
end

function TutorialPrompts:OnShowTutorialTest(nTutorialId, bInstantPopUp, strPopupText, eAnchor)

	if strPopupText ~= nil and strPopupText ~= "" and eAnchor ~= nil and eAnchor ~= GameLib.CodeEnumTutorialAnchor.None then  -- Hint Window check; it will draw on the return event
		Event_FireGenericEvent("Tutorial_RequestUIAnchor", eAnchor, nTutorialId, strPopupText)
		return
	end

	local tTutorial = GameLib.GetTutorial(nTutorialId)  -- tTutorial is an array of tutorial tables. Whee!
	if tTutorial == nil then
		return
	end

	-- Instant, don't queue
	if bInstantPopUp == true or tTutorial[1].nLayoutId == 8 then
		GameLib.MarkTutorialViewed(nTutorialId, true)
		self:DrawTutorialPage(nTutorialId)
		return
	end

	table.insert(self.tPendingTutorials, nTutorialId)

	self:UpdateAlerts()
end

function TutorialPrompts:OnAutoCloseTutorialInterval()
	for idx,wndTutorial in ipairs(self.tAutoCloseTutorials) do
		if wndTutorial:IsValid() then
			local wndTimer = wndTutorial:FindChild("Timer")
			if wndTimer:GetData() == 0 then --1 second left
				wndTutorial:Show(false)
				table.remove(self.tAutoCloseTutorials, idx)
			else
				local nTimeLeft = wndTimer:GetData() - 1
				 wndTimer:SetData(nTimeLeft)
				 
				 if nTimeLeft <= 10 then --display a timer when auto closing will complete
					wndTimer:SetText(nTimeLeft)
				end
			end
		else
			table.remove(self.tAutoCloseTutorials, idx)
		end
	end
	
	if #self.tAutoCloseTutorials == 0 then
		Apollo.StopTimer("AutoCloseTutorial")
		self.wndAlertContainer:DestroyChildren()
	end
end

function TutorialPrompts:AddAutoCloseTutorial(wndTutorial)
	wndTutorial:FindChild("Timer"):SetData(30) --#of seconds to count down from.
	
	--timer stops if the count is 0. We're about to add one so restart it.
	if #self.tAutoCloseTutorials == 0 then
		Apollo.StartTimer("AutoCloseTutorial")
	end
	
	table.insert(self.tAutoCloseTutorials, wndTutorial)
end

function TutorialPrompts:UpdateAlerts()

	self.wndAlertContainer:DestroyChildren()

	if #self.tPendingTutorials > 5 then
		local wndMore = Apollo.LoadForm(self.xmlDoc, "TutorialAlertMore", self.wndAlertContainer, self)
		wndMore:Show(true)
		--wndMore:FindChild("TransitionSprite"):SetSprite("sprWinAnim_BirthSmallTemp")
	end

	for i = 1, 5 do
		if self.tPendingTutorials[i] ~= nil then
			local tTutorial = GameLib.GetTutorial(self.tPendingTutorials[i])
			local wnd = Apollo.LoadForm(self.xmlDoc, "TutorialAlert", self.wndAlertContainer, self)
			wnd:SetData(self.tPendingTutorials[i])
			wnd:FindChild("TutorialAlertBtn"):SetData(self.tPendingTutorials[i])
			wnd:SetTooltip(String_GetWeaselString(Apollo.GetString("Tutorials_ClickToLearn"), tTutorial[1].strTitle))
			wnd:Show(true)
			wnd:FindChild("IconHoverGlow"):Show(false, true)
			if #self.tPendingTutorials <= 5 then
				--wnd:FindChild("TransitionSprite"):SetSprite("sprWinAnim_BirthSmallTemp")
			end
			
			self:AddAutoCloseTutorial(wnd)
		end
	end

	self.wndAlertContainer:ArrangeChildrenHorz(2)
end

function TutorialPrompts:DrawHintWindow(eAnchor, nTutorialId, strPopupText, tRect)
	if self.tDisplayedPrompts[eAnchor] ~= nil then
		self.tDisplayedPrompts[eAnchor]:Destroy()
		self.tDisplayedPrompts[eAnchor] = nil
	end

	-- Early out for incomplete tutorial
	if eAnchor == nil or nTutorialId == nil or tRect == nil or strPopupText == nil or strPopupText == "" then return false end

	local wnd = Apollo.LoadForm(self.xmlDoc, "HintWindow", "TooltipStratum", self)
	wnd:SetData(eAnchor)

	local tTutorial	 = GameLib.GetTutorial(nTutorialId)

	if tTutorial ~= nil then
		wnd:FindChild("PanelToggleContainer"):Show(true)
		wnd:FindChild("PanelToggleContainer"):FindChild("HintAlertBtn"):Show(false, true)
		wnd:FindChild("HintAlertPrompt"):SetData(nTutorialId)
		wnd:FindChild("HintAlertBtn"):SetData(nTutorialId)
	else
		wnd:FindChild("PanelToggleContainer"):Show(false)
		GameLib.MarkTutorialViewed(nTutorialId, true)
	end

	wnd:FindChild("BGArt_Prompt"):Show(tTutorial ~= nil)
	wnd:FindChild("BGArt_NoPrompt"):Show(tTutorial == nil)

	-- Crazy resize time!
	local wndText = wnd:FindChild("HintTextWnd")
	wndText:SetText(strPopupText)
	wndText:SetHeightToContentHeight()
	local lText, tText, rText, bText = wndText:GetAnchorOffsets()
	local nTextHeight = bText-tText

	if nTextHeight < (self.tDefHintTextOffsets.b - self.tDefHintTextOffsets.t) then -- smaller than default box size;don't resize the frame, just center the text
		local nWndHeight = self.tDefHintRec.b - self.tDefHintRec.t
		wndText:SetAnchorOffsets(lText, (nWndHeight/2)-(nTextHeight/2), rText, (nWndHeight/2)+(nTextHeight/2))
	else
		wnd:SetAnchorOffsets(self.tDefHintRec.l, self.tDefHintRec.t, self.tDefHintRec.r, bText + (self.tDefHintRec.b-self.tDefHintTextOffsets.b))
	end

	-- Show the right connector
	for i = 1, 8 do
		wnd:FindChild("ConnectorContainer"):FindChild("Connector" .. i):Show(i == kTutorialComponents[eAnchor][2])
	end

	-- Time to boogie:
	if kTutorialComponents[eAnchor] == nil then return false end

	local lSized, tSized, rSized, bSized = wnd:GetRect()
	local nSizedWidth = rSized-lSized
	local nSizedHeight = bSized-tSized
	local tEntry = kTutorialComponents[eAnchor]

	-- The time indicates the UI's position, not the tutorial hint's
	if tEntry[2] == 1 then -- noon
		wnd:Move((tRect.r-tRect.l)/2 + tEntry[3], tRect.b + tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 2 then -- 1:30
		wnd:Move(tRect.l - nSizedWidth + tEntry[3], tRect.b + tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 3 then -- 3:00
		wnd:Move(tRect.l - nSizedWidth + tEntry[3], (tRect.t + (tRect.b-tRect.t)/2)-nSizedHeight/2+ tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 4 then -- 4:30
		if tEntry[5] ~= true then -- top of a UI
			wnd:Move(tRect.l - nSizedWidth + tEntry[3], tRect.t - nSizedHeight + tEntry[4], nSizedWidth, nSizedHeight)
		else -- bottom of a UI
			wnd:Move(tRect.l - nSizedWidth + tEntry[3], tRect.b - nSizedHeight + tEntry[4], nSizedWidth, nSizedHeight)
		end
	elseif tEntry[2] == 5 then -- 6:00
		wnd:Move(tRect.l+((tRect.r-tRect.l)/2) - (nSizedWidth/2) + tEntry[3], tRect.t - nSizedHeight + tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 6 then -- 7:30
		wnd:Move(tRect.r + tEntry[3], tRect.t - nSizedHeight + tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 7 then -- 9:00
		wnd:Move(tRect.r + tEntry[3], tRect.t+((tRect.b-tRect.t)/2)-nSizedHeight/2 + tEntry[4], nSizedWidth, nSizedHeight)
	elseif tEntry[2] == 8 then -- 10:30
		wnd:Move(tRect.r + tEntry[3], tRect.b + tEntry[4], nSizedWidth, nSizedHeight)
	else  -- no idea, use noon
		wnd:Move((tRect.r-tRect.l)/2 + tEntry[3], tRect.b + tEntry[4], nSizedWidth, nSizedHeight)
	end

	local posL, posT, posR, posB = wnd:GetRect()
	
	self:AddAutoCloseTutorial(wnd)
	wnd:Show(true)
	self.tDisplayedPrompts[eAnchor] = wnd
end

---------------------------------------------------------------------------------------------------
-- Alert Functions
---------------------------------------------------------------------------------------------------
function TutorialPrompts:OnTutorialMoreBtn(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_OpenTutorialMenu")
end

function TutorialPrompts:OnTutorialAlertBtn(wndHandler, wndControl)
	-- on click, advance the table by one, remove the last, redraw alerts, remove any prompts
	local nId = wndControl:GetData()

	if nId == nil or wndHandler ~= wndControl then
		return
	end

	self:DrawTutorialPage(nId)
	GameLib.MarkTutorialViewed(nId, true)

	for idx, wnd in pairs(self.tDisplayedPrompts) do
		if wnd:FindChild("HintAlertBtn"):GetData() == nId then
			wnd:Destroy()
			self.tDisplayedPrompts[idx] = nil
		end
	end

	for _, wndAlert in pairs(self.wndAlertContainer:GetChildren()) do
		if wndAlert:GetData() == nId then
			wndAlert:Destroy()
		end
	end

	local nEntryToPull = nil
	for idx, nEntry in pairs(self.tPendingTutorials) do -- idx is i-sequenced, v is the nId
		if nEntry == nId then
			self:RemoveAlert(idx)
		end
	end
end

function TutorialPrompts:RemoveAlert(nStartIdx)
	if nStartIdx == nil then
		return
	end

	for idx = nStartIdx, #self.tPendingTutorials do
		if self.tPendingTutorials[idx + 1] ~= nil then
			self.tPendingTutorials[idx] = self.tPendingTutorials[idx + 1]
		end
	end

	self.tPendingTutorials[#self.tPendingTutorials] = nil

	self:UpdateAlerts()
end

---------------------------------------------------------------------------------------------------
-- HintWindow Functions
---------------------------------------------------------------------------------------------------
function TutorialPrompts:OnCloseHintWindow(wndHandler, wndControl)

	if wndHandler ~= wndControl then return false end
	local wndParent = wndControl:GetParent():GetParent()
	local nEnum = wndControl:GetParent():GetParent():GetData()

	if wndParent:FindChild("PanelToggleContainer"):IsShown() then
		local idx = wndParent:FindChild("HintAlertBtn"):GetData()
		self:RemoveAlert(idx)
		GameLib.MarkTutorialViewed(idx, true)
	end

	for idx, wnd in pairs(self.tDisplayedPrompts) do
		if wnd:GetData() == nEnum then
			wnd:Destroy()
			self.tDisplayedPrompts[idx] = nil
		end
	end
end

function TutorialPrompts:OnHintMouseEnter(wndHandler, wndControl)
	if wndHandler ~= wndControl then return false end
	wndControl:FindChild("Overlay"):Show(true)
	wndControl:FindChild("HintAlertBtn"):Show(true)
end

function TutorialPrompts:OnHintMouseExit(wndHandler, wndControl)
	if wndHandler ~= wndControl then return false end
	wndControl:FindChild("Overlay"):Show(false)
	wndControl:FindChild("HintAlertBtn"):Show(false)
end

function TutorialPrompts:OnHoverGlowMouseEnter(wndHandler, wndControl)
	--[[if wndHandler:FindChild("IconHoverGlow") then
		wndHandler:FindChild("IconHoverGlow"):Show(true)
	end	--]]
end

function TutorialPrompts:OnHoverGlowMouseExit(wndHandler, wndControl)
	--[[if wndHandler:FindChild("IconHoverGlow") then
		wndHandler:FindChild("IconHoverGlow"):Show(false, true)
	end	--]]
end

---------------------------------------------------------------------------------------------------
-- Tutorial Panel Functions
---------------------------------------------------------------------------------------------------
function TutorialPrompts:DrawTutorialPage(nTutorialId, nPassedPage) --(wndArg, nCurrPage, tTutorial, nTutorialId)

	GameLib.StopTutorialSound() -- Stops any sounds currently being played by the Tutorial system

	for idx, wnd in pairs(self.wndForms) do
		wnd:Show(false)
	end

	self.wndTransparentTutorial = nil

	local tTutorial = GameLib.GetTutorial(nTutorialId)
	local nCurrPage = nPassedPage or 1

	if tTutorial == nil then return false end

	local wnd = self.wndForms[tTutorial[nCurrPage].nLayoutId]

	if wnd == nil then return false end

	if tTutorial[nCurrPage].nLayoutId == 8 then -- TODO: REALLY DICEY; we're hardcoding the value for "transparent"
		self:DrawTransparentTutorialPage(nTutorialId, nPassedPage)
		return
	end

	-- Reset before updating
	wnd:FindChild("Body"):Show(false)
	wnd:FindChild("BodyFrameBG"):Show(false)
	if wnd:FindChild("BodyLeft") and wnd:FindChild("BodyRight") then
		wnd:FindChild("BodyLeft"):Show(false)
		wnd:FindChild("BodyRight"):Show(false)
	end

	wnd:FindChild("SpriteContainer"):Show(false)
	if wnd:FindChild("SpriteContainerLeft") and wnd:FindChild("SpriteContainerRight") then
		wnd:FindChild("SpriteContainerLeft"):Show(false)
		wnd:FindChild("SpriteContainerRight"):Show(false)
	end

	-- Set the "view" toggle for the tutorial's category (carrying the option for additional pages)
	if wnd:FindChild("HideCategoryBtn") ~= nil then
		local nType = tTutorial.eTutorialCategory
		if nCurrPage == 1 then -- get the setting from page 1
			self.bTypeViewSetting = not GameLib.IsTutorialCategoryVisible(nType)
		end

		wnd:FindChild("HideCategoryBtn"):SetData(nType)
		wnd:FindChild("HideCategoryBtn"):SetCheck(self.bTypeViewSetting)
	end


	-- Figure out to show just the body/sprite or if we need to show bodyleft and bodyright
	local nOnGoingHeight = 0
	for idx, strCurrText in ipairs(tTutorial[nCurrPage].tBody) do
		local wndToDo = nil
		local bStrCurrTextExists = strCurrText and string.len(strCurrText) > 0
		local strAsAML = "<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\" Align=\"Left\">"..strCurrText.."</P>"

		if idx == 1 and bStrCurrTextExists then
			wnd:FindChild("Body"):Show(true)
			wnd:FindChild("BodyFrameBG"):Show(true)
			wnd:FindChild("Body"):SetAML(strAsAML)

			if wnd:GetName() ~= "TutorialForm_ExtraLarge" then
				local nWidth, nHeight = wnd:FindChild("Body"):SetHeightToContentHeight()
				nOnGoingHeight = math.max(42, nHeight + 20) -- Guarantee at least two lines of height
			end
		elseif idx == 2 and wnd:FindChild("BodyLeft") and bStrCurrTextExists then
			wnd:FindChild("BodyLeft"):Show(true)
			wnd:FindChild("BodyLeft"):SetAML(strAsAML)
		elseif idx == 3 and wnd:FindChild("BodyRight") and bStrCurrTextExists then
			wnd:FindChild("BodyRight"):Show(true)
			wnd:FindChild("BodyRight"):SetAML(strAsAML)
		end
	end

	for idx, strCurrSprite in ipairs(tTutorial[nCurrPage].tSprites) do
		local bStrCurrSpriteExists = strCurrSprite and string.len(strCurrSprite) > 0
		if idx == 1 and bStrCurrSpriteExists then
			wnd:FindChild("SpriteContainer"):Show(true)
			wnd:FindChild("Sprite"):SetSprite(strCurrSprite)
		elseif idx == 2 and wnd:FindChild("SpriteContainerLeft") and bStrCurrSpriteExists then
			wnd:FindChild("SpriteContainerLeft"):Show(true)
			wnd:FindChild("SpriteLeft"):SetSprite(strCurrSprite)
		elseif idx == 3 and wnd:FindChild("SpriteContainerRight") and bStrCurrSpriteExists then
			wnd:FindChild("SpriteContainerRight"):Show(true)
			wnd:FindChild("SpriteRight"):SetSprite(strCurrSprite)
		end
	end

	-- Top title
	if #tTutorial > 1 then
		wnd:FindChild("Title"):SetText(String_GetWeaselString(Apollo.GetString("Tutorials_CurrentPage"), nCurrPage, #tTutorial, tTutorial[nCurrPage].strTitle))
	else
		wnd:FindChild("Title"):SetText(tTutorial[nCurrPage].strTitle)
	end

	-- Configure buttons
	if #tTutorial > 1 then -- multipage
		wnd:FindChild("btnNext"):Show(true)
		wnd:FindChild("btnPrevious"):Show(true)
		wnd:FindChild("btnPrevious"):Enable(nCurrPage ~= 1)
		wnd:FindChild("btnCloseBig"):Show(false)
		wnd:FindChild("btnNext"):SetData({ nCurrPage, tTutorial, nTutorialId } )
		wnd:FindChild("btnPrevious"):SetData({ nCurrPage, tTutorial, nTutorialId } )
		if nCurrPage >= #tTutorial then
			wnd:FindChild("btnNext"):SetText(Apollo.GetString("Tutorials_Finish"))
		else
			wnd:FindChild("btnNext"):SetText(Apollo.GetString("Tutorials_NextPage"))
		end
	else
		wnd:FindChild("btnNext"):Show(false)
		wnd:FindChild("btnPrevious"):Show(false)
		wnd:FindChild("btnCloseBig"):Show(true)
	end
	
	self.btnNextIsShown = wnd:FindChild("btnNext"):IsShown()

	-- TODO: Refactor this resize code. Also verify if it even works.
	if tTutorial[nCurrPage].wndRel then
		local nRelX, nRelY = TutorialLib.GetPos(tTutorial[nCurrPage].wndRel, tTutorial[nCurrPage].relPos)
		local nOffsetX, nOffsetY = tTutorial[nCurrPage].spacing, tTutorial[nCurrPage].spacing

		local nCompH = TutorialLib.PosCompareHoriz(tTutorial[nCurrPage].tutorialPos, tTutorial[nCurrPage].relPos)
		if nCompH < 0 then
			nOffsetX = -nOffsetX
		elseif nCompH == 0 then
			nOffsetX = 0
		end

		local nCompV = TutorialLib.PosCompareVert(tTutorial[nCurrPage].tutorialPos, tTutorial[nCurrPage].relPos)
		if nCompV < 0 then
			nOffsetY = -nOffsetY
		elseif nCompV == 0 then
			nOffsetY = 0
		end

		local nNewX, nNewY = TutorialLib.AlignPos(wnd, tTutorial[nCurrPage].tutorialPos, nRelX, nRelY, nOffsetX, nOffsetY)
		wnd:Move(nNewX, nNewY, wnd:GetWidth(), wnd:GetHeight())
	end

	-- Resize
	local tDefaultDimensions = wnd:GetData()
	local nLeft = tDefaultDimensions.nLeft
	local nTop = tDefaultDimensions.nTop
	local nWidth = tDefaultDimensions.nWidth +  nLeft
	local nHeight = tDefaultDimensions.nHeight +  nTop+ nOnGoingHeight
	wnd:SetAnchorOffsets(nLeft, nTop,  nWidth, nHeight)

	-- Play Sound
	if GameLib.HasTutorialSound(nTutorialId, nPassedPage) == true then
		GameLib.PlayTutorialSound(nTutorialId, nPassedPage)
		-- set data
	end

	wnd:Show(true)
	wnd:ToFront()
end

function TutorialPrompts:OnWindowMove(wndHandler, wndControl)

local tWndData = wndHandler:GetData()
local nLeft, nTop = wndHandler:GetAnchorOffsets()
tWndData.nLeft = nLeft
tWndData.nTop = nTop
wndHandler:SetData(tWndData)--saving left and top, windows width and height doesn't change while moving

end
--------------------------------------------------------------------------------------------
-- Custom function for transparent tutorials; these only have 1 page and should have a sound
function TutorialPrompts:DrawTransparentTutorialPage(nTutorialId, nPassedPage)

	local tTutorial = GameLib.GetTutorial(nTutorialId)
	local nCurrPage = nPassedPage or 1
	self.wndTransparentTutorial = self.wndForms[tTutorial[nCurrPage].nLayoutId]

	-- should only ever have 1 sprite
	for idx, strCurrSprite in ipairs(tTutorial[nCurrPage].tSprites) do
		local bStrCurrSpriteExists = strCurrSprite and string.len(strCurrSprite) > 0
		if idx == 1 and bStrCurrSpriteExists then
			self.wndTransparentTutorial:FindChild("Sprite"):SetSprite(strCurrSprite)
		end
	end

	-- Play Sound
	if GameLib.HasTutorialSound(nTutorialId, nPassedPage) == true then
		GameLib.PlayTutorialSound(nTutorialId, nPassedPage)
	end

	self.wndTransparentTutorial:Show(true)
	self.wndTransparentTutorial:ToFront()
end


--------------------------------------------------------------------------------------------
function TutorialPrompts:OnClose(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end -- wndHandler is 'btnClose'
	
	if self.bAllViewSetting then
		Event_FireGenericEvent("HideAllTutorials")
	end
	
	wndControl:GetParent():Close()
	GameLib.StopTutorialSound()
end

function TutorialPrompts:OnTransparentWindowClose(wndHandler, wndControl)
	if self.wndTransparentTutorial ~= nil then
		self.wndTransparentTutorial = nil
	end
	GameLib.StopTutorialSound()
end

function TutorialPrompts:OnTutorialWindowClosed(wndHandler, wndControl)
	GameLib.StopTutorialSound()

	if wndControl:FindChild("HideCategoryBtn") == nil then return end

	-- check the current setting for hiding the category and adjust if needed
	local nType = wndControl:FindChild("HideCategoryBtn"):GetData()
	if nType ~= nil and (GameLib.IsTutorialCategoryVisible(nType) == wndControl:FindChild("HideCategoryBtn"):IsChecked() or wndControl:FindChild("HideAllBtn"):IsChecked()) then
		GameLib.ToggleTutorialVisibilityFlags(nType)
	end
end

function TutorialPrompts:ShowNext(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then return end -- wndHandler is 'btnNext' and its data is { nCurrPage, tTutorial, nTutorialId }
	
	if self.bAllViewSetting then
		Event_FireGenericEvent("HideAllTutorials")
		wndHandler:GetParent():Close()
	end

	local nCurrPage = wndHandler:GetData()[1]
	local tTutorial = wndHandler:GetData()[2]
	local nTutorialId = wndHandler:GetData()[3]

	if nCurrPage < #tTutorial then
		self:DrawTutorialPage(nTutorialId, nCurrPage + 1)
	else
		wndHandler:GetParent():Close()
	end
end

function TutorialPrompts:ShowPrevious(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then return end -- wndHandler is 'btnNext' and its data is { nCurrPage, tTutorial, nTutorialId }
	
	if self.bAllViewSetting then
		Event_FireGenericEvent("HideAllTutorials")
		wndHandler:GetParent():Close()
	end
	
	local nCurrPage = wndHandler:GetData()[1]
	local tTutorial = wndHandler:GetData()[2]
	local nTutorialId = wndHandler:GetData()[3]

	if nCurrPage > 1 then
		self:DrawTutorialPage(nTutorialId, nCurrPage - 1)
	end
end

function TutorialPrompts:OnTypeViewToggle(wndHandler, wndControl)
	self.bTypeViewSetting = wndControl:IsChecked()
	self.bAllViewSetting = not wndControl:IsChecked()
end

function TutorialPrompts:OnAllViewToggle(wndHandler, wndControl)
	self.bTypeViewSetting = not wndControl:IsChecked()
	self.bAllViewSetting = wndControl:IsChecked()
end

---------------------------------------------------------------------------------------------------
-- TutorialTesterForm Functions
---------------------------------------------------------------------------------------------------
function TutorialPrompts:OnTutorialPromptTest()
	self:OnResetAll()
	self.wndMain:Show(true)
end

function TutorialPrompts:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

-- Verify the tutorial can be sent
function TutorialPrompts:OnTutorialTesterChanged( wndHandler, wndControl, strText )
	local tTutorial = {}
	tTutorial.strPopupText = self.wndMain:FindChild("LabelEntryWnd"):GetText()

	if self.wndMain:FindChild("NoTutorialBtn"):IsChecked() then -- artificial number just to send the signal
		--self.wndMain:FindChild("IDEntryWnd"):SetText("")
		self.wndMain:FindChild("IDEntryWnd"):SetTextColor(ApolloColor.new("UI_TextMetalBody"))
		tTutorial.id = 100000
	else
		self.wndMain:FindChild("IDEntryWnd"):SetTextColor(ApolloColor.new("white"))
		tTutorial.id = tonumber(self.wndMain:FindChild("IDEntryWnd"):GetText())
	end

	if tTutorial.strPopupText == kstrDefaultLabel and self.wndMain:FindChild("UseTutorialBtn"):IsChecked() then
		self.wndMain:FindChild("LabelEntryWnd"):SetTextColor(ApolloColor.new("UI_TextMetalBody"))
		tTutorial.strPopupText = ""
	else
		self.wndMain:FindChild("LabelEntryWnd"):SetTextColor(ApolloColor.new("white"))
	end

	-- Get button selection
	tTutorial.eAnchor = nil
	for i = 1, #self.tComponentList do
		if self.tComponentList[i]:IsChecked() then
			tTutorial.eAnchor = self.tComponentList[i]:GetData()
		end
	end

	self.wndMain:FindChild("OkButton"):SetData(tTutorial)
	local bEnable = (self.wndMain:FindChild("NoTutorialBtn"):IsChecked() and tTutorial.strPopupText ~= "" and tTutorial.eAnchor ~= GameLib.CodeEnumTutorialAnchor.None)
	or (self.wndMain:FindChild("UseTutorialBtn"):IsChecked() and tTutorial.id ~= nil and tTutorial.id ~= "" and tTutorial.id ~= 0)
	self.wndMain:FindChild("OkButton"):Enable(bEnable)
end

function TutorialPrompts:OnPreviewTutorialBtn(wndHandler, wndControl)
	local tTutorial = wndControl:GetData()

	-- Send the signal for the tutorial
	if tTutorial ~= nil then
		self:OnShowTutorialTest(tTutorial.id, false, tTutorial.strPopupText, tTutorial.eAnchor)
	end
end

-- Define general functions here
function TutorialPrompts:OnResetAll()
	self.wndMain:FindChild("LabelEntryWnd"):SetText(kstrDefaultLabel)
	self.wndMain:FindChild("LabelEntryWnd"):SetTextColor(ApolloColor.new("white"))
	self.wndMain:FindChild("IDEntryWnd"):SetText("")
	self.wndMain:FindChild("LabelEntryWnd"):ClearFocus()
	self.wndMain:FindChild("IDEntryWnd"):ClearFocus()
	self.wndMain:FindChild("NoTutorialBtn"):SetCheck(true)
	self.wndMain:FindChild("UseTutorialBtn"):SetCheck(false)

	local wndDefault = nil
	for i = 1, #self.tComponentList do
		self.tComponentList[i]:SetCheck(self.tComponentList[i]:GetData() == GameLib.CodeEnumTutorialAnchor.None)
		if self.tComponentList[i]:GetData() == GameLib.CodeEnumTutorialAnchor.None then
			 wndDefault = self.tComponentList[i]
		end
	end

	if wndDefault ~= nil then
		self.wndMain:FindChild("TutorialComponentList"):EnsureChildVisible(wndDefault)
	end

	self.wndMain:FindChild("OkButton"):SetData(nil)
	self.wndMain:FindChild("OkButton"):Enable(false)
end

---------------------------------------------------------------------------------------------------
-- ComponentSelectBtn Functions
---------------------------------------------------------------------------------------------------

function TutorialPrompts:OnComponentSelect( wndHandler, wndControl, eMouseButton )
	local nSelected = wndControl:GetData()

	for i = 1, #self.tComponentList do
		self.tComponentList[i]:SetCheck(self.tComponentList[i]:GetData() == nSelected)
	end

	self:OnTutorialTesterChanged()
end

-----------------------------------------------------------------------------------------------
-- TutorialPrompts Instance
-----------------------------------------------------------------------------------------------
local TutorialPromptsInst = TutorialPrompts:new()
TutorialPromptsInst:Init()
