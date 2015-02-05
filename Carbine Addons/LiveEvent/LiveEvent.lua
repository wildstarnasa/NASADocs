-----------------------------------------------------------------------------------------------
-- Client Lua Script for LiveEvent
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "LiveEventsLib"
require "LiveEvent"

local LiveEvent = {}

local tSpecificEventData =
{
	eCurrency 			= Money.CodeEnumCurrencyType.ShadeSilver,
	strCurrencyTitle	= Apollo.GetString("LiveEvent_YourShadeSilver"),
	strCurrencyTooltip	= Apollo.GetString("LiveEvent_ShadeSilverTooltip"),
}

function LiveEvent:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function LiveEvent:Init()
	Apollo.RegisterAddon(self)
end

function LiveEvent:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LiveEvent.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function LiveEvent:OnDocLoaded()
	Apollo.RegisterEventHandler("PlayerCurrencyChanged",  	"OnPlayerCurrencyChanged", self)
	Apollo.RegisterEventHandler("LiveEvent_ToggleWindow", 	"OnLiveEvent_ToggleWindow", self)
	Apollo.RegisterTimerHandler("LiveEvent_UpdateTimer", 	"UpdateList", self)
	Apollo.CreateTimer("LiveEvent_UpdateTimer", 10, true)
	Apollo.StopTimer("LiveEvent_UpdateTimer")

	self.wndMain = nil
end

function LiveEvent:OnLiveEvent_ToggleWindow()
	if self.wndMain and self.wndMain:IsValid() then
		Apollo.StopTimer("LiveEvent_UpdateTimer")
		self.wndMain:Destroy()
		self.wndMain = nil
	else
		local tEventData = LiveEventsLib.GetLiveEvent(8) -- TODO: Hardcoded for Shade's Eve
		if not tEventData or not tEventData:GetId() then
			return
		end

		Apollo.StartTimer("LiveEvent_UpdateTimer")

		self.wndMain = Apollo.LoadForm(self.xmlDoc , "LiveEventMain", nil, self)
		self.wndMain:FindChild("LiveTabProgressBtn"):AttachWindow(self.wndMain:FindChild("LiveEventProgressScroll"))
		self.wndMain:FindChild("LiveTabSummaryBtn"):AttachWindow(self.wndMain:FindChild("LiveEventSummaryScroll"))

		self.wndMain:FindChild("LiveEventSummaryText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff56b381\">"..tEventData:GetSummary().."</P>")
		self.wndMain:FindChild("LiveEventSummaryText"):SetHeightToContentHeight()
		self.wndMain:FindChild("LiveEventSummaryScroll"):ArrangeChildrenVert(0)

		self:UpdateList()
	end
end

function LiveEvent:UpdateList() -- Also from one second timer
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	-- Build Scroll Bar
	local wndScroll = self.wndMain:FindChild("LiveEventProgressScroll")
	local nScrollPos = wndScroll:GetVScrollPos()
	wndScroll:DestroyChildren()

	for idx, peEvent in pairs(PublicEvent.GetActiveEvents() or {}) do
		if peEvent and peEvent:GetEventType() == PublicEvent.PublicEventType_LiveEvent then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "LiveEventItem", wndScroll, self)
			wndCurr:FindChild("LiveEventTitle"):SetAML("<P Font=\"CRB_HeaderSmall\" TextColor=\"UI_WindowTitleYellow\">"..peEvent:GetName().."</P>")
			wndCurr:FindChild("LiveEventHintBtn"):SetData(peEvent)

			-- Now Objectives
			for nObjectiveIdx, peoObjective in pairs(peEvent:GetObjectives() or {}) do
				if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active and not peoObjective:IsHidden() then
					local wndObj = Apollo.LoadForm(self.xmlDoc, "LiveObjectiveItem", wndCurr:FindChild("LiveObjectiveContainer"), self)
					wndObj:FindChild("LiveObjectiveHintBtn"):SetData({ peEvent = peEvent, nObjectiveIdx = nObjectiveIdx })
					wndObj:FindChild("LiveObjectiveText"):SetAML(self:BuildEventObjectiveTitleString(peoObjective))

					local nTextWidth, nTextHeight = wndObj:FindChild("LiveObjectiveText"):SetHeightToContentHeight()
					local nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
					wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight + 10)
				end
			end

			local nObjectiveContainerHeight = wndCurr:FindChild("LiveObjectiveContainer"):ArrangeChildrenVert(0)
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			wndCurr:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nObjectiveContainerHeight + 35)
		end
	end
	wndScroll:ArrangeChildrenVert(0)
	wndScroll:SetVScrollPos(nScrollPos)

	self:OnPlayerCurrencyChanged()
end

function LiveEvent:OnPlayerCurrencyChanged()
	if self.wndMain and self.wndMain:IsValid() then
		-- Build Currency
		self.wndMain:FindChild("LiveEventCashWindow"):SetMoneySystem(tSpecificEventData.eCurrency)
		self.wndMain:FindChild("LiveEventCashWindow"):SetAmount(GameLib.GetPlayerCurrency(tSpecificEventData.eCurrency):GetAmount())
		self.wndMain:FindChild("LiveEventCashWindow"):SetTooltip(tSpecificEventData.strCurrencyTooltip)
		self.wndMain:FindChild("LiveEventCashTitle"):SetText(tSpecificEventData.strCurrencyTitle)
	end
end

function LiveEvent:OnLiveEventHintBtn(wndHandler, wndControl)
	wndHandler:GetData():ShowHintArrow()
end

function LiveEvent:OnLiveObjectiveHintBtn(wndHandler, wndControl)
	local peEvent = wndHandler:GetData().peEvent
	peEvent:ShowHintArrow(wndHandler:GetData().nObjectiveIdx)
end

function LiveEvent:OnLiveEventClose(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if self.wndMain and self.wndMain:IsValid() then
		Apollo.StopTimer("LiveEvent_UpdateTimer")
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function LiveEvent:BuildEventObjectiveTitleString(peoObjective)
	-- Use short form or reward text if possible
	local strResult = ""
	local strShortText = peoObjective:GetShortDescription()
	if strShortText and string.len(strShortText) > 0 then
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strShortText)
	else
		strResult = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", peoObjective:GetDescription())
	end

	-- Progress Brackets and Time if Active
	if peoObjective:GetStatus() == PublicEventObjective.PublicEventStatus_Active then
		local nCompleted = peoObjective:GetCount()
		local eCategory = peoObjective:GetCategory()
		local eType = peoObjective:GetObjectiveType()
		local nNeeded = peoObjective:GetRequiredCount()

		-- Prefix Brackets
		local strPrefix = ""
		if nNeeded == 0 and (eType == PublicEventObjective.PublicEventObjectiveType_Exterminate or eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits) then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), Apollo.FormatNumber(nCompleted, 0, true)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_DefendObjectiveUnits and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", String_GetWeaselString(Apollo.GetString("QuestTracker_Remaining"), Apollo.FormatNumber(nCompleted - nNeeded + 1, 0, true)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_Turnstile then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), Apollo.FormatNumber(math.abs(nCompleted - nNeeded), 0, true)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_ParticipantsInTriggerVolume then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s </T>", String_GetWeaselString(Apollo.GetString("QuestTracker_WaitingForMore"), Apollo.FormatNumber(math.abs(nCompleted - nNeeded), 0, true)))
		elseif eType == PublicEventObjective.PublicEventObjectiveType_TimedWin then
			-- Do Nothing
		elseif nNeeded > 1 and not peoObjective:ShowPercent() and not peoObjective:ShowHealthBar() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\">%s</T>", String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), Apollo.FormatNumber(nCompleted, 0, true), Apollo.FormatNumber(nNeeded, 0, true)))
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		end

		-- Prefix Time
		if peoObjective:IsBusy() then
			strPrefix = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</T>", kstrYellow, Apollo.GetString("QuestTracker_Paused"))
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
			strPrefix = ""
		elseif peoObjective:GetTotalTime() > 0 then
			local strColorOverride = peoObjective:GetObjectiveType() == PublicEventObjective.PublicEventObjectiveType_TimedWin and kstrGreen or nil
			local nTime = math.max(0, math.floor((peoObjective:GetTotalTime() - peoObjective:GetElapsedTime()) / 1000))
			strResult = self:HelperPrefixTimeString(nTime, strResult, strColorOverride)
		end

		if strPrefix ~= "" then
			strResult = String_GetWeaselString(Apollo.GetString("QuestTracker_BuildText"), strPrefix, strResult)
		end
	end
	return "<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff56b381\">"..strResult.."</P>"
end

local LiveEventInst = LiveEvent:new()
LiveEventInst:Init()
ss="Window" LAnchorPoint="0" LAnchorOffset="66" TAnchorPoint=".6" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="-4" BAnchorPoint="1" BAnchorOffset="-9" RelativeToClient="1" Font="CRB_InterfaceMedium_B" Text="" Name="SalvageListItemType" TextId="Challenges_NoProgress" BGColor="ffffffff" TextColor="UI_TextHoloBodyCyan" DT_VCENTER="1" DT_WORDBREAK="1" TooltipColor=""/>
        </Control>
    </Form>
</Forms>
øSÂ|5©Döñ‘ğpj;V³¿~„òşÑï3Ë?áÏ¿7+ûSÃ0¯]áuéë<ûo¥+ç_1c~ÇãÓDäşŠx†¼d:²É¦ ò­Ä‚J„‰áëF„›‚¥Aô{"ü‘`9úü0æsŒ1ÆcŒ1ÆcŒ1ÆcŒ1Æãsƒÿ?&x¬Ê      ³ °:åı H H@èAç9ÿÿÿÿ        èAç9ÿÿÿÿ ñ¤I’$(BÇ9/¿ÿÿ'œà–¹$ªRç9
¯õUJ
œàRw—˜Mk(B
¯½µ€@¦ğñ„,c+/--Ø–1éóœqŒ-©‰ÙÓ¬#ÇbºóœÓœ«©©©ÙÓ±çTIÕóœóœ    Ø•˜ƒ5P4ÓœqŒzzbb?‹ÕZ/:„,càèxxPĞ¨µ¬_'Mk(B èş^.Ğ8Ööó$ËZèA úWU X_'I’$IJç9è_UU        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ(1y•WªRèA%%55{1ïğ1•w„ëZ/--½Øz&`
/™»óœ0„‹-õÙ   m›$Óœ’”ÿ UÙ   m›$ÓœqŒ ª ×q Õ¤_?²”Ï{€ààzu(X/ö¢³>ï{ëZxxx^$à£>sB'ŠRç9xX\^        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ y‘xÉ›äIJç9-5µÕW¥àRw™»Mk(B
+¯õ~1Pnv›ü„ëZ«ÿÕA °m¶$0„,c ªÿU‚@ °m¶$0„,c ªÿU|,€¸±­ÿ'ï{ëZ€èşWK	-ö¬S?Mk(Bèø~_ `2'N’$(Bç9øüÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ ï›I’$IJç9/½UU)à’ù$ªRèA ¯UU+ @’¶$ËZB ªUU* @’¶$ËZB êUU'€FÖş“$ŠRç9 êU  Ó'I’$IJç9x_UU        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ            œÙ Ì ÎQæı H@H         èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ            œÙ – ”'æı H@H         èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ        èAç9ÿÿÿÿ