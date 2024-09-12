--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
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
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Warlock    = HR.Commons.Warlock
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local mathmax    = math.max
local mathmin    = math.min
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Demonology
local I = Item.Warlock.Demonology

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- DF Trinkets
  I.MirrorofFracturedTomorrows:ID(),
  -- TWW Trinkets
  I.ImperfectAscendancySerum:ID(),
  I.SpymastersWeb:ID()
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  CommonsDS = HR.GUISettings.APL.Warlock.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warlock.CommonsOGCD,
  Demonology = HR.GUISettings.APL.Warlock.Demonology
}

--- ===== Rotation Variables =====
local VarNextTyrantCD = 0
local VarInOpener = true
local VarImpDespawn = 0
local VarImpl = false
local VarPoolCoresForTyrant = false
local VarDiabolicRitualRemains = 0
local VilefiendAbility = S.MarkofFharg:IsAvailable() and S.SummonCharhound or (S.MarkofShatug:IsAvailable() and S.SummonGloomhound or S.SummonVilefiend)
local SoulShards = 0
local DemonicCoreStacks = 0
local CombatTime = 0
local GCDMax = 0
local Enemies40y
local Enemies8ySplash, EnemiesCount8ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Non-Trinket Precombat Variables =====
local VarFirstTyrantTime = 12
local function SetPrecombatVariables()
  VarFirstTyrantTime = 12
  VarFirstTyrantTime = VarFirstTyrantTime + (S.GrimoireFelguard:IsAvailable() and S.GrimoireFelguard:ExecuteTime() or 0)
  VarFirstTyrantTime = VarFirstTyrantTime + (S.SummonVilefiend:IsAvailable() and S.SummonVilefiend:ExecuteTime() or 0)
  VarFirstTyrantTime = VarFirstTyrantTime + ((S.GrimoireFelguard:IsAvailable() or S.SummonVilefiend:IsAvailable()) and Player:GCD() or 0)
  VarFirstTyrantTime = VarFirstTyrantTime - (S.SummonDemonicTyrant:ExecuteTime() + S.ShadowBolt:ExecuteTime())
  VarFirstTyrantTime = mathmin(VarFirstTyrantTime, 10)
end
SetPrecombatVariables()

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinket1BuffDuration, VarTrinket2BuffDuration
local VarTrinket1Sync, VarTrinket2Sync
local VarDamageTrinketPriority, VarTrinketPriority
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

  VarTrinket1Exclude = VarTrinket1ID == 193757
  VarTrinket2Exclude = VarTrinket2ID == 193757

  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1ID == I.ImperfectAscendancySerum:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.ImperfectAscendancySerum:ID()

  VarTrinket1BuffDuration = Trinket1:BuffDuration() + (VarTrinket1ID == I.MirrorofFracturedTomorrows:ID() and 20 or 0)
  VarTrinket2BuffDuration = Trinket2:BuffDuration() + (VarTrinket2ID == I.MirrorofFracturedTomorrows:ID() and 20 or 0)

  VarTrinket1Sync = 0.5
  if VarTrinket1Buffs and (VarTrinket1CD % 60 == 0 or 60 % VarTrinket1CD == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (VarTrinket2CD % 60 == 0 or 60 % VarTrinket2CD == 0) then
    VarTrinket2Sync = 1
  end

  local T1Level = Trinket1:Level() or 0
  local T2Level = Trinket2:Level() or 0
  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and T2Level > T1Level then
    VarDamageTrinketPriority = 2
  end

  -- Note: If BuffDuration is 0, set to 1 to avoid divide by zero errors.
  local T1BuffDur = VarTrinket1BuffDuration > 0 and VarTrinket1BuffDuration or 1
  local T2BuffDur = VarTrinket2BuffDuration > 0 and VarTrinket2BuffDuration or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > (((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync)) * (1 + ((Trinket1:Level() - Trinket2:Level()) / 100))) then
    VarTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.Shadowfury, "Cast Shadowfury (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarNextTyrantCD = 0
  VarInOpener = true
  VarImpDespawn = 0
  VarImpl = false
  VarPoolCoresForTyrant = false
  VarDiabolicRitualRemains = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Demonbolt:RegisterInFlight()
  S.HandofGuldan:RegisterInFlight()
  VilefiendAbility = S.MarkofFharg:IsAvailable() and S.SummonCharhound or (S.MarkofShatug:IsAvailable() and S.SummonGloomhound or S.Vilefiend)
  SetPrecombatVariables()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.Demonbolt:RegisterInFlight()
S.HandofGuldan:RegisterInFlight()

--- ===== Helper Functions =====
local function WildImpsCount()
  return Warlock.GuardiansTable.ImpCount or 0
end

-- Function to check two_cast_imps or last_cast_imps
local function CheckImpCasts(count)
  local ImpCount = 0
  for _, Pet in pairs(Warlock.GuardiansTable.Pets) do
    if Pet.ImpCasts <= count then
      ImpCount = ImpCount + 1
    end
  end
  return ImpCount
end

-- Function to check for Grimoire Felguard
local function GrimoireFelguardTime()
  return Warlock.GuardiansTable.FelguardDuration or 0
end

local function GrimoireFelguardActive()
  return GrimoireFelguardTime() > 0
end

-- Function to check for Demonic Tyrant
local function DemonicTyrantTime()
  return Warlock.GuardiansTable.DemonicTyrantDuration or 0
end

local function DemonicTyrantActive()
  return DemonicTyrantTime() > 0
end

-- Function to check for Dreadstalkers
local function DreadstalkerTime()
  return Warlock.GuardiansTable.DreadstalkerDuration or 0
end

local function DreadstalkerActive()
  return DreadstalkerTime() > 0
end

-- Function to check for Vilefiend
local function VilefiendTime()
  return Warlock.GuardiansTable.VilefiendDuration or 0
end

local function VilefiendActive()
  return VilefiendTime() > 0
end

-- Function to check for Pit Lord
local function PitLordTime()
  return Warlock.GuardiansTable.PitLordDuration or 0
end

local function PitLordActive()
  return PitLordTime() > 0
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfDemonbolt(TargetUnit)
  -- if=set_bonus.tier31_2pc&(debuff.doom_brand.remains>10&buff.demonic_core.up&soul_shard<4)&!variable.pool_cores_for_tyrant
  -- Note: All but debuff.doom_brand.remains handled prior to CastTargetIf.
  return TargetUnit:DebuffRemains(S.DoomBrandDebuff) > 10
end

--- ===== CastCycle Functions =====
local function EvaluateCycleDemonbolt(TargetUnit)
  -- target_if=(!debuff.doom.up|!action.demonbolt.in_flight&debuff.doom.remains<=2)
  return TargetUnit:DebuffDown(S.DoomDebuff) or not S.Demonbolt:InFlight() and Target:DebuffRemains(S.DoomDebuff) <= 2
end

local function EvaluateCycleDemonbolt2(TargetUnit)
  -- target_if=(!debuff.doom.up)|active_enemies<4
  return TargetUnit:DebuffDown(S.DoomDebuff) or EnemiesCount8ySplash < 4
end

local function EvaluateCycleDemonbolt3(TargetUnit)
  -- target_if=(!debuff.doom.up)|active_enemies<4,if=talent.doom&(debuff.doom.remains>10&buff.demonic_core.up&soul_shard<4-talent.quietus)&!variable.pool_cores_for_tyrant
  return (TargetUnit:DebuffDown(S.DoomDebuff) or EnemiesCount8ySplash < 4) and (Target:DebuffRemains(S.DoomDebuff) > 10 and Player:BuffUp(S.DemonicCoreBuff) and SoulShards < 4 - num(S.Quietus:IsAvailable()))
end

local function EvaluateCycleDoom(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.Doom)
end

local function EvaluateCycleDoomBrand(TargetUnit)
  -- target_if=!debuff.doom_brand.up
  return TargetUnit:DebuffDown(S.DoomBrandDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  -- Moved to APL()
  -- snapshot_stats
  -- variable,name=first_tyrant_time,op=set,value=12
  -- variable,name=first_tyrant_time,op=add,value=action.grimoire_felguard.execute_time,if=talent.grimoire_felguard.enabled
  -- variable,name=first_tyrant_time,op=add,value=action.summon_vilefiend.execute_time,if=talent.summon_vilefiend.enabled
  -- variable,name=first_tyrant_time,op=add,value=gcd.max,if=talent.grimoire_felguard.enabled|talent.summon_vilefiend.enabled
  -- variable,name=first_tyrant_time,op=sub,value=action.summon_demonic_tyrant.execute_time+action.shadow_bolt.execute_time
  -- variable,name=first_tyrant_time,op=min,value=10
  -- variable,name=in_opener,op=set,value=1
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell
  -- variable,name=trinket_1_manual,value=trinket.1.is.spymasters_web|trinket.1.is.imperfect_ascendancy_serum
  -- variable,name=trinket_2_manual,value=trinket.2.is.spymasters_web|trinket.2.is.imperfect_ascendancy_serum
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.mirror_of_fractured_tomorrows*20)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.mirror_of_fractured_tomorrows*20)
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.summon_demonic_tyrant.duration=0|cooldown.summon_demonic_tyrant.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.summon_demonic_tyrant.duration=0|cooldown.summon_demonic_tyrant.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>trinket.1.ilvl
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1.5+trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>(((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1.5+trinket.1.has_buff.intellect)*(variable.trinket_1_sync))*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED event handling.
  -- power_siphon
  -- Note: Only suggest Power Siphon if we won't overcap buff stacks, unless the buff is about to expire.
  if S.PowerSiphon:IsReady() and (DemonicCoreStacks + mathmax(WildImpsCount(), 2) <= 4 or Player:BuffRemains(S.DemonicCoreBuff) < 3) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon precombat 2"; end
  end
  -- Manually added: demonbolt,if=!target.is_boss&buff.demonic_core.up
  -- Note: This is to avoid suggesting ShadowBolt on a new pack of mobs when we have Demonic Core buff stacks.
  if S.Demonbolt:IsReady() and not Target:IsInBossList() and Player:BuffUp(S.DemonicCoreBuff) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 4"; end
  end
  -- demonbolt,if=!buff.power_siphon.up
  -- Note: Manually added power_siphon check so this line is skipped when power_siphon is used in Precombat.
  if S.Demonbolt:IsReady() and Player:BuffDown(S.DemonicCoreBuff) and not Player:PrevGCDP(1, S.PowerSiphon) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 6"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 8"; end
  end
end

local function FightEnd()
  -- grimoire_felguard,if=fight_remains<20
  if CDsON() and S.GrimoireFelguard:IsReady() and BossFightRemains < 20 then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard) then return "grimoire_felguard fight_end 2"; end
  end
  -- ruination
  if S.RuinationAbility:IsReady() then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination fight_end 4"; end
  end
  -- implosion,if=fight_remains<2*gcd.max&!prev_gcd.1.implosion
  if S.Implosion:IsReady() and (BossFightRemains < 2 * Player:GCD() and not Player:PrevGCDP(1, S.Implosion)) then
    if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion fight_end 6"; end
  end
  -- demonbolt,if=fight_remains<gcd.max*2*buff.demonic_core.stack+9&buff.demonic_core.react&(soul_shard<4|fight_remains<buff.demonic_core.stack*gcd.max)
  if S.Demonbolt:IsReady() and (BossFightRemains < Player:GCD() * 2 * DemonicCoreStacks + 9 and Player:BuffUp(S.DemonicCoreBuff) and (SoulShards < 4 or BossFightRemains < DemonicCoreStacks * Player:GCD())) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt fight_end 8"; end
  end
  -- call_dreadstalkers,if=fight_remains<20
  if S.CallDreadstalkers:IsReady() then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers fight_end 10"; end
  end
  -- summon_vilefiend,if=fight_remains<20
  if VilefiendAbility:IsReady() then
    if Cast(VilefiendAbility) then return "summon_vilefiend fight_end 12"; end
  end
  -- summon_demonic_tyrant,if=fight_remains<20
  if S.SummonDemonicTyrant:IsCastable() and (BossFightRemains < 20) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant fight_end 14"; end
  end
  -- demonic_strength,if=fight_remains<10
  if S.DemonicStrength:IsCastable() and (BossFightRemains < 10) then
    if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength fight_end 16"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<3&fight_remains<20
  if S.PowerSiphon:IsReady() and (DemonicCoreStacks < 3 and BossFightRemains < 20) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon fight_end 18"; end
  end
  -- demonbolt,if=fight_remains<gcd.max*2*buff.demonic_core.stack+9&buff.demonic_core.react&(soul_shard<4|fight_remains<buff.demonic_core.stack*gcd.max)
  if S.Demonbolt:IsReady() and (BossFightRemains < Player:GCD() * 2 * DemonicCoreStacks + 9 and Player:BuffUp(S.DemonicCoreBuff) and (SoulShards < 4 or BossFightRemains < DemonicCoreStacks * Player:GCD())) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt fight_end 20"; end
  end
  -- hand_of_guldan,if=soul_shard>2&fight_remains<gcd.max*2*buff.demonic_core.stack+9
  if S.HandofGuldan:IsReady() and (SoulShards > 2 and BossFightRemains < Player:GCD() * 2 * DemonicCoreStacks + 9) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan fight_end 22"; end
  end
  -- infernal_bolt
  if S.InfernalBolt:IsCastable() then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt fight_end 24"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!pet.demonic_tyrant.active&trinket.1.cast_time>0|!trinket.1.cast_time>0)&(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant|variable.trinket_priority=2&cooldown.summon_demonic_tyrant.remains>20&!pet.demonic_tyrant.active&trinket.2.cooldown.remains<cooldown.summon_demonic_tyrant.remains+5)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1&!variable.trinket_2_manual)|variable.trinket_1_buff_duration>=fight_remains
    if Trinket1:IsReady() and (VarTrinket1Buffs and not VarTrinket1Manual and (not DemonicTyrantActive() and VarTrinket1CastTime > 0 or not (VarTrinket1CastTime > 0)) and (DemonicTyrantActive() or not S.SummonDemonicTyrant:IsAvailable() or VarTrinketPriority == 2 and S.SummonDemonicTyrant:CooldownRemains() > 20 and not DemonicTyrantActive() and Trinket2:CooldownRemains() < S.SummonDemonicTyrant:CooldownRemains() + 5) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1 and not VarTrinket2Manual) or VarTrinket1BuffDuration >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 2"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!pet.demonic_tyrant.active&trinket.2.cast_time>0|!trinket.2.cast_time>0)&(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant|variable.trinket_priority=1&cooldown.summon_demonic_tyrant.remains>20&!pet.demonic_tyrant.active&trinket.1.cooldown.remains<cooldown.summon_demonic_tyrant.remains+5)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2&!variable.trinket_1_manual)|variable.trinket_2_buff_duration>=fight_remains\
    if Trinket2:IsReady() and (VarTrinket2Buffs and not VarTrinket2Manual and (not DemonicTyrantActive() and VarTrinket2CastTime > 0 or not (VarTrinket2CastTime > 0)) and (DemonicTyrantActive() or not S.SummonDemonicTyrant:IsAvailable() or VarTrinketPriority == 1 and S.SummonDemonicTyrant:CooldownRemains() > 20 and not DemonicTyrantActive() and Trinket1:CooldownRemains() < S.SummonDemonicTyrant:CooldownRemains() + 5) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2 and not VarTrinket1Manual) or VarTrinket2BuffDuration >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 4"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&((variable.damage_trinket_priority=1|trinket.2.cooldown.remains)&(trinket.1.cast_time>0&!pet.demonic_tyrant.active|!trinket.1.cast_time>0)|(time<20&variable.trinket_2_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
    if Trinket1:IsReady() and (not VarTrinket1Buffs and not VarTrinket1Manual and ((VarDmgTrinketPriority == 1 or Trinket2:CooldownDown()) and (VarTrinket1CastTime > 0 and not DemonicTyrantActive() or not (VarTrinket1CastTime > 0)) or (CombatTime < 20 and VarTrinket2Buffs) or S.SummonDemonicTyrant:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&((variable.damage_trinket_priority=2|trinket.1.cooldown.remains)&(trinket.2.cast_time>0&!pet.demonic_tyrant.active|!trinket.2.cast_time>0)|(time<20&variable.trinket_1_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
    if Trinket2:IsReady() and (not VarTrinket2Buffs and not VarTrinket2Manual and ((VarDmgTrinketPriority == 2 or Trinket1:CooldownDown()) and (VarTrinket2CastTime > 0 and not DemonicTyrantActive() or not (VarTrinket2CastTime > 0)) or (CombatTime < 20 and VarTrinket1Buffs) or S.SummonDemonicTyrant:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 8"; end
    end
    -- use_item,use_off_gcd=1,name=spymasters_web,if=pet.demonic_tyrant.active&fight_remains<=80&buff.spymasters_report.stack>=30&(!variable.trinket_1_buffs&trinket.2.is.spymasters_web|!variable.trinket_2_buffs&trinket.1.is.spymasters_web)|fight_remains<=20&(trinket.1.cooldown.remains&trinket.2.is.spymasters_web|trinket.2.cooldown.remains&trinket.1.is.spymasters_web|!variable.trinket_1_buffs|!variable.trinket_2_buffs)
    if I.SpymastersWeb:IsEquippedAndReady() and (DemonicTyrantActive() and BossFightRemains <= 80 and Player:BuffStack(S.SpymastersReportBuff) >= 30 and (not VarTrinket1Buffs and VarTrinket2ID == I.SpymastersWeb:ID() or not VarTrinket2Buffs and VarTrinket1ID == I.SpymastersWeb:ID()) or BossFightRemains <= 20 and (Trinket1:CooldownDown() and VarTrinket2ID == I.SpymastersWeb:ID() or Trinket2:CooldownDown() and VarTrinket1ID == I.SpymastersWeb:ID() or not VarTrinket1Buffs or not VarTrinket2Buffs)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web items 10"; end
    end
    -- use_item,use_off_gcd=1,name=imperfect_ascendancy_serum,if=pet.demonic_tyrant.active&gcd.remains>0|fight_remains<=30
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (DemonicTyrantActive() or BossFightRemains <= 30) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum items 12"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=main_hand
  if Settings.Commons.Enabled.Items then
    local MainHandToUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandToUse then
      if Cast(MainHandToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "use_item main_hand items 14"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=mirror_of_fractured_tomorrows,if=trinket.1.is.mirror_of_fractured_tomorrows&variable.trinket_priority=2|trinket.2.is.mirror_of_fractured_tomorrows&variable.trinket_priority=1
    if I.MirrorofFracturedTomorrows:IsEquippedAndReady() and (VarTrinket1ID == I.MirrorofFracturedTomorrows:ID() and VarTrinketPriority == 2 or VarTrinket2ID == I.MirrorofFracturedTomorrows:ID() and VarTrinketPriority == 1) then
      if Cast(I.MirrorofFracturedTomorrows, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows items 16"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)
    if Trinket1:IsReady() and (not VarTrinket1Buffs and (VarDmgTrinketPriority == 1 or Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 18"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains)
    if Trinket2:IsReady() and (not VarTrinket2Buffs and (VarDmgTrinketPriority == 2 or Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 20"; end
    end
  end
end

local function Opener()
  -- grimoire_felguard,if=soul_shard>=5-talent.fel_invocation
  if CDsON() and S.GrimoireFelguard:IsReady() and (SoulShards >= 5 - num(S.FelInvocation:IsAvailable())) then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard opener 2"; end
  end
  -- summon_vilefiend,if=soul_shard=5
  if VilefiendAbility:IsReady() and (SoulShards == 5) then
    if Cast(VilefiendAbility) then return "summon_vilefiend opener 4"; end
  end
  -- shadow_bolt,if=soul_shard<5&cooldown.call_dreadstalkers.up
  if S.ShadowBolt:IsCastable() and (SoulShards < 5 and S.CallDreadstalkers:CooldownUp()) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt opener 6"; end
  end
  -- call_dreadstalkers,if=soul_shard=5
  if S.CallDreadstalkers:IsReady() and (SoulShards == 5) then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers opener 8"; end
  end
  -- Ruination
  if S.RuinationAbility:IsReady() then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination opener 10"; end
  end
end

local function Racials()
  -- berserking,use_off_gcd=1
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racials 2"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racials 4"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racials 6"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racials 8"; end
  end
end

local function Tyrant()
  -- call_action_list,name=racials,if=variable.imp_despawn&variable.imp_despawn<time+gcd.max*2+action.summon_demonic_tyrant.cast_time&(prev_gcd.1.hand_of_guldan|prev_gcd.1.ruination)&(variable.imp_despawn&variable.imp_despawn<time+gcd.max+action.summon_demonic_tyrant.cast_time|soul_shard<2)
  if CDsON() and (VarImpDespawn and VarImpDespawn < CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and (Player:PrevGCDP(1, S.HandofGuldan) or Player:PrevGCDP(1, S.RuinationAbility)) and (VarImpDespawn and VarImpDespawn < CombatTime + Player:GCD() + S.SummonDemonicTyrant:CastTime() or SoulShards < 2)) then
    local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
  end
  -- potion,if=variable.imp_despawn&variable.imp_despawn<time+gcd.max*2+action.summon_demonic_tyrant.cast_time&(prev_gcd.1.hand_of_guldan|prev_gcd.1.ruination)&(variable.imp_despawn&variable.imp_despawn<time+gcd.max+action.summon_demonic_tyrant.cast_time|soul_shard<2)
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (VarImpDespawn and VarImpDespawn < CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and (Player:PrevGCDP(1, S.HandofGuldan) or Player:PrevGCDP(1, S.RuinationAbility)) and (VarImpDespawn and VarImpDespawn < CombatTime + Player:GCD() + S.SummonDemonicTyrant:CastTime() or SoulShards < 2)) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion tyrant 2"; end
    end
  end
  -- power_siphon,if=cooldown.summon_demonic_tyrant.remains<15
  if S.PowerSiphon:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() < 15) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 4"; end
  end
  -- ruination,if=buff.dreadstalkers.remains>gcd.max+action.summon_demonic_tyrant.cast_time&(soul_shard=5|variable.imp_despawn)
  if S.RuinationAbility:IsReady() and (DreadstalkerTime() > Player:GCD() + S.SummonDemonicTyrant:CastTime() and (SoulShards == 5 or VarImpDespawn)) then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination tyrant 6"; end
  end
  -- infernal_bolt,if=!buff.demonic_core.react&variable.imp_despawn>time+gcd.max*2+action.summon_demonic_tyrant.cast_time&soul_shard<3
  if S.InfernalBolt:IsCastable() and (Player:BuffDown(S.DemonicCoreBuff) and VarImpDespawn > CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and SoulShards < 3) then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt tyrant 8"; end
  end
  if S.ShadowBolt:IsCastable() and (
  -- shadow_bolt,if=prev_gcd.1.call_dreadstalkers&soul_shard<4&buff.demonic_core.react<4
  (Player:PrevGCDP(1, S.CallDreadstalkers) and SoulShards < 4 and DemonicCoreStacks < 4) or
  -- shadow_bolt,if=prev_gcd.2.call_dreadstalkers&prev_gcd.1.shadow_bolt&buff.bloodlust.up&soul_shard<5
  (Player:PrevGCDP(2, S.CallDreadstalkers) and Player:PrevGCDP(1, S.ShadowBolt) and Player:BloodlustUp() and SoulShards < 5) or
  -- shadow_bolt,if=prev_gcd.1.summon_vilefiend&(buff.demonic_calling.down|prev_gcd.2.grimoire_felguard)
  (Player:PrevGCDP(1, VilefiendAbility) and (Player:BuffDown(S.DemonicCallingBuff) or Player:PrevGCDP(2, S.GrimoireFelguard))) or
  -- shadow_bolt,if=prev_gcd.1.grimoire_felguard&buff.demonic_core.react<3&buff.demonic_calling.remains>gcd.max*3
  (Player:PrevGCDP(1, S.GrimoireFelguard) and DemonicCoreStacks < 3 and Player:BuffRemains(S.DemonicCallingBuff) > Player:GCD() * 3)
  ) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 10"; end
  end
  -- hand_of_guldan,if=variable.imp_despawn>time+gcd.max*2+action.summon_demonic_tyrant.cast_time&!buff.demonic_core.react&buff.demonic_art_pit_lord.up&variable.imp_despawn<time+gcd.max*5+action.summon_demonic_tyrant.cast_time
  if S.HandofGuldan:IsReady() and (VarImpDespawn > CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and Player:BuffDown(S.DemonicCoreBuff) and Player:BuffUp(S.DemonicArtPitLordBuff) and VarImpDespawn < CombatTime + Player:GCD() * 5 + S.SummonDemonicTyrant:CastTime()) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 12"; end
  end
  -- hand_of_guldan,if=variable.imp_despawn>time+gcd.max+action.summon_demonic_tyrant.cast_time&variable.imp_despawn<time+gcd.max*2+action.summon_demonic_tyrant.cast_time&buff.dreadstalkers.remains>gcd.max+action.summon_demonic_tyrant.cast_time&soul_shard>1
  if S.HandofGuldan:IsReady() and (VarImpDespawn > CombatTime + Player:GCD() + S.SummonDemonicTyrant:CastTime() and VarImpDespawn < CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and DreadstalkerTime() > Player:GCD() + S.SummonDemonicTyrant:CastTime() and SoulShards > 1) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 14"; end
  end
  -- shadow_bolt,if=!buff.demonic_core.react&variable.imp_despawn>time+gcd.max*2+action.summon_demonic_tyrant.cast_time&variable.imp_despawn<time+gcd.max*4+action.summon_demonic_tyrant.cast_time&soul_shard<3&buff.dreadstalkers.remains>gcd.max*2+action.summon_demonic_tyrant.cast_time
  if S.ShadowBolt:IsCastable() and (Player:BuffDown(S.DemonicCoreBuff) and VarImpDespawn > CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() and VarImpDespawn < CombatTime + Player:GCD() * 4 + S.SummonDemonicTyrant:CastTime() and SoulShards < 3 and DreadstalkerTime() > Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime()) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 16"; end
  end
  -- grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains<13+gcd.max&cooldown.summon_vilefiend.remains<gcd.max&cooldown.call_dreadstalkers.remains<gcd.max*3.33&(soul_shard=5-(pet.felguard.cooldown.soul_strike.remains<gcd.max)&talent.fel_invocation|soul_shard=5)
  if CDsON() and S.GrimoireFelguard:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() < 13 + Player:GCD() and VilefiendAbility:CooldownRemains() < Player:GCD() and S.CallDreadstalkers:CooldownRemains() < Player:GCD() * 3.33 and (SoulShards == 5 - num(S.SoulStrikePetAbility:CooldownRemains() < Player:GCD()) and S.FelInvocation:IsAvailable() or SoulShards == 5)) then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant 18"; end
  end
  -- summon_vilefiend,if=(buff.grimoire_felguard.up|cooldown.grimoire_felguard.remains>10|!talent.grimoire_felguard)&cooldown.summon_demonic_tyrant.remains<13&cooldown.call_dreadstalkers.remains<gcd.max*2.33&(soul_shard=5|soul_shard=4&(buff.demonic_core.react=4)|buff.grimoire_felguard.up)
  if VilefiendAbility:IsReady() and ((GrimoireFelguardActive() or S.GrimoireFelguard:CooldownRemains() > 10 or not S.GrimoireFelguard:IsAvailable()) and S.SummonDemonicTyrant:CooldownRemains() < 13 and S.CallDreadstalkers:CooldownRemains() < Player:GCD() * 2.33 and (SoulShards == 5 or SoulShards == 4 and (DemonicCoreStacks == 4) or GrimoireFelguardActive())) then
    if Cast(VilefiendAbility) then return "summon_vilefiend tyrant 20"; end
  end
  -- call_dreadstalkers,if=(!talent.summon_vilefiend|buff.vilefiend.up)&cooldown.summon_demonic_tyrant.remains<10&soul_shard>=(5-(buff.demonic_core.react>=3))|prev_gcd.3.grimoire_felguard
  if S.CallDreadstalkers:IsReady() and ((not S.SummonVilefiend:IsAvailable() or VilefiendActive()) and S.SummonDemonicTyrant:CooldownRemains() < 10 and SoulShards >= (5 - num(DemonicCoreStacks >= 3)) or Player:PrevGCDP(3, S.GrimoireFelguard)) then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant 22"; end
  end
  -- summon_demonic_tyrant,if=variable.imp_despawn&variable.imp_despawn<time+gcd.max*2+cast_time|buff.dreadstalkers.up&buff.dreadstalkers.remains<gcd.max*2+cast_time
  if S.SummonDemonicTyrant:IsReady() and (VarImpDespawn and VarImpDespawn < CombatTime + Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime() or DreadstalkerActive() and DreadstalkerTime() < Player:GCD() * 2 + S.SummonDemonicTyrant:CastTime()) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant 24"; end
  end
  -- hand_of_guldan,if=(variable.imp_despawn|buff.dreadstalkers.remains)&soul_shard>=3|soul_shard=5
  if S.HandofGuldan:IsReady() and ((VarImpDespawn or DreadstalkerActive()) and SoulShards >= 3 or SoulShards == 5) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 26"; end
  end
  -- infernal_bolt,if=variable.imp_despawn&soul_shard<3
  if S.InfernalBolt:IsCastable() and (VarImpDespawn and SoulShards < 3) then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt tyrant 28"; end
  end
  -- demonbolt,if=variable.imp_despawn&buff.demonic_core.react&soul_shard<4|prev_gcd.1.call_dreadstalkers&soul_shard<4&buff.demonic_core.react=4|buff.demonic_core.react=4&soul_shard<4|buff.demonic_core.react>=2&cooldown.power_siphon.remains<5
  if S.Demonbolt:IsReady() and (VarImpDespawn and Player:BuffUp(S.DemonicCoreBuff) and SoulShards < 4 or Player:PrevGCDP(1, S.CallDreadstalkers) and SoulShards < 4 and DemonicCoreStacks == 4 or DemonicCoreStacks == 4 and SoulShards < 4 or DemonicCoreStacks >= 2 and S.PowerSiphon:CooldownRemains() < 5) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt tyrant 30"; end
  end
  -- ruination,if=variable.imp_despawn|soul_shard=5&cooldown.summon_vilefiend.remains>gcd.max*3
  if S.RuinationAbility:IsReady() and (VarImpDespawn or SoulShards == 5 and VilefiendAbility:CooldownRemains() > Player:GCD() * 3) then
    if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination tyrant 32"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 34"; end
  end
  -- infernal_bolt
  if S.InfernalBolt:IsCastable() then
    if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt tyrant 36"; end
  end
end

local function Variables()
  -- variable,name=next_tyrant_cd,op=set,value=cooldown.summon_demonic_tyrant.remains_expected
  VarNextTyrantCD = S.SummonDemonicTyrant:CooldownRemains()
  -- variable,name=in_opener,op=set,value=0,if=pet.demonic_tyrant.active
  if VarInOpener and DemonicTyrantActive() then
    VarInOpener = false
  end
  -- variable,name=imp_despawn,op=set,value=2*spell_haste*6+0.58+time,if=prev_gcd.1.hand_of_guldan&buff.dreadstalkers.up&cooldown.summon_demonic_tyrant.remains<13&variable.imp_despawn=0
  if Player:PrevGCDP(1, S.HandofGuldan) and DreadstalkerActive() and S.SummonDemonicTyrant:CooldownRemains() < 13 and VarImpDespawn == 0 then
    VarImpDespawn = 2 * Player:SpellHaste() * 6 + 0.58 + CombatTime
  end
  -- variable,name=imp_despawn,op=set,value=(variable.imp_despawn>?buff.dreadstalkers.remains+time),if=variable.imp_despawn
  if VarImpDespawn > 0 then
    VarImpDespawn = mathmin(VarImpDespawn, DreadstalkerTime() + CombatTime)
  end
  -- variable,name=imp_despawn,op=set,value=variable.imp_despawn>?buff.grimoire_felguard.remains+time,if=variable.imp_despawn&buff.grimoire_felguard.up
  if VarImpDespawn > 0 and GrimoireFelguardActive() then
    VarImpDespawn = mathmin(VarImpDespawn, GrimoireFelguardTime() + CombatTime)
  end
  -- variable,name=imp_despawn,op=set,value=0,if=buff.tyrant.up
  if DemonicTyrantActive() then
    VarImpDespawn = 0
  end
  -- variable,name=impl,op=set,value=buff.tyrant.down,if=active_enemies>1+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 1 + num(S.SacrificedSouls:IsAvailable()) then
    VarImpl = not DemonicTyrantActive()
  end
  -- variable,name=impl,op=set,value=buff.tyrant.remains<6,if=active_enemies>2+(talent.sacrificed_souls.enabled)&active_enemies<5+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 2 + num(S.SacrificedSouls:IsAvailable()) and EnemiesCount8ySplash < 5 + num(S.SacrificedSouls:IsAvailable()) then
    VarImpl = DemonicTyrantTime() < 6
  end
  -- variable,name=impl,op=set,value=buff.tyrant.remains<8,if=active_enemies>4+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 4 + num(S.SacrificedSouls:IsAvailable()) then
    VarImpl = DemonicTyrantTime() < 8
  end
  -- variable,name=pool_cores_for_tyrant,op=set,value=cooldown.summon_demonic_tyrant.remains<20&variable.next_tyrant_cd<20&(buff.demonic_core.stack<=2|!buff.demonic_core.up)&cooldown.summon_vilefiend.remains<gcd.max*8&cooldown.call_dreadstalkers.remains<gcd.max*8
  VarPoolCoresForTyrant = S.SummonDemonicTyrant:CooldownRemains() < 20 and VarNextTyrantCD < 20 and (DemonicCoreStacks <= 2 or Player:BuffDown(S.DemonicCoreBuff)) and VilefiendAbility:CooldownRemains() < Player:GCD() * 8 and S.CallDreadstalkers:CooldownRemains() < Player:GCD() * 8
  -- variable,name=diabolic_ritual_remains,value=buff.diabolic_ritual_mother_of_chaos.remains,if=buff.diabolic_ritual_mother_of_chaos.up
  if Player:BuffUp(S.DiabolicRitualMotherBuff) then
    VarDiabolicRitualRemains = Player:BuffRemains(S.DiabolicRitualMotherBuff)
  end
  -- variable,name=diabolic_ritual_remains,value=buff.diabolic_ritual_overlord.remains,if=buff.diabolic_ritual_overlord.up
  if Player:BuffUp(S.DiabolicRitualOverlordBuff) then
    VarDiabolicRitualRemains = Player:BuffRemains(S.DiabolicRitualOverlordBuff)
  end
  -- variable,name=diabolic_ritual_remains,value=buff.diabolic_ritual_pit_lord.remains,if=buff.diabolic_ritual_pit_lord.up
  if Player:BuffUp(S.DiabolicRitualPitLordBuff) then
    VarDiabolicRitualRemains = Player:BuffRemains(S.DiabolicRitualPitLordBuff)
  end
end

--- ===== APL Main =====
local function APL()
  -- Update Enemy Counts
  if AoEON() then
    Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    Enemies40y = Player:GetEnemiesInRange(40)
  else
    Enemies8ySplash = {}
    EnemiesCount8ySplash = 1
    Enemies40y = {}
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Update Demonology-specific Tables
    Warlock.UpdatePetTable()

    -- Update CombatTime, which is used in many spell suggestions
    CombatTime = HL.CombatTime()

    -- Calculate Soul Shards
    SoulShards = Player:SoulShardsP()

    -- Calculate Demonic Core Stacks
    DemonicCoreStacks = Player:BuffStack(S.DemonicCoreBuff)

    -- Safety for nil VilefiendAbility
    if not VilefiendAbility then
      VilefiendAbility = S.MarkofFharg:IsAvailable() and S.SummonCharhound or (S.MarkofShatug:IsAvailable() and S.SummonGloomhound or S.SummonVilefiend)
    end
  end

  -- summon_pet
  if S.SummonPet:IsCastable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if HR.CastAnnotated(S.SummonPet, Settings.Demonology.GCDasOffGCD.SummonPet, "NO PET", nil, Settings.Demonology.SummonPetFontSize) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() and not (Player:IsCasting(S.Demonbolt) or Player:IsCasting(S.ShadowBolt)) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.AxeToss, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: unending_resolve
    if S.UnendingResolve:IsReady() and (Player:HealthPercentage() < Settings.Demonology.UnendingResolveHP) then
      if Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return "unending_resolve defensive"; end
    end
    -- call_action_list,name=variables
    Variables()
    -- potion,if=buff.tyrant.remains>10
    if Settings.Commons.Enabled.Potions and DemonicTyrantTime() > 10 then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- call_action_list,name=racials,if=pet.demonic_tyrant.active|fight_remains<22,use_off_gcd=1
    if CDsON() and (DemonicTyrantActive() or FightRemains < 22) then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items,use_off_gcd=1
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- invoke_external_buff,name=power_infusion,if=fight_remains<20|pet.demonic_tyrant.active&fight_remains<100|fight_remains<25|(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant&buff.dreadstalkers.up)
    -- Note: Not handling external buffs
    -- call_action_list,name=fight_end,if=fight_remains<30
    if FightRemains < 30 then
      local ShouldReturn = FightEnd(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=opener,if=time<variable.first_tyrant_time
    if CombatTime < VarFirstTyrantTime then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=tyrant,if=cooldown.summon_demonic_tyrant.remains<gcd.max*14
    if S.SummonDemonicTyrant:CooldownRemains() < Player:GCD() * 14 then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- hand_of_guldan,if=time<0.5&(fight_remains%%95>40|fight_remains%%95<15)&(talent.reign_of_tyranny|active_enemies>2)
    if S.HandofGuldan:IsReady() and (CombatTime < 0.5 and (FightRemains % 95 > 40 or FightRemains % 95 < 15) and (S.ReignofTyranny:IsAvailable() or EnemiesCount8ySplash > 2)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 4"; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains>25|variable.next_tyrant_cd>25
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 25 or VarNextTyrantCD > 25) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 6"; end
    end
    -- summon_demonic_tyrant,if=buff.vilefiend.up|buff.grimoire_felguard.up|cooldown.grimoire_felguard.remains>60
    if S.SummonDemonicTyrant:IsReady() and (VilefiendActive() or GrimoireFelguardActive() or S.GrimoireFelguard:CooldownRemains() > 60) then
      if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant main 8"; end
    end
    -- summon_vilefiend,if=cooldown.summon_demonic_tyrant.remains>30
    if VilefiendAbility:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 30) then
      if Cast(VilefiendAbility) then return "summon_vilefiend main 10"; end
    end
    -- demonbolt,target_if=(!debuff.doom.up|!action.demonbolt.in_flight&debuff.doom.remains<=2),if=buff.demonic_core.up&(((!talent.soul_strike|cooldown.soul_strike.remains>gcd.max*2&talent.fel_invocation)&soul_shard<4)|soul_shard<(4-(active_enemies>2)))&!prev_gcd.1.demonbolt&talent.doom&cooldown.summon_demonic_tyrant.remains>15
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and (((not S.SoulStrike:IsAvailable() or S.SoulStrike:CooldownRemains() > Player:GCD() * 2 and S.FelInvocation:IsAvailable()) and SoulShards < 4) or SoulShards < (4 - (num(EnemiesCount8ySplash > 2)))) and not Player:PrevGCDP(1, S.Demonbolt) and S.Doom:IsAvailable() and S.SummonDemonicTyrant:CooldownRemains() > 15) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 12"; end
    end
    -- demonbolt,if=buff.demonic_core.stack>=3&soul_shard<=3&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (DemonicCoreStacks >= 3 and SoulShards <= 3 and not VarPoolCoresForTyrant) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 14"; end
    end
    -- power_siphon,if=buff.demonic_core.stack<3&cooldown.summon_demonic_tyrant.remains>25
    if S.PowerSiphon:IsCastable() and (DemonicCoreStacks < 3 and S.SummonDemonicTyrant:CooldownRemains() > 25) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 16"; end
    end
    -- demonic_strength,if=!(raid_event.adds.in<45-raid_event.add.duration)
    if S.DemonicStrength:IsCastable() then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 18"; end
    end
    -- bilescourge_bombers
    if S.BilescourgeBombers:IsReady() then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 20"; end
    end
    -- guillotine,if=(cooldown.demonic_strength.remains|!talent.demonic_strength)&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>6)
    if S.Guillotine:IsCastable() and (S.DemonicStrength:CooldownDown() or not S.DemonicStrength:IsAvailable()) then
      if Cast(S.Guillotine, Settings.Demonology.GCDasOffGCD.Guillotine, nil, not Target:IsInRange(40)) then return "guillotine main 22"; end
    end
    -- ruination
    if S.RuinationAbility:IsReady() then
      if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination main 24"; end
    end
    -- infernal_bolt,if=soul_shard<3&cooldown.summon_demonic_tyrant.remains>20
    if S.InfernalBolt:IsCastable() and (SoulShards < 3 and S.SummonDemonicTyrant:CooldownRemains() > 20) then
      if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt main 26"; end
    end
    -- implosion,if=two_cast_imps>0&variable.impl&!prev_gcd.1.implosion&!raid_event.adds.exists|two_cast_imps>0&variable.impl&!prev_gcd.1.implosion&raid_event.adds.exists&(active_enemies>3|active_enemies<=3&last_cast_imps>0)
    -- Note: Simplified the logic slightly.
    if S.Implosion:IsReady() and (CheckImpCasts(2) > 0 and VarImpl and not Player:PrevGCDP(1, S.Implosion) and (EnemiesCount8ySplash == 1 or (EnemiesCount8ySplash > 3 or EnemiesCount8ySplash <= 3 and CheckImpCasts(1) > 0))) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 28"; end
    end
    -- Demonbolt,if=variable.diabolic_ritual_remains>gcd.max&variable.diabolic_ritual_remains<gcd.max+gcd.max&buff.demonic_core.up&soul_shard<=3
    if S.Demonbolt:IsReady() and (VarDiabolicRitualRemains > Player:GCD() and VarDiabolicRitualRemains < Player:GCD() * 2 and Player:BuffUp(S.DemonicCoreBuff) and SoulShards <= 3) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 30"; end
    end
    -- shadow_bolt,if=variable.diabolic_ritual_remains>gcd.max&variable.diabolic_ritual_remains<soul_shard.deficit*cast_time+gcd.max&soul_shard<5
    if S.ShadowBolt:IsCastable() and (VarDiabolicRitualRemains > Player:GCD() and VarDiabolicRitualRemains < (5 - SoulShards) * S.ShadowBolt:CastTime() + Player:GCD() and SoulShards < 5) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 32"; end
    end
    -- hand_of_guldan,if=((soul_shard>2&(cooldown.call_dreadstalkers.remains>gcd.max*4|buff.demonic_calling.remains-gcd.max>cooldown.call_dreadstalkers.remains)&cooldown.summon_demonic_tyrant.remains>17)|soul_shard=5|soul_shard=4&talent.fel_invocation)&(active_enemies=1)
    if S.HandofGuldan:IsReady() and (((SoulShards > 2 and (S.CallDreadstalkers:CooldownRemains() > Player:GCD() * 4 or Player:BuffRemains(S.DemonicCallingBuff) - Player:GCD() > S.CallDreadstalkers:CooldownRemains()) and S.SummonDemonicTyrant:CooldownRemains() > 17) or SoulShards == 5 or SoulShards == 4 and S.FelInvocation:IsAvailable()) and (EnemiesCount8ySplash == 1)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 34"; end
    end
    -- hand_of_guldan,if=soul_shard>2&!(active_enemies=1)
    if S.HandofGuldan:IsReady() and (SoulShards > 2 and not (EnemiesCount8ySplash == 1)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 36"; end
    end
    -- demonbolt,target_if=(!debuff.doom.up)|active_enemies<4,if=buff.demonic_core.stack>1&((soul_shard<4&!talent.soul_strike|cooldown.soul_strike.remains>gcd.max*2&talent.fel_invocation)|soul_shard<3)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (DemonicCoreStacks > 1 and ((SoulShards < 4 and not S.SoulStrike:IsAvailable() or S.SoulStrike:CooldownRemains() > Player:GCD() * 2 and S.FelInvocation:IsAvailable()) or SoulShards < 3) and not VarPoolCoresForTyrant) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt2, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 38"; end
    end
    -- demonbolt,if=buff.demonic_core.react&buff.tyrant.up&soul_shard<3-talent.quietus
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and DemonicTyrantActive() and SoulShards < 3 - num(S.Quietus:IsAvailable())) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 40"; end
    end
    -- demonbolt,if=buff.demonic_core.react>1&soul_shard<4-talent.quietus
    if S.Demonbolt:IsReady() and (DemonicCoreStacks > 1 and SoulShards < 4 - num(S.Quietus:IsAvailable())) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 42"; end
    end
    -- demonbolt,target_if=(!debuff.doom.up)|active_enemies<4,if=talent.doom&(debuff.doom.remains>10&buff.demonic_core.up&soul_shard<4-talent.quietus)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (S.Doom:IsAvailable() and not VarPoolCoresForTyrant) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt3, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 44"; end
    end
    -- demonbolt,if=fight_remains<buff.demonic_core.stack*gcd.max
    if S.Demonbolt:IsReady() and (BossFightRemains < DemonicCoreStacks * Player:GCD()) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 46"; end
    end
    -- demonbolt,target_if=(!debuff.doom.up)|active_enemies<4,if=buff.demonic_core.up&(cooldown.power_siphon.remains<4)&(soul_shard<4-talent.quietus)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and (S.PowerSiphon:CooldownRemains() < 4) and (SoulShards < 4 - num(S.Quietus:IsAvailable())) and not VarPoolCoresForTyrant) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt2, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 46"; end
    end
    -- power_siphon,if=!buff.demonic_core.up&cooldown.summon_demonic_tyrant.remains>25
    if S.PowerSiphon:IsCastable() and (Player:BuffDown(S.DemonicCoreBuff) and S.SummonDemonicTyrant:CooldownRemains() > 25) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 48"; end
    end
    -- summon_vilefiend,if=fight_remains<cooldown.summon_demonic_tyrant.remains+5
    if VilefiendAbility:IsReady() and (BossFightRemains < S.SummonDemonicTyrant:CooldownRemains() + 5) then
      if Cast(VilefiendAbility) then return "summon_vilefiend main 50"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 52"; end
    end
    -- infernal_bolt
    if S.InfernalBolt:IsCastable() then
      if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt main 54"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(266, APL, Init)
