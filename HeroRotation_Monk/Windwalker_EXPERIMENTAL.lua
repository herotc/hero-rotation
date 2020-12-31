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

local function MarkOfTheCraneStacks()
  return GetSpellCount(101546)
end

-- Reward Estimation for Chi Spenders
-- See https://docs.google.com/spreadsheets/d/1Agwilw8sG5PeBBgACneZl3J4jumS1EBWQAJK8BIUzgE/edit#gid=0
-- TODO: inner fury, calculated strikes, coordinated offensive computation
-- TODO: autoattack loss
-- TODO: BOK value from CDR

-- assume MH/OH setup, better because 2x enchants
-- TODO: handle weapon swapping; need to update these values on swaps.
--local mh_dps = GetItemStats(GetInventoryItemLink("player", 16))["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
--local oh_dps = GetItemStats(GetInventoryItemLink("player", 17))["ITEM_MOD_DAMAGE_PER_SECOND_SHORT"]
--local function AbilityPower()
--  return 1.02 * (4*mh_dps + 2*oh_dps + Player:AttackPower())
--end
local function AbilityPower()
  return Player:AttackPower()
end

local armor_reduction_coeff = 0.70
local mystic_touch_coeff = 1.05
local inner_fury_coeff = 1.0
if S.InnerFury:ConduitEnabled() then inner_fury_coeff = 1.04 + 0.004*(S.InnerFury:ConduitRank() - 1) end
local calculated_strikes_effect = 0.0
if S.CalculatedStrikes:ConduitEnabled() then calculated_strikes_effect = 0.1 + 0.01*(S.CalculatedStrikes:ConduitRank() - 1) end

-- TODO: handle autoattack loss
local function GetSpinningCraneKickValue()
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local ap_coeff = 0.40
  local aura_coeff = 0.87 * 2.4
  local crane_coeff = 1 + (0.1 + calculated_strikes_effect) * MarkOfTheCraneStacks()
  local chiji_coeff = 1.0
  if Player:BuffUp(S.DanceOfChijiBuff) then chiji_coeff = 3.0 end
  local tooltip = ability_power * ap_coeff * aura_coeff * vers_coeff * crane_coeff * chiji_coeff
  local damage = tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  return damage * num_targets
end

-- TODO: handle autoattack loss
local function GetFistsOfFuryValue()
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local ap_coeff = 6.0375
  local aura_coeff = 0.87
  local tooltip = ability_power * ap_coeff * aura_coeff * vers_coeff
  local damage = tooltip * inner_fury_coeff * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_off_targets = max(0, min(5, EnemiesCount8-1))
  return damage * (1 + 0.5*num_off_targets)
end

-- TODO: handle CD reduction value
local function GetBlackoutKickValue()
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local ap_coeff = 0.847
  local aura_coeff = 0.87 * 1.26 * 1.1
  local tooltip = ability_power * ap_coeff * aura_coeff * vers_coeff
  local damage = tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  return damage
end

local function GetRisingSunKickValue()
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local ap_coeff = 1.438
  local aura_coeff = 0.87 * 1.26 * 1.7
  local tooltip = ability_power * ap_coeff * aura_coeff * vers_coeff
  local damage = tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  return damage
end


local function GetRushingJadeWindValue()
  local ability_power = AbilityPower()
  local mastery_coeff = 1 + Player:MasteryPct() / 100.0
  local vers_coeff = 1 + Player:VersatilityDmgPct() / 100.0
  local ap_coeff = 0.90
  local aura_coeff = 0.87 * 1.22
  local tooltip = ability_power * ap_coeff * aura_coeff * vers_coeff
  local damage = tooltip * mastery_coeff * armor_reduction_coeff * mystic_touch_coeff
  local num_targets = min(6, EnemiesCount8)
  return num_targets * damage
end



-- Returns the ability (completely not subject to any constraints)
-- that is the "best damage per chi" in the given scenario.
-- There is also a "best available" version of this that takes the readiness + combo-strike-itude of the abilities into account in case we
-- have to forcibly spend chi at cap
local function BestDamagePerChi()
  local bok_val = GetBlackoutKickValue()
  local sck_val = GetSpinningCraneKickValue()
  local rsk_val = GetRisingSunKickValue()
  local rjw_val = GetRushingJadeWindValue()

  -- TODO: don't hardcode, some CDs change these values!
  local bok_chi = 1.0
  local sck_chi = 2.0
  local rsk_chi = 2.0
  local rjw_chi = 1.0

  local bok_eff = bok_val / bok_chi
  local sck_eff = sck_val / sck_chi
  local rsk_eff = rsk_val / rsk_chi
  local rjw_eff = rjw_val / rjw_chi
 
  
  local best_move = nil
  local best_eff = 0

  if bok_eff > best_eff then
    best_move = S.BlackoutKick
    best_eff = bok_eff
  end
  if sck_eff > best_eff then
    best_move = S.SpinningCraneKick
    best_eff = sck_eff
  end
  if rjw_eff > best_eff then
    best_move = S.RushingJadeWind
    best_eff = rjw_eff
  end
  if rsk_eff > best_eff then
    best_move = S.RisingSunKick
    best_eff = rsk_eff
  end

  -- Note: it's not always the case that FOF is better than SCK on aoe - consider 6t with 6 MOTC stacks up: SCK damage per chi is 8543, FOF damage per chi is 8412
  -- this gets more pronounced if you have calculated strikes conduit.
  return best_move
end

-- Very similar to best damage per chi, except this conditions on a) CD is ready and b) this is a combo strike
-- if the result of this fn is the same as the last one, then it's good to spend chi (it's almost always FOF for the last one)
-- if the result of this fn is NOT the same as the last one, but we're ~chi capped, go ahead and fire off this spender.
local function BestAvailableDamagePerChi()
  local bok_val = GetBlackoutKickValue()
  local sck_val = GetSpinningCraneKickValue()
  local rsk_val = GetRisingSunKickValue()
  local rjw_val = GetRushingJadeWindValue()

  -- TODO: don't hardcode, some CDs change these values!
  local bok_chi = 1.0
  local sck_chi = 2.0
  local rsk_chi = 2.0
  local rjw_chi = 1.0

  local bok_eff = bok_val / bok_chi
  local sck_eff = sck_val / sck_chi
  local rsk_eff = rsk_val / rsk_chi
  local rjw_eff = rjw_val / rjw_chi
  
  local best_move = nil
  local best_eff = 0

  if bok_eff > best_eff and S.BlackoutKick:IsReady() and ComboStrike(S.BlackoutKick) then
    best_move = S.BlackoutKick
    best_eff = bok_eff
  end
  if sck_eff > best_eff and S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) then
    best_move = S.SpinningCraneKick
    best_eff = sck_eff
  end
  if rjw_eff > best_eff and S.RushingJadeWind:IsReady() and ComboStrike(S.RushingJadeWind) then
    best_move = S.RushingJadeWind
    best_eff = rjw_eff
  end
  if rsk_eff > best_eff and S.RisingSunKick:IsReady() and ComboStrike(S.RisingSunKick) then
    best_move = S.RisingSunKick
    best_eff = rsk_eff
  end
  return best_move
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
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "Storm Earth and Fire non-kyrian"; end
  end
  if S.StormEarthAndFire:IsReady() and S.WeaponsOfOrder:IsAvailable() and (Player:BuffUp(S.WeaponsOfOrder) or ((HL.BossFilteredFightRemains("<", S.WeaponsOfOrder:CooldownRemains()) or (S.WeaponsOfOrder:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "Storm Earth and Fire kyrian"; end
  end

  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 2) or Player:ChiDeficit() >= 4) then
    if HR.CastRightSuggested(S.EnergizingElixir) then return "Elixir CD"; end
  end
  if S.TouchOfDeath:IsReady() and Target:Health() < Player:Health() then
    if HR.CastRightSuggested(S.TouchOfDeath) then return "Touch of Death Main Target"; end
  end
  -- TODO: TOD on off-targets
  -- touch of death as suggested-right if current target and on nameplate if not?
  -- should consider how to handle sef and xuen
  -- put SEF as suggested-left icon?
  -- put long-ish on-use trinkets here
  -- put weapons of order here
  -- put venthyr portal thing here
end

local function Precombat()
  if S.ChiBurst:IsReady() then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Precombat Chi Burst"; end
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
    if EnergyTimeToMaxRounded() < Player:GCD() then
      if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
        if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "FOTWT @ Energy Cap" end
      end
      if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then -- todo: handle pvp talent for 2 chi here
        if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm @ Energy Cap" end
      end
      if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 1 then -- todo: handle any case where TP gives more chi?
        if HR.Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(8)) then return "Tiger Palm @ Energy Cap" end
      end
    end

    -- Handle WDP + WDP setup as a highest priority
    if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
      if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch" end
    end

    if S.WhirlingDragonPunch:IsAvailable() and S.RisingSunKick:IsReady() and S.WhirlingDragonPunch:CooldownRemains() < 5 and (S.FistsOfFury:CooldownRemains() > 3 or Player:Chi() >= 5) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Rising Sun Kick to enable WDP" end
    end

    if S.FaelineStomp:IsReady() then
      if HR.Cast(S.FaelineStomp, nil, nil, not Target:IsInMeleeRange(8)) then return "Faeline Stomp" end
    end

    -- Handle free spells
    -- TODO: if FOF or RSK are up in ST, put them on CD before using a free BOK?
    local best_free_spell = nil
    local best_free_spell_value = 0
    if Player:BuffUp(S.BlackoutKickBuff) and ComboStrike(S.BlackoutKick) then 
      local bok_dam = GetBlackoutKickValue()
      if bok_dam > best_free_spell_value then
        best_free_spell = S.BlackoutKick
        best_free_spell_value = bok_dam
      end
    end
    if Player:BuffUp(S.DanceOfChijiBuff) and ComboStrike(S.SpinningCraneKick) then
      local sck_dam = GetSpinningCraneKickValue()
      if sck_dam > best_free_spell_value then
        best_free_spell = S.SpinningCraneKick
        best_free_spell_value = sck_dam
      end
    end
    if best_free_spell ~= nil then
      if HR.Cast(best_free_spell, nil, nil, not Target:IsInMeleeRange(8)) then return "Free Chi Spender" end
    end

    -- You don't want to spend chi below 3 (or 2) if you're about to fists or RSK
    -- You do want to spend chi if you're at the chi cap
    -- definitely dump chi if you have energizing elixir or FOTWT coming off CD soon

    -- If your next spell is a FOF channel that would cap energy then try to dump energy now too.
    -- TODO: idea here is that we have to rule out casting anything higher prio before we dump like this
    if EnergyTimeToMaxRounded() < Player:GCD() + FOFChannelTime and S.FistsOfFury:CooldownRemains() < Player:GCD() then 
      if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
        if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "FOTWT @ PreFists EnergyCap" end
      end
      if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then -- todo: handle pvp talent for 2 chi here
        if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm @ PreFists Energy Cap" end
      end
      if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 1 then -- todo: handle any case where TP gives more chi?
        if HR.Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(8)) then return "Tiger Palm @ PreFists Energy Cap" end
      end
    end

    if S.FistOfTheWhiteTiger:IsReady() and Player:ChiDeficit() >= 3 then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "FOTWT @ PreFists EnergyCap" end
    end
    if S.ExpelHarm:IsReady() and Player:ChiDeficit() >= 1 then -- todo: handle pvp talent for 2 chi here
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm @ PreFists Energy Cap" end
    end
    if S.ChiBurst:IsReady() and Player:ChiDeficit() >= min(2, EnemiesCount8) and EnergyTimeToMaxRounded() > ChiBurstCastTime then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "Chi Burst" end
    end

    if S.FistsOfFury:IsReady() then
      if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsInMeleeRange(8)) then return "Fists of Fury" end
    end

    local true_best_spender = BestDamagePerChi() -- cannot be nil
    local available_best_spender = BestAvailableDamagePerChi() -- can be nil
    if available_best_spender ~= nil and true_best_spender == available_best_spender then
      if HR.Cast(true_best_spender, nil, nil, not Target:IsInMeleeRange(8)) then return "Most efficient spender is available" end
    end

    if ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 then -- todo: handle any case where TP gives more chi?
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(8)) then return "Tiger Palm" end
    end

    if S.ChiBurst:IsReady() and Player:ChiDeficit() >= min(2, EnemiesCount8) then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInMeleeRange(8)) then return "Chi Burst" end
    end

    if Player:ChiDeficit() < 2 and available_best_spender ~= nil then
      if HR.Cast(available_best_spender, nil, nil, not Target:IsInMeleeRange(8)) then return "Chi cap spender" end
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