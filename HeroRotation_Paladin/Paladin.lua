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
  AvengingWrath                         = Spell(31884),
  AvengingWrathBuff                     = Spell(31884),
  Consecration                          = Spell(26573),
  ConsecrationBuff                      = Spell(188370),
  ConsecrationDebuff                    = Spell(204242),
  CrusaderStrike                        = Spell(35395),
  DevotionAura                          = Spell(465),
  DevotionAuraBuff                      = Spell(465),
  DivineShield                          = Spell(642),
  DivineSteed                           = Spell(190784),
  FlashofLight                          = Spell(19750),
  HammerofJustice                       = Spell(853),
  HammerofWrath                         = MultiSpell(24275, 326730),
  HandofReckoning                       = Spell(62124),
  LayonHands                            = Spell(633),
  Rebuke                                = Spell(96231),
  ShieldoftheRighteous                  = Spell(53600),
  ShieldoftheRighteousBuff              = Spell(132403),
  WordofGlory                           = Spell(85673),
  -- Talents
  HolyAvenger                           = Spell(105809),
  HolyAvengerBuff                       = Spell(105809),
  Seraphim                              = Spell(152262),
  SeraphimBuff                          = Spell(152262),
  -- Covenants (Shadowlands)
  AshenHallow                           = Spell(316958),
  BlessingofAutumn                      = Spell(328622),
  BlessingofSpring                      = Spell(328282),
  BlessingofSummer                      = Spell(328620),
  BlessingofWinter                      = Spell(328281),
  DivinePurpose                         = Spell(223817),
  DivineToll                            = Spell(304971),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  VanquishersHammer                     = Spell(328204),
  VanquishersHammerBuff                 = Spell(328204),
  -- Soulbinds/Conduits (Shadowlands)
  Expurgation                           = Spell(339371),
  VengefulShock                         = Spell(340006),
  VengefulShockDebuff                   = Spell(340007),
  -- Buffs
  DivinePurposeBuff                     = Spell(223819),
  -- Legendary Effects
  DivineResonanceBuff                   = Spell(355455),
  FinalVerdictBuff                      = Spell(337228),
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
  BladeofJustice                        = Spell(184575),
  DivineStorm                           = Spell(53385),
  Judgment                              = Spell(20271),
  JudgmentDebuff                        = Spell(197277),
  TemplarsVerdict                       = Spell(85256),
  WakeofAshes                           = Spell(255937),
  -- Talents
  BladeofWrath                          = Spell(231832),
  Crusade                               = Spell(231895),
  CrusadeBuff                           = Spell(231895),
  EmpyreanPower                         = Spell(326732),
  ExecutionSentence                     = Spell(343527),
  FinalReckoning                        = Spell(343721),
  FiresofJustice                        = Spell(203316),
  RighteousVerdict                      = Spell(267610),
  SanctifiedWrath                       = Spell(317866),
  Zeal                                  = Spell(269569),
  -- Defensive
  ShieldofVengeance                     = Spell(184662),
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
  PotionofPhantomFire                   = Item(171349),
  -- Trinkets
  AspirantsBadgeSinful                  = Item(175884, {13, 14}),
  AspirantsBadgeUnchained               = Item(185161, {13, 14}),
  DarkmoonDeckVoracity                  = Item(173087, {13, 14}),
  DreadfireVessel                       = Item(184030, {13, 14}),
  FaultyCountermeasure                  = Item(137539, {13, 14}),
  GiantOrnamentalPearl                  = Item(137369, {13, 14}),
  GladiatorsBadgeSinful                 = Item(175921, {13, 14}),
  GladiatorsBadgeUnchained              = Item(185197, {13, 14}),
  GrimCodex                             = Item(178811, {13, 14}),
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  MacabreSheetMusic                     = Item(184024, {13, 14}),
  MemoryofPastSins                      = Item(184025, {13, 14}),
  OverwhelmingPowerCrystal              = Item(179342, {13, 14}),
  SalvagedFusionAmplifier               = Item(186432, {13, 14}),
  SkulkersWing                          = Item(184016, {13, 14}),
  SpareMeatHook                         = Item(178751, {13, 14}),
  WindscarWhetstone                     = Item(137486, {13, 14}),
}

Item.Paladin.Protection = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Retribution = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Holy = MergeTableByKey(Item.Paladin.Commons, {
})
