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
-- File Locals
--local Commons    = {}

--- ======= GLOBALIZE =======
--HR.Commons.Monk = Commons

--- ============================ CONTENT ============================

-- Spell
if not Spell.Monk then Spell.Monk = {}; end
Spell.Monk.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(25046),
  AzeriteSurge                          = Spell(436344),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  GiftoftheNaaru                        = Spell(59547),
  Haymaker                              = Spell(287712),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  QuakingPalm                           = Spell(107079),
  RocketBarrage                         = Spell(69041),
  Shadowmeld                            = Spell(58984),
  -- Abilities
  CracklingJadeLightning                = Spell(117952),
  ExpelHarm                             = Spell(322101),
  LegSweep                              = Spell(119381),
  Provoke                               = Spell(115546),
  Resuscitate                           = Spell(115178),
  RisingSunKick                         = Spell(107428),
  Roll                                  = Spell(109132),
  TigerPalm                             = Spell(100780),
  TouchofDeath                          = Spell(322109),
  Transcendence                         = Spell(101643),
  TranscendenceTransfer                 = Spell(119996),
  Vivify                                = Spell(116670),
  -- Talents
  BonedustBrew                          = Spell(386276),
  Celerity                              = Spell(115173),
  ChiBurst                              = Spell(123986),
  ChiTorpedo                            = Spell(115008),
  ChiWave                               = Spell(115098),
  DampenHarm                            = Spell(122278),
  Detox                                 = Spell(218164),
  Disable                               = Spell(116095),
  DiffuseMagic                          = Spell(122783),
  EyeoftheTiger                         = Spell(196607),
  FastFeet                              = Spell(388809),
  ImpTouchofDeath                       = Spell(322113),
  InnerStrengthBuff                     = Spell(261769),
  Paralysis                             = Spell(115078),
  RingofPeace                           = Spell(116844),
  RushingJadeWind                       = Spell(116847),
  SpearHandStrike                       = Spell(116705),
  StrengthofSpirit                      = Spell(387276),
  SummonWhiteTigerStatue                = Spell(388686),
  TigerTailSweep                        = Spell(264348),
  TigersLust                            = Spell(116841),
  -- Buffs
  BonedustBrewBuff                      = Spell(386276),
  BonedustBrewDebuff                    = Spell(386276),
  DampenHarmBuff                        = Spell(122278),
  PressurePointBuff                     = Spell(393053),
  RushingJadeWindBuff                   = Spell(116847),
  -- Debuffs
  -- Item Effects
  CalltoDominanceBuff                   = Spell(403380), -- Neltharion trinket buff
  DomineeringArroganceBuff              = Spell(411661), -- Neltharion trinket buff2
  TheEmperorsCapacitorBuff              = Spell(235054),
  -- Misc
  PoolEnergy                            = Spell(999910),
  StopFoF                               = Spell(363653)
}

Spell.Monk.ConduitoftheCelestials = {
  -- Talents
  CelestialConduit                      = Spell(443028),
  -- Buffs
  HeartoftheJadeSerpentBuff             = Spell(456368),
  HeartoftheJadeSerpentCDRBuff          = Spell(443421),
  HeartoftheJadeSerpentCDRCelestialBuff = Spell(443616),
}

Spell.Monk.MasterofHarmony = {
}

Spell.Monk.ShadoPan = {
  -- Talents
  FlurryStrikes                         = Spell(450615),
  WisdomoftheWall                       = Spell(450994),
  -- Buffs
  WisdomoftheWallFlurryBuff             = Spell(452688),
}

Spell.Monk.Windwalker = MergeTableByKey(Spell.Monk.Commons, {
  -- Abilities
  BlackoutKick                          = Spell(100784),
  FlyingSerpentKick                     = Spell(101545),
  FlyingSerpentKickLand                 = Spell(115057),
  SpinningCraneKick                     = Spell(101546),
  -- Talents
  CourageousImpulse                     = Spell(451495),
  CraneVortex                           = Spell(388848),
  EnergyBurst                           = Spell(451498),
  GaleForce                             = Spell(451580),
  JadefireHarmony                       = Spell(391412),
  JadefireStomp                         = Spell(388193),
  FistsofFury                           = Spell(113656),
  GloryoftheDawn                        = Spell(392958),
  HitCombo                              = Spell(196740),
  InnerPeace                            = Spell(397768),
  InvokeXuenTheWhiteTiger               = Spell(123904),
  KnowledgeoftheBrokenTemple            = Spell(451529),
  MemoryoftheMonastery                  = Spell(454969),
  OrderedElements                       = Spell(451463),
  RevolvingWhirl                        = Spell(451524),
  SequencedStrikes                      = Spell(451515),
  ShadowboxingTreads                    = Spell(392982),
  SingularlyFocusedJade                 = Spell(451573),
  SlicingWinds                          = Spell(1217413),
  SlicingWindsDamage                    = Spell(1217411),
  StormEarthAndFire                     = Spell(137639),
  StormEarthAndFireFixate               = Spell(221771),
  StrikeoftheWindlord                   = Spell(392983),
  TeachingsoftheMonastery               = Spell(116645),
  WhirlingDragonPunch                   = Spell(152175),
  XuensBattlegear                       = Spell(392993),
  XuensBond                             = Spell(392986),
  -- Defensive
  FortifyingBrew                        = Spell(243435),
  TouchofKarma                          = Spell(122470),
  -- Buffs
  BlackoutKickBuff                      = Spell(116768),
  ChiEnergyBuff                         = Spell(393057),
  DanceofChijiBuff                      = Spell(325202),
  HiddenMastersForbiddenTouchBuff       = Spell(213114),
  InvokersDelightBuff                   = Spell(388663),
  MemoryoftheMonasteryBuff              = Spell(454970),
  OrderedElementsBuff                   = Spell(451462),
  StormEarthAndFireBuff                 = Spell(137639),
  TeachingsoftheMonasteryBuff           = Spell(202090),
  -- Debuffs
  AcclamationDebuff                     = Spell(451433),
  MarkoftheCraneDebuff                  = Spell(228287),
  -- Tier 31 Effects
  BlackoutReinforcementBuff             = Spell(424454),
  -- TWW2 Effects
  CashoutBuff                           = Spell(1216498), -- TWW2 4pc
})
Spell.Monk.Windwalker = MergeTableByKey(Spell.Monk.Windwalker, Spell.Monk.ConduitoftheCelestials)
Spell.Monk.Windwalker = MergeTableByKey(Spell.Monk.Windwalker, Spell.Monk.ShadoPan)

Spell.Monk.Brewmaster = MergeTableByKey(Spell.Monk.Commons, {
  -- Abilities
  BlackoutKick                          = Spell(205523),
  Clash                                 = Spell(324312),
  SpinningCraneKick                     = Spell(322729),
  -- Talents
  BlackoutCombo                         = Spell(196736),
  BlackOxBrew                           = Spell(115399),
  BreathofFire                          = Spell(115181),
  BobandWeave                           = Spell(280515),
  CelestialFlames                       = Spell(325177),
  CharredPassions                       = Spell(386965),
  ExplodingKeg                          = Spell(325153),
  FluidityofMotion                      = Spell(387230),
  HighTolerance                         = Spell(196737),
  ImprovedInvokeNiuzao                  = Spell(322740),
  ImprovedPurifyingBrew                 = Spell(343743),
  InvokeNiuzao                          = Spell(132578),
  KegSmash                              = Spell(121253),
  LightBrewing                          = Spell(325093),
  PresstheAdvantage                     = Spell(418359),
  ScaldingBrew                          = Spell(383698),
  Shuffle                               = Spell(322120),
  SpecialDelivery                       = Spell(196730),
  SummonBlackOxStatue                   = Spell(115315),
  WeaponsofOrder                        = Spell(387184),
  -- Defensive
  CelestialBrew                         = Spell(322507),
  FortifyingBrew                        = Spell(115203),
  PurifyingBrew                         = Spell(119582),
  -- Buffs
  BlackoutComboBuff                     = Spell(228563),
  CharredPassionsBuff                   = Spell(386963),
  ElusiveBrawlerBuff                    = Spell(195630),
  FortifyingBrewBuff                    = Spell(120954),
  PresstheAdvantageBuff                 = Spell(418361),
  WeaponsofOrderBuff                    = Spell(387184),
  -- Debuffs
  BreathofFireDotDebuff                 = Spell(123725),
  WeaponsofOrderDebuff                  = Spell(387179),
  -- Stagger Levels
  HeavyStagger                          = Spell(124273),
  ModerateStagger                       = Spell(124274),
  LightStagger                          = Spell(124275),
  -- TWW2 Effects
  OpportunisticStrikeBuff               = Spell(1217999), -- TWW2 4pc
})
Spell.Monk.Brewmaster = MergeTableByKey(Spell.Monk.Brewmaster, Spell.Monk.MasterofHarmony)
Spell.Monk.Brewmaster = MergeTableByKey(Spell.Monk.Brewmaster, Spell.Monk.ShadoPan)

-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Commons = {
}

Item.Monk.Windwalker = MergeTableByKey(Item.Monk.Commons, {
  -- DF Trinkets
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  DragonfireBombDispenser               = Item(202610, {14, 14}),
  EruptingSpearFragment                 = Item(193769, {13, 14}),
  ManicGrieftorch                       = Item(194308, {13, 14}),
  -- TWW Trinkets
  ImperfectAscendancySerum              = Item(225654, {13, 14}),
  MadQueensMandate                      = Item(212454, {13, 14}),
  TreacherousTransmitter                = Item(221023, {13, 14}),
  -- Other On-Use Items
  Djaruun                               = Item(202569, {16}),
})

Item.Monk.Brewmaster = MergeTableByKey(Item.Monk.Commons, {
})
