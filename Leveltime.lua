local addon = LibStub("AceAddon-3.0"):NewAddon("Broker_Leveltime","AceTimer-3.0","AceEvent-3.0")
addon.totaltime = 0
addon.playedthislevel = 0
addon.basetime = 0
addon.difftime = 0
local f = CreateFrame("frame")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject("Broker_Leveltime", {
    type = "data source",
    icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
	text = "Broker_Leveltime",
})

function dataobj:OnTooltipShow()
	local tottime = addon.totaltime + addon.difftime
	local lvltime = addon.playedthislevel + addon.difftime
	local totdays = floor( tottime / (60*60*24))
	local tothours = floor( (tottime-(totdays*60*60*24)) / (60*60))
	local totmins = floor( (tottime-(totdays*60*60*24)-(tothours*60*60)) / 60 )
	if totdays > 0  then
	  self:AddLine("Total time played: " .. totdays .. " day(s) " .. tothours .. " hour(s) " .. totmins .. " min(s)")
	elseif tothours > 0 then 
	  self:AddLine("Total time played: " .. tothours .. " hour(s) " .. totmins .. " min(s)")
	else
	  self:AddLine("Total time played: " .. totmins .. " min(s)")
    end	
	local lvldays = floor( lvltime / (60*60*24))
	local lvlhours = floor( (lvltime-(lvldays*60*60*24)) / (60*60))
	local lvlmins = floor( (lvltime-(lvldays*60*60*24)-(lvlhours*60*60)) / 60 )
	if lvldays > 0  then
	  self:AddLine("Time played this level: " .. lvldays .. " day(s) " .. lvlhours .. " hour(s) " .. lvlmins .. " min(s)")
	elseif lvlhours > 0 then 
	  self:AddLine("Time played this level: " .. lvlhours .. " hour(s) " .. lvlmins .. " min(s)")
	else
	  self:AddLine("Time played this level: " .. lvlmins .. " min(s)")
    end
	if addon.db.char.level then
		if addon.db.char.level[UnitLevel("player")] then
			if addon.db.char.level[UnitLevel("player")].time then 
			  self:AddLine("Current level was achieved ".. date("%c",addon.db.char.level[UnitLevel("player")].time))
			end
		end
		local printlevel=UnitLevel("player") - 1
		if printlevel < 0 then printlevel = 1 end
		local printtolevel = UnitLevel("player") - 5
		if printtolevel < 0 then printtolevel = 1 end
		while printlevel >= printtolevel do
		  if addon.db.char.level[printlevel] then
		    local tempstr = ""
			if addon.db.char.level[printlevel].time then
			  tempstr = "Level "..printlevel.." was achieved ".. date("%c",addon.db.char.level[printlevel].time)
			end
			if addon.db.char.level[printlevel].playtime then
			  local tmptime = addon.db.char.level[printlevel].playtime
			  local ptdays = floor(tmptime / (60*60*24))
			  local pthours = floor((tmptime - (ptdays * 60*60*24)) / (60*60))
			  local ptmins = floor((tmptime - (ptdays * 60*60*24) - (pthours *60*60)) / 60)
			  local ptstr = ""
			  if ptdays>0 then ptstr = ptdays.." day(s) " end
			  if pthours>0 then ptstr = ptstr..pthours.." hour(s) " end
			  ptstr = ptstr..ptmins.." min(s)" 
			  if tempstr == "" then tempstr = "Level "..printlevel end
			  tempstr= tempstr.." playtime was "..ptstr
			end
			if tempstr ~= "" then self:AddLine(tempstr) end
		  end
		  
		  printlevel = printlevel-1
		end
	end
	
	
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

function addon:TIME_PLAYED_MSG(eventName, total, level)
  self.totaltime = total
  self.playedthislevel = level
  self.basetime = time()
end

function addon:PLAYER_LEVEL_UP(eventName,level, hp, mp, talentPoints, strength, agility, stamina, intellect, spirit)
  if not self.db.char.level then self.db.char.level={} end
  if not self.db.char.level[level] then self.db.char.level[level]={} end
  if not self.db.char.level[level-1] then self.db.char.level[level-1]={} end
  self.db.char.level[level].time = time()
  self.db.char.level[level-1].playtime = self.playedthislevel + self.difftime
  RequestTimePlayed()
end

function addon:MinTimer()
  self.difftime = time() - self.basetime
end

function addon:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("LeveltimeDB")
  self:RegisterEvent("TIME_PLAYED_MSG")
  self:RegisterEvent("PLAYER_LEVEL_UP")
  self.minuteTimer = self:ScheduleRepeatingTimer("MinTimer", 1)
  RequestTimePlayed()
end