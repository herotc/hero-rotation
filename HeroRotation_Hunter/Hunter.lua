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
}

Spell.Hunter.Survival = {
  SummonPet                             = Spell(883),
  Flare                                 = Spell(1543),
  SteelTrapDebuff                       = Spell(162487),
  SteelTrap                             = Spell(162488),
  TarTrap                               = Spell(187698),
  Harpoon                               = Spell(190925),
  MongooseBite                          = MultiSpell(259387, 265888),
  MongooseFuryBuff                      = Spell(259388),
  CoordinatedAssaultBuff                = Spell(266779),
  BlurofTalons                          = Spell(277653),
  BlurofTalonsBuff                      = Spell(277969),
  RaptorStrike                          = MultiSpell(186270, 265189),
  FlankingStrike                        = Spell(269751),
  KillCommand                           = Spell(259489),
  KillShot                              = Spell(320976),
  WildfireBomb                          = Spell(259495),
  WildfireBombDebuff                    = Spell(269747),
  ShrapnelBomb                          = Spell(270335),
  PheromoneBomb                         = Spell(270323),
  VolatileBomb                          = Spell(271045),
  SerpentSting                          = Spell(259491),
  SerpentStingDebuff                    = Spell(259491),
  AMurderofCrows                        = Spell(131894),
  CoordinatedAssault                    = Spell(266779),
  TipoftheSpearBuff                     = Spell(260286),
  ShrapnelBombDebuff                    = Spell(270339),
  Chakrams                              = Spell(259391),
  BloodFury                             = Spell(20572),
  AncestralCall                         = Spell(274738),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  Berserking                            = Spell(26297),
  BagofTricks                           = Spell(312411),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  AspectoftheEagle                      = Spell(186289),
  Exhilaration                          = Spell(109304),
  Muzzle                                = Spell(187707),
  Intimidation                          = Spell(19577),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  GuardianofAzerothBuff                 = Spell(295855),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  Carve                                 = Spell(187708),
  GuerrillaTactics                      = Spell(264332),
  LatentPoison                          = Spell(273283),
  LatentPoisonDebuff                    = Spell(273286),
  BloodseekerDebuff                     = Spell(259277),
  Butchery                              = Spell(212436),
  WildfireInfusion                      = Spell(271014),
  InternalBleedingDebuff                = Spell(270343),
  VipersVenomBuff                       = Spell(268552),
  TermsofEngagement                     = Spell(265895),
  VipersVenom                           = Spell(268501),
  AlphaPredator                         = Spell(269737),
  HydrasBite                            = Spell(260241),
  BirdsofPrey                           = Spell(260331),
  ArcaneTorrent                         = Spell(50613),
  RazorCoralDebuff                      = Spell(303568),
  PoolFocus                             = Spell(999910),
  -- Covenants
  DeathChakram                          = Spell(325028),
  FlayedShot                            = Spell(324149),
  ResonatingArrow                       = Spell(308491),
  WildSpirits                           = Spell(328231),
  WildSpiritsBuff                       = Spell(328275),
  --legendary_debuffs
}

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.BeastMastery = {
  -- Potions/Trinkets
  -- "Other On Use"
  PotionOfSpectralAgility = Item(171270)
}

Item.Hunter.Marksmanship = {
  PotionOfSpectralAgility = Item(171270)
}

Item.Hunter.Survival = {
  PotionOfSpectralAgility = Item(171270)
}