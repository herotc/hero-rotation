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

-- Spell
if not Spell.DemonHunter then Spell.DemonHunter = {} end
Spell.DemonHunter.Commons = {
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  -- Abilities
  ImmolationAura                        = Spell(258920),
  ImmolationAuraBuff                    = Spell(258920),
  -- Talents
  ChaosNova                             = Spell(179057),
  Demonic                               = Spell(213410),
  ElysianDecree                         = Spell(390163),
  Felblade                              = Spell(232893),
  FoddertotheFlame                      = Spell(391429),
  SigilofFlame                          = Spell(204596),
  TheHunt                               = Spell(370965),
  -- Utility
  Disrupt                               = Spell(183752),
  -- Buffs
  -- Debuffs
  SigilofFlameDebuff                    = Spell(204598),
  -- Covenant Abilities
  DoorofShadows                         = Spell(300728),
  ElysianDecreeCov                      = Spell(306830),
  Fleshcraft                            = Spell(324631),
  SinfulBrand                           = Spell(317009),
  SinfulBrandDebuff                     = Spell(317009),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  TheHuntCov                            = Spell(323639),
  -- Legendary Effects
  BlindFaithBuff                        = Spell(355894),
  ChaosTheoryLegBuff                    = Spell(337567),
  FelBombardmentBuff                    = Spell(337849),
  BurningWoundLegDebuff                    = Spell(346278),
  -- Soulbind/Conduit Effects
  EnduringGloom                         = Spell(319978),
  ExposedWoundDebuff                    = Spell(339229), -- Triggered by Serrated Glaive
  PustuleEruption                       = Spell(351094),
  SerratedGlaiveConduit                 = Spell(339230),
  VolatileSolvent                       = Spell(323074),
  VolatileSolventHumanBuff              = Spell(323491),
  -- Trinket Effects
  AcquiredAxeBuff                       = Spell(368656),
  AcquiredSwordBuff                     = Spell(368657),
  AcquiredWandBuff                      = Spell(368654),
  -- Other Item Effects
  TemptationBuff                        = Spell(234143),
  -- Other
  Pool                                  = Spell(999910)
}

Spell.DemonHunter.Vengeance = MergeTableByKey(Spell.DemonHunter.Commons, {
  -- Abilities
  InfernalStrike                        = Spell(189110),
  Shear                                 = Spell(203782),
  SoulCleave                            = Spell(228477),
  SoulFragments                         = Spell(203981),
  ThrowGlaive                           = Spell(204157),
  -- Defensive
  DemonSpikes                           = Spell(203720),
  Torment                               = Spell(185245),
  -- Talents
  AgonizingFlames                       = Spell(207548),
  BulkExtraction                        = Spell(320341),
  BurningAlive                          = Spell(207739),
  CharredFlesh                          = Spell(336639),
  ConcentratedSigils                    = Spell(207666),
  Fallout                               = Spell(227174),
  FelDevastation                        = Spell(212084),
  FieryBrand                            = Spell(204021),
  Frailty                               = Spell(389958),
  Fracture                              = Spell(263642),
  SoulBarrier                           = Spell(263648),
  SoulCarver                            = Spell(207407),
  SpiritBomb                            = Spell(247454),
  -- Utility
  Metamorphosis                         = Spell(187827),
  -- Buffs
  DemonSpikesBuff                       = Spell(203819),
  MetamorphosisBuff                     = Spell(187827),
  -- Debuffs
  FieryBrandDebuff                      = Spell(207771),
  FrailtyDebuff                         = Spell(247456),
})

Spell.DemonHunter.Havoc = MergeTableByKey(Spell.DemonHunter.Commons, {
  -- Abilities
  Annihilation                          = Spell(201427),
  BladeDance                            = Spell(188499),
  Blur                                  = Spell(198589),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  DemonsBite                            = Spell(162243),
  FelRush                               = Spell(195072),
  Metamorphosis                         = Spell(191427),
  ThrowGlaive                           = Spell(185123),
  -- Talents
  BlindFury                             = Spell(203550),
  BurningWound                          = Spell(391189),
  ChaosTheory                           = Spell(389687),
  CycleofHatred                         = Spell(258887),
  DemonBlades                           = Spell(203555),
  EssenceBreak                          = Spell(258860),
  EyeBeam                               = Spell(198013),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  FirstBlood                            = Spell(206416),
  FuriousGaze                           = Spell(343311),
  GlaiveTempest                         = Spell(342817),
  Momentum                              = Spell(206476),
  Ragefire                              = Spell(388107),
  SerratedGlaive                        = Spell(390154),
  Soulrend                              = Spell(388106),
  TacticalRetreat                       = Spell(389688),
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(347461),
  VengefulRetreat                       = Spell(198793),
  -- Buffs
  ChaosTheoryBuff                       = Spell(390195),
  FuriousGazeBuff                       = Spell(343312),
  MetamorphosisBuff                     = Spell(162264),
  MomentumBuff                          = Spell(208628),
  TacticalRetreatBuff                   = Spell(389890),
  UnboundChaosBuff                      = Spell(347462),
  -- Debuffs
  BurningWoundDebuff                    = Spell(391191),
  EssenceBreakDebuff                    = Spell(320338),
})

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Commons = {
  -- Potions
  PotionofPhantomFire              = Item(171349),
  -- Trinkets
  CacheofAcquiredTreasures         = Item(188265, {13, 14}),
  PulsatingStoneheart              = Item(178825, {13, 14}),
  DarkmoonDeckIndomitable          = Item(173096, {13, 14}),
  -- Other On-Use Items
  RingofCollapsingFutures          = Item(142173, {11, 12}),
  WrapsofElectrostaticPotential    = Item(169069),
}

Item.DemonHunter.Vengeance = MergeTableByKey(Item.DemonHunter.Commons, {
})

Item.DemonHunter.Havoc = MergeTableByKey(Item.DemonHunter.Commons, {
})
