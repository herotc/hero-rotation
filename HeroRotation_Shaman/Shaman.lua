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
if not Spell.Shaman then Spell.Shaman = {} end
Spell.Shaman.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(33697),
  Fireblood                             = Spell(265221),
  -- Abilities
  Bloodlust                             = MultiSpell(2825,32182), -- Bloodlust/Heroism
  FlameShock                            = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  HealingSurge                          = Spell(8004),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),
  -- Talents
  AstralShift                           = Spell(108271),
  CapacitorTotem                        = Spell(192058),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  EarthShield                           = Spell(974),
  ElementalBlast                        = Spell(117014),
  LavaBurst                             = Spell(51505),
  DeeplyRootedElements                  = Spell(378270),
  NaturesSwiftness                      = Spell(378081),
  PrimordialWave                        = Spell(375982),
  SpiritwalkersGrace                    = Spell(79206),
  TotemicRecall                         = Spell(108285),
  WindShear                             = Spell(57994),
  -- Buffs
  LightningShieldBuff                   = Spell(192106),
  PrimordialWaveBuff                    = Spell(375986),
  SpiritwalkersGraceBuff                = Spell(79206),
  SplinteredElementsBuff                = Spell(382043),
  -- Debuffs
  FlameShockDebuff                      = Spell(188389),
  -- Trinket Effects
  AcquiredSwordBuff                     = Spell(368657),
  ScarsofFraternalStrifeBuff4           = Spell(368638),
  -- Misc
  Pool                                  = Spell(999910),
}

Spell.Shaman.Enhancement = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  Windstrike                            = Spell(115356),
  -- Talents
  Ascendance                            = Spell(114051),
  AshenCatalyst                         = Spell(390370),
  ConvergingStorms                      = Spell(384363),
  CrashLightning                        = Spell(187874),
  CrashingStorms                        = Spell(334308),
  DoomWinds                             = Spell(384352),
  ElementalAssault                      = Spell(210853),
  ElementalSpirits                      = Spell(262624),
  FeralSpirit                           = Spell(51533),
  FireNova                              = Spell(333974),
  Hailstorm                             = Spell(334195),
  HotHand                               = Spell(201900),
  IceStrike                             = Spell(342240),
  LashingFlames                         = Spell(334046),
  LavaLash                              = Spell(60103),
  MoltenAssault                         = Spell(334033),
  OverflowingMaelstrom                  = Spell(384149),
  StaticAccumulation                    = Spell(384411),
  Stormblast                            = Spell(319930),
  Stormflurry                           = Spell(344357),
  Stormstrike                           = Spell(17364),
  Sundering                             = Spell(197214),
  SwirlingMaelstrom                     = Spell(384359),
  ThorimsInvocation                     = Spell(384444),
  WindfuryTotem                         = Spell(8512),
  WindfuryWeapon                        = Spell(33757),
  -- Buffs
  AscendanceBuff                        = Spell(114051),
  AshenCatalystBuff                     = Spell(390371),
  ConvergingStormsBuff                  = Spell(198300),
  CracklingThunderBuff                  = Spell(409834),
  CrashLightningBuff                    = Spell(187878),
  CLCrashLightningBuff                  = Spell(333964),
  DoomWindsBuff                         = Spell(384352),
  FeralSpiritBuff                       = Spell(333957),
  GatheringStormsBuff                   = Spell(198300),
  HailstormBuff                         = Spell(334196),
  HotHandBuff                           = Spell(215785),
  MaelstromWeaponBuff                   = Spell(344179),
  StormbringerBuff                      = Spell(201846),
  WindfuryTotemBuff                     = Spell(327942),
  -- Debuffs
  LashingFlamesDebuff                   = Spell(334168),
  -- Elemental Spirits Buffs
  CracklingSurgeBuff                    = Spell(224127),
  EarthenWeaponBuff                     = Spell(392375),
  LegacyoftheFrostWitch                 = Spell(335901),
  IcyEdgeBuff                           = Spell(224126),
  MoltenWeaponBuff                      = Spell(224125),
  -- Tier 29 Buffs
  MaelstromofElementsBuff               = Spell(394677),
})

Spell.Shaman.Elemental = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  EarthShock                            = Spell(8042),
  Earthquake                            = Spell(61882),
  FireElemental                         = Spell(198067),
  -- Talents
  Aftershock                            = Spell(273221),
  Ascendance                            = Spell(114050),
  EarthenRage                           = Spell(170374),
  EchooftheElements                     = Spell(333919),
  EchoesofGreatSundering                = Spell(384087),
  EchoingShock                          = Spell(320125),
  EchoingShockBuff                      = Spell(320125),
  ElectrifiedShocks                     = Spell(382086),
  EyeoftheStorm                         = Spell(381708),
  FlowofPower                           = Spell(385923),
  FluxMelting                           = Spell(381776),
  Icefury                               = Spell(210714),
  IcefuryBuff                           = Spell(210714),
  LavaBeam                              = Spell(114074),
  LavaSurge                             = Spell(77756),
  LightningRod                          = Spell(210689),
  LiquidMagmaTotem                      = Spell(192222),
  MagmaChamber                          = Spell(381932),
  MasteroftheElements                   = Spell(16166),
  PrimalElementalist                    = Spell(117013),
  PrimordialSurge                       = Spell(386474),
  SearingFlames                         = Spell(381782),
  SkybreakersFieryDemise                = Spell(378310),
  StaticDischarge                       = Spell(342243),
  StormElemental                        = Spell(192249),
  Stormkeeper                           = Spell(191634),
  StormkeeperBuff                       = Spell(191634),
  SurgeofPower                          = Spell(262303),
  SwellingMaelstrom                     = Spell(384359),
  UnlimitedPower                        = Spell(260895),
  UnrelentingCalamity                   = Spell(382685),
  WindGustBuff                          = Spell(263806),
  -- Pets
  Meteor                                = Spell(117588, "pet"),
  CallLightning                         = Spell(157348, "pet"),
  CallLightningBuff                     = Spell(157348),
  -- Buffs
  AscendanceBuff                        = Spell(114050),
  EchoesofGreatSunderingBuff            = Spell(384088),
  FluxMeltingBuff                       = Spell(381777),
  LavaSurgeBuff                         = Spell(77762),
  MasteroftheElementsBuff               = Spell(260734),
  PoweroftheMaelstromBuff               = Spell(191877),
  SurgeofPowerBuff                      = Spell(285514),
  WindspeakersLavaResurgenceBuff        = Spell(378269),
  -- Debuffs
  ElectrifiedShocksDebuff               = Spell(382089),
  LightningRodDebuff                    = Spell(197209),
})

Spell.Shaman.Restoration = MergeTableByKey(Spell.Shaman.Commons, {
})

if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Commons = {
  -- Trinkets
  CacheofAcquiredTreasures              = Item(188265, {13, 14}),
  ScarsofFraternalStrife                = Item(188253, {13, 14}),
  TheFirstSigil                         = Item(188271, {13, 14}),
}
Item.Shaman.Enhancement = MergeTableByKey(Item.Shaman.Commons, {
})

Item.Shaman.Elemental = MergeTableByKey(Item.Shaman.Commons, {
})

Item.Shaman.Restoration = MergeTableByKey(Item.Shaman.Commons, {
})