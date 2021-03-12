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
if not Spell.Warrior then Spell.Warrior = {} end

Spell.Warrior.Fury = {
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),

  -- Abilities
  BattleShout                           = Spell(6673),
  BattleShoutBuff                       = Spell(6673),
  Bloodbath                             = Spell(335096),
  Bloodthirst                           = Spell(23881),
  Charge                                = Spell(100),
  CrushingBlow                          = Spell(335097),
  EnrageBuff                            = Spell(184362),
  Execute                               = MultiSpell(5308, 280735),
  FujiedasFuryBuff                      = Spell(207775),
  IntimidatingShout                     = Spell(5246),
  HeroicLeap                            = Spell(6544),
  MeatCleaverBuff                       = Spell(85739),
  Pummel                                = Spell(6552),
  RagingBlow                            = Spell(85288),
  Rampage                               = Spell(184367),
  RecklessnessBuff                      = Spell(1719),
  Recklessness                          = Spell(1719),
  VictoryRush                           = Spell(34428),
  Whirlwind                             = Spell(190411),

  -- Talents
  AngerManagement                       = Spell(152278),
  Bladestorm                            = Spell(46924),
  Cruelty                               = Spell(335070),
  DragonRoar                            = Spell(118000),
  Frenzy                                = Spell(335077),
  FrenzyBuff                            = Spell(335077),
  FrothingBerserker                     = Spell(215571),
  ImpendingVictory                      = Spell(202168),
  Massacre                              = Spell(206315),
  Onslaught                             = Spell(315720),
  RecklessAbandon                       = Spell(202751),
  Siegebreaker                          = Spell(280772),
  SiegebreakerDebuff                    = Spell(280773),
  StormBolt                             = Spell(107570),
  SuddenDeath                           = Spell(280721),
  SuddenDeathBuff                       = Spell(280776),

  -- Covenant Abilities
  AncientAftershock                     = Spell(325886),
  Condemn                               = MultiSpell(330325, 317485),
  CondemnDebuff                         = Spell(317491),
  ConquerorsBanner                      = Spell(324143),
  ConquerorsFrenzyBuff                  = Spell(343672),
  SpearofBastion                        = Spell(307865),
  SpearofBastionBuff                    = Spell(307871),

  -- Legendary Effects
  WilloftheBerserkerBuff                = Spell(335594),

  -- Conduits
  MercilessBonegrinder                  = Spell(335260),
  MercilessBonegrinderBuff              = Spell(346574),
  ViciousContempt                       = Spell(337302),

  -- Item Buffs/Debuffs

  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Warrior.Arms = {
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
  BattleShoutBuff                       = Spell(6673),
  Bladestorm                            = Spell(227847),
  Charge                                = Spell(100),
  ColossusSmash                         = Spell(167105),
  ColossusSmashDebuff                   = Spell(208086),
  DeepWoundsDebuff                      = Spell(262115),
  Execute                               = MultiSpell(163201, 281000),
  HeroicLeap                            = Spell(6544),
  IntimidatingShout                     = Spell(5246),
  MortalStrike                          = Spell(12294),
  Overpower                             = Spell(7384),
  OverpowerBuff                         = Spell(7384),
  Pummel                                = Spell(6552),
  Slam                                  = Spell(1464),
  SweepingStrikes                       = Spell(260708),
  SweepingStrikesBuff                   = Spell(260708),
  Whirlwind                             = Spell(1680),

  -- Talents
  AngerManagement                       = Spell(152278),
  Avatar                                = Spell(107574),
  Cleave                                = Spell(845),
  CollateralDamage                      = Spell(334779),
  DeadlyCalm                            = Spell(262228),
  DeadlyCalmBuff                        = Spell(262228),
  Doubletime                            = Spell(103827),
  Dreadnaught                           = Spell(262150),
  FervorofBattle                        = Spell(202316),
  ImpendingVictory                      = Spell(202168),
  Inforthekill                          = Spell(248621),
  Massacre                              = Spell(281001),
  Ravager                               = Spell(152277),
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(772),
  Skullsplitter                         = Spell(260643),
  StormBolt                             = Spell(107570),
  SuddenDeathBuff                       = Spell(52437),
  Warbreaker                            = Spell(262161),
  WarMachineBuff                        = Spell(262231),

  -- Covenant Abilities
  AncientAftershock                     = Spell(325886),
  Condemn                               = MultiSpell(330334, 317349),
  CondemnDebuff                         = Spell(317491),
  ConquerorsBanner                      = Spell(324143),
  ConquerorsFrenzyBuff                  = Spell(343672),
  SpearofBastion                        = Spell(307865),
  SpearofBastionBuff                    = Spell(307871),

  -- Legendary Effects

  -- Conduits
  BattlelordBuff                        = Spell(346369),
  ExploiterDebuff                       = Spell(335452),

  -- Item Buffs/Debuffs

  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Warrior.Protection = {
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),

  -- Abilities
  Avatar                                = Spell(107574),
  AvatarBuff                            = Spell(107574),
  Charge                                = Spell(100),
  DemoralizingShout                     = Spell(1160),
  Devastate                             = Spell(20243),
  Execute                               = Spell(163201),
  IgnorePain                            = Spell(190456),
  IntimidatingShout                     = Spell(5246),
  LastStand                             = Spell(12975),
  LastStandBuff                         = Spell(12975),
  Pummel                                = Spell(6552),
  Revenge                               = Spell(6572),
  RevengeBuff                           = Spell(5302),
  ShieldBlock                           = Spell(2565),
  ShieldBlockBuff                       = Spell(132404),
  ShieldSlam                            = Spell(23922),
  ThunderClap                           = Spell(6343),
  VictoryRush                           = Spell(34428),

  -- Talents
  BoomingVoice                          = Spell(202743),
  DragonRoar                            = Spell(118000),
  ImpendingVictory                      = Spell(202168),
  Ravager                               = Spell(228920),
  StormBolt                             = Spell(107570),
  UnstoppableForce                      = Spell(275336),

  -- Covenant Abilities
  AncientAftershock                     = Spell(325886),
  Condemn                               = Spell(317349),
  CondemnDebuff                         = Spell(317491),
  ConquerorsBanner                      = Spell(324143),
  ConquerorsFrenzyBuff                  = Spell(343672),
  SpearofBastion                        = Spell(307865),
  SpearofBastionBuff                    = Spell(307871),

  -- Legendary Effects

  -- Conduits

  -- Item Buffs/Debuffs

  -- Pool
  Pool                                  = Spell(999910),
}

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Fury = {
  PotionofSpectralStrength         = Item(171275),
  GrimCodex                        = Item(178811, {13, 14}),
  DDVoracity                       = Item(173087, {13, 14}),
}

Item.Warrior.Arms = {
  PotionofSpectralStrength         = Item(171275),
  GrimCodex                        = Item(178811, {13, 14}),
  DDVoracity                       = Item(173087, {13, 14}),
}

Item.Warrior.Protection = {
  PotionofPhantomFire              = Item(171349),
}

