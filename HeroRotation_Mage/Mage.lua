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

-- File Locals
HR.Commons.Mage = {}
local Settings = HR.GUISettings.APL.Mage.Commons
local Mage = HR.Commons.Mage

--- ============================ CONTENT ============================

-- Spells
if not Spell.Mage then Spell.Mage = {} end
Spell.Mage.Arcane = {
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BerserkingBuff                        = Spell(26297),
  BloodFury                             = Spell(20572),
  BloodFuryBuff                         = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Abilities
  ArcaneBarrage                         = Spell(44425), --Splash, 10
  ArcaneBlast                           = Spell(30451),
  ArcaneMissiles                        = Spell(5143),
  ArcaneExplosion                       = Spell(1449), --Melee, 10
  ArcaneIntellect                       = Spell(1459),
  ArcanePower                           = Spell(12042),
  Blink                                 = MultiSpell(1953, 212653),
  ClearcastingBuff                      = Spell(263725),
  Counterspell                          = Spell(2139),
  Evocation                             = Spell(12051),
  MirrorImage                           = Spell(55342),
  PresenceofMind                        = Spell(205025),
  TouchoftheMagi                        = Spell(321507), --Splash, 8
  Frostbolt                             = Spell(116),
  ConjureManaHem                        = Spell(759),
  FrostNova                             = Spell(122),
  -- Talents
  Amplification                         = Spell(236628),
  RuleofThrees                          = Spell(264354),
  RuleofThreesBuff                      = Spell(264774),
  ArcaneFamiliar                        = Spell(205022),
  ArcaneFamiliarBuff                    = Spell(210126),
  Slipstream                            = Spell(236457),
  RuneofPower                           = Spell(116011),
  RuneofPowerBuff                       = Spell(116014),
  Resonance                             = Spell(205028),
  ArcaneEcho                            = Spell(342231), --Splash, 8
  NetherTempest                         = Spell(114923), --Splash, 10
  ArcaneOrb                             = Spell(153626), --Splash, 16
  Supernova                             = Spell(157980), --Splash, 8
  Overpowered                           = Spell(155147),
  Enlightened                           = Spell(321387),
  -- Covenant Abilities
  RadiantSpark                          = Spell(307443),
  RadiantSparlVulnerability             = Spell(307454),
  MirrorsofTorment                      = Spell(314793),
  Deathborne                            = Spell(324220),
  ShiftingPower                         = Spell(314791),
  -- Azerite Traits (BfA)
  ArcanePummeling                       = Spell(270669),
  Equipoise                             = Spell(286027),
  -- Azerite Essences (BfA)
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258), --Splash, 30 
  GuardianofAzeroth                     = Spell(295840),
  GuardianofAzerothBuff                 = Spell(295855),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337), --Splash, 8
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RippleInSpace                         = Spell(302731), --Splash, 8
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186)
}

Spell.Mage.Fire = {
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneIntellect                       = Spell(1459),
  MirrorImage                           = Spell(55342),
  Pyroblast                             = Spell(11366),
  LivingBomb                            = Spell(44457),
  CombustionBuff                        = Spell(190319),
  Combustion                            = Spell(190319),
  Meteor                                = Spell(153561),
  RuneofPowerBuff                       = Spell(116014),
  RuneofPower                           = Spell(116011),
  Firestarter                           = Spell(205026),
  LightsJudgment                        = Spell(255647),
  FireBlast                             = Spell(108853),
  BlasterMasterBuff                     = Spell(274598),
  Fireball                              = Spell(133),
  BlasterMaster                         = Spell(274596),
  BloodFury                             = Spell(20572),
  Berserking                            = Spell(26297),
  Fireblood                             = Spell(265221),
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Scorch                                = Spell(2948),
  HeatingUpBuff                         = Spell(48107),
  HotStreakBuff                         = Spell(48108),
  PyroclasmBuff                         = Spell(269651),
  PhoenixFlames                         = Spell(257541),
  DragonsBreath                         = Spell(31661),
  FlameOn                               = Spell(205029),
  Flamestrike                           = Spell(2120),
  FlamePatch                            = Spell(205037),
  SearingTouch                          = Spell(269644),
  AlexstraszasFury                      = Spell(235870),
  Kindling                              = Spell(155148),
  Counterspell                          = Spell(2139),
  BloodoftheEnemy                       = Spell(297108),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337),
  RippleInSpace                         = Spell(302731),
  ConcentratedFlame                     = Spell(295373),
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
  FocusedAzeriteBeam                    = Spell(295258),
  GuardianofAzeroth                     = Spell(295840),
  RecklessForceBuff                     = Spell(302932),
  ConcentratedFlameBurn                 = Spell(295368),
  HarmonicDematerializer                = Spell(293512),
  ReapingFlames                         = Spell(310690)
}

Spell.Mage.Frost = {
  -- Racials
  AncestralCall                         = Spell(274738),
  BagofTricks                           = Spell(312411),
  Berserking                            = Spell(26297),
  BloodFury                             = Spell(20572),
  Fireblood                             = Spell(265221),
  LightsJudgment                        = Spell(255647),
  -- Base Abilities
  ArcaneExplosion                       = Spell(1449), --Melee, 10
  ArcaneIntellect                       = Spell(1459),
  Blink                                 = MultiSpell(1953, 212653),
  Blizzard                              = Spell(190356), --splash, 16
  BrainFreezeBuff                       = Spell(190446),
  ConeofCold                            = Spell(120),--Melee, 12
  Counterspell                          = Spell(2139),
  FingersofFrostBuff                    = Spell(44544),
  Flurry                                = Spell(44614),
  Frostbolt                             = Spell(116),
  FrozenOrb                             = Spell(84714), --splash, 16
  FrostNova                             = Spell(122), --Melee, 12
  IceLance                              = Spell(30455), --splash, 8 (with splitting ice)
  IciclesBuff                           = Spell(205473),
  IcyVeins                              = Spell(12472),
  SummonWaterElemental                  = Spell(31687),
  WintersChillDebuff                    = Spell(228358),
  TimeWarp                              = Spell(80353),
  FireBlast                             = Spell(319836),
  Frostbite                             = Spell(198121),
  Freeze                                = Spell(33395), --splash, 8
  MirrorImage                           = Spell(55342),
  -- Talents
  IceNova                               = Spell(157997), --splash, 8
  IceFloes                              = Spell(108839),
  IncantersFlow                         = Spell(1463),
  IncantersFlowBuff                     = Spell(116267),
  FocusMagic                            = Spell(321358),
  RuneofPower                           = Spell(116011),
  RuneofPowerBuff                       = Spell(116014),
  Ebonbolt                              = Spell(257537), --splash, 8 (with splitting ice)
  FreezingRain                          = Spell(270233),
  SplittingIce                          = Spell(56377), --splash, 8
  CometStorm                            = Spell(153595), --splash, 6
  RayofFrost                            = Spell(205021),
  GlacialSpike                          = Spell(199786), --splash, 8 (with splitting ice)
  GlacialSpikeBuff                      = Spell(199844),
  -- Covenant Abilities
  Deathborne                            = Spell(324220),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  MirrorsofTorment                      = Spell(314793),
  RadiantSpark                          = Spell(307443),
  RadiantSparkDebuff                    = Spell(307443),
  RaidantSparkVulnerability             = Spell(307454),
  ShiftingPower                         = Spell(314791),
  Soulshape                             = Spell(310143),
  WastelandPropriety                    = Spell(333251),
  -- Conduit Effects
  -- Azerite Traits
  PackedIceDebuff                       = Spell(272970),
  -- Essences
  BloodoftheEnemy                       = Spell(297108),
  ConcentratedFlame                     = Spell(295373),
  ConcentratedFlameBurn                 = Spell(295368),
  FocusedAzeriteBeam                    = Spell(295258), --Splash, 30
  GuardianofAzeroth                     = Spell(295840),
  MemoryofLucidDreams                   = Spell(298357),
  PurifyingBlast                        = Spell(295337), --Splash, 8
  ReapingFlames                         = Spell(310690),
  RecklessForceBuff                     = Spell(302932),
  RippleInSpace                         = Spell(302731), --Splash, 8
  TheUnboundForce                       = Spell(298452),
  WorldveinResonance                    = Spell(295186),
}

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Arcane = {
  ManaGem                          = Item (36799),
  PotionofFocusedResolve           = Item(168506),
  TidestormCodex                   = Item(165576, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  -- Other On Use Trinkets for VarFontDoubleOnUse
  NotoriousAspirantsBadge          = Item(167528, {13, 14}),
  NotoriousGladiatorsBadge         = Item(167380, {13, 14}),
  SinisterGladiatorsBadge          = Item(165058, {13, 14}),
  SinisterAspirantsBadge           = Item(165223, {13, 14}),
  DreadGladiatorsBadge             = Item(161902, {13, 14}),
  DreadAspirantsBadge              = Item(162966, {13, 14}),
  DreadCombatantsInsignia          = Item(161676, {13, 14}),
  NotoriousAspirantsMedallion      = Item(167525, {13, 14}),
  NotoriousGladiatorsMedallion     = Item(167377, {13, 14}),
  SinisterGladiatorsMedallion      = Item(165055, {13, 14}),
  SinisterAspirantsMedallion       = Item(165220, {13, 14}),
  DreadGladiatorsMedallion         = Item(161674, {13, 14}),
  DreadAspirantsMedallion          = Item(162897, {13, 14}),
  DreadCombatantsMedallion         = Item(161811, {13, 14}),
  IgnitionMagesFuse                = Item(159615, {13, 14}),
  TzanesBarkspines                 = Item(161411, {13, 14}),
  AzurethoseSingedPlumage          = Item(161377, {13, 14}),
  AncientKnotofWisdomAlliance      = Item(161417, {13, 14}),
  AncientKnotofWisdomHorde         = Item(166793, {13, 14}),
  ShockbitersFang                  = Item(169318, {13, 14}),
  NeuralSynapseEnhancer            = Item(168973, {13, 14}),
  BalefireBranch                   = Item(159630, {13, 14}),
  ManifestoofMadness               = Item(174103, {13, 14})
}

Item.Mage.Fire = {
  -- Potion
  SuperiorBattlePotionofIntellect  = Item(168498),
  -- Non-trinket items
  HyperthreadWristwraps            = Item(168989),
  MalformedHeraldsLegwraps         = Item(167835),
  -- Trinkets
  IgnitionMagesFuse                = Item(159615, {13, 14}),
  RotcrustedVoodooDoll             = Item(159624, {13, 14}),
  BalefireBranch                   = Item(159630, {13, 14}),
  AzurethoseSingedPlumage          = Item(161377, {13, 14}),
  TzanesBarkspines                 = Item(161411, {13, 14}),
  AncientKnotofWisdomAlliance      = Item(161417, {13, 14}),
  TidestormCodex                   = Item(165576, {13, 14}),
  AncientKnotofWisdomHorde         = Item(166793, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14}),
  ShiverVenomRelic                 = Item(168905, {13, 14}),
  NeuralSynapseEnhancer            = Item(168973, {13, 14}),
  AquipotentNautilus               = Item(169305, {13, 14}),
  AzsharasFontofPower              = Item(169314, {13, 14}),
  ShockbitersFang                  = Item(169318, {13, 14}),
  ForbiddenObsidianClaw            = Item(173944, {13, 14}),
  ManifestoofMadness               = Item(174103, {13, 14}),
  -- PvP Badges/Medallions
  DreadGladiatorsMedallion         = Item(161674, {13, 14}),
  DreadCombatantsInsignia          = Item(161676, {13, 14}),
  DreadCombatantsMedallion         = Item(161811, {13, 14}),
  DreadGladiatorsBadge             = Item(161902, {13, 14}),
  DreadAspirantsMedallion          = Item(162897, {13, 14}),
  DreadAspirantsBadge              = Item(162966, {13, 14}),
  SinisterGladiatorsMedallion      = Item(165055, {13, 14}),
  SinisterGladiatorsBadge          = Item(165058, {13, 14}),
  SinisterAspirantsMedallion       = Item(165220, {13, 14}),
  SinisterAspirantsBadge           = Item(165223, {13, 14}),
  NotoriousGladiatorsMedallion     = Item(167377, {13, 14}),
  NotoriousGladiatorsBadge         = Item(167380, {13, 14}),
  NotoriousAspirantsMedallion      = Item(167525, {13, 14}),
  NotoriousAspirantsBadge          = Item(167528, {13, 14})
}

Item.Mage.Frost = {
  BalefireBranch                   = Item(159630, {13, 14}),
  TidestormCodex                   = Item(165576, {13, 14}),
  PocketsizedComputationDevice     = Item(167555, {13, 14})
}

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
