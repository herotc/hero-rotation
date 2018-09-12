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
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),

  -- Abilities
  FlameShock            = Spell(188389),
  FlameShockDebuff      = Spell(188389),
  BloodLust             = Spell(2825),
  BloodLustBuff         = Spell(2825),

  TotemMastery          = Spell(210643),
  EmberTotemBuff        = Spell(210658),
  TailwindTotemBuff     = Spell(210659),
  ResonanceTotemBuff    = Spell(202192),
  StormTotemBuff        = Spell(210652),

  HealingSurge          = Spell(188070),

  EarthShock            = Spell(8042),
  LavaBurst             = Spell(51505),
  FireElemental         = Spell(198067),
  EarthElemental        = Spell(198103),
  LightningBolt         = Spell(188196),
  LavaBeam              = Spell(114074),
  EarthQuake            = Spell(61882),
  LavaSurgeBuff         = Spell(77762),
  ChainLightning        = Spell(188443),
  ElementalFocusBuff    = Spell(16246),
  FrostShock            = Spell(196840),

  -- Talents
  ElementalMastery      = Spell(16166),
  ElementalMasteryBuff  = Spell(16166),
  Ascendance            = Spell(114050),
  AscendanceBuff        = Spell(114050),
  LightningRod          = Spell(210689),
  LightningRodDebuff    = Spell(197209),
  LiquidMagmaTotem      = Spell(192222),
  ElementalBlast        = Spell(117014),
  Aftershock            = Spell(210707),
  Icefury               = Spell(210714),
  IcefuryBuff           = Spell(210714),

  -- Artifact
  Stormkeeper           = Spell(205495),
  StormkeeperBuff       = Spell(205495),
  SwellingMaelstrom     = Spell(238105),
  PowerOfTheMaelstrom   = Spell(191861),
  PowerOfTheMaelstromBuff = Spell(191861),

  -- Tier bonus
  EarthenStrengthBuff   = Spell(252141),

  -- Utility
  WindShear             = Spell(57994),

  -- Tomb Trinkets
  SpecterOfBetrayal     = Spell(246461),

  -- Item Buffs
  EOTGS                 = Spell(208723),

  -- Misc
  PoolFocus             = Spell(9999000010)
}
local S = Spell.Shaman.Elemental
local Everyone = HR.Commons.Everyone;

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Elemental = {
  -- Legendaries
  SmolderingHeart           = Item(151819, {10}),
  TheDeceiversBloodPact     = Item(137035, {8}),

  -- Trinkets
  SpecterOfBetrayal         = Item(151190, {13, 14}),

  -- Rings
  GnawedThumbRing           = Item(134526, {11}, {12}),

  -- Consumables
  BPoA                      = Item(163223),  -- Battle Potion of Agility
  CHP                       = Item(152494),  -- Coastal Healing Potion
  BSAR                      = Item(160053),  -- Battle-Scarred Augment Rune
  Healthstone               = Item(5512),
}
local I = Item.Shaman.Elemental

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Shaman = HR.GUISettings.APL.Shaman
}

local function MaelstromP()
  local maelstrom = Player:Maelstrom()
  if not Player:IsCasting() then
    return maelstrom
  end
  local overloadChance = Player:MasteryPct()/100
  local resonance = 0
  if S.TotemMastery:IsCastableP() then
    resonance = Player:CastRemains()
  end
  local factor = 1 + 0.75 * overloadChance
  if Player:IsCasting(S.LightningBolt) then
    return maelstrom + 8 * factor + resonance
  end
  if Player:IsCasting(S.Icefury) then
    return maelstrom + 24 * factor + resonance
  end
  if Player:IsCasting(S.ChainLightning) then
    local enemiesHit = min(Cache.EnemiesCount[40], 3)
    return maelstrom + 6 * enemiesHit * factor + resonance
  end
  if Player:IsCasting(S.LavaBurst) then
    return maelstrom + 12 * factor + resonance
  end
  return maelstrom + resonance
end

local function MaelstromMinP()
  local maelstrom = Player:Maelstrom()
  if not Player:IsCasting() then
    return maelstrom
  end
  local resonance = 0
  if S.TotemMastery:IsCastableP() then
    resonance = Player:CastRemains()
  end
  if Player:IsCasting(S.LightningBolt) then
    return maelstrom + 8 + resonance
  end
  if Player:IsCasting(S.Icefury) then
    return maelstrom + 24 + resonance
  end
  if Player:IsCasting(S.ChainLightning) then
    local enemiesHit = min(Cache.EnemiesCount[40], 3)
    return maelstrom + 6 * enemiesHit + resonance
  end
  if Player:IsCasting(S.LavaBurst) then
    return maelstrom + 12 + resonance
  end
  return maelstrom + resonance
end

-- APL Main
local function APL ()
  -- Unit Update
  HL.GetEnemies(40)  -- General casting range
  Everyone.AoEToggleEnemiesUpdate()

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener
    if Everyone.TargetIsValid() then
      if S.TotemMastery:IsCastableP() and (not Player:Buff(S.ResonanceTotemBuff) and S.TotemMastery:TimeSinceLastCast() >= 5) then
        if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
      elseif S.LightningBolt:IsCastableP(40) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end
    end
    return
  end

  -- Interrupts
  if S.WindShear:IsCastableP(30) and Target:IsInterruptible() and Settings.General.InterruptEnabled then
    if HR.Cast(S.WindShear, Settings.Shaman.Commons.OffGCDasOffGCD.WindShear) then return "Cast WindShear" end
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Battle Potion of Agility
    if Settings.Shaman.Commons.ShowBPoA and I.BPoA:IsReady() and Target:MaxHealth() >= (Settings.Shaman.Commons.ConsumableMinHPThreshHold * 1000) and (Player:Buff(S.AscendanceBuff) or Target:TimeToDie() <= 60) then
      if HR.CastSuggested(I.BPoA) then return "Use BPoA" end
    end

    -- Battle-Scarred Augment Rune
    if Settings.Shaman.Commons.ShowBSAR and I.BSAR:IsReady() and Target:MaxHealth() >= (Settings.Shaman.Commons.ConsumableMinHPThreshHold * 1000) and (Player:Buff(S.AscendanceBuff) or Target:TimeToDie() <= 60) then
      if HR.CastSuggested(I.BSAR) then return "Use BSAR" end
    end

    -- Use healthstone or health potion if we have it and our health is low.
    if Settings.Shaman.Commons.ShowHSHP and (Player:HealthPercentage() <= Settings.Shaman.Commons.HealingHPThreshold) then
      if I.Healthstone:IsReady() then
        if HR.CastSuggested(I.Healthstone) then return "Use Healthstone" end
      elseif I.CHP:IsReady() then
        if HR.CastSuggested(I.CHP) then return "Use CHP" end
      end
    end

    -- Heal when we have less than the set health threshold (instant casts only)!
    if Settings.Shaman.Commons.HealingSurgeEnabled and Player:HealthPercentage() <= Settings.Shaman.Commons.HealingSurgeHPThreshold then
      if S.HealingSurge:IsCastableP() and (Player:Maelstrom() >= 20 and Player:Mana() >= S.HealingSurge:Cost()) then
        if HR.Cast(S.HealingSurge) then return "Cast HealingSurge" end
      end
    end

    -- On use trinkets.
    if Settings.Shaman.Commons.OnUseTrinkets then
	  if I.SpecterOfBetrayal:IsEquipped() and Target:IsInRange("Melee") and S.SpecterOfBetrayal:TimeSinceLastCast() > 45 and not Player:IsMoving() then
	    if HR.CastSuggested(I.SpecterOfBetrayal) then return "Use SpecterOfBetrayal" end
	  end
    end

    -- actions+=/totem_mastery,if=buff.resonance_totem.remains<2
    -- TODO: Handle this as per the APL.
    if S.TotemMastery:IsCastableP() and ((not Player:Buff(S.ResonanceTotemBuff) and S.TotemMastery:TimeSinceLastCast() >= 5) or S.TotemMastery:TimeSinceLastCast() >= 120 - 3) then
      if HR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
    end

    -- actions+=/fire_elemental
    -- actions+=/storm_elemental
    if S.FireElemental:IsCastableP() and (S.EarthElemental:TimeSinceLastCast() >= 60) then
      if HR.Cast(S.FireElemental) then return "Cast FireElemental" end
    end
    if S.EarthElemental:IsCastableP() and (S.FireElemental:TimeSinceLastCast() >= 60) then
      if HR.Cast(S.EarthElemental) then return "Cast EarthElemental" end
    end

    -- actions+=/elemental_mastery
    if S.ElementalMastery:IsCastableP() then
      if HR.Cast(S.ElementalMastery) then return "Cast ElementalMastery" end
    end

    -- actions+=/use_item,name=gnawed_thumb_ring,if=equipped.gnawed_thumb_ring&(talent.ascendance.enabled&!buff.ascendance.up|!talent.ascendance.enabled)
    if I.GnawedThumbRing:IsEquipped() and I.GnawedThumbRing:IsReady() and (S.Ascendance:IsAvailable() and not Player:BuffP(S.AscendanceBuff) or not S.Ascendance:IsAvailable()) then
      if HR.Cast(I.GnawedThumbRing) then return "Use GnawedThumbRing" end
    end

    -- Racial
    -- actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
    if S.BloodFury:IsCastableP() and (not S.Ascendance:IsAvailable() or Player:BuffP(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
      if HR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- Racial
    -- actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
    if S.Berserking:IsCastableP() and (not S.Ascendance:IsAvailable() or Player:BuffP(S.AscendanceBuff)) then
      if HR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if Cache.EnemiesCount[40] > 2 then
      -- actions.aoe=stormkeeper
      if S.Stormkeeper:IsCastableP() then
        if HR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.aoe+=/ascendance
      if S.Ascendance:IsCastableP() then
        if S.Ascendance:IsAvailable() and not Player:Buff(S.AscendanceBuff) then
          if HR.Cast(S.Ascendance) then return "Cast Ascendance" end
        end
      end

      -- actions.aoe+=/liquid_magma_totem
      if S.LiquidMagmaTotem:IsCastableP() then
        if S.LiquidMagmaTotem:IsAvailable() then
          if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
        end
      end

      -- actions.aoe+=/flame_shock,if=spell_targets.chain_lightning<4&maelstrom>=20,target_if=refreshable
      if S.FlameShock:IsCastableP() and (Cache.EnemiesCount[40] < 4 and MaelstromMinP() >= 20) then
        if Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.aoe+=/earthquake
      if S.EarthQuake:IsCastableP() then
        if MaelstromMinP() >= S.EarthQuake:Cost() then
          if HR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
        end
      end

      -- actions.aoe+=/lava_burst,if=dot.flame_shock.remains>cast_time&buff.lava_surge.up&!talent.lightning_rod.enabled&spell_targets.chain_lightning<4
      if S.LavaBurst:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) > S.LavaBurst:CastTime() and Player:BuffP(S.LavaSurgeBuff) and not S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 4) then
        if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- actions.aoe+=/elemental_blast,if=!talent.lightning_rod.enabled&spell_targets.chain_lightning<5|talent.lightning_rod.enabled&spell_targets.chain_lightning<4
      if S.ElementalBlast:IsCastableP() and ((not S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 5) or (S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 4)) then
        if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.aoe+=/lava_beam
      if S.LavaBeam:IsCastableP() then
        if HR.Cast(S.LavaBeam) then return "Cast LavaBeam" end
      end

      -- actions.aoe+=/chain_lightning,target_if=debuff.lightning_rod.down
      if S.ChainLightning:IsCastableP() and not Target:DebuffP(S.LightningRodDebuff) then
        if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.aoe+=/chain_lightning
      if S.ChainLightning:IsCastableP() then
        if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.aoe+=/lava_burst,moving=1
      if S.LavaBurst:IsCastableP() and Player:IsMoving() then
        if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- actions.aoe+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end
    end

    -- actions+=/run_action_list,name=single_asc,if=talent.ascendance.enabled
    if S.Ascendance:IsAvailable() then
      -- actions.single_asc=ascendance,if=dot.flame_shock.remains>buff.ascendance.duration&(time>=60|buff.bloodlust.up)&cooldown.lava_burst.remains>0&!buff.stormkeeper.up
      if S.Ascendance:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) > Player:BuffRemainsP(S.AscendanceBuff) and (HL.CombatTime() >= 60 or Player:BuffP(S.BloodLustBuff)) and S.LavaBurst:CooldownRemainsP() > 0 and not Player:BuffP(S.StormkeeperBuff)) then
        if HR.Cast(S.Ascendance) then return "Cast Ascendance" end
      end

      -- actions.single_asc+=/flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
      if S.FlameShock:IsCastableP() and (not Target:DebuffP(S.FlameShockDebuff) or (Target:DebuffRemainsP(S.FlameShockDebuff) <= Player:GCDRemains())) then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/flame_shock,if=maelstrom>=20&remains<=buff.ascendance.duration&cooldown.ascendance.remains+buff.ascendance.duration<=duration
      if S.FlameShock:IsCastableP() and (MaelstromMinP() >= 20 and Target:DebuffRemainsP(S.FlameShockDebuff) <= Player:BuffRemainsP(S.AscendanceBuff) and S.Ascendance:CooldownRemainsP() + S.Ascendance:BaseDuration() <= S.FlameShockDebuff:BaseDuration()) then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/earthquake,if=buff.echoes_of_the_great_sundering.up&!buff.ascendance.up
      if S.EarthQuake:IsCastableP() and (Player:BuffP(S.EOTGS) and not Player:BuffP(S.AscendanceBuff)) then
        if MaelstromMinP() >= S.EarthQuake:Cost() then
          if HR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
        end
      end

      -- actions.single_asc+=/elemental_blast
      if S.ElementalBlast:IsCastableP() then
        if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.single_asc+=/earth_shock,if=maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 117 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 92)) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/stormkeeper,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.Stormkeeper:IsCastableP() and (Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.single_asc+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.LiquidMagmaTotem:IsCastableP() and (Cache.EnemiesCount[40] < 3)  then
        if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
      end

      -- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Player:BuffP(S.StormkeeperBuff) and Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/lava_burst,if=dot.flame_shock.remains>cast_time&(cooldown_react|buff.ascendance.up)
      if S.LavaBurst:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) > S.LavaBurst:CastTime()) then
        if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- actions.single_asc+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
      if S.FlameShock:IsCastableP() and (MaelstromMinP() >= 20 and Player:BuffP(S.ElementalFocusBuff)) then
        if Target:DebuffRemains(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_asc+=/earth_shock,if=maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.smoldering_heart&equipped.the_deceivers_blood_pact&maelstrom>70&talent.aftershock.enabled
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 111 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 86) or (I.SmolderingHeart:IsEquipped() and I.TheDeceiversBloodPact:IsEquipped() and MaelstromP() > 70 and S.Aftershock:IsAvailable())) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1
      if S.LavaBeam:IsCastableP() and (Cache.EnemiesCount[40] > 1) then
        if HR.Cast(S.LavaBeam) then return "Cast LavaBeam" end
      end

      -- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
      if S.ChainLightning:IsCastableP() and (Cache.EnemiesCount[40] > 1) then
        if HR.Cast(S.ChainLightning) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/lightning_bolt
      if S.LightningBolt:IsCastableP() then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_asc+=/earth_shock,moving=1
      if S.EarthShock:IsCastableP() and Player:IsMoving() then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/flame_shock,moving=1,if=movement.distance>6
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end
    end

    -- actions+=/run_action_list,name=single_if,if=talent.icefury.enabled
    if S.Icefury:IsAvailable() then
      -- actions.single_if=flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
      if S.FlameShock:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) <= Player:GCDRemains()) then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_if+=/earthquake,if=buff.echoes_of_the_great_sundering.up&!buff.ascendance.up
      if S.EarthQuake:IsCastableP() and (Player:BuffP(S.EOTGS) and not Player:BuffP(S.AscendanceBuff)) then
        if HR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
      end

      -- actions.single_if+=/elemental_blast
      if S.ElementalBlast:IsCastableP() then
        if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.single_if+=/earth_shock,if=maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 117 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 92)) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_if+=/stormkeeper,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.Stormkeeper:IsCastableP() and (Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.single_if+=/icefury,if=(raid_event.movement.in<5|maelstrom<=101&artifact.swelling_maelstrom.enabled|!artifact.swelling_maelstrom.enabled&maelstrom<=76)&!buff.ascendance.up
      if S.Icefury:IsCastableP() and (((MaelstromP() <= 101 and S.SwellingMaelstrom:IsAvailable()) or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() <= 76)) and not Player:BuffP(S.AscendanceBuff)) then
        if HR.Cast(S.Icefury) then return "Cast Icefury" end
      end

      -- actions.single_if+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.LiquidMagmaTotem:IsCastableP() and (Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
      end

      -- actions.single_if+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Player:BuffP(S.StormkeeperBuff) and Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_if+=/lava_burst,if=dot.flame_shock.remains>cast_time&cooldown_react
      if S.LavaBurst:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) > S.FlameShock:CastTime()) then
        if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- TODO: spell_haste
      -- actions.single_if+=/frost_shock,if=buff.icefury.up&((maelstrom>=20&raid_event.movement.in>buff.icefury.remains)|buff.icefury.remains<(1.5*spell_haste*buff.icefury.stack+1))
      if S.FrostShock:IsCastableP() and (Player:BuffP(S.IcefuryBuff) and ((MaelstromMinP() >= 20) or Player:BuffRemainsP(S.IcefuryBuff) < (1.5 * Player:BuffStackP(S.IcefuryBuff) + 1))) then
        if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
      end

      -- actions.single_if+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
      if S.FlameShock:IsCastableP() and (MaelstromMinP() >= 20 and Player:BuffP(S.ElementalFocusBuff)) then
        if Target:DebuffRemains(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_if+=/frost_shock,moving=1,if=buff.icefury.up
      if S.FrostShock:IsCastableP() and (Player:IsMoving() and Player:BuffP(S.IcefuryBuff)) then
        if HR.Cast(S.FrostShock) then return "Cast FrostShock" end
      end

      -- actions.single_if+=/earth_shock,if=maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.smoldering_heart&equipped.the_deceivers_blood_pact&maelstrom>70&talent.aftershock.enabled&buff.earthen_strength.up
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 111 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 86) or (I.SmolderingHeart:IsEquipped() and I.TheDeceiversBloodPact:IsEquipped() and MaelstromP() > 70 and S.Aftershock:IsAvailable() and Player:BuffP(S.EarthenStrengthBuff))) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_if+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_if+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
      if S.ChainLightning:IsCastableP() and (Cache.EnemiesCount[40] > 1) then
        if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.single_if+=/lightning_bolt
      if S.LightningBolt:IsCastableP() then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_if+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_if+=/earth_shock,moving=1
      if S.EarthShock:IsCastableP() and Player:IsMoving() then
        if MaelstromMinP() >= 10 then
          if HR.Cast(S.EarthShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_if+=/flame_shock,moving=1,if=movement.distance>6
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end
    end

    -- actions+=/run_action_list,name=single_lr,if=talent.lightning_rod.enabled
    if S.LightningRod:IsAvailable() then
      -- actions.single_lr=flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
      if S.FlameShock:IsCastableP() and (not Target:DebuffP(S.FlameShockDebuff) and Target:DebuffRemainsP(S.FlameShockDebuff) <= Player:GCDRemains()) then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_lr+=/elemental_blast
      if S.ElementalBlast:IsCastableP() then
        if HR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.single_lr+=/earth_shock,if=maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 117 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 92)) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_lr+=/stormkeeper,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.Stormkeeper:IsCastableP() and (Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.single_lr+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.LiquidMagmaTotem:IsCastableP() and (Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
      end

      -- actions.single_lr+=/lava_burst,if=dot.flame_shock.remains>cast_time&cooldown_react
      if S.LavaBeam:IsCastableP() and (Target:DebuffRemainsP(S.FlameShockDebuff) > S.LavaBurst:CastTime()) then
        if HR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- actions.single_lr+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
      if S.FlameShock:IsCastableP() and (MaelstromMinP() >= 20 and Player:BuffP(S.ElementalFocusBuff)) then
        if Target:DebuffRemains(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_lr+=/earth_shock,if=maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.smoldering_heart&equipped.the_deceivers_blood_pact&maelstrom>70&talent.aftershock.enabled
      if S.EarthShock:IsCastableP() and (MaelstromP() >= 111 or (not S.SwellingMaelstrom:IsAvailable() and MaelstromP() >= 86) or (I.SmolderingHeart:IsEquipped() and I.TheDeceiversBloodPact:IsEquipped() and MaelstromP() > 70 and S.Aftershock:IsAvailable())) then
        if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_lr+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3,target_if=debuff.lightning_rod.down
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Cache.EnemiesCount[40] < 3 and not Target:DebuffP(LightningRodDebuff)) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_lr+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastableP() and (Player:BuffP(S.PowerOfTheMaelstromBuff) and Cache.EnemiesCount[40] < 3) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_lr+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1,target_if=debuff.lightning_rod.down
      if S.ChainLightning:IsCastableP() and (Cache.EnemiesCount[40] > 1 and not Target:DebuffP(S.LightningRodDebuff)) then
        if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.single_lr+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
      if S.ChainLightning:IsCastableP() and (Cache.EnemiesCount[40] > 1) then
        if HR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.single_lr+=/lightning_bolt,target_if=debuff.lightning_rod.down
      if S.LightningBolt:IsCastableP() and (not Target:DebuffP(S.LightningRodDebuff)) then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_lr+=/lightning_bolt
      if S.LightningBolt:IsCastableP() then
        if HR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_lr+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastableP() and (Player:IsMoving()) then
        if Target:DebuffRemainsP(S.FlameShockDebuff) <= 2.5 then
          if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
        end
      end

      -- actions.single_lr+=/earth_shock,moving=1
      if S.EarthShock:IsCastableP() and Player:IsMoving() then
        if MaelstromMinP() >= 10 then
          if HR.Cast(S.EarthShock) then return "Cast EarthShock" end
        end
      end

      -- actions.single_lr+=/flame_shock,moving=1,if=movement.distance>6
      if S.FlameShock:IsCastableP() and Player:IsMoving() then
        if HR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end
    end
    if HR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

HR.SetAPL(262, APL)
