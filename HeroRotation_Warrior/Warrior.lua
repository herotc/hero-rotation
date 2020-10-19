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
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  
  -- Abilities
  RecklessnessBuff                      = Spell(1719),
  Recklessness                          = Spell(1719),
  HeroicLeap                            = Spell(6544),
  Rampage                               = Spell(184367),
  EnrageBuff                            = Spell(184362),
  Execute                               = MultiSpell(5308, 280735),
  Bloodthirst                           = Spell(23881),
  Bloodbath                             = Spell(335096),
  CrushingBlow                          = Spell(335097),
  RagingBlow                            = Spell(85288),
  Bladestorm                            = Spell(46924),
  Whirlwind                             = Spell(190411),
  Charge                                = Spell(100),
  FujiedasFuryBuff                      = Spell(207775),
  MeatCleaverBuff                       = Spell(85739),
  Pummel                                = Spell(6552),
  IntimidatingShout                     = Spell(5246),
  
  -- Talents
  DragonRoar                            = Spell(118000),
  FrothingBerserker                     = Spell(215571),
  Massacre                              = Spell(206315),
  Onslaught                             = Spell(315720),
  RecklessAbandon                       = Spell(202751),
  SuddenDeath                           = Spell(280721),
  SuddenDeathBuff                       = Spell(280776),
  Siegebreaker                          = Spell(280772),
  SiegebreakerDebuff                    = Spell(280773),
  StormBolt                             = Spell(107570),
  
  -- Covenant Abilities

  -- Legendary Effects

  -- Conduits

  -- Item Buffs/Debuffs
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  NoxiousVenomDebuff                    = Spell(267410),
  
  -- Azerite Traits (BfA)
  ColdSteelHotBlood                     = Spell(288080),

  -- Essences (BfA)
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  LifebloodBuff                         = MultiSpell(295137, 305694),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RecklessForceCounter                  = MultiSpell(298409, 302917),
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186)
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
  
  -- Legendary Effects
  
  -- Conduits
  
  -- Item Buffs/Debuffs
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  
  -- Azerite Traits (BfA)
  CrushingAssaultBuff                   = Spell(278826),
  SeismicWave                           = Spell(277639),
  TestofMight                           = Spell(275529),
  TestofMightBuff                       = Spell(275540),
  
  -- Essences (BfA)
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  GuardianofAzerothBuff                 = Spell(295855),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RippleInSpace                         = Spell(302731),
  SeethingRageBuff                      = Spell(297126),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
}

-- Items
if not Item.Warrior then Item.Warrior = {} end
Item.Warrior.Fury = {
  PotionofUnbridledFury            = Item(169299),
  GrongsPrimalRage                 = Item(165574, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
}

Item.Warrior.Arms = {
  PotionofUnbridledFury            = Item(169299),
  GrongsPrimalRage                 = Item(165574, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
}