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
if not Spell.Monk then Spell.Monk = {}; end
Spell.Monk.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(25046),
  BagOfTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  GiftoftheNaaru                        = Spell(59547),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  QuakingPalm                           = Spell(107079),
  Shadowmeld                            = Spell(58984),
  -- Abilities
  CracklingJadeLightning                = Spell(117952),
  ExpelHarm                             = Spell(322101),
  RisingSunKick                         = Spell(107428),
  TigerPalm                             = Spell(100780),
  TouchOfDeath                          = Spell(322109),
  -- Talents
  Celerity                              = Spell(115173),
  ChiBurst                              = Spell(123986),
  ChiWave                               = Spell(115098),
  EyeOfTheTiger                         = Spell(196607),
  GoodKarma                             = Spell(280195),
  InnerStrengthBuff                     = Spell(261769),
  RushingJadeWind                       = Spell(116847),
  RushingJadeWindBuff                   = Spell(116847),
  -- Talents
  ChiTorpedo                            = Spell(115008),
  DampenHarm                            = Spell(122278),
  DampenHarmBuff                        = Spell(122278),
  DiffuseMagic                          = Spell(122783),
  EnergizingElixir                      = Spell(115288),
  HealingElixir                         = Spell(122281),
  LegSweep                              = Spell(119381),
  RingOfPeace                           = Spell(116844),
  TigersLust                            = Spell(116841),
  TigerTailSweep                        = Spell(264348),
  -- Utility
  Detox                                 = Spell(218164),
  Disable                               = Spell(116095),
  Paralysis                             = Spell(115078),
  Provoke                               = Spell(115546),
  Resuscitate                           = Spell(115178),
  Roll                                  = Spell(109132),
  SpearHandStrike                       = Spell(116705),
  Transcendence                         = Spell(101643),
  TranscendenceTransfer                 = Spell(119996),
  Vivify                                = Spell(116670),
  -- Covenant Abilities (Shadowlands)
  BonedustBrew                          = Spell(325216),
  FaelineStomp                          = Spell(327104),
  FaelineStompBuff                      = Spell(347480),
  FaelineStompDebuff                    = Spell(327257),
  FallenOrder                           = Spell(326860),
  Fleshcraft                            = Spell(324631),
  WeaponsOfOrder                        = Spell(310454),
  WeaponsOfOrderChiBuff                 = Spell(311054),
  WeaponsOfOrderDebuff                  = Spell(312106),
  -- Soulbinds (Shadowlands)
  GroveInvigoration                     = Spell(322721),
  LeadByExample                         = Spell(342156),
  PustuleEruption                       = Spell(351094),
  VolatileSolvent                       = Spell(323074),
  -- Conduits (Shadowlands)
  FortifyingIngrediencesBuff            = Spell(336874),
  -- Legendary Effects (Shadowlands)
  ChiEnergyBuff                         = Spell(337571),
  InvokersDelight                       = Spell(338321),
  RecentlyRushingTigerPalm              = Spell(337341),
  SkyreachExhaustion                    = Spell(337341),
  TheEmperorsCapacitor                  = Spell(337291),
  -- Trinket Effects
  AcquiredAxeBuff                       = Spell(368656),
  AcquiredWandBuff                      = Spell(368654),
  ScarsofFraternalStrifeBuff4           = Spell(368638),
  -- Misc
  PoolEnergy                            = Spell(999910)
}

Spell.Monk.Windwalker = MergeTableByKey(Spell.Monk.Commons, {
  -- Abilities
  BlackoutKick                          = Spell(100784),
  BlackoutKickBuff                      = Spell(116768),
  FistsOfFury                           = Spell(113656),
  FlyingSerpentKick                     = Spell(101545),
  FlyingSerpentKickActionBarReplacement = Spell(115057),
  InvokeXuenTheWhiteTiger               = Spell(123904),
  SpinningCraneKick                     = Spell(101546),
  StormEarthAndFire                     = Spell(137639),
  StormEarthAndFireBuff                 = Spell(137639),
  StormEarthAndFireFixate               = Spell(221771),
  -- Debuffs
  MarkOfTheCraneDebuff                  = Spell(228287),
  -- Talents
  DanceOfChijiBuff                      = Spell(325202),
  FistOfTheWhiteTiger                   = Spell(261947),
  HitCombo                              = Spell(196740),
  HitComboBuff                          = Spell(196741),
  Serenity                              = Spell(152173),
  SerenityBuff                          = Spell(152173),
  SpiritualFocus                        = Spell(280197),
  WhirlingDragonPunch                   = Spell(152175),
  WhirlingDragonPunchBuff               = Spell(196742),
  -- Defensive
  FortifyingBrew                        = Spell(243435),
  TouchOfKarma                          = Spell(122470),
  -- Conduits
  CalculatedStrikes                     = Spell(336526),
  CoordinatedOffensive                  = Spell(336598),
  InnerFury                             = Spell(336452),
  -- Tier 28 Set Bonus
  PrimordialPotentialBuff               = Spell(363911),
  PrimordialPowerBuff                   = Spell(368685),
})

Spell.Monk.Brewmaster = MergeTableByKey(Spell.Monk.Commons, {
  -- Abilities
  BlackoutKick                          = Spell(205523),
  BreathOfFire                          = Spell(115181),
  Clash                                 = Spell(324312),
  InvokeNiuzaoTheBlackOx                = Spell(132578),
  KegSmash                              = Spell(121253),
  SpinningCraneKick                     = Spell(322729),
  -- Debuffs
  BreathOfFireDotDebuff                 = Spell(123725),
  -- Talents
  BlackoutCombo                         = Spell(196736),
  BlackoutComboBuff                     = Spell(228563),
  BlackOxBrew                           = Spell(115399),
  BobAndWeave                           = Spell(280515),
  CelestialFlames                       = Spell(325177),
  ExplodingKeg                          = Spell(325153),
  HighTolerance                         = Spell(196737),
  LightBrewing                          = Spell(325093),
  SpecialDelivery                       = Spell(196730),
  Spitfire                              = Spell(242580),
  SummonBlackOxStatue                   = Spell(115315),
  -- Defensive
  CelestialBrew                         = Spell(322507),
  ElusiveBrawlerBuff                    = Spell(195630),
  FortifyingBrew                        = Spell(115203),
  FortifyingBrewBuff                    = Spell(115203),
  PurifyingBrew                         = Spell(119582),
  PurifiedChiBuff                       = Spell(325092),
  Shuffle                               = Spell(215479),
  -- Legendary Effects (Shadowlands)
  CharredPassions                       = Spell(338140),
  MightyPour                            = Spell(337994),
  -- Stagger Levels
  HeavyStagger                          = Spell(124273),
  ModerateStagger                       = Spell(124274),
  LightStagger                          = Spell(124275),
})

Spell.Monk.Mistweaver = MergeTableByKey(Spell.Monk.Commons, {
  -- Abilities
  BlackoutKick                          = Spell(100784),
  EnvelopingMist                        = Spell(124682),
  EssenceFont                           = Spell(191837),
  EssenceFontBuff                       = Spell(191840),
  InvokeYulonTheJadeSerpent             = Spell(123904),
  LifeCocoon                            = Spell(116849),
  RenewingMist                          = Spell(115151),
  Revival                               = Spell(115310),
  SoothingMist                          = Spell(115175),
  SpinningCraneKick                     = Spell(101546),
  TeachingsOfTheMonasteryBuff           = Spell(202090),
  ThunderFocusTea                       = Spell(116680),
  -- Talents
  InvokeChiJiTheRedCrane                = Spell(325197),
  LifecyclesEnvelopingMistBuff          = Spell(197919),
  LifecyclesVivifyBuff                  = Spell(197916),
  ManaTea                               = Spell(197908),
  RefreshingJadeWind                    = Spell(196725),
  SongOfChiJi                           = Spell(198898),
  SummonJadeSerpentStatue               = Spell(115313),
  -- Defensive
  FortifyingBrew                        = Spell(243435),
  -- Utility
  Reawaken                              = Spell(212051),
})

-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Commons = {
  -- Potions
  PotionofPhantomFire                  = Item(171349),
  PotionofSpectralAgility              = Item(171270),
  PotionofSpectralIntellect            = Item(171273),
  -- Trinkets
  CacheofAcquiredTreasures             = Item(188265, {13, 14}),
  GladiatorsBadgeCosmic                = Item(186866, {13, 14}),
  GladiatorsBadgeSinful                = Item(175921, {13, 14}),
  GladiatorsBadgeUnchained             = Item(185197, {13, 14}),
  InscrutibleQuantumDevice             = Item(179350, {13, 14}),
  OverchargedAnimaBattery              = Item(180116, {13, 14}),
  ScarsofFraternalStrife                = Item(188253, {13, 14}),
  ShadowgraspTotem                     = Item(179356, {13, 14}),
  TheFirstSigil                        = Item(188271, {13, 14}),
  Wrathstone                           = Item(156000, {13, 14}),
  -- Other On-Use Items
  Jotungeirr                           = Item(186404),
}

Item.Monk.Windwalker = MergeTableByKey(Item.Monk.Commons, {
})

Item.Monk.Brewmaster = MergeTableByKey(Item.Monk.Commons, {
})

Item.Monk.Mistweaver = MergeTableByKey(Item.Monk.Commons, {
})
