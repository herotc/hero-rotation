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
  -- Buffs
  VolleyBuff                            = Spell(260243),
  MasterMarksmanBuff                    = Spell(269576),
  PreciseShotsBuff                      = Spell(260242),
  SteadyFocusBuff                       = Spell(193534),
  DeadEyeBuff                           = Spell(321461),
  TrickShotsBuff                        = Spell(257622),
  -- Debuffs
  SerpentStingDebuff                    = Spell(271788),
  HuntersMarkDebuff                     = Spell(257284),
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
