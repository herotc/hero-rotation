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
  I.RazorCoral:ID(),
  I.CacheOfAcquiredTreasures:ID()
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
local EffectiveComboPoints, ComboPoints, ComboPointsDeficit
local Energy, EnergyRegen, EnergyDeficit, EnergyTimeToMax, EnergyMaxOffset
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function () return true end },
}
local VanishMACondition = false

-- Legendaries
local CovenantId = Player:CovenantID()
local IsKyrian, IsVenthyr, IsNightFae, IsNecrolord = (CovenantId == 1), (CovenantId == 2), (CovenantId == 3), (CovenantId == 4)
local DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
local MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
local TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
local ConcealedBlunderbussEquipped = Player:HasLegendaryEquipped(122)
local InvigoratingShadowdustEquipped = Player:HasLegendaryEquipped(114)
local GreenskinsWickersEquipped = Player:HasLegendaryEquipped(125)
HL:RegisterForEvent(function()
  CovenantId = Player:CovenantID()
  IsKyrian, IsVenthyr, IsNightFae, IsNecrolord = (CovenantId == 1), (CovenantId == 2), (CovenantId == 3), (CovenantId == 4)
  DeathlyShadowsEquipped = Player:HasLegendaryEquipped(129)
  MarkoftheMasterAssassinEquipped = Player:HasLegendaryEquipped(117)
  TinyToxicBladeEquipped = Player:HasLegendaryEquipped(116)
  ConcealedBlunderbussEquipped = Player:HasLegendaryEquipped(122)
  InvigoratingShadowdustEquipped = Player:HasLegendaryEquipped(114)
  GreenskinsWickersEquipped = Player:HasLegendaryEquipped(125)
end, "PLAYER_EQUIPMENT_CHANGED", "COVENANT_CHOSEN" )

-- Utils
local function num(val)
  if val then return 1 else return 0 end
end

-- Stable Energy Prediction
local PrevEnergyTimeToMaxPredicted, PrevEnergyPredicted = 0, 0
local function EnergyTimeToMaxStable (MaxOffset)
  local EnergyTimeToMaxPredicted = Player:EnergyTimeToMaxPredicted(nil, MaxOffset)
  if mathabs(PrevEnergyTimeToMaxPredicted - EnergyTimeToMaxPredicted) > 1 then
    PrevEnergyTimeToMaxPredicted = EnergyTimeToMaxPredicted
  end
  return PrevEnergyTimeToMaxPredicted
end
local function EnergyPredictedStable (MaxOffset)
  local EnergyPredicted = Player:EnergyPredicted(nil, MaxOffset)
  if mathabs(PrevEnergyPredicted - EnergyPredicted) > 9 then
    PrevEnergyPredicted = EnergyPredicted
  end
  return PrevEnergyPredicted
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
      -- # Reroll BT + GM or single buffs early other than Broadside, TB with Shadowdust, or SnC with Blunderbuss
      -- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(!buff.broadside.up&(!runeforge.concealed_blunderbuss&!talent.fan_the_hammer|!buff.skull_and_crossbones.up)&(!runeforge.invigorating_shadowdust|!buff.true_bearing.up))|rtb_buffs=2&buff.buried_treasure.up&buff.grand_melee.up
      if RtB_Buffs() == 2 and Player:BuffUp(S.BuriedTreasure) and Player:BuffUp(S.GrandMelee) then
        Cache.APLVar.RtB_Reroll = true
      elseif RtB_Buffs() < 2 and (not Player:BuffUp(S.Broadside) and (not ConcealedBlunderbussEquipped and not S.FanTheHammer:IsAvailable() or not Player:BuffUp(S.SkullandCrossbones))
        and (not InvigoratingShadowdustEquipped or not Player:BuffUp(S.TrueBearing))) then
        Cache.APLVar.RtB_Reroll = true
      else
        Cache.APLVar.RtB_Reroll = false
      end
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

-- # Finish at max possible CP without overflowing bonus combo points, unless for BtE which always should be 5+ CP
-- # Always attempt to use BtE at 5+ CP, regardless of CP gen waste
-- # Finish at 2+ in the last GCD of Flagellation
local function Finish_Condition ()
  --actions+=/variable,name=finish_condition,op=reset,if=cooldown.between_the_eyes.ready&effective_combo_points<5
  if S.BetweentheEyes:CooldownUp() and EffectiveComboPoints < 5 then
    return false
  end
  -- actions+=/variable,name=finish_condition,value=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*(talent.quick_draw|talent.fan_the_hammer)|buff.concealed_blunderbuss.up)|effective_combo_points>=cp_max_spend
  if ComboPoints >= (Rogue.CPMaxSpend() - num(Player:BuffUp(S.Broadside)) - (num(Player:BuffUp(S.Opportunity)) *
    num((S.QuickDraw:IsAvailable() or S.FanTheHammer:IsAvailable()) or Player:BuffUp(S.ConcealedBlunderbuss)))) or EffectiveComboPoints >= Rogue.CPMaxSpend() then
    return true
  end
  -- actions+=/variable,name=finish_condition,value=1,if=buff.flagellation_buff.up&buff.flagellation_buff.remains<1&effective_combo_points>=2
  if EffectiveComboPoints >=2 and S.Flagellation:AnyDebuffUp() and Player:BuffRemains(S.Flagellation) < 1.5 then
    return true
  end

  return false
end

-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50&(!conduit.count_the_odds|buff.roll_the_bones.remains>=10)
  return ComboPointsDeficit >= 2 + num(Player:BuffUp(S.Broadside)) and EffectiveComboPoints < Rogue.CPMaxSpend()
    and Energy > 50 and (not S.CountTheOdds:ConduitEnabled() or Player:BuffRemains(S.RolltheBones) > 10)
end

-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>1+talent.killing_spree.enabled
local function Blade_Flurry_Sync ()
  return not AoEON() or EnemiesBFCount < 2 or (Player:BuffRemains(S.BladeFlurry) > 1 + num(S.KillingSpree:IsAvailable()))
end

-- Determine if we are allowed to use Vanish offensively in the current situation
local function Vanish_DPS_Condition ()
  return Settings.Outlaw.UseDPSVanish and CDsON() and not (Everyone.IsSoloMode() and Player:IsTanking(Target))
end

-- Marked for Death Target_if Functions
-- actions.cds+=/marked_for_death,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
local function EvaluateMfDTargetIfCondition(TargetUnit)
  return TargetUnit:TimeToDie()
end
local function EvaluateMfDCondition(TargetUnit)
  -- Note: Increased the SimC condition by 50% since we are slower.
  return TargetUnit:FilteredTimeToDie("<", ComboPointsDeficit*1.5) or (not Player:StealthUp(true, false) and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1)
end

-- Flagellation Target_if Functions
-- actions.cds+=/flagellation,target_if=max:target.time_to_die,if=!stealthed.all&(variable.finish_condition&target.time_to_die>10|fight_remains<13)
local function EvaluateFlagellationTargetIfCondition(TargetUnit)
  return TargetUnit:TimeToDie()
end
local function EvaluateFlagellationCondition(TargetUnit)
  return Finish_Condition() and Target:FilteredTimeToDie(">", 10) or HL.BossFilteredFightRemains("<", 13)
end

local function CDs ()
  --actions.cds=blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
  if S.BladeFlurry:IsReady() and AoEON() and EnemiesBFCount >= 2 and not Player:BuffUp(S.BladeFlurry) then
    if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
      HR.CastSuggested(S.BladeFlurry)
    else
      if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
    end
  end
  --actions.cds+=/roll_the_bones,if=master_assassin_remains=0&buff.dreadblades.down&(!buff.roll_the_bones.up|variable.rtb_reroll)
  if S.RolltheBones:IsReady() and Rogue.MasterAssassinsMarkRemains() <= 0 and Player:BuffDown(S.Dreadblades) and (not Player:BuffUp(S.RolltheBones) or RtB_Reroll()) then
    if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones" end
  end
  if CDsON() and Target:IsSpellInRange(S.SinisterStrike) then
    --actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&(buff.broadside.up+buff.true_bearing.up+buff.skull_and_crossbones.up+buff.ruthless_precision.up)>2
    if S.KeepItRolling:IsReady() and (not RtB_Reroll()) and (num(Player:BuffUp(S.Broadside)) + num(Player:BuffUp(S.TrueBearing)) + num(Player:BuffUp(S.SkullandCrossbones)) + num(Player:BuffUp(S.RuthlessPrecision))) > 2 then
	    if HR.Cast(S.KeepItRolling) then return "Cast Keep It Rolling" end
    end
    --actions.cds+=/flagellation,target_if=max:target.time_to_die,if=!stealthed.all&(variable.finish_condition&target.time_to_die>10|fight_remains<13)
    if S.Flagellation:IsReady() and not Player:StealthUp(true, true) then
      if Everyone.CastTargetIf(S.Flagellation, EnemiesBF, "max", EvaluateFlagellationTargetIfCondition,
        EvaluateFlagellationCondition, not Target:IsInMeleeRange(5), nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Flagellation" end
    end
    --actions.cds+=/shadow_dance,if=!runeforge.mark_of_the_master_assassin&!runeforge.invigorating_shadowdust&!runeforge.deathly_shadows&!stealthed.all&!buff.take_em_by_surprise.up&(variable.finish_condition&buff.slice_and_dice.up|variable.ambush_condition&!buff.slice_and_dice.up)
    if S.ShadowDance:IsAvailable() and S.ShadowDance:IsReady()
      and not MarkoftheMasterAssassinEquipped and not InvigoratingShadowdustEquipped and not DeathlyShadowsEquipped
      and not Player:StealthUp(true, true) and not Player:BuffUp(S.TakeEmBySurprise)
      and ((Finish_Condition() and Player:BuffUp(S.SliceandDice)) or (Ambush_Condition() and not Player:BuffUp(S.SliceandDice))) then
        if HR.Cast(S.ShadowDance) then return "Cast Shadow Dance" end
      end
    -- # Vanish
    if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
      --actions.cds+=/vanish,if=!runeforge.mark_of_the_master_assassin&!runeforge.invigorating_shadowdust&!runeforge.deathly_shadows&!stealthed.all&!buff.take_em_by_surprise.up&(variable.finish_condition&buff.slice_and_dice.up|variable.ambush_condition&!buff.slice_and_dice.up)
      if not MarkoftheMasterAssassinEquipped and not InvigoratingShadowdustEquipped and not DeathlyShadowsEquipped
      and not Player:StealthUp(true, true) and not Player:BuffUp(S.TakeEmBySurprise)
      and ((Finish_Condition() and Player:BuffUp(S.SliceandDice)) or (Ambush_Condition() and not Player:BuffUp(S.SliceandDice))) then
       if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Finish or Ambush)" end
      end
      --actions.cds+=/vanish,if=runeforge.deathly_shadows&!stealthed.all&buff.deathly_shadows.down&combo_points<=2&variable.ambush_condition
      if DeathlyShadowsEquipped and not Player:StealthUp(true, true) and Player:BuffDown(S.DeathlyShadowsBuff) and ComboPoints <= 2 and Ambush_Condition() then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Deathly Shadows - Ambush)" end
      end
      if MarkoftheMasterAssassinEquipped then
        --actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&!talent.marked_for_death.enabled,value=(!cooldown.between_the_eyes.ready&variable.finish_condition)|(cooldown.between_the_eyes.ready&variable.ambush_condition)
        if not S.MarkedforDeath:IsAvailable() then
          VanishMACondition = (not S.BetweentheEyes:IsReady() and Finish_Condition()) or (S.BetweentheEyes:IsReady() and Ambush_Condition())
        --actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&talent.marked_for_death.enabled,value=variable.finish_condition
        else VanishMACondition = Finish_Condition() end
        --actions.cds+=/vanish,if=variable.vanish_ma_condition&master_assassin_remains=0&variable.blade_flurry_sync
        if VanishMACondition and Rogue.MasterAssassinsMarkRemains() <= 0 and Blade_Flurry_Sync() then
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Mark of the Master Assassin)" end
        end
      end
    end
    --actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!talent.improved_adrenaline_rush|combo_points<=2)
    if S.AdrenalineRush:IsCastable() and not Player:BuffUp(S.AdrenalineRush) and ((not S.ImprovedAdrenalineRush:IsAvailable()) or ComboPoints <= 2) then
      if HR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
    end
    --actions.cds+=/fleshcraft,if=(soulbind.pustule_eruption|soulbind.volatile_solvent)&!stealthed.all&(!buff.blade_flurry.up|spell_targets.blade_flurry<2)&(!buff.adrenaline_rush.up|energy.base_time_to_max>2)
    if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled())
      and not Player:StealthUp(true, true)
      and (not Player:BuffUp(S.BladeFlurry) or EnemiesBFCount < 2) and (not Player:BuffUp(S.AdrenalineRush) or EnergyTimeToMax > 2) then
      HR.CastSuggested(S.Fleshcraft)
    end
    --actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=2&(!covenant.venthyr|buff.flagellation_buff.up)&(!talent.marked_for_death|!cooldown.marked_for_death.ready)
    if S.Dreadblades:IsReady() and Target:IsSpellInRange(S.Dreadblades) and not Player:StealthUp(true, true) and ComboPoints <= 2
      and (not IsVenthyr or S.Flagellation:AnyDebuffUp()) and (not S.MarkedforDeath:IsAvailable() or not S.MarkedforDeath:CooldownUp()) then
      if HR.Cast(S.Dreadblades, Settings.Outlaw.GCDasOffGCD.Dreadblades) then return "Cast Dreadblades" end
    end
    --actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
    --actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1&(!covenant.venthyr|cooldown.flagellation.remains>10|buff.flagellation_buff.up)
    --actions.cds+=/variable,name=killing_spree_vanish_sync,value=!runeforge.mark_of_the_master_assassin|cooldown.vanish.remains>10|master_assassin_remains>2
    if Blade_Flurry_Sync() then
      --actions.cds+=/killing_spree,if=variable.blade_flurry_sync&variable.killing_spree_vanish_sync&!stealthed.rogue&(debuff.between_the_eyes.up&buff.dreadblades.down&energy.base_deficit>(energy.regen*2+15)|spell_targets.blade_flurry>(2-buff.deathly_shadows.up)|master_assassin_remains>0)
      if CDsON() and S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and not Player:StealthUp(true, false)
        and (not MarkoftheMasterAssassinEquipped or S.Vanish:CooldownRemains() > 10 or Rogue.MasterAssassinsMarkRemains() > 2 or not Vanish_DPS_Condition())
        and (Target:DebuffUp(S.BetweentheEyes) and not Player:BuffUp(S.Dreadblades) and EnergyDeficit > (EnergyRegen * 2 + 10)
        or EnemiesBFCount > (2 - num(Player:BuffUp(S.DeathlyShadowsBuff))) or Rogue.MasterAssassinsMarkRemains() > 0) then
        if HR.Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle) then return "Cast Killing Spree" end
      end
      --actions.cds+=/blade_rush,if=variable.blade_flurry_sync&(energy.base_time_to_max>2&!buff.dreadblades.up&!buff.flagellation_buff.up|energy<=30|spell_targets>2)
      if S.BladeRush:IsCastable() and Target:IsSpellInRange(S.BladeRush) and (EnergyTimeToMax > 2 and not Player:BuffUp(S.Dreadblades) and not S.Flagellation:AnyDebuffUp()
        or Energy <= 30 or EnemiesBFCount > 2) then
        if HR.Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
      end
    end
    --actions.cds+=/vanish,if=runeforge.invigorating_shadowdust&covenant.venthyr&!stealthed.all&variable.finish_condition&(!cooldown.flagellation.ready&(!talent.dreadblades|!cooldown.dreadblades.ready|!buff.flagellation_buff.up))
    --actions.cds+=/vanish,if=runeforge.invigorating_shadowdust&!covenant.venthyr&!stealthed.all&variable.finish_condition&(cooldown.echoing_reprimand.remains>6|!cooldown.sepsis.ready|cooldown.serrated_bone_spike.full_recharge_time>20)
    if CDsON() and S.Vanish:IsReady() and InvigoratingShadowdustEquipped and not Player:StealthUp(true, true) and Finish_Condition() then
      if (IsVenthyr and (not S.Flagellation:IsReady() and (not S.Dreadblades:IsAvailable() or not S.Dreadblades:IsReady() or not S.Flagellation:AnyDebuffUp()))
        or (not IsVenthyr and (S.EchoingReprimand:CooldownRemains() > 6 or S.EchoingReprimandTalent:CooldownRemains() > 6 or not S.Sepsis:IsReady() or not S.SepsisTalent:IsReady() or S.SerratedBoneSpike:FullRechargeTime() > 20))) then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Invigorating Shadowdust)" end
      end
    end
    --actions.cds+=/shadowmeld,if=!stealthed.all&((conduit.count_the_odds|talent.count_the_odds)&variable.finish_condition|!talent.weaponmaster.enabled&variable.ambush_condition)
    --actions.cds+=/thistle_tea,if=energy.deficit>=100&!buff.thistle_tea.up&(charges=3|buff.adrenaline_rush.up|fight_remains<charges*6)
    if S.ThistleTea:IsCastable() and (EnergyDeficit >= 100 and not Player:BuffUp(S.ThistleTea)) then
      if HR.Cast(S.ThistleTea) then return "Cast Thistle Tea" end
    end
    --actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
    --actions.cds+=/blood_fury
    if S.BloodFury:IsCastable() then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
    end
    --actions.cds+=/berserking
    if S.Berserking:IsCastable() then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
    end
    --actions.cds+=/fireblood
    if S.Fireblood:IsCastable() then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
    end
    --actions.cds+=/ancestral_call
    if S.AncestralCall:IsCastable() then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
    end

    if Settings.Commons.UseItems then
      --actions.cds+=/use_item,name=wraps_of_electrostatic_potential
      if I.WrapsOfElectrostaticPotential:IsEquippedAndReady() then
        if HR.Cast(I.WrapsOfElectrostaticPotential, nil, Settings.Commons.ItemDisplayStyle) then return "Use Wraps of Electrostatic Potential" end
      end
      --actions.cds+=/use_item,name=ring_of_collapsing_futures,if=buff.temptation.down|fight_remains<30
      if I.RingOfCollapsingFutures:IsEquippedAndReady() then
        if HR.Cast(I.RingOfCollapsingFutures, nil, Settings.Commons.ItemDisplayStyle) then return "Use Ring of Collapsing Futures" end
      end
    end

    if Settings.Commons.UseTrinkets then
      --actions.cds+=/use_item,name=windscar_whetstone,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<7
      --actions.cds+=/use_item,name=cache_of_acquired_treasures,if=buff.acquired_axe.up|fight_remains<25     
      if I.CacheOfAcquiredTreasures:IsEquippedAndReady() and (Player:BuffUp(S.AcquiredAxe) or (Target:FilteredTimeToDie("<", 25) or HL.BossFilteredFightRemains("<", 25))) then
        if HR.Cast(I.CacheOfAcquiredTreasures, nil, Settings.Commons.TrinketDisplayStyle) then return "Use Cache of Acquired Treasures" end
      end
      --actions.cds+=/use_item,name=bloodstained_handkerchief,target_if=max:target.time_to_die*(!dot.cruel_garrote.ticking),if=!dot.cruel_garrote.ticking
      --actions.cds+=/use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<30
      --actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
      --actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse and (Target:DebuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 20) or TrinketToUse:TrinketHasStatAnyDps()) then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
      end
    end
  end
end

local function Stealth ()
  --actions.stealth=dispatch,if=variable.finish_condition
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
  --actions.stealth+=/ambush
  if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
  end
end

local function Finish ()
  --actions.finish=between_the_eyes,if=target.time_to_die>3&(debuff.between_the_eyes.remains<4|(runeforge.greenskins_wickers|talent.greenskins_wickers)&!buff.greenskins_wickers.up|!runeforge.greenskins_wickers&!talent.greenskins_wickers&buff.ruthless_precision.up)
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes)
    and (Target:FilteredTimeToDie(">", 3) or Target:TimeToDieIsNotValid())
    and ((Target:DebuffRemains(S.BetweentheEyes) < 4 or GreenskinsWickersEquipped or S.GreenskinsWickersTalent:IsAvailable())
    and (not Player:BuffUp(S.GreenskinsWickersBuff) and not Player:BuffUp(S.GreenskinsWickers)) or not GreenskinsWickersEquipped and not S.GreenskinsWickersTalent:IsAvailable()
    and Player:BuffUp(S.RuthlessPrecision)) then
    if HR.CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
  end
  --actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable&(!talent.swift_slasher|combo_points>=cp_max_spend)
  if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8
    and (not S.SwiftSlasher:IsAvailable() or ComboPoints >= Rogue.CPMaxSpend())
    then
    if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice" end
  end
  --actions.finish+=/cold_blood,if=!(runeforge.greenskins_wickers|talent.greenskins_wickers)
  if S.ColdBloodTalent:IsCastable() and not (GreenskinsWickersEquipped or S.GreenskinsWickersTalent:IsAvailable()) then
    if HR.CastPooling(S.ColdBloodTalent) then return "Cast Cold Blood" end
  end
  --actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
end

local function Build ()
  --actions.build=sepsis,target_if=max:target.time_to_die*debuff.between_the_eyes.up,if=target.time_to_die>11&debuff.between_the_eyes.up|fight_remains<11
  if CDsON() and S.SepsisTalent:IsReady() and Target:IsSpellInRange(S.SepsisTalent)
    and (Target:FilteredTimeToDie(">", 11) and Target:DebuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 11)) then
    if HR.Cast(S.SepsisTalent, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis" end
  end
  if CDsON() and S.Sepsis:IsReady() and Target:IsSpellInRange(S.Sepsis)
    and (Target:FilteredTimeToDie(">", 11) and Target:DebuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 11)) then
    if HR.Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis (Covenant)" end
  end
  --actions.build+=/ghostly_strike,if=debuff.ghostly_strike.remains<=3
  if S.GhostlyStrike:IsReady() and Target:IsSpellInRange(S.GhostlyStrike) and Target:DebuffRemains(S.GhostlyStrike) <= 3 then
    if HR.Cast(S.GhostlyStrike, Settings.Outlaw.GCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
  end
  --actions.build+=/shiv,if=runeforge.tiny_toxic_blade
  if S.Shiv:IsReady() and TinyToxicBladeEquipped then
    if HR.Cast(S.Shiv) then return "Cast Shiv (TTB)" end
  end
  --actions.build+=/echoing_reprimand,if=!soulbind.effusive_anima_accelerator|variable.blade_flurry_sync
  if S.EchoingReprimandTalent:IsReady() and Target:IsSpellInRange(S.EchoingReprimandTalent) and (not S.EffusiveAnimaAccelerator:SoulbindEnabled() or Blade_Flurry_Sync()) then
    if HR.Cast(S.EchoingReprimandTalent, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand" end
  end
  if S.EchoingReprimand:IsReady() and Target:IsSpellInRange(S.EchoingReprimand) and (not S.EffusiveAnimaAccelerator:SoulbindEnabled() or Blade_Flurry_Sync()) then
    if HR.Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand (Covenant)" end
  end
  --actions.build+=/ambush
  if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) and Player:BuffUp(S.AudacityBuff) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
  end
  --actions.build+=/cold_blood,if=buff.opportunity.up&buff.greenskins_wickers.up|buff.greenskins_wickers.up&buff.greenskins_wickers.remains<1.5
  if S.ColdBloodTalent:IsCastable()
    and (((Player:BuffUp(S.Opportunity) and Player:BuffUp(S.GreenskinsWickersBuff))
    or (Player:BuffUp(S.GreenskinsWickersBuff) and (Player:BuffRemains(S.GreenskinsWickersBuff) < 1.5)))
    or ((Player:BuffUp(S.Opportunity) and Player:BuffUp(S.GreenskinsWickers))
    or (Player:BuffUp(S.GreenskinsWickers) and (Player:BuffRemains(S.GreenskinsWickers) < 1.5)))) then
    if HR.CastPooling(S.ColdBloodTalent) then return "Cast Cold Blood" end
  end
  --actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up|talent.fan_the_hammer)|buff.greenskins_wickers.up&buff.greenskins_wickers.remains<1.5
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) then
    if Player:BuffUp(S.Opportunity) and (Player:BuffUp(S.GreenskinsWickersBuff) or Player:BuffUp(S.GreenskinsWickers) or Player:BuffUp(S.ConcealedBlunderbuss) or S.FanTheHammer:IsAvailable()) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (Buffed)" end
    elseif (Player:BuffUp(S.GreenskinsWickersBuff) and (Player:BuffRemains(S.GreenskinsWickersBuff) < 1.5)) or (Player:BuffUp(S.GreenskinsWickers) and (Player:BuffRemains(S.GreenskinsWickers) < 1.5)) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (GSW Dump)" end
    end
  end
--actions.build+=/pool_resource,for_next=1
  --actions.build+=/ambush
  if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) and Player:BuffUp(S.AudacityBuff) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
  end
  --actions.build+=/serrated_bone_spike,if=!dot.serrated_bone_spike_dot.ticking
  if S.SerratedBoneSpike:IsReady() and not Target:DebuffUp(S.SerratedBoneSpikeDebuff) then
    if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike" end
  end
  --actions.build+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=!dot.serrated_bone_spike_dot.ticking
  if AoEON() and S.SerratedBoneSpike:IsReady() then
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
  --actions.build+=/serrated_bone_spike,if=fight_remains<=5|cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25|combo_points.deficit=cp_gain&!buff.skull_and_crossbones.up&energy.base_time_to_max>1
  if S.SerratedBoneSpike:IsReady() and S.SerratedBoneSpike:ChargesFractional() > 2.75 then
    if HR.Cast(S.SerratedBoneSpike, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Serrated Bone Spike Filler" end
  end
  --actions.build+=/pistol_shot,if=buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|!talent.weaponmaster&combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot)
    and Player:BuffUp(S.Opportunity) and (EnergyDeficit > (EnergyRegen * 1.5)
    or not S.Weaponmaster:IsAvailable() and ComboPointsDeficit <= 1 + num(Player:BuffUp(S.Broadside))
    or S.QuickDraw:IsAvailable()
    or S.Audacity:IsAvailable() and not Player:BuffUp(S.AudacityBuff)) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
  end
--actions.build+=/sinister_strike,target_if=min:dot.vicious_wound.remains,if=buff.acquired_axe_driver.up
  --actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
    if HR.CastPooling(S.SinisterStrike) then return "Cast Sinister Strike" end
  end
end

--- ======= MAIN =======
local function APL ()
  -- Local Update
  BladeFlurryRange = S.AcrobaticStrikes:IsAvailable() and 9 or 6
  BetweenTheEyesDMGThreshold = S.Dispatch:Damage() * 1.25
  ComboPoints = Player:ComboPoints()
  EffectiveComboPoints = Rogue.EffectiveComboPoints(ComboPoints)
  ComboPointsDeficit = Player:ComboPointsDeficit()
  EnergyMaxOffset = Player:BuffUp(S.AdrenalineRush, nil, true) and -50 or 0 -- For base_time_to_max emulation
  Energy = EnergyPredictedStable(EnergyMaxOffset)
  EnergyRegen = Player:EnergyRegen()
  EnergyTimeToMax = EnergyTimeToMaxStable(EnergyMaxOffset)
  EnergyDeficit = Player:EnergyDeficitPredicted(nil, EnergyMaxOffset)

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
      if CDsON() and S.MarkedforDeath:IsCastable() and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1 then
        if Settings.Commons.STMfDAsDPSCD then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        else
          if HR.CastSuggested(S.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
      end
      -- TODO actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
      if S.AdrenalineRush:IsReady() and S.ImprovedAdrenalineRush:IsAvailable() then
        if HR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush (Opener)" end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=2
      if S.RolltheBones:IsReady() and (not Player:BuffUp(S.RolltheBones) or RtB_Reroll()) then
        if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones (Opener)" end
      end
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if S.SliceandDice:IsReady() and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 then
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
  -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1&(!covenant.venthyr|cooldown.flagellation.remains>10|buff.flagellation_buff.up)
  if S.MarkedforDeath:IsCastable() then
    if EnemiesBFCount > 1 and Everyone.CastTargetIf(S.MarkedforDeath, Enemies30y, "min", EvaluateMfDTargetIfCondition, EvaluateMfDCondition, nil, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then
      return "Cast Marked for Death (Cycle)"
    elseif EnemiesBFCount == 1 and not Player:StealthUp(true, false) and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1
      and (not IsVenthyr or S.Flagellation:CooldownRemains() > 10 or S.Flagellation:AnyDebuffUp()) then
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
    if S.ArcaneTorrent:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) and EnergyDeficit > 15 + EnergyRegen then
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
      and EnergyDeficit < 25 and (ComboPointsDeficit >= 1 or EnergyTimeToMax <= 1.2) then
      if HR.Cast(S.PistolShot) then return "Cast Pistol Shot (OOR)" end
    end
  end
end

local function Init ()
  S.Flagellation:RegisterAuraTracking()
end

HR.SetAPL(260, APL, Init)

--- ======= SIMC =======
-- Last Update: 2022-10-25

--  # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>25
-- actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
-- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
-- actions.precombat+=/roll_the_bones,precombat_seconds=2
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/stealth

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- # Reroll BT + GM or single buffs early other than Broadside, TB with Shadowdust, or SnC with Blunderbuss
-- actions+=/variable,name=rtb_reroll,value=rtb_buffs<2&(!buff.broadside.up&(!runeforge.concealed_blunderbuss&!talent.fan_the_hammer|!buff.skull_and_crossbones.up)&(!runeforge.invigorating_shadowdust|!buff.true_bearing.up))|rtb_buffs=2&buff.buried_treasure.up&buff.grand_melee.up
-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
-- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+buff.broadside.up&energy>=50&(!conduit.count_the_odds&!talent.count_the_odds|buff.roll_the_bones.remains>=10)
-- # Finish at max possible CP without overflowing bonus combo points, unless for BtE which always should be 5+ CP
-- actions+=/variable,name=finish_condition,value=combo_points>=cp_max_spend-buff.broadside.up-(buff.opportunity.up*(talent.quick_draw|talent.fan_the_hammer)|buff.concealed_blunderbuss.up)|effective_combo_points>=cp_max_spend
-- # Always attempt to use BtE at 5+ CP, regardless of CP gen waste
-- actions+=/variable,name=finish_condition,op=reset,if=cooldown.between_the_eyes.ready&effective_combo_points<5
-- # Finish at 2+ in the last GCD of Flagellation
-- actions+=/variable,name=finish_condition,value=1,if=buff.flagellation_buff.up&buff.flagellation_buff.remains<1&effective_combo_points>=2
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>1+talent.killing_spree.enabled
-- actions+=/run_action_list,name=stealth,if=stealthed.all
-- actions+=/call_action_list,name=cds
-- actions+=/run_action_list,name=finish,if=variable.finish_condition
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.base_deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- actions.build=sepsis,target_if=max:target.time_to_die*debuff.between_the_eyes.up,if=target.time_to_die>11&debuff.between_the_eyes.up|fight_remains<11
-- actions.build+=/ghostly_strike,if=debuff.ghostly_strike.remains<=3
-- actions.build+=/shiv,if=runeforge.tiny_toxic_blade
-- actions.build+=/echoing_reprimand,if=!soulbind.effusive_anima_accelerator|variable.blade_flurry_sync
-- actions.build+=/ambush
-- # Use Pistol Shot when buffed by bonuses as a priority
-- actions.build+=/cold_blood,if=buff.opportunity.up&buff.greenskins_wickers.up|buff.greenskins_wickers.up&buff.greenskins_wickers.remains<1.5
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(buff.greenskins_wickers.up|buff.concealed_blunderbuss.up|talent.fan_the_hammer)|buff.greenskins_wickers.up&buff.greenskins_wickers.remains<1.5
-- actions.build+=/pool_resource,for_next=1
-- actions.build+=/ambush
-- # Apply SBS to all targets without a debuff as priority, preferring targets dying sooner after the primary target
-- actions.build+=/serrated_bone_spike,if=!dot.serrated_bone_spike_dot.ticking
-- actions.build+=/serrated_bone_spike,target_if=min:target.time_to_die+(dot.serrated_bone_spike_dot.ticking*600),if=!dot.serrated_bone_spike_dot.ticking
-- # Attempt to use when it will cap combo points and SnD is down, otherwise keep from capping charges
-- actions.build+=/serrated_bone_spike,if=fight_remains<=5|cooldown.serrated_bone_spike.max_charges-charges_fractional<=0.25|combo_points.deficit=cp_gain&!buff.skull_and_crossbones.up&energy.base_time_to_max>1
-- # Use Pistol Shot with Opportunity if Combat Potency won't overcap energy, when it will exactly cap CP, or when using Quick Draw
-- actions.build+=/pistol_shot,if=buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|!talent.weaponmaster&combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
-- # Use Sinister Strike on targets without the Cache DoT if the trinket is up
-- actions.build+=/sinister_strike,target_if=min:dot.vicious_wound.remains,if=buff.acquired_axe_driver.up
-- actions.build+=/sinister_strike

-- # Cooldowns
-- # Blade Flurry on 2+ enemies
-- actions.cds=blade_flurry,if=spell_targets>=2&!buff.blade_flurry.up
-- actions.cds+=/roll_the_bones,if=master_assassin_remains=0&buff.dreadblades.down&(!buff.roll_the_bones.up|variable.rtb_reroll)
-- actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&(buff.broadside.up+buff.true_bearing.up+buff.skull_and_crossbones.up+buff.ruthless_precision.up)>2
-- actions.cds+=/flagellation,target_if=max:target.time_to_die,if=!stealthed.all&(variable.finish_condition&target.time_to_die>10|fight_remains<13)
-- actions.cds+=/shadow_dance,if=!runeforge.mark_of_the_master_assassin&!runeforge.invigorating_shadowdust&!runeforge.deathly_shadows&!stealthed.all&!buff.take_em_by_surprise.up&(variable.finish_condition&buff.slice_and_dice.up|variable.ambush_condition&!buff.slice_and_dice.up)
-- actions.cds+=/vanish,if=!runeforge.mark_of_the_master_assassin&!runeforge.invigorating_shadowdust&!runeforge.deathly_shadows&!stealthed.all&!buff.take_em_by_surprise.up&(variable.finish_condition&buff.slice_and_dice.up|variable.ambush_condition&!buff.slice_and_dice.up)
-- # With Deathly Shadows, optimize for combo point generation when the buff is down
-- actions.cds+=/vanish,if=runeforge.deathly_shadows&!stealthed.all&buff.deathly_shadows.down&combo_points<=2&variable.ambush_condition
-- # With Master Asssassin, sync Vanish with a finisher or Ambush depending on BtE cooldown, or always a finisher with MfD
-- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&!talent.marked_for_death.enabled,value=(!cooldown.between_the_eyes.ready&variable.finish_condition)|(cooldown.between_the_eyes.ready&variable.ambush_condition)
-- actions.cds+=/variable,name=vanish_ma_condition,if=runeforge.mark_of_the_master_assassin&talent.marked_for_death.enabled,value=variable.finish_condition
-- actions.cds+=/vanish,if=variable.vanish_ma_condition&master_assassin_remains=0&variable.blade_flurry_sync
-- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!talent.improved_adrenaline_rush|combo_points<=2)
-- # Fleshcraft for Pustule Eruption if not stealthed and not with Blade Flurry
-- actions.cds+=/fleshcraft,if=(soulbind.pustule_eruption|soulbind.volatile_solvent)&!stealthed.all&(!buff.blade_flurry.up|spell_targets.blade_flurry<2)&(!buff.adrenaline_rush.up|energy.base_time_to_max>2)
-- actions.cds+=/dreadblades,if=!stealthed.all&combo_points<=2&(!covenant.venthyr|buff.flagellation_buff.up)&(!talent.marked_for_death|!cooldown.marked_for_death.ready)
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|!stealthed.rogue&combo_points.deficit>=cp_max_spend-1)
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&!stealthed.rogue&combo_points.deficit>=cp_max_spend-1&(!covenant.venthyr|cooldown.flagellation.remains>10|buff.flagellation_buff.up)
-- # Attempt to sync Killing Spree with Vanish for Master Assassin
-- actions.cds+=/variable,name=killing_spree_vanish_sync,value=!runeforge.mark_of_the_master_assassin|cooldown.vanish.remains>10|master_assassin_remains>2
-- # Use in 1-2T if BtE is up and won't cap Energy, or at 3T+ (2T+ with Deathly Shadows) or when Master Assassin is up.
-- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&variable.killing_spree_vanish_sync&!stealthed.rogue&(debuff.between_the_eyes.up&buff.dreadblades.down&energy.base_deficit>(energy.regen*2+15)|spell_targets.blade_flurry>(2-buff.deathly_shadows.up)|master_assassin_remains>0)
-- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&(energy.base_time_to_max>2&!buff.dreadblades.up&!buff.flagellation_buff.up|energy<=30|spell_targets>2)
-- # If using Invigorating Shadowdust, use normal logic in addition to checking major CDs.
-- actions.cds+=/vanish,if=runeforge.invigorating_shadowdust&covenant.venthyr&!stealthed.all&variable.finish_condition&(!cooldown.flagellation.ready&(!talent.dreadblades|!cooldown.dreadblades.ready|!buff.flagellation_buff.up))
-- actions.cds+=/vanish,if=runeforge.invigorating_shadowdust&!covenant.venthyr&!stealthed.all&variable.finish_condition&(cooldown.echoing_reprimand.remains>6|!cooldown.sepsis.ready|cooldown.serrated_bone_spike.full_recharge_time>20)
-- actions.cds+=/shadowmeld,if=!stealthed.all&((conduit.count_the_odds|talent.count_the_odds)&variable.finish_condition|!talent.weaponmaster.enabled&variable.ambush_condition)
-- actions.cds+=/thistle_tea,if=energy.deficit>=100&!buff.thistle_tea.up&(charges=3|buff.adrenaline_rush.up|fight_remains<charges*6)
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call
-- actions.cds+=/use_item,name=wraps_of_electrostatic_potential
-- actions.cds+=/use_item,name=ring_of_collapsing_futures,if=buff.temptation.down|fight_remains<30
-- actions.cds+=/use_item,name=windscar_whetstone,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<7
-- actions.cds+=/use_item,name=cache_of_acquired_treasures,if=buff.acquired_axe.up|fight_remains<25
-- actions.cds+=/use_item,name=bloodstained_handkerchief,target_if=max:target.time_to_die*(!dot.cruel_garrote.ticking),if=!dot.cruel_garrote.ticking
-- actions.cds+=/use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<30
-- # Default conditions for usable items.
-- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
-- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20

-- # Finishers
-- # BtE to keep the Crit debuff up, if RP is up, or for Greenskins, unless the target is about to die.
-- actions.finish=between_the_eyes,if=target.time_to_die>3&(debuff.between_the_eyes.remains<4|(runeforge.greenskins_wickers|talent.greenskins_wickers)&!buff.greenskins_wickers.up|!runeforge.greenskins_wickers&!talent.greenskins_wickers&buff.ruthless_precision.up)
-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable&(!talent.swift_slasher|combo_points>=cp_max_spend)
-- actions.finish+=/cold_blood,if=!(runeforge.greenskins_wickers|talent.greenskins_wickers)
-- actions.finish+=/dispatch

-- # Stealth
-- actions.stealth=dispatch,if=variable.finish_condition
-- actions.stealth+=/ambush
