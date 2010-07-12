local addon = LibStub("AceAddon-3.0"):NewAddon("Broker_Leveltime","AceTimer-3.0","AceEvent-3.0")
local f = CreateFrame("frame")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject("Broker_Leveltime", {
    type = "data source",
    icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
	text = "Broker_Leveltime",
})

function dataobj:OnTooltipShow()
	self:AddLine("Starting point")
end

function dataobj:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
	GameTooltip:ClearLines()
	dataobj.OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end

function dataobj:OnLeave()
	GameTooltip:Hide()
end

function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("LeveltimeDB")
end