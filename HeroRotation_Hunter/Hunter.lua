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
if not Spell.Hunter then Spell.Hunter = {} end
Spell.Hunter.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  ArcaneShot                            = Spell(185358),
  Exhilaration                          = Spell(109304),
  Flare                                 = Spell(1543),
  FreezingTrap                          = Spell(187650),
  HuntersMark                           = Spell(257284),
  -- Pet Utility Abilities
  MendPet                               = Spell(136),
  RevivePet                             = Spell(982),
  SummonPet                             = Spell(883),
  SummonPet2                            = Spell(83242),
  SummonPet3                            = Spell(83243),
  SummonPet4                            = Spell(83244),
  SummonPet5                            = Spell(83245),
  -- Talents
  AlphaPredator                         = Spell(269737),
  Barrage                               = Spell(120360),
  BeastMaster                           = Spell(378007),
  CounterShot                           = Spell(147362),
  DeathChakram                          = Spell(375891),
  ExplosiveShot                         = Spell(212431),
  HydrasBite                            = Spell(260241),
  Intimidation                          = Spell(19577),
  KillerInstinct                        = Spell(273887),
  Muzzle                                = Spell(187707),
  PoisonInjection                       = Spell(378014),
  ScareBeast                            = Spell(1513),
  SerpentSting                          = Spell(271788),
  Stampede                              = Spell(201430),
  SteelTrap                             = Spell(162488),
  TarTrap                               = Spell(187698),
  WailingArrow                          = Spell(392060),
  -- Buffs
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  DeathblowBuff                         = Spell(378770),
  JunkmaestrosBuff                      = Spell(1219661), -- Buff from Junkmaestro's Mega Magnet
  SeethingRageBuff                      = Spell(408835), -- Buff from Djaruun
  -- Debuffs
  HuntersMarkDebuff                     = Spell(257284),
  LatentPoisonDebuff                    = Spell(336903),
  SerpentStingDebuff                    = Spell(271788),
  TarTrapDebuff                         = Spell(135299),
  -- Misc
  PoolFocus                             = Spell(999910),
}

Spell.Hunter.DarkRanger = {
  -- Abilities
  BlackArrow                            = Spell(466930),
  -- Talents
  BlackArrowTalent                      = Spell(466932),
  BleakArrows                           = Spell(467749),
  BleakArrowsBMAbility                  = Spell(472084),
  BleakArrowsMMAbility                  = Spell(467914),
  BleakPowder                           = Spell(467911),
  PhantomPain                           = Spell(467941),
  PhantomPainAbility                    = Spell(468019),
  ShadowHounds                          = Spell(430707),
  ShadowHoundsAbility                   = Spell(444269),
  WitheringFire                         = Spell(466990),
  WitheringFireBlackArrow               = Spell(468037),
  -- Buffs
  WitheringFireBuff                     = Spell(466991),
  WitheringFireBuildUp                  = Spell(468074),
  WitheringFireReady                    = Spell(468075),
  -- Debuffs
  BlackArrowDebuff                      = Spell(468572),
}

Spell.Hunter.PackLeader = {
  -- Talents
  HowlofthePackLeader                   = Spell(471876),
  -- Buffs
  HogstriderBuff                        = Spell(472640),
  HowlofthePackBuff                     = Spell(462515),
  HowlofthePackLeaderCDBuff             = Spell(471877),
  PackCoordinationBuff                  = Spell(445695),
  ScatteredPreyBuff                     = Spell(461866),
  -- Howl of the Pack Leader Summon Buffs
  HowlBearBuff                          = Spell(472325),
  HowlBoarBuff                          = Spell(472324),
  HowlWyvernBuff                        = Spell(471878),
}

Spell.Hunter.Sentinel = {
  -- Talents
  CrescentSteel                         = Spell(450385),
  LunarStorm                            = Spell(450385),
  Sentinel                              = Spell(450369),
  SymphonicArsenal                      = Spell(450383),
  SymphonicArsenalAbility               = Spell(451194),
  -- Debuffs
  CrescentSteelDebuff                   = Spell(451531),
  SentinelDebuff                        = Spell(450387),
  SentinelTick                          = Spell(450412),
  -- Lunar Storm Spells
  LunarStormAbility                     = Spell(1217459),
  LunarStormPeriodicTrigger             = Spell(450978),
  LunarStormPeriodicAbility             = Spell(450883),
  LunarStormReadyBuff                   = Spell(451805),
  LunarStormCDBuff                      = Spell(451803),
}

Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  -- Pet Abilities
  Bite                                 = Spell(17253, "Pet"),
  BloodBolt                            = Spell(288962, "Pet"),
  Claw                                 = Spell(16827, "Pet"),
  Growl                                = Spell(2649, "Pet"),
  Smack                                = Spell(49966, "Pet"),
  -- Talents
  AMurderofCrows                        = Spell(131894),
  AnimalCompanion                       = Spell(267116),
  AspectoftheWild                       = Spell(193530),
  BarbedScales                          = Spell(469880),
  BarbedShot                            = Spell(217200),
  BeastCleave                           = Spell(115939),
  BestialWrath                          = Spell(19574),
  Bloodshed                             = Spell(321530),
  BloodyFrenzy                          = Spell(407412),
  CalloftheWild                         = Spell(359844),
  CobraShot                             = Spell(193455),
  DireBeast                             = Spell(120679),
  DireCleave                            = Spell(1217524),
  DireFrenzy                            = Spell(385810),
  HuntmastersCall                       = Spell(459730),
  KillCleave                            = Spell(378207),
  KillCommand                           = Spell(34026),
  KillShot                              = Spell(53351),
  KillerCobra                           = Spell(199532),
  MultiShot                             = Spell(2643),
  OneWithThePack                        = Spell(199528),
  PoisonedBarbs                         = Spell(1217535),
  Savagery                              = Spell(424557),
  ScentofBlood                          = Spell(193532),
  SolitaryCompanion                     = Spell(474746),
  Stomp                                 = Spell(199530),
  ThunderingHooves                      = Spell(459693),
  WildCall                              = Spell(185789),
  WildInstincts                         = Spell(378442),
  -- Buffs
  AspectoftheWildBuff                   = Spell(193530),
  BeastCleavePetBuff                    = Spell(118455, "Pet"),
  BeastCleaveBuff                       = Spell(268877),
  BestialWrathBuff                      = Spell(19574),
  BestialWrathPetBuff                   = Spell(186254, "Pet"),
  CalloftheWildBuff                     = Spell(359844),
  FrenzyPetBuff                         = Spell(272790, "Pet"),
  HuntersPreyBuff                       = Spell(378215),
  HuntmastersCallBuff                   = Spell(459731),
  SolitaryCompanionBuff                 = Spell(474751),
  -- Debuffs
  BarbedShotDebuff                      = Spell(217200),
  LacerationDebuff                      = Spell(459555), -- "laceration_driver"
  LacerationBleedDebuff                 = Spell(459560),
})
Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.BeastMastery, Spell.Hunter.DarkRanger)
Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.BeastMastery, Spell.Hunter.PackLeader)

Spell.Hunter.Marksmanship = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  SteadyShot                            = Spell(56641),
  SteadyShotEnergize                    = Spell(77443),
  -- Talents
  AimedShot                             = Spell(19434),
  AspectoftheHydra                      = Spell(470945),
  Bulletstorm                           = Spell(389019),
  Bullseye                              = Spell(204089),
  BurstingShot                          = Spell(186387),
  CarefulAim                            = Spell(260228),
  ChimaeraShot                          = Spell(342049),
  DoubleTap                             = Spell(260402),
  Headshot                              = Spell(471363),
  InTheRhythm                           = Spell(407404),
  KillShot                              = Spell(53351),
  LegacyoftheWindrunners                = Spell(406425),
  LoneWolf                              = Spell(155228),
  MultiShot                             = Spell(257620),
  NoScope                               = Spell(473385),
  OhnahranWinds                         = Spell(1215021),
  PreciseShots                          = Spell(260240),
  PrecisionDetonation                   = Spell(471369),
  RapidFire                             = Spell(257044),
  RapidFireTick                         = Spell(257045),
  RapidFireEnergize                     = Spell(263585),
  RapidFireBarrage                      = Spell(459800),
  RazorFragments                        = Spell(384790),
  Readiness                             = Spell(389865),
  Salvo                                 = Spell(400456),
  SerpentstalkersTrickery               = Spell(378888),
  SmallGameHunter                       = Spell(459802),
  SteadyFocus                           = Spell(193533),
  Streamline                            = Spell(260367),
  SurgingShots                          = Spell(391559),
  TrickShots                            = Spell(257621),
  Trueshot                              = Spell(288613),
  UnbreakableBond                       = Spell(1223323),
  Volley                                = Spell(260243),
  VolleyDmg                             = Spell(260247),
  WindrunnerQuiver                      = Spell(473523),
  WindrunnersGuidance                   = Spell(378905),
  -- Buffs
  BombardmentBuff                       = Spell(386875),
  BulletstormBuff                       = Spell(389020),
  DoubleTapBuff                         = Spell(260402),
  InTheRhythmBuff                       = Spell(407405),
  LockandLoadBuff                       = Spell(194594),
  MovingTargetBuff                      = Spell(474293),
  OnTargetBuff                          = Spell(474257),
  PrecisionDetonationBuff               = Spell(474199),
  PreciseShotsBuff                      = Spell(260242),
  RazorFragmentsBleed                   = Spell(385638),
  RazorFragmentsBuff                    = Spell(388998),
  SalvoBuff                             = Spell(400456),
  StreamlineBuff                        = Spell(342076),
  TrickShotsBuff                        = Spell(257622),
  TrueshotBuff                          = Spell(288613),
  VolleyBuff                            = Spell(260243),
  -- Debuffs
  KillZoneDebuff                        = Spell(393480),
  OhnahranWindsDebuff                   = Spell(1215057),
  ShrapnelShotDebuff                    = Spell(474310),
  SpottersMarkDebuff                    = Spell(466872),
  -- Legendaries
  EagletalonsTrueFocusBuff              = Spell(336851),
})
Spell.Hunter.Marksmanship = MergeTableByKey(Spell.Hunter.Marksmanship, Spell.Hunter.DarkRanger)
Spell.Hunter.Marksmanship = MergeTableByKey(Spell.Hunter.Marksmanship, Spell.Hunter.Sentinel)

Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  -- Pet Abilities
  Bite                                 = Spell(17253, "Pet"),
  BloodBolt                            = Spell(288962, "Pet"),
  Claw                                 = Spell(16827, "Pet"),
  Growl                                = Spell(2649, "Pet"),
  Smack                                = Spell(49966, "Pet"),
  -- Talents
  AspectoftheEagle                      = Spell(186289),
  Bombardier                            = Spell(389880),
  BorntoKill                            = Spell(1217434),
  Butchery                              = Spell(212436),
  ContagiousReagents                    = Spell(459741),
  CoordinatedAssault                    = Spell(360952),
  CulltheHerd                           = Spell(1217429),
  FlankingStrike                        = Spell(269751),
  FuryoftheEagle                        = Spell(203415),
  Harpoon                               = Spell(190925),
  KillCommand                           = Spell(259489),
  KillShot                              = Spell(320976),
  MercilessBlow                         = Spell(459868),
  MongooseBite                          = Spell(259387),
  MongooseBiteEagle                     = Spell(265888),
  MongooseFury                          = Spell(259388),
  RaptorStrike                          = Spell(186270),
  RaptorStrikeEagle                     = Spell(265189),
  RelentlessPrimalFerocity              = Spell(459922),
  RuthlessMarauder                      = Spell(385718),
  SicEm                                 = Spell(459920),
  Spearhead                             = Spell(360966),
  SymbioticAdrenaline                   = Spell(459875),
  WildfireArsenal                       = Spell(321290),
  WildfireBomb                          = Spell(259495),
  -- Buffs
  BombardierBuff                        = Spell(459859),
  CoordinatedAssaultBuff                = Spell(360952),
  CulltheHerdBuff                       = Spell(1217430),
  ExposedFlankBuff                      = Spell(459864),
  FlankingStrikeBuff                    = Spell(269752),
  FrenzyStrikesBuff                     = Spell(1217377),
  MongooseFuryBuff                      = Spell(259388),
  RelentlessPrimalFerocityBuff          = Spell(459962),
  RuthlessMarauderBuff                  = Spell(470070),
  SerpentStingDebuff                    = Spell(259491),
  SicEmBuff                             = Spell(461409),
  StrikeItRichBuff                      = Spell(1216879), -- TWW S2 4pc
  TipoftheSpearBuff                     = Spell(260286),
  TipoftheSpearExpBuff                  = Spell(460852),
  TipoftheSpearFotEBuff                 = Spell(471536),
  WildfireArsenalBuff                   = Spell(1223701),
  -- Debuffs
  BloodseekerDebuff                     = Spell(259277),
  MercilessBlowFlankingDebuff           = Spell(1217375),
  MercilessBlowButcheryDebuff           = Spell(459870),
  SpearheadBleed                        = Spell(378957),
  SpearheadDebuff                       = Spell(1221386),
})
Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Survival, Spell.Hunter.PackLeader)
Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Survival, Spell.Hunter.Sentinel)

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Commons = {
  -- Trinkets kept for variables
  HouseofCards                          = Item(230027, {13, 14}),
  -- TWW Trinkets
  JunkmaestrosMegaMagnet                = Item(230189, {13, 14}),
}

Item.Hunter.BeastMastery = MergeTableByKey(Item.Hunter.Commons, {
})

Item.Hunter.Marksmanship = MergeTableByKey(Item.Hunter.Commons, {
})

Item.Hunter.Survival = MergeTableByKey(Item.Hunter.Commons, {
  -- DF Trinkets
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  ManicGrieftorch                       = Item(194308, {13, 14}),
  -- TWW Trinkets
  ImperfectAscendancySerum              = Item(225654, {13, 14}),
  MadQueensMandate                      = Item(212454, {13, 14}),
  SkardynsGrace                         = Item(133282, {13, 14}),
})