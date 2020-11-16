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
local Settings = HR.GUISettings.APL.Shaman.Commons
local Everyone = HR.Commons.Everyone
-- Lua
-- File Locals
local Commons = {}

--- ======= GLOBALIZE =======
HR.Commons.Class = Commons


--- ============================ CONTENT ============================


-- Spells
if not Spell.Shaman then Spell.Shaman = {} end
Spell.Shaman.Enhancement = {
  -- General Abilities

  -- Abilities Shaman
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlameShock                            = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),

  -- Defensive
  AstralShift                           = Spell(10871),

  -- Utility
  CapacitorTotem                        = Spell(192058),

  -- Racials
  ArcaneTorrent                         = Spell(50613),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),

  -- Abilities
  Bloodlust                             = Spell(2825),
  ChainLightning                        = Spell(188443),
  EarthElemental                        = Spell(198103),
  FlameShock                            = Spell(188389),
  FlamentongueWeapon                    = Spell(318038),
  FrostShock                            = Spell(196840),
  LightningBolt                         = Spell(188196),
  LightningShield                       = Spell(192106),

  -- Defensive
  AstralShift                           = Spell(10871),

  -- Utility
  CapacitorTotem                        = Spell(192058),


  CrashLightning                        = Spell(187874),
  FeralSpirit                           = Spell(51533),
  LavaLash                              = Spell(60103),
  Stormstrike                           = Spell(17364),
  Windstrike                            = Spell(115356),
  WindfuryTotem                         = Spell(8512),
  WindfuryTotemBuff                     = Spell(327942),
  WindfuryWeapon                        = Spell(33757),
  MaelstromWeapon                       = Spell(344179),
  CrashLightningBuff                    = Spell(187878),

  -- Talents
  Ascendance                            = Spell(114051),
  Sundering                             = Spell(197214),
  Hailstorm                             = Spell(334195),
  HailstormBuff                         = Spell(334196),
  Stormkeeper                           = Spell(320137),
  StormkeeperBuff                       = Spell(320137),
  EarthenSpike                          = Spell(188089),
  FireNova                              = Spell(333974),
  LashingFlames                         = Spell(334046),
  ElementalBlast                        = Spell(117014),
  Stormflurry                           = Spell(344357),
  HotHand                               = Spell(201900),
  HotHandBuff                           = Spell(215785),
  IceStrike                             = Spell(342240),
  CrashingStorm                         = Spell(192246),
  ElementalSpirits                      = Spell(262624),
  ForcefulWinds                         = Spell(262647),
  -- Artifact

  -- Defensive

  -- Utility

  -- Legendaries

  -- Misc

  -- Macros

}
