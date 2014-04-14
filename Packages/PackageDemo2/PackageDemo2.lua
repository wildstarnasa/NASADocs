-----------------------------------------------------------------------------------------------
-- Client Lua Script for PackageDemo2
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- PackageDemo2 Module Definition
-----------------------------------------------------------------------------------------------
local PackageDemo2 = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PackageDemo2:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function PackageDemo2:Init()
    Apollo.RegisterAddon(self, false, "", {"DemoPkg"})
end
 

-----------------------------------------------------------------------------------------------
-- PackageDemo2 OnLoad
-----------------------------------------------------------------------------------------------
function PackageDemo2:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PackageDemo2.xml")
	
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self.pkgDemo = Apollo.GetPackage("DemoPkg").tPackage
	
	-- if something has gone wrong, return a string, otherwise return nil
end

function PackageDemo2:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	-- if you return false, or don't define this function
	-- any Addons/Packages that list you as a dependency
	-- will also receive a dependency error
	return false
end

-----------------------------------------------------------------------------------------------
-- PackageDemo2:OnDocLoaded 
-----------------------------------------------------------------------------------------------
function PackageDemo2:OnDocLoaded()

	-- check for external dependencies here
	if self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "PackageDemo2Form", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

		self.wndResults = self.wndMain:FindChild("Results")		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("packagedemo2", "OnPackageDemo2On", self)


		-- Do additional Addon initialization here
		
	end
end

-----------------------------------------------------------------------------------------------
-- PackageDemo2 Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/packagedemo"
function PackageDemo2:OnPackageDemo2On()
	self.wndMain:Show(true) -- show the window
end


-----------------------------------------------------------------------------------------------
-- PackageDemo2Form Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function PackageDemo2:OnCallPackageFn()
	self.pkgDemo.DoSomethingWithAWindow(self.wndResults)
end

-- when the Cancel button is clicked
function PackageDemo2:OnCancel()
	self.wndMain:Show(false) -- hide the window
end


-----------------------------------------------------------------------------------------------
-- PackageDemo2 Instance
-----------------------------------------------------------------------------------------------
local PackageDemo2Inst = PackageDemo2:new()
PackageDemo2Inst:Init()
