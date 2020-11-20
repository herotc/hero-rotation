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

-- Spell
if not Spell.Paladin then Spell.Paladin = {} end
Spell.Paladin.Protection = {
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
  ArdentDefender                        = Spell(31850),
  ArdentDefenderBuff                    = Spell(31850),
  AvengersShield                        = Spell(31935),
  AvengingWrath                         = Spell(31884),
  AvengingWrathBuff                     = Spell(31884),
  Consecration                          = Spell(26573),
  ConsecrationBuff                      = Spell(188370),
  DevotionAura                          = Spell(465),
  DevotionAuraBuff                      = Spell(465),
  DivineShield                          = Spell(642),
  DivineSteed                           = Spell(190784),
  FlashofLight                          = Spell(19750),
  GuardianofAncientKings                = Spell(86659),
  GuardianofAncientKingsBuff            = Spell(86659),
  HammerofJustice                       = Spell(853),
  HammeroftheRighteous                  = Spell(53595),
  HammerofWrath                         = Spell(24275),
  HandofReckoning                       = Spell(62124),
  Judgment                              = Spell(275779),
  JudgmentDebuff                        = Spell(197277),
  LayonHands                            = Spell(633),
  Rebuke                                = Spell(96231),
  ShieldoftheRighteous                  = Spell(53600),
  ShieldoftheRighteousBuff              = Spell(132403),
  ShiningLightFreeBuff                  = Spell(327510),
  WordofGlory                           = Spell(85673),
  
  -- Talents
  BlessedHammer                         = Spell(204019),
  CrusadersJudgment                     = Spell(204023),
  HolyAvenger                           = Spell(105809),
  HolyAvengerBuff                       = Spell(105809),
  MomentofGlory                         = Spell(327193),
  SanctifiedWrath                       = Spell(171648),
  Seraphim                              = Spell(152262),
  SeraphimBuff                          = Spell(152262),
  
  -- Covenant Abilities
  AshenHallow                           = Spell(316958),
  BlessingofAutumn                      = Spell(328622),
  BlessingofSpring                      = Spell(328282),
  BlessingofSummer                      = Spell(328620),
  BlessingofWinter                      = Spell(328281),
  DivineToll                            = Spell(304971),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  VanquishersHammer                     = Spell(328204),
  VanquishersHammerBuff                 = Spell(328204),
  
  -- Soulbind/Conduit Effects
  VengefulShock                         = Spell(340006),
  VengefulShockDebuff                   = Spell(340007),
  
  -- Trinket Effects
  
  -- Azerite Traits (BfA)
  
  -- Essences (BfA)
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
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  
  -- Pool
  Pool                                  = Spell(999910)
}

-- Items
if not Item.Paladin then Item.Paladin = {} end
Item.Paladin.Protection = {
  PotionofUnbridledFury            = Item(169299),
}