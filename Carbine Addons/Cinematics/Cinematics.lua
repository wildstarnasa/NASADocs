require "Window"
require "Unit"


---------------------------------------------------------------------------------------------------
-- Cinematics module definition

local Cinematics = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Cinematics initialization
---------------------------------------------------------------------------------------------------
function Cinematics:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	-- initialize our variables

	-- return our object
	return o
end

---------------------------------------------------------------------------------------------------
function Cinematics:Init()

	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- Cinematics EventHandlers
---------------------------------------------------------------------------------------------------


function Cinematics:OnLoad()
	Apollo.RegisterEventHandler("CinematicsNotify", "OnCinematicsNotify", self)
	Apollo.RegisterEventHandler("CinematicsCancel", "OnCinematicsCancel", self)
	-- load our forms
	self.wndCin = Apollo.LoadForm("Cinematics.xml", "CinematicsWindow", nil, self)
	self.wndCin:Show(false)
end
	
---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

function Cinematics:OnCinematicsNotify(msg, param)
	-- save the parameter and show the window
	self.wndCin:FindChild("Message"):SetText(msg)
	self.wndCin:Show(true)
	self.param = param
end

function Cinematics:OnCinematicsCancel(param)
	-- save the parameter and show the window
	if param == self.param then
		self.wndCin:Show(false)
	end
end

function Cinematics:OnPlay()
	-- call back to the game with 
	Cinematics_Play(self.param)
	self.wndCin:Show(false)
end

function Cinematics:OnCancel()
	-- call back to the game with
	Cinematics_Cancel(self.param)
	self.wndCin:Show(false)
end

---------------------------------------------------------------------------------------------------
-- Cinematics instance
---------------------------------------------------------------------------------------------------
local CinematicsInst = Cinematics:new()
Cinematics:Init()



		