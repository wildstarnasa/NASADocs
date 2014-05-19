-----------------------------------------------------------------------------------------------
-- Client Lua Script for Who
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "ChatSystemLib"
 
-----------------------------------------------------------------------------------------------
-- Who Module Definition
-----------------------------------------------------------------------------------------------
local Who = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Who:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function Who:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- Who OnLoad
-----------------------------------------------------------------------------------------------
function Who:OnLoad()
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
    
	Apollo.RegisterEventHandler("WhoResponse", "OnWhoResponse", self)

end


-----------------------------------------------------------------------------------------------
-- Who Functions
-----------------------------------------------------------------------------------------------

function Who:OnWhoResponse(arResponse, eWhoResult)
	if eWhoResult == GameLib.CodeEnumWhoResult.OK or eWhoResult == GameLib.CodeEnumWhoResult.Partial then
		if arResponse == nil or #arResponse == 0 then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("Who_NoResults"))
			return
		end

		for _, tWho in ipairs(arResponse) do
			-- each line in arResponse has strName, nLevel, eRaceId, eClassId, ePlayerPathType, nWorldZone, strRace, strClass, strZone, strPath, the last 4 can be nil
			local strLine = String_GetWeaselString(Apollo.GetString("Who_Listing"), tWho.strName, tWho.nLevel, tWho.strRace or "", tWho.strClass or "", tWho.strPath or "", tWho.strZone or "")
		
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strLine, "")
		end
	elseif eWhoResult == GameLib.CodeEnumWhoResult.UnderCooldown then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, Apollo.GetString("Who_UnderCooldown"), "")
	end
end

-----------------------------------------------------------------------------------------------
-- Who Instance
-----------------------------------------------------------------------------------------------
local WhoInst = Who:new()
WhoInst:Init()
