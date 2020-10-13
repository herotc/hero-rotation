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
  SoulStrike                            = Spell(264057),
  SummonVilefiend                       = Spell(264119),
  
  -- Covenant Abilities
  DecimatingBolt                        = Spell(325289),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  ImpendingCatastrophe                  = Spell(321792), -- Splash, 8/10/12/15?
  ScouringTithe                         = Spell(312321),
  SoulRot                               = Spell(325640), -- Splash, 15
  
  -- Azerite Traits
  BalefulInvocation                     = Spell(287059),
  ExplosivePotential                    = Spell(275395),
  ExplosivePotentialBuff                = Spell(275398),
  ShadowsBite                           = Spell(272944),
  ShadowsBiteBuff                       = Spell(272945),
  
  -- Azerite Essences
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
  RippleInSpace                         = Spell(302731),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  
  -- Item Effects
  ShiverVenomDebuff                     = Spell(301624),
}

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Demonology = {
  PotionofUnbridledFury            = Item(169299)
}