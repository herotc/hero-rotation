--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- HeroRotation
local HR = HeroRotation;
-- Lua
local pairs = pairs;


--- APL Local Vars
-- Spells
  if not Spell.Paladin then Spell.Paladin = {}; end
  Spell.Paladin.Retribution = {
    -- Racials
    ArcaneTorrent                 = Spell(155145),
    GiftoftheNaaru                = Spell(59547),
    -- Abilities
    BladeofJustice                = Spell(184575),
    Consecration                  = Spell(205228),
    CrusaderStrike                = Spell(35395),
    DivineHammer                  = Spell(198034),
    DivinePurpose                 = Spell(223817),
    DivinePurposeBuff             = Spell(223819),
	  EmpyreanPowerBuff   	        = Spell(286393),
    DivineStorm                   = Spell(53385),
    ExecutionSentence             = Spell(267798),
    GreaterJudgment               = Spell(218718),
    HolyWrath                     = Spell(210220),
    Judgment                      = Spell(20271),
    JudgmentDebuff                = Spell(197277),
	  JusticarsVengeance            = Spell(215661),
	  TemplarsVerdict               = Spell(85256),
	  HammerOfWrath                 = Spell(24275),
    -- Offensive
    AvengingWrath                 = Spell(31884),
    Crusade                       = Spell(231895),
    WakeofAshes                   = Spell(255937),
	  Inquisition                   = Spell(84963),
    -- Defensive
    -- Utility
    HammerofJustice               = Spell(853),
    Rebuke                        = Spell(96231),
  };
  local S = Spell.Paladin.Retribution;
-- Items
  if not Item.Paladin then Item.Paladin = {}; end
  Item.Paladin.Retribution = {
    -- Legendaries
    JusticeGaze                   = Item(137065, {1}),
    LiadrinsFuryUnleashed         = Item(137048, {11, 12}),
    WhisperoftheNathrezim         = Item(137020, {15})
  };
  local I = Item.Paladin.Retribution;
-- Rotation Var
-- GUI Settings
  local Settings = {
    General = HR.GUISettings.General,
    Retribution = HR.GUISettings.APL.Paladin.Retribution
  };




-- APL Action Lists (and Variables)
--actions.cooldowns
--action,conditions
--potion,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
--TODO
--lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
--TODO
--fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
--TODO
--avenging_wrath,if=buff.inquisition.up|!talent.inquisition.enabled
local conditions_avenging_wrath
--crusade,if=holy_power>=4
local conditions_crusade 
--templars_verdict
local conditions_templars_verdict
--execution_sentence
local conditions_execution_sentence
--actions.finishers
--action,conditions
--variable,name=ds_castable,value=spell_targets.divine_storm>=2
local conditions_ds_castable
--Blade of Justice
local conditions_blade_of_justice
-- Wake of Ashes
local conditions_wake_of_ashes
-- Inquisition
local conditions_inquisition
-- APL Main
local function APL ()-- APL Action Lists (and Variables)
  --- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ DBM Count
      -- Opener

    end
  -- In Combat
    -- Unit Update
    HL.GetEnemies(8, true); -- Divine Storm
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
		  -- Interrupts
		if Settings.General.InterruptEnabled and Target:IsInterruptible()  then
			if S.Rebuke:IsCastable("Melee") then
				if HR.Cast(S.Rebuke) then return "Cast Rebuke"; end
			elseif Settings.General.InterruptWithStun and Target:CanBeStunned() then
				if S.HammerofJustice:IsCastable(10) then
					if HR.Cast(S.HammerofJustice) then return "Cast Hammer of Justice"; end
				end
			end
		end
		var_spell_targets = Cache.EnemiesCount[8]
		--actions.cooldowns
		--action,conditions
		--potion,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
		--TODO
		--lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
		--TODO
		--fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
		--TODO
		--avenging_wrath,if=buff.inquisition.up|!talent.inquisition.enabled
		conditions_avenging_wrath = (Player:Buff(S.Inquisition) or not S.Inquisition:IsAvailable());
		--crusade,if=holy_power>=4
		conditions_crusade = (Player:HolyPower() >=4 and S.Crusade:IsReady());
		--templars_verdict
		conditions_templars_verdict = (Player:HolyPower() >= 3)
		--execution_sentence
		conditions_execution_sentence = (var_spell_targets<= 2 and (not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > Player:GCD() * 2) and S.ExecutionSentence:IsAvailable() and S.ExecutionSentence:IsReady())
		--actions.finishers
		--action,conditions		
		conditions_blade_of_justice = (Player:HolyPower() <=3 and S.BladeofJustice:IsReady() and S.BladeofJustice:IsCastable())
		-- Wake of Ashes
		conditions_wake_of_ashes = (Player:HolyPower() <= 0 or Player:HolyPower() == 1 and S.BladeofJustice:CooldownRemains() > Player:GCD())
		-- Inquisition
		conditions_inquisition = ((not Player:Buff(S.Inquisition) or Player:BuffRemainsP(S.Inquisition) <5) and Player:HolyPower() >=3) or ((S.ExecutionSentence:IsAvailable() and S.ExecutionSentence:CooldownRemains() <10 and Player:BuffRemainsP(S.Inquisition) < 15 or S.AvengingWrath:CooldownRemains() <15 and Player:BuffRemainsP(S.Inquisition) <20) and Player:HolyPower() >=3)
		--# Executed every time the actor is available.
		--actions=auto_attack
		--actions+=/rebuke
		--actions+=/call_action_list,name=opener
		opener()
		--actions+=/call_action_list,name=cooldowns
		--actions+=/call_action_list,name=generators
		--
		--actions.cooldowns=use_item,name=ritual_feather_of_unng_ak,if=(buff.avenging_wrath.up|buff.crusade.up)
		--actions.cooldowns+=/use_item,name=dooms_fury,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<18
		--actions.cooldowns+=/potion,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
		--actions.cooldowns+=/lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
		--actions.cooldowns+=/fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
		--actions.cooldowns+=/shield_of_vengeance
		--actions.cooldowns+=/avenging_wrath,if=buff.inquisition.up|!talent.inquisition.enabled
		if (conditions_avenging_wrath) then
			if HR.CDsON() and S.AvengingWrath:IsCastable() then
				if HR.Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "Cast Avenging Wrath"; end
			end
		end
		--actions.cooldowns+=/crusade,if=holy_power>=4
		if (conditions_crusade) then
			if HR.CDsON() and S.Crusade:IsCastable() then
				if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
			end
		end
		--
		--actions.generators=variable,name=HoW,value=(!talent.hammer_of_wrath.enabled|target.health.pct>=20&(buff.avenging_wrath.down|buff.crusade.down))
		conditions_hammer_of_wrath = (not S.HammerOfWrath:IsAvailable() or Target:HealthPercentage() >= 20 and (not Player:Buff(S.Crusade) or not Player:Buff(S.AvengingWrath)));
		--actions.generators+=/call_action_list,name=finishers,if=holy_power>=5
		if (Player:HolyPower() >=5) then
			finishers()
		end
		--actions.generators+=/wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15|spell_targets.wake_of_ashes>=2)&(holy_power<=0|holy_power=1&cooldown.blade_of_justice.remains>gcd)
		if (var_spell_targets >=2 and (conditions_wake_of_ashes)) then 
			if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
				if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
			end
		end
		--actions.generators+=/blade_of_justice,if=holy_power<=2|(holy_power=3&(cooldown.hammer_of_wrath.remains>gcd*2|variable.HoW))
		if (Player:HolyPower() <= 2 or (Player:HolyPower() == 3 and (S.HammerOfWrath:CooldownRemains() > Player:GCD() * 2) or conditions_hammer_of_wrath)) then 
			if (conditions_blade_of_justice) then
				if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
			end
		end
		--actions.generators+=/judgment,if=holy_power<=2|(holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|variable.HoW))
		if (Player:HolyPower() <= 2 or (Player:HolyPower() <=4 and (S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or conditions_hammer_of_wrath))) then
			if S.Judgment:IsCastable() then
				if HR.Cast(S.Judgment) then return "Cast Judgment"; end
			end
		end
		--actions.generators+=/hammer_of_wrath,if=holy_power<=4
		if (Player:HolyPower() <=4) then
			if (not conditions_hammer_of_wrath) then
				if HR.Cast(S.HammerOfWrath) then return "Cast Hammer of Wrath"; end
			end	
		end
		--actions.generators+=/consecration,if=holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2
		if (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 and S.Judgment:CooldownRemains() > Player:GCD() * 2) then
			if HR.AoEON() and S.Consecration:IsCastable(10, true) then
				if HR.Cast(S.Consecration) then return "Cast Consecration"; end
			end
		end
		--actions.generators+=/call_action_list,name=finishers,if=talent.hammer_of_wrath.enabled&(target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up)
		if (S.HammerOfWrath:IsAvailable() and (Target:HealthPercentage() <= 20 or Player:Buff(S.AvengingWrath) or Player:Buff(S.Crusade))) then
			finishers()
		end
		--actions.generators+=/crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2&cooldown.consecration.remains>gcd*2)
		if (S.CrusaderStrike:IsCastable() and S.CrusaderStrike:ChargesFractional() >= 1.75 and (Player:HolyPower() <=2 or Player:HolyPower() <=3 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 and S.Judgment:CooldownRemains() > Player:GCD()*2 and S.Consecration:CooldownRemains() > Player:GCD()*2)) then
			if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
		  end
		
		--actions.generators+=/call_action_list,name=finishers
		finishers()
		--actions.generators+=/crusader_strike,if=holy_power<=4
		if (Player:HolyPower() <=4 and S.CrusaderStrike:IsReady()) then
			if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
		end
		--actions.generators+=/arcane_torrent,if=holy_power<=4
		if (S.ArcaneTorrent:IsCastable() and Player:HolyPower() <= 4) then
			if HR.Cast(S.ArcaneTorrent, Settings.Retribution.OffGCDasOffGCD.ArcaneTorrent) then return "Cast Arcane Torrent"; end
		end
	end
end

function opener()
	--actions.opener=sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&talent.execution_sentence.enabled&!talent.hammer_of_wrath.enabled,name=wake_opener_ES_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:execution_sentence
	if (S.WakeofAshes:IsAvailable() and S.Crusade:IsAvailable() and S.ExecutionSentence:IsAvailable() and not S.HammerOfWrath:IsAvailable()) then
		wake_opener_ES_CS()
	end
	--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&!talent.execution_sentence.enabled&!talent.hammer_of_wrath.enabled,name=wake_opener_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:templars_verdict
	if (S.WakeofAshes:IsAvailable() and S.Crusade:IsAvailable() and not S.ExecutionSentence:IsAvailable() and not S.HammerOfWrath:IsAvailable()) then
		wake_opener_CS()
	end
	--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&talent.execution_sentence.enabled&talent.hammer_of_wrath.enabled,name=wake_opener_ES_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:execution_sentence
	if (S.WakeofAshes:IsAvailable() and S.Crusade:IsAvailable() and S.ExecutionSentence:IsAvailable() and S.HammerOfWrath:IsAvailable()) then
		wake_opener_ES_HoW()
	end
	--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&!talent.execution_sentence.enabled&talent.hammer_of_wrath.enabled,name=wake_opener_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:templars_verdict
	if (S.WakeofAshes:IsAvailable() and S.Crusade:IsAvailable() and not S.ExecutionSentence:IsAvailable() and S.HammerOfWrath:IsAvailable()) then
		wake_opener_HoW()
	end
	--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.inquisition.enabled,name=wake_opener_Inq:shield_of_vengeance:blade_of_justice:judgment:inquisition:avenging_wrath:wake_of_ashes
	if (S.WakeofAshes:IsAvailable() and S.Inquisition:IsAvailable()) then
		wake_opener_Inq()
	end
	
	--new actions.opner for normal wake_opener
	if (S.WakeofAshes:IsAvailable() and not S.Crusade:IsAvailable() and not S.Inquisition:IsAvailable()) then
		wake_opener()
	end
end

--name=wake_opener_ES_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:execution_sentence
function wake_opener_ES_CS()

	if (conditions_blade_of_justice) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (conditions_crusade) then
		if HR.CDsON() and S.Crusade:IsCastable() then
			if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
        end
	end
	if (conditions_templars_verdict) then
		if S.TemplarsVerdict:IsCastable() then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
	if (S.WakeofAshes:IsCastable()) then
		if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
	if (var_crusader_strike) then
		if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
	end
	if (conditions_execution_sentence) then
		if HR.Cast(S.ExecutionSentence) then return "Cast Execution Sentence"; end
	end
end

--name=wake_opener_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:templars_verdict
function wake_opener_CS()

	if (conditions_blade_of_justice) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (conditions_crusade) then
		if HR.CDsON() and S.Crusade:IsCastable() then
			if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
        end
	end
	if (conditions_templars_verdict) then
		if S.TemplarsVerdict:IsCastable() then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
	if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
			if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
	if (var_crusader_strike) then
		if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
	end
end

--name=wake_opener_ES_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:execution_sentence
function wake_opener_ES_HoW()

	if (conditions_blade_of_justice) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (conditions_crusade) then
		if HR.CDsON() and S.Crusade:IsCastable() then
			if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
        end
	end
	if (conditions_templars_verdict) then
		if S.TemplarsVerdict:IsCastable() then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
	if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
			if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
	if (not conditions_hammer_of_wrath) then
		if HR.Cast(S.HammerOfWrath) then return "Cast Hammer of Wrath"; end
	end	
	if (conditions_execution_sentence) then
		if HR.Cast(S.ExecutionSentence) then return "Cast Execution Sentence"; end
	end
end

--name=wake_opener_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:templars_verdict
function wake_opener_HoW()

	if (conditions_blade_of_justice) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (conditions_crusade) then
		if HR.CDsON() and S.Crusade:IsCastable() then
			if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
        end
	end
	if (conditions_templars_verdict) then
		if S.TemplarsVerdict:IsCastable() then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
	if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
			if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
	if (not conditions_hammer_of_wrath) then
		if HR.Cast(S.HammerOfWrath) then return "Cast Hammer of Wrath"; end
	end	
end

--name=wake_opener_Inq:shield_of_vengeance:blade_of_justice:judgment:inquisition:avenging_wrath:wake_of_ashes
function wake_opener_Inq()

	if (conditions_templars_verdict) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (conditions_inquisition) then
		if HR.Cast(S.Inquisition) then return "Cast Inquisition"; end
	end
	if (conditions_avenging_wrath) then
		if HR.CDsON() and S.AvengingWrath:IsCastable() then
			if HR.Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "Cast Avenging Wrath"; end
        end
	end
	if (conditions_templars_verdict) then
		if S.TemplarsVerdict:IsCastable() then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
	if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
		if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
end

function wake_opener()
	--TODO add an better option for casting wake of ashes when no opener function matches and simcraft cause not matches (wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15|spell_targets.wake_of_ashes>=2)&(holy_power<=0|holy_power=1&cooldown.blade_of_justice.remains>gcd))
	if (conditions_templars_verdict) then
		if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
	end
	if (S.Judgment:IsCastable()) then
		if HR.Cast(S.Judgment) then return "Cast Judgment"; end
	end
	if (S.WakeofAshes:IsAvailable() and S.WakeofAshes:IsReady()) then
		if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
	end
end

function finishers()
	--actions.finishers=variable,name=ds_castable,value=spell_targets.divine_storm>=2
	conditions_ds_castable = (var_spell_targets >= 2 and HR.AoEON() and Player:HolyPower() >= 3);
	--actions.finishers+=/inquisition,if=buff.inquisition.down|buff.inquisition.remains<5&holy_power>=3|talent.execution_sentence.enabled&cooldown.execution_sentence.remains<10&buff.inquisition.remains<15|cooldown.avenging_wrath.remains<15&buff.inquisition.remains<20&holy_power>=3
	if (S.Inquisition:IsAvailable()) then
		if (conditions_inquisition) then
			if HR.Cast(S.Inquisition) then return "Cast Inquisition"; end
		end
	end
	--actions.finishers+=/execution_sentence,if=spell_targets.divine_storm<=2&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)
	if (var_spell_targets <= 2 and (not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > Player:GCD() * 2)) then
		if (conditions_execution_sentence) then
			if HR.Cast(S.ExecutionSentence) then return "Cast Execution Sentence"; end
		end
	end
	
	--actions.finishers+=/divine_storm,if=variable.ds_castable&buff.divine_purpose.react
	if (conditions_ds_castable and Player:Buff(S.DivinePurposeBuff)) then
		if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
	end
	--actions.finishers+=/divine_storm,if=variable.ds_castable&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)|buff.empyrean_power.up&debuff.judgment.down&buff.divine_purpose.down
	if (conditions_ds_castable and (not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > Player:GCD() * 2) or Player:Buff(S.EmpyreanPowerBuff) and Target:Debuff(S.Judgment) and not Player:Buff(S.DivinePurposeBuff) ) then
		if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
	end
	
	--actions.finishers+=/templars_verdict,if=buff.divine_purpose.react
	if (S.DivinePurpose:IsAvailable()) then
		if (conditions_templars_verdict) then
			if Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD() * 2 then
				if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
			end
		end
	end
	--actions.finishers+=/templars_verdict,if=(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence.enabled|buff.crusade.up&buff.crusade.stack<10|cooldown.execution_sentence.remains>gcd*2)
	if (conditions_templars_verdict) then
		if ((not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > Player:GCD() * 3) and (not S.ExecutionSentence:IsAvailable() or Player:Buff(S.Crusade) and Player:BuffStack(S.Crusade) >= 10 or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 2)) then
			if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict" end
		end
	end
end

HR.SetAPL(70, APL);

-- Last Update: 21/12/2018

--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/potion
--actions.precombat+=/arcane_torrent,if=!talent.wake_of_ashes.enabled
--
--# Executed every time the actor is available.
--actions=auto_attack
--actions+=/rebuke
--actions+=/call_action_list,name=opener
--actions+=/call_action_list,name=cooldowns
--actions+=/call_action_list,name=generators
--
--actions.cooldowns=use_item,name=ritual_feather_of_unng_ak,if=(buff.avenging_wrath.up|buff.crusade.up)
--actions.cooldowns+=/use_item,name=dooms_fury,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<18
--actions.cooldowns+=/potion,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
--actions.cooldowns+=/lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
--actions.cooldowns+=/fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
--actions.cooldowns+=/shield_of_vengeance
--actions.cooldowns+=/avenging_wrath,if=buff.inquisition.up|!talent.inquisition.enabled
--actions.cooldowns+=/crusade,if=holy_power>=4
--
--actions.finishers=variable,name=ds_castable,value=spell_targets.divine_storm>=2
--actions.finishers+=/inquisition,if=buff.inquisition.down|buff.inquisition.remains<5&holy_power>=3|talent.execution_sentence.enabled&cooldown.execution_sentence.remains<10&buff.inquisition.remains<15|cooldown.avenging_wrath.remains<15&buff.inquisition.remains<20&holy_power>=3
--actions.finishers+=/execution_sentence,if=spell_targets.divine_storm<=2&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)
--actions.finishers+=/divine_storm,if=variable.ds_castable&buff.divine_purpose.react
--actions.finishers+=/divine_storm,if=variable.ds_castable&(!talent.crusade.enabled|cooldown.crusade.remains>gcd*2)|buff.empyrean_power.up&debuff.judgment.down&buff.divine_purpose.down
--actions.finishers+=/templars_verdict,if=buff.divine_purpose.react
--actions.finishers+=/templars_verdict,if=(!talent.crusade.enabled|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence.enabled|buff.crusade.up&buff.crusade.stack<10|cooldown.execution_sentence.remains>gcd*2)
--
--actions.generators=variable,name=HoW,value=(!talent.hammer_of_wrath.enabled|target.health.pct>=20&(buff.avenging_wrath.down|buff.crusade.down))
--actions.generators+=/call_action_list,name=finishers,if=holy_power>=5
--actions.generators+=/wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15|spell_targets.wake_of_ashes>=2)&(holy_power<=0|holy_power=1&cooldown.blade_of_justice.remains>gcd)
--actions.generators+=/blade_of_justice,if=holy_power<=2|(holy_power=3&(cooldown.hammer_of_wrath.remains>gcd*2|variable.HoW))
--actions.generators+=/judgment,if=holy_power<=2|(holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|variable.HoW))
--actions.generators+=/hammer_of_wrath,if=holy_power<=4
--actions.generators+=/consecration,if=holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2
--actions.generators+=/call_action_list,name=finishers,if=talent.hammer_of_wrath.enabled&(target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up)
--actions.generators+=/crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2&cooldown.consecration.remains>gcd*2)
--actions.generators+=/call_action_list,name=finishers
--actions.generators+=/crusader_strike,if=holy_power<=4
--actions.generators+=/arcane_torrent,if=holy_power<=4
--
--actions.opener=sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&talent.execution_sentence.enabled&!talent.hammer_of_wrath.enabled,name=wake_opener_ES_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:execution_sentence
--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&!talent.execution_sentence.enabled&!talent.hammer_of_wrath.enabled,name=wake_opener_CS:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:crusader_strike:templars_verdict
--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&talent.execution_sentence.enabled&talent.hammer_of_wrath.enabled,name=wake_opener_ES_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:execution_sentence
--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.crusade.enabled&!talent.execution_sentence.enabled&talent.hammer_of_wrath.enabled,name=wake_opener_HoW:shield_of_vengeance:blade_of_justice:judgment:crusade:templars_verdict:wake_of_ashes:templars_verdict:hammer_of_wrath:templars_verdict
--actions.opener+=/sequence,if=talent.wake_of_ashes.enabled&talent.inquisition.enabled,name=wake_opener_Inq:shield_of_vengeance:blade_of_justice:judgment:inquisition:avenging_wrath:wake_of_ashes
