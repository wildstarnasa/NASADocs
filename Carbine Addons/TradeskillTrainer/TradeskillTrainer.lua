-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillTrainer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "XmlDoc"
require "Apollo"
require "CraftingLib"


local TradeskillTrainer = {}

local knMaxTradeskills = 2 -- how many skills is the player allowed to learn

function TradeskillTrainer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TradeskillTrainer:Init()
    Apollo.RegisterAddon(self)
end

function TradeskillTrainer:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("TradeskillTrainer.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillTrainer:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	Apollo.RegisterEventHandler("InvokeTradeskillTrainerWindow", "OnInvokeTradeskillTrainer", self)
	Apollo.RegisterEventHandler("CloseTradeskillTrainerWindow", "OnClose", self)

	self.nActiveTradeskills = 0
end

function TradeskillTrainer:OnInvokeTradeskillTrainer(unitTrainer)
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillTrainerForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("DialogResponse_TradskillTraining")})

		if self.locSavedWindowLoc then
			self.wndMain:MoveToLocation(self.locSavedWindowLoc)
		end
	end

	self.nActiveTradeskills = 0
	self.wndMain:FindChild("ListContainer"):DestroyChildren()

	self.wndMain:FindChild("SwapTradeskillBtn1"):SetData(nil)
	self.wndMain:FindChild("SwapTradeskillBtn2"):SetData(nil)

	for idx, tTradeskill in ipairs(unitTrainer:GetTrainerTradeskills()) do
		local tInfo = CraftingLib.GetTradeskillInfo(tTradeskill.eTradeskillId)
		if not tInfo.bIsHobby then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "ProfListItem", self.wndMain:FindChild("ListContainer"), self)
			wndCurr:FindChild("ListItemBtn"):SetData(tTradeskill.eTradeskillId)
			wndCurr:FindChild("ListItemText"):SetText(tInfo.strName)
			wndCurr:FindChild("ListItemCheck"):Show(tInfo.bIsActive)

			if tInfo.bIsActive then
				self.nActiveTradeskills = self.nActiveTradeskills + 1

				if self.wndMain:FindChild("SwapTradeskillBtn1"):GetData() == nil then
					self.wndMain:FindChild("SwapTradeskillBtn1"):SetData(tTradeskill.eTradeskillId)
					self.wndMain:FindChild("SwapTradeskillBtn1"):SetText(String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapWith"), tInfo.strName))
				else
					self.wndMain:FindChild("SwapTradeskillBtn2"):SetData(tTradeskill.eTradeskillId)
					self.wndMain:FindChild("SwapTradeskillBtn2"):SetText(String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapWith"), tInfo.strName))
				end
			end
		end
	end

	for idx, tTradeskill in ipairs(CraftingLib.GetKnownTradeskills()) do
		local tInfo = CraftingLib.GetTradeskillInfo(tTradeskill.eId)
		if tInfo.bIsHobby and tTradeskill.eId ~= CraftingLib.CodeEnumTradeskill.Farmer then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "HobbyListItem", self.wndMain:FindChild("ListContainer"), self)
			wndCurr:FindChild("ListItemBtn"):SetData(tTradeskill.eId)
			wndCurr:FindChild("ListItemText"):SetText(tInfo.strName)
			wndCurr:FindChild("ListItemCheck"):Show(true)
		end
	end

	self.wndMain:FindChild("ListContainer"):ArrangeChildrenVert(0)
end

function TradeskillTrainer:OnClose()
	if self.wndMain then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		self.wndMain = nil
	end
	Event_CancelTradeskillTraining()
end

function TradeskillTrainer:OnWindowClosed(wndHandler, wndControl)
	self:OnClose()
end

function TradeskillTrainer:OnProfListItemClick(wndHandler, wndControl) -- wndHandler is "ListItemBtn", data is tradeskill id
	for key, wndCurr in pairs(self.wndMain:FindChild("BGLeft:ListContainer"):GetChildren()) do
		if wndCurr:FindChild("ListItemBtn") then
			wndCurr:FindChild("ListItemBtn"):SetCheck(false)
			if wndCurr:GetName() == "HobbyListItem" then
				wndCurr:FindChild("ListItemBtn:ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))
			else
				wndCurr:FindChild("ListItemBtn:ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			end
		end
	end
	wndHandler:SetCheck(true)
	wndHandler:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	-- Main's right panel formatting
	local idTradeskill = wndHandler:GetData()
	local bAtMax = self.nActiveTradeskills == knMaxTradeskills
	local tTradeskillInfo = CraftingLib.GetTradeskillInfo(idTradeskill)	
	local bAlreadyKnown = wndHandler:FindChild("ListItemCheck"):IsShown()

	self.wndMain:FindChild("RightContainer:BottomBG:AlreadyKnown"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:HobbyMessage"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:SwapContainer"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:LearnTradeskillBtn"):Show(false)
	self.wndMain:FindChild("RightContainer:BottomBG:LearnTradeskillBtn"):SetData(wndHandler:GetData()) -- Also used in Swap
	self.wndMain:FindChild("RightContainer:BottomBG:FullDescription"):SetText(tTradeskillInfo.strDescription)

	local nCooldownCurrent = CraftingLib.GetRelearnCooldown() or 0
	local nCooldownNew = tTradeskillInfo and tTradeskillInfo.nRelearnCooldownDays or 0
	if nCooldownCurrent > 0 then
		local strCooldownText = ""
		if nCooldownCurrent < 1 then
			strCooldownText = Apollo.GetString("TradeskillTrainer_SwapOnCooldownShort")
		else
			strCooldownText = String_GetWeaselString(Apollo.GetString("TradeskillTrainer_SwapOnCooldown"), tostring(math.floor(nCooldownCurrent + 0.5)))
		end
		self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked"):Show(true)
		self.wndMain:FindChild("RightContainer:BottomBG:CooldownLocked:CooldownLockedText"):SetText(strCooldownText)
	elseif bAlreadyKnown then
		self.wndMain:FindChild("RightContainer:BottomBG:AlreadyKnown"):Show(true)
	elseif bAtMax and not bAlreadyKnown then
		local nRelearnCost = CraftingLib.GetRelearnCost(idTradeskill):GetAmount()
		local strCooldown = String_GetWeaselString(Apollo.GetString("Tradeskill_Trainer_CooldownDynamic"), nCooldownNew)
		local strCooldownTooltip = String_GetWeaselString(Apollo.GetString("Tradeskill_Trainer_CooldownDynamicTooltip"), nCooldownNew)

		local wndSwapContainer = self.wndMain:FindChild("RightContainer:BottomBG:SwapContainer")
		wndSwapContainer:Show(true)
		wndSwapContainer:FindChild("CostWindow"):Show(nRelearnCost > 0 or nCooldownNew > 0)
		wndSwapContainer:FindChild("CostWindow:SwapCashWindow"):SetAmount(nRelearnCost)
		wndSwapContainer:FindChild("SwapTimeWarningContainer"):Show(nRelearnCost > 0 or nCooldownNew > 0)
		wndSwapContainer:FindChild("SwapTimeWarningContainer"):SetTooltip(strCooldownTooltip)
		wndSwapContainer:FindChild("SwapTimeWarningContainer:SwapTimeWarningLabel"):SetText(strCooldown)
	elseif not bAtMax and not bAlreadyKnown then
		self.wndMain:FindChild("LearnTradeskillBtn"):Show(true)
	end

	-- Current Craft Blocker
	local tCurrentCraft = CraftingLib.GetCurrentCraft()
	self.wndMain:FindChild("RightContainer:BottomBG:BotchCraftBlocker"):Show(tCurrentCraft and tCurrentCraft.nSchematicId)
end

function TradeskillTrainer:OnHobbyListItemClick(wndHandler, wndControl)
	for key, wndCurr in pairs(self.wndMain:FindChild("ListContainer"):GetChildren()) do
		if wndCurr:FindChild("ListItemBtn") then
			wndCurr:FindChild("ListItemBtn"):SetCheck(false)
			if wndCurr:GetName() == "HobbyListItem" then
				wndCurr:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))
			else
				wndCurr:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			end
		end
	end
	wndHandler:SetCheck(true)
	wndHandler:FindChild("ListItemText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListPressed"))

	-- Main's right panel formatting
	self.wndMain:FindChild("AlreadyKnown"):Show(false)
	self.wndMain:FindChild("CooldownLocked"):Show(false)
	self.wndMain:FindChild("SwapContainer"):Show(false)
	self.wndMain:FindChild("LearnTradeskillBtn"):Show(false)
	self.wndMain:FindChild("FullDescription"):SetText(CraftingLib.GetTradeskillInfo(wndHandler:GetData()).strDescription)

	self.wndMain:FindChild("HobbyMessage"):Show(true)
end

function TradeskillTrainer:OnLearnTradeskillBtn(wndHandler, wndControl)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local nCurrentTradeskill = self.wndMain:FindChild("LearnTradeskillBtn"):GetData()
	local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(nCurrentTradeskill)
		if not tCurrTradeskillInfo.bIsHarvesting then
			Event_FireGenericEvent("TradeskillLearnedFromTHOR")
		else
	end
	CraftingLib.LearnTradeskill(nCurrentTradeskill)
	self:OnClose()
end

function TradeskillTrainer:OnSwapTradeskillBtn(wndHandler, wndControl) --SwapTradeskillBtn1 or SwapTradeskillBtn2, data is nTradeskillId
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local nCurrentTradeskill = self.wndMain:FindChild("LearnTradeskillBtn"):GetData()
	local tCurrTradeskillInfo = CraftingLib.GetTradeskillInfo(nCurrentTradeskill)
		if not tCurrTradeskillInfo.bIsHarvesting then
			Event_FireGenericEvent("TradeskillLearnedFromTHOR")
		else
	end

	CraftingLib.LearnTradeskill(nCurrentTradeskill, wndHandler:GetData())
	self:OnClose()
end

local TradeskillTrainerInst = TradeskillTrainer:new()
TradeskillTrainerInst:Init()
”µîn„ˆN¶\f~ü%av!–p¸[rìµñÈÔ‚ä¨‰N\Xh©‰\m’íKuRy A•âÂ8J~&£BÙ;õEóÍ{¯YÂP/6åYİRá¶F¨7ò!6O
ÙĞ£§· Ó´ñüúô)­6!Ó~J¿ÙİXn“ãÂo—Ñö’BbŞù¼{›¬ÆÛO¯ÔÅ*.b©æö’øhı9ªVñÏÍ‡Z˜ï#“?Ú Ã—äŒ†]kõœ=\rV‘HMvà¬ß‡Z°Äí³GşU’ÕVÃß¿L'îaû¬ş‡E¾
(ÿã¼¨ÄÜ‚ÇáìM)ö’Å½ˆÏ¦/¦ÑNYÂCMÑa~9×+ˆĞ?wŠ%Ä_$"ÕG}!Ì¸û<\Ä#IÍ QFåFã©u\£—(D±ûœï¸6XYòŞLúÓ¬ã…²İÃ>÷¡SHE‰7ğr?D´¨O9ˆ•…ş46wq0 ƒ4èLùZ:œC.EÙFìø,ğHú'œ`÷Œ¶Ô’ÉÂÃ¿/9˜à©[ì,e ¦§Ùò«I¯¡xßğÌY][¤ÒZ1Tÿ=z8ş(ÿ«mb¼~XˆşUI2P÷¨¡Á•´404.‹rYV`@V¼¤?y=ˆäğG…˜Gâ©¿v„Rá®e³q ò¿WÁ¡˜0.±ŒÿšøÂ’ûf­åˆä9\‘	²e¢yü8·–Èæ,AsfS¦¼R	dûpÄ˜\¶ïßúÒĞĞç³u¥û}!QL#-­œfNc?*'Ş¬µNßxşÆ«6²—O6Å¾%ĞÎ\{Í;Í»)3o2ÓĞLÿµ1óÉ—›’³GJË\Î[õæ÷²·DuûĞœş»eÃp¢70pí#ùr}. .9áH—0Ñ«ÍGß®?]ÏÏi‰˜lg)Y#È5Úø–ŞØoù‡DöìE‘HÈ§ÅºÂpıF“gÔĞJÍæ¡âçhOınş|Jóg–XÒ~7m~7m~7m~7m~7m~ã¦[^;­œşnÑÿhÂ1r¼6í{Ÿ©ÇŸ‹ä=9Y€™J½e×jÅbCàlÂë÷;á±ál/wv8©­”=2Sö˜èãB!Á~şÅ>œcÌ”½»<|tÌ“=cŸpeO™({¾°RÀ$Ùk3Uöj¶Šc­ì5˜+pÙ?qWµ-F/]ÁéïBröJş	öølSÍñ<Íc³íMjL	¼­dm¢½^FQİ,‚<Ãh[FÌ4">³ªßj‰Yşä¥Œ»v˜¥¢Tò™.^qı»§õïY­¯fŒm_4zm4ù
òá“,ò–kŒ9·Â[š@–&²qdõZçóM#ÇaºÑ"öñeÍ.q@ïö-‰ÕÍß”X5^M®”aÂ.,¦™"ÎÕMä;zİ~öZEh4¬³…cüÊ<
—Ñƒx.(	Ï¦Î¾²¤İÁ¬ÖóJÎã»?f¿ËH—áz˜®K-‰}£dŸÿÓ6N÷	ımŸÌ?[®ªëã|v)6ÈÎàŠ†Î°oE‘ğ‚0&$nfŞ6åS²†­yv‹!ŒäüÅnİšĞ¶Å$ÔeVÑD©´µ!|÷MÎÈ¡Óx£ı¬Óx$³"Ÿ]$+ó2‚Àï=\„w²ëJ~<[WG`%ŠÈäâß°Q&"ø våtæ}ëp¥ş ö]Æ»ÙŞÇÃ'°™GÕÑ:Ã»,@>ÉÉıâõÉîËÇÑÉER’/2ŸÌåL˜KrÏ¤ìRôˆ”î”ƒ¯p±¤ÛSî¹X`üƒÂËW Bfö³øæäXHe¯® ÓW¸-,×Ëà7ÇÍxçSÆPO±!ğ@G“—ù¯ÚpÌè	~ú™äøíöïã¾‹ø'ò8#@[RÅ}¹:UõÖ/rÁMè­ˆ¦ŒbÂ„³ût÷ë¢GşØMTğëà/>Y7¿şÚGÿ°K_²>
¿ywØË[õ(o÷".Î{l\CBUèİ´§¯M)=®æÊ›·
µ¤ÃÇˆ)u“ÿ*–ê5_­á}T<Ú¹ˆßËÂ<Ó,(Si70C•Õ%Í€äóÜû(·‘Í³„°úŞ-'§‡Á'ƒÈ]g3B?Í½$º„Ğ=è…•†+·p[éîmR«UE	¦ƒóB,¸­Ïv WÜÌpLQ>\_goJÒºêº’¹FçœˆÔRÜ¼]u+¨GÛr§7ûh›ı	ù‰UKŞ~ìAM°­”nD’‡C]ç¥–'ÑÈ\$ÃÇ•ì›|[w¿z”¹‡“1v½Äs³T‹¬Ëıs³ôÄa¯Ü~Rùwå^(‚ùXQ!0z‘××Tú¾Š©×ı]Ùü®lš•Íó$ÃĞ¥ÿ$ƒ}ºÑ•š¶FË•‡åÙcû»ïÆúgĞ¦ªùµŸÃMëT¿ŸOd[[W}WïNÃ»Ú¶¬‡Mc‰e®A’|’eZ¯µâ¹=b›$—Zş‹à\7ìğF²%ZwYNíóB”-Y&ÚfÆ‚ç!.&¼¯*×LkÆa·a~Øi˜×ú5ö›nÄ¸™¬àÒ t€@HvØİF*2ÙÜ
õtŸê&!÷Jêh•õúìŸ”À5øté…q.Ô#Ğww‘7t'·½•¤™ˆÖ8Æ%ËÂ»d‘iåãñÇ49n £s¡q"ğÇÑrZœáıY]|k¶‚ú4öFÌ¶swã¥Ú¸ûÑry7R0l L°F¦ ªÀ¸±PïÍNÊu°kgÒ+jÜUFÉİ«nä¶ƒƒãêwÕkÿ\şÛZ”=|Iæo3üzP’çwğòë:{—[8Hı²Ãu^º,|‡!<å>ààü×‡¯Nv¾;yíñ•ìlTàùœÄg*ÒŒ)Ë|]@ş^QŒpğ+;zl=}dM¨xOuĞgóF²Ã Íè|ø“hVå(ˆæ	tª Ó-†f­Qfd^Æ$Û<s¨=ŸÑìwV•o9s¯LÕı@©÷¥İoİÚûĞÛÀËwÎ¤Û|Õˆ¡È˜h
Ã67šĞõ¾Mk72èõ>AÿÖ˜rÛÀUó0 	İúï1¶A±Ç4°»¤’›+7µbâÒÉğíŠoİJ9K¤:Ui­¢BSoš