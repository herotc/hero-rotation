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
if not Spell.Priest then Spell.Priest = {} end
Spell.Priest.Commons = {
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
  -- Abilities
  DesperatePrayer                       = Spell(19236),
  HolyNova                              = Spell(132157), -- Melee, 12
  MindBlast                             = Spell(8092),
  MindSear                              = Spell(48045), -- Splash, 10
  PowerInfusion                         = Spell(10060),
  PowerInfusionBuff                     = Spell(10060),
  ShadowWordDeath                       = Spell(32379),
  ShadowWordPain                        = Spell(589),
  ShadowWordPainDebuff                  = Spell(589),
  Smite                                 = Spell(585),
  -- Talents
  DivineStar                            = Spell(110744),
  -- Covenant Abilities
  AscendedNova                          = Spell(325020), -- Melee, 8
  BoonoftheAscended                     = Spell(325013),
  BoonoftheAscendedBuff                 = Spell(325013),
  FaeGuardians                          = Spell(327661),
  FaeGuardiansBuff                      = Spell(327661),
  Fleshcraft                            = Spell(324631),
  Mindgames                             = Spell(323673),
  UnholyNova                            = Spell(324724), -- Melee, 15
  WrathfulFaerieDebuff                  = Spell(342132),
  -- Soulbind Abilities
  FieldofBlossoms                       = Spell(319191),
  GroveInvigoration                     = Spell(322721),
  PustuleEruption                       = Spell(351094),
  VolatileSolvent                       = Spell(323074),
  VolatileSolventHumanBuff              = Spell(323491),
  -- Other
  Pool                                  = Spell(999910)
}
Spell.Priest.Shadow = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  DarkThoughtBuff                       = Spell(341207),
  DevouringPlague                       = Spell(335467),
  DevouringPlagueDebuff                 = Spell(335467),
  Dispersion                            = Spell(47585),
  Mindbender                            = MultiSpell(200174,34433),
  MindFlay                              = Spell(15407),
  Shadowform                            = Spell(232698),
  ShadowformBuff                        = Spell(232698),
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
  -- Conduit/Soulbind Effects
  CombatMeditation                      = Spell(328266),
  DissonantEchoes                       = Spell(338342),
  DissonantEchoesBuff                   = Spell(343144),
  FieldofBlossoms                       = Spell(319191),
  GroveInvigoration                     = Spell(322721),
  RedirectedAnimaBuff                   = Spell(342814),
  -- Tier Set Effects
  LivingShadowBuff                      = Spell(363578)
})

Spell.Priest.Discipline = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  Penance                               = Spell(47540),
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
  Halo                                  = Spell(120517),
  SpiritShell                           = Spell(109964),
  -- Covenant Abilities
  AscendedBlast                         = Spell(325315),
})

Spell.Priest.Holy = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  HolyFire                              = Spell(14914),
  HolyFireDebuff                        = Spell(14914),
  HolyWordChastise                      = Spell(88625),
  -- Talents
  Apotheosis                            = Spell(200183),
  Halo                                  = Spell(120517),
})

-- Items
if not Item.Priest then Item.Priest = {} end
Item.Priest.Commons = {
  -- Potion
  PotionofSpectralIntellect        = Item(171352),
  -- Trinkets
  ArchitechtsIngenuityCore         = Item(188268, {13, 14}),
  DarkmoonDeckPutrescence          = Item(173069, {13, 14}),
  DreadfireVessel                  = Item(184030, {13, 14}),
  EmpyrealOrdinance                = Item(180117, {13, 14}),
  GlyphofAssimilation              = Item(184021, {13, 14}),
  InscrutableQuantumDevice         = Item(179350, {13, 14}),
  MacabreSheetMusic                = Item(184024, {13, 14}),
  ShadowedOrbofTorment             = Item(186428, {13, 14}),
  SinfulGladiatorsBadgeofFerocity  = Item(175921, {13, 14}),
  SoullettingRuby                  = Item(178809, {13, 14}),
  SunbloodAmethyst                 = Item(178826, {13, 14}),
  TheFirstSigil                    = Item(188271, {13, 14}),
}

Item.Priest.Shadow = MergeTableByKey(Item.Priest.Commons, {
})

Item.Priest.Discipline = MergeTableByKey(Item.Priest.Commons, {
})

Item.Priest.Holy = MergeTableByKey(Item.Priest.Commons, {
})
