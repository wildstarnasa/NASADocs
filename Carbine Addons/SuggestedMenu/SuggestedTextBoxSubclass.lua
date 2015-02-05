--------------------------------------------------------------
--SuggestedTextBoxSubclass
--------------------------------------------------------------

local SuggestedTextBoxSubclass = {}
local SuggestedTextBoxSubclassRegistrarInst = {}

function SuggestedTextBoxSubclass:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function SuggestedTextBoxSubclass:Init()
	self.xmlDoc = XmlDoc.CreateFromFile("SuggestedMenu.xml")
end

function SuggestedTextBoxSubclass:HelperAssaignLua()
	local luaSuggestedMenu = SuggestedMenu:new()
	luaSuggestedMenu:Init(self, self.xmlDoc)

	if luaSuggestedMenu and not luaSuggestedMenu.bFailed then
		self.luaSuggestedMenu = luaSuggestedMenu
	end
end

function SuggestedTextBoxSubclass:OnEditBoxChanged(wndHandler, wndControl, strText)
	if wndHandler ~= wndControl then
		return
	end

	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end
	
	if self.luaSuggestedMenu then
		self.luaSuggestedMenu:OnInputChangedUpdateSuggested(wndControl, strText)
	end
end

function SuggestedTextBoxSubclass:OnWindowKeyTab(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end
	
	if self.luaSuggestedMenu then
		self.luaSuggestedMenu:OnSuggestedMenuNavigate()
	end
end

function SuggestedTextBoxSubclass:OnEditBoxReturn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		self.luaSuggestedMenu:OnInputReturn()
	end
end

function SuggestedTextBoxSubclass:IsSuggestedMenuShown()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:HelperIsSuggestedMenuShown()
	end
end

function SuggestedTextBoxSubclass:HideSuggestedMenu()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:HideSuggestedMenu()
	end
end


function SuggestedTextBoxSubclass:SetFilters(tFilterOut)
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		self.luaSuggestedMenu:SetFilters(tFilterOut)
	end
end

--Operators
function SuggestedTextBoxSubclass:GetEnumAnd()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumAnd()
	end
end

function SuggestedTextBoxSubclass:GetEnumOr()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumOr()
	end
end

function SuggestedTextBoxSubclass:GetEnumNot()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumNot()
	end
end

--Lists
function SuggestedTextBoxSubclass:GetEnumFriends()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumFriends()
	end
end

function SuggestedTextBoxSubclass:GetEnumAccountFriends()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumAccountFriends()
	end
end

function SuggestedTextBoxSubclass:GetEnumGroups()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumGroups()
	end
end

function SuggestedTextBoxSubclass:GetEnumNeighbors()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumNeighbors()
	end
end

function SuggestedTextBoxSubclass:GetEnumRecent()
	if not self.luaSuggestedMenu then
		self:HelperAssaignLua()
	end

	if self.luaSuggestedMenu then
		return self.luaSuggestedMenu:GetEnumRecent()
	end
end
--------------------------------------------------------------
--SuggestedTextBoxSubclassRegistrar
--------------------------------------------------------------

local SuggestedTextBoxSubclassRegistrar = {}

function SuggestedTextBoxSubclassRegistrar:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function SuggestedTextBoxSubclassRegistrar:Init()
    Apollo.RegisterAddon(self)

	--Register for events to handle here 
	--**events that are already registered in xml, will not be caught,
	--in the lua for the registered handled event, must manually go through
	--the subclass and call the function here
    Apollo.RegisterWindowSubclass("SuggestedTextBoxSubclass", self, 
	{
		{strEvent = "EditBoxChanged", strFunction = "OnEditBoxChanged"},
		{strEvent = "WindowKeyTab", strFunction = "OnWindowKeyTab"},
		{strEvent = "EditBoxReturn", strFunction = "OnEditBoxReturn"},
	
	})
end

function SuggestedTextBoxSubclassRegistrar:SubclassWindow(wndNew, strSubclass, strParam)
	local subclass = SuggestedTextBoxSubclass:new({wnd = wndNew})
	subclass:Init()
	wndNew:SetWindowSubclass(subclass, strParam)
end

SuggestedTextBoxSubclassRegistrarInst = SuggestedTextBoxSubclassRegistrar:new()
SuggestedTextBoxSubclassRegistrarInst:Init()oint="0" LAnchorOffset="29" TAnchorPoint="0" TAnchorOffset="29" RAnchorPoint="1" RAnchorOffset="-29" BAnchorPoint="1" BAnchorOffset="-29" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="Blocker" BGColor="UI_AlphaPercent90" TextColor="ffffffff" TooltipColor="" Sprite="BK3:spr_BK3_Holo_Alert_Confirm_Blocker" Picture="1" HideInEditor="1" NewControlDepth="2" Visible="0" Sizable="0" IgnoreMouse="0"/>
        <Control Class="Button" Base="BK3:btnHolo_Close" Font="CRB_InterfaceMedium" ButtonType="PushButton" RadioGroup="" LAnchorPoint="1" LAnchorOffset="-70" TAnchorPoint="0" TAnchorOffset="28" RAnchorPoint="1" RAnchorOffset="-28" BAnchorPoint="0" BAnchorOffset="73" DT_VCENTER="1" DT_CENTER="1" Name="CloseButton" BGColor="ffffffff" TextColor="ffffffff" NoClip="1" WindowSoundTemplate="CloseWindowPhys" NormalTextColor="ffffffff" PressedTextColor="ffffffff" FlybyTextColor="ffffffff" PressedFlybyTextColor="ffffffff" DisabledTextColor="ffffffff" TooltipColor="">
            <Event Name="ButtonSignal" Function="OnClose"/>
        </Control>
    </Form>
    <Form Class="Window" LAnchorPoint=".5" LAnchorOffset="-228" TAnchorPoint=".5" TAnchorOffset="-133" RAnchorPoint=".5" RAnchorOffset="228" BAnchorPoint=".5" BAnchorOffset="129" RelativeToClient="1" Font="Default" Text="" Template="Default" Name="DeathConfirm" Border="0" Picture="0" SwallowMouseClicks="1" Moveable="0" Escapable="0" Overlapped="1" BGColor="ffffffff" TextColor="ffffffff" TextId="" TooltipColor="" Tooltip="" Sprite="" NoClip="1" NewControlDepth="1" IgnoreMouse="1" TransitionShowHide="1">
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="Default" Text="" Template="Holo_Small" Name="BGArt" BGColor="white" TextColor="white" Picture="1" IgnoreMouse="1" Sprite="" HideInEditor="0" TooltipColor="" Border="1" UseTemplateBG="1"/>
        <Control Class="Window" LAnchorPoint=".5" LAnchorOffset="-130" TAnchorPoint="0" TAnchorOffset="53" RAnchorPoint=".5" RAnchorOffset="130" BAnchorPoint="0" BAnchorOffset="139" RelativeToClient="1" Font="CRB_InterfaceMedium" Template="Default" Name="NoticeTextFrame" BGColor="ffffffff" TextColor="UI_TextHoloTitle" DT_CENTER="1" DT_VCENTER="1" DT_WORDBREAK="1" TextId="" TooltipColor="" Text="" Tooltip="" Sprite="BK3:UI_BK3_Holo_InsetSimple" Picture="1" IgnoreMouse="1" NewControlDepth="2"/>
        <Control Class="Window" LAnchorPoint=".5" LAnchorOffset="-120" TAnchorPoint="0" TAnchorOffset="56" RAnchorPoint=".5" RAnchorOffset="120" BAnchorPoint="0" BAnchorOffset="135" RelativeToClient="1" Font="CRB_InterfaceMedium" Template="Default" Name="NoticeText" BGColor="ffffffff" TextColo