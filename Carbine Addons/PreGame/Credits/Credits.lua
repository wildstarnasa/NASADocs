-----------------------------------------------------------------------------------------------
-- Client Lua Script for Credits
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Credits Module Definition
-----------------------------------------------------------------------------------------------
local Credits = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kScrollPixelsPerSec = 100
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Credits:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function Credits:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureButton, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Credits OnLoad
-----------------------------------------------------------------------------------------------
function Credits:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Credits.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Credits OnDocLoaded
-----------------------------------------------------------------------------------------------
function Credits:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "CreditsHolder", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.wndCredits = self.wndMain:FindChild("CreditsForm")
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("ShowCredits", "OnCreditsOn", self)

		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Credits Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/credits"
function Credits:OnCreditsOn()
	self.wndMain:Show(true) -- show the window
	self.wndCredits:DestroyChildren()
	
	self.tCredits = PreGameLib.GetCredits()
	if self.tCredits == nil then
		self.wndMain:Show(false, true)
	else
		self.nGroup = 1
		self.nPerson = 0
		self.tWindows = {}
		self:NextCredit()
	end
	
end

function Credits:NextCredit()
	local tMainClient = self.wndMain:GetClientRect()

	local tIdsToDestroy = {}
	for id,wnd in pairs(self.tWindows) do
		local loc = wnd:GetTransLocation()
		if loc:ToTable().nOffsets[4] < 0 then
			wnd:Destroy()
			tIdsToDestroy[id] = id
		end
	end
	for id,idx in pairs(tIdsToDestroy) do
		self.tWindows[id] = nil
	end
	
	local tGroup = self.tCredits[self.nGroup]
	if tGroup == nil then
		local fWait = tMainClient.nHeight / kScrollPixelsPerSec
		self.timer = ApolloTimer.Create(fWait, false, "CloseCredits", self)
		return
	end
	

		
	if self.nPerson == 0 then
		-- load up a group header
		local wnd = Apollo.LoadForm(self.xmlDoc, "CreditsHolder:CreditsForm:GroupHeader", self.wndCredits, self)
		wnd:SetText(tGroup.strGroupName)
		local tGroupClient = wnd:GetClientRect()
		
		local tLocBegin = {fPoints={0,0,1,0}, nOffsets={0, tMainClient.nHeight, 0, tMainClient.nHeight + tGroupClient.nHeight}}
		local tLocEnd = {fPoints={0,0,1,0}, nOffsets={0, -500, 0, -500 + tGroupClient.nHeight}}

		local locBegin = WindowLocation.new(tLocBegin)
		local locEnd = WindowLocation.new(tLocEnd)
		
		wnd:MoveToLocation(locBegin)
		wnd:TransitionMove(locEnd, tMainClient.nHeight / kScrollPixelsPerSec)
		
		local fWait = tGroupClient.nHeight / kScrollPixelsPerSec
		
		self.timer = ApolloTimer.Create(fWait, false, "NextCredit", self)
		self.nPerson = 1
		self.tWindows[wnd:GetId()] = wnd
		return
	end
	
	local tCredit = tGroup.arCredits[self.nPerson]
	if tCredit == nil then
		self.nPerson = 0
		self.nGroup = self.nGroup + 1
		self:NextCredit()
		return
	else
		if tCredit.strImage ~= "" then
			local wnd = Apollo.LoadForm(self.xmlDoc, "CreditsHolder:CreditsForm:ImageHolder", self.wndCredits, self)
			
			if tCredit.strImage == "CarbineLogo" then
				wnd:FindChild("ImageCarbineLogo"):Show(true)
			elseif tCredit.strImage == "NCSoftLogo" then
				wnd:FindChild("ImageNCSoftLogo"):Show(true)
			else
				local wndImg = wnd:FindChild("Image")
				wndImg:SetSprite(tCredit.strImage)
			end
	
			local tImageClient = wnd:GetClientRect()
			
			local tLocBegin = {fPoints={0,0,1,0}, nOffsets={0, tMainClient.nHeight, 0, tMainClient.nHeight + tImageClient .nHeight}}
			local tLocEnd = {fPoints={0,0,1,0}, nOffsets={0, -500, 0, -500 + tImageClient.nHeight}}
	
			local locBegin = WindowLocation.new(tLocBegin)
			local locEnd = WindowLocation.new(tLocEnd)
			
			wnd:MoveToLocation(locBegin)
			wnd:TransitionMove(locEnd, tMainClient.nHeight / kScrollPixelsPerSec)
			
			local fWait = tImageClient .nHeight / kScrollPixelsPerSec
			
			self.timer = ApolloTimer.Create(fWait, false, "NextCredit", self)
			self.nPerson = self.nPerson + 1
			self.tWindows[wnd:GetId()] = wnd
			return
		else
			local wnd = Apollo.LoadForm(self.xmlDoc, "CreditsHolder:CreditsForm:Person", self.wndCredits, self)
			local wndName = wnd:FindChild("Name")
			wndName:SetText(tCredit.strPersonName)
			local nMaxHeight = wndName:GetLocation():ToTable().nOffsets[4]
			for idx,strTitle in ipairs(tCredit.arTitles) do
				local wndTitle = wnd:FindChild("Title"..tostring(idx))
				if wndTitle ~= nil and (idx <= 1 or string.len(strTitle) > 0) then
					wndTitle:SetText(strTitle)
					nMaxHeight = wndTitle:GetLocation():ToTable().nOffsets[4]
				end
			end
			
			nMaxHeight = nMaxHeight + 2
			local tLocBegin = {fPoints={0,0,1,0}, nOffsets={0, tMainClient.nHeight, 0, tMainClient.nHeight + nMaxHeight}}
			local tLocEnd = {fPoints={0,0,1,0}, nOffsets={0, -500, 0, -500 + nMaxHeight}}
	
			local locBegin = WindowLocation.new(tLocBegin)
			local locEnd = WindowLocation.new(tLocEnd)
			
			wnd:MoveToLocation(locBegin)
			wnd:TransitionMove(locEnd, tMainClient.nHeight / kScrollPixelsPerSec)
			
			local fWait = nMaxHeight / kScrollPixelsPerSec
			
			self.timer = ApolloTimer.Create(fWait, false, "NextCredit", self)
			self.nPerson = self.nPerson + 1
			self.tWindows[wnd:GetId()] = wnd
			return
		end
	end
end

function Credits:CloseCredits()
	self.wndMain:DestroyChildren()
	self.wndMain:Show(false)
end

-----------------------------------------------------------------------------------------------
-- CreditsForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function Credits:OnOK()
	self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function Credits:OnCancel()
	self.wndMain:Show(false) -- hide the window
end


-----------------------------------------------------------------------------------------------
-- Credits Instance
-----------------------------------------------------------------------------------------------
local CreditsInst = Credits:new()
CreditsInst:Init()
z“íòóI‘êìÈú#nÇõòh≤ì&¡hdr™å/ê4)‰~Ük›	MØ€ÒºÔY±UOlk–î¸D6e7‘√ÚMyI]il*ÿU¨W†D†ÏÁPg e0Ì∞ÿ⁄ßã8[L‰ﬁ~‚8'ø∫◊'ﬂP‰ )Ò3WŸ<¥¿Û·4FŒÖè®Ó@?°1S=£ì`ÍœGcYÄ‡¢<w¸Ù¥)»Û¢:^ãõ`¡Eì˚≥ _OA}3ØÃ¡z]ç”gáÅx5‚`ÙEﬂ, CösÙeıbHÀ‡å%a[¸¡ÜQ,FAñ›˜ +∫µÜÆÑ‚Cu_,·/ñpÃx ≥m<	GR-3í“ﬂg‡"> ‰`ÃŒîw“≥.…·≈◊kÃï¡;Ø`XBóÊ˙7¶ø_`Ê™î	”d"#&=r†∞.Ÿx∫
á>CëøåévaHDÓêµ|d•ˆ ùrÇ–!Ñ.À`‘%<eR(ﬁ˘KbÜZLoDH£@É£
0∑‚óœºùfP„}O'øHΩp‰Jª∆=©\C
a§)`‹€[¯[ã ∂”r‰Ÿ[è[Èä†‘k1»œì øpVÈÇO;ˇ‹˚R17Cây„…QcùkväC”Ñ_ó<Q≤S5a6qEóöº⁄…JåÚµ¬´H[Q‡Pó‰ƒ≥FˆÁ.ôÈ¯ÁLääó√&Èg	™@\˛˘~à´∫/°≤Ë€Keıfö¨U$≥(∞»,éMÀ†î°3˙•™ÙPwìÈù|úI›ÉîËYv2ı1∆?í”{^ëKÆ>í˘∏»`3P\9tçÊ⁄Y#9.äÇ FÊú∂yWÂK.êÌ (f9Sv}EÔ
z™•6ôAJ÷cÕP∞æVuã\√ÍTh™^ƒ&:Ç∏Ó¥ÃÀ∏´≤∆„Ôj•ßg]Öü¶0ó∞y∞∫Ìr∏◊°´KhÄPâ˜¿›	Ω≠u@êíCj◊Y]‘Iqıõ”Ò7ß„Üπüj¨4\¯0~`à‰ß	?∫Òvz°›ã‚√0ûÂ®'A¡”FN‚w…˜xY«,ÃÚ†âßhÖˆ!a˝l$r— ›(ô`y‘‰ee§áç‘˛-S7M»¡}åq@ÔÔàZÇı`ÊIÅ{€¥ŒLaˆe°$3X*",‘√Ìèèç?€ÁsËÆöyñÑE≈†{¶£ªÃ±®z-¬|0èhzuˆûÎÙ2à∑9$”ÙÆ¥.®ûçã∂Ÿ˝€<z&OnGÚ—N˘H≤ÒFfîÄjÿπΩévXœ˘ˇPxá¢√ô◊£˝|
≤Ω0&qåKÚMíæ.∫=ÛÍ¡zLG£0ªÏà2ó"ëtá∏‰œl›€˛Ì4
B}â#ñåPòlJË’£Uõ\ñΩAÏ∆J….`lˇ.ÿOˇ÷˘Mæám!ÒçQúòÇål“oi¿˜áWXÉ0û’mFÒ∆˙ŸNÂ3…rZ˚6Ç÷õ6u⁄$ˇœÒàÿ¶këMOáÌ?£såñ≥ü¬Q~Ÿ7û))%ØqöàﬁHÿ,ü¯£cºŸH¶ÏÔc(eˇÓ‡Kep3+ëWÒEã⁄!ªç¸H∞ﬂ».\ÿ.–}˘\¯	yﬁkt)P˘P´gÉœÕiÇm˘"Î÷uÉ≈˜ø¯Ì˙÷Ã£ùoÅìå∞jào§Uq† 4©·æÊ≈E¿J%.f¥NÕ"∏ã≈‘©V:ålÕ’;RìıÃ…ø0th@~}A√æ1ÙæFW‹kJî3√ü≈ïó\¯	n»bìmÌk¸bUnt≈8æ»XêGpRÀ≤M9Å˙ÊÛ•∫?àÒ)ΩDbäA‚VÖWq»V÷ˇ|˙Í™/ +æ‰˝ 0˙ÈH tColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff">
            <Event Name="ButtonSignal" Function="OnCancelBtn"/>
        </Control>
        <Control Class="Button" Base="CRB_Basekit:kitBtn_Metal_LargeBlue" Font="CRB_Button" ButtonType="PushButton" RadioGroup="" LAnchorPoint="1" LAnchorOffset="-154" TAnchorPoint="1" TAnchorOffset="-79" RAnchorPoint="1" RAnchorOffset="-35" BAnchorPoint="1" BAnchorOffset="-31" DT_VCENTER="1" DT_CENTER="1" Name="ReportBugBtn" BGColor="ffffffff" TextColor="ffffffff" RelativeToClient="1" TextId="PlayerTicket_SubmitTicketBtn" TooltipColor="" NormalTextColor="UI_BtnTextBlueNormal" PressedTextColor="UI_BtnTextBluePressed" FlybyTextColor="UI_BtnTextBlueFlyby" PressedFlybyTextColor="UI_BtnTextBluePressedFlyby" DisabledTextColor="UI_BtnTextBlueDisabled" Text="">
            <Event Name="ButtonSignal" Function="OnReportBug"/>
        </Control>
    </Form>
</Forms>
yChange∞ ≥=Â˝ H H@owMap["PlayerTicketTextEntrySubject"]:SetFocus()
	self.tWindowMap["PlayerTicketTextEntrySubject"]:SetSel(0, -1)

	self:UpdateSubmitButton()
end

function PlayerTicketDialog:UpdateSubmitButton()
	local nCategory = self.tWindowMap["Category"]:GetCellData(self.tWindowMap["Category"]:GetCurrentRow(), 1)
	local nSubCategory = self.tWindowMap["SubCategory"]:GetCellData(self.tWindowMap["SubCategory"]:GetCurrentRow(), 1)
	local strText = self.tWindowMap["PlayerTicketTextEntry"]:GetText()
	local strTextSubject = self.tWindowMap["PlayerTicketTextEntrySubject"]:GetText()

	local bEnable = nCategory ~= nil and nSubCategory ~= nil and strText ~= nil and strText ~= "" and strTextSubject ~= nil and strTextSubject ~= ""
	self.tWindowMap["OkBtn"]:Enable(bEnable)
	if bEnable then
		self.tWindowMap["OkBtn"]:SetActionData(GameLib.CodeEnumConfirmButtonType.SubmitSupportTicket, nCategory, nSubCategory, strTextSubject, strText)
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
	if self.bAddIgnore and self.strTarget then
		FriendshipLib.AddByName(FriendshipLib.CharacterFriendshipType_Ignore, self.strTarget) 
		Event_FireGenericEvent("GenericEvent_SystemChannel