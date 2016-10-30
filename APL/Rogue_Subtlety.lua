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
	if not Spell.Rogue then Spell.Rogue = {}; end
	Spell.Rogue.Subtlety = {
		-- Racials
		ArcaneTorrent = Spell(25046),
		Berserking = Spell(26297),
		BloodFury = Spell(20572),
		GiftoftheNaaru = Spell(59547),
		Shadowmeld = Spell(58984),
		-- Abilities
		Alacrity = Spell(193539),
		AlacrityBuff = Spell(193538),
		Anticipation = Spell(114015),
		Backstab = Spell(53),
		DeathFromAbove = Spell(152150),
		DeeperStrategem = Spell(193531),
		EnvelopingShadows = Spell(206237),
		Eviscerate = Spell(196819),
		Gloomblade = Spell(200758),
		KidneyShot = Spell(408),
		MasterofShadows = Spell(196976),
		MasterOfSubtlety = Spell(31223),
		MasterOfSubtletyBuff = Spell(31665),
		Nightblade = Spell(195452),
		FinalityNightblade = Spell(195452),
		Premeditation = Spell(196979),
		ShadowFocus = Spell(108209),
		Shadowstrike = Spell(185438),
		ShurikenStorm = Spell(197835),
		ShurikenToss = Spell(114014),
		Stealth = Spell(1784),
		Subterfuge = Spell(108208),
		SymbolsofDeath = Spell(212283),
		Vigor = Spell(14983),
		-- Offensive
		GoremawsBite = Spell(209782),
		MarkedforDeath = Spell(137619),
		ShadowBlades = Spell(121471),
		ShadowDance = Spell(185313),
		Vanish = Spell(1856),
		-- Defensive
		CrimsonVial = Spell(185311),
		Feint = Spell(1966),
		-- Utility
		Kick = Spell(1766),
		Sprint = Spell(2983),
		-- Legendaries
		DreadlordsDeceit = Spell(228224)
	};
	local S = Spell.Rogue.Subtlety;
-- Items
	if not Item.Rogue then Item.Rogue = {}; end
	Item.Rogue.Outlaw = {
		-- Legendaries
		ShadowSatyrsWalk = Item(137032) -- 8
	};
	local I = Item.Rogue.Outlaw;
-- Rotation Var
	local EnemiesCount = {
		[10] = 0,
		[8] = 0,
		[5] = 0
	};
-- GUI Settings
	local Settings = {
		General = ER.GUISettings.General,
		Subtlety = ER.GUISettings.APL.Rogue.Subtlety
	};

-- APL Action Lists (and Variables)
-- actions=variable,name=ssw_er,value=equipped.shadow_satyrs_walk*(10-floor(target.distance*0.5))
local function SSW_ER ()
	return (I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0)*8; -- 10-2 as we will always be at least at +4yds.
end
-- actions+=/variable,name=ed_threshold,value=energy.deficit<=(20+talent.vigor.enabled*35+talent.master_of_shadows.enabled*25+variable.ssw_er)
local function ED_Threshold ()
	return (Player:EnergyDeficit() <= (20 + (S.Vigor:IsAvailable() and 1 or 0)*35 + (S.MasterofShadows:IsAvailable() and 1 or 0)*25 + SSW_ER())) and true or false;
end
-- # Builders
local function Build ()
	-- actions.build=shuriken_storm,if=spell_targets.shuriken_storm>=2
	if EnemiesCount[10] >= 2 and S.ShurikenStorm:IsCastable() then
		ER.CastGCD(S.ShurikenStorm);
		return "Cast";
	end
	if Target:IsInRange(5) then
		-- actions.build+=/gloomblade
		if S.Gloomblade:IsCastable() then
			ER.CastGCD(S.Gloomblade);
			return "Cast";
		-- actions.build+=/backstab
		elseif S.Backstab:IsCastable() then
			ER.CastGCD(S.Backstab);
			return "Cast";
		end
	end
	return false;
end
-- # Cooldowns
local function CDs ()
	if Target:IsInRange(5) then
		-- Racials
		if Player:IsStealthed(true, false) then
			-- actions.cds+=/blood_fury,if=stealthed
			if S.BloodFury:IsCastable() then
				ER.CastOffGCD(S.BloodFury);
			end
			-- actions.cds+=/berserking,if=stealthed
			if S.Berserking:IsCastable() then
				ER.CastOffGCD(S.Berserking);
			end
			-- actions.cds+=/arcane_torrent,if=stealthed&energy.deficit>70
			if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 70 then
				ER.CastOffGCD(S.ArcaneTorrent);
			end
		end
		-- actions.cds+=/shadow_blades,if=!(stealthed|buff.shadowmeld.up)
		if S.ShadowBlades:IsCastable() and not Player:IsStealthed(true, true) and not Player:Buff(S.ShadowBlades) then
			ER.CastOffGCD(S.ShadowBlades);
		end
		-- actions.cds+=/goremaws_bite,if=!buff.shadow_dance.up&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|target.time_to_die<8)
		if S.GoremawsBite:IsCastable() and not Player:Buff(S.ShadowDance) and ((Player:ComboPointsDeficit() >= 4-(ER.CombatTime() < 10 and 1 or 0)*2 and Player:EnergyDeficit() > 50 + (S.Vigor:IsAvailable() and 1 or 0)*25 - (ER.CombatTime() >= 10 and 1 or 0)*15) or Target:TimeToDie(10) < 8) then
			ER.CastGCD(S.GoremawsBite);
			return "Cast A";
		end
		-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15)&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)
		--[[Normal MfD
		if not S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= 4+(S.DeeperStrategem:IsAvailable() and 1 or 0)+(S.Anticipation:IsAvailable() and 1 or 0) then
			ER.CastOffGCD(S.MarkedforDeath);
		end]]
	end
	return false;
end
-- # Finishers
local function Finish ()
	-- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
	if S.EnvelopingShadows:IsCastable() and Player:BuffRemains(S.EnvelopingShadows) < Target:TimeToDie() and Player:BuffRemains(S.EnvelopingShadows) < Player:ComboPoints()*1.8 then
		ER.CastGCD(S.EnvelopingShadows);
		return "Cast";
	end
	-- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=6
	if EnemiesCount[8] >= 6 and Target:IsInRange(15) and S.DeathFromAbove:IsCastable() then
		ER.CastGCD(S.DeathFromAbove);
		return "Cast";
	end
	-- actions.finish+=/nightblade,target_if=max:target.time_to_die,if=target.time_to_die>8&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time)
	if S.Nightblade:IsCastable() then
		if Target:IsInRange(5) and Target:TimeToDie() > 8 and ((Target:DebuffRefreshable(S.Nightblade, (6+Player:ComboPoints()*2)*0.3) and (not ER.Finality(Target) or Player:Buff(S.FinalityNightblade))) or Target:DebuffRemains(S.Nightblade) < 2) then
			ER.CastGCD(S.Nightblade);
			return "Cast";
		end
		if ER.AoEON() then
			local BestUnit, BestUnitTTD = nil, 8;
			for Key, Value in pairs(ER.Cache.Enemies[5]) do
				if Value:TimeToDie() > BestUnitTTD and ((Value:DebuffRefreshable(S.Nightblade, (6+Player:ComboPoints()*2)*0.3) and (not ER.Finality(Target) or Player:Buff(S.FinalityNightblade))) or Value:DebuffRemains(S.Nightblade) < 2) then
					BestUnit, BestUnitTTD = Value, Value:TimeToDie();
				end
			end
			if BestUnit then
				ER.Nameplate.AddIcon(BestUnit, S.Nightblade);
			end
		end
	end
	-- actions.finish+=/death_from_above
	if Target:IsInRange(15) and S.DeathFromAbove:IsCastable() then
		ER.CastGCD(S.DeathFromAbove);
		return "Cast";
	end
	-- actions.finish+=/eviscerate
	if Target:IsInRange(5) and S.Eviscerate:IsCastable() then
		ER.CastGCD(S.Eviscerate);
		return "Cast";
	end
	return false;
end
-- # Stealth Cooldowns
local function Stealth_CDs ()
	if Target:IsInRange(5) then
		-- actions.stealth_cds=shadow_dance,if=charges_fractional>=2.65
		if (ER.CDsON() or (S.ShadowDance:Charges() >= Settings.Subtlety.ShD.EcoCharge and S.ShadowDance:Recharge() <= Settings.Subtlety.ShD.EcoCD)) and S.ShadowDance:IsCastable() and S.ShadowDance:ChargesFractional() >= 2.65 then
			ER.CastGCD(S.ShadowDance);
			return "Cast";
		end
		-- actions.stealth_cds+=/vanish
		if ER.CDsON() and S.Vanish:IsCastable() and not Player:IsTanking(Target) then
			ER.CastGCD(S.Vanish);
			return "Cast";
		end
		-- actions.stealth_cds+=/shadow_dance,if=charges>=2&combo_points<=1
		if (ER.CDsON() or (S.ShadowDance:Charges() >= Settings.Subtlety.ShD.EcoCharge and S.ShadowDance:Recharge() <= Settings.Subtlety.ShD.EcoCD)) and S.ShadowDance:IsCastable() and S.ShadowDance:Charges() >= 2 and Player:ComboPoints() <= 1 then
			ER.CastGCD(S.ShadowDance);
			return "Cast";
		end
		-- actions.stealth_cds+=/shadowmeld,if=energy>=40-variable.ssw_er&energy.deficit>10
		if ER.CDsON() and S.Shadowmeld:IsCastable() and not Player:IsTanking(Target) and GetUnitSpeed("player") == 0 and Player:EnergyDeficit() > 10 then
			-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40-variable.ssw_er
			if Player:Energy() < 40-SSW_ER() then
				return "Pool";
			end
			ER.CastGCD(S.Shadowmeld);
			return "Cast";
		end
		-- actions.stealth_cds+=/shadow_dance,if=combo_points<=1
		if (ER.CDsON() or (S.ShadowDance:Charges() >= Settings.Subtlety.ShD.EcoCharge and S.ShadowDance:Recharge() <= Settings.Subtlety.ShD.EcoCD)) and S.ShadowDance:IsCastable() and Player:ComboPoints() <= 1 and S.ShadowDance:Charges() >= 1 then
			ER.CastGCD(S.ShadowDance);
			return "Cast";
		end
	end
	return false;
end
-- # Stealthed Rotation
local function Stealthed ()
	-- actions.stealthed=symbols_of_death,if=buff.shadowmeld.down&((buff.symbols_of_death.remains<target.time_to_die-4&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3)|(equipped..shadow_satyrs_walk&energy.time_to_max<0.25))
	if S.SymbolsofDeath:IsCastable() and not Player:Buff(S.Shadowmeld) and ((Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5)) or (I.ShadowSatyrsWalk:IsEquipped(8) and Player:EnergyTimeToMax() < 0.25)) then
		ER.CastOffGCD(S.SymbolsofDeath);
	end
	-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5
	if Player:ComboPoints() >= 5 then
		if Finish() then
			return "Cast";
		end
	end
	-- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|buff.the_dreadlords_deceit.stack>=29)
	if ER.AoEON() and S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld) and ((Player:ComboPointsDeficit() >= 3 and EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0)) or (Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
		ER.CastGCD(S.ShurikenStorm);
		return "Cast";
	end
	-- actions.stealthed+=/shadowstrike
	if Target:IsInRange(5) and S.Shadowstrike:IsCastable() then
		ER.CastGCD(S.Shadowstrike);
		return "Cast";
	end
	return false;
end
local SappedSoulSpells = {
	{S.Feint, "Cast Feint Sappel Soul", function () return true; end},
	{S.CrimsonVial, "Cast Crimson Vial Sappel Soul", function () return true; end},
	{S.Kick, "Cast Kick Sappel Soul", function () return Target:IsInRange(5); end}
};
local function MythicDungeon ()
	-- Sapped Soul
	if ER.MythicDungeon() == "Sapped Soul" then
		for i = 1, #SappedSoulSpells do
			if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
				ER.CastGCD(SappedSoulSpells[i][1]);
				ER.ChangePulseTimer(1);
				return SappedSoulSpells[i][2];
			end
		end
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
	-- Spell ID Changes check
	S.Stealth = S.Subterfuge:IsAvailable() and Spell(115191) or Spell(1784); -- w/ or w/o Subterfuge Talent
	--- Out of Combat
		if not Player:AffectingCombat() then
			if not InCombatLockdown() and not S.Stealth:IsOnCooldown() and not Player:IsStealthed() and GetNumLootItems() == 0 and not UnitExists("npc") and ER.OutOfCombatTime() > 1 then
				ER.CastOffGCD(S.Stealth);
			end
			-- Crimson Vial
			if S.CrimsonVial:IsCastable() and Player:HealthPercentage() <= 80 then
				ER.CastOffGCD(S.CrimsonVial);
			end
			-- Flask
			-- Food
			-- Rune
			-- PrePot w/ DBM Count
			-- Symbols of Death
			if S.SymbolsofDeath:IsCastable() and Player:IsStealthed(true, true) and (ER.BMPullTime() == 60 or (ER.BMPullTime() <= 15 and ER.BMPullTime() >= 14) or (ER.BMPullTime() <= 4 and ER.BMPullTime() >= 3)) then
				ER.CastGCD(S.SymbolsofDeath);
			end
			-- Opener (Evi)
			if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
				if Player:ComboPoints() >= 5 then
					if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade) then
						ER.CastGCD(S.Nightblade);
						return "Cast Nightblade";
					elseif S.Eviscerate:IsCastable() then
						ER.CastGCD(S.Eviscerate);
						return "Cast Eviscerate";
					end
				elseif Player:IsStealthed(true, true) and S.Shadowstrike:IsCastable() then
					ER.CastGCD(S.Shadowstrike);
					return "Cast Shadowstrike";
				elseif S.Backstab:IsCastable() then
					ER.CastGCD(S.Backstab);
					return "Cast Backstab";
				end
			end
			return;
		end
	-- In Combat
		-- Unit Update
		if S.MarkedforDeath:IsAvailable() then ER.GetEnemies(30); end
		ER.GetEnemies(10); -- Shuriken Storm
		ER.GetEnemies(8); -- Death From Above
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
		-- MfD Sniping
		if S.MarkedforDeath:IsCastable() then
			local BestUnit, BestUnitTTD = nil, 60;
			for Key, Value in pairs(ER.Cache.Enemies[30]) do
				if not Value:IsMfdBlacklisted() and Value:TimeToDie() < Player:ComboPointsDeficit()*1.5 and Value:TimeToDie() < BestUnitTTD then -- I increased the SimC condition since we are slower.
					BestUnit, BestUnitTTD = Value, Value:TimeToDie();
				end
			end
			if BestUnit then
				ER.Nameplate.AddIcon(BestUnit, S.MarkedforDeath);
			end
		end
		-- Crimson Vial
		if S.CrimsonVial:IsCastable() and Player:HealthPercentage() <= 35 then
			ER.CastOffGCD(S.CrimsonVial);
		end
		-- Feint
		if S.Feint:IsCastable() and not Player:Buff(S.Feint) and Player:HealthPercentage() <= 10 then
			ER.CastGCD(S.Feint);
			return "Cast Feint";
		end
		if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
			-- Mythic Dungeon
			if MythicDungeon() then
				return;
			end
			--[[ Disabled since not coded for Subtlety yet
			-- Training Scenario
			if TrainingScenario() then
				return;
			end
			]]
			-- Kick
			if Settings.General.InterruptEnabled and not S.Kick:IsOnCooldown() and Target:IsInRange(5) and Target:IsInterruptible() then
				ER.CastOffGCD(S.Kick);
			end
			-- actions+=/call_action_list,name=cds
			if ER.CDsON() and CDs() then
				return;
			end
			-- actions+=/run_action_list,name=stealthed,if=stealthed|buff.shadowmeld.up
			if Player:IsStealthed(true, true) then
				Stealthed();
				return; -- run_action_list forces the return
			end
			-- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
			if Player:ComboPoints() >= 5 or (Player:ComboPoints() >= 4 and EnemiesCount[10] >= 3 and EnemiesCount[10] <= 4) then
				if Finish() then
					return;
				end
			end
			-- actions+=/call_action_list,name=stealth_cds,if=combo_points.deficit>=2+talent.premeditation.enabled&(variable.ed_threshold|(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)|target.time_to_die<12)
			if Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0) and (ED_Threshold() or (not S.Shadowmeld:IsOnCooldown() and S.Vanish:IsOnCooldown() and S.ShadowDance:Charges() <= 1) or Target:TimeToDie() < 12) then
				if Stealth_CDs() then
					return;
				end
			end
			-- actions+=/call_action_list,name=build,if=variable.ed_threshold
			if ED_Threshold() then
				if Build() then
					return;
				end
			end
			-- Shuriken Toss Out of Range
			if not Target:IsInRange(10) and Target:IsInRange(20) and S.ShurikenToss:IsCastable() and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
				ER.CastGCD(S.ShurikenToss);
				return;
			end
		end
end

ER.SetAPL(261, APL);
