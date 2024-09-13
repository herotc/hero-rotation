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
if not Spell.Warrior then Spell.Warrior = {} end
Spell.Warrior.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  BattleShout                           = Spell(6673),
  BattleStance                          = Spell(386164),
  Charge                                = Spell(100),
  HeroicThrow                           = Spell(57755),
  Pummel                                = Spell(6552),
  Slam                                  = Spell(1464),
  VictoryRush                           = Spell(34428),
  DefensiveStance                       = Spell(386208),
  -- Talents
  Avatar                                = Spell(107574),
  BerserkerRage                         = Spell(18499),
  BerserkersTorment                     = Spell(390123),
  Bladestorm                            = MultiSpell(227847, 389774, 446035),
  BloodandThunder                       = Spell(384277),
  ChampionsMight                        = Spell(386284),
  ChampionsSpear                        = Spell(376079),
  DoubleTime                            = Spell(103827),
  CrushingForce                         = Spell(382764),
  FrothingBerserker                     = Spell(215571),
  Hurricane                             = Spell(390563),
  ImmovableObject                       = Spell(394307),
  IntimidatingShout                     = Spell(5246),
  HeroicLeap                            = Spell(6544),
  ImpendingVictory                      = Spell(202168),
  OverwhelmingRage                      = Spell(382767),
  RallyingCry                           = Spell(97462),
  Ravager                               = Spell(228920),
  RumblingEarth                         = Spell(275339),
  Shockwave                             = Spell(46968),
  SonicBoom                             = Spell(390725),
  SpellReflection                       = Spell(23920),
  StormBolt                             = Spell(107570),
  ThunderClap                           = Spell(6343),
  ThunderousRoar                        = Spell(384318),
  TitanicThrow                          = Spell(384090),
  WarlordsTorment                       = Spell(390140),
  WreckingThrow                         = Spell(384110),
  -- Buffs
  AvatarBuff                            = Spell(107574),
  BattleShoutBuff                       = Spell(6673),
  ChampionsMightBuff                    = Spell(386286),
  HurricaneBuff                         = Spell(390581),
  WarMachineBuff                        = Spell(262232),
  -- Debuffs
  ChampionsMightDebuff                  = Spell(376080),
  MarkofFyralathDebuff                  = Spell(414532),
  RavagerDebuff                         = Spell(228920), -- Dummy Debuff entry. Actually handled in Events.
  ThunderousRoarDebuff                  = Spell(397364),
  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Warrior.Colossus = {
  -- Talents
  Demolish                              = Spell(436358),
  -- Buffs
  ColossalMightBuff                     = Spell(440989),
}

Spell.Warrior.MountainThane = {
  -- Abilities
  ThunderBlastAbility                   = Spell(435222),
  -- Talents
  CrashingThunder                       = Spell(436707),
  LightningStrikes                      = Spell(434969),
  ThunderBlast                          = Spell(435607),
  -- Buffs
  BurstofPowerBuff                      = Spell(437121),
  ThunderBlastBuff                      = Spell(435615),
}

Spell.Warrior.Slayer = {
  -- Talents
  SlayersDominance                      = Spell(444767),
  -- Buffs
  BrutalFinishBuff                      = Spell(446918),
  ImminentDemiseBuff                    = Spell(445606),
  OpportunistBuff                       = Spell(456120),
  -- Debuffs
  MarkedforExecutionDebuff              = Spell(445584),
}

Spell.Warrior.Arms = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  Execute                               = MultiSpell(163201, 281000),
  Whirlwind                             = Spell(1680),
  -- Talents
  BlademastersTorment                   = Spell(390138),
  Bloodletting                          = Spell(383154),
  Cleave                                = Spell(845),
  ColossusSmash                         = MultiSpell(167105, 262161),
  Dreadnaught                           = Spell(262150),
  ExecutionersPrecision                 = Spell(386634),
  FervorofBattle                        = Spell(202316),
  Massacre                              = Spell(281001),
  MercilessBonegrinder                  = Spell(383317),
  MortalStrike                          = Spell(12294),
  Overpower                             = Spell(7384),
  Rend                                  = Spell(772),
  Skullsplitter                         = Spell(260643),
  SweepingStrikes                       = Spell(260708),
  Unhinged                              = Spell(386628),
  Warbreaker                            = Spell(262161),
  -- Buffs
  CollateralDamageBuff                  = Spell(334783),
  JuggernautBuff                        = Spell(383290),
  LethalBlowsBuff                       = Spell(455485), -- TWW S1 4pc
  MartialProwessBuff                    = Spell(7384),
  MercilessBonegrinderBuff              = Spell(383316),
  StrikeVulnerabilitiesBuff             = Spell(394173),
  SuddenDeathBuff                       = Spell(52437),
  SweepingStrikesBuff                   = Spell(260708),
  -- Debuffs
  ColossusSmashDebuff                   = Spell(208086),
  ExecutionersPrecisionDebuff           = Spell(386633),
  RendDebuff                            = Spell(388539),
})
Spell.Warrior.Arms = MergeTableByKey(Spell.Warrior.Arms, Spell.Warrior.Colossus)
Spell.Warrior.Arms = MergeTableByKey(Spell.Warrior.Arms, Spell.Warrior.Slayer)

Spell.Warrior.Fury = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  BerserkerStance                       = Spell(386196),
  Bloodbath                             = Spell(335096),
  CrushingBlow                          = Spell(335097),
  Execute                               = MultiSpell(5308, 280735),
  Whirlwind                             = Spell(190411),
  -- Talents
  AngerManagement                       = Spell(152278),
  AshenJuggernaut                       = Spell(392536),
  Bloodthirst                           = Spell(23881),
  DancingBlades                         = Spell(391683),
  ImprovedWhilwind                      = Spell(12950),
  Massacre                              = Spell(206315),
  MeatCleaver                           = Spell(280392),
  OdynsFury                             = Spell(385059),
  Onslaught                             = Spell(315720),
  RagingBlow                            = Spell(85288),
  Rampage                               = Spell(184367),
  RecklessAbandon                       = Spell(396749),
  Recklessness                          = Spell(1719),
  SlaughteringStrikes                   = Spell(388004),
  Tenderize                             = Spell(388933),
  TitanicRage                           = Spell(394329),
  TitansTorment                         = Spell(390135),
  Unhinged                              = Spell(386628),
  ViciousContempt                       = Spell(383885),
  WrathandFury                          = Spell(392936),
  -- Buffs
  AshenJuggernautBuff                   = Spell(392537),
  BloodbathBuff                         = Spell(461288),
  BloodcrazeBuff                        = Spell(393951),
  CrushingBlowBuff                      = Spell(396752),
  DancingBladesBuff                     = Spell(391688),
  EnrageBuff                            = Spell(184362),
  FuriousBloodthirstBuff                = Spell(423211), -- T31 2pc
  MeatCleaverBuff                       = Spell(85739),
  MercilessAssaultBuff                  = Spell(409983),
  RecklessnessBuff                      = Spell(1719),
  SuddenDeathBuff                       = Spell(280776),
  -- Debuffs
  GushingWoundDebuff                    = Spell(385042),
  OdynsFuryDebuff                       = Spell(385060),
})
Spell.Warrior.Fury = MergeTableByKey(Spell.Warrior.Fury, Spell.Warrior.MountainThane)
Spell.Warrior.Fury = MergeTableByKey(Spell.Warrior.Fury, Spell.Warrior.Slayer)

Spell.Warrior.Protection = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  Devastate                             = Spell(20243),
  Execute                               = Spell(163201),
  ShieldBlock                           = Spell(2565),
  ShieldSlam                            = Spell(23922),
  -- Talents
  Avatar                                = Spell(401150),
  BarbaricTraining                      = Spell(390675),
  Bolster                               = Spell(280001),
  BoomingVoice                          = Spell(202743),
  ChampionsBulwark                      = Spell(386328),
  DemoralizingShout                     = Spell(1160),
  EnduringDefenses                      = Spell(386027),
  HeavyRepercussions                    = Spell(203177),
  IgnorePain                            = Spell(190456),
  Intervene                             = Spell(3411),
  ImpenetrableWall                      = Spell(384072),
  Juggernaut                            = Spell(393967),
  LastStand                             = Spell(12975),
  Massacre                              = Spell(281001),
  Rend                                  = Spell(394062),
  Revenge                               = Spell(6572),
  SeismicReverberation                  = Spell(382956),
  ShieldCharge                          = Spell(385952),
  ShieldWall                            = Spell(871),
  SuddenDeath                           = Spell(29725),
  UnnervingFocus                        = Spell(384042),
  UnstoppableForce                      = Spell(275336),
  -- Buffs
  AvatarBuff                            = Spell(401150),
  EarthenTenacityBuff                   = Spell(410218), -- T30 4P
  FervidBuff                            = Spell(425517), -- T31 2P
  LastStandBuff                         = Spell(12975),
  RallyingCryBuff                       = Spell(97463),
  RevengeBuff                           = Spell(5302),
  SeeingRedBuff                         = Spell(386486),
  ShieldBlockBuff                       = Spell(132404),
  ShieldWallBuff                        = Spell(871),
  SuddenDeathBuff                       = Spell(52437),
  ViolentOutburstBuff                   = Spell(386478),
  VanguardsDeterminationBuff            = Spell(394056), -- T29 2P
  -- Debuffs
  RendDebuff                            = Spell(388539),
})
Spell.Warrior.Protection = MergeTableByKey(Spell.Warrior.Protection, Spell.Warrior.Colossus)
Spell.Warrior.Protection = MergeTableByKey(Spell.Warrior.Protection, Spell.Warrior.MountainThane)

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Commons = {
  -- DF Trinkets
  AlgetharPuzzleBox                     = Item(193701, {13, 14}),
  -- TWW Trinkets
  TreacherousTransmitter                = Item(221023, {13, 14}),
  -- Other Items
  Fyralath                              = Item(206448, {16}),
}

Item.Warrior.Fury = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Arms = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Protection = MergeTableByKey(Item.Warrior.Commons, {
})
