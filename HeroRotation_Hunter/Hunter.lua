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
if not Spell.Hunter then Spell.Hunter = {} end
Spell.Hunter.BeastMastery = {
  -- Player Abilities
  AMurderofCrows                        = Spell(131894),
  AnimalCompanion                       = Spell(267116),
  ArcaneShot                            = Spell(185358),
  AspectoftheWild                       = Spell(193530),
  BarbedShot                            = Spell(217200),
  Barrage                               = Spell(120360),
  BestialWrath                          = Spell(19574),
  ChimaeraShot                          = Spell(53209),
  CobraShot                             = Spell(193455),
  CounterShot                           = Spell(147362),
  DireBeast                             = Spell(120679),
  Exhilaration                          = Spell(109304),
  Flare                                 = Spell(1543),
  HuntersMark                           = Spell(257284),
  Intimidation                          = Spell(19577),
  KillCommand                           = Spell(34026),
  KillerInstinct                        = Spell(273887),
  KillShot                              = Spell(53351),
  MultiShot                             = Spell(2643),
  Stampede                              = Spell(201430),
  TarTrap                               = Spell(187698),
  -- Pet Utility Abilities
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  SummonPet                             = Spell(883),
  SummonPet2                            = Spell(83242),
  SummonPet3                            = Spell(83243),
  SummonPet4                            = Spell(83244),
  SummonPet5                            = Spell(83245),
  -- Pet Abilities
  Bite                                 = Spell(17253, "pet"),
  BloodBolt                            = Spell(288962, "pet"),
  Claw                                 = Spell(16827, "pet"),
  Growl                                = Spell(2649, "pet"),
  Smack                                = Spell(49966, "pet"),
  -- Talents
  Bloodshed                             = Spell(321530),
  OneWithThePack                        = Spell(199528),
  ScentOfBlood                          = Spell(193532),
  SpittingCobra                         = Spell(257891),
  Stomp                                 = Spell(199530),
  -- Covenants
  DeathChakram                          = Spell(325028),
  FlayedShot                            = Spell(324149),
  ResonatingArrow                       = Spell(308491),
  WildSpirits                           = Spell(328231),
  WildSpiritsBuff                       = Spell(328275),
  -- Legendaries (Shadowlands)
  NesingwarysTrappingApparatusBuff      = Spell(336744),
  SoulforgeEmbersDebuff                 = Spell(336746),
  WailingArrow                          = Spell(355589),
  -- Conduits (Shadowlands)
  Bloodletting                          = Spell(341440),
  NewfoundResolve                       = Spell(351149),
  -- Buffs
  AspectoftheWildBuff                   = Spell(193530),
  BeastCleavePetBuff                    = Spell(118455, "pet"),
  BeastCleaveBuff                       = Spell(268877),
  BerserkingBuff                        = Spell(26297),
  BestialWrathBuff                      = Spell(19574),
  BestialWrathPetBuff                   = Spell(186254, "pet"),
  BloodFuryBuff                         = Spell(20572),
  FrenzyPetBuff                         = Spell(272790, "pet"),
  -- Debuffs
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Misc
  PoolFocus                             = Spell(999910),
}

Spell.Hunter.Marksmanship = {
  SummonPet                             = Spell(883),
  HuntersMark                           = Spell(257284),
  Trueshot                              = Spell(288613),
  AimedShot                             = Spell(19434),
  RapidFire                             = Spell(257044),
  CarefulAim                            = Spell(260228),
  ExplosiveShot                         = Spell(212431),
  Barrage                               = Spell(120360),
  AMurderofCrows                        = Spell(131894),
  SerpentSting                          = Spell(271788),
  ArcaneShot                            = Spell(185358),
  TarTrap                               = Spell(187698),
  SteadyShot                            = Spell(56641),
  Flare                                 = Spell(1543),
  KillShot                              = Spell(53351),
  Multishot                             = Spell(257620),
  CounterShot                           = Spell(147362),
  Exhilaration                          = Spell(109304),
  -- Covenants
  WildSpirits                           = Spell(328231),
  DeathChakram                          = Spell(325028),
  ResonatingArrow                       = Spell(308491),
  FlayedShot                            = Spell(324149),
  Fleshcraft                            = Spell(324631),
  -- Soulbinds
  EffusiveAnimaAccelerator              = Spell(352188),
  PustuleEruption                       = Spell(351094),
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  BagofTricks                           = Spell(312411),
  PiercingShot                          = Spell(198670),
  -- Talents
  CallingtheShots                       = Spell(260404),
  DoubleTap                             = Spell(260402),
  MasterMarksman                        = Spell(260309),
  SteadyFocus                           = Spell(193533),
  Volley                                = Spell(260243),
  ChimaeraShot                          = Spell(342049),
  DeadEye                               = Spell(321460),
  Streamline                            = Spell(260367),
  -- Buffs
  VolleyBuff                            = Spell(260243),
  MasterMarksmanBuff                    = Spell(269576),
  PreciseShotsBuff                      = Spell(260242),
  SteadyFocusBuff                       = Spell(193534),
  DeadEyeBuff                           = Spell(321461),
  TrickShotsBuff                        = Spell(257622),
  LockandLoadBuff                       = Spell(194594),
  -- Debuffs
  SerpentStingDebuff                    = Spell(271788),
  HuntersMarkDebuff                     = Spell(257284),
  ResonatingArrowDebuff                 = Spell(308498),
  WildMarkDebuff                        = Spell(328275),
  -- Legendaries
  EagletalonsTrueFocusBuff              = Spell(336851),
  WailingArrow                          = Spell(355589),
}

Spell.Hunter.Survival = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Pet Utility Abilities
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  SummonPet                             = Spell(883),
  SummonPet2                            = Spell(83242),
  SummonPet3                            = Spell(83243),
  SummonPet4                            = Spell(83244),
  SummonPet5                            = Spell(83245),
  -- Abilities
  AspectoftheEagle                      = Spell(186289),
  Carve                                 = Spell(187708),
  CoordinatedAssault                    = Spell(266779),
  Exhilaration                          = Spell(109304),
  Flare                                 = Spell(1543),
  Harpoon                               = Spell(190925),
  Intimidation                          = Spell(19577),
  KillCommand                           = Spell(259489),
  KillShot                              = Spell(320976),
  LatentPoison                          = Spell(273283),
  Muzzle                                = Spell(187707),
  RaptorStrike                          = MultiSpell(186270,265189),
  SerpentSting                          = Spell(259491),
  -- Traps
  FreezingTrap                          = Spell(187650),
  SteelTrap                             = Spell(162488),
  SteelTrapDebuff                       = Spell(162487),
  TarTrap                               = Spell(187698),
  TarTrapDebuff                         = Spell(135299),
  -- Bombs
  PheromoneBomb                         = Spell(270323),
  PheromoneBombDebuff                   = Spell(270332),
  ShrapnelBomb                          = Spell(270335),
  ShrapnelBombDebuff                    = Spell(270339),
  VolatileBomb                          = Spell(271045),
  VolatileBombDebuff                    = Spell(271049),
  WildfireBomb                          = Spell(259495),
  WildfireBombDebuff                    = Spell(269747),
  -- Talents
  AlphaPredator                         = Spell(269737),
  AMurderofCrows                        = Spell(131894),
  BirdsofPrey                           = Spell(260331),
  BloodseekerDebuff                     = Spell(259277),
  Butchery                              = Spell(212436),
  Chakrams                              = Spell(259391),
  FlankingStrike                        = Spell(269751),
  HydrasBite                            = Spell(260241),
  MongooseBite                          = MultiSpell(259387, 265888),
  MongooseFuryBuff                      = Spell(259388),
  TermsofEngagement                     = Spell(265895),
  TipoftheSpearBuff                     = Spell(260286),
  VipersVenom                           = Spell(268501),
  WildfireInfusion                      = Spell(271014),
  -- Buffs/Debuffs
  CoordinatedAssaultBuff                = Spell(266779),
  InternalBleedingDebuff                = Spell(270343),
  LatentPoisonDebuff                    = Spell(273286),
  SerpentStingDebuff                    = Spell(259491),
  VipersVenomBuff                       = Spell(268552),
  -- Covenants
  DeathChakram                          = Spell(325028),
  FlayedShot                            = Spell(324149),
  Fleshcraft                            = Spell(324631),
  ResonatingArrow                       = Spell(308491),
  WildSpirits                           = Spell(328231),
  WildSpiritsDebuff                     = Spell(328275),
  -- Soulbinds/Conduits
  PustuleEruption                       = Spell(351094),
  VolatileSolvent                       = Spell(323074),
  --legendary_debuffs
  NessingwarysTrappingBuff              = Spell(336744),
  SoulforgeEmbersDebuff                 = Spell(336746),
  -- Other
  PoolFocus                             = Spell(999910)
}

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.BeastMastery = {
  -- Potion
  PotionOfSpectralAgility = Item(171270)
  -- Trinkets
}

Item.Hunter.Marksmanship = {
  -- Potion
  PotionOfSpectralAgility = Item(171270)
  -- Trinkets
}

Item.Hunter.Survival = {
  -- Potion
  PotionOfSpectralAgility = Item(171270),
  -- Trinkets
  DreadfireVessel         = Item(184030, {13, 14})
}