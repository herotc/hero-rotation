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
  I.CacheofAcquiredTreasures:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.TheFirstSigil:ID(),
}

-- Rotation Var
local HasMainHandEnchant, HasOffHandEnchant
local MHEnchantTimeRemains, OHEnchantTimeRemains
local Enemies40y, Enemies10y, Enemies10yCount, Enemies40yCount
local BossFightRemains = 11111
local FightRemains = 11111
local VesperHealingCharges = 0
local TiLightningBolt, TiChainLightning = 0

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

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
  return (TargetUnit:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount and S.FlameShockDebuff:AuraActiveCount() < 6))
end

local function Precombat()
  -- actions.precombat=flask
  -- actions.precombat+=/food
  -- actions.precombat+=/augmentation

  -- actions.precombat+=/windfury_weapon
  if ((not HasMainHandEnchant) or MHEnchantTimeRemains < 600000) and S.WindfuryWeapon:IsCastable() then
    if Cast(S.WindfuryWeapon) then return "Windfury Weapon enchant"; end
  end
  -- actions.precombat+=/flametongue_weapon
  if ((not HasOffHandEnchant) or OHEnchantTimeRemains < 600000) and S.FlamentongueWeapon:IsCastable() then
    if Cast(S.FlamentongueWeapon) then return "Flametongue Weapon enchant"; end
  end
  -- actions.precombat+=/lightning_shield
  -- Note: Moved to top of APL()

  -- actions.precombat+=/stormkeeper
  if S.Stormkeeper:IsCastable() then
    if Cast(S.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- actions.precombat+=/windfury_totem,if=!runeforge.doom_winds.equipped
  if S.WindfuryTotem:IsReady() and ((not DoomWindsEquipped) and (Player:BuffDown(S.WindfuryTotemBuff, true))) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem precombat"; end
  end
  -- actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "Fleshcraft precombat"; end
  end
  -- actions.precombat+=/variable,name=trinket1_is_weird,value=trinket.1.is.the_first_sigil|trinket.1.is.scars_of_fraternal_strife|trinket.1.is.cache_of_acquired_treasures
  -- actions.precombat+=/variable,name=trinket2_is_weird,value=trinket.2.is.the_first_sigil|trinket.2.is.scars_of_fraternal_strife|trinket.2.is.cache_of_acquired_treasures
  -- Note: These variables just exclude these three trinkets from the generic use_items. We'll just use HR's OnUseExcludes instead.

  -- # Snapshot raid buffed stats before combat begins and pre-potting is done.
  -- actions.precombat+=/snapshot_stats
end

local function Single()
  -- actions.single=windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "Windstrike single"; end
  end
  -- actions.single+=/lava_lash,if=buff.hot_hand.up|buff.ashen_catalyst.stack=8|(runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack=8)
  if S.LavaLash:IsReady() and Player:BuffUp(S.HotHandBuff) or Player:BuffStack(S.AshenCatalystBuff) == 8 or (PrimalLavaActuatorsEquipped and Player:BuffStack(S.PrimalLavaActuatorsBuff) == 8) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash single"; end
  end
  -- actions.single+=/windfury_totem,if=!buff.windfury_totem.up
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true)) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem single"; end
  end
  if Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.DoomWinds) then   
    -- actions.single+=/stormstrike,if=buff.doom_winds.up|buff.doom_winds_talent.up
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "Stormstrike single (Doom Winds buff)"; end
    end
    -- actions.single+=/crash_lightning,if=buff.doom_winds.up|buff.doom_winds_talent.up
    if S.CrashLightning:IsReady() then
      if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "Crash Lightning single (Doom Winds buff)"; end
    end
    -- actions.single+=/ice_strike,if=buff.doom_winds.up|buff.doom_winds_talent.up
    if S.IceStrike:IsReady() then
      if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "Ice Strike single (Doom Winds buff)"; end
    end
    -- actions.single+=/sundering,if=buff.doom_winds.up|buff.doom_winds_talent.up
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "Sundering single (Doom Winds buff)"; end
    end
  end
  -- actions.single+=/primordial_wave,if=buff.primordial_wave.down&(raid_event.adds.in>42|raid_event.adds.in<6)
  if S.PrimordialWave:IsCastable() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "Primordial Wave single"; end
  end
  -- actions.single+=/flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "Flame Shock single"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains&(!buff.splintered_elements.up|fight_remains<=12)
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5 and Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "Lightning Bolt single"; TiLightningBolt = 1; TiChainLightning = 0; end
  end
  -- actions.single+=/ice_strike,if=talent.hailstorm.enabled
    if S.IceStrike:IsReady() and S.Hailstorm:IsAvailable() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "Ice Strike single"; end
  end
  -- actions.single+=/frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "Frost Shock single"; end
  end
  -- actions.single+=/lava_lash,if=dot.flame_shock.refreshable
  if S.LavaLash:IsCastable() and (Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash single (Refresh dot)"; end
  end
  -- actions.single+=/stormstrike,if=talent.stormflurry.enabled&buff.stormbringer.up
  if S.Stormstrike:IsCastable() and (S.Stormflurry:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "Stormstrike single"; end
  end
  -- actions.single+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and (not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "Elemental Blast single"; end
  end
  -- actions.single+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5&raid_event.adds.in>=90
  if S.ChainHarvest:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "Chain Harvest single"; end
  end
  -- actions.single+=/lava_burst,if=buff.maelstrom_weapon.stack>=5
  if S.LavaBurst:IsReady() and Player:BuffStack(S.MaelstromWeaponBuff) >= 5 then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "Lava Burst single"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack=10&buff.primordial_wave.down
  if S.LightningBolt:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) == 10 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "Lightning Bolt single"; TiLightningBolt = 1; TiChainLightning = 0; end
  end
  -- actions.single+=/stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "Stormstrike single"; end
  end
  -- actions.single+=/fleshcraft,interrupt=1,if=soulbind.volatile_solvent
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "Fleshcraft single"; end
  end
  -- actions.single+=/windfury_totem,if=buff.windfury_totem.remains<10
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 110) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem single"; end
  end
  -- actions.single+=/ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "Ice Strike single"; end
  end
  -- actions.single+=/lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash single"; end
  end
  -- actions.single+=/bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "Bag of Tricks single"; end
  end
  -- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "Lightning Bolt single"; TiLightningBolt = 1; TiChainLightning = 0; end
  end
  -- actions.single+=/sundering,if=raid_event.adds.in>=40
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "Sundering single"; end
  end
  -- actions.single+=/fire_nova,if=talent.swirling_maelstrom.enabled&active_dot.flame_shock
  if S.FireNova:IsReady() and S.SwirlingMaelstrom:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) then
    if Cast(S.FireNova) then return "Fire Nova single (Swirling Maelstrom)"; end
  end
  -- actions.single+=/frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "Frost Shock single"; end
  end
  -- actions.single+=/crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "Crash Lightning single"; end
  end
  -- actions.single+=/fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and Target:DebuffUp(S.FlameShockDebuff) then
    if Cast(S.FireNova) then return "Fire Nova single"; end
  end
  -- actions.single+=/fleshcraft,if=soulbind.pustule_eruption
  if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled()) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "Fleshcraft single"; end
  end
  -- actions.single+=/earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "Earth Elemental single"; end
  end
  -- actions.single+=/flame_shock
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "Flame Shock single"; end
  end
  -- actions.single+=/windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem single"; end
  end
end

local function Aoe()
  -- actions.aoe=crash_lightning,if=(talent.doom_winds|runeforge.doom_winds.equipped)&(buff.doom_winds.up|buff.doom_winds_talent.up)
  if S.CrashLightning:IsReady() and (S.DoomWinds:IsAvailable() or DoomWindsEquipped) and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.DoomWinds)) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "Crash Lightning aoe (Doom Winds buff)"; end
  end
  -- actions.aoe+=/lightning_bolt,if=(active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack>=(5+5*talent.overflowing_maelstrom.enabled)&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
  if S.LightningBolt:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() == Enemies10yCount or S.FlameShockDebuff:AuraActiveCount() == 6) and Player:BuffUp(S.PrimordialWaveBuff) and Player:BuffStack(S.MaelstromWeaponBuff) >= (5 + 5 * num(S.OverflowingMaelstrom:IsAvailable())) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "Lightning Bolt aoe"; TiLightningBolt = 1; TiChainLightning = 0; end
  end
  -- actions.aoe+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5
  if S.ChainHarvest:IsCastable() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ChainHarvest)) then return "Chain Harvest aoe"; end
  end
  -- actions.aoe+=/sundering,if=(talent.doomwinds|runeforge.doom_winds.equipped)&(buff.doom_winds.up|buff.doom_winds_talent.up)
  if S.Sundering:IsReady() and (S.DoomWinds:IsAvailable() or DoomWindsEquipped) and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.DoomWinds)) then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "Sundering aoe (Doom Winds Buff)"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= Enemies10yCount)) then
    if Cast(S.FireNova) then return "Fire Nova aoe"; end
  end
  -- actions.aoe+=/primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies40y, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Covenant) then return "Primordial Wave aoe"; end
  end
  -- actions.aoe+=/windstrike,if=talent.thorims_invocation.enabled&ti_chain_lightning&buff.maelstrom_weapon.stack>1
  if S.Windstrike:IsReady() and S.ThorimsInvocation:IsAvailable() and TiChainLightning == 1 and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "Windstrike aoe"; end
  end
  -- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies&active_dot.flame_shock<6)
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, Enemies10y, "min", EvaluateTargetIfFilterLavaLash, EvaluateTargetIfLavaLash2, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash aoe"; end
  end
  -- actions.aoe+=/flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "Flame Shock aoe"; end
  end
  -- actions.aoe+=/flame_shock,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!talent.hailstorm.enabled&active_dot.flame_shock<active_enemies&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((not S.Hailstorm:IsAvailable()) and S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "Flame Shock aoe"; end
  end
  -- actions.aoe+=/ice_strike,if=talent.hailstorm.enabled
  if S.IceStrike:IsReady() and S.Hailstorm:IsAvailable() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "Ice Strike aoe"; end
  end
  -- actions.aoe+=/frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and S.Hailstorm:IsAvailable() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "Frost Shock aoe (Hailstorm Buff)"; end
  end
  -- actions.aoe+=/sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "Sundering aoe"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=4
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 4) then
    if Cast(S.FireNova) then return "Fire Nova aoe (4+ targets)"; end
  end
  -- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, Enemies10y, "min", EvaluateTargetIfFilterLavaLash, EvaluateTargetIfLavaLash, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash aoe"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "Fire Nova aoe (3+ targets)"; end
  end
  if (Player:BuffStack(S.MaelstromWeaponBuff) == 10) then
    -- actions.aoe+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=10&(!talent.crashing_storms.enabled|active_enemies<=3)
    if S.ElementalBlast:IsReady() and (not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and (not S.CrashingStorms:IsAvailable() or (Enemies40yCount <= 3)) then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "Elemental Blast aoe (Maelstrom Weapon Buff Stacks == 10)"; end
    end
    -- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack=10
    if S.ChainLightning:IsReady() then
      if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "Chain Lightning aoe (Maelstrom Weapon Buff Stacks == 10)"; TiLightningBolt = 0; TiChainLightning = 1; end
    end
  end
  -- actions.aoe+=/crash_lightning,if=buff.cl_crash_lightning.up
  if S.CrashLightning:IsReady() and Player:BuffUp(S.ClCrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "Crash Lightning aoe (Chain Lightning Buff)"; end
  end
  if Player:BuffUp(S.CrashLightningBuff) then
    -- actions.aoe+=/lava_lash,if=buff.crash_lightning.up&buff.ashen_catalyst.stack=8|buff.primal_lava_actuators.stack=8
    if S.LavaLash:IsReady() and ((Player:BuffStack(S.AshenCatalystBuff) == 8) or (Player:BuffStack(S.PrimalLavaActuatorsBuff) == 8) then
      if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash aoe (Ashen Catalyst / Primal Lava Actuator Buff)"; end
    end
    -- actions.aoe+=/windstrike,if=buff.crash_lightning.up
    if S.Windstrike:IsReady() then
     if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "Windstrike aoe (Crash Lightning Buff)"; end
    end
    -- actions.aoe+=/stormstrike,if=buff.crash_lightning.up&buff.gathering_storms.stack=6
    if S.Stormstrike:IsReady() and (Player:BuffStack(S.GatheringStorms) == 6) then
      if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "Stormstrike aoe (Gathering Storms Buff)"; end
    end
    -- actions.aoe+=/lava_lash,if=buff.crash_lightning.up
    if S.LavaLash:IsReady() then
      if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash aoe (Crash Lightning Buff)"; end
    end
    -- actions.aoe+=/ice_strike,if=buff.crash_lightning.up
    if S.IceStrike:IsReady() then
      if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "Ice Strike aoe (Crash Lightning Buff)"; end
    end
    -- actions.aoe+=/stormstrike,if=buff.crash_lightning.up
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsInMeleeRange(5)) then return "Stormstrike aoe (Crash Lightning Buff)"; end
    end
  end
  -- actions.aoe+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and (not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and (Player:BuffStack(S.MaelstromWeaponBuff) == 5) and (not S.CrashingStorms:IsAvailable() or (Enemies40yCount <= 3)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "Elemental Blast aoe (Maelstrom Weapon Stacks >= 5)"; end
  end
  -- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "Fire Nova aoe (2+ targets)"; end
  end
  -- actions.aoe+=/crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "Crash Lightning aoe"; end
  end
  -- actions.aoe+=/windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "Windstrike aoe"; end
  end
  -- actions.aoe+=/lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "Lava Lash aoe"; end
  end
  -- actions.aoe+=/ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "Ice Strike aoe"; end
  end
  -- actions.aoe+=/stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "Stormstrike aoe"; end
  end
  -- actions.aoe+=/flame_shock,target_if=refreshable,cycle_targets=1
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "Flame Shock aoe"; end
  end
  -- actions.aoe+=/frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "Frost Shock aoe"; end
  end
  -- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (Player:BuffStack(S.MaelstromWeaponBuff) >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "Chain Lightning aoe"; TiLightningBolt = 0; TiChainLightning = 1; end
  end
  -- actions.aoe+=/earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "Earth Elemental aoe"; end
  end
  -- actions.aoe+=/windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem aoe"; end
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
    Enemies10y = Player:GetEnemiesInMeleeRange(10)
    Enemies10yCount = #Enemies10y
  else
    Enemies40y = {}
    Enemies40yCount = 1
    Enemies10y = {}
    Enemies10yCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10y, false)
    end
  end

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

    -- actions=bloodlust,line_cd=600
    -- Note: Not adding this, as when to use Bloodlust will vary fight to fight

    -- actions+=/potion,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.hot_hand.enabled&buff.molten_weapon.up)|buff.icy_edge.up|(talent.stormflurry.enabled&buff.crackling_surge.up)|active_enemies>1|fight_remains<30
    if I.PotionofSpectralAgility:IsReady() and ((S.Ascendance:IsAvailable() and S.Ascendance:CooldownRemains() < 10) or (S.HotHand:IsAvailable() and Player:BuffUp(S.MoltenWeaponBuff)) or Player:BuffUp(S.IcyEdgeBuff) or (S.Stormflurry:IsAvailable() and Player:BuffUp(S.CracklingSurgeBuff)) or Enemies10yCount > 1 or FightRemains < 30) then
      if Cast(I.PotionofSpectralAgility, nil, Settings.Commons.DisplayStyle.Potions) then return "Potion main"; end
    end
    -- actions+=/auto_attack
    -- actions+=/heart_essence

    if (Settings.Commons.Enabled.Trinkets) and CDsON() then
      -- actions+=/use_item,name=the_first_sigil,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.hot_hand.enabled&buff.molten_weapon.up)|buff.icy_edge.up|(talent.stormflurry.enabled&buff.crackling_surge.up)|active_enemies>1|fight_remains<30
      if I.TheFirstSigil:IsEquippedAndReady() and ((S.Ascendance:IsAvailable() and S.Ascendance:CooldownRemains() < 10) or (S.HotHand:IsAvailable() and Player:BuffUp(S.MoltenWeaponBuff)) or Player:BuffUp(S.IcyEdgeBuff) or (S.Stormflurry:IsAvailable() and Player:BuffUp(S.CracklingSurgeBuff)) or Enemies10yCount > 1 or FightRemains < 30) then
        if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "The First Sigil main"; end
      end
      -- actions+=/use_item,name=cache_of_acquired_treasures,if=buff.acquired_sword.up|fight_remains<25
      if I.CacheofAcquiredTreasures:IsEquippedAndReady() and (Player:BuffUp(S.AcquiredSwordBuff) or FightRemains < 25) then
        if Cast(I.CacheofAcquiredTreasures, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Cache of Acquired Treasures main"; end
      end
      -- actions+=/use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<31|raid_event.adds.in<16|active_enemies>1
      if I.ScarsofFraternalStrife:IsEquippedAndReady() and (Player:BuffDown(S.ScarsofFraternalStrifeBuff4) or FightRemains < 31 or Enemies10yCount > 1) then
        if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Scars of Fraternal Strife main"; end
      end
      -- actions+=/use_items,slots=trinket1,if=!variable.trinket1_is_weird
      -- actions+=/use_items,slots=trinket2,if=!variable.trinket2_is_weird
      -- Note: These variables just exclude the above three trinkets from the generic use_items. We'll just use HR's OnUseExcludes instead.
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end

    if (CDsON()) then
      -- actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "Blood Fury racial"; end
      end
      -- actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "Berserking racial"; end
      end
      -- actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
    end
    -- actions+=/feral_spirit
    if S.FeralSpirit:IsCastable() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "Feral Spirit main"; end
    end
    -- actions+=/fae_transfusion,if=runeforge.seeds_of_rampant_growth.equipped|soulbind.grove_invigoration|soulbind.field_of_blossoms|active_enemies=1
    if S.FaeTransfusion:IsReady() and (SeedsofRampantGrowthEquipped or S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable() or Enemies10yCount == 1) then
      if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "Fae Transfusion main"; end
    end
    -- actions+=/vesper_totem,if=raid_event.adds.in>40|active_enemies>1
    if S.VesperTotem:IsReady() and Enemies10yCount > 1 then
      if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "Vesper Totem main"; end
    end
    -- actions+=/ascendance,if=(ti_lightning_bolt&active_enemies=1&raid_event.adds.in>=90)|(ti_chain_lightning&active_enemies>1)
    if CDsON() and S.Ascendance:IsCastable() and ((TiLightningBolt == 1 and Enemies40yCount == 1) or (TiChainLightning == 1 and Enemies40yCount > 1)) then
      if Cast(S.Ascendance, Settings.Enhancement.GCDasOffGCD.Ascendance) then return "Ascendance main"; end
    end
    -- actions+=/doom_winds,if=raid_event.adds.in>=90|active_enemies>1
    -- TODO some tests
    if CDsON() and S.DoomWinds:IsReady() then
      if Cast(S.DoomWinds, nil, nil, not Target:IsSpellInRange(S.DoomWinds)) then return "Doom Winds main"; end
    end
    -- actions+=/windfury_totem,if=runeforge.doom_winds.equipped&buff.doom_winds_debuff.down&(raid_event.adds.in>=60|active_enemies>1)
    -- Note: Added TimeSinceLastCast, as DoomWindsBuff has an internal CD of 60s
    if S.WindfuryTotem:IsReady() and (DoomWindsEquipped and Player:BuffDown(S.DoomWindsBuff) and S.WindfuryTotem:TimeSinceLastCast() > 60) then
      if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "Windfury Totem main (Doom Wind Equipped)"; end
    end

    -- call_action_list,name=single,if=active_enemies=1
    if Enemies10yCount < 2 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1
    if Enemies10yCount > 1 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FlameShockDebuff:RegisterAuraTracking()
  -- HR.Print("Enhancement Shaman rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(263, APL, Init)

-- SIMC APL
-- Update : 2022-10-27
-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/windfury_weapon
-- actions.precombat+=/flametongue_weapon
-- actions.precombat+=/lightning_shield
-- actions.precombat+=/windfury_totem,if=!runeforge.doom_winds.equipped
-- actions.precombat+=/fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
-- actions.precombat+=/variable,name=trinket1_is_weird,value=trinket.1.is.the_first_sigil|trinket.1.is.scars_of_fraternal_strife|trinket.1.is.cache_of_acquired_treasures
-- actions.precombat+=/variable,name=trinket2_is_weird,value=trinket.2.is.the_first_sigil|trinket.2.is.scars_of_fraternal_strife|trinket.2.is.cache_of_acquired_treasures
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- 
-- # Executed every time the actor is available.
-- actions=bloodlust,line_cd=600
-- actions+=/potion,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.hot_hand.enabled&buff.molten_weapon.up)|buff.icy_edge.up|(talent.stormflurry.enabled&buff.crackling_surge.up)|active_enemies>1|fight_remains<30
-- actions+=/auto_attack
-- actions+=/heart_essence
-- actions+=/use_item,name=the_first_sigil,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.hot_hand.enabled&buff.molten_weapon.up)|buff.icy_edge.up|(talent.stormflurry.enabled&buff.crackling_surge.up)|active_enemies>1|fight_remains<30
-- actions+=/use_item,name=cache_of_acquired_treasures,if=buff.acquired_sword.up|fight_remains<25
-- actions+=/use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<31|raid_event.adds.in<16|active_enemies>1
-- actions+=/use_items,slots=trinket1,if=!variable.trinket1_is_weird
-- actions+=/use_items,slots=trinket2,if=!variable.trinket2_is_weird
-- actions+=/blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
-- actions+=/berserking,if=!talent.ascendance.enabled|buff.ascendance.up
-- actions+=/fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
-- actions+=/ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
-- actions+=/feral_spirit
-- actions+=/fae_transfusion,if=runeforge.seeds_of_rampant_growth.equipped|soulbind.grove_invigoration|soulbind.field_of_blossoms|active_enemies=1
-- actions+=/vesper_totem,if=raid_event.adds.in>40|active_enemies>1
-- actions+=/ascendance,if=(ti_lightning_bolt&active_enemies=1&raid_event.adds.in>=90)|(ti_chain_lightning&active_enemies>1)
-- actions+=/doom_winds,if=raid_event.adds.in>=90|active_enemies>1
-- actions+=/windfury_totem,if=runeforge.doom_winds.equipped&buff.doom_winds_debuff.down&(raid_event.adds.in>=60|active_enemies>1)
-- # If_only_one_enemy,_priority_follows_the_'single'_action_list.
-- actions+=/call_action_list,name=single,if=active_enemies=1
-- # On_multiple_enemies,_the_priority_follows_the_'aoe'_action_list.
-- actions+=/call_action_list,name=aoe,if=active_enemies>1
-- 
-- # Multi target action priority list
-- actions.aoe=crash_lightning,if=(talent.doom_winds|runeforge.doom_winds.equipped)&(buff.doom_winds.up|buff.doom_winds_talent.up)
-- actions.aoe+=/lightning_bolt,if=(active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack>=(5+5*talent.overflowing_maelstrom.enabled)&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
-- actions.aoe+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5
-- actions.aoe+=/sundering,if=(talent.doomwinds|runeforge.doom_winds.equipped)&(buff.doom_winds.up|buff.doom_winds_talent.up)
-- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
-- actions.aoe+=/primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
-- actions.aoe+=/windstrike,if=talent.thorims_invocation.enabled&ti_chain_lightning&buff.maelstrom_weapon.stack>1
-- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies&active_dot.flame_shock<6)
-- actions.aoe+=/flame_shock,if=!ticking
-- actions.aoe+=/flame_shock,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!talent.hailstorm.enabled&active_dot.flame_shock<active_enemies&active_dot.flame_shock<6
-- actions.aoe+=/ice_strike,if=talent.hailstorm.enabled
-- actions.aoe+=/frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
-- actions.aoe+=/sundering
-- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=4
-- actions.aoe+=/lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
-- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=3
-- actions.aoe+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=10&(!talent.crashing_storms.enabled|active_enemies<=3)
-- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack=10
-- actions.aoe+=/crash_lightning,if=buff.cl_crash_lightning.up
-- actions.aoe+=/lava_lash,if=buff.crash_lightning.up&buff.ashen_catalyst.stack=8|buff.primal_lava_actuators.stack=8
-- actions.aoe+=/windstrike,if=buff.crash_lightning.up
-- actions.aoe+=/stormstrike,if=buff.crash_lightning.up&buff.gathering_storms.stack=6
-- actions.aoe+=/lava_lash,if=buff.crash_lightning.up
-- actions.aoe+=/ice_strike,if=buff.crash_lightning.up
-- actions.aoe+=/stormstrike,if=buff.crash_lightning.up
-- actions.aoe+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5&(!talent.crashing_storms.enabled|active_enemies<=3)
-- actions.aoe+=/fire_nova,if=active_dot.flame_shock>=2
-- actions.aoe+=/crash_lightning
-- actions.aoe+=/windstrike
-- actions.aoe+=/lava_lash
-- actions.aoe+=/ice_strike
-- actions.aoe+=/stormstrike
-- actions.aoe+=/flame_shock,target_if=refreshable,cycle_targets=1
-- actions.aoe+=/frost_shock
-- actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack>=5
-- actions.aoe+=/earth_elemental
-- actions.aoe+=/windfury_totem,if=buff.windfury_totem.remains<30
-- 
-- # Single target action priority list
-- actions.single=windstrike
-- actions.single+=/lava_lash,if=buff.hot_hand.up|buff.ashen_catalyst.stack=8|(runeforge.primal_lava_actuators.equipped&buff.primal_lava_actuators.stack=8)
-- actions.single+=/windfury_totem,if=!buff.windfury_totem.up
-- actions.single+=/stormstrike,if=buff.doom_winds.up|buff.doom_winds_talent.up
-- actions.single+=/crash_lightning,if=buff.doom_winds.up|buff.doom_winds_talent.up
-- actions.single+=/ice_strike,if=buff.doom_winds.up|buff.doom_winds_talent.up
-- actions.single+=/sundering,if=buff.doom_winds.up|buff.doom_winds_talent.up
-- actions.single+=/primordial_wave,if=buff.primordial_wave.down&(raid_event.adds.in>42|raid_event.adds.in<6)
-- actions.single+=/flame_shock,if=!ticking
-- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains&(!buff.splintered_elements.up|fight_remains<=12)
-- actions.single+=/ice_strike,if=talent.hailstorm.enabled
-- actions.single+=/frost_shock,if=buff.hailstorm.up
-- actions.single+=/lava_lash,if=dot.flame_shock.refreshable
-- actions.single+=/stormstrike,if=talent.stormflurry.enabled&buff.stormbringer.up
-- actions.single+=/elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5
-- actions.single+=/chain_harvest,if=buff.maelstrom_weapon.stack>=5&raid_event.adds.in>=90
-- actions.single+=/lava_burst,if=buff.maelstrom_weapon.stack>=5
-- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack=10&buff.primordial_wave.down
-- actions.single+=/stormstrike
-- actions.single+=/fleshcraft,interrupt=1,if=soulbind.volatile_solvent
-- actions.single+=/windfury_totem,if=buff.windfury_totem.remains<10
-- actions.single+=/ice_strike
-- actions.single+=/lava_lash
-- actions.single+=/bag_of_tricks
-- actions.single+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
-- actions.single+=/sundering,if=raid_event.adds.in>=40
-- actions.single+=/fire_nova,if=talent.swirling_maelstrom.enabled&active_dot.flame_shock
-- actions.single+=/frost_shock
-- actions.single+=/crash_lightning
-- actions.single+=/fire_nova,if=active_dot.flame_shock
-- actions.single+=/fleshcraft,if=soulbind.pustule_eruption
-- actions.single+=/earth_elemental
-- actions.single+=/flame_shock
-- actions.single+=/windfury_totem,if=buff.windfury_totem.remains<30
