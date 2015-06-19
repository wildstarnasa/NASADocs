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
SuggestedTextBoxSubclassRegistrarInst:Init()