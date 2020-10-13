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
  -- Pet Care Abilities
  SummonPet                             = Spell(883),
  SummonPet2                            = Spell(83242),
  SummonPet3                            = Spell(83243),
  SummonPet4                            = Spell(83244),
  SummonPet5                            = Spell(83245),
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  -- Player Abilities
  HuntersMark                           = Spell(257284),
  AnimalCompanion                       = Spell(267116),
  AspectoftheWild                       = Spell(193530),
  BestialWrath                          = Spell(19574),
  KillerInstinct                        = Spell(273887),
  BarbedShot                            = Spell(217200),
  Multishot                             = Spell(2643),
  Stampede                              = Spell(201430),
  ChimaeraShot                          = Spell(53209),
  AMurderofCrows                        = Spell(131894),
  Barrage                               = Spell(120360),
  KillCommand                           = Spell(34026),
  DireBeast                             = Spell(120679),
  CobraShot                             = Spell(193455),
  Intimidation                          = Spell(19577),
  CounterShot                           = Spell(147362),
  Exhilaration                          = Spell(109304),
  TarTrap                               = Spell(187698),
  Flare                                 = Spell(1543),
  KillShot                              = Spell(53351),
  ArcaneShot                            = Spell(185358),
  -- Talents
  SpittingCobra                         = Spell(257891),
  OneWithThePack                        = Spell(199528),
  ScentOfBlood                          = Spell(193532),
  Bloodshed                             = Spell(321530),
  -- Covenants
  WildSpirits                           = Spell(328231),
  DeathChakram                          = Spell(325028),
  ResonatingArrow                       = Spell(308491),
  FlayedShot                            = Spell(324149),
  -- Buffs
  AspectoftheWildBuff                   = Spell(193530),
  BestialWrathBuff                      = Spell(19574),
  BestialWrathPetBuff                   = Spell(186254),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  BeastCleaveBuff                       = Spell(118455, "pet"),
  BeastCleavePlayerBuff                 = Spell(268877),
  FrenzyBuff                            = Spell(272790, "pet"),
  -- Debuffs
  -- Racials
  AncestralCall                         = Spell(274738),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  BagofTricks                           = Spell(312411),
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
  Volley                                = Spell(260242),
  ChimaeraShot                          = Spell(342049),
  DeadEye                               = Spell(321460),
  -- Buffs
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
  PotionOfSpectralAgility = Item(171270),
  SoulForgeEmbersChest = Item(172327),
  SoulForgeEmbersHead = Item(172325)
}

Item.Hunter.Marksmanship = {
  PotionOfSpectralAgility = Item(171270),
  SoulForgeEmbersChest = Item(172327),
  SoulForgeEmbersHead = Item(172325)
}
