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
local Druid = HR.Commons.Druid

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
local VarDotRequirements
local VarSaveForCAInc
local VarDreamWillFallOff
local VarIgnoreStarsurge
local VarStarfallWontFallOff
local VarStarfireinSolar
local VarCritNotUp
local VarAspPerSec
local GCDMax
local PAPValue
local fightRemains

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local Covenants = _G.C_Covenants
local CovenantID = Covenants.GetActiveCovenantID()

-- CA/Incarnation Variable
local CaInc = S.Incarnation:IsAvailable() and S.Incarnation or S.CelestialAlignment

-- Eclipse Variables
local InEclipse = false
local EclipseState = 0 -- 0 = any_next, 1 = in_solar, 2 = in_lunar, 3 = in_both, 4 = solar_next, 5 = lunar_next
local EclipseTable = { [0] = "any_next", [1] = "in_solar", [2] = "in_lunar", [3] = "in_both", [4] = "solar_next", [5] = "lunar_next" }

-- Precise Alignment Variables
local PreciseAlignmentTimeTable = { 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12 }
local PATime = S.PreciseAlignment:ConduitEnabled() and PreciseAlignmentTimeTable[S.PreciseAlignment:ConduitRank()] or 0

-- Legendaries
local PAPEquipped = Player:HasLegendaryEquipped(51)
local BOATEquipped = Player:HasLegendaryEquipped(52)
local LycaraEquipped = Player:HasLegendaryEquipped(48)
local OnethsEquipped = Player:HasLegendaryEquipped(50)
local TimewornEquipped = Player:HasLegendaryEquipped(53)

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
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  InEclipse = false
  EclipseState = 0
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
  CovenantID = Covenants.GetActiveCovenantID()
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
  return (TargetUnit:DebuffRemains(S.MoonfireDebuff) > (TargetUnit:DebuffRemains(S.SunfireDebuff) * 22 % 18))
end

local function EvaluateCycleAdaptiveSwarmST(TargetUnit)
  return (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() and (Player:BuffDown(S.AdaptiveSwarmHeal) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 5) or TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffUp(S.AdaptiveSwarmDebuff))
end

local function EvaluateCycleMoonfireST(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > 12)
end

local function EvaluateCycleSunfireST(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and TargetUnit:TimeToDie() > 12)
end

local function EvaluateCycleStellarFlareST(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and TargetUnit:TimeToDie() > 16)
end

local function EvaluateCycleSunfireAoe(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.SunfireDebuff) or Player:BuffRemains(S.EclipseSolar) < 3 and EclipseState == 1 and TargetUnit:DebuffRemains(S.SunfireDebuff) < 14 and S.SouloftheForest:IsAvailable()) and TargetUnit:TimeToDie() > 14 - EnemiesCount8ySplash + TargetUnit:DebuffRemains(S.SunfireDebuff) and ((EclipseState == 1 or EclipseState == 2 or EclipseState == 3) or TargetUnit:DebuffRemains(S.SunfireDebuff) < GCDMax))
end

local function EvaluateCycleAdaptiveSwarmAoe(TargetUnit)
  return (TargetUnit:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() or TargetUnit:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and TargetUnit:DebuffRemains(S.AdaptiveSwarmDebuff) < 3)
end

local function EvaluateCycleMoonfireAoe(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and TargetUnit:TimeToDie() > ((14 + (EnemiesCount8ySplash * 2 * num(Player:BuffUp(S.EclipseLunar)))) + TargetUnit:DebuffRemains(S.MoonfireDebuff)) % (1 + num(S.TwinMoons:IsAvailable())))
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
  if (Player:BuffUp(S.EclipseSolar) and Player:BuffUp(S.EclipseLunar)) then
    EclipseState = 3
  elseif (Player:BuffUp(S.EclipseLunar) and Player:BuffDown(S.EclipseSolar)) then
    EclipseState = 2
  elseif (Player:BuffUp(S.EclipseSolar) and Player:BuffDown(S.EclipseLunar)) then
    EclipseState = 1
  end
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
  -- moonkin_form
  if S.MoonkinForm:IsCastable() then
    if Cast(S.MoonkinForm) then return "moonkin_form precombat"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and not Player:IsCasting(S.Wrath) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 2"; end
  end
  -- wrath
  if S.Wrath:IsCastable() then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath precombat 4"; end
  end
  -- Moved Starfire/Starsuge lines to Opener function
end

local function Opener()
  -- starfire,if=!runeforge.balance_of_all_things|!covenant.night_fae|!spell_targets.starfall=1|!talent.natures_balance.enabled
  if S.Starfire:IsCastable() and not Player:IsCasting(S.Starfire) and (not BOATEquipped or CovenantID ~= 3 or not EnemiesCount40y == 1 or not S.NaturesBalance:IsAvailable()) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire opener 2"; end
  end
  -- starsurge,if=runeforge.balance_of_all_things&covenant.night_fae&spell_targets.starfall=1
  if S.Starsurge:IsReady() and (BOATEquipped and CovenantID == 3 and EnemiesCount40y == 1) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge opener 4"; end
  end
end

local function Fallthru()
  -- starsurge,if=!runeforge.balance_of_all_things.equipped
  if S.Starsurge:IsReady() and (not BOATEquipped) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge fallthru 2"; end
  end
  -- sunfire,target_if=dot.moonfire.remains>remains*22%18
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies8ySplash, EvaluateCycleSunfireFallthru, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire fallthru 4"; end
  end
  -- moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire fallthru 6"; end
  end
end

local function St()
  -- ravenous_frenzy,if=buff.ca_inc.remains>15
  if S.RavenousFrenzy:IsCastable() and (Player:BuffRemains(CaInc) > 15) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RavenousFrenzy)) then return "ravenous_frenzy st 2"; end
  end
  -- starsurge,if=runeforge.timeworn_dreambinder.equipped&(eclipse.in_any&!((buff.timeworn_dreambinder.remains>action.wrath.execute_time+0.1&(eclipse.in_both|eclipse.in_solar|eclipse.lunar_next)|buff.timeworn_dreambinder.remains>action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))|!buff.timeworn_dreambinder.up)|(buff.ca_inc.up|variable.convoke_desync)&cooldown.convoke_the_spirits.ready&covenant.night_fae)&(!covenant.kyrian|cooldown.empower_bond.remains>8)&(buff.ca_inc.up|!cooldown.ca_inc.ready)
  if S.Starsurge:IsReady() and (TimewornEquipped and (InEclipse and not ((Player:BuffRemains(S.TimewornDreambinderBuff) > (S.Wrath:ExecuteTime() + 0.1) and (EclipseState == 3 or EclipseState == 1 or EclipseState == 5) or Player:BuffRemains(S.TimewornDreambinderBuff) > (S.Starfire:ExecuteTime() + 0.6) and (EclipseState == 2 or EclipseState == 4 or EclipseState == 0)) or Player:BuffDown(S.TimewornDreambinderBuff)) or (Player:BuffUp(CaInc) or VarConvokeDesync) and S.ConvoketheSpirits:CooldownUp() and CovenantID == 3) and (CovenantID ~= 1 or S.EmpowerBond:CooldownRemains() > 8) and (Player:BuffUp(CaInc) or not CaInc:CooldownUp())) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 4"; end
  end
  -- adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>5)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3&dot.adaptive_swarm_damage.ticking
  if S.AdaptiveSwarm:IsCastable() then
    if Everyone.CastCycle(S.AdaptiveSwarm, Enemies8ySplash, EvaluateCycleAdaptiveSwarmST, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm st 6"; end
  end
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready|buff.ca_inc.up)&astral_power<40&(buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)|fight_remains<10)
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and not CaInc:CooldownUp() or Player:BuffUp(CaInc)) and Player:AstralPowerP() < 40 and (Player:BuffRemains(S.EclipseLunar) > 10 or Player:BuffRemains(S.EclipseSolar) > 10) or fightRemains < 10)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ConvoketheSpirits)) then return "convoke_the_spirits st 8"; end
  end
  -- variable,name=dot_requirements,value=(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)&(buff.kindred_empowerment_energize.remains<gcd.max)&(buff.eclipse_solar.remains>gcd.max|buff.eclipse_lunar.remains>gcd.max)
  VarDotRequirements = ((Player:BuffRemains(S.RavenousFrenzyBuff) > 5 or Player:BuffDown(S.RavenousFrenzyBuff)) and (Player:BuffRemains(S.KindredEmpowermentEnergizeBuff) < GCDMax) and (Player:BuffRemains(S.EclipseSolar) > GCDMax or Player:BuffRemains(S.EclipseLunar) > GCDMax))
  -- moonfire,target_if=refreshable&target.time_to_die>12,if=ap_check&variable.dot_requirements
  if S.Moonfire:IsCastable() and (AP_Check(S.Moonfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Moonfire, Enemies8ySplash, EvaluateCycleMoonfireST, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire st 10"; end
  end
  -- sunfire,target_if=refreshable&target.time_to_die>12,if=ap_check&variable.dot_requirements
  if S.Sunfire:IsCastable() and (AP_Check(S.Sunfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Sunfire, Enemies8ySplash, EvaluateCycleSunfireST, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire st 12"; end
  end
  -- stellar_flare,target_if=refreshable&target.time_to_die>16,if=ap_check&variable.dot_requirements
  if S.StellarFlare:IsCastable() and (AP_Check(S.StellarFlare) and VarDotRequirements) then
    if Everyone.CastCycle(S.StellarFlare, Enemies8ySplash, EvaluateCycleStellarFlareST, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare st 14"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceofNature, nil, not Target:IsInRange(45)) then return "force_of_nature st 16"; end
  end
  -- kindred_spirits,if=((buff.eclipse_solar.remains>10|buff.eclipse_lunar.remains>10)&cooldown.ca_inc.remains>30&(buff.primordial_arcanic_pulsar.value<240|!runeforge.primordial_arcanic_pulsar.equipped))|buff.primordial_arcanic_pulsar.value>=270|cooldown.ca_inc.ready&astral_power>90
  if S.KindredSpirits:IsCastable() and (((Player:BuffRemains(S.EclipseSolar) > 10 or Player:BuffRemains(S.EclipseLunar) > 10) and CaInc:CooldownRemains() > 30 and (PAPValue < 240 or not PAPEquipped)) or PAPValue >= 270 or CaInc:CooldownUp() and Player:AstralPowerP() > 90) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.KindredSpirits)) then return "kindred_spirits st 18"; end
  end
  -- celestial_alignment,if=!druid.no_cds&variable.cd_condition&(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|buff.bloodlust.up&buff.bloodlust.remains<20+((9*runeforge.primordial_arcanic_pulsar.equipped)+(conduit.precise_alignment.time_value)))&!buff.ca_inc.up&(!covenant.night_fae|cooldown.convoke_the_spirits.up|interpolated_fight_remains<cooldown.convoke_the_spirits.remains+6|interpolated_fight_remains%%180<20+(conduit.precise_alignment.time_value))
  if S.CelestialAlignment:IsCastable() and (CDsON() and VarCDCondition and (Player:AstralPowerP() > 90 and (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID ~= 1) or CovenantID == 3 or Player:BloodlustUp() and Player:BloodlustRemains() < 20 + ((9 * num(PAPEquipped)) + PATime)) and Player:BuffDown(CaInc) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() or fightRemains < (S.ConvoketheSpirits:CooldownRemains() + 6) or fightRemains % 180 < 20 + PATime)) then
    if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment st 20"; end
  end
  -- incarnation,if=!druid.no_cds&variable.cd_condition&(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|buff.bloodlust.up&buff.bloodlust.remains<30+((9*runeforge.primordial_arcanic_pulsar.equipped)+(conduit.precise_alignment.time_value)))&!buff.ca_inc.up&(!covenant.night_fae|cooldown.convoke_the_spirits.up|interpolated_fight_remains<cooldown.convoke_the_spirits.remains+6|interpolated_fight_remains%%180<30+(conduit.precise_alignment.time_value))
  if S.Incarnation:IsCastable() and (CDsON() and VarCDCondition and (Player:AstralPowerP() > 90 and (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID ~= 1) or CovenantID == 3 or Player:BloodlustUp() and Player:BloodlustRemains() < 30 + ((9 * num(PAPEquipped)) + PATime)) and Player:BuffDown(CaInc) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() or fightRemains < (S.ConvoketheSpirits:CooldownRemains() + 6) or fightRemains % 180 < 30 + PATime)) then
    if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation st 22"; end
  end
  -- variable,name=save_for_ca_inc,value=!cooldown.ca_inc.ready|!variable.convoke_desync&covenant.night_fae|druid.no_cds
  VarSaveForCAInc = (not CaInc:CooldownUp() or not VarConvokeDesync and CovenantID == 3 or not CDsON())
  -- fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<240&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord)&variable.save_for_ca_inc
  if S.FuryofElune:IsCastable() and ((EclipseState == 1 or EclipseState == 2 or EclipseState == 3) and AP_Check(S.FuryofElune) and PAPValue < 240 and (Target:DebuffUp(S.AdaptiveSwarmDebuff) or CovenantID ~= 4) and VarSaveForCAInc) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryofElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune st 24"; end
  end
  -- starfall,if=buff.oneths_perception.up&buff.starfall.refreshable
  if S.Starfall:IsReady() and (Player:BuffUp(S.OnethsPerceptionBuff) and Player:BuffRefreshable(S.StarfallBuff)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 26"; end
  end
  -- cancel_buff,name=starlord,if=buff.starlord.remains<5&(buff.eclipse_solar.remains>5|buff.eclipse_lunar.remains>5)&astral_power>90
  -- starsurge,if=covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.remains<5&!druid.no_cds
  if S.Starsurge:IsReady() and (CovenantID == 3 and VarConvokeDesync and S.ConvoketheSpirits:CooldownRemains() < 5 and CDsON()) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 28"; end
  end
  -- starfall,if=talent.stellar_drift.enabled&!talent.starlord.enabled&buff.starfall.refreshable&(buff.eclipse_lunar.remains>6&eclipse.in_lunar&buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250&astral_power>90|dot.adaptive_swarm_damage.remains>8|action.adaptive_swarm_damage.in_flight)&!cooldown.ca_inc.ready
  if S.Starfall:IsReady() and (S.StellarDrift:IsAvailable() and not S.Starlord:IsAvailable() and Player:BuffRefreshable(S.StarfallBuff) and (Player:BuffRemains(S.EclipseLunar) > 6 and EclipseState == 2 and PAPValue < 250 or PAPValue >= 250 and Player:AstralPowerP() > 90 or Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 8 or S.AdaptiveSwarm:InFlight()) and not CaInc:CooldownUp()) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 30"; end
  end
  -- starsurge,if=buff.oneths_clear_vision.up|buff.kindred_empowerment_energize.up|buff.ca_inc.up&(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up&!cooldown.ravenous_frenzy.ready|!covenant.venthyr)|astral_power>90&eclipse.in_any
  if S.Starsurge:IsReady() and (Player:BuffUp(S.OnethsClearVisionBuff) or Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or Player:BuffUp(CaInc) and (Player:BuffRemains(S.RavenousFrenzyBuff) < (GCDMax * ceil(Player:AstralPowerP() % 30)) and Player:BuffUp(S.RavenousFrenzyBuff) or Player:BuffDown(S.RavenousFrenzyBuff) and not S.RavenousFrenzy:CooldownUp() or CovenantID ~= 2) or Player:AstralPowerP() > 90 and (EclipseState == 1 or EclipseState == 2 or EclipseState == 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 32"; end
  end
  -- starsurge,if=talent.starlord.enabled&!runeforge.timeworn_dreambinder.equipped&(buff.starlord.up|astral_power>90)&buff.starlord.stack<3&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&buff.primordial_arcanic_pulsar.value<270&(cooldown.ca_inc.remains>10|!variable.convoke_desync&covenant.night_fae)
  if S.Starsurge:IsReady() and (S.Starlord:IsAvailable() and not TimewornEquipped and (Player:BuffUp(S.StarlordBuff) or Player:AstralPowerP() > 90) and Player:BuffStack(S.StarlordBuff) < 3 and (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar)) and PAPValue < 270 and (CaInc:CooldownRemains() > 10 or not VarConvokeDesync and CovenantID == 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 34"; end
  end
  -- starsurge,if=!runeforge.timeworn_dreambinder.equipped&(buff.primordial_arcanic_pulsar.value<270|buff.primordial_arcanic_pulsar.value<250&talent.stellar_drift.enabled)&buff.eclipse_solar.remains>7&eclipse.in_solar&!buff.oneths_perception.up&!talent.starlord.enabled&cooldown.ca_inc.remains>7&(cooldown.kindred_spirits.remains>7|!covenant.kyrian)
  if S.Starsurge:IsReady() and (not TimewornEquipped and (PAPValue < 270 or PAPValue < 250 and S.StellarDrift:IsAvailable()) and Player:BuffRemains(S.EclipseSolar) > 7 and EclipseState == 1 and Player:BuffDown(S.OnethsPerceptionBuff) and not S.Starlord:IsAvailable() and CaInc:CooldownRemains() > 7 and (S.KindredSpirits:CooldownRemains() > 7 or CovenantID ~= 1)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 36"; end
  end
  -- new_moon,if=(buff.eclipse_lunar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
  if S.NewMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.NewMoon:ExecuteTime() or (S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5) or S.NewMoon:Charges() == 3) and AP_Check(S.NewMoon) and VarSaveForCAInc) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon st 38"; end
  end
  -- half_moon,if=(buff.eclipse_lunar.remains>execute_time&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
  if S.HalfMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.HalfMoon:ExecuteTime() and CovenantID ~= 1 or (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1) or (S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5) or S.HalfMoon:Charges() == 3 or Player:BuffUp(CaInc)) and AP_Check(S.HalfMoon) and VarSaveForCAInc) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon st 40"; end
  end
  -- full_moon,if=(buff.eclipse_lunar.remains>execute_time&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
  if S.FullMoon:IsCastable() and ((Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() and CovenantID ~= 1 or (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1) or (S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5) or S.FullMoon:Charges() == 3 or Player:BuffUp(CaInc)) and AP_Check(S.FullMoon) and VarSaveForCAInc) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon st 42"; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorofElune) then return "warrior_of_elune st 44"; end
  end
  -- starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
  if S.Starfire:IsCastable() and (EclipseState == 2 or EclipseState == 4 or EclipseState == 0 or Player:BuffUp(S.WarriorofEluneBuff) and Player:BuffUp(S.EclipseLunar) or (Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc))) then
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
  -- variable,name=dream_will_fall_off,value=(buff.timeworn_dreambinder.remains<gcd.max+0.1|buff.timeworn_dreambinder.remains<action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))&buff.timeworn_dreambinder.up&runeforge.timeworn_dreambinder.equipped
  -- Moved TimewornEquipped to the front to abort as quickly as possible if it's not equipped
  VarDreamWillFallOff = (TimewornEquipped and (Player:BuffRemains(S.TimewornDreambinderBuff) < (GCDMax + 0.1) or Player:BuffRemains(S.TimewornDreambinderBuff) < (S.Starfire:ExecuteTime() + 0.1) and (EclipseState == 2 or EclipseState == 4 or EclipseState == 0)) and Player:BuffUp(S.TimewornDreambinderBuff))
  -- variable,name=ignore_starsurge,value=!eclipse.in_solar&(spell_targets.starfire>5&talent.soul_of_the_forest.enabled|spell_targets.starfire>7)
  VarIgnoreStarsurge = (EclipseState ~= 1 and (EnemiesCount8ySplash > 5 and S.SouloftheForest:IsAvailable() or EnemiesCount8ySplash > 7))
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready|buff.ca_inc.up)&(astral_power<50|variable.ignore_starsurge)&(buff.eclipse_lunar.remains>6|buff.eclipse_solar.remains>6)&(!runeforge.balance_of_all_things|buff.balance_of_all_things_nature.stack>3|buff.balance_of_all_things_arcane.stack>3)|fight_remains<10)
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and not CaInc:CooldownUp() or Player:BuffUp(CaInc)) and (Player:AstralPowerP() < 50 or VarIgnoreStarsurge) and (Player:BuffRemains(S.EclipseLunar) > 6 or Player:BuffRemains(S.EclipseSolar) > 6) and (not BOATEquipped or Player:BuffStack(S.BOATNatureBuff) > 3 or Player:BuffStack(S.BOATArcaneBuff) > 3) or fightRemains < 10)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ConvoketheSpirits)) then return "convoke_the_spirits aoe 2"; end
  end
  -- ravenous_frenzy,if=buff.ca_inc.remains>15
  if S.RavenousFrenzy:IsCastable() and (Player:BuffRemains(CaInc) > 15) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RavenousFrenzy)) then return "ravenous_frenzy aoe 4"; end
  end
  -- sunfire,target_if=(refreshable|buff.eclipse_solar.remains<3&eclipse.in_solar&remains<14&talent.soul_of_the_forest.enabled)&target.time_to_die>14-spell_targets+remains&(eclipse.in_any|remains<gcd.max),if=
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireAoe, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire aoe 6"; end
  end
  -- starfall,if=(buff.starfall.refreshable&(spell_targets.starfall<3|!runeforge.timeworn_dreambinder.equipped)|talent.soul_of_the_forest.enabled&buff.eclipse_solar.remains<3&eclipse.in_solar&buff.starfall.remains<7&spell_targets.starfall>=4)&(!runeforge.lycaras_fleeting_glimpse.equipped|time%%45>buff.starfall.remains+2)&target.time_to_die>5
  if S.Starfall:IsReady() and ((Player:BuffRefreshable(S.StarfallBuff) and (EnemiesCount40y < 3 or not TimewornEquipped) or S.SouloftheForest:IsAvailable() and Player:BuffRemains(S.EclipseSolar) < 3 and EclipseState == 1 and Player:BuffRemains(S.StarfallBuff) < 7 and EnemiesCount40y >= 4) and (not LycaraEquipped or HL.CombatTime() % 45 > Player:BuffRemains(S.StarfallBuff) + 2) and Target:TimeToDie() > 5) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 8"; end
  end
  -- starfall,if=runeforge.timeworn_dreambinder.equipped&spell_targets.starfall>=3&(!buff.timeworn_dreambinder.up&buff.starfall.refreshable|(variable.dream_will_fall_off&(buff.starfall.remains<3|spell_targets.starfall>2&talent.stellar_drift.enabled&buff.starfall.remains<5)))
  if S.Starfall:IsReady() and (TimewornEquipped and EnemiesCount40y >= 3 and (Player:BuffDown(S.TimewornDreambinderBuff) and Player:BuffRefreshable(S.StarfallBuff) or (VarDreamWillFallOff and (Player:BuffRemains(S.StarfallBuff) < 3 or EnemiesCount40y > 2 and S.StellarDrift:IsAvailable() and Player:BuffRemains(S.StarfallBuff) < 5)))) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 10"; end
  end
  -- variable,name=starfall_wont_fall_off,value=astral_power>80-(10*buff.timeworn_dreambinder.stack)-(buff.starfall.remains*3%spell_haste)-(dot.fury_of_elune.remains*5)&buff.starfall.up
  local FuryofEluneRemains = S.FuryofElune:CooldownRemains() - 51
  if FuryofEluneRemains < 0 then FuryofEluneRemains = 0 end
  VarStarfallWontFallOff = (Player:AstralPowerP() > (80 - (10 * Player:BuffStack(S.TimewornDreambinderBuff)) - (Player:BuffRemains(S.StarfallBuff) * 3 % (Player:HastePct() / 100)) - (FuryofEluneRemains * 5)) and Player:BuffUp(S.StarfallBuff))
  -- starsurge,if=variable.dream_will_fall_off&variable.starfall_wont_fall_off&!variable.ignore_starsurge|(buff.balance_of_all_things_nature.stack>3|buff.balance_of_all_things_arcane.stack>3)&spell_targets.starfall<4&variable.starfall_wont_fall_off
  if S.Starsurge:IsReady() and (VarDreamWillFallOff and VarStarfallWontFallOff and not VarIgnoreStarsurge or (Player:BuffStack(S.BOATNatureBuff) > 3 or Player:BuffStack(S.BOATArcaneBuff) > 3) and EnemiesCount40y < 4 and VarStarfallWontFallOff) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 12"; end
  end
  -- adaptive_swarm,target_if=!ticking&!action.adaptive_swarm_damage.in_flight|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3
  if S.AdaptiveSwarm:IsCastable() then
    if Everyone.CastCycle(S.AdaptiveSwarm, Enemies40y, EvaluateCycleAdaptiveSwarmAoe, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm aoe 14"; end
  end
  -- moonfire,target_if=refreshable&target.time_to_die>((14+(spell_targets.starfire*2*buff.eclipse_lunar.up))+remains)%(1+talent.twin_moons.enabled),if=(cooldown.ca_inc.ready&!druid.no_cds&(variable.convoke_desync|cooldown.convoke_the_spirits.ready|!covenant.night_fae)|spell_targets.starfire<((6-(buff.eclipse_lunar.up*2))*(1+talent.twin_moons.enabled))&!eclipse.solar_next|(eclipse.in_solar|(eclipse.in_both|eclipse.in_lunar)&!talent.soul_of_the_forest.enabled|buff.primordial_arcanic_pulsar.value>=250)&(spell_targets.starfire<10*(1+talent.twin_moons.enabled))&astral_power>50-buff.starfall.remains*6)&(!buff.kindred_empowerment_energize.up|eclipse.in_solar|!covenant.kyrian)
  if S.Moonfire:IsCastable() and ((CaInc:CooldownUp() and CDsON() and (VarConvokeDesync or S.ConvoketheSpirits:CooldownUp() or CovenantID ~= 3) or EnemiesCount8ySplash < ((6 - (num(Player:BuffUp(S.EclipseLunar)) * 2)) * (1 + num(S.TwinMoons:IsAvailable()))) and EclipseState ~= 4 or (EclipseState == 1 or (EclipseState == 3 or EclipseState == 2) and not S.SouloftheForest:IsAvailable() or PAPValue >= 250) and (EnemiesCount8ySplash < 10 * (1 + num(S.TwinMoons:IsAvailable()))) and Player:AstralPowerP() > 50 - Player:BuffRemains(S.StarfallBuff) * 6) and (Player:BuffDown(S.KindredEmpowermentEnergizeBuff) or EclipseState == 1 or CovenantID ~= 1)) then
    if Everyone.CastCycle(S.Moonfire, Enemies8ySplash, EvaluateCycleMoonfireAoe, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire aoe 16"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceofNature) then return "force_of_nature aoe 18"; end
  end
  -- celestial_alignment,if=!druid.no_cds&variable.cd_condition&(buff.starfall.up|astral_power>50)&(!buff.solstice.up&!buff.ca_inc.up&(!covenant.night_fae|cooldown.convoke_the_spirits.up&astral_power<50)&target.time_to_die>15+conduit.precise_alignment.time_value|interpolated_fight_remains<20+(conduit.precise_alignment.time_value))
  if S.CelestialAlignment:IsCastable() and (CDsON() and VarCDCondition and (Player:BuffUp(S.StarfallBuff) or Player:AstralPowerP() > 50) and (Player:BuffDown(S.SolsticeBuff) and Player:BuffDown(CaInc) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() and Player:AstralPowerP() < 50) and Target:TimeToDie() > 15 + PATime or fightRemains < 20 + PATime)) then
    if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment aoe 20"; end
  end
  -- incarnation,if=!druid.no_cds&variable.cd_condition&(buff.starfall.up|astral_power>50)&(!buff.solstice.up&!buff.ca_inc.up&(!covenant.night_fae|cooldown.convoke_the_spirits.up&astral_power<50)&target.time_to_die>20+conduit.precise_alignment.time_value|interpolated_fight_remains<cooldown.convoke_the_spirits.remains+6|interpolated_fight_remains%%180<30+(conduit.precise_alignment.time_value))
  if S.Incarnation:IsCastable() and (CDsON() and VarCDCondition and (Player:BuffUp(S.StarfallBuff) or Player:AstralPowerP() > 50) and (Player:BuffDown(S.SolsticeBuff) and Player:BuffDown(CaInc) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp() and Player:AstralPowerP() < 50) and Target:TimeToDie() > 20 + PATime or fightRemains < S.ConvoketheSpirits:CooldownRemains() + 6 or fightRemains % 180 < 30 + PATime)) then
    if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation aoe 22"; end
  end
  -- kindred_spirits,if=interpolated_fight_remains<15|(buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250)&buff.starfall.up&(cooldown.ca_inc.remains>50|druid.no_cds)
  if S.KindredSpirits:IsCastable() and (fightRemains < 15 or (PAPValue < 250 or PAPValue >= 250) and Player:BuffUp(S.StarfallBuff) and (CaInc:CooldownRemains() > 50 or not CDsON())) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.KindredSpirits)) then return "kindred_spirits aoe 24"; end
  end
  -- stellar_flare,target_if=refreshable&time_to_die>15,if=spell_targets.starfire<4&ap_check&(buff.ca_inc.remains>10|!buff.ca_inc.up)
  if S.StellarFlare:IsCastable() and (EnemiesCount8ySplash < 4 and AP_Check(S.StellarFlare) and (Player:BuffRemains(CaInc) > 10 or Player:BuffDown(CaInc))) then
    if Everyone.CastCycle(S.StellarFlare, Enemies8ySplash, EvaluateCycleStellarFlareAoe, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare aoe 26"; end
  end
  -- fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<250&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord|spell_targets>2)
  if S.FuryofElune:IsCastable() and ((EclipseState == 1 or EclipseState == 2 or EclipseState == 3) and AP_Check(S.FuryofElune) and PAPValue < 250 and (Target:DebuffUp(S.AdaptiveSwarmDebuff) or CovenantID ~= 4 or EnemiesCount8ySplash > 2)) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryofElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune aoe 28"; end
  end
  -- starfall,if=buff.oneths_perception.up&(buff.starfall.refreshable|astral_power>90)
  if S.Starfall:IsReady() and (Player:BuffUp(S.OnethsPerceptionBuff) and (Player:BuffRefreshable(S.StarfallBuff) or Player:AstralPowerP() > 90)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 30"; end
  end
  -- starfall,if=covenant.night_fae&(variable.convoke_desync|cooldown.ca_inc.up|buff.ca_inc.up)&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%50)&buff.starfall.remains<4&!druid.no_cds
  if S.Starfall:IsReady() and (CovenantID == 3 and (VarConvokeDesync or CaInc:CooldownUp() or Player:BuffUp(CaInc)) and S.ConvoketheSpirits:CooldownRemains() < GCDMax * ceil(Player:AstralPowerP() % 50) and Player:BuffRemains(S.StarfallBuff) < 4 and CDsON()) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 32"; end
  end
  -- starsurge,if=covenant.night_fae&(variable.convoke_desync|cooldown.ca_inc.up|buff.ca_inc.up)&cooldown.convoke_the_spirits.remains<6&buff.starfall.up&eclipse.in_any&!variable.ignore_starsurge&!druid.no_cds
  if S.Starsurge:IsReady() and (CovenantID == 3 and (VarConvokeDesync or CaInc:CooldownUp() or Player:BuffUp(CaInc)) and S.ConvoketheSpirits:CooldownRemains() < 6 and Player:BuffUp(S.StarfallBuff) and (EclipseState == 1 or EclipseState == 2 or EclipseState == 3) and not VarIgnoreStarsurge and CDsON()) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 34"; end
  end
  -- starsurge,if=buff.oneths_clear_vision.up|(!starfire.ap_check&!variable.ignore_starsurge|(buff.ca_inc.remains<5&buff.ca_inc.up|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))&variable.starfall_wont_fall_off&spell_targets.starfall<3)&(!runeforge.timeworn_dreambinder.equipped|spell_targets.starfall<3)
  if S.Starsurge:IsReady() and (Player:BuffUp(S.OnethsClearVisionBuff) or (not AP_Check(S.Starfire) and not VarIgnoreStarsurge or (Player:BuffRemains(CaInc) < 5 and Player:BuffUp(CaInc) or (Player:BuffRemains(S.RavenousFrenzyBuff) < GCDMax * ceil(Player:AstralPowerP() % 30) and Player:BuffUp(S.RavenousFrenzyBuff))) and VarStarfallWontFallOff and EnemiesCount40y < 3) and (not TimewornEquipped or EnemiesCount40y < 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 36"; end
  end
  -- new_moon,if=(buff.eclipse_solar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.NewMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.NewMoon:ExecuteTime() or (S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5) or S.NewMoon:Charges() == 3) and AP_Check(S.NewMoon)) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon aoe 38"; end
  end
  -- half_moon,if=(buff.eclipse_solar.remains>execute_time|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.HalfMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.HalfMoon:ExecuteTime() or (S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5) or S.HalfMoon:Charges() == 3) and AP_Check(S.HalfMoon)) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon aoe 40"; end
  end
  -- full_moon,if=(buff.eclipse_solar.remains>execute_time&(cooldown.ca_inc.remains>50|cooldown.convoke_the_spirits.remains>50)|(charges=2&recharge_time<5)|charges=3)&ap_check
  if S.FullMoon:IsCastable() and ((Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime() and (CaInc:CooldownRemains() > 50 or S.ConvoketheSpirits:CooldownRemains() > 50) or (S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5) or S.FullMoon:Charges() == 3) and AP_Check(S.FullMoon)) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon aoe 42"; end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorofElune) then return "warrior_of_elune aoe 44"; end
  end
  -- variable,name=starfire_in_solar,value=spell_targets.starfire>4+floor(mastery_value*100%20)+floor(buff.starsurge_empowerment_solar.stack%4)
  -- TODO: Find a way to calculate starsurge_empowerment_solar
  VarStarfireinSolar = (EnemiesCount8ySplash > 4 + floor(GetCombatRating(26) * 100 % 20))
  -- wrath,if=(eclipse.lunar_next|eclipse.any_next&variable.is_cleave)&(target.time_to_die>4|eclipse.lunar_in_2|fight_remains<10)|buff.eclipse_solar.remains<action.starfire.execute_time&buff.eclipse_solar.up|eclipse.in_solar&!variable.starfire_in_solar|buff.ca_inc.remains<action.starfire.execute_time&!variable.is_cleave&buff.ca_inc.remains<execute_time&buff.ca_inc.up|buff.ravenous_frenzy.up&spell_haste>0.6&(spell_targets<=3|!talent.soul_of_the_forest.enabled)|!variable.is_cleave&buff.ca_inc.remains>execute_time
  -- TODO: Determine a way to calculate lunar_in_2
  if S.Wrath:IsCastable() and ((EclipseState == 5 or EclipseState == 0 and VarIsCleave) and (Target:TimeToDie() > 4 or fightRemains < 10) or Player:BuffRemains(S.EclipseSolar) < S.Starfire:ExecuteTime() and Player:BuffUp(S.EclipseSolar) or EclipseState == 1 and not VarStarfireinSolar or Player:BuffRemains(CaInc) < S.Starfire:ExecuteTime() and not VarIsCleave and Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc) or Player:BuffUp(S.RavenousFrenzyBuff) and (Player:HastePct() / 100) > 0.6 and (EnemiesCount40y <= 3 or not S.SouloftheForest:IsAvailable()) or not VarIsCleave and Player:BuffRemains(CaInc) > S.Wrath:ExecuteTime()) then
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
  -- Just a couple of pre-checks
  local FuryofEluneRemains = S.FuryofElune:CooldownRemains() - 51
  if FuryofEluneRemains < 0 then FuryofEluneRemains = 0 end
  local FuryTicksRemain = FuryofEluneRemains * 2
  -- ravenous_frenzy,if=buff.ca_inc.remains>15
  if S.RavenousFrenzy:IsCastable() and (Player:BuffRemains(CaInc) > 15) then
    if Cast(S.RavenousFrenzy, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RavenousFrenzy)) then return "ravenous_frenzy boat 2"; end
  end
  -- variable,name=critnotup,value=!buff.balance_of_all_things_nature.up&!buff.balance_of_all_things_arcane.up
  VarCritNotUp = (Player:BuffDown(S.BOATNatureBuff) and Player:BuffDown(S.BOATArcaneBuff))
  -- adaptive_swarm,target_if=buff.balance_of_all_things_nature.stack<4&buff.balance_of_all_things_arcane.stack<4&(!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>3)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<5&dot.adaptive_swarm_damage.ticking)
  if S.AdaptiveSwarm:IsCastable() and (Player:BuffStack(S.BOATNatureBuff) < 4 and Player:BuffStack(S.BOATArcaneBuff) < 4 and (Target:DebuffDown(S.AdaptiveSwarmDebuff) and not S.AdaptiveSwarm:InFlight() and (Player:BuffDown(S.AdaptiveSwarmHeal) or Player:BuffRemains(S.AdaptiveSwarmHeal) > 3) or Target:DebuffStack(S.AdaptiveSwarmDebuff) < 3 and Target:DebuffRemains(S.AdaptiveSwarmDebuff) < 5 and Target:DebuffUp(S.AdaptiveSwarmDebuff))) then
    if Cast(S.AdaptiveSwarm, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.AdaptiveSwarm)) then return "adaptive_swarm boat 4"; end
  end
  -- convoke_the_spirits,if=!druid.no_cds&((variable.convoke_desync&!cooldown.ca_inc.ready|buff.ca_inc.up)&(buff.balance_of_all_things_nature.stack=5|buff.balance_of_all_things_arcane.stack=5)|fight_remains<10)
  if S.ConvoketheSpirits:IsCastable() and (CDsON() and ((VarConvokeDesync and not CaInc:CooldownUp() or Player:BuffUp(CaInc)) and (Player:BuffStack(S.BOATNatureBuff) == 5 or Player:BuffStack(S.BOATArcaneBuff) == 5) or fightRemains < 10)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ConvoketheSpirits)) then return "convoke_the_spirits boat 6"; end
  end
  -- fury_of_elune,if=((buff.balance_of_all_things_nature.stack>4|buff.balance_of_all_things_arcane.stack>4)&(druid.no_cds|cooldown.ca_inc.remains>50|(covenant.night_fae&cooldown.convoke_the_spirits.remains>50)))|(dot.adaptive_swarm_damage.remains>8&cooldown.ca_inc.remains>10&covenant.necrolord)|interpolated_fight_remains<8|(covenant.kyrian&buff.kindred_empowerment.up)
  if S.FuryofElune:IsCastable() and (((Player:BuffStack(S.BOATNatureBuff) > 4 or Player:BuffStack(S.BOATArcaneBuff) > 4) and (not CDsON() or CaInc:CooldownRemains() > 50 or (CovenantID == 3 and S.ConvoketheSpirits:CooldownRemains() > 50))) or (Target:DebuffRemains(S.AdaptiveSwarmDebuff) > 8 and CaInc:CooldownRemains() > 10 and CovenantID == 4) or fightRemains < 8 or (CovenantID == 1 and Player:BuffUp(S.KindredEmpowermentEnergizeBuff))) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryofElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune boat 8"; end
  end
  -- cancel_buff,name=starlord,if=(buff.balance_of_all_things_nature.remains>4.5|buff.balance_of_all_things_arcane.remains>4.5)&(cooldown.ca_inc.remains>7|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))&astral_power>=30
  -- starsurge,if=!variable.critnotup&(covenant.night_fae|cooldown.ca_inc.remains>7|!variable.cd_condition&!covenant.kyrian|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))&(!dot.fury_of_elune.ticking|!cooldown.ca_inc.ready|!cooldown.convoke_the_spirits.ready)
  if S.Starsurge:IsReady() and (not VarCritNotUp and (CovenantID == 3 or CaInc:CooldownRemains() > 7 or not VarCDCondition and CovenantID ~= 1 or (S.EmpowerBond:CooldownRemains() > 7 and Player:BuffDown(S.KindredEmpowermentEnergizeBuff) and CovenantID == 1)) and (FuryofEluneRemains == 0 or not CaInc:CooldownUp() or not S.ConvoketheSpirits:CooldownUp())) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge boat 10"; end
  end
  -- starsurge,if=(cooldown.convoke_the_spirits.remains<5&!druid.no_cds&(variable.convoke_desync|cooldown.ca_inc.remains<5)&variable.cd_condition)&!dot.fury_of_elune.ticking&covenant.night_fae&!druid.no_cds&eclipse.in_any
  if S.Starsurge:IsReady() and ((S.ConvoketheSpirits:CooldownRemains() < 5 and CDsON() and (VarConvokeDesync or CaInc:CooldownRemains() < 5) and VarCDCondition) and FuryofEluneRemains == 0 and CovenantID == 3 and CDsON() and (EclipseState == 1 or EclipseState == 2 or EclipseState == 3)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge boat 12"; end
  end
  -- variable,name=dot_requirements,value=(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)&(buff.kindred_empowerment_energize.remains<gcd.max)&(buff.eclipse_solar.remains>gcd.max|buff.eclipse_lunar.remains>gcd.max)
  VarDotRequirements = ((Player:BuffRemains(S.RavenousFrenzyBuff) > 5 or Player:BuffDown(S.RavenousFrenzyBuff)) and (Player:BuffRemains(S.KindredEmpowermentEnergizeBuff) < GCDMax) and (Player:BuffRemains(S.EclipseSolar) > GCDMax or Player:BuffRemains(S.EclipseLunar) > GCDMax))
  -- sunfire,target_if=refreshable&target.time_to_die>16,if=ap_check&variable.dot_requirements
  if S.Sunfire:IsCastable() and (AP_Check(S.Sunfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Sunfire, Enemies8ySplash, EvaluateCycleSunfireBOAT, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire boat 14"; end
  end
  -- moonfire,target_if=refreshable&target.time_to_die>13.5,if=ap_check&variable.dot_requirements
  if S.Moonfire:IsCastable() and (AP_Check(S.Moonfire) and VarDotRequirements) then
    if Everyone.CastCycle(S.Moonfire, Enemies8ySplash, EvaluateCycleMoonfireBOAT, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire boat 16"; end
  end
  -- stellar_flare,target_if=refreshable&target.time_to_die>16+remains,if=ap_check&variable.dot_requirements
  if S.StellarFlare:IsCastable() and (AP_Check(S.StellarFlare) and VarDotRequirements) then
    if Everyone.CastCycle(S.StellarFlare, Enemies8ySplash, EvaluateCycleStellarFlareBOAT, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare boat 18"; end
  end
  -- force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and (AP_Check(S.ForceofNature)) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceofNature) then return "force_of_nature boat 20"; end
  end
  -- kindred_spirits,if=(eclipse.lunar_next|eclipse.solar_next|eclipse.any_next|buff.balance_of_all_things_nature.remains>4.5|buff.balance_of_all_things_arcane.remains>4.5|astral_power>90&cooldown.ca_inc.ready&!druid.no_cds)&(cooldown.ca_inc.remains>30|cooldown.ca_inc.ready)|interpolated_fight_remains<10
  if S.KindredSpirits:IsCastable() and ((EclipseState == 5 or EclipseState == 4 or EclipseState == 0 or Player:BuffRemains(S.BOATNatureBuff) > 4.5 or Player:BuffRemains(S.BOATArcaneBuff) > 4.5 or Player:AstralPowerP() > 90 and CaInc:CooldownUp() and CDsON()) and (CaInc:CooldownRemains() > 30 or CaInc:CooldownUp()) or fightRemains < 10) then
    if Cast(S.KindredSpirits, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.KindredSpirits)) then return "kindred_spirits boat 22"; end
  end
  -- fury_of_elune,if=cooldown.ca_inc.ready&variable.cd_condition&(astral_power>90&!covenant.night_fae|covenant.night_fae&astral_power<40)&(!covenant.night_fae|cooldown.convoke_the_spirits.ready)&!druid.no_cds
  if S.FuryofElune:IsCastable() and (CaInc:CooldownUp() and VarCDCondition and (Player:AstralPowerP() > 90 and CovenantID ~= 3 or CovenantID == 3 and Player:AstralPowerP() < 40) and (CovenantID ~= 3 or S.ConvoketheSpirits:CooldownUp()) and CDsON()) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryofElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune boat 24"; end
  end
  -- celestial_alignment,if=!druid.no_cds&variable.cd_condition&((astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|buff.bloodlust.up&buff.bloodlust.remains<20+(conduit.precise_alignment.time_value))|interpolated_fight_remains<20+(conduit.precise_alignment.time_value)|covenant.night_fae)&(!covenant.night_fae|(astral_power<40|dot.fury_of_elune.ticking)&(variable.convoke_desync|cooldown.convoke_the_spirits.ready))
  if S.CelestialAlignment:IsCastable() and (CDsON() and VarCDCondition and ((Player:AstralPowerP() > 90 and (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID ~= 1) or Player:BloodlustUp() and Player:BloodlustRemains() < 20 + PATime) or fightRemains < 20 + PATime or CovenantID == 3) and (CovenantID ~= 3 or (Player:AstralPowerP() < 40 or FuryofEluneRemains > 0) and (VarConvokeDesync or S.ConvoketheSpirits:CooldownUp()))) then
    if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment boat 26"; end
  end
  -- incarnation,if=!druid.no_cds&variable.cd_condition&((astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|buff.bloodlust.up&buff.bloodlust.remains<30+(conduit.precise_alignment.time_value))|interpolated_fight_remains<30+(conduit.precise_alignment.time_value)|covenant.night_fae)&(!covenant.night_fae|(astral_power<40|dot.fury_of_elune.ticking)&(variable.convoke_desync|cooldown.convoke_the_spirits.ready))
  if S.Incarnation:IsCastable() and (CDsON() and VarCDCondition and ((Player:AstralPowerP() > 90 and (Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or CovenantID ~= 1) or Player:BloodlustUp() and Player:BloodlustRemains() < 30 + PATime) or fightRemains < 30 + PATime or CovenantID == 3) and (CovenantID ~= 3 or (Player:AstralPowerP() < 40 or FuryofEluneRemains > 0) and (VarConvokeDesync or S.ConvoketheSpirits:CooldownUp()))) then
    if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation boat 28"; end
  end
  -- variable,name=aspPerSec,value=eclipse.in_lunar*8%action.starfire.execute_time+!eclipse.in_lunar*(6+talent.soul_of_the_forest.enabled*3)%action.wrath.execute_time+0.2%spell_haste
  VarAspPerSec = (num(EclipseState == 2) * 8 % S.Starfire:ExecuteTime() + num(not (EclipseState == 2)) * (6 + num(S.SouloftheForest:IsAvailable()) * 3) % S.Wrath:ExecuteTime() + 0.2 % (Player:HastePct() / 100))
  -- starsurge,if=(interpolated_fight_remains<4|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))|(astral_power+variable.aspPerSec*buff.eclipse_solar.remains+dot.fury_of_elune.ticks_remain*2.5>110|astral_power+variable.aspPerSec*buff.eclipse_lunar.remains+dot.fury_of_elune.ticks_remain*2.5>110)&eclipse.in_any&(!buff.ca_inc.up|!talent.starlord.enabled)&((!cooldown.ca_inc.up|covenant.kyrian&!cooldown.empower_bond.up)|covenant.night_fae)&(!covenant.venthyr|!buff.ca_inc.up|astral_power>90)|(talent.starlord.enabled&buff.ca_inc.up&(buff.starlord.stack<3|astral_power>90))|buff.ca_inc.remains>8&!buff.ravenous_frenzy.up&!talent.starlord.enabled
  if S.Starsurge:IsReady() and ((fightRemains < 4 or (Player:BuffRemains(S.RavenousFrenzyBuff) < GCDMax * ceil(Player:AstralPowerP() % 30) and Player:BuffUp(S.RavenousFrenzyBuff))) or (Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseSolar) + FuryTicksRemain * 2.5 > 110 or Player:AstralPowerP() + VarAspPerSec * Player:BuffRemains(S.EclipseLunar) + FuryTicksRemain * 2.5 > 110) and (EclipseState == 1 or EclipseState == 2 or EclipseState == 3) and (Player:BuffDown(CaInc) or not S.Starlord:IsAvailable()) and ((not CaInc:CooldownUp() or CovenantID == 1 and not S.EmpowerBond:CooldownUp()) or CovenantID == 3) and (CovenantID ~= 2 or Player:BuffDown(CaInc) or Player:AstralPowerP() > 90) or (S.Starlord:IsAvailable() and Player:BuffUp(CaInc) and (Player:BuffStack(S.StarlordBuff) < 3 or Player:AstralPowerP() > 90)) or Player:BuffRemains(CaInc) > 8 and Player:BuffDown(S.RavenousFrenzyBuff) and not S.Starlord:IsAvailable()) then
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
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorofElune) then return "warrior_of_elune boat 38"; end
  end
  -- starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
  if S.Starfire:IsCastable() and (EclipseState == 2 or EclipseState == 4 or EclipseState == 0 or Player:BuffUp(S.WarriorofEluneBuff) and Player:BuffUp(S.EclipseLunar) or (Player:BuffRemains(CaInc) < S.Wrath:ExecuteTime() and Player:BuffUp(CaInc))) then
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
  fightRemains = max(HL.FightRemains(Enemies8ySplash, false), HL.BossFightRemains())

  -- Determine amount of AP fed into Primordial Arcanic Pulsar
  -- TODO: Verify which slot holds the AP value
  PAPValue = 0
  if PAPEquipped then
    PAPValue = select(16, Player:BuffInfo(S.PAPBuff, false, true))
  end

  -- Eclipse Stuffs
  if (Player:PrevGCD(1, S.Wrath) or Player:PrevGCD(1, S.Starfire)) then
    EclipseCheck()
  end

  if (Player:BuffDown(S.EclipseLunar) and Player:BuffDown(S.EclipseSolar)) then
    if EclipseState == 1 then EclipseState = 5 end
    if EclipseState == 2 then EclipseState = 4 end
    if EclipseState == 3 then EclipseState = 0 end
  end

  InEclipse = (EclipseState == 1 or EclipseState == 2 or EclipseState == 3)

  -- Moonkin Form OOC, if setting is true
  if S.MoonkinForm:IsCastable() and Settings.Balance.ShowMoonkinFormOOC then
    if Cast(S.MoonkinForm) then return "moonkin_form ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=is_aoe,value=spell_targets.starfall>1&(!talent.starlord.enabled|talent.stellar_drift.enabled)|spell_targets.starfall>2
    VarIsAoe = (EnemiesCount40y > 1 and (not S.Starlord:IsAvailable() or S.StellarDrift:IsAvailable()) or EnemiesCount40y > 2)
    -- variable,name=is_cleave,value=spell_targets.starfire>1
    VarIsCleave = (EnemiesCount8ySplash > 1)
    -- Manually added: Opener function
    if (HL.CombatTime() < 4 and not Player:PrevGCD(1, S.Starsurge) and not Player:PrevGCD(2, S.Starsurge)) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- berserking,if=(!covenant.night_fae|!cooldown.convoke_the_spirits.up)&buff.ca_inc.up
    if S.Berserking:IsCastable() and ((CovenantID ~= 3 or not S.ConvoketheSpirits:CooldownUp()) and Player:BuffUp(CaInc)) then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 2"; end
    end
    -- potion,if=buff.ca_inc.remains>15|fight_remains<25
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffRemains(CaInc) > 15 or fightRemains < 25) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion 4"; end
    end
    -- variable,name=convoke_desync,value=ceil((interpolated_fight_remains-15-cooldown.ca_inc.remains)%180)=ceil((interpolated_fight_remains-15-120-cooldown.convoke_the_spirits.remains)%180)|cooldown.ca_inc.remains>interpolated_fight_remains|cooldown.convoke_the_spirits.remains>interpolated_fight_remains-10|!covenant.night_fae
    if (CovenantID == 3) then
      local test1 = ceil((fightRemains - 15 - CaInc:CooldownRemains()) % 180)
      local test2 = ceil((fightRemains - 15 - 120 - S.ConvoketheSpirits:CooldownRemains()) % 180)
      VarConvokeDesync = test1 == test2 or CaInc:CooldownRemains() > fightRemains or S.ConvoketheSpirits:CooldownRemains() > fightRemains - 10
    else
      VarConvokeDesync = true
    end
    -- variable,name=cd_condition,value=(!equipped.empyreal_ordnance|cooldown.empyreal_ordnance.remains<160&!cooldown.empyreal_ordnance.ready)&((variable.on_use_trinket=1|variable.on_use_trinket=3)&(trinket.1.ready_cooldown|trinket.1.cooldown.remains>interpolated_fight_remains-10)|variable.on_use_trinket=2&(trinket.2.ready_cooldown|trinket.2.cooldown.remains>interpolated_fight_remains-10)|variable.on_use_trinket=0)|covenant.kyrian
    VarCDCondition = (not I.EmpyrealOrdinance:IsEquipped() or I.EmpyrealOrdinance:CooldownRemains() < 160 and not I.EmpyrealOrdinance:IsReady()) and ((VarOnUseTrinket == 1 or VarOnUseTrinket == 3) and (trinket1:IsReady() or trinket1:CooldownRemains() > fightRemains - 10) or VarOnUseTrinket == 2 and (trinket2:IsReady() or trinket2:CooldownRemains() > fightRemains - 10) or VarOnUseTrinket == 0) or CovenantID == 1
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=empyreal_ordnance,if=cooldown.ca_inc.remains<20&cooldown.convoke_the_spirits.remains<20|fight_remains<37
      if I.EmpyrealOrdinance:IsEquippedAndReady() and (CaInc:CooldownRemains() < 20 and S.ConvoketheSpirits:CooldownRemains() < 20 or fightRemains < 37) then
        if Cast(I.EmpyrealOrdinance, nil, Settings.Commons.DisplayStyle.Trinkets) then return "empyreal_ordnance main 6"; end
      end
      -- use_item,name=soulletting_ruby,if=cooldown.ca_inc.remains<6&!variable.convoke_desync|cooldown.convoke_the_spirits.remains<6&variable.convoke_desync|fight_remains<25
      if I.SoullettingRuby:IsEquippedAndReady() and (CaInc:CooldownRemains() < 6 and not VarConvokeDesync or S.ConvoketheSpirits:CooldownRemains() < 6 and VarConvokeDesync or fightRemains < 25) then
        if Cast(I.SoullettingRuby, nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby main 8"; end
      end
      -- use_item,name=inscrutable_quantum_device,if=buff.ca_inc.up
      if I.InscrutableQuantumDevice:IsEquippedAndReady() and (Player:BuffUp(CaInc)) then
        if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device main 10"; end
      end
      -- use_items,slots=trinket1,if=(variable.on_use_trinket=1|variable.on_use_trinket=3)&(buff.ca_inc.up|cooldown.ca_inc.remains+2>trinket.1.cooldown.duration&(!covenant.night_fae|!variable.convoke_desync)&!covenant.kyrian|covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.up&!cooldown.ca_inc.up&((buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)&!runeforge.balance_of_all_things|(buff.balance_of_all_things_nature.stack=5|buff.balance_of_all_things_arcane.stack=5))|buff.kindred_empowerment_energize.up)|fight_remains<20|variable.on_use_trinket=0
      if trinket1:IsReady() and ((VarOnUseTrinket == 1 or VarOnUseTrinket == 3) and (Player:BuffUp(CaInc) or CaInc:CooldownRemains() + 2 > trinket1:CooldownRemains() and (CovenantID ~= 3 or not VarConvokeDesync) and CovenantID ~= 1 or CovenantID == 3 and VarConvokeDesync and S.ConvoketheSpirits:CooldownUp() and not CaInc:CooldownUp() and ((Player:BuffRemains(S.EclipseLunar) > 10 or Player:BuffRemains(S.EclipseSolar) > 10) and not BOATEquipped or (Player:BuffStack(S.BOATNatureBuff) == 5 or Player:BuffStack(S.BOATArcaneBuff) == 5)) or Player:BuffUp(S.KindredEmpowermentEnergizeBuff)) or fightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 main 12"; end
      end
      -- use_items,slots=trinket2,if=variable.on_use_trinket=3&!trinket.1.ready_cooldown|(buff.ca_inc.up|cooldown.ca_inc.remains+2>trinket.2.cooldown.duration&(!covenant.night_fae|!variable.convoke_desync)&!covenant.kyrian|covenant.night_fae&variable.convoke_desync&cooldown.convoke_the_spirits.up&!cooldown.ca_inc.up&((buff.eclipse_lunar.remains>10|buff.eclipse_solar.remains>10)&!runeforge.balance_of_all_things|(buff.balance_of_all_things_nature.stack=5|buff.balance_of_all_things_arcane.stack=5)))|buff.kindred_empowerment_energize.up|fight_remains<20|variable.on_use_trinket=0
      if trinket2:IsReady() and (VarOnUseTrinket == 3 and not trinket1:IsReady() or (Player:BuffUp(CaInc) or CaInc:CooldownRemains() + 2 > trinket2:CooldownRemains() and (CovenantID ~= 3 or not VarConvokeDesync) and CovenantID ~= 1 or CovenantID == 3 and VarConvokeDesync and S.ConvoketheSpirits:CooldownUp() and not CaInc:CooldownUp() and ((Player:BuffRemains(S.EclipseLunar) > 10 or Player:BuffRemains(S.EclipseSolar) > 10) and not BOATEquipped or (Player:BuffStack(S.BOATNatureBuff) == 5 or Player:BuffStack(S.BOATArcaneBuff) == 5))) or Player:BuffUp(S.KindredEmpowermentEnergizeBuff) or fightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 main 14"; end
      end
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
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
end

HR.SetAPL(102, APL, OnInit)
