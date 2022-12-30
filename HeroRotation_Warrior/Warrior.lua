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
  DefensiveStance                       = Spell(386208),
  -- Talents
  Avatar                                = Spell(107574),
  AvatarBuff                            = Spell(107574),
  BerserkerRage                         = Spell(18499),
  BloodandThunder                       = Spell(384277),
  DoubleTime                            = Spell(103827),
  CrushingForce                         = Spell(382764),
  FrothingBerserker                     = Spell(215571),
  IntimidatingShout                     = Spell(5246),
  HeroicLeap                            = Spell(6544),
  ImpendingVictory                      = Spell(202168),
  OverwhelmingRage                      = Spell(382767),
  RallyingCry                           = Spell(97462),
  Shockwave                             = Spell(46968),
  SonicBoom                             = Spell(390725),
  SpearofBastion                        = Spell(376079),
  SpellReflection                       = Spell(23920),
  StormBolt                             = Spell(107570),
  ThunderClap                           = Spell(396719),
  ThunderousRoar                        = Spell(384318),
  TitanicThrow                          = Spell(384090),
  WarMachineBuff                        = Spell(262232),
  WreckingThrow                         = Spell(384110),
  -- Buffs
  BattleShoutBuff                       = Spell(6673),
  -- Pool
  Pool                                  = Spell(999910),
}

Spell.Warrior.Fury = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  BerserkerStance                       = Spell(386196),
  Bloodbath                             = Spell(335096),
  CrushingBlow                          = Spell(335097),
  Execute                               = MultiSpell(5308, 280735),
  Whirlwind                             = Spell(190411),
  -- Talents
  Annihilator                           = Spell(383916),
  AshenJuggernaut                       = Spell(392536),
  AshenJuggernautBuff                   = Spell(392537),
  Bloodthirst                           = Spell(23881),
  DancingBlades                         = Spell(391683),
  DancingBladesBuff                     = Spell(391688),
  Frenzy                                = Spell(335077),
  FrenzyBuff                            = Spell(335082),
  ImprovedWhilwind                      = Spell(12950),
  MeatCleaver                           = Spell(280392),
  MeatCleaverBuff                       = Spell(85739),
  OdynsFury                             = Spell(385059),
  Onslaught                             = Spell(315720),
  RagingBlow                            = Spell(85288),
  Rampage                               = Spell(184367),
  Ravager                               = Spell(228920),
  RecklessAbandon                       = Spell(396749),
  Recklessness                          = Spell(1719),
  RecklessnessBuff                      = Spell(1719),
  StormofSwords                         = Spell(388903),
  SuddenDeath                           = Spell(280721),
  SuddenDeathBuff                       = Spell(280776),
  Tenderize                             = Spell(388933),
  TitanicRage                           = Spell(394329),
  TitansTorment                         = Spell(390135),
  WrathandFury                          = Spell(392936),
  -- Buffs
  EnrageBuff                            = Spell(184362),
})

Spell.Warrior.Arms = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  BattleStance                          = Spell(386164),
  Execute                               = MultiSpell(163201, 281000),
  Whirlwind                             = Spell(1680),
  -- Talents
  Battlelord                            = Spell(386630),
  BattlelordBuff                        = Spell(386631),
  BlademastersTorment                   = Spell(390138),
  Bladestorm                            = MultiSpell(227847, 389774),
  Cleave                                = Spell(845),
  ColossusSmash                         = MultiSpell(167105, 262161),
  ColossusSmashDebuff                   = Spell(208086),
  Dreadnaught                           = Spell(262150),
  ExecutionersPrecision                 = Spell(386634),
  ExecutionersPrecisionDebuff           = Spell(386633),
  FervorofBattle                        = Spell(202316),
  Hurricane                             = Spell(390563),
  HurricaneBuff                         = Spell(390581),
  Juggernaut                            = Spell(383292),
  JuggernautBuff                        = Spell(383292),
  Massacre                              = Spell(281001),
  MercilessBonegrinder                  = Spell(383317),
  MercilessBonegrinderBuff              = Spell(383316),
  MortalStrike                          = Spell(12294),
  Overpower                             = Spell(7384),
  Rend                                  = Spell(772),
  RendDebuff                            = Spell(388539),
  Skullsplitter                         = Spell(260643),
  StormofSwords                         = Spell(385512),
  SuddenDeath                           = Spell(29725),
  SuddenDeathBuff                       = Spell(52437),
  SweepingStrikes                       = Spell(260708),
  SweepingStrikesBuff                   = Spell(260708),
  TestofMight                           = Spell(385008),
  TestofMightBuff                       = Spell(385013),
  TideofBlood                           = Spell(386357),
  Unhinged                              = Spell(386628),
  Warbreaker                            = Spell(262161),
  WarlordsTorment                       = Spell(390140),
  -- Debuffs
  DeepWoundsDebuff                      = Spell(262115),
})

Spell.Warrior.Protection = MergeTableByKey(Spell.Warrior.Commons, {
  -- Abilities
  BattleStance                          = Spell(386164),
  Devastate                             = Spell(20243),
  Execute                               = Spell(163201),
  ShieldBlock                           = Spell(2565),
  ShieldSlam                            = Spell(23922),
  -- Talents
  BoomingVoice                          = Spell(202743),
  DemoralizingShout                     = Spell(1160),
  IgnorePain                            = Spell(190456),
  Intervene                             = Spell(3411),
  LastStand                             = Spell(12975),
  Ravager                               = Spell(228920),
  Rend                                  = Spell(394062),
  Revenge                               = Spell(6572),
  ShieldCharge                          = Spell(385952),
  ShieldWall                            = Spell(871),
  UnstoppableForce                      = Spell(275336),
  -- Buffs
  LastStandBuff                         = Spell(12975),
  RallyingCryBuff                       = Spell(97463),
  RevengeBuff                           = Spell(5302),
  SeeingRedBuff                         = Spell(386486),
  ShieldBlockBuff                       = Spell(132404),
  ShieldWallBuff                        = Spell(871),
  ViolentOutburstBuff                   = Spell(386478),
  -- Debuffs
})

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Commons = {
  -- Trinkets
  AlgethaPuzzleBox                      = Item(193701, {13, 14}),
  ManicGrieftorch                       = Item(194308, {13, 14}),
}

Item.Warrior.Fury = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Arms = MergeTableByKey(Item.Warrior.Commons, {
})

Item.Warrior.Protection = MergeTableByKey(Item.Warrior.Commons, {
})
