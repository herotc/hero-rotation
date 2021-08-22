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
-- lua
local GetTime    = GetTime

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
  FireBlast                             = Spell(319836),
  MirrorImage                           = Spell(55342),
  PresenceofMind                        = Spell(205025),
  TouchoftheMagi                        = Spell(321507), --Splash, 8
  Frostbolt                             = Spell(116),
  ConjureManaHem                        = Spell(759),
  FrostNova                             = Spell(122),
  TimeWarp                              = Spell(80353),
  AlterTime                             = Spell(108978),
  SpellSteal                            = Spell(30449),
  RemoveCurse                           = Spell(475),
  Invisibility                          = Spell(66),
  SlowFall                              = Spell(130),
  IceBlock                              = Spell(45438),
  PrismaticBarrier                      = Spell(235450),
  GreaterInvisibility                   = Spell(110959),
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
  FocusMagic                            = Spell(321358),
  RingOfFrost                           = Spell(113724),
  -- Covenant Abilities
  RadiantSpark                          = Spell(307443),
  RadiantSparkVulnerability             = Spell(307454),
  MirrorsofTorment                      = Spell(314793),
  Deathborne                            = Spell(324220),
  Fleshcraft                            = Spell(324631),
  ShiftingPower                         = Spell(314791),
  FieldOfBlossoms                       = Spell(319191),
  -- Conduit
  ArcaneProdigy                         = Spell(336873),
  VolatileSolvent                       = Spell(323074),
  PustuleEruption                       = Spell(351094),
  -- Legendaries (Shadowlands)
  ExpandedPotentialBuff                 = Spell(327495),
  SiphonStormBuff                       = Spell(332928),
  DisciplinaryCommandBuff               = Spell(327371),
  ArcaneHarmonyBuff                     = Spell(332777),
  -- Trinket
  SoulIgniterBuff                       = Spell(345211),
  TomeofMonstruousConstructionsBuff     = Spell(357163),
}

Spell.Mage.Fire = {
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
  ArcaneIntellect                       = Spell(1459),
  ArcaneIntellectBuff                   = Spell(1459),
  ArcaneExplosion                       = Spell(1449),
  Blink                                 = MultiSpell(1953, 212653),
  Frostbolt                             = Spell(116),
  TimeWarp                              = Spell(80353),
  MirrorImage                           = Spell(55342),
  Pyroblast                             = Spell(11366),
  Combustion                            = Spell(190319),
  CombustionBuff                        = Spell(190319),
  FireBlast                             = Spell(108853),
  Fireball                              = Spell(133),
  Scorch                                = Spell(2948),
  HeatingUpBuff                         = Spell(48107),
  HotStreakBuff                         = Spell(48108),
  PhoenixFlames                         = Spell(257541),
  DragonsBreath                         = Spell(31661),
  Flamestrike                           = Spell(2120),
  Counterspell                          = Spell(2139),
  FrostNova                             = Spell(122),
  Ignite                                = Spell(12654),
  AlterTime                             = Spell(108978),
  SpellSteal                            = Spell(30449),
  RemoveCurse                           = Spell(475),
  Invisibility                          = Spell(66),
  SlowFall                              = Spell(130),
  IceBlock                              = Spell(45438),
  BlazingBarrier                        = Spell(235313),
  -- Talents
  Firestarter                           = Spell(205026),
  SearingTouch                          = Spell(269644),
  RuneofPower                           = Spell(116011),
  RuneofPowerBuff                       = Spell(116014),
  FlameOn                               = Spell(205029),
  AlexstraszasFury                      = Spell(235870),
  FromTheAshes                          = Spell(342344),
  FlamePatch                            = Spell(205037),
  LivingBomb                            = Spell(44457),
  Kindling                              = Spell(155148),
  Pyroclasm                             = Spell(269650),
  PyroclasmBuff                         = Spell(269651),
  Meteor                                = Spell(153561),
  FocusMagic                            = Spell(321358),
  RingOfFrost                           = Spell(113724),
  BlastWave                             = Spell(157981),
  -- Covenant Abilities
  Deathborne                            = Spell(324220),
  DeathborneBuff                        = Spell(324220),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  MirrorsofTorment                      = Spell(314793),
  RadiantSpark                          = Spell(307443),
  RadiantSparkDebuff                    = Spell(307443),
  RaidantSparkVulnerability             = Spell(307454),
  ShiftingPower                         = Spell(314791), --Melee 15
  Soulshape                             = Spell(310143),
  WastelandPropriety                    = Spell(333251),
  SiphonedMalice                        = Spell(337090),
  GroveInvigoration                     = Spell(322721),
  FieldOfBlossoms                       = Spell(319191),
  IreOfTheAscended                      = Spell(337058),
  -- Conduit
  FlameAccretion                        = Spell(337224),
  InfernalCascade                       = Spell(336821),
  InfernalCascadeBuff                   = Spell(336832),
  -- Legendaries (Shadowlands)
  FirestormBuff                         = Spell(333100),
  SunKingsBlessingBuff                  = Spell(333314),
  SunKingsBlessingBuffReady             = Spell(333315),
  GrislyIcicleBuff                      = Spell(333393),
  GrislyIcicleDebuff                    = Spell(348007),
  DisciplinaryCommandBuff               = Spell(327371),
  -- Trinkets
  SoulIgnitionBuff                      = Spell(345211),
  TomeofMonstruousConstructionsBuff     = Spell(357163),
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
  TemporalDisplacement                  = Spell(80354),
  AlterTime                             = Spell(108978),
  SpellSteal                            = Spell(30449),
  RemoveCurse                           = Spell(475),
  Invisibility                          = Spell(66),
  SlowFall                              = Spell(130),
  IceBarrier                            = Spell(11426),
  IceBlock                              = Spell(45438),
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
  RingOfFrost                           = Spell(113724),
  -- Covenant Abilities
  CombatMeditation                      = Spell(328266),
  Deathborne                            = Spell(324220),
  DoorofShadows                         = Spell(300728),
  Fleshcraft                            = Spell(324631),
  MirrorsofTorment                      = Spell(314793),
  RadiantSpark                          = Spell(307443),
  RadiantSparkDebuff                    = Spell(307443),
  RaidantSparkVulnerability             = Spell(307454),
  ShiftingPower                         = Spell(314791), --Melee 15
  Soulshape                             = Spell(310143),
  WastelandPropriety                    = Spell(333251),
  SiphonedMalice                        = Spell(337090),
  GroveInvigoration                     = Spell(322721),
  FieldOfBlossoms                       = Spell(319191),
  IreOfTheAscended                      = Spell(337058),
  -- Conduit
  -- Legendaries (Shadowlands)
  ExpandedPotentialBuff                 = Spell(327495),
  FreezingWindsBuff                     = Spell(327364),
  SlickIceBuff                          = Spell(327508),
  DisciplinaryCommandBuff               = Spell(327371),
  -- Trinkets
  TomeofMonstruousConstructionsBuff     = Spell(357163),
}

-- Items
if not Item.Mage then Item.Mage = {} end
Item.Mage.Arcane = {
  ManaGem                          = Item(36799),
  -- Potion,
  PotionofSpectralIntellect        = Item(171273),
  -- Trinkets
  DarkmoonDeckPutrescence          = Item(173069),
  DreadfireVessel                  = Item(184030),
  EmpyrealOrdnance                 = Item(180117),
  FlameofBattle                    = Item(181501),
  GlyphofAssimilation              = Item(184021),
  InscrutableQuantumDevice         = Item(179350),
  MacabreSheetMusic                = Item(184024),
  SinfulGladiatorsBadge            = Item(175921),
  SoulIgniter                      = Item(184019),
  SoullettingRuby                  = Item(178809),
  SunbloodAmethyst                 = Item(178826),
  WakenersFrond                    = Item(181457),
  ShadowedOrbofTorment             = Item(186428),
  TomeofMonstruousConstructions    = Item(186422),
}

Item.Mage.Fire = {
  -- Potion,
  PotionofSpectralIntellect        = Item(171273),
  -- Trinkets
  DreadfireVessel                  = Item(184030),
  EmpyrealOrdnance                 = Item(180117),
  FlameofBattle                    = Item(181501),
  GlyphofAssimilation              = Item(184021),
  InscrutableQuantumDevice         = Item(179350),
  InstructorsDivineBell            = Item(184842),
  MacabreSheetMusic                = Item(184024),
  SinfulAspirantsBadge             = Item(175884),
  SinfulGladiatorsBadge            = Item(175921),
  SoulIgniter                      = Item(184019),
  SunbloodAmethyst                 = Item(178826),
  WakenersFrond                    = Item(181457),
  ShadowedOrbofTorment             = Item(186428),
  TomeofMonstruousConstructions    = Item(186422),
}

Item.Mage.Frost = {
  PotionofSpectralIntellect        = Item(171273),
  ShadowedOrbofTorment             = Item(186428),
  TomeofMonstruousConstructions    = Item(186422),
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

Mage.DC = {
  Arcane = 0,
  ArcaneTime = 0,
  Fire = 0,
  FireTime = 0,
  Frost = 0,
  FrostTime = 0
}

function Mage.DCCheck()
  local CurrentTime = GetTime()
  local specID = Cache.Persistent.Player.Spec[1]
  local S
  if specID == 62 then
    S = Spell.Mage.Arcane
  elseif specID == 63 then
    S = Spell.Mage.Fire
  elseif specID == 64 then
    S = Spell.Mage.Frost
  end

  local M = Mage.DC
  local var_disciplinary_command_cd_remains = 30 - S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  if Player:BuffDown(S.DisciplinaryCommandBuff) and var_disciplinary_command_cd_remains <= 0 then
    if M.Arcane == 0 then
      -- Split Blink (1953)/Shimmer (212653) into unique spell objects, as PrevGCD doesn't like MultiSpell, apparently
      if Player:PrevOffGCD(1, S.Counterspell) or Player:PrevGCD(1, S.ArcaneExplosion) or Player:PrevGCD(1, S.RuneofPower) or Player:PrevOffGCD(1, Spell(212653)) or Player:PrevOffGCD(1, Spell(1953)) or Player:PrevGCD(1, S.ArcaneIntellect) or Player:PrevGCD(1, S.AlterTime) or Player:PrevGCD(1, S.SpellSteal) or Player:PrevGCD(1, S.RemoveCurse) or Player:PrevGCD(1, S.MirrorImage) or Player:PrevGCD(1, S.Invisibility) or Player:PrevGCD(1, S.SlowFall) or Player:PrevGCD(1, S.FocusMagic) or Player:PrevOffGCD(1, S.TimeWarp)
      or (S.RuneofPower:IsAvailable() and ((specID == 64 and Player:PrevOffGCD(1, S.IcyVeins)) or (specID == 63 and Player:PrevOffGCD(1, S.Combustion)) or (specID == 62 and Player:PrevOffGCD(1, S.ArcanePower)))) 
      or (specID == 62 and (Player:PrevGCD(1, S.ArcaneBarrage) or Player:PrevGCD(1, S.ArcaneBlast) or Player:PrevGCD(1, S.ArcaneMissiles) or Player:PrevGCD(1, S.ArcaneOrb) or Player:PrevOffGCD(1, S.ArcanePower) or Player:PrevGCD(1, S.Evocation) or Player:PrevGCD(1, S.PresenceofMind) or Player:PrevGCD(1, S.GreaterInvisibility) or Player:PrevGCD(1, S.PrismaticBarrier) or Player:PrevGCD(1, S.TouchoftheMagi) or Player:PrevGCD(1, S.ArcaneFamiliar) or Player:PrevGCD(1, S.NetherTempest) or Player:PrevGCD(1, S.Supernova))) then
        M.Arcane = 1
        M.ArcaneTime = CurrentTime
      end
    end
    if M.Fire == 0 then
      if Player:PrevGCD(1, S.FireBlast)
      or (specID == 63 and (Player:PrevOffGCD(1, S.FireBlast) or Player:PrevGCD(1, S.Fireball) or Player:PrevGCD(1, S.Scorch) or Player:PrevGCD(1, S.Pyroblast) or Player:PrevGCD(1, S.Flamestrike) or Player:PrevGCD(1, S.BlazingBarrier) or Player:PrevOffGCD(1, S.Combustion) or Player:PrevGCD(1, S.DragonsBreath) or Player:PrevGCD(1, S.PhoenixFlames) or Player:PrevGCD(1, S.BlastWave) or Player:PrevGCD(1, S.LivingBomb) or Player:PrevGCD(1, S.Meteor))) then
        M.Fire = 1
        M.FireTime = CurrentTime
      end
    end
    if M.Frost == 0 then
      if Player:PrevGCD(1, S.Frostbolt) or Player:PrevGCD(1, S.FrostNova) or Player:PrevGCD(1, S.IceBlock) or Player:PrevGCD(1, S.RingOfFrost) 
      or (specID == 64 and (Player:PrevGCD(1, S.IceLance) or Player:PrevGCD(1, S.Flurry) or Player:PrevGCD(1, S.Blizzard) or Player:PrevGCD(1, S.ConeofCold) or Player:PrevGCD(1, S.FrozenOrb) or Player:PrevGCD(1, S.IceBarrier) or Player:PrevOffGCD(1, S.IcyVeins) or Player:PrevGCD(1, S.RayofFrost) or Player:PrevGCD(1, S.GlacialSpike) or Player:PrevGCD(1, S.CometStorm) or Player:PrevGCD(1, S.Ebonbolt) or Player:PrevOffGCD(1, S.IceFloes) or Player:PrevOffGCD(1, S.IceNova) or Player:PrevOffGCD(1, S.SummonWaterElemental))) then
        M.Frost = 1
        M.FrostTime = CurrentTime
      end
    end
  end
  if Player:BuffUp(S.DisciplinaryCommandBuff) and (M.Arcane == 1 or M.Fire == 1 or M.Frost == 1) then
    M.Arcane = 0
    M.Fire = 0
    M.Frost = 0
  end
  if M.Arcane == 1 and M.ArcaneTime < CurrentTime - 10 then
    M.Arcane = 0
  end
  if M.Fire == 1 and M.FireTime < CurrentTime - 10 then
    M.Fire = 0
  end
  if M.Frost == 1 and M.FrostTime < CurrentTime - 10 then
    M.Frost = 0
  end
end
