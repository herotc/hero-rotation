--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Lua
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local max        = math.max
local strmatch   = string.match

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local HasMainHandEnchant, HasOffHandEnchant
local MHEnchantTimeRemains, OHEnchantTimeRemains
local Enemies40y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y, Enemies40yCount
local FightRemains
local VesperHealingCharges = 0

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Enhancement = HR.GUISettings.APL.Shaman.Enhancement
}

-- Legendaries
local DeeplyRootedEquipped = Player:HasLegendaryEquipped(132)
local DoomWindsEquipped = Player:HasLegendaryEquipped(138)
local PrimalLavaActuatorsEquipped = Player:HasLegendaryEquipped(141)
local SeedsofRampantGrowthEquipped = Player:HasLegendaryEquipped(246)

HL:RegisterForEvent(function()
  DeeplyRootedEquipped = Player:HasLegendaryEquipped(132)
  DoomWindsEquipped = Player:HasLegendaryEquipped(138)
  PrimalLavaActuatorsEquipped = Player:HasLegendaryEquipped(141)
  SeedsofRampantGrowthEquipped = Player:HasLegendaryEquipped(246)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function TotemFinder()
  for i = 1, 6, 1 do
    if strmatch(Player:TotemName(i), 'Totem') then
      return i
    end
  end
end

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateCycleLavaLash(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.LashingFlamesDebuff))
end

local function EvaluateTargetIfFilterPrimordialWave(TargetUnit)
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff))
end

local function EvaluateTargetIfPrimordialWave(TargetUnit)
  return (Player:BuffDown(S.PrimordialWaveBuff))
end

local function EvaluateTargetIfFilterLavaLash(TargetUnit)
  return (Target:DebuffRemains(S.LashingFlamesDebuff))
end

local function EvaluateTargetIfLavaLash(TargetUnit)
  return (S.LashingFlames:IsAvailable())
end

local function EvaluateTargetIfLavaLash2(TargetUnit)
  return (TargetUnit:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < MeleeEnemies10yCount and S.FlameShockDebuff:AuraActiveCount() < 6))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- windfury_weapon
  if ((not HasMainHandEnchant) or MHEnchantTimeRemains < 600000) and S.WindfuryWeapon:IsCastable() then
    if Cast(S.WindfuryWeapon) then return "windfury_weapon enchant"; end
  end
  -- flametongue_weapon
  if ((not HasOffHandEnchant) or OHEnchantTimeRemains < 600000) and S.FlamentongueWeapon:IsCastable() then
    if Cast(S.FlamentongueWeapon) then return "flametongue_weapon enchant"; end
  end
  -- lightning_shield
  -- Note: Moved to top of APL()
  -- stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() then
    if Cast(S.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- windfury_totem,if=!runeforge.doom_winds.equipped
  if S.WindfuryTotem:IsReady() and ((not DoomWindsEquipped) and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90)) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem precombat 4"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft precombat 6"; end
  end
  -- potion
  -- Manually removed, as this is no longer needed precombat
  -- snapshot_stats
end

local function Single()
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike single 2"; end
  end
  -- lava_lash,if=buff.hot_hand.up|(runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack>6)
  if S.LavaLash:IsReady() and (Player:BuffUp(S.HotHandBuff) or (PrimalLavaActuatorsEquipped and Player:BuffStack(S.PrimalLavaActuatorsBuff) > 6)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 4"; end
  end
  -- windfury_totem,if=!buff.windfury_totem.up
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true)) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 6"; end
  end
  if (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    -- stormstrike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 8"; end
    end
    -- crash_lightning,if=runeforge.doom_winds.equipped&buff.doom_winds.up
    if S.CrashLightning:IsReady() then
      if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 10"; end
    end
    -- ice_strike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
    if S.IceStrike:IsReady() then
      if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 12"; end
    end
    -- sundering,if=runeforge.doom_winds.equipped&buff.doom_winds.up
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 14"; end
    end
  end
  -- primordial_wave,if=buff.primordial_wave.down&(raid_event.adds.in>42|raid_event.adds.in<6)
  if S.PrimordialWave:IsCastable() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single 16"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 18"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5 and Player:BuffUp(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 20"; end
  end
  -- vesper_totem,if=raid_event.adds.in>40
  if S.VesperTotem:IsReady() then
    if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem single 22"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 24"; end
  end
  -- earthen_spike
  if S.EarthenSpike:IsReady() then
    if Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike single 26"; end
  end
  -- lava_lash,if=dot.flame_shock.refreshable
  if S.LavaLash:IsCastable() and (Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 28"; end
  end
  -- fae_transfusion,if=!runeforge.seeds_of_rampant_growth.equipped|cooldown.feral_spirit.remains>30
  if S.FaeTransfusion:IsReady() and ((not SeedsofRampantGrowthEquipped) or S.FeralSpirit:CooldownRemains() > 30) then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion single 30"; end
  end
  -- stormstrike,if=talent.stormflurry.enabled&buff.stormbringer.up
  if S.Stormstrike:IsCastable() and (S.Stormflurry:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 32"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single 34"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 36"; end
  end
  -- healing_stream_totem,if=runeforge.raging_vesper_vortex.equipped&talent.earth_shield.enabled&(vesper_totem_heal_charges>1|(vesper_totem_heal_charges>0&raid_event.adds.in>(buff.vesper_totem.remains-3)))
  -- TODO: Find a way to track vesper_totem charges
  -- earth_shield,if=runeforge.raging_vesper_vortex.equipped&talent.earth_shield.enabled&(vesper_totem_heal_charges>1|(vesper_totem_heal_charges>0&raid_event.adds.in>(buff.vesper_totem.remains-3)))
  -- TODO: Find a way to track vesper_totem charges
  -- chain_harvest,if=buff.maelstrom_weapon.stack>=5&raid_event.adds.in>=90
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest single 42"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack=10&buff.primordial_wave.down
  if S.LightningBolt:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 44"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 46"; end
  end
  -- stormkeeper,if=buff.maelstrom_weapon.stack>=5
  if S.Stormkeeper:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.Stormkeeper) then return "stormkeeper single 48"; end
  end
  -- fleshcraft,interrupt=1,if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft single 50"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<10
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 110) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 52"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 54"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 56"; end
  end
  -- sundering,if=raid_event.adds.in>=40
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 58"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 60"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 62"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 64"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single 66"; end
  end
  -- fleshcraft,if=soulbind.pustule_eruption
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft single 68"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 70"; end
  end
  -- flame_shock
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 72"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 74"; end
  end
end

local function Aoe()
  -- chain_harvest,if=buff.maelstrom_weapon.stack>=5
  if S.ChainHarvest:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest aoe 2"; end
  end
  if (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    -- crash_lightning,if=runeforge.doom_winds.equipped&buff.doom_winds.up
    if S.CrashLightning:IsReady() then
      if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 4"; end
    end
    -- sundering
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 6"; end
    end
  end
  -- healing_stream_totem,if=runeforge.raging_vesper_vortex.equipped&talent.earth_shield.enabled&vesper_totem_heal_charges>0
  -- TODO: Find a way to track vesper_totem charges
  -- earth_shield,if=runeforge.raging_vesper_vortex.equipped&talent.earth_shield.enabled&vesper_totem_heal_charges>0
  -- TODO: Find a way to track vesper_totem charges
  -- fire_nova,if=active_dot.flame_shock>=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= MeleeEnemies10yCount)) then
    if Cast(S.FireNova) then return "fire_nova aoe 12"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies40y, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Covenant) then return "primordial_wave aoe 14"; end
  end
  if (DeeplyRootedEquipped and Player:BuffUp(S.CrashLightningBuff)) then
    -- windstrike,if=runeforge.deeply_rooted_elements.equipped&buff.crash_lightning.up
    if S.Windstrike:IsReady() then
      if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 16"; end
    end
    -- stormstrike,if=runeforge.deeply_rooted_elements.equipped&buff.crash_lightning.up
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "stormstrike aoe 18"; end
    end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies&active_dot.flame_shock<6)
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, MeleeEnemies10y, "min", EvaluateTargetIfFilterLavaLash, EvaluateTargetIfLavaLash2, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 20"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 22"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!talent.hailstorm.enabled&active_dot.flame_shock<active_enemies&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((not S.Hailstorm:IsAvailable()) and S.FlameShockDebuff:AuraActiveCount() < MeleeEnemies10yCount and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 24"; end
  end
  -- lightning_bolt,if=(active_dot.flame_shock>=active_enemies|active_dot.flame_shock>=4)&buff.primordial_wave.up&buff.maelstrom_weapon.stack>=5
  if S.LightningBolt:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() >= MeleeEnemies10yCount or S.FlameShockDebuff:AuraActiveCount() >= 4) and Player:BuffUp(S.PrimordialWaveBuff) and Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 26"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 28"; end
  end
  -- fae_transfusion,if=soulbind.grove_invigoration|soulbind.field_of_blossoms|runeforge.seeds_of_rampant_growth.equipped
  if S.FaeTransfusion:IsReady() and (S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable() or SeedsofRampantGrowthEquipped) then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 30"; end
  end
  if (Player:BuffUp(S.PrimordialWaveBuff) and Player:BuffStack(S.MaelstromWeaponBuff) < 5) then
    -- crash_lightning,if=buff.crash_lightning.down&buff.primordial_wave.up&buff.maelstrom_weapon.stack<5
    if S.CrashLightning:IsReady() and (Player:BuffDown(S.CrashLightningBuff)) then
      if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 32"; end
    end
    -- sundering,if=buff.primordial_wave.up&buff.maelstrom_weapon.stack<5
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 34"; end
    end
    -- stormstrike,if=buff.primordial_wave.up&buff.maelstrom_weapon.stack<5
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "stormstrike aoe 36"; end
    end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 38"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=4
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 4) then
    if Cast(S.FireNova) then return "fire_nova aoe 40"; end
  end
  -- crash_lightning,if=talent.crashing_storm.enabled|buff.crash_lightning.down
  if S.CrashLightning:IsReady() and (S.CrashingStorm:IsAvailable() or Player:BuffDown(S.CrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 42"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, MeleeEnemies10y, "min", EvaluateTargetIfFilterLavaLash, EvaluateTargetIfLavaLash, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 44"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova aoe 46"; end
  end
  -- vesper_totem
  if S.VesperTotem:IsReady() then
    if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem aoe 48"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 50"; end
  end
  -- lava_lash,if=buff.crash_lightning.up
  if S.LavaLash:IsReady() and (Player:BuffUp(S.CrashLightningBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 52"; end
  end
  if (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    -- elemental_blast,if=buff.maelstrom_weapon.stack>=5
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 54"; end
    end
    -- stormkeeper,if=buff.maelstrom_weapon.stack>=5
    if S.Stormkeeper:IsCastable() then
      if Cast(S.Stormkeeper) then return "stormkeeper aoe 56"; end
    end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=10
  if S.ChainLightning:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 58"; end
  end
  -- stormstrike,if=buff.crash_lightning.up
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "lava_lash aoe 60"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova aoe 62"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 64"; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 66"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 68"; end
  end
  -- fleshcraft,interrupt=1,if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft aoe 70"; end
  end
  -- flame_shock,target_if=refreshable,cycle_targets=1
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 72"; end
  end
  -- fae_transfusion
  if S.FaeTransfusion:IsReady() then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 74"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 76"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 78"; end
  end
  -- earthen_spike
  if S.EarthenSpike:IsReady() then
    if Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike aoe 80"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental aoe 82"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem aoe 84"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Local Update
  --TotemFinder()
  HasMainHandEnchant, MHEnchantTimeRemains, _, _, HasOffHandEnchant, OHEnchantTimeRemains = GetWeaponEnchantInfo()
  -- Unit Update
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40)
    Enemies40yCount = #Enemies40y
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10)
    MeleeEnemies10yCount = #MeleeEnemies10y
  else
    Enemies40y = {}
    Enemies40yCount = 1
    MeleeEnemies10y = {}
    MeleeEnemies10yCount = 1
  end

  -- Calculate how long is remaining in the fight
  FightRemains = HL.FightRemains(MeleeEnemies10y, false)

  if Everyone.TargetIsValid() then
    -- Moved from Precombat: lightning_shield
    -- Manually added: earth_shield if available and PreferEarthShield setting is true
    if Settings.Enhancement.PreferEarthShield and S.EarthShield:IsReady() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield main 2"; end
    elseif S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) and (Settings.Enhancement.PreferEarthShield and Player:BuffDown(S.EarthShield) or not Settings.Enhancement.PreferEarthShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield main 2"; end
    end
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- bloodlust
    -- Not adding this, as when to use Bloodlust will vary fight to fight
    -- potion,if=expected_combat_length-time<60
    if I.PotionofSpectralAgility:IsReady() and (FightRemains < 60) then
      if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- heart_essence (I guess the simc module is out of date?)
    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if (CDsON()) then
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and (not S.Ascendance:IsAvailable() or not Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racial"; end
      end
    end
    -- feral_spirit
    if S.FeralSpirit:IsCastable() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit main 6"; end
    end
    -- fae_transfusion,if=(talent.ascendance.enabled|runeforge.doom_winds.equipped)&(soulbind.grove_invigoration|soulbind.field_of_blossoms|active_enemies=1)
    if S.FaeTransfusion:IsReady() and ((S.Ascendance:IsAvailable() or DoomWindsEquipped) and (S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable() or MeleeEnemies10yCount == 1)) then
      if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion main 8"; end
    end
    -- ascendance,if=raid_event.adds.in>=90|active_enemies>1
    if S.Ascendance:IsCastable() and CDsON() then
      if Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "ascendance main 10"; end
    end
    -- windfury_totem,if=runeforge.doom_winds.equipped&buff.doom_winds_debuff.down&(raid_event.adds.in>=60|active_enemies>1)
    -- Note: Added TimeSinceLastCast, as DoomWindsBuff has an internal CD of 60s
    if S.WindfuryTotem:IsReady() and (DoomWindsEquipped and Player:BuffDown(S.DoomWindsBuff) and S.WindfuryTotem:TimeSinceLastCast() > 60) then
      if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem main 12"; end
    end
    -- call_action_list,name=single,if=active_enemies=1
    if MeleeEnemies10yCount < 2 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1
    if MeleeEnemies10yCount > 1 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FlameShockDebuff:RegisterAuraTracking()
  HR.Print("Enhancement Shaman rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(263, APL, Init)
