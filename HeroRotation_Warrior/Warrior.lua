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
  Charge                                = Spell(100),
  HeroicThrow                           = Spell(57755),
  Pummel                                = Spell(6552),
  Slam                                  = Spell(1464),
  VictoryRush                           = Spell(34428),
  -- Talents
  Avatar                                = Spell(107574),
  DoubleTime                            = Spell(103827),
  FrothingBerserker                     = Spell(215571),
  IntimidatingShout                     = Spell(5246),
  HeroicLeap                            = Spell(6544),
  ImpendingVictory                      = Spell(202168),
  OverwhelmingRage                      = Spell(382767),
  Shockwave                             = Spell(46968),
  SpearofBastion                        = Spell(376079),
  StormBolt                             = Spell(107570),
  ThunderousRoar                        = Spell(384318),
  TitansTorment                         = Spell(390135),
  WreckingThrow                         = Spell(384110),
  -- Buffs
  AvatarBuff                            = Spell(107574),
  BattleShoutBuff                       = Spell(6673),
  -- Debuffs
  SpearofBastionDebuff                  = Spell(376080),
  -- Covenant Abilities (Shadowlands)
  AncientAftershock                     = Spell(325886),
  Condemn                               = MultiSpell(330325, 330334, 317485, 317349),
  CondemnDebuff                         = Spell(317491),
  ConquerorsBanner                      = Spell(324143),
  ConquerorsFrenzyBuff                  = Spell(343672),
  ElysianMightBuff                      = Spell(311193),
  Fleshcraft                            = Spell(324631),
  SpearofBastionCov                     = Spell(307865),
  SpearofBastionCovBuff                 = Spell(307871),
  -- Conduits (Shadowlands)
  MercilessBonegrinder                  = Spell(335260),
  MercilessBonegrinderBuff              = Spell(346574),
  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Warrior.Fury = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  Bloodbath                             = Spell(335096),
  CrushingBlow                          = Spell(335097),
  Execute                               = MultiSpell(5308, 280735),
  Whirlwind                             = Spell(190411),
  -- Talents
  Annihilator                           = Spell(383916),
  Bloodthirst                           = Spell(23881),
  Cruelty                               = Spell(392931),
  Frenzy                                = Spell(335077),
  Massacre                              = Spell(206315),
  MeatCleaver                           = Spell(280392),
  OdynsFury                             = Spell(385059),
  Onslaught                             = Spell(315720),
  RagingBlow                            = Spell(85288),
  Rampage                               = Spell(184367),
  Ravager                               = Spell(228920),
  RecklessAbandon                       = Spell(202751),
  Recklessness                          = Spell(1719),
  SuddenDeath                           = Spell(280721),
  Tenderize                             = Spell(388933),
  -- Buffs
  EnrageBuff                            = Spell(184362),
  FrenzyBuff                            = Spell(335082),
  MeatCleaverBuff                       = Spell(85739),
  RecklessnessBuff                      = Spell(1719),
  SuddenDeathBuff                       = Spell(280776),
  -- Debuffs
  SiegebreakerDebuff                    = Spell(280773),
  -- Conduits (Shadowlands)
  ViciousContempt                       = Spell(337302),
  -- Legendary Effects (Shadowlands)
  WilloftheBerserkerBuff                = Spell(335594),
})

Spell.Warrior.Arms = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  Execute                               = MultiSpell(163201, 281000),
  Whirlwind                             = Spell(1680),
  -- Talents
  AngerManagement                       = Spell(152278),
  Bladestorm                            = Spell(227847),
  Cleave                                = Spell(845),
  CollateralDamage                      = Spell(334779),
  ColossusSmash                         = Spell(167105),
  Dreadnaught                           = Spell(262150),
  ExecutionersPrecision                 = Spell(386634),
  FervorofBattle                        = Spell(202316),
  Hurricane                             = Spell(390563),
  InfortheKill                          = Spell(248621),
  MartialProwess                        = Spell(316440),
  Massacre                              = Spell(281001),
  MortalStrike                          = Spell(12294),
  Overpower                             = Spell(7384),
  Rend                                  = Spell(772),
  Skullsplitter                         = Spell(260643),
  SuddenDeath                           = Spell(29725),
  SweepingStrikes                       = Spell(260708),
  SweepingStrikesBuff                   = Spell(260708),
  TestofMight                           = Spell(385008),
  TideofBlood                           = Spell(386357),
  Unhinged                              = Spell(386628),
  Warbreaker                            = Spell(262161),
  Ravager                               = Spell(228920),
  -- Buffs
  MartialProwessBuff                    = Spell(7384),
  SuddenDeathBuff                       = Spell(52437),
  TestofMightBuff                       = Spell(385013),
  WarMachineBuff                        = Spell(262231),
  JuggernautBuff                        = Spell(383292),
  -- Debuffs
  ColossusSmashDebuff                   = Spell(208086),
  DeepWoundsDebuff                      = Spell(262115),
  ExecutionersPrecisionDebuff           = Spell(386633),
  RendDebuff                            = Spell(388539),
  -- Conduits (Shadowlands)
  AshenJuggernaut                       = Spell(335232),
  AshenJuggernautBuff                   = Spell(335234),
  BattlelordBuff                        = Spell(346369),
  ExploiterDebuff                       = Spell(335452),
})

Spell.Warrior.Protection = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  DemoralizingShout                     = Spell(1160),
  Devastate                             = Spell(20243),
  Execute                               = Spell(163201),
  IgnorePain                            = Spell(190456),
  Intervene                             = Spell(3411),
  LastStand                             = Spell(12975),
  LastStandBuff                         = Spell(12975),
  Revenge                               = Spell(6572),
  RevengeBuff                           = Spell(5302),
  ShieldBlock                           = Spell(2565),
  ShieldBlockBuff                       = Spell(132404),
  ShieldSlam                            = Spell(23922),
  ThunderClap                           = Spell(6343),
  -- Talents
  BoomingVoice                          = Spell(202743),
  Ravager                               = Spell(228920),
  UnstoppableForce                      = Spell(275336),
  -- Tier Effects
  OutburstBuff                          = Spell(364010),
  SeeingRedBuff                         = Spell(364006),
})

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Commons = {
  -- Potions
  PotionofPhantomFire                   = Item(171349),
  PotionofSpectralStrength              = Item(171275),
  -- Trinkets
  DDVoracity                            = Item(173087, {13, 14}),
  FlameofBattle                         = Item(181501, {13, 14}),
  GrimCodex                             = Item(178811, {13, 14}),
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  InstructorsDivineBell                 = Item(184842, {13, 14}),
  MacabreSheetMusic                     = Item(184024, {13, 14}),
  OverwhelmingPowerCrystal              = Item(179342, {13, 14}),
  WakenersFrond                         = Item(181457, {13, 14}),
  -- Gladiator's Badges
  SinfulGladiatorsBadge                 = Item(175921, {13, 14}),
  UnchainedGladiatorsBadge              = Item(185197, {13, 14}),
}

Item.Warrior.Fury = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Arms = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Protection = MergeTableByKey(Item.Warrior.Commons, {
})
