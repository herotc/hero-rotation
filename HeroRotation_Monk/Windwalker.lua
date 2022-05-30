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
local Cast       = HR.Cast
-- Lua
local pairs      = pairs


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker
local I = Item.Monk.Windwalker

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.CacheofAcquiredTreasures:ID(),
  I.GladiatorsBadgeCosmic:ID(),
  I.GladiatorsBadgeSinful:ID(),
  I.GladiatorsBadgeUnchained:ID(),
  I.InscrutibleQuantumDevice:ID(),
  I.OverchargedAnimaBattery:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.ShadowgraspTotem:ID(),
  I.TheFirstSigil:ID(),
  I.Wrathstone:ID(),
}

-- Rotation Var
local Enemies5y
local Enemies8y
local EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111
local XuenActive
local VarXuenOnUse = false
local VarHoldXuen = false
local VarHoldSEF = false
local VarSerenityBurst = false
local VarBoKNeeded = false
local Stuns = {
  { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end },
  { S.RingOfPeace, "Cast Ring Of Peace (Stun)", function () return true end },
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
local FaelineHarmonyEquipped = Player:HasLegendaryEquipped(257)

HL:RegisterForEvent(function()
  CelestialInfusionEquipped = Player:HasLegendaryEquipped(88)
  EscapeFromRealityEquipped = Player:HasLegendaryEquipped(82)
  FatalTouchEquipped = Player:HasLegendaryEquipped(85)
  InvokersDelightEquipped = Player:HasLegendaryEquipped(83)
  JadeIgnitionEquipped = Player:HasLegendaryEquipped(96)
  KeefersSkyreachEquipped = Player:HasLegendaryEquipped(95)
  LastEmperorsCapacitorEquipped = Player:HasLegendaryEquipped(97)
  XuensTreasureEquipped = Player:HasLegendaryEquipped(94)
  FaelineHarmonyEquipped = Player:HasLegendaryEquipped(257)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

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

local function EvaluateTargetIfFilterMarkoftheCrane100(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkOfTheCraneDebuff)
end

local function EvaluateTargetIfFilterMarkoftheCrane101(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkOfTheCraneDebuff) + (num(TargetUnit:DebuffUp(S.SkyreachExhaustion)) * 20)
end

local function EvaluateTargetIfFistOfTheWhiteTiger102(TargetUnit)
  return (Player:ChiDeficit() >= 3 and (EnergyTimeToMaxRounded() < 1 or EnergyTimeToMaxRounded() < 4 and S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2) and TargetUnit:DebuffDown(S.BonedustBrew))
end

local function EvaluateTargetIfTigerPalm106(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4 and S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2) and TargetUnit:DebuffDown(S.BonedustBrew))
end

local function UseItems()
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- variable,name=xuen_on_use_trinket,op=set,value=equipped.inscrutable_quantum_device|equipped.gladiators_badge|equipped.wrathstone|equipped.overcharged_anima_battery|equipped.shadowgrasp_totem|equipped.the_first_sigil|equipped.cache_of_acquired_treasures
  VarXuenOnUse = (I.InscrutibleQuantumDevice:IsEquipped() or I.GladiatorsBadgeCosmic:IsEquipped() or I.GladiatorsBadgeSinful:IsEquipped() or I.GladiatorsBadgeUnchained:IsEquipped() or I.Wrathstone:IsEquipped() or I.OverchargedAnimaBattery:IsEquipped() or I.ShadowgraspTotem:IsEquipped() or I.TheFirstSigil:IsEquipped() or I.CacheofAcquiredTreasures:IsEquipped())
  -- fleshcraft
  if S.Fleshcraft:IsCastable() then
    if Cast(S.Fleshcraft) then return "fleshcraft precombat 2"; end
  end
  -- chi_burst,if=!covenant.night_fae
  if S.ChiBurst:IsReady() and (CovenantID ~= 3) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat 4"; end
  end
  -- chi_wave,if=!talent.energizing_elixir.enabled
  if S.ChiWave:IsReady() and (not S.EnergizingElixir:IsAvailable()) then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat 6"; end
  end
end

local function Opener()
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistOfTheWhiteTiger:IsReady() and (Player:ChiDeficit() >= 3) then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "fist_of_the_white_tiger opener 2"; end
  end
  -- expel_harm,if=talent.chi_burst.enabled&chi.max-chi>=3
  if S.ExpelHarm:IsReady() and (S.ChiBurst:IsAvailable() and Player:ChiDeficit() >= 3) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm opener 4"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm opener 6"; end
  end
  -- chi_wave,if=chi.max-chi=2
  if S.ChiWave:IsReady() and (Player:ChiDeficit() >= 2) then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave opener 8"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm opener 10"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=chi.max-chi>=2
  if S.TigerPalm:IsReady() and (Player:ChiDeficit() >= 2) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm opener 12"; end
  end
end

local function Aoe()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "whirling_dragon_punch aoe 2"; end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|debuff.bonedust_brew_debuff.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceOfChijiBuff) or Target:DebuffUp(S.BonedustBrew))) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick aoe 6"; end
  end
  -- fists_of_fury,if=energy.time_to_max>execute_time|chi.max-chi<=1
  if S.FistsOfFury:IsReady() and (EnergyTimeToMaxRounded() > S.FistsOfFury:ExecuteTime() or Player:ChiDeficit() <= 1) then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury aoe 8"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+4)&(cooldown.fists_of_fury.remains>3|chi>=5)
  if S.RisingSunKick:IsReady() and ((S.WhirlingDragonPunch:IsAvailable() and S.RisingSunKick:CooldownRemains() > S.WhirlingDragonPunch:CooldownRemains() + 4) and (S.FistsOfFury:CooldownRemains() > 3 or Player:Chi() >= 5)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick aoe 10"; end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind aoe 12"; end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm aoe 14"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistOfTheWhiteTiger:IsReady() and (Player:ChiDeficit() >= 3) then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "fist_of_the_white_tiger aoe 16"; end
  end
  -- chi_burst,if=chi.max-chi>=2
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 2) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst aoe 18"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.fists_of_fury.remains>execute_time
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitor) > 19 and EnergyTimeToMaxRounded() > S.CracklingJadeLightning:ExecuteTime() - 1 and S.FistsOfFury:CooldownRemains() > S.CracklingJadeLightning:ExecuteTime()) then
    if Cast(S.CracklingJadeLightning, nil, nil, not Target:IsInRange(40)) then return "crackling_jade_lightning aoe 20"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=chi.max-chi>=2&(!talent.hit_combo|combo_strike)
  if S.TigerPalm:IsReady() and (Player:ChiDeficit() >= 2 and ((not S.HitCombo:IsAvailable()) or ComboStrike(S.TigerPalm))) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm aoe 22"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "arcane_torrent aoe 24"; end
  end
  -- spinning_crane_kick,if=combo_strike&(cooldown.bonedust_brew.remains>2|!covenant.necrolord)&(chi>=5|cooldown.fists_of_fury.remains>6|cooldown.fists_of_fury.remains>3&chi>=3&energy.time_to_50<1|energy.time_to_max<=(3+3*cooldown.fists_of_fury.remains<5)|buff.storm_earth_and_fire.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (S.BonedustBrew:CooldownRemains() > 2 or CovenantID ~= 4) and (Player:Chi() >= 5 or S.FistsOfFury:CooldownRemains() > 6 or S.FistsOfFury:CooldownRemains() > 3 and Player:Chi() >= 3 and Player:EnergyTimeToX(50) < 1 or EnergyTimeToMaxRounded() <= (3 + 3 * num(S.FistsOfFury:CooldownRemains() < 5)) or Player:BuffUp(S.StormEarthAndFireBuff))) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick aoe 26"; end
  end
  -- chi_wave,if=combo_strike
  if S.ChiWave:IsReady() and (ComboStrike(S.ChiWave)) then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave aoe 28"; end
  end
  -- flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
  local FSK = S.FlyingSerpentKickActionBarReplacement:IsAvailable() and S.FlyingSerpentKickActionBarReplacement or S.FlyingSerpentKick
  if FSK:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if Cast(FSK, nil, nil, not Target:IsInRange(40)) then return "flying_serpent_kick aoe 30"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|talent.hit_combo&prev_gcd.1.tiger_palm&chi=2&cooldown.fists_of_fury.remains<3|chi.max-chi<=1&prev_gcd.1.spinning_crane_kick&energy.time_to_max<3)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.BlackoutKickBuff) or S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and Player:Chi() == 2 and S.FistsOfFury:CooldownRemains() < 3 or Player:ChiDeficit() <= 1 and Player:PrevGCD(1, S.SpinningCraneKick) and EnergyTimeToMaxRounded() < 3)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick aoe 32"; end
  end
end

local function CDSerenity()
  -- variable,name=serenity_burst,op=set,value=cooldown.serenity.remains<1|pet.xuen_the_white_tiger.active&cooldown.serenity.remains>30|fight_remains<20
  VarSerenityBurst = (S.Serenity:CooldownRemains() < 1 or XuenActive and S.Serenity:CooldownRemains() > 30 or FightRemains < 20)
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and ((not VarHoldXuen) or FightRemains < 25) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_serenity 2"; end
  end
  if VarSerenityBurst then
    -- ancestral_call,if=variable.serenity_burst
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd_serenity 4"; end
    end
    -- blood_fury,if=variable.serenity_burst
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd_serenity 6"; end
    end
    -- fireblood,if=variable.serenity_burst
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd_serenity 8"; end
    end
    -- berserking,if=variable.serenity_burst
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd_serenity 10"; end
    end
    -- bag_of_tricks
    if S.BagOfTricks:IsCastable() then
      if Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks cd_serenity 12"; end
    end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment cd_serenity 14"; end
  end
  -- touch_of_death,if=fight_remains>(180-runeforge.fatal_touch*120)|pet.xuen_the_white_tiger.active&(!covenant.necrolord|buff.bonedust_brew.up)|(cooldown.invoke_xuen_the_white_tiger.remains>fight_remains)&buff.bonedust_brew.up|fight_remains<10
  if S.TouchOfDeath:IsReady() and (FightRemains > (180 - num(FatalTouchEquipped) * 120) or XuenActive and (CovenantID ~= 4 or Player:BuffUp(S.BonedustBrew)) or (S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains) and Player:BuffUp(S.BonedustBrew) or FightRemains < 10) then
    if Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsSpellInRange(S.TouchOfDeath)) then return "touch_of_death cd_serenity 16"; end
  end
  -- touch_of_karma,if=fight_remains>90|pet.xuen_the_white_tiger.active|fight_remains<10
  if S.TouchOfKarma:IsReady() and not Settings.Windwalker.IgnoreToK and (FightRemains > 90 or XuenActive or FightRemains < 10) then
    if Cast(S.TouchOfKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cd_serenity 18"; end
  end
  -- weapons_of_order,if=cooldown.rising_sun_kick.remains<execute_time
  if S.WeaponsOfOrder:IsReady() and (S.RisingSunKick:CooldownRemains() < S.WeaponsOfOrder:ExecuteTime()) then
    if Cast(S.WeaponsOfOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "weapons_of_order cd_serenity 20"; end
  end
  if (VarSerenityBurst or FightRemains < 20) then
    -- use_item,name=jotungeirr_destinys_call,if=variable.serenity_burst|fight_remains<20
    if I.Jotungeirr:IsEquippedAndReady() then
      if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call cd_serenity 22"; end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=inscrutable_quantum_device,if=variable.serenity_burst|fight_remains<20
      if I.InscrutibleQuantumDevice:IsEquippedAndReady() then
        if Cast(I.InscrutibleQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device cd_serenity 24"; end
      end
      -- use_item,name=wrathstone,if=variable.serenity_burst|fight_remains<20
      if I.Wrathstone:IsEquippedAndReady() then
        if Cast(I.Wrathstone, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wrathstone cd_serenity 26"; end
      end
      -- use_item,name=overcharged_anima_battery,if=variable.serenity_burst|fight_remains<20
      if I.OverchargedAnimaBattery:IsEquippedAndReady() then
        if Cast(I.OverchargedAnimaBattery, nil, Settings.Commons.DisplayStyle.Trinkets) then return "overcharged_anima_battery cd_serenity 28"; end
      end
    end
  end
  -- use_item,name=shadowgrasp_totem,if=pet.xuen_the_white_tiger.active|fight_remains<20|!runeforge.invokers_delight
  if I.ShadowgraspTotem:IsEquippedAndReady() and (XuenActive or FightRemains < 20 or not InvokersDelightEquipped) then
    if Cast(I.ShadowgraspTotem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowgrasp_totem cd_serenity 30"; end
  end
  if (Settings.Commons.Enabled.Trinkets and (VarSerenityBurst or FightRemains < 20)) then
    -- use_item,name=gladiators_badge,if=variable.serenity_burst|fight_remains<20
    if I.GladiatorsBadgeCosmic:IsEquippedAndReady() then
      if Cast(I.GladiatorsBadgeCosmic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_serenity 32 cosmic"; end
    end
    if I.GladiatorsBadgeSinful:IsEquippedAndReady() then
      if Cast(I.GladiatorsBadgeSinful, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_serenity 32 sinful"; end
    end
    if I.GladiatorsBadgeUnchained:IsEquippedAndReady() then
      if Cast(I.GladiatorsBadgeUnchained, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_serenity 32 unchained"; end
    end
    -- use_item,name=the_first_sigil,if=variable.serenity_burst|fight_remains<20
    if I.TheFirstSigil:IsEquippedAndReady() then
      if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "the_first_sigil cd_serenity 34"; end
    end
  end
  -- use_items,if=!variable.xuen_on_use_trinket|cooldown.invoke_xuen_the_white_tiger.remains>20|variable.hold_xuen
  if ((not VarXuenOnUse) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 20 or VarHoldXuen) then
    local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
  end
  -- faeline_stomp
  if S.FaelineStomp:IsReady() and ComboStrike(S.FaelineStomp) then
    if Cast(S.FaelineStomp, nil, Settings.Commons.CovenantDisplayStyle) then return "faeline_stomp cd_serenity 36"; end
  end
  -- fallen_order
  if S.FallenOrder:IsReady() then
    if Cast(S.FallenOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "fallen_order cd_serenity 38"; end
  end
  -- bonedust_brew,if=fight_remains<15|(chi>=2&(fight_remains>60&((cooldown.serenity.remains>10|buff.serenity.up|cooldown.serenity.up)&(pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>10|variable.hold_xuen)))|(fight_remains<=60&(pet.xuen_the_White_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>fight_remains)))
  if S.BonedustBrew:IsReady() and (FightRemains < 15 or (Player:Chi() >= 2 and (FightRemains > 60 and ((S.Serenity:CooldownRemains() > 10 or Player:BuffUp(S.SerenityBuff) or S.Serenity:CooldownUp()) and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or VarHoldXuen))) or (FightRemains <= 60 and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains)))) then
    if Cast(S.BonedustBrew, nil, Settings.Commons.CovenantDisplayStyle) then return "bonedust_brew cd_serenity 40"; end
  end
  -- serenity,if=cooldown.rising_sun_kick.remains<2|fight_remains<15
  if S.Serenity:IsReady() and (S.RisingSunKick:CooldownRemains() < 2 or FightRemains < 15) then
    if Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "serenity cd_serenity 42"; end
  end
  -- bag_of_tricks
  if S.BagOfTricks:IsCastable() then
    if Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks cd_serenity 44"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption&!pet.xuen_the_white_tiger.active&buff.serenity.down&buff.bonedust_brew_debuff.down
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() and (not XuenActive) and Player:BuffDown(S.SerenityBuff) and Player:BuffDown(S.BonedustBrew)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft cd_serenity 46"; end
  end
end

local function CDSEF()
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen&(cooldown.rising_sun_kick.remains<2|!covenant.kyrian)&(!covenant.necrolord|cooldown.bonedust_brew.remains<2)|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and ((not VarHoldXuen) and (S.RisingSunKick:CooldownRemains() < 2 or CovenantID ~= 1) and (CovenantID ~= 4 or S.BonedustBrew:CooldownRemains() < 2) or FightRemains < 25) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_sef 2"; end
  end
  -- touch_of_death,if=fight_remains>(180-runeforge.fatal_touch*120)|buff.storm_earth_and_fire.down&pet.xuen_the_white_tiger.active&(!covenant.necrolord|buff.bonedust_brew.up)|(cooldown.invoke_xuen_the_white_tiger.remains>fight_remains)&buff.bonedust_brew.up|fight_remains<10
  if S.TouchOfDeath:IsReady() and (FightRemains > (180 - num(FatalTouchEquipped) * 120) or Player:BuffDown(S.StormEarthAndFireBuff) and XuenActive and (CovenantID ~= 4 or Player:BuffUp(S.BonedustBrew)) or (S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains) and Player:BuffUp(S.BonedustBrew) or FightRemains < 10) then
    if Cast(S.TouchOfDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsSpellInRange(S.TouchOfDeath)) then return "touch_of_death cd_sef 4"; end
  end
  -- weapons_of_order,if=(raid_event.adds.in>45|raid_event.adds.up)&cooldown.rising_sun_kick.remains<execute_time&cooldown.invoke_xuen_the_white_tiger.remains>(20+20*runeforge.invokers_delight)&(!runeforge.xuens_treasure|cooldown.fists_of_fury.remains)|fight_remains<35
  if S.WeaponsOfOrder:IsReady() and (S.RisingSunKick:CooldownRemains() < S.WeaponsOfOrder:ExecuteTime() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > (20 + 20 * num(InvokersDelightEquipped)) and ((not XuensTreasureEquipped) or S.FistsOfFury:CooldownRemains() > 0) or FightRemains < 35) then
    if Cast(S.WeaponsOfOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "weapons_of_order cd_sef 6"; end
  end
  -- faeline_stomp,if=combo_strike&(raid_event.adds.in>10|raid_event.adds.up)
  if S.FaelineStomp:IsReady() and (ComboStrike(S.FaelineStomp)) then
    if Cast(S.FaelineStomp, nil, Settings.Commons.CovenantDisplayStyle) then return "faeline_stomp cd_sef 8"; end
  end
  -- fallen_order,if=raid_event.adds.in>30|raid_event.adds.up
  if S.FallenOrder:IsReady() then
    if Cast(S.FallenOrder, nil, Settings.Commons.CovenantDisplayStyle) then return "fallen_order cd_sef 10"; end
  end
  -- bonedust_brew,if=!buff.bonedust_brew.up&(chi>=2&fight_remains>60&(cooldown.storm_earth_and_fire.charges>0|cooldown.storm_earth_and_fire.remains>10)&(pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>10|variable.hold_xuen)|(chi>=2&fight_remains<=60&(pet.xuen_the_White_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>fight_remains)&(cooldown.storm_earth_and_fire.charges>0|cooldown.storm_earth_and_fire.remains>fight_remains|buff.storm_earth_and_fire.up))|fight_remains<15)|fight_remains<10&soulbind.lead_by_example
  if S.BonedustBrew:IsReady() and (Player:BuffDown(S.BonedustBrew) and (Player:Chi() >= 2 and FightRemains > 60 and (S.StormEarthAndFire:Charges() > 0 or S.StormEarthAndFire:CooldownRemains() > 10) and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or VarHoldXuen) or (Player:Chi() >= 2 and FightRemains <= 60 and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains) and (S.StormEarthAndFire:Charges() > 0 or S.StormEarthAndFire:CooldownRemains() > FightRemains or Player:BuffUp(S.StormEarthAndFireBuff))) or FightRemains < 15) or FightRemains < 10 and S.LeadByExample:SoulbindEnabled()) then
    if Cast(S.BonedustBrew, nil, Settings.Commons.CovenantDisplayStyle) then return "bonedust_brew cd_sef 12"; end
  end
  -- storm_earth_and_fire_fixate,if=conduit.coordinated_offensive.enabled
  if S.StormEarthAndFireFixate:IsCastable() and (Player:BuffUp(S.StormEarthAndFireBuff) and S.StormEarthAndFireFixate:TimeSinceLastCast() > 15) and (S.CoordinatedOffensive:ConduitEnabled()) then
    if Cast(S.StormEarthAndFireFixate, Settings.Windwalker.GCDasOffGCD.StormEarthAndFireFixate) then return "storm_earth_and_fire_fixate cd_sef 14"; end
  end
  -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|fight_remains<20|(raid_event.adds.remains>15|(!covenant.kyrian&!covenant.necrolord)&((raid_event.adds.in>cooldown.storm_earth_and_fire.full_recharge_time|!raid_event.adds.exists)&(cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time|variable.hold_xuen))&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
  if S.StormEarthAndFire:IsReady() and (S.StormEarthAndFire:Charges() == 2 or FightRemains < 20 or ((CovenantID ~= 1 and CovenantID ~= 4) and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime() or VarHoldXuen) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cd_sef 16"; end
  end
  -- storm_earth_and_fire,if=covenant.kyrian&(buff.weapons_of_order.up|(fight_remains<cooldown.weapons_of_order.remains|cooldown.weapons_of_order.remains>cooldown.storm_earth_and_fire.full_recharge_time)&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12)
  if S.StormEarthAndFire:IsReady() and (CovenantID == 1 and (Player:BuffUp(S.WeaponsOfOrder) or (FightRemains < S.WeaponsOfOrder:CooldownRemains() or S.WeaponsOfOrder:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime()) and S.FistsOfFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12)) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cd_sef 18"; end
  end
  -- storm_earth_and_fire,if=covenant.necrolord&(debuff.bonedust_brew_debuff.up&!variable.hold_sef)&debuff.bonedust_brew_debuff.up&(pet.xuen_the_white_tiger.active|variable.hold_xuen|cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time|cooldown.invoke_xuen_the_white_tiger.remains>30)
  if S.StormEarthAndFire:IsReady() and (CovenantID == 4 and (Target:DebuffUp(S.BonedustBrew) and not VarHoldSEF) and Target:DebuffUp(S.BonedustBrew) and (XuenActive or VarHoldXuen or S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime() or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30)) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cd_sef 20"; end
  end
  -- use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<35
  if I.ScarsofFraternalStrife:IsEquippedAndReady() and Settings.Commons.Enabled.Trinkets and (Player:BuffDown(S.ScarsofFraternalStrifeBuff4) or FightRemains < 35) then
    if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife cd_sef 22"; end
  end
  -- use_item,name=jotungeirr_destinys_call,if=pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>60&fight_remains>180|fight_remains<20
  if I.Jotungeirr:IsEquippedAndReady() and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 60 and FightRemains > 180 or FightRemains < 20) then
    if Cast(I.Jotungeirr, nil, Settings.Commons.DisplayStyle.Items) then return "jotungeirr_destinys_call cd_sef 24"; end
  end
  if (Settings.Commons.Enabled.Trinkets) then
    -- use_item,name=inscrutable_quantum_device,if=pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>60&fight_remains>180|fight_remains<20
    if I.InscrutibleQuantumDevice:IsEquippedAndReady() and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 60 and FightRemains > 180 or FightRemains < 20) then
      if Cast(I.InscrutibleQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device cd_sef 26"; end
    end
    -- use_item,name=wrathstone,if=pet.xuen_the_white_tiger.active|fight_remains<20
    if I.Wrathstone:IsEquippedAndReady() and (XuenActive or FightRemains < 20) then
      if Cast(I.Wrathstone, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wrathstone cd_sef 28"; end
    end
    -- use_item,name=shadowgrasp_totem,if=pet.xuen_the_white_tiger.active|fight_remains<20|!runeforge.invokers_delight
    if I.ShadowgraspTotem:IsEquippedAndReady() and (XuenActive or FightRemains < 20 or not InvokersDelightEquipped) then
      if Cast(I.ShadowgraspTotem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowgrasp_totem cd_sef 30"; end
    end
    -- use_item,name=overcharged_anima_battery,if=pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>90|fight_remains<20
    if I.OverchargedAnimaBattery:IsEquippedAndReady() and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 90 or FightRemains < 20) then
      if Cast(I.OverchargedAnimaBattery, nil, Settings.Commons.DisplayStyle.Trinkets) then return "overcharged_anima_battery cd_sef 32"; end
    end
    -- use_item,name=gladiators_badge,if=cooldown.invoke_xuen_the_white_tiger.remains>55|variable.hold_xuen|fight_remains<15
    if I.GladiatorsBadgeCosmic:IsEquippedAndReady() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 55 or VarHoldXuen or FightRemains < 15) then
      if Cast(I.GladiatorsBadgeCosmic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_sef 34 cosmic"; end
    end
    if I.GladiatorsBadgeSinful:IsEquippedAndReady() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 55 or VarHoldXuen or FightRemains < 15) then
      if Cast(I.GladiatorsBadgeSinful, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_sef 34 sinful"; end
    end
    if I.GladiatorsBadgeUnchained:IsEquippedAndReady() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 55 or VarHoldXuen or FightRemains < 15) then
      if Cast(I.GladiatorsBadgeUnchained, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge cd_sef 34 unchained"; end
    end
    -- use_item,name=the_first_sigil,if=pet.xuen_the_white_tiger.remains>15|cooldown.invoke_xuen_the_white_tiger.remains>60&fight_remains>300|fight_remains<20
    if I.TheFirstSigil:IsEquippedAndReady() and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() < 9 or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 60 and FightRemains > 300 or FightRemains < 20) then
      if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "the_first_sigil cd_sef 36"; end
    end
    -- use_item,name=cache_of_acquired_treasures,if=active_enemies<2&buff.acquired_wand.up|active_enemies>1&buff.acquired_axe.up|fight_remains<20
    if I.CacheofAcquiredTreasures:IsEquippedAndReady() and (EnemiesCount8y < 2 and Player:BuffUp(S.AcquiredWandBuff) or EnemiesCount8y > 1 and Player:BuffUp(S.AcquiredAxeBuff) or FightRemains < 20) then
      if Cast(I.CacheofAcquiredTreasures, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cache_of_acquired_treasures cd_sef 38"; end
    end
    -- use_items,if=!variable.xuen_on_use_trinket|cooldown.invoke_xuen_the_white_tiger.remains>20&pet.xuen_the_white_tiger.remains<20|variable.hold_xuen
    if ((not VarXuenOnUse) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 20 and XuenActive and S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() > 4 or VarHoldXuen) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- touch_of_karma,if=fight_remains>90|pet.xuen_the_white_tiger.active|variable.hold_xuen|fight_remains<16
  if S.TouchOfKarma:IsReady() and not Settings.Windwalker.IgnoreToK and (FightRemains > 90 or XuenActive or VarHoldXuen or FightRemains < 16) then
    if Cast(S.TouchOfKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cd_sef 40"; end
  end
  -- touch_of_karma,if=fight_remains>159|variable.hold_xuen
  if S.TouchOfKarma:IsReady() and not Settings.Windwalker.IgnoreToK and (FightRemains > 159 or VarHoldXuen) then
    if Cast(S.TouchOfKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cd_sef 42"; end
  end
  if (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarHoldXuen or FightRemains < 20) then
    -- ancestral_call,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd_sef 44"; end
    end
    -- blood_fury,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd_sef 46"; end
    end
    -- fireblood,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd_sef 48"; end
    end
    -- berserking,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd_sef 50"; end
    end
  end
  -- bag_of_tricks,if=buff.storm_earth_and_fire.down
  if S.BagOfTricks:IsCastable() and (Player:BuffDown(S.StormEarthAndFireBuff)) then
    if Cast(S.BagOfTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks cd_sef 52"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment cd_sef 54"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption&!pet.xuen_the_white_tiger.active&buff.storm_earth_and_fire.down&buff.bonedust_brew.down
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() and (not XuenActive) and Player:BuffDown(S.StormEarthAndFireBuff) and Player:BuffDown(S.BonedustBrew)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft cd_sef 56"; end
  end
end

local function Serenity()
  -- fists_of_fury,if=buff.serenity.remains<1
  if S.FistsOfFury:IsReady() and (Player:BuffRemains(S.SerenityBuff) < 1) then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury serenity 2"; end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>=3|active_enemies>1&!cooldown.rising_sun_kick.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (EnemiesCount8y >= 3 or EnemiesCount8y > 1 and not S.RisingSunKick:CooldownUp())) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 4"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity 6"; end
  end
  -- fists_of_fury,if=active_enemies>=3
  if S.FistsOfFury:IsReady() and (EnemiesCount8y >= 3) then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury serenity 8"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 10"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.weapons_of_order.up&cooldown.rising_sun_kick.remains>2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.WeaponsOfOrder) and S.RisingSunKick:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 12"; end
  end
  -- fists_of_fury,interrupt_if=!cooldown.rising_sun_kick.up
  if S.FistsOfFury:IsReady() then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury serenity 14"; end
  end
  -- spinning_crane_kick,if=combo_strike&debuff.bonedust_brew.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Target:DebuffUp(S.BonedustBrew)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 16"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistOfTheWhiteTiger:IsReady() and (Player:Chi() < 3) then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "fist_of_the_white_tiger serenity 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) or not S.HitCombo:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 20"; end
  end
  -- spinning_crane_kick
  if S.SpinningCraneKick:IsReady() then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 22"; end
  end
end

local function WeaponsOfOrder()
  -- call_action_list,name=cd_sef,if=!talent.serenity
  if (CDsON() and not S.Serenity:IsAvailable()) then
    local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=cd_serenity,if=talent.serenity
  if (CDsON() and S.Serenity:IsAvailable()) then
    local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick weapons_of_order 4"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&cooldown.rising_sun_kick.remains&buff.weapons_of_order_ww.up
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsOfFury:CooldownRemains() > 0 and S.RisingSunKick:CooldownRemains() > 0 and Player:BuffUp(S.WeaponsOfOrderChiBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick weapons_of_order 6"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick weapons_of_order 7"; end
  end
  -- fists_of_fury,interrupt=1,interrupt_immediate=1,if=buff.weapons_of_order_ww.up&buff.storm_earth_and_fire.up&!set_bonus.tier28_2pc&active_enemies<2
  if S.FistsOfFury:IsReady() and (Player:BuffUp(S.WeaponsOfOrderChiBuff) and Player:BuffUp(S.StormEarthAndFireBuff) and (not Player:HasTier(28, 2)) and EnemiesCount8y < 2) then
    if HR.CastQueue(S.FistsOfFury, S.StopFoF) then return "one_gcd fists_of_fury weapons_of_order 8"; end
  end
  -- fists_of_fury,if=buff.weapons_of_order_ww.up&buff.storm_earth_and_fire.up&set_bonus.tier28_2pc|active_enemies>=2&buff.weapons_of_order_ww.remains<1
  if S.FistsOfFury:IsReady() and (Player:BuffUp(S.WeaponsOfOrderChiBuff) and Player:BuffUp(S.StormEarthAndFireBuff) and Player:HasTier(28, 2) or EnemiesCount8y >= 2 and AoEON() and Player:BuffRemains(S.WeaponsOfOrderChiBuff) < 1) then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury weapons_of_order 10"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "whirling_dragon_punch weapons_of_order 12"; end
  end
  -- spinning_crane_kick,if=combo_strike&active_enemies>=3&buff.weapons_of_order_ww.up
  if S.SpinningCraneKick:IsReady() and AoEON() and (ComboStrike(S.SpinningCraneKick) and EnemiesCount8y >= 3 and Player:BuffUp(S.WeaponsOfOrderChiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick weapons_of_order 14"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi=0&buff.weapons_of_order_ww.remains<4|chi<3
  if S.FistOfTheWhiteTiger:IsReady() and (Player:Chi() == 0 and Player:BuffRemains(S.WeaponsOfOrderChiBuff) < 4 or Player:Chi() < 3) then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100) then return "fist_of_the_white_tiger weapons_of_order 16"; end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInRange(8)) then return "expel_harm weapons_of_order 18"; end
  end
  -- chi_burst,if=chi.max-chi>=(1+active_enemies>1)
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= (1 + num(EnemiesCount8y > 1))) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst weapons_of_order 20"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=chi=0&buff.weapons_of_order_ww.remains<4|(!talent.hit_combo|combo_strike)&chi.max-chi>=2
  if S.TigerPalm:IsReady() and (Player:Chi() == 0 and Player:BuffRemains(S.WeaponsOfOrderChiBuff) < 4 or ((not S.HitCombo:IsAvailable()) or ComboStrike(S.TigerPalm)) and Player:ChiDeficit() >= 2) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm weapons_of_order 22"; end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.ChiEnergyBuff) > 30 - 5 * EnemiesCount8y) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInRange(8)) then return "spinning_crane_kick weapons_of_order 24"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&active_enemies<=3&chi>=3|buff.weapons_of_order_ww.up
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and EnemiesCount8y <= 3 and Player:Chi() >= 3 or Player:BuffUp(S.WeaponsOfOrderChiBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100) then return "blackout_kick weapons_of_order 26"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave weapons_of_order 28"; end
  end
  -- flying_serpent_kick,interrupt=1
  local FSK = S.FlyingSerpentKickActionBarReplacement:IsAvailable() and S.FlyingSerpentKickActionBarReplacement or S.FlyingSerpentKick
  if FSK:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if Cast(FSK, nil, nil, not Target:IsInRange(40)) then return "flying_serpent_kick weapons_of_order 30"; end
  end
end

local function St()
  -- whirling_dragon_punch,if=(buff.primordial_potential.stack<9|buff.bonedust_brew.remains<cooldown.rising_sun_kick.remains&buff.bonedust_brew.up&pet.xuen_the_white_tiger.active)&(raid_event.adds.in>cooldown.whirling_dragon_punch.duration*0.8|spell_targets>1)
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffStack(S.PrimordialPotentialBuff) < 9 or Player:BuffRemains(S.BonedustBrew) < S.RisingSunKick:CooldownRemains() and Player:BuffUp(S.BonedustBrew) and XuenActive) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "whirling_dragon_punch st 2"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&(raid_event.adds.in>buff.dance_of_chiji.remains-2|raid_event.adds.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceOfChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick st 6"; end
  end
  -- fleshcraft,interrupt_immediate=1,interrupt_if=buff.volatile_solvent_humanoid.up|energy.time_to_max<3|cooldown.rising_sun_kick.remains<2|cooldown.fists_of_fury.remains<2,if=soulbind.volatile_solvent&buff.storm_earth_and_fire.down&debuff.bonedust_brew_debuff.down
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.StormEarthAndFireBuff) and Target:DebuffDown(S.BonedustBrew)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft st 8"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>1|!talent.serenity&(cooldown.weapons_of_order.remains>4|!covenant.kyrian)&(!runeforge.xuens_treasure|cooldown.fists_of_fury.remains)
  if S.RisingSunKick:IsReady() and (S.Serenity:CooldownRemains() > 1 or (not S.Serenity:IsAvailable()) and (S.WeaponsOfOrder:CooldownRemains() > 4 or CovenantID ~= 1) and ((not XuensTreasureEquipped) or S.FistsOfFury:CooldownRemains() > 0)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick st 10"; end
  end
  -- fists_of_fury,if=(raid_event.adds.in>cooldown.fists_of_fury.duration*0.8|raid_event.adds.up)&(energy.time_to_max>execute_time-1|chi.max-chi<=1|buff.storm_earth_and_fire.remains<execute_time+1)|fight_remains<execute_time+1|debuff.bonedust_brew_debuff.up|buff.primordial_power.up
  if S.FistsOfFury:IsReady() and ((EnergyTimeToMaxRounded() > S.FistsOfFury:ExecuteTime() - 1 or Player:ChiDeficit() <= 1 or Player:BuffRemains(S.StormEarthAndFireBuff) < S.FistsOfFury:ExecuteTime() + 1) or FightRemains < S.FistsOfFury:ExecuteTime() + 1 or Target:DebuffUp(S.BonedustBrew) or Player:BuffUp(S.PrimordialPowerBuff)) then
    if Cast(S.FistsOfFury, nil, nil, not Target:IsSpellInRange(S.FistsOfFury)) then return "fists_of_fury st 12"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.rising_sun_kick.remains>execute_time|buff.the_emperors_capacitor.stack>14&(cooldown.serenity.remains<5&talent.serenity|cooldown.weapons_of_order.remains<5&covenant.kyrian|fight_remains<5)
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitor) > 19 and EnergyTimeToMaxRounded() > S.CracklingJadeLightning:ExecuteTime() - 1 and S.RisingSunKick:CooldownRemains() > S.CracklingJadeLightning:ExecuteTime() or Player:BuffStack(S.TheEmperorsCapacitor) > 14 and (S.Serenity:IsAvailable() and S.Serenity:CooldownRemains() < 5 or CovenantID == 1 and S.WeaponsOfOrder:CooldownRemains() < 5 or FightRemains < 5)) then
    if Cast(S.CracklingJadeLightning, nil, nil, not Target:IsInRange(40)) then return "crackling_jade_lightning st 14"; end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and EnemiesCount8y > 1) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind st 16"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistOfTheWhiteTiger:IsReady() and (Player:Chi() < 3) then
    if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "fist_of_the_white_tiger st 18"; end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm st 20"; end
  end
  -- chi_burst,if=chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2&active_enemies>=2
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1 and EnemiesCount8y == 1 or Player:ChiDeficit() >= 2 and EnemiesCount8y >= 2) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst st 22"; end
  end
  -- chi_wave,if=!buff.primordial_power.up
  if S.ChiWave:IsReady() and (Player:BuffDown(S.PrimordialPowerBuff)) then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave st 24"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.down
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.StormEarthAndFireBuff)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm st 26"; end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.ChiEnergyBuff) > 30 - 5 * EnemiesCount8y and Player:BuffDown(S.StormEarthAndFireBuff) and (S.RisingSunKick:CooldownRemains() > 2 and S.FistsOfFury:CooldownRemains() > 2 or S.RisingSunKick:CooldownRemains() < 3 and S.FistsOfFury:CooldownRemains() > 3 and Player:Chi() > 3 or S.RisingSunKick:CooldownRemains() > 3 and S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() > 4 or Player:ChiDeficit() <= 1 and EnergyTimeToMaxRounded() < 2) or Player:BuffStack(S.ChiEnergyBuff) > 10 and FightRemains < 7) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick st 28"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(talent.serenity&cooldown.serenity.remains<3|cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>1|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>3|chi>5|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (S.Serenity:IsAvailable() and S.Serenity:CooldownRemains() < 3 or S.RisingSunKick:CooldownRemains() > 1 and S.FistsOfFury:CooldownRemains() > 1 or S.RisingSunKick:CooldownRemains() < 3 and S.FistsOfFury:CooldownRemains() > 3 and Player:Chi() > 2 or S.RisingSunKick:CooldownRemains() > 3 and S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() > 3 or Player:Chi() > 5 or Player:BuffUp(S.BlackoutKickBuff))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick st 30"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm st 32"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent st 34"; end
  end
  -- flying_serpent_kick,interrupt=1,if=!covenant.necrolord|buff.primordial_potential.up
  local FSK = S.FlyingSerpentKickActionBarReplacement:IsAvailable() and S.FlyingSerpentKickActionBarReplacement or S.FlyingSerpentKick
  if FSK:IsReady() and (not Settings.Windwalker.IgnoreFSK) and (CovenantID ~= 4 or Player:BuffUp(S.PrimordialPotentialBuff)) then
    if Cast(FSK, nil, nil, not Target:IsInRange(40)) then return "flying_serpent_kick st 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains<3&chi=2&prev_gcd.1.tiger_palm&energy.time_to_50<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsOfFury:CooldownRemains() < 3 and Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm) and Player:EnergyTimeToX(50) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick st 38"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<2&(chi.max-chi<=1|prev_gcd.1.tiger_palm)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and EnergyTimeToMaxRounded() < 2 and (Player:ChiDeficit() <= 1 or Player:PrevGCD(1, S.TigerPalm))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick st 40"; end
  end
end

-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  if AoEON() then
    EnemiesCount8y = #Enemies8y -- AOE Toogle
  else
    EnemiesCount8y = 1
  end

  local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end
  end

  XuenActive = S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Fortifying Brew
    if S.FortifyingBrew:IsReady() and IsTanking and Settings.Windwalker.ShowFortifyingBrewCD  then
      if Cast(S.FortifyingBrew, Settings.Windwalker.GCDasOffGCD.FortifyingBrew, nil, not Target:IsSpellInRange(S.FortifyingBrew)) then return "fortifying_brew main 2"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Stuns); if ShouldReturn then return ShouldReturn; end
    -- variable,name=hold_xuen,op=set,value=cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains-cooldown.invoke_xuen_the_white_tiger.remains<120&((talent.serenity&fight_remains>cooldown.serenity.remains&cooldown.serenity.remains>10)|(cooldown.storm_earth_and_fire.full_recharge_time<fight_remains&cooldown.storm_earth_and_fire.full_recharge_time>15)|(cooldown.storm_earth_and_fire.charges=0&cooldown.storm_earth_and_fire.remains<fight_remains))
    VarHoldXuen = (S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains or FightRemains - S.InvokeXuenTheWhiteTiger:CooldownRemains() < 120 and ((S.Serenity:IsAvailable() and FightRemains > S.Serenity:CooldownRemains() and S.Serenity:CooldownRemains() > 10) or (S.StormEarthAndFire:FullRechargeTime() < FightRemains and S.StormEarthAndFire:FullRechargeTime() > 15) or (S.StormEarthAndFire:Charges() == 0 and S.StormEarthAndFire:CooldownRemains() < FightRemains)))
    -- variable,name=hold_sef,op=set,value=cooldown.bonedust_brew.up&cooldown.storm_earth_and_fire.charges<2&chi<3|buff.bonedust_brew.remains<8
    VarHoldSEF = (S.BonedustBrew:CooldownUp() and S.StormEarthAndFire:Charges() < 2 and Player:Chi() < 3 or Player:BuffRemains(S.BonedustBrew) < 8)
    -- potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&pet.xuen_the_white_tiger.active|fight_remains<=60
    if I.PotionofSpectralAgility:IsReady() and Settings.Commons.UsePotions and ((Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and XuenActive or FightRemains <= 60) then
      if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    -- call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffUp(S.SerenityBuff) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=weapons_of_order,if=buff.weapons_of_order.up
    if Player:BuffUp(S.WeaponsOfOrder) then
      local ShouldReturn = WeaponsOfOrder(); if ShouldReturn then return ShouldReturn; end
    end
    -- faeline_stomp,if=combo_strike&(raid_event.adds.in>10|active_enemies>2)&(runeforge.faeline_harmony|soulbind.grove_invigoration|active_enemies<3&buff.storm_earth_and_fire.down)
    if S.FaelineStomp:IsCastable() and (ComboStrike(S.FaelineStomp) and (FaelineHarmonyEquipped or S.GroveInvigoration:SoulbindEnabled() or EnemiesCount8y < 3 and Player:BuffDown(S.StormEarthAndFireBuff))) then
      if Cast(S.FaelineStomp, nil, Settings.Commons.DisplayStyle.Covenant) then return "faeline_stomp main 6"; end
    end
    -- call_action_list,name=opener,if=time<4&chi<5&!pet.xuen_the_white_tiger.active
    if (HL.CombatTime() < 4 and Player:Chi() < 5 and not (XuenActive)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&(energy.time_to_max<1|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)&!debuff.bonedust_brew_debuff.up
    if S.FistOfTheWhiteTiger:IsReady() then
      if Everyone.CastTargetIf(S.FistOfTheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistOfTheWhiteTiger102, not Target:IsInMeleeRange(5)) then return "fist_of_the_white_tiger main 10"; end
    end
    -- expel_harm,if=chi.max-chi>=1&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)&!buff.bonedust_brew.up
    if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4 and S.FistsOfFury:CooldownRemains() < 1.5 or S.WeaponsOfOrder:CooldownRemains() < 2) and Target:DebuffDown(S.BonedustBrew)) then
      if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm main 12"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5|cooldown.weapons_of_order.remains<2)&!debuff.bonedust_brew_debuff.up
    if S.TigerPalm:IsReady() then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm106, not Target:IsInMeleeRange(5)) then return "tiger_palm main 14"; end
    end
    -- chi_burst,if=covenant.night_fae&cooldown.faeline_stomp.remains>25&(chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2&active_enemies>=2)
    if S.ChiBurst:IsReady() and (CovenantID == 3 and S.FaelineStomp:CooldownRemains() > 25 and (Player:ChiDeficit() >= 1 and EnemiesCount8y == 1 or Player:ChiDeficit() >= 2 and EnemiesCount8y >= 2)) then
      if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst main 16"; end
    end
    -- energizing_elixir,if=prev_gcd.1.tiger_palm&chi<4
    if S.EnergizingElixir:IsCastable() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 4) then
      if Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "energizing_elixir main 18"; end
    end
    -- call_action_list,name=cd_sef,if=!talent.serenity
    if (CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity
    if (CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount8y < 3 or not AoEON()) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (AoEON() and EnemiesCount8y >= 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added Pool filler
    if Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
  --HR.Print("Windwalker Monk rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(269, APL, Init)
