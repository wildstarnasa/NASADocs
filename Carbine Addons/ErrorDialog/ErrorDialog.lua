-- Client lua script
require "Window"
require "QuestLib"

---------------------------------------------------------------------------------------------------
-- ErrorDialog module definition
---------------------------------------------------------------------------------------------------
local ErrorDialog = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------
local knSaveVerison = 1

---------------------------------------------------------------------------------------------------
-- ErrorDialog initialization
---------------------------------------------------------------------------------------------------
function ErrorDialog:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	-- initialize our variables
	o.wnd = nil

	-- return our object
	return o
end

---------------------------------------------------------------------------------------------------
function ErrorDialog:Init()
	Apollo.RegisterAddon(self)
end

function ErrorDialog:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locReportBugLoc = self.wndReportBug and self.wndReportBug:GetLocation() or self.locReportBugLoc
	local locLuaError = self.wndErrorDialog and self.wndErrorDialog:GetLocation() or self.locAddonError
	
	local tSave =
	{
		tReportBugLoc = locReportBugLoc and locReportBugLoc:ToTable() or nil,
		tLuaErrorLoc = locLuaError and locLuaError:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function ErrorDialog:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		if tSavedData.tReportBugLoc then
			self.locReportBugLoc = WindowLocation.new(tSavedData.tReportBugLoc)
		end
		
		if tSavedData.tLuaErrorLoc then
			self.locAddonError = WindowLocation.new(tSavedData.tLuaErrorLoc)
		end
	end			
end

---------------------------------------------------------------------------------------------------
-- ErrorDialog EventHandlers
---------------------------------------------------------------------------------------------------
function ErrorDialog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ErrorDialog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ErrorDialog:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleReportBug", "ToggleWindow", self)
	Apollo.RegisterEventHandler("ToggleErrorDialog", "ToggleWindow", self)
	Apollo.RegisterEventHandler("ErrorDialogSetSelection", "SelectErrorType", self)
	Apollo.RegisterEventHandler("GameClickUnit", "OnGameClickUnit", self)
	Apollo.RegisterEventHandler("GameClickProp", "OnGameClickProp", self)
	Apollo.RegisterEventHandler("GameClickWorld", "OnGameClickWorld", self)
	Apollo.RegisterEventHandler("LuaError", "OnLuaError", self)
	Apollo.RegisterEventHandler("TicketToBugDialog", "OnBugOpen", self)

	-- load our forms
	self.wndReportBug = Apollo.LoadForm(self.xmlDoc, "ReportBugDialog", nil, self)
	self.wndReportBug:Show(false)
	--self.wndReportBug:FindChild("ShowQuestList"):AttachWindow(self.wndReportBug:FindChild("Flyout"))
	if self.locReportBugLoc then
		self.wndReportBug:MoveToLocation(self.locReportBugLoc)
	end
	--self.wndReportBug:FindChild("ShowQuestList"):AttachWindow(self.wndReportBug:FindChild("QuestList"))
	
	self.wndErrorDialog = nil

	self.tCats = GameLib.GetErrorCategories()
	self.idQuest = 0
	self.unitSelected = nil

	local wndCatList = self.wndReportBug:FindChild("Category")
	for idx, tCat in ipairs(self.tCats) do
		wndCatList:AddRow(tCat.strName, "", tCat)
	end
	wndCatList:SetCurrentRow(1)
	self:FillSubcategories()
end

function ErrorDialog:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_ReportBug"), {"InterfaceMenu_ToggleReportBug", "", "Icon_Windows32_UI_CRB_InterfaceMenu_ReportBug"})
end

function ErrorDialog:FillSubcategories()
	local wndCatList = self.wndReportBug:FindChild("Category")
	local wndSubcatList = self.wndReportBug:FindChild("SubCategory")
	local nRow = wndCatList:GetCurrentRow()
	if not nRow then
		return
	end

	local tCat = wndCatList:GetCellData(nRow, 1)
	if tCat == nil then
		return
	end

	local nSel = 1
	wndSubcatList:DeleteAll()
	for idx, tSub in ipairs(tCat.tSubCategories) do
		local nJustAdded = wndSubcatList:AddRow(tSub.strName, "", tSub)
		if tCat.idLastSub and tCat.idLastSub == tSub.nId then
			nSel = nJustAdded
		end
	end

	wndSubcatList:SetCurrentRow(nSel)
end

function ErrorDialog:OnGameClickUnit(unitClicked)
	self.unitSelected = unitClicked
	if unitClicked ~= nil then
		self.wndReportBug:FindChild("Unit"):SetText(unitClicked:GetName())
	else
		self.wndReportBug:FindChild("Unit"):SetText("")
	end
end

function ErrorDialog:OnGameClickWorld(tPos)
	local strFormatted = string.format("%.0f, %.0f, %.0f", tPos.x, tPos.y, tPos.z)
	self.wndReportBug:FindChild("WorldPosition"):SetText(strFormatted)
end

function ErrorDialog:OnGameClickProp(idProp)
	local strPropId = tostring(idProp)
	self.wndReportBug:FindChild("PropId"):SetText(strPropId)
end

function ErrorDialog:ShowErrorDialog(bShow)
	--[[
	self.TextEntry:SetText(Apollo.GetString("CRB_enter_description"))

	if (show == true) then
		self:PopulateTypeCombo()
	end
	--]]
	self.wndReportBug:Show(bShow)

	if bShow then
		
		local wndList = self.wndReportBug:FindChild("QuestList")
		wndList:DeleteAll()

		local nSelRow = 1
		local tEpisodeList = QuestLib.GetAllEpisodes(true, true)


		wndList:AddRow(Apollo.GetString("CRB_None"), "", 0)
		for idx, epiCurr in ipairs(tEpisodeList) do
			local tQuestList = epiCurr:GetVisibleQuests(true, true, true, true)
			if tQuestList ~= nil then
				for idx, queCurr in ipairs(tQuestList) do
					if queCurr:GetState() ~= Quest.QuestState_Unknown then
						local nRow = wndList:AddRow(queCurr:GetTitle(), "", queCurr:GetId())
						if queCurr:GetId() == self.idQuest then
							nSelRow = nRow
						end
					end
				end
			end
		end

		wndList:SetCurrentRow(nSelRow)

		self.wndReportBug:FindChild("Description"):SetFocus()

		-- make sure unit is still valid
		if self.unitSelected ~= nil then
			if not self.unitSelected:IsValid() then
				self.unitSelected = nil
				self.wndReportBug:FindChild("Unit"):SetText("")
			end
		end
	end
end

function ErrorDialog:OnCancelBtn()
	self.wndReportBug:Show(false)
end

function ErrorDialog:OnBugOpen(strText)
	self:ShowErrorDialog(true)
	self.wndReportBug:FindChild("Description"):SetText(strText)
end

---------------------------------------------------------------------------------------------------

function ErrorDialog:ToggleWindow()
	if self.wndReportBug:IsVisible() then
		self.wndReportBug:Show(false)
	else
		self:ShowErrorDialog(true)
	end
end

---------------------------------------------------------------------------------------------------

function ErrorDialog:OnLuaError(tAddon, strError, bCanIgnore)
	local strMessage = String_GetWeaselString(Apollo.GetString("LuaError_Oops"), tAddon.strName)
	if tAddon.bCarbine then
		strMessage = String_GetWeaselString(Apollo.GetString("LuaError_CarbineAddon"), strMessage)
	else
		strMessage = String_GetWeaselString(Apollo.GetString("LuaError_AddonAuthor"), strMessage, tAddon.strAuthor)
	end

	Print(String_GetWeaselString(Apollo.GetString("LuaError_DebugOutput"), tAddon.strName))

	if #tAddon.arErrors > 1 then
		return
	end

	local strPrompt = ""
	if bCanIgnore then
		strPrompt = Apollo.GetString("LuaError_YouMayIgnore")
	else
		strPrompt = Apollo.GetString("LuaError_AddonSuspended")
		wnd:FindChild("Ignore"):SetText(Apollo.GetString("CRB_Close"))
		wnd:FindChild("Suspend"):Enable(false)
	end

	if self.wndErrorDialog and self.wndErrorDialog:IsValid() then
		self.wndErrorDialog:Destroy()
	end
	
	self.wndErrorDialog = Apollo.LoadForm(self.xmlDoc, "AddonError", nil, self)
	self.wndErrorDialog:FindChild("Message"):SetText(String_GetWeaselString(strPrompt, strMessage))
	local strPartialError = string.sub(strError, 0, 1000)
	self.wndErrorDialog:FindChild("ErrorText"):SetText(strPartialError)
	self.wndErrorDialog:FindChild("CopyToClipboard"):SetActionData(GameLib.CodeEnumConfirmButtonType.CopyToClipboard, strPartialError)
	
	if self.locAddonError then
		self.wndErrorDialog:MoveToLocation(self.locAddonError)
	end

	self.wndErrorDialog:SetData(tAddon)

	self.wndErrorDialog:ToFront()
end

---------------------------------------------------------------------------------------------------
-- AddonError Functions
---------------------------------------------------------------------------------------------------

function ErrorDialog:OnSuspendAddon(wndHandler, wndControl)
	local tAddon = self.wndErrorDialog:GetData()
	Apollo.SuspendAddon(tAddon.strName)
	self.locAddonError = self.wndErrorDialog:GetLocation()
	self.wndErrorDialog:Destroy()
	self.wndErrorDialog = nil
end

function ErrorDialog:OnDisableAddon(wndHandler, wndControl, eMouseButton)
	local tAddon = self.wndErrorDialog:GetData()
	Apollo.SuspendAddon(tAddon.strName)
	Apollo.DisableAddon(tAddon.strName)
	self.locAddonError = self.wndErrorDialog:GetLocation()
	self.wndErrorDialog:Destroy()
	self.wndErrorDialog = nil
end

function ErrorDialog:OnIgnoreError(wndHandler, wndControl)
	self.locAddonError = self.wndErrorDialog:GetLocation()
	self.wndErrorDialog:Destroy()
	self.wndErrorDialog = nil
end

function ErrorDialog:OnCloseBtn(wndHandler, wndControl)
	self.locAddonError = self.wndErrorDialog:GetLocation()
	self.wndErrorDialog:Destroy()
	self.wndErrorDialog = nil
end

function ErrorDialog:OnCloseErrorWindow(wndHandler, wndControl)
	self.locAddonError = self.wndErrorDialog:GetLocation()
	wndHandler:Destroy()
end

---------------------------------------------------------------------------------------------------
-- ReportBugDialog Functions
---------------------------------------------------------------------------------------------------

function ErrorDialog:OnReportBug( wndHandler, wndControl, eMouseButton )
	local wndSubcatList = self.wndReportBug:FindChild("SubCategory")

	local nSubRow = wndSubcatList:GetCurrentRow()
	if not nSubRow then
		return
	end

	local tSub = wndSubcatList:GetCellData(nSubRow, 1)
	GameLib.ReportBug(tSub.nId, self.unitSelected, self.idQuest, self.wndReportBug:FindChild("Description"):GetText())
	self.wndReportBug:FindChild("Description"):SetText("")
	self.wndReportBug:Show(false)
end

function ErrorDialog:OnCategoryChanged()
	Sound.Play(Sound.PlayUIButtonHoloSmall)
	self:FillSubcategories()
end

function ErrorDialog:OnSubcategoryChanged()
	Sound.Play(Sound.PlayUIButtonHoloSmall)
	local wndCatList = self.wndReportBug:FindChild("Category")
	local wndSubcatList = self.wndReportBug:FindChild("SubCategory")

	local nCatRow = wndCatList:GetCurrentRow()
	if not nCatRow then
		return
	end

	local nSubRow = wndSubcatList:GetCurrentRow()
	if not nSubRow then
		return
	end

	local tCat = wndCatList:GetCellData(nCatRow, 1)
	local tSub = wndSubcatList:GetCellData(nSubRow, 1)
	tCat.idLastSub = tSub.nId
end

function ErrorDialog:OnInsertPosition(wndHandler, wndControl, eMouseButton)
	local strPos = String_GetWeaselString(Apollo.GetString("ErrorDialog_WorldPos"), self.wndReportBug:FindChild("WorldPosition"):GetText())
	self.wndReportBug:FindChild("Description"):InsertText(strPos)
	self.wndReportBug:FindChild("Description"):SetFocus()
end

function ErrorDialog:OnInsertPropId(wndHandler, wndControl, eMouseButton)
	local strId = String_GetWeaselString(Apollo.GetString("ErrorDialog_PropId"), self.wndReportBug:FindChild("PropId"):GetText())
	self.wndReportBug:FindChild("Description"):InsertText(strId)
	self.wndReportBug:FindChild("Description"):SetFocus()
end

function ErrorDialog:OnQuestChanged(wndHandler, wndControl)
	Sound.Play(Sound.PlayUIButtonHoloSmall)
	local wndList = self.wndReportBug:FindChild("QuestList")
	local wndListFrame = self.wndReportBug:FindChild("Flyout")

	local nRow = wndList:GetCurrentRow()
	if not nRow then
		return
	end

	self.idQuest = wndList:GetCellData(nRow, 1)
	self.wndReportBug:FindChild("QuestTitle"):SetText(wndList:GetCellText(nRow, 1))
	wndListFrame:Show(false)
	self.wndReportBug:FindChild("ShowQuestList"):SetCheck(false)
end

function ErrorDialog:OnClearUnit( wndHandler, wndControl, eMouseButton )
	self.unitSelected = nil
	self.wndReportBug:FindChild("Unit"):SetText("")
end

function ErrorDialog:OnDescriptionChanged(wndHandler, wndControl, strText)
	local nLength = string.len(strText)
	local strDesc = String_GetWeaselString(Apollo.GetString("ErrorDialog_TextCount"), Apollo.GetString("Description"), nLength)
	self.wndReportBug:FindChild("DescriptionLabel"):SetText(strDesc)

	if nLength > 500 then
		self.wndReportBug:FindChild("DescriptionLabel"):SetTextColor("red")
		self.wndReportBug:FindChild("ReportBugBtn"):Enable(false)
	else
		self.wndReportBug:FindChild("DescriptionLabel"):SetTextColor("white")
		self.wndReportBug:FindChild("ReportBugBtn"):Enable(true)
	end

end

function ErrorDialog:OnQuestListToggle(wndHandler, wndControl)
	local wndQuestListFrame = self.wndReportBug:FindChild("Flyout")
	local wndQuestList = wndQuestListFrame:FindChild("QuestList")
	local bIsShown = wndHandler:IsChecked()

	
	wndQuestListFrame:Show(bIsShown)
	wndQuestList:Show(bIsShown)
	
end

---------------------------------------------------------------------------------------------------
-- ErrorDialog instance
---------------------------------------------------------------------------------------------------
local ErrorDialogInst = ErrorDialog:new()
ErrorDialogInst:Init()
