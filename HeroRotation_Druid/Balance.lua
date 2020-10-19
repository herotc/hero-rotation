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

-- Lua

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
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
  {S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end},
};

-- Variables
local enemiesCountInStarfallRange, enemiesInStarfallRange

local starfallRange = 45
local starfireSplashRange = 8
local sunfireSplashRange = 8
local moonfireSplashRange = (S.TwinMoons:IsAvailable()) and 8 or 0

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
  -- solar_wrath
  if S.Wrath:IsCastable() and (not Player:PrevGCD(1, S.Wrath) and not Player:PrevGCD(2, S.Wrath)) then
    if HR.Cast(S.Wrath) then return "wrath 2"; end
  end
  --actions.precombat+=/wrath
  if S.Wrath:IsCastable() and (Player:PrevGCD(1, S.Wrath) and not Player:PrevGCD(2, S.Wrath)) then
    if HR.Cast(S.Wrath) then return "wrath 3"; end
  end
  --actions.precombat+=/starfire
  if S.Starfire:IsCastable() and (Player:PrevGCD(1, S.Wrath) and Player:PrevGCD(2, S.Wrath)) then
    if HR.Cast(S.Starfire) then return "starfire 4"; end
end
  --actions.precombat+=/variable,name=convoke_desync,value=floor((interpolated_fight_remains-20)%120)>floor((interpolated_fight_remains-25-(10*talent.incarnation.enabled)-(4*conduit.precise_alignment.enabled))%180)
end

local function prepatch_st()
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
end

local function EnemiesInPlayerRange(range)
  return Player:GetEnemiesInMeleeRange(range)
end

local function EnemiesInSplashRange(range)
  return Target:GetEnemiesInSplashRangeCount(range)
end

--- ======= MAIN =======
local function APL ()
  -- Local Update
  enemiesInStarfallRange =  EnemiesInPlayerRange(starfallRange)
  enemiesCountInStarfallRange = #enemiesInStarfallRange
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
    local is_aoe = enemiesCountInStarfallRange > 1 and (not S.Starlord:IsAvailable() or S.StellarDrift:IsAvailable()) or enemiesCountInStarfallRange > 2
    if is_aoe then
      --local ShouldReturn = aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/variable,name=is_cleave,value=spell_targets.starfire>1
    local is_cleave = EnemiesInSplashRange(starfireSplashRange)
    if is_cleave then
      --local ShouldReturn = cleave(); if ShouldReturn then return ShouldReturn; end
    end
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
    prepatch_st()

    return
  end
end

HR.SetAPL(102, APL)


--- ======= SIMC =======
-- Last Update: 12/31/2999

-- APL goes here

--# Executed every time the actor is available.


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
