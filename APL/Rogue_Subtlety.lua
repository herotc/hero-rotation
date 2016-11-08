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
		DeeperStratagem = Spell(193531),
		EnvelopingShadows = Spell(206237),
		Eviscerate = Spell(196819--[[, 
			Eviscerate DMG Formula (Pre-Mitigation):
				AP * CP * EviscR1_APCoef * EviscR2_M * F:Evisc_M * ShadowFangs_M * LegionBlade_M * MoS_M * DS_M * SoD_M * Versa_M * Mastery_M
			function () 
				return 
					-- Attack Power
					Player:AttackPower() * 
					-- Combo Points	
					Player:ComboPoints() * 
					-- Eviscerate R1 AP Coef
					0.98130 * 
					-- Eviscerate R2 Multiplier			
					1.5 * 
					-- Finality: Eviscerate Multiplier | Used 1.2 atm (TODO: Check the % from Tooltip or do an Event Listener)
					(Player:Buff(S.FinalityEviscerate) and 1.2 or 1) * 
					-- Shadow Fangs Multiplier
					(S.ShadowFangs:Exists() and 1.4 or 1) * 
					-- Legion Blade Multiplier
					(S.LegionBlade():ArtifactRank() > 0 and 1.05+0.005*(S.LegionBlade():ArtifactRank()-1) or 1) * 
					-- Master of Subtlety Multiplier
					(Player:Buff(S.MasterOfSubtletyBuff) and 1.1 or 1) * 
					-- Deeper Stratagem Multiplier
					(S.DeeperStratagem:Exists() and 1.1 or 1) * 
					-- Symbols of Death Multiplier
					(Player:Buff(S.SymbolsofDeath) and 1.2 or 1) * 
					-- Versatility Damage Multiplier
					(1 + Player:VersatilyDmgPct()) * 
					-- Mastery Finisher Multiplier
					(1 + Player:MasteryPct());
			end]]
		),
		FinalityEviscerate = Spell(197496),
		FinalityNightblade = Spell(195452),
		Gloomblade = Spell(200758),
		KidneyShot = Spell(408),
		LegionBlade = Spell(214930),
		MasterofShadows = Spell(196976),
		MasterOfSubtlety = Spell(31223),
		MasterOfSubtletyBuff = Spell(31665),
		Nightblade = Spell(195452),
		Premeditation = Spell(196979),
		ShadowFangs = Spell(221856),
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
	local ShouldReturn, ShouldReturn2; -- Used to get the return string
	local BestUnit, BestUnitTTD; -- Used for cycling
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
	if ER.AoEON() and ER.Cache.EnemiesCount[10] >= 2 and S.ShurikenStorm:IsCastable() then
		if ER.Cast(S.ShurikenStorm) then return "Cast"; end
	end
	if Target:IsInRange(5) then
		-- actions.build+=/gloomblade
		if S.Gloomblade:IsCastable() then
			if ER.Cast(S.Gloomblade) then return "Cast"; end
		-- actions.build+=/backstab
		elseif S.Backstab:IsCastable() then
			if ER.Cast(S.Backstab) then return "Cast"; end
		end
	end
	return false;
end
-- # Cooldowns
local function CDs ()
	if Target:IsInRange(5) then
		-- Racials
		if Player:IsStealthed(true, false) then
			-- actions.cds+=/blood_fury,if=stealthed.rogue
			if S.BloodFury:IsCastable() then
				if ER.Cast(S.BloodFury, Settings.Subtlety.OffGCDasOffGCD.BloodFury) then return "Cast"; end
			end
			-- actions.cds+=/berserking,if=stealthed.rogue
			if S.Berserking:IsCastable() then
				if ER.Cast(S.Berserking, Settings.Subtlety.OffGCDasOffGCD.Berserking) then return "Cast"; end
			end
			-- actions.cds+=/arcane_torrent,if=stealthed.rogue&energy.deficit>70
			if S.ArcaneTorrent:IsCastable() and Player:EnergyDeficit() > 70 then
				if ER.Cast(S.ArcaneTorrent, Settings.Subtlety.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
			end
		end
		-- actions.cds+=/shadow_blades,if=!stealthed.all
		if S.ShadowBlades:IsCastable() and not Player:IsStealthed(true, true) and not Player:Buff(S.ShadowBlades) then
			if ER.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return "Cast"; end
		end
		-- actions.cds+=/goremaws_bite,if=!stealthed.all&((combo_points.deficit>=4-(time<10)*2&energy.deficit>50+talent.vigor.enabled*25-(time>=10)*15)|target.time_to_die<8)
		if S.GoremawsBite:IsCastable() and not Player:IsStealthed(true, true) and ((Player:ComboPointsDeficit() >= 4-(ER.CombatTime() < 10 and 2 or 0) and Player:EnergyDeficit() > 50 + (S.Vigor:IsAvailable() and 25 or 0) - (ER.CombatTime() >= 10 and 15 or 0)) or Target:TimeToDie(10) < 8) then
			if ER.Cast(S.GoremawsBite) then return "Cast"; end
		end
		-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|(raid_event.adds.in>40&combo_points.deficit>=4+talent.deeper_strategem.enabled+talent.anticipation.enabled)
		--[[Normal MfD
		if not S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= 4+(S.DeeperStratagem:IsAvailable() and 1 or 0)+(S.Anticipation:IsAvailable() and 1 or 0) then
			if ER.Cast(S.MarkedforDeath, Settings.Subtlety.OffGCDasOffGCD.MarkedforDeath) then return "Cast"; end
		end]]
	end
	return false;
end
-- # Finishers
local function Finish ()
	-- actions.finish=enveloping_shadows,if=buff.enveloping_shadows.remains<target.time_to_die&buff.enveloping_shadows.remains<=combo_points*1.8
	if S.EnvelopingShadows:IsCastable() and Player:BuffRemains(S.EnvelopingShadows) < Target:TimeToDie() and Player:BuffRemains(S.EnvelopingShadows) < Player:ComboPoints()*1.8 then
		if ER.Cast(S.EnvelopingShadows) then return "Cast"; end
	end
	-- actions.finish+=/death_from_above,if=spell_targets.death_from_above>=6
	if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 6 and Target:IsInRange(15) and S.DeathFromAbove:IsCastable() then
		if ER.Cast(S.DeathFromAbove) then return "Cast"; end
	end
	-- actions.finish+=/nightblade,target_if=max:target.time_to_die,if=target.time_to_die>8&((refreshable&(!finality|buff.finality_nightblade.up))|remains<tick_time)
	if S.Nightblade:IsCastable() then
		if Target:IsInRange(5) and Target:TimeToDie() > 8 and ((Target:DebuffRefreshable(S.Nightblade, (6+Player:ComboPoints()*2)*0.3) and (not ER.Finality(Target) or Player:Buff(S.FinalityNightblade))) or Target:DebuffRemains(S.Nightblade) < 2) then
			if ER.Cast(S.Nightblade) then return "Cast"; end
		end
		if ER.AoEON() then
			BestUnit, BestUnitTTD = nil, 8;
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
		if ER.Cast(S.DeathFromAbove) then return "Cast"; end
	end
	-- actions.finish+=/eviscerate
	if Target:IsInRange(5) and S.Eviscerate:IsCastable() then
		if ER.Cast(S.Eviscerate) then return "Cast"; end
	end
	return false;
end
-- # Stealth Cooldowns
local function Stealth_CDs ()
	if Target:IsInRange(5) then
		-- actions.stealth_cds=shadow_dance,if=charges_fractional>=2.45
		if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:ChargesFractional() >= 2.45 then
			if ER.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast"; end
		end
		-- actions.stealth_cds+=/vanish
		if ER.CDsON() and S.Vanish:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target) and S.ShadowDance:ChargesFractional() < 2.45 then
			if ER.Cast(S.Vanish, Settings.Subtlety.OffGCDasOffGCD.Vanish) then return "Cast"; end
		end
		-- actions.stealth_cds+=/shadow_dance,if=charges>=2&combo_points<=1
		if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:Charges() >= 2 and Player:ComboPoints() <= 1 then
			if ER.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast"; end
		end
		-- actions.stealth_cds+=/shadowmeld,if=energy>=40-variable.ssw_er&energy.deficit>10
		if ER.CDsON() and S.Shadowmeld:IsCastable() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Vanish:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target) and S.ShadowDance:ChargesFractional() < 2.45 and GetUnitSpeed("player") == 0 and Player:EnergyDeficit() > 10 then
			-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40-variable.ssw_er
			if Player:Energy() < 40-SSW_ER() then
				return "Pool for Shadowmeld";
			end
			if ER.Cast(S.Shadowmeld, Settings.Subtlety.OffGCDasOffGCD.Shadowmeld) then return "Cast"; end
		end
		-- actions.stealth_cds+=/shadow_dance,if=combo_points<=1
		if (ER.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge)) and S.ShadowDance:IsCastable() and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.ShadowDance:TimeSinceLastDisplay() ~= 0 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and Player:ComboPoints() <= 1 and S.ShadowDance:Charges() >= 1 then
			if ER.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast"; end
		end
	end
	return false;
end
-- # Stealthed Rotation
local function Stealthed ()
	-- actions.stealthed=symbols_of_death,if=buff.shadowmeld.down&((buff.symbols_of_death.remains<target.time_to_die-4&buff.symbols_of_death.remains<=buff.symbols_of_death.duration*0.3)|(equipped..shadow_satyrs_walk&energy.time_to_max<0.25))
	if S.SymbolsofDeath:IsCastable() and not Player:Buff(S.Shadowmeld) and ((Player:BuffRemains(S.SymbolsofDeath) < Target:TimeToDie(10)-4 and Player:BuffRefreshable(S.SymbolsofDeath, 10.5)) or (I.ShadowSatyrsWalk:IsEquipped(8) and Player:EnergyTimeToMax() < 0.25)) then
		if ER.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast"; end
	end
	-- actions.stealthed+=/call_action_list,name=finish,if=combo_points>=5
	if Player:ComboPoints() >= 5 then
		ShouldReturn = Finish();
		if ShouldReturn then
			return ShouldReturn;
		end
	end
	-- actions.stealthed+=/shuriken_storm,if=buff.shadowmeld.down&((combo_points.deficit>=3&spell_targets.shuriken_storm>=2+talent.premeditation.enabled+equipped.shadow_satyrs_walk)|buff.the_dreadlords_deceit.stack>=29)
	if ER.AoEON() and S.ShurikenStorm:IsCastable() and not Player:Buff(S.Shadowmeld) and ((Player:ComboPointsDeficit() >= 3 and ER.Cache.EnemiesCount[10] >= 2+(S.Premeditation:IsAvailable() and 1 or 0)+(I.ShadowSatyrsWalk:IsEquipped(8) and 1 or 0)) or (Target:IsInRange(5) and Player:BuffStack(S.DreadlordsDeceit) >= 29)) then
		if ER.Cast(S.ShurikenStorm) then return "Cast"; end
	end
	-- actions.stealthed+=/shadowstrike
	if Target:IsInRange(5) and S.Shadowstrike:IsCastable() then
		if ER.Cast(S.Shadowstrike) then return "Cast"; end
	end
	return false;
end
local SappedSoulSpells = {
	{S.Feint, "Cast Feint (Sappel Soul)", function () return true; end},
	{S.CrimsonVial, "Cast Crimson Vial (Sappel Soul)", function () return true; end},
	{S.Kick, "Cast Kick (Sappel Soul)", function () return Target:IsInRange(5); end}
};
local function MythicDungeon ()
	-- Sapped Soul
	if ER.MythicDungeon() == "Sapped Soul" then
		for i = 1, #SappedSoulSpells do
			if SappedSoulSpells[i][1]:IsCastable() and SappedSoulSpells[i][3]() then
				ER.Cast(SappedSoulSpells[i][1]);
				ER.ChangePulseTimer(1);
				return SappedSoulSpells[i][2];
			end
		end
	end
	return false;
end
local function TrainingScenario ()
	if Target:CastName() == "Unstable Explosion" and Target:CastPercentage() > 60-10*Player:ComboPoints() then
		-- Kidney Shot
		if Target:IsInRange(5) and S.KidneyShot:IsCastable() and Player:ComboPoints() > 0 then
			if ER.Cast(S.KidneyShot) then return "Cast Kidney Shot (Unstable Explosion)"; end
		end
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
				if ER.Cast(S.Stealth, Settings.Subtlety.OffGCDasOffGCD.Stealth) then return "Cast"; end
			end
			-- Crimson Vial
			if S.CrimsonVial:IsCastable() and Player:HealthPercentage() <= 80 then
				if ER.Cast(S.CrimsonVial, Settings.Subtlety.GCDasOffGCD.CrimsonVial) then return "Cast"; end
			end
			-- Flask
			-- Food
			-- Rune
			-- PrePot w/ DBM Count
			-- Symbols of Death
			if S.SymbolsofDeath:IsCastable() and Player:IsStealthed(true, true) and (ER.BMPullTime() == 60 or (ER.BMPullTime() <= 15 and ER.BMPullTime() >= 14) or (ER.BMPullTime() <= 4 and ER.BMPullTime() >= 3)) then
				if ER.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast"; end
			end
			-- Opener
			if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
				if Player:ComboPoints() >= 5 then
					if S.Nightblade:IsCastable() and not Target:Debuff(S.Nightblade) then
						if ER.Cast(S.Nightblade) then return "Cast"; end
					elseif S.Eviscerate:IsCastable() then
						if ER.Cast(S.Eviscerate) then return "Cast"; end
					end
				elseif Player:IsStealthed(true, true) and S.Shadowstrike:IsCastable() then
					if ER.Cast(S.Shadowstrike) then return "Cast"; end
				elseif S.Backstab:IsCastable() then
					if ER.Cast(S.Backstab) then return "Cast"; end
				end
			end
			return;
		end
	-- In Combat
		-- Unit Update
		ER.GetEnemies(30); -- Marked for Death
		ER.GetEnemies(10); -- Shuriken Storm
		ER.GetEnemies(8); -- Death From Above
		ER.GetEnemies(5); -- Melee
		-- MfD Sniping
		if S.MarkedforDeath:IsCastable() then
			BestUnit, BestUnitTTD = nil, 60;
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
			if ER.Cast(S.CrimsonVial, Settings.Subtlety.GCDasOffGCD.CrimsonVial) then return "Cast"; end
		end
		-- Feint
		if S.Feint:IsCastable() and not Player:Buff(S.Feint) and Player:HealthPercentage() <= 10 then
			if ER.Cast(S.Feint, Settings.Subtlety.GCDasOffGCD.Feint) then return "Cast Kick"; end
		end
		if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
			-- Mythic Dungeon
			ShouldReturn = MythicDungeon();
			if ShouldReturn then
				return ShouldReturn;
			end
			--[[ Disabled since not coded for Subtlety yet
			-- Training Scenario
			if TrainingScenario() then
				return;
			end
			]]
			-- Kick
			if Settings.General.InterruptEnabled and not S.Kick:IsOnCooldown() and Target:IsInRange(5) and Target:IsInterruptible() then
				if ER.Cast(S.Kick, Settings.Subtlety.OffGCDasOffGCD.Kick) then return "Cast Kick"; end
			end
			-- actions+=/call_action_list,name=cds
			if ER.CDsON() then
				ShouldReturn = CDs();
				if ShouldReturn then
					return ShouldReturn;
				end
			end
			-- actions+=/run_action_list,name=stealthed,if=stealthed.all
			if Player:IsStealthed(true, true) then
				ShouldReturn = Stealthed();
				if ShouldReturn then
					return ShouldReturn;
				end
				return "Stealthed Pooling"; -- run_action_list forces the return
			end
			-- actions+=/call_action_list,name=finish,if=combo_points>=5|(combo_points>=4&spell_targets.shuriken_storm>=3&spell_targets.shuriken_storm<=4)
			if Player:ComboPoints() >= 5 or (ER.AoEON() and Player:ComboPoints() >= 4 and ER.Cache.EnemiesCount[10] >= 3 and ER.Cache.EnemiesCount[10] <= 4) then
				ShouldReturn = Finish();
				if ShouldReturn then
					return ShouldReturn;
				end
			end
			-- actions+=/call_action_list,name=stealth_cds,if=combo_points.deficit>=2+talent.premeditation.enabled&(variable.ed_threshold|(cooldown.shadowmeld.up&!cooldown.vanish.up&cooldown.shadow_dance.charges<=1)|target.time_to_die<12)
			if Player:ComboPointsDeficit() >= 2+(S.Premeditation:IsAvailable() and 1 or 0) and (ED_Threshold() or (not S.Shadowmeld:IsOnCooldown() and S.Vanish:IsOnCooldown() and S.ShadowDance:Charges() <= 1) or Target:TimeToDie() < 12) then
				ShouldReturn = Stealth_CDs();
				if ShouldReturn then
					return ShouldReturn;
				end
			end
			-- actions+=/call_action_list,name=build,if=variable.ed_threshold
			if ED_Threshold() then
				ShouldReturn = Build();
				if ShouldReturn then
					return ShouldReturn;
				end
			end
			-- Shuriken Toss Out of Range
			if not Target:IsInRange(10) and Target:IsInRange(20) and S.ShurikenToss:IsCastable() and not Player:IsStealthed(true, true) and Player:EnergyDeficit() < 20 and (Player:ComboPointsDeficit() >= 1 or Player:EnergyTimeToMax() <= 1.2) then
				if ER.Cast(S.ShurikenToss) then return "Cast Shuriken Toss"; end
			end
		end
end

ER.SetAPL(261, APL);
