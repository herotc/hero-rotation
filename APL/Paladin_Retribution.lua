-- Pull Addon Vars
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

--- APL Local Vars
-- Spells
	if not Spell.Paladin then Spell.Paladin = {}; end
	Spell.Paladin.Subtlety = {
		-- Racials
		ArcaneTorrent = Spell(25046),
		GiftoftheNaaru = Spell(59547)
		-- Abilities
		-- Offensive
		-- Defensive
		-- Utility
		-- Legendaries
	};
	local S = Spell.Paladin.Retribution;
-- Items
	if not Item.Paladin then Item.Paladin = {}; end
	Item.Paladin.Retribution = {
		-- Legendaries
	};
	local I = Item.Paladin.Outlaw;
-- Rotation Var
	local EnemiesCount = {
		[5] = 0
	};
-- GUI Settings
	local Settings = {
		General = ER.GUISettings.General,
	};

-- APL Action Lists (and Variables)
local function MythicDungeon ()
	-- Sapped Soul
	if ER.MythicDungeon() == "Sapped Soul" then

	end
	return false;
end
local function TrainingScenario ()
	if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then

	end
	return false;
end

-- APL Main
local function APL ()
	--- Out of Combat
		if not Player:AffectingCombat() then
			-- Flask
			-- Food
			-- Rune
			-- PrePot w/ DBM Count
			-- Opener (Evi)
			if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
				
			end
			return;
		end
	-- In Combat
		-- Unit Update
		ER.GetEnemies(5); -- Melee
		if ER.AoEON() then
			for Key, Value in pairs(EnemiesCount) do
				EnemiesCount[Key] = #ER.Cache.Enemies[Key];
			end
		else
			for Key, Value in pairs(EnemiesCount) do
				EnemiesCount[Key] = 1;
			end
		end
		if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
			--[[ Disabled since not coded for Retribution yet
			-- Mythic Dungeon
			if MythicDungeon() then
				return;
			end
			-- Training Scenario
			if TrainingScenario() then
				return;
			end
			]]
		end
end

ER.SetAPL(70, APL);
