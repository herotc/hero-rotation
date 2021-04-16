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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

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
local ShouldReturn -- Used to get the return string
local EnemiesCount6ySplash, EnemiesCount8ySplash, EnemiesCount16ySplash, EnemiesCount30ySplash --Enemies arround target
local EnemiesCount10yMelee, EnemiesCount12yMelee, EnemiesCount15yMelee, EnemiesCount18yMelee  --Enemies arround player
local Mage = HR.Commons.Mage
local TemporalWarpEquipped = HL.LegendaryEnabled(9)
local GrislyIcicleEquipped = HL.LegendaryEnabled(8)
local FreezingWindsEquipped = HL.LegendaryEnabled(4)
local GlacialFragmentsEquipped = HL.LegendaryEnabled(5)
local DisciplinaryCommandEquipped = HL.LegendaryEnabled(7)

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
  TemporalWarpEquipped = HL.LegendaryEnabled(9)
  GrislyIcicleEquipped = HL.LegendaryEnabled(8)
  FreezingWindsEquipped = HL.LegendaryEnabled(4)
  GlacialFragmentsEquipped = HL.LegendaryEnabled(5)
  DisciplinaryCommandEquipped = HL.LegendaryEnabled(7)
end, "PLAYER_EQUIPMENT_CHANGED")

local function Precombat ()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 1"; end
  end
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if HR.Cast(S.SummonWaterElemental) then return "summon_water_elemental precombat 2"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- mirror_image
    if S.MirrorImage:IsCastable() and HR.CDsON() and Settings.Frost.MirrorImagesBeforePull then
      if HR.Cast(S.MirrorImage, Settings.Frost.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 3"; end
    end
    -- potion
    --[[ if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion precombat 4"; end
    end ]]
    -- frostbolt
    if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
      if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 5"; end
    end
    -- frozen_orb
    if S.FrozenOrb:IsCastable() then
      if HR.Cast(S.FrozenOrb, nil, nil, not Target:IsInRange(40)) then return "frozen_orb precombat 6"; end
    end
  end
end

local function Cooldowns ()
  --potion,if=prev_off_gcd.icy_veins|fight_remains<30
  -- TODO : potion
  --[[ if I.PotionofFocusedResolve:IsReady() and Settings.Commons.UsePotions and (Player:PrevGCDP(1, S.IcyVeins) or Target:TimeToDie() < 30) then
    if HR.CastSuggested(I.PotionofFocusedResolve) then return "potion cd 1"; end
  end ]]
  --deathborne
  if S.Deathborne:IsCastable() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.CovenantDisplayStyle) then return "deathborne cd 2"; end
  end
  --mirrors_of_torment,if=active_enemies<3&(conduit.siphoned_malice.enabled|soulbind.wasteland_propriety.enabled)
  if S.MirrorsofTorment:IsCastable() and EnemiesCount8ySplash < 3 and (S.WastelandPropriety:IsAvailable() or S.SiphonedMalice:IsAvailable()) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment cd 3"; end
  end
  --rune_of_power,if=cooldown.icy_veins.remains>12&buff.rune_of_power.down
  if S.RuneofPower:IsCastable() and not Player:IsCasting(S.RuneofPower) and Player:BuffDown(S.RuneofPowerBuff) and (S.IcyVeins:CooldownRemains() > S.RuneofPower:BaseDuration() or Target:TimeToDie() < S.RuneofPower:BaseDuration() + S.RuneofPower:CastTime() + Player:GCD()) then
    if HR.Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 4"; end
  end
  --icy_veins,if=buff.rune_of_power.down
  if S.IcyVeins:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if HR.Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 5"; end
  end
  --time_warp,if=runeforge.temporal_warp.equipped&buff.exhaustion.up&(prev_off_gcd.icy_veins|fight_remains<30)
  if S.TimeWarp:IsCastable() and Settings.Frost.UseTemporalWarp and TemporalWarpEquipped and Player:BloodlustExhaustUp() and Player:BloodlustDown() and (Player:BuffUp(S.IcyVeins) or Target:TimeToDie() < 30) then
    if HR.Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 6"; end
  end
  --use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse and Settings.Commons.UseTrinkets then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name() .. " cd 7" end
  end
  --blood_fury
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 8"; end
  end
  --berserking
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 9"; end
  end
  --lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 10"; end
  end
  --fireblood
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 11"; end
  end
  --ancestral_call
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 12"; end
  end
  --bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 13"; end
  end
end

local function Aoe ()
  --frozen_orb
  if S.FrozenOrb:IsCastable() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsSpellInRange(S.FrozenOrb)) then return "frozen_orb aoe 1"; end
  end
  --blizzard
  if S.Blizzard:IsCastable() then
    if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 2"; end
  end
  --flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&buff.fingers_of_frost.react=0)
  if S.Flurry:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 0 and (Player:IsCasting(S.Ebonbolt) or (Player:BuffUp(S.BrainFreezeBuff) and Player:BuffStack(S.FingersofFrostBuff) == 0)) then
    if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 3"; end
  end
  --ice_nova
  if S.IceNova:IsCastable() and EnemiesCount8ySplash >= 5 then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 4"; end
  end
  --comet_storm
  if S.CometStorm:IsCastable() and EnemiesCount6ySplash >= 5 then
    if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 5"; end
  end
  --ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and EnemiesCount8ySplash >= 2 and (Player:BuffStack(S.FingersofFrostBuff) > 0 or Target:DebuffRemains(S.Frostbite) > S.IceLance:TravelTime() or (Target:DebuffStack(S.WintersChillDebuff) > 1 and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime())) then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 6"; end
  end
  --radiant_spark
  if HR.CDsON() and S.RadiantSpark:IsCastable() then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe 7"; end
  end
  --mirrors_of_torment
  if HR.CDsON() and S.MirrorsofTorment:IsCastable() and (not Player:IsCasting(S.MirrorsofTorment)) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment aoe 8"; end
  end
  --shifting_power
  if HR.CDsON() and S.ShiftingPower:IsCastable() then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.ShiftingPower)) then return "shifting_power aoe 9"; end
  end
  --frost_nova,if=runeforge.grisly_icicle.equipped&target.level<=level&debuff.frozen.down
  -- NYI frozen
  if S.FrostNova:IsCastable() and Target:IsSpellInRange(S.FrostNova) and GrislyIcicleEquipped and Target:Level() <= Player:Level() then
    if HR.Cast(S.FrostNova) then return "frost_nova aoe 10"; end
  end
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and S.DisciplinaryCommandArcaneBuff:TimeSinceLastAppliedOnPlayer() > 30 and S.DisciplinaryCommandFireBuff:TimeSinceLastAppliedOnPlayer() > 30 and Player:BuffDown(S.DisciplinaryCommandFireBuff) then
    if HR.Cast(S.FireBlast) then return "fire_blast aoe 11"; end
  end
  --arcane_explosion,if=mana.pct>30&active_enemies>=6
  --TODO : change to splash + stay distance option
  if S.ArcaneExplosion:IsCastable() and Target:IsInRange(10) and Player:ManaPercentageP() > 30 and EnemiesCount10yMelee >= 6 then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 12"; end
  end
  --ebonbolt
  if S.Ebonbolt:IsCastable() and EnemiesCount8ySplash >= 2 then
    if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 13"; end
  end
  --ice_lance,if=runeforge.glacial_fragments.equipped&talent.splitting_ice.enabled&travel_time<ground_aoe.blizzard.remains
  --NYI blizzard.remains
  if S.IceLance:IsCastable() and GlacialFragmentsEquipped and S.SplittingIce:IsAvailable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 14"; end
  end
  --wait,sec=0.1,if=runeforge.glacial_fragments.equipped&talent.splitting_ice.enabled
  --NYI wait
  --frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 15"; end
  end
  --ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 16"; end
  end
end

local function Single ()
  --flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)
  --&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!conduit.ire_of_the_ascended|cooldown.radiant_spark.remains|runeforge.freezing_winds)
  --|prev_gcd.1.radiant_spark|buff.fingers_of_frost.react=0&(debuff.mirrors_of_torment.up|buff.freezing_winds.up|buff.expanded_potential.react)))
  if S.Flurry:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 0 
  and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:IsCasting(S.GlacialSpike) or (Player:IsCasting(S.Frostbolt) and (not S.IreOfTheAscended:IsAvailable() or S.RadiantSpark:CooldownRemains() == 0 or FreezingWindsEquipped)) 
  or Player:IsCasting(S.RadiantSpark) or (Player:BuffStack(S.FingersofFrostBuff) == 0 and (Target:DebuffStack(S.MirrorsofTorment) > 0 or Player:BuffUp(S.FreezingWindsBuff) or Player:BuffUp(S.ExpandedPotentialBuff))))) then
    if HR.Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 1"; end
  end
  --frozen_orb
  if S.FrozenOrb:IsCastable() then
    if HR.Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 2"; end
  end
  --blizzard,if=buff.freezing_rain.up|active_enemies>=2
  if S.Blizzard:IsCastable() and (Player:BuffUp(S.FreezingRain) or EnemiesCount16ySplash >= 2) then
    if HR.Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 3"; end
  end
  --ray_of_frost,if=remaining_winters_chill=1&debuff.winters_chill.remains
  if S.RayofFrost:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) == 1 then
    if HR.Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 4"; end
  end
  --glacial_spike,if=remaining_winters_chill&debuff.winters_chill.remains>cast_time+travel_time
  if S.GlacialSpike:IsCastable() and not Player:IsCasting(S.GlacialSpike) and Target:DebuffStack(S.WintersChillDebuff) > 0 and Target:DebuffRemains(S.WintersChillDebuff) > S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime() then
    if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 5"; end
  end
  --ice_lance,if=remaining_winters_chill&remaining_winters_chill>buff.fingers_of_frost.react&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and Target:DebuffStack(S.WintersChillDebuff) > 0 and Target:DebuffStack(S.WintersChillDebuff) > Player:BuffStack(S.FingersofFrostBuff) and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 6"; end
  end
  --comet_storm
  if S.CometStorm:IsCastable() then
    if HR.Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 7"; end
  end
  --ice_nova
  if S.IceNova:IsCastable() then
    if HR.Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 8"; end
  end
  --radiant_spark,if=buff.freezing_winds.up&active_enemies=1
  if HR.CDsON() and S.RadiantSpark:IsCastable() and Player:BuffUp(S.FreezingWindsBuff) and EnemiesCount16ySplash == 1 then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 9"; end
  end
  --ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time
  if S.IceLance:IsCastable() and (Player:BuffStack(S.FingersofFrostBuff) > 0 or Target:DebuffRemains(S.Freeze) > S.IceLance:TravelTime()) then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 10"; end
  end
  --ebonbolt
  if S.Ebonbolt:IsCastable() then
    if HR.Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 11"; end
  end
  --radiant_spark,if=(!runeforge.freezing_winds.equipped|active_enemies>=2)&buff.brain_freeze.react
  if HR.CDsON() and S.RadiantSpark:IsCastable() and (not FreezingWindsEquipped or EnemiesCount15yMelee >= 2) and Player:BuffUp(S.BrainFreezeBuff) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 12"; end
  end
  --mirrors_of_torment
  if HR.CDsON() and S.MirrorsofTorment:IsCastable() and (not Player:IsCasting(S.MirrorsofTorment)) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.CovenantDisplayStyle) then return "mirrors_of_torment single 13"; end
  end
  --shifting_power,if=buff.rune_of_power.down&(soulbind.grove_invigoration.enabled|soulbind.field_of_blossoms.enabled|active_enemies>=2)
  if HR.CDsON() and S.ShiftingPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) and (S.GroveInvigoration:IsAvailable() or S.FieldOfBlossoms:IsAvailable() or EnemiesCount8ySplash >= 2)then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.CovenantDisplayStyle) then return "shifting_power single 14"; end
  end
  --frost_nova,if=runeforge.grisly_icicle.equipped&target.level<=level&debuff.frozen.down
  -- NYI frozen
  if S.FrostNova:IsCastable() and Target:IsSpellInRange(S.FrostNova) and GrislyIcicleEquipped and Target:Level() <= Player:Level() then
    if HR.Cast(S.FrostNova) then return "frost_nova single 15"; end
  end
  --arcane_explosion,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down
  if S.ArcaneExplosion:IsCastable() and Target:IsInRange(10) and DisciplinaryCommandEquipped and S.DisciplinaryCommandArcaneBuff:TimeSinceLastAppliedOnPlayer() > 30 and S.DisciplinaryCommandFireBuff:TimeSinceLastAppliedOnPlayer() > 30 and Player:BuffDown(S.DisciplinaryCommandArcaneBuff) then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion single 16"; end
  end
  --fire_blast,if=runeforge.disciplinary_command.equipped&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and DisciplinaryCommandEquipped and S.DisciplinaryCommandArcaneBuff:TimeSinceLastAppliedOnPlayer() > 30 and S.DisciplinaryCommandFireBuff:TimeSinceLastAppliedOnPlayer() > 30 and Player:BuffDown(S.DisciplinaryCommandFireBuff) then
    if HR.Cast(S.FireBlast) then return "fire_blast single 17"; end
  end
  --glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and not Player:IsCasting(S.GlacialSpike) and Player:BuffUp(S.BrainFreezeBuff) then
    if HR.Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 18"; end
  end
  --frostbolt
  if S.Frostbolt:IsCastable() then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 19"; end
  end
  --ice_lance
  if S.IceLance:IsCastable() then
    if HR.Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 20"; end
  end
end

--- ======= ACTION LISTS =======
local function APL ()
  EnemiesCount6ySplash = Target:GetEnemiesInSplashRangeCount(6)
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  EnemiesCount30ySplash = Target:GetEnemiesInSplashRangeCount(30)
  Enemies10yMelee = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yMelee = #Enemies10yMelee
  Enemies12yMelee = Player:GetEnemiesInMeleeRange(12)
  EnemiesCount12yMelee = #Enemies12yMelee
  Enemies15yMelee = Player:GetEnemiesInMeleeRange(15)
  EnemiesCount15yMelee = #Enemies15yMelee
  Enemies18yMelee = Player:GetEnemiesInMeleeRange(18)
  EnemiesCount18yMelee = #Enemies18yMelee
  Mage.IFTracker()

  --call precombat
  if not Player:AffectingCombat() and (not Player:IsCasting() or Player:IsCasting(S.WaterElemental)) then
    ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    --counterspell
    ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    --call_action_list,name=cds
    if HR.CDsON() then
      ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=aoe,if=active_enemies>=4
    if HR.AoEON() and EnemiesCount16ySplash >= 4 then
      ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --call_action_list,name=single,if=active_enemies<4
    if not HR.AoEON() or EnemiesCount16ySplash < 4 then
      ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init ()

end

HR.SetAPL(64, APL, Init)
