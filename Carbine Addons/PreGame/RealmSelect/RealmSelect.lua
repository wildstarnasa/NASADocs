require "Window"
require "Apollo"
require "Sound"
require "PreGameLib"

---------------------------------------------------------------------------------------------------
-- RealmSelect module definition

local RealmSelect = {}



---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------
-- RealmSelect initialization
---------------------------------------------------------------------------------------------------
function RealmSelect:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

---------------------------------------------------------------------------------------------------
function RealmSelect:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- RealmSelect EventHandlers
---------------------------------------------------------------------------------------------------


function RealmSelect:OnLoad()
	self.xmlDocSatus = XmlDoc.CreateFromFile("UI\\Pregame\\ErrorScreen\\Status.xml")
	self.xmlDocRealmSelect = XmlDoc.CreateFromFile("RealmSelect.xml")

	math.randomseed( PreGameLib.GetTimeBasedSeed() )

	if PreGameLib.IsDemo() then
		return
	end

	self.tRealmWindowCache = {}
	self.bSortRealmListAsc = true
	self.strSortType = "Name"

	Apollo.RegisterEventHandler("RealmListChanged", "OnRealmListChanged", self)
	Apollo.RegisterEventHandler("AnimationFinished", "OnAnimationFinished", self)

	Apollo.RegisterEventHandler("NetworkStatus", "OnNetworkStatus", self)
	Apollo.RegisterTimerHandler("NetworkStatusTimer", "OnNetworkStatusTimer", self)

	--PreGameLib.uScene:SetBackground("UI\\Screens\\UI_CRB_LoginScreen.tex")
	PreGameLib.SetMusic( PreGameLib.CodeEnumMusic.Realm )

	self.wndNetworkStatus = Apollo.LoadForm(self.xmlDocSatus, "NetworkStatusMessage", nil, self)
	self.wndNetworkStatus:Show(false)

	self.wndSelectForm = Apollo.LoadForm(self.xmlDocRealmSelect, "RealmSelectForm", nil, self)
	self.wndTicker = Apollo.LoadForm(self.xmlDocRealmSelect, "MOTDTicker", nil, self)
	self.wndControlFrame = Apollo.LoadForm(self.xmlDocRealmSelect, "ControlFrame", nil, self)
	self.wndMOTD = self.wndSelectForm:FindChild("MOTD")
	self.wndMOTD:Show(false)
	self.nCurrentRealm = nil

	self.wndSortNameBtn = self.wndSelectForm:FindChild("SortNameBtn")
	self.wndSortTypeBtn = self.wndSelectForm:FindChild("SortTypeBtn")
	self.wndSortPopBtn = self.wndSelectForm:FindChild("SortPopBtn")
	self.wndSortNoteBtn = self.wndSelectForm:FindChild("SortNoteBtn")
	self.wndSortStatusBtn = self.wndSelectForm:FindChild("SortStatusBtn")
	self.wndRealmList = self.wndSelectForm:FindChild("RealmList")

	self.bInitialRealmCheck = false

	-- setup defaults, incase the assets change out from under us.
	PreGameLib.uScene:SetMap( 1559 );  -- this designates map.
	local setupPos = Vector3.New( -4118.33, -899.95, -484.485 )
	local cameraOffset = Vector3.New( 10, 0, 6 )
	local up = Vector3.New( 0, 1, 0)
	PreGameLib.uScene:SetCameraPosition( setupPos + cameraOffset, setupPos, up )
	PreGameLib.uScene:SetCameraFoVNearFar( 50, .1, 512 ) -- field of view, near plane and far plane settings for camera.  Can not set near plane to 0.  Setting a very small near plane causes graphic artifacts.

	PreGameLib.uScene:SetMapTimeOfDay( math.random( 1, 24 * 60 * 60 ) - 1 ) -- in seconds from midnight. New band now playing!

	self.tPosition = Vector3.New( -4133.13, 1899.31, -505.005 )

	self.camera = PreGameLib.uScene:AddActorByFile(1, "Art\\Prop\\Character_Creation\\Camera\\Camera_RealmSelect_000.m3")
	if self.camera then
		self.camera:SetPosition(1, self.tPosition, Vector3:Zero())
		self.camera:AttachCamera(6) -- ModelCamera_Cinematic
	end

	local strShipFile
	if math.random( 0, 1 ) == 0 then
		strShipFile = "Art\\Prop\\Constructed\\Ship\\ArkShip\\ArkShipExile\\PRP_Ship_ArkShip_Exterior_Exile_000.m3"
	else
		strShipFile = "Art\\Prop\\Constructed\\Ship\\ArkShip\\ArkShipDominion\\PRP_Ship_ArkShip_Exterior_Dominion_000.m3"
	end

	self.primary = PreGameLib.uScene:AddActorByFile(2, strShipFile)
	if self.primary then
		self.primary:AttachToActor( self.camera, 78 )
	end
end

function RealmSelect:OnRealmListChanged()

	local tList = RealmSelectScreenLib.GetRealmList()
	if not self.bInitialRealmCheck then
		local bHasCharacters = false

		for idx, tRealm in ipairs(tList) do
			if tRealm.nCount > 0 then
				bHasCharacters = true
			end

			if Apollo.GetConsoleVariable("login.realm") == tRealm.strName then
				self.nCurrentRealm = tRealm.nRealmId
			end
		end

		self.wndSelectForm:FindChild("RealmFilterBtnAll"):SetCheck(not bHasCharacters)
		self.wndSelectForm:FindChild("RealmFilterBtnMine"):SetCheck(bHasCharacters)

		self.wndSortNameBtn:SetCheck(true)

		self.bInitialRealmCheck = true
	end

	if self.wndSelectForm:FindChild("RealmFilterBtnPvE"):IsChecked() then
		self:FilterForPvE(tList)
	elseif self.wndSelectForm:FindChild("RealmFilterBtnPvP"):IsChecked() then
		self:FilterForPvP(tList)
	elseif self.wndSelectForm:FindChild("RealmFilterBtnMine"):IsChecked() then
		self:FilterForMine(tList)
	else -- assume "all"
		self:BuildListWindows(tList)
	end

	-- Realm message of the day
	self.arMessages = RealmSelectScreenLib.GetRealmMessages()
	self.nMsgCount = #self.arMessages
	if self.nMsgCount == 0 then
		self.wndMOTD:Show(false)
	else
		self.wndMOTD:Show(false)	-- set this to true to see the old boring way of showing realm motds
		self.iCurrentMessage = 1
		self:UpdateMessageButtons()
	end

	local strAllMessage = ""
	for _, strMessage in ipairs(PreGameLib.GetLastRealmMessages()) do
		strAllMessage = strAllMessage .. strMessage .. "\n"
	end
	self.wndTicker:SetText(strAllMessage)
	self.wndTicker:Show(true)
end

function RealmSelect:FilterForPvE(tList)
	local tFilteredList = {}

	for idx, tRealm in ipairs(tList) do
		if tRealm.nRealmPVPType ~= PreGameLib.CodeEnumRealmPVPType.PVP then
			table.insert(tFilteredList, tRealm)
		end
	end

	self:BuildListWindows(tFilteredList)
end

function RealmSelect:FilterForPvP(tList)
	local tFilteredList = {}

	for idx, tRealm in ipairs(tList) do
		if tRealm.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP then
			table.insert(tFilteredList, tRealm)
		end
	end

	self:BuildListWindows(tFilteredList)
end

function RealmSelect:FilterForMine(tList)
	local tFilteredList = {}

	for idx, tRealm in ipairs(tList) do
		if tRealm.nCount > 0 then
			table.insert(tFilteredList, tRealm)
		end
	end

	self:BuildListWindows(tFilteredList)
end

function RealmSelect:BuildListWindows(tList, tListMine)
	self.wndRealmList:DestroyChildren()
	self.wndRealmList:RecalculateContentExtents()

	self.btnSelected = nil

	local arPopulationStrings = {Apollo.GetString("RealmPopulation_Low"),
								 Apollo.GetString("RealmPopulation_Medium"),
								 Apollo.GetString("RealmPopulation_High"),
								 Apollo.GetString("RealmPopulation_Full") }

	for idx, tRealm in ipairs(tList) do
		self:HelperConfigureRealmEntry(tRealm)
	end

	self:SortList()

	----

	if self.btnSelected ~= nil then
		self.wndRealmList:SetRadioSelButton("SelectedRealm", self.btnSelected)
		self.wndRealmList:EnsureChildVisible(self.btnSelected)
		self:OnRealmSelect(self.btnSelected, self.btnSelected)
		self.wndSelectForm:FindChild("SelectBtn"):Enable(true)
	else
		self.wndSelectForm:FindChild("SelectBtn"):Enable(false)
	end

	self.wndSelectForm:SetFocus()
end

local tSortTypeFieldMap =
{	--Type	 =	 Order of table properities to sort on
	["Name"] = { "strName", "nRealmId" },
	["Type"] = { "nRealmPVPType", "strName" },
	["Note"] = { "strNote", "strName" },
	["Pop"] = { "nPopulation", "strName" },
	["Status"] = { "nRealmStatus", "strName" },
}

function RealmSelect:SortList()
	local this = self
	self.wndRealmList:ArrangeChildrenVert(0, function(wndLeft, wndRight)
		local tLeft = wndLeft:GetData()
		local tRight = wndRight:GetData()

		if (tLeft.nCount == 0 and tRight.nCount ~= 0) or (tLeft.nCount ~= 0 and tRight.nCount == 0) then
			return tLeft.nCount > tRight.nCount -- Realms with characters go to top
		end

		local fnSortListCompareData
		fnSortListCompareData = function(nLevel)
			local strProperity = tSortTypeFieldMap[self.strSortType][nLevel]
			if strProperity == nil then
				return true
			end

			if tLeft[strProperity] == tRight[strProperity] then
				return fnSortListCompareData(nLevel+1)
			end

			if self.bSortRealmListAsc then
				return tLeft[strProperity] < tRight[strProperity]
			end
			return tLeft[strProperity] > tRight[strProperity]
		end

		return fnSortListCompareData(1)
	end)
end

function RealmSelect:SortByCharacters(tSentList)
	local arCharacters = {}
	local arCharactersRev = {}
	local tList = {}

	for idx, tRealm in pairs(tSentList) do
		if arCharacters[tRealm.nCount+1] == nil then -- zero-indexed
			arCharacters[tRealm.nCount+1] = {}
		end

		table.insert(arCharacters[tRealm.nCount+1], tRealm)
	end

	for idx, tRealm in pairs(arCharacters) do
		table.insert(arCharactersRev, #arCharacters-idx, tRealm)
	end

	-- alphabetize and build
	for tIdx, tCharacters in pairs(arCharactersRev) do
		table.sort(tCharacters, function ( left, right ) return left.strName  < right.strName end)

		for entryIdx, tRealmEntry in pairs(tCharacters) do
			table.insert(tList, #tList+1, tRealmEntry)
		end
	end

	return tList
end

function RealmSelect:UpdateMessageButtons()
	self.wndMOTD:FindChild("Message"):SetText(self.arMessages[self.iCurrentMessage])
	self.wndMOTD:FindChild("Next"):Enable(self.nMsgCount > self.iCurrentMessage)
	self.wndMOTD:FindChild("Previous"):Enable(self.iCurrentMessage > 1)
end

function RealmSelect:OnPreviousMessage( wndHandler, wndControl, eMouseButton )
	self.iCurrentMessage = math.max(0, self.iCurrentMessage - 1)
	self:UpdateMessageButtons()
end

function RealmSelect:OnNextMessage( wndHandler, wndControl, eMouseButton )
	self.iCurrentMessage = math.min(self.nMsgCount, self.iCurrentMessage + 1)
	self:UpdateMessageButtons()
end

function RealmSelect:OnRealmSelect(wndHandler, wndControl)
	local arPopulationColors = {CColor.new(47/255, 1, 47/255, 1),		-- Green
								CColor.new(222/255, 157/255, 35/255, 1),-- Orange
								CColor.new(1, 47/255, 47/255, 1),		-- Red
								CColor.new(1, 47/255, 47/255, 1)}		-- Red

	for _, wndCurr in pairs(self.wndRealmList:GetChildren()) do
		if wndCurr and wndCurr:FindChild("RealmPopulation") and wndCurr:FindChild("Name") then
			local nPopulation = wndCurr:FindChild("RealmPopulation"):GetData()
			wndCurr:FindChild("RealmPopulation"):SetTextColor(arPopulationColors[nPopulation+1])
			wndCurr:FindChild("Name"):SetTextColor(ApolloColor.new("UI_BtnTextHoloPressed"))
		end
	end

	local nRealmId = wndControl:GetData().nRealmId
	local nPopulation = wndControl:FindChild("RealmPopulation"):GetData()
	wndControl:FindChild("RealmPopulation"):SetTextColor(arPopulationColors[nPopulation+1])

	wndControl:FindChild("Name"):SetTextColor(ApolloColor.new("UI_BtnTextHoloPressedFlyby"))
	RealmSelectScreenLib.SetCurrentRealm(nRealmId)
	self.wndSelectForm:FindChild("SelectBtn"):Enable(true)

end

function RealmSelect:HelperConfigureRealmEntry(tRealm)
	local strLoginRealm = Apollo.GetConsoleVariable("login.realm")
	local arPopulationStrings = {Apollo.GetString("RealmPopulation_Low"),
								 Apollo.GetString("RealmPopulation_Medium"),
								 Apollo.GetString("RealmPopulation_High"),
								 Apollo.GetString("RealmPopulation_Full") }

	local arPopulationColors = {CColor.new(47/255, 1, 47/255, 1),		-- Green
								CColor.new(222/255, 157/255, 35/255, 1),-- Orange
								CColor.new(1, 47/255, 47/255, 1),		-- Red
								CColor.new(1, 47/255, 47/255, 1)}		-- Red

	local wndItem = self:FactoryRealmCacheProduce(self.wndRealmList, "RealmItem", tRealm.strName)

	if tRealm.nPopulation <= #arPopulationStrings then
		wndItem:FindChild("RealmPopulation"):SetText(arPopulationStrings[tRealm.nPopulation+1])
		wndItem:FindChild("RealmPopulation"):SetData(tRealm.nPopulation)
		wndItem:FindChild("RealmPopulation"):SetTextColor(arPopulationColors[tRealm.nPopulation+1])
	end

	wndItem:FindChild("Name"):SetText(tRealm.strName)
	wndItem:FindChild("Name"):SetTextColor(ApolloColor.new("UI_BtnTextHoloPressed"))
	wndItem:SetData(tRealm)

	if tRealm.nRealmStatus == PreGameLib.CodeEnumRealmStatus.Up then
		wndItem:FindChild("RealmStatus"):FindChild("RealmStatus_Up"):Show(true)
	elseif tRealm.nRealmStatus == PreGameLib.CodeEnumRealmStatus.Standby then
		wndItem:FindChild("RealmStatus"):FindChild("RealmStatus_Standby"):Show(true)
	elseif tRealm.nRealmStatus == PreGameLib.CodeEnumRealmStatus.Down then
		wndItem:FindChild("RealmStatus"):FindChild("RealmStatus_Down"):Show(true)
	elseif tRealm.nRealmStatus == PreGameLib.CodeEnumRealmStatus.Offline then
		wndItem:FindChild("RealmStatus"):FindChild("RealmStatus_Offline"):Show(true)
	else
		wndItem:FindChild("RealmStatus"):FindChild("RealmStatus_Unknown"):Show(true)
	end

	if tRealm.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP then
		wndItem:FindChild("RealmType"):SetText(Apollo.GetString("RealmSelect_PvP"))
		wndItem:FindChild("RealmType"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
	else
		wndItem:FindChild("RealmType"):SetText(Apollo.GetString("RealmSelect_PvE"))
		wndItem:FindChild("RealmType"):SetTextColor(ApolloColor.new("UI_BtnTextHoloNormal"))
	end

	wndItem:FindChild("RealmNote"):SetText(tRealm.strNote)

	if tRealm.nCount > 0 or strLoginRealm == tRealm.strName then
		if strLoginRealm == tRealm.strName then
			self.btnSelected = wndItem
		end

		if tRealm.strLastPlayed ~= "" then
			local str = PreGameLib.String_GetWeaselString(Apollo.GetString("AccountServices_RealmNumCharacters"), tRealm.nCount)
			if tRealm.nCount > 0 then
				str = str .. " (" .. tRealm.strLastPlayed .. ")"
			end
			wndItem:FindChild("CharacterCount"):SetText(str)
		end

		wndItem:FindChild("CharacterIcon"):Show(tRealm.nCount > 0)
		wndItem:FindChild("CharacterCount"):Show(tRealm.nCount > 0)
	else
		wndItem:FindChild("CharacterCount"):Show(false)
		wndItem:FindChild("CharacterIcon"):Show(false)
	end

	wndItem:FindChild("VertSortContainer"):ArrangeChildrenVert(1)
	wndItem:FindChild("HorzSortContainer"):ArrangeChildrenHorz()
end


function RealmSelect:OnAnimationFinished(uActor, nSlot, nModelSequence)
	if uActor == self.primary and nModelSequence == 1109 then
		self.primary:Animate(0, 1120, 0, true, false)
		-- note - putting the realm select after the animation gives 1 frame where the ship is at the wrong spot. Fix it later for polish.
		RealmSelectScreenLib.SelectRealm()
	end
end

function RealmSelect:OnNetworkStatus( strStatus )
	if strStatus then
		self.wndNetworkStatus:FindChild("NetworkStatus_Body"):SetText( strStatus )
		if not self.wndNetworkStatus:IsShown() then
			Apollo.CreateTimer("NetworkStatusTimer", 2, false)
		end
	else
		Apollo.StopTimer("NetworkStatusTimer")
		self.wndNetworkStatus:Show(false)
	end
end

function RealmSelect:OnNetworkStatusTimer()
	self.wndNetworkStatus:Show(true)
end
---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

function RealmSelect:OnExitBtn()
	if self.nCurrentRealm ~= nil then
		RealmSelectScreenLib.SetCurrentRealm(self.nCurrentRealm)
		RealmSelectScreenLib.SelectRealm()
	end
end

function RealmSelect:OnSelectBtn()
	if self.primary and not self.bEnding then
		self.primary:Animate(0, 1109, 0, false, true)
		self.primary:SetDefaultSequence(1120)

		Sound.Play(Sound.PlayUIArkshipDominionWarp)
		self.wndSelectForm:FindChild("SelectBtn"):Enable(false)
		self.bEnding = true
	end
end

function RealmSelect:OnSortNameBtn(wndHandler, wndControl)
	self.bSortRealmListAsc = not self.bSortRealmListAsc
	self.strSortType = "Name"
	self:SortList()
end

function RealmSelect:OnSortTypeBtn(wndHandler, wndControl)
	self.bSortRealmListAsc = not self.bSortRealmListAsc
	self.strSortType = "Type"
	self:SortList()
end

function RealmSelect:OnSortPopBtn(wndHandler, wndControl)
	self.bSortRealmListAsc = not self.bSortRealmListAsc
	self.strSortType = "Pop"
	self:SortList()
end

function RealmSelect:OnSortStatusBtn(wndHandler, wndControl)
	self.bSortRealmListAsc = not self.bSortRealmListAsc
	self.strSortType = "Status"
	self:SortList()
end

function RealmSelect:OnSortNoteBtn(wndHandler, wndControl)
	self.bSortRealmListAsc = not self.bSortRealmListAsc
	self.strSortType = "Note"
	self:SortList()
end

---------------------------------------------------------------------------------------------------
-- Factory
---------------------------------------------------------------------------------------------------
function RealmSelect:FactoryRealmCacheProduce(wndParent, strFormName, strKey)
	local wnd = self.tRealmWindowCache[strKey]
	if not wnd or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDocRealmSelect, strFormName, wndParent, self)
		self.tRealmWindowCache[strKey] = wnd

		for strKey, wndCached in pairs(self.tRealmWindowCache) do
		if not self.tRealmWindowCache[strKey]:IsValid() then
				self.tRealmWindowCache[strKey] = nil
			end
		end
	end

	return wnd
end

---------------------------------------------------------------------------------------------------
-- RealmSelect instance
---------------------------------------------------------------------------------------------------
local RealmSelectInst = RealmSelect:new()
RealmSelect:Init()




