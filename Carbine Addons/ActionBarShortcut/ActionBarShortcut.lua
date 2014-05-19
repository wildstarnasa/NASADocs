-----------------------------------------------------------------------------------------------
-- Client Lua Script for ActionBarShortcut
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Unit"
require "ActionSetLib"
require "AttributeMilestonesLib"

local ActionBarShortcut = {}
local knMaxBars = ActionSetLib.ShortcutSet.Count

function ActionBarShortcut:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function ActionBarShortcut:Init()
	Apollo.RegisterAddon(self)
end

function ActionBarShortcut:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ActionBarShortcut.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ActionBarShortcut:OnDocumentReady()
	Apollo.RegisterEventHandler("ShowActionBarShortcut", "ShowWindow", self)

	self.tActionBars = {}
	local tShortcutCount = {}
	local knStartingBar = 4 -- Skip 1 to 3, as that is the Engineer Bar and Engineer Pet Bars, which is handled in EngineerResource

	for idx = knStartingBar, knMaxBars do
		local wndCurrBar = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcut", nil, self)
		wndCurrBar:FindChild("ActionBarContainer"):DestroyChildren() -- TODO can remove
		wndCurrBar:Show(false)

		for iBar = 0, 7 do
			local wndBarItem = Apollo.LoadForm(self.xmlDoc, "ActionBarShortcutItem", wndCurrBar:FindChild("ActionBarContainer"), self)
			wndBarItem:FindChild("ActionBarShortcutBtn"):SetContentId(idx * 12 + iBar)
			if wndBarItem:FindChild("ActionBarShortcutBtn"):GetContent()["strIcon"] ~= "" then
				tShortcutCount[idx] = iBar + 1
			end
			wndCurrBar:FindChild("ActionBarContainer"):ArrangeChildrenHorz(0)
		end

		self.tActionBars[idx] = wndCurrBar
	end

	for idx = knStartingBar, knMaxBars do
		self:ShowWindow(idx, IsActionBarSetVisible(idx), tShortcutCount[idx])
	end
end

function ActionBarShortcut:GetBarPosition(nBar)
	if not self.tActionBars[nBar] then
		return {}
	end

	local tAnchors = {}
	tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom = self.tActionBars[nBar]:GetAnchorOffsets()

	local tSize = {}
	tSize.nWidth = self.tActionBars[nBar]:GetWidth()
	tSize.nHeight = self.tActionBars[nBar]:GetHeight()

	local tCenter = {}
	tCenter.nX = (tAnchors.nLeft + tAnchors.nRight) / 2
	tCenter.nY = (tAnchors.nTop + tAnchors.nBottom) / 2

	return { tSize = tSize, tCenter = tCenter }
end

function ActionBarShortcut:SetBarPosition(nBar, tArgSize, tArgCenter)

	if  tArgSize == nil then
		tArgSize = {}
	end
	if  tArgCenter == nil then
		tArgCenter = {}
	end

	local tPosition = self:GetBarPosition(nBar)

	local tHalf = {}
	tHalf.nWidth = (tArgSize.nWidth or tPosition.tSize.nWidth) / 2
	tHalf.nHeight = (tArgSize.nHeight or tPosition.tSize.nHeight) / 2

	local tCenter = {}
	tCenter.nX = tArgCenter.nX or tPosition.tCenter.nX
	tCenter.nY = tArgCenter.nY or tPosition.tCenter.nY

	nScreenWidth, nScreenHeight = Apollo.GetScreenSize()
	if tCenter.nX + tHalf.nWidth > nScreenWidth / 2 or tCenter.nX - tHalf.nWidth < nScreenWidth / -2 then
		tCenter.nX = 0
	end

	tAnchors = { 	nLeft   = tCenter.nX - tHalf.nWidth,
					nTop    = tCenter.nY - tHalf.nHeight,
					nRight  = tCenter.nX + tHalf.nWidth,
					nBottom = tCenter.nY + tHalf.nHeight }
	self.tActionBars[nBar]:SetAnchorOffsets( tAnchors.nLeft, tAnchors.nTop, tAnchors.nRight, tAnchors.nBottom )
end

function ActionBarShortcut:ShowWindow(nBar, bIsVisible, nShortcuts)
    if self.tActionBars[nBar] == nil then
		return
	end

	if nShortcuts and bIsVisible then
		-- set the position of this action bar ignoring overlapping
		self:SetBarPosition( nBar, { nWidth = (nShortcuts * 37) + 4 } )

		local tPosition = self:GetBarPosition(nBar)

		-- collect all overlapping bars
		local arRow = { nBar }
		local nRowWidth = tPosition.tSize.nWidth
		local nRowX = tPosition.tCenter.nX
		for nOtherBar,tActionBar in pairs(self.tActionBars) do
			if nOtherBar ~= nBar and tActionBar:IsShown() then
				local tOtherPosition = self:GetBarPosition(nOtherBar)

				if tOtherPosition and tOtherPosition.tCenter and tOtherPosition.tCenter.nY == tPosition.tCenter.nY then
					nRowWidth = nRowWidth + tOtherPosition.tSize.nWidth
					nRowX = (nRowX * #arRow + tOtherPosition.tCenter.nX) / (#arRow + 1)
					arRow[#arRow + 1] = nOtherBar
				end
			end
		end

		-- if there were any overlapping then rearrange all of them
		if #arRow > 1 then
			local kOverlap = 4

			local nLeft = nRowX - nRowWidth / 2
			local nScreenWidth
			local nScreenHeight
			nScreenWidth, nScreenHeight = Apollo.GetScreenSize()

			if nLeft + nRowWidth > nScreenWidth / 2 then
				nLeft = nRowWidth / -2
			end
			nLeft = nLeft + kOverlap * #arRow

			for nIdx, nTmpBar in pairs(arRow) do
				local tTmpPosition = self:GetBarPosition(nTmpBar)
				self:SetBarPosition(nTmpBar, nil, { nX = nLeft + tTmpPosition.tSize.nWidth / 2 } )
				nLeft = nLeft + tTmpPosition.tSize.nWidth - kOverlap
			end
		end
	end

	self.tActionBars[nBar]:Show(bIsVisible, not bIsVisible)
end

function ActionBarShortcut:OnGenerateTooltip(wndControl, wndHandler, eType, oArg1, oArg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemInstance then
		local itemEquipped = oArg1:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		--Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = oArg1}) -- OLD
	elseif eType == Tooltip.TooltipGenerateType_ItemData then
		local itemEquipped = oArg1:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, oArg1, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
		--Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = oArg1}) - OLD
	elseif eType == Tooltip.TooltipGenerateType_GameCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(oArg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, oArg1)
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	end
end

-----------------------------------------------------------
local ActionBarShortcut_Singleton = ActionBarShortcut:new()
ActionBarShortcut_Singleton:Init()
