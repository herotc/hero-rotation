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
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua
local mathmin = math.min
local mathabs = math.abs


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
  Outlaw = HR.GUISettings.APL.Rogue.Outlaw,
}

-- Define S/I for spell and item arrays
local S = Spell.Rogue.Outlaw
local I = Item.Rogue.Outlaw

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ComputationDevice:ID(),
  I.VigorTrinket:ID(),
  I.FontOfPower:ID(),
  I.RazorCoral:ID()
}

S.Dispatch:RegisterDamageFormula(
  -- Dispatch DMG Formula (Pre-Mitigation):
  --- Player Modifier
    -- AP * CP * EviscR1_APCoef * Aura_M * NS_M * DS_M * DSh_M * SoD_M * Finality_M * Mastery_M * Versa_M
  --- Target Modifier
    -- Ghostly_M * Sinful_M
  function ()
    return
      --- Player Modifier
        -- Attack Power
        Player:AttackPowerDamageMod() *
        -- Combo Points
        Rogue.CPSpend() *
        -- Eviscerate R1 AP Coef
        0.35 *
        -- Aura Multiplier (SpellID: 137036)
        1.13 *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
        -- Ghostly Strike Multiplier
        (Target:DebuffUp(S.GhostlyStrike) and 1.1 or 1) *
        -- Sinful Revelation Enchant
        (Target:DebuffUp(S.SinfulRevelationDebuff) and 1.06 or 1)
  end
)

-- Rotation Var
local Enemies30y, EnemiesBF, EnemiesBFCount
local ShouldReturn; -- Used to get the return string
local BladeFlurryRange = 6
local BetweenTheEyesDMGThreshold
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function () return true end },
}

-- Legendaries
local TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
local MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)

HL:RegisterForEvent(function()
  TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
  MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Utils
local function num(val)
  if val then return 1 else return 0 end
end

-- Stable Energy Prediction
local PrevEnergyTimeToMaxPredicted, PrevEnergyPredicted = 0, 0
local function EnergyTimeToMaxStable ()
  local EnergyTimeToMaxPredicted = Player:EnergyTimeToMaxPredicted()
  if mathabs(PrevEnergyTimeToMaxPredicted - EnergyTimeToMaxPredicted) > 1 then
    PrevEnergyTimeToMaxPredicted = EnergyTimeToMaxPredicted
  end
  return PrevEnergyTimeToMaxPredicted
end
local function EnergyPredictedStable ()
  local EnergyPredicted = Player:EnergyPredicted()
  if mathabs(PrevEnergyPredicted - EnergyPredicted) > 9 then
    PrevEnergyPredicted = EnergyPredicted
  end
  return PrevEnergyPredicted
end

-- Marked for Death Cycle Targets
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
local function EvaluateMfDTargetIfConditionCondition(TargetUnit)
  return TargetUnit:TimeToDie()
end
local function EvaluateMfDCondition(TargetUnit)
  -- Note: Increased the SimC condition by 50% since we are slower.
  return TargetUnit:FilteredTimeToDie("<", Player:ComboPointsDeficit()*1.5) or (not Player:StealthUp(true, false) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1)
end

--- ======= ACTION LISTS =======
local RtB_BuffsList = {
  S.Broadside,
  S.BuriedTreasure,
  S.GrandMelee,
  S.RuthlessPrecision,
  S.SkullandCrossbones,
  S.TrueBearing
}
local function RtB_List (Type, List)
  if not Cache.APLVar.RtB_List then Cache.APLVar.RtB_List = {} end
  if not Cache.APLVar.RtB_List[Type] then Cache.APLVar.RtB_List[Type] = {} end
  local Sequence = table.concat(List)
  -- All
  if Type == "All" then
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      local Count = 0
      for i = 1, #List do
        if Player:BuffUp(RtB_BuffsList[List[i]]) then
          Count = Count + 1
        end
      end
      Cache.APLVar.RtB_List[Type][Sequence] = Count == #List and true or false
    end
  -- Any
  else
    if not Cache.APLVar.RtB_List[Type][Sequence] then
      Cache.APLVar.RtB_List[Type][Sequence] = false
      for i = 1, #List do
        if Player:BuffUp(RtB_BuffsList[List[i]]) then
          Cache.APLVar.RtB_List[Type][Sequence] = true
          break
        end
      end
    end
  end
  return Cache.APLVar.RtB_List[Type][Sequence]
end
-- Get the number of Roll the Bones buffs currently on
local function RtB_Buffs ()
  if not Cache.APLVar.RtB_Buffs then
    Cache.APLVar.RtB_Buffs = 0
    for i = 1, #RtB_BuffsList do
      if Player:BuffUp(RtB_BuffsList[i]) then
        Cache.APLVar.RtB_Buffs = Cache.APLVar.RtB_Buffs + 1
      end
    end
  end
  return Cache.APLVar.RtB_Buffs
end
-- RtB rerolling strategy, return true if we should reroll
local function RtB_Reroll ()
  if not Cache.APLVar.RtB_Reroll then
    -- 1+ Buff
    if Settings.Outlaw.RolltheBonesLogic == "1+ Buff" then
      Cache.APLVar.RtB_Reroll = (RtB_Buffs() <= 0) and true or false
    -- Broadside
    elseif Settings.Outlaw.RolltheBonesLogic == "Broadside" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.Broadside)) and true or false
    -- Buried Treasure
    elseif Settings.Outlaw.RolltheBonesLogic == "Buried Treasure" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.BuriedTreasure)) and true or false
    -- Grand Melee
    elseif Settings.Outlaw.RolltheBonesLogic == "Grand Melee" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.GrandMelee)) and true or false
    -- Skull and Crossbones
    elseif Settings.Outlaw.RolltheBonesLogic == "Skull and Crossbones" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.SkullandCrossbones)) and true or false
    -- Ruthless Precision
    elseif Settings.Outlaw.RolltheBonesLogic == "Ruthless Precision" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.RuthlessPrecision)) and true or false
    -- True Bearing
    elseif Settings.Outlaw.RolltheBonesLogic == "True Bearing" then
      Cache.APLVar.RtB_Reroll = (not Player:BuffUp(S.TrueBearing)) and true or false
    -- SimC Default
    else
      -- # Reroll single buffs early other than True Bearing and Broadside
      -- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(!buff.true_bearing.up&!buff.broadside.up)
      Cache.APLVar.RtB_Reroll = (RtB_Buffs() < 2 and (not Player:BuffUp(S.TrueBearing) and not Player:BuffUp(S.Broadside))) and true or false
    end

    -- Defensive Override : Grand Melee if HP < 60
    if Everyone.IsSoloMode() then
      if Player:BuffUp(S.GrandMelee) then
        if Player:IsTanking(Target) or Player:HealthPercentage() < mathmin(Settings.Outlaw.RolltheBonesLeechKeepHP, Settings.Outlaw.RolltheBonesLeechRerollHP) then
          Cache.APLVar.RtB_Reroll = false
        end
      elseif Player:HealthPercentage() < Settings.Outlaw.RolltheBonesLeechRerollHP then
        Cache.APLVar.RtB_Reroll = true
      end
    end
  end

  return Cache.APLVar.RtB_Reroll
end

-- # Finish at maximum CP but avoid wasting Broadside and Quick Draw bonus combo points
local function Finish_Condition ()
  -- actions+=/variable,name=finish_condition,value=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*talent.quick_draw.enabled)|combo_points=animacharged_cp
  return Player:ComboPoints() >= (Rogue.CPMaxSpend() - num(Player:BuffUp(S.Broadside)) - (num(Player:BuffUp(S.Opportunity)) * num(S.QuickDraw:IsAvailable())))
    or Player:ComboPoints() == Rogue.AnimachargedCP()
end

-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50&(!conduit.count_the_odds|buff.roll_the_bones.remains>=10)
  return Player:ComboPointsDeficit() >= 2 + num(Player:BuffUp(S.Broadside)) and EnergyPredictedStable() > 50
    and (not S.CountTheOdds:ConduitEnabled() or Rogue.RtBRemains() > 10)
end
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>1+talent.killing_spree.enabled
local function Blade_Flurry_Sync ()
  return not AoEON() or EnemiesBFCount < 2 or (Player:BuffRemains(S.BladeFlurry) > 1 + num(S.KillingSpree:IsAvailable()))
end

-- Determine if we are allowed to use Vanish offensively in the current situation
local function Vanish_DPS_Condition()
  return Settings.Outlaw.UseDPSVanish and CDsON() and not (Everyone.IsSoloMode() and Player:IsTanking(Target))
end

local function CDs ()
  -- actions.cds+=/blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
  if S.BladeFlurry:IsReady() and AoEON() and EnemiesBFCount >= 2 and not Player:BuffUp(S.BladeFlurry) then
    if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
      HR.CastSuggested(S.BladeFlurry)
    else
      if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
    end
  end
  if Target:IsSpellInRange(S.SinisterStrike) then
    -- # Using Ambush is a 2% increase, so Vanish can be sometimes be used as a utility spell unless using Master Assassin or Deathly Shadows
    if S.Vanish:IsCastable() and Vanish_DPS_Condition() and not Player:StealthUp(true, true) then
      if not MarkoftheMasterAssassinEquipped then
        -- actions.cds+=/vanish,if=!runeforge.mark_of_the_master_assassin&!stealthed.all&variable.ambush_condition&(!runeforge.deathly_shadows|buff.deathly_shadows.down&combo_points<=2)
        if Ambush_Condition() and not Player:BuffUp(S.DeathlyShadowsBuff)
        and (not Settings.Outlaw.Enabled.VanishEchoingReprimand or not S.EchoingReprimand:IsAvailable() -- Note: Vanish / ER sync for ER FW Bug
          or S.EchoingReprimand:CooldownUp() or S.EchoingReprimand:CooldownRemains() >= 35) then
            if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish" end
        end
      else
        -- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&!talent.marked_for_death.enabled,value=(!cooldown.between_the_eyes.ready&variable.finish_condition)|(cooldown.between_the_eyes.ready&variable.ambush_condition)
        -- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&talent.marked_for_death.enabled,value=variable.finish_condition
        -- actions.cds+=/vanish,if=variable.vanish_ma_condition&master_assassin_remains=0&variable.blade_flurry_sync
        if Rogue.MasterAssassinsMarkRemains() <= 0 and Blade_Flurry_Sync() then
          if S.MarkedforDeath:IsAvailable() then
            if Finish_Condition() then
              if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (MA+MfD)" end
            end
          else
            if (not S.BetweentheEyes:CooldownUp() and Finish_Condition() or S.BetweentheEyes:CooldownUp() and Ambush_Condition()) then
              if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (MA)" end
            end
          end
        end
      end
    end
    -- actions.cds+=/flagellation
    if CDsON() and S.Flagellation:IsReady() and not Target:DebuffUp(S.Flagellation) then
      if HR.Cast(S.Flagellation, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flagellation" end
    end
    -- actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2
    if S.FlagellationCleanse:IsReady() and Target:DebuffUp(S.Flagellation) and Target:DebuffRemains(S.Flagellation) < 2 then
      if HR.Cast(S.FlagellationCleanse, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flagellation Cleanse" end
    end
    -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up
    if CDsON() and S.AdrenalineRush:IsCastable() and not Player:BuffUp(S.AdrenalineRush) then
      if HR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
    end
    -- actions.cds+=/roll_the_bones,if=master_assassin_remains=0&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
    if S.RolltheBones:IsReady() and Rogue.MasterAssassinsMarkRemains() <= 0 and (Rogue.RtBRemains() <= 3 or RtB_Reroll()) then
      if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones" end
    end
  end
  if Blade_Flurry_Sync() then
    -- # Attempt to sync Killing Spree with Vanish for Master Assassin
    -- actions.cds+=/variable,name=killing_spree_vanish_sync,value=!runeforge.mark_of_the_master_assassin|cooldown.vanish.remains>10|master_assassin_remains>2
    -- # Use in 1-2T if BtE is up and won't cap Energy, or at 3T+ (2T+ with Deathly Shadows) or when Master Assassin is up.
    -- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&variable.killing_spree_vanish_sync&!stealthed.rogue&(debuff.between_the_eyes.up&energy.deficit>(energy.regen*2+15)|spell_targets.blade_flurry>(2-buff.deathly_shadows.up)|master_assassin_remains>0)
    if CDsON() and S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and not Player:StealthUp(true, false)
        and (not MarkoftheMasterAssassinEquipped or S.Vanish:CooldownRemains() > 10 or Rogue.MasterAssassinsMarkRemains() > 2 or not Vanish_DPS_Condition())
        and (Target:DebuffUp(S.BetweentheEyes) and Player:EnergyDeficitPredicted() > (Player:EnergyRegen() * 2 + 10)
          or EnemiesBFCount > (2 - num(Player:BuffUp(S.DeathlyShadowsBuff))) or Rogue.MasterAssassinsMarkRemains() > 0) then
      if HR.Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle) then return "Cast Killing Spree" end
    end
      -- blade_rush,if=variable.blade_flurry_sync&(energy.time_to_max>2|spell_targets>2)
      if S.BladeRush:IsCastable() and Target:IsSpellInRange(S.BladeRush) and (EnergyTimeToMaxStable() > 2 or EnemiesBFCount > 2) then
      if HR.Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
    end
  end
  if Target:IsSpellInRange(S.SinisterStrike) then
    if CDsON() then
      -- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
      if Settings.Outlaw.UseDPSVanish and S.Shadowmeld:IsCastable() and Ambush_Condition() then
        if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
      end
      -- actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=1
      if S.Dreadblades:IsReady() and Target:IsSpellInRange(S.Dreadblades) and not Player:StealthUp(true, true) and Player:ComboPoints() < 2 then
        if HR.Cast(S.Dreadblades, Settings.Outlaw.GCDasOffGCD.Dreadblades) then return "Cast Dreadblades" end
      end

      -- actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up

      -- Trinkets
      if Settings.Commons.UseTrinkets then
        -- actions.cds+=/use_items,slots=trinket1,if=!runeforge.mark_of_the_master_assassin&debuff.between_the_eyes.up&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)|master_assassin_remains>0|trinket.1.has_stat.any_dps|fight_remains<=20
        -- actions.cds+=/use_items,slots=trinket2,if=!runeforge.mark_of_the_master_assassin&debuff.between_the_eyes.up&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)|master_assassin_remains>0|trinket.2.has_stat.any_dps|fight_remains<=20
        -- TODO: Need trinket.X.has_stat.any_dps DBC support
        local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
        if TrinketToUse and (HL.BossFilteredFightRemains("<", 20) or Rogue.MasterAssassinsMarkRemains() > 0
          or (not MarkoftheMasterAssassinEquipped and Target:DebuffUp(S.BetweentheEyes) and (not S.GhostlyStrike:IsAvailable() or Target:DebuffUp(S.GhostlyStrike)))) then
          if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
      end
    end

    -- Racials
      -- actions.cds+=/blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
      end
      -- actions.cds+=/berserking
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
      end
      -- actions.cds+=/fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
      end
      -- actions.cds+=/ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
      end
    end
  end
end

local function Stealth ()
  -- ER FW Bug
  if Settings.Outlaw.Enabled.VanishEchoingReprimand and CDsON() and S.EchoingReprimand:IsReady() and Target:IsSpellInRange(S.EchoingReprimand) then
    if HR.Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand" end
  end
  -- actions.stealth=dispatch,if=variable.finish_condition
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
    -- actions.stealth=ambush
  if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
  end
end

local function Finish ()
  -- actions.finish=slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable
  -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
  if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + Player:ComboPoints()) * 1.8 then
    if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice" end
  end
  -- # BtE on cooldown to keep the Crit debuff up, unless the target is about to die
  -- actions.finish+=/between_the_eyes,if=target.time_to_die>3
  -- Note: Increased threshold to 4s to account for player reaction time
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes)
    and (Target:FilteredTimeToDie(">", 4) or Target:TimeToDieIsNotValid()) and Rogue.CanDoTUnit(Target, BetweenTheEyesDMGThreshold) then
    if HR.CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
  end
  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
end

local function Build ()
  -- actions.build=sepsis
  if CDsON() and S.Sepsis:IsReady() and Target:IsSpellInRange(S.Sepsis) and Rogue.MasterAssassinsMarkRemains() <= 0 then
    if HR.Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis" end
  end
  -- actions.build+=/ghostly_strike
  if S.GhostlyStrike:IsReady() and Target:IsSpellInRange(S.GhostlyStrike) then
    if HR.Cast(S.GhostlyStrike, Settings.Outlaw.GCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
  end
  -- actions.build=shiv,if=runeforge.tiny_toxic_blade.equipped
  if S.Shiv:IsReady() and TinyToxicBladeEquipped then
    if HR.Cast(S.Shiv) then return "Cast Shiv (TTB)" end
  end
  -- actions.build+=/echoing_reprimand
  if CDsON() and S.EchoingReprimand:IsReady() and (not Settings.Outlaw.Enabled.VanishEchoingReprimand or not Settings.Outlaw.UseDPSVanish or S.Vanish:CooldownRemains() >= 100 or Player:IsTanking(Target)) and Target:IsSpellInRange(S.EchoingReprimand) then
    if HR.Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand" end
  end
  -- actions.build+=/serrated_bone_spike,cycle_targets=1,if=buff.slice_and_dice.up&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75
  if S.SerratedBoneSpike:IsReady() then
    if (Player:BuffUp(S.SliceandDice) and not Target:DebuffUp(S.SerratedBoneSpikeDebuff)) or HL.BossFilteredFightRemains("<", 5) then
      if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike" end
    end
    if AoEON() then
      -- Prefer melee cycle units
      local BestUnit, BestUnitTTD = nil, 4
      local TargetGUID = Target:GUID()
      for _, CycleUnit in pairs(Enemies30y) do
        if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemains(S.SerratedBoneSpike))
        and not CycleUnit:DebuffUp(S.SerratedBoneSpikeDebuff) then
          BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie()
        end
      end
      if BestUnit then
        HR.CastLeftNameplate(BestUnit, S.SerratedBoneSpike)
      end
    end
    if S.SerratedBoneSpike:ChargesFractional() > 2.75 then
      if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike Filler" end
    end
  end
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and Player:BuffUp(S.Opportunity) then
    -- actions.build+=/pistol_shot,if=buff.opportunity.up&(energy.deficit>(energy.regen+10)|combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled)
    if Player:EnergyDeficitPredicted() > (Player:EnergyRegen() + 10) or Player:ComboPointsDeficit() <= 1 + num(Player:BuffUp(S.Broadside)) or S.QuickDraw:IsAvailable() then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
    end
    -- actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up)
    if Player:BuffUp(S.GreenskinsWickers) or Player:BuffUp(S.ConcealedBlunderbuss) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (Buffed)" end
    end
  end
  -- actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
    if HR.CastPooling(S.SinisterStrike) then return "Cast Sinister Strike" end
  end
  -- actions.build+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1+buff.broadside.up
  -- TODO
end

--- ======= MAIN =======
local function APL ()
  -- Local Update
  BladeFlurryRange = S.AcrobaticStrikes:IsAvailable() and 9 or 6
  BetweenTheEyesDMGThreshold = S.Dispatch:Damage() * 1.25

  -- Unit Update
  if AoEON() then
    Enemies30y = Player:GetEnemiesInRange(30) -- Serrated Bone Spike cycle
    EnemiesBF = Player:GetEnemiesInRange(BladeFlurryRange)
    EnemiesBFCount = #EnemiesBF
  else
    EnemiesBFCount = 1
  end

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
    -- Stealth
    if not Player:BuffUp(S.VanishBuff) then
      ShouldReturn = Rogue.Stealth(S.Stealth)
      if ShouldReturn then return ShouldReturn end
    end
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then
      -- Precombat CDs
      -- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>25
      if CDsON() and S.MarkedforDeath:IsCastable() and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
        if Settings.Commons.STMfDAsDPSCD then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        else
          if HR.CastSuggested(S.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=2
      if S.RolltheBones:IsReady() and (Rogue.RtBRemains() <= 3 or RtB_Reroll()) then
        if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones (Opener)" end
      end
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if S.SliceandDice:IsReady() and Player:BuffRemains(S.SliceandDice) < (1 + Player:ComboPoints()) * 1.8 then
        if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice (Opener)" end
      end
      if Player:StealthUp(true, true) then
        ShouldReturn = Stealth()
        if ShouldReturn then return "Stealth (Opener): " .. ShouldReturn end
      elseif Finish_Condition() then
        ShouldReturn = Finish()
        if ShouldReturn then return "Finish (Opener): " .. ShouldReturn end
      elseif S.SinisterStrike:IsCastable() then
        if HR.Cast(S.SinisterStrike) then return "Cast Sinister Strike (Opener)" end
      end
    end
    return
  end

  -- In Combat
  -- MfD Sniping (Higher Priority than APL)
  -- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=target.time_to_die<combo_points.deficit|((raid_event.adds.in>40|buff.true_bearing.remains>15-buff.adrenaline_rush.up*5)&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
  -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1
  if S.MarkedforDeath:IsCastable() then
    if EnemiesBFCount > 1 and Everyone.CastTargetIf(S.MarkedforDeath, Enemies30y, "min", EvaluateMfDTargetIfConditionCondition, EvaluateMfDCondition, nil, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then
      return "Cast Marked for Death (Cycle)"
    elseif EnemiesBFCount == 1 and not Player:StealthUp(true, false) and Player:ComboPointsDeficit() >= Rogue.CPMaxSpend() - 1 then
      if Settings.Commons.STMfDAsDPSCD then
        if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (ST)" end
      else
        HR.CastSuggested(S.MarkedforDeath)
      end
    end
  end

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, Settings.Commons2.OffGCDasOffGCD.Kick, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- actions+=/call_action_list,name=stealth,if=stealthed.all
    if Player:StealthUp(true, true) then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth: " .. ShouldReturn end
    end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end
    -- actions+=/run_action_list,name=finish,if=variable.finish_condition
    if Finish_Condition() then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
      -- run_action_list forces the return
      HR.Cast(S.PoolEnergy)
      return "Finish Pooling"
    end
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build()
    if ShouldReturn then return "Build: " .. ShouldReturn end
    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) and Player:EnergyDeficitPredicted() > 15 + Player:EnergyRegen() then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
      if HR.Cast(S.ArcanePulse) then return "Cast Arcane Pulse" end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.LightsJudgment, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Lights Judgment" end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
      if HR.Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
    end
    -- OutofRange Pistol Shot
    if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and not Target:IsInRange(BladeFlurryRange) and not Player:StealthUp(true, true)
      and Player:EnergyDeficitPredicted() < 25 and (Player:ComboPointsDeficit() >= 1 or EnergyTimeToMaxStable() <= 1.2) then
      if HR.Cast(S.PistolShot) then return "Cast Pistol Shot (OOR)" end
    end
  end
end

local function Init ()
end

HR.SetAPL(260, APL, Init)

--- ======= SIMC =======
-- Last Update: 2021-02-15

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>25
-- actions.precombat+=/roll_the_bones,precombat_seconds=2
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/stealth

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- # Reroll single buffs early other than True Bearing and Broadside
-- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(!buff.true_bearing.up&!buff.broadside.up)
-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
-- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50&(!conduit.count_the_odds|buff.roll_the_bones.remains>=10)
-- # Finish at maximum CP but avoid wasting Broadside and Quick Draw bonus combo points
-- actions+=/variable,name=finish_condition,value=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*talent.quick_draw.enabled)|combo_points=animacharged_cp
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>1+talent.killing_spree.enabled
-- actions+=/run_action_list,name=stealth,if=stealthed.all
-- actions+=/call_action_list,name=cds
-- actions+=/run_action_list,name=finish,if=variable.finish_condition
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- actions.build=sepsis
-- actions.build+=/ghostly_strike
-- actions.build+=/shiv,if=runeforge.tiny_toxic_blade
-- actions.build+=/echoing_reprimand
-- actions.build+=/serrated_bone_spike,cycle_targets=1,if=buff.slice_and_dice.up&!dot.serrated_bone_spike_dot.ticking|fight_remains<=5|cooldown.serrated_bone_spike.charges_fractional>=2.75
-- # Use Pistol Shot with Opportunity if Combat Potency won't overcap energy, when it will exactly cap CP, or when using Quick Draw
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(energy.deficit>(energy.regen+10)|combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled)
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up)
-- actions.build+=/sinister_strike
-- actions.build+=/gouge,if=talent.dirty_tricks.enabled&combo_points.deficit>=1+buff.broadside.up

-- # Cooldowns
-- # Blade Flurry on 2+ enemies
-- actions.cds=blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
-- # Using Ambush is a 2% increase, so Vanish can be sometimes be used as a utility spell unless using Master Assassin or Deathly Shadows
-- actions.cds+=/vanish,if=!runeforge.mark_of_the_master_assassin&!stealthed.all&variable.ambush_condition&(!runeforge.deathly_shadows|buff.deathly_shadows.down&combo_points<=2)
-- # With Master Asssassin, sync Vanish with a finisher or Ambush depending on BtE cooldown, or always a finisher with MfD
-- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&!talent.marked_for_death.enabled,value=(!cooldown.between_the_eyes.ready&variable.finish_condition)|(cooldown.between_the_eyes.ready&variable.ambush_condition)
-- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&talent.marked_for_death.enabled,value=variable.finish_condition
-- actions.cds+=/vanish,if=variable.vanish_ma_condition&master_assassin_remains=0&variable.blade_flurry_sync
-- actions.cds+=/flagellation
-- actions.cds+=/flagellation_cleanse,if=debuff.flagellation.remains<2
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up
-- actions.cds+=/roll_the_bones,if=master_assassin_remains=0&(buff.roll_the_bones.remains<=3|variable.rtb_reroll)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1
-- # Attempt to sync Killing Spree with Vanish for Master Assassin
-- actions.cds+=/variable,name=killing_spree_vanish_sync,value=!runeforge.mark_of_the_master_assassin|cooldown.vanish.remains>10|master_assassin_remains>2
-- # Use in 1-2T if BtE is up and won't cap Energy, or at 3T+ (2T+ with Deathly Shadows) or when Master Assassin is up.
-- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&variable.killing_spree_vanish_sync&!stealthed.rogue&(debuff.between_the_eyes.up&energy.deficit>(energy.regen*2+15)|spell_targets.blade_flurry>(2-buff.deathly_shadows.up)|master_assassin_remains>0)
-- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&(energy.time_to_max>2|spell_targets>2)
-- actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=1
-- actions.cds+=/shadowmeld,if=!stealthed.all&variable.ambush_condition
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call
-- # Default conditions for usable items.
-- actions.cds+=/use_items,slots=trinket1,if=!runeforge.mark_of_the_master_assassin&debuff.between_the_eyes.up&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)|master_assassin_remains>0|trinket.1.has_stat.any_dps|fight_remains<=20
-- actions.cds+=/use_items,slots=trinket2,if=!runeforge.mark_of_the_master_assassin&debuff.between_the_eyes.up&(!talent.ghostly_strike.enabled|debuff.ghostly_strike.up)|master_assassin_remains>0|trinket.2.has_stat.any_dps|fight_remains<=20

-- # Finishers
-- actions.finish=slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable
-- # BtE on cooldown to keep the Crit debuff up, unless the target is about to die
-- actions.finish+=/between_the_eyes,if=target.time_to_die>3
-- actions.finish+=/dispatch

-- # Stealth
-- actions.stealth=dispatch,if=variable.finish_condition
-- actions.stealth+=/ambush
