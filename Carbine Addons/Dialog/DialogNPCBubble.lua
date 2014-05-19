-- Client lua script
require "Window"
require "DialogSys"
require "Quest"
require "Unit"

---------------------------------------------------------------------------------------------------
-- DialogNPCBubble
---------------------------------------------------------------------------------------------------
DialogNPCBubble = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------
local kDefaultFont = "CRB_Dialog"
local kDefaultTextColor = "ff8096a8"
local kCommTextColor = "ffb1ffff"
local kRewardIconCnt = 4
local kRewardHeight = 35

---------------------------------------------------------------------------------------------------
-- DialogNPCBubble initialization
---------------------------------------------------------------------------------------------------
function DialogNPCBubble:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	-- return our object
	return o
end

---------------------------------------------------------------------------------------------------
function DialogNPCBubble:Init(parentWnd, id)

end
