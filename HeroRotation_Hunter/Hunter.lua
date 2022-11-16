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
if not Spell.Hunter then Spell.Hunter = {} end
Spell.Hunter.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  ArcaneShot                            = Spell(185358),
  Exhilaration                          = Spell(109304),
  Flare                                 = Spell(1543),
  HuntersMark                           = Spell(257284),
  -- Pet Utility Abilities
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  SummonPet                             = Spell(883),
  SummonPet2                            = Spell(83242),
  SummonPet3                            = Spell(83243),
  SummonPet4                            = Spell(83244),
  SummonPet5                            = Spell(83245),
  -- Talents
  AlphaPredator                         = Spell(269737),
  Barrage                               = Spell(120360),
  CounterShot                           = Spell(147362),
  DeathChakram                          = Spell(371891),
  ExplosiveShot                         = Spell(212431),
  Intimidation                          = Spell(19577),
  KillCommand                           = Spell(34026),
  KillShot                              = Spell(53351),
  KillerInstinct                        = Spell(273887),
  ScareBeast                            = Spell(1513),
  SerpentSting                          = Spell(271788),
  Stampede                              = Spell(201430),
  SteelTrap                             = Spell(162488),
  TarTrap                               = Spell(187698),
  -- Buffs
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  -- Debuffs
  HuntersMarkDebuff                     = Spell(257284),
  LatentPoisonDebuff                    = Spell(336903),
  SerpentStingDebuff                    = Spell(271788),
  TarTrapDebuff                         = Spell(135299),
  -- Misc
  PoolFocus                             = Spell(999910),
}

Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  -- Pet Abilities
  Bite                                 = Spell(17253, "pet"),
  BloodBolt                            = Spell(288962, "pet"),
  Claw                                 = Spell(16827, "pet"),
  Growl                                = Spell(2649, "pet"),
  Smack                                = Spell(49966, "pet"),
  -- Talents
  AMurderofCrows                        = Spell(131894),
  AnimalCompanion                       = Spell(267116),
  AspectoftheWild                       = Spell(193530),
  BarbedShot                            = Spell(217200),
  BeastCleave                           = Spell(115939),
  BestialWrath                          = Spell(19574),
  Bloodshed                             = Spell(321530),
  CalloftheWild                         = Spell(359844),
  CobraShot                             = Spell(193455),
  DireBeast                             = Spell(120679),
  KillCleave                            = Spell(378207),
  MultiShot                             = Spell(2643),
  OneWithThePack                        = Spell(199528),
  ScentofBlood                          = Spell(193532),
  Stomp                                 = Spell(199530),
  WailingArrow                          = Spell(392060),
  WildCall                              = Spell(185789),
  WildInstincts                         = Spell(378442),
  -- Buffs
  AspectoftheWildBuff                   = Spell(193530),
  BeastCleavePetBuff                    = Spell(118455, "pet"),
  BeastCleaveBuff                       = Spell(268877),
  BestialWrathBuff                      = Spell(19574),
  BestialWrathPetBuff                   = Spell(186254, "pet"),
  CalloftheWildBuff                     = Spell(359844),
  FrenzyPetBuff                         = Spell(272790, "pet"),
  -- Debuffs
  BarbedShotDebuff                      = Spell(217200),
})

Spell.Hunter.Marksmanship = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  AimedShot                             = Spell(19434),
  BurstingShot                          = Spell(186387),
  KillShot                              = Spell(53351),
  Multishot                             = Spell(257620),
  RapidFire                             = Spell(257044),
  SteadyShot                            = Spell(56641),
  Trueshot                              = Spell(288613),
  -- Talents
  CallingtheShots                       = Spell(260404),
  CarefulAim                            = Spell(260228),
  ChimaeraShot                          = Spell(342049),
  DeadEye                               = Spell(321460),
  DoubleTap                             = Spell(260402),
  MasterMarksman                        = Spell(260309),
  SteadyFocus                           = Spell(193533),
  Streamline                            = Spell(260367),
  Volley                                = Spell(260243),
  -- Buffs
  DeadEyeBuff                           = Spell(321461),
  LockandLoadBuff                       = Spell(194594),
  MasterMarksmanBuff                    = Spell(269576),
  PreciseShotsBuff                      = Spell(260242),
  SteadyFocusBuff                       = Spell(193534),
  TrickShotsBuff                        = Spell(257622),
  VolleyBuff                            = Spell(260243),
  -- Debuffs
  -- Legendaries
  EagletalonsTrueFocusBuff              = Spell(336851),
})

Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  AspectoftheEagle                      = Spell(186289),
  Carve                                 = Spell(187708),
  CoordinatedAssault                    = Spell(266779),
  Harpoon                               = Spell(190925),
  KillCommand                           = Spell(259489),
  KillShot                              = Spell(320976),
  Muzzle                                = Spell(187707),
  RaptorStrike                          = MultiSpell(186270,265189),
  SerpentSting                          = Spell(259491),
  -- Traps
  FreezingTrap                          = Spell(187650),
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
  BirdsofPrey                           = Spell(260331),
  BloodseekerDebuff                     = Spell(259277),
  Butchery                              = Spell(212436),
  Chakrams                              = Spell(259391),
  FlankingStrike                        = Spell(269751),
  HydrasBite                            = Spell(260241),
  MongooseBite                          = MultiSpell(259387, 265888),
  MongooseFuryBuff                      = Spell(259388),
  TermsofEngagement                     = Spell(265895),
  TipoftheSpear                         = Spell(260285),
  TipoftheSpearBuff                     = Spell(260286),
  VipersVenom                           = Spell(268501),
  WildfireInfusion                      = Spell(271014),
  -- Buffs/Debuffs
  CoordinatedAssaultBuff                = Spell(266779),
  InternalBleedingDebuff                = Spell(270343),
  MadBombardierBuff                     = Spell(363805),
  SerpentStingDebuff                    = Spell(259491),
  SteelTrapDebuff                       = Spell(162487),
  VipersVenomBuff                       = Spell(268552),
})

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Commons = {
  -- Potions
  PotionOfSpectralAgility               = Item(171270),
  -- Trinkets
  CacheofAcquiredTreasures              = Item(188265, {13, 14}),
  DreadfireVessel                       = Item(184030, {13, 14}),
  -- Other On-Use Items
  Jotungeirr                            = Item(186404)
}

Item.Hunter.BeastMastery = MergeTableByKey(Item.Hunter.Commons, {
})

Item.Hunter.Marksmanship = MergeTableByKey(Item.Hunter.Commons, {
})

Item.Hunter.Survival = MergeTableByKey(Item.Hunter.Commons, {
})