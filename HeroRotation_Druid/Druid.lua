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
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Commons = {
  -- Racials
  Berserking                            = Spell(26297),
  Shadowmeld                            = Spell(58984),
  -- Abilities
  Barkskin                              = Spell(22812),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  SkullBash                             = Spell(106839),
  SurvivalInstincts                     = Spell(61336),
  -- Talents
  BalanceAffinity                       = Spell(197488),
  HeartoftheWild                        = Spell(319454),
  HeartoftheWildBuff                    = Spell(108291),
  -- Covenant Abilities
  AdaptiveSwarm                         = Spell(325727),
  AdaptiveSwarmDebuff                   = Spell(325733),
  AdaptiveSwarmHeal                     = Spell(325748),
  ConvoketheSpirits                     = Spell(323764),
  EmpowerBond                           = Spell(326647),
  Fleshcraft                            = Spell(324631),
  KindredSpirits                        = Spell(326434),
  KindredEmpowermentEnergizeBuff        = Spell(327022),
  RavenousFrenzy                        = Spell(323546),
  RavenousFrenzyBuff                    = Spell(323546),
  RavenousFrenzySHBuff                  = Spell(355315),
  -- Soulbind Abilities
  ThrillSeeker                          = Spell(331586),
  ThrillSeekerBuff                      = Spell(331939),
  -- Conduit Effects
  DeepAllegiance                        = Spell(341378),
  PreciseAlignment                      = Spell(340706),
  PustuleEruption                       = Spell(351094),
  SavageCombatantBuff                   = Spell(340613), -- Needs verified
  SuddenAmbushBuff                      = Spell(340698),
  TasteForBlood                         = Spell(340682),
  VolatileSolvent                       = Spell(323074),
  -- Other
  Pool                                  = Spell(999910)
}

Spell.Druid.Balance = MergeTableByKey(Spell.Druid.Commons, {
  -- Abilities
  CelestialAlignment                    = Spell(194223),
  EclipseLunar                          = Spell(48518),
  EclipseSolar                          = Spell(48517),
  Innervate                             = Spell(29166),
  MoonkinForm                           = Spell(24858),
  Starfall                              = Spell(191034),
  StarfallBuff                          = Spell(191034),
  Starfire                              = Spell(194153),
  Starsurge                             = Spell(78674),
  Sunfire                               = Spell(93402),
  SunfireDebuff                         = Spell(164815),
  Wrath                                 = Spell(190984),
  -- Talents
  ForceofNature                         = Spell(205636),
  FuryofElune                           = Spell(202770),
  Incarnation                           = Spell(102560),
  NaturesBalance                        = Spell(202430),
  Solstice                              = Spell(343647),
  SolsticeBuff                          = Spell(343648),
  SouloftheForest                       = Spell(114107),
  Starlord                              = Spell(202345),
  StarlordBuff                          = Spell(279709),
  StellarDrift                          = Spell(202354),
  StellarFlare                          = Spell(202347),
  StellarFlareDebuff                    = Spell(202347),
  TwinMoons                             = Spell(279620),
  WarriorofElune                        = Spell(202425),
  WarriorofEluneBuff                    = Spell(202425),
  -- New Moon Phases
  FullMoon                              = Spell(274283),
  HalfMoon                              = Spell(274282),
  NewMoon                               = Spell(274281),
  -- Legendary Effects
  BOATArcaneBuff                        = Spell(339946),
  BOATNatureBuff                        = Spell(339943),
  OnethsClearVisionBuff                 = Spell(339797),
  OnethsPerceptionBuff                  = Spell(339800),
  PAPBuff                               = Spell(338825),
  TimewornDreambinderBuff               = Spell(340049)
})

Spell.Druid.Feral = MergeTableByKey(Spell.Druid.Commons, {
  -- Abilties
  Berserk                               = Spell(106951),
  CatForm                               = Spell(768),
  Clearcasting                          = Spell(135700),
  FerociousBite                         = Spell(22568),
  Maim                                  = Spell(22570),
  Prowl                                 = Spell(5215),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  Rip                                   = Spell(1079),
  RipDebuff                             = Spell(1079),
  Shred                                 = Spell(5221),
  Swipe                                 = Spell(106785),
  Thrash                                = Spell(106830),
  ThrashDebuff                          = Spell(106830),
  TigersFury                            = Spell(5217),
  -- Talents
  Bloodtalons                           = Spell(319439),
  BloodtalonsBuff                       = Spell(145152),
  BrutalSlash                           = Spell(202028),
  FeralFrenzy                           = Spell(274837),
  Incarnation                           = Spell(102543),
  LunarInspiration                      = Spell(155580),
  LIMoonfire                            = Spell(155625), -- Lunar Inspiration Moonfire
  LIMoonfireDebuff                      = Spell(155625),
  MightyBash                            = Spell(5211),
  Predator                              = Spell(202021),
  PrimalWrath                           = Spell(285381),
  Sabertooth                            = Spell(202031),
  SavageRoar                            = Spell(52610),
  SouloftheForest                       = Spell(158476),
  WildCharge                            = Spell(49376),
  -- Owlweaving Abilities
  MoonkinForm                           = Spell(197625),
  Starsurge                             = Spell(197626),
  Sunfire                               = Spell(197630),
  -- Legendary Effects
  ApexPredatorsCravingBuff              = Spell(339140)
})

Spell.Druid.Guardian = MergeTableByKey(Spell.Druid.Commons, {
  -- Abilities
  BearForm                              = Spell(5487),
  Berserk                               = Spell(50334),
  BerserkBuff                           = Spell(50334),
  FrenziedRegeneration                  = Spell(22842),
  FrenziedRegenerationBuff              = Spell(22842),
  Ironfur                               = Spell(192081),
  IronfurBuff                           = Spell(192081),
  Mangle                                = Spell(33917),
  Maul                                  = Spell(6807),
  Swipe                                 = Spell(213771),
  Thrash                                = Spell(77758),
  ThrashDebuff                          = Spell(192090),
  -- Talents
  BristlingFur                          = Spell(155835),
  GalacticGuardianBuff                  = Spell(213708),
  Incarnation                           = Spell(102558),
  IncarnationBuff                       = Spell(102558),
  Pulverize                             = Spell(80313),
  ToothandClawBuff                      = Spell(135286),
  WildCharge                            = Spell(16979),
})

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Commons = {
  -- Potions
  PotionofPhantomFire                   = Item(171349),
  PotionofSpectralAgility               = Item(171270),
  PotionofSpectralIntellect             = Item(171273),
  -- Trinkets
  EmpyrealOrdinance                     = Item(180117, {13, 14}),
  InscrutableQuantumDevice              = Item(179350, {13, 14}),
  InstructorsDivineBell                 = Item(184842, {13, 14}),
  ShadowedOrbofTorment                  = Item(186428, {13, 14}),
  SoullettingRuby                       = Item(178809, {13, 14}),
  -- Other On-Use Items
  Jotungeirr                            = Item(186404)
}

Item.Druid.Balance = MergeTableByKey(Item.Druid.Commons, {
})

Item.Druid.Feral = MergeTableByKey(Item.Druid.Commons, {
})

Item.Druid.Guardian = MergeTableByKey(Item.Druid.Commons, {
})
