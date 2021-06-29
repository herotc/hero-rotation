--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
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
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
local Mage       = HR.Commons.Mage
-- lua
local max        = math.max

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Frost
local I = Item.Mage.Frost

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local EnemiesCount6ySplash, EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local EnemiesCount15yMelee  --Enemies arround player
local Enemies16ySplash
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied
local fightRemains
local TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
local GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
local FreezingWindsEquipped = Player:HasLegendaryEquipped(4)
local GlacialFragmentsEquipped = Player:HasLegendaryEquipped(5)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
local HeartoftheFaeEquipped = Player:HasLegendaryEquipped(260)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost
}

S.FrozenOrb:RegisterInFlightEffect(84721)
S.FrozenOrb:RegisterInFlight()
HL:RegisterForEvent(function() S.FrozenOrb:RegisterInFlight() end, "LEARNED_SPELL_IN_TAB")
S.Frostbolt:RegisterInFlightEffect(228597)--also register hitting spell to track in flight (spell book id ~= hitting id)
S.Frostbolt:RegisterInFlight()
S.Flurry:RegisterInFlightEffect(228354)
S.Flurry:RegisterInFlight()
S.IceLance:RegisterInFlightEffect(228598)
S.IceLance:RegisterInFlight()

HL:RegisterForEvent(function()
  TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
  GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
  FreezingWindsEquipped = Player:HasLegendaryEquipped(4)
  GlacialFragmentsEquipped = Player:HasLegendaryEquipped(5)
  DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
  HeartoftheFaeEquipped = Player:HasLegendaryEquipped(260)
end, "PLAYER_EQUIPMENT_CHANGED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function FrozenRemains()
  return max(Target:DebuffRemains(S.Frostbite), Target:DebuffRemains(S.Freeze), Target:DebuffRemains(S.FrostNova))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 1"; end
  end
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if Cast(S.SummonWaterElemental) then return "summon_water_elemental precombat 2"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- blizzard,if=active_enemies>=2
    -- TODO
    -- frostbolt,if=active_enemies=1
    if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
      if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 5"; end
    end
    -- frozen_orb
    if S.FrozenOrb:IsCastable() then
      if Cast(S.FrozenOrb, nil, nil, not Target:IsInRange(40)) then return "frozen_orb precombat 6"; end
    end
  end
end

local function Cooldowns()
  -- use_item,name=shadowed_orb_of_torment,if=buff.rune_of_power.down
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment cd 1"; end
  end
  -- potion,if=prev_off_gcd.icy_veins|fight_remains<30
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (Player:PrevGCDP(1, S.IcyVeins) or fightRemains < 30) then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cd 2"; end
  end
  -- deathborne
  if S.Deathborne:IsCastable() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cd 3"; end
  end
  -- mirrors_of_torment,if=active_enemies<3&(conduit.siphoned_malice.enabled|soulbind.wasteland_propriety.enabled)
  if S.MirrorsofTorment:IsCastable() and (EnemiesCount8ySplash < 3 and (S.SiphonedMalice:ConduitEnabled() or S.WastelandPropriety:IsAvailable())) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment cd 4"; end
  end
  -- rune_of_power,if=cooldown.icy_veins.remains>12&buff.rune_of_power.down
  if S.RuneofPower:IsCastable() and (S.IcyVeins:CooldownRemains() > S.RuneofPower:BaseDuration() or fightRemains < S.RuneofPower:CastTime() + Player:GCD()) then
    if Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 5"; end
  end
  -- icy_veins,if=buff.rune_of_power.down&(buff.icy_veins.down|talent.rune_of_power)&(buff.slick_ice.down|active_enemies>=2)
  if S.IcyVeins:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (Player:BuffDown(S.IcyVeins) or S.RuneofPower:IsAvailable()) and (Player:BuffDown(S.SlickIceBuff) or EnemiesCount8ySplash >= 2)) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 6"; end
  end
  -- time_warp,if=runeforge.temporal_warp&buff.exhaustion.up&(prev_off_gcd.icy_veins|fight_remains<40)
  if S.TimeWarp:IsCastable() and Settings.Frost.UseTemporalWarp and (TemporalWarpEquipped and Player:BloodlustExhaustUp() and Player:BloodlustDown() and (Player:BuffUp(S.IcyVeins) or fightRemains < 40)) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 7"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name() .. " cd 8" end
    end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 9"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 10"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 11"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 12"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 13"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 14"; end
  end
end

local function Aoe()
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 1"; end
  end
  -- blizzard
  if S.Blizzard:IsCastable() then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 2"; end
  end
  -- flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&buff.fingers_of_frost.react=0)
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and Player:BuffDown(S.FingersofFrostBuff))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 3"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() and (EnemiesCount8ySplash >= 5) then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 4"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() and (EnemiesCount6ySplash >= 5) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 5"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and EnemiesCount8ySplash >= 2 and (Player:BuffUp(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or Target:DebuffStack(S.WintersChillDebuff) > 1 and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 6"; end
  end
  if CDsON() then
    -- radiant_spark,if=soulbind.combat_meditation
    if S.RadiantSpark:IsCastable() and (S.CombatMeditation:IsAvailable()) then
      if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe 7"; end
    end
    -- mirrors_of_torment
    if S.MirrorsofTorment:IsCastable() then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment aoe 8"; end
    end
    -- shifting_power
    if S.ShiftingPower:IsCastable() then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power aoe 9"; end
    end
  end
  -- fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0) then
    if Cast(S.FireBlast) then return "fire_blast aoe 11"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=6&!runeforge.glacial_fragments
  -- Note: Using 8y splash instead of 10y to account for distance from caster to the target after moving into range
  if S.ArcaneExplosion:IsCastable() and (Player:ManaPercentageP() > 30 and EnemiesCount8ySplash >= 6 and not GlacialFragmentsEquipped) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion aoe 12 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 12"; end
    end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 13"; end
  end
  -- ice_lance,if=runeforge.glacial_fragments.equipped&talent.splitting_ice.enabled&travel_time<ground_aoe.blizzard.remains
  local BlizzardRemains = 7 - S.Blizzard:TimeSinceLastCast()
  if BlizzardRemains < 0 then BlizzardRemains = 0 end
  if S.IceLance:IsCastable() and (GlacialFragmentsEquipped and S.SplittingIce:IsAvailable() and S.IceLance:TravelTime() < BlizzardRemains) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 14"; end
  end
  -- wait,sec=0.1,if=runeforge.glacial_fragments.equipped&talent.splitting_ice.enabled
  -- NYI wait
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 15"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 16"; end
  end
end

local function Single()
  -- flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!conduit.ire_of_the_ascended|cooldown.radiant_spark.remains|runeforge.freezing_winds)|prev_gcd.1.radiant_spark|buff.fingers_of_frost.react=0&(debuff.mirrors_of_torment.up|buff.freezing_winds.up|buff.expanded_potential.react)))
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:IsCasting(S.GlacialSpike) or Player:IsCasting(S.Frostbolt) and (not S.IreOfTheAscended:ConduitEnabled() or S.RadiantSpark:CooldownRemains() > 0 or FreezingWindsEquipped) or Player:IsCasting(S.RadiantSpark) or Player:BuffDown(S.FingersofFrostBuff) and (Target:DebuffUp(S.MirrorsofTorment) or Player:BuffUp(S.FreezingWindsBuff) or Player:BuffUp(S.ExpandedPotentialBuff))))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 1"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 2"; end
  end
  -- blizzard,if=buff.freezing_rain.up|active_enemies>=2
  if S.Blizzard:IsCastable() and (Player:BuffUp(S.FreezingRain) or EnemiesCount16ySplash >= 2) then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 3"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1&debuff.winters_chill.remains
  if S.RayofFrost:IsCastable() and (Target:DebuffStack(S.WintersChillDebuff) == 1) then
    if Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 4"; end
  end
  -- glacial_spike,if=remaining_winters_chill&debuff.winters_chill.remains>cast_time+travel_time
  if S.GlacialSpike:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff) and Target:DebuffRemains(S.WintersChillDebuff) > S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime()) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 5"; end
  end
  -- ice_lance,if=remaining_winters_chill&remaining_winters_chill>buff.fingers_of_frost.react&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff) and Target:DebuffStack(S.WintersChillDebuff) > num(Player:BuffUp(S.FingersofFrostBuff)) and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 6"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 7"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 8"; end
  end
  if CDsON() then
    -- radiant_spark,if=buff.freezing_winds.up&active_enemies=1
    if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.FreezingWindsBuff) and EnemiesCount16ySplash == 1) then
      if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 9"; end
    end
    -- radiant_spark,if=buff.brain_freeze.react&talent.glacial_spike&conduit.ire_of_the_ascended&buff.icicles.stack>=4
    if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff)and S.GlacialSpike:IsAvailable() and S.IreOfTheAscended:ConduitEnabled() and Player:BuffStack(S.IciclesBuff) >= 4) then
      if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 10"; end
    end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time
  if S.IceLance:IsCastable() and (Player:BuffUp(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 11"; end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 12"; end
  end
  if CDsON() then
    -- radiant_spark,if=(!talent.glacial_spike|!conduit.ire_of_the_ascended)&(!runeforge.freezing_winds|active_enemies>=2)&buff.brain_freeze.react
    if S.RadiantSpark:IsCastable() and ((not S.GlacialSpike:IsAvailable() or not S.IreOfTheAscended:ConduitEnabled()) and (not FreezingWindsEquipped or EnemiesCount15yMelee >= 2) and Player:BuffUp(S.BrainFreezeBuff)) then
      if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 13"; end
    end
    -- mirrors_of_torment
    if S.MirrorsofTorment:IsCastable() then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment single 14"; end
    end
    -- shifting_power,if=buff.rune_of_power.down&(runeforge.heart_of_the_fae|soulbind.grove_invigoration|soulbind.field_of_blossoms|runeforge.freezing_winds&buff.freezing_winds.down|active_enemies>=2)
    if S.ShiftingPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (HeartoftheFaeEquipped or S.GroveInvigoration:IsAvailable() or S.FieldOfBlossoms:IsAvailable() or FreezingWindsEquipped and Player:BuffDown(S.FreezingWindsBuff) or EnemiesCount16ySplash >= 2)) then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power single 15"; end
    end
  end
  -- arcane_explosion,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down
  if S.ArcaneExplosion:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Arcane == 0) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion single 16 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion single 16"; end
    end
  end
  -- fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0) then
    if Cast(S.FireBlast) then return "fire_blast single 17"; end
  end
  -- glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 18"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 19"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 16"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Enemies Update
  Enemies16ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount6ySplash = Target:GetEnemiesInSplashRangeCount(6)
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  else
    EnemiesCount15yMelee = 1
    EnemiesCount6ySplash = 1
    EnemiesCount8ySplash = 1
    EnemiesCount16ySplash = 1
  end

  -- Check our IF status
  Mage.IFTracker()

  -- How long is left in the fight?
  fightRemains = HL.FightRemains(Enemies16ySplash, false)

  -- Check when the Disciplinary Command buff was last applied and its internal CD
  var_disciplinary_command_last_applied = S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  var_disciplinary_command_cd_remains = 30 - var_disciplinary_command_last_applied
  if var_disciplinary_command_cd_remains < 0 then var_disciplinary_command_cd_remains = 0 end

  -- Disciplinary Command Check
  Mage.DCCheck()

  -- call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=!runeforge.disciplinary_command|cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down
    if S.Counterspell:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Arcane == 0) then
      if Cast(S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, nil, not Target:IsSpellInRange(S.Counterspell)) then return "counterspell default"; end
    end
    -- call_action_list,name=cds
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if AoEON() and EnemiesCount16ySplash >= 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single,if=active_enemies<3
    if not AoEON() or EnemiesCount16ySplash < 3 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=movement
  end
end

local function Init()

end

HR.SetAPL(64, APL, Init)
