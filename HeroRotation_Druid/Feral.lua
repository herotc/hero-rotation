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
local mathmax     = math.max
local mathmin     = math.min
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
local OnUseExcludes = {
  I.BestinSlotsMelee:ID(),
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
local VarConvokeCountRemaining, VarZerkCountRemaining
local VarPotCountRemaining, VarSlot1CountRemaining, VarSlot2CountRemaining
local VarFirstHoldBerserkCondition, VarSecondHoldBerserkCondition
local VarHoldBerserk, VarHoldConvoke, VarHoldPot
local VarBsIncCD = S.BerserkHeartoftheLion:IsAvailable() and 120 or 180
local VarConvokeCD = S.AshamanesGuidance:IsAvailable() and 60 or 120
local VarPotCD = 300
local VarHighestCDRemaining, VarLowestCDRemaining, VarSecondLowestCDRemaining
local VarRipDuration, VarRipMaxPandemicDuration
local VarNeedBT
local VarCCCapped, VarRegrowth, VarEasySwipe
local ComboPoints, ComboPointsDeficit
local BsInc = S.Incarnation:IsAvailable() and S.Incarnation or S.Berserk
local IsInMeleeRange, IsInAoERange
local BossFightRemains = 11111
local FightRemains = 11111
local EnemiesMelee, EnemiesCountMelee
local Enemies8y, EnemiesCount8y

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
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

  VarTrinket1ID = Trinket1:ID()
  VarTrinket2ID = Trinket2:ID()

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
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local InterruptStuns = {
  { S.MightyBash, "Cast Mighty Bash (Interrupt)", function () return true; end },
  { S.Typhoon, "Cast Typhoon (Interrupt)", function () return true; end },
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
  return (Player:StealthUp(true, true) or S.Prowl:TimeSinceLastRemovedOnPlayer() < 1) and 1.6 or 1
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
  S.ThrashCat,
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
  -- target_if=max:ticks_gained_on_refresh
  return TicksGainedOnRefresh(S.LIMoonfireDebuff, TargetUnit)
end

local function EvaluateTargetIfFilterRakeAoEBuilder(TargetUnit)
  -- target_if=max:ticks_gained_on_refresh
  return TicksGainedOnRefresh(S.RakeDebuff, TargetUnit)
end

local function EvaluateTargetIfFilterRakeMain(TargetUnit)
  -- target_if=max:refreshable+(persistent_multiplier>dot.rake.pmultiplier)
  return num(TargetUnit:DebuffRefreshable(S.RakeDebuff)) + num(Player:PMultiplier(S.Rake) > TargetUnit:PMultiplier(S.Rake))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return TargetUnit:TimeToDie()
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfAdaptiveSwarm(TargetUnit)
  -- if=buff.cat_form.up&dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1&dot.rip.ticking
  -- Note: Everything but stack count and rip check handled before CastTargetIf call
  return TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffUp(S.RipDebuff)
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
  -- if=spell_targets.primal_wrath>1&((dot.primal_wrath.remains<6.5&!buff.bs_inc.up|dot.primal_wrath.refreshable)|(!talent.rampant_ferocity.enabled&(spell_targets.primal_wrath>1&!dot.bloodseeker_vines.ticking&!buff.ravage.up|spell_targets.primal_wrath>6+talent.ravage)))
  return (TargetUnit:DebuffRemains(S.RipDebuff) < 6.5 and Player:BuffDown(BsInc) or TargetUnit:DebuffRefreshable(S.RipDebuff)) or (not S.RampantFerocity:IsAvailable() and (EnemiesCount8y > 1 and TargetUnit:DebuffDown(S.BloodseekerVinesDebuff) and Player:BuffDown(S.RavageBuffFeral) or EnemiesCount8y > 6 + num(S.Ravage:IsAvailable())))
end

local function EvaluateTargetIfRakeRefreshable(TargetUnit)
  -- if=refreshable
  return TargetUnit:DebuffRefreshable(S.RakeDebuff)
end

--- ===== CastCycle Condition Functions =====
local function EvaluateCycleAdaptiveSwarm(TargetUnit)
  -- target_if=dot.adaptive_swarm_damage.stack<3&(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2),if=!action.adaptive_swarm_damage.in_flight&(spell_targets=1|!talent.unbridled_swarm)&(dot.rip.ticking|hero_tree.druid_of_the_claw)
  return (TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) or TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 2)) and (TargetUnit:DebuffUp(S.RipDebuff) or Player:HeroTreeID() == 21)
end

local function EvaluateCycleMoonfire(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.LIMoonfireDebuff)
end

local function EvaluateCycleRake(TargetUnit)
  -- target_if=!dot.rake.ticking
  return TargetUnit:DebuffDown(S.RakeDebuff)
end

local function EvaluateCycleRakeRefreshable(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.RakeDebuff)
end

local function EvaluateCycleRakeAoeBuilder(TargetUnit)
  -- target_if=dot.rake.pmultiplier<1.6
  return TargetUnit:PMultiplier(S.Rake) < 1.6
end

local function EvaluateCycleRip(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.RipDebuff)
end

local function EvaluateCycleRip2(TargetUnit)
  -- target_if=refreshable,if=(!talent.primal_wrath|spell_targets=1)&(buff.bloodtalons.up|!talent.bloodtalons)&(buff.tigers_fury.up|dot.rip.remains<cooldown.tigers_fury.remains)&(remains<fight_remains|remains<4&buff.ravage.up)
  -- Note: (!talent.primal_wrath|spell_targets=1)&(buff.bloodtalons.up|!talent.bloodtalons) checked before CastCycle.
  return TargetUnit:DebuffRefreshable(S.RipDebuff) and (Player:BuffUp(S.TigersFury) or TargetUnit:DebuffRemains(S.RipDebuff) < S.TigersFury:CooldownRemains()) and (TargetUnit:DebuffRemains(S.RipDebuff) < FightRemains or TargetUnit:DebuffRemains(S.RipDebuff) < 4 and Player:BuffUp(S.RavageBuffFeral))
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
  -- heart_of_the_wild
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=imperfect_ascendancy_serum
    if I.ImperfectAscendancySerum:IsEquippedAndReady() then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum precombat"; end
    end
    -- use_item,name=treacherous_transmitter
    if I.TreacherousTransmitter:IsEquippedAndReady() then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter precombat"; end
    end
  end
  -- prowl,if=!buff.prowl.up
  if S.Prowl:IsReady() then
    if Cast(S.Prowl) then return "prowl precombat 4"; end
  end
  -- Manually added: wild_charge
  if S.WildCharge:IsCastable() and (not Target:IsInRange(8)) then
    if Cast(S.WildCharge, Settings.CommonsOGCD.GCDasOffGCD.WildCharge, nil, not Target:IsInRange(28)) then return "wild_charge precombat 6"; end
  end
  -- Manually added: rake
  if S.Rake:IsReady() then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake precombat 8"; end
  end
end

local function AoeBuilder()
  -- thrash_cat,if=refreshable&!talent.thrashing_claws&!(variable.need_bt&buff.bt_thrash.up)
  if S.ThrashCat:IsReady() and (Target:DebuffRefreshable(S.ThrashCatDebuff) and not S.ThrashingClaws:IsAvailable() and not (VarNeedBT and BTBuffUp(S.ThrashCat))) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash aoe_builder 2"; end
  end
  -- brutal_slash,target_if=min:time_to_die,if=(cooldown.brutal_slash.full_recharge_time<4|time_to_die<4|raid_event.adds.remains<4|(buff.bs_inc.up&spell_targets>=3-hero_tree.druid_of_the_claw))&!(variable.need_bt&buff.bt_swipe.up&(buff.bs_inc.down|spell_targets<3-hero_tree.druid_of_the_claw))
  if S.BrutalSlash:IsReady() and ((S.BrutalSlash:FullRechargeTime() < 4 or FightRemains < 4 or (Player:BuffUp(BsInc) and EnemiesCount8y >= 3 - num(Player:HeroTreeID() == 21))) and not (VarNeedBT and BTBuffUp(S.Swipe) and (Player:BuffDown(BsInc) or EnemiesCount8y < 3 - num(Player:HeroTreeID() == 21)))) then
    if Everyone.CastTargetIf(S.BrutalSlash, Enemies8y, "min", EvaluateTargetIfFilterTTD, nil, not IsInAoERange) then return "brutal_slash aoe_builder 4"; end
  end
  -- swipe_cat,target_if=min:time_to_die,if=talent.wild_slashes&(time_to_die<4|raid_event.adds.remains<4|buff.bs_inc.up&spell_targets>=3-hero_tree.druid_of_the_claw)&!(variable.need_bt&buff.bt_swipe.up&(buff.bs_inc.down|spell_targets<3-hero_tree.druid_of_the_claw))
  if S.Swipe:IsReady() and (S.WildSlashes:IsAvailable() and (FightRemains < 4 or Player:BuffUp(BsInc) and EnemiesCount8y >= 3 - num(Player:HeroTreeID() == 21)) and not (VarNeedBT and BTBuffUp(S.Swipe) and (Player:BuffDown(BsInc) or EnemiesCount8y < 3 - num(Player:HeroTreeID() == 21)))) then
    if Everyone.CastTargetIf(S.Swipe, Enemies8y, "min", EvaluateTargetIfFilterTTD, nil, not IsInAoERange) then return "swipe aoe_builder 6"; end
  end
  -- swipe_cat,if=time_to_die<4|(talent.wild_slashes&spell_targets.swipe_cat>4&!(variable.need_bt&buff.bt_swipe.up))
  if S.Swipe:IsReady() and (FightRemains < 4 or (S.WildSlashes:IsAvailable() and EnemiesCount8y > 4 and not (VarNeedBT and BTBuffUp(S.Swipe)))) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe aoe_builder 8"; end
  end
  -- prowl,target_if=dot.rake.refreshable|dot.rake.pmultiplier<1.4,if=!(variable.need_bt&buff.bt_rake.up)&action.rake.ready&gcd.remains=0&!buff.sudden_ambush.up&!variable.cc_capped
  -- Note: Skipping cycling and putting target_if into main condition.
  if S.Prowl:IsReady() and not Player:StealthUp(false, true) and ((not (VarNeedBT and BTBuffUp(S.Rake)) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and not VarCCCapped) and (DebuffRefreshAny(EnemiesMelee, S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4)) then
    if Cast(S.Prowl) then return "prowl aoe_builder 10"; end
  end
  -- shadowmeld,target_if=dot.rake.refreshable|dot.rake.pmultiplier<1.4,if=!(variable.need_bt&buff.bt_rake.up)&action.rake.ready&!buff.sudden_ambush.up&!buff.prowl.up&!variable.cc_capped
  -- Note: Skipping cycling and putting target_if into main condition.
  if S.Shadowmeld:IsReady() and not Player:StealthUp(false, true) and ((not (VarNeedBT and BTBuffUp(S.Rake)) and S.Rake:IsReady() and Player:BuffDown(S.SuddenAmbushBuff) and Player:BuffDown(S.Prowl) and not VarCCCapped) and (DebuffRefreshAny(EnemiesMelee, S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4)) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "shadowmeld aoe_builder 12"; end
  end
  -- rake,target_if=refreshable,if=talent.doubleclawed_rake&!(variable.need_bt&buff.bt_rake.up)&!variable.cc_capped
  if S.Rake:IsReady() and (S.DoubleClawedRake:IsAvailable() and not (VarNeedBT and BTBuffUp(S.Rake)) and not VarCCCapped) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeRefreshable, nil, not IsInMeleeRange) then return "rake aoe_builder 14"; end
  end
  -- swipe_cat,if=talent.wild_slashes&spell_targets.swipe_cat>2&!(variable.need_bt&buff.bt_swipe.up)
  if S.Swipe:IsReady() and (S.WildSlashes:IsAvailable() and EnemiesCount8y > 2 and not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe aoe_builder 16"; end
  end
  -- rake,target_if=max:dot.rake.ticking,if=!dot.rake.ticking&hero_tree.wildstalker
  if S.Rake:IsReady() and (Player:HeroTreeID() == 22) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRake, nil, not IsInMeleeRange) then return "rake aoe_builder 18"; end
  end
  -- moonfire_cat,target_if=refreshable,if=!(variable.need_bt&buff.bt_moonfire.up)&!variable.cc_capped
  if S.LIMoonfire:IsReady() and (not (VarNeedBT and BTBuffUp(S.LIMoonfireDebuff)) and not VarCCCapped) then
    if Everyone.CastCycle(S.LIMoonfire, Enemies8y, EvaluateCycleMoonfire, not Target:IsInRange(40)) then return "moonfire_cat aoe_builder 20"; end
  end
  -- rake,target_if=refreshable,if=!(variable.need_bt&buff.bt_rake.up)&!variable.cc_capped
  if S.Rake:IsReady() and (S.DoubleClawedRake:IsAvailable() and not (VarNeedBT and BTBuffUp(S.Rake)) and not VarCCCapped) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeRefreshable, nil, not IsInMeleeRange) then return "rake aoe_builder 22"; end
  end
  -- brutal_slash,if=!(variable.need_bt&buff.bt_swipe.up)
  if S.BrutalSlash:IsReady() and (not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInMeleeRange) then return "brutal_slash aoe_builder 24"; end
  end
  -- swipe_cat,if=!(variable.need_bt&buff.bt_swipe.up)
  if S.Swipe:IsReady() and (not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe aoe_builder 26"; end
  end
  -- shred,if=!buff.sudden_ambush.up&!variable.easy_swipe&!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and (Player:BuffDown(S.SuddenAmbushBuff) and not VarEasySwipe and not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred aoe_builder 28"; end
  end
  -- thrash_cat,if=!talent.thrashing_claws&!(variable.need_bt&buff.bt_thrash.up)
  if S.ThrashCat:IsReady() and (not S.ThrashingClaws:IsAvailable() and not (VarNeedBT and BTBuffUp(S.ThrashCat))) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash aoe_builder 30"; end
  end
  -- rake,target_if=max:ticks_gained_on_refresh,if=talent.doubleclawed_rake&buff.sudden_ambush.up&variable.need_bt&buff.bt_rake.down
  if S.Rake:IsReady() and (S.DoubleClawedRake:IsAvailable() and Player:BuffUp(S.SuddenAmbushBuff) and VarNeedBT and BTBuffDown(S.Rake)) then
    if Everyone.CastTargetIf(S.Rake, Enemies8y, "max", EvaluateTargetIfFilterRakeAoEBuilder, nil, not IsInMeleeRange) then return "rake aoe_builder 32"; end
  end
  -- moonfire_cat,target_if=max:ticks_gained_on_refresh,if=variable.need_bt&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (VarNeedBT and BTBuffDown(S.LIMoonfire)) then
    if Everyone.CastTargetIf(S.LIMoonfire, Enemies8y, "max", EvaluateTargetIfFilterLIMoonfire, nil, not Target:IsInRange(40)) then return "moonfire_cat aoe_builder 34"; end
  end
  -- rake,target_if=max:ticks_gained_on_refresh,if=buff.sudden_ambush.up&variable.need_bt&buff.bt_rake.down
  if S.Rake:IsReady() and (Player:BuffUp(S.SuddenAmbushBuff) and VarNeedBT and BTBuffDown(S.Rake)) then
    if Everyone.CastTargetIf(S.Rake, Enemies8y, "max", EvaluateTargetIfFilterRakeAoEBuilder, nil, not IsInMeleeRange) then return "rake aoe_builder 36"; end
  end
  -- shred,if=variable.need_bt&buff.bt_shred.down&!variable.easy_swipe
  if S.Shred:IsReady() and (VarNeedBT and BTBuffDown(S.Shred) and not VarEasySwipe) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred aoe_builder 38"; end
  end
  -- rake,target_if=dot.rake.pmultiplier<1.6,if=variable.need_bt&buff.bt_rake.down
  if S.Rake:IsReady() and (VarNeedBT and BTBuffDown(S.Rake)) then
    if Everyone.CastCycle(S.Rake, EnemiesMelee, EvaluateCycleRakeAoeBuilder, not IsInMeleeRange) then return "rake aoe_builder 40"; end
  end
  -- thrash_cat,if=variable.need_bt&buff.bt_shred.down
  if S.ThrashCat:IsReady() and (VarNeedBT and BTBuffDown(S.Shred)) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash aoe_builder 42"; end
  end
end

local function Builder()
  -- prowl,if=gcd.remains=0&energy>=35&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!(variable.need_bt&buff.bt_rake.up)&buff.tigers_fury.up&!buff.shadowmeld.up
  if S.Prowl:IsReady() and not Player:StealthUp(false, true) and (Player:Energy() >= 35 and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and not (VarNeedBT and BTBuffUp(S.Rake)) and Player:BuffUp(S.TigersFury)) then
    if Cast(S.Prowl) then return "prowl builder 2"; end
  end
  -- shadowmeld,if=gcd.remains=0&energy>=35&!buff.sudden_ambush.up&(dot.rake.refreshable|dot.rake.pmultiplier<1.4)&!(variable.need_bt&buff.bt_rake.up)&buff.tigers_fury.up&!buff.prowl.up
  if S.Shadowmeld:IsCastable() and not Player:StealthUp(false, true) and (Player:Energy() >= 35 and Player:BuffDown(S.SuddenAmbushBuff) and (Target:DebuffRefreshable(S.RakeDebuff) or Target:PMultiplier(S.Rake) < 1.4) and not (VarNeedBT and BTBuffUp(S.Rake)) and Player:BuffUp(S.TigersFury)) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "shadowmeld builder 4"; end
  end
  -- rake,if=((refreshable&persistent_multiplier>=dot.rake.pmultiplier|dot.rake.remains<3.5)|buff.sudden_ambush.up&persistent_multiplier>dot.rake.pmultiplier)&!(variable.need_bt&buff.bt_rake.up)&(hero_tree.wildstalker|!buff.bs_inc.up)
  if S.Rake:IsReady() and (((Target:DebuffRefreshable(S.RakeDebuff) and Player:PMultiplier(S.Rake) >= Target:PMultiplier(S.Rake) or Target:DebuffRemains(S.RakeDebuff) < 3.5) or Player:BuffUp(S.SuddenAmbushBuff) and Player:PMultiplier(S.Rake) > Target:PMultiplier(S.Rake)) and not (VarNeedBT and BTBuffUp(S.Rake)) and (Player:HeroTreeID() == 22 or Player:BuffDown(BsInc))) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 6"; end
  end
  -- shred,if=buff.sudden_ambush.up&buff.bs_inc.up&!(variable.need_bt&buff.bt_shred.up&active_bt_triggers=2)
  if S.Shred:IsReady() and (Player:BuffUp(S.SuddenAmbushBuff) and Player:BuffUp(BsInc) and not (VarNeedBT and BTBuffUp(S.Shred) and CountActiveBtTriggers() == 2)) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 8"; end
  end
  -- brutal_slash,if=cooldown.brutal_slash.full_recharge_time<4&!(variable.need_bt&buff.bt_swipe.up)
  if S.BrutalSlash:IsReady() and (S.BrutalSlash:FullRechargeTime() < 4 and not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 10"; end
  end
  -- moonfire_cat,if=refreshable
  if S.LIMoonfire:IsReady() and (Target:DebuffRefreshable(S.LIMoonfireDebuff)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsInRange(40)) then return "moonfire_cat builder 12"; end
  end
  -- thrash_cat,if=refreshable&!talent.thrashing_claws&!buff.bs_inc.up
  if S.ThrashCat:IsCastable() and (Target:DebuffRefreshable(S.ThrashCatDebuff) and not S.ThrashingClaws:IsAvailable() and Player:BuffDown(BsInc)) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash builder 14"; end
  end
  -- shred,if=buff.clearcasting.react&!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and (Player:BuffUp(S.Clearcasting) and not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 16"; end
  end
  -- pool_resource,if=variable.dot_refresh_soon&energy.deficit>70&!variable.need_bt&!buff.bs_inc.up&cooldown.tigers_fury.remains>3
  -- TODO
  -- brutal_slash,if=!(variable.need_bt&buff.bt_swipe.up)
  if S.BrutalSlash:IsReady() and (not (VarNeedBT and BTBuffUp(S.Swipe))) then
    if Cast(S.BrutalSlash, nil, nil, not IsInAoERange) then return "brutal_slash builder 18"; end
  end
  -- shred,if=!(variable.need_bt&buff.bt_shred.up)
  if S.Shred:IsReady() and (not (VarNeedBT and BTBuffUp(S.Shred))) then
    if Cast(S.Shred, nil, nil, not IsInMeleeRange) then return "shred builder 20"; end
  end
  -- rake,if=refreshable
  if S.Rake:IsReady() and (Target:DebuffRefreshable(S.RakeDebuff)) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 22"; end
  end
  -- thrash_cat,if=refreshable&!talent.thrashing_claws
  if S.ThrashCat:IsReady() and (Target:DebuffRefreshable(S.ThrashCatDebuff) and not S.ThrashingClaws:IsAvailable()) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash builder 24"; end
  end
  -- swipe_cat,if=variable.need_bt&buff.bt_swipe.down
  if S.Swipe:IsReady() and (VarNeedBT and BTBuffDown(S.Swipe)) then
    if Cast(S.Swipe, nil, nil, not IsInAoERange) then return "swipe builder 26"; end
  end
  -- rake,if=variable.need_bt&buff.bt_rake.down&persistent_multiplier>=dot.rake.pmultiplier
  if S.Rake:IsReady() and (VarNeedBT and BTBuffDown(S.Rake) and Player:PMultiplier(S.Rake) >= Target:PMultiplier(S.Rake)) then
    if Cast(S.Rake, nil, nil, not IsInMeleeRange) then return "rake builder 28"; end
  end
  -- moonfire_cat,if=variable.need_bt&buff.bt_moonfire.down
  if S.LIMoonfire:IsReady() and (VarNeedBT and BTBuffDown(S.LIMoonfire)) then
    if Cast(S.LIMoonfire, nil, nil, not Target:IsInRange(40)) then return "moonfire_cat builder 30"; end
  end
  -- thrash_cat,if=variable.need_bt&buff.bt_thrash.down
  if S.ThrashCat:IsCastable() and (VarNeedBT and BTBuffDown(S.ThrashCat)) then
    if Cast(S.ThrashCat, nil, nil, not IsInAoERange) then return "thrash builder 32"; end
  end
end

local function Cooldown()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=trinket.1.has_use_damage&(trinket.2.cooldown.remains>20&(!trinket.1.is.junkmaestros_mega_magnet|cooldown.bestinslots.remains>20|!equipped.bestinslots)|!trinket.2.has_use_buff&(cooldown.bestinslots.remains>20|!equipped.bestinslots)|cooldown.tigers_fury.remains<25&cooldown.tigers_fury.remains>20)|fight_remains<5
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (Trinket1:HasUseDamage() and (Trinket2:CooldownRemains() > 20 and (VarTrinket1ID ~= I.JunkmaestrosMegaMagnet:ID() or I.BestinSlotsMelee:CooldownRemains() > 20 or not I.BestinSlotsMelee:IsEquipped()) or not Trinket2:HasUseBuff() and (I.BestinSlotsMelee:CooldownRemains() > 20 or not I.BestinSlotsMelee:IsEquipped()) or S.TigersFury:CooldownRemains() < 25 and S.TigersFury:CooldownRemains() > 20) or BossFightRemains < 5) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for "..Trinket1:Name().." cooldown 2"; end
    end
    -- use_item,slot=trinket2,if=trinket.2.has_use_damage&(trinket.1.cooldown.remains>20&(!trinket.2.is.junkmaestros_mega_magnet|cooldown.bestinslots.remains>20|!equipped.bestinslots)|!trinket.1.has_use_buff&(cooldown.bestinslots.remains>20|!equipped.bestinslots)|cooldown.tigers_fury.remains<25&cooldown.tigers_fury.remains>20)|fight_remains<5
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (Trinket2:HasUseDamage() and (Trinket1:CooldownRemains() > 20 and (VarTrinket2ID ~= I.JunkmaestrosMegaMagnet:ID() or I.BestinSlotsMelee:CooldownRemains() > 20 or not I.BestinSlotsMelee:IsEquipped()) or not Trinket1:HasUseBuff() and (I.BestinSlotsMelee:CooldownRemains() > 20 or not I.BestinSlotsMelee:IsEquipped()) or S.TigersFury:CooldownRemains() < 25 and S.TigersFury:CooldownRemains() > 20) or BossFightRemains < 5) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for "..Trinket2:Name().." cooldown 4"; end
    end
  end
  -- incarnation,if=buff.tigers_fury.up&!variable.holdBerserk
  if S.Incarnation:IsReady() and (Player:BuffUp(S.TigersFury) and not VarHoldBerserk) then
    if Cast(S.Incarnation, Settings.Feral.GCDasOffGCD.BsInc) then return "incarnation cooldown 6"; end
  end
  -- berserk,if=buff.tigers_fury.up&!variable.holdBerserk
  if S.Berserk:IsReady() and (Player:BuffUp(S.TigersFury) and not VarHoldBerserk) then
    if Cast(S.Berserk, Settings.Feral.GCDasOffGCD.BsInc) then return "berserk cooldown 8"; end
  end
  -- berserking,if=buff.bs_inc.up
  if S.Berserking:IsCastable() and (Player:BuffUp(BsInc)) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cooldown 10"; end
  end
  -- potion,if=buff.bs_inc.up|fight_remains<32|buff.tigers_fury.up&!variable.holdPot
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(BsInc) or FightRemains < 32 or Player:BuffUp(S.TigersFury) and not VarHoldPot) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldown 12"; end
    end
  end
  -- use_items
  if Settings.Commons.Enabled.Items then
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse and ItemToUse:IsReady() then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_item for " .. ItemToUse:Name() .. " cooldown 14"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,use_off_gcd=1,if=(time>10|buff.bs_inc.up)&trinket.1.has_use_buff&(cooldown.tigers_fury.remains>=25|(trinket.1.is.treacherous_transmitter|trinket.1.is.imperfect_ascendancy_serum)&cooldown.tigers_fury.remains<2)&(buff.potion.up|variable.slot1CountRemaining!=variable.potCountRemaining)&(cooldown.bs_inc.remains<5&!variable.holdBerserk|cooldown.convoke_the_spirits.remains<10&!variable.holdConvoke|variable.lowestCDremaining>trinket.1.cooldown.duration|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&(variable.highestCDremaining+3)>trinket.1.cooldown.duration|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.bs_inc.remains<?cooldown.convoke_the_spirits.remains)>trinket.1.cooldown.duration|variable.slot1CountRemaining=variable.potCountRemaining-1&buff.potion.up|trinket.2.has_use_buff&(variable.secondLowestCDremaining>trinket.1.cooldown.duration&variable.lowestCDremaining>trinket.2.cooldown.remains|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&variable.highestCDremaining>trinket.2.cooldown.remains|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.convoke_the_spirits.remains<?cooldown.bs_inc.remains)>trinket.2.cooldown.remains))
    local Potion = Everyone.PotionSelected()
    local PotionUp = Potion and Potion:TimeSinceLastCast() < 30 or not Settings.Commons.Enabled.Potions
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and ((HL.CombatTime() > 10 or Player:BuffUp(BsInc)) and Trinket1:HasUseBuff() and (S.TigersFury:CooldownRemains() >= 25 or (VarTrinket1ID == I.TreacherousTransmitter:ID() or VarTrinket1ID == I.ImperfectAscendancySerum:ID()) and S.TigersFury:CooldownRemains() < 2) and (PotionUp or VarSlot1CountRemaining ~= VarPotCountRemaining) and (BsInc:CooldownRemains() < 5 and not VarHoldBerserk or S.ConvoketheSpirits:CooldownRemains() < 10 and not VarHoldConvoke or VarLowestCDRemaining > VarTrinket1CD or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and (VarHighestCDRemaining + 3) > VarTrinket1CD or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(BsInc:CooldownRemains(), S.ConvoketheSpirits:CooldownRemains()) > VarTrinket1CD or VarSlot1CountRemaining  == VarPotCountRemaining - 1 and PotionUp or Trinket2:HasUseBuff() and (VarSecondLowestCDRemaining > VarTrinket1CD and VarLowestCDRemaining > Trinket2:CooldownRemains() or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and VarHighestCDRemaining > Trinket2:CooldownRemains() or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains()) > Trinket2:CooldownRemains()))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 cooldown 16"; end
    end
    -- use_item,slot=trinket2,use_off_gcd=1,if=(time>10|buff.bs_inc.up)&trinket.2.has_use_buff&(cooldown.tigers_fury.remains>=25|(trinket.2.is.treacherous_transmitter|trinket.2.is.imperfect_ascendancy_serum)&cooldown.tigers_fury.remains<2)&(buff.potion.up|variable.slot2CountRemaining!=variable.potCountRemaining)&(cooldown.bs_inc.remains<5&!variable.holdBerserk|cooldown.convoke_the_spirits.remains<10&!variable.holdConvoke|variable.lowestCDremaining>trinket.2.cooldown.duration|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&(variable.highestCDremaining+3)>trinket.2.cooldown.duration|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.bs_inc.remains<?cooldown.convoke_the_spirits.remains)>trinket.2.cooldown.duration|variable.slot1CountRemaining=variable.potCountRemaining-1&buff.potion.up|trinket.1.has_use_buff&(variable.secondLowestCDremaining>trinket.2.cooldown.duration&variable.lowestCDremaining>trinket.1.cooldown.remains|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&variable.highestCDremaining>trinket.1.cooldown.remains|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.convoke_the_spirits.remains<?cooldown.bs_inc.remains)>trinket.1.cooldown.remains))
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and ((HL.CombatTime() > 10 or Player:BuffUp(BsInc)) and Trinket2:HasUseBuff() and (S.TigersFury:CooldownRemains() >= 25 or (VarTrinket2ID == I.TreacherousTransmitter:ID() or VarTrinket2ID == I.ImperfectAscendancySerum:ID()) and S.TigersFury:CooldownRemains() < 2) and (PotionUp or VarSlot2CountRemaining ~= VarPotCountRemaining) and (BsInc:CooldownRemains() < 5 and not VarHoldBerserk or S.ConvoketheSpirits:CooldownRemains() < 10 and not VarHoldConvoke or VarLowestCDRemaining > VarTrinket2CD or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and (VarHighestCDRemaining + 3) > VarTrinket2CD or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(BsInc:CooldownRemains(), S.ConvoketheSpirits:CooldownRemains()) > VarTrinket2CD or VarSlot1CountRemaining  == VarPotCountRemaining - 1 and PotionUp or Trinket1:HasUseBuff() and (VarSecondLowestCDRemaining > VarTrinket2CD and VarLowestCDRemaining > Trinket1:CooldownRemains() or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and VarHighestCDRemaining > Trinket1:CooldownRemains() or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains()) > Trinket1:CooldownRemains()))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 cooldown 18"; end
    end
    -- use_item,slot=trinket1,if=fight_remains<=20
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (BossFightRemains <= 20) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 cooldown 20"; end
    end
    -- use_item,slot=trinket2,if=fight_remains<=20
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (BossFightRemains <= 20) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 cooldown 22"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,name=bestinslots,use_off_gcd=1,if=(time>10|buff.bs_inc.up)&cooldown.tigers_fury.remains>=25&(cooldown.bs_inc.remains<5&!variable.holdBerserk|cooldown.convoke_the_spirits.remains<10&!variable.holdConvoke|variable.lowestCDremaining>cooldown.bestinslots.duration|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&(variable.highestCDremaining+3)>cooldown.bestinslots.duration|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.bs_inc.remains<?cooldown.convoke_the_spirits.remains)>cooldown.bestinslots.duration|trinket.2.has_use_buff&((variable.secondLowestCDremaining>cooldown.bestinslots.duration|variable.secondLowestCDremaining>trinket.1.cooldown.remains)&variable.lowestCDremaining>trinket.2.cooldown.remains|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&variable.highestCDremaining>trinket.2.cooldown.remains|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.convoke_the_spirits.remains<?cooldown.bs_inc.remains)>trinket.2.cooldown.remains)|trinket.1.has_use_buff&((variable.secondLowestCDremaining>cooldown.bestinslots.duration|variable.secondLowestCDremaining>trinket.2.cooldown.remains)&variable.lowestCDremaining>trinket.1.cooldown.remains|variable.zerkCountRemaining=1&variable.convokeCountRemaining=1&variable.potCountRemaining=1&variable.highestCDremaining>trinket.1.cooldown.remains|variable.zerkCountRemaining=variable.convokeCountRemaining&variable.zerkCountRemaining!=variable.potCountRemaining&(cooldown.convoke_the_spirits.remains<?cooldown.bs_inc.remains)>trinket.1.cooldown.remains))
    if I.BestinSlotsMelee:IsReady() and ((HL.CombatTime() > 10 or Player:BuffUp(BsInc)) and S.TigersFury:CooldownRemains() >= 25 and (BsInc:CooldownRemains() < 5 and not VarHoldBerserk or S.ConvoketheSpirits:CooldownRemains() < 10 and not VarHoldConvoke or VarLowestCDRemaining > 120 or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and (VarHighestCDRemaining + 3) > 120 or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(BsInc:CooldownRemains(), S.ConvoketheSpirits:CooldownRemains()) > 120 or Trinket2:HasUseBuff() and ((VarSecondLowestCDRemaining > 120 or VarSecondLowestCDRemaining > Trinket1:CooldownRemains()) 
    and VarLowestCDRemaining > Trinket2:CooldownRemains() or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and VarHighestCDRemaining > Trinket2:CooldownRemains() or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains()) > Trinket2:CooldownRemains()) or Trinket1:HasUseBuff() and ((VarSecondLowestCDRemaining > 120 or VarSecondLowestCDRemaining > Trinket2:CooldownRemains()) and VarLowestCDRemaining > Trinket1:CooldownRemains() or VarZerkCountRemaining == 1 and VarConvokeCountRemaining == 1 and VarPotCountRemaining == 1 and VarHighestCDRemaining > Trinket1:CooldownRemains() or VarZerkCountRemaining == VarConvokeCountRemaining and VarZerkCountRemaining ~= VarPotCountRemaining and mathmax(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains()) > Trinket1:CooldownRemains()))) then
      if Cast(I.BestinSlotsMelee, nil, Settings.CommonsDS.DisplayStyle.Items) then return "bestinslots cooldown 24"; end
    end
    -- use_item,name=bestinslots,use_off_gcd=1,if=fight_remains<=20
    if I.BestinSlotsMelee:IsReady() and (BossFightRemains <= 20) then
      if Cast(I.BestinSlotsMelee, nil, Settings.CommonsDS.DisplayStyle.Items) then return "bestinslots cooldown 26"; end
    end
  end
  -- do_treacherous_transmitter_task,if=buff.tigers_fury.up|fight_remains<22
  -- feral_frenzy,if=combo_points<=1+buff.bs_inc.up&(buff.tigers_fury.up|!talent.savage_fury|!hero_tree.wildstalker|fight_remains<cooldown.tigers_fury.remains)
  if S.FeralFrenzy:IsReady() and (ComboPoints <= 1 + num(Player:BuffUp(BsInc)) and (Player:BuffUp(S.TigersFury) or not S.SavageFury:IsAvailable() or Player:HeroTreeID() ~= 22 or BossFightRemains < S.TigersFury:CooldownRemains())) then
    if Cast(S.FeralFrenzy, Settings.Feral.GCDasOffGCD.FeralFrenzy, nil, not IsInMeleeRange) then return "feral_frenzy cooldown 28"; end
  end
  -- convoke_the_spirits,if=fight_remains<5|buff.bs_inc.up&buff.bs_inc.remains<5-talent.ashamanes_guidance|buff.tigers_fury.up&!variable.holdConvoke&(combo_points<=4|buff.bs_inc.up&combo_points<=3)
  if S.ConvoketheSpirits:IsCastable() and (BossFightRemains < 5 or Player:BuffUp(BsInc) and Player:BuffRemains(BsInc) < 5 - num(S.AshamanesGuidance:IsAvailable()) or Player:BuffUp(S.TigersFury) and not VarHoldConvoke and (ComboPoints <= 4 or Player:BuffUp(BsInc) and ComboPoints <= 3)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.CommonsDS.DisplayStyle.ConvokeTheSpirits, not IsInMeleeRange) then return "convoke_the_spirits cooldown 30"; end
  end
end

local function Finisher()
  -- primal_wrath,target_if=max:dot.bloodseeker_vines.ticking,if=spell_targets.primal_wrath>1&((dot.primal_wrath.remains<6.5&!buff.bs_inc.up|dot.primal_wrath.refreshable)|(!talent.rampant_ferocity.enabled&(spell_targets.primal_wrath>1&!dot.bloodseeker_vines.ticking&!buff.ravage.up|spell_targets.primal_wrath>6+talent.ravage)))
  if S.PrimalWrath:IsReady() and (EnemiesCount8y > 1) then
    if Everyone.CastTargetIf(S.PrimalWrath, Enemies8y, "max", EvaluateTargetIfFilterBloodseeker, EvaluateTargetIfPrimalWrath, not IsInAoERange) then return "primal_wrath finisher 2"; end
  end
  -- rip,target_if=refreshable,if=(!talent.primal_wrath|spell_targets=1)&(buff.bloodtalons.up|!talent.bloodtalons)&(buff.tigers_fury.up|dot.rip.remains<cooldown.tigers_fury.remains)&(remains<fight_remains|remains<4&buff.ravage.up)
  if S.Rip:IsReady() and ((not S.PrimalWrath:IsAvailable() or EnemiesCountMelee == 1) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable())) then
    if Everyone.CastCycle(S.Rip, EnemiesMelee, EvaluateCycleRip2, not IsInMeleeRange) then return "rip finisher 4"; end
  end
  -- pool_resource,for_next=1
  -- ferocious_bite,max_energy=1,target_if=max:dot.bloodseeker_vines.ticking,if=!buff.bs_inc.up
  -- TODO: Determine a way to do both pool_resource and target_if together.
  if BiteFinisher:IsReady() and (Player:BuffDown(BsInc)) then
    if CastPooling(BiteFinisher, Player:EnergyTimeToX(50)) then return "ferocious_bite finisher 6"; end
  end
  -- pool_resource,for_next=1
  -- ferocious_bite,target_if=max:dot.bloodseeker_vines.ticking
  if BiteFinisher:IsReady() then
    if Everyone.CastTargetIf(BiteFinisher, EnemiesMelee, "max", EvaluateTargetIfFilterBloodseeker, nil, not IsInMeleeRange) then return "ferocious_bite finisher 8"; end
  end
end

local function Variables()
  -- variable,name=convokeCountRemaining,value=floor(((fight_remains-variable.convoke_cd)%cooldown.convoke_the_spirits.duration)+(fight_remains>cooldown.convoke_the_spirits.remains))
  local ConvokeCD = S.AshamanesGuidance:IsAvailable() and 60 or 120
  VarConvokeCountRemaining = mathfloor(((FightRemains - VarConvokeCD) / ConvokeCD) + num(FightRemains > S.ConvoketheSpirits:CooldownRemains()))
  -- variable,name=zerkCountRemaining,value=floor(((fight_remains-variable.bs_inc_cd)%cooldown.bs_inc.duration)+(fight_remains>cooldown.bs_inc.remains))
  local BsIncCD = S.BerserkHeartoftheLion:IsAvailable() and 120 or 180
  VarZerkCountRemaining = mathfloor(((FightRemains - VarBsIncCD) / BsIncCD) + num(FightRemains > BsInc:CooldownRemains()))
  -- variable,name=potCountRemaining,value=floor(((fight_remains-variable.pot_cd)%cooldown.potion.duration)+(fight_remains>cooldown.potion.remains))
  local PotionSelected = Everyone.PotionSelected()
  local PotCDRemains = PotionSelected and PotionSelected:CooldownRemains() or 0
  VarPotCountRemaining = mathfloor(((FightRemains - VarPotCD) / 300) + num(FightRemains > PotCDRemains))
  -- variable,name=slot1CountRemaining,value=floor(((fight_remains-trinket.1.cooldown.remains-10)%trinket.1.cooldown.duration)+(fight_remains>trinket.1.cooldown.remains))
  VarSlot1CountRemaining = mathfloor(((FightRemains - Trinket1:CooldownRemains() - 10) / VarTrinket1CD) + num(FightRemains > Trinket1:CooldownRemains()))
  -- variable,name=slot2CountRemaining,value=floor(((fight_remains-trinket.2.cooldown.remains-10)%trinket.2.cooldown.duration)+(fight_remains>trinket.2.cooldown.remains))
  VarSlot2CountRemaining = mathfloor(((FightRemains - Trinket2:CooldownRemains() - 10) / VarTrinket2CD) + num(FightRemains > Trinket2:CooldownRemains()))
  -- variable,name=firstHoldBerserkCondition,value=variable.zerkCountRemaining=1&(variable.convokeCountRemaining=1&cooldown.convoke_the_spirits.remains>10|variable.potCountRemaining=1&cooldown.potion.remains)
  VarFirstHoldBerserkCondition = VarZerkCountRemaining == 1 and (VarConvokeCountRemaining == 1 and S.ConvoketheSpirits:CooldownRemains() > 10 or VarPotCountRemaining == 1 and PotCDRemains > 0)
  -- variable,name=secondHoldBerserkCondition,value=cooldown.convoke_the_spirits.remains>20&variable.convokeCountRemaining=variable.zerkCountRemaining&variable.zerkCountRemaining=floor(((fight_remains-variable.convoke_cd)%cooldown.bs_inc.duration)+(fight_remains>cooldown.convoke_the_spirits.remains))
  VarSecondHoldBerserkCondition = S.ConvoketheSpirits:CooldownRemains() > 20 and VarConvokeCountRemaining == VarZerkCountRemaining and VarZerkCountRemaining == mathfloor(((FightRemains - VarConvokeCD) / BsIncCD) + num(FightRemains > S.ConvoketheSpirits:CooldownRemains()))
  -- variable,name=holdBerserk,value=variable.firstHoldBerserkCondition|variable.secondHoldBerserkCondition
  VarHoldBerserk = VarFirstHoldBerserkCondition or VarSecondHoldBerserkCondition
  -- variable,name=holdConvoke,value=variable.convokeCountRemaining=1&variable.zerkCountRemaining=1&!buff.bs_inc.up
  VarHoldConvoke = VarConvokeCountRemaining == 1 and VarZerkCountRemaining == 1 and Player:BuffDown(BsInc)
  -- variable,name=holdPot,value=variable.potCountRemaining=floor(((fight_remains-variable.bs_inc_cd)%cooldown.potion.duration)+(fight_remains>cooldown.bs_inc.remains))
  VarHoldPot = VarPotCountRemaining == mathfloor(((FightRemains - VarBsIncCD) / 300) + num(FightRemains > BsInc:CooldownRemains()))
  -- variable,name=bs_inc_cd,value=cooldown.bs_inc.remains+10
  VarBsIncCD = BsInc:CooldownRemains() + 10
  -- variable,name=convoke_cd,value=cooldown.convoke_the_spirits.remains+10
  VarConvokeCD = S.ConvoketheSpirits:CooldownRemains() + 10
  -- variable,name=pot_cd,value=cooldown.potion.remains+25
  VarPotCD = PotCDRemains + 25
  -- variable,name=highestCDremaining,value=cooldown.convoke_the_spirits.remains<?cooldown.bs_inc.remains<?cooldown.potion.remains
  VarHighestCDRemaining = mathmax(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains(), PotCDRemains)
  -- variable,name=lowestCDremaining,value=cooldown.convoke_the_spirits.remains>?cooldown.bs_inc.remains>?cooldown.potion.remains
  VarLowestCDRemaining = mathmin(S.ConvoketheSpirits:CooldownRemains(), BsInc:CooldownRemains(), PotCDRemains)
  -- variable,name=secondLowestCDremaining,op=setif,condition=cooldown.convoke_the_spirits.remains>cooldown.bs_inc.remains,value=cooldown.convoke_the_spirits.remains>?cooldown.potion.remains,value_else=cooldown.bs_inc.remains>?cooldown.potion.remains
  if S.ConvoketheSpirits:CooldownRemains() > BsInc:CooldownRemains() then
    VarSecondLowestCDRemaining = mathmin(S.ConvoketheSpirits:CooldownRemains(), PotCDRemains)
  else
    VarSecondLowestCDRemaining = mathmin(BsInc:CooldownRemains(), PotCDRemains)
  end
  -- variable,name=rip_max_pandemic_duration,value=((4+(4*combo_points))*(1-(0.2*talent.circle_of_life_and_death))*(1+(0.25*talent.veinripper)))*0.3
  -- Note: Moved above rip_duration, as this variable is used in defining that variable and causes an error otherwise.
  VarRipMaxPandemicDuration = ((4 + (4 * ComboPoints)) * (1 - (0.2 * num(S.CircleofLifeandDeath:IsAvailable()))) * (1 + (0.25 * num(S.Veinripper:IsAvailable())))) * 0.3
  -- variable,name=rip_duration,value=((4+(4*combo_points))*(1-(0.2*talent.circle_of_life_and_death))*(1+(0.25*talent.veinripper)))+(variable.rip_max_pandemic_duration>?dot.rip.remains)
  VarRipDuration = ((4 + (4 * ComboPoints)) * (1 - (0.2 * num(S.CircleofLifeandDeath:IsAvailable()))) * (1 + (0.25 * num(S.Veinripper:IsAvailable())))) + mathmin(VarRipMaxPandemicDuration, Target:DebuffRemains(S.RipDebuff))
  -- variable,name=dot_refresh_soon,value=(!talent.thrashing_claws&(dot.thrash_cat.remains-dot.thrash_cat.duration*0.3<=2))|(talent.lunar_inspiration&(dot.moonfire_cat.remains-dot.moonfire_cat.duration*0.3<=2))|((dot.rake.pmultiplier<1.6|buff.sudden_ambush.up)&(dot.rake.remains-dot.rake.duration*0.3<=2))
  -- TODO: Variable is currently only used in a single 0.2s pool, so we're ignoring it for now.
  -- variable,name=need_bt,value=talent.bloodtalons&buff.bloodtalons.stack<=1
  VarNeedBT = S.Bloodtalons:IsAvailable() and Player:BuffStack(S.BloodtalonsBuff) <= 1
  -- variable,name=cc_capped,value=buff.clearcasting.stack=(1+talent.moment_of_clarity)
  VarCCCapped = Player:BuffStack(S.Clearcasting) == (1 + num(S.MomentofClarity:IsAvailable()))
  -- variable,name=regrowth,op=reset
  VarRegrowth = Settings.Feral.ShowHealSpells and Player:HealthPercentage() <= Settings.Feral.HealThreshold
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

    -- Bite Finisher to handle DotC's Ravage
    if Player:HeroTreeID() == 21 then
      BiteFinisher = S.RavageAbilityCat:IsLearned() and S.RavageAbilityCat or S.FerociousBite
    else
      BiteFinisher = S.FerociousBite
    end
  end

  -- cat_form OOC, if setting is true
  if S.CatForm:IsCastable() and not Player:AffectingCombat() and Settings.Feral.ShowCatFormOOC then
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
    if S.Prowl:IsReady() and (Player:BuffDown(BsInc) or not Player:AffectingCombat()) then
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
    -- tigers_fury,if=(energy.deficit>35|combo_points=5|combo_points>=3&dot.rip.refreshable&buff.bloodtalons.up&hero_tree.wildstalker)&(fight_remains<=15|(cooldown.bs_inc.remains>20&target.time_to_die>5)|(cooldown.bs_inc.ready&target.time_to_die>12|target.time_to_die=fight_remains))
    if S.TigersFury:IsCastable() and ((Player:EnergyDeficit() > 35 or ComboPoints == 5 or ComboPoints >= 3 and Target:DebuffRefreshable(S.RipDebuff) and Player:BuffUp(S.BloodtalonsBuff) and Player:HeroTreeID() == 22) and (BossFightRemains <= 15 or (BsInc:CooldownRemains() > 20 and Target:TimeToDie() > 5) or (BsInc:CooldownUp() and Target:TimeToDie() > 12 or Target:TimeToDie() == FightRemains))) then
      if Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "tigers_fury main 6"; end
    end
    -- rake,target_if=max:refreshable+(persistent_multiplier>dot.rake.pmultiplier),if=buff.shadowmeld.up|buff.prowl.up
    if S.Rake:IsReady() and (Player:StealthUp(false, true)) then
      if Everyone.CastTargetIf(S.Rake, EnemiesMelee, "max", EvaluateTargetIfFilterRakeMain, nil, not IsInAoERange) then return "rake main 8"; end
    end
    -- natures_vigil,if=spell_targets.swipe_cat>0&variable.regrowth
    if S.NaturesVigil:IsCastable() and (EnemiesCount8y > 0 and VarRegrowth) then
      if Cast(S.NaturesVigil, Settings.Feral.OffGCDasOffGCD.NaturesVigil) then return "natures_vigil main 10"; end
    end
    -- renewal,if=spell_targets.swipe_cat>0&variable.regrowth
    if S.Renewal:IsCastable() and (EnemiesCount8y > 0 and VarRegrowth) then
      if Cast(S.Renewal, Settings.Feral.GCDasOffGCD.Renewal) then return "renewal main 12"; end
    end
    -- adaptive_swarm,target_if=dot.adaptive_swarm_damage.stack<3&(!dot.adaptive_swarm_damage.ticking|dot.adaptive_swarm_damage.remains<2),if=!action.adaptive_swarm_damage.in_flight&(spell_targets=1|!talent.unbridled_swarm)&(dot.rip.ticking|hero_tree.druid_of_the_claw)
    if S.AdaptiveSwarm:IsReady() and (not S.AdaptiveSwarm:InFlight() and (EnemiesCount8y == 1 or not S.UnbridledSwarm:IsAvailable())) then
      if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8y, EvaluateCycleAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.CommonsDS.DisplayStyle.AdaptiveSwarm) then return "adaptive_swarm main 14"; end
    end
    -- adaptive_swarm,target_if=max:(1+dot.adaptive_swarm_damage.stack)*dot.adaptive_swarm_damage.stack<3*time_to_die,if=buff.cat_form.up&dot.adaptive_swarm_damage.stack<3&talent.unbridled_swarm.enabled&spell_targets.swipe_cat>1&dot.rip.ticking
    if S.AdaptiveSwarm:IsReady() and (Player:BuffUp(S.CatForm) and S.UnbridledSwarm:IsAvailable() and EnemiesCount8y > 1) then
      if Everyone.CastTargetIf(S.AdaptiveSwarm, Enemies8y, "max", EvaluateTargetIfFilterAdaptiveSwarm, EvaluateTargetIfAdaptiveSwarm, not Target:IsSpellInRange(S.AdaptiveSwarm), nil, Settings.CommonsDS.DisplayStyle.AdaptiveSwarm) then return "adaptive_swarm main 16"; end
    end
    -- ferocious_bite,if=buff.apex_predators_craving.up&!(variable.need_bt&active_bt_triggers=2)
    if BiteFinisher:IsReady() and (Player:BuffUp(S.ApexPredatorsCravingBuff) and not (VarNeedBT and CountActiveBtTriggers() == 2)) then
      if Cast(BiteFinisher, nil, nil, not IsInMeleeRange) then return "ferocious_bite main 18"; end
    end
    -- call_action_list,name=cooldown,if=dot.rip.ticking
    if CDsON() and Target:DebuffUp(S.RipDebuff) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- rip,if=talent.veinripper&spell_targets=1&hero_tree.wildstalker&!(talent.raging_fury&talent.veinripper)&(buff.bloodtalons.up|!talent.bloodtalons)&(dot.rip.remains<5&buff.tigers_fury.remains>10&combo_points>=3|((buff.tigers_fury.remains<3&combo_points=5)|buff.tigers_fury.remains<=1)&buff.tigers_fury.up&combo_points>=3&remains<cooldown.tigers_fury.remains)
    -- rip,if=!talent.veinripper&spell_targets=1&hero_tree.wildstalker&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons)&(combo_points>=3&refreshable&cooldown.tigers_fury.remains>25|buff.tigers_fury.remains<5&variable.rip_duration>cooldown.tigers_fury.remains&cooldown.tigers_fury.remains>=dot.rip.remains)
    -- Note: Combining both lines.
    if S.Rip:IsReady() and (
      (S.Veinripper:IsAvailable() and EnemiesCount8y == 1 and Player:HeroTreeID() == 22 and not (S.RagingFury:IsAvailable() and S.Veinripper:IsAvailable()) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (Target:DebuffRemains(S.RipDebuff) < 5 and Player:BuffRemains(S.TigersFury) > 10 and ComboPoints >= 3 or ((Player:BuffRemains(S.TigersFury) < 3 and ComboPoints == 5) or Player:BuffRemains(S.TigersFury) <= 1) and Player:BuffUp(S.TigersFury) and ComboPoints >= 3 and Target:DebuffRemains(S.RipDebuff) < S.TigersFury:CooldownRemains())) or
      (not S.Veinripper:IsAvailable() and EnemiesCount8y == 1 and Player:HeroTreeID() == 22 and Player:BuffUp(S.TigersFury) and (Player:BuffUp(S.BloodtalonsBuff) or not S.Bloodtalons:IsAvailable()) and (ComboPoints >= 3 and Target:DebuffRefreshable(S.RipDebuff) and S.TigersFury:CooldownRemains() > 25 or Player:BuffRemains(S.TigersFury) < 5 and VarRipDuration > S.TigersFury:CooldownRemains() and S.TigersFury:CooldownRemains() >= Target:DebuffRemains(S.RipDebuff)))
    ) then
      if Cast(S.Rip, nil, nil, not IsInMeleeRange) then return "rip main 20"; end
    end
    -- call_action_list,name=builder,if=(buff.bs_inc.up&!buff.ravage.up&!buff.coiled_to_spring.up&hero_tree.druid_of_the_claw&talent.coiled_to_spring&spell_targets<=2)|buff.bloodtalons.stack=0&active_bt_triggers=2
    if (Player:BuffUp(BsInc) and Player:BuffDown(S.RavageBuffFeral) and Player:BuffDown(S.CoiledtoSpringBuff) and Player:HeroTreeID() == 21 and S.CoiledtoSpring:IsAvailable() and EnemiesCount8y <= 2) or Player:BuffStack(S.BloodtalonsBuff) == 0 and CountActiveBtTriggers() == 2 then
      local ShouldReturn = Builder(); if ShouldReturn then return ShouldReturn; end
    end
    -- wait,sec=action.tigers_fury.ready,if=combo_points=5&cooldown.tigers_fury.remains<3&spell_targets=1
    if ComboPoints == 5 and S.TigersFury:CooldownRemains() < 3 and EnemiesCount8y == 1 then
      if CastPooling(S.Pool, S.TigersFury:CooldownRemains()) then return "wait for tigers_fury"; end
    end
    -- call_action_list,name=finisher,if=combo_points=5
    if ComboPoints == 5 then
      local ShouldReturn = Finisher(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=builder,if=spell_targets.swipe_cat=1&combo_points<5
    if EnemiesCount8y == 1 and ComboPoints < 5 then
      local ShouldReturn = Builder(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_builder,if=spell_targets.swipe_cat>=2&combo_points<5
    if EnemiesCount8y >= 2 and ComboPoints < 5 then
      local ShouldReturn = AoeBuilder(); if ShouldReturn then return ShouldReturn; end
    end
    -- regrowth,if=buff.predatory_swiftness.up&variable.regrowth
    if S.Regrowth:IsReady() and (Player:BuffUp(S.PredatorySwiftnessBuff) and VarRegrowth) then
      if Cast(S.Regrowth, Settings.Feral.GCDasOffGCD.Regrowth) then return "regrowth main 22"; end
    end
    -- Pool if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool Energy"; end
  end
end

local function OnInit()
  S.RipDebuff:RegisterAuraTracking()

  HR.Print("Feral Druid rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(103, APL, OnInit)
