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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker;
local I = Item.Monk.Windwalker;
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.GalecallersBoon:ID(),
  I.LustrousGoldenPlumage:ID(),
  I.PocketsizedComputationDevice:ID(),
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
  I.RemoteGuidanceDevice:ID(),
  I.WrithingSegmentofDrestagath:ID()
}

-- Rotation Var
local IsInMeleeRange
local IsInAoERange
local Enemies5y
local Enemies8y
local EnemiesCount8
local ShouldReturn
local VarXuenOnUse = false
local VarXuenHold = false
local VarSerenityBurst = false
local Interrupts = {
  { S.SpearHandStrike, "Cast Spear Hand Strike (Interrupt)", function () return true end },
}
local VarHoldTod = false
local VarFoPPreChan = 0

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Monk = HR.Commons.Monk;
local Settings = {
  General    = HR.GUISettings.General,
  Commons    = HR.GUISettings.APL.Monk.Commons,
  Windwalker = HR.GUISettings.APL.Monk.Windwalker
};

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence()
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID])
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight()

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

local function ConflictAndStrifeMajor()
  if Spell:MajorEssenceEnabled(AE.ConflictandStrife) then return 1 else return 0 end
end

local function EvaluateTargetIfFilterMarkoftheCrane100(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFistoftheWhiteTiger102(TargetUnit)
  return (Player:Chi() < 3)
end

local function EvaluateTargetIfFistoftheWhiteTiger104(TargetUnit)
  return (Player:ChiDeficit() >= 3 and ((EnergyTimeToMaxRounded() < 1 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5))
end

local function EvaluateTargetIfTigerPalm106(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5)
end

local function EvaluateTargetIfRisingSunKick200(TargetUnit)
  return ((S.WhirlingDragonPunch:IsAvailable() and ((10 * Player:SpellHaste()) > (S.WhirlingDragonPunch:CooldownRemains() + 3))) and ((S.FistsofFury:CooldownRemains() > 3) or Player:Chi() >= 5))
end

local function EvaluateTargetIfFistoftheWhiteTiger202(TargetUnit)
  return (Player:ChiDeficit() >= 3)
end

local function EvaluateTargetIfTigerPalm204(TargetUnit)
  return (Player:ChiDeficit() >= 2 and (not S.HitCombo:IsAvailable() or ComboStrike(S.TigerPalm)))
end

local function EvaluateTargetIfBlackoutKick206(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.BlackoutKickBuff) or (S.HitCombo:IsAvailable() and Player:PrevGCD(1, S.TigerPalm) and ((Player:ChiDeficit() >= 1 or Player:EnergyTimeToX(50) < 1) or (Player:Chi() == 2 and S.FistsofFury:CooldownRemains() < 3)))))
end

local function EvaluateTargetIfTigerPalm500(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2)
end

local function EvaluateTargetIfFilterMarkoftheCrane502(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end
local function EvaluateTargetIfTigerPalm504(TargetUnit)
  return (Player:ChiDeficit() >= 2)
end

local function EvaluateTargetIfRisingSunKick600(TargetUnit)
  return (ComboStrike(S.RisingSunKick))
end

local function EvaluateTargetIfBlackoutKick602(TargetUnit)
  return (ComboStrike(S.BlackoutKick) or not S.HitCombo:IsAvailable())
end

local function EvaluateTargetIfRisingSunKick700(TargetUnit)
  return (S.Serenity:IsAvailable() or S.Serenity:CooldownRemains() > 1 or not S.Serenity:IsAvailable())
end

local function EvaluateTargetIfTigerPalm702(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.StormEarthAndFireBuff))
end

local function EvaluateTargetIfBlackoutKick704(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and ((S.Serenity:IsAvailable() and S.Serenity:CooldownRemains() < 3) or (S.RisingSunKick:CooldownRemains() > 1 and S.TouchofDeath:CooldownRemains() > 1) or (S.RisingSunKick:CooldownRemains() < 3 and S.TouchofDeath:CooldownRemains() > 3 and Player:Chi() > 2) or (S.RisingSunKick:CooldownRemains() > 3 and S.TouchofDeath:CooldownRemains() < 3 and Player:Chi() > 3) or Player:Chi() > 5 or Player:BuffUp(S.BlackoutKickBuff)))
end

local function EvaluateTargetIfTigerPalm706(TargetUnit)
  return (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2)
end

local function EvaluateTargetIfBlackoutKick708(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and (S.FistsofFury:CooldownRemains() < 3 and Player:Chi() == 2 and Player:PrevGCD(1, S.TigerPalm) or Player:EnergyTimeToX(50) < 1))
end

local function EvaluateTargetIfBlackoutKick710(TargetUnit)
  return (ComboStrike(S.BlackoutKick) and EnergyTimeToMaxRounded() < 2 and (Player:ChiDeficit() <= 1 or Player:PrevGCD(1, S.TigerPalm)))
end

local function UseItems()
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
  end
  -- variable,name=xuen_on_use_trinket,op=set,value=0
  if (true) then
    VarXuenOnUse = false
  end
  -- chi_burst,if=!talent.serenity.enabled|!talent.fist_of_the_white_tiger.enabled
  if S.ChiBurst:IsReady() and (not S.Serenity:IsAvailable() or not S.FistoftheWhiteTiger:IsAvailable()) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst 4"; end
  end
  -- chi_wave,if=!talent.energizing_elixer.enabled
  if S.ChiWave:IsReady() and not S.EnergizingElixir:IsAvailable() then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave 6"; end
  end
end

local function Aoe()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "whirling_dragon_punch 200"; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3|chi.max-chi>=4&(energy.time_to_max>2|!prev_gcd.1.tiger_palm)
  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 3) or (Player:ChiDeficit() >= 4 and EnergyTimeToMaxRounded() > 2) or (not Player:PrevGCD(1, S.TigerPalm))) then
    if HR.Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "energizing_elixir 202"; end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|buff.dance_of_chiji_azerite.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceofChijiBuff) or Player:BuffUp(S.DanceofChijiAzeriteBuff)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 204"; end
  end
  -- fists_of_fury,if=energy.time_to_max>execute_time-1|buff.storm_earth_and_fire.remains
  if S.FistsofFury:IsReady() and ((EnergyTimeToMaxRounded() > (S.FistsofFury:ExecuteTime() - 1)) or Player:BuffUp(S.StormEarthAndFireBuff)) then
    if HR.Cast(S.FistsofFury, nil, nil, not Target:IsSpellInRange(S.FistsofFury)) then return "fists_of_fury 206"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=(talent.whirling_dragon_punch.enabled&cooldown.rising_sun_kick.duration>cooldown.whirling_dragon_punch.remains+3)&(cooldown.fists_of_fury.remains>3|chi>=5)
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick200) then return "rising_sun_kick 208"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick200(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "rising_sun_kick 210"; end
    end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind 212"; end
  end
  -- spinning_crane_kick,if=combo_strike&((chi>3|cooldown.fists_of_fury.remains>6)&(chi>=5|cooldown.fists_of_fury.remains>2)|energy.time_to_max<=3)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (((Player:Chi() > 3 or S.FistsofFury:CooldownRemains() > 6) and (Player:Chi() > 5 or S.FistsofFury:CooldownRemains() > 2)) or (EnergyTimeToMaxRounded() <= 3)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 214"; end
  end
  -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm 216"; end
  end
  -- chi_burst,if=chi.max-chi>=1
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst 218"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistoftheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger202) then return "fist_of_the_white_tiger 220"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger202(Target) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistoftheWhiteTiger)) then return "fist_of_the_white_tiger 222"; end
    end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=2&(!talent.hit_combo.enabled|combo_strike)
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm204) then return "tiger_palm 224"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm204(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 226"; end
    end
  end
  -- chi_wave,if=combo_strike
  if S.ChiWave:IsReady() and (ComboStrike(S.ChiWave)) then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave 228"; end
  end
  -- flying_serpent_kick,if=buff.bok_proc.down,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, not Target:IsInRange(40)) then return "chi_wave 230"; end
  end
  if S.FlyingSerpentKick:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(40)) then return "chi_wave 232"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.bok_proc.up|talent.hit_combo.enabled&prev_gcd.1.tiger_palm&(chi.max-chi>=14&energy.time_to_50<1|chi=2&cooldown.fists_of_fury.remains<3))
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick206) then return "blackout_kick 234"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick206(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "blackout_kick 236"; end
    end
  end
end

local function CDSEF()
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and (not VarXuenHold or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger 300"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "arcane_torrent 302"; end
  end
  -- touch_of_death,if=buff.storm_earth_and_fire.down
  if S.TouchofDeath:IsReady() and Target:HealthPercentage() <= 15 and Player:BuffDown(S.StormEarthAndFireBuff) then
    if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, not Target:IsSpellInRange(S.TouchofDeath)) then return "touch_of_death 304"; end
  end
  -- blood_of_the_enemy,if=cooldown.fists_of_fury.remains<2|fight_remains<12
  if S.BloodoftheEnemy:IsCastable() and (S.TouchofDeath:CooldownRemains() < 2 or HL.BossFilteredFightRemains("<", 12)) then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(12)) then return "blood_of_the_enemy 306"; end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 308"; end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 310"; end
  end
  -- concentrated_flame,if=!dot.concentrated_flame_burn.remains&((!talent.whirling_dragon_punch.enabled|cooldown.whirling_dragon_punch.remains)&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&buff.storm_earth_and_fire.down)|fight_remains<8
  if S.ConcentratedFlame:IsCastable() and (Target:DebuffDown(S.ConcentratedFlameBurn) and ((not S.WhirlingDragonPunch:IsAvailable() or not S.WhirlingDragonPunch:CooldownUp()) and not S.RisingSunKick:CooldownUp() and not S.FistsofFury:CooldownUp() and Player:BuffDown(S.StormEarthAndFireBuff)) or HL.BossFilteredFightRemains("<", 8)) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "concentrated_flame 312"; end
  end
  -- the_unbound_force
  if S.TheUnboundForce:IsCastable() then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "the_unbound_force 314"; end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "purifying_blast 316"; end
  end
  -- reaping_flames,if=target.time_to_pct_20>30|target.health.pct<=20
  if (Target:TimeToX(20) > 30 or Target:HealthPercentage() <= 20) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- focused_azerite_beam
  if S.FocusedAzeriteBeam:IsCastable() then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 318"; end
  end
  -- memory_of_lucid_dreams,if=energy<40
  if S.MemoryofLucidDreams:IsCastable() and (Player:Energy() < 40) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 320"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 322"; end
  end
  -- storm_earth_and_fire,if=cooldown.storm_earth_and_fire.charges=2|fight_remains<20|buff.seething_rage.up|(cooldown.blood_of_the_enemy.remains+1>cooldown.storm_earth_and_fire.full_recharge_time|!essence.blood_of_the_enemy.major)&cooldown.fists_of_fury.remains<10&chi>=2&cooldown.whirling_dragon_punch.remains<12
  if S.StormEarthAndFire:IsReady() and (S.StormEarthAndFire:Charges() == 2 or HL.BossFilteredFightRemains("<", 20) or Player:BuffUp(S.SeethingRageBuff) or (((S.BloodoftheEnemy:CooldownRemains() + 1) > S.StormEarthAndFire:FullRechargeTime()) or not Spell:MajorEssenceEnabled(AE.BloodoftheEnemy)) and S.FistsofFury:CooldownRemains() < 10 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() < 12) then
    if HR.Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire 324"; end
  end
  if (Settings.Commons.UseTrinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- touch_of_karma,interval=90,pct_health=0.5
  if S.TouchofKarma:IsReady() and not Settings.Windwalker.IgnoreToK then
    if HR.Cast(S.TouchofKarma, nil, nil, not Target:IsInRange(20)) then return "touch_of_karma 326"; end
  end
  -- blood_fury,if=fight_remains>125|buff.storm_earth_and_fire.up|fight_remains<20
  if S.BloodFury:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or Player:BuffUp(S.StormEarthAndFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 328"; end
  end
  -- berserking,if=fight_remains>185|buff.storm_earth_and_fire.up|fight_remains<20
  if S.Berserking:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or Player:BuffUp(S.StormEarthAndFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 330"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment 332"; end
  end
  -- fireblood,if=fight_remains>125|buff.storm_earth_and_fire.up|fight_remains<20
  if S.Fireblood:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or Player:BuffUp(S.StormEarthAndFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 334"; end
  end
  -- ancestral_call,if=fight_remains>185|buff.storm_earth_and_fire.up|fight_remains<20
  if S.AncestralCall:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or Player:BuffUp(S.StormEarthAndFireBuff) or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 336"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks 338"; end
  end
end

local function CDSerenity()
  -- variable,name=serenity_burst,op=set,value=cooldown.serenity.remains<1|fight_remains<20
  if (true) then
    VarSerenityBurst = (Player:BuffRemains(S.SerenityBuff) < 1 or (HL.BossFilteredFightRemains("<", 20)))
  end
  -- invoke_xuen_the_white_tiger,if=!variable.hold_xuen|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsReady() and ( not VarXuenHold or HL.BossFilteredFightRemains("<", 25)) then
    if HR.Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger 400"; end
  end
  -- guardian_of_azeroth,if=fight_remains>185|variable.serenity_burst|fight_remains<35
  if S.GuardianofAzeroth:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or VarSerenityBurst or HL.BossFilteredFightRemains("<", 35)) then
    if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth 402"; end
  end
  -- worldvein_resonance,if=variable.serenity_burst
  if S.WorldveinResonance:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance 404"; end
  end
  -- blood_of_the_enemy,if=variable.serenity_burst
  if S.BloodoftheEnemy:IsCastable() and VarSerenityBurst then
    if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(12)) then return "blood_of_the_enemy 406"; end
  end
  -- concentrated_flame,if=(cooldown.serenity.remains|cooldown.concentrated_flame.charges=2)&!dot.concentrated_flame_burn.remains&(cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains|fight_remains<8)
  if S.ConcentratedFlame:IsCastable() and ((not S.Serenity:CooldownUp() or S.ConcentratedFlame:Charges() == 2) and Target:DebuffDown(S.ConcentratedFlameBurn) and ((not S.RisingSunKick:CooldownUp() and not S.FistsofFury:CooldownUp()) or HL.BossFilteredFightRemains("<", 8))) then
    if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "concentrated_flame 408"; end
  end
  -- the_unbound_force
  if S.TheUnboundForce:IsCastable() then
    if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "the_unbound_force 410"; end
  end
  -- purifying_blast
  if S.PurifyingBlast:IsCastable() then
    if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "purifying_blast 412"; end
  end
  -- reaping_flames,if=target.time_to_pct_20>30|target.health.pct<=20|target.time_to_die<2
  if (Target:TimeToX(20) > 30 or Target:HealthPercentage() <= 20 or Target:TimeToDie() < 2) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- focused_azerite_beam
  if S.FocusedAzeriteBeam:IsCastable() then
    if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam 414"; end
  end
  -- memory_of_lucid_dreams,if=energy<40
  if S.MemoryofLucidDreams:IsCastable() and (Player:Energy() < 40) then
    if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams 416"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space 418"; end
  end
  -- blood_fury,if=fight_remains>125|variable.serenity_burst
  if S.BloodFury:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or VarSerenityBurst or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 420"; end
  end
  -- berserking,if=fight_remains>185|variable.serenity_burst
  if S.Berserking:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or VarSerenityBurst or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 422"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and Player:ChiDeficit() >= 1 then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInMeleeRange(8)) then return "arcane_torrent 424"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "lights_judgment 426"; end
  end
  -- fireblood,if=fight_remains>125|variable.serenity_burst
  if S.Fireblood:IsCastable() and (HL.BossFilteredFightRemains(">", 125) or VarSerenityBurst or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 428"; end
  end
  -- ancestral_call,if=fight_remains>125|variable.serenity_burst
  if S.AncestralCall:IsCastable() and (HL.BossFilteredFightRemains(">", 185) or VarSerenityBurst or HL.BossFilteredFightRemains("<", 20)) then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 430"; end
  end
  if (Settings.Commons.UseTrinkets) then
    if (true) then
      local ShouldReturn = UseItems(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- touch_of_death
  if S.TouchofDeath:IsReady() and Target:HealthPercentage() <= 15  then
    if HR.Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchofDeath, nil, not Target:IsSpellInRange(S.TouchofDeath)) then return "touch_of_death 432"; end
  end
  -- touch_of_karma,interval=90,pct_health=0.5
  if S.TouchofKarma:IsReady() and not Settings.Windwalker.IgnoreToK then
    if HR.Cast(S.TouchofKarma, nil, nil, not Target:IsInRange(20)) then return "touch_of_karma 434"; end
  end
  -- serenity,if=cooldown.rising_sun_kick.remains<2|fight_remains<15
  if S.Serenity:IsReady() and (S.RisingSunKick:CooldownRemains() < 2 or HL.BossFilteredFightRemains("<", 15)) then
    if HR.Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "serenity 436"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(40)) then return "bag_of_tricks 438"; end
  end
end

local function Opener()
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3
  if S.FistoftheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger202) then return "fist_of_the_white_tiger 500"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger202(Target) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistoftheWhiteTiger)) then return "fist_of_the_white_tiger 502"; end
    end
  end
  -- expel_harm,if=talent.chi_burst.enabled&chi.max-chi>=3
  if S.ExpelHarm:IsReady() and S.ChiBurst:IsAvailable() and Player:ChiDeficit() >= 3 then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm 504"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm500) then return "tiger_palm 624"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm500(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 506"; end
    end
  end
  -- chi_wave,if=chi.max-chi=2
  if S.ChiWave:IsReady() and Player:ChiDeficit() >= 2 then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave 6"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm 508"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.recently_rushing_tiger_palm.up*20),if=chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm504) then return "tiger_palm 624"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm504(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 514"; end
    end
  end
end

local function Serenity()
  -- fists_of_fury,if=buff.serenity.remains<1|active_enemies>1
  if S.FistsofFury:IsReady() and (Player:BuffRemains(S.SerenityBuff) < 1 or EnemiesCount8 > 1) then
    if HR.Cast(S.FistsofFury, nil, nil, not Target:IsSpellInRange(S.FistsofFury)) then return "fists_of_fury 600"; end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>2|active_enemies>1&!cooldown.rising_sun_kick.up)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (EnemiesCount8 > 2 or (EnemiesCount8 > 1 and not S.RisingSunKick:CooldownUp()))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 602"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick600) then return "rising_sun_kick 604"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick600(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "rising_sun_kick 606"; end
    end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|buff.dance_of_chiji_azerite.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceofChijiBuff) or Player:BuffUp(S.DanceofChijiAzeriteBuff)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 608"; end
  end
  -- fists_of_fury,interrupt_if=gcd.remains=0
  if S.FistsofFury:IsReady() then
    if HR.Cast(S.FistsofFury, nil, nil, not Target:IsSpellInRange(S.FistsofFury)) then return "fists_of_fury 610"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistoftheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger102) then return "fist_of_the_white_tiger 172"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger102(Target) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistoftheWhiteTiger)) then return "fist_of_the_white_tiger 612"; end
    end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike|!talent.hit_combo.enabled
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick602) then return "blackout_kick 614"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick602(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "blackout_kick 616"; end
    end
  end
  -- spinning_crane_kick
  if S.SpinningCraneKick:IsReady() then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 618"; end
  end
end

local function St()
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() and Player:BuffUp(S.WhirlingDragonPunchBuff) then
    if HR.Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(8)) then return "whirling_dragon_punch 700"; end
  end
  -- energizing_elixir,if=chi.max-chi>=2&energy.time_to_max>3|chi.max-chi>=4&(energy.time_to_max>2|!prev_gcd.1.tiger_palm)
  if S.EnergizingElixir:IsReady() and ((Player:ChiDeficit() >= 2 and EnergyTimeToMaxRounded() > 3) or (Player:ChiDeficit() >= 4 and EnergyTimeToMaxRounded() > 2) or (not Player:PrevGCD(1, S.TigerPalm))) then
    if HR.Cast(S.EnergizingElixir, Settings.Windwalker.OffGCDasOffGCD.EnergizingElixir) then return "energizing_elixir 702"; end
  end
  -- spinning_crane_kick,if=combo_strike&(buff.dance_of_chiji.up|buff.dance_of_chiji_azerite.up)
  if S.SpinningCraneKick:IsReady() and ComboStrike(S.SpinningCraneKick) and (Player:BuffUp(S.DanceofChijiBuff) or Player:BuffUp(S.DanceofChijiAzeriteBuff)) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 704"; end
  end
  -- fists_of_fury
  if S.FistsofFury:IsReady() then
    if HR.Cast(S.FistsofFury, nil, nil, not Target:IsSpellInRange(S.FistsofFury)) then return "fists_of_fury 706"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=cooldown.serenity.remains>1|!talent.serenity.enabled
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfRisingSunKick700) then return "rising_sun_kick 708"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfRisingSunKick700(Target) then
      if HR.Cast(S.RisingSunKick, nil, nil, not Target:IsSpellInRange(S.RisingSunKick)) then return "rising_sun_kick 710"; end
    end
  end
  -- rushing_jade_wind,if=buff.rushing_jade_wind.down&active_enemies>1
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and EnemiesCount8 > 1) then
    if HR.Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind 712"; end
  end
  -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) then
    if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm 714"; end
  end
  -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi<3
  if S.FistoftheWhiteTiger:IsReady() then
    if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger102) then return "fist_of_the_white_tiger 716"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger102(Target) then
      if HR.Cast(S.FistoftheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistoftheWhiteTiger)) then return "fist_of_the_white_tiger 718"; end
    end
  end
  -- chi_burst,if=chi.max-chi>=1
  if S.ChiBurst:IsReady() and (Player:ChiDeficit() >= 1) then
    if HR.Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst 720"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if HR.Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave 722"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.down
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm702) then return "tiger_palm 724"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm702(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 726"; end
    end
  end
  -- spinning_crane_kick,if=buff.chi_energy.stack>30-5*active_enemies&combo_strike&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.ChiEnergyBuff) > (30 - (5 * EnemiesCount8))) and ComboStrike(S.SpinningCraneKick) and (((S.RisingSunKick:CooldownRemains() > 2 and S.FistsofFury:CooldownRemains() > 2) or (S.RisingSunKick:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:Chi() > 3) or (S.RisingSunKick:CooldownRemains() > 3 and S.FistsofFury:CooldownRemains() < 3 and Player:Chi() > 4) or (Player:ChiDeficit() <= 1 and EnergyTimeToMaxRounded() < 2)) or (Player:BuffStack(S.ChiEnergyBuff) > 10 and HL.BossFilteredFightRemains("<", 7))) then
    if HR.Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick 728"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(talent.serenity.enabled&cooldown.serenity.remains<3|cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>1|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>2|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>3|chi>5|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick704) then return "blackout_kick 730"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick704(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "blackout_kick 732"; end
    end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2
  if S.TigerPalm:IsReady() then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm706) then return "tiger_palm 734"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm706(Target) then
      if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 736"; end
    end
  end
  -- flying_serpent_kick,interrupt=1
  if S.FlyingSerpentKickActionBarReplacement:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKickActionBarReplacement, nil, nil, not Target:IsInRange(40)) then return "flying_serpent_kick 738"; end
  end
  if S.FlyingSerpentKick:IsReady() and not Settings.Windwalker.IgnoreFSK then
    if HR.Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(40)) then return "flying_serpent_kick 740"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains<3&chi=2&prev_gcd.1.tiger_palm&energy.time_to_50<1
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick708) then return "blackout_kick 742"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick708(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "blackout_kick 744"; end
    end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<2&(chi.max-chi<=1|prev_gcd.1.tiger_palm)
  if S.BlackoutKick:IsReady() then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfBlackoutKick710) then return "blackout_kick 746"; end
    if EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfBlackoutKick710(Target) then
      if HR.Cast(S.BlackoutKick, nil, nil, not Target:IsSpellInRange(S.BlackoutKick)) then return "blackout_kick 748"; end
    end
  end
end

-- Action Lists --
--- ======= MAIN =======ss
-- APL Main
local function APL()
  Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  EnemiesCount8 = Target:GetEnemiesInSplashRangeCount(8) -- AOE Toogle
  
  ComputeTargetRange()

  if Everyone.TargetIsValid() then
    -- Out of Combat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
  
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.SpearHandStrike, Settings.Commons.OffGCDasOffGCD.SpearHandStrike, Interrupts); if ShouldReturn then return ShouldReturn; end
    -- variable,name=hold_xuen,op=set,value=cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains<120&fight_remains>cooldown.serenity.remains&cooldown.serenity.remains>10
    if (true) then
      VarXuenHold = (HL.BossFilteredFightRemains("<", S.InvokeXuenTheWhiteTiger:CooldownRemains()) or HL.BossFilteredFightRemains("<", 120)) and HL.BossFilteredFightRemains(">", S.Serenity:CooldownRemains()) and (S.Serenity:CooldownRemains() > 10)
    end
    -- potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&pet.xuen_the_white_tiger.active|fight_remains<=60
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24 or HL.BossFilteredFightRemains("<=", 60)) then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 100"; end
    end
    -- call_action_list,name=serenity,if=buff.serenity.up
    if Player:BuffUp(S.SerenityBuff) then
      local ShouldReturn = Serenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=opener,if=time<5&chi<5&!pet.xuen_the_white_tiger.active
    if HL.CombatTime() < 5 and Player:Chi() < 5 and (not (S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- fist_of_the_white_tiger,target_if=min:debuff.mark_of_the_crane.remains,if=chi.max-chi>=3&(energy.time_to_max<1|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.FistoftheWhiteTiger:IsReady() then
      if Everyone.CastTargetIf(S.FistoftheWhiteTiger, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfFistoftheWhiteTiger104) then return "fist_of_the_white_tiger 102"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfFistoftheWhiteTiger104(Target)) then
        if HR.Cast(S.FistoftheWhiteTiger, nil, nil, not Target:IsSpellInRange(S.FistoftheWhiteTiger)) then return "fist_of_the_white_tiger 104"; end
      end
    end
    -- expel_harm,if=chi.max-chi>=1+essence.conflict_and_strife.major&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.ExpelHarm:IsReady() and ((Player:ChiDeficit() >= (1 + ConflictAndStrifeMajor())) and (EnergyTimeToMaxRounded() < 1 or S.Serenity:CooldownRemains() < 2 or EnergyTimeToMaxRounded() < 4) and S.FistsofFury:CooldownRemains() < 1.5) then
      if HR.Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm 106"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.max-chi>=2&(energy.time_to_max<1|cooldown.serenity.remains<2|energy.time_to_max<4&cooldown.fists_of_fury.remains<1.5)
    if S.TigerPalm:IsReady() then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane100, EvaluateTargetIfTigerPalm106) then return "tiger_palm 108"; end
      if (EvaluateTargetIfFilterMarkoftheCrane100(Target) and EvaluateTargetIfTigerPalm106(Target)) then
        if HR.Cast(S.TigerPalm, nil, nil, not Target:IsSpellInRange(S.TigerPalm)) then return "tiger_palm 110"; end
      end
    end
    -- ccall_action_list,name=cd_sef,if=!talent.serenity.enabled
    if (HR.CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity.enabled
    if (HR.CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3
    if (EnemiesCount8 < 3) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (EnemiesCount8 >= 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added Pool filler
    if HR.Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
--  HL.RegisterNucleusAbility(113656, 8, 6)               -- Fists of Fury
--  HL.RegisterNucleusAbility(101546, 8, 6)               -- Spinning Crane Kick
--  HL.RegisterNucleusAbility(261715, 8, 6)               -- Rushing Jade Wind
--  HL.RegisterNucleusAbility(152175, 8, 6)               -- Whirling Dragon Punch
end

HR.SetAPL(269, APL, Init);
