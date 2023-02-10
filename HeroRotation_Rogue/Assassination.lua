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
local CastLeftNameplate = HR.CastLeftNameplate
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local pairs = pairs
local mathfloor = math.floor
local mathmax = math.max

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
  I.AlgetharPuzzleBox,
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
local ExsanguinateSyncRemains, PoisonedBleeds, EnergyRegenCombined, EnergyTimeToMaxCombined, EnergyRegenSaturated, SingleTarget
local TrinketSyncSlot = 0

-- Covenant and Legendaries
local Equipment = Player:GetEquipment()
local TrinketItem1 = Equipment[13] and Item(Equipment[13]) or Item(0)
local TrinketItem2 = Equipment[14] and Item(Equipment[14]) or Item(0)
local function SetTrinketVariables ()
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  if TrinketItem1:TrinketHasStatAnyDps() and (not TrinketItem2:TrinketHasStatAnyDps() or TrinketItem1:Cooldown() >= TrinketItem2:Cooldown()) then
    TrinketSyncSlot = 1
  elseif TrinketItem2:TrinketHasStatAnyDps() and (not TrinketItem1:TrinketHasStatAnyDps() or TrinketItem2:Cooldown() > TrinketItem1:Cooldown()) then
    TrinketSyncSlot = 2
  else
    TrinketSyncSlot = 0
  end
end
SetTrinketVariables()

HL:RegisterForEvent(function()
  Equipment = Player:GetEquipment()
  TrinketItem1 = Equipment[13] and Item(Equipment[13]) or Item(0)
  TrinketItem2 = Equipment[14] and Item(Equipment[14]) or Item(0)
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED" )

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
      0.22 *
      -- Aura Multiplier (SpellID: 137037)
      1.0 *
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
      0.485 *
      -- Aura Multiplier (SpellID: 137037)
      1.0 *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct()/100)
  end
)

-- Master Assassin Remains Check
local function MasterAssassinRemains ()
  -- Currently stealthed (i.e. Aura)
  if Player:BuffRemains(S.MasterAssassinBuff) == 9999 then
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

local function ComputeImprovedGarrotePMultiplier ()
  if S.ImprovedGarrote:IsAvailable() and (Player:BuffUp(S.ImprovedGarroteAura, nil, true)
    or Player:BuffUp(S.ImprovedGarroteBuff, nil, true) or Player:BuffUp(S.SepsisBuff, nil, true)) then
    return 1.5
  end
  return 1
end
S.Garrote:RegisterPMultiplier(ComputeImprovedGarrotePMultiplier)

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

-- actions+=/variable,name=exsang_sync_remains,op=setif,condition=cooldown.deathmark.remains>cooldown.exsanguinate.remains&cooldown.deathmark.remains<fight_remains,value=cooldown.deathmark.remains,value_else=cooldown.exsanguinate.remains
local function ExsangSyncRemains()
  if S.Deathmark:CooldownRemains() > S.Exsanguinate:CooldownRemains()
    and (HL.BossFightRemainsIsNotValid() or HL.BossFilteredFightRemains(">", S.Deathmark:CooldownRemains())) then
    return S.Deathmark:CooldownRemains()
  end
  return S.Exsanguinate:CooldownRemains()
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

-- # Determine if we should be be casting our pre-Exsanguinate Rupture with Echoing Reprimand CP
local function ExsanguinateRuptureCP ()
  -- actions.precombat+=/variable,name=exsanguinate_rupture_cp,value=cp_max_spend<?(talent.resounding_clarity*7)
  return S.ResoundingClarity:IsAvailable() and 7 or Rogue.CPMaxSpend()
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
  if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
    if S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp() and not Rogue.Exsanguinated(Target, S.Garrote)
      and (Target:PMultiplier(S.Garrote) <= 1 or IsDebuffRefreshable(Target, S.Garrote)) then
      -- actions.vanish+=/vanish,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&(debuff.deathmark.up|cooldown.deathmark.remains<4)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)
      if (S.Deathmark:AnyDebuffUp() or S.Deathmark:CooldownRemains() < 4) and ComboPointsDeficit >= math.min(MeleeEnemies10yCount, 4) then
        -- actions.cds+=/pool_resource,for_next=1,extra_amount=45
        if Settings.Commons.ShowPooling and Player:EnergyPredicted() < 45 then
          if Cast(S.PoolEnergy) then return "Pool for Vanish (Garrote Deathmark)" end
        end
        if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Garrote Deathmark)" end
      end
      -- actions.vanish+=/vanish,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&spell_targets.fan_of_knives>(3-talent.indiscriminate_carnage)&(!talent.indiscriminate_carnage|cooldown.indiscriminate_carnage.ready)
      if MeleeEnemies10yCount > (3 - BoolToInt(S.IndiscriminateCarnage:IsAvailable())) and (not S.IndiscriminateCarnage:IsAvailable() or S.IndiscriminateCarnage:CooldownUp()) then
        -- actions.cds+=/pool_resource,for_next=1,extra_amount=45
        if Settings.Commons.ShowPooling and Player:EnergyPredicted() < 45 then
          if Cast(S.PoolEnergy) then return "Pool for Vanish (Garrote)" end
        end
        if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Garrote)" end
      end
    end
    -- actions.vanish+=/vanish,if=!talent.improved_garrote&talent.master_assassin&!dot.rupture.refreshable&dot.garrote.remains>3&debuff.deathmark.up&(debuff.shiv.up|debuff.deathmark.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3
    if not S.ImprovedGarrote:IsAvailable() and S.MasterAssassin:IsAvailable() and not IsDebuffRefreshable(Target, S.Rupture) and Target:DebuffRemains(S.Garrote) > 3
      and Target:DebuffUp(S.Deathmark) and (Target:DebuffUp(S.ShivDebuff) or Target:DebuffRemains(S.Deathmark) < 4 or Target:DebuffUp(S.Sepsis)) and Target:DebuffRemains(S.Sepsis) < 3 then
      if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Master Assassin)" end
    end
  end
  if S.ShadowDance:IsCastable() then
    -- actions.vanish+=/shadow_dance,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&(debuff.deathmark.up|cooldown.deathmark.remains<12|cooldown.deathmark.remains>60)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)
    if S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp() and not Rogue.Exsanguinated(Target, S.Garrote) and Target:PMultiplier(S.Garrote) <= 1
      and (S.Deathmark:AnyDebuffUp() or S.Deathmark:CooldownRemains() < 12 or S.Deathmark:CooldownRemains() > 60) and ComboPointsDeficit >= math.min(MeleeEnemies10yCount, 4) then
      if Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance (Garrote)" end
    end
    -- actions.vanish+=/shadow_dance,if=!talent.improved_garrote&talent.master_assassin&!dot.rupture.refreshable&dot.garrote.remains>3&(debuff.deathmark.up|cooldown.deathmark.remains>60)&(debuff.shiv.up|debuff.deathmark.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3
    if not S.ImprovedGarrote:IsAvailable() and S.MasterAssassin:IsAvailable() and not IsDebuffRefreshable(Target, S.Rupture)
      and Target:DebuffRemains(S.Garrote) > 3 and (Target:DebuffUp(S.Deathmark) or S.Deathmark:CooldownRemains() > 60)
      and (Target:DebuffUp(S.ShivDebuff) or Target:DebuffRemains(S.Deathmark) < 4 or Target:DebuffUp(S.Sepsis)) and Target:DebuffRemains(S.Sepsis) < 3 then
      if Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance (Master Assassin)" end
    end
  end
end

-- # Cooldowns
local function CDs ()
  if S.MarkedforDeath:IsCastable() then
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit*1.5|combo_points.deficit>=cp_max_spend)
    if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit() * 1.5) then
      if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
    end
    -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
    if ComboPointsDeficit >= Rogue.CPMaxSpend() then
      if not Settings.Commons.STMfDAsDPSCD then
        HR.CastSuggested(S.MarkedforDeath)
      elseif HR.CDsON() then
        if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      end
    end
  end

  if not TargetInAoERange or not HR.CDsON() then
    return
  end

  if not Player:StealthUp(true, false) then
    -- actions.cds+=/sepsis,if=!stealthed.rogue&!stealthed.improved_garrote&(!talent.improved_garrote&dot.garrote.ticking|talent.improved_garrote&cooldown.garrote.up)&(target.time_to_die>10|fight_remains<10)
    if S.Sepsis:IsReady() and ImprovedGarroteRemains() == 0 and (S.ImprovedGarrote:IsAvailable() and S.Garrote:CooldownUp() or Target:DebuffUp(S.Garrote))
      and (Target:FilteredTimeToDie(">", 10) or HL.BossFilteredFightRemains("<=", 10)) then
      if Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis" end
    end

    -- actions.cds+=/use_item,name=algethar_puzzle_box,use_off_gcd=1,if=(!talent.exsanguinate|cooldown.exsanguinate.remains>15|exsanguinated.rupture|exsanguinated.garrote)&dot.rupture.ticking&cooldown.deathmark.remains<2|fight_remains<=22
    -- actions.cds+=/use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
    -- actions.cds+=/use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
    if Settings.Commons.UseTrinkets then
      if I.AlgetharPuzzleBox:IsEquippedAndReady() and (((not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemains() > 15
        or Rogue.Exsanguinated(Target, S.Rupture) or Rogue.Exsanguinated(Target, S.Garrote)) and Target:DebuffUp(S.Rupture)
        and S.Deathmark:CooldownRemains() <= 2) or HL.BossFilteredFightRemains("<", 22)) then
        if HR.Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.TrinketDisplayStyle) then return "Algethar Puzzle Box"; end
      end
      if TrinketItem1:IsReady() and not Player:IsTrinketBlacklisted(TrinketItem1) and not ValueIsInArray(OnUseExcludeTrinkets, TrinketItem1:ID())
        and (TrinketSyncSlot == 1 and (S.Deathmark:AnyDebuffUp() or HL.BossFilteredFightRemains("<", 20))
          or (TrinketSyncSlot == 2 and (not TrinketItem2:IsReady() or not S.Deathmark:AnyDebuffUp() and S.Deathmark:CooldownRemains() > 20)) or TrinketSyncSlot == 0) then
        if Cast(TrinketItem1, nil, Settings.Commons.TrinketDisplayStyle) then return "Trinket 1"; end
      elseif TrinketItem2:IsReady() and not Player:IsTrinketBlacklisted(TrinketItem2) and not ValueIsInArray(OnUseExcludeTrinkets, TrinketItem2:ID())
        and (TrinketSyncSlot == 2 and (S.Deathmark:AnyDebuffUp() or HL.BossFilteredFightRemains("<", 20))
          or (TrinketSyncSlot == 1 and (not TrinketItem1:IsReady() or not S.Deathmark:AnyDebuffUp() and S.Deathmark:CooldownRemains() > 20)) or TrinketSyncSlot == 0) then
        if Cast(TrinketItem2, nil, Settings.Commons.TrinketDisplayStyle) then return "Trinket 2"; end
      end
    end

    if S.Deathmark:IsCastable() then
      -- actions.cds+=/variable,name=deathmark_exsanguinate_condition,value=!talent.exsanguinate|cooldown.exsanguinate.remains>15|exsanguinated.rupture|exsanguinated.garrote
      -- actions.cds+=/variable,name=deathmark_ma_condition,value=!talent.master_assassin.enabled|dot.garrote.ticking
      -- actions.cds+=/variable,name=deathmark_condition,value=!stealthed.rogue&dot.rupture.ticking&!debuff.deathmark.up&variable.deathmark_exsanguinate_condition&variable.deathmark_ma_condition
      -- actions.cds+=/deathmark,if=variable.deathmark_condition
      if Target:DebuffUp(S.Rupture) and not S.Deathmark:AnyDebuffUp()
        and (not S.Exsanguinate:IsAvailable() or S.Exsanguinate:CooldownRemains() > 15 or Rogue.Exsanguinated(Target, S.Rupture) or Rogue.Exsanguinated(Target, S.Garrote))
        and (not S.MasterAssassin:IsAvailable() or Target:DebuffUp(S.Garrote)) then
        if Cast(S.Deathmark, Settings.Assassination.OffGCDasOffGCD.Deathmark) then return "Cast Deathmark" end
      end
    end
    -- actions.cds+=/kingsbane,if=(debuff.shiv.up|cooldown.shiv.remains<6)&buff.envenom.up&(cooldown.deathmark.remains>=50|dot.deathmark.ticking)
    if S.Kingsbane:IsReady() and (Target:DebuffUp(S.ShivDebuff) or S.Shiv:CooldownRemains() < 6) and Player:BuffUp(S.Envenom)
      and (S.Deathmark:CooldownRemains() >= 50 or Target:DebuffUp(S.Deathmark)) then
      if Cast(S.Kingsbane, Settings.Assassination.GCDasOffGCD.Kingsbane) then return "Cast Kingsbane" end
    end
    -- actions.cds+=/variable,name=exsanguinate_condition,value=talent.exsanguinate&!stealthed.rogue&!stealthed.improved_garrote&!dot.deathmark.ticking&target.time_to_die>variable.exsang_sync_remains+4&variable.exsang_sync_remains<4
    -- actions.cds+=/echoing_reprimand,if=talent.exsanguinate&talent.resounding_clarity&(variable.exsanguinate_condition&combo_points<=2&variable.exsang_sync_remains<=2&!dot.garrote.refreshable&dot.rupture.remains>9.6|variable.exsang_sync_remains>40)
    -- actions.cds+=/exsanguinate,if=variable.exsanguinate_condition&(!dot.garrote.refreshable&dot.rupture.remains>4+4*variable.exsanguinate_rupture_cp|dot.rupture.remains*0.5>target.time_to_die)    
    if S.Exsanguinate:IsAvailable() then
      if ImprovedGarroteRemains() == 0 and Target:DebuffDown(S.Deathmark) and Target:FilteredTimeToDie(">", ExsanguinateSyncRemains + 4) and ExsanguinateSyncRemains < 4 then
        if S.ResoundingClarity:IsAvailable() and S.EchoingReprimand:IsReady()
          and Player:ComboPoints() <= 2 and ExsanguinateSyncRemains <= 2
          and not IsDebuffRefreshable(Target, S.Garrote) and Target:DebuffRemains(S.Rupture) > 9.6 then
          if Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle, not TargetInMeleeRange) then return "Cast Echoing Reprimand (Exsang Sync)" end
        end
        if S.Exsanguinate:IsReady() and not IsDebuffRefreshable(Target, S.Garrote) and Target:DebuffRemains(S.Rupture) > 4 + 4 * ExsanguinateRuptureCP()
          or Target:FilteredTimeToDie("<", Target:DebuffRemains(S.Rupture)*0.5) then
          if Cast(S.Exsanguinate, Settings.Assassination.GCDasOffGCD.Exsanguinate) then return "Cast Exsanguinate" end
        end
      end
      if S.ResoundingClarity:IsAvailable() and S.EchoingReprimand:IsReady() and ExsanguinateSyncRemains > 40 then
        if Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle, not TargetInMeleeRange) then return "Cast Echoing Reprimand (Exsang Desync)" end
      end
    end
  end
  -- actions.cds+=/shiv,if=talent.kingsbane&!debuff.shiv.up&dot.kingsbane.ticking&dot.garrote.ticking&dot.rupture.ticking&(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)
  -- actions.cds+=/shiv,if=talent.arterial_precision&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&(debuff.deathmark.up|cooldown.shiv.charges_fractional>max_charges-0.5&cooldown.deathmark.remains>10)
  -- actions.cds+=/shiv,if=talent.sepsis&!talent.kingsbane&!talent.arterial_precision&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&((cooldown.sepsis.ready|cooldown.sepsis.remains>12)+(cooldown.deathmark.ready|cooldown.deathmark.remains>12)=2)
  -- actions.cds+=/shiv,if=!talent.kingsbane&!talent.arterial_precision&!talent.sepsis&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)&(!talent.exsanguinate|variable.exsang_sync_remains>2)
  if S.Shiv:IsCastable()
    and not Target:DebuffUp(S.ShivDebuff) and Target:DebuffUp(S.Garrote) and Target:DebuffUp(S.Rupture) then
    if S.Kingsbane:IsAvailable() then
      if Target:DebuffUp(S.Kingsbane) and (not S.CrimsonTempest:IsAvailable() or SingleTarget or Target:DebuffUp(S.CrimsonTempest)) then
        if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then return "Cast Shiv (Kingsbane)" end
      end
    end
    if S.ArterialPrecision:IsAvailable() then
      if S.Deathmark:AnyDebuffUp() or S.Shiv:ChargesFractional() > (S.Shiv:MaxCharges() - 0.5) and S.Deathmark:CooldownRemains() > 10 then
        if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then return "Cast Shiv (Arterial Precision)" end
      end
    end
    if not S.ArterialPrecision:IsAvailable() and not S.ArterialPrecision:IsAvailable() then
      if S.Sepsis:IsAvailable() then
        if (BoolToInt(S.Sepsis:CooldownUp() or S.Sepsis:CooldownRemains() > 12) + BoolToInt(S.Deathmark:CooldownUp() or S.Deathmark:CooldownRemains() > 12) == 2) then
          if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then return "Cast Shiv (Sepsis)" end
        end
      else
        if (not S.CrimsonTempest:IsAvailable() or SingleTarget or Target:DebuffUp(S.CrimsonTempest)) and (not S.Exsanguinate:IsAvailable() or ExsanguinateSyncRemains > 2) then
          if Cast(S.Shiv, Settings.Assassination.GCDasOffGCD.Shiv) then return "Cast Shiv" end
        end
      end
    end
  end
  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.deficit>=100|charges=3&(dot.kingsbane.ticking|debuff.deathmark.up)|fight_remains<charges*6)
  if S.ThistleTea:IsCastable() and not Player:BuffUp(S.ThistleTea)
    and (Player:EnergyDeficit() >= 100 + EnergyRegenCombined or S.ThistleTea:Charges() == 3 and (Target:DebuffUp(S.Kingsbane) or S.Deathmark:AnyDebuffUp())
      or HL.BossFilteredFightRemains("<", S.ThistleTea:Charges() * 6)) then
    if HR.Cast(S.ThistleTea, Settings.Commons.OffGCDasOffGCD.ThistleTea) then return "Cast Thistle Tea" end
  end
  -- actions.cds+=/indiscriminate_carnage,if=(spell_targets.fan_of_knives>desired_targets|spell_targets.fan_of_knives>1&raid_event.adds.in>60)&(!talent.improved_garrote|cooldown.vanish.remains>45)
  if S.IndiscriminateCarnage:IsReady() and MeleeEnemies10yCount > 1 and (not S.ImprovedGarrote:IsAvailable() or S.Vanish:CooldownRemains() > 45) then
    if Cast(S.IndiscriminateCarnage, Settings.Assassination.OffGCDasOffGCD.IndiscriminateCarnage) then return "Cast Indiscriminate Carnage" end
  end

  -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5
  -- Racials
  if S.Deathmark:AnyDebuffUp() and (not ShouldReturn or Settings.Commons.OffGCDasOffGCD.Racials) then
    if ShouldReturn then
      Racials()
    else
      ShouldReturn = Racials()
    end
  end

  -- actions.cds+=/call_action_list,name=vanish,if=!stealthed.all&master_assassin_remains=0
  if not Player:StealthUp(true, true) and ImprovedGarroteRemains() <= 0 and MasterAssassinRemains() <= 0 then
    if ShouldReturn then
      Vanish()
    else
      ShouldReturn = Vanish()
    end
  end
  -- actions.cds+=/cold_blood,if=combo_points>=4
  if S.ColdBlood:IsReady() and Player:DebuffDown(S.ColdBlood) and ComboPoints >= 4 
    and (Settings.Commons.OffGCDasOffGCD.ColdBlood or not ShouldReturn) then
    if Cast(S.ColdBlood, Settings.Commons.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
  end

  return ShouldReturn
end

-- # Stealthed
local function Stealthed ()
  -- actions.stealthed=indiscriminate_carnage,if=spell_targets.fan_of_knives>desired_targets|spell_targets.fan_of_knives>1&raid_event.adds.in>60
  if S.IndiscriminateCarnage:IsReady() and MeleeEnemies10yCount > 1 then
    if Cast(S.IndiscriminateCarnage, Settings.Assassination.OffGCDasOffGCD.IndiscriminateCarnage) then return "Cast Indiscriminate Carnage" end
  end
  if S.Garrote:IsCastable() and ImprovedGarroteRemains() > 0 then
    -- actions.stealthed+=/garrote,target_if=min:remains,if=stealthed.improved_garrote&!will_lose_exsanguinate&(remains<12%exsanguinated_rate|pmultiplier<=1)&target.time_to_die-remains>2
    local function GarroteTargetIfFunc(TargetUnit)
      return TargetUnit:DebuffRemains(S.Garrote)
    end
    local function GarroteIfFunc(TargetUnit)
      return not Rogue.WillLoseExsanguinate(TargetUnit, S.Garrote) and
        (TargetUnit:PMultiplier(S.Garrote) <= 1 or TargetUnit:DebuffRemains(S.Garrote) < (12 / Rogue.ExsanguinatedRate(TargetUnit, S.Garrote)))
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
      -- actions.stealthed+=/pool_resource,for_next=1
      if CastPooling(S.Garrote, nil, not TargetInMeleeRange) then return "Cast Garrote (Improved Garrote)" end
    end
    -- actions.stealthed+=/garrote,if=talent.exsanguinate.enabled&stealthed.improved_garrote&active_enemies=1&!will_lose_exsanguinate&(remains<18%exsanguinated_rate|pmultiplier<=1)&variable.exsang_sync_remains<18&improved_garrote_remains<1.3
    if S.Exsanguinate:IsAvailable() and MeleeEnemies10yCount == 1 and not Rogue.WillLoseExsanguinate(Target, S.Garrote)
      and (Target:DebuffRemains(S.Garrote) < (18 / Rogue.ExsanguinatedRate(Target, S.Garrote)) or Target:PMultiplier(S.Garrote) <= 1)
      and ExsanguinateSyncRemains < 18 and ImprovedGarroteRemains() < 1.3 then
      -- actions.stealthed+=/pool_resource,for_next=1
      if CastPooling(S.Garrote, nil, not TargetInMeleeRange) then return "Pool for Garrote (Exsanguinate Refresh)" end
    end
  end
end

-- # Damage over time abilities
local function Dot ()
  local SkipCycleGarrote, SkipCycleRupture, SkipRupture = false, false, false
  if PriorityRotation then
    -- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&(dot.garrote.remains<cooldown.garrote.duration|variable.regen_saturated)
    SkipCycleGarrote = MeleeEnemies10yCount > 3 and (Target:DebuffRemains(S.Garrote) < 6 or EnergyRegenSaturated)
    -- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&(debuff.shiv.up&spell_targets.fan_of_knives>2|variable.regen_saturated)
    SkipCycleRupture = (Target:DebuffUp(S.ShivDebuff) and MeleeEnemies10yCount > 2) or EnergyRegenSaturated
  end
  -- actions.dot+=/variable,name=skip_rupture,value=0
  -- SkipRupture = false
  if HR.CDsON() and S.Exsanguinate:IsAvailable() and ExsanguinateSyncRemains < 2 then
    -- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!will_lose_exsanguinate&dot.garrote.pmultiplier<=1&cooldown.exsanguinate.remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
    if S.Garrote:IsCastable() and TargetInMeleeRange and MeleeEnemies10yCount == 1
      and not Rogue.WillLoseExsanguinate(Target, S.Garrote) and Target:PMultiplier(S.Garrote) <= 1
      and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Garrote)*0.5) then
      if CastPooling(S.Garrote) then return "Cast Garrote (Pre-Exsanguinate)" end
    end
    -- actions.dot+=/rupture,if=talent.exsanguinate.enabled&!will_lose_exsanguinate&dot.rupture.pmultiplier<=1&cooldown.exsanguinate.remains<1&effective_combo_points>=variable.exsanguinate_rupture_cp&dot.rupture.remains*0.5<target.time_to_die
    if S.Rupture:IsReady() and TargetInMeleeRange and Target:PMultiplier(S.Rupture) <= 1 and not Rogue.WillLoseExsanguinate(Target, S.Rupture)
      and (ComboPoints >= ExsanguinateRuptureCP() and ExsanguinateSyncRemains < 1 and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Rupture)*0.5)) then
      if Cast(S.Rupture) then return "Cast Rupture (Pre-Exsanguinate)" end
    end
  end
  -- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>4&master_assassin_remains=0  
  -- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>12&master_assassin_remains=0
  if S.Garrote:IsCastable() and ComboPointsDeficit >= 1 then
    local function Evaluate_Garrote_Target(TargetUnit)
      GarroteTickTime = Rogue.Exsanguinated(TargetUnit, S.Garrote) and ExsanguinatedBleedTickTime or BleedTickTime
      return IsDebuffRefreshable(TargetUnit, S.Garrote) and MasterAssassinRemains() <= 0
        and (TargetUnit:PMultiplier(S.Garrote) <= 1 or (MeleeEnemies10yCount >= 3 and TargetUnit:DebuffRemains(S.Garrote) <= GarroteTickTime))
        and (not Rogue.WillLoseExsanguinate(TargetUnit, S.Garrote) or TargetUnit:DebuffRemains(S.Garrote) <= GarroteTickTime * (1 + BoolToInt(MeleeEnemies10yCount >= 3)))
    end
    if Evaluate_Garrote_Target(Target) and Rogue.CanDoTUnit(Target, GarroteDMGThreshold)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      -- actions.dot+=/pool_resource,for_next=1
      if CastPooling(S.Garrote, nil, not TargetInMeleeRange) then return "Pool for Garrote (ST)" end
    end
    if HR.AoEON() and not SkipCycleGarrote then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 12, MeleeEnemies5y)
    end
  end
  -- actions.dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>=2&effective_combo_points>=4&energy.regen_combined>20&(!cooldown.deathmark.ready|dot.rupture.ticking)&remains<(2+3*(spell_targets>=4))
  if HR.AoEON() and S.CrimsonTempest:IsReady() and MeleeEnemies10yCount >= 2 and ComboPoints >= 4
    and EnergyRegenCombined > 20 and (not S.Deathmark:CooldownUp() or Target:DebuffUp(S.Rupture)) then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if CycleUnit:DebuffRemains(S.CrimsonTempest) < (2 + 3 * BoolToInt(MeleeEnemies10yCount >= 4)) then
        if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE)" end
      end
    end
  end
  -- actions.dot+=/rupture,if=!variable.skip_rupture&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(talent.doomblade*5)+(variable.regen_saturated*6))
  -- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(talent.doomblade*5)+(variable.regen_saturated*6))
  if S.Rupture:IsReady() and ComboPoints >= 4 then
    -- target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(talent.doomblade*5)+(variable.regen_saturated*6))
    RuptureDurationThreshold = 4 + BoolToInt(S.DashingScoundrel:IsAvailable()) * 5 + BoolToInt(S.Doomblade:IsAvailable()) * 5 + BoolToInt(EnergyRegenSaturated) * 6
    local function Evaluate_Rupture_Target(TargetUnit)
      RuptureTickTime = Rogue.Exsanguinated(TargetUnit, S.Rupture) and ExsanguinatedBleedTickTime or BleedTickTime
      return IsDebuffRefreshable(TargetUnit, S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemains(S.Rupture) <= RuptureTickTime and MeleeEnemies10yCount >= 3)
        and (not Rogue.WillLoseExsanguinate(TargetUnit, S.Rupture) or TargetUnit:DebuffRemains(S.Rupture) <= RuptureTickTime * (1 + BoolToInt(MeleeEnemies10yCount >= 3)))
        and (TargetUnit:FilteredTimeToDie(">", RuptureDurationThreshold, -TargetUnit:DebuffRemains(S.Rupture)) or TargetUnit:TimeToDieIsNotValid())
    end
    if not SkipRupture and Evaluate_Rupture_Target(Target) and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if Cast(S.Rupture, nil, nil, not TargetInMeleeRange) then return "Cast Rupture (Refresh)" end
    end
    if not SkipRupture and not SkipCycleRupture and HR.AoEON() then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, RuptureDurationThreshold, MeleeEnemies5y)
    end
  end
  -- actions.dot+=/crimson_tempest,if=spell_targets>=2&effective_combo_points>=4&remains<2+3*(spell_targets>=4)
  if HR.AoEON() and S.CrimsonTempest:IsReady() and MeleeEnemies10yCount >= 2 and ComboPoints >= 4 then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      -- Note: The APL does not do this due to target_if mechanics, just to determine if any targets are low on duration of the AoE Bleed
      if CycleUnit:DebuffRemains(S.CrimsonTempest) < 2 + 3 * BoolToInt(MeleeEnemies10yCount >= 4) then
        if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE Fallback)" end
      end
    end
  end
  -- actions.dot+=/crimson_tempest,if=spell_targets=1&!talent.dashing_scoundrel&effective_combo_points>=(cp_max_spend-1)&refreshable&!will_lose_exsanguinate&!debuff.shiv.up&debuff.amplifying_poison.stack<15&(!talent.kingsbane|buff.envenom.up|!cooldown.kingsbane.up)&target.time_to_die-remains>4
  if S.CrimsonTempest:IsReady() and TargetInAoERange and MeleeEnemies10yCount == 1
    and not S.DashingScoundrel:IsAvailable() and ComboPoints >= (Rogue.CPMaxSpend() - 1) and IsDebuffRefreshable(Target, S.CrimsonTempest, CrimsonTempestThreshold)
    and not Rogue.WillLoseExsanguinate(Target, S.CrimsonTempest) and not Target:DebuffUp(S.ShivDebuff) and Target:DebuffStack(S.AmplifyingPoisonDebuff) < 15
    and (not S.Kingsbane:IsAvailable() or Player:BuffUp(S.Envenom) or not S.Kingsbane:CooldownUp())
    and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.CrimsonTempest)) or Target:TimeToDieIsNotValid())
    and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
    if Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (ST)" end
  end

  return false
end

-- # Direct damage abilities
local function Direct ()
  -- actions.direct=envenom,if=effective_combo_points>=4+talent.deeper_stratagem.enabled&(debuff.deathmark.up|debuff.shiv.up|debuff.amplifying_poison.stack>=10|energy.deficit<=25+energy.regen_combined|!variable.single_target|effective_combo_points>cp_max_spend)&(!talent.exsanguinate.enabled|variable.exsang_sync_remains>2|talent.resounding_clarity&(cooldown.echoing_reprimand.ready&combo_points>2|effective_combo_points>5))
  if S.Envenom:IsReady() and ComboPoints >= 4 + BoolToInt(S.DeeperStratagem:IsAvailable())
    and (Target:DebuffUp(S.Deathmark) or Target:DebuffUp(S.ShivDebuff) or Target:DebuffStack(S.AmplifyingPoisonDebuff) >= 10
      or Player:EnergyDeficit() <= (25 + EnergyRegenCombined) or not SingleTarget or ComboPoints > Rogue.CPMaxSpend())
    and (not S.Exsanguinate:IsAvailable() or ExsanguinateSyncRemains > 2 or not HR.CDsON()
      or S.ResoundingClarity:IsAvailable() and (S.EchoingReprimand:IsReady() and Player:ComboPoints() > 2 or ComboPoints > 5)) then
    if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then return "Cast Envenom" end
  end

  --- !!!! ---
  -- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|!variable.single_target
  -- Note: This is used in all following fillers, so we just return false if not true and won't consider these.
  if not (ComboPointsDeficit > 1 or Player:EnergyDeficit() <= 25 + EnergyRegenCombined or not SingleTarget) then
    return false
  end
  --- !!!! ---

  if S.SerratedBoneSpike:IsReady() then
    -- actions.direct+=/serrated_bone_spike,if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
    if not Target:DebuffUp(S.SerratedBoneSpikeDebuff) then
      if Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle, not TargetInAoERange) then return "Cast Serrated Bone Spike" end
    else
      -- actions.direct+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
      if HR.AoEON() then
        if Everyone.CastTargetIf(S.SerratedBoneSpike, Enemies30y, "min", EvaluateSBSTargetIfConditionCondition, EvaluateSBSCondition) then
          return "Cast Serrated Bone (AoE)"
        end
      end
      -- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&(fight_remains<=5|cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25)
      -- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&!variable.single_target&debuff.shiv.up
      if MasterAssassinRemains() < 0.8 then
        if (HL.BossFightRemains() <= 5 or (S.SerratedBoneSpike:MaxCharges() - S.SerratedBoneSpike:ChargesFractional() <= 0.25)) then
          if Cast(S.SerratedBoneSpike, nil, Settings.Commons.SerratedBoneSpikeDumpDisplayStyle, not TargetInAoERange) then return "Cast Serrated Bone Spike (Dump Charge)" end
        elseif not SingleTarget and Target:DebuffUp(S.ShivDebuff) then
          if Cast(S.SerratedBoneSpike, nil, Settings.Commons.SerratedBoneSpikeDumpDisplayStyle, not TargetInAoERange) then return "Cast Serrated Bone Spike (Shiv)" end
        end
      end
    end
  end
  -- actions.direct+=/echoing_reprimand,if=(!talent.exsanguinate|!talent.resounding_clarity)&variable.use_filler&cooldown.deathmark.remains>10|fight_remains<20
  if CDsON() and S.EchoingReprimand:IsReady() and ((not S.Exsanguinate:IsAvailable() or not S.ResoundingClarity:IsAvailable())
    and (not S.Deathmark:IsAvailable() or S.Deathmark:CooldownRemains() > 10) or HL.BossFilteredFightRemains("<=", 20)) then
    if Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle, not TargetInMeleeRange) then return "Cast Echoing Reprimand" end
  end
  if S.FanofKnives:IsCastable() then
    -- actions.direct+=/fan_of_knives,if=variable.use_filler&(!priority_rotation&spell_targets.fan_of_knives>=3+stealthed.rogue+talent.dragontempered_blades)
    if HR.AoEON() and MeleeEnemies10yCount >= 1 and (not PriorityRotation
      and MeleeEnemies10yCount >= 3 + BoolToInt(Player:StealthUp(true, false)) + BoolToInt(S.DragonTemperedBlades:IsAvailable())) then
      if CastPooling(S.FanofKnives) then return "Cast Fan of Knives" end
    end
    -- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking&(!priority_rotation|dot.garrote.ticking|dot.rupture.ticking),if=variable.use_filler&spell_targets.fan_of_knives>=3
    if HR.AoEON() and Player:BuffUp(S.DeadlyPoison) and MeleeEnemies10yCount >= 3 then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        if not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff, true) and (not PriorityRotation or CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) then
          if CastPooling(S.FanofKnives) then return "Cast Fan of Knives (DP Refresh)" end
        end
      end
    end
  end
  -- actions.direct+=/ambush,if=variable.use_filler
  if S.Ambush:IsCastable() and (Player:StealthUp(true, true) or Player:BuffUp(S.BlindsideBuff)) then
    if CastPooling(S.Ambush, nil, not TargetInMeleeRange) then return "Cast Ambush" end
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
    if CastPooling(S.Mutilate, nil, not TargetInMeleeRange) then return "Cast Mutilate" end
  end

  return false
end

--- ======= MAIN =======
local function APL ()
  -- Enemies Update
  MeleeRange = S.AcrobaticStrikes:IsAvailable() and 8 or 5
  AoERange = S.AcrobaticStrikes:IsAvailable() and 10 or 13
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
    if not Player:BuffUp(Rogue.VanishBuffSpell()) then
      ShouldReturn = Rogue.Stealth(Rogue.StealthSpell())
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
        -- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>15
        if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() and Everyone.TargetIsValid() then
          if Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
      end
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if not Player:BuffUp(S.SliceandDice) then
        if S.SliceandDice:IsReady() and ComboPoints >= 2 then
          if Cast(S.SliceandDice) then return "Cast Slice and Dice" end
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
    EnergyRegenCombined = Player:EnergyRegen() + PoisonedBleeds * 6 / (2 * Player:SpellHaste())
    EnergyTimeToMaxCombined = Player:EnergyDeficit() / EnergyRegenCombined
    -- actions+=/variable,name=regen_saturated,value=energy.regen_combined>35
    EnergyRegenSaturated = EnergyRegenCombined > 35
    ExsanguinateSyncRemains = ExsangSyncRemains()
    -- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
    SingleTarget = MeleeEnemies10yCount < 2

    -- actions+=/call_action_list,name=stealthed,if=stealthed.rogue|stealthed.improved_garrote
    if Player:StealthUp(true, false) or ImprovedGarroteRemains() > 0 then
      ShouldReturn = Stealthed()
      if ShouldReturn then return ShouldReturn .. " (Stealthed)" end
    end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return ShouldReturn end
    -- # Put SnD up initially for Cut to the Chase, refresh with Envenom if at low duration
    -- actions+=/slice_and_dice,if=!buff.slice_and_dice.up&combo_points>=2|!talent.cut_to_the_chase&refreshable&combo_points>=4
    if not Player:BuffUp(S.SliceandDice) then
      if S.SliceandDice:IsReady() and Player:ComboPoints() >= 2
        or not S.CutToTheChase:IsAvailable() and Player:ComboPoints() >= 4 and Player:BuffRemains(S.SliceandDice) < (1 + Player:ComboPoints()) * 1.8 then
        if Cast(S.SliceandDice) then return "Cast Slice and Dice" end
      end
    elseif TargetInAoERange and S.CutToTheChase:IsAvailable() then
      -- actions+=/envenom,if=talent.cut_to_the_chase&buff.slice_and_dice.up&buff.slice_and_dice.remains<5&combo_points>=4
      if S.Envenom:IsReady() and Player:BuffRemains(S.SliceandDice) < 5 and Player:ComboPoints() >= 4 then
        if Cast(S.Envenom, nil, nil, not TargetInMeleeRange) then return "Cast Envenom (CttC)" end
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
      if S.ArcaneTorrent:IsCastable() and TargetInMeleeRange and Player:EnergyDeficit() > 15 then
        if Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastable() and TargetInMeleeRange then
        if Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastable() and TargetInMeleeRange then
        if Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsCastable() and TargetInMeleeRange then
        if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
      end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.Mutilate:IsCastable() and TargetInAoERange then
      if Cast(S.PoolEnergy) then return "Normal Pooling" end
    end
  end
end

local function Init ()
  S.Deathmark:RegisterAuraTracking()
  S.Sepsis:RegisterAuraTracking()
end

HR.SetAPL(259, APL, Init)

--- ======= SIMC =======
-- Last Update: 2023-02-06

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>15
-- # Determine which (if any) stat buff trinket we want to attempt to sync with Deathmark.
-- actions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
-- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
-- # Determine if we should be be casting our pre-Exsanguinate Rupture with Echoing Reprimand CP
-- actions.precombat+=/variable,name=exsanguinate_rupture_cp,value=cp_max_spend<?(talent.resounding_clarity*7)
-- actions.precombat+=/stealth
-- actions.precombat+=/slice_and_dice,precombat_seconds=1

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
-- # Combined Energy Regen needed to saturate
-- actions+=/variable,name=regen_saturated,value=energy.regen_combined>35
-- # Next Exsanguinate cooldown time based on Deathmark syncing logic and remaining fight duration
-- actions+=/variable,name=exsang_sync_remains,op=setif,condition=cooldown.deathmark.remains>cooldown.exsanguinate.remains&cooldown.deathmark.remains<fight_remains,value=cooldown.deathmark.remains,value_else=cooldown.exsanguinate.remains
-- actions+=/call_action_list,name=stealthed,if=stealthed.rogue|stealthed.improved_garrote
-- actions+=/call_action_list,name=cds
-- # Put SnD up initially for Cut to the Chase, refresh with Envenom if at low duration
-- actions+=/slice_and_dice,if=!buff.slice_and_dice.up&combo_points>=2|!talent.cut_to_the_chase&refreshable&combo_points>=4
-- actions+=/envenom,if=talent.cut_to_the_chase&buff.slice_and_dice.up&buff.slice_and_dice.remains<5&combo_points>=4
-- actions+=/call_action_list,name=dot
-- actions+=/call_action_list,name=direct
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen_combined
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Cooldowns
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds=marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(!variable.single_target|target.time_to_die<30)&(target.time_to_die<combo_points.deficit*1.5|combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD for max CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
-- # Sync Deathmark window with Exsanguinate if applicable
-- actions.cds+=/variable,name=deathmark_exsanguinate_condition,value=!talent.exsanguinate|cooldown.exsanguinate.remains>15|exsanguinated.rupture|exsanguinated.garrote
-- # Wait on Deathmark for Garrote with MA
-- actions.cds+=/variable,name=deathmark_ma_condition,value=!talent.master_assassin.enabled|dot.garrote.ticking
-- actions.cds+=/sepsis,if=!stealthed.rogue&!stealthed.improved_garrote&(!talent.improved_garrote&dot.garrote.ticking|talent.improved_garrote&cooldown.garrote.up)&(target.time_to_die>10|fight_remains<10)
-- # Deathmark to be used if not stealthed, Rupture is up, and all other talent conditions are satisfied
-- actions.cds+=/variable,name=deathmark_condition,value=!stealthed.rogue&dot.rupture.ticking&!debuff.deathmark.up&variable.deathmark_exsanguinate_condition&variable.deathmark_ma_condition
-- # Sync the priority stat buff trinket with Deathmark, otherwise use on cooldown
-- actions.cds+=/use_item,name=algethar_puzzle_box,use_off_gcd=1,if=(!talent.exsanguinate|cooldown.exsanguinate.remains>15|exsanguinated.rupture|exsanguinated.garrote)&dot.rupture.ticking&cooldown.deathmark.remains<2|fight_remains<=22
-- actions.cds+=/use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
-- actions.cds+=/use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(debuff.deathmark.up|fight_remains<=20)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready|!debuff.deathmark.up&cooldown.deathmark.remains>20))|!variable.trinket_sync_slot)
-- actions.cds+=/deathmark,if=variable.deathmark_condition
-- actions.cds+=/kingsbane,if=(debuff.shiv.up|cooldown.shiv.remains<6)&buff.envenom.up&(cooldown.deathmark.remains>=50|dot.deathmark.ticking)
-- # Exsanguinate when not stealthed and both Rupture and Garrote are up for long enough. Attempt to sync with Deathmark and also Echoing Reprimand if using Resounding Clarity.
-- actions.cds+=/variable,name=exsanguinate_condition,value=talent.exsanguinate&!stealthed.rogue&!stealthed.improved_garrote&!dot.deathmark.ticking&target.time_to_die>variable.exsang_sync_remains+4&variable.exsang_sync_remains<4
-- actions.cds+=/echoing_reprimand,if=talent.exsanguinate&talent.resounding_clarity&(variable.exsanguinate_condition&combo_points<=2&variable.exsang_sync_remains<=2&!dot.garrote.refreshable&dot.rupture.remains>9.6|variable.exsang_sync_remains>40)
-- actions.cds+=/exsanguinate,if=variable.exsanguinate_condition&(!dot.garrote.refreshable&dot.rupture.remains>4+4*variable.exsanguinate_rupture_cp|dot.rupture.remains*0.5>target.time_to_die)
-- # Shiv if DoTs are up; Always Shiv with Kingsbane, otherwise attempt to sync with Sepsis or Deathmark if we won't waste more than half Shiv's cooldown
-- actions.cds+=/shiv,if=talent.kingsbane&!debuff.shiv.up&dot.kingsbane.ticking&dot.garrote.ticking&dot.rupture.ticking&(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)
-- actions.cds+=/shiv,if=talent.arterial_precision&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&(debuff.deathmark.up|cooldown.shiv.charges_fractional>max_charges-0.5&cooldown.deathmark.remains>10)
-- actions.cds+=/shiv,if=talent.sepsis&!talent.kingsbane&!talent.arterial_precision&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&((cooldown.sepsis.ready|cooldown.sepsis.remains>12)+(cooldown.deathmark.ready|cooldown.deathmark.remains>12)=2)
-- actions.cds+=/shiv,if=!talent.kingsbane&!talent.arterial_precision&!talent.sepsis&!debuff.shiv.up&dot.garrote.ticking&dot.rupture.ticking&(!talent.crimson_tempest.enabled|variable.single_target|dot.crimson_tempest.ticking)
-- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.deficit>=100|charges=3&(dot.kingsbane.ticking|debuff.deathmark.up)|fight_remains<charges*6)
-- actions.cds+=/indiscriminate_carnage,if=(spell_targets.fan_of_knives>desired_targets|spell_targets.fan_of_knives>1&raid_event.adds.in>60)&(!talent.improved_garrote|cooldown.vanish.remains>45)
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|debuff.deathmark.up
-- actions.cds+=/blood_fury,if=debuff.deathmark.up
-- actions.cds+=/berserking,if=debuff.deathmark.up
-- actions.cds+=/fireblood,if=debuff.deathmark.up
-- actions.cds+=/ancestral_call,if=debuff.deathmark.up
-- actions.cds+=/call_action_list,name=vanish,if=!stealthed.all&master_assassin_remains=0
-- actions.cds+=/cold_blood,if=combo_points>=4

-- # Direct damage abilities
-- # Envenom at 4+ (5+ with DS) CP. Immediately on 2+ targets, with Deathmark, or with TB; otherwise wait for some energy. Also wait if Exsg combo is coming up.
-- actions.direct=envenom,if=effective_combo_points>=4+talent.deeper_stratagem.enabled&(debuff.deathmark.up|debuff.shiv.up|debuff.amplifying_poison.stack>=10|energy.deficit<=25+energy.regen_combined|!variable.single_target|effective_combo_points>cp_max_spend)&(!talent.exsanguinate.enabled|variable.exsang_sync_remains>2|talent.resounding_clarity&(cooldown.echoing_reprimand.ready&combo_points>2|effective_combo_points>5))
-- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+energy.regen_combined|!variable.single_target
-- # Apply SBS to all targets without a debuff as priority, preferring targets dying sooner after the primary target
-- actions.direct+=/serrated_bone_spike,if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
-- actions.direct+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=variable.use_filler&!dot.serrated_bone_spike_dot.ticking
-- # Keep from capping charges or burn at the end of fights
-- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&(fight_remains<=5|cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25)
-- # When MA is not at high duration, sync with Shiv
-- actions.direct+=/serrated_bone_spike,if=variable.use_filler&master_assassin_remains<0.8&!variable.single_target&debuff.shiv.up
-- actions.direct+=/echoing_reprimand,if=(!talent.exsanguinate|!talent.resounding_clarity)&variable.use_filler&cooldown.deathmark.remains>10|fight_remains<20
-- # Fan of Knives at 3+ targets or 4+ with DTB
-- actions.direct+=/fan_of_knives,if=variable.use_filler&(!priority_rotation&spell_targets.fan_of_knives>=3+stealthed.rogue+talent.dragontempered_blades)
-- # Fan of Knives to apply poisons if inactive on any target (or any bleeding targets with priority rotation) at 3T
-- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking&(!priority_rotation|dot.garrote.ticking|dot.rupture.ticking),if=variable.use_filler&spell_targets.fan_of_knives>=3
-- actions.direct+=/ambush,if=variable.use_filler
-- # Tab-Mutilate to apply Deadly Poison at 2 targets
-- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking&!debuff.amplifying_poison.up,if=variable.use_filler&spell_targets.fan_of_knives=2
-- actions.direct+=/mutilate,if=variable.use_filler

-- # Damage over time abilities
-- # Limit secondary Garrotes for priority rotation if we have 35 energy regen or Garrote will expire on the primary target
-- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&(dot.garrote.remains<cooldown.garrote.duration|variable.regen_saturated)
-- # Limit secondary Ruptures for priority rotation if we have 35 energy regen or Shiv is up on 2T+
-- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&(debuff.shiv.up&spell_targets.fan_of_knives>2|variable.regen_saturated)
-- # Limit Ruptures when appropriate, not currently used
-- actions.dot+=/variable,name=skip_rupture,value=0
-- # Special Garrote and Rupture setup prior to Exsanguinate cast
-- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!will_lose_exsanguinate&dot.garrote.pmultiplier<=1&variable.exsang_sync_remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
-- actions.dot+=/rupture,if=talent.exsanguinate.enabled&!will_lose_exsanguinate&dot.rupture.pmultiplier<=1&variable.exsang_sync_remains<1&effective_combo_points>=variable.exsanguinate_rupture_cp&dot.rupture.remains*0.5<target.time_to_die
-- # Garrote upkeep, also tries to use it as a special generator for the last CP before a finisher
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>4&master_assassin_remains=0
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&(target.time_to_die-remains)>12&master_assassin_remains=0
-- # Crimson Tempest on multiple targets at 4+ CP when running out in 2-5s as long as we have enough regen and aren't setting up for Deathmark
-- actions.dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>=2&effective_combo_points>=4&energy.regen_combined>20&(!cooldown.deathmark.ready|dot.rupture.ticking)&remains<(2+3*(spell_targets>=4))
-- # Keep up Rupture at 4+ on all targets (when living long enough and not snapshot)
-- actions.dot+=/rupture,if=!variable.skip_rupture&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(talent.doomblade*5)+(variable.regen_saturated*6))
-- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&effective_combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3)&(!will_lose_exsanguinate|remains<=tick_time*2&spell_targets.fan_of_knives>=3)&target.time_to_die-remains>(4+(talent.dashing_scoundrel*5)+(talent.doomblade*5)+(variable.regen_saturated*6))
-- # Fallback AoE Crimson Tempest with the same logic as above, but ignoring the energy conditions if we aren't using Rupture
-- actions.dot+=/crimson_tempest,if=spell_targets>=2&effective_combo_points>=4&remains<2+3*(spell_targets>=4)
-- # Crimson Tempest on ST if in pandemic and nearly max energy and if Envenom won't do more damage due to TB/MA
-- actions.dot+=/crimson_tempest,if=spell_targets=1&!talent.dashing_scoundrel&effective_combo_points>=(cp_max_spend-1)&refreshable&!will_lose_exsanguinate&!debuff.shiv.up&debuff.amplifying_poison.stack<15&(!talent.kingsbane|buff.envenom.up|!cooldown.kingsbane.up)&target.time_to_die-remains>4

-- # Stealthed Actions
-- actions.stealthed=indiscriminate_carnage,if=spell_targets.fan_of_knives>desired_targets|spell_targets.fan_of_knives>1&raid_event.adds.in>60
-- # Improved Garrote: Apply or Refresh with buffed Garrotes
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,target_if=min:remains,if=stealthed.improved_garrote&!will_lose_exsanguinate&(remains<12%exsanguinated_rate|pmultiplier<=1)&target.time_to_die-remains>2
-- # Improved Garrote + Exsg on 1T: Refresh Garrote at the end of stealth to get max duration before Exsanguinate
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,if=talent.exsanguinate.enabled&stealthed.improved_garrote&active_enemies=1&!will_lose_exsanguinate&(remains<18%exsanguinated_rate|pmultiplier<=1)&variable.exsang_sync_remains<18&improved_garrote_remains<1.3

-- # Stealth Cooldowns
-- # Vanish Sync for Improved Garrote with Deathmark
-- actions.vanish=pool_resource,for_next=1,extra_amount=45
-- actions.vanish+=/vanish,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&(debuff.deathmark.up|cooldown.deathmark.remains<4)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)
-- # Vanish for Indiscriminate Carnage or Improved Garrote at 2-3+ targets
-- actions.vanish+=/pool_resource,for_next=1,extra_amount=45
-- actions.vanish+=/vanish,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&spell_targets.fan_of_knives>(3-talent.indiscriminate_carnage)&(!talent.indiscriminate_carnage|cooldown.indiscriminate_carnage.ready)
-- # Vanish with Master Assassin: Rupture+Garrote not in refresh range, during Deathmark+Shiv. Sync with Sepsis final hit if possible.
-- actions.vanish+=/vanish,if=!talent.improved_garrote&talent.master_assassin&!dot.rupture.refreshable&dot.garrote.remains>3&debuff.deathmark.up&(debuff.shiv.up|debuff.deathmark.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3
-- actions.vanish+=/pool_resource,for_next=1,extra_amount=45
-- # Shadow Dance for Improved Garrote with Deathmark
-- actions.vanish+=/shadow_dance,if=talent.improved_garrote&cooldown.garrote.up&!exsanguinated.garrote&(dot.garrote.pmultiplier<=1|dot.garrote.refreshable)&(debuff.deathmark.up|cooldown.deathmark.remains<12|cooldown.deathmark.remains>60)&combo_points.deficit>=(spell_targets.fan_of_knives>?4)
-- # Shadow Dance with Master Assassin: Rupture+Garrote not in refresh range, during Deathmark+Shiv. Sync with Sepsis final hit if possible.
-- actions.vanish+=/shadow_dance,if=!talent.improved_garrote&talent.master_assassin&!dot.rupture.refreshable&dot.garrote.remains>3&(debuff.deathmark.up|cooldown.deathmark.remains>60)&(debuff.shiv.up|debuff.deathmark.remains<4|dot.sepsis.ticking)&dot.sepsis.remains<3

