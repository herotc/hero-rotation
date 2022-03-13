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
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlameShock                            = Spell(188389),
  FlameShockDebuff                      = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LavaBurst                             = Spell(51505),
  LavaSurgeBuff                         = Spell(77762),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),
  LightningShieldBuff                   = Spell(192106),
  WindShear                             = Spell(57994),
  -- Talents
  EarthShield                           = Spell(974),
  ElementalBlast                        = Spell(117014),
  -- Defensive
  AstralShift                           = Spell(10871),
  -- Utility
  CapacitorTotem                        = Spell(192058),
  SpiritwalkersGrace                    = Spell(79206),
  SpiritwalkersGraceBuff                = Spell(79206),
  -- Covenant Abilities (Shadowlands)
  ChainHarvest                          = Spell(320674),
  FaeTransfusion                        = Spell(328923),
  Fleshcraft                            = Spell(324631),
  PrimordialWave                        = Spell(326059),
  PrimordialWaveBuff                    = Spell(327164),
  VesperTotem                           = Spell(324386),
  -- Soulbind Abilities (Shadowlands)
  FieldofBlossoms                       = Spell(319191),
  GroveInvigoration                     = Spell(322721),
  PustuleEruption                       = Spell(351094),
  VolatileSolvent                       = Spell(323074),
  -- Trinket Effects
  AcquiredSwordBuff                     = Spell(368657),
  ScarsofFraternalStrifeBuff4           = Spell(368638),
  -- Misc
  Pool                                  = Spell(999910),
}

Spell.Shaman.Enhancement = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  CrashLightning                        = Spell(187874),
  CrashLightningBuff                    = Spell(187878),
  FeralSpirit                           = Spell(51533),
  LavaLash                              = Spell(60103),
  StormbringerBuff                      = Spell(201846),
  Stormstrike                           = Spell(17364),
  Windstrike                            = Spell(115356),
  WindfuryTotem                         = Spell(8512),
  WindfuryTotemBuff                     = Spell(327942),
  WindfuryWeapon                        = Spell(33757),
  MaelstromWeaponBuff                   = Spell(344179),
  -- Talents
  Ascendance                            = Spell(114051),
  AscendanceBuff                        = Spell(114051),
  CrashingStorm                         = Spell(192246),
  EarthenSpike                          = Spell(188089),
  ElementalSpirits                      = Spell(262624),
  FireNova                              = Spell(333974),
  ForcefulWinds                         = Spell(262647),
  Hailstorm                             = Spell(334195),
  HailstormBuff                         = Spell(334196),
  HotHand                               = Spell(201900),
  HotHandBuff                           = Spell(215785),
  IceStrike                             = Spell(342240),
  LashingFlames                         = Spell(334046),
  LashingFlamesDebuff                   = Spell(334168),
  Sundering                             = Spell(197214),
  Stormflurry                           = Spell(344357),
  Stormkeeper                           = Spell(320137),
  StormkeeperBuff                       = Spell(320137),
  -- Elemental Spirits Buffs
  CracklingSurgeBuff                    = Spell(224127),
  IcyEdgeBuff                           = Spell(224126),
  MoltenWeaponBuff                      = Spell(224125),
  -- Legendaries (Shadowlands)
  DoomWindsBuff                         = Spell(335903),
  DoomWindsDebuff                       = Spell(335904),
  PrimalLavaActuatorsBuff               = Spell(335896),
})

Spell.Shaman.Elemental = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  EarthShock                            = Spell(8042),
  Earthquake                            = Spell(61882),
  FireElemental                         = Spell(198067),
  -- Talents
  Aftershock                            = Spell(273221),
  Ascendance                            = Spell(114050),
  AscendanceBuff                        = Spell(114050),
  EarthenRage                           = Spell(170374),
  EchoOfTheElements                     = Spell(333919),
  EchoingShock                          = Spell(320125),
  EchoingShockBuff                      = Spell(320125),
  Icefury                               = Spell(210714),
  IcefuryBuff                           = Spell(210714),
  LavaBeam                              = Spell(114074),
  LiquidMagmaTotem                      = Spell(192222),
  MasterOfTheElements                   = Spell(16166),
  MasterOfTheElementsBuff               = Spell(260734),
  PrimalElementalist                    = Spell(117013),
  StaticDischarge                       = Spell(342243),
  StormElemental                        = Spell(192249),
  Stormkeeper                           = Spell(191634),
  StormkeeperBuff                       = Spell(191634),
  SurgeOfPower                          = Spell(262303),
  UnlimitedPower                        = Spell(260895),
  WindGustBuff                          = Spell(263806),
  -- Pets
  Meteor                                = Spell(117588, "pet"),
  CallLightning                         = Spell(157348, "pet"),
  CallLightningBuff                     = Spell(157348),
  EyeOfTheStorm                         = Spell(157375, "pet"),
  -- Conduits (Shadowlands)
  CallOfFlame                           = Spell(338303),
  -- Legendaries (Shadowlands)
  EchoesofGreatSunderingBuff            = Spell(336217),
  ElementalEquilibriumBuff              = Spell(347348),
})

Spell.Shaman.Restoration = MergeTableByKey(Spell.Shaman.Commons, {
})

if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Commons = {
  -- Potions
  PotionofSpectralAgility               = Item(171270),
  PotionofSpectralIntellect             = Item(171273),
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