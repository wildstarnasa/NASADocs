-- Util.lua
-- Carbine Studios, LLC


function FixXMLString(str)
	str = str:gsub("&", "&amp;")	-- must do this first!
	str = str:gsub("<", "&lt;")
	str = str:gsub(">", "&gt;")
	str = str:gsub("'", "&apos;")
	str = str:gsub('"', "&quot;")
	return str
end


---------------------------------------------------------------------------------------------------
-- TableUtil:Copy
---------------------------------------------------------------------------------------------------
TableUtil = {}
function TableUtil:Copy(t)
  local t2 = {}
  if type(t) ~= "table" then
    return t
  end
  for k,v in pairs(t) do
    t2[k] = TableUtil:Copy(v)
  end
  return t2
end

---------------------------------------------------------------------------------------------------
-- fifo queue implementation
---------------------------------------------------------------------------------------------------
Queue = {}

function Queue:new(o)
  	o = o or {tItems={}}
	setmetatable(o, self)
	self.__index = self
	o.iFirst = 1
	o.iLast = 0
	return o
end
---------------------------------------------------------------------------------------------------
function Queue:Push( oValue )
    local iNewIndex = self.iLast + 1
	self.iLast = iNewIndex
	self.tItems[iNewIndex] = oValue
	return iNewIndex
end
---------------------------------------------------------------------------------------------------
function Queue:Pop()
	local iNewFront = self.iFirst
	if self:Empty() then
		return
	end
	
	local oValue = self.tItems[iNewFront]
	self.tItems[iNewFront] = nil
	self.iFirst = iNewFront + 1
	
	return oValue
end
---------------------------------------------------------------------------------------------------
function Queue:InsertAbsolute( iPos, item )
	if iPos < self.iFirst or iPos > self.iLast + 1 then
		return 0
	end
    table.insert( self.tItems, iPos, item )
	self.iLast = self.iLast + 1
	return iPos
end
---------------------------------------------------------------------------------------------------
function Queue:RemoveAbsolute( iPos )
	if iPos < self.iFirst or iPos > self.iLast then
		return 0
	end
    table.remove( self.tItems, iPos )
	self.iLast = self.iLast - 1
	return iPos
end
---------------------------------------------------------------------------------------------------
function Queue:Insert( iPos, item )
	return self:InsertAbsolute( self.iFirst + iPos - 1, item )
end
---------------------------------------------------------------------------------------------------
function Queue:Remove( iPos )
    return self:RemoveAbsolute( self.iFirst + iPos - 1, item )
end
---------------------------------------------------------------------------------------------------
function Queue:GetItems()
    return self.tItems
end
---------------------------------------------------------------------------------------------------
function Queue:GetSize()
    return self.iLast - self.iFirst + 1
end
---------------------------------------------------------------------------------------------------
function Queue:Empty()
	return self.iFirst > self.iLast
end
---------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local UtilLib = {}

function UtilLib:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function UtilLib:Init()
	Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- Rover OnLoad
-----------------------------------------------------------------------------------------------
function UtilLib:OnLoad()
end


-----------------------------------------------------------------------------------------------
-- Rover Instance
-----------------------------------------------------------------------------------------------
local UtilLibInst = UtilLib:new()
UtilLibInst:Init()
UtilLibInst = nil



