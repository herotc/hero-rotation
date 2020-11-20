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

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local Enemies40y, Enemies40yCount, EnemiesCount10ySplash
local SEActive, FEActive

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateCycleLavaBurst200(TargetUnit)
  return (TargetUnit:DebuffUp(S.FlameShockDebuff))
end

local function EvaluateCycleFlameShock202(TargetUnit)
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff) <= Player:GCD() and (Player:BuffUp(S.LavaSurgeBuff) or Player:BloodlustDown()))
end

local function EvaluateCycleFlameShock204(TargetUnit)
  return ((TargetUnit:DebuffRemains(S.FlameShockDebuff) <= Player:GCD() or S.Ascendance:IsAvailable() and Target:DebuffRemains(S.FlameShockDebuff) < (S.Ascendance:CooldownRemains() + S.Ascendance:BaseDuration()) and S.Ascendance:CooldownRemains() < 4) and (Player:BuffUp(S.LavaSurgeBuff) or Player:BloodlustDown()))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- lightning_shield
  if S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) then
    if HR.Cast(S.LightningShield) then return "lightning_shield precombat"; end
  end
  -- potion
  -- snapshot_stats
  -- Manually added: flame_shock
  if S.FlameShock:IsReady() and Target:DebuffDown(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock precombat"; end
  end
end

local function Aoe()
  -- earthquake,if=buff.echoing_shock.up
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoingShockBuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake aoe"; end
  end
  -- chain_harvest TODO
  -- stormkeeper,if=talent.stormkeeper.enabled
  if S.Stormkeeper:IsCastable() and not Player:IsCasting(S.Stormkeeper) then
    if HR.Cast(S.Stormkeeper) then return "Stormkeeper 1"; end
  end
  -- flame_shock,if=active_dot.flame_shock<3&active_enemies<=5,target_if=refreshable
  if S.FlameShock:IsReady() and (EnemiesCount10ySplash <= 5) then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 1"; end
  end
  -- flame_shock,if=!active_dot.flame_shock
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled&maelstrom>=60
  if S.EchoingShock:IsReady() and (Player:Maelstrom() >= 60) then
    if HR.Cast(S.EchoingShock) then return "EchoingShock 1"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(!pet.storm_elemental.active)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and (SEActive and (not S.Icefury:IsAvailable() or not Player:BuffUp(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance, Settings.Elemental.GCDasOffGCD.Ascendance) then return "ascendance aoe"; end
  end
  -- liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsReady() then
    if HR.Cast(S.LiquidMagmaTotem) then return "LiquidMagmaTotem 1"; end
  end
  -- earth_shock,if=runeforge.echoes_of_great_sundering.equipped&!buff.echoes_of_great_sundering.up TODO
  -- earth_elemental,if=runeforge.deeptremor_stone.equipped&(!talent.primal_elementalist.enabled|(!pet.storm_elemental.active&!pet.fire_elemental.active)) TODO
  -- lavaburst,target_if=dot.flame_shock.remains,if=spell_targets.chain_lightning<4|buff.lava_surge.up|(talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&maelstrom>=60)
  if S.LavaBurst:IsReady() and (EnemiesCount10ySplash < 4 or Player:BuffUp(S.LavaSurgeBuff) or (S.MasterOfTheElements:IsAvailable() and Player:BuffDown(S.MasterOfTheElementsBuff) and Player:Maelstrom() >= 60)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies40y, EvaluateCycleLavaBurst200, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe"; end
  end
  -- earthquake,if=!talent.master_of_the_elements.enabled|buff.stormkeeper.up|maelstrom>=(100-4*spell_targets.chain_lightning)|buff.master_of_the_elements.up|spell_targets.chain_lightning>3
  if S.Earthquake:IsReady() and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.StormkeeperBuff) or Player:Maelstrom() >= (100 - 4 * EnemiesCount10ySplash) or Player:BuffUp(S.MasterOfTheElementsBuff) or EnemiesCount10ySplash > 3) then
    if HR.Cast(S.Earthquake) then return "Earthquake 1"; end
  end
  -- chain_lightning,if=buff.stormkeeper.remains<3*gcd*buff.stormkeeper.stack
  if S.ChainLightning:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 3 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff)) then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe"; end
  end
  -- lava_burst,if=buff.lava_surge.up&spell_targets.chain_lightning<4&(!pet.storm_elemental.active)&dot.flame_shock.ticking
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and EnemiesCount10ySplash < 4 and SEActive and Target:DebuffUp(S.FlameShockDebuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "LavaBurst 1"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled&spell_targets.chain_lightning<5&(!pet.storm_elemental.active)
  if S.ElementalBlast:IsReady() and (EnemiesCount10ySplash < 5 and SEActive) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe"; end
  end
  -- lava_beam,if=talent.ascendance.enabled
  if S.LavaBeam:IsReady() then
    if HR.Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsReady() then
    if HR.Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "ChainLightning 1"; end
  end
  -- lava_burst,moving=1,if=buff.lava_surge.up&cooldown_react
  if S.LavaBurst:IsReady() and Player:IsMoving() and (Player:BuffUp(S.LavaSurgeBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsReady() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 2"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsReady() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "FrostShock 1"; end
  end
end

local function SESingle()
  -- flame_shock,target_if=(remains<=gcd)&(buff.lava_surge.up|!buff.bloodlust.up)
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock202, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock ses"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&(cooldown.lava_burst.remains>0)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and ((HL.CombatTime() >= 60 or Player:BloodlustUp()) and S.LavaBurst:CooldownRemains() > 0 and (not S.Icefury:IsAvailable() or Player:BuffDown(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance) then return "ascendance ses"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled
  if S.ElementalBlast:IsReady() then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast ses"; end
  end
  -- stormkeeper,if=talent.stormkeeper.enabled&(maelstrom<44)
  if S.Stormkeeper:IsCastable() and (Player:Maelstrom() < 44) then
    if HR.Cast(S.Stormkeeper) then return "stormkeeper ses"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled
  if S.EchoingShock:IsReady() then
    if HR.Cast(S.EchoingShock, nil, nil, not Target:IsSpellInRange(S.EchoingShock)) then return "echoing_shock ses"; end
  end
  -- lava_burst,if=buff.wind_gust.stack<18|buff.lava_surge.up
  if S.LavaBurst:IsReady() and (Player:BuffStack(S.WindGustBuff) < 18 or Player:BuffUp(S.LavaSurgeBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.StormkeeperBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesoftheGreatSunderingBuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake ses"; end
  end
  -- earthquake,if=(spell_targets.chain_lightning>1)&(!dot.flame_shock.refreshable)
  if S.Earthquake:IsReady() and (EnemiesCount10ySplash > 1 and not Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if HR.Cast(S.Earthquake) then return "earthquake ses"; end
  end
  -- earth_shock,if=spell_targets.chain_lightning<2&maelstrom>=60&(buff.wind_gust.stack<20|maelstrom>90)
  if S.EarthShock:IsReady() and (EnemiesCount10ySplash < 2 and Player:Maelstrom() >= 60 and (Player:BuffStack(S.WindGustBuff) < 20 or Player:Maelstrom() > 90)) then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock ses"; end
  end
  -- lightning_bolt,if=(buff.stormkeeper.remains<1.1*gcd*buff.stormkeeper.stack|buff.stormkeeper.up&buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff) or Player:BuffUp(S.StormkeeperBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses"; end
  end
  -- frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and S.MasterOfTheElements:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses"; end
  end
  -- lava_burst,if=buff.ascendance.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.AscendanceBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses"; end
  end
  -- lava_burst,if=cooldown_react&!talent.master_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and not S.MasterOfTheElements:IsAvailable()) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses"; end
  end
  -- icefury,if=talent.icefury.enabled&!(maelstrom>75&cooldown.lava_burst.remains<=0)
  if S.Icefury:IsReady() and not Player:IsCasting(S.IceFury) and (not (Player:Maelstrom() > 75 and S.LavaBurst:CooldownUp())) then
    if HR.Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury ses"; end
  end
  -- lava_burst,if=cooldown_react&charges>talent.echo_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and S.LavaBurst:Charges() > num(S.EchoOfTheElements:IsAvailable())) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst ses"; end
  end
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.IcefuryBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses"; end
  end
  -- chain_harvest TODO
  -- static_discharge,if=talent.static_discharge.enabled
  if S.StaticDischarge:IsReady() then
    if HR.Cast(S.StaticDischarge, nil, nil, not Target:IsSpellInRange(S.StaticDischarge)) then return "static_discharge ses"; end
  end
  -- earth_elemental,if=!talent.primal_elementalist.enabled|talent.primal_elementalist.enabled&(!pet.storm_elemental.active)
  if S.EarthElemental:IsCastable() and (not S.PrimalElementalist:IsAvailable() or S.PrimalElementalist:IsAvailable() and not SEActive) then
    if HR.Cast(S.EarthElemental) then return "earth_elemental ses"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsReady() then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt ses"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsReady() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShockDebuff) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock ses"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsReady() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock ses"; end
  end
end

local function Single()
  -- flame_shock,target_if=(!ticking|dot.flame_shock.remains<=gcd|talent.ascendance.enabled&dot.flame_shock.remains<(cooldown.ascendance.remains+buff.ascendance.duration)&cooldown.ascendance.remains<4)&(buff.lava_surge.up|!buff.bloodlust.up)
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies40y, EvaluateCycleFlameShock204, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single"; end
  end
  -- ascendance,if=talent.ascendance.enabled&(time>=60|buff.bloodlust.up)&(cooldown.lava_burst.remains>0)&(!talent.icefury.enabled|!buff.icefury.up&!cooldown.icefury.up)
  if S.Ascendance:IsCastable() and ((HL.CombatTime() >= 60 or Player:BloodlustUp()) and S.LavaBurst:CooldownRemains() > 0 and (not S.Icefury:IsAvailable() or Player:BuffDown(S.IcefuryBuff) and not S.Icefury:CooldownUp())) then
    if HR.Cast(S.Ascendance) then return "ascendance single"; end
  end
  -- elemental_blast,if=talent.elemental_blast.enabled&(talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up&maelstrom<60|!buff.master_of_the_elements.up)|!talent.master_of_the_elements.enabled)
  if S.ElementalBlast:IsReady() and (S.MasterOfTheElements:IsAvailable() and (Player:BuffUp(S.MasterOfTheElementsBuff) and Player:Maelstrom() < 60 or Player:BuffDown(S.MasterOfTheElementsBuff)) or not S.MasterOfTheElements:IsAvailable()) then
    if HR.Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single"; end
  end
  -- stormkeeper,if=talent.stormkeeper.enabled&(raid_event.adds.count<3|raid_event.adds.in>50)&(maelstrom<44)
  if S.Stormkeeper:IsCastable() and not Player:IsCasting(S.Stormkeeper) and (Player:Maelstrom() < 44) then
    if HR.Cast(S.Stormkeeper) then return "stormkeeper single"; end
  end
  -- echoing_shock,if=talent.echoing_shock.enabled&cooldown.lava_burst.remains<=0
  if S.EchoingShock:IsReady() and (S.LavaBurst:CooldownUp()) then
    if HR.Cast(S.EchoingShock, nil, nil, not Target:IsSpellInRange(S.EchoingShock)) then return "echoing_shock single"; end
  end
  -- lava_burst,if=talent.echoing_shock.enabled&buff.echoing_shock.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.EchoingShockBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single"; end
  end
  -- liquid_magma_totem,if=talent.liquid_magma_totem.enabled
  if S.LiquidMagmaTotem:IsReady() then
    if HR.Cast(S.LiquidMagmaTotem) then return "LiquidMagmaTotem 2"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&spell_targets.chain_lightning<2&(buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffUp(S.StormkeeperBuff) and EnemiesCount10ySplash < 2 and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up)
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesoftheGreatSunderingBuff) and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.MasterOfTheElementsBuff))) then
    if HR.Cast(S.Earthquake) then return "earthquake single"; end
  end
  -- earthquake,if=(spell_targets.chain_lightning>1)&(!dot.flame_shock.refreshable)&(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up|cooldown.lava_burst.remains>0&maelstrom>=92)
  if S.Earthquake:IsReady() and (EnemiesCount10ySplash > 1 and not Target:DebuffRefreshable(S.FlameShockDebuff) and (not S.MasterOfTheElements:IsAvailable() or Player:BuffUp(S.MasterOfTheElementsBuff) or S.LavaBurst:CooldownRemains() > 0 and Player:Maelstrom() >= 92)) then
    if HR.Cast(S.Earthquake) then return "earthquake single"; end
  end
  -- earth_shock,if=talent.master_of_the_elements.enabled&(buff.master_of_the_elements.up|cooldown.lava_burst.remains>0&maelstrom>=92|spell_targets.chain_lightning<2&buff.stormkeeper.up&cooldown.lava_burst.remains<=gcd)|!talent.master_of_the_elements.enabled
  if S.EarthShock:IsReady() and (S.MasterOfTheElements:IsAvailable() and (Player:BuffUp(S.MasterOfTheElementsBuff) or S.LavaBurst:CooldownRemains() > 0 and Player:Maelstrom() >= 92 or EnemiesCount10ySplash < 2 and Player:BuffUp(S.StormkeeperBuff) and S.LavaBurst:CooldownRemains() <= Player:GCD()) or not S.MasterOfTheElements:IsAvailable()) then
    if HR.Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single"; end
  end
  -- lightning_bolt,if=(buff.stormkeeper.remains<1.1*gcd*buff.stormkeeper.stack|buff.stormkeeper.up&buff.master_of_the_elements.up)
  if S.LightningBolt:IsReady() and (Player:BuffRemains(S.StormkeeperBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.StormkeeperBuff) or Player:BuffUp(S.StormkeeperBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single"; end
  end
  -- frost_shock,if=talent.icefury.enabled&talent.master_of_the_elements.enabled&buff.icefury.up&buff.master_of_the_elements.up
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and S.MasterOfTheElements:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffUp(S.MasterOfTheElementsBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single"; end
  end
  -- lava_burst,if=buff.ascendance.up
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.AscendanceBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single"; end
  end
  -- lava_burst,if=cooldown_react&!talent.master_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and not S.MasterOfTheElements:IsAvailable()) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single"; end
  end
  -- icefury,if=talent.icefury.enabled&!(maelstrom>75&cooldown.lava_burst.remains<=0)
  if S.Icefury:IsReady() and not Player:IsCasting(S.IceFury) and (not (Player:Maelstrom() > 75 and S.LavaBurst:CooldownUp())) then
    if HR.Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single"; end
  end
  -- lava_burst,if=cooldown_react&charges>talent.echo_of_the_elements.enabled
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff) and S.LavaBurst:Charges() > num(S.EchoOfTheElements:IsAvailable())) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single"; end
  end
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up&buff.icefury.remains<1.1*gcd*buff.icefury.stack
  if S.FrostShock:IsReady() and (S.Icefury:IsAvailable() and Player:BuffUp(S.IcefuryBuff) and Player:BuffRemains(S.IcefuryBuff) < 1.1 * Player:GCD() * Player:BuffStack(S.IcefuryBuff)) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single"; end
  end
  -- lava_burst,if=cooldown_react
  if S.LavaBurst:IsReady() and (Player:BuffUp(S.LavaSurgeBuff)) then
    if HR.Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single"; end
  end
  -- flame_shock,target_if=refreshable
  if S.FlameShock:IsReady() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single"; end
  end
  -- earthquake,if=spell_targets.chain_lightning>1&!runeforge.echoes_of_great_sundering.equipped|(buff.echoes_of_great_sundering.up&buff.master_of_the_elements.up) TODO
  -- frost_shock,if=talent.icefury.enabled&buff.icefury.up&(buff.icefury.remains<gcd*4*buff.icefury.stack|buff.stormkeeper.up|!talent.master_of_the_elements.enabled)
  if S.FrostShock:IsReady() and (Player:BuffUp(S.IcefuryBuff) and (Player:BuffRemains(S.IcefuryBuff) < Player:GCD() * 4 * Player:BuffStack(S.IcefuryBuff) or Player:BuffUp(S.StormkeeperBuff) or not S.MasterOfTheElements:IsAvailable())) then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single"; end
  end
  -- frost_shock,if=runeforge.elemental_equilibrium.equipped&!buff.elemental_equilibrium_debuff.up&!talent.elemental_blast.enabled&!talent.echoing_shock.enabled TODO
  -- chain_harvest TODO
  -- static_discharge,if=talent.static_discharge.enabled
  if S.StaticDischarge:IsReady() then
    if HR.Cast(S.StaticDischarge) then return "static_discharge single"; end
  end
  -- earth_elemental,if=!talent.primal_elementalist.enabled|!pet.fire_elemental.active
  if S.EarthElemental:IsCastable() and (not S.PrimalElementalist:IsAvailable() or not FEActive) then
    if HR.Cast(S.EarthElemental) then return "earth_elemental single"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsReady() then
    if HR.Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "LightningBolt 1"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() and Player:IsMoving() and Target:DebuffRefreshable(S.FlameShock) then
    if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 5"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if HR.Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "FrostShock 1"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
    Enemies40yCount = #Enemies40y
  else
    EnemiesCount10ySplash = 1
    Enemies40yCount = 1
  end
  
  SEActive = (S.StormElemental:IsAvailable() and S.StormElemental:CooldownRemains() < S.StormElemental:Cooldown() - 30)
  FEActive = (not S.StormElemental:IsAvailable() and S.FireElemental:CooldownRemains() < S.FireElemental:Cooldown() - 30)

  -- In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.Disrupt, false); if ShouldReturn then return ShouldReturn; end
    -- use_items
    local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
    -- flame_shock,if=!ticking
    if S.FlameShock:IsCastable() and Target:DebuffDown(S.FlameShock) then
      if HR.Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "FlameShock 3"; end
    end
    if CDsON() then
      -- fire_elemental
      if S.FireElemental:IsCastable() then
        if HR.Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "FireElemental 1"; end
      end
      -- storm_elemental
      if S.StormElemental:IsCastable() then
        if HR.Cast(S.StormElemental) then return "StormElemental 1"; end
      end
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial 1"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.BloodFury:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial 2"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial 3"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and ( not S.Ascendance:IsAvailable() or Player:BuffUp(S.Ascendance) or S.Ascendance:CooldownRemains() > 50 ) then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial 4"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and ( not S.Ascendance:IsAvailable() or not Player:BuffUp(S.Ascendance) ) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:SpellInRange(S.BagofTricks)) then return "bag_of_tricks racial 5"; end
      end
    end
    -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up TODO
    -- vesper_totem,if=covenant.kyrian TODO
    -- fae_transfusion,if=covenant.night_fae TODO
    -- run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if EnemiesCount10ySplash > 2 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target,if=!talent.storm_elemental.enabled&active_enemies<=2
    if not S.StormElemental:IsAvailable() and EnemiesCount10ySplash <= 2 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=se_single_target,if=talent.storm_elemental.enabled&active_enemies<=2
    if S.StormElemental:IsAvailable() and EnemiesCount10ySplash <= 2 then
      local ShouldReturn = SESingle(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(262, APL, Init)
