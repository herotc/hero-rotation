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
  Felblade                              = Spell(232893),
  -- Utility
  Disrupt                               = Spell(183752),
  -- Covenant Abilities
  DoorofShadows                         = Spell(300728),
  ElysianDecree                         = Spell(306830),
  Fleshcraft                            = Spell(324631),
  SinfulBrand                           = Spell(317009),
  SinfulBrandDebuff                     = Spell(317009),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  TheHunt                               = Spell(323639),
  -- Legendary Effects
  BlindFaithBuff                        = Spell(355894),
  ChaosTheoryBuff                       = Spell(337567),
  FelBombardmentBuff                    = Spell(337849),
  BurningWoundDebuff                    = Spell(346278),
  -- Soulbind/Conduit Effects
  EnduringGloom                         = Spell(319978),
  ExposedWoundDebuff                    = Spell(339229), -- Triggered by Serrated Glaive
  PustuleEruption                       = Spell(351094),
  SerratedGlaive                        = Spell(339230),
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
  FelDevastation                        = Spell(212084),
  Frailty                               = Spell(247456),
  InfernalStrike                        = Spell(189110),
  Shear                                 = Spell(203782),
  SigilofFlame                          = MultiSpell(204596, 204513),
  SigilofFlameDebuff                    = Spell(204598),
  SoulCleave                            = Spell(228477),
  SoulFragments                         = Spell(203981),
  ThrowGlaive                           = Spell(204157),
  -- Defensive
  DemonSpikes                           = Spell(203720),
  DemonSpikesBuff                       = Spell(203819),
  FieryBrand                            = Spell(204021),
  FieryBrandDebuff                      = Spell(207771),
  Torment                               = Spell(185245),
  -- Talents
  AgonizingFlames                       = Spell(207548),
  BulkExtraction                        = Spell(320341),
  BurningAlive                          = Spell(207739),
  CharredFlesh                          = Spell(336639),
  ConcentratedSigils                    = Spell(207666),
  Demonic                               = Spell(321453),
  Fallout                               = Spell(227174),
  Fracture                              = Spell(263642),
  SoulBarrier                           = Spell(263648),
  SpiritBomb                            = Spell(247454),
  SpiritBombDebuff                      = Spell(247456),
  -- Utility
  Metamorphosis                         = Spell(187827),
  MetamorphosisBuff                     = Spell(187827)
})

Spell.DemonHunter.Havoc = MergeTableByKey(Spell.DemonHunter.Commons, {
  -- Abilities
  Annihilation                          = Spell(201427),
  BladeDance                            = Spell(188499),
  ChaosNova                             = Spell(179057),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  DemonsBite                            = Spell(162243),
  EyeBeam                               = Spell(198013),
  FelRush                               = Spell(195072),
  FuriousGazeBuff                       = Spell(343312),
  Metamorphosis                         = Spell(191427),
  MetamorphosisBuff                     = Spell(162264),
  ThrowGlaive                           = Spell(185123),
  VengefulRetreat                       = Spell(198793),
  Blur                                  = Spell(198589),
  -- Talents
  BlindFury                             = Spell(203550),
  CycleofHatred                         = Spell(258887),
  DemonBlades                           = Spell(203555),
  Demonic                               = Spell(213410),
  EssenceBreak                          = Spell(258860),
  EssenceBreakDebuff                    = Spell(320338),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  FirstBlood                            = Spell(206416),
  GlaiveTempest                         = Spell(342817),
  Momentum                              = Spell(206476),
  MomentumBuff                          = Spell(208628),
  PreparedBuff                          = Spell(203650), -- Procs from Vengeful Retreat with Momentum
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(347461),
  UnboundChaosBuff                      = Spell(347462)
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
