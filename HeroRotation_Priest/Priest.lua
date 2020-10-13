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
  -- Azerite Traits
  ChorusofInsanity                      = Spell(278661),
  DeathThroes                           = Spell(278659),
  HarvestedThoughtsBuff                 = Spell(288343),
  SearingDialogue                       = Spell(272788),
  SpitefulApparitions                   = Spell(277682),
  ThoughtHarvester                      = Spell(288340),
  WhispersoftheDamned                   = Spell(275722),

  -- Base Spells
  DarkThoughtsBuff                      = Spell(341207),
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
  VoidBolt                              = MultiSpell(205448,343355),
  VoidEruption                          = Spell(228260), -- Splash, 10
  VoidformBuff                          = Spell(194249),

  -- Talents
  Damnation                             = Spell(341374),
  FortressOfTheMind                     = Spell(193195),
  HungeringVoid                         = Spell(345218),
  Misery                                = Spell(238558),
  PsychicLink                           = Spell(199484),
  SearingNightmare                      = Spell(341385), -- Splash, 10
  ShadowCrash                           = Spell(205385), -- Splash, 8
  SurrenderToMadness                    = Spell(319952),
  TwistofFate                           = Spell(109142),
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

  -- Conduit Effects
  DissonantEchoes                       = Spell(338342),
  DissonantEchoesBuff                   = Spell(343144),

  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),

  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186)
}

-- Items
if not Item.Priest then Item.Priest = {} end
Item.Priest.Shadow = {
  PotionofDeathlyFixation          = Item(171351),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  CalltotheVoidGloves              = Item(173244),
  CalltotheVoidWrists              = Item(173249),
  PainbreakerPsalmChest            = Item(173241),
  PainbreakerPsalmCloak            = Item(173242),
  ShadowflamePrismGloves           = Item(173244),
  ShadowflamePrismHelm             = Item(173245),
  SunPriestessHelm                 = Item(173245),
  SunPriestessShoulders            = Item(173247),
  SephuzNeck                       = Item(178927),
  SephuzShoulders                  = Item(173247),
  SephuzChest                      = Item(173241),
}
