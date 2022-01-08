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
local MouseOver  = Unit.MouseOver
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
local MergeTableByKey = HL.Utils.MergeTableByKey
-- HeroRotation
local HR = HeroRotation
local Everyone = HR.Commons.Everyone
-- Lua
local mathmin = math.min
local pairs = pairs
-- File Locals
local Commons = {}

--- ======= GLOBALIZE =======
HR.Commons.Rogue = Commons

--- ============================ CONTENT ============================
-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Rogue.Commons,
  Commons2 = HR.GUISettings.APL.Rogue.Commons2,
  Assassination = HR.GUISettings.APL.Rogue.Assassination,
  Outlaw = HR.GUISettings.APL.Rogue.Outlaw,
  Subtlety = HR.GUISettings.APL.Rogue.Subtlety
}

-- Spells
if not Spell.Rogue then Spell.Rogue = {} end

Spell.Rogue.Commons = {
  -- Racials
  AncestralCall           = Spell(274738),
  ArcanePulse             = Spell(260364),
  ArcaneTorrent           = Spell(25046),
  BagofTricks             = Spell(312411),
  Berserking              = Spell(26297),
  BloodFury               = Spell(20572),
  Fireblood               = Spell(265221),
  LightsJudgment          = Spell(255647),
  Shadowmeld              = Spell(58984),
  -- Defensive
  CloakofShadows          = Spell(31224),
  CrimsonVial             = Spell(185311),
  Evasion                 = Spell(5277),
  Feint                   = Spell(1966),
  -- Utility
  Blind                   = Spell(2094),
  CheapShot               = Spell(1833),
  Kick                    = Spell(1766),
  KidneyShot              = Spell(408),
  Sap                     = Spell(6770),
  Shadowstep              = Spell(36554),
  Sprint                  = Spell(2983),
  TricksoftheTrade        = Spell(57934),
  -- Legendaries (Shadowlands)
  MasterAssassinsMark     = Spell(340094),
  -- Covenants (Shadowlands)
  EchoingReprimand        = Spell(323547),
  EchoingReprimand2       = Spell(323558),
  EchoingReprimand3       = Spell(323559),
  EchoingReprimand4       = Spell(323560),
  EchoingReprimand5       = Spell(354838),
  Flagellation            = Spell(323654),
  FlagellationBuff        = Spell(345569),
  Fleshcraft              = Spell(324631),
  Sepsis                  = Spell(328305),
  SepsisBuff              = Spell(347037),
  SerratedBoneSpike       = Spell(328547),
  SerratedBoneSpikeDebuff = Spell(324073),
  -- Soulbinds/Conduits (Shadowlands)
  KevinsOozeling          = Spell(352110),
  KevinsWrathDebuff       = Spell(352528),
  LeadbyExample           = Spell(342156),
  LeadbyExampleBuff       = Spell(342181),
  MarrowedGemstoneBuff    = Spell(327069),
  PustuleEruption         = Spell(351094),
  VolatileSolvent         = Spell(323074),
  -- Domination Shards
  ChaosBaneBuff           = Spell(355829),
  -- Misc
  PoolEnergy              = Spell(999910),
  SinfulRevelationDebuff  = Spell(324260),
}

Spell.Rogue.Assassination = MergeTableByKey(Spell.Rogue.Commons, {
  -- Abilities
  Ambush                  = Spell(8676),
  DeadlyPoison            = Spell(2823),
  DeadlyPoisonDebuff      = Spell(2818),
  Envenom                 = Spell(32645),
  FanofKnives             = Spell(51723),
  Garrote                 = Spell(703),
  Mutilate                = Spell(1329),
  PoisonedKnife           = Spell(185565),
  Rupture                 = Spell(1943),
  SliceandDice            = Spell(315496),
  Stealth                 = Spell(1784),
  Stealth2                = Spell(115191), -- w/ Subterfuge Talent
  Vanish                  = Spell(1856),
  VanishBuff              = Spell(11327),
  Vendetta                = Spell(79140),
  WoundPoison             = Spell(8679),
  WoundPoisonDebuff       = Spell(8680),
  -- Talents
  BlindsideBuff           = Spell(121153),
  CrimsonTempest          = Spell(121411),
  DeeperStratagem         = Spell(193531),
  Elusiveness             = Spell(79008),
  Exsanguinate            = Spell(200806),
  HiddenBladesBuff        = Spell(270070),
  InternalBleeding        = Spell(154953),
  MarkedforDeath          = Spell(137619),
  MasterAssassin          = Spell(255989),
  MasterAssassinBuff      = Spell(256735),
  Nightstalker            = Spell(14062),
  PreyontheWeak           = Spell(131511),
  PreyontheWeakDebuff     = Spell(255909),
  Shiv                    = Spell(5938),
  ShivDebuff              = Spell(319504),
  Subterfuge              = Spell(108208),
  SubterfugeBuff          = Spell(115192),
  VenomRush               = Spell(152152),
  -- PvP
  DeathfromAbove          = Spell(269513),
  Maneuverability         = Spell(197000),
  Neurotoxin              = Spell(206328),
  SmokeBomb               = Spell(212182),
})

Spell.Rogue.Outlaw = MergeTableByKey(Spell.Rogue.Commons, {
  -- Abilities
  AdrenalineRush          = Spell(13750),
  Ambush                  = Spell(8676),
  BetweentheEyes          = Spell(315341),
  BladeFlurry             = Spell(13877),
  Dispatch                = Spell(2098),
  Elusiveness             = Spell(79008),
  Opportunity             = Spell(195627),
  PistolShot              = Spell(185763),
  RolltheBones            = Spell(315508),
  Shiv                    = Spell(5938),
  SinisterStrike          = Spell(193315),
  SliceandDice            = Spell(315496),
  Stealth                 = Spell(1784),
  Vanish                  = Spell(1856),
  VanishBuff              = Spell(11327),
  -- Talents
  AcrobaticStrikes        = Spell(196924),
  BladeRush               = Spell(271877),
  DeeperStratagem         = Spell(193531),
  Dreadblades             = Spell(343142),
  GhostlyStrike           = Spell(196937),
  KillingSpree            = Spell(51690),
  LoadedDiceBuff          = Spell(256171),
  MarkedforDeath          = Spell(137619),
  PreyontheWeak           = Spell(131511),
  PreyontheWeakDebuff     = Spell(255909),
  QuickDraw               = Spell(196938),
  -- Utility
  Gouge                   = Spell(1776),
  -- PvP
  DeathfromAbove          = Spell(269513),
  Dismantle               = Spell(207777),
  Maneuverability         = Spell(197000),
  PlunderArmor            = Spell(198529),
  SmokeBomb               = Spell(212182),
  ThickasThieves          = Spell(221622),
  -- Roll the Bones
  Broadside               = Spell(193356),
  BuriedTreasure          = Spell(199600),
  GrandMelee              = Spell(193358),
  RuthlessPrecision       = Spell(193357),
  SkullandCrossbones      = Spell(199603),
  TrueBearing             = Spell(193359),
  -- Soulbinds/Conduits (Shadowlands)
  Ambidexterity           = Spell(341542),
  CountTheOdds            = Spell(341546),
  -- Legendaries (Shadowlands)
  ConcealedBlunderbuss    = Spell(340587),
  DeathlyShadowsBuff      = Spell(341202),
  GreenskinsWickers       = Spell(340573),
})

Spell.Rogue.Subtlety = MergeTableByKey(Spell.Rogue.Commons, {
  -- Racials
  AncestralCall           = Spell(274738),
  ArcanePulse             = Spell(260364),
  ArcaneTorrent           = Spell(50613),
  BagofTricks             = Spell(312411),
  Berserking              = Spell(26297),
  BloodFury               = Spell(20572),
  Fireblood               = Spell(265221),
  LightsJudgment          = Spell(255647),
  Shadowmeld              = Spell(58984),
  -- Abilities
  Backstab                = Spell(53),
  BlackPowder             = Spell(319175),
  Elusiveness             = Spell(79008),
  Eviscerate              = Spell(196819),
  FindWeaknessDebuff      = Spell(316220),
  Rupture                 = Spell(1943),
  ShadowBlades            = Spell(121471),
  ShadowDance             = Spell(185313),
  ShadowDanceBuff         = Spell(185422),
  Shadowstrike            = Spell(185438),
  Shiv                    = Spell(5938),
  ShurikenStorm           = Spell(197835),
  ShurikenToss            = Spell(114014),
  SliceandDice            = Spell(315496),
  Stealth                 = Spell(1784),
  Stealth2                = Spell(115191), -- w/ Subterfuge Talent
  SymbolsofDeath          = Spell(212283),
  SymbolsofDeathCrit      = Spell(227151),
  Vanish                  = Spell(1856),
  VanishBuff              = Spell(11327),
  VanishBuff2             = Spell(115193), -- w/ Subterfuge Talent
  -- Talents
  Alacrity                = Spell(193539),
  DarkShadow              = Spell(245687),
  DeeperStratagem         = Spell(193531),
  EnvelopingShadows       = Spell(238104),
  Gloomblade              = Spell(200758),
  MarkedforDeath          = Spell(137619),
  MasterofShadows         = Spell(196976),
  Nightstalker            = Spell(14062),
  PreyontheWeak           = Spell(131511),
  PreyontheWeakDebuff     = Spell(255909),
  Premeditation           = Spell(343160),
  PremeditationBuff       = Spell(343173),
  SecretTechnique         = Spell(280719),
  ShadowFocus             = Spell(108209),
  ShurikenTornado         = Spell(277925),
  Subterfuge              = Spell(108208),
  Vigor                   = Spell(14983),
  Weaponmaster            = Spell(193537),
  -- PvP
  ColdBlood               = Spell(213981),
  DeathfromAbove          = Spell(269513),
  Maneuverability         = Spell(197000),
  ShadowyDuel             = Spell(207736),
  SmokeBomb               = Spell(212182),
  VeilofMidnight          = Spell(198952),
  -- Soulbinds/Conduits (Shadowlands)
  DeeperDaggers           = Spell(341549),
  PerforatedVeinsBuff     = Spell(341572),
  -- Legendaries (Shadowlands)
  DeathlyShadowsBuff      = Spell(341202),
  FinalityBlackPowder     = Spell(340603),
  FinalityEviscerate      = Spell(340600),
  FinalityRupture         = Spell(340601),
  TheRottenBuff           = Spell(341134),
})

-- Items
if not Item.Rogue then Item.Rogue = {} end
Item.Rogue.Assassination = {
  -- Trinkets
  GalecallersBoon       = Item(159614, {13, 14}),
  LustrousGoldenPlumage = Item(159617, {13, 14}),
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

Item.Rogue.Outlaw = {
  -- Trinkets
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

Item.Rogue.Subtlety = {
  ComputationDevice     = Item(167555, {13, 14}),
  VigorTrinket          = Item(165572, {13, 14}),
  FontOfPower           = Item(169314, {13, 14}),
  RazorCoral            = Item(169311, {13, 14}),
}

-- Stealth
function Commons.Stealth(Stealth, Setting)
  if Settings.Commons2.StealthOOC and Stealth:IsCastable() and Player:StealthDown() then
    if HR.Cast(Stealth, Settings.Commons2.OffGCDasOffGCD.Stealth) then return "Cast Stealth (OOC)" end
  end

  return false
end

-- Crimson Vial
do
  local CrimsonVial = Spell(185311)

  function Commons.CrimsonVial()
    if CrimsonVial:IsCastable() and Player:HealthPercentage() <= Settings.Commons2.CrimsonVialHP then
      if HR.Cast(CrimsonVial, Settings.Commons2.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial (Defensives)" end
    end

    return false
  end
end

-- Feint
do
  local Feint = Spell(1966)

  function Commons.Feint()
    if Feint:IsCastable() and Player:BuffDown(Feint) and Player:HealthPercentage() <= Settings.Commons2.FeintHP then
      if HR.Cast(Feint, Settings.Commons2.GCDasOffGCD.Feint) then return "Cast Feint (Defensives)" end
    end
  end
end

-- Poisons
do
  local CripplingPoison     = Spell(3408)
  local DeadlyPoison        = Spell(2823)
  local InstantPoison       = Spell(315584)
  local NumbingPoison       = Spell(5761)
  local WoundPoison         = Spell(8679)

  function Commons.Poisons()
    local PoisonRefreshTime = Player:AffectingCombat() and Settings.Commons.PoisonRefreshCombat * 60 or Settings.Commons.PoisonRefresh * 60
    local PoisonRemains
    -- Lethal Poison
    PoisonRemains = Player:BuffRemains(WoundPoison)
    if PoisonRemains > 0 then
      if PoisonRemains < PoisonRefreshTime then
        HR.CastSuggested(WoundPoison)
      end
    else
      if DeadlyPoison:IsAvailable() then
        PoisonRemains = Player:BuffRemains(DeadlyPoison)
        if PoisonRemains < PoisonRefreshTime then
          HR.CastSuggested(DeadlyPoison)
        end
      else
        PoisonRemains = Player:BuffRemains(InstantPoison)
        if PoisonRemains < PoisonRefreshTime then
          HR.CastSuggested(InstantPoison)
        end
      end
    end
    -- Non-Lethal Poisons
    PoisonRemains = Player:BuffRemains(CripplingPoison)
    if PoisonRemains > 0 then
      if PoisonRemains < PoisonRefreshTime then
        HR.CastSuggested(CripplingPoison)
      end
    else
      PoisonRemains = Player:BuffRemains(NumbingPoison)
      if PoisonRemains < PoisonRefreshTime then
        HR.CastSuggested(NumbingPoison)
      end
    end
  end
end

-- Marked for Death Sniping
function Commons.MfDSniping(MarkedforDeath)
  if MarkedforDeath:IsCastable() then
    local BestUnit, BestUnitTTD = nil, 60
    local MOTTD = MouseOver:IsInRange(30) and MouseOver:TimeToDie() or 11111
    for _, ThisUnit in pairs(Player:GetEnemiesInRange(30)) do
      local TTD = ThisUnit:TimeToDie()
      -- Note: Increased the SimC condition by 50% since we are slower.
      if not ThisUnit:IsMfDBlacklisted() and TTD < Player:ComboPointsDeficit()*1.5 and TTD < BestUnitTTD then
        if MOTTD - TTD > 1 then
          BestUnit, BestUnitTTD = ThisUnit, TTD
        else
          BestUnit, BestUnitTTD = MouseOver, MOTTD
        end
      end
    end
    if BestUnit and BestUnit:GUID() ~= Target:GUID() then
      HR.CastLeftNameplate(BestUnit, MarkedforDeath)
    end
  end
end

-- Everyone CanDotUnit override, originally used for Mantle legendary
-- Is it worth to DoT the unit ?
function Commons.CanDoTUnit(ThisUnit, HealthThreshold)
  return Everyone.CanDoTUnit(ThisUnit, HealthThreshold)
end
--- ======= SIMC CUSTOM FUNCTION / EXPRESSION =======
-- cp_max_spend
do
  local DeeperStratagem = Spell(193531)

  function Commons.CPMaxSpend()
    return DeeperStratagem:IsAvailable() and 6 or 5
  end
end

-- "cp_spend"
function Commons.CPSpend()
  return mathmin(Player:ComboPoints(), Commons.CPMaxSpend())
end

-- "animacharged_cp"
do
  function Commons.AnimachargedCP()
    if Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand2) then
      return 2
    elseif Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand3) then
      return 3
    elseif Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand4) then
      return 4
    elseif Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand5) then
      return 5
    end

    return -1
  end

  function Commons.EffectiveComboPoints(ComboPoints)
    if ComboPoints == 2 and Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand2)
    or ComboPoints == 3 and Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand3)
    or ComboPoints == 4 and Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand4)
    or ComboPoints == 5 and Player:BuffUp(Spell.Rogue.Commons.EchoingReprimand5) then
      return 7
    end
    return ComboPoints
  end
end

-- poisoned
--[[ Original SimC Code
  return dots.deadly_poison -> is_ticking() ||
          debuffs.wound_poison -> check();
]]
do
  local DeadlyPoisonDebuff = Spell.Rogue.Assassination.DeadlyPoisonDebuff
  local WoundPoisonDebuff = Spell.Rogue.Assassination.WoundPoisonDebuff

  function Commons.Poisoned (ThisUnit)
    return (ThisUnit:DebuffUp(DeadlyPoisonDebuff) or ThisUnit:DebuffUp(WoundPoisonDebuff)) and true or false
  end
end

-- poison_remains
--[[ Original SimC Code
  if ( dots.deadly_poison -> is_ticking() ) {
    return dots.deadly_poison -> remains();
  } else if ( debuffs.wound_poison -> check() ) {
    return debuffs.wound_poison -> remains();
  } else {
    return timespan_t::from_seconds( 0.0 );
  }
]]
do
  local DeadlyPoisonDebuff = Spell.Rogue.Assassination.DeadlyPoisonDebuff
  local WoundPoisonDebuff = Spell.Rogue.Assassination.WoundPoisonDebuff

  function Commons.PoisonRemains (ThisUnit)
    return (ThisUnit:DebuffUp(DeadlyPoisonDebuff) and ThisUnit:DebuffRemains(DeadlyPoisonDebuff)) or (ThisUnit:DebuffUp(WoundPoisonDebuff) and ThisUnit:DebuffRemains(WoundPoisonDebuff)) or 0
  end
end

-- bleeds
--[[ Original SimC Code
  rogue_td_t* tdata = get_target_data( target );
  return tdata -> dots.garrote -> is_ticking() +
          tdata -> dots.internal_bleeding -> is_ticking() +
          tdata -> dots.rupture -> is_ticking();
]]
do
  local Garrote = Spell.Rogue.Assassination.Garrote
  local Rupture = Spell.Rogue.Assassination.Rupture
  local CrimsonTempest = Spell.Rogue.Assassination.CrimsonTempest
  local InternalBleeding = Spell.Rogue.Assassination.InternalBleeding

  function Commons.Bleeds ()
    return (Target:DebuffUp(Garrote) and 1 or 0) + (Target:DebuffUp(Rupture) and 1 or 0) + (Target:DebuffUp(CrimsonTempest) and 1 or 0) + (Target:DebuffUp(InternalBleeding) and 1 or 0)
  end
end

-- poisoned_bleeds
--[[ Original SimC Code
  int poisoned_bleeds = 0;
  for ( size_t i = 0, actors = sim -> target_non_sleeping_list.size(); i < actors; i++ )
  {
    player_t* t = sim -> target_non_sleeping_list[i];
    rogue_td_t* tdata = get_target_data( t );
    if ( tdata -> lethal_poisoned() ) {
      poisoned_bleeds += tdata -> dots.garrote -> is_ticking() +
                          tdata -> dots.internal_bleeding -> is_ticking() +
                          tdata -> dots.rupture -> is_ticking();
    }
  }
  return poisoned_bleeds;
]]
do
  local Garrote = Spell.Rogue.Assassination.Garrote
  local InternalBleeding = Spell.Rogue.Assassination.InternalBleeding
  local Rupture = Spell.Rogue.Assassination.Rupture

  local PoisonedBleedsCount = 0
  function Commons.PoisonedBleeds ()
    PoisonedBleedsCount = 0
    for _, ThisUnit in pairs(Player:GetEnemiesInRange(50)) do
      if Commons.Poisoned(ThisUnit) then
        if ThisUnit:DebuffUp(Garrote) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1
        end
        if ThisUnit:DebuffUp(InternalBleeding) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1
        end
        if ThisUnit:DebuffUp(Rupture) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1
        end
      end
    end
    return PoisonedBleedsCount
  end
end

-- Master Assassin's Mark Remains Check
do
  local MasterAssassinsMark, NominalDuration = Spell(340094), 4

  function Commons.MasterAssassinsMarkRemains ()
    if Player:BuffRemains(MasterAssassinsMark) < 0 then
      return Player:GCDRemains() + NominalDuration
    else
      return Player:BuffRemains(MasterAssassinsMark)
    end
  end
end
