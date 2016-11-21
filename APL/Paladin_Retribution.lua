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
	Spell.Paladin.Retribution = {
		-- Racials
		ArcaneTorrent = Spell(25046),
		GiftoftheNaaru = Spell(59547),
		-- Abilities
		BladeofJustice = Spell(184575),
		Consecration = Spell(205228),
		CrusaderStrike = Spell(35395),
		DivineHammer = Spell(198034),
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
		TheFiresofJusticeBuff = Spell(209785),
		Zeal = Spell(217020),
		-- Offensive
		AvengingWrath = Spell(31884),
		Crusade = Spell(231895),
		WakeofAshes = Spell(205273);
		-- Defensive
		-- Utility
		-- Legendaries
		WhisperoftheNathrezim = Spell(207635)
	};
	local S = Spell.Paladin.Retribution;
-- Items
	if not Item.Paladin then Item.Paladin = {}; end
	Item.Paladin.Retribution = {
		-- Legendaries
		WhisperoftheNathrezim = Item(137020) -- 15
	};
	local I = Item.Paladin.Retribution;
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
			-- Opener
			if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(5) then
				if S.Judgment:IsCastable() then
					if ER.Cast(S.Judgment) then return "Cast Judgment"; end
				elseif S.Zeal:IsCastable() then
					if ER.Cast(S.Zeal) then return "Cast Zeal"; end
				elseif S.CrusaderStrike:IsCastable() then
					if ER.Cast(S.CrusaderStrike) then return "Cast CrusaderStrike"; end
				end
			end
			return;
		end
	-- In Combat
		-- Unit Update
		ER.GetEnemies(8); -- Divine Storm
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
					if ER.Cast(S.HolyWrath, Settings.Retribution.GCDasOffGCD.HolyWrath) then return "Cast Holy Wrath"; end
				end
				-- actions+=/avenging_wrath
				if ER.CDsON() and S.AvengingWrath:IsCastable() then
					if ER.Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "Cast Avenging Wrath"; end
				end
				-- actions+=/shield_of_vengeance
				-- TODO: Add it if dmg are taken, not only based on HP.
				-- actions+=/crusade,if=holy_power>=5
				if ER.CDsON() and S.Crusade:IsCastable() and Player:HolyPower() >= 5 then
					if ER.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
				end
				-- actions+=/wake_of_ashes,if=holy_power>=0&time<2
				if S.WakeofAshes:IsCastable() and Player:HolyPower() >= 0 and ER.CombatTime() < 2 then
					if ER.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
				end
			end
			-- actions+=/execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.67)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)
			if Target:IsInRange(20) and S.ExecutionSentence:IsCastable() and ER.Cache.EnemiesCount[8] <= 3 and (S.Judgment:Cooldown() < Player:GCD()*4.5 or Target:DebuffRemains(S.Judgment) > Player:GCD()*4.67) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*2) then
				if ER.Cast(S.ExecutionSentence) then return "Cast Execution Sentence"; end
			end
			if Target:IsInRange(5) then
				-- actions+=/blood_fury
				-- actions+=/berserking
				-- actions+=/arcane_torrent,if=holy_power<5
				if S.ArcaneTorrent:IsCastable() and Player:HolyPowerDeficit() < 5 then
					if ER.Cast(S.ArcaneTorrent, Settings.Retribution.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
				end
			end
			-- SoloMode : Justicar's Vengeance
			if Settings.Retribution.SoloMode and S.JusticarsVengeance:IsCastable() then
				-- Divine Purpose 
				if Player:HealthPercentage() <= Settings.Retribution.SoloJusticarDP and Player:Buff(S.DivinePurposeBuff) then
					if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
				end
				-- Regular
				if Player:HealthPercentage() <= Settings.Retribution.SoloJusticar5HP and Player:HolyPower() >= 5 then
					if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
				end
			end

			if (Target:Debuff(S.JudgmentDebuff) or S.Judgment:Cooldown() > Player:GCD()*4) then
				if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 2 and S.DivineStorm:IsCastable() then
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
					if Player:Buff(S.DivinePurposeBuff) and Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD()*2 then
						if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
					end
					if Player:HolyPower() >= 5 then
						-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&buff.divine_purpose.react
						if Player:Buff(S.DivinePurposeBuff) then
							if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
						end
						-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
						if not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*3 then
							if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
						end
					end
				end
				if Target:IsInRange(5) then
					if S.JusticarsVengeance:IsCastable() and not I.WhisperoftheNathrezim:IsEquipped(15) then
						-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.whisper_of_the_nathrezim
						if Player:Buff(S.DivinePurposeBuff) and Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD()*2 then
							if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
						end
						-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
						if Player:HolyPower() >= 5 and Player:Buff(S.DivinePurposeBuff) then
							if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
						end
					end
					if S.TemplarsVerdict:IsCastable() then
						-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
						if Player:Buff(S.DivinePurposeBuff) and Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD()*2 then
							if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
						end
						if Player:HolyPower() >= 5 then
							-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
							if Player:Buff(S.DivinePurposeBuff) then
								if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
							end
							-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
							if not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*3 then
								if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
							end
						end
					end
				end
				if Player:HolyPower() >= 3 then
					-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
					if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 2 and S.DivineStorm:IsCastable() and ((S.WakeofAshes:IsCastable() and S.WakeofAshes:Cooldown() < Player:GCD()*2) or (Player:Buff(S.WhisperoftheNathrezim) and Player:BuffRemains(S.WhisperoftheNathrezim) < Player:GCD())) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*4) then
						if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
					end
					if Target:IsInRange(5) then
						-- actions+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=3&buff.divine_purpose.up&cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled&!equipped.whisper_of_the_nathrezim
						if S.JusticarsVengeance:IsCastable() and Player:Buff(S.DivinePurposeBuff) and S.WakeofAshes:IsCastable() and S.WakeofAshes:Cooldown() < Player:GCD()*2 and not I.WhisperoftheNathrezim:IsEquipped(15) then
							if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
						end
						-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(cooldown.wake_of_ashes.remains<gcd*2&artifact.wake_of_ashes.enabled|buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd)&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
						if S.TemplarsVerdict:IsCastable() and ((S.WakeofAshes:IsCastable() and S.WakeofAshes:Cooldown() < Player:GCD()*2) or (Player:Buff(S.WhisperoftheNathrezim) and Player:BuffRemains(S.WhisperoftheNathrezim) < Player:GCD())) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*4) then
							if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
						end
					end
				end
			end
			if Target:IsInRange(5) then
				-- actions+=/wake_of_ashes,if=holy_power=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&(cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)
				if S.WakeofAshes:IsCastable() and (Player:HolyPower() == 0 or (Player:HolyPower() == 1 and (S.BladeofJustice:Cooldown() > Player:GCD() or S.DivineHammer:Cooldown() > Player:GCD())) or (Player:HolyPower() == 2 and (S.Zeal:ChargesFractional() <= 0.65 or S.CrusaderStrike:ChargesFractional() <= 0.65))) then
					if ER.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
				end
				if Player:HolyPower() <= 4 then
					-- actions+=/zeal,if=charges=2&holy_power<=4
					if S.Zeal:IsCastable() and S.Zeal:Charges() == 2 then
						if ER.Cast(S.Zeal) then return "Cast Zeal"; end
					end
					-- actions+=/crusader_strike,if=charges=2&holy_power<=4
					if S.CrusaderStrike:IsCastable() and S.CrusaderStrike:Charges() == 2 then
						if ER.Cast(S.CrusaderStrike) then return "Cast CrusaderStrike"; end
					end
				end
			end
			if Player:HolyPower() <= 2 or (Player:HolyPower() <= 3 and (S.Zeal:ChargesFractional() <= 1.34 or S.CrusaderStrike:ChargesFractional() <= 1.34)) then
				-- actions+=/blade_of_justice,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
				if Target:IsInRange(10) and S.BladeofJustice:IsCastable() then
					if ER.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
				end
				-- actions+=/divine_hammer,if=holy_power<=2|(holy_power<=3&(cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34))
				if Target:IsInRange(8) and S.DivineHammer:IsCastable() then
					if ER.Cast(S.DivineHammer) then return "Cast Divine Hammer"; end
				end
			end
			-- actions+=/judgment,if=holy_power>=3|((cooldown.zeal.charges_fractional<=1.67|cooldown.crusader_strike.charges_fractional<=1.67)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd))|(talent.greater_judgment.enabled&target.health.pct>50)
			if Target:IsInRange(30) and S.Judgment:IsCastable() and (Player:HolyPower() >= 3 or ((S.Zeal:ChargesFractional() <= 1.67 or S.CrusaderStrike:ChargesFractional() <= 1.67) and (S.DivineHammer:Cooldown() > Player:GCD() or S.BladeofJustice:Cooldown() > Player:GCD())) or (S.GreaterJudgment:IsAvailable() and Target:HealthPercentage() > 50)) then
				if ER.Cast(S.Judgment) then return "Cast Judgment"; end
			end
			-- actions+=/consecration
			if Target:IsInRange(8) and S.Consecration:IsCastable() then
				if ER.Cast(S.Consecration) then return "Cast Consecration"; end
			end
			if (Target:Debuff(S.JudgmentDebuff) or S.Judgment:Cooldown() > Player:GCD()*4) then
				if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 2 and S.DivineStorm:IsCastable() then
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.divine_purpose.react
					if Player:Buff(S.DivinePurposeBuff) then
						if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
					end
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
					if Player:HolyPower() >= 3 and Player:Buff(S.TheFiresofJusticeBuff) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*3) then
						if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
					end
					-- actions+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
					if (Player:HolyPower() >= 4 or (Player:HolyPower() >= 3 and (S.Zeal:ChargesFractional() <= 1.34 or S.CrusaderStrike:ChargesFractional() <= 1.34) and (S.DivineHammer:Cooldown() > Player:GCD() or S.BladeofJustice:Cooldown() > Player:GCD()))) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*4) then
						if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
					end
				end
				if Target:IsInRange(5) then
					-- actions+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.whisper_of_the_nathrezim
					if S.JusticarsVengeance:IsCastable() and Player:Buff(S.DivinePurposeBuff) and not I.WhisperoftheNathrezim:IsEquipped(15) then
						if ER.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
					end
					if S.TemplarsVerdict:IsCastable() then
						-- actions+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
						if Player:Buff(S.DivinePurposeBuff) then
							if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
						end
						-- actions+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)
						if Player:Buff(S.TheFiresofJusticeBuff) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*3) then
							if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
						end
						-- actions+=/templars_verdict,if=debuff.judgment.up&(holy_power>=4|((cooldown.zeal.charges_fractional<=1.34|cooldown.crusader_strike.charges_fractional<=1.34)&(cooldown.divine_hammer.remains>gcd|cooldown.blade_of_justice.remains>gcd)))&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*4)
						if (Player:HolyPower() >= 4 or (Player:HolyPower() >= 3 and (S.Zeal:ChargesFractional() <= 1.34 or S.CrusaderStrike:ChargesFractional() <= 1.34) and (S.DivineHammer:Cooldown() > Player:GCD() or S.BladeofJustice:Cooldown() > Player:GCD()))) and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*4) then
							if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
						end
					end
				end
			end
			if Target:IsInRange(5) and Player:HolyPower() <= 4 then
				-- actions+=/zeal,if=holy_power<=4
				if S.Zeal:IsCastable() then
					if ER.Cast(S.Zeal) then return "Cast Zeal"; end
				end
				-- actions+=/crusader_strike,if=holy_power<=4
				if S.CrusaderStrike:IsCastable() then
					if ER.Cast(S.CrusaderStrike) then return "Cast CrusaderStrike"; end
				end
			end
			if (Target:Debuff(S.JudgmentDebuff) or S.Judgment:Cooldown() > Player:GCD()*4) and Player:HolyPower() >= 3 and (not S.Crusade:IsAvailable() or not ER.CDsON() or S.Crusade:Cooldown() > Player:GCD()*5) then
				-- actions+=/divine_storm,if=debuff.judgment.up&holy_power>=3&spell_targets.divine_storm>=2&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
				if ER.AoEON() and ER.Cache.EnemiesCount[8] >= 2 and S.DivineStorm:IsCastable() then
					if ER.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
				end
				-- actions+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*5)
				if Target:IsInRange(5) and S.TemplarsVerdict:IsCastable() then
					if ER.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
				end
			end
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
