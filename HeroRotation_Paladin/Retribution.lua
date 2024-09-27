--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- Lua
local mathmin = math.min
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Retribution
local I = Item.Paladin.Retribution

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.ShadowedRazingAnnihilator:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Paladin = HR.Commons.Paladin
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  CommonsDS = HR.GUISettings.APL.Paladin.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Paladin.CommonsOGCD,
  Retribution = HR.GUISettings.APL.Paladin.Retribution
}


--- ===== Rotation Variables =====
local BossFightRemains = 11111
local FightRemains = 11111
local TimeToHPG
local HolyPower = 0
local PlayerGCD = 0
local VarDSCastable
local VerdictSpell = (S.FinalVerdict:IsLearned()) and S.FinalVerdict or S.TemplarsVerdict
local Enemies8y, EnemiesCount8y

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  VarTrinket1Buffs = Trinket1:HasUseBuff()
  VarTrinket2Buffs = Trinket2:HasUseBuff()

  VarTrinket1Sync = 0.5
  -- Note: If VarTrinket1CD is 0, set variable to 1 instead to avoid divide by zero errors.
  local T1CD = VarTrinket1CD > 0 and VarTrinket1CD or 1
  if VarTrinket1Buffs and (VarTrinket1CD % 120 == 0 or 120 % T1CD == 0) then
    VarTrinket1Sync = 1
  end

  VarTrinket2Sync = 0.5
  -- Note: If VarTrinket2CD is 0, set variable to 1 instead to avoid divide by zero errors.
  local T2CD = VarTrinket2CD > 0 and VarTrinket2CD or 1
  if VarTrinket2Buffs and (VarTrinket2CD % 120 == 0 or 120 % T2CD == 0) then
    VarTrinket2Sync = 1
  end

  VarTrinketPriority = 1
  local T1BuffDur = Trinket1:BuffDuration() > 0 and Trinket1:BuffDuration() or 1
  local T2BuffDur = Trinket2:BuffDuration() > 0 and Trinket2:BuffDuration() or 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  { S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end },
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VerdictSpell = (S.FinalVerdict:IsLearned()) and S.FinalVerdict or S.TemplarsVerdict
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
local function TemplarStrikesRemains()
  local Remains = 5 - S.TemplarStrike:TimeSinceLastCast()
  if S.TemplarSlash:TimeSinceLastCast() < S.TemplarStrike:TimeSinceLastCast() then
    Remains = 0
  end
  return Remains > 0 and Remains or 0
end
-- time_to_hpg_expr_t @ https://github.com/simulationcraft/simc/blob/shadowlands/engine/class_modules/paladin/sc_paladin.cpp#L3236
--[[local function ComputeTimeToHPG()
  local GCDRemains = Player:GCDRemains()
  local ShortestHPGTime = mathmin(
    S.CrusaderStrike:CooldownRemains(),
    S.BladeofJustice:CooldownRemains(),
    S.Judgment:CooldownRemains(),
    S.HammerofWrath:IsUsable() and S.HammerofWrath:CooldownRemains() or 10, -- if not usable, return a dummy 10
    S.WakeofAshes:CooldownRemains()
  )

  if GCDRemains > ShortestHPGTime then
    return GCDRemains
  end

  return ShortestHPGTime
end]]

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- shield_of_vengeance
  if S.ShieldofVengeance:IsCastable() then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance precombat 2"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.1.cooldown.duration=0|trinket.1.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.2.cooldown.duration=0|trinket.2.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- Note: Moved to SetTrinketVariables().
  -- Manually added: openers
  if VerdictSpell:IsReady() and HolyPower >= 4 and Target:IsSpellInRange(VerdictSpell) then
    if Cast(VerdictSpell, nil, nil, not Target:IsSpellInRange(VerdictSpell)) then return "either verdict precombat 2" end
  end
  if S.BladeofJustice:IsCastable() then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice precombat 4" end
  end
  if S.Judgment:IsCastable() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 6" end
  end
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath precombat 8" end
  end
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsSpellInRange(S.CrusaderStrike)) then return "crusader_strike 10" end
  end
end

local function Cooldowns()
  -- potion,if=buff.avenging_wrath.up|buff.crusade.up|debuff.execution_sentence.up|fight_remains<30
  if Settings.Commons.Enabled.Potions and ((Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff)) or Target:DebuffUp(S.ExecutionSentenceDebuff) or BossFightRemains < 30) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.avenging_wrath.up|buff.crusade.up|debuff.execution_sentence.up
  -- Note: Not handling external buffs
  if CDsON() then
    -- lights_judgment,if=spell_targets.lights_judgment>=2|!raid_event.adds.exists|raid_event.adds.in>75|raid_event.adds.up
    if S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment cooldowns 4" end
    end
    -- fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10|debuff.execution_sentence.up
    if S.Fireblood:IsCastable() and ((Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) or Target:DebuffUp(S.ExecutionSentenceDebuff)) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 6" end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=((buff.avenging_wrath.up&cooldown.avenging_wrath.remains>40|buff.crusade.up&buff.crusade.stack=10)&!talent.radiant_glory|talent.radiant_glory&(!talent.execution_sentence&cooldown.wake_of_ashes.remains=0|debuff.execution_sentence.up))&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1:IsReady() and not VarTrinket1BL and (((Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffUp(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() > 40 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) and not S.RadiantGlory:IsAvailable() or S.RadiantGlory:IsAvailable() and (not S.ExecutionSentence:IsAvailable() and S.WakeofAshes:CooldownUp() or Target:DebuffUp(S.ExecutionSentenceDebuff))) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for trinket1 ("..Trinket1:Name()..") cooldowns 8"; end
    end
    -- use_item,slot=trinket2,if=((buff.avenging_wrath.up&cooldown.avenging_wrath.remains>40|buff.crusade.up&buff.crusade.stack=10)&!talent.radiant_glory|talent.radiant_glory&(!talent.execution_sentence&cooldown.wake_of_ashes.remains=0|debuff.execution_sentence.up))&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2:IsReady() and not VarTrinket2BL and (((Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffUp(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() > 40 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 1) and not S.RadiantGlory:IsAvailable() or S.RadiantGlory:IsAvailable() and (not S.ExecutionSentence:IsAvailable() and S.WakeofAshes:CooldownUp() or Target:DebuffUp(S.ExecutionSentenceDebuff))) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for trinket2 ("..Trinket2:Name()..") cooldowns 8"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs or (Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 20 or Player:BuffDown(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() > 20))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for trinket1 ("..Trinket1:Name()..") cooldowns 10"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs or (Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 20 or Player:BuffDown(S.AvengingWrathBuff) and S.AvengingWrath:CooldownRemains() > 20))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for trinket2 ("..Trinket2:Name()..") cooldowns 12"; end
    end
  end
  -- shield_of_vengeance,if=fight_remains>15&(!talent.execution_sentence|!debuff.execution_sentence.up)
  if S.ShieldofVengeance:IsCastable() and (FightRemains > 15 and (not S.ExecutionSentence:IsAvailable() or Target:DebuffDown(S.ExecutionSentence))) then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance cooldowns 14"; end
  end
  -- execution_sentence,if=(!buff.crusade.up&cooldown.crusade.remains>15|buff.crusade.stack=10|cooldown.avenging_wrath.remains<0.75|cooldown.avenging_wrath.remains>15|talent.radiant_glory)&(holy_power>=4&time<5|holy_power>=3&time>5|holy_power>=2&(talent.divine_auxiliary|talent.radiant_glory))&(target.time_to_die>8&!talent.executioners_will|target.time_to_die>12)&cooldown.wake_of_ashes.remains<gcd
  if S.ExecutionSentence:IsCastable() and ((Settings.Retribution.DisableCrusadeAWCDCheck or Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 15 or Player:BuffStack(S.CrusadeBuff) == 10 or not S.Crusade:IsAvailable() and S.AvengingWrath:CooldownRemains() < 0.75 or S.AvengingWrath:CooldownRemains() > 15 or S.RadiantGlory:IsAvailable()) and (HolyPower >= 4 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() > 5 or HolyPower >= 2 and (S.DivineAuxiliary:IsAvailable() or S.RadiantGlory:IsAvailable())) and (Target:TimeToDie() > 8 and not S.ExecutionersWill:IsAvailable() or Target:TimeToDie() > 12) and S.WakeofAshes:CooldownRemains() < PlayerGCD) then
    if Cast(S.ExecutionSentence, Settings.Retribution.GCDasOffGCD.ExecutionSentence, nil, not Target:IsSpellInRange(S.ExecutionSentence)) then return "execution_sentence cooldowns 16"; end
  end
  -- avenging_wrath,if=(holy_power>=4&time<5|holy_power>=3&time>5|holy_power>=2&talent.divine_auxiliary&(cooldown.execution_sentence.remains=0|cooldown.final_reckoning.remains=0))&(!raid_event.adds.up|target.time_to_die>10)
  if S.AvengingWrath:IsCastable() and ((HolyPower >= 4 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() > 5 or HolyPower >= 2 and S.DivineAuxiliary:IsAvailable() and (S.ExecutionSentence:CooldownUp() or S.FinalReckoning:CooldownUp())) and (EnemiesCount8y == 1 or Target:TimeToDie() > 10)) then
    if Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 18" end
  end
  -- crusade,if=holy_power>=5&time<5|holy_power>=3&time>5
  if S.Crusade:IsCastable() and (HolyPower >= 5 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() >= 5) then
    if Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "crusade cooldowns 20" end
  end
  -- final_reckoning,if=(holy_power>=4&time<8|holy_power>=3&time>=8|holy_power>=2&(talent.divine_auxiliary|talent.radiant_glory))&(cooldown.avenging_wrath.remains>10|cooldown.crusade.remains&(!buff.crusade.up|buff.crusade.stack>=10)|talent.radiant_glory&(buff.avenging_wrath.up|talent.crusade&cooldown.wake_of_ashes.remains<gcd))&(!raid_event.adds.exists|raid_event.adds.up|raid_event.adds.in>40)
  if S.FinalReckoning:IsCastable() and ((HolyPower >= 4 and HL.CombatTime() < 8 or HolyPower >= 3 and HL.CombatTime() >= 8 or HolyPower >= 2 and (S.DivineAuxiliary:IsAvailable() or S.RadiantGlory:IsAvailable())) and (Settings.Retribution.DisableCrusadeAWCDCheck or S.AvengingWrath:CooldownRemains() > 10 or S.Crusade:CooldownDown() and (Player:BuffDown(S.CrusadeBuff) or Player:BuffStack(S.CrusadeBuff) >= 10) or S.RadiantGlory:IsAvailable() and (Player:BuffUp(S.AvengingWrathBuff) or S.Crusade:IsAvailable() and S.WakeofAshes:CooldownRemains() < PlayerGCD))) then
    if Cast(S.FinalReckoning, Settings.Retribution.GCDasOffGCD.FinalReckoning, nil, not Target:IsInRange(30)) then return "final_reckoning cooldowns 22" end
  end
end

local function Finishers()
  -- variable,name=ds_castable,value=(spell_targets.divine_storm>=2|buff.empyrean_power.up|!talent.final_verdict&talent.tempest_of_the_lightbringer)&!buff.empyrean_legacy.up&!(buff.divine_arbiter.up&buff.divine_arbiter.stack>24)
  VarDSCastable = (EnemiesCount8y >= 2 or Player:BuffUp(S.EmpyreanPowerBuff) or not S.FinalVerdict:IsAvailable() and S.TempestoftheLightbringer:IsAvailable()) and Player:BuffDown(S.EmpyreanLegacyBuff) and not (Player:BuffUp(S.DivineArbiterBuff) and Player:BuffStack(S.DivineArbiterBuff) > 24)
  -- hammer_of_light
  if S.HammerofLight:IsReady() then
    if Cast(S.HammerofLight, Settings.Retribution.GCDasOffGCD.WakeOfAshes, nil, not Target:IsInRange(12)) then return "hammer_of_light finishers 2"; end
  end
  -- divine_hammer,if=holy_power=5
  if S.DivineHammer:IsCastable() and (HolyPower == 5) then
    if Cast(S.DivineHammer, nil, nil, not Target:IsInRange(8)) then return "divine_hammer finishers 4"; end
  end
  -- divine_storm,if=variable.ds_castable&!buff.hammer_of_light_ready.up&(!talent.crusade|cooldown.crusade.remains>gcd*3|buff.crusade.up&buff.crusade.stack<10|talent.radiant_glory)&(!buff.divine_hammer.up|cooldown.divine_hammer.remains>110&holy_power>=4)
  if S.DivineStorm:IsReady() and (VarDSCastable and not S.HammerofLight:IsReady() and (Settings.Retribution.DisableCrusadeAWCDCheck or not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > PlayerGCD * 3 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10 or S.RadiantGlory:IsAvailable()) and (not Paladin.DivineHammerActive or S.DivineHammer:CooldownRemains() > 110 and HolyPower >= 4)) then
    if Cast(S.DivineStorm, nil, nil, not Target:IsInRange(8)) then return "divine_storm finishers 6" end
  end
  -- justicars_vengeance,if=(!talent.crusade|cooldown.crusade.remains>gcd*3|buff.crusade.up&buff.crusade.stack<10|talent.radiant_glory)&!buff.hammer_of_light_ready.up&(!buff.divine_hammer.up|cooldown.divine_hammer.remains>110&holy_power>=4)
  if S.JusticarsVengeance:IsReady() and ((Settings.Retribution.DisableCrusadeAWCDCheck or not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > PlayerGCD * 3 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10 or S.RadiantGlory:IsAvailable()) and not S.HammerofLight:IsReady() and (not Paladin.DivineHammerActive or S.DivineHammer:CooldownRemains() > 110 and HolyPower >= 4)) then
    if Cast(S.JusticarsVengeance, nil, nil, not Target:IsSpellInRange(S.JusticarsVengeance)) then return "justicars_vengeance finishers 8"; end
  end
  -- templars_verdict,if=(!talent.crusade|cooldown.crusade.remains>gcd*3|buff.crusade.up&buff.crusade.stack<10|talent.radiant_glory)&!buff.hammer_of_light_ready.up&(!buff.divine_hammer.up|cooldown.divine_hammer.remains>110&holy_power>=4)
  if VerdictSpell:IsReady() and ((Settings.Retribution.DisableCrusadeAWCDCheck or not S.Crusade:IsAvailable() or S.Crusade:CooldownRemains() > PlayerGCD * 3 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10 or S.RadiantGlory:IsAvailable()) and not S.HammerofLight:IsReady() and (not Paladin.DivineHammerActive or S.DivineHammer:CooldownRemains() > 110 and HolyPower >= 4)) then
    if Cast(VerdictSpell, nil, nil, not Target:IsSpellInRange(VerdictSpell)) then return "either verdict finishers 10" end
  end
end

local function Generators()
  -- call_action_list,name=finishers,if=holy_power=5|holy_power=4&buff.divine_resonance.up
  if HolyPower == 5 or HolyPower == 4 and Player:BuffUp(S.DivineResonanceBuff) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- templar_slash,if=buff.templar_strikes.remains<gcd*2
  if S.TemplarSlash:IsReady() and (TemplarStrikesRemains() < PlayerGCD * 2) then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsSpellInRange(S.TemplarSlash)) then return "templar_slash generators 2"; end
  end
  -- blade_of_justice,if=!dot.expurgation.ticking&talent.holy_flames
  if S.BladeofJustice:IsCastable() and (Target:DebuffDown(S.ExpurgationDebuff) and S.HolyFlames:IsAvailable()) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 4"; end
  end
  -- wake_of_ashes,if=(!talent.lights_guidance|holy_power>=2&talent.lights_guidance)&(cooldown.avenging_wrath.remains>6|cooldown.crusade.remains>6|talent.radiant_glory)&(!talent.execution_sentence|cooldown.execution_sentence.remains>4|target.time_to_die<8)&(!raid_event.adds.exists|raid_event.adds.in>10|raid_event.adds.up)
  if S.WakeofAshes:IsCastable() and ((not S.LightsGuidance:IsAvailable() or HolyPower >= 2 and S.LightsGuidance:IsAvailable()) and (Settings.Retribution.DisableCrusadeAWCDCheck or S.AvengingWrath:CooldownRemains() > 6 or S.Crusade:CooldownRemains() > 6 or S.RadiantGlory:IsAvailable()) and (not S.ExecutionSentence:IsAvailable() or S.ExecutionSentence:CooldownRemains() > 4 or FightRemains < 8)) then
    if Cast(S.WakeofAshes, Settings.Retribution.GCDasOffGCD.WakeOfAshes, nil, not Target:IsInRange(14)) then return "wake_of_ashes generators 6"; end
  end
  -- divine_toll,if=holy_power<=2&(!raid_event.adds.exists|raid_event.adds.in>10|raid_event.adds.up)&(cooldown.avenging_wrath.remains>15|cooldown.crusade.remains>15|talent.radiant_glory|fight_remains<8)
  if S.DivineToll:IsCastable() and (HolyPower <= 2 and (Settings.Retribution.DisableCrusadeAWCDCheck or S.AvengingWrath:CooldownRemains() > 15 or S.Crusade:CooldownRemains() > 15 or S.RadiantGlory:IsAvailable() or BossFightRemains < 8)) then
    if Cast(S.DivineToll, nil, Settings.CommonsDS.DisplayStyle.DivineToll, not Target:IsInRange(30)) then return "divine_toll generators 8"; end
  end
  -- call_action_list,name=finishers,if=holy_power>=3&buff.crusade.up&buff.crusade.stack<10
  if HolyPower >= 3 and Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10 then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- templar_slash,if=buff.templar_strikes.remains<gcd&spell_targets.divine_storm>=2
  if S.TemplarSlash:IsReady() and (TemplarStrikesRemains() < PlayerGCD and EnemiesCount8y >= 2) then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsSpellInRange(S.TemplarSlash)) then return "templar_slash generators 10"; end
  end
  -- blade_of_justice,if=(holy_power<=3|!talent.holy_blade)&(spell_targets.divine_storm>=2&talent.blade_of_vengeance)
  if S.BladeofJustice:IsCastable() and ((HolyPower <= 3 or not S.HolyBlade:IsAvailable()) and (EnemiesCount8y >= 2 and S.BladeofVengeance:IsAvailable())) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 12"; end
  end
  -- hammer_of_wrath,if=(spell_targets.divine_storm<2|!talent.blessed_champion)&(holy_power<=3|target.health.pct>20|!talent.vanguards_momentum)&(target.health.pct<35&talent.vengeful_wrath|buff.blessing_of_anshe.up)
  if S.HammerofWrath:IsReady() and ((EnemiesCount8y < 2 or not S.BlessedChampion:IsAvailable()) and (HolyPower <= 3 or Target:HealthPercentage() > 20 or not S.VanguardsMomentum:IsAvailable()) and (Target:HealthPercentage() < 35 and S.VengefulWrath:IsAvailable() or Player:BuffUp(S.BlessingofAnsheRetBuff))) then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 14"; end
  end
  -- templar_strike
  if S.TemplarStrike:IsCastable() then
    if Cast(S.TemplarStrike, nil, nil, not Target:IsSpellInRange(S.TemplarStrike)) then return "templar_strike generators 16"; end
  end
  -- judgment,if=holy_power<=3|!talent.boundless_judgment
  if S.Judgment:IsCastable() and (HolyPower <= 3 or not S.BoundlessJudgment:IsAvailable()) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 18"; end
  end
  -- blade_of_justice,if=holy_power<=3|!talent.holy_blade
  if S.BladeofJustice:IsCastable() and (HolyPower <= 3 or not S.HolyBlade:IsAvailable()) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 20"; end
  end
  -- hammer_of_wrath,if=(spell_targets.divine_storm<2|!talent.blessed_champion)&(holy_power<=3|target.health.pct>20|!talent.vanguards_momentum)
  if S.HammerofWrath:IsReady() and ((EnemiesCount8y < 2 or not S.BlessedChampion:IsAvailable()) and (HolyPower <= 3 or Target:HealthPercentage() > 20 or not S.VanguardsMomentum:IsAvailable())) then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 22"; end
  end
  -- templar_slash
  if S.TemplarSlash:IsReady() then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsSpellInRange(S.TemplarSlash)) then return "templar_slash generators 24"; end
  end
  -- call_action_list,name=finishers,if=(target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up|buff.empyrean_power.up)
  if Target:HealthPercentage() <= 20 or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) or Player:BuffUp(S.EmpyreanPowerBuff) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2)
  if S.CrusaderStrike:IsCastable() and (S.CrusaderStrike:ChargesFractional() >= 1.75 and (HolyPower <= 2 or HolyPower <= 3 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 or HolyPower == 4 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 and S.Judgment:CooldownRemains() > PlayerGCD * 2)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsSpellInRange(S.CrusaderStrike)) then return "crusader_strike generators 26"; end
  end
  -- call_action_list,name=finishers
  local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  -- hammer_of_wrath,if=holy_power<=3|target.health.pct>20|!talent.vanguards_momentum
  if S.HammerofWrath:IsReady() and (HolyPower <= 3 or Target:HealthPercentage() > 20 or not S.VanguardsMomentum:IsAvailable()) then
    if Cast(S.HammerofWrath, Settings.CommonsOGCD.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 28"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsSpellInRange(S.CrusaderStrike)) then return "crusader_strike generators 30"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent generators 32"; end
  end
end

--- ===== APL Main =====
local function APL()
  -- Enemies Update
  Enemies8y = Player:GetEnemiesInRange(8) -- Divine Storm
  if AoEON() then
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end

    -- We check Player:GCD() and Player:HolyPower() a lot, so let's put them in variables
    PlayerGCD = Player:GCD()
    HolyPower = Player:HolyPower()
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- rebuke
    local ShouldReturn = Everyone.Interrupt(S.Rebuke, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    -- Note: Checking CDsON within the function, as potion and trinket usage is also included, but shouldn't be tied to CDsON.
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=generators
    local ShouldReturn = Generators(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pooling, if nothing else to do
    if Cast(S.Pool) then return "Wait/Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Retribution Paladin rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(70, APL, OnInit)
