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

-- APL from Shaman_Elemental_T20M on 7/17/2017

-- APL Local Vars
-- Spells
if not Spell.Shaman then Spell.Shaman = {}; end
Spell.Shaman.Elemental = {
  -- Racials
  Berserking            = Spell(26297),
  BloodFury             = Spell(20572),

  -- Abilities
  TotemMastery          = Spell(210643),
  EmberTotemBuff        = Spell(210658),
  TailwindTotemBuff     = Spell(210659),
  ResonanceTotemBuff    = Spell(202192),
  StormTotemBuff        = Spell(210652),

  LavaBurst             = Spell(51505),
  FireElemental         = Spell(198067),
  EarthElemental        = Spell(198103),
  LightningBolt         = Spell(188196),
  LavaBeam              = Spell(114074),
  FlameShock            = Spell(188389),
  FlameShockDebuff      = Spell(188389),

  -- Talents
  ElementalMastery      = Spell(16166),
  ElementalMasteryBuff  = Spell(16166),
  Ascendance            = Spell(114050),
  AscendanceBuff        = Spell(114050),
  LiquidMagmaTotem      = Spell(192222),

  -- Artifact
  Stormkeeper           = Spell(205495),
  StormkeeperBuff       = Spell(205495),

  -- Utility
  WindShear             = Spell(57994)
}
local S = Spell.Shaman.Elemental

-- Items
if not Item.Shaman then Item.Shaman = {} end
Item.Shaman.Elemental = {
  -- Legendaries
  SmolderingHeart           = Item(151819)
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

      -- Refreshable?
      -- actions.aoe+=/flame_shock,if=spell_targets.chain_lightning<4&maelstrom>=20,target_if=refreshable
      if S.FlameShock:IsCastable() and (Cache.EnemiesCount[40] < 4 and Player:Maelstrom() >= 20) then
        if AR.Cast(S.FlameShock) then return "Cast FlameShock" end
      end
    end
  end
end

AR.SetAPL(262, APL)
