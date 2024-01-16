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
  Glide                                 = Spell(131347),
  ImmolationAura                        = Spell(258920),
  ImmolationAuraBuff                    = Spell(258920),
  -- Talents
  ChaosNova                             = Spell(179057),
  CollectiveAnguish                     = Spell(390152),
  Demonic                               = Spell(213410),
  ElysianDecree                         = Spell(390163),
  Felblade                              = Spell(232893),
  FirstoftheIllidari                    = Spell(235893),
  FoddertotheFlame                      = Spell(391429),
  SigilofFlame                          = MultiSpell(204596, 389810), -- 204596: Base ID, 389810: Precise
  SigilofMisery                         = MultiSpell(207684, 389813), -- 207684: Base ID, 389813: Precise
  SoulSigils                            = Spell(395446),
  TheHunt                               = Spell(370965),
  -- Utility
  Disrupt                               = Spell(183752),
  -- Buffs
  -- Debuffs
  SigilofFlameDebuff                    = Spell(204598),
  SigilofMiseryDebuff                   = Spell(207685),
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
  AscendingFlame                        = Spell(428603),
  BulkExtraction                        = Spell(320341),
  BurningAlive                          = Spell(207739),
  BurningBlood                          = Spell(390213),
  CharredFlesh                          = Spell(336639),
  ConcentratedSigils                    = Spell(207666),
  CycleofBinding                        = Spell(389718),
  DarkglareBoon                         = Spell(389708),
  DowninFlames                          = Spell(389732),
  Fallout                               = Spell(227174),
  FelDevastation                        = Spell(212084),
  FieryBrand                            = Spell(204021),
  FieryDemise                           = Spell(389220),
  FocusedCleave                         = Spell(343207),
  Frailty                               = Spell(389958),
  Fracture                              = Spell(263642),
  ShearFury                             = Spell(389997),
  SigilofChains                         = MultiSpell(202138, 389807), -- 202138: Base ID, 389807: Precise
  SigilofSilence                        = MultiSpell(202137, 389809), -- 202137: Base ID, 389809: Precise
  SoulBarrier                           = Spell(263648),
  SoulCarver                            = Spell(207407),
  Soulcrush                             = Spell(389985),
  SpiritBomb                            = Spell(247454),
  StoketheFlames                        = Spell(393827),
  Vulnerability                         = Spell(389976),
  -- Utility
  Metamorphosis                         = Spell(187827),
  -- Buffs
  DemonSpikesBuff                       = Spell(203819),
  MetamorphosisBuff                     = Spell(187827),
  RecriminationBuff                     = Spell(409877), -- Tier 30 4pc
  -- Debuffs
  FieryBrandDebuff                      = Spell(207771),
  FrailtyDebuff                         = Spell(247456),
  SigilofChainsDebuff                   = Spell(204843),
  SigilofSilenceDebuff                  = Spell(204490),
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
  AFireInside                           = Spell(427775),
  AnyMeansNecessary                     = Spell(388114),
  BlindFury                             = Spell(203550),
  BurningWound                          = Spell(391189),
  ChaosTheory                           = Spell(389687),
  ChaoticTransformation                 = Spell(388112),
  CycleofHatred                         = Spell(258887),
  DemonBlades                           = Spell(203555),
  EssenceBreak                          = Spell(258860),
  EyeBeam                               = Spell(198013),
  FelBarrage                            = Spell(258925),
  FelEruption                           = Spell(211881),
  FirstBlood                            = Spell(206416),
  FuriousGaze                           = Spell(343311),
  FuriousThrows                         = Spell(393029),
  GlaiveTempest                         = Spell(342817),
  Inertia                               = Spell(427640),
  Initiative                            = Spell(388108),
  InnerDemon                            = Spell(389693),
  IsolatedPrey                          = Spell(388113),
  Momentum                              = Spell(206476),
  Ragefire                              = Spell(388107),
  RestlessHunter                        = Spell(390142),
  SerratedGlaive                        = Spell(390154),
  ShatteredDestiny                      = Spell(388116),
  Soulrend                              = Spell(388106),
  Soulscar                              = Spell(388106),
  TacticalRetreat                       = Spell(389688),
  TrailofRuin                           = Spell(258881),
  UnboundChaos                          = Spell(347461),
  VengefulRetreat                       = Spell(198793),
  -- Buffs
  ChaosTheoryBuff                       = Spell(390195),
  FuriousGazeBuff                       = Spell(343312),
  InertiaBuff                           = Spell(427641),
  InitiativeBuff                        = Spell(391215),
  InnerDemonBuff                        = Spell(390145),
  MetamorphosisBuff                     = Spell(162264),
  MomentumBuff                          = Spell(208628),
  TacticalRetreatBuff                   = Spell(389890),
  UnboundChaosBuff                      = Spell(347462),
  -- Debuffs
  BurningWoundDebuff                    = Spell(391191),
  EssenceBreakDebuff                    = Spell(320338),
  SerratedGlaiveDebuff                  = Spell(390155),
})

-- Items
if not Item.DemonHunter then Item.DemonHunter = {} end
Item.DemonHunter.Commons = {
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  DragonfireBombDispenser               = Item(202610, {13, 14}),
  ElementiumPocketAnvil                 = Item(202617, {13, 14}),
  IrideusFragment                       = Item(193743, {13, 14}),
  ManicGrieftorch                       = Item(194308, {13, 14}),
  MarkofDargrul                         = Item(137357, {13, 14}),
  ScreamingBlackDragonscale             = Item(202612, {13, 14}),
  StormEatersBoon                       = Item(194302, {13, 14}),
  WitherbarksBranch                     = Item(109999, {13, 14}),
}

Item.DemonHunter.Vengeance = MergeTableByKey(Item.DemonHunter.Commons, {
})

Item.DemonHunter.Havoc = MergeTableByKey(Item.DemonHunter.Commons, {
})
