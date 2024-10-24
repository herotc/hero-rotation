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
local CastQueue = HR.CastQueue
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num
local bool = HR.Commons.Everyone.bool
-- Lua
local mathmin = math.min
local mathmax = math.max
local mathabs = math.abs
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
  Outlaw = HR.GUISettings.APL.Rogue.Outlaw,
}

-- Define S/I for spell and item arrays
local S = Spell.Rogue.Outlaw
local I = Item.Rogue.Outlaw

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BottledFlayedwingToxin:ID(),
  I.ImperfectAscendancySerum:ID(),
  I.MadQueensMandate:ID()
}

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

-- Rotation Var
local Enemies30y, EnemiesBF, EnemiesBFCount
local ShouldReturn; -- Used to get the return string
local BladeFlurryRange = 6
local EffectiveComboPoints, ComboPoints, ChargedComboPoints, ComboPointsDeficit
local Energy, EnergyRegen, EnergyDeficit, EnergyTimeToMax, EnergyMaxOffset
local Interrupts = {
  { S.Blind, "Cast Blind (Interrupt)", function()
    return true
  end },
  { S.KidneyShot, "Cast Kidney Shot (Interrupt)", function()
    return ComboPoints > 0
  end }
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

local enableRtBDebugging = false
-- Get the number of Roll the Bones buffs currently on
local function RtB_Buffs ()
  if not Cache.APLVar.RtB_Buffs then
    Cache.APLVar.RtB_Buffs = {}
    Cache.APLVar.RtB_Buffs.Will_Lose = {}
    Cache.APLVar.RtB_Buffs.Will_Lose.Total = 0
    Cache.APLVar.RtB_Buffs.Total = 0
    Cache.APLVar.RtB_Buffs.Normal = 0
    Cache.APLVar.RtB_Buffs.Shorter = 0
    Cache.APLVar.RtB_Buffs.Longer = 0
    Cache.APLVar.RtB_Buffs.MinRemains = 0
    Cache.APLVar.RtB_Buffs.MaxRemains = 0
    local RtBRemains = Rogue.RtBRemains()
    for i = 1, #RtB_BuffsList do
      local Remains = Player:BuffRemains(RtB_BuffsList[i])
      if Remains > 0 then
        Cache.APLVar.RtB_Buffs.Total = Cache.APLVar.RtB_Buffs.Total + 1
        if Remains > Cache.APLVar.RtB_Buffs.MaxRemains then
          Cache.APLVar.RtB_Buffs.MaxRemains = Remains
        end

        if Remains < Cache.APLVar.RtB_Buffs.MinRemains then
          Cache.APLVar.RtB_Buffs.MinRemains = Remains
        end

        local difference = math.abs(Remains - RtBRemains)
        if difference <= 0.5 then
          Cache.APLVar.RtB_Buffs.Normal = Cache.APLVar.RtB_Buffs.Normal + 1
          Cache.APLVar.RtB_Buffs.Will_Lose[RtB_BuffsList[i]:Name()] = true
          Cache.APLVar.RtB_Buffs.Will_Lose.Total = Cache.APLVar.RtB_Buffs.Will_Lose.Total + 1

        elseif Remains > RtBRemains then
          Cache.APLVar.RtB_Buffs.Longer = Cache.APLVar.RtB_Buffs.Longer + 1

        else
          Cache.APLVar.RtB_Buffs.Shorter = Cache.APLVar.RtB_Buffs.Shorter + 1
          Cache.APLVar.RtB_Buffs.Will_Lose[RtB_BuffsList[i]:Name()] = true
          Cache.APLVar.RtB_Buffs.Will_Lose.Total = Cache.APLVar.RtB_Buffs.Will_Lose.Total + 1
        end
      end

      if enableRtBDebugging then
        print("RtbRemains", RtBRemains)
        print(RtB_BuffsList[i]:Name(), Remains)
      end
    end

    if enableRtBDebugging then
      print("have: ", Cache.APLVar.RtB_Buffs.Total)
      print("will lose: ", Cache.APLVar.RtB_Buffs.Will_Lose.Total)
      print("shorter: ", Cache.APLVar.RtB_Buffs.Shorter)
      print("normal: ", Cache.APLVar.RtB_Buffs.Normal)
      print("longer: ", Cache.APLVar.RtB_Buffs.Longer)
      print("max remains: ", Cache.APLVar.RtB_Buffs.MaxRemains)
    end
  end
  return Cache.APLVar.RtB_Buffs.Total
end

local function checkBuffWillLose(buff)
  return (Cache.APLVar.RtB_Buffs.Will_Lose and Cache.APLVar.RtB_Buffs.Will_Lose[buff]) and true or false
end

-- RtB rerolling strategy, return true if we should reroll
local function RtB_Reroll(ForceLoadedDice)
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
      -- # Variables that define the reroll rules for Roll the Bones Default rule: reroll if the only buff that will be rolled away is Buried Treasure, or Grand Melee in single target without upcoming adds
      -- actions+=/variable,name=rtb_reroll,value=rtb_buffs.will_lose=(rtb_buffs.will_lose.buried_treasure+rtb_buffs.will_lose.grand_melee
      -- &spell_targets.blade_flurry<2&raid_event.adds.in>12&raid_event.adds.count<2)
      Cache.APLVar.RtB_Reroll = RtB_Buffs() == num(checkBuffWillLose(S.BuriedTreasure)) + (num(checkBuffWillLose(S.GrandMelee) and num(EnemiesBFCount < 2)))

      -- # If Loaded Dice is talented, then keep any 1 buff from Roll the Bones but roll it into 2 buffs when Loaded Dice is active. Also reroll 2 buffs with loaded dice up if broadside, ruthless precision and true bearing are all missing and loaded dice is up
      -- actions+=/variable,name=rtb_reroll,if=talent.loaded_dice,value=(rtb_buffs.will_lose<=buff.loaded_dice.up)
      -- |buff.loaded_dice.up&rtb_buffs.will_lose<3&(!rtb_buffs.will_lose.broadside|buff.broadside.remains<11)
      -- &(!rtb_buffs.will_lose.ruthless_precision|buff.ruthless_precision.remains<11)&(!rtb_buffs.will_lose.true_bearing
      -- |buff.true_bearing.remains<11)
      Cache.APLVar.RtB_Reroll = S.LoadedDice:IsAvailable() and (Cache.APLVar.RtB_Buffs.Will_Lose.Total <= num(Player:BuffUp(S.LoadedDiceBuff) or ForceLoadedDice))
      or Player:BuffUp(S.LoadedDiceBuff) and Cache.APLVar.RtB_Buffs.Will_Lose.Total < 3 and (not checkBuffWillLose(S.Broadside) or Player:BuffRemains(S.Broadside) < 11)
      and (not checkBuffWillLose(S.RuthlessPrecision) or Player:BuffRemains(S.RuthlessPrecision) < 11) and (not checkBuffWillLose(S.TrueBearing) or Player:BuffRemains(S.TrueBearing) < 11)

      -- # If all active Roll the Bones buffs are ahead of its container buff and have under 40s remaining or with supercharger talented,
      -- then reroll again with Loaded Dice active in an attempt to get even more buffs
      -- actions+=/variable,name=rtb_reroll,value=variable.rtb_reroll&rtb_buffs.longer=0|rtb_buffs.normal=0&rtb_buffs.longer>=1
      -- &buff.loaded_dice.up&(rtb_buffs<6&rtb_buffs.max_remains<39|talent.supercharger)
      Cache.APLVar.RtB_Reroll = Cache.APLVar.RtB_Reroll and Cache.APLVar.RtB_Buffs.Longer == 0 or Cache.APLVar.RtB_Buffs.Normal == 0
        and Cache.APLVar.RtB_Buffs.Longer >= 1 and (Player:BuffUp(S.LoadedDiceBuff) or ForceLoadedDice)
        and (RtB_Buffs() <= 6 and Cache.APLVar.RtB_Buffs.MaxRemains <= 39 or S.Supercharger:IsAvailable())

      --# Non supercharger builds should avoid rerolls when we will not have time remaining on the fight or add wave to recoup the opportunity cost of the global
      -- actions+=/variable,name=rtb_reroll,op=reset,if=!talent.supercharger&!(raid_event.adds.remains>12|raid_event.adds.up
      -- &(raid_event.adds.in-raid_event.adds.remains)<6|target.time_to_die>12)|fight_remains<12
      if not S.Supercharger:IsAvailable() and (Target:FilteredTimeToDie("<", 12) or HL.BossFilteredFightRemains("<", 12)) then
        Cache.APLVar.RtB_Reroll = false
      end
    end
  end

  return Cache.APLVar.RtB_Reroll
end

-- # Use finishers if at -1 from max combo points, or -2 in Stealth with Crackshot
local function Finish_Condition ()
  -- actions+=/variable,name=finish_condition,value=combo_points>=cp_max_spend-1-(stealthed.all&talent.crackshot|
  -- (talent.hand_of_fate|talent.flawless_form)&talent.hidden_opportunity&(buff.audacity.up|buff.opportunity.up))
  return ComboPoints >= Rogue.CPMaxSpend() - 1 - num((Player:StealthUp(true, true) and S.Crackshot:IsAvailable()
    or (S.HandOfFate:IsAvailable() or S.FlawlessForm:IsAvailable()) and S.HiddenOpportunity:IsAvailable()
    and (Player:BuffUp(S.AudacityBuff) or Player:BuffUp(S.Opportunity))))
end

-- # Ensure we want to cast Ambush prior to triggering a Stealth cooldown
local function Ambush_Condition ()
  -- actions+=/variable,name=ambush_condition,value=(talent.hidden_opportunity|combo_points.deficit>=2+talent.improved_ambush+buff.broadside.up)&energy>=50
  return (S.HiddenOpportunity:IsAvailable() or ComboPointsDeficit >= 2 + num(S.ImprovedAmbush:IsAvailable()) + num(Player:BuffUp(S.Broadside))) and Energy >= 50
end

-- Determine if we are allowed to use Vanish offensively in the current situation
local function Vanish_DPS_Condition ()
  -- You can vanish if we've set the UseDPSVanish setting, and we're either not tanking or we're solo but the DPS vanish while solo flag is set).
  return Settings.Commons.UseDPSVanish and (not Player:IsTanking(Target) or Settings.Commons.UseSoloVanish)
end

local function Stealth(ReturnSpellOnly)
  if S.BladeFlurry:IsReady() then
    if S.DeftManeuvers:IsAvailable() and not Finish_Condition() and (EnemiesBFCount >= 3
      and ComboPointsDeficit == EnemiesBFCount + num(Player:BuffUp(S.Broadside)) or EnemiesBFCount >= 5) then
      if ReturnSpellOnly then
        return S.BladeFlurry
      else
        if Cast(S.BladeFlurry, Settings.Outlaw.GCDasOffGCD.BladeFlurry) then
          return "Cast Blade Flurry"
        end
      end
    end
  end

  -- actions.stealth+=/cold_blood,if=variable.finish_condition
  if S.ColdBlood:IsReady() and Player:BuffDown(S.ColdBlood) and Finish_Condition() then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
      return "Cast Cold Blood"
    end
  end

  -- actions.stealth+=/between_the_eyes,if=variable.finish_condition&talent.crackshot&(!buff.shadowmeld.up|stealthed.rogue)
  if (S.BetweentheEyes:IsReady() or ReturnSpellOnly) and Finish_Condition() and S.Crackshot:IsAvailable()
    and (not Player:BuffUp(S.Shadowmeld) or Player:StealthUp(true, false) or ReturnSpellOnly) then
    if ReturnSpellOnly then
      return S.BetweentheEyes
    else
      if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
        return "Cast Between the Eyes"
      end
    end
  end

  -- actions.stealth+=/dispatch,if=variable.finish_condition
  if S.Dispatch:IsReady() and Finish_Condition() then
    if ReturnSpellOnly then
      return S.Dispatch
    else
      if CastPooling(S.Dispatch, nil, not Target:IsSpellInRange(S.Dispatch)) then
        return "Cast Dispatch"
      end
    end
  end

  -- # 2 Fan the Hammer Crackshot builds can consume Opportunity in stealth with max stacks, Broadside, and low CPs, or with Greenskins active
  -- actions.stealth+=/pistol_shot,if=talent.crackshot&talent.fan_the_hammer.rank>=2&buff.opportunity.stack>=6
  -- &(buff.broadside.up&combo_points<=1|buff.greenskins_wickers.up)
  if S.PistolShot:IsReady() and S.Crackshot:IsAvailable() and S.FanTheHammer:TalentRank() >= 2 and Player:BuffStack(S.Opportunity) >= 6
    and (Player:BuffUp(S.Broadside) and ComboPoints <= 1 or Player:BuffUp(S.GreenskinsWickersBuff)) then
    if ReturnSpellOnly then
      return S.PistolShot
    else
      if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
        return "Cast Pistol Shot"
      end
    end
  end

  -- ***NOT PART of SimC*** Condition duplicated from build to Show SS Icon in stealth with audacity buff
  if S.Ambush:IsReady() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.AudacityBuff) then
    if ReturnSpellOnly then
      return S.SSAudacity
    else
      if CastPooling(S.SSAudacity, nil, not Target:IsSpellInRange(S.Ambush)) then
        return "Cast Ambush (SS High-Prio Buffed)"
      end
    end
  end

  -- actions.stealth+=/ambush,if=talent.hidden_opportunity
  if S.Ambush:IsReady() and S.HiddenOpportunity:IsAvailable() then
    if ReturnSpellOnly then
      return S.Ambush
    else
      if CastPooling(S.Ambush, nil, not Target:IsSpellInRange(S.Ambush)) then
        return "Cast Ambush"
      end
    end
  end
end

local function Finish(ReturnSpellOnly)
  -- # Use Between the Eyes to keep the crit buff up, but on cooldown if Improved/Greenskins, and avoid overriding Greenskins
  -- actions.finish=between_the_eyes,if=!talent.crackshot
  -- &(buff.between_the_eyes.remains<4|talent.improved_between_the_eyes|talent.greenskins_wickers)
  -- &!buff.greenskins_wickers.up
  if S.BetweentheEyes:IsReady() and not S.Crackshot:IsAvailable()
    and (Player:BuffRemains(S.BetweentheEyes) < 4 or S.ImprovedBetweenTheEyes:IsAvailable() or S.GreenskinsWickers:IsAvailable())
    and Player:BuffDown(S.GreenskinsWickers) then
    if ReturnSpellOnly then
      return S.BetweentheEyes
    else
      if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
        return "Cast Between the Eyes"
      end
    end
  end

  -- # Crackshot builds use Between the Eyes outside of Stealth to refresh the Between the Eyes crit buff or on cd with the Ruthless Precision buff
  -- actions.finish+=/between_the_eyes,if=talent.crackshot&(buff.ruthless_precision.up|buff.between_the_eyes.remains<4)
  if S.BetweentheEyes:IsReady() then
    if S.Crackshot:IsAvailable() and (Player:BuffUp(S.RuthlessPrecision) or Player:BuffRemains(S.BetweentheEyes) < 4) then
      if ReturnSpellOnly then
        return S.BetweentheEyes
      else
        if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
          return "Cast Between the Eyes"
        end
      end
    end
  end

  -- actions.finish+=/slice_and_dice,if=buff.slice_and_dice.remains<fight_remains&refreshable
  -- Note: Added Player:BuffRemains(S.SliceandDice) == 0 to maintain the buff while TTD is invalid (it's mainly for Solo, not an issue in raids)
  if S.SliceandDice:IsReady() and (HL.FilteredFightRemains(EnemiesBF, ">", Player:BuffRemains(S.SliceandDice), true) or Player:BuffRemains(S.SliceandDice) == 0)
    and Player:BuffRemains(S.SliceandDice) < (1 + ComboPoints) * 1.8 then
    if ReturnSpellOnly then
      return S.SliceandDice
    else
      if Cast(S.SliceandDice) then
        return "Cast Slice and Dice"
      end
    end
  end

  if S.ColdBlood:IsReady() and Player:BuffDown(S.ColdBlood) then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
      return "Cast Cold Blood"
    end
  end

  -- actions.finish+=/coup_de_grace
  if S.CoupDeGrace:IsReady() then
    if ReturnSpellOnly then
      return S.CoupDeGrace
    else
      if CastPooling(S.CoupDeGrace, nil, not Target:IsSpellInRange(S.CoupDeGrace)) then
        return "Cast Coup de Grace"
      end
    end
  end

  -- actions.finish+=/dispatch
  if S.Dispatch:IsReady() then
    if ReturnSpellOnly then
      return S.Dispatch
    else
      if CastPooling(S.Dispatch, nil, not Target:IsSpellInRange(S.Dispatch)) then
        return "Cast Dispatch"
      end
    end
  end
end

local StealthCDs

-- # Spell Queue Macros
-- This returns a table with the base spell and the result of the Stealth or Finish action lists as if the applicable buff / Combo points was present
local function SpellQueueMacro (BaseSpell, ReturnSpellOnly)
  local MacroAbility

  -- Handle StealthMacro GUI options
  -- If false, just suggest them as off-GCD and bail out of the macro functionality
  if BaseSpell:ID() == S.Vanish:ID() or BaseSpell:ID() == S.Shadowmeld:ID() then
    -- Fetch stealth spell
    MacroAbility = Stealth(true)
    if MacroAbility and ReturnSpellOnly then
      return MacroAbility
    end

    if BaseSpell:ID() == S.Vanish:ID() and (not Settings.Outlaw.SpellQueueMacro.Vanish or not MacroAbility) then
      if Cast(S.Vanish, Settings.CommonsOGCD.OffGCDasOffGCD.Vanish) then
        return "Cast Vanish"
      end
      return false
    elseif BaseSpell:ID() == S.Shadowmeld:ID() and (not Settings.Outlaw.SpellQueueMacro.Shadowmeld or not MacroAbility) then
      if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
        return "Cast Shadowmeld"
      end
      return false
    end
  elseif BaseSpell:ID() == S.AdrenalineRush:ID() then
    -- Force max CPs for check so we don't get builders
    ComboPoints = Player:ComboPointsMax()

    -- Check if we need to reroll after getting loaded Dice from using AR
    -- Note: Not calling CD's here because the first condition is AR and will bring us back here, so instead of increasing
    -- code complexity and putting in hacks to skip the AR condition, the RtB condition has been put here separately.
    -- Use Roll the Bones if reroll conditions are met, or with no buffs, or seven seconds early if about to enter a Vanish window with Crackshot
    -- actions.cds+=/roll_the_bones,if=variable.rtb_reroll|rtb_buffs=0
    if S.RolltheBones:IsReady() then
      if RtB_Reroll(true) or RtB_Buffs() == 0 then
        MacroAbility = S.RolltheBones
      end
    end

    -- If we don't need to reroll then we can check finishers
    if not MacroAbility then
      -- Fetch Finisher if not in stealth (AR->Dispatch) or Stealth Ability if we are (AR->BtE)
      -- Outside of stealth could be AR -> Vanish -> BtE so check for this first then fallback into normal finisher.
      if not Player:StealthUp(true, true) then
        local MacroAbilities = StealthCDs(true)
        -- Make sure StealthCDs returned a combo which may not happen if targeting something out of range
        if MacroAbilities and MacroAbilities[2] and MacroAbilities[2] ~= "Cast Vanish" then
          local ARMacroTable = { BaseSpell, unpack(MacroAbilities) }
          ShouldReturn = CastQueue(unpack(ARMacroTable))
          if ShouldReturn then
            return "| " .. ARMacroTable[2]:Name() .. " | " .. ARMacroTable[3]:Name()
          end
        end

        MacroAbility = Finish(true)
      else
        MacroAbility = Stealth(true)
      end
      if not Settings.Outlaw.SpellQueueMacro.ImprovedAdrenalineRush or not MacroAbility then
        if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          return "Cast Adrenaline Rush"
        end
        return false
      end
    end
  end

  local MacroTable = { BaseSpell, MacroAbility }
  ShouldReturn = CastQueue(unpack(MacroTable))
  if ShouldReturn then
    return "| " .. MacroTable[2]:Name()
  end

  return false
end

function StealthCDs (ReturnSpellOnly)
  -- # Stealth Cooldowns Builds with Underhanded Upper Hand and Subterfuge must use Vanish while Adrenaline Rush is active
  -- and either BTE on CD with RP up, adrenaline rush about to expire, supercharger buff up, vanish capped on charges or about to cap or fight about to end
  -- actions.stealth_cds=vanish,if=talent.underhanded_upper_hand&talent.subterfuge&talent.crackshot&buff.adrenaline_rush.up
  -- &variable.finish_condition&(!cooldown.between_the_eyes.ready&buff.ruthless_precision.up|buff.adrenaline_rush.remains<3
  -- |buff.supercharge_1.up|buff.supercharge_2.up|cooldown.vanish.full_recharge_time<15|fight_remains<8)
  if S.Vanish:IsReady() and Vanish_DPS_Condition() then
    if S.UnderhandedUpperhand:IsAvailable() and S.Subterfuge:IsAvailable() and S.Crackshot:IsAvailable() and Player:BuffUp(S.AdrenalineRush)
      and Finish_Condition() and (not S.BetweentheEyes:IsReady() and Player:BuffUp(S.RuthlessPrecision) or Player:BuffRemains(S.AdrenalineRush) < 3
      or ChargedComboPoints > 0 or S.Vanish:CooldownRemains() < 15 or HL.BossFilteredFightRemains("<", 8)) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 1 " .. ShouldReturn
      end
    end
  end

  -- # Builds with Underhanded Upper Hand and Subterfuge but without crackshot use vanish only with Adrenaline Rush active
  -- actions.stealth_cds+=/vanish,if=talent.underhanded_upper_hand&talent.subterfuge&!talent.crackshot&buff.adrenaline_rush.up
  -- &(variable.ambush_condition|!talent.hidden_opportunity)&(!cooldown.between_the_eyes.ready&buff.ruthless_precision.up
  -- |buff.ruthless_precision.down|buff.adrenaline_rush.remains<3)
  if S.Vanish:IsReady() and Vanish_DPS_Condition() and S.UnderhandedUpperhand:IsAvailable() and S.Subterfuge:IsAvailable()
    and not S.Crackshot:IsAvailable() and Player:BuffUp(S.AdrenalineRush) and (Ambush_Condition() or not S.HiddenOpportunity:IsAvailable())
    and (not S.BetweentheEyes:IsReady() and Player:BuffUp(S.RuthlessPrecision) or Player:BuffDown(S.RuthlessPrecision) or Player:BuffRemains(S.AdrenalineRush) < 3) then
    ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
    if ShouldReturn then
      if ReturnSpellOnly then
        return { S.Vanish, ShouldReturn }
      end
      return "Vanish Macro 2 " .. ShouldReturn
    end
  end

  -- # Builds without Underhanded Upper Hand but with Crackshot must still use Vanish into Between the Eyes on cooldown
  -- actions.stealth_cds+=/vanish,if=!talent.underhanded_upper_hand&talent.crackshot&variable.finish_condition
  if S.Vanish:IsReady() and Vanish_DPS_Condition() and not S.UnderhandedUpperhand:IsAvailable() and S.Crackshot:IsAvailable() and Finish_Condition() then
    ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
    if ShouldReturn then
      if ReturnSpellOnly then
        return { S.Vanish, ShouldReturn }
      end
      return "Vanish Macro 3 " .. ShouldReturn
    end
  end

  -- # Builds without Underhanded Upper Hand and Crackshot but still Hidden Opportunity use Vanish into Ambush when Audacity is not active and under max Opportunity stacks
  -- actions.stealth_cds+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&talent.hidden_opportunity&!buff.audacity.up
  -- &buff.opportunity.stack<buff.opportunity.max_stack&variable.ambush_condition
  if S.Vanish:IsReady() and Vanish_DPS_Condition() and not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and S.HiddenOpportunity:IsAvailable()
    and Player:BuffDown(S.AudacityBuff) and Player:BuffStack(S.Opportunity) < 6 and Ambush_Condition() then
    ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
    if ShouldReturn then
      if ReturnSpellOnly then
        return { S.Vanish, ShouldReturn }
      end
      return "Vanish Macro 4 " .. ShouldReturn
    end
  end

  -- # Builds without Underhanded Upper Hand, Crackshot, and Hidden Opportunity but with Fatebound use Vanish at five
  -- stacks of either Fatebound coin in order to proc the Lucky Coin if it's not already active, and otherwise continue
  -- to Vanish into a Dispatch to proc Double Jeopardy on a biased coin
  -- actions.stealth_cds+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&!talent.hidden_opportunity
  -- &talent.fateful_ending&(!buff.fatebound_lucky_coin.up&(buff.fatebound_coin_tails.stack>=5
  -- |buff.fatebound_coin_heads.stack>=5)|buff.fatebound_lucky_coin.up&!cooldown.between_the_eyes.ready)
  if S.Vanish:IsReady() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and not S.HiddenOpportunity():IsAvailable()
      and not S.FatefulEnding:IsAvailable() and (Player:BuffDown(S.FateboundLuckyCoin) and (Player:BuffStack(S.FateboundCoinTails) >= 5
      or Player:BuffStack(S.FateboundCoinHeads) >= 5) or Player:BuffUp(S.FateboundLuckyCoin and not S.BetweentheEyes:IsReady())) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 5 " .. ShouldReturn
      end
    end
  end

  -- # Builds with none of the above can use Vanish to maintain Take 'em By Surprise
  -- actions.stealth_cds+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&!talent.hidden_opportunity
  -- &!talent.fateful_ending&talent.take_em_by_surprise&!buff.take_em_by_surprise.up
  if S.Vanish:IsReady() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and not S.HiddenOpportunity:IsAvailable()
      and not S.FatefulEnding:IsAvailable() and S.TakeEmBySurprise:IsAvailable() and Player:BuffDown(S.TakeEmBySurpriseBuff) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 6 " .. ShouldReturn
      end
    end
  end

  -- actions.stealth_cds+=/shadowmeld,if=variable.finish_condition&!cooldown.vanish.ready
  if S.Shadowmeld:IsAvailable() and S.Shadowmeld:IsReady() and Finish_Condition() and not S.Vanish:IsReady() then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Shadowmeld"
    end
  end
end

local function CDs ()
  -- # Use Adrenaline Rush if it is not active and the finisher condition is not met, with Improved Adrenaline Rush you can also refresh it with 2cp or less if Loaded Dice is not already up
  -- # Adrenaline rush if buff is missing unless you can finish or with 2 or less cp if loaded dice is missing
  -- actions.cds=adrenaline_rush,if=!buff.adrenaline_rush.up&(!variable.finish_condition|!talent.improved_adrenaline_rush)
  -- |talent.improved_adrenaline_rush&combo_points<=2&!buff.loaded_dice.up
  if CDsON() and S.AdrenalineRush:IsCastable()
    and (not Player:BuffUp(S.AdrenalineRush) and (not Finish_Condition() or not S.ImprovedAdrenalineRush:IsAvailable())
    or S.ImprovedAdrenalineRush:IsAvailable() and ComboPoints <= 2 and not Player:BuffUp(S.LoadedDiceBuff)) then
    if S.ImprovedAdrenalineRush:IsAvailable() then
      ShouldReturn = SpellQueueMacro(S.AdrenalineRush)
      if ShouldReturn then
        return "AR Finisher Macro 1 " .. ShouldReturn
      end
    else
      if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
        return "Cast Adrenaline Rush"
      end
    end
  end

  -- # Sprint to further benefit from Scroll of Momentum trinket
  -- actions.cds+=/sprint,if=(trinket.1.is.scroll_of_momentum|trinket.2.is.scroll_of_momentum)&buff.full_momentum.up
  if S.Sprint:IsReady() and Player:BuffDown(S.Sprint) and
    (trinket1:ID() == I.ScrollOfMomentum:ID() or trinket2:ID() == I.ScrollOfMomentum:ID()) and Player:BuffUp(S.FullMomentum) then
    if Cast(S.Sprint, Settings.CommonsOGCD.OffGCDasOffGCD.Sprint) then
      return "Cast Sprint"
    end
  end

  -- # Maintain Blade Flurry on 2+ targets
  if S.BladeFlurry:IsReady() then
    if EnemiesBFCount >= 2 and Player:BuffRemains(S.BladeFlurry) < Player:GCD() then
      if Cast(S.BladeFlurry, Settings.Outlaw.GCDasOffGCD.BladeFlurry) then
        return "Cast Blade Flurry"
      end
    end
  end

  -- # With Deft Maneuvers, use Blade Flurry on cooldown at 5+ targets, or at 3-4 targets if missing combo points equal to the amount given
  -- action.cds/blade_flurry,if=talent.deft_maneuvers&!variable.finish_condition&(spell_targets>=3
  -- &combo_points.deficit=spell_targets+buff.broadside.up|spell_targets>=5)
  if S.BladeFlurry:IsReady() then
    if S.DeftManeuvers:IsAvailable() and not Finish_Condition() and (EnemiesBFCount >= 3
      and ComboPointsDeficit == EnemiesBFCount + num(Player:BuffUp(S.Broadside)) or EnemiesBFCount >= 5) then
      if Cast(S.BladeFlurry, Settings.Outlaw.GCDasOffGCD.BladeFlurry) then
        return "Cast Blade Flurry"
      end
    end
  end

  -- # Use Roll the Bones if reroll conditions are met, or with no buffs
  -- actions.cds+=/roll_the_bones,if=variable.rtb_reroll|rtb_buffs=0
  if S.RolltheBones:IsReady() then
    if RtB_Reroll() or RtB_Buffs() == 0 then
      if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then
        return "Cast Roll the Bones"
      end
    end
  end

  -- # Use Keep it Rolling with any 4 buffs. If Broadside is not active, then wait until just before the lowest buff expires in an attempt to obtain it from Count the Odds.
  -- actions.cds+=/keep_it_rolling,if=rtb_buffs>=4&(rtb_buffs.min_remains<2|buff.broadside.up)
  if S.KeepItRolling:IsReady() and RtB_Buffs() >= 4 and (Cache.APLVar.RtB_Buffs.MinRemains < 3 or Player:BuffUp(S.Broadside)) then
    if Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then
      return "Cast Keep it Rolling"
    end
  end

  --actions.cds+=/ghostly_strike,if=effective_combo_points<cp_max_spend
  if S.GhostlyStrike:IsAvailable() and S.GhostlyStrike:IsReady() and EffectiveComboPoints < 7 then
    if Cast(S.GhostlyStrike, Settings.Outlaw.OffGCDasOffGCD.GhostlyStrike, nil, not Target:IsSpellInRange(S.GhostlyStrike)) then
      return "Cast Ghostly Strike"
    end
  end

  -- # Trinkets that should not be used during stealth and have higher priority than entering stealth
  if Settings.Commons.Enabled.Trinkets then
    -- actions.cds+=/use_item,name=imperfect_ascendancy_serum,if=!stealthed.all|fight_remains<=22
    if I.ImperfectAscendancySerum:IsEquippedAndReady() then
      if not Player:StealthUp(true, true) or HL.BossFilteredFightRemains("<=", 22) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.ImperfectAscendancySerum)) then
          return "Imperfect Ascendancy Serum";
        end
      end
    end

    -- actions.cds+=/use_item,name=mad_queens_mandate,if=!stealthed.all|fight_remains<=5
    if I.MadQueensMandate:IsEquippedAndReady() then
      if not Player:StealthUp(true, true) or HL.BossFilteredFightRemains("<=", 5) then
        if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.MadQueensMandate)) then
          return "Mad Queens Mandate";
        end
      end
    end
  end

  -- # Killing Spree has higher priority than stealth cooldowns
  -- actions.finish+=/killing_spree,if=variable.finish_condition&!stealthed.all
  if S.KillingSpree:IsCastable() and Finish_Condition() and not Player:StealthUp(true, true) then
    if Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle, not Target:IsSpellInRange(S.KillingSpree), nil) then
      return "Cast Killing Spree"
    end
  end

  -- # Crackshot builds use stealth cooldowns if not already in stealth
  -- actions.cds+=/call_action_list,name=stealth_cds,if=!stealthed.all
  if not Player:StealthUp(true, true) then
    ShouldReturn = StealthCDs()
    if ShouldReturn then
      return ShouldReturn
    end
  end

  -- actions.cds+=/thistle_tea,if=!buff.thistle_tea.up&(energy.base_deficit>=100|fight_remains<charges*6)
  if CDsON() and S.ThistleTea:IsCastable() and not Player:BuffUp(S.ThistleTea)
    and (EnergyDeficit >= 150 or HL.BossFilteredFightRemains("<", S.ThistleTea:Charges() * 6)) then
    if Cast(S.ThistleTea, Settings.CommonsOGCD.OffGCDasOffGCD.ThistleTea) then
      return "Cast Thistle Tea"
    end
  end

  -- # Use Blade Rush at minimal energy outside of stealth
  -- actions.cds+=/blade_rush,if=energy.base_time_to_max>4&!stealthed.all
  if S.BladeRush:IsCastable() and EnergyTimeToMax > 4 and not Player:StealthUp(true, true) then
    if Cast(S.BladeRush, Settings.Outlaw.GCDasOffGCD.BladeRush, nil, not Target:IsSpellInRange(S.BladeRush)) then
      return "Cast Blade Rush"
    end
  end

  -- actions.cds+=/potion,if=buff.bloodlust.react|fight_remains<30|buff.adrenaline_rush.up
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() and (Player:BloodlustUp() or HL.BossFilteredFightRemains("<", 30) or Player:BuffUp(S.AdrenalineRush)) then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then
        return "Cast Potion";
      end
    end
  end

  -- actions.cds+=/blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Blood Fury"
    end
  end

  -- actions.cds+=/berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Berserking"
    end
  end

  -- actions.cds+=/fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Fireblood"
    end
  end

  -- actions.cds+=/ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Ancestral Call"
    end
  end

  if Settings.Commons.Enabled.Trinkets then
    -- # Default conditions for usable items.
    -- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
    -- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20
    local TrinketToUse = Player:GetUseableItems(OnUseExcludes, 13) or Player:GetUseableItems(OnUseExcludes, 14)
    local TrinketSpell
    local TrinketRange = 100
    if TrinketToUse then
      TrinketSpell = TrinketToUse:OnUseSpell()
      TrinketRange = (TrinketSpell and TrinketSpell.MaximumRange > 0 and TrinketSpell.MaximumRange <= 100) and TrinketSpell.MaximumRange or 100
    end
    if TrinketToUse and (Player:BuffUp(S.BetweentheEyes) or HL.BossFilteredFightRemains("<", 20) or TrinketToUse:HasStatAnyDps()) then
      if Cast(TrinketToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(TrinketRange)) then
        return "Generic use_items for " .. TrinketToUse:Name()
      end
    end
  end
end

local function Build ()
  -- # High priority Ambush for Hidden Opportunity builds
  -- actions.build+=/ambush,if=talent.hidden_opportunity&buff.audacity.up
  if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.AudacityBuff) then
    if CastPooling(S.SSAudacity, nil, not Target:IsSpellInRange(S.Ambush)) then
      return "Cast Ambush (SS High-Prio Buffed)"
    end
  end

  -- # With Audacity + Hidden Opportunity + Fan the Hammer, consume Opportunity to proc Audacity any time Ambush is not available
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up
  if S.FanTheHammer:IsAvailable() and S.Audacity:IsAvailable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.Opportunity) and Player:BuffDown(S.AudacityBuff) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot (Audacity)"
    end
  end

  -- # With Fan the Hammer, consume Opportunity as a higher priority if at max stacks or if it will expire
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)
  if S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and (Player:BuffStack(S.Opportunity) >= 6 or Player:BuffRemains(S.Opportunity) < 2) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot (FtH Dump)"
    end
  end

  -- # With Fan the Hammer, consume Opportunity if it will not overcap CPs, or with 1 CP at minimum
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(combo_points.deficit>=(1+(talent.quick_draw+buff.broadside.up)
  -- *(talent.fan_the_hammer.rank+1))|combo_points<=talent.ruthlessness)
  if S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and (ComboPointsDeficit >= (1 + (num(S.QuickDraw:IsAvailable()) + num(Player:BuffUp(S.Broadside)))
    * (S.FanTheHammer:TalentRank() + 1)) or ComboPoints <= num(S.Ruthlessness:IsAvailable())) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot (Low CP Opportunity)"
    end
  end

  -- #If not using Fan the Hammer, then consume Opportunity based on energy, when it will exactly cap CPs, or when using Quick Draw
  -- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|combo_points.deficit<=1+buff.broadside.up
  -- |talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
  if not S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and (EnergyTimeToMax > 1.5 or ComboPointsDeficit <= 1 + num(Player:BuffUp(S.Broadside))
    or S.QuickDraw:IsAvailable() or S.Audacity:IsAvailable() and Player:BuffDown(S.AudacityBuff)) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot"
    end
  end

  -- actions.build+=/sinister_strike
  if S.SinisterStrike:IsCastable() then
    if CastPooling(S.SinisterStrike, nil, not Target:IsSpellInRange(S.SinisterStrike)) then
      return "Cast Sinister Strike"
    end
  end
end

--- ======= MAIN =======
local function APL ()
  -- Local Update
  BladeFlurryRange = 8
  ComboPoints = Player:ComboPoints()
  ChargedComboPoints = Player:ChargedComboPoints()
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
  if not Player:AffectingCombat() and S.Vanish:TimeSinceLastCast() > 1 then
    -- Stealth
    if not Player:StealthUp(true, false) then
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
    if Everyone.TargetIsValid() then
      -- Precombat CDs
      if I.ImperfectAscendancySerum:IsEquippedAndReady() then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.ImperfectAscendancySerum)) then
          return "Imperfect Ascendancy Serum";
        end
      end
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=1,if=talent.improved_adrenaline_rush&talent.keep_it_rolling&talent.loaded_dice
      if S.AdrenalineRush:IsReady() and S.ImprovedAdrenalineRush:IsAvailable() and S.KeepItRolling:IsAvailable()
        and S.LoadedDice:IsAvailable() then
        if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          return "Cast Adrenaline Rush (Opener KiR)"
        end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=1
      -- Use same extended logic as a normal rotation for between pulls
      if S.RolltheBones:IsReady() and not Player:DebuffUp(S.Dreadblades) and (RtB_Buffs() == 0 or RtB_Reroll()) then
        if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then
          return "Cast Roll the Bones (Opener)"
        end
      end
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=0,if=talent.improved_adrenaline_rush
      if S.AdrenalineRush:IsReady() and S.ImprovedAdrenalineRush:IsAvailable() then
        if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          return "Cast Adrenaline Rush (Opener)"
        end
      end

      if Player:StealthUp(true, false) then
        ShouldReturn = Stealth()
        if ShouldReturn then
          return "Stealth (Opener): " .. ShouldReturn
        end
        if S.KeepItRolling:IsAvailable() and S.GhostlyStrike:IsReady() and S.EchoingReprimand:IsAvailable() then
          if Cast(S.GhostlyStrike, nil, nil, not Target:IsSpellInRange(S.GhostlyStrike)) then
            return "Cast Ghostly Strike KiR (Opener)"
          end
        end
        if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() then
          if Cast(S.Ambush, nil, nil, not Target:IsSpellInRange(S.Ambush)) then
            return "Cast Ambush (Opener)"
          end
        else
          if S.SinisterStrike:IsCastable() then
            if Cast(S.SinisterStrike, nil, nil, not Target:IsSpellInRange(S.SinisterStrike)) then
              return "Cast Sinister Strike (Opener)"
            end
          end
        end
      elseif Finish_Condition() then
        ShouldReturn = Finish()
        if ShouldReturn then
          return "Finish (Opener): " .. ShouldReturn
        end
      end
      if S.SinisterStrike:IsCastable() then
        if Cast(S.SinisterStrike, nil, nil, not Target:IsSpellInRange(S.SinisterStrike)) then
          return "Cast Sinister Strike (Opener)"
        end
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
    ShouldReturn = Everyone.Interrupt(S.Kick, Settings.CommonsDS.DisplayStyle.Interrupts, Interrupts)
    if ShouldReturn then
      return ShouldReturn
    end

    -- actions+=/call_action_list,name=cds
    ShouldReturn = CDs()
    if ShouldReturn then
      return "CDs: " .. ShouldReturn
    end

    -- actions+=/call_action_list,name=stealth,if=stealthed.all
    if Player:StealthUp(true, true) then
      ShouldReturn = Stealth()
      if ShouldReturn then
        return "Stealth: " .. ShouldReturn
      end
    end

    -- actions+=/run_action_list,name=finish,if=variable.finish_condition
    if Finish_Condition() then
      ShouldReturn = Finish()
      if ShouldReturn then
        return "Finish: " .. ShouldReturn
      end
      -- run_action_list forces the return
      Cast(S.PoolEnergy)
      return "Finish Pooling"
    end
    -- actions+=/call_action_list,name=build
    ShouldReturn = Build()
    if ShouldReturn then
      return "Build: " .. ShouldReturn
    end

    -- actions+=/arcane_torrent,if=energy.deficit>=15+energy.regen
    if S.ArcaneTorrent:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) and EnergyDeficit > 15 + EnergyRegen then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
        return "Cast Arcane Torrent"
      end
    end
    -- actions+=/arcane_pulse
    if S.ArcanePulse:IsCastable() and Target:IsSpellInRange(S.SinisterStrike) then
      if Cast(S.ArcanePulse) then
        return "Cast Arcane Pulse"
      end
    end
    -- actions+=/lights_judgment
    if S.LightsJudgment:IsCastable() and Target:IsInMeleeRange(5) then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
        return "Cast Lights Judgment"
      end
    end
    -- actions+=/bag_of_tricks
    if S.BagofTricks:IsCastable() and Target:IsInMeleeRange(5) then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
        return "Cast Bag of Tricks"
      end
    end

    -- OutofRange Pistol Shot
    if S.PistolShot:IsCastable() and Target:IsSpellInRange(S.PistolShot) and not Target:IsInRange(BladeFlurryRange) and not Player:StealthUp(true, true)
      and EnergyDeficit < 25 and (ComboPointsDeficit >= 1 or EnergyTimeToMax <= 1.2) then
      if Cast(S.PistolShot) then
        return "Cast Pistol Shot (OOR)"
      end
    end

    -- Generic Pooling suggestion
    if not Target:IsSpellInRange(S.Dispatch) then
      if CastAnnotated(S.PoolEnergy, false, "OOR") then
        return "Pool Energy (OOR)"
      end
    else
      if Cast(S.PoolEnergy) then
        return "Pool Energy"
      end
    end
  end
end

local function Init ()
  HR.Print("Outlaw Rogue rotation has been updated for patch 11.0.5 \n ",
    "Note: It is known & Intended that Audacity procs will suggest Sinister Strike without a keybind shown")
end

HR.SetAPL(260, APL, Init)
