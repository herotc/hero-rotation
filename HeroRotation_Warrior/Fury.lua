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
  -- Trinkets
  I.TreacherousTransmitter:ID(),
  -- Items
  I.BestinSlots:ID(),
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
local BladestormAbility = S.UnrelentingOnslaught:IsAvailable() and S.SlayerBladestorm or S.Bladestorm
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
  BladestormAbility = S.UnrelentingOnslaught:IsAvailable() and S.SlayerBladestorm or S.Bladestorm
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Rotation Functions =====
local function Precombat()
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
    if Cast(S.BattleShout, nil, Settings.CommonsDS.DisplayStyle.BattleShout) then return "battle_shout precombat 4"; end
  end
  -- use_item,name=treacherous_transmitter
  if Settings.Commons.Enabled.Trinkets and I.TreacherousTransmitter:IsEquippedAndReady() then
    if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat 6"; end
  end
  -- recklessness,if=!equipped.fyralath_the_dreamrender
  if CDsON() and S.Recklessness:IsCastable() then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 8"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
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

local function Slayer()
  -- From below: Force StormBolt to the top while Bladestorm is up, as it's the only spell able to be cast.
  if S.StormBolt:IsReady() and (Player:BuffUp(BladestormAbility)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer 2"; end
  end
  -- recklessness
  if CDsON() and S.Recklessness:IsCastable() then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness slayer 4"; end
  end
  -- avatar,if=cooldown.recklessness.remains
  if CDsON() and S.Avatar:IsCastable() and (S.Recklessness:CooldownDown()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar slayer 6"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<=gcd
  if S.Execute:IsReady() and (Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 8"; end
  end
  -- champions_spear,if=buff.enrage.up&(cooldown.bladestorm.remains>=2|cooldown.bladestorm.remains>=16&debuff.marked_for_execution.stack=3)
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp and (BladestormAbility:CooldownRemains() >= 2 or BladestormAbility:CooldownRemains() >= 16 and Target:DebuffStack(S.MarkedforExecutionDebuff) == 3)) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear slayer 10"; end
  end
  -- ravager,if=buff.enrage.up
  if CDsON() and S.Ravager:IsCastable() and (EnrageUp) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager slayer 12"; end
  end
  -- bladestorm,if=buff.enrage.up&(talent.reckless_abandon&cooldown.avatar.remains>=24|talent.anger_management&cooldown.recklessness.remains>=18)
  if CDsON() and BladestormAbility:IsCastable() and (EnrageUp and (S.RecklessAbandon:IsAvailable() and S.Avatar:CooldownRemains() >= 24 or S.AngerManagement:IsAvailable() and S.Recklessness:CooldownRemains() >= 18)) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer 14"; end
  end
  -- odyns_fury,if=(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and ((EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury slayer 16"; end
  end
  -- whirlwind,if=active_enemies>=2&talent.meat_cleaver&buff.meat_cleaver.stack=0
  if S.Whirlwind:IsCastable() and (EnemiesMeleeCount >= 2 and S.MeatCleaver:IsAvailable() and Player:BuffDown(S.MeatCleaverBuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer 18"; end
  end
  -- execute,if=buff.sudden_death.stack=2&buff.sudden_death.remains<7
  if S.Execute:IsReady() and (Player:BuffStack(S.SuddenDeathBuff) == 2 and Player:BuffRemains(S.SuddenDeathBuff) < 7) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 20"; end
  end
  -- execute,if=buff.sudden_death.up&buff.sudden_death.remains<2
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) and Player:BuffRemains(S.SuddenDeathBuff) < 2) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 22"; end
  end
  -- execute,if=buff.sudden_death.up&buff.imminent_demise.stack<3&cooldown.bladestorm.remains<25
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) and Player:BuffStack(S.ImminentDemiseBuff) < 3 and BladestormAbility:CooldownRemains() < 25) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 24"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught slayer 26"; end
  end
  -- rampage,if=!buff.enrage.up|buff.slaughtering_strikes.stack>=4
  if S.Rampage:IsReady() and (not EnrageUp or Player:BuffStack(S.SlaughteringStrikesBuff) >= 4) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer 28"; end
  end
  -- crushing_blow,if=action.raging_blow.charges=2|buff.brutal_finish.up&(!debuff.champions_might.up|debuff.champions_might.up&debuff.champions_might.remains>gcd)
  -- Note: Simplified champions_might check. If DebuffRemains > GCD, then DebuffUp is true, so no need to check both.
  if S.CrushingBlow:IsCastable() and (S.RagingBlow:Charges() == 2 or Player:BuffUp(S.BrutalFinishBuff) and (Target:DebuffDown(S.ChampionsMightDebuff) or Target:DebuffRemains(S.ChampionsMightDebuff) > Player:GCD())) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow slayer 30"; end
  end
  -- thunderous_roar,if=buff.enrage.up&!buff.brutal_finish.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp and Player:BuffDown(S.BrutalFinishBuff)) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer 32"; end
  end
  -- execute,if=debuff.marked_for_execution.stack=3
  if S.Execute:IsReady() and (Target:DebuffStack(S.MarkedforExecutionDebuff) == 3) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 34"; end
  end
  -- bloodbath,if=buff.bloodcraze.stack>=1|(talent.uproar&dot.bloodbath_dot.remains<40&talent.bloodborne)|buff.enrage.up&buff.enrage.remains<gcd
  if S.Bloodbath:IsCastable() and (Player:BuffStack(S.BloodcrazeBuff) >= 1 or (S.Uproar:IsAvailable() and Target:DebuffRemains(S.BloodbathDebuff) < 40 and S.Bloodborne:IsAvailable()) or EnrageUp and Player:BuffRemains(S.EnrageBuff) < Player:GCD()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer_ra_st 36"; end
  end
  -- raging_blow,if=buff.brutal_finish.up&buff.slaughtering_strikes.stack<5&(!debuff.champions_might.up|debuff.champions_might.up&debuff.champions_might.remains>gcd)
  -- Note: Simplified champions_might check. If DebuffRemains > GCD, then DebuffUp is true, so no need to check both.
  if S.RagingBlow:IsCastable() and (Player:BuffUp(S.BrutalFinishBuff) and Player:BuffStack(S.SlaughteringStrikesBuff) < 5 and (Target:DebuffDown(S.ChampionsMightDebuff) or Target:DebuffRemains(S.ChampionsMightDebuff) > Player:GCD())) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer 38"; end
  end
  -- bloodthirst,if=active_enemies>3
  if S.Bloodthirst:IsCastable() and (EnemiesMeleeCount > 3) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer 40"; end
  end
  -- rampage,if=action.raging_blow.charges<=1&rage>=100&talent.anger_management&buff.recklessness.down
  if S.Rampage:IsReady() and (S.RagingBlow:Charges() <= 1 and Player:Rage() >= 100 and S.AngerManagement:IsAvailable() and Player:BuffDown(S.RecklessnessBuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer 42"; end
  end
  -- rampage,if=rage>=120|talent.reckless_abandon&buff.recklessness.up&buff.slaughtering_strikes.stack>=3
  if S.Rampage:IsReady() and (Player:Rage() >= 120 or S.RecklessAbandon:IsAvailable() and Player:BuffUp(S.RecklessnessBuff) and Player:BuffStack(S.SlaughteringStrikesBuff) >= 3) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer 44"; end
  end
  -- bloodbath,if=buff.bloodcraze.stack>=4|crit_pct_current>=85|active_enemies>2
  local CritPctCurrent = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.BloodcrazeBuff) * 15
  if S.Bloodbath:IsCastable() and (Player:BuffStack(S.BloodcrazeBuff) >= 4 or CritPctCurrent >= 85 or EnemiesMeleeCount > 2) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer 46"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow slayer 48"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath slayer 50"; end
  end
  -- raging_blow,if=buff.opportunist.up
  if S.RagingBlow:IsCastable() and (Player:BuffUp(S.OpportunistBuff)) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer 52"; end
  end
  -- bloodthirst,if=(target.health.pct<35&talent.vicious_contempt&buff.bloodcraze.stack>=2)|active_enemies>2
  if S.Bloodthirst:IsCastable() and ((Target:HealthPercentage() < 35 and S.ViciousContempt:IsAvailable() and Player:BuffStack(S.BloodcrazeBuff) >= 2) or EnemiesMeleeCount > 2) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer 54"; end
  end
  -- rampage,if=rage>=100&talent.anger_management&buff.recklessness.up
  if S.Rampage:IsReady() and (Player:Rage() >= 100 and S.AngerManagement:IsAvailable() or Player:BuffUp(S.RecklessnessBuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer 56"; end
  end
  -- bloodthirst,if=buff.bloodcraze.stack>=4|crit_pct_current>=85
  -- Note: crit_pct_current set in above bloodbath line.
  if S.Bloodthirst:IsCastable() and (Player:BuffStack(S.BloodcrazeBuff) >= 4 or CritPctCurrent >= 85) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer 58"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow slayer 60"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw slayer 62"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst slayer 64"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage slayer 66"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer 68"; end
  end
  -- whirlwind,if=talent.improved_whirlwind
  if S.Whirlwind:IsCastable() and (S.ImprovedWhirlwind:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind slayer 70"; end
  end
  -- slam,if=!talent.improved_whirlwind
  if S.Slam:IsCastable() and (not S.ImprovedWhirlwind:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer 72"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  -- Note: Moving to the top of the function, as it's the only spell able to be cast during Bladestorm.
end

local function Thane()
  -- recklessness
  if CDsON() and S.Recklessness:IsCastable() then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness thane 2"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar thane 4"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager thane 6"; end
  end
  -- thunder_blast,if=buff.enrage.up&talent.meat_cleaver
  if S.ThunderBlastAbility:IsReady() and (EnrageUp and S.MeatCleaver:IsAvailable()) then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast thane 8"; end
  end
  -- thunder_clap,if=buff.meat_cleaver.stack=0&talent.meat_cleaver&active_enemies>=2
  if S.ThunderClap:IsCastable() and (Player:BuffUp(S.MeatCleaverBuff) and S.MeatCleaver:IsAvailable() and EnemiesMeleeCount >= 2) then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane 10"; end
  end
  -- thunderous_roar,if=buff.enrage.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar thane 12"; end
  end
  -- champions_spear,if=buff.enrage.up
  if CDsON() and S.ChampionsSpear:IsCastable() and (EnrageUp) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not (Target:IsInRange(25) or TargetInMeleeRange)) then return "champions_spear thane 14"; end
  end
  -- odyns_fury,if=(buff.enrage.up|talent.titanic_rage)&cooldown.avatar.remains
  if CDsON() and S.OdynsFury:IsCastable() and ((EnrageUp or S.TitanicRage:IsAvailable()) and S.Avatar:CooldownDown()) then
    if Cast(S.OdynsFury, nil, Settings.CommonsDS.DisplayStyle.OdynsFury, not Target:IsInMeleeRange(12)) then return "odyns_fury thane 16"; end
  end
  -- rampage,if=buff.enrage.down
  if S.Rampage:IsReady() and (not EnrageUp) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane 18"; end
  end
  -- execute,if=talent.ashen_juggernaut&buff.ashen_juggernaut.remains<=gcd
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable() and Player:BuffRemains(S.AshenJuggernautBuff) <= Player:GCD()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane 20"; end
  end
  -- rampage,if=talent.bladestorm&cooldown.bladestorm.remains<=gcd&!debuff.champions_might.up
  if S.Rampage:IsReady() and (BladestormAbility:IsLearned() and BladestormAbility:CooldownRemains() <= Player:GCD() and Target:DebuffDown(S.ChampionsMightDebuff)) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane 22"; end
  end
  -- bladestorm,if=buff.enrage.up&talent.unhinged
  if CDsON() and BladestormAbility:IsCastable() and (EnrageUp and S.Unhinged:IsAvailable()) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm thane 24"; end
  end
  -- bloodbath,if=buff.bloodcraze.stack>=2
  if S.Bloodbath:IsCastable() and (Player:BuffStack(S.BloodcrazeBuff) >= 2) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath thane 26"; end
  end
  -- rampage,if=rage>=115&talent.reckless_abandon&buff.recklessness.up&buff.slaughtering_strikes.stack>=3
  if S.Rampage:IsReady() and (Player:Rage() >= 115 and S.RecklessAbandon:IsAvailable() and Player:BuffUp(S.RecklessnessBuff) and Player:BuffStack(S.SlaughteringStrikesBuff) >= 3) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane 28"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow thane 30"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath thane 32"; end
  end
  -- onslaught,if=talent.tenderize
  if S.Onslaught:IsReady() and (S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught thane 34"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage thane 36"; end
  end
  -- bloodthirst,if=talent.vicious_contempt&target.health.pct<35&buff.bloodcraze.stack>=2|!buff.ravager.up&buff.bloodcraze.stack>=3|active_enemies>=6
  if S.Bloodthirst:IsCastable() and (S.ViciousContempt:IsAvailable() and Target:HealthPercentage() < 35 and Player:BuffStack(S.BloodcrazeBuff) >= 2 or Target:DebuffDown(S.RavagerDebuff) and Player:BuffStack(S.BloodcrazeBuff) >= 3 or EnemiesMeleeCount >= 6) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane 38"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow thane 40"; end
  end
  -- execute,if=talent.ashen_juggernaut
  if S.Execute:IsReady() and (S.AshenJuggernaut:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane 42"; end
  end
  -- thunder_blast
  if S.ThunderBlastAbility:IsReady() then
    if Cast(S.ThunderBlastAbility, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_blast thane 44"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw thane 46"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst thane 48"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute thane 50"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsCastable() then
    if Cast(S.ThunderClap, nil, nil, not Target:IsInMeleeRange(8)) then return "thunder_clap thane 52"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task
    -- use_item,name=treacherous_transmitter,if=variable.adds_remain|variable.st_planning
    if I.TreacherousTransmitter:IsEquippedAndReady() and (VarAddsRemain or VarSTPlanning) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&buff.avatar.up&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket1CastTime > 0 or VarTrinket1CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= BossFightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&buff.avatar.up&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket2CastTime > 0 or VarTrinket2CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= BossFightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for " .. Trinket2:Name() .. " trinkets 6"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) and not VarTrinket1Manual and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs) or (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) and not VarTrinket2Manual and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs) or (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for " .. Trinket2:Name() .. " trinkets 10"; end
    end
  end
  -- use_item,slot=main_hand,if=!equipped.fyralath_the_dreamrender&!equipped.bestinslots&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  if Settings.Commons.Enabled.Items and ((not VarTrinket1Buffs or Trinket1:CooldownDown()) and (not VarTrinket2Buffs or Trinket2:CooldownDown())) then
    -- Note: Adding a generic use_items for non-trinkets instead.
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ItemToUse:ID() ~= I.BestinSlots:ID() then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 12"; end
    end
  end
  -- use_item,name=bestinslots,if=target.time_to_die>120&(cooldown.avatar.remains>20&(trinket.1.cooldown.remains|trinket.2.cooldown.remains)|cooldown.avatar.remains>20&(!trinket.1.has_cooldown|!trinket.2.has_cooldown))|target.time_to_die<=120&target.health.pct<35&cooldown.avatar.remains>85|target.time_to_die<15
  if Settings.Commons.Enabled.Items and I.BestinSlots:IsEquippedAndReady() and (Target:TimeToDie() > 120 and (S.Avatar:CooldownRemains() > 20 and (Trinket1:CooldownDown() or Trinket2:CooldownDown()) or S.Avatar:CooldownRemains() > 20 and (not Trinket1:HasCooldown() or not Trinket2:HasCooldown())) or Target:TimeToDie() <= 120 and Target:HealthPercentage() < 35 and S.Avatar:CooldownRemains() > 85 or Target:TimeToDie() < 15) then
    if Cast(I.BestinSlots, nil, Settings.CommonsDS.DisplayStyle.Items) then return "bestin_slots trinkets 14"; end
  end
end

local function Variables()
  -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
  VarSTPlanning = (EnemiesMeleeCount == 1)
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
  VarAddsRemain = (EnemiesMeleeCount >= 2)
  -- variable,name=execute_phase,value=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
  VarExecutePhase = (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20
  -- variable,name=on_gcd_racials,value=buff.recklessness.down&buff.avatar.down&rage<80&buff.sudden_death.down&!cooldown.bladestorm.ready&(!cooldown.execute.ready|!variable.execute_phase)
  VarOnGCDRacials = Player:BuffDown(S.RecklessnessBuff) and Player:BuffDown(S.AvatarBuff) and Player:Rage() < 80 and Player:BuffDown(S.SuddenDeathBuff) and BladestormAbility:CooldownDown() and (S.Execute:CooldownDown() or not VarExecutePhase)
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
    TargetInMeleeRange = Target:IsSpellInRange(S.Execute)

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
      if Cast(S.BattleShout, nil, Settings.CommonsDS.DisplayStyle.BattleShout) then return "battle_shout main 2"; end
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
    -- potion,if=target.time_to_die>300|target.time_to_die<300&target.health.pct<35&buff.recklessness.up|target.time_to_die<25
    if CDsON() and Settings.Commons.Enabled.Potions and (Target:TimeToDie() > 300 or Target:TimeToDie() < 300 and Target:HealthPercentage() < 35 and Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 25) then
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
        if Cast(S.VictoryRush, nil, Settings.CommonsDS.DisplayStyle.VictoryRush, not TargetInMeleeRange) then return "victory_rush heal 10"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, Settings.CommonsDS.DisplayStyle.VictoryRush, not TargetInMeleeRange) then return "impending_victory heal 12"; end
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
    -- Note: If character has no hero talents, use Slayer.
    -- run_action_list,name=slayer,if=talent.slayers_dominance
    if S.SlayersDominance:IsAvailable() or Player:Level() < 71 then
      local ShouldReturn = Slayer(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Slayer()"; end
    end
    -- run_action_list,name=thane,if=talent.lightning_strikes
    if S.LightningStrikes:IsAvailable() then
      local ShouldReturn = Thane(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Thane()"; end
    end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Fury Warrior rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(72, APL, Init)
