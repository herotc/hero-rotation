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
local EnemiesCount8ySplash, EnemiesCount16ySplash --Enemies arround target
local EnemiesCount15yMelee  --Enemies arround player
local Enemies16ySplash
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied
local var_snowstorm_max_stack = 30
local BossFightRemains = 11111
local FightRemains = 11111

local SlickIceEquipped = Player:HasLegendaryEquipped(2)
local ColdFrontEquipped = Player:HasLegendaryEquipped(3)
local FreezingWindsEquipped = Player:HasLegendaryEquipped(4)
local GlacialFragmentsEquipped = Player:HasLegendaryEquipped(5)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
local DeathsFathomEquipped = Player:HasLegendaryEquipped(221)

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
  DeathsFathomEquipped = Player:HasLegendaryEquipped(221)
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
  -- time_warp,if=buff.exhaustion.up&buff.bloodlust.down
  if S.TimeWarp:IsCastable() and Settings.Frost.UseTemporalWarp and Player:BloodlustExhaustUp() and Player:BloodlustDown() then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp cd 2"; end
  end
  -- potion
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cd 4"; end
  end
  -- deathborne
  if S.Deathborne:IsCastable() then
    if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne cd 6"; end
  end
  -- mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment cd 8"; end
  end
  -- icy_veins,if=buff.rune_of_power.down
  if S.IcyVeins:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.IcyVeins, Settings.Frost.GCDasOffGCD.IcyVeins) then return "icy_veins cd 10"; end
  end
  -- rune_of_power,if=buff.rune_of_power.down&cooldown.icy_veins.remains>10
  if S.RuneofPower:IsCastable() and (S.IcyVeins:CooldownRemains() > 10 and Player:BuffDown(S.RuneofPowerBuff)) then
    if Cast(S.RuneofPower, Settings.Frost.GCDasOffGCD.RuneOfPower) then return "rune_of_power cd 12"; end
  end
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name() .. " cd 14" end
    end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 16"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 18"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 20"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 22"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 24"; end
  end
end

local function Aoe()
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb aoe 2"; end
  end
  -- blizzard
  if S.Blizzard:IsCastable() then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard aoe 4"; end
  end
  -- frost_nova,if=prev_gcd.1.comet_storm
  if S.FrostNova:IsCastable() and Player:PrevGCD(1, S.CometStorm) then
    if Cast(S.FrostNova, nil, nil, not Target:IsInRange(12)) then return "frost_nova aoe 6"; end
  end
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.ebonbolt|prev_gcd.1.glacial_spike)
  if S.Flurry:IsCastable() and (Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Frostbolt) or Player:IsCasting(S.Ebonbolt) or Player:IsCasting(S.GlacialSpike))) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry aoe 8"; end
  end
  -- ice_nova
  if S.IceNova:IsCastable() then
    if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova aoe 10"; end
  end
  -- freeze,if=!talent.snowstorm|buff.snowstorm.stack=buff.snowstorm.max_stack&cooldown.cone_of_cold.ready
  if S.Freeze:IsPetKnown() and S.Freeze:CooldownUp() and (not S.SnowStorm:IsAvailable() or (Player:BuffStackP(S.SnowStormBuff) == var_snowstorm_max_stack and S.ConeofCold:CooldownRemains() == 0)) then
    if Cast(S.Freeze, nil, nil, not Target:IsInRange(40)) then return "freeze aoe 10"; end
  end
  -- cone_of_cold,if=buff.snowstorm.stack=buff.snowstorm.max_stack
  if S.ConeofCold:IsCastable() and Player:BuffStackP(S.SnowStormBuff) == var_snowstorm_max_stack then
    if Cast(S.ConeofCold, nil, nil, not Target:IsInRange(10)) then return "cone_of_cold aoe 12"; end
  end
  -- comet_storm
  if S.CometStorm:IsCastable() then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm aoe 14"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&buff.volatile_solvent_humanoid.down,interrupt_immediate=1,interrupt_global=1,interrupt_if=1
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft aoe 16"; end
  end
  -- frostbolt,if=runeforge.deaths_fathom&(runeforge.cold_front|runeforge.slick_ice)&buff.deathborne.remains>cast_time+travel_time
  if S.Frostbolt:IsCastable() and (DeathsFathomEquipped and (ColdFrontEquipped or SlickIceEquipped) and Player:BuffRemains(S.Deathborne) > S.Frostbolt:CastTime() + S.Frostbolt:TravelTime()) then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 18"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react|debuff.frozen.remains>travel_time|remaining_winters_chill&debuff.winters_chill.remains>travel_time
  if S.IceLance:IsCastable() and EnemiesCount8ySplash >= 2 and (Player:BuffUpP(S.FingersofFrostBuff) or FrozenRemains() > S.IceLance:TravelTime() or Target:DebuffStack(S.WintersChillDebuff) > 1 and Target:DebuffRemains(S.WintersChillDebuff) > S.IceLance:TravelTime()) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 20"; end
  end
  -- radiant_spark,if=soulbind.combat_meditation
  if S.RadiantSpark:IsCastable() and (S.CombatMeditation:SoulbindEnabled()) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe 22"; end
  end
  if CDsON() then
    -- mirrors_of_torment
    if S.MirrorsofTorment:IsCastable() then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.MirrorsofTorment)) then return "mirrors_of_torment aoe 24"; end
    end
    -- shifting_power
    if S.ShiftingPower:IsCastable() then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power aoe 26"; end
    end
  end
  -- fire_blast,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_fire.down
  if S.FireBlast:IsCastable() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Fire == 0) then
    if Cast(S.FireBlast) then return "fire_blast aoe 28"; end
  end
  -- arcane_explosion,if=mana.pct>30&active_enemies>=6&!runeforge.glacial_fragments
  -- Note: Using 8y splash instead of 10y to account for distance from caster to the target after moving into range
  if S.ArcaneExplosion:IsCastable() and (Player:ManaPercentageP() > 30 and EnemiesCount8ySplash >= 6 and not GlacialFragmentsEquipped) then
    if Settings.Frost.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion aoe 30 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion aoe 30"; end
    end
  end
  -- ebonbolt
  if S.Ebonbolt:IsCastable() and (EnemiesCount8ySplash >= 2) then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt aoe 32"; end
  end
  -- frostbolt
  if S.Frostbolt:IsCastable() then
    if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt aoe 34"; end
  end
  -- Manually added: ice_lance as a fallthrough when MovingRotation is true
  if S.IceLance:IsCastable() then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance aoe 36"; end
  end
end

local function Single()
  -- flurry,if=cooldown_react&remaining_winters_chill=0&debuff.winters_chill.down&(prev_gcd.1.frostbolt|prev_gcd.1.ebonbolt|prev_gcd.1.glacial_spike|prev_gcd.1.radiant_spark)
  if S.Flurry:IsCastable() and Target:DebuffDown(S.WintersChillDebuff) and (Player:IsCasting(S.Ebonbolt) or Player:IsCasting(S.GlacialSpike) or Player:IsCasting(S.Frostbolt) or Player:IsCasting(S.RadiantSpark)) then
    if Cast(S.Flurry, nil, nil, not Target:IsSpellInRange(S.Flurry)) then return "flurry single 2"; end
  end
  -- water_jet,if=cooldown.flurry.charges_fractional<1
  if S.WaterJet:IsPetKnown() and S.WaterJet:CooldownUp() and S.Flurry:Charges() < 1 then
    if Cast(S.WaterJet) then return "water_jet single 4"; end
  end
  -- meteor,if=prev_gcd.1.flurry
  if S.Meteor:IsCastable() and Player:PrevGCD(1, S.Flurry) then
    if Cast(S.Meteor, nil, nil, not Target:IsSpellInRange(S.Meteor)) then return "meteor single 6"; end
  end
  -- comet_storm,if=prev_gcd.1.flurry
  if S.CometStorm:IsCastable() and Player:PrevGCD(1, S.Flurry) then
    if Cast(S.CometStorm, nil, nil, not Target:IsSpellInRange(S.CometStorm)) then return "comet_storm single 8"; end
  end
  -- frozen_orb
  if S.FrozenOrb:IsCastable() then
    if Cast(S.FrozenOrb, Settings.Frost.GCDasOffGCD.FrozenOrb, nil, not Target:IsInRange(40)) then return "frozen_orb single 10"; end
  end
  -- blizzard,if=active_enemies>=2&talent.ice_caller&talent.freezing_rain
  if S.Blizzard:IsCastable() and EnemiesCount16ySplash >= 2 and S.IceCaller:IsAvailable() and S.FreezingRain:IsAvailable() then
    if Cast(S.Blizzard, nil, nil, not Target:IsInRange(40)) then return "blizzard single 12"; end
  end
  -- shifting_power,if=buff.rune_of_power.down
  if S.ShiftingPower:IsCastable() and Player:BuffDown(S.RuneofPowerBuff) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power single 14"; end
  end
  -- glacial_spike,if=remaining_winters_chill
  if S.GlacialSpike:IsCastable() and (Target:DebuffUp(S.WintersChillDebuff) and Target:DebuffRemains(S.WintersChillDebuff) > S.GlacialSpike:CastTime() + S.GlacialSpike:TravelTime()) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 16"; end
  end
  -- ray_of_frost,if=remaining_winters_chill=1&debuff.winters_chill.remains
  if S.RayofFrost:IsCastable() and (Target:DebuffStack(S.WintersChillDebuff) == 1) then
    if Cast(S.RayofFrost, nil, nil, not Target:IsSpellInRange(S.RayofFrost)) then return "ray_of_frost single 18"; end
  end
  -- radiant_spark,if=buff.freezing_winds.up&active_enemies=1
  if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.FreezingWindsBuff) and EnemiesCount16ySplash == 1) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 20"; end
  end
  -- radiant_spark,if=action.flurry.cooldown_react&talent.glacial_spike&conduit.ire_of_the_ascended&buff.icicles.stack>=4
  if S.RadiantSpark:IsCastable() and (Player:BuffUp(S.BrainFreezeBuff) and S.GlacialSpike:IsAvailable() and S.IreOfTheAscended:ConduitEnabled() and Player:BuffStackP(S.IciclesBuff) >= 4) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 22"; end
  end
  -- ice_lance,if=buff.fingers_of_frost.react&!prev_gcd.1.glacial_spike|remaining_winters_chill
  if S.IceLance:IsCastable() and (Player:BuffUpP(S.FingersofFrostBuff) and not Player:IsCasting(S.GlacialSpike) or Target:DebuffUp(S.WintersChillDebuff)) then
    if Cast(S.IceLance, nil, nil, not Target:IsSpellInRange(S.IceLance)) then return "ice_lance single 24"; end
  end
  -- radiant_spark,if=(!talent.glacial_spike|!conduit.ire_of_the_ascended)&(!runeforge.freezing_winds|active_enemies>=2)&action.flurry.cooldown_react
  if S.RadiantSpark:IsCastable() and ((not S.GlacialSpike:IsAvailable() or not S.IreOfTheAscended:ConduitEnabled()) and (not FreezingWindsEquipped or EnemiesCount15yMelee >= 2) and Player:BuffUp(S.BrainFreezeBuff)) then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark single 30"; end
  end
  -- mirrors_of_torment
  if S.MirrorsofTorment:IsCastable() then
    if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment single 32"; end
  end
  -- glacial_spike,if=buff.brain_freeze.react
  if S.GlacialSpike:IsCastable() and Player:BuffUp(S.BrainFreezeBuff) then
    if Cast(S.GlacialSpike, nil, nil, not Target:IsSpellInRange(S.GlacialSpike)) then return "glacial_spike single 34"; end
  end
  -- ebonbolt,if=cooldown.flurry.charges_fractional<1
  if S.Ebonbolt:IsCastable() and S.Flurry:Charges() < 1 then
    if Cast(S.Ebonbolt, nil, nil, not Target:IsSpellInRange(S.Ebonbolt)) then return "ebonbolt single 36"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&buff.volatile_solvent_humanoid.down,interrupt_immediate=1,interrupt_global=1,interrupt_if=1
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VolatileSolventHumanBuff)) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft single 38"; end
  end
  if CDsON() then
    -- bag_of_tricks
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 40"; end
    end
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
  Enemies16ySplash = Target:GetEnemiesInSplashRange(16)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  else
    EnemiesCount15yMelee = 1
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
  HR.Print("Frost Mage rotation is currently a work in progress, but has been updated for patch 10.0.0.")
end

HR.SetAPL(64, APL, Init)
