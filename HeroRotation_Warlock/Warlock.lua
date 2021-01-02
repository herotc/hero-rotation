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
if not Spell.Warlock then Spell.Warlock = {} end
Spell.Warlock.Demonology = {
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),

  -- Base Abilities
  AxeToss                               = Spell(119914),
  CallDreadstalkers                     = Spell(104316),
  Demonbolt                             = Spell(264178),
  DemonicCoreBuff                       = Spell(264173),
  Felstorm                              = Spell(89751),
  HandofGuldan                          = Spell(105174), -- Splash, 8
  Implosion                             = Spell(196277), -- Splash, 8
  ShadowBolt                            = Spell(686),
  SpellLock                             = Spell(119910),
  SummonDemonicTyrant                   = Spell(265187),
  SummonPet                             = Spell(30146),
  UnendingResolve                       = Spell(104773),

  -- Talents
  BilescourgeBombers                    = Spell(267211), -- Splash, 8
  DemonicCalling                        = Spell(205145),
  DemonicCallingBuff                    = Spell(205146),
  DemonicConsumption                    = Spell(267215),
  DemonicPowerBuff                      = Spell(265273),
  DemonicStrength                       = Spell(267171),
  Doom                                  = Spell(603),
  DoomDebuff                            = Spell(603),
  GrimoireFelguard                      = Spell(111898),
  InnerDemons                           = Spell(267216),
  NetherPortal                          = Spell(267217),
  NetherPortalBuff                      = Spell(267218),
  PowerSiphon                           = Spell(264130),
  SacrificedSouls                       = Spell(267214),
  SoulStrike                            = Spell(264057),
  SummonVilefiend                       = Spell(264119),

  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DecimatingBoltBuff                    = Spell(325299),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792), -- Splash, 8/10/12/15?
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640), -- Splash, 15

  -- Legendary Effects
  BalespidersBuff                       = Spell(337161),

  -- Item Effects
  ShiverVenomDebuff                     = Spell(301624),
}

Spell.Warlock.Affliction = {
  -- Racials
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),

  -- Base Abilities
  Agony                                 = Spell(980),
  AgonyDebuff                           = Spell(980),
  Corruption                            = Spell(172),
  CorruptionDebuff                      = Spell(146739),
  DrainLife                             = Spell(234153),
  MaleficRapture                        = Spell(324536),
  SeedofCorruption                      = Spell(27243),
  SeedofCorruptionDebuff                = Spell(27243),
  ShadowBolt                            = Spell(686),
  ShadowEmbrace                         = Spell(32388),
  ShadowEmbraceDebuff                   = Spell(32390),
  SummonDarkglare                       = Spell(205180),
  SummonPet                             = Spell(688),
  UnstableAffliction                    = Spell(316099),
  UnstableAfflictionDebuff              = Spell(316099),

  -- Talents
  Nightfall                             = Spell(108558),
  InevitableDemise                      = Spell(334319),
  InvetiableDemiseBuff                  = Spell(334320),
  DrainSoul                             = Spell(198590),

  WritheinAgony                         = Spell(196102),
  AbsoluteCorruption                    = Spell(196103),
  SiphonLife                            = Spell(63106),
  SiphonLifeDebuff                      = Spell(63106),

  SowtheSeeds                           = Spell(196226),
  PhantomSingularity                    = Spell(205179),
  PhantomSingularityDebuff              = Spell(205179),
  VileTaint                             = Spell(278350),
  VileTaintDebuff                       = Spell(278350),

  Haunt                                 = Spell(48181),

  GrimoireofSacrifice                   = Spell(108503),
  GrimoireofSacrificeBuff               = Spell(196099),

  DarkSoulMisery                        = Spell(113860),

  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792), -- Splash, 8/10/12/15?
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640), -- Splash, 15

  -- Item Effects

}

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Demonology = {
  PotionofSpectralIntellect             = Item(307096)
}

Item.Warlock.Affliction = {
}
