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
  Soulburn                              = Spell(385899),
  -- Buffs
  PowerInfusionBuff                     = Spell(10060),
  -- Debuffs
  -- Command Demon Abilities
  AxeToss                               = Spell(119914),
  Seduction                             = Spell(119909),
  ShadowBulwark                         = Spell(119907),
  SingeMagic                            = Spell(119905),
  SpellLock                             = Spell(119910),
}

Spell.Warlock.Demonology = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Felstorm                              = Spell(89751),
  HandofGuldan                          = Spell(105174), -- Splash, 8
  SummonPet                             = Spell(30146),
  -- Talents
  BilescourgeBombers                    = Spell(267211), -- Splash, 8
  CallDreadstalkers                     = Spell(104316),
  Demonbolt                             = Spell(264178),
  DemonicCalling                        = Spell(205145),
  DemonicStrength                       = Spell(267171),
  Doom                                  = Spell(603),
  FromtheShadows                        = Spell(267170),
  GrimoireFelguard                      = Spell(111898),
  Guillotine                            = Spell(386833),
  Implosion                             = Spell(196277), -- Splash, 8
  InnerDemons                           = Spell(267216),
  NetherPortal                          = Spell(267217),
  PowerSiphon                           = Spell(264130),
  SacrificedSouls                       = Spell(267214),
  SoulStrike                            = Spell(264057),
  SummonDemonicTyrant                   = Spell(265187),
  SummonVilefiend                       = Spell(264119),
  FelCovenant                           = Spell(387432),
  FelCovenantBuff                       = Spell(387437),
  SoulboundTyrant                       = Spell(334585),
  -- Buffs
  DemonicCallingBuff                    = Spell(205146),
  DemonicCoreBuff                       = Spell(264173),
  DemonicPowerBuff                      = Spell(265273),
  NetherPortalBuff                      = Spell(267218),
  -- Debuffs
  DoomDebuff                            = Spell(603),
  FromtheShadowsDebuff                  = Spell(270569),
})

Spell.Warlock.Affliction = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Agony                                 = Spell(980),
  Corruption                            = Spell(172),
  DrainLife                             = Spell(234153),
  SummonPet                             = Spell(688),
  -- Talents
  AbsoluteCorruption                    = Spell(196103),
  DrainSoul                             = Spell(198590),
  DreadTouch                            = Spell(389775),
  Haunt                                 = Spell(48181),
  InevitableDemise                      = Spell(334319),
  MaleficAffliction                     = Spell(389761),
  MaleficRapture                        = Spell(324536),
  Nightfall                             = Spell(108558),
  PhantomSingularity                    = Spell(205179),
  SowTheSeeds                           = Spell(196226),
  SeedofCorruption                      = Spell(27243),
  ShadowEmbrace                         = Spell(27243),
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
  -- Debuffs
  AgonyDebuff                           = Spell(980),
  CorruptionDebuff                      = Spell(146739),
  HauntDebuff                           = Spell(48181),
  PhantomSingularityDebuff              = Spell(205179),
  SeedofCorruptionDebuff                = Spell(27243),
  SiphonLifeDebuff                      = Spell(63106),
  UnstableAfflictionDebuff              = Spell(316099),
  VileTaintDebuff                       = Spell(278350),
  SoulRotDebuff                         = Spell(386997),
  DreadTouchDebuff                      = Spell(389868),
  ShadowEmbraceDebuff                   = Spell(32390),
})

Spell.Warlock.Destruction = MergeTableByKey(Spell.Warlock.Commons, {
  -- Base Abilities
  Immolate                              = Spell(348),
  Incinerate                            = Spell(29722),
  SummonPet                             = Spell(688),
  -- Talents
  AshenRemains                          = Spell(387252),
  AvatarofDestruction                   = Spell(387159),
  Backdraft                             = Spell(196406),
  Cataclysm                             = Spell(152108),
  ChannelDemonfire                      = Spell(196447),
  ChaosBolt                             = Spell(116858),
  Conflagrate                           = Spell(17962),
  CryHavoc                              = Spell(387522),
  DiabolicEmbers                        = Spell(387173),
  DimensionalRift                       = Spell(387976),
  Eradication                           = Spell(196412),
  FireandBrimstone                      = Spell(196408),
  Havoc                                 = Spell(80240),
  Inferno                               = Spell(270545),
  InternalCombustion                    = Spell(266134),
  MadnessoftheAzjAqir                   = Spell(387400),
  Mayhem                                = Spell(387506),
  RagingDemonfire                       = Spell(387166),
  RainofChaos                           = Spell(266086),
  RainofFire                            = Spell(5740),
  RoaringBlaze                          = Spell(205184),
  Ruin                                  = Spell(387103),
  SoulFire                              = Spell(6353),
  SummonInfernal                        = Spell(1122),
  -- Buffs
  BackdraftBuff                         = Spell(117828),
  MadnessCBBuff                         = Spell(387409),
  RainofChaosBuff                       = Spell(266087),
  RitualofRuinBuff                      = Spell(387157),
  BurntoAshesBuff                       = Spell(387154),
  -- Debuffs
  EradicationDebuff                     = Spell(196414),
  HavocDebuff                           = Spell(80240),
  ImmolateDebuff                        = Spell(157736),
  RoaringBlazeDebuff                    = Spell(265931),
})

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Commons = {
  -- Trinkets
  ConjuredChillglobe                    = Item(194300, {13, 14}),
  DesperateInvokersCodex                = Item(194310, {13, 14}),
  TimebreachingTalon                    = Item(193791, {13, 14}),
}

Item.Warlock.Affliction = MergeTableByKey(Item.Warlock.Commons, {
})

Item.Warlock.Demonology = MergeTableByKey(Item.Warlock.Commons, {
})

Item.Warlock.Destruction = MergeTableByKey(Item.Warlock.Commons, {
})
