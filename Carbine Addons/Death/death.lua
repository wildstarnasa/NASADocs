-----------------------------------------------------------------------------------------------
-- Client Lua Script for Death
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Tooltip"
require "XmlDoc"
require "GameLib"
require "MatchingGame"

---------------------------------------------------------------------------------------------------
-- Death module definition
---------------------------------------------------------------------------------------------------
local Death = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------
local RezType =
{
	Here = 1,
	Eldan = 2,
	SpellCasterLocation = 4,
	ExitInstance = 32
}

local kcrCanResurrectButtonColor = CColor.new(1, 1, 1, 1)
local kcrCannotResurrectButtonColor = CColor.new(.6, .6, .6, 1)
local kcrCanResurrectTextColor = ApolloColor.new("ff9aaea3")
local kcrCannotResurrectTextColor = CColor.new(.3, .3, .3, 1)

local knSaveVersion = 2

---------------------------------------------------------------------------------------------------
-- Death functions
---------------------------------------------------------------------------------------------------
function Death:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.wndResurrect = nil
	o.nGoldPenalty = 0
	o.bEnableRezHere = true
	o.bEnableCasterRez = false
	o.bHasCasterRezRequest = false
	o.nRezCost = 0
	o.fTimeBeforeRezable = 0
	o.fTimeBeforeWakeHere = 0

	return o
end

function Death:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- EventHandlers
---------------------------------------------------------------------------------------------------
function Death:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Death.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end


function Death:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		
		Apollo.RegisterEventHandler("ShowResurrectDialog", 		"OnShowResurrectDialog", self)
		Apollo.RegisterEventHandler("UpdateResurrectDialog", 	"OnUpdateResurrectDialog", self)
		Apollo.RegisterEventHandler("ShowIncapacitationBar", 	"ShowIncapacitationBar", self)
		Apollo.RegisterEventHandler("HideIncapacitationBar", 	"HideIncapacitationBar", self)
		Apollo.RegisterEventHandler("CasterResurrectedPlayer", 	"CasterResurrectedPlayer", self)
		Apollo.RegisterEventHandler("ForceResurrect", 			"OnForcedResurrection", self)
		Apollo.RegisterEventHandler("ScriptResurrect", 			"OnScriptResurrection", self)
		Apollo.RegisterEventHandler("MatchExited", 				"OnForcedResurrection", self)
		Apollo.RegisterEventHandler("PVPDeathmatchPoolUpdated", "OnPVPDeathmatchPoolUpdated", self)
		Apollo.RegisterEventHandler("CharacterCreated", 		"OnCharacterCreated", self)

		self.wndResurrect = Apollo.LoadForm(self.xmlDoc, "ResurrectDialog", nil, self)
		self.wndResurrect:Show(false)

		self.wndExitConfirm = Apollo.LoadForm(self.xmlDoc, "ExitInstanceDialog", nil, self)
		self.wndExitConfirm:Show(false)	
		
		if self.locSavedWindowLoc then
			self.wndResurrect:MoveToLocation(self.locSavedWindowLoc)
		end
		
		self.xmlDoc = nil
		
		self.nTimerProgress = nil
		self.bDead = false
		
		self.timerTenthSec = ApolloTimer.Create(0.10, true, "OnTenthSecTimer", self)
		self.timerTenthSec:Stop()

		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		end
	end
end

function Death:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local tSaveData = 
	{
		bCasterRezzed = self.bHasCasterRezRequest,
		tWindowLocation = self.wndResurrect and self.wndResurrect:GetLocation():ToTable() or self.locSavedWindowLoc:ToTable(),
		nSaveVersion = knSaveVersion,
	}
	return tSaveData
end

function Death:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bHasCasterRezRequest = tSavedData.bCasterRezzed
		
		if tSavedData.tWindowLocation then
			self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------------------------------
function Death:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if unitPlayer:IsDead() == false then
		return
	end
	
	self.bDead = true
	self.fTimeBeforeRezable = GetDeathPenalty() 
	self.fTimeBeforeWakeHere = GetWakeHereTime() 
	self.fTimeBeforeForceRez = GetForceRezTime() 
	self.nRezCost = GetRezCost() 
	self.bEnableRezHere = GetRezOptionWakeHere() 
	self.bEnableRezHoloCrypt = GetRezOptionHolocrypt() 
	self.bEnableRezExitInstance = GetRezOptionExitInstance()
	self.bEnableCasterRez = GetRezOptionAcceptCasterRez()
	
	self:OnShowResurrectDialog(self.bDead, self.bEnableRezHere, self.bEnableRezHoloCrypt, self.bEnableRezExitInstance, self.bEnableCasterRez, self.bHasCasterRezRequest, self.nRezCost, self.fTimeBeforeRezable, self.fTimeBeforeWakeHere, self.fTimeBeforeForceRez)
end

function Death:OnShowResurrectDialog(bPlayerIsDead, bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
	self.timerTenthSec:Start()
	
	self.bDead = bPlayerIsDead
	
	self:OnUpdateResurrectDialog(bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
end

function Death:OnUpdateResurrectDialog(bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
	self.bEnableRezHere = bEnableRezHere
	self.bEnableRezHoloCrypt = bEnableRezHoloCrypt
	self.bEnableRezExitInstance = bEnableRezExitInstance
	self.bEnableCasterRez = bEnableCasterRez or false
	self.bHasCasterRezRequest = bHasCasterRezRequest
	self.nRezCost = nRezCost
	self.fTimeBeforeRezable = fTimeBeforeRezable
	self.fTimeBeforeWakeHere = fTimeBeforeWakeHere
	self.fTimeBeforeForceRez = fTimeBeforeForceRez
	
	if self.bDead == false then
		self.wndExitConfirm:Show(false)	
		self.wndResurrect:Show(false)
		self.nTimerProgress = nil
		return
	end
	
	--hide and format everything
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.ExitInstance"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(false)	
	self.wndResurrect:FindChild("ArtTimeToRezHere"):SetText(Apollo.GetString("CRB_Time_Remaining_2"))
	self.wndResurrect:FindChild("ArtTimeToRezHere"):Show(true)
	self.wndResurrect:FindChild("ForceRezText"):Show(false)
	
	if self.bDead and not self.wndResurrect:IsShown() then
		self.wndResurrect:Invoke()
	end
end


------------------------------------//------------------------------
function Death:OnTenthSecTimer() -- there's no reason we can't run the whole thing off of this
	if self.bDead ~= true or not self.wndResurrect:IsVisible() then
		self.bHasCasterRezRequest = false
		return
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndResurrect:GetAnchorOffsets()
			
	-- update all of our timers
	self.fTimeBeforeWakeHere = self.fTimeBeforeWakeHere - 100
	self.fTimeBeforeForceRez = self.fTimeBeforeForceRez - 100
	self.fTimeBeforeRezable = self.fTimeBeforeRezable - 100
			
	if self.fTimeBeforeRezable > 0 then -- this timer takes precendence over everything. if it has a count, the player can't do anything
		local strTimeBeforeRezableFormatted = self:HelperCalcTimeSecondsMS(self.fTimeBeforeRezable)
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):SetText(strTimeBeforeRezableFormatted .. Apollo.GetString("CRB__seconds"))
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(true)
		self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 211)
	else
		local tMatchInfo = MatchingGame.GetPVPMatchState()
		if tMatchInfo ~= nil then
			if tMatchInfo.eRules == MatchingGame.Rules.DeathmatchPool then
				if (tMatchInfo.eMyTeam == MatchingGame.Team.Team1 and tMatchInfo.tLivesRemaining.nTeam1 == 0) or (tMatchInfo.eMyTeam == MatchingGame.Team.Team2 and tMatchInfo.tLivesRemaining.nTeam2 == 0) then
					self.wndResurrect:FindChild("ResurrectDialog.Timer"):SetText(Apollo.GetString("Death_NoLives"))
					self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(true)	
					self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 211)
					self.wndResurrect:FindChild("ForceRezText"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(false)		
					self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(false)	
					return
				end
			elseif tMatchInfo.eRules == MatchingGame.Rules.WaveRespawn then
				self.wndResurrect:Close()
				return
			end
		end
	
		self.wndResurrect:FindChild("ArtTimeToRezHere"):Show(false)
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(false)
		self.wndResurrect:FindChild("ForceRezText"):Show(self.fTimeBeforeForceRez > 0)
		self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(self.bEnableRezHere)
		self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(self.bEnableRezHoloCrypt and not self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.ExitInstance"):Show(not self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)		
		self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(self.bEnableCasterRez and self.bHasCasterRezRequest)	
		

		if self.wndResurrect:FindChild("ResurrectDialog.Caster"):IsShown() then
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 320)
		elseif self.wndResurrect:FindChild("ResurrectDialog.Here"):IsShown() or self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):IsShown() then
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 288)
		else
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 220)
		end
		
		self.wndResurrect:FindChild("ResurrectDialogButtons"):ArrangeChildrenVert(0)
		-- set up rez here
		if self.wndResurrect:FindChild("ResurrectDialog.Here"):IsShown() then
			local wndBtn = self.wndResurrect:FindChild("ResurrectDialog.Here")
			wndBtn:FindChild("ResurrectDialog.Cash"):SetAmount(self.nRezCost)
						
			if self.fTimeBeforeWakeHere <= 0 then  -- ready to go
				local bCanAfford = self.nRezCost <= GameLib.GetPlayerCurrency():GetAmount()
				wndBtn:Enable(bCanAfford)
				wndBtn:FindChild("WakeHereText"):SetText(Apollo.GetString("Death_WakeHere"))
				wndBtn:FindChild("WakeHereCooldownText"):SetText("")
				wndBtn:FindChild("ResurrectDialog.Cash"):Show(true)
				wndBtn:FindChild("CostLabel"):Show(true)
				if bCanAfford then
					self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCanResurrectButtonColor)
					wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCanResurrectTextColor)
					wndBtn:FindChild("ResurrectDialog.Cash"):SetTextColor(ApolloColor.new("white"))
				else -- not enough money
					self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCannotResurrectButtonColor)
					wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCannotResurrectTextColor)	
					wndBtn:FindChild("ResurrectDialog.Cash"):SetTextColor(ApolloColor.new("red"))						
				end	
			else -- still cooling down
				wndBtn:Enable(false)
				local strCooldownFormatted = self:HelperCalcTimeMS(self.fTimeBeforeWakeHere)
				wndBtn:FindChild("WakeHereCooldownText"):SetText(String_GetWeaselString(Apollo.GetString("Death_CooldownTimer"), strCooldownFormatted))
				wndBtn:FindChild("ResurrectDialog.Cash"):Show(false)
				wndBtn:FindChild("CostLabel"):Show(false)
				self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCannotResurrectButtonColor)
				wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCannotResurrectTextColor)					
			end
		end	
	end
		
	if self.fTimeBeforeForceRez > 0 then
		local strTimeFormatted = self:HelperCalcTimeMS(self.fTimeBeforeForceRez)
		self.wndResurrect:FindChild("ForceRezText"):SetText(String_GetWeaselString(Apollo.GetString("Death_AutoRelease"), strTimeFormatted))
	end

end

------------------------------------//------------------------------

function Death:CasterResurrectedPlayer(strCasterName)
	self.bHasCasterRezRequest = true;
end

function Death:OnResurrectHere()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.Here, 0)
	end
	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end
------------------------------------//------------------------------
function Death:OnResurrectCaster()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.SpellCasterLocation, 0) -- WIP, this should send in the UnitId of the caster
	end
	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end
------------------------------------//------------------------------
function Death:OnResurrectEldan()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.Eldan, 0)
	end

	self.wndResurrect:Show(false)
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
	
	if GameLib.GetPvpFlagInfo().nCooldown then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, Apollo.GetString("Death_PvPFlagReset"), "" )
	end
end
------------------------------------//------------------------------
function Death:OnExitInstance()
	self.wndExitConfirm:Invoke()
	self.wndResurrect:Close()
end

function Death:OnConfirmExit()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.ExitInstance, 0)
	end

	self.wndExitConfirm:Close()	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

function Death:OnCancelExit()
	self.wndExitConfirm:Close()	
	self.wndResurrect:Invoke()
end

------------------------------------//------------------------------
function Death:OnForcedResurrection()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Close()
	self.bDead = false

	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

------------------------------------//------------------------------
function Death:OnScriptResurrection()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Close()
	self.bDead = false

	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

------------------------------------//------------------------------

function Death:HideIncapacitationBar()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Show(false)
end

function Death:HelperCalcTimeSecondsMS(fTimeMS)
	local fTime = math.floor(fTimeMS / 1000)
	local fMillis = fTimeMS % 1000
	return string.format("%d.%d", fTime, math.floor(fMillis / 100))
end

function Death:HelperCalcTimeMS(fTimeMS)
	local fSeconds = fTimeMS / 1000
	local fMillis = fTimeMS % 1000
	local strOutputSeconds = "00"
	if math.floor(fSeconds % 60) >= 10 then
		strOutputSeconds = tostring(math.floor(fSeconds % 60))
	else
		strOutputSeconds = "0" .. math.floor(fSeconds % 60)
	end
	
	return String_GetWeaselString(Apollo.GetString("CRB_TimeMinsToMS"), math.floor(fSeconds / 60), strOutputSeconds, math.floor(fMillis / 100))
end

function Death:HelperCalcTime(fSeconds)
	local strOutputSeconds = "00"
	if math.floor(fSeconds % 60) >= 10 then
		strOutputSeconds = tostring(math.floor(fSeconds % 60))
	else
		strOutputSeconds = "0" .. math.floor(fSeconds % 60)
	end
	
	return String_GetWeaselString(Apollo.GetString("CRB_TimeMinsToMS"), math.floor(fSeconds / 60), strOutputSeconds)
end

---------------------------------------------------------------------------------------------------
-- Death instance
---------------------------------------------------------------------------------------------------
local DeathInst = Death:new()
DeathInst:Init()
¥Õd6~ız?¶øÿ®~ÖÈèp}ù|¾øÜƒ™‹9Æ†íMàWÉ“ëœC¥ÅfÏ|*Ø°ZÚ~EÖÏÒu*¾€Ï‹æK¨¿p'ç2ı`óå„Ö?È<Ã¼ûö•súÕíÔ&ˆ\UŸæ®âû¡œÉ+dPÒ"½Hõ´;P/{în×ó[vŒ WÙ3¬¯~ÉÏhøPOHæU¶“õ#äùìÑÄş^úUªï}ŒÃü|f©êM ~„!ÕÆçB¹ıÕö+ìy®¾ä¹ùÃä¤bëÉËt{‘¹Ÿæo"”^¦û39È8ëÛasdÆ%úzf¿ƒ,‹?K¹—ó¿òı»	×ÿñ1¯Çm]áp¿Îw
§…ô¸Eèó‹,,‡úÿtû›#	§×cÀ¯‚z“åQ®øÜ‹Í\=ÔÇÿü'¯OÉ+>urÆşøP"Ù´t¾ó§ì^›>BÅéõ+4şş|ãPóXôóAÿG$işú9 ~úCÄÄ^z âÑaƒù‹œ>øŸüVø¯ˆè¿±=Œ\/¾/ô|¦ê×ß´tUª¡*‰…ë}§-eM•íğúPo’-«Ìy¦¡â&ô+2T°?–`¿/£RµøÛÁB½‰)êù}éÙŠ=ÙÓ,\/.Ê_¤¡’ëG4›¬\=Z&3:”?ËşŞùŠ{‹ŞëíFô;VmÒë3&_•ŸólÜÎFmv<øU¸úª:ªWNâõúzn>Ç:?RÅé»‚Óë±$û/~ÛU®~
ôŠ˜w{ü)êI¾-wëåH’RÒäªâêM =t½ü$ÌÇJªó¹ªZdS·•G±/*ĞÛQè;4Î~!ø"ôOÙÀÏêûÁ¯0šãç™XøùğÆ‡zm¿Ô•a};G¿UšßæNàúú—1»9¿Ê©70Å'!ZÂ¾¤ò]><ÿZ˜W%.8d™ñÿ‰æ¯Óø7E‘ì¦ôõWÕ/‡â¿»¾öoêÅñÿ]YL¤%/„ŞŸÛ ~VrIîŠ÷ÁJnô¹~V^ÙAğ«hº8:°\|¥`šåbğ­ ÅSğ›î|û+ÒŸ~ŞÜ\ft¨Q°|^¿	££ˆ«¢¼!7ú× ş'Êòâ”õÍ"˜çÓHõúäqÉ z=›İó«r&„«6İèœ­ƒyê«Í$#ÙŸİ<ÅÕWQùnd~4ıPßí|G´è²¢
ÎßĞ6:İã$—@Ÿÿ9‹OyRsBôBñG…ÙewS}î),
ÌÖu(ı„ú¥°ëÎ2ışÙú‚^5—«·r¦j‡0Ûs§ú¢À¢Ë¡äø¸íK2?‘èa•TÎ?$kÎN6…æ‡ÇkµE’òäôwfs÷°šLÆşZ_øCsw=c$Ñ]ÉqÅï†~A­Óévwlì6ã|˜/—Ba¢¿\ü±–~^V«Ç#!îu¢`ÔJ®~ñ‡›%´şù±2ÔS}zà\T[È¯š-vUµæãú£¨OzvˆëÙgŞœ âü©Æ$Æ¶äÜB$W®—m$!«—?ª»ÊëyÓSÊâ)Ğ/ıKpÿÂ›w×›Àı>ï³sóG¡
î2:ŒŸ?
z™Ôø“%[`>İŞÆÂıB–Êø~óT“Ú€aÃ faVîö› ·‰¬Ş›ªRdÜ¥Z|ô8aêÖÅÂ¼QÅª Ç½’Êä/‡şØ¿ÑÖå‘BÿÔyñÜû5›ºn=ä–¿Şòù ß9†ÿ%®Ê?ååÆæü*§ö1eQEî%‹ì*/_crÒ/Ü!bÂÏûØ‹,ô³¯Œ¶¿òñ.³î:ëe¡>~œ˜êuªW >Ğc5#É§=_ÊùG]æ¯õ‹PñÄ"®Şü¦FúıE.ªÊ\•Gàø =]Âéó›pür*ØÂ< ª/¦ùs–µ3Iuğ½­l>Oó×Dz±-ÒÔ*ıàïÁõòŞZßØ[ô]oãîş¨^ß6”Ü¨<˜›~Ä¿16oğ‚İÍ"èwjÔÊåKÓ 0rÂ†P}Éi6§×'²+‚Ş.›9šX8½ş"Ô“P½r«^ÈĞwõz·Ÿ%!o¿¡ÿ=÷~àzù¸^ò³@Ÿÿ,zàJÙ—Å¹‚/y’6Kq}Wz9Í—àÊ ®ŸTäùYÓk•Ó`µÑÔ{êKy¦¿ÿ¿¯hø’«·½òÓ^¯À|t*ßµYºè	"F]KãŸ~ÿ<(oş­oç$İvwôJ,qÌ˜~ı”âÊwˆÿ‚îø_öPß«¯úg™şôÔ7BÿaI¦ù²½õEÎÏrºˆŠ³È®/ĞüÉµs¤×i¾¸Ïƒÿkù¼féjÄÓ^âü_áúq…Ök?d½É}qd¨Ş*5Q\TñlŞúØœàì Äÿ¤á#-"1Ô[µRyÁD¥=ò£…õiSÙ8½>~ÿÓßÌ¯†ø§¿;¿ÖëFÔë‡»¯GÂùJİæ6 S£E‚y`Z­Ó7^:<òEÜ(ËµÚ°Nø}ñ€~)«µ+œÌß9úé‚Q	œ>_†÷/üÎÜİ/[TaM^Ïù·Nú{qeİÜ?4K§°.úyÈåñÑDb±¸úeíONãØ5í™EÜ<«.š "’QªÎäç¡-£	Ğ{Ş_ÿ`¸^¢ÖoåÎoªÓí&ã£”ÓóŸ¬mt‘’Ä
—>¦ºKÛodäúÛÁşşôç¤gş"?ïİøĞ÷u¼BëŸËHQå{‡Æ†üª†»8=Ó	~•³.ùùy_FÅM W©^‡zùç'Ó_¨æ=i×ØóœYÕ<úÛ¡>úEÆŠù~ğ£<A3ÕË”|]o"!Åx§»ŞÄøÿÖ›0dáÖ[ú=º_ÏÍcøƒ§Êµ¥§Şd©„y&÷ƒ—5ùúğÓÀí\½IÀ½n°¸Y:uÛÁœ¿•ì\;¬®—[.°gX*Ç¦3Ü¼Q?¯™«ÏÕ/×Oƒóqë<“Şòy!ÿs,£zå†2eïW¥.tUT¬]¯¼À¶±Pÿøı¯/‰I†í¤zEÆ¬ŒµG~¼SÇÕW_¥f,é4Ş!? Ÿ=Œ8ŞUÏ+UÃşn­ï-ï÷cø¯”ŒŒ.£ú?ÙésO“L¹úòú?½«`îc£UÊóà×1rmV„m–®£ğô/š¬^”äÓtŠ§âü¬Ş“/½EÏõ6 ®Ê7Ê‡úSo¨x6w½ê§àúâÒé#iü«3À¯¢r¥à!Õ!ª×ßN_Ì¾ôtYMƒ‰…ë
Õ—ÅÄòµ_ÕëKnç0²·ØZ´ıÈ,ŞÏrOO†|şÈ$º~Êºçp–cø«sÏ«ƒ‚Â¢Éa4_®‰§¹‚³‚°~’ùÇÔs®ËøĞ×z£·¼¿şÎâÛæ[UTP½ş2Wo•ª7ì\3(Cõ†Z*Xæ·‡WŠJÿÊî±X5bGSúõO40ÿôŠ„dï­?ÆÕëİÚÒ[Ş¯ĞFRJ¬úò#ïToh¾”ä6lÿ3øåÉZ§sÎ]dÒGaşÇ _şF{ã›­ëûa¾œÉÖ­7îûåV}şÕÓëeÏEÇ¾DÙçtjS¤yq±<2_pw Æÿäqbõj"»w*ßeI
ËNöwÎÖÁüˆÿpR=iÊúEšÙ¨×ïKˆ«x]ÁùœA×c	ÌÔè—ÀõÖ9Ç+&/œ÷Ö½Á— Ë£]Ÿ4æÔoA¾`=Ö?Æp¾$ú­\¿à¶m©©Ñ¢†íëò¢ca>™s†V=t¡ˆê_ğoR¹ê­ş²ps*øY«Õ
õV_t.î©·úzÿxşˆï¯p2¶$'¥ì/ß›êÜ6$løº¹çTÊ\=–\+ê¬Owlş¿íXSWº÷Wö—$äñR­B *nhD§‡XµŒC[RÄ3ÚÖ)´µk!µeæë1X(ZSV¼ğñi':ŒåÀÑ~gJÛùÆiçRÏ™ŒWDë¥šVÓfïo½k'ˆÎôL§Utñø<}~BöŞëÍZÿÿzßweôygx,–R2ÿ?Æ$Æ‰õ„·¬ş6Ğú