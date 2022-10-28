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
local BoolToInt = HL.Utils.BoolToInt
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua
local pairs = pairs
local tableinsert = table.insert
local mathmin = math.min
local mathmax = math.max
local mathabs = math.abs

--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue
-- Define S/I for spell and item arrays
local S = Spell.Rogue.Subtlety
local I = Item.Rogue.Subtlety

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.CacheOfAcquiredTreasures:ID()
}

-- Rotation Var
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y
local ShouldReturn; -- Used to get the return string
local PoolingAbility, PoolingEnergy, PoolingFinisher; -- Used to store an ability we might want to pool for as a fallback in the current situation
local Stealth, VanishBuff
local RuptureThreshold, RuptureDMGThreshold
local EffectiveComboPoints, ComboPoints, ComboPointsDeficit, StealthEnergyRequired
local PriorityRotation

-- Covenant and Legendaries
local CovenantId = Player:CovenantID()
local IsKyrian, IsVenthyr, IsNightFae, IsNecrolord = (CovenantId == 1), (CovenantId == 2), (CovenantId == 3), (CovenantId == 4)
local DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
local TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
local AkaarisSoulFragmentEquipped = Player:HasLegendaryEquipped(127)
local MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
local FinalityEquipped = Player:HasLegendaryEquipped(126)
local ObedienceEquipped = Player:HasLegendaryEquipped(229) or (Player:HasUnity() and IsVenthyr)
local ResoundingClarityEquipped = Player:HasLegendaryEquipped(231) or (Player:HasUnity() and IsKyrian)
local TheRottenEquipped = Player:HasLegendaryEquipped(128)
local Tier282pcEquipped = Player:HasTier(28, 2)
HL:RegisterForEvent(function()
  CovenantId = Player:CovenantID()
  IsKyrian, IsVenthyr, IsNightFae, IsNecrolord = (CovenantId == 1), (CovenantId == 2), (CovenantId == 3), (CovenantId == 4)
  DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
  TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
  AkaarisSoulFragmentEquipped = Player:HasLegendaryEquipped(127)
  MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
  FinalityEquipped = Player:HasLegendaryEquipped(126)
  ObedienceEquipped = Player:HasLegendaryEquipped(229) or (Player:HasUnity() and IsVenthyr)
  ResoundingClarityEquipped = Player:HasLegendaryEquipped(231) or (Player:HasUnity() and IsKyrian)
  TheRottenEquipped = Player:HasLegendaryEquipped(128)
  Tier282pcEquipped = Player:HasTier(28, 2)
end, "PLAYER_EQUIPMENT_CHANGED", "COVENANT_CHOSEN" )

S.Eviscerate:RegisterDamageFormula(
  -- Eviscerate DMG Formula (Pre-Mitigation):
  --- Player Modifier
    -- AP * CP * EviscR1_APCoef * Aura_M * NS_M * DS_M * DSh_M * SoD_M * Finality_M * Mastery_M * Versa_M
  --- Target Modifier
    -- EviscR2_M * Sinful_M
  function ()
    return
      --- Player Modifier
        -- Attack Power
        Player:AttackPowerDamageMod() *
        -- Combo Points
        EffectiveComboPoints *
        -- Eviscerate R1 AP Coef
        0.176 *
        -- Aura Multiplier (SpellID: 137035)
        1.21 *
        -- Nightstalker Multiplier
        (S.Nightstalker:IsAvailable() and Player:StealthUp(true, false) and 1.12 or 1) *
        -- Deeper Stratagem Multiplier
        (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
        -- Shadow Dance Multiplier
        (S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.3 or 1) *
        (not S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.15 or 1) *
        -- Symbols of Death Multiplier
        (Player:BuffUp(S.SymbolsofDeath) and 1.15 or 1) *
        -- Finality Multiplier
        (Player:BuffUp(S.FinalityEviscerate) and 1.25 or 1) *
        -- Mastery Finisher Multiplier
        (1 + Player:MasteryPct() / 100) *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
        -- Eviscerate R2 Multiplier
        (Target:DebuffUp(S.FindWeaknessDebuff) and 1.5 or 1) *
        -- Sinful Revelation Enchant
        (Target:DebuffUp(S.SinfulRevelationDebuff) and 1.06 or 1)
  end
)
S.Rupture:RegisterPMultiplier(
  function ()
    return S.Nightstalker:IsAvailable() and Player:StealthUp(true, false) and 1.12 or 1
  end
)

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Commons2 = HR.GUISettings.APL.Rogue.Commons2,
  Subtlety = HR.GUISettings.APL.Rogue.Subtlety
}

local function SetPoolingAbility(PoolingSpell, EnergyThreshold)
  if not PoolingAbility then
    PoolingAbility = PoolingSpell
    PoolingEnergy = EnergyThreshold or 0
  end
end

local function SetPoolingFinisher(PoolingSpell)
  if not PoolingFinisher then
    PoolingFinisher = PoolingSpell
  end
end

local function MayBurnShadowDance()
  if Settings.Subtlety.BurnShadowDance == "On Bosses not in Dungeons" and Player:IsInDungeonArea() then
    return false
  elseif Settings.Subtlety.BurnShadowDance ~= "Always" and not Target:IsInBossList() then
    return false
  else
    return true
  end
end

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
    -- Council of Blood
    elseif Target:NPCID() == 166969 or Target:NPCID() == 166971 or Target:NPCID() == 166970 then
      return true
    -- Anduin (Remnant of a Fallen King/Monstrous Soul)
    elseif Target:NPCID() == 183463 or Target:NPCID() == 183671 then
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
    HR.CastLeftNameplate(BestUnit, DoTSpell)
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
      HR.CastLeftNameplate(BestUnit, DoTSpell)
    end
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

-- APL Action Lists (and Variables)
local function Stealth_Threshold ()
  -- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*20+talent.master_of_shadows.enabled*20+talent.shadow_focus.enabled*25+talent.alacrity.enabled*20+25*(spell_targets.shuriken_storm>=4)
  return 25 + num(S.Vigor:IsAvailable()) * 20 + num(S.MasterofShadows:IsAvailable()) * 20 + num(S.ShadowFocus:IsAvailable()) * 25 + num(S.Alacrity:IsAvailable()) * 20 + num(MeleeEnemies10yCount >= 4) * 25
end
local function ShD_Threshold ()
  -- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=(1.75-0.75*(covenant.kyrian&set_bonus.tier28_2pc&cooldown.symbols_of_death.remains>=8))
  -- actions.stealth_cds+=/variable,name=shd_threshold,if=runeforge.the_rotten,value=cooldown.shadow_dance.charges_fractional>=1.75|cooldown.symbols_of_death.remains>=16
  if TheRottenEquipped then
    return S.ShadowDance:ChargesFractional() >= 1.75 or S.SymbolsofDeath:CooldownRemains() >= 16
  end
  return S.ShadowDance:ChargesFractional() >= (1.75 - (0.75 * BoolToInt(IsKyrian and Tier282pcEquipped and S.SymbolsofDeath:CooldownRemains() >= 8)))
end
local function ShD_Combo_Points ()
  -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=2+buff.shadow_blades.up
  -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=3,if=covenant.kyrian
  -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=variable.use_priority_rotation&spell_targets.shuriken_storm>=4
  -- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=spell_targets.shuriken_storm=4
  if MeleeEnemies10yCount == 4 then
    return ComboPointsDeficit <= 1
  elseif PriorityRotation and MeleeEnemies10yCount >= 4 then
    return ComboPointsDeficit <= 1
  elseif IsKyrian then
    return ComboPointsDeficit >= 3
  else
    return ComboPointsDeficit >= (2 + num(Player:BuffUp(S.ShadowBlades)))
  end
end
local function SnD_Condition ()
  -- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up|spell_targets.shuriken_storm>=6
  return Player:BuffUp(S.SliceandDice) or MeleeEnemies10yCount >= 6
end
local function Skip_Rupture (ShadowDanceBuff)
  -- actions.finish+=/variable,name=skip_rupture,value=master_assassin_remains>0|!talent.nightstalker.enabled&talent.dark_shadow.enabled&buff.shadow_dance.up|spell_targets.shuriken_storm>=(4-stealthed.all*talent.shadow_focus.enabled)
  return Rogue.MasterAssassinsMarkRemains() > 0
    or (not S.Nightstalker:IsAvailable() and S.DarkShadow:IsAvailable() and ShadowDanceBuff)
    or MeleeEnemies10yCount >= (4 - BoolToInt(Player:StealthUp(true, true) or ShadowDanceBuff) * BoolToInt(S.ShadowFocus:IsAvailable()))
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, StealthSpell)
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())

  if S.SliceandDice:IsCastable() and HL.FilteredFightRemains(MeleeEnemies10y, ">", Player:BuffRemains(S.SliceandDice)) then
    -- actions.finish=variable,name=premed_snd_condition,value=talent.premeditation.enabled&spell_targets.shuriken_storm<(5-covenant.necrolord)&!covenant.kyrian
    if S.Premeditation:IsAvailable() and MeleeEnemies10yCount < 5 - num(IsNecrolord) and not IsKyrian then
      -- actions.finish+=/slice_and_dice,if=variable.premed_snd_condition&cooldown.shadow_dance.charges_fractional<1.75&buff.slice_and_dice.remains<cooldown.symbols_of_death.remains&(cooldown.shadow_dance.ready&buff.symbols_of_death.remains-buff.shadow_dance.remains<1.2)
      if S.ShadowDance:ChargesFractional() < 1.75 and Player:BuffRemains(S.SliceandDice) < S.SymbolsofDeath:CooldownRemains()
        and (S.ShadowDance:Charges() >= 1 and Player:BuffRemains(S.SymbolsofDeath) - Player:BuffRemains(S.ShadowDanceBuff) < 1.2) then
        if ReturnSpellOnly then
          return S.SliceandDice
        else
          if S.SliceandDice:IsReady() and HR.Cast(S.SliceandDice) then return "Cast Slice and Dice (Premed)" end
          SetPoolingFinisher(S.SliceandDice)
        end
      end
    else
      -- actions.finish+=/slice_and_dice,if=!variable.premed_snd_condition&spell_targets.shuriken_storm<6&!buff.shadow_dance.up&buff.slice_and_dice.remains<fight_remains&refreshable
      if MeleeEnemies10yCount < 6 and not ShadowDanceBuff
        and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints * 1.8) then
        if ReturnSpellOnly then
          return S.SliceandDice
        else
          if S.SliceandDice:IsReady() and HR.Cast(S.SliceandDice) then return "Cast Slice and Dice" end
          SetPoolingFinisher(S.SliceandDice)
        end
      end
    end
  end

  local SkipRupture = Skip_Rupture(ShadowDanceBuff)
  if (not SkipRupture or PriorityRotation) and S.Rupture:IsCastable() and not (Player:StealthUp(true, true) or ShadowDanceBuff) then   
    -- actions.finish+=/rupture,if=!stealthed.all&(!variable.skip_rupture|variable.use_priority_rotation)&target.time_to_die-remains>6&refreshable
    if Target:IsInMeleeRange(5)
      and (Target:FilteredTimeToDie(">", 6, -Target:DebuffRemains(S.Rupture)) or Target:TimeToDieIsNotValid())
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)
      and Target:DebuffRefreshable(S.Rupture, RuptureThreshold) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if S.Rupture:IsReady() and HR.Cast(S.Rupture) then return "Cast Rupture 1" end
        SetPoolingFinisher(S.Rupture)
      end
    end
  end
  -- actions.finish+=/secret_technique
  if S.SecretTechnique:IsReady() then
    if ReturnSpellOnly then
      return S.SecretTechnique
    else
      if HR.Cast(S.SecretTechnique) then return "Cast Secret Technique" end
    end
  end
  if not SkipRupture and S.Rupture:IsCastable() then
    -- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&target.time_to_die>=(5+(2*combo_points))&refreshable
    if not ReturnSpellOnly and HR.AoEON() and not PriorityRotation and MeleeEnemies10yCount >= 2 then
      local function Evaluate_Rupture_Target(TargetUnit)
        return Everyone.CanDoTUnit(TargetUnit, RuptureDMGThreshold)
          and TargetUnit:DebuffRefreshable(S.Rupture, RuptureThreshold)
      end
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, (5 + 2 * ComboPoints), MeleeEnemies5y)
    end
    -- actions.finish+=/rupture,if=!variable.skip_rupture&remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
    if Target:IsInMeleeRange(5) and Target:DebuffRemains(S.Rupture) < S.SymbolsofDeath:CooldownRemains() + 10
      and S.SymbolsofDeath:CooldownRemains() <= 5
      and Rogue.CanDoTUnit(Target, RuptureDMGThreshold)
      and Target:FilteredTimeToDie(">", 5 + S.SymbolsofDeath:CooldownRemains(), -Target:DebuffRemains(S.Rupture)) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if S.Rupture:IsReady() and HR.Cast(S.Rupture) then return "Cast Rupture 2" end
        SetPoolingFinisher(S.Rupture)
      end
    end
  end
  -- actions.finish+=/black_powder,if=!variable.use_priority_rotation&spell_targets>=3
  if S.BlackPowder:IsCastable() and not PriorityRotation and MeleeEnemies10yCount >= 3 then
    if ReturnSpellOnly then
      return S.BlackPowder
    else
      if S.BlackPowder:IsReady() and HR.Cast(S.BlackPowder) then return "Cast Black Powder" end
      SetPoolingFinisher(S.BlackPowder)
    end
  end
  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() and Target:IsInMeleeRange(5) then
    if ReturnSpellOnly then
      return S.Eviscerate
    else
      if S.Eviscerate:IsReady() and HR.Cast(S.Eviscerate) then return "Cast Eviscerate" end
      SetPoolingFinisher(S.Eviscerate)
    end
  end

  return false
end

-- # Stealthed Rotation
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Stealthed (ReturnSpellOnly, StealthSpell)
  local StealthBuff = Player:BuffUp(Stealth) or (StealthSpell and StealthSpell:ID() == Stealth:ID())
  local VanishBuffCheck = Player:BuffUp(VanishBuff) or (StealthSpell and StealthSpell:ID() == S.Vanish:ID())
  local ShadowDanceBuff = Player:BuffUp(S.ShadowDanceBuff) or (StealthSpell and StealthSpell:ID() == S.ShadowDance:ID())
  local ShadowDanceBuffRemains = Player:BuffRemains(S.ShadowDanceBuff)
  if StealthSpell and StealthSpell:ID() == S.ShadowDance:ID() then
    ShadowDanceBuffRemains = 8
  end
  local ShadowstrikeIsCastable = S.Shadowstrike:IsCastable() or StealthBuff or VanishBuffCheck or ShadowDanceBuff
  if StealthBuff or VanishBuffCheck then
    ShadowstrikeIsCastable = ShadowstrikeIsCastable and Target:IsInRange(25)
  else
    ShadowstrikeIsCastable = ShadowstrikeIsCastable and Target:IsInMeleeRange(5)
  end

  -- actions.stealthed=shadowstrike,if=(buff.stealth.up|buff.vanish.up)&(spell_targets.shuriken_storm<4|variable.use_priority_rotation)&master_assassin_remains=0
  if ShadowstrikeIsCastable and (StealthBuff or VanishBuffCheck) and (MeleeEnemies10yCount < 4 or PriorityRotation) and Rogue.MasterAssassinsMarkRemains() == 0 then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (Stealth)" end
    end
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=effective_combo_points>=cp_max_spend
  if EffectiveComboPoints >= Rogue.CPMaxSpend() then
    return Finish(ReturnSpellOnly, StealthSpell)
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
  if Player:BuffUp(S.ShurikenTornado) and ComboPointsDeficit <= 2 then
    return Finish(ReturnSpellOnly, StealthSpell)
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm>=4&effective_combo_points>=4
  if MeleeEnemies10yCount >= 4 and EffectiveComboPoints >= 4 then
    return Finish(ReturnSpellOnly, StealthSpell)
  end
  -- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
  if ComboPointsDeficit <= 1 - num(S.DeeperStratagem:IsAvailable() and VanishBuffCheck) then
    return Finish(ReturnSpellOnly, StealthSpell)
  end
  -- actions.stealthed+=/shadowstrike,if=stealthed.sepsis&spell_targets.shuriken_storm<4
  if ShadowstrikeIsCastable and not Player:StealthUp(true, false) and Player:BuffUp(S.SepsisBuff) and MeleeEnemies10yCount < 4 then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (Sepsis)" end
    end
  end
  -- As we're in stealth, show a special macro combo with the PV icon to make it clear we are casting Backstab specifically within Shadow Dance
  -- actions.stealthed+=/backstab,if=conduit.perforated_veins.rank>=8&buff.perforated_veins.stack>=5&buff.shadow_dance.remains>=3&buff.shadow_blades.up&(spell_targets.shuriken_storm<=3|variable.use_priority_rotation)&(buff.shadow_blades.remains<=buff.shadow_dance.remains+2|!covenant.venthyr)
  if S.PerforatedVeins:ConduitRank() >= 8 and Player:BuffStack(S.PerforatedVeinsBuff) >= 5 and ShadowDanceBuffRemains >= 3 and Player:BuffUp(S.ShadowBlades)
    and (MeleeEnemies10yCount <= 3 or PriorityRotation) and (not IsVenthyr or Player:BuffRemains(S.ShadowBlades) <= ShadowDanceBuffRemains + 2) then
    if ReturnSpellOnly then
      -- If calling from a Stealth macro, we don't need the PV suggestion since it's already a macro cast
      if StealthSpell then
        return S.Backstab
      else
        return { S.Backstab, S.PerforatedVeins }
      end
    else
      if HR.CastQueue(S.Backstab, S.PerforatedVeins) then return "Cast Backstab (Stealth PV)" end
    end
  end
  -- actions.stealthed+=/shiv,if=talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped&spell_targets.shuriken_storm<5
  if S.Shiv:IsReady() and TinyToxicBladeEquipped and S.Nightstalker:IsAvailable() and MeleeEnemies10yCount < 5 then
    if ReturnSpellOnly then
      return S.Shiv
    else
      if HR.Cast(S.Shiv) then return "Cast Shiv (TTB NS)" end
    end
  end
  -- actions.stealthed+=/shadowstrike,cycle_targets=1,if=!variable.use_priority_rotation&debuff.find_weakness.remains<1&spell_targets.shuriken_storm<=3&target.time_to_die-remains>6
  -- !!!NYI!!! (Is this worth it? How do we want to display it in an understandable way?)
  -- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=4)
  if ShadowstrikeIsCastable and PriorityRotation
    and (Target:DebuffRemains(S.FindWeaknessDebuff) < 1 or S.Weaponmaster:IsAvailable() and MeleeEnemies10yCount <= 4) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (Prio Rotation)" end
    end
  end
  -- actions.stealthed+=/shuriken_storm,if=spell_targets>=3+(buff.the_rotten.up|runeforge.akaaris_soul_fragment|set_bonus.tier28_2pc&talent.shadow_focus.enabled)&(buff.symbols_of_death_autocrit.up|!buff.premeditation.up|spell_targets>=5)
  if HR.AoEON() and S.ShurikenStorm:IsCastable()
    and MeleeEnemies10yCount >= 3 + num(Player:BuffUp(S.TheRottenBuff) or AkaarisSoulFragmentEquipped or Tier282pcEquipped and S.ShadowFocus:IsAvailable())
    and (Player:BuffUp(S.SymbolsofDeathCrit) or not Player:BuffUp(S.PremeditationBuff) or MeleeEnemies10yCount >= 5) then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm" end
    end
  end
  -- actions.stealthed+=/shadowstrike,if=debuff.find_weakness.remains<=1|cooldown.symbols_of_death.remains<18&debuff.find_weakness.remains<cooldown.symbols_of_death.remains
  if ShadowstrikeIsCastable and (Target:DebuffRemains(S.FindWeaknessDebuff) < 1 or S.SymbolsofDeath:CooldownRemains() < 18
    and Target:DebuffRemains(S.FindWeaknessDebuff) < S.SymbolsofDeath:CooldownRemains()) then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike (FW Refresh)" end
    end
  end
  -- TODO: actions.stealthed+=/gloomblade,if=buff.perforated_veins.stack>=5&conduit.perforated_veins.rank>=13
  -- actions.stealthed+=/shadowstrike
  if ShadowstrikeIsCastable then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if HR.Cast(S.Shadowstrike) then return "Cast Shadowstrike 2" end
    end
  end
  -- actions.stealthed+=/cheap_shot,if=!target.is_boss&combo_points.deficit>=1&buff.shot_in_the_dark.up&energy.time_to_40>gcd.max
  -- NYI. Needed? Special handling?
  return false
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell, EnergyThreshold)
  -- Fetch the predicted ability to use after the stealth spell
  local MacroAbility = Stealthed(true, StealthSpell)

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell == S.Vanish and (not Settings.Subtlety.StealthMacro.Vanish or not MacroAbility) then
    if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
    return false
  elseif StealthSpell == S.Shadowmeld and (not Settings.Subtlety.StealthMacro.Shadowmeld or not MacroAbility) then
    if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
    return false
  elseif StealthSpell == S.ShadowDance and (not Settings.Subtlety.StealthMacro.ShadowDance or not MacroAbility) then
    if HR.Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
    return false
  end

  local MacroTable = {StealthSpell, MacroAbility}

  -- Set the stealth spell only as a pooling fallback if we did not meet the threshold
  if EnergyThreshold and Player:EnergyPredicted() < EnergyThreshold then
    SetPoolingAbility(MacroTable, EnergyThreshold)
    return false
  end

   -- Note: In case DfA is adviced (which can only be a combo for ShD), we swap them to let understand it's DfA then ShD during DfA (DfA - ShD bug)
  if MacroTable[1] == S.ShadowDance and MacroTable[2] == S.DeathfromAbove then
    ShouldReturn = HR.CastQueue(MacroTable[2], MacroTable[1])
    if ShouldReturn then return "| " .. MacroTable[1]:Name() end
  else
    ShouldReturn = HR.CastQueue(unpack(MacroTable))
    if ShouldReturn then return "| " .. MacroTable[2]:Name() end
  end

  return false
end

-- # Cooldowns
local function CDs ()
  if Player:BuffUp(S.ShurikenTornado) then
    -- actions.cds+=/shadow_dance,off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
    if S.SymbolsofDeath:IsCastable() and S.ShadowDance:IsCastable() and not Player:BuffUp(S.SymbolsofDeath) and not Player:BuffUp(S.ShadowDance) then
      if HR.CastQueue(S.SymbolsofDeath, S.ShadowDance) then return "Dance + Symbols (during Tornado)" end
    elseif S.SymbolsofDeath:IsCastable() and not Player:BuffUp(S.SymbolsofDeath) then
      if HR.Cast(S.SymbolsofDeath) then return "Cast Symbols of Death (during Tornado)" end
    elseif S.ShadowDance:IsCastable() and not Player:BuffUp(S.ShadowDanceBuff) then
      if HR.Cast(S.ShadowDance) then return "Cast Shadow Dance (during Tornado)" end
    end
  end

  local SnDCondition = SnD_Condition()

  if Target:IsInMeleeRange(5) then
    -- actions.cds+=/flagellation,if=variable.snd_condition&!stealthed.mantle&(spell_targets.shuriken_storm<=1&cooldown.symbols_of_death.up&!talent.shadow_focus.enabled|buff.symbols_of_death.up)&combo_points>=5
    if HR.CDsON() and S.Flagellation:IsReady() and SnDCondition and not Player:StealthUp(false, false) and ComboPoints >= 5 and 
      (MeleeEnemies10yCount <= 1 and S.SymbolsofDeath:CooldownUp() and not S.ShadowFocus:IsAvailable() or Player:BuffUp(S.SymbolsofDeath)) then
      if HR.Cast(S.Flagellation, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flrgrrlation" end
    end
  end
  -- actions.cds+=/vanish,if=(runeforge.mark_of_the_master_assassin&combo_points.deficit<=1-talent.deeper_strategem.enabled|runeforge.deathly_shadows&combo_points<1)&buff.symbols_of_death.up&buff.shadow_dance.up&master_assassin_remains=0&buff.deathly_shadows.down
  if HR.CDsON() and S.Vanish:IsCastable()
    and (MarkoftheMasterAssassinEquipped and ComboPointsDeficit <= 1 - num(S.DeeperStratagem:IsAvailable()) or DeathlyShadowsEquipped)
    and Player:BuffUp(S.SymbolsofDeath) and Player:BuffUp(S.ShadowDanceBuff) and Rogue.MasterAssassinsMarkRemains() == 0
    and not Player:BuffUp(S.DeathlyShadowsBuff) then
    if StealthMacro(S.Vanish) then return "Vanish Macro" end
  end
  -- actions.cds+=/shuriken_tornado,if=spell_targets.shuriken_storm<=1&energy>=60&variable.snd_condition&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1&(!runeforge.obedience|debuff.flagellation.up|spell_targets.shuriken_storm>=(1+4*(!talent.nightstalker.enabled&!talent.dark_shadow.enabled)))&combo_points<=2&!buff.premeditation.up&(!covenant.venthyr|!cooldown.flagellation.up)
  if S.ShurikenTornado:IsCastable() and MeleeEnemies10yCount <= 1 and SnDCondition and S.SymbolsofDeath:CooldownUp() and S.ShadowDance:Charges() >= 1
    and (not ObedienceEquipped or Target:DebuffUp(S.Flagellation) or MeleeEnemies10yCount >= 1 + 4*num(not S.Nightstalker:IsAvailable() and not S.DarkShadow:IsAvailable()))
    and ComboPoints <= 2 and not Player:BuffUp(S.PremeditationBuff) and (not IsVenthyr or not S.Flagellation:CooldownUp()) then
    -- actions.cds+=/pool_resource,for_next=1,if=talent.shuriken_tornado.enabled&!talent.shadow_focus.enabled
    if Player:Energy() >= 60 then
      if HR.Cast(S.ShurikenTornado, Settings.Subtlety.GCDasOffGCD.ShurikenTornado) then return "Cast Shuriken Tornado" end
    elseif not S.ShadowFocus:IsAvailable() then
      if HR.CastPooling(S.ShurikenTornado) then return "Pool for Shuriken Tornado" end
    end
  end
  -- actions.cds+=/serrated_bone_spike,cycle_targets=1,if=variable.snd_condition&!dot.serrated_bone_spike_dot.ticking&target.time_to_die>=21&(combo_points.deficit>=(cp_gain>?4))&!buff.shuriken_tornado.up&(!buff.premeditation.up|spell_targets.shuriken_storm>4)|fight_remains<=5&spell_targets.shuriken_storm<3
  if S.SerratedBoneSpike:IsReady() then
    if Target:IsInRange(30) and HL.BossFilteredFightRemains("<=", 5) and MeleeEnemies10yCount < 3 then
      if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike (End of Fight)" end
    end
    -- TODO: Implement cp_gain logic
    if SnDCondition and not Player:BuffUp(S.ShurikenTornado) and ComboPointsDeficit >= 2
      and (not Player:BuffUp(S.PremeditationBuff) or MeleeEnemies10yCount > 4) then
      local function Evaluate_BoneSpike_Target(TargetUnit)
        return not TargetUnit:DebuffUp(S.SerratedBoneSpikeDebuff)
      end
      if Target:IsInRange(30) and Evaluate_BoneSpike_Target(Target) and Target:FilteredTimeToDie(">", 21) then
        if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike (ST)" end
      end
      if HR.AoEON() then
        SuggestCycleDoT(S.SerratedBoneSpike, Evaluate_BoneSpike_Target, 21, Enemies30y)
      end
    end
  end
  if Target:IsInMeleeRange(5) then
    -- actions.cds+=/sepsis,if=variable.snd_condition&combo_points.deficit>=1&target.time_to_die>=16
    if HR.CDsON() and S.Sepsis:IsReady() and SnDCondition and ComboPointsDeficit >= 1 and not Target:FilteredTimeToDie("<", 16) then
      if HR.Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis" end
    end
    -- actions.cds+=/symbols_of_death,if=variable.snd_condition&(!stealthed.all|buff.perforated_veins.stack<4|spell_targets.shuriken_storm>4&!variable.use_priority_rotation)&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|spell_targets.shuriken_storm>=2|cooldown.shuriken_tornado.remains>2)&(!covenant.venthyr|cooldown.flagellation.remains>10|cooldown.flagellation.up&combo_points>=5)
    if S.SymbolsofDeath:IsCastable() and SnDCondition
      and (not Player:StealthUp(true, true) or Player:BuffStack(S.PerforatedVeinsBuff) < 4 or MeleeEnemies10yCount > 4 and not PriorityRotation)
      and (not S.ShurikenTornado:IsAvailable() or S.ShadowFocus:IsAvailable() or MeleeEnemies10yCount >= 2 or S.ShurikenTornado:CooldownRemains() > 2)
      and (not IsVenthyr or S.Flagellation:CooldownRemains() > 10 or S.Flagellation:CooldownUp() and ComboPoints >= 5) then
      if HR.Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then return "Cast Symbols of Death" end
    end
  end
  if S.MarkedforDeath:IsCastable() then
    -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit
    if Target:FilteredTimeToDie("<", ComboPointsDeficit) then
      if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
    end
    -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30&!stealthed.all&combo_points.deficit>=cp_max_spend
    if not Player:StealthUp(true, true) and ComboPointsDeficit >= Rogue.CPMaxSpend() then
      if not Settings.Commons.STMfDAsDPSCD then
        HR.CastSuggested(S.MarkedforDeath)
      elseif HR.CDsON() then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death" end
      end
    end
  end
  if HR.CDsON() then
    -- actions.cds+=/shadow_blades,if=variable.snd_condition&combo_points.deficit>=2&(buff.symbols_of_death.up|fight_remains<=20|!buff.shadow_blades.up&set_bonus.tier28_2pc)
    if S.ShadowBlades:IsCastable() and SnDCondition and ComboPointsDeficit >= 2
      and (Player:BuffUp(S.SymbolsofDeath) or HL.BossFilteredFightRemains("<=", 20) or (not Player:BuffUp(S.ShadowBlades) and Tier282pcEquipped)) then
      if HR.Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then return "Cast Shadow Blades" end
    end
    -- actions.cds+=/echoing_reprimand,if=(!talent.shadow_focus.enabled|!stealthed.all|spell_targets.shuriken_storm>=4)&variable.snd_condition&combo_points.deficit>=2&(variable.use_priority_rotation|spell_targets.shuriken_storm<=4|runeforge.resounding_clarity)
    if S.EchoingReprimand:IsReady() and Target:IsInMeleeRange(5)
      and (not Player:StealthUp(true, true) or not S.ShadowFocus:IsAvailable() or MeleeEnemies10yCount >= 4)
      and SnDCondition and ComboPointsDeficit >= 2 and (PriorityRotation or MeleeEnemies10yCount <= 4 or ResoundingClarityEquipped) then
      if HR.Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand" end
    end
    -- actions.cds+=/shuriken_tornado,if=(talent.shadow_focus.enabled|spell_targets.shuriken_storm>=2)&variable.snd_condition&buff.symbols_of_death.up&combo_points<=2&(!buff.premeditation.up|spell_targets.shuriken_storm>4)
    if S.ShurikenTornado:IsReady() and (S.ShadowFocus:IsAvailable() or MeleeEnemies10yCount >= 2) and SnDCondition and Player:BuffUp(S.SymbolsofDeath)
      and ComboPoints <= 2 and (not Player:BuffUp(S.PremeditationBuff) or MeleeEnemies10yCount > 4) then
      if HR.Cast(S.ShurikenTornado, Settings.Subtlety.GCDasOffGCD.ShurikenTornado) then return "Cast Shuriken Tornado (SF)" end
    end
    -- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled
    if S.ShadowDance:IsCastable() and MayBurnShadowDance() and not Player:BuffUp(S.ShadowDanceBuff) and HL.BossFilteredFightRemains("<=", 8 + num(S.Subterfuge:IsAvailable())) then
      ShouldReturn = StealthMacro(S.ShadowDance)
      if ShouldReturn then return "Shadow Dance Macro (Low TTD) " .. ShouldReturn end
    end
    -- actions.cds+=/fleshcraft,if=(soulbind.pustule_eruption|soulbind.volatile_solvent)&energy.deficit>=30&!stealthed.all&buff.symbols_of_death.down
    if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled())
      and Player:EnergyDeficitPredicted() > 30 and not Player:StealthUp(true, true) and not Player:BuffUp(S.SymbolsofDeath) then
      HR.CastSuggested(S.Fleshcraft)
    end

    -- TODO: Add Potion Suggestion
    -- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.symbols_of_death.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)

    -- Racials
    if Player:BuffUp(S.SymbolsofDeath) then
      -- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
      end
      -- actions.cds+=/berserking,if=buff.symbols_of_death.up
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
      end
      -- actions.cds+=/fireblood,if=buff.symbols_of_death.up
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
      end
      -- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
      end
    end

    -- Trinkets
    if Settings.Commons.UseTrinkets then
      -- use_item,name=cache_of_acquired_treasures,if=(covenant.venthyr&buff.acquired_axe.up|!covenant.venthyr&buff.acquired_wand.up)&(spell_targets.shuriken_storm=1&raid_event.adds.in>60|fight_remains<25|variable.use_priority_rotation)|buff.acquired_axe.up&spell_targets.shuriken_storm>1
      if I.CacheOfAcquiredTreasures:IsEquippedAndReady() then
        if Player:BuffUp(S.AcquiredAxe) and MeleeEnemies10yCount > 1 then
          if HR.Cast(I.CacheOfAcquiredTreasures, nil, Settings.Commons.TrinketDisplayStyle) then return "Cache for AoE" end
        elseif (IsVenthyr and Player:BuffUp(S.AcquiredAxe) or not IsVenthyr and Player:BuffUp(S.AcquiredWand))
          and (MeleeEnemies10yCount == 1 or PriorityRotation) and (Target:IsInBossList() or Target:IsDummy()) or HL.BossFilteredFightRemains("<", 25) then
          if HR.Cast(I.CacheOfAcquiredTreasures, nil, Settings.Commons.TrinketDisplayStyle) then return "Cache for ST" end
        end
      end
      local DefaultTrinketCondition = Player:BuffUp(S.SymbolsofDeath) or HL.BossFilteredFightRemains("<", 20)
      -- actions.cds+=/use_items,if=buff.symbols_of_death.up|fight_remains<20
      if DefaultTrinketCondition then
        local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
        if TrinketToUse then
          if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
        end
      end
    end
  end

  return false
end

-- # Stealth Cooldowns
local function Stealth_CDs (EnergyThreshold)
  if HR.CDsON() and S.ShadowDance:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3 and not Player:IsTanking(Target) then
    -- actions.stealth_cds+=/vanish,if=(!variable.shd_threshold|!talent.nightstalker.enabled&talent.dark_shadow.enabled)&combo_points.deficit>1&!runeforge.mark_of_the_master_assassin.equipped
    if S.Vanish:IsCastable() and (not ShD_Threshold() or not S.Nightstalker:IsAvailable() and S.DarkShadow:IsAvailable())
      and ComboPointsDeficit > 1 and not MarkoftheMasterAssassinEquipped then
      ShouldReturn = StealthMacro(S.Vanish, EnergyThreshold)
      if ShouldReturn then return "Vanish Macro " .. ShouldReturn end
    end
    -- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1
    if S.Shadowmeld:IsCastable() and Target:IsInMeleeRange(5) and not Player:IsMoving()
      and Player:EnergyDeficitPredicted() > 10 and not ShD_Threshold() and ComboPointsDeficit > 1 then
      -- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40
      if Player:Energy() < 40 then
        if HR.CastPooling(S.Shadowmeld, Player:EnergyTimeToX(40)) then return "Pool for Shadowmeld" end
      end
      ShouldReturn = StealthMacro(S.Shadowmeld, EnergyThreshold)
      if ShouldReturn then return "Shadowmeld Macro " .. ShouldReturn end
    end
  end
  if Target:IsInMeleeRange(5) and S.ShadowDance:IsCastable() and S.ShadowDance:Charges() >= 1
    and S.Vanish:TimeSinceLastDisplay() > 0.3 and S.Shadowmeld:TimeSinceLastDisplay() > 0.3
    and (HR.CDsON() or (S.ShadowDance:ChargesFractional() >= Settings.Subtlety.ShDEcoCharge - (not S.EnvelopingShadows:IsAvailable() and 0.75 or 0))) then
    -- actions.stealth_cds+=/shadow_dance,if=(runeforge.the_rotten&cooldown.symbols_of_death.remains<=8|variable.shd_combo_points&(buff.symbols_of_death.remains>=1.2|variable.shd_threshold)|buff.chaos_bane.up|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)&(buff.perforated_veins.stack<4|spell_targets.shuriken_storm>3)
    if (TheRottenEquipped and Player:BuffRemains(S.SymbolsofDeath) <= 8
      or ShD_Combo_Points() and (Player:BuffRemains(S.SymbolsofDeath) >= 1.2 or ShD_Threshold())
      or Player:BuffUp(S.ChaosBaneBuff) or (MeleeEnemies10yCount >= 4 and S.SymbolsofDeath:CooldownRemains() > 10))
      and (Player:BuffStack(S.PerforatedVeinsBuff) < 4 or MeleeEnemies10yCount > 3) then
      ShouldReturn = StealthMacro(S.ShadowDance, EnergyThreshold)
      if ShouldReturn then return "ShadowDance Macro 1 " .. ShouldReturn end
    end
    -- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&fight_remains<cooldown.symbols_of_death.remains|!talent.enveloping_shadows.enabled
    if MayBurnShadowDance() and (ShD_Combo_Points() and HL.BossFilteredFightRemains("<", S.SymbolsofDeath:CooldownRemains())
      or not S.EnvelopingShadows:IsAvailable()) then
      ShouldReturn = StealthMacro(S.ShadowDance, EnergyThreshold)
      if ShouldReturn then return "ShadowDance Macro 2 " .. ShouldReturn end
    end
  end
  return false
end

-- # Builders
local function Build (EnergyThreshold)
  local ThresholdMet = not EnergyThreshold or Player:EnergyPredicted() >= EnergyThreshold
  -- actions.build=shiv,if=!talent.nightstalker.enabled&runeforge.tiny_toxic_blade.equipped&spell_targets.shuriken_storm<5
  if S.Shiv:IsCastable() and TinyToxicBladeEquipped and not S.Nightstalker:IsAvailable() and MeleeEnemies10yCount < 5 then
    if ThresholdMet and HR.Cast(S.Shiv) then return "Cast Shiv (TTB)" end
    SetPoolingAbility(S.Shiv, EnergyThreshold)
  end
  -- actions.build+=/shuriken_storm,if=spell_targets>=2&(!covenant.necrolord|cooldown.serrated_bone_spike.max_charges-charges_fractional>=0.25|spell_targets.shuriken_storm>4)&(buff.perforated_veins.stack<=4|spell_targets.shuriken_storm>4&!variable.use_priority_rotation)
  if HR.AoEON() and S.ShurikenStorm:IsCastable() and MeleeEnemies10yCount >= 2
    and (not IsNecrolord or (S.SerratedBoneSpike:MaxCharges() - S.SerratedBoneSpike:ChargesFractional()) >= 0.25 or MeleeEnemies10yCount > 4)
    and (Player:BuffStack(S.PerforatedVeinsBuff) <= 4 or MeleeEnemies10yCount > 4 and not PriorityRotation) then
    if ThresholdMet and HR.Cast(S.ShurikenStorm) then return "Cast Shuriken Storm" end
    SetPoolingAbility(S.ShurikenStorm, EnergyThreshold)
  end
  -- actions.build+=/serrated_bone_spike,if=buff.perforated_veins.stack<=2&(cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25|soulbind.lead_by_example.enabled&!buff.lead_by_example.up|soulbind.kevins_oozeling.enabled&!debuff.kevins_wrath.up)
  if S.SerratedBoneSpike:IsCastable() and Player:BuffStack(S.PerforatedVeinsBuff) <= 2
    and ((S.SerratedBoneSpike:MaxCharges() - S.SerratedBoneSpike:ChargesFractional()) <= 0.25
    or ((S.LeadbyExample:SoulbindEnabled() and not Player:BuffUp(S.LeadbyExampleBuff))
      or (S.KevinsOozeling:SoulbindEnabled() and not Target:DebuffUp(S.KevinsWrathDebuff))) and not HL.BossFightRemainsIsNotValid()) then
    if ThresholdMet and HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike (Capping Filler)" end
    SetPoolingAbility(S.SerratedBoneSpike, EnergyThreshold)
  end
  if Target:IsInMeleeRange(5) then
    -- Pooling for generator conditions below
    -- if=!covenant.kyrian|!(variable.is_next_cp_animacharged&(time_to_sht.3.plus<0.5|time_to_sht.4.plus<1)&energy<60)
    if IsKyrian and Player:Energy() < 60
      and (ComboPoints == 2 and Player:BuffUp(S.EchoingReprimand3)
        or ComboPoints == 3 and Player:BuffUp(S.EchoingReprimand4)
        or ComboPoints == 4 and Player:BuffUp(S.EchoingReprimand5))
      and (Rogue.TimeToSht(3) < 0.5 or Rogue.TimeToSht(4) < 1.0 or Rogue.TimeToSht(5) < 1.0) then
      HR.Cast(S.PoolEnergy)
      return "ER Generator Pooling"
    end
    -- actions.build+=/gloomblade
    if S.Gloomblade:IsCastable() then
      if ThresholdMet and HR.Cast(S.Gloomblade) then return "Cast Gloomblade" end
      SetPoolingAbility(S.Gloomblade, EnergyThreshold)
    -- actions.build+=/backstab,if=!covenant.kyrian|!(variable.is_next_cp_animacharged&(time_to_sht.3.plus<0.5|time_to_sht.4.plus<1)&energy<60)
    elseif S.Backstab:IsCastable() then
      if ThresholdMet and HR.Cast(S.Backstab) then return "Cast Backstab" end
      SetPoolingAbility(S.Backstab, EnergyThreshold)
    end
  end
  return false
end

local Interrupts = {
  {S.Blind, "Cast Blind (Interrupt)", function () return true end},
  {S.KidneyShot, "Cast Kidney Shot (Interrupt)", function () return ComboPoints > 0 end},
  {S.CheapShot, "Cast Cheap Shot (Interrupt)", function () return Player:StealthUp(true, true) end}
}

-- APL Main
local function APL ()
  -- Spell ID Changes check
  if S.Subterfuge:IsAvailable() then
    Stealth = S.Stealth2
    VanishBuff = S.VanishBuff2
  else
    Stealth = S.Stealth
    VanishBuff = S.VanishBuff
  end

  -- Reset pooling cache
  PoolingAbility = nil
  PoolingFinisher = nil
  PoolingEnergy = 0

  -- Unit Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10) -- Shuriken Storm & Black Powder
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(5) -- Melee cycle
  else
    Enemies30y = {}
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 0
    MeleeEnemies5y = {}
  end
  
  -- Cache updates
  ComboPoints = Player:ComboPoints()
  EffectiveComboPoints = Rogue.EffectiveComboPoints(ComboPoints)
  ComboPointsDeficit = Player:ComboPointsDeficit()
  PriorityRotation = UsePriorityRotation()
  StealthEnergyRequired = Player:EnergyMax() - Stealth_Threshold()

  -- Adjust Animacharged CP Prediction for Shadow Techniques
  -- If we are on a non-optimal Animacharged CP, ignore it if the time to ShT is less than GCD + 500ms, unless the ER buff will expire soon
  -- Reduces the risk of queued finishers into ShT procs for non-optimal CP amounts
  -- This is an adaptation of the following APL lines:
  -- actions+=/variable,name=is_next_cp_animacharged,if=covenant.kyrian,value=combo_points=1&buff.echoing_reprimand_2.up|combo_points=2&buff.echoing_reprimand_3.up|combo_points=3&buff.echoing_reprimand_4.up|combo_points=4&buff.echoing_reprimand_5.up
  -- actions+=/variable,name=effective_combo_points,value=effective_combo_points
  -- actions+=/variable,name=effective_combo_points,if=covenant.kyrian&effective_combo_points>combo_points&combo_points.deficit>2&time_to_sht.4.plus<0.5&!variable.is_next_cp_animacharged,value=combo_points
  if EffectiveComboPoints > ComboPoints and ComboPointsDeficit > 2 and Player:AffectingCombat() then
    if ComboPoints == 2 and not Player:BuffUp(S.EchoingReprimand3)
    or ComboPoints == 3 and not Player:BuffUp(S.EchoingReprimand4)
    or ComboPoints == 4 and not Player:BuffUp(S.EchoingReprimand5) then
      local TimeToSht = Rogue.TimeToSht(4)
      if TimeToSht == 0 then TimeToSht = Rogue.TimeToSht(5) end
      if TimeToSht < (mathmax(Player:EnergyTimeToX(35), Player:GCDRemains()) + 0.5) then
        EffectiveComboPoints = ComboPoints
      end
    end
  end

  -- Shuriken Tornado Combo Point Prediction
  if Player:BuffUp(S.ShurikenTornado, nil, true) and ComboPoints < Rogue.CPMaxSpend() then
    local TimeToNextTornadoTick = Rogue.TimeToNextTornado()
    if TimeToNextTornadoTick <= Player:GCDRemains() or mathabs(Player:GCDRemains() - TimeToNextTornadoTick) < 0.25 then
      local PredictedComboPointGeneration = MeleeEnemies10yCount + num(Player:BuffUp(S.ShadowBlades))
      ComboPoints = mathmin(ComboPoints + PredictedComboPointGeneration, Rogue.CPMaxSpend())
      ComboPointsDeficit = mathmax(ComboPointsDeficit - PredictedComboPointGeneration, 0)
      if EffectiveComboPoints < Rogue.CPMaxSpend() then
        EffectiveComboPoints = ComboPoints
      end
    end
  end

  -- Damage Cache updates (after EffectiveComboPoints adjustments)
  RuptureThreshold = (4 + EffectiveComboPoints * 4) * 0.3
  RuptureDMGThreshold = S.Eviscerate:Damage()*Settings.Subtlety.EviscerateDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.

  --- Defensives
  -- Crimson Vial
  ShouldReturn = Rogue.CrimsonVial()
  if ShouldReturn then return ShouldReturn end
  -- Feint
  ShouldReturn = Rogue.Feint()
  if ShouldReturn then return ShouldReturn end

  -- Poisons
  Rogue.Poisons()

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    -- Note: Since 7.2.5, Blizzard disallowed Stealth cast under ShD (workaround to prevent the Extended Stealth bug)
    if not Player:BuffUp(S.ShadowDanceBuff) and not Player:BuffUp(VanishBuff) then
      ShouldReturn = Rogue.Stealth(Stealth)
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and (Target:IsSpellInRange(S.Shadowstrike) or Target:IsInMeleeRange(5)) then
      -- Precombat CDs
      if HR.CDsON() then
        if S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
        -- TODO: actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
      end
      if Player:StealthUp(true, true) then
        PoolingAbility = Stealthed(true)
        if PoolingAbility then -- To avoid pooling icon spam
          if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
            if HR.CastQueuePooling(nil, unpack(PoolingAbility)) then return "Stealthed Macro Cast or Pool (OOC): ".. PoolingAbility[1]:Name() end
          else
            if HR.CastPooling(PoolingAbility) then return "Stealthed Cast or Pool (OOC): "..PoolingAbility:Name() end
          end
        end
      elseif ComboPoints >= 5 then
        ShouldReturn = Finish()
        if ShouldReturn then return ShouldReturn .. " (OOC)" end
      elseif S.Backstab:IsCastable() then
        if HR.Cast(S.Backstab) then return "Cast Backstab (OOC)" end
      end
    end
    return
  end

  -- In Combat
  -- MfD Sniping
  Rogue.MfDSniping(S.MarkedforDeath)

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons2.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- # Check CDs at first
    -- actions=call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end

    -- # Apply Slice and Dice at 4+ CP if it expires within the next GCD or is not up
    -- actions+=/slice_and_dice,if=spell_targets.shuriken_storm<6&fight_remains>6&buff.slice_and_dice.remains<gcd.max&combo_points>=4-(time<10)*2
    if S.SliceandDice:IsCastable() and MeleeEnemies10yCount < 6 and HL.FilteredFightRemains(MeleeEnemies10y, ">", 6)
      and Player:BuffRemains(S.SliceandDice) < Player:GCD() and ComboPoints >= 4-(2*(BoolToInt(HL.CombatTime() < 5))) then
      if S.SliceandDice:IsReady() and HR.Cast(S.SliceandDice) then return "Cast Slice and Dice (Low Duration)" end
      SetPoolingFinisher(S.SliceandDice)
    end

    -- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
    -- actions+=/run_action_list,name=stealthed,if=stealthed.all
    if Player:StealthUp(true, true) then
      PoolingAbility = Stealthed(true)
      if PoolingAbility then -- To avoid pooling icon spam
        if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
          if HR.CastQueuePooling(nil, unpack(PoolingAbility)) then return "Stealthed Macro " .. PoolingAbility[1]:Name() .. "|" .. PoolingAbility[2]:Name() end
        else
          -- Special case for Shuriken Tornado
          if Player:BuffUp(S.ShurikenTornado) and ComboPoints ~= Player:ComboPoints()
            and (PoolingAbility == S.BlackPowder or PoolingAbility == S.Eviscerate or PoolingAbility == S.Rupture or PoolingAbility == S.SliceandDice) then
            if HR.CastQueuePooling(nil, S.ShurikenTornado, PoolingAbility) then return "Stealthed Tornado Cast  " .. PoolingAbility:Name() end
          else
            if HR.CastPooling(PoolingAbility) then return "Stealthed Cast " .. PoolingAbility:Name() end
          end
        end
      end
      HR.Cast(S.PoolEnergy)
      return "Stealthed Pooling"
    end

    -- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
    if PriorityRotation then
      ShouldReturn = Stealth_CDs()
      if ShouldReturn then return "Stealth CDs: (Priority Rotation)" .. ShouldReturn end
    end

    -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
    if Player:EnergyPredicted() >= StealthEnergyRequired then
      ShouldReturn = Stealth_CDs()
      if ShouldReturn then return "Stealth CDs: " .. ShouldReturn end
    end

    -- actions+=/call_action_list,name=finish,if=effective_combo_points>=cp_max_spend
    -- # Finish at 4+ without DS or with SoD crit buff, 5+ with DS (outside stealth)
    -- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|fight_remains<=1&effective_combo_points>=3|buff.symbols_of_death_autocrit.up&effective_combo_points>=4
    -- # With DS also finish at 4+ against 4 targets (outside stealth)
    -- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm>=4&effective_combo_points>=4
    if EffectiveComboPoints >= Rogue.CPMaxSpend()
      or (ComboPointsDeficit <= 1 or (HL.BossFilteredFightRemains("<", 2) and EffectiveComboPoints >= 3))
      or (MeleeEnemies10yCount >= 4 and EffectiveComboPoints >= 4)
      or (Player:BuffUp(S.SymbolsofDeathCrit) and EffectiveComboPoints >= 4) then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
    else
      -- NOTE: Duplicated stealth_cds line from above since both this and build have the same energy threshold if condition
      -- If we aren't finishing in between, we'll be suggesting to pool something and re-process with StealthEnergyRequired
      
      -- # Consider using a Stealth CD when reaching the energy threshold, called with params to register potential pooling
      -- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
      ShouldReturn = Stealth_CDs(StealthEnergyRequired)
      if ShouldReturn then return "Stealth CDs: " .. ShouldReturn end

      -- # Use a builder when reaching the energy threshold
      -- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
      ShouldReturn = Build(StealthEnergyRequired)
      if ShouldReturn then return "Build: " .. ShouldReturn end
    end

    if HR.CDsON() then
      -- # Lowest priority in all of the APL because it causes a GCD
      -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
      if S.ArcaneTorrent:IsReady() and Target:IsInMeleeRange(5) and Player:EnergyDeficitPredicted() > 15 + Player:EnergyRegen() then
        if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
      end
      -- actions+=/arcane_pulse
      if S.ArcanePulse:IsReady() and Target:IsInMeleeRange(5) then
        if HR.Cast(S.ArcanePulse, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Pulse" end
      end
      -- actions+=/lights_judgment
      if S.LightsJudgment:IsReady() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
      end
      -- actions+=/bag_of_tricks
      if S.BagofTricks:IsReady() then
        if HR.Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
      end
    end

    -- Show what ever was first stored for pooling
    if PoolingFinisher then SetPoolingAbility(PoolingFinisher) end
    if PoolingAbility and Target:IsInMeleeRange(5) then
      if type(PoolingAbility) == "table" and #PoolingAbility > 1 then
        if HR.CastQueuePooling(Player:EnergyTimeToX(PoolingEnergy), unpack(PoolingAbility)) then return "Macro pool towards ".. PoolingAbility[1]:Name() .. " at " .. PoolingEnergy end
      elseif PoolingAbility:IsCastable() then
        PoolingEnergy = mathmax(PoolingEnergy, PoolingAbility:Cost())
        if HR.CastPooling(PoolingAbility, Player:EnergyTimeToX(PoolingEnergy)) then return "Pool towards: " .. PoolingAbility:Name() .. " at " .. PoolingEnergy end
      end
    end

    -- Shuriken Toss Out of Range
    if S.ShurikenToss:IsCastable() and Target:IsInRange(30) and not Target:IsInRange(10) and not Player:StealthUp(true, true) and not Player:BuffUp(S.Sprint)
      and Player:EnergyDeficitPredicted() < 20 and (ComboPointsDeficit >= 1 or Player:EnergyTimeToMax() <= 1.2) then
      if HR.CastPooling(S.ShurikenToss) then return "Cast Shuriken Toss" end
    end
  end
end

local function Init ()
  HR.Print("Subtlety Rogue rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(261, APL, Init)

-- Last Update: 04/24/2022

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
-- actions.precombat+=/stealth
-- actions.precombat+=/marked_for_death,precombat_seconds=15
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/shadow_blades,if=runeforge.mark_of_the_master_assassin

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- # Used to determine whether cooldowns wait for SnD based on targets.
-- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up|spell_targets.shuriken_storm>=6
-- # Check to see if the next CP (in the event of a ShT proc) is Animacharged
-- actions+=/variable,name=is_next_cp_animacharged,if=covenant.kyrian,value=combo_points=1&buff.echoing_reprimand_2.up|combo_points=2&buff.echoing_reprimand_3.up|combo_points=3&buff.echoing_reprimand_4.up|combo_points=4&buff.echoing_reprimand_5.up
-- # Account for ShT reaction time by ignoring low-CP animacharged matches in the 0.5s preceeding a potential ShT proc
-- actions+=/variable,name=effective_combo_points,value=effective_combo_points
-- actions+=/variable,name=effective_combo_points,if=covenant.kyrian&effective_combo_points>combo_points&combo_points.deficit>2&time_to_sht.4.plus<0.5&!variable.is_next_cp_animacharged,value=combo_points
-- # Check CDs at first
-- actions+=/call_action_list,name=cds
-- # Apply Slice and Dice at 2+ CP during the first 10 seconds, after that 4+ CP if it expires within the next GCD or is not up
-- actions+=/slice_and_dice,if=spell_targets.shuriken_storm<6&fight_remains>6&buff.slice_and_dice.remains<gcd.max&combo_points>=4-(time<10)*2
-- # Run fully switches to the Stealthed Rotation (by doing so, it forces pooling if nothing is available).
-- actions+=/run_action_list,name=stealthed,if=stealthed.all
-- # Only change rotation if we have priority_rotation set and multiple targets up.
-- actions+=/variable,name=use_priority_rotation,value=priority_rotation&spell_targets.shuriken_storm>=2
-- # Priority Rotation? Let's give a crap about energy for the stealth CDs (builder still respect it). Yup, it can be that simple.
-- actions+=/call_action_list,name=stealth_cds,if=variable.use_priority_rotation
-- # Used to define when to use stealth CDs or builders
-- actions+=/variable,name=stealth_threshold,value=25+talent.vigor.enabled*20+talent.master_of_shadows.enabled*20+talent.shadow_focus.enabled*25+talent.alacrity.enabled*20+25*(spell_targets.shuriken_storm>=4)
-- # Consider using a Stealth CD when reaching the energy threshold
-- actions+=/call_action_list,name=stealth_cds,if=energy.deficit<=variable.stealth_threshold
-- actions+=/call_action_list,name=finish,if=variable.effective_combo_points>=cp_max_spend
-- # Finish at 4+ without DS or with SoD crit buff, 5+ with DS (outside stealth)
-- actions+=/call_action_list,name=finish,if=combo_points.deficit<=1|fight_remains<=1&variable.effective_combo_points>=3|buff.symbols_of_death_autocrit.up&variable.effective_combo_points>=4
-- # With DS also finish at 4+ against 4 targets (outside stealth)
-- actions+=/call_action_list,name=finish,if=spell_targets.shuriken_storm>=4&variable.effective_combo_points>=4
-- # Use a builder when reaching the energy threshold
-- actions+=/call_action_list,name=build,if=energy.deficit<=variable.stealth_threshold
-- # Lowest priority in all of the APL because it causes a GCD
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- actions.build=shiv,if=!talent.nightstalker.enabled&runeforge.tiny_toxic_blade&spell_targets.shuriken_storm<5
-- actions.build+=/shuriken_storm,if=spell_targets>=2&(!covenant.necrolord|cooldown.serrated_bone_spike.max_charges-charges_fractional>=0.25|spell_targets.shuriken_storm>4)&(buff.perforated_veins.stack<=4|spell_targets.shuriken_storm>4&!variable.use_priority_rotation)
-- actions.build+=/serrated_bone_spike,if=buff.perforated_veins.stack<=2&(cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25|soulbind.lead_by_example.enabled&!buff.lead_by_example.up|soulbind.kevins_oozeling.enabled&!debuff.kevins_wrath.up)
-- actions.build+=/gloomblade
-- # Backstab immediately unless the next CP is Animacharged and we won't cap energy waiting for it.
-- actions.build+=/backstab,if=!covenant.kyrian|!(variable.is_next_cp_animacharged&(time_to_sht.3.plus<0.5|time_to_sht.4.plus<1)&energy<60)

-- # Cooldowns
-- # Use Dance off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds=shadow_dance,use_off_gcd=1,if=!buff.shadow_dance.up&buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- # (Unless already up because we took Shadow Focus) use Symbols off-gcd before the first Shuriken Storm from Tornado comes in.
-- actions.cds+=/symbols_of_death,use_off_gcd=1,if=buff.shuriken_tornado.up&buff.shuriken_tornado.remains<=3.5
-- actions.cds+=/flagellation,if=variable.snd_condition&!stealthed.mantle&(spell_targets.shuriken_storm<=1&cooldown.symbols_of_death.up&!talent.shadow_focus.enabled|buff.symbols_of_death.up)&combo_points>=5
-- actions.cds+=/vanish,if=(runeforge.mark_of_the_master_assassin&combo_points.deficit<=1-talent.deeper_strategem.enabled|runeforge.deathly_shadows&combo_points<1)&buff.symbols_of_death.up&buff.shadow_dance.up&master_assassin_remains=0&buff.deathly_shadows.down
-- # Pool for Tornado pre-SoD with ShD ready when not running SF.
-- actions.cds+=/pool_resource,for_next=1,if=talent.shuriken_tornado.enabled&!talent.shadow_focus.enabled
-- # Use Tornado pre SoD when we have the energy whether from pooling without SF or just generally.
-- actions.cds+=/shuriken_tornado,if=spell_targets.shuriken_storm<=1&energy>=60&variable.snd_condition&cooldown.symbols_of_death.up&cooldown.shadow_dance.charges>=1&(!runeforge.obedience|debuff.flagellation.up|spell_targets.shuriken_storm>=(1+4*(!talent.nightstalker.enabled&!talent.dark_shadow.enabled)))&combo_points<=2&!buff.premeditation.up&(!covenant.venthyr|!cooldown.flagellation.up)
-- actions.cds+=/serrated_bone_spike,cycle_targets=1,if=variable.snd_condition&!dot.serrated_bone_spike_dot.ticking&target.time_to_die>=21&(combo_points.deficit>=(cp_gain>?4))&!buff.shuriken_tornado.up&(!buff.premeditation.up|spell_targets.shuriken_storm>4)|fight_remains<=5&spell_targets.shuriken_storm<3
-- actions.cds+=/sepsis,if=variable.snd_condition&combo_points.deficit>=1&target.time_to_die>=16
-- # Use Symbols on cooldown (after first SnD) unless we are going to pop Tornado and do not have Shadow Focus.
-- actions.cds+=/symbols_of_death,if=variable.snd_condition&(!stealthed.all|buff.perforated_veins.stack<4|spell_targets.shuriken_storm>4&!variable.use_priority_rotation)&(!talent.shuriken_tornado.enabled|talent.shadow_focus.enabled|spell_targets.shuriken_storm>=2|cooldown.shuriken_tornado.remains>2)&(!covenant.venthyr|cooldown.flagellation.remains>10|cooldown.flagellation.up&combo_points>=5)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or not stealthed without any CP.
-- actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.all&combo_points.deficit>=cp_max_spend)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend
-- actions.cds+=/shadow_blades,if=variable.snd_condition&combo_points.deficit>=2&(buff.symbols_of_death.up|fight_remains<=20|!buff.shadow_blades.up&set_bonus.tier28_2pc)
-- actions.cds+=/echoing_reprimand,if=(!talent.shadow_focus.enabled|!stealthed.all|spell_targets.shuriken_storm>=4)&variable.snd_condition&combo_points.deficit>=2&(variable.use_priority_rotation|spell_targets.shuriken_storm<=4|runeforge.resounding_clarity)
-- # With SF, if not already done, use Tornado with SoD up.
-- actions.cds+=/shuriken_tornado,if=(talent.shadow_focus.enabled|spell_targets.shuriken_storm>=2)&variable.snd_condition&buff.symbols_of_death.up&combo_points<=2&(!buff.premeditation.up|spell_targets.shuriken_storm>4)
-- actions.cds+=/shadow_dance,if=!buff.shadow_dance.up&fight_remains<=8+talent.subterfuge.enabled
-- actions.cds+=/fleshcraft,if=(soulbind.pustule_eruption|soulbind.volatile_solvent)&energy.deficit>=30&!stealthed.all&buff.symbols_of_death.down
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.symbols_of_death.up&(buff.shadow_blades.up|cooldown.shadow_blades.remains<=10)
-- actions.cds+=/blood_fury,if=buff.symbols_of_death.up
-- actions.cds+=/berserking,if=buff.symbols_of_death.up
-- actions.cds+=/fireblood,if=buff.symbols_of_death.up
-- actions.cds+=/ancestral_call,if=buff.symbols_of_death.up
-- actions.cds+=/use_item,name=cache_of_acquired_treasures,if=(covenant.venthyr&buff.acquired_axe.up|!covenant.venthyr&buff.acquired_wand.up)&(spell_targets.shuriken_storm=1&raid_event.adds.in>60|fight_remains<25|variable.use_priority_rotation)|buff.acquired_axe.up&spell_targets.shuriken_storm>1
-- # Default fallback for usable items: Use with Symbols of Death.
-- actions.cds+=/use_items,if=buff.symbols_of_death.up|fight_remains<20

-- # Finishers
-- # While using Premeditation, avoid casting Slice and Dice when Shadow Dance is soon to be used, except for Kyrian
-- actions.finish=variable,name=premed_snd_condition,value=talent.premeditation.enabled&spell_targets.shuriken_storm<(5-covenant.necrolord)&!covenant.kyrian
-- actions.finish+=/slice_and_dice,if=!variable.premed_snd_condition&spell_targets.shuriken_storm<6&!buff.shadow_dance.up&buff.slice_and_dice.remains<fight_remains&refreshable
-- actions.finish+=/slice_and_dice,if=variable.premed_snd_condition&cooldown.shadow_dance.charges_fractional<1.75&buff.slice_and_dice.remains<cooldown.symbols_of_death.remains&(cooldown.shadow_dance.ready&buff.symbols_of_death.remains-buff.shadow_dance.remains<1.2)
-- # Helper Variable for Rupture. Skip during Master Assassin or during Dance with Dark and no Nightstalker.
-- actions.finish+=/variable,name=skip_rupture,value=master_assassin_remains>0|!talent.nightstalker.enabled&talent.dark_shadow.enabled&buff.shadow_dance.up|spell_targets.shuriken_storm>=(4-stealthed.all*talent.shadow_focus.enabled)
-- # Keep up Rupture if it is about to run out.
-- actions.finish+=/rupture,if=!stealthed.all&(!variable.skip_rupture|variable.use_priority_rotation)&target.time_to_die-remains>6&refreshable
-- actions.finish+=/secret_technique
-- # Multidotting targets that will live for the duration of Rupture, refresh during pandemic.
-- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.use_priority_rotation&spell_targets.shuriken_storm>=2&target.time_to_die>=(5+(2*combo_points))&refreshable
-- # Refresh Rupture early if it will expire during Symbols. Do that refresh if SoD gets ready in the next 5s.
-- actions.finish+=/rupture,if=!variable.skip_rupture&remains<cooldown.symbols_of_death.remains+10&cooldown.symbols_of_death.remains<=5&target.time_to_die-remains>cooldown.symbols_of_death.remains+5
-- actions.finish+=/black_powder,if=!variable.use_priority_rotation&spell_targets>=3
-- actions.finish+=/eviscerate

-- # Stealth Cooldowns
-- # Helper Variable
-- actions.stealth_cds=variable,name=shd_threshold,value=cooldown.shadow_dance.charges_fractional>=(1.75-0.75*(covenant.kyrian&set_bonus.tier28_2pc&cooldown.symbols_of_death.remains>=8))
-- actions.stealth_cds+=/variable,name=shd_threshold,if=runeforge.the_rotten,value=cooldown.shadow_dance.charges_fractional>=1.75|cooldown.symbols_of_death.remains>=16
-- # Vanish if we are capping on Dance charges. Early before first dance if we have no Nightstalker but Dark Shadow in order to get Rupture up (no Master Assassin).
-- actions.stealth_cds+=/vanish,if=(!variable.shd_threshold|!talent.nightstalker.enabled&talent.dark_shadow.enabled)&combo_points.deficit>1&!runeforge.mark_of_the_master_assassin
-- # Pool for Shadowmeld + Shadowstrike unless we are about to cap on Dance charges. Only when Find Weakness is about to run out.
-- actions.stealth_cds+=/pool_resource,for_next=1,extra_amount=40,if=race.night_elf
-- actions.stealth_cds+=/shadowmeld,if=energy>=40&energy.deficit>=10&!variable.shd_threshold&combo_points.deficit>1
-- # CP thresholds for entering Shadow Dance
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=2+buff.shadow_blades.up
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit>=3,if=covenant.kyrian
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=variable.use_priority_rotation&spell_targets.shuriken_storm>=4
-- actions.stealth_cds+=/variable,name=shd_combo_points,value=combo_points.deficit<=1,if=spell_targets.shuriken_storm=4
-- # Dance during Symbols or above threshold.
-- actions.stealth_cds+=/shadow_dance,if=(runeforge.the_rotten&cooldown.symbols_of_death.remains<=8|variable.shd_combo_points&(buff.symbols_of_death.remains>=1.2|variable.shd_threshold)|buff.chaos_bane.up|spell_targets.shuriken_storm>=4&cooldown.symbols_of_death.remains>10)&(buff.perforated_veins.stack<4|spell_targets.shuriken_storm>3)
-- # Burn Dances charges if you play Dark Shadows/Alacrity or before the fight ends if SoD won't be ready in time.
-- actions.stealth_cds+=/shadow_dance,if=variable.shd_combo_points&fight_remains<cooldown.symbols_of_death.remains|!talent.enveloping_shadows.enabled

-- # Stealthed Rotation
-- # If Stealth/vanish are up, use Shadowstrike to benefit from the passive bonus and Find Weakness, even if we are at max CP (unless using Master Assassin)
-- actions.stealthed=shadowstrike,if=(buff.stealth.up|buff.vanish.up)&(spell_targets.shuriken_storm<4|variable.use_priority_rotation)&master_assassin_remains=0
-- actions.stealthed+=/call_action_list,name=finish,if=variable.effective_combo_points>=cp_max_spend
-- # Finish at 3+ CP without DS / 4+ with DS with Shuriken Tornado buff up to avoid some CP waste situations.
-- actions.stealthed+=/call_action_list,name=finish,if=buff.shuriken_tornado.up&combo_points.deficit<=2
-- # Also safe to finish at 4+ CP with exactly 4 targets. (Same as outside stealth.)
-- actions.stealthed+=/call_action_list,name=finish,if=spell_targets.shuriken_storm>=4&variable.effective_combo_points>=4
-- # Finish at 4+ CP without DS, 5+ with DS, and 6 with DS after Vanish
-- actions.stealthed+=/call_action_list,name=finish,if=combo_points.deficit<=1-(talent.deeper_stratagem.enabled&buff.vanish.up)
-- actions.stealthed+=/shadowstrike,if=stealthed.sepsis&spell_targets.shuriken_storm<4
-- # Backstab during Shadow Dance when on high PV stacks and Shadow Blades is up.
-- actions.stealthed+=/backstab,if=conduit.perforated_veins.rank>=8&buff.perforated_veins.stack>=5&buff.shadow_dance.remains>=3&buff.shadow_blades.up&(spell_targets.shuriken_storm<=3|variable.use_priority_rotation)&(buff.shadow_blades.remains<=buff.shadow_dance.remains+2|!covenant.venthyr)
-- actions.stealthed+=/shiv,if=talent.nightstalker.enabled&runeforge.tiny_toxic_blade&spell_targets.shuriken_storm<5
-- # Up to 3 targets (no prio) keep up Find Weakness by cycling Shadowstrike.
-- actions.stealthed+=/shadowstrike,cycle_targets=1,if=!variable.use_priority_rotation&debuff.find_weakness.remains<1&spell_targets.shuriken_storm<=3&target.time_to_die-remains>6
-- # For priority rotation, use Shadowstrike over Storm with WM against up to 4 targets or if FW is running off (on any amount of targets)
-- actions.stealthed+=/shadowstrike,if=variable.use_priority_rotation&(debuff.find_weakness.remains<1|talent.weaponmaster.enabled&spell_targets.shuriken_storm<=4)
-- actions.stealthed+=/shuriken_storm,if=spell_targets>=3+(buff.the_rotten.up|runeforge.akaaris_soul_fragment|set_bonus.tier28_2pc&talent.shadow_focus.enabled)&(buff.symbols_of_death_autocrit.up|!buff.premeditation.up|spell_targets>=5)
-- # Shadowstrike to refresh Find Weakness and to ensure we can carry over a full FW into the next SoD if possible.
-- actions.stealthed+=/shadowstrike,if=debuff.find_weakness.remains<=1|cooldown.symbols_of_death.remains<18&debuff.find_weakness.remains<cooldown.symbols_of_death.remains
-- actions.stealthed+=/gloomblade,if=buff.perforated_veins.stack>=5&conduit.perforated_veins.rank>=13
-- actions.stealthed+=/shadowstrike
-- actions.stealthed+=/cheap_shot,if=!target.is_boss&combo_points.deficit>=1&buff.shot_in_the_dark.up&energy.time_to_40>gcd.max
