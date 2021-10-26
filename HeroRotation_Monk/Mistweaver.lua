--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
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
local pairs      = pairs


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
local S = Spell.Monk.Mistweaver
local I = Item.Monk.Mistweaver

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
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
}
local Traps = {
  { S.Paralysis, "Cast Paralysis (Stun)", function () return true end },
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Mistweaver = HR.GUISettings.APL.Monk.Mistweaver
}

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

local function Defensives()
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  -- Dampen Harm
  if S.DampenHarm:IsCastable() and Settings.Mistweaver.ShowDampenHarmCD then
    if HR.Cast(S.DampenHarm, Settings.Mistweaver.GCDasOffGCD.DampenHarm) then return "Dampen Harm"; end
  end
  -- Fortifying Brew
  if S.FortifyingBrew:IsCastable() then
    if HR.Cast(S.FortifyingBrew, Settings.Mistweaver.GCDasOffGCD.FortifyingBrew) then return "Fortifying Brew"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Unit Update
  IsInMeleeRange()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle

  --- Out of Combat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    -- flask
    -- food
    -- augmentation
    -- snapshot_stats
    -- potion
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofPhantomFire) then return "Potion of Phantom Fire"; end
    end
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofSpectralIntellect) then return "Potion of Spectral Intellect"; end
    end
    if I.PotionofDeathlyFixation:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofDeathlyFixation) then return "Potion of Deathly Fixation"; end
    end
    if I.PotionofEmpoweredExorcisms:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofEmpoweredExorcisms) then return "Potion of Empowered Exorcisms"; end
    end
    if I.PotionofHardenedShadows:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofHardenedShadows) then return "Potion of Hardened Shadows"; end
    end
    if I.PotionofSpectralStamina:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofSpectralStamina) then return "Potion of Spectral Stamina"; end
    end
    -- chi_burst
    if S.ChiBurst:IsCastable() then
      if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst"; end
    end
    -- chi_wave
    if S.ChiWave:IsCastable() then
      if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave"; end
    end
  end

  --- In Combat
  if Everyone.TargetIsValid() then
    -- auto_attack
    -- Interrupts
    -- Stun
    local ShouldReturn = Everyone.Interrupt(5, S.LegSweep, Settings.Commons.GCDasOffGCD.LegSweep, Stuns); if ShouldReturn and Settings.General.InterruptWithStun then return ShouldReturn; end
    -- Trap
    local ShouldReturn = Everyone.Interrupt(5, S.Paralysis, Settings.Commons.GCDasOffGCD.Paralysis, Stuns); if ShouldReturn and Settings. General.InterruptWithStun then return ShouldReturn; end
    -- Defensives
    if HR.CDsON() then
      -- potion
      if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofPhantomFire) then return "Potion of Phantom Fire 2"; end
      end
      if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofSpectralIntellect) then return "Potion of Spectral Intellect 2"; end
      end
      if I.PotionofDeathlyFixation:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofDeathlyFixation) then return "Potion of Deathly Fixation 2"; end
      end
      if I.PotionofEmpoweredExorcisms:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofEmpoweredExorcisms) then return "Potion of Empowered Exorcisms 2"; end
      end
      if I.PotionofHardenedShadows:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofHardenedShadows) then return "Potion of Hardened Shadows 2"; end
      end
      if I.PotionofSpectralStamina:IsReady() and Settings.Commons.UsePotions then
        if HR.CastSuggested(I.PotionofSpectralStamina) then return "Potion of Spectral Stamina 2"; end
      end
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
        if HR.Cast(S.WeaponsOfOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "Weapons Of Order"; end
      end
      -- faeline_stomp
      if S.FaelineStomp:IsCastable() then
        if HR.Cast(S.FaelineStomp, nil, Settings.Commons.CovenantDisplayStyle) then return "Faeline Stomp"; end
      end
      -- fallen_order
      if S.FallenOrder:IsCastable() then
        if HR.Cast(S.FallenOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "Fallen Order"; end
      end
      -- bonedust_brew
      if S.BonedustBrew:IsCastable() then
        if HR.Cast(S.BonedustBrew, nil, Settings.Commons.CovenantDisplayStyle) then return "Bonedust Brew"; end
      end
      -- summon_jade_serpent_statue
      if S.SummonJadeSerpentStatue:IsCastable() and S.SummonJadeSerpentStatue:TimeSinceLastCast() >= 900 then
        if HR.Cast(S.SummonJadeSerpentStatue, Settings.Mistweaver.GCDasOffGCD.SummonJadeSerpentStatue) then return "Summon Jade Serpent Statue"; end
      end
      -- invoke_yulon_the_jade_serpent
      if S.InvokeYulonTheJadeSerpent:IsCastable() and HL.BossFilteredFightRemains(">", 25) then
        if HR.Cast(S.InvokeYulonTheJadeSerpent, Settings.Mistweaver.GCDasOffGCD.InvokeYulonTheJadeSerpent) then return "Invoke Yu'lon the Jade Serpent"; end
      end
      -- invoke_chiji_the_red_crane
      if S.InvokeChiJiTheRedCrane:IsCastable() and HL.BossFilteredFightRemains(">", 25) then
        if HR.Cast(S.InvokeChiJiTheRedCrane, Settings.Mistweaver.GCDasOffGCD.InvokeChiJiTheRedCrane) then return "Invoke Chi-Ji the Red Crane"; end
      end
      -- thunder_focus_tea
      if S.ThunderFocusTea:IsCastable() and EnemiesCount8 < 3 then
        if HR.Cast(S.ThunderFocusTea, Settings.Mistweaver.OffGCDasOffGCD.ThunderFocusTea) then return "Thunder Focus Tea"; end
      end
      -- renewing_mist
      if S.RenewingMist:IsCastable() then
        if HR.Cast(S.RenewingMist, Settings.Mistweaver.GCDasOffGCD.RenewingMist) then return "Renewing Mist"; end
      end
      -- Defensives
      if (true) then
        local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
      end
      -- use_item
      if (Settings.Commons.UseTrinkets) then
        if (true) then
          local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
        end
      end
    end
    if (HR.AoEON() and (EnemiesCount8 >=3)) then
      -- spinning_crane_kick
      if S.SpinningCraneKick:IsCastable() then
        if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 1"; end
      end
      -- chi_burst
      if S.ChiBurst:IsCastable() then
        if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst AoE"; end
      end
      -- chi_wave
      if S.ChiWave:IsCastable() then
        if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave AoE"; end
      end
    end
    if EnemiesCount8 < 3 or (not HR.AoEON()) then
      -- rising_sun_kick
      if S.RisingSunKick:IsCastable() then
        if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "Rising Sun Kick"; end
      end
      -- blackout_strike,if=buff.teachings_of_the_monastery.stack=1&cooldown.rising_sun_kick.remains<12
      if S.BlackoutKick:IsCastable() and Player:BuffStack(S.TeachingsOfTheMonasteryBuff) >= 1 and S.RisingSunKick:CooldownRemains() < 12 then
        if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick"; end
      end
      -- chi_burst
      if S.ChiBurst:IsCastable() then
        if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst Single Target"; end
      end
      -- chi_wave
      if S.ChiWave:IsCastable() then
        if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave Single Target"; end
      end
    -- tiger_palm,if=buff.teachings_of_the_monastery.stack<3|buff.teachings_of_the_monastery.remains<2
    if S.TigerPalm:IsCastable() and Player:BuffStack(S.TeachingsOfTheMonasteryBuff) < 3 or Player:BuffRemains(S.TeachingsOfTheMonasteryBuff) < 2 then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 1"; end
    end
    end
    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) and not Settings.Mistweaver.NoMistweaverPooling then return "Pool Energy"; end
  end
end

local function Init()
end

HR.SetAPL(270, APL, Init)

-- Last Update: 2020-12-18

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/chi_burst
-- actions.precombat+=/chi_wave

-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/use_item,name=skulkers_wing
-- actions+=/blood_fury,if=target.time_to_die<18
-- actions+=/berserking,if=target.time_to_die<18
-- actions+=/arcane_torrent,if=chi.max-chi>=1&target.time_to_die<18
-- actions+=/lights_judgment,if=target.time_to_die<18
-- actions+=/fireblood,if=target.time_to_die<18
-- actions+=/ancestral_call,if=target.time_to_die<18
-- actions+=/bag_of_tricks,if=target.time_to_die<18
-- actions+=/potion
-- actions+=/run_action_list,name=aoe,if=active_enemies>=3
-- actions+=/call_action_list,name=st,if=active_enemies<3
-- actions+=/weapons_of_order
-- actions+=/faeline_stomp
-- actions+=/fallen_order
-- actions+=/bonedust_brew

-- actions.aoe=spinning_crane_kick
-- actions.aoe+=/chi_wave
-- actions.aoe+=/chi_burst

-- actions.st=thunder_focus_tea
-- actions.st+=/rising_sun_kick
-- actions.st+=/blackout_kick,if=buff.teachings_of_the_monastery.stack=1&cooldown.rising_sun_kick.remains<12
-- actions.st+=/chi_wave
-- actions.st+=/chi_burst
-- actions.st+=/tiger_palm,if=buff.teachings_of_the_monastery.stack<3|buff.teachings_of_the_monastery.remains<2

