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
if not Spell.Monk then Spell.Monk = {}; end
Spell.Monk.Windwalker = {

  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(25046),
  BagOfTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Bloodlust                             = Spell(2825),
  GiftoftheNaaru                        = Spell(59547),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  QuakingPalm                           = Spell(107079),
  Shadowmeld                            = Spell(58984),

  -- Abilities
  BlackoutKick                          = Spell(100784),
  BlackoutKickBuff                      = Spell(116768),
  CracklingJadeLightning                = Spell(117952),
  ExpelHarm                             = Spell(322101),
  FistsOfFury                           = Spell(113656),
  FlyingSerpentKick                     = Spell(101545),
  FlyingSerpentKickActionBarReplacement = Spell(115057),
  InvokeXuenTheWhiteTiger               = Spell(123904),
  RisingSunKick                         = Spell(107428),
  SpinningCraneKick                     = Spell(101546),
  StormEarthAndFire                     = Spell(137639),
  StormEarthAndFireBuff                 = Spell(137639),
  TigerPalm                             = Spell(100780),
  TouchOfDeath                          = Spell(322109),

  -- Debuffs
  MarkOfTheCraneDebuff                  = Spell(228287),

  -- Talents
  Celerity                              = Spell(115173),
  ChiWave                               = Spell(115098),
  ChiBurst                              = Spell(123986),
  DanceOfChijiBuff                      = Spell(325202),
  EyeOfTheTiger                         = Spell(196607),
  FistOfTheWhiteTiger                   = Spell(261947),
  GoodKarma                             = Spell(280195),
  HitCombo                              = Spell(196740),
  HitComboBuff                          = Spell(196741),
  InnerStrengthBuff                     = Spell(261769),
  RushingJadeWind                       = Spell(116847),
  RushingJadeWindBuff                   = Spell(116847),
  WhirlingDragonPunch                   = Spell(152175),
  WhirlingDragonPunchBuff               = Spell(196742),
  Serenity                              = Spell(152173),
  SerenityBuff                          = Spell(152173),
  SpiritualFocus                        = Spell(280197),

  -- Defensive
  DampenHarm                            = Spell(122278), -- Talent
  DampenHarmBuff                        = Spell(122278),
  DiffuseMagic                          = Spell(122783), -- Talent
  FortifyingBrew                        = Spell(243435),
  HealingElixir                         = Spell(122281), -- Talent
  TouchOfKarma                          = Spell(122470),

  -- Utility
  ChiTorpedo                            = Spell(115008), -- Talent
  Detox                                 = Spell(218164),
  Disable                               = Spell(116095),
  EnergizingElixir                      = Spell(115288), -- Talent
  LegSweep                              = Spell(119381), -- Talent
  Paralysis                             = Spell(115078),
  Provoke                               = Spell(115546),
  Resuscitate                           = Spell(115178),
  RingOfPeace                           = Spell(116844), -- Talent
  Roll                                  = Spell(109132),
  SpearHandStrike                       = Spell(116705),
  TigersLust                            = Spell(116841), -- Talent
  TigerTailSweep                        = Spell(264348),
  Transcendence                         = Spell(101643),
  TranscendenceTransfer                 = Spell(119996),
  Vivify                                = Spell(116670),

  -- Trinket Debuffs

  -- PvP Abilities

  -- Shadowland Covenant
  BonedustBrew                          = Spell(325216),
  FaelineStomp                          = Spell(327104),
  FaelineStompDebuff                    = Spell(327257),
  FallenOrder                           = Spell(326860),
  Fleshcraft                            = Spell(324631),
  WeaponsOfOrder                        = Spell(310454),
  WeaponsOfOrderChiBuff                 = Spell(311054),
  WeaponsOfOrderDebuff                  = Spell(312106),

  -- Shadowland Essences
  FortifyingIngrediencesBuff            = Spell(336874),

  -- Shadowlands Legendary
  ChiEnergyBuff                         = Spell(337571),
  InvokersDelight                       = Spell(338321),
  KeefersSkyreachDebuff                 = Spell(344021),
  RecentlyRushingTigerPalm              = Spell(337341),
  TheEmperorsCapacitor                  = Spell(337291),

  -- Conduits
  InnerFury                             = Spell(336452),
  CalculatedStrikes                     = Spell(336526),

  -- Misc
  PoolEnergy                            = Spell(999910)
}

Spell.Monk.Brewmaster = {

  -- Racials
  AncestralCall                = Spell(274738),
  ArcaneTorrent                = Spell(50613),
  BagOfTricks                  = Spell(312411),
  Berserking                   = Spell(26297),
  BloodFury                    = Spell(20572),
  Fireblood                    = Spell(265221),
  LightsJudgment               = Spell(255647),

  -- Abilities
  BlackoutKick                 = Spell(205523),
  BreathOfFire                 = Spell(115181),
  Clash                        = Spell(324312),
  CracklingJadeLightning       = Spell(117952),
  ExpelHarm                    = Spell(322101),
  InvokeNiuzaoTheBlackOx       = Spell(132578),
  KegSmash                     = Spell(121253),
  SpinningCraneKick            = Spell(322729),
  TigerPalm                    = Spell(100780),
  TouchOfDeath                 = Spell(322109),

  -- Debuffs
  BreathOfFireDotDebuff        = Spell(123725),

  -- Talents
  BlackoutCombo                = Spell(196736),
  BlackoutComboBuff            = Spell(228563),
  BlackOxBrew                  = Spell(115399),
  BobAndWeave                  = Spell(280515),
  Celerity                     = Spell(115173),
  CelestialFlames              = Spell(325177),
  ChiBurst                     = Spell(123986),
  ChiWave                      = Spell(115098),
  EyeOfTheTiger                = Spell(196607),
  ExplodingKeg                 = Spell(214326),
  LightBrewing                 = Spell(325093),
  RushingJadeWind              = Spell(116847),
  SpecialDelivery              = Spell(196730),
  Spitfire                     = Spell(242580),
  SummonBlackOxStatue          = Spell(115315),

  -- Defensive
  CelestialBrew                = Spell(322507),
  DampenHarm                   = Spell(122278), -- Talent
  DampenHarmBuff               = Spell(122278),
  ElusiveBrawlerBuff           = Spell(195630),
  FortifyingBrew               = Spell(115203),
  FortifyingBrewBuff           = Spell(115203),
  HighTolerance                = Spell(196737), -- Talent
  PurifyingBrew                = Spell(119582),
  PurifiedChiBuff              = Spell(325092),
  Shuffle                      = Spell(215479),

  -- Utility
  ChiTorpedo                   = Spell(115008), -- Talent
  Detox                        = Spell(218164),
  Disable                      = Spell(116095),
  LegSweep                     = Spell(119381), -- Talent
  Paralysis                    = Spell(115078),
  Provoke                      = Spell(115546),
  Resuscitate                  = Spell(115178),
  RingOfPeace                  = Spell(116844), -- Talent
  Roll                         = Spell(109132),
  SpearHandStrike              = Spell(116705),
  TigersLust                   = Spell(116841), -- Talent
  TigerTailSweep               = Spell(264348), -- Talent
  Transcendence                = Spell(101643),
  TranscendenceTransfer        = Spell(119996),
  Vivify                       = Spell(116670),

  -- Shadowlands Covenants
  BonedustBrew                 = Spell(325216),
  FaelineStomp                 = Spell(327104),
  FaelineStompBuff             = Spell(347480),
  FaelineStompDebuff           = Spell(327257),
  FallenOrder                  = Spell(326860),
  Fleshcraft                   = Spell(324631),
  WeaponsOfOrder               = Spell(310454),
  WeaponsOfOrderDebuff         = Spell(312106),

  -- Shadowlands Legendary
  CharredPassions              = Spell(338140),
  InvokersDelight              = Spell(338321),
  KeefersSkyreach              = Spell(344021),
  MightyPour                   = Spell(337994),
  RecentlyRushingTigerPalm     = Spell(337341),

  -- Trinket Debuffs

  -- PvP Abilities

  -- Stagger Levels
  HeavyStagger                 = Spell(124273),
  ModerateStagger              = Spell(124274),
  LightStagger                 = Spell(124275),

  -- Misc
  PoolEnergy                   = Spell(999910)
}

Spell.Monk.Mistweaver = {

  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(25046),
  BagOfTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Bloodlust                             = Spell(2825),
  GiftoftheNaaru                        = Spell(59547),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  QuakingPalm                           = Spell(107079),
  Shadowmeld                            = Spell(58984),

  -- Abilities
  BlackoutKick                          = Spell(100784),
  CracklingJadeLightning                = Spell(117952),
  EnvelopingMist                        = Spell(124682),
  EssenceFont                           = Spell(191837),
  EssenceFontBuff                       = Spell(191840),
  ExpelHarm                             = Spell(322101),
  InvokeYulonTheJadeSerpent             = Spell(123904),
  LifeCocoon                            = Spell(116849),
  RenewingMist                          = Spell(115151),
  Revival                               = Spell(115310),
  RisingSunKick                         = Spell(107428),
  SoothingMist                          = Spell(115175),
  SpinningCraneKick                     = Spell(101546),
  TeachingsOfTheMonasteryBuff           = Spell(202090),
  ThunderFocusTea                       = Spell(116680),
  TigerPalm                             = Spell(100780),
  TouchOfDeath                          = Spell(322109),

  -- Debuffs

  -- Talents
  Celerity                              = Spell(115173),
  ChiWave                               = Spell(115098),
  ChiBurst                              = Spell(123986),
  EyeOfTheTiger                         = Spell(196607),
  GoodKarma                             = Spell(280195),
  InnerStrengthBuff                     = Spell(261769),
  InvokeChiJiTheRedCrane                = Spell(325197),
  LifecyclesEnvelopingMistBuff          = Spell(197919),
  LifecyclesVivifyBuff                  = Spell(197916),
  ManaTea                               = Spell(197908),
  RefreshingJadeWind                    = Spell(196725),
  SummonJadeSerpentStatue               = Spell(115313),

  -- Defensive
  DampenHarm                            = Spell(122278), -- Talent
  DampenHarmBuff                        = Spell(122278),
  DiffuseMagic                          = Spell(122783), -- Talent
  FortifyingBrew                        = Spell(243435),
  HealingElixir                         = Spell(122281), -- Talent

  -- Utility
  ChiTorpedo                            = Spell(115008), -- Talent
  Detox                                 = Spell(218164),
  Disable                               = Spell(116095),
  EnergizingElixir                      = Spell(115288), -- Talent
  LegSweep                              = Spell(119381), -- Talent
  Paralysis                             = Spell(115078),
  Provoke                               = Spell(115546),
  Reawaken                              = Spell(212051),
  Resuscitate                           = Spell(115178),
  RingOfPeace                           = Spell(116844), -- Talent
  Roll                                  = Spell(109132),
  SongOfChiJi                           = Spell(198898), -- Talent
  SpearHandStrike                       = Spell(116705),
  TigersLust                            = Spell(116841), -- Talent
  TigerTailSweep                        = Spell(264348),
  Transcendence                         = Spell(101643),
  TranscendenceTransfer                 = Spell(119996),
  Vivify                                = Spell(116670),

  -- Trinket Debuffs

  -- PvP Abilities

  -- Shadowland Covenant
  BonedustBrew                          = Spell(325216),
  FaelineStomp                          = Spell(327104),
  FaelineStompDebuff                    = Spell(327257),
  FallenOrder                           = Spell(326860),
  Fleshcraft                            = Spell(324631),
  WeaponsOfOrder                        = Spell(310454),
  WeaponsOfOrderChiBuff                 = Spell(311054),
  WeaponsOfOrderDebuff                  = Spell(312106),

  -- Soulbinds
  LeadByExample                         = Spell(342156),
  VolatileSolvent                       = Spell(323074),

  -- Shadowland Essences
  FortifyingIngrediencesBuff            = Spell(336874),

  -- Shadowlands Legendary
  ChiEnergyBuff                         = Spell(337571),
  InvokersDelight                       = Spell(338321),
  KeefersSkyreachDebuff                 = Spell(344021),
  RecentlyRushingTigerPalm              = Spell(337341),
  TheEmperorsCapacitor                  = Spell(337291),

  -- Misc
  PoolEnergy                            = Spell(999910)
}

-- Items
if not Item.Monk then Item.Monk = {}; end
Item.Monk.Windwalker = {
  -- Potions
  PotionofPhantomFire                  = Item(171349),
  PotionofSpectralAgility              = Item(171270),
  PotionofDeathlyFixation              = Item(171351),
  PotionofEmpoweredExorcisms           = Item(171352),
  PotionofHardenedShadows              = Item(171271),
  PotionofSpectralStamina              = Item(171274)
}

Item.Monk.Brewmaster = {
  -- Potions
  PotionofPhantomFire                  = Item(171349),
  -- Items/Trinkets
  Jotungeirr                           = Item(186404)
}

Item.Monk.Mistweaver = {
  -- Potions
  PotionofSpectralIntellect            = Item(171273),
  -- Items/Trinkets
  Jotungeirr                           = Item(186404)
}
