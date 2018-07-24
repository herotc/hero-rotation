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
    ArcaneTorrent                 = Spell(25046),
    GiftoftheNaaru                = Spell(59547),
    -- Abilities
    BladeofJustice                = Spell(184575),
    Consecration                  = Spell(205228),
    CrusaderStrike                = Spell(35395),
    DivineHammer                  = Spell(198034),
    DivinePurpose                 = Spell(223817),
    DivinePurposeBuff             = Spell(223819),
    DivineStorm                   = Spell(53385),
    ExecutionSentence             = Spell(213757),
    GreaterJudgment               = Spell(218718),
    HolyWrath                     = Spell(210220),
    Judgment                      = Spell(20271),
    JudgmentDebuff                = Spell(197277),
    JusticarsVengeance            = Spell(215661),
    TemplarsVerdict               = Spell(85256),
    TheFiresofJustice             = Spell(203316),
    TheFiresofJusticeBuff         = Spell(209785),
    Zeal                          = Spell(217020),
    -- Offensive
    AvengingWrath                 = Spell(31884),
    Crusade                       = Spell(231895),
    WakeofAshes                   = Spell(205273),
    -- Defensive
    -- Utility
    HammerofJustice               = Spell(853),
    Rebuke                        = Spell(96231),
    -- Legendaries
    LiadrinsFuryUnleashed         = Spell(208408),
    ScarletInquisitorsExpurgation = Spell(248289);
    WhisperoftheNathrezim         = Spell(207635)
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
local function Judged ()
  return Target:Debuff(S.JudgmentDebuff) or S.Judgment:CooldownRemains() > Player:GCD()*2;
end
local function MythicDungeon ()
  -- Sapped Soul
  if HL.MythicDungeon() == "Sapped Soul" then

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
      if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
        if S.Judgment:IsCastable() then
          if HR.Cast(S.Judgment) then return "Cast Judgment"; end
        elseif Target:IsInRange("Melee") then 
          if S.Zeal:IsCastable() then
            if HR.Cast(S.Zeal) then return "Cast Zeal"; end
          elseif S.CrusaderStrike:IsCastable() then
            if HR.Cast(S.CrusaderStrike) then return "Cast CrusaderStrike"; end
          end
        end
      end
      return;
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
          if HR.Cast(S.Rebuke) then return "Cast"; end
        elseif Settings.General.InterruptWithStun and Target:CanBeStunned() then
          if S.HammerofJustice:IsCastable(10) then
            if HR.Cast(S.HammerofJustice) then return "Cast"; end
          end
        end
      end
      -- actions+=/call_action_list,name=opener,if=time<2&(cooldown.judgment.up|cooldown.blade_of_justice.up|cooldown.divine_hammer.up|cooldown.wake_of_ashes.up)
      if HL.CombatTime() < 2 and (S.Judgment:CooldownUp() or S.BladeofJustice:CooldownUp() or S.DivineHammer:CooldownUp() or S.WakeofAshes:CooldownUp()) then
        -- actions.opener=blood_fury
          -- Not available for Paladin :P
        -- actions.opener+=/berserking
          -- Not available for Paladin :P
        -- actions.opener+=/arcane_torrent
        if S.ArcaneTorrent:IsCastable("Melee") then
          if HR.Cast(S.ArcaneTorrent, Settings.Retribution.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
        end
        -- actions.opener+=/judgment
        if S.Judgment:IsCastable(30) then
          if HR.Cast(S.Judgment) then return "Cast Judgment"; end
        end
        if (I.LiadrinsFuryUnleashed:IsEquipped() or Player:Race() == "BloodElf" or not S.WakeofAshes:CooldownUp()) then
          -- actions.opener+=/blade_of_justice,if=equipped.137048|race.blood_elf|!cooldown.wake_of_ashes.up
          if S.BladeofJustice:IsCastable(S.BladeofJustice) then
            if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
          end
          -- actions.opener+=/divine_hammer,if=equipped.137048|race.blood_elf|!cooldown.wake_of_ashes.up
          if S.DivineHammer:IsCastable(8, true) then
            if HR.Cast(S.DivineHammer) then return "Cast Divine Hammer"; end
          end
        end
        -- actions.opener+=/wake_of_ashes
        if S.WakeofAshes:IsCastable(10) then
          if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
        end
      end
      -- actions+=/call_action_list,name=cooldowns
      if Target:IsInRange("Melee") then
        -- actions.cooldowns+=/use_item
          -- TODO
        -- actions.cooldowns+=/potion,name=old_war,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
          -- TODO
        -- actions.cooldowns+=/blood_fury
          -- Not available for Paladin :P
        -- actions.cooldowns+=/berserking
          -- Not available for Paladin :P
        -- actions.cooldowns+=/arcane_torrent,if=holy_power<=4
        if S.ArcaneTorrent:IsCastable() and Player:HolyPower() <= 4 then
          if HR.Cast(S.ArcaneTorrent, Settings.Retribution.OffGCDasOffGCD.ArcaneTorrent) then return "Cast"; end
        end
        -- actions.cooldowns+=/holy_wrath
        if HR.CDsON() and S.HolyWrath:IsCastable() then
          if HR.Cast(S.HolyWrath, Settings.Retribution.GCDasOffGCD.HolyWrath) then return "Cast Holy Wrath"; end
        end
        -- actions.cooldowns+=/avenging_wrath
        if HR.CDsON() and S.AvengingWrath:IsCastable() then
          if HR.Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "Cast Avenging Wrath"; end
        end
        -- actions.cooldowns+=/crusade,if=holy_power>=5&!equipped.137048|((equipped.137048|race.blood_elf)&holy_power>=2)
        if HR.CDsON() and S.Crusade:IsCastable() and ((Player:HolyPower() >= 5 and not I.LiadrinsFuryUnleashed:IsEquipped()) or ((I.LiadrinsFuryUnleashed:IsEquipped() or Player:Race() == "BloodElf") and Player:HolyPower() >= 2)) then
          if HR.Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.Crusade) then return "Cast Crusade"; end
        end
      end
      -- SoloMode : Justicar's Vengeance
      if Settings.General.SoloMode and S.JusticarsVengeance:IsReady() and Target:IsInRange("Melee") then
        -- Divine Purpose 
        if Player:HealthPercentage() <= Settings.Retribution.SoloJusticarDP and Player:Buff(S.DivinePurposeBuff) then
          if HR.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
        end
        -- Regular
        if Player:HealthPercentage() <= Settings.Retribution.SoloJusticar5HP and Player:HolyPower() >= 5 then
          if HR.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
        end
      end
      -- actions+=/call_action_list,name=priority
        -- actions.priority=execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.5)
        if S.ExecutionSentence:IsReady() and Target:IsInRange(20) and Cache.EnemiesCount[8] <= 3 and (S.Judgment:CooldownRemains() < Player:GCD()*4.5 or Target:DebuffRemains(S.Judgment) > Player:GCD()*4.5) then
          if HR.Cast(S.ExecutionSentence) then return "Cast Execution Sentence"; end
        end
        -- actions.priority+=/variable,name=ds_castable,value=spell_targets.divine_storm>=2|(buff.scarlet_inquisitors_expurgation.stack>=29&(buff.avenging_wrath.up|(buff.crusade.up&buff.crusade.stack>=15)|(cooldown.crusade.remains>15&!buff.crusade.up)|cooldown.avenging_wrath.remains>15))
        local Var_DS_Castable = (Cache.EnemiesCount[8] >= 2 or (Player:BuffStack(S.ScarletInquisitorsExpurgation) >= 29 and (Player:Buff(S.AvengingWrath) or Player:BuffStack(S.Crusade) >= 15 or not HR.CDsON() or (S.Crusade:IsAvailable() and S.Crusade:CooldownRemains() > 15 and not Player:Buff(S.Crusade)) or (not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemains() > 15)))) and HR.AoEON();
        -- actions.priority+=/variable,name=crusade,value=!talent.crusade.enabled|cooldown.crusade.remains>gcd*3
        local Var_Crusade = (not S.Crusade:IsAvailable() or (S.Crusade:CooldownRemains() > Player:GCD() * 3)) and HR.CDsON() or (not HR.CDsON() or Settings.Retribution.OffGCDasOffGCD.Crusade);
        if Judged() then
          if S.DivineStorm:IsReady() then
            if Var_DS_Castable and Player:Buff(S.DivinePurposeBuff) then
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
              if Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD() * 2 then
                if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
              end
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5&buff.divine_purpose.react
              if Player:HolyPower() >= 5 then
                if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
              end
            end
            -- actions.priority+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
            if Cache.EnemiesCount[8] >= 2 and Player:HolyPower() >= 3 and ((Player:Buff(S.Crusade) and Player:BuffStack(S.Crusade) < 15) or Player:Buff(S.LiadrinsFuryUnleashed)) then
              if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
            end
            -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5&variable.crusade
            if Var_DS_Castable and Var_Crusade and Player:HolyPower() >= 5 then
              if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
            end
          end
          if Target:IsInRange("Melee") then
            if S.JusticarsVengeance:IsReady() and Player:Buff(S.DivinePurposeBuff) and not I.WhisperoftheNathrezim:IsEquipped() then
              -- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.137020
              if Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD()*2 then
                if HR.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
              end
              -- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.137020
              if Player:HolyPower() >= 5 then
                if HR.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
              end
            end
            if S.TemplarsVerdict:IsReady() then
              if Player:Buff(S.DivinePurposeBuff) then
                -- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
                if Player:BuffRemains(S.DivinePurposeBuff) < Player:GCD()*2 then
                  if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
                end
                -- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
                if Player:HolyPower() >= 5 then
                  if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
                end
              end
              -- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
              if Player:HolyPower() >= 3 and ((Player:Buff(S.Crusade) and Player:BuffStack(S.Crusade) < 15) or Player:Buff(S.LiadrinsFuryUnleashed)) then
                if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
              end
            end
          end
          if Var_Crusade then
            -- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&variable.crusade
            if S.TemplarsVerdict:IsReady() and Target:IsInRange("Melee") and Player:HolyPower() >= 5 then
              if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
            end
            if Var_DS_Castable and S.DivineStorm:IsReady() then
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2&variable.crusade
              if S.WakeofAshes:IsAvailable() and S.WakeofAshes:CooldownRemains() < Player:GCD()*2 then
                if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
              end
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5&variable.crusade
              if Player:Buff(S.WhisperoftheNathrezim) and Player:BuffRemains(S.WhisperoftheNathrezim) < Player:GCD() * 1.5 then
                if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
              end
            end
          end
        end
        if Var_Crusade and S.TemplarsVerdict:IsReady() and Target:IsInRange("Melee") then
          -- actions.priority+=/templars_verdict,if=(equipped.137020|debuff.judgment.up)&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2&variable.crusade
          if (I.WhisperoftheNathrezim:IsEquipped() or Judged()) and S.WakeofAshes:IsAvailable() and S.WakeofAshes:CooldownRemains() < Player:GCD()*2 then
            if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
          end
          -- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5&variable.crusade
          if Judged() and Player:Buff(S.WhisperoftheNathrezim) and Player:BuffRemains(S.WhisperoftheNathrezim) < Player:GCD() * 1.5 then
            if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
          end
        end
        -- actions.priority+=/judgment,if=dot.execution_sentence.ticking&dot.execution_sentence.remains<gcd*2&debuff.judgment.remains<gcd*2
        if S.Judgment:IsCastable(30) and Target:Debuff(S.ExecutionSentence) and Target:DebuffRemains(S.ExecutionSentence) < Player:GCD() * 2 and Target:DebuffRemains(S.JudgmentDebuff) < Player:GCD() * 2 then
          if HR.Cast(S.Judgment) then return "Cast Judgment"; end
        end
        -- actions.priority+=/consecration,if=(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)
        if HR.AoEON() and S.Consecration:IsCastable(10, true) and (S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or S.DivineHammer:CooldownRemains() > Player:GCD() * 2) then
          if HR.Cast(S.Consecration) then return "Cast Consecration"; end
        end
        -- actions.priority+=/wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15)&(holy_power<=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&((cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)))
        if S.WakeofAshes:IsCastable(10) and (Player:HolyPower() == 0 or (Player:HolyPower() == 1 and (S.BladeofJustice:CooldownRemains() > Player:GCD() or S.DivineHammer:CooldownRemains() > Player:GCD())) or (Player:HolyPower() == 2 and (S.Zeal:ChargesFractional() <= 0.65 or S.CrusaderStrike:ChargesFractional() <= 0.65))) then
          if HR.Cast(S.WakeofAshes) then return "Cast Wake of Ashes"; end
        end
        if Player:HolyPower() <= 3 - (HL.Tier20_2Pc and 1 or 0) then
          -- actions.priority+=/blade_of_justice,if=holy_power<=3-set_bonus.tier20_2pc
          if S.BladeofJustice:IsCastable(S.BladeofJustice) then
            if HR.Cast(S.BladeofJustice) then return "Cast Blade of Justice"; end
          end
          -- actions.priority+=/divine_hammer,if=holy_power<=3-set_bonus.tier20_2pc
          if S.DivineHammer:IsCastable(8, true) then
            if HR.Cast(S.DivineHammer) then return "Cast Divine Hammer"; end
          end
        end
        -- actions.priority+=/hammer_of_justice,if=equipped.137065&target.health.pct>=75&holy_power<=4
        if S.HammerofJustice:IsCastable(10) and I.JusticeGaze:IsEquipped() and Target:HealthPercentage() >= 75 and Player:HolyPower() <= 4 then
          if HR.Cast(S.HammerofJustice) then return "Cast Hammer of Justice"; end
        end
        -- actions.priority+=/judgment
        if S.Judgment:IsCastable(30) then
          if HR.Cast(S.Judgment) then return "Cast Judgment"; end
        end
        if Target:IsInRange("Melee") and Player:HolyPower() <= 4 and (S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or S.DivineHammer:CooldownRemains() > Player:GCD() * 2) and Target:DebuffRemains(S.JudgmentDebuff) < Player:GCD() * 2 then
          -- actions.priority+=/zeal,if=cooldown.zeal.charges_fractional>=1.65&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
          if S.Zeal:IsCastable() and S.Zeal:ChargesFractional() >= 1.65 then
            if HR.Cast(S.Zeal) then return "Cast Zeal"; end
          end
          -- actions.priority+=/crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.65-talent.the_fires_of_justice.enabled*0.25&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
          if S.CrusaderStrike:IsCastable() and S.CrusaderStrike:ChargesFractional() >= 1.65 - (S.TheFiresofJustice:IsAvailable() and 0.25 or 0) then
            if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
          end
        end
        -- actions.priority+=/consecration
        if HR.AoEON() and S.Consecration:IsCastable(10, true) then
          if HR.Cast(S.Consecration) then return "Cast Consecration"; end
        end
        if Judged() then
          if Var_DS_Castable and S.DivineStorm:IsReady() then
            -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.react
            if Player:Buff(S.DivinePurposeBuff) then
              if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
            end
            if Var_Crusade then
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.the_fires_of_justice.react&variable.crusade
              if Player:Buff(S.TheFiresofJusticeBuff) then
                if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
              end
              -- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&variable.crusade
              if HR.Cast(S.DivineStorm) then return "Cast Divine Storm"; end
            end
          end
          if Target:IsInRange("Melee") then
            -- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.137020
            if S.JusticarsVengeance:IsReady() and Player:Buff(S.DivinePurposeBuff) and not I.WhisperoftheNathrezim:IsEquipped() then
              if HR.Cast(S.JusticarsVengeance) then return "Cast Justicars Vengeance"; end
            end
            if S.TemplarsVerdict:IsReady() then
              -- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
              if Player:Buff(S.DivinePurposeBuff) then
                if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
              end
              if Var_Crusade then
                -- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react&variable.crusade
                if Player:Buff(S.TheFiresofJusticeBuff) then
                  if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
                end
                -- actions.priority+=/templars_verdict,if=debuff.judgment.up&variable.crusade&(!talent.execution_sentence.enabled|cooldown.execution_sentence.remains>gcd*2)
                if not S.ExecutionSentence:IsAvailable() or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 2 then
                  if HR.Cast(S.TemplarsVerdict) then return "Cast Templars Verdict"; end
                end
              end
            end
          end
        end
        if Target:IsInRange("Melee") and Player:HolyPower() <= 4 then
          -- actions+=/zeal,if=holy_power<=4
          if S.Zeal:IsCastable() then
            if HR.Cast(S.Zeal) then return "Cast Zeal"; end
          end
          -- actions+=/crusader_strike,if=holy_power<=4
          if S.CrusaderStrike:IsCastable() then
            if HR.Cast(S.CrusaderStrike) then return "Cast Crusader Strike"; end
          end
        end
    end
end

HR.SetAPL(70, APL);

-- Last Update: 06/12/2017

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask,type=flask_of_the_countless_armies
-- actions.precombat+=/food,type=azshari_salad
-- actions.precombat+=/augmentation,type=defiled
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion,name=old_war

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/rebuke
-- actions+=/call_action_list,name=opener,if=time<2&(cooldown.judgment.up|cooldown.blade_of_justice.up|cooldown.divine_hammer.up|cooldown.wake_of_ashes.up)
-- actions+=/call_action_list,name=cooldowns
-- actions+=/call_action_list,name=priority

-- actions.cooldowns=use_item,name=specter_of_betrayal,if=(buff.crusade.up&buff.crusade.stack>=15|cooldown.crusade.remains>gcd*2)|(buff.avenging_wrath.up|cooldown.avenging_wrath.remains>gcd*2)
-- actions.cooldowns+=/use_item,name=vial_of_ceaseless_toxins,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack>=15)|(cooldown.crusade.remains>30&!buff.crusade.up|cooldown.avenging_wrath.remains>30)
-- actions.cooldowns+=/potion,name=old_war,if=(buff.bloodlust.react|buff.avenging_wrath.up|buff.crusade.up&buff.crusade.remains<25|target.time_to_die<=40)
-- actions.cooldowns+=/blood_fury
-- actions.cooldowns+=/berserking
-- actions.cooldowns+=/arcane_torrent,if=holy_power<=4
-- actions.cooldowns+=/holy_wrath
-- actions.cooldowns+=/avenging_wrath
-- actions.cooldowns+=/crusade,if=holy_power>=5&!equipped.137048|((equipped.137048|race.blood_elf)&holy_power>=2)

-- actions.opener=blood_fury
-- actions.opener+=/berserking
-- actions.opener+=/arcane_torrent
-- actions.opener+=/judgment
-- actions.opener+=/blade_of_justice,if=equipped.137048|race.blood_elf|!cooldown.wake_of_ashes.up
-- actions.opener+=/divine_hammer,if=equipped.137048|race.blood_elf|!cooldown.wake_of_ashes.up
-- actions.opener+=/wake_of_ashes

-- actions.priority=execution_sentence,if=spell_targets.divine_storm<=3&(cooldown.judgment.remains<gcd*4.5|debuff.judgment.remains>gcd*4.5)
-- actions.priority+=/variable,name=ds_castable,value=spell_targets.divine_storm>=2|(buff.scarlet_inquisitors_expurgation.stack>=29&(buff.avenging_wrath.up|(buff.crusade.up&buff.crusade.stack>=15)|(cooldown.crusade.remains>15&!buff.crusade.up)|cooldown.avenging_wrath.remains>15))
-- actions.priority+=/variable,name=crusade,value=!talent.crusade.enabled|cooldown.crusade.remains>gcd*3
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5&buff.divine_purpose.react
-- actions.priority+=/divine_storm,if=debuff.judgment.up&spell_targets.divine_storm>=2&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&holy_power>=5&variable.crusade
-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2&!equipped.137020
-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react&!equipped.137020
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.up&buff.divine_purpose.remains<gcd*2
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&buff.divine_purpose.react
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=3&(buff.crusade.up&buff.crusade.stack<15|buff.liadrins_fury_unleashed.up)
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&holy_power>=5&variable.crusade
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2&variable.crusade
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5&variable.crusade
-- actions.priority+=/templars_verdict,if=(equipped.137020|debuff.judgment.up)&artifact.wake_of_ashes.enabled&cooldown.wake_of_ashes.remains<gcd*2&variable.crusade
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.whisper_of_the_nathrezim.up&buff.whisper_of_the_nathrezim.remains<gcd*1.5&variable.crusade
-- actions.priority+=/judgment,if=dot.execution_sentence.ticking&dot.execution_sentence.remains<gcd*2&debuff.judgment.remains<gcd*2
-- actions.priority+=/consecration,if=(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)
-- actions.priority+=/wake_of_ashes,if=(!raid_event.adds.exists|raid_event.adds.in>15)&(holy_power<=0|holy_power=1&(cooldown.blade_of_justice.remains>gcd|cooldown.divine_hammer.remains>gcd)|holy_power=2&((cooldown.zeal.charges_fractional<=0.65|cooldown.crusader_strike.charges_fractional<=0.65)))
-- actions.priority+=/blade_of_justice,if=holy_power<=3-set_bonus.tier20_2pc
-- actions.priority+=/divine_hammer,if=holy_power<=3-set_bonus.tier20_2pc
-- actions.priority+=/hammer_of_justice,if=equipped.137065&target.health.pct>=75&holy_power<=4
-- actions.priority+=/judgment
-- actions.priority+=/zeal,if=cooldown.zeal.charges_fractional>=1.65&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
-- actions.priority+=/crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.65-talent.the_fires_of_justice.enabled*0.25&holy_power<=4&(cooldown.blade_of_justice.remains>gcd*2|cooldown.divine_hammer.remains>gcd*2)&debuff.judgment.remains>gcd
-- actions.priority+=/consecration
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.divine_purpose.react
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&buff.the_fires_of_justice.react&variable.crusade
-- actions.priority+=/divine_storm,if=debuff.judgment.up&variable.ds_castable&variable.crusade
-- actions.priority+=/justicars_vengeance,if=debuff.judgment.up&buff.divine_purpose.react&!equipped.137020
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.divine_purpose.react
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&buff.the_fires_of_justice.react&variable.crusade
-- actions.priority+=/templars_verdict,if=debuff.judgment.up&variable.crusade&(!talent.execution_sentence.enabled|cooldown.execution_sentence.remains>gcd*2)
-- actions.priority+=/zeal,if=holy_power<=4
-- actions.priority+=/crusader_strike,if=holy_power<=4
