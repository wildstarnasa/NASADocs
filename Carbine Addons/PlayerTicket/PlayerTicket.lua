-- Client lua script
require "Window"

---------------------------------------------------------------------------------------------------
-- PlayerTicketDialog module definition
---------------------------------------------------------------------------------------------------
local PlayerTicketDialog = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------
local kstrCellNormal = "CRB_Basekit:kitBtn_HoloNormal"
local kstrCellNormalFocus = "CRB_Basekit:kitBtn_HoloFlyby"
local kstrCellSelected = "CRB_Basekit:kitBtn_HoloPressed"
local kstrCellSelectedFocus = "CRB_Basekit:kitBtn_HoloPressedFlyby"

local kstrEnterTicket = Apollo.GetString("PlayerTicket_ChooseCategory")

---------------------------------------------------------------------------------------------------
-- PlayerTicketDialog initialization
---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	-- initialize our variables
	o.tWindowMap = {}
	o.bIsBug = false

	-- return our object
	return o
end

function PlayerTicketDialog:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- PlayerTicketDialog EventHandlers
---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PlayerTicket.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function PlayerTicketDialog:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 			"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 				"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("GenericEvent_OpenReportPlayerTicket", 	"OnGenericEvent_OpenReportPlayerTicket", self) -- Does ToggleWindow with a preselection
	Apollo.RegisterEventHandler("TogglePlayerTicketWindow", 			"ToggleWindow", self)
	Apollo.RegisterEventHandler("PlayerTicketSetSelection", 			"SelectPlayerTicketType", self)

	-- load our forms
	local wndMain = Apollo.LoadForm(self.xmlDoc, "PlayerTicketDialog", nil, self)
	self.tWindowMap =
	{
		["Main"] = wndMain,
		["PlayerTicketTextEntry"] = wndMain:FindChild("PlayerTicketTextEntry"),
		["Category"] = wndMain:FindChild("Category"),
		["SubCategory"] = wndMain:FindChild("SubCategory"),
		["OkBtn"] = wndMain:FindChild("OkBtn"),
		["SubCatBlocker"] = wndMain:FindChild("SubCatBlocker"),
		["ConvertToBugBtn"] = wndMain:FindChild("ConvertToBugBtn")
	}

	self.xmlDoc = nil

	self.tWindowMap["Main"]:Show(false)

	if self.locSavedWindowLoc then
		self.tWindowMap["Main"]:MoveToLocation(self.locSavedWindowLoc)
	end

	self.tWindowMap["Category"]:SetColumnText(1, Apollo.GetString("CRB_Category"))
	self.tWindowMap["SubCategory"]:SetColumnText(1, Apollo.GetString("ErrorDialog_SubcatTitle"))
end

function PlayerTicketDialog:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_SubmitTicket"), {"TogglePlayerTicketWindow", "", "Icon_Windows32_UI_CRB_InterfaceMenu_SupportTicket"})
end

function PlayerTicketDialog:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.tWindowMap["Main"], strName = Apollo.GetString("InterfaceMenu_SubmitTicket")})
end

function PlayerTicketDialog:OnGenericEvent_OpenReportPlayerTicket(strMessage)
	self:PopulateTypePicker()
	self.tWindowMap["Category"]:SetCurrentRow(2)
	self.tWindowMap["PlayerTicketTextEntry"]:SetText(strMessage or "")
	self:PopulateSubtypeCombo() -- After picking a Category
end

function PlayerTicketDialog:ToggleWindow()
	if self.tWindowMap["Main"]:IsVisible() then
		self.tWindowMap["Main"]:Show(false)
	else
		self:PopulateTypePicker()
	end
end

function PlayerTicketDialog:PopulateTypePicker()
	local tListOfEntries = PlayerTicket_GetErrorTypeList()
	self.tWindowMap["Category"]:DeleteAll()
	self.tWindowMap["SubCategory"]:DeleteAll()
	self.tWindowMap["PlayerTicketTextEntry"]:SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.PlayerTicketText))
	self.tWindowMap["PlayerTicketTextEntry"]:SetText(kstrEnterTicket)
	self.tWindowMap["PlayerTicketTextEntry"]:SetTextColor(ApolloColor.new("UI_TextHoloBodyCyan"))
	self.tWindowMap["PlayerTicketTextEntry"]:Enable(false)
	self.tWindowMap["OkBtn"]:Enable(false)
	self.tWindowMap["SubCatBlocker"]:Show(true)

	self.nMainRowCount = 0
	for idx, CurrentError in ipairs(tListOfEntries) do
		local iRow = self.tWindowMap["Category"]:AddRow(CurrentError.localizedText, "", CurrentError.index)
	end

	self.tWindowMap["Main"]:Show(true)
end

function PlayerTicketDialog:PopulateSubtypeCombo()
	local iRow = self.tWindowMap["Category"]:GetCurrentRow()
	local index = self.tWindowMap["Category"]:GetCellData(iRow, 1)
	self.tWindowMap["SubCategory"]:DeleteAll()

	local nRows = 0
	local tListOfSubentries = PlayerTicket_GetSubtype(index)
	for idx, CurrentSubError in ipairs (tListOfSubentries) do
		local wndNewRow = self.tWindowMap["SubCategory"]:AddRow(CurrentSubError.localizedText, "", CurrentSubError.index)
		nRows = nRows + 1
	end

	if nRows > 0 then
		if self.tWindowMap["PlayerTicketTextEntry"]:GetText() == kstrEnterTicket then
			self.tWindowMap["PlayerTicketTextEntry"]:SetText("")
		end

		self.tWindowMap["SubCategory"]:SetCurrentRow(1)
		self.tWindowMap["PlayerTicketTextEntry"]:SetTextColor(ApolloColor.new("UI_TextHoloBody"))
		self.tWindowMap["PlayerTicketTextEntry"]:Enable(true)
		self.tWindowMap["SubCatBlocker"]:Show(false)
		self.tWindowMap["OkBtn"]:Enable(self.tWindowMap["PlayerTicketTextEntry"]:GetText() ~= nil and self.tWindowMap["PlayerTicketTextEntry"]:GetText() ~= "")
		self.tWindowMap["PlayerTicketTextEntry"]:SetFocus()
		self.tWindowMap["PlayerTicketTextEntry"]:SetSel(0, -1)
	else
		self.tWindowMap["PlayerTicketTextEntry"]:SetText(kstrEnterTicket)
		self.tWindowMap["PlayerTicketTextEntry"]:SetTextColor(ApolloColor.new("UI_TextHoloBodyCyan"))
		self.tWindowMap["PlayerTicketTextEntry"]:Enable(false)
		self.tWindowMap["OkBtn"]:Enable(false)
		self.tWindowMap["SubCatBlocker"]:Show(true)
	end

	--Bug category is index 4.  Yup, this is pretty ugly.
	if iRow == 4 then
		self.tWindowMap["OkBtn"]:Enable(true)
		self.tWindowMap["OkBtn"]:SetText(Apollo.GetString("InterfaceMenu_ReportBug"))
		self.bIsBug = true
	else
		self.tWindowMap["OkBtn"]:SetText(Apollo.GetString("PlayerTicket_SendTicketBtn"))
		self.bIsBug = false
	end

	self:UpdateSubmitButton()
end

function PlayerTicketDialog:OnSubcategoryChanged()
	self.tWindowMap["PlayerTicketTextEntry"]:SetFocus()
	self.tWindowMap["PlayerTicketTextEntry"]:SetSel(0, -1)

	self:UpdateSubmitButton()
end

function PlayerTicketDialog:UpdateSubmitButton()
	local nCategory = self.tWindowMap["Category"]:GetCellData(self.tWindowMap["Category"]:GetCurrentRow(), 1)
	local nSubCategory = self.tWindowMap["SubCategory"]:GetCellData(self.tWindowMap["SubCategory"]:GetCurrentRow(), 1)
	local strText = self.tWindowMap["PlayerTicketTextEntry"]:GetText()

	local bEnable = nCategory ~= nil and nSubCategory ~= nil and strText ~= nil and strText ~= ""
	self.tWindowMap["OkBtn"]:Enable(bEnable)
	if bEnable then
		self.tWindowMap["OkBtn"]:SetActionData(GameLib.CodeEnumConfirmButtonType.SubmitSupportTicket, nCategory, nSubCategory, strText)
	end

	if self.bIsBug ~= not self.tWindowMap["OkBtn"]:IsShown() then
		self.tWindowMap["OkBtn"]:Show(not self.bIsBug)
	end

	if self.bIsBug ~= self.tWindowMap["ConvertToBugBtn"]:IsShown() then
		self.tWindowMap["ConvertToBugBtn"]:Show(self.bIsBug)
	end
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnSupportTicketSubmitted(wndHandler, wndControl, eMouseButton)
	self:UpdateSubmitButton()
	self.tWindowMap["Main"]:Close()
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnConvertToBugBtn(wndHandler, wndControl, eMouseButton)
	if self.bIsBug then
		local strText = self.tWindowMap["PlayerTicketTextEntry"]:GetText()
		Event_FireGenericEvent("TicketToBugDialog", strText)
		self.bIsBug = false
	end

	self:UpdateSubmitButton()
	self.tWindowMap["Main"]:Close()
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnCancelBtn(wndHandler, wndControl, eMouseButton)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	self.tWindowMap["Main"]:Show(false)
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnTextChanged()
	self:UpdateSubmitButton()
end

---------------------------------------------------------------------------------------------------
-- PlayerTicketDialog instance
---------------------------------------------------------------------------------------------------
local PlayerTicketDialogInst = PlayerTicketDialog:new()
PlayerTicketDialogInst:Init()
