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
if not Spell.DeathKnight then Spell.DeathKnight = {} end
Spell.DeathKnight.Commons = {
  -- Abilities
  DeathAndDecay                         = Spell(43265),
  DeathCoil                             = Spell(47541),
  -- Talents
  AbominationLimb                       = Spell(383269),
  Asphyxiate                            = Spell(221562),
  ChainsofIce                           = Spell(45524),
  CleavingStrikes                       = Spell(316916),
  DeathStrike                           = Spell(49998),
  EmpowerRuneWeapon                     = Spell(47568),
  IceboundFortitude                     = Spell(48792),
  IcyTalons                             = Spell(194878),
  RaiseDead                             = Spell(46585),
  RunicAttenuation                      = Spell(207104),
  SacrificialPact                       = Spell(327574),
  SoulReaper                            = Spell(343294),
  -- Covenant Abilities
  AbominationLimbCov                    = Spell(315443),
  AbominationLimbCovBuff                = Spell(315443),
  DeathsDue                             = Spell(324128),
  Fleshcraft                            = Spell(324631),
  ShackleTheUnworthy                    = Spell(312202),
  SwarmingMist                          = Spell(311648),
  SwarmingMistBuff                      = Spell(311648),
  -- Soulbind Effects (Shadowlands)
  KevinsOozeling                        = Spell(352110),
  LeadByExample                         = Spell(342156),
  LeadByExampleBuff                     = Spell(342181),
  PustuleEruption                       = Spell(351094),
  VolatileSolvent                       = Spell(323074),
  VolatileSolventHumanBuff              = Spell(323491),
  -- Buffs
  DeathAndDecayBuff                     = Spell(188290),
  DeathsDueBuff                         = Spell(324165), -- SL Covenant. Remove after DF launch?
  EmpowerRuneWeaponBuff                 = Spell(47568),
  IcyTalonsBuff                         = Spell(194879),
  UnholyStrengthBuff                    = Spell(53365),
  -- Debuffs
  BloodPlagueDebuff                     = Spell(55078),
  FrostFeverDebuff                      = Spell(55095),
  VirulentPlagueDebuff                  = Spell(191587),
  -- Racials
  AncestralCall                         = Spell(274738),
  ArcanePulse                           = Spell(260364),
  ArcaneTorrent                         = Spell(50613),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Interrupts
  MindFreeze                            = Spell(47528),
  -- Custom
  Pool                                  = Spell(999910)
}

Spell.DeathKnight.Blood = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  BloodBoil                             = Spell(50842),
  DancingRuneWeapon                     = Spell(49028),
  DeathsCaress                          = Spell(195292),
  HeartStrike                           = Spell(206930),
  Marrowrend                            = Spell(195182),
  RuneTap                               = Spell(194679),
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
  -- Buffs
  BoneShieldBuff                        = Spell(195181),
  CrimsonScourgeBuff                    = Spell(81141),
  DancingRuneWeaponBuff                 = Spell(81256),
  HemostasisBuff                        = Spell(273947),
  IceboundFortitudeBuff                 = Spell(48792),
  RuneTapBuff                           = Spell(194679),
  VampiricBloodBuff                     = Spell(55233)
})

Spell.DeathKnight.Frost = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  FrostStrike                           = Spell(49143),
  HowlingBlast                          = Spell(49184),
  -- Talents
  Avalanche                             = Spell(207142),
  BitingCold                            = Spell(377056),
  BreathofSindragosa                    = Spell(152279),
  ChillStreak                           = Spell(305392),
  ColdHeart                             = Spell(281208),
  Frostscythe                           = Spell(207230),
  FrostwyrmsFury                        = Spell(279302),
  GatheringStorm                        = Spell(194912),
  GlacialAdvance                        = Spell(194913),
  HornofWinter                          = Spell(57330),
  Icebreaker                            = Spell(392950),
  Icecap                                = Spell(207126),
  ImprovedObliterate                    = Spell(317198),
  MightoftheFrozenWastes                = Spell(81333),
  Obliterate                            = Spell(49020),
  Obliteration                          = Spell(281238),
  PillarofFrost                         = Spell(51271),
  RageoftheFrozenChampion               = Spell(377076),
  RemorselessWinter                     = Spell(196770),
  UnleashedFrenzy                       = Spell(376905),
  -- Buffs
  ColdHeartBuff                         = Spell(281209),
  GatheringStormBuff                    = Spell(211805),
  KillingMachineBuff                    = Spell(51124),
  PillarofFrostBuff                     = Spell(51271),
  RimeBuff                              = Spell(59052),
  UnleashedFrenzyBuff                   = Spell(376907),
  -- Debuffs
  RazoriceDebuff                        = Spell(51714)
})

Spell.DeathKnight.Unholy = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  -- Talents
  Apocalypse                            = Spell(275699),
  ArmyoftheDamned                       = Spell(276837),
  ArmyoftheDead                         = Spell(42650),
  BurstingSores                         = Spell(207264),
  ClawingShadows                        = Spell(207311),
  CoilofDevastation                     = Spell(390270),
  CommanderoftheDead                    = Spell(390259),
  DarkTransformation                    = Spell(63560),
  Defile                                = Spell(152280),
  Epidemic                              = Spell(207317),
  EternalAgony                          = Spell(390268),
  FesteringStrike                       = Spell(85948),
  Festermight                           = Spell(377590),
  GhoulishFrenzy                        = Spell(377587),
  ImprovedDeathCoil                     = Spell(377580),
  Morbidity                             = Spell(377592),
  Outbreak                              = Spell(77575),
  Pestilence                            = Spell(277234),
  Plaguebringer                         = Spell(390175),
  RottenTouch                           = Spell(390275),
  ScourgeStrike                         = Spell(55090),
  SummonGargoyle                        = MultiSpell(49206, 207349),
  Superstrain                           = Spell(390283),
  UnholyAssault                         = Spell(207289),
  UnholyBlight                          = Spell(115989),
  UnholyCommand                         = Spell(316941),
  UnholyPact                            = Spell(319230),
  VileContagion                         = Spell(390279),
  -- Buffs
  FestermightBuff                       = Spell(377591),
  PlaguebringerBuff                     = Spell(390178),
  RunicCorruptionBuff                   = Spell(51460),
  SuddenDoomBuff                        = Spell(81340),
  UnholyAssaultBuff                     = Spell(207289),
  -- Debuffs
  FesteringWoundDebuff                  = Spell(194310),
  UnholyBlightDebuff                    = Spell(115994),
})

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Commons = {
  -- Potions
  PotionofSpectralStrength              = Item(171275),
  -- Trinkets
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  OverwhelmingPowerCrystal              = Item(179342, {13, 14}),
  ScarsofFraternalStrife                = Item(188253, {13, 14}),
  TheFirstSigil                         = Item(188271, {13, 14}),
  -- Other On-Use Items
  GaveloftheFirstArbiter                = Item(189862),
}

Item.DeathKnight.Blood = MergeTableByKey(Item.DeathKnight.Commons, {
})

Item.DeathKnight.Frost = MergeTableByKey(Item.DeathKnight.Commons, {
})

Item.DeathKnight.Unholy = MergeTableByKey(Item.DeathKnight.Commons, {
})
