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
  AntiMagicBarrier                      = Spell(205727),
  AntiMagicShell                        = Spell(48707),
  AntiMagicZone                         = Spell(51052),
  Asphyxiate                            = Spell(221562),
  Assimilation                          = Spell(374383),
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
  UnholyGround                          = Spell(374265),
  UnyieldingWill                        = Spell(457574),
  -- Buffs
  AbominationLimbBuff                   = Spell(383269),
  DeathAndDecayBuff                     = Spell(188290),
  DeathStrikeBuff                       = Spell(101568),
  EmpowerRuneWeaponBuff                 = Spell(47568),
  IcyTalonsBuff                         = Spell(194879),
  RuneofHysteriaBuff                    = Spell(326918),
  UnholyStrengthBuff                    = Spell(53365),
  -- Debuffs
  BloodPlagueDebuff                     = Spell(55078),
  FrostFeverDebuff                      = Spell(55095),
  MarkofFyralathDebuff                  = Spell(414532),
  SoulReaperDebuff                      = Spell(343294),
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

Spell.DeathKnight.Deathbringer = {
  -- Talents
  BindinDarkness                        = Spell(440031),
  DarkTalons                            = Spell(436687),
  Exterminate                           = Spell(441378),
  ReaperofSouls                         = Spell(440002),
  ReapersMark                           = Spell(439843),
  WitherAway                            = Spell(441894),
  -- Buffs
  ExterminateBuff                       = Spell(441416),
  PainfulDeathBuff                      = Spell(447954),
  ReaperofSoulsBuff                     = Spell(469172),
  -- Debuffs
  ReapersMarkDebuff                     = Spell(434765),
}

Spell.DeathKnight.RideroftheApocalypse = {
  -- Talents
  AFeastofSouls                         = Spell(444072),
  ApocalypseNow                         = Spell(444040),
  -- Buffs
  AFeastofSoulsBuff                     = Spell(440861),
  HungeringThirst                       = Spell(444037),
  MograinesMightBuff                    = Spell(444505),
  -- Debuffs
  TrollbaneSlowDebuff                   = Spell(444834),
}

Spell.DeathKnight.Sanlayn = {
  -- Abilities
  VampiricStrikeAction                  = Spell(433895),
  -- Talents
  FrenziedBloodthirst                   = Spell(434075),
  GiftoftheSanlayn                      = Spell(434152),
  VampiricStrike                        = Spell(433901),
  -- Buffs
  EssenceoftheBloodQueenBuff            = Spell(433925),
  GiftoftheSanlaynBuff                  = Spell(434153),
  InflictionofSorrowBuff                = Spell(460049),
  VampiricStrikeBuff                    = Spell(433899),
  -- Debuffs
  InciteTerrorDebuff                    = Spell(458478),
}

Spell.DeathKnight.Blood = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  -- Talents
  BloodBoil                             = Spell(50842),
  BloodTap                              = Spell(221699),
  Blooddrinker                          = Spell(206931),
  Bonestorm                             = Spell(194844),
  Coagulopathy                          = Spell(391477),
  Consumption                           = Spell(274156),
  DancingRuneWeapon                     = Spell(49028),
  DeathsCaress                          = Spell(195292),
  EverlastingBond                       = Spell(377668),
  HeartStrike                           = Spell(206930),
  Heartbreaker                          = Spell(221536),
  Marrowrend                            = Spell(195182),
  RelishinBlood                         = Spell(317610),
  RuneTap                               = Spell(194679),
  ShatteringBone                        = Spell(377640),
  Tombstone                             = Spell(219809),
  VampiricBlood                         = Spell(55233),
  -- Buffs
  BoneShieldBuff                        = Spell(195181),
  CoagulopathyBuff                      = Spell(391481),
  ConsumptionBuff                       = Spell(274156),
  DancingRuneWeaponBuff                 = Spell(81256),
  InnerResilienceBuff                   = Spell(450706), -- Tome of Light's Devotion buff
  HemostasisBuff                        = Spell(273947),
  IceboundFortitudeBuff                 = Spell(48792),
  RuneTapBuff                           = Spell(194679),
  VampiricBloodBuff                     = Spell(55233),
  -- TWW2 Effects
  LuckoftheDrawBuff                     = Spell(1218601), -- TWW S2 2P
  PiledriverBuff                        = Spell(457506), -- TWW S2 4P
  UnbreakableBuff                       = Spell(457468), -- TWW S2 2P
  UnbrokenBuff                          = Spell(457473), -- TWW S2 2P
})
Spell.DeathKnight.Blood = MergeTableByKey(Spell.DeathKnight.Blood, Spell.DeathKnight.Deathbringer)
Spell.DeathKnight.Blood = MergeTableByKey(Spell.DeathKnight.Blood, Spell.DeathKnight.Sanlayn)

Spell.DeathKnight.Frost = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  FrostStrike                           = Spell(49143),
  HowlingBlast                          = Spell(49184),
  -- Talents
  ArcticAssault                         = Spell(456230),
  Avalanche                             = Spell(207142),
  BitingCold                            = Spell(377056),
  Bonegrinder                           = Spell(377098),
  BreathofSindragosa                    = Spell(152279),
  ChillStreak                           = Spell(305392),
  ColdHeart                             = Spell(281208),
  EnduringStrength                      = Spell(377190),
  Frostscythe                           = Spell(207230),
  FrostwyrmsFury                        = Spell(279302),
  GatheringStorm                        = Spell(194912),
  GlacialAdvance                        = Spell(194913),
  HornofWinter                          = Spell(57330),
  Icebreaker                            = Spell(392950),
  Icecap                                = Spell(207126),
  Obliterate                            = Spell(49020),
  Obliteration                          = Spell(281238),
  PillarofFrost                         = Spell(51271),
  RageoftheFrozenChampion               = Spell(377076),
  RemorselessWinter                     = Spell(196770),
  ShatteredFrost                        = Spell(455993),
  ShatteringBlade                       = Spell(207057),
  SmotheringOffense                     = Spell(435005),
  TheLongWinter                         = Spell(456240),
  UnleashedFrenzy                       = Spell(376905),
  -- Buffs
  BonegrinderFrostBuff                  = Spell(377103),
  ColdHeartBuff                         = Spell(281209),
  GatheringStormBuff                    = Spell(211805),
  KillingMachineBuff                    = Spell(51124),
  PillarofFrostBuff                     = Spell(51271),
  RimeBuff                              = Spell(59052),
  UnleashedFrenzyBuff                   = Spell(376907),
  -- Debuffs
  RazoriceDebuff                        = Spell(51714),
  -- TWW2 Effects
  MurderousFrenzyBuff                   = Spell(1222698), -- TWW S2 4P
  WinningStreakBuff                     = Spell(1217897), -- TWW S2 2P
})
Spell.DeathKnight.Frost = MergeTableByKey(Spell.DeathKnight.Frost, Spell.DeathKnight.Deathbringer)
Spell.DeathKnight.Frost = MergeTableByKey(Spell.DeathKnight.Frost, Spell.DeathKnight.RideroftheApocalypse)

Spell.DeathKnight.Unholy = MergeTableByKey(Spell.DeathKnight.Commons, {
  -- Abilities
  FesteringScytheAction                 = Spell(458128),
  -- Talents
  Apocalypse                            = Spell(275699),
  ArmyoftheDead                         = Spell(42650),
  BurstingSores                         = Spell(207264),
  ClawingShadows                        = Spell(207311),
  CoilofDevastation                     = Spell(390270),
  CommanderoftheDead                    = Spell(390259),
  DarkTransformation                    = Spell(63560),
  Defile                                = Spell(152280),
  DoomedBidding                         = Spell(455386),
  Epidemic                              = Spell(207317),
  FesteringStrike                       = Spell(85948),
  Festermight                           = Spell(377590),
  HarbingerofDoom                       = Spell(276023),
  ImprovedDeathCoil                     = Spell(377580),
  MenacingMagus                         = Spell(455135),
  Morbidity                             = Spell(377592),
  Outbreak                              = Spell(77575),
  Pestilence                            = Spell(277234),
  Plaguebringer                         = Spell(390175),
  RaiseAbomination                      = Spell(455395),
  RaiseDead                             = Spell(46584),
  RottenTouch                           = Spell(390275),
  ScourgeStrike                         = Spell(55090),
  SummonGargoyle                        = MultiSpell(49206, 207349),
  Superstrain                           = Spell(390283),
  UnholyAssault                         = Spell(207289),
  UnholyBlight                          = Spell(115989),
  VileContagion                         = Spell(390279),
  -- Buffs
  CommanderoftheDeadBuff                = Spell(390260),
  FesteringScytheBuff                   = Spell(458123),
  FestermightBuff                       = Spell(377591),
  RunicCorruptionBuff                   = Spell(51460),
  SuddenDoomBuff                        = Spell(81340),
  -- Debuffs
  DeathRotDebuff                        = Spell(377540),
  FesteringWoundDebuff                  = Spell(194310),
  RottenTouchDebuff                     = Spell(390276),
  -- TWW2 Effects
  UnholyCommanderBuff                   = Spell(456698), -- TWW S2 4P
  WinningStreakBuff                     = Spell(1216813), -- TWW S2 2P
})
Spell.DeathKnight.Unholy = MergeTableByKey(Spell.DeathKnight.Unholy, Spell.DeathKnight.RideroftheApocalypse)
Spell.DeathKnight.Unholy = MergeTableByKey(Spell.DeathKnight.Unholy, Spell.DeathKnight.Sanlayn)

-- Items
if not Item.DeathKnight then Item.DeathKnight = {} end
Item.DeathKnight.Commons = {
  -- TWW Trinkets
  FunhouseLens                          = Item(234217, {13, 14}),
  ImprovisedSeaforiumPacemaker          = Item(232541, {13, 14}),
  TreacherousTransmitter                = Item(221023, {13, 14}),
}

Item.DeathKnight.Blood = MergeTableByKey(Item.DeathKnight.Commons, {
  -- TWW Trinkets
  TomeofLightsDevotion                  = Item(219309, {13, 14}),
  -- TWW Items
  BestinSlots                           = Item(232526, {16}),
})

Item.DeathKnight.Frost = MergeTableByKey(Item.DeathKnight.Commons, {
})

Item.DeathKnight.Unholy = MergeTableByKey(Item.DeathKnight.Commons, {
  -- TWW Trinkets
  SignetofthePriory                     = Item(219308, {13, 14}),
})
