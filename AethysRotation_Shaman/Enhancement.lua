--- Localize Vars
-- Addon
local addonName, addonTable = ...;

-- AethysCore
local AC = AethysCore;
local Cache = AethysCache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;

-- AethysRotation
local AR = AethysRotation;

-- APL from T21_Shaman_Enhancement on 2017-12-03

-- APL Local Vars
-- Spells
if not Spell.Shaman then Spell.Shaman = {}; end
Spell.Shaman.Enhancement = {
  -- Racials
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),

  -- Abilities
  CrashLightning        = Spell(187874),
  CrashLightningBuff    = Spell(187878),
  LightningCrashBuff    = Spell(242284),
  Flametongue           = Spell(193796),
  FlametongueBuff       = Spell(194084),
  Frostbrand            = Spell(196834),
  FrostbrandBuff        = Spell(196834),
  StormStrike           = Spell(17364),
  StormbringerBuff      = Spell(201846),

  FeralSpirit           = Spell(51533),
  LavaLash              = Spell(60103),
  LightningBolt         = Spell(187837),
  Rockbiter             = Spell(193786),
  WindStrike            = Spell(115356),
  HealingSurge          = Spell(188070),

  -- Talents
  Windsong              = Spell(201898),
  HotHandBuff           = Spell(215785),
  Landslide             = Spell(197992),
  LandslideBuff         = Spell(202004),
  Hailstorm             = Spell(210853),
  Overcharge            = Spell(210727),
  CrashingStorm         = Spell(192246),
  FuryOfAir             = Spell(197211),
  FuryOfAirBuff         = Spell(197211),
  Sundering             = Spell(197214),
  Ascendance            = Spell(114051),
  AscendanceBuff        = Spell(114051),
  Boulderfist           = Spell(246035),
  EarthenSpike          = Spell(188089),
  EarthenSpikeDebuff    = Spell(188089),

  -- T21 2pc set bonus
  FotMBuff              = Spell(254308),

  -- Artifact
  DoomWinds             = Spell(204945),
  DoomWindsBuff         = Spell(204945),
  AlphaWolf             = Spell(198434),

  -- Utility
  WindShear             = Spell(57994),

  -- ToS Trinkets
  SpecterOfBetrayal     = Spell(246461),

  -- Misc
  PoolFocus             = Spell(9999000010),
}
local S = Spell.Shaman.Enhancement
local Everyone = AR.Commons.Everyone;

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Enhancement = {
  -- Legendaries
  SmolderingHeart           = Item(151819, {10}),
  AkainusAbsoluteJustice    = Item(137084, {9}),

  -- Trinkets
  SpecterOfBetrayal         = Item(151190, {13, 14}),

  -- Misc
  PoPP                      = Item(142117),
  Healthstone               = Item(5512),
}
local I = Item.Shaman.Enhancement

-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Shaman = AR.GUISettings.APL.Shaman,
}

--- APL Variables
-- actions+=/variable,name=hailstormCheck,value=((talent.hailstorm.enabled&!buff.frostbrand.up)|!talent.hailstorm.enabled)
local function hailstormCheck()
  return (S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff)) or not S.Hailstorm:IsAvailable()
end

-- actions+=/variable,name=furyCheck80,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>80))
local function furyCheck80()
  return not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 80)
end

-- actions+=/variable,name=furyCheck70,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>70))
local function furyCheck70()
  return not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 70)
end

-- actions+=/variable,name=furyCheck45,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>45))
local function furyCheck45()
  return not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 45)
end

-- actions+=/variable,name=furyCheck25,value=(!talent.fury_of_air.enabled|(talent.fury_of_air.enabled&maelstrom>25))
local function furyCheck25()
  return not S.FuryOfAir:IsAvailable() or (S.FuryOfAir:IsAvailable() and Player:Maelstrom() > 25)
end

-- actions+=/variable,name=OCPool70,value=(!talent.overcharge.enabled|(talent.overcharge.enabled&maelstrom>70))
local function OCPool70()
  return not S.Overcharge:IsAvailable() or (S.Overcharge:IsAvailable() and Player:Maelstrom() > 70)
end

-- actions+=/variable,name=OCPool60,value=(!talent.overcharge.enabled|(talent.overcharge.enabled&maelstrom>60))
local function OCPool60()
  return not S.Overcharge:IsAvailable() or (S.Overcharge:IsAvailable() and Player:Maelstrom() > 60)
end

-- actions+=/variable,name=heartEquipped,value=(equipped.151819)
local function heartEquipped()
  return I.SmolderingHeart:IsEquipped()
end

-- actions+=/variable,name=akainuEquipped,value=(equipped.137084)
local function akainuEquipped()
  return I.AkainusAbsoluteJustice:IsEquipped()
end

-- actions+=/variable,name=akainuAS,value=(variable.akainuEquipped&buff.hot_hand.react&!buff.frostbrand.up)
local function akainuAS()
  return akainuEquipped() and Player:Buff(S.HotHandBuff) and not Player:Buff(S.FrostbrandBuff)
end

-- actions+=/variable,name=LightningCrashNotUp,value=(!buff.lightning_crash.up&set_bonus.tier20_2pc)
local function LightningCrashNotUp()
  return (not Player:Buff(S.LightningCrashBuff)) and AC.Tier20_2Pc
end

-- actions+=/variable,name=alphaWolfCheck,value=((pet.frost_wolf.buff.alpha_wolf.remains<2&pet.fiery_wolf.buff.alpha_wolf.remains<2&pet.lightning_wolf.buff.alpha_wolf.remains<2)&feral_spirit.remains>4)
local function alphaWolfCheck()
  return S.AlphaWolf:ArtifactEnabled() and S.FeralSpirit:TimeSinceLastCast() <= 11 and (S.CrashLightning:TimeSinceLastCast() >= 6)
end

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(40);  -- Lightning Bolt
  AC.GetEnemies(30);  -- Purge / Wind Shear
  AC.GetEnemies(10);  -- ES / FB / FT / RB / WS /
  AC.GetEnemies(8);   -- FOA / CL / Sundering
  Everyone.AoEToggleEnemiesUpdate()

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener
    -- actions+=/call_action_list,name=opener
    if Everyone.TargetIsValid() then
      -- actions.opener=rockbiter,if=maelstrom<15&time<gcd
      if S.Rockbiter:IsCastable(10) and Player:Maelstrom() < 15 then
        if AR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
      end
    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Interrupts
    if S.WindShear:IsCastable(30) and Target:IsInterruptible() and Settings.General.InterruptEnabled then
      if AR.Cast(S.WindShear, Settings.Shaman.Commons.OffGCDasOffGCD.WindShear) then return "Cast WindShear" end
    end

    -- Potion of Prolonged Power
    if Settings.Shaman.Commons.ShowPoPP and Target:MaxHealth() >= 1000000000 and (I.PoPP:IsReady() and (Player:HasHeroism() or Target:TimeToDie() <= 80 or Target:HealthPercentage() < 35)) then
      if AR.CastSuggested(I.PoPP) then return "Use PoPP" end
    end

    -- Use healthstone if we have it and our health is low.
    if Settings.Shaman.Commons.HealthstoneEnabled and (I.Healthstone:IsReady() and Player:HealthPercentage() <= 50) then
      if AR.CastSuggested(I.Healthstone) then return "Use Healthstone" end
    end

    -- Heal when we have less than the set health threshold!
    if S.HealingSurge:IsReady() and Settings.Shaman.Commons.HealingSurgeEnabled and Player:HealthPercentage() <= Settings.Shaman.Commons.HealingSurgeHPThreshold then
      -- Instant casts using maelstrom only.
      if Player:Maelstrom() >= 20 then
        if AR.Cast(S.HealingSurge) then return "Cast HealingSurge" end
      end
    end

    -- ToS Trinkets
    if Settings.Shaman.Commons.OnUseTrinkets and I.SpecterOfBetrayal:IsEquipped() and Target:IsInRange("Melee") and S.SpecterOfBetrayal:TimeSinceLastCast() > 45 and not Player:IsMoving() then
      if AR.CastSuggested(I.SpecterOfBetrayal) then return "Use SpecterOfBetrayal" end
    end

    -- actions+=/call_action_list,name=asc,if=buff.ascendance.up
    if Player:Buff(S.AscendanceBuff) then
      -- actions.asc=earthen_spike
      if S.EarthenSpike:IsCastable(10) and Player:Maelstrom() >= S.EarthenSpike:Cost() then
        if AR.Cast(S.EarthenSpike) then return "Cast EarthenSpike" end
      end

      -- actions.asc+=/doom_winds,if=cooldown.strike.up
      if S.DoomWinds:IsCastable() and (S.WindStrike:CooldownRemainsP() > 0 or S.StormStrike:CooldownRemainsP() > 0) then
        if AR.Cast(S.DoomWinds, Settings.Shaman.Enhancement.OffGCDasOffGCD.DoomWinds) then return "Cast DoomWinds" end
      end

      -- actions.asc+=/windstrike
      if S.WindStrike:IsCastable(30) and Player:Maelstrom() >= S.EarthenSpike:Cost() then
        if AR.Cast(S.WindStrike) then return "Cast WindStrike" end
      end
    end

    -- actions+=/call_action_list,name=buffs
    -- actions.buffs=rockbiter,if=talent.landslide.enabled&!buff.landslide.up
    if S.Rockbiter:IsCastable(10) and (S.Landslide:IsAvailable() and not Player:Buff(S.LandslideBuff)) then
      if AR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.buffs+=/fury_of_air,if=!ticking&maelstrom>22
    if S.FuryOfAir:IsCastable(8, true) and Player:Maelstrom() >= S.FuryOfAir:Cost() + 9 and (not Player:Buff(S.FuryOfAirBuff) and Player:Maelstrom() > 22) then
      if AR.Cast(S.FuryOfAir) then return "Cast FuryOfAir" end
    end

    -- actions.buffs+=/crash_lightning,if=artifact.alpha_wolf.rank&prev_gcd.1.feral_spirit
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (S.AlphaWolf:ArtifactEnabled() and Player:PrevGCD(1, S.FeralSpirit)) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.buffs+=/flametongue,if=!buff.flametongue.up
    if S.Flametongue:IsCastable(10) and (not Player:Buff(S.FlametongueBuff)) then
      if AR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&!buff.frostbrand.up&variable.furyCheck45
    if S.Frostbrand:IsCastable(10) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and not Player:Buff(S.FrostbrandBuff) and furyCheck45()) then
      if AR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.buffs+=/flametongue,if=buff.flametongue.remains<6+gcd&cooldown.doom_winds.remains<gcd*2
    if S.Flametongue:IsCastable(10) and (Player:BuffRemainsP(S.FlametongueBuff) < 6 + Player:GCD() and S.DoomWinds:CooldownRemainsP() < Player:GCD() * 2) then
      if AR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.buffs+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<6+gcd&cooldown.doom_winds.remains<gcd*2
    if S.Frostbrand:IsCastable(10) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and Player:BuffRemainsP(S.FrostbrandBuff) < 6 + Player:GCD() and S.DoomWinds:CooldownRemainsP() < Player:GCD() * 2) then
      if AR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions+=/call_action_list,name=cds
    if AR.CDsON() then
      -- Racial
      -- actions.cds+=/berserking,if=buff.ascendance.up|(cooldown.doom_winds.up)|level<100
      if S.Berserking:IsCastable() and (Player:Buff(S.AscendanceBuff) or S.DoomWinds:CooldownRemainsP() > 0) then
        if AR.Cast(S.Berserking, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast Berserking" end
      end

      -- Racial
      -- actions.cds+=/blood_fury,if=buff.ascendance.up|(feral_spirit.remains>5)|level<100
      if S.BloodFury:IsCastable() and (Player:Buff(S.AscendanceBuff) or S.FeralSpirit:TimeSinceLastCast() <= 10) then
        if AR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
      end

      -- actions.cds+=/feral_spirit
      if S.FeralSpirit:IsCastable() then
        if AR.Cast(S.FeralSpirit, Settings.Shaman.Enhancement.GCDasOffGCD.FeralSpirit) then return "Cast FeralSpirit" end
      end

      -- actions.cds+=/doom_winds,if=cooldown.ascendance.remains>6|talent.boulderfist.enabled|debuff.earthen_spike.up
      if S.DoomWinds:IsCastable() and (S.Ascendance:CooldownRemainsP() > 6 or S.Boulderfist:IsAvailable() or Target:Debuff(S.EarthenSpikeDebuff)) then
        if AR.Cast(S.DoomWinds, Settings.Shaman.Enhancement.OffGCDasOffGCD.DoomWinds) then return "Cast DoomWinds" end
      end

      -- actions.cds+=/ascendance,if=(cooldown.strike.remains>0)&buff.ascendance.down
      if S.Ascendance:IsCastable() and ((S.WindStrike:CooldownRemainsP() > 0 or S.StormStrike:CooldownRemainsP() > 0) and not Player:Buff(S.AscendanceBuff)) then
        if AR.Cast(S.Ascendance, Settings.Shaman.Enhancement.OffGCDasOffGCD.Ascendance) then return "Cast Ascendance" end
      end
    end

    -- actions+=/call_action_list,name=core
    -- actions.core=earthen_spike,if=variable.furyCheck25
    if S.EarthenSpike:IsCastable(10) and (furyCheck25()) and Player:Maelstrom() >= S.EarthenSpike:Cost() then
      if AR.Cast(S.EarthenSpike) then return "Cast EarthenSpike" end
    end

    -- actions.core+=/crash_lightning,if=!buff.crash_lightning.up&active_enemies>=2
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (not Player:Buff(S.CrashLightningBuff) and Cache.EnemiesCount[8] >= 2) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.core+=/windsong
    if S.Windsong:IsCastable(10) then
      if AR.Cast(S.Windsong) then return "Cast Windsong" end
    end

    -- actions.core+=/crash_lightning,if=active_enemies>=8|(active_enemies>=6&talent.crashing_storm.enabled)
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[8] >= 8 or (Cache.EnemiesCount[8] >= 6 and S.CrashingStorm:IsAvailable())) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.core+=/windstrike
    if S.WindStrike:IsCastable(30) and Player:Maelstrom() >= S.EarthenSpike:Cost() then
      if AR.Cast(S.WindStrike) then return "Cast WindStrike" end
    end

    -- actions.core+=/stormstrike,if=buff.stormbringer.up&variable.furyCheck25
    if S.StormStrike:IsCastable("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and (Player:Buff(S.StormbringerBuff) and furyCheck25()) then
      if AR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.core+=/crash_lightning,if=active_enemies>=4|(active_enemies>=2&talent.crashing_storm.enabled)
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[8] >= 4 or (Cache.EnemiesCount[8] >= 2 and S.CrashingStorm:IsAvailable())) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

	-- actions.core+=/rockbiter,if=buff.force_of_the_mountain.up
    if S.Rockbiter:IsCastable(10) and (Player:Buff(S.FotMBuff)) then
      if AR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
	end

    -- actions.core+=/lightning_bolt,if=talent.overcharge.enabled&variable.furyCheck45&maelstrom>=40
    if S.LightningBolt:IsCastable(40) and (S.Overcharge:IsAvailable() and furyCheck45() and Player:Maelstrom() >= 40) then
      if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
    end

    -- actions.core+=/stormstrike,if=(!talent.overcharge.enabled&variable.furyCheck45)|(talent.overcharge.enabled&variable.furyCheck80)
    if S.StormStrike:IsCastable("Melee") and Player:Maelstrom() >= S.StormStrike:Cost() and ((not S.Overcharge:IsAvailable() and furyCheck45()) or (S.Overcharge:IsAvailable() and furyCheck80())) then
      if AR.Cast(S.StormStrike) then return "Cast StormStrike" end
    end

    -- actions.core+=/frostbrand,if=variable.akainuAS
    if S.Frostbrand:IsCastable(10) and Player:Maelstrom() >= S.Frostbrand:Cost() and (akainuAS()) then
      if AR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.core+=/lava_lash,if=buff.hot_hand.react&((variable.akainuEquipped&buff.frostbrand.up)|!variable.akainuEquipped)
    if S.LavaLash:IsCastable("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (Player:Buff(S.HotHandBuff) and ((akainuEquipped() and Player:Buff(S.FrostbrandBuff)) or not akainuEquipped())) then
      if AR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.core+=/sundering,if=active_enemies>=3
    if S.Sundering:IsCastable() and Player:Maelstrom() >= S.Sundering:Cost() and (Cache.EnemiesCount[8] >= 3) then
      if AR.Cast(S.Sundering) then return "Cast Sundering" end
    end

    -- actions.core+=/crash_lightning,if=active_enemies>=3|variable.LightningCrashNotUp|variable.alphaWolfCheck
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and (Cache.EnemiesCount[8] >= 3 or LightningCrashNotUp() or alphaWolfCheck()) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions+=/call_action_list,name=filler
    -- actions.filler=rockbiter,if=maelstrom<120
    if S.Rockbiter:IsCastable(10) and (Player:Maelstrom() < 120) then
      if AR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/flametongue,if=buff.flametongue.remains<4.8
    if S.Flametongue:IsCastable(10) and (Player:BuffRemainsP(S.FlametongueBuff) < 4.8) then
      if AR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    -- actions.filler+=/crash_lightning,if=(talent.crashing_storm.enabled|active_enemies>=2)&debuff.earthen_spike.up&maelstrom>=40&variable.OCPool60
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and ((S.CrashingStorm:IsAvailable() or Cache.EnemiesCount[8] >= 2) and Target:Debuff(S.EarthenSpikeDebuff) and Player:Maelstrom() >= 40 and OCPool60()) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/frostbrand,if=talent.hailstorm.enabled&buff.frostbrand.remains<4.8&maelstrom>40
    if S.Frostbrand:IsCastable(10) and Player:Maelstrom() >= S.Frostbrand:Cost() and (S.Hailstorm:IsAvailable() and Player:BuffRemainsP(S.FrostbrandBuff) < 4.8 and Player:Maelstrom() > 40) then
      if AR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.filler+=/frostbrand,if=variable.akainuEquipped&!buff.frostbrand.up&maelstrom>=75
    if S.Frostbrand:IsCastable(10) and Player:Maelstrom() >= S.Frostbrand:Cost() and (akainuEquipped() and not Player:Buff(S.FrostbrandBuff) and Player:Maelstrom() >= 75) then
      if AR.Cast(S.Frostbrand) then return "Cast Frostbrand" end
    end

    -- actions.filler+=/sundering
    if S.Sundering:IsCastable() and Player:Maelstrom() >= S.Sundering:Cost() then
      if AR.Cast(S.Sundering) then return "Cast Sundering" end
    end

    -- actions.filler+=/lava_lash,if=maelstrom>=50&variable.OCPool70&variable.furyCheck80
    if S.LavaLash:IsCastable("Melee") and Player:Maelstrom() >= S.LavaLash:Cost() and (Player:Maelstrom() >= 50 and OCPool70() and furyCheck80()) then
      if AR.Cast(S.LavaLash) then return "Cast LavaLash" end
    end

    -- actions.filler+=/rockbiter
    if S.Rockbiter:IsCastable(10) then
      if AR.Cast(S.Rockbiter) then return "Cast Rockbiter" end
    end

    -- actions.filler+=/crash_lightning,if=(maelstrom>=65|talent.crashing_storm.enabled|active_enemies>=2)&variable.OCPool60&variable.furyCheck45
    if S.CrashLightning:IsCastable("Melee", true) and Player:Maelstrom() >= S.CrashLightning:Cost() and ((Player:Maelstrom() >= 65 or S.CrashingStorm:IsAvailable() or Cache.EnemiesCount[8] >= 2) and OCPool60() and furyCheck45()) then
      if AR.Cast(S.CrashLightning) then return "Cast CrashLightning" end
    end

    -- actions.filler+=/flametongue
    if S.Flametongue:IsCastable(10) then
        if AR.Cast(S.Flametongue) then return "Cast Flametongue" end
    end

    if AR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

AR.SetAPL(263, APL)
