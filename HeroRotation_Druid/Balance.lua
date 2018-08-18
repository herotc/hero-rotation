--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Balance = {
  MoonkinForm                           = Spell(24858),
  SolarWrath                            = Spell(190984),
  FuryofElune                           = Spell(202770),
  CelestialAlignmentBuff                = Spell(194223),
  IncarnationBuff                       = Spell(102560),
  CelestialAlignment                    = Spell(194223),
  Incarnation                           = Spell(102560),
  ForceofNature                         = Spell(205636),
  Sunfire                               = Spell(93402),
  SunfireDebuff                         = Spell(164815),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  StellarFlare                          = Spell(202347),
  LunarStrike                           = Spell(194153),
  LunarEmpowermentBuff                  = Spell(164547),
  SolarEmpowermentBuff                  = Spell(164545),
  Starsurge                             = Spell(78674),
  OnethsIntuitionBuff                   = Spell(209406),
  Starfall                              = Spell(191034),
  StarlordBuff                          = Spell(279709),
  NewMoon                               = Spell(274281),
  HalfMoon                              = Spell(274282),
  FullMoon                              = Spell(274283),
  WarriorofEluneBuff                    = Spell(202425),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  WarriorofElune                        = Spell(202425),
  SunblazeBuff                          = Spell(274399),
  OwlkinFrenzyBuff                      = Spell(157228),
  SolarBeam                             = Spell(78675),
};
local S = Spell.Druid.Balance;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Balance = {
  ProlongedPower                   = Item(142117),
  TheEmeraldDreamcatcher           = Item(137062)
};
local I = Item.Druid.Balance;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Balance = HR.GUISettings.APL.Druid.Balance
};

-- Variables

local EnemyRanges = {40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function FutureAstralPower()
  local AstralPower=Player:AstralPower()
  if not Player:IsCasting() then
    return AstralPower
  else
    if Player:IsCasting(S.NewnMoon) then
      return AstralPower + 10
    elseif Player:IsCasting(S.HalfMoon) then
      return AstralPower + 20
    elseif Player:IsCasting(S.FullMoon) then
      return AstralPower + 40
    elseif Player:IsCasting(S.StellarFlare) then
      return AstralPower + 8
    elseif Player:IsCasting(S.SolarWrath) then
      return AstralPower + 8
    elseif Player:IsCasting(S.LunarStrike) then
      return AstralPower + 12
    else
      return AstralPower
    end
  end
end

local function SuggestCycleDot(DoTSpell, DoTEvaluation, DoTMinTTD)
  local BestUnit, BestUnitTTD = nil, DoTMinTTD;
  local TargetGUID = Target:GUID();
  for _, CycleUnit in pairs(Cache.Enemies[40]) do
    if CycleUnit:GUID() ~= TargetGUID and Everyone.UnitIsCycleValid(CycleUnit, BestUnitTTD, -CycleUnit:DebuffRemainsP(DoTSpell)) and DoTEvaluation(CycleUnit) then
      BestUnit, BestUnitTTD = CycleUnit, CycleUnit:TimeToDie();
    end
  end
  if BestUnit then
    HR.CastLeftNameplate(BestUnit, DoTSpell);
  end
end

local function Precombat ()
  -- moonkin_form
  if S.MoonkinForm:IsCastableP() and not Player:Buff(S.MoonkinForm) then
    if HR.Cast(S.MoonkinForm) then return ""; end
  end
  -- potion
  if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
    if HR.CastSuggested(I.ProlongedPower) then return ""; end
  end
  -- solar_wrath
  if S.SolarWrath:IsCastableP() and not Player:IsCasting(S.SolarWrath) then
    if HR.Cast(S.SolarWrath) then return ""; end
  end
  -- sunfire
  if S.Sunfire:IsCastableP() and (true) then
    if HR.Cast(S.Sunfire) then return ""; end
  end
end

local function CDs ()
  -- potion,if=buff.celestial_alignment.up|buff.incarnation.up
  if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) then
    if HR.CastSuggested(I.ProlongedPower) then return ""; end
  end
  -- blood_fury,if=buff.celestial_alignment.up|buff.incarnation.up
  if S.BloodFury:IsCastableP() and HR.CDsON() and (Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- berserking,if=buff.celestial_alignment.up|buff.incarnation.up
  if S.Berserking:IsCastableP() and HR.CDsON() and (Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- arcane_torrent,if=buff.celestial_alignment.up|buff.incarnation.up
  if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- lights_judgment,if=buff.celestial_alignment.up|buff.incarnation.up
  if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastableP() and not Player:Buff(S.WarriorofElune) then
    if HR.Cast(S.WarriorofElune, Settings.Balance.GCDasOffGcd.WarriorOfElune) then return ""; end
  end
  -- TODO(mrdmnd / synecdoche): INNERVATE here if azerite.lively_spirit and incarn is up or C.A cooldown is < 12 s
  -- incarnation,if=astral_power>=40
  if S.Incarnation:IsCastableP() and (FutureAstralPower() >= 40) then
    if HR.Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CelestialAlignment) then return ""; end
  end
  -- celestial_alignment,if=astral_power>=40
  if S.CelestialAlignment:IsCastableP() and (FutureAstralPower() >= 40) then
    if HR.Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CelestialAlignment) then return ""; end
  end
  -- fury_of_elune,if=(buff.celestial_alignment.up|buff.incarnation.up)|(cooldown.celestial_alignment.remains>30|cooldown.incarnation.remains>30)
  if S.FuryofElune:IsCastableP() and ((Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) or (S.CelestialAlignment:CooldownRemainsP() > 30 or S.Incarnation:CooldownRemainsP() > 30)) then
    if HR.Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune) then return ""; end
  end
  -- force_of_nature,if=(buff.celestial_alignment.up|buff.incarnation.up)|(cooldown.celestial_alignment.remains>30|cooldown.incarnation.remains>30)
  if S.ForceofNature:IsCastableP() and ((Player:BuffP(S.CelestialAlignmentBuff) or Player:BuffP(S.IncarnationBuff)) or (S.CelestialAlignment:CooldownRemainsP() > 30 or S.Incarnation:CooldownRemainsP() > 30)) then
    if HR.Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return ""; end
  end
end

local function Dot ()
-- TODO(mrdmnd): add conditions on azerite traits
-- Code largely lifted from assassination implmentation.
--actions+=/sunfire,
--          target_if=refreshable|(variable.az_hn=3&active_enemies<=2&(dot.moonfire.ticking|time_to_die<=6.6)&(!talent.stellar_flare.enabled|dot.stellar_flare.ticking|time_to_die<=7.2)&astral_power<40),
--          if=astral_power.deficit>=7&target.time_to_die>5.4&(!buff.celestial_alignment.up&!buff.incarnation.up|!variable.az_streak|!prev_gcd.1.sunfire)|variable.az_hn=3
--actions+=/moonfire,
--          target_if=refreshable,
--          if=astral_power.deficit>=7&target.time_to_die>6.6&(!buff.celestial_alignment.up&!buff.incarnation.up|!variable.az_streak|!prev_gcd.1.moonfire)
--actions+=/stellar_flare,
--          target_if=refreshable,
--          if=astral_power.deficit>=12&target.time_to_die>7.2&(!buff.celestial_alignment.up&!buff.incarnation.up|!variable.az_streak|!prev_gcd.1.stellar_flare)
  local function Evaluate_Sunfire_Target(TargetUnit)
    return TargetUnit:DebuffRefreshableCP(S.SunfireDebuff) and Target:TimeToDie() > 5.4
  end
  local function Evaluate_Moonfire_Target(TargetUnit)
    return TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff) and Target:TimeToDie() > 6.6
  end
  local function Evaluate_StellarFlare_Target(TargetUnit)
    return TargetUnit:DebuffRefreshableCP(S.StellarFlare) and Target:TimeToDie() > 7.2
  end

  -- main target refreshes
  if Evaluate_Sunfire_Target(Target) then
    if HR.Cast(S.Sunfire) then return ""; end
  end
  if Evaluate_Moonfire_Target(Target) then
    if HR.Cast(S.Moonfire) then return ""; end
  end
  if S.StellarFlare:IsCastableP() and Evaluate_StellarFlare_Target(Target) then
    if HR.Cast(S.StellarFlare) then return ""; end
  end

  local ttdval = 12
  SuggestCycleDot(S.Sunfire, Evaluate_Sunfire_Target, ttdval)
  SuggestCycleDot(S.Moonfire, Evaluate_Moonfire_Target, ttdval)
  if S.StellarFlare:IsCastableP() then
    SuggestCycleDot(S.StellarFlare, Evaluate_StellarFlare_Target, ttdval)
  end
end

local function EmpowermentCapCheck ()
-- TODO(mrdmnd) - add conditions on azerite traits
--actions+=/lunar_strike,
--          if=astral_power.deficit>=16&
--          (buff.lunar_empowerment.stack=3|(spell_targets<3 & astral_power>=40 & (buff.lunar_empowerment.stack=2&buff.solar_empowerment.stack=2)))&
--          !(variable.az_hn=3&active_enemies=1)&
--          !(spell_targets.moonfire>=2&variable.az_potm=3&active_enemies=2)
--actions+=/solar_wrath,
--          if=astral_power.deficit>=12&
--          (buff.solar_empowerment.stack=3|(variable.az_sb>1&spell_targets.starfall<3&astral_power>=32&!buff.sunblaze.up))&
--          !(variable.az_hn=3&active_enemies=1)&
--          !(spell_targets.moonfire>=2&active_enemies<=4&variable.az_potm=3)
  if S.LunarStrike:IsCastableP() and Player:AstralPowerDeficit() >= 16 and (Player:BuffStackP(S.LunarEmpowermentBuff) == 3 or (Cache.EnemiesCount[40] < 3 and Player:AstralPower() >= 40 and Player:BuffStackP(S.LunarEmpowermentBuff) == 2 and Player:BuffStack(S.SolarEmpowermentBuff) == 2)) then
    if HR.Cast(S.LunarStrike) then return "Lunar Strike at Cap"; end
  end

  if S.SolarWrath:IsCastableP() and Player:AstralPowerDeficit() >= 12 and (Player:BuffStackP(S.SolarEmpowermentBuff) == 3) then
    if HR.Cast(S.SolarWrath) then return "Solar Wrath at Cap"; end
  end
end

local function CoreRotation ()
-- TODO(mrdmnd): Implement conditionals on azerite traits. For now, assume all vairable.az_WHATEVER evaluates to zero.
-- actions+=/starsurge,if=(spell_targets.starfall<3&(!buff.starlord.up|buff.starlord.remains>=4)|execute_time*(astral_power%40)>target.time_to_die)&(!buff.celestial_alignment.up&!buff.incarnation.up|variable.az_streak<2|!prev_gcd.1.starsurge)
-- actions+=/starfall,if=spell_targets.starfall>=3&(!buff.starlord.up|buff.starlord.remains>=4)
-- actions+=/new_moon,if=astral_power.deficit>10+execute_time%1.5
-- actions+=/half_moon,if=astral_power.deficit>20+execute_time%1.5
-- actions+=/full_moon,if=astral_power.deficit>40+execute_time%1.5
-- actions+=/lunar_strike,if=((buff.warrior_of_elune.up|buff.lunar_empowerment.up|spell_targets>=3&!buff.solar_empowerment.up)&(!buff.celestial_alignment.up&!buff.incarnation.up|variable.az_streak<2|!prev_gcd.1.lunar_strike)|(variable.az_ds&!buff.dawning_sun.up))&!(spell_targets.moonfire>=2&active_enemies<=4&(variable.az_potm=3|variable.az_potm=2&active_enemies=2))
-- actions+=/solar_wrath,if=(!buff.celestial_alignment.up&!buff.incarnation.up|variable.az_streak<2|!prev_gcd.1.solar_wrath)&!(spell_targets.moonfire>=2&active_enemies<=4&(variable.az_potm=3|variable.az_potm=2&active_enemies=2))
-- actions+=/sunfire,if=(!buff.celestial_alignment.up&!buff.incarnation.up|!variable.az_streak|!prev_gcd.1.sunfire)&!(variable.az_potm>=2&spell_targets.moonfire>=2)
-- actions+=/moonfire
  if S.Starsurge:IsCastableP() and Cache.EnemiesCount[40] < 3 and (not Player:BuffP(S.StarlordBuff) or Player:BuffRemainsP(S.StarlordBuff) >= 4 or (Player:GCD() * (FutureAstralPower() / 40)) > Target:TimeToDie()) and FutureAstralPower() >= 40 then
    if HR.Cast(S.Starsurge) then return ""; end
  end
  if S.Starfall:IsCastableP() and Cache.EnemiesCount[40] >= 3 and (not Player:BuffP(S.StarlordBuff) or Player:BuffRemainsP(S.StarlordBuff) >= 4) and FutureAstralPower() >= 50 then
    if HR.Cast(S.Starfall) then return ""; end
  end
  if S.NewMoon:IsCastableP() and (Player:AstralPowerDeficit() > 10 + (Player:GCD() / 1.5)) then
    if HR.Cast(S.NewMoon) then return ""; end
  end
  if S.HalfMoon:IsCastableP() and (Player:AstralPowerDeficit() > 20+ (Player:GCD() / 1.5)) then
    if HR.Cast(S.HalfMoon) then return ""; end
  end
  if S.FullMoon:IsCastableP() and (Player:AstralPowerDeficit() > 40+ (Player:GCD() / 1.5)) then
    if HR.Cast(S.FullMoon) then return ""; end
  end
  -- Lunar strike when warrior of elune or OwlkinFrenzy is up
  if S.LunarStrike:IsCastableP() and (Player:BuffP(S.WarriorofEluneBuff) or Player:BuffP(S.OwlkinFrenzyBuff)) then
    if HR.Cast(S.LunarStrike) then return ""; end
  end
  -- don't suggest an empowered cast if we're casting the last empowered stack
  -- bad assumption: detects cleave targets based on 20yds from caster, centered. cannot do clump detection, i am not clever enough yet
  if (Cache.EnemiesCount[40] >= 2) then
    -- Cleave situation: prioritize lunar strike empower > solar wrath empower > lunar strike
    if S.LunarStrike:IsCastableP() and Player:BuffP(S.LunarEmpowermentBuff) and not (Player:BuffStackP(S.LunarEmpowermentBuff) == 1 and Player:IsCasting(S.LunarStrike)) then
      if HR.Cast(S.LunarStrike) then return ""; end
    end
    if S.SolarWrath:IsCastableP() and Player:BuffP(S.SolarEmpowermentBuff) and not (Player:BuffStackP(S.SolarEmpowermentBuff) == 1 and Player:IsCasting(S.SolarWrath)) then
      if HR.Cast(S.SolarWrath) then return ""; end
    end
    if S.LunarStrike:IsCastableP() and (true) then
      if HR.Cast(S.LunarStrike) then return ""; end
    end
  else
    -- ST situation: prioritize solar wrath empower > lunar strike empower > solar wrath
    if S.SolarWrath:IsCastableP() and Player:BuffP(S.SolarEmpowermentBuff) and not (Player:BuffStackP(S.SolarEmpowermentBuff) == 1 and Player:IsCasting(S.SolarWrath)) then
      if HR.Cast(S.SolarWrath) then return ""; end
    end
    if S.LunarStrike:IsCastableP() and Player:BuffP(S.LunarEmpowermentBuff) and not (Player:BuffStackP(S.LunarEmpowermentBuff) == 1 and Player:IsCasting(S.LunarStrike)) then
      if HR.Cast(S.LunarStrike) then return ""; end
    end
    if S.SolarWrath:IsCastableP() and (true) then
      if HR.Cast(S.SolarWrath) then return ""; end
    end
  end

  if S.Moonfire:IsCastableP() and (true) then
    if HR.Cast(S.Moonfire) then return ""; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()

  if not Player:AffectingCombat() then
    ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end

  Everyone.Interrupt(5, S.SolarBeam, Settings.Commons.OffGCDasOffGCD.SolarBeam, Interrupts);

  if HR.CDsON() then
    ShouldReturn = CDs();
    if ShouldReturn then return ShouldReturn; end
  end

  ShouldReturn = Dot();
  if ShouldReturn then return ShouldReturn; end

  ShouldReturn = EmpowermentCapCheck();
  if ShouldReturn then return ShouldReturn; end

  ShouldReturn = CoreRotation();
  if ShouldReturn then return ShouldReturn; end
end

HR.SetAPL(102, APL)
