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
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua

-- Azerite Essence Setup
local AE = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Commons
local Everyone = HR.Commons.Everyone
local Druid = HR.Commons.Druid

-- Define S/I for spell and item arrays
local S = Spell.Druid.Balance;
local I = Item.Druid.Balance;

-- Rotation Var
local ShouldReturn; -- Used to get the return string


-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Druid.Commons,
  Balance = HR.GUISettings.APL.Druid.Balance
}

-- Stuns
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function() return true; end },
};

-- Variables
local enemiesCountInStarfallRange, enemiesInStarfallRange, enemies45y, enemies8y, enemies15y, enemiesCount8ySplash, enemiesCount15ySplash

-- Prev Casts
local prev_starsurge, prev_wrath, prev_starfire

local starsurgeIsCastable, starfallIsCastable

local is_aoe, is_cleave

local starfallRange = 45
local starfireSplashRange = 8
local ca_inc_Remains = (Player:BuffRemains(S.CelestialAlignment) or Player:BuffRemains(S.Incarnation))
local ca_inc = (S.CelestialAlignment or S.Incarnation)

--- TODO HERO_DBC update neeeded
local moonfirePandemic, sunfirePandemic, stellarFlarePandamic
moonfirePandemic = 6.6
sunfirePandemic = 5.4
stellarFlarePandamic = 7.2

local function ap_check()
  local APGen = 0
  local CurAP = Player:AstralPower()
  if Player:IsCasting(S.Sunfire) or Player:IsCasting(S.Moonfire) then
    APGen = 2
  elseif Player:IsCasting(S.Wrath) then
    if S.SoulOfTheForest:IsAvailable() then
      APGen = 9
    else
      APGen = 6
    end
  elseif Player:IsCasting(S.ForceofNature) then
    APGen = 20
  elseif Player:IsCasting(S.StellarFlare) or Player:IsCasting(S.Starfire) then
    APGen = 8
  elseif Player:IsCasting(S.NewMoon) then
    APGen = 10
  elseif Player:IsCasting(S.HalfMoon) then
    APGen = 20
  elseif Player:IsCasting(S.FullMoon) then
    APGen = 40
  end

  if S.ShootingStars:IsAvailable() then
    APGen = APGen + 3
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

local function DoTsUp()
  return (Target:Debuff(S.MoonfireDebuff) and Target:Debuff(S.Sunfire) and (not S.StellarFlare:IsAvailable() or Target:Debuff(S.StellarFlareDebuff)))
end

local function evaluateCastCycleMoonfire(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.MoonfireDebuff, moonfirePandemic) and TargetUnit:TimeToDie() > 12) and (ca_inc_Remains > 5 or Player:BuffDown(ca_inc) or Player:AstralPower() < 30) and ap_check()
end

local function evaluateCastCycleSunfire(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.SunfireDebuff, sunfirePandemic) and TargetUnit:TimeToDie() > 12) and (ca_inc_Remains > 5 or Player:BuffDown(ca_inc) or Player:AstralPower() < 30) and ap_check()
end

local function evaluateCastCycleStellarFlare(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.StellarFlareDebuff, stellarFlarePandamic) and TargetUnit:TimeToDie() > 16) and (ca_inc_Remains > 5 or Player:BuffDown(ca_inc) or Player:AstralPower() < 30) and ap_check()
end

local eclipseUpAny

--- ======= ACTION LISTS =======
-- Put here action lists only if they are called multiple times in the APL
-- If it's only put one time, it's doing a closure call for nothing.
local function precombat()
  --# Executed before combat begins. Accepts non-harmful --actions only.
  --actions.precombat=flask
  --actions.precombat+=/food
  --actions.precombat+=/augmentation
  --# Snapshot raid buffed stats before combat begins and pre-potting is done.
  --actions.precombat+=/snapshot_stats
  --actions.precombat+=/moonkin_form
  if S.MoonkinForm:IsCastable() and Player:BuffDown(S.MoonkinForm) then
    if HR.Cast(S.MoonkinForm) then return "moonkin_form 1"; end
    --, Settings.Balance.GCDasOffGCD.MoonkinForm
  end
  --actions.precombat+=/wrath
  --actions.precombat+=/wrath
  if S.Wrath:IsCastable() and S.Wrath:Count() > 0 then
    if HR.Cast(S.Wrath) then return "wrath 2"; end
  end
  --actions.precombat+=/starfire
  if S.Starfire:IsCastable() and Player:BuffUp(S.EclipseLunar) then
    if HR.Cast(S.Starfire) then return "starfire 3"; end
  end
  --actions.precombat+=/variable,name=convoke_desync,value=floor((interpolated_fight_remains-20)%120)>floor((interpolated_fight_remains-25-(10*talent.incarnation.enabled)-(4*conduit.precise_alignment.enabled))%180)
  --- TODO
end

local function fallthru()
  --actions.fallthru=starsurge,if=!runeforge.balance_of_all_things.equipped
  --TODO Shadowlands
  --actions.fallthru+=/sunfire,target_if=dot.moonfire.remains>remains
  if S.Sunfire:IsCastable() and Target:DebuffRemains(S.Moonfire) > Target:DebuffRemains(S.Sunfire) then
    if HR.Cast(S.Sunfire) then return "sunfire 19"; end
  end
  --actions.fallthru+=/moonfire
  if S.Moonfire:IsCastable() then
    if HR.Cast(S.Moonfire) then return "moonfire 20"; end
  end
end

local function prepatch_st()

  --actions.prepatch_st=moonfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
  if S.Moonfire:IsCastable() then
    if Everyone.CastCycle(S.Moonfire, enemies45y, evaluateCastCycleMoonfire, not Target:IsSpellInRange(S.Moonfire)) then return "moonfire 4"; end
  end
  --actions.prepatch_st+=/sunfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
  if S.Sunfire:IsCastable() then
    if Everyone.CastCycle(S.Sunfire, enemies45y, evaluateCastCycleSunfire, not Target:IsSpellInRange(S.Sunfire)) then return "sunfire 5"; end
  end
  --actions.prepatch_st+=/stellar_flare,target_if=refreshable&target.time_to_die>16,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
  if S.StellarFlare:IsCastable() then
    if Everyone.CastCycle(S.StellarFlare, enemies45y, evaluateCastCycleStellarFlare, not Target:IsSpellInRange(S.StellarFlare)) then return "stellar_flare 6"; end
  end
  --actions.prepatch_st+=/force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and ap_check() then
    if HR.Cast(S.ForceofNature) then return "force_of_nature 7"; end
  end
  --actions.prepatch_st+=/celestial_alignment,if=(astral_power>90|buff.bloodlust.up&buff.bloodlust.remains<26)&!buff.ca_inc.up
  if S.CelestialAlignment:IsCastable() and (Player:AstralPower() > 90 or Player:BloodlustUp() and Player:BloodlustRemains() < 26) and not Player:BuffUp(ca_inc) then
    if HR.Cast(S.CelestialAlignment) then return "celestial_alignment 8"; end
  end
  --actions.prepatch_st+=/incarnation,if=(astral_power>90|buff.bloodlust.up&buff.bloodlust.remains<36)&!buff.ca_inc.up
  if S.Incarnation:IsCastable() and (Player:AstralPower() > 90 or Player:BloodlustUp() and Player:BloodlustRemains() < 26) and not Player:BuffUp(ca_inc) then
    if HR.Cast(S.Incarnation) then return "incarnation 8"; end
  end
  --actions.prepatch_st+=/variable,name=save_for_ca_inc,value=!cooldown.ca_inc.ready
  local save_for_ca_inc = not (S.CelestialAlignment:IsReady() or S.Incarnation:IsReady())
  --actions.prepatch_st+=/fury_of_elune,if=eclipse.in_any&ap_check&variable.save_for_ca_inc
  if S.FuryofElune:IsCastable() and eclipseUpAny and ap_check() and save_for_ca_inc then
    if HR.Cast(S.FuryofElune) then return "fury_of_elune 12"; end
  end
  --actions.prepatch_st+=/cancel_buff,name=starlord,if=buff.starlord.remains<6&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&astral_power>90
  --- TODO Settings do you want to play with cancel aura starlord macro?
  if Player:BuffRemains(S.StarlordBuff) < 6 and (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar)) and Player:AstralPower() > 90 then
    if HR.Cast(S.Starlord) then return "cancel_starlord 13"; end
  end
  --actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&(buff.ca_inc.up|astral_power>90&eclipse.in_any)
  --- TODO buff.ca_inc.remains<execute_time is missing here
  if S.Starsurge:IsCastable() and ((not S.StreakingStars:AzeriteRank() or not prev_starsurge) and (Player:BuffUp(ca_inc) or Player:AstralPower() > 90 and eclipseUpAny)) then
    print("starsurge 14")
    if HR.Cast(S.Starsurge) and starsurgeIsCastable then return "starsruge 14"; end
  end
  --actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&talent.starlord.enabled&(buff.starlord.up|astral_power>90)&buff.starlord.stack<3&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&cooldown.ca_inc.remains>7
  --- TODO buff.ca_inc.remains<execute_time is missing here
  if S.Starsurge:IsCastable() and ((not S.StreakingStars:AzeriteRank() or not prev_starsurge) and S.Starlord:IsAvailable() and (Player:BuffUp(S.StarlordBuff) or Player:AstralPower() > 90) and Player:BuffStack(S.StarlordBuff) < 3 and ((Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar)) and ca_inc:CooldownRemains() > 7)) then
    print("starsurge 15")
    if HR.Cast(S.Starsurge) and starsurgeIsCastable then return "starsruge 15"; end
  end
  --actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&buff.eclipse_solar.remains>7&eclipse.in_solar&!talent.starlord.enabled&cooldown.ca_inc.remains>7
  if S.Starsurge:IsCastable() and (not S.StreakingStars:AzeriteRank() or not prev_starsurge) and Player:BuffRemains(S.EclipseSolar) > 7 and Player:BuffUp(S.EclipseSolar) and not S.Starlord:IsAvailable() and ca_inc.CooldownRemains() > 7 then
    --- TODO test it
    print("starsurge 16")
    if HR.Cast(S.Starsurge) and starsurgeIsCastable then return "starsurge 16"; end
  end
  --actions.prepatch_st+=/new_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
  if S.NewMoon:IsCastable() and (Player:BuffUp(S.EclipseLunar) or S.NewMoon:Charges() == 2 and S.NewMoon:Recharge() < 5 or S.NewMoon:Charges() == 3) and ap_check() and save_for_ca_inc then
    if HR.Cast(S.NewMoon) then return "new_moon 9"; end
  end
  --actions.prepatch_st+=/half_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
  if S.HalfMoon:IsCastable() and (Player:BuffUp(S.EclipseLunar) or S.HalfMoon:Charges() == 2 and S.HalfMoon:Recharge() < 5 or S.HalfMoon:Charges() == 3) and ap_check() and save_for_ca_inc then
    if HR.Cast(S.HalfMoon) then return "half_moon 10"; end
  end
  --actions.prepatch_st+=/full_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
  if S.FullMoon:IsCastable() and (Player:BuffUp(S.EclipseLunar) or S.FullMoon:Charges() == 2 and S.FullMoon:Recharge() < 5 or S.FullMoon:Charges() == 3) and ap_check() and save_for_ca_inc then
    if HR.Cast(S.FullMoon) then return "full_moon 11"; end
  end
  --actions.prepatch_st+=/warrior_of_elune
  if S.WarriorofElune:IsCastable() then
    if HR.Cast(S.WarriorofElune) then return "warrior_of_elune 17"; end
  end
  --actions.prepatch_st+=/starfire,if=(azerite.streaking_stars.rank&buff.ca_inc.remains>execute_time&variable.prev_wrath)|(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starfire)&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up))|(azerite.dawning_sun.rank>2&buff.eclipse_solar.remains>5&!buff.dawning_sun.remains>action.wrath.execute_time)
  --- TODO buff.ca_inc.remains<execute_time is missing here
  if S.Starfire:IsCastable() and (S.StreakingStars:AzeriteRank() and Player:PrevGCDP(1, S.Wrath) or (not S.StreakingStars:AzeriteRank() or Player:PrevGCDP(1, S.Starfire)) and (Player:BuffUp(S.EclipseLunar))) then
    if HR.Cast(S.Starfire) then return "starfire 21"; end
  end
  --actions.prepatch_st+=/wrath
  if S.Wrath:IsCastable() then
    if HR.Cast(S.Wrath) then return "wrath 18"; end
  end
  --actions.prepatch_st+=/run_action_list,name=fallthru
  fallthru()
end

local function aoe()
  --actions.aoe=starfall,if=buff.starfall.refreshable&(!runeforge.lycaras_fleeting_glimpse.equipped|time%%45>buff.starfall.remains+2)
  --- TODO &(!runeforge.lycaras_fleeting_glimpse.equipped|time%%45>buff.starfall.remains+2)
  if S.Starfall:IsCastable() and (Player:BuffRefreshable(S.StarfallBuff)) then
    if HR.Cast(S.Starfall) and starsurgeIsCastable then return "starfall 22"; end
  end
  --actions.aoe+=/variable,name=starfall_wont_fall_off,value=astral_power>80-(10*buff.timeworn_dreambinder.stack)-(buff.starfall.remains*3%spell_haste)-(dot.fury_of_elune.remains*5)&buff.starfall.up
  --- TODO

  --actions.aoe+=/starsurge,if=(buff.timeworn_dreambinder.remains<gcd.max+0.1|buff.timeworn_dreambinder.remains<action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))&variable.starfall_wont_fall_off&buff.timeworn_dreambinder.up
  --- TODO

  --actions.aoe+=/sunfire,target_if=refreshable&target.time_to_die>14-spell_targets+remains,if=ap_check&eclipse.in_any
  if S.Sunfire:IsCastable() and (Target:DebuffRefreshable(S.Sunfire) and Target:TimeToDie() > 14 - enemiesCount8ySplash + Target:DebuffRemains(S.Sunfire)) then
    if ap_check() and eclipseUpAny then
      if HR.Cast(S.Sunfire) then return "sunfire 23"; end
    end
  end
  --actions.aoe+=/adaptive_swarm,target_if=!ticking&!action.adaptive_swarm_damage.in_flight|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3
  --- TODO

  --actions.aoe+=/moonfire,target_if=refreshable&target.time_to_die>(14+(spell_targets.starfire*1.5))%spell_targets+remains,if=(cooldown.ca_inc.ready|spell_targets.starfire<3|(eclipse.in_solar|eclipse.in_both|eclipse.in_lunar&!talent.soul_of_the_forest.enabled)&(spell_targets.starfire<10*(1+talent.twin_moons.enabled))&astral_power>50-buff.starfall.remains*6)&!buff.kindred_empowerment_energize.up&ap_check
  --- TODO check if refreshable&target.time_to_die>(14+(spell_targets.starfire*1.5))%spell_targets+remains is correct implemented
  --- what is spell_targets here? Moonfire withtout the talent "Twin Moon" dont have any spell_targets
  if S.Moonfire:IsCastable() and (Target:DebuffRefreshable(S.Moonfire) and Target:TimeToDie() > (14 + (enemiesCount8ySplash * 1.5)) % 1) then
    --if=(cooldown.ca_inc.ready|spell_targets.starfire<3|(eclipse.in_solar|eclipse.in_both|eclipse.in_lunar&!talent.soul_of_the_forest.enabled)&(spell_targets.starfire<10*(1+talent.twin_moons.enabled))&astral_power>50-buff.starfall.remains*6)&!buff.kindred_empowerment_energize.up&ap_check
    --- TODO i guess its enmiesCount15ySplash for TwinMoons and !buff.kindred_empowerment_energize.up no yet implemented
    if (ca_inc:IsReady() or enemiesCount8ySplash < 3 or (eclipseUpAny and not S.SoulOfTheForest:IsAvailable()) and (enemiesCount8ySplash < 10 * (1 + enemiesCount15ySplash)) and Player:AstraPower() > 50 - Player:BuffRemains(S.Starfall) * 6) and not true and ap_check() then
      if HR.Cast(S.Moonfire) then return "moonfire 24"; end
    end
  end
  --actions.aoe+=/force_of_nature,if=ap_check
  if S.ForceofNature:IsCastable() and ap_check() then
    if HR.Cast(S.ForceofNature) then return "force_of_nature 7"; end
  end
  --actions.aoe+=/ravenous_frenzy,if=buff.ca_inc.up
  --- TODO

  --actions.aoe+=/celestialalignment,if=(buff.starfall.up|astral_power>50)&!buff.solstice.up&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<22|cooldown.convoke_the_spirits.up|!covenant.night_fae)
  --- TODO &(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<22|cooldown.convoke_the_spirits.up|!covenant.night_fae)
  if S.CelestialAlignment:IsCastable() and (Player:BuffUp(S.StarfallBuff) or Player:AstralPower() > 50) and not Player:BuffUp(S.SolsticeBuff) and not Player:BuffUp(ca_inc) then
    if HR.Cast(S.CelestialAlignment) then return "celestialalignment 25"; end
  end
  --actions.aoe+=/incarnation,if=(buff.starfall.up|astral_power>50)&!buff.solstice.up&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<32|cooldown.convoke_the_spirits.up|!covenant.night_fae)
  --- TODO &(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<32|cooldown.convoke_the_spirits.up|!covenant.night_fae)
  if S.Incarnation:IsCastable() and (Player:BuffUp(S.StarfallBuff) or Player:AstralPower() > 50) and not Player:BuffUp(S.SolsticeBuff) and not Player:BuffUp(ca_inc) then
    if HR.Cast(S.Incarnation) then return "celestialalignment 26"; end
  end
  --actions.aoe+=/kindred_spirits,if=interpolated_fight_remains<15|(buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250)&buff.starfall.up&cooldown.ca_inc.remains>50
  --actions.aoe+=/stellar_flare,target_if=refreshable&time_to_die>15,if=spell_targets.starfire<4&ap_check&(buff.ca_inc.remains>10|!buff.ca_inc.up)
  --actions.aoe+=/variable,name=convoke_condition,value=buff.primordial_arcanic_pulsar.value<250-astral_power&(cooldown.ca_inc.remains+10>interpolated_fight_remains|cooldown.ca_inc.remains+30<interpolated_fight_remains&interpolated_fight_remains>130|buff.ca_inc.remains>7)&eclipse.in_any|interpolated_fight_remains%%120<15
  --actions.aoe+=/convoke_the_spirits,if=variable.convoke_condition&astral_power<50
  --actions.aoe+=/fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<250&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord|spell_targets>2)
  --actions.aoe+=/starfall,if=buff.oneths_perception.up&(buff.starfall.refreshable|astral_power>90)
  --actions.aoe+=/starfall,if=covenant.night_fae&variable.convoke_condition&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%50)&buff.starfall.refreshable
  --actions.aoe+=/starsurge,if=covenant.night_fae&variable.convoke_condition&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%30)&buff.starfall.up
  --actions.aoe+=/starsurge,if=buff.oneths_clear_vision.up|!starfire.ap_check|(buff.ca_inc.remains<5&buff.ca_inc.up|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))&variable.starfall_wont_fall_off&spell_targets.starfall<3
  --actions.aoe+=/new_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
  --actions.aoe+=/half_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
  --actions.aoe+=/full_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
  --actions.aoe+=/warrior_of_elune
  --actions.aoe+=/variable,name=starfire_in_solar,value=spell_targets.starfire>8+floor(mastery_value%20)+floor(buff.starsurge_empowerment.stack%4)
  --actions.aoe+=/wrath,if=eclipse.lunar_next|eclipse.any_next&variable.is_cleave|eclipse.in_solar&!variable.starfire_in_solar|buff.ca_inc.remains<action.starfire.execute_time&!variable.is_cleave&buff.ca_inc.remains<execute_time&buff.ca_inc.up|buff.ravenous_frenzy.up&spell_haste>0.6|!variable.is_cleave&buff.ca_inc.remains>execute_time
  --actions.aoe+=/starfire
  --actions.aoe+=/run_action_list,name=fallthru
  fallthru()
end

local function EnemiesInPlayerRange(range)
  return Player:GetEnemiesInMeleeRange(range)
end

local function EnemiesInSplashRange(range)
  return Target:GetEnemiesInSplashRangeCount(range)
end

--- ======= MAIN =======
local function APL()
  -- Local Update
  enemiesInStarfallRange = EnemiesInPlayerRange(starfallRange)
  enemiesCountInStarfallRange = #enemiesInStarfallRange
  enemies45y = Player:GetEnemiesInRange(45)
  eclipseUpAny = (Player:BuffUp(S.EclipseSolar) or Player:BuffUp(S.EclipseLunar))
  starsurgeIsCastable = (Player:AstralPower() >= 30)
  starfallIsCastable = (Player:AstralPower() >= 50)

  --actions+=/variable,name=prev_starsurge,value=prev.starsurge
  prev_starsurge = (Player:PrevGCDP(1, S.Starsurge))
  --actions+=/variable,name=prev_wrath,value=prev.wrath
  prev_wrath = (Player:PrevGCDP(1, S.Wrath))
  --actions+=/variable,name=prev_starfire,value=prev.starfire
  prev_starfire = (Player:PrevGCDP(1, S.Starfire))

  if AoEON() then
    enemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    enemiesCount15ySplash = Target:GetEnemiesInSplashRangeCount(15)
  else
    enemiesCount8ySplash = 1
    enemiesCount15ySplash = 1
  end
  -- Unit Update

  -- Defensives

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then
      local ShouldReturn = precombat(); if ShouldReturn then return ShouldReturn; end
    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then

    --actions=variable,name=is_aoe,value=spell_targets.starfall>1&(!talent.starlord.enabled|talent.stellar_drift.enabled)|spell_targets.starfall>2
    is_aoe = enemiesCountInStarfallRange > 1 and (not S.Starlord:IsAvailable() or S.StellarDrift:IsAvailable()) or enemiesCountInStarfallRange > 2
    --actions+=/variable,name=is_cleave,value=spell_targets.starfire>1
    is_cleave = EnemiesInSplashRange(starfireSplashRange)
    --actions+=/berserking,if=(!covenant.night_fae|!cooldown.convoke_the_spirits.up)&buff.ca_inc.up
    --actions+=/potion,if=buff.ca_inc.up
    --actions+=/use_items
    --actions+=/heart_essence,if=level=50
    --actions+=/run_action_list,name=aoe,if=variable.is_aoe
    if is_aoe then
      local ShouldReturn = aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/run_action_list,name=dreambinder,if=runeforge.timeworn_dreambinder.equipped
    --actions+=/run_action_list,name=boat,if=runeforge.balance_of_all_things.equipped
    --actions+=/run_action_list,name=st,if=level>50
    --actions+=/variable,name=prev_wrath,value=prev.wrath
    --actions+=/variable,name=prev_starfire,value=prev.starfire
    --actions+=/variable,name=prev_starsurge,value=prev.starsurge
    --actions+=/run_action_list,name=prepatch_st
    prepatch_st()

    return
  end
end

HR.SetAPL(102, APL)


--- ======= SIMC =======
-- Last Update: 12/31/2999

-- APL goes here

--  # Executed every time the actor is available.
--actions=variable,name=is_aoe,value=spell_targets.starfall>1&(!talent.starlord.enabled|talent.stellar_drift.enabled)|spell_targets.starfall>2
--actions+=/variable,name=is_cleave,value=spell_targets.starfire>1
--actions+=/berserking,if=(!covenant.night_fae|!cooldown.convoke_the_spirits.up)&buff.ca_inc.up
--actions+=/potion,if=buff.ca_inc.up
--actions+=/use_items
--actions+=/heart_essence,if=level=50
--actions+=/run_action_list,name=aoe,if=variable.is_aoe
--actions+=/run_action_list,name=dreambinder,if=runeforge.timeworn_dreambinder.equipped
--actions+=/run_action_list,name=boat,if=runeforge.balance_of_all_things.equipped
--actions+=/run_action_list,name=st,if=level>50
--actions+=/variable,name=prev_wrath,value=prev.wrath
--actions+=/variable,name=prev_starfire,value=prev.starfire
--actions+=/variable,name=prev_starsurge,value=prev.starsurge
--actions+=/run_action_list,name=prepatch_st

--actions.aoe=starfall,if=buff.starfall.refreshable&(!runeforge.lycaras_fleeting_glimpse.equipped|time%%45>buff.starfall.remains+2)
--actions.aoe+=/variable,name=starfall_wont_fall_off,value=astral_power>80-(10*buff.timeworn_dreambinder.stack)-(buff.starfall.remains*3%spell_haste)-(dot.fury_of_elune.remains*5)&buff.starfall.up
--actions.aoe+=/starsurge,if=(buff.timeworn_dreambinder.remains<gcd.max+0.1|buff.timeworn_dreambinder.remains<action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))&variable.starfall_wont_fall_off&buff.timeworn_dreambinder.up
--actions.aoe+=/sunfire,target_if=refreshable&target.time_to_die>14-spell_targets+remains,if=ap_check&eclipse.in_any
--actions.aoe+=/adaptive_swarm,target_if=!ticking&!action.adaptive_swarm_damage.in_flight|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3
--actions.aoe+=/moonfire,target_if=refreshable&target.time_to_die>(14+(spell_targets.starfire*1.5))%spell_targets+remains,if=(cooldown.ca_inc.ready|spell_targets.starfire<3|(eclipse.in_solar|eclipse.in_both|eclipse.in_lunar&!talent.soul_of_the_forest.enabled)&(spell_targets.starfire<10*(1+talent.twin_moons.enabled))&astral_power>50-buff.starfall.remains*6)&!buff.kindred_empowerment_energize.up&ap_check
--actions.aoe+=/force_of_nature,if=ap_check
--actions.aoe+=/ravenous_frenzy,if=buff.ca_inc.up
--actions.aoe+=/celestial_alignment,if=(buff.starfall.up|astral_power>50)&!buff.solstice.up&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<22|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.aoe+=/incarnation,if=(buff.starfall.up|astral_power>50)&!buff.solstice.up&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains%%180<32|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.aoe+=/kindred_spirits,if=interpolated_fight_remains<15|(buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250)&buff.starfall.up&cooldown.ca_inc.remains>50
--actions.aoe+=/stellar_flare,target_if=refreshable&time_to_die>15,if=spell_targets.starfire<4&ap_check&(buff.ca_inc.remains>10|!buff.ca_inc.up)
--actions.aoe+=/variable,name=convoke_condition,value=buff.primordial_arcanic_pulsar.value<250-astral_power&(cooldown.ca_inc.remains+10>interpolated_fight_remains|cooldown.ca_inc.remains+30<interpolated_fight_remains&interpolated_fight_remains>130|buff.ca_inc.remains>7)&eclipse.in_any|interpolated_fight_remains%%120<15
--actions.aoe+=/convoke_the_spirits,if=variable.convoke_condition&astral_power<50
--actions.aoe+=/fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<250&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord|spell_targets>2)
--actions.aoe+=/starfall,if=buff.oneths_perception.up&(buff.starfall.refreshable|astral_power>90)
--actions.aoe+=/starfall,if=covenant.night_fae&variable.convoke_condition&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%50)&buff.starfall.refreshable
--actions.aoe+=/starsurge,if=covenant.night_fae&variable.convoke_condition&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%30)&buff.starfall.up
--actions.aoe+=/starsurge,if=buff.oneths_clear_vision.up|!starfire.ap_check|(buff.ca_inc.remains<5&buff.ca_inc.up|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))&variable.starfall_wont_fall_off&spell_targets.starfall<3
--actions.aoe+=/new_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.aoe+=/half_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.aoe+=/full_moon,if=(eclipse.in_any&cooldown.ca_inc.remains>50|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.aoe+=/warrior_of_elune
--actions.aoe+=/variable,name=starfire_in_solar,value=spell_targets.starfire>8+floor(mastery_value%20)+floor(buff.starsurge_empowerment.stack%4)
--actions.aoe+=/wrath,if=eclipse.lunar_next|eclipse.any_next&variable.is_cleave|eclipse.in_solar&!variable.starfire_in_solar|buff.ca_inc.remains<action.starfire.execute_time&!variable.is_cleave&buff.ca_inc.remains<execute_time&buff.ca_inc.up|buff.ravenous_frenzy.up&spell_haste>0.6|!variable.is_cleave&buff.ca_inc.remains>execute_time
--actions.aoe+=/starfire
--actions.aoe+=/run_action_list,name=fallthru

--actions.boat=ravenous_frenzy,if=buff.ca_inc.up
--actions.boat+=/variable,name=critnotup,value=!buff.balance_of_all_things_nature.up&!buff.balance_of_all_things_arcane.up
--actions.boat+=/cancel_buff,name=starlord,if=(buff.balance_of_all_things_nature.remains>4.5|buff.balance_of_all_things_arcane.remains>4.5)&astral_power>=90&(cooldown.ca_inc.remains>7|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))
--actions.boat+=/starsurge,if=!variable.critnotup&((!cooldown.convoke_the_spirits.up|!variable.convoke_condition|!covenant.night_fae)&(covenant.night_fae|(cooldown.ca_inc.remains>7|(cooldown.empower_bond.remains>7&!buff.kindred_empowerment_energize.up&covenant.kyrian))))|(cooldown.convoke_the_spirits.up&cooldown.ca_inc.ready&covenant.night_fae)
--actions.boat+=/adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>5)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3&dot.adaptive_swarm_damage.ticking
--actions.boat+=/sunfire,target_if=refreshable&target.time_to_die>16,if=ap_check&(variable.critnotup|(astral_power<30&!buff.ca_inc.up)|cooldown.ca_inc.ready)
--actions.boat+=/moonfire,target_if=refreshable&target.time_to_die>13.5,if=ap_check&(variable.critnotup|(astral_power<30&!buff.ca_inc.up)|cooldown.ca_inc.ready)&!buff.kindred_empowerment_energize.up
--actions.boat+=/stellar_flare,target_if=refreshable&target.time_to_die>16+remains,if=ap_check&(variable.critnotup|astral_power<30|cooldown.ca_inc.ready)
--actions.boat+=/force_of_nature,if=ap_check
--actions.boat+=/fury_of_elune,if=(eclipse.in_any|eclipse.solar_in_1|eclipse.lunar_in_1)&(!covenant.night_fae|(astral_power<95&(variable.critnotup|astral_power<30|variable.is_aoe)&(variable.convoke_desync&!cooldown.convoke_the_spirits.up|!variable.convoke_desync&!cooldown.ca_inc.up)))&(cooldown.ca_inc.remains>30|astral_power>90&cooldown.ca_inc.up&(cooldown.empower_bond.remains<action.starfire.execute_time|!covenant.kyrian)|interpolated_fight_remains<10)&(dot.adaptive_swarm_damage.remains>4|!covenant.necrolord)
--actions.boat+=/kindred_spirits,if=(eclipse.lunar_next|eclipse.solar_next|eclipse.any_next|buff.balance_of_all_things_nature.remains>4.5|buff.balance_of_all_things_arcane.remains>4.5|astral_power>90&cooldown.ca_inc.ready)&(cooldown.ca_inc.remains>30|cooldown.ca_inc.ready)|interpolated_fight_remains<10
--actions.boat+=/celestial_alignment,if=(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|buff.bloodlust.up&buff.bloodlust.remains<20+(4*conduit.precise_alignment.enabled))&(!covenant.night_fae|cooldown.convoke_the_spirits.up|interpolated_fight_remains<cooldown.convoke_the_spirits.remains+6|interpolated_fight_remains%%180<20+(4*conduit.precise_alignment.enabled))
--actions.boat+=/incarnation,if=(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|buff.bloodlust.up&buff.bloodlust.remains<30+(4*conduit.precise_alignment.enabled))&(!covenant.night_fae|cooldown.convoke_the_spirits.up|variable.convoke_desync&interpolated_fight_remains>180+20+(4*conduit.precise_alignment.enabled)|interpolated_fight_remains<cooldown.convoke_the_spirits.remains+6|interpolated_fight_remains<30+(4*conduit.precise_alignment.enabled))
--actions.boat+=/convoke_the_spirits,if=(variable.convoke_desync&interpolated_fight_remains>130|buff.ca_inc.up)&(buff.balance_of_all_things_nature.stack_value>30|buff.balance_of_all_things_arcane.stack_value>30)|interpolated_fight_remains<10
--actions.boat+=/starsurge,if=covenant.night_fae&(variable.convoke_desync|cooldown.ca_inc.remains<10)&astral_power>50&cooldown.convoke_the_spirits.remains<10
--actions.boat+=/variable,name=aspPerSec,value=eclipse.in_lunar*8%action.starfire.execute_time+!eclipse.in_lunar*6%action.wrath.execute_time+0.2%spell_haste
--actions.boat+=/starsurge,if=(interpolated_fight_remains<4|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))|(astral_power+variable.aspPerSec*buff.eclipse_solar.remains+dot.fury_of_elune.ticks_remain*2.5>120|astral_power+variable.aspPerSec*buff.eclipse_lunar.remains+dot.fury_of_elune.ticks_remain*2.5>120)&eclipse.in_any&((!cooldown.ca_inc.up|covenant.kyrian&!cooldown.empower_bond.up)|covenant.night_fae)&(!covenant.venthyr|!buff.ca_inc.up|astral_power>90)|buff.ca_inc.remains>8&!buff.ravenous_frenzy.up
--actions.boat+=/new_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.boat+=/half_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.boat+=/full_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check
--actions.boat+=/warrior_of_elune
--actions.boat+=/starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&eclipse.in_lunar|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
--actions.boat+=/wrath
--actions.boat+=/run_action_list,name=fallthru

--actions.dreambinder=variable,name=safe_to_use_spell,value=(buff.timeworn_dreambinder.remains>gcd.max+0.1&(eclipse.in_both|eclipse.in_solar|eclipse.lunar_next)|buff.timeworn_dreambinder.remains>action.starfire.execute_time+0.1&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next))|!buff.timeworn_dreambinder.up
--actions.dreambinder+=/starsurge,if=(!variable.safe_to_use_spell|(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up))|astral_power>90
--actions.dreambinder+=/adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>5)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3&dot.adaptive_swarm_damage.ticking
--actions.dreambinder+=/moonfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.dreambinder+=/sunfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.dreambinder+=/stellar_flare,target_if=refreshable&target.time_to_die>16,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.dreambinder+=/force_of_nature,if=ap_check
--actions.dreambinder+=/ravenous_frenzy,if=buff.ca_inc.up
--actions.dreambinder+=/kindred_spirits,if=((buff.eclipse_solar.remains>10|buff.eclipse_lunar.remains>10)&cooldown.ca_inc.remains>30)|cooldown.ca_inc.ready
--actions.dreambinder+=/celestial_alignment,if=(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|variable.is_aoe|buff.bloodlust.up&buff.bloodlust.remains<20+(4*conduit.precise_alignment.enabled)&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains<22|interpolated_fight_remains%%180<22|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.dreambinder+=/incarnation,if=(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|variable.is_aoe|buff.bloodlust.up&buff.bloodlust.remains<30+(4*conduit.precise_alignment.enabled)&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains<32|interpolated_fight_remains%%180<32|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.dreambinder+=/variable,name=convoke_condition,value=covenant.night_fae&(buff.primordial_arcanic_pulsar.value<240&(cooldown.ca_inc.remains+10>interpolated_fight_remains|cooldown.ca_inc.remains+30<interpolated_fight_remains&interpolated_fight_remains>130|buff.ca_inc.remains>7)&buff.eclipse_solar.remains>10|interpolated_fight_remains%%120<15)
--actions.dreambinder+=/variable,name=save_for_ca_inc,value=(!cooldown.ca_inc.ready|!variable.convoke_condition&covenant.night_fae)
--actions.dreambinder+=/convoke_the_spirits,if=variable.convoke_condition&astral_power<40
--actions.dreambinder+=/fury_of_elune,if=eclipse.in_any&ap_check&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord)&variable.save_for_ca_inc
--actions.dreambinder+=/starsurge,if=covenant.night_fae&variable.convoke_condition&astral_power>=40&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%30)
--actions.dreambinder+=/new_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
--actions.dreambinder+=/half_moon,if=(buff.eclipse_lunar.up&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.dreambinder+=/full_moon,if=(buff.eclipse_lunar.up&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.dreambinder+=/warrior_of_elune
--actions.dreambinder+=/starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
--actions.dreambinder+=/wrath
--actions.dreambinder+=/run_action_list,name=fallthru

--actions.fallthru=starsurge,if=!runeforge.balance_of_all_things.equipped
--actions.fallthru+=/sunfire,target_if=dot.moonfire.remains>remains
--actions.fallthru+=/moonfire

--actions.prepatch_st=moonfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
--actions.prepatch_st+=/sunfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
--actions.prepatch_st+=/stellar_flare,target_if=refreshable&target.time_to_die>16,if=(buff.ca_inc.remains>5|!buff.ca_inc.up|astral_power<30)&ap_check
--actions.prepatch_st+=/force_of_nature,if=ap_check
--actions.prepatch_st+=/celestial_alignment,if=(astral_power>90|buff.bloodlust.up&buff.bloodlust.remains<26)&!buff.ca_inc.up
--actions.prepatch_st+=/incarnation,if=(astral_power>90|buff.bloodlust.up&buff.bloodlust.remains<36)&!buff.ca_inc.up
--actions.prepatch_st+=/variable,name=save_for_ca_inc,value=!cooldown.ca_inc.ready
--actions.prepatch_st+=/fury_of_elune,if=eclipse.in_any&ap_check&variable.save_for_ca_inc
--actions.prepatch_st+=/cancel_buff,name=starlord,if=buff.starlord.remains<6&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&astral_power>90
--actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&(buff.ca_inc.up|astral_power>90&eclipse.in_any)
--actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&talent.starlord.enabled&(buff.starlord.up|astral_power>90)&buff.starlord.stack<3&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&cooldown.ca_inc.remains>7
--actions.prepatch_st+=/starsurge,if=(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starsurge)&buff.eclipse_solar.remains>7&eclipse.in_solar&!talent.starlord.enabled&cooldown.ca_inc.remains>7
--actions.prepatch_st+=/new_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
--actions.prepatch_st+=/half_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.prepatch_st+=/full_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.prepatch_st+=/warrior_of_elune
--actions.prepatch_st+=/starfire,if=(azerite.streaking_stars.rank&buff.ca_inc.remains>execute_time&variable.prev_wrath)|(!azerite.streaking_stars.rank|buff.ca_inc.remains<execute_time|!variable.prev_starfire)&(eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up))|(azerite.dawning_sun.rank>2&buff.eclipse_solar.remains>5&!buff.dawning_sun.remains>action.wrath.execute_time)
--actions.prepatch_st+=/wrath
--actions.prepatch_st+=/run_action_list,name=fallthru

--actions.st=adaptive_swarm,target_if=!dot.adaptive_swarm_damage.ticking&!action.adaptive_swarm_damage.in_flight&(!dot.adaptive_swarm_heal.ticking|dot.adaptive_swarm_heal.remains>5)|dot.adaptive_swarm_damage.stack<3&dot.adaptive_swarm_damage.remains<3&dot.adaptive_swarm_damage.ticking
--actions.st+=/moonfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.st+=/sunfire,target_if=refreshable&target.time_to_die>12,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.st+=/stellar_flare,target_if=refreshable&target.time_to_die>16,if=(buff.ca_inc.remains>5&(buff.ravenous_frenzy.remains>5|!buff.ravenous_frenzy.up)|!buff.ca_inc.up|astral_power<30)&(!buff.kindred_empowerment_energize.up|astral_power<30)&ap_check
--actions.st+=/force_of_nature,if=ap_check
--actions.st+=/ravenous_frenzy,if=buff.ca_inc.up
--actions.st+=/kindred_spirits,if=((buff.eclipse_solar.remains>10|buff.eclipse_lunar.remains>10)&cooldown.ca_inc.remains>30&(buff.primordial_arcanic_pulsar.value<240|!runeforge.primordial_arcanic_pulsar.equipped))|buff.primordial_arcanic_pulsar.value>=270|cooldown.ca_inc.ready&(astral_power>90|variable.is_aoe)
--actions.st+=/celestial_alignment,if=(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|variable.is_aoe|buff.bloodlust.up&buff.bloodlust.remains<20+((9*runeforge.primordial_arcanic_pulsar.equipped)+(4*conduit.precise_alignment.enabled)))&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains<22+(9*(buff.primordial_arcanic_pulsar.value>100))|interpolated_fight_remains%%180<22|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.st+=/incarnation,if=(astral_power>90&(buff.kindred_empowerment_energize.up|!covenant.kyrian)|covenant.night_fae|variable.is_aoe|buff.bloodlust.up&buff.bloodlust.remains<30+((9*runeforge.primordial_arcanic_pulsar.equipped)+(4*conduit.precise_alignment.enabled)))&!buff.ca_inc.up&(interpolated_fight_remains<cooldown.convoke_the_spirits.remains+7|interpolated_fight_remains<32+(9*(buff.primordial_arcanic_pulsar.value>100))|interpolated_fight_remains%%180<32|cooldown.convoke_the_spirits.up|!covenant.night_fae)
--actions.st+=/variable,name=convoke_condition,value=covenant.night_fae&(buff.primordial_arcanic_pulsar.value<240&(cooldown.ca_inc.remains+10>interpolated_fight_remains|cooldown.ca_inc.remains+30<interpolated_fight_remains&interpolated_fight_remains>130|buff.ca_inc.remains>7)&buff.eclipse_solar.remains>10|interpolated_fight_remains%%120<15)
--actions.st+=/variable,name=save_for_ca_inc,value=(!cooldown.ca_inc.ready|!variable.convoke_condition&covenant.night_fae)
--actions.st+=/convoke_the_spirits,if=variable.convoke_condition&astral_power<30
--actions.st+=/fury_of_elune,if=eclipse.in_any&ap_check&buff.primordial_arcanic_pulsar.value<240&(dot.adaptive_swarm_damage.ticking|!covenant.necrolord)&variable.save_for_ca_inc
--actions.st+=/starfall,if=buff.oneths_perception.up&buff.starfall.refreshable
--actions.st+=/cancel_buff,name=starlord,if=buff.starlord.remains<5&(buff.eclipse_solar.remains>5|buff.eclipse_lunar.remains>5)&astral_power>90
--actions.st+=/starsurge,if=covenant.night_fae&variable.convoke_condition&cooldown.convoke_the_spirits.remains<gcd.max*ceil(astral_power%30)
--actions.st+=/starfall,if=talent.stellar_drift.enabled&!talent.starlord.enabled&buff.starfall.refreshable&(buff.eclipse_lunar.remains>6&eclipse.in_lunar&buff.primordial_arcanic_pulsar.value<250|buff.primordial_arcanic_pulsar.value>=250&astral_power>90|dot.adaptive_swarm_damage.remains>8|action.adaptive_swarm_damage.in_flight)&!cooldown.ca_inc.ready
--actions.st+=/starsurge,if=buff.oneths_clear_vision.up|buff.kindred_empowerment_energize.up|buff.ca_inc.up&(buff.ravenous_frenzy.remains<gcd.max*ceil(astral_power%30)&buff.ravenous_frenzy.up|!buff.ravenous_frenzy.up&!cooldown.ravenous_frenzy.ready|!covenant.venthyr)|astral_power>90&eclipse.in_any
--actions.st+=/starsurge,if=talent.starlord.enabled&(buff.starlord.up|astral_power>90)&buff.starlord.stack<3&(buff.eclipse_solar.up|buff.eclipse_lunar.up)&buff.primordial_arcanic_pulsar.value<270&(cooldown.ca_inc.remains>10|!variable.convoke_condition&covenant.night_fae)
--actions.st+=/starsurge,if=(buff.primordial_arcanic_pulsar.value<270|buff.primordial_arcanic_pulsar.value<250&talent.stellar_drift.enabled)&buff.eclipse_solar.remains>7&eclipse.in_solar&!buff.oneths_perception.up&!talent.starlord.enabled&cooldown.ca_inc.remains>7&(cooldown.kindred_spirits.remains>7|!covenant.kyrian)
--actions.st+=/new_moon,if=(buff.eclipse_lunar.up|(charges=2&recharge_time<5)|charges=3)&ap_check&variable.save_for_ca_inc
--actions.st+=/half_moon,if=(buff.eclipse_lunar.up&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.st+=/full_moon,if=(buff.eclipse_lunar.up&!covenant.kyrian|(buff.kindred_empowerment_energize.up&covenant.kyrian)|(charges=2&recharge_time<5)|charges=3|buff.ca_inc.up)&ap_check&variable.save_for_ca_inc
--actions.st+=/warrior_of_elune
--actions.st+=/starfire,if=eclipse.in_lunar|eclipse.solar_next|eclipse.any_next|buff.warrior_of_elune.up&buff.eclipse_lunar.up|(buff.ca_inc.remains<action.wrath.execute_time&buff.ca_inc.up)
--actions.st+=/wrath
--actions.st+=/run_action_list,name=fallthru
