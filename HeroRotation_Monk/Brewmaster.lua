--- ============================ HEADER ============================
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


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Brewmaster;
local I = Item.Monk.Brewmaster;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- BfA
--  I.PocketsizedComputationDevice:ID(),
--  I.AshvanesRazorCoral:ID(),
}

-- Rotation Var
local Enemies5y
local Enemies8y
local EnemiesCount8
local IsInMeleeRange, IsInAoERange
local ShouldReturn; -- Used to get the return string
local Interrupts = {
  { S.SpearHandStrike, "Cast Spear Hand Strike (Interrupt)", function () return true end },
}
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
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
  Brewmaster = HR.GUISettings.APL.Monk.Brewmaster
};

-- Legendary variables
local CelestialInfusionEquipped = Player:HasLegendaryEquipped(88)
local CharredPassionsEquipped = Player:HasLegendaryEquipped(86)
local EscapeFromRealityEquipped = Player:HasLegendaryEquipped(82)
local FatalTouchEquipped = Player:HasLegendaryEquipped(85)
local InvokersDelightEquipped = Player:HasLegendaryEquipped(83)
local ShaohaosMightEquipped = Player:HasLegendaryEquipped(89)
local StormstoutsLastKegEquipped = Player:HasLegendaryEquipped(87)
local SwiftsureWrapsEquipped = Player:HasLegendaryEquipped(84)

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

local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

-- I am going keep this function in place in case it is needed in the future.
-- The code is sound for a smoothing of damage intake.
-- However this is not needed in the current APL.
local function ShouldPurify ()
  return S.PurifyingBrew:ChargesFractional() >= 1.8 and (Player:DebuffUp(S.HeavyStagger) or Player:DebuffUp(S.ModerateStagger) or Player:DebuffUp(S.LightStagger))
end

local function Defensives()
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);

  if S.CelestialBrew:IsCastable() and Player:BuffStack(S.PurifiedChiBuff) >= 2 then
    if HR.Cast(S.CelestialBrew) then return "Celestial Brew"; end
  end
  if S.PurifyingBrew:IsCastable() and ShouldPurify() then
    if HR.CastRightSuggested(S.PurifyingBrew) then return "Purifying Brew"; end
  end
  if S.DampenHarm:IsCastable() and Player:HealthPercentage() <= 35 then
    if HR.CastSuggested(S.DampenHarm) then return "Dampen Harm"; end
  end
  if S.FortifyingBrew:IsCastable() and Player:HealthPercentage() <= 25 then
    if HR.CastSuggested(S.FortifyingBrew) then return "Fortifying Brew"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  IsInMeleeRange();
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle

  --- Out of Combat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    if S.RushingJadeWind:IsCastable() then
      if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "Rushing Jade Wind"; end
    end
    if S.ChiBurst:IsCastable() then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst"; end
    end
    if S.KegSmash:IsCastable() then 
      if HR.Cast(S.KegSmash, nil, nil, not Target:IsInRange(40)) then return "Keg Smash"; end
    end
    if S.ChiWave:IsCastable() then
      if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave"; end
    end
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Everyone.Interrupt(5, S.LegSweep, Settings.Commons.GCDasOffGCD.LegSweep, Stuns); if ShouldReturn and Settings.General.InterruptWithStun then return ShouldReturn; end
    local ShouldReturn = Everyone.Interrupt(5, S.Paralysis, Settings.Commons.GCDasOffGCD.Paralysis, Stuns); if ShouldReturn and Settings. General.InterruptWithStun then return ShouldReturn; end
    ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    if HR.CDsON() then
      
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury"; end
      end
      -- berserking
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking"; end
      end
      -- lights_judgment
      if S.LightsJudgment:IsCastable() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, not Target:IsInRange(40)) then return "Lights Judgment"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Fireblood"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Ancestral Call"; end
      end
      -- bag_of_tricks
      if S.BagOfTricks:IsCastable() then
        if HR.Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, not Target:IsInRange(40)) then return "Bag of Tricks"; end
      end
      -- weapons_of_order
      if S.WeaponsOfOrder:IsCastable() then
        if HR.Cast(S.WeaponsOfOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "Weapons Of Order cd 1"; end
      end
      -- fallen_order
      if S.FallenOrder:IsCastable() then
        if HR.Cast(S.FallenOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "Fallen Order cd 1"; end
      end
      -- bonedust_brew
      if S.BonedustBrew:IsCastable() then
        if HR.Cast(S.BonedustBrew, nil, Settings.Commons.CovenantDisplayStyle) then return "Bonedust Brew cd 1"; end
      end
      -- invoke_niuzao_the_black_ox
      if S.InvokeNiuzaoTheBlackOx:IsCastable() and HL.BossFilteredFightRemains(">", 25) then
        if HR.Cast(S.InvokeNiuzaoTheBlackOx, Settings.Brewmaster.GCDasOffGCD.InvokeNiuzaoTheBlackOx) then return "Invoke Niuzao the Black Ox"; end
      end
      -- black_ox_brew,if=cooldown.purifying_brew.charges_fractional<0.5
      if S.BlackOxBrew:IsCastable() and S.PurifyingBrew:ChargesFractional() < 0.5 then
        if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "Black Ox Brew"; end
      end
      -- black_ox_brew,if=(energy+(energy.regen*cooldown.keg_smash.remains))<40&buff.blackout_combo.down&cooldown.keg_smash.up
      if S.BlackOxBrew:IsCastable() and (Player:Energy() + (Player:EnergyRegen() * S.KegSmash:CooldownRemains())) < 40 and Player:BuffDown(S.BlackoutComboBuff) and S.KegSmash:CooldownUp() then
        if HR.Cast(S.BlackOxBrew, Settings.Brewmaster.OffGCDasOffGCD.BlackOxBrew) then return "Black Ox Brew 2"; end
      end
      if (Settings.Commons.UseTrinkets) then
        if (true) then
          local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
        end
      end
    end

    -- keg_smash,if=spell_targets>=2
    if S.KegSmash:IsCastable() and EnemiesCount8 >= 2 then
      if HR.Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "Keg Smash 1"; end
    end
    -- faeline_stomp,if=spell_targets>=2
    if S.FaelineStomp:IsCastable() and EnemiesCount8 >= 2 then
      if HR.Cast(S.FaelineStomp, nil, Settings.Commons.CovenantDisplayStyle) then return "Faeline Stomp cd 1"; end
    end
    -- keg_smash,if=buff.weapons_of_order.up
    if S.KegSmash:IsCastable() and Player:BuffUp(S.WeaponsOfOrder) then
      if HR.Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "Keg Smash 2"; end
    end
    -- blackout_strike
    if S.BlackoutKick:IsCastable() then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick"; end
    end
    -- keg_smash
    if S.KegSmash:IsCastable() then
      if HR.Cast(S.KegSmash, nil, nil, not Target:IsSpellInRange(S.KegSmash)) then return "Keg Smash 3"; end
    end
    -- faeline_stomp
    if S.FaelineStomp:IsCastable() then
      if HR.Cast(S.FaelineStomp, nil, Settings.Commons.CovenantDisplayStyle) then return "Faeline Stomp cd 2"; end
    end
    -- Note: Add extra handling to prevent Expel Harm over-healing
    if S.ExpelHarm:IsReady() and S.ExpelHarm:Count() >= 3 and Player:BuffUp(S.CelestialBrew) then
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 2"; end
    end
    if S.TouchOfDeath:IsReady() and Target:Health() < UnitHealthMax("player") then
      if HR.CastSuggested(S.TouchOfDeath) then return "Touch Of Death 1"; end
    end
	-- Prio SCK with charred_passions buff/legendary
	if Player:HasLegendaryEquipped(86) and not S.BlackoutKick:IsCastable() and S.SpinningCraneKick:IsCastable() and Player:BuffUp(S.CharredPassions) then
      if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 2"; end
    end
    if Player:HasLegendaryEquipped(86) and S.BlackoutKick:IsCastable() and Player:BuffUp(S.CharredPassions) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick"; end
    end
	-- RJW
    if S.RushingJadeWind:IsCastable() and Player:BuffDown(S.RushingJadeWind) then
      if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "Rushing Jade Wind"; end
    end
    -- breath_of_fire,if=buff.blackout_combo.down&(buff.bloodlust.down|(buff.bloodlust.up&dot.breath_of_fire_dot.refreshable))
    if S.BreathOfFire:IsCastable(10, true) and (Player:BuffDown(S.BlackoutComboBuff) and (Player:BloodlustDown() or (Player:BloodlustUp() and Target:BuffRefreshable(S.BreathOfFireDotDebuff)))) then
      if HR.Cast(S.BreathOfFire, nil, nil, not Target:IsInMeleeRange(8)) then return "Breath of Fire 2"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastable() then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst 2"; end
    end
    -- chi_wave
    if S.ChiWave:IsCastable() then
      if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 2"; end
    end
    -- spinning_crane_kick,if=active_enemies>=3&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+execute_time)))>=65&(!talent.spitfire.enabled|!runeforge.charred_passions.equipped)
    if S.SpinningCraneKick:IsCastable() and (EnemiesCount8 >= 3 and S.KegSmash:CooldownRemains() > Player:GCD() and ((Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemains() + S.SpinningCraneKick:ExecuteTime())) >= 65)) and (not S.Spitfire:IsAvailable() or not CharredPassionsEquipped)) then
      if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 2"; end
    end
    -- tiger_palm,if=!talent.blackout_combo.enabled&cooldown.keg_smash.remains>gcd&(energy+(energy.regen*(cooldown.keg_smash.remains+gcd)))>=65
    if S.TigerPalm:IsCastable() and (not S.BlackoutCombo:IsAvailable() and S.KegSmash:CooldownRemains() > Player:GCD() and ((Player:Energy() + (Player:EnergyRegen() * (S.KegSmash:CooldownRemains() + Player:GCD()))) >= 65)) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 3"; end
    end
    -- rushing_jade_wind
    if S.RushingJadeWind:IsCastable() then
      if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "Rushing Jade Wind 2"; end
    end
    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) and not Settings.Brewmaster.NoBrewmasterPooling then return "Pool Energy"; end
  end
end

local function Init()
end

HR.SetAPL(268, APL, Init);