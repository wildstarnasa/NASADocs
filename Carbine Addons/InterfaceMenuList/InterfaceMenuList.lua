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
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuList_NewAddOn", 			"OnNewAddonListed", self)
	Apollo.RegisterEventHandler("InterfaceMenuList_AlertAddOn", 		"OnDrawAlert", self)
	Apollo.RegisterEventHandler("CharacterCreated", 					"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 			"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterTimerHandler("TimeUpdateTimer", 						"OnUpdateTimer", self)
	Apollo.RegisterTimerHandler("QueueRedrawTimer", 					"OnQueuedRedraw", self)
	Apollo.RegisterEventHandler("ApplicationWindowSizeChanged", 		"ButtonListRedraw", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences", 		"OnUpdateTimer", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc , "InterfaceMenuListForm", "FixedHudStratumHigh", self)
	self.wndList = Apollo.LoadForm(self.xmlDoc , "FullListFrame", nil, self)

	self.wndMain:FindChild("OpenFullListBtn"):AttachWindow(self.wndList)
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
		[Apollo.GetString("InterfaceMenu_SystemMenu")] = { "", "Escape", "Icon_Windows32_UI_CRB_InterfaceMenu_EscMenu" }, --
	}
	
	self.tMenuTooltips = {}
	self.tMenuAlerts = {}

	self:ButtonListRedraw()

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
end

function InterfaceMenuList:OnListShow()
	self.wndList:ToFront()
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
	local nVisibility = Apollo.GetConsoleVariable("hud.TimeDisplay")
	
	local tLocalTime = GameLib.GetLocalTime()
	local tServerTime = GameLib.GetServerTime()
	local b24Hour = true
	local nLocalHour = tLocalTime.nHour > 12 and tLocalTime.nHour - 12 or tLocalTime.nHour == 0 and 12 or tLocalTime.nHour
	local nServerHour = tServerTime.nHour > 12 and tServerTime.nHour - 12 or tServerTime.nHour == 0 and 12 or tServerTime.nHour
		
	self.wndMain:FindChild("Time"):SetText(string.format("%02d:%02d", tostring(tLocalTime.nHour), tostring(tLocalTime.nMinute)))
	
	if nVisibility == 2 then --Local 12hr am/pm
		self.wndMain:FindChild("Time"):SetText(string.format("%02d:%02d", tostring(nLocalHour), tostring(tLocalTime.nMinute)))
		
		b24Hour = false
	elseif nVisibility == 3 then --Server 24hr
		self.wndMain:FindChild("Time"):SetText(string.format("%02d:%02d", tostring(tServerTime.nHour), tostring(tServerTime.nMinute)))
	elseif nVisibility == 4 then --Server 12hr am/pm
		self.wndMain:FindChild("Time"):SetText(string.format("%02d:%02d", tostring(nServerHour), tostring(tServerTime.nMinute)))
		
		b24Hour = false
	end
	
	nLocalHour = b24Hour and tLocalTime.nHour or nLocalHour
	nServerHour = b24Hour and tServerTime.nHour or nServerHour
	
	self.wndMain:FindChild("Time"):SetTooltip(
		string.format("%s%02d:%02d\n%s%02d:%02d", 
			Apollo.GetString("OptionsHUD_Local"), tostring(nLocalHour), tostring(tLocalTime.nMinute),
			Apollo.GetString("OptionsHUD_Server"), tostring(nServerHour), tostring(tServerTime.nMinute)
		)
	)
end

function InterfaceMenuList:OnNewAddonListed(strKey, tParams)
	strKey = string.gsub(strKey, ":", "|") -- ":'s don't work for window names, sorry!"

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
	local wndParent = self.wndList:FindChild("FullListScroll")
	
	local strQuery = Apollo.StringToLower(tostring(self.wndList:FindChild("SearchEditBox"):GetText()) or "")
	if strQuery == nil or strQuery == "" or not strQuery:match("[%w%s]+") then
		strQuery = ""
	end

	for strWindowText, tData in pairs(self.tMenuData) do
		local bSearchResultMatch = string.find(Apollo.StringToLower(strWindowText), strQuery) ~= nil
		
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
	self.wndList:FindChild("SearchClearBtn"):Show(string.len(wndHandler:GetText() or "") > 0)
	self:FullListRedraw()
end

function InterfaceMenuList:OnSearchClearBtn(wndHandler, wndControl)
	self.wndList:FindChild("SearchFlash"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.wndList:FindChild("SearchFlash"):SetFocus()
	self.wndList:FindChild("SearchClearBtn"):Show(false)
	self.wndList:FindChild("SearchEditBox"):SetText("")
	self:FullListRedraw()
end

function InterfaceMenuList:OnSearchCommitBtn(wndHandler, wndControl)
	self.wndList:FindChild("SearchFlash"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
	self.wndList:FindChild("SearchFlash"):SetFocus()
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
	
	local wndParent = self.wndList:FindChild("FullListScroll")
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
	self.wndList:Show(false)
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
	if wndHandler ~= wndControl or self.wndList:IsVisible() then
		return
	end
end

function InterfaceMenuList:OnListBtnMouseExit(wndHandler, wndControl) -- Also self.wndMain MouseExit and ButtonList MouseExit
	wndHandler:SetBGColor("9dffffff")
end

function InterfaceMenuList:OnOpenFullListCheck(wndHandler, wndControl)
	self.wndList:FindChild("SearchEditBox"):SetFocus()
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
		--[GameLib.CodeEnumTutorialAnchor.Character] 		= "CharacterBtn",
		--[GameLib.CodeEnumTutorialAnchor.Mail] 				= "MailBtn",
		--[GameLib.CodeEnumTutorialAnchor.GalacticArchive] = "LoreBtn",
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
InterfaceMenuListInst:Init()şê 2ObÿdiËZèAU_ê %Iòÿ$@ªRÇ9Uÿª &Iòß$) ªRÇ9Uÿª 5IşÛ%9ËZBUõ« OÉ}·%7	Mk(Bõ¿«z&¹}—åÄ	ï{ËZõ½+¶S¹{—æÄ	²”sõ½+
Øqç0 óœQŒ-‚ ÚÔÄ9ªYóœ²”,€ÙŸ  €€4óœ’” ¸îkµP-Ö«O?²”mkàèz~]-ö«Ã>siJèxz^ à3'|â$IJç9x\^W        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ%1‘wÉ™ÄŠRç9--µÕd¥àRw—›siJ
+­½±P¥àN7—›’”mk
+­½×–@&SóœqŒ ƒÚÔæÔPª+ĞóœÓœZj©¥ÙŸª¬  óœ’”pŠ*¨Õq~ÂúlÓœï{_ú  ¦N~ÒÚ	h’”mkWşª€ˆ<ORÛ#	I0„,cUÿª z6IRÛÛ „cUÿª z8IbÛÜ „cUÿª ;Éo·$'	0„,cU¿ª ¨QÉm·ä&	’”mkÕ¿ªÔq¹m—å4óœï{õ¯
 Ù¡1U  ¥’”-ëøÿÚÔÅŠéóœ²”>€Ú§   
4óœ’”àø¾kÓb+Ö¬_?²”®s€àø~x$­Õ«_?Ï{ªRàèz~0X/:ôÓ'ËZBx\^W H’$I’$èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ I$I’$ç9ç9    /îs¹™ÜËZèA-¥µÕnàNw™»Ï{ªR/½õ±Qœ`Nw—»²”Mk
+¯½ØŒ@î—óœQŒ(¢-ÚÏ¤ ‘ óœ²”€/üÚÎ " ¤ móœÓœ5Wj«Ù­u   óœ²”ø¿èÙ˜OÂ¶ óœqŒW  ªØÒÖÒ óœQŒUê Ø‘Iâ¶“ óœQŒUª  Ù˜Éİ–’  ¥qŒÕ«€ÿÙ±‰¹	   ¥²”½â_ıÚÎ  ÀÆM¥²”x÷¿«ÛÕj’¸é4Hóœ²” ÀøÚ›  @À,>ÓœqŒ (Š`Ôa;Ö¬_?²”®s€àø~€(+Ö¬_?0„ËZèú~_>+ö¬_?,cBèz^W hÂ$I’$(BÇ9üşÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ É‘äI’$(BÇ9¿ÿÿÿ1æps¹›ÜËZB+½ÕUeœàRw™»siJ
+¯õŸAœPNw™»qŒMk
+½ÕÖpPNw™ßÓœï{ 
¯õÙš   ¥»ÓœqŒ
¨‚-ÚÆÚH Ióœ²” 
ÿèÚÔœäØÀ*	óœ²”¨ ÿÚÔ8u²&óœ²”ÿ  
ÚÓ pÛ¹{_óœ²”ÿ   ÚÕ‚–$æ óœ²”«  ÿÛÕNbwDÖóœ²”  ú¿Ù¥    ¸>óœ’” ú¯zØ} ±¬í?Óœ0„
€ø_¬KĞ¨±¬_?’”mk è~_t Ğ(Ö¬_?Ï{ªR èş_=+Ö¬ï?cBèz^W `Â$I’$(BÇ9øşÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ I$I’$ç9ç9    $î—É$ªRç9+½ÕULœàrw™ÜMk(B
«½õv&œPnw›Üï{ËZ
«½ÕœD“Pnv›ßqŒMk«½Õ¾gPrw™»²”Ï{ *¿õÔ˜PN/SÓœqŒ 
	ÖÒÂmİV­óœÓœ©«ª«ØÔItI•TóœÓœêªªªÙœ€¤±b/:ÓœqŒ
 èxÈo€¶±¬o?²”ï{  ú_¥L¶±¬ï'’”mk êÿW‚.Ğ6²­ï'„ëZ êşWXĞ(¶¬ï?nsiJ úW,»úõó$ËZèAè~WU	 `ò$I’$BÇ9üÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ ñ¤I’$(BÇ9/¿ÿÿ'œà–¹$ªRç9
¯õUJ
œàRw—˜Mk(B
¯½µ€@¦ğñ„,c+/--Ø–1éóœqŒ-©‰ÙÓ¬#ÇbºóœÓœ«©©©ÙÓ±çTIÕóœóœ    Ø•˜ƒ5P4ÓœqŒzzbb?‹ÕZ/:„,càèxxPĞ¨µ¬_'Mk(B èş^.Ğ8Ööó$ËZèA úWU X_'I’$IJç9è_UU        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ(1y•WªRèA%%55{1ïğ1•w„ëZ/--½Øz&`
/™»óœ0„‹-õÙ   m›$Óœ’”ÿ UÙ   m›$ÓœqŒ ª ×q Õ¤_?²”Ï{€ààzu(X/ö¢³>ï{ëZxxx^$à£>sB'ŠRç9xX\^        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ y‘xÉ›äIJç9-5µÕW¥àRw™»Mk(B
+¯õ~1Pnv›ü„ëZ«ÿÕA °m¶$0„,c ªÿU‚@ °m¶$0„,c ªÿU|,€¸±­ÿ'ï{ëZ€èşWK	-ö¬S?Mk(Bèø~_ `2'N’$(Bç9øüÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ