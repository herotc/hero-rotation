--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
-- Lua


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

local S = Spell.Shaman.Elemental
local I = Item.Shaman.Elemental

-- Rotation Var
local Enemies40y, Enemies40yCount, EnemiesCount10ySplash

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffDown(S.FlameShock) and TargetUnit:DebuffRefreshable(S.FlameShock))
end

local function precombat()
  --actions.precombat=flask
  --actions.precombat+=/food
  --actions.precombat+=/augmentation
  --actions.precombat+=/lightning_shield
  if S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) then
    if HR.Cast(S.LightningShield) then return "lightning_shield precombat"; end
  end
  --actions.precombat+=/potion
  --# Snapshot raid buffed stats before combat begins and pre-potting is done.
  --actions.precombat+=/snapshot_stats

  -- no APL but something to start with
  if S.FlameShock:IsCastable() and Target:DebuffDown(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock precombat"; end
  end
end

local function aoe()
  --actions.aoe=stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() and S.Stormkeeper:IsAvailable() then
    if HR.Cast(S.Stormkeeper) then return "Stormkeeper 1"; end
  end
  --actions.aoe+=/flame_shock,target_if=refreshable
  if S.FlameShock:IsCastable() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 1"; end
  end
  --actions.aoe+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsCastable() and S.LiquidMagmaTotem:IsAvailable() then
    if HR.Cast(S.LiquidMagmaTotem) then return "LiquidMagmaTotem 1"; end
  end
  --actions.aoe+=/lava_burst,if=talent.master_of_the_elements.enabled&maelstrom>=50&buff.lava_surge.up
  if S.LavaBurst:IsCastable() and S.MasterOfTheElements:IsAvailable() and  Player:Maelstrom() >= 50 and Player:BuffUp(S.LavaSurgeBuff) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "LavaBurst 1"; end
  end
  --actions.aoe+=/echoing_shock,if=talent.echoing_shock.enabled
  if S.EchoingShock:IsCastable() and S.EchoingShock:IsAvailable() then
    if HR.Cast(S.EchoingShock) then return "EchoingShock 1"; end
  end
  --actions.aoe+=/earthquake
  if S.Earthquake:IsCastable() and Player:Maelstrom() >= 60 then
    if HR.Cast(S.Earthquake) then return "Earthquake 1"; end
  end
  --actions.aoe+=/chain_lightning
  if S.ChainLightning:IsCastable() then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "ChainLightning 1"; end
  end
  --actions.aoe+=/flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 2"; end
  end
  --actions.aoe+=/frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "FrostShock 1"; end
  end
end

local function single()
  --actions.single_target=flame_shock,target_if=refreshable
  if S.FlameShock:IsCastable() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 4"; end
  end
  --actions.single_target+=/elemental_blast,if=talent.elemental_blast.enabled
  if S.ElementalBlast:IsCastable() and S.ElementalBlast:IsAvailable() then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "ElementalBlast 1"; end
  end
  --actions.single_target+=/stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() and S.Stormkeeper:IsAvailable() then
    if HR.Cast(S.Stormkeeper) then return "Stormkeeper 2"; end
  end
  --actions.single_target+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsCastable() and S.LiquidMagmaTotem:IsAvailable() then
    if HR.Cast(S.LiquidMagmaTotem) then return "LiquidMagmaTotem 2"; end
  end
  --actions.single_target+=/echoing_shock,if=talent.echoing_shock.enabled
  if S.EchoingShock:IsCastable() and S.EchoingShock:IsAvailable() then
    if HR.Cast(S.EchoingShock) then return "EchoingShock 2"; end
  end
  --actions.single_target+=/static_discharge,if=talent.static_discharge.enabled
  if S.StaticDischarge:IsCastable() and S.StaticDischarge:IsAvailable() then
    if HR.Cast(S.StaticDischarge) then return "StaticDischarge 1"; end
  end
  --actions.single_target+=/ascendance,if=talent.ascendance.enabled
  if S.Ascendance:IsCastable() and S.Ascendance:IsAvailable() and CDsON() then
    if HR.Cast(S.Ascendance, Settings.Elemental.GCDasOffGCD.Ascendance) then return "Ascendance 1"; end
  end
  --actions.single_target+=/lava_burst,if=cooldown_react
  if S.LavaBurst:IsCastable() and (Player:BuffUp(S.LavaSurgeBuff) or Player:BuffUp(S.Ascendance)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "LavaBurst 2"; end
  end
  --actions.single_target+=/lava_burst,if=cooldown_react
  if S.LavaBurst:IsCastable() and (Player:BuffUp(S.LavaSurgeBuff) or Player:BuffUp(S.Ascendance)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "LavaBurst 2"; end
  end
  --actions.single_target+=/earthquake,if=(spell_targets.chain_lightning>1&!runeforge.echoes_of_great_sundering.equipped|buff.echoes_of_great_sundering.up) TODO
  --actions.single_target+=/earth_shock
  if S.EarthShock:IsCastable() and Player:Maelstrom() >= 60 then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "EarthShock 1"; end
  end
  --actions.single_target+=/lightning_lasso
  if S.LightningLasso:IsCastable() and S.LightningLasso:IsAvailable() then
    if HR.Cast(S.LightningLasso, nil, nil, not Target:IsSpellInRange(S.LightningLasso)) then return "LightningLasso 1"; end
  end
  --actions.single_target+=/frost_shock,if=talent.icefury.enabled&buff.icefury.up
  if S.FrostShock:IsCastable() and S.Icefury:IsAvailable() and Player:BuffUp(S.Icefury) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "FrostShock 2"; end
  end
  --actions.single_target+=/icefury,if=talent.icefury.enabled
  if S.Icefury:IsCastable() and S.Icefury:IsAvailable() then
    if HR.Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "Icefury 1"; end
  end
  --actions.single_target+=/lightning_bolt
  if S.LightningBolt:IsCastable() then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "LightningBolt 1"; end
  end
  --actions.single_target+=/flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 5"; end
  end
  --actions.single_target+=/flame_shock,moving=1,if=movement.distance>6 TODO
  --# Frost Shock is our movement filler.
  --actions.single_target+=/frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "FrostShock 1"; end
  end
end

--- ======= ACTION LISTS =======
-- Put here action lists only if they are called multiple times in the APL
-- If it's only put one time, it's doing a closure call for nothing.



--- ======= MAIN =======
local function APL ()
  -- Local Update

  -- Unit Update
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40)
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
    Enemies40yCount = #Enemies40y
  else
    Enemies40yCount = 1
  end

  -- Defensives

  -- Out of Combat
  if not Player:AffectingCombat() then
    -- Flask
    -- Food
    -- Rune
    -- PrePot w/ Bossmod Countdown
    -- Opener
    if Everyone.TargetIsValid() then
      -- there is ni precombat defined in APL so i created my own
      local ShouldReturn = precombat(); if ShouldReturn then return ShouldReturn; end
    end
    return
  end

  -- In Combat
  if Everyone.TargetIsValid() then
    --# Executed every time the actor is available.
    --# Interrupt of casts.
    --actions=wind_shear
    --actions+=/use_items
    --actions+=/flame_shock,if=!ticking
    if S.FlameShock:IsCastable() and Target:DebuffDown(S.FlameShock) then
      if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 3"; end
    end
    --actions+=/fire_elemental
    if S.FireElemental:IsCastable() and CDsON() then
      if HR.Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "FireElemental 1"; end
    end
    --actions+=/storm_elemental
    if S.StormElemental:IsCastable() and S.StormElemental:IsAvailable() and CDsON() then
      if HR.Cast(S.StormElemental) then return "StormElemental 1"; end
    end

    if CDsON() then
      --actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial 1"; end
      end
      --actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial 2"; end
      end
      --actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial 3"; end
      end
      --actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial 4"; end
      end
      --actions+=/bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and ( not S.Ascendance:IsAvailable() or not Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:SpellInRange(S.BagofTricks)) then return "bag_of_tricks racial 5"; end
      end
    end
    --actions+=/primordial_wave,if=covenant.necrolord TODO
    --actions+=/vesper_totem,if=covenant.kyrian TODO
    --actions+=/chain_harvest,if=covenant.venthyr TODO
    --actions+=/fae_transfusion,if=covenant.night_fae TODO
    --actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if Enemies40yCount > 2 and EnemiesCount10ySplash > 0 then
      local ShouldReturn = aoe(); if ShouldReturn then return ShouldReturn; end
    end
    --actions+=/run_action_list,name=single_target,if=active_enemies<=2
    if Enemies40yCount <= 2 then
      local ShouldReturn = single(); if ShouldReturn then return ShouldReturn; end
    end
    return
  end
end

HR.SetAPL(262, APL)


--- ======= SIMC =======
-- Last Update: 11/12/2020

-- APL goes here
--# Executed every time the actor is available.
--# Interrupt of casts.
--actions=wind_shear
--actions+=/use_items
--actions+=/flame_shock,if=!ticking
--actions+=/fire_elemental
--actions+=/storm_elemental
--actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
--actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
--actions+=/bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
--actions+=/primordial_wave,if=covenant.necrolord
--actions+=/vesper_totem,if=covenant.kyrian
--actions+=/chain_harvest,if=covenant.venthyr
--actions+=/fae_transfusion,if=covenant.night_fae
--actions+=/run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
--actions+=/run_action_list,name=single_target,if=active_enemies<=2

--actions.aoe=stormkeeper,if=talent.stormkeeper.enabled
--actions.aoe+=/flame_shock,target_if=refreshable
--actions.aoe+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
--actions.aoe+=/lava_burst,if=talent.master_of_the_elements.enabled&maelstrom>=50&buff.lava_surge.up
--actions.aoe+=/echoing_shock,if=talent.echoing_shock.enabled
--actions.aoe+=/earthquake
--actions.aoe+=/chain_lightning
--actions.aoe+=/flame_shock,moving=1,target_if=refreshable
--actions.aoe+=/frost_shock,moving=1

--actions.single_target=flame_shock,target_if=refreshable
--actions.single_target+=/elemental_blast,if=talent.elemental_blast.enabled
--actions.single_target+=/stormkeeper,if=talent.stormkeeper.enabled
--actions.single_target+=/liquid_magma_totem,if=talent.liquid_magma_totem.enabled
--actions.single_target+=/echoing_shock,if=talent.echoing_shock.enabled
--actions.single_target+=/static_discharge,if=talent.static_discharge.enabled
--actions.single_target+=/ascendance,if=talent.ascendance.enabled
--actions.single_target+=/lava_burst,if=cooldown_react
--actions.single_target+=/lava_burst,if=cooldown_react
--actions.single_target+=/earthquake,if=(spell_targets.chain_lightning>1&!runeforge.echoes_of_great_sundering.equipped|buff.echoes_of_great_sundering.up)
--actions.single_target+=/earth_shock
--actions.single_target+=/lightning_lasso
--actions.single_target+=/frost_shock,if=talent.icefury.enabled&buff.icefury.up
--actions.single_target+=/icefury,if=talent.icefury.enabled
--actions.single_target+=/lightning_bolt
--actions.single_target+=/flame_shock,moving=1,target_if=refreshable
--actions.single_target+=/flame_shock,moving=1,if=movement.distance>6
--# Frost Shock is our movement filler.
--actions.single_target+=/frost_shock,moving=1
