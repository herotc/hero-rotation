--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local MultiSpell    = HL.MultiSpell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua

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
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Variables
local VarInit = false
local VarNoCDTalent
local VarSolarEclipseST
local VarOnUseTrinket
local VarIsAoe
local VarIsCleave
local VarPassiveAsp
local VarCDConditionST
local VarCDConditionAoE
local VarEnterEclipse
local VarEnterSolar
local VarConvokeCondition
local PAPValue
local CAIncBuffUp
local CAIncBuffRemains
local Druid = HL.Druid
local BossFightRemains = 11111
local FightRemains = 11111

-- CA/Incarnation Variable
local CaInc = S.IncarnationTalent:IsAvailable() and S.Incarnation or S.CelestialAlignment

-- Eclipse Variables
local EclipseInAny = false
local EclipseInBoth = false
local EclipseInLunar = false
local EclipseInSolar = false
local EclipseLunarNext = false
local EclipseSolarNext = false
local EclipseAnyNext = false


-- Register
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
  VarInit = false
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarInit = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  CaInc = S.IncarnationTalent:IsAvailable() and S.Incarnation or S.CelestialAlignment
  VarInit = false
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

-- Enemy Variables
local Enemies40y, EnemiesCount40y
local Enemies8ySplash, EnemiesCount8ySplash

-- Stuns

-- CastCycle/CastTargetIf Functions
local function EvaluateCycleSunfireST(TargetUnit)
  -- target_if=refreshable&remains<2&(target.time_to_die-remains)>6
  local Remains = TargetUnit:DebuffRemains(S.SunfireDebuff)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and Remains < 2 and (TargetUnit:TimeToDie() - Remains) > 6)
end

local function EvaluateCycleSunfireST2(TargetUnit)
  -- target_if=refreshable&astral_power.deficit>variable.passive_asp+3
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and Player:AstralPowerDeficit() > VarPassiveAsp + 3)
end

local function EvaluateCycleMoonfireST(TargetUnit)
  -- target_if=refreshable&remains<2&(target.time_to_die-remains)>6
  local Remains = TargetUnit:DebuffRemains(S.MoonfireDebuff)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and Remains < 2 and (TargetUnit:TimeToDie() - Remains) > 6)
end

local function EvaluateCycleMoonfireST2(TargetUnit)
  -- target_if=refreshable&astral_power.deficit>variable.passive_asp+3
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and Player:AstralPowerDeficit() > VarPassiveAsp + 3)
end

local function EvaluateCycleStellarFlareST(TargetUnit)
  -- target_if=refreshable&astral_power.deficit>variable.passive_asp+8&remains<2&(target.time_to_die-remains)>8
  local Remains = TargetUnit:DebuffRemains(S.StellarFlareDebuff)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and Player:AstralPowerDeficit() > VarPassiveAsp + 8 and Remains < 2 and (TargetUnit:TimeToDie() - Remains) > 8)
end

local function EvaluateCycleStellarFlareST2(TargetUnit)
  -- target_if=refreshable&astral_power.deficit>variable.passive_asp+8
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and Player:AstralPowerDeficit() > VarPassiveAsp + 8)
end

local function EvaluateCycleSunfireAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains)>6-(spell_targets%2)&astral_power.deficit>variable.passive_asp+3
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff) and (TargetUnit:TimeToDie() - Target:DebuffRemains(S.SunfireDebuff)) > 6 - (EnemiesCount8ySplash / 2) and Player:AstralPowerDeficit() > VarPassiveAsp + 3)
end

local function EvaluateCycleMoonfireAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+3
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff) and (TargetUnit:TimeToDie() - Target:DebuffRemains(S.MoonfireDebuff)) > 6 and Player:AstralPowerDeficit() > VarPassiveAsp + 3)
end

local function EvaluateCycleStellarFlareAoE(TargetUnit)
  -- target_if=refreshable&(target.time_to_die-remains-spell_targets.starfire)>8+spell_targets.starfire
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff) and (TargetUnit:TimeToDie() - TargetUnit:DebuffRemains(S.StellarFlareDebuff) - TargetUnit:GetEnemiesInSplashRangeCount(8)) > 8 + EnemiesCount8ySplash)
end

local function EvaluateCycleSunfireFallthru(TargetUnit)
  -- target_if=dot.moonfire.remains>remains*22%18
  return (TargetUnit:DebuffRemains(S.MoonfireDebuff) > (TargetUnit:DebuffRemains(S.SunfireDebuff) * 22 / 18))
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

local function InitVars()
  -- variable,name=no_cd_talent,value=!talent.celestial_alignment&!talent.incarnation_chosen_of_elune|druid.no_cds
  VarNoCDTalent = (not S.CelestialAlignment:IsAvailable()) and (not S.IncarnationTalent:IsAvailable()) or not CDsON()
  -- variable,name=solar_eclipse_st,value=talent.soul_of_the_forest&talent.warrior_of_elune
  VarSolarEclipseST = S.SouloftheForest:IsAvailable() and S.WarriorofElune:IsAvailable()
  -- variable,name=on_use_trinket,value=0
  VarOnUseTrinket = 0
  -- variable,name=on_use_trinket,op=add,value=trinket.1.has_proc.any&trinket.1.cooldown.duration
  VarOnUseTrinket = VarOnUseTrinket + num(trinket1:IsReady() or trinket1:CooldownRemains() > 0)
  -- variable,name=on_use_trinket,op=add,value=(trinket.2.has_proc.any&trinket.2.cooldown.duration)*2
  VarOnUseTrinket = VarOnUseTrinket + (num(trinket2:IsReady() or trinket2:CooldownRemains() > 0) * 2)

  VarInit = true
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.MarkoftheWild:IsCastable() and (Player:BuffDown(S.MarkoftheWildBuff, true) or Everyone.GroupBuffMissing(S.MarkoftheWildBuff)) then
    if Cast(S.MarkoftheWild, Settings.Commons.GCDasOffGCD.MarkOfTheWild) then return "mark_of_the_wild precombat"; end
  end
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
  -- stellar_flare
  if S.StellarFlare:IsCastable() then
    if Cast(S.StellarFlare, nil, nil, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare precombat 6"; end
  end
  -- starfire,if=!talent.stellar_flare
  if S.Starfire:IsCastable() and (not S.StellarFlare:IsAvailable()) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire precombat 8"; end
  end
end

local function Fallthru()
  -- starfall,if=variable.is_aoe
  if S.Starfall:IsReady() and (VarIsAoe) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall fallthru 2"; end
  end
  -- starsurge
  if S.Starsurge:IsReady() then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge fallthru 4"; end
  end
  -- sunfire,target_if=dot.moonfire.remains>remains*22%18
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireFallthru, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire fallthru 6"; end
  end
  -- moonfire
  if S.Moonfire:IsCastable() then
    if Cast(S.Moonfire, nil, nil, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire fallthru 8"; end
  end
end

local function St()
  -- sunfire,target_if=refreshable&remains<2&(target.time_to_die-remains)>6
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireST, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire st 4"; end
  end
  -- moonfire,target_if=refreshable&remains<2&(target.time_to_die-remains)>6
  if S.Moonfire:IsCastable() then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireST, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire st 6"; end
  end
  -- stellar_flare,target_if=refreshable&astral_power.deficit>variable.passive_asp+8&remains<2&(target.time_to_die-remains)>8
  if S.StellarFlare:IsCastable() then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareST, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare st 10"; end
  end
  -- variable,name=cd_condition_st,value=!druid.no_cds&(cooldown.ca_inc.remains<15&!buff.ca_inc.up&(target.time_to_die>15|fight_remains<25+10*talent.incarnation_chosen_of_elune))
  VarCDConditionST = CDsON() and (CaInc:CooldownRemains() < 15 and (not CAIncBuffUp) and (Target:TimeToDie() > 15 or FightRemains < 25 + 10 * num(S.IncarnationTalent:IsAvailable())))
  -- starfall,if=buff.primordial_arcanic_pulsar.value>=550&!buff.ca_inc.up&buff.starweavers_warp.up
  if S.Starfall:IsReady() and (PAPValue >= 550 and (not CAIncBuffUp) and Player:BuffUp(S.StarweaversWarp)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 12.5"; end
  end
  -- starsurge,if=buff.primordial_arcanic_pulsar.value>=560&buff.starweavers_weft.up
  if S.Starsurge:IsReady() and (PAPValue >= 560 and Player:BuffUp(S.StarweaversWeft)) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 13"; end
  end
  if CDsON() then
    -- celestial_alignment,if=variable.cd_condition_st
    if S.CelestialAlignment:IsCastable() and (VarCDConditionST) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment st 16"; end
    end
    -- incarnation,if=variable.cd_condition_st
    if S.Incarnation:IsCastable() and (VarCDConditionST) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "incarnation st 18"; end
    end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune st 24"; end
  end
  -- variable,name=enter_eclipse,value=eclipse.any_next|variable.solar_eclipse_st&buff.eclipse_solar.up&(buff.eclipse_solar.remains<action.starfire.cast_time)|!variable.solar_eclipse_st&buff.eclipse_lunar.up&(buff.eclipse_lunar.remains<action.wrath.cast_time)
  VarEnterEclipse = (EclipseAnyNext or VarSolarEclipseST and Player:BuffUp(S.EclipseSolar) and (Player:BuffRemains(S.EclipseSolar) < S.Starfire:CastTime()) or (not VarSolarEclipseST) and Player:BuffUp(S.EclipseLunar) and (Player:BuffRemains(S.EclipseLunar) < S.Wrath:CastTime()))
  -- starfire,if=variable.enter_eclipse&variable.solar_eclipse_st
  if S.Starfire:IsCastable() and (VarEnterEclipse and VarSolarEclipseST) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire st 25"; end
  end
  -- wrath,if=variable.enter_eclipse
  if S.Wrath:IsCastable() and (VarEnterEclipse) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath st 26"; end
  end
  -- variable,name=convoke_condition,value=buff.ca_inc.remains>4|(cooldown.ca_inc.remains>30|variable.no_cd_talent)&(buff.eclipse_lunar.remains>4|buff.eclipse_solar.remains>4)
  VarConvokeCondition = (CAIncBuffRemains > 4 or (CaInc:CooldownRemains() > 30 or VarNoCDTalent) and (Player:BuffRemains(S.EclipseLunar) > 4 or Player:BuffRemains(S.EclipseSolar) > 4))
  -- starsurge,if=talent.convoke_the_spirits&cooldown.convoke_the_spirits.ready&variable.convoke_condition
  if S.Starsurge:IsReady() and (S.ConvoketheSpirits:IsAvailable() and S.ConvoketheSpirits:IsCastable() and VarConvokeCondition) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 28"; end
  end
  -- convoke_the_spirits,if=variable.convoke_condition
  if S.ConvoketheSpirits:IsCastable() and CDsON() and (VarConvokeCondition) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "convoke_the_spirits st 30"; end
  end
  -- astral_communion,if=astral_power.deficit>variable.passive_asp+55
  if S.AstralCommunion:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 55) then
    if Cast(S.AstralCommunion, Settings.Balance.GCDasOffGCD.AstralCommunion) then return "astral_communion st 32"; end
  end
  -- force_of_nature,if=astral_power.deficit>variable.passive_asp+20
  if S.ForceofNature:IsCastable() and CDsON() and (Player:AstralPowerDeficit() > VarPassiveAsp + 20) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature, nil, not Target:IsInRange(45)) then return "force_of_nature st 34"; end
  end
  -- fury_of_elune,if=astral_power.deficit>variable.passive_asp+8&target.time_to_die>2
  if S.FuryofElune:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 8 and Target:TimeToDie() > 2) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune st 36"; end
  end
  -- starfall,if=buff.starweavers_warp.up
  if S.Starfall:IsReady() and (Player:BuffUp(S.StarweaversWarp)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall st 38"; end
  end
  -- starsurge,if=talent.starlord&buff.starlord.stack<3|talent.rattle_the_stars&buff.rattled_stars.up&buff.rattled_stars.remains<gcd.max
  if S.Starsurge:IsReady() and (S.Starlord:IsAvailable() and Player:BuffStack(S.StarlordBuff) < 3 or S.RattletheStars:IsAvailable() and Player:BuffUp(S.RattledStarsBuff) and Player:BuffRemains(S.RattledStarsBuff) < Player:GCD() + 0.5) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 40"; end
  end
  -- sunfire,target_if=refreshable&astral_power.deficit>variable.passive_asp+3
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireST2, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire st 42"; end
  end
  -- moonfire,target_if=refreshable&astral_power.deficit>variable.passive_asp+3
  if S.Moonfire:IsCastable() then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireST2, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire st 44"; end
  end
  -- stellar_flare,target_if=refreshable&astral_power.deficit>variable.passive_asp+8
  if S.StellarFlare:IsCastable() then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareST2, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare st 46"; end
  end
  -- new_moon,if=astral_power.deficit>variable.passive_asp+10
  if S.NewMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 10) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon st 48"; end
  end
  -- half_moon,if=astral_power.deficit>variable.passive_asp+20&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)
  if S.HalfMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 20 and (Player:BuffRemains(S.EclipseLunar) > S.HalfMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.HalfMoon:ExecuteTime())) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon st 50"; end
  end
  -- full_moon,if=astral_power.deficit>variable.passive_asp+40&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)
  if S.FullMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 40 and (Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime())) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon st 52"; end
  end
  -- starsurge,if=buff.starweavers_weft.up|astral_power.deficit<variable.passive_asp+(8*(1+0.5*talent.soul_of_the_forest*buff.eclipse_solar.up))|talent.astral_communion&cooldown.astral_communion.remains<3|fight_remains<5
  if S.Starsurge:IsReady() and (Player:BuffUp(S.StarweaversWeft) or Player:AstralPowerDeficit() < VarPassiveAsp + (8 * (1 + 0.5 * num(S.SouloftheForest:IsAvailable()) * num(Player:BuffUp(S.EclipseSolar)))) or S.AstralCommunion:IsAvailable() and S.AstralCommunion:CooldownRemains() < 3 or FightRemains < 5) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge st 54"; end
  end
  -- wild_mushroom,if=talent.fungal_growth&(!fight_style.dungeonroute|target.time_to_die>(full_recharge_time-7)|fight_remains<10)
  local DungeonRoute = Player:IsInParty() and not Player:IsInRaid()
  if S.WildMushroom:IsCastable() and (S.FungalGrowth:IsAvailable() and ((not DungeonRoute) or Target:TimeToDie() > (S.WildMushroom:FullRechargeTime() - 7) or FightRemains < 10)) then
    if Cast(S.WildMushroom, Settings.Balance.GCDasOffGCD.WildMushroom, nil, not Target:IsSpellInRange(S.WildMushroom)) then return "wild_mushroom st 56"; end
  end
  -- starfire,if=eclipse.in_lunar&buff.umbral_embrace.react|buff.ca_inc.up&buff.warrior_of_elune.up&buff.warrior_of_elune.stack=1
  if S.Starfire:IsCastable() and (EclipseInLunar and Player:BuffUp(S.UmbralEmbraceBuff) or CAIncBuffUp and Player:BuffUp(S.WarriorofEluneBuff) and Player:BuffStack(S.WarriorofEluneBuff) == 1) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire st 58"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and not Player:IsMoving() then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath st 60"; end
  end
  -- run_action_list,name=fallthru
  local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
  if HR.CastAnnotated(S.Pool, false, "MOVING") then return "Pool ST due to movement and no fallthru"; end
end

local function AoE()
  local DungeonRoute = Player:IsInParty() and not Player:IsInRaid()
  -- moonfire,target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+3,if=fight_style.dungeonroute
  if S.Moonfire:IsCastable() and (DungeonRoute) then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireAoE, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire aoe 2"; end
  end
  -- sunfire,target_if=refreshable&(target.time_to_die-remains)>6-(spell_targets%2)&astral_power.deficit>variable.passive_asp+3
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, Enemies40y, EvaluateCycleSunfireAoE, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire aoe 4"; end
  end
  -- moonfire,target_if=refreshable&(target.time_to_die-remains)>6&astral_power.deficit>variable.passive_asp+3,if=!fight_style.dungeonroute
  if S.Moonfire:IsCastable() and (not DungeonRoute) then
    if Everyone.CastCycle(S.Moonfire, Enemies40y, EvaluateCycleMoonfireAoE, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire aoe 6"; end
  end
  -- variable,name=cd_condition_aoe,value=!druid.no_cds&(cooldown.ca_inc.remains<5&!buff.ca_inc.up&(target.time_to_die>10|fight_remains<25+10*talent.incarnation_chosen_of_elune))
  VarCDConditionAoE = CDsON() and (CaInc:CooldownRemains() < 5 and (not CAIncBuffUp) and (Target:TimeToDie() > 10 or FightRemains < 25 + 10 * num(S.IncarnationTalent:IsAvailable())))
  -- stellar_flare,target_if=refreshable&(target.time_to_die-remains-spell_targets.starfire)>8+spell_targets.starfire,if=astral_power.deficit>variable.passive_asp+8&spell_targets.starfire<(11-talent.umbral_intensity.rank-talent.astral_smolder.rank)&variable.cd_condition_aoe
  if S.StellarFlare:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 8 and EnemiesCount8ySplash < (11 - S.UmbralIntensity:TalentRank() - S.AstralSmolder:TalentRank()) and VarCDConditionAoE) then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareAoE, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare aoe 9"; end
  end
  -- starfall,if=variable.cd_condition_aoe&(talent.orbital_strike&astral_power.deficit<variable.passive_asp+8*spell_targets|buff.touch_the_cosmos.up)|astral_power.deficit<(variable.passive_asp+8+12*(buff.eclipse_lunar.remains<4|buff.eclipse_solar.remains<4))
  if S.Starfall:IsReady() and (VarCDConditionAoE and (S.OrbitalStrike:IsAvailable() and Player:AstralPowerDeficit() < VarPassiveAsp + 8 * EnemiesCount40y or Player:BuffUp(S.TouchtheCosmos)) or Player:AstralPowerDeficit() < (VarPassiveAsp + 8 + 12 * num(Player:BuffRemains(S.EclipseLunar) < 4 or Player:BuffRemains(S.EclipseSolar) < 4))) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 10"; end
  end
  if CDsON() then
    -- celestial_alignment,if=variable.cd_condition_aoe
    if S.CelestialAlignment:IsCastable() and (VarCDConditionAoE) then
      if Cast(S.CelestialAlignment, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment aoe 12"; end
    end
    -- incarnation,if=variable.cd_condition_aoe
    if S.Incarnation:IsCastable() and (VarCDConditionAoE) then
      if Cast(S.Incarnation, Settings.Balance.GCDasOffGCD.CaInc) then return "celestial_alignment aoe 14"; end
    end
  end
  -- warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if Cast(S.WarriorofElune, Settings.Balance.GCDasOffGCD.WarriorOfElune) then return "warrior_of_elune aoe 16"; end
  end
  -- variable,name=enter_solar,value=spell_targets.starfire<3
  local VarEnterSolar = EnemiesCount8ySplash < 3
  -- starfire,if=variable.enter_solar&(eclipse.any_next|buff.eclipse_solar.remains<action.starfire.execute_time)
  if S.Starfire:IsCastable() and (VarEnterSolar and (EclipseAnyNext or Player:BuffRemains(S.EclipseSolar) < S.Starfire:ExecuteTime())) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire aoe 17"; end
  end
  -- wrath,if=!variable.enter_solar&(eclipse.any_next|buff.eclipse_lunar.remains<action.wrath.execute_time)
  if S.Wrath:IsCastable() and ((not VarEnterSolar) and (EclipseAnyNext or Player:BuffRemains(S.EclipseLunar) < S.Wrath:ExecuteTime())) then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath aoe 18"; end
  end
  -- wild_mushroom,if=astral_power.deficit>variable.passive_asp+20&(!talent.fungal_growth|!talent.waning_twilight|dot.fungal_growth.remains<2&target.time_to_die>7&!prev_gcd.1.wild_mushroom)
  if S.WildMushroom:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 20 and ((not S.FungalGrowth:IsAvailable()) or (not S.WaningTwilight:IsAvailable()) or Target:DebuffRemains(S.FungalGrowthDebuff) < 2 and Target:TimeToDie() > 7 and not Player:PrevGCDP(1, S.WildMushroom))) then
    if Cast(S.WildMushroom, Settings.Balance.GCDasOffGCD.WildMushroom, nil, not Target:IsSpellInRange(S.WildMushroom)) then return "wild_mushroom aoe 20"; end
  end
  -- fury_of_elune,if=astral_power.deficit>variable.passive_asp+8&target.time_to_die>2
  if S.FuryofElune:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 8 and Target:TimeToDie() > 2) then
    if Cast(S.FuryofElune, Settings.Balance.GCDasOffGCD.FuryOfElune, nil, not Target:IsSpellInRange(S.FuryofElune)) then return "fury_of_elune aoe 22"; end
  end
  -- full_moon,if=astral_power.deficit>variable.passive_asp+40&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)
  if S.FullMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 40 and (Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime())) then
    if Cast(S.FullMoon, nil, nil, not Target:IsSpellInRange(S.FullMoon)) then return "full_moon aoe 24"; end
  end
  -- starfall,if=target.time_to_die>4&(buff.starweavers_warp.up|talent.starlord&buff.starlord.stack<3)
  if S.Starfall:IsReady() and (Target:TimeToDie() > 4 and (Player:BuffUp(S.StarweaversWarp) or S.Starlord:IsAvailable() and Player:BuffStack(S.StarlordBuff) < 3)) then
    if Cast(S.Starfall, Settings.Balance.GCDasOffGCD.Starfall, nil, not Target:IsInRange(45)) then return "starfall aoe 26"; end
  end
  -- starfire,if=(buff.gathering_starstuff.stack=3|buff.umbral_embrace.up)&astral_power.deficit>variable.passive_asp+(8*(1+0.4*buff.warrior_of_elune.up))
  if S.Starfire:IsCastable() and ((Player:BuffStack(S.GatheringStarstuff) == 3 or Player:BuffUp(S.UmbralEmbraceBuff)) and Player:AstralPowerDeficit() > VarPassiveAsp + (8 * (1 + 0.4 * num(Player:BuffUp(S.WarriorofEluneBuff))))) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire aoe 28"; end
  end
  -- starsurge,if=buff.starweavers_weft.up&spell_targets.starfire<3
  if S.Starsurge:IsReady() and (Player:BuffUp(S.StarweaversWeft) and EnemiesCount8ySplash < 3) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 30"; end
  end
  -- stellar_flare,target_if=refreshable&(target.time_to_die-remains-spell_targets.starfire)>8+spell_targets.starfire,if=astral_power.deficit>variable.passive_asp+8&spell_targets.starfire<(11-talent.umbral_intensity.rank-talent.astral_smolder.rank)
  if S.StellarFlare:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 8 and EnemiesCount8ySplash < (11 - S.UmbralIntensity:TalentRank() - S.AstralSmolder:TalentRank())) then
    if Everyone.CastCycle(S.StellarFlare, Enemies40y, EvaluateCycleStellarFlareAoE, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare aoe 32"; end
  end
  -- astral_communion,if=astral_power.deficit>variable.passive_asp+50
  if S.AstralCommunion:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 50) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.AstralCommunion) then return "astral_communion aoe 34"; end
  end
  -- convoke_the_spirits,if=astral_power<50&spell_targets.starfall<3+talent.elunes_guidance&(buff.eclipse_lunar.remains>4|buff.eclipse_solar.remains>4)
  if S.ConvoketheSpirits:IsCastable() and CDsON() and (Player:AstralPowerP() < 50 and EnemiesCount40y < 3 + num(S.ElunesGuidance:IsAvailable()) and (Player:BuffRemains(S.EclipseLunar) > 4 or Player:BuffRemains(S.EclipseSolar) > 4)) then
    if Cast(S.ConvoketheSpirits, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "convoke_the_spirits aoe 36"; end
  end
  -- new_moon,if=astral_power.deficit>variable.passive_asp+10
  if S.NewMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 10) then
    if Cast(S.NewMoon, nil, nil, not Target:IsSpellInRange(S.NewMoon)) then return "new_moon aoe 38"; end
  end
  -- half_moon,if=astral_power.deficit>variable.passive_asp+20&(buff.eclipse_lunar.remains>execute_time|buff.eclipse_solar.remains>execute_time)
  if S.HalfMoon:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 20 and (Player:BuffRemains(S.EclipseLunar) > S.FullMoon:ExecuteTime() or Player:BuffRemains(S.EclipseSolar) > S.FullMoon:ExecuteTime())) then
    if Cast(S.HalfMoon, nil, nil, not Target:IsSpellInRange(S.HalfMoon)) then return "half_moon aoe 40"; end
  end
  -- force_of_nature,if=astral_power.deficit>variable.passive_asp+20
  if S.ForceofNature:IsCastable() and (Player:AstralPowerDeficit() > VarPassiveAsp + 20) then
    if Cast(S.ForceofNature, Settings.Balance.GCDasOffGCD.ForceOfNature, nil, not Target:IsInRange(45)) then return "force_of_nature aoe 42"; end
  end
  -- starsurge,if=buff.starweavers_weft.up&spell_targets.starfire<17
  if S.Starsurge:IsReady() and (Player:BuffUp(S.StarweaversWeft) and EnemiesCount8ySplash < 17) then
    if Cast(S.Starsurge, nil, nil, not Target:IsSpellInRange(S.Starsurge)) then return "starsurge aoe 44"; end
  end
  -- starfire,if=spell_targets>2&buff.eclipse_lunar.up
  if S.Starfire:IsCastable() and not Player:IsMoving() and (EnemiesCount8ySplash > 2 and Player:BuffUp(S.EclipseLunar)) then
    if Cast(S.Starfire, nil, nil, not Target:IsSpellInRange(S.Starfire)) then return "starfire aoe 46"; end
  end
  -- wrath
  if S.Wrath:IsCastable() and not Player:IsMoving() then
    if Cast(S.Wrath, nil, nil, not Target:IsSpellInRange(S.Wrath)) then return "wrath aoe 48"; end
  end
  -- run_action_list,name=fallthru
  local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
  if HR.CastAnnotated(S.Pool, false, "MOVING") then return "Pool AoE due to movement and no fallthru"; end
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

  -- Set required variables
  if Everyone.TargetIsValid() and not VarInit then
    InitVars()
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Determine amount of AP fed into Primordial Arcanic Pulsar
    PAPValue = 0
    if S.PrimordialArcanicPulsar:IsAvailable() then
      local spellTable = Player:BuffInfo(S.PAPBuff, false, true)
      if spellTable ~= nil then
        PAPValue = spellTable.points[1]
      end
    end

    -- Check CA/Incarnation Buff Status
    CAIncBuffUp = Player:BuffUp(S.CABuff) or Player:BuffUp(S.IncarnationBuff)
    CAIncBuffRemains = 0
    if CAIncBuffUp then
      CAIncBuffRemains = S.IncarnationTalent:IsAvailable() and Player:BuffRemains(S.IncarnationBuff) or Player:BuffRemains(S.CABuff)
    end
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
    -- variable,name=is_aoe,value=spell_targets.starfall>1
    VarIsAoe = (EnemiesCount40y > 1)
    -- variable,name=is_cleave,value=spell_targets.starfire>1
    VarIsCleave = (EnemiesCount8ySplash > 1)
    -- variable,name=passive_asp,value=6%spell_haste+talent.natures_balance+talent.orbit_breaker*dot.moonfire.ticking*(buff.orbit_breaker.stack>(27-2*buff.solstice.up))*40
    VarPassiveAsp = 6 / Player:SpellHaste() + num(S.NaturesBalance:IsAvailable()) + num(S.OrbitBreaker:IsAvailable()) * num(Target:DebuffUp(S.MoonfireDebuff)) * num(Druid.OrbitBreakerStacks > (27 - 2 * num(Player:BuffUp(S.SolsticeBuff)))) * 40
    -- berserking,if=buff.ca_inc.remains>=20|variable.no_cd_talent|fight_remains<15
    if S.Berserking:IsCastable() and CDsON() and (CAIncBuffRemains >= 20 or VarNoCDTalent or FightRemains < 15) then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 2"; end
    end
    -- potion,if=!druid.no_cds&(buff.ca_inc.remains>=20|variable.no_cd_talent|fight_remains<30)
    -- Note: Using Enabled.Potions instead of !druid.no_cds
    if Settings.Commons.Enabled.Potions and (CAIncBuffRemains >= 20 or VarNoCDTalent or FightRemains < 30) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion 4"; end
      end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_items,slots=trinket1,if=variable.on_use_trinket!=1&!trinket.2.ready_cooldown|(variable.on_use_trinket=1|variable.on_use_trinket=3)&buff.ca_inc.up|variable.no_cd_talent|fight_remains<20|variable.on_use_trinket=0
      local Trinket1ToUse = Player:GetUseableTrinkets(OnUseExcludes, 13)
      if Trinket1ToUse and (VarOnUseTrinket ~= 1 and (not trinket2:IsReady()) or (VarOnUseTrinket == 1 or VarOnUseTrinket == 3) and CAIncBuffUp or VarNoCDTalent or FightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 main 6"; end
      end
      -- use_items,slots=trinket2,if=variable.on_use_trinket!=2&!trinket.1.ready_cooldown|variable.on_use_trinket=2&buff.ca_inc.up|variable.no_cd_talent|fight_remains<20|variable.on_use_trinket=0
      local Trinket2ToUse = Player:GetUseableTrinkets(OnUseExcludes, 14)
      if Trinket2ToUse and (VarOnUseTrinket ~= 2 and (not trinket1:IsReady()) or VarOnUseTrinket == 2 and CAIncBuffUp or VarNoCDTalent or FightRemains < 20 or VarOnUseTrinket == 0) then
        if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 main 8"; end
      end
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- invoke_external_buff,name=power_infusion
    -- Note: Not handling external buffs
    -- run_action_list,name=aoe,if=variable.is_aoe
    if VarIsAoe and AoEON() then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT/AoE") then return "Wait for AoE"; end
    end
    -- run_action_list,name=st
    if (true) then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT/ST") then return "Wait for ST"; end
    end
  end
end

local function OnInit()
  HR.Print("Balance Druid rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(102, APL, OnInit)
