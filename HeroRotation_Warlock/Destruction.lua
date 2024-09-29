--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Utils         = HL.Utils
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
local Warlock    = HR.Commons.Warlock
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua
local max           = math.max
local floor         = math.floor
-- WoW API
local Delay         = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Destruction
local I = Item.Warlock.Destruction

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.SpymastersWeb:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  CommonsDS = HR.GUISettings.APL.Warlock.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warlock.CommonsOGCD,
  Destruction = HR.GUISettings.APL.Warlock.Destruction
}

--- ===== Rotation Variables =====
local VarAllowRoF2TSpender = 2
local VarDoRoF2T = VarAllowRoF2TSpender > 1.99 and not (S.Cataclysm:IsAvailable() and S.ImprovedChaosBolt:IsAvailable())
local VarDisableCB2T = VarDoRoF2T or VarAllowRoF2TSpender > 0.01 and VarAllowRoF2TSpender < 0.99
local VarPoolSoulShards = false
local VarHavocActive, VarHavocRemains = false, 0
local VarHavocImmoTime = 0
local VarPoolingCondition = false
local VarPoolingConditionCB = false
local VarInfernalActive = false
local VarT1WillLoseCast, VarT2WillLoseCast = false, false
local SoulShards = 0
local Enemies40y, EnemiesCount8ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
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
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

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
  if VarTrinket1Buffs and (VarTrinket1CD % 120 == 0 or 120 % VarTrinket1CD == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (VarTrinket2CD % 120 == 0 or 120 % VarTrinket2CD == 0) then
    VarTrinket2Sync = 1
  end

  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID()

  VarTrinket1Exclude = VarTrinket1ID == 194301
  VarTrinket2Exclude = VarTrinket2ID == 194301

  VarTrinket1BuffDuration = Trinket1:BuffDuration()
  VarTrinket2BuffDuration = Trinket2:BuffDuration()

  -- Note: If buff duration is 0, set to 1 to avoid divide by zero errors below.
  local T1BuffDur = (VarTrinket1BuffDuration > 0) and VarTrinket1BuffDuration or 1
  local T2BuffDur = (VarTrinket2BuffDuration > 0) and VarTrinket2BuffDuration or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarAllowRoF2TSpender = 2
  VarDoRoF2T = VarAllowRoF2TSpender > 1.99 and not (S.Cataclysm:IsAvailable() and S.ImprovedChaosBolt:IsAvailable())
  VarDisableCB2T = VarDoRoF2T or VarAllowRoF2TSpender > 0.01 and VarAllowRoF2TSpender < 0.99
  VarPoolSoulShards = false
  VarHavocActive, VarHavocRemains = false, 0
  VarHavocImmoTime = 0
  VarPoolingCondition = false
  VarPoolingConditionCB = false
  VarInfernalActive = false
  VarT1WillLoseCast, VarT2WillLoseCast = false, false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.ChaosBolt:RegisterInFlight()
  S.Incinerate:RegisterInFlight()
  S.SoulFire:RegisterInFlight()
  S.SummonInfernal:RegisterInFlight()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.ChaosBolt:RegisterInFlight()
S.Incinerate:RegisterInFlight()
S.SoulFire:RegisterInFlight()
S.SummonInfernal:RegisterInFlight()

--- ===== Helper Functions =====
local function UnitWithHavoc(enemies)
  for k in pairs(enemies) do
    local CycleUnit = enemies[k]
    if CycleUnit:DebuffUp(S.Havoc) then
      return true, CycleUnit:DebuffRemains(S.HavocDebuff), CycleUnit:DebuffRemains(S.ImmolateDebuff)
    end
  end
  return false, 0, 0
end

local function ChannelDemonfireCastTime()
  return 3 * Player:SpellHaste() * (S.DemonfireMastery:IsAvailable() and 0.65 or 1)
end

local function DemonicArt()
  return Player:BuffUp(S.DemonicArtOverlordBuff) or Player:BuffUp(S.DemonicArtMotherBuff) or Player:BuffUp(S.DemonicArtPitLordBuff)
end

local function DiabolicRitual()
  return Player:BuffUp(S.DiabolicRitualOverlordBuff) or Player:BuffUp(S.DiabolicRitualMotherBuff) or Player:BuffUp(S.DiabolicRitualPitLordBuff)
end

local function InfernalActive()
  return Warlock.GuardiansTable.InfernalDuration > 0
end

local function InfernalTime()
  return Warlock.GuardiansTable.InfernalDuration or (S.SummonInfernal:InFlight() and 30) or 0
end

local function OverfiendActive()
  return Warlock.GuardiansTable.OverfiendDuration > 0
end

local function OverfiendTime()
  return Warlock.GuardiansTable.OverfiendDuration or 0
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterHavoc(TargetUnit)
  -- target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target)
  return max(TargetUnit:TimeToDie() * -1, -15) + TargetUnit:DebuffRemains(S.ImmolateDebuff) + 99 * num(TargetUnit:GUID() == Target:GUID())
end

local function EvaluateTargetIfFilterImmolate(TargetUnit)
  -- target_if=min:dot.immolate.remains+99*debuff.havoc.remains
  return TargetUnit:DebuffRemains(S.ImmolateDebuff) + 99 * TargetUnit:DebuffRemains(S.HavocDebuff)
end

local function EvaluateTargetIfFilterWitherRemains(TargetUnit)
  -- target_if=min:dot.wither.remains+99*debuff.havoc.remains+99*!dot.wither.ticking
  return TargetUnit:DebuffRemains(S.WitherDebuff) + 99 * num(TargetUnit:DebuffUp(S.HavocDebuff)) + 99 * num(TargetUnit:DebuffDown(S.WitherDebuff))
end

local function EvaluateTargetIfFilterWitherRemains2(TargetUnit)
  -- target_if=min:dot.wither.remains+99*debuff.havoc.remains
  return TargetUnit:DebuffRemains(S.WitherDebuff) + 99 * num(TargetUnit:DebuffUp(S.HavocDebuff))
end

local function EvaluateTargetIfFilterWitherRemains3(TargetUnit)
  -- target_if=min:dot.wither.remains+dot.immolate.remains-5*debuff.conflagrate.up+100*debuff.havoc.remains
  return TargetUnit:DebuffRemains(S.WitherDebuff) + TargetUnit:DebuffRemains(S.ImmolateDebuff) - 5 * num(TargetUnit:DebuffUp(S.ConflagrateDebuff)) + 100 * num(TargetUnit:DebuffUp(S.HavocDebuff))
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfHavoc(TargetUnit)
  -- if=(!cooldown.summon_infernal.up|!talent.summon_infernal)&target.time_to_die>8
  -- if=(!cooldown.summon_infernal.up|!talent.summon_infernal|(talent.inferno&active_enemies>4))&target.time_to_die>8
  -- Note: For both lines, all but time_to_die is handled before CastTargetIf
  return TargetUnit:TimeToDie() > 8
end

local function EvaluateTargetIfImmolateAoE(TargetUnit)
  -- if=dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&active_dot.immolate<=4&target.time_to_die>18
  -- Note: active_dot.immolate handled before CastCycle
  return (TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and (not S.RagingDemonfire:IsAvailable() or S.ChannelDemonfire:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff) or HL.CombatTime() < 5) and TargetUnit:TimeToDie() > 18)
end

local function EvaluateTargetIfImmolateAoE2(TargetUnit)
  -- if=((dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains))|active_enemies>active_dot.immolate)&target.time_to_die>10&!havoc_active&!(talent.diabolic_ritual&talent.inferno)
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff))) or EnemiesCount8ySplash > S.ImmolateDebuff:AuraActiveCount()) and TargetUnit:TimeToDie() > 10 and not VarHavocActive and not (S.DiabolicRitual:IsAvailable() and S.Inferno:IsAvailable()))
end

local function EvaluateTargetIfImmolateAoE3(TargetUnit)
  -- if=((dot.immolate.refreshable&variable.havoc_immo_time<5.4)|(dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|(variable.havoc_immo_time<2)*havoc_active)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&target.time_to_die>11&!(talent.diabolic_ritual&talent.inferno)
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and VarHavocImmoTime < 5.4) or (TargetUnit:DebuffRemains(S.ImmolateDebuff) < 2 and TargetUnit:DebuffRemains(S.ImmolateDebuff) < VarHavocRemains) or TargetUnit:DebuffDown(S.ImmolateDebuff) or bool(num(VarHavocImmoTime < 2) * num(VarHavocActive))) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and TargetUnit:TimeToDie() > 11 and not (S.DiabolicRitual:IsAvailable() and S.Inferno:IsAvailable()))
end

local function EvaluateTargetIfImmolateCleave(TargetUnit)
  -- if=(dot.immolate.refreshable&(dot.immolate.remains<cooldown.havoc.remains|!dot.immolate.ticking))&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains+(!talent.mayhem*action.soul_fire.cast_time)>dot.immolate.remains)&target.time_to_die>15
  return ((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (TargetUnit:DebuffRemains(S.ImmolateDebuff) < S.Havoc:CooldownRemains() or TargetUnit:DebuffDown(S.ImmolateDebuff))) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and (not S.SoulFire:IsAvailable() or S.SoulFire:CooldownRemains() + (num(not S.Mayhem:IsAvailable()) * S.SoulFire:CastTime()) > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and TargetUnit:TimeToDie() > 15)
end

local function EvaluateTargetIfImmolateHavoc(TargetUnit)
  -- if=(((dot.immolate.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  -- Note: Soul Shard check handled before CastTargetIf call.
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and VarHavocImmoTime < 5.4) and TargetUnit:TimeToDie() > 5) or ((TargetUnit:DebuffRemains(S.ImmolateDebuff) < 2 and TargetUnit:DebuffRemains(S.ImmolateDebuff) < VarHavocRemains) or TargetUnit:DebuffDown(S.ImmolateDebuff) or VarHavocImmoTime < 2) and TargetUnit:TimeToDie() > 11)
end

local function EvaluateTargetIfWitherAoE(TargetUnit)
  -- if=dot.wither.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.wither.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&(active_dot.wither<=4|time>15)&target.time_to_die>18
  -- Note: Wither count performed before CastTargetIf.
  return TargetUnit:DebuffRefreshable(S.WitherDebuff) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.WitherDebuff)) and (not S.RagingDemonfire:IsAvailable() or S.ChannelDemonfire:CooldownRemains() > TargetUnit:DebuffRemains(S.WitherDebuff) or HL.CombatTime() < 5) and TargetUnit:TimeToDie() > 18
end

local function EvaluateTargetIfWitherAoE2(TargetUnit)
  -- if=dot.wither.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.wither.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&active_dot.wither<=active_enemies&target.time_to_die>18
  -- Note: Checked active_dot.wither<=active_enemies prior to CastTargetIf.
  return TargetUnit:DebuffRefreshable(S.WitherDebuff) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.WitherDebuff)) and (not S.RagingDemonfire:IsAvailable() or S.ChannelDemonfire:CooldownRemains() > TargetUnit:DebuffRemains(S.WitherDebuff) or HL.CombatTime() < 5) and TargetUnit:TimeToDie() > 18
end

local function EvaluateTargetIfWitherCleave(TargetUnit)
  -- if=talent.internal_combustion&(((dot.wither.remains-5*action.chaos_bolt.in_flight)<dot.wither.duration*0.4)|dot.wither.remains<3|(dot.wither.remains-action.chaos_bolt.execute_time)<5&action.chaos_bolt.usable)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains-5))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
  -- Note: Checked internal_combustion and soul_fire.in_flight_to_target before CastTargetIf.
  return (((TargetUnit.DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight())) < S.WitherDebuff:MaxDuration() * 0.4) or TargetUnit:DebuffRemains(S.WitherDebuff) < 3 or (TargetUnit:DebuffRemains(S.WitherDebuff) - S.ChaosBolt:ExecuteTime()) < 5 and S.ChaosBolt:IsReady()) and (not S.SoulFire:IsAvailable() or S.SoulFire:CooldownRemains() + S.SoulFire:CastTime() > (TargetUnit:DebuffRemains(S.WitherDebuff) - 5)) and TargetUnit:TimeToDie() > 8
end

local function EvaluateTargetIfWitherCleave2(TargetUnit)
  -- if=!talent.internal_combustion&(((dot.wither.remains-5*(action.chaos_bolt.in_flight))<dot.wither.duration*0.3)|dot.wither.remains<3)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
  -- Note: Checked internal_combustion and soul_fire.in_flight_to_target before CastTargetIf.
  return (((TargetUnit:DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight())) < S.WitherDebuff:MaxDuration() * 0.3) or TargetUnit:DebuffRemains(S.WitherDebuff) < 3) and (not S.SoulFire:IsAvailable() or S.SoulFire:CooldownRemains() + S.SoulFire:CastTime() > (TargetUnit:DebuffRemains(S.WitherDebuff))) and TargetUnit:TimeToDie() > 8
end

local function EvaluateTargetIfWitherHavoc(TargetUnit)
  -- if=(((dot.wither.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.wither.remains<2&dot.wither.remains<havoc_remains)|!dot.wither.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  return ((TargetUnit:DebuffRefreshable(S.WitherDebuff) and VarHavocImmoTime < 5.4) and TargetUnit:TimeToDie() > 5) or ((TargetUnit:DebuffRemains(S.WitherDebuff) < 2 and TargetUnit:DebuffRemains(S.WitherDebuff) < VarHavocRemains) or TargetUnit:DebuffDown(S.WitherDebuff) or VarHavocImmoTime < 2) and TargetUnit:TimeToDie() > 11
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  -- Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  VarCleaveAPL = false
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.summon_infernal.duration=0|cooldown.summon_infernal.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.summon_infernal.duration=0|cooldown.summon_infernal.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.spymasters_web
  -- variable,name=trinket_2_manual,value=trinket.2.is.spymasters_web
  -- variable,name=trinket_1_exclude,value=trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1+0.5*trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1+0.5*trinket.1.has_buff.intellect)*(variable.trinket_1_sync))
  -- Note: Trinket variables moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- variable,name=allow_rof_2t_spender,default=2,op=reset
  -- variable,name=do_rof_2t,value=variable.allow_rof_2t_spender>1.99&!(talent.cataclysm&talent.improved_chaos_bolt),op=set
  -- variable,name=disable_cb_2t,value=variable.do_rof_2t|variable.allow_rof_2t_spender>0.01&variable.allow_rof_2t_spender<0.99
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsReady() then
    if Cast(S.GrimoireofSacrifice, Settings.Destruction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- soul_fire
  if S.SoulFire:IsReady() and (not Player:IsCasting(S.SoulFire)) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire precombat 4"; end
  end
  -- cataclysm,if=raid_event.adds.in>15
  if S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm precombat 6"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() and (not Player:IsCasting(S.Incinerate)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate precombat 8"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=spymasters_web,if=pet.infernal.remains>=10&pet.infernal.remains<=20&buff.spymasters_report.stack>=38&(fight_remains>240|fight_remains<=140)|fight_remains<=30
    if I.SpymastersWeb:IsEquippedAndReady() and (InfernalTime() >= 10 and InfernalTime() <= 20 and Player:BuffStack(S.SpymastersReportBuff) >= 38 and (FightRemains > 240 or FightRemains <= 140) or FightRemains <= 30) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web items 2"; end
    end
    -- use_item,slot=trinket1,if=(variable.infernal_active|!talent.summon_infernal|variable.trinket_1_will_lose_cast)&(variable.trinket_priority=1|variable.trinket_2_exclude|!trinket.2.has_cooldown|(trinket.2.cooldown.remains|variable.trinket_priority=2&cooldown.summon_infernal.remains>20&!variable.infernal_active&trinket.2.cooldown.remains<cooldown.summon_infernal.remains))&variable.trinket_1_buffs&!variable.trinket_1_manual|(variable.trinket_1_buff_duration+1>=fight_remains)
    if Trinket1:IsReady() and not VarTrinket1BL and ((VarInfernalActive or not S.SummonInfernal:IsAvailable() or VarT1WillLoseCast) and (VarTrinketPriority == 1 or VarTrinket2Exclude or not Trinket2:HasCooldown() or (Trinket2:CooldownDown() or VarTrinketPriority == 2 and S.SummonInfernal:CooldownRemains() > 20 and not VarInfernalActive and Trinket2:CooldownRemains() < S.SummonInfernal:CooldownRemains())) and VarTrinket1Buffs and not VarTrinket1Manual or (VarTrinket1BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 4"; end
    end
    -- use_item,slot=trinket2,if=(variable.infernal_active|!talent.summon_infernal|variable.trinket_2_will_lose_cast)&(variable.trinket_priority=2|variable.trinket_1_exclude|!trinket.1.has_cooldown|(trinket.1.cooldown.remains|variable.trinket_priority=1&cooldown.summon_infernal.remains>20&!variable.infernal_active&trinket.1.cooldown.remains<cooldown.summon_infernal.remains))&variable.trinket_2_buffs&!variable.trinket_2_manual|(variable.trinket_2_buff_duration+1>=fight_remains)
    if Trinket2:IsReady() and not VarTrinket2BL and ((VarInfernalActive or not S.SummonInfernal:IsAvailable() or VarT2WillLoseCast) and (VarTrinketPriority == 2 or VarTrinket1Exclude or not Trinket1:HasCooldown() or (Trinket1:CooldownDown() or VarTrinketPriority == 1 and S.SummonInfernal:CooldownRemains() > 20 and not VarInfernalActive and Trinket1:CooldownRemains() < S.SummonInfernal:CooldownRemains())) and VarTrinket2Buffs and not VarTrinket2Manual or (VarTrinket2BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|talent.summon_infernal&cooldown.summon_infernal.remains_expected>20&!prev_gcd.1.summon_infernal|!talent.summon_infernal)
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs) or S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemains() > 20 and not Player:PrevGCDP(1, S.SummonInfernal) or not S.SummonInfernal:IsAvailable())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|talent.summon_infernal&cooldown.summon_infernal.remains_expected>20&!prev_gcd.1.summon_infernal|!talent.summon_infernal)
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs) or S.SummonInfernal:IsAvailable() and S.SummonInfernal:CooldownRemains() > 20 and not Player:PrevGCDP(1, S.SummonInfernal) or not S.SummonInfernal:IsAvailable())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 10"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=main_hand
  -- Note: Including all non-trinket items
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ItemToUse:IsReady() then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "non-trinket item (" .. ItemToUse:Name() .. ") items 12"; end
    end
  end
end

local function oGCD()
  -- potion,if=variable.infernal_active|!talent.summon_infernal
  if Settings.Commons.Enabled.Potions and (VarInfernalActive or not S.SummonInfernal:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ogcd 2"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=variable.infernal_active|!talent.summon_infernal|(fight_remains<cooldown.summon_infernal.remains_expected+10+cooldown.invoke_power_infusion_0.duration&fight_remains>cooldown.invoke_power_infusion_0.duration)|fight_remains<cooldown.summon_infernal.remains_expected+15
  -- Note: Not handling external PI.
  -- berserking,if=variable.infernal_active|!talent.summon_infernal|(fight_remains<(cooldown.summon_infernal.remains_expected+cooldown.berserking.duration)&(fight_remains>cooldown.berserking.duration))|fight_remains<cooldown.summon_infernal.remains_expected
  if S.Berserking:IsCastable() and (VarInfernalActive or not S.SummonInfernal:IsAvailable() or (FightRemains < (S.SummonInfernal:CooldownRemains() + 12) and (FightRemains > 12)) or FightRemains < S.SummonInfernal:CooldownRemains()) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking ogcd 4"; end
  end
  -- blood_fury,if=variable.infernal_active|!talent.summon_infernal|(fight_remains<cooldown.summon_infernal.remains_expected+10+cooldown.blood_fury.duration&fight_remains>cooldown.blood_fury.duration)|fight_remains<cooldown.summon_infernal.remains
  if S.BloodFury:IsCastable() and (VarInfernalActive or not S.SummonInfernal:IsAvailable() or (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 15) and (FightRemains > 15)) or FightRemains < S.SummonInfernal:CooldownRemains()) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 6"; end
  end
  -- fireblood,if=variable.infernal_active|!talent.summon_infernal|(fight_remains<cooldown.summon_infernal.remains_expected+10+cooldown.fireblood.duration&fight_remains>cooldown.fireblood.duration)|fight_remains<cooldown.summon_infernal.remains_expected
  if S.Fireblood:IsCastable() and (VarInfernalActive or not S.SummonInfernal:IsAvailable() or (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 8) and (FightRemains > 8)) or FightRemains < S.SummonInfernal:CooldownRemains()) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood ogcd 8"; end
  end
  -- ancestral_call,if=variable.infernal_active|!talent.summon_infernal|(fight_remains<(cooldown.summon_infernal.remains_expected+cooldown.berserking.duration)&(fight_remains>cooldown.berserking.duration))|fight_remains<cooldown.summon_infernal.remains_expected
  -- Note: Assume they copied from berserking and actually meant to use ancestral_call durations
  if S.AncestralCall:IsCastable() and (VarInfernalActive or not S.SummonInfernal:IsAvailable() or (FightRemains < (S.SummonInfernal:CooldownRemains() + 15) and (FightRemains > 15)) or FightRemains < S.SummonInfernal:CooldownRemains()) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call ogcd 10"; end
  end
end

local function Havoc()
  -- conflagrate,if=talent.backdraft&buff.backdraft.down&soul_shard>=1&soul_shard<=4
  if S.Conflagrate:IsCastable() and (S.Backdraft:IsAvailable() and Player:BuffDown(S.BackdraftBuff) and SoulShards >= 1 and SoulShards <= 4) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 2"; end
  end
  -- soul_fire,if=cast_time<havoc_remains&soul_shard<2.5
  if S.SoulFire:IsCastable() and (S.SoulFire:CastTime() < VarHavocRemains and SoulShards < 2.5) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire havoc 4"; end
  end
  -- cataclysm,if=raid_event.adds.in>15|(talent.wither&dot.wither.remains<action.wither.duration*0.3)
  if S.Cataclysm:IsReady() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm havoc 8"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+100*debuff.havoc.remains,if=(((dot.immolate.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  if S.Immolate:IsCastable() and (SoulShards < 4.5) then
    if Everyone.CastTargetIf(S.Immolate, Enemies8ySplash, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateHavoc, not Target:IsSpellInRange(S.Immolate)) then return "immolate havoc 10"; end
  end
  -- wither,target_if=min:dot.wither.remains+100*debuff.havoc.remains,if=(((dot.wither.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.wither.remains<2&dot.wither.remains<havoc_remains)|!dot.wither.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  -- Note: ETIFWitherRemains2 is 99*debuff.havoc.remains. Just using that.
  if S.Wither:IsCastable() and (SoulShards < 4.5) then
    if Everyone.CastTargetIf(S.Wither, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains2, EvaluateTargetIfWitherHavoc, not Target:IsSpellInRange(S.Wither)) then return "wither havoc 12"; end
  end
  -- shadowburn,if=(cooldown.shadowburn.full_recharge_time<=gcd.max*3|debuff.eradication.remains<=gcd.max&talent.eradication&!action.chaos_bolt.in_flight&!talent.diabolic_ritual)&(talent.conflagration_of_chaos|talent.blistering_atrophy)
  if S.Shadowburn:IsReady() and ((S.Shadowburn:FullRechargeTime() <= Player:GCD() * 3 or Target:DebuffRemains(S.EradicationDebuff) <= Player:GCD() and S.Eradication:IsAvailable() and not S.ChaosBolt:InFlight() and not S.DiabolicRitual:IsAvailable()) and (S.ConflagrationofChaos:IsAvailable() or S.BlisteringAtrophy:IsAvailable())) then
    if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn havoc 14"; end
  end
  -- shadowburn,if=havoc_remains<=gcd.max*3
  if S.Shadowburn:IsReady() and (VarHavocRemains <= Player:GCD() * 3) then
    if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn havoc 16"; end
  end
  -- chaos_bolt,if=cast_time<havoc_remains&(active_enemies<=2-(talent.inferno-talent.improved_chaos_bolt-talent.cataclysm)*talent.wither+(talent.cataclysm&talent.improved_chaos_bolt)*!talent.wither)
  if S.ChaosBolt:IsReady() and (S.ChaosBolt:CastTime() < VarHavocRemains and (EnemiesCount8ySplash <= 2 - (num(S.Inferno:IsAvailable()) - num(S.ImprovedChaosBolt:IsAvailable()) - num(S.Cataclysm:IsAvailable())) * num(S.Wither:IsAvailable()) + num(S.Cataclysm:IsAvailable() and S.ImprovedChaosBolt:IsAvailable()) * num(not S.Wither:IsAvailable()))) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt havoc 18"; end
  end
  -- rain_of_fire,if=active_enemies>=3-talent.wither
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash >= 3 - num(S.Wither:IsAvailable())) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 20"; end
  end
  -- channel_demonfire,if=soul_shard<4.5
  if S.ChannelDemonfire:IsReady() and (SoulShards < 4.5) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire havoc 22"; end
  end
  -- conflagrate,if=!talent.backdraft
  if S.Conflagrate:IsCastable() and not S.Backdraft:IsAvailable() then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 24"; end
  end
  -- dimensional_rift,if=soul_shard<4.7&(charges>2|fight_remains<cooldown.dimensional_rift.duration)
  if CDsON() and S.DimensionalRift:IsCastable() and (SoulShards < 4.7 and (S.DimensionalRift:Charges() > 2 or FightRemains < S.DimensionalRift:Cooldown())) then
    if Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift havoc 26"; end
  end
  -- incinerate,if=cast_time<havoc_remains
  if S.Incinerate:IsCastable() and (S.Incinerate:CastTime() < VarHavocRemains) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate havoc 28"; end
  end
end

local function Aoe()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- malevolence,if=cooldown.summon_infernal.remains>=55&soul_shard<4.7&(active_enemies<=3+active_dot.wither|time>30)
  if S.Malevolence:IsReady() and (S.SummonInfernal:CooldownRemains() >= 55 and SoulShards < 4.7 and (EnemiesCount8ySplash <= 3 + S.WitherDebuff:AuraActiveCount() or HL.CombatTime() > 30)) then
    if Cast(S.Malevolence, nil, nil, not Target:IsSpellInRange(S.Malevolence)) then return "malevolence aoe 2"; end
  end
  -- rain_of_fire,if=demonic_art
  if S.RainofFire:IsReady() and (DemonicArt()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 4"; end
  end
  -- wait,sec=((buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)),if=(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)<gcd.max*0.25)&soul_shard>2
  -- TODO: Add wait?
  -- incinerate,if=(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)<=action.incinerate.cast_time&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)>gcd.max*0.25)
  if S.Incinerate:IsCastable() and (DiabolicRitual() and VarDRSum <= S.Incinerate:CastTime() and VarDRSum > Player:GCD() * 0.25) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 6"; end
  end
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd.max&active_enemies<5&(!cooldown.summon_infernal.up|!talent.summon_infernal)
  if VarHavocActive and VarHavocRemains > Player:GCD() and EnemiesCount8ySplash < 5 and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable()) then
    local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
  end
  -- dimensional_rift,if=soul_shard<4.7&(charges>2|fight_remains<cooldown.dimensional_rift.duration)
  if CDsON() and S.DimensionalRift:IsCastable() and (SoulShards < 4.7 and (S.DimensionalRift:Charges() > 2 or FightRemains < S.DimensionalRift:Cooldown())) then
    if Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift aoe 8"; end
  end
  -- rain_of_fire,if=!talent.inferno&soul_shard>=(4.5-0.1*active_dot.immolate)|soul_shard>=(3.5-0.1*active_dot.immolate)|buff.ritual_of_ruin.up
  if S.RainofFire:IsReady() and (not S.Inferno:IsAvailable() and SoulShards >= (4.5 - 0.1 * S.ImmolateDebuff:AuraActiveCount()) or SoulShards >= (3.5 - 0.1 * S.ImmolateDebuff:AuraActiveCount()) or Player:BuffUp(S.RitualofRuinBuff)) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 10"; end
  end
  -- wither,target_if=min:dot.wither.remains+99*debuff.havoc.remains+99*!dot.wither.ticking,if=dot.wither.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.wither.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&(active_dot.wither<=4|time>15)&target.time_to_die>18
  if S.Wither:IsReady() and ((S.WitherDebuff:AuraActiveCount() <= 4 or HL.CombatTime() > 15)) then
    if Everyone.CastTargetIf(S.Wither, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains, EvaluateTargetIfWitherAoE, not Target:IsInRange(40)) then return "wither aoe 12"; end
  end
  -- channel_demonfire,if=dot.immolate.remains+dot.wither.remains>cast_time&talent.raging_demonfire
  if S.ChannelDemonfire:IsReady() and (Target:DebuffRemains(S.ImmolateDebuff) + Target:DebuffRemains(S.WitherDebuff) > ChannelDemonfireCastTime() and S.RagingDemonfire:IsAvailable()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire aoe 14"; end
  end
  -- shadowburn,if=(active_enemies<4+(talent.cataclysm+4*talent.cataclysm)*talent.wither)&((cooldown.shadowburn.full_recharge_time<=gcd.max*3|debuff.eradication.remains<=gcd.max&talent.eradication&!action.chaos_bolt.in_flight&!talent.diabolic_ritual)&(talent.conflagration_of_chaos|talent.blistering_atrophy)&(active_enemies<5+(talent.wither&talent.cataclysm)+havoc_active)|fight_remains<=8)
  if S.Shadowburn:IsReady() and ((EnemiesCount8ySplash < 4 + (num(S.Cataclysm:IsAvailable()) + 4 * num(S.Cataclysm:IsAvailable())) * num(S.Wither:IsAvailable())) and ((S.Shadowburn:FullRechargeTime() <= Player:GCD() * 3 or Target:DebuffRemains(S.EradicationDebuff) <= Player:GCD() and S.Eradication:IsAvailable() and not S.ChaosBolt:InFlight() and not S.DiabolicRitual:IsAvailable()) and (S.ConflagrationofChaos:IsAvailable() or S.BlisteringAtrophy:IsAvailable()) and (EnemiesCount8ySplash < 5 + num(S.Wither:IsAvailable() and S.Cataclysm:IsAvailable()) + num(VarHavocActive)) or BossFightRemains <= 8)) then
    if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn aoe 16"; end
  end
  -- shadowburn,target_if=min:time_to_die,if=(active_enemies<4+(talent.cataclysm+4*talent.cataclysm)*talent.wither)&((cooldown.shadowburn.full_recharge_time<=gcd.max*3|debuff.eradication.remains<=gcd.max&talent.eradication&!action.chaos_bolt.in_flight&!talent.diabolic_ritual)&(talent.conflagration_of_chaos|talent.blistering_atrophy)&(active_enemies<5+(talent.wither&talent.cataclysm)+havoc_active)&time_to_die<5|fight_remains<=8)
  if S.Shadowburn:IsReady() and ((EnemiesCount8ySplash < 4 + (num(S.Cataclysm:IsAvailable()) + 4 * num(S.Cataclysm:IsAvailable())) * num(S.Wither:IsAvailable())) and ((S.Shadowburn:FullRechargeTime() <= Player:GCD() * 3 or Target:DebuffRemains(S.EradicationDebuff) <= Player:GCD() and S.Eradication:IsAvailable() and not S.ChaosBolt:InFlight() and not S.DiabolicRitual:IsAvailable()) and (S.ConflagrationofChaos:IsAvailable() or S.BlisteringAtrophy:IsAvailable()) and (EnemiesCount8ySplash < 5 + num(S.Wither:IsAvailable() and S.Cataclysm:IsAvailable()) + num(VarHavocActive)) and Target:TimeToDie() < 5 or FightRemains <= 8)) then
    if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn aoe 18"; end
  end
  -- ruination
  if S.RuinationAbility:IsReady() then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination aoe 20"; end
  end
  -- rain_of_fire,if=pet.infernal.active&talent.rain_of_chaos
  if S.RainofFire:IsReady() and (InfernalActive() and S.RainofChaos:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsInRange(40)) then return "rain_of_fire aoe 22"; end
  end
  -- soul_fire,target_if=min:dot.wither.remains+dot.immolate.remains-5*debuff.conflagrate.up+100*debuff.havoc.remains,if=(buff.decimation.up)&!talent.raging_demonfire&havoc_active
  if S.SoulFire:IsReady() and (Player:BuffUp(S.DecimationBuff) and not S.RagingDemonfire:IsAvailable() and VarHavocActive) then
    if Everyone.CastTargetIf(S.SoulFire, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains3, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire aoe 24"; end
  end
  -- soul_fire,target_if=min:(dot.wither.remains+dot.immolate.remains-5*debuff.conflagrate.up+100*debuff.havoc.remains),if=buff.decimation.up&active_dot.immolate<=4
  if S.SoulFire:IsReady() and (Player:BuffUp(S.DecimationBuff) and S.ImmolateDebuff:AuraActiveCount() <= 4) then
    if Everyone.CastTargetIf(S.SoulFire, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains3, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire aoe 26"; end
  end
  -- infernal_bolt,if=soul_shard<2.5
  if S.InfernalBolt:IsReady() and (SoulShards < 2.5) then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt aoe 28"; end
  end
  -- chaos_bolt,if=soul_shard>3.5-(0.1*active_enemies)&!talent.rain_of_fire
  if S.ChaosBolt:IsReady() and (SoulShards > 3.5 - (0.1 * EnemiesCount8ySplash) and not S.RainofFire:IsAvailable()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt aoe 30"; end
  end
  -- cataclysm,if=raid_event.adds.in>15|talent.wither
  if S.Cataclysm:IsReady() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm aoe 32"; end
  end
  -- havoc,target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target),if=(!cooldown.summon_infernal.up|!talent.summon_infernal|(talent.inferno&active_enemies>4))&target.time_to_die>8&(cooldown.malevolence.remains>15|!talent.malevolence)|time<5
  if S.Havoc:IsReady() and ((S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable() or (S.Inferno:IsAvailable() and EnemiesCount8ySplash > 4)) and (S.Malevolence:CooldownRemains() > 15 or not S.Malevolence:IsAvailable()) or HL.CombatTime() < 5) then
    local BestUnit, BestConditionValue, CUCV = nil, nil, nil
    for _, CycleUnit in pairs(Enemies8ySplash) do
      if CycleUnit:GUID() ~= Target:GUID() then
        if BestConditionValue then
          CUCV = EvaluateTargetIfFilterHavoc(CycleUnit)
        end
        if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
          and (not BestConditionValue or Utils.CompareThis("min", CUCV, BestConditionValue)) then
          BestUnit, BestConditionValue = CycleUnit, CUCV
        end
      end
    end
    if BestUnit and EvaluateTargetIfHavoc(BestUnit) then
      HR.CastLeftNameplate(BestUnit, S.Havoc)
    end
  end
  -- wither,target_if=min:dot.wither.remains+99*debuff.havoc.remains,if=dot.wither.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.wither.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&active_dot.wither<=active_enemies&target.time_to_die>18
  if S.Wither:IsReady() and (S.WitherDebuff:AuraActiveCount() <= EnemiesCount8ySplash) then
    if Everyone.CastTargetIf(S.Wither, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains2, EvaluateTargetIfWitherAoE2, not Target:IsSpellInRange(S.Wither)) then return "wither aoe 34"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains|time<5)&(active_dot.immolate<=6&!(talent.diabolic_ritual&talent.inferno)|active_dot.immolate<=4)&target.time_to_die>18
  if S.Immolate:IsCastable() and (S.ImmolateDebuff:AuraActiveCount() <= 6 and not (S.DiabolicRitual:IsAvailable() and S.Inferno:IsAvailable()) or S.ImmolateDebuff:AuraActiveCount() <= 4) then
    if Everyone.CastTargetIf(S.Immolate, Enemies8ySplash, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 36"; end
  end
  -- call_action_list,name=ogcd
  -- Note: Skipping this line, as the ogcd call at the start of the function covers it.
  -- summon_infernal,if=cooldown.invoke_power_infusion_0.up|cooldown.invoke_power_infusion_0.duration=0|fight_remains>=120
  -- Note: Not handling power_infusion conditions.
  if CDsON() and S.SummonInfernal:IsReady() then
    if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal aoe 38"; end
  end
  -- rain_of_fire,if=debuff.pyrogenics.down&active_enemies<=4&!talent.diabolic_ritual
  if S.RainofFire:IsReady() and (Target:DebuffDown(S.PyrogenicsDebuff) and EnemiesCount8ySplash <= 4 and not S.DiabolicRitual:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 40"; end
  end
  -- channel_demonfire,if=dot.immolate.remains+dot.wither.remains>cast_time
  if S.ChannelDemonfire:IsReady() and (Target:DebuffRemains(S.ImmolateDebuff) + Target:DebuffRemains(S.WitherDebuff) > ChannelDemonfireCastTime()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire aoe 42"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=((dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains))|active_enemies>active_dot.immolate)&target.time_to_die>10&!havoc_active&!(talent.diabolic_ritual&talent.inferno)
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies8ySplash, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE2, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 44"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=((dot.immolate.refreshable&variable.havoc_immo_time<5.4)|(dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|(variable.havoc_immo_time<2)*havoc_active)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&target.time_to_die>11&!(talent.diabolic_ritual&talent.inferno)
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies8ySplash, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE3, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 46"; end
  end
  -- dimensional_rift
  if CDsON() and S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift aoe 48"; end
  end
  -- soul_fire,target_if=min:(dot.wither.remains+dot.immolate.remains-5*debuff.conflagrate.up+100*debuff.havoc.remains),if=buff.decimation.up
  if S.SoulFire:IsCastable() and (Player:BuffUp(S.DecimationBuff)) then
    if Everyone.CastTargetIf(S.SoulFire, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains3, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire aoe 50"; end
  end
  -- incinerate,if=talent.fire_and_brimstone.enabled&buff.backdraft.up
  if S.Incinerate:IsCastable() and (S.FireandBrimstone:IsAvailable() and Player:BuffUp(S.BackdraftBuff)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 52"; end
  end
  -- conflagrate,if=buff.backdraft.stack<2|!talent.backdraft
  if S.Conflagrate:IsCastable() and (Player:BuffStack(S.BackdraftBuff) < 2 or not S.Backdraft:IsAvailable()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate aoe 54"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 56"; end
  end
end

local function Cleave()
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd.max
  if VarHavocActive and VarHavocRemains > Player:GCD() then
    local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
  end
  -- variable,name=pool_soul_shards,value=cooldown.havoc.remains<=5|talent.mayhem
  VarPoolSoulShards = (S.Havoc:CooldownRemains() <= 5) or S.Mayhem:IsAvailable()
  -- malevolence,if=(!cooldown.summon_infernal.up|!talent.summon_infernal)
  if S.Malevolence:IsReady() and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable()) then
    if Cast(S.Malevolence, nil, nil, not Target:IsSpellInRange(S.Malevolence)) then return "malevolence cleave 2"; end
  end
  -- havoc,target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target),if=(!cooldown.summon_infernal.up|!talent.summon_infernal)&target.time_to_die>8
  if S.Havoc:IsCastable() and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable()) then
    local BestUnit, BestConditionValue, CUCV = nil, nil, nil
    for _, CycleUnit in pairs(Enemies40y) do
      if CycleUnit:GUID() ~= Target:GUID() then
        if BestConditionValue then
          CUCV = EvaluateTargetIfFilterHavoc(CycleUnit)
        end
        if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
          and (not BestConditionValue or Utils.CompareThis("min", CUCV, BestConditionValue)) then
          BestUnit, BestConditionValue = CycleUnit, CUCV
        end
      end
    end
    if BestUnit and EvaluateTargetIfHavoc(BestUnit) then
      HR.CastLeftNameplate(BestUnit, S.Havoc)
    end
  end
  -- chaos_bolt,if=demonic_art
  if S.ChaosBolt:IsReady() and (DemonicArt()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 4"; end
  end
  -- soul_fire,if=buff.decimation.react&(soul_shard<=4|buff.decimation.remains<=gcd.max*2)&debuff.conflagrate.remains>=execute_time&cooldown.havoc.remains
  if S.SoulFire:IsReady() and (Player:BuffUp(S.DecimationBuff) and (SoulShards <= 4 or Player:BuffRemains(S.DecimationBuff) <= Player:GCD() * 2) and Target:DebuffRemains(S.ConflagrateDebuff) >= S.SoulFire:ExecuteTime() and S.Havoc:CooldownDown()) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 6"; end
  end
  -- wither,target_if=min:dot.wither.remains+99*debuff.havoc.remains,if=talent.internal_combustion&(((dot.wither.remains-5*action.chaos_bolt.in_flight)<dot.wither.duration*0.4)|dot.wither.remains<3|(dot.wither.remains-action.chaos_bolt.execute_time)<5&action.chaos_bolt.usable)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains-5))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
  if S.Wither:IsReady() and (S.InternalCombustion:IsAvailable() and not S.SoulFire:InFlight()) then
    if Everyone.CastTargetIf(S.Wither, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains2, EvaluateTargetIfWitherCleave, not Target:IsSpellInRange(S.Wither)) then return "wither cleave 8"; end
  end
  -- wither,target_if=min:dot.wither.remains+99*debuff.havoc.remains,if=!talent.internal_combustion&(((dot.wither.remains-5*(action.chaos_bolt.in_flight))<dot.wither.duration*0.3)|dot.wither.remains<3)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
  if S.Wither:IsReady() and (not S.InternalCombustion:IsAvailable() and not S.SoulFire:InFlight()) then
    if Everyone.CastTargetIf(S.Wither, Enemies8ySplash, "min", EvaluateTargetIfFilterWitherRemains2, EvaluateTargetIfWitherCleave2, not Target:IsSpellInRange(S.Wither)) then return "wither cleave 8"; end
  end
  -- conflagrate,if=(talent.roaring_blaze.enabled&full_recharge_time<=gcd.max*2)|recharge_time<=8&(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)<gcd.max)&!variable.pool_soul_shards
  if S.Conflagrate:IsCastable() and ((S.RoaringBlaze:IsAvailable() and S.Conflagrate:FullRechargeTime() <= Player:GCD() * 2) or S.Conflagrate:Recharge() <= 8 and (DiabolicRitual() and (VarDRSum) < Player:GCD()) and not VarPoolSoulShards) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 10"; end
  end
  -- shadowburn,if=(cooldown.shadowburn.full_recharge_time<=gcd.max*3|debuff.eradication.remains<=gcd.max&talent.eradication&!action.chaos_bolt.in_flight&!talent.diabolic_ritual)&(talent.conflagration_of_chaos|talent.blistering_atrophy)|fight_remains<=8
  if S.Shadowburn:IsReady() and ((S.Shadowburn:FullRechargeTime() <= Player:GCD() * 3 or Target:DebuffRemains(S.EradicationDebuff) <= Player:GCD() and S.Eradication:IsAvailable() and not S.ChaosBolt:InFlight() and not S.DiabolicRitual:IsAvailable()) and (S.ConflagrationofChaos:IsAvailable() or S.BlisteringAtrophy:IsAvailable()) or BossFightRemains <= 8) then
    if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn cleave 12"; end
  end
  -- chaos_bolt,if=buff.ritual_of_ruin.up
  if S.ChaosBolt:IsReady() and (Player:BuffUp(S.RitualofRuinBuff)) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 14"; end
    end
  if S.SummonInfernal:CooldownRemains() >= 90 and S.RainofChaos:IsAvailable() then
    -- rain_of_fire,if=cooldown.summon_infernal.remains>=90&talent.rain_of_chaos
    if S.RainofFire:IsReady() then
      if Cast(S.RainofFire, nil, nil, not Target:IsInRange(40)) then return "rain_of_fire cleave 16"; end
    end
    -- shadowburn,if=cooldown.summon_infernal.remains>=90&talent.rain_of_chaos
    if S.Shadowburn:IsReady() then
      if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn cleave 18"; end
    end
    -- chaos_bolt,if=cooldown.summon_infernal.remains>=90&talent.rain_of_chaos
    if S.ChaosBolt:IsReady() then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 20"; end
    end
  end
  -- ruination,if=(debuff.eradication.remains>=execute_time|!talent.eradication|!talent.shadowburn)
  if S.RuinationAbility:IsReady() and (Target:DebuffRemains(S.EradicationDebuff) >= S.RuinationAbility:ExecuteTime() or not S.Eradication:IsAvailable() or not S.Shadowburn:IsAvailable()) then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination cleave 22"; end
  end
  -- cataclysm,if=raid_event.adds.in>15
  if S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm cleave 24"; end
  end
  -- channel_demonfire,if=talent.raging_demonfire&(dot.immolate.remains+dot.wither.remains-5*(action.chaos_bolt.in_flight&talent.internal_combustion))>cast_time
  if S.ChannelDemonfire:IsReady() and (S.RagingDemonfire:IsAvailable() and (Target:DebuffRemains(S.ImmolateDebuff) + Target:DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight() and S.InternalCombustion:IsAvailable())) > S.ChannelDemonfire:CastTime()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 26"; end
  end
  -- soul_fire,if=soul_shard<=3.5&(debuff.conflagrate.remains>cast_time+travel_time|!talent.roaring_blaze&buff.backdraft.up)&!variable.pool_soul_shards
  if S.SoulFire:IsCastable() and (SoulShards <= 3.5 and (Target:DebuffRemains(S.RoaringBlazeDebuff) > S.SoulFire:CastTime() + S.SoulFire:TravelTime() or not S.RoaringBlaze:IsAvailable() and Player:BuffUp(S.BackdraftBuff)) and not VarPoolSoulShards) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 28"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=(dot.immolate.refreshable&(dot.immolate.remains<cooldown.havoc.remains|!dot.immolate.ticking))&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains+(!talent.mayhem*action.soul_fire.cast_time)>dot.immolate.remains)&target.time_to_die>15
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies8ySplash, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateCleave, not Target:IsSpellInRange(S.Immolate)) then return "immolate cleave 30"; end
  end
  -- summon_infernal
  if CDsON() and S.SummonInfernal:IsCastable() then
    if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal cleave 32"; end
  end
  -- incinerate,if=talent.diabolic_ritual&(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains-2-!variable.disable_cb_2t*action.chaos_bolt.cast_time-variable.disable_cb_2t*gcd.max)<=0)
  if S.Incinerate:IsCastable() and (S.DiabolicRitual:IsAvailable() and (DiabolicRitual() and (VarDRSum - 2 - num(not VarDisableCB2T) * S.ChaosBolt:CastTime() - num(VarDisableCB2T) * Player:GCD()) <= 0)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 34"; end
  end
  -- rain_of_fire,if=variable.pooling_condition&!talent.wither&buff.rain_of_chaos.up
  if S.RainofFire:IsReady() and (VarPoolingCondition and not S.Wither:IsAvailable() and Player:BuffUp(S.RainofChaosBuff)) then
    if Cast(S.RainofFire, nil, nil, not Target:IsInRange(40)) then return "rain_of_fire cleave 36"; end
  end
  -- rain_of_fire,if=variable.allow_rof_2t_spender>=1&!talent.wither&talent.pyrogenics&debuff.pyrogenics.remains<=gcd.max&(!talent.rain_of_chaos|cooldown.summon_infernal.remains>=gcd.max*3)&variable.pooling_condition
  if S.RainofFire:IsReady() and (VarAllowRoF2TSpender >= 1 and not S.Wither:IsAvailable() and S.Pyrogenics:IsAvailable() and Target:DebuffRemains(S.PyrogenicsDebuff) <= Player:GCD() and (not S.RainofChaos:IsAvailable() or S.SummonInfernal:CooldownRemains() >= Player:GCD() * 3) and VarPoolingCondition) then
    if Cast(S.RainofFire, nil, nil, not Target:IsInRange(40)) then return "rain_of_fire cleave 38"; end
  end
  -- rain_of_fire,if=variable.do_rof_2t&variable.pooling_condition&(cooldown.summon_infernal.remains>=gcd.max*3|!talent.rain_of_chaos)
  if S.RainofFire:IsReady() and (VarDoRoF2T and VarPoolingCondition and (S.SummonInfernal:CooldownRemains() >= Player:GCD() * 3 or not S.RainofChaos:IsAvailable())) then
    if Cast(S.RainofFire, nil, nil, not Target:IsInRange(40)) then return "rain_of_fire cleave 40"; end
  end
  -- soul_fire,if=soul_shard<=4&talent.mayhem
  if S.SoulFire:IsCastable() and (SoulShards <= 4 and S.Mayhem:IsAvailable()) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 42"; end
  end
  -- chaos_bolt,if=!variable.disable_cb_2t&variable.pooling_condition_cb&(cooldown.summon_infernal.remains>=gcd.max*3|soul_shard>4|!talent.rain_of_chaos)
  if S.ChaosBolt:IsReady() and (not VarDisableCB2T and VarPoolingConditionCB and (S.SummonInfernal:CooldownRemains() >= Player:GCD() * 3 or SoulShards > 4 or not S.RainofChaos:IsAvailable())) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 44"; end
  end
  -- channel_demonfire
  if S.ChannelDemonfire:IsReady() then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 46"; end
  end
  -- dimensional_rift
  if S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift cleave 48"; end
  end
  -- infernal_bolt
  if S.InfernalBolt:IsReady() then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt cleave 50"; end
  end
  -- conflagrate,if=charges>(max_charges-1)|fight_remains<gcd.max*charges
  if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < Player:GCD() * S.Conflagrate:Charges()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 52"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 54"; end
  end
end

local function Variables()
  -- variable,name=havoc_immo_time,op=reset
  VarHavocImmoTime = 0
  -- variable,name=pooling_condition,value=(soul_shard>=3|(talent.secrets_of_the_coven&buff.infernal_bolt.up|buff.decimation.up)&soul_shard>=3),default=1,op=set
  VarPoolingCondition = SoulShards >= 3 or (S.SecretsoftheCoven:IsAvailable() and Player:BuffUp(S.InfernalBoltBuff) or Player:BuffUp(S.DecimationBuff)) and SoulShards >= 3
  -- variable,name=pooling_condition_cb,value=variable.pooling_condition|pet.infernal.active&soul_shard>=3,default=1,op=set
  VarPoolingConditionCB = VarPoolingCondition or InfernalActive() and SoulShards >= 3
  -- cycling_variable,name=havoc_immo_time,op=add,value=dot.immolate.remains*debuff.havoc.up<?dot.wither.remains*debuff.havoc.up
  for _, CycleUnit in pairs(Enemies8ySplash) do
    local HavocUp = num(CycleUnit:DebuffUp(S.HavocDebuff))
    VarHavocImmoTime = VarHavocImmoTime + max(CycleUnit:DebuffRemains(S.ImmolateDebuff) * HavocUp, CycleUnit:DebuffRemains(S.WitherDebuff) * HavocUp)
  end
  -- variable,name=infernal_active,op=set,value=pet.infernal.active|(cooldown.summon_infernal.duration-cooldown.summon_infernal.remains)<20
  VarInfernalActive = InfernalActive() or S.SummonInfernal:TimeSinceLastCast() < 20
  -- variable,name=trinket_1_will_lose_cast,value=((floor((fight_remains%trinket.1.cooldown.duration)+1)!=floor((fight_remains+(cooldown.summon_infernal.duration-cooldown.summon_infernal.remains))%cooldown.summon_infernal.duration))&(floor((fight_remains%trinket.1.cooldown.duration)+1))!=(floor(((fight_remains-cooldown.summon_infernal.remains)%trinket.1.cooldown.duration)+1))|((floor((fight_remains%trinket.1.cooldown.duration)+1)=floor((fight_remains+(cooldown.summon_infernal.duration-cooldown.summon_infernal.remains))%cooldown.summon_infernal.duration))&(((fight_remains-cooldown.summon_infernal.remains%%trinket.1.cooldown.duration)-cooldown.summon_infernal.remains-variable.trinket_1_buff_duration)>0)))&cooldown.summon_infernal.remains>20
  -- Note: Let's avoid divide by zero...
  local T1CD = (VarTrinket1CD > 0) and VarTrinket1CD or 1
  VarT1WillLoseCast = ((floor((FightRemains / T1CD) + 1) ~= floor((FightRemains + (120 - S.SummonInfernal:CooldownRemains())) / 120)) and (floor((FightRemains / T1CD) + 1)) ~= (floor(((FightRemains - S.SummonInfernal:CooldownRemains()) / T1CD) + 1)) or ((floor((FightRemains / T1CD) + 1) == floor((FightRemains + (120 - S.SummonInfernal:CooldownRemains())) / 120)) and (((FightRemains - S.SummonInfernal:CooldownRemains() % T1CD) - S.SummonInfernal:CooldownRemains() - VarTrinket1BuffDuration) > 0))) and S.SummonInfernal:CooldownRemains() > 20
  -- variable,name=trinket_2_will_lose_cast,value=((floor((fight_remains%trinket.2.cooldown.duration)+1)!=floor((fight_remains+(cooldown.summon_infernal.duration-cooldown.summon_infernal.remains))%cooldown.summon_infernal.duration))&(floor((fight_remains%trinket.2.cooldown.duration)+1))!=(floor(((fight_remains-cooldown.summon_infernal.remains)%trinket.2.cooldown.duration)+1))|((floor((fight_remains%trinket.2.cooldown.duration)+1)=floor((fight_remains+(cooldown.summon_infernal.duration-cooldown.summon_infernal.remains))%cooldown.summon_infernal.duration))&(((fight_remains-cooldown.summon_infernal.remains%%trinket.2.cooldown.duration)-cooldown.summon_infernal.remains-variable.trinket_2_buff_duration)>0)))&cooldown.summon_infernal.remains>20
  -- Note: Let's avoid divide by zero...
  local T2CD = (VarTrinket2CD > 0) and VarTrinket2CD or 1
  VarT2WillLoseCast = ((floor((FightRemains / T2CD) + 1) ~= floor((FightRemains + (120 - S.SummonInfernal:CooldownRemains())) / 120)) and (floor((FightRemains / T2CD) + 1)) ~= (floor(((FightRemains - S.SummonInfernal:CooldownRemains()) / T2CD) + 1)) or ((floor((FightRemains / T2CD) + 1) == floor((FightRemains + (120 - S.SummonInfernal:CooldownRemains())) / 120)) and (((FightRemains - S.SummonInfernal:CooldownRemains() % T2CD) - S.SummonInfernal:CooldownRemains() - VarTrinket2BuffDuration) > 0))) and S.SummonInfernal:CooldownRemains() > 20
end

--- ===== APL Main =====
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(12)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(12)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Check Havoc Status
    VarHavocActive, VarHavocRemains, VarHavocImmoTime = UnitWithHavoc(Enemies40y)

    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Soul Shards
    SoulShards = Player:SoulShardsP()

    -- Variables for buffs/debuffs that we check often.
    VarDRMotherBuffRemains = Player:BuffRemains(S.DiabolicRitualMotherBuff)
    VarDROverlordBuffRemains = Player:BuffRemains(S.DiabolicRitualOverlordBuff)
    VarDRPitLordBuffRemains = Player:BuffRemains(S.DiabolicRitualPitLordBuff)
    VarDRSum = VarDRMotherBuffRemains + VarDROverlordBuffRemains + VarDRPitLordBuffRemains
    VarSFCDRPlusCT = S.SoulFire:CooldownRemains() + S.SoulFire:CastTime()
  end

  -- Summon Pet
  if S.SummonPet:IsCastable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if Cast(S.SummonPet, Settings.Destruction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.SpellLock, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=aoe,if=(active_enemies>=3)&!variable.cleave_apl
    if AoEON() and EnemiesCount8ySplash >= 3 and not VarCleaveAPL then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies!=1|variable.cleave_apl
    if AoEON() and (EnemiesCount8ySplash > 1 or VarCleaveAPL) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- malevolence,if=cooldown.summon_infernal.remains>=55
    if S.Malevolence:IsReady() and (S.SummonInfernal:CooldownRemains() >= 55) then
      if Cast(S.Malevolence, nil, nil, not Target:IsSpellInRange(S.Malevolence)) then return "malevolence main 2"; end
    end
    -- wait,sec=((buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)),if=(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)<gcd.max*0.25)&soul_shard>2
    -- TODO: Add wait?
    -- chaos_bolt,if=demonic_art
    if S.ChaosBolt:IsReady() and (DemonicArt()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 4"; end
    end
    -- soul_fire,if=buff.decimation.react&(soul_shard<=4|buff.decimation.remains<=gcd.max*2)&debuff.conflagrate.remains>=execute_time
    if S.SoulFire:IsCastable() and (Player:BuffUp(S.DecimationBuff) and (SoulShards <= 4 or Player:BuffRemains(S.DecimationBuff) <= Player:GCD() * 2) and Target:DebuffRemains(S.ConflagrateDebuff) >= S.SoulFire:ExecuteTime()) then
      if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire main 6"; end
    end
    -- wither,if=talent.internal_combustion&(((dot.wither.remains-5*action.chaos_bolt.in_flight)<dot.wither.duration*0.4)|dot.wither.remains<3|(dot.wither.remains-action.chaos_bolt.execute_time)<5&action.chaos_bolt.usable)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains-5))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
    if S.Wither:IsReady() and (S.InternalCombustion:IsAvailable() and (((Target:DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight())) < S.WitherDebuff:MaxDuration() * 4) or Target:DebuffRemains(S.WitherDebuff) < 3 or (Target:DebuffRemains(S.WitherDebuff) - S.ChaosBolt:ExecuteTime()) < 5 and S.ChaosBolt:IsReady()) and (not S.SoulFire:IsAvailable() or VarSFCDRPlusCT > (Target:DebuffRemains(S.WitherDebuff) - 5)) and Target:TimeToDie() > 8 and not S.SoulFire:InFlight()) then
      if Cast(S.Wither, nil, nil, not Target:IsInRange(40)) then return "wither main 8"; end
    end
    -- conflagrate,if=talent.roaring_blaze&debuff.conflagrate.remains<1.5|full_recharge_time<=gcd.max*2|recharge_time<=8&(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains)<gcd.max)&soul_shard>=1.5
    if S.Conflagrate:IsReady() and (S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.RoaringBlazeDebuff) < 1.5 or S.Conflagrate:FullRechargeTime() <= Player:GCD() * 2 or S.Conflagrate:Recharge() <= 8 and (DiabolicRitual() and VarDRSum < Player:GCD()) and SoulShards >= 1.5) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 10"; end
    end
    -- shadowburn,if=(cooldown.shadowburn.full_recharge_time<=gcd.max*3|debuff.eradication.remains<=gcd.max&talent.eradication&!action.chaos_bolt.in_flight&!talent.diabolic_ritual)&(talent.conflagration_of_chaos|talent.blistering_atrophy)|fight_remains<=8
    if S.Shadowburn:IsReady() and ((S.Shadowburn:FullRechargeTime() <= Player:GCD() * 3 or Target:DebuffRemains(S.EradicationDebuff) <= Player:GCD() and S.Eradication:IsAvailable() and not S.ChaosBolt:InFlight() and not S.DiabolicRitual:IsAvailable()) and (S.ConflagrationofChaos:IsAvailable() or S.BlisteringAtrophy:IsAvailable()) or BossFightRemains <= 8) then
      if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn main 12"; end
    end
    -- chaos_bolt,if=buff.ritual_of_ruin.up
    if S.ChaosBolt:IsReady() and (Player:BuffUp(S.RitualofRuinBuff)) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 14"; end
    end
    -- shadowburn,if=(cooldown.summon_infernal.remains>=90&talent.rain_of_chaos)|buff.malevolence.up
    if S.Shadowburn:IsReady() and ((S.SummonInfernal:CooldownRemains() >= 90 and S.RainofChaos:IsAvailable()) or Player:BuffUp(S.MalevolenceBuff)) then
      if Cast(S.Shadowburn, nil, nil, not Target:IsSpellInRange(S.Shadowburn)) then return "shadowburn main 16"; end
    end
    -- chaos_bolt,if=(cooldown.summon_infernal.remains>=90&talent.rain_of_chaos)|buff.malevolence.up
    if S.ChaosBolt:IsReady() and ((S.SummonInfernal:CooldownRemains() >= 90 and S.RainofChaos:IsAvailable()) or Player:BuffUp(S.MalevolenceBuff)) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 16"; end
    end
    -- ruination,if=(debuff.eradication.remains>=execute_time|!talent.eradication|!talent.shadowburn)
    if S.RuinationAbility:IsReady() and (Target:DebuffRemains(S.EradicationDebuff) >= S.RuinationAbility:ExecuteTime() or not S.Eradication:IsAvailable() or not S.Shadowburn:IsAvailable()) then
      if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination main 18"; end
    end
    -- cataclysm,if=raid_event.adds.in>15&(dot.immolate.refreshable&!talent.wither|talent.wither&dot.wither.refreshable)
    if S.Cataclysm:IsReady() and (Target:DebuffRefreshable(S.ImmolateDebuff) and not S.Wither:IsAvailable() or S.Wither:IsAvailable() and Target:DebuffRefreshable(S.WitherDebuff)) then
      if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm main 20"; end
    end
    -- channel_demonfire,if=talent.raging_demonfire&(dot.immolate.remains+dot.wither.remains-5*(action.chaos_bolt.in_flight&talent.internal_combustion))>cast_time
    if S.ChannelDemonfire:IsReady() and (S.RagingDemonfire:IsAvailable() and (Target:DebuffRemains(S.ImmolateDebuff) + Target:DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight() and S.InternalCombustion:IsAvailable())) > S.ChannelDemonfire:CastTime()) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 22"; end
    end
    -- wither,if=!talent.internal_combustion&(((dot.wither.remains-5*(action.chaos_bolt.in_flight))<dot.wither.duration*0.3)|dot.wither.remains<3)&(!talent.cataclysm|cooldown.cataclysm.remains>dot.wither.remains)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.wither.remains))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
    if S.Wither:IsReady() and (not S.InternalCombustion:IsAvailable() and (((Target:DebuffRemains(S.WitherDebuff) - 5 * num(S.ChaosBolt:InFlight())) < S.WitherDebuff:MaxDuration() * 0.3) or Target:DebuffRemains(S.WitherDebuff) < 3) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > Target:DebuffRemains(S.WitherDebuff)) and (not S.SoulFire:IsAvailable() or VarSFCDRPlusCT > Target:DebuffRemains(S.WitherDebuff)) and Target:TimeToDie() > 8 and not S.SoulFire:InFlight()) then
      if Cast(S.Wither, nil, nil, not Target:IsInRange(40)) then return "wither main 24"; end
    end
    -- immolate,if=(((dot.immolate.remains-5*(action.chaos_bolt.in_flight&talent.internal_combustion))<dot.immolate.duration*0.3)|dot.immolate.remains<3|(dot.immolate.remains-action.chaos_bolt.execute_time)<5&talent.internal_combustion&action.chaos_bolt.usable)&(!talent.cataclysm|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.immolate.remains-5*talent.internal_combustion))&target.time_to_die>8&!action.soul_fire.in_flight_to_target
    if S.Immolate:IsReady() and ((((Target:DebuffRemains(S.ImmolateDebuff) - 5 * num(S.ChaosBolt:InFlight() and S.InternalCombustion:IsAvailable())) < S.ImmolateDebuff:MaxDuration() * 0.3) or Target:DebuffRemains(S.ImmolateDebuff) < 3 or (Target:DebuffRemains(S.ImmolateDebuff) - S.ChaosBolt:ExecuteTime()) < 5 and S.InternalCombustion:IsAvailable() and S.ChaosBolt:IsReady()) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > Target:DebuffRemains(S.ImmolateDebuff)) and (not S.SoulFire:IsAvailable() or VarSFCDRPlusCT > (Target:DebuffRemains(S.ImmolateDebuff) - 5 * num(S.InternalCombustion:IsAvailable()))) and Target:TimeToDie() > 8 and not S.SoulFire:InFlight()) then
      if Cast(S.Immolate, nil, nil, not Target:IsSpellInRange(S.Immolate)) then return "immolate main 26"; end
    end
    -- summon_infernal
    if CDsON() and S.SummonInfernal:IsCastable() then
      if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal main 28"; end
    end
    -- incinerate,if=talent.diabolic_ritual&(diabolic_ritual&(buff.diabolic_ritual_mother_of_chaos.remains+buff.diabolic_ritual_overlord.remains+buff.diabolic_ritual_pit_lord.remains-2-!variable.disable_cb_2t*action.chaos_bolt.cast_time-variable.disable_cb_2t*gcd.max)<=0)
    if S.Incinerate:IsCastable() and (S.DiabolicRitual:IsAvailable() and (DiabolicRitual() and (VarDRSum - 2 - num(not VarDisableCB2T) * S.ChaosBolt:CastTime() - num(VarDisableCB2T) * Player:GCD()) <= 0)) then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate main 30"; end
    end
    -- chaos_bolt,if=variable.pooling_condition_cb&(cooldown.summon_infernal.remains>=gcd.max*3|soul_shard>4|!talent.rain_of_chaos)
    if S.ChaosBolt:IsReady() and (VarPoolingConditionCB and (S.SummonInfernal:CooldownRemains() >= Player:GCD() * 3 or SoulShards > 4 or not S.RainofChaos:IsAvailable())) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 32"; end
    end
    -- channel_demonfire
    if S.ChannelDemonfire:IsReady() then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 34"; end
    end
    -- dimensional_rift
    if CDsON() and S.DimensionalRift:IsCastable() then
      if Cast(S.DimensionalRift, Settings.Destruction.GCDasOffGCD.DimensionalRift, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift main 36"; end
    end
    -- infernal_bolt
    if S.InfernalBolt:IsCastable() then
      if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt main 38"; end
    end
    -- conflagrate,if=charges>(max_charges-1)|fight_remains<gcd.max*charges
    if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < Player:GCD() * S.Conflagrate:Charges()) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 40"; end
    end
    -- soul_fire,if=buff.backdraft.up
    if S.SoulFire:IsCastable() and (Player:BuffUp(S.BackdraftBuff)) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire main 42"; end
  end
    -- incinerate
    if S.Incinerate:IsCastable() then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate main 36"; end
    end
  end
end

local function OnInit()
  S.ImmolateDebuff:RegisterAuraTracking()
  S.WitherDebuff:RegisterAuraTracking()

  HR.Print("Destruction Warlock rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(267, APL, OnInit)