--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua
local mathmax       = math.max
-- WoW API
local Delay         = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Affliction
local I = Item.Warlock.Affliction

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- DF Trinkets
  I.TimeThiefsGambit:ID(),
  -- TWW Trinkets
  I.AberrantSpellforge:ID(),
  I.SpymastersWeb:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Warlock  = HR.Commons.Warlock
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  CommonsDS = HR.GUISettings.APL.Warlock.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warlock.CommonsOGCD,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

--- ===== Rotation Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1BuffDuration, VarTrinket2BuffDuration
local VarTrinketPriority
local VarCleaveAPL = Settings.Affliction.UseCleaveAPL
local Enemies40y, Enemies10ySplash, EnemiesCount10ySplash
local VarPSUp, VarVTUp, VarVTPSUp, VarSRUp, VarCDDoTsUp, VarHasCDs, VarCDsActive
local VarDoTsUp, VarMinAgony, VarMinVT, VarMinPS, VarMinPS1
local DSSB = (S.DrainSoulTalent:IsAvailable()) and S.DrainSoul or S.ShadowBolt
local ShadowEmbraceDebuff = S.DrainSoul:IsLearned() and S.ShadowEmbraceDSDebuff or S.ShadowEmbraceSBDebuff
local ShadowEmbraceMaxStack = S.DrainSoul:IsLearned() and 4 or 2
local SoulShards = 0
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

--- ===== Trinket Variables (from Precombat) =====
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

  -- If we don't have trinket items, try again in 2 seconds.
  if VarTrinketFailures < 5 and (T1.ID == 0 or T2.ID == 0) then
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
  if VarTrinket1Buffs and (VarTrinket1CD % 60 == 0 or 60 % VarTrinket1CD == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (VarTrinket2CD % 60 == 0 or 60 % VarTrinket2CD == 0) then
    VarTrinket2Sync = 1
  end

  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1ID == I.AberrantSpellforge:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.AberrantSpellforge:ID()

  VarTrinket1Exclude = VarTrinket1ID == 193757
  VarTrinket2Exclude = VarTrinket2ID == 193757

  VarTrinket1BuffDuration = Trinket1:BuffDuration() + (num(VarTrinket1ID == 207581) * 20)
  VarTrinket2BuffDuration = Trinket2:BuffDuration() + (num(VarTrinket2ID == 207581) * 20)

  -- Note: If BuffDuration is 0, set to 1 to avoid divide by zero errors.
  local T1BuffDur = VarTrinket1BuffDuration > 0 and VarTrinket1BuffDuration or 1
  local T2BuffDur = VarTrinket2BuffDuration > 0 and VarTrinket2BuffDuration or 1
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1+0.5*trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1+0.5*trinket.1.has_buff.intellect)*(variable.trinket_1_sync))
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
  DSSB = (S.DrainSoulTalent:IsAvailable()) and S.DrainSoul or S.ShadowBolt
  ShadowEmbraceDebuff = S.DrainSoul:IsLearned() and S.ShadowEmbraceDSDebuff or S.ShadowEmbraceSBDebuff
  ShadowEmbraceMaxStack = S.DrainSoul:IsLearned() and 4 or 2
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
local function CalcMinDoT(Enemies, Spell)
  -- cycling_variable,name=min_agony,op=min,value=dot.agony.remains+(99*!dot.agony.remains)
  -- cycling_variable,name=min_vt,op=min,default=10,value=dot.vile_taint.remains+(99*!dot.vile_taint.remains)
  -- cycling_variable,name=min_ps,op=min,default=16,value=dot.phantom_singularity.remains+(99*!dot.phantom_singularity.remains)
  if not Enemies or not Spell then return 0 end
  local LowestDoT
  for _, CycleUnit in pairs(Enemies) do
    local UnitDoT = CycleUnit:DebuffRemains(Spell) + (99 * num(CycleUnit:DebuffDown(Spell)))
    if LowestDoT == nil or UnitDoT < LowestDoT then
      LowestDoT = UnitDoT
    end
  end
  return LowestDoT or 0
end

local function CanSeed(Enemies)
  if not Enemies or #Enemies == 0 then return false end
  if S.SeedofCorruption:InFlight() or Player:PrevGCDP(1, S.SeedofCorruption) then return false end
  local TotalTargets = 0
  local SeededTargets = 0
  for _, CycleUnit in pairs(Enemies) do
    TotalTargets = TotalTargets + 1
    if CycleUnit:DebuffUp(S.SeedofCorruptionDebuff) then
      SeededTargets = SeededTargets + 1
    end
  end
  return (TotalTargets == SeededTargets)
end

local function DarkglareActive()
  return Warlock.GuardiansTable.DarkglareDuration > 0
end

local function DarkglareTime()
  return Warlock.GuardiansTable.DarkglareDuration
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterAgony(TargetUnit)
  -- target_if=remains
  return TargetUnit:DebuffRemains(S.AgonyDebuff)
end

local function EvaluateTargetIfFilterCorruption(TargetUnit)
  -- target_if=min:remains
  return TargetUnit:DebuffRemains(S.CorruptionDebuff)
end

local function EvaluateTargetIfFilterShadowEmbrace(TargetUnit)
  -- target_if=min:debuff.shadow_embrace.remains
  return TargetUnit:DebuffRemains(ShadowEmbraceDebuff)
end

local function EvaluateTargetIfFilterWither(TargetUnit)
  -- target_if=min:remains
  return TargetUnit:DebuffRemains(S.WitherDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfAgony(TargetUnit)
  -- if=active_dot.agony<8&(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&gcd.max+action.soul_rot.cast_time+gcd.max<(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)&remains<10
  -- Note: Non-DoT checks handled before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime() or not S.VileTaint:IsAvailable()) and TargetUnit:DebuffRemains(S.AgonyDebuff) < 10
end

local function EvaluateTargetIfAgony2(TargetUnit)
  -- if=(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&(remains<gcd.max*2|talent.demonic_soul&remains<cooldown.soul_rot.remains+8&cooldown.soul_rot.remains<5)&fight_remains>remains+5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime() or not S.VileTaint:IsAvailable()) and (TargetUnit:DebuffRemains(S.AgonyDebuff) < Player:GCD() * 2 or S.DemonicSoul:IsAvailable() and TargetUnit:DebuffRemains(S.AgonyDebuff) < S.SoulRot:CooldownRemains() + 8 and S.SoulRot:CooldownRemains() < 5) and FightRemains > TargetUnit:DebuffRemains(S.AgonyDebuff) + 5
end

local function EvaluateTargetIfCorruption(TargetUnit)
  -- if=remains<5
  return TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5
end

local function EvaluateTargetIfCorruption2(TargetUnit)
  -- if=remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)&fight_remains>remains+5
  return TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5 and not (S.SeedofCorruption:InFlight() or TargetUnit:DebuffUp(S.SeedofCorruptionDebuff)) and FightRemains > TargetUnit:DebuffRemains(S.CorruptionDebuff) + 5
end

local function EvaluateTargetIfDrainSoul(TargetUnit)
  -- if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  -- Note: buff.nightfall.react check done before CastTargetIf.
  return S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 3 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3) or not S.ShadowEmbrace:IsAvailable()
end

local function EvaluateTargetIfDrainSoul2(TargetUnit)
  -- if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<4|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  -- Note: buff.nightfall.react check done before CastTargetIf.
  return S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 4 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3) or not S.ShadowEmbrace:IsAvailable()
end

local function EvaluateTargetIfDrainSoul3(TargetUnit)
  -- if=talent.shadow_embrace&talent.drain_soul&(talent.wither|talent.demonic_soul&buff.nightfall.react)&(debuff.shadow_embrace.stack<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3)&fight_remains>15,interrupt_if=debuff.shadow_embrace.stack>3
  -- Note: Most checks done before CastTargetIf.
  return TargetUnit:DebuffStack(ShadowEmbraceDebuff) < ShadowEmbraceMaxStack or TargetUnit:DebuffRemains(ShadowEmbraceDebuff)
end

local function EvaluateTargetIfShadowBolt(TargetUnit)
  -- if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<2|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  -- Note: buff.nightfall.react check done before CastTargetIf.
  return S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 2 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3) or not S.ShadowEmbrace:IsAvailable()
end

local function EvaluateTargetIfShadowBolt2(TargetUnit)
  -- if=talent.shadow_embrace&!talent.drain_soul&((debuff.shadow_embrace.stack+action.shadow_bolt.in_flight_to_target_count)<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3&!action.shadow_bolt.in_flight_to_target)&fight_remains>15
  -- Note: Most checks done before CastTargetIf.
  return (TargetUnit:DebuffStack(ShadowEmbraceDebuff) + num(S.ShadowBolt:InFlight())) < ShadowEmbraceMaxStack or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3 and not S.ShadowBolt:InFlight()
end

local function EvaluateTargetIfWither(TargetUnit)
  -- if=remains<5&!talent.seed_of_corruption
  return TargetUnit:DebuffRemains(S.WitherDebuff) < 5
end

local function EvaluateTargetIfWither2(TargetUnit)
  -- if=remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)&fight_remains>remains+5
  return TargetUnit:DebuffRemains(S.WitherDebuff) < 5 and not (S.SeedofCorruption:InFlight() or TargetUnit:DebuffUp(S.SeedofCorruptionDebuff)) and FightRemains > TargetUnit:DebuffRemains(S.WitherDebuff) + 5
end

--- ===== CastCycle Functions =====
local function EvaluateCycleAgonyRefreshable(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.AgonyDebuff)
end

local function EvaluateCycleCorruptionRefreshable(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.CorruptionDebuff)
end

local function EvaluateCycleDrainSoul(TargetUnit)
  -- if=talent.drain_soul&buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<4|debuff.shadow_embrace.remains<3)
  -- Note: Non-debuff checks done before CastCycle.
  return TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 4 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3
end

local function EvaluateCycleDrainSoul2(TargetUnit)
  -- if=talent.drain_soul&(talent.shadow_embrace&(debuff.shadow_embrace.stack<4|debuff.shadow_embrace.remains<3))|!talent.shadow_embrace
  return (S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 4 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3)) or not S.ShadowEmbrace:IsAvailable()
end

local function EvaluateCycleShadowBolt(TargetUnit)
  -- if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<2|debuff.shadow_embrace.remains<3)
  -- Note: Non-debuff checks done before CastCycle.
  return TargetUnit:DebuffStack(ShadowEmbraceDebuff) < 2 or TargetUnit:DebuffRemains(ShadowEmbraceDebuff) < 3
end

local function EvaluateCycleWitherRefreshable(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.WitherDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet - Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.spymasters_web|trinket.1.is.aberrant_spellforge
  -- variable,name=trinket_2_manual,value=trinket.2.is.spymasters_web|trinket.2.is.aberrant_spellforge
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.mirror_of_fractured_tomorrows*20)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.mirror_of_fractured_tomorrows*20)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1+0.5*trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1+0.5*trinket.1.has_buff.intellect)*(variable.trinket_1_sync))
  -- Note: Trinket variables moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>2|spell_targets.seed_of_corruption_aoe>1&talent.demonic_soul
  -- NYI precombat multi target
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt precombat 4"; end
  end
  -- Manually added: unstable_affliction
  if S.UnstableAffliction:IsReady() then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 6"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=aberrant_spellforge,use_off_gcd=1,if=gcd.remains>gcd.max*0.8
    -- Note: Ignoring gcd.remains check, as it flickers too much in practice.
    if I.AberrantSpellforge:IsEquippedAndReady() then
      if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge items 2"; end
    end
    -- use_item,name=spymasters_web,if=variable.cd_dots_up&(buff.spymasters_report.stack>=38|fight_remains<=80|talent.drain_soul&target.health.pct<20)|fight_remains<20
    if I.SpymastersWeb:IsEquippedAndReady() and (VarCDDoTsUp and (Player:BuffStack(S.SpymastersReportBuff) >= 38 or FightRemains <= 80 or S.DrainSoul:IsAvailable() and Target:HealthPercentage() < 20 ) or BossFightRemains < 20) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web items 4"; end
    end
    -- use_item,slot=trinket1,if=(variable.cds_active)&(variable.trinket_priority=1|variable.trinket_2_exclude|!trinket.2.has_cooldown|(trinket.2.cooldown.remains|variable.trinket_priority=2&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.2.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_1_buffs&!variable.trinket_1_manual|(variable.trinket_1_buff_duration+1>=fight_remains)
    if Trinket1:IsReady() and not VarTrinket1BL and (VarCDsActive and (VarTrinketPriority == 1 or VarTrinket2Exclude or not Trinket2:HasCooldown() or (Trinket2:CooldownDown() or VarTrinketPriority == 2 and S.SummonDarkglare:CooldownRemains() > 20 and not DarkglareActive() and Trinket2:CooldownRemains() < S.SummonDarkglare:CooldownRemains())) and VarTrinket1Buffs and not VarTrinket1Manual or (VarTrinket1BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 6"; end
    end
    -- use_item,slot=trinket2,if=(variable.cds_active)&(variable.trinket_priority=2|variable.trinket_1_exclude|!trinket.1.has_cooldown|(trinket.1.cooldown.remains|variable.trinket_priority=1&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.1.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_2_buffs&!variable.trinket_2_manual|(variable.trinket_2_buff_duration+1>=fight_remains)
    if Trinket2:IsReady() and not VarTrinket2BL and (VarCDsActive and (VarTrinketPriority == 2 or VarTrinket1Exclude or not Trinket1:HasCooldown() or (Trinket1:CooldownDown() or VarTrinketPriority == 1 and S.SummonDarkglare:CooldownRemains() > 20 and not DarkglareActive() and Trinket1:CooldownRemains() < S.SummonDarkglare:CooldownRemains())) and VarTrinket2Buffs and not VarTrinket2Manual or (VarTrinket2BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 8"; end
    end
    -- use_item,name=time_thiefs_gambit,if=variable.cds_active|fight_remains<15|((trinket.1.cooldown.duration<cooldown.summon_darkglare.remains_expected+5)&active_enemies=1)|(active_enemies>1&havoc_active)
    -- Note: I believe havoc_active is a copy/paste error, since Havoc is a Destruction spec thing...
    if I.TimeThiefsGambit:IsEquippedAndReady() and (VarCDsActive or BossFightRemains < 15 or ((Trinket1:Cooldown() < S.SummonDarkglare:CooldownRemains() + 5) and EnemiesCount10ySplash == 1) or (EnemiesCount10ySplash > 1)) then
      if Cast(I.TimeThiefsGambit, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "time_thiefs_gambit items 10"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs) or S.SummonDarkglare:IsAvailable() and S.SummonDarkglare:CooldownRemains() > 20 or not S.SummonDarkglare:IsAvailable())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 12"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs) or S.SummonDarkglare:IsAvailable() and S.SummonDarkglare:CooldownRemains() > 20 or not S.SummonDarkglare:IsAvailable())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 12"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=main_hand
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " items 14"; end
    end
  end
end

local function oGCD()
  local SRTime = Player:PrevGCDP(1, S.SoulRot) and HL.CombatTime() < 20
  -- potion,if=variable.cds_active|fight_remains<32|prev_gcd.1.soul_rot&time<20
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (VarCDsActive or BossFightRemains < 32 or SRTime) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ogcd 2"; end
    end
  end
  -- berserking,if=variable.cds_active|fight_remains<14|prev_gcd.1.soul_rot&time<20
  if S.Berserking:IsCastable() and (VarCDsActive or BossFightRemains < 14 or SRTime) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking ogcd 4"; end
  end
  -- blood_fury,if=variable.cds_active|fight_remains<17|prev_gcd.1.soul_rot&time<20
  if S.BloodFury:IsCastable() and (VarCDsActive or BossFightRemains < 17 or SRTime) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 6"; end
  end
  -- invoke_external_buff,name=power_infusion,if=variable.cds_active
  -- Note: Not handling external buffs
  -- fireblood,if=variable.cds_active|fight_remains<10|prev_gcd.1.soul_rot&time<20
  if S.Fireblood:IsCastable() and (VarCDsActive or BossFightRemains < 10 or SRTime) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood ogcd 8"; end
  end
  -- ancestral_call,if=variable.cds_active|fight_remains<17|prev_gcd.1.soul_rot&time<20
  if S.AncestralCall:IsCastable() and (VarCDsActive or BossFightRemains < 17 or SRTime) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call ogcd 10"; end
  end
end

local function EndofFight()
  -- drain_soul,if=talent.demonic_soul&(fight_remains<5&buff.nightfall.react|prev_gcd.1.haunt&buff.nightfall.react=2&!buff.tormented_crescendo.react)
  if S.DrainSoul:IsReady() and (S.DemonicSoul:IsAvailable() and (BossFightRemains < 5 and Player:BuffUp(S.NightfallBuff) or Player:PrevGCDP(1, S.Haunt) and Player:BuffStack(S.NightfallBuff) == 2 and Player:BuffDown(S.TormentedCrescendoBuff))) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul end_of_fight 2"; end
  end
  -- oblivion,if=soul_shard>1&fight_remains<(soul_shard+buff.tormented_crescendo.react)*gcd.max+execute_time
  if S.Oblivion:IsReady() and (SoulShards > 1 and BossFightRemains < (SoulShards + Player:BuffStack(S.TormentedCrescendoBuff)) * GCDMax + S.Oblivion:ExecuteTime()) then
    if Cast(S.Oblivion, nil, nil, not Target:IsSpellInRange(S.Oblivion)) then return "oblivion end_of_fight 4"; end
  end
  -- malefic_rapture,if=fight_remains<4&(!talent.demonic_soul|talent.demonic_soul&buff.nightfall.react<1)
  if S.MaleficRapture:IsReady() and (BossFightRemains < 4 and (not S.DemonicSoul:IsAvailable() or S.DemonicSoul:IsAvailable() and Player:BuffDown(S.NightfallBuff))) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture end_of_fight 6"; end
  end
end

local function AoE()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- cycling_variable,name=min_agony,op=min,value=dot.agony.remains+(99*!dot.agony.remains)
  -- cycling_variable,name=min_vt,op=min,default=10,value=dot.vile_taint.remains+(99*!dot.vile_taint.remains)
  -- cycling_variable,name=min_ps,op=min,default=16,value=dot.phantom_singularity.remains+(99*!dot.phantom_singularity.remains)
  -- variable,name=min_ps1,op=set,value=(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)
  -- Calculating these in APL() so they're calculated each cycle.
  -- haunt,if=debuff.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt aoe 2"; end
  end
  -- vile_taint,if=(cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25)
  if S.VileTaint:IsReady() and (S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25) then
    if Cast(S.VileTaint, Settings.Affliction.GCDasOffGCD.VileTaint, nil, not Target:IsInRange(40)) then return "vile_taint aoe 4"; end
  end
  -- phantom_singularity,if=(cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25)&dot.agony.remains
  if S.PhantomSingularity:IsCastable() and ((S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25) and Target:DebuffUp(S.AgonyDebuff)) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity aoe 6"; end
  end
  -- unstable_affliction,if=remains<5
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction aoe 8"; end
  end
  -- agony,target_if=min:remains,if=active_dot.agony<8&(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&gcd.max+action.soul_rot.cast_time+gcd.max<(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)&remains<10
  if S.Agony:IsReady() and (S.AgonyDebuff:AuraActiveCount() < 8 and GCDMax + S.SoulRot:CastTime() + GCDMax < (VarMinVT * mathmax(num(S.VileTaint:IsAvailable()), VarMinPS) * num(S.PhantomSingularity:IsAvailable()))) then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 10"; end
  end
  -- soul_rot,if=variable.vt_up&(variable.ps_up|variable.vt_up)&dot.agony.remains
  if S.SoulRot:IsReady() and (VarVTUp and (VarPSUp or VarVTUp) and Target:DebuffUp(S.AgonyDebuff)) then
    if Cast(S.SoulRot, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot aoe 12"; end
  end
  -- malevolence,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  -- Note: Not handling invoke_power_infusion_0.
  if S.Malevolence:IsReady() and (VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.Malevolence, Settings.Affliction.GCDasOffGCD.Malevolence) then return "malevolence aoe 14"; end
  end
  -- seed_of_corruption,if=((!talent.wither&dot.corruption.remains<5)|(talent.wither&dot.wither.remains<5))&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)
  if S.SeedofCorruption:IsReady() and (((not S.Wither:IsAvailable() and Target:DebuffRemains(S.CorruptionDebuff) < 5) or (S.Wither:IsAvailable() and Target:DebuffRemains(S.WitherDebuff) < 5)) and not (S.SeedofCorruption:InFlight() or Target:DebuffUp(S.SeedofCorruptionDebuff))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 16"; end
  end
  -- corruption,target_if=min:remains,if=remains<5&!talent.seed_of_corruption
  if S.Corruption:IsReady() and (not S.SeedofCorruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption aoe 18"; end
  end
  -- wither,target_if=min:remains,if=remains<5&!talent.seed_of_corruption
  if S.Wither:IsReady() and (not S.SeedofCorruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.Wither, Enemies40y, "min", EvaluateTargetIfFilterWither, EvaluateTargetIfWither, not Target:IsInRange(40)) then return "wither aoe 20"; end
  end
  -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  -- Note: Not handling Power Infusion
  if CDsON() and S.SummonDarkglare:IsCastable() and (VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare aoe 22"; end
  end
  if S.MaleficRapture:IsReady() and (
    -- malefic_rapture,if=(cooldown.summon_darkglare.remains>15|soul_shard>3|(talent.demonic_soul&soul_shard>2))&buff.tormented_crescendo.up
    ((S.SummonDarkglare:CooldownRemains() > 15 or SoulShards > 3 or (S.DemonicSoul:IsAvailable() and SoulShards > 2)) and Player:BuffUp(S.TormentedCrescendoBuff)) or 
    -- malefic_rapture,if=soul_shard>4|(talent.tormented_crescendo&buff.tormented_crescendo.react=1&soul_shard>3)
    (SoulShards > 4 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 3)) or
    -- malefic_rapture,if=talent.demonic_soul&(soul_shard>2|(talent.tormented_crescendo&buff.tormented_crescendo.react=1&soul_shard))
    (S.DemonicSoul:IsAvailable() and (SoulShards > 2 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 0))) or
    -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react
    (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff)) or
    -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react=2
    -- Note: This line is covered by the one above it.
    --(S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 2) or
    -- malefic_rapture,if=(variable.cd_dots_up|variable.vt_ps_up)&(soul_shard>2|cooldown.oblivion.remains>10|!talent.oblivion)
    ((VarCDDoTsUp or VarVTPSUp) and (SoulShards > 2 or S.Oblivion:CooldownRemains() > 10 or not S.Oblivion:IsAvailable())) or
    -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react
    (S.TormentedCrescendo:IsAvailable() and S.Nightfall:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff))    
  ) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 24"; end
  end
  -- drain_soul,interrupt_if=cooldown.vile_taint.ready,if=talent.drain_soul&buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<4|debuff.shadow_embrace.remains<3)
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff) and S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(ShadowEmbraceDebuff) < 4 or Target:DebuffRemains(ShadowEmbraceDebuff) < 3)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul aoe 26"; end
  end
  -- drain_soul,interrupt_if=cooldown.vile_taint.ready,interrupt_global=1,if=talent.drain_soul&(talent.shadow_embrace&(debuff.shadow_embrace.stack<4|debuff.shadow_embrace.remains<3))|!talent.shadow_embrace
  if S.DrainSoul:IsReady() and ((S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(ShadowEmbraceDebuff) < 4 or Target:DebuffRemains(ShadowEmbraceDebuff) < 3)) or not S.ShadowEmbrace:IsAvailable()) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul aoe 28"; end
  end
  -- shadow_bolt,if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<2|debuff.shadow_embrace.remains<3)
  if S.ShadowBolt:IsReady() and (Player:BuffUp(S.NightfallBuff) and S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(ShadowEmbraceDebuff) < 2 or Target:DebuffRemains(ShadowEmbraceDebuff) < 3)) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt aoe 30"; end
  end
end

local function OpenerCleaveSE()
  -- drain_soul,if=talent.shadow_embrace&talent.drain_soul&buff.nightfall.react&(debuff.shadow_embrace.stack<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3)&(fight_remains>15|time<20),interrupt_if=debuff.shadow_embrace.stack=debuff.shadow_embrace.max_stack
  if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and Player:BuffUp(S.NightfallBuff) and (Target:DebuffStack(ShadowEmbraceDebuff) < ShadowEmbraceMaxStack or Target:DebuffRemains(ShadowEmbraceDebuff) < 3) and (FightRemains > 15 or HL.CombatTime() < 20)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul opener_cleave_se 2"; end
  end
end

local function CleaveSEMaintenance()
  -- drain_soul,target_if=min:debuff.shadow_embrace.remains,if=talent.shadow_embrace&talent.drain_soul&(talent.wither|talent.demonic_soul&buff.nightfall.react)&(debuff.shadow_embrace.stack<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3)&fight_remains>15,interrupt_if=debuff.shadow_embrace.stack>3
  if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (S.Wither:IsAvailable() or S.DemonicSoul:IsAvailable() and Player:BuffUp(S.NightfallBuff)) and FightRemains > 15) then
    if Everyone.CastTargetIf(S.DrainSoul, Enemies10ySplash, "min", EvaluateTargetIfFilterShadowEmbrace, EvaluateTargetIfDrainSoul3, not Target:IsInRange(40)) then return "drain_soul cleave_se_maintenance 2"; end
  end
  -- shadow_bolt,target_if=min:debuff.shadow_embrace.remains,if=talent.shadow_embrace&!talent.drain_soul&((debuff.shadow_embrace.stack+action.shadow_bolt.in_flight_to_target_count)<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3&!action.shadow_bolt.in_flight_to_target)&fight_remains>15
  if S.ShadowBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and not S.DrainSoul:IsAvailable() and FightRemains > 15) then
    if Everyone.CastTargetIf(S.ShadowBolt, Enemies10ySplash, "min", EvaluateTargetIfFilterShadowEmbrace, EvaluateTargetIfShadowBolt2, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave_se_maintenance 4"; end
  end
end

local function Cleave()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=end_of_fight
  local ShouldReturn = EndofFight(); if ShouldReturn then return ShouldReturn; end
  -- agony,target_if=min:remains,if=(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&(remains<gcd.max*2|talent.demonic_soul&remains<cooldown.soul_rot.remains+8&cooldown.soul_rot.remains<5)&fight_remains>remains+5
  if S.Agony:IsReady() then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony2, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 2"; end
  end
  -- wither,target_if=min:remains,if=remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)&fight_remains>remains+5
  if S.Wither:IsReady() then
    if Everyone.CastTargetIf(S.Wither, Enemies40y, "min", EvaluateTargetIfFilterWither, EvaluateTargetIfWither2, not Target:IsInRange(40)) then return "wither cleave 4"; end
  end
  -- haunt,if=talent.demonic_soul&buff.nightfall.react<2-prev_gcd.1.drain_soul&(!talent.vile_taint|cooldown.vile_taint.remains)|debuff.haunt.remains<3
  if S.Haunt:IsReady() and (S.DemonicSoul:IsAvailable() and Player:BuffStack(S.NightfallBuff) < 2 - num(Player:PrevGCDP(1, S.DrainSoul)) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) or Target:DebuffRemains(S.HauntDebuff)) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt cleave 6"; end
  end
  -- unstable_affliction,if=(remains<5|talent.demonic_soul&remains<cooldown.soul_rot.remains+8&cooldown.soul_rot.remains<5)&fight_remains>remains+5
  if S.UnstableAffliction:IsReady() and ((Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5 or S.DemonicSoul:IsAvailable() and Target:DebuffRemains(S.UnstableAfflictionDebuff) < S.SoulRot:CooldownRemains() + 8 and S.SoulRot:CooldownRemains() < 5) and FightRemains > Target:DebuffRemains(S.UnstableAfflictionDebuff) + 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction cleave 8"; end
  end
  -- corruption,target_if=min:remains,if=remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)&fight_remains>remains+5
  if S.Corruption:IsReady() then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption2, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 10"; end
  end
  -- call_action_list,name=cleave_se_maintenance,if=talent.wither
  if S.Wither:IsAvailable() then
    local ShouldReturn = CleaveSEMaintenance(); if ShouldReturn then return ShouldReturn; end
  end
  -- vile_taint,if=!talent.soul_rot|(variable.min_agony<1.5|cooldown.soul_rot.remains<=execute_time+gcd.max)|cooldown.soul_rot.remains>=20
  if S.VileTaint:IsReady() and (not S.SoulRot:IsAvailable() or (VarMinAgony < 1.5 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() + GCDMax) or S.SoulRot:CooldownRemains() >= 20) then
    if Cast(S.VileTaint, Settings.Affliction.GCDasOffGCD.VileTaint, nil, not Target:IsInRange(40)) then return "vile_taint cleave 12"; end
  end
  -- phantom_singularity,if=(!talent.soul_rot|cooldown.soul_rot.remains<4|fight_remains<cooldown.soul_rot.remains)&active_dot.agony=2
  if S.PhantomSingularity:IsReady() and ((not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() < 4 or FightRemains < S.SoulRot:CooldownRemains()) and S.AgonyDebuff:AuraActiveCount() == 2) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity cleave 14"; end
  end
  if VarVTPSUp and CDsON() then
    -- malevolence,if=variable.vt_ps_up
    if S.Malevolence:IsReady() then
      if Cast(S.Malevolence, Settings.Affliction.GCDasOffGCD.Malevolence) then return "malevolence cleave 16"; end
    end
    -- soul_rot,if=(variable.vt_ps_up)&active_dot.agony=2
    if S.SoulRot:IsReady() and (S.AgonyDebuff:AuraActiveCount() == 2) then
      if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot cleave 18"; end
    end
  end
  -- summon_darkglare,if=variable.cd_dots_up
  if CDsON() and S.SummonDarkglare:IsReady() and (VarCDDoTsUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare cleave 20"; end
  end
  if S.DemonicSoul:IsAvailable() then
    -- call_action_list,name=opener_cleave_se,if=talent.demonic_soul
    local ShouldReturn = OpenerCleaveSE(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cleave_se_maintenance,if=talent.demonic_soul
    local ShouldReturn = CleaveSEMaintenance(); if ShouldReturn then return ShouldReturn; end
  end
  -- malefic_rapture,if=soul_shard>4&(talent.demonic_soul&buff.nightfall.react<2|!talent.demonic_soul)|buff.tormented_crescendo.react>1
  if S.MaleficRapture:IsReady() and (SoulShards > 4 and (S.DemonicSoul:IsAvailable() and Player:BuffStack(S.NightfallBuff) < 2 or not S.DemonicSoul:IsAvailable()) or Player:BuffStack(S.TormentedCrescendoBuff) > 1) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 22"; end
  end
  -- drain_soul,if=talent.demonic_soul&buff.nightfall.react&buff.tormented_crescendo.react<2&target.health.pct<20
  if S.DrainSoul:IsReady() and (S.DemonicSoul:IsAvailable() and Player:BuffUp(S.NightfallBuff) and Player:BuffStack(S.TormentedCrescendoBuff) < 2 and Target:HealthPercentage() < 20) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul cleave 24"; end
  end
  if S.MaleficRapture:IsReady() and (
    -- malefic_rapture,if=talent.demonic_soul&(soul_shard>1|buff.tormented_crescendo.react&cooldown.soul_rot.remains>buff.tormented_crescendo.remains*gcd.max)&(!talent.vile_taint|soul_shard>1&cooldown.vile_taint.remains>10)&(!talent.oblivion|cooldown.oblivion.remains>10|soul_shard>2&cooldown.oblivion.remains<10)
    (S.DemonicSoul:IsAvailable() and (SoulShards > 1 or Target:BuffUp(S.TormentedCrescendoBuff) and S.SoulRot:CooldownRemains() > Player:BuffRemains(S.TormentedCrescendoBuff) * GCDMax) and (not S.VileTaint:IsAvailable() or SoulShards > 1 and S.VileTaint:CooldownRemains() > 10) and (not S.Oblivion:IsAvailable() or S.Oblivion:CooldownRemains() > 10 or SoulShards > 2 and S.Oblivion:CooldownRemains() < 10)) or
    -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react&(buff.tormented_crescendo.remains<gcd.max*2|buff.tormented_crescendo.react=2)
    (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and (Player:BuffRemains(S.TormentedCrescendoBuff) < GCDMax * 2 or Player:BuffStack(S.TormentedCrescendoBuff) == 2)) or
    -- malefic_rapture,if=(variable.cd_dots_up|(talent.demonic_soul|talent.phantom_singularity)&variable.vt_ps_up|talent.wither&variable.vt_ps_up&!dot.soul_rot.remains&soul_shard>1)&(!talent.oblivion|cooldown.oblivion.remains>10|soul_shard>2&cooldown.oblivion.remains<10)
    ((VarCDDoTsUp or (S.DemonicSoul:IsAvailable() or S.PhantomSingularity:IsAvailable()) and VarVTPSUp or S.Wither:IsAvailable() and VarVTPSUp and Target:DebuffDown(S.SoulRotDebuff) and SoulShards > 1) and (not S.Oblivion:IsAvailable() or S.Oblivion:CooldownRemains() > 10 or SoulShards > 2 and S.Oblivion:CooldownRemains() < 10)) or
    -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react|talent.demonic_soul&!buff.nightfall.react&(!talent.vile_taint|cooldown.vile_taint.remains>10|soul_shard>1&cooldown.vile_taint.remains<10)
    (S.TormentedCrescendo:IsAvailable() and S.NightfallBuff:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff) or S.DemonicSoul:IsAvailable() and Player:BuffDown(S.NightfallBuff) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownRemains() > 10 or SoulShards > 1 and S.VileTaint:CooldownRemains() < 10)) or
    -- malefic_rapture,if=!talent.demonic_soul&buff.tormented_crescendo.react
    (S.DemonicSoul:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff))
  ) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 26"; end
  end
  -- agony,if=refreshable|cooldown.soul_rot.remains<5&remains<8
  if S.Agony:IsReady() and (Target:DebuffRefreshable(S.AgonyDebuff) or S.SoulRot:CooldownRemains() < 5 and Target:DebuffRemains(S.AgonyDebuff)) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 28"; end
  end
  -- unstable_affliction,if=refreshable|cooldown.soul_rot.remains<5&remains<8
  if S.UnstableAffliction:IsReady() and (Target:DebuffRefreshable(S.UnstableAfflictionDebuff) or S.SoulRot:CooldownRemains() < 5 and Target:DebuffRemains(S.UnstableAfflictionDebuff) < 8) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction cleave 30"; end
  end
  if Player:BuffUp(S.NightfallBuff) then
    -- drain_soul,if=buff.nightfall.react
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul cleave 32"; end
    end
    -- shadow_bolt,if=buff.nightfall.react
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave 34"; end
    end
  end
  -- wither,if=refreshable
  if S.Wither:IsReady() and (Target:DebuffRefreshable(S.WitherDebuff)) then
    if Cast(S.Wither, nil, nil, not Target:IsInRange(40)) then return "wither cleave 36"; end
  end
  -- corruption,if=refreshable
  if S.Corruption:IsReady() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 38"; end
  end
  -- drain_soul,chain=1,early_chain_if=buff.nightfall.react,interrupt_if=tick_time>0.5
  -- TODO: Handle early_chain_if. Otherwise, this condition is covered by the 4th line above.
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsInRange(40)) then return "shadow_bolt cleave 40"; end
  end
end

local function SEMaintenance()
  -- drain_soul,interrupt=1,if=talent.shadow_embrace&talent.drain_soul&(debuff.shadow_embrace.stack<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3)&active_enemies<=4&fight_remains>15,interrupt_if=debuff.shadow_embrace.stack=debuff.shadow_embrace.max_stack
  if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(ShadowEmbraceDebuff) < ShadowEmbraceMaxStack or Target:DebuffRemains(ShadowEmbraceDebuff) < 3) and EnemiesCount10ySplash <= 4 and FightRemains > 15) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul se_maintenance 2"; end
  end
  -- shadow_bolt,if=talent.shadow_embrace&((debuff.shadow_embrace.stack+action.shadow_bolt.in_flight_to_target_count)<debuff.shadow_embrace.max_stack|debuff.shadow_embrace.remains<3&!action.shadow_bolt.in_flight_to_target)&active_enemies<=4&fight_remains>15
  if S.ShadowBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and ((Target:DebuffStack(ShadowEmbraceDebuff) + num(S.ShadowBolt:InFlight() or Player:IsCasting(S.ShadowBolt))) < ShadowEmbraceMaxStack or Target:DebuffRemains(ShadowEmbraceDebuff) < 3 and not S.ShadowBolt:InFlight()) and EnemiesCount10ySplash <= 4 and FightRemains > 15) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt se_maintenance 4"; end
  end
end

local function Variables()
  -- variable,name=ps_up,op=set,value=!talent.phantom_singularity|dot.phantom_singularity.remains
  VarPSUp = not S.PhantomSingularity:IsAvailable() or Target:DebuffUp(S.PhantomSingularityDebuff)
  -- variable,name=vt_up,op=set,value=!talent.vile_taint|dot.vile_taint_dot.remains
  VarVTUp = not S.VileTaint:IsAvailable() or Target:DebuffUp(S.VileTaintDebuff)
  -- variable,name=vt_ps_up,op=set,value=(!talent.vile_taint&!talent.phantom_singularity)|dot.vile_taint_dot.remains|dot.phantom_singularity.remains
  VarVTPSUp = (not S.VileTaint:IsAvailable() and not S.PhantomSingularity:IsAvailable()) or Target:DebuffUp(S.VileTaintDebuff) or Target:DebuffUp(S.PhantomSingularityDebuff)
  -- variable,name=sr_up,op=set,value=!talent.soul_rot|dot.soul_rot.remains
  VarSRUp = not S.SoulRot:IsAvailable() or Target:DebuffUp(S.SoulRotDebuff)
  -- variable,name=cd_dots_up,op=set,value=variable.ps_up&variable.vt_up&variable.sr_up
  VarCDDoTsUp = (VarPSUp and VarVTUp and VarSRUp)
  -- variable,name=has_cds,op=set,value=talent.phantom_singularity|talent.vile_taint|talent.soul_rot|talent.summon_darkglare
  VarHasCDs = (S.PhantomSingularity:IsAvailable() or S.VileTaint:IsAvailable() or S.SoulRot:IsAvailable() or S.SummonDarkglare:IsAvailable())
  -- variable,name=cds_active,op=set,value=!variable.has_cds|(variable.cd_dots_up&(!talent.summon_darkglare|cooldown.summon_darkglare.remains>20|pet.darkglare.remains))
  VarCDsActive = not VarHasCDs or (VarCDDoTsUp and (not S.SummonDarkglare:IsAvailable() or S.SummonDarkglare:CooldownRemains() > 20 or DarkglareActive()))
  -- variable,name=min_vt,op=reset,if=variable.min_vt
  -- variable,name=min_ps,op=reset,if=variable.min_ps
  -- Note: These are being set every cycle in APL().
end

--- ===== APL Main =====
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount10ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end

    -- SoulShards variable
    SoulShards = Player:SoulShardsP()

    -- Generic variable to check if Agony, Corruption/Wither, and UA are active.
    VarDoTsUp = Target:DebuffUp(S.AgonyDebuff) and (Target:DebuffUp(S.CorruptionDebuff) or Target:DebuffUp(S.WitherDebuff)) and Target:DebuffUp(S.UnstableAfflictionDebuff)

    -- Calculate "Min" Variables
    VarMinAgony = CalcMinDoT(Enemies10ySplash, S.AgonyDebuff)
    VarMinVT = CalcMinDoT(Enemies10ySplash, S.VileTaintDebuff)
    VarMinPS = CalcMinDoT(Enemies10ySplash, S.PhantomSingularityDebuff)
    VarMinPS1 = VarMinVT * mathmax(num(S.VileTaint:IsAvailable()), VarMinPS) * num(S.PhantomSingularity:IsAvailable())

    -- Check Cleave APL Setting
    VarCleaveAPL = Settings.Affliction.UseCleaveAPL

    -- Calculate GCDMax
    GCDMax = Player:GCD() + 0.25
  end

  -- summon_pet
  if S.SummonPet:IsCastable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- interrupts
    local ShouldReturn = Everyone.Interrupt(S.SpellLock, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=cleave,if=active_enemies!=1&active_enemies<3|variable.cleave_apl
    if AoEON() and EnemiesCount10ySplash > 1 and EnemiesCount10ySplash < 3 or VarCleaveAPL then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>2
    if AoEON() and EnemiesCount10ySplash > 2 then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=end_of_fight
    local ShouldReturn = EndofFight(); if ShouldReturn then return ShouldReturn; end
    -- agony,if=(!talent.vile_taint|remains<cooldown.vile_taint.remains+action.vile_taint.cast_time)&(talent.absolute_corruption&remains<3|!talent.absolute_corruption&remains<5|cooldown.soul_rot.remains<5&remains<8)&fight_remains>dot.agony.remains+5
    if S.Agony:IsReady() and ((not S.VileTaint:IsAvailable() or Target:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime()) and (S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.AgonyDebuff) < 3 or not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.AgonyDebuff) < 5 or S.SoulRot:CooldownRemains() < 5 and Target:DebuffRemains(S.AgonyDebuff) < 8) and FightRemains > Target:DebuffRemains(S.AgonyDebuff) + 5) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 2"; end
    end
    -- haunt,if=talent.demonic_soul&buff.nightfall.react<2-prev_gcd.1.drain_soul&(!talent.vile_taint|cooldown.vile_taint.remains)
    if S.Haunt:IsReady() and (S.DemonicSoul:IsAvailable() and Player:BuffStack(S.NightfallBuff) < 2 - num(Player:PrevGCDP(1, S.DrainSoul)) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown())) then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 4"; end
    end
    -- unstable_affliction,if=(talent.absolute_corruption&remains<3|!talent.absolute_corruption&remains<5|cooldown.soul_rot.remains<5&remains<8)&(!talent.demonic_soul|buff.nightfall.react<2|prev_gcd.1.haunt&buff.nightfall.stack<2)&fight_remains>dot.unstable_affliction.remains+5
    if S.UnstableAffliction:IsReady() and ((S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.UnstableAfflictionDebuff) < 3 or not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5 or S.SoulRot:CooldownRemains() < 5 and Target:DebuffRemains(S.UnstableAfflictionDebuff) < 8) and (not S.DemonicSoul:IsAvailable() or Target:BuffStack(S.NightfallBuff) < 2 or Player:PrevGCDP(1, S.Haunt) and Target:DebuffStack(S.NightfallBuff) < 2) and FightRemains > Target:DebuffRemains(S.UnstableAfflictionDebuff) + 5) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 6"; end
    end
    
    -- haunt,if=(talent.absolute_corruption&debuff.haunt.remains<3|!talent.absolute_corruption&debuff.haunt.remains<5|cooldown.soul_rot.remains<5&debuff.haunt.remains<8)&(!talent.vile_taint|cooldown.vile_taint.remains)&fight_remains>debuff.haunt.remains+5
    if S.Haunt:IsReady() and ((S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.HauntDebuff) < 3 or not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.HauntDebuff) < 5 or S.SoulRot:CooldownRemains() < 5 and Target:DebuffRemains(S.HauntDebuff) < 8) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) and FightRemains > Target:DebuffRemains(S.HauntDebuff) + 5) then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 8"; end
    end
    -- wither,if=talent.wither&(talent.absolute_corruption&remains<3|!talent.absolute_corruption&remains<5)&fight_remains>dot.wither.remains+5
    if S.Wither:IsReady() and ((S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.WitherDebuff) < 3 or not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.WitherDebuff) < 5) and FightRemains > Target:DebuffRemains(S.WitherDebuff) + 5) then
      if Cast(S.Wither, nil, nil, not Target:IsInRange(40)) then return "wither main 10"; end
    end
    -- corruption,if=refreshable&fight_remains>dot.corruption.remains+5
    if S.Corruption:IsReady() and (Target:DebuffRefreshable(S.CorruptionDebuff) and FightRemains > Target:DebuffRemains(S.CorruptionDebuff) + 5) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 12"; end
    end
    -- drain_soul,if=buff.nightfall.react&(buff.nightfall.react>1|buff.nightfall.remains<execute_time*2)&!buff.tormented_crescendo.react&cooldown.soul_rot.remains&soul_shard<5-buff.tormented_crescendo.react&(!talent.vile_taint|cooldown.vile_taint.remains)
    if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff) and (Player:BuffStack(S.NightfallBuff) > 1 or Player:BuffRemains(S.NightfallBuff) < S.DrainSoul:ExecuteTime() * 2) and Player:BuffDown(S.TormentedCrescendoBuff) and S.SoulRot:CooldownDown() and SoulShards < 5 - Player:BuffStack(S.TormentedCrescendoBuff) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown())) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul main 14"; end
    end
    -- shadow_bolt,if=buff.nightfall.react&(buff.nightfall.react>1|buff.nightfall.remains<execute_time*2)&buff.tormented_crescendo.react<2&cooldown.soul_rot.remains&soul_shard<5-buff.tormented_crescendo.react&(!talent.vile_taint|cooldown.vile_taint.remains)
    if S.ShadowBolt:IsReady() and (Player:BuffUp(S.NightfallBuff) and (Player:BuffStack(S.NightfallBuff) > 1 or Player:BuffRemains(S.NightfallBuff) < S.ShadowBolt:ExecuteTime() * 2) and Player:BuffStack(S.TormentedCrescendoBuff) < 2 and S.SoulRot:CooldownDown() and SoulShards < 5 - Player:BuffStack(S.TormentedCrescendoBuff) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown())) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 16"; end
    end
    -- call_action_list,name=se_maintenance,if=talent.wither
    if S.Wither:IsAvailable() then
      local ShouldReturn = SEMaintenance(); if ShouldReturn then return ShouldReturn; end
    end
    -- vile_taint,if=(!talent.soul_rot|cooldown.soul_rot.remains>20|cooldown.soul_rot.remains<=execute_time+gcd.max|fight_remains<cooldown.soul_rot.remains)&dot.agony.remains&(dot.corruption.remains|dot.wither.remains)&dot.unstable_affliction.remains
    if S.VileTaint:IsReady() and ((not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() > 20 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() + GCDMax or BossFightRemains < S.SoulRot:CooldownRemains()) and VarDoTsUp) then
      if Cast(S.VileTaint, Settings.Affliction.GCDasOffGCD.VileTaint, nil, not Target:IsInRange(40)) then return "vile_taint main 18"; end
    end
    -- phantom_singularity,if=(!talent.soul_rot|cooldown.soul_rot.remains<4|fight_remains<cooldown.soul_rot.remains)&dot.agony.remains&(dot.corruption.remains|dot.wither.remains)&dot.unstable_affliction.remains
    if S.PhantomSingularity:IsReady() and ((not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() < 4 or BossFightRemains < S.SoulRot:CooldownRemains()) and VarDoTsUp) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 20"; end
    end
    if VarVTPSUp and CDsON() then
      -- malevolence,if=variable.vt_ps_up
      if S.Malevolence:IsReady() then
        if Cast(S.Malevolence, Settings.Affliction.GCDasOffGCD.Malevolence) then return "malevolence main 22"; end
      end
      -- soul_rot,if=variable.vt_ps_up
      if S.SoulRot:IsReady() then
        if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot main 24"; end
      end
    end
    -- summon_darkglare,if=variable.cd_dots_up&(debuff.shadow_embrace.stack=debuff.shadow_embrace.max_stack)
    if CDsON() and S.SummonDarkglare:IsReady() and (VarCDDoTsUp and (Target:DebuffStack(ShadowEmbraceDebuff) == ShadowEmbraceMaxStack)) then
      if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare main 26"; end
    end
    -- call_action_list,name=se_maintenance,if=talent.demonic_soul
    if S.DemonicSoul:IsAvailable() then
      local ShouldReturn = SEMaintenance(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=soul_shard>4&(talent.demonic_soul&buff.nightfall.react<2|!talent.demonic_soul)|buff.tormented_crescendo.react>1
    if S.MaleficRapture:IsReady() and (SoulShards > 4 and (S.DemonicSoul:IsAvailable() and Player:BuffStack(S.NightfallBuff) < 2 or not S.DemonicSoul:IsAvailable()) or Player:BuffStack(S.TormentedCrescendoBuff) > 1) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 28"; end
    end
    -- drain_soul,if=talent.demonic_soul&buff.nightfall.react&buff.tormented_crescendo.react<2&target.health.pct<20
    if S.DrainSoul:IsReady() and (S.DemonicSoul:IsAvailable() and Player:BuffUp(S.NightfallBuff) and Player:BuffStack(S.TormentedCrescendoBuff) < 2 and Target:HealthPercentage() < 20) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsInRange(40)) then return "drain_soul main 30"; end
    end
    -- malefic_rapture,if=talent.demonic_soul&(soul_shard>1|buff.tormented_crescendo.react&cooldown.soul_rot.remains>buff.tormented_crescendo.remains*gcd.max)&(!talent.vile_taint|soul_shard>1&cooldown.vile_taint.remains>10)&(!talent.oblivion|cooldown.oblivion.remains>10|soul_shard>2&cooldown.oblivion.remains<10)
    if S.MaleficRapture:IsReady() and (S.DemonicSoul:IsAvailable() and (SoulShards > 1 or Target:BuffUp(S.TormentedCrescendoBuff) and S.SoulRot:CooldownRemains() > Player:BuffRemains(S.TormentedCrescendoBuff) * GCDMax) and (not S.VileTaint:IsAvailable() or SoulShards > 1 and S.VileTaint:CooldownRemains() > 10) and (not S.Oblivion:IsAvailable() or S.Oblivion:CooldownRemains() > 10 or SoulShards > 2 and S.Oblivion:CooldownRemains() < 10)) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 32"; end
    end
    -- oblivion,if=dot.agony.remains&(dot.corruption.remains|dot.wither.remains)&dot.unstable_affliction.remains&debuff.haunt.remains>5
    if S.Oblivion:IsReady() and (VarDoTsUp and Target:DebuffRemains(S.HauntDebuff) > 5) then
      if Cast(S.Oblivion, nil, nil, not Target:IsSpellInRange(S.Oblivion)) then return "oblivion main 34"; end
    end
    if S.MaleficRapture:IsReady() and (
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react&(buff.tormented_crescendo.remains<gcd.max*2|buff.tormented_crescendo.react=2)
      (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and (Player:BuffRemains(S.TormentedCrescendoBuff) < GCDMax * 2 or Player:BuffStack(S.TormentedCrescendoBuff) == 2)) or
      -- malefic_rapture,if=(variable.cd_dots_up|(talent.demonic_soul|talent.phantom_singularity)&variable.vt_ps_up|talent.wither&variable.vt_ps_up&!dot.soul_rot.remains&soul_shard>2)&(!talent.oblivion|cooldown.oblivion.remains>10|soul_shard>2&cooldown.oblivion.remains<10)
      ((VarCDDoTsUp or (S.DemonicSoul:IsAvailable() or S.PhantomSingularity:IsAvailable()) and VarVTPSUp or S.Wither:IsAvailable() and VarVTPSUp and Target:DebuffDown(S.SoulRot) and SoulShards > 2) and (not S.Oblivion:IsAvailable() or S.Oblivion:CooldownRemains() > 10 or SoulShards > 2 and S.Oblivion:CooldownRemains() < 10)) or
      -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react|talent.demonic_soul&!buff.nightfall.react&(!talent.vile_taint|cooldown.vile_taint.remains>10|soul_shard>1&cooldown.vile_taint.remains<10)
      (S.TormentedCrescendo:IsAvailable() and S.NightfallBuff:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff) or S.DemonicSoul:IsAvailable() and Player:BuffDown(S.NightfallBuff) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownRemains() > 10 or SoulShards > 1 and S.VileTaint:CooldownRemains() < 10)) or
      -- malefic_rapture,if=!talent.demonic_soul&buff.tormented_crescendo.react
      (S.DemonicSoul:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff))
    ) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 36"; end
    end
    -- drain_soul,if=buff.nightfall.react
    -- shadow_bolt,if=buff.nightfall.react
    if DSSB:IsReady() and Player:BuffUp(S.NightfallBuff) then
      if Cast(DSSB, nil, nil, not Target:IsInRange(40)) then return "drain_soul/shadow_bolt main 38"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsReady() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 40"; end
    end
    -- unstable_affliction,if=refreshable
    if S.UnstableAffliction:IsReady() and (Target:DebuffRefreshable(S.UnstableAfflictionDebuff)) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 42"; end
    end
    -- drain_soul,chain=1,early_chain_if=buff.nightfall.react,interrupt_if=tick_time>0.5
    -- shadow_bolt
    if DSSB:IsReady() then
      if Cast(DSSB, nil, nil, not Target:IsInRange(40)) then return "drain_soul/shadow_bolt main 44"; end
    end
  end
end

local function OnInit()
  S.AgonyDebuff:RegisterAuraTracking()
  S.CorruptionDebuff:RegisterAuraTracking()
  S.SiphonLifeDebuff:RegisterAuraTracking()
  S.UnstableAfflictionDebuff:RegisterAuraTracking()
  S.ShadowEmbraceDSDebuff:RegisterAuraTracking()

  HR.Print("Affliction Warlock rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(265, APL, OnInit)