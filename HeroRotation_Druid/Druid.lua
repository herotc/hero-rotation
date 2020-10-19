--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local MouseOver = Unit.MouseOver
local Spell = HL.Spell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local Settings = HR.GUISettings.APL.Druid.Commons
local Everyone = HR.Commons.Everyone
-- Lua
-- File Locals
local Commons = {}
local Druid = HR.Commons.Druid

--- ======= GLOBALIZE =======
HR.Commons.Druid = Commons


--- ============================ CONTENT ============================

-- Spells
if not Spell.Druid then Spell.Druid = {} end
Spell.Druid.Balance = {
  -- Racials
  AncestralCall                         = Spell(274738),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  LightsJudgment                        = Spell(255647),
  Fireblood                             = Spell(265221),
  BagofTricks                           = Spell(312411),
  -- Abilities
  MoonkinForm                           = Spell(24858),
  Wrath                                 = Spell(190984),
  Starfire                              = Spell(194153),
  Innervate                             = Spell(29166),
  CelestialAlignment                    = Spell(194223),
  SunfireDebuff                         = Spell(164815),
  MoonfireDebuff                        = Spell(164812),
  Starfall                              = Spell(191034),
  Starsurge                             = Spell(78674),
  Sunfire                               = Spell(93402),
  Moonfire                              = Spell(8921),
  SolarBeam                             = Spell(78675),
  Dash                                  = Spell(1850),

  -- Talents
  NaturesBalance                        = Spell(202430),
  WarriorofElune                        = Spell(202425),
  WarriorofEluneBuff                    = Spell(202425),
  ForceofNature                         = Spell(205636),

  TigerDash                             = Spell(252216),
  Renewal                               = Spell(108238),
  WildChargeBear                        = Spell(16979),
  WildChargeCat                         = Spell(49376),
  WildChargeMount                       = Spell(102417),
  WildChargeMoonkin                     = Spell(102383),

  SoulOfTheForest                       = Spell(114107),
  Starlord                              = Spell(202345),
  StarlordBuff                          = Spell(279709),
  Incarnation                           = Spell(102560),

  StellarDrift                          = Spell(202354),
  TwinMoons                             = Spell(279620),
  StellarFlare                          = Spell(202347),
  StellarFlareDebuff                    = Spell(202347),

  Solstice                              = Spell(343647),
  FuryofElune                           = Spell(202770),
  NewMoon                               = Spell(274281),
  HalfMoon                              = Spell(274282),
  FullMoon                              = Spell(274283),

  Thorns                                = Spell(236696),

  -- Artifact

  -- Defensive
  Barkskin                              = Spell(22812),

  -- Utility


  -- Essences
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
  -- Azerite
  StreakingStars                        = Spell(272871),
  ArcanicPulsarBuff                     = Spell(287790),
  ArcanicPulsar                         = Spell(287773),
  LivelySpirit                          = Spell(279642),
  LivelySpiritBuff                      = Spell(279646)

  -- Legendaries

  -- Misc

  -- Macros

}

-- Items
if not Item.Druid then Item.Druid = {} end
Item.Druid.Balance = {
  -- Potions/Trinkets
  ShiverVenomDebuff                     = Spell(301624),
  AzsharasFontofPowerBuff               = Spell(296962)
  -- "Other On Use"

}

















