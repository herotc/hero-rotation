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
  StreakingStars                        = Spell(272871),
  ArcanicPulsarBuff                     = Spell(287790),
  ArcanicPulsar                         = Spell(287773),
  StarlordBuff                          = Spell(279709),
  Starlord                              = Spell(202345),
  TwinMoons                             = Spell(279620),
  MoonkinForm                           = Spell(24858),
  SolarWrath                            = Spell(190984),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  WarriorofElune                        = Spell(202425),
  Innervate                             = Spell(29166),
  LivelySpirit                          = Spell(279642),
  Incarnation                           = Spell(102560),
  CelestialAlignment                    = Spell(194223),
  SunfireDebuff                         = Spell(164815),
  MoonfireDebuff                        = Spell(164812),
  StellarFlareDebuff                    = Spell(202347),
  StellarFlare                          = Spell(202347),
  LivelySpiritBuff                      = Spell(279646),
  FuryofElune                           = Spell(202770),
  ForceofNature                         = Spell(205636),
  Starfall                              = Spell(191034),
  Starsurge                             = Spell(78674),
  LunarEmpowermentBuff                  = Spell(164547),
  SolarEmpowermentBuff                  = Spell(164545),
  Sunfire                               = Spell(93402),
  Moonfire                              = Spell(8921),
  NewMoon                               = Spell(274281),
  HalfMoon                              = Spell(274282),
  FullMoon                              = Spell(274283),
  LunarStrike                           = Spell(194153),
  WarriorofEluneBuff                    = Spell(202425),
  ShootingStars                         = Spell(202342),
  NaturesBalance                        = Spell(202430)
};
local S = Spell.Druid.Balance;

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Balance = {
  BattlePotionofIntellect          = Item(163222),
  BalefireBranch                   = Item(159630),
  DreadGladiatorsBadge             = Item(161902),
  AzurethosSingedPlumage           = Item(161377),
  TidestormCodex                   = Item(165576)
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
local VarAzSs = 0;
local VarAzAp = 0;
local VarSfTargets = 0;

HL:RegisterForEvent(function()
  VarAzSs = 0
  VarAzAp = 0
  VarSfTargets = 0
end, "PLAYER_REGEN_ENABLED")

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
    if Player:IsCasting(S.NewMoon) then
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

local function CaInc()
  return S.Incarnation:IsAvailable() and S.Incarnation or S.CelestialAlignment
end

local function AP_Check(spell)
  local APGen = 0
  local CurAP = Player:AstralPower()
  if spell == S.Sunfire or spell == S.Moonfire then 
    APGen = 3
  elseif spell == S.StellarFlare or spell == S.SolarWrath then
    APGen = 8
  elseif spell == S.Incarnation or spell == S.CelestialAlignment then
    APGen = 40
  elseif spell == S.ForceofNature then
    APGen = 20
  elseif spell == S.LunarStrike then
    APGen = 12
  end
  
  if S.ShootingStars:IsAvailable() then 
    APGen = APGen + 4
  end
  if S.NaturesBalance:IsAvailable() then
    APGen = APGen + 2
  end
  
  if CurAP + APGen < Player:AstralPowerMax() then
    return true
  else
    return false
  end
end

local function EvaluateCycleSunfire250(TargetUnit)
  return (TargetUnit:DebuffRefreshableCP(S.SunfireDebuff)) and (AP_Check(S.Sunfire) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) * Cache.EnemiesCount[40] >= math.ceil (math.floor (2 / Cache.EnemiesCount[40]) * 1.5) + 2 * Cache.EnemiesCount[40] and (Cache.EnemiesCount[40] > 1 + num(S.TwinMoons:IsAvailable()) or TargetUnit:DebuffP(S.MoonfireDebuff)) and (not bool(VarAzSs) or not Player:BuffP(CaInc()) or not PrevGCDP(1, S.Sunfire)) and (Player:BuffRemainsP(CaInc()) > TargetUnit:DebuffRemainsP(S.SunfireDebuff) or not Player:BuffP(CaInc())))
end

local function EvaluateCycleMoonfire313(TargetUnit)
  return (TargetUnit:DebuffRefreshableCP(S.MoonfireDebuff)) and (AP_Check(S.Moonfire) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) * Cache.EnemiesCount[40] >= 6 and (not bool(VarAzSs) or not Player:BuffP(CaInc()) or not PrevGCDP(1, S.Moonfire)) and (Player:BuffRemainsP(CaInc()) > TargetUnit:DebuffRemainsP(S.MoonfireDebuff) or not Player:BuffP(CaInc())))
end

local function EvaluateCycleStellarFlare348(TargetUnit)
  return (TargetUnit:DebuffRefreshableCP(S.StellarFlareDebuff)) and (AP_Check(S.StellarFlare) and math.floor (TargetUnit:TimeToDie() / (2 * Player:SpellHaste())) >= 5 and (not bool(VarAzSs) or not Player:BuffP(CaInc()) or not PrevGCDP(1, S.StellarFlare)) and not Player:IsCasting(S.StellarFlare))
end

--- ======= ACTION LISTS =======
local function APL()
  local Precombat
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- variable,name=az_ss,value=azerite.streaking_stars.rank
    if (true) then
      VarAzSs = S.StreakingStars:AzeriteRank()
    end
    -- variable,name=az_ap,value=azerite.arcanic_pulsar.rank
    if (true) then
      VarAzAp = S.ArcanicPulsar:AzeriteRank()
    end
    -- variable,name=sf_targets,value=4
    if (true) then
      VarSfTargets = 4
    end
    -- variable,name=sf_targets,op=add,value=1,if=azerite.arcanic_pulsar.enabled
    if (S.ArcanicPulsar:AzeriteEnabled()) then
      VarSfTargets = VarSfTargets + 1
    end
    -- variable,name=sf_targets,op=add,value=1,if=talent.starlord.enabled
    if (S.Starlord:IsAvailable()) then
      VarSfTargets = VarSfTargets + 1
    end
    -- variable,name=sf_targets,op=add,value=1,if=azerite.streaking_stars.rank>2&azerite.arcanic_pulsar.enabled
    if (S.StreakingStars:AzeriteRank() > 2 and S.ArcanicPulsar:AzeriteEnabled()) then
      VarSfTargets = VarSfTargets + 1
    end
    -- variable,name=sf_targets,op=sub,value=1,if=!talent.twin_moons.enabled
    if (not S.TwinMoons:IsAvailable()) then
      VarSfTargets = VarSfTargets - 1
    end
    -- moonkin_form
    if S.MoonkinForm:IsCastableP() and not Player:Buff(S.MoonkinForm) then
      if HR.Cast(S.MoonkinForm) then return "moonkin_form 39"; end
    end
    -- snapshot_stats
    -- potion
    if I.BattlePotionofIntellect:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.BattlePotionofIntellect) then return "battle_potion_of_intellect 42"; end
    end
    -- solar_wrath
    if S.SolarWrath:IsCastableP() and not Player:IsCasting(S.SolarWrath) then
      if HR.Cast(S.SolarWrath) then return "solar_wrath 44"; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and Everyone.TargetIsValid() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- potion,if=buff.ca_inc.remains>6&active_enemies=1
    if I.BattlePotionofIntellect:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(CaInc()) > 6 and Cache.EnemiesCount[40] == 1) then
      if HR.CastSuggested(I.BattlePotionofIntellect) then return "battle_potion_of_intellect 47"; end
    end
    -- potion,name=battle_potion_of_intellect,if=buff.ca_inc.remains>6
    if I.BattlePotionofIntellect:IsReady() and Settings.Commons.UsePotions and (Player:BuffRemainsP(CaInc()) > 6) then
      if HR.CastSuggested(I.BattlePotionofIntellect) then return "battle_potion_of_intellect 57"; end
    end
    -- blood_fury,if=buff.ca_inc.up
    if S.BloodFury:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 61"; end
    end
    -- berserking,if=buff.ca_inc.up
    if S.Berserking:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 65"; end
    end
    -- arcane_torrent,if=buff.ca_inc.up
    if S.ArcaneTorrent:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent 69"; end
    end
    -- lights_judgment,if=buff.ca_inc.up
    if S.LightsJudgment:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.LightsJudgment) then return "lights_judgment 73"; end
    end
    -- fireblood,if=buff.ca_inc.up
    if S.Fireblood:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 77"; end
    end
    -- ancestral_call,if=buff.ca_inc.up
    if S.AncestralCall:IsCastableP() and HR.CDsON() and (Player:BuffP(CaInc())) then
      if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 81"; end
    end
    -- use_item,name=balefire_branch,if=equipped.159630&cooldown.ca_inc.remains>30
    if I.BalefireBranch:IsReady() and (I.BalefireBranch:IsEquipped() and CaInc():CooldownRemainsP() > 30) then
      if HR.CastSuggested(I.BalefireBranch) then return "balefire_branch 85"; end
    end
    -- use_item,name=dread_gladiators_badge,if=equipped.161902&cooldown.ca_inc.remains>30
    if I.DreadGladiatorsBadge:IsReady() and (I.DreadGladiatorsBadge:IsEquipped() and CaInc():CooldownRemainsP() > 30) then
      if HR.CastSuggested(I.DreadGladiatorsBadge) then return "dread_gladiators_badge 91"; end
    end
    -- use_item,name=azurethos_singed_plumage,if=equipped.161377&cooldown.ca_inc.remains>30
    if I.AzurethosSingedPlumage:IsReady() and (I.AzurethosSingedPlumage:IsEquipped() and CaInc():CooldownRemainsP() > 30) then
      if HR.CastSuggested(I.AzurethosSingedPlumage) then return "azurethos_singed_plumage 97"; end
    end
    -- use_item,name=tidestorm_codex,if=equipped.165576
    if I.TidestormCodex:IsReady() and (I.TidestormCodex:IsEquipped()) then
      if HR.CastSuggested(I.TidestormCodex) then return "tidestorm_codex 103"; end
    end
    -- use_items,if=cooldown.ca_inc.remains>30
    -- warrior_of_elune
    if S.WarriorofElune:IsCastableP() then
      if HR.Cast(S.WarriorofElune) then return "warrior_of_elune 108"; end
    end
    -- innervate,if=azerite.lively_spirit.enabled&(cooldown.incarnation.remains<2|cooldown.celestial_alignment.remains<12)
    if S.Innervate:IsCastableP() and (S.LivelySpirit:AzeriteEnabled() and (S.Incarnation:CooldownRemainsP() < 2 or S.CelestialAlignment:CooldownRemainsP() < 12)) then
      if HR.Cast(S.Innervate) then return "innervate 110"; end
    end
    -- incarnation,if=dot.sunfire.remains>8&dot.moonfire.remains>12&(dot.stellar_flare.remains>6|!talent.stellar_flare.enabled)&ap_check&!buff.ca_inc.up
    if S.Incarnation:IsCastableP() and (Target:DebuffRemainsP(S.SunfireDebuff) > 8 and Target:DebuffRemainsP(S.MoonfireDebuff) > 12 and (Target:DebuffRemainsP(S.StellarFlareDebuff) > 6 or not S.StellarFlare:IsAvailable()) and AP_Check(S.Incarnation) and not Player:BuffP(CaInc())) then
      if HR.Cast(S.Incarnation) then return "incarnation 118"; end
    end
    -- celestial_alignment,if=astral_power>=40&!buff.ca_inc.up&ap_check&(!azerite.lively_spirit.enabled|buff.lively_spirit.up)&(dot.sunfire.remains>2&dot.moonfire.ticking&(dot.stellar_flare.ticking|!talent.stellar_flare.enabled))
    if S.CelestialAlignment:IsCastableP() and (FutureAstralPower() >= 40 and not Player:BuffP(CaInc()) and AP_Check(S.CelestialAlignment) and (not S.LivelySpirit:AzeriteEnabled() or Player:BuffP(S.LivelySpiritBuff)) and (Target:DebuffRemainsP(S.SunfireDebuff) > 2 and Target:DebuffP(S.MoonfireDebuff) and (Target:DebuffP(S.StellarFlareDebuff) or not S.StellarFlare:IsAvailable()))) then
      if HR.Cast(S.CelestialAlignment) then return "celestial_alignment 130"; end
    end
    -- fury_of_elune,if=(buff.ca_inc.up|cooldown.ca_inc.remains>30)&solar_wrath.ap_check
    if S.FuryofElune:IsCastableP() and ((Player:BuffP(CaInc()) or CaInc():CooldownRemainsP() > 30) and AP_Check(S.SolarWrath)) then
      if HR.Cast(S.FuryofElune) then return "fury_of_elune 146"; end
    end
    -- force_of_nature,if=(buff.ca_inc.up|cooldown.ca_inc.remains>30)&ap_check
    if S.ForceofNature:IsCastableP() and ((Player:BuffP(CaInc()) or CaInc():CooldownRemainsP() > 30) and AP_Check(S.ForceofNature)) then
      if HR.Cast(S.ForceofNature) then return "force_of_nature 152"; end
    end
    -- cancel_buff,name=starlord,if=buff.starlord.remains<3&!solar_wrath.ap_check
    -- if (Player:BuffRemainsP(S.StarlordBuff) < 3 and not bool(solar_wrath.ap_check)) then
      -- if HR.Cancel(S.StarlordBuff) then return ""; end
    -- end
    -- starfall,if=(buff.starlord.stack<3|buff.starlord.remains>=8)&spell_targets>=variable.sf_targets&(target.time_to_die+1)*spell_targets>cost%2.5
    if S.Starfall:IsCastableP() and ((Player:BuffStackP(S.StarlordBuff) < 3 or Player:BuffRemainsP(S.StarlordBuff) >= 8) and Cache.EnemiesCount[40] >= VarSfTargets and (Target:TimeToDie() + 1) * Cache.EnemiesCount[40] > S.Starfall:Cost() / 2.5) then
      if HR.Cast(S.Starfall) then return "starfall 164"; end
    end
    -- starsurge,if=(talent.starlord.enabled&(buff.starlord.stack<3|buff.starlord.remains>=5&buff.arcanic_pulsar.stack<8)|!talent.starlord.enabled&(buff.arcanic_pulsar.stack<8|buff.ca_inc.up))&spell_targets.starfall<variable.sf_targets&buff.lunar_empowerment.stack+buff.solar_empowerment.stack<4&buff.solar_empowerment.stack<3&buff.lunar_empowerment.stack<3&(!variable.az_ss|!buff.ca_inc.up|!prev.starsurge)|target.time_to_die<=execute_time*astral_power%40|!solar_wrath.ap_check
    if S.Starsurge:IsCastableP() and ((S.Starlord:IsAvailable() and (Player:BuffStackP(S.StarlordBuff) < 3 or Player:BuffRemainsP(S.StarlordBuff) >= 5 and Player:BuffStackP(S.ArcanicPulsarBuff) < 8) or not S.Starlord:IsAvailable() and (Player:BuffStackP(S.ArcanicPulsarBuff) < 8 or Player:BuffP(CaInc()))) and Cache.EnemiesCount[40] < VarSfTargets and Player:BuffStackP(S.LunarEmpowermentBuff) + Player:BuffStackP(S.SolarEmpowermentBuff) < 4 and Player:BuffStackP(S.SolarEmpowermentBuff) < 3 and Player:BuffStackP(S.LunarEmpowermentBuff) < 3 and (not bool(VarAzSs) or not Player:BuffP(CaInc()) or not PrevGCDP(1, S.Starsurge)) or Target:TimeToDie() <= S.Starsurge:ExecuteTime() * FutureAstralPower() / 40 or not AP_Check(S.SolarWrath)) then
      if HR.Cast(S.Starsurge) then return "starsurge 188"; end
    end
    -- sunfire,if=buff.ca_inc.up&buff.ca_inc.remains<gcd.max&variable.az_ss&dot.moonfire.remains>remains
    if S.Sunfire:IsCastableP() and (Player:BuffP(CaInc()) and Player:BuffRemainsP(CaInc()) < Player:GCD() and bool(VarAzSs) and Target:DebuffRemainsP(S.MoonfireDebuff) > Target:DebuffRemainsP(S.SunfireDebuff)) then
      if HR.Cast(S.Sunfire) then return "sunfire 222"; end
    end
    -- moonfire,if=buff.ca_inc.up&buff.ca_inc.remains<gcd.max&variable.az_ss
    if S.Moonfire:IsCastableP() and (Player:BuffP(CaInc()) and Player:BuffRemainsP(CaInc()) < Player:GCD() and bool(VarAzSs)) then
      if HR.Cast(S.Moonfire) then return "moonfire 238"; end
    end
    -- sunfire,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))*spell_targets>=ceil(floor(2%spell_targets)*1.5)+2*spell_targets&(spell_targets>1+talent.twin_moons.enabled|dot.moonfire.ticking)&(!variable.az_ss|!buff.ca_inc.up|!prev.sunfire)&(buff.ca_inc.remains>remains|!buff.ca_inc.up)
    if S.Sunfire:IsCastableP() then
      if HR.CastCycle(S.Sunfire, 40, EvaluateCycleSunfire250) then return "sunfire 308" end
    end
    -- moonfire,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))*spell_targets>=6&(!variable.az_ss|!buff.ca_inc.up|!prev.moonfire)&(buff.ca_inc.remains>remains|!buff.ca_inc.up)
    if S.Moonfire:IsCastableP() then
      if HR.CastCycle(S.Moonfire, 40, EvaluateCycleMoonfire313) then return "moonfire 343" end
    end
    -- stellar_flare,target_if=refreshable,if=ap_check&floor(target.time_to_die%(2*spell_haste))>=5&(!variable.az_ss|!buff.ca_inc.up|!prev.stellar_flare)
    if S.StellarFlare:IsCastableP() then
      if HR.CastCycle(S.StellarFlare, 40, EvaluateCycleStellarFlare348) then return "stellar_flare 360" end
    end
    -- new_moon,if=ap_check
    if S.NewMoon:IsCastableP() and (AP_Check(S.NewMoon)) then
      if HR.Cast(S.NewMoon) then return "new_moon 361"; end
    end
    -- half_moon,if=ap_check
    if S.HalfMoon:IsCastableP() and (AP_Check(S.HalfMoon)) then
      if HR.Cast(S.HalfMoon) then return "half_moon 363"; end
    end
    -- full_moon,if=ap_check
    if S.FullMoon:IsCastableP() and (AP_Check(S.FullMoon)) then
      if HR.Cast(S.FullMoon) then return "full_moon 365"; end
    end
    -- lunar_strike,if=buff.solar_empowerment.stack<3&(ap_check|buff.lunar_empowerment.stack=3)&((buff.warrior_of_elune.up|buff.lunar_empowerment.up|spell_targets>=2&!buff.solar_empowerment.up)&(!variable.az_ss|!buff.ca_inc.up)|variable.az_ss&buff.ca_inc.up&prev.solar_wrath)
    if S.LunarStrike:IsCastableP() and (Player:BuffStackP(S.SolarEmpowermentBuff) < 3 and (AP_Check(S.LunarStrike) or Player:BuffStackP(S.LunarEmpowermentBuff) == 3) and ((Player:BuffP(S.WarriorofEluneBuff) or Player:BuffP(S.LunarEmpowermentBuff) or Cache.EnemiesCount[40] >= 2 and not Player:BuffP(S.SolarEmpowermentBuff)) and (not bool(VarAzSs) or not Player:BuffP(CaInc())) or bool(VarAzSs) and Player:BuffP(CaInc()) and PrevGCDP(1, S.SolarWrath))) then
      if HR.Cast(S.LunarStrike) then return "lunar_strike 367"; end
    end
    -- solar_wrath,if=variable.az_ss<3|!buff.ca_inc.up|!prev.solar_wrath
    if S.SolarWrath:IsCastableP() and (VarAzSs < 3 or not Player:BuffP(CaInc()) or not PrevGCDP(1, S.SolarWrath)) then
      if HR.Cast(S.SolarWrath) then return "solar_wrath 393"; end
    end
    -- sunfire
    if S.Sunfire:IsCastableP() then
      if HR.Cast(S.Sunfire) then return "sunfire 399"; end
    end
  end
end

HR.SetAPL(102, APL)
