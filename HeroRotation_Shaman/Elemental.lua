--- Localize Vars
-- Addon
local addonName, addonTable = ...;

-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;

-- HeroRotation
local HR = HeroRotation;

-- APL from T21_Shaman_Elemental on 2017-12-06

-- APL Local Vars
-- Spells
if not Spell.Shaman then Spell.Shaman = {}; end
Spell.Shaman.Elemental = {
  -- Racials
  Berserking              = Spell(26297),
  BloodFury               = Spell(20572),

  -- Abilities
  FlameShock              = Spell(188389),
  FlameShockDebuff        = Spell(188389),
  BloodLust               = Spell(2825),
  BloodLustBuff           = Spell(2825),

  TotemMastery            = Spell(210643),
  EmberTotemBuff          = Spell(210658),
  TailwindTotemBuff       = Spell(210659),
  ResonanceTotemBuff      = Spell(202192),
  StormTotemBuff          = Spell(210652),

  HealingSurge            = Spell(188070),

  EarthShock              = Spell(8042),
  LavaBurst               = Spell(51505),
  FireElemental           = Spell(198067),
  EarthElemental          = Spell(198103),
  LightningBolt           = Spell(188196),
  LavaBeam                = Spell(114074),
  EarthQuake              = Spell(61882),
  LavaSurgeBuff           = Spell(77762),
  ChainLightning          = Spell(188443),
  ElementalFocusBuff      = Spell(16246),
  FrostShock              = Spell(196840),

  -- Talents
  EarthenRage             = Spell(170374),
  EchoOfTheElements       = Spell(108283),
  ElementalBlast          = Spell(117014),
  Aftershock              = Spell(273221),
  CallTheThunder          = Spell(260897),
  TotemMastery            = Spell(210643),
  TailWindTotem           = Spell(210659),
  MasterOfTheElements     = Spell(16166),
  MasterOfTheElementsBuff = Spell(260734),
  StormElemental          = Spell(192249),
  WindGustBuff            = Spell(263806),
  LiquidMagmaTotem        = Spell(192222),
  SurgeOfPower            = Spell(262303),
  SurgeOfPowerBuff        = Spell(285514),
  PrimalElementalist      = Spell(117013),
  Icefury                 = Spell(210714),
  IcefuryBuff             = Spell(210714),
  UnlimitedPower          = Spell(260895),
  Stormkeeper             = Spell(191634),
  StormkeeperBuff         = Spell(191634),
  Ascendance              = Spell(114050),
  AscendanceBuff          = Spell(114050),

  -- Azerite
  NaturalHarmony          = Spell(278697),

  -- Tier bonus
  EarthenStrengthBuff     = Spell(252141),

  -- Utility
  WindShear               = Spell(57994),

  -- Tomb Trinkets
  SpecterOfBetrayal       = Spell(246461),

  -- Item Buffs
  EOTGS                   = Spell(208723),

  -- Misc
  PoolFocus               = Spell(9999000010)
}
local S = Spell.Shaman.Elemental
local Everyone = HR.Commons.Everyone;

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Elemental = {
  -- Legendaries
  SmolderingHeart       = Item(151819, {10}),
  TheDeceiversBloodPact = Item(137035, {8}),

  -- Trinkets
  SpecterOfBetrayal     = Item(151190, {13, 14}),

  -- Rings
  GnawedThumbRing       = Item(134526, {11}, {12}),

  -- Consumables
  BPoA                  = Item(163223),  -- Battle Potion of Agility
  CHP                   = Item(152494),  -- Coastal Healing Potion
  BSAR                  = Item(160053),  -- Battle-Scarred Augment Rune
  Healthstone           = Item(5512),
}
local I = Item.Shaman.Elemental

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Shaman = HR.GUISettings.APL.Shaman,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

local function FutureMaelstromPower()
  local MaelstromPower = Player:Maelstrom()
  local overloadChance = Player:MasteryPct()/100
  local factor = 1 + 0.75 * overloadChance
  local resonance = 0

  if (Player:AffectingCombat()) then
    if S.TotemMastery:IsCastableP() then
      resonance = Player:CastRemains()
    end
    if not Player:IsCasting() then
      return MaelstromPower
    else
      if Player:IsCasting(S.LightningBolt) then
        return MaelstromPower + 8 + resonance
      elseif Player:IsCasting(S.LavaBurst) then
        return MaelstromPower + 10 + resonance
      elseif Player:IsCasting(S.ChainLightning) then
        local enemiesHit = min(Cache.EnemiesCount[40], 3)
        return MaelstromPower + 4 * enemiesHit * factor + resonance
      elseif Player:IsCasting(S.Icefury) then
        return MaelstromPower + 25 * factor + resonance
      else
        return MaelstromPower
      end
    end
  end
end

local spell_targets

local flame_shock_refreshable

-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(40)  -- General casting range
  Everyone.AoEToggleEnemiesUpdate()

  spell_targets = Cache.EnemiesCount[40]
  flame_shock_refreshable = (Target:DebuffRemains(S.FlameShockDebuff) <= 6.5)
  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener

      --# Executed before combat begins. Accepts non-harmful actions only.
    --actions.precombat=flask
    --actions.precombat+=/food
    --actions.precombat+=/augmentation
    --# Snapshot raid buffed stats before combat begins and pre-potting is done.
    --actions.precombat+=/snapshot_stats
    --actions.precombat+=/totem_mastery
    if Everyone.TargetIsValid() then
      if S.TotemMastery:IsCastableP() and (not Player:Buff(S.ResonanceTotemBuff) and S.TotemMastery:TimeSinceLastCast() >= 5) then
        if HR.Cast(S.TotemMastery) then return "Cast Totem Mastery" end
      end
      --actions.precombat+=/earth_elemental,if=!talent.primal_elementalist.enabled
      if (not S.PrimalElementalist:IsAvailable() and S.EarthElemental:IsReady()) then
        if HR.Cast(S.EarthElemental, Settings.Elemental.GCDasOffGCD.EarthElemental) then return "Cast Earth Elemental" end
      end
      --# Use Stormkeeper precombat unless some adds will spawn soon.
      --actions.precombat+=/stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)
      if (not S.Stormkeeper:IsAvailable() and S.Stormkeeper:IsReady()) then
        if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "Cast Stormkeeper" end
      end
      --actions.precombat+=/fire_elemental,if=!talent.storm_elemental.enabled
      if (not S.StormElemental:IsAvailable() and S.FireElemental:IsReady()) then
        if HR.Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "Cast Fire Elemental" end
      end
      --actions.precombat+=/storm_elemental,if=talent.storm_elemental.enabled
      if (S.StormElemental:IsAvailable()) then
        if (S.StormElemental:IsReady()) then
          if HR.Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "Cast Storm Elemental" end
        end
      end
      --actions.precombat+=/potion
      --actions.precombat+=/elemental_blast,if=talent.elemental_blast.enabled
      if (S.ElementalBlast:IsAvailable() and S.ElementalBlast:IsReady()) then
        if HR.Cast(S.ElementalBlast) then return "Cast Elemental Blast" end
      end
      --actions.precombat+=/lava_burst,if=!talent.elemental_blast.enabled
      if (not S.ElementalBlast:IsAvailable() and S.LavaBurst:IsReady() and not Player:IsCasting(S.LavaBurst)) then
        if HR.Cast(S.LavaBurst) then return "Cast Lava Burst" end
      end
    end

  end

  -- Interrupts
  if S.WindShear:IsCastableP(30) and Target:IsInterruptible() and Settings.General.InterruptEnabled then
  if HR.Cast(S.WindShear, Settings.Shaman.Commons.OffGCDasOffGCD.WindShear) then return "Cast WindShear" end
  end

  -- In Combat
  if Everyone.TargetIsValid() then
  --
  --# Executed every time the actor is available.
  --# Cast Bloodlust manually if the Azerite Trait Ancestral Resonance is present.
  --actions=bloodlust,if=azerite.ancestral_resonance.enabled
  --# In-combat potion is preferentially linked to your Elemental, unless combat will end shortly
  --actions+=/potion,if=expected_combat_length-time<30|cooldown.fire_elemental.remains>120|cooldown.storm_elemental.remains>120
  --# Interrupt of casts.
  --actions+=/wind_shear
  --actions+=/totem_mastery,if=talent.totem_mastery.enabled&buff.resonance_totem.remains<2
  if S.TotemMastery:IsCastableP() and ((not Player:Buff(S.ResonanceTotemBuff) and S.TotemMastery:TimeSinceLastCast() >= 5) or S.TotemMastery:TimeSinceLastCast() >= 120 - 3) then
    if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
  end
  --actions+=/fire_elemental,if=!talent.storm_elemental.enabled
  if (not S.StormElemental:IsAvailable()) then
    if (S.FireElemental:IsReady()) then
      if HR.Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "Cast Fire Elemental" end
    end
  end
  --actions+=/storm_elemental,if=talent.storm_elemental.enabled&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if (S.StormElemental:IsAvailable() and (not S.Icefury:IsAvailable() or not Player:Buff(S.IcefuryBuff) and not S.Icefury:IsCastable())) then
    if (S.StormElemental:IsReady()) then
      if HR.Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "Cast Storm Elemental" end
    end
  end
  --actions+=/earth_elemental,if=!talent.primal_elementalist.enabled|talent.primal_elementalist.enabled&(cooldown.fire_elemental.remains<120&!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120&talent.storm_elemental.enabled)
  if ((not S.PrimalElementalist:IsAvailable() or S.PrimalElementalist:IsAvailable() and (S.FireElemental:CooldownRemains() <120 and not S.StormElemental:IsAvailable() or S.StormElemental:CooldownRemains() <120 and S.StormElemental:IsAvailable()))) then
    if (S.EarthElemental:IsReady()) then
      if HR.Cast(S.EarthElemental, Settings.Elemental.GCDasOffGCD.EarthElemental) then return "Cast Earth Elemental" end
    end
  end
  --actions+=/use_items
  --actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
  if (not S.Ascendance:IsAvailable() or Player:Buff(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50 and S.BloodFury:IsAvailable()) then
    if (S.BloodFury:IsReady()) then
      if HR.Cast(S.BloodFury) then return "Cast Blood Fury" end
    end
  end
  --actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
  if (not S.Ascendance:IsAvailable() or Player:Buff(S.AscendanceBuff) and S.Berserking:IsAvailable()) then
    if (S.Berserking:IsReady()) then
      if HR.Cast(S.Berserking) then return "Cast Berserking" end
    end
  end
  --actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
  --actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
  --actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
  if (spell_targets > 2) then
    aoe()
  end
  --actions+=/run_action_list,name=single_target
  single_target()
  end
end

function aoe()
  --# Multi target action priority list
  --actions.aoe=stormkeeper,if=talent.stormkeeper.enabled
  if (S.Stormkeeper:IsAvailable()) then
    if (S.Stormkeeper:IsReady()) then
      if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "Cast Stormkeeper" end
    end
  end
  --actions.aoe+=/ascendance,if=talent.ascendance.enabled&(talent.storm_elemental.enabled&cooldown.storm_elemental.remains<120&cooldown.storm_elemental.remains>15|!talent.storm_elemental.enabled)
  if (S.Ascendance:IsAvailable() and (S.StormElemental:IsAvailable() and S.StormElemental:CooldownRemains() < 120 and S.StormElemental:CooldownRemains() >15 or not S.StormElemental:IsAvailable())) then
    if (S.Ascendance:IsReady()) then
      if HR.Cast(S.Ascendance) then return "Cast Ascendance" end
    end
  end
  --actions.aoe+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if (S.LiquidMagmaTotem:IsAvailable()) then
    if (S.LiquidMagmaTotem:IsReady()) then
      if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
    end
  end
  --# Spread Flame Shock in <=4 target fights, but not during SE uptime, unless you're fighting 3 targets and have less than 14 Wind Gust BuffStack.
  --actions.aoe+=/flame_shock,target_if=refreshable&spell_targets.chain_lightning<5&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120|spell_targets.chain_lightning=3&buff.wind_gust.stack<14)
  if (S.FlameShock:IsCastableP() and spell_targets < 5 and (not S.StormElemental:IsAvailable() or S.StormElemental:CooldownRemains() < 120 or spell_targets == 3 and Player:BuffStack(S.WindGustBuff) < 14)) then
    if (Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 and S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --# Try to game Earthquake with Master of the Elements buff when fighting 3 targets. Don't overcap Maelstrom!
  --actions.aoe+=/earthquake,if=!talent.master_of_the_elements.enabled|buff.stormkeeper.up|maelstrom>=(100-4*spell_targets.chain_lightning)|buff.master_of_the_elements.up|spell_targets.chain_lightning>3
  if (not S.MasterOfTheElements:IsAvailable() or Player:Buff(S.StormkeeperBuff) or FutureMaelstromPower() >= (100-4* min(Cache.EnemiesCount[40], 3)) or Player:Buff(S.MasterOfTheElementsBuff) or spell_targets > 3) then
    if (FutureMaelstromPower() >= 60) then
      if HR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
    end
  end
  --# Only cast Lava Burst on three targets if it is an instant and Storm Elemental is NOT active.
  --actions.aoe+=/lava_burst,if=(buff.lava_surge.up|buff.ascendance.up)&spell_targets.chain_lightning<4&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120)
  if ((Player:Buff(S.LavaSurgeBuff) or Player:Buff(S.Ascendance)) and spell_targets <4 and (not S.StormElemental:IsAvailable() or S.StormElemental:CooldownRemains() < 120)) then
    if (S.LavaBurst:IsReady()) then
      if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
    end
  end
  --# Use Elemental Blast against up to 3 targets as long as Storm Elemental is not active.
  --actions.aoe+=/elemental_blast,if=talent.elemental_blast.enabled&spell_targets.chain_lightning<4&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120)
  if (S.ElementalBlast:IsAvailable() and spell_targets <4 and (not S.StormElemental:IsAvailable() or S.StormElemental:CooldownRemains() < 120)) then
    if (S.ElementalBlast:IsReady()) then
      if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
    end
  end
  --actions.aoe+=/lava_beam,if=talent.ascendance.enabled
  if (Player:Buff(S.AscendanceBuff)) then
    if HR.Cast(S.LavaBeam) then return "Cast LavaBeam" end
  end
  --actions.aoe+=/chain_lightning
  if (spell_targets > 2) then
    if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
  end
  --actions.aoe+=/lava_burst,moving=1,if=talent.ascendance.enabled
  if (Player:IsMoving() and Player:Buff(S.AscendanceBuff)) then
    if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
  end
  --actions.aoe+=/flame_shock,moving=1,target_if=refreshable
  if (Player:IsMoving()) then
    if (S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --actions.aoe+=/frost_shock,moving=1
  if (Player:IsMoving()) then
    if (S.FrostShock:IsReady()) then
      if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
    end
  end
end


function single_target()
  --# Single Target Action Priority List
  --# Ensure FS is active unless you have 14 or more BuffStack of Wind Gust from Storm Elemental. (Edge case: upcoming Ascendance but active SE; don't )
  --actions.single_target=flame_shock,if=(!ticking|talent.storm_elemental.enabled&cooldown.storm_elemental.remains<2*gcd|dot.flame_shock.remains<=gcd|talent.ascendance.enabled&dot.flame_shock.remains<(cooldown.ascendance.remains+buff.ascendance.duration)&cooldown.ascendance.remains<4&(!talent.storm_elemental.enabled|talent.storm_elemental.enabled&cooldown.storm_elemental.remains<120))&buff.wind_gust.stack<14
  if (not Target:Debuff(S.FlameShockDebuff) or S.StormElemental:IsAvailable() and S.StormElemental:CooldownRemains() <2*Player:GCD() or Target:DebuffRemains(S.FlameShock) <= Player:GCD() or S.Ascendance:IsAvailable() and Target:DebuffRemains(S.FlameShockDebuff) < (S.Ascendance:CooldownRemains() + S.AscendanceBuff:MaxDuration()) and S.Ascendance:CooldownRemains() <4 and (not S.StormElemental:IsAvailable() or S.StormElemental:IsAvailable() and S.StormElemental:CooldownRemains() <120) and Player:BuffStack(S.WindGustBuff) <14) then
    if (S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --# Use Ascendance after you've spent all Lava Burst charges and only if neither Storm Elemental nor Icefury are currently active.
  --actions.single_target+=/ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&cooldown.lava_burst.remains>0&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains>120)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if (S.Ascendance:IsAvailable() and (Target:TimeToDie() >= 60 or Player:Buff(S.BloodLustBuff)) and S.LavaBurst:CooldownRemains() >0 ) then
    if (S.Ascendance:IsReady()) then
      if HR.Cast(S.Ascendance) then return "Cast Ascendance" end
    end
  end
  --# Don't use Elemental Blast if you could cast a Master of the Elements empowered Earth Shock instead. Don't cast Elemental Blast during Storm Elemental unless you have 3x Natural Harmony in which case you stop using Elemental Blast once you reach 14 BuffStack of Wind Gust.
  --actions.single_target+=/elemental_blast,if=talent.elemental_blast.enabled&(talent.master_of_the_elements.enabled&buff.master_of_the_elements.up&maelstrom<60|!talent.master_of_the_elements.enabled)&(!(cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled)|azerite.natural_harmony.rank=3&buff.wind_gust.stack<14)
  if (S.ElementalBlast:IsAvailable() and (S.MasterOfTheElements:IsAvailable() and Player:Buff(S.MasterOfTheElementsBuff) and FutureMaelstromPower() <60 or not S.MasterOfTheElements:IsAvailable()) and (not S.StormElemental:CooldownRemains()>120 and S.StormElemental:IsAvailable() or S.NaturalHarmony:AzeriteRank() == 3 and Player:Buff(S.WindGustBuff) < 14)) then
    if (S.ElementalBlast:IsReady()) then
      if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
    end
  end
  --# Keep SK for large or soon add waves. Unless you have Surge of Power, in which case you want to double buff Lightning Bolt by pooling Maelstrom beforehand. Example sequence: 100MS, ES, SK, LB, LvB, ES, LB
  --actions.single_target+=/stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)&(!talent.surge_of_power.enabled|buff.surge_of_power.up|maelstrom>=44)
  if (S.Stormkeeper:IsAvailable() and (not S.SurgeOfPower:IsAvailable() or Player:Buff(S.SurgeOfPowerBuff) or FutureMaelstromPower() >= 44)) then
    if (S.Stormkeeper:IsReady()) then
      if HR.Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "Cast Stormkeeper" end
    end
  end
  --actions.single_target+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)
  if (S.LiquidMagmaTotem:IsAvailable()) then
    if (S.LiquidMagmaTotem:IsReady()) then
      if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
    end
  end
  --# Combine Stormkeeper with Master of the Elements or Surge of Power.
  --actions.single_target+=/lightning_bolt,if=buff.stormkeeper.up&spell_targets.chain_lightning<2&(buff.master_of_the_elements.up&!talent.surge_of_power.enabled|buff.surge_of_power.up)
  if (Player:Buff(S.StormkeeperBuff) and spell_targets <2 and (Player:Buff(S.MasterOfTheElementsBuff) and not S.SurgeOfPower:IsAvailable() or Player:Buff(S.SurgeOfPowerBuff))) then
    if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
  end
  --# There might come an update for this line with some SoP logic.
  --actions.single_target+=/earthquake,if=active_enemies>1&spell_targets.chain_lightning>1&(!talent.surge_of_power.enabled|!dot.flame_shock.refreshable|cooldown.storm_elemental.remains>120)&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up|maelstrom>=92)
  if (spell_targets >1 and (not S.SurgeOfPower:IsAvailable() or S.StormElemental:CooldownRemains() >120) and (not S.MasterOfTheElements:IsAvailable() or Player:Buff(S.MasterOfTheElementsBuff) or FutureMaelstromPower() >=92)) then
    if (FutureMaelstromPower() >=60) then
      if HR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
    end
  end
  --# Boy...what a condition. With Master of the Elements pool Maelstrom up to 8 Maelstrom below the cap to ensure it's used with Earth Shock. Without Master of the Elements, use Earth Shock either if Stormkeeper is up, Maelstrom is 10 Maelstrom below the cap or less, or either Storm Elemental isn't talented or it's not active and your last Storm Elemental of the fight will have only a partial duration.
  --actions.single_target+=/earth_shock,if=!buff.surge_of_power.up&talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up|maelstrom>=92+30*talent.call_the_thunder.enabled|buff.stormkeeper.up&active_enemies<2)|!talent.master_of_the_elements.enabled&(buff.stormkeeper.up|maelstrom>=90+30*talent.call_the_thunder.enabled|!(cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled)&expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)>=30*(1+(azerite.echo_of_the_elementals.rank>=2)))
  if (not Player:Buff(S.SurgeOfPowerBuff) and S.MasterOfTheElements:IsAvailable() and (Player:Buff(S.MasterOfTheElementsBuff) or (FutureMaelstromPower()>= 122 and S.CallTheThunder:IsAvailable()) or Player:Buff(S.StormkeeperBuff) and spell_targets < 2) or not S.MasterOfTheElements:IsAvailable() and (Player:Buff(S.StormkeeperBuff) or (FutureMaelstromPower()>= 120 and S.CallTheThunder:IsAvailable()) or not (S.StormElemental:CooldownRemains() >120 and S.StormElemental:IsAvailable()))) then
    if (FutureMaelstromPower() >=60) then
      if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
    end
  end
  --# Use Earth Shock if Surge of Power is talented, but neither it nor a DPS Elemental is active at the moment, and Lava Burst is ready or will be within the next GCD.
  --actions.single_target+=/earth_shock,if=talent.surge_of_power.enabled&!buff.surge_of_power.up&cooldown.lava_burst.remains<=gcd&(!talent.storm_elemental.enabled&!(cooldown.fire_elemental.remains>120)|talent.storm_elemental.enabled&!(cooldown.storm_elemental.remains>120))
  if (S.SurgeOfPower:IsAvailable() and not Player:Buff(S.SurgeOfPowerBuff) and S.LavaBurst:CooldownRemains() <= Player:GCD() and (not S.StormElemental:IsAvailable() and not (S.FireElemental:CooldownRemains() > 120) or S.StormElemental:IsAvailable() and not (S.StormElemental:CooldownRemains() >120))) then
    if (FutureMaelstromPower() >=60) then
      if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
    end
  end
  --# Cast Lightning Bolts during Storm Elemental duration.
  --actions.single_target+=/lightning_bolt,if=cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled
  if (S.StormElemental:CooldownRemains() >120 and S.StormElemental:IsAvailable()) then
    if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
  end
  --# Use Frost Shock with Icefury and Master of the Elements.
  --actions.single_target+=/frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
  if (S.Icefury:IsAvailable() and S.MasterOfTheElements:IsAvailable() and Player:Buff(S.IcefuryBuff) and Player:Buff(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
  end
  --actions.single_target+=/lava_burst,if=buff.ascendance.up
  if (Player:Buff(S.AscendanceBuff)) then
    if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
  end
  --# Utilize Surge of Power to spread Flame Shock if multiple enemies are present.
  --actions.single_target+=/flame_shock,target_if=refreshable&active_enemies>1&buff.surge_of_power.up
  if (spell_targets>1 and Player:Buff(S.StormkeeperBuff)) then
    if (S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --# Use Lava Burst with Surge of Power if the last potential usage of a DPS Elemental hasn't a full duration OR if you could get another usage of the DPS Elemental if the remaining fight was 16% longer.
  --actions.single_target+=/lava_burst,if=talent.storm_elemental.enabled&cooldown_react&buff.surge_of_power.up&(expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)<30*(1+(azerite.echo_of_the_elementals.rank>=2))|(1.16*(expected_combat_length-time)-cooldown.storm_elemental.remains-150*floor((1.16*(expected_combat_length-time)-cooldown.storm_elemental.remains)%150))<(expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)))
  if (S.StormElemental:IsAvailable() and Player:Buff(S.SurgeOfPowerBuff)) then
    if (S.LavaBurst:IsReady()) then
      if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
    end
  end
  --# Use Lava Burst with Surge of Power if the last potential usage of a DPS Elemental hasn't a full duration OR if you could get another usage of the DPS Elemental if the remaining fight was 16% longer.
  --actions.single_target+=/lava_burst,if=!talent.storm_elemental.enabled&cooldown_react&buff.surge_of_power.up&(expected_combat_length-time-cooldown.fire_elemental.remains-150*floor((expected_combat_length-time-cooldown.fire_elemental.remains)%150)<30*(1+(azerite.echo_of_the_elementals.rank>=2))|(1.16*(expected_combat_length-time)-cooldown.fire_elemental.remains-150*floor((1.16*(expected_combat_length-time)-cooldown.fire_elemental.remains)%150))<(expected_combat_length-time-cooldown.fire_elemental.remains-150*floor((expected_combat_length-time-cooldown.fire_elemental.remains)%150)))
  if (not S.StormElemental:IsAvailable() and Player:Buff(S.SurgeOfPowerBuff)) then
    if (S.LavaBurst:IsReady()) then
      if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
    end
  end
  --actions.single_target+=/lightning_bolt,if=buff.surge_of_power.up
  if (Player:Buff(S.SurgeOfPowerBuff)) then
    if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
  end
  --actions.single_target+=/lava_burst,if=cooldown_react
  if (S.LavaBurst:IsReady() and not Player:IsCasting(S.LavaBurst)) then
    if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
  end
  if (S.LavaBurst:IsReady() and Player:IsCasting(S.LavaBurst) and Player:Buff(S.LavaSurgeBuff)) then
    if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
  end
  --# Don't accidentally use Surge of Power with Flame Shock during single target.
  --actions.single_target+=/flame_shock,target_if=refreshable&!buff.surge_of_power.up
  if (not Player:Buff(S.SurgeOfPowerBuff)) then
    if (S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --actions.single_target+=/totem_mastery,if=talent.totem_mastery.enabled&(buff.resonance_totem.remains<6|(buff.resonance_totem.remains<(buff.ascendance.duration+cooldown.ascendance.remains)&cooldown.ascendance.remains<15))
  if (S.TotemMastery:IsAvailable() and (S.TotemMastery:TimeSinceLastCast() >= 120 - 6)) then
    if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
  end
  --# Slightly game Icefury buff to hopefully buff some with Master of the Elements.
  --actions.single_target+=/frost_shock,if=talent.icefury.enabled&buff.icefury.up&(buff.icefury.remains<gcd*4*buff.icefury.stack|buff.stormkeeper.up|!talent.master_of_the_elements.enabled)
  if (S.Icefury:IsAvailable() and Player:Buff(S.IcefuryBuff) and (Player:BuffRemains(S.IcefuryBuff) < Player:GCD()*4*Player:BuffStack(S.IcefuryBuff) or Player:Buff(S.StormkeeperBuff) or not S.MasterOfTheElements:IsAvailable())) then
    if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
  end
  --actions.single_target+=/icefury,if=talent.icefury.enabled
  if (S.Icefury:IsAvailable() and S.Icefury:IsReady()) then
    if HR.Cast(S.Icefury) then return "Cast Icefury" end
  end
  --actions.single_target+=/lightning_bolt
  if (spell_targets <= 2) then
    if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
  end
  --actions.single_target+=/flame_shock,moving=1,target_if=refreshable
  if (Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock)) then
    if (S.FlameShock:IsReady() and flame_shock_refreshable) then
      if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
    end
  end
  --actions.single_target+=/flame_shock,moving=1,if=movement.distance>6
  --# Frost Shock is our movement filler.
  --actions.single_target+=/frost_shock,moving=1
  if  (Player:IsMoving()) then
    if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
  end
end

HR.SetAPL(262, APL)

--Updated 27.12.2018

--# This default action priority list is automatically created based on your character.
--# It is a attempt to provide you with a action list that is both simple and practicable,
--# while resulting in a meaningful and good simulation. It may not result in the absolutely highest possible dps.
--# Feel free to edit, adapt and improve it to your own needs.
--# SimulationCraft is always looking for updates and improvements to the default action lists.
--
--# Executed before combat begins. Accepts non-harmful actions only.
--actions.precombat=flask
--actions.precombat+=/food
--actions.precombat+=/augmentation
--# Snapshot raid buffed stats before combat begins and pre-potting is done.
--actions.precombat+=/snapshot_stats
--actions.precombat+=/totem_mastery
--actions.precombat+=/earth_elemental,if=!talent.primal_elementalist.enabled
--# Use Stormkeeper precombat unless some adds will spawn soon.
--actions.precombat+=/stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)
--actions.precombat+=/fire_elemental,if=!talent.storm_elemental.enabled
--actions.precombat+=/storm_elemental,if=talent.storm_elemental.enabled
--actions.precombat+=/potion
--actions.precombat+=/elemental_blast,if=talent.elemental_blast.enabled
--actions.precombat+=/lava_burst,if=!talent.elemental_blast.enabled
--
--# Executed every time the actor is available.
--# Cast Bloodlust manually if the Azerite Trait Ancestral Resonance is present.
--actions=bloodlust,if=azerite.ancestral_resonance.enabled
--# In-combat potion is preferentially linked to your Elemental, unless combat will end shortly
--actions+=/potion,if=expected_combat_length-time<30|cooldown.fire_elemental.remains>120|cooldown.storm_elemental.remains>120
--# Interrupt of casts.
--actions+=/wind_shear
--actions+=/totem_mastery,if=talent.totem_mastery.enabled&buff.resonance_totem.remains<2
--actions+=/fire_elemental,if=!talent.storm_elemental.enabled
--actions+=/storm_elemental,if=talent.storm_elemental.enabled&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
--actions+=/earth_elemental,if=!talent.primal_elementalist.enabled|talent.primal_elementalist.enabled&(cooldown.fire_elemental.remains<120&!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120&talent.storm_elemental.enabled)
--actions+=/use_items
--actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
--actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
--actions+=/run_action_list,name=single_target
--
--# Multi target action priority list
--actions.aoe=stormkeeper,if=talent.stormkeeper.enabled
--actions.aoe+=/ascendance,if=talent.ascendance.enabled&(talent.storm_elemental.enabled&cooldown.storm_elemental.remains<120&cooldown.storm_elemental.remains>15|!talent.storm_elemental.enabled)
--actions.aoe+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
--# Spread Flame Shock in <=4 target fights, but not during SE uptime, unless you're fighting 3 targets and have less than 14 Wind Gust stacks.
--actions.aoe+=/flame_shock,target_if=refreshable&spell_targets.chain_lightning<5&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120|spell_targets.chain_lightning=3&buff.wind_gust.stack<14)
--# Try to game Earthquake with Master of the Elements buff when fighting 3 targets. Don't overcap Maelstrom!
--actions.aoe+=/earthquake,if=!talent.master_of_the_elements.enabled|buff.stormkeeper.up|maelstrom>=(100-4*spell_targets.chain_lightning)|buff.master_of_the_elements.up|spell_targets.chain_lightning>3
--# Only cast Lava Burst on three targets if it is an instant and Storm Elemental is NOT active.
--actions.aoe+=/lava_burst,if=(buff.lava_surge.up|buff.ascendance.up)&spell_targets.chain_lightning<4&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120)
--# Use Elemental Blast against up to 3 targets as long as Storm Elemental is not active.
--actions.aoe+=/elemental_blast,if=talent.elemental_blast.enabled&spell_targets.chain_lightning<4&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains<120)
--actions.aoe+=/lava_beam,if=talent.ascendance.enabled
--actions.aoe+=/chain_lightning
--actions.aoe+=/lava_burst,moving=1,if=talent.ascendance.enabled
--actions.aoe+=/flame_shock,moving=1,target_if=refreshable
--actions.aoe+=/frost_shock,moving=1
--
--# Single Target Action Priority List
--# Ensure FS is active unless you have 14 or more stacks of Wind Gust from Storm Elemental. (Edge case: upcoming Asc but active SE; don't )
--actions.single_target=flame_shock,if=(!ticking|talent.storm_elemental.enabled&cooldown.storm_elemental.remains<2*gcd|dot.flame_shock.remains<=gcd|talent.ascendance.enabled&dot.flame_shock.remains<(cooldown.ascendance.remains+buff.ascendance.duration)&cooldown.ascendance.remains<4&(!talent.storm_elemental.enabled|talent.storm_elemental.enabled&cooldown.storm_elemental.remains<120))&buff.wind_gust.stack<14
--# Use Ascendance after you've spent all Lava Burst charges and only if neither Storm Elemental nor Icefury are currently active.
--actions.single_target+=/ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&cooldown.lava_burst.remains>0&(!talent.storm_elemental.enabled|cooldown.storm_elemental.remains>120)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
--# Don't use Elemental Blast if you could cast a Master of the Elements empowered Earth Shock instead. Don't cast Elemental Blast during Storm Elemental unless you have 3x Natural Harmony in which case you stop using Elemental Blast once you reach 14 stacks of Wind Gust.
--actions.single_target+=/elemental_blast,if=talent.elemental_blast.enabled&(talent.master_of_the_elements.enabled&buff.master_of_the_elements.up&maelstrom<60|!talent.master_of_the_elements.enabled)&(!(cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled)|azerite.natural_harmony.rank=3&buff.wind_gust.stack<14)
--# Keep SK for large or soon add waves. Unless you have Surge of Power, in which case you want to double buff Lightning Bolt by pooling Maelstrom beforehand. Example sequence: 100MS, ES, SK, LB, LvB, ES, LB
--actions.single_target+=/stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)&(!talent.surge_of_power.enabled|buff.surge_of_power.up|maelstrom>=44)
--actions.single_target+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)
--# Combine Stormkeeper with Master of the Elements or Surge of Power.
--actions.single_target+=/lightning_bolt,if=buff.stormkeeper.up&spell_targets.chain_lightning<2&(buff.master_of_the_elements.up&!talent.surge_of_power.enabled|buff.surge_of_power.up)
--# There might come an update for this line with some SoP logic.
--actions.single_target+=/earthquake,if=active_enemies>1&spell_targets.chain_lightning>1&(!talent.surge_of_power.enabled|!dot.flame_shock.refreshable|cooldown.storm_elemental.remains>120)&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up|maelstrom>=92)
--# Boy...what a condition. With Master of the Elements pool Maelstrom up to 8 Maelstrom below the cap to ensure it's used with Earth Shock. Without Master of the Elements, use Earth Shock either if Stormkeeper is up, Maelstrom is 10 Maelstrom below the cap or less, or either Storm Elemental isn't talented or it's not active and your last Storm Elemental of the fight will have only a partial duration.
--actions.single_target+=/earth_shock,if=!buff.surge_of_power.up&talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up|maelstrom>=92+30*talent.call_the_thunder.enabled|buff.stormkeeper.up&active_enemies<2)|!talent.master_of_the_elements.enabled&(buff.stormkeeper.up|maelstrom>=90+30*talent.call_the_thunder.enabled|!(cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled)&expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)>=30*(1+(azerite.echo_of_the_elementals.rank>=2)))
--# Use Earth Shock if Surge of Power is talented, but neither it nor a DPS Elemental is active at the moment, and Lava Burst is ready or will be within the next GCD.
--actions.single_target+=/earth_shock,if=talent.surge_of_power.enabled&!buff.surge_of_power.up&cooldown.lava_burst.remains<=gcd&(!talent.storm_elemental.enabled&!(cooldown.fire_elemental.remains>120)|talent.storm_elemental.enabled&!(cooldown.storm_elemental.remains>120))
--# Cast Lightning Bolts during Storm Elemental duration.
--actions.single_target+=/lightning_bolt,if=cooldown.storm_elemental.remains>120&talent.storm_elemental.enabled
--# Use Frost Shock with Icefury and Master of the Elements.
--actions.single_target+=/frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
--actions.single_target+=/lava_burst,if=buff.ascendance.up
--# Utilize Surge of Power to spread Flame Shock if multiple enemies are present.
--actions.single_target+=/flame_shock,target_if=refreshable&active_enemies>1&buff.surge_of_power.up
--# Use Lava Burst with Surge of Power if the last potential usage of a DPS Elemental hasn't a full duration OR if you could get another usage of the DPS Elemental if the remaining fight was 16% longer.
--actions.single_target+=/lava_burst,if=talent.storm_elemental.enabled&cooldown_react&buff.surge_of_power.up&(expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)<30*(1+(azerite.echo_of_the_elementals.rank>=2))|(1.16*(expected_combat_length-time)-cooldown.storm_elemental.remains-150*floor((1.16*(expected_combat_length-time)-cooldown.storm_elemental.remains)%150))<(expected_combat_length-time-cooldown.storm_elemental.remains-150*floor((expected_combat_length-time-cooldown.storm_elemental.remains)%150)))
--# Use Lava Burst with Surge of Power if the last potential usage of a DPS Elemental hasn't a full duration OR if you could get another usage of the DPS Elemental if the remaining fight was 16% longer.
--actions.single_target+=/lava_burst,if=!talent.storm_elemental.enabled&cooldown_react&buff.surge_of_power.up&(expected_combat_length-time-cooldown.fire_elemental.remains-150*floor((expected_combat_length-time-cooldown.fire_elemental.remains)%150)<30*(1+(azerite.echo_of_the_elementals.rank>=2))|(1.16*(expected_combat_length-time)-cooldown.fire_elemental.remains-150*floor((1.16*(expected_combat_length-time)-cooldown.fire_elemental.remains)%150))<(expected_combat_length-time-cooldown.fire_elemental.remains-150*floor((expected_combat_length-time-cooldown.fire_elemental.remains)%150)))
--actions.single_target+=/lightning_bolt,if=buff.surge_of_power.up
--actions.single_target+=/lava_burst,if=cooldown_react
--# Don't accidentally use Surge of Power with Flame Shock during single target.
--actions.single_target+=/flame_shock,target_if=refreshable&!buff.surge_of_power.up
--actions.single_target+=/totem_mastery,if=talent.totem_mastery.enabled&(buff.resonance_totem.remains<6|(buff.resonance_totem.remains<(buff.ascendance.duration+cooldown.ascendance.remains)&cooldown.ascendance.remains<15))
--# Slightly game Icefury buff to hopefully buff some with Master of the Elements.
--actions.single_target+=/frost_shock,if=talent.icefury.enabled&buff.icefury.up&(buff.icefury.remains<gcd*4*buff.icefury.stack|buff.stormkeeper.up|!talent.master_of_the_elements.enabled)
--actions.single_target+=/icefury,if=talent.icefury.enabled
--actions.single_target+=/lightning_bolt
--actions.single_target+=/flame_shock,moving=1,target_if=refreshable
--actions.single_target+=/flame_shock,moving=1,if=movement.distance>6
--# Frost Shock is our movement filler.
--actions.single_target+=/frost_shock,moving=1
