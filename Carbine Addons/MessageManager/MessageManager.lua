require "MessageManagerLib"
require "Window"
require "CombatFloater"
require "GameLib"
require "Unit"


---------------------------------------------------------------------------------------------------
--Float Text
MessageManager = {}

----------------------------------------------------------------------------------------------- 
-- Constants 
----------------------------------------------------------------------------------------------- 

-- enum for all the message type handled - should be global so that it can be used throughout the lua scripts
LuaEnumMessageType = 
{
    AchievementAdvanced 			= 1,
    BonusKillNotice 				= 2,
    BossBattleNotifications 		= 3,
    CastBar 						= 4,
    ChallengePrompt 				= 5,
    CurrencyCollected 				= 6,
    DuelInvite 						= 7,
    DuelingNotifications 			= 8,
    EpisodeStart 					= 9,
    EpisodeComplete 				= 10,
    GenericPlayerInvokedError 		= 11,
    GroupInvite 					= 12,
    HoldoutPrompt 					= 13,
    LootCollectionPrompt 			= 14,
    LootCollected 					= 15,
    PVPBattlegroundNotifications 	= 16,
    QuestObjectiveAdvanced 			= 17,
    ReputationIncrease 				= 18,
    SpellCastError 					= 19,
    StoryPanel 						= 20,
    SystemMessage 					= 21,
    XPAwarded 						= 22,
    ZoneName 						= 23,
	PathXp 							= 24,
	TradeskillXp 					= 25,
	RealmBroadcastTierMedium 		= 26,
	AlternateCurrency		 		= 27,
}

local LuaEnumMessageField = 
{
    Upper = 1,
    Alert = 2,
    Middle = 3,
    Lower = 4,
}

local LuaEnumMessageDisplayType =
{
    TextFloater = 1,
    Window = 2,
    StoryPanel = 3,
}

local ktMessageSettings = {}  



-- if preempt, it will replace the current message on screen if current message is preemptable or destroyable. else it will put into front of queue behind all other preempt items
-- if preemptable, when the msg is on screen when a preempt message kicks in, the msg on screen will add back to the front of display queue
-- if destroyable, when the msg is on screen when a preempt message kicks in, the msg will be destroyed
-- if bQueue, then it will be queued by priority and bPreempt will take no effect
-- if bRemoveSameTypeInQueue, then it will remove all the previous messages that are still in the queue

ktMessageSettings = 
{
	[LuaEnumMessageType.AchievementAdvanced] 			= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 3,	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.BonusKillNotice] 				= {eField = LuaEnumMessageField.Middle,	bQueue = true,	nPriority = 1,	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.BossBattleNotifications] 		= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.CastBar] 						= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.ChallengePrompt] 				= {eField = LuaEnumMessageField.Alert,	bQueue = true,	nPriority = 3,	bPreempt = true,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.CurrencyCollected] 				= {eField = LuaEnumMessageField.Lower,	bQueue = true,	nPriority = 4,	bPreempt = false,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.DuelInvite] 					= {eField = LuaEnumMessageField.Alert,	bQueue = true,	nPriority = 5,	bPreempt = true,	bPreemptable = true,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.DuelingNotifications] 			= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1, 	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.EpisodeStart] 					= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 5,	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.EpisodeComplete] 				= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 4,	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.GenericPlayerInvokedError] 		= {eField = LuaEnumMessageField.Lower,	bQueue = false,	nPriority = 1,	bPreempt = true,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	--[LuaEnumMessageType.GenericPlayerInvokedError] 		= {eField = LuaEnumMessageField.Lower,	bQueue = false,	nPriority = 2,	bPreempt = true,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.GroupInvite] 					= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = true,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.HoldoutPrompt] 					= {eField = LuaEnumMessageField.Alert,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.LootCollectionPrompt] 			= {eField = LuaEnumMessageField.Lower,	bQueue = false,	nPriority = 5,	bPreempt = false,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.LootCollected] 					= {eField = LuaEnumMessageField.Lower,	bQueue = true,	nPriority = 3,	bPreempt = false,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.PVPBattlegroundNotifications] 	= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = false,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.QuestObjectiveAdvanced] 		= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 2,	bPreempt = false,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.ReputationIncrease] 			= {eField = LuaEnumMessageField.Lower,	bQueue = true,	nPriority = 3,	bPreempt = false,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.SpellCastError] 				= {eField = LuaEnumMessageField.Lower,	bQueue = false,	nPriority = 1,	bPreempt = true,	bPreemptable = false,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.StoryPanel] 					= {eField = LuaEnumMessageField.Alert,	bQueue = true,	nPriority = 4,	bPreempt = false,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.SystemMessage] 					= {eField = LuaEnumMessageField.Alert,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = false,	bDestroyable = false,	bReposition = false,},
	[LuaEnumMessageType.XPAwarded] 						= {eField = LuaEnumMessageField.Middle,	bQueue = true,	nPriority = 2,	bPreempt = false,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.ZoneName] 						= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = true,	bDestroyable = true,	bReposition = false,	bRemoveSameTypeInQueue = true},
	[LuaEnumMessageType.PathXp] 						= {eField = LuaEnumMessageField.Middle,	bQueue = true,	nPriority = 2,	bPreempt = false,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.TradeskillXp] 					= {eField = LuaEnumMessageField.Middle,	bQueue = true,	nPriority = 2,	bPreempt = false,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.RealmBroadcastTierMedium] 		= {eField = LuaEnumMessageField.Upper,	bQueue = true,	nPriority = 1,	bPreempt = true,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
	[LuaEnumMessageType.AlternateCurrency] 				= {eField = LuaEnumMessageField.Lower,	bQueue = true,	nPriority = 3,	bPreempt = true,	bPreemptable = true,	bDestroyable = true,	bReposition = false,},
}

local kfFirstMessageStallDuration = 20 -- updated OnFrame so figure about 30 fps
---------------------------------------------------------------------------------------------------

function MessageManager:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	self.tDisplayQueue = {}
    self.tMessagesOnScreen = {}   
    
	return o
end

---------------------------------------------------------------------------------------------------

function MessageManager:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
function MessageManager:OnLoad()
	Apollo.RegisterEventHandler("Float_RequestShowTextFloater", 	"RequestShowTextFloater", self )
	Apollo.RegisterEventHandler("MessageFinished", 					"OnMessageFinished", self )
	Apollo.RegisterEventHandler("StoryPanel_StoryPanelHidden", 		"OnMessageFinished", self)
	Apollo.RegisterEventHandler("RequestShowStoryPanel",			"OnRequestShowStoryPanel", self )
	Apollo.RegisterEventHandler("MessageManager_HideStoryPanel", 	"HideStoryPanels", self)
	--Apollo.RegisterEventHandler("VarChange_FrameCount", 			"OnFrameUpdate", self)
	Apollo.RegisterTimerHandler("MessageUpdateTimer", 				"OnFrameUpdate", self)
	
	Apollo.CreateTimer("MessageUpdateTimer", 0.05, true)
	
	Apollo.RegisterSlashCommand("hidetext", 						"OnHideText", self ) -- for testing
    -- initialize queues
    
	self.tFirstMessageStall = {}
	
    for key, eValue in pairs(LuaEnumMessageField) do
		self.tDisplayQueue[eValue] = Queue:new()
        self.tMessagesOnScreen[eValue] = nil
		self.tFirstMessageStall[eValue] = 0
    end
end

---------------------------------------------------------------------------------------------------
function MessageManager:OnFrameUpdate()
    -- display item in queue if the message on screen is empty
    for key, eValue in pairs(LuaEnumMessageField) do
        if self.tMessagesOnScreen[eValue] == nil then
            -- show the first message on queue if any
            if not self.tDisplayQueue[eValue]:Empty() then
				if self.tFirstMessageStall[eValue] > 0 then -- delay the first message for things to amass. We'll loop back around on the next frame
					self.tFirstMessageStall[eValue] = self.tFirstMessageStall[eValue] - 1
				else
					local tParams = self.tDisplayQueue[eValue]:Pop()
					if tParams then
						self:ShowMessage(tParams.eMessageType, tParams)
					end
				end
            end
        end
    end 
		
end
---------------------------------------------------------------------------------------------------
-- use this function to request displaying text floaters
-- tParams = the same as the param for ShowTextFloater
function MessageManager:RequestShowTextFloater(eMessageType, tParams, tContent)
	if tContent ~= nil and eMessageType == LuaEnumMessageType.XPAwarded then
		self:UpdateOrAddXpFloater(eMessageType, tParams, tContent)
	elseif tContent ~= nil and eMessageType == LuaEnumMessageType.AlternateCurrency then
		self:UpdateOrAddPathXpFloater(eMessageType, tParams, tContent)
	elseif tContent ~= nil and eMessageType == LuaEnumMessageType.PathXp then
		self:UpdateOrAddPathXpFloater(eMessageType, tParams, tContent)	
	elseif tContent ~= nil and eMessageType == LuaEnumMessageType.ReputationIncrease then
		self:UpdateOrAddRepFloater(eMessageType, tParams, tContent)	
	else
		tParams.eDisplayType = LuaEnumMessageDisplayType.TextFloater
		self:RequestShowMessage( eMessageType, tParams )
	end	
end

function MessageManager:UpdateOrAddXpFloater(eMessageType, tParams, tContent)
	-- For XP the content table has:
	-- tContent.nType = LuaEnumMessageType.XPAwarded
	-- tContent.nNormal
	-- tContent.nRested
	local bUpdated = false
	
	--[[ Stopping the stomp of float text. TODO: Formatting should be done for floaters in float text
	local eField = ktMessageSettings[eMessageType].eField
	for idx, tMessage in pairs(self.tDisplayQueue[eField]:GetItems()) do
		if eMessageType == tMessage.eMessageType then
			local nNormalCombined = tMessage.tContent.nNormal + tContent.nNormal
			local nRestedCombined = tMessage.tContent.nRested + tContent.nRested
			

			if nNormalCombined > 0 and nRestedCombined > 0 then
				tMessage.strText = String_GetWeaselString(Apollo.GetString("MessageManager_XPWithRest"), nNormalCombined, nRestedCombined)
			elseif nNormalCombined > 0 then
				tMessage.strText = String_GetWeaselString(Apollo.GetString("MessageManager_XP"), nNormalCombined)
			elseif nRestedCombined > 0 then
				tMessage.strText = String_GetWeaselString(Apollo.GetString("MessageManager_RestXP"), nRestedCombined)
			end


			tMessage.tContent.nNormal = nNormalCombined
			tMessage.tContent.nRested = nRestedCombined
			bUpdated = true
		end
	end
	]]--

	if not bUpdated then
		tParams.eDisplayType = LuaEnumMessageDisplayType.TextFloater
		tParams.eMessageType = eMessageType
		tParams.tContent = tContent
		self:RequestShowMessage(eMessageType, tParams)
	end
end

function MessageManager:UpdateOrAddPathXpFloater(eMessageType, tParams, tContent)
	-- For Path XP the content table has:
	-- tContent.nType 
	-- tContent.nAmount 	
	
	local bUpdated = false
	local eField = ktMessageSettings[eMessageType].eField
	for idx, tMessage in pairs(self.tDisplayQueue[eField]:GetItems()) do
		if eMessageType == tMessage.eMessageType then
			local nCombined = tMessage.tContent.nAmount + tContent.nAmount
			tMessage.strText = String_GetWeaselString(Apollo.GetString("MessageManager_PathXP"), nCombined)
			tMessage.tContent.nAmount = nCombined
			bUpdated = true
		end
	end

	if not bUpdated then
		tParams.eDisplayType = LuaEnumMessageDisplayType.TextFloater
		tParams.eMessageType = eMessageType
		tParams.tContent = tContent
		self:RequestShowMessage(eMessageType, tParams)
	end
end

function MessageManager:UpdateOrAddRepFloater(eMessageType, tParams, tContent)	
	-- For Rep the content table has:
	-- tContent.nType 
	-- tContent.nAmount 	
	-- tContent.nFactionId 
	-- tContent.nName 
	
	local bUpdated = false
	local eField = ktMessageSettings[eMessageType].eField
	for idx, tMessage in pairs(self.tDisplayQueue[eField]:GetItems()) do
		if eMessageType == tMessage.eMessageType and tContent.idFaction == tMessage.tContent.idFaction then
			local nCombined = tMessage.tContent.nAmount + tContent.nAmount
			tMessage.strText = String_GetWeaselString(Apollo.GetString("MessageManager_Rep"), nCombined, tMessage.tContent.strName)
			tMessage.tContent.nAmount = nCombined
			bUpdated = true
		end
	end

	if not bUpdated then
		tParams.eDisplayType = LuaEnumMessageDisplayType.TextFloater
		tParams.eMessageType = eMessageType
		tParams.tContent = tContent
		self:RequestShowMessage( eMessageType, tParams )
	end
end

---------------------------------------------------------------------------------------------------
-- use this function to request displaying window
-- wndMessage = the window to be displayed
function MessageManager:RequestShowWindow(eMessageType, wndMessage)
    local tParams = 
	{
		wndMessage 		= wndMessage,
		eDisplayType 	= LuaEnumMessageDisplayType.Window,
	}
    self:RequestShowMessage(eMessageType, tParams)
end
---------------------------------------------------------------------------------------------------
-- use this function to request displaying alert
-- params are params used in AlertMessage:DisplayAlert
function MessageManager:RequestShowAlert(eMessageType, tParams)
    tParams.eDisplayType = LuaEnumMessageDisplayType.Alert 
    self:RequestShowMessage(eMessageType, tParams)
end
---------------------------------------------------------------------------------------------------
-- use this function to request displaying story panel
-- params are params used in StoryPanel:ShowStoryPanel
function MessageManager:OnRequestShowStoryPanel(eMessageType, tParams)
    tParams.eDisplayType = LuaEnumMessageDisplayType.StoryPanel 
    self:RequestShowMessage(eMessageType, tParams)
end

---------------------------------------------------------------------------------------------------
function MessageManager:RequestShowMessage(eMessageType, tParams)
    
    local eField = ktMessageSettings[eMessageType].eField
    tParams.eMessageType = eMessageType
    
    -- if the tMessage is queueable then add it into queue
    if ktMessageSettings[eMessageType].bQueue == true then
        tParams.eMessageType = eMessageType
        
        -- insert the tMessage into the queue according to the priority
        local nPriority = ktMessageSettings[eMessageType].nPriority
            

		-- if bRemoveSameTypeInQueue then go thru the queue and remove it's same time first
		if ktMessageSettings[eMessageType].bRemoveSameTypeInQueue == true then
			for i=self.tDisplayQueue[eField].iLast,self.tDisplayQueue[eField].iFirst,-1 do -- doing the list backward so that deleting won't screw up indices
				if self.tDisplayQueue[eField]:GetItems()[i].eMessageType == eMessageType then
			        self.tDisplayQueue[eField]:RemoveAbsolute(i)
			    end
			end
		end
		
     	local nInsert = 0
        for key, tValue in pairs(self.tDisplayQueue[eField]:GetItems()) do
            if ktMessageSettings[tValue.eMessageType].nPriority > nPriority then
                nInsert = key
                break
            end
        end
		
		if eField == LuaEnumMessageField.Middle and self.tDisplayQueue[eField]:Empty() then -- first tMessage in the queue
			self.tFirstMessageStall[eField] = kfFirstMessageStallDuration -- update delay so things can amass; done before to beat the onframe
		end

		if nInsert > 0 then
	        nInsert = self.tDisplayQueue[eField]:InsertAbsolute(nInsert, tParams)
		else
			nInsert = self.tDisplayQueue[eField]:Push(tParams)
		end

    else
        -- if there is no items on screen
		
        if not self.tMessagesOnScreen[eField] then
            self:ShowMessage(eMessageType, tParams)
            return
        end
        -- if tMessage is preempt, then display it
        if ktMessageSettings[eMessageType].bPreempt then
            -- check if the current display tMessage is bPreemptable or bDestroyable
            local eCurrMessageType = self.tMessagesOnScreen[eField].tParams.eMessageType        
            if ktMessageSettings[eCurrMessageType].bPreemptable or ktMessageSettings[eCurrMessageType].bDestroyable then
				-- if so, then show the tMessage, 
				self:ShowMessage(eMessageType, tParams)
            else
				-- else add the tMessage to front of queue (behind all the other preempt messages in the queue)
				local nInsert = 0
				for key, tValue in pairs(self.tDisplayQueue[eField]:GetItems()) do
					if not ktMessageSettings[tValue.eMessageType].bPreempt then
						nInsert = key
						break
					end
				end
				if nInsert > 0 then
					self.tDisplayQueue[eField]:InsertAbsolute( nInsert, tParams )
				else
					self.tDisplayQueue[eField]:Push( tParams )
				end
            end
        end
    end
        
end

---------------------------------------------------------------------------------------------------
function MessageManager:ShowMessage(eMessageType, tParams)
    local eField = ktMessageSettings[eMessageType].eField
    -- hide the tMessage that is currently being displayed
    self:HideMessage(eField, true)

    -- display the tMessage according to the tMessage type
    local oMessage = nil
    local eDisplayType = tParams.eDisplayType 
    local bReposition = ktMessageSettings[eMessageType].bReposition
    tParams.bReposition = bReposition

    if eDisplayType == LuaEnumMessageDisplayType.TextFloater then
		if bReposition then
			tParams.tTextOption.bReposition = true
		end
        oMessage = CombatFloater.ShowTextFloater(tParams.unitTarget, tParams.strText, tParams.tTextOption)
        if oMessage == nil then
			return -- nothing is shown
		end
    elseif eDisplayType == LuaEnumMessageDisplayType.Window then
        oMessage = tParams.wndMessage
        if bReposition then
			oMessage:Reposition()
		end
        oMessage:Show(true)
    elseif eDisplayType == LuaEnumMessageDisplayType.StoryPanel then
        oMessage = LuaEnumMessageType.StoryPanel -- using the type to identify the tMessage
        MessageManagerLib.DisplayStoryPanel(tParams)
    else 
        Print(Apollo.GetString("MessageManager_UnknownType"))
        return -- nothing is shown
    end

    -- keep track of the ref of the messsage in the tMessagesOnScreen list
    self.tMessagesOnScreen[eField] = 
	{
		eMessageType 	= eMessageType,
		oMessage 		= oMessage,
		tParams 		= tParams,
	}
    
end
---------------------------------------------------------------------------------------------------
function MessageManager:HideMessage(eField)
    
    if self.tMessagesOnScreen[eField] == nil then
        return
    end
    
    local eMessageType = self.tMessagesOnScreen[eField].eMessageType
    local oMessage = self.tMessagesOnScreen[eField].oMessage
    local eDisplayType = self.tMessagesOnScreen[eField].tParams.eDisplayType -- ktMessageSettings[eMessageType].eDisplayType
    
    -- hide the tMessage according to the tMessage display type
    if eDisplayType == LuaEnumMessageDisplayType.TextFloater then
        CombatFloater.HideTextFloater(oMessage)
    elseif eDisplayType == LuaEnumMessageDisplayType.Window then
        oMessage:Show(false)
    elseif eDisplayType == LuaEnumMessageDisplayType.StoryPanel then
        MessageManagerLib.HideStoryPanel()
    end
    
    if  ktMessageSettings[eMessageType].bPreemptable == true then
       -- add it back into the front of queue
       self.tDisplayQueue[ eField ]:Insert( 1, self.tMessagesOnScreen[ eField ].tParams )
    end
    
    -- remove the tMessage from the tMessagesOnScreen list
    self:OnMessageFinished( oMessage )

end
---------------------------------------------------------------------------------------------------
function MessageManager:HideStoryPanels()
    -- remove all the story panels in the story panel's queue
    local tDisplayQueue = self.tDisplayQueue[ktMessageSettings[LuaEnumMessageType.StoryPanel].eField]
    for idx = tDisplayQueue.iLast, tDisplayQueue.iFirst, -1 do -- counting backward from the back
        if tDisplayQueue:GetItems()[idx].eMessageType == LuaEnumMessageType.StoryPanel then
			tDisplayQueue:RemoveAbsolute(idx)
        end
    end 
end
---------------------------------------------------------------------------------------------------
function MessageManager:OnHideText() -- for testing
    self:HideMessage(LuaEnumMessageField.Upper)
    self:HideMessage(LuaEnumMessageField.Middle)
    self:HideMessage(LuaEnumMessageField.Alert)
    self:HideMessage(LuaEnumMessageField.Lower)
end
---------------------------------------------------------------------------------------------------
function MessageManager:OnMessageFinished(oMessage)

    local eField = nil
    for key, eValue in pairs(LuaEnumMessageField) do
        if self.tMessagesOnScreen[eValue] ~= nil and self.tMessagesOnScreen[eValue].oMessage == oMessage then
            -- remove the tMessage from the tMessagesOnScreen list
            self.tMessagesOnScreen[eValue] = nil
        end
    end
end
---------------------------------------------------------------------------------------------------
-- MessageManager instance
---------------------------------------------------------------------------------------------------
local MessageManagerInst = MessageManager:new()
MessageManagerInst:Init()
