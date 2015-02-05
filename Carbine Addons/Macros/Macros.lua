require "Window"
require "MacrosLib"


---------------------------------------------------------------------------------------------------
-- Macros module definition

local Macros = {}

---------------------------------------------------------------------------------------------------
-- Macros initialization
---------------------------------------------------------------------------------------------------
function Macros:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	-- initialize our variables

	-- return our object
	return o
end

---------------------------------------------------------------------------------------------------
function Macros:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- Macros EventHandlers
---------------------------------------------------------------------------------------------------

function Macros:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Macros.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function Macros:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("InterfaceMenu_ToggleMacro", "OnInterfaceMenu_ToggleMacro", self)
	Apollo.RegisterSlashCommand("macros", "OnMacrosOn", self)
	Apollo.RegisterSlashCommand("reloadui", "OnRequestReloadUI", self)
	Apollo.RegisterTimerHandler("LoadIconTimer", "OnLoadIcons", self)

	-- load our forms
	self.wndMacros = Apollo.LoadForm(self.xmlDoc, "MacrosWindow", nil, self)
	self.wndMacroList = self.wndMacros:FindChild("List")
	self.wndEditMacro = self.wndMacros:FindChild("EditMacro")
	self.wndDeleteMacro = self.wndMacros:FindChild("DeleteMacro")
	self.wndMacros:Show(false)
	if self.locSavedWindowLoc then
		self.wndMacros:MoveToLocation(self.locSavedWindowLoc)
	end
		
	self.tItems = {}
	self.wndEdit = nil
	self.wndIcon = nil
	self.wndSelectedMacroItem = nil
	self.bIconTimerCreated = false
	
	self:EnableEditingButtons(false)
end

function Macros:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Macro"), {"InterfaceMenu_ToggleMacro", "", "Icon_Windows32_UI_CRB_InterfaceMenu_Macro"})
end

function Macros:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMacros, strName = Apollo.GetString("InterfaceMenu_Macro")})
end
	
function Macros:OnInterfaceMenu_ToggleMacro()
	if self.wndMacros and self.wndMacros:IsValid() and self.wndMacros:IsVisible() then
		self.wndMacros:Close()
	else
		self:OnMacrosOn()
	end
end
---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Main Dialog (wndMacros)
---------------------------------------------------------------------------------------------------

function Macros:OnMacrosOn()

	self.wndMacros:Show(true)
	self.wndMacros:ToFront()
	self:EnableEditingButtons(false)
	
	for idx, wnd in ipairs(self.tItems) do
		wnd:Destroy()
	end
	self.tItems = {}
	
	-- get list of macros 
	local tListMacros = MacrosLib.GetMacrosList()
	
	for idx = 1, #tListMacros do
        self:AddMacro(idx, tListMacros[idx].nId)
        self:UpdateMacroUIData(self.tItems[idx], tListMacros[idx]);
	end
	
	self.wndMacroList:ArrangeChildrenVert()
end

function Macros:OnRequestReloadUI()
	RequestReloadUI()
end

function Macros:OnOK()
	self.wndMacros:Show(false)
end

function Macros:OnQueryBeginDragDrop(wndHandler, wndControl, nX, nY)
	if wndHandler ~= wndControl then
		return false
	end
	local nMacro = wndControl:GetParent():GetData()
	if nMacro == nil then
		return false
	end
	Apollo.BeginDragDrop(wndControl, "DDMacro", wndControl:FindChild("IconImage"):GetSprite(), nMacro)
	return true
end

function Macros:OnMacroClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then
		return false
	end
	
	local nMacroId = wndControl:GetParent():GetData()
	
	if nMacroId == nil then
		return 
	end
	
	if  eMouseButton == GameLib.CodeEnumInputMouse.Left  then --  left button
	    Apollo.BeginClickStick(wndControl, "DDMacro", wndControl:FindChild("IconImage"):GetSprite(), nMacroId)
	else
	    MacrosLib.DoMacro( nMacroId )
	end
end

function Macros:UpdateMacroUIData( wnd, tMacro )
    -- fill the macro item of the given index with the given macro data
    
    -- set name
    wnd:FindChild("Name"):SetText(tMacro.strName)
    
    -- set icon
    wnd:FindChild("IconImage"):SetSprite(tMacro.strSprite)
    
    -- set commands
    wnd:FindChild("MacroCommands"):DestroyChildren() -- clear existing commands
    -- repopulate the list
 	for idx = 1, #tMacro.arCommands do
		local wndCmd = Apollo.LoadForm(self.xmlDoc, "CommandItem", wnd:FindChild("MacroCommands"), self)
		wndCmd:SetText(tMacro.arCommands[idx])
	end
    
	-- arrange command items
	wnd:FindChild("MacroCommands"):ArrangeChildrenVert()
end

function Macros:AddMacro( idx, id )
    -- add new macro into the form
    local wnd = Apollo.LoadForm(self.xmlDoc, "MacroItem", self.wndMacroList, self)
	self.tItems[idx] = wnd
	
	-- add the macro into the macro manager if it doesnt have an id
	if id == nil then
	    id = MacrosLib.CreateMacro()
	end
	
	wnd:SetData(id)
	wnd:FindChild("MacroFrame"):SetData(wnd)
end

function Macros:OnMacroSelect(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
    
    -- show new selection frame
    self:EnableEditingButtons(true)
    self.wndSelectedMacroItem = wndControl:GetData()
    local wndSelectedFrame = self.wndSelectedMacroItem:FindChild("MacroFrame")
    if not (wndSelectedFrame == nil) then
        wndSelectedFrame:SetCheck(true)
    end
end

function Macros:OnMacroDeselect(wndHandler, wndControl)
	self:EnableEditingButtons(false)
end

function Macros:EnableEditingButtons(bEnable)
	local wndBtn = self.wndEditMacro
	wndBtn:Enable(bEnable)
	wndBtn = self.wndDeleteMacro
	wndBtn:Enable(bEnable)
end

function Macros:OnDeleteMacro()
    
    -- no macro selected -> return
    if self.wndSelectedMacroItem == nil then
        return
    end
    
    -- check if a wndEdit of the macro is opened
    if not (self.wndEdit == nil) then
        local wndMacro = self.wndEdit:GetData()
        if (wndMacro == self.wndSelectedMacroItem ) then
            self:DestroyMacroWnd()
        end
	end
	
	-- delete the macro in game
	MacrosLib.DeleteMacro(self.wndSelectedMacroItem:GetData())
	
    -- delete the macro in UI	
    local bFound = false
	for idx, wnd in ipairs(self.tItems) do
	    if wnd == self.wndSelectedMacroItem then
		    wnd:Destroy()
		    bFound = true
		end
		if bFound and not(idx == #self.tItems) then
           self.tItems[idx] = self.tItems[idx + 1]
        end
	end
	self.tItems[#self.tItems] = nil
	self.wndSelectedMacroItem = nil
	self:EnableEditingButtons(false)
	
	self.wndMacroList:ArrangeChildrenVert()

    MacrosLib:SaveMacros()
end


---------------------------------------------------------------------------------------------------
-- Macro Edit (wndEdit)
---------------------------------------------------------------------------------------------------

function Macros:OnNewMacro()
    -- initialize wndEdit with default data
	if not self.wndEdit then
		self.wndEdit = Apollo.LoadForm(self.xmlDoc, "MacroDefine", nil, self)
		self.wndEdit:FindChild("MacroName"):SetText(Apollo.GetString("Macro_NewMacro"))
		self.wndEdit:FindChild("MacroName"):SetSel(0, -1)
		self.wndEdit:FindChild("MacroName"):SetFocus()
		self.wndEdit:FindChild("GlobalCheck"):SetCheck(true)
		self.wndSelectedIcon = nil
		self.wndEdit:SetData(nil)
		self.wndEdit:MoveToLocation(self.locSavedEditLoc)
	else
	    -- already have another wndEdit opened
	    -- TODO: confirmation to save before navigating to another macro
		self.wndEdit:ToFront()
	end
end

function Macros:OnEditMacro()
    
    -- no macro selected -> return
    if self.wndSelectedMacroItem == nil then
        return
    end

    -- set data to wndEdit
	local id = self.wndSelectedMacroItem:GetData()
	if id == nil then
		return
	end
    
	if not self.wndEdit then
		self.wndEdit = Apollo.LoadForm(self.xmlDoc, "MacroDefine", nil, self)
		self.wndEdit:MoveToLocation(self.locSavedEditLoc)
	else
	    -- already have another wndEdit opened
	    -- TODO: confirmation to save before navigating to another macro
		self.wndEdit:ToFront()
	end
	
	local tMacro = MacrosLib.GetMacro(id)
	self.wndEdit:FindChild("MacroName"):SetText(tMacro.strName)
	self.wndEdit:FindChild("MacroName"):SetSel(0, -1)
	self.wndEdit:FindChild("MacroName"):SetFocus()
	self.wndEdit:FindChild("Icon"):SetSprite(tMacro.strSprite)
	self.wndEdit:FindChild("GlobalCheck"):SetCheck(tMacro.bIsGlobal)
	local strCommands = ""
	for idx = 1, #tMacro.arCommands do
	    strCommands = string.format( "%s%s\n", strCommands, tMacro.arCommands[idx])
	end
	self.wndEdit:FindChild("MacroBody"):SetText(strCommands)
	self.wndEdit:SetData(self.wndSelectedMacroItem)
	
	self.wndSelectedIcon = nil
	
end

function Macros:DestroyMacroWnd()
	if self.wndEdit ~= nil then
		self.wndEdit:Destroy()
		self.locSavedEditLoc = self.wndEdit:GetLocation()
		self.wndEdit = nil
		self:DestroyIconWnd()
	end
end

function Macros:OnMacroOK(wndHandler, wndControl)

    local wndMacroItem = nil
    
    if self.wndEdit:GetData() == nil then
        -- add the new macro
        local idx = #self.tItems + 1
        self:AddMacro(idx, nil)
        wndMacroItem = self.tItems[idx]
    else
        wndMacroItem = self.wndEdit:GetData()
    end
    
    -- set its values
    local strName = self.wndEdit:FindChild("MacroName"):GetText()
    local strSprite = self.wndEdit:FindChild("Icon"):GetSprite()
 	local strCmds = self.wndEdit:FindChild("MacroBody"):GetText()
 	local bGlobal = self.wndEdit:FindChild("GlobalCheck"):IsChecked()
    local id = wndMacroItem:GetData()
    -- set its value in game
    MacrosLib.SetMacroData( id, bGlobal, strName, strSprite, strCmds )
   
    -- update the value in UI
    local tMacro = MacrosLib.GetMacro(id)
    self:UpdateMacroUIData(wndMacroItem, tMacro)
    
    self.wndMacroList:ArrangeChildrenVert()
	self:DestroyMacroWnd()
	
	MacrosLib:SaveMacros()
end

function Macros:OnMacroCancel(wndHandler, wndControl)
	self:DestroyMacroWnd()
end

function Macros:OnIconClick(wndHandler, wndControl)
    self:OpenIconWnd()
end


---------------------------------------------------------------------------------------------------
-- Icon Selections (wndIcon)
---------------------------------------------------------------------------------------------------
function Macros:OpenIconWnd()
	if self.wndIcon == nil then
		self.wndIcon = Apollo.LoadForm(self.xmlDoc, "SelectIcon", nil, self)
		self.bIconsLoaded = false;
        Apollo.CreateTimer("LoadIconTimer", 0.1, false)
		Apollo.StartTimer("LoadIconTimer")
	else
		self.wndIcon:ToFront()
	end
end

function Macros:OnLoadIcons()
	self.wndIconList = self.wndIcon:FindChild("IconList")
	self.wndIconList:SetFocus()
	
	-- create the list of icons
	local arStrMacroIcons = MacrosLib.GetMacroIconList()
	 
	local wndFirstIcon = nil;
	for idx = 1, #arStrMacroIcons do	
	
         if self.wndIcon == nil then -- in case when user quits before done loading
            break
         end
	
         local wnd = Apollo.LoadForm(self.xmlDoc, "IconItem", self.wndIconList, self)
         if idx == 1 then
             wndFirstIcon = wnd
         end
         
         wnd:SetSprite(arStrMacroIcons[idx])
         local strSelectedIconSprite = self.wndEdit:FindChild("Icon"):GetSprite()
         if strSelectedIconSprite == arStrMacroIcons[idx] then
            self:SelectIcon(wnd)
         end
	end
	
	if self.wndSelectedIcon == nil and wndFirstIcon ~= nil then 
        self:SelectIcon(wndFirstIcon) -- select the first icon
    end
		
	self.wndIconList:ArrangeChildrenTiles()	
end

function Macros:DestroyIconWnd()
	if not ( self.wndIcon == nil ) then
		self.wndIcon:Destroy()
		self.wndIcon = nil
		self.wndSelectedIcon = nil
	end
end

function Macros:OnIconOK()
    if self.wndSelectedIcon ~= nil then
        -- assign the selected icon to the icon in edit wnd
        local strIcon = self.wndSelectedIcon:GetSprite()
        local wndIconSprite = self.wndEdit:FindChild("Icon")
        wndIconSprite:SetSprite( strIcon )
    end
	self:DestroyIconWnd()
end

function Macros:OnIconCancel()
	self:DestroyIconWnd()
end

function Macros:SelectIcon(wnd)
    -- hide old selection frame
    if self.wndSelectedIcon ~= nil then
        local wndSelectedFrame = self.wndSelectedIcon:FindChild("IconSelectedFrame")
        wndSelectedFrame:Show(false)
    end
    
    -- show new selection frame
    self.wndSelectedIcon = wnd
    local wndSelectedFrame = self.wndSelectedIcon:FindChild("IconSelectedFrame")
    wndSelectedFrame:Show(true)
end

function Macros:OnIconSelect(wndHandler, wndControl)
 
    self:SelectIcon(wndControl)   
end

---------------------------------------------------------------------------------------------------
-- Macros instance
---------------------------------------------------------------------------------------------------
local MacrosInst = Macros:new()
Macros:Init()
üËl™“¢Æk„§°Qğ´c°FzÚ1X#åLL«üiSiğ‹/e_ÔË³ÒNzb,oøÄø”:ñiÊ¦&¨ßcÆğ]P¯²$_c¦”Í2Êw—"Û0+MÃ•h<Í®³Ğºï†Æ§™Çë çä$ûx¤o@˜g›±Nó¿ˆã údy³Í¸ãË „ñI¡åb/OryZïÄ˜1˜×<ĞKL˜ÿ¨BcÆŒé¼Öm9Í%y˜3•1•/¢Hì
ëzí3}ÎBõÆt¿°cˆÇŒ‘üR¦é£Ä„sªÈaj¥”3ÖòŠz.«¤)BÖl#Œ7åVœû½*x§A|Š¢Ğ >-Ş¾A~ZÔKîÖÑòIÖl*z?†‡ÎD—°LnĞ2‹'™ `¨¡‹_2“Y<Î³‹%¦1Á‰Dï‚¡Óìê@Ùz‰.¤‰¤Ï‹"Ûs„S*§X¶’iìÄ4Ú½M%%82;ÍÇ8Ì–‰<Š${»•¬›cT\Æ=¢ÎŒGÒ"HIÂxFn$D|¤nØWÛ:[+mŸó~X»	ã,Íûp]“_Gé6Íi¯“]˜Æ´+^AØßL.|nšÒëü>H«$mcÆMqê²vWâ(@ÅYí;&\†»”Â„ñH ß®MS.9P˜9\1aü˜$UôÈ„ñ4ÜDùvkÚ2ÎïuUSB/-|åëÛ‡0Arqmh˜´.Š=œ~ÆyP$êÇô[Ç*Üä„|.%	ã-Ğ;ºVÚwÂ•iÀI¨ç'š0EbÚrşmÅ—0a_	³Üø°í*=sÂşFŒ	cí_Gû=Ô„1ğÃÎÛå¡	0}sƒ¥ª`š	cÇÇÍ„O9õmÍØïu†i£a(è¿;®¯_Å:ÇéºQ`FÈUGPœk¥jš0úqÌõ“.u–U1U:àºcbt‘§:hR1FŒæYa4°ôVØZô„±Æëd¢›gÈ&)¡¥ù?P§ ª½Z›0¦x$Ã|:[–±ÁÃ¢Òúb0–wT[Uª.ĞEÖöó¼	gmW„¥`ˆhù$Ç†éJ.{V°Â?'Œ5]å‘BdYÅ&Œ]gÖDÉ¤³Ó˜%&Œ]Oz«IyÂ…¦c×:w ¡`3¬6øÚ¤š™0ôb+Y&†	c7·(jQ¡ÆV~±ÙÔ»a2ñÍ>˜tqùñ¯´’1mîƒäàôŒq¶Öuæš3>ë<?X…&ŒüA€³Î£2ìÑŞœ©Á`n*àŸ‰DÒ<p–pg[r1âa‰wIPœ­	Ä³üjæ±nëReË$\çº4a¬Üj\j‰ÑÂTæ	˜zÄ©3ÑeX×Ëxy&Œ554ŞµÉRÆ²,x
ÎKdl Ö®t< ÆüqÆaºõËºN8‹·ÒCëê›;7Ná§0ÍƒhõbmÆÂ}±Û%R‡¡
šCŞË§§·Ï°Ø»H¸›™1j["ÃUæƒ¶{X2&¿nğ,¢U¸«R¨O8;µšõ¢+şÊĞq¯ìgÂÆ­?Â¡aÌÎ˜®YßCÊª²W¡Qç›óûà_A²¹­p²	ciÖ$uÍ†12k’UâmÚĞĞ,ò½åvÂØ“¯®—×ó‹G«LÁ„1([$}CÂ¤p¯òÔj©!¤yAÕ¯>:SÇdä¶îŒŸ‚$T
iXqcH¾É±.Q"D\?™@lÕëC ÿpıºàJ]í,&&ûJ¤Çà%F[…¡ğ1CY'•}ÂuËFdb³K²Úõ’	ÑVG×ŸKÓš¹»(O¢V¿hÂ K¢O2Ê.)£YˆNñdÛ°’µŒ)RO·år™0¦Hèæ2OÃ2vÈò |iµ¢Œ!Rg;ÿó¨Ê+Ú5&Œ5ò–s¿zsU:>c’\jÿXMf“%×ÜçÙ¶bkÆ8©“·c
tW_âL•Ú„u®ƒcµ¨4+Ü-çJZ^,œD¨SÆV‰&T­¡¦†‚‘UMöE¼NêÑ¼¡¶“r§(ÛáÆì¬)cÆTÆ»rÎ”±cº=ÕË×9Í#U5zà”›(CDsIq£FúÇãÎªg:å˜h([£x…»°ö´sê<Oª´÷åkZİ*çgvEu´ÑıJ ,acw#­òîGlÙU #k8¨úTgœ—ÀVÌ>–X*Šj?¼b.æ^¶½g8Ma§õæó‚ÀªàØiY<ŒéJØej>W™Éy‡ÒçjUO9ú\•¢î·_î‘órbÀ½#ª½9pïˆ¬øõ÷jèJdµÖ´ø±¢ÅÜ‹ 'ÂzÀ½ ª&¸w?Ulï€{éÓ ;`ßøXÑ£îU}9àŞğ8‘mîÕN½5àèØ±Lî5NİÙ?rk„P¢äf&bÑ]à¤uµÚ ›ŞÃBziø/Ñ‹…€õ2ÙCÛjgl}xíCyĞE¯;FwèöQ€Š°×y”½õä¶"»#]7›MÉ}®NÖmHŸ+‹…Ö©;Óçê`Áåäp4èîMQ}€‰`Bp¢6ÅL}# Rw$TA‹sµOd8ñk@é=	œ p÷Ò=Úr<V½ôquôwêö~Ÿ‚4\÷R8€Rìşıòç&ø8`ÓS%{ze[ê3"BÛÊ:ò¸9ä?ŒÈô!x¬p(a¤ÂNÊŞç*Áà·-Erƒ~'PöãRëìs5at/X‹NÕ:FaÅıŒ¸+'ğ6xırfh8CLES˜ú\e›¦ohhhÓ}¬Ù4CCÃ^±ÍÈĞĞRÃ¦Îl«iœ•2óÎÕé¢¯Ö€»uµÓWëáÇ+.}µ6~|ãÒ›ubÂ
ºèÍš11]ôfı˜€ƒ"ìUe@ªêqö¹z1.™J¦°1ÄLL‘Cl]Íû\øŞ0Í–û·´JÛĞçÊÈh¢GQjb}®ŠŒ&¸v¥¿»ÏÕ€c.ú*’Ï¨à4WşÅ®qwŸg÷[_.µk±Äv›Û•bø!ÀÜZ_.e¸y›|mV”qóÛ„êo1ãë/H±>3Z.×Â¥gœSiÀ”)~0$œñˆî²:‰¿t›šo“n=«üÂ2PŸK×_Oc2Úö¹Tı–Ç»Ïååo¬Õ•¨¯ãŒª»Ù¿˜Ğ[CÎ%Ş«‘—N¿ÊÂİçòó