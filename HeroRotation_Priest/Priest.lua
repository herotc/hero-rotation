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
  -- Abilities
  VoidWraithAbility           = Spell(451235),
  -- Talents
  DepthofShadows              = Spell(451308),
  DevourMatter                = Spell(451840),
  EntropicRift                = Spell(447444),
  InnerQuietus                = Spell(448278),
  VoidBlast                   = Spell(450405),
  VoidEmpowerment             = Spell(450138),
  VoidWraith                  = Spell(451234),
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
  Deathspeaker                = Spell(392507),
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
  MindsEye                    = Spell(407470),
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
  MindMeltBuff                = Spell(391092),
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

-- Items
if not Item.Priest then Item.Priest = {} end
Item.Priest.Shadow = {
  -- TWW Trinkets
  AberrantSpellforge          = Item(212451, {13, 14}),
  SpymastersWeb               = Item(220202, {13, 14}),
}
