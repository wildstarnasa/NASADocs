
-----------------------------------------------------------------------------------------------
-- DemoPkg Definition
-----------------------------------------------------------------------------------------------
local DemoPkg = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------
-- DemoPkg OnLoad
-----------------------------------------------------------------------------------------------
function DemoPkg:OnLoad()
	-- called when all dependencies are loaded
	-- if something has gone wrong, return a string with 
	-- the strError that will be passed to YOUR dependencies
end

function DemoPkg:OnDependencyError(strDep, strError)
	-- if you don't care about this dependency, return true.
	-- if you return false, or don't define this function
	-- any Addons/Packages that list you as a dependency
	-- will also receive a dependency error
	return false
end

function DemoPkg:OnSave(eType)
	-- Packages can save data, but this one doesn't
	return nil
end

function DemoPkg:OnRestore(eType, tData)
	-- Packages can restore data too
end

-----------------------------------------------------------------------------------------------
-- DemoPkg functions
-----------------------------------------------------------------------------------------------

function DemoPkg.DoSomethingWithAWindow(wnd)
	if wnd ~= nil then
		wnd:SetText("Okay, I did something (version 2)")
	end
end

-----------------------------------------------------------------------------------------------
-- DemoPkg Instance
-----------------------------------------------------------------------------------------------
--DemoPkg:Init()
Apollo.RegisterPackage(DemoPkg, "DemoPkg", 2, {})
DemoPkg = nil	-- setting nil here allows this table to be collected if a newer one exists



