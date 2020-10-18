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
local MouseOver  = Unit.MouseOver
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR = HeroRotation
local Settings = HR.GUISettings.APL.Rogue.Commons
local Everyone = HR.Commons.Everyone
-- Lua
local mathmin = math.min
local pairs = pairs
-- File Locals
local Commons = {}

--- ======= GLOBALIZE =======
HR.Commons.Rogue = Commons

--- ============================ CONTENT ============================
-- Spells
if not Spell.Rogue then Spell.Rogue = {} end
Spell.Rogue.Assassination = {
  -- Racials
  AncestralCall         = Spell(274738),
  ArcanePulse           = Spell(260364),
  ArcaneTorrent         = Spell(25046),
  BagofTricks           = Spell(312411),
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),
  Fireblood             = Spell(265221),
  LightsJudgment        = Spell(255647),
  Shadowmeld            = Spell(58984),
  -- Abilities
  Ambush                = Spell(8676),
  Envenom               = Spell(32645),
  FanofKnives           = Spell(51723),
  Garrote               = Spell(703),
  KidneyShot            = Spell(408),
  Mutilate              = Spell(1329),
  PoisonedKnife         = Spell(185565),
  Rupture               = Spell(1943),
  SliceAndDice          = Spell(315496),
  Stealth               = Spell(1784),
  Stealth2              = Spell(115191), -- w/ Subterfuge Talent
  Vanish                = Spell(1856),
  VanishBuff            = Spell(11327),
  Vendetta              = Spell(79140),
  -- Talents
  BlindsideBuff         = Spell(121153),
  CrimsonTempest        = Spell(121411),
  DeeperStratagem       = Spell(193531),
  Exsanguinate          = Spell(200806),
  HiddenBladesBuff      = Spell(270070),
  InternalBleeding      = Spell(154953),
  MarkedforDeath        = Spell(137619),
  MasterAssassin        = Spell(255989),
  Nightstalker          = Spell(14062),
  Shiv                  = Spell(5938),
  ShivDebuff            = Spell(319504),
  Subterfuge            = Spell(108208),
  SubterfugeBuff        = Spell(115192),
  VenomRush             = Spell(152152),
  -- Azerite Traits
  DoubleDose            = Spell(273007),
  EchoingBlades         = Spell(287649),
  ShroudedSuffocation   = Spell(278666),
  ScentOfBlood          = Spell(277679),
  TwistTheKnife         = Spell(273488),
  -- Essences
  BloodoftheEnemy       = Spell(297108),
  MemoryofLucidDreams   = Spell(298357),
  PurifyingBlast        = Spell(295337),
  RippleInSpace         = Spell(302731),
  ConcentratedFlame     = Spell(295373),
  TheUnboundForce       = Spell(298452),
  WorldveinResonance    = Spell(295186),
  FocusedAzeriteBeam    = Spell(295258),
  GuardianofAzeroth     = Spell(295840),
  ReapingFlames         = Spell(310690),
  BloodoftheEnemyDebuff = Spell(297108),
  RecklessForceBuff     = Spell(302932),
  RecklessForceCounter  = Spell(302917),
  LifebloodBuff         = Spell(295137),
  LucidDreamsBuff       = MultiSpell(298357, 299372, 299374),
  ConcentratedFlameBurn = Spell(295368),
  -- Covenant
  SerratedBoneSpike       = Spell(328547),
  SerratedBoneSpikeDebuff = Spell(324073),
  Flagellation            = Spell(323654),
  FlagellationMastery     = Spell(345569),
  -- Defensive
  CrimsonVial           = Spell(185311),
  Feint                 = Spell(1966),
  -- Utility
  Blind                 = Spell(2094),
  Kick                  = Spell(1766),
  -- Poisons
  CripplingPoison       = Spell(3408),
  DeadlyPoison          = Spell(2823),
  DeadlyPoisonDebuff    = Spell(2818),
  WoundPoison           = Spell(8679),
  WoundPoisonDebuff     = Spell(8680),
  -- Misc
  TheDreadlordsDeceit   = Spell(208693),
  VigorTrinketBuff      = Spell(287916),
  RazorCoralDebuff      = Spell(303568),
  PoolEnergy            = Spell(999910)
}

Spell.Rogue.Outlaw = {
  -- Racials
  AncestralCall                   = Spell(274738),
  ArcanePulse                     = Spell(260364),
  ArcaneTorrent                   = Spell(25046),
  BagofTricks                     = Spell(312411),
  Berserking                      = Spell(26297),
  BloodFury                       = Spell(20572),
  Fireblood                       = Spell(265221),
  LightsJudgment                  = Spell(255647),
  Shadowmeld                      = Spell(58984),
  -- Abilities
  AdrenalineRush                  = Spell(13750),
  Ambush                          = Spell(8676),
  BetweentheEyes                  = Spell(315341),
  BladeFlurry                     = Spell(13877),
  Opportunity                     = Spell(195627),
  PistolShot                      = Spell(185763),
  RolltheBones                    = Spell(315508),
  Dispatch                        = Spell(2098),
  SinisterStrike                  = Spell(193315),
  Stealth                         = Spell(1784),
  Vanish                          = Spell(1856),
  VanishBuff                      = Spell(11327),
  -- Talents
  AcrobaticStrikes                = Spell(196924),
  BladeRush                       = Spell(271877),
  DeeperStratagem                 = Spell(193531),
  GhostlyStrike                   = Spell(196937),
  KillingSpree                    = Spell(51690),
  LoadedDiceBuff                  = Spell(256171),
  MarkedforDeath                  = Spell(137619),
  QuickDraw                       = Spell(196938),
  SliceandDice                    = Spell(315496),
  -- Azerite Traits
  AceUpYourSleeve                 = Spell(278676),
  Deadshot                        = Spell(272935),
  DeadshotBuff                    = Spell(272940),
  SnakeEyesPower                  = Spell(275846),
  SnakeEyesBuff                   = Spell(275863),
  KeepYourWitsBuff                = Spell(288988),
  -- Essences
  BloodoftheEnemy                 = Spell(297108),
  MemoryofLucidDreams             = Spell(298357),
  PurifyingBlast                  = Spell(295337),
  RippleInSpace                   = Spell(302731),
  ConcentratedFlame               = Spell(295373),
  TheUnboundForce                 = Spell(298452),
  WorldveinResonance              = Spell(295186),
  FocusedAzeriteBeam              = Spell(295258),
  GuardianofAzeroth               = Spell(295840),
  ReapingFlames                   = Spell(310690),
  LifebloodBuff                   = Spell(295137),
  LucidDreamsBuff                 = MultiSpell(298357, 299372, 299374),
  ConcentratedFlameBurn           = Spell(295368),
  BloodoftheEnemyDebuff           = Spell(297108),
  RecklessForceBuff               = Spell(302932),
  RecklessForceCounter            = Spell(302917),
  -- Legendary
  MasterAssassinsMark             = Spell(340094),
  -- Covenant
  SerratedBoneSpike               = Spell(328547),
  SerratedBoneSpikeDebuff         = Spell(324073),
  Flagellation                    = Spell(323654),
  FlagellationMastery             = Spell(345569),
  -- Defensive
  CrimsonVial                     = Spell(185311),
  Feint                           = Spell(1966),
  -- Utility
  Kick                            = Spell(1766),
  Blind                           = Spell(2094),
  -- Roll the Bones
  Broadside                       = Spell(193356),
  BuriedTreasure                  = Spell(199600),
  GrandMelee                      = Spell(193358),
  RuthlessPrecision               = Spell(193357),
  SkullandCrossbones              = Spell(199603),
  TrueBearing                     = Spell(193359),
  -- Poisons
  CripplingPoison                 = Spell(3408),
  InstantPoison                   = Spell(315584),
  NumblingPoison                  = Spell(5761),
  -- Misc
  ConductiveInkDebuff             = Spell(302565),
  VigorTrinketBuff                = Spell(287916),
  RazorCoralDebuff                = Spell(303568),
}

Spell.Rogue.Subtlety = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  Shadowmeld                            = Spell(58984),
  -- Abilities
  Backstab                              = Spell(53),
  Eviscerate                            = Spell(196819),
  FindWeaknessDebuff                    = Spell(316220),
  ShadowBlades                          = Spell(121471),
  ShadowDance                           = Spell(185313),
  ShadowDanceBuff                       = Spell(185422),
  Shadowstrike                          = Spell(185438),
  ShadowVault                           = Spell(319175),
  ShurikenStorm                         = Spell(197835),
  ShurikenToss                          = Spell(114014),
  SliceandDice                          = Spell(315496),
  Stealth                               = Spell(1784),
  Stealth2                              = Spell(115191), -- w/ Subterfuge Talent
  SymbolsofDeath                        = Spell(212283),
  Rupture                               = Spell(1943),
  Vanish                                = Spell(1856),
  VanishBuff                            = Spell(11327),
  VanishBuff2                           = Spell(115193), -- w/ Subterfuge Talent
  -- Talents
  Alacrity                              = Spell(193539),
  DarkShadow                            = Spell(245687),
  DeeperStratagem                       = Spell(193531),
  EnvelopingShadows                     = Spell(238104),
  Gloomblade                            = Spell(200758),
  MarkedforDeath                        = Spell(137619),
  MasterofShadows                       = Spell(196976),
  Nightstalker                          = Spell(14062),
  PremeditationBuff                     = Spell(343173),
  SecretTechnique                       = Spell(280719),
  ShadowFocus                           = Spell(108209),
  ShurikenTornado                       = Spell(277925),
  Subterfuge                            = Spell(108208),
  Vigor                                 = Spell(14983),
  Weaponmaster                          = Spell(193537),
  -- Azerite Traits
  BladeInTheShadows                     = Spell(275896),
  Inevitability                         = Spell(278683),
  NightsVengeancePower                  = Spell(273418),
  NightsVengeanceBuff                   = Spell(273424),
  Perforate                             = Spell(277673),
  ReplicatingShadows                    = Spell(286121),
  TheFirstDance                         = Spell(278681),
  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  ReapingFlames                         = Spell(310690),
  BloodoftheEnemyDebuff                 = Spell(297108),
  RecklessForceBuff                     = Spell(302932),
  RecklessForceCounter                  = Spell(302917),
  LifebloodBuff                         = Spell(295137),
  ConcentratedFlameBurn                 = Spell(295368),
  -- Covenant
  SerratedBoneSpike                     = Spell(328547),
  SerratedBoneSpikeDot                  = Spell(324073),
  EchoingReprimand                      = Spell(323547),
  Sepsis                                = Spell(328305),
  Flagellation                          = Spell(323654),
  FlagellationMastery                   = Spell(345569),
  -- Legendaries
  TheRottenBuff                         = Spell(341134),
  -- Defensive
  CrimsonVial                           = Spell(185311),
  Feint                                 = Spell(1966),
  -- Utility
  Blind                                 = Spell(2094),
  CheapShot                             = Spell(1833),
  Kick                                  = Spell(1766),
  KidneyShot                            = Spell(408),
  Sprint                                = Spell(2983),
  -- Poisons
  CripplingPoison                       = Spell(3408),
  InstantPoison                         = Spell(315584),
  NumbingPoison                         = Spell(5761),
  -- Misc
  ConductiveInkDebuff                   = Spell(302565),
  VigorTrinketBuff                      = Spell(287916),
  RazorCoralDebuff                      = Spell(303568),
  TheDreadlordsDeceit                   = Spell(228224),
  PoolEnergy                            = Spell(999910)
}

-- Items
if not Item.Rogue then Item.Rogue = {} end
Item.Rogue.Assassination = {
  -- Trinkets
  GalecallersBoon       = Item(159614, {13, 14}),
  LustrousGoldenPlumage = Item(159617, {13, 14}),
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

Item.Rogue.Outlaw = {
  -- Trinkets
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

Item.Rogue.Subtlety = {
  -- Trinkets
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

-- Stealth
function Commons.Stealth (Stealth, Setting)
  if Settings.StealthOOC and Stealth:IsCastable() and Player:StealthDown() then
    if HR.Cast(Stealth, Settings.OffGCDasOffGCD.Stealth) then return "Cast Stealth (OOC)" end
  end

  return false
end

-- Crimson Vial
function Commons.CrimsonVial (CrimsonVial)
  if CrimsonVial:IsCastable() and Player:HealthPercentage() <= Settings.CrimsonVialHP then
    if HR.Cast(CrimsonVial, Settings.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial (Defensives)" end
  end

  return false
end

-- Feint
function Commons.Feint (Feint)
  if Feint:IsCastable() and Player:BuffDown(Feint) and Player:HealthPercentage() <= Settings.FeintHP then
    if HR.Cast(Feint, Settings.GCDasOffGCD.Feint) then return "Cast Feint (Defensives)" end
  end
end

-- Marked for Death Sniping
function Commons.MfDSniping (MarkedforDeath)
  if MarkedforDeath:IsCastable() then
    local BestUnit, BestUnitTTD = nil, 60
    local MOTTD = MouseOver:IsInRange(30) and MouseOver:TimeToDie() or 11111
    for _, ThisUnit in pairs(Player:GetEnemiesInRange(30)) do
      local TTD = ThisUnit:TimeToDie()
      -- Note: Increased the SimC condition by 50% since we are slower.
      if not ThisUnit:IsMfDBlacklisted() and TTD < Player:ComboPointsDeficit()*1.5 and TTD < BestUnitTTD then
        if MOTTD - TTD > 1 then
          BestUnit, BestUnitTTD = ThisUnit, TTD
        else
          BestUnit, BestUnitTTD = MouseOver, MOTTD
        end
      end
    end
    if BestUnit and BestUnit:GUID() ~= Target:GUID() then
      HR.CastLeftNameplate(BestUnit, MarkedforDeath)
    end
  end
end

-- Everyone CanDotUnit override, originally used for Mantle legendary
-- Is it worth to DoT the unit ?
function Commons.CanDoTUnit (Unit, HealthThreshold)
  return Everyone.CanDoTUnit(Unit, HealthThreshold)
end
--- ======= SIMC CUSTOM FUNCTION / EXPRESSION =======
-- cp_max_spend
function Commons.CPMaxSpend ()
  -- Should work for all 3 specs since they have same Deeper Stratagem Spell ID.
  return Spell.Rogue.Subtlety.DeeperStratagem:IsAvailable() and 6 or 5
end

-- "cp_spend"
function Commons.CPSpend ()
  return mathmin(Player:ComboPoints(), Commons.CPMaxSpend())
end

-- poisoned
--[[ Original SimC Code
  return dots.deadly_poison -> is_ticking() ||
          debuffs.wound_poison -> check();
]]
function Commons.Poisoned (Unit)
  return (Unit:DebuffUp(Spell.Rogue.Assassination.DeadlyPoisonDebuff) or Unit:DebuffUp(Spell.Rogue.Assassination.WoundPoisonDebuff)) and true or false
end

-- poison_remains
--[[ Original SimC Code
  if ( dots.deadly_poison -> is_ticking() ) {
    return dots.deadly_poison -> remains();
  } else if ( debuffs.wound_poison -> check() ) {
    return debuffs.wound_poison -> remains();
  } else {
    return timespan_t::from_seconds( 0.0 );
  }
]]
function Commons.PoisonRemains (Unit)
  return (Unit:DebuffUp(Spell.Rogue.Assassination.DeadlyPoisonDebuff) and Unit:DebuffRemains(Spell.Rogue.Assassination.DeadlyPoisonDebuff))
    or (Unit:DebuffUp(Spell.Rogue.Assassination.WoundPoisonDebuff) and Unit:DebuffRemains(Spell.Rogue.Assassination.WoundPoisonDebuff))
    or 0
end

-- bleeds
--[[ Original SimC Code
  rogue_td_t* tdata = get_target_data( target );
  return tdata -> dots.garrote -> is_ticking() +
          tdata -> dots.internal_bleeding -> is_ticking() +
          tdata -> dots.rupture -> is_ticking();
]]
function Commons.Bleeds ()
  return (Target:DebuffUp(Spell.Rogue.Assassination.Garrote) and 1 or 0) + (Target:DebuffUp(Spell.Rogue.Assassination.Rupture) and 1 or 0)
  + (Target:DebuffUp(Spell.Rogue.Assassination.CrimsonTempest) and 1 or 0) + (Target:DebuffUp(Spell.Rogue.Assassination.InternalBleeding) and 1 or 0)
end

-- poisoned_bleeds
--[[ Original SimC Code
  int poisoned_bleeds = 0;
  for ( size_t i = 0, actors = sim -> target_non_sleeping_list.size(); i < actors; i++ )
  {
    player_t* t = sim -> target_non_sleeping_list[i];
    rogue_td_t* tdata = get_target_data( t );
    if ( tdata -> lethal_poisoned() ) {
      poisoned_bleeds += tdata -> dots.garrote -> is_ticking() +
                          tdata -> dots.internal_bleeding -> is_ticking() +
                          tdata -> dots.rupture -> is_ticking();
    }
  }
  return poisoned_bleeds;
]]
local PoisonedBleedsCount = 0
function Commons.PoisonedBleeds ()
  PoisonedBleedsCount = 0
  for _, ThisUnit in pairs(Player:GetEnemiesInRange(50)) do
    if Commons.Poisoned(ThisUnit) then
      -- TODO: For loop for this ? Not sure it's worth considering we would have to make 2 times spell object (Assa is init after Commons)
      if ThisUnit:DebuffUp(Spell.Rogue.Assassination.Garrote) then
        PoisonedBleedsCount = PoisonedBleedsCount + 1
      end
      if ThisUnit:DebuffUp(Spell.Rogue.Assassination.InternalBleeding) then
        PoisonedBleedsCount = PoisonedBleedsCount + 1
      end
      if ThisUnit:DebuffUp(Spell.Rogue.Assassination.Rupture) then
        PoisonedBleedsCount = PoisonedBleedsCount + 1
      end
    end
  end
  return PoisonedBleedsCount
end

-- Master Assassin's Mark Remains Check
local MasterAssassinLegoBuff, NominalDuration = Spell(340094), 4
function Commons.MasterAssassinsMarkRemains ()
  if Player:BuffRemains(MasterAssassinLegoBuff) < 0 then
    return Player:GCDRemains() + NominalDuration
  else
    return Player:BuffRemains(MasterAssassinLegoBuff)
  end
end
