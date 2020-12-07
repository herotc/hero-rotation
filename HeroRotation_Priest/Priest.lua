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
if not Spell.Priest then Spell.Priest = {} end
Spell.Priest.Shadow = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),

  -- Base Spells
  DarkThoughtBuff                       = Spell(341207),
  DevouringPlague                       = Spell(335467),
  DevouringPlagueDebuff                 = Spell(335467),
  Dispersion                            = Spell(47585),
  Mindbender                            = MultiSpell(200174,34433),
  MindBlast                             = Spell(8092),
  MindFlay                              = Spell(15407),
  MindSear                              = Spell(48045), -- Splash, 10
  PowerInfusion                         = Spell(10060),
  PowerInfusionBuff                     = Spell(10060),
  Shadowform                            = Spell(232698),
  ShadowformBuff                        = Spell(232698),
  ShadowWordDeath                       = Spell(32379),
  ShadowWordPain                        = Spell(589),
  ShadowWordPainDebuff                  = Spell(589),
  Silence                               = Spell(15487),
  VampiricTouch                         = Spell(34914),
  VampiricTouchDebuff                   = Spell(34914),
  VoidBolt                              = Spell(205448),
  VoidEruption                          = Spell(228260), -- Splash, 10
  VoidformBuff                          = Spell(194249),

  -- Talents
  Damnation                             = Spell(341374),
  FortressOfTheMind                     = Spell(193195),
  HungeringVoid                         = Spell(345218),
  HungeringVoidDebuff                   = Spell(345219),
  Misery                                = Spell(238558),
  PsychicLink                           = Spell(199484),
  SearingNightmare                      = Spell(341385), -- Splash, 10
  ShadowCrash                           = Spell(205385), -- Splash, 8
  SurrenderToMadness                    = Spell(319952),
  TwistofFate                           = Spell(109142),
  UnfurlingDarkness                     = Spell(341273),
  UnfurlingDarknessBuff                 = Spell(341282),
  VoidTorrent                           = Spell(263165),

  -- Covenant Abilities
  AscendedBlast                         = Spell(325283),
  AscendedNova                          = Spell(325020), -- Melee, 8
  BoonoftheAscended                     = Spell(325013),
  BoonoftheAscendedBuff                 = Spell(325013),
  FaeGuardians                          = Spell(327661),
  FaeGuardiansBuff                      = Spell(327661),
  Mindgames                             = Spell(323673),
  UnholyNova                            = Spell(324724), -- Melee, 15
  WrathfulFaerieDebuff                  = Spell(342132),

  -- Conduit/Soulbind Effects
  CombatMeditation                      = Spell(328266),
  DissonantEchoes                       = Spell(338342),
  DissonantEchoesBuff                   = Spell(343144),
  FieldofBlossoms                       = Spell(319191),
  GroveInvigoration                     = Spell(322721),

  -- Legendary Effects
}

Spell.Priest.Discipline = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BerserkingBuff                        = Spell(26297),
  BloodFury                             = Spell(20572),
  BloodFuryBuff                         = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),

  -- Base Spells
  MindBlast                             = Spell(8092),
  Smite                                 = Spell(585),
  ShadowWordPain                        = Spell(589),
  ShadowWordPainDebuff                  = Spell(589),
  ShadowWordDeath                       = Spell(32379),
  HolyNova                              = Spell(132157), -- Melee, 12
  MindSear                              = Spell(48045), -- Splash, 10
  Penance                               = Spell(47540),
  PowerInfusion                         = Spell(10060),
  PowerWordRadiance                     = Spell(194509),
  PowerWordFortitude                    = Spell(21562),

  -- Talents
  Schism                                = Spell(214621),
  Mindbender                            = MultiSpell(123040, 34433),
  PowerWordSolace                       = Spell(129250),
  ShadowCovenant                        = Spell(314867),
  ShadowCovenantBuff                    = Spell(322105),
  PurgeTheWicked                        = Spell(204197),
  PurgeTheWickedDebuff                  = Spell(204213),
  DivineStar                            = Spell(110744),
  Halo                                  = Spell(120517),

  -- Covenant Abilities
  AscendedBlast                         = Spell(325315),
  AscendedNova                          = Spell(325020), -- Melee, 8
  BoonoftheAscended                     = Spell(325013),
  BoonoftheAscendedBuff                 = Spell(325013),
  FaeGuardians                          = Spell(327661),
  FaeGuardiansBuff                      = Spell(327661),
  WrathfulFaerieDebuff                  = Spell(342132),
  Mindgames                             = Spell(323673),
  UnholyNova                            = Spell(324724), -- Melee, 15

  -- Conduit/Soulbind Effects

  -- Legendary Effects

  -- Other
  Pool                                  = Spell(999910)
}

-- Items
if not Item.Priest then Item.Priest = {} end
Item.Priest.Shadow = {
  -- Potion
  PotionofPhantomFire              = Item(171352),
  -- Trinkets
  DarkmoonDeckPutrescence          = Item(173069, {13, 14}),
  DreadfireVessel                  = Item(184030, {13, 14}),
  EmpyrealOrdinance                = Item(180117, {13, 14}),
  GlyphofAssimilation              = Item(184021, {13, 14}),
  InscrutableQuantumDevice         = Item(179350, {13, 14}),
  MacabreSheetMusic                = Item(184024, {13, 14}),
  SinfulGladiatorsBadgeofFerocity  = Item(175921, {13, 14}),
  SoullettingRuby                  = Item(178809, {13, 14}),
  SunbloodAmethyst                 = Item(178826, {13, 14}),
}

Item.Priest.Discipline = {
}
