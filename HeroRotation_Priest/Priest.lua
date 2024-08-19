--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC                   = HeroDBC.DBC
-- HeroLib
local HL                    = HeroLib
local Cache                 = HeroCache
local Unit                  = HL.Unit
local Player                = Unit.Player
local Target                = Unit.Target
local Pet                   = Unit.Pet
local Spell                 = HL.Spell
local MultiSpell            = HL.MultiSpell
local Item                  = HL.Item
local MergeTableByKey       = HL.Utils.MergeTableByKey
-- HeroRotation
local HR                    = HeroRotation

--- ============================ CONTENT ============================

-- Spells
if not Spell.Priest then Spell.Priest = {} end
Spell.Priest.Commons = {
  -- Racials
  AncestralCall               = Spell(274738),
  ArcanePulse                 = Spell(260364),
  ArcaneTorrent               = Spell(50613),
  BagofTricks                 = Spell(312411),
  Berserking                  = Spell(26297),
  BerserkingBuff              = Spell(26297),
  BloodFury                   = Spell(20572),
  BloodFuryBuff               = Spell(20572),
  Fireblood                   = Spell(265221),
  LightsJudgment              = Spell(255647),
  -- Abilities
  DeathAndMadness             = Spell(321291),
  DesperatePrayer             = Spell(19236),
  DivineStar                  = Spell(122121),
  HolyNova                    = Spell(132157), -- Melee, 12
  MindBlast                   = Spell(8092),
  MindSear                    = Spell(48045), -- Splash, 10
  PowerInfusion               = Spell(10060),
  PowerWordFortitude          = Spell(21562),
  PowerWordShield             = Spell(17),
  ShadowWordDeath             = Spell(32379),
  ShadowWordPain              = Spell(589),
  ShadowWordPainDebuff        = Spell(589),
  FlashHeal                   = Spell(2061),
  Smite                       = Spell(585),
  Renew                       = Spell(139),
  -- Talents
  Mindgames                   = Spell(375901),
  Manipulation                = Spell(390996),
  Shadowfiend                 = Spell(34433),
  CrystallineReflection       = Spell(373457),
  Rhapsody                    = Spell(390622),
  PowerWordLife               = Spell(373481),
  TwistofFate                 = Spell(390972),
  -- Buffs
  AberrantSpellforgeBuff      = Spell(451895),
  PowerWordFortitudeBuff      = Spell(21562),
  RhapsodyBuff                = Spell(390636),
  SpymastersReportBuff        = Spell(451199), -- Stacking buff from before using Spymaster's Web trinket
  SpymastersWebBuff           = Spell(444959), -- Buff from using Spymaster's Web trinket
  TwistofFateBuff             = Spell(390978),
  -- Debuffs
  -- Other
  Pool                        = Spell(999910)
}

Spell.Priest.Archon = {
  -- Talents
  EmpoweredSurges             = Spell(453799),
}

Spell.Priest.Voidweaver = {
  -- Talents
  DepthofShadows              = Spell(451308),
  EntropicRift                = Spell(447444),
  VoidBlast                   = Spell(450405),
  VoidEmpowerment             = Spell(450138),
}

Spell.Priest.Shadow = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  MindFlay                    = Spell(15407),
  Shadowform                  = Spell(232698),
  VampiricTouch               = Spell(34914),
  VoidBolt                    = Spell(205448),
  VoidEruption                = Spell(228260), -- Splash, 10
  -- Talents
  DarkAscension               = Spell(391109),
  DevouringPlague             = Spell(335467),
  Dispersion                  = Spell(47585),
  DistortedReality            = Spell(409044),
  DivineStar                  = Spell(122121),
  Halo                        = Spell(120644),
  InescapableTorment          = Spell(373427),
  InsidiousIre                = Spell(373212),
  Mindbender                  = Spell(200174),
  MindDevourer                = Spell(373202),
  MindFlayInsanity            = Spell(391403),
  MindMelt                    = Spell(391090),
  MindSpike                   = Spell(73510),
  MindSpikeInsanity           = Spell(407466),
  Misery                      = Spell(238558),
  PsychicLink                 = Spell(199484),
  ShadowCrash                 = Spell(205385), -- Splash, 8
  ShadowCrashTarget           = Spell(457042),
  Silence                     = Spell(15487),
  UnfurlingDarkness           = Spell(341273),
  VoidTorrent                 = Spell(263165),
  Voidtouched                 = Spell(407430),
  WhisperingShadows           = Spell(406777),
  -- Buffs
  DarkAscensionBuff           = Spell(391109),
  DarkEvangelismBuff          = Spell(391099),
  DeathspeakerBuff            = Spell(392511),
  DevouredFearBuff            = Spell(373319), -- Idol of Y'Shaarj buff
  DevouredPrideBuff           = Spell(373316), -- Idol of Y'Shaarj buff
  MindDevourerBuff            = Spell(373204),
  MindFlayInsanityBuff        = Spell(391401),
  MindSpikeInsanityBuff       = Spell(407468),
  ShadowformBuff              = Spell(232698),
  UnfurlingDarknessBuff       = Spell(341282),
  VoidformBuff                = Spell(194249),
  -- Debuffs
  DevouringPlagueDebuff       = Spell(335467),
  VampiricTouchDebuff         = Spell(34914),
})
Spell.Priest.Shadow = MergeTableByKey(Spell.Priest.Shadow, Spell.Priest.Archon)
Spell.Priest.Shadow = MergeTableByKey(Spell.Priest.Shadow, Spell.Priest.Voidweaver)

Spell.Priest.Discipline = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  Penance                     = Spell(47540),
  PowerWordRadiance           = Spell(194509),
  -- Talents
  DivineStar                  = Spell(110744),
  Schism                      = Spell(214621),
  Mindbender                  = MultiSpell(123040, 34433),
  PowerWordSolace             = Spell(129250),
  ShadowCovenant              = Spell(314867),
  ShadowCovenantBuff          = Spell(322105),
  PurgeTheWicked              = Spell(204197),
  PurgeTheWickedDebuff        = Spell(204213),
  Halo                        = Spell(120517),
  SpiritShell                 = Spell(109964),
  -- Covenant Abilities
  AscendedBlast               = Spell(325315),
})

Spell.Priest.Holy = MergeTableByKey(Spell.Priest.Commons, {
  -- Base Spells
  HolyFire                    = Spell(14914),
  HolyFireDebuff              = Spell(14914),
  HolyWordChastise            = Spell(88625),
  -- Talents
  Apotheosis                  = Spell(200183),
  DivineStar                  = Spell(110744),
  Halo                        = Spell(120517),
})

-- Items
if not Item.Priest then Item.Priest = {} end
Item.Priest.Commons = {
  -- Trinkets
  AberrantSpellforge          = Item(212451, {13, 14}),
  BeacontotheBeyond           = Item(203963, {13, 14}),
  BelorrelostheSuncaller      = Item(207172, {13, 14}),
  ConjuredChillglobe          = Item(194300, {13, 14}),
  DesperateInvokersCodex      = Item(194310, {13, 14}),
  DMDDance                    = Item(198088, {13, 14}),
  DMDDanceBox                 = Item(198478, {13, 14}),
  DMDInferno                  = Item(198086, {13, 14}),
  DMDInfernoBox               = Item(194872, {13, 14}),
  DMDRime                     = Item(198087, {13, 14}),
  DMDRimeBox                  = Item(198477, {13, 14}),
  EruptingSpearFragment       = Item(193769, {13, 14}),
  IcebloodDeathsnare          = Item(194304, {13, 14}),
  NymuesUnravelingSpindle     = Item(208615, {13, 14}),
  RashoksMoltenHeart          = Item(202614, {13, 14}),
  SpymastersWeb               = Item(220202, {13, 14}),
  VoidmendersShadowgem        = Item(110007, {13, 14}),
  -- Other Items
  Dreambinder                 = Item(208616, {16}),
}

Item.Priest.Shadow = MergeTableByKey(Item.Priest.Commons, {
})

Item.Priest.Discipline = MergeTableByKey(Item.Priest.Commons, {
})

Item.Priest.Holy = MergeTableByKey(Item.Priest.Commons, {
})
