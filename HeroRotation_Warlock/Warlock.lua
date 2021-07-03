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

--- ============================ CONTENT ============================

-- Spells
if not Spell.Warlock then Spell.Warlock = {} end
Spell.Warlock.Demonology = {
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(33702),
  Fireblood                             = Spell(265221),

  -- Base Abilities
  AxeToss                               = Spell(119914),
  CallDreadstalkers                     = Spell(104316),
  Demonbolt                             = Spell(264178),
  DemonicCoreBuff                       = Spell(264173),
  Felstorm                              = Spell(89751),
  HandofGuldan                          = Spell(105174), -- Splash, 8
  Implosion                             = Spell(196277), -- Splash, 8
  ShadowBolt                            = Spell(686),
  SpellLock                             = Spell(119910),
  SummonDemonicTyrant                   = Spell(265187),
  SummonPet                             = Spell(30146),
  UnendingResolve                       = Spell(104773),

  -- Talents
  BilescourgeBombers                    = Spell(267211), -- Splash, 8
  DemonicCalling                        = Spell(205145),
  DemonicCallingBuff                    = Spell(205146),
  DemonicConsumption                    = Spell(267215),
  DemonicPowerBuff                      = Spell(265273),
  DemonicStrength                       = Spell(267171),
  Doom                                  = Spell(603),
  DoomDebuff                            = Spell(603),
  FromtheShadows                        = Spell(267170),
  GrimoireFelguard                      = Spell(111898),
  InnerDemons                           = Spell(267216),
  NetherPortal                          = Spell(267217),
  NetherPortalBuff                      = Spell(267218),
  PowerSiphon                           = Spell(264130),
  SacrificedSouls                       = Spell(267214),
  SoulConduit                           = Spell(215941),
  SoulStrike                            = Spell(264057),
  SummonVilefiend                       = Spell(264119),

  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DecimatingBoltBuff                    = Spell(325299),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792), -- Splash, 8/10/12/15?
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640), -- Splash, 15

  -- Soulbinds/Conduits
  CombatMeditation                      = Spell(328266),
  FieldofBlossoms                       = Spell(319191),
  GroveInvigoration                     = Spell(322721),
  LeadByExample                         = Spell(342156),
  RefinedPalate                         = Spell(336243),
  WildHuntTactics                       = Spell(325066),

  -- Legendary Effects
  BalespidersBuff                       = Spell(337161),
  ImplosivePotentialBuff                = Spell(337139),

  -- Item Effects
  ShiverVenomDebuff                     = Spell(301624),
}

Spell.Warlock.Affliction = {
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(33702),
  Fireblood                             = Spell(265221),

  -- Base Abilities
  Agony                                 = Spell(980),
  AgonyDebuff                           = Spell(980),
  Corruption                            = Spell(172),
  CorruptionDebuff                      = Spell(146739),
  DrainLife                             = Spell(234153),
  MaleficRapture                        = Spell(324536),
  SeedofCorruption                      = Spell(27243),
  SeedofCorruptionDebuff                = Spell(27243),
  ShadowBolt                            = Spell(686),
  SummonDarkglare                       = Spell(205180),
  SummonPet                             = Spell(688),
  UnstableAffliction                    = Spell(316099),
  UnstableAfflictionDebuff              = Spell(316099),

  -- Talents
  Nightfall                             = Spell(108558),
  InevitableDemise                      = Spell(334319),
  InvetiableDemiseBuff                  = Spell(334320),
  DrainSoul                             = Spell(198590),

  WritheinAgony                         = Spell(196102),
  AbsoluteCorruption                    = Spell(196103),
  SiphonLife                            = Spell(63106),
  SiphonLifeDebuff                      = Spell(63106),

  SowtheSeeds                           = Spell(196226),
  PhantomSingularity                    = Spell(205179),
  PhantomSingularityDebuff              = Spell(205179),
  VileTaint                             = Spell(278350),
  VileTaintDebuff                       = Spell(278350),

  ShadowEmbrace                         = Spell(32388),
  ShadowEmbraceDebuff                   = Spell(32390),
  Haunt                                 = Spell(48181),
  HauntDebuff                           = Spell(48181),

  GrimoireofSacrifice                   = Spell(108503),
  GrimoireofSacrificeBuff               = Spell(196099),

  DarkSoulMisery                        = Spell(113860),

  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792), -- Splash, 8/10/12/15?
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640), -- Splash, 15

  -- Conduit Effects
  CorruptingLeer                        = Spell(339455),

  -- Legendary Effects
  MaleficWrathBuff                      = Spell(337125),

  -- Item Effects

}

Spell.Warlock.Destruction = {
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(33702),
  Fireblood                             = Spell(265221),

  -- Base Abilities
  ChaosBolt                             = Spell(116858),
  Conflagrate                           = Spell(17962),
  Backdraft                             = Spell(117828),
  Havoc                                 = Spell(80240),
  Immolate                              = Spell(348),
  ImmolateDebuff                        = Spell(157736),
  Incinerate                            = Spell(29722),
  RainofFire                            = Spell(5740),
  SummonInfernal                        = Spell(1122),
  ShadowBolt                            = Spell(686),
  SummonDarkglare                       = Spell(205180),
  SummonPet                             = Spell(688),
  UnstableAffliction                    = Spell(316099),
  UnstableAfflictionDebuff              = Spell(316099),

  -- Talents
  Flashover                             = Spell(267115),
  Eradication                           = Spell(196412),
  EradicationDebuff                     = Spell(196414),
  SoulFire                              = Spell(6353),

  ReverseEntropy                        = Spell(205148),
  InternalCombustion                    = Spell(266134),
  Shadowburn                            = Spell(17877),

  Inferno                               = Spell(270545),
  FireandBrimstone                      = Spell(196408),
  Cataclysm                             = Spell(152108),

  RoaringBlaze                          = Spell(205184),
  RoaringBlazeDebuff                    = Spell(265931),
  RainofChaos                           = Spell(266086),
  GrimoireofSacrifice                   = Spell(108503),
  GrimoireofSacrificeBuff               = Spell(196099),

  SoulConduit                           = Spell(215941),
  ChannelDemonfire                      = Spell(196447),
  DarkSoulInstability                   = Spell(113858),

  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792),
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640),

  -- Conduit Effects
  LeadByExample                         = Spell(342156),

  -- Item Effects

}

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Demonology = {
  -- Potion
  PotionofSpectralIntellect             = Item(307096),
  -- Trinkets
  DarkmoonDeckPutrescence               = Item(173069, {13, 14}),
  DreadfireVessel                       = Item(184030, {13, 14}),
  EbonsoulVise                          = Item(186431, {13, 14}),
  EmpyrealOrdnance                      = Item(180117, {13, 14}),
  GlyphofAssimilation                   = Item(184021, {13, 14}),
  OverflowingAnimaCage                  = Item(178849, {13, 14}),
  ShadowedOrbofTorment                  = Item(186428, {13, 14}),
  SinfulAspirantsEmblem                 = Item(178334, {13, 14}),
  SinfulGladiatorsEmblem                = Item(178447, {13, 14}),
  SoleahsSecretTechnique                = Item(185818, {13, 14}),
  SoulIgniter                           = Item(184019, {13, 14}),
  SoullettingRuby                       = Item(178809, {13, 14}),
  SunbloodAmethyst                      = Item(178826, {13, 14}),
  TomeofMonstrousConstructions          = Item(186422, {13, 14}),
  UnchainedGladiatorsShackles           = Item(186980, {13, 14}),
}

Item.Warlock.Affliction = {
  -- Potion
  PotionofSpectralIntellect             = Item(307096),
  -- Trinkets
  DarkmoonDeckPutrescence               = Item(173069, {13, 14}),
  DreadfireVessel                       = Item(184030, {13, 14}),
  EbonsoulVise                          = Item(186431, {13, 14}),
  EmpyrealOrdnance                      = Item(180117, {13, 14}),
  FlameofBattle                         = Item(181501, {13, 14}),
  GlyphofAssimilation                   = Item(184021, {13, 14}),
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  InstructorsDivineBell                 = Item(184842, {13, 14}),
  MacabreSheetMusic                     = Item(184024, {13, 14}),
  OverflowingAnimaCage                  = Item(178849, {13, 14}),
  ShadowedOrbofTorment                  = Item(186428, {13, 14}),
  SinfulAspirantsBadgeofFerocity        = Item(175884, {13, 14}),
  SinfulGladiatorsBadgeofFerocity       = Item(175921, {13, 14}),
  SoulIgniter                           = Item(184019, {13, 14}),
  SoullettingRuby                       = Item(178809, {13, 14}),
  SunbloodAmethyst                      = Item(178826, {13, 14}),
  TabletofDespair                       = Item(181357, {13, 14}),
  UnchainedGladiatorsShackles           = Item(186980, {13, 14}),
  WakenersFrond                         = Item(181457, {13, 14}),
}

Item.Warlock.Destruction = {
  -- Potion
  PotionofSpectralIntellect             = Item(307096)
  -- Trinkets
}
