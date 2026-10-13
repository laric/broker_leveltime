--[[
Broker_Leveltime: a LibDataBroker data source that tracks time played per level.

How it works:
  * /played data (WoW's TIME_PLAYED_MSG) gives the total and per-level time at one
    moment. A 1-second timer tracks the seconds elapsed since then (difftime), so the
    tooltip stays live without re-requesting /played.
  * On level-up, the time of the level-up and the playtime of the finished level are
    stored per character in LeveltimeDB (db.char.level[level]).

Saved data layout:
  LeveltimeDB.char.<char>.level[n] = {
    level    = n,  -- explicit, since a contiguous table is saved as a bare array
    time     = <unix time when level n was reached>,
    playtime = <seconds spent at level n before levelling up>,
  }
]]

local addon = LibStub("AceAddon-3.0"):NewAddon("Broker_Leveltime", "AceTimer-3.0", "AceEvent-3.0")
local ldb = LibStub("LibDataBroker-1.1")

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR
local HISTORY_LEVELS = 5 -- how many previous levels the tooltip lists

-- Runtime state, refreshed from TIME_PLAYED_MSG and the 1-second timer.
addon.totaltime = 0        -- total /played at last TIME_PLAYED_MSG
addon.playedthislevel = 0  -- /played at current level at last TIME_PLAYED_MSG
addon.basetime = 0         -- time() of last TIME_PLAYED_MSG
addon.difftime = 0         -- seconds elapsed since basetime

--- Returns the max player level. Resolved on demand because the MAX_PLAYER_LEVEL
-- global is not reliably set when this file loads (it was nil, breaking the tooltip).
local function GetMaxLevel()
	return GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
		or MAX_PLAYER_LEVEL
		or math.huge
end

--- Formats a number of seconds as "2 day(s) 3 hour(s) 4 min(s)".
-- Leading units that are zero are dropped; minutes are always shown.
-- @param seconds number of seconds (fractions are floored away)
-- @return string
local function FormatDuration(seconds)
	local days = floor(seconds / SECONDS_PER_DAY)
	local hours = floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
	local mins = floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
	if days > 0 then
		return days .. " day(s) " .. hours .. " hour(s) " .. mins .. " min(s)"
	elseif hours > 0 then
		return hours .. " hour(s) " .. mins .. " min(s)"
	end
	return mins .. " min(s)"
end

--- Adds one tooltip line describing a past level, if any data was recorded for it.
-- The line combines whichever of "achieved at" and "playtime" is known, and is
-- skipped entirely when neither is.
-- @param tooltip the tooltip to add the line to
-- @param level the level to describe
local function AddLevelHistory(tooltip, level)
	local entry = addon.db.char.level and addon.db.char.level[level]
	if not entry then return end

	local text
	if entry.time then
		text = "Level " .. level .. " was achieved " .. date("%c", entry.time)
	end
	if entry.playtime then
		text = (text or "Level " .. level) .. " playtime was " .. FormatDuration(entry.playtime)
	end
	if text then tooltip:AddLine(text) end
end

--- Returns the saved record for a level, creating it (with its explicit level field)
-- if missing.
-- @param level the level to look up
-- @return table the record
local function GetLevelEntry(level)
	local levels = addon.db.char.level
	if not levels then
		levels = {}
		addon.db.char.level = levels
	end
	local entry = levels[level]
	if not entry then
		entry = { level = level }
		levels[level] = entry
	end
	return entry
end

local dataobj = ldb:NewDataObject("Broker_Leveltime", {
	type = "data source",
	icon = "Interface\\Icons\\spell_nature_timestop",
})

--- Fills a tooltip with total time, time this level, XP/hour and recent level history.
-- Display addons (Bazooka etc.) call this with their own tooltip as `self` and handle
-- anchoring and hiding themselves, so no OnEnter/OnLeave is defined.
function dataobj:OnTooltipShow()
	local level = UnitLevel("player")
	local xp = UnitXP("player")
	local totaltime = addon.totaltime + addon.difftime
	local leveltime = addon.playedthislevel + addon.difftime

	self:AddLine("Total time played: " .. FormatDuration(totaltime))
	self:AddLine("Time played this level: " .. FormatDuration(leveltime))

	-- XP/hour is meaningless at max level or before any XP/time has accrued.
	if xp > 0 and leveltime > 0 and level < GetMaxLevel() then
		self:AddLine("XP per hour this level: " .. floor(xp / (leveltime / SECONDS_PER_HOUR)))
	end

	local current = addon.db.char.level and addon.db.char.level[level]
	if current and current.time then
		self:AddLine("Current level was achieved " .. date("%c", current.time))
	end

	-- Most recent first, down to HISTORY_LEVELS levels back (never below level 1).
	for past = level - 1, math.max(1, level - HISTORY_LEVELS), -1 do
		AddLevelHistory(self, past)
	end
end

--- Event handler: /played result. Resets the baseline the live timer counts from.
-- @param total seconds played on this character
-- @param level seconds played at the current level
function addon:TIME_PLAYED_MSG(_, total, level)
	self.totaltime = total
	self.playedthislevel = level
	self.basetime = time()
end

--- Event handler: level-up. Records when the new level was reached and how long the
-- previous level took, then requests fresh /played data.
-- @param level the new level
function addon:PLAYER_LEVEL_UP(_, level)
	GetLevelEntry(level).time = time()
	GetLevelEntry(level - 1).playtime = self.playedthislevel + self.difftime
	RequestTimePlayed()
end

--- Timer callback (every second): updates seconds elapsed since the last /played.
function addon:UpdateDiffTime()
	self.difftime = time() - self.basetime
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("LeveltimeDB")
	-- Migrate records saved before the explicit level field existed.
	for level, entry in pairs(self.db.char.level or {}) do
		entry.level = entry.level or level
	end
	self:RegisterEvent("TIME_PLAYED_MSG")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:ScheduleRepeatingTimer("UpdateDiffTime", 1)
	RequestTimePlayed() -- triggers TIME_PLAYED_MSG to seed the baseline
end
