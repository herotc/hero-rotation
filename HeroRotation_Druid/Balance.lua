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
local Pet = Unit.Pet
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast  = HR.Cast
-- Lua
local GetCombatRating = GetCombatRating
local floor = math.floor
local ceil = math.ceil
local max = math.max

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Balance = HR.GUISettings.APL.Druid.Balance
}

-- Spells
local S = Spell.Druid.Balance

-- Items
local I = Item.Druid.Balance
local OnUseExcludes = {--  I.TrinketName:ID(),
  I.EmpyrealOrdinance:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.ShadowedOrbofTorment:ID(),
  I.SoullettingRuby:ID()
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = Item(0)
local trinket2 = Item(0)
if equip[13] then
  trinket1 = Item(equip[13])
end
if equip[14] then
  trinket2 = Item(equip[14])
end

-- Rotation Variables
local VarOnUseTrinket
local VarIsAoe
local VarIsCleave
local VarConvokeDesync
local VarCDCondition
local VarCDConditionST
local VarCDConditionAoE
local VarCDConditionBOAT
local VarDotRequirements
local VarDotOutsideEclipse
local VarSaveForCAInc
local VarDreamWillFallOff
local VarIgnoreStarsurge
local VarStarfallWontFallOff
local VarStarfireinSolar
local VarAspPerSec
local VarThrillSeekerWait
local VarIQDCondition
local VarWrathInFrenzy
local GCDMax
local PAPValue
local FuryTicksRemain
local FuryofEluneRemains
local OpenerFinished = false
local fightRemains

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- CA/Incarnation Variable
local CaInc = S.Incarnation:IsAvailable() and S.Incarnation or S.CelestialAlignment

-- Eclipse Variables
local EclipseInAny = false
local EclipseInBoth = false
local EclipseInLunar = false
local EclipseInSolar = false
local EclipseLunarNext = false
local EclipseSolarNext = false
local EclipseAnyNext = false

-- Precise Alignment Variables
local PreciseAlignmentTimeTable = { 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12 }
local PATime = S.PreciseAlignment:ConduitEnabled() and PreciseAlignmentTimeTable[S.PreciseAlignment:ConduitRank()] or 0

-- Legendaries
local PAPEquipped = Player:HasLegendaryEquipped(51)
local BOATEquipped = Player:HasLegendaryEquipped(52)
local LycaraEquipped = Player:HasLegendaryEquipped(48)
local OnethsEquipped = Player:HasLegendaryEquipped(50)
local TimewornEquipped = Player:HasLegendaryEquipped(53)
local SinfulHysteriaEquipped = Player:HasLegendaryEquipped(220)
local CelestialSpiritsEquipped = Player:HasLegendaryEquipped(226)

-- Register
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = Item(0)
  trinket2 = Item(0)
  if equip[13] then
    trinket1 = Item(equip[13])
  end
  if equip[14] then
    trinket2 = Item(equip[14])
  end
  PAPEquipped = Player:HasLegendaryEquipped(51)
  BOATEquipped = Player:HasLegendaryEquipped(52)
  LycaraEquipped = Player:HasLegendaryEquipped(48)
  OnethsEquipped = Player:HasLegendaryEquipped(50)
  TimewornEquipped = Player:HasLegendaryEquipped(53)
  SinfulHysteriaEquipped = Player:HasLegendaryEquipped(220)
  CelestialSpiritsEquipped = Player:HasLegendaryEquipped(226)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  OpenerFinished = false
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AdaptiveSwarm:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.AdaptiveSwarm:RegisterInFlight()

HL:RegisterForEvent(function()
  CaInc = S.Incarnation:IsAvailable() and S.Incarnation or S.CelestialAlignment
end, "PLAYER_TALENT_UPDATE")

-- Figure out new Precise Alignment time when changed
-- Might be using too many events, but would rather capture too many than too few
HL:RegisterForEvent(function()
  PATime = S.PreciseAlignment:ConduitEnabled() and PreciseAlignmentTimeTable[S.PreciseAlignment:ConduitRank()] or 0
end, "SOULBIND_ACTIVATED", "SOULBIND_CONDUIT_COLLECTION_UPDATED", "SOULBIND_CONDUIT_INSTALLED", "SOULBIND_NODE_UPDATED")

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Enemy Variables
local Enemies40y, EnemiesCount40y
local Enemies8ySplash, EnemiesCount8ySplash

-- Stuns

-- num/bool Functions
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- CastCycle/CastTargetIf Functions
local function EvaluateCycleSunfireFallthru(TargetUnit)
  return (TargetUnit:DebuffRemains(S.MoonfireDebuff) > (TargetUnit:DebuffRemains(S.SunfireDebuff) * 22 / 18))
end

local function EvaluateCycleAdaptiveSwarmST(TargetUnit)
  return (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() and (Player:BuffDown(S.AdaptiveSwarmHeal) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 5) or TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffUp(S.AdaptiveSwarmDebuff))
end

local function EvaluateCycleMoonfireST(TargetUnit)
  return ((Player:BuffRemains(S.EclipseSolar) > TargetUnit:DebuffRemains(S.MoonfireDebuff) or Player:BuffRemains(S.EclipseLunar) > TargetUnit:DebuffRemains(S.MoonfireDebuff) or VarDotOutsideEclipse) and TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12)
end

local function EvaluateCycleSunfireST(TargetUnit)
  return ((Player:BuffRemains(S.EclipseSolar) > TargetUnit:DebuffRemains(S.SunfireDebuff) or Player:BuffRemains(S.EclipseLunar) > TargetUnit:DebuffRemains(S.SunfireDebuff) or VarDotOutsideEclipse) and TargetUnit:DebuffRefreshable(S.SunfireDebuff) and TargetUnit:TimeToDie() > 12)
end

local function EvaluateCycleStellarFlareST(TargetUnit)
  return ((Player:BuffRemains(S.EclipseSolar) > TargetUnit:DebuffRemains(S.StellarFlareDebuff) or Player:BuffRemains(S.EclipseLunar) > TargetUnit:DebuffRemains(S.StellarFlareDebuff) or VarDotOutsideEclipse) and TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and TargetUnit:TimeToDie() > 16)
end

local function EvaluateCycleSunfireAoe(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.SunfireDebuff) or Player:BuffRemains(S.EclipseSolar) < 3 and EclipseInSolar and TargetUnit:DebuffRemains(S.SunfireDebuff) < 14 and S.SouloftheForest:IsAvailable()) and TargetUnit:TimeToDie() > 14 - EnemiesCount8ySplash + TargetUnit:DebuffRemains(S.SunfireDebuff) and (EclipseInAny or TargetUnit:DebuffRemains(S.SunfireDebuff) < GCDMax))
end

local function EvaluateCycleAdaptiveSwarmAoe(TargetUnit)
  return (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() or TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 3)
end

local function EvaluateCycleMoonfireAoe(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > ((14 + (EnemiesCount8ySplash * 2 * num(Player:BuffUp(S.EclipseLunar)))) + TargetUnit:DebuffRemains(S.MoonfireDebuff)) / (1 + num(S.TwinMoons:IsAvailable())))
end

local function EvaluateCycleStellarFlareAoe(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and TargetUnit:TimeToDie() > 15)
end

local function EvaluateCycleSunfireBOAT(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and TargetUnit:TimeToDie() > 16)
end

local function EvaluateCycleMoonfireBOAT(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 13.5)
end

local function EvaluateCycleStellarFlareBOAT(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and TargetUnit:TimeToDie() > (16 + TargetUnit:DebuffRemains(S.StellarFlareDebuff)))
end

-- Other Functions
local function EclipseCheck()
  EclipseInAny = (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar))
  EclipseInBoth = (Player:BuffUp(S.EclipseSolar) and Player:BuffUp(S.EclipseLunar))
  EclipseInLunar = (Player:BuffUp(S.EclipseLunar) and Player:BuffDown(S.EclipseSolar))
  EclipseInSolar = (Player:BuffUp(S.EclipseSolar) and Player:BuffDown(S.EclipseLunar))
  EclipseLunarNext = (not EclipseInAny and (S.Starfire:Count() == 0 and S.Wrath:Count() > 0 or Player:IsCasting(S.Wrath))) or EclipseInSolar
  EclipseSolarNext = (not EclipseInAny and (S.Wrath:Count() == 0 and S.Starfire:Count() > 0 or Player:IsCasting(S.Starfire))) or EclipseInLunar
  EclipseAnyNext = (not EclipseInAny and S.Wrath:Count() > 0 and S.Starfire:Count() > 0)
end

local function AP_Check(spell)
  local APGen = 0
  local CurAP = Player:AstralPowerP()

  if spell == S.Sunfire or spell == S.Moonfire then
    APGen = 2
  elseif spell == S.StellarFlare or spell == S.Starfire then
    APGen = 8
  elseif spell == S.Wrath or spell == S.FuryofElune then
    APGen = 6
  elseif spell == S.ForceofNature or spell == S.HalfMoon then
    APGen = 20
  elseif spell == S.NewMoon then
    APGen = 10
  elseif spell == S.FullMoon then
    APGen = 40
  end

  if S.NaturesBalance:IsAvailable() then
    APGen = APGen + 1
  end

  if CurAP + APGen < Player:AstralPowerMax() then
    return true
  else
    return false
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=on_use_trinket,value=0
  VarOnUseTrinket = 0
  -- variable,name=on_use_trinket,op=add,value=trinket.1.has_proc.any&trinket.1.cooldown.duration
  VarOnUseTrinket = VarOnUseTrinket + num(trinket1:IsReady() or trinket1:CooldownRemains() > 0)
  -- variable,name=on_use_trinket,op=add,value=(trinket.2.has_proc.any&trinket.2.cooldown.duration)*2
  VarOnUseTrinket = VarOnUseTrinket + (num(trinket2:IsReady() or trinket2:CooldownRemains() > 0) * 2)
  -- variable,name=on_use_trinket,op=add,value=(equipped.inscrutable_quantum_device|equipped.empyreal_ordnance|equipped.soulletting_ruby)*4
  VarOnUseTrinket = VarOnUseTrinket + (num(I.InscrutableQuantumDevice:IsEquipped() or I.EmpyrealOrdinance:IsEquipped() or I.SoullettingRuby:IsEquipped()) * 4)
  -- moonkin_form
  if S.MoonkinForm:IsCastable() then
    if Cast(S.MoonkinForm) then return "moonkin_form precombat"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and not Player:IsCasting(S.Wrath) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 2"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and (Player:IsCasting(S.Wrath) and S.Wrath:Count() == 2 or Player:PrevGCD(1, S.Wrath) and S.Wrath:Count() == 1) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 4"; end
  end
  -- starfire,if=!runeforge.balance_of_all_things|!covenant.night_fae|!spell_targets.starfall=1|!talent.natures_balance.enabled
  if S.Starfire:IsCastable() and not Player:IsCasting(S.Starfire) and ((not BOATEquipped) or CovenantID ~= 3 or EnemiesCount40y ~= 1 or not S.NaturesBalance:IsAvailable()) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire precombat 6"; end
  end
  -- starsurge,if=runeforge.balance_of_all_things&covenant.night_fae&spell_targets.starfall=1
  if S.Starsurge:IsReady() and (BOATEquipped and CovenantID == 3 and EnemiesCount40y == 1) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge precombat 8"; end
  end
end

local function Opener()
  -- moonfire
  if S.Moonfire:IsReady() and (Target:DebuffDown(S.MoonfireDebuff)) then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire opener 2"; end
  end
  -- sunfire
  if S.Sunfire:IsReady() and (Target:DebuffDown(S.SunfireDebuff)) then
    if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire opener 4"; end
  end
  -- stellar_flare
  if S.StellarFlare:IsReady() and (Target:DebuffDown(S.StellarFlareDebuff)) then
    if Cast(S.StellarFlare, nil, nil, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare opener 6"; end
  end
  if (CovenantID == 3 and CDsON()) then
    -- warrior_of_elune
    if S.WarriorofElune:IsReady() then
      if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune opener 8"; end
    end
    -- force_of_nature
    if S.ForceofNature:IsReady() then
      if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature opener 10"; end
    end
    -- fury_of_elune
    if S.FuryofElune:IsReady() then
      if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune opener 12"; end
    end
  end
  if (CovenantID == 2) then
    if S.RavenousFrenzy:IsCastable() and CDsON() then
      if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy opener 14"; end
    end
  end
  -- ca_inc
  if CaInc:IsReady() and CDsON() then
    if Cast(CaInc, Settings.Balance.GCDasOffGCD.CaInc) then return "ca_inc opener 16"; end
  end
  -- starsurge,if=prev_gcd.1.ca_inc
  if S.Starsurge:IsReady() and (Player:PrevGCDP(1, CaInc)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge opener 18"; end
  end
  if (CovenantID == 2) then
    -- wrath,if=prev_gcd.1.starsurge
    if S.Wrath:IsCastable() and (Player:PrevGCDP(1, S.Starsurge)) then
      if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath opener 20"; end
    end
    -- wrath,if=prev_gcd.1.wrath&prev_gcd.2.starsurge
    if S.Wrath:IsCastable() and (Player:PrevGCDP(1, S.Wrath) and Player:PrevGCDP(2, S.Starsurge)) then
      if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath opener 22"; end
    end
    -- wrath,if=prev_gcd.1.wrath&prev_gcd.2.wrath&prev_gcd.3.starsurge
    if S.Wrath:IsCastable() and (Player:PrevGCDP(1, S.Wrath) and Player:PrevGCDP(2, S.Wrath) and Player:PrevGCDP(3, S.Starsurge)) then
      if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath opener 24"; end
    end
    -- variable,name=opener_finished,value=1,if=prev_gcd.3.wrath&prev_gcd.4.starsurge
    if (Player:PrevGCDP(3, S.Wrath) and Player:PrevGCDP(4, S.Starsurge)) then
      OpenerFinished = true
    end
  end
  if (CovenantID == 3) then
    -- starsurge,if=prev_gcd.1.starsurge&prev_gcd.2.ca_inc
    if S.Starsurge:IsReady() and (Player:PrevGCDP(1, S.Starsurge) and Player:PrevGCDP(2, CaInc)) then
      if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge opener 26"; end
    end
    -- convoke_the_spirits
    if S.ConvoketheSpirits:IsReady() and CDsON() then
      if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "convoke_the_spirits opener 28"; end
    end
    -- starsurge,if=astral_power>=30
    if S.Starsurge:IsReady() then
      if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge opener 30"; end
    end
    -- variable,name=opener_finished,value=1,if=astral_power<30
    if (S.ConvoketheSpirits:CooldownDown() and CaInc:CooldownDown() and Player:AstralPowerP() < 30) then
      OpenerFinished = true
    end
  end
end

local function Fallthru()
  -- starsurge,if=!runeforge.balance_of_all_things.equipped
  if S.Starsurge:IsReady() and (not BOATEquipped) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge fallthru 2"; end
  end
  -- sunfire,target_if=dot.moonfire.remains>remains*22%18
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireFallthru, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire fallthru 4"; end
  end
  -- moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire fallthru 6"; end
  end
end

local function St()
  -- starsurge,if=runeforge.timeworn_dreambinder&(eclipse.in_any&!((buff.timeworn_dreambinder.remains>action.wrath.execute_time+0.1&(eclipse.in_both|eclipse.in_solar|eclipse.lunar_next)|buff.timeworn_dreambinder.remains>action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))|!buff.timeworn_dreambinder.up)|(buff.ca_inc.up|variable.convoke_desync)&cooldown.convoke_the_spirits.ready&covenant.night_fae)&(!covenant.kyrian|cooldown.empower_bond.remains>8)&(buff.ca_inc.up|!cooldown.ca_inc.ready)
  if S.Starsurge:IsReady() and (TimewornEquipped and (EclipseInAny and not ((Player:BuffRemains(S.TimewornDreambinderBuff) > (S.Wrath:ExecuteTime() + 0.6) and (EclipseInBoth or EclipseInSolar or EclipseLunarNext) or Player:BuffRemains(S.TimewornDreambinderBuff) > (S.Starfire:ExecuteTime() + 0.6) and (EclipseInLunar or EclipseSolarNext or EclipseAnyNext)) or Player:BuffDown(S.TimewornDreambinderBuff)) or (Player:BuffUp(CaInc) or VarConvokeDesync) and S.ConvoketheSpirits:CooldownUp() and CovenantID == 3) and (CovenantID ~= 1 or S.EmpowerBond:CooldownRemains() > 8) and (Player:BuffUp(CaInc) or not CaInc:CooldownUp())) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 4"; end
  end
  -- adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>5)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3&dot.adaptive_swarm_damage.ticking
  if S.AdaptiveSwarm:IsCastable() then
    if Everyone.CastCycle(S.AdaptiveSwarm, Enemies40y, EvaluateCycleAdaptiveSwarmST, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm st 6"; end
  end
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready&!runeforge.primordial_arcanic_pulsar|buff.ca_inc.up)&astral_power<=40&(buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)|fight_remains<10&!cooldown.ca_inc.ready)
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and (not CaInc:CooldownUp()) and (not PAPEquipped) or Player:BuffUp(CaInc)) and Player:AstralPowerP() <= 40 and (Player:BuffRemains(S.EclipseLunar) > 10 or Player:BuffRemains(S.EclipseSolar) > 10) or fightRemains < 10 and not CaInc:CooldownUp())) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "convoke_the_spirits st 8"; end
  end
  -- variable,name=dot_requirements,value=(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)&!buff.ravenous_frenzy_sinful_hysteria.up&(buff.kindred_empowerment_energize.remains<gcd.max)&(buff.eclipse_solar.remains>gcd.max|buff.eclipse_lunar.remains>gcd.max|(!buff.eclipse_lunar.up|!buff.eclipse_solar.up)&!talent.solstice.enabled)
  VarDotRequirements = ((Player:BuffRemains(S.RavenousFrenzyBuff) > 5 or Player:BuffDown(S.RavenousFrenzyBuff)) and Player:BuffDown(S.RavenousFrenzySHBuff) and (Player:BuffRemains(S.KindredEmpowermentEnergizeBuff) < GCDMax) and (Player:BuffRemains(S.EclipseSolar) > GCDMax or Player:BuffRemains(S.EclipseLunar) > GCDMax or (Player:BuffDown(S.EclipseLunar) or Player:BuffDown(S.EclipseSolar)) and not S.Solstice:IsAvailable()))
  -- variable,name=dot_outside_eclipse,value=(!buff.eclipse_solar.up&!buff.eclipse_lunar.up)|talent.solstice.enabled
  VarDotOutsideEclipse = ((Player:BuffDown(S.EclipseSolar) and Player:BuffDown(S.EclipseLunar)) or S.Solstice:IsAvailable())
  -- moonfire,target_if=(buff.eclipse_solar.remains>remains|buff.eclipse_lunar.remains>remains|variable.dot_outside_eclipse)&refreshable&target.time_to_die>12,if=ap_check&variable.dot_requirements
  if S.Moonfire:IsCastable() and (AP_Check(S.Moonfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireST, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire st 10"; end
  end
  -- sunfire,target_if=(buff.eclipse_solar.remains>remains|buff.eclipse_lunar.remains>remains|variable.dot_outside_eclipse)&refreshable&target.time_to_die>12,if=ap_check&variable.dot_requirements
  if S.Sunfire:IsCastable() and (AP_Check(S.Sunfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireST, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire st 12"; end
  end
  -- stellar_flare,target_if=(buff.eclipse_solar.remains>remains|buff.eclipse_lunar.remains>remains|variable.dot_outside_eclipse)&refreshable&target.time_to_die>16,if=ap_check&variable.dot_requirements
  if S.StellarFlare:IsCastable() and (AP_Check(S.StellarFlare) and VarDotRequirements) then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareST, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare st 14"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and CDsON() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature, nil, not Target:IsInRange(45)) then return "force_of_nature st 16"; end
  end
  -- kindred_spirits,if=((buff.eclipse_solar.remains>10|buff.eclipse_lunar.remains>10)&cooldown.ca_inc.remains>30&(buff.primordial_arcanic_pulsar.value<240|!runeforge.primordial_arcanic_pulsar.equipped))|buff.primordial_arcanic_pulsar.value>=270|buff.ca_inc.remains>10
  if S.KindredSpirits:IsCastable() and (((Player:BuffRemains(S.EclipseSolar) > 10 or Player:BuffRemains(S.EclipseLunar) > 10) and CaInc:CooldownRemains() > 30 and (PAPValue < 240 or not PAPEquipped)) or PAPValue >= 270 or Player:BuffRemains(CaInc) > 10) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "kindred_spirits st 18"; end
  end
  -- variable,name=cd_condition_st,value=!druid.no_cds&variable.cd_condition&((cooldown.empyreal_ordnance.remains<167+(11*runeforge.sinful_hysteria)&equipped.empyreal_ordnance)|astral_power>=90&(!talent.fury_of_elune.enabled|buff.ca_inc.duration>cooldown.fury_of_elune.remains+8)&dot.sunfire.remains>8&dot.moonfire.remains>9&(dot.stellar_flare.remains>10|!talent.stellar_flare.enabled)&variable.thrill_seeker_wait&(cooldown.empower_bond.up|!covenant.kyrian)&target.time_to_die>buff.ca_inc.duration*0.7|fight_remains<buff.ca_inc.duration|covenant.night_fae|buff.bloodlust.up&buff.bloodlust.remains<buff.ca_inc.duration+(9*runeforge.primordial_arcanic_pulsar.equipped))&!buff.ca_inc.up&(!covenant.night_fae|cooldown.convoke_the_spirits.up|fight_remains<cooldown.convoke_the_spirits.remains+6|fight_remains%%180<buff.ca_inc.duration)
  VarCDConditionST = (CDsON() and VarCDCondition and ((I.EmpyrealOrdinance:CooldownRemains() < 167 + (11 * num(SinfulHysteriaEquipped)) and I.EmpyrealOrdinance:IsEquipped()) or Player:AstralPowerP() >= 90 and ((not S.FuryofElune:IsAvailable()) or CaInc:BaseDuration() > S.FuryofElune:CooldownRemains() + 8) and Target:DebuffRemains(S.SunfireDebuff) > 8 and Target:DebuffRemains(S.MoonfireDebuff) > 9 and (Target:DebuffRemains(S.StellarFlareDebuff) > 10 or not S.StellarFlare:IsAvailable()) and VarThrillSeekerWait and (S.EmpowerBond:CooldownUp() or CovenantID ~= 1) and Target:TimeToDie() > CaInc:BaseDuration() * 0.7 or fightRemains < CaInc:BaseDuration() or CovenantID == 3 or Player:BloodlustUp() and Player:BloodlustRemains() < CaInc:BaseDuration() + (9 * num(PAPEquipped))) and Player:BuffDown(CaInc) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() or fightRemains < S.ConvoketheSpirits:CooldownRemains() + 6 or fightRemains % 180 < CaInc:BaseDuration()))
  -- ravenous_frenzy,if=buff.ca_inc.remains>15|buff.ca_inc.duration<32&variable.cd_condition_st
  if S.RavenousFrenzy:IsCastable() and (Player:BuffRemains(CaInc) > 15 or CaInc:BaseDuration() < 32 and VarCDConditionST) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy st 2"; end
  end
  if (CDsON()) then
    -- celestial_alignment,if=variable.cd_condition_st&(buff.ca_inc.duration>=32|!covenant.venthyr)|buff.ravenous_frenzy.up&buff.ravenous_frenzy.remains<9+conduit.precise_alignment.time_value+(!buff.bloodlust.up&!talent.starlord.enabled)
    if S.CelestialAlignment:IsCastable() and (VarCDConditionST and (CaInc:BaseDuration() >= 32 or CovenantID ~= 2) or Player:BuffUp(S.RavenousFrenzyBuff) and Player:BuffRemains(S.RavenousFrenzyBuff) < 9 + PATime + num(Player:BloodlustDown() and not S.Starlord:IsAvailable())) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment st 20"; end
    end
    -- incarnation,if=variable.cd_condition_st
    if S.Incarnation:IsCastable() and (VarCDConditionST) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation st 22"; end
    end
  end
  -- variable,name=save_for_ca_inc,value=!cooldown.ca_inc.ready|!variable.convoke_desync&covenant.night_fae|druid.no_cds
  VarSaveForCAInc = (not CaInc:CooldownUp() or not VarConvokeDesync and CovenantID == 3 or not CDsON())
  -- fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<240&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord)&variable.save_for_ca_inc&(buff.ravenous_frenzy.remains<9-(5*runeforge.sinful_hysteria+!equipped.instructors_divine_bell)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up)&(!covenant.kyrian|cooldown.empower_bond.remains>20)
  if S.FuryofElune:IsCastable() and CDsON() and (EclipseInAny and AP_Check(S.FuryofElune) and PAPValue < 240 and (Target:DebuffUp(S.AdaptiveSwarmDebuff) or CovenantID ~= 4) and VarSaveForCAInc and (Player:BuffRemains(S.RavenousFrenzyBuff) < 9 - (5 * num(SinfulHysteriaEquipped) + num(not I.InstructorsDivineBell:IsEquipped())) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffDown(S.RavenousFrenzyBuff)) and (CovenantID ~= 1 or S.EmpowerBond:CooldownRemains() > 20)) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune st 24"; end
  end
  -- starfall,if=buff.oneths_perception.up&buff.starfall.refreshable
  if S.Starfall:IsReady() and (Player:BuffUp(S.OnethsPerceptionBuff) and Player:BuffRefreshable(S.StarfallBuff)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 26"; end
  end
  -- cancel_buff,name=starlord,if=buff.starlord.remains<5&(buff.eclipse_solar.remains>5|buff.eclipse_lunar.remains>5)&astral_power>90
  -- starsurge,if=covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.remains<5&!druid.no_cds&eclipse.in_any&astral_power>40
  if S.Starsurge:IsReady() and (CovenantID == 3 and VarConvokeDesync and S.ConvoketheSpirits:CooldownRemains() < 5 and CDsON() and EclipseInAny and Player:AstralPowerP() > 40) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 28"; end
  end
  -- starfall,if=talent.stellar_drift.enabled&!talent.starlord.enabled&buff.starfall.refreshable&(buff.eclipse_lunar.remains>8&eclipse.in_lunar&buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250&astral_power>90|dot.adaptive_swarm_damage.remains>8|action.adaptive_swarm_damage.in_flight)&cooldown.ca_inc.remains>10
  if S.Starfall:IsReady() and (S.StellarDrift:IsAvailable() and not S.Starlord:IsAvailable() and Player:BuffRefreshable(S.StarfallBuff) and (Player:BuffRemains(S.EclipseLunar) > 6 and EclipseInLunar and PAPValue < 250 or PAPValue >= 250 and Player:AstralPowerP() > 90 or Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 8 or S.AdaptiveSwarm:InFlight()) and CaInc:CooldownRemains() > 10) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 30"; end
  end
  -- starsurge,if=buff.oneths_clear_vision.up|buff.kindred_empowerment_energize.up|buff.ca_inc.up&(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)+3*talent.new_moon.enabled&!runeforge.sinful_hysteria&buff.ravenous_frenzy.up|buff.ca_inc.remains<gcd.max*ceil(astral_power%30)|buff.ravenous_frenzy_sinful_hysteria.up|(buff.ravenous_frenzy.remains<action.starfire.execute_time&spell_haste<0.4|buff.ravenous_frenzy.remains<action.wrath.execute_time|variable.iqd_condition&cooldown.inscrutable_quantum_device.ready&equipped.inscrutable_quantum_device)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up&!cooldown.ravenous_frenzy.ready|!covenant.venthyr)|astral_power>90&eclipse.in_any
  if S.Starsurge:IsReady() and (Player:BuffUp(S.OnethsClearVisionBuff) or Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or Player:BuffUp(CaInc) and (Player:BuffRemains(S.RavenousFrenzyBuff) < (GCDMax * ceil(Player:AstralPowerP() / 30) + 3 * num(S.NewMoon:IsAvailable())) and (not SinfulHysteriaEquipped) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffRemains(CaInc) < (GCDMax * ceil(Player:AstralPowerP() / 30)) or Player:BuffUp(S.RavenousFrenzySHBuff) or (Player:BuffRemains(S.RavenousFrenzyBuff) < S.Starfire:ExecuteTime() + 0.5 and Player:SpellHaste() < 0.4 or Player:BuffRemains(S.RavenousFrenzyBuff) < S.Wrath:ExecuteTime() + 0.5 or VarIQDCondition and I.InscrutableQuantumDevice:IsEquippedAndReady()) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffUp(S.RavenousFrenzyBuff) and S.RavenousFrenzy:CooldownDown() or CovenantID ~= 2) or Player:AstralPowerP() > 90 and EclipseInAny) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 32"; end
  end
  -- starsurge,if=talent.starlord.enabled&!runeforge.timeworn_dreambinder&(buff.starlord.up|astral_power>90)&buff.starlord.stack<3&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&buff.primordial_arcanic_pulsar.value<270&(cooldown.ca_inc.remains>10|!variable.convoke_desync&covenant.night_fae)
  if S.Starsurge:IsReady() and (S.Starlord:IsAvailable() and (not TimewornEquipped) and (Player:BuffUp(S.StarlordBuff) or Player:AstralPowerP() > 90) and Player:BuffStack(S.StarlordBuff) < 3 and (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar)) and PAPValue < 270 and (CaInc:CooldownRemains() > 10 or (not VarConvokeDesync) and CovenantID == 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 34"; end
  end
  -- variable,name=aspPerSec,value=eclipse.in_lunar*8%action.starfire.execute_time+!eclipse.in_lunar*(6+talent.soul_of_the_forest.enabled*3)%action.wrath.execute_time+0.45%spell_haste+0.5*talent.natures_balance.enabled
  VarAspPerSec = (num(EclipseInLunar) * 8 / S.Starfire:ExecuteTime() + num(not EclipseInLunar) * (6 + num(S.SouloftheForest:IsAvailable()) * 3) / S.Wrath:ExecuteTime() + 0.45 / Player:SpellHaste() + 0.5 * num(S.NaturesBalance:IsAvailable()))
  -- starsurge,if=!runeforge.timeworn_dreambinder&(buff.primordial_arcanic_pulsar.value<270|buff.primordial_arcanic_pulsar.value<250&talent.stellar_drift.enabled)&(eclipse.in_solar&astral_power+variable.aspPerSec*buff.eclipse_solar.remains+dot.fury_of_elune.ticks_remain*2.5>80|eclipse.in_lunar&astral_power+variable.aspPerSec*buff.eclipse_lunar.remains+dot.fury_of_elune.ticks_remain*2.5>90)&!buff.oneths_perception.up&!talent.starlord.enabled&(cooldown.ca_inc.remains>7|soulbind.thrill_seeker.enabled&buff.thrill_seeker.stack<33-(runeforge.sinful_hysteria*5)&fight_remains>100&fight_remains<200|druid.no_cds)&(cooldown.kindred_spirits.remains>7|!covenant.kyrian)
  if S.Starsurge:IsReady() and ((not TimewornEquipped) and (PAPValue < 270 or PAPValue < 250 and S.StellarDrift:IsAvailable()) and (EclipseInSolar and Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseSolar) + FuryTicksRemain * 2.5 > 80 or EclipseInLunar and Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseLunar) + FuryTicksRemain * 2.5 > 90) and Player:BuffDown(S.OnethsPerceptionBuff) and (not S.Starlord:IsAvailable()) and (CaInc:CooldownRemains() > 7 or S.ThrillSeeker:SoulbindEnabled() and Player:BuffStack(S.ThrillSeekerBuff) < 33 - (num(SinfulHysteriaEquipped) * 5) and fightRemains > 100 and fightRemains < 200 or not CDsON()) and (S.KindredSpirits:CooldownRemains() > 7 or CovenantID ~= 1)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 36"; end
  end
  -- new_moon,if=(buff.eclipse_lunar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
  if S.NewMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.NewMoon:ExecuteTime() or (S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5) or S.NewMoon:Charges() == 3) and AP_Check(S.NewMoon) and VarSaveForCAInc) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon st 38"; end
  end
  -- half_moon,if=(buff.eclipse_lunar.remains>execute_time&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc&(buff.ravenous_frenzy.remains<(5-2*runeforge.sinful_hysteria)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up)
  if S.HalfMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.HalfMoon:ExecuteTime() and CovenantID ~= 1 or (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1) or (S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5) or S.HalfMoon:Charges() == 3 or Player:BuffUp(CaInc)) and AP_Check(S.HalfMoon) and VarSaveForCAInc and (Player:BuffRemains(S.RavenousFrenzyBuff) < (5 - 2 * num(SinfulHysteriaEquipped)) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffDown(S.RavenousFrenzyBuff))) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon st 40"; end
  end
  -- full_moon,if=(buff.eclipse_lunar.remains>execute_time&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc&(buff.ravenous_frenzy.remains<5&buff.ravenous_frenzy.up&!runeforge.sinful_hysteria|!buff.ravenous_frenzy.up)
  if S.FullMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() and CovenantID ~= 1 or (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1) or (S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5) or S.FullMoon:Charges() == 3 or Player:BuffUp(CaInc)) and AP_Check(S.FullMoon) and VarSaveForCAInc and (Player:BuffRemains(S.RavenousFrenzyBuff) < 5 and Player:BuffUp(S.RavenousFrenzyBuff) and (not SinfulHysteriaEquipped) or Player:BuffDown(S.RavenousFrenzyBuff))) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon st 42"; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune st 44"; end
  end
  -- starfire,if=eclipse.in_lunar&!buff.ravenous_frenzy.up|eclipse.solar_next|eclipse.any_next|(buff.warrior_of_elune.up|spell_haste<0.45&!covenant.venthyr|spell_haste<0.4&covenant.venthyr)&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
  if S.Starfire:IsCastable() and (EclipseInLunar and Player:BuffDown(S.RavenousFrenzyBuff) or EclipseSolarNext or EclipseAnyNext or (Player:BuffUp(S.WarriorofEluneBuff) or Player:SpellHaste() < 0.45 and CovenantID ~= 2 or Player:SpellHaste() < 0.4 and CovenantID == 2) and Player:BuffUp(S.EclipseLunar) or (Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc))) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire st 46"; end
  end
  -- wrath
  if S.Wrath:IsCastable() then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath st 48"; end
  end
  -- run_action_list,name=fallthru
  if (true) then
    local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Aoe()
  -- variable,name=dream_will_fall_off,value=(buff.timeworn_dreambinder.remains<gcd.max+0.1|buff.timeworn_dreambinder.remains<action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))&buff.timeworn_dreambinder.up&runeforge.timeworn_dreambinder
  -- Moved TimewornEquipped to the front to abort as quickly as possible if it's not equipped
  VarDreamWillFallOff = (TimewornEquipped and (Player:BuffRemains(S.TimewornDreambinderBuff) < (GCDMax + 0.1) or Player:BuffRemains(S.TimewornDreambinderBuff) < (S.Starfire:ExecuteTime() + 0.1) and (EclipseInLunar or EclipseSolarNext or EclipseAnyNext)) and Player:BuffUp(S.TimewornDreambinderBuff))
  -- variable,name=ignore_starsurge,value=!eclipse.in_solar&(spell_targets.starfire>5&talent.soul_of_the_forest.enabled|spell_targets.starfire>7)
  VarIgnoreStarsurge = (not EclipseInSolar and (EnemiesCount8ySplash > 5 and S.SouloftheForest:IsAvailable() or EnemiesCount8ySplash > 7))
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready|buff.ca_inc.up)&(buff.eclipse_lunar.remains>6|buff.eclipse_solar.remains>6)&(!runeforge.balance_of_all_things|buff.balance_of_all_things_nature.stack>3|buff.balance_of_all_things_arcane.stack>3)|fight_remains<10&!cooldown.ca_inc.ready)
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and CaInc:CooldownDown() or Player:BuffUp(CaInc)) and (Player:BuffRemains(S.EclipseLunar) > 6 or Player:BuffRemains(S.EclipseSolar) > 6) and ((not BOATEquipped) or Player:BuffStack(S.BOATNatureBuff) > 3 or Player:BuffStack(S.BOATArcaneBuff) > 3) or fightRemains < 10 and CaInc:CooldownDown())) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "convoke_the_spirits aoe 2"; end
  end
  -- sunfire,target_if=(refreshable|buff.eclipse_solar.remains<3&eclipse.in_solar&remains<14&talent.soul_of_the_forest.enabled)&target.time_to_die>14-spell_targets+remains&(eclipse.in_any|remains<gcd.max)
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireAoe, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire aoe 6"; end
  end
  -- sunfire,if=variable.iqd_condition&cooldown.inscrutable_quantum_device.ready&equipped.inscrutable_quantum_device
  if S.Sunfire:IsCastable() and Settings.Commons.Enabled.Trinkets and (VarIQDCondition and I.InscrutableQuantumDevice:IsEquippedAndReady()) then
    if Cast(S.Sunfire, nil, nil, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire aoe 7"; end
  end
  -- starfall,if=!talent.stellar_drift.enabled&(buff.starfall.refreshable&(spell_targets.starfall<3|!runeforge.timeworn_dreambinder)|talent.soul_of_the_forest.enabled&buff.eclipse_solar.remains<3&eclipse.in_solar&buff.starfall.remains<7&spell_targets.starfall>=4)&(!runeforge.lycaras_fleeting_glimpse|time%%45>buff.starfall.remains+2)&target.time_to_die>5
  if S.Starfall:IsReady() and ((not S.StellarDrift:IsAvailable()) and (Player:BuffRefreshable(S.StarfallBuff) and (EnemiesCount40y < 3 or not TimewornEquipped) or S.SouloftheForest:IsAvailable() and Player:BuffRemains(S.EclipseSolar) < 3 and EclipseInSolar and Player:BuffRemains(S.StarfallBuff) < 7 and EnemiesCount40y >= 4) and ((not LycaraEquipped) or HL.CombatTime() % 45 > Player:BuffRemains(S.StarfallBuff) + 2) and Target:TimeToDie() > 5) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 8"; end
  end
  -- starfall,if=talent.stellar_drift.enabled&buff.starfall.refreshable&(!runeforge.lycaras_fleeting_glimpse|time%%45>4)&target.time_to_die>3
  if S.Starfall:IsReady() and (S.StellarDrift:IsAvailable() and Player:BuffRefreshable(S.StarfallBuff) and ((not LycaraEquipped) or HL.CombatTime() % 45 > 4) and Target:TimeToDie() > 3) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 9"; end
  end
  -- starfall,if=runeforge.timeworn_dreambinder&spell_targets.starfall>=3&(!buff.timeworn_dreambinder.up&buff.starfall.refreshable|(variable.dream_will_fall_off&(buff.starfall.remains<3|spell_targets.starfall>2&talent.stellar_drift.enabled&buff.starfall.remains<5)))
  if S.Starfall:IsReady() and (TimewornEquipped and EnemiesCount40y >= 3 and (Player:BuffDown(S.TimewornDreambinderBuff) and Player:BuffRefreshable(S.StarfallBuff) or (VarDreamWillFallOff and (Player:BuffRemains(S.StarfallBuff) < 3 or EnemiesCount40y > 2 and S.StellarDrift:IsAvailable() and Player:BuffRemains(S.StarfallBuff) < 5)))) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 10"; end
  end
  -- variable,name=starfall_wont_fall_off,value=astral_power>80-(10*buff.timeworn_dreambinder.stack)-(buff.starfall.remains*3%spell_haste*!talent.stellar_drift.enabled)-(cooldown.starfall.remains*3%spell_haste*talent.stellar_drift.enabled)-(dot.fury_of_elune.remains*5)&(buff.starfall.up|cooldown.starfall.remains)
  VarStarfallWontFallOff = (Player:AstralPowerP() > 80 - (10 * Player:BuffStack(S.TimewornDreambinderBuff)) - (Player:BuffRemains(S.StarfallBuff) * 3 / Player:SpellHaste() * num(not S.StellarDrift:IsAvailable())) - (S.Starfall:CooldownRemains() * 3 / Player:SpellHaste() * num(S.StellarDrift:IsAvailable())) - (FuryofEluneRemains * 5) and (Player:BuffUp(S.StarfallBuff) or S.Starfall:CooldownDown()))
  -- starsurge,if=variable.dream_will_fall_off&variable.starfall_wont_fall_off&!variable.ignore_starsurge|(buff.balance_of_all_things_nature.stack>3|buff.balance_of_all_things_arcane.stack>3)&spell_targets.starfall<4&variable.starfall_wont_fall_off
  if S.Starsurge:IsReady() and (VarDreamWillFallOff and VarStarfallWontFallOff and not VarIgnoreStarsurge or (Player:BuffStack(S.BOATNatureBuff) > 3 or Player:BuffStack(S.BOATArcaneBuff) > 3) and EnemiesCount40y < 4 and VarStarfallWontFallOff) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 12"; end
  end
  -- adaptive_swarm,target_if=!ticking&!action.adaptive_swarm_damage.in_flight|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3
  if S.AdaptiveSwarm:IsCastable() then
    if Everyone.CastCycle(S.AdaptiveSwarm, Enemies40y, EvaluateCycleAdaptiveSwarmAoe, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm aoe 14"; end
  end
  -- moonfire,target_if=refreshable&target.time_to_die>((14+(spell_targets.starfire*2*buff.eclipse_lunar.up))+remains)%(1+talent.twin_moons.enabled),if=(cooldown.ca_inc.ready&!druid.no_cds&(variable.convoke_desync|cooldown.convoke_the_spirits.ready|!covenant.night_fae)|spell_targets.starfire<((6-(buff.eclipse_lunar.up*2))*(1+talent.twin_moons.enabled))&!eclipse.solar_next|(eclipse.in_solar|(eclipse.in_both|eclipse.in_lunar)&!talent.soul_of_the_forest.enabled|buff.primordial_arcanic_pulsar.value>=250)&(spell_targets.starfire<10*(1+talent.twin_moons.enabled))&astral_power>50-buff.starfall.remains*6)&(!buff.kindred_empowerment_energize.up|eclipse.in_solar|!covenant.kyrian)&!buff.ravenous_frenzy_sinful_hysteria.up
  if S.Moonfire:IsCastable() and ((CaInc:CooldownUp() and CDsON() and (VarConvokeDesync or S.ConvoketheSpirits:CooldownUp() or CovenantID ~= 3) or EnemiesCount8ySplash < ((6 - (num(Player:BuffUp(S.EclipseLunar)) * 2)) * (1 + num(S.TwinMoons:IsAvailable()))) and not EclipseSolarNext or (EclipseInSolar or (EclipseInBoth or EclipseInLunar) and not S.SouloftheForest:IsAvailable() or PAPValue >= 250) and (EnemiesCount8ySplash < 10 * (1 + num(S.TwinMoons:IsAvailable()))) and Player:AstralPowerP() > 50 - Player:BuffRemains(S.StarfallBuff) * 6) and (Player:BuffDown(S.KindredEmpowermentEnergizeBuff) or EclipseInSolar or CovenantID ~= 1) and Player:BuffDown(S.RavenousFrenzySHBuff)) then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireAoe, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire aoe 16"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and CDsON() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature aoe 18"; end
  end
  -- variable,name=cd_condition_aoe,value=!druid.no_cds&variable.cd_condition&((buff.starfall.up|talent.stellar_drift.enabled|covenant.night_fae)&(!buff.solstice.up&!buff.ca_inc.up&(!talent.fury_of_elune.enabled|buff.ca_inc.duration>cooldown.fury_of_elune.remains+8)&variable.thrill_seeker_wait&(!covenant.night_fae|cooldown.convoke_the_spirits.up&(buff.starfall.remains<2|!talent.stellar_drift.enabled))&target.time_to_die>buff.ca_inc.duration*0.7)|fight_remains<buff.ca_inc.duration)
  VarCDConditionAoE = (CDsON() and VarCDCondition and ((Player:BuffUp(S.StarfallBuff) or S.StellarDrift:IsAvailable() or CovenantID == 3) and (Player:BuffDown(S.SolsticeBuff) and Player:BuffDown(CaInc) and ((not S.FuryofElune:IsAvailable()) or CaInc:BaseDuration() > S.FuryofElune:CooldownRemains() + 8) and VarThrillSeekerWait and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() and (Player:BuffRemains(S.StarfallBuff) < 2 or not S.StellarDrift:IsAvailable())) and Target:TimeToDie() > CaInc:BaseDuration() * 0.7) or fightRemains < CaInc:BaseDuration()))
  -- ravenous_frenzy,if=buff.ca_inc.remains>15|buff.ca_inc.duration<30&variable.cd_condition_aoe
  if S.RavenousFrenzy:IsCastable() and (Player:BuffRemains(CaInc) > 15 or CaInc:BaseDuration() < 30 and VarCDConditionAoE) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy aoe 4"; end
  end
  if (CDsON()) then
    -- celestial_alignment,if=variable.cd_condition_aoe&(buff.ca_inc.duration>=30|!covenant.venthyr)|buff.ravenous_frenzy.up&buff.ravenous_frenzy.remains<9+conduit.precise_alignment.time_value+(!buff.bloodlust.up&!talent.starlord.enabled)
    if S.CelestialAlignment:IsCastable() and (VarCDConditionAoE and (CaInc:BaseDuration() >= 30 or CovenantID ~= 2) or Player:BuffUp(S.RavenousFrenzyBuff) and Player:BuffRemains(S.RavenousFrenzyBuff) < 9 + PATime + num(Player:BloodlustDown() and not S.Starlord:IsAvailable())) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment aoe 20"; end
    end
    -- incarnation,if=variable.cd_condition_aoe
    if S.Incarnation:IsCastable() and (VarCDConditionAoE) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation aoe 22"; end
    end
  end
  -- kindred_spirits,if=interpolated_fight_remains<15|(buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250)&buff.starfall.up&(cooldown.ca_inc.remains>40|druid.no_cds)
  if S.KindredSpirits:IsCastable() and (fightRemains < 15 or (PAPValue < 250 or PAPValue >= 250) and Player:BuffUp(S.StarfallBuff) and (CaInc:CooldownRemains() > 40 or not CDsON())) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "kindred_spirits aoe 24"; end
  end
  -- stellar_flare,target_if=refreshable&time_to_die>15,if=spell_targets.starfire<4&ap_check&(buff.ca_inc.remains>10|!buff.ca_inc.up)
  if S.StellarFlare:IsCastable() and (EnemiesCount8ySplash < 4 and AP_Check(S.StellarFlare) and (Player:BuffRemains(CaInc) > 10 or Player:BuffDown(CaInc))) then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareAoe, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare aoe 26"; end
  end
  -- fury_of_elune,if=eclipse.in_any&buff.primordial_arcanic_pulsar.value<250&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord|spell_targets>2)&(buff.ravenous_frenzy.remains<9-(5*runeforge.sinful_hysteria)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up)&(!cooldown.ca_inc.up|buff.thrill_seeker.stack<15&fight_remains<200&fight_remains>100|!soulbind.thrill_seeker.enabled)&(soulbind.thrill_seeker.enabled|cooldown.ca_inc.remains>30)
  if S.FuryofElune:IsCastable() and (EclipseInAny and PAPValue < 250 and (Target:DebuffUp(S.AdaptiveSwarmDebuff) or CovenantID ~= 4 or EnemiesCount8ySplash > 2) and (Player:BuffRemains(S.RavenousFrenzyBuff) < 9 - (5 * num(SinfulHysteriaEquipped)) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffDown(S.RavenousFrenzyBuff)) and (CaInc:CooldownDown() or Player:BuffStack(S.ThrillSeekerBuff) < 15 and fightRemains < 200 and fightRemains > 100 or not S.ThrillSeeker:SoulbindEnabled()) and (S.ThrillSeeker:SoulbindEnabled() or CaInc:CooldownRemains() > 30)) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune aoe 28"; end
  end
  -- starfall,if=buff.oneths_perception.up&(buff.starfall.refreshable|astral_power>90)
  if S.Starfall:IsReady() and (Player:BuffUp(S.OnethsPerceptionBuff) and (Player:BuffRefreshable(S.StarfallBuff) or Player:AstralPowerP() > 90)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 30"; end
  end
  -- starfall,if=covenant.night_fae&!talent.stellar_drift.enabled&(variable.convoke_desync|cooldown.ca_inc.up|buff.ca_inc.up)&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%50)&buff.starfall.remains<4&!druid.no_cds
  if S.Starfall:IsReady() and (CovenantID == 3 and (not S.StellarDrift:IsAvailable()) and (VarConvokeDesync or CaInc:CooldownUp() or Player:BuffUp(CaInc)) and S.ConvoketheSpirits:CooldownRemains() < GCDMax * ceil(Player:AstralPowerP() / 50) and Player:BuffRemains(S.StarfallBuff) < 4 and CDsON()) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 32"; end
  end
  -- starsurge,if=covenant.night_fae&(variable.convoke_desync|cooldown.ca_inc.up|buff.ca_inc.up)&cooldown.convoke_the_spirits.remains<6&buff.starfall.up&eclipse.in_any&!variable.ignore_starsurge&!druid.no_cds
  if S.Starsurge:IsReady() and (CovenantID == 3 and (VarConvokeDesync or CaInc:CooldownUp() or Player:BuffUp(CaInc)) and S.ConvoketheSpirits:CooldownRemains() < 6 and Player:BuffUp(S.StarfallBuff) and EclipseInAny and not VarIgnoreStarsurge and CDsON()) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 34"; end
  end
  -- starsurge,if=buff.oneths_clear_vision.up|(!starfire.ap_check&!variable.ignore_starsurge|(buff.ca_inc.remains<5&buff.ca_inc.up|((buff.ca_inc.remains<gcd.max*ceil(astral_power%30)&buff.ca_inc.up|buff.ravenous_frenzy_sinful_hysteria.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy_sinful_hysteria.up)&covenant.venthyr))&(spell_targets.starfall<3|variable.starfall_wont_fall_off))&!variable.ignore_starsurge&(!runeforge.timeworn_dreambinder|spell_targets.starfall<3)
  if S.Starsurge:IsReady() and (Player:BuffUp(S.OnethsClearVisionBuff) or ((not AP_Check(S.Starfire)) and (not VarIgnoreStarsurge) or (Player:BuffRemains(CaInc) < 5 and Player:BuffUp(CaInc) or ((Player:BuffRemains(CaInc) < GCDMax * ceil(Player:AstralPowerP() / 30) and Player:BuffUp(CaInc) or Player:BuffRemains(S.RavenousFrenzySHBuff) < GCDMax * ceil(Player:AstralPowerP() / 30) and Player:BuffUp(S.RavenousFrenzySHBuff)) and CovenantID == 2)) and (EnemiesCount40y < 3 or VarStarfallWontFallOff)) and (not VarIgnoreStarsurge) and ((not TimewornEquipped) or EnemiesCount40y < 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 36"; end
  end
  -- new_moon,if=(buff.eclipse_solar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.NewMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.NewMoon:ExecuteTime() or (S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5) or S.NewMoon:Charges() == 3) and AP_Check(S.NewMoon)) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon aoe 38"; end
  end
  -- half_moon,if=(buff.eclipse_solar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check&(buff.ravenous_frenzy.remains<5&buff.ravenous_frenzy.up&!runeforge.sinful_hysteria|!buff.ravenous_frenzy.up)
  if S.HalfMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.HalfMoon:ExecuteTime() or (S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5) or S.HalfMoon:Charges() == 3) and AP_Check(S.HalfMoon) and (Player:BuffRemains(S.RavenousFrenzyBuff) < 5 and Player:BuffUp(S.RavenousFrenzyBuff) and (not SinfulHysteriaEquipped) or Player:BuffDown(S.RavenousFrenzyBuff))) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon aoe 40"; end
  end
  -- full_moon,if=(buff.eclipse_solar.remains>execute_time&(cooldown.ca_inc.remains>50|cooldown.convoke_the_spirits.remains>50)|(charges=2&recharge_time<5)|charges=3)&ap_check&(buff.ravenous_frenzy.remains<5&buff.ravenous_frenzy.up&!runeforge.sinful_hysteria|!buff.ravenous_frenzy.up)
  if S.FullMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime() and (CaInc:CooldownRemains() > 50 or S.ConvoketheSpirits:CooldownRemains() > 50) or (S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5) or S.FullMoon:Charges() == 3) and AP_Check(S.FullMoon) and (Player:BuffRemains(S.RavenousFrenzyBuff) < 5 and Player:BuffUp(S.RavenousFrenzyBuff) and (not SinfulHysteriaEquipped) or Player:BuffDown(S.RavenousFrenzyBuff))) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon aoe 42"; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune aoe 44"; end
  end
  -- variable,name=starfire_in_solar,value=spell_targets.starfire>4+floor(mastery_value*100%20)+floor(buff.starsurge_empowerment_solar.stack%4)
  -- TODO: Find a way to calculate starsurge_empowerment_solar
  VarStarfireinSolar = (EnemiesCount8ySplash > 4 + floor(Player:MasteryPct() / 20))
  -- variable,name=wrath_in_frenzy,value=1%spell_haste<2-(0.2*(spell_targets.starfire-1)*(1+talent.soul_of_the_forest.enabled*1.5))+0.15*buff.ravenous_frenzy.remains
  VarWrathInFrenzy = (1 / Player:SpellHaste() < 2 - (0.2 * (EnemiesCount8ySplash - 1) * (1 + num(S.SouloftheForest:IsAvailable()) * 1.5)) + 0.15 * Player:BuffRemains(S.RavenousFrenzyBuff))
  -- wrath,if=(eclipse.lunar_next|eclipse.any_next&variable.is_cleave)&(target.time_to_die>4|eclipse.lunar_in_2|fight_remains<10)|buff.eclipse_solar.remains<action.starfire.execute_time&buff.eclipse_solar.up|eclipse.in_solar&!variable.starfire_in_solar|buff.ca_inc.remains<action.starfire.execute_time&!variable.is_cleave&buff.ca_inc.remains<execute_time&buff.ca_inc.up|buff.ravenous_frenzy.up&variable.wrath_in_frenzy|!variable.is_cleave&buff.ca_inc.remains>execute_time
  if S.Wrath:IsCastable() and ((EclipseLunarNext or EclipseAnyNext and VarIsCleave) and (Target:TimeToDie() > 4 or S.Wrath:Count() == 2 or fightRemains < 10) or Player:BuffRemains(S.EclipseSolar) < S.Starfire:ExecuteTime() and Player:BuffUp(S.EclipseSolar) or EclipseInSolar and not VarStarfireinSolar or Player:BuffRemains(CaInc) < S.Starfire:ExecuteTime() and not VarIsCleave and Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc) or Player:BuffUp(S.RavenousFrenzyBuff) and VarWrathInFrenzy or (not VarIsCleave) and Player:BuffRemains(CaInc) > S.Wrath:ExecuteTime()) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath aoe 46"; end
  end
  -- starfire
  if S.Starfire:IsCastable() then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire aoe 48"; end
  end
  -- run_action_list,name=fallthru
  if (true) then
    local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Boat()
  -- ravenous_frenzy,if=buff.ca_inc.remains>15
  if S.RavenousFrenzy:IsCastable() and CDsON() and (Player:BuffRemains(CaInc) > 15) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant) then return "ravenous_frenzy boat 2"; end
  end
  -- adaptive_swarm,target_if=buff.balance_of_all_things_nature.stack<8&buff.balance_of_all_things_arcane.stack<8&(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  if S.AdaptiveSwarm:IsCastable() and (Player:BuffStack(S.BOATNatureBuff) < 8 and Player:BuffStack(S.BOATArcaneBuff) < 8 and (Target:DebuffDown(S.AdaptiveSwarmDebuff) and (not S.AdaptiveSwarm:InFlight()) and (Player:BuffDown(S.AdaptiveSwarmHeal) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 3) or Target:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and Target:DebuffRemains(S.AdaptiveSwarmDebuff) < 5 and Target:DebuffUp(S.AdaptiveSwarmDebuff))) then
    if Cast(S.AdaptiveSwarm, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm boat 4"; end
  end
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready|buff.ca_inc.up)&(buff.balance_of_all_things_nature.stack=8|buff.balance_of_all_things_arcane.stack=8)|fight_remains<10&cooldown.ca_inc.remains>7)
  -- Note: Changed BOAT buff stack to >6 for usability
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and CaInc:CooldownDown() or Player:BuffUp(CaInc)) and (Player:BuffStack(S.BOATNatureBuff) > 6 or Player:BuffStack(S.BOATArcaneBuff) > 6) or fightRemains < 10 and CaInc:CooldownRemains() > 7)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "convoke_the_spirits boat 6"; end
  end
  -- fury_of_elune,if=(((buff.balance_of_all_things_nature.stack>6|buff.balance_of_all_things_arcane.stack>6)&(!covenant.venthyr|!buff.ravenous_frenzy.up))&(druid.no_cds|cooldown.ca_inc.remains>50|(covenant.night_fae&cooldown.convoke_the_spirits.remains>50)))|(dot.adaptive_swarm_damage.remains>8&cooldown.ca_inc.remains>10&covenant.necrolord)|interpolated_fight_remains<8&!cooldown.ca_inc.ready|covenant.kyrian&buff.kindred_empowerment.up|covenant.venthyr&buff.ravenous_frenzy.remains<9&buff.ravenous_frenzy.up
  if S.FuryofElune:IsCastable() and CDsON() and ((((Player:BuffStack(S.BOATNatureBuff) > 6 or Player:BuffStack(S.BOATArcaneBuff) > 6) and (CovenantID ~= 2 or Player:BuffDown(S.RavenousFrenzyBuff))) and ((not CDsON()) or CaInc:CooldownRemains() > 50 or (CovenantID == 3 and S.ConvoketheSpirits:CooldownRemains() > 50))) or (Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 8 and CaInc:CooldownRemains() > 10 and CovenantID == 4) or fightRemains < 8 and CaInc:CooldownDown() or CovenantID == 1 and Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID == 2 and Player:BuffRemains(S.RavenousFrenzyBuff) < 9 and Player:BuffUp(S.RavenousFrenzyBuff)) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune boat 8"; end
  end
  -- cancel_buff,name=starlord,if=(buff.balance_of_all_things_nature.remains>7.5|buff.balance_of_all_things_arcane.remains>7.5)&(cooldown.ca_inc.remains>7|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))&astral_power>=30
  -- starsurge,if=(buff.balance_of_all_things_nature.stack>2|buff.balance_of_all_things_arcane.stack>2)&((!covenant.night_fae|astral_power>=40)&cooldown.ca_inc.remains>7|!variable.cd_condition&!covenant.kyrian|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))&(!dot.fury_of_elune.ticking|!cooldown.ca_inc.ready|!cooldown.convoke_the_spirits.ready)
  if S.Starsurge:IsReady() and ((Player:BuffStack(S.BOATNatureBuff) > 2 or Player:BuffStack(S.BOATArcaneBuff) > 2) and ((CovenantID ~= 3 or Player:AstralPowerP() >= 40) and CaInc:CooldownRemains() > 7 or (not VarCDCondition) and CovenantID ~= 1 or (S.EmpowerBond:CooldownRemains() > 7 and Player:BuffDown(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1)) and (Target:DebuffDown(S.FuryofElune) or CaInc:CooldownDown() or S.ConvoketheSpirits:CooldownDown())) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge boat 10"; end
  end
  -- starsurge,if=(cooldown.convoke_the_spirits.remains<5&!druid.no_cds&(variable.convoke_desync|cooldown.ca_inc.remains<5)&variable.cd_condition)&!dot.fury_of_elune.ticking&covenant.night_fae&!druid.no_cds&eclipse.in_any&astral_power>40
  if S.Starsurge:IsReady() and ((S.ConvoketheSpirits:CooldownRemains() < 5 and CDsON() and (VarConvokeDesync or CaInc:CooldownRemains() < 5) and VarCDCondition) and FuryofEluneRemains == 0 and CovenantID == 3 and CDsON() and EclipseInAny and Player:AstralPowerP() > 40) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge boat 12"; end
  end
  -- variable,name=dot_requirements,value=(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)&(buff.kindred_empowerment_energize.remains<gcd.max)&(buff.eclipse_solar.remains>gcd.max|buff.eclipse_lunar.remains>gcd.max)
  VarDotRequirements = ((Player:BuffRemains(S.RavenousFrenzyBuff) > 5 or Player:BuffDown(S.RavenousFrenzyBuff)) and (Player:BuffRemains(S.KindredEmpowermentEnergizeBuff) < GCDMax) and (Player:BuffRemains(S.EclipseSolar) > GCDMax or Player:BuffRemains(S.EclipseLunar) > GCDMax))
  -- sunfire,target_if=refreshable&target.time_to_die>16,if=ap_check&variable.dot_requirements
  if S.Sunfire:IsCastable() and (AP_Check(S.Sunfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireBOAT, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire boat 14"; end
  end
  -- moonfire,target_if=refreshable&target.time_to_die>13.5,if=ap_check&variable.dot_requirements
  if S.Moonfire:IsCastable() and (AP_Check(S.Moonfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireBOAT, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire boat 16"; end
  end
  -- stellar_flare,target_if=refreshable&target.time_to_die>16+remains,if=ap_check&variable.dot_requirements
  if S.StellarFlare:IsCastable() and (AP_Check(S.StellarFlare) and VarDotRequirements) then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareBOAT, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare boat 18"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and CDsON() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature) then return "force_of_nature boat 20"; end
  end
  -- kindred_spirits,if=(eclipse.lunar_next|eclipse.solar_next|eclipse.any_next|buff.balance_of_all_things_nature.remains>7.5|buff.balance_of_all_things_arcane.remains>7.5|astral_power>90&cooldown.ca_inc.ready&!druid.no_cds)&(cooldown.ca_inc.remains>30|cooldown.ca_inc.ready)|interpolated_fight_remains<10
  if S.KindredSpirits:IsCastable() and ((EclipseLunarNext or EclipseSolarNext or EclipseAnyNext or Player:BuffRemains(S.BOATNatureBuff) > 7.5 or Player:BuffRemains(S.BOATArcaneBuff) > 7.5 or Player:AstralPowerP() > 90 and CaInc:CooldownUp() and CDsON()) and (CaInc:CooldownRemains() > 30 or CaInc:CooldownUp()) or fightRemains < 10) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant) then return "kindred_spirits boat 22"; end
  end
  -- fury_of_elune,if=cooldown.ca_inc.ready&variable.cd_condition&(astral_power>90&!covenant.night_fae|covenant.night_fae&astral_power<40)&!covenant.venthyr&(!covenant.night_fae|cooldown.convoke_the_spirits.ready)&!druid.no_cds
  if S.FuryofElune:IsCastable() and CDsON() and (CaInc:CooldownUp() and VarCDCondition and (Player:AstralPowerP() > 90 and CovenantID ~= 3 or CovenantID == 3 and Player:AstralPowerP() < 40) and CovenantID ~= 2 and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp()) and CDsON()) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune boat 24"; end
  end
  -- variable,name=cd_condition_boat,value=!druid.no_cds&variable.cd_condition&((astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|buff.bloodlust.up&buff.bloodlust.remains<buff.ca_inc.duration)|interpolated_fight_remains<buff.ca_inc.duration|covenant.night_fae)&(!covenant.night_fae|(astral_power<40|dot.fury_of_elune.ticking)&(variable.convoke_desync|cooldown.convoke_the_spirits.ready))
  VarCDConditionBOAT = (CDsON() and VarCDCondition and ((Player:AstralPowerP() > 90 and (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID ~= 1) or Player:BloodlustUp() and Player:BloodlustRemains() < CaInc:BaseDuration()) or fightRemains < CaInc:BaseDuration() or CovenantID == 3) and (CovenantID ~= 3 or (Player:AstralPowerP() < 40 or Target:DebuffUp(S.FuryofElune)) and (VarConvokeDesync or S.ConvoketheSpirits:CooldownUp())))
  if (CDsON()) then
    -- celestial_alignment,if=variable.cd_condition_boat
    if S.CelestialAlignment:IsCastable() and (VarCDConditionBOAT) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment boat 26"; end
    end
    -- incarnation,if=variable.cd_condition_boat
    if S.Incarnation:IsCastable() and (VarCDConditionBOAT) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation boat 28"; end
    end
  end
  -- variable,name=aspPerSec,value=eclipse.in_lunar*8%action.starfire.execute_time+!eclipse.in_lunar*(6+talent.soul_of_the_forest.enabled*3)%action.wrath.execute_time+0.2%spell_haste
  VarAspPerSec = (num(EclipseInLunar) * 8 / S.Starfire:ExecuteTime() + num(not EclipseInLunar) * (6 + num(S.SouloftheForest:IsAvailable()) * 3) / S.Wrath:ExecuteTime() + 0.2 / Player:SpellHaste())
  -- starsurge,if=(interpolated_fight_remains<4|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))|(astral_power+variable.aspPerSec*buff.eclipse_solar.remains+dot.fury_of_elune.ticks_remain*2.5>110|astral_power+variable.aspPerSec*buff.eclipse_lunar.remains+dot.fury_of_elune.ticks_remain*2.5>110)&eclipse.in_any&(!buff.ca_inc.up|!talent.starlord.enabled)&((!cooldown.ca_inc.up|covenant.kyrian&!cooldown.empower_bond.up)|covenant.night_fae)&(!covenant.venthyr|!buff.ca_inc.up|astral_power>90)|(talent.starlord.enabled&buff.ca_inc.up&(buff.starlord.stack<3|astral_power>90))|buff.ca_inc.up&!buff.ravenous_frenzy.up&!talent.starlord.enabled
  if S.Starsurge:IsReady() and ((fightRemains < 4 or (Player:BuffRemains(S.RavenousFrenzyBuff) < GCDMax * ceil(Player:AstralPowerP() / 30) and Player:BuffUp(S.RavenousFrenzyBuff))) or (Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseSolar) + FuryTicksRemain * 2.5 > 110 or Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseLunar) + FuryTicksRemain * 2.5 > 110) and EclipseInAny and (Player:BuffDown(CaInc) or not S.Starlord:IsAvailable()) and ((not CaInc:CooldownUp() or CovenantID == 1 and not S.EmpowerBond:CooldownUp()) or CovenantID == 3) and (CovenantID ~= 2 or Player:BuffDown(CaInc) or Player:AstralPowerP() > 90) or (S.Starlord:IsAvailable() and Player:BuffUp(CaInc) and (Player:BuffStack(S.StarlordBuff) < 3 or Player:AstralPowerP() > 90)) or Player:BuffUp(CaInc) and Player:BuffDown(S.RavenousFrenzyBuff) and not S.Starlord:IsAvailable()) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge boat 30"; end
  end
  -- new_moon,if=(buff.eclipse_lunar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.NewMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.NewMoon:ExecuteTime() or (S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5) or S.NewMoon:Charges() == 3) and AP_Check(S.NewMoon)) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon boat 32"; end
  end
  -- half_moon,if=(buff.eclipse_lunar.remains>execute_time&(cooldown.ca_inc.remains>50|cooldown.convoke_the_spirits.remains>50)|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.HalfMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.HalfMoon:ExecuteTime() and (CaInc:CooldownRemains() > 50 or S.ConvoketheSpirits:CooldownRemains() > 50) or (S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5) or S.HalfMoon:Charges() == 3) and AP_Check(S.HalfMoon)) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon boat 34"; end
  end
  -- full_moon,if=(buff.eclipse_lunar.remains>execute_time&(cooldown.ca_inc.remains>50|cooldown.convoke_the_spirits.remains>50)|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.FullMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() and (CaInc:CooldownRemains() > 50 or S.ConvoketheSpirits:CooldownRemains()) or (S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5) or S.FullMoon:Charges() == 3) and AP_Check(S.FullMoon)) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon boat 36"; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune boat 38"; end
  end
  -- starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
  if S.Starfire:IsCastable() and (EclipseInLunar or EclipseSolarNext or EclipseAnyNext or Player:BuffUp(S.WarriorofEluneBuff) and Player:BuffUp(S.EclipseLunar) or (Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc))) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire boat 40"; end
  end
  -- wrath
  if S.Wrath:IsCastable() then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath boat 42"; end
  end
  -- run_action_list,name=fallthru
  if (true) then
    local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount40y = #Enemies40y
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount40y = 1
    EnemiesCount8ySplash = 1
  end

  -- GCDMax is GCD plus half a second, to account for lag and player reaction time
  GCDMax = Player:GCD() + 0.5

  -- Length of fight remaining - Used for later variables
  fightRemains = HL.FightRemains(Enemies8ySplash, false)

  -- Determine amount of AP fed into Primordial Arcanic Pulsar
  -- TODO: Verify which slot holds the AP value
  PAPValue = 0
  if PAPEquipped then
    PAPValue = select(16, Player:BuffInfo(S.PAPBuff, false, true)) or 0
  end

  -- Check Fury of Elune
  if S.FuryofElune:IsAvailable() then
    FuryofEluneRemains = S.FuryofElune:CooldownRemains() - 51
    if FuryofEluneRemains < 0 then FuryofEluneRemains = 0 end
    FuryTicksRemain = FuryofEluneRemains * 2
  else
    FuryofEluneRemains = 0
    FuryTicksRemain = 0
  end

  -- Moonkin Form OOC, if setting is true
  if S.MoonkinForm:IsCastable() and Settings.Balance.ShowMoonkinFormOOC then
    if Cast(S.MoonkinForm) then return "moonkin_form ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Eclipse Check
    EclipseCheck()
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=is_aoe,value=spell_targets.starfall>1&(!talent.starlord.enabled|talent.stellar_drift.enabled)|spell_targets.starfall>2
    VarIsAoe = (EnemiesCount40y > 1 and (not S.Starlord:IsAvailable() or S.StellarDrift:IsAvailable()) or EnemiesCount40y > 2)
    -- variable,name=is_cleave,value=spell_targets.starfire>1
    VarIsCleave = (EnemiesCount8ySplash > 1)
    -- variable,name=in_gcd,value=prev_gcd.1.moonfire|prev_gcd.1.sunfire|prev_gcd.1.starsurge|prev_gcd.1.starfall|prev_gcd.1.fury_of_elune|prev.ravenous_frenzy|buff.ca_inc.remains=buff.ca_inc.duration|variable.is_aoe
    -- Ignoring this, as HR shouldn't need it
    -- Manually added: Opener function
    if HL.CombatTime() > 20 then OpenerFinished = true end
    if (not OpenerFinished and (CovenantID == 2 or CovenantID == 3)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- berserking,if=((!covenant.night_fae|!cooldown.convoke_the_spirits.up)&buff.ca_inc.remains>15&!covenant.venthyr|covenant.venthyr&buff.ca_inc.up&buff.ravenous_frenzy.up&(buff.ravenous_frenzy.remains<11-5*runeforge.sinful_hysteria|buff.ca_inc.remains<11|1%spell_haste<1.55))&variable.in_gcd
    if S.Berserking:IsCastable() and CDsON() and ((CovenantID ~= 3 or not S.ConvoketheSpirits:CooldownUp()) and Player:BuffRemains(CaInc) > 15 and CovenantID ~= 2 or CovenantID == 2 and Player:BuffUp(CaInc) and Player:BuffUp(S.RavenousFrenzyBuff) and (Player:BuffRemains(S.RavenousFrenzyBuff) < 11 - 5 * num(SinfulHysteriaEquipped) or Player:BuffRemains(CaInc) < 11 or 1 / Player:SpellHaste() < 1.55)) then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 2"; end
    end
    -- potion,if=(buff.ca_inc.remains>15&(!runeforge.sinful_hysteria|buff.ravenous_frenzy.remains<17-2*buff.bloodlust.up&buff.ravenous_frenzy.up)|fight_remains<25)&variable.in_gcd
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffRemains(CaInc) > 15 and ((not SinfulHysteriaEquipped) or Player:BuffRemains(S.RavenousFrenzyBuff) < 17 - 2 * num(Player:BloodlustUp()) and Player:BuffUp(S.RavenousFrenzyBuff)) or fightRemains < 25) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion 4"; end
    end
    -- variable,name=convoke_desync,value=ceil((fight_remains-15-cooldown.ca_inc.remains)%180)=ceil((fight_remains-15-cooldown.convoke_the_spirits.duration-cooldown.convoke_the_spirits.remains)%180)&!raid_event.adds.exists|cooldown.ca_inc.remains>interpolated_fight_remains|runeforge.celestial_spirits&cooldown.ca_inc.remains>30|cooldown.convoke_the_spirits.remains>interpolated_fight_remains-10|!covenant.night_fae
    if (CovenantID == 3) then
      local test1 = ceil((fightRemains - 15 - CaInc:CooldownRemains()) / 180)
      local test2 = ceil((fightRemains - 15 - 120 - S.ConvoketheSpirits:CooldownRemains()) / 180)
      VarConvokeDesync = (test1 == test2 and EnemiesCount8ySplash == 1 or CaInc:CooldownRemains() > fightRemains or CelestialSpiritsEquipped and CaInc:CooldownRemains() > 30 or S.ConvoketheSpirits:CooldownRemains() > fightRemains - 10 or CovenantID ~= 3)
    else
      VarConvokeDesync = true
    end
    -- variable,name=cd_condition,value=(target.time_to_die>15|raid_event.adds.in>50)&(((equipped.empyreal_ordnance&(cooldown.empyreal_ordnance.remains<160|covenant.venthyr&cooldown.empyreal_ordnance.remains<167+(11*runeforge.sinful_hysteria))&!cooldown.empyreal_ordnance.ready)|equipped.soulletting_ruby&(!covenant.night_fae|cooldown.soulletting_ruby_345801.remains<114)|(cooldown.berserking.ready|!race.troll)&((equipped.inscrutable_quantum_device&cooldown.inscrutable_quantum_device.ready)|(equipped.shadowed_orb_of_torment&cooldown.tormented_insight_355321.remains)|((variable.on_use_trinket=1|variable.on_use_trinket=3)&(trinket.1.ready_cooldown|trinket.1.cooldown.remains>interpolated_fight_remains-10)|variable.on_use_trinket=2&(trinket.2.ready_cooldown|trinket.2.cooldown.remains>interpolated_fight_remains-10)|variable.on_use_trinket=0)))|covenant.kyrian)|fight_remains<buff.ca_inc.duration
    VarCDCondition = (fightRemains > 15 and (((I.EmpyrealOrdinance:IsEquipped() and (I.EmpyrealOrdinance:CooldownRemains() < 160 or CovenantID == 2 and I.EmpyrealOrdinance:CooldownRemains() < 167 + (11 * num(SinfulHysteriaEquipped))) and not I.EmpyrealOrdinance:IsReady()) or I.SoullettingRuby:IsEquipped() and (CovenantID ~= 3 or I.SoullettingRuby:CooldownRemains() < 114) or (S.Berserking:CooldownUp() or Player:Race() ~= "Troll") and ((I.InscrutableQuantumDevice:IsEquippedAndReady()) or (I.ShadowedOrbofTorment:IsEquipped() and not I.ShadowedOrbofTorment:CooldownUp()) or ((VarOnUseTrinket == 1 or VarOnUseTrinket == 3) and (trinket1:IsReady() or trinket1:CooldownRemains() > fightRemains - 10) or VarOnUseTrinket == 2 and (trinket2:IsReady() or trinket2:CooldownRemains() > fightRemains - 10) or VarOnUseTrinket == 0))) or CovenantID == 1) or fightRemains < CaInc:BaseDuration())
    -- variable,name=thrill_seeker_wait,value=!soulbind.thrill_seeker.enabled|fight_remains>200|fight_remains<25+(40-buff.thrill_seeker.stack*2)|buff.thrill_seeker.stack>38-(runeforge.sinful_hysteria*5)
    VarThrillSeekerWait = ((not S.ThrillSeeker:SoulbindEnabled()) or fightRemains > 200 or fightRemains < 25 + (40 - Player:BuffStack(S.ThrillSeekerBuff) * 2) or Player:BuffStack(S.ThrillSeekerBuff) > 38 - (num(SinfulHysteriaEquipped) * 5))
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=empyreal_ordnance,if=cooldown.ca_inc.remains<20&cooldown.convoke_the_spirits.remains<20&(variable.thrill_seeker_wait|buff.thrill_seeker.stack>30+(runeforge.sinful_hysteria*6))&variable.in_gcd|fight_remains<37
      if I.EmpyrealOrdinance:IsEquippedAndReady() and (CaInc:CooldownRemains() < 20 and S.ConvoketheSpirits:CooldownRemains() < 20 and (VarThrillSeekerWait or Player:BuffStack(S.ThrillSeekerBuff) > 30 + (num(SinfulHysteriaEquipped) * 6)) or fightRemains < 37) then
        if Cast(I.EmpyrealOrdinance, nil, Settings.Commons.DisplayStyle.Trinkets) then return "empyreal_ordnance main 6"; end
      end
      -- use_item,name=soulletting_ruby,if=(cooldown.ca_inc.remains<6&!covenant.venthyr&!covenant.night_fae|covenant.night_fae&cooldown.convoke_the_spirits.remains<6&(variable.convoke_desync|cooldown.ca_inc.remains<6)|covenant.venthyr&(!runeforge.sinful_hysteria&cooldown.ca_inc.remains<6|buff.ravenous_frenzy.remains<14+(5*equipped.instructors_divine_bell)&buff.ravenous_frenzy.up)|fight_remains<25|equipped.empyreal_ordnance&cooldown.empyreal_ordnance.remains>20)&variable.in_gcd&!equipped.inscrutable_quantum_device|cooldown.inscrutable_quantum_device.remains>20|fight_remains<20
      if I.SoullettingRuby:IsEquippedAndReady() and ((CaInc:CooldownRemains() < 6 and CovenantID ~= 2 and CovenantID ~= 3 or CovenantID == 3 and S.ConvoketheSpirits:CooldownRemains() < 6 and (VarConvokeDesync or CaInc:CooldownRemains() < 6) or CovenantID == 2 and ((not SinfulHysteriaEquipped) and CaInc:CooldownRemains() < 6 or Player:BuffRemains(S.RavenousFrenzyBuff) < 14 + (5 * num(I.InstructorsDivineBell:IsEquipped())) and Player:BuffUp(S.RavenousFrenzyBuff)) or fightRemains < 25 or I.EmpyrealOrdinance:IsEquipped() and I.EmpyrealOrdinance:CooldownRemains() > 20) and (not I.InscrutableQuantumDevice:IsEquipped()) or I.InscrutableQuantumDevice:CooldownRemains() > 20 or fightRemains < 20) then
        if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby main 8"; end
      end
      -- variable,name=iqd_condition,value=buff.ca_inc.remains>15&(!runeforge.sinful_hysteria|buff.ravenous_frenzy.remains<=12.2+(3*buff.bloodlust.up)+(8-5*buff.bloodlust.up)*equipped.instructors_divine_bell&buff.ravenous_frenzy.up)|fight_remains<25|equipped.empyreal_ordnance&cooldown.empyreal_ordnance.remains
      VarIQDCondition = (CDsON() and Player:BuffRemains(CaInc) > 15 and ((not SinfulHysteriaEquipped) or Player:BuffRemains(S.RavenousFrenzyBuff) <= 12.2 + (3 * num(Player:BloodlustUp())) + (8 - 5 * num(Player:BloodlustUp())) * num(I.InstructorsDivineBell:IsEquipped()) and Player:BuffUp(S.RavenousFrenzyBuff)) or fightRemains < 25 or I.EmpyrealOrdinance:IsEquipped() and not I.EmpyrealOrdinance:CooldownUp())
      -- use_item,name=inscrutable_quantum_device,if=variable.iqd_condition&variable.in_gcd
      if I.InscrutableQuantumDevice:IsEquippedAndReady() and (VarIQDCondition) then
        if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device main 10"; end
      end
      -- use_item,name=shadowed_orb_of_torment,if=(cooldown.ca_inc.ready&!covenant.night_fae&variable.thrill_seeker_wait&(cooldown.berserking.ready|!race.troll)|covenant.night_fae&cooldown.convoke_the_spirits.ready&(variable.convoke_desync|cooldown.ca_inc.ready))&dot.sunfire.ticking&(dot.stellar_flare.ticking|!talent.stellar_flare.enabled|spell_targets.starfire>3)&dot.moonfire.ticking&(variable.is_aoe|runeforge.balance_of_all_things|astral_power>=90|variable.convoke_desync|buff.bloodlust.up)&!equipped.inscrutable_quantum_device|equipped.inscrutable_quantum_device&cooldown.inscrutable_quantum_device.remains>30&!buff.ca_inc.up|fight_remains<40
      if I.ShadowedOrbofTorment:IsEquippedAndReady() and ((CaInc:CooldownUp() and CovenantID ~= 3 and VarThrillSeekerWait and (S.Berserking:CooldownUp() or Player:Race() ~= "Troll") or CovenantID == 3 and S.ConvoketheSpirits:CooldownUp() and (VarConvokeDesync or CaInc:CooldownUp())) and Target:DebuffUp(S.SunfireDebuff) and (Target:DebuffUp(S.StellarFlareDebuff) or (not S.StellarFlare:IsAvailable()) or EnemiesCount8ySplash > 3) and Target:DebuffUp(S.MoonfireDebuff) and (VarIsAoe or BOATEquipped or Player:AstralPowerP() >= 90 or VarConvokeDesync or Player:BloodlustUp()) and (not I.InscrutableQuantumDevice:IsEquipped()) or I.InscrutableQuantumDevice:IsEquipped() and I.InscrutableQuantumDevice:CooldownRemains() > 30 and Player:BuffDown(CaInc) or fightRemains < 40) then
        if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment main 11"; end
      end
      -- use_items,slots=trinket1,if=(variable.on_use_trinket!=1&!trinket.2.ready_cooldown|(variable.on_use_trinket=1|variable.on_use_trinket=3)&(buff.ca_inc.up&(!covenant.venthyr|buff.ravenous_frenzy.remains+(5*runeforge.sinful_hysteria)<=trinket.1.proc.any.duration&buff.ravenous_frenzy.up|buff.ravenous_frenzy_sinful_hysteria.up)|cooldown.ca_inc.remains+2>trinket.1.cooldown.duration&!buff.ca_inc.up&(!covenant.night_fae|!variable.convoke_desync)&!covenant.kyrian|covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.up&!cooldown.ca_inc.up&((buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)&!runeforge.balance_of_all_things|(buff.balance_of_all_things_nature.stack=5|buff.balance_of_all_things_arcane.stack=8))|buff.kindred_empowerment_energize.up)|fight_remains<20|variable.on_use_trinket=0)&variable.in_gcd
      -- Temporarily held until we can get trinket.x.proc.any.duration figured out
      --if trinket1:IsReady() and () then
        --if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 main 12"; end
      --end
      -- use_items,slots=trinket2,if=(variable.on_use_trinket!=2&!trinket.1.ready_cooldown|variable.on_use_trinket=2&(buff.ca_inc.up&(!covenant.venthyr|buff.ravenous_frenzy.remains+(5*runeforge.sinful_hysteria)<=trinket.2.proc.any.duration&buff.ravenous_frenzy.up|buff.ravenous_frenzy_sinful_hysteria.up)|cooldown.ca_inc.remains+2>trinket.2.cooldown.duration&!buff.ca_inc.up&(!covenant.night_fae|!variable.convoke_desync)&!covenant.kyrian&(!buff.ca_inc.up|!covenant.venthyr)|covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.up&!cooldown.ca_inc.up&((buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)&!runeforge.balance_of_all_things|(buff.balance_of_all_things_nature.stack=5|buff.balance_of_all_things_arcane.stack=8)))|buff.kindred_empowerment_energize.up|fight_remains<20|variable.on_use_trinket=0)&variable.in_gcd
      -- Temporarily held until we can get trinket.x.proc.any.duration figured out
      --if trinket2:IsReady() and () then
        --if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 main 14"; end
      --end
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    else
      VarIQDCondition = false
    end
    -- run_action_list,name=aoe,if=variable.is_aoe
    if (VarIsAoe) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=boat,if=runeforge.balance_of_all_things.equipped
    if (BOATEquipped) then
      local ShouldReturn = Boat(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=st
    if (true) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function OnInit()
  HR.Print("Balance Druid rotation is currently a work in progress, but has been updated for patch 9.1.")
end

HR.SetAPL(102, APL, OnInit)
