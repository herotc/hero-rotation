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
  -- retribution_aura
  if S.RetributionAura:IsCastable() and (MissingAura()) then
    if Cast(S.RetributionAura) then return "retribution_aura precombat 2"; end
  end
  -- arcane_torrent,if=talent.final_reckoning&talent.seraphim
  if S.ArcaneTorrent:IsCastable() and Target:IsInRange(8) and (S.FinalReckoning:IsAvailable() and S.Seraphim:IsAvailable()) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent precombat 4"; end
  end
  -- shield_of_vengeance
  if S.ShieldofVengeance:IsCastable() then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance precombat 6"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.1.cooldown.duration=0|trinket.1.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.crusade.duration=0|cooldown.crusade.duration%%trinket.2.cooldown.duration=0|trinket.2.cooldown.duration%%cooldown.avenging_wrath.duration=0|cooldown.avenging_wrath.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- Note: Currently unable to handle some of the above trinket conditions.
  -- Manually added: openers
  if Player:HolyPower() >= 4 and Target:IsInMeleeRange(5) then
    if S.DivineStorm:IsReady() and EnemiesCount8y >= 2 then
      if Cast(S.DivineStorm) then return "divine_storm precombat 8" end
    end
    if VerdictSpell:IsReady() and EnemiesCount8y < 2 and Target:IsInMeleeRange(5) then
      if Cast(VerdictSpell) then return "either verdict precombat 10" end
    end
  end
  if S.BladeofJustice:IsCastable() then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice precombat 12" end
  end
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath precombat 14" end
  end
  if S.Judgment:IsCastable() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 16" end
  end
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike 18" end
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
  -- fireblood,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10)&!talent.execution_sentence
  if S.Fireblood:IsCastable() and ((Player:BuffUp(S.AvengingWrathBuff) or (Player:BuffUp(S.Crusade) and Player:BuffStack(S.Crusade) == 10)) and not S.ExecutionSentence:IsAvailable()) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 6" end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=algethar_puzzle_box,if=(cooldown.avenging_wrath.remains<5&!talent.crusade|cooldown.crusade.remains<5&talent.crusade)&(holy_power>=5&time<5|holy_power>=3&time>5)
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((S.AvengingWrath:CooldownRemains() < 5 and (not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() < 5 and S.Crusade:IsAvailable()) and (Player:HolyPower() >= 5 and HL.CombatTime() < 5 or Player:HolyPower() >= 3 and HL.CombatTime() > 5)) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldowns 8"; end
    end
    -- use_item,slot=trinket1,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    -- use_item,slot=trinket2,if=(buff.avenging_wrath.up|buff.crusade.up&buff.crusade.stack=10)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|!buff.crusade.up&cooldown.crusade.remains>20|!buff.avenging_wrath.up&cooldown.avenging_wrath.remains>20)
    -- Note: Can't handle all of the above trinket conditions, so using a generic use_items instead.
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- shield_of_vengeance,if=(!talent.execution_sentence|cooldown.execution_sentence.remains<52)&fight_remains>15
  if S.ShieldofVengeance:IsCastable() and (((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() < 52) and FightRemains > 15) then
    if Cast(S.ShieldofVengeance, Settings.Retribution.GCDasOffGCD.ShieldOfVengeance) then return "shield_of_vengeance cooldowns 10"; end
  end
  -- avenging_wrath,if=((holy_power>=4&time<5|holy_power>=3&time>5)|talent.holy_avenger&cooldown.holy_avenger.remains=0)&(!talent.seraphim|!talent.final_reckoning|cooldown.seraphim.remains>0)
  if S.AvengingWrath:IsCastable() and (((Player:HolyPower() >= 4 and HL.CombatTime() < 5 or Player:HolyPower() >= 3 and HL.CombatTime() > 5) or S.HolyAvenger:IsAvailable() and S.HolyAvenger:CooldownUp()) and ((not S.Seraphim:IsAvailable()) or (not S.FinalReckoning:IsAvailable()) or S.Seraphim:CooldownDown())) then
    if Cast(S.AvengingWrath, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 12" end
  end
  -- crusade,if=holy_power>=4&time<5|holy_power>=3&time>5
  if S.Crusade:IsCastable() and (Player:HolyPower() >= 4 and HL.CombatTime() < 5 or Player:HolyPower() >= 3 and HL.CombatTime() >= 5) then
    if Cast(S.Crusade, Settings.Retribution.OffGCDasOffGCD.AvengingWrath) then return "crusade cooldowns 14" end
  end
  -- holy_avenger,if=time_to_hpg=0&holy_power<=2&(buff.avenging_wrath.up|talent.crusade&(cooldown.crusade.remains=0|buff.crusade.up)|fight_remains<20)
  if S.HolyAvenger:IsCastable() and (TimeToHPG <= Player:GCDRemains() and Player:HolyPower() <= 2 and (Player:BuffUp(S.AvengingWrath) or S.Crusade:IsAvailable() and (S.Crusade:CooldownUp() or Player:BuffUp(S.CrusadeBuff)) or FightRemains < 20)) then
    if Cast(S.HolyAvenger) then return "holy_avenger cooldowns 16" end
  end
  -- final_reckoning,if=(holy_power>=4&time<8|holy_power>=3&time>=8)&(cooldown.avenging_wrath.remains>gcd|cooldown.crusade.remains&(!buff.crusade.up|buff.crusade.stack>=10))&(time_to_hpg>0|holy_power=5)&(!talent.seraphim|buff.seraphim.up)&(!raid_event.adds.exists|raid_event.adds.up|raid_event.adds.in>40)&(!buff.avenging_wrath.up|holy_power=5|cooldown.hammer_of_wrath.remains)
  if S.FinalReckoning:IsCastable() and ((Player:HolyPower() >= 4 and HL.CombatTime() < 8 or Player:HolyPower() >= 3 and HL.CombatTime() >= 8) and (S.AvengingWrath:CooldownRemains() > Player:GCD() or S.Crusade:CooldownDown() and (Player:BuffDown(S.CrusadeBuff) or Player:BuffStack(S.CrusadeBuff) >= 10)) and (TimeToHPG > 0 or Player:HolyPower() == 5) and ((not S.Seraphim:IsAvailable()) or Player:BuffUp(S.Seraphim)) and (Player:BuffDown(S.AvengingWrathBuff) or Player:HolyPower() == 5 or S.HammerofWrath:CooldownDown())) then
    if Cast(S.FinalReckoning) then return "final_reckoning cooldowns 18" end
  end
end

local function Finishers()
  -- variable,name=ds_castable,value=spell_targets.divine_storm>=2|buff.empyrean_power.up&!debuff.judgment.up&!buff.divine_purpose.up|buff.crusade.up&buff.crusade.stack<10&buff.empyrean_legacy.up&!talent.justicars_vengeance
  VarDSCastable = (EnemiesCount8y >= 2 and AoEON() or Player:BuffUp(S.EmpyreanPowerBuff) and Target:DebuffDown(S.JudgmentDebuff) and Player:BuffDown(S.DivinePurposeBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10 and Player:BuffUp(S.EmpyreanLegacyBuff) and not S.JusticarsVengeance:IsAvailable())
  -- seraphim,if=(cooldown.avenging_wrath.remains>15|cooldown.crusade.remains>15)&!talent.final_reckoning&(!talent.execution_sentence|spell_targets.divine_storm>=5)&(!raid_event.adds.exists|raid_event.adds.in>40|raid_event.adds.in<gcd|raid_event.adds.up)|fight_remains<15&fight_remains>5|buff.crusade.up&buff.crusade.stack<10
  if S.Seraphim:IsReady() and ((S.AvengingWrath:CooldownRemains() > 15 or S.Crusade:CooldownRemains() > 15) and (not S.FinalReckoning:IsAvailable()) and ((not S.ExecutionSentence:IsAvailable()) or EnemiesCount8y >= 5) or FightRemains < 15 and FightRemains > 5 or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    if Cast(S.Seraphim, Settings.Retribution.GCDasOffGCD.Seraphim) then return "seraphim finishers 2" end
  end
  -- execution_sentence,if=(buff.crusade.down&cooldown.crusade.remains>10|buff.crusade.stack>=3|cooldown.avenging_wrath.remains>10)&(!talent.final_reckoning|cooldown.final_reckoning.remains>10)&target.time_to_die>8&(spell_targets.divine_storm<5|talent.executioners_wrath)
  if S.ExecutionSentence:IsReady() and ((Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 10 or Player:BuffStack(S.CrusadeBuff) >= 3 or S.AvengingWrath:CooldownRemains() > 10) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > 10) and Target:TimeToDie() > 8 and (EnemiesCount8y < 5 or S.ExecutionersWrath:IsAvailable())) then
    if Cast(S.ExecutionSentence, Settings.Retribution.GCDasOffGCD.ExecutionSentence, nil, not Target:IsSpellInRange(S.ExecutionSentence)) then return "execution_sentence finishers 4" end
  end
  -- radiant_decree,if=(buff.crusade.down&cooldown.crusade.remains>5|buff.crusade.stack>=3|cooldown.avenging_wrath.remains>5)&(!talent.final_reckoning|cooldown.final_reckoning.remains>5)
  if S.RadiantDecree:IsReady() and ((Player:BuffDown(S.CrusadeBuff) and S.Crusade:CooldownRemains() > 5 or Player:BuffStack(S.CrusadeBuff) >= 3 or S.AvengingWrath:CooldownRemains() > 5) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > 5)) then
    if Cast(S.RadiantDecree, nil, nil, not Target:IsInMeleeRange(12)) then return "radiant_decree finishers 6"; end
  end
  -- divine_storm,if=variable.ds_castable&(!buff.empyrean_legacy.up|buff.crusade.up&buff.crusade.stack<10)&((!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|cooldown.execution_sentence.remains>gcd*6|cooldown.execution_sentence.remains>gcd*4&holy_power>=4|target.time_to_die<8|spell_targets.divine_storm>=5|!talent.seraphim&cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|cooldown.final_reckoning.remains>gcd*6|cooldown.final_reckoning.remains>gcd*4&holy_power>=4|!talent.seraphim&cooldown.final_reckoning.remains>gcd*2)|talent.holy_avenger&cooldown.holy_avenger.remains<gcd*3|buff.holy_avenger.up|buff.crusade.up&buff.crusade.stack<10)
  if S.DivineStorm:IsReady() and (VarDSCastable and (Player:BuffDown(S.EmpyreanLegacyBuff) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) and (((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > Player:GCD() * 3) and ((not S.ExecutionSentence) or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 6 or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or Target:TimeToDie() < 8 or EnemiesCount8y >= 5 or (not S.Seraphim:IsAvailable()) and S.ExecutionSentence:CooldownRemains() > Player:GCD() * 2) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > Player:GCD() * 6 or S.FinalReckoning:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or (not S.Seraphim:IsAvailable()) and S.FinalReckoning:CooldownRemains() > Player:GCD() * 2) or S.HolyAvenger:IsAvailable() and S.HolyAvenger:CooldownRemains() < Player:GCD() * 3 or Player:BuffUp(S.HolyAvenger) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10)) then
    if Cast(S.DivineStorm, nil, nil, not Target:IsInRange(8)) then return "divine_storm finishers 8" end
  end
  -- justicars_vengeance,if=((!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|cooldown.execution_sentence.remains>gcd*6|cooldown.execution_sentence.remains>gcd*4&holy_power>=4|target.time_to_die<8|!talent.seraphim&cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|cooldown.final_reckoning.remains>gcd*6|cooldown.final_reckoning.remains>gcd*4&holy_power>=4|!talent.seraphim&cooldown.final_reckoning.remains>gcd*2)|talent.holy_avenger&cooldown.holy_avenger.remains<gcd*3|buff.holy_avenger.up|buff.crusade.up&buff.crusade.stack<10)&!buff.empyrean_legacy.up
  if S.JusticarsVengeance:IsReady() and ((((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > Player:GCD() * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 6 or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or Target:TimeToDie() < 8 or (not S.Seraphim:IsAvailable()) and S.ExecutionSentence:CooldownRemains() > Player:GCD() * 2) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > Player:GCD() * 6 or S.FinalReckoning:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or (not S.Seraphim:IsAvailable()) and S.FinalReckoning:CooldownRemains() > Player:GCD() * 2) or S.HolyAvenger:IsAvailable() and S.HolyAvenger:CooldownRemains() < Player:GCD() * 3 or Player:BuffUp(S.HolyAvenger) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) and Player:BuffDown(S.EmpyreanLegacyBuff)) then
    if Cast(S.JusticarsVengeance, nil, nil, not Target:IsInMeleeRange(5)) then return "justicars_vengeance finishers 10"; end
  end
  -- templars_verdict,if=(!talent.crusade|cooldown.crusade.remains>gcd*3)&(!talent.execution_sentence|cooldown.execution_sentence.remains>gcd*6|cooldown.execution_sentence.remains>gcd*4&holy_power>=4|target.time_to_die<8|!talent.seraphim&cooldown.execution_sentence.remains>gcd*2)&(!talent.final_reckoning|cooldown.final_reckoning.remains>gcd*6|cooldown.final_reckoning.remains>gcd*4&holy_power>=4|!talent.seraphim&cooldown.final_reckoning.remains>gcd*2)|talent.holy_avenger&cooldown.holy_avenger.remains<gcd*3|buff.holy_avenger.up|buff.crusade.up&buff.crusade.stack<10
  if VerdictSpell:IsReady() and (((not S.Crusade:IsAvailable()) or S.Crusade:CooldownRemains() > Player:GCD() * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 6 or S.ExecutionSentence:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or Target:TimeToDie() < 8 or (not S.Seraphim:IsAvailable()) and S.ExecutionSentence:CooldownRemains() > Player:GCD() * 2) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > Player:GCD() * 6 or S.FinalReckoning:CooldownRemains() > Player:GCD() * 4 and Player:HolyPower() >= 4 or (not S.Seraphim:IsAvailable()) and S.FinalReckoning:CooldownRemains() > Player:GCD() * 2) or S.HolyAvenger:IsAvailable() and S.HolyAvenger:CooldownRemains() < Player:GCD() * 3 or Player:BuffUp(S.HolyAvenger) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    if Cast(VerdictSpell, nil, nil, not Target:IsInMeleeRange(5)) then return "either verdict finishers 12" end
  end
end

local function Generators()
  -- call_action_list,name=finishers,if=holy_power=5|(debuff.judgment.up|holy_power=4)&buff.divine_resonance.up|buff.holy_avenger.up
  if (Player:HolyPower() >= 5 or (Target:DebuffUp(S.JudgmentDebuff) or Player:HolyPower() == 4) and Player:BuffUp(S.DivineResonanceBuff) or Player:BuffUp(S.HolyAvenger)) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- hammer_of_wrath,if=talent.zealots_paragon
  if S.HammerofWrath:IsReady() and (S.ZealotsParagon:IsAvailable()) then
    if Cast(S.HammerofWrath, nil, Settings.Commons.GCDasOffGCD.HammerOfWrath, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 2"; end
  end
  -- wake_of_ashes,if=holy_power<=2&talent.ashes_to_dust&(cooldown.avenging_wrath.remains|cooldown.crusade.remains)
  if S.WakeofAshes:IsCastable() and (Player:HolyPower() <= 2 and S.AshestoDust:IsAvailable() and (S.AvengingWrath:CooldownDown() or S.Crusade:CooldownDown())) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInRange(12)) then return "wake_of_ashes generators 4"; end
  end
  -- divine_toll,if=holy_power<=2&!debuff.judgment.up&(!talent.seraphim|buff.seraphim.up)&(!raid_event.adds.exists|raid_event.adds.in>30|raid_event.adds.up)&!talent.final_reckoning&(!talent.execution_sentence|fight_remains<8|spell_targets.divine_storm>=5)&(cooldown.avenging_wrath.remains>15|cooldown.crusade.remains>15|fight_remains<8)
  if S.DivineToll:IsCastable() and (Player:HolyPower() <= 2 and Target:DebuffDown(S.JudgmentDebuff) and ((not S.Seraphim:IsAvailable()) or Player:BuffUp(S.SeraphimBuff)) and (not S.FinalReckoning:IsAvailable()) and ((not S.ExecutionSentence) or FightRemains < 8 or EnemiesCount8y >= 5) and (S.AvengingWrath:CooldownRemains() > 15 or S.Crusade:CooldownRemains() > 15 or FightRemains < 8)) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll generators 6"; end
  end
  -- judgment,if=!debuff.judgment.up&holy_power>=2
  if S.Judgment:IsCastable() and (Target:DebuffDown(S.JudgmentDebuff) and Player:HolyPower() >= 2) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 8"; end
  end
  -- wake_of_ashes,if=(holy_power=0|holy_power<=2&cooldown.blade_of_justice.remains>gcd*2)&(!raid_event.adds.exists|raid_event.adds.in>20|raid_event.adds.up)&(!talent.seraphim|cooldown.seraphim.remains>5)&(!talent.execution_sentence|cooldown.execution_sentence.remains>15|target.time_to_die<8|spell_targets.divine_storm>=5)&(!talent.final_reckoning|cooldown.final_reckoning.remains>15|fight_remains<8)&(cooldown.avenging_wrath.remains|cooldown.crusade.remains)
  if S.WakeofAshes:IsCastable() and ((Player:HolyPower() == 0 or Player:HolyPower() <= 2 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2) and ((not S.Seraphim:IsAvailable()) or S.Seraphim:CooldownRemains() > 5) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() > 15 or Target:TimeToDie() < 8 or EnemiesCount8y >= 5) and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() > 15 or FightRemains < 8) and (S.AvengingWrath:CooldownDown() or S.Crusade:CooldownDown())) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInRange(12)) then return "wake_of_ashes generators 10"; end
  end
  -- call_action_list,name=finishers,if=holy_power>=3&buff.crusade.up&buff.crusade.stack<10
  if (Player:HolyPower() >= 3 and Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- exorcism
  if S.Exorcism:IsCastable() then
    if Cast(S.Exorcism, nil, nil, not Target:IsSpellInRange(S.Exorcism)) then return "exorcism generators 12"; end
  end
  -- judgment,if=!debuff.judgment.up
  if S.Judgment:IsCastable() and (Target:DebuffDown(S.JudgmentDebuff)) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment generators 14"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath generators 16"; end
  end
  -- blade_of_justice,if=holy_power<=3
  if S.BladeofJustice:IsCastable() and (Player:HolyPower() <= 3) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice generators 18"; end
  end
  -- call_action_list,name=finishers,if=(target.health.pct<=20|buff.avenging_wrath.up|buff.crusade.up|buff.empyrean_power.up)
  if (Target:HealthPercentage() <= 20 or Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.CrusadeBuff) or Player:BuffUp(S.EmpyreanPowerBuff)) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- consecration,if=!consecration.up&spell_targets.divine_storm>=2
  if S.Consecration:IsCastable() and (Target:DebuffDown(S.ConsecrationDebuff) and EnemiesCount8y >= 2) then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration generators 20"; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2)
  if S.CrusaderStrike:IsCastable() and (S.CrusaderStrike:ChargesFractional() >= 1.75 and (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 and S.Judgment:CooldownRemains() > Player:GCD() * 2)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike generators 22"; end
  end
  -- call_action_list,name=finishers
  local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Target:DebuffDown(S.ConsecrationDebuff)) then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration generators 24"; end
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
end

local function ESFRActive()
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood es_fr_active 2"; end
  end
  -- call_action_list,name=finishers,if=holy_power=5|debuff.judgment.up|debuff.final_reckoning.up&(debuff.final_reckoning.remains<gcd.max|spell_targets.divine_storm>=2&!talent.execution_sentence)|debuff.execution_sentence.up&debuff.execution_sentence.remains<gcd.max
  if (Player:HolyPower() == 5 or Target:DebuffUp(S.JudgmentDebuff) or Target:DebuffUp(S.FinalReckoning) and (Target:DebuffRemains(S.FinalReckoning) < Player:GCD() + 0.5 or EnemiesCount8y >= 2 and not S.ExecutionSentence:IsAvailable()) or Target:DebuffUp(S.ExecutionSentence) and Target:DebuffRemains(S.ExecutionSentence) < Player:GCD() + 0.5) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- divine_toll,if=holy_power<=2
  if S.DivineToll:IsCastable() and (Player:HolyPower() <= 2) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll es_fr_active 4"; end
  end
  -- wake_of_ashes,if=holy_power<=2&(debuff.final_reckoning.up&debuff.final_reckoning.remains<gcd*2&!talent.divine_resonance|debuff.execution_sentence.up&debuff.execution_sentence.remains<gcd|spell_targets.divine_storm>=5&talent.divine_resonance&talent.execution_sentence)
  if S.WakeofAshes:IsCastable() and (Player:HolyPower() <= 2 and (Target:DebuffUp(S.FinalReckoning) and Target:DebuffRemains(S.FinalReckoning) < Player:GCD() * 2 and (not S.DivineResonance:IsAvailable()) or Target:DebuffUp(S.ExecutionSentence) and Target:DebuffRemains(S.ExecutionSentence) < Player:GCD() or EnemiesCount8y >= 5 and S.DivineResonance:IsAvailable() and S.ExecutionSentence:IsAvailable())) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInRange(12)) then return "wake_of_ashes es_fr_active 6"; end
  end
  -- blade_of_justice,if=talent.expurgation&(!talent.divine_resonance&holy_power<=3|holy_power<=2)
  if S.BladeofJustice:IsCastable() and (S.Expurgation:ConduitEnabled() and ((not S.DivineResonance:IsAvailable()) and Player:HolyPower() <= 3 or Player:HolyPower() <= 2)) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice es_fr_active 8"; end
  end
  -- judgment,if=!debuff.judgment.up&holy_power>=2
  if S.Judgment:IsCastable() and (Target:DebuffDown(S.JudgmentDebuff) and Player:HolyPower() >= 2) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment es_fr_active 10"; end
  end
  -- call_action_list,name=finishers
  local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  -- wake_of_ashes,if=holy_power<=2
  if S.WakeofAshes:IsCastable() and (Player:HolyPower() <= 2) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInRange(12)) then return "wake_of_ashes es_fr_active 12"; end
  end
  -- blade_of_justice,if=holy_power<=3
  if S.BladeofJustice:IsCastable() and (Player:HolyPower() <= 3) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice es_fr_active 14"; end
  end
  -- judgment,if=!debuff.judgment.up
  if S.Judgment:IsCastable() and (Target:DebuffDown(S.Judgment)) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment es_fr_active 16"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath es_fr_active 18"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike es_fr_active 20"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent es_fr_active 22"; end
  end
  -- exorcism
  if S.Exorcism:IsCastable() then
    if Cast(S.Exorcism, nil, nil, not Target:IsSpellInRange(S.Exorcism)) then return "exorcism es_fr_active 24"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration es_fr_active 26"; end
  end
end

local function ESFRPooling()
  -- seraphim,if=holy_power=5&(!talent.final_reckoning|cooldown.final_reckoning.remains<=gcd*3)&(!talent.execution_sentence|cooldown.execution_sentence.remains<=gcd*3|talent.final_reckoning)
  if S.Seraphim:IsReady() and (Player:HolyPower() == 5 and ((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() <= Player:GCD() * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() <= Player:GCD() * 3 or S.FinalReckoning:IsAvailable())) then
    if Cast(S.Seraphim, Settings.Retribution.GCDasOffGCD.Seraphim) then return "seraphim es_fr_pooling 2"; end
  end
  -- call_action_list,name=finishers,if=holy_power=5|debuff.final_reckoning.up|buff.crusade.up&buff.crusade.stack<10
  if (Player:HolyPower() == 5 or Target:DebuffUp(S.FinalReckoning) or Player:BuffUp(S.CrusadeBuff) and Player:BuffStack(S.CrusadeBuff) < 10) then
    local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  end
  -- hammer_of_wrath,if=talent.vanguards_momentum
  if S.HammerofWrath:IsReady() and (S.VanguardsMomentum:IsAvailable()) then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath es_fr_pooling 4"; end
  end
  -- wake_of_ashes,if=holy_power<=2&talent.ashes_to_dust&(cooldown.crusade.remains|cooldown.avenging_wrath.remains)
  if S.WakeofAshes:IsCastable() and (Player:HolyPower() <=2 and S.AshestoDust:IsAvailable() and (S.Crusade:CooldownDown() or S.AvengingWrath:CooldownDown())) then
    if Cast(S.WakeofAshes, nil, nil, not Target:IsInRange(12)) then return "wake_of_ashes es_fr_pooling 6"; end
  end
  -- blade_of_justice,if=holy_power<=3
  if S.BladeofJustice:IsCastable() and (Player:HolyPower() <= 3) then
    if Cast(S.BladeofJustice, nil, nil, not Target:IsSpellInRange(S.BladeofJustice)) then return "blade_of_justice es_fr_pooling 8"; end
  end
  -- judgment,if=!debuff.judgment.up
  if S.Judgment:IsCastable() and (Target:DebuffDown(S.JudgmentDebuff)) then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment es_fr_pooling 10"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Commons.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath es_fr_pooling 12"; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges_fractional>=1.75&(holy_power<=2|holy_power<=3&cooldown.blade_of_justice.remains>gcd*2|holy_power=4&cooldown.blade_of_justice.remains>gcd*2&cooldown.judgment.remains>gcd*2)
  if S.CrusaderStrike:IsCastable() and (S.CrusaderStrike:ChargesFractional() >= 1.75 and (Player:HolyPower() <= 2 or Player:HolyPower() <= 3 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 or Player:HolyPower() == 4 and S.BladeofJustice:CooldownRemains() > Player:GCD() * 2 and S.Judgment:CooldownRemains() > Player:GCD() * 2)) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike es_fr_pooling 14"; end
  end
  -- seraphim,if=!talent.final_reckoning&cooldown.execution_sentence.remains<=gcd*3
  if S.Seraphim:IsReady() and ((not S.FinalReckoning:IsAvailable()) and S.ExecutionSentence:CooldownRemains() <= Player:GCD() * 3) then
    if Cast(S.Seraphim, Settings.Retribution.GCDasOffGCD.Seraphim) then return "seraphim es_fr_pooling 16"; end
  end
  -- call_action_list,name=finishers
  local ShouldReturn = Finishers(); if ShouldReturn then return ShouldReturn; end
  -- crusader_strike
  if S.CrusaderStrike:IsCastable() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike es_fr_pooling 18"; end
  end
  -- arcane_torrent,if=holy_power<=4
  if S.ArcaneTorrent:IsCastable() and (Player:HolyPower() <= 4) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent es_fr_pooling 20"; end
  end
  -- exorcism
  if S.Exorcism:IsCastable() then
    if Cast(S.Exorcism, nil, nil, not Target:IsSpellInRange(S.Exorcism)) then return "exorcism es_fr_pooling 22"; end
  end
  -- seraphim,if=(!talent.final_reckoning|cooldown.final_reckoning.remains<=gcd*3)&(!talent.execution_sentence|cooldown.execution_sentence.remains<=gcd*3|talent.final_reckoning)
  if S.Seraphim:IsReady() and (((not S.FinalReckoning:IsAvailable()) or S.FinalReckoning:CooldownRemains() <= Player:GCD() * 3) and ((not S.ExecutionSentence:IsAvailable()) or S.ExecutionSentence:CooldownRemains() <= Player:GCD() * 3 or S.FinalReckoning:IsAvailable())) then
    if Cast(S.Seraphim, Settings.Retribution.GCDasOffGCD.Seraphim) then return "seraphim es_fr_pooling 24"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration es_fr_pooling 26"; end
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
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- rebuke
    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, Interrupts); if ShouldReturn then return "Interrupts: " .. ShouldReturn; end
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return "Cooldowns: " .. ShouldReturn; end
    end
    -- call_action_list,name=es_fr_pooling,if=(!raid_event.adds.exists|raid_event.adds.up|raid_event.adds.in<9|raid_event.adds.in>30)&(talent.execution_sentence&cooldown.execution_sentence.remains<9&spell_targets.divine_storm<5|talent.final_reckoning&cooldown.final_reckoning.remains<9)&(!buff.crusade.up|buff.crusade.stack=10)&target.time_to_die>8
    if ((S.ExecutionSentence:IsAvailable() and S.ExecutionSentence:CooldownRemains() < 9 and EnemiesCount8y < 5 or S.FinalReckoning:IsAvailable() and S.FinalReckoning:CooldownRemains() < 9) and (Player:BuffDown(S.CrusadeBuff) or Player:BuffStack(S.CrusadeBuff) == 10) and Target:TimeToDie() > 8) then
      local ShouldReturn = ESFRPooling(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=es_fr_active,if=debuff.execution_sentence.up|debuff.final_reckoning.up
    if (Target:DebuffUp(S.ExecutionSentence) or Target:DebuffUp(S.FinalReckoning)) then
      local ShouldReturn = ESFRActive(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=generators
    local ShouldReturn = Generators(); if ShouldReturn then return "Generators: " .. ShouldReturn; end
    -- Manually added: Pooling, if nothing else to do
    if Cast(S.Pool) then return "Wait/Pool Resources"; end
  end
end

local function OnInit()
  HR.Print("Retribution Paladin rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(70, APL, OnInit)
