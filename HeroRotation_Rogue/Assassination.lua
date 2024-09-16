--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
local BoolToInt = HL.Utils.BoolToInt
local IntToBool = HL.Utils.IntToBool
local ValueIsInArray = HL.Utils.ValueIsInArray
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast = HR.Cast
local CastPooling = HR.CastPooling
local CastQueue = HR.CastQueue
local CastLeftNameplate = HR.CastLeftNameplate
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local pairs = pairs
local mathfloor = math.floor
local mathmax = math.max
local mathmin = math.min
-- WoW API
local Delay = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  CommonsDS = HR.GUISettings.APL.Rogue.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Rogue.CommonsOGCD,
  Assassination = HR.GUISettings.APL.Rogue.Assassination
}

-- Spells
local S = Spell.Rogue.Assassination

-- Items
local I = Item.Rogue.Assassination
local OnUseExcludeTrinkets = {
  I.AlgetharPuzzleBox:ID(),
  I.AshesoftheEmbersoul:ID(),
  I.BottledFlayedwingToxin:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.TreacherousTransmitter:ID(),
}

-- Enemies
local MeleeRange, AoERange, TargetInMeleeRange, TargetInAoERange
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y

-- Rotation Variables
local ShouldReturn
local BleedTickTime, ExsanguinatedBleedTickTime = 2 * Player:SpellHaste(), 1 * Player:SpellHaste()
local ComboPoints, ComboPointsDeficit
local RuptureThreshold, CrimsonTempestThreshold, RuptureDMGThreshold, GarroteDMGThreshold, RuptureDurationThreshold, RuptureTickTime, GarroteTickTime
local PriorityRotation
local NotPooling, SepsisSyncRemains, PoisonedBleeds, EnergyRegenCombined, EnergyTimeToMaxCombined, EnergyRegenSaturated, SingleTarget, ScentSaturated
local TrinketSyncSlot = 0
local EffectiveCPSpend

-- Equipment
local VarTrinketFailures = 0
local function SetTrinketVariables ()
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

  TrinketItem1 = T1.Object
  TrinketItem2 = T2.Object

  -- actions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)&!trinket.2.is.witherbarks_branch|trinket.1.is.witherbarks_branch
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)&!trinket.1.is.witherbarks_branch|trinket.2.is.witherbarks_branch
  if TrinketItem1:HasStatAnyDps() and (not TrinketItem2:HasStatAnyDps() or T1.Cooldown >= T2.Cooldown) and T2.ID ~= I.WitherbarksBranch:ID() or T1.ID == I.WitherbarksBranch:ID() then
    TrinketSyncSlot = 1
  elseif TrinketItem2:HasStatAnyDps() and (not TrinketItem1:HasStatAnyDps() or T2.Cooldown > T1.Cooldown) and T1.ID ~= I.WitherbarksBranch:ID() or T2.ID == I.WitherbarksBranch:ID() then
    TrinketSyncSlot = 2
  else
    TrinketSyncSlot = 0
  end
end
SetTrinketVariables()

HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

-- Interrupts
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function()
    return true
  end },
  { S.KidneyShot, "Cast Kidney Shot (Interrupt)", function()
    return ComboPoints > 0
  end }
}

-- Spells Damage
S.Envenom:RegisterDamageFormula(
-- Envenom DMG Formula:
--  AP * CP * Env_APCoef * Aura_M * ToxicB_M * DS_M * Mastery_M * Versa_M
  function()
    return
    -- Attack Power
    Player:AttackPowerDamageMod() *
      -- Combo Points
      ComboPoints *
      -- Envenom AP Coef
      0.22 *
      -- Aura Multiplier (SpellID: 137037)
      1.0 *
      -- Shiv Multiplier
      (Target:DebuffUp(S.ShivDebuff) and 1.3 or 1) *
      -- Deeper Stratagem Multiplier
      (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
      -- Mastery Finisher Multiplier
      (1 + Player:MasteryPct() / 100) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct() / 100)
  end
)
S.Mutilate:RegisterDamageFormula(
  function()
    return
    -- Attack Power (MH Factor + OH Factor)
    (Player:AttackPowerDamageMod() + Player:AttackPowerDamageMod(true)) *
      -- Mutilate Coefficient
      0.485 *
      -- Aura Multiplier (SpellID: 137037)
      1.0 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct() / 100)
  end
)

-- Master Assassin Remains Check
local function MasterAssassinAuraUp()
  return Player:BuffRemains(S.MasterAssassinBuff) == 9999
end
local function MasterAssassinRemains ()
  -- Currently stealthed (i.e. Aura)
  if MasterAssassinAuraUp() then
    return Player:GCDRemains() + 3
  end
  -- Broke stealth recently (i.e. Buff)
  return Player:BuffRemains(S.MasterAssassinBuff)
end

-- Improved Garrote Remains Check
local function ImprovedGarroteRemains ()
  -- Currently stealthed (i.e. Aura)
  if Player:BuffUp(S.ImprovedGarroteAura) then
    return Player:GCDRemains() + 3
  end
  -- Broke stealth recently (i.e. Buff)
  return Player:BuffRemains(S.ImprovedGarroteBuff)
end

-- Indiscriminate Carnage Remains Check
local function IndiscriminateCarnageRemains ()
  -- Currently stealthed (i.e. Aura)
  if Player:BuffUp(S.IndiscriminateCarnageAura) then
    return Player:GCDRemains() + 10
  end
  -- Broke stealth recently (i.e. Buff)
  return Player:BuffRemains(S.IndiscriminateCarnageBuff)
end

--- ======= HELPERS =======
-- Check if the Priority Rotation variable should be set
local function UsePriorityRotation()
  if MeleeEnemies10yCount < 2 then
    return false
  elseif Settings.Assassination.UsePriorityRotation == "Always" then
    return true
  elseif Settings.Assassination.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  elseif Settings.Assassination.UsePriorityRotation == "Auto" then
    -- Zul Mythic
    if Player:InstanceDifficulty() == 16 and Target:NPCID() == 138967 then
      return true
    end
  end

  return false
end

-- actions+=/variable,name=not_pooling,value=(dot.deathmark.ticking|dot.kingsbane.ticking|debuff.shiv.up)
-- |(buff.envenom.up&buff.envenom.remains<=1)
-- |energy.pct>=(40+30*talent.hand_of_fate-15*talent.vicious_venoms)
-- |fight_remains<=20
local function NotPoolingVar()
  if (Target:DebuffUp(S.Deathmark) or Target:DebuffUp(S.Kingsbane) or Target:DebuffUp(S.ShivDebuff))
    or (Player:BuffUp(S.Envenom) and Player:BuffRemains(S.Envenom) <= 1)
    or Player:EnergyPercentage() >= (40 + 30 * num(S.HandOfFate:IsAvailable()) - 15 * num(S.ViciousVenoms:IsAvailable()))
    or HL.BossFilteredFightRemains("<=", 20) then
    return true
  end
  return false
end

-- actions.dot=variable,name=scent_effective_max_stacks,value=(spell_targets.fan_of_knives*talent.scent_of_blood.rank*2)>?20
-- actions.dot+=/variable,name=scent_saturation,value=buff.scent_of_blood.stack>=variable.scent_effective_max_stacks
local function ScentSaturatedVar()
  if not S.ScentOfBlood:IsAvailable() then
    return true
  end
  return Player:BuffStack(S.ScentOfBloodBuff) >= mathmin(20, S.ScentOfBlood:TalentRank() * 2 * MeleeEnemies10yCount)
end

-- Custom Override for Handling 4pc Pandemics
local function IsDebuffRefreshable(TargetUnit, Spell, PandemicThreshold)
  local PandemicThreshold = PandemicThreshold or Spell:PandemicThreshold()
  --if Tier284pcEquipped and TargetUnit:DebuffUp(S.Vendetta) then
  --  PandemicThreshold = PandemicThreshold * 0.5
  --end
  return TargetUnit:DebuffRefreshable(Spell, PandemicThreshold)
end

-- Handle CastLeftNameplate Suggestions for DoT Spells
local function SuggestCycleDoT(DoTSpell, DoTEvaluation, DoTMinTTD, Enemies)
  -- Prefer melee cycle units
  local BestUnit, BestUnitTTD = nil, DoTMinTTD
  local TargetGUID = Target:GUID()
  for _, CycleUnit in pairs(Enemies) do
    if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(DoTSpell))
      and DoTEvaluation(CycleUnit) then
      BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
    end
  end
  if BestUnit then
    CastLeftNameplate(BestUnit, DoTSpell)
    -- Check ranged units next, if the RangedMultiDoT option is enabled
  elseif Settings.Commons.RangedMultiDoT then
    BestUnit, BestUnitTTD = nil, DoTMinTTD
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(DoTSpell))
        and DoTEvaluation(CycleUnit) then
        BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
      end
    end
    if BestUnit then
      CastLeftNameplate(BestUnit, DoTSpell)
    end
  end
end

-- Target If handler
-- Mode is "min", "max", or "first"
-- ModeEval the target_if condition (function with a target as param)
-- IfEval the condition on the resulting target (function with a target as param)
local function CheckTargetIfTarget(Mode, ModeEvaluation, IfEvaluation)
  -- First mode: Only check target if necessary
  local TargetsModeValue = ModeEvaluation(Target)
  if Mode == "first" and TargetsModeValue ~= 0 then
    return Target
  end

  local BestUnit, BestValue = nil, 0
  local function RunTargetIfCycler(Enemies)
    for _, CycleUnit in pairs(Enemies) do
      local ValueForUnit = ModeEvaluation(CycleUnit)
      if not BestUnit and Mode == "first" then
        if ValueForUnit ~= 0 then
          BestUnit, BestValue = CycleUnit, ValueForUnit
        end
      elseif Mode == "min" then
        if not BestUnit or ValueForUnit < BestValue then
          BestUnit, BestValue = CycleUnit, ValueForUnit
        end
      elseif Mode == "max" then
        if not BestUnit or ValueForUnit > BestValue then
          BestUnit, BestValue = CycleUnit, ValueForUnit
        end
      end
      -- Same mode value, prefer longer TTD
      if BestUnit and ValueForUnit == BestValue and CycleUnit:TimeToDie() > BestUnit:TimeToDie() then
        BestUnit, BestValue = CycleUnit, ValueForUnit
      end
    end
  end

  -- Prefer melee cycle units over ranged
  RunTargetIfCycler(MeleeEnemies5y)
  if Settings.Commons.RangedMultiDoT then
    RunTargetIfCycler(MeleeEnemies10y)
  end
  -- Prefer current target if equal mode value results to prevent "flickering"
  if BestUnit and BestValue == TargetsModeValue and IfEvaluation(Target) then
    return Target
  end
  if BestUnit and IfEvaluation(BestUnit) then
    return BestUnit
  end
  return nil
end

--- ======= ACTION LISTS =======
local function Racials ()
  -- actions.misc_cds+=/blood_fury,if=debuff.deathmark.up
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Blood Fury"
    end
  end
  -- actions.misc_cds+=/berserking,if=debuff.deathmark.up
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Berserking"
    end
  end
  -- actions.misc_cds+=/fireblood,if=debuff.deathmark.up
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Fireblood"
    end
  end
  -- actions.misc_cds+=/ancestral_call,if=(!talent.kingsbane&debuff.deathmark.up&debuff.shiv.up)|(talent.kingsbane&debuff.deathmark.up&dot.kingsbane.ticking&dot.kingsbane.remains<8)
  if S.AncestralCall:IsCastable() then
    if (not S.Kingsbane:IsAvailable() and Target:DebuffUp(S.ShivDebuff))
      or (Target:DebuffUp(S.Kingsbane) and Target:DebuffRemains(S.Kingsbane) < 8) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
        return "Cast Ancestral Call"
      end
    end
  end

  return false
end

-- # Stealthed
local function Stealthed (ReturnSpellOnly, ForceStealth)
  -- actions.stealthed=pool_resource,for_next=1

  -- # Apply Deathstalkers Mark if it has fallen off
  -- actions.stealthed+=/ambush,if=!debuff.deathstalkers_mark.up&talent.deathstalkers_mark
  if (S.Ambush:IsReady() or ForceStealth) and Target:DebuffDown(S.DeathStalkersMarkDebuff) and S.DeathStalkersMark:IsAvailable() then
    if ReturnSpellOnly then
      return S.Ambush
    else
      if Cast(S.Ambush, nil, nil, not TargetInMeleeRange) then
        return "Cast Ambush Stealthed"
      end
    end
  end

  -- actions.stealthed+=/shiv,if=talent.kingsbane&(dot.kingsbane.ticking|cooldown.kingsbane.up)&(!debuff.shiv.up&debuff.shiv.remains<1)&buff.envenom.up
  if S.Kingsbane:IsAvailable() and Player:BuffUp(S.Envenom) then
    if S.Shiv:IsReady() and (Target:DebuffUp(S.Kingsbane) or S.Kingsbane:CooldownUp()) and Target:DebuffDown(S.ShivDebuff) then
      if ReturnSpellOnly then
        return S.Shiv
      else
        if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
          return "Cast Shiv (Stealth Kingsbane)"
        end
      end
    end
  end

  -- actions.stealthed+=/envenom,if=effective_combo_points>=variable.effective_spend_cp&dot.kingsbane.ticking&buff.envenom.remains<=3
  -- &(debuff.deathstalkers_mark.up|buff.edge_case.up|buff.cold_blood.up)

  -- actions.stealthed+=/envenom,if=effective_combo_points>=variable.effective_spend_cp&buff.master_assassin_aura.up&variable.single_target
  -- &(debuff.deathstalkers_mark.up|buff.edge_case.up|buff.cold_blood.up)
  if ComboPoints >= EffectiveCPSpend and (Target:DebuffUp(S.DeathStalkersMarkDebuff) or Player:BuffUp(S.EdgeCase) or Player:BuffUp(S.ColdBlood)) then
    if Target:DebuffUp(S.Kingsbane) and Player:BuffRemains(S.Envenom) <= 3 then
      if ReturnSpellOnly then
        return S.Envenom
      else
        if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then
          return "Cast Envenom (Stealth Kingsbane)"
        end
      end
    end
    if SingleTarget and MasterAssassinAuraUp() then
      if ReturnSpellOnly then
        return S.Envenom
      else
        if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then
          return "Cast Envenom (Master Assassin)"
        end
      end
    end
  end

  -- # Rupture during Indiscriminate Carnage
  -- actions.stealthed+=/rupture,target_if=effective_combo_points>=variable.effective_spend_cp&buff.indiscriminate_carnage.up
  -- &refreshable&(!variable.regen_saturated|!variable.scent_saturation|!dot.rupture.ticking)&target.time_to_die>15
  if S.Rupture:IsCastable() or ForceStealth then
    local function RuptureTargetIfFunc(TargetUnit)
      return TargetUnit:DebuffRemains(S.Rupture)
    end
    local function RuptureIfFunc(TargetUnit)
      return ComboPoints >= EffectiveCPSpend and Player:BuffUp(S.IndiscriminateCarnageBuff) and TargetUnit:DebuffRefreshable(S.Rupture)
        and (not EnergyRegenSaturated or not ScentSaturated or TargetUnit:DebuffDown(S.Rupture))
        and Target:TimeToDie() > 15
    end
    if HR.AoEON() then
      local TargetIfUnit = CheckTargetIfTarget("min", RuptureTargetIfFunc, RuptureIfFunc)
      if TargetIfUnit and TargetIfUnit:GUID() ~= Target:GUID() then
        CastLeftNameplate(TargetIfUnit, S.Rupture)
      end
    end
    if RuptureIfFunc(Target) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if Cast(S.Rupture, nil, nil, not TargetInMeleeRange) then
          return "Cast Rupture (Stealth Indiscriminate Carnage)"
        end
      end
    end
  end

  -- actions.stealthed+=/garrote,target_if=min:remains,if=stealthed.improved_garrote&(remains<12|pmultiplier<=1|(buff.indiscriminate_carnage.up&active_dot.garrote<spell_targets.fan_of_knives))&!variable.single_target&target.time_to_die-remains>2
  -- actions.stealthed+=/garrote,if=stealthed.improved_garrote&(pmultiplier<=1|remains<12|!variable.single_target&buff.master_assassin_aura.remains<3)&combo_points.deficit>=1+2*talent.shrouded_suffocation
  if (S.Garrote:IsCastable() and ImprovedGarroteRemains() > 0) or ForceStealth then
    local function GarroteTargetIfFunc(TargetUnit)
      return TargetUnit:DebuffRemains(S.Garrote)
    end
    local function GarroteIfFunc(TargetUnit)
      return (TargetUnit:PMultiplier(S.Garrote) <= 1 or TargetUnit:DebuffRemains(S.Garrote) < 12
        or (IndiscriminateCarnageRemains() > 0 and S.Garrote:AuraActiveCount() < MeleeEnemies10yCount)) and not SingleTarget
        and (TargetUnit:FilteredTimeToDie(">", 2, -TargetUnit:DebuffRemains(S.Garrote)) or TargetUnit:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold)
    end
    if HR.AoEON() then
      local TargetIfUnit = CheckTargetIfTarget("min", GarroteTargetIfFunc, GarroteIfFunc)
      if TargetIfUnit and TargetIfUnit:GUID() ~= Target:GUID() then
        return CastLeftNameplate(TargetIfUnit, S.Garrote)
      end
    end
    if GarroteIfFunc(Target) then
      if ReturnSpellOnly then
        return S.Garrote
      else
        if Cast(S.Garrote, nil, nil, not TargetInMeleeRange) then
          return "Cast Garrote (Improved Garrote)"
        end
      end
    end
    if ComboPointsDeficit >= (1 + 2 * num(S.ShroudedSuffocation:IsAvailable())) and (Target:PMultiplier(S.Garrote) <= 1 or Target:DebuffRemains(S.Garrote) < 12 or not SingleTarget and MasterAssassinRemains() < 3) then
      if ReturnSpellOnly then
        return S.Garrote
      else
        if Cast(S.Garrote, nil, nil, not TargetInMeleeRange) then
          return "Cast Garrote (Improved Garrote Low CP)"
        end
      end
    end
  end
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell)
  -- Fetch the predicted ability to use after the stealth spell, a number of abilities require stealth to be castable
  -- so fake stealth to allow them to be evaluated
  local MacroAbility = Stealthed(true, true)

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell:ID() == S.Vanish:ID() and (not Settings.Assassination.StealthMacro.Vanish or not MacroAbility) then
    if Cast(S.Vanish, Settings.CommonsOGCD.OffGCDasOffGCD.Vanish) then
      return "Cast Vanish"
    end
    return false
  elseif StealthSpell:ID() == S.Shadowmeld:ID() and (not Settings.Assassination.StealthMacro.Shadowmeld or not MacroAbility) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Shadowmeld"
    end
    return false
  end

  local MacroTable = { StealthSpell, MacroAbility }

  ShouldReturn = CastQueue(unpack(MacroTable))
  if ShouldReturn then
    return "| " .. MacroTable[2]:Name()
  end
  return false
end

-- # Vanish Handling
local function Vanish ()
  -- actions.vanish=pool_resource,for_next=1,extra_amount=45
  if Settings.Commons.ShowPooling and Player:EnergyPredicted() < 45 then
    if Cast(S.PoolEnergy) then
      return "Pool for Vanish"
    end
  end

  -- # Vanish to fish for Fateful Ending
  -- actions.vanish+=/vanish,if=!buff.fatebound_lucky_coin.up&(buff.fatebound_coin_tails.stack>=5|buff.fatebound_coin_heads.stack>=5)
  if S.Vanish:IsCastable() and Player:BuffDown(S.FateboundLuckyCoin) and
    (Player:BuffStack(S.FateboundCoinTails) >= 5 or Player:BuffStack(S.FateboundCoinHeads) >= 5) then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish (Fateful Ending Fish)" .. ShouldReturn
    end
  end

  -- # Vanish to spread Garrote during Deathmark without Indiscriminate Carnage
  -- actions.vanish+=/vanish,if=!talent.master_assassin&!talent.indiscriminate_carnage&talent.improved_garrote
  -- &cooldown.garrote.up&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)
  -- &(debuff.deathmark.up|cooldown.deathmark.remains<4)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)
  if S.Vanish:IsCastable() and not S.MasterAssassin:IsAvailable() and not S.IndiscriminateCarnage:IsAvailable()
    and S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp() and (Target:PMultiplier(S.Garrote) <= 1
    or IsDebuffRefreshable(Target, S.Garrote)) and (Target:DebuffUp(S.Deathmark) or S.Deathmark:CooldownRemains() < 4)
    and ComboPointsDeficit >= mathmin(MeleeEnemies10yCount, 4) then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish Garrote Deathmark (No Carnage)" .. ShouldReturn
    end
  end

  -- actions.vanish=pool_resource,for_next=1,extra_amount=45
  if Settings.Commons.ShowPooling and Player:EnergyPredicted() < 45 then
    if Cast(S.PoolEnergy) then
      return "Pool for Vanish"
    end
  end

  -- # Vanish for cleaving Garrotes with Indiscriminate Carnage
  --actions.vanish+=/vanish,if=!talent.master_assassin&talent.indiscriminate_carnage&talent.improved_garrote
  -- &cooldown.garrote.up&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&spell_targets.fan_of_knives>2
  -- &(target.time_to_die-remains>15|raid_event.adds.in>20)
  if S.Vanish:IsCastable() and not S.MasterAssassin:IsAvailable() and S.IndiscriminateCarnage:IsAvailable()
    and S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp() and (Target:PMultiplier(S.Garrote) <= 1 or
    IsDebuffRefreshable(Target, S.Garrote)) and MeleeEnemies10yCount > 2 then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish (Garrote Carnage)" .. ShouldReturn
    end
  end

  -- # Vanish fallback for Master Assassin
  --actions.vanish+=/vanish,if=!talent.improved_garrote&talent.master_assassin&!dot.rupture.refreshable
  -- &dot.garrote.remains>3&debuff.deathmark.up&(debuff.shiv.up|debuff.deathmark.remains<4)
  if S.Vanish:IsCastable() and not S.ImprovedGarrote:IsAvailable() and S.MasterAssassin:IsAvailable()
    and not IsDebuffRefreshable(Target, S.Rupture) and Target:DebuffRemains(S.Garrote) > 3 and Target.DebuffUp(S.Deathmark)
    and (Target.DebuffUp(S.ShivDebuff) or Target.DebuffRemains(S.Deathmark) < 4) then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish (Master Assassin)" .. ShouldReturn
    end
  end

  -- # Vanish fallback for Improved Garrote during Deathmark if no add waves are expected
  --actions.vanish+=/vanish,if=talent.improved_garrote&cooldown.garrote.up
  -- &(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)
  -- &(debuff.deathmark.up|cooldown.deathmark.remains<4)&raid_event.adds.in>30
  if S.Vanish:IsCastable() and S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp()
    and (Target:PMultiplier(S.Garrote) <= 1 or IsDebuffRefreshable(Target, S.Garrote))
    and (Target:DebuffUp(S.Deathmark) or S.Deathmark:CooldownRemains() < 4) then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish (Improved Garrote during Deathmark)" .. ShouldReturn
    end
  end

  -- # Vanish for slightly more mark uptime since you can apply mark and have darkest night at the same time
  --actions.vanish+=/vanish,if=!talent.improved_garrote&buff.darkest_night.up&combo_points.deficit>=3&variable.single_target
  if S.Vanish:IsReady() and not S.ImprovedGarrote:IsAvailable() and Player:BuffUp(S.DarkestNightBuff)
    and ComboPointsDeficit >= 3 and SingleTarget then
    ShouldReturn = StealthMacro(S.Vanish)
    if ShouldReturn then
      return "Cast Vanish (Deathmark Uptime)" .. ShouldReturn
    end
  end
end

local function UsableItems ()
  if not Settings.Commons.Enabled.Trinkets then
    return
  end

  -- actions.items+=/use_item,name=ashes_of_the_embersoul,use_off_gcd=1,if=(dot.kingsbane.ticking&dot.kingsbane.remains<=11)|fight_remains<=22
  -- actions.items+=/use_item,name=algethar_puzzle_box,use_off_gcd=1,if=dot.rupture.ticking&cooldown.deathmark.remains<2|fight_remains<=22
  if I.AshesoftheEmbersoul:IsEquippedAndReady() then
    if (Target:DebuffUp(S.Kingsbane) and Target:DebuffRemains(S.Kingsbane) <= 11 or HL.BossFilteredFightRemains("<", 22)) then
      if Cast(I.AshesoftheEmbersoul, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Ashes of the Embersoul";
      end
    end
  end

  if I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if (Target:DebuffUp(S.Rupture) and S.Deathmark:CooldownRemains() <= 2 or HL.BossFilteredFightRemains("<", 22)) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Algethar Puzzle Box";
      end
    end
  end

  -- actions.items+=/use_item,name=treacherous_transmitter,use_off_gcd=1,if=variable.base_trinket_condition
  if I.TreacherousTransmitter:IsEquippedAndReady() then
    if (Target:DebuffUp(S.Rupture) and S.Deathmark:CooldownRemains() <= 2 or HL.BossFilteredFightRemains("<", 22)) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Treacherous Transmitter";
      end
    end
  end

  -- actions.items+=/use_item,name=imperfect_ascendancy_serum,use_off_gcd=1,if=variable.base_trinket_condition
  if I.ImperfectAscendancySerum:IsEquippedAndReady() then
    if (Target:DebuffUp(S.Rupture) and S.Deathmark:CooldownRemains() <= 2 or HL.BossFilteredFightRemains("<", 22)) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Imperfect Ascendancy Serum";
      end
    end
  end

  -- actions.items+=/use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
  -- actions.items+=/use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
  if TrinketItem1:IsReady() then
    if not Player:IsItemBlacklisted(TrinketItem1) and not ValueIsInArray(OnUseExcludeTrinkets, TrinketItem1:ID())
      and (TrinketSyncSlot == 1 and (S.Deathmark:AnyDebuffUp() or HL.BossFilteredFightRemains("<", 20))
      or (TrinketSyncSlot == 2 and (not TrinketItem2:IsReady() or not S.Deathmark:AnyDebuffUp() and S.Deathmark:CooldownRemains() > 20)) or TrinketSyncSlot == 0) then
      if Cast(TrinketItem1, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Trinket 1";
      end
    end
  end

  if TrinketItem2:IsReady() then
    if not Player:IsItemBlacklisted(TrinketItem2) and not ValueIsInArray(OnUseExcludeTrinkets, TrinketItem2:ID())
      and (TrinketSyncSlot == 2 and (S.Deathmark:AnyDebuffUp() or HL.BossFilteredFightRemains("<", 20))
      or (TrinketSyncSlot == 1 and (not TrinketItem1:IsReady() or not S.Deathmark:AnyDebuffUp() and S.Deathmark:CooldownRemains() > 20)) or TrinketSyncSlot == 0) then
      if Cast(TrinketItem2, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Trinket 2";
      end
    end
  end
end

local function ShivUsage ()
  -- actions.shiv=variable,name=shiv_condition,value=!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking
  local ShivCondition = Target:DebuffDown(S.ShivDebuff) and Target:DebuffUp(S.Garrote) and Target:DebuffUp(S.Rupture)

  --  actions.shiv+=/variable,name=shiv_kingsbane_condition,value=talent.kingsbane&buff.envenom.up&variable.shiv_condition
  local ShivKingsbaneCondition = S.Kingsbane:IsAvailable() and Player:BuffUp(S.Envenom) and ShivCondition

  if S.Shiv:IsReady() then
    -- # Shiv for aoe with Arterial Precision
    -- actions.shiv+=/shiv,if=talent.arterial_precision&variable.shiv_condition&spell_targets.fan_of_knives>=4
    -- &dot.crimson_tempest.ticking
    if S.ArterialPrecision:IsAvailable() and ShivCondition and MeleeEnemies10yCount >= 4 then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv (Arterial Precision)"
      end
    end

    -- # Shiv cases for Kingsbane
    -- actions.shiv+=/shiv,if=!talent.lightweight_shiv.enabled&variable.shiv_kingsbane_condition
    -- &(dot.kingsbane.ticking&dot.kingsbane.remains<8|!dot.kingsbane.ticking&cooldown.kingsbane.remains>=24)
    -- &(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)
    if not S.LightweightShiv:IsAvailable() and ShivKingsbaneCondition
      and (Target:DebuffUp(S.Kingsbane) and Target:DebuffRemains(S.Kingsbane) < 8 or not Target:DebuffUp(S.Kingsbane) and S.Kingsbane:CooldownRemains() >= 24)
      and (not S.CrimsonTempest:IsAvailable() or SingleTarget or Target:DebuffUp(S.CrimsonTempest)) then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv (Kingsbane)"
      end
    end

    -- actions.shiv+=/shiv,if=talent.lightweight_shiv.enabled&variable.shiv_kingsbane_condition
    -- &(dot.kingsbane.ticking|cooldown.kingsbane.remains<=1)
    if S.LightweightShiv:IsAvailable() and ShivKingsbaneCondition and (Target:DebuffUp(S.Kingsbane) or S.Kingsbane:CooldownRemains() <= 1) then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv (Kingsbane Lightweight)"
      end
    end

    -- # Fallback shiv for arterial during deathmark
    -- actions.shiv+=/shiv,if=talent.arterial_precision&variable.shiv_condition&debuff.deathmark.up
    if S.ArterialPrecision:IsAvailable() and ShivCondition and S.Deathmark:AnyDebuffUp() then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv (Arterial Precision Deathmark)"
      end
    end

    -- # Fallback if no special cases apply
    -- actions.shiv+=/shiv,if=!talent.kingsbane&!talent.arterial_precision&variable.shiv_condition
    -- &(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)
    if not S.Kingsbane:IsAvailable() and not S.ArterialPrecision:IsAvailable() and ShivCondition
      and (not S.CrimsonTempest:IsAvailable() or SingleTarget or Target:DebuffUp(S.CrimsonTempest)) then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv"
      end
    end

    --# Dump Shiv on fight end
    --actions.shiv+=/shiv,if=fight_remains<=charges*8
    if HL.BossFilteredFightRemains("<=", S.Shiv:Charges() * 8) then
      if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then
        return "Cast Shiv (End Fight)"
      end
    end
  end
end

local function MiscCDs ()
  -- actions.misc_cds=potion,if=buff.bloodlust.react|fight_remains<30|debuff.deathmark.up
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 30) or S.Deathmark:AnyDebuffUp()) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then
        return "Cast Potion";
      end
    end
  end

  -- Racials
  if S.Deathmark:AnyDebuffUp() and (not ShouldReturn or Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
    if ShouldReturn then
      Racials()
    else
      ShouldReturn = Racials()
    end
  end
end

-- # Cooldowns
local function CDs ()
  if not TargetInAoERange then
    return
  end

  if not HR.CDsON() then
    return
  end

  -- actions.cds=variable,name=deathmark_ma_condition,value=!talent.master_assassin.enabled|dot.garrote.ticking
  -- actions.cds+=/variable,name=deathmark_kingsbane_condition,value=!talent.kingsbane|cooldown.kingsbane.remains<=2
  -- actions.cds+=/variable,name=deathmark_condition,value=!stealthed.rogue&buff.slice_and_dice.remains>5&dot.rupture.ticking
  -- &buff.envenom.up&!debuff.deathmark.up&variable.deathmark_ma_condition&variable.deathmark_kingsbane_condition
  local DeathmarkCondition = not Player:StealthUp(true, false) and Player:BuffRemains(S.SliceandDice) > 5 and Target:DebuffUp(S.Rupture)
    and Player:BuffUp(S.Envenom) and not S.Deathmark:AnyDebuffUp()
    and (not S.MasterAssassin:IsAvailable() or Target:DebuffUp(S.Garrote))
    and (not S.Kingsbane:IsAvailable() or S.Kingsbane:CooldownRemains() <= 2)

  -- actions.cds+=/call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets then
    if ShouldReturn then
      UsableItems()
    else
      ShouldReturn = UsableItems()
    end
  end

  -- actions.cds+=/invoke_external_buff,name=power_infusion,if=dot.deathmark.ticking
  -- Note: We don't handle external buffs.

  -- actions.cds+=/deathmark,if=(variable.deathmark_condition&target.time_to_die>=10)|fight_remains<=20
  if S.Deathmark:IsCastable() then
    if (DeathmarkCondition and Target:TimeToDie() >= 10) or HL.BossFilteredFightRemains("<=", 20) then
      if Cast(S.Deathmark, Settings.Assassination.OffGCDasOffGCD.Deathmark) then
        return "Cast Deathmark"
      end
    end
  end

  -- -- actions.cds+=/call_action_list,name=shiv
  ShouldReturn = ShivUsage()
  if ShouldReturn then
    return ShouldReturn
  end

  -- actions.cds+=/kingsbane,if=(debuff.shiv.up|cooldown.shiv.remains<6)&buff.envenom.up&(cooldown.deathmark.remains>=50|dot.deathmark.ticking)|fight_remains<=15
  if S.Kingsbane:IsReady() then
    if (Target:DebuffUp(S.ShivDebuff) or S.Shiv:CooldownRemains() < 6) and Player:BuffUp(S.Envenom)
      and (S.Deathmark:CooldownRemains() >= 50 or Target:DebuffUp(S.Deathmark)) or HL.BossFilteredFightRemains("<=", 15) then
      if Cast(S.Kingsbane, Settings.Assassination.GCDasOffGCD.Kingsbane) then
        return "Cast Kingsbane"
      end
    end
  end

  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(((energy.deficit>=100+energy.regen_combined|charges>=3)
  -- &debuff.shiv.remains>=4)|spell_targets.fan_of_knives>=4&debuff.shiv.remains>=6)|fight_remains<charges*6
  if S.ThistleTea:IsCastable() and not Player:BuffUp(S.ThistleTea) then
    if (((Player:EnergyDeficit() >= 100 + EnergyRegenCombined
      or S.ThistleTea:Charges() >= 3) and Target:DebuffRemains(S.ShivDebuff) >= 4) or MeleeEnemies10yCount >= 4 and Target:DebuffRemains(S.Shiv) >= 6)
      or HL.BossFilteredFightRemains("<", S.ThistleTea:Charges() * 6) then
      if HR.Cast(S.ThistleTea, Settings.CommonsOGCD.OffGCDasOffGCD.ThistleTea) then
        return "Cast Thistle Tea"
      end
    end
  end

  -- actions.cds+=/call_action_list,name=misc_cds
  if ShouldReturn then
    MiscCDs()
  else
    ShouldReturn = MiscCDs()
    if ShouldReturn then
      return ShouldReturn
    end
  end

  -- actions.cds+=/call_action_list,name=vanish,if=!stealthed.all&master_assassin_remains=0
  if not Player:StealthUp(true, true) and MasterAssassinRemains() <= 0 then
    if ShouldReturn then
      Vanish()
    else
      ShouldReturn = Vanish()
      if ShouldReturn then
        return ShouldReturn
      end
    end
  end

  -- # Cold Blood with similar conditions to Envenom, avoiding munching Edge Case
  -- actions.cds+=/cold_blood,if=!buff.edge_case.up&cooldown.deathmark.remains>10&!buff.darkest_night.up
  -- &effective_combo_points>=variable.effective_spend_cp&(variable.not_pooling|debuff.amplifying_poison.stack>=20
  -- |!variable.single_target)&!buff.vanish.up&(!cooldown.kingsbane.up|!variable.single_target)&!cooldown.deathmark.up
  if S.ColdBlood:IsReady() and Player:DebuffDown(S.ColdBlood) then
    if Player:BuffDown(S.EdgeCase) and S.Deathmark:CooldownRemains() > 10 and Player:BuffDown(S.DarkestNightBuff)
      and ComboPoints >= EffectiveCPSpend and (NotPooling or Target:DebuffStack(S.AmplifyingPoisonDebuff) >= 20
      or not SingleTarget) and Player:BuffDown(Rogue.VanishBuffSpell()) and (not S.CooldownUp(S.Kingsbane) or not SingleTarget)
      and not S.CooldownUp(S.Deathmark) then
      if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
        return "Cast Cold Blood"
      end
    end
  end
end

local function Evaluate_Garrote_Target(TargetUnit)
  return IsDebuffRefreshable(TargetUnit, S.Garrote) and TargetUnit:PMultiplier(S.Garrote) <= 1
end

local function Evaluate_Rupture_Target(TargetUnit)
  RuptureDurationThreshold = 4 + BoolToInt(S.DashingScoundrel:IsAvailable()) * 5 + BoolToInt(EnergyRegenSaturated) * 6
  return IsDebuffRefreshable(TargetUnit, S.Rupture, RuptureThreshold) and TargetUnit:PMultiplier(S.Rupture) <= 1
    and (TargetUnit:FilteredTimeToDie(">", RuptureDurationThreshold, -TargetUnit:DebuffRemains(S.Rupture)) or TargetUnit:TimeToDieIsNotValid())
end

local function Core_Dot()
  -- # Maintain Garrote
  -- actions.core_dot=/garrote,if=combo_points.deficit>=1&(pmultiplier<=1)&refreshable&target.time_to_die-remains>12
  if S.Garrote:IsCastable() and ComboPointsDeficit >= 1 then
    if Evaluate_Garrote_Target(Target) and Rogue.CanDoTUnit(Target, GarroteDMGThreshold)
      and (Target:FilteredTimeToDie(">", 12, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      if CastPooling(S.Garrote, nil, not TargetInMeleeRange) then
        return "Pool for Garrote (ST)"
      end
    end
  end

  -- # Maintain Rupture unless darkest night is up
  --actions.core_dot+=/rupture,if=effective_combo_points>=variable.effective_spend_cp&(pmultiplier<=1)
  -- &refreshable&target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(variable.regen_saturated*6))&!buff.darkest_night.up
  if S.Rupture:IsReady() and ComboPoints >= EffectiveCPSpend and Player:BuffDown(S.DarkestNightBuff) then
    if Evaluate_Rupture_Target(Target) and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if CastPooling(S.Rupture, nil, nil, not TargetInMeleeRange) then
        return "Cast Rupture"
      end
    end
  end

  -- # Crimson Tempest with Momentum of Despair
  -- actions.core_dot+=/crimson_tempest,if=effective_combo_points>=variable.effective_spend_cp&refreshable
  -- &buff.momentum_of_despair.remains>6&variable.single_target
  if S.CrimsonTempest:IsReady() and ComboPoints >= EffectiveCPSpend and IsDebuffRefreshable(Target, S.CrimsonTempest)
    and Player:BuffRemains(S.MomentumOfDespair) > 6 and SingleTarget then
    if Cast(S.CrimsonTempest) then
      return "Crimson Tempest with Momentum of Despair"
    end
  end
end

-- # Damage over time abilities
local function AoE_Dot ()
  local DotFinisherCondition = ComboPoints >= EffectiveCPSpend

  -- # Crimson Tempest on 2+ Targets if we have enough energy regen
  -- actions.aoe_dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>=2&variable.dot_finisher_condition
  -- &refreshable&target.time_to_die-remains>6
  if HR.AoEON() and S.CrimsonTempest:IsReady() and MeleeEnemies10yCount >= 2 and DotFinisherCondition then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if IsDebuffRefreshable(CycleUnit, S.CrimsonTempest, CrimsonTempestThreshold)
        and CycleUnit:PMultiplier(S.CrimsonTempest) <= 1
        and CycleUnit:FilteredTimeToDie(">", 6, -CycleUnit:DebuffRemains(S.CrimsonTempest)) then
        if Cast(S.CrimsonTempest) then
          return "Cast Crimson Tempest (AoE High Energy)"
        end
      end
    end
  end

  -- # Garrote upkeep, also uses it in AoE to reach energy saturation
  -- actions.aoe_dot+=/garrote,cycle_targets=1,if=combo_points.deficit>=1&(pmultiplier<=1)&refreshable
  -- &!variable.regen_saturated&target.time_to_die-remains>12
  if S.Garrote:IsCastable() and ComboPointsDeficit >= 1 then
    if Evaluate_Garrote_Target(Target) and not EnergyRegenSaturated
      and (Target:FilteredTimeToDie(">", 12, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 12, MeleeEnemies5y)
    end
  end

  -- # Rupture upkeep, also uses it in AoE to reach energy or scent of blood saturation
  --actions.aoe_dot+=/rupture,cycle_targets=1,if=variable.dot_finisher_condition&refreshable&(!dot.kingsbane.ticking
  -- |buff.cold_blood.up)&(!variable.regen_saturated&(talent.scent_of_blood.rank=2|talent.scent_of_blood.rank<=1
  -- &(buff.indiscriminate_carnage.up|target.time_to_die-remains>15)))
  -- &target.time_to_die-remains>(7+(talent.dashing_scoundrel*5)+(variable.regen_saturated*6))&!buff.darkest_night.up
  if S.Rupture:IsReady() and HR.AoEON() and DotFinisherCondition and (Target:DebuffDown(S.Kingsbane) or Player:BuffUp(S.ColdBlood))
    and (not EnergyRegenSaturated and (S.ScentOfBlood:TalentRank() == 2 or S.ScentOfBlood:TalentRank() <= 1
    and (Player:BuffUp(S.IndiscriminateCarnageBuff or Target:TimeToDie() > 15))))
    and Target:TimeToDie() > (7 + (BoolToInt(S.DashingScoundrel:IsAvailable()) * 5) + (BoolToInt(EnergyRegenSaturated) * 6))
    and Player:BuffDown(S.DarkestNightBuff) then
    SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, RuptureDurationThreshold, MeleeEnemies5y)
  end

  -- actions.aoe_dot+=/rupture,cycle_targets=1,if=variable.dot_finisher_condition&refreshable
  -- &(!dot.kingsbane.ticking|buff.cold_blood.up)&variable.regen_saturated&!variable.scent_saturation
  -- &target.time_to_die-remains>19&!buff.darkest_night.up
  if S.Rupture:IsReady() and DotFinisherCondition and Player:BuffDown(S.DarkestNightBuff) and HR.AoEON() then
    RuptureDurationThreshold = 7 + BoolToInt(S.DashingScoundrel:IsAvailable()) * 5 + BoolToInt(EnergyRegenSaturated) * 6
    if (not Target:DebuffUp(S.Kingsbane or Player:BuffUp(S.ColdBlood))) and EnergyRegenSaturated or not ScentSaturated then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, RuptureDurationThreshold, MeleeEnemies5y)
    end
  end

  -- # Garrote as a special generator for the last CP before a finisher for edge case handling
  -- actions.aoe_dot+=/garrote,if=refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time
  -- &spell_targets.fan_of_knives>=3)&(remains<=tick_time*2&spell_targets.fan_of_knives>=3)
  -- &(target.time_to_die-remains)>4&master_assassin_remains=0
  if S.Garrote:IsReady() and ComboPointsDeficit >= 1 and MasterAssassinRemains() <= 0
    and (Target:PMultiplier(S.Garrote) <= 1 or Target:DebuffRemains(S.Garrote) < BleedTickTime and MeleeEnemies10yCount >= 3)
    and (Target:DebuffRemains(S.Garrote) < BleedTickTime * 2 and MeleeEnemies10yCount >= 3)
    and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
    if Cast(S.Garrote, nil, nil, not TargetInMeleeRange) then
      return "Garrote (Fallback)"
    end
  end

  return false
end

-- # Direct damage abilities
local function Direct ()
  -- actions.direct=envenom,if=!buff.darkest_night.up&effective_combo_points>=variable.effective_spend_cp
  -- &(variable.not_pooling|debuff.amplifying_poison.stack>=20|effective_combo_points>cp_max_spend|!variable.single_target)&!buff.vanish.up
  if S.Envenom:IsReady() and Player:BuffDown(S.DarkestNightBuff) and ComboPoints > EffectiveCPSpend
    and (NotPooling or Target:DebuffStack(S.AmplifyingPoisonDebuff) >= 20 or ComboPoints > Rogue.CPMaxSpend()
    or not SingleTarget) and Player:BuffDown(Rogue.VanishBuffSpell()) then
    if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then
      return "Cast Envenom 1"
    end
  end

  -- actions.direct=envenom,if=buff.darkest_night.up&effective_combo_points>=cp_max_spend
  if S.Envenom:IsReady() and Player:BuffUp(S.DarkestNightBuff) and ComboPoints >= Rogue.CPMaxSpend() then
    if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then
      return "Cast Envenom 2"
    end
  end

  --- !!!! ---
  -- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|variable.not_pooling|!variable.single_target
  -- Note: This is used in all following fillers, so we just return false if not true and won't consider these.
  if not (ComboPointsDeficit > 1 or NotPooling or not SingleTarget) then
    return false
  end
  --- !!!! ---

  -- # Maintain Caustic Spatter
  -- actions.direct+=/mutilate,if=talent.caustic_spatter&dot.rupture.ticking&(!debuff.caustic_spatter.up|debuff.caustic_spatter.remains<=2)&variable.use_filler&!variable.single_target
  -- actions.direct+=/ambush,if=talent.caustic_spatter&dot.rupture.ticking&(!debuff.caustic_spatter.up|debuff.caustic_spatter.remains<=2)&variable.use_filler&!variable.single_target
  if not SingleTarget and S.CausticSpatter:IsAvailable() and Target:DebuffUp(S.Rupture) and Target:DebuffRemains(S.CausticSpatterDebuff) <= 2 then
    if S.Mutilate:IsCastable() then
      if Cast(S.Mutilate, nil, nil, not TargetInMeleeRange) then
        return "Cast Mutilate (Caustic)"
      end
    end

    if (S.Ambush:IsReady() or S.AmbushOverride:IsReady()) and (Player:StealthUp(true, true) or Player:BuffUp(S.BlindsideBuff)) then
      if Cast(S.Ambush, nil, nil, not TargetInMeleeRange) then
        return "Cast Ambush (Caustic)"
      end
    end
  end

  -- actions.direct+=/echoing_reprimand,if=variable.use_filler|fight_remains<20
  if CDsON() and S.EchoingReprimand:IsReady() then
    if Cast(S.EchoingReprimand, Settings.CommonsOGCD.GCDasOffGCD.EchoingReprimand, nil, not TargetInMeleeRange) then
      return "Cast Echoing Reprimand"
    end
  end

  -- # Fan of Knives at 3+ targets, accounting for various edge cases
  --actions.direct+=/fan_of_knives,if=variable.use_filler&!priority_rotation
  -- &(spell_targets.fan_of_knives>=3-(talent.momentum_of_despair&talent.thrown_precision)
  -- |buff.clear_the_witnesses.up&!talent.vicious_venoms)
  if S.FanofKnives:IsReady() then
    if HR.AoEON() and not PriorityRotation and (MeleeEnemies10yCount >= 3 - BoolToInt(S.MomentumOfDespair and S.ThrownPrecision))
      or Player:BuffUp(S.ClearTheWitnessesBuff) and not S.ViciousVenoms:IsAvailable() then
      if CastPooling(S.FanofKnives) then
        return "Cast Fan of Knives"
      end
    end
  end

  -- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking
  -- &(!priority_rotation|dot.garrote.ticking|dot.rupture.ticking),if=variable.use_filler
  -- &spell_targets.fan_of_knives>=3-(talent.momentum_of_despair&talent.thrown_precision)
  if HR.AoEON() and Player:BuffUp(S.DeadlyPoison)
    and MeleeEnemies10yCount >= 3 - BoolToInt(S.MomentumOfDespair:IsAvailable() and S.ThrownPrecision:IsAvailable()) then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff, true) and (not PriorityRotation or CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) then
        if CastPooling(S.FanofKnives) then
          return "Cast Fan of Knives (DP Refresh)"
        end
      end
    end
  end

  -- actions.direct+=/ambush,if=variable.use_filler&(buff.blindside.up|stealthed.rogue)&(!dot.kingsbane.ticking|debuff.deathmark.down|buff.blindside.up)
  if (S.Ambush:IsReady() or S.AmbushOverride:IsReady()) and (Player:BuffUp(S.BlindsideBuff) or Player:StealthUp(true, false))
    and (Target:DebuffDown(S.Kingsbane) or Target:DebuffDown(S.Deathmark) or Player:BuffUp(S.BlindsideBuff)) then
    if CastPooling(S.Ambush, nil, not TargetInMeleeRange) then
      return "Cast Ambush"
    end
  end

  -- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking&!debuff.amplifying_poison.up,if=variable.use_filler&spell_targets.fan_of_knives=2
  if S.Mutilate:IsCastable() and MeleeEnemies10yCount == 2 and Target:DebuffDown(S.DeadlyPoisonDebuff, true)
    and Target:DebuffDown(S.AmplifyingPoisonDebuff, true) then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(MeleeEnemies5y) do
      -- Note: The APL does not do this due to target_if mechanics, but since we are cycling we should check to see if the unit has a bleed
      if CycleUnit:GUID() ~= TargetGUID and (CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture))
        and not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff, true) and not CycleUnit:DebuffUp(S.AmplifyingPoisonDebuff, true) then
        CastLeftNameplate(CycleUnit, S.Mutilate)
        break
      end
    end
  end
  -- actions.direct+=/mutilate,if=variable.use_filler
  if S.Mutilate:IsCastable() then
    if CastPooling(S.Mutilate, nil, not TargetInMeleeRange) then
      return "Cast Mutilate"
    end
  end

  return false
end

--- ======= MAIN =======
local function APL ()
  -- Enemies Update
  MeleeRange = 5
  AoERange = 10
  TargetInMeleeRange = Target:IsInMeleeRange(MeleeRange)
  TargetInAoERange = Target:IsInMeleeRange(AoERange)
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Poisoned Knife & Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(AoERange) -- Fan of Knives & Crimson Tempest
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(MeleeRange) -- Melee cycle
  else
    Enemies30y = {}
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 1
    MeleeEnemies5y = {}
  end

  -- Rotation Variables Update
  BleedTickTime, ExsanguinatedBleedTickTime = 2 * Player:SpellHaste(), 1 * Player:SpellHaste()
  ComboPoints = Rogue.EffectiveComboPoints(Player:ComboPoints())
  ComboPointsDeficit = Player:ComboPointsMax() - ComboPoints
  RuptureThreshold = (4 + ComboPoints * 4) * 0.3
  CrimsonTempestThreshold = (4 + ComboPoints * 2) * 0.3
  RuptureDMGThreshold = S.Envenom:Damage() * Settings.Assassination.EnvenomDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.
  GarroteDMGThreshold = S.Mutilate:Damage() * Settings.Assassination.MutilateDMGOffset; -- Used as TTD Not Valid fallback since it's a generator.
  PriorityRotation = UsePriorityRotation()
  EffectiveCPSpend = mathmax(Player:ComboPointsMax() - 2, 5 * num(S.HandOfFate:IsAvailable()))

  -- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial()
  if ShouldReturn then
    return ShouldReturn
  end

  -- Poisons
  Rogue.Poisons()

  -- Bottled Flayedwing Toxin
  if I.BottledFlayedwingToxin:IsEquippedAndReady() and Player:BuffDown(S.FlayedwingToxin) then
    if Cast(I.BottledFlayedwingToxin, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
      return "Bottled Flayedwing Toxin";
    end
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- actions.precombat=apply_poison
    -- Note: Handled just above.
    -- actions.precombat+=/flask
    -- actions.precombat+=/augmentation
    -- actions.precombat+=/food
    -- actions.precombat+=/snapshot_stats
    -- actions.precombat+=/stealth
    if not Player:BuffUp(Rogue.VanishBuffSpell()) then
      ShouldReturn = Rogue.Stealth(Rogue.StealthSpell())
      if ShouldReturn then
        return ShouldReturn
      end
    end
    -- Opener
    if Everyone.TargetIsValid() then
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if not Player:BuffUp(S.SliceandDice) then
        if S.SliceandDice:IsReady() and ComboPoints >= 2 then
          if Cast(S.SliceandDice) then
            return "Cast Slice and Dice"
          end
        end
      end
    end
  end

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(S.Kick, Settings.CommonsDS.DisplayStyle.Interrupts, Interrupts)
    if ShouldReturn then
      return ShouldReturn
    end

    PoisonedBleeds = Rogue.PoisonedBleeds()
    -- TODO: Make this match the updated code version
    EnergyRegenCombined = Player:EnergyRegen() + PoisonedBleeds * 6 / (2 * Player:SpellHaste())
    EnergyTimeToMaxCombined = Player:EnergyDeficit() / EnergyRegenCombined
    -- actions+=/variable,name=regen_saturated,value=energy.regen_combined>35
    EnergyRegenSaturated = EnergyRegenCombined > 30
    NotPooling = NotPoolingVar()
    ScentSaturated = ScentSaturatedVar()

    -- actions=/stealth
    -- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
    SingleTarget = MeleeEnemies10yCount < 2

    -- actions+=/call_action_list,name=stealthed,if=stealthed.rogue|stealthed.improved_garrote|master_assassin_remains>0
    if Player:StealthUp(true, false) or ImprovedGarroteRemains() > 0 or MasterAssassinRemains() > 0 then
      ShouldReturn = Stealthed()
      if ShouldReturn then
        return ShouldReturn .. " (Stealthed)"
      end
    end

    -- # Put SnD up initially for Cut to the Chase, refresh with Envenom if at low duration
    -- actions+=/slice_and_dice,if=!buff.slice_and_dice.up&dot.rupture.ticking&combo_points>=1
    -- &(!buff.indiscriminate_carnage.up|variable.single_target)
    if not Player:BuffUp(S.SliceandDice) then
      if S.SliceandDice:IsReady() and Target:DebuffUp(S.Rupture) and Player:ComboPoints() >= 1
        and (Player:BuffDown(S.IndiscriminateCarnageBuff) or SingleTarget) then
        if Cast(S.SliceandDice) then
          return "Cast Slice and Dice"
        end
      end
    elseif TargetInAoERange then
      -- actions+=/envenom,if=buff.slice_and_dice.up&buff.slice_and_dice.remains<5&combo_points>=5
      if S.Envenom:IsReady() and Player:BuffRemains(S.SliceandDice) < 5 and Player:ComboPoints() >= 5 then
        if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then
          return "Cast Envenom (CttC)"
        end
      end
    else
      --- !!!! ---
      -- Special fallback Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
      -- Only if we are about to cap energy, not stealthed, and completely out of range
      --- !!!! ---
      if S.PoisonedKnife:IsCastable() and Target:IsInRange(30) and not Player:StealthUp(true, true)
        and MeleeEnemies10yCount == 0 and Player:EnergyTimeToMax() <= Player:GCD() * 1.5 then
        if Cast(S.PoisonedKnife) then
          return "Cast Poisoned Knife"
        end
      end
    end

    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then
      return ShouldReturn
    end

    -- actions+=/call_action_list,name=core_dot
    ShouldReturn = Core_Dot()
    if ShouldReturn then
      return ShouldReturn
    end

    -- actions+=/call_action_list,name=aoe_dot,if=!variable.single_target
    if HR.AoEON() and not SingleTarget then
      ShouldReturn = AoE_Dot()
      if ShouldReturn then
        return ShouldReturn
      end
    end

    -- actions+=/call_action_list,name=direct
    ShouldReturn = Direct()
    if ShouldReturn then
      return ShouldReturn
    end

    -- Racials
    if HR.CDsON() then
      -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen_combined
      if S.ArcaneTorrent:IsCastable() and TargetInMeleeRange and Player:EnergyDeficit() >= 15 + EnergyRegenCombined then
        if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
          return "Cast Arcane Torrent"
        end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastable() and TargetInMeleeRange then
        if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
          return "Cast Arcane Pulse"
        end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastable() and TargetInMeleeRange then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
          return "Cast Lights Judgment"
        end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsCastable() and TargetInMeleeRange then
        if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
          return "Cast Bag of Tricks"
        end
      end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.Mutilate:IsCastable() or S.Ambush:IsReady() or S.AmbushOverride:IsReady() then
      if Cast(S.PoolEnergy) then
        return "Normal Pooling"
      end
    end
  end
end

local function Init ()
  S.Deathmark:RegisterAuraTracking()
  S.Sepsis:RegisterAuraTracking()
  S.Garrote:RegisterAuraTracking()

  HR.Print("Assassination Rogue rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(259, APL, Init)
