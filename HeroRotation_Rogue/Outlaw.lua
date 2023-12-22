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
local Cast = HR.Cast
local CastPooling = HR.CastPooling
local CastSuggested = HR.CastSuggested
local CastAnnotated = HR.CastAnnotated
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
  I.DragonfireBombDispenser:ID(),
  I.BeaconToTheBeyond:ID()
}

-- Trinkets
local Equipment = Player:GetEquipment()
local trinket1 = Equipment[13] and Item(Equipment[13]) or Item(0)
local trinket2 = Equipment[14] and Item(Equipment[14]) or Item(0)

HL:RegisterForEvent(function()
  Equipment = Player:GetEquipment()
  trinket1 = Equipment[13] and Item(Equipment[13]) or Item(0)
  trinket2 = Equipment[14] and Item(Equipment[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED" )

-- Rotation Var
local Enemies30y, EnemiesBF, EnemiesBFCount
local ShouldReturn; -- Used to get the return string
local BladeFlurryRange = 6
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
      Cache.APLVar.RtB_Reroll = false
      RtB_Buffs()
      -- # Default Roll the Bones reroll rule: reroll for any buffs that aren't Buried Treasure, excluding Grand Melee in single target
      -- actions+=/variable,name=rtb_reroll,value=rtb_buffs.will_lose=
      -- (rtb_buffs.will_lose.buried_treasure+rtb_buffs.will_lose.grand_melee&spell_targets.blade_flurry<2&raid_event.adds.in>10)
      if RtB_Buffs() <= 2 and Player:BuffUp(S.BuriedTreasure) and Player:BuffDown(S.GrandMelee) and EnemiesBFCount < 2 then
        Cache.APLVar.RtB_Reroll = true
      end

      -- # Crackshot builds without T31 should reroll for True Bearing (or Broadside without Hidden Opportunity) if we won't lose over 1 buff
      -- actions+=/variable,name=rtb_reroll,if=talent.crackshot&talent.hidden_opportunity&!set_bonus.tier31_4pc,value=
      -- (!rtb_buffs.will_lose.true_bearing&talent.hidden_opportunity|!rtb_buffs.will_lose.broadside&!talent.hidden_opportunity)&rtb_buffs.will_lose<=1
      if S.Crackshot:IsAvailable() and S.HiddenOpportunity:IsAvailable() and not Player:HasTier(31, 4)
        and (not Player:BuffUp(S.TrueBearing) and S.HiddenOpportunity:IsAvailable() or not Player:BuffUp(S.Broadside) and not S.HiddenOpportunity:IsAvailable()) and RtB_Buffs() <= 1 then
        Cache.APLVar.RtB_Reroll = true
      end

      -- # Crackshot builds with T31 should reroll if we won't lose over 1 buff (2 with Loaded Dice)
      -- actions+=/variable,name=rtb_reroll,if=talent.crackshot&set_bonus.tier31_4pc,value=
      -- (rtb_buffs.will_lose<=1+buff.loaded_dice.up)&(talent.hidden_opportunity|!buff.broadside.up)
      if S.Crackshot:IsAvailable() and Player:HasTier(31, 4)
        and (RtB_Buffs() <= 1 + num(Player:BuffUp(S.LoadedDiceBuff))) then
        Cache.APLVar.RtB_Reroll = true
      end

      -- # Hidden Opportunity builds without Crackshot should reroll for Skull and Crossbones or any 2 buffs excluding Grand Melee in single target
      -- actions+=/variable,name=rtb_reroll,if=!talent.crackshot&talent.hidden_opportunity,value=!rtb_buffs.will_lose.skull_and_crossbones
      -- &(rtb_buffs.will_lose<2+rtb_buffs.will_lose.grand_melee&spell_targets.blade_flurry<2&raid_event.adds.in>10)
      if not S.Crackshot:IsAvailable() and S.HiddenOpportunity:IsAvailable() and not Player:BuffUp(S.SkullandCrossbones)
        and (RtB_Buffs() < 2 + num(Player:BuffUp(S.GrandMelee)) and EnemiesBFCount < 2) then
        Cache.APLVar.RtB_Reroll = true
      end

      -- # Additional reroll rules if all active buffs will not be rolled away and we don't already have 5+ buffs
      -- actions+/variable,name=rtb_reroll,value=variable.rtb_reroll|rtb_buffs.normal=0&rtb_buffs.longer>=1&rtb_buffs<5&rtb_buffs.max_remains<=39
      if Cache.APLVar.RtB_Reroll and (Cache.APLVar.RtB_Buffs.Longer == 0 or Cache.APLVar.RtB_Buffs.Normal == 0) and Cache.APLVar.RtB_Buffs.Longer >= 1 and RtB_Buffs() < 5 and Rogue.RtBRemains() <= 39
      and not Player:StealthUp(true, true) then
        Cache.APLVar.RtB_Reroll = true
      end

      -- # Avoid rerolls when we will not have time remaining on the fight or add wave to recoup the opportunity cost of the global
      -- actions+=/variable,name=rtb_reroll,op=reset,if=!(raid_event.adds.remains>12|raid_event.adds.up
      -- &(raid_event.adds.in-raid_event.adds.remains)<6|target.time_to_die>12)|fight_remains<12
      if Target:FilteredTimeToDie("<", 12) or HL.BossFilteredFightRemains("<", 12) then
        Cache.APLVar.RtB_Reroll = false
      end
    end
  end

  return Cache.APLVar.RtB_Reroll
end

-- # Use finishers if at -1 from max combo points, or -2 in Stealth with Crackshot
local function Finish_Condition ()
  -- actions+=/variable,name=finish_condition,value=effective_combo_points>=cp_max_spend-1-(stealthed.all&talent.crackshot)
  return EffectiveComboPoints >= Rogue.CPMaxSpend()-1-num((Player:StealthUp(true, true)) and S.Crackshot:IsAvailable())
end

-- # Ensure we want to cast Ambush prior to triggering a Stealth cooldown
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=(talent.hidden_opportunity|combo_points.deficit>=2+talent.improved_ambush+buff.broadside.up)&energy>=50
  return (S.HiddenOpportunity:IsAvailable() or ComboPointsDeficit >=2 + num(S.ImprovedAmbush:IsAvailable()) + num(Player:BuffUp(S.Broadside))) and Energy >= 50
end

-- Determine if we are allowed to use Vanish offensively in the current situation
local function Vanish_DPS_Condition ()
  -- You can vanish if we've set the UseDPSVanish setting, and we're either not tanking or we're solo but the DPS vanish while solo flag is set).
  return Settings.Commons2.UseDPSVanish and (not Player:IsTanking(Target) or Settings.Commons2.UseSoloVanish)
end

local function Vanish_Opportunity_Condition ()
  -- actions.stealth_cds=variable,name=vanish_opportunity_condition,value=!talent.shadow_dance&talent.fan_the_hammer.rank+talent.quick_draw+talent.audacity<talent.count_the_odds+talent.keep_it_rolling
  return not S.ShadowDanceTalent:IsAvailable()
    and S.FanTheHammer:TalentRank() + num(S.QuickDraw:IsAvailable()) + num(S.Audacity:IsAvailable()) < num(S.CountTheOdds:IsAvailable()) + num(S.KeepItRolling:IsAvailable())
end

local function Shadow_Dance_Condition ()
  -- # Hidden Opportunity builds without Crackshot use Dance if Audacity and Opportunity are not active
  -- actions.stealth_cds+=/variable,name=shadow_dance_condition,value=buff.between_the_eyes.up
  -- &(!talent.hidden_opportunity|!buff.audacity.up&(talent.fan_the_hammer.rank<2|!buff.opportunity.up))&!talent.crackshot
  return Player:BuffUp(S.BetweentheEyes) and (not S.HiddenOpportunity:IsAvailable() or Player:BuffDown(S.AudacityBuff)
    and (S.FanTheHammer:TalentRank() < 2 or Player:BuffDown(S.Opportunity))) and not S.Crackshot:IsAvailable()
end


local function StealthCDs ()
  -- # Hidden Opportunity builds without Crackshot use Vanish if Audacity is not active and when under max Opportunity stacks
  -- actions.stealth_cds+=/vanish,if=talent.hidden_opportunity&!talent.crackshot&!buff.audacity.up&(variable.vanish_opportunity_condition|buff.opportunity.stack<buff.opportunity.max_stack)&variable.ambush_condition
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() and S.HiddenOpportunity:IsAvailable() and not S.Crackshot:IsAvailable() and not Player:BuffUp(S.Audacity)
    and (Vanish_Opportunity_Condition() or Player:BuffStack(S.Opportunity) < 6) and Ambush_Condition() then
    if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (HO)" end
  end

  -- # Crackshot builds or builds without Hidden Opportunity use Vanish at finish condition
  -- actions.stealth_cds+=/vanish,if=(!talent.hidden_opportunity|talent.crackshot)&variable.finish_condition
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() and (not S.HiddenOpportunity:IsAvailable() or S.Crackshot:IsAvailable()) and Finish_Condition() then
    if Cast(S.Vanish, Settings.Commons.OffGCDasOffGCD.Vanish) then return "Cast Vanish (Finish)" end
  end

  -- # Crackshot builds use Dance at finish condition
  -- actions.stealth_cds+=/shadow_dance,if=talent.crackshot&variable.finish_condition
  -- synecdoche note: DPS gain in testing to hold off on shadow dance if vanish is coming up in the next 6 seconds to avoid wasting vanish CDR
  if S.ShadowDance:IsAvailable() and S.ShadowDance:IsCastable() and S.Crackshot:IsAvailable() and Finish_Condition() and S.Vanish:CooldownRemains() >= 6 then
    if Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
  end

  -- actions.stealth_cds+=/shadow_dance,if=!talent.keep_it_rolling&variable.shadow_dance_condition&buff.slice_and_dice.up
  -- &(variable.finish_condition|talent.hidden_opportunity)&(!talent.hidden_opportunity|!cooldown.vanish.ready)
  if S.ShadowDance:IsAvailable() and S.ShadowDance:IsCastable() and not S.KeepItRolling:IsAvailable() and Shadow_Dance_Condition() and Player:BuffUp(S.SliceandDice)
      and (Finish_Condition() or S.HiddenOpportunity:IsAvailable()) and (not S.HiddenOpportunity:IsAvailable() or not S.Vanish:IsReady()) then
    if Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
  end

  -- # Keep it Rolling builds without Crackshot use Dance at finish condition but hold it for an upcoming Keep it Rolling
  -- actions.stealth_cds+=/shadow_dance,if=talent.keep_it_rolling&variable.shadow_dance_condition
  -- &(cooldown.keep_it_rolling.remains<=30|cooldown.keep_it_rolling.remains>120&(variable.finish_condition|talent.hidden_opportunity))
  if S.ShadowDance:IsAvailable() and S.ShadowDance:IsCastable() and S.KeepItRolling:IsAvailable() and Shadow_Dance_Condition()
    and (S.KeepItRolling:CooldownRemains() <= 30 or S.KeepItRolling:CooldownRemains() >= 120 and (Finish_Condition() or S.HiddenOpportunity:IsAvailable())) then
    if Cast(S.ShadowDance, Settings.Commons.OffGCDasOffGCD.ShadowDance) then return "Cast Shadow Dance" end
  end

  -- actions.stealth_cds+=/shadowmeld,if=talent.crackshot&variable.finish_condition|!talent.crackshot&(talent.count_the_odds&variable.finish_condition|talent.hidden_opportunity)
  if S.Shadowmeld:IsAvailable() and S.Shadowmeld:IsReady() then
    if S.Crackshot:IsAvailable() and Finish_Condition() or not S.Crackshot:IsAvailable() and (S.CountTheOdds:IsAvailable() and Finish_Condition() or S.HiddenOpportunity:IsAvailable()) then
      if Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Shadowmeld" end
    end
  end
end

local function CDs ()
  -- # Cooldowns Use Adrenaline Rush if it is not active and at 2cp if Improved, but Crackshot builds can refresh it in stealth
  -- actions.cds=adrenaline_rush,if=(!buff.adrenaline_rush.up|stealthed.all&talent.crackshot&talent.improved_adrenaline_rush)
  -- &(combo_points<=2|!talent.improved_adrenaline_rush)
  if CDsON() and S.AdrenalineRush:IsCastable()
    and (not Player:BuffUp(S.AdrenalineRush) or Player:StealthUp(true, true) and S.Crackshot:IsAvailable() and S.ImprovedAdrenalineRush:IsAvailable())
    and (ComboPoints <= 2 or not S.ImprovedAdrenalineRush:IsAvailable()) then
    if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then return "Cast Adrenaline Rush" end
  end

  -- # Maintain Blade Flurry on 2+ targets, and on single target with Underhanded, or on cooldown at 5+ targets with Deft Maneuvers
  -- actions.cds+=/blade_flurry,if=(spell_targets>=2-talent.underhanded_upper_hand&!stealthed.rogue)
  -- &buff.blade_flurry.remains<gcd|talent.deft_maneuvers&spell_targets>=5&!variable.finish_condition
  -- synecdoche note: ravenholdt testing suggests this is a damage gain on 3+ targets if flurrying will cap your CP
  if S.BladeFlurry:IsReady() then
    local bf_cp_gen = EnemiesBFCount + num(Player:BuffUp(S.Broadside))
    if (EnemiesBFCount >= 2 - num(S.UnderhandedUpperhand:IsAvailable()) and not Player:StealthUp(true, false))
      and Player:BuffRemains(S.BladeFlurry) < Player:GCDRemains() or S.DeftManeuvers:IsAvailable() and EnemiesBFCount >= 3 and bf_cp_gen >= ComboPointsDeficit and not Finish_Condition() then
      if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
        CastSuggested(S.BladeFlurry)
      else
        if Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
      end
    end
  end

  -- # Use Roll the Bones if reroll conditions are met, or just before buffs expire based on T31 and upcoming stealth cooldowns
  -- actions.cds+=/roll_the_bones,if=variable.rtb_reroll|rtb_buffs.max_remains<=set_bonus.tier31_4pc+(cooldown.shadow_dance.remains<=1|cooldown.vanish.remains<=1)*6
  -- synecdoche note: also don't want to roll the bones inside a crackshot window; this isn't actually captured by the APL, but is a damage gain in local testing
  if S.RolltheBones:IsReady() then
    local outside_crackshot_window = not Player:StealthUp(true, true) or not S.Crackshot:IsAvailable()
    if outside_crackshot_window and (RtB_Reroll() or Rogue.RtBRemains() <= num(Player:HasTier(31, 4)) + num(S.ShadowDance:CooldownRemains() <=1 or S.Vanish:CooldownRemains() <= 1) * 6) then
      if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then return "Cast Roll the Bones" end
    end
  end

  -- # Use Keep it Rolling with at least 3 buffs (4 with T31)
  -- actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&rtb_buffs>=3+set_bonus.tier31_4pc&(buff.shadow_dance.down|rtb_buffs>=6)
  if S.KeepItRolling:IsReady() and not RtB_Reroll() and  RtB_Buffs() >= 3 + num(Player:HasTier(31, 4)) and (Player:BuffDown(S.ShadowDance) or RtB_Buffs() >= 6) then
    if Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then return "Cast Keep it Rolling" end
  end

  --actions.cds+=/ghostly_strike
  if S.GhostlyStrike:IsAvailable() and S.GhostlyStrike:IsReady() then
    if Cast(S.GhostlyStrike, Settings.Outlaw.OffGCDasOffGCD.GhostlyStrike) then return "Cast Ghostly Strike" end
  end

  -- # Use Sepsis to trigger Crackshot or if the target will survive its DoT
  -- actions.cds+=/sepsis,if=talent.crackshot&cooldown.between_the_eyes.ready&variable.finish_condition&!stealthed.all
  -- |!talent.crackshot&target.time_to_die>11&buff.between_the_eyes.up|fight_remains<11
  if CDsON() and S.Sepsis:IsAvailable() and S.Sepsis:IsReady() then
    if S.Crackshot:IsAvailable() and S.BetweentheEyes:IsReady() and Finish_Condition() and not Player:StealthUp(true, true)
      or not S.Crackshot:IsAvailable() and Target:FilteredTimeToDie(">", 11) and Player:BuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 11) then
      if Cast(S.Sepsis, Settings.Outlaw.GCDasOffGCD.Sepsis) then return "Cast Sepsis" end
    end
  end

  -- # Use Blade Rush at minimal energy outside of stealth
  -- actions.cds+=/blade_rush,if=energy.base_time_to_max>4&!stealthed.all
  if S.BladeRush:IsReady() and EnergyTimeToMax > 4 and not Player:StealthUp(true, true) then
    if Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush) then return "Cast Blade Rush" end
  end

  -- actions.cds+=/call_action_list,name=stealth_cds,if=!stealthed.all
  if not Player:StealthUp(true, true, true) then
    ShouldReturn = StealthCDs()
    if ShouldReturn then return ShouldReturn end
  end

  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.base_deficit>=100|fight_remains<charges*6)
  if CDsON() and S.ThistleTea:IsCastable() and not Player:BuffUp(S.ThistleTea)
    and (EnergyDeficit >= 100 or HL.BossFilteredFightRemains("<", S.ThistleTea:Charges()*6)) then
    if Cast(S.ThistleTea, Settings.Commons.OffGCDasOffGCD.ThistleTea) then return "Cast Thistle Tea" end
  end

  -- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 30) or Player:BuffUp(S.AdrenalineRush)) then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "Cast Potion"; end
    end
  end

  -- actions.cds+=/blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Blood Fury" end
  end

  -- actions.cds+=/berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
  end

  -- actions.cds+=/fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
  end

  -- actions.cds+=/ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Ancestral Call" end
  end

  -- # Default conditions for usable items.
  if Settings.Commons.Enabled.Trinkets then
    -- actions.cds+=/use_item,name=manic_grieftorch,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!stealthed.all&buff.between_the_eyes.up|fight_remains<=5
    if I.ManicGrieftorch:IsEquippedAndReady() then
      if Player:GCDRemains() > Player:GCD()-0.1 and not Player:StealthUp(true, true) and Player:BuffUp(S.BetweentheEyes) or
        HL.BossFilteredFightRemains("<=", 5) then
        if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Manic Grieftorch"; end
      end
    end

    -- actions.cds+=/use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=(!trinket.1.is.dragonfire_bomb_dispenser&trinket.1.cooldown.remains>10
    -- |trinket.2.cooldown.remains>10)|cooldown.dragonfire_bomb_dispenser.charges>2|fight_remains<20|!trinket.2.has_cooldown|!trinket.1.has_cooldown
    if I.DragonfireBombDispenser:IsEquippedAndReady() then
      if (not trinket1:ID() == I.DragonfireBombDispenser:ID() and trinket1:CooldownRemains() > 10 or
        trinket2:CooldownRemains() > 10) or HL.BossFilteredFightRemains("<", 20) or not trinket2:HasCooldown() or not trinket1:HasCooldown() then
        if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Dragonfire Bomb Dispenser"; end
      end
    end

   -- actions.cds+=/use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!stealthed.all&buff.between_the_eyes.up|fight_remains<=5
    if I.BeaconToTheBeyond:IsEquippedAndReady() then
      if not Player:StealthUp(true, true) and Player:BuffUp(S.BetweentheEyes)
        or HL.BossFilteredFightRemains("<", 5) then
        if Cast(I.BeaconToTheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Beacon"; end
      end
    end

    -- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
    -- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20
    local TrinketToUse = Player:GetUseableItems(OnUseExcludes, 13) or Player:GetUseableItems(OnUseExcludes, 14)
    if TrinketToUse and (Player:BuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 20) or TrinketToUse:HasStatAnyDps()) then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name() end
    end
  end
end

local function Stealth()
	-- actions.stealth=blade_flurry,if=talent.subterfuge&talent.hidden_opportunity&spell_targets>=2&buff.blade_flurry.remains<gcd
	if S.BladeFlurry:IsReady() and S.BladeFlurry:IsCastable() and AoEON() and S.Subterfuge:IsAvailable() and S.HiddenOpportunity:IsAvailable() and EnemiesBFCount >= 2
		and Player:BuffRemains(S.BladeFlurry) <= Player:GCDRemains() then
		if Settings.Outlaw.GCDasOffGCD.BladeFlurry then
		  CastSuggested(S.BladeFlurry)
		else
		  if Cast(S.BladeFlurry) then return "Cast Blade Flurry" end
		end
	end

	-- actions.stealth+=/cold_blood,if=variable.finish_condition
	if S.ColdBlood:IsCastable() and Player:BuffDown(S.ColdBlood) and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
		if Cast(S.ColdBlood, Settings.Commons.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
	end

	-- actions.stealth+=/between_the_eyes,if=variable.finish_condition&talent.crackshot
	if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) and Finish_Condition() and S.Crackshot:IsAvailable() then
		if CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
	end

	-- actions.stealth+=/dispatch,if=variable.finish_condition
	if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) and Finish_Condition() then
		if CastPooling(S.Dispatch) then return "Cast Dispatch" end
	end

	-- # 2 Fan the Hammer Crackshot builds can consume Opportunity in stealth with max stacks, Broadside, and low CPs, or with Greenskins active
	-- actions.stealth+=/pistol_shot,if=talent.crackshot&talent.fan_the_hammer.rank>=2&buff.opportunity.stack>=6
	-- &(buff.broadside.up&combo_points<=1|buff.greenskins_wickers.up)
	if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and S.Crackshot:IsAvailable() and S.FanTheHammer:TalentRank() >= 2 and Player:BuffStack(S.Opportunity) >= 6
		and (Player:BuffUp(S.Broadside) and ComboPoints <= 1 or Player:BuffUp(S.GreenskinsWickersBuff)) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
	end

	-- actions.stealth+=/ambush,if=talent.hidden_opportunity
	if S.Ambush:IsCastable() and Target:IsSpellInRange(S.Ambush) and S.HiddenOpportunity:IsAvailable() then
		if CastPooling(S.Ambush) then return "Cast Ambush" end
	end
end

local function Finish ()
	-- # Finishers Use Between the Eyes to keep the crit buff up, but on cooldown if Improved/Greenskins/T30, and avoid overriding Greenskins
	-- actions.finish=between_the_eyes,if=!talent.crackshot
	-- &(buff.between_the_eyes.remains<4|talent.improved_between_the_eyes|talent.greenskins_wickers|set_bonus.tier30_4pc)
	-- &!buff.greenskins_wickers.up
	if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) and not S.Crackshot:IsAvailable()
		and (Player:BuffRemains(S.BetweentheEyes) < 4 or S.ImprovedBetweenTheEyes:IsAvailable() or S.GreenskinsWickers:IsAvailable()
    or Player:HasTier(30, 4)) and Player:BuffDown(S.GreenskinsWickers) then
		if CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
	end

	-- #Crackshot builds use Between the Eyes outside of Stealth if Vanish or Dance will not come off cooldown within the next cast
	-- actions.finish+=/between_the_eyes,if=talent.crackshot&(cooldown.vanish.remains>45&cooldown.shadow_dance.remains>12)
	if S.BetweentheEyes:IsCastable() and Target:IsSpellInRange(S.BetweentheEyes) and S.Crackshot:IsAvailable()
		and (S.Vanish:CooldownRemains() > 45 and S.ShadowDance:CooldownRemains() > 12) then
		if CastPooling(S.BetweentheEyes) then return "Cast Between the Eyes" end
	end

	-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable
	-- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
	if S.SliceandDice:IsCastable() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
		and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 then
		if CastPooling(S.SliceandDice) then return "Cast Slice and Dice" end
	end

	-- actions.finish+=/killing_spree,if=debuff.ghostly_strike.up|!talent.ghostly_strike
	if S.KillingSpree:IsCastable() and Target:IsSpellInRange(S.KillingSpree) and (Target:DebuffUp(S.GhostlyStrike) or not S.GhostlyStrike:IsAvailable()) then
		if Cast(S.KillingSpree) then return "Cast Killing Spree" end
	end

  if S.ColdBlood:IsCastable() and Player:BuffDown(S.ColdBlood) and Target:IsSpellInRange(S.Dispatch) then
    if Cast(S.ColdBlood, Settings.Commons.OffGCDasOffGCD.ColdBlood) then return "Cast Cold Blood" end
  end
  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() and Target:IsSpellInRange(S.Dispatch) then
    if CastPooling(S.Dispatch) then return "Cast Dispatch" end
  end
end

local function Build ()
	-- actions.build+=/echoing_reprimand
	if CDsON() and S.EchoingReprimand:IsReady() then
		if Cast(S.EchoingReprimand, Settings.Commons.GCDasOffGCD.EchoingReprimand) then
			return "Cast Echoing Reprimand"
		end
	end

	-- actions.build+=/ambush,if=talent.hidden_opportunity&buff.audacity.up
  if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.AudacityBuff) then
    if CastPooling(S.Ambush) then return "Cast Ambush (High-Prio Buffed)" end
  end

	-- # With Audacity + Hidden Opportunity + Fan the Hammer, consume Opportunity to proc Audacity any time Ambush is not available
	-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up
	if S.FanTheHammer:IsAvailable() and S.Audacity:IsAvailable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.Opportunity) and Player:BuffDown(S.AudacityBuff) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot (Audacity)" end
	end

	-- # Use Greenskins Wickers buff immediately with Opportunity unless running Fan the Hammer
	-- actions.build+=/pistol_shot,if=buff.greenskins_wickers.up&(!talent.fan_the_hammer&buff.opportunity.up|buff.greenskins_wickers.remains<1.5)
	if Player:BuffUp(S.GreenskinsWickersBuff) and (not S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) or Player:BuffRemains(S.GreenskinsWickersBuff) < 1.5) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot (GSW Dump)" end
	end

	-- #With Fan the Hammer, consume Opportunity at max stacks or if it will expire
	-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)
	if S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and (Player:BuffStack(S.Opportunity) >= 6 or Player:BuffRemains(S.Opportunity) < 2) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot (FtH Dump)" end
	end

	-- # With Fan the Hammer, consume Opportunity based on CP deficit, and 2 Fan the Hammer Crackshot builds can briefly hold stacks for an upcoming stealth cooldown
	-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&combo_points.deficit>((1+talent.quick_draw)*talent.fan_the_hammer.rank)
	-- &(!cooldown.vanish.ready&!cooldown.shadow_dance.ready|stealthed.all|!talent.crackshot|talent.fan_the_hammer.rank<=1)
	if S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and ComboPointsDeficit > (1+num(S.QuickDraw:IsAvailable())*S.FanTheHammer:TalentRank())
		and (not S.Vanish:IsReady() and not S.ShadowDance:IsReady() or Player:StealthUp(true, true) or not S.Crackshot:IsAvailable() or S.FanTheHammer:TalentRank() <= 1) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
	end

	-- #If not using Fan the Hammer, then consume Opportunity based on energy, when it will exactly cap CPs, or when using Quick Draw
	-- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up
	-- &(energy.base_deficit>energy.regen*1.5|combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
	if not S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity)
		and (EnergyTimeToMax > 1.5 or ComboPointsDeficit <= 1 + num(Player:BuffUp(S.Broadside)) or S.QuickDraw:IsAvailable() or S.Audacity:IsAvailable() and Player:BuffDown(S.AudacityBuff)) then
		if CastPooling(S.PistolShot) then return "Cast Pistol Shot" end
	end

  -- actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
    if CastPooling(S.SinisterStrike) then return "Cast Sinister Strike" end
  end
end

--- ======= MAIN =======
local function APL ()
  -- Local Update
  BladeFlurryRange = S.AcrobaticStrikes:IsAvailable() and 9 or 6
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

  -- Poisons
  Rogue.Poisons()

  -- Out of Combat
  if not Player:AffectingCombat() and S.Vanish:TimeSinceLastCast() > 1 then
    -- actions.precombat+=/blade_flurry,precombat_seconds=4,if=talent.underhanded_upper_hand
    -- Blade Flurry Breaks Stealth so must be done first
    if S.BladeFlurry:IsReady() and Player:BuffDown(S.BladeFlurry) and S.UnderhandedUpperhand:IsAvailable() and not Player:StealthUp(true, true) then
      if Cast(S.BladeFlurry) then return "Blade Flurry (Opener)" end
    end

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
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
      if S.AdrenalineRush:IsReady() and S.ImprovedAdrenalineRush:IsAvailable() and ComboPoints <= 2 then
        if Cast(S.AdrenalineRush) then return "Cast Adrenaline Rush (Opener)" end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=2
      -- Use same extended logic as a normal rotation for between pulls
      if S.RolltheBones:IsReady() and not Player:DebuffUp(S.Dreadblades) and (RtB_Buffs() == 0 or RtB_Reroll()) then
        if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then return "Cast Roll the Bones (Opener)" end
      end
      -- actions.precombat+=/slice_and_dice,precombat_seconds=1
      if S.SliceandDice:IsReady() and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 then
        if CastPooling(S.SliceandDice) then return "Cast Slice and Dice (Opener)" end
      end
      if Player:StealthUp(true, false) then
        ShouldReturn = Stealth()
        if ShouldReturn then return "Stealth (Opener): " .. ShouldReturn end
        if S.KeepItRolling:IsAvailable() and S.GhostlyStrike:IsReady() and S.EchoingReprimand:IsAvailable() then
          if Cast(S.GhostlyStrike) then return "Cast Ghostly Strike KiR (Opener)" end
        end
        if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() then
          if Cast(S.Ambush) then return "Cast Ambush (Opener)" end
        else
          if S.SinisterStrike:IsCastable() then
            if Cast(S.SinisterStrike) then return "Cast Sinister Strike (Opener)" end
          end
        end
      elseif Finish_Condition() then
        ShouldReturn = Finish()
        if ShouldReturn then return "Finish (Opener): " .. ShouldReturn end
      end
      if S.SinisterStrike:IsCastable() then
        if Cast(S.SinisterStrike) then return "Cast Sinister Strike (Opener)" end
      end
    end
    return
  end

  -- In Combat

  -- Fan the Hammer Combo Point Prediction
  if S.FanTheHammer:IsAvailable() and S.PistolShot:TimeSinceLastCast() < Player:GCDRemains() then
    ComboPoints = mathmax(ComboPoints, Rogue.FanTheHammerCP())
    EffectiveComboPoints = Rogue.EffectiveComboPoints(ComboPoints)
    ComboPointsDeficit = Player:ComboPointsDeficit()
  end

  if Everyone.TargetIsValid() then
    -- Interrupts
    ShouldReturn = Everyone.Interrupt(5, S.Kick, true, Interrupts)
    if ShouldReturn then return ShouldReturn end

    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then return "CDs: " .. ShouldReturn end

    -- actions+=/call_action_list,name=stealth,if=stealthed.all
    if Player:StealthUp(true, true) then
      ShouldReturn = Stealth()
      if ShouldReturn then return "Stealth: " .. ShouldReturn end
    end

    -- actions+=/run_action_list,name=finish,if=variable.finish_condition
    if Finish_Condition() then
      ShouldReturn = Finish()
      if ShouldReturn then return "Finish: " .. ShouldReturn end
      -- run_action_list forces the return
      Cast(S.PoolEnergy)
      return "Finish Pooling"
    end
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build()
    if ShouldReturn then return "Build: " .. ShouldReturn end

    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) and EnergyDeficit > 15 + EnergyRegen then
      if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Arcane Torrent" end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
      if Cast(S.ArcanePulse) then return "Cast Arcane Pulse" end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
      if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Lights Judgment" end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
      if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "Cast Bag of Tricks" end
    end

    -- OutofRange Pistol Shot
    if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and not Target:IsInRange(BladeFlurryRange) and not Player:StealthUp(true, true)
      and EnergyDeficit < 25 and (ComboPointsDeficit >= 1 or EnergyTimeToMax <= 1.2) then
      if Cast(S.PistolShot) then return "Cast Pistol Shot (OOR)" end
    end

    -- Generic Pooling suggestion
    if not Target:IsSpellInRange(S.Dispatch) then
      if CastAnnotated(S.PoolEnergy, false, "OOR") then return "Pool Energy (OOR)" end
    else
      if Cast(S.PoolEnergy) then return "Pool Energy" end
    end
  end
end

local function Init ()
  HR.Print("Outlaw Rogue rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(260, APL, Init)

--- ======= SIMC =======
-- Last Update: 2023-01-31

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=apply_poison
-- actions.precombat+=/flask
-- actions.precombat+=/augmentation
-- actions.precombat+=/food

-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/blade_flurry,precombat_seconds=4,if=talent.underhanded_upper_hand
-- actions.precombat+=/adrenaline_rush,precombat_seconds=3,if=talent.improved_adrenaline_rush
-- actions.precombat+=/roll_the_bones,precombat_seconds=2
-- actions.precombat+=/slice_and_dice,precombat_seconds=1
-- actions.precombat+=/stealth

-- # Executed every time the actor is available.
-- # Restealth if possible (no vulnerable enemies in combat)
-- actions=stealth

-- # Interrupt on cooldown to allow simming interactions with that
-- actions+=/kick

-- # Default Roll the Bones reroll rule: reroll for any buffs that aren't Buried Treasure, excluding Grand Melee in single target
-- actions+=/variable,name=rtb_reroll,value=rtb_buffs.will_lose=(rtb_buffs.will_lose.buried_treasure+rtb_buffs.will_lose.grand_melee&spell_targets.blade_flurry<2&raid_event.adds.in>10)

-- # Crackshot builds without T31 should reroll for True Bearing (or Broadside without Hidden Opportunity) if we won't lose over 1 buff
-- actions+=/variable,name=rtb_reroll,if=talent.crackshot&talent.hidden_opportunity&!set_bonus.tier31_4pc,value=(!rtb_buffs.will_lose.true_bearing&talent.hidden_opportunity|!rtb_buffs.will_lose.broadside&!talent.hidden_opportunity)&rtb_buffs.will_lose<=1

-- # Crackshot builds with T31 should reroll if we won't lose over 1 buff (2 with Loaded Dice), and if Broadside is not active for builds without Hidden Opportunity
-- actions+=/variable,name=rtb_reroll,if=talent.crackshot&set_bonus.tier31_4pc,value=(rtb_buffs.will_lose<=1+buff.loaded_dice.up)&(talent.hidden_opportunity|!buff.broadside.up)

-- # Hidden Opportunity builds without Crackshot should reroll for Skull and Crossbones or any 2 buffs excluding Grand Melee in single target
-- actions+=/variable,name=rtb_reroll,if=!talent.crackshot&talent.hidden_opportunity,value=!rtb_buffs.will_lose.skull_and_crossbones&(rtb_buffs.will_lose<2+rtb_buffs.will_lose.grand_melee&spell_targets.blade_flurry<2&raid_event.adds.in>10)

-- # Additional reroll rules if all active buffs will not be rolled away and we don't already have 5+ buffs
-- actions+/variable,name=rtb_reroll,value=variable.rtb_reroll|rtb_buffs.normal=0&rtb_buffs.longer>=1&rtb_buffs<5&rtb_buffs.max_remains<=39

-- # Avoid rerolls when we will not have time remaining on the fight or add wave to recoup the opportunity cost of the global
-- actions+=/variable,name=rtb_reroll,op=reset,if=!(raid_event.adds.remains>12|raid_event.adds.up&(raid_event.adds.in-raid_event.adds.remains)<6|target.time_to_die>12)|fight_remains<12

-- # Ensure we want to cast Ambush prior to triggering a Stealth cooldown
-- actions+=/variable,name=ambush_condition,value=(talent.hidden_opportunity|combo_points.deficit>=2+talent.improved_ambush+buff.broadside.up)&energy>=50

-- # Use finishers if at -1 from max combo points, or -2 in Stealth with Crackshot
-- actions+=/variable,name=finish_condition,value=effective_combo_points>=cp_max_spend-1-(stealthed.all&talent.crackshot)

-- # With multiple targets, this variable is checked to decide whether some CDs should be synced with Blade Flurry
-- actions+=/variable,name=blade_flurry_sync,value=spell_targets.blade_flurry<2&raid_event.adds.in>20|buff.blade_flurry.remains>gcd

-- # Higher priority Stealth list for Count the Odds or true Stealth/Vanish that will break in a single global
-- actions+=/call_action_list,name=cds
-- actions+=/call_action_list,name=stealth,if=stealthed.all
-- actions+=/run_action_list,name=finish,if=variable.finish_condition
-- actions+=/call_action_list,name=build
-- actions+=/arcane_torrent,if=energy.base_deficit>=15+energy.regen
-- actions+=/arcane_pulse
-- actions+=/lights_judgment
-- actions+=/bag_of_tricks


-- # Builders
-- actions.build=echoing_reprimand

-- # High priority Ambush for Hidden Opportunity builds
-- actions.build+=/ambush,if=talent.hidden_opportunity&buff.audacity.up

-- # With Audacity + Hidden Opportunity + Fan the Hammer, consume Opportunity to proc Audacity any time Ambush is not available
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up

-- # Use Greenskins Wickers buff immediately with Opportunity unless running Fan the Hammer
-- actions.build+=/pistol_shot,if=buff.greenskins_wickers.up&(!talent.fan_the_hammer&buff.opportunity.up|buff.greenskins_wickers.remains<1.5)

-- #With Fan the Hammer, consume Opportunity at max stacks or if it will expire
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)

-- # With Fan the Hammer, consume Opportunity based on CP deficit, and 2 Fan the Hammer Crackshot builds can briefly hold stacks for an upcoming stealth cooldown
-- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&combo_points.deficit>((1+talent.quick_draw)*talent.fan_the_hammer.rank)&(!cooldown.vanish.ready&!cooldown.shadow_dance.ready|stealthed.all|!talent.crackshot|talent.fan_the_hammer.rank<=1)

-- #If not using Fan the Hammer, then consume Opportunity based on energy, when it will exactly cap CPs, or when using Quick Draw
-- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|combo_points.deficit<=1+buff.broadside.up|talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)

-- actions.build+=/sinister_strike



-- # Cooldowns
-- # Cooldowns Use Adrenaline Rush if it is not active and at 2cp if Improved, but Crackshot builds can refresh it in stealth
-- actions.cds=adrenaline_rush,if=(!buff.adrenaline_rush.up|stealthed.all&talent.crackshot&talent.improved_adrenaline_rush)&(combo_points<=2|!talent.improved_adrenaline_rush)

-- # Maintain Blade Flurry on 2+ targets, and on single target with Underhanded, or on cooldown at 5+ targets with Deft Maneuvers
-- actions.cds+=/blade_flurry,if=(spell_targets>=2-talent.underhanded_upper_hand&!stealthed.rogue)&buff.blade_flurry.remains<gcd|talent.deft_maneuvers&spell_targets>=5&!variable.finish_condition

-- # Use Roll the Bones if reroll conditions are met, or just before buffs expire based on T31 and upcoming stealth cooldowns
-- actions.cds+=/roll_the_bones,if=variable.rtb_reroll|rtb_buffs.max_remains<=set_bonus.tier31_4pc+(cooldown.shadow_dance.remains<=1|cooldown.vanish.remains<=1)*6

-- # Use Keep it Rolling with at least 3 buffs (4 with T31)
-- actions.cds+=/keep_it_rolling,if=!variable.rtb_reroll&rtb_buffs>=3+set_bonus.tier31_4pc&(buff.shadow_dance.down|rtb_buffs>=6)

--actions.cds+=/ghostly_strike

-- # Use Sepsis to trigger Crackshot or if the target will survive its DoT
-- actions.cds+=/sepsis,if=talent.crackshot&cooldown.between_the_eyes.ready&variable.finish_condition&!stealthed.all|!talent.crackshot&target.time_to_die>11&buff.between_the_eyes.up|fight_remains<11

-- # Use Blade Rush at minimal energy outside of stealth
-- actions.cds+=/blade_rush,if=energy.base_time_to_max>4&!stealthed.all

-- actions.cds+=/call_action_list,name=stealth_cds,if=!stealthed.all

-- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.base_deficit>=100|fight_remains<charges*6)

-- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up

-- actions.cds+=/blood_fury
-- actions.cds+=/berserking
-- actions.cds+=/fireblood
-- actions.cds+=/ancestral_call


-- # Default conditions for usable items.
-- actions.cds+=/use_item,name=manic_grieftorch,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!stealthed.all&buff.between_the_eyes.up&(!talent.ghostly_strike|debuff.ghostly_strike.up|spell_targets.blade_flurry>2)|fight_remains<=5
-- actions.cds+=/use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=(!trinket.1.is.dragonfire_bomb_dispenser&trinket.1.cooldown.remains>10|trinket.2.cooldown.remains>10)|cooldown.dragonfire_bomb_dispenser.charges>2|fight_remains<20|!trinket.2.has_cooldown|!trinket.1.has_cooldown
-- actions.cds+=/use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=gcd.remains>gcd.max-0.1&!stealthed.all&buff.between_the_eyes.up&(!talent.ghostly_strike|debuff.ghostly_strike.up|spell_targets.blade_flurry>2)|fight_remains<=5
-- actions.cds+=/use_item,name=use_item,name=stormeaters_boon,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<10
-- actions.cds+=/use_item,name=windscar_whetstone,if=spell_targets.blade_flurry>desired_targets|raid_event.adds.in>60|fight_remains<7
-- actions.cds+=/use_items,slots=trinket1,if=buff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
-- actions.cds+=/use_items,slots=trinket2,if=buff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20

-- # Finishers
-- # Finishers Use Between the Eyes to keep the crit buff up, but on cooldown if Improved/Greenskins/T30, and avoid overriding Greenskins
-- actions.finish=between_the_eyes,if=!talent.crackshot&(buff.between_the_eyes.remains<4|talent.improved_between_the_eyes|talent.greenskins_wickers|set_bonus.tier30_4pc)&!buff.greenskins_wickers.up

-- #Crackshot builds use Between the Eyes outside of Stealth if Vanish or Dance will not come off cooldown within the next cast
-- actions.finish+=/between_the_eyes,if=talent.crackshot&(cooldown.vanish.remains>45&cooldown.shadow_dance.remains>12)

-- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable
-- actions.finish+=/killing_spree,if=debuff.ghostly_strike.up|!talent.ghostly_strike
-- actions.finish+=/cold_blood
-- actions.finish+=/dispatch


-- # Stealth
-- actions.stealth=blade_flurry,if=talent.subterfuge&talent.hidden_opportunity&spell_targets>=2&buff.blade_flurry.remains<gcd
-- actions.stealth+=/cold_blood,if=variable.finish_condition
-- actions.stealth+=/between_the_eyes,if=variable.finish_condition&talent.crackshot
-- actions.stealth+=/dispatch,if=variable.finish_condition

-- # 2 Fan the Hammer Crackshot builds can consume Opportunity in stealth with max stacks, Broadside, and low CPs, or with Greenskins active
-- actions.stealth+=/pistol_shot,if=talent.crackshot&talent.fan_the_hammer.rank>=2&buff.opportunity.stack>=6&(buff.broadside.up&combo_points<=1|buff.greenskins_wickers.up)

-- actions.stealth+=/ambush,if=talent.hidden_opportunity


-- # Stealth Cooldowns
-- actions.stealth_cds=variable,name=vanish_opportunity_condition,value=!talent.shadow_dance&talent.fan_the_hammer.rank+talent.quick_draw+talent.audacity<talent.count_the_odds+talent.keep_it_rolling

-- # Hidden Opportunity builds without Crackshot use Vanish if Audacity is not active and when under max Opportunity stacks
-- actions.stealth_cds+=/vanish,if=talent.hidden_opportunity&!talent.crackshot&!buff.audacity.up&(variable.vanish_opportunity_condition|buff.opportunity.stack<buff.opportunity.max_stack)&variable.ambush_condition

-- # Crackshot builds or builds without Hidden Opportunity use Vanish at finish condition
-- actions.stealth_cds+=/vanish,if=(!talent.hidden_opportunity|talent.crackshot)&variable.finish_condition

-- # Crackshot builds use Dance at finish condition
-- actions.stealth_cds+=/shadow_dance,if=talent.crackshot&variable.finish_condition

-- # Hidden Opportunity builds without Crackshot use Dance if Audacity and Opportunity are not active
-- actions.stealth_cds+=/variable,name=shadow_dance_condition,value=buff.between_the_eyes.up&(!talent.hidden_opportunity|!buff.audacity.up&(talent.fan_the_hammer.rank<2|!buff.opportunity.up))&!talent.crackshot

-- actions.stealth_cds+=/shadow_dance,if=!talent.keep_it_rolling&variable.shadow_dance_condition&buff.slice_and_dice.up&(variable.finish_condition|talent.hidden_opportunity)&(!talent.hidden_opportunity|!cooldown.vanish.ready)

-- # Keep it Rolling builds without Crackshot use Dance at finish condition but hold it for an upcoming Keep it Rolling
-- actions.stealth_cds+=/shadow_dance,if=talent.keep_it_rolling&variable.shadow_dance_condition&(cooldown.keep_it_rolling.remains<=30|cooldown.keep_it_rolling.remains>120&(variable.finish_condition|talent.hidden_opportunity))

-- actions.stealth_cds+=/shadowmeld,if=talent.crackshot&variable.finish_condition|!talent.crackshot&(talent.count_the_odds&variable.finish_condition|talent.hidden_opportunity)
