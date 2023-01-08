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
local Pet        = Unit.Pet
local Target     = Unit.Target
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Elemental
local I = Item.Shaman.Elemental

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.TrinketName:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

HL:RegisterForEvent(function()
  S.PrimordialWave:RegisterInFlightEffect(327162)
  S.PrimordialWave:RegisterInFlight()
  S.LavaBurst:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.PrimordialWave:RegisterInFlightEffect(327162)
S.PrimordialWave:RegisterInFlight()
S.LavaBurst:RegisterInFlight()

-- Rotation Variables
local BossFightRemains = 11111
local FightRemains = 11111
local Enemies40y, Enemies10ySplash
Shaman.Targets = 0
Shaman.ClusterTargets = 0

-- Some spells aren't castable while moving or if you're currently casting them, so we handle that behavior here.
-- Additionally, lavaburst isn't castable without a charge or a proc.
local function IsViable(spell)
  if spell == nil then
    return nil
  end
  local BaseCheck = spell:IsReady()
  if spell == S.Stormkeeper or spell == S.ElementalBlast or spell == S.Icefury then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.SpiritwalkersGraceBuff))
    return BaseCheck and MovementPredicate and not Player:IsCasting(spell)
  elseif spell == S.LavaBeam then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.SpiritwalkersGraceBuff))
    return BaseCheck and MovementPredicate
  elseif spell == S.LightningBolt or spell == S.ChainLightning then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.StormkeeperBuff) or Player:BuffUp(S.SpiritwalkersGraceBuff))
    return BaseCheck and MovementPredicate
  elseif spell == S.LavaBurst then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.LavaSurgeBuff) or Player:BuffUp(S.SpiritwalkersGraceBuff))
    local a = Player:BuffUp(S.LavaSurgeBuff)
    local b = (not Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() >= 1)
    local c = (Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() == 2)
    -- d) TODO: you are casting something else, but you will have >= 1 charge at the end of the cast of the spell
    --    Implementing d) will require something like LavaBurstChargesFractionalP(); this is not hard but I haven't done it.
    return BaseCheck and MovementPredicate and (a or b or c)
  elseif spell == S.PrimordialWave then
    return BaseCheck and not Player:BuffUp(S.PrimordialWaveBuff) and not Player:BuffUp(S.LavaSurgeBuff)
  else
    return BaseCheck
  end
end

local function EvaluateFlameShockRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateFlameShockRemains(TargetUnit)
  -- target_if=min:dot.flame_shock.remains
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff))
end

local function EvaluateFlameShockRemains2(TargetUnit)
  -- target_if=dot.flame_shock.remains>2
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff) > 2)
end

local function EvaluateLightningRodRemains(TargetUnit)
  -- target_if=min:debuff.lightning_rod.remains
  return (TargetUnit:DebuffRemains(S.LightningRodDebuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- flametongue_weapon,if=talent.imporved_flametongue_weapon.enabled
  -- potion
  -- Note: Skipping potion precombat, as that's not necessarily optimal
  -- Manually added: Opener abilities
  if IsViable(S.Stormkeeper) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  if IsViable(S.ElementalBlast) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast precombat 4"; end
  end
  if Player:IsCasting(S.ElementalBlast) and IsViable(S.PrimordialWave) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 6"; end
  end
  if Player:IsCasting(S.ElementalBlast) and (not IsViable(S.PrimordialWave)) and S.FlameShock:IsReady() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flameshock precombat 8"; end
  end
  if IsViable(S.LavaBurst) and (not Player:IsCasting(S.LavaBurst)) and ((not S.ElementalBlast:IsAvailable()) or (S.ElementalBlast:IsAvailable() and not IsViable(S.ElementalBlast))) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lavaburst precombat 10"; end
  end
  if Player:IsCasting(S.LavaBurst) and S.FlameShock:IsReady() then 
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flameshock precombat 12"; end
  end
  if Player:IsCasting(S.LavaBurst) and IsViable(S.PrimordialWave) then
    if Cast(S.PrimordialWave, nil, nil, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 14"; end
  end
end

local function Aoe()
  -- fire_elemental
  if S.FireElemental:IsCastable() then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental aoe 2"; end
  end
  -- storm_elemental
  if S.StormElemental:IsCastable() then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental aoe 4"; end
  end
  -- stormkeeper,if=!buff.stormkeeper.up
  if IsViable(S.Stormkeeper) and (not Player:StormkeeperP()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper aoe 6"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&buff.surge_of_power.up&!buff.splintered_elements.up
  if IsViable(S.PrimordialWave) and (Player:BuffDown(S.PrimordialWaveBuff) and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 8"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&!buff.splintered_elements.up
  if IsViable(S.PrimordialWave) and (Player:BuffDown(S.PrimordialWaveBuff) and S.DeeplyRootedElements:IsAvailable() and (not S.SurgeofPower:IsAvailable()) and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled
  if IsViable(S.PrimordialWave) and (Player:BuffDown(S.PrimordialWaveBuff) and S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 12"; end
  end
  -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&(!talent.lightning_rod.enabled|talent.skybreakers_fiery_demise.enabled)
  if S.FlameShock:IsCastable() and (Player:BuffUp(S.SurgeofPowerBuff) and ((not S.LightningRod:IsAvailable()) or S.SkybreakersFieryDemise:IsAvailable())) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 14"; end
  end
  -- flame_shock,target_if=refreshable,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled
  if S.FlameShock:IsCastable() and (S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 16"; end
  end
  -- flame_shock,target_if=refreshable,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled
  if S.FlameShock:IsCastable() and (S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 18"; end
  end
  -- ascendance
  if S.Ascendance:IsCastable() then
    if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance aoe 20"; end
  end
  -- liquid_magma_totem
  if S.LiquidMagmaTotem:IsCastable() then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem aoe 22"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(maelstrom>=60-5*talent.eye_of_the_storm.rank-2*talent.flow_of_power.enabled)&(!talent.echoes_of_great_sundering.enabled|buff.echoes_of_great_sundering.up)&(!buff.ascendance.up&active_enemies>3&talent.unrelenting_calamity.enabled|active_enemies>3&!talent.unrelenting_calamity.enabled|active_enemies=3)
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.LavaSurgeBuff) and S.MasteroftheElements:IsAvailable() and (not Player:MOTEP()) and (Player:MaelstromP() >= 60 - 5 * S.EyeoftheStorm:TalentRank() - 2 * num(S.FlowofPower:IsAvailable())) and ((not S.EchoesofGreatSundering:IsAvailable()) or Player:BuffUp(S.EchoesofGreatSunderingBuff)) and (Player:BuffDown(S.AscendanceBuff) and Shaman.Targets > 3 and S.UnrelentingCalamity:IsAvailable() or Shaman.Targets > 3 and (not S.UnrelentingCalamity:IsAvailable()) or Shaman.Targets == 3)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 24"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&active_enemies>3&(spell_targets.chain_lightning>3|spell_targets.lava_beam>3)
  if S.Earthquake:IsReady() and ((not S.EchoesofGreatSundering:IsAvailable()) and Shaman.Targets > 3 and Shaman.ClusterTargets > 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 26"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled&active_enemies=3&(spell_targets.chain_lightning=3|spell_targets.lava_beam=3)
  if S.Earthquake:IsReady() and ((not S.EchoesofGreatSundering:IsAvailable()) and (not S.ElementalBlast:IsAvailable()) and Shaman.Targets == 3 and Shaman.ClusterTargets == 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 28"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 30"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if IsViable(S.ElementalBlast) and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 32"; end
  end
  -- elemental_blast,if=talent.echoes_of_great_sundering.enabled
  if IsViable(S.ElementalBlast) and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 34"; end
  end
  -- elemental_blast,if=enemies=3&!talent.echoes_of_great_sundering.enabled
  if IsViable(S.ElementalBlast) and (Shaman.Targets == 3 and not S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 36"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 38"; end
  end
  -- earth_shock,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 40"; end
  end
  -- lava_beam,if=buff.stormkeeper.up
  if IsViable(S.LavaBeam) and (Player:StormkeeperP()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 42"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if IsViable(S.ChainLightning) and (Player:StormkeeperP()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 44"; end
  end
  -- lava_beam,if=buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time
  if IsViable(S.LavaBeam) and (Player:BuffUp(S.PoweroftheMaelstromBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 46"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up
  if IsViable(S.ChainLightning) and (Player:BuffUp(S.PoweroftheMaelstromBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 48"; end
  end
  -- lava_beam,if=active_enemies>=6&buff.surge_of_power.up&buff.ascendance.remains>cast_time
  if IsViable(S.LavaBeam) and (Shaman.Targets >= 6 and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 50"; end
  end
  -- chain_lightning,if=active_enemies>=6&buff.surge_of_power.up
  if IsViable(S.ChainLightning) and (Shaman.Targets >= 6 and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 52"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=buff.lava_surge.up&talent.deeply_rooted_elements.enabled&buff.windspeakers_lava_resurgence.up
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.LavaSurgeBuff) and S.DeeplyRootedElements:IsAvailable() and Player:BuffUp(S.WindspeakersLavaResurgenceBuff)) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 54"; end
  end
  -- lava_beam,if=buff.master_of_the_elements.up&buff.ascendance.remains>cast_time
  if IsViable(S.LavaBeam) and (Player:MOTEP() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 56"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=enemies=3&talent.master_of_the_elements.enabled
  if IsViable(S.LavaBurst) and (Shaman.Targets == 3 and S.MasteroftheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 58"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=buff.lava_surge.up&talent.deeply_rooted_elements.enabled
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.LavaSurgeBuff) and S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 60"; end
  end
  -- icefury,if=talent.electrified_shocks.enabled&active_enemies<5
  if IsViable(S.Icefury) and (S.ElectrifiedShocks:IsAvailable() and Shaman.Targets < 5) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 62"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&!debuff.electrified_shocks.up&active_enemies<5
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and Target:DebuffDown(S.ElectrifiedShocksDebuff) and Shaman.Targets < 5) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 64"; end
  end
  -- lava_beam,if=buff.ascendance.remains>cast_time
  if IsViable(S.LavaBeam) and (Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 66"; end
  end
  -- chain_lightning
  if IsViable(S.ChainLightning) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 68"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock moving aoe 70"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 72"; end
  end
end

local function SingleTarget()
  -- fire_elemental
  if S.FireElemental:IsCastable() then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental single_target 2"; end
  end
  -- storm_elemental
  if S.StormElemental:IsCastable() then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental single_target 4"; end
  end
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>45
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 45) then
    if Cast(S.TotemicRecall, Settings.Commons.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_target 6"; end
  end
  -- liquid_magma_totem
  if S.LiquidMagmaTotem:IsCastable() then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 8"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&!buff.splintered_elements.up
  if IsViable(S.PrimordialWave) and (Player:BuffDown(S.PrimordialWaveBuff) and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave single_target 10"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies=1&refreshable&!buff.surge_of_power.up
  if S.FlameShock:IsCastable() and (Shaman.Targets == 1 and Player:BuffDown(S.SurgeofPowerBuff)) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateFlameShockRemains, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 12"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&refreshable&!buff.surge_of_power.up&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled),cycle_targets=1
  if S.FlameShock:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:BuffDown(S.SurgeofPowerBuff) and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable())) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateFlameShockRemains, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 14"; end
  end
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up
  if IsViable(S.Stormkeeper) and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperP()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 16"; end
  end
  -- ascendance,if=!buff.stormkeeper.up
  if S.Ascendance:IsCastable() and (not Player:StormkeeperP()) then
    if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance single_target 18"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&buff.surge_of_power.up
  if IsViable(S.LightningBolt) and (Player:StormkeeperP() and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 20"; end
  end
  -- lava_beam,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if S.LavaBeam:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:StormkeeperP() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 22"; end
  end
  -- chain_lightning,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if IsViable(S.ChainLightning) and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:StormkeeperP() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 24"; end
  end
  -- lava_burst,if=buff.stormkeeper.up&!buff.master_of_the_elements.up&!talent.surge_of_power.enabled&talent.master_of_the_elements.enabled
  if IsViable(S.LavaBurst) and (Player:StormkeeperP() and (not Player:MOTEP()) and (not S.SurgeofPower:IsAvailable()) and S.MasteroftheElements:IsAvailable()) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 25"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&buff.master_of_the_elements.up
  if IsViable(S.LightningBolt) and (Player:StormkeeperP() and (not S.SurgeofPower:IsAvailable()) and Player:MOTEP()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 26"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&!talent.master_of_the_elements.enabled
  if IsViable(S.LightningBolt) and (Player:StormkeeperP() and (not S.SurgeofPower:IsAvailable()) and not S.MasteroftheElements:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 27"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up
  if IsViable(S.LightningBolt) and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 28"; end
  end
  -- icefury,if=talent.electrified_shocks.enabled
  if IsViable(S.Icefury) and (S.ElectrifiedShocks:IsAvailable()) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 30"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&(!debuff.electrified_shocks.up|buff.icefury.remains<=gcd)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and (Target:DebuffDown(S.ElectrifiedShocksDebuff) or Player:BuffRemains(S.IcefuryBuff) <= Player:GCD())) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 32"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&maelstrom>=50&debuff.electrified_shocks.remains<2*gcd&buff.stormkeeper.up
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and Player:MaelstromP() >= 50 and Target:DebuffRemains(S.ElectrifiedShocksDebuff) < 2 * Player:GCD() and Player:StormkeeperP()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 34"; end
  end
  -- lava_beam,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:BuffUp(S.PoweroftheMaelstromBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 36"; end
  end
  -- lava_burst,if=buff.windspeakers_lava_resurgence.up
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.WindspeakersLavaResurgenceBuff)) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 38"; end
  end
  -- lava_burst,if=cooldown_react&buff.lava_surge.up
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.LavaSurgeBuff)) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 40"; end
  end
  -- lava_burst,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&maelstrom>=50&!talent.swelling_maelstrom.enabled&maelstrom<=80
  if IsViable(S.LavaBurst) and (S.MasteroftheElements:IsAvailable() and (not Player:MOTEP()) and Player:MaelstromP() >= 50 and (not S.SwellingMaelstrom:IsAvailable()) and Player:MaelstromP() <= 80) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 41"; end
  end
  -- lava_burst,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&maelstrom>=50&talent.swelling_maelstrom.enabled&maelstrom<=130
  if IsViable(S.LavaBurst) and (S.MasteroftheElements:IsAvailable() and (not Player:MOTEP()) and Player:MaelstromP() >= 50 and S.SwellingMaelstrom:IsAvailable() and Player:MaelstromP() <= 130) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 42"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering.up&(!talent.elemental_blast.enabled&active_enemies<2|active_enemies>1)
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and ((not S.ElementalBlast:IsAvailable()) and Shaman.Targets < 2 or Shaman.Targets > 1)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 43"; end
  end
  -- earthquake,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled
  if S.Earthquake:IsReady() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and (not S.EchoesofGreatSundering:IsAvailable()) and not S.ElementalBlast:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 44"; end
  end
  -- elemental_blast
  if IsViable(S.ElementalBlast) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 46"; end
  end
  -- earth_shock
  if S.EarthShock:IsReady() then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 48"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.flux_melting.up&active_enemies>1
  if IsViable(S.LavaBurst) and (Player:BuffUp(S.FluxMeltingBuff) and Shaman.Targets > 1) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 50"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=enemies=1&talent.deeply_rooted_elements.enabled
  if IsViable(S.LavaBurst) and (Shaman.Targets == 1 and S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 52"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.flux_melting.enabled&!buff.flux_melting.up
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.FluxMelting:IsAvailable() and Player:BuffDown(S.FluxMeltingBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 54"; end
  end
  -- frost_shock,if=buff.icefury.up&(talent.electrified_shocks.enabled&!debuff.electrified_shocks.up|buff.icefury.remains<6)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and (S.ElectrifiedShocks:IsAvailable() and Target:DebuffDown(S.ElectrifiedShocksDebuff) or Player:BuffRemains(S.IcefuryBuff) < 6)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 56"; end
  end
  -- lightning_bolt,if=buff.power_of_the_maelstrom.up&talent.unrelenting_calamity.enabled
  if IsViable(S.LightningBolt) and (Player:BuffUp(S.PoweroftheMaelstromBuff) and S.UnrelentingCalamity:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 58"; end
  end
  -- icefury
  if IsViable(S.Icefury) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 60"; end
  end
  -- lightning_bolt,if=pet.storm_elemental.active&debuff.lightning_rod.up&(debuff.electrified_shocks.up|buff.power_of_the_maelstrom.up)
  if IsViable(S.LightningBolt) and (Pet:IsActive() and Pet:Name() == "Primal Storm Elemental" and Target:DebuffUp(S.LightningRodDebuff) and (Target:DebuffUp(S.ElectrifiedShocksDebuff) or Player:BuffUp(S.PoweroftheMaelstromBuff))) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 62"; end
  end
  -- frost_shock,if=buff.icefury.up&buff.master_of_the_elements.up&!buff.lava_surge.up&!talent.electrified_shocks.enabled&!talent.flux_melting.enabled&cooldown.lava_burst.charges_fractional<1.0&talent.echoes_of_the_elements.enabled
  -- Note: echoes_of_the_elements doesn't appear to exist???
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and Player:MOTEP() and Player:BuffDown(S.LavaSurgeBuff) and (not S.ElectrifiedShocks:IsAvailable()) and (not S.FluxMelting:IsAvailable()) and S.LavaBurst:ChargesFractional() < 1.0) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 63"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.flux_melting.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.FluxMelting:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 63.5"; end
  end
  -- lightning_bolt,if=buff.master_of_the_elements.up&!buff.lava_surge.up&(cooldown.lava_burst.charges_fractional<1.0&talent.echoes_of_the_elements.enabled)
  -- Note: echoes_of_the_elements doesn't appear to exist???
  if IsViable(S.LightningBolt) and (Player:MOTEP() and Player:BuffDown(S.LavaSurgeBuff) and (S.LavaBurst:ChargesFractional() < 1.0)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 64"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2
  if IsViable(S.LavaBurst) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 65"; end
  end
  -- frost_shock,if=buff.icefury.up&!talent.electrified_shocks.enabled&!talent.flux_melting.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and (not S.ElectrifiedShocks:IsAvailable()) and not S.FluxMelting:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 66"; end
  end
  -- chain_lightning,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if IsViable(S.ChainLightning) and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 68"; end
  end
  -- lightning_bolt
  if IsViable(S.LightningBolt) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 70"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and (Player:IsMoving()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 72"; end
  end
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 74"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 76"; end
  end
end

--- ======= MAIN =======
local function APL()
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    Shaman.Targets = #Enemies40y
    Shaman.ClusterTargets = #Enemies10ySplash
  else
    Shaman.Targets = 1
    Shaman.ClusterTargets = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Refresh shields.
    if Settings.Elemental.PreferEarthShield and S.EarthShield:IsCastable() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Earth Shield Refresh"; end
    elseif S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) and (Settings.Elemental.PreferEarthShield and Player:BuffDown(S.EarthShield) or not Settings.Elemental.PreferEarthShield) then
      if Cast(S.LightningShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Lightning Shield Refresh" end
    end
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- spiritwalkers_grace,moving=1,if=movement.distance>6
    -- Note: Too situation to include
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
    if S.BloodFury:IsCastable() and ((not S.Ascendance:IsAvailable()) or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
      if Cast(S.BloodFury, Settings.Commons.GCDasOffGCD.Racials) then return "blood_fury main 2"; end
    end
    -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
    if S.Berserking:IsCastable() and ((not S.Ascendance:IsAvailable()) or Player:BuffUp(S.AscendanceBuff)) then
      if Cast(S.Berserking, Settings.Commons.GCDasOffGCD.Racials) then return "berserking main 4"; end
    end
    -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
    if S.Fireblood:IsCastable() and ((not S.Ascendance:IsAvailable()) or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
      if Cast(S.Fireblood, Settings.Commons.GCDasOffGCD.Racials) then return "fireblood main 6"; end
    end
    -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
    if S.AncestralCall:IsCastable() and ((not S.Ascendance:IsAvailable()) or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
      if Cast(S.AncestralCall, Settings.Commons.GCDasOffGCD.Racials) then return "ancestral_call main 8"; end
    end
    -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
    if S.BagofTricks:IsCastable() and ((not S.Ascendance:IsAvailable()) or Player:BuffUp(S.AscendanceBuff)) then
      if Cast(S.BagofTricks, Settings.Commons.GCDasOffGCD.Racials) then return "bag_of_tricks main 10"; end
    end
    -- use_items
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "General use_items for " .. TrinketToUse:Name(); end
    end
    -- auto_attack
    -- natures_swiftness
    if S.NaturesSwiftness:IsCastable() then
      if Cast(S.NaturesSwiftness, Settings.Commons.GCDasOffGCD.NaturesSwiftness) then return "natures_swiftness main 12"; end
    end
    -- invoke_external_buff,name=power_infusion,if=talent.ascendance.enabled&buff.ascendance.up|!talent.ascendance.enabled
    -- Note: Not handling external buffs.
    -- run_action_list,name=aoe,if=active_enemies>2&(spell_targets.chain_lightning>2|spell_targets.lava_beam>2)
    if (AoEON() and Shaman.Targets > 2 and Shaman.ClusterTargets > 2) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "POOL") then return "Pool for Aoe()"; end
    end
    -- run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "POOL") then return "Pool for SingleTarget()"; end
    end
  end
end

local function Init()
  HR.Print("Elemental Shaman rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(262, APL, Init)
