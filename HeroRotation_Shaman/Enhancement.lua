--- Localize Vars
-- Addon
local addonName, addonTable = ...;

-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;

-- HeroRotation
local HR = HeroRotation;

-- APL from T22_Shaman_Enhancement on 2018-08-19 13:50 PDT
-- https://github.com/simulationcraft/simc/blob/143242249d1c65a36194fe0f60f86974c754bb22/profiles/Tier22/T22_Shaman_Enhancement.simc

-- APL Local Vars
-- Spells
if not Spell.Shaman then Spell.Shaman = {}; end
Spell.Shaman.Enhancement = {
  -- Racials
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  Fireblood             = Spell(265221),
  AncestralCall         = Spell(274738),

  -- Abilities
  CrashLightning        = Spell(187874),
  CrashLightningBuff    = Spell(187878), -- CrashLightning buff for hitting 2 or more targets
  Flametongue           = Spell(193796),
  FlametongueBuff       = Spell(194084),
  Frostbrand            = Spell(196834),
  FrostbrandBuff        = Spell(196834),
  StormStrike           = Spell(17364),
  StormbringerBuff      = Spell(201846),
  EarthElemental        = Spell(198103),
  GatheringStormsBuff   = Spell(198300),

  FeralSpirit           = Spell(51533),
  LavaLash              = Spell(60103),
  LightningBolt         = Spell(187837),
  Rockbiter             = Spell(193786),
  WindStrike            = Spell(115356),
  HealingSurge          = Spell(188070),

  -- Talents
  HotHand               = Spell(201900),
  HotHandBuff           = Spell(215785),
  Landslide             = Spell(197992),
  LandslideBuff         = Spell(202004),
  Hailstorm             = Spell(210853),
  Overcharge            = Spell(210727),
  CrashingStorm         = Spell(192246),
  FuryOfAir             = Spell(197211),
  FuryOfAirBuff         = Spell(197211),
  Sundering             = Spell(197214),
  Ascendance            = Spell(114051),
  AscendanceBuff        = Spell(114051),
  EarthenSpike          = Spell(188089),
  EarthenSpikeDebuff    = Spell(188089),
  ForcefulWinds         = Spell(262647),
  SearingAssault        = Spell(192087),
  LightningShield       = Spell(192106),
  LightningShieldBuff   = Spell(192106),
  ElementalSpirits      = Spell(262624),

  TotemMastery          = Spell(262395),
  ResonanceTotemBuff    = Spell(262417),
  StormTotemBuff        = Spell(262397),
  EmberTotemBuff        = Spell(262399),
  TailwindTotemBuff     = Spell(262400),

  -- Azerite Traits
  LightningConduit       = Spell(275388),
  LightningConduitDebuff = Spell(275391),

  -- Utility
  WindShear             = Spell(57994),

  -- Legion Trinkets
  SpecterOfBetrayal     = Spell(246461),
  HornOfValor           = Spell(215956),

  -- Item Buffs
  BSARBuff              = Spell(270058),
  DFRBuff               = Spell(224001),

  -- Misc
  PoolFocus             = Spell(9999000010),
}
local S = Spell.Shaman.Enhancement;
local Everyone = HR.Commons.Everyone;

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Enhancement = {
  -- Legion Legendaries
  SmolderingHeart           = Item(151819, {10}),
  AkainusAbsoluteJustice    = Item(137084, {9}),

  -- Legion Trinkets
  SpecterOfBetrayal         = Item(151190, {13, 14}),
  HornOfValor				= Item(133642, {13, 14}),

  -- BfA Consumables
  Healthstone               = Item(5512),

  BPoA                      = Item(163223),  -- Battle Potion of Agility
  CHP                       = Item(152494),  -- Coastal Healing Potion
  BSAR                      = Item(160053),  -- Battle-Scarred Augment Rune

  -- Legion Consumables
  DAR                       = Item(140587),  -- Defiled Augment Rune
  PoPP                      = Item(142117),  -- Potion of Prolonged Power
}
local I = Item.Shaman.Enhancement;

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Shaman = HR.GUISettings.APL.Shaman,
}

--- APL Variables
-- actions+=/variable,name=furyCheck45,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>45))
local function furyCheck45()
  return (not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 45))
end

-- actions+=/variable,name=furyCheck35,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>35))
local function furyCheck35()
  return (not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 35))
end

-- actions+=/variable,name=furyCheck25,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>25))
local function furyCheck25()
  return (not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 25))
end


-- actions+=/variable,name=OCPool80,value=(!talent.overcharge.enabled|active_enemies>1|(talent.overcharge.enabled&active_enemies=1&(cooldown.lightning_bolt.remains>=2*gcd|maelstrom>80)))
local function OCPool80()
  return (not S.Overcharge:IsAvailable() or Cache.EnemiesCount[10] > 1 or (S.Overcharge:IsAvailable() and Cache.EnemiesCount[10] > 1 and (S.LightningBolt:CooldownRemainsP() >= 2 * Player:GCD() or Player:Maelstrom() > 80)))
end

-- actions+=/variable,name=OCPool70,value=(!talent.overcharge.enabled|active_enemies>1|(talent.overcharge.enabled&active_enemies=1&(cooldown.lightning_bolt.remains>=2*gcd|maelstrom>70)))
local function OCPool70()
  return (not S.Overcharge:IsAvailable() or Cache.EnemiesCount[10] > 1 or (S.Overcharge:IsAvailable() and Cache.EnemiesCount[10] > 1 and (S.LightningBolt:CooldownRemainsP() >= 2 * Player:GCD() or Player:Maelstrom() > 70)))
end

-- actions+=/variable,name=OCPool60,value=(!talent.overcharge.enabled|active_enemies>1|(talent.overcharge.enabled&active_enemies=1&(cooldown.lightning_bolt.remains>=2*gcd|maelstrom>60)))
local function OCPool60()
  return (not S.Overcharge:IsAvailable() or Cache.EnemiesCount[10] > 1 or (S.Overcharge:IsAvailable() and Cache.EnemiesCount[10] > 1 and (S.LightningBolt:CooldownRemainsP() >= 2 * Player:GCD() or Player:Maelstrom() > 60)))
end

-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(40);      -- LightningBolt, HealingSurge
  HL.GetEnemies(30);      -- WindShear
  HL.GetEnemies(10);      -- EarthenSpike
  HL.GetEnemies("Melee"); -- Melee
  Everyone.AoEToggleEnemiesUpdate()

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener
    -- actions+=/call_action_list,name=opener
    if Everyone.TargetIsValid() then
      -- actions.opener=rockbiter,if=maelstrom<15&time<gcd
      if S.Rockbiter:IsCastableP(20) and Player:Maelstrom() < 15 then
        if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
      end
    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupt
    if S.WindShear:IsCastableP(30) and Player:Maelstrom() >= S.WindStrike:Cost() and Target:IsInterruptible() and Settings.General.InterruptEnabled then
      if HR.Cast(S.WindShear, Settings.Shaman.Commons.OffGCDasOffGCD.WindShear) then return "Cast WindShear" end
    end

    -- Use healthstone or health potion if we have it and our health is low.
    if Settings.Shaman.Commons.ShowHSHP and (Player:HealthPercentage() <= Settings.Shaman.Commons.HealingHPThreshold) then
      if I.Healthstone:IsReady() then
        if HR.CastSuggested(I.Healthstone) then return "Use Healthstone" end
      elseif I.CHP:IsReady() then
        if HR.CastSuggested(I.CHP) then return "Use CHP" end
      end
    end

    -- Healing surge when we have less than the set health threshold!
    if S.HealingSurge:IsReady() and Settings.Shaman.Commons.HealingSurgeEnabled and Player:HealthPercentage() <= Settings.Shaman.Commons.HealingHPThreshold then
      -- Instant casts using maelstrom only.
      if Player:Maelstrom() >= 20 then
        if HR.Cast(S.HealingSurge) then return "Cast HealingSurge" end
      end
    end

    -- Potions
    -- Potion of Prolonged Power, then Battle Potion of Agility
    if Settings.Shaman.Commons.ShowPotions and Target:MaxHealth() >= (Settings.Shaman.Commons.ConsumableMinHPThreshHold * 1000) and ((Player:Buff(S.AscendanceBuff)) or Target:TimeToDie() <= 60 or Player:HasHeroism()) then
      if I.PoPP:IsReady() then
        if HR.CastSuggested(I.PoPP) then return "Use PoPP" end
      elseif I.BPoA:IsReady() then
        if HR.CastSuggested(I.BPoA) then return "Use BPoA" end
      end
    end

    -- Runes
    -- Defiled Augment Rune, then Battle-Scarred Augment Rune
    if Settings.Shaman.Commons.ShowRunes and Target:MaxHealth() >= (Settings.Shaman.Commons.ConsumableMinHPThreshHold * 1000) and (not Player:Buff(S.DFRBuff) and not Player:Buff(S.BSARBuff)) then
      if I.DAR:IsReady() then
        if HR.CastSuggested(I.DAR) then return "Use DAR" end
      elseif I.BSAR:IsReady() then
        if HR.CastSuggested(I.BSAR) then return "Use BSAR" end
      end
    end

    -- Legion Trinkets
    if Settings.Shaman.Commons.OnUseTrinkets then
	  if I.SpecterOfBetrayal:IsEquipped() and Target:IsInRange("Melee") and S.SpecterOfBetrayal:TimeSinceLastCast() > 45 and not Player:IsMoving() then
	    if HR.CastSuggested(I.SpecterOfBetrayal) then return "Use SpecterOfBetrayal" end
	  end

	  if I.HornOfValor:IsEquipped() and Target:IsInRange("Melee") and S.HornOfValor:TimeSinceLastCast() > 120 then
	    if HR.CastSuggested(I.HornOfValor) then return "Use HornOfValor" end
	  end
    end

    -- Lightning Shield: Not in the APL, but if we are talented into it and don't use it, what good is it?
    if S.LightningShield:IsAvailable() and not Player:Buff(S.LightningShieldBuff) then
      if HR.Cast(S.LightningShield) then return "Cast LightningShield" end
    end

    -- actions+=/call_action_list,name=asc,if=buff.ascendance.up
    if Player:Buff(S.AscendanceBuff) then
      -- actions.asc=crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck25
      if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (not Player:Buff(S.CrashLightningBuff) and Cache.EnemiesCount[10] > 1 and furyCheck25()) then
        if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
      end

      -- actions.asc+=/rockbiter,if=talent.landslide.enabled&!buff.landslide.up&charges_fractional>1.7
      if S.Rockbiter:IsCastableP(20) and S.Landslide:IsAvailable() and not Player:Buff(S.LandslideBuff) and S.Rockbiter:ChargesFractional() > 1.7 then
        if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
      end

      -- actions.asc+=/windstrike
      if S.WindStrike:IsCastableP(30) and Player:Maelstrom() >= S.WindStrike:Cost() then
        if HR.Cast(S.WindStrike) then return "Cast WindStrike" end
      end
    end

    -- actions+=/call_action_list,name=buffs
    -- actions.buffs=crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck25
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (not Player:Buff(S.CrashLightningBuff) and Cache.EnemiesCount[10] > 1 and furyCheck25()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.buffs+=/rockbiter,if=talent.landslide.enabled&!buff.landslide.up&charges_fractional>1.7
    if S.Rockbiter:IsCastableP(20) and (S.Landslide:IsAvailable() and not Player:Buff(S.LandslideBuff) and S.Rockbiter:ChargesFractional() > 1.7) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.buffs+=/fury_of_air,if=!ticking&maelstrom>=20
    if S.FuryOfAir:IsCastableP(10, true) and Player:Maelstrom() >= S.FuryOfAir:Cost() and (not Player:Buff(S.FuryOfAirBuff) and Player:Maelstrom() >= 20) then
      if HR.Cast(S.FuryOfAir) then return "Cast FuryOfAir" end
    end

    -- actions.buffs+=/flametongue,if=!buff.flametongue.up
    if S.Flametongue:IsCastableP(20) and (not Player:Buff(S.FlametongueBuff)) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck25
    if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff) and furyCheck25()) then
      if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.buffs+=/flametongue,if=buff.flametongue.remains<4.8+gcd
    if S.Flametongue:IsCastableP(20) and (Player:BuffRemainsP(S.FlametongueBuff) < 4.8 + Player:GCD()) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8+gcd&variable.furyCheck25
    if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and Player:BuffRemainsP(S.FrostbrandBuff) < 4.8 + Player:GCD() and furyCheck25()) then
      if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- Not exact, but if we don't have totems down then place them
    -- actions.buffs+=/totem_mastery,if=buff.resonance_totem.remains<2
    if S.TotemMastery:IsCastableP() and (not Player:Buff(S.ResonanceTotemBuff)) then
      if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
    end

    -- actions+=/call_action_list,name=cds
    if HR.CDsON() then
      -- Racial
      -- actions.cds+=/berserking,if=(talent.ascendance.enabled&buff.ascendance.up)|(talent.elemental_spirits.enabled&feral_spirit.remains>5)|(!talent.ascendance.enabled&!talent.elemental_spirits.enabled)
      if S.Berserking:IsCastableP() and (S.Ascendance:IsAvailable() or (S.ElementalSpirits:IsAvailable() and S.FeralSpirit:TimeSinceLastCast() <= 10) or (not S.Ascendance:IsAvailable() and not S.ElementalSpirits:IsAvailable())) then
        if HR.Cast(S.Berserking, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
      end

      -- Racial
      -- actions.cds+=/blood_fury,if=(talent.ascendance.enabled&(buff.ascendance.up|cooldown.ascendance.remains>50))|(!talent.ascendance.enabled&(feral_spirit.remains>5|cooldown.feral_spirit.remains>50))
      if S.BloodFury:IsCastableP() and ((S.Ascendance:IsAvailable() and (Player:Buff(S.AscendanceBuff) or S.Ascendance:TimeSinceLastCast() <= 130)) or (not S.Ascendance:IsAvailable() and (S.FeralSpirit:TimeSinceLastCast() <= 10 or S.Ascendance:TimeSinceLastCast() <= 130))) then
        if HR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
      end

      -- Racial
      -- actions.cds+=/fireblood,if=(talent.ascendance.enabled&(buff.ascendance.up|cooldown.ascendance.remains>50))|(!talent.ascendance.enabled&(feral_spirit.remains>5|cooldown.feral_spirit.remains>50))
      if S.Fireblood:IsCastableP() and ((S.Ascendance:IsAvailable() and (Player:Buff(S.AscendanceBuff) or S.Ascendance:TimeSinceLastCast() <= 130)) or (not S.Ascendance:IsAvailable() and (S.FeralSpirit:TimeSinceLastCast() <= 10 or S.Ascendance:TimeSinceLastCast() <= 130))) then
        if HR.Cast(S.Fireblood, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
      end

      -- Racial
      -- actions.cds+=/ancestral_call,if=(talent.ascendance.enabled&(buff.ascendance.up|cooldown.ascendance.remains>50))|(!talent.ascendance.enabled&(feral_spirit.remains>5|cooldown.feral_spirit.remains>50))
      if S.AncestralCall:IsCastableP() and ((S.Ascendance:IsAvailable() and (Player:Buff(S.AscendanceBuff) or S.Ascendance:TimeSinceLastCast() <= 130)) or (not S.Ascendance:IsAvailable() and (S.FeralSpirit:TimeSinceLastCast() <= 10 or S.Ascendance:TimeSinceLastCast() <= 130))) then
        if HR.Cast(S.AncestralCall, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast AncestralCall" end
      end

      -- actions.cds+=/potion,if=buff.ascendance.up|!talent.ascendance.enabled&feral_spirit.remains>5|target.time_to_die<=60
      -- Already handled

      -- actions.cds+=/feral_spirit
      if S.FeralSpirit:IsCastableP() and Settings.Shaman.Enhancement.EnableFS then
        if HR.Cast(S.FeralSpirit) then return "Cast FeralSpirit" end
      end

      -- actions.cds+=/ascendance,if=cooldown.strike.remains>0
      if S.Ascendance:IsCastableP() and ((S.WindStrike:CooldownRemainsP() > 0 or S.StormStrike:CooldownRemainsP() > 0)) then
        if HR.Cast(S.Ascendance) then return "Cast Ascendance" end
      end

      -- actions.cds+=/earth_elemental
      if S.EarthElemental:IsCastableP() and Settings.Shaman.Enhancement.EnableEE then
        if HR.Cast(S.EarthElemental) then return "Cast EarthElemental" end
      end
    end

    -- actions+=/call_action_list,name=core
    -- actions.core=earthen_spike,if=variable.furyCheck25
    if S.EarthenSpike:IsCastableP(10) and Player:Maelstrom() >= S.EarthenSpike:Cost() and (furyCheck25()) then
      if HR.Cast(S.EarthenSpike) then return "Cast EarthenSpike" end
    end

    -- actions.core+=/sundering,if=active_enemies>=3
    if S.Sundering:IsCastableP(10) and Player:Maelstrom() >= S.Sundering:Cost() and (Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.Sundering) then return "Cast Sundering" end
    end

    -- actions.core+=/stormstrike,cycle_targets=1,if=azerite.lightning_conduit.enabled&!debuff.lightning_conduit.up&active_enemies>1&(buff.stormbringer.up|(variable.OCPool70&variable.furyCheck35))
    if S.StormStrike:IsCastableP("Melee") and (S.LightningConduit:AzeriteEnabled() and not Target:Debuff(S.LightningConduitDebuff) and Cache.EnemiesCount[10] > 1 and (Player:Buff(S.StormbringerBuff) or (OCPool70() and furyCheck35()))) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.core+=/stormstrike,if=buff.stormbringer.up|(buff.gathering_storms.up&variable.OCPool70&variable.furyCheck35)
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Player:Buff(S.StormbringerBuff) or (Player:Buff(S.GatheringStormsBuff) and OCPool70() and furyCheck35())) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.core+=/crash_lightning,if=active_enemies>=3&variable.furyCheck25
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[10] >= 3 and furyCheck25()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.core+=/lightning_bolt,if=talent.overcharge.enabled&active_enemies=1&variable.furyCheck45&maelstrom>=40
    if S.LightningBolt:IsCastableP(40) and (S.Overcharge:IsAvailable() and Cache.EnemiesCount[40] == 1 and furyCheck45() and Player:Maelstrom() >= 40) then
      if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
    end

    -- actions.core+=/stormstrike,if=variable.OCPool70&variable.furyCheck35
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (OCPool70() and furyCheck35()) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.filler+=/sundering
    if S.Sundering:IsCastableP(10) and Player:Maelstrom() >= S.Sundering:Cost() then
      if HR.Cast(S.Sundering) then return "Cast Sundering" end
    end

    -- actions.core+=/crash_lightning,if=talent.forceful_winds.enabled&active_enemies>1&variable.furyCheck25
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (S.ForcefulWinds:IsAvailable() and Cache.EnemiesCount[10] > 1 and furyCheck25()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.core+=/flametongue,if=talent.searing_assault.enabled
    if S.Flametongue:IsCastableP(20) and (S.SearingAssault:IsAvailable()) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.core+=/lava_lash,if=talent.hot_hand.enabled&buff.hot_hand.react
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (S.HotHand:IsAvailable() and Player:Buff(S.HotHandBuff)) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.core+=/crash_lightning,if=active_enemies>1&variable.furyCheck25
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[10] > 1 and furyCheck25()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions+=/call_action_list,name=filler
    -- actions.filler=rockbiter,if=maelstrom<70
    if S.Rockbiter:IsCastableP(20) and (Player:Maelstrom() < 70) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/crash_lightning,if=talent.crashing_storm.enabled&variable.OCPool60
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (S.CrashingStorm:IsAvailable() and OCPool60()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/lava_lash,if=variable.OCPool80&variable.furyCheck45
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.filler+=/rockbiter
    if S.Rockbiter:IsCastableP(20) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/flametongue
    if S.Flametongue:IsCastableP(20) then
        if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    if HR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

HR.SetAPL(263, APL)