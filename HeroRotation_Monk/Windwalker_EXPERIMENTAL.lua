-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Lua
local mathmin    = math.min
local pairs      = pairs;


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker;
local I = Item.Monk.Windwalker;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
--  I.GalecallersBoon:ID(),
}

-- Rotation Var
local IsInMeleeRange
local IsInAoERange
local Enemies5y
local Enemies8y
local EnemiesCount8
local ShouldReturn
local Interrupts = {
  { S.SpearHandStrike, "Cast Spear Hand Strike (Interrupt)", function () return true end },
}
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
}
local KnockBack = {
  { S.RingOfPeace, "Cast Ring Of Peace (Stun)", function () return true end },
}
local Traps = {
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

-- Legendary variables
local CelestialInfusionEquipped = Player:HasLegendaryEquipped(88)
local EscapeFromRealityEquipped = Player:HasLegendaryEquipped(82)
local FatalTouchEquipped = Player:HasLegendaryEquipped(85)
local InvokersDelightEquipped = Player:HasLegendaryEquipped(83)
local JadeIgnitionEquipped = Player:HasLegendaryEquipped(96)
local KeefersSkyreachEquipped = Player:HasLegendaryEquipped(95)
local LastEmperorsCapacitorEquipped = Player:HasLegendaryEquipped(97)
local XuensTreasureEquipped = Player:HasLegendaryEquipped(94)

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
end, "PLAYER_REGEN_ENABLED")

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange(range)
  if S.TigerPalm:TimeSinceLastCast() <= Player:GCD() then
    return true
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

local EnemyRanges = {5, 8, 10, 30, 40, 100}
local TargetIsInRange = {}
local function ComputeTargetRange()
  for _, i in ipairs(EnemyRanges) do
    if i == 8 or 5 then TargetIsInRange[i] = Target:IsInMeleeRange(i) end
    TargetIsInRange[i] = Target:IsInRange(i)
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EnergyTimeToMaxRounded()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end

local function EnergyPredictedRounded()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

-- Cast the spell, but choose the target with the minimum remaining timer on it's crane stacks.
local function CastAtBestCraneTarget(SpellObject, DebugMessage)
  local BestUnit = Target
  local min_time = Target:DebuffRemains(S.MarkOfTheCraneDebuff)
  for _, Unit in pairs(Enemies8y) do
    local unit_time = Unit:DebuffRemains(S.MarkOfTheCraneDebuff)
    if unit_time < min_time then
      BestUnit = Unit
      min_time = unit_time
    end
  end
  if BestUnit:GUID() == Target:GUID()  then
    if HR.Cast(SpellObject, nil, nil, not Target:IsInMeleeRange(8)) then return DebugMessage end
  else
    if HR.CastLeftNameplate(BestUnit, SpellObject) then return DebugMessage end
  end
end

-- This function returns a table, indexed by spell object (S.XXX) keys.
-- It contains the current-state chi costs of each chi spender (perhaps zero).
-- Assumption here is that we always want to fists on CD, so we don't bother tracking it here.
local function ChiSpenderCosts()
  costs = {}
  costs[S.RisingSunKick] = 2
  costs[S.SpinningCraneKick] = 2
  costs[S.RushingJadeWind] = 1
  costs[S.BlackoutKick] = 1
  if Player:BuffUp(S.WeaponsOfOrder) then
    for spell, cost in pairs(costs) do
      costs[spell] = max(0, cost-1)
    end
  end
  if Player:BuffUp(S.DanceOfChijiBuff) then
    costs[S.SpinningCraneKick] = 0
  end
  if Player:BuffUp(S.BlackoutKickBuff) then
    costs[S.BlackoutKick] = 0
  end
  if Player:BuffUp(S.SerenityBuff) then
    for spell, cost in pairs(costs) do
      costs[spell] = 0
    end
  end
  return costs
end

local function MarkOfTheCraneStacks()
  return GetSpellCount(101546)
end

local function AbilityPower()
  local mh = GetInventoryItemLink("player", 16)
  local mh_dps = GetItemStats(mh)["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
  local oh = GetInventoryItemLink("player", 17)
  if oh ~= nil then
    local oh_dps = GetItemStats(oh)["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
    return 1.02 * (4*mh_dps + 2*oh_dps + Player:AttackPower())
  else
    return 0.98 * (6*mh_dps + Player:AttackPower())
  end
end

-- This function returns a table, indexed by spell object (S.XXX) keys.
-- It returns a table of values of using the given chi spender in the current state.
-- See https://docs.google.com/spreadsheets/d/1Agwilw8sG5PeBBgACneZl3J4jumS1EBWQAJK8BIUzgE/edit#gid=0
-- TODO: autoattack loss on SCK
-- TODO: BOK value from CDR
local function ChiSpenderValues()
  -- Set up some variables/constants here.
  -- Base multipliers
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local armor_reduction_coeff = 0.70
  local mystic_touch_coeff = 1.05

  values = {}
  -- RSK
  local rsk_ap_coeff = 1.438
  local rsk_aura_coeff = 0.87 * 1.26 * 1.7
  local rsk_tooltip = ability_power * rsk_ap_coeff * rsk_aura_coeff * vers_coeff
  local rsk_damage = rsk_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  values[S.RisingSunKick] = rsk_damage
  -- SCK
  local sck_ap_coeff = 0.40
  local sck_aura_coeff = 0.87 * 2.4
  local calculated_strikes_effect = 0.0
  if S.CalculatedStrikes:ConduitEnabled() then calculated_strikes_effect = 0.1 + 0.01*(S.CalculatedStrikes:ConduitRank() - 1) end
  local crane_coeff = 1 + (0.1 + calculated_strikes_effect) * MarkOfTheCraneStacks()
  local chiji_coeff = 1.0
  if Player:BuffUp(S.DanceOfChijiBuff) then chiji_coeff = 3.0 end
  local sck_tooltip = ability_power * sck_ap_coeff * sck_aura_coeff * vers_coeff * crane_coeff * chiji_coeff
  local sck_damage = sck_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  values[S.SpinningCraneKick] = sck_damage * num_targets
  -- RJW
  local rjw_ap_coeff = 0.90
  local rjw_aura_coeff = 0.87 * 1.22
  local rjw_tooltip = ability_power * rjw_ap_coeff * rjw_aura_coeff * vers_coeff
  local rjw_damage = rjw_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  values[S.RushingJadeWind] = num_targets * rjw_damage
  -- BOK
  local bok_ap_coeff = 0.847
  local bok_aura_coeff = 0.87 * 1.26 * 1.1
  local bok_tooltip = ability_power * bok_ap_coeff * bok_aura_coeff * vers_coeff
  local bok_damage = bok_tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  values[S.BlackoutKick] = bok_damage

  return values
end



-- Returns the ability (completely not subject to any constraints) that is the "best damage per chi" in the given scenario.
-- This function takes a parameter "constrain_to_available" which, if set true, only considers spells that are off CD and a combo strike.
-- The second form of this function is useful if we *have* to spend chi at chi-cap.
local function BestDamagePerChi(constrain_to_available)
  local values_table = ChiSpenderValues()
  local costs_table = ChiSpenderCosts()

  local best_spell = nil
  local best_eff = 0

  for spell, cost in pairs(costs_table) do
   --print("Spell: " .. spell.SpellName .. " cost=" .. cost .. " val=" .. values_table[spell])
    local mod_cost = cost
    -- Avoid divide-by-zero here>
    if cost == 0 then mod_cost = 0.001 end
    local eff = values_table[spell] / mod_cost
    if eff > best_eff and (not constrain_to_available or (spell:IsReady() and ComboStrike(spell))) then
      best_spell = spell
      best_eff = eff
    end
  end
  --print("------------------------")
  return best_spell
end

local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function UseCooldowns()
  -- notable TODO: consider putting energizing elixir into main rotation
  -- elixir is off gcd, as is serenity/SEF, but elixir is less of a CD and more of a rotational thing
  if S.InvokeXuenTheWhiteTiger:IsReady() then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "Invoke Xuen the White Tiger"; end
  end
  if S.StormEarthAndFire:IsReady() and (S.StormEarthAndFire:Charges() == 2 or HL.BossFilteredFightRemains("<", 20) or ((not S.WeaponsOfOrder:IsAvailable()) and ((S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and (S.FistsOfFury:CooldownRemains() <= 9) and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.CastSuggested(S.StormEarthAndFire) then return "Storm Earth and Fire non-kyrian"; end
  end
  if S.StormEarthAndFire:IsReady() and S.WeaponsOfOrder:IsAvailable() and (Player:BuffUp(S.WeaponsOfOrder) or ((HL.BossFilteredFightRemains("<", S.WeaponsOfOrder:CooldownRemains()) or (S.WeaponsOfOrder:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.CastSuggested(S.StormEarthAndFire) then return "Storm Earth and Fire kyrian"; end
  end

  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 2) or Player:ChiDeficit() >= 4) then
    if HR.CastRightSuggested(S.EnergizingElixir) then return "Elixir CD"; end
  end
  if S.TouchOfDeath:IsReady() and Target:Health() < UnitHealthMax("player") then
    if HR.CastRightSuggested(S.TouchOfDeath) then return "Touch of Death Main Target"; end
  end
  if S.WeaponsOfOrder:IsReady() then
    if HR.Cast(S.WeaponsOfOrder, true, nil, not Target:IsInRange(40)) then return "Weapons of Order" end
  end
  -- TODO: TOD on off-targets?
  -- touch of death as suggested-right if current target and on nameplate if not?
  -- put venthyr portal thing here
end

local function Precombat()
  if S.ChiBurst:IsReady() then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Precombat Chi Burst"; end
  end
end

local function SpendEnergy()
    if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
      CastAtBestCraneTarget(S.FistOfTheWhiteTiger, "FOTWT @ Energy Cap")
    end
    if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm @ Energy Cap" end
    end
    if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 1 then
      return CastAtBestCraneTarget(S.TigerPalm, "Tiger Palm @ Energy Cap")
    end
end

-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle
  ComputeTargetRange()
  local FOFChannelTime = 4.0 / (1 + Player:HastePct() / 100.0)
  local ChiBurstCastTime = 1.0 / (1 + Player:HastePct() / 100.0)


  if Everyone.TargetIsValid() then
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if ShouldReturn then return ShouldReturn; end

    UseCooldowns()
    UseItems()

    -- If you're about to cap energy, use an energy spender.
    -- If your next spell is a FOF channel that would cap energy then try to dump energy now too.
    if (EnergyTimeToMaxRounded() < Player:GCD()) or 
       (EnergyTimeToMaxRounded() < Player:GCD() + FOFChannelTime and S.FistsOfFury:CooldownRemains() < Player:GCD())  then
      SpendEnergy()
    end

    -- Handle WDP + WDP setup as a highest priority
    if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
      if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch" end
    end

    if S.WhirlingDragonPunch:IsAvailable() and S.RisingSunKick:IsReady() and S.WhirlingDragonPunch:CooldownRemains() < 5 and (S.FistsOfFury:CooldownRemains() > 3 or Player:Chi() >= 5) then
      CastAtBestCraneTarget(S.RisingSunKick, "RSK to enable WDP")
    end

    if S.FaelineStomp:IsReady() then
      if HR.Cast(S.FaelineStomp, nil, nil, not Target:IsInMeleeRange(8)) then return "Faeline Stomp" end
    end

    -- Get the chi-reduction ASAP in Weapons of Order buff.
    if Player:BuffUp(S.WeaponsOfOrder) and S.RisingSunKick:IsReady() and ComboStrike(S.RisingSunKick) then
      return CastAtBestCraneTarget(S.RisingSunKick, "RSK inside of WOO")
    end

    -- Fist on CD otherwise.
    if S.FistsOfFury:IsReady() then
      if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsInMeleeRange(8)) then return "Fists of Fury" end
    end


    -- "smart logic" section!!
    local true_best_spender = BestDamagePerChi(false) -- cannot be nil
    local available_best_spender = BestDamagePerChi(true) -- can be nil

    if true_best_spender == available_best_spender then
      if true_best_spender == S.RisingSunKick or true_best_spender == S.BlackoutKick then
        return CastAtBestCraneTarget(true_best_spender, "Best spender " .. true_best_spender.SpellName .. " is available.")
      else
        if HR.Cast(true_best_spender, nil, nil, not Target:IsInMeleeRange(8)) then return "Best spender " .. true_best_spender.SpellName .. " is available." end
      end
    end

    if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
      return CastAtBestCraneTarget(S.FistOfTheWhiteTiger, "Fist of the White Tiger off CD")
    end

    if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm off CD" end
    end

    if S.ChiBurst:IsReady() and Player:ChiDeficit() >= min(2, EnemiesCount8) and EnergyTimeToMaxRounded() > ChiBurstCastTime then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "Chi Burst" end
    end

    if S.ChiWave:IsReady() then
      if HR.Cast(S.ChiWave, nil, nil, not Target:IsInMeleeRange(8)) then return "Chi Wave" end
    end

    -- Use generic builder/spenders (tiger palm, blackout kick, spinning crane kick)
    -- TODO: consider ordering on logic here
    if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 then -- todo: handle any case where TP gives more chi?
      return CastAtBestCraneTarget(S.TigerPalm, "Tiger Palm")
    end

    if Player:ChiDeficit() < 2 and available_best_spender ~= nil then
      if available_best_spender == S.RisingSunKick or available_best_spender == S.BlackoutKick then
        return CastAtBestCraneTarget(available_best_spender, "Chi-cap spender: " .. available_best_spender.SpellName .. " is best available.")
      else
        if HR.Cast(available_best_spender, nil, nil, not Target:IsInMeleeRange(8)) then return  "Chi-cap spender: " .. available_best_spender.SpellName .. " is best available."end
      end
    end

    -- Freely spend chi when FOF CD (or RSK, in ST) are far away
    if (S.FistOfTheWhiteTiger:CooldownRemains() < S.FistsOfFury:CooldownRemains()+2 or 
        ((Player:Chi() > 3 or S.FistsOfFury:CooldownRemains() > 6) and
         (Player:Chi() >= 5 or S.FistsOfFury:CooldownRemains() > 2)))
        and available_best_spender ~= nil then
      if available_best_spender == S.RisingSunKick or available_best_spender == S.BlackoutKick then
        return CastAtBestCraneTarget(available_best_spender, "Safe spender: " .. available_best_spender.SpellName .. " is best available.")
      else
        if HR.Cast(available_best_spender, nil, nil, not Target:IsInMeleeRange(8)) then return  "Safe spender: " .. available_best_spender.SpellName .. " is best available."end
      end
    end

    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) and not Settings.Windwalker.NoWindwalkerPooling then return "Pool Energy"; end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
--  HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
--  HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
--  HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch
end

HR.SetAPL(269, APL, Init);