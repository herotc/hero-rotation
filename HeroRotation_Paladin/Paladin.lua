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
local MergeTableByKey = HL.Utils.MergeTableByKey
-- HeroRotation
local HR         = HeroRotation

--- ============================ CONTENT ============================
-- Spells
if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  GiftoftheNaaru                        = Spell(59542),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  Consecration                          = Spell(26573),
  CrusaderStrike                        = Spell(35395),
  DivineShield                          = Spell(642),
  DivineSteed                           = Spell(190784),
  FlashofLight                          = Spell(19750),
  HammerofJustice                       = Spell(853),
  HandofReckoning                       = Spell(62124),
  Judgment                              = Spell(20271),
  Rebuke                                = Spell(96231),
  ShieldoftheRighteous                  = Spell(53600),
  WordofGlory                           = Spell(85673),
  -- Talents
  AvengingWrath                         = Spell(384376),
  HammerofWrath                         = MultiSpell(24275, 326730),
  HolyAvenger                           = Spell(105809),
  HolyAvengerBuff                       = Spell(105809),
  LayonHands                            = Spell(633),
  SanctifiedWrath                       = Spell(53376),
  Seraphim                              = Spell(152262),
  SeraphimBuff                          = Spell(152262),
  -- Covenants (Shadowlands)
  AshenHallow                           = Spell(316958),
  BlessingofAutumn                      = Spell(328622),
  BlessingofSpring                      = Spell(328282),
  BlessingofSummer                      = Spell(328620),
  BlessingofWinter                      = Spell(328281),
  DivinePurpose                         = Spell(223817),
  DivineTollCov                         = Spell(304971),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  VanquishersHammer                     = Spell(328204),
  VanquishersHammerBuff                 = Spell(328204),
  -- Soulbinds/Conduits (Shadowlands)
  Expurgation                           = Spell(339371),
  PustuleEruption                       = Spell(351094),
  VengefulShock                         = Spell(340006),
  VengefulShockDebuff                   = Spell(340007),
  VolatileSolvent                       = Spell(323074),
  VolatileSolventHumanBuff              = Spell(323491),
  -- Auras
  ConcentrationAura                     = Spell(317920),
  CrusaderAura                          = Spell(32223),
  DevotionAura                          = Spell(465),
  RetributionAura                       = Spell(183435),
  -- Buffs
  AvengingWrathBuff                     = Spell(31884),
  ConsecrationBuff                      = Spell(188370),
  DivinePurposeBuff                     = Spell(223819),
  ScarsofFraternalStrifeBuff4           = Spell(368638),
  ShieldoftheRighteousBuff              = Spell(132403),
  TemptationBuff                        = Spell(234143),
  -- Debuffs
  ConsecrationDebuff                    = Spell(204242),
  CruelGarroteDebuff                    = Spell(230011),
  -- Legendary Effects
  DivineResonanceBuff                   = Spell(355455),
  FinalVerdictBuff                      = Spell(337228),
  JudgmentDebuff                        = Spell(197277),
  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Paladin.Protection = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  ArdentDefender                        = Spell(31850),
  ArdentDefenderBuff                    = Spell(31850),
  AvengersShield                        = Spell(31935),
  GuardianofAncientKings                = Spell(86659),
  GuardianofAncientKingsBuff            = Spell(86659),
  HammeroftheRighteous                  = Spell(53595),
  Judgment                              = Spell(275779),
  JudgmentDebuff                        = Spell(197277),
  ShiningLightFreeBuff                  = Spell(327510),
  -- Talents
  BlessedHammer                         = Spell(204019),
  CrusadersJudgment                     = Spell(204023),
  MomentofGlory                         = Spell(327193),
  SanctifiedWrath                       = Spell(171648),
})

Spell.Paladin.Retribution = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  TemplarsVerdict                       = Spell(85256),
  -- Talents
  AshestoDust                           = Spell(383300),
  BladeofJustice                        = Spell(184575),
  BladeofWrath                          = Spell(231832),
  Crusade                               = Spell(231895), -- On-bar spell ID. Talent is a different ID for some reason.
  CrusadeTalent                         = Spell(384392),
  DivineStorm                           = Spell(53385),
  DivineToll                            = Spell(375576),
  EmpyreanPower                         = Spell(326732),
  ExecutionSentence                     = Spell(343527),
  ExecutionersWrath                     = Spell(387196),
  Exorcism                              = Spell(383185),
  FinalReckoning                        = Spell(343721),
  FiresofJustice                        = Spell(203316),
  RadiantDecree                         = Spell(383469),
  RadiantDecreeTalent                   = Spell(384052),
  RighteousVerdict                      = Spell(267610),
  ShieldofVengeance                     = Spell(184662),
  WakeofAshes                           = Spell(255937),
  Zeal                                  = Spell(269569),
  -- Buffs
  CrusadeBuff                           = Spell(231895),
  EmpyreanPowerBuff                     = Spell(326733),
  -- Debuffs
  -- Legendary Effects
  FinalVerdict                          = Spell(336872),
})

Spell.Paladin.Holy = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  DivineProtection                      = Spell(498),
  HolyShock                             = Spell(20473),
  Judgment                              = Spell(275773),
  JudgmentDebuff                        = Spell(197277),
  LightofDawn                           = Spell(85222),
  InfusionofLightBuff                   = Spell(54149),
  -- Talents
  AvengingCrusader                      = Spell(216331),
  Awakening                             = Spell(248033),
  BestowFaith                           = Spell(223306),
  CrusadersMight                        = Spell(196926),
  GlimmerofLight                        = Spell(325966),
  GlimmerofLightDebuff                  = Spell(325966),
  HolyPrism                             = Spell(114165),
  LightsHammer                          = Spell(114158),
})

-- Items
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Commons = {
  -- Potion
  PotionofSpectralIntellect             = Item(171273),
  PotionofSpectralStrength              = Item(171275),
  -- Trinkets
  AspirantsBadgeCosmic                  = Item(186906, {13, 14}),
  AspirantsBadgeSinful                  = Item(175884, {13, 14}),
  AspirantsBadgeUnchained               = Item(185161, {13, 14}),
  BloodstainedHandkerchief              = Item(142159, {13, 14}),
  ChainsofDomination                    = Item(188252, {13, 14}),
  DarkmoonDeckVoracity                  = Item(173087, {13, 14}),
  DreadfireVessel                       = Item(184030, {13, 14}),
  EarthbreakersImpact                   = Item(188264, {13, 14}),
  EnforcersStunGrenade                  = Item(110017, {13, 14}),
  FaultyCountermeasure                  = Item(137539, {13, 14}),
  GiantOrnamentalPearl                  = Item(137369, {13, 14}),
  GladiatorsBadgeCosmic                 = Item(186866, {13, 14}),
  GladiatorsBadgeSinful                 = Item(175921, {13, 14}),
  GladiatorsBadgeUnchained              = Item(185197, {13, 14}),
  GrimCodex                             = Item(178811, {13, 14}),
  HeartoftheSwarm                       = Item(188255, {13, 14}),
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  MacabreSheetMusic                     = Item(184024, {13, 14}),
  MemoryofPastSins                      = Item(184025, {13, 14}),
  OverwhelmingPowerCrystal              = Item(179342, {13, 14}),
  RemoteGuidanceDevice                  = Item(169769, {13, 14}),
  SalvagedFusionAmplifier               = Item(186432, {13, 14}),
  ScarsofFraternalStrife                = Item(188253, {13, 14}),
  SkulkersWing                          = Item(184016, {13, 14}),
  SpareMeatHook                         = Item(178751, {13, 14}),
  TheFirstSigil                         = Item(188271, {13, 14}),
  ToeKneesPromise                       = Item(142164, {13, 14}),
  WindscarWhetstone                     = Item(137486, {13, 14}),
  -- Other On-Use Items
  AnodizedDeflectors                    = Item(168978),
  GaveloftheFirstArbiter                = Item(189862),
  RingofCollapsingFutures               = Item(142173, {11, 12}),
}

Item.Paladin.Protection = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Retribution = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Holy = MergeTableByKey(Item.Paladin.Commons, {
})
