require "Apollo"
require "Window"
require "PreGameLib"

---------------------------------------------------------------------------------------------------
-- Login module definition
---------------------------------------------------------------------------------------------------

local Login = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------


local c_SceneTime = 6 * 60 * 60 -- seonds from midnight
local c_strFormFile = "Login.xml"

---------------------------------------------------------------------------------------------------
-- Login initialization
---------------------------------------------------------------------------------------------------
function Login:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	-- initialize our variables

	-- return our object
	return o
end

---------------------------------------------------------------------------------------------------
function Login:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- Login EventHandlers
---------------------------------------------------------------------------------------------------

function Login:OnLoad()
	math.randomseed(PreGameLib.GetTimeBasedSeed())

	self.wndLogo = Apollo.LoadForm(c_strFormFile, "WildstarLogo", nil, self)
	self.wndVersionString = Apollo.LoadForm(c_strFormFile, "VersionString", nil, self)
	self.wndNetworkStatus = Apollo.LoadForm("UI\\Pregame\\ErrorScreen\\Status.xml", "NetworkStatusMessage", nil, self)

	Apollo.RegisterEventHandler("LoginError", "OnLoginError", self)
	
	Apollo.RegisterEventHandler("NetworkStatus", "OnNetworkStatus", self)
	Apollo.RegisterTimerHandler("NetworkStatusTimer", "OnNetworkStatusTimer", self)

	self.wndNetworkStatus:Show(false)
	
	-- This is where the realm messages get loaded if they exist.	
	self.arServerMessages = PreGameLib.GetLastRealmMessages()
	self.wndServerMessagesContainer = Apollo.LoadForm(c_strFormFile, "RealmMessagesContainer", nil, self)
	self.wndServerMessage = self.wndServerMessagesContainer:FindChild("RealmMessage")

	local strAllMessage = ""
	for _, strMessage in ipairs(self.arServerMessages or {}) do
		strAllMessage = strAllMessage .. strMessage .. "\n"
	end
	
	self.wndServerMessage:SetAML(string.format("<T Font=\"CRB_Interface10_B\" TextColor=\"xkcdBurntYellow\">%s</T>", strAllMessage))
	self.wndServerMessagesContainer:Show(string.len(strAllMessage or "") > 0)
	local nWidth, nHeight = self.wndServerMessage:SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = self.wndServerMessagesContainer:GetAnchorOffsets()
	self.wndServerMessagesContainer:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.min(75, nHeight + 5))
	--self.wndServerMessages:Show(true)


	--PreGameLib.uScene:SetBackground("UI\\Screens\\UI_CRB_LoginScreen.tex")
	PreGameLib.SetMusic( PreGameLib.CodeEnumMusic.Login )
	
	PreGameLib.uScene:SetMap( 1559 );  -- this designates map.  Dont actually change 1346 map, make a new one and put the map number in here.
	PreGameLib.uScene:SetCameraFoVNearFar( 50, .1, 512 ) -- field of view, near plane and far plane settings for camera.  Can not set near plane to 0.  Setting a very small near plane causes graphic artifacts.  
	PreGameLib.uScene:SetMapTimeOfDay(c_SceneTime) -- in seconds from midnight. New band now playing!

	self.wndVersionString:SetText(PreGameLib.GetVersionString())
	
	local cameraOffset = Vector3.New( -1.5, -2, 15 )		
	local up = Vector3.New( 0, 1, 0 )
	self.tPositionOffset = Vector3.New( -4850.41, -905.66, -6420.76 )
	
	PreGameLib.uScene:SetCameraPosition( self.tPositionOffset + cameraOffset, self.tPositionOffset, up )
	
	self.tPlanetPosition = Vector3.New( -4369.47, -879.143, -2812.23 )

	self.primary = PreGameLib.uScene:AddActorByFile(1, "Art\\Cinematics\\Zones\\Login\\Camera_Login.m3")
	if self.primary then
		self.primary:SetPosition(1, self.tPlanetPosition, Vector3:Zero())
		self.primary:AttachCamera(6) -- ModelCamera_Cinematic
		self.primary:Animate( 0, 150, 1, true, false, 1, 0 ) -- last two numbers of this are speed, and %start of animation in that order .  use a speed of 0, and blend between 0 and 1 for zooming camera.  "0, .2 )"
	end	

end

function Login:OnLoginError( strError )
	Apollo.StopTimer("NetworkStatusTimer")
	self.wndNetworkStatus:Show(false)

	-- do something here to show error messages on login -

	return false -- change this to true when ready
end

function Login:OnNetworkStatus( strStatus )
	if strStatus then
		self.wndNetworkStatus:FindChild("NetworkStatus_Body"):SetText( strStatus )
		if not self.wndNetworkStatus:IsShown() then
			Apollo.CreateTimer("NetworkStatusTimer", 2, false)
		end
	else
		Apollo.StopTimer("NetworkStatusTimer")
		self.wndNetworkStatus:Show(false)
	end
end

function Login:OnNetworkStatusTimer()
	self.wndNetworkStatus:Show(true)
end
---------------------------------------------------------------------------------------------------
-- Login instance
---------------------------------------------------------------------------------------------------
local LoginInst = Login:new()
LoginInst:Init()



		
