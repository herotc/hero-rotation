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

-- APL from Shaman_Elemental_T20M on 8/21/2017

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

  EarthShock            = Spell(8042),
  LavaBurst             = Spell(51505),
  FireElemental         = Spell(198067),
  EarthElemental        = Spell(198103),
  LightningBolt         = Spell(188196),
  LavaBeam              = Spell(114074),
  EarthQuake            = Spell(8042),
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

  -- Utility
  WindShear             = Spell(57994),

  -- Trinkets

  -- Item Buffs
  EOTGS                 = Spell(208723),

  -- Misc
  PoolFocus             = Spell(9999000010)
}
local S = Spell.Shaman.Elemental

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Elemental = {
  -- Legendaries
  SmolderingHeart           = Item(151819, {10}),
  TheDeceiversBloodPact     = Item(137035, {8})
}
local I = Item.Shaman.Elemental

-- GUI Settings
local Settings = {
  General = AR.GUISettings.General,
  Shaman = AR.GUISettings.APL.Shaman
}

-- APL Main
local function APL ()
  -- Unit Update
  AC.GetEnemies(40);  -- General casting range

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Opener
    if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
      if S.LavaBurst:IsCastable() then
        if not Player:Buff(S.ResonanceTotemBuff) then
          if AR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
        elseif Target:IsInRange(40) then
          if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
        end
      end
    end
    return
  end

  -- Interrupts
  if S.WindShear:IsCastable() and Target:IsInterruptible() and Settings.General.InterruptEnabled then
    if Target:IsInRange(30) then
      if AR.Cast(S.WindShear, Settings.Shaman.Commons.OffGCDasOffGCD.WindShear) then return "Cast WindShear" end
    end
  end

  -- In Combat
  if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() then
    -- actions+=/totem_mastery,if=buff.resonance_totem.remains<2
    if S.TotemMastery:IsCastable() and (not Player:Buff(S.ResonanceTotemBuff) or S.TotemMastery:TimeSinceLastCast() >= 118) then
      if AR.Cast(S.TotemMastery) then return "Cast TotemMastery" end
    end

    -- actions+=/fire_elemental
    -- actions+=/storm_elemental
    if S.FireElemental:IsCastable() and (S.EarthElemental:TimeSinceLastCast() > 60) then
      if AR.Cast(S.FireElemental) then return "Cast FireElemental" end
    end
    if S.EarthElemental:IsCastable() and (S.FireElemental:TimeSinceLastCast() > 60) then
      if AR.Cast(S.EarthElemental) then return "Cast EarthElemental" end
    end

    -- actions+=/elemental_mastery
    if S.ElementalMastery:IsCastable() then
      if AR.Cast(S.ElementalMastery) then return "Cast ElementalMastery" end
    end

    -- actions+=/use_item,name=gnawed_thumb_ring,if=equipped.gnawed_thumb_ring&(talent.ascendance.enabled&!buff.ascendance.up|!talent.ascendance.enabled)
    -- TODO

    -- Racial
    -- actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
    if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:Buff(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
      if AR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- Racial
    -- actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
    if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:Buff(S.AscendanceBuff)) then
      if AR.Cast(S.BloodFury, Settings.Shaman.Commons.OffGCDasOffGCD.Racials) then return "Cast BloodFury" end
    end

    -- actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if Cache.EnemiesCount[40] > 2 then
      -- actions.aoe=stormkeeper
      if S.Stormkeeper:IsCastable() then
        if AR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.aoe+=/ascendance
      if S.Ascendance:IsCastable() then
        if S.Ascendance:IsAvailable() and not Player:Buff(S.AscendanceBuff) then
          if AR.Cast(S.Ascendance) then return "Cast Ascendance" end
        end
      end

      -- actions.aoe+=/liquid_magma_totem
      if S.LiquidMagmaTotem:IsCastable() then
        if S.LiquidMagmaTotem:IsAvailable() then
          if AR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
        end
      end

      -- TODO: refreshable
      -- actions.aoe+=/flame_shock,if=spell_targets.chain_lightning<4&maelstrom>=20,target_if=refreshable
      if S.FlameShock:IsCastable() and (Cache.EnemiesCount[40] < 4 and Player:Maelstrom() >= 20) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.aoe+=/earthquake
      if S.EarthQuake:IsCastable() then
        if AR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
      end

      -- actions.aoe+=/lava_burst,if=dot.flame_shock.remains>cast_time&buff.lava_surge.up&!talent.lightning_rod.enabled&spell_targets.chain_lightning<4
      if S.LavaBurst:IsCastable() and (Target:DebuffRemains(S.FlameShockDebuff) > S.LavaBurst:CastTime() and Player:Buff(S.LavaSurgeBuff) and not S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 4) then
        if AR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- actions.aoe+=/elemental_blast,if=!talent.lightning_rod.enabled&spell_targets.chain_lightning<5|talent.lightning_rod.enabled&spell_targets.chain_lightning<4
      if S.ElementalBlast:IsCastable() and (not S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 5 or S.LightningRod:IsAvailable() and Cache.EnemiesCount[40] < 4) then
        if AR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.aoe+=/lava_beam
      if S.LavaBeam:IsCastable() then
        if AR.Cast(S.LavaBeam) then return "Cast LavaBeam" end
      end

      -- actions.aoe+=/chain_lightning,target_if=debuff.lightning_rod.down
      if S.ChainLightning:IsCastable() and not Target:Debuff(S.LightningRodDebuff) then
        if AR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.aoe+=/chain_lightning
      if S.ChainLightning:IsCastable() then
        if AR.Cast(S.ChainLightning) then return "Cast ChainLightning" end
      end

      -- actions.aoe+=/lava_burst,moving=1
      if S.LavaBurst:IsCastable() then
        if AR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- TODO: refreshable
      -- actions.aoe+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastable() then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end
    end

    -- actions+=/run_action_list,name=single_asc,if=talent.ascendance.enabled
    if S.Ascendance:IsAvailable() then
      -- actions.single_asc=ascendance,if=dot.flame_shock.remains>buff.ascendance.duration&(time>=60|buff.bloodlust.up)&cooldown.lava_burst.remains>0&!buff.stormkeeper.up
      if S.Ascendance:IsCastable() and (Target:DebuffRemains(S.FlameShockDebuff) > Player:BuffRemains(S.AscendanceBuff) and (AC.CombatTime() >= 60 or Player:Buff(S.BloodLustBuff)) and S.LavaBurst:CooldownRemains() > 0 and not Player:Buff(S.StormkeeperBuff)) then
        if AR.Cast(S.Ascendance) then return "Cast Ascendance" end
      end

      -- actions.single_asc+=/flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
      if S.FlameShock:IsCastable() and (not Target:DebuffRemains(S.FlameShockDebuff) <= Player:GCDRemains()) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/flame_shock,if=maelstrom>=20&remains<=buff.ascendance.duration&cooldown.ascendance.remains+buff.ascendance.duration<=duration
      if S.FlameShock:IsCastable() and (Player:Maelstrom() >= 20 and AC.CombatTime() <= Player:BuffRemains(S.AscendanceBuff) and S.Ascendance:CooldownRemains() + S.Ascendance:Duration() <= Target:DebuffRemains(S.FlameShockDebuff)) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/elemental_blast
      if S.ElementalBlast:IsCastable() then
        if AR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.single_asc+=/earthquake,if=buff.echoes_of_the_great_sundering.up&!buff.ascendance.up&maelstrom>=86
      if S.EarthQuake:IsCastable() and (Player:Buff(S.EOTGS) and not Player:Buff(S.AscendanceBuff) and Player:Maelstrom() >= 86) then
        if AR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
      end

      -- actions.single_asc+=/earth_shock,if=maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92
      if S.EarthShock:IsCastable() and (Player:Maelstrom() >= 117 or (not S.SwellingMaelstrom:IsAvailable() and Player:Maelstrom() >= 92)) then
        if AR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/stormkeeper,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.Stormkeeper:IsCastable() then
        if AR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.single_asc+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.LiquidMagmaTotem:IsCastable() then
        if AR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
      end

      -- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastable() and (Player:Buff(S.PowerOfTheMaelstromBuff) and Player:Buff(S.StormkeeperBuff) and Cache.EnemiesCount[40] < 3) then
        if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- TODO: cooldown_react
      -- actions.single_asc+=/lava_burst,if=dot.flame_shock.remains>cast_time&(cooldown_react|buff.ascendance.up)
      if S.LavaBurst:IsCastable() and (Target:DebuffRemains(S.FlameShockDebuff) > S.LavaBurst:CastTime() and (Player:Buff(S.AscendanceBuff))) then
        if AR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- TODO: refreshable
      -- actions.single_asc+=/flame_shock,if=maelstrom>=20&buff.elemental_focus.up,target_if=refreshable
      if S.FlameShock:IsCastable() and (Player:Maelstrom() >= 20 and Player:Buff(S.ElementalFocusBuff)) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/earth_shock,if=maelstrom>=111|!artifact.swelling_maelstrom.enabled&maelstrom>=86|equipped.smoldering_heart&equipped.the_deceivers_blood_pact&maelstrom>70&talent.aftershock.enabled
      if S.EarthShock:IsCastable() and (Player:Maelstrom() >= 111 or (not S.SwellingMaelstrom:IsAvailable() and Player:Maelstrom() >= 86) or (I.SmolderingHeart:IsEquipped() and I.TheDeceiversBloodPact:IsEquipped() and Player:Maelstrom() > 70 and S.Aftershock:IsAvailable())) then
        if AR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/totem_mastery,if=buff.resonance_totem.remains<10|(buff.resonance_totem.remains<(buff.ascendance.duration+cooldown.ascendance.remains)&cooldown.ascendance.remains<15)
      if S.TotemMastery:IsCastable() and (Player:BuffRemains(S.ResonanceTotemBuff) < 10 or (Player:BuffRemains(S.ResonanceTotemBuff) < (Player:BuffRemains(S.AscendanceBuff) + S.Ascendance:CooldownRemains()) and S.Ascendance:CooldownRemains() < 15)) then
        if AR.Cast(TotemMastery) then return "Cast TotemMastery" end
      end

      -- actions.single_asc+=/lava_beam,if=active_enemies>1&spell_targets.lava_beam>1
      if S.LavaBeam:IsCastable() and (AC.EnemiesCount[40] > 1) then
        if AR.Cast(S.LavaBeam) then return "Cast LavaBeam" end
      end

      -- actions.single_asc+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastable() and (Player:Buff(S.PowerOfTheMaelstromBuff) and AC.EnemiesCount[40] < 3) then
        if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/chain_lightning,if=active_enemies>1&spell_targets.chain_lightning>1
      if S.ChainLightning:IsCastable() and (AC.EnemiesCount[40] > 1) then
        if AR.Cast(S.ChainLightning) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/lightning_bolt
      if S.LightningBolt:IsCastable() then
        if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_asc+=/flame_shock,moving=1,target_if=refreshable
      if S.FlameShock:IsCastable() then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_asc+=/earth_shock,moving=1
      if S.EarthShock:IsCastable() then
        if AR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_asc+=/flame_shock,moving=1,if=movement.distance>6
      if S.FlameShock:IsCastable() then
        if AR.Cast(FlameShock) then return "Cast FlameShock" end
      end
    end

    -- actions+=/run_action_list,name=single_if,if=talent.icefury.enabled
    if S.Icefury:IsAvailable() then
      -- actions.single_if=flame_shock,if=!ticking|dot.flame_shock.remains<=gcd
      if S.FlameShock:IsCastable() and (not Target:Debuff(S.FlameShockDebuff) or Target:DebuffRemains(S.FlameShockDebuff) <= Player:GCD()) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end

      -- actions.single_if+=/earthquake,if=buff.echoes_of_the_great_sundering.up&maelstrom>=86
      if S.EarthQuake:IsCastable() and (Player:Buff(S.EOTGS) and Player:Maelstrom() >= 86) then
        if AR.Cast(S.EarthQuake) then return "Cast EarthQuake" end
      end

      -- actions.single_if+=/frost_shock,if=buff.icefury.up&maelstrom>=111&!buff.ascendance.up
      if S.FrostShock:IsCastable() and (Player:Buff(S.IcefuryBuff) and Player:Maelstrom() >= 111 and not Player:Buff(S.AscendanceBuff)) then
        if AR.Cast(S.FrostShock) then return "Cast FrostShock" end
      end

      -- actions.single_if+=/elemental_blast
      if S.ElementalBlast:IsCastable() then
        if AR.Cast(S.ElementalBlast) then return "Cast ElementalBlast" end
      end

      -- actions.single_if+=/earth_shock,if=maelstrom>=117|!artifact.swelling_maelstrom.enabled&maelstrom>=92
      if S.EarthShock:IsCastable() and (Player:Maelstrom() >= 117 or (S.SwellingMaelstrom:IsAvailable() and Player:Maelstrom() >= 92)) then
        if AR.Cast(S.EarthShock) then return "Cast EarthShock" end
      end

      -- actions.single_if+=/stormkeeper,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.Stormkeeper:IsCastable() and (AC.EnemiesCount[40] < 3) then
        if AR.Cast(S.Stormkeeper) then return "Cast Stormkeeper" end
      end

      -- actions.single_if+=/icefury,if=(raid_event.movement.in<5|maelstrom<=101&artifact.swelling_maelstrom.enabled|!artifact.swelling_maelstrom.enabled&maelstrom<=76)&!buff.ascendance.up
      if S.Icefury:IsCastable() and (Player:Maelstrom() <= 101 and S.SwellingMaelstrom:IsAvailable() or (not S.SwellingMaelstrom:IsAvailable() and Player:Maelstrom() <= 76) and not Player:Buff(S.AscendanceBuff)) then
        if AR.Cast(S.Icefury) then return "Cast Icefury" end
      end

      -- actions.single_if+=/liquid_magma_totem,if=raid_event.adds.count<3|raid_event.adds.in>50
      if S.LiquidMagmaTotem:IsCastable() and (AC.EnemiesCount[40] < 3) then
        if AR.Cast(S.LiquidMagmaTotem) then return "Cast LiquidMagmaTotem" end
      end

      -- actions.single_if+=/lightning_bolt,if=buff.power_of_the_maelstrom.up&buff.stormkeeper.up&spell_targets.chain_lightning<3
      if S.LightningBolt:IsCastable() and (Player:Buff(S.PowerOfTheMaelstromBuff) and Player:Buff(S.StormkeeperBuff) and AC.EnemiesCount[40] < 3) then
        if AR.Cast(S.LightningBolt) then return "Cast LightningBolt" end
      end

      -- actions.single_if+=/lava_burst,if=dot.flame_shock.remains>cast_time&cooldown_react
      if S.LavaBurst:IsCastable() and (Target:DebuffRemains(S.FlameShockDebuff)) then
        if AR.Cast(S.LavaBurst) then return "Cast LavaBurst" end
      end

      -- TODO: Spell_Haste
      -- actions.single_if+=/frost_shock,if=buff.icefury.up&((maelstrom>=20&raid_event.movement.in>buff.icefury.remains)|buff.icefury.remains<(1.5*spell_haste*buff.icefury.stack+1))
      if S.FrostShock:IsCastable() and (Player:Buff(S.IcefuryBuff) and ((Player:Maelstrom() >= 20) or Player:BuffRemains(S.IcefuryBuff) < (1.5 * Player:BuffStack(S.IcefuryBuff)))) then
        if AR.Cast(S.FrostShock) then return "Cast FrostShock" end
      end
    end

    if AR.Cast(S.PoolFocus) then return "Cast PoolFocus" end
  end
end

AR.SetAPL(262, APL)
