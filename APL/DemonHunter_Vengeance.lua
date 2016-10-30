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

-- APL Local Vars
-- Spell
	if not Spell.DemonHunter then Spell.DemonHunter = {}; end
	Spell.DemonHunter.Vengeance = {
		-- Abilities
		Felblade = Spell(213241),
		FelDevastation = Spell(212084),
		ImmolationAura = Spell(178740),
		Shear = Spell(203782),
		SigilofFlame = Spell(204596),
		SoulCleave = Spell(228477),
		ThrowGlaive = Spell(204157),
		-- Offensive
		SoulCarver = Spell(207407),
		-- Defensive
		DemonSpikes = Spell(203720),
		DemonSpikesBuff = Spell(203819),
		-- Utility
		ConsumeMagic = Spell(183752),
		InfernalStrike = Spell(189110)
	};
	local S = Spell.DemonHunter.Vengeance;
-- Rotation Var
	local EnemiesCount = {
		[15] = 1,
		[8] = 1
	};

-- APL Main
local function APL ()
	--- Out of Combat
	if not Player:AffectingCombat() then
		-- Flask
		-- Food
		-- Rune
		-- PrePot w/ DBM Count
		-- Opener (Shear)
		if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) and S.Shear:IsCastable() then
			ER.CastGCD(S.Shear);
			return "Cast Shear";
		end
		return;
	end
	-- In Combat
		ER.GetEnemies(15); -- Fel Devastation (I think it's 20 thp)
		ER.GetEnemies(8); -- Sigil of Flamme
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
		-- Demon Spikes
		if S.DemonSpikes:IsCastable() and Player:HealthPercentage() <= 70 and Player:Pain() >= 20 and not Player:Buff(S.DemonSpikesBuff) then
			ER.CastOffGCD(S.DemonSpikes);
		end
		if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
			-- Consume Magic
			if Settings.General.InterruptEnabled and Target:IsInRange(20) and S.ConsumeMagic:IsCastable() and Target:IsInterruptible() then
				ER.CastOffGCD(S.ConsumeMagic);
			end
			-- actions+=/soul_carver
			if ER.CDsON() and Target:IsInRange(5) and S.SoulCarver:IsCastable() then
				ER.CastGCD(S.SoulCarver);
				return "Cast Soul Carver";
			end
			-- actions+=/immolation_aura,if=pain<=80
			if Target:IsInRange(8) and S.ImmolationAura:IsCastable() and not Player:Buff(S.ImmolationAura) then
				ER.CastGCD(S.ImmolationAura);
				return "Cast Immolation Aura";
			end
			-- actions+=/felblade,if=pain<=70
			if Target:IsInRange(15) and S.Felblade:IsCastable() then
				ER.CastGCD(S.Felblade);
				return "Cast Felblade";
			end
			-- actions+=/fel_devastation
			if ER.CDsON() and ER.AoEON() and Target:IsInRange(15) and S.FelDevastation:IsCastable() and GetUnitSpeed("player") == 0 and Player:Pain() >= 30 then
				ER.CastGCD(S.FelDevastation);
				return "Cast Fel Devastation";
			end
			-- actions+=/sigil_of_flame
			if ER.AoEON() and Target:IsInRange(8) and S.SigilofFlame:IsCastable() then
				ER.CastGCD(S.SigilofFlame);
				return "Cast Sigil of Flame";
			end
			if Target:IsInRange(5) then
				-- actions+=/soul_cleave,if=pain>=80
				if S.SoulCleave:IsCastable() and Player:Pain() >= 60 then
					ER.CastGCD(S.SoulCleave);
					return "Cast Soul Cleave";
				end
				-- Infernal Strike Charges Dump
				if S.InfernalStrike:IsCastable() and S.InfernalStrike:Charges() > 1 then
					ER.CastOffGCD(S.InfernalStrike);
				end
				-- actions+=/shear
				if S.Shear:IsCastable() then
					ER.CastGCD(S.Shear);
					return "Cast Shear";
				end
			end
			if Target:IsInRange(30) and S.ThrowGlaive:IsCastable() then
				ER.CastGCD(S.ThrowGlaive);
				return "Cast Throw Glaive";
			end
		end
end

ER.SetAPL(581, APL);
