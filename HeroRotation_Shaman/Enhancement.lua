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

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local hasMainHandEnchant, hasOffHandEnchant
local Enemies40y, MeleeEnemies10y, MeleeEnemies10yCount, MeleeEnemies5y, Enemies40yCount, EnemiesCount30ySplash
local EnemiesFlameShockCount = 0
local DoomWindsEquipped = Player:HasLegendaryEquipped(138)
local PrimalLavaActuatorsEquipped = Player:HasLegendaryEquipped(141)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Enhancement = HR.GUISettings.APL.Shaman.Enhancement
}

HL:RegisterForEvent(function()
  DoomWindsEquipped = Player:HasLegendaryEquipped(138)
  PrimalLavaActuatorsEquipped = Player:HasLegendaryEquipped(141)
end, "PLAYER_EQUIPMENT_CHANGED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function totemFinder()
  for i = 1, 6, 1 do
    if string.match(Player:TotemName(i), 'Totem') then
      return i
    end
  end
end

-- Counter for Debuff on other enemies
local function calcEnemiesFlameShockCount(Object, Enemies)
  local debuffs = 0;
  if HR.AoEON() then
    for _, CycleUnit in pairs(Enemies) do
      if CycleUnit:DebuffUp(Object) then
        debuffs = debuffs + 1;
        EnemiesFlameShockCount = debuffs
      end
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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- windfury_weapon
  if not hasMainHandEnchant and S.WindfuryWeapon:IsCastable() then
    if Cast(S.WindfuryWeapon) then return "WindfuryWeapon enchant"; end
  end
  -- flametongue_weapon
  if not hasOffHandEnchant and S.FlamentongueWeapon:IsCastable() then
    if Cast(S.FlamentongueWeapon) then return "FlamentongueWeapon enchant"; end
  end
  -- lightning_shield
  -- Note: Moved to top of APL()
  -- stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() then
    if Cast(S.Stormkeeper) then return "Stormkeeper precombat"; end
  end
  -- windfury_totem,if=!runeforge.doom_winds.equipped
  if S.WindfuryTotem:IsReady() and (not DoomWindsEquipped and (Player:BuffDown(S.WindfuryTotemBuff) or S.WindfuryTotem:TimeSinceLastCast() > 90)) then
    if Cast(S.WindfuryTotem) then return "windfury_totem precombat"; end
  end
  -- potion
  if I.PotionofSpectralAgility:IsReady() and Settings.Commons.Enabled.Potions then
    if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion precombat"; end
  end
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
  -- primordial_wave,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single 6"; end
  end
  -- stormstrike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.Stormstrike:IsReady() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 8"; end
  end
  -- crash_lightning,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.CrashLightning:IsReady() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 10"; end
  end
  -- ice_strike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.IceStrike:IsReady() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 12"; end
  end
  -- sundering,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.Sundering:IsReady() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 14"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 18"; end
  end
  -- vesper_totem
  if S.VesperTotem:IsReady() then
    if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem single 20"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 22"; end
  end
  -- earthen_spike
  if S.EarthenSpike:IsReady() then
    if Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike single 24"; end
  end
  -- fae_transfusion
  if S.FaeTransfusion:IsReady() then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion single 26"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  -- Manually changed to: lightning_bolt,if=buff.stormkeeper.up
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 28"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 30"; end
  end
  -- chain_harvest,if=buff.maelstrom_weapon.stack>=5&raid_event.adds.in>=90
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest single 32"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack=10
  if S.LightningBolt:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 34"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 36"; end
  end
  -- stormkeeper,if=buff.maelstrom_weapon.stack>=5
  if S.Stormkeeper:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.Stormkeeper) then return "stormkeeper single 38"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 40"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 42"; end
  end
  -- flame_shock,target_if=refreshable
  if S.FlameShock:IsReady() and (Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 44"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 46"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 48"; end
  end
  -- sundering,if=raid_event.adds.in>=40
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(8)) then return "sundering single 50"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova, nil, nil, not Target:IsInMeleeRange(5)) then return "fire_nova single 52"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5
  if S.LightningBolt:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 54"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 56"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem) then return "windfury_totem single 58"; end
  end
end

local function Aoe()
  -- windstrike,if=buff.crash_lightning.up
  if S.Windstrike:IsReady() and Player:BuffUp(S.CrashLightningBuff) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 2"; end
  end
  -- fae_transfusion,if=soulbind.grove_invigoration|soulbind.field_of_blossoms
  if S.FaeTransfusion:IsReady() and (S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable()) then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 4"; end
  end
  -- crash_lightning,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.CrashLightning:IsReady() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 6"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 8"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 10"; end
  end
  -- flame_shock,target_if=refreshable,cycle_targets=1,if=talent.fire_nova.enabled|talent.lashing_flames.enabled|covenant.necrolord|runeforge.primal_lava_actuators.equipped
  if S.FlameShock:IsReady() and (S.FireNova:IsAvailable() or S.LashingFlames:IsAvailable() or Player:Covenant() == "Necrolord" or PrimalLavaActuatorsEquipped) then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 12"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies40y, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Covenant) then return "primordial_wave aoe 14"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (EnemiesFlameShockCount >= 3) then
    if Cast(S.FireNova, nil, nil, not Target:IsInMeleeRange(5)) then return "fire_nova aoe 16"; end
  end
  -- vesper_totem
  if S.VesperTotem:IsReady() then
    if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem aoe 18"; end
  end
  -- lightning_bolt,if=buff.primordial_wave.up&buff.maelstrom_weapon.stack>=5
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.PrimordialWaveBuff) and Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 20"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 22"; end
  end
  -- crash_lightning,if=talent.crashing_storm.enabled|buff.crash_lightning.down
  if S.CrashLightning:IsReady() and (S.CrashingStorm:IsAvailable() or Player:BuffDown(S.CrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 24"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, MeleeEnemies10y, "min", EvaluateTargetIfFilterLavaLash, EvaluateTargetIfLavaLash, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 26"; end
  end
  -- lava_lash,if=buff.crash_lightning.up&(buff.hot_hand.up|(runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack>6))
  if S.LavaLash:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and (Player:BuffUp(S.HotHandBuff) or (PrimalLavaActuatorsEquipped and Player:BuffStack(S.PrimalLavaActuatorsBuff) > 6))) then
    if Cast(S.LavaLash, nil, nil, not Target:IsInMeleeRange(5)) then return "lava_lash aoe 28"; end
  end
  -- stormstrike,if=buff.crash_lightning.up
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "stormstrike aoe 30"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 32"; end
  end
  -- chain_harvest,if=buff.maelstrom_weapon.stack>=5
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest aoe 34"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 36"; end
  end
  -- stormkeeper,if=buff.maelstrom_weapon.stack>=5
  if S.Stormkeeper:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.Stormkeeper) then return "stormkeeper aoe 38"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=10
  if S.ChainLightning:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 40"; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 42"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 44"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsInMeleeRange(5)) then return "lava_lash aoe 46"; end
  end
  -- flame_shock,target_if=refreshable,cycle_targets=1
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 48"; end
  end
  -- fae_transfusion
  if S.FaeTransfusion:IsReady() then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 50"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 52"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike aoe 54"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 56"; end
  end
  -- fire_nova,if=active_dot.flame_shock>1
  if S.FireNova:IsReady() and (EnemiesFlameShockCount > 1) then
    if Cast(S.FireNova, nil, nil, not Target:IsInMeleeRange(5)) then return "fire_nova aoe 58"; end
  end
  -- earthen_spike
  if S.EarthenSpike:IsReady() then
    if Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike aoe 60"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental aoe 62"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem) then return "windfury_totem aoe 64"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Local Update
  totemFinder()
  hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
  -- Unit Update
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40)
    Enemies40yCount = #Enemies40y
    MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10)
    MeleeEnemies10yCount = #MeleeEnemies10y
    EnemiesCount30ySplash = Target:GetEnemiesInSplashRangeCount(30)
    calcEnemiesFlameShockCount(S.FlameShock, Enemies40y)
  else
    Enemies40yCount = 1
    MeleeEnemies10yCount = 1
    EnemiesCount30ySplash = 1
    EnemiesFlameShockCount = 1
  end

  -- Calculate how long is remaining in the fight
  fightRemains = max(HL.FightRemains(Enemies8ySplash, false), HL.BossFightRemains())

  if Everyone.TargetIsValid() then
    -- lightning_shield
    -- Manually added: earth_shield if available and PreferEarthShield setting is true
    if Settings.Enhancement.PreferEarthShield and S.EarthShield:IsReady() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield default 2"; end
    elseif S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) and (Settings.Enhancement.PreferEarthShield and Player:BuffDown(S.EarthShield) or not Settings.Enhancement.PreferEarthShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield default 2"; end
    end
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- potion,if=expected_combat_length-time<60
    if I.PotionofSpectralAgility:IsReady() and (fightRemains < 60) then
      if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "potion default 4"; end
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
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and (not S.Ascendance:IsAvailable() or not Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racial"; end
      end
    end
    -- feral_spirit
    if S.FeralSpirit:IsCastable() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit default 6"; end
    end
    -- fae_transfusion,if=(talent.ascendance.enabled|runeforge.doom_winds.equipped)&(soulbind.grove_invigoration|soulbind.field_of_blossoms|active_enemies=1)
    if S.FaeTransfusion:IsReady() and ((S.Ascendance:IsAvailable() or DoomWindsEquipped) and (S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable() or MeleeEnemies10yCount == 1)) then
      if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion default 8"; end
    end
    -- ascendance,if=raid_event.adds.in>=90|active_enemies>1
    if S.Ascendance:IsCastable() and CDsON() then
      if Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "ascendance default 10"; end
    end
    -- windfury_totem,if=runeforge.doom_winds.equipped&buff.doom_winds_debuff.down&(raid_event.adds.in>=60|active_enemies>1)
    -- Note: Added TimeSinceLastCast, as DoomWindsBuff has an internal CD of 60s
    if S.WindfuryTotem:IsReady() and (DoomWindsEquipped and Player:BuffDown(S.DoomWindsBuff) and S.WindfuryTotem:TimeSinceLastCast() > 60) then
      if Cast(S.WindfuryTotem) then return "windfury_totem default 12"; end
    end
    -- call_action_list,name=single,if=active_enemies=1
    if MeleeEnemies10yCount == 1 then
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

end

HR.SetAPL(263, APL, Init)
