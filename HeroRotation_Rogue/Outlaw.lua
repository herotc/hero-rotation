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
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local mathmin = math.min
local mathmax = math.max
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
  I.ManicGrieftorch:ID(),
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
        0.3 *
        -- Aura Multiplier (SpellID: 137036)
        1.0 *
        -- Versatility Damage Multiplier
        (1 + Player:VersatilityDmgPct() / 100) *
      --- Target Modifier
        -- Ghostly Strike Multiplier
        (Target:DebuffUp(S.GhostlyStrike) and 1.1 or 1)
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

-- Stable Energy Prediction
local PrevEnergyTimeToMaxPredicted, PrevEnergyPredicted = 0, 0
local function EnergyTimeToMaxStable (MaxOffset)
  local EnergyTimeToMaxPredicted = Player:EnergyTimeToMaxPredicted(nil, MaxOffset)
  if EnergyTimeToMaxPredicted < PrevEnergyTimeToMaxPredicted 
    or (EnergyTimeToMaxPredicted - PrevEnergyTimeToMaxPredicted) > 0.5 then
    PrevEnergyTimeToMaxPredicted = EnergyTimeToMaxPredicted
  end
  return PrevEnergyTimeToMaxPredicted
end
local function EnergyPredictedStable ()
  local EnergyPredicted = Player:EnergyPredicted()
  if EnergyPredicted > PrevEnergyPredicted
    or (EnergyPredicted - PrevEnergyPredicted) > 9 then
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
    Cache.APLVar.RtB_Buffs = {}
    Cache.APLVar.RtB_Buffs.Total = 0
    Cache.APLVar.RtB_Buffs.Normal = 0
    Cache.APLVar.RtB_Buffs.Shorter = 0
    Cache.APLVar.RtB_Buffs.Longer = 0
    local RtBRemains = Rogue.RtBRemains()
    for i = 1, #RtB_BuffsList do
      local Remains = Player:BuffRemains(RtB_BuffsList[i])
      if Remains > 0 then
        Cache.APLVar.RtB_Buffs.Total = Cache.APLVar.RtB_Buffs.Total + 1
        if Remains == RtBRemains then
          Cache.APLVar.RtB_Buffs.Normal = Cache.APLVar.RtB_Buffs.Normal + 1
        elseif Remains > RtBRemains then
          Cache.APLVar.RtB_Buffs.Longer = Cache.APLVar.RtB_Buffs.Longer + 1
        else
          Cache.APLVar.RtB_Buffs.Shorter = Cache.APLVar.RtB_Buffs.Shorter + 1
        end
      end
    end
  end
  return Cache.APLVar.RtB_Buffs.Total
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
      -- actions+=/variable,name=rtb_reroll,if=!talent.hidden_opportunity,value=rtb_buffs<2&(!buff.broadside.up&(!talent.fan_the_hammer|!buff.skull_and_crossbones.up)&!buff.true_bearing.up|buff.loaded_dice.up)|rtb_buffs=2&(buff.buried_treasure.up&buff.grand_melee.up|!buff.broadside.up&!buff.true_bearing.up&buff.loaded_dice.up)
      -- actions+=/variable,name=rtb_reroll,if=!talent.hidden_opportunity&(talent.keep_it_rolling|talent.count_the_odds),value=variable.rtb_reroll|((rtb_buffs.normal=0&rtb_buffs.longer>=1)&!(buff.broadside.up&buff.true_bearing.up&buff.skull_and_crossbones.up)&!(buff.broadside.remains>39|buff.true_bearing.remains>39|buff.ruthless_precision.remains>39|buff.skull_and_crossbones.remains>39))
      -- actions+=/variable,name=rtb_reroll,if=talent.hidden_opportunity,value=!rtb_buffs.will_lose.skull_and_crossbones&(rtb_buffs.will_lose-rtb_buffs.will_lose.grand_melee)<2+buff.loaded_dice.up
      if S.HiddenOpportunity:IsAvailable() then
        RtB_Buffs() -- Update cache
        if (Player:BuffDown(S.SkullandCrossbones) or Player:BuffRemains(S.SkullandCrossbones) > Rogue.RtBRemains())
          and ((Cache.APLVar.RtB_Buffs.Normal + Cache.APLVar.RtB_Buffs.Shorter) -
            num(Player:BuffUp(S.GrandMelee) and Player:BuffRemains(S.GrandMelee) <= Rogue.RtBRemains())) < (2 + num(Player:BuffUp(S.LoadedDiceBuff))) then
          Cache.APLVar.RtB_Reroll = true
        else
          Cache.APLVar.RtB_Reroll = false
        end
      else
        if RtB_Buffs() == 2 then
          if Player:BuffUp(S.BuriedTreasure) and Player:BuffUp(S.GrandMelee) then
            Cache.APLVar.RtB_Reroll = true
          elseif Player:BuffUp(S.LoadedDiceBuff) and not Player:BuffUp(S.Broadside) and not Player:BuffUp(S.TrueBearing) then
            Cache.APLVar.RtB_Reroll = true
          end
        elseif RtB_Buffs() < 2
          and (not Player:BuffUp(S.Broadside) and (not S.FanTheHammer:IsAvailable() or not Player:BuffUp(S.SkullandCrossbones))
            and not Player:BuffUp(S.TrueBearing) or Player:BuffUp(S.LoadedDiceBuff)) then
          Cache.APLVar.RtB_Reroll = true
        else
          Cache.APLVar.RtB_Reroll = false
        end

        if Cache.APLVar.RtB_Reroll == false and (S.KeepItRolling:IsAvailable() or S.CountTheOdds:IsAvailable()) then
          if Cache.APLVar.RtB_Buffs.Normal == 0 and Cache.APLVar.RtB_Buffs.Longer > 0
            and not (Player:BuffUp(S.Broadside) and Player:BuffUp(S.TrueBearing) and Player:BuffUp(S.SkullandCrossbones))
            and not (Player:BuffRemains(S.Broadside) > 39 or Player:BuffRemains(S.TrueBearing) > 39
              or Player:BuffRemains(S.RuthlessPrecision) > 39 or Player:BuffRemains(S.SkullandCrossbones) > 39) then
            Cache.APLVar.RtB_Reroll = true
          end
        end
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

-- # Checks if we are in an appropriate Stealth state for triggering the Count the Odds bonus
local function Stealthed_CtO (BypassRecovery)
  -- actions+=/variable,name=stealthed_cto,value=talent.count_the_odds&(stealthed.basic|buff.shadowmeld.up|buff.shadow_dance.up)
  return S.CountTheOdds:IsAvailable() and (Player:StealthUp(false, false, BypassRecovery)
    or Player:BuffUp(S.Shadowmeld, nil, BypassRecovery) or Player:BuffUp(S.ShadowDanceBuff, nil, BypassRecovery))
end

-- # Finish at 6 (5 with Summarily Dispatched talented) CP or CP Max-1, whichever is greater of the two
local function Finish_Condition ()
  -- actions+=/variable,name=finish_condition,value=combo_points>=((cp_max_spend-1)<?(6-talent.summarily_dispatched))|effective_combo_points>=cp_max_spend
  return ComboPoints >= mathmax(Rogue.CPMaxSpend() - 1, 6 - num(S.SummarilyDispatched:IsAvailable())) or EffectiveComboPoints >= Rogue.CPMaxSpend()
end

-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+talent.improved_ambush+buff.broadside.up&energy>=50&(!talent.count_the_odds|buff.roll_the_bones.remains>=10)
  return ComboPointsDeficit >= 2 + num(S.ImprovedAmbush:IsAvailable()) + num(Player:BuffUp(S.Broadside)) and EffectiveComboPoints < Rogue.CPMaxSpend()
    and Energy >= 50 and (not S.CountTheOdds:IsAvailable() or Rogue.RtBRemains() > 10)
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
-- actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|combo_points.deficit>=cp_max_spend-1)&!buff.dreadblades.up
local function EvaluateMfDTargetIfCondition(TargetUnit)
  return TargetUnit:TimeToDie()
end
local function EvaluateMfDCondition(TargetUnit)
  -- Note: Increased the SimC condition by 50% since we are slower.
  return (TargetUnit:FilteredTimeToDie("<", ComboPointsDeficit*1.5) or (not Player:StealthUp(true, false) and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1)) and not Player:DebuffUp(S.Dreadblades)
end

local function StealthCDs ()
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    -- actions.stealth_cds=variable,name=vanish_condition,value=talent.hidden_opportunity|!talent.shadow_dance|!cooldown.shadow_dance.ready
    if S.HiddenOpportunity:IsAvailable() or not S.ShadowDanceTalent:IsAvailable() or not S.ShadowDance:IsCastable() then
      -- actions.stealth_cds+=/vanish,if=talent.find_weakness&!talent.audacity&debuff.find_weakness.down&variable.ambush_condition&variable.vanish_condition
      -- actions.stealth_cds+=/vanish,if=talent.hidden_opportunity&!buff.audacity.up&(variable.vanish_opportunity_condition|buff.opportunity.stack<buff.opportunity.max_stack)&variable.ambush_condition&variable.vanish_condition
      -- actions.stealth_cds+=/vanish,if=(!talent.find_weakness|talent.audacity)&!talent.hidden_opportunity&variable.finish_condition&variable.vanish_condition
      if S.FindWeakness:IsAvailable() and not S.Audacity:IsAvailable() and Target:DebuffDown(S.FindWeaknessDebuff) and Ambush_Condition() then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (FW)" end
        return
      end
      if S.HiddenOpportunity:IsAvailable() then
        -- actions.stealth_cds+=/variable,name=vanish_opportunity_condition,value=!talent.shadow_dance&talent.fan_the_hammer.rank+talent.quick_draw+talent.audacity<talent.count_the_odds+talent.keep_it_rolling
        local VanishOpportunityCondition = not S.ShadowDanceTalent:IsAvailable()
          and (S.FanTheHammer:TalentRank() + num(S.QuickDraw:IsAvailable()) + num(S.Audacity:IsAvailable()) < num(S.CountTheOdds:IsAvailable()) + num(S.KeepItRolling:IsAvailable()))
        if Player:BuffDown(S.AudacityBuff) and (VanishOpportunityCondition or Player:BuffStack(S.Opportunity) < (S.FanTheHammer:IsAvailable() and 6 or 1)) and Ambush_Condition() then
          if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (HO)" end
          return
        end
      end
      if (not S.FindWeakness:IsAvailable() or not S.Audacity:IsAvailable()) and not S.HiddenOpportunity:IsAvailable() and Finish_Condition() then
        if HR.Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Finish)" end
        return
      end
    end
  end
  if S.ShadowDance:IsCastable() then
    -- actions.stealth_cds+=/variable,name=shadow_dance_condition,value=talent.shadow_dance&debuff.between_the_eyes.up&(!talent.ghostly_strike|debuff.ghostly_strike.up)&(!talent.dreadblades|!cooldown.dreadblades.ready)&(!talent.hidden_opportunity|!buff.audacity.up&(talent.fan_the_hammer.rank<2|!buff.opportunity.up))
    -- actions.stealth_cds+=/shadow_dance,if=!talent.keep_it_rolling&variable.shadow_dance_condition&buff.slice_and_dice.up&(variable.finish_condition|talent.hidden_opportunity)&(!talent.hidden_opportunity|!cooldown.vanish.ready)
    -- actions.stealth_cds+=/shadow_dance,if=talent.keep_it_rolling&variable.shadow_dance_condition&(cooldown.keep_it_rolling.remains<=30|cooldown.keep_it_rolling.remains>120&(variable.finish_condition|talent.hidden_opportunity))
    if Target:DebuffUp(S.BetweentheEyes) and (not S.GhostlyStrike:IsAvailable() or Target:DebuffUp(S.GhostlyStrike))
      and (not S.Dreadblades:IsAvailable() or not S.Dreadblades:IsCastable())
      and (not S.HiddenOpportunity:IsAvailable() or Player:BuffDown(S.AudacityBuff) and (S.FanTheHammer:TalentRank() < 2 or Player:BuffDown(S.Opportunity))) then
      if S.KeepItRolling:IsAvailable() then
        if (S.KeepItRolling:CooldownRemains() <= 30 or S.KeepItRolling:CooldownRemains() > 120 and (Finish_Condition() or S.HiddenOpportunity:IsAvailable())) then
          if HR.Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance (KiR)" end
          return
        end
      else
        if Player:BuffUp(S.SliceandDice) and (Finish_Condition() or S.HiddenOpportunity:IsAvailable())
          and (not S.HiddenOpportunity:IsAvailable() or not S.Vanish:CooldownUp() or not Vanish_DPS_Condition()) then
          if HR.Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
          return
        end
      end
    end
  end
end

local function CDs ()
  -- actions.cds+=/adrenaline_rush,if=!buff.adrenaline_rush.up&(!talent.improved_adrenaline_rush|combo_points<=2)
  if CDsON() and S.AdrenalineRush:IsCastable() and not Player:BuffUp(S.AdrenalineRush)
    and (not S.ImprovedAdrenalineRush:IsAvailable() or ComboPoints <= 2) then
    if HR.Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
  end
  -- actions.cds+=/blade_flurry,if=spell_targets>=2&buff.blade_flurry.remains<gcd
  if S.BladeFlurry:IsReady() and AoEON() and EnemiesBFCount >= 2
    and Player:BuffRemains(S.BladeFlurry) < (Player:BuffUp(S.AdrenalineRush) and 0.8 or 1) then
    if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
      HR.CastSuggested(S.BladeFlurry)
    else
      if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
    end
  end
  -- actions.cds+=/roll_the_bones,if=buff.dreadblades.down&(rtb_buffs.total=0|variable.rtb_reroll)
  if S.RolltheBones:IsReady() and not Player:DebuffUp(S.Dreadblades) and (RtB_Buffs() == 0 or RtB_Reroll()) then
    if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones" end
  end
  -- actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&(buff.broadside.up+buff.true_bearing.up+buff.skull_and_crossbones.up+buff.ruthless_precision.up)>2&(buff.shadow_dance.down|rtb_buffs>=6)
  if S.KeepItRolling:IsCastable() and not RtB_Reroll()
    and (num(Player:BuffUp(S.Broadside)) + num(Player:BuffUp(S.TrueBearing)) + num(Player:BuffUp(S.SkullandCrossbones)) + num(Player:BuffUp(S.RuthlessPrecision))) > 2
    and (Player:BuffDown(S.ShadowDanceBuff) or RtB_Buffs() >= 6) then
    if HR.Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then return "Cast Keep it Rolling" end
  end
  -- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&!buff.dreadblades.up&(energy.base_time_to_max>4+stealthed.rogue-spell_targets%3)
  if S.BladeRush:IsCastable() and Target:IsSpellInRange(S.BladeRush) and Blade_Flurry_Sync() and not Player:DebuffUp(S.Dreadblades)
    and EnergyTimeToMax > (4 + num(Player:StealthUp(true, false)) - (EnemiesBFCount / 3)) and HL.FilteredFightRemains(EnemiesBF, ">", 4) then
    if HR.Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
  end
  if Target:IsSpellInRange(S.SinisterStrike) then
    -- actions.cds+=/call_action_list,name=stealth_cds,if=!stealthed.all|talent.count_the_odds&!variable.stealthed_cto
    if not Player:StealthUp(true, true, true) or S.CountTheOdds:IsAvailable() and not Stealthed_CtO(true) then
      ShouldReturn = StealthCDs()
      if ShouldReturn then return ShouldReturn end
    end
    -- actions.cds+=/dreadblades,if=!(variable.stealthed_cto|stealthed.basic|talent.hidden_opportunity&stealthed.rogue)&combo_points<=2&(!talent.marked_for_death|!cooldown.marked_for_death.ready)&target.time_to_die>=10
    if S.Dreadblades:IsCastable() and Target:IsSpellInRange(S.Dreadblades) and ComboPoints <= 2 
      and not (Stealthed_CtO() or Player:StealthUp(false, false) or S.HiddenOpportunity:IsAvailable() and Player:StealthUp(true, false))
      and (not S.MarkedforDeath:IsAvailable() or not S.MarkedforDeath:CooldownUp()) and Target:FilteredTimeToDie(">=", 10) then
      if HR.CastPooling(S.Dreadblades) then return "Cast Dreadblades" end
    end
  end
  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.base_deficit>=100|fight_remains<charges*6)
  if CDsON() and S.ThistleTea:IsCastable() and not Player:BuffUp(S.ThistleTea)
    and (EnergyDeficit >= 100 or HL.BossFilteredFightRemains("<", S.ThistleTea:Charges()*6)) then
    if HR.Cast(S.ThistleTea, Settings.Commons.OffGCDasOffGCD.ThistleTea) then return "Cast Thistle Tea" end
  end
  -- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&!stealthed.rogue&debuff.between_the_eyes.up&energy.base_time_to_max>4
  if CDsON() and S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and Blade_Flurry_Sync()
    and not Player:StealthUp(true, false) and Target:DebuffUp(S.BetweentheEyes) and EnergyTimeToMax > 4 then
    if HR.Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle) then return "Cast Killing Spree" end
  end
  if Target:IsSpellInRange(S.SinisterStrike) and CDsON() then
    -- actions.cds+=/shadowmeld,if=!stealthed.all&(talent.count_the_odds&variable.finish_condition|!talent.weaponmaster.enabled&variable.ambush_condition)
    if Settings.Outlaw.UseDPSVanish and S.Shadowmeld:IsCastable() and
      (S.CountTheOdds:IsAvailable() and Finish_Condition() or not S.Weaponmaster:IsAvailable() and Ambush_Condition()) then
      if HR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
    end

    -- TODO actions.cds=potion,if=buff.bloodlust.react|target.time_to_die<=60|buff.adrenaline_rush.up

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

    -- Trinkets
    -- Windscar Whetstone has a bugged 26 second lockout despite the tooltip
    if Settings.Commons.UseTrinkets and I.WindscarWhetstone:TimeSinceLastCast() > 26 then
      -- actions.cds+=/use_item,name=manic_grieftorch,if=!stealthed.all&!buff.adrenaline_rush.up|fight_remains<5
      if I.ManicGrieftorch:IsEquippedAndReady() and Target:FilteredTimeToDie(">", 2) and not Player:StealthUp(true, true) then
        if HR.Cast(I.ManicGrieftorch, nil, Settings.Commons.TrinketDisplayStyle) then return "Manic Grieftorch"; end
      end
      -- actions.cds+=/use_item,name=windscar_whetstone,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<7
      -- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
      -- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse and (Target:DebuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 20) or TrinketToUse:TrinketHasStatAnyDps()) then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() end
      end
    end
  end
end

local function Stealth ()
  -- actions.stealth=blade_flurry,if=talent.subterfuge&talent.hidden_opportunity&spell_targets>=2&!buff.blade_flurry.up
  if S.BladeFlurry:IsReady() and AoEON() and EnemiesBFCount >= 2 and S.Subterfuge:IsAvailable()
    and S.HiddenOpportunity:IsAvailable() and not Player:BuffUp(S.BladeFlurry) then
    if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
      HR.CastSuggested(S.BladeFlurry)
    else
      if HR.Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
    end
  end
  -- actions.stealth+=/cold_blood,if=variable.finish_condition
  if S.ColdBlood:IsCastable() and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
    if HR.Cast(S.ColdBlood, Settings.Commons.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
  end
  -- actions.stealth+=/dispatch,if=variable.finish_condition
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
  -- actions.stealth+=/ambush,if=variable.stealthed_cto|stealthed.basic&talent.find_weakness&!debuff.find_weakness.up|talent.hidden_opportunity
  if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) and (Stealthed_CtO() or S.HiddenOpportunity:IsAvailable()
    or Player:StealthUp(false, false) and S.FindWeakness:IsAvailable() and not Target:DebuffUp(S.FindWeaknessDebuff)) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush" end
  end
end

local function Finish ()
  -- # BtE to keep the Crit debuff up, if RP is up, or for Greenskins, unless the target is about to die.
  -- actions.finish=between_the_eyes,if=target.time_to_die>3&(debuff.between_the_eyes.remains<4|talent.greenskins_wickers&!buff.greenskins_wickers.up|!talent.greenskins_wickers&buff.ruthless_precision.up)
  -- Note: Increased threshold to 4s to account for player reaction time
  if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes)
    and (Target:FilteredTimeToDie(">", 4) or Target:TimeToDieIsNotValid()) and Rogue.CanDoTUnit(Target, BetweenTheEyesDMGThreshold)
    and (Target:DebuffRemains(S.BetweentheEyes) < 4 or S.GreenskinsWickers:IsAvailable() and not Player:BuffUp(S.GreenskinsWickersBuff)
      or not S.GreenskinsWickers:IsAvailable() and Player:BuffUp(S.RuthlessPrecision)) then
    if HR.CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
  end
  -- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable&(!talent.swift_slasher|combo_points>=cp_max_spend)
  -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
  if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 and (not S.SwiftSlasher:IsAvailable() or ComboPointsDeficit == 0) then
    if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice" end
  end
  if S.ColdBlood:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.Cast(S.ColdBlood, Settings.Commons.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
  end
  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if HR.CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
end

local function Build ()
  -- actions.build=sepsis,target_if=max:target.time_to_die*debuff.between_the_eyes.up,if=target.time_to_die>11&debuff.between_the_eyes.up|fight_remains<11
  -- TODO: target_if
  if CDsON() and S.Sepsis:IsReady() and Target:IsSpellInRange(S.Sepsis)
    and (Target:FilteredTimeToDie(">", 11) and Target:DebuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 11)) then
    if HR.Cast(S.Sepsis, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Sepsis" end
  end
  -- actions.build+=/ghostly_strike,if=debuff.ghostly_strike.remains<=3&(spell_targets.blade_flurry<=2|buff.dreadblades.up)&!buff.subterfuge.up&target.time_to_die>=5
  if S.GhostlyStrike:IsReady() and Target:IsSpellInRange(S.GhostlyStrike) and Target:DebuffRemains(S.GhostlyStrike) <= 3
    and (EnemiesBFCount <= 2 or Player:BuffUp(S.Dreadblades)) and Player:BuffDown(S.SubterfugeBuff) and Target:FilteredTimeToDie(">=", 5) then
    if HR.Cast(S.GhostlyStrike, Settings.Outlaw.GCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
  end
  -- actions.build+=/echoing_reprimand,if=!buff.dreadblades.up
  if CDsON() and S.EchoingReprimand:IsReady() and not Player:DebuffUp(S.Dreadblades) then
    if HR.Cast(S.EchoingReprimand, nil, Settings.Commons.CovenantDisplayStyle) then return "Cast Echoing Reprimand" end
  end
  -- actions.build+=/ambush,if=(talent.hidden_opportunity|talent.keep_it_rolling)&(buff.audacity.up|buff.sepsis_buff.up|buff.subterfuge.up&cooldown.keep_it_rolling.ready)|talent.find_weakness&debuff.find_weakness.down
  if S.Ambush:IsReady() then
    if S.FindWeakness:IsAvailable() and not Target:DebuffUp(S.FindWeaknessDebuff) then
      if HR.Cast(S.Ambush) then return "Cast Ambush (High-Prio FW)" end
    end
    if (S.HiddenOpportunity:IsAvailable() or S.KeepItRolling:IsAvailable())
      and (Player:BuffUp(S.AudacityBuff) or Player:BuffUp(S.SepsisBuff) or Player:BuffUp(S.SubterfugeBuff) and S.KeepItRolling:IsReady()) then
      if HR.Cast(S.Ambush) then return "Cast Ambush (High-Prio Buffed)" end
    end
  end
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up&!buff.subterfuge.up&!buff.shadow_dance.up
  -- actions.build+=/pistol_shot,if=buff.greenskins_wickers.up&(!talent.fan_the_hammer&buff.opportunity.up|buff.greenskins_wickers.remains<1.5)
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&combo_points.deficit>((1+talent.quick_draw)*talent.fan_the_hammer.rank)&!buff.dreadblades.up&(!talent.hidden_opportunity|!buff.subterfuge.up&!buff.shadow_dance.up)
  if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) then
    if Player:BuffUp(S.GreenskinsWickersBuff) and (not S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity)) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (Buffed)" end
    elseif Player:BuffUp(S.GreenskinsWickersBuff) and Player:BuffRemains(S.GreenskinsWickersBuff) < 1.5 then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (GSW Dump)" end
    end
    if S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) then
      if S.Audacity:IsAvailable() and S.HiddenOpportunity:IsAvailable() and Player:BuffDown(S.AudacityBuff)
        and Player:BuffDown(S.SubterfugeBuff) and Player:BuffDown(S.ShadowDanceBuff) then
        if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (Audacity)" end
      elseif Player:BuffStack(S.Opportunity) >= 6 or Player:BuffRemains(S.Opportunity) < 2 then
        if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (FtH Dump)" end
      elseif ComboPointsDeficit > (1+num(S.QuickDraw:IsAvailable())*S.FanTheHammer:TalentRank()) and not Player:DebuffUp(S.Dreadblades)
        and (not S.HiddenOpportunity:IsAvailable() or not Player:BuffUp(S.SubterfugeBuff) and not Player:BuffUp(S.ShadowDanceBuff)) then
        if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot (FtH)" end
      end
    end
  end
  -- actions.build+=/pool_resource,for_next=1
  -- actions.build+=/ambush,if=talent.hidden_opportunity|talent.find_weakness&debuff.find_weakness.down
  if S.Ambush:IsCastable() and (Player:BuffUp(S.AudacityBuff) or Player:StealthUp(true, true))
    and (S.HiddenOpportunity:IsAvailable() or S.FindWeakness:IsAvailable() and not Target:DebuffUp(S.FindWeaknessDebuff)) then
    if HR.CastPooling(S.Ambush) then return "Cast Ambush (Pooling)" end
  end
  -- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|!talent.weaponmaster&combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
    if not S.FanTheHammer:IsAvailable() and S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and Player:BuffUp(S.Opportunity) then
    if (EnergyTimeToMax > 1.5 or S.QuickDraw:IsAvailable() or (S.Audacity:IsAvailable() and not Player:BuffUp(S.AudacityBuff))
      or (not S.Weaponmaster:IsAvailable() and ComboPointsDeficit <= 1 + num(Player:BuffUp(S.Broadside)))) then
      if HR.CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
    end
  end
  -- actions.build+=/sinister_strike
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
  Energy = EnergyPredictedStable()
  EnergyRegen = Player:EnergyRegen()
  EnergyTimeToMax = EnergyTimeToMaxStable(EnergyMaxOffset) -- energy.base_time_to_max
  EnergyDeficit = Player:EnergyDeficitPredicted(nil, EnergyMaxOffset) -- energy.base_deficit

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
  if not Player:AffectingCombat() and S.Vanish:TimeSinceLastCast() > 1 then
    -- Stealth
    if not Player:StealthUp(true, false) then
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
      -- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>25
      if CDsON() and S.MarkedforDeath:IsCastable() and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1 then
        if Settings.Commons.STMfDAsDPSCD then
          if HR.Cast(S.MarkedforDeath, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        else
          if HR.CastSuggested(S.MarkedforDeath) then return "Cast Marked for Death (OOC)" end
        end
      end
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
      if S.AdrenalineRush:IsReady() and S.ImprovedAdrenalineRush:IsAvailable() and ComboPoints <= 2 then
        if HR.Cast(S.AdrenalineRush) then return "Cast Adrenaline Rush (Opener)" end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=2
      -- Use same extended logic as a normal rotation for between pulls
      if S.RolltheBones:IsReady() and not Player:DebuffUp(S.Dreadblades) and (RtB_Buffs() == 0 or RtB_Reroll()) then
        if HR.Cast(S.RolltheBones) then return "Cast Roll the Bones (Opener)" end
      end
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if S.SliceandDice:IsReady() and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 then
        if HR.CastPooling(S.SliceandDice) then return "Cast Slice and Dice (Opener)" end
      end
      if Player:StealthUp(true, false) then
        ShouldReturn = Stealth()
        if ShouldReturn then return "Stealth (Opener): " .. ShouldReturn end
        if S.Ambush:IsCastable() then
          if HR.Cast(S.Ambush) then return "Cast Ambush (Opener)" end
        end
      elseif Finish_Condition() then
        ShouldReturn = Finish()
        if ShouldReturn then return "Finish (Opener): " .. ShouldReturn end
      end
      if S.SinisterStrike:IsCastable() then
        if HR.Cast(S.SinisterStrike) then return "Cast Sinister Strike (Opener)" end
      end
    end
    return
  end

  -- In Combat

  -- Fan the Hammer Combo Point Prediction
  if S.FanTheHammer:IsAvailable() and S.PistolShot:TimeSinceLastCast() < Player:GCDRemains() then
    ComboPoints = mathmax(ComboPoints, Rogue.FanTheHammerCP())
  end

  -- MfD Sniping (Higher Priority than APL)
  -- actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|combo_points.deficit>=cp_max_spend-1)&!buff.dreadblades.up
  -- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend-1&!buff.dreadblades.up
  if S.MarkedforDeath:IsCastable() then
    if EnemiesBFCount > 1 and Everyone.CastTargetIf(S.MarkedforDeath, Enemies30y, "min", EvaluateMfDTargetIfCondition, EvaluateMfDCondition, nil, Settings.Commons.OffGCDasOffGCD.MarkedforDeath) then
      return "Cast Marked for Death (Cycle)"
    elseif EnemiesBFCount == 1 and ComboPointsDeficit >= Rogue.CPMaxSpend() - 1 and not Player:DebuffUp(S.Dreadblades) then
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

    -- # Higher priority Stealth list for Count the Odds or true Stealth/Vanish that will break in a single global
    -- actions+=/call_action_list,name=stealth,if=stealthed.basic|buff.shadowmeld.up
    if Player:StealthUp(false, false) or Player:BuffUp(S.Shadowmeld) then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth: " .. ShouldReturn end
    end
    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end
    -- # Lower priority Stealth list for Shadow Dance
    -- actions+=/call_action_list,name=stealth,if=variable.stealthed_cto
    if Stealthed_CtO() then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth CtO: " .. ShouldReturn end
    end
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
  -- Nothing
end

HR.SetAPL(260, APL, Init)

--- ======= SIMC =======
-- Last Update: 2023-01-25

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/marked_for_death,precombat_seconds=10,if=raid_event.adds.in>25
-- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
-- actions.precombat+=/roll_the_bones,precombat_seconds=2
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/stealth

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth
-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick
-- # Checks if we are in an appropriate Stealth state for triggering the Count the Odds bonus
-- actions+=/variable,name=stealthed_cto,value=talent.count_the_odds&(stealthed.basic|buff.shadowmeld.up|buff.shadow_dance.up)
-- # Roll the Bones Reroll Conditions
-- actions+=/variable,name=rtb_reroll,if=!talent.hidden_opportunity,value=rtb_buffs<2&(!buff.broadside.up&(!talent.fan_the_hammer|!buff.skull_and_crossbones.up)&!buff.true_bearing.up|buff.loaded_dice.up)|rtb_buffs=2&(buff.buried_treasure.up&buff.grand_melee.up|!buff.broadside.up&!buff.true_bearing.up&buff.loaded_dice.up)
-- # Additional Reroll Conditions for Keep it Rolling or Count the Odds
-- actions+=/variable,name=rtb_reroll,if=!talent.hidden_opportunity&(talent.keep_it_rolling|talent.count_the_odds),value=variable.rtb_reroll|((rtb_buffs.normal=0&rtb_buffs.longer>=1)&!(buff.broadside.up&buff.true_bearing.up&buff.skull_and_crossbones.up)&!(buff.broadside.remains>39|buff.true_bearing.remains>39|buff.ruthless_precision.remains>39|buff.skull_and_crossbones.remains>39))
-- # With Hidden Opportunity, prioritize rerolling for Skull and Crossbones over everything else
-- actions+=/variable,name=rtb_reroll,if=talent.hidden_opportunity,value=!rtb_buffs.will_lose.skull_and_crossbones&(rtb_buffs.will_lose-rtb_buffs.will_lose.grand_melee)<2+buff.loaded_dice.up
-- # Avoid rerolls when we will not have time remaining on the fight or add wave to recoup the opportunity cost of the global
-- actions+=/variable,name=rtb_reroll,op=reset,if=!(raid_event.adds.remains>12|raid_event.adds.up&(raid_event.adds.in-raid_event.adds.remains)<6|target.time_to_die>12)|fight_remains<12
-- # Ensure we get full Ambush CP gains and aren't rerolling Count the Odds buffs away
-- actions+=/variable,name=ambush_condition,value=combo_points.deficit>=2+talent.improved_ambush+buff.broadside.up&energy>=50&(!talent.count_the_odds|buff.roll_the_bones.remains>=10)
-- # Finish at 6 (5 with Summarily Dispatched talented) CP or CP Max-1, whichever is greater of the two
-- actions+=/variable,name=finish_condition,value=combo_points>=((cp_max_spend-1)<?(6-talent.summarily_dispatched))|effective_combo_points>=cp_max_spend
-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>1+talent.killing_spree.enabled
-- # Higher priority Stealth list for Count the Odds or true Stealth/Vanish that will break in a single global
-- actions+=/call_action_list,name=stealth,if=stealthed.basic|buff.shadowmeld.up
-- actions+=/call_action_list,name=cds
-- # Lower priority Stealth list for Shadow Dance
-- actions+=/call_action_list,name=stealth,if=variable.stealthed_cto
-- actions+=/run_action_list,name=finish,if=variable.finish_condition
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.base_deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks

-- # Builders
-- actions.build=sepsis,target_if=max:target.time_to_die*debuff.between_the_eyes.up,if=target.time_to_die>11&debuff.between_the_eyes.up|fight_remains<11
-- actions.build+=/ghostly_strike,if=debuff.ghostly_strike.remains<=3&(spell_targets.blade_flurry<=2|buff.dreadblades.up)&!buff.subterfuge.up&target.time_to_die>=5
-- actions.build+=/echoing_reprimand,if=!buff.dreadblades.up
-- # High priority Ambush line to apply Find Weakness or consume Audacity/Sepsis buff before Pistol Shot
-- actions.build+=/ambush,if=(talent.hidden_opportunity|talent.keep_it_rolling)&(buff.audacity.up|buff.sepsis_buff.up|buff.subterfuge.up&cooldown.keep_it_rolling.ready)|talent.find_weakness&debuff.find_weakness.down
-- # With Audacity + Hidden Opportunity + Fan the Hammer, use Pistol Shot to proc Audacity any time Ambush is not available
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up&!buff.subterfuge.up&!buff.shadow_dance.up
-- # Use Greenskins Wickers buff immediately with Opportunity unless running Fan the Hammer
-- actions.build+=/pistol_shot,if=buff.greenskins_wickers.up&(!talent.fan_the_hammer&buff.opportunity.up|buff.greenskins_wickers.remains<1.5)
-- # With Fan the Hammer, consume Opportunity at max stacks or if we will get max 4+ CP and Dreadblades is not up
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&combo_points.deficit>((1+talent.quick_draw)*talent.fan_the_hammer.rank)&!buff.dreadblades.up&(!talent.hidden_opportunity|!buff.subterfuge.up&!buff.shadow_dance.up)
-- actions.build+=/pool_resource,for_next=1
-- actions.build+=/ambush,if=talent.hidden_opportunity|talent.find_weakness&debuff.find_weakness.down
-- # Use Pistol Shot with Opportunity if Combat Potency won't overcap energy, when it will exactly cap CP, or when using Quick Draw
-- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|!talent.weaponmaster&combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
-- actions.build+=/sinister_strike

-- # Cooldowns
-- actions.cds=adrenaline_rush,if=!buff.adrenaline_rush.up&(!talent.improved_adrenaline_rush|combo_points<=2)
-- actions.cds+=/blade_flurry,if=spell_targets>=2&buff.blade_flurry.remains<gcd
-- actions.cds+=/roll_the_bones,if=buff.dreadblades.down&(rtb_buffs.total=0|variable.rtb_reroll)
-- actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&(buff.broadside.up+buff.true_bearing.up+buff.skull_and_crossbones.up+buff.ruthless_precision.up)>2&(buff.shadow_dance.down|rtb_buffs>=6)
-- actions.cds+=/blade_rush,if=variable.blade_flurry_sync&!buff.dreadblades.up&(energy.base_time_to_max>4+stealthed.rogue-spell_targets%3)
-- actions.cds+=/call_action_list,name=stealth_cds,if=!stealthed.all|talent.count_the_odds&!variable.stealthed_cto
-- actions.cds+=/dreadblades,if=!(variable.stealthed_cto|stealthed.basic|talent.hidden_opportunity&stealthed.rogue)&combo_points<=2&(!talent.marked_for_death|!cooldown.marked_for_death.ready)&target.time_to_die>=10
-- # If adds are up, snipe the one with lowest TTD. Use when dying faster than CP deficit or without any CP.
-- actions.cds+=/marked_for_death,line_cd=1.5,target_if=min:target.time_to_die,if=raid_event.adds.up&(target.time_to_die<combo_points.deficit|combo_points.deficit>=cp_max_spend-1)&!buff.dreadblades.up
-- # If no adds will die within the next 30s, use MfD on boss without any CP.
-- actions.cds+=/marked_for_death,if=raid_event.adds.in>30-raid_event.adds.duration&combo_points.deficit>=cp_max_spend-1&!buff.dreadblades.up
-- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.base_deficit>=100|fight_remains<charges*6)
-- actions.cds+=/killing_spree,if=variable.blade_flurry_sync&!stealthed.rogue&debuff.between_the_eyes.up&energy.base_time_to_max>4
-- actions.cds+=/shadowmeld,if=!stealthed.all&(talent.count_the_odds&variable.finish_condition|!talent.weaponmaster.enabled&variable.ambush_condition)
-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call
-- # Default conditions for usable items.
-- actions.cds+=/use_item,name=manic_grieftorch,if=!stealthed.all&!buff.adrenaline_rush.up|fight_remains<5
-- actions.cds+=/use_item,name=stormeaters_boon,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<10
-- actions.cds+=/use_item,name=windscar_whetstone,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<7
-- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
-- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20

-- # Stealth Cooldowns
-- actions.stealth_cds=variable,name=vanish_condition,value=talent.hidden_opportunity|!talent.shadow_dance|!cooldown.shadow_dance.ready
-- actions.stealth_cds+=/variable,name=vanish_opportunity_condition,value=!talent.shadow_dance&talent.fan_the_hammer.rank+talent.quick_draw+talent.audacity<talent.count_the_odds+talent.keep_it_rolling
-- actions.stealth_cds+=/vanish,if=talent.find_weakness&!talent.audacity&debuff.find_weakness.down&variable.ambush_condition&variable.vanish_condition
-- actions.stealth_cds+=/vanish,if=talent.hidden_opportunity&!buff.audacity.up&(variable.vanish_opportunity_condition|buff.opportunity.stack<buff.opportunity.max_stack)&variable.ambush_condition&variable.vanish_condition
-- actions.stealth_cds+=/vanish,if=(!talent.find_weakness|talent.audacity)&!talent.hidden_opportunity&variable.finish_condition&variable.vanish_condition
-- actions.stealth_cds+=/variable,name=shadow_dance_condition,value=talent.shadow_dance&debuff.between_the_eyes.up&(!talent.ghostly_strike|debuff.ghostly_strike.up)&(!talent.dreadblades|!cooldown.dreadblades.ready)&(!talent.hidden_opportunity|!buff.audacity.up&(talent.fan_the_hammer.rank<2|!buff.opportunity.up))
-- actions.stealth_cds+=/shadow_dance,if=!talent.keep_it_rolling&variable.shadow_dance_condition&buff.slice_and_dice.up&(variable.finish_condition|talent.hidden_opportunity)&(!talent.hidden_opportunity|!cooldown.vanish.ready)
-- actions.stealth_cds+=/shadow_dance,if=talent.keep_it_rolling&variable.shadow_dance_condition&(cooldown.keep_it_rolling.remains<=30|cooldown.keep_it_rolling.remains>120&(variable.finish_condition|talent.hidden_opportunity))

-- # Finishers
-- # BtE to keep the Crit debuff up, if RP is up, or for Greenskins, unless the target is about to die.
-- actions.finish=between_the_eyes,if=target.time_to_die>3&(debuff.between_the_eyes.remains<4|talent.greenskins_wickers&!buff.greenskins_wickers.up|!talent.greenskins_wickers&buff.ruthless_precision.up)
-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable&(!talent.swift_slasher|combo_points>=cp_max_spend)
-- actions.finish+=/cold_blood
-- actions.finish+=/dispatch

-- # Stealth
-- actions.stealth=blade_flurry,if=talent.subterfuge&talent.hidden_opportunity&spell_targets>=2&!buff.blade_flurry.up
-- actions.stealth+=/cold_blood,if=variable.finish_condition
-- actions.stealth+=/dispatch,if=variable.finish_condition
-- actions.stealth+=/ambush,if=variable.stealthed_cto|stealthed.basic&talent.find_weakness&!debuff.find_weakness.up|talent.hidden_opportunity

