-----------------------------------------------------------------------------------------------
-- Client Lua Script for InterfaceMenuList
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Apollo"

local InterfaceMenuList = {}
local knVersion = 2

function InterfaceMenuList:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function InterfaceMenuList:Init()
    Apollo.RegisterAddon(self)
end

function InterfaceMenuList:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local tSavedData = {
		nVersion = knVersion,
		tPinnedAddons = self.tPinnedAddons,
	}
	
	return tSavedData
end

function InterfaceMenuList:OnRestore(eType, tSavedData)
	if tSavedData.nVersion ~= knVersion then
		return
	end
	
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	if tSavedData.tPinnedAddons then
		self.tPinnedAddons = tSavedData.tPinnedAddons
	end
	
	self.tSavedData = tSavedData
end


function InterfaceMenuList:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("InterfaceMenuList.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function InterfaceMenuList:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuList_NewAddOn", 			"OnNewAddonListed", self)
	Apollo.RegisterEventHandler("InterfaceMenuList_AlertAddOn", 		"OnDrawAlert", self)
	Apollo.RegisterEventHandler("CharacterCreated", 					"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 			"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterTimerHandler("TimeUpdateTimer", 						"OnUpdateTimer", self)
	Apollo.RegisterTimerHandler("QueueRedrawTimer", 					"OnQueuedRedraw", self)
	Apollo.RegisterEventHandler("ApplicationWindowSizeChanged", 		"ButtonListRedraw", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc , "InterfaceMenuListForm", nil, self)

	self.wndMain:FindChild("OpenFullListBtn"):AttachWindow(self.wndMain:FindChild("FullListFrame"))
	self.wndMain:FindChild("OpenFullListBtn"):Enable(false)

	Apollo.CreateTimer("QueueRedrawTimer", 0.3, false)

	if not self.tPinnedAddons then
		self.tPinnedAddons = {
			Apollo.GetString("InterfaceMenu_AccountInventory"),
			Apollo.GetString("InterfaceMenu_Character"),
			Apollo.GetString("InterfaceMenu_AbilityBuilder"),
			Apollo.GetString("InterfaceMenu_QuestLog"),
			Apollo.GetString("InterfaceMenu_GroupFinder"),
			Apollo.GetString("InterfaceMenu_Social"),
			Apollo.GetString("InterfaceMenu_Mail"),
			Apollo.GetString("InterfaceMenu_Lore"),
		}
	end
	
	self.tMenuData = {
		[Apollo.GetString("InterfaceMenu_SystemMenu")] = { "", "", "Icon_Windows32_UI_CRB_InterfaceMenu_EscMenu" }, --
	}
	
	self.tMenuTooltips = {}
	self.tMenuAlerts = {}

	self:ButtonListRedraw()

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
end

function InterfaceMenuList:OnCharacterCreated()	
	Apollo.CreateTimer("TimeUpdateTimer", 1.0, true)
end

function InterfaceMenuList:OnUpdateTimer()
	if not self.bHasLoaded then
		Event_FireGenericEvent("InterfaceMenuListHasLoaded")
		self.wndMain:FindChild("OpenFullListBtn"):Enable(true)
		self.bHasLoaded = true
	end

	--Toggle Visibility based on ui preference
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end
	local bIsInCombat = unitPlayer:IsInCombat()
	local nVisibility = Apollo.GetConsoleVariable("hud.TimeDisplay")
	local bShowTime = true
	
	if nVisibility == 2 then --always off
		bShowTime = false
	elseif nVisibility == 3 then --on in combat
		bShowTime = bIsInCombat
	elseif nVisibility == 4 then --on out of combat
		bShowTime = not bIsInCombat
	else
		bShowTime = true
	end

	local tTime = GameLib.GetLocalTime()
	self.wndMain:FindChild("Time"):SetText(bShowTime and string.format("%02d:%02d", tostring(tTime.nHour), tostring(tTime.nMinute)) or "")
end

function InterfaceMenuList:OnNewAddonListed(strKey, tParams)
	self.tMenuData[strKey] = tParams
	
	self:FullListRedraw()
	self:ButtonListRedraw()
end

function InterfaceMenuList:IsPinned(strText)
	for idx, strWindowText in pairs(self.tPinnedAddons) do
		if (strText == strWindowText) then
			return true
		end
	end
	
	return false
end

function InterfaceMenuList:FullListRedraw()
	local strUnbound = Apollo.GetString("Keybinding_Unbound")
	local wndParent = self.wndMain:FindChild("FullListScroll")
	
	local strQuery = string.lower(tostring(self.wndMain:FindChild("SearchEditBox"):GetText()) or "")
	if strQuery == nil or strQuery == "" or not strQuery:match("[%w%s]+") then
		strQuery = ""
	end

	for strWindowText, tData in pairs(self.tMenuData) do
		local bSearchResultMatch = string.find(string.lower(strWindowText), strQuery) ~= nil
		
		if strQuery == "" or bSearchResultMatch then
			local wndMenuItem = self:LoadByName("MenuListItem", wndParent, strWindowText)
			local wndMenuButton = self:LoadByName("InterfaceMenuButton", wndMenuItem:FindChild("Icon"), strWindowText)
			local strTooltip = strWindowText
			
			if string.len(tData[2]) > 0 then
				local strKeyBindLetter = GameLib.GetKeyBinding(tData[2])
				strKeyBindLetter = strKeyBindLetter == strUnbound and "" or string.format(" (%s)", strKeyBindLetter)  -- LOCALIZE
				
				strTooltip = strKeyBindLetter ~= "" and strTooltip .. strKeyBindLetter or strTooltip
			end
			
			if tData[3] ~= "" then
				wndMenuButton:FindChild("Icon"):SetSprite(tData[3])
			else 
				wndMenuButton:FindChild("Icon"):SetText(string.sub(strTooltip, 1, 1))
			end
			
			wndMenuButton:FindChild("ShortcutBtn"):SetData(strWindowText)
			wndMenuButton:FindChild("Icon"):SetTooltip(strTooltip)
			self.tMenuTooltips[strWindowText] = strTooltip
			
			wndMenuItem:FindChild("MenuListItemBtn"):SetText(strWindowText)
			wndMenuItem:FindChild("MenuListItemBtn"):SetData(tData[1])
			
			wndMenuItem:FindChild("PinBtn"):SetCheck(self:IsPinned(strWindowText))
			wndMenuItem:FindChild("PinBtn"):SetData(strWindowText)
			
			if string.len(tData[2]) > 0 then
				local strKeyBindLetter = GameLib.GetKeyBinding(tData[2])
				wndMenuItem:FindChild("MenuListItemBtn"):FindChild("MenuListItemKeybind"):SetText(strKeyBindLetter == strUnbound and "" or string.format("(%s)", strKeyBindLetter))  -- LOCALIZE
			end
		elseif not bSearchResultMatch and wndParent:FindChild(strWindowText) then
			wndParent:FindChild(strWindowText):Destroy()
		end
	end
	
	wndParent:ArrangeChildrenVert(0, function (a,b) return a:GetName() < b:GetName() end)
end

function InterfaceMenuList:ButtonListRedraw()
	Apollo.StopTimer("QueueRedrawTimer")
	Apollo.StartTimer("QueueRedrawTimer")
end

function InterfaceMenuList:OnQueuedRedraw()
	local strUnbound = Apollo.GetString("Keybinding_Unbound")
	local wndParent = self.wndMain:FindChild("ButtonList")
	wndParent:DestroyChildren()
	local nParentWidth = wndParent:GetWidth()
	
	local nLastButtonWidth = 0
	local nTotalWidth = 0

	for idx, strWindowText in pairs(self.tPinnedAddons) do
		tData = self.tMenuData[strWindowText]
		
		--Magic number below is allowing the 1 pixel gutter on the right
		if tData and nTotalWidth + nLastButtonWidth <= nParentWidth + 1 then
			local wndMenuItem = self:LoadByName("InterfaceMenuButton", wndParent, strWindowText)
			local strTooltip = strWindowText
			nLastButtonWidth = wndMenuItem:GetWidth()
			nTotalWidth = nTotalWidth + nLastButtonWidth

			if string.len(tData[2]) > 0 then
				local strKeyBindLetter = GameLib.GetKeyBinding(tData[2])
				strKeyBindLetter = strKeyBindLetter == strUnbound and "" or string.format(" (%s)", strKeyBindLetter)  -- LOCALIZE
				strTooltip = strKeyBindLetter ~= "" and strTooltip .. strKeyBindLetter or strTooltip
			end
			
			if tData[3] ~= "" then
				wndMenuItem:FindChild("Icon"):SetSprite(tData[3])
			else 
				wndMenuItem:FindChild("Icon"):SetText(string.sub(strTooltip, 1, 1))
			end
			
			wndMenuItem:FindChild("ShortcutBtn"):SetData(strWindowText)
			wndMenuItem:FindChild("Icon"):SetTooltip(strTooltip)
		end
		
		if self.tMenuAlerts[strWindowText] then
			self:OnDrawAlert(strWindowText, self.tMenuAlerts[strWindowText])
		end
	end
	
	wndParent:ArrangeChildrenHorz(0)
end

-----------------------------------------------------------------------------------------------
-- Search
-----------------------------------------------------------------------------------------------

function InterfaceMenuList:OnSearchEditBoxChanged(wndHandler, wndControl)
	self.wndMain:FindChild("SearchClearBtn"):Show(string.len(wndHandler:GetText() or "") > 0)
	self:FullListRedraw()
end

function InterfaceMenuList:OnSearchClearBtn(wndHandler, wndControl)
	self.wndMain:FindChild("SearchFlash"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.wndMain:FindChild("SearchFlash"):SetFocus()
	self.wndMain:FindChild("SearchClearBtn"):Show(false)
	self.wndMain:FindChild("SearchEditBox"):SetText("")
	self:FullListRedraw()
end

function InterfaceMenuList:OnSearchCommitBtn(wndHandler, wndControl)
	self.wndMain:FindChild("SearchFlash"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.wndMain:FindChild("SearchFlash"):SetFocus()
	self:FullListRedraw()
end

-----------------------------------------------------------------------------------------------
-- Alerts
-----------------------------------------------------------------------------------------------

function InterfaceMenuList:OnDrawAlert(strWindowName, tParams)
	self.tMenuAlerts[strWindowName] = tParams
	for idx, wndTarget in pairs(self.wndMain:FindChild("ButtonList"):GetChildren()) do
		if wndTarget and tParams then
			local wndButton = wndTarget:FindChild("ShortcutBtn")
			if wndButton then 
				local wndIcon = wndButton:FindChild("Icon")
				
				if wndButton:GetData() == strWindowName then
					if tParams[1] then
						local wndIndicator = self:LoadByName("AlertIndicator", wndButton:FindChild("Alert"), "AlertIndicator")
						
					elseif wndButton:FindChild("AlertIndicator") ~= nil then
						wndButton:FindChild("AlertIndicator"):Destroy()
					end
					
					if tParams[2] then
						wndIcon:SetTooltip(string.format("%s\n\n%s", self.tMenuTooltips[strWindowName], tParams[2]))
					end
					
					if tParams[3] and tParams[3] > 0 then
						local strColor = tParams[1] and "UI_WindowTextOrange" or "UI_TextHoloTitle"
						
						wndButton:FindChild("Number"):Show(true)
						wndButton:FindChild("Number"):SetText(tParams[3])
						wndButton:FindChild("Number"):SetTextColor(ApolloColor.new(strColor))
					else
						wndButton:FindChild("Number"):Show(false)
						wndButton:FindChild("Number"):SetText("")
						wndButton:FindChild("Number"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
					end
				end
			end
		end
	end
	
	local wndParent = self.wndMain:FindChild("FullListScroll")
	for idx, wndTarget in pairs(wndParent:GetChildren()) do
		local wndButton = wndTarget:FindChild("ShortcutBtn")
		local wndIcon = wndButton:FindChild("Icon")
		
		if wndButton:GetData() == strWindowName then
			if tParams[1] then
				local wndIndicator = self:LoadByName("AlertIndicator", wndButton:FindChild("Alert"), "AlertIndicator")
			elseif wndButton:FindChild("AlertIndicator") ~= nil then
				wndButton:FindChild("AlertIndicator"):Destroy()
			end
			
			if tParams[2] then
				wndIcon:SetTooltip(string.format("%s\n\n%s", self.tMenuTooltips[strWindowName], tParams[2]))
			end
			
			if tParams[3] and tParams[3] > 0 then
				local strColor = tParams[1] and "UI_WindowTextOrange" or "UI_TextHoloTitle"
				
				wndButton:FindChild("Number"):Show(true)
				wndButton:FindChild("Number"):SetText(tParams[3])
				wndButton:FindChild("Number"):SetTextColor(ApolloColor.new(strColor))
			else
				wndButton:FindChild("Number"):Show(false)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers and Errata
-----------------------------------------------------------------------------------------------

function InterfaceMenuList:OnMenuListItemClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	if string.len(wndControl:GetData()) > 0 then
		Event_FireGenericEvent(wndControl:GetData())
	else
		InvokeOptionsScreen()
	end
	self.wndMain:FindChild("FullListFrame"):Show(false)
end

function InterfaceMenuList:OnPinBtnChecked(wndHandler, wndControl)
	if wndHandler ~= wndControl then return end
	
	local wndParent = wndControl:GetParent():GetParent()
	
	self.tPinnedAddons = {}
	
	for idx, wndMenuItem in pairs(wndParent:GetChildren()) do
		if wndMenuItem:FindChild("PinBtn"):IsChecked() then
		
			table.insert(self.tPinnedAddons, wndMenuItem:FindChild("PinBtn"):GetData())
		end
	end
	
	self:ButtonListRedraw()
end

function InterfaceMenuList:OnListBtnClick(wndHandler, wndControl) -- These are the five always on icons on the top
	if wndHandler ~= wndControl then return end
	local strMappingResult = self.tMenuData[wndHandler:GetData()][1] or ""
	
	if string.len(strMappingResult) > 0 then
		Event_FireGenericEvent(strMappingResult)
	else
		InvokeOptionsScreen()
	end
end

function InterfaceMenuList:OnListBtnMouseEnter(wndHandler, wndControl)
	wndHandler:SetBGColor("ffffffff")
	if wndHandler ~= wndControl or self.wndMain:FindChild("FullListFrame"):IsVisible() then
		return
	end
end

function InterfaceMenuList:OnListBtnMouseExit(wndHandler, wndControl) -- Also self.wndMain MouseExit and ButtonList MouseExit
	wndHandler:SetBGColor("9dffffff")
end

function InterfaceMenuList:OnOpenFullListCheck(wndHandler, wndControl)
	self.wndMain:FindChild("SearchEditBox"):SetFocus()
	self:FullListRedraw()
end

function InterfaceMenuList:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc , strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

function InterfaceMenuList:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	local arTutorialAnchorMapping =
	{
		--[GameLib.CodeEnumTutorialAnchor.Abilities] 			= "LASBtn",
		--[GameLib.CodeEnumTutorialAnchor.Character] 			= "CharacterBtn",
		--[GameLib.CodeEnumTutorialAnchor.Mail] 				= "MailBtn",
		--[GameLib.CodeEnumTutorialAnchor.GalacticArchive] 	= "LoreBtn",
		--[GameLib.CodeEnumTutorialAnchor.Social] 			= "SocialBtn",
		--[GameLib.CodeEnumTutorialAnchor.GroupFinder] 		= "GroupFinderBtn",
	}

	local strWindowName = "ButtonList" or false
	if not strWindowName then
		return
	end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:FindChild(strWindowName):GetRect()
	tRect.r = tRect.r - 26
	
	if arTutorialAnchorMapping[eAnchor] then
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local InterfaceMenuListInst = InterfaceMenuList:new()
InterfaceMenuListInst:Init()