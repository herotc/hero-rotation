local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local pairs = pairs;
local select = select;
local stringsub = string.sub;
local stringfind = string.find;
local tableinsert = table.insert;
local tableremove = table.remove;
local tonumber = tonumber;
local wipe = table.wipe;


-- Used for every Events
ER.Events = {};
ER.EventFrame = CreateFrame("Frame", "EasyRaid_EventFrame", UIParent);

-- Used for Combat Log Events
-- To be used with Combat Log Unfiltered
ER.CombatEvents = {};
-- To be used with Combat Log Unfiltered with SourceGUID == PlayerGUID filter
ER.SelfCombatEvents = {};

--- Register a handler for an event.
-- @param Event The event name.
-- @param Handler The handler function.
function ER:RegisterForEvent (Handler, ...)
	local EventsTable = {...};
	local Event;
	for i = 1, #EventsTable do
		Event = EventsTable[i];
		if not ER.Events[Event] then
			ER.Events[Event] = {Handler};
			ER.EventFrame:RegisterEvent(Event);
		else
			tableinsert(ER.Events[Event], Handler);
		end
	end
end

--- Register a handler for a combat event.
-- @param Event The combat event name.
-- @param Handler The handler function.
function ER:RegisterForCombatEvent (Handler, ...)
	local EventsTable = {...};
	local Event;
	for i = 1, #EventsTable do
		Event = EventsTable[i];
		if not ER.CombatEvents[Event] then
			ER.CombatEvents[Event] = {Handler};
		else
			tableinsert(ER.CombatEvents[Event], Handler);
		end
	end
end

--- Register a handler for a self combat event.
-- @param Event The combat event name.
-- @param Handler The handler function.
function ER:RegisterForSelfCombatEvent (Handler, ...)
	local EventsTable = {...};
	local Event;
	for i = 1, #EventsTable do
		Event = EventsTable[i];
		if not ER.SelfCombatEvents[Event] then
			ER.SelfCombatEvents[Event] = {Handler};
		else
			tableinsert(ER.SelfCombatEvents[Event], Handler);
		end
	end
end

--- Unregister a handler from an event.
-- @param Event The event name.
-- @param Handler The handler function.
function ER:UnregisterForEvent (Handler, Event)
	if ER.Events[Event] then
		for Index, Function in pairs(ER.Events[Event]) do
			if Function == Handler then
				tableremove(ER.Events[Event], Index);
				if #ER.Events[Event] == 0 then
					ER.EventFrame:UnregisterEvent(Event);
				end
				return;
			end
		end
	end
end

--- Unregister a handler from a combat event.
-- @param Event The combat event name.
-- @param Handler The handler function.
function ER:UnregisterForCombatEvent (Handler, Event)
	if ER.CombatEvents[Event] then
		for Index, Function in pairs(ER.CombatEvents[Event]) do
			if Function == Handler then
				tableremove(ER.CombatEvents[Event], Index);
				return;
			end
		end
	end
end

--- Unregister a handler from a combat event.
-- @param Event The combat event name.
-- @param Handler The handler function.
function ER:UnregisterForSelfCombatEvent (Handler, Event)
	if ER.SelfCombatEvents[Event] then
		for Index, Function in pairs(ER.SelfCombatEvents[Event]) do
			if Function == Handler then
				tableremove(ER.SelfCombatEvents[Event], Index);
				return;
			end
		end
	end
end

-- OnEvent Frame
ER.EventFrame:SetScript("OnEvent", 
	function (self, Event, ...)
		for Index, Handler in pairs(ER.Events[Event]) do
			Handler(...);
		end
	end
);

-- Combat Log Event Unfiltered
ER:RegisterForEvent(
	function (TimeStamp, Event, ...)
		if ER.CombatEvents[Event] then
			-- Unfiltered Combat Log
			for Index, Handler in pairs(ER.CombatEvents[Event]) do
				Handler(TimeStamp, Event, ...);
			end
		end
		if ER.SelfCombatEvents[Event] then
			-- Unfiltered Combat Log with SourceGUID == PlayerGUID filter
			if select(2, ...) == Player:GUID() then
				for Index, Handler in pairs(ER.SelfCombatEvents[Event]) do
					Handler(TimeStamp, Event, ...);
				end
			end
		end
	end
	, "COMBAT_LOG_EVENT_UNFILTERED"
);

--- ============== NON-COMBATLOG ==============

	-- PLAYER_REGEN_DISABLED
		ER.CombatStarted = 0;
		ER.CombatEnded = 1;
		-- Entering Combat
		ER:RegisterForEvent(
			function ()
				ER.CombatStarted = ER.GetTime();
				ER.CombatEnded = 0;
			end
			, "PLAYER_REGEN_DISABLED"
		);

	-- PLAYER_REGEN_ENABLED
		-- Leaving Combat
		ER:RegisterForEvent(
			function ()
				ER.CombatStarted = 0;
				ER.CombatEnded = ER.GetTime();
			end
			, "PLAYER_REGEN_ENABLED"
		);

	-- CHAT_MSG_ADDON
		-- DBM/BW Pull Timer
		ER:RegisterForEvent(
			function (Prefix, Message)
				if Prefix == "D4" and stringfind(Message, "PT") then
					ER.BossModTime = tonumber(stringsub(Message, 4, 5));
					ER.BossModEndTime = ER.GetTime() + ER.BossModTime;
				end
			end
			, "CHAT_MSG_ADDON"
		);

	-- OnSpecGearTalentUpdate
		-- Gear Inspector
		ER:RegisterForEvent(
			function ()
				-- Refresh Gear
				ER.GetEquipment();
				-- WoD
				ER.Tier18_2Pc, ER.Tier18_4Pc = ER.HasTier("T18");
				ER.Tier18_ClassTrinket = ER.HasClassTrinket();
				-- Legion
				Spell:ArtifactScan();
				ER.Tier19_2Pc, ER.Tier19_4Pc = ER.HasTier("T19");
			end
			, "ZONE_CHANGED_NEW_AREA"
			, "PLAYER_TALENT_UPDATE"
			, "PLAYER_EQUIPMENT_CHANGED"
		);

	-- Spell Book Scanner
		-- Checks the same event as Blizzard Spell Book, from SpellBookFrame_OnLoad in SpellBookFrame.lua
		ER:RegisterForEvent(
			function ()
				wipe(ER.PersistentCache.SpellLearned.Player);
				wipe(ER.PersistentCache.SpellLearned.Pet);
				Spell:BookScan();
			end
			, "SPELLS_CHANGED"
			, "LEARNED_SPELL_IN_TAB"
			, "SKILL_LINES_CHANGED"
			, "PLAYER_GUILD_UPDATE"
			, "PLAYER_SPECIALIZATION_CHANGED"
			, "USE_GLYPH"
			, "CANCEL_GLYPH_CAST"
			, "ACTIVATE_GLYPH"
		);

--- ============== COMBATLOG ==============

	--- Combat Log Arguments


		------- Base -------
			--     1        2        3            4           5           6               7           8         9         10           11
			-- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags


		------- Prefixes -------

			--- SWING
			-- N/A

			--- SPELL & SPELL_PERIODIC
			--    12        13         14
			-- SpellID, SpellName, SpellSchool


		------- Suffixes -------

			--- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
			-- N/A

			--- _CAST_FAILED
			--     15
			-- FailedType

			--- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
			--    15
			-- AuraType

			--- _AURA_APPLIED_DOSE
			--    15        16
			-- AuraType, Charges

			--- _INTERRUPT
			--      15            16              17
			-- ExtraSpellID, ExtraSpellName, ExtraSchool

			--- _HEAL
			--   15        16          17        18
			-- Amount, Overhealing, Absorbed, Critical

			--- _DAMAGE
			--   15       16       17       18       19        20        21        22        23
			-- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

			--- _MISSED
			--    15        16           17
			-- MissType, IsOffHand, AmountMissed


		------- Special -------

			--- UNIT_DIED, UNIT_DESTROYED
			-- N/A

	--- End Combat Log Arguments

	-- Arguments Variables
	local DestGUID, SpellID;

	-- Rogue
	if ({UnitClass("player")})[3] == 4 then
		ER.BleedTable = {
			-- Assassination
			Assassination = {
				Garrote = {},
				Rupture = {}
			},
			-- Subtlety
			Subtlety = {
				Nightblade = {},
				FinalityNightblade = false,
				FinalityNightbladeTime = 0
			}
			
		};
		local BleedGUID;
		--- Exsanguinated Handler
			local BleedDuration, BleedExpires;
			function ER.Exsanguinated (Unit, SpellName)
				BleedGUID = Unit:GUID();
				if BleedGUID then
					if SpellName == "Garrote" then
						if ER.BleedTable.Assassination.Garrote[BleedGUID] then
							return ER.BleedTable.Assassination.Garrote[BleedGUID][3];
						end
					elseif SpellName == "Rupture" then
						if ER.BleedTable.Assassination.Rupture[BleedGUID] then
							return ER.BleedTable.Assassination.Rupture[BleedGUID][3];
						end
					end
				end
				return false;
			end
			-- Exsanguinate Cast
			ER:RegisterForSelfCombatEvent(
				function (...)
					DestGUID, _, _, _, SpellID = select(8, ...);

					-- Exsanguinate
					if SpellID == 200806 then
						for Key, _ in pairs(ER.BleedTable.Assassination) do
							for Key2, _ in pairs(ER.BleedTable.Assassination[Key]) do
								if Key2 == DestGUID then
									-- Change the Exsanguinate info to true
									ER.BleedTable.Assassination[Key][Key2][3] = true;
								end
							end
						end
					end
				end
				, "SPELL_CAST_SUCCESS"
			);
			-- Bleed infos
			local function GetBleedInfos (GUID, Spell)
				-- Core API is not used since we don't want cached informations
				return select(6, UnitAura(GUID, ({GetSpellInfo(Spell)})[1], nil, "HARMFUL|PLAYER"));
			end
			-- Record the bleed state if it is successfully applied on an unit
			ER:RegisterForSelfCombatEvent(
				function (...)
					DestGUID, _, _, _, SpellID = select(8, ...);

					--- Record the Bleed Target and its Infos
					-- Garrote
					if SpellID == 703 then
						BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
						ER.BleedTable.Assassination.Garrote[DestGUID] = {BleedDuration, BleedExpires, false};
					-- Rupture
					elseif SpellID == 1943 then
						BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
						ER.BleedTable.Assassination.Rupture[DestGUID] = {BleedDuration, BleedExpires, false};
					end
				end
				, "SPELL_AURA_APPLIED"
				, "SPELL_AURA_REFRESH"
			);
			-- Bleed Remove
			ER:RegisterForSelfCombatEvent(
				function (...)
					DestGUID, _, _, _, SpellID = select(8, ...);

					-- Removes the Unit from Garrote Table
					if SpellID == 703 then
						if ER.BleedTable.Assassination.Garrote[DestGUID] then
							ER.BleedTable.Assassination.Garrote[DestGUID] = nil;
						end
					-- Removes the Unit from Rupture Table
					elseif SpellID == 1943 then
						if ER.BleedTable.Assassination.Rupture[DestGUID] then
							ER.BleedTable.Assassination.Rupture[DestGUID] = nil;
						end
					end
				end
				, "SPELL_AURA_REMOVED"
			);
			ER:RegisterForCombatEvent(
				function (...)
					DestGUID = select(8, ...);

					-- Removes the Unit from Garrote Table
					if ER.BleedTable.Assassination.Garrote[DestGUID] then
						ER.BleedTable.Assassination.Garrote[DestGUID] = nil;
					end
					-- Removes the Unit from Rupture Table
					if ER.BleedTable.Assassination.Rupture[DestGUID] then
						ER.BleedTable.Assassination.Rupture[DestGUID] = nil;
					end
				end
				, "UNIT_DIED"
				, "UNIT_DESTROYED"
			);
		--- Finality Nightblade Handler
			function ER.Finality (Unit)
				BleedGUID = Unit:GUID();
				if BleedGUID then
					if ER.BleedTable.Subtlety.Nightblade[BleedGUID] then
						return ER.BleedTable.Subtlety.Nightblade[BleedGUID];
					end
				end
				return false;
			end
			-- Check the Finality buff on cast (because it disappears after) but don't record it until application (because it can miss)
			ER:RegisterForSelfCombatEvent(
				function (...)
					SpellID = select(12, ...);

					-- Exsanguinate
					if SpellID == 195452 then
						ER.BleedTable.Subtlety.FinalityNightblade = Player:Buff(Spell.Rogue.Subtlety.FinalityNightblade) and true or false; -- To replace by Spell.Rogue.Subtlety.FinalityNightblade
						ER.BleedTable.Subtlety.FinalityNightbladeTime = ER.GetTime() + 0.3;
					end
				end
				, "SPELL_CAST_SUCCESS"
			);
			-- Record the bleed state if it is successfully applied on an unit
			ER:RegisterForSelfCombatEvent(
				function (...)
					DestGUID, _, _, _, SpellID = select(8, ...);

					if SpellID == 195452 then
						ER.BleedTable.Subtlety.Nightblade[DestGUID] = ER.GetTime() < ER.BleedTable.Subtlety.FinalityNightbladeTime and ER.BleedTable.Subtlety.FinalityNightblade;
					end
				end
				, "SPELL_AURA_APPLIED"
				, "SPELL_AURA_REFRESH"
			);
			-- Remove the bleed when it expires or the unit dies
			ER:RegisterForSelfCombatEvent(
				function (...)
					DestGUID, _, _, _, SpellID = select(8, ...);

					if SpellID == 195452 then
						if ER.BleedTable.Subtlety.Nightblade[DestGUID] then
							ER.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
						end
					end
				end
				, "SPELL_AURA_REMOVED"
			);
			ER:RegisterForCombatEvent(
				function (...)
					DestGUID = select(8, ...);

					if ER.BleedTable.Subtlety.Nightblade[DestGUID] then
						ER.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
					end
				end
				, "UNIT_DIED"
				, "UNIT_DESTROYED"
			);
		--- Just Stealthed
			-- TODO: Add Assassination Spells when it'll be done
			ER:RegisterForSelfCombatEvent(
				function (...)
					SpellID = select(12, ...);

					-- Shadow Dance
					if SpellID == 185313 then
						Spell.Rogue.Subtlety.ShadowDance.LastCastTime = ER.GetTime();
					-- Shadowmeld
					elseif SpellID == 58984 then
						Spell.Rogue.Outlaw.Shadowmeld.LastCastTime = ER.GetTime();
						Spell.Rogue.Subtlety.Shadowmeld.LastCastTime = ER.GetTime();
					-- Vanish
					elseif SpellID == 1856 then
						Spell.Rogue.Outlaw.Vanish.LastCastTime = ER.GetTime();
						Spell.Rogue.Subtlety.Vanish.LastCastTime = ER.GetTime();
					end
				end
				, "SPELL_CAST_SUCCESS"
			);
	end
