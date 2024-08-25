--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC         = HeroDBC.DBC
-- HeroLib
local HL          = HeroLib
local Cache       = HeroCache
local Unit        = HL.Unit
local Player      = Unit.Player
local Pet         = Unit.Pet
local Target      = Unit.Target
local Spell       = HL.Spell
local MultiSpell  = HL.MultiSpell
local Item        = HL.Item
-- HeroRotation
local HR          = HeroRotation
local AoEON       = HR.AoEON
local CDsON       = HR.CDsON
local Cast        = HR.Cast
local CastPooling = HR.CastPooling
-- Num/Bool Helper Functions
local num         = HR.Commons.Everyone.num
local bool        = HR.Commons.Everyone.bool
-- lua
local mathfloor   = math.floor
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- Define S/I for spell and item arrays
local S = Spell.Druid.Feral
local I = Item.Druid.Feral

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {--  I.TrinketName:ID(),
  I.AlgetharPuzzleBox:ID(),
  I.AshesoftheEmbersoul:ID(),
  I.BandolierofTwistedBlades:ID(),
  I.IrideusFragment:ID(),
  I.ManicGrieftorch:ID(),
  I.MirrorofFracturedTomorrows:ID(),
  I.MydasTalisman:ID(),
  I.WitherbarksBranch:ID(),
  I.VerdantBadge:ID(),
}

--- ===== GUI Settings =====
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  CommonsDS = HR.GUISettings.APL.Druid.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Druid.CommonsOGCD,
  Feral = HR.GUISettings.APL.Druid.Feral
}

--- ===== Rotation Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Duration, VarTrinket2Duration
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinketPriority
local VarProccingBT
local VarEffectiveEnergy, VarTimeToPool, VarNeedBT
local VarLastConvoke, VarLastZerk, VarLastPotion
local VarZerkBiteweave, VarRegrowth, VarEasySwipe
local ComboPoints, ComboPointsDeficit
local BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
local IsInMeleeRange, IsInAoERange
local BossFightRemains = 11111
local FightRemains = 11111
local EnemiesMelee, EnemiesCountMelee
local Enemies8y, EnemiesCount8y

--- ===== Trinket Variables =====
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

  -- Note: Using value >0 to avoid divide by zero errors.
  VarTrinket1Duration = (Trinket1:BuffDuration() > 0) and Trinket1:BuffDuration() or 1
  VarTrinket2Duration = (Trinket2:BuffDuration() > 0) and Trinket2:BuffDuration() or 1

  VarTrinket1Sync = 0.5
  if (S.ConvoketheSpirits:IsAvailable() and not S.AshamanesGuidance:IsAvailable() and VarTrinket1Buffs and (VarTrinket1CD % 120 == 0 or 120 % VarTrinket1CD == 0)) or (not (S.ConvoketheSpirits:IsAvailable() and not S.AshamanesGuidance:IsAvailable()) and VarTrinket1Buffs and (VarTrinket1CD % 180 == 0 or 180 % VarTrinket1CD == 0 or VarTrinket1CD % 120 == 0 or 120 % VarTrinket1CD == 0)) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if (S.ConvoketheSpirits:IsAvailable() and not S.AshamanesGuidance:IsAvailable() and VarTrinket2Buffs and (VarTrinket2CD % 120 == 0 or 120 % VarTrinket2CD == 0)) or (not (S.ConvoketheSpirits:IsAvailable() and not S.AshamanesGuidance:IsAvailable()) and VarTrinket2Buffs and (VarTrinket2CD % 180 == 0 or 180 % VarTrinket2CD == 0 or VarTrinket2CD % 120 == 0 or 120 % VarTrinket2CD == 0)) then
    VarTrinket2Sync = 1
  end

  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / VarTrinket2Duration) * (VarTrinket2Sync)) > ((VarTrinket1CD / VarTrinket1Duration) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local InterruptStuns = {
  { S.MightyBash, "Cast Mighty Bash (Interrupt)", function () return true; end },
}

--- ===== Event Registration =====
HL:RegisterForEvent(function()
  BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AdaptiveSwarm:RegisterInFlightEffect(391889)
  S.AdaptiveSwarm:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.AdaptiveSwarm:RegisterInFlightEffect(391889)
S.AdaptiveSwarm:RegisterInFlight()

--- ===== PMultiplier Registrations =====
local function ComputeRakePMultiplier()
  return Player:StealthUp(true, true) and 1.6 or 1
end
S.Rake:RegisterPMultiplier(S.RakeDebuff, ComputeRakePMultiplier)


local function ComputeRipPMultiplier()
  local Mult = 1
  Mult = Player:BuffUp(S.BloodtalonsBuff) and Mult * 1.25 or Mult
  Mult = S.DreadfulBleeding:IsAvailable() and Mult * 1.2 or Mult
  Mult = Player:HasTier("TWW1", 4) and Mult * 1.08 or Mult
  Mult = S.LionsStrength:IsAvailable() and Mult * 1.15 or Mult
  Mult = Player:BuffUp(S.TigersFury) and Mult * 1.15 or Mult
  return Mult
end
S.Rip:RegisterPMultiplier(S.RipDebuff, ComputeRipPMultiplier)

--- ===== Helper Functions =====
local BtTriggers = {
  S.Rake,
  S.LIMoonfire,
  S.Thrash,
  S.BrutalSlash,
  S.Swipe,
  S.Shred,
  S.FeralFrenzy,
}

local function DebuffRefreshAny(Enemies, Spell)
  for _, Enemy in pairs(Enemies) do
    if Enemy:DebuffRefreshable(Spell) then
      return true
    end
  end
  return false
end

local function BTBuffUp(Trigger)
  if not S.Bloodtalons:IsAvailable() then return false end
  return Trigger:TimeSinceLastCast() < math.min(5, S.BloodtalonsBuff:TimeSinceLastAppliedOnPlayer())
end

local function BTBuffDown(Trigger)
  return not BTBuffUp(Trigger)
end

local function CountActiveBtTriggers()
  local ActiveTriggers = 0
  for i = 1, #BtTriggers do
    if BTBuffUp(BtTriggers[i]) then ActiveTriggers = ActiveTriggers + 1 end
  end
  return ActiveTriggers
end

local function TicksGainedOnRefresh(Spell, Tar)
  if not Tar then Tar = Target end
  local AddedDuration = 0
  local MaxDuration = 0
  -- Added TickTime variable, as Rake and Moonfire don't have tick times in DBC
  local TickTime = 0
  if Spell == S.RipDebuff then
    AddedDuration = (4 + ComboPoints * 4)
    MaxDuration = 31.2
    TickTime = Spell:TickTime()
  else
    AddedDuration = Spell:BaseDuration()
    MaxDuration = Spell:MaxDuration()
    TickTime = Spell:TickTime()
  end

  local OldTicks = Tar:DebuffTicksRemain(Spell)
  local OldTime = Tar:DebuffRemains(Spell)
  local NewTime = AddedDuration + OldTime
  if NewTime > MaxDuration then NewTime = MaxDuration end
  local NewTicks = NewTime / TickTime
  if not OldTicks then OldTicks = 0 end
  local TicksAdded = NewTicks - OldTicks
  return TicksAdded
end

local function HighestTTD(enemies)
  if not enemies then return 0 end
  local HighTTD = 0
  local HighTTDTar = nil
  for _, enemy in pairs(enemies) do
    local TTD = enemy:TimeToDie()
    if TTD > HighTTD then
      HighTTD = TTD
      HighTTDTar = enemy
    end
  end
  return HighTTD, HighTTDTar
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterAdaptiveSwarm(TargetUnit)
  -- target_if=max:(1+dot.adaptive_swarm_damage.stack)*dot.adaptive_swarm_damage.stack<3*time_to_die
  return (1 + TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff)) * num(TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3) * TargetUnit:TimeToDie()
end

local function EvaluateTargetIfFilterBloodseeker(TargetUnit)
  -- target_if=max:dot.bloodseeker_vines.ticking
  return TargetUnit:DebuffRemains(S.BloodseekerVinesDebuff)
end

local function EvaluateTargetIfFilterLIMoonfire(TargetUnit)
  -- target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking
  return (3 * num(TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff))) + num(TargetUnit:DebuffUp(S.LIMoonfireDebuff))
end

local function EvaluateTargetIfFilterLIMoonfire2(TargetUnit)
  -- target_if=max:dot.moonfire.ticks_gained_on_refresh
  return TicksGainedOnRefresh(S.LIMoonfireDebuff, TargetUnit)
end

local function EvaluateTargetIfFilterRakeAoEBuilder(TargetUnit)
  -- target_if=min:dot.rake.remains-20*(dot.rake.pmultiplier<persistent_multiplier)
  return TargetUnit:DebuffRemains(S.RakeDebuff) - 20 * num(TargetUnit:PMultiplier(S.Rake) < Player:PMultiplier(S.Rake))
end

local function EvaluateTargetIfFilterRakeMain(TargetUnit)
  -- target_if=max:refreshable+persistent_multiplier>dot.rake.pmultiplier
  return num(TargetUnit:DebuffRefreshable(S.RakeDebuff)) + Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake)
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return TargetUnit:TimeToDie()
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfAdaptiveSwarm(TargetUnit)
  -- if=dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1
  -- Note: Everything but stack count handled before CastTargetIf call
  return TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3
end

local function EvaluateTargetIfBrutalSlashAoeBuilder(TargetUnit)
  -- if=!(variable.need_bt&buff.bt_swipe.up)&(cooldown.brutal_slash.full_recharge_time<4|time_to_die<4|raid_event.adds.remains<4)
  return not (VarNeedBT or BTBuffUp(S.Swipe)) and (S.BrutalSlash:FullRechargeTime() < 4 or TargetUnit:TimeToDie() < 4 or FightRemains < 4)
end

local function EvaluateTargetIfLIMoonfireRefreshable(TargetUnit)
  -- if=refreshable
  return TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff)
end

local function EvaluateTargetIfPrimalWrath(TargetUnit)
  -- if=spell_targets.primal_wrath>1&((dot.primal_wrath.remains<6.5&!buff.bs_inc.up|dot.primal_wrath.refreshable)|(!talent.rampant_ferocity.enabled&(spell_targets.primal_wrath>1&!dot.bloodseeker_vines.ticking&!buff.ravage.up|spell_targets.primal_wrath>6+talent.ravage))|dot.primal_wrath.pmultiplier<persistent_multiplier)
  return (TargetUnit:DebuffRemains(S.RipDebuff) < 6.5 and Player:BuffDown(BsInc) or TargetUnit:DebuffRefreshable(S.RipDebuff)) or (not S.RampantFerocity:IsAvailable() and (EnemiesCount8y > 1 and TargetUnit:DebuffDown(S.BloodseekerVinesDebuff) and Player:BuffDown(S.RavageBuffFeral) or EnemiesCount8y > 6 + num(S.Ravage:IsAvailable()))) or TargetUnit:PMultiplier(S.Rip) < Player:PMultiplier(S.Rip)
end

local function EvaluateTargetIfRakeRefreshable(TargetUnit)
  -- if=refreshable
  return TargetUnit:DebuffRefreshable(S.RakeDebuff)
end

--- ===== CastCycle Condition Functions =====
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&dot.adaptive_swarm_damage.stack<3&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight&target.time_to_die>5
  return (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2) and TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and not S.AdaptiveSwarm:InFlight() and TargetUnit:TimeToDie() > 5
end

local function EvaluateCycleRake(TargetUnit)
  -- target_if=!dot.rake.ticking
  return TargetUnit:DebuffDown(S.RakeDebuff)
end

local function EvaluateCycleRakeAoeBuilder(TargetUnit)
  -- target_if=dot.rake.pmultiplier<1.6
  return TargetUnit:PMultiplier(S.Rake) < 1.6
end

local function EvaluateCycleRip(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.RipDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and Everyone.GroupBuffMissing(S.MarkoftheWildBuff) then
    if Cast(S.MarkoftheWild, Settings.CommonsOGCD.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
  -- cat_form,if=!buff.cat_form.up
  if S.CatForm:IsCastable() then
    if Cast(S.CatForm) then return "cat_form precombat 2"; end
  end
  -- prowl,if=!buff.prowl.up
  if S.Prowl:IsCastable() then
    if Cast(S.Prowl) then return "prowl precombat 4"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.agility|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.agility|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=talent.convoke_the_spirits&!talent.ashamanes_guidance&variable.trinket_1_buffs&(trinket.1.cooldown.duration%%120=0|120%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=talent.convoke_the_spirits&!talent.ashamanes_guidance&variable.trinket_2_buffs&(trinket.1.cooldown.duration%%120=0|120%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=!(talent.convoke_the_spirits&!talent.ashamanes_guidance)&variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.bs_inc.duration=0|cooldown.bs_inc.duration%%trinket.1.cooldown.duration=0|trinket.1.cooldown.duration%%cooldown.convoke_the_spirits.duration=0|cooldown.convoke_the_spirits.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=!(talent.convoke_the_spirits&!talent.ashamanes_guidance)&variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.bs_inc.duration=0|cooldown.bs_inc.duration%%trinket.2.cooldown.duration=0|trinket.2.cooldown.duration%%cooldown.convoke_the_spirits.duration=0|cooldown.convoke_the_spirits.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.agility)*(1.2+trinket.2.has_buff.mastery)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.agility)*(1.2+trinket.1.has_buff.mastery)*(variable.trinket_1_sync))
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED.
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (not Target:IsInRange(8)) then
    if Cast(S.WildCharge, nil, nil, not Target:IsInRange(28)) then return "wild_charge precombat 6"; end
  end
  -- Manually added: rake
  if S.Rake:IsReady() then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake precombat 8"; end
  end
end

local function Builder()
  -- variable,name=proccing_bt,op=set,value=variable.need_bt
  VarProccingBT = VarNeedBT
  -- shadowmeld,if=gcd=0&energy>=35&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)*!(variable.need_bt&buff.bt_rake.up)&buff.tigers_fury.up
  if S.Shadowmeld:IsCastable() and not Player:StealthUp(false, true) and (Player:Energy() >= 35 and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and not (VarNeedBT and BTBuffUp(S.Rake)) and Player:BuffUp(S.TigersFury)) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "shadowmeld builder 2"; end
  end
  -- rake,if=((refreshable&persistent_multiplier>=dot.rake.pmultiplier|dot.rake.remains<3)|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)&!(variable.need_bt&buff.bt_rake.up)
  if S.Rake:IsReady() and (((Target:DebuffRefreshable(S.RakeDebuff) and Player:PMultiplier(S.Rake) >= Target:PMultiplier(S.Rake) or Target:DebuffRemains(S.RakeDebuff) < 3) or Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)) and not (VarNeedBT and BTBuffUp(S.Rake))) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 4"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.full_recharge_time<4&!(variable.need_bt&buff.bt_swipe.up)
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:FullRechargeTime() < 4 and not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 6"; end
  end
  -- thrash_cat,if=refreshable
  if S.Thrash:IsCastable() and (Target:DebuffRefreshable(S.ThrashDebuff)) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash builder 8"; end
  end
  -- shred,if=buff.clearcasting.react
  if S.Shred:IsReady() and (Player:BuffUp(S.Clearcasting)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 10"; end
  end
  -- moonfire_cat,if=refreshable
  if S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 12"; end
  end
  -- brutal_slash,if=!(variable.need_bt&buff.bt_swipe.up)
  if S.BrutalSlash:IsReady() and (not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 14"; end
  end
  -- swipe_cat,if=talent.wild_slashes&!(variable.need_bt&buff.bt_swipe.up)
  if S.Swipe:IsReady() and (S.WildSlashes:IsAvailable() and not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe builder 16"; end
  end
  -- shred,if=!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and (not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 18"; end
  end
  -- swipe_cat,if=variable.need_bt&buff.bt_swipe.down
  if S.Swipe:IsReady() and (VarNeedBT and BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe builder 20"; end
  end
  -- rake,if=variable.need_bt&buff.bt_rake.down&persistent_multiplier>=dot.rake.pmultiplier
  if S.Rake:IsReady() and (VarNeedBT and BTBuffDown(S.Rake) and Player:PMultiplier(S.Rake) >= Target:PMultiplier(S.Rake)) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 22"; end
  end
  -- moonfire_cat,if=variable.need_bt&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (VarNeedBT and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat builder 24"; end
  end
  -- thrash_cat,if=variable.need_bt&buff.bt_thrash.down
  if S.Thrash:IsCastable() and (VarNeedBT and BTBuffDown(S.Thrash)) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash builder 26"; end
  end
end

local function Finisher()
  -- primal_wrath,target_if=max:dot.bloodseeker_vines.ticking,if=spell_targets.primal_wrath>1&((dot.primal_wrath.remains<6.5&!buff.bs_inc.up|dot.primal_wrath.refreshable)|(!talent.rampant_ferocity.enabled&(spell_targets.primal_wrath>1&!dot.bloodseeker_vines.ticking&!buff.ravage.up|spell_targets.primal_wrath>6+talent.ravage))|dot.primal_wrath.pmultiplier<persistent_multiplier)
  if S.PrimalWrath:IsReady() and (EnemiesCount8y > 1) then
    if Everyone.CastTargetIf(S.PrimalWrath, Enemies8y, "max", EvaluateTargetIfFilterBloodseeker, EvaluateTargetIfPrimalWrath, not IsInAoERange) then return "primal_wrath finisher 2"; end
  end
  -- rip,target_if=refreshable,if=(!talent.primal_wrath|spell_targets=1)&(buff.bloodtalons.up|!talent.bloodtalons)&(buff.tigers_fury.up|dot.rip.remains<cooldown.tigers_fury.remains)
  if S.Rip:IsReady() and ((not S.PrimalWrath:IsAvailable() or EnemiesCountMelee == 1) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (Player:BuffUp(S.TigersFury) or Target:DebuffRemains(S.RipDebuff) < S.TigersFury:CooldownRemains())) then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip, not IsInMeleeRange) then return "rip finisher 4"; end
  end
  -- pool_resource,for_next=1
  -- ferocious_bite,max_energy=1,target_if=max:dot.bloodseeker_vines.ticking,if=!buff.bs_inc.up|!talent.soul_of_the_forest.enabled
  -- TODO: Determine a way to do both pool_resource and target_if together.
  if S.FerociousBite:IsReady() and (Player:BuffDown(BsInc) or not S.SouloftheForest:IsAvailable()) then
    if CastPooling(S.FerociousBite, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 6"; end
  end
  -- ferocious_bite,target_if=max:dot.bloodseeker_vines.ticking
  if S.FerociousBite:IsReady() then
    if Everyone.CastTargetIf(S.FerociousBite, EnemiesMelee, "max", EvaluateTargetIfFilterBloodseeker, nil, not IsInMeleeRange) then return "ferocious_bite finisher 8"; end
  end
end

local function AoeBuilder()
  -- variable,name=proccing_bt,op=set,value=variable.need_bt
  VarProccingBT = VarNeedBT
  -- rake,target_if=!dot.rake.ticking,if=buff.sudden_ambush.up&!(variable.need_bt&buff.bt_rake.up)
  if S.Rake:IsReady() and (Player:BuffUp(S.SuddenAmbushBuff) and not (VarNeedBT and BTBuffUp(S.Rake))) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRake, nil, not IsInMeleeRange) then return "rake aoe_builder 2"; end
  end
  -- brutal_slash,target_if=max:time_to_die,if=!(variable.need_bt&buff.bt_swipe.up)&(cooldown.brutal_slash.full_recharge_time<4|time_to_die<4|raid_event.adds.remains<4)
  if S.BrutalSlash:IsReady() then
    if Everyone.CastTargetIf(S.BrutalSlash, Enemies8y, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfBrutalSlashAoeBuilder, not IsInMeleeRange) then return "brutal_slash aoe_builder 4"; end
  end
  -- thrash_cat,if=refreshable&!talent.thrashing_claws
  if S.Thrash:IsReady() and (Target:DebuffRefreshable(S.ThrashDebuff) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash aoe_builder 6"; end
  end
  -- prowl,target_if=dot.rake.refreshable|dot.rake.pmultiplier<1.4,if=!(buff.bt_rake.up&active_bt_triggers=2)&action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up
  -- Note: Skipping cycling and putting target_if into main condition.
  if S.Prowl:IsReady() and not Player:StealthUp(false, true) and ((not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff)) and (DebuffRefreshAny(EnemiesMelee, S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4)) then
    if Cast(S.Prowl) then return "prowl aoe_builder 8"; end
  end
  -- shadowmeld,target_if=dot.rake.refreshable|dot.rake.pmultiplier<1.4,if=!(buff.bt_rake.up&active_bt_triggers=2)&action.rake.ready&!buff.sudden_ambush.up&!buff.prowl.up
  -- Note: Skipping cycling and putting target_if into main condition.
  if S.Shadowmeld:IsReady() and not Player:StealthUp(false, true) and ((not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and Player:BuffDown(S.Prowl)) and (DebuffRefreshAny(EnemiesMelee, S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4)) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "shadowmeld aoe_builder 10"; end
  end
  -- rake,target_if=min:dot.rake.remains-20*(dot.rake.pmultiplier<persistent_multiplier),if=refreshable&!(buff.bt_rake.up&active_bt_triggers=2)
  if S.Rake:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "min", EvaluateTargetIfFilterRakeAoEBuilder, EvaluateTargetIfRakeRefreshable, not IsInMeleeRange) then return "rake aoe_builder 12"; end
  end
  -- brutal_slash,if=!(buff.bt_swipe.up&active_bt_triggers=2)
  if S.BrutalSlash:IsReady() and (not (BTBuffUp(S.Swipe) and CountActiveBtTriggers() == 2)) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash aoe_builder 14"; end
  end
  -- moonfire_cat,target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking,if=refreshable&(spell_targets.swipe_cat<4|talent.brutal_slash)&!(buff.bt_moonfire.up&active_bt_triggers=2)
  if S.LIMoonfire:IsReady() and ((EnemiesCount8y < 4 or S.BrutalSlash:IsAvailable()) and not (BTBuffUp(S.LIMoonfireDebuff) and CountActiveBtTriggers() == 2)) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies8y, "max", EvaluateTargetIfFilterLIMoonfire, EvaluateTargetIfLIMoonfireRefreshable, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builder 16"; end
  end
  -- swipe_cat,if=!(buff.bt_swipe.up&active_bt_triggers=2)
  if S.Swipe:IsReady() and (not (BTBuffUp(S.Swipe) and CountActiveBtTriggers() == 2)) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe aoe_builder 18"; end
  end
  -- moonfire_cat,target_if=max:(3*refreshable)+dot.adaptive_swarm_damage.ticking,if=refreshable&!(buff.bt_moonfire.up&active_bt_triggers=2)
  if S.LIMoonfire:IsReady() and (not (BTBuffUp(S.LIMoonfire) and CountActiveBtTriggers() == 2)) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies8y, "max", EvaluateTargetIfFilterLIMoonfire, EvaluateTargetIfLIMoonfireRefreshable, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builder 20"; end
  end
  -- rake,target_if=min:dot.rake.remains-20*(dot.rake.pmultiplier<persistent_multiplier),if=!(buff.bt_rake.up&active_bt_triggers=2)
  if S.Rake:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2)) then
    if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "min", EvaluateTargetIfFilterRakeAoEBuilder, nil, not IsInMeleeRange) then return "rake aoe_builder 22"; end
  end
  -- shred,if=!(buff.bt_shred.up&active_bt_triggers=2)&!variable.easy_swipe&!buff.sudden_ambush.up
  if S.Shred:IsReady() and (not (BTBuffUp(S.Shred) and CountActiveBtTriggers() == 2) and not VarEasySwipe and not Player:BuffUp(S.SuddenAmbushBuff)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred aoe_builder 24"; end
  end
  -- thrash_cat,if=!(buff.bt_thrash.up&active_bt_triggers=2)&!talent.thrashing_claws
  if S.Thrash:IsReady() and (not (BTBuffUp(S.Thrash) and CountActiveBtTriggers() == 2) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash aoe_builder 26"; end
  end
  -- moonfire_cat,target_if=max:dot.moonfire.ticks_gained_on_refresh,if=variable.need_bt&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (VarNeedBT and BTBuffDown(S.LIMoonfire)) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies8y, "max", EvaluateTargetIfFilterLIMoonfire2, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat aoe_builder 28"; end
  end
  -- shred,if=variable.need_bt&buff.bt_shred.down&!variable.easy_swipe
  if S.Shred:IsReady() and (VarNeedBT and BTBuffDown(S.Shred) and not VarEasySwipe) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred aoe_builder 30"; end
  end
  -- rake,target_if=dot.rake.pmultiplier<1.6,if=variable.need_bt&buff.bt_rake.down
  if S.Rake:IsReady() and (VarNeedBT and BTBuffDown(S.Rake)) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeAoeBuilder, not IsInMeleeRange) then return "rake aoe_builder 32"; end
  end
end

local function Berserk()
  -- call_action_list,name=finisher,if=combo_points=5
  if ComboPoints == 5 then
    local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
  end
  -- run_action_list,name=aoe_builder,if=spell_targets.swipe_cat>=2
  if EnemiesCount8y >= 2 then
    local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoeBuilder()"; end
  end
  -- prowl,if=!(buff.bt_rake.up&active_bt_triggers=2)&action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.shadowmeld.up
  if S.Prowl:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Shadowmeld)) then
    if Cast(S.Prowl) then return "prowl berserk 2"; end
  end
  -- shadowmeld,if=!(buff.bt_rake.up&active_bt_triggers=2)&action.rake.ready&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!buff.prowl.up
  if S.Shadowmeld:IsCastable() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and Player:BuffDown(S.Prowl)) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "shadowmeld berserk 4"; end
  end
  -- rake,if=!(buff.bt_rake.up&active_bt_triggers=2)&(dot.rake.remains<3|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)
  if S.Rake:IsReady() and (not (BTBuffUp(S.Rake) and CountActiveBtTriggers() == 2) and (Target:DebuffRemains(S.RakeDebuff) < 3 or (Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)))) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake berserk 6"; end
  end
  -- moonfire_cat,if=refreshable
  if S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsSpellInRange(S.LIMoonfire)) then return "moonfire_cat berserk 8"; end
  end
  -- thrash_cat,if=!talent.thrashing_claws&refreshable
  if S.Thrash:IsReady() and (not S.ThrashingClaws:IsAvailable() and Target:DebuffRefreshable(S.ThrashDebuff)) then
    if Cast(S.Thrash, nil, nil, not IsInAoERange) then return "thrash berserk 10"; end
  end  
  -- shred,if=active_bt_triggers=2&buff.bt_shred.down
  if S.Shred:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred berserk 12"; end
  end
  -- brutal_slash,if=active_bt_triggers=2&buff.bt_swipe.down
  if S.BrutalSlash:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Swipe)) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash berserk 14"; end
  end
  -- swipe_cat,if=active_bt_triggers=2&buff.bt_swipe.down&talent.wild_slashes
  if S.Swipe:IsReady() and (CountActiveBtTriggers() == 2 and BTBuffDown(S.Swipe) and S.WildSlashes:IsAvailable()) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe_cat berserk 16"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.charges>1&buff.bt_swipe.down
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:Charges() > 1 and BTBuffDown(S.Swipe)) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash berserk 18"; end
  end
  -- shred,if=buff.bt_shred.down
  if S.Shred:IsReady() and (BTBuffDown(S.Shred)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred berserk 20"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.charges>1
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:Charges() > 1) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash berserk 22"; end
  end
  -- swipe_cat,if=buff.bt_swipe.down&talent.wild_slashes
  if S.Swipe:IsReady() and (BTBuffDown(S.Swipe) and S.WildSlashes:IsAvailable()) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe_cat berserk 24"; end
  end
  -- shred
  if S.Shred:IsReady() then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred berserk 26"; end
  end
end

local function Cooldown()
  -- incarnation
  if S.Incarnation:IsReady() then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 2"; end
  end
  -- berserk
  if S.Berserk:IsReady() then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 4"; end
  end
  -- berserking,if=buff.bs_inc.up|cooldown.bs_inc.remains>50
  if S.Berserking:IsCastable() and (Player:BuffUp(BsInc) or BsInc:CooldownRemains() > 50) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cooldown 6"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<32|(!variable.lastZerk&variable.lastConvoke&cooldown.convoke_the_spirits.remains<10)
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < 32 or (not VarLastZerk and VarLastConvoke and S.ConvoketheSpirits:CooldownRemains() < 10)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldown 8"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ItemToUse:IsReady() then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " cooldown 10"; end
    end
  end
  -- feral_frenzy,if=combo_points<=1|buff.bs_inc.up&combo_points<=2
  if S.FeralFrenzy:IsReady() and (ComboPoints <= 1 or Player:BuffUp(BsInc) and ComboPoints <= 2) then
    if Cast(S.FeralFrenzy, Settings.Feral.GCDasOffGCD.FeralFrenzy, nil, not IsInMeleeRange) then return "feral_frenzy cooldown 12"; end
  end
  -- use_item,slot=trinket1,if=(buff.bs_inc.up|((buff.tigers_fury.up&cooldown.tigers_fury.remains>20)&(cooldown.convoke_the_spirits.remains<4|cooldown.convoke_the_spirits.remains>45|cooldown.convoke_the_spirits.remains-trinket.2.cooldown.remains>0|!talent.convoke_the_spirits&(cooldown.bs_inc.remains>40|cooldown.bs_inc.remains-trinket.2.cooldown.remains>0))))&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  if Trinket1:IsReady() and not VarTrinket1BL and ((Player:BuffUp(BsInc) or ((Player:BuffUp(S.TigersFury) and S.TigersFury:CooldownRemains() > 20) and (S.ConvoketheSpirits:CooldownRemains() < 4 or S.ConvoketheSpirits:CooldownRemains() > 45 or S.ConvoketheSpirits:CooldownRemains() - Trinket2:CooldownRemains() > 0 or not S.ConvoketheSpirits:IsAvailable() and (BsInc:CooldownRemains() > 40 or BsInc:CooldownRemains() - Trinket2:CooldownRemains() > 0)))) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1) or VarTrinket1Duration >= FightRemains) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for "..Trinket1:Name().." cooldown 14"; end
  end
  -- use_item,slot=trinket2,if=(buff.bs_inc.up|((buff.tigers_fury.up&cooldown.tigers_fury.remains>20)&(cooldown.convoke_the_spirits.remains<4|cooldown.convoke_the_spirits.remains>45|cooldown.convoke_the_spirits.remains-trinket.1.cooldown.remains>0|!talent.convoke_the_spirits&(cooldown.bs_inc.remains>40|cooldown.bs_inc.remains-trinket.1.cooldown.remains>0))))&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  if Trinket2:IsReady() and not VarTrinket2BL and ((Player:BuffUp(BsInc) or ((Player:BuffUp(S.TigersFury) and S.TigersFury:CooldownRemains() > 20) and (S.ConvoketheSpirits:CooldownRemains() < 4 or S.ConvoketheSpirits:CooldownRemains() > 45 or S.ConvoketheSpirits:CooldownRemains() - Trinket1:CooldownRemains() > 0 or not S.ConvoketheSpirits:IsAvailable() and (BsInc:CooldownRemains() > 40 or BsInc:CooldownRemains() - Trinket1:CooldownRemains() > 0)))) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 1) or VarTrinket1Duration >= FightRemains) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for "..Trinket2:Name().." cooldown 16"; end
  end
  -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.2.cooldown.remains>20|!variable.trinket_2_buffs|trinket.2.cooldown.remains&cooldown.tigers_fury.remains>20)
  if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and (Trinket2:CooldownRemains() > 20 or not VarTrinket2Buffs or Trinket2:CooldownDown() and S.TigersFury:CooldownRemains() > 20)) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for "..Trinket1:Name().." cooldown 18"; end
  end
  -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.1.cooldown.remains>20|!variable.trinket_1_buffs|trinket.1.cooldown.remains&cooldown.tigers_fury.remains>20)
  if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and (Trinket1:CooldownRemains() > 20 or not VarTrinket1Buffs or Trinket1:CooldownDown() and S.TigersFury:CooldownRemains() > 20)) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for "..Trinket2:Name().." cooldown 20"; end
  end
  -- convoke_the_spirits,if=fight_remains<5|(buff.tigers_fury.up&(combo_points<=2|buff.bs_inc.up&combo_points<=3)&(target.time_to_die>5-talent.ashamanes_guidance.enabled|target.time_to_die=fight_remains))
  if S.ConvoketheSpirits:IsCastable() and (BossFightRemains < 5 or (Player:BuffUp(S.TigersFury) and (ComboPoints <= 2 or Player:BuffUp(BsInc) and ComboPoints <= 3) and (Target:TimeToDie() > 5 - num(S.AshamanesGuidance:IsAvailable()) or Target:TimeToDie() == FightRemains))) then
    if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits, not IsInMeleeRange) then return "convoke_the_spirits cooldown 22"; end
  end
end

local function Variables()
  -- variable,name=effective_energy,op=set,value=energy+(40*buff.clearcasting.stack)+(3*energy.regen)+(50*cooldown.tigers_fury.remains<3.5)
  VarEffectiveEnergy = Player:Energy() + (40 * Player:BuffStack(S.Clearcasting)) + (3 * Player:EnergyRegen()) + (50 * num(S.TigersFury:CooldownRemains() < 3.5))
  -- variable,name=time_to_pool,op=set,value=((115-variable.effective_energy-(23*buff.incarnation.up))%energy.regen)
  VarTimeToPool = ((115 - VarEffectiveEnergy - (23 * num(Player:BuffUp(S.Incarnation)))) / Player:EnergyRegen())
  -- variable,name=need_bt,value=talent.bloodtalons&buff.bloodtalons.stack<=1
  VarNeedBT = S.Bloodtalons:IsAvailable() and Player:BuffStack(S.BloodtalonsBuff) <= 1
  -- variable,name=lastConvoke,value=(cooldown.convoke_the_spirits.remains+cooldown.convoke_the_spirits.duration)>remains&cooldown.convoke_the_spirits.remains<remains
  VarLastConvoke = (S.ConvoketheSpirits:CooldownRemains() + 120) > FightRemains and S.ConvoketheSpirits:CooldownRemains() < FightRemains
  -- variable,name=lastZerk,value=(cooldown.bs_inc.remains+cooldown.bs_inc.duration+5)>remains&cooldown.convoke_the_spirits.remains<remains
  VarLastZerk = (BsInc:CooldownRemains() + 185) > FightRemains and BsInc:CooldownRemains() < FightRemains
  -- variable,name=lastPotion,value=(300-((time+300)%%300)+300+15)>remains&300-((time+300)%%300)+15<remains
  VarLastPotion = (300 - ((HL.CombatTime() + 300) % 300) + 300 + 15) > FightRemains and 300 - ((HL.CombatTime() + 300) % 300) + 15 < FightRemains
  -- variable,name=zerk_biteweave,op=reset
  VarZerkBiteweave = Settings.Feral.UseZerkBiteweave
  -- variable,name=regrowth,op=reset
  VarRegrowth = Settings.Feral.ShowHealSpells
  -- variable,name=easy_swipe,op=reset
  VarEasySwipe = Settings.Feral.UseEasySwipe
end

--- ===== APL Main =====
local function APL()
  -- Update Enemies
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5)
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  if AoEON() then
    EnemiesCountMelee = #EnemiesMelee
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCountMelee = 1
    EnemiesCount8y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end

    -- Combo Points
    ComboPoints = Player:ComboPoints()
    ComboPointsDeficit = Player:ComboPointsDeficit()

    -- Range Stuffs
    IsInMeleeRange = Target:IsInRange(5)
    IsInAoERange = Target:IsInRange(8)
  end

  -- cat_form OOC, if setting is true
  if S.CatForm:IsCastable() and Settings.Feral.ShowCatFormOOC then
    if Cast(S.CatForm) then return "cat_form ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.SkullBash, Settings.CommonsDS.DisplayStyle.Interrupts, InterruptStuns); if ShouldReturn then return ShouldReturn; end
    -- prowl,if=buff.bs_inc.down&!buff.prowl.up
    if S.Prowl:IsCastable() and (Player:BuffDown(BsInc) or not Player:AffectingCombat()) then
      if Cast(S.Prowl) then return "prowl main 2"; end
    end
    -- cat_form,if=!buff.cat_form.up&!talent.fluid_form
    if S.CatForm:IsCastable() and (not S.FluidForm:IsAvailable()) then
      if Cast(S.CatForm) then return "cat_form main 4"; end
    end
    -- invoke_external_buff,name=power_infusion,if=buff.bs_inc.up|!talent.berserk_heart_of_the_lion
    -- Note: We're not handling external buffs
    -- call_action_list,name=variables
    Variables()
    -- auto_attack,if=!buff.prowl.up|!buff.shadowmeld.up
    -- tigers_fury,if=energy.deficit>35|combo_points=5
    if S.TigersFury:IsCastable() and (Player:EnergyDeficit() > 35 or ComboPoints == 5) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 6"; end
    end
    -- rake,target_if=max:refreshable+persistent_multiplier>dot.rake.pmultiplier,if=buff.shadowmeld.up|buff.prowl.up
    if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
      if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeMain, nil, not IsInAoERange) then return "rake main 8"; end
    end
    -- natures_vigil,if=spell_targets.swipe_cat>0
    if Settings.Feral.ShowHealSpells and S.NaturesVigil:IsCastable() and (EnemiesCount8y > 0) then
      if Cast(S.NaturesVigil, Settings.Feral.OffGCDasOffGCD.NaturesVigil) then return "natures_vigil main 10"; end
    end
    -- renewal,if=spell_targets.swipe_cat>0
    if Settings.Feral.ShowHealSpells and S.Renewal:IsCastable() and (EnemiesCount8y > 0) then
      if Cast(S.Renewal, Settings.Feral.GCDasOffGCD.Renewal) then return "renewal main 12"; end
    end
    -- ferocious_bite,if=buff.apex_predators_craving.up&!(variable.need_bt&active_bt_triggers=2)
    if S.FerociousBite:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff) and not (VarNeedBT and CountActiveBtTriggers() == 2)) then
      if Cast(S.FerociousBite, nil, nil, not IsInMeleeRange) then return "ferocious_bite main 14"; end
    end
    -- adaptive_swarm,target_if=(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2)&dot.adaptive_swarm_damage.stack<3&!action.adaptive_swarm_damage.in_flight&!action.adaptive_swarm.in_flight&target.time_to_die>5,if=buff.cat_form.up&!talent.unbridled_swarm.enabled|spell_targets.swipe_cat=1
    if S.AdaptiveSwarm:IsReady() and (Player:BuffUp(S.CatForm) and not S.UnbridledSwarm:IsAvailable() or EnemiesCount8y == 1) then
      if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8y, EvaluateCycleAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "adaptive_swarm main 16"; end
    end
    -- adaptive_swarm,target_if=max:(1+dot.adaptive_swarm_damage.stack)*dot.adaptive_swarm_damage.stack<3*time_to_die,if=buff.cat_form.up&dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1
    if S.AdaptiveSwarm:IsReady() and (Player:BuffUp(S.CatForm) and Target:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and S.UnbridledSwarm:IsAvailable() and EnemiesCount8y > 1) then
      if Everyone.CastTargetIf(S.AdaptiveSwarm, Enemies8y, "max", EvaluateTargetIfFilterAdaptiveSwarm, EvaluateTargetIfAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "adaptive_swarm main 18"; end
    end
    -- call_action_list,name=cooldown,if=dot.rip.ticking
    if CDsON() and Target:DebuffUp(S.RipDebuff) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=berserk,if=buff.bs_inc.up
    if Player:BuffUp(BsInc) then
      local ShouldReturn = Berserk(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=finisher,if=combo_points=5
    if ComboPoints == 5 then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=builder,if=spell_targets.swipe_cat=1&combo_points<5&(variable.time_to_pool<=0|!variable.need_bt|variable.proccing_bt)
    if EnemiesCount8y == 1 and ComboPoints < 5 and (VarTimeToPool <= 0 or not VarNeedBT or VarProccingBT) then
      local ShouldReturn = Builder(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_builder,if=spell_targets.swipe_cat>=2&combo_points<5&(variable.time_to_pool<=0|!variable.need_bt|variable.proccing_bt)
    if EnemiesCount8y >= 2 and ComboPoints < 5 and (VarTimeToPool <= 0 or not VarNeedBT or VarProccingBT) then
      local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
    end
    -- regrowth,if=buff.predatory_swiftness.up&variable.regrowth
    if S.Regrowth:IsReady() and (Player:BuffUp(S.PredatorySwiftnessBuff) and VarRegrowth) then
      if Cast(S.Regrowth, Settings.Feral.GCDasOffGCD.Regrowth) then return "regrowth main 20"; end
    end
    -- Pool if nothing else to do
    if (true) then
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Energy"; end
    end
  end
end

local function OnInit()
  S.RipDebuff:RegisterAuraTracking()

  HR.Print("Feral Druid rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(103, APL, OnInit)
