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
if not Spell.Warlock then Spell.Warlock = {} end
Spell.Warlock.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(33702),
  Fireblood                             = Spell(265221),
  -- Abilities
  ShadowBolt                            = Spell(686),
  SummonDarkglare                       = Spell(205180),
  UnendingResolve                       = Spell(104773),
  -- Talents
  GrimoireofSacrifice                   = Spell(108503),
  GrimoireofSacrificeBuff               = Spell(196099),
  SoulConduit                           = Spell(215941),
  SummonSoulkeeper                      = Spell(386256),
  InquisitorsGaze                       = Spell(386344),
  InquisitorsGazeBuff                   = Spell(388068),
  Shadowfury                            = Spell(30283),
  Soulburn                              = Spell(385899),
  -- Buffs
  SpymastersReportBuff                  = Spell(451199),
  -- Debuffs
  -- Command Demon Abilities
  AxeToss                               = Spell(119914),
  Seduction                             = Spell(119909),
  ShadowBulwark                         = Spell(119907),
  SingeMagic                            = Spell(119905),
  SpellLock                             = Spell(119910),
}

Spell.Warlock.Diabolist = {
  -- Abilities
  InfernalBolt                          = Spell(434506),
  RuinationAbility                      = Spell(434635),
  -- Talents
  DiabolicRitual                        = Spell(428514),
  Ruination                             = Spell(428522),
  SecretsoftheCoven                     = Spell(428518),
  -- Buffs
  DemonicArtMotherBuff                  = Spell(432794),
  DemonicArtOverlordBuff                = Spell(428524),
  DemonicArtPitLordBuff                 = Spell(432795),
  DiabolicRitualMotherBuff              = Spell(432815),
  DiabolicRitualOverlordBuff            = Spell(431944),
  DiabolicRitualPitLordBuff             = Spell(432816),
  InfernalBoltBuff                      = Spell(433891),
}

Spell.Warlock.Hellcaller = {
  -- Talents
  Malevolence                           = Spell(442726),
  Wither                                = Spell(445468),
  -- Debuffs
  MalevolenceBuff                       = Spell(442726),
  WitherDebuff                          = Spell(445474),
}

Spell.Warlock.SoulHarvester = {
  -- Talents
  DemonicSoul                           = Spell(449614),
  Quietus                               = Spell(449634),
}

Spell.Warlock.Affliction = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Agony                                 = Spell(980),
  Corruption                            = Spell(172),
  DrainLife                             = Spell(234153),
  SummonPet                             = Spell(688),
  -- Talents
  AbsoluteCorruption                    = Spell(196103),
  CreepingDeath                         = Spell(264000),
  DrainSoul                             = Spell(198590),
  DrainSoulTalent                       = Spell(388667),
  DreadTouch                            = Spell(389775),
  Haunt                                 = Spell(48181),
  ImprovedShadowBolt                    = Spell(453080),
  InevitableDemise                      = Spell(334319),
  MaleficAffliction                     = Spell(389761),
  MaleficRapture                        = Spell(324536),
  Nightfall                             = Spell(108558),
  Oblivion                              = Spell(417537),
  PhantomSingularity                    = Spell(205179),
  SowTheSeeds                           = Spell(196226),
  SeedofCorruption                      = Spell(27243),
  ShadowEmbrace                         = Spell(32388),
  SiphonLife                            = Spell(63106),
  SoulRot                               = Spell(386997),
  SoulSwap                              = Spell(386951),
  SoulTap                               = Spell(387073),
  SouleatersGluttony                    = Spell(389630),
  SowtheSeeds                           = Spell(196226),
  TormentedCrescendo                    = Spell(387075),
  UnstableAffliction                    = Spell(316099),
  VileTaint                             = Spell(278350),
  -- Buffs
  InevitableDemiseBuff                  = Spell(334320),
  NightfallBuff                         = Spell(264571),
  MaleficAfflictionBuff                 = Spell(389845),
  TormentedCrescendoBuff                = Spell(387079),
  UmbrafireKindlingBuff                 = Spell(423765), -- T31 4pc
  -- Debuffs
  AgonyDebuff                           = Spell(980),
  CorruptionDebuff                      = Spell(146739),
  HauntDebuff                           = Spell(48181),
  PhantomSingularityDebuff              = Spell(205179),
  SeedofCorruptionDebuff                = Spell(27243),
  SiphonLifeDebuff                      = Spell(63106),
  UnstableAfflictionDebuff              = Spell(316099),
  VileTaintDebuff                       = Spell(386931),
  SoulRotDebuff                         = Spell(386997),
  DreadTouchDebuff                      = Spell(389868),
  ShadowEmbraceDSDebuff                 = Spell(32390),
  ShadowEmbraceSBDebuff                 = Spell(453206),
})
Spell.Warlock.Affliction = MergeTableByKey(Spell.Warlock.Affliction, Spell.Warlock.Hellcaller)
Spell.Warlock.Affliction = MergeTableByKey(Spell.Warlock.Affliction, Spell.Warlock.SoulHarvester)

Spell.Warlock.Demonology = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Felstorm                              = Spell(89751),
  HandofGuldan                          = Spell(105174), -- Splash, 8
  ShadowBoltLineCD                      = Spell(686),
  SummonPet                             = Spell(30146),
  -- Talents
  BilescourgeBombers                    = Spell(267211), -- Splash, 8
  CallDreadstalkers                     = Spell(104316),
  Demonbolt                             = Spell(264178),
  DemonicCalling                        = Spell(205145),
  DemonicStrength                       = Spell(267171),
  Doom                                  = Spell(460551),
  FelInvocation                         = Spell(428351),
  GrandWarlocksDesign                   = Spell(387084),
  GrimoireFelguard                      = Spell(111898),
  Guillotine                            = Spell(386833),
  Implosion                             = Spell(196277), -- Splash, 8
  InnerDemons                           = Spell(267216),
  MarkofFharg                           = Spell(455450),
  MarkofShatug                          = Spell(455449),
  NetherPortal                          = Spell(267217),
  PowerSiphon                           = Spell(264130),
  ReignofTyranny                        = Spell(427684),
  SacrificedSouls                       = Spell(267214),
  SoulboundTyrant                       = Spell(334585),
  SoulStrike                            = Spell(428344),
  SoulStrikePetAbility                  = Spell(264057, "Pet"),
  SummonCharhound                       = Spell(455476),
  SummonDemonicTyrant                   = Spell(265187),
  SummonGloomhound                      = Spell(455465),
  SummonVilefiend                       = Spell(264119),
  TheExpendables                        = Spell(387600),
  -- Buffs
  DemonicCallingBuff                    = Spell(205146),
  DemonicCoreBuff                       = Spell(264173),
  DemonicPowerBuff                      = Spell(265273),
  DoomDebuff                            = Spell(460553),
  NetherPortalBuff                      = Spell(267218),
  RiteofRuvaraadBuff                    = Spell(409725), -- T30 4pc
  -- Debuffs
  DoomDebuff                            = Spell(603),
  DoomBrandDebuff                       = Spell(423583), -- T31 2pc
  FromtheShadowsDebuff                  = Spell(270569),
})
Spell.Warlock.Demonology = MergeTableByKey(Spell.Warlock.Demonology, Spell.Warlock.Diabolist)
Spell.Warlock.Demonology = MergeTableByKey(Spell.Warlock.Demonology, Spell.Warlock.SoulHarvester)

Spell.Warlock.Destruction = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Immolate                              = Spell(348),
  Incinerate                            = Spell(29722),
  SummonPet                             = Spell(688),
  -- Talents
  AshenRemains                          = Spell(387252),
  AvatarofDestruction                   = Spell(387159),
  Backdraft                             = Spell(196406),
  BlisteringAtrophy                     = Spell(456939),
  BurntoAshes                           = Spell(387153),
  Cataclysm                             = Spell(152108),
  ChannelDemonfire                      = Spell(196447),
  ChaosBolt                             = Spell(116858),
  ChaosIncarnate                        = Spell(387275),
  Chaosbringer                          = Spell(422057),
  Conflagrate                           = Spell(17962),
  ConflagrationofChaos                  = Spell(387108),
  CrashingChaos                         = Spell(417234),
  CryHavoc                              = Spell(387522),
  Decimation                            = Spell(456985),
  DemonfireMastery                      = Spell(456946),
  DiabolicEmbers                        = Spell(387173),
  DimensionalRift                       = Spell(387976),
  Eradication                           = Spell(196412),
  FireandBrimstone                      = Spell(196408),
  Havoc                                 = Spell(80240),
  ImprovedChaosBolt                     = Spell(456951),
  Inferno                               = Spell(270545),
  InternalCombustion                    = Spell(266134),
  MadnessoftheAzjAqir                   = Spell(387400),
  Mayhem                                = Spell(387506),
  Pyrogenics                            = Spell(387095),
  RagingDemonfire                       = Spell(387166),
  RainofChaos                           = Spell(266086),
  RainofFire                            = Spell(5740),
  RoaringBlaze                          = Spell(205184),
  Ruin                                  = Spell(387103),
  Shadowburn                            = Spell(17877),
  SoulFire                              = Spell(6353),
  SummonInfernal                        = Spell(1122),
  -- Buffs
  BackdraftBuff                         = Spell(117828),
  DecimationBuff                        = Spell(457555),
  MadnessCBBuff                         = Spell(387409),
  MadnessRoFBuff                        = Spell(387413),
  MadnessSBBuff                         = Spell(387414),
  RainofChaosBuff                       = Spell(266087),
  RitualofRuinBuff                      = Spell(387157),
  BurntoAshesBuff                       = Spell(387154),
  -- Debuffs
  ConflagrateDebuff                     = Spell(265931),
  EradicationDebuff                     = Spell(196414),
  HavocDebuff                           = Spell(80240),
  ImmolateDebuff                        = Spell(157736),
  PyrogenicsDebuff                      = Spell(387096),
  RoaringBlazeDebuff                    = Spell(265931),
})
Spell.Warlock.Destruction = MergeTableByKey(Spell.Warlock.Destruction, Spell.Warlock.Diabolist)
Spell.Warlock.Destruction = MergeTableByKey(Spell.Warlock.Destruction, Spell.Warlock.Hellcaller)

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Commons = {
  -- TWW Trinkets
  SpymastersWeb                         = Item(220202, {13, 14}),
}

Item.Warlock.Affliction = MergeTableByKey(Item.Warlock.Commons, {
  -- DF Trinkets
  TimeThiefsGambit                      = Item(207579, {13, 14}),
  -- TWW Trinkets
  AberrantSpellforge                    = Item(212451, {13, 14}),
})

Item.Warlock.Demonology = MergeTableByKey(Item.Warlock.Commons, {
  -- DF Trinkets
  MirrorofFracturedTomorrows            = Item(207581, {13, 14}),
  -- TWW Trinkets
  ImperfectAscendancySerum              = Item(225654, {13, 14}),
})

Item.Warlock.Destruction = MergeTableByKey(Item.Warlock.Commons, {
})
