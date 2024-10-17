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
  KillCommand                           = MultiSpell(34026,259489),
  KillShot                              = MultiSpell(53351,320976),
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
  -- Talents
  BlackArrow                            = Spell(430703),
}

Spell.Hunter.PackLeader = {
  -- Talents
  CulltheHerd                           = Spell(445717),
  ViciousHunt                           = Spell(445404),
  -- Buffs
  FuriousAssaultBuff                    = Spell(448814),
}

Spell.Hunter.Sentinel = {
  -- Talents
  LunarStorm                            = Spell(450385),
  SymphonicArsenal                      = Spell(450383),
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
  BarbedShot                            = Spell(217200),
  BeastCleave                           = Spell(115939),
  BestialWrath                          = Spell(19574),
  Bloodshed                             = Spell(321530),
  BloodyFrenzy                          = Spell(407412),
  CalloftheWild                         = Spell(359844),
  CobraShot                             = Spell(193455),
  DireBeast                             = Spell(120679),
  HuntmastersCall                       = Spell(459730),
  KillCleave                            = Spell(378207),
  KillerCobra                           = Spell(199532),
  MultiShot                             = Spell(2643),
  OneWithThePack                        = Spell(199528),
  Savagery                              = Spell(424557),
  ScentofBlood                          = Spell(193532),
  Stomp                                 = Spell(199530),
  VenomsBite                            = Spell(459565),
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
  -- Debuffs
  BarbedShotDebuff                      = Spell(217200),
})
Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.BeastMastery, Spell.Hunter.DarkRanger)
Spell.Hunter.BeastMastery = MergeTableByKey(Spell.Hunter.BeastMastery, Spell.Hunter.PackLeader)

Spell.Hunter.Marksmanship = MergeTableByKey(Spell.Hunter.Commons, {
  -- Abilities
  SteadyShot                            = Spell(56641),
  -- Talents
  AimedShot                             = Spell(19434),
  BurstingShot                          = Spell(186387),
  CarefulAim                            = Spell(260228),
  ChimaeraShot                          = Spell(342049),
  DoubleTap                             = Spell(260402),
  InTheRhythm                           = Spell(407404),
  LegacyoftheWindrunners                = Spell(406425),
  LoneWolf                              = Spell(155228),
  MultiShot                             = Spell(257620),
  RapidFire                             = Spell(257044),
  RapidFireBarrage                      = Spell(459800),
  Salvo                                 = Spell(400456),
  SerpentstalkersTrickery               = Spell(378888),
  SmallGameHunter                       = Spell(459802),
  SteadyFocus                           = Spell(193533),
  Streamline                            = Spell(260367),
  SurgingShots                          = Spell(391559),
  TrickShots                            = Spell(257621),
  Trueshot                              = Spell(288613),
  Volley                                = Spell(260243),
  WindrunnersGuidance                   = Spell(378905),
  -- Buffs
  BombardmentBuff                       = Spell(386875),
  BulletstormBuff                       = Spell(389020),
  DoubleTapBuff                         = Spell(260402),
  InTheRhythmBuff                       = Spell(407405),
  LockandLoadBuff                       = Spell(194594),
  PreciseShotsBuff                      = Spell(260242),
  RazorFragmentsBuff                    = Spell(388998),
  SalvoBuff                             = Spell(400456),
  SteadyFocusBuff                       = Spell(193534),
  TrickShotsBuff                        = Spell(257622),
  TrueshotBuff                          = Spell(288613),
  VolleyBuff                            = Spell(260243),
  -- Debuffs
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
  Butchery                              = Spell(212436),
  ContagiousReagents                    = Spell(459741),
  CoordinatedAssault                    = Spell(360952),
  FlankingStrike                        = Spell(269751),
  FuryoftheEagle                        = Spell(203415),
  Harpoon                               = Spell(190925),
  MercilessBlows                        = Spell(459868),
  MongooseBite                          = Spell(259387),
  MongooseBiteEagle                     = Spell(265888),
  RaptorStrike                          = Spell(186270),
  RaptorStrikeEagle                     = Spell(265189),
  RelentlessPrimalFerocity              = Spell(459922),
  RuthlessMarauder                      = Spell(385718),
  SicEm                                 = Spell(459920),
  Spearhead                             = Spell(360966),
  SymbioticAdrenaline                   = Spell(459875),
  WildfireBomb                          = Spell(259495),
  -- Buffs
  BombardierBuff                        = Spell(459859),
  CoordinatedAssaultBuff                = Spell(360952),
  ExposedFlankBuff                      = Spell(459864),
  MercilessBlowsBuff                    = Spell(459870), -- Exposed Flank buff from Merciless Blows talent. Called buff.merciless_blows in APL.
  MongooseFuryBuff                      = Spell(259388),
  SerpentStingDebuff                    = Spell(259491),
  SicEmBuff                             = Spell(461409),
  TipoftheSpearBuff                     = Spell(260286),
  -- Debuffs
  BloodseekerDebuff                     = Spell(259277),
})
Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Survival, Spell.Hunter.PackLeader)
Spell.Hunter.Survival = MergeTableByKey(Spell.Hunter.Survival, Spell.Hunter.Sentinel)

-- Items
if not Item.Hunter then Item.Hunter = {} end
Item.Hunter.Commons = {
  -- Trinkets kept for variables
  MirrorofFracturedTomorrows            = Item(207581, {13, 14}),
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