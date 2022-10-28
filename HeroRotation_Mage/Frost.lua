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
  I.ShadowedOrbofTorment:ID()
}

-- Rotation Var
local EnemiesCount6ySplash, EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local EnemiesCount15yMelee  --Enemies arround player
local Enemies16ySplash
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied
local BossFightRemains = 11111
local FightRemains = 11111

local SlickIceEquipped = Player:HasLegendaryEquipped(2)
local ColdFrontEquipped = Player:HasLegendaryEquipped(3)
local FreezingWindsEquipped = Player:HasLegendaryEquipped(4)
local GlacialFragmentsEquipped = Player:HasLegendaryEquipped(5)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
local GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
local TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
local DeathsFathomEquipped = Player:HasLegendaryEquipped(221)
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
  SlickIceEquipped = Player:HasLegendaryEquipped(2)
  ColdFrontEquipped = Player:HasLegendaryEquipped(3)
  FreezingWindsEquipped = Player:HasLegendaryEquipped(4)
  GlacialFragmentsEquipped = Player:HasLegendaryEquipped(5)
  DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
  GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
  TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
  DeathsFathomEquipped = Player:HasLegendaryEquipped(221)
  HeartoftheFaeEquipped = Player:HasLegendaryEquipped(260)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function FrozenRemains()
  return max(Target:DebuffRemains(S.Frostbite), Target:DebuffRemains(S.Freeze), Target:DebuffRemains(S.FrostNova))
end

local function CometStormRemains()
  local TravelDelay = 1
  local CSPulses = 7
  local CSPulseTime = 0.2
  local CSTime = TravelDelay + (CSPulseTime * CSPulses)
  return max(CSTime - S.CometStorm:TimeSinceLastCast(), 0)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellect, true) then
    if Cast(S.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- summon_water_elemental
  if S.SummonWaterElemental:IsCastable() then
    if Cast(S.SummonWaterElemental) then return "summon_water_elemental precombat 4"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft
    if S.Fleshcraft:IsCastable() then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 5"; end
    end
    -- Manually added : precast Tome of monstruous Constructions
    if I.TomeofMonstruousConstructions:IsEquippedAndReady() and Player:BuffDown(S.TomeofMonstruousConstructionsBuff) then
      if Cast(I.TomeofMonstruousConstructions, nil, Settings.Commons.DisplayStyle.Trinkets) then return "tome_of_monstruous_constructions precombat 6"; end
    end
    -- blizzard,if=active_enemies>=2
    -- TODO precombat active_enemies
    -- frostbolt,if=active_enemies=1
    if S.Frostbolt:IsCastable() and not Player:IsCasting(S.Frostbolt) then
      if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt precombat 10"; end
    end
  end
end

local function Cooldowns()
  -- use_item,name=shadowed_orb_of_torment,if=buff.rune_of_power.down
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment cd 2"; end
  end
  -- potion,if=prev_off_gcd.icy_veins|fight_remains<30
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (Player:PrevGCDP(1, S.IcyVeins) or FightRemains < 30) then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cd 4"; end
  end
  -- deathborne
  if S.Deathborne:IsCastable() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cd 6"; end
  end
  -- mirrors_of_torment,if=active_enemies<3&(conduit.siphoned_malice|soulbind.wasteland_propriety)&buff.brain_freeze.react=0
  if S.MirrorsofTorment:IsCastable() and (EnemiesCount8ySplash < 3 and (S.SiphonedMalice:ConduitEnabled() or S.WastelandPropriety:SoulbindEnabled()) and Player:BuffDown(S.BrainFreezeBuff)) then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment cd 8"; end
  end
  -- rune_of_power,if=cooldown.icy_veins.remains>12&buff.rune_of_power.down
  if S.RuneofPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 12 and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 10"; end
  end
  -- icy_veins,if=buff.rune_of_power.down&(buff.icy_veins.down|talent.rune_of_power)&(buff.slick_ice.down|conduit.icy_propulsion&(talent.comet_storm|set_bonus.tier28_2pc)|active_enemies>=2)
  if S.IcyVeins:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (Player:BuffDown(S.IcyVeins) or S.RuneofPower:IsAvailable()) and (Player:BuffDown(S.SlickIceBuff) or S.IcyPropulsion:ConduitEnabled() and (S.CometStorm:IsAvailable() or Player:HasTier(28, 2)) or EnemiesCount8ySplash >= 2)) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 12"; end
  end
  -- time_warp,if=runeforge.temporal_warp&buff.exhaustion.up&(prev_off_gcd.icy_veins|fight_remains<40)
  if S.TimeWarp:IsCastable() and Settings.Frost.UseTemporalWarp and (TemporalWarpEquipped and Player:BloodlustExhaustUp() and Player:BloodlustDown() and (Player:BuffUp(S.IcyVeins) or FightRemains < 40)) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 14"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name() .. " cd 16" end
    end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 18"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 20"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 22"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 24"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 26"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 28"; end
  end
end

local function Aoe()
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 2"; end
  end
  -- blizzard,if=buff.deathborne.down|!runeforge.deaths_fathom|buff.freezing_rain.up|active_enemies>=6
  if S.Blizzard:IsCastable() and (Player:BuffDown(S.Deathborne) or (not DeathsFathomEquipped) or Player:BuffUp(S.FreezingRainBuff) or EnemiesCount16ySplash >= 6) then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 4"; end
  end
  if S.Blizzard:IsCastable() and Player:BuffUp(S.Deathborne) then
    -- blizzard,if=buff.deathborne.up&active_enemies=5&(talent.freezing_rain|talent.bone_chilling|conduit.shivering_core|!runeforge.cold_front)
    if (EnemiesCount16ySplash == 5 and (S.FreezingRain:IsAvailable() or S.BoneChilling:IsAvailable() or S.ShiveringCore:ConduitEnabled() or not ColdFrontEquipped)) then
      if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 6"; end
    end
    -- blizzard,if=buff.deathborne.up&active_enemies=4&(talent.freezing_rain|talent.bone_chilling&conduit.shivering_core|!runeforge.cold_front&!runeforge.slick_ice)
    if (EnemiesCount16ySplash == 4 and (S.FreezingRain:IsAvailable() or S.BoneChilling:IsAvailable() and S.ShiveringCore:ConduitEnabled() or (not ColdFrontEquipped) and not SlickIceEquipped)) then
      if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 8"; end
    end
    -- blizzard,if=buff.deathborne.up&active_enemies<=3&!runeforge.slick_ice&!runeforge.cold_front&conduit.shivering_core&(talent.freezing_rain|talent.bone_chilling)
    if (EnemiesCount16ySplash <= 3 and (not SlickIceEquipped) and (not ColdFrontEquipped) and S.ShiveringCore:ConduitEnabled() and (S.FreezingRain:IsAvailable() or S.BoneChilling:IsAvailable())) then
      if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 10"; end
    end
  end
  -- flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&(buff.fingers_of_frost.react=0|runeforge.deaths_fathom&prev_gcd.1.frostbolt&(runeforge.cold_front|runeforge.slick_ice)&buff.deathborne.up))
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:BuffDownP(S.FingersofFrostBuff) or DeathsFathomEquipped and Player:PrevGCD(1, S.Frostbolt) and (ColdFrontEquipped or SlickIceEquipped) and Player:BuffUp(S.Deathborne)))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 12"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 14"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 16"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&buff.volatile_solvent_humanoid.down,interrupt_immediate=1,interrupt_global=1,interrupt_if=1
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft aoe 17"; end
  end
  -- frostbolt,if=runeforge.deaths_fathom&(runeforge.cold_front|runeforge.slick_ice)&buff.deathborne.remains>cast_time+travel_time
  if S.Frostbolt:IsCastable() and (DeathsFathomEquipped and (ColdFrontEquipped or SlickIceEquipped) and Player:BuffRemains(S.Deathborne) > S.Frostbolt:CastTime() + S.Frostbolt:TravelTime()) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 18"; end
  end
  -- frostbolt,if=remaining_winters_chill=1&comet_storm_remains>action.ice_lance.travel_time
  if S.Frostbolt:IsCastable() and (Target:DebuffStack(S.WintersChillDebuff) == 1 and CometStormRemains() > S.IceLance:TravelTime()) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 20"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and EnemiesCount8ySplash >= 2 and (Player:BuffUpP(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or Target:DebuffStack(S.WintersChillDebuff) > 1 and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 22"; end
  end
  -- radiant_spark,if=soulbind.combat_meditation
  if S.RadiantSpark:IsCastable() and (S.CombatMeditation:SoulbindEnabled()) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe 24"; end
  end
  if CDsON() then
    -- mirrors_of_torment
    if S.MirrorsofTorment:IsCastable() then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment aoe 26"; end
    end
    -- shifting_power
    if S.ShiftingPower:IsCastable() then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power aoe 28"; end
    end
  end
  -- fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0) then
    if Cast(S.FireBlast) then return "fire_blast aoe 30"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=6&!runeforge.glacial_fragments
  -- Note: Using 8y splash instead of 10y to account for distance from caster to the target after moving into range
  if S.ArcaneExplosion:IsCastable() and (Player:ManaPercentageP() > 30 and EnemiesCount8ySplash >= 6 and not GlacialFragmentsEquipped) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion aoe 32 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 32"; end
    end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 34"; end
  end
  -- ice_lance,if=runeforge.glacial_fragments&(talent.splitting_ice|active_enemies>=5)&travel_time<ground_aoe.blizzard.remains
  local BlizzardRemains = 7 - S.Blizzard:TimeSinceLastCast()
  if BlizzardRemains < 0 then BlizzardRemains = 0 end
  if S.IceLance:IsCastable() and (GlacialFragmentsEquipped and (S.SplittingIce:IsAvailable() or EnemiesCount8ySplash >= 5) and S.IceLance:TravelTime() < BlizzardRemains) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 36"; end
  end
  -- wait,sec=0.1,if=runeforge.glacial_fragments&!runeforge.deaths_fathom&(!talent.comet_storm&active_enemies>=5|active_enemies>=6)
  -- NYI wait
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 38"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 40"; end
  end
end

local function Single()
  -- flurry,if=(remaining_winters_chill=0|debuff.winters_chill.down)&(prev_gcd.1.ebonbolt|buff.brain_freeze.react&(prev_gcd.1.glacial_spike|prev_gcd.1.frostbolt&(!conduit.ire_of_the_ascended|cooldown.radiant_spark.remains|runeforge.freezing_winds)|prev_gcd.1.radiant_spark|buff.fingers_of_frost.react=0&(debuff.mirrors_of_torment.up|buff.freezing_winds.up|buff.expanded_potential.react)))
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Ebonbolt) or Player:BuffUp(S.BrainFreezeBuff) and (Player:IsCasting(S.GlacialSpike) or Player:IsCasting(S.Frostbolt) and (not S.IreOfTheAscended:ConduitEnabled() or S.RadiantSpark:CooldownRemains() > 0 or FreezingWindsEquipped) or Player:IsCasting(S.RadiantSpark) or Player:BuffDownP(S.FingersofFrostBuff) and (Target:DebuffUp(S.MirrorsofTorment) or Player:BuffUp(S.FreezingWindsBuff) or Player:BuffUp(S.ExpandedPotentialBuff))))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 2"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 4"; end
  end
  -- comet_storm,if=remaining_winters_chill
  if S.CometStorm:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff)) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 6"; end
  end
  -- ice_lance,if=talent.splitting_ice&talent.chain_reaction&buff.fingers_of_frost.react=buff.fingers_of_frost.max_stack
  if S.IceLance:IsCastable() and (S.SplittingIce:IsAvailable() and S.ChainReaction:IsAvailable() and Player:BuffStackP(S.FingersofFrostBuff) == 2) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 7"; end
  end
  -- frostbolt,if=runeforge.deaths_fathom&(runeforge.cold_front|runeforge.slick_ice)&buff.deathborne.remains>cast_time+travel_time&active_enemies>=2
  if S.Frostbolt:IsCastable() and (DeathsFathomEquipped and (ColdFrontEquipped or SlickIceEquipped) and Player:BuffRemains(S.Deathborne) > S.Frostbolt:CastTime() + S.Frostbolt:TravelTime() and EnemiesCount16ySplash >= 2) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 8"; end
  end
  -- blizzard,if=(!runeforge.slick_ice|!conduit.icy_propulsion&buff.deathborne.down)&active_enemies>=2
  if S.Blizzard:IsCastable() and (((not SlickIceEquipped) or (not S.IcyPropulsion:ConduitEnabled()) and Player:BuffDown(S.Deathborne)) and EnemiesCount16ySplash >= 2) then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 10"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1&debuff.winters_chill.remains
  if S.RayofFrost:IsCastable() and (Target:DebuffStack(S.WintersChillDebuff) == 1) then
    if Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 12"; end
  end
  -- glacial_spike,if=remaining_winters_chill&debuff.winters_chill.remains>cast_time+travel_time
  if S.GlacialSpike:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff) and Target:DebuffRemains(S.WintersChillDebuff) > S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime()) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 14"; end
  end
  -- frostbolt,if=remaining_winters_chill=1&comet_storm_remains>action.ice_lance.travel_time
  if S.Frostbolt:IsCastable() and (Target:DebuffStack(S.WintersChillDebuff) == 1 and CometStormRemains() > S.IceLance:TravelTime()) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 16"; end
  end
  -- ice_lance,if=remaining_winters_chill&remaining_winters_chill>buff.fingers_of_frost.react&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff) and Target:DebuffStack(S.WintersChillDebuff) > num(Player:BuffUpP(S.FingersofFrostBuff)) and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 18"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova single 20"; end
  end
  -- radiant_spark,if=buff.freezing_winds.up&active_enemies=1
  if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.FreezingWindsBuff) and EnemiesCount16ySplash == 1) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 22"; end
  end
  -- radiant_spark,if=buff.brain_freeze.react&talent.glacial_spike&conduit.ire_of_the_ascended&buff.icicles.stack>=4
  if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff)and S.GlacialSpike:IsAvailable() and S.IreOfTheAscended:ConduitEnabled() and Player:BuffStackP(S.IciclesBuff) >= 4) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 24"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time
  if S.IceLance:IsCastable() and (Player:BuffUpP(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 26"; end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 28"; end
  end
  -- radiant_spark,if=(!talent.glacial_spike|!conduit.ire_of_the_ascended)&(!runeforge.freezing_winds|active_enemies>=2)&buff.brain_freeze.react
  if S.RadiantSpark:IsCastable() and ((not S.GlacialSpike:IsAvailable() or not S.IreOfTheAscended:ConduitEnabled()) and (not FreezingWindsEquipped or EnemiesCount15yMelee >= 2) and Player:BuffUp(S.BrainFreezeBuff)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 30"; end
  end
  if CDsON() then
    -- mirrors_of_torment
    if S.MirrorsofTorment:IsCastable() then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment single 32"; end
    end
    -- shifting_power,if=buff.rune_of_power.down&(runeforge.heart_of_the_fae|soulbind.grove_invigoration|soulbind.field_of_blossoms|runeforge.freezing_winds&buff.freezing_winds.down|active_enemies>=2)
    if S.ShiftingPower:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and (HeartoftheFaeEquipped or S.GroveInvigoration:IsAvailable() or S.FieldOfBlossoms:IsAvailable() or FreezingWindsEquipped and Player:BuffDown(S.FreezingWindsBuff) or EnemiesCount16ySplash >= 2)) then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power single 34"; end
    end
  end
  -- arcane_explosion,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down
  if S.ArcaneExplosion:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Arcane == 0) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion single 36 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion single 36"; end
    end
  end
  -- fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0) then
    if Cast(S.FireBlast) then return "fire_blast single 38"; end
  end
  -- glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff)) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 40"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&buff.volatile_solvent_humanoid.down,interrupt_immediate=1,interrupt_global=1,interrupt_if=1
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft single 41"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt single 42"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 44"; end
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
  -- Note: Not referenced in the current APL, but saving for potential use later
  --Mage.IFTracker()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies16ySplash, false)
    end
  end

  -- Check when the Disciplinary Command buff was last applied and its internal CD
  var_disciplinary_command_last_applied = S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  var_disciplinary_command_cd_remains = 30 - var_disciplinary_command_last_applied
  if var_disciplinary_command_cd_remains < 0 then var_disciplinary_command_cd_remains = 0 end

  -- Disciplinary Command Check
  Mage.DCCheck()

  -- call precombat
  if not Player:AffectingCombat() then
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
  -- APL April 6, 2022 https://github.com/simulationcraft/simc/tree/1ba3249f3ecc4ca494c4bf95a2439980389a13b6
  HR.Print("Frost Mage rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(64, APL, Init)
