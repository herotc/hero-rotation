-- ----- ============================ HEADER ============================
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


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker
local I = Item.Monk.Windwalker

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
local VarXuenOnUse = false
local VarXuenHold = false
local VarSerenityBurst = false
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
local VarHoldTod = false
local VarFoPPreChan = 0

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
}

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

local function EnergyTimeToMaxRounded ()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end

local function EnergyPredictedRounded ()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

local function EvaluateTargetIfFilterMarkoftheCrane100(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkOfTheCraneDebuff)
end

local function EvaluateTargetIfFistOfTheWhiteTiger102(TargetUnit)
  return (Player:Chi() < 3)
end

local function EvaluateTargetIfFistOfTheWhiteTiger104(TargetUnit)
  return (Player:ChiDeficit() >= 3 and ((EnergyTimeToMaxRounded() < 1 or EnergyTimeToMaxRounded() < 4) and (S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2)))
end

local function EvaluateTargetIfTigerPalm106(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and (S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2))
end

local function EvaluateTargetIfFistOfTheWhiteTiger200(TargetUnit)
  return (Player:ChiDeficit() >= 3)
end

local function EvaluateTargetIfTigerPalm202(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2)
end

local function EvaluateTargetIfTigerPalm204(TargetUnit)
  return (Player:ChiDeficit() == 2)
end

local function EvaluateTargetIfRisingSunKick300(TargetUnit)
  return ((S.WhirlingDragonPunch:IsAvailable() and (S.RisingSunKick:CooldownRemains() > (S.WhirlingDragonPunch:CooldownRemains() + 4))) and ((S.FistsOfFury:CooldownRemains() > 3) or Player:Chi() >= 5))
end

local function EvaluateTargetIfTigerPalm302(TargetUnit)
  return (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or ComboStrike(S.TigerPalm)))
end

local function EvaluateTargetIfFilterMarkoftheCrane304(TargetUnit)
  return ((KeefersSkyreachEquipped and TargetUnit:DebuffRemains(S.RecentlyRushingTigerPalm)) or TargetUnit:DebuffRemains(S.MarkOfTheCraneDebuff))
end

local function EvaluateTargetIfBlackoutKick306(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() == 2 and S.FistsOfFury:CooldownRemains() < 3) or (Player:ChiDeficit() <= 1 and Player:PrevGCD(1, S.SpinningCraneKick) and EnergyTimeToMaxRounded() < 3)))
end

local function EvaluateTargetIfRisingSunKick600(TargetUnit)
  return (ComboStrike(S.RisingSunKick))
end

local function EvaluateTargetIfBlackoutKick602(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.WeaponsOfOrder) and S.RisingSunKick:CooldownRemains() > 2)
end

local function EvaluateTargetIfBlackoutKick604(TargetUnit)
  return (ComboStrike(S.BlackoutKick) or not S.HitCombo:IsAvailable())
end

local function EvaluateTargetIfBlackoutKick700(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and EnemiesCount8 >=2)
end

local function EvaluateTargetIfBlackoutKick702(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (Player:Chi() >= 3 or Player:BuffUp(S.WeaponsOfOrder)))
end

local function EvaluateTargetIfRisingSunKick800(TargetUnit)
  return (S.Serenity:IsAvailable() or S.Serenity:CooldownRemains() > 1 or not S.Serenity:IsAvailable())
end

local function EvaluateTargetIfTigerPalm802(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.StormEarthAndFireBuff))
end

local function EvaluateTargetIfBlackoutKick804(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and ((S.Serenity:IsAvailable() and S.Serenity:CooldownRemains() < 3) or (S.RisingSunKick:CooldownRemains() > 1 and S.FistsOfFury:CooldownRemains() > 1) or (S.RisingSunKick:CooldownRemains() < 3 and S.FistsOfFury:CooldownRemains() > 3 and Player:Chi() > 2) or (S.RisingSunKick:CooldownRemains() > 3 and S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() > 3) or Player:Chi() > 5 or Player:BuffUp(S.BlackoutKickBuff)))
end

local function EvaluateTargetIfBlackoutKick806(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm) and Player:EnergyTimeToX(50) < 1))
end

local function EvaluateTargetIfBlackoutKick808(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and EnergyTimeToMaxRounded() < 2 and (Player:ChiDeficit() <= 1 or Player:PrevGCD(1, S.TigerPalm)))
end

local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
--  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
--    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
--  end
  -- variable,name=xuen_on_use_trinket,op=set,value=0
  if (true) then
    VarXuenOnUse = false
  end
  -- chi_burst,if=!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled
  if S.ChiBurst:IsReady() and (not S.Serenity:IsAvailable() or not S.FistOfTheWhiteTiger:IsAvailable()) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst 4"; end
  end
  -- chi_wave,if=!talent.energizing_elixer.enabled
  if S.ChiWave:IsReady() and not S.EnergizingElixir:IsAvailable() then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 6"; end
  end
end

local function Opener()
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistOfTheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger200) then return "Fist of the White Tiger 200"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger200(Target) then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 202"; end
    end
  end
  -- expel_harm,if=talent.chi_burst.enabled&chi.max-chi>=3
  if S.ExpelHarm:IsReady() and Player:Level() >= 43 and S.ChiBurst:IsAvailable() and Player:ChiDeficit() >= 3 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 204"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm202) then return "Tiger Palm 206"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm202(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 208"; end
    end
  end
  -- chi_wave,if=chi.max-chi=2
  if S.ChiWave:IsReady() and Player:ChiDeficit() >= 2 then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 210"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() and Player:Level() >= 43 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 212"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm204) then return "Tiger Palm 214"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm204(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 216"; end
    end
  end
end

local function Aoe()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch 300"; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>2|chi.max-chi>=4
  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 2) or Player:ChiDeficit() >= 4) then
    if HR.Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "Energizing Elixir 302"; end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|debuff.bonedust_brew.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceOfChijiBuff) or Target:DebuffUp(S.BonedustBrew)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 304"; end
  end
  -- fists_of_fury,if=energy.time_to_max>execute_time|chi.max-chi<=1
  if S.FistsOfFury:IsReady() and ((EnergyTimeToMaxRounded() > S.FistsOfFury:ExecuteTime()) or Player:ChiDeficit() <= 1) then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 306"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+4)&(cooldown.fists_of_fury.remains>3|chi>=5)
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick300) then return "Rising Sun Kick 308"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick300(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "Rising Sun Kick 310"; end
    end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "Rushing Jade Wind 312"; end
  end
  -- spinning_crane_kick,if=combo_strike&((cooldown.bonedust_brew.remains>2&(chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2))|energy.time_to_max<=3)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and ((S.BonedustBrew:CooldownRemains() > 2 and (Player:Chi() > 3 or S.FistsOfFury:CooldownRemains() > 6) and (Player:Chi() >= 5 or S.FistsOfFury:CooldownRemains() > 2) or EnergyTimeToMaxRounded() <= 3)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 314"; end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and Player:Level() >= 43 and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 316"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistOfTheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger200) then return "Fist of the White Tiger 318"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger200(Target) then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 320"; end
    end
  end
  -- chi_burst,if=chi.max-chi>=2
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 2) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst 322"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.fists_of_fury.remains>execute_time
  if S.CracklingJadeLightning:IsReady() and ((Player:BuffStack(S.TheEmperorsCapacitor) > 19) and (EnergyTimeToMaxRounded() > (S.CracklingJadeLightning:ExecuteTime() - 1)) and (S.FistsOfFury:CooldownRemains() > S.CracklingJadeLightning:ExecuteTime())) then
    if HR.Cast(S.CracklingJadeLightning, nil, nil, not Target:IsInRange(40)) then return "Crackling Jade Lightning 324"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=chi.max-chi>=2&(!talent.hit_combo|combo_strike)
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane304, EvaluateTargetIfTigerPalm302) then return "Tiger Palm 326"; end
    if EvaluateTargetIfFilterMarkoftheCrane304(Target) and EvaluateTargetIfTigerPalm302(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 328"; end
    end
  end
  -- chi_wave,if=combo_strike
  if S.ChiWave:IsReady() and (ComboStrike(S.ChiWave)) then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 330"; end
  end
  -- flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick Slam 332"; end
  end
  if S.FlyingSerpentKick:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick 334"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|talent.hit_combo&prev_gcd.1.tiger_palm&chi=2&cooldown.fists_of_fury.remains<3|chi.max-chi<=1&prev_gcd.1.spinning_crane_kick&energy.time_to_max<3)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick306) then return "Blackout Kick 336"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick306(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 338"; end
    end
  end
end

local function CDSEF()
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and (not VarXuenHold or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "Invoke Xuen the White Tiger 400"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "Arcane Torrent 402"; end
  end
  -- touch_of_death,if=buff.storm_earth_and_fire.down&pet.xuen_the_white_tiger.active|fight_remains<10|fight_remains>180
  if S.TouchOfDeath:IsReady() and Target:HealthPercentage() <= 15 and ((Player:BuffDown(S.StormEarthAndFireBuff) and S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24) or HL.BossFilteredFightRemains("<", 10) or HL.BossFilteredFightRemains(">", 180)) then
    if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsSpellInRange(S.TouchOfDeath)) then return "Touch of Death 404"; end
  end
  -- weapons_of_order,if=(raid_event.adds.in>45|raid_event.adds.up)&cooldown.rising_sun_kick.remains<execute_time
  if S.WeaponsOfOrder:IsReady() and S.RisingSunKick:CooldownRemains() < Player:GCD() then
    if HR.Cast(S.WeaponsOfOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "Weapons Of Order 406"; end
  end
  -- faeline_stomp,if=combo_strike&(raid_event.adds.in>10|raid_event.adds.up)
  if S.FaelineStomp:IsReady() and ComboStrike(S.FaelineStomp) then
    if HR.Cast(S.FaelineStomp, nil, Settings.Commons.DisplayStyle.Covenant) then return "Faeline Stomp 408"; end
  end
  -- fallen_order,if=raid_event.adds.in>30|raid_event.adds.up
  if S.FallenOrder:IsReady() then
    if HR.Cast(S.FallenOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "Faeline Stomp 410"; end
  end
  -- bonedust_brew,if=raid_event.adds.in>50|raid_event.adds.up,line_cd=60
  if S.BonedustBrew:IsReady() then
    if HR.Cast(S.BonedustBrew, nil, Settings.Commons.DisplayStyle.Covenant) then return "Bonedust Brew 412"; end
  end
  -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|fight_remains<20|(raid_event.adds.remains>15|!covenant.kyrian&((raid_event.adds.in>cooldown.storm_earth_and_fire.full_recharge_time|!raid_event.adds.exists)&(cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time|variable.hold_xuen))&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
  if S.StormEarthAndFire:IsReady() and (S.StormEarthAndFire:Charges() == 2 or HL.BossFilteredFightRemains("<", 20) or ((not S.WeaponsOfOrder:IsAvailable()) and ((S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime()) or VarXuenHold) and (S.FistsOfFury:CooldownRemains() <= 9) and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "Storm Earth and Fire 414"; end
  end
  -- storm_earth_and_fire,if=covenant.kyrian&(buff.weapons_of_order.up|(fight_remains<cooldown.weapons_of_order.remains|cooldown.weapons_of_order.remains>cooldown.storm_earth_and_fire.full_recharge_time)&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
  if S.StormEarthAndFire:IsReady() and S.WeaponsOfOrder:IsAvailable() and (Player:BuffUp(S.WeaponsOfOrder) or ((HL.BossFilteredFightRemains("<", S.WeaponsOfOrder:CooldownRemains()) or (S.WeaponsOfOrder:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime())) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "Storm Earth and Fire 416"; end
  end
  if (Settings.Commons.Enabled.Trinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- touch_of_karma,if=fight_remains>159|pet.xuen_the_white_tiger.active|variable.hold_xuen
  if S.TouchOfKarma:IsReady() and not Settings.Windwalker.IgnoreToK then
    if HR.Cast(S.TouchOfKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "Touch of Karma 418"; end
  end
  -- blood_fury,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.BloodFury:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarXuenHold or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury 420"; end
  end
  -- berserking,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.Berserking:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarXuenHold or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking 422"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "Lights Judgment 424"; end
  end
  -- fireblood,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.Fireblood:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarXuenHold or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Fireblood 426"; end
  end
  -- ancestral_call,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.AncestralCall:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarXuenHold or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Ancestral Call 428"; end
  end
  -- bag_of_tricks,if=buff.storm_earth_and_fire.down
  if S.BagOfTricks:IsCastable() and Player:BuffDown(S.StormEarthAndFire) then
    if HR.Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "Bag of Tricks 430"; end
  end
end

local function CDSerenity()
  -- variable,name=serenity_burst,op=set,value=cooldown.serenity.remains<1|pet.xuen_the_white_tiger.active&cooldown.serenity.remains>30|fight_remains<20
  if (true) then
    VarSerenityBurst = (Player:BuffRemains(S.SerenityBuff) < 1 or (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 and S.Serenity:CooldownRemains() < 30) or (HL.BossFilteredFightRemains("<", 20)))
  end
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and ( not VarXuenHold or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "Invoke Xuen the White Tiger 500"; end
  end
  if (Settings.Commons.Enabled.Trinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- blood_fury,if=variable.serenity_burst
  if S.BloodFury:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury 502"; end
  end
  -- berserking,if=variable.serenity_burst
  if S.Berserking:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking 504"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "Arcane Torrent 506"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "Lights Judgment 508"; end
  end
  -- fireblood,if=variable.serenity_burst
  if S.Fireblood:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "Fireblood 510"; end
  end
  -- ancestral_call,if=variable.serenity_burst
  if S.AncestralCall:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "Ancestral Call 512"; end
  end
  -- touch_of_death,if=fight_remains>180|pet.xuen_the_white_tiger.active|fight_remains<10
  if S.TouchOfDeath:IsReady() and Target:HealthPercentage() <= 15 and ((HL.BossFilteredFightRemains(">", 180)) or S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or (HL.BossFilteredFightRemains("<", 10))) then
    if HR.Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsSpellInRange(S.TouchOfDeath)) then return "Touch of Death 514"; end
  end
  -- touch_of_karma,if=fight_remains>90|pet.xuen_the_white_tiger.active|fight_remains<10
  if S.TouchOfKarma:IsReady() and not Settings.Windwalker.IgnoreToK then
    if HR.Cast(S.TouchOfKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "Touch of Karma 516"; end
  end
  -- weapons_of_order,if=cooldown.rising_sun_kick.remains<execute_time
  if S.WeaponsOfOrder:IsReady() and S.RisingSunKick:CooldownRemains() < Player:GCD() then
    if HR.Cast(S.WeaponsOfOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "Weapons Of Order 518"; end
  end
  -- faeline_stomp
  if S.FaelineStomp:IsReady() and ComboStrike(S.FaelineStomp) then
    if HR.Cast(S.FaelineStomp, nil, Settings.Commons.DisplayStyle.Covenant) then return "Faeline Stomp 520"; end
  end
  -- fallen_order
  if S.FallenOrder:IsReady() then
    if HR.Cast(S.FallenOrder, nil, Settings.Commons.DisplayStyle.Covenant) then return "Faeline Stomp 522"; end
  end
  -- bonedust_brew
  if S.BonedustBrew:IsReady() then
    if HR.Cast(S.BonedustBrew, nil, Settings.Commons.DisplayStyle.Covenant) then return "Bonedust Brew 524"; end
  end
  -- serenity,if=cooldown.rising_sun_kick.remains<2|fight_remains<15
  if S.Serenity:IsReady() and (S.RisingSunKick:CooldownRemains() < 2 or HL.BossFilteredFightRemains("<", 15)) then
    if HR.Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "Serenity 526"; end
  end
  -- bag_of_tricks
  if S.BagOfTricks:IsCastable() then
    if HR.Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "Bag of Tricks 528"; end
  end
end

local function Serenity()
  -- fists_of_fury,if=buff.serenity.remains<1
  if S.FistsOfFury:IsReady() and Player:BuffRemains(S.SerenityBuff) < 1 then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 600"; end
  end
  if (Settings.Commons.Enabled.Trinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>=3|active_enemies>1&!cooldown.rising_sun_kick.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and ((HR.AoEON() and EnemiesCount8 >= 3) or (EnemiesCount8 > 1 and not S.RisingSunKick:CooldownUp()))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 602"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick600) then return "Rising Sun Kick 604"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick600(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "Rising Sun Kick 606"; end
    end
  end
  -- fists_of_fury,if=active_enemies>=3
  if S.FistsOfFury:IsReady() and HR.AoEON() and EnemiesCount8 >= 3 then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 608"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 610"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.weapons_of_order_ww.up&cooldown.rising_sun_kick.remains>2
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick602) then return "Blackout Kick 612"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick602(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 614"; end
    end
  end
  -- fists_of_fury,interrupt_if=!cooldown.rising_sun_kick.up
  if S.FistsOfFury:IsReady() then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 616"; end
  end
  -- spinning_crane_kick,if=combo_strike&debuff.bonedust_brew.up
  if S.SpinningCraneKick:IsReady() and Target:DebuffUp(S.BonedustBrew) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 618"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistOfTheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger102) then return "Fist of the White Tiger 620"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger102(Target) then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 622"; end
    end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick604) then return "Blackout Kick 624"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick604(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 626"; end
    end
  end
  -- spinning_crane_kick
  if S.SpinningCraneKick:IsReady() then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 628"; end
  end
end

local function WeaponsOfOrder()
  -- call_action_list,name=cd_sef,if=!talent.serenity
  if (HR.CDsON() and not S.Serenity:IsAvailable()) then
    local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=cd_serenity,if=talent.serenity
  if (HR.CDsON() and S.Serenity:IsAvailable()) then
    local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3
  if S.EnergizingElixir:IsReady() and (Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 3) then
    if HR.Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "Energizing Elixir 700"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100) then return "Rising Sun Kick 702"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "Rising Sun Kick 704"; end
    end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 706"; end
  end
  if HR.AoEON() then
    -- fists_of_fury,if=active_enemies>=2&buff.weapons_of_order_ww.remains<1
    if S.FistsOfFury:IsReady() and EnemiesCount8 >= 2 and Player:BuffRemains(S.WeaponsOfOrder) < 1 then
      if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 708"; end
    end
    -- whirling_dragon_punch,if=active_enemies>=2
    if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) and EnemiesCount8 >= 2 then
      if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch 710"; end
    end
    -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&active_enemies<=2
    if S.BlackoutKick:IsReady() then
      if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick700) then return "Blackout Kick 712"; end
      if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick700(Target) then
        if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 714"; end
      end
    end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch 716"; end
  end
  -- fists_of_fury,interrupt=1,if=buff.storm_earth_and_fire.up&raid_event.adds.in>cooldown.fists_of_fury.duration*0.6
  if S.FistsOfFury:IsReady() and Player:BuffUp(S.StormEarthAndFireBuff) then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 718"; end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffStack(S.ChiEnergyBuff) > (30 - (5 * EnemiesCount8))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 720"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistOfTheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger102) then return "Fist of the White Tiger 722"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger102(Target) then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 724"; end
    end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and Player:Level() >= 43 and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 726"; end
  end
  -- chi_burst,if=chi.max-chi>=(1+active_enemies>1)
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst 728"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=(!talent.hit_combo|combo_strike)&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane304, EvaluateTargetIfTigerPalm302) then return "Tiger Palm 730"; end
    if EvaluateTargetIfFilterMarkoftheCrane304(Target) and EvaluateTargetIfTigerPalm302(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 732"; end
    end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 734"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=chi>=3|buff.weapons_of_order_ww.up
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick702) then return "Blackout Kick 736"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick702(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 738"; end
    end
  end
  -- flying_serpent_kick,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick Slam 740"; end
  end
  if S.FlyingSerpentKick:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick 742"; end
  end
end

local function St()
  -- whirling_dragon_punch,if=raid_event.adds.in>cooldown.whirling_dragon_punch.duration*0.8|raid_event.adds.up
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "Whirling Dragon Punch 800"; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3|chi.max-chi>=4&(energy.time_to_max>2|!prev_gcd.1.tiger_palm)
  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 3) or (Player:ChiDeficit() >= 4 and (EnergyTimeToMaxRounded() > 2 or not Player:PrevGCD(1, S.TigerPalm)))) then
    if HR.Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "Energizing Elixir 802"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&(raid_event.adds.in>buff.dance_of_chiji.remains-2|raid_event.adds.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 804"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>1|!talent.serenity
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick800) then return "Rising Sun Kick 806"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick800(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "Rising Sun Kick 808"; end
    end
  end
  -- fists_of_fury,if=(raid_event.adds.in>cooldown.fists_of_fury.duration*0.8|raid_event.adds.up)&(energy.time_to_max>execute_time-1|chi.max-chi<=1|buff.storm_earth_and_fire.remains<execute_time+1)|fight_remains<execute_time+1
  if S.FistsOfFury:IsReady() and (((EnergyTimeToMaxRounded() > (S.FistsOfFury:ExecuteTime() - 1)) or Player:ChiDeficit() <= 1 or (Player:BuffRemains(S.StormEarthAndFireBuff) < (S.FistsOfFury:ExecuteTime() + 1))) or HL.BossFilteredFightRemains("<", (S.FistsOfFury:ExecuteTime() + 1))) then
    if HR.Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "Fists of Fury 810"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.rising_sun_kick.remains>execute_time|buff.the_emperors_capacitor.stack>14&(cooldown.serenity.remains<5&talent.serenity|cooldown.weapons_of_order.remains<5&covenant.kyrian|fight_remains<5)
  if S.CracklingJadeLightning:IsReady() and (((Player:BuffStack(S.TheEmperorsCapacitor) > 19) and (EnergyTimeToMaxRounded() > S.CracklingJadeLightning:ExecuteTime() - 1) and (S.RisingSunKick:CooldownRemains() > S.CracklingJadeLightning:ExecuteTime())) or ((Player:BuffStack(S.TheEmperorsCapacitor) > 14) and ((S.Serenity:IsAvailable() and (S.Serenity:CooldownRemains() < 5)) or (S.WeaponsOfOrder:IsAvailable() and (S.WeaponsOfOrder:CooldownRemains() < 5)) or (HL.BossFilteredFightRemains("<", 20))))) then
    if HR.Cast(S.CracklingJadeLightning, nil, nil, not Target:IsInRange(40)) then return "Crackling Jade Lightning 812"; end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and HR.AoEON() and EnemiesCount8 > 1) then
    if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "Rushing Jade Wind 814"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistOfTheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger102) then return "Fist of the White Tiger 816"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger102(Target) then
      if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 818"; end
    end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and Player:Level() >= 43 and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 820"; end
  end
  -- chi_burst,if=chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2&active_enemies>=2
  if S.ChiBurst:IsReady() and ((Player:ChiDeficit() >= 1 and EnemiesCount8 == 1) or (Player:ChiDeficit() >= 2 and EnemiesCount8 >= 2)) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "Chi Burst 822"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "Chi Wave 824"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.down
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane304, EvaluateTargetIfTigerPalm802) then return "Tiger Palm 826"; end
    if EvaluateTargetIfFilterMarkoftheCrane304(Target) and EvaluateTargetIfTigerPalm802(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 828"; end
    end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (((Player:BuffStack(S.ChiEnergyBuff) > (30 - (5 * EnemiesCount8))) and Player:BuffDown(S.StormEarthAndFireBuff) and ((S.RisingSunKick:CooldownRemains() > 2 and (S.FistsOfFury:CooldownRemains() > 2)) or (S.RisingSunKick:CooldownRemains() < 3 and S.FistsOfFury:CooldownRemains() > 3 and Player:Chi() > 3) or (S.RisingSunKick:CooldownRemains() > 3 and S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() > 4) or (Player:ChiDeficit() <= 1 and EnergyTimeToMaxRounded() < 2))) or (Player:BuffStack(S.ChiEnergyBuff) > 10 and HL.BossFilteredFightRemains("<", 7))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "Spinning Crane Kick 830"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(talent.serenity&cooldown.serenity.remains<3|cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>1|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>3|chi>5|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick804) then return "Blackout Kick 832"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick804(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 834"; end
    end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane304, EvaluateTargetIfTigerPalm202) then return "Tiger Palm 836"; end
    if EvaluateTargetIfFilterMarkoftheCrane304(Target) and EvaluateTargetIfTigerPalm202(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 838"; end
    end
  end
  -- flying_serpent_kick,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick Slam 840"; end
  end
  if S.FlyingSerpentKick:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(40)) then return "Flying Serpent Kick 842"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains<3&chi=2&prev_gcd.1.tiger_palm&energy.time_to_50<1
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick806) then return "Blackout Kick 844"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick806(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 846"; end
    end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<2&(chi.max-chi<=1|prev_gcd.1.tiger_palm)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick808) then return "Blackout Kick 848"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick808(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "Blackout Kick 850"; end
    end
  end
end

-- Action Lists --
--- ======= MAIN =======
-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = #Enemies8y -- AOE Toogle
  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  ComputeTargetRange()

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end

    -- auto_attack
    -- Fortifying Brew
    if S.FortifyingBrew:IsReady() and IsTanking and Settings.Windwalker.ShowFortifyingBrewCD  then
      if HR.Cast(S.FortifyingBrew, Settings.Windwalker.GCDasOffGCD.FortifyingBrew, nil, not Target:IsSpellInRange(S.FortifyingBrew)) then return "Fortifying Brew 100"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if ShouldReturn then return ShouldReturn; end
    -- Stun
    local ShouldReturn = Everyone.Interrupt(5, S.LegSweep, Settings.Commons.GCDasOffGCD.LegSweep, Stuns); if ShouldReturn and Settings.General.InterruptWithStun then return ShouldReturn; end
    -- Trap
    local ShouldReturn = Everyone.Interrupt(20, S.Paralysis, Settings.Commons.GCDasOffGCD.Paralysis, Stuns); if ShouldReturn and Settings. General.InterruptWithStun then return ShouldReturn; end
    -- Knock Back
    local ShouldReturn = Everyone.Interrupt(40, S.RingOfPeace, Settings.Commons.GCDasOffGCD.RingOfPeace, Stuns); if ShouldReturn and Settings.General.InterruptWithStun then return ShouldReturn; end
    -- variable,name=hold_xuen,op=set,value=cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains<120&fight_remains>cooldown.serenity.remains&cooldown.serenity.remains>10
    if (true) then
      VarXuenHold = (HL.BossFilteredFightRemains("<", S.InvokeXuenTheWhiteTiger:CooldownRemains()) or HL.BossFilteredFightRemains("<", 120)) and HL.BossFilteredFightRemains(">", S.Serenity:CooldownRemains()) and (S.Serenity:CooldownRemains() > 10)
    end
    -- potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&pet.xuen_the_white_tiger.active|fight_remains<=60
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofPhantomFire) then return "Potion of Phantom Fire 102"; end
    end
    if I.PotionofSpectralAgility:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofSpectralAgility) then return "Potion of Spectral Agility 104"; end
    end
    if I.PotionofDeathlyFixation:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofDeathlyFixation) then return "Potion of Deathly Fixation 106"; end
    end
    if I.PotionofEmpoweredExorcisms:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofEmpoweredExorcisms) then return "Potion of Empowered Exorcisms 108"; end
    end
    if I.PotionofHardenedShadows:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofHardenedShadows) then return "Potion of Hardened Shadows 110"; end
    end
    if I.PotionofSpectralStamina:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60))then
      if HR.CastSuggested(I.PotionofSpectralStamina) then return "Potion of Spectral Stamina 112"; end
    end
    -- call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffUp(S.SerenityBuff) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=weapons_of_order,if=buff.weapons_of_order.up
    if Player:BuffUp(S.WeaponsOfOrder) then
      local ShouldReturn = WeaponsOfOrder(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=opener,if=time<4&chi<5&!pet.xuen_the_white_tiger.active
    if HL.CombatTime() < 4 and Player:Chi() < 5 and (not (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&(energy.time_to_max<1|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
    if S.FistOfTheWhiteTiger:IsReady() then
      if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger104) then return "Fist of the White Tiger 114"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistOfTheWhiteTiger104(Target)) then
        if HR.Cast(S.FistOfTheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistOfTheWhiteTiger)) then return "Fist of the White Tiger 116"; end
      end
    end
    -- expel_harm,if=chi.max-chi>=1&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
    if S.ExpelHarm:IsReady() and Player:Level() >= 43 and Player:ChiDeficit() >= 1 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and (S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2) then
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "Expel Harm 118"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
    if S.TigerPalm:IsReady() then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm106) then return "Tiger Palm 120"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm106(Target)) then
        if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "Tiger Palm 122"; end
      end
    end
    -- call_action_list,name=cd_sef,if=!talent.serenity
    if (HR.CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity
    if (HR.CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if ((EnemiesCount8 < 3) or (not HR.AoEON())) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if HR.AoEON() and (EnemiesCount8 >= 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
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

HR.SetAPL(269, APL, Init)

-- Last Update: 2020-12-18

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion
-- actions.precombat+=/variable,name=xuen_on_use_trinket,op=set,value=0
-- actions.precombat+=/chi_burst
-- actions.precombat+=/chi_wave,if=!talent.energizing_elixir.enabled

-- # Executed every time the actor is available.
-- # Executed every time the actor is available.
-- actions=auto_attack
-- actions+=/spear_hand_strike,if=target.debuff.casting.react
-- actions+=/variable,name=hold_xuen,op=set,value=cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains<120&fight_remains>cooldown.serenity.remains&cooldown.serenity.remains>10
-- actions+=/potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&pet.xuen_the_white_tiger.active|fight_remains<=60
-- actions+=/call_action_list,name=serenity,if=buff.serenity.up
-- actions+=/call_action_list,name=weapons_of_order,if=buff.weapons_of_order.up
-- actions+=/call_action_list,name=opener,if=time<4&chi<5&!pet.xuen_the_white_tiger.active
-- actions+=/fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&(energy.time_to_max<1|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
-- actions+=/expel_harm,if=chi.max-chi>=1&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
-- actions+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)
-- actions+=/call_action_list,name=cd_sef,if=!talent.serenity
-- actions+=/call_action_list,name=cd_serenity,if=talent.serenity
-- actions+=/call_action_list,name=st,if=active_enemies<3
-- actions+=/call_action_list,name=aoe,if=active_enemies>=3

-- actions.aoe=whirling_dragon_punch
-- actions.aoe+=/energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>2|chi.max-chi>=4
-- actions.aoe+=/spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|debuff.bonedust_brew.up)
-- actions.aoe+=/fists_of_fury,if=energy.time_to_max>execute_time|chi.max-chi<=1
-- actions.aoe+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+4)&(cooldown.fists_of_fury.remains>3|chi>=5)
-- actions.aoe+=/rushing_jade_wind,if=buff.rushing_jade_wind.down
-- actions.aoe+=/spinning_crane_kick,if=combo_strike&((cooldown.bonedust_brew.remains>2&(chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2))|energy.time_to_max<=3)
-- actions.aoe+=/expel_harm,if=chi.max-chi>=1
-- actions.aoe+=/fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
-- actions.aoe+=/chi_burst,if=chi.max-chi>=2
-- actions.aoe+=/crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.fists_of_fury.remains>execute_time
-- actions.aoe+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=chi.max-chi>=2&(!talent.hit_combo|combo_strike)
-- actions.aoe+=/chi_wave,if=combo_strike
-- actions.aoe+=/flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
-- actions.aoe+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|talent.hit_combo&prev_gcd.1.tiger_palm&chi=2&cooldown.fists_of_fury.remains<3|chi.max-chi<=1&prev_gcd.1.spinning_crane_kick&energy.time_to_max<3)

-- actions.cd_sef=invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
-- actions.cd_sef+=/arcane_torrent,if=chi.max-chi>=1
-- actions.cd_sef+=/touch_of_death,if=buff.storm_earth_and_fire.down&pet.xuen_the_white_tiger.active|fight_remains<10|fight_remains>180
-- actions.cd_sef+=/weapons_of_order,if=(raid_event.adds.in>45|raid_event.adds.up)&cooldown.rising_sun_kick.remains<execute_time
-- actions.cd_sef+=/faeline_stomp,if=combo_strike&(raid_event.adds.in>10|raid_event.adds.up)
-- actions.cd_sef+=/fallen_order,if=raid_event.adds.in>30|raid_event.adds.up
-- actions.cd_sef+=/bonedust_brew,if=raid_event.adds.in>50|raid_event.adds.up,line_cd=60
-- actions.cd_sef+=/storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|fight_remains<20|(raid_event.adds.remains>15|!covenant.kyrian&((raid_event.adds.in>cooldown.storm_earth_and_fire.full_recharge_time|!raid_event.adds.exists)&(cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time|variable.hold_xuen))&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
-- actions.cd_sef+=/storm_earth_and_fire,if=covenant.kyrian&(buff.weapons_of_order.up|(fight_remains<cooldown.weapons_of_order.remains|cooldown.weapons_of_order.remains>cooldown.storm_earth_and_fire.full_recharge_time)&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
-- actions.cd_sef+=/use_item,name=inscrutable_quantum_device
-- actions.cd_sef+=/use_item,name=darkmoon_deck_voracity
-- actions.cd_sef+=/touch_of_karma,if=fight_remains>159|pet.xuen_the_white_tiger.active|variable.hold_xuen
-- actions.cd_sef+=/blood_fury,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
-- actions.cd_sef+=/berserking,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<15
-- actions.cd_sef+=/lights_judgment
-- actions.cd_sef+=/fireblood,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<10
-- actions.cd_sef+=/ancestral_call,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
-- actions.cd_sef+=/bag_of_tricks,if=buff.storm_earth_and_fire.down

-- actions.cd_serenity=variable,name=serenity_burst,op=set,value=cooldown.serenity.remains<1|pet.xuen_the_white_tiger.active&cooldown.serenity.remains>30|fight_remains<20
-- actions.cd_serenity+=/invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
-- actions.cd_serenity+=/use_item,name=inscrutable_quantum_device
-- actions.cd_serenity+=/use_item,name=darkmoon_deck_voracity
-- actions.cd_serenity+=/blood_fury,if=variable.serenity_burst
-- actions.cd_serenity+=/berserking,if=variable.serenity_burst
-- actions.cd_serenity+=/arcane_torrent,if=chi.max-chi>=1
-- actions.cd_serenity+=/lights_judgment
-- actions.cd_serenity+=/fireblood,if=variable.serenity_burst
-- actions.cd_serenity+=/ancestral_call,if=variable.serenity_burst
-- actions.cd_serenity+=/bag_of_tricks,if=variable.serenity_burst
-- actions.cd_serenity+=/touch_of_death,if=fight_remains>180|pet.xuen_the_white_tiger.active|fight_remains<10
-- actions.cd_serenity+=/touch_of_karma,if=fight_remains>90|pet.xuen_the_white_tiger.active|fight_remains<10
-- actions.cd_serenity+=/weapons_of_order,if=cooldown.rising_sun_kick.remains<execute_time
-- actions.cd_serenity+=/faeline_stomp
-- actions.cd_serenity+=/fallen_order
-- actions.cd_serenity+=/bonedust_brew
-- actions.cd_serenity+=/serenity,if=cooldown.rising_sun_kick.remains<2|fight_remains<15
-- actions.cd_serenity+=/bag_of_tricks

-- actions.opener=fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
-- actions.opener+=/expel_harm,if=talent.chi_burst.enabled&chi.max-chi>=3
-- actions.opener+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2
-- actions.opener+=/chi_wave,if=chi.max-chi=2
-- actions.opener+=/expel_harm
-- actions.opener+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=chi.max-chi>=2

-- actions.serenity=fists_of_fury,if=buff.serenity.remains<1
-- actions.serenity+=/use_item,name=inscrutable_quantum_device
-- actions.serenity+=/use_item,name=darkmoon_deck_voracity
-- actions.serenity+=/spinning_crane_kick,if=combo_strike&(active_enemies>=3|active_enemies>1&!cooldown.rising_sun_kick.up)
-- actions.serenity+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
-- actions.serenity+=/fists_of_fury,if=active_enemies>=3
-- actions.serenity+=/spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.weapons_of_order_ww.up&cooldown.rising_sun_kick.remains>2
-- actions.serenity+=/fists_of_fury,interrupt_if=!cooldown.rising_sun_kick.up
-- actions.serenity+=/spinning_crane_kick,if=combo_strike&debuff.bonedust_brew.up
-- actions.serenity+=/fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
-- actions.serenity+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo
-- actions.serenity+=/spinning_crane_kick

-- actions.st=whirling_dragon_punch,if=raid_event.adds.in>cooldown.whirling_dragon_punch.duration*0.8|raid_event.adds.up
-- actions.st+=/energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3|chi.max-chi>=4&(energy.time_to_max>2|!prev_gcd.1.tiger_palm)
-- actions.st+=/spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&(raid_event.adds.in>buff.dance_of_chiji.remains-2|raid_event.adds.up)
-- actions.st+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>1|!talent.serenity
-- actions.st+=/fists_of_fury,if=(raid_event.adds.in>cooldown.fists_of_fury.duration*0.8|raid_event.adds.up)&(energy.time_to_max>execute_time-1|chi.max-chi<=1|buff.storm_earth_and_fire.remains<execute_time+1)|fight_remains<execute_time+1
-- actions.st+=/crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.rising_sun_kick.remains>execute_time|buff.the_emperors_capacitor.stack>14&(cooldown.serenity.remains<5&talent.serenity|cooldown.weapons_of_order.remains<5&covenant.kyrian|fight_remains<5)
-- actions.st+=/rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
-- actions.st+=/fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
-- actions.st+=/expel_harm,if=chi.max-chi>=1
-- actions.st+=/chi_burst,if=chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2&active_enemies>=2
-- actions.st+=/chi_wave
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.down
-- actions.st+=/spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(talent.serenity&cooldown.serenity.remains<3|cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>1|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>3|chi>5|buff.bok_proc.up)
-- actions.st+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2
-- actions.st+=/flying_serpent_kick,interrupt=1
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains<3&chi=2&prev_gcd.1.tiger_palm&energy.time_to_50<1
-- actions.st+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<2&(chi.max-chi<=1|prev_gcd.1.tiger_palm)

-- actions.weapons_of_order=call_action_list,name=cd_sef,if=!talent.serenity
-- actions.weapons_of_order+=/call_action_list,name=cd_serenity,if=talent.serenity
-- actions.weapons_of_order+=/energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3
-- actions.weapons_of_order+=/rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
-- actions.weapons_of_order+=/spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
-- actions.weapons_of_order+=/fists_of_fury,if=active_enemies>=2&buff.weapons_of_order_ww.remains<1
-- actions.weapons_of_order+=/whirling_dragon_punch,if=active_enemies>=2
-- actions.weapons_of_order+=/spinning_crane_kick,if=combo_strike&active_enemies>=3&buff.weapons_of_order_ww.up
-- actions.weapons_of_order+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&active_enemies<=2
-- actions.weapons_of_order+=/whirling_dragon_punch
-- actions.weapons_of_order+=/fists_of_fury,interrupt=1,if=buff.storm_earth_and_fire.up&raid_event.adds.in>cooldown.fists_of_fury.duration*0.6
-- actions.weapons_of_order+=/spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies
-- actions.weapons_of_order+=/fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
-- actions.weapons_of_order+=/expel_harm,if=chi.max-chi>=1
-- actions.weapons_of_order+=/chi_burst,if=chi.max-chi>=(1+active_enemies>1)
-- actions.weapons_of_order+=/tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=(!talent.hit_combo|combo_strike)&chi.max-chi>=2
-- actions.weapons_of_order+=/chi_wave
-- actions.weapons_of_order+=/blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=chi>=3|buff.weapons_of_order_ww.up
-- actions.weapons_of_order+=/flying_serpent_kick,interrupt=1
