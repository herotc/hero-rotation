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
-- lua
local GetTime    = GetTime

-- File Locals
HR.Commons.Mage = {}
local Settings = HR.GUISettings.APL.Mage.Commons
local Mage = HR.Commons.Mage

--- ============================ CONTENT ============================

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Commons = {
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  ArcaneExplosion                       = Spell(1449), --Melee, 10
  ArcaneIntellect                       = Spell(1459),
  Blink                                 = MultiSpell(1953, 212653),
  Frostbolt                             = Spell(116),
  FrostNova                             = Spell(122),
  SlowFall                              = Spell(130),
  TimeWarp                              = Spell(80353),
  -- Talents
  AlterTime                             = Spell(342245),
  BlastWave                             = Spell(157981),
  Counterspell                          = Spell(2139),
  DragonsBreath                         = Spell(31661),
  FocusMagic                            = Spell(321358),
  IceBlock                              = Spell(45438),
  IceFloes                              = Spell(108839),
  IceNova                               = Spell(157997), --splash, 8
  Invisibility                          = Spell(66),
  Meteor                                = Spell(153561),
  MirrorImage                           = Spell(55342),
  RemoveCurse                           = Spell(475),
  RingOfFrost                           = Spell(113724),
  ShiftingPower                         = Spell(382440), --Melee 15
  SpellSteal                            = Spell(30449),
  TemporalWarp                          = Spell(386539),
  -- Buffs
  ArcaneIntellectBuff                   = Spell(1459),
  BerserkingBuff                        = Spell(26297),
  BloodFuryBuff                         = Spell(20572),
  TemporalWarpBuff                      = Spell(386540),
  -- Debuffs
  -- Trinket Effects
  SpoilsofNeltharusCrit                 = Spell(381954),
  SpoilsofNeltharusHaste                = Spell(381955),
  SpoilsofNeltharusMastery              = Spell(381956),
  SpoilsofNeltharusVers                 = Spell(381957),
  -- Pool
  Pool                                  = Spell(999910)
}

Spell.Mage.Arcane = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  ArcaneBlast                           = Spell(30451),
  FireBlast                             = Spell(319836),
  -- Talents
  Amplification                         = Spell(236628),
  ArcaneBarrage                         = Spell(44425), --Splash, 10
  ArcaneBombardment                     = Spell(384581),
  ArcaneEcho                            = Spell(342231), --Splash, 8
  ArcaneFamiliar                        = Spell(205022),
  ArcaneHarmony                         = Spell(384452),
  ArcaneMissiles                        = Spell(5143),
  ArcaneOrb                             = Spell(153626), --Splash, 16
  ArcanePower                           = Spell(321739),
  ArcaneSurge                           = Spell(365350),
  ArcingCleave                          = Spell(231564),
  CascadingPower                        = Spell(384276),
  ChargedOrb                            = Spell(384651),
  ConjureManaGem                        = Spell(759),
  Concentration                         = Spell(384374),
  Enlightened                           = Spell(321387),
  Evocation                             = Spell(12051),
  GreaterInvisibility                   = Spell(110959),
  NetherTempest                         = Spell(114923), --Splash, 10
  NetherPrecision                       = Spell(383782),
  OrbBarrage                            = Spell(384858),
  Overpowered                           = Spell(155147),
  PresenceofMind                        = Spell(205025),
  PrismaticBarrier                      = Spell(235450),
  RadiantSpark                          = Spell(376103),
  Resonance                             = Spell(205028),
  RuleofThrees                          = Spell(264354),
  SiphonStorm                           = Spell(384187),
  Slipstream                            = Spell(236457),
  Supernova                             = Spell(157980), --Splash, 8
  TimeAnomaly                           = Spell(383243),
  TouchoftheMagi                        = Spell(321507), --Splash, 8
  -- Buffs
  ArcaneArtilleryBuff                   = Spell(424331), -- Tier 31 4pc
  ArcaneFamiliarBuff                    = Spell(210126),
  ArcaneHarmonyBuff                     = Spell(384455),
  ArcaneOverloadBuff                    = Spell(409022), -- Tier 30 4pc
  ArcaneSurgeBuff                       = Spell(365362),
  ClearcastingBuff                      = Spell(263725),
  ConcentrationBuff                     = Spell(384379),
  NetherPrecisionBuff                   = Spell(383783),
  PresenceofMindBuff                    = Spell(205025),
  RuleofThreesBuff                      = Spell(264774),
  SiphonStormBuff                       = Spell(384267),
  -- Debuffs
  NetherTempestDebuff                   = Spell(114923), --Splash, 10
  RadiantSparkDebuff                    = Spell(376103),
  RadiantSparkVulnerability             = Spell(376104),
  TouchoftheMagiDebuff                  = Spell(210824),
  -- Misc
  StopAM                                = Spell(363653),
})

Spell.Mage.Fire = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  Fireball                              = Spell(133),
  Flamestrike                           = Spell(2120),
  -- Talents
  AlexstraszasFury                      = Spell(235870),
  BlazingBarrier                        = Spell(235313),
  Combustion                            = Spell(190319),
  FeeltheBurn                           = Spell(383391),
  FireBlast                             = Spell(108853),
  Firestarter                           = Spell(205026),
  FlameOn                               = Spell(205029),
  FlamePatch                            = Spell(205037),
  FromTheAshes                          = Spell(342344),
  FueltheFire                           = Spell(416094),
  Hyperthermia                          = Spell(383860),
  ImprovedScorch                        = Spell(383604),
  Kindling                              = Spell(155148),
  LivingBomb                            = Spell(44457),
  PhoenixFlames                         = Spell(257541),
  Pyroblast                             = Spell(11366),
  Scorch                                = Spell(2948),
  SearingTouch                          = Spell(269644),
  SunKingsBlessing                      = Spell(383886),
  TemperedFlames                        = Spell(383659),
  -- Buffs
  CombustionBuff                        = Spell(190319),
  FeeltheBurnBuff                       = Spell(383395),
  FlameAccelerantBuff                   = Spell(203277),
  FlamesFuryBuff                        = Spell(409964), -- T30 4pc bonus
  HeatingUpBuff                         = Spell(48107),
  HotStreakBuff                         = Spell(48108),
  HyperthermiaBuff                      = Spell(383874),
  SunKingsBlessingBuff                  = Spell(383882),
  FuryoftheSunKingBuff                  = Spell(383883),
  -- Debuffs
  CharringEmbersDebuff                  = Spell(408665), -- T30 2pc bonus
  IgniteDebuff                          = Spell(12654),
  ImprovedScorchDebuff                  = Spell(383608),
})

Spell.Mage.Frost = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  Blizzard                              = Spell(190356), --splash, 16
  ConeofCold                            = Spell(120),--Melee, 12
  FireBlast                             = Spell(319836),
  -- Talents
  BoneChilling                          = Spell(205027),
  ChainReaction                         = Spell(278309),
  ColdestSnap                           = Spell(417493),
  CometStorm                            = Spell(153595), --splash, 6
  DeepShatter                           = Spell(378749),
  Flurry                                = Spell(44614),
  FreezingRain                          = Spell(270233),
  FreezingWinds                         = Spell(382103),
  Frostbite                             = Spell(378756),
  FrozenOrb                             = Spell(84714), --splash, 16
  FrozenTouch                           = Spell(205030),
  GlacialSpike                          = Spell(199786), --splash, 8 (with splitting ice)
  IceBarrier                            = Spell(11426),
  IceCaller                             = Spell(236662),
  IceLance                              = Spell(30455), --splash, 8 (with splitting ice)
  IcyVeins                              = Spell(12472),
  RayofFrost                            = Spell(205021),
  SlickIce                              = Spell(382144),
  Snowstorm                             = Spell(381706),
  SplinteringCold                       = Spell(379049),
  SplittingIce                          = Spell(56377), --splash, 8
  -- Pet Abilities
  Freeze                                = Spell(33395), --splash, 8
  WaterJet                              = Spell(135029),
  -- Buffs
  BoneChillingBuff                      = Spell(205766),
  BrainFreezeBuff                       = Spell(190446),
  FingersofFrostBuff                    = Spell(44544),
  FreezingRainBuff                      = Spell(270232),
  FreezingWindsBuff                     = Spell(382106),
  GlacialSpikeBuff                      = Spell(199844),
  IciclesBuff                           = Spell(205473),
  IcyVeinsBuff                          = Spell(12472),
  SnowstormBuff                         = Spell(381522),
  -- Debuffs
  FrostbiteDebuff                       = Spell(378760),
  WintersChillDebuff                    = Spell(228358),
})

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Commons = {
  -- Trinkets
  AshesoftheEmbersoul                   = Item(207167, {13, 14}),
  BalefireBranch                        = Item(159630, {13, 14}),
  BeacontotheBeyond                     = Item(203963, {13, 14}),
  BelorrelostheSuncaller                = Item(207172, {13, 14}),
  ConjuredChillglobe                    = Item(194300, {13, 14}),
  DesperateInvokersCodex                = Item(194310, {13, 14}),
  DMDDance                              = Item(198088, {13, 14}),
  DMDDanceBox                           = Item(198478, {13, 14}),
  DMDInferno                            = Item(198086, {13, 14}),
  DMDInfernoBox                         = Item(194872, {13, 14}),
  DMDRime                               = Item(198087, {13, 14}),
  DMDRimeBox                            = Item(198477, {13, 14}),
  DragonfireBombDispenser               = Item(202610, {13, 14}),
  EruptingSpearFragment                 = Item(193769, {13, 14}),
  HornofValor                           = Item(133642, {13, 14}),
  IcebloodDeathsnare                    = Item(194304, {13, 14}),
  IrideusFragment                       = Item(193743, {13, 14}),
  MirrorofFracturedTomorrows            = Item(207581, {13, 14}),
  MoonlitPrism                          = Item(137541, {13, 14}),
  NeltharionsCalltoChaos                = Item(204201, {13, 14}),
  NymuesUnravelingSpindle               = Item(208615, {13, 14}),
  SeaStar                               = Item(56290, {13, 14}),
  SpoilsofNeltharus                     = Item(193773, {13, 14}),
  TimebreachingTalon                    = Item(193791, {13, 14}),
  TimeThiefsGambit                      = Item(207579, {13, 14}),
  TomeofUnstablePower                   = Item(193628, {13, 14}),
  VoidmendersShadowgem                  = Item(110007, {13, 14}),
  -- Gladiator's Badges
  CrimsonGladiatorsBadge                = Item(201807, {13, 14}),
  ObsidianGladiatorsBadge               = Item(205708, {13, 14}),
  VerdantGladiatorsBadge                = Item(209343, {13, 14}),
  -- Other On-Use Items
  Dreambinder                           = Item(208616, {16}),
  IridaltheEarthsMaster                 = Item(208321, {16}),
}

Item.Mage.Arcane = MergeTableByKey(Item.Mage.Commons, {
  ManaGem                          = Item(36799),
})

Item.Mage.Fire = MergeTableByKey(Item.Mage.Commons, {
})

Item.Mage.Frost = MergeTableByKey(Item.Mage.Commons, {
})

-- Variables
Mage.IFST = {
  CurrStacks = 0,
  CurrStacksTime = 0,
  OldStacks = 0,
  OldStacksTime = 0,
  Direction = 0
}
local S = {}
S.IncantersFlowBuff = Spell(116267)

HL:RegisterForEvent(function()
  Mage.IFST.CurrStacks = 0
  Mage.IFST.CurrStacksTime = 0
  Mage.IFST.OldStacks = 0
  Mage.IFST.OldStacksTime = 0
  Mage.IFST.Direction = 0
end, "PLAYER_REGEN_ENABLED")

function Mage.IFTracker()
  if HL.CombatTime() == 0 then return; end
  local TickDiff = Mage.IFST.CurrStacksTime - Mage.IFST.OldStacksTime
  local CurrStacks = Mage.IFST.CurrStacks
  local CurrStacksTime = Mage.IFST.CurrStacksTime
  local OldStacks = Mage.IFST.OldStacks
  if (Player:BuffUp(S.IncantersFlowBuff)) then
    if (Player:BuffStack(S.IncantersFlowBuff) ~= CurrStacks or (Player:BuffStack(S.IncantersFlowBuff) == CurrStacks and TickDiff > 1)) then
      Mage.IFST.OldStacks = CurrStacks
      Mage.IFST.OldStacksTime = CurrStacksTime
    end
    Mage.IFST.CurrStacks = Player:BuffStack(S.IncantersFlowBuff)
    Mage.IFST.CurrStacksTime = HL.CombatTime()
    if Mage.IFST.CurrStacks > Mage.IFST.OldStacks then
      if Mage.IFST.CurrStacks == 5 then
        Mage.IFST.Direction = 0
      else
        Mage.IFST.Direction = 1
      end
    elseif Mage.IFST.CurrStacks < Mage.IFST.OldStacks then
      if Mage.IFST.CurrStacks == 1 then
        Mage.IFST.Direction = 0
      else
        Mage.IFST.Direction = -1
      end
    else
      if Mage.IFST.CurrStacks == 1 then
        Mage.IFST.Direction = 1
      else
        Mage.IFST.Direction = -1
      end
    end
  else
    Mage.IFST.OldStacks = 0
    Mage.IFST.OldStacksTime = 0
    Mage.IFST.CurrStacks = 0
    Mage.IFST.CurrStacksTime = 0
    Mage.IFST.Direction = 0
  end
end

function Mage.IFTimeToX(count, direction)
    local low
    local high
    local buff_position
    if Mage.IFST.Direction == -1 or (Mage.IFST.Direction == 0 and Mage.IFST.CurrStacks == 0) then
      buff_position = 10 - Mage.IFST.CurrStacks + 1
    else
      buff_position = Mage.IFST.CurrStacks
    end
    if direction == "up" then
        low = count
        high = count
    elseif direction == "down" then
        low = 10 - count + 1
        high = 10 - count + 1
    else
        low = count
        high = 10 - count + 1
    end
    if low == buff_position or high == buff_position then
      return 0
    end
    local ticks_low = (10 + low - buff_position) % 10
    local ticks_high = (10 + high - buff_position) % 10
    return (Mage.IFST.CurrStacksTime - Mage.IFST.OldStacksTime) + math.min(ticks_low, ticks_high) - 1
end
