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
-- Temporary until 11.1
local GetBuildInfo = GetBuildInfo
local TOCNum       = select(4, GetBuildInfo())

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
  FlameShock                            = MultiSpell(188389,470411),
  FlametongueWeapon                     = Spell(318038),
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
  ElementalOrbit                        = Spell(383010),
  LavaBurst                             = Spell(51505),
  DeeplyRootedElements                  = Spell(378270),
  NaturesSwiftness                      = Spell(378081),
  PrimordialWave                        = Spell(375982),
  SpiritwalkersGrace                    = Spell(79206),
  TotemicRecall                         = Spell(108285),
  WindShear                             = Spell(57994),
  -- Buffs
  EarthShieldOtherBuff                  = Spell(974),
  EarthShieldSelfBuff                   = Spell(383648),
  LightningShieldBuff                   = Spell(192106),
  PrimordialWaveBuff                    = Spell(375986),
  SpiritwalkersGraceBuff                = Spell(79206),
  SplinteredElementsBuff                = Spell(382043),
  -- Debuffs
  FlameShockDebuff                      = Spell(188389),
  LightningRodDebuff                    = Spell(197209),
  -- Other Class Debuffs
  ChaosBrandDebuff                      = Spell(1490),
  HuntersMarkDebuff                     = Spell(257284),
  -- Trinket Effects
  SpymastersReportBuff                  = Spell(451199), -- Stacking buff from before using Spymaster's Web trinket
  SpymastersWebBuff                     = Spell(444959), -- Buff from using Spymaster's Web trinket
  -- Misc
  Pool                                  = Spell(999910),
}

Spell.Shaman.Farseer = {
  -- Talents
  AncestralSwiftness                    = Spell(443454),
  CalloftheAncestors                    = Spell(443450),
  ElementalReverb                       = Spell(443418),
  PrimordialCapacity                    = Spell(443448),
}

Spell.Shaman.Stormbringer = {
  -- Abilities
  TempestAbility                        = Spell(452201),
  TempestOverload                       = Spell(463351),
  -- Talents
  ArcDischarge                          = Spell(455096),
  AwakeningStorms                       = Spell(455129),
  RollingThunder                        = Spell(454026),
  Supercharge                           = Spell(455110),
  Tempest                               = Spell(454009),
  -- Buffs
  ArcDischargeBuff                      = Spell(455097),
  AwakeningStormsBuff                   = Spell(462131),
  TempestBuff                           = Spell(454015),
}

Spell.Shaman.Totemic = {
  -- Talents
  AmplificationCore                     = Spell(445029),
  Earthsurge                            = Spell(455590),
  LivelyTotems                          = Spell(445034),
  SurgingTotem                          = Spell(444995),
  TotemicRebound                        = Spell(445025),
  -- Buffs
  LivelyTotemsBuff                      = Spell(461242),
  TotemicReboundBuff                    = Spell(458269),
  WhirlingAirBuff                       = Spell(453409),
  WhirlingEarthBuff                     = Spell(453406),
  WhirlingFireBuff                      = Spell(453405),
}

Spell.Shaman.Elemental = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  EarthShock                            = Spell(8042),
  Earthquake                            = MultiSpell(61882, 462620),
  FireElemental                         = Spell(198067),
  -- Talents
  Ascendance                            = Spell(114050),
  EchoChamber                           = Spell(382032),
  EchooftheElementals                   = Spell(462864),
  EchooftheElements                     = Spell(333919),
  EchoesofGreatSundering                = Spell(384087),
  ElectrifiedShocks                     = Spell(382086),
  EruptingLava                          = Spell(468574),
  EyeoftheStorm                         = Spell(381708),
  FirstAscendant                        = Spell(462440),
  FlowofPower                           = Spell(385923),
  FluxMelting                           = Spell(381776),
  FuryoftheStorms                       = Spell(191717),
  FusionofElements                      = Spell(462840),
  Icefury                               = Spell(210714),
  ImprovedFlametongueWeapon             = Spell(382027),
  LightningRod                          = Spell(210689),
  LiquidMagmaTotem                      = Spell(192222),
  MagmaChamber                          = Spell(381932),
  MasteroftheElements                   = Spell(16166),
  MountainsWillFall                     = Spell(381726),
  PoweroftheMaelstrom                   = Spell(191861),
  PrimalElementalist                    = Spell(117013),
  SearingFlames                         = Spell(381782),
  SkybreakersFieryDemise                = Spell(378310),
  SplinteredElements                    = Spell(382042),
  StormElemental                        = Spell(192249),
  Stormkeeper                           = Spell(191634),
  SurgeofPower                          = Spell(262303),
  SwellingMaelstrom                     = Spell(384359),
  ThunderstrikeWard                     = Spell(462757),
  -- Buffs
  AscendanceBuff                        = Spell(1219480),
  EchoesofGreatSunderingBuff            = Spell(384088),
  FluxMeltingBuff                       = Spell(381777),
  FuryofStormsBuff                      = Spell(191716),
  FusionofElementsFire                  = Spell(462843),
  FusionofElementsNature                = Spell(462841),
  IcefuryBuff                           = Spell(210714),
  JackpotBuff                           = Spell(1218612), -- TWW S2 4pc
  LavaSurgeBuff                         = Spell(77762),
  MagmaChamberBuff                      = Spell(381933),
  MasteroftheElementsBuff               = Spell(260734),
  PoweroftheMaelstromBuff               = Spell(191877),
  StormFrenzyBuff                       = Spell(462725),
  StormkeeperBuff                       = Spell(191634),
  SurgeofPowerBuff                      = Spell(285514),
  WindGustBuff                          = Spell(263806),
  -- Debuffs
  ElectrifiedShocksDebuff               = Spell(382089),
  -- Tier Bonuses
  MaelstromSurgeBuff                    = Spell(457727), -- TWWS1 4pc
})
Spell.Shaman.Elemental = MergeTableByKey(Spell.Shaman.Elemental, Spell.Shaman.Farseer)
Spell.Shaman.Elemental = MergeTableByKey(Spell.Shaman.Elemental, Spell.Shaman.Stormbringer)

Spell.Shaman.Enhancement = MergeTableByKey(Spell.Shaman.Commons, {
  -- Abilities
  VoltaicBlazeAbility                   = Spell(470057),
  Windstrike                            = Spell(115356),
  -- Talents
  AlphaWolf                             = Spell(198434),
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
  FlowingSpirits                        = Spell(469314),
  Hailstorm                             = Spell(334195),
  HotHand                               = Spell(201900),
  IceStrike                             = MultiSpell(342240, 470194),
  LashingFlames                         = Spell(334046),
  LavaLash                              = Spell(60103),
  LegacyoftheFrostWitch                 = Spell(384450),
  MoltenAssault                         = Spell(334033),
  OverflowingMaelstrom                  = Spell(384149),
  PrimordialStorm                       = Spell(1218047),
  PrimordialStormAbility                = Spell(1218090),
  RagingMaelstrom                       = Spell(384143),
  StaticAccumulation                    = Spell(384411),
  Stormblast                            = Spell(319930),
  Stormflurry                           = Spell(344357),
  Stormstrike                           = Spell(17364),
  Sundering                             = Spell(197214),
  SwirlingMaelstrom                     = Spell(384359),
  TempestStrikes                        = Spell(428071),
  ThorimsInvocation                     = Spell(384444),
  UnrelentingStorms                     = Spell(470490),
  UnrulyWinds                           = Spell(390288),
  VoltaicBlaze                          = Spell(470053),
  WindfuryTotem                         = Spell(8512),
  WindfuryWeapon                        = Spell(33757),
  WitchDoctorsAncestry                  = Spell(384447),
  -- Buffs
  AscendanceBuff                        = Spell(114051),
  AshenCatalystBuff                     = Spell(390371),
  ConvergingStormsBuff                  = Spell(198300),
  CracklingThunderBuff                  = Spell(409834),
  CrashLightningBuff                    = Spell(187878),
  CLCrashLightningBuff                  = Spell(333964),
  DoomWindsBuff                         = Spell(466772),
  EarthenWeaponBuff                     = Spell(392375),
  ElectrostaticWagerBuff                = Spell(1223410), -- TWW S2 4pc
  ElectrostaticWagerDmg                 = Spell(1223332), -- TWW S2 4pc
  FeralSpiritBuff                       = Spell(333957),
  GatheringStormsBuff                   = Spell(198300),
  HailstormBuff                         = Spell(334196),
  HotHandBuff                           = Spell(215785),
  IceStrikeBuff                         = Spell(384357),
  LegacyoftheFrostWitchBuff             = Spell(384451),
  MaelstromWeaponBuff                   = Spell(344179),
  PrimordialStormBuff                   = Spell(1218125),
  StormblastBuff                        = Spell(470466),
  StormsurgeBuff                        = Spell(201846),
  WindfuryTotemBuff                     = Spell(327942),
  WinningStreakBuff                     = Spell(1218616), -- TWW S2 2pc
  -- Debuffs
  LashingFlamesDebuff                   = Spell(334168),
  -- Elemental Spirits Buffs
  CracklingSurgeBuff                    = Spell(224127),
  IcyEdgeBuff                           = Spell(224126),
  MoltenWeaponBuff                      = Spell(224125),
  -- Tier 29 Buffs
  MaelstromofElementsBuff               = Spell(394677),
  -- Tier 30 Buffs
  VolcanicStrengthBuff                  = Spell(409833),
})
Spell.Shaman.Enhancement = MergeTableByKey(Spell.Shaman.Enhancement, Spell.Shaman.Stormbringer)
Spell.Shaman.Enhancement = MergeTableByKey(Spell.Shaman.Enhancement, Spell.Shaman.Totemic)

if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Commons = {
}

Item.Shaman.Enhancement = MergeTableByKey(Item.Shaman.Commons, {
  -- DF Trinkets
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  ElementiumPocketAnvil                 = Item(202617, {13, 14}),
  ManicGrieftorch                       = Item(194308, {13, 14}),
})

Item.Shaman.Elemental = MergeTableByKey(Item.Shaman.Commons, {
  -- TWW Trinkets
  FunhouseLens                          = Item(234217, {13, 14}),
  HouseofCards                          = Item(230027, {13, 14}),
  SpymastersWeb                         = Item(220202, {13, 14}),
  -- TWW Items
  BestinSlotsCaster                     = Item(232805, {16}),
  -- TWW S2 Previous Expansion Items
  NeuralSynapseEnhancer                 = Item(168973, {16}),
})
