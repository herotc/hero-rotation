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
local GetTime    = GetTime

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
local HasMainHandEnchant, MHEnchantTimeRemains
local Enemies40y, Enemies10ySplash
Shaman.Targets = 0
Shaman.ClusterTargets = 0

local function T302pcNextTick()
  return 40 - (GetTime() - Shaman.LastT302pcBuff)
end

local function EvaluateFlameShockRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateFlameShockRefreshable2(TargetUnit)
  -- target_if=refreshable,if=dot.flame_shock.remains<target.time_to_die-5
  -- Note: Trimmed items handled before this function is called
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff) and TargetUnit:DebuffRemains(S.FlameShockDebuff) < TargetUnit:TimeToDie() - 5)
end

local function EvaluateFlameShockRefreshable3(TargetUnit)
  -- target_if=refreshable,if=dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
  -- Note: Trimmed items handled before this function is called
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff) and TargetUnit:DebuffRemains(S.FlameShockDebuff) < TargetUnit:TimeToDie() - 5 and TargetUnit:DebuffRemains(S.FlameShockDebuff) > 0)
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
  -- Check weapon enchants
  HasMainHandEnchant, MHEnchantTimeRemains = GetWeaponEnchantInfo()
  -- flametongue_weapon,if=talent.improved_flametongue_weapon.enabled
  if S.ImprovedFlametongueWeapon:IsAvailable() and (not HasMainHandEnchant or MHEnchantTimeRemains < 600000) and S.FlametongueWeapon:IsViable() then
    if Cast(S.FlametongueWeapon) then return "flametongue_weapon enchant"; end
  end
  -- potion
  -- Note: Skipping this, as we don't need to use potion in Precombat any longer.
  -- stormkeeper
  if S.Stormkeeper:IsViable() then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- icefury
  if S.Icefury:IsViable() then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury precombat 4"; end
  end
  -- Manually added: Opener abilities, in case icefury is on CD
  if S.ElementalBlast:IsViable() then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast precombat 6"; end
  end
  if Player:IsCasting(S.ElementalBlast) and S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 8"; end
  end
  if Player:IsCasting(S.ElementalBlast) and not S.PrimordialWave:IsViable() and S.FlameShock:IsReady() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flameshock precombat 10"; end
  end
  if S.LavaBurst:IsViable() and not Player:IsCasting(S.LavaBurst) and (not S.ElementalBlast:IsAvailable() or (S.ElementalBlast:IsAvailable() and not S.ElementalBlast:IsViable())) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lavaburst precombat 12"; end
  end
  if Player:IsCasting(S.LavaBurst) and S.FlameShock:IsReady() then 
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flameshock precombat 14"; end
  end
  if Player:IsCasting(S.LavaBurst) and S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 16"; end
  end
end

local function Aoe()
  -- fire_elemental
  if S.FireElemental:IsReady() then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental aoe 2"; end
  end
  -- storm_elemental
  if S.StormElemental:IsReady() then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental aoe 4"; end
  end
  -- stormkeeper,if=!buff.stormkeeper.up
  if S.Stormkeeper:IsViable() and (not Player:StormkeeperP()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper aoe 6"; end
  end
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>45
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 45) then
    if Cast(S.TotemicRecall, Settings.Commons.GCDasOffGCD.TotemicRecall) then return "totemic_recall aoe 8"; end
  end
  -- liquid_magma_totem
  if S.LiquidMagmaTotem:IsReady() then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem aoe 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&buff.surge_of_power.up&!buff.splintered_elements.up
  if S.PrimordialWave:IsViable() and (Player:BuffDown(S.PrimordialWaveBuff) and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 12"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&!buff.splintered_elements.up
  if S.PrimordialWave:IsViable() and (Player:BuffDown(S.PrimordialWaveBuff) and S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable() and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 14"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled
  if S.PrimordialWave:IsViable() and (Player:BuffDown(S.PrimordialWaveBuff) and S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 16"; end
  end
  if S.FlameShock:IsCastable() then
    -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&talent.lightning_rod.enabled&talent.windspeakers_lava_resurgence.enabled&dot.flame_shock.remains<target.time_to_die-16&active_enemies<5
    if (Player:BuffUp(S.SurgeofPowerBuff) and S.LightningRod:IsAvailable() and S.WindspeakersLavaResurgence:IsAvailable() and Target:DebuffRemains(S.FlameShockDebuff) < Target:TimeToDie() - 1) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable2, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 18"; end
    end
    -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&(!talent.lightning_rod.enabled|talent.skybreakers_fiery_demise.enabled)&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
    if (Player:BuffUp(S.SurgeofPowerBuff) and (not S.LightningRod:IsAvailable() or S.SkybreakersFieryDemise:IsAvailable()) and S.FlameShockDebuff:AuraActiveCount() < 6) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable2, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 20"; end
    end
    -- flame_shock,target_if=refreshable,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
    if (S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() and not S.SurgeofPower:IsAvailable() and S.FlameShockDebuff:AuraActiveCount() < 6) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable2, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 22"; end
    end
    -- flame_shock,target_if=refreshable,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
    if (S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable() and S.FlameShockDebuff:AuraActiveCount() < 6) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable2, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 24"; end
    end
    -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&(!talent.lightning_rod.enabled|talent.skybreakers_fiery_demise.enabled)&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
    if (Player:BuffUp(S.SurgeofPowerBuff) and (not S.LightningRod:IsAvailable() or S.SkybreakersFieryDemise:IsAvailable())) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable3, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 26"; end
    end
    -- flame_shock,target_if=refreshable,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
    if (S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() and not S.SurgeofPower:IsAvailable()) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable3, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 28"; end
    end
    -- flame_shock,target_if=refreshable,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
    if (S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable()) then
      if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable3, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 30"; end
    end
  end
  -- ascendance
  if S.Ascendance:IsCastable() then
    if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance aoe 32"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=active_enemies=3&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBurst:IsViable() and (Shaman.Targets == 3 and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 34"; end
  end
  -- earthquake,if=buff.master_of_the_elements.up&(buff.magma_chamber.stack>15&active_enemies>=(7-talent.unrelenting_calamity.enabled)|talent.splintered_elements.enabled&active_enemies>=(10-talent.unrelenting_calamity.enabled)|talent.mountains_will_fall.enabled&active_enemies>=9)&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.Earthquake:IsReady() and (Player:MOTEP() and (Player:BuffStack(S.MagmaChamberBuff) > 15 and Shaman.Targets >= (7 - num(S.UnrelentingCalamity:IsAvailable())) or S.SplinteredElements:IsAvailable() and Shaman.Targets >= (10 - num(S.UnrelentingCalamity:IsAvailable())) or S.MountainsWillFall:IsAvailable() and Shaman.Targets >= 9) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 36"; end
  end
  -- lava_beam,if=buff.stormkeeper.up&(buff.surge_of_power.up&active_enemies>=6|buff.master_of_the_elements.up&(active_enemies<6|!talent.surge_of_power.enabled))&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBeam:IsViable() and (Player:StormkeeperP() and (Player:BuffUp(S.SurgeofPowerBuff) and Shaman.Targets >= 6 or Player:MOTEP() and (Shaman.Targets < 6 or not S.SurgeofPower:IsAvailable())) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 38"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up&(buff.surge_of_power.up&active_enemies>=6|buff.master_of_the_elements.up&(active_enemies<6|!talent.surge_of_power.enabled))&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.ChainLightning:IsViable() and (Player:StormkeeperP() and (Player:BuffUp(S.SurgeofPowerBuff) and Shaman.Targets >= 6 or Player:MOTEP() and (Shaman.Targets < 6 or not S.SurgeofPower:IsAvailable())) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 40"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 42"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(maelstrom>=60-5*talent.eye_of_the_storm.rank-2*talent.flow_of_power.enabled)&(!talent.echoes_of_great_sundering.enabled&!talent.lightning_rod.enabled|buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(!buff.ascendance.up&active_enemies>3&talent.unrelenting_calamity.enabled|active_enemies>3&!talent.unrelenting_calamity.enabled|active_enemies=3)
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.MasteroftheElements:IsAvailable() and not Player:MOTEP() and (Player:MaelstromP() >= 60 - 5 * S.EyeoftheStorm:TalentRank() - 2 * num(S.FlowofPower:IsAvailable())) and (not S.EchoesofGreatSundering:IsAvailable() and not S.LightningRod:IsAvailable() or Player:BuffUp(S.EchoesofGreatSunderingBuff)) and (Player:BuffDown(S.AscendanceBuff) and Shaman.Targets > 3 and not S.UnrelentingCalamity:IsAvailable() or Shaman.ClusterTargets == 3)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 44"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&active_enemies>3&(spell_targets.chain_lightning>3|spell_targets.lava_beam>3)
  if S.Earthquake:IsReady() and (not S.EchoesofGreatSundering:IsAvailable() and Shaman.Targets > 3 and Shaman.ClusterTargets > 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 46"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled&active_enemies=3&(spell_targets.chain_lightning=3|spell_targets.lava_beam=3)
  if S.Earthquake:IsReady() and (not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable() and Shaman.Targets == 3 and Shaman.ClusterTargets == 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 48"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 50"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 52"; end
  end
  -- elemental_blast,if=talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 54"; end
  end
  -- elemental_blast,if=enemies=3&!talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (Shaman.Targets == 3 and not S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 56"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 58"; end
  end
  -- earth_shock,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 60"; end
  end
  -- icefury,if=!buff.ascendance.up&talent.electrified_shocks.enabled&(talent.lightning_rod.enabled&active_enemies<5&!buff.master_of_the_elements.up|talent.deeply_rooted_elements.enabled&active_enemies=3)
  if S.Icefury:IsViable() and (Player:BuffDown(S.AscendanceBuff) and S.ElectrifiedShocks:IsAvailable() and (S.LightningRod:IsAvailable() and Shaman.Targets < 5 and not Player:MOTEP() or S.DeeplyRootedElements:IsAvailable() and Shaman.Targets == 3)) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 62"; end
  end
  -- frost_shock,if=!buff.ascendance.up&buff.icefury.up&talent.electrified_shocks.enabled&(!debuff.electrified_shocks.up|buff.icefury.remains<gcd)&(talent.lightning_rod.enabled&active_enemies<5&!buff.master_of_the_elements.up|talent.deeply_rooted_elements.enabled&active_enemies=3)
  if S.FrostShock:IsCastable() and (Player:BuffDown(S.AscendanceBuff) and Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and (Target:DebuffDown(S.ElectrifiedShocksDebuff) or Player:BuffRemains(S.IcefuryBuff) < Player:GCD()) and (S.LightningRod:IsAvailable() and Shaman.Targets < 5 and not Player:MOTEP() or S.DeeplyRootedElements:IsAvailable() and Shaman.Targets == 3)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 64"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(buff.stormkeeper.up|t30_2pc_timer.next_tick<3&set_bonus.tier30_2pc)&(maelstrom<60-5*talent.eye_of_the_storm.rank-2*talent.flow_of_power.enabled-10)&active_enemies<5
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MOTEP() and (Player:StormkeeperP() or Player:HasTier(30, 2) and T302pcNextTick() < 3) and (Player:MaelstromP() < 60 - 5 * S.EyeoftheStorm:TalentRank() - 2 * num(S.FlowofPower:IsAvailable()) - 10) and Shaman.Targets < 5) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 66"; end
  end
  -- lava_beam,if=buff.stormkeeper.up
  if S.LavaBeam:IsViable() and (Player:StormkeeperP()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 68"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsViable() and (Player:StormkeeperP()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 70"; end
  end
  -- lava_beam,if=buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:PotMP() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 72"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up
  if S.ChainLightning:IsViable() and (Player:PotMP()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 74"; end
  end
  -- lava_beam,if=active_enemies>=6&buff.surge_of_power.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Shaman.Targets >= 6 and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 76"; end
  end
  -- chain_lightning,if=active_enemies>=6&buff.surge_of_power.up
  if S.ChainLightning:IsViable() and (Shaman.Targets >= 6 and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 78"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=buff.lava_surge.up&talent.deeply_rooted_elements.enabled&buff.windspeakers_lava_resurgence.up
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.DeeplyRootedElements:IsAvailable() and Player:BuffUp(S.WindspeakersLavaResurgenceBuff)) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 80"; end
  end
  -- lava_beam,if=buff.master_of_the_elements.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:MOTEP() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 82"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=enemies=3&talent.master_of_the_elements.enabled
  if S.LavaBurst:IsViable() and (Shaman.Targets == 3 and S.MasteroftheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 84"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=buff.lava_surge.up&talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 86"; end
  end
  -- icefury,if=talent.electrified_shocks.enabled&active_enemies<5
  if S.Icefury:IsViable() and (S.ElectrifiedShocks:IsAvailable() and Shaman.ClusterTargets < 5) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 88"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&!debuff.electrified_shocks.up&active_enemies<5&talent.unrelenting_calamity.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and Target:DebuffDown(S.ElectrifiedShocksDebuff) and Shaman.Targets < 5 and S.UnrelentingCalamity:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 90"; end
  end
  -- lava_beam,if=buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 92"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsViable() then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 94"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock moving aoe 96"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 98"; end
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
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>45&(talent.lava_surge.enabled&talent.splintered_elements.enabled|active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1))
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 45 and (S.LavaSurge:IsAvailable() and S.SplinteredElements:IsAvailable() or Shaman.Targets > 1 and Shaman.ClusterTargets > 1)) then
    if Cast(S.TotemicRecall, Settings.Commons.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_target 6"; end
  end
  -- liquid_magma_totem,if=talent.lava_surge.enabled&talent.splintered_elements.enabled|active_dot.flame_shock=0|dot.flame_shock.remains<6|active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.LiquidMagmaTotem:IsCastable() and (S.LavaSurge:IsAvailable() and S.SplinteredElements:IsAvailable() or S.FlameShockDebuff:AuraActiveCount() == 0 or Target:DebuffRemains(S.FlameShockDebuff) < 6 or Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 8"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up&!buff.splintered_elements.up
  if S.PrimordialWave:IsViable() and (Player:BuffDown(S.PrimordialWaveBuff) and Player:BuffDown(S.SplinteredElementsBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave single_target 10"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies=1&refreshable&(dot.flame_shock.remains<cooldown.primordial_wave.remains|!talent.primordial_wave.enabled)&!buff.surge_of_power.up&(!buff.master_of_the_elements.up|(!buff.stormkeeper.up&(talent.elemental_blast.enabled&maelstrom<90-8*talent.eye_of_the_storm.rank|maelstrom<60-5*talent.eye_of_the_storm.rank)))
  if S.FlameShock:IsCastable() and (Shaman.Targets == 1 and Target:DebuffRefreshable(S.FlameShockDebuff) and (Target:DebuffRemains(S.FlameShockDebuff) < S.PrimordialWave:CooldownRemains() or not S.PrimordialWave:IsAvailable()) and Player:BuffDown(S.SurgeofPowerBuff) and (not Player:MOTEP() or (not Player:StormkeeperP() and (S.ElementalBlast:IsAvailable() and Player:MaelstromP() < 90 - 8 * S.EyeoftheStorm:TalentRank() or Player:MaelstromP() < 60 - 5 * S.EyeoftheStorm:TalentRank())))) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 12"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_dot.flame_shock=0&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(!buff.master_of_the_elements.up&(buff.stormkeeper.up|cooldown.stormkeeper.remains=0)|!talent.surge_of_power.enabled)
  if S.FlameShock:IsCastable() and (S.FlameShockDebuff:AuraActiveCount() == 0 and Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (not Player:MOTEP() and (Player:StormkeeperP() or S.Stormkeeper:CooldownUp()) or not S.SurgeofPower:IsAvailable())) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateFlameShockRemains, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 14"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&refreshable&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(buff.surge_of_power.up&!buff.stormkeeper.up&!cooldown.stormkeeper.remains=0|!talent.surge_of_power.enabled),cycle_targets=1
  if S.FlameShock:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (Player:BuffUp(S.SurgeofPowerBuff) and not Player:StormkeeperP() and S.Stormkeeper:CooldownDown() or not S.SurgeofPower:IsAvailable())) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateFlameShockRemains, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 16"; end
  end
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up&maelstrom>=116&talent.elemental_blast.enabled&talent.surge_of_power.enabled&talent.swelling_maelstrom.enabled&!talent.lava_surge.enabled&!talent.echo_of_the_elements.enabled&!talent.primordial_surge.enabled
  if S.Stormkeeper:IsViable() and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperP() and Player:MaelstromP() >= 116 and S.ElementalBlast:IsAvailable() and S.SurgeofPower:IsAvailable() and S.SwellingMaelstrom:IsAvailable() and not S.LavaSurge:IsAvailable() and not S.EchooftheElements:IsAvailable() and not S.PrimordialSurge:IsAvailable()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 18"; end
  end
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up&buff.surge_of_power.up&!talent.lava_surge.enabled&!talent.echo_of_the_elements.enabled&!talent.primordial_surge.enabled
  if S.Stormkeeper:IsViable() and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperP() and Player:BuffUp(S.SurgeofPowerBuff) and not S.LavaSurge:IsAvailable() and not S.EchooftheElements:IsAvailable() and not S.PrimordialSurge:IsAvailable()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 20"; end
  end
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up&(!talent.surge_of_power.enabled|!talent.elemental_blast.enabled|talent.lava_surge.enabled|talent.echo_of_the_elements.enabled|talent.primordial_surge.enabled)
  if S.Stormkeeper:IsViable() and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperP() and (not S.SurgeofPower:IsAvailable() or not S.ElementalBlast:IsAvailable() or S.LavaSurge:IsAvailable() or S.EchooftheElements:IsAvailable() or S.PrimordialSurge:IsAvailable())) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 22"; end
  end
  -- ascendance,if=!buff.stormkeeper.up
  if S.Ascendance:IsCastable() and (not Player:StormkeeperP()) then
    if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance single_target 24"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:StormkeeperP() and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 26"; end
  end
  -- lava_beam,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if S.LavaBeam:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:StormkeeperP() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 28"; end
  end
  -- chain_lightning,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if S.ChainLightning:IsViable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:StormkeeperP() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 30"; end
  end
  -- lava_burst,if=buff.stormkeeper.up&!buff.master_of_the_elements.up&!talent.surge_of_power.enabled&talent.master_of_the_elements.enabled
  if S.LavaBurst:IsViable() and (Player:StormkeeperP() and not Player:MOTEP() and not S.SurgeofPower:IsAvailable() and S.MasteroftheElements:IsAvailable()) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 32"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&buff.master_of_the_elements.up
  if S.LightningBolt:IsViable() and (Player:StormkeeperP() and not S.SurgeofPower:IsAvailable() and Player:MOTEP()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 34"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&!talent.master_of_the_elements.enabled
  if S.LightningBolt:IsViable() and (Player:StormkeeperP() and not S.SurgeofPower:IsAvailable() and not S.MasteroftheElements:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 36"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up&talent.lightning_rod.enabled
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff) and S.LightningRod:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 38"; end
  end
  -- icefury,if=talent.electrified_shocks.enabled&talent.lightning_rod.enabled
  if S.Icefury:IsViable() and (S.ElectrifiedShocks:IsAvailable() and S.LightningRod:IsAvailable()) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 40"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&(debuff.electrified_shocks.remains<2|buff.icefury.remains<=gcd)&talent.lightning_rod.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and (Target:DebuffRemains(S.ElectrifiedShocksDebuff) < 2 or Player:BuffRemains(S.IcefuryBuff) <= Player:GCD()) and S.LightningRod:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 42"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&maelstrom>=50&debuff.electrified_shocks.remains<2*gcd&buff.stormkeeper.up&talent.lightning_rod.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and Player:MaelstromP() >= 50 and Target:DebuffRemains(S.ElectrifiedShocksDebuff) < 2 * Player:GCD() and Player:StormkeeperP() and S.LightningRod:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 44"; end
  end
  -- lava_beam,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time&!set_bonus.tier31_4pc
  if S.LavaBeam:IsCastable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and Player:PotMP() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime() and not Player:HasTier(31, 4)) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 46"; end
  end
  -- frost_shock,if=buff.icefury.up&buff.stormkeeper.up&!talent.lava_surge.enabled&!talent.echo_of_the_elements.enabled&!talent.primordial_surge.enabled&talent.elemental_blast.enabled&(maelstrom>=61&maelstrom<75&cooldown.lava_burst.remains>gcd|maelstrom>=49&maelstrom<63&cooldown.lava_burst.ready)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and Player:StormkeeperP() and not S.LavaSurge:IsAvailable() and not S.EchooftheElements:IsAvailable() and not S.PrimordialSurge:IsAvailable() and S.ElementalBlast:IsAvailable() and (Player:MaelstromP() >= 61 and Player:MaelstromP() < 75 and S.LavaBurst:CooldownRemains() > Player:GCD() or Player:MaelstromP() >= 49 and Player:MaelstromP() < 63 and S.LavaBurst:CooldownUp())) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 48"; end
  end
  -- frost_shock,if=buff.icefury.up&buff.stormkeeper.up&!talent.lava_surge.enabled&!talent.echo_of_the_elements.enabled&!talent.elemental_blast.enabled&(maelstrom>=36&maelstrom<50&cooldown.lava_burst.remains>gcd|maelstrom>=24&maelstrom<38&cooldown.lava_burst.ready)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and not S.LavaSurge:IsAvailable() and not S.EchooftheElements:IsAvailable() and not S.ElementalBlast:IsAvailable() and (Player:MaelstromP() >= 36 and Player:MaelstromP() < 50 and S.LavaBurst:CooldownRemains() > Player:GCD() or Player:MaelstromP() >= 24 and Player:MaelstromP() < 38 and S.LavaBurst:CooldownUp())) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 50"; end
  end
  -- lava_burst,if=buff.windspeakers_lava_resurgence.up&(talent.echo_of_the_elements.enabled|talent.lava_surge.enabled|talent.primordial_surge.enabled|maelstrom>=63&talent.master_of_the_elements.enabled|maelstrom>=38&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)|!talent.elemental_blast.enabled)
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.WindspeakersLavaResurgenceBuff) and (S.EchooftheElements:IsAvailable() or S.LavaSurge:IsAvailable() or S.PrimordialSurge:IsAvailable() or Player:MaelstromP() >= 63 and S.MasteroftheElements:IsAvailable() or Player:MaelstromP() >= 38 and Player:BuffUp(S.EchoesofGreatSunderingBuff) and Shaman.Targets > 1 and Shaman.ClusterTargets > 1 or not S.ElementalBlast:IsAvailable())) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 52"; end
  end
  -- lava_burst,if=cooldown_react&buff.lava_surge.up&(talent.echo_of_the_elements.enabled|talent.lava_surge.enabled|talent.primordial_surge.enabled|!talent.master_of_the_elements.enabled|!talent.elemental_blast.enabled)
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and (S.EchooftheElements:IsAvailable() or S.LavaSurge:IsAvailable() or S.PrimordialSurge:IsAvailable() or not S.MasteroftheElements:IsAvailable() or not S.ElementalBlast:IsAvailable())) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 54"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.ascendance.up&(set_bonus.tier31_4pc|!talent.elemental_blast.enabled)&(!talent.further_beyond.enabled|fb_extension_remaining<2)
  -- TODO: Determine a way to calculate fb_extension_remaining.
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.AscendanceBuff) and (Player:HasTier(31, 4) or not S.ElementalBlast:IsAvailable())) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 56"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=!buff.ascendance.up&(!talent.elemental_blast.enabled|!talent.mountains_will_fall.enabled)&!talent.lightning_rod.enabled&set_bonus.tier31_4pc
  if S.LavaBurst:IsViable() and (Player:BuffDown(S.AscendanceBuff) and (not S.ElementalBlast:IsAvailable() or not S.MountainsWillFall:IsAvailable()) and not S.LightningRod:IsAvailable() and Player:HasTier(31, 4)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 58"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&!talent.lightning_rod.enabled
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MOTEP() and not S.LightningRod:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 60"; end
  end
  -- lava_burst,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(maelstrom>=75|maelstrom>=50&!talent.elemental_blast.enabled)&talent.swelling_maelstrom.enabled&maelstrom<=130
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MOTEP() and (Player:MaelstromP() >= 75 or Player:MaelstromP() >= 50 and not S.ElementalBlast:IsAvailable()) and S.SwellingMaelstrom:IsAvailable() and Player:MaelstromP() <= 130) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 62"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(!talent.elemental_blast.enabled&active_enemies<2|active_enemies>1)
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and (not S.ElementalBlast:IsAvailable() and Shaman.Targets < 2 or Shaman.Targets > 1)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 64"; end
  end
  -- earthquake,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled
  if S.Earthquake:IsReady() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 66"; end
  end
  -- elemental_blast,if=(!talent.master_of_the_elements.enabled|buff.master_of_the_elements.up)&debuff.electrified_shocks.up
  if S.ElementalBlast:IsViable() and ((not S.MasteroftheElements:IsAvailable() or Player:MOTEP()) and Target:DebuffUp(S.ElectrifiedShocksDebuff)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 68"; end
  end
  -- frost_shock,if=buff.icefury.up&buff.master_of_the_elements.up&maelstrom<110&cooldown.lava_burst.charges_fractional<1.0&talent.electrified_shocks.enabled&talent.elemental_blast.enabled&!talent.lightning_rod.enabled
  if S.FrostShock:IsViable() and (Player:IcefuryP() and Player:MOTEP() and Player:MaelstromP() < 110 and S.LavaBurst:ChargesFractional() < 1.0 and S.ElectrifiedShocks:IsAvailable() and S.ElementalBlast:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 70"; end
  end
  -- elemental_blast,if=buff.master_of_the_elements.up|talent.lightning_rod.enabled
  if S.ElementalBlast:IsViable() and (Player:MOTEP() or S.LightningRod:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 72"; end
  end
  -- earth_shock
  if S.EarthShock:IsReady() then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 74"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.electrified_shocks.enabled&buff.master_of_the_elements.up&!talent.lightning_rod.enabled&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.FrostShock:IsViable() and (Player:IcefuryP() and S.ElectrifiedShocks:IsAvailable() and Player:MOTEP() and not S.LightningRod:IsAvailable() and Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 76"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 78"; end
  end
  -- frost_shock,if=buff.icefury.up&talent.flux_melting.enabled&!buff.flux_melting.up
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and S.FluxMelting:IsAvailable() and Player:BuffDown(S.FluxMeltingBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 80"; end
  end
  -- frost_shock,if=buff.icefury.up&(talent.electrified_shocks.enabled&debuff.electrified_shocks.remains<2|buff.icefury.remains<6)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and (S.ElectrifiedShocks:IsAvailable() and Target:DebuffRemains(S.ElectrifiedShocksDebuff) < 2 or Player:BuffRemains(S.IcefuryBuff) < 6)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 82"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.echo_of_the_elements.enabled|talent.lava_surge.enabled|talent.primordial_surge.enabled|!talent.elemental_blast.enabled|!talent.master_of_the_elements.enabled|buff.stormkeeper.up
  if S.LavaBurst:IsViable() and (S.EchooftheElements:IsAvailable() or S.LavaSurge:IsAvailable() or S.PrimordialSurge:IsAvailable() or not S.ElementalBlast:IsAvailable() or not S.MasteroftheElements:IsAvailable() or Player:StormkeeperP()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 84"; end
  end
  -- elemental_blast
  if S.ElementalBlast:IsViable() then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 86"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up&talent.unrelenting_calamity.enabled&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.ChainLightning:IsViable() and (Player:PotMP() and S.UnrelentingCalamity:IsAvailable() and Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 88"; end
  end
  -- lightning_bolt,if=buff.power_of_the_maelstrom.up&talent.unrelenting_calamity.enabled
  if S.LightningBolt:IsViable() and (Player:PotMP() and S.UnrelentingCalamity:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 90"; end
  end
  -- icefury
  if S.Icefury:IsViable() then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 92"; end
  end
  -- chain_lightning,if=pet.storm_elemental.active&debuff.lightning_rod.up&(debuff.electrified_shocks.up|buff.power_of_the_maelstrom.up)&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.ChainLightning:IsViable() and (Pet:IsActive() and Pet:Name() == "Greater Storm Elemental" and Target:DebuffUp(S.LightningRodDebuff) and (Target:DebuffUp(S.ElectrifiedShocksDebuff) or Player:PotMP()) and Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 94"; end
  end
  -- lightning_bolt,if=pet.storm_elemental.active&debuff.lightning_rod.up&(debuff.electrified_shocks.up|buff.power_of_the_maelstrom.up)
  if S.LightningBolt:IsViable() and (Pet:IsActive() and Pet:Name() == "Greater Storm Elemental" and Target:DebuffUp(S.LightningRodDebuff) and (Target:DebuffUp(S.ElectrifiedShocksDebuff) or Player:PotMP())) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 96"; end
  end
  -- frost_shock,if=buff.icefury.up&buff.master_of_the_elements.up&!buff.lava_surge.up&!talent.electrified_shocks.enabled&!talent.flux_melting.enabled&cooldown.lava_burst.charges_fractional<1.0&talent.echo_of_the_elements.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and Player:MOTEP() and Player:BuffDown(S.LavaSurgeBuff) and not S.ElectrifiedShocks:IsAvailable() and not S.FluxMelting:IsAvailable() and S.LavaBurst:ChargesFractional() < 1.0 and S.EchooftheElements:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 98"; end
  end
  -- frost_shock,if=buff.icefury.up&(talent.flux_melting.enabled|talent.electrified_shocks.enabled&!talent.lightning_rod.enabled)
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and (S.FluxMelting:IsAvailable() or S.ElectrifiedShocks:IsAvailable() and not S.LightningRod:IsAvailable())) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 100"; end
  end
  -- chain_lightning,if=buff.master_of_the_elements.up&!buff.lava_surge.up&(cooldown.lava_burst.charges_fractional<1.0&talent.echo_of_the_elements.enabled)&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.ChainLightning:IsViable() and (Player:MOTEP() and Player:BuffDown(S.LavaSurgeBuff) and (S.LavaBurst:ChargesFractional() < 1.0 and S.EchooftheElements:IsAvailable()) and Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 102"; end
  end
  -- lightning_bolt,if=buff.master_of_the_elements.up&!buff.lava_surge.up&(cooldown.lava_burst.charges_fractional<1.0&talent.echo_of_the_elements.enabled)
  if S.LightningBolt:IsViable() and (Player:MOTEP() and Player:BuffDown(S.LavaSurgeBuff) and (S.LavaBurst:ChargesFractional() < 1.0 and S.EchooftheElements:IsAvailable())) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 104"; end
  end
  -- frost_shock,if=buff.icefury.up&!talent.electrified_shocks.enabled&!talent.flux_melting.enabled
  if S.FrostShock:IsCastable() and (Player:IcefuryP() and not S.ElectrifiedShocks:IsAvailable() and not S.FluxMelting:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 106"; end
  end
  -- chain_lightning,if=active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)
  if S.ChainLightning:IsViable() and (Shaman.Targets > 1 and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 108"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsViable() then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 110"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and (Player:IsMoving()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 112"; end
  end
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 114"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 116"; end
  end
end

--- ======= MAIN =======
local function APL()
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    Shaman.Targets = #Enemies40y
    Shaman.ClusterTargets = Target:GetEnemiesInSplashRangeCount(10)
  else
    Shaman.Targets = 1
    Shaman.ClusterTargets = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end
  end

  -- Shield Handling
  if Everyone.TargetIsValid() or Settings.Commons.ShieldsOOC then
    local EarthShieldBuff = (S.ElementalOrbit:IsAvailable()) and S.EarthShieldSelfBuff or S.EarthShieldOtherBuff
    if (S.ElementalOrbit:IsAvailable() or Settings.Commons.PreferEarthShield) and S.EarthShield:IsReady() and (Player:BuffDown(EarthShieldBuff) or (not Player:AffectingCombat() and Player:BuffStack(EarthShieldBuff) < 5)) then
      if Cast(S.EarthShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Earth Shield Refresh"; end
    elseif (S.ElementalOrbit:IsAvailable() or not Settings.Commons.PreferEarthShield) and S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) then
      if Cast(S.LightningShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Lightning Shield Refresh" end
    end
  end

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- spiritwalkers_grace,moving=1,if=movement.distance>6
    -- Note: Too situational to include
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    if CDsON() then
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 2"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 4"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 6"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 8"; end
      end
      -- bag_of_tricks,if=!talent.ascendance.enabled|!buff.ascendance.up
      if S.BagofTricks:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks main 10"; end
      end
    end
    -- use_items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- natures_swiftness
    if S.NaturesSwiftness:IsCastable() then
      if Cast(S.NaturesSwiftness, Settings.Commons.GCDasOffGCD.NaturesSwiftness) then return "natures_swiftness main 12"; end
    end
    -- invoke_external_buff,name=power_infusion,if=talent.ascendance.enabled&buff.ascendance.up|!talent.ascendance.enabled
    -- Note: Not handling external buffs.
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 14"; end
      end
    end
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
  S.FlameShockDebuff:RegisterAuraTracking()

  HR.Print("Elemental Shaman rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(262, APL, Init)
