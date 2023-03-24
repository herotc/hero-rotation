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
if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  GiftoftheNaaru                        = Spell(59542),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  Consecration                          = Spell(26573),
  CrusaderStrike                        = Spell(35395),
  DivineShield                          = Spell(642),
  DivineSteed                           = Spell(190784),
  FlashofLight                          = Spell(19750),
  HammerofJustice                       = Spell(853),
  HandofReckoning                       = Spell(62124),
  Judgment                              = Spell(20271),
  Rebuke                                = Spell(96231),
  ShieldoftheRighteous                  = Spell(53600),
  WordofGlory                           = Spell(85673),
  -- Talents
  AvengingWrath                         = Spell(31884),
  HammerofWrath                         = Spell(24275),
  HolyAvenger                           = Spell(105809),
  LayonHands                            = Spell(633),
  Seraphim                              = Spell(152262),
  ZealotsParagon                        = Spell(391142),
  -- Auras
  ConcentrationAura                     = Spell(317920),
  CrusaderAura                          = Spell(32223),
  DevotionAura                          = Spell(465),
  RetributionAura                       = Spell(183435),
  -- Buffs
  AvengingWrathBuff                     = Spell(31884),
  BlessingofDuskBuff                    = Spell(385126),
  ConsecrationBuff                      = Spell(188370),
  DivinePurposeBuff                     = Spell(223819),
  HolyAvengerBuff                       = Spell(105809),
  SeraphimBuff                          = Spell(152262),
  ShieldoftheRighteousBuff              = Spell(132403),
  -- Debuffs
  ConsecrationDebuff                    = Spell(204242),
  JudgmentDebuff                        = Spell(197277),
  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Paladin.Protection = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  Judgment                              = Spell(275779),
  -- Talents
  ArdentDefender                        = Spell(31850),
  AvengersShield                        = Spell(31935),
  BastionofLight                        = Spell(378974),
  BlessedHammer                         = Spell(204019),
  CrusadersJudgment                     = Spell(204023),
  DivineToll                            = Spell(375576),
  EyeofTyr                              = Spell(387174),
  GuardianofAncientKings                = MultiSpell(86659,212641),
  HammeroftheRighteous                  = Spell(53595),
  MomentofGlory                         = Spell(327193),
  RighteousProtector                    = Spell(204074),
  Sentinel                              = MultiSpell(385438,389539),
  -- Buffs
  ArdentDefenderBuff                    = Spell(31850),
  BastionofLightBuff                    = Spell(378974),
  GuardianofAncientKingsBuff            = MultiSpell(86659,212641),
  MomentofGloryBuff                     = Spell(327193),
  ShiningLightFreeBuff                  = Spell(327510),
  -- Debuffs
})

Spell.Paladin.Retribution = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  TemplarsVerdict                       = Spell(85256),
  -- Talents
  AshestoDust                           = Spell(383300),
  BladeofJustice                        = Spell(184575),
  BladeofWrath                          = Spell(231832),
  BlessedChampion                       = Spell(403010),
  BoundlessJudgment                     = Spell(405278),
  Crusade                               = Spell(231895),
  DivineAuxiliary                       = Spell(406158),
  DivineHammer                          = Spell(198034),
  DivineResonance                       = Spell(384027),
  DivineStorm                           = Spell(53385),
  DivineToll                            = Spell(375576),
  EmpyreanLegacy                        = Spell(387170),
  EmpyreanPower                         = Spell(326732),
  ExecutionSentence                     = Spell(343527),
  ExecutionersWrath                     = Spell(387196),
  Exorcism                              = Spell(383185),
  Expurgation                           = Spell(383344),
  FinalReckoning                        = Spell(343721),
  FinalVerdict                          = Spell(383328),
  FiresofJustice                        = Spell(203316),
  HolyBlade                             = Spell(383342),
  JusticarsVengeance                    = Spell(215661),
  RadiantDecree                         = Spell(383469),
  RadiantDecreeTalent                   = Spell(384052),
  RighteousVerdict                      = Spell(267610),
  ShieldofVengeance                     = Spell(184662),
  TemplarSlash                          = Spell(406647),
  TemplarStrike                         = Spell(407480),
  VanguardsMomentum                     = Spell(383314),
  WakeofAshes                           = Spell(255937),
  Zeal                                  = Spell(269569),
  -- Buffs
  CrusadeBuff                           = Spell(231895),
  DivineArbiterBuff                     = Spell(406975),
  DivineResonanceBuff                   = Spell(384029),
  EmpyreanLegacyBuff                    = Spell(387178),
  EmpyreanPowerBuff                     = Spell(326733),
  -- Debuffs
})

Spell.Paladin.Holy = MergeTableByKey(Spell.Paladin.Commons, {
  -- Abilities
  DivineProtection                      = Spell(498),
  HolyShock                             = Spell(20473),
  Judgment                              = Spell(275773),
  LightofDawn                           = Spell(85222),
  InfusionofLightBuff                   = Spell(54149),
  -- Talents
  AvengingCrusader                      = Spell(216331),
  Awakening                             = Spell(248033),
  BestowFaith                           = Spell(223306),
  CrusadersMight                        = Spell(196926),
  GlimmerofLight                        = Spell(325966),
  GlimmerofLightDebuff                  = Spell(325966),
  HolyPrism                             = Spell(114165),
  LightsHammer                          = Spell(114158),
})

-- Items
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Commons = {
  -- Trinkets
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
}

Item.Paladin.Protection = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Retribution = MergeTableByKey(Item.Paladin.Commons, {
})

Item.Paladin.Holy = MergeTableByKey(Item.Paladin.Commons, {
})
