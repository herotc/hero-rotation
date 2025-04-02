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
local ValueIsInArray = HL.Utils.ValueIsInArray
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast = HR.Cast
local CastLeftNameplate = HR.CastLeftNameplate
local CastPooling = HR.CastPooling
local CastQueue = HR.CastQueue
local CastQueuePooling = HR.CastQueuePooling
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local pairs = pairs
local tableinsert = table.insert
local mathmin = math.min
local mathmax = math.max
local mathabs = math.abs
local Delay = C_Timer.After

--- APL Local Vars
-- Commons
local Everyone = HR.Commons.Everyone
local Rogue = HR.Commons.Rogue
-- Define S/I for spell and item arrays
local S = Spell.Rogue.Subtlety
local I = Item.Rogue.Subtlety

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BottledFlayedwingToxin:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.MadQueensMandate:ID(),
  I.TreacherousTransmitter:ID()
}

-- Rotation Var
local MeleeRange, AoERange, TargetInAoERange
local Enemies30y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y
local ShouldReturn; -- Used to get the return string
local PoolingAbility, PoolingEnergy, PoolingFinisher; -- Used to store an ability we might want to pool for as a fallback in the current situation
local RuptureThreshold, RuptureDMGThreshold
local EffectiveComboPoints, ComboPoints, ComboPointsDeficit
local PriorityRotation
local Stealth, SkipRupture, Maintenance, Secret, RacialSync, ShdCp

-- Trinkets
local trinket1, trinket2
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

  trinket1 = T1.Object
  trinket2 = T2.Object
end
SetTrinketVariables()

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

S.Eviscerate:RegisterDamageFormula(
-- Eviscerate DMG Formula (Pre-Mitigation):
--- Player Modifier
-- AP * CP * EviscR1_APCoef * Aura_M * NS_M * DS_M * DSh_M * SoD_M * Finality_M * Mastery_M * Versa_M
--- Target Modifier
-- EviscR2_M * Sinful_M
  function()
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
      -- Deeper Stratagem Multiplier
      (S.DeeperStratagem:IsAvailable() and 1.05 or 1) *
      -- Shadow Dance Multiplier
      (S.DarkShadow:IsAvailable() and Player:BuffUp(S.ShadowDanceBuff) and 1.3 or 1) *
      -- Symbols of Death Multiplier
      (Player:BuffUp(S.SymbolsofDeath) and 1.1 or 1) *
      -- Finality Multiplier
      (Player:BuffUp(S.FinalityEviscerateBuff) and 1.3 or 1) *
      -- Mastery Finisher Multiplier
      (1 + Player:MasteryPct() / 100) *
      -- Versatility Damage Multiplier
      (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
      -- Eviscerate R2 Multiplier
      (Target:DebuffUp(S.FindWeaknessDebuff) and 1.5 or 1)
  end
)

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  CommonsDS = HR.GUISettings.APL.Rogue.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Rogue.CommonsOGCD,
  Subtlety = HR.GUISettings.APL.Rogue.Subtlety
}

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
  elseif Settings.Subtlety.UsePriorityRotation == "Always" then
    return true
  elseif Settings.Subtlety.UsePriorityRotation == "On Bosses" and Target:IsInBossList() then
    return true
  elseif Settings.Subtlety.UsePriorityRotation == "Auto" then
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

-- APL Action Lists (and Variables)
local function Stealth_Threshold ()
  -- actions+=/ variable,name=stealth_threshold,value=20+talent.vigor.rank*25+talent.thistle_tea*20+talent.shadowcraft*20
  return 20 + S.Vigor:TalentRank() * 25 + num(S.ThistleTea:IsAvailable()) * 20 + num(S.Shadowcraft:IsAvailable()) * 20
end

local function SnD_Condition ()
  -- actions+=/variable,name=snd_condition,value=buff.slice_and_dice.up
  return Player:BuffUp(S.SliceandDice)
end

local function Rupture_Before_Flag()
  -- actions.cds=variable,name=ruptures_before_flag,value=variable.priority_rotation|spell_targets<=4
  -- |(talent.replicating_shadows&(spell_targets>=5&active_dot.rupture>=spell_targets-2))|!talent.replicating_shadows
  return PriorityRotation or MeleeEnemies10yCount <= 4
    or (S.ReplicatingShadows:IsAvailable() and (MeleeEnemies10yCount >= 5 and S.Rupture:AuraActiveCount() >= MeleeEnemies10yCount - 2))
    or not S.ReplicatingShadows:IsAvailable()
end

local function Used_For_Danse(Spell)
  return Player:BuffUp(S.ShadowDanceBuff) and Spell:TimeSinceLastCast() < S.ShadowDance:TimeSinceLastCast()
end

local function Trinket_Sync_Slot()
  -- ctions.precombat+=/variable,name=trinket_sync_slot,value=1,if=trinket.1.has_use_buff
  -- &(!trinket.2.has_use_buff|trinket.1.is.treacherous_transmitter|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  -- actions.precombat+=/variable,name=trinket_sync_slot,value=2,if=trinket.2.has_use_buff
  -- &(!trinket.1.has_use_buff|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  local TrinketSyncSlot = 0

  if trinket1:HasUseBuff() and (not trinket2:HasUseBuff() or trinket1:ID() == I.TreacherousTransmitter:ID() or trinket1:Cooldown() >= trinket2:Cooldown()) then
    TrinketSyncSlot = 1
  elseif trinket2:HasUseBuff() and (not trinket1:HasUseBuff() or trinket2:Cooldown() > trinket1:Cooldown()) then
    TrinketSyncSlot = 2
  end

  return TrinketSyncSlot
end

-- # Finishers
-- ReturnSpellOnly and StealthSpell parameters are to Predict Finisher in case of Stealth Macros
local function Finish (ReturnSpellOnly, ForceStealth)
  -- actions.finish=secret_technique,if=variable.secret
  if S.SecretTechnique:IsReady() and (Secret or ForceStealth) then
      if ReturnSpellOnly then
        return S.SecretTechnique
      end
      if Cast(S.SecretTechnique, Settings.Subtlety.GCDasOffGCD.SecretTechnique) then
        return "Cast Secret Technique"
      end
  end

  -- # Maintenance Finisher
  -- actions.finish+=/rupture,if=!variable.skip_rupture&(!dot.rupture.ticking|refreshable)&target.time_to_die-remains>6
  if S.Rupture:IsReady() then
    if not SkipRupture and (not Target:DebuffUp(S.Rupture) or Target:DebuffRefreshable(S.Rupture, RuptureThreshold)) and Target:TimeToDie() > 6 then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if CastPooling(S.Rupture, nil, not Target:IsSpellInRange(S.Rupture)) then
          return "Cast Rupture"
        end
      end
    end
  end

  -- actions.finish+=/rupture,cycle_targets=1,if=!variable.skip_rupture&!variable.priority_rotation
  -- &target.time_to_die>=(2*combo_points)&refreshable&variable.targets>=2
  if S.Rupture:IsReady() and not SkipRupture then
    if not ReturnSpellOnly and HR.AoEON() and not PriorityRotation and MeleeEnemies10yCount >= 2 then
      local function Evaluate_Rupture_Target(TargetUnit)
        return Everyone.CanDoTUnit(TargetUnit, RuptureDMGThreshold)
          and TargetUnit:DebuffRefreshable(S.Rupture, RuptureThreshold)
      end
      SuggestCycleDoT(S.Rupture, Evaluate_Rupture_Target, (2 * ComboPoints), MeleeEnemies5y)
    end
  end

  -- actions.finish+=/rupture,if=talent.unseen_blade&cooldown.flagellation.remains<10&dot.rupture.remains<fight_remains
  if S.Rupture:IsReady() and Settings.Subtlety.HoldCoupForCDs then
    if S.UnseenBlade:IsAvailable() and S.Flagellation:CooldownRemains() < 10
      and (Target:DebuffRemains(S.Rupture) < HL.FightRemains(MeleeEnemies10y, false)) then
      if ReturnSpellOnly then
        return S.Rupture
      else
        if CastPooling(S.Rupture, nil, not Target:IsSpellInRange(S.Rupture)) then
          return "Cast Rupture"
        end
      end
    end
  end

  -- # Direct Damage Finisher
  -- actions.finish+=/coup_de_grace,if=debuff.fazed.up&cooldown.flagellation.remains>=20
  if S.CoupDeGrace:IsCastable() and Target:DebuffUp(S.FazedDebuff) and (S.Flagellation:CooldownRemains() >= 20 or not Settings.Subtlety.HoldCoupForCDs) then
      if ReturnSpellOnly then
        return S.CoupDeGrace
      else
        if CastPooling(S.CoupDeGrace, nil, not Target:IsSpellInRange(S.CoupDeGrace)) then
          return "Cast Coup De Grace"
        end
      end
  end

  -- actions.finish+=/black_powder,if=!variable.priority_rotation&variable.maintenance&(((variable.targets>=2
  -- &talent.deathstalkers_mark&(!buff.darkest_night.up|buff.shadow_dance.up&variable.targets>=5))
  -- |talent.unseen_blade&variable.targets>=7)|action.coup_de_grace.ready)
  if S.BlackPowder:IsCastable() then
    if not PriorityRotation and Maintenance and (((MeleeEnemies10yCount >= 2 and S.DeathStalkersMark:IsAvailable()
    and (Player:BuffDown(S.DarkestNightBuff) or Player:BuffUp(S.ShadowDanceBuff) and MeleeEnemies10yCount >= 5))
    or S.UnseenBlade:IsAvailable() and MeleeEnemies10yCount >= 7) or (S.CoupDeGrace:IsReady() and Settings.Subtlety.HoldCoupForCDs)) then
      if ReturnSpellOnly then
        return S.BlackPowder
      else
        if CastPooling(S.BlackPowder, nil, not TargetInAoERange) then
          return "Cast BlackPowder"
        end
      end
    end
  end

  -- actions.finish+=/eviscerate
  if S.Eviscerate:IsCastable() then
    if ReturnSpellOnly then
      return S.Eviscerate
    else
      if CastPooling(S.Eviscerate, nil, not Target:IsSpellInRange(S.Eviscerate)) then
        return "Cast Eviscerate"
      end
    end
  end

  return false
end

-- # Builders
local function Build (ReturnSpellOnly, ForceStealth)
  -- actions.build=backstab,if=buff.shadow_dance.up&!used_for_danse|!variable.stealth&buff.shadow_blades.up
  if S.Backstab:IsReady() and (Player:BuffUp(S.ShadowDanceBuff) or ForceStealth) and not Used_For_Danse(S.Backstab)
    or not Stealth and Player:BuffUp(S.ShadowBlades) then
    if ReturnSpellOnly then
      return S.Backstab
    else
      if CastPooling(S.Backstab, nil, not Target:IsSpellInRange(S.Backstab)) then
        return "Cast Backstab"
      end
    end
  end

  -- actions.build+=/gloomblade,if=buff.shadow_dance.up&!used_for_danse|!variable.stealth&buff.shadow_blades.up
  if S.Gloomblade:IsReady() and (Player:BuffUp(S.ShadowDanceBuff) or ForceStealth) and not Used_For_Danse(S.Gloomblade)
    or not Stealth and Player:BuffUp(S.ShadowBlades) then
    if ReturnSpellOnly then
      return S.Gloomblade
    else
      if CastPooling(S.Gloomblade, nil, not Target:IsSpellInRange(S.Gloomblade)) then
        return "Cast Gloomblade"
      end
    end
  end

  -- actions.build=shadowstrike,cycle_targets=1,if=debuff.find_weakness.remains<=2&variable.targets=2
  -- &talent.unseen_blade|!used_for_danse&!talent.premeditation
  if S.Shadowstrike:IsReady() and HR.AoEON() and (Player:StealthUp(true, false) or ForceStealth) then
    if MeleeEnemies10yCount == 2 and S.UnseenBlade:IsAvailable()
      or not Used_For_Danse(S.Shadowstrike) and not S.Premeditation:IsAvailable() then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        if CycleUnit:GUID() ~= Target:GUID() and CycleUnit:DebuffRemains(S.FindWeaknessDebuff) <= 2 then
          CastLeftNameplate(CycleUnit, S.Shadowstrike)
        end
      end
    end
  end

  -- actions.build+=/shuriken_tornado,if=buff.lingering_darkness.up|talent.deathstalkers_mark&cooldown.shadow_blades.remains>=32
  -- &variable.targets>=3|talent.unseen_blade&buff.symbols_of_death.up&variable.targets>=4
  if S.ShurikenTornado:IsReady() and S.ShurikenTornado:IsAvailable() then
    if Player:BuffUp(S.LingeringDarknessBuff) or S.DeathStalkersMark:IsAvailable()
      and S.ShadowBlades:CooldownRemains() >= 32 and MeleeEnemies10yCount >= 3 or S.UnseenBlade:IsAvailable()
      and Player:BuffUp(S.SymbolsofDeath) and MeleeEnemies10yCount >= 4 then
      if ReturnSpellOnly then
        return S.ShurikenTornado
      else
        if Cast(S.ShurikenTornado, Settings.Subtlety.GCDasOffGCD.ShurikenTornado) then
          return "Cast ShurikenTornado"
        end
      end
    end
  end

  -- actions.build+=/shuriken_storm,if=buff.clear_the_witnesses.up&(variable.targets>=2|!buff.symbols_of_death.up)
  if S.ShurikenStorm:IsReady() and not ForceStealth and HR.AoEON() then
    if Player:BuffUp(S.ClearTheWitnessesBuff) and (MeleeEnemies10yCount >= 2 or Player:BuffDown(S.SymbolsofDeath)) then
      if ReturnSpellOnly then
        return S.ShurikenStorm
      else
        if CastPooling(S.ShurikenStorm) then
          return "Cast ShurikenStorm"
        end
      end
    end
  end

  -- actions.build+=/shadowstrike,cycle_targets=1,if=talent.deathstalkers_mark&!debuff.deathstalkers_mark.up&variable.targets>=3
  -- &(buff.shadow_blades.up|buff.premeditation.up|talent.the_rotten)
  if S.Shadowstrike:IsReady() and HR.AoEON() and Player:StealthUp(true, false) then
    if S.DeathStalkersMark:IsAvailable() and Target:DebuffDown(S.DeathStalkersMarkDebuff) and MeleeEnemies10yCount >= 3
    and (Player:BuffUp(S.ShadowBlades) or Player:BuffUp(S.PremeditationBuff) or S.TheRotten:IsAvailable()) then
      for _, CycleUnit in pairs(MeleeEnemies10y) do
        if CycleUnit:GUID() ~= Target:GUID() then
          CastLeftNameplate(CycleUnit, S.Shadowstrike)
        end
      end
    end
  end

  -- actions.build+=/shuriken_storm,if=talent.deathstalkers_mark&variable.targets>=(2+3*buff.shadow_dance.up)
  if S.ShurikenStorm:IsReady() and not ForceStealth and HR.AoEON()
    and S.DeathStalkersMark:IsAvailable() and MeleeEnemies10yCount >= (2 + 3 * num(Player:BuffUp(S.ShadowDanceBuff))) then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if CastPooling(S.ShurikenStorm) then
        return "Cast ShurikenStorm"
      end
    end
  end

  -- actions.build+=/shuriken_storm,if=talent.unseen_blade&(buff.flawless_form.up&variable.targets>=3
  -- &!variable.stealth|buff.the_rotten.stack=1&variable.targets>=7&buff.shadow_dance.up)
  if S.ShurikenStorm:IsReady() and not ForceStealth and HR.AoEON() and S.UnseenBlade:IsAvailable()
  and (Player:BuffUp(S.FlawlessFormBuff) and MeleeEnemies10yCount >= 3 and not Stealth
    or Player:BuffStack(S.TheRottenBuff) == 1 and MeleeEnemies10yCount >= 7 and Player:BuffUp(S.ShadowDanceBuff)) then
    if ReturnSpellOnly then
      return S.ShurikenStorm
    else
      if CastPooling(S.ShurikenStorm) then
        return "Cast ShurikenStorm"
      end
    end
  end

  -- actions.build+=/shadowstrike
  if S.Shadowstrike:IsReady() or ForceStealth then
    if ReturnSpellOnly then
      return S.Shadowstrike
    else
      if CastPooling(S.Shadowstrike, nil, not Target:IsSpellInRange(S.Shadowstrike)) then
        return "Cast Shadowstrike"
      end
    end
  end

  -- actions.build+=/goremaws_bite,if=combo_points.deficit>=3
  if HR.CDsON() and S.GoremawsBite:IsAvailable() and S.GoremawsBite:IsReady() then
    if ComboPointsDeficit >= 3 then
      if ReturnSpellOnly then
        return S.GoremawsBite
      else
        if CastPooling(S.GoremawsBite, nil, not Target:IsSpellInRange(S.GoremawsBite)) then
          return "Cast GoremawsBite"
        end
      end
    end
  end

  -- actions.build+=/gloomblade
  if S.Gloomblade:IsCastable() then
    if ReturnSpellOnly then
      return S.Gloomblade
    else
      if CastPooling(S.Gloomblade, nil, not Target:IsSpellInRange(S.Gloomblade)) then
        return "Cast Gloomblade"
      end
    end
  end

  -- actions.build+=/backstab
  if S.Backstab:IsCastable() then
    if ReturnSpellOnly then
      return S.Backstab
    else
      if CastPooling(S.Backstab, nil, not Target:IsSpellInRange(S.Backstab)) then
        return "Cast Backstab"
      end
    end
  end
  return false
end

-- # Stealth Macros
-- This returns a table with the original Stealth spell and the result of the Stealthed action list as if the applicable buff was present
local function StealthMacro (StealthSpell)
  -- Fetch the predicted ability to use after the stealth spell
  local MacroAbility
  if not Player:BuffUp(S.DarkestNightBuff) and EffectiveComboPoints >= 6 or Player:BuffUp(S.DarkestNightBuff) and ComboPoints == Rogue.CPMaxSpend() then
    MacroAbility = Finish(true, StealthSpell, true)
  end

  if not MacroAbility then
    MacroAbility = Build(true, true)
  end

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if StealthSpell:ID() == S.Vanish:ID() and (not Settings.Subtlety.StealthMacro.Vanish or not MacroAbility) then
    if Cast(S.Vanish, Settings.CommonsOGCD.OffGCDasOffGCD.Vanish) then
      return "Cast Vanish"
    end
    return false
  elseif StealthSpell:ID() == S.Shadowmeld:ID() and (not Settings.Subtlety.StealthMacro.Shadowmeld or not MacroAbility) then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Shadowmeld"
    end
    return false
  elseif StealthSpell:ID() == S.ShadowDance:ID() and (not Settings.Subtlety.StealthMacro.ShadowDance or not MacroAbility) then
    if Cast(S.ShadowDance, Settings.Subtlety.OffGCDasOffGCD.ShadowDance) then
      return "Cast Shadow Dance"
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

-- # Cooldowns
local function CDs ()
  -- actions.cds=cold_blood,if=cooldown.secret_technique.up&buff.shadow_dance.up&combo_points>=6&variable.secret&buff.flagellation_persist.up
  if HR.CDsON() and S.ColdBlood:IsReady() and S.SecretTechnique:IsReady() and Player:BuffUp(S.ShadowDanceBuff)
    and ComboPoints >= 6 and Secret and Player:BuffUp(S.FlagellationPersistBuff) then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
      return "Cast Cold Blood"
    end
  end

  -- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.flagellation_buff.up
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 30) or Player:BuffUp(S.FlagellationBuff)) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then
        return "Cast Potion";
      end
    end
  end

  -- actions.cds+=/symbols_of_death,if=(buff.symbols_of_death.remains<=3&variable.maintenance
  -- &(!talent.flagellation|cooldown.flagellation.remains>=30-15*!talent.death_perception
  -- &cooldown.secret_technique.remains<8|!talent.death_perception)|fight_remains<=15)
  if HR.CDsON() and S.SymbolsofDeath:IsReady() then
    if (Player:BuffRemains(S.SymbolsofDeath) <= 3 and Maintenance and
      (not S.Flagellation:IsAvailable() or (S.Flagellation:CooldownRemains() >= 30 - 15 * num(not S.DeathPerception:IsAvailable()) or S.Flagellation:IsReady())
      and S.SecretTechnique:CooldownRemains() <= 8 or not S.DeathPerception:IsAvailable()) or HL.BossFilteredFightRemains("<=", 15)) then
      if Cast(S.SymbolsofDeath, Settings.Subtlety.OffGCDasOffGCD.SymbolsofDeath) then
        return "Cast Symbols of Death"
      end
    end
  end

  -- actions.cds+=/shadow_blades,if=variable.maintenance&variable.shd_cp&buff.shadow_dance.up&!buff.premeditation.up
  if HR.CDsON() and S.ShadowBlades:IsReady() then
    if Maintenance and ShdCp and Player:BuffUp(S.ShadowDanceBuff) and not Player:BuffUp(S.PremeditationBuff)
      and (Player:BuffUp(S.FlagellationBuff) or Player:BuffUp(S.FlagellationPersistBuff)) then
      if Cast(S.ShadowBlades, Settings.Subtlety.OffGCDasOffGCD.ShadowBlades) then
        return "Cast Shadow Blades"
      end
    end
  end

  -- actions.cds+=/thistle_tea,if=buff.shadow_dance.remains>2&!buff.thistle_tea.up
  if S.ThistleTea:IsReady() then
    if Player:BuffRemains(S.ShadowDanceBuff) > 2 and Player:BuffDown(S.ThistleTea) then
      if Cast(S.ThistleTea, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
        return "Thistle Tea";
      end
    end
  end

  -- actions.cds+=/flagellation,if=combo_points>=5|fight_remains<=25
  if HR.CDsON() and S.Flagellation:IsAvailable() and S.Flagellation:IsReady()
    and (S.ShadowDance:IsReady() or Player:BuffUp(S.ShadowDanceBuff))
    and (S.SymbolsofDeath:IsReady() or Player:BuffUp(S.SymbolsofDeath))
    and (S.ShadowBlades:IsReady() or Player:BuffUp(S.ShadowBlades) or S.ShadowBlades:CooldownRemains() <=3) then
    if ComboPoints >= 5
      or HL.BossFilteredFightRemains("<=", 25) then
      if Cast(S.Flagellation, nil, Settings.CommonsDS.DisplayStyle.Flagellation, not Target:IsSpellInRange(S.Flagellation)) then
        return "Cast Flagellation"
      end
    end
  end

  return false
end

local function Race()
  -- actions.cds+=/blood_fury,if=variable.racial_sync
  if S.BloodFury:IsCastable() and RacialSync then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Blood Fury"
    end
  end

  -- actions.cds+=/berserking,if=variable.racial_sync
  if S.Berserking:IsCastable() and RacialSync then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Berserking"
    end
  end

  -- actions.race+=/fireblood,if=variable.racial_sync&buff.shadow_dance.up
  if S.Fireblood:IsCastable() and RacialSync and Player:BuffUp(S.ShadowDanceBuff) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Fireblood"
    end
  end

  -- actions.cds+=/ancestral_call,if=variable.racial_sync
  if S.AncestralCall:IsCastable() and RacialSync then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Ancestral Call"
    end
  end
end

-- # Items
local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- actions.items=use_item,name=treacherous_transmitter,if=cooldown.flagellation.remains<=2|fight_remains<=15
    if I.TreacherousTransmitter:IsEquippedAndReady() then
      if S.Flagellation:CooldownRemains() <= 2 or S.Flagellation:IsReady() or Player:BuffUp(S.FlagellationBuff) or Player:BuffUp(S.FlagellationPersistBuff)
      or HL.BossFilteredFightRemains("<=", 15) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
          return "Treacherous Transmitter"
        end
      end
    end

    -- actions.items+=/use_item,name=imperfect_ascendancy_serum,use_off_gcd=1,if=dot.rupture.ticking&buff.flagellation_buff.up
    if I.ImperfectAscendancySerum:IsEquippedAndReady() then
      if Target:DebuffUp(S.Rupture) and Player:BuffUp(S.Flagellation) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then
          return "Imperfect Ascendancy Serum"
        end
      end
    end

    -- actions.items+=/use_item,name=mad_queens_mandate,if=(!talent.lingering_darkness|buff.lingering_darkness.up
    -- |equipped.treacherous_transmitter)&(!equipped.treacherous_transmitter
    -- |trinket.treacherous_transmitter.cooldown.remains>20)|fight_remains<=15
    if I.MadQueensMandate:IsEquippedAndReady() then
      if (not S.LingeringDarkness:IsAvailable() or Player:BuffUp(S.LingeringDarknessBuff) or I.TreacherousTransmitter:IsEquipped())
        and (not I.TreacherousTransmitter:IsEquipped() or I.TreacherousTransmitter:CooldownRemains() > 20) or HL.BossFilteredFightRemains("<=", 15) then
        if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then
          return "Mad Queens Mandate"
        end
      end
    end

    local TrinketSpell
    local TrinketRange = 100
    -- actions.item+=/use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.shadow_blades.up
      -- |fight_remains<=20)|(variable.trinket_sync_slot=2&(!trinket.2.cooldown.ready&cooldown.shadow_blades.remains>20))
      -- |!variable.trinket_sync_slot)
    if trinket1 then
      TrinketSpell = trinket1:OnUseSpell()
      TrinketRange = (TrinketSpell and TrinketSpell.MaximumRange > 0 and TrinketSpell.MaximumRange <= 100) and TrinketSpell.MaximumRange or 100
    end
    if trinket1 and trinket1:IsEquippedAndReady() and not Player:IsItemBlacklisted(trinket1) then
      if not ValueIsInArray(OnUseExcludes, trinket1:ID()) and (Trinket_Sync_Slot() == 1 and (Player:BuffUp(S.ShadowBlades)
        or HL.BossFilteredFightRemains("<=", 20)) or (Trinket_Sync_Slot() == 2 and (not trinket2:IsReady()
        and S.ShadowBlades:CooldownRemains() > 20)) or Trinket_Sync_Slot() == 0) then
        if Cast(trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(TrinketRange)) then
          return "Generic use_items for " .. trinket1:Name()
        end
      end
    end

    -- actions.item+=/use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.shadow_blades.up
    -- |fight_remains<=20)|(variable.trinket_sync_slot=1&(!trinket.1.cooldown.ready&cooldown.shadow_blades.remains>20))
    -- |!variable.trinket_sync_slot)
    if trinket2 then
      TrinketSpell = trinket2:OnUseSpell()
      TrinketRange = (TrinketSpell and TrinketSpell.MaximumRange > 0 and TrinketSpell.MaximumRange <= 100) and TrinketSpell.MaximumRange or 100
    end
    if trinket2 and trinket2:IsEquippedAndReady() and not Player:IsItemBlacklisted(trinket2) then
      if not ValueIsInArray(OnUseExcludes, trinket2:ID()) and (Trinket_Sync_Slot() == 2 and (Player:BuffUp(S.ShadowBlades)
        or HL.BossFilteredFightRemains("<=", 20)) or (Trinket_Sync_Slot() == 1 and (not trinket1:IsReady()
        and S.ShadowBlades:CooldownRemains() > 20)) or Trinket_Sync_Slot() == 0) then
        if Cast(trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(TrinketRange)) then
          return "Generic use_items for " .. trinket2:Name()
        end
      end
    end
  end

  return false
end

-- # Stealth Cooldowns
local function Stealth_CDs ()
  if HR.CDsON() and not (Everyone.IsSoloMode() and Player:IsTanking(Target)) then
    -- actions.stealth_cds=shadow_dance,if=variable.shd_cp&variable.maintenance&cooldown.secret_technique.remains<=24
    -- &(buff.symbols_of_death.remains>=6|buff.shadow_blades.remains>=6)|fight_remains<=10
    if S.ShadowDance:IsReady() then
      if ShdCp and Maintenance and S.SecretTechnique:CooldownRemains() <= 24 and (Player:BuffRemains(S.SymbolsofDeath) >= 6
        or Player:BuffRemains(S.ShadowBlades) >= 6) or HL.BossFilteredFightRemains("<=", 10) then
        ShouldReturn = StealthMacro(S.ShadowDance)
        if ShouldReturn then
          return "Shadow Dance Macro " .. ShouldReturn
        end
      end
    end

    --actions.stealth_cds+=/vanish,if=energy>=40&!buff.subterfuge.up&effective_combo_points<=3
    if S.Vanish:IsReady() then
      if Player:Energy() >= 40 and not Player:BuffUp(S.Subterfuge) and EffectiveComboPoints <= 3 then
        ShouldReturn = StealthMacro(S.Vanish)
        if ShouldReturn then
          return "Vanish Macro " .. ShouldReturn
        end
      end
    end

    --actions.stealth_cds+=/shadowmeld,if=energy>=40&combo_points.deficit>=3
    if Settings.Commons.ShowPooling and S.Shadowmeld:IsReady() and Player:Energy() >= 40 and ComboPointsDeficit >= 3 then
      ShouldReturn = StealthMacro(S.Shadowmeld)
      if ShouldReturn then
        return "Shadowmeld Macro " .. ShouldReturn
      end
      return false
    end
  end
end

local function Fill()
  if HR.CDsON() then
    -- # This list usually contains Cooldowns with neglectable impact that causes global cooldowns
    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsReady() and Player:EnergyDeficitPredicted() >= 15 + Player:EnergyRegen() then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.GCDasOffGCD.Racials) then
        return "Cast Arcane Torrent"
      end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsReady() then
      if Cast(S.ArcanePulse, Settings.CommonsOGCD.GCDasOffGCD.Racials) then
        return "Cast Arcane Pulse"
      end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsReady() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.GCDasOffGCD.Racials) then
        return "Cast Lights Judgment"
      end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsReady() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.GCDasOffGCD.Racials) then
        return "Cast Bag of Tricks"
      end
    end
  end
end

local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function()
    return true
  end },
  { S.KidneyShot, "Cast Kidney Shot (Interrupt)", function()
    return ComboPoints > 0
  end },
  { S.CheapShot, "Cast Cheap Shot (Interrupt)", function()
    return Player:StealthUp(true, true)
  end }
}

-- APL Main
local function APL ()
  -- Reset pooling cache
  PoolingAbility = nil
  PoolingFinisher = nil
  PoolingEnergy = 0

  -- Unit Update
  MeleeRange = 5
  AoERange = 10
  TargetInAoERange = Target:IsInMeleeRange(AoERange)
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(AoERange) -- Shuriken Storm & Black Powder
    MeleeEnemies10yCount = #MeleeEnemies10y
    MeleeEnemies5y = Player:GetEnemiesInMeleeRange(MeleeRange) -- Melee cycle
  else
    Enemies30y = {}
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 1
    MeleeEnemies5y = {}
  end

  -- Cache updates
  ComboPoints = Player:ComboPoints()
  EffectiveComboPoints = Rogue.EffectiveComboPoints(ComboPoints)
  ComboPointsDeficit = Player:ComboPointsDeficit()
  PriorityRotation = UsePriorityRotation()

  Stealth = Player:StealthUp(true, false)

  -- actions+=/variable,name=skip_rupture,value=buff.shadow_dance.up|buff.darkest_night.up|variable.targets>=8
    -- &!talent.replicating_shadows&talent.unseen_blade
  SkipRupture = Player:BuffUp(S.ShadowDanceBuff) or Player:BuffUp(S.DarkestNightBuff)
    or MeleeEnemies10yCount >= 8 and not S.ReplicatingShadows:IsAvailable() and S.UnseenBlade:IsAvailable()

  -- actions+=/variable,name=maintenance,value=(dot.rupture.ticking|variable.skip_rupture)&(buff.slice_and_dice.up|variable.targets<=2)
  Maintenance = (Target:DebuffUp(S.Rupture) or SkipRupture) and (Player:BuffUp(S.SliceandDice) or MeleeEnemies10yCount <= 2)

  -- actions+=/variable,name=secret,value=buff.shadow_dance.up|(cooldown.flagellation.remains<40&cooldown.flagellation.remains>20&talent.death_perception)
  Secret = Player:BuffUp(S.ShadowDanceBuff) or (S.Flagellation:CooldownRemains() < 40 and S.Flagellation:CooldownRemains() > 20 and S.DeathPerception:IsAvailable())

  -- actions+=/variable,name=racial_sync,value=(buff.shadow_blades.up&buff.shadow_dance.up)|!talent.shadow_blades&buff.symbols_of_death.up|fight_remains<20
  RacialSync = (Player:BuffUp(S.ShadowBlades) and Player:BuffUp(S.ShadowDanceBuff)) or not S.ShadowBlades:IsAvailable() and Player:BuffUp(S.SymbolsofDeath) or HL.BossFilteredFightRemains("<", 20)

  -- actions+=/variable,name=shd_cp,value=combo_points<=1|buff.darkest_night.up&combo_points>=7|effective_combo_points>=6&talent.unseen_blade
  ShdCp = ComboPoints <= 1 or Player:BuffUp(S.DarkestNightBuff) and ComboPoints >= 7 or EffectiveComboPoints >= 6 and S.UnseenBlade:IsAvailable()

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
  RuptureDMGThreshold = S.Eviscerate:Damage() * Settings.Subtlety.EviscerateDMGOffset; -- Used to check if Rupture is worth to be casted since it's a finisher.

  --- Defensives
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
      return "Bottle Of Flayedwing Toxin";
    end
  end

  -- Shadowstep if out of range
  if S.Shadowstep:IsCastable() and not Target:IsInMeleeRange(MeleeRange) and Target:Exists() then
    if Cast(S.Shadowstep, nil, Settings.CommonsDS.DisplayStyle.Shadowstep, not Target:IsSpellInRange(S.Shadowstep)) then
      return "Cast Shadowstep"
    end
  end

  --- Out of Combat
  if not Player:AffectingCombat() then
    -- Stealth
    -- Note: Since 7.2.5, Blizzard disallowed Stealth cast under ShD (workaround to prevent the Extended Stealth bug)
    if not Player:BuffUp(S.ShadowDanceBuff) and not Player:BuffUp(Rogue.VanishBuffSpell()) then
      ShouldReturn = Rogue.Stealth(Rogue.StealthSpell())
      if ShouldReturn then
        return ShouldReturn
      end
    end

    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() and (Target:IsSpellInRange(S.Shadowstrike)) then
      if ComboPoints >= 5 then
        ShouldReturn = Finish()
        if ShouldReturn then
          return ShouldReturn .. " (OOC)"
        end
      else
        ShouldReturn = Build()
        if ShouldReturn then
          return ShouldReturn .. " (OOC)"
        end
      end
    end
    return
  end

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(S.Kick, Settings.CommonsDS.DisplayStyle.Interrupts, Interrupts)
    if ShouldReturn then
      return ShouldReturn
    end

    -- # Check CDs at first
    -- actions=call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then
      return "CDs: " .. ShouldReturn
    end

    -- # Racials
    --actions+=/call_action_list,name=race
    ShouldReturn = Race()
    if ShouldReturn then
      return "Racials: " .. ShouldReturn
    end

    -- # Items (Trinkets)
    -- actions+=/call_action_list,name=items
    ShouldReturn = Items()
    if ShouldReturn then
      return "Items: " .. ShouldReturn
    end

    -- # Cooldowns for Stealth
    -- actions+=/call_action_list,name=stealth_cds,if=!variable.stealth
    if not Player:StealthUp(true, false) then
      ShouldReturn = Stealth_CDs()
      if ShouldReturn then
        return "Stealth CDs: " .. ShouldReturn
      end
    end

    -- # Finishing Rules
    -- actions+=/call_action_list,name=finish,if=!buff.darkest_night.up&effective_combo_points>=6|buff.darkest_night.up&combo_points==cp_max_spend
    if not Player:BuffUp(S.DarkestNightBuff) and EffectiveComboPoints >= 6 or Player:BuffUp(S.DarkestNightBuff) and ComboPoints == Rogue.CPMaxSpend() then
      ShouldReturn = Finish()
      if ShouldReturn then
        return "Finish: " .. ShouldReturn
      end
    end

    -- # Combo Point Builder
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build()
    if ShouldReturn then
      return "Build: " .. ShouldReturn
    end

    -- # Filler, Spells used if you can use nothing else.
    --actions+=/call_action_list,name=fill,if=!variable.stealth
    if not Stealth then
      ShouldReturn = Fill()
      if ShouldReturn then
        return "Fill: " .. ShouldReturn
      end
    end

    -- Shuriken Toss Out of Range
    if S.ShurikenToss:IsCastable() and Target:IsInRange(30) and not TargetInAoERange and not Player:StealthUp(true, true) and not Player:BuffUp(S.Sprint)
      and Player:EnergyDeficitPredicted() < 20 and (ComboPointsDeficit >= 1 or Player:EnergyTimeToMax() <= 1.2) then
      if CastPooling(S.ShurikenToss) then
        return "Cast Shuriken Toss"
      end
    end
  end
end

local function Init ()
  S.Rupture:RegisterAuraTracking()

  HR.Print("Subtlety Rogue rotation has been updated for patch 11.1.0.")
end

HR.SetAPL(261, APL, Init)
