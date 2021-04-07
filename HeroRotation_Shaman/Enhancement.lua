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
local GetWeaponEnchantInfo = GetWeaponEnchantInfo

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId
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

local function Single()
  -- actions.single=windstrike
  if S.Windstrike:IsCastable() then
    if HR.Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike main 142"; end
  end
  -- actions.single+=/primordial_wave,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if HR.Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single 2"; end
  end
  -- actions.single+=/stormstrike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.Stormstrike:IsCastable() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if HR.Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 26"; end
  end
  -- actions.single+=/crash_lightning,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.CrashLightning:IsCastable() and Target:IsInMeleeRange(8) and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if HR.Cast(S.CrashLightning) then return "crash_lightning single 32"; end
  end
  -- actions.single+=/ice_strike,if=runeforge.doom_winds.equipped&buff.doom_winds.up
  if S.IceStrike:IsCastable() and (DoomWindsEquipped and Player:BuffUp(S.DoomWindsBuff)) then
    if HR.Cast(S.IceStrike) then return "ice_strike single 38"; end
  end
  -- actions.single+=/flame_shock,if=!ticking
  if S.FlameShock:IsCastable() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 6"; end
  end
  -- actions.single+=/vesper_totem
  if S.VesperTotem:IsReady() then
    if HR.Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem single 8"; end
  end
  -- actions.single+=/frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsCastable() and (Player:BuffUp(S.HailstormBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 10"; end
  end
  -- actions.single+=/earthen_spike
  if S.EarthenSpike:IsCastable() then
    if HR.Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike single 12"; end
  end
  -- actions.single+=/fae_transfusion
  if S.FaeTransfusion:IsReady() then
    if HR.Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion single 14"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.stormkeeper.up
  if S.LightningBolt:IsCastable() and (Player:BuffUp(S.StormkeeperBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 16"; end
  end
  -- actions.single+=/elemental_blast,if=buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 18"; end
  end
  -- actions.single+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest single 20"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack=10
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 22"; end
  end
  -- actions.single+=/lava_lash,if=buff.hot_hand.up|(runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack>6)
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.HotHandBuff) or (PrimalLavaActuatorsEquipped and Player:BuffStack(S.PrimalLavaActuatorsBuff) > 6)) then
    if HR.Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 24"; end
  end
  -- actions.single+=/stormstrike
  if S.Stormstrike:IsCastable() then
    if HR.Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 26"; end
  end
  -- actions.single+=/stormkeeper,if=buff.maelstrom_weapon.stack>=5
  if S.Stormkeeper:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.Stormkeeper) then return "stormkeeper single 28"; end
  end
  -- actions.single+=/lava_lash
  if S.LavaLash:IsCastable() then
    if HR.Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 30"; end
  end
  -- actions.single+=/crash_lightning
  if S.CrashLightning:IsCastable() and Target:IsInMeleeRange(8) then
    if HR.Cast(S.CrashLightning) then return "crash_lightning single 32"; end
  end
  -- actions.single+=/flame_shock,target_if=refreshable
  if S.FlameShock:IsCastable() and (Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 34"; end
  end
  -- actions.single+=/frost_shock
  if S.FrostShock:IsCastable() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 36"; end
  end
  -- actions.single+=/ice_strike
  if S.IceStrike:IsCastable() then
    if HR.Cast(S.IceStrike) then return "ice_strike single 38"; end
  end
  -- actions.single+=/sundering
  if S.Sundering:IsCastable() then
    if HR.Cast(S.Sundering) then return "sundering single 40"; end
  end
  -- actions.single+=/fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsCastable() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if HR.Cast(S.FireNova) then return "fire_nova single 42"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 44"; end
  end
  -- actions.single+=/earth_elemental
  if S.EarthElemental:IsCastable() then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 46"; end
  end
  -- actions.single+=/windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsCastable() and Player:BuffDown(S.WindfuryTotemBuff) then
    if HR.Cast(S.WindfuryTotem) then return "wf1"; end
  end
end

local function Aoe()
  -- actions.aoe=windstrike,if=buff.crash_lightning.up
  if S.Windstrike:IsCastable() and Player:BuffUp(S.CrashLightningBuff) then
    if HR.Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike main 142"; end
  end
  -- actions.aoe+=/fae_transfusion,if=soulbind.grove_invigoration|soulbind.field_of_blossoms
  -- TODO
  if S.FaeTransfusion:IsReady() then
    if HR.Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 104"; end
  end
  -- actions.aoe+=/frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsCastable() and (Player:BuffUp(S.HailstormBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 62"; end
  end
  -- actions.aoe+=/flame_shock,target_if=refreshable,cycle_targets=1,if=talent.fire_nova.enabled|talent.lashing_flames.enabled|covenant.necrolord
  if S.FlameShock:IsCastable() and (S.FireNova:IsAvailable() or S.LashingFlames:IsAvailable() or Player:Covenant() == "Necrolord") then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 66"; end
  end
  -- actions.aoe+=/primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastCycle(S.PrimordialWave, MeleeEnemies10y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave aoe 68"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsCastable() and (EnemiesFlameShockCount >= 3) then
    if HR.Cast(S.FireNova) then return "fire_nova aoe 70"; end
  end
  -- actions.aoe+=/vesper_totem
  if S.VesperTotem:IsReady() then
    if HR.Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "vesper_totem aoe 72"; end
  end
  -- actions.aoe+=/lightning_bolt,if=buff.primordial_wave.up&(buff.stormkeeper.up|buff.maelstrom_weapon.stack>=5)
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffUp(S.StormkeeperBuff) or Player:BuffStack(S.MaelstromWeaponBuff) >= 5)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 74"; end
  end
  -- actions.aoe+=/crash_lightning,if=talent.crashing_storm.enabled|buff.crash_lightning.down
  if S.CrashLightning:IsCastable() and Target:IsInMeleeRange(8) and (S.CrashingStorm:IsAvailable() or Player:BuffDown(S.CrashLightningBuff)) then
    if HR.Cast(S.CrashLightning) then return "crash_lightning aoe 76"; end
  end
  -- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastCycle(S.LavaLash, MeleeEnemies10y, EvaluateCycleLavaLash, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 78"; end
  end
  -- actions.aoe+=/stormstrike,if=buff.crash_lightning.up
  if S.Stormstrike:IsCastable() and Player:BuffUp(S.CrashLightningBuff) then
    if HR.Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 98"; end
  end
  -- actions.aoe+=/crash_lightning
  if S.CrashLightning:IsCastable() and Target:IsInMeleeRange(8) then
    if HR.Cast(S.CrashLightning) then return "crash_lightning aoe 80"; end
  end
  -- actions.aoe+=/chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsCastable() and (Player:BuffUp(S.StormkeeperBuff)) then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 82"; end
  end
  -- actions.aoe+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "chain_harvest aoe 84"; end
  end
  -- actions.aoe+=/elemental_blast,if=buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 86"; end
  end
  -- actions.aoe+=/stormkeeper,if=buff.maelstrom_weapon.stack>=5
  if S.Stormkeeper:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.Stormkeeper) then return "stormkeeper aoe 88"; end
  end
  -- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack=10
  if S.ChainLightning:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 90"; end
  end
  -- actions.aoe+=/flame_shock,target_if=refreshable,cycle_targets=1,if=talent.fire_nova.enabled
  if S.FlameShock:IsReady() and (S.FireNova:IsAvailable()) then
    if Everyone.CastCycle(S.FlameShock, MeleeEnemies10y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 92"; end
  end
  -- actions.aoe+=/sundering
  if S.Sundering:IsCastable() and Target:IsInMeleeRange(11) then
    if HR.Cast(S.Sundering) then return "sundering aoe 94"; end
  end
  -- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack>6
  -- TODO
  if S.LavaLash:IsReady() and (PrimalLavaActuatorsEquipped and Player:BuffStack(S.PrimalLavaActuatorsBuff) > 6) then
    if Everyone.CastCycle(S.LavaLash, MeleeEnemies10y, EvaluateCycleLavaLash, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 96"; end
  end
  -- actions.aoe+=/windstrike
  if S.Windstrike:IsCastable() then
    if HR.Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike main 142"; end
  end
  -- actions.aoe+=/stormstrike
  if S.Stormstrike:IsCastable() then
    if HR.Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 98"; end
  end
  -- actions.aoe+=/lava_lash
  if S.LavaLash:IsCastable() then
    if HR.Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 100"; end
  end
  -- actions.aoe+=/flame_shock,target_if=refreshable,cycle_targets=1
  if S.FlameShock:IsCastable() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 102"; end
  end
  -- actions.aoe+=/fae_transfusion
  if S.FaeTransfusion:IsReady() then
    if HR.Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "fae_transfusion aoe 104"; end
  end
  -- actions.aoe+=/frost_shock
  if S.FrostShock:IsCastable() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 106"; end
  end
  -- actions.aoe+=/ice_strike
  if S.IceStrike:IsCastable() then
    if HR.Cast(S.IceStrike) then return "ice_strike aoe 108"; end
  end
  -- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 110"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>1
  if S.FireNova:IsCastable() and (EnemiesFlameShockCount > 1) then
    if HR.Cast(S.FireNova) then return "fire_nova aoe 112"; end
  end
  -- actions.aoe+=/earthen_spike
  if S.EarthenSpike:IsCastable() then
    if HR.Cast(S.EarthenSpike, nil, nil, not Target:IsSpellInRange(S.EarthenSpike)) then return "earthen_spike aoe 114"; end
  end
  -- actions.aoe+=/earth_elemental
  if S.EarthElemental:IsCastable() then
    if HR.Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental aoe 116"; end
  end
  -- actions.aoe+=/windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsCastable() and Player:BuffDown(S.WindfuryTotemBuff) then
    if HR.Cast(S.WindfuryTotem) then return "wf2"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Local Update
  totemFinder()
  hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId = GetWeaponEnchantInfo()
  -- Unit Update
  EnemiesCount30ySplash = Target:GetEnemiesInSplashRangeCount(30)
  MeleeEnemies10y = Player:GetEnemiesInMeleeRange(10)
  MeleeEnemies10yCount = #MeleeEnemies10y
  if AoEON() then
    Enemies40y = Player:GetEnemiesInRange(40)
    Enemies40yCount = #Enemies40y
    calcEnemiesFlameShockCount(S.FlameShock, Enemies40y)
  else
    Enemies40yCount = 1
    EnemiesFlameShockCount = 1
  end

  if Everyone.TargetIsValid() then
    -- windfury_weapon
    if not hasMainHandEnchant and S.WindfuryWeapon:IsCastable() then
      if HR.Cast(S.WindfuryWeapon) then return "WindfuryWeapon enchant"; end
    end
    -- flametongue_weapon
    if not hasOffHandEnchant and S.FlamentongueWeapon:IsCastable() then
      if HR.Cast(S.FlamentongueWeapon) then return "FlamentongueWeapon enchant"; end
    end
    -- lightning_shield
    -- Manually added: earth_shield if available and PreferEarthShield setting is true
    if Settings.Enhancement.PreferEarthShield and S.EarthShield:IsCastable() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield precombat"; end
    elseif S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield precombat"; end
    end
    -- stormkeeper,if=talent.stormkeeper.enabled
    if S.Stormkeeper:IsCastable() then
      if HR.Cast(S.Stormkeeper) then return "Stormkeeper precombat"; end
    end
    -- windfury_totem
    if S.WindfuryTotem:IsCastable() and (Player:BuffDown(S.WindfuryTotemBuff) or (DoomWindsEquipped and Player:DebuffDown(S.DoomWindsDebuff))) then
      if HR.Cast(S.WindfuryTotem) then return "wf3"; end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end

    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end

    if (CDsON()) then
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and (not S.Ascendance:IsAvailable() or not Player:BuffUp(S.AscendanceBuff)) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks racial"; end
      end
    end
    -- feral_spirit
    if S.FeralSpirit:IsCastable() then
      if HR.Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit main 144"; end
    end
    -- ascendance
    if S.Ascendance:IsCastable() and CDsON() then
      if HR.Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "ascendance main 146"; end
    end
    -- call_action_list,name=single,if=active_enemies=1
    if Enemies40yCount == 1 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1
    if Enemies40yCount > 1 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(263, APL, Init)
