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

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Paladin = HR.Commons.Paladin

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Retribution = HR.GUISettings.APL.Paladin.Retribution
}

-- Spells
local S = Spell.Paladin.Retribution

-- Items
local I = Item.Paladin.Retribution
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
}

-- Enemies
local Enemies5y
local Enemies8y
local EnemiesCount8y

-- Rotation Variables
local BossFightRemains = 11111
local FightRemains = 11111
local TimeToHPG
local HolyPower = 0
local PlayerGCD = 0
local VarDSCastable
local VerdictSpell = (S.FinalVerdict:IsLearned()) and S.FinalVerdict or S.TemplarsVerdict

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VerdictSpell = (S.FinalVerdict:IsAvailable()) and S.FinalVerdict or S.TemplarsVerdict
end, "PLAYER_TALENT_UPDATE")

-- Interrupts
local Interrupts = {
  { S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end },
}

--- ======= HELPERS =======
-- time_to_hpg_expr_t @ https://github.com/simulationcraft/simc/blob/shadowlands/engine/class_modules/paladin/sc_paladin.cpp#L3236
local function ComputeTimeToHPG()
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
end

local function MissingAura()
  return (Player:BuffDown(S.RetributionAura) and Player:BuffDown(S.DevotionAura) and Player:BuffDown(S.ConcentrationAura) and Player:BuffDown(S.CrusaderAura))
end

--- ======= ACTION LISTS =======
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- shield_of_vengeance
  if S.ShieldofVengeance:IsCastable() then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance precombat 6"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit
  -- variable,name=trinket_1_manual,value=trinket.1.is.manic_grieftorch
  -- variable,name=trinket_2_manual,value=trinket.2.is.manic_grieftorch
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.1.cooldown.duration=0|trinket.1.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.2.cooldown.duration=0|trinket.2.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- Note: Currently unable to handle some of the above trinket conditions.
  -- Manually added: openers
  if VerdictSpell:IsReady() and HolyPower >= 4 and Target:IsInMeleeRange(5) then
    if Cast(VerdictSpell) then return "either verdict precombat 2" end
  end
  if S.BladeofJustice:IsCastable() then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice precombat 4" end
  end
  if S.Judgment:IsCastable() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 6" end
  end
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath precombat 8" end
  end
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike 10" end
  end
end

local function Cooldowns()
  -- potion,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10|fight_remains<25
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10 or FightRemains < 25) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 2"; end
    end
  end
  -- lights_judgment,if=spell_targets.lights_judgment>=2|!raid_event.adds.exists|raid_event.adds.in>75|raid_event.adds.up
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment cooldowns 4" end
  end
  -- fireblood,if=buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10
  if S.Fireblood:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) == 10) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 6" end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,if=(cooldown.avenging_wrath.remains<5&!talent.crusade|cooldown.crusade.remains<5&talent.crusade)&(holy_power>=5&time<5|holy_power>=3&time>5)
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((S.AvengingWrath:CooldownRemains() < 5 and (not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() < 5 and S.Crusade:IsAvailable()) and (HolyPower >= 5 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() > 5)) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldowns 8"; end
    end
    -- use_item,slot=trinket1,if=(buff.avenging_wrath.up&cooldown.avenging_wrath.remains>40|buff.crusade.up&buff.crusade.stack=10)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    -- use_item,slot=trinket2,if=(buff.avenging_wrath.up&cooldown.avenging_wrath.remains>40|buff.crusade.up&buff.crusade.stack=10)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(!variable.trinket_1_manual|buff.avenging_wrath.down&buff.crusade.down)&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(!variable.trinket_2_manual|buff.avenging_wrath.down&buff.crusade.down)&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    -- Note: Can't handle all of the above trinket conditions, so using a generic use_items instead.
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- shield_of_vengeance,if=fight_remains>15
  if S.ShieldofVengeance:IsCastable() and (FightRemains > 15) then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance cooldowns 10"; end
  end
  -- avenging_wrath,if=holy_power>=4&time<5|holy_power>=3&time>5|holy_power>=2&talent.divine_auxiliary&(cooldown.execution.remains=0|cooldown.final_reckoning.remains=0)
  if S.AvengingWrath:IsCastable() and (HolyPower >= 4 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() > 5 or HolyPower >= 2 and S.DivineAuxiliary:IsAvailable() and (S.ExecutionSentence:CooldownUp() or S.FinalReckoning:CooldownUp())) then
    if Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 12" end
  end
  -- crusade,if=holy_power>=4&time<5|holy_power>=3&time>5
  if S.Crusade:IsCastable() and (HolyPower >= 4 and HL.CombatTime() < 5 or HolyPower >= 3 and HL.CombatTime() >= 5) then
    if Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "crusade cooldowns 14" end
  end
  -- execution_sentence,if=(!buff.crusade.up&cooldown.crusade.remains>10|buff.crusade.stack=10|cooldown.avenging_wrath.remains>10)&(holy_power>=3|holy_power>=2&talent.divine_auxiliary)&target.time_to_die>8
  if S.ExecutionSentence:IsCastable() and ((Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 10 or Player:BuffStack(S.CrusadeBuff) == 1 or S.AvengingWrath:CooldownRemains() > 10) and (HolyPower >= 3 or HolyPower >= 2 and S.DivineAuxiliary:IsAvailable()) and FightRemains > 8) then
    if Cast(S.ExecutionSentence, Settings.Retribution.GCDasOffGCD.ExecutionSentence, nil, not Target:IsSpellInRange(S.ExecutionSentence)) then return "execution_sentence cooldowns 16"; end
  end
  -- final_reckoning,if=(holy_power>=4&time<8|holy_power>=3&time>=8|holy_power>=2&talent.divine_auxiliary)&(cooldown.avenging_wrath.remains>gcd|cooldown.crusade.remains&(!buff.crusade.up|buff.crusade.stack>=10))&(time_to_hpg>0|holy_power=5|holy_power>=2&talent.divine_auxiliary)&(!raid_event.adds.exists|raid_event.adds.up|raid_event.adds.in>40)
  if S.FinalReckoning:IsCastable() and ((HolyPower >= 4 and HL.CombatTime() < 8 or HolyPower >= 3 and HL.CombatTime() >= 8 or HolyPower >= 2 and S.DivineAuxiliary:IsAvailable()) and (S.AvengingWrath:CooldownRemains() > PlayerGCD or S.Crusade:CooldownDown() and (Player:BuffDown(S.CrusadeBuff) or Player:BuffStack(S.CrusadeBuff) >= 10)) and (TimeToHPG > 0 or HolyPower == 5 or HolyPower >= 2 and S.DivineAuxiliary:IsAvailable())) then
    if Cast(S.FinalReckoning, Settings.Retribution.GCDasOffGCD.FinalReckoning, nil, not Target:IsSpellInRange(S.FinalReckoning)) then return "final_reckoning cooldowns 18" end
  end
end

local function Finishers()
  -- variable,name=ds_castable,value=spell_targets.divine_storm>=2|buff.empyrean_power.up
  VarDSCastable = (EnemiesCount8y >= 2 or Player:BuffUp(S.EmpyreanPowerBuff))
  -- divine_storm,if=variable.ds_castable&!buff.empyrean_legacy.up&!(buff.divine_arbiter.up&buff.divine_arbiter.stack>24)&((!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|talent.divine_auxiliary|target.time_to_die<8|cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|talent.divine_auxiliary|cooldown.final_reckoning.remains>gcd*2)|buff.crusade.up&buff.crusade.stack<10)
  if S.DivineStorm:IsReady() and (VarDSCastable and Player:BuffDown(S.EmpyreanLegacyBuff) and (not (Player:BuffUp(S.DivineArbiterBuff) and Player:BuffStack(S.DivineArbiterBuff) > 24)) and (((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > PlayerGCD * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.DivineAuxiliary:IsAvailable() or FightRemains < 8 or S.ExecutionSentence:CooldownRemains() > PlayerGCD * 2) and ((not S.FinalReckoning:IsAvailable()) or S.DivineAuxiliary or S.FinalReckoning:CooldownRemains() > PlayerGCD * 2) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10)) then
    if Cast(S.DivineStorm, nil, nil, not Target:IsInRange(8)) then return "divine_storm finishers 2" end
  end
  -- justicars_vengeance,if=(!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|talent.divine_auxiliary|target.time_to_die<8|cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|talent.divine_auxiliary|cooldown.final_reckoning.remains>gcd*2)|buff.crusade.up&buff.crusade.stack<10
  if S.JusticarsVengeance:IsReady() and (((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > PlayerGCD * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.DivineAuxiliary:IsAvailable() or FightRemains < 8 or S.ExecutionSentence:CooldownRemains() > PlayerGCD * 2) and ((not S.FinalReckoning:IsAvailable()) or S.DivineAuxiliary:IsAvailable() or S.FinalReckoning:CooldownRemains() > PlayerGCD * 2) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    if Cast(S.JusticarsVengeance, nil, nil, not Target:IsInMeleeRange(5)) then return "justicars_vengeance finishers 4"; end
  end
  -- templars_verdict,if=(!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|talent.divine_auxiliary|target.time_to_die<8|cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|talent.divine_auxiliary|cooldown.final_reckoning.remains>gcd*2)|buff.crusade.up&buff.crusade.stack<10
  if VerdictSpell:IsReady() and (((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > PlayerGCD * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.DivineAuxiliary:IsAvailable() or FightRemains < 8 or S.ExecutionSentence:CooldownRemains() > PlayerGCD * 2) and ((not S.FinalReckoning:IsAvailable()) or S.DivineAuxiliary:IsAvailable() or S.FinalReckoning:CooldownRemains() > PlayerGCD * 2) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    if Cast(VerdictSpell, nil, nil, not Target:IsInMeleeRange(5)) then return "either verdict finishers 6" end
  end
end

local function Generators()
  -- call_action_list,name=finishers,if=holy_power=5|(debuff.judgment.up|holy_power=4)&buff.divine_resonance.up
  if (HolyPower >= 5 or (Target:DebuffUp(S.JudgmentDebuff) or HolyPower == 4) and Player:BuffUp(S.DivineResonanceBuff)) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- wake_of_ashes,if=holy_power<=2&(cooldown.avenging_wrath.remains|cooldown.crusade.remains)&(!talent.execution_sentence|cooldown.execution_sentence.remains>4|target.time_to_die<8)&(!raid_event.adds.exists|raid_event.adds.in>20|raid_event.adds.up)
  if S.WakeofAshes:IsCastable() and (HolyPower <= 2 and (S.AvengingWrath:CooldownDown() or S.Crusade:CooldownDown()) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() > 4 or FightRemains < 8)) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInMeleeRange(12)) then return "wake_of_ashes generators 2"; end
  end
  -- divine_toll,if=holy_power<=2&!debuff.judgment.up&(!raid_event.adds.exists|raid_event.adds.in>30|raid_event.adds.up)&(cooldown.avenging_wrath.remains>15|cooldown.crusade.remains>15|fight_remains<8)
  if S.DivineToll:IsCastable() and (HolyPower <= 2 and Target:DebuffDown(S.JudgmentDebuff) and ((not S.Seraphim:IsAvailable()) or Player:BuffUp(S.SeraphimBuff)) and (not S.FinalReckoning:IsAvailable()) and ((not S.ExecutionSentence) or FightRemains < 8 or EnemiesCount8y >= 5) and (S.AvengingWrath:CooldownRemains() > 15 or S.Crusade:CooldownRemains() > 15 or FightRemains < 8)) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll generators 6"; end
  end
  -- call_action_list,name=finishers,if=holy_power>=3&buff.crusade.up&buff.crusade.stack<10
  if (HolyPower >= 3 and Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- templar_slash,if=buff.templar_strikes.remains<gcd&spell_targets.divine_storm>=2
  if S.TemplarSlash:IsReady() and (S.TemplarStrike:TimeSinceLastCast() + PlayerGCD < 4 and EnemiesCount8y >= 2) then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsInMeleeRange(9)) then return "templar_slash generators 8"; end
  end
  -- judgment,if=!debuff.judgment.up&(holy_power<=3|!talent.boundless_judgment)&spell_targets.divine_storm>=2
  if S.Judgment:IsReady() and (Target:DebuffDown(S.JudgmentDebuff) and (HolyPower <= 3 or not S.BoundlessJudgment:IsAvailable()) and EnemiesCount8y >= 2) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 10"; end
  end
  -- blade_of_justice,if=(holy_power<=3|!talent.holy_blade)&spell_targets.divine_storm>=2
  if S.BladeofJustice:IsCastable() and ((HolyPower <= 3 or not S.HolyBlade:IsAvailable()) and EnemiesCount8y >= 2) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 12"; end
  end
  -- hammer_of_wrath,if=(spell_targets.divine_storm<2|!talent.blessed_champion)&(holy_power<=3|target.health.pct>20|!talent.vanguards_momentum)
  if S.HammerofWrath:IsReady() and ((EnemiesCount8y < 2 or not S.BlessedChampion:IsAvailable()) and (HolyPower <= 3 or Target:HealthPercentage() > 20 or not S.VanguardsMomentum:IsAvailable())) then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 14"; end
  end
  -- templar_slash,if=buff.templar_strikes.remains<gcd
  if S.TemplarSlash:IsReady() and (S.TemplarStrike:TimeSinceLastCast() + PlayerGCD < 4) then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsInMeleeRange(9)) then return "templar_slash generators 16"; end
  end
  -- blade_of_justice,if=holy_power<=3|!talent.holy_blade
  if S.BladeofJustice:IsCastable() and (HolyPower <= 3 or not S.HolyBlade:IsAvailable()) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 18"; end
  end
  -- judgment,if=!debuff.judgment.up&(holy_power<=3|!talent.boundless_judgment)
  if S.Judgment:IsReady() and (Target:DebuffDown(S.JudgmentDebuff) and (HolyPower <= 3 or not S.BoundlessJudgment:IsAvailable())) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 20"; end
  end
  -- call_action_list,name=finishers,if=(target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up|buff.empyrean_power.up)
  if (Target:HealthPercentage() <= 20 or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) or Player:BuffUp(S.EmpyreanPowerBuff)) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- consecration,if=!consecration.up&spell_targets.divine_storm>=2
  if S.Consecration:IsCastable() and (Target:DebuffDown(S.ConsecrationDebuff) and EnemiesCount8y >= 2) then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration generators 22"; end
  end
  -- divine_hammer,if=spell_targets.divine_storm>=2
  if S.DivineHammer:IsCastable() and (EnemiesCount8y >= 2) then
    if Cast(S.DivineHammer, nil, nil, not Target:IsInMeleeRange(8)) then return "divine_hammer generators 24"; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2)
  if S.CrusaderStrike:IsCastable() and (S.CrusaderStrike:ChargesFractional() >= 1.75 and (HolyPower <= 2 or HolyPower <= 3 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 or HolyPower == 4 and S.BladeofJustice:CooldownRemains() > PlayerGCD * 2 and S.Judgment:CooldownRemains() > PlayerGCD * 2)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike generators 26"; end
  end
  -- call_action_list,name=finishers
  local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  -- templar_slash
  if S.TemplarSlash:IsReady() then
    if Cast(S.TemplarSlash, nil, nil, not Target:IsInMeleeRange(9)) then return "templar_slash generators 28"; end
  end
  -- templar_strike
  if S.TemplarStrike:IsReady() then
    if Cast(S.TemplarStrike, nil, nil, not Target:IsInMeleeRange(9)) then return "templar_strike generators 30"; end
  end
  -- judgment,if=holy_power<=3|!talent.boundless_judgment
  if S.Judgment:IsReady() and (HolyPower <= 3 or not S.BoundlessJudgment:IsAvailable()) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 32"; end
  end
  -- hammer_of_wrath,if=holy_power<=3|target.health.pct>20|!talent.vanguards_momentum
  if S.HammerofWrath:IsReady() and (HolyPower <= 3 or Target:HealthPercentage() > 20 or not S.VanguardsMomentum:IsAvailable()) then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 34"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike generators 26"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent generators 28"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration generators 30"; end
  end
  -- divine_hammer
  if S.DivineHammer:IsCastable() then
    if Cast(S.DivineHammer, nil, nil, not Target:IsInMeleeRange(8)) then return "divine_hammer generators 32"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Enemies Update
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Divine Storm
    EnemiesCount8y = #Enemies8y
    Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Light's Judgment
  else
    Enemies8y = {}
    EnemiesCount8y = 1
    Enemies5y = {}
  end

  -- Rotation Variables Update
  TimeToHPG = ComputeTimeToHPG()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
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
    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, Interrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=generators
    local ShouldReturn = Generators(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pooling, if nothing else to do
    if Cast(S.Pool) then return "Wait/Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Retribution Paladin rotation is currently a work in progress, but has been updated for patch 10.0.7.")
end

HR.SetAPL(70, APL, OnInit)
