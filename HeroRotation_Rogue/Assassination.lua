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
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast = HR.Cast
local CastPooling = HR.CastPooling
local CastLeftNameplate = HR.CastLeftNameplate
-- Lua
local pairs = pairs
local mathfloor = math.floor


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Commons2 = HR.GUISettings.APL.Rogue.Commons2,
  Assassination = HR.GUISettings.APL.Rogue.Assassination
}

-- Spells
local S = Spell.Rogue.Assassination

-- Items
local I = Item.Rogue.Assassination
local OnUseExcludeTrinkets = {
  --  I.TrinketName:ID(),
}

-- Enemies
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y

-- Rotation Variables
local ShouldReturn
local Stealth
local BleedTickTime, ExsanguinatedBleedTickTime = 2 / Player:SpellHaste(), 1 / Player:SpellHaste()
local ComboPoints, ComboPointsDeficit
local RuptureThreshold, CrimsonTempestThreshold, RuptureDMGThreshold, GarroteDMGThreshold, RuptureDurationThreshold
local PriorityRotation
local PoisonedBleeds, EnergyRegenCombined, EnergyRegenSaturated, SingleTarget

-- Legendaries
local DashingScoundrelEquipped = Player:HasLegendaryEquipped(118)
local DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
local DoombladeEquipped = Player:HasLegendaryEquipped(119)
local DuskwalkersPatchEquipped = Player:HasLegendaryEquipped(121)
local MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
local VendettaCDMultiplier = DuskwalkersPatchEquipped and 0.55 or 1.0
HL:RegisterForEvent(function()
  DashingScoundrelEquipped = Player:HasLegendaryEquipped(118)
  DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
  DoombladeEquipped = Player:HasLegendaryEquipped(119)
  DuskwalkersPatchEquipped = Player:HasLegendaryEquipped(121)
  MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
  VendettaCDMultiplier = DuskwalkersPatchEquipped and 0.55 or 1.0
end, "PLAYER_EQUIPMENT_CHANGED")

-- Interrupts
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function () return true end },
  { S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return ComboPoints > 0 end }
}

-- Spells Damage
S.Envenom:RegisterDamageFormula(
  -- Envenom DMG Formula:
  --  AP * CP * Env_APCoef * Aura_M * ToxicB_M * DS_M * Mastery_M * Versa_M
  function ()
    return
      -- Attack Power
      Player:AttackPowerDamageMod() *
      -- Combo Points
      ComboPoints *
      -- Envenom AP Coef
      0.16 *
      -- Aura Multiplier (SpellID: 137037)
      1.51 *
      -- Shiv Multiplier
      (Target:DebuffUp(S.ShivDebuff) and 1.3 or 1) *
      -- Deeper Stratagem Multiplier
      (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
      -- Mastery Finisher Multiplier
      (1 + Player:MasteryPct()/100) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100)
  end
)
S.Mutilate:RegisterDamageFormula(
  function ()
    return
      -- Attack Power (MH Factor + OH Factor)
      (Player:AttackPowerDamageMod() + Player:AttackPowerDamageMod(true)) *
      -- Mutilate Coefficient
      0.35 *
      -- Aura Multiplier (SpellID: 137037)
      1.51 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100)
  end
)
local function ComputeNighstalkerPMultiplier ()
  return S.Nightstalker:IsAvailable() and Player:StealthUp(true, false, true) and 1.5 or 1
end
local function ComputeSubterfugeGarrotePMultiplier ()
  return S.Subterfuge:IsAvailable() and Player:StealthUp(true, false, true) and 2 or 1
end
S.Garrote:RegisterPMultiplier(ComputeNighstalkerPMultiplier, ComputeSubterfugeGarrotePMultiplier)
S.Rupture:RegisterPMultiplier(ComputeNighstalkerPMultiplier)


--- ======= HELPERS =======
-- Check if the Priority Rotation variable should be set
local function UsePriorityRotation()
  if MeleeEnemies10yCount < 2 then
    return false
  elseif Settings.Commons.UsePriorityRotation == "Always" then
    return true
  elseif Settings.Commons.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  elseif Settings.Commons.UsePriorityRotation == "Auto" then
    -- Zul Mythic
    if Player:InstanceDifficulty() == 16 and Target:NPCID() == 138967 then
      return true
    end
  end

  return false
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

-- Master Assassin Remains Check
local function MasterAssassinRemains ()
  local LegendaryRemains = Rogue.MasterAssassinsMarkRemains()

  -- Legendary is up
  if LegendaryRemains > 0 then
    return LegendaryRemains
  -- Currently stealthed (i.e. Aura)
  elseif Player:BuffRemains(S.MasterAssassinBuff) < 0 then
    return Player:GCDRemains() + 3
  -- Broke stealth recently (i.e. Buff)
  else
    return Player:BuffRemains(S.MasterAssassinBuff)
  end
end
local function CheckWillWasteCooldown(ThisCooldownLength, OtherCooldownRemains, EffectDuration)
  local FightRemains = Target:TimeToDie()
  if not HL.BossFightRemainsIsNotValid() then
    FightRemains = HL.BossFightRemains()
  elseif FightRemains < EffectDuration then
    return false -- Bail out if we are not in a boss encounter and fighting a low-HP target
  end
  -- e.g. if=floor((fight_remains-30)%cooldown)>floor((fight_remains-30-cooldown.vendetta.remains)%cooldown)
  if mathfloor((FightRemains - EffectDuration) / ThisCooldownLength) >
    mathfloor((FightRemains - EffectDuration - OtherCooldownRemains) / ThisCooldownLength) then
    return true
  end
  return false
end

-- Serrated Bone Spike Cycle Targets
-- actions.direct+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
local function EvaluateSBSTargetIfConditionCondition(TargetUnit)
  if TargetUnit:DebuffUp(S.SerratedBoneSpikeDebuff) then
    return 1000000 -- Random big number
  end
  return TargetUnit:TimeToDie()
end
local function EvaluateSBSCondition(TargetUnit)
  return not TargetUnit:DebuffUp(S.SerratedBoneSpikeDebuff)
end

--- ======= ACTION LISTS =======
local function Trinkets ()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludeTrinkets)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
  end

  return false
end
local function Racials ()
  -- actions.cds+=/blood_fury,if=debuff.vendetta.up
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
  end
  -- actions.cds+=/berserking,if=debuff.vendetta.up
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
  end
  -- actions.cds+=/fireblood,if=debuff.vendetta.up
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
  end
  -- actions.cds+=/ancestral_call,if=debuff.vendetta.up
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
  end

  return false
end

-- # Vanish Handling
local function Vanish ()
  if not S.Vanish:IsCastable() or Player:IsTanking(Target) then
    return
  end

  if S.Nightstalker:IsAvailable() then
    -- # Finish with max CP for Nightstalker, unless using Deathly Shadows
    -- actions.vanish=variable,name=nightstalker_cp_condition,value=(!runeforge.deathly_shadows&effective_combo_points>=cp_max_spend)|(runeforge.deathly_shadows&combo_points<2)
    if (not DeathlyShadowsEquipped and ComboPoints >= Rogue.CPMaxSpend()) or (DeathlyShadowsEquipped and ComboPoints<2) then
      -- # Vanish with Exsg + Nightstalker: Maximum CP and Exsg ready for next GCD
      -- actions.vanish+=/vanish,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&variable.nightstalker_cp_condition&cooldown.exsanguinate.remains<1
      if S.Exsanguinate:IsAvailable() and S.Exsanguinate:CooldownRemains() < 1 then
        if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Exsanguinate)" end
      end
      -- # Vanish with Nightstalker + No Exsg: Maximum CP and Vendetta up
      -- actions.vanish+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&variable.nightstalker_cp_condition&debuff.vendetta.up
      if not S.Exsanguinate:IsAvailable() and Target:DebuffUp(S.Vendetta) then
        if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Nightstalker)" end
      end
    end
  end
  -- actions.cds+=/vanish,if=talent.subterfuge.enabled&!stealthed.rogue&cooldown.garrote.up&(dot.garrote.refreshable|debuff.vendetta.up&dot.garrote.pmultiplier<=1)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)&raid_event.adds.in>12
  -- actions.vanish+=/vanish,if=talent.subterfuge.enabled&cooldown.garrote.up&(dot.garrote.refreshable|debuff.vendetta.up&dot.garrote.pmultiplier<=1)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)&raid_event.adds.in>12
  if S.Subterfuge:IsAvailable() and S.Garrote:CooldownUp()
    and (Target:DebuffRefreshable(S.Garrote) or (Target:DebuffUp(S.Vendetta) and Target:PMultiplier(S.Garrote) <= 1))
    and ComboPointsDeficit >= math.min(MeleeEnemies10yCount, 4) then
    -- actions.cds+=/pool_resource,for_next=1,extra_amount=45
    if Settings.Commons.ShowPooling and Player:EnergyPredicted() < 45 then
      if Cast(S.PoolEnergy) then return "Pool for Vanish (Subterfuge)" end
    end
    if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Subterfuge)" end
  end
  -- # Vanish with Master Assasin: Rupture+Garrote not in refresh range, during Vendetta+Shiv. Sync with Sepsis final hit if possible.
  -- actions.vanish+=/vanish,if=(talent.master_assassin.enabled|runeforge.mark_of_the_master_assassin)&!dot.rupture.refreshable&dot.garrote.remains>3&debuff.vendetta.up&(debuff.shiv.up|debuff.vendetta.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3
  if (S.MasterAssassin:IsAvailable() or MarkoftheMasterAssassinEquipped) and S.Vendetta:AnyDebuffUp() then
    local VendettaUnit = S.Vendetta:MaxDebuffRemainsUnit()
    if not VendettaUnit:DebuffRefreshable(S.Rupture, RuptureThreshold) and VendettaUnit:DebuffRemains(S.Garrote) > 3
      and (VendettaUnit:DebuffUp(S.ShivDebuff) or VendettaUnit:DebuffRemains(S.Vendetta) < 4 or S.Sepsis:AnyDebuffUp())
      and S.Sepsis:MaxDebuffRemains() < 3 then
      if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Master Assassin)" end
    end
  end
end

-- # Cooldowns
local function CDs ()
  if S.MarkedforDeath:IsCastable() then
    -- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit*1.5|combo_points.deficit>=cp_max_spend)
    if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit() * 1.5) then
      if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
    end
    -- # If no adds will die within the next 30s, use MfD on boss without any CP.
    -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
    if ComboPointsDeficit >= Rogue.CPMaxSpend() then
      if not Settings.Commons.STMfDAsDPSCD then
        HR.CastSuggested(S.MarkedforDeath)
      elseif HR.CDsON() then
        if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      end
    end
  end

  if not Target:IsInMeleeRange(10) or not HR.CDsON() then
    return
  end

  if not Player:StealthUp(true, false) then
    -- actions.cds+=/flagellation,if=!stealthed.rogue&(cooldown.vendetta.remains<3&effective_combo_points>=4&target.time_to_die>10|debuff.vendetta.up|fight_remains<24)
    -- actions.cds+=/flagellation,if=!stealthed.rogue&effective_combo_points>=4&(floor((fight_remains-24)%cooldown)>floor((fight_remains-24-cooldown.vendetta.remains*variable.vendetta_cdr)%cooldown))
    if S.Flagellation:IsReady() then
      if S.Vendetta:CooldownRemains() < 3 and ComboPoints >= 4 and (Target:FilteredTimeToDie(">", 10) or Target:TimeToDieIsNotValid())
        or Target:DebuffUp(S.Vendetta) or HL.BossFilteredFightRemains("<=", 24) then
        if Cast(S.Flagellation, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flagellation (Sync)" end
      elseif ComboPoints >= 4 and CheckWillWasteCooldown(90, S.Vendetta:CooldownRemains() * VendettaCDMultiplier, 24) then
        if Cast(S.Flagellation, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flagellation (Burn)" end
      end
    end
    -- actions.cds+=/sepsis,if=!stealthed.rogue&(cooldown.vendetta.remains<1&target.time_to_die>10|debuff.vendetta.up|fight_remains<10)
    -- actions.cds+=/sepsis,if=!stealthed.rogue&(floor((fight_remains-10)%cooldown)>floor((fight_remains-10-cooldown.vendetta.remains*variable.vendetta_cdr)%cooldown))
    if S.Sepsis:IsReady() then
      if S.Vendetta:CooldownRemains() < 1 and (Target:FilteredTimeToDie(">", 10) or Target:TimeToDieIsNotValid())
        or Target:DebuffUp(S.Vendetta) or HL.BossFilteredFightRemains("<=", 10) then
        if Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis (Sync)" end
      elseif CheckWillWasteCooldown(90, S.Vendetta:CooldownRemains() * VendettaCDMultiplier, 10) then
        if Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis (Burn)" end
      end
    end
    -- actions.cds+=/vendetta,if=!stealthed.rogue&dot.rupture.ticking&!debuff.vendetta.up&variable.vendetta_nightstalker_condition&variable.vendetta_covenant_condition
    if S.Vendetta:IsCastable() and Target:DebuffUp(S.Rupture) and not Target:DebuffUp(S.Vendetta) then
      -- actions.cds+=/variable,name=vendetta_nightstalker_condition,value=!talent.nightstalker.enabled|!talent.exsanguinate.enabled|cooldown.exsanguinate.remains<5-2*talent.deeper_stratagem.enabled
      local NightstalkerCondition = not S.Nightstalker:IsAvailable() or not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemains() < 5 - 2 * BoolToInt(S.DeeperStratagem:IsAvailable())
      -- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.kyrian|covenant.necrolord|covenant.none,value=1
      -- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.venthyr,value=floor((fight_remains-20)%(120*variable.vendetta_cdr))>floor((fight_remains-20-cooldown.flagellation.remains)%(120*variable.vendetta_cdr))|buff.flagellation_buff.up|debuff.flagellation.up|fight_remains<20
      -- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.night_fae,value=floor((fight_remains-20)%(120*variable.vendetta_cdr))>floor((fight_remains-20-cooldown.sepsis.remains)%(120*variable.vendetta_cdr))|dot.sepsis.ticking|fight_remains<20
      local Covenant = Player:Covenant()
      if NightstalkerCondition and (HL.BossFilteredFightRemains("<", 20) or Covenant == "Necrolord" or Covenant == "Kyrian" or Covenant == nil
        or (Covenant == "Venthyr" and (CheckWillWasteCooldown(120 * VendettaCDMultiplier, S.Flagellation:CooldownRemains(), 20)
          or Player:BuffUp(S.Flagellation) or Player:BuffUp(S.FlagellationBuff) or Target:DebuffUp(S.Flagellation)))
        or (Covenant == "Night Fae" and (CheckWillWasteCooldown(120 * VendettaCDMultiplier, S.Sepsis:CooldownRemains(), 20) or Target:DebuffUp(S.Sepsis)))) then
        if Cast(S.Vendetta, Settings.Assassination.OffGCDasOffGCD.Vendetta) then return "Cast Vendetta" end
      end
    end
    -- # Exsanguinate when not stealthed and both Rupture and Garrote are up for long enough.
    -- actions.cds+=/exsanguinate,if=!stealthed.rogue&(!dot.garrote.refreshable&dot.rupture.remains>4+4*cp_max_spend|dot.rupture.remains*0.5>target.time_to_die)&target.time_to_die>4
    if S.Exsanguinate:IsCastable() and (not Target:DebuffRefreshable(S.Garrote) and Target:DebuffRemains(S.Rupture) > 4+4*Rogue.CPMaxSpend()
      or Target:FilteredTimeToDie("<", Target:DebuffRemains(S.Rupture)*0.5)) and (Target:FilteredTimeToDie(">", 4) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if Cast(S.Exsanguinate) then return "Cast Exsanguinate" end
    end
  end
  -- actions.cds+=/shiv,if=dot.rupture.ticking&(!cooldown.sepsis.ready|cooldown.vendetta.remains>12)|dot.sepsis.ticking
  if S.Shiv:IsCastable() and (Target:DebuffUp(S.Rupture) and (S.Sepsis:CooldownRemains() > 15 or S.Vendetta:CooldownRemains() > 12) or Target:DebuffUp(S.Sepsis)) then
    if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then ShouldReturn = "Cast Shiv" end
  end
  -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5
  -- Racials
  if Target:DebuffUp(S.Vendetta) and (not ShouldReturn or Settings.Commons.OffGCDasOffGCD.Racials) then
    if ShouldReturn then
      Racials()
    else
      ShouldReturn = Racials()
    end
  end
  -- actions.cds+=/call_action_list,name=vanish,if=!stealthed.all&master_assassin_remains=0
  if not Player:StealthUp(true, true) and MasterAssassinRemains() <= 0 then
    if ShouldReturn then
      Vanish()
    else
      ShouldReturn = Vanish()
    end
  end

  -- Trinkets
  if Settings.Commons.UseTrinkets and (not ShouldReturn or Settings.Commons.TrinketDisplayStyle ~= "Main Icon") then
    if ShouldReturn then
      Trinkets()
    else
      ShouldReturn = Trinkets()
    end
  end

  return ShouldReturn
end

-- # Stealthed
local function Stealthed ()
  -- # Nighstalker on 3T: Crimson Tempest
  -- actions.stealthed=crimson_tempest,if=talent.nightstalker.enabled&spell_targets>=3&combo_points>=4&target.time_to_die-remains>6
  if S.CrimsonTempest:IsReady() and S.Nightstalker:IsAvailable() and MeleeEnemies10yCount >= 3 and ComboPoints >= 4
    and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.CrimsonTempest)) or Target:TimeToDieIsNotValid()) then
    if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (Nightstalker)" end
  end
  -- # Nighstalker on 1T: Snapshot Rupture
  -- actions.stealthed+=/rupture,if=talent.nightstalker.enabled&combo_points>=4&target.time_to_die-remains>6
  if S.Rupture:IsReady() and S.Nightstalker:IsAvailable() and ComboPoints >= 4
    and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid()) then
    if Cast(S.Rupture, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Rupture (Nightstalker)" end
  end
  if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() then
    -- # Subterfuge: Apply or Refresh with buffed Garrotes
    -- actions.stealthed+=/pool_resource,for_next=1
    -- actions.stealthed+=/garrote,target_if=min:remains,if=talent.subterfuge.enabled&(remains<12|pmultiplier<=1)&target.time_to_die-remains>2
    local function GarroteTargetIfFunc(TargetUnit)
      return TargetUnit:DebuffRemains(S.Garrote)
    end
    local function GarroteIfFunc(TargetUnit)
      return (TargetUnit:DebuffRemains(S.Garrote) < 12 or TargetUnit:PMultiplier(S.Garrote) <= 1)
        and (TargetUnit:FilteredTimeToDie(">", 2, -TargetUnit:DebuffRemains(S.Garrote)) or TargetUnit:TimeToDieIsNotValid())
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold)
    end
    if HR.AoEON() then
      local TargetIfUnit = CheckTargetIfTarget("min", GarroteTargetIfFunc, GarroteIfFunc)
      if TargetIfUnit and TargetIfUnit:GUID() ~= Target:GUID() then
        CastLeftNameplate(TargetIfUnit, S.Garrote)
      end
    end
    if GarroteIfFunc(Target) then
      if CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Cast Garrote (Subterfuge)" end
    end
    -- # Subterfuge + Exsg on 1T: Refresh Garrote at the end of stealth to get max duration before Exsanguinate
    -- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&active_enemies=1&buff.subterfuge.remains<1.3
    if S.Exsanguinate:IsAvailable() and MeleeEnemies10yCount == 1 and Player:BuffRemains(S.SubterfugeBuff) < 1.3 then
      if CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Pool for Garrote (Exsanguinate Refresh)" end
    end
  end
  -- actions.stealthed+=/mutilate,if=talent.subterfuge.enabled&combo_points<=3
  if S.Subterfuge:IsAvailable() and S.Mutilate:IsCastable() and ComboPoints <= 3 then
    if CastPooling(S.Mutilate) then return "Cast Mutilate (Subterfurge)" end
  end
end

-- # Damage over time abilities
local function Dot ()
  local SkipCycleGarrote, SkipCycleRupture, SkipRupture = false, false, false
  if PriorityRotation then
    -- # Limit secondary Garrotes for priority rotation if we have 35 energy regen or Garrote will expire on the primary target
    -- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&(dot.garrote.remains<cooldown.garrote.duration|energy.regen_combined>35)
    SkipCycleGarrote = MeleeEnemies10yCount > 3 and (Target:DebuffRemains(S.Garrote) < 6 or EnergyRegenSaturated)
    -- # Limit secondary Ruptures for priority rotation if we have 35 energy regen or Shiv is up on 2T+
    -- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&(debuff.shiv.up&spell_targets.fan_of_knives>2|energy.regen_combined>35)
    SkipCycleRupture = (Target:DebuffUp(S.ShivDebuff) and MeleeEnemies10yCount > 2) or EnergyRegenSaturated
  end
  -- # Limit Ruptures if Vendetta+Shiv/Master Assassin is up and we have 2+ seconds left on the Rupture DoT
  -- actions.dot+=/variable,name=skip_rupture,value=debuff.vendetta.up&(debuff.shiv.up|master_assassin_remains>0)&dot.rupture.remains>2
  SkipRupture = Target:DebuffUp(S.Vendetta) and (Target:DebuffUp(S.ShivDebuff) or MasterAssassinRemains() > 0) and Target:DebuffRemains(S.Rupture) > 2

  -- # Special Garrote and Rupture setup prior to Exsanguinate cast
  if HR.CDsON() and S.Exsanguinate:IsAvailable() then
    -- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!exsanguinated.garrote&dot.garrote.pmultiplier<=1&cooldown.exsanguinate.remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
    if S.Garrote:IsCastable() and Target:IsInMeleeRange(5) and MeleeEnemies10yCount == 1 and S.Exsanguinate:CooldownRemains() < 2 and not Rogue.Exsanguinated(Target, S.Garrote)
      and Target:PMultiplier(S.Garrote) <= 1 and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Garrote)*0.5) then
      if CastPooling(S.Garrote) then return "Cast Garrote (Pre-Exsanguinate)" end
    end
    -- actions.dot+=/rupture,if=talent.exsanguinate.enabled&(effective_combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1&dot.rupture.remains*0.5<target.time_to_die)
    if S.Rupture:IsReady() and Target:IsInMeleeRange(5) and ComboPoints > 0
      and (ComboPoints >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemains() < 1 and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Rupture)*0.5)) then
      if Cast(S.Rupture) then return "Cast Rupture (Pre-Exsanguinate)" end
    end
  end
  -- # Garrote upkeep, also tries to use it as a special generator for the last CP before a finisher
  -- actions.dot+=/pool_resource,for_next=1
  -- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>4&master_assassin_remains=0
  -- actions.dot+=/pool_resource,for_next=1
  -- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>12&master_assassin_remains=0
  if S.Garrote:IsCastable() and ComboPointsDeficit >= 1 then
    local function Evaluate_Garrote_Target(TargetUnit)
      return TargetUnit:DebuffRefreshable(S.Garrote)
        and (TargetUnit:PMultiplier(S.Garrote) <= 1 or (MeleeEnemies10yCount >= 3
          and TargetUnit:DebuffRemains(S.Garrote) <= (Rogue.Exsanguinated(TargetUnit, S.Garrote) and ExsanguinatedBleedTickTime or BleedTickTime)))
        and (not Rogue.Exsanguinated(TargetUnit, S.Garrote) or TargetUnit:DebuffRemains(S.Garrote) <= 1.5 and MeleeEnemies10yCount >= 3)
        and MasterAssassinRemains() <= 0
    end
    if Evaluate_Garrote_Target(Target) and Rogue.CanDoTUnit(Target, GarroteDMGThreshold)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      if CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Pool for Garrote (ST)" end
    end
    if HR.AoEON() and not SkipCycleGarrote then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 12, MeleeEnemies5y)
    end
  end
  -- # Crimson Tempest on multiple targets at 4+ CP when running out in 2-5s as long as we have enough regen and aren't setting up for Vendetta
  -- actions.dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>=2&effective_combo_points>=4&energy.regen_combined>20&(!cooldown.vendetta.ready|dot.rupture.ticking)&remains<2+3*(spell_targets>=4)
  if HR.AoEON() and S.CrimsonTempest:IsReady() and MeleeEnemies10yCount >= 2 and ComboPoints >= 4
    and EnergyRegenCombined > 20 and (not S.Vendetta:CooldownUp() or Target:DebuffUp(S.Rupture)) then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if CycleUnit:DebuffRemains(S.CrimsonTempest) < 2 + 3 * BoolToInt(MeleeEnemies10yCount >= 4) then
        if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE)" end
      end
    end
  end
  -- # Keep up Rupture at 4+ on all targets (when living long enough and not snapshot)
  -- actions.dot+=/rupture,if=!variable.skip_rupture&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(runeforge.dashing_scoundrel*5)+(runeforge.doomblade*5)+(variable.regen_saturated*6))
  -- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(runeforge.dashing_scoundrel*5)+(runeforge.doomblade*5)+(variable.regen_saturated*6))
  if not SkipRupture and S.Rupture:IsReady() and ComboPoints >= 4 then
    -- target.time_to_die-remains>(4+(runeforge.dashing_scoundrel*5)+(runeforge.doomblade*5)+(variable.regen_saturated*6))
    RuptureDurationThreshold = 4 + BoolToInt(DashingScoundrelEquipped) * 5 + BoolToInt(DoombladeEquipped) * 5 + BoolToInt(EnergyRegenSaturated) * 6
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshable(S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemains(S.Rupture) <= (Rogue.Exsanguinated(TargetUnit, S.Rupture) and ExsanguinatedBleedTickTime or BleedTickTime) and MeleeEnemies10yCount >= 3)
        and (not Rogue.Exsanguinated(TargetUnit, S.Rupture) or TargetUnit:DebuffRemains(S.Rupture) <= ExsanguinatedBleedTickTime * 2 and MeleeEnemies10yCount >= 3)
        and (TargetUnit:FilteredTimeToDie(">", RuptureDurationThreshold, -TargetUnit:DebuffRemains(S.Rupture)) or TargetUnit:TimeToDieIsNotValid())
    end
    if Evaluate_Rupture_Target(Target) and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if Cast(S.Rupture, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Rupture (Refresh)" end
    end
    if HR.AoEON() and not SkipCycleRupture then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, RuptureDurationThreshold, MeleeEnemies5y)
    end
  end
  -- # Fallback AoE Crimson Tempest with the same logic as above, but ignoring the energy conditions if we aren't using Rupture
  -- actions.dot+=/crimson_tempest,if=spell_targets>=2&effective_combo_points>=4&remains<2+3*(spell_targets>=4)
  if HR.AoEON() and S.CrimsonTempest:IsReady() and MeleeEnemies10yCount >= 2 and ComboPoints >= 4 then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      -- Note: The APL does not do this due to target_if mechanics, just to determine if any targets are low on duration of the AoE Bleed
      if CycleUnit:DebuffRemains(S.CrimsonTempest) < 2 + 3 * BoolToInt(MeleeEnemies10yCount >= 4) then
        if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE Fallback)" end
      end
    end
  end
  -- # Crimson Tempest on ST if in pandemic and nearly max energy and if Envenom won't do more damage due to TB/MA
  -- actions.dot+=/crimson_tempest,if=spell_targets=1&!runeforge.dashing_scoundrel&master_assassin_remains=0&effective_combo_points>=(cp_max_spend-1)&refreshable&!exsanguinated&!debuff.shiv.up&(energy.deficit<=25+variable.energy_regen_combined)&target.time_to_die-remains>4
  if S.CrimsonTempest:IsReady() and Target:IsInMeleeRange(10) and MeleeEnemies10yCount == 1
    and not DashingScoundrelEquipped and MasterAssassinRemains() <= 0
    and ComboPoints >= (Rogue.CPMaxSpend() - 1) and Target:DebuffRefreshable(S.CrimsonTempest, CrimsonTempestThreshold)
    and not Rogue.Exsanguinated(Target, S.CrimsonTempest) and not Target:DebuffUp(S.ShivDebuff)
    and Player:EnergyDeficitPredicted() <= 25 + EnergyRegenCombined
    and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.CrimsonTempest)) or Target:TimeToDieIsNotValid())
    and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
    if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (ST)" end
  end

  return false
end

-- # Direct damage abilities
local function Direct ()
  -- # Envenom at 4+ (5+ with DS) CP. Immediately on 2+ targets, with Vendetta, or with TB; otherwise wait for some energy. Also wait if Exsg combo is coming up.
  -- actions.direct=envenom,if=effective_combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.shiv.up|debuff.flagellation.up|energy.deficit<=25+variable.energy_regen_combined|!variable.single_target)&(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
  if S.Envenom:IsReady() and ComboPoints >= 4 + BoolToInt(S.DeeperStratagem:IsAvailable())
    and (Target:DebuffUp(S.Vendetta) or Target:DebuffUp(S.ShivDebuff) or Target:DebuffUp(S.Flagellation)
      or Player:BuffUp(S.Flagellation) or Player:BuffUp(S.MarrowedGemstoneBuff)
      or Player:EnergyDeficitPredicted() <= (25 + EnergyRegenCombined) or not SingleTarget)
    and (not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemains() > 2 or not HR.CDsON()) then
    if Cast(S.Envenom, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Envenom" end
  end

  --- !!!! ---
  -- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|!variable.single_target
  -- Note: This is used in all following fillers, so we just return false if not true and won't consider these.
  if not (ComboPointsDeficit > 1 or Player:EnergyDeficitPredicted() <= 25 + EnergyRegenCombined or not SingleTarget) then
    return false
  end
  --- !!!! ---

  if S.SerratedBoneSpike:IsReady() then
    -- actions.direct+=/serrated_bone_spike,if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
    if not Target:DebuffUp(S.SerratedBoneSpikeDebuff) then
      if Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsInMeleeRange(10)) then return "Cast Serrated Bone Spike" end
    else
      -- actions.direct+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
      if HR.AoEON() then
        if Everyone.CastTargetIf(S.SerratedBoneSpike, Enemies30y, "min", EvaluateSBSTargetIfConditionCondition, EvaluateSBSCondition) then
          return "Cast Serrated Bone (AoE)"
        end
      end
      -- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&(fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75|soulbind.lead_by_example.enabled&!buff.lead_by_example.up&debuff.vendetta.up)
      if MasterAssassinRemains() < 0.8 and (HL.BossFightRemains() <= 5 or S.SerratedBoneSpike:ChargesFractional() >= 2.75
        or (S.LeadbyExample:SoulbindEnabled() and not Player:BuffUp(S.LeadbyExampleBuff) and Target:DebuffUp(S.Vendetta)) or Player:BuffUp(S.MarrowedGemstoneBuff)) then
        if Cast(S.SerratedBoneSpike, nil, Settings.Commons.SerratedBoneSpikeDumpDisplayStyle, not Target:IsInMeleeRange(10)) then return "Cast Serrated Bone Spike (Filler)" end
      end
    end
  end
  if S.FanofKnives:IsCastable() then
    -- # Fan of Knives at 19+ stacks of Hidden Blades or against 4+ targets.
    -- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|(!priority_rotation&spell_targets.fan_of_knives>=4+stealthed.rogue))
    if HR.AoEON() and (Player:BuffStack(S.HiddenBladesBuff) >= 19 and MeleeEnemies10yCount >= 1
      or (not PriorityRotation and MeleeEnemies10yCount >= 4 + BoolToInt(DoombladeEquipped and S.CrimsonTempest:IsAvailable()) + BoolToInt(Player:StealthUp(true, false)))) then
      if CastPooling(S.FanofKnives) then return "Cast Fan of Knives" end
    end
    -- # Fan of Knives to apply poisons if inactive on any target (or any bleeding targets with priority rotation) at 3T
    -- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking&(!priority_rotation|dot.garrote.ticking|dot.rupture.ticking),if=variable.use_filler&spell_targets.fan_of_knives>=3
    if HR.AoEON() and Player:BuffUp(S.DeadlyPoison) and MeleeEnemies10yCount >= 3 then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        if not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff, true) and (not PriorityRotation or CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) then
          if CastPooling(S.FanofKnives) then return "Cast Fan of Knives (DP Refresh)" end
        end
      end
    end
  end
  -- actions.direct+=/echoing_reprimand,if=variable.use_filler&cooldown.vendetta.remains>10
  if CDsON() and S.EchoingReprimand:IsReady() and S.Vendetta:CooldownRemains() > 10 then
    if Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsInMeleeRange(5)) then return "Cast Echoing Reprimand" end
  end
  -- actions.direct+=/ambush,if=variable.use_filler&(master_assassin_remains=0&!runeforge.doomblade|buff.blindside.up)
  if S.Ambush:IsCastable() and (MasterAssassinRemains() <= 0 and not DoombladeEquipped and Player:StealthUp(true, true) or Player:BuffUp(S.BlindsideBuff)) then
    if CastPooling(S.Ambush, nil, not Target:IsInMeleeRange(5)) then return "Cast Ambush" end
  end
  -- # Tab-Mutilate to apply Deadly Poison at 2 targets
  -- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives=2
  if S.Mutilate:IsCastable() and MeleeEnemies10yCount == 2 and Target:DebuffUp(S.DeadlyPoisonDebuff, true) then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(MeleeEnemies5y) do
      -- Note: The APL does not do this due to target_if mechanics, but since we are cycling we should check to see if the unit has a bleed
      if CycleUnit:GUID() ~= TargetGUID and (CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) and not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff, true) then
        CastLeftNameplate(CycleUnit, S.Mutilate)
        break
      end
    end
  end
  -- actions.direct+=/mutilate,if=variable.use_filler
  if S.Mutilate:IsCastable() then
    if CastPooling(S.Mutilate, nil, not Target:IsInMeleeRange(5)) then return "Cast Mutilate" end
  end

  return false
end

--- ======= MAIN =======
local function APL ()
  -- Enemies Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Poisoned Knife & Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10) -- Fan of Knives & Crimson Tempest
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(5) -- Melee cycle
  else
    Enemies30y = {}
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 1
    MeleeEnemies5y = {}
  end

  -- Rotation Variables Update
  Stealth = S.Subterfuge:IsAvailable() and S.Stealth2 or S.Stealth; -- w/ or w/o Subterfuge Talent
  BleedTickTime, ExsanguinatedBleedTickTime = 2 / Player:SpellHaste(), 1 / Player:SpellHaste()
  ComboPoints = Rogue.EffectiveComboPoints(Player:ComboPoints())
  ComboPointsDeficit = Player:ComboPointsMax() - ComboPoints
  RuptureThreshold = (4 + ComboPoints * 4) * 0.3
  CrimsonTempestThreshold = (2 + ComboPoints * 2) * 0.3
  RuptureDMGThreshold = S.Envenom:Damage() * Settings.Assassination.EnvenomDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.
  GarroteDMGThreshold = S.Mutilate:Damage() * Settings.Assassination.MutilateDMGOffset; -- Used as TTD Not Valid fallback since it's a generator.
  PriorityRotation = UsePriorityRotation()

  -- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial()
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint()
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  Rogue.Poisons()

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- actions=stealth
    if not Player:BuffUp(S.VanishBuff) then
      ShouldReturn = Rogue.Stealth(Stealth)
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then
      -- Precombat CDs
      if HR.CDsON() then
        if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() and Everyone.TargetIsValid() then
          if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
      end
    end
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath)
  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons2.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    PoisonedBleeds = Rogue.PoisonedBleeds()
    -- TODO: Make this match the updated code version
    EnergyRegenCombined = Player:EnergyRegen() + PoisonedBleeds * 8 / (2 * Player:SpellHaste())
    -- actions+=/variable,name=regen_saturated,value=energy.regen_combined>35
    EnergyRegenSaturated = EnergyRegenCombined > 35
    -- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
    SingleTarget = MeleeEnemies10yCount < 2

    -- actions+=/call_action_list,name=stealthed,if=stealthed.rogue
    if Player:StealthUp(true, false) then
      ShouldReturn = Stealthed()
      if ShouldReturn then return ShouldReturn .. " (Stealthed)" end
    end
    -- actions+=/call_action_list,name=cds,if=(!talent.master_assassin.enabled|dot.garrote.ticking)
    if not S.MasterAssassin:IsAvailable() or Target:DebuffUp(S.Garrote) then
      ShouldReturn = CDs()
      if ShouldReturn then return ShouldReturn end
    end
    -- # Put SnD up initially for Cut to the Chase, refresh with Envenom if at low duration
    -- actions+=/slice_and_dice,if=!buff.slice_and_dice.up&combo_points>=1
    if not Player:BuffUp(S.SliceandDice) then
      if S.SliceandDice:IsReady() and ComboPoints >= 1 then
        if Cast(S.SliceandDice) then return "Cast Slice and Dice" end
      end
    elseif Target:IsInMeleeRange(10) then
      -- actions+=/envenom,if=buff.slice_and_dice.up&buff.slice_and_dice.remains<5&combo_points>=4
      if S.Envenom:IsReady() and Player:BuffRemains(S.SliceandDice) < 5 and ComboPoints >= 4 then
        if Cast(S.Envenom, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Envenom (CttC)" end
      end
    else
      --- !!!! ---
      -- Special fallback Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
      -- Only if we are about to cap energy, not stealthed, and completely out of range
      --- !!!! ---
      if S.PoisonedKnife:IsCastable() and Target:IsInRange(30) and not Player:StealthUp(true, true)
        and MeleeEnemies10yCount == 0 and Player:EnergyTimeToMax() <= Player:GCD() * 1.5 then
        if Cast(S.PoisonedKnife) then return "Cast Poisoned Knife" end
      end
    end
    -- actions+=/call_action_list,name=dot
    ShouldReturn = Dot()
    if ShouldReturn then return ShouldReturn end
    -- actions+=/call_action_list,name=direct
    ShouldReturn = Direct()
    if ShouldReturn then return ShouldReturn end
    -- Racials
    if HR.CDsON() then
      -- actions+=/arcane_torrent,if=energy.deficit>=15+variable.energy_regen_combined
      if S.ArcaneTorrent:IsCastable() and Target:IsInMeleeRange(5) and Player:EnergyDeficitPredicted() > 15 + EnergyRegenCombined then
        if Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastable() and Target:IsInMeleeRange(5) then
        if Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
        if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
        if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
      end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.Mutilate:IsCastable() and Target:IsInMeleeRange(10) then
      if Cast(S.PoolEnergy) then return "Normal Pooling" end
    end
  end
end

local function Init ()
  S.Vendetta:RegisterAuraTracking()
  S.Sepsis:RegisterAuraTracking()
end

HR.SetAPL(259, APL, Init)

--- ======= SIMC =======
-- Last Update: 04/11/2021

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>15
-- actions.precombat+=/variable,name=vendetta_cdr,value=1-(runeforge.duskwalkers_patch*0.45)
-- # Determine which (if any) stat buff trinket we want to attempt to sync with Vendetta.
-- actions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
-- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
-- actions.precombat+=/stealth
-- actions.precombat+=/slice_and_dice,precombat_seconds=1

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
-- actions+=/call_action_list,name=stealthed,if=stealthed.rogue
-- actions+=/call_action_list,name=cds,if=(!talent.master_assassin.enabled|dot.garrote.ticking)
-- # Put SnD up initially for Cut to the Chase, refresh with Envenom if at low duration
-- actions+=/slice_and_dice,if=!buff.slice_and_dice.up&combo_points>=3
-- actions+=/envenom,if=buff.slice_and_dice.up&buff.slice_and_dice.remains<5&combo_points>=4
-- actions+=/call_action_list,name=dot
-- actions+=/call_action_list,name=direct
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen_combined
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Cooldowns
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds=marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit*1.5|combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
-- # Sync Flagellation with Vendetta as long as we won't lose a cast over the fight duration
-- actions.cds+=/flagellation,if=!stealthed.rogue&(cooldown.vendetta.remains<3&effective_combo_points>=4&target.time_to_die>10|debuff.vendetta.up|fight_remains<24)
-- actions.cds+=/flagellation,if=!stealthed.rogue&effective_combo_points>=4&(floor((fight_remains-24)%cooldown)>floor((fight_remains-24-cooldown.vendetta.remains*variable.vendetta_cdr)%cooldown))
-- # Sync Sepsis with Vendetta as long as we won't lose a cast over the fight duration, but prefer targets that will live at least 10s
-- actions.cds+=/sepsis,if=!stealthed.rogue&(cooldown.vendetta.remains<1&target.time_to_die>10|debuff.vendetta.up|fight_remains<10)
-- actions.cds+=/sepsis,if=!stealthed.rogue&(floor((fight_remains-10)%cooldown)>floor((fight_remains-10-cooldown.vendetta.remains*variable.vendetta_cdr)%cooldown))
-- # Sync Vendetta window with Nightstalker+Exsanguinate if applicable
-- actions.cds+=/variable,name=vendetta_nightstalker_condition,value=!talent.nightstalker.enabled|!talent.exsanguinate.enabled|cooldown.exsanguinate.remains<5-2*talent.deeper_stratagem.enabled
-- # Sync Vendetta with Flagellation and Sepsis as long as we won't lose a cast over the fight duration
-- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.kyrian|covenant.necrolord|covenant.none,value=1
-- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.venthyr,value=floor((fight_remains-20)%(120*variable.vendetta_cdr))>floor((fight_remains-20-cooldown.flagellation.remains)%(120*variable.vendetta_cdr))|buff.flagellation_buff.up|debuff.flagellation.up|fight_remains<20
-- actions.cds+=/variable,name=vendetta_covenant_condition,if=covenant.night_fae,value=floor((fight_remains-20)%(120*variable.vendetta_cdr))>floor((fight_remains-20-cooldown.sepsis.remains)%(120*variable.vendetta_cdr))|dot.sepsis.ticking|fight_remains<20
-- actions.cds+=/vendetta,if=!stealthed.rogue&dot.rupture.ticking&!debuff.vendetta.up&variable.vendetta_nightstalker_condition&variable.vendetta_covenant_condition
-- # Exsanguinate when not stealthed and both Rupture and Garrote are up for long enough.
-- actions.cds+=/exsanguinate,if=!stealthed.rogue&(!dot.garrote.refreshable&dot.rupture.remains>4+4*cp_max_spend|dot.rupture.remains*0.5>target.time_to_die)&target.time_to_die>4
-- # Shiv if we are about to Envenom, and attempt to sync with Sepsis final hit if we won't waste more than half the cooldown.
-- actions.cds+=/shiv,if=dot.rupture.ticking&(!cooldown.sepsis.ready|cooldown.vendetta.remains>12)|dot.sepsis.ticking
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|debuff.vendetta.up
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/fireblood,if=debuff.vendetta.up
-- actions.cds+=/ancestral_call,if=debuff.vendetta.up
-- actions.cds+=/call_action_list,name=vanish,if=!stealthed.all&master_assassin_remains=0
-- # Sync the priority stat buff trinket with Vendetta, otherwise use on cooldown
-- actions.cds+=/use_items,slots=trinket1,if=variable.trinket_sync_slot=1&(debuff.vendetta.up|fight_remains<=20)|(variable.trinket_sync_slot=2&!trinket.2.cooldown.ready)|!variable.trinket_sync_slot
-- actions.cds+=/use_items,slots=trinket2,if=variable.trinket_sync_slot=2&(debuff.vendetta.up|fight_remains<=20)|(variable.trinket_sync_slot=1&!trinket.1.cooldown.ready)|!variable.trinket_sync_slot

-- # Direct damage abilities
-- # Envenom at 4+ (5+ with DS) CP. Immediately on 2+ targets, with Vendetta, or with TB; otherwise wait for some energy. Also wait if Exsg combo is coming up.
-- actions.direct=envenom,if=effective_combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.shiv.up|debuff.flagellation.up|energy.deficit<=25+energy.regen_combined|!variable.single_target)&(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2)
-- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+energy.regen_combined|!variable.single_target
-- # Apply SBS to all targets without a debuff as priority, preferring targets dying sooner after the primary target
-- actions.direct+=/serrated_bone_spike,if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
-- actions.direct+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
-- # When MA is not at high duration, use SBS to apply Lead by Example during Vendetta, otherwise keep from capping charges
-- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&(fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75|soulbind.lead_by_example.enabled&!buff.lead_by_example.up&debuff.vendetta.up|buff.marrowed_gemstone_enhancement.up)
-- # Fan of Knives at 19+ stacks of Hidden Blades or against 4+ targets.
-- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|(!priority_rotation&spell_targets.fan_of_knives>=4+stealthed.rogue))
-- # Fan of Knives to apply poisons if inactive on any target (or any bleeding targets with priority rotation) at 3T
-- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking&(!priority_rotation|dot.garrote.ticking|dot.rupture.ticking),if=variable.use_filler&spell_targets.fan_of_knives>=3
-- actions.direct+=/echoing_reprimand,if=variable.use_filler&cooldown.vendetta.remains>10
-- actions.direct+=/ambush,if=variable.use_filler&(master_assassin_remains=0&!runeforge.doomblade|buff.blindside.up)
-- # Tab-Mutilate to apply Deadly Poison at 2 targets
-- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives=2
-- actions.direct+=/mutilate,if=variable.use_filler

-- # Damage over time abilities
-- # Limit secondary Garrotes for priority rotation if we have 35 energy regen or Garrote will expire on the primary target
-- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&(dot.garrote.remains<cooldown.garrote.duration|energy.regen_combined>35)
-- # Limit secondary Ruptures for priority rotation if we have 35 energy regen or Shiv is up on 2T+
-- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&(debuff.shiv.up&spell_targets.fan_of_knives>2|energy.regen_combined>35)
-- # Limit Ruptures if Vendetta+Shiv/Master Assassin is up and we have 2+ seconds left on the Rupture DoT
-- actions.dot+=/variable,name=skip_rupture,value=debuff.vendetta.up&(debuff.shiv.up|master_assassin_remains>0)&dot.rupture.remains>2
-- # Special Garrote and Rupture setup prior to Exsanguinate cast
-- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!exsanguinated.garrote&dot.garrote.pmultiplier<=1&cooldown.exsanguinate.remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
-- actions.dot+=/rupture,if=talent.exsanguinate.enabled&(effective_combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1&dot.rupture.remains*0.5<target.time_to_die)
-- # Garrote upkeep, also tries to use it as a special generator for the last CP before a finisher
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>4&master_assassin_remains=0
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>12&master_assassin_remains=0
-- # Crimson Tempest on multiple targets at 4+ CP when running out in 2-3s as long as we have enough regen and aren't setting up for Vendetta
-- actions.dot+=/crimson_tempest,if=spell_targets>=2&remains<2+(spell_targets>=5)&effective_combo_points>=4&energy.regen_combined>20&(!cooldown.vendetta.ready|dot.rupture.ticking)
-- # Keep up Rupture at 4+ on all targets (when living long enough and not snapshot)
-- actions.dot+=/rupture,if=!variable.skip_rupture&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+runeforge.dashing_scoundrel*9+runeforge.doomblade*6)
-- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+runeforge.dashing_scoundrel*9+runeforge.doomblade*6)
-- # Fallback AoE Crimson Tempest with the same logic as above, but ignoring the energy conditions if we aren't using Rupture
-- actions.dot+=/crimson_tempest,if=spell_targets>=2&remains<2+(spell_targets>=5)&effective_combo_points>=4
-- # Crimson Tempest on ST if in pandemic and nearly max energy and if Envenom won't do more damage due to TB/MA
-- actions.dot+=/crimson_tempest,if=spell_targets=1&!runeforge.dashing_scoundrel&master_assassin_remains=0&effective_combo_points>=(cp_max_spend-1)&refreshable&!exsanguinated&!debuff.shiv.up&(energy.deficit<=25+energy.regen_combined)&target.time_to_die-remains>4

-- # Stealthed Actions
-- # Nighstalker on 3T: Crimson Tempest
-- actions.stealthed=crimson_tempest,if=talent.nightstalker.enabled&spell_targets>=3&combo_points>=4&target.time_to_die-remains>6
-- # Nighstalker on 1T: Snapshot Rupture
-- actions.stealthed+=/rupture,if=talent.nightstalker.enabled&combo_points>=4&target.time_to_die-remains>6
-- # Subterfuge: Apply or Refresh with buffed Garrotes
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,target_if=min:remains,if=talent.subterfuge.enabled&(remains<12|pmultiplier<=1)&target.time_to_die-remains>2
-- # Subterfuge + Exsg on 1T: Refresh Garrote at the end of stealth to get max duration before Exsanguinate
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&active_enemies=1&buff.subterfuge.remains<1.3
-- actions.stealthed+=/mutilate,if=talent.subterfuge.enabled&combo_points<=3

-- # Vanish
-- # Finish with max CP for Nightstalker, unless using Deathly Shadows
-- actions.vanish=variable,name=nightstalker_cp_condition,value=(!runeforge.deathly_shadows&effective_combo_points>=cp_max_spend)|(runeforge.deathly_shadows&combo_points<2)
-- # Vanish with Exsg + Nightstalker: Maximum CP and Exsg ready for next GCD
-- actions.vanish+=/vanish,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&variable.nightstalker_cp_condition&cooldown.exsanguinate.remains<1
-- # Vanish with Nightstalker + No Exsg: Maximum CP and Vendetta up
-- actions.vanish+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&variable.nightstalker_cp_condition&debuff.vendetta.up
-- actions.vanish+=/pool_resource,for_next=1,extra_amount=45
-- actions.vanish+=/vanish,if=talent.subterfuge.enabled&cooldown.garrote.up&(dot.garrote.refreshable|debuff.vendetta.up&dot.garrote.pmultiplier<=1)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)&raid_event.adds.in>12
-- # Vanish with Master Assasin: Rupture+Garrote not in refresh range, during Vendetta+Shiv. Sync with Sepsis final hit if possible.
-- actions.vanish+=/vanish,if=(talent.master_assassin.enabled|runeforge.mark_of_the_master_assassin)&!dot.rupture.refreshable&dot.garrote.remains>3&debuff.vendetta.up&(debuff.shiv.up|debuff.vendetta.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3
