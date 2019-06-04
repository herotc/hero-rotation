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
  Boulderfist           = Spell(246035),

  TotemMastery          = Spell(262395),
  ResonanceTotemBuff    = Spell(262417),
  StormTotemBuff        = Spell(262397),
  EmberTotemBuff        = Spell(262399),
  TailwindTotemBuff     = Spell(262400),

  -- Azerite Traits
  LightningConduit         = Spell(275388),
  LightningConduitDebuff   = Spell(275391),
  PrimalPrimer             = Spell(272992),
  PrimalPrimerDebuff       = Spell(273006),
  StrengthOfEarth          = Spell(273461),
  NaturalHarmony           = Spell(278697),
  NaturalHarmonyFireBuff   = Spell(279028),
  NaturalHarmonyNatureBuff = Spell(279033),
  NaturalHarmonyFrostBuff  = Spell(279029),

  -- Utility
  WindShear             = Spell(57994),

  -- BfA Trinkets
  GalecallersBoon       = Spell(268314),

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

  -- BfA Trinkets
  GalecallersBoon           = Item(159614, {13, 14}),

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
  Commons = HR.GUISettings.APL.Shaman.Commons,
}

--- APL Variables
-- # Attempt to sync racial cooldowns with Ascendance or Feral Spirits, or use on cooldown if saving them will result in significant cooldown waste
-- actions+=/variable,name=cooldown_sync,value=(talent.ascendance.enabled&(buff.ascendance.up|cooldown.ascendance.remains>50))|(!talent.ascendance.enabled&(feral_spirit.remains>5|cooldown.feral_spirit.remains>50))
local function cooldown_sync()
  return ((S.Ascendance:IsAvailable() and (Player:Buff(S.AscendanceBuff) or S.Ascendance:CooldownRemainsP() > 50)) or (not S.Ascendance:IsAvailable() and (S.FeralSpirit:CooldownRemainsP() <= 115 or S.FeralSpirit:CooldownRemainsP() > 50)))
end
-- # Do not use a maelstrom-costing ability if it will bring you to 0 maelstrom and cancel fury of air.
-- actions+=/variable,name=furyCheck_SS,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.stormstrike.cost))
local function furyCheck_SS()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.StormStrike:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- actions+=/variable,name=furyCheck_LL,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.lava_lash.cost))
local function furyCheck_LL()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.LavaLash:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- actions+=/variable,name=furyCheck_CL,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.crash_lightning.cost))
local function furyCheck_CL()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.CrashLightning:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- actions+=/variable,name=furyCheck_FB,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.frostbrand.cost))
local function furyCheck_FB()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.Frostbrand:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- actions+=/variable,name=furyCheck_ES,value=maelstrom>=(talent.fury_of_air.enabled*(6+action.earthen_spike.cost))
local function furyCheck_ES()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.EarthenSpike:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- actions+=/variable,name=furyCheck_LB,value=maelstrom>=(talent.fury_of_air.enabled*(6+40))
local function furyCheck_LB()
  if S.FuryOfAir:IsAvailable() then
    return Player:Maelstrom() >= 6 + S.FuryOfAir:Cost()
  else
    return Player:Maelstrom() >= 0
  end
end
-- # Attempt to pool maelstrom so you'll be able to cast a fully-powered lightning bolt as soon as it's available when fighting one target.
-- actions+=/variable,name=OCPool,value=(active_enemies>1|(cooldown.lightning_bolt.remains>=2*gcd))
local function OCPool()
  return (Cache.EnemiesCount[10] > 1 or S.LightningBolt:CooldownRemainsP() >= 2 + Player:GCDRemains())
end
-- actions+=/variable,name=OCPool_SS,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.stormstrike.cost)))
local function OCPool_SS()
  if S.Overcharge:IsAvailable() then
    return (OCPool() or Player:Maelstrom() >= 40 + S.StormStrike:Cost())
  else
    return (OCPool() or Player:Maelstrom() >= 0)
  end
end
-- actions+=/variable,name=OCPool_LL,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.lava_lash.cost)))
local function OCPool_LL()
  if S.Overcharge:IsAvailable() then
    return (OCPool() or Player:Maelstrom() >= 40 + S.LavaLash:Cost())
  else
    return (OCPool() or Player:Maelstrom() >= 0)
  end
end
-- actions+=/variable,name=OCPool_CL,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.crash_lightning.cost)))
local function OCPool_CL()
  if S.Overcharge:IsAvailable() then
    return (OCPool() or Player:Maelstrom() >= 40 + S.CrashLightning:Cost())
  else
    return (OCPool() or Player:Maelstrom() >= 0)
  end
end
-- actions+=/variable,name=OCPool_FB,value=(variable.OCPool|maelstrom>=(talent.overcharge.enabled*(40+action.frostbrand.cost)))
local function OCPool_FB()
  if S.Overcharge:IsAvailable() then
    return (OCPool() or Player:Maelstrom() >= 40 + S.Frostbrand:Cost())
  else
    return (OCPool() or Player:Maelstrom() >= 0)
  end
end
-- # Attempt to pool maelstrom for Crash Lightning if multiple targets are present.
-- actions+=/variable,name=CLPool_LL,value=active_enemies=1|maelstrom>=(action.crash_lightning.cost+action.lava_lash.cost)
local function CLPool_LL()
  return (Cache.EnemiesCount[10] == 1 or Player:Maelstrom() >= S.CrashLightning:Cost() + S.LavaLash:Cost())
end
-- actions+=/variable,name=CLPool_SS,value=active_enemies=1|maelstrom>=(action.crash_lightning.cost+action.stormstrike.cost)
local function CLPool_SS()
  return (Cache.EnemiesCount[10] == 1 or Player:Maelstrom() >= S.CrashLightning:Cost() + S.StormStrike:Cost())
end
-- actions+=/variable,name=freezerburn_enabled,value=(talent.hot_hand.enabled&talent.hailstorm.enabled&azerite.primal_primer.enabled)
local function freezerburn_enabled()
  return (S.HotHand:IsAvailable() and S.Hailstorm:IsAvailable() and S.PrimalPrimer:AzeriteEnabled())
end
-- actions+=/variable,name=rockslide_enabled,value=(!variable.freezerburn_enabled&(talent.boulderfist.enabled&talent.landslide.enabled&azerite.strength_of_earth.enabled))
local function rockslide_enabled()
  return (not freezerburn_enabled() and (S.Boulderfist:IsAvailable() and S.Landslide:IsAvailable() and S.StrengthOfEarth:AzeriteEnabled()))
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
    Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false);

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
    if Settings.Shaman.Commons.ShowPotions and Target:MaxHealth() >= (Settings.Shaman.Commons.ConsumableMinHPThreshHold * 1000) and (Target:TimeToDie() <= 60 or Player:HasHeroism()) then
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

    -- BfA Trinkets
    if Settings.Shaman.Commons.OnUseTrinkets then
	  if I.GalecallersBoon:IsEquipped() and Target:IsInRange("Melee") and S.GalecallersBoon:TimeSinceLastCast() >= 60 and not Player:IsMoving() then
	    if HR.CastSuggested(I.GalecallersBoon) then return "Use GalecallersBoon" end
	  end
    end

    -- Lightning Shield if we have it talented!
    if S.LightningShield:IsAvailable() and not Player:Buff(S.LightningShieldBuff) then
      if HR.Cast(S.LightningShield) then return "Cast LightningShield" end
    end

    -- actions+=/call_action_list,name=asc,if=buff.ascendance.up
    if Player:Buff(S.AscendanceBuff) then
      -- actions.asc=crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck_CL
      if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and not Player:Buff(S.CrashLightningBuff) and Cache.EnemiesCount[10] > 1 and furyCheck_CL() then
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

    -- actions+=/call_action_list,name=priority
    -- actions.priority=crash_lightning,if=active_enemies>=(8-(talent.forceful_winds.enabled*3))&variable.freezerburn_enabled&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() then
      if S.ForcefulWinds:IsAvailable() and (Cache.EnemiesCount[10] >= (8 - 3)) and freezerburn_enabled() and furyCheck_CL() then
        if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
      elseif S.ForcefulWinds:IsAvailable() and (Cache.EnemiesCount[10] >= 8) and freezerburn_enabled() and furyCheck_CL() then
        if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
      end
    end

    -- actions.priority+=/lava_lash,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack=10&active_enemies=1&variable.freezerburn_enabled&variable.furyCheck_LL
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (S.PrimalPrimer:AzeriteRank() >= 2 and Target:DebuffStack(S.PrimalPrimerDebuff) == 10 and Cache.EnemiesCount[10] == 1 and freezerburn_enabled() and furyCheck_LL()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.priority+=/crash_lightning,if=!buff.crash_lightning.up&active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (not Player:Buff(S.CrashLightningBuff) and Cache.EnemiesCount[10] > 1 and furyCheck_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.priority+=/fury_of_air,if=!buff.fury_of_air.up&maelstrom>=20&spell_targets.fury_of_air_damage>=(1+variable.freezerburn_enabled)
    if S.FuryOfAir:IsCastableP(10, true) and Player:Maelstrom() >= S.FuryOfAir:Cost() then
      if not Player:Buff(S.FuryOfAirBuff) and Player:Maelstrom() >= 20 and Cache.EnemiesCount[10] >= 2 then
        if HR.Cast(S.FuryOfAir) then return "Cast FuryOfAir" end
      end
    end

    -- actions.priority+=/fury_of_air,if=buff.fury_of_air.up&&spell_targets.fury_of_air_damage<(1+variable.freezerburn_enabled)
    -- Disable if we don't have enough maelstrom.
    if S.FuryOfAir:IsCastableP() and (Player:Buff(S.FuryOfAirBuff) and Cache.EnemiesCount[10] <= 1) then
      if HR.Cast(S.FuryOfAir) then return "Cast FuryOfAir" end
    end

    -- Not exact, but if we don't have totems down then place them
    -- actions.priority+=/totem_mastery,if=buff.resonance_totem.remains<=2*gcd
    if S.TotemMastery:IsCastableP() and (not Player:Buff(S.ResonanceTotemBuff)) then
      if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
    end

    -- actions.priority+=/sundering,if=active_enemies>=3
    if S.Sundering:IsCastableP(10) and Player:Maelstrom() >= S.Sundering:Cost() and (Cache.EnemiesCount[10] >= 3) then
      if HR.Cast(S.Sundering, Settings.Shaman.Enhancement.GCDasOffGCD.Sundering) then return "Cast Sundering" end
    end

    -- actions.priority+=/rockbiter,if=talent.landslide.enabled&!buff.landslide.up&charges_fractional>1.7
    if S.Rockbiter:IsCastableP(20) and (S.Landslide:IsAvailable() and not Player:Buff(S.LandslideBuff) and S.Rockbiter:ChargesFractional() > 1.7) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- # With Natural Harmony, elevate the priority of elemental attacks in order to maintain the buffs when they're about to expire.
    -- actions.priority+=/frostbrand,if=(azerite.natural_harmony.enabled&buff.natural_harmony_frost.remains<=2*gcd)&talent.hailstorm.enabled&variable.furyCheck_FB
    if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and ((S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyFrostBuff) <= 2 * Player:GCDRemains()) and S.Hailstorm:IsAvailable() and furyCheck_FB()) then
      if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.priority+=/flametongue,if=(azerite.natural_harmony.enabled&buff.natural_harmony_fire.remains<=2*gcd)
    if S.Flametongue:IsCastableP(20) and (S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyFireBuff) <= 2 * Player:GCDRemains()) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.priority+=/rockbiter,if=(azerite.natural_harmony.enabled&buff.natural_harmony_nature.remains<=2*gcd)&maelstrom<70
    if S.Rockbiter:IsCastableP(20) and (S.NaturalHarmony:AzeriteEnabled() and Player:BuffRemainsP(S.NaturalHarmonyNatureBuff) <= 2 * Player:GCDRemains() and Player:Maelstrom() < 70) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions+=/call_action_list,name=maintenance,if=active_enemies<3
    if Cache.EnemiesCount[10] < 3 then
      -- actions.maintenance=flametongue,if=!buff.flametongue.up
      if S.Flametongue:IsCastableP(20) and (not Player:Buff(S.Flametongue)) then
        if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
      end

      -- actions.maintenance+=/frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck_FB
      if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff) and furyCheck_FB()) then
        if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
      end
    end

    -- actions+=/call_action_list,name=cds

    -- Skipping bloodlust..
    -- actions.cds=bloodlust,if=azerite.ancestral_resonance.enabled

    -- actions.cds+=/berserking,if=variable.cooldown_sync
    if S.Berserking:IsCastableP() and S.Berserking:IsAvailable() and cooldown_sync() then
      if HR.Cast(S.Berserking, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
    end

    -- actions.cds+=/blood_fury,if=variable.cooldown_sync
    if S.BloodFury:IsCastableP() and S.BloodFury:IsAvailable() and cooldown_sync() then
      if HR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- actions.cds+=/fireblood,if=variable.cooldown_sync
    if S.Fireblood:IsCastableP() and S.Fireblood:IsAvailable() and cooldown_sync() then
      if HR.Cast(S.Fireblood, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast Fireblood" end
    end

    -- actions.cds+=/ancestral_call,if=variable.cooldown_sync
    if S.AncestralCall:IsCastableP() and S.AncestralCall:IsAvailable() and cooldown_sync() then
      if HR.Cast(S.AncestralCall, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast AncestralCall" end
    end

    -- # Attempt to sync your DPS potion with a cooldown, unless the target is about to die.
    -- actions.cds+=/potion,if=buff.ascendance.up|!talent.ascendance.enabled&feral_spirit.remains>5|target.time_to_die<=60
    -- We already roughly handle this toward the beginning.

    -- actions.cds+=/feral_spirit
    if S.FeralSpirit:IsCastableP() and Settings.Shaman.Enhancement.EnableFS then
      if HR.Cast(S.FeralSpirit, Settings.Shaman.Enhancement.GCDasOffGCD.FeralSpirit) then return "Cast FeralSpirit" end
    end

    -- actions.cds+=/ascendance,if=cooldown.strike.remains>0
    if S.Ascendance:IsCastableP() and ((S.WindStrike:CooldownRemainsP() > 0 or S.StormStrike:CooldownRemainsP() > 0)) then
      if HR.Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "Cast Ascendance" end
    end

    -- actions.cds+=/earth_elemental
    if S.EarthElemental:IsCastableP() and Settings.Shaman.Enhancement.EnableEE then
      if HR.Cast(S.EarthElemental) then return "Cast EarthElemental" end
    end

    -- actions+=/call_action_list,name=freezerburn_core,if=variable.freezerburn_enabled
    -- actions.freezerburn_core=lava_lash,target_if=max:debuff.primal_primer.stack,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack=10&variable.furyCheck_LL&variable.CLPool_LL
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (Target:DebuffStack(S.PrimalPrimerDebuff) == 10 and S.PrimalPrimer:AzeriteRank() >= 2 and furyCheck_LL() and CLPool_LL()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.freezerburn_core+=/earthen_spike,if=variable.furyCheck_ES
    if S.EarthenSpike:IsCastableP(10) and Player:Maelstrom() >= S.EarthenSpike:Cost() and (furyCheck_ES()) then
      if HR.Cast(S.EarthenSpike) then return "Cast EarthenSpike" end
    end

    -- actions.freezerburn_core+=/stormstrike,cycle_targets=1,if=active_enemies>1&azerite.lightning_conduit.enabled&!debuff.lightning_conduit.up&variable.furyCheck_SS
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Cache.EnemiesCount[10] > 1 and S.LightningConduit:AzeriteEnabled() and not Target:Debuff(S.LightningConduitDebuff) and furyCheck_SS()) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.freezerburn_core+=/stormstrike,if=buff.stormbringer.up|(active_enemies>1&buff.gathering_storms.up&variable.furyCheck_SS)
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Player:Buff(S.StormbringerBuff) or (Cache.EnemiesCount[10] > 1 and Player:Buff(S.GatheringStormsBuff) and furyCheck_SS())) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.freezerburn_core+=/crash_lightning,if=active_enemies>=3&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[10] > 3 and furyCheck_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.freezerburn_core+=/lightning_bolt,if=talent.overcharge.enabled&active_enemies=1&variable.furyCheck_LB&maelstrom>=40
    if S.LightningBolt:IsCastableP(40) and (S.Overcharge:IsAvailable() and Cache.EnemiesCount[40] == 1 and furyCheck_LB() and Player:Maelstrom() >= 40) then
      if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
    end

    -- actions.freezerburn_core+=/lava_lash,if=azerite.primal_primer.rank>=2&debuff.primal_primer.stack>7&variable.furyCheck_LL&variable.CLPool_LL
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (S.PrimalPrimer:AzeriteRank() >= 2 and Target:DebuffStack(S.PrimalPrimer) > 7 and furyCheck_LL() and CLPool_LL()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.freezerburn_core+=/stormstrike,if=variable.OCPool_SS&variable.furyCheck_SS&variable.CLPool_SS
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (OCPool_SS() and furyCheck_SS() and CLPool_SS()) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.freezerburn_core+=/lava_lash,if=debuff.primal_primer.stack=10&variable.furyCheck_LL
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (Target:DebuffStack(S.PrimalPrimerDebuff) == 10 and furyCheck_LL()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions+=/call_action_list,name=default_core,if=!variable.freezerburn_enabled
    -- actions.default_core=earthen_spike,if=variable.furyCheck_ES
    if S.EarthenSpike:IsCastableP(10) and Player:Maelstrom() >= S.EarthenSpike:Cost() and (furyCheck_ES()) then
      if HR.Cast(S.EarthenSpike) then return "Cast EarthenSpike" end
    end

    -- actions.default_core+=/stormstrike,cycle_targets=1,if=active_enemies>1&azerite.lightning_conduit.enabled&!debuff.lightning_conduit.up&variable.furyCheck_SS
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Cache.EnemiesCount[10] > 1 and S.LightningConduit:AzeriteEnabled() and not Target:Debuff(S.LightningConduitDebuff) and furyCheck_SS()) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.default_core+=/stormstrike,if=buff.stormbringer.up|(active_enemies>1&buff.gathering_storms.up&variable.furyCheck_SS)
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Player:Buff(S.StormbringerBuff) or (Cache.EnemiesCount[10] >= 1 and Player:Buff(S.GatheringStormsBuff) and furyCheck_SS())) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.default_core+=/crash_lightning,if=active_enemies>=3&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[10] > 3 and furyCheck_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.default_core+=/lightning_bolt,if=talent.overcharge.enabled&active_enemies=1&variable.furyCheck_LB&maelstrom>=40
    if S.LightningBolt:IsCastableP(40) and (S.Overcharge:IsAvailable() and Cache.EnemiesCount[40] == 1 and furyCheck_LB() and Player:Maelstrom() >= 40) then
      if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
    end

    -- actions.default_core+=/stormstrike,if=variable.OCPool_SS&variable.furyCheck_SS
    if S.StormStrike:IsCastableP("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (OCPool_SS() and furyCheck_SS()) then
      if HR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions+=/call_action_list,name=maintenance,if=active_enemies>=3
    if Cache.EnemiesCount[10] >= 3 then
      -- actions.maintenance=flametongue,if=!buff.flametongue.up
      if S.Flametongue:IsCastableP(20) and (not Player:Buff(S.Flametongue)) then
        if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
      end

      -- actions.maintenance+=/frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck_FB
      if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff) and furyCheck_FB()) then
        if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
      end
    end

    -- actions.filler=sundering
    if S.Sundering:IsCastableP(10) and Player:Maelstrom() >= S.Sundering:Cost() then
      if HR.Cast(S.Sundering, Settings.Shaman.Enhancement.GCDasOffGCD.Sundering) then return "Cast Sundering" end
    end

    -- actions.filler+=/crash_lightning,if=talent.forceful_winds.enabled&active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (S.ForcefulWinds:IsAvailable() and Cache.EnemiesCount[10] > 1 and furyCheck_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/flametongue,if=talent.searing_assault.enabled
    if S.Flametongue:IsCastableP(20) and (S.SearingAssault:IsAvailable()) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.filler+=/lava_lash,if=!azerite.primal_primer.enabled&talent.hot_hand.enabled&buff.hot_hand.react
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (not S.PrimalPrimer:AzeriteEnabled() and S.HotHand:IsAvailable()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.filler+=/crash_lightning,if=active_enemies>1&variable.furyCheck_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[10] > 1 and furyCheck_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/rockbiter,if=maelstrom<70&!buff.strength_of_earth.up
    if S.Rockbiter:IsCastableP(20) and (Player:Maelstrom() < 70 and not Player:Buff(S.StrengthOfEarth)) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/crash_lightning,if=talent.crashing_storm.enabled&variable.OCPool_CL
    if S.CrashLightning:IsCastableP("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (S.CrashingStorm:IsAvailable() and OCPool_CL()) then
      if HR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/lava_lash,if=variable.OCPool_LL&variable.furyCheck_LL
    if S.LavaLash:IsCastableP("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (OCPool_LL() and furyCheck_LL()) then
      if HR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.filler+=/rockbiter
    if S.Rockbiter:IsCastableP(20) and (Player:Maelstrom() < 70 and not Player:Buff(S.StrengthOfEarth)) then
      if HR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8+gcd&variable.furyCheck_FB
    if S.Frostbrand:IsCastableP(20) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and Player:BuffRemainsP(S.FrostbrandBuff) < (4.8 + Player:GCDRemains()) and furyCheck_FB()) then
      if HR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.filler+=/flametongue
    if S.Flametongue:IsCastableP(20) then
      if HR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    if HR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

HR.SetAPL(263, APL)