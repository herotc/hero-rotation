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
if not Spell.DemonHunter then Spell.DemonHunter = {} end
Spell.DemonHunter.Vengeance = {
  -- Abilities
  FelDevastation                        = Spell(212084),
  Frailty                               = Spell(247456),
  ImmolationAura                        = Spell(258920),
  ImmolationAuraBuff                    = Spell(258920),
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
  Felblade                              = Spell(232893),
  Fracture                              = Spell(263642),
  SoulBarrier                           = Spell(263648),
  SpiritBomb                            = Spell(247454),
  SpiritBombDebuff                      = Spell(247456),

  -- Utility
  Disrupt                               = Spell(183752),
  Metamorphosis                         = Spell(187827),
  MetamorphosisBuff                     = Spell(187827),

  -- Covenant Abilities
  DoorofShadows                         = Spell(300728),
  ElysianDecree                         = Spell(306830),
  Fleshcraft                            = Spell(324631),
  FoddertotheFlame                      = Spell(329554),
  SinfulBrand                           = Spell(317009),
  SinfulBrandDebuff                     = Spell(317009),
  Soulshape                             = Spell(310143),
  SummonSteward                         = Spell(324739),
  TheHunt                               = Spell(323639),

  -- Legendary Effects
  FelBombardmentBuff                    = Spell(337849),

  -- Soulbind/Conduit Effects
  EnduringGloom                         = Spell(319978),

  -- Other
  Pool                                  = Spell(999910)
}

Spell.DemonHunter.Havoc = {
  -- Racials

  -- Abilities
  Annihilation                          = Spell(201427),
  BladeDance                            = Spell(188499),
  ChaosNova                             = Spell(179057),
  ChaosStrike                           = Spell(162794),
  DeathSweep                            = Spell(210152),
  DemonsBite                            = Spell(162243),
  Disrupt                               = Spell(183752),
  EyeBeam                               = Spell(198013),
  FelRush                               = Spell(195072),
  FuriousGazeBuff                       = Spell(343312),
  ImmolationAura                        = Spell(258920),
  ImmolationAuraBuff                    = Spell(258920),
  Metamorphosis                         = Spell(191427),
  MetamorphosisBuff                     = Spell(162264),
  ThrowGlaive                           = Spell(185123),
  VengefulRetreat                       = Spell(198793),

  -- Talents
  BlindFury                             = Spell(203550),
  DemonBlades                           = Spell(203555),
  Demonic                               = Spell(213410),
  EssenceBreak                          = Spell(258860),
  EssenceBreakDebuff                    = Spell(320338),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  Felblade                              = Spell(232893),
  FirstBlood                            = Spell(206416),
  GlaiveTempest                         = Spell(342817),
  Momentum                              = Spell(206476),
  MomentumBuff                          = Spell(208628),
  PreparedBuff                          = Spell(203650), -- Procs from Vengeful Retreat with Momentum
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(275144),
  UnboundChaosBuff                      = Spell(337313),

  -- Covenant Abilities
  ElysianDecree                         = Spell(306830),
  FoddertotheFlame                      = Spell(329554),
  SinfulBrand                           = Spell(317009),
  SinfulBrandDebuff                     = Spell(317009),
  TheHunt                               = Spell(323639),

  -- Legendary Effects
  ChaosTheoryBuff                       = Spell(337567),
  FelBombardmentBuff                    = Spell(337849),
  BurningWoundDebuff                    = Spell(346278),

  -- Conduits
  ExposedWoundDebuff                    = Spell(339229), -- Triggered by Serrated Glaive
  SerratedGlaive                        = Spell(339230)
}

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Vengeance = {
  PotionofPhantomFire              = Item(171349),
}

Item.DemonHunter.Havoc = {
  PotionofPhantomFire              = Item(171349),
}
