-----------------------------------------------------------------------------------------------
-- Client Lua Script for CharacterSelect
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "CharacterScreenLib"

local CharacterSelection = {}

local kiCharacterMax = 6
local kiMaxClassCount = 20 -- highest class entry (1-20)
local kiMaxPathCount = 4 -- highest path count (0-3; adding 1 for Lua's ineptitude)
local knCheerAnimation = 1621
local knDeleteModelAttachmentId = 98

function CharacterSelection:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CharacterSelection:Init()
	Apollo.RegisterAddon(self)
end

function CharacterSelection:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CharacterSelection.xml")

	Apollo.RegisterEventHandler("LoadFromCharacter", "OnLoadFromCharacter", self)
	Apollo.RegisterEventHandler("CharacterDelete", "OnCharacterDeleteResult", self)
	Apollo.RegisterTimerHandler("DeleteFailedTimer", "OnDeleteFailedTimer", self)
	Apollo.RegisterEventHandler("AnimationFinished", "OnAnimationFinished", self)
	Apollo.RegisterEventHandler("CharacterSelectFail", "OnCharacterSelectResult", self)
	Apollo.RegisterEventHandler("CharacterRename", "OnCharacterRenameResult", self)
	Apollo.RegisterEventHandler("SelectCharacter", "OnSelectCharacter", self)
	Apollo.RegisterTimerHandler("RemoveCountdown", "OnRemoveCountdown", self)

	self.wndSelectList = Apollo.LoadForm(self.xmlDoc, "LeftControlPanel", "Navigation", self)
	self.wndTopPanel = Apollo.LoadForm(self.xmlDoc, "TopContainer", "Navigation", self)
	self.wndDelete = Apollo.LoadForm(self.xmlDoc, "DeleteControls", "Navigation", self)
	self.wndRename = Apollo.LoadForm(self.xmlDoc, "RenameControls", "Navigation", self)
	self.wndDeleteError = Apollo.LoadForm(self.xmlDoc, "DeleteErrorMessage", "Navigation", self)

	self.wndSelectList:Show(false)
	self.wndTopPanel:Show(false)
	self.wndDelete:Show(false)
	self.wndRename:Show(false)
	self.wndDeleteError:Show(false)

	self.wndCharacterDeleteBtn = self.wndSelectList:FindChild("DeleteBtn")
	self.wndCharacterDeleteBtn:Enable(false) -- will get turned on by choosing a character through code or player input
	self.tSelectedCharacter = {} -- used to return after mouse-over

	self.nAttemptedDelete = nil
	self.nStartingCharacterRotation = 0
end

function CharacterSelection:OnLoadFromCharacter()

	local tRealmInfo = CharacterScreenLib.GetRealmInfo()
	local strRealm = ""
	local strRealmName = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">%s</T>", tostring(tRealmInfo.strName))
	local strRealmLabel = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">%s</T>", Apollo.GetString("CharacterSelect_RealmLabel"))

	strRealm = string.format("<P Align=\"Center\">%s</P>", strRealmLabel .. "    " .. strRealmName)
	self.wndTopPanel:FindChild("RealmLabel"):SetText(strRealm)

	local btnSel = nil
	self.nAttemptedDelete = nil
	g_nState = LuaEnumState.Select

	self.arItems = {}
	self.wndSelectList:FindChild("CharacterList"):DestroyChildren()

	self.wndTopPanel:FindChild("CharacterName"):Show(true)
	self.wndTopPanel:FindChild("CharacterNameBacker"):Show(true)

	self.wndDelete:Show(false)
	self.wndRename:Show(false)
	self.wndDeleteError:Show(false)

	self.wndCameraToggles = g_controls:FindChild("CameraControls")
	self.wndCameraToggles:FindChild("ToggleCameraBtnBody"):SetCheck(true)
	self.wndCameraToggles:FindChild("ToggleCameraBtnPortrait"):SetCheck(false)
	g_controls:FindChild("EnterForm"):FindChild("BGArt_BottomRunnerName"):Show(false)
	g_controls:FindChild("EnterForm"):FindChild("BGArt_BottomRunner"):Show(true)
	g_controls:FindChild("EnterForm"):Show(true)
	g_controls:FindChild("EnterBtn"):FindChild("EnterLabel"):SetText(Apollo.GetString("CharacterSelect_EnterGame"))
	g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff3c524f"))
	g_controls:FindChild("EnterBtn"):SetData(nil)
	g_controls:FindChild("EnterBtn"):Enable(false)
	g_controls:FindChild("ExitForm"):Show(true)
	g_controls:FindChild("ExitForm"):Enable(true)
	g_controls:FindChild("ExitForm"):FindChild("BackBtnLabel"):SetText(Apollo.GetString("CRB_Exit"))
	g_controls:FindChild("OptionsContainer"):Show(true)

	local frameL, frameT, frameR, frameB = self.wndSelectList:GetAnchorOffsets()
	local listL, listT, listR, listB = self.wndSelectList:FindChild("CharacterList"):GetAnchorOffsets()

	local wndSel = nil
	local nCharCount = 0
	local nEntryHeight = 0
	local nNewHeight = 0
	local fLastLoggedOutDays = nil

	for idx, tChar in ipairs(g_arCharacters) do
		nCharCount = nCharCount + 1
		local wndItem = Apollo.LoadForm(self.xmlDoc, "CharacterOption", self.wndSelectList:FindChild("CharacterList"), self)
		local btnItem = wndItem:FindChild("CharacterOptionFrameBtn")
		local wndClassIconComplex = wndItem:FindChild("ClassIconComplex")
		local wndPathIconComplex = wndItem:FindChild("PathIconComplex")

		if nCharCount == 1 then
			wndItem:FindChild("CharacterOptionFrameBtn"):ChangeArt("CharacterCreate:btnCharC_SelectTop")
		elseif nCharCount == kiCharacterMax then
			wndItem:FindChild("CharacterOptionFrameBtn"):ChangeArt("CharacterCreate:btnCharC_SelectBottom")
		end

		nEntryHeight = wndItem:GetHeight()

		-- Faction
		wndItem:FindChild("BGFactionFrame_Ex"):Show(tChar.idFaction ~= 166)
		wndItem:FindChild("BGFactionFrame_Dom"):Show(tChar.idFaction == 166)

		if tChar.fLastLoggedOutDays ~= nil and not tChar.bDisabled == true and ( fLastLoggedOutDays == nil or fLastLoggedOutDays < tChar.fLastLoggedOutDays ) then
			fLastLoggedOutDays = tChar.fLastLoggedOutDays
			wndSel = wndItem
		end

		wndItem:FindChild("Level"):SetText(tChar.nLevel)
		CharacterScreenLib.ApplyCharacterToCostumeWindow(idx, wndItem:FindChild("CharacterPortrait"))

		for iClassIcon = 1, kiMaxClassCount do
			wndClassIconComplex:FindChild("ClassIcon_" .. iClassIcon):Show(false) -- hides all
		end

		if tChar.idClass <= kiMaxClassCount then -- prevents breaking from a really bizarre class number
			wndClassIconComplex:FindChild("ClassIcon_" .. tChar.idClass):Show(true)
		end

		for iPathIcon = 1, kiMaxPathCount do
			wndPathIconComplex:FindChild("PathIcon_" .. iPathIcon):Show(false) -- hides all
		end

		local iAdjustedPath = tChar.idPath + 1 --CPP zero indexes paths
		if iAdjustedPath <= kiMaxPathCount then -- prevents breaking from a really bizarre path number
			wndPathIconComplex:FindChild("PathIcon_" .. iAdjustedPath):Show(true)
		end

		wndItem:FindChild("Location"):SetText(tChar.strZone)

		wndItem:FindChild("CharacterName"):SetText(tChar.strName)

		if tChar.bDisabled == true then
			wndItem:FindChild("CharacterOptionFrameBtn"):Show(false)
			wndItem:FindChild("BGFactionFrame_Ex"):SetBGColor(CColor.new(0.4, 0.4, 0.4, 1.0))
			wndItem:FindChild("BGFactionFrame_Dom"):SetBGColor(CColor.new(0.4, 0.4, 0.4, 1.0))
			wndItem:FindChild("CharacterName"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
			wndItem:FindChild("Location"):SetText(Apollo.GetString("CharacterSelect_Locked"))
			wndItem:FindChild("LockIcon"):Show(true)

			for iClassIcon = 1, kiMaxClassCount do
				wndClassIconComplex:FindChild("ClassIcon_" .. iClassIcon):SetBGColor(CColor.new(0.4, 0.4, 0.4, 1.0))
			end

			for iPathIcon = 1, kiMaxPathCount do
				wndPathIconComplex:FindChild("PathIcon_" .. iPathIcon):SetBGColor(CColor.new(0.4, 0.4, 0.4, 1.0))
			end

		end
		
		if g_arCharacterInWorld ~= nil then
			wndItem:FindChild("DisabledBlocker"):Show(g_arCharacterInWorld.nCharacterIndex ~= nCharCount)
			
			if g_arCharacterInWorld.nCharacterIndex == nCharCount then
				wndSel = wndItem
			end
		end

		btnItem:SetData(idx)
		self.arItems[idx] = wndItem
	end
	
	if g_arCharacterInWorld ~= nil then
		Apollo.CreateTimer("RemoveCountdown", 0.5, true)
		self.wndSelectList:FindChild("DisabledCountBG"):Show(true)
	end

	if nCharCount == 0 then
		local wndPrompt = Apollo.LoadForm(self.xmlDoc, "CreateNewPrompt", self.wndSelectList:FindChild("CharacterList"), self)
		nNewHeight = wndPrompt:GetHeight()
		nCharCount = 1
		nEntryHeight = wndPrompt:GetHeight()

		-- remove the model if there's none on the list; our remove function is broken, so replace
		--if g_arActors.primary ~= nil then

		--end
	end

	if nCharCount < kiCharacterMax then
		local wndCreate = Apollo.LoadForm(self.xmlDoc, "CreateNewOption", self.wndSelectList:FindChild("CharacterList"), self)
		nNewHeight = wndCreate:GetHeight()
	end

	local nTotalHeight = listT - listB + (nEntryHeight*nCharCount) + nNewHeight -- listB is a negative value
	self.wndSelectList:SetAnchorOffsets(frameL, -(nTotalHeight/2), frameR, nTotalHeight/2)

	self.wndSelectList:FindChild("CharacterList"):ArrangeChildrenVert()

	if wndSel ~= nil then
		local btnSel = wndSel:FindChild("CharacterOptionFrameBtn")
		self:OnCharacterSelectCheck(btnSel, btnSel)
	else -- no default
		if #self.arItems > 0 then
			local btnSel = self.arItems[1]:FindChild("CharacterOptionFrameBtn")
			self:OnCharacterSelectCheck(btnSel, btnSel)
		else
			self.wndTopPanel:FindChild("CharacterName"):SetText(Apollo.GetString("CharacterSelect_NoCharactersFound"))
			local nWidth = Apollo.GetTextWidth("CRB_HeaderHuge", Apollo.GetString("CharacterSelect_NoCharactersFound"))+20
			local backerL, backerT, backerR, backerB = self.wndTopPanel:FindChild("CharacterNameBacker"):GetAnchorOffsets()
			--self.wndTopPanel:FindChild("CharacterNameBacker"):SetAnchorOffsets( -(nWidth/2), backerT, (nWidth/2), backerB)

			g_arActors.primary = g_scene:AddActorByFile( 1, "Art\\Creature\\Rowsdower\\Rowsdower.m3" )
			g_arActors.primary:AttachToActor( g_arActors.characterAttach, 17 )

			g_nCharCurrentRot = 0
			g_arActors.characterAttach:Animate(0, 1120, 0, true, false, 0, g_nCharCurrentRot)
			g_arActors.primary:Animate(0, 5612, 0, true, false)

			g_bReplaceActor = true

			-- Disable the faction/race/class icons
			if g_arActors.factionIcon ~= nil then
				g_arActors.factionIcon:Animate(0, 6670, 0, true, false)
			end

			if g_arActors.weaponIcon ~= nil then
				g_arActors.weaponIcon:Animate(0, 6667, 0, true, false)
			end

			if g_arActors.pathIcon ~= nil then
				g_arActors.pathIcon:Animate(0, 1109, 0, true, false)
			end
		end
	end

	self.wndSelectList:Show(true)
	self.wndTopPanel:Show(true)

	self.wndSelectList:SetFocus()

	PreGameLib.SetMusic(PreGameLib.CodeEnumMusic.CharacterSelect)

	if g_arActors.warningLight1 then
		g_arActors.warningLight1:Animate(0, 1122, 0, true, false)
	end

	if g_arActors.warningLight2 then
		g_arActors.warningLight2:Animate(0, 1122, 0, true, false)
	end


end

function CharacterSelection:OnRemoveCountdown()
	g_arCharacterInWorld.nCharacterRemoveTime = g_arCharacterInWorld.nCharacterRemoveTime - 500
	local nTimeLeft = g_arCharacterInWorld.nCharacterRemoveTime / 1000
	
	local str = PreGameLib.String_GetWeaselString(Apollo.GetString("CharacterSelect_LogoffInSeconds"), nTimeLeft)
	self.wndSelectList:FindChild("DisabledCountdown"):SetText(str)
	
	if nTimeLeft < 0 then
		self.wndSelectList:FindChild("DisabledCountBG"):Show(false)
		Apollo.StopTimer("RemoveCountdown")
		
		for idx, wndCharacter in pairs(self.wndSelectList:FindChild("CharacterList"):GetChildren()) do
			wndCharacter:FindChild("DisabledBlocker"):Show(false)
		end
	end
end

function CharacterSelection:OnCharacterSelectCheck(wndHandler, wndControl, iButton)
	if wndHandler ~= wndControl then
		return false
	end

	local wndCharacter = wndControl:GetParent()
	local nId = wndControl:GetData()

	-- Send event to Account Services (which may need it)
	local tSelected = g_arCharacters[nId]
	local strName = tSelected and tSelected.strName or ""
	PreGameLib.Event_FireGenericEvent("Pregame_CharacterSelected", nId, strName or "")

	-- Set check in case we're doing this from code and not an actual click
	if not wndControl:IsChecked() then
		wndControl:SetCheck(true)
	end

	self:SetCharacterDisplay(nId)
	self.wndRename:Show(false)

	-- TODO: double click will go here
	if iButton == 1 then
		--EnterGame()
		self:OnSelectCharacter(nId)
		return
	end

	for idx, wndItem in ipairs(self.arItems) do
		if wndItem == wndCharacter then
			self:HelperFormatEntrySelected(wndItem)-- Do stuff to the selected one
		else
			self:HelperFormatEntryDeselected(wndItem) -- Do stuff to the non-selected ones
		end
	end
end

function CharacterSelection:HelperFormatEntrySelected(wnd)
	-- this sets up the non-current character choices
	wnd:FindChild("CharacterName"):SetTextColor(ApolloColor.new("white"))
	wnd:FindChild("Level"):SetTextColor(ApolloColor.new("white"))
	wnd:FindChild("Location"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
end

function CharacterSelection:HelperFormatEntryDeselected(wnd)
	-- this sets up the non-current character choices
	wnd:FindChild("CharacterName"):SetTextColor(ApolloColor.new("UI_BtnTextBlueNormal"))
	wnd:FindChild("Level"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
	wnd:FindChild("Location"):SetTextColor(ApolloColor.new("UI_TextHoloBody"))
end

-------------

function CharacterSelection:SetCharacterDisplay(tId)
	local tSetChar = g_arCharacters[tId]

	if tSetChar == nil then
		g_controls:FindChild("EnterBtn"):SetData(nil)
		g_controls:FindChild("EnterBtn"):Enable(false)
		g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff3c524f"))
		self.wndCharacterDeleteBtn:Enable(false)
		return
	end

	self.wndCharacterDeleteBtn:Enable(true)

	self:SetCharacterCreateModel(tId)

	self.tSelectedCharacter = tSetChar
	g_controls:FindChild("EnterBtn"):Enable(true)
	g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff72f2a0"))
	g_controls:FindChild("EnterBtn"):SetData(tId)

	self.wndTopPanel:FindChild("CharacterName"):SetText(tSetChar.strName)
	local nWidth = Apollo.GetTextWidth("CRB_HeaderHuge", tSetChar.strName)+20
	local backerL, backerT, backerR, backerB = self.wndTopPanel:FindChild("CharacterNameBacker"):GetAnchorOffsets()
	--self.wndTopPanel:FindChild("CharacterNameBacker"):SetAnchorOffsets( -(nWidth/2), backerT, (nWidth/2), backerB)
end

---------------------------------------------------------------------------------------------------
function CharacterSelection:SetCharacterCreateModel(nId)
	--Set the actor if we don't have one or update to match race/gender
	local tSelected = g_arCharacters[nId]
	g_arActors.primary = g_scene:AddActorByRaceGender(1, tSelected.idRace, tSelected.idGender)

	PreGameLib.Event_FireGenericEvent("Select_SetModel",
									   tSelected.idRace,
									   tSelected.idGender,
									   tSelected.idFaction,
									   tSelected.idClass,
									   tSelected.idPath,
									   nId)
end

function CharacterSelection:OnSelectCharacter(tId)

	local tSetChar
	if tId ~= nil then
		tSetChar = g_arCharacters[tId]
	end

	if tSetChar == nil then
		return
	end

	if tSetChar.bRequiresRename then
		self.wndRename:Show(true)
		self.wndRename:FindChild("RenameCharacterNameEntry"):SetText("")
		self.wndRename:FindChild("RenameCharacterNameEntry"):SetFocus()
	else
		CharacterScreenLib.SelectCharacter(tId)
	end
end

function CharacterSelection:PopupError(strResult, strTitle)
	Apollo.CreateTimer("DeleteFailedTimer", 10.0, false)
	Apollo.StartTimer("DeleteFailedTimer")
	self.wndDeleteError:FindChild("DeleteError_Body"):SetText(strResult)
	self.wndDeleteError:FindChild("DeleteError_Title"):SetText(strTitle)
	self.wndDeleteError:Show(true)
end

function CharacterSelection:OnCharacterDeleteResult(nDeleteResult, nData)

	if g_nState ~= LuaEnumState.Delete or self.nAttemptedDelete == nil then return end

	local nCharMax = #g_arCharacters

	if nDeleteResult == PreGameLib.CodeEnumCharacterModifyResults.DeleteOk then
		for idx = self.nAttemptedDelete, nCharMax do
			if g_arCharacters[idx+1] ~= nil then
				g_arCharacters[idx] = g_arCharacters[idx+1]
			end
		end
		table.remove(g_arCharacters, nCharMax)

		-- special effect
		g_arActors.deleteEffect = g_scene:AddActorByFile(20000, "Art\\FX\\Model\\OT\\CharacterDelete_RED\\CharacterDelete_RED.m3")
		if g_arActors.deleteEffect then
			g_arActors.deleteEffect:AttachToActor( g_arActors.primary, knDeleteModelAttachmentId )
			g_arActors.deleteEffect:Animate(0, 150, 0, false, true)
			g_controls:FindChild("PregameControls:ExitForm:BackBtn"):Enable(false)
		else
			self:OnLoadFromCharacter()
		end

	else -- couldn't delete
		local strResult = Apollo.GetString("CharacterSelect_DefaultDeleteError")
		if nDeleteResult == PreGameLib.CodeEnumCharacterModifyResults.DeleteFailed then -- failed for some reason
			strResult = Apollo.GetString("CharacterSelect_DefaultDeleteError")
		elseif nDeleteResult == PreGameLib.CodeEnumCharacterModifyResults.DeleteFailed_GuildMaster then -- failed for being a guild master
			strResult = Apollo.GetString("CharacterSelect_DeleteGuildMaster") .. " " .. tostring(nData) .. " " .. Apollo.GetString("CharacterSelect_DeleteGuildMaster2")
		elseif nDeleteResult == PreGameLib.CodeEnumCharacterModifyResults.DeleteFailed_CharacterOnline then -- failed for character still online
			strResult = Apollo.GetString("CharacterSelect_DeleteErrorFailedCharacterOnline")
		end

		local strTitle = Apollo.GetString("CharacterSelect_DeleteErrorTitle")
		self:PopupError(strResult, strTitle)

		self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetText("")
		self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetFocus()

	--[[	if g_arActors.primary then
			g_arActors.primary:Animate(0, knCheerAnimation, 0, false, true)
		end

		self.bDeleteError = true--]]
	end
end

function CharacterSelection:OnDeleteFailedTimer()
	self.wndDeleteError:Show(false)
end


function CharacterSelection:OnAnimationFinished( uActor, nLayer, nSequence )
	if g_arActors.deleteEffect and g_arActors.deleteEffect == uActor then
		g_arActors.deleteEffect = nil
		g_controls:FindChild("PregameControls:ExitForm:BackBtn"):Enable(true)
		self:OnLoadFromCharacter()
	end
	--[[
	elseif nSequence == knCheerAnimation and self.bDeleteError ~= nil and self.bDeleteError == true then -- error deleteing
		self.bDeleteError = false
		g_arActors.primary:Animate(0, 5638, 0, true, false)
	elseif nSequence == knCheerAnimation then -- cancelled delete
		g_arActors.primary:Animate(0, 5612, 0, true, false)
		self:OnLoadFromCharacter()
	end--]]
end

function CharacterSelection:OnCharacterSelectResult(nSelectResult)

	local strResult = Apollo.GetString("CharacterSelect_SelectErrorFailed")
	if nSelectResult == PreGameLib.CodeEnumCharacterSelectResults.FailedRename then -- failed because character needs rename
		strResult = Apollo.GetString("CharacterSelect_SelectErrorFailedRename")
	elseif nSelectResult == PreGameLib.CodeEnumCharacterSelectResults.FailedDisabled then -- failed because character is disabled
		strResult = Apollo.GetString("CharacterSelect_SelectErrorFailedDisabled")
	elseif nSelectResult == PreGameLib.CodeEnumCharacterSelectResults.FailedCharacterInWorld then -- failed because another character is still in the world.
		strResult = Apollo.GetString("CharacterSelect_SelectErrorFailedCharacterInWorld")
	end

	local strTitle = Apollo.GetString("CharacterSelect_SelectErrorTitle")
	self:PopupError(strResult, strTitle)
end


function CharacterSelection:OnCharacterRenameResult(nRenameResult, strName)

	if nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameOk then
		local tId = g_controls:FindChild("EnterBtn"):GetData()
		if tId ~= nil then
			g_arCharacters[tId].bRequiresRename = false
			g_arCharacters[tId].strName = strName
			
			if self.arItems[tId] then
				self.arItems[tId]:FindChild("CharacterName"):SetText(strName)
			end

			self:OnSelectCharacter(tId)
		end
		return
	end

	local strResult = Apollo.GetString("CharacterSelect_RenameErrorFailed")
	if nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_Internal then -- failed for some reason
		strResult = Apollo.GetString("CharacterSelect_RenameErrorFailedInternal")
	elseif nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_InvalidName then
		strResult = Apollo.GetString("CharacterSelect_RenameErrorFailedInvalidName")
	elseif nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_UniqueName then
		strResult = Apollo.GetString("CharacterSelect_RenameErrorFailedUniqueName")
	elseif nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_CharacterOnline then
		strResult = Apollo.GetString("CharacterSelect_RenameErrorFailedCharacterOnline")
	elseif nRenameResult == PreGameLib.CodeEnumCharacterModifyResults.RenameFailed_NoRename then
		strResult = Apollo.GetString("CharacterSelect_RenameErrorFailedNoRename")
	end

	local strTitle = Apollo.GetString("CharacterSelect_RenameErrorTitle")
	self:PopupError(strResult, strTitle)

end


---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

function CharacterSelection:OnMessageAck()
	self.CharacterSelectMsgDlg:Show(false)
end

function CharacterSelection:OnDeleteBtn()

	g_nState = LuaEnumState.Delete
	self.wndDelete:Show(true)
	self.wndTopPanel:FindChild("CharacterName"):Show(false)
	self.wndTopPanel:FindChild("CharacterNameBacker"):Show(false)
	self.wndCameraToggles:Show(false)
	g_controls:FindChild("EnterForm"):Show(false)
	self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetText("")
	self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetPrompt(g_arCharacters[g_controls:FindChild("EnterBtn"):GetData()].strName)
	self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetFocus()
	self.wndDelete:FindChild("Delete_ConfirmDeleteBtn"):Enable(false)
	self.wndDelete:FindChild("Delete_ConfirmDeleteBtn"):SetData(g_controls:FindChild("EnterBtn"):GetData())
	g_controls:FindChild("ExitForm"):FindChild("BackBtnLabel"):SetText(Apollo.GetString("CRB_Back"))
	self.wndSelectList:Show(false)

	PreGameLib.SetMusic(PreGameLib.CodeEnumMusic.CharacterDelete)

	if g_arActors.warningLight1 then
		g_arActors.warningLight1:Animate(0, 1071, 0, true, false)
	end

	if g_arActors.warningLight2 then
		g_arActors.warningLight2:Animate(0, 1071, 0, true, false)
	end

	if g_arActors.primary then
		g_arActors.primary:Animate(0, 5638, 0, true, false)
		g_arActors.primary:SetWeaponSheath(false)
	end
end

function CharacterSelection:OnCreateBtn()
	self.wndSelectList:Show(false)
	self.wndTopPanel:Show(false)
	self.wndCameraToggles:Show(false)

	-- call this from the main Character file
	PreGameLib.Event_FireGenericEvent("OpenCharacterCreateBtn")
end

function CharacterSelection:OnEnterKey()
	if g_controls:FindChild("EnterBtn"):GetData() ~= nil then
		self:OnSelectCharacter(g_controls:FindChild("EnterBtn"):GetData())
	end
end

function CharacterSelection:OnDeleteNameEscape(wndHandler, wndControl, strNew)
	local strName = self.wndDelete:FindChild("Delete_CharacterNameEntry"):GetText()

	if strName == nil or strName == "" then
		self:OnLoadFromCharacter()
	else
		self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetText("")
		self.wndDelete:FindChild("Delete_ConfirmDeleteBtn"):Enable(false)
		self.wndDelete:FindChild("Delete_CharacterNameEntry"):SetFocus()
	end
end

function CharacterSelection:OnDeleteNameChanged(wndHandler, wndControl, strNew)
	local strName = self.wndDelete:FindChild("Delete_CharacterNameEntry"):GetText()
	local nId = g_controls:FindChild("EnterBtn"):GetData()
	local tSelected = g_arCharacters[nId]
	local strDelete = tSelected.strName
	
	self.wndDelete:FindChild("Delete_ConfirmDeleteBtn"):Enable(string.lower(strName) == string.lower(strDelete))
end

function CharacterSelection:OnDeleteConfirm(wndHandler, wndControl)
	self.wndDelete:FindChild("Delete_ConfirmDeleteBtn"):Enable(false)
	self.nAttemptedDelete = g_controls:FindChild("EnterBtn"):GetData()
	CharacterScreenLib.DeleteCharacter(g_controls:FindChild("EnterBtn"):GetData())
end

function CharacterSelection:OnDeleteErrorClose(wndHandler, wndControl)
	Apollo.StopTimer("DeleteFailedTimer")
	self.wndDeleteError:Show(false)
end

function CharacterSelection:OnRenameConfirm(wndHandler, wndControl)
	self.wndRename:Show(false)
	if g_controls:FindChild("EnterBtn"):GetData() ~= nil then
		-- this can call CharacterRename result, so don't do anything to conflict with it
		CharacterScreenLib.RenameCharacter(g_controls:FindChild("EnterBtn"):GetData(),
										   self.wndRename:FindChild("RenameCharacterNameEntry"):GetText())
	end
end

function CharacterSelection:OnRenameNameChanged(wndHandler, wndControl)
	-- do something here to show number of characters / validation for name.
end

function CharacterSelection:OnRenameNameEscape(wndHandler, wndControl)
	self.wndRename:Show(false)
end


function CharacterSelection:OnRealmBtn(wndHandler, wndControl)
	CharacterScreenLib.ExitToRealmSelect()
end


---------------------------------------------------------------------------------------------------
-- CharacterSelection instance
---------------------------------------------------------------------------------------------------
local CharacterSelectionInst = CharacterSelection:new()
CharacterSelection:Init()
