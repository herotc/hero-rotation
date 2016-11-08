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
		GiftoftheNaaru = Spell(59547),
		-- Abilities
		BladeofJustice = Spell(184575),
		Consecration = Spell(205228),
		CrusaderStrike = Spell(35395),
		DivineHamme = Spell(198034),
		DivinePurpose = Spell(223817),
		DivinePurposeBuff = Spell(223819),
		DivineStorm = Spell(53385),
		ExecutionSentence = Spell(213757),
		GreaterJudgment = Spell(218718),
		HolyWrath = Spell(210220),
		Judgment = Spell(20271),
		JudgmentDebuff = Spell(197277),
		JusticarsVengeance = Spell(215661),
		TemplarsVerdict = Spell(85256),
		TheFiresofJustice = Spell(203316),
		Zeal = Spell(217020),
		-- Offensive
		AvengingWrath = Spell(31884),
		Crusade = Spell(231895),
		WakeofAshes = Spell(205273)
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
-- GUI Settings
	local Settings = {
		General = ER.GUISettings.General,
		Retribution = ER.GUISettings.APL.Paladin.Retribution
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
		ER.GetEnemies(8); -- Divine Storm
		ER.GetEnemies(5); -- Melee
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
			if Target:IsInRange(5) then
				-- actions+=/holy_wrath
				if ER.CDsON() and S.HolyWrath:IsCastable() then
					if ER.Cast(S.HolyWrath, Settings.Retribution.GCDasOffGCD.HolyWrath) then return "Cast Holy Wrath" end
				end
				-- actions+=/avenging_wrath
				if ER.CDsON() and S.AvengingWrath:IsCastable() then
					if ER.Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "Cast Avenging Wrath" end
				end
				-- actions+=/shield_of_vengeance
				-- TODO: Add it if dmg are taken, not honly based on HP.
				-- actions+=/crusade,if=holy_power>=5
				if ER.CDsON() and S.Crusade:IsCastable() and Player:HolyPower() >= 5 then
					if ER.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade" end
				end
				-- actions+=/wake_of_ashes,if=holy_power>=0&time<2
				if ER.CDsON() and S.WakeofAshes:IsCastable() and Player:HolyPower() >= 0 and ER.CombatTime() < 2 then
					if ER.Cast(S.WakeofAshes) then return "Cast Wake of Ashes" end
				end
			end
			-- actions+=/execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.67)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)
			if Target:IsInRange(20) and S.ExecutionSentence:IsCastable() and EnemiesCount[8] <= 3 and (S.Judgment:Cooldown() < Player:GCD()*4.5 or Target:DebuffRemains(S.Judgment) > Player:GCD()*4.67) and (not S.Crusade:IsAvailable() or S.Crusade:Cooldown() > Player:GCD()*2) then
				if ER.Cast(S.ExecutionSentence) then return "Cast Execution Sentence" end
			end
			if Target:IsInRange(5) then
				-- actions+=/blood_fury
				-- actions+=/berserking
				-- actions+=/arcane_torrent,if=holy_power<5
				if S.ArcaneTorrent:IsCastable() and Player:HolyPowerDeficit() < 5 then
					if ER.Cast(S.ArcaneTorrent, Settings.Retribution.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
				end
			end
			if ER.Cache.EnemiesCount[8] >= 2 and Target:Debuff(S.JudgmentDebuff) then
				-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
				if Player:Buff(S.DivinePurposeBuff) and Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD() * 2 then

				end
				if Player:HolyPower() >= 5 then
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&buff.divine_purpose.react
					if Player:Buff(S.DivinePurposeBuff) then

					end
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
					if (not S.Crusade:Exists() or S.Crusade:Cooldown() > Player:GCD() * 3) then

					end
				end
			end
			
			-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.whisper_of_the_nathrezim
			-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
			-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
			-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
			-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
			-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
			-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=3&buff.divine_purpose.up&cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled&!equipped.whisper_of_the_nathrezim
			-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
			-- actions+=/wake_of_ashes,if=holy_power=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&(cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)
			-- actions+=/zeal,if=charges=2&holy_power<=4
			-- actions+=/crusader_strike,if=charges=2&holy_power<=4
			-- actions+=/blade_of_justice,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
			-- actions+=/divine_hammer,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
			-- actions+=/judgment,if=holy_power>=3|((cooldown.zeal.charges_fractional<=1.67|cooldown.crusader_strike.charges_fractional<=1.67)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd))|(talent.greater_judgment.enabled&target.health.pct>50)
			-- actions+=/consecration
			-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.react
			-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
			-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
			-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
			-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
			-- actions+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
			-- actions+=/templars_verdict,if=debuff.judgment.up&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
			-- actions+=/zeal,if=holy_power<=4
			-- actions+=/crusader_strike,if=holy_power<=4
			-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
			-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
		end
end

ER.SetAPL(70, APL);

-- Last Update: 11/07
-- actions=auto_attack
-- actions+=/rebuke
-- actions+=/potion,name=old_war,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up|target.time_to_die<=40)
-- actions+=/holy_wrath
-- actions+=/avenging_wrath
-- actions+=/shield_of_vengeance
-- actions+=/crusade,if=holy_power>=5
-- actions+=/wake_of_ashes,if=holy_power>=0&time<2
-- ac-- tions+=/execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.67)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)
-- actions+=/blood_fury
-- actions+=/berserking
-- actions+=/arcane_torrent,if=holy_power<5
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&buff.divine_purpose.react
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.whisper_of_the_nathrezim
-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=3&buff.divine_purpose.up&cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled&!equipped.whisper_of_the_nathrezim
-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
-- actions+=/wake_of_ashes,if=holy_power=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&(cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)
-- actions+=/zeal,if=charges=2&holy_power<=4
-- actions+=/crusader_strike,if=charges=2&holy_power<=4
-- actions+=/blade_of_justice,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
-- actions+=/divine_hammer,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
-- actions+=/judgment,if=holy_power>=3|((cooldown.zeal.charges_fractional<=1.67|cooldown.crusader_strike.charges_fractional<=1.67)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd))|(talent.greater_judgment.enabled&target.health.pct>50)
-- actions+=/consecration
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.react
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
-- actions+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
-- actions+=/templars_verdict,if=debuff.judgment.up&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
-- actions+=/zeal,if=holy_power<=4
-- actions+=/crusader_strike,if=holy_power<=4
-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
