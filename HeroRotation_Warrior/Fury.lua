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
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Fury
local I = Item.Warrior.Fury

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.Fyralath:ID(),
}

-- Variables
local EnrageUp
local VarSTPlanning, VarAddsRemain
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- Enemies Variables
local EnemiesMelee, EnemiesMeleeCount
local TargetInMeleeRange

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Fury = HR.GUISettings.APL.Warrior.Fury
}

-- Interrupts List
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
}

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%cooldown.avatar.duration=0|trinket.1.cooldown.duration%%cooldown.odyns_fury.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%cooldown.avatar.duration=0|trinket.2.cooldown.duration%%cooldown.odyns_fury.duration=0)
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit&!variable.trinket_1_exclude)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit&!variable.trinket_2_exclude)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  -- Note: Ruby Whelp Shell is already globally excluded. Puzzle Box is excluded via OnUseExcludes.
  -- Note: Not able to handle the other trinket variables.
  -- Manually added: Group Battle Shout check
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout precombat"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 2"; end
  end
  -- berserker_stance,toggle=on
  if S.BerserkerStance:IsCastable() and Player:BuffDown(S.BerserkerStance, true) then
    if Cast(S.BerserkerStance) then return "berserker_stance precombat 4"; end
  end
  -- avatar,if=!talent.titans_torment
  if S.Avatar:IsCastable() and (not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar precombat 6"; end
  end
  -- recklessness,if=!talent.reckless_abandon
  if S.Recklessness:IsCastable() and (not S.RecklessAbandon:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 8"; end
  end
  -- Manually Added: Charge if not in melee range. Bloodthirst if in melee range
  if S.Bloodthirst:IsCastable() and TargetInMeleeRange then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 10"; end
  end
  if S.Charge:IsReady() and not TargetInMeleeRange then
    if Cast(S.Charge, nil, nil, not Target:IsInRange(25)) then return "charge precombat 12"; end
  end
end

local function MultiTarget()
  -- recklessness,if=raid_event.adds.in>15|active_enemies>1|target.time_to_die<12
  if CDsON() and S.Recklessness:IsCastable() and (EnemiesMeleeCount > 1 or FightRemains < 12) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness multi_target 2"; end
  end
  -- odyns_fury,if=active_enemies>1&talent.titanic_rage&(!buff.meat_cleaver.up|buff.avatar.up|buff.recklessness.up)
  if CDsON() and S.OdynsFury:IsCastable() and (EnemiesMeleeCount > 1 and S.TitanicRage:IsAvailable() and (Player:BuffDown(S.MeatCleaverBuff) or Player:BuffUp(S.AvatarBuff) or Player:BuffUp(S.RecklessnessBuff))) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 4"; end
  end
  -- whirlwind,if=spell_targets.whirlwind>1&talent.improved_whirlwind&!buff.meat_cleaver.up|raid_event.adds.in<2&talent.improved_whirlwind&!buff.meat_cleaver.up
  if S.Whirlwind:IsCastable() and (EnemiesMeleeCount > 1 and S.ImprovedWhilwind:IsAvailable() and Player:BuffDown(S.MeatCleaverBuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind multi_target 6"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd
  if S.Execute:IsReady() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar multi_target 10"; end
  end
  -- odyns_fury,if=active_enemies>1&buff.enrage.up&raid_event.adds.in>15
  if CDsON() and S.OdynsFury:IsCastable() and (EnemiesMeleeCount > 1 and EnrageUp) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 12"; end
  end
  local BTCritChance = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.MercilessAssaultBuff) * 10 + Player:BuffStack(S.BloodcrazeBuff) * 15
  -- bloodbath,if=set_bonus.tier30_4pc&action.bloodthirst.crit_pct_current>=95|set_bonus.tier31_4pc
  if S.Bloodbath:IsCastable() and (Player:HasTier(30, 4) and BTCritChance >= 95 or Player:HasTier(31, 4)) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 14"; end
  end
  -- bloodthirst,if=(set_bonus.tier30_4pc&action.bloodthirst.crit_pct_current>=95)|(!talent.reckless_abandon&buff.furious_bloodthirst.up&buff.enrage.up)
  if S.Bloodthirst:IsCastable() and ((Player:HasTier(30, 4) and BTCritChance >= 95) or (not S.RecklessAbandon:IsAvailable() and Player:BuffUp(S.FuriousBloodthirstBuff) and EnrageUp))  then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 16"; end
  end
  -- crushing_blow,if=talent.wrath_and_fury&buff.enrage.up
  if S.CrushingBlow:IsCastable() and (S.WrathandFury:IsAvailable() and EnrageUp) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 18"; end
  end
  -- execute,if=buff.enrage.up
  if S.Execute:IsReady() and (EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 20"; end
  end
  -- odyns_fury,if=buff.enrage.up&raid_event.adds.in>15
  if CDsON() and S.OdynsFury:IsCastable() and (EnrageUp) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 22"; end
  end
  -- rampage,if=buff.recklessness.up|buff.enrage.remains<gcd|(rage>110&talent.overwhelming_rage)|(rage>80&!talent.overwhelming_rage)
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or (Player:Rage() > 110 and S.OverwhelmingRage:IsAvailable()) or (Player:Rage() > 80 and not S.OverwhelmingRage:IsAvailable())) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage multi_target 24"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 26"; end
  end
  -- bloodbath,if=buff.enrage.up&talent.reckless_abandon&!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and (EnrageUp and S.RecklessAbandon:IsAvailable() and not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 28"; end
  end
  -- bloodthirst,if=buff.enrage.down|(talent.annihilator&!buff.recklessness.up)
  if S.Bloodthirst:IsCastable() and (not EnrageUp or (S.Annihilator:IsAvailable() and Player:BuffDown(S.RecklessnessBuff))) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 30"; end
  end
  -- onslaught,if=!talent.annihilator&buff.enrage.up|talent.tenderize
  if S.Onslaught:IsReady() and (not S.Annihilator:IsAvailable() and EnrageUp or S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught multi_target 32"; end
  end
  -- raging_blow,if=charges>1&talent.wrath_and_fury
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() > 1 and S.WrathandFury:IsAvailable()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 34"; end
  end
  -- crushing_blow,if=charges>1&talent.wrath_and_fury
  if S.CrushingBlow:IsCastable() and (S.CrushingBlow:Charges() > 1 and S.WrathandFury:IsAvailable()) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 36"; end
  end
  -- bloodbath,if=buff.enrage.down|!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and (not EnrageUp or not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 38"; end
  end
  -- crushing_blow,if=buff.enrage.up&talent.reckless_abandon
  if S.CrushingBlow:IsCastable() and (EnrageUp and S.RecklessAbandon:IsAvailable()) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 40"; end
  end
  -- bloodthirst,if=!talent.wrath_and_fury
  if S.Bloodthirst:IsCastable() and (not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 42"; end
  end
  -- raging_blow,if=charges>=1
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() > 1) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 44"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage multi_target 46"; end
  end
  -- slam,if=talent.annihilator
  if S.Slam:IsReady() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam multi_target 48"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 50"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 52"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 54"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind multi_target 56"; end
  end
end

local function SingleTarget()
  -- whirlwind,if=spell_targets.whirlwind>1&talent.improved_whirlwind&!buff.meat_cleaver.up|raid_event.adds.in<2&talent.improved_whirlwind&!buff.meat_cleaver.up
  if S.Whirlwind:IsCastable() and (EnemiesMeleeCount > 1 and S.ImprovedWhilwind:IsAvailable() and Player:BuffDown(S.MeatCleaverBuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 2"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd
  if S.Execute:IsReady() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 4"; end
  end
  -- odyns_fury,if=(buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)&(talent.dancing_blades&buff.dancing_blades.remains<5|!talent.dancing_blades))
  if CDsON() and S.OdynsFury:IsCastable() and (EnrageUp and (S.DancingBlades:IsAvailable() and Player:BuffRemains(S.DancingBladesBuff) < 5 or not S.DancingBlades:IsAvailable())) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury single_target 6"; end
  end
  -- rampage,if=talent.anger_management&(buff.recklessness.up|buff.enrage.remains<gcd|rage.pct>85)
  if S.Rampage:IsReady() and (S.AngerManagement:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:RagePercentage() > 85)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 8"; end
  end
  local BTCritChance = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.MercilessAssaultBuff) * 10 + Player:BuffStack(S.BloodcrazeBuff) * 15
  -- bloodbath,if=set_bonus.tier30_4pc&action.bloodthirst.crit_pct_current>=95
  if S.Bloodbath:IsCastable() and (Player:HasTier(30, 4) and BTCritChance >= 95) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 10"; end
  end
  -- bloodthirst,if=(set_bonus.tier30_4pc&action.bloodthirst.crit_pct_current>=95)|(!talent.reckless_abandon&buff.furious_bloodthirst.up&buff.enrage.up&(!dot.gushing_wound.remains|buff.elysian_might.up))
  if S.Bloodthirst:IsCastable() and ((Player:HasTier(30, 4) and BTCritChance >= 95) or (not S.RecklessAbandon:IsAvailable() and Player:BuffUp(S.FuriousBloodthirstBuff) and EnrageUp and (Target:DebuffDown(S.GushingWoundDebuff) or Player:BuffUp(S.ElysianMightBuff)))) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 12"; end
  end
  -- bloodbath,if=set_bonus.tier31_2pc
  if S.Bloodbath:IsCastable() and (Player:HasTier(31, 2)) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 14"; end
  end
  -- thunderous_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 16"; end
  end
  -- onslaught,if=buff.enrage.up|talent.tenderize
  if S.Onslaught:IsReady() and (EnrageUp or S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught single_target 18"; end
  end
  -- crushing_blow,if=talent.wrath_and_fury&buff.enrage.up&!buff.furious_bloodthirst.up
  if S.CrushingBlow:IsCastable() and (S.WrathandFury:IsAvailable() and EnrageUp and Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 20"; end
  end
  -- execute,if=buff.enrage.up&!buff.furious_bloodthirst.up&buff.ashen_juggernaut.up|buff.sudden_death.remains<=gcd&(target.health.pct>35&talent.massacre|target.health.pct>20)
  if S.Execute:IsReady() and (EnrageUp and Player:BuffDown(S.FuriousBloodthirstBuff) and Player:BuffUp(S.AshenJuggernautBuff) or Player:BuffRemains(S.SuddenDeathBuff) <= Player:GCD() and (Target:HealthPercentage() > 35 and S.Massacre:IsAvailable() or Target:HealthPercentage() > 20)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 22"; end
  end
  -- rampage,if=talent.reckless_abandon&(buff.recklessness.up|buff.enrage.remains<gcd|rage.pct>85)
  if S.Rampage:IsReady() and (S.RecklessAbandon:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:RagePercentage() > 85)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 26"; end
  end
  -- execute,if=buff.enrage.up
  if S.Execute:IsReady() and (EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 28"; end
  end
  -- rampage,if=talent.anger_management
  if S.Rampage:IsReady() and (S.AngerManagement:IsAvailable()) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 24"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 26"; end
  end
  -- bloodbath,if=buff.enrage.up&talent.reckless_abandon&!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and (EnrageUp and S.RecklessAbandon:IsAvailable() and not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 28"; end
  end
  -- rampage,if=target.health.pct<35&talent.massacre.enabled
  if S.Rampage:IsReady() and (Target:HealthPercentage() < 35 and S.Massacre:IsAvailable()) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 30"; end
  end
  -- bloodthirst,if=(buff.enrage.down|(talent.annihilator&!buff.recklessness.up))&!buff.furious_bloodthirst.up
  if S.Bloodthirst:IsCastable() and ((not EnrageUp or (S.Annihilator:IsAvailable() and Player:BuffDown(S.RecklessnessBuff))) and Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 32"; end
  end
  -- raging_blow,if=charges>1&talent.wrath_and_fury
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() > 1 and S.WrathandFury:IsAvailable()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 34"; end
  end
  -- crushing_blow,if=charges>1&talent.wrath_and_fury&!buff.furious_bloodthirst.up
  if S.CrushingBlow:IsCastable() and (S.CrushingBlow:Charges() > 1 and S.WrathandFury:IsAvailable() and Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 36"; end
  end
  -- bloodbath,if=buff.enrage.down|!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and (not EnrageUp or not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 38"; end
  end
  -- crushing_blow,if=buff.enrage.up&talent.reckless_abandon&!buff.furious_bloodthirst.up
  if S.CrushingBlow:IsCastable() and (EnrageUp and S.RecklessAbandon:IsAvailable() and Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 40"; end
  end
  -- bloodthirst,if=!talent.wrath_and_fury&!buff.furious_bloodthirst.up
  if S.Bloodthirst:IsCastable() and (not S.WrathandFury:IsAvailable() and Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 42"; end
  end
  -- raging_blow,if=charges>1
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() > 1) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 44"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 46"; end
  end
  -- slam,if=talent.annihilator
  if S.Slam:IsReady() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 48"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 50"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 52"; end
  end
  -- crushing_blow,if=!buff.furious_bloodthirst.up
  if S.CrushingBlow:IsCastable() and (Player:BuffDown(S.FuriousBloodthirstBuff)) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 54"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 56"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 58"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw single_target 60"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if Cast(S.StormBolt, nil, nil, not TargetInMeleeRange) then return "storm_bolt single_target 62"; end
  end
end

local function Trinkets()
  -- use_item,name=fyralath_the_dreamrender,if=dot.mark_of_fyralath.ticking
  if Settings.Commons.Enabled.Items and I.Fyralath:IsEquippedAndReady() and (S.MarkofFyralathDebuff:AuraActiveCount() > 0) then
    if Cast(I.Fyralath, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(25)) then return "fyralath_the_dreamrender trinkets 1"; end
  end
  -- use_item,use_off_gcd=1,name=algethar_puzzle_box,if=cooldown.recklessness.remains<3|(talent.anger_management&cooldown.avatar.remains<3)
  if I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() < 3 or (S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 3)) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&(buff.avatar.up)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&(buff.avatar.up)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
  -- use_item,use_off_gcd=1,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- Note: Can't handle most of the above. Using a generic use_items instead.
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
  VarSTPlanning = (EnemiesMeleeCount == 1)
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
  VarAddsRemain = (EnemiesMeleeCount >= 2)
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMeleeCount = 1
  end

  -- Enrage check
  EnrageUp = Player:BuffUp(S.EnrageBuff)

  -- Range check
  TargetInMeleeRange = Target:IsInRange(5)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- In Combat
    -- Manually added: battle_shout during combat
    if S.BattleShout:IsCastable() and Settings.Commons.ShoutDuringCombat and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
      if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout main 1"; end
    end
    -- auto_attack
    -- charge,if=time<=0.5|movement.distance>5
    if S.Charge:IsCastable() then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and not TargetInMeleeRange and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap main 4"; end
    end
    -- potion
    if CDsON() and Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- pummel,if=target.debuff.casting.react
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if CDsON() then
      -- ravager,if=cooldown.recklessness.remains<3|buff.recklessness.up
      -- Note: manually added end of fight
      if S.Ravager:IsCastable() and (S.Avatar:CooldownRemains() < 3 or Player:BuffUp(S.RecklessnessBuff) or FightRemains < 10) then
        if Cast(S.Ravager, Settings.Fury.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager main 8"; end
      end
      -- lights_judgment,if=buff.recklessness.down
      if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RecklessnessBuff) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 10"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() and Player:BuffUp(S.RecklessnessBuff) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 12"; end
      end
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 14"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 16"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 18"; end
      end
      -- avatar,if=talent.titans_torment&buff.enrage.up&raid_event.adds.in>15&!buff.avatar.up&cooldown.odyns_fury.remains|talent.berserkers_torment&buff.enrage.up&!buff.avatar.up&raid_event.adds.in>15|!talent.titans_torment&!talent.berserkers_torment&(buff.recklessness.up|target.time_to_die<20)
      if S.Avatar:IsCastable() and (S.TitansTorment:IsAvailable() and EnrageUp and Player:BuffDown(S.AvatarBuff) and S.OdynsFury:CooldownDown() or S.BerserkersTorment:IsAvailable() and EnrageUp and Player:BuffDown(S.AvatarBuff) or not S.TitansTorment:IsAvailable() and not S.BerserkersTorment:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or FightRemains < 20)) then
        if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar main 20"; end
      end
      -- recklessness,if=!raid_event.adds.exists&(talent.annihilator&cooldown.champions_spear.remains<1|cooldown.avatar.remains>40|!talent.avatar|target.time_to_die<12)
      if S.Recklessness:IsCastable() and (S.Annihilator:IsAvailable() and S.ChampionsSpear:CooldownRemains() < 1 or S.Avatar:CooldownRemains() > 40 or not S.Avatar:IsAvailable() or FightRemains < 12) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 22"; end
      end
      -- recklessness,if=!raid_event.adds.exists&!talent.annihilator|target.time_to_die<12
      if S.Recklessness:IsCastable() and (not S.Annihilator:IsAvailable() or FightRemains < 12) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 24"; end
      end
      -- champions_spear,if=buff.enrage.up&((buff.furious_bloodthirst.up&talent.titans_torment)|!talent.titans_torment|target.time_to_die<20|active_enemies>1|!set_bonus.tier31_2pc)&raid_event.adds.in>15
      if S.ChampionsSpear:IsCastable() and (EnrageUp and ((Player:BuffUp(S.FuriousBloodthirstBuff) and S.TitansTorment:IsAvailable()) or not S.TitansTorment:IsAvailable() or FightRemains < 20 or EnemiesMeleeCount > 1 or not Player:HasTier(31, 2))) then
        if Cast(S.ChampionsSpear, nil, Settings.Commons.DisplayStyle.Signature, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear main 26"; end
      end
    end
    -- run_action_list,name=multi_target,if=active_enemies>=2
    if AoEON() and EnemiesMeleeCount >= 2 then
      local ShouldReturn = MultiTarget(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for MultiTarget()"; end
    end
    -- run_action_list,name=single_target,if=active_enemies=1
    if EnemiesMeleeCount == 1 then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleTarget()"; end
    end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Fury Warrior rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(72, APL, Init)
