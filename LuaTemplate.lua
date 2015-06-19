--[[ 
-----------------------------------------------------------------------------------------------
									Wildstar NASA Lua Template
									
	Based on Carbine's default template. Includes a number of common
	sections not clearly documented.
-----------------------------------------------------------------------------------------------
												Instructions
-----------------------------------------------------------------------------------------------
	Find and Replace the following:	
			$AddonName -- Addon Name
			$Author -- Author Name	
	Do not use whole word, but do make it Case Sensitive
--------------------------------------------------------------------------------------------
											Optional Sections
---------------------------------------------------------------------------------------------
Remove sections if not desired

-------------------------------------- Slash Command ----------------------------------
	$SlashCommand -- String - Slash Command 
	
	Uncomment line in OnDocLoaded
	
--------------------------------------------- Timer -----------------------------------------
	$TimerInterval -- Number - Interval of Timer
	$TimerRepeat -- Boolean - Timer Repeating
	
	Uncomment line in OnDocLoaded
	
------------------------------------- Interface Menu Button ----------------------------
	$ShortcutKey -- String - Key for shortcut if desired. Replace with nothing if not desired
	$MenuSprite -- String - The icon on the menu button if desired. Replace with nothing if not desired

-------------------------------------- Configuration Button -----------------------------

-------------------------------------- Save and Restore Data-----------------------------

 ]]

-----------------------------------------------------------------------------------------------
-- 								$AddonName
-- 		Copyright (c) $Author. All rights reserved
-- 
-----------------------------------------------------------------------------------------------
require "Window"
 
-----------------------------------------------------------------------------------------------
-- $AddonName Module Definition
-----------------------------------------------------------------------------------------------
local $AddonName = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function $AddonName:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
	
    -- initialize variables here
	self.tSavedVariables = {}
    return o
end

function $AddonName:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 
 function $AddonName:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	if strDep == " " then
		return true
	end
	return false
end
-----------------------------------------------------------------------------------------------
-- $AddonName OnLoad
-----------------------------------------------------------------------------------------------
function $AddonName:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("$AddonName.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- $AddonName OnDocLoaded
-----------------------------------------------------------------------------------------------
function $AddonName:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "$AddonNameForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		---------------------- Event Handlers --------------------------------------------
		-- Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded",	"OnInterfaceMenuLoaded", self)
		-- Apollo.RegisterEventHandler("$AddonName_InterfaceMenu",	"$AddonNameInterfaceMenu", self)
		
		------------------------ Slash Commands ----------------------------------------
		-- Apollo.RegisterSlashCommand("$SlashCommand", "On$AddonNameOn", self)
		
		------------------------------------- Timers ----------------------------------------
		-- self.timer = ApolloTimer.Create($TimerInterval, $TimerRepeat, "OnTimer", self)
		
		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Save and Restore Data
-----------------------------------------------------------------------------------------------
function $AddonName:OnSave(eLevel)
	local tSavedData = {}
	-- This example uses account level saves.
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
	-- Set your variables into tData
	end
	
	return tSavedData
end

function $AddonName:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		-- Set your reference for the saved variables
		self.tSavedVariables = tData
	end
end

-----------------------------------------------------------------------------------------------
-- InterfaceMenu Button
--  Remove if you don't want an interface menu button
-----------------------------------------------------------------------------------------------
function $AddonName:OnInterfaceMenuLoaded()
	local tData = {"$AddonName_InterfaceMenu", "$ShortcutKey","$MenuSprite"}
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "$AddonName" , tData)
end

function $AddonName:On$AddonNameInterfaceMenu()
	-- Define what happens here.
	self:On$AddonNameOn()
end

-----------------------------------------------------------------------------------------------
-- Configuration Button
--  Remove if you don't want configuration menu button
-----------------------------------------------------------------------------------------------
function $AddonName::OnConfigure()
	-- Define what happens when the Configuration menu button is clicked.
end

-----------------------------------------------------------------------------------------------
-- $AddonName Functions
-----------------------------------------------------------------------------------------------
---------------------------------- Slash Command Function ----------------------------
-- Remove if not needed
function $AddonName:On$AddonNameOn()
	self.wndMain:Invoke() -- show the window
end
----------------------------------------- Timer Function ---------------------------------
-- Remove if not needed
function $AddonName:OnTimer()
	-- Do your timer-related stuff here.
end
----------------------------------- General Functions -----------------------------------


-----------------------------------------------------------------------------------------------
-- $AddonNameForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function $AddonName:OnOK(wndHandler, wndControl, eMouseButton )
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function $AddonName:OnCancel(wndHandler, wndControl, eMouseButton )
	self.wndMain:Close() -- hide the window
end

-----------------------------------------------------------------------------------------------
-- $AddonName Instance
-----------------------------------------------------------------------------------------------
local $AddonNameInst = $AddonName:new()
$AddonNameInst:Init()