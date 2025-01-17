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
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  ArcaneExplosion                       = Spell(1449), --Melee, 10
  ArcaneIntellect                       = Spell(1459),
  Frostbolt                             = Spell(116),
  FrostNova                             = Spell(122),
  -- Talents
  Counterspell                          = Spell(2139),
  DragonsBreath                         = Spell(31661),
  IceFloes                              = Spell(108839),
  IceNova                               = Spell(157997), --splash, 8
  MirrorImage                           = Spell(55342),
  ShiftingPower                         = Spell(382440), --Melee 15
  -- Buffs
  ArcaneIntellectBuff                   = Spell(1459),
  -- Debuffs
  -- Trinket Effects
  EtherealPowerlinkBuff                 = Spell(449954), -- Buff from Treacherous Transmitter trinket
  SpymastersReportBuff                  = Spell(451199), -- Buff from using Spymaster's Web trinket
  SpymastersWebBuff                     = Spell(444959), -- Buff from using Spymaster's Web trinket
  -- Pool
  Pool                                  = Spell(999910)
}

Spell.Mage.Frostfire = {
  -- Abilities
  FrostfireBolt                         = Spell(431044),
  -- Talents
  ExcessFire                            = Spell(438595),
  ExcessFrost                           = Spell(438600),
  IsothermicCore                        = Spell(431095),
  -- Buffs
  ExcessFireBuff                        = Spell(438624),
  ExcessFrostBuff                       = Spell(438611),
  FrostfireEmpowermentBuff              = Spell(431177),
}

Spell.Mage.Spellslinger = {
  -- Talents
  ShiftingShards                        = Spell(444675),
  SplinteringSorcery                    = Spell(443739),
  Splinterstorm                         = Spell(443742),
  UnerringProficiency                   = Spell(444974),
  -- Buffs
  UnerringProficiencyBuff               = Spell(444981),
}

Spell.Mage.Sunfury = {
  -- Talents
  SpellfireSpheres                      = Spell(448601),
  SunfuryExecution                      = Spell(449349),
  -- Buffs
  ArcaneSoulBuff                        = Spell(451038),
  BurdenofPowerBuff                     = Spell(451049),
  GloriousIncandescenceBuff             = Spell(451073),
  SpellfireSpheresBuff                  = Spell(449400),
}

Spell.Mage.Arcane = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  ArcaneBlast                           = Spell(30451),
  -- Talents
  ArcaneBarrage                         = Spell(44425), --Splash, 10
  ArcaneBombardment                     = Spell(384581),
  ArcaneFamiliar                        = Spell(205022),
  ArcaneHarmony                         = Spell(384452),
  ArcaneMissiles                        = Spell(5143),
  ArcaneOrb                             = Spell(153626), --Splash, 16
  ArcaneSurge                           = Spell(365350),
  ArcaneTempo                           = Spell(383980),
  ArcingCleave                          = Spell(231564),
  ChargedOrb                            = Spell(384651),
  Enlightened                           = Spell(321387),
  Evocation                             = Spell(12051),
  HighVoltage                           = Spell(461248),
  Impetus                               = Spell(383676),
  ImprovedClearcasting                  = Spell(321420),
  MagisSpark                            = Spell(454016),
  OrbBarrage                            = Spell(384858),
  PresenceofMind                        = Spell(205025),
  Reverberate                           = Spell(281482),
  Supernova                             = Spell(157980), --Splash, 8
  TouchoftheMagi                        = Spell(321507), --Splash, 8
  -- Buffs
  AetherAttunementBuff                  = Spell(453601),
  AethervisionBuff                      = Spell(467634),
  ArcaneFamiliarBuff                    = Spell(210126),
  ArcaneHarmonyBuff                     = Spell(384455),
  ArcaneSurgeBuff                       = Spell(365362),
  ArcaneTempoBuff                       = Spell(383997),
  ClearcastingBuff                      = Spell(263725),
  ClarityBuff                           = Spell(1216178), -- TWW S2 Tier 2pc
  EnlightenedBuff                       = Spell(1217242),
  IntuitionBuff                         = Spell(455681), -- TWW S1 Tier 4pc
  LeydrinkerBuff                        = Spell(453758),
  NetherPrecisionBuff                   = Spell(383783),
  PresenceofMindBuff                    = Spell(205025),
  SiphonStormBuff                       = Spell(384267),
  -- Debuffs
  MagisSparkABDebuff                    = Spell(453912),
  MagisSparkABarDebuff                  = Spell(451911),
  MagisSparkAMDebuff                    = Spell(453898),
  TouchoftheMagiDebuff                  = Spell(210824),
  -- Misc
  StopAM                                = Spell(363653),
})
Spell.Mage.Arcane = MergeTableByKey(Spell.Mage.Arcane, Spell.Mage.Spellslinger)
Spell.Mage.Arcane = MergeTableByKey(Spell.Mage.Arcane, Spell.Mage.Sunfury)

Spell.Mage.Fire = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  Fireball                              = Spell(133),
  Flamestrike                           = Spell(2120),
  -- Talents
  AlexstraszasFury                      = Spell(235870),
  CalloftheSunKing                      = Spell(343222),
  Combustion                            = Spell(190319),
  FeeltheBurn                           = Spell(383391),
  FlameAccelerant                       = Spell(203275),
  FireBlast                             = Spell(108853),
  Firestarter                           = Spell(205026),
  FlamePatch                            = Spell(205037),
  Hyperthermia                          = Spell(383860),
  ImprovedScorch                        = Spell(383604),
  Kindling                              = Spell(155148),
  Meteor                                = Spell(153561),
  PhoenixFlames                         = Spell(257541),
  PhoenixReborn                         = Spell(453123),
  Pyroblast                             = Spell(11366),
  Quickflame                            = Spell(450807),
  Scald                                 = Spell(450746),
  Scorch                                = Spell(2948),
  SearingTouch                          = Spell(269644),
  SpontaneousCombustion                 = Spell(451875),
  SunKingsBlessing                      = Spell(383886),
  UnleashedInferno                      = Spell(416506),
  -- Buffs
  CombustionBuff                        = Spell(190319),
  FeeltheBurnBuff                       = Spell(383395),
  FlameAccelerantBuff                   = Spell(203277),
  FlamesFuryBuff                        = Spell(409964), -- T30 4pc bonus
  HeatShimmerBuff                       = Spell(458964),
  HeatingUpBuff                         = Spell(48107),
  HotStreakBuff                         = Spell(48108),
  HyperthermiaBuff                      = Spell(383874),
  RollinHotBuff                         = Spell(1219035), -- TWW S2 Tier 4pc
  SunKingsBlessingBuff                  = Spell(383882),
  FuryoftheSunKingBuff                  = Spell(383883),
  -- Debuffs
  IgniteDebuff                          = Spell(12654),
  ImprovedScorchDebuff                  = Spell(383608),
})
Spell.Mage.Fire = MergeTableByKey(Spell.Mage.Fire, Spell.Mage.Frostfire)
Spell.Mage.Fire = MergeTableByKey(Spell.Mage.Fire, Spell.Mage.Sunfury)

Spell.Mage.Frost = MergeTableByKey(Spell.Mage.Commons, {
  -- Abilities
  Blizzard                              = Spell(190356), --splash, 16
  ConeofCold                            = Spell(120),--Melee, 12
  FireBlast                             = Spell(319836),
  -- Talents
  ColdFront                             = Spell(382110),
  ColdestSnap                           = Spell(417493),
  CometStorm                            = Spell(153595), --splash, 6
  DeathsChill                           = Spell(450331),
  DeepShatter                           = Spell(378749),
  Flurry                                = Spell(44614),
  FreezingRain                          = Spell(270233),
  Frostbite                             = Spell(378756),
  FrozenOrb                             = Spell(84714), --splash, 16
  FrozenTouch                           = Spell(205030),
  GlacialSpike                          = Spell(199786), --splash, 8 (with splitting ice)
  IceCaller                             = Spell(236662),
  IceLance                              = Spell(30455), --splash, 8 (with splitting ice)
  IcyVeins                              = Spell(12472),
  RayofFrost                            = Spell(205021),
  SlickIce                              = Spell(382144),
  SplinteringCold                       = Spell(379049),
  SplinteringRay                        = Spell(418733),
  -- Pet Abilities
  Freeze                                = Spell(33395), --splash, 8
  -- Buffs
  BrainFreezeBuff                       = Spell(190446),
  DeathsChillBuff                       = Spell(454371),
  ExtendedBankrollBuff                  = Spell(1216914), -- TWW S2 Tier 4pc
  FingersofFrostBuff                    = Spell(44544),
  FreezingRainBuff                      = Spell(270232),
  FreezingWindsBuff                     = Spell(382106),
  GlacialSpikeBuff                      = Spell(199844),
  IciclesBuff                           = Spell(205473),
  IcyVeinsBuff                          = Spell(12472),
  -- Debuffs
  FreezingWindsDebuff                   = Spell(1216988),
  WintersChillDebuff                    = Spell(228358),
})
Spell.Mage.Frost = MergeTableByKey(Spell.Mage.Frost, Spell.Mage.Frostfire)
Spell.Mage.Frost = MergeTableByKey(Spell.Mage.Frost, Spell.Mage.Spellslinger)

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Commons = {
  -- Trinkets kept for variables
  NymuesUnravelingSpindle               = Item(208615, {13, 14}),
  -- TWW Trinkets
  ImperfectAscendancySerum              = Item(225654, {13, 14}),
  SpymastersWeb                         = Item(220202, {13, 14}),
  TreacherousTransmitter                = Item(221023, {13, 14}),
}

Item.Mage.Arcane = MergeTableByKey(Item.Mage.Commons, {
  -- TWW Trinkets
  AberrantSpellforge                    = Item(212451, {13, 14}),
  FearbreakersEcho                      = Item(224449, {13, 14}),
  HighSpeakersAccretion                 = Item(219303, {13, 14}),
  MadQueensMandate                      = Item(212454, {13, 14}),
  MereldarsToll                         = Item(219313, {13, 14}),
  QuickwickCandlestick                  = Item(225649, {13, 14}),
  SignetofthePriory                     = Item(219308, {13, 14}),
})

Item.Mage.Fire = MergeTableByKey(Item.Mage.Commons, {
  -- DF Gladiator's Badges
  CrimsonGladiatorsBadge                = Item(201807, {13, 14}),
  DraconicGladiatorsBadge               = Item(216279, {13, 14}),
  ObsidianGladiatorsBadge               = Item(205708, {13, 14}),
  VerdantGladiatorsBadge                = Item(209343, {13, 14}),
  -- TWW Gladiator's Badges
  ForgedGladiatorsBadge                 = Item(218713, {13, 14}),
  -- Trinkets kept for variables
  DragonfireBombDispenser               = Item(202610, {13, 14}),
  HornofValor                           = Item(133642, {13, 14}),
  IrideusFragment                       = Item(193743, {13, 14}),
  MoonlitPrism                          = Item(137541, {13, 14}),
  SpoilsofNeltharus                     = Item(193773, {13, 14}),
  TimebreachingTalon                    = Item(193791, {13, 14}),
})

Item.Mage.Frost = MergeTableByKey(Item.Mage.Commons, {
  -- TWW Trinkets
  BurstofKnowledge                      = Item(231424, {13, 14}),
})

--[[ Variables
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
end]]
