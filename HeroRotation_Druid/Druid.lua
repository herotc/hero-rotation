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
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Balance = {
  -- Racials
  Berserking                            = Spell(26297),

  -- Abilities
  Barkskin                              = Spell(22812),
  CelestialAlignment                    = Spell(194223),
  EclipseLunar                          = Spell(48518),
  EclipseSolar                          = Spell(48517),
  Innervate                             = Spell(29166),
  Moonfire                              = Spell(8921),
  MoonfireDebuff                        = Spell(164812),
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

  -- Covenant Abilities
  AdaptiveSwarm                         = Spell(325727),
  AdaptiveSwarmDebuff                   = Spell(325733),
  AdaptiveSwarmHeal                     = Spell(325748),
  ConvoketheSpirits                     = Spell(323764),
  EmpowerBond                           = Spell(326647),
  KindredSpirits                        = Spell(326434),
  KindredEmpowermentEnergizeBuff        = Spell(327022),
  RavenousFrenzy                        = Spell(323546),
  RavenousFrenzyBuff                    = Spell(323546),

  -- Conduit Effects
  PreciseAlignment                      = Spell(340706),

  -- Legendary Effects
  BOATArcaneBuff                        = Spell(339946),
  BOATNatureBuff                        = Spell(339943),
  OnethsClearVisionBuff                 = Spell(339797),
  OnethsPerceptionBuff                  = Spell(339800),
  PAPBuff                               = Spell(338825),
  TimewornDreambinderBuff               = Spell(340049),

  -- Item Effects

  -- Custom
  Pool                                  = Spell(999910)
}

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Balance = {
  -- Potion/Trinkets
  PotionofSpectralIntellect             = Item(307096),
  EmpyrealOrdinance                     = Item(180117),
  InscrutableQuantumDevice              = Item(179350),
  SoullettingRuby                       = Item(178809)
  -- Other "On-Use"
}
