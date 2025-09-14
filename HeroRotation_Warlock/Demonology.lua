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
  I.SpymastersWeb:ID(),
  -- Older Items
  I.NeuralSynapseEnhancer:ID(),
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
local VarLastDS = 0
local VarLastHoG = 0
local VarHoGAfterDS = false
local VilefiendAbility = S.MarkofFharg:IsAvailable() and S.SummonCharhound or (S.MarkofShatug:IsAvailable() and S.SummonGloomhound or S.SummonVilefiend)
local SoulShards = 0
local DemonicCoreStacks = 0
local GCDMax = 0
local TWW2_2pc = Player:HasTier("TWW2", 2)
local TWW2_4pc = Player:HasTier("TWW2", 4)
local Enemies40y
local Enemies8ySplash, EnemiesCount8ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinket1BuffDuration, VarTrinket2BuffDuration
local VarTrinket1Sync, VarTrinket2Sync
local VarDamageTrinketPriority, VarTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

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

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarTrinket1Buffs = Trinket1:HasUseBuff() or VarTrinket1ID == I.FunhouseLens:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() or VarTrinket2ID == I.FunhouseLens:ID()

  VarTrinket1Exclude = VarTrinket1ID == 193757
  VarTrinket2Exclude = VarTrinket2ID == 193757

  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1ID == I.ImperfectAscendancySerum:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.ImperfectAscendancySerum:ID()

  if VarTrinket1ID == I.FunhouseLens:ID() then
    VarTrinket1BuffDuration = 15
  elseif VarTrinket1ID == I.SignetofthePriory:ID() then
    VarTrinket1BuffDuration = 20
  else
    VarTrinket1BuffDuration = Trinket1:BuffDuration()
  end
  if VarTrinket2ID == I.FunhouseLens:ID() then
    VarTrinket2BuffDuration = 15
  elseif VarTrinket2ID == I.SignetofthePriory:ID() then
    VarTrinket2BuffDuration = 20
  else
    VarTrinket2BuffDuration = Trinket2:BuffDuration()
  end

  VarTrinket1Sync = 0.5
  if VarTrinket1Buffs and (VarTrinket1CD % 60 == 0 or 60 % VarTrinket1CD == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if VarTrinket2Buffs and (VarTrinket2CD % 60 == 0 or 60 % VarTrinket2CD == 0) then
    VarTrinket2Sync = 1
  end

  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level > VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end

  -- Note: If BuffDuration is 0, set to 1 to avoid divide by zero errors.
  local T1BuffDur = VarTrinket1BuffDuration > 0 and VarTrinket1BuffDuration or 1
  local T2BuffDur = VarTrinket2BuffDuration > 0 and VarTrinket2BuffDuration or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDur) * (VarTrinket2Sync)) > (((VarTrinket1CD / T1BuffDur) * (VarTrinket1Sync)) * (1 + ((VarTrinket1Level - VarTrinket2Level) / 100))) then
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
  VarLastDS = 0
  VarLastHoG = 0
  VarHoGAfterDS = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  TWW2_2pc = Player:HasTier("TWW2", 2)
  TWW2_4pc = Player:HasTier("TWW2", 4)
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Demonbolt:RegisterInFlight()
  S.HandofGuldan:RegisterInFlight()
  VilefiendAbility = S.MarkofFharg:IsAvailable() and S.SummonCharhound or (S.MarkofShatug:IsAvailable() and S.SummonGloomhound or S.SummonVilefiend)
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.Demonbolt:RegisterInFlight()
S.HandofGuldan:RegisterInFlight()

--- ===== Helper Functions =====
local function DemonicArt()
  return Player:BuffUp(S.DemonicArtPitLordBuff) or Player:BuffUp(S.DemonicArtMotherBuff) or Player:BuffUp(S.DemonicArtOverlordBuff)
end

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

-- Function to check for Greater Dreadstalkers (TWW Set Bonus Spawns)
-- Note: Greater Dreadstalkers are force-spawned by Summon Demonic Tyrant, so force full duration if we're casting SDT.
local function GreaterDreadstalkerTime()
  local TableTime = Warlock.GuardiansTable.GreaterDreadstalkerDuration or 0
  local GDTime = (TWW2_2pc and Player:IsCasting(S.SummonDemonicTyrant)) and 12 or TableTime
  return GDTime
end

local function GreaterDreadstalkerActive()
  return GreaterDreadstalkerTime() > 0
end

-- Function to check for Vilefiend
local function VilefiendTime()
  return Warlock.GuardiansTable.VilefiendDuration or 0
end

local function VilefiendActive()
  return VilefiendTime() > 0
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterDemonbolt(TargetUnit)
  -- target_if=min:debuff.doom.remains
  return TargetUnit:DebuffRemains(S.DoomDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfDemonboltMain(TargetUnit)
  -- if=buff.demonic_core.stack>=3-(talent.doom&debuff.doom.down)*2&soul_shard<=3&talent.doom
  -- Note: Shards and Doom checks handled before CTI.
  return DemonicCoreStacks >= 3 - num(S.Doom:IsAvailable() and TargetUnit:DebuffDown(S.DoomDebuff)) * 2
end

--- ===== CastCycle Functions =====
local function EvaluateCycleDemonbolt(TargetUnit)
  -- target_if=(!debuff.doom.up)
  return TargetUnit:DebuffDown(S.DoomDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- summon_pet
  -- Moved to APL()
  -- snapshot_stats
  -- variable,name=in_opener,op=set,value=1
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|trinket.1.is.funhouse_lens
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|trinket.2.is.funhouse_lens
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell
  -- variable,name=trinket_1_manual,value=trinket.1.is.spymasters_web|trinket.1.is.imperfect_ascendancy_serum
  -- variable,name=trinket_2_manual,value=trinket.2.is.spymasters_web|trinket.2.is.imperfect_ascendancy_serum
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.funhouse_lens*15)+(trinket.1.is.signet_of_the_priory*20)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.funhouse_lens*15)+(trinket.2.is.signet_of_the_priory*20)
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
  -- Note: This is to avoid suggesting ShadowBolt on a new pack of non-boss mobs when we have Demonic Core buff stacks.
  -- Note: Old method was checking Target:IsInBossList(), but that doesn't populate until after Precombat.
  if S.Demonbolt:IsReady() and Target:Level() ~= -1 and Player:BuffUp(S.DemonicCoreBuff) then
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

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!pet.demonic_tyrant.active&trinket.1.cast_time>0|!trinket.1.cast_time>0)&(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant|variable.trinket_priority=2&cooldown.summon_demonic_tyrant.remains>20&!pet.demonic_tyrant.active&trinket.2.cooldown.remains<cooldown.summon_demonic_tyrant.remains+5)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1&!variable.trinket_2_manual)|variable.trinket_1_buff_duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and not VarTrinket1Manual and (not DemonicTyrantActive() and VarTrinket1CastTime > 0 or not (VarTrinket1CastTime > 0)) and (DemonicTyrantActive() or not S.SummonDemonicTyrant:IsAvailable() or VarTrinketPriority == 2 and S.SummonDemonicTyrant:CooldownRemains() > 20 and not DemonicTyrantActive() and Trinket2:CooldownRemains() < S.SummonDemonicTyrant:CooldownRemains() + 5) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1 and not VarTrinket2Manual) or VarTrinket1BuffDuration >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 2"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!pet.demonic_tyrant.active&trinket.2.cast_time>0|!trinket.2.cast_time>0)&(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant|variable.trinket_priority=1&cooldown.summon_demonic_tyrant.remains>20&!pet.demonic_tyrant.active&trinket.1.cooldown.remains<cooldown.summon_demonic_tyrant.remains+5)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2&!variable.trinket_1_manual)|variable.trinket_2_buff_duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and not VarTrinket2Manual and (not DemonicTyrantActive() and VarTrinket2CastTime > 0 or not (VarTrinket2CastTime > 0)) and (DemonicTyrantActive() or not S.SummonDemonicTyrant:IsAvailable() or VarTrinketPriority == 1 and S.SummonDemonicTyrant:CooldownRemains() > 20 and not DemonicTyrantActive() and Trinket1:CooldownRemains() < S.SummonDemonicTyrant:CooldownRemains() + 5) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2 and not VarTrinket1Manual) or VarTrinket2BuffDuration >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 4"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&((variable.damage_trinket_priority=1|trinket.2.cooldown.remains)&(trinket.1.cast_time>0&!pet.demonic_tyrant.active|!trinket.1.cast_time>0)|(time<20&variable.trinket_2_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and not VarTrinket1Manual and ((VarDamageTrinketPriority == 1 or Trinket2:CooldownDown()) and (VarTrinket1CastTime > 0 and not DemonicTyrantActive() or not (VarTrinket1CastTime > 0)) or (HL.CombatTime() < 20 and VarTrinket2Buffs) or S.SummonDemonicTyrant:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&((variable.damage_trinket_priority=2|trinket.1.cooldown.remains)&(trinket.2.cast_time>0&!pet.demonic_tyrant.active|!trinket.2.cast_time>0)|(time<20&variable.trinket_1_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and not VarTrinket2Manual and ((VarDamageTrinketPriority == 2 or Trinket1:CooldownDown()) and (VarTrinket2CastTime > 0 and not DemonicTyrantActive() or not (VarTrinket2CastTime > 0)) or (HL.CombatTime() < 20 and VarTrinket1Buffs) or S.SummonDemonicTyrant:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 8"; end
    end
    -- use_item,use_off_gcd=1,name=spymasters_web,if=pet.demonic_tyrant.active&fight_remains<=80&buff.spymasters_report.stack>=30&(!variable.trinket_1_buffs&trinket.2.is.spymasters_web|!variable.trinket_2_buffs&trinket.1.is.spymasters_web)|fight_remains<=20&(trinket.1.cooldown.remains&trinket.2.is.spymasters_web|trinket.2.cooldown.remains&trinket.1.is.spymasters_web|!variable.trinket_1_buffs|!variable.trinket_2_buffs)
    if I.SpymastersWeb:IsEquippedAndReady() and (DemonicTyrantActive() and BossFightRemains <= 80 and Player:BuffStack(S.SpymastersReportBuff) >= 30 and (not VarTrinket1Buffs and VarTrinket2ID == I.SpymastersWeb:ID() or not VarTrinket2Buffs and VarTrinket1ID == I.SpymastersWeb:ID()) or BossFightRemains <= 20 and (Trinket1:CooldownDown() and VarTrinket2ID == I.SpymastersWeb:ID() or Trinket2:CooldownDown() and VarTrinket1ID == I.SpymastersWeb:ID() or not VarTrinket1Buffs or not VarTrinket2Buffs)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web items 10"; end
    end
    -- use_item,use_off_gcd=1,name=imperfect_ascendancy_serum,if=pet.demonic_tyrant.active|fight_remains<=30
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (DemonicTyrantActive() or BossFightRemains <= 30) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum items 12"; end
    end
    -- use_item,name=mirror_of_fractured_tomorrows,if=trinket.1.is.mirror_of_fractured_tomorrows&variable.trinket_priority=2|trinket.2.is.mirror_of_fractured_tomorrows&variable.trinket_priority=1
    if I.MirrorofFracturedTomorrows:IsEquippedAndReady() and (VarTrinket1ID == I.MirrorofFracturedTomorrows:ID() and VarTrinketPriority == 2 or VarTrinket2ID == I.MirrorofFracturedTomorrows:ID() and VarTrinketPriority == 1) then
      if Cast(I.MirrorofFracturedTomorrows, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows items 16"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 18"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 20"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,use_off_gcd=1,slot=main_hand,name=!neural_synapse_enhancer
    -- Note: neural_synapse_enhancer is excluded via OnUseExcludes, so won't be included in the below.
    local MainHandToUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandToUse then
      if Cast(MainHandToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "use_item main_hand items 14"; end
    end
    if I.NeuralSynapseEnhancer:IsEquippedAndReady() and (
      -- use_item,use_off_gcd=1,slot=main_hand,name=neural_synapse_enhancer,if=(pet.demonic_tyrant.active|fight_remains<=15)&!variable.trinket_1_buffs&!variable.trinket_2_buffs
      ((DemonicTyrantActive() or BossFightRemains <= 15) and not VarTrinket1Buffs and not VarTrinket2Buffs) or
      -- use_item,use_off_gcd=1,slot=main_hand,name=neural_synapse_enhancer,if=(pet.demonic_tyrant.active|fight_remains<=15|trinket.2.cooldown.remains>cooldown.summon_demonic_tyrant.remains)&variable.trinket_2_buffs
      ((DemonicTyrantActive() or BossFightRemains <= 15 or Trinket2:CooldownRemains() > S.SummonDemonicTyrant:CooldownRemains()) and VarTrinket2Buffs) or
      -- use_item,use_off_gcd=1,slot=main_hand,name=neural_synapse_enhancer,if=(pet.demonic_tyrant.active|fight_remains<=15|trinket.1.cooldown.remains>cooldown.summon_demonic_tyrant.remains)&variable.trinket_1_buffs
      ((DemonicTyrantActive() or BossFightRemains <= 15 or Trinket1:CooldownRemains() > S.SummonDemonicTyrant:CooldownRemains()) and VarTrinket1Buffs)
    ) then
      if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Items) then return "neural_synapse_enhancer main_hand items 16"; end
    end
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

local function Variables()
  -- variable,name=next_tyrant_cd,op=set,value=cooldown.summon_demonic_tyrant.remains_expected
  VarNextTyrantCD = S.SummonDemonicTyrant:CooldownRemains()
  -- variable,name=in_opener,op=set,value=0,if=pet.demonic_tyrant.active
  if VarInOpener and DemonicTyrantActive() then
    VarInOpener = false
  end
  -- variable,name=imp_despawn,op=set,value=2*spell_haste*6+0.58+time,if=prev_gcd.1.hand_of_guldan&buff.dreadstalkers.up&cooldown.summon_demonic_tyrant.remains<13&variable.imp_despawn=0
  -- Note: Removed 'time' from the calculation.
  if Player:PrevGCDP(1, S.HandofGuldan) and DreadstalkerActive() and S.SummonDemonicTyrant:CooldownRemains() < 13 and VarImpDespawn == 0 then
    VarImpDespawn = 2 * Player:SpellHaste() * 6 + 0.58
  end
  -- variable,name=imp_despawn,op=set,value=buff.dreadstalkers.remains+time,if=prev_gcd.1.hand_of_guldan&buff.dreadstalkers.up&cooldown.summon_demonic_tyrant.remains<13&variable.imp_despawn=0
  if Player:PrevGCDP(1, S.HandofGuldan) and DreadstalkerActive() and S.SummonDemonicTyrant:CooldownRemains() < 13 and VarImpDespawn == 0 then
    VarImpDespawn = DreadstalkerTime()
  end
  -- variable,name=imp_despawn,op=set,value=(variable.imp_despawn>?buff.dreadstalkers.remains+time),if=variable.imp_despawn
  -- Note: Removed 'time' from the calculation, as it needlessly complicates its usage.
  if VarImpDespawn > 0 then
    VarImpDespawn = mathmin(VarImpDespawn, DreadstalkerTime())
  end
  -- variable,name=imp_despawn,op=set,value=variable.imp_despawn>?buff.vilefiend.remains+time,if=variable.imp_despawn&buff.vilefiend.up
  -- Note: Removed 'time' from the calculation, as it needlessly complicates its usage.
  if VarImpDespawn > 0 and VilefiendActive() then
    VarImpDespawn = mathmin(VarImpDespawn, VilefiendTime())
  end
  -- variable,name=imp_despawn,op=set,value=variable.imp_despawn>?buff.grimoire_felguard.remains+time,if=variable.imp_despawn&buff.grimoire_felguard.up
  -- Note: Removed 'time' from the calculation, as it needlessly complicates its usage.
  if VarImpDespawn > 0 and GrimoireFelguardActive() then
    VarImpDespawn = mathmin(VarImpDespawn, GrimoireFelguardTime())
  end
  -- variable,name=imp_despawn,op=set,value=0,if=buff.tyrant.up
  if DemonicTyrantActive() then
    VarImpDespawn = 0
  end
  -- Note: Reset VarImpl to false before the following checks to ensure it doesn't end up as true in a situation where AoE has whittled down to ST.
  VarImpl = false
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
  -- variable,name=last_ds,default=0,value=time,if=prev_gcd.1.call_dreadstalkers
  VarLastDS = 0
  if Player:PrevGCDP(1, S.CallDreadstalkers) then
    VarLastDS = HL.CombatTime()
  end
  -- variable,name=last_ds,value=0,if=buff.tyrant.up
  if DemonicTyrantActive() then
    VarLastDS = 0
  end
  -- variable,name=last_hog,default=0,value=time,if=prev_gcd.1.hand_of_guldan
  VarLastHoG = 0
  if Player:PrevGCDP(1, S.HandofGuldan) then
    VarLastHoG = HL.CombatTime()
  end
  -- variable,name=last_hog,value=0,if=buff.tyrant.up
  if DemonicTyrantActive() then
    VarLastHoG = 0
  end
  -- variable,name=hog_after_ds,value=variable.last_ds>0&variable.last_hog>0&variable.last_hog>variable.last_ds
  VarHoGAfterDS = VarLastDS > 0 and VarLastHoG > 0 and VarLastHoG > VarLastDS
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
    -- potion,if=pet.demonic_tyrant.active
    if Settings.Commons.Enabled.Potions and DemonicTyrantActive() then
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
    -- invoke_external_buff,name=power_infusion,if=variable.imp_despawn&variable.imp_despawn<time+gcd.max*6+cast_time
    -- Note: Not handling external buffs.
    -- hand_of_guldan,if=soul_shard>=3&cooldown.summon_demonic_tyrant.remains_expected<10&pet.dreadstalker.active
    if S.HandofGuldan:IsReady() and (SoulShards >= 3 and S.SummonDemonicTyrant:CooldownRemains() < 10 and DreadstalkerActive()) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsInRange(40)) then return "hand_of_guldan main 4"; end
    end
    -- summon_demonic_tyrant,if=(variable.imp_despawn&pet.vilefiend.active&pet.dreadstalker.active&(variable.imp_despawn<time+gcd.max+cast_time|buff.wild_imps.stack>=9-2*prev_gcd.1.hand_of_guldan))|(buff.grimoire_felguard.remains>cast_time&buff.grimoire_felguard.remains<action.hand_of_guldan.cast_time+cast_time+gcd.max)|(buff.dreadstalkers.remains>cast_time&((buff.dreadstalkers.remains<action.hand_of_guldan.cast_time+cast_time+gcd.max)|(variable.hog_after_ds&(time>10|buff.wild_imps.stack>=9-2*prev_gcd.1.hand_of_guldan))))
    -- Note: Simc stores imp_despawn as an absolute time. We store as relative, so we don't need to add 'time'.
    if S.SummonDemonicTyrant:IsReady() and ((VarImpDespawn > 0 and VilefiendActive() and DreadstalkerActive() and (VarImpDespawn < Player:GCD() + S.SummonDemonicTyrant:CastTime() or WildImpsCount() >= 9 - 2 * num(Player:PrevGCDP(1, S.HandofGuldan)))) or (GrimoireFelguardTime() > S.SummonDemonicTyrant:CastTime() and GrimoireFelguardTime() < S.HandofGuldan:CastTime() + S.SummonDemonicTyrant:CastTime() + Player:GCD()) or (DreadstalkerTime() > S.SummonDemonicTyrant:CastTime() and ((DreadstalkerTime() < S.HandofGuldan:CastTime() + S.SummonDemonicTyrant:CastTime() + Player:GCD()) or (VarHoGAfterDS and (HL.CombatTime() > 10 or WildImpsCount() >= 9 - 2 * num(Player:PrevGCDP(1, S.HandofGuldan))))))) then
      if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant main 6"; end
    end
    -- grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains<=15&cooldown.call_dreadstalkers.remains<10
    if S.GrimoireFelguard:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() <= 15 and S.CallDreadstalkers:CooldownRemains() < 10) then
      if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard) then return "grimoire_felguard main 8"; end
    end
    -- summon_vilefiend,if=cooldown.summon_demonic_tyrant.remains>=25+cast_time&(!pet.vilefiend.active&talent.the_houndmasters_gambit|!talent.the_houndmasters_gambit)|cooldown.summon_demonic_tyrant.remains<=13&cooldown.call_dreadstalkers.remains<10
    if VilefiendAbility:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() >= 25 + VilefiendAbility:CastTime() and (not VilefiendActive() and S.TheHoundmastersGambit:IsAvailable() or not S.TheHoundmastersGambit:IsAvailable()) or S.SummonDemonicTyrant:CooldownRemains() <= 13 and S.CallDreadstalkers:CooldownRemains() < 10) then
      if Cast(VilefiendAbility, Settings.Demonology.GCDasOffGCD.SummonVilefiend) then return "summon_vilefiend main 10"; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains>=10|cooldown.summon_demonic_tyrant.remains<=10
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() >= 10 or S.SummonDemonicTyrant:CooldownRemains() <= 10) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 12"; end
    end
    if S.CallDreadstalkers:IsReady() and (
      -- call_dreadstalkers,if=buff.grimoire_felguard.up&buff.grimoire_felguard.remains<12+gcd.max+cast_time
      (GrimoireFelguardActive() and GrimoireFelguardTime() < 12 + Player:GCD() + S.CallDreadstalkers:CastTime()) or
      -- call_dreadstalkers,if=buff.vilefiend.up&buff.vilefiend.remains<12+gcd.max+cast_time
      (VilefiendActive() and VilefiendTime() < 12 + Player:GCD() + S.CallDreadstalkers:CastTime()) or
      -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains>cooldown+gcd.max+action.summon_demonic_tyrant.cast_time
      (S.SummonDemonicTyrant:CooldownRemains() > 20 + Player:GCD() + S.SummonDemonicTyrant:CastTime()) or
      -- call_dreadstalkers,if=(!talent.grimoire_felguard|buff.grimoire_felguard.down&cooldown.grimoire_felguard.remains>cooldown-gcd.max-cast_time-action.summon_demonic_tyrant.cast_time)&(!talent.summon_vilefiend|buff.vilefiend.down>cooldown-gcd.max-cast_time-action.summon_demonic_tyrant.cast_time)
      ((not S.GrimoireFelguard:IsAvailable() or not GrimoireFelguardActive() and S.GrimoireFelguard:CooldownRemains() > 20 - Player:GCD() - S.CallDreadstalkers:CastTime() - S.SummonDemonicTyrant:CastTime()) and (not S.SummonVilefiend:IsAvailable() or not VilefiendActive() and VilefiendAbility:CooldownRemains() > 20 - Player:GCD() - S.CallDreadstalkers:CastTime() - S.SummonDemonicTyrant:CastTime()))
    ) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 14"; end
    end
    -- demonbolt,target_if=min:debuff.doom.remains,if=buff.demonic_core.stack>=3-(talent.doom&debuff.doom.down)*2&soul_shard<=3&talent.doom
    if S.Demonbolt:IsReady() and (SoulShards <= 3 and S.Doom:IsAvailable()) then
      if Everyone.CastTargetIf(S.Demonbolt, Enemies8ySplash, "min", EvaluateTargetIfFilterDemonbolt, EvaluateTargetIfDemonboltMain, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 16"; end
    end
    -- demonic_strength,if=pet.demonic_tyrant.active
    if S.DemonicStrength:IsCastable() and (DemonicTyrantActive()) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 18"; end
    end
    -- bilescourge_bombers,if=active_enemies>1
    if S.BilescourgeBombers:IsReady() and (EnemiesCount8ySplash > 1) then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 20"; end
    end
    -- hand_of_guldan,if=demonic_art&soul_shard>=3
    if S.HandofGuldan:IsReady() and (DemonicArt() and SoulShards >= 3) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsInRange(40)) then return "hand_of_guldan main 22"; end
    end
    -- implosion,if=(cooldown.summon_demonic_tyrant.remains_expected>10)&(active_enemies>3&set_bonus.tww2_4pc&buff.wild_imps.stack>7&!buff.demonic_core.react&!prev_gcd.1.implosion|!set_bonus.tww2_4pc&active_enemies>2&two_cast_imps>2&!prev_gcd.1.implosion&variable.impl)
    if S.Implosion:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 10 and (EnemiesCount8ySplash > 3 and TWW2_4pc and WildImpsCount() > 7 and Player:BuffDown(S.DemonicCoreBuff) and not Player:PrevGCDP(1, S.Implosion) or not TWW2_4pc and EnemiesCount8ySplash > 2 and CheckImpCasts(2) > 2 and not Player:PrevGCDP(1, S.Implosion) and VarImpl)) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 24"; end
    end
    -- ruination
    if S.RuinationAbility:IsReady() then
      if Cast(S.RuinationAbility, nil, nil, not Target:IsSpellInRange(S.RuinationAbility)) then return "ruination main 26"; end
    end
    -- demonbolt,target_if=(!debuff.doom.up),if=soul_shard<4&buff.demonic_core.stack>=3&talent.doom
    if S.Demonbolt:IsReady() and (SoulShards < 4 and DemonicCoreStacks >= 3 and S.Doom:IsAvailable()) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 28"; end
    end
    -- demonbolt,if=soul_shard<4&buff.demonic_core.stack>=3&!talent.doom
    if S.Demonbolt:IsReady() and (SoulShards < 4 and DemonicCoreStacks >= 3 and not S.Doom:IsAvailable()) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 30"; end
    end
    -- power_siphon,if=!buff.demonic_core.up
    if S.PowerSiphon:IsReady() and (Player:BuffDown(S.DemonicCoreBuff)) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 32"; end
    end
    -- infernal_bolt,if=soul_shard<3
    if S.InfernalBolt:IsCastable() and (SoulShards < 3) then
      if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt main 34"; end
    end
    -- hand_of_guldan,if=soul_shard>=3
    if S.HandofGuldan:IsReady() and (SoulShards >= 3) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsInRange(40)) then return "hand_of_guldan main 36"; end
    end
    -- demonbolt,if=soul_shard<4&buff.demonic_core.react
    if S.Demonbolt:IsReady() and (SoulShards < 4 and Player:BuffUp(S.DemonicCoreBuff)) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 38"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 40"; end
    end
    -- infernal_bolt
    if S.InfernalBolt:IsCastable() then
      if Cast(S.InfernalBolt, nil, nil, not Target:IsSpellInRange(S.InfernalBolt)) then return "infernal_bolt main 42"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(266, APL, Init)
