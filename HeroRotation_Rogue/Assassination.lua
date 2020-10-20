--- Localize Vars
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
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua
local pairs = pairs
local mathfloor = math.floor

--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue
-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
-- Define S/I for spell and item arrays
local S = Spell.Rogue.Assassination
local I = Item.Rogue.Assassination

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.GalecallersBoon:ID(),
  I.LustrousGoldenPlumage:ID(),
  I.ComputationDevice:ID(),
  I.VigorTrinket:ID(),
  I.FontOfPower:ID(),
  I.RazorCoral:ID()
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
      Rogue.CPSpend() *
      -- Envenom AP Coef
      0.16 *
      -- Aura Multiplier (SpellID: 137037)
      1.27 *
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
      1.27 *
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

-- Rotation Var
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y
local ShouldReturn; -- Used to get the return string
local BleedTickTime, ExsanguinatedBleedTickTime = 2 / Player:SpellHaste(), 1 / Player:SpellHaste()
local Stealth
local RuptureThreshold, RuptureDMGThreshold, RuptureDurationThreshold, GarroteDMGThreshold, CrimsonTempestThreshold
local ComboPoints, ComboPointsDeficit, Energy_Regen_Combined, PoisonedBleeds
local PriorityRotation

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Assassination = HR.GUISettings.APL.Rogue.Assassination
}

local function num(val)
  if val then return 1 else return 0 end
end

-- Check if the Priority Rotation variable should be set
local function UsePriorityRotation()
  if MeleeEnemies10yCount < 2 then
    return false
  end
  if Settings.Assassination.UsePriorityRotation == "Always" then
    return true
  end
  if Settings.Assassination.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  end
  -- Zul Mythic
  if Player:InstanceDifficulty() == 16 and Target:NPCID() == 138967 then
    return true
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
    HR.CastLeftNameplate(BestUnit, DoTSpell)
  -- Check ranged units next, if the RangedMultiDoT option is enabled
  elseif Settings.Assassination.RangedMultiDoT then
    BestUnit, BestUnitTTD = nil, DoTMinTTD
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(DoTSpell))
      and DoTEvaluation(CycleUnit) then
        BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
      end
    end
    if BestUnit then
      HR.CastLeftNameplate(BestUnit, DoTSpell)
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
  if Settings.Assassination.RangedMultiDoT then
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
local MasterAssassinBuff, NominalDuration = Spell(256735), 3
local function MasterAssassinRemains ()
  local LegoRemains = Rogue.MasterAssassinsMarkRemains()
  if LegoRemains > 0 then
    return LegoRemains
  elseif Player:BuffRemains(MasterAssassinBuff) < 0 then
    return Player:GCDRemains() + NominalDuration
  else
    return Player:BuffRemains(MasterAssassinBuff)
  end
end

-- Fake ss_buffed (wonky without Subterfuge but why would you, eh?)
local function SSBuffed(TargetUnit)
  return S.ShroudedSuffocation:AzeriteEnabled() and TargetUnit:PMultiplier(S.Garrote) > 1
end

-- non_ss_buffed_targets
local function NonSSBuffedTargets()
  local count = 0
  for _, CycleUnit in pairs(MeleeEnemies10y) do
    if not CycleUnit:DebuffUp(S.Garrote) or not SSBuffed(CycleUnit) then
      count = count + 1
    end
  end
  return count
end

-- ss_buffed_targets_above_pandemic
local function SSBuffedTargetsAbovePandemic()
  local count = 0
  for _, CycleUnit in pairs(MeleeEnemies10y) do
    if CycleUnit:DebuffRemains(S.Garrote) > 5.4 and SSBuffed(CycleUnit) then
      count = count + 1
    end
  end
  return count
end

local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return ComboPoints > 0 end}
}

-- APL Action Lists (and Variables)
-- # Essences
local function Essences ()
  -- actions.essences+=/blood_of_the_enemy,if=debuff.vendetta.up&(exsanguinated.garrote|debuff.toxic_blade.up&combo_points.deficit<=1|debuff.vendetta.remains<=10)|fight_remains<=10
  if S.BloodoftheEnemy:IsCastable() and (Target:DebuffUp(S.Vendetta) and (Rogue.Exsanguinated(Target, S.Garrote)
    or (Target:DebuffUp(S.ShivDebuff) and Player:ComboPointsDeficit() <= 1) or Target:DebuffRemains(S.Vendetta) <= 10)
    or HL.BossFilteredFightRemains("<=", 10)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast BloodoftheEnemy" end
  end
  -- concentrated_flame,if=energy.time_to_max>1&!debuff.vendetta.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
  if S.ConcentratedFlame:IsCastable() and Player:EnergyTimeToMaxPredicted() > 1 and not Target:DebuffUp(S.Vendetta) and (not Target:DebuffUp(S.ConcentratedFlameBurn)
    and not Player:PrevGCD(1, S.ConcentratedFlame) or S.ConcentratedFlame:FullRechargeTime() < Player:GCD() + Player:GCDRemains()) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast ConcentratedFlame" end
  end
  if S.GuardianofAzeroth:IsCastable() then
    -- guardian_of_azeroth,if=cooldown.vendetta.remains<3|debuff.vendetta.up|fight_remains<30
    if S.Vendetta:CooldownRemains() < 3 or Target:DebuffUp(S.Vendetta) or HL.BossFilteredFightRemains("<", 30) then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth Synced" end
    elseif not HL.BossFightRemainsIsNotValid() then
      local BossFightRemains = HL.BossFightRemains()
      -- guardian_of_azeroth,if=floor((fight_remains-30)%cooldown)>floor((fight_remains-30-cooldown.vendetta.remains)%cooldown)
      if mathfloor(BossFightRemains - 30 / 180) > mathfloor((BossFightRemains - 30 - S.Vendetta:CooldownRemains()) / 180) then
        if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth Desynced" end
      end
    end
  end
  -- focused_azerite_beam,if=spell_targets.fan_of_knives>=2|raid_event.adds.in>60&energy<70|fight_remains<10
  if S.FocusedAzeriteBeam:IsCastable() and (Player:EnergyPredicted() < 70 or HL.BossFilteredFightRemains("<", 10)) then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast FocusedAzeriteBeam" end
  end
  -- purifying_blast,if=spell_targets.fan_of_knives>=2|raid_event.adds.in>60|fight_remains<10
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast PurifyingBlast" end
  end
  -- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
  if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff) or Player:BuffStack(S.RecklessForceCounter) < 10) then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast TheUnboundForce" end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast RippleInSpace" end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast WorldveinResonance" end
  end
  -- memory_of_lucid_dreams,if=energy<50&!cooldown.vendetta.up
  if S.MemoryofLucidDreams:IsCastable() and Player:EnergyPredicted() < 50 and not S.Vendetta:CooldownUp() then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast MemoryofLucidDreams" end
  end
  -- reaping_flames,if=target.health.pct>80|target.health.pct<=20|target.time_to_pct_20>30
  ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle)
  if ShouldReturn then return ShouldReturn end

  return false
end

local function Trinkets ()
  -- use_item,name=lustrous_golden_plumage,if=debuff.vendetta.up
  if I.LustrousGoldenPlumage:IsEquipped() and I.LustrousGoldenPlumage:IsReady() and Target:DebuffUp(S.Vendetta) then
    if HR.Cast(I.LustrousGoldenPlumage, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Golden Plumage" end
  end
  -- if=master_assassin_remains=0&!debuff.vendetta.up&!debuff.toxic_blade.up&buff.memory_of_lucid_dreams.down&energy<80&dot.rupture.remains>4
  if I.ComputationDevice:IsEquipped() and I.ComputationDevice:IsReady() and MasterAssassinRemains() <= 0 and not Target:DebuffUp(S.Vendetta)
    and not Target:DebuffUp(S.ShivDebuff) and not Player:BuffUp(S.LucidDreamsBuff) and Player:EnergyPredicted() < 80 and Target:DebuffRemains(S.Rupture) > 4 then
    if HR.Cast(I.ComputationDevice, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Computation Device" end
  end
  if I.RazorCoral:IsEquipped() and I.RazorCoral:IsReady() then
    -- use_item,name=ashvanes_razor_coral,if=(!talent.exsanguinate.enabled|!talent.subterfuge.enabled)&debuff.vendetta.remains>10-4*equipped.azsharas_font_of_power
    if (not S.Exsanguinate:IsAvailable() or not S.Subterfuge:IsAvailable()) and Target:DebuffRemains(S.Vendetta) > 10 - 4 * num(I.FontOfPower:IsEquipped()) then
      if HR.Cast(I.RazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Razor Coral Default Sync" end
    end
    -- use_item,name=ashvanes_razor_coral,if=(talent.exsanguinate.enabled&talent.subterfuge.enabled)&debuff.vendetta.up&(exsanguinated.garrote|azerite.shrouded_suffocation.enabled&dot.garrote.pmultiplier>1)
    if (S.Exsanguinate:IsAvailable() and S.Subterfuge:IsAvailable()) and Target:DebuffRemains(S.Vendetta) > 10
      and (Rogue.Exsanguinated(Target, S.Garrote) or S.ShroudedSuffocation:AzeriteEnabled() and Target:PMultiplier(S.Garrote) > 1) then
      if HR.Cast(I.RazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Razor Coral Exsanguinate Sync" end
    end
  end
  -- V.I.G.O.R. trinket, emulate SimC default behavior to use at max stacks
  if I.VigorTrinket:IsEquipped() and I.VigorTrinket:IsReady() and Player:BuffStack(S.VigorTrinketBuff) == 6 then
    if HR.Cast(I.VigorTrinket, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Vigor Trinket" end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
  end

  return false
end

local function Racials ()
  -- actions.cds+=/blood_fury,if=debuff.vendetta.up
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
  end
  -- actions.cds+=/berserking,if=debuff.vendetta.up
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
  end
  -- actions.cds+=/fireblood,if=debuff.vendetta.up
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
  end
  -- actions.cds+=/ancestral_call,if=debuff.vendetta.up
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
  end

  return false
end

-- # Cooldowns
local function CDs ()
  -- Higher Priority Trinket Handling
  if Settings.Commons.UseTrinkets then
    -- Special Font of Power Handling
    -- use_item,name=azsharas_font_of_power,if=!stealthed.all&master_assassin_remains=0&(cooldown.vendetta.remains<?cooldown.toxic_blade.remains)<10+10*equipped.ashvanes_razor_coral&!debuff.vendetta.up&!debuff.toxic_blade.up
    if I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() and not Player:StealthUp(true, true) and MasterAssassinRemains() <= 0
      and math.max(S.Vendetta:CooldownRemains(), S.Shiv:CooldownRemains() * num(I.RazorCoral:IsEquipped())) < 10 + 10 * num(I.RazorCoral:IsEquipped())
      and not Target:DebuffUp(S.Vendetta) and not Target:DebuffUp(S.ShivDebuff) then
      if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Use Font of Power" end
    end
    if I.RazorCoral:IsEquipped() and I.RazorCoral:IsReady() then
      -- use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|fight_remains<20
      if S.RazorCoralDebuff:AuraActiveCount() == 0 or HL.BossFilteredFightRemains("<", 20) then
        if HR.Cast(I.RazorCoral, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Razor Coral" end
      end
    end
    -- use_item,name=galecallers_boon,if=(debuff.vendetta.up|(!talent.exsanguinate.enabled&cooldown.vendetta.remains>45|talent.exsanguinate.enabled&(cooldown.exsanguinate.remains<6|cooldown.exsanguinate.remains>20&fight_remains>65)))&!exsanguinated.rupture
    if I.GalecallersBoon:IsEquipped() and I.GalecallersBoon:IsReady() then
      if (Target:DebuffUp(S.Vendetta) or (not S.Exsanguinate:IsAvailable() and S.Vendetta:CooldownRemains() > 45
        or S.Exsanguinate:IsAvailable() and (S.Exsanguinate:CooldownRemains() < 6 or S.Exsanguinate:CooldownRemains() > 20 and HL.FilteredFightRemains(MeleeEnemies10y, ">", 65, true))))
        and not Rogue.Exsanguinated(Target, S.Rupture) then
        if HR.Cast(I.GalecallersBoon, nil, Settings.Commons.TrinketDisplayStyle) then return "Cast Galecallers Boon" end
      end
    end
  end

  if Target:IsInMeleeRange(5) then
    -- Quick and dirty Flagellation
    if S.Flagellation:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.Flagellation) then return "Cast Flrgrrlation" end
    end
    if S.FlagellationMastery:IsCastable() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.FlagellationMastery, Settings.Commons.OffGCDasOffGCD.FlagellationMastery) then return "Cast Flrgrrlation Mastery" end
    end

    -- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&dot.rupture.ticking&master_assassin_remains=0
    if HR.CDsON() and not Player:StealthUp(true, true) and Target:DebuffUp(S.Rupture) and MasterAssassinRemains() <= 0 then
      ShouldReturn = Essences()
      if ShouldReturn then return ShouldReturn end
    end

    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit*1.5|(raid_event.adds.in>40&combo_points.deficit>=cp_max_spend)
    if S.MarkedforDeath:IsCastable() then
      if Target:FilteredTimeToDie("<", Player:ComboPointsDeficit() * 1.5) then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      end
      if ComboPointsDeficit >= Rogue.CPMaxSpend() then
        HR.CastSuggested(S.MarkedforDeath)
      end
    end

    if HR.CDsON() then
      -- actions.cds+=/vendetta,if=!stealthed.rogue&dot.rupture.ticking&!debuff.vendetta.up&variable.vendetta_subterfuge_condition&variable.vendetta_nightstalker_condition&variable.vendetta_font_condition
      if S.Vendetta:IsCastable() and not Player:StealthUp(true, false) and Target:DebuffUp(S.Rupture) and not Target:DebuffUp(S.Vendetta) then
        -- actions.cds+=/variable,name=vendetta_subterfuge_condition,value=!talent.subterfuge.enabled|!azerite.shrouded_suffocation.enabled|dot.garrote.pmultiplier>1&(spell_targets.fan_of_knives<6|!cooldown.vanish.up)
        local SubterfugeCondition = (not S.Subterfuge:IsAvailable() or not S.ShroudedSuffocation:AzeriteEnabled() or Target:PMultiplier(S.Garrote) > 1
          and (MeleeEnemies10yCount < 6 or not S.Vanish:CooldownUp()))
        -- actions.cds+=/variable,name=vendetta_nightstalker_condition,value=!talent.nightstalker.enabled|!talent.exsanguinate.enabled|cooldown.exsanguinate.remains<5-2*talent.deeper_stratagem.enabled
        local NightstalkerCondition = (not S.Nightstalker:IsAvailable() or not S.Exsanguinate:IsAvailable()
          or S.Exsanguinate:CooldownRemains() < 5 - 2 * num(S.DeeperStratagem:IsAvailable()))
        -- actions.cds+=/variable,name=vendetta_font_condition,value=!equipped.azsharas_font_of_power|azerite.shrouded_suffocation.enabled|debuff.razor_coral_debuff.down|trinket.ashvanes_razor_coral.cooldown.remains<10&(cooldown.toxic_blade.remains<1|debuff.toxic_blade.up)
        local FontCondition = (not Settings.Commons.UseTrinkets or not I.FontOfPower:IsEquipped() or S.ShroudedSuffocation:AzeriteEnabled()
          or S.RazorCoralDebuff:AuraActiveCount() == 0 or I.RazorCoral:CooldownRemains() < 10 and (S.Shiv:CooldownRemains() < 1 or Target:DebuffUp(S.ShivDebuff)))
        if SubterfugeCondition and NightstalkerCondition and FontCondition then
          if HR.Cast(S.Vendetta, Settings.Assassination.GCDasOffGCD.Vendetta) then return "Cast Vendetta" end
        end
      end
      if S.Vanish:IsCastable() and not Player:IsTanking(Target) then
        local VanishSuggested = false
        if S.Nightstalker:IsAvailable() then
          -- actions.cds+=/vanish,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1
          if not VanishSuggested and S.Exsanguinate:IsAvailable() and ComboPoints >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemains() < 1 then
            if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Exsanguinate)" end
            VanishSuggested = true
          end
          -- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&(debuff.vendetta.up|essence.vision_of_perfection.enabled)
          if not VanishSuggested and not S.Exsanguinate:IsAvailable() and ComboPoints >= Rogue.CPMaxSpend()
            and (Target:DebuffUp(S.Vendetta) or Spell:EssenceEnabled(AE.VisionofPerfection)) then
            if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Nightstalker)" end
            VanishSuggested = true
          end
        end
        -- actions.cds+=/variable,name=ss_vanish_condition,value=azerite.shrouded_suffocation.enabled&(non_ss_buffed_targets>=1|spell_targets.fan_of_knives=3)&(ss_buffed_targets_above_pandemic=0|spell_targets.fan_of_knives>=6)
        local VarSSVanishCondition = S.ShroudedSuffocation:AzeriteEnabled() and (NonSSBuffedTargets() >= 1 or MeleeEnemies10yCount == 3)
          and (SSBuffedTargetsAbovePandemic() == 0 or MeleeEnemies10yCount >= 6)
        -- actions.cds+=/vanish,if=talent.subterfuge.enabled&!stealthed.rogue&cooldown.garrote.up&(variable.ss_vanish_condition|!azerite.shrouded_suffocation.enabled&(dot.garrote.refreshable|debuff.vendetta.up&dot.garrote.pmultiplier<=1))&combo_points.deficit>=((1+2*azerite.shrouded_suffocation.enabled)*spell_targets.fan_of_knives)>?4&raid_event.adds.in>12
        if not VanishSuggested and S.Subterfuge:IsAvailable() and not Player:StealthUp(true, false) and S.Garrote:CooldownUp()
          and (VarSSVanishCondition or not S.ShroudedSuffocation:AzeriteEnabled()
            and (Target:DebuffRefreshable(S.Garrote) or Target:DebuffUp(S.Vendetta) and Target:PMultiplier(S.Garrote) <= 1))
          and ComboPointsDeficit >= math.min((1 + 2 * num(S.ShroudedSuffocation:AzeriteEnabled())) * MeleeEnemies10yCount, 4) then
          -- actions.cds+=/pool_resource,for_next=1,extra_amount=45
          if not Settings.Assassination.NoPooling and Player:EnergyPredicted() < 45 then
            if HR.Cast(S.PoolEnergy) then return "Pool for Vanish (Subterfuge)" end
          end
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Subterfuge)" end
          VanishSuggested = true
        end
        -- actions.cds+=/vanish,if=talent.master_assassin.enabled&!stealthed.all&master_assassin_remains<=0&!dot.rupture.refreshable&dot.garrote.remains>3&debuff.vendetta.up&(!talent.toxic_blade.enabled|debuff.toxic_blade.up)&(!essence.blood_of_the_enemy.major|debuff.blood_of_the_enemy.up)
        if not VanishSuggested and S.MasterAssassin:IsAvailable() and not Player:StealthUp(true, false) and MasterAssassinRemains() <= 0
          and not Target:DebuffRefreshable(S.Rupture, RuptureThreshold) and Target:DebuffRemains(S.Garrote) > 3
          and (Target:DebuffUp(S.Vendetta) and Target:DebuffUp(S.ShivDebuff)
          and (not Spell:MajorEssenceEnabled(AE.BloodoftheEnemy) or Target:DebuffUp(S.BloodoftheEnemyDebuff))
            or Spell:EssenceEnabled(AE.VisionofPerfection)) then
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Master Assassin)" end
        end
      end
      -- actions.cds+=/shadowmeld,if=!stealthed.all&azerite.shrouded_suffocation.enabled&dot.garrote.refreshable&dot.garrote.pmultiplier<=1&combo_points.deficit>=1
      if HR.CDsON() and S.Shadowmeld:IsCastable() and not Player:StealthUp(true, true) and S.ShroudedSuffocation:AzeriteEnabled() and Target:DebuffRefreshable(S.Garrote) and Target:PMultiplier(S.Garrote) <= 1 and Player:ComboPointsDeficit() >= 1 then
        if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
      end
      if S.Exsanguinate:IsCastable() then
        -- actions.cds+=/exsanguinate,if=!stealthed.rogue&(!dot.garrote.refreshable&dot.rupture.remains>4+4*cp_max_spend|dot.rupture.remains*0.5>target.time_to_die)&target.time_to_die>4
        if not Player:StealthUp(true, false) and (not Target:DebuffRefreshable(S.Garrote) and Target:DebuffRemains(S.Rupture) > 4+4*Rogue.CPMaxSpend()
          or Target:FilteredTimeToDie("<", Target:DebuffRemains(S.Rupture)*0.5)) and (Target:FilteredTimeToDie(">", 4) or Target:TimeToDieIsNotValid())
          and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
          if HR.Cast(S.Exsanguinate) then return "Cast Exsanguinate" end
        end
      end
      -- actions.cds+=/toxic_blade,if=dot.rupture.ticking&(!equipped.azsharas_font_of_power|cooldown.vendetta.remains>10)
      if S.Shiv:IsCastable() and Target:IsInMeleeRange(5) and Target:DebuffUp(S.Rupture) and Player:Level() >= 56
        and (not Settings.Commons.UseTrinkets or not I.FontOfPower:IsEquipped() or S.Vendetta:CooldownRemains() > 10) then
        if HR.Cast(S.Shiv) then ShouldReturn = "Cast Shiv" end
      end

      -- Placeholder Bone Spike
      if S.SerratedBoneSpike:IsCastable() and not Player:StealthUp(true, true) then
        if not Target:DebuffUp(S.SerratedBoneSpikeDebuff) then
          if HR.Cast(S.SerratedBoneSpike) then ShouldReturn = "Cast Serrated Bone Spike" end
        else
          if HR.AoEON() then
            local function Evaluate_Bone_Spike_Target(TargetUnit)
              return not TargetUnit:DebuffUp(S.SerratedBoneSpikeDebuff) and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold)
            end
            SuggestCycleDoT(S.SerratedBoneSpike, Evaluate_Bone_Spike_Target, 4, Enemies30y)
          end
          if ComboPointsDeficit > 1 and S.SerratedBoneSpike:ChargesFractional() > 2.9 then
            if HR.Cast(S.SerratedBoneSpike) then ShouldReturn = "Cast Serrated Bone Spike Filler" end
          end
        end
      end
    end

    -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|debuff.vendetta.up&cooldown.vanish.remains<5

    -- Trinkets
    if Settings.Commons.UseTrinkets and (not ShouldReturn or Settings.Commons.TrinketDisplayStyle ~= "Main Icon") then
      if ShouldReturn then
        Trinkets()
      else
        ShouldReturn = Trinkets()
      end
    end

    -- Racials
    if HR.CDsON() and Target:DebuffUp(S.Vendetta) and (not ShouldReturn or Settings.Commons.OffGCDasOffGCD.Racials) then
      if ShouldReturn then
        Racials()
      else
        ShouldReturn = Racials()
      end
    end
  end

  return ShouldReturn
end

-- # Stealthed
local function Stealthed ()
  -- actions.stealthed=rupture,if=talent.nightstalker.enabled&combo_points>=4&target.time_to_die-remains>6
  if S.Rupture:IsReady() and S.Nightstalker:IsAvailable() and ComboPoints >= 4
    and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid()) then
    if HR.Cast(S.Rupture, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Rupture (Nightstalker)" end
  end
  if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() then
    -- actions.stealthed+=/pool_resource,for_next=1
    -- actions.stealthed+=/garrote,if=azerite.shrouded_suffocation.enabled&buff.subterfuge.up&buff.subterfuge.remains<1.3&!ss_buffed
    -- Not implemented because this is special for simc and we can have a shifting main target in reality where simc checks only a fix target on all normal abilities.
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
        HR.CastLeftNameplate(TargetIfUnit, S.Garrote)
      end
    end
    if GarroteIfFunc(Target) then
      if HR.CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Cast Garrote (Subterfuge)" end
    end
  end
  -- actions.stealthed+=/rupture,if=talent.subterfuge.enabled&azerite.shrouded_suffocation.enabled&!dot.rupture.ticking&variable.single_target
  if S.Rupture:IsReady() and S.Subterfuge:IsAvailable() and ComboPoints > 0 and S.ShroudedSuffocation:AzeriteEnabled()
    and not Target:DebuffUp(S.Rupture) and MeleeEnemies10yCount < 2 then
    if HR.Cast(S.Rupture, nil, nil, not Target:IsInMeleeRange(5)) then return "Cast Rupture (Shrouded Suffocation)" end
  end
  if S.Garrote:IsCastable() and S.Subterfuge:IsAvailable() then
    -- actions.stealthed+=/pool_resource,for_next=1
    -- actions.stealthed+=/garrote,target_if=min:remains,if=talent.subterfuge.enabled&azerite.shrouded_suffocation.enabled&(active_enemies>1|!talent.exsanguinate.enabled)&target.time_to_die>remains&(remains<18|!ss_buffed)
    local function GarroteTargetIfFunc(TargetUnit)
      return TargetUnit:DebuffRemains(S.Garrote)
    end
    local function GarroteIfFunc(TargetUnit)
      return S.ShroudedSuffocation:AzeriteEnabled()
        and (MeleeEnemies10yCount > 1 or not S.Exsanguinate:IsAvailable())
        and (TargetUnit:FilteredTimeToDie(">", 0, -TargetUnit:DebuffRemains(S.Garrote)) or TargetUnit:TimeToDieIsNotValid())
        and (TargetUnit:DebuffRemains(S.Garrote) < 18 or not SSBuffed(TargetUnit))
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold)
    end
    if HR.AoEON() then
      local TargetIfUnit = CheckTargetIfTarget("min", GarroteTargetIfFunc, GarroteIfFunc)
      if TargetIfUnit and TargetIfUnit:GUID() ~= Target:GUID() then
        HR.CastLeftNameplate(TargetIfUnit, S.Garrote)
      end
    end
    if GarroteIfFunc(Target) then
      if HR.CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Cast Garrote (Shrouded Suffocation)" end
    end
    -- actions.stealthed+=/pool_resource,for_next=1
    -- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&active_enemies=1&buff.subterfuge.remains<1.3
    if S.Exsanguinate:IsAvailable() and MeleeEnemies10yCount == 1 and Player:BuffRemains(S.SubterfugeBuff) < 1.3 then
      if HR.CastPooling(S.Garrote, nil, not Target:IsInMeleeRange(5)) then return "Pool for Garrote (Exsanguinate Refresh)" end
    end
  end
end

-- # Damage over time abilities
local function Dot ()
  local SkipCycleGarrote, SkipCycleRupture, SkipRupture
  if PriorityRotation and MeleeEnemies10yCount > 3 then
    -- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&spell_targets.fan_of_knives>3&(dot.garrote.remains<cooldown.garrote.duration|poisoned_bleeds>5)
    SkipCycleGarrote = Target:DebuffRemains(S.Garrote) < 6 or PoisonedBleeds > 5
    -- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&spell_targets.fan_of_knives>3&(debuff.toxic_blade.up|(poisoned_bleeds>5&!azerite.scent_of_blood.enabled))
    SkipCycleRupture = Target:DebuffUp(S.ShivDebuff) or (PoisonedBleeds > 5 and not S.ScentOfBlood:AzeriteEnabled())
  end
  -- actions.dot+=/variable,name=skip_rupture,value=debuff.vendetta.up&(debuff.toxic_blade.up|master_assassin_remains>0)&dot.rupture.remains>2
  SkipRupture = Target:DebuffUp(S.Vendetta) and (Target:DebuffUp(S.ShivDebuff) or MasterAssassinRemains() > 0) and Target:DebuffRemains(S.Rupture) > 2

  if HR.CDsON() and S.Exsanguinate:IsAvailable() then
    -- actions.dot+=/pool_resource,for_next=1
    -- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!exsanguinated.garrote&dot.garrote.pmultiplier<=1&cooldown.exsanguinate.remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
    if S.Garrote:IsCastable() and Target:IsInMeleeRange(5) and MeleeEnemies10yCount == 1 and S.Exsanguinate:CooldownRemains() < 2 and not Rogue.Exsanguinated(Target, S.Garrote)
      and Target:PMultiplier(S.Garrote) <= 1 and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Garrote)*0.5) then
      if HR.CastPooling(S.Garrote) then return "Cast Garrote (Pre-Exsanguinate)" end
    end
    -- actions.dot+=/rupture,if=talent.exsanguinate.enabled&!dot.garrote.refreshable&(combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1&dot.rupture.remains*0.5<target.time_to_die)
    if S.Rupture:IsReady() and Target:IsInMeleeRange(5) and ComboPoints > 0 and not Target:DebuffRefreshable(S.Garrote)
      and (ComboPoints >= Rogue.CPMaxSpend() and S.Exsanguinate:CooldownRemains() < 1 and Target:FilteredTimeToDie(">", Target:DebuffRemains(S.Rupture)*0.5)) then
      if HR.Cast(S.Rupture) then return "Cast Rupture (Pre-Exsanguinate)" end
    end
  end
  -- actions.dot+=/pool_resource,for_next=1
  -- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1+3*(azerite.shrouded_suffocation.enabled&cooldown.vanish.up)&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&!ss_buffed&(target.time_to_die-remains)>4&(master_assassin_remains=0|!ticking&azerite.shrouded_suffocation.enabled)
  -- actions.dot+=/pool_resource,for_next=1
  -- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1+3*(azerite.shrouded_suffocation.enabled&cooldown.vanish.up)&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&!ss_buffed&(target.time_to_die-remains)>12&(master_assassin_remains=0|!ticking&azerite.shrouded_suffocation.enabled)
  local EmpoweredDotRefresh = MeleeEnemies10yCount >= 3 + num(S.ShroudedSuffocation:AzeriteEnabled())
  if S.Garrote:IsCastable() and (ComboPointsDeficit >= 1 + 3 * num(S.ShroudedSuffocation:AzeriteEnabled() and S.Vanish:CooldownUp())) then
    local function Evaluate_Garrote_Target(TargetUnit)
      return TargetUnit:DebuffRefreshable(S.Garrote)
        and (TargetUnit:PMultiplier(S.Garrote) <= 1 or TargetUnit:DebuffRemains(S.Garrote)
          <= (Rogue.Exsanguinated(TargetUnit, S.Garrote) and ExsanguinatedBleedTickTime or BleedTickTime) and EmpoweredDotRefresh)
        and (not Rogue.Exsanguinated(TargetUnit, S.Garrote) or TargetUnit:DebuffRemains(S.Garrote) <= 1.5 and EmpoweredDotRefresh)
        and not SSBuffed(TargetUnit)
        and (MasterAssassinRemains() <= 0 or not Target:DebuffUp(S.Garrote) and S.ShroudedSuffocation:AzeriteEnabled())
        and Rogue.CanDoTUnit(TargetUnit, GarroteDMGThreshold)
    end
    if Target:IsInMeleeRange(5) and Evaluate_Garrote_Target(Target)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Garrote)) or Target:TimeToDieIsNotValid()) then
      if HR.CastPooling(S.Garrote) then return "Pool for Garrote (ST)" end
    end
    if HR.AoEON() and not SkipCycleGarrote then
      SuggestCycleDoT(S.Garrote, Evaluate_Garrote_Target, 12, MeleeEnemies5y)
    end
  end
  -- actions.dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>3&remains<2+(spell_targets>=5)&combo_points>=4
  if HR.AoEON() and S.CrimsonTempest:IsReady() and ComboPoints >= 4 and MeleeEnemies10yCount > 3 then
    for _, CycleUnit in pairs(MeleeEnemies10y) do
      -- Note: The APL does not do this due to target_if mechanics, just to determine if any targets are low on duration of the AoE Bleed
      if CycleUnit:DebuffRemains(S.CrimsonTempest) < 2 + num(MeleeEnemies10yCount >= 5) then
        if HR.Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE 4+)" end
      end
    end
  end
  -- actions.dot+=/rupture,if=!variable.skip_rupture&(combo_points>=4&refreshable|!ticking&(time>10|combo_points>=2))&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&target.time_to_die-remains>4
  -- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&target.time_to_die-remains>4+(poisoned_bleeds>2)*6
  if not SkipRupture and S.Rupture:IsReady() then
    local function Evaluate_Rupture_Target(TargetUnit)
      return TargetUnit:DebuffRefreshable(S.Rupture, RuptureThreshold)
        and (TargetUnit:PMultiplier(S.Rupture) <= 1 or TargetUnit:DebuffRemains(S.Rupture)
          <= (Rogue.Exsanguinated(TargetUnit, S.Rupture) and ExsanguinatedBleedTickTime or BleedTickTime) and EmpoweredDotRefresh)
        and (not Rogue.Exsanguinated(TargetUnit, S.Rupture) or TargetUnit:DebuffRemains(S.Rupture) <= ExsanguinatedBleedTickTime*2 and EmpoweredDotRefresh)
        and Rogue.CanDoTUnit(TargetUnit, RuptureDMGThreshold)
    end
    if Target:IsInMeleeRange(5) and (ComboPoints >= 4 and Target:DebuffRefreshable(S.Rupture, RuptureThreshold)
      or (not Target:DebuffUp(S.Rupture) and (HL.CombatTime() > 10 or (ComboPoints >= 2)))) and Evaluate_Rupture_Target(Target)
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid()) then
      if HR.Cast(S.Rupture) then return "Cast Rupture (Refresh)" end
    end
    if HR.AoEON() and not SkipCycleRupture and ComboPoints >= 4 then
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, RuptureDurationThreshold, MeleeEnemies5y)
    end
  end
  if S.CrimsonTempest:IsReady() then
    -- actions.dot+=/crimson_tempest,target_if=min:remains,if=spell_targets>1&remains<2+(spell_targets>=5)&combo_points>=4
    -- Add the <4 check because this line evaluation is mutually exclusive to the one above at spell_targets>3
    if HR.AoEON() and ComboPoints >= 4 and MeleeEnemies10yCount > 1 and MeleeEnemies10yCount < 4 then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        -- Note: The APL does not do this due to target_if mechanics, just to determine if any targets are low on duration of the AoE Bleed
        if CycleUnit:DebuffRemains(S.CrimsonTempest) < 2 + num(MeleeEnemies10yCount >= 5) then
          if HR.Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (AoE 2-3)" end
        end
      end
    end
    -- actions.dot+=/crimson_tempest,if=spell_targets=1&combo_points>=(cp_max_spend-1)&refreshable&!exsanguinated&!debuff.toxic_blade.up&master_assassin_remains=0&!azerite.twist_the_knife.enabled&target.time_to_die-remains>4
    if Target:IsInMeleeRange(5) and MeleeEnemies10yCount == 1 and ComboPoints >= (Rogue.CPMaxSpend() - 1) and Target:DebuffRefreshable(S.CrimsonTempest, CrimsonTempestThreshold)
      and not Rogue.Exsanguinated(Target, S.CrimsonTempest) and not Target:DebuffUp(S.ShivDebuff) and MasterAssassinRemains() <= 0 and not S.TwistTheKnife:AzeriteEnabled()
      and (Target:FilteredTimeToDie(">", 4, -Target:DebuffRemains(S.CrimsonTempest)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold) then
      if HR.Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (ST)" end
    end
    -- actions.dot+=/crimson_tempest,if=spell_targets>(7-buff.envenom.up)&combo_points>=4+talent.deeper_stratagem.enabled&!debuff.vendetta.up&!debuff.toxic_blade.up&energy.deficit<=25+variable.energy_regen_combined
    if HR.AoEON() and ComboPoints >= 4 + num(S.DeeperStratagem:IsAvailable()) and MeleeEnemies10yCount > 7 - num(Player:BuffUp(S.Envenom))
      and not Target:DebuffUp(S.Vendetta) and not Target:DebuffUp(S.ShivDebuff) and Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined then
      if HR.Cast(S.CrimsonTempest) then return "Cast Crimson Tempest (Replace Envenom)" end
    end
  end

  -- Placeholder Slice and Dice Line Copied from Outlaw
  if S.SliceAndDice:IsCastable() and ComboPoints >= 4
    and (HL.FilteredFightRemains(MeleeEnemies10y, ">", Player:BuffRemains(S.SliceAndDice), true) or Player:BuffRemains(S.SliceAndDice) == 0)
    and Player:BuffRemains(S.SliceAndDice) < (1 + ComboPoints) * 1.8 then
    if HR.Cast(S.SliceAndDice) then return "Cast Slice and Dice" end
  end

  return false
end

-- # Direct damage abilities
local function Direct ()
  -- actions.direct=envenom,if=combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.toxic_blade.up|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2)&(!talent.exsanguinate.enabled|!debuff.vendetta.up|cooldown.exsanguinate.remains>2)
  if S.Envenom:IsReady() and Target:IsInMeleeRange(5) and ComboPoints >= 4 + (S.DeeperStratagem:IsAvailable() and 1 or 0)
    and (Target:DebuffUp(S.Vendetta) or Target:DebuffUp(S.ShivDebuff) or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined
      or MeleeEnemies10yCount >= 2 or Settings.Assassination.NoPooling) and (not S.Exsanguinate:IsAvailable() or not Target:DebuffUp(S.Vendetta)
      or S.Exsanguinate:CooldownRemains() > 2 or not HR.CDsON()) then
    if HR.Cast(S.Envenom) then return "Cast Envenom" end
  end

  -------------------------------------------------------------------
  -------------------------------------------------------------------
  -- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|spell_targets.fan_of_knives>=2
  -- This is used in all following fillers, so we just return false if not true and won't consider these.
  if not (ComboPointsDeficit > 1 or Player:EnergyDeficitPredicted() <= 25 + Energy_Regen_Combined or MeleeEnemies10yCount >= 2) then
    return false
  end
  -------------------------------------------------------------------
  -------------------------------------------------------------------

  if S.FanofKnives:IsCastable() and Target:IsInMeleeRange(10) then
    -- actions.direct+=/fan_of_knives,if=variable.use_filler&azerite.echoing_blades.enabled&spell_targets.fan_of_knives>=2+(debuff.vendetta.up*(1+(azerite.echoing_blades.rank=1)))
    if S.EchoingBlades:AzeriteEnabled() and MeleeEnemies10yCount >= 2 + (num(Target:DebuffUp(S.Vendetta)) * (1 + num(S.EchoingBlades:AzeriteRank() == 1))) then
      if HR.Cast(S.FanofKnives) then return "Cast Fan of Knives (Echoing Blades)" end
    end
    -- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|(!priority_rotation&spell_targets.fan_of_knives>=4+(azerite.double_dose.rank>2)+stealthed.rogue))
    if HR.AoEON() and (Player:BuffStack(S.HiddenBladesBuff) >= 19 or Player:BuffStack(S.TheDreadlordsDeceit) >= 29
      or not PriorityRotation and MeleeEnemies10yCount >= 4 + num(Player:StealthUp(true, false)) + num(S.DoubleDose:AzeriteRank() > 2)) then
      if HR.Cast(S.FanofKnives) then return "Cast Fan of Knives" end
    end
    -- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives>=3
    if HR.AoEON() and Player:BuffUp(S.DeadlyPoison) and MeleeEnemies10yCount >= 3 then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        -- Note: The APL does not do this due to target_if mechanics, but since we are cycling we should check to see if the unit has a bleed
        if (CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) and not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff) then
          if HR.CastPooling(S.FanofKnives) then return "Cast Fan of Knives (DP Refresh)" end
        end
      end
    end
  end
  -- actions.direct+=/blindside,if=variable.use_filler&(buff.blindside.up|!talent.venom_rush.enabled&!azerite.double_dose.enabled)
  if S.Ambush:IsCastable() and Target:IsInMeleeRange(5) and Player:BuffUp(S.BlindsideBuff) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush (Blindside)" end
  end
  -- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives=2
  if S.Mutilate:IsCastable() and Target:IsInMeleeRange(5) and MeleeEnemies10yCount == 2 then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(MeleeEnemies5y) do
      -- Note: The APL does not do this due to target_if mechanics, but since we are cycling we should check to see if the unit has a bleed
      if CycleUnit:GUID() ~= TargetGUID and (CycleUnit:DebuffUp(S.Garrote) or CycleUnit:DebuffUp(S.Rupture)) and not CycleUnit:DebuffUp(S.DeadlyPoisonDebuff) then
        HR.CastLeftNameplate(CycleUnit, S.Mutilate)
        break
      end
    end
  end
  -- actions.direct+=/mutilate,if=variable.use_filler
  if S.Mutilate:IsCastable() and Target:IsInMeleeRange(5) then
    if HR.CastPooling(S.Mutilate) then return "Cast Mutilate" end
  end

  return false
end

-- APL Main
local function APL ()
  -- Spell ID Changes check
  Stealth = S.Subterfuge:IsAvailable() and S.Stealth2 or S.Stealth; -- w/ or w/o Subterfuge Talent

  -- Unit Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Poisoned Knife Poison refresh & Serrated Bone Spike cycle
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10) -- Fan of Knives
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(5) -- Melee cycle
  else
    MeleeEnemies10yCount = 1
  end

  -- Compute Cache
  ComboPoints = Player:ComboPoints()
  ComboPointsDeficit = Player:ComboPointsMax() - ComboPoints
  RuptureThreshold = (4 + ComboPoints * 4) * 0.3
  CrimsonTempestThreshold = (2 + ComboPoints * 2) * 0.3
  RuptureDMGThreshold = S.Envenom:Damage()*Settings.Assassination.EnvenomDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.
  GarroteDMGThreshold = S.Mutilate:Damage()*Settings.Assassination.MutilateDMGOffset; -- Used as TTD Not Valid fallback since it's a generator.
  PriorityRotation = UsePriorityRotation()

  -- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial(S.CrimsonVial)
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint(S.Feint)
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  local PoisonRefreshTime = Player:AffectingCombat() and Settings.Assassination.PoisonRefreshCombat*60 or Settings.Assassination.PoisonRefresh*60
  -- Lethal Poison
  if Player:BuffRemains(S.DeadlyPoison) <= PoisonRefreshTime
    and Player:BuffRemains(S.WoundPoison) <= PoisonRefreshTime then
    HR.CastSuggested(S.DeadlyPoison)
  end
  -- Non-Lethal Poison
  if Player:BuffRemains(S.CripplingPoison) <= PoisonRefreshTime then
    HR.CastSuggested(S.CripplingPoison)
  end

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
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
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
        -- actions.precombat+=/use_item,name=azsharas_font_of_power
        if Settings.Commons.UseTrinkets and I.FontOfPower:IsEquipped() and I.FontOfPower:IsReady() then
          if HR.Cast(I.FontOfPower, nil, Settings.Commons.TrinketDisplayStyle) then return "Use Font of Power (OOC)" end
        end
        -- actions.precombat+=/guardian_of_azeroth,if=talent.exsanguinate.enabled
        if S.GuardianofAzeroth:IsCastable() and S.Exsanguinate:IsAvailable() then
          if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "Cast GuardianofAzeroth (OOC)" end
        end
      end
    end
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath)
  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- actions=variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*7%(2*spell_haste)
    PoisonedBleeds = Rogue.PoisonedBleeds()
    Energy_Regen_Combined = Player:EnergyRegen() + PoisonedBleeds * 7 / (2 * Player:SpellHaste())
    RuptureDurationThreshold = 4 + num(PoisonedBleeds > 2) * 6

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
    -- actions+=/call_action_list,name=dot
    ShouldReturn = Dot()
    if ShouldReturn then return ShouldReturn end
    -- actions+=/call_action_list,name=direct
    ShouldReturn = Direct()
    if ShouldReturn then return ShouldReturn end
    -- Racials
    if HR.CDsON() then
      -- actions+=/arcane_torrent,if=energy.deficit>=15+variable.energy_regen_combined
      if S.ArcaneTorrent:IsCastable() and Target:IsInMeleeRange(5) and Player:EnergyDeficitPredicted() > 15 + Energy_Regen_Combined then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsCastable() and Target:IsInMeleeRange(5) then
        if HR.Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
        if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
        if HR.Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
      end
    end
    -- Poisoned Knife Out of Range [EnergyCap] or [PoisonRefresh]
    if S.PoisonedKnife:IsCastable() and Target:IsInRange(30) and not Player:StealthUp(true, true)
      and ((not Target:IsInMeleeRange(10) and Player:EnergyTimeToMax() <= Player:GCD()*1.2)
        or (not Target:IsInMeleeRange(5) and Target:DebuffRefreshable(S.DeadlyPoisonDebuff))) then
      if HR.Cast(S.PoisonedKnife) then return "Cast Poisoned Knife" end
    end
    -- Trick to take in consideration the Recovery Setting
    if S.Mutilate:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.PoolEnergy) then return "Normal Pooling" end
    end
  end
end

local function Init ()
  S.RazorCoralDebuff:RegisterAuraTracking()
end

HR.SetAPL(259, APL, Init)

-- Last Update: 2020-06-10

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/marked_for_death,precombat_seconds=5,if=raid_event.adds.in>15
-- actions.precombat+=/apply_poison
-- actions.precombat+=/stealth
-- actions.precombat+=/use_item,name=azsharas_font_of_power
-- actions.precombat+=/guardian_of_azeroth,if=talent.exsanguinate.enabled

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- actions+=/variable,name=energy_regen_combined,value=energy.regen+poisoned_bleeds*7%(2*spell_haste)
-- actions+=/variable,name=single_target,value=spell_targets.fan_of_knives<2
-- actions+=/call_action_list,name=stealthed,if=stealthed.rogue
-- actions+=/call_action_list,name=cds,if=(!talent.master_assassin.enabled|dot.garrote.ticking)
-- actions+=/call_action_list,name=dot
-- actions+=/call_action_list,name=direct
-- actions+=/arcane_torrent,if=energy.deficit>=15+variable.energy_regen_combined
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Cooldowns
-- actions.cds=use_item,name=azsharas_font_of_power,if=!stealthed.all&master_assassin_remains=0&(cooldown.vendetta.remains<?(cooldown.toxic_blade.remains*equipped.ashvanes_razor_coral))<10+10*equipped.ashvanes_razor_coral&!debuff.vendetta.up&!debuff.toxic_blade.up
-- actions.cds+=/call_action_list,name=essences,if=!stealthed.all&dot.rupture.ticking&master_assassin_remains=0
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit*1.5|combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
-- # Vendetta logical conditionals based on current spec
-- actions.cds+=/variable,name=vendetta_subterfuge_condition,value=!talent.subterfuge.enabled|!azerite.shrouded_suffocation.enabled|dot.garrote.pmultiplier>1&(spell_targets.fan_of_knives<6|!cooldown.vanish.up)
-- actions.cds+=/variable,name=vendetta_nightstalker_condition,value=!talent.nightstalker.enabled|!talent.exsanguinate.enabled|cooldown.exsanguinate.remains<5-2*talent.deeper_stratagem.enabled
-- actions.cds+=/variable,name=variable,name=vendetta_font_condition,value=!equipped.azsharas_font_of_power|azerite.shrouded_suffocation.enabled|debuff.razor_coral_debuff.down|trinket.ashvanes_razor_coral.cooldown.remains<10&(cooldown.toxic_blade.remains<1|debuff.toxic_blade.up)
-- actions.cds+=/vendetta,if=!stealthed.rogue&dot.rupture.ticking&!debuff.vendetta.up&variable.vendetta_subterfuge_condition&variable.vendetta_nightstalker_condition&variable.vendetta_font_condition
-- # Vanish with Exsg + Nightstalker: Maximum CP and Exsg ready for next GCD
-- actions.cds+=/vanish,if=talent.exsanguinate.enabled&talent.nightstalker.enabled&combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1
-- # Vanish with Nightstalker + No Exsg: Maximum CP and Vendetta up (unless using VoP)
-- actions.cds+=/vanish,if=talent.nightstalker.enabled&!talent.exsanguinate.enabled&combo_points>=cp_max_spend&(debuff.vendetta.up|essence.vision_of_perfection.enabled)
-- # See full comment on https://github.com/Ravenholdt-TC/Rogue/wiki/Assassination-APL-Research.
-- actions.cds+=/variable,name=ss_vanish_condition,value=azerite.shrouded_suffocation.enabled&(non_ss_buffed_targets>=1|spell_targets.fan_of_knives=3)&(ss_buffed_targets_above_pandemic=0|spell_targets.fan_of_knives>=6)
-- actions.cds+=/pool_resource,for_next=1,extra_amount=45
-- actions.cds+=/vanish,if=talent.subterfuge.enabled&!stealthed.rogue&cooldown.garrote.up&(variable.ss_vanish_condition|!azerite.shrouded_suffocation.enabled&(dot.garrote.refreshable|debuff.vendetta.up&dot.garrote.pmultiplier<=1))&combo_points.deficit>=((1+2*azerite.shrouded_suffocation.enabled)*spell_targets.fan_of_knives)>?4&raid_event.adds.in>12
-- # Vanish with Master Assasin: No stealth and no active MA buff, Rupture not in refresh range, during Vendetta+TB+BotE (unless using VoP)
-- actions.cds+=/vanish,if=talent.master_assassin.enabled&!stealthed.all&master_assassin_remains<=0&!dot.rupture.refreshable&dot.garrote.remains>3&(debuff.vendetta.up&(!talent.toxic_blade.enabled|debuff.toxic_blade.up)&(!essence.blood_of_the_enemy.major|debuff.blood_of_the_enemy.up)|essence.vision_of_perfection.enabled)
-- # Shadowmeld for Shrouded Suffocation
-- actions.cds+=/shadowmeld,if=!stealthed.all&azerite.shrouded_suffocation.enabled&dot.garrote.refreshable&dot.garrote.pmultiplier<=1&combo_points.deficit>=1
-- # Exsanguinate when not stealthed and both Rupture and Garrote are up for long enough.
-- actions.cds+=/exsanguinate,if=!stealthed.rogue&(!dot.garrote.refreshable&dot.rupture.remains>4+4*cp_max_spend|dot.rupture.remains*0.5>target.time_to_die)&target.time_to_die>4
-- actions.cds+=/toxic_blade,if=dot.rupture.ticking&(!equipped.azsharas_font_of_power|cooldown.vendetta.remains>10)
-- actions.cds+=/potion,if=buff.bloodlust.react|debuff.vendetta.up
-- actions.cds+=/blood_fury,if=debuff.vendetta.up
-- actions.cds+=/berserking,if=debuff.vendetta.up
-- actions.cds+=/fireblood,if=debuff.vendetta.up
-- actions.cds+=/ancestral_call,if=debuff.vendetta.up
-- actions.cds+=/use_item,name=galecallers_boon,if=(debuff.vendetta.up|(!talent.exsanguinate.enabled&cooldown.vendetta.remains>45|talent.exsanguinate.enabled&(cooldown.exsanguinate.remains<6|cooldown.exsanguinate.remains>20&fight_remains>65)))&!exsanguinated.rupture
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=debuff.razor_coral_debuff.down|fight_remains<20
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=(!talent.exsanguinate.enabled|!talent.subterfuge.enabled)&debuff.vendetta.remains>10-4*equipped.azsharas_font_of_power
-- actions.cds+=/use_item,name=ashvanes_razor_coral,if=(talent.exsanguinate.enabled&talent.subterfuge.enabled)&debuff.vendetta.up&(exsanguinated.garrote|azerite.shrouded_suffocation.enabled&dot.garrote.pmultiplier>1)
-- actions.cds+=/use_item,effect_name=cyclotronic_blast,if=master_assassin_remains=0&!debuff.vendetta.up&!debuff.toxic_blade.up&buff.memory_of_lucid_dreams.down&energy<80&dot.rupture.remains>4
-- actions.cds+=/use_item,name=lurkers_insidious_gift,if=debuff.vendetta.up
-- actions.cds+=/use_item,name=lustrous_golden_plumage,if=debuff.vendetta.up
-- actions.cds+=/use_item,effect_name=gladiators_medallion,if=debuff.vendetta.up
-- actions.cds+=/use_item,effect_name=gladiators_badge,if=debuff.vendetta.up
-- # Default fallback for usable items: Use on cooldown.
-- actions.cds+=/use_items

-- # Direct damage abilities
-- # Envenom at 4+ (5+ with DS) CP. Immediately on 2+ targets, with Vendetta, or with TB; otherwise wait for some energy. Also wait if Exsg combo is coming up.
-- actions.direct=envenom,if=combo_points>=4+talent.deeper_stratagem.enabled&(debuff.vendetta.up|debuff.toxic_blade.up|energy.deficit<=25+variable.energy_regen_combined|!variable.single_target)&(!talent.exsanguinate.enabled|cooldown.exsanguinate.remains>2|target.time_to_die<4)
-- actions.direct+=/variable,name=use_filler,value=combo_points.deficit>1|energy.deficit<=25+variable.energy_regen_combined|!variable.single_target
-- # With Echoing Blades, Fan of Knives at 2+ targets, or 3-4+ targets when Vendetta is up
-- actions.direct+=/fan_of_knives,if=variable.use_filler&azerite.echoing_blades.enabled&spell_targets.fan_of_knives>=2+(debuff.vendetta.up*(1+(azerite.echoing_blades.rank=1)))
-- # Fan of Knives at 19+ stacks of Hidden Blades or against 4+ (5+ with Double Dose) targets.
-- actions.direct+=/fan_of_knives,if=variable.use_filler&(buff.hidden_blades.stack>=19|(!priority_rotation&spell_targets.fan_of_knives>=4+(azerite.double_dose.rank>2)+stealthed.rogue))
-- # Fan of Knives to apply Deadly Poison if inactive on any target at 3 targets.
-- actions.direct+=/fan_of_knives,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives>=3
-- actions.direct+=/blindside,if=variable.use_filler&(buff.blindside.up|!talent.venom_rush.enabled&!azerite.double_dose.enabled)
-- # Tab-Mutilate to apply Deadly Poison at 2 targets
-- actions.direct+=/mutilate,target_if=!dot.deadly_poison_dot.ticking,if=variable.use_filler&spell_targets.fan_of_knives=2
-- actions.direct+=/mutilate,if=variable.use_filler

-- # Damage over time abilities
-- # Limit Garrotes on non-primrary targets for the priority rotation if 5+ bleeds are already up
-- actions.dot=variable,name=skip_cycle_garrote,value=priority_rotation&spell_targets.fan_of_knives>3&(dot.garrote.remains<cooldown.garrote.duration|poisoned_bleeds>5)
-- # Limit Ruptures on non-primrary targets for the priority rotation if 5+ bleeds are already up
-- actions.dot+=/variable,name=skip_cycle_rupture,value=priority_rotation&spell_targets.fan_of_knives>3&(debuff.toxic_blade.up|(poisoned_bleeds>5&!azerite.scent_of_blood.enabled))
-- # Limit Ruptures if Vendetta+Toxic Blade/Master Assassin is up and we have 2+ seconds left on the Rupture DoT
-- actions.dot+=/variable,name=skip_rupture,value=debuff.vendetta.up&(debuff.toxic_blade.up|master_assassin_remains>0)&dot.rupture.remains>2
-- # Special Garrote and Rupture setup prior to Exsanguinate cast
-- actions.dot+=/garrote,if=talent.exsanguinate.enabled&!exsanguinated.garrote&dot.garrote.pmultiplier<=1&cooldown.exsanguinate.remains<2&spell_targets.fan_of_knives=1&raid_event.adds.in>6&dot.garrote.remains*0.5<target.time_to_die
-- actions.dot+=/rupture,if=talent.exsanguinate.enabled&!dot.garrote.refreshable&(combo_points>=cp_max_spend&cooldown.exsanguinate.remains<1&dot.rupture.remains*0.5<target.time_to_die)
-- # Garrote upkeep, also tries to use it as a special generator for the last CP before a finisher
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,if=refreshable&combo_points.deficit>=1+3*(azerite.shrouded_suffocation.enabled&cooldown.vanish.up)&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&!ss_buffed&(target.time_to_die-remains)>4&(master_assassin_remains=0|!ticking&azerite.shrouded_suffocation.enabled)
-- actions.dot+=/pool_resource,for_next=1
-- actions.dot+=/garrote,cycle_targets=1,if=!variable.skip_cycle_garrote&target!=self.target&refreshable&combo_points.deficit>=1+3*(azerite.shrouded_suffocation.enabled&cooldown.vanish.up)&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&!ss_buffed&(target.time_to_die-remains)>12&(master_assassin_remains=0|!ticking&azerite.shrouded_suffocation.enabled)
-- # Crimson Tempest on multiple targets at 4+ CP when running out in 2s (up to 4 targets) or 3s (5+ targets)
-- actions.dot+=/crimson_tempest,if=spell_targets>=2&remains<2+(spell_targets>=5)&combo_points>=4
-- # Keep up Rupture at 4+ on all targets (when living long enough and not snapshot)
-- actions.dot+=/rupture,if=!variable.skip_rupture&(combo_points>=4&refreshable|!ticking&(time>10|combo_points>=2))&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&target.time_to_die-remains>4
-- actions.dot+=/rupture,cycle_targets=1,if=!variable.skip_cycle_rupture&!variable.skip_rupture&target!=self.target&combo_points>=4&refreshable&(pmultiplier<=1|remains<=tick_time&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&(!exsanguinated|remains<=tick_time*2&spell_targets.fan_of_knives>=3+azerite.shrouded_suffocation.enabled)&target.time_to_die-remains>4
-- # Crimson Tempest on ST if in pandemic and it will do less damage than Envenom due to TB/MA/TtK
-- actions.dot+=/crimson_tempest,if=spell_targets=1&combo_points>=(cp_max_spend-1)&refreshable&!exsanguinated&!debuff.toxic_blade.up&master_assassin_remains=0&!azerite.twist_the_knife.enabled&target.time_to_die-remains>4

-- # Essences
-- actions.essences=concentrated_flame,if=energy.time_to_max>1&!debuff.vendetta.up&(!dot.concentrated_flame_burn.ticking&!action.concentrated_flame.in_flight|full_recharge_time<gcd.max)
-- # Always use Blood with Vendetta up. Hold for Exsanguinate. Use with TB up before a finisher as long as it runs for 10s during Vendetta.
-- actions.essences+=/blood_of_the_enemy,if=debuff.vendetta.up&(exsanguinated.garrote|debuff.toxic_blade.up&combo_points.deficit<=1|debuff.vendetta.remains<=10)|fight_remains<=10
-- # Attempt to align Guardian with Vendetta as long as it won't result in losing a full-value cast over the remaining duration of the fight
-- actions.essences+=/guardian_of_azeroth,if=cooldown.vendetta.remains<3|debuff.vendetta.up|fight_remains<30
-- actions.essences+=/guardian_of_azeroth,if=floor((fight_remains-30)%cooldown)>floor((fight_remains-30-cooldown.vendetta.remains)%cooldown)
-- actions.essences+=/focused_azerite_beam,if=spell_targets.fan_of_knives>=2|raid_event.adds.in>60&energy<70|fight_remains<10
-- actions.essences+=/purifying_blast,if=spell_targets.fan_of_knives>=2|raid_event.adds.in>60|fight_remains<10
-- actions.essences+=/the_unbound_force,if=buff.reckless_force.up|buff.reckless_force_counter.stack<10
-- actions.essences+=/ripple_in_space
-- actions.essences+=/worldvein_resonance
-- actions.essences+=/memory_of_lucid_dreams,if=energy<50&!cooldown.vendetta.up
-- # Hold Reaping Flames for execute range or kill buffs, if possible. Always try to get the lowest cooldown based on available enemies.
-- actions.essences+=/cycling_variable,name=reaping_delay,op=min,if=essence.breath_of_the_dying.major,value=target.time_to_die
-- actions.essences+=/reaping_flames,target_if=target.time_to_die<1.5|((target.health.pct>80|target.health.pct<=20)&(active_enemies=1|variable.reaping_delay>29))|(target.time_to_pct_20>30&(active_enemies=1|variable.reaping_delay>44))

-- # Stealthed Actions
-- # Nighstalker on 1T: Snapshot Rupture
-- actions.stealthed=rupture,if=talent.nightstalker.enabled&combo_points>=4&target.time_to_die-remains>6
-- # Subterfuge + Shrouded Suffocation: Ensure we use one global to apply Garrote to the main target if it is not snapshot yet, so all other main target abilities profit.
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,if=azerite.shrouded_suffocation.enabled&buff.subterfuge.up&buff.subterfuge.remains<1.3&!ss_buffed
-- # Subterfuge: Apply or Refresh with buffed Garrotes
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,target_if=min:remains,if=talent.subterfuge.enabled&(remains<12|pmultiplier<=1)&target.time_to_die-remains>2
-- # Subterfuge + Shrouded Suffocation in ST: Apply early Rupture that will be refreshed for pandemic
-- actions.stealthed+=/rupture,if=talent.subterfuge.enabled&azerite.shrouded_suffocation.enabled&!dot.rupture.ticking&variable.single_target
-- # Subterfuge w/ Shrouded Suffocation: Reapply for bonus CP and/or extended snapshot duration.
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,target_if=min:remains,if=talent.subterfuge.enabled&azerite.shrouded_suffocation.enabled&(active_enemies>1|!talent.exsanguinate.enabled)&target.time_to_die>remains&(remains<18|!ss_buffed)
-- # Subterfuge + Exsg on 1T: Refresh Garrote at the end of stealth to get max duration before Exsanguinate
-- actions.stealthed+=/pool_resource,for_next=1
-- actions.stealthed+=/garrote,if=talent.subterfuge.enabled&talent.exsanguinate.enabled&active_enemies=1&buff.subterfuge.remains<1.3

