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
	o.wnd = nil
	
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
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("TogglePlayerTicketWindow", "ToggleWindow", self)
	Apollo.RegisterEventHandler("PlayerTicketSetSelection", "SelectPlayerTicketType", self)
	
	-- load our forms
	self.wndMain 				= Apollo.LoadForm(self.xmlDoc, "PlayerTicketDialog", nil, self)
	self.wndTextEntry 			= self.wndMain:FindChild("PlayerTicketTextEntry")
	self.wndCatList 			= self.wndMain:FindChild("Category")
	self.wndSubcatList 			= self.wndMain:FindChild("SubCategory")
	self.wndAcceptBtn 			= self.wndMain:FindChild("OkBtn")
	self.wndSubCategoryBlocker 	= self.wndMain:FindChild("SubCatBlocker")
	self.xmlDoc = nil
	
	self.wndMain:Show(false)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self.wndCatList:SetColumnText(1, Apollo.GetString("CRB_Category"))
	self.wndSubcatList:SetColumnText(1, Apollo.GetString("ErrorDialog_SubcatTitle"))
	
	self.bIsBug = false
end

function PlayerTicketDialog:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_SubmitTicket"), {"TogglePlayerTicketWindow", "", "Icon_Windows32_UI_CRB_InterfaceMenu_SupportTicket"})
end

function PlayerTicketDialog:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_SubmitTicket")})
end

function PlayerTicketDialog:ToggleWindow()
	if self.wndMain:IsVisible() then
		self.wndMain:Show(false)
	else
		self:PopulateTypePicker()
	end
end

function PlayerTicketDialog:PopulateTypePicker()
	local tListOfEntries = PlayerTicket_GetErrorTypeList()	
	self.wndCatList:DeleteAll()
	self.wndSubcatList:DeleteAll()	
	self.wndTextEntry:SetText(kstrEnterTicket)
	self.wndTextEntry:SetTextColor(ApolloColor.new("UI_TextHoloBodyCyan"))
	self.wndTextEntry:Enable(false)
	self.wndAcceptBtn:Enable(false)
	self.wndSubCategoryBlocker:Show(true)
	
	self.nMainRowCount = 0
	for idx, CurrentError in ipairs (tListOfEntries) do
		local iRow = self.wndCatList:AddRow(CurrentError.localizedText, "", CurrentError.index)
	end
	
	self.wndMain:Show(true)
end

function PlayerTicketDialog:PopulateSubtypeCombo()
	local iRow = self.wndCatList:GetCurrentRow()
	local index = self.wndCatList:GetCellData(iRow, 1)
	self.wndSubcatList:DeleteAll()		

	local nRows = 0
	local tListOfSubentries = PlayerTicket_GetSubtype(index)	
	for idx, CurrentSubError in ipairs (tListOfSubentries) do
		local wndNewRow = self.wndSubcatList:AddRow(CurrentSubError.localizedText, "", CurrentSubError.index)
		nRows = nRows + 1
	end
	
	if nRows > 0 then
		if self.wndTextEntry:GetText() == kstrEnterTicket then
			self.wndTextEntry:SetText("")
		end	
		
		self.wndSubcatList:SetCurrentRow(1)	
		self.wndTextEntry:SetTextColor(ApolloColor.new("UI_TextHoloBody"))
		self.wndTextEntry:Enable(true)
		self.wndSubCategoryBlocker:Show(false)
		self.wndAcceptBtn:Enable(self.wndTextEntry:GetText() ~= nil and self.wndTextEntry:GetText() ~= "")
		self.wndTextEntry:SetFocus()
		self.wndTextEntry:SetSel(0, -1)	
	else	
		self.wndTextEntry:SetText(kstrEnterTicket)
		self.wndTextEntry:SetTextColor(ApolloColor.new("UI_TextHoloBodyCyan"))
		self.wndTextEntry:Enable(false)	
		self.wndAcceptBtn:Enable(false)		
		self.wndSubCategoryBlocker:Show(true)
	end
	
	--Bug category is index 4.  Yup, this is pretty ugly.
	if iRow == 4 then
		self.wndAcceptBtn:Enable(true)
		self.wndAcceptBtn:SetText(Apollo.GetString("InterfaceMenu_ReportBug"))
		self.bIsBug = true
	else
		self.wndAcceptBtn:SetText(Apollo.GetString("PlayerTicket_SendTicketBtn"))
		self.bIsBug = false
	end
end

function PlayerTicketDialog:OnSubcategoryChanged()
	self.wndTextEntry:SetFocus()
	self.wndTextEntry:SetSel(0, -1)	
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnOkBtn(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	--PlayerTicketDialog_Report (self.PlayerTicketTypeCombo:GetSelectedData (), self.PlayerTicketSubType:GetSelectedData (), self.wndTextEntry:GetText())
	local nCategory = self.wndCatList:GetCellData(self.wndCatList:GetCurrentRow(), 1)
	local nSubCategory = self.wndSubcatList:GetCellData(self.wndSubcatList:GetCurrentRow(), 1)
	
	
	
	if self.bIsBug then
		local strText = self.wndTextEntry:GetText()
		Event_FireGenericEvent("TicketToBugDialog", strText)
		self.bIsBug = false
	elseif nCategory ~= nil and nSubCategory ~= nil then
		PlayerTicketDialog_Report (nCategory, nSubCategory, self.wndTextEntry:GetText())
	end
	
	self.wndMain:Close()
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnCancelBtn(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	self.wndMain:Show(false)
end

---------------------------------------------------------------------------------------------------
function PlayerTicketDialog:OnTextChanged()
	self.wndAcceptBtn:Enable(self.wndTextEntry:GetText() ~= nil and self.wndTextEntry:GetText() ~= "")
end



---------------------------------------------------------------------------------------------------
-- PlayerTicketDialog instance
---------------------------------------------------------------------------------------------------
local PlayerTicketDialogInst = PlayerTicketDialog:new()
PlayerTicketDialogInst:Init()
