--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC               = HeroDBC.DBC
-- HeroLib
local HL                = HeroLib
local Cache             = HeroCache
local Unit              = HL.Unit
local Player            = Unit.Player
local Pet               = Unit.Pet
local Target            = Unit.Target
local Spell             = HL.Spell
local MultiSpell        = HL.MultiSpell
local Item              = HL.Item
-- HeroRotation
local HR                = HeroRotation
local Cast              = HR.Cast
local CastLeftNameplate = HR.CastLeftNameplate
local AoEON             = HR.AoEON
local CDsON             = HR.CDsON
-- Num/Bool Helper Functions
local num               = HR.Commons.Everyone.num
local bool              = HR.Commons.Everyone.bool
-- Lua
local GetTime           = GetTime
-- WoW API
local Delay             = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Elemental
local I = Item.Shaman.Elemental

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.TrinketName:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  CommonsDS = HR.GUISettings.APL.Shaman.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Shaman.CommonsOGCD,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

--- ===== Rotation Variables =====
local VarMaelCap = 100 + 50 * num(S.SwellingMaelstrom:IsAvailable()) + 25 * num(S.PrimordialCapacity:IsAvailable())
local BossFightRemains = 11111
local FightRemains = 11111
local HasMainHandEnchant, MHEnchantTimeRemains
local Enemies40y, Enemies10ySplash
Shaman.ClusterTargets = 0

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarMaelCap = 100 + 50 * num(S.SwellingMaelstrom:IsAvailable()) + 25 * num(S.PrimordialCapacity:IsAvailable())
  S.PrimordialWave:RegisterInFlightEffect(327162)
  S.PrimordialWave:RegisterInFlight()
  S.LavaBurst:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.PrimordialWave:RegisterInFlightEffect(327162)
S.PrimordialWave:RegisterInFlight()
S.LavaBurst:RegisterInFlight()

--- ===== Helper Functions =====
local function T302pcNextTick()
  return 40 - (GetTime() - Shaman.LastT302pcBuff)
end

local function LowestFlameShock(Enemies)
  local Lowest, BestTarget
  for _, Enemy in pairs(Enemies) do
    local FSRemains = Enemy:DebuffRemains(S.FlameShockDebuff)
    if not Lowest or FSRemains < Lowest then
      Lowest = FSRemains
      BestTarget = Enemy
    end
  end
  return Lowest, BestTarget
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterFlameShockRemains(TargetUnit)
  -- target_if=min:dot.flame_shock.remains
  return TargetUnit:DebuffRemains(S.FlameShockDebuff)
end

local function EvaluateTargetIfFilterLightningRodRemains(TargetUnit)
  -- target_if=min:debuff.lightning_rod.remains
  return TargetUnit:DebuffRemains(S.LightningRodDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfFlameShockRefreshable(TargetUnit)
  -- if=refreshable
  return TargetUnit:DebuffRefreshable(S.FlameShockDebuff)
end

local function EvaluateTargetIfFlameShockST(TargetUnit)
  -- if=active_enemies=1&(dot.flame_shock.remains<2|active_dot.flame_shock=0)&(dot.flame_shock.remains<cooldown.primordial_wave.remains|!talent.primordial_wave.enabled)&(dot.flame_shock.remains<cooldown.liquid_magma_totem.remains|!talent.liquid_magma_totem.enabled)&!buff.surge_of_power.up&talent.fire_elemental.enabled
  -- Note: Target count, SoP buff, and FireElemental talent checked before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff) < 2 or S.FlameShockDebuff:AuraActiveCount() == 0) and (TargetUnit:DebuffRemains(S.FlameShockDebuff) < S.PrimordialWave:CooldownRemains() or not S.PrimordialWave:IsAvailable()) and (TargetUnit:DebuffRemains(S.FlameShockDebuff) < S.LiquidMagmaTotem:CooldownRemains() or not S.LiquidMagmaTotem:IsAvailable())
end

--- ===== CastCycle Functions =====
local function EvaluateCycleFlameShockRefreshable(TargetUnit)
  -- target_if=refreshable
  return TargetUnit:DebuffRefreshable(S.FlameShockDebuff)
end

local function EvaluateCycleFlameShockRemains(TargetUnit)
  -- target_if=dot.flame_shock.remains
  return TargetUnit:DebuffUp(S.FlameShockDebuff)
end

local function EvaluateCycleFlameShockRemains2(TargetUnit)
  -- target_if=dot.flame_shock.remains>2
  return TargetUnit:DebuffRemains(S.FlameShockDebuff) > 2
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- flametongue_weapon,if=talent.improved_flametongue_weapon.enabled
  -- Note: Moved to APL().
  -- potion
  -- Note: Skipping this, as we don't need to use potion in Precombat any longer.
  -- stormkeeper
  if S.Stormkeeper:IsViable() then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- lightning_shield
  -- Note: Moved to APL()
  -- thunderstrike_ward
  local ShieldEnchantID = select(8, GetWeaponEnchantInfo())
  if S.ThunderstrikeWard:IsReady() and (not ShieldEnchantID or ShieldEnchantID ~= 7587) then
    if Cast(S.ThunderstrikeWard) then return "thunderstrike_ward precombat 4"; end
  end
  -- Manually added: Opener abilities, in case thunderstrike_ward is on CD
  if S.ElementalBlast:IsViable() then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast precombat 6"; end
  end
  if Player:IsCasting(S.ElementalBlast) and S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 8"; end
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
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 16"; end
  end
end

local function Aoe()
  -- fire_elemental,if=!buff.fire_elemental.up
  if S.FireElemental:IsReady() and (not Shaman.FireElemental.GreaterActive) then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental aoe 2"; end
  end
  -- storm_elemental,if=!buff.storm_elemental.up
  if S.StormElemental:IsReady() and (not Shaman.StormElemental.GreaterActive) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental aoe 4"; end
  end
  -- stormkeeper,if=!buff.stormkeeper.up
  if S.Stormkeeper:IsViable() and (not Player:StormkeeperUp()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper aoe 6"; end
  end
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>25
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 25) then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall aoe 8"; end
  end
  -- liquid_magma_totem
  if S.LiquidMagmaTotem:IsReady() then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem aoe 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=buff.surge_of_power.up
  if S.PrimordialWave:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "primordial_wave aoe 12"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled
  if S.PrimordialWave:IsViable() and (S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable()) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "primordial_wave aoe 14"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled
  if S.PrimordialWave:IsViable() and (S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "primordial_wave aoe 16"; end
  end
  if S.FlameShock:IsCastable() then
    local Lowest, BestTarget = LowestFlameShock(Enemies10ySplash)
    if BestTarget:DebuffRefreshable(S.FlameShockDebuff) then
      -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&talent.lightning_rod.enabled&dot.flame_shock.remains<target.time_to_die-16&active_enemies<5
      if Player:BuffUp(S.SurgeofPowerBuff) and S.LightningRod:IsAvailable() and Lowest < BestTarget:TimeToDie() - 16 and Shaman.ClusterTargets < 5 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 18"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 18"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&(!talent.lightning_rod.enabled|talent.skybreakers_fiery_demise.enabled)&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
      if Player:BuffUp(S.SurgeofPowerBuff) and (not S.LightningRod:IsAvailable() or S.SkybreakersFieryDemise:IsAvailable()) and Lowest < BestTarget:TimeToDie() - 5 and S.FlameShockDebuff:AuraActiveCount() < 6 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 20"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 20"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
      if S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() and not S.SurgeofPower:IsAvailable() and Lowest < BestTarget:TimeToDie() - 5 and S.FlameShockDebuff:AuraActiveCount() < 6 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 22"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 22"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&active_dot.flame_shock<6
      if S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable() and Lowest < BestTarget:TimeToDie() - 5 and S.FlameShockDebuff:AuraActiveCount() < 6 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 24"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 24"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&(!talent.lightning_rod.enabled|talent.skybreakers_fiery_demise.enabled)&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
      if Player:BuffUp(S.SurgeofPowerBuff) and (not S.LightningRod:IsAvailable() or S.SkybreakersFieryDemise:IsAvailable()) and Lowest < BestTarget:TimeToDie() - 5 and BestTarget:DebuffRemains(S.FlameShockDebuff) > 0 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 26"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 26"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
      if S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() and not S.SurgeofPower:IsAvailable() and Lowest < BestTarget:TimeToDie() - 5 and BestTarget:DebuffRemains(S.FlameShockDebuff) > 0 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 28"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 28"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=talent.deeply_rooted_elements.enabled&!talent.surge_of_power.enabled&dot.flame_shock.remains<target.time_to_die-5&dot.flame_shock.remains>0
      if S.DeeplyRootedElements:IsAvailable() and not S.SurgeofPower:IsAvailable() and Lowest < BestTarget:TimeToDie() - 5 and BestTarget:DebuffRemains(S.FlameShockDebuff) > 0 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 30"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 30"; end
        end
      end
    end
  end
  -- ascendance
  if S.Ascendance:IsCastable() then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe 32"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=active_enemies=3&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBurst:IsViable() and (Shaman.ClusterTargets == 3 and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 34"; end
  end
  -- earthquake,if=buff.master_of_the_elements.up&(buff.magma_chamber.stack=10&active_enemies>=6|talent.splintered_elements.enabled&active_enemies>=9|talent.mountains_will_fall.enabled&active_enemies>=9)&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.Earthquake:IsReady() and (Player:MotEUp() and (Player:BuffStack(S.MagmaChamberBuff) == 10 and Shaman.ClusterTargets >= 6 or S.SplinteredElements:IsAvailable() and Shaman.ClusterTargets >= 9 or S.MountainsWillFall:IsAvailable() and Shaman.ClusterTargets >= 9) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 36"; end
  end
  -- lava_beam,if=buff.stormkeeper.up&(buff.surge_of_power.up&active_enemies>=6|buff.master_of_the_elements.up&(active_enemies<6|!talent.surge_of_power.enabled))&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBeam:IsViable() and (Player:StormkeeperUp() and (Player:BuffUp(S.SurgeofPowerBuff) and Shaman.ClusterTargets >= 6 or Player:MotEUp() and (Shaman.ClusterTargets < 6 or not S.SurgeofPower:IsAvailable())) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 38"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up&(buff.surge_of_power.up&active_enemies>=6|buff.master_of_the_elements.up&(active_enemies<6|!talent.surge_of_power.enabled))&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.ChainLightning:IsViable() and (Player:StormkeeperUp() and (Player:BuffUp(S.SurgeofPowerBuff) and Shaman.ClusterTargets >= 6 or Player:MotEUp() and (Shaman.ClusterTargets < 6 or not S.SurgeofPower:IsAvailable())) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 40"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&(!talent.lightning_rod.enabled&set_bonus.tier31_4pc)
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and (not S.LightningRod:IsAvailable() and Player:HasTier(31, 4))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 42"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(maelstrom>=52-5*talent.eye_of_the_storm.enabled-2*talent.flow_of_power.enabled)&(!talent.echoes_of_great_sundering.enabled&!talent.lightning_rod.enabled|buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(!buff.ascendance.up&active_enemies>3|active_enemies=3)
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and (Player:MaelstromP() >= 52 - 5 * num(S.EyeoftheStorm:IsAvailable()) - 2 * num(S.FlowofPower:IsAvailable())) and (not S.EchoesofGreatSundering:IsAvailable() and not S.LightningRod:IsAvailable() or Player:BuffUp(S.EchoesofGreatSunderingBuff)) and (Player:BuffDown(S.AscendanceBuff) and Shaman.ClusterTargets > 3 or Shaman.ClusterTargets == 3)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 44"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&active_enemies>3&(spell_targets.chain_lightning>3|spell_targets.lava_beam>3)
  if S.Earthquake:IsReady() and (not S.EchoesofGreatSundering:IsAvailable() and Shaman.ClusterTargets > 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 46"; end
  end
  -- earthquake,if=!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled&active_enemies=3&(spell_targets.chain_lightning=3|spell_targets.lava_beam=3)
  if S.Earthquake:IsReady() and (not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable() and Shaman.ClusterTargets == 3) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 48"; end
  end
  -- earthquake,if=buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 50"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 52"; end
  end
  -- elemental_blast,if=talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 54"; end
  end
  -- elemental_blast,if=enemies=3&!talent.echoes_of_great_sundering.enabled
  if S.ElementalBlast:IsViable() and (Shaman.ClusterTargets == 3 and not S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 56"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 58"; end
  end
  -- earth_shock,if=talent.echoes_of_great_sundering.enabled
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 60"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(buff.stormkeeper.up|t30_2pc_timer.next_tick<3&set_bonus.tier30_2pc)&(maelstrom<60-5*talent.eye_of_the_storm.enabled-2*talent.flow_of_power.enabled-10)&active_enemies<5
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and (Player:StormkeeperUp() or T302pcNextTick() < 3 and Player:HasTier(30, 2)) and (Player:MaelstromP() < 60 - 5 * num(S.EyeoftheStorm:IsAvailable()) - 2 * num(S.FlowofPower:IsAvailable()) - 10) and Shaman.ClusterTargets < 5) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 62"; end
  end
  -- lava_beam,if=buff.stormkeeper.up
  if S.LavaBeam:IsViable() and (Player:StormkeeperUp()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 64"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up
  if S.ChainLightning:IsViable() and (Player:StormkeeperUp()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 66"; end
  end
  -- lava_beam,if=buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:PotMUp() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 68"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up
  if S.ChainLightning:IsViable() and (Player:PotMUp()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 70"; end
  end
  -- lava_beam,if=active_enemies>=6&buff.surge_of_power.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Shaman.ClusterTargets >= 6 and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 72"; end
  end
  -- chain_lightning,if=active_enemies>=6&buff.surge_of_power.up
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets >= 6 and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 74"; end
  end
  -- lava_beam,if=buff.master_of_the_elements.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:MotEUp() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 76"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=enemies=3&talent.master_of_the_elements.enabled
  if S.LavaBurst:IsViable() and (Shaman.ClusterTargets == 3 and S.MasteroftheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 78"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=buff.lava_surge.up&talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 80"; end
  end
  -- icefury,if=talent.fusion_of_elements.enabled&talent.echoes_of_great_sundering.enabled
  if S.Icefury:IsViable() and (S.FusionofElements:IsAvailable() and S.EchoesofGreatSundering:IsAvailable()) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 82"; end
  end
  -- lava_beam,if=buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 84"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsViable() then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 86"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and Player:IsMoving() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock moving aoe 88"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 90"; end
  end
end

local function SingleTarget()
  -- fire_elemental,if=!buff.fire_elemental.up
  if S.FireElemental:IsCastable() and (not Shaman.FireElemental.GreaterActive) then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental single_target 2"; end
  end
  -- storm_elemental,if=!buff.storm_elemental.up
  if S.StormElemental:IsCastable() and (not Shaman.StormElemental.GreaterActive) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental single_target 4"; end
  end
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>15&spell_targets.chain_lightning>1
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 15 and Shaman.ClusterTargets > 1) then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_target 6"; end
  end
  -- liquid_magma_totem,if=!buff.ascendance.up&talent.fire_elemental.enabled
  if S.LiquidMagmaTotem:IsCastable() and (Player:BuffDown(S.AscendanceBuff) and S.FireElemental:IsAvailable()) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 8"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=(!buff.surge_of_power.up&spell_targets.chain_lightning=1)|active_dot.flame_shock=0|talent.fire_elemental.enabled&(talent.skybreakers_fiery_demise.enabled|talent.deeply_rooted_elements.enabled)|(buff.surge_of_power.up|!talent.surge_of_power.enabled)&spell_targets.chain_lightning>1
  if S.PrimordialWave:IsViable() and ((Player:BuffDown(S.SurgeofPowerBuff) and Shaman.ClusterTargets == 1) or S.FlameShockDebuff:AuraActiveCount() == 0 or S.FireElemental:IsAvailable() and (S.SkybreakersFieryDemise:IsAvailable() or S.DeeplyRootedElements:IsAvailable()) or (Player:BuffUp(S.SurgeofPowerBuff) or not S.SurgeofPower:IsAvailable()) and Shaman.ClusterTargets > 1) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.Signature) then return "primordial_wave single_target 10"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies=1&(dot.flame_shock.remains<2|active_dot.flame_shock=0)&(dot.flame_shock.remains<cooldown.primordial_wave.remains|!talent.primordial_wave.enabled)&(dot.flame_shock.remains<cooldown.liquid_magma_totem.remains|!talent.liquid_magma_totem.enabled)&!buff.surge_of_power.up&talent.fire_elemental.enabled
  if S.FlameShock:IsCastable() and (Shaman.ClusterTargets == 1 and Player:BuffDown(S.SurgeofPowerBuff) and S.FireElemental:IsAvailable()) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, EvaluateTargetIfFlameShockST, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 12"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_dot.flame_shock=0&active_enemies>1&(spell_targets.chain_lightning>1|spell_targets.lava_beam>1)&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(!buff.master_of_the_elements.up&(buff.stormkeeper.up|cooldown.stormkeeper.remains=0)|!talent.surge_of_power.enabled)
  if S.FlameShock:IsCastable() and (S.FlameShockDebuff:AuraActiveCount() == 0 and Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (not Player:MotEUp() and (Player:StormkeeperUp() or S.Stormkeeper:CooldownUp()) or not S.SurgeofPower:IsAvailable())) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 14"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=spell_targets.chain_lightning>1&refreshable&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(buff.surge_of_power.up&!buff.stormkeeper.up&!cooldown.stormkeeper.remains=0|!talent.surge_of_power.enabled),cycle_targets=1
  if S.FlameShock:IsCastable() and (Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (Player:BuffUp(S.SurgeofPowerBuff) and not Player:StormkeeperUp() and S.Stormkeeper:CooldownDown() or not S.SurgeofPower:IsAvailable())) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, EvaluateTargetIfFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 16"; end
  end
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up
  if S.Stormkeeper:IsViable() and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperUp()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 18"; end
  end
  -- tempest
  -- TODO: Verify tempest ability spell ID.
  if S.TempestAbility:IsReady() then
    if Cast(S.TempestAbility, nil, nil, not Target:IsSpellInRange(S.TempestAbility)) then return "tempest single_target 20"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:StormkeeperUp() and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 22"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.stormkeeper.up&!buff.master_of_the_elements.up&!talent.surge_of_power.enabled&talent.master_of_the_elements.enabled
  if S.LavaBurst:IsViable() and (Player:StormkeeperUp() and not Player:MotEUp() and not S.SurgeofPower:IsAvailable() and S.MasteroftheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 24"; end
  end
  -- lava_beam,if=spell_targets.lava_beam>1&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if S.LavaBeam:IsViable() and (Shaman.ClusterTargets > 1 and Player:StormkeeperUp() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 26"; end
  end
  -- chain_lightning,if=spell_targets.chain_lightning>1&buff.stormkeeper.up&!talent.surge_of_power.enabled
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets > 1 and Player:StormkeeperUp() and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 28"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&(buff.master_of_the_elements.up|!talent.master_of_the_elements.enabled)
  if S.LightningBolt:IsViable() and (Player:StormkeeperUp() and not S.SurgeofPower:IsAvailable() and (Player:MotEUp() or not S.MasteroftheElements:IsAvailable())) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 30"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up&!buff.ascendance.up&talent.echo_chamber.enabled
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffDown(S.AscendanceBuff) and S.EchoChamber:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 32"; end
  end
  -- ascendance,if=cooldown.lava_burst.charges_fractional<1.0
  if S.Ascendance:IsCastable() and (S.LavaBurst:ChargesFractional() < 1) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single_target 34"; end
  end
  -- lava_beam,if=spell_targets.lava_beam>1&buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time&!set_bonus.tier31_4pc
  if S.LavaBeam:IsViable() and (Shaman.ClusterTargets > 1 and Player:BuffUp(S.PoweroftheMaelstromBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime() and not Player:HasTier(31, 4)) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam single_target 36"; end
  end
  -- lava_burst,if=cooldown_react&buff.lava_surge.up&(talent.deeply_rooted_elements.enabled|!talent.master_of_the_elements.enabled)
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and (S.DeeplyRootedElements:IsAvailable() or not S.MasteroftheElements:IsAvailable())) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 38"; end
  end
  -- earthquake,if=buff.master_of_the_elements.up&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(buff.fusion_of_elements_nature.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>9|!buff.ascendance.up)
  if S.Earthquake:IsReady() and (Player:MotEUp() and Player:BuffUp(S.EchoesofGreatSunderingBuff) and (Player:BuffUp(S.FusionofElementsNature) or Player:MaelstromP() > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 9 or Player:BuffDown(S.AscendanceBuff))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 40"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=buff.master_of_the_elements.up&(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>6|!buff.ascendance.up)
  if S.ElementalBlast:IsViable() and (Player:MotEUp() and (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire) or Player:MaelstromP() > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 6 or Player:BuffDown(S.AscendanceBuff))) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 42"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=buff.master_of_the_elements.up&(buff.fusion_of_elements_nature.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>9|!buff.ascendance.up)
  if S.EarthShock:IsReady() and (Player:MotEUp() and (Player:BuffUp(S.FusionofElementsNature) or Player:MaelstromP() > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 9 or Player:BuffDown(S.AscendanceBuff))) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 44"; end
  end
  -- icefury,if=!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)&buff.icefury.stack=2&(talent.fusion_of_elements.enabled|!buff.ascendance.up)
  if S.Icefury:IsViable() and (not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire)) and Player:BuffStack(S.IcefuryBuff) == 2 and (S.FusionofElements:IsAvailable() or Player:BuffDown(S.AscendanceBuff))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 46"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.ascendance.up
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.AscendanceBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 48"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&talent.fire_elemental.enabled
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and S.FireElemental:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 50"; end
  end
  -- lava_burst,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&(maelstrom>=82-10*talent.eye_of_the_storm.enabled|maelstrom>=52-5*talent.eye_of_the_storm.enabled&(!talent.elemental_blast.enabled|buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|spell_targets.chain_lightning>1&!talent.echoes_of_great_sundering.enabled))&(debuff.lightning_rod.remains<2|!debuff.lightning_rod.up)
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and (Player:MaelstromP() >= 82 - 10 * num(S.EyeoftheStorm:IsAvailable()) or Player:MaelstromP() >= 52 - 5 * num(S.EyeoftheStorm:IsAvailable()) and (not S.ElementalBlast:IsAvailable() or Player:BuffUp(S.EchoesofGreatSunderingBuff) or Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable())) and (Target:DebuffRemains(S.LightningRodDebuff) < 2 or Target:DebuffDown(S.LightningRodDebuff))) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 52"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(maelstrom>variable.mael_cap-20|!talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled|buff.stormkeeper.up&talent.lightning_rod.enabled)
  -- Note: Buff ID for echoes_of_great_sundering_eb and echoes_of_great_sundering_es is the same.
  if S.Earthquake:IsReady() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and (Player:MaelstromP() > VarMaelCap - 20 or not S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() or Player:StormkeeperUp() and S.LightningRod:IsAvailable())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 52"; end
  end
  -- earthquake,if=spell_targets.chain_lightning>1&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled&(maelstrom>variable.mael_cap-20|!talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled|buff.stormkeeper.up&talent.lightning_rod.enabled)
  if S.Earthquake:IsReady() and (Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable() and (Player:MaelstromP() > VarMaelCap - 20 or not S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() or Player:StormkeeperUp() and S.LightningRod:IsAvailable())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 54"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=maelstrom>variable.mael_cap-20|!talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled
  if S.ElementalBlast:IsViable() and (Player:MaelstromP() > VarMaelCap - 20 or not S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 56"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=maelstrom>variable.mael_cap-20|!talent.master_of_the_elements.enabled&!talent.lightning_rod.enabled|(buff.stormkeeper.up&talent.lightning_rod.enabled)
  if S.EarthShock:IsReady() and (Player:MaelstromP() > VarMaelCap - 20 or not S.MasteroftheElements:IsAvailable() and not S.LightningRod:IsAvailable() or (Player:StormkeeperUp() and S.LightningRod:IsAvailable())) then
    if Cast(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 58"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 60"; end
  end
  -- icefury,if=!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)
  if S.Icefury:IsViable() and (not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 62"; end
  end
  -- frost_shock,if=buff.icefury_dmg.up
  if S.FrostShock:IsCastable() and (Player:IcefuryUp()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 64"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning>1
  if S.ChainLightning:IsViable() and (Player:BuffUp(S.PoweroftheMaelstromBuff) and Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 66"; end
  end
  -- lightning_bolt,if=buff.power_of_the_maelstrom.up
  if S.LightningBolt:IsViable() and (Player:PotMUp()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 68"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 70"; end
  end
  -- chain_lightning,if=spell_targets.chain_lightning>1
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets > 1) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 72"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsViable() then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 74"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and (Player:IsMoving()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 76"; end
  end
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 78"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 80"; end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    Shaman.ClusterTargets = Target:GetEnemiesInSplashRangeCount(10)
  else
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
  if Everyone.TargetIsValid() or Player:AffectingCombat() or Settings.Commons.ShieldsOOC then
    local EarthShieldBuff = (S.ElementalOrbit:IsAvailable()) and S.EarthShieldSelfBuff or S.EarthShieldOtherBuff
    if (S.ElementalOrbit:IsAvailable() or Settings.Commons.PreferEarthShield) and S.EarthShield:IsReady() and (Player:BuffDown(EarthShieldBuff) or (not Player:AffectingCombat() and Player:BuffStack(EarthShieldBuff) < 5)) then
      if Cast(S.EarthShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Earth Shield Refresh"; end
    elseif (S.ElementalOrbit:IsAvailable() or not Settings.Commons.PreferEarthShield) and S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) then
      if Cast(S.LightningShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Lightning Shield Refresh" end
    end
  end

  -- Weapon Buff Handling
  if Everyone.TargetIsValid() or Player:AffectingCombat() or Settings.Commons.WeaponBuffsOOC then
    -- Check weapon enchants
    HasMainHandEnchant, MHEnchantTimeRemains = GetWeaponEnchantInfo()
    -- flametongue_weapon,if=talent.improved_flametongue_weapon.enabled
    if S.ImprovedFlametongueWeapon:IsAvailable() and (not HasMainHandEnchant or MHEnchantTimeRemains < 600000) and S.FlametongueWeapon:IsViable() then
      if Cast(S.FlametongueWeapon) then return "flametongue_weapon enchant"; end
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
    local ShouldReturn = Everyone.Interrupt(S.WindShear, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    if CDsON() then
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 2"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 4"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 6"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 8"; end
      end
    end
    -- use_items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- natures_swiftness
    if S.NaturesSwiftness:IsCastable() and Player:BuffDown(S.NaturesSwiftness) then
      if Cast(S.NaturesSwiftness, Settings.CommonsOGCD.GCDasOffGCD.NaturesSwiftness) then return "natures_swiftness main 12"; end
    end
    -- ancestral_swiftness
    if S.AncestralSwiftness:IsCastable() then
      if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness main 14"; end
    end
    -- invoke_external_buff,name=power_infusion
    -- Note: Not handling external buffs.
    -- potion
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 14"; end
      end
    end
    -- run_action_list,name=aoe,if=spell_targets.chain_lightning>2
    if AoEON() and (Shaman.ClusterTargets > 2) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "POOL") then return "Pool for Aoe()"; end
    end
    -- run_action_list,name=single_target
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "POOL") then return "Pool for SingleTarget()"; end
  end
end

local function Init()
  S.FlameShockDebuff:RegisterAuraTracking()

  HR.Print("Elemental Shaman rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(262, APL, Init)
