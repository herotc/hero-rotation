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
  I.JunkmaestrosMegaMagnet:ID(),
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
local EffectiveComboPoints, ComboPoints, EffectiveChargedComboPoints, ChargedComboPoints, ComboPointsDeficit
local KSBaseDuration, HasteMultiplier, KSHastedDuration
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
    Cache.APLVar.RtB_Buffs.MinRemains = 9999
    Cache.APLVar.RtB_Buffs.MaxRemains = 0
    Cache.APLVar.RtB_Buffs.BuffsAbovePandemic = 0
    local RtBRemains = Rogue.RtBRemains()
    for i = 1, #RtB_BuffsList do
      local Remains = Player:BuffRemains(RtB_BuffsList[i])
      if Remains > 0 then
        if Remains > 39 then
          Cache.APLVar.RtB_Buffs.BuffsAbovePandemic = Cache.APLVar.RtB_Buffs.BuffsAbovePandemic + 1
        end

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
      print("min remains: ", Cache.APLVar.RtB_Buffs.MinRemains)
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
      Cache.APLVar.RtB_Reroll = (Cache.APLVar.RtB_Buffs.Total <= 0) and true or false
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

      -- actions.cds+=/variable,name=buffs_above_pandemic,value=0+(buff.broadside.remains>39)+(buff.ruthless_precision.remains>39)
        -- +(buff.true_bearing.remains>39)+(buff.grand_melee.remains>39)+(buff.buried_treasure.remains>39)+(buff.skull_and_crossbones.remains>39)
      -- Added to RtB Cache, See RtB_Buffs

      -- # With TWW2 set, recast Roll the Bones if we will roll away between 0-1 buffs. If KIR was recently used
      -- on a natural 5 buff, then wait until all buffs are below around 41s remaining.
      -- actions.cds+=/roll_the_bones,if=set_bonus.tww2_4pc&rtb_buffs.will_lose<=1&(variable.buffs_above_pandemic<5|rtb_buffs.max_remains<42)
      Cache.APLVar.RtB_Reroll = Player:HasTier("TWW2", 4) and Cache.APLVar.RtB_Buffs.Will_Lose.Total <= 1 and (Cache.APLVar.RtB_Buffs.BuffsAbovePandemic < 5
        or Cache.APLVar.RtB_Buffs.MaxRemains <= 42)

      -- # With TWW2 set, recast Roll the Bones with at most 2 buffs active regardless of duration.
      -- Supercharger builds will also roll if we will lose between 0-4 buffs, but KIR Supercharger builds wait until
      -- they are all below 11s remaining.
      -- actions.cds+=/roll_the_bones,if=set_bonus.tww2_4pc&(rtb_buffs<=2|(rtb_buffs.max_remains<11|!talent.keep_it_rolling)
        -- &rtb_buffs.will_lose<5&talent.supercharger)
      if not Cache.APLVar.RtB_Reroll then
        Cache.APLVar.RtB_Reroll = Player:HasTier("TWW2", 4) and (Cache.APLVar.RtB_Buffs.Total <= 2
          or (Cache.APLVar.RtB_Buffs.MaxRemains < 11 or not S.KeepItRolling:IsAvailable())
            and Cache.APLVar.RtB_Buffs.Will_Lose.Total < 5 and S.Supercharger:IsAvailable())
      end

      -- # Without TWW2 set or Sleight of Hand, recast Roll the Bones to override 1 buff into 2 buffs with Loaded Dice,
      -- or reroll any 2 buffs with Loaded Dice+Supercharger. Hidden Opportunity builds can also reroll 2 buffs with Loaded Dice to try for BS/RP/TB.
      -- actions.cds+=/roll_the_bones,if=!set_bonus.tww2_4pc&(rtb_buffs.will_lose<=buff.loaded_dice.up|talent.supercharger
      -- &buff.loaded_dice.up&rtb_buffs<=2|talent.hidden_opportunity&buff.loaded_dice.up&rtb_buffs<=2&!buff.broadside.up
      -- &!buff.ruthless_precision.up&!buff.true_bearing.up)
      if not Cache.APLVar.RtB_Reroll then
        Cache.APLVar.RtB_Reroll = not Player:HasTier("TWW2", 4) and (Cache.APLVar.RtB_Buffs.Will_Lose.Total <= num(Player:BuffUp(S.LoadedDiceBuff) or ForceLoadedDice)
        or S.Supercharger:IsAvailable() and (Player:BuffUp(S.LoadedDiceBuff) or ForceLoadedDice) and Cache.APLVar.RtB_Buffs.Total <= 2
        or S.HiddenOpportunity:IsAvailable() and (Player:BuffUp(S.LoadedDiceBuff) or ForceLoadedDice) and Cache.APLVar.RtB_Buffs.Total <= 2
        and Player:BuffDown(S.Broadside) and Player:BuffDown(S.RuthlessPrecision) and Player:BuffDown(S.TrueBearing) )
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
  -- actions.stealth+=/cold_blood,if=variable.finish_condition
  if S.ColdBlood:IsCastable() and Player:BuffDown(S.ColdBlood) and Finish_Condition() then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
      return "Cast Cold Blood"
    end
  end

  -- actions.stealth+=/between_the_eyes,if=variable.finish_condition&talent.crackshot&(!buff.shadowmeld.up|stealthed.rogue)
  if (S.BetweentheEyes:CooldownUp() or S.BetweentheEyes:CooldownRemains() <= Player:GCDRemains() or ReturnSpellOnly) and Finish_Condition() and S.Crackshot:IsAvailable()
    and (not Player:BuffUp(S.Shadowmeld) or Player:StealthUp(true, false) or ReturnSpellOnly) then
    if ReturnSpellOnly then
      return S.BetweentheEyes
    else
      if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
        return "Cast Between the Eyes (Stealth)"
      end
    end
  end

  -- actions.stealth+=/dispatch,if=variable.finish_condition
  if S.Dispatch:IsCastable() and Finish_Condition() then
    if ReturnSpellOnly then
      return S.Dispatch
    else
      if CastPooling(S.Dispatch, nil, not Target:IsSpellInRange(S.Dispatch)) then
        return "Cast Dispatch (Stealth)"
      end
    end
  end

  -- # 2 Fan the Hammer Crackshot builds can consume Opportunity in stealth with max stacks, Broadside, and low CPs, or with Greenskins active
  -- actions.stealth+=/pistol_shot,if=talent.crackshot&talent.fan_the_hammer.rank>=2&buff.opportunity.stack>=6
  -- &(buff.broadside.up&combo_points<=1|buff.greenskins_wickers.up)
  if S.PistolShot:IsCastable() and S.Crackshot:IsAvailable() and S.FanTheHammer:TalentRank() >= 2 and Player:BuffStack(S.Opportunity) >= 6
    and (Player:BuffUp(S.Broadside) and ComboPoints <= 1 or Player:BuffUp(S.GreenskinsWickersBuff)) then
    if ReturnSpellOnly then
      return S.PistolShot
    else
      if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
        return "Cast Pistol Shot (Crackshot)"
      end
    end
  end

  -- ***NOT PART of SimC*** Condition duplicated from build to Show SS Icon in stealth with audacity buff
  if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.AudacityBuff) then
    if ReturnSpellOnly then
      return S.SSAudacity
    else
      if CastPooling(S.SSAudacity, nil, not Target:IsSpellInRange(S.Ambush)) then
        return "Cast Ambush (SS High-Prio Buffed)"
      end
    end
  end

  -- actions.stealth+=/ambush,if=talent.hidden_opportunity
  if S.Ambush:IsCastable() and S.HiddenOpportunity:IsAvailable() then
    if ReturnSpellOnly then
      return S.Ambush
    else
      if CastPooling(S.Ambush, nil, not Target:IsSpellInRange(S.Ambush)) then
        return "Cast Ambush"
      end
    end
  end

  -- ***NOT PART of SimC*** The builder list isn't part of Stealth so in the case of an any CP vanish to prevent AR
  -- falling off and BF / Ambush (KiR) / finisher conditions aren't met show a vanish combo with SS instead of vanish
  -- on it's own
  if S.SinisterStrike:IsCastable() and not Finish_Condition() then
    if ReturnSpellOnly then
      return S.SinisterStrike
    end
  end
end

local function Finish(ReturnSpellOnly)
  -- actions.finish+=/killing_spree
  if S.KillingSpree:IsCastable() and (Player:BuffDown(S.AdrenalineRush) or Player:BuffRemains(S.AdrenalineRush) > KSHastedDuration) then
    if ReturnSpellOnly then
      return S.KillingSpree
    else
      if Cast(S.KillingSpree, nil, Settings.Outlaw.KillingSpreeDisplayStyle, not Target:IsSpellInRange(S.KillingSpree), nil) then
        return "Cast Killing Spree"
      end
    end
  end

  -- actions.finish+=/coup_de_grace
  if S.CoupDeGrace:IsCastable() then
    if ReturnSpellOnly then
      return S.CoupDeGrace
    else
      if CastPooling(S.CoupDeGrace, nil, not Target:IsSpellInRange(S.CoupDeGrace)) then
        return "Cast Coup de Grace"
      end
    end
  end

  -- # Use Between the Eyes outside of Stealth to maintain the buff, or with Ruthless Precision active,
  -- or to proc Greenskins Wickers if not active. Trickster builds can also send BtE on cooldown.
  -- actions.finish=between_the_eyes,if=(buff.ruthless_precision.up|buff.between_the_eyes.remains<4|!talent.mean_streak)
  -- &(!buff.greenskins_wickers.up|!talent.greenskins_wickers)
  if S.BetweentheEyes:IsCastable() and (Player:BuffUp(S.RuthlessPrecision) or Player:BuffRemains(S.BetweentheEyes) < 4 or
    not S.MeanStreak:IsAvailable()) and (Player:BuffDown(S.GreenskinsWickersBuff) or not S.GreenskinsWickers:IsAvailable()) then
    if ReturnSpellOnly then
      return S.BetweentheEyes
    else
      if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
        return "Cast Between the Eyes (Finish)"
      end
    end
  end

  -- # Crackshot builds use Between the Eyes outside of Stealth to refresh the Between the Eyes crit buff or on cd with the Ruthless Precision buff
  -- actions.finish+=/between_the_eyes,if=talent.crackshot&(buff.ruthless_precision.up|buff.between_the_eyes.remains<4|!talent.keep_it_rolling|!talent.mean_streak)
  if S.BetweentheEyes:IsCastable() then
    if S.Crackshot:IsAvailable() and (Player:BuffUp(S.RuthlessPrecision) or Player:BuffRemains(S.BetweentheEyes) < 4
    or not S.KeepItRolling:IsAvailable() or not S.MeanStreak:IsAvailable()) then
      if ReturnSpellOnly then
        return S.BetweentheEyes
      else
        if CastPooling(S.BetweentheEyes, nil, not Target:IsSpellInRange(S.BetweentheEyes)) then
          return "Cast Between the Eyes (Crackshot OOS)"
        end
      end
    end
  end

  if S.ColdBlood:IsCastable() and Player:BuffDown(S.ColdBlood) then
    if Cast(S.ColdBlood, Settings.CommonsOGCD.OffGCDasOffGCD.ColdBlood) then
      return "Cast Cold Blood"
    end
  end

  -- actions.finish+=/dispatch
  if S.Dispatch:IsCastable() then
    if ReturnSpellOnly then
      return S.Dispatch
    else
      if CastPooling(S.Dispatch, nil, not Target:IsSpellInRange(S.Dispatch)) then
        return "Cast Dispatch (Finish)"
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
    if S.RolltheBones:IsCastable() then
      if RtB_Reroll(S.LoadedDice:IsAvailable()) or Cache.APLVar.RtB_Buffs.Total == 0 then
        MacroAbility = S.RolltheBones
      end
    end

    -- If we don't need to reroll then we can check finishers
    if not MacroAbility then
      -- Fetch Finisher if not in stealth (AR->Dispatch/Coup) or Stealth Ability if we are (AR->BtE)
      -- Outside of stealth could be AR -> Vanish -> BtE so check for this first then fallback into normal finisher.
      if not Player:StealthUp(true, true) then
        -- AR->Coup Highest prio, outside of stealth especially if double coup
        if S.CoupDeGrace:IsCastable() and (S.CoupDeGrace:TimeSinceLastCast() < 1 and Player:BuffUp(S.AdrenalineRush)) then
          MacroAbility = S.CoupDeGrace
        else
          local MacroAbilities = StealthCDs(true)

          -- Make sure StealthCDs returned a combo which may not happen if targeting something out of range
          if MacroAbilities and MacroAbilities[2] and MacroAbilities[2] ~= "Cast Vanish"
            and Settings.Outlaw.SpellQueueMacro.ImprovedAdrenalineRush then
            local ARMacroTable = { BaseSpell, unpack(MacroAbilities) }
            ShouldReturn = CastQueue(unpack(ARMacroTable))
            if ShouldReturn then
              return "| " .. ARMacroTable[2]:Name() .. " | " .. ARMacroTable[3]:Name()
            end
          end

          MacroAbility = Finish(true)
        end
      else
        MacroAbility = Stealth(true)
      end
    end
    if not Settings.Outlaw.SpellQueueMacro.ImprovedAdrenalineRush or not MacroAbility then
      if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
        return "Cast Adrenaline Rush"
      end
      return false
    end
  end

  local MacroTable = { BaseSpell, MacroAbility }
  ShouldReturn = CastQueue(unpack(MacroTable))
  if ShouldReturn then
    return "| " .. MacroTable[2]:Name()
  end

  ComboPoints = Player:ComboPoints()
  return false
end

function StealthCDs (ReturnSpellOnly)
  -- # Flex Vanish usage for standard builds.

  -- # Without Killing Spree, attempt to hold Vanish for when BtE is on cooldown and Ruthless Precision is active.
  -- Also with Keep it Rolling, hold Vanish if we haven't done the first roll after KIR yet.
  -- actions.vanish_usage=vanish,if=!talent.killing_spree&!cooldown.between_the_eyes.ready&buff.ruthless_precision.remains>4
  -- &(cooldown.keep_it_rolling.remains>150&rtb_buffs.normal>0|!talent.keep_it_rolling)
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.KillingSpree:IsAvailable() and not S.BetweentheEyes:IsReady() and Player:BuffRemains(S.RuthlessPrecision) > 4
      and (S.KeepItRolling:CooldownRemains() > 150 and Cache.APLVar.RtB_Buffs.Normal > 0 or not S.KeepItRolling:IsAvailable()) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 1 " .. ShouldReturn
      end
    end
  end

  -- # Supercharger builds that do not use Killing Spree should also Vanish if Supercharger becomes active.
  -- actions.vanish_usage+=/vanish,if=!talent.killing_spree&buff.supercharge_1.up
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.KillingSpree:IsAvailable() and ChargedComboPoints > 0 then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 2 " .. ShouldReturn
      end
    end
  end

  -- # Builds with Killing Spree can freely Vanish if KS is not up soon.
  -- actions.vanish_usage+=/vanish,if=cooldown.killing_spree.remains>15
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if S.KillingSpree:CooldownRemains() > 30 then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 3 " .. ShouldReturn
      end
    end
  end

  -- # Vanish if about to cap on charges or fight is ending.
  -- actions.vanish_usage+=/vanish,if=cooldown.vanish.full_recharge_time<15|fight_remains<8
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if S.Vanish:FullRechargeTime() < 15 or HL.BossFilteredFightRemains("<", 8) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 4 " .. ShouldReturn
      end
    end
  end
end

local function StealthCDs_2 (ReturnSpellOnly)
  -- Flex Vanish usage for builds lacking one of the mandatory stealth talents. APL support for these builds is considered limited.

  --actions.stealth_cds_2=vanish,if=talent.underhanded_upper_hand&talent.subterfuge&!talent.crackshot&buff.adrenaline_rush.up
  -- &(variable.ambush_condition|!talent.hidden_opportunity)&(!cooldown.between_the_eyes.ready
  -- &buff.ruthless_precision.up|buff.ruthless_precision.down|buff.adrenaline_rush.remains<3)
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if S.UnderhandedUpperhand:IsAvailable() and S.Subterfuge:IsAvailable() and not S.Crackshot:IsAvailable() and Player:BuffUp(S.AdrenalineRush)
      and (Ambush_Condition() or not S.HiddenOpportunity:IsAvailable()) and (not S.BetweentheEyes:IsReady() and Player:BuffUp(S.RuthlessPrecision)
      or Player:BuffDown(S.RuthlessPrecision or Player:BuffRemains(S.AdrenalineRush) < 3)) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 1 (Off Meta) " .. ShouldReturn
      end
    end
  end

  --actions.stealth_cds_2+=/vanish,if=!talent.underhanded_upper_hand&talent.crackshot&variable.finish_condition
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and S.Crackshot:IsAvailable() and Finish_Condition() then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 2 (Off Meta) " .. ShouldReturn
      end
    end
  end

  --actions.stealth_cds_2+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&talent.hidden_opportunity
  -- &!buff.audacity.up&buff.opportunity.stack<buff.opportunity.max_stack&variable.ambush_condition
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and S.HiddenOpportunity:IsAvailable()
      and not Player:BuffUp(S.AudacityBuff) and Player:BuffStack(S.Opportunity) < 6 and Ambush_Condition() then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 3 (Off Meta) " .. ShouldReturn
      end
    end
  end

  --actions.stealth_cds_2+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&!talent.hidden_opportunity
  -- &talent.fateful_ending&(!buff.fatebound_lucky_coin.up&(buff.fatebound_coin_tails.stack>=5|buff.fatebound_coin_heads.stack>=5)
  -- |buff.fatebound_lucky_coin.up&!cooldown.between_the_eyes.ready)
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and not S.HiddenOpportunity:IsAvailable()
      and S.FatefulEnding:IsAvailable() and (not Player:BuffUp(S.FateboundLuckyCoin)
      and (Player:BuffStack(S.FateboundCoinTails) >= 5 or Player:BuffStack(S.FateboundCoinHeads) >= 5)
      or Player:BuffUp(S.FateboundLuckyCoin) and not S.BetweentheEyes:IsReady()) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 4 (Off Meta) " .. ShouldReturn
      end
    end
  end

  --actions.stealth_cds_2+=/vanish,if=!talent.underhanded_upper_hand&!talent.crackshot&!talent.hidden_opportunity
  -- &!talent.fateful_ending&talent.take_em_by_surprise&!buff.take_em_by_surprise.up
  if S.Vanish:IsCastable() and Vanish_DPS_Condition() then
    if not S.UnderhandedUpperhand:IsAvailable() and not S.Crackshot:IsAvailable() and not S.HiddenOpportunity:IsAvailable()
      and not S.FatefulEnding:IsAvailable() and S.TakeEmBySurprise:IsAvailable() and not Player:BuffUp(S.TakeEmBySurpriseBuff) then
      ShouldReturn = SpellQueueMacro(S.Vanish, ReturnSpellOnly)
      if ShouldReturn then
        if ReturnSpellOnly then
          return { S.Vanish, ShouldReturn }
        end
        return "Vanish Macro 5 (Off Meta) " .. ShouldReturn
      end
    end
  end

  --actions.stealth_cds_2+=/shadowmeld,if=variable.finish_condition&!cooldown.vanish.ready
  if S.Shadowmeld:IsCastable() and Finish_Condition() and not S.Vanish:IsReady() then
    if Cast(S.Shadowmeld, Settings.Outlaw.GCDasOffGCD.Shadowmeld) then
      return "Cast Shadowmeld (Off Meta)"
    end
  end
end

local function CDs ()
  -- # Maintain Adrenaline Rush if it is not active. Use at low CPs with Improved AR.
  -- actions.cds=adrenaline_rush,if=!buff.adrenaline_rush.up&(!variable.finish_condition|!talent.improved_adrenaline_rush)
  if CDsON() and S.AdrenalineRush:IsCastable()
    and not Player:BuffUp(S.AdrenalineRush) and (not Finish_Condition() or not S.ImprovedAdrenalineRush:IsAvailable()) then
    if S.ImprovedAdrenalineRush:IsAvailable() then
      ShouldReturn = SpellQueueMacro(S.AdrenalineRush)
      if ShouldReturn then
        return "AR Finisher Macro 1 " .. ShouldReturn
      end
    else
      if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
        return "Cast Adrenaline Rush 1"
      end
    end
  end

  -- # If using Improved AR, recast AR if it is already active at low CPs.
  -- actions.cds+=/adrenaline_rush,if=buff.adrenaline_rush.up&talent.improved_adrenaline_rush&combo_points<=2
  if CDsON() and S.AdrenalineRush:IsCastable() then
    if Player:BuffUp(S.AdrenalineRush) and S.ImprovedAdrenalineRush:IsAvailable() and ComboPoints <= 2 then
      if S.ImprovedAdrenalineRush:IsAvailable() then
        ShouldReturn = SpellQueueMacro(S.AdrenalineRush)
        if ShouldReturn then
          return "AR Finisher Macro 2 " .. ShouldReturn
        end
      else
        if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          return "Cast Adrenaline Rush 2"
        end
      end
    end
  end

  -- # High priority Ghostly Strike as it is off-gcd. 1 FTH builds prefer to not use it at max CPs.
  -- actions.cds+=/ghostly_strike,if=combo_points<cp_max_spend|talent.fan_the_hammer.rank>1
  if S.GhostlyStrike:IsCastable() then
    if ComboPoints < Rogue.CPMaxSpend() or S.FanTheHammer:TalentRank() > 1 then
      if Cast(S.GhostlyStrike, Settings.Outlaw.OffGCDasOffGCD.GhostlyStrike, nil, not Target:IsSpellInRange(S.GhostlyStrike)) then
        return "Cast Ghostly Strike"
      end
    end
  end

  -- double coup
  if S.CoupDeGrace:IsCastable() and S.CoupDeGrace:TimeSinceLastCast() < 1 and Player:BuffUp(S.AdrenalineRush) then
    if CastPooling(S.CoupDeGrace, nil, not Target:IsSpellInRange(S.CoupDeGrace)) then
      return "Double Coup De Grace CDs"
    end
  end

  -- # Sprint to further benefit from Scroll of Momentum trinket
  -- actions.cds+=/sprint,if=(trinket.1.is.scroll_of_momentum|trinket.2.is.scroll_of_momentum)&buff.full_momentum.up
  if S.Sprint:IsCastable() and Player:BuffDown(S.Sprint) and
    (trinket1:ID() == I.ScrollOfMomentum:ID() or trinket2:ID() == I.ScrollOfMomentum:ID()) and Player:BuffUp(S.FullMomentum) then
    if Cast(S.Sprint, Settings.CommonsOGCD.OffGCDasOffGCD.Sprint) then
      return "Cast Sprint"
    end
  end

  -- # Maintain Blade Flurry on 2+ targets
  if S.BladeFlurry:IsCastable() then
    if EnemiesBFCount >= 2 and Player:BuffRemains(S.BladeFlurry) < Player:GCD() then
      if Cast(S.BladeFlurry, Settings.Outlaw.GCDasOffGCD.BladeFlurry) then
        return "Cast Blade Flurry"
      end
    end
  end

  -- # With a natural 5 buff roll, use Keep it Rolling when you obtain the remaining buff from Count the Odds and all buffs are within 30s remaining.
  -- actions.cds+=/keep_it_rolling,if=rtb_buffs.normal>=5&rtb_buffs=6
  if S.KeepItRolling:IsCastable() then
    if Cache.APLVar.RtB_Buffs.Normal >= 5 and Cache.APLVar.RtB_Buffs.Total == 6 then
      if Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then
        return "Cast Keep it Rolling"
      end
    end
  end

  -- # Without a natural 5 buff roll, use Keep it Rolling at 4+ buffs
  -- actions.cds+=/keep_it_rolling,if=rtb_buffs>=4&rtb_buffs.normal<=2
  if S.KeepItRolling:IsCastable() and Cache.APLVar.RtB_Buffs.Total >= 4 and Cache.APLVar.RtB_Buffs.Normal <= 2 then
    if Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then
      return "Cast Keep it Rolling"
    end
  end

  -- # Without a natural 5 buff roll, use Keep it Rolling at 3 buffs if you have the combination of Ruthless Precision + Broadside + True Bearing.
  -- actions.cds+=/keep_it_rolling,if=rtb_buffs>=3&rtb_buffs.normal<=2&buff.broadside.up&buff.ruthless_precision.up&buff.true_bearing.up
  if S.KeepItRolling:IsCastable() and Cache.APLVar.RtB_Buffs.Total >= 3 and Cache.APLVar.RtB_Buffs.Normal <= 2
    and Player:BuffUp(S.Broadside) and Player:BuffUp(S.RuthlessPrecision) and Player:BuffUp(S.TrueBearing) then
    if Cast(S.KeepItRolling, Settings.Outlaw.GCDasOffGCD.KeepItRolling) then
      return "Cast Keep it Rolling"
    end
  end

  -- # Roll the bones if you have no buffs, or will lose no buffs by rolling. With Loaded Dice up, roll if you have 1 buff or will lose at most 1 buff.
  if S.RolltheBones:IsCastable() then
    if RtB_Reroll() or Cache.APLVar.RtB_Buffs.Total == 0 then
      if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then
        return "Cast Roll the Bones"
      end
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

  -- # If necessary, standard builds prioritize using Vanish at any CP to prevent Adrenaline Rush downtime.
  -- actions.cds+=/vanish,if=talent.underhanded_upper_hand&talent.subterfuge&buff.adrenaline_rush.up&!stealthed.all
  -- &buff.adrenaline_rush.remains<2&cooldown.adrenaline_rush.remains>30
  if S.UnderhandedUpperhand:IsAvailable() and S.Subterfuge:IsAvailable() and Player:BuffUp(S.AdrenalineRush)
    and not Player:StealthUp(true, true) and Player:BuffRemains(S.AdrenalineRush) < 2 and S.AdrenalineRush:CooldownRemains() > 30 then
    ShouldReturn = StealthCDs()
    if ShouldReturn then
      return ShouldReturn
    end
  end

  -- # If not at risk of losing Adrenaline Rush, run finishers to use Killing Spree or Coup de Grace as a higher priority than Vanish.
  -- actions.cds+=/run_action_list,name=finish,if=!stealthed.all&(cooldown.killing_spree.ready&talent.killing_spree
  -- |buff.escalating_blade.stack>=4)&variable.finish_condition
  if not Player:StealthUp(true, true) and (S.KillingSpree:IsReady() and S.KillingSpree:IsAvailable()
    or Player:BuffStack(S.EscalatingBlade) >= 4) and Finish_Condition() then
    ShouldReturn = Finish()
    if ShouldReturn then
      return "Finish CDs: " .. ShouldReturn
    end
  end

  -- # If not at risk of losing Adrenaline Rush, call flexible Vanish rules to be used at finisher CPs.
  -- Trickster builds attempt to hold Vanish if at 3 stacks of Escalating Blades with Disorienting Strikes active.
  -- actions.cds+=/call_action_list,name=vanish_usage,if=!stealthed.all&talent.crackshot&talent.underhanded_upper_hand
  -- &talent.subterfuge&buff.adrenaline_rush.up&variable.finish_condition
  if not Player:StealthUp(true, true) and S.Crackshot:IsAvailable() and S.UnderhandedUpperhand:IsAvailable()
    and S.Subterfuge:IsAvailable() and Player:BuffUp(S.AdrenalineRush) and Finish_Condition() then
    ShouldReturn = StealthCDs()
    if ShouldReturn then
      return ShouldReturn
    end
  end

  -- # Secondary stealth cds list for off meta builds missing at least one of Underhanded Upper Hand, Crackshot or Subterfuge
  --actions.cds+=/call_action_list,name=stealth_cds_2,if=!stealthed.all&(!talent.underhanded_upper_hand|!talent.crackshot|!talent.subterfuge)
  if not Player:StealthUp(true, true) and (not S.UnderhandedUpperhand:IsAvailable() or not S.Crackshot:IsAvailable() or not S.Subterfuge:IsAvailable()) then
    ShouldReturn = StealthCDs_2()
    if ShouldReturn then
      return ShouldReturn
    end
  end

  -- # Generic catch-all for Shadowmeld. Technically, usage in DungeonSlice or DungeonRoute sims could mirror Vanish usage on packs.
  -- actions.stealth_cds+=/shadowmeld,if=variable.finish_condition&!cooldown.vanish.ready
  if S.Shadowmeld:IsAvailable() and S.Shadowmeld:IsReady() and Finish_Condition() and not S.Vanish:IsReady() then
    if Cast(S.Shadowmeld, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then
      return "Cast Shadowmeld"
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

  -- # Let the magnet trinket stack up just so it does not disrupt a 2nd on-use trinket.
  -- actions.cds+=/use_item,name=junkmaestros_mega_magnet,if=buff.between_the_eyes.up&buff.junkmaestros_mega_magnet.stack>25|fight_remains<5
  if Settings.Commons.Enabled.Trinkets then
    if I.JunkmaestrosMegaMagnet:IsEquippedAndReady() then
      if Player:BuffUp(S.BetweentheEyes) and Player:BuffStack(S.JunkmaestrosBuff) > 25 or HL.BossFilteredFightRemains("<", 5) then
        if Cast(I.JunkmaestrosMegaMagnet, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsItemInRange(I.JunkmaestrosMegaMagnet)) then
          return "Junkmaestros Mega Magnet";
        end
      end
    end
  end

  if Settings.Commons.Enabled.Trinkets then
    -- # Default conditions for usable items.
    -- actions.cds+=/use_items,slots=trinket1,if=debuff.between_the_eyes.up|trinket.1.has_stat.any_dps|fight_remains<=20
    -- actions.cds+=/use_items,slots=trinket2,if=debuff.between_the_eyes.up|trinket.2.has_stat.any_dps|fight_remains<=20
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    local TrinketToUse, TrinketRange
    if Trinket1ToUse then
      TrinketToUse = Trinket1ToUse
      TrinketRange = Trinket1Range
    elseif Trinket2ToUse then
      TrinketToUse = Trinket2ToUse
      TrinketRange = Trinket2Range
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

  -- # Trickster builds should prioritize Sinister Strike during Disorienting Strikes.
  -- HO builds prefer to do this only at 3 Escalating Blade stacks and not at max Opportunity stacks.
  -- actions.build+=/sinister_strike,if=buff.disorienting_strikes.up&!stealthed.all&(buff.escalating_blade.stack>2
  -- &buff.opportunity.stack<buff.opportunity.max_stack|!talent.hidden_opportunity)&buff.escalating_blade.stack<4
  if S.SinisterStrike:IsCastable() then
    if Rogue.DisorientingStrikesCount() > 0 and not Player:StealthUp(true, true)
      and (Player:BuffStack(S.EscalatingBlade)>2 and Player:BuffStack(S.Opportunity) < 6 or not S.HiddenOpportunity:IsAvailable())
      and Player:BuffStack(S.EscalatingBlade) < 4 then
      if CastPooling(S.SinisterStrike, nil, not Target:IsSpellInRange(S.SinisterStrike)) then
        return "Cast Sinister Strike... Spend Disorienting Strikes"
      end
    end
  end

  -- # With Audacity + Hidden Opportunity + Fan the Hammer, consume Opportunity to proc Audacity any time Ambush is not available
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&talent.audacity&talent.hidden_opportunity&buff.opportunity.up&!buff.audacity.up
  if S.FanTheHammer:IsAvailable() and S.Audacity:IsAvailable() and S.HiddenOpportunity:IsAvailable() and Player:BuffUp(S.Opportunity) and Player:BuffDown(S.AudacityBuff) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot (Audacity)"
    end
  end

  -- # Without Hidden Opportunity, prioritize building CPs with Blade Flurry at 4+ targets, with low CPs unless AR isn't active.
  -- actions.build+=/blade_flurry,if=talent.deft_maneuvers&spell_targets>=4&(combo_points<=2|!buff.adrenaline_rush.up)
  if S.BladeFlurry:IsCastable() then
    if S.DeftManeuvers:IsAvailable() and EnemiesBFCount >= 4 and (ComboPoints <= 2 or Player:BuffDown(S.AdrenalineRush)) then
      if Cast(S.BladeFlurry, Settings.Outlaw.GCDasOffGCD.BladeFlurry) then
        return "Cast Blade Flurry (Fatebound or 1FTH)"
      end
    end
  end

  -- # With 2 ranks in Fan the Hammer, consume Opportunity as a higher priority if at max stacks or if it will expire
  -- actions.build+=/pistol_shot,if=talent.fan_the_hammer&buff.opportunity.up&(buff.opportunity.stack>=buff.opportunity.max_stack|buff.opportunity.remains<2)
    if S.FanTheHammer:IsAvailable() and S.FanTheHammer:TalentRank() == 2 and Player:BuffUp(S.Opportunity)
      and (Player:BuffStack(S.Opportunity) >= 6 or Player:BuffRemains(S.Opportunity) < 2) then
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

  -- # If not using Fan the Hammer, then consume Opportunity based on energy, when it will exactly cap CPs, or when using Quick Draw
  -- actions.build+=/pistol_shot,if=!talent.fan_the_hammer&buff.opportunity.up&(energy.base_deficit>energy.regen*1.5|combo_points.deficit<=1+buff.broadside.up
  -- |talent.quick_draw.enabled|talent.audacity.enabled&!buff.audacity.up)
  if not S.FanTheHammer:IsAvailable() and Player:BuffUp(S.Opportunity) and (EnergyTimeToMax > 1.5 or ComboPointsDeficit <= 1 + num(Player:BuffUp(S.Broadside))
    or S.QuickDraw:IsAvailable() or S.Audacity:IsAvailable() and Player:BuffDown(S.AudacityBuff)) then
    if CastPooling(S.PistolShot, nil, not Target:IsSpellInRange(S.PistolShot)) then
      return "Cast Pistol Shot (No Fan the Hammer)"
    end
  end

  -- # Use Coup de Grace at low CP if Sinister Strike would otherwise be used.
  -- actions.build+=/coup_de_grace,if=!stealthed.all
  if S.CoupDeGrace:IsCastable() and not Player:StealthUp(true, true) then
    if CastPooling(S.CoupDeGrace, nil, not Target:IsSpellInRange(S.CoupDeGrace)) then
      return "Low CP Coup De Grace"
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
  RtB_Buffs()
  BladeFlurryRange = 8
  ComboPoints = Player:ComboPoints()
  ChargedComboPoints = Player:ChargedComboPoints()

  -- Calculate Killing Spree Hasted Duration based on current player HastePct
  --  This allows KS to be delayed if AR will fall off during it.
  EffectiveChargedComboPoints = 0
  if ComboPoints > 0 and ChargedComboPoints > 0 then
    EffectiveChargedComboPoints = ChargedComboPoints + num(S.ForcedInduction:IsAvailable())
  end
  EffectiveComboPoints = ComboPoints + EffectiveChargedComboPoints
  ComboPointsDeficit = Player:ComboPointsDeficit()
  KSBaseDuration = EffectiveComboPoints * 0.4
  HasteMultiplier = 1 + (Player:HastePct() / 100)
  KSHastedDuration = KSBaseDuration / HasteMultiplier

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
      -- # Builds with Keep it Rolling+Loaded Dice prepull Adrenaline Rush before Roll the Bones to consume Loaded Dice immediately instead of on the next pandemic roll.
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=1,if=talent.improved_adrenaline_rush&talent.keep_it_rolling&talent.loaded_dice
      if S.AdrenalineRush:IsCastable() and S.ImprovedAdrenalineRush:IsAvailable() and S.KeepItRolling:IsAvailable()
        and S.LoadedDice:IsAvailable() and (not S.Supercharger:IsAvailable() or ChargedComboPoints == 0) then
        if Cast(S.AdrenalineRush, Settings.Outlaw.OffGCDasOffGCD.AdrenalineRush) then
          return "Cast Adrenaline Rush (Opener KiR)"
        end
      end
      -- actions.precombat+=/roll_the_bones,precombat_seconds=1
      -- Use same extended logic as a normal rotation for between pulls
      if S.RolltheBones:IsCastable() and not Player:DebuffUp(S.Dreadblades) and (Cache.APLVar.RtB_Buffs.Total == 0 or RtB_Reroll())
        and (not S.Supercharger:IsAvailable() or ChargedComboPoints == 0) then
        if Cast(S.RolltheBones, Settings.Outlaw.GCDasOffGCD.RollTheBones) then
          return "Cast Roll the Bones (Opener)"
        end
      end
      -- actions.precombat+=/adrenaline_rush,precombat_seconds=0,if=talent.improved_adrenaline_rush
      if S.AdrenalineRush:IsCastable() and S.ImprovedAdrenalineRush:IsAvailable() then
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
    else
      -- actions+=/call_action_list,name=build
      ShouldReturn = Build()
      if ShouldReturn then
        return "Build: " .. ShouldReturn
      end
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
  HR.Print("Outlaw Rogue rotation has been updated for patch 11.1.0 \n ",
    "Note: It is known & Intended that Audacity procs will suggest Sinister Strike without a keybind shown")
end

HR.SetAPL(260, APL, Init)
