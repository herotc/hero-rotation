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
-- WoW API
local Delay      = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Fury
local I = Item.Warrior.Fury

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  CommonsDS = HR.GUISettings.APL.Warrior.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warrior.CommonsOGCD,
  Fury = HR.GUISettings.APL.Warrior.Fury
}

--- ===== Rotation Variables =====
local VarSTPlanning, VarAddsRemain
local VarExecutePhase, VarOnGCDRacials
local EnemiesMelee, EnemiesMeleeCount
local TargetInMeleeRange
local EnrageUp
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarTrinket1Exclude = T1.ID == I.TreacherousTransmitter:ID()
  VarTrinket2Exclude = T2.ID == I.TreacherousTransmitter:ID()

  VarTrinket1Sync = 0.5
  if Trinket1:HasUseBuff() and (VarTrinket1CD % 90 == 0 or VarTrinket1CD) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if Trinket2:HasUseBuff() and (VarTrinket2CD % 90 == 0) then
    VarTrinket2Sync = 1
  end

  VarTrinket1Buffs = Trinket1:HasUseBuff() or (Trinket1:HasStatAnyDps() and not VarTrinket1Exclude)
  VarTrinket2Buffs = Trinket2:HasUseBuff() or (Trinket2:HasStatAnyDps() and not VarTrinket2Exclude)

  -- Note: Using the below buff durations to avoid potential divide by zero errors.
  local T1BuffDuration = (Trinket1:BuffDuration() > 0) and Trinket1:BuffDuration() or 1
  local T2BuffDuration = (Trinket2:BuffDuration() > 0) and Trinket2:BuffDuration() or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDuration) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDuration) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end

  VarTrinket1Manual = T1.ID == I.AlgetharPuzzleBox:ID()
  VarTrinket2Manual = T2.ID == I.AlgetharPuzzleBox:ID()
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- berserker_stance,toggle=on
  if S.BerserkerStance:IsCastable() and Player:BuffDown(S.BerserkerStance, true) then
    if Cast(S.BerserkerStance) then return "berserker_stance precombat 2"; end
  end
  -- variable,name=trinket_1_exclude,value=trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_exclude,value=trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%cooldown.avatar.duration=0|trinket.1.cooldown.duration%%cooldown.odyns_fury.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%cooldown.avatar.duration=0|trinket.2.cooldown.duration%%cooldown.odyns_fury.duration=0)
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_stat.any_dps&!variable.trinket_1_exclude)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_stat.any_dps&!variable.trinket_2_exclude)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  -- variable,name=treacherous_transmitter_precombat_cast,value=2
  -- Note: Moved the above variables to declarations and PLAYER_EQUIPMENT_CHANGED.
  -- Manually added: Group Battle Shout check
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout precombat 4"; end
  end
  -- use_item,name=treacherous_transmitter
  if Settings.Commons.Enabled.Trinkets and I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 6"; end
  end
  -- recklessness,if=!equipped.fyralath_the_dreamrender
  if CDsON() and S.Recklessness:IsCastable() and (not I.Fyralath:IsEquipped()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 8"; end
  end
  -- avatar,if=!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and (not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar precombat 10"; end
  end
  -- Manually Added: Charge if not in melee range. Bloodthirst if in melee range
  if S.Bloodthirst:IsCastable() and TargetInMeleeRange then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 12"; end
  end
  if S.Charge:IsReady() and not TargetInMeleeRange then
    if Cast(S.Charge, nil, nil, not Target:IsInRange(25)) then return "charge precombat 14"; end
  end
end

local function SlayerAMST()
  -- recklessness,if=(!talent.anger_management&cooldown.avatar.remains<1&talent.titans_torment)|talent.anger_management|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and ((not S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable()) or S.AngerManagement:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer_am_st 2"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar slayer_am_st 4"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_am_st 6"; end
  end
  -- champions_spear,if=(buff.enrage.up&talent.titans_torment&cooldown.avatar.remains<gcd)|(buff.enrage.up&!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and ((EnrageUp and S.TitansTorment:IsAvailable() and S.Avatar:CooldownRemains() < Player:GCD()) or (EnrageUp and not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear slayer_am_st 8"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury slayer_am_st 10"; end
  end
  -- execute,if=debuff.marked_for_execution.stack=3|buff.ashen_juggernaut.remains<2|buff.sudden_death.stack=2&buff.sudden_death.remains<7|buff.sudden_death.remains<2
  if S.Execute:IsReady() and (Target:DebuffStack(S.MarkedforExecutionDebuff) == 3 or Player:BuffRemains(S.AshenJuggernautBuff) < 2 or Player:BuffStack(S.SuddenDeathBuff) == 2 and Player:BuffRemains(S.SuddenDeathBuff) < 7 or Player:BuffRemains(S.SuddenDeathBuff) < 2) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_st 12"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_st 14"; end
  end
  -- bladestorm,if=buff.enrage.up&(cooldown.recklessness.remains>=9|cooldown.avatar.remains>=9)
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and (S.Recklessness:CooldownRemains() >= 9 or S.Avatar:CooldownRemains() >= 9)) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_am_st 16"; end
  end
  -- onslaught,if=talent.tenderize&buff.brutal_finish.up
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable() or Player:BuffUp(S.BrutalFinishBuff)) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_am_st 18"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_st 20"; end
  end
  -- raging_blow,if=buff.opportunist.up
  if S.RagingBlow:IsCastable() and (Player:BuffUp(S.OpportunistBuff)) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_am_st 22"; end
  end
  -- bloodthirst,if=target.health.pct<35&talent.vicious_contempt&buff.bloodcraze.stack>=2
  if S.Bloodthirst:IsCastable() and (Target:HealthPercentage() < 35 and S.ViciousContempt:IsAvailable() and Player:BuffStack(S.BloodcrazeBuff) >= 2) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_am_st 24"; end
  end
  -- rampage,if=action.raging_blow.charges<=1&rage>=115
  if S.Rampage:IsReady() and (S.RagingBlow:Charges() <= 1 and Player:Rage() >= 115) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_st 26"; end
  end
  -- bloodthirst,if=buff.bloodcraze.stack>3|crit_pct_current>=85
  local CritPctCurrent = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.BloodcrazeBuff) * 15
  if S.Bloodthirst:IsCastable() and (Player:BuffStack(S.BloodcrazeBuff) > 3 or CritPctCurrent >= 85) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_am_st 28"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_am_st 30"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_am_st 28"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_st 30"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_st 32"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_am_st 34"; end
  end
  -- whirlwind,if=talent.meat_cleaver
  if S.Whirlwind:IsCastable() and (S.MeatCleaver:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_am_st 36"; end
  end
  -- slam
  if S.Slam:IsCastable() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer_am_st 38"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  if S.StormBolt:IsCastable() and (Player:BuffUp(S.Bladestorm)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_am_st 40"; end
  end
end

local function SlayerRAST()
  -- recklessness,if=cooldown.avatar.remains<1&talent.titans_torment|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and (S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer_ra_st 2"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_st 4"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar slayer_ra_st 6"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_ra_st 8"; end
  end
  -- champions_spear,if=(buff.enrage.up&talent.titans_torment&cooldown.avatar.remains<gcd)|(buff.enrage.up&!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and ((EnrageUp and S.TitansTorment:IsAvailable() and S.Avatar:CooldownRemains() < Player:GCD()) or (EnrageUp and not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear slayer_ra_st 10"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury slayer_ra_st 12"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_st 14"; end
  end
  -- bladestorm,if=buff.enrage.up&cooldown.avatar.remains>=9
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and S.Avatar:CooldownRemains() >= 9) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_ra_st 16"; end
  end
  -- execute,if=debuff.marked_for_execution.stack=3|buff.ashen_juggernaut.remains<2|buff.sudden_death.stack=2&buff.sudden_death.remains<7|buff.sudden_death.remains<2
  if S.Execute:IsReady() and (Target:DebuffStack(S.MarkedforExecutionDebuff) == 3 or Player:BuffRemains(S.AshenJuggernautBuff) < 2 or Player:BuffStack(S.SuddenDeathBuff) == 2 and Player:BuffRemains(S.SuddenDeathBuff) < 7 or Player:BuffRemains(S.SuddenDeathBuff) < 2) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_ra_st 18"; end
  end
  -- onslaught,if=talent.tenderize&buff.brutal_finish.up
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable() or Player:BuffUp(S.BrutalFinishBuff)) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_st 20"; end
  end
  -- bloodbath,if=crit_pct_current>=85|buff.bloodcraze.stack>=3
  local CritPctCurrent = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.BloodcrazeBuff) * 15
  if S.Bloodbath:IsCastable() and (CritPctCurrent >= 85 or Player:BuffStack(S.BloodcrazeBuff) >= 3) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_st 22"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow slayer_ra_st 24"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_st 26"; end
  end
  -- bloodbath,if=target.health.pct<35&talent.vicious_contempt
  if S.Bloodbath:IsCastable() and (Target:HealthPercentage() < 35 and S.ViciousContempt:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_st 28"; end
  end
  -- rampage,if=rage>=115
  if S.Rampage:IsReady() and (Player:Rage() >= 115) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_st 30"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_ra_st 32"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_st 34"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_st 36"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_ra_st 38"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_ra_st 40"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_st 42"; end
  end
  -- whirlwind,if=talent.meat_cleaver
  if S.Whirlwind:IsCastable() and (S.MeatCleaver:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_ra_st 44"; end
  end
  -- slam
  if S.Slam:IsCastable() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer_ra_st 46"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  if S.StormBolt:IsCastable() and (Player:BuffUp(S.Bladestorm)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_ra_st 48"; end
  end
end

local function SlayerAMMT()
  -- recklessness
  if CDsON() and S.Recklessness:IsCastable() then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer_am_mt 2"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar slayer_am_mt 4"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_am_mt 6"; end
  end
  -- champions_spear,if=(buff.enrage.up&talent.titans_torment&cooldown.avatar.remains<gcd)|(buff.enrage.up&!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and ((EnrageUp and S.TitansTorment:IsAvailable() and S.Avatar:CooldownRemains() < Player:GCD()) or (EnrageUp and not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear slayer_am_mt 8"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury slayer_am_mt 10"; end
  end
  -- whirlwind,if=buff.meat_cleaver.stack=0&talent.meat_cleaver
  if S.Whirlwind:IsCastable() and (Player:BuffDown(S.MeatCleaverBuff) and S.MeatCleaver:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_am_mt 12"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_mt 14"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_mt 16"; end
  end
  -- bladestorm,if=buff.enrage.up&cooldown.avatar.remains>=5
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and S.Avatar:CooldownRemains() >= 5) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_am_mt 18"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_am_mt 20"; end
  end
  -- execute,if=buff.enrage.up&debuff.marked_for_execution.stack=3
  if S.Execute:IsReady() and (EnrageUp and Target:DebuffStack(S.MarkedforExecutionDebuff) == 3) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_mt 22"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_mt 24"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_am_mt 26"; end
  end
  -- rampage,if=buff.slaughtering_strikes.stack>=2
  if S.Rampage:IsReady() and (Player:BuffStack(S.SlaughteringStrikesBuff) >= 2) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_mt 28"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_am_mt 30"; end
  end
  -- execute,if=buff.enrage.up
  if S.Execute:IsReady() and (EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_mt 32"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_am_mt 34"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_am_mt 36"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_am_mt 38"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  if S.StormBolt:IsCastable() and (Player:BuffUp(S.Bladestorm)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_am_mt 40"; end
  end
end

local function SlayerRAMT()
  -- recklessness,if=(!talent.anger_management&cooldown.avatar.remains<1&talent.titans_torment)|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and ((not S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable()) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer_ra_mt 2"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment&buff.enrage.up
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable() and EnrageUp) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar slayer_ra_mt 4"; end
  end
  -- rampage,if=!buff.enrage.up&!talent.titans_torment
  if S.Rampage:IsReady() and (not EnrageUp and not S.TitansTorment:IsAvailable()) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_mt 6"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_ra_mt 8"; end
  end
  -- champions_spear,if=(buff.enrage.up&talent.titans_torment&cooldown.avatar.remains<gcd)|(buff.enrage.up&!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and ((EnrageUp and S.TitansTorment:IsAvailable() and S.Avatar:CooldownRemains() < Player:GCD()) or (EnrageUp and not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear slayer_ra_mt 10"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury slayer_ra_mt 12"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_mt 14"; end
  end
  -- bladestorm,if=buff.enrage.up&cooldown.avatar.remains>=9&buff.enrage.remains>3
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and S.Avatar:CooldownRemains() >= 9 and Player:BuffRemains(S.EnrageBuff) > 3) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_ra_mt 16"; end
  end
  -- whirlwind,if=buff.meat_cleaver.stack=0&talent.meat_cleaver
  if S.Whirlwind:IsCastable() and (Player:BuffDown(S.MeatCleaverBuff) and S.MeatCleaver:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_ra_mt 18"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_ra_mt 20"; end
  end
  -- onslaught,if=talent.tenderize&buff.brutal_finish.up
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable() or Player:BuffUp(S.BrutalFinishBuff)) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_mt 26"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_mt 28"; end
  end
  -- bloodbath,if=active_enemies>=6
  if S.Bloodbath:IsCastable() and (EnemiesMeleeCount >= 6) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_mt 30"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow slayer_ra_mt 32"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_mt 34"; end
  end
  -- bloodthirst,if=active_enemies>=6
  if S.Bloodthirst:IsCastable() and (EnemiesMeleeCount >= 6) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_ra_mt 36"; end
  end
  -- execute,if=buff.enrage.up&debuff.marked_for_execution.up
  if S.Execute:IsReady() and (EnrageUp and Target:DebuffUp(S.MarkedforExecutionDebuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_ra_mt 38"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_mt 40"; end
  end
  -- rampage,if=rage>115
  if S.Rampage:IsReady() and (Player:Rage() > 115) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer_ra_mt 42"; end
  end
  -- raging_blow,if=talent.slaughtering_strikes
  if S.RagingBlow:IsCastable() and (S.SlaughteringStrikes:IsAvailable()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_ra_mt 44"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer_ra_mt 46"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer_ra_mt 48"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer_ra_mt 50"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer_ra_mt 52"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  if S.StormBolt:IsCastable() and (Player:BuffUp(S.Bladestorm)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_ra_mt 54"; end
  end
end

local function ThaneAMST()
  -- recklessness,if=talent.anger_management|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and (S.AngerManagement:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness thane_am_st 2"; end
  end
  -- thunder_blast,if=buff.enrage.up
  if S.ThunderBlastAbility:IsReady() and (EnrageUp) then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast thane_am_st 4"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar thane_am_st 6"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager thane_am_st 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar thane_am_st 10"; end
  end
  -- champions_spear,if=buff.enrage.up&(cooldown.avatar.remains<gcd|!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp and (S.Avatar:CooldownRemains() < Player:GCD() or not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear thane_am_st 12"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury thane_am_st 14"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_am_st 16"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_am_st 18"; end
  end
  -- bladestorm,if=buff.enrage.up&talent.unhinged
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and S.Unhinged:IsAvailable()) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm thane_am_st 20"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_am_st 22"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_am_st 24"; end
  end
  -- bloodthirst,if=talent.vicious_contempt&target.health.pct<35&buff.bloodcraze.stack>=2|!dot.ravager.remains&buff.bloodcraze.stack>=3
  if S.Bloodthirst:IsCastable() and (S.ViciousContempt:IsAvailable() and Target:HealthPercentage() < 35 and Player:BuffStack(S.BloodcrazeBuff) >= 2 or Target:DebuffDown(S.RavagerDebuff) and Player:BuffStack(S.BloodcrazeBuff) >= 3) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_am_st 26"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow thane_am_st 28"; end
  end
  -- execute,if=talent.ashen_juggernaut
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_am_st 30"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_am_st 32"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_am_st 34"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_am_st 36"; end
  end
end

local function ThaneRAST()
  -- recklessness,if=(!talent.anger_management&cooldown.avatar.remains<1&talent.titans_torment)|talent.anger_management|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and ((not S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable()) or S.AngerManagement:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness thane_ra_st 2"; end
  end
  -- thunder_blast,if=buff.enrage.up
  if S.ThunderBlastAbility:IsReady() and (EnrageUp) then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast thane_ra_st 4"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment&buff.enrage.up
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable() and EnrageUp) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar thane_ra_st 6"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager thane_ra_st 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar thane_ra_st 10"; end
  end
  -- champions_spear,if=buff.enrage.up&(cooldown.avatar.remains<gcd|!talent.titans_torment)
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp and (S.Avatar:CooldownRemains() < Player:GCD() or not S.TitansTorment:IsAvailable())) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear thane_ra_st 12"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury thane_ra_st 14"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_ra_st 16"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_st 18"; end
  end
  -- bladestorm,if=buff.enrage.up&talent.unhinged
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and S.Unhinged:IsAvailable()) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm thane_ra_st 20"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_st 22"; end
  end
  -- bloodbath,if=talent.vicious_contempt&target.health.pct<35|buff.bloodcraze.stack>=3
  if S.Bloodbath:IsCastable() and (S.ViciousContempt:IsAvailable() and Target:HealthPercentage() < 35 or Player:BuffStack(S.BloodcrazeBuff) >= 3) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath thane_ra_st 24"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow thane_ra_st 26"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_ra_st 28"; end
  end
  -- rampage,if=rage>=115
  if S.Rampage:IsReady() and (Player:Rage() >= 115) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_st 30"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow thane_ra_st 32"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath thane_ra_st 34"; end
  end
  -- bloodthirst,if=buff.enrage.up&!buff.burst_of_power.up
  if S.Bloodthirst:IsCastable() and (EnrageUp and Player:BuffDown(S.BurstofPowerBuff)) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_ra_st 36"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_st 38"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_ra_st 40"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_ra_st 42"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_ra_st 44"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_ra_st 46"; end
  end
  -- whirlwind,if=talent.meat_cleaver
  if S.Whirlwind:IsCastable() and (S.MeatCleaver:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind thane_ra_st 48"; end
  end
  -- slam
  if S.Slam:IsCastable() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam thane_ra_st 50"; end
  end
end

local function ThaneAMMT()
  -- recklessness,if=(!talent.anger_management&cooldown.avatar.remains<1&talent.titans_torment)|talent.anger_management|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and ((not S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable()) or S.AngerManagement:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness thane_am_mt 2"; end
  end
  -- thunder_blast,if=buff.enrage.up
  if S.ThunderBlastAbility:IsReady() and (EnrageUp) then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast thane_am_mt 4"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar thane_am_mt 6"; end
  end
  -- thunder_clap,if=buff.meat_cleaver.stack=0&talent.meat_cleaver
  if S.ThunderClap:IsCastable() and (Player:BuffDown(S.MeatCleaverBuff) and S.MeatCleaver:IsAvailable()) then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_am_mt 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar thane_am_mt 10"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager thane_am_mt 12"; end
  end
  -- champions_spear,if=buff.enrage.up
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear thane_am_mt 14"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury thane_am_mt 16"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_am_mt 18"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_am_mt 20"; end
  end
  -- bladestorm,if=buff.enrage.up
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm thane_am_mt 22"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_am_mt 24"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_am_mt 26"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_am_mt 28"; end
  end
  -- thunder_clap,if=active_enemies>=3
  if S.ThunderClap:IsCastable() and (EnemiesMeleeCount >= 3) then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_am_mt 30"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow thane_am_mt 32"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_am_mt 34"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_am_mt 36"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_am_mt 38"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind thane_am_mt 40"; end
  end
  -- slam
  if S.Slam:IsCastable() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam thane_am_mt 42"; end
  end
end

local function ThaneRAMT()
  -- recklessness,if=cooldown.avatar.remains<1&talent.titans_torment|!talent.titans_torment
  if CDsON() and S.Recklessness:IsCastable() and (S.Avatar:CooldownRemains() < 1 and S.TitansTorment:IsAvailable() or not S.TitansTorment:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer_ra_mt 2"; end
  end
  -- thunder_blast,if=buff.enrage.up
  if S.ThunderBlastAbility:IsReady() and (EnrageUp) then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast slayer_ra_mt 4"; end
  end
  -- avatar,if=(talent.titans_torment&(buff.enrage.up|talent.titanic_rage)&(debuff.champions_might.up|!talent.champions_might))|!talent.titans_torment&buff.enrage.up
  if CDsON() and S.Avatar:IsCastable() and ((S.TitansTorment:IsAvailable() and (EnrageUp or S.TitanicRage:IsAvailable()) and (Target:DebuffUp(S.ChampionsMightDebuff) or not S.ChampionsMight:IsAvailable())) or not S.TitansTorment:IsAvailable() and EnrageUp) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar thane_ra_mt 6"; end
  end
  -- thunder_clap,if=buff.meat_cleaver.stack=0&talent.meat_cleaver
  if S.ThunderClap:IsCastable() and (Player:BuffDown(S.MeatCleaverBuff) and S.MeatCleaver:IsAvailable()) then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_ra_mt 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar thane_ra_mt 10"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager thane_ra_mt 12"; end
  end
  -- champions_spear,if=buff.enrage.up
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear thane_ra_mt 14"; end
  end
  -- odyns_fury,if=dot.odyns_fury_torment_mh.remains<1&(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and (Target:DebuffRemains(S.OdynsFuryDebuff) < 1 and (EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury thane_ra_mt 16"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd&buff.enrage.up
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD() and EnrageUp) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_ra_mt 18"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (S.Bladestorm:IsLearned() and S.Bladestorm:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_mt 20"; end
  end
  -- bladestorm,if=buff.enrage.up
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm thane_ra_mt 22"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_ra_mt 24"; end
  end
  -- rampage,if=!buff.enrage.up
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_mt 26"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath thane_ra_mt 28"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow thane_ra_mt 30"; end
  end
  -- rampage,if=buff.recklessness.up|rage>115
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or Player:Rage() > 115) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_mt 32"; end
  end
  -- onslaught,if=talent.tenderize
  -- Note: Covered by the above onslaught suggestion.
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane_ra_mt 36"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane_ra_mt 38"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow thane_ra_mt 40"; end
  end
  -- onslaught
  if S.Onslaught:IsReady() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane_ra_mt 42"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane_ra_mt 44"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane_ra_mt 46"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind thane_ra_mt 48"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task
    -- use_item,name=treacherous_transmitter,if=variable.adds_remain|variable.st_planning
    if I.TreacherousTransmitter:IsEquippedAndReady() and (VarAddsRemain or VarSTPlanning) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&((talent.titans_torment&cooldown.avatar.ready)|(buff.avatar.up&!talent.titans_torment))&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket1CastTime > 0 or VarTrinket1CastTime == 0) and ((S.TitansTorment:IsAvailable() and S.Avatar:CooldownUp()) or (Player:BuffUp(S.AvatarBuff) and not S.TitansTorment:IsAvailable())) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= BossFightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&((talent.titans_torment&cooldown.avatar.ready)|(buff.avatar.up&!talent.titans_torment))&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket2CastTime > 0 or VarTrinket2CastTime == 0) and ((S.TitansTorment:IsAvailable() and S.Avatar:CooldownUp()) or (Player:BuffUp(S.AvatarBuff) and not S.TitansTorment:IsAvailable())) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= BossFightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for " .. Trinket2:Name() .. " trinkets 6"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) and not VarTrinket1Manual and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs) or (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) and not VarTrinket2Manual and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs) or (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for " .. Trinket2:Name() .. " trinkets 10"; end
    end
  end
  -- use_item,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  if Settings.Commons.Enabled.Items then
    -- Note: Adding a generic use_items for non-trinkets instead.
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 12"; end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
  VarSTPlanning = (EnemiesMeleeCount == 1)
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
  VarAddsRemain = (EnemiesMeleeCount >= 2)
  -- variable,name=execute_phase,value=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
  VarExecutePhase = (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20
  -- variable,name=on_gcd_racials,value=buff.recklessness.down&buff.avatar.down&rage<80&buff.bloodbath.down&buff.crushing_blow.down&buff.sudden_death.down&!cooldown.bladestorm.ready&(!cooldown.execute.ready|!variable.execute_phase)
  VarOnGCDRacials = Player:BuffDown(S.RecklessnessBuff) and Player:BuffDown(S.AvatarBuff) and Player:Rage() < 80 and Player:BuffDown(S.BloodbathBuff) and Player:BuffDown(S.CrushingBlowBuff) and Player:BuffDown(S.SuddenDeathBuff) and S.Bladestorm:CooldownDown() and (S.Execute:CooldownDown() or not VarExecutePhase)
end

--- ===== APL Main =====
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
  else
    EnemiesMeleeCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Enrage check
    EnrageUp = Player:BuffUp(S.EnrageBuff)

    -- Range check
    TargetInMeleeRange = Target:IsInRange(5)

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
    -- Manually added: battle_shout during combat
    if S.BattleShout:IsCastable() and Settings.Commons.ShoutDuringCombat and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
      if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout main 2"; end
    end
    -- auto_attack
    -- charge,if=time<=0.5|movement.distance>5
    if S.Charge:IsCastable() then
      if Cast(S.Charge, nil, Settings.CommonsDS.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 4"; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and not TargetInMeleeRange and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.CommonsDS.DisplayStyle.HeroicLeap) then return "heroic_leap main 6"; end
    end
    -- potion
    if CDsON() and Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 8"; end
      end
    end
    -- pummel,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.Pummel, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal 10"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal 12"; end
      end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=variables
    Variables()
    if CDsON() then
      -- lights_judgment,if=variable.on_gcd_racials
      if S.LightsJudgment:IsCastable() and (VarOnGCDRacials) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 16"; end
      end
      -- bag_of_tricks,if=variable.on_gcd_racials
      if S.BagofTricks:IsCastable() and (VarOnGCDRacials) then
        if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 17"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() and Player:BuffUp(S.RecklessnessBuff) then
        if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 18"; end
      end
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 20"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 22"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 24"; end
      end
      -- invoke_external_buff,name=power_infusion,if=buff.avatar.remains>15&fight_remains>=135|variable.execute_phase&buff.avatar.up|fight_remains<=25
      -- Note: Not handling external buffs.
    end
    -- Note: For below lines, using <2 instead of =1 to avoid losing suggestions when moving slightly out of range.
    -- Note: Re-ordered action list calls for better nesting.
    -- Note: If character has no hero talents, use Slayer.
    if S.SlayersDominance:IsAvailable() or Player:Level() < 71 then
      if S.RecklessAbandon:IsAvailable() then
        -- run_action_list,name=slayer_ra_st,if=talent.slayers_dominance&talent.reckless_abandon&active_enemies=1
        if EnemiesMeleeCount < 2 then
          local ShouldReturn = SlayerRAST(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerRAST()"; end
        end
        -- run_action_list,name=slayer_ra_mt,if=talent.slayers_dominance&talent.reckless_abandon&active_enemies>1
        if EnemiesMeleeCount > 1 then
          local ShouldReturn = SlayerRAMT(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerRAMT()"; end
        end
      end
      if S.AngerManagement:IsAvailable() then
        -- run_action_list,name=slayer_am_st,if=talent.slayers_dominance&talent.anger_management&active_enemies=1
        if EnemiesMeleeCount < 2 then
          local ShouldReturn = SlayerAMST(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerAMST()"; end
        end
        -- run_action_list,name=slayer_am_mt,if=talent.slayers_dominance&talent.anger_management&active_enemies>1
        if EnemiesMeleeCount > 1 then
          local ShouldReturn = SlayerAMMT(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerAMMT()"; end
        end
      end
    end
    if S.LightningStrikes:IsAvailable() then
      if S.RecklessAbandon:IsAvailable() then
        -- run_action_list,name=thane_ra_st,if=talent.lightning_strikes&talent.reckless_abandon&active_enemies=1
        if EnemiesMeleeCount < 2 then
          local ShouldReturn = ThaneRAST(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ThaneRAST()"; end
        end
        -- run_action_list,name=thane_ra_mt,if=talent.lightning_strikes&talent.reckless_abandon&active_enemies>1
        if EnemiesMeleeCount > 1 then
          local ShouldReturn = ThaneRAMT(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ThaneRAMT()"; end
        end
      end
      if S.AngerManagement:IsAvailable() then
        -- run_action_list,name=thane_am_st,if=talent.lightning_strikes&talent.anger_management&active_enemies=1
        if EnemiesMeleeCount < 2 then
          local ShouldReturn = ThaneAMST(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ThaneAMST()"; end
        end
        -- run_action_list,name=thane_am_mt,if=talent.lightning_strikes&talent.anger_management&active_enemies>1
        if EnemiesMeleeCount > 1 then
          local ShouldReturn = ThaneAMMT(); if ShouldReturn then return ShouldReturn; end
          if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ThaneAMMT()"; end
        end
      end
    end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Fury Warrior rotation has been updated for patch 11.0.5.")
end

HR.SetAPL(72, APL, Init)
