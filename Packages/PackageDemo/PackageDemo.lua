-----------------------------------------------------------------------------------------------
-- Client Lua Script for PackageDemo
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- PackageDemo Module Definition
-----------------------------------------------------------------------------------------------
local PackageDemo = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PackageDemo:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function PackageDemo:Init()
    Apollo.RegisterAddon(self, false, "", {"DemoPkg"})
end
 

-----------------------------------------------------------------------------------------------
-- PackageDemo OnLoad
-----------------------------------------------------------------------------------------------
function PackageDemo:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PackageDemo.xml")
	
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self.pkgDemo = Apollo.GetPackage("DemoPkg").tPackage
	
	-- if something has gone wrong, return a string, otherwise return nil
end

function PackageDemo:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	-- if you return false, or don't define this function
	-- any Addons/Packages that list you as a dependency
	-- will also receive a dependency error
	return false
end

-----------------------------------------------------------------------------------------------
-- PackageDemo:OnDocLoaded 
-----------------------------------------------------------------------------------------------
function PackageDemo:OnDocLoaded()

	-- check for external dependencies here
	if self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "PackageDemoForm", nil, self)
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
		Apollo.RegisterSlashCommand("packagedemo", "OnPackageDemoOn", self)


		-- Do additional Addon initialization here
		
	end
end

-----------------------------------------------------------------------------------------------
-- PackageDemo Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/packagedemo"
function PackageDemo:OnPackageDemoOn()
	self.wndMain:Show(true) -- show the window
end


-----------------------------------------------------------------------------------------------
-- PackageDemoForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function PackageDemo:OnCallPackageFn()
	self.pkgDemo.DoSomethingWithAWindow(self.wndResults)
end

-- when the Cancel button is clicked
function PackageDemo:OnCancel()
	self.wndMain:Show(false) -- hide the window
end


-----------------------------------------------------------------------------------------------
-- PackageDemo Instance
-----------------------------------------------------------------------------------------------
local PackageDemoInst = PackageDemo:new()
PackageDemoInst:Init()
