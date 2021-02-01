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

-- Spells
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Blood = {
  -- Abilities
  Asphyxiate                            = Spell(221562),
  BloodBoil                             = Spell(50842),
  DancingRuneWeapon                     = Spell(49028),
  DeathandDecay                         = Spell(43265),
  DeathsCaress                          = Spell(195292),
  DeathStrike                           = Spell(49998),
  HeartStrike                           = Spell(206930),
  IceboundFortitude                     = Spell(48792),
  Marrowrend                            = Spell(195182),
  RaiseDead                             = Spell(46585),
  RuneTap                               = Spell(194679),
  SacrificialPact                       = Spell(327574),
  VampiricBlood                         = Spell(55233),
  -- Talents
  Blooddrinker                          = Spell(206931),
  BloodTap                              = Spell(221699),
  Bonestorm                             = Spell(194844),
  Consumption                           = Spell(274156),
  Heartbreaker                          = Spell(221536),
  RapidDecomposition                    = Spell(194662),
  RelishinBlood                         = Spell(317610),
  Tombstone                             = Spell(219809),
  -- Covenant Abilities
  AbominationLimb                       = Spell(315443),
  AbominationLimbBuff                   = Spell(315443),
  DeathsDue                             = Spell(324128),
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  -- Conduit Effects
  -- Buffs
  BoneShieldBuff                        = Spell(195181),
  CrimsonScourgeBuff                    = Spell(81141),
  DancingRuneWeaponBuff                 = Spell(81256),
  HemostasisBuff                        = Spell(273947),
  IceboundFortitudeBuff                 = Spell(48792),
  RuneTapBuff                           = Spell(194679),
  UnholyStrengthBuff                    = Spell(53365),
  VampiricBloodBuff                     = Spell(55233),
  -- Debuffs
  BloodPlagueDebuff                     = Spell(55078),
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  ArcanePulse                           = Spell(260364),
  Fireblood                             = Spell(265221),
  -- Interrupts
  MindFreeze                            = Spell(47528),
  -- Custom
  Pool                                  = Spell(999910)
}

Spell.DeathKnight.Frost = {
  -- Abilities
  RaiseDead                             = Spell(46585),
  SacrificialPact                       = Spell(327574),
  DeathAndDecay                         = Spell(43265),
  DeathStrike                           = Spell(49998),
  RemorselessWinter                     = Spell(196770),
  FrostStrike                           = Spell(49143),
  Obliterate                            = Spell(49020),
  HowlingBlast                          = Spell(49184),
  ChainsofIce                           = Spell(45524),
  FrostwyrmsFury                        = Spell(279302),
  EmpowerRuneWeapon                     = Spell(47568),
  PillarofFrost                         = Spell(51271),
  -- Talents
  Avalanche                             = Spell(207142),
  Asphyxiate                            = Spell(108194),
  GatheringStorm                        = Spell(194912),
  GlacialAdvance                        = Spell(194913),
  IcyTalons                             = Spell(194878),
  Frostscythe                           = Spell(207230),
  RunicAttenuation                      = Spell(207104),
  FrozenPulse                           = Spell(194909),
  HornofWinter                          = Spell(57330),
  ColdHeart                             = Spell(281208),
  HypothermicPresence                   = Spell(321995),
  Icecap                                = Spell(207126),
  Obliteration                          = Spell(281238),
  BreathofSindragosa                    = Spell(152279),
  -- Covenant Abilities
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  AbominationLimb                       = Spell(315443),
  DeathsDue                             = Spell(324128),
  -- Conduit Effects
  EradicatingBlow                       = Spell(337934),
  BitingCold                            = Spell(337988),
  UnleashedFrenzy                       = Spell(338492),
  Everfrost                             = Spell(337988),
  -- Buffs
  DeathAndDecayBuff                     = Spell(188290),
  RimeBuff                              = Spell(59052),
  KillingMachineBuff                    = Spell(51124),
  PillarofFrostBuff                     = Spell(51271),
  ColdHeartBuff                         = Spell(281209),
  FrozenPulseBuff                       = Spell(194909),
  EmpowerRuneWeaponBuff                 = Spell(47568),
  DeathStrikeBuff                       = Spell(101568),
  IcyTalonsBuff                         = Spell(194879),
  UnholyStrengthBuff                    = Spell(53365),
  EradicatingBlowBuff                   = Spell(337936),
  UnleashedFrenzyBuff                   = Spell(338501),
  -- Debuffs
  RazoriceDebuff                        = Spell(51714),
  FrostFeverDebuff                      = Spell(55095),
  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcanePulse                           = Spell(260364),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  -- Interrupts
  MindFreeze                            = Spell(47528),
  -- Custom
  PoolRange                             = Spell(999910)
}

Spell.DeathKnight.Unholy = {
  -- Abilities
  Apocalypse                            = Spell(275699),
  ArmyoftheDead                         = Spell(42650),
  DarkTransformation                    = Spell(63560),
  DeathAndDecay                         = Spell(43265),
  DeathCoil                             = Spell(47541),
  DeathStrike                           = Spell(49998),
  Epidemic                              = Spell(207317),
  FesteringStrike                       = Spell(85948),
  Outbreak                              = Spell(77575),
  RaiseDead                             = Spell(46584),
  SacrificialPact                       = Spell(327574),
  ScourgeStrike                         = Spell(55090),

  -- Talents
  ArmyoftheDamned                       = Spell(276837),
  Asphyxiate                            = Spell(108194),
  BurstingSores                         = Spell(207264),
  ClawingShadows                        = Spell(207311),
  Defile                                = Spell(152280),
  Pestilence                            = Spell(277234),
  SoulReaper                            = Spell(343294),
  SummonGargoyle                        = MultiSpell(49206, 207349),
  UnholyAssault                         = Spell(207289),
  UnholyBlight                          = Spell(115989),
  UnholyPact                            = Spell(319230),

  -- Covenant Abilities
  AbominationLimb                       = Spell(315443),
  DeathsDue                             = Spell(324128),
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  SwarmingMistBuff                      = Spell(311648),

  -- Conduit/Soulbind Effects
  ConvocationOfTheDead                  = Spell(338553),
  LeadByExample                         = Spell(342156),

  -- Buffs
  DeathAndDecayBuff                     = Spell(188290),
  DeathStrikeBuff                       = Spell(101568),
  RunicCorruptionBuff                   = Spell(51460),
  SuddenDoomBuff                        = Spell(81340),
  UnholyAssaultBuff                     = Spell(207289),
  UnholyStrengthBuff                    = Spell(53365),

  -- Debuffs
  BloodPlagueDebuff                     = Spell(55078),
  FesteringWoundDebuff                  = Spell(194310),
  FrostFeverDebuff                      = Spell(55095),
  UnholyBlightDebuff                    = Spell(115994),
  VirulentPlagueDebuff                  = Spell(191587),

  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  LightsJudgment                        = Spell(255647),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  ArcanePulse                           = Spell(260364),
  Fireblood                             = Spell(265221),

  -- Interrupts
  MindFreeze                            = Spell(47528),

  -- Custom
  PoolResources                         = Spell(999910)
}

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Blood = {
  -- Potions/Trinkets
  PotionofUnbridledFury                 = Item(169299),
  -- "Other On Use"
}

Item.DeathKnight.Frost = {
  -- Potions/Trinkets
  -- "Other On Use"
}

Item.DeathKnight.Unholy = {
  -- Potions/Trinkets
  PotionofSpectralStrength              = Item(171275),
  DarkmoonDeckVoracity                  = Item(173087),
  DreadfireVessel                       = Item(184030),
  InscrutableQuantumDevice              = Item(179350),
  MacabreSheetMusic                     = Item(184024),
  -- "Other On Use"
}
