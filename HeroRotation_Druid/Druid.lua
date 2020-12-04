--- Localize Vars
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
local MultiSpell = HL.MultiSpell

-- HeroRotation
local HR = HeroRotation;
-- Lua

-- Commons
HR.Commons.Druid = {};

-- GUI Settings
local Settings = HR.GUISettings.APL.Druid.Commons;
local Druid = HR.Commons.Druid;

-- Spells
if not Spell.Druid then Spell.Druid = {} end

Spell.Druid.Feral = {
  Regrowth                              = Spell(8936),
  BloodtalonsBuff                       = Spell(145152),
  Bloodtalons                           = Spell(155672),
  WildFleshrending                      = Spell(279527),
  CatFormBuff                           = Spell(768),
  CatForm                               = Spell(768),
  ProwlBuff                             = Spell(5215),
  Prowl                                 = Spell(5215),
  BerserkBuff                           = Spell(106951),
  Berserk                               = Spell(106951),
  TigersFury                            = Spell(5217),
  TigersFuryBuff                        = Spell(5217),
  Berserking                            = Spell(26297),
  FeralFrenzy                           = Spell(274837),
  Incarnation                           = Spell(102543),
  IncarnationBuff                       = Spell(102543),
  BalanceAffinity                       = Spell(197488),
  Shadowmeld                            = Spell(58984),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  SavageRoar                            = Spell(52610),
  SavageRoarBuff                        = Spell(52610),
  PrimalWrath                           = Spell(285381),
  RipDebuff                             = Spell(1079),
  Rip                                   = Spell(1079),
  Sabertooth                            = Spell(202031),
  Maim                                  = Spell(22570),
  IronJawsBuff                          = Spell(276026),
  FerociousBiteMaxEnergy                = Spell(22568),
  FerociousBite                         = Spell(22568),
  PredatorySwiftnessBuff                = Spell(69369),
  LunarInspiration                      = Spell(155580),
  BrutalSlash                           = Spell(202028),
  ThrashCat                             = Spell(106830),
  ThrashCatDebuff                       = Spell(106830),
  ScentofBlood                          = Spell(285564),
  ScentofBloodBuff                      = Spell(285646),
  SwipeCat                              = Spell(106785),
  MoonfireCat                           = Spell(155625),
  MoonfireCatDebuff                     = Spell(155625),
  ClearcastingBuff                      = Spell(135700),
  Shred                                 = Spell(5221),
  SkullBash                             = Spell(106839),
  ShadowmeldBuff                        = Spell(58984),
  JungleFury                            = Spell(274424),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  ReapingFlames                         = Spell(310690),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  Thorns                                = Spell(236696),
  
  -- Icon for pooling energy
  -- PoolResource                          = Spell(9999000010)
  PoolResource                         	= Spell(999910),
};

Spell.Druid.Balance = {
  StreakingStars                        = Spell(272871),
  ArcanicPulsarBuff                     = Spell(287790),
  ArcanicPulsar                         = Spell(287773),
  StarlordBuff                          = Spell(279709),
  Starlord                              = Spell(202345),
  TwinMoons                             = Spell(279620),
  MoonkinForm                           = Spell(24858),
  SolarWrath                            = Spell(190984),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  WarriorofElune                        = Spell(202425),
  Innervate                             = Spell(29166),
  LivelySpirit                          = Spell(279642),
  Incarnation                           = Spell(102560),
  CelestialAlignment                    = Spell(194223),
  SunfireDebuff                         = Spell(164815),
  MoonfireDebuff                        = Spell(164812),
  StellarFlareDebuff                    = Spell(202347),
  StellarFlare                          = Spell(202347),
  LivelySpiritBuff                      = Spell(279646),
  FuryofElune                           = Spell(202770),
  ForceofNature                         = Spell(205636),
  Starfall                              = Spell(191034),
  Starsurge                             = Spell(78674),
  LunarEmpowermentBuff                  = Spell(164547),
  SolarEmpowermentBuff                  = Spell(164545),
  Sunfire                               = Spell(93402),
  Moonfire                              = Spell(8921),
  NewMoon                               = Spell(274281),
  HalfMoon                              = Spell(274282),
  FullMoon                              = Spell(274283),
  LunarStrike                           = Spell(194153),
  WarriorofEluneBuff                    = Spell(202425),
  ShootingStars                         = Spell(202342),
  NaturesBalance                        = Spell(202430),
  Barkskin                              = Spell(22812),
  Renewal                               = Spell(108238),
  SolarBeam                             = Spell(78675),
  ShiverVenomDebuff                     = Spell(301624),
  AzsharasFontofPowerBuff               = Spell(296962),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  Thorns                                = Spell(236696)
};

if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Restoration = {
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  BalanceAffinity                       = Spell(197632),
  FeralAffinity                         = Spell(197490),
  CatForm                               = Spell(768),
  CatFormBuff                           = Spell(768),
  MoonkinForm                           = Spell(197625),
  MoonkinFormBuff                       = Spell(197625),
  Prowl                                 = Spell(5215),
  Sunfire                               = Spell(93402),
  SunfireDebuff                         = Spell(164815),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  Starsurge                             = Spell(197626),
  LunarEmpowerment                      = Spell(164547),
  LunarStrike                           = Spell(197628),
  SolarWrath                            = Spell(5176),
  Rake                                  = Spell(1822),
  RakeDebuff                            = Spell(155722),
  Rip                                   = Spell(1079),
  RipDebuff                             = Spell(1079),
  FerociousBite                         = Spell(22568),
  SwipeCat                              = Spell(213764),
  Shred                                 = Spell(5221),
  MemoryofLucidDreams                   = Spell(298357),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  WorldveinResonance                    = Spell(295186),
  Shadowmeld                            = Spell(58984),
  Pool                                  = Spell(999910)
};

Spell.Druid.Guardian = {
  BearForm                              = Spell(5487),
  CatForm                               = Spell(768),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  ArcaneTorrent                         = Spell(50613),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Barkskin                              = Spell(22812),
  LunarBeam                             = Spell(204066),
  BristlingFur                          = Spell(155835),
  Maul                                  = Spell(6807),
  Ironfur                               = Spell(192081),
  LayeredMane                           = Spell(279552),
  Pulverize                             = Spell(80313),
  PulverizeBuff                         = Spell(158792),
  ThrashBearDebuff                      = Spell(192090),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
  Incarnation                           = Spell(102558),
  IncarnationBuff                       = Spell(102558),
  Thrash                                = MultiSpell(77758, 106830),
  Swipe                                 = MultiSpell(213771, 106785),
  Mangle                                = Spell(33917),
  GalacticGuardian                      = Spell(203964),
  GalacticGuardianBuff                  = Spell(213708),
  PoweroftheMoon                        = Spell(273367),
  FrenziedRegeneration                  = Spell(22842),
  BalanceAffinity                       = Spell(197488),
  WildChargeTalent                      = Spell(102401),
  WildChargeBear                        = Spell(16979),
  SurvivalInstincts                     = Spell(61336),
  SkullBash                             = Spell(106839),
  AnimaofDeath                          = Spell(294926),
  MemoryofLucidDreams                   = Spell(298357),
  Conflict                              = Spell(303823),
  WorldveinResonance                    = Spell(295186),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  SharpenedClawsBuff                    = Spell(279943),
  RazorCoralDebuff                      = Spell(303568),
  ConductiveInkDebuff                   = Spell(302565)
};

-- Items
if not Item.Druid then Item.Druid = {} end

Item.Druid.Restoration = {
  PotionofUnbridledFury            = Item(169299),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
};

Item.Druid.Balance = {
  PotionofUnbridledFury            = Item(169299),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  ShiverVenomRelic                 = Item(168905, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  ManifestoofMadness               = Item(174103, {13, 14})
};

Item.Druid.Feral = {
  PotionofFocusedResolve                = Item(168506),
  PocketsizedComputationDevice          = Item(167555, {13, 14}),
  AshvanesRazorCoral                    = Item(169311, {13, 14}),
  AzsharasFontofPower                   = Item(169314, {13, 14})
};

Item.Druid.Guardian = {
  PotionofFocusedResolve           = Item(168506),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AshvanesRazorCoral               = Item(169311, {13, 14})
};
