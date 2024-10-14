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
local mathmin           = math.min
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
local VarMaelstrom
local VarMaelCap = 100 + 50 * num(S.SwellingMaelstrom:IsAvailable()) + 25 * num(S.PrimordialCapacity:IsAvailable())
local BossFightRemains = 11111
local FightRemains = 11111
local HasMainHandEnchant, MHEnchantTimeRemains
local Enemies40y, Enemies10ySplash
Shaman.ClusterTargets = 0

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarSpymasterIn1st, VarSpymasterIn2nd
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarSpymasterIn1st = T1.ID == I.SpymastersWeb:ID()
  VarSpymasterIn2nd = T2.ID == I.SpymastersWeb:ID()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

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
local function RollingThunderNextTick()
  return 50 - (GetTime() - Shaman.LastRollingThunderTick)
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
local function EvaluateTargetIfEarthquakeAoE(TargetUnit)
  -- if=(debuff.lightning_rod.remains=0&talent.lightning_rod.enabled|maelstrom>variable.mael_cap-30)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering.enabled)
  -- Note: Buff checked before CastTargetIf.
  return TargetUnit:DebuffDown(S.LightningRodDebuff) and S.LightningRod:IsAvailable() or VarMaelstrom > VarMaelCap - 30
end

local function EvaluateTargetIfFlameShockST(TargetUnit)
  -- if=active_enemies=1&(dot.flame_shock.remains<2|active_dot.flame_shock=0)&(dot.flame_shock.remains<cooldown.primordial_wave.remains|!talent.primordial_wave.enabled)&(dot.flame_shock.remains<cooldown.liquid_magma_totem.remains|!talent.liquid_magma_totem.enabled)&!buff.surge_of_power.up&talent.fire_elemental.enabled
  -- Note: Target count, SoP buff, and FireElemental talent checked before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff) < 2 or S.FlameShockDebuff:AuraActiveCount() == 0) and (TargetUnit:DebuffRemains(S.FlameShockDebuff) < S.PrimordialWave:CooldownRemains() or not S.PrimordialWave:IsAvailable()) and (TargetUnit:DebuffRemains(S.FlameShockDebuff) < S.LiquidMagmaTotem:CooldownRemains() or not S.LiquidMagmaTotem:IsAvailable())
end

local function EvaluateTargetIfFlameShockST2(TargetUnit)
  -- if=spell_targets.chain_lightning>1&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(buff.surge_of_power.up&!buff.stormkeeper.up|!talent.surge_of_power.enabled)&dot.flame_shock.remains<6&talent.fire_elemental.enabled,cycle_targets=1
  -- Note: All but dot.flame_shock.remains<6 checked before CastTargetIf.
  return TargetUnit:DebuffRemains(S.FlameShockDebuff) < 6
end

local function EvaluateTargetIfSpenderST(TargetUnit)
  -- if=maelstrom>variable.mael_cap-15|debuff.lightning_rod.remains<gcd|fight_remains<5
  return VarMaelstrom > VarMaelCap - 15 or TargetUnit:DebuffRemains(S.LightningRodDebuff) < Player:GCD() or BossFightRemains < 5
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
  -- lightning_shield
  -- thunderstrike_ward
  -- Note: Moved above 3 lines to APL()
  -- stormkeeper
  if S.Stormkeeper:IsViable() then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- variable,name=mael_cap,value=100+50*talent.swelling_maelstrom.enabled+25*talent.primordial_capacity.enabled,op=set
  -- variable,name=spymaster_in_1st,value=trinket.1.is.spymasters_web
  -- variable,name=spymaster_in_2nd,value=trinket.2.is.spymasters_web
  -- Note: Moved above to variable declarations.
  -- Manually added: Opener abilities
  if S.StormElemental:IsReady() and (not Shaman.StormElemental.GreaterActive) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental precombat 6"; end
  end
  if S.Stormkeeper:IsViable() and (not Player:StormkeeperUp()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 8"; end
  end
  if S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 10"; end
  end
  if S.AncestralSwiftness:IsReady() then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness precombat 12"; end
  end
  if S.LavaBurst:IsViable() then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lavaburst precombat 12"; end
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
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>15&(active_dot.flame_shock<(spell_targets.chain_lightning>?6)-2|talent.fire_elemental.enabled)
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 15 and (S.FlameShockDebuff:AuraActiveCount() < (mathmin(Shaman.ClusterTargets, 6) - 2) or S.FireElemental:IsAvailable())) then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall aoe 8"; end
  end
  -- liquid_magma_totem
  if S.LiquidMagmaTotem:IsReady() then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem aoe 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=buff.surge_of_power.up|!talent.surge_of_power.enabled|maelstrom<60-5*talent.eye_of_the_storm.enabled
  if S.PrimordialWave:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff) or not S.SurgeofPower:IsAvailable() or VarMaelstrom < 60 - 5 * num(S.EyeoftheStorm:IsAvailable())) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.PrimordialWave) then return "primordial_wave aoe 12"; end
  end
  -- ancestral_swiftness
  if S.AncestralSwiftness:IsReady() then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness aoe 14"; end
  end
  if S.FlameShock:IsCastable() then
    local Lowest, BestTarget = LowestFlameShock(Enemies10ySplash)
    if BestTarget:DebuffRefreshable(S.FlameShockDebuff) then
      -- flame_shock,target_if=refreshable,if=buff.surge_of_power.up&talent.lightning_rod.enabled&dot.flame_shock.remains<target.time_to_die-16&active_dot.flame_shock<(spell_targets.chain_lightning>?6)&!talent.liquid_magma_totem.enabled
      if Player:BuffUp(S.SurgeofPowerBuff) and S.LightningRod:IsAvailable() and Lowest < BestTarget:TimeToDie() - 16 and S.FlameShockDebuff:AuraActiveCount() < mathmin(Shaman.ClusterTargets, 6) and not S.LiquidMagmaTotem:IsAvailable() then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 16"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 16"; end
        end
      end
      -- flame_shock,target_if=min:dot.flame_shock.remains,if=buff.primordial_wave.up&buff.stormkeeper.up&maelstrom<60-5*talent.eye_of_the_storm.enabled-(8+2*talent.flow_of_power.enabled)*active_dot.flame_shock&spell_targets.chain_lightning>=6&active_dot.flame_shock<6
      if Player:BuffUp(S.PrimordialWaveBuff) and Player:StormkeeperUp() and VarMaelstrom < 60 - 5 * num(S.EyeoftheStorm:IsAvailable()) - (8 + 2 * num(S.FlowofPower:IsAvailable())) * S.FlameShockDebuff:AuraActiveCount() and Shaman.ClusterTargets >= 6 and S.FlameShockDebuff:AuraActiveCount() < 6 then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 18"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 18"; end
        end
      end
      -- flame_shock,target_if=refreshable,if=talent.fire_elemental.enabled&(buff.surge_of_power.up|!talent.surge_of_power.enabled)&dot.flame_shock.remains<target.time_to_die-5&(active_dot.flame_shock<6|dot.flame_shock.remains>0)
      if S.FireElemental:IsAvailable() and (Player:BuffUp(S.SurgeofPowerBuff) or not S.SurgeofPower:IsAvailable()) and BestTarget:DebuffRemains(S.FlameShockDebuff) < BestTarget:TimeToDie() - 5 and (S.FlameShockDebuff:AuraActiveCount() < 6 or BestTarget:DebuffRemains(S.FlameShockDebuff) > 0) then
        if Target:GUID() == BestTarget:GUID() then
          if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe main-target 20"; end
        else
          if CastLeftNameplate(BestTarget, S.FlameShock) then return "flame_shock aoe off-target 20"; end
        end
      end
    end
  end
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=!buff.arc_discharge.up
  if S.TempestAbility:IsReady() and (Player:BuffDown(S.ArcDischargeBuff)) then
    if Everyone.CastTargetIf(S.TempestAbility, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40)) then return "tempest aoe 22"; end
  end
  -- ascendance (JUST DO IT! https://i.kym-cdn.com/entries/icons/mobile/000/018/147/Shia_LaBeouf__Just_Do_It__Motivational_Speech_(Original_Video_by_LaBeouf__R%C3%B6nkk%C3%B6___Turner)_0-4_screenshot.jpg
  if S.Ascendance:IsCastable() then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe 32"; end
  end
  -- lava_beam,if=active_enemies>=6&buff.surge_of_power.up&buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Shaman.ClusterTargets >= 6 and Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 34"; end
  end
  -- chain_lightning,if=active_enemies>=6&buff.surge_of_power.up
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets >= 6 and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 36"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.primordial_wave.up&buff.stormkeeper.up&maelstrom<60-5*talent.eye_of_the_storm.enabled&spell_targets.chain_lightning>=6&talent.surge_of_power.enabled
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.PrimordialWaveBuff) and Player:StormkeeperUp() and VarMaelstrom < 60 - 5 * num(S.EyeoftheStorm:IsAvailable()) and Shaman.ClusterTargets >= 6 and S.SurgeofPower:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 38"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.primordial_wave.up&(buff.primordial_wave.remains<4|buff.lava_surge.up)
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffRemains(S.PrimordialWaveBuff) < 4 or Player:BuffUp(S.LavaSurgeBuff))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 40"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&!buff.master_of_the_elements.up&talent.master_of_the_elements.enabled&talent.fire_elemental.enabled
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and not Player:MotEUp() and S.MasteroftheElements:IsAvailable() and S.FireElemental:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 42"; end
  end
  -- earthquake,if=cooldown.primordial_wave.remains<gcd&talent.surge_of_power.enabled&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering.enabled)
  if S.Earthquake:IsReady() and (S.PrimordialWave:CooldownRemains() < Player:GCD() and S.SurgeofPower:IsAvailable() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 44"; end
  end
  -- earthquake,if=(lightning_rod=0&talent.lightning_rod.enabled|maelstrom>variable.mael_cap-30)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering.enabled)
  if S.Earthquake:IsReady() and ((S.LightningRodDebuff:AuraActiveCount() == 0 and S.LightningRod:IsAvailable() or VarMaelstrom > VarMaelCap - 30) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 46"; end
  end
  -- earthquake,if=buff.stormkeeper.up&spell_targets.chain_lightning>=6&talent.surge_of_power.enabled&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering.enabled)
  if S.Earthquake:IsReady() and (Player:StormkeeperUp() and Shaman.ClusterTargets >= 6 and S.SurgeofPower:IsAvailable() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 48"; end
  end
  -- earthquake,if=(buff.master_of_the_elements.up|spell_targets.chain_lightning>=5)&(buff.fusion_of_elements_nature.up|buff.ascendance.remains>9|!buff.ascendance.up)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering.enabled)&talent.fire_elemental.enabled
  if S.Earthquake:IsReady() and ((Player:MotEUp() or Shaman.ClusterTargets >= 5) and (Player:BuffUp(S.FusionofElementsNature) or Player:BuffRemains(S.AscendanceBuff) > 9 or Player:BuffDown(S.AscendanceBuff)) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable()) and S.FireElemental:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 50"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled&!buff.echoes_of_great_sundering_eb.up&(lightning_rod=0|maelstrom>variable.mael_cap-30)
  if S.ElementalBlast:IsViable() and (S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff) and (S.LightningRodDebuff:AuraActiveCount() == 0 or VarMaelstrom > VarMaelCap - 30)) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 52"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=talent.echoes_of_great_sundering.enabled&!buff.echoes_of_great_sundering_es.up&(lightning_rod=0|maelstrom>variable.mael_cap-30)
  if S.EarthShock:IsReady() and (S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff) and (S.LightningRodDebuff:AuraActiveCount() == 0 or VarMaelstrom > VarMaelCap - 30)) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 54"; end
  end
  -- icefury,if=talent.fusion_of_elements.enabled&!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)
  if S.Icefury:IsViable() and (S.FusionofElements:IsAvailable() and not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 56"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&!buff.ascendance.up&talent.fire_elemental.enabled
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and Player:BuffDown(S.AscendanceBuff) and S.FireElemental:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 58"; end
  end
  -- lava_beam,if=buff.stormkeeper.up&(buff.surge_of_power.up|spell_targets.lava_beam<6)
  if S.LavaBeam:IsViable() and (Player:StormkeeperUp() and (Player:BuffUp(S.SurgeofPowerBuff) or Shaman.ClusterTargets < 6)) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 60"; end
  end
  -- chain_lightning,if=buff.stormkeeper.up&(buff.surge_of_power.up|spell_targets.chain_lightning<6)
  if S.ChainLightning:IsViable() and (Player:StormkeeperUp() and (Player:BuffUp(S.SurgeofPowerBuff) or Shaman.ClusterTargets < 6)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 62"; end
  end
  -- lava_beam,if=buff.power_of_the_maelstrom.up&buff.ascendance.remains>cast_time&!buff.stormkeeper.up
  if S.LavaBeam:IsViable() and (Player:PotMUp() and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime() and not Player:StormkeeperUp()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 64"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up&!buff.stormkeeper.up
  if S.ChainLightning:IsViable() and (Player:PotMUp() and not Player:StormkeeperUp()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 66"; end
  end
  -- lava_beam,if=(buff.master_of_the_elements.up&spell_targets.lava_beam>=4|spell_targets.lava_beam>=5)&buff.ascendance.remains>cast_time&!buff.stormkeeper.up
  if S.LavaBeam:IsViable() and ((Player:MotEUp() and Shaman.ClusterTargets >= 4 or Shaman.ClusterTargets >= 5) and Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime() and not Player:StormkeeperUp()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 68"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 70"; end
  end
  -- lava_beam,if=buff.ascendance.remains>cast_time
  if S.LavaBeam:IsViable() and (Player:BuffRemains(S.AscendanceBuff) > S.LavaBeam:CastTime()) then
    if Cast(S.LavaBeam, nil, nil, not Target:IsSpellInRange(S.LavaBeam)) then return "lava_beam aoe 72"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsViable() then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 74"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and Player:IsMoving() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock moving aoe 76"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() and Player:IsMoving() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 78"; end
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
  -- stormkeeper,if=!buff.ascendance.up&!buff.stormkeeper.up
  if S.Stormkeeper:IsViable() and (Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperUp()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 6"; end
  end
  -- totemic_recall,if=cooldown.liquid_magma_totem.remains>15&spell_targets.chain_lightning>1&talent.fire_elemental.enabled
  if S.TotemicRecall:IsCastable() and (S.LiquidMagmaTotem:CooldownRemains() > 15 and Shaman.ClusterTargets > 1 and S.FireElemental:IsAvailable()) then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_target 8"; end
  end
  -- liquid_magma_totem,if=!buff.ascendance.up&(talent.fire_elemental.enabled|spell_targets.chain_lightning>1)
  if S.LiquidMagmaTotem:IsCastable() and (Player:BuffDown(S.AscendanceBuff) and (S.FireElemental:IsAvailable() or Shaman.ClusterTargets > 1)) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=spell_targets.chain_lightning=1|buff.surge_of_power.up|!talent.surge_of_power.enabled|maelstrom<60-5*talent.eye_of_the_storm.enabled|talent.liquid_magma_totem.enabled
  if S.PrimordialWave:IsViable() and (Shaman.ClusterTargets == 1 or Player:BuffUp(S.SurgeofPowerBuff) or not S.SurgeofPower:IsAvailable() or VarMaelstrom < 60 - 5 * num(S.EyeoftheStorm:IsAvailable()) or S.LiquidMagmaTotem:IsAvailable()) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.PrimordialWave) then return "primordial_wave single_target 12"; end
  end
  -- ancestral_swiftness,if=!buff.primordial_wave.up|!buff.stormkeeper.up|!talent.elemental_blast.enabled
  if S.AncestralSwiftness:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff) or not Player:StormkeeperUp() or not S.ElementalBlast:IsAvailable()) then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness single_target 14"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_enemies=1&(dot.flame_shock.remains<2|active_dot.flame_shock=0)&(dot.flame_shock.remains<cooldown.primordial_wave.remains|!talent.primordial_wave.enabled)&(dot.flame_shock.remains<cooldown.liquid_magma_totem.remains|!talent.liquid_magma_totem.enabled)&!buff.surge_of_power.up&talent.fire_elemental.enabled
  if S.FlameShock:IsCastable() and (Shaman.ClusterTargets == 1 and (Target:DebuffRemains(S.FlameShockDebuff) < 2 or S.FlameShockDebuff:AuraActiveCount() == 0) and (Target:DebuffRemains(S.FlameShockDebuff) < S.PrimordialWave:CooldownRemains() or not S.PrimordialWave:IsAvailable()) and (Target:DebuffRemains(S.FlameShockDebuff) < S.LiquidMagmaTotem:CooldownRemains() or not S.LiquidMagmaTotem:IsAvailable()) and Player:BuffDown(S.SurgeofPowerBuff) and S.FireElemental:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 16"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=active_dot.flame_shock<active_enemies&spell_targets.chain_lightning>1&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(!buff.surge_of_power.up&buff.stormkeeper.up|!talent.surge_of_power.enabled|cooldown.ascendance.remains=0&talent.ascendance.enabled)&!talent.liquid_magma_totem.enabled
  if S.FlameShock:IsCastable() and (S.FlameShockDebuff:AuraActiveCount() < Shaman.ClusterTargets and Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (Player:BuffDown(S.SurgeofPowerBuff) and Player:StormkeeperUp() or not S.SurgeofPower:IsAvailable() or S.Ascendance:CooldownUp() and S.Ascendance:IsAvailable()) and not S.LiquidMagmaTotem:IsAvailable()) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 18"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=spell_targets.chain_lightning>1&(talent.deeply_rooted_elements.enabled|talent.ascendance.enabled|talent.primordial_wave.enabled|talent.searing_flames.enabled|talent.magma_chamber.enabled)&(buff.surge_of_power.up&!buff.stormkeeper.up|!talent.surge_of_power.enabled)&dot.flame_shock.remains<6&talent.fire_elemental.enabled,cycle_targets=1
  if S.FlameShock:IsCastable() and (Shaman.ClusterTargets > 1 and (S.DeeplyRootedElements:IsAvailable() or S.Ascendance:IsAvailable() or S.PrimordialWave:IsAvailable() or S.SearingFlames:IsAvailable() or S.MagmaChamber:IsAvailable()) and (Player:BuffUp(S.SurgeofPowerBuff) and not Player:StormkeeperUp() or not S.SurgeofPower:IsAvailable()) and S.FireElemental:IsAvailable()) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterFlameShockRemains, EvaluateTargetIfFlameShockST2, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 20"; end
  end
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=!buff.arc_discharge.up
  if S.TempestAbility:IsReady() and (Player:BuffDown(S.ArcDischargeBuff)) then
    if Everyone.CastTargetIf(S.TempestAbility, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40)) then return "tempest single_target 22"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:StormkeeperUp() and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 24"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.stormkeeper.up&!buff.master_of_the_elements.up&!talent.surge_of_power.enabled&talent.master_of_the_elements.enabled
  if S.LavaBurst:IsViable() and (Player:StormkeeperUp() and not Player:MotEUp() and not S.SurgeofPower:IsAvailable() and S.MasteroftheElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 26"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&!talent.surge_of_power.enabled&(buff.master_of_the_elements.up|!talent.master_of_the_elements.enabled)
  if S.LightningBolt:IsViable() and (Player:StormkeeperUp() and not S.SurgeofPower:IsAvailable() and (Player:MotEUp() or not S.MasteroftheElements:IsAvailable())) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 28"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up&!buff.ascendance.up&talent.echo_chamber.enabled
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff) and Player:BuffDown(S.AscendanceBuff) and S.EchoChamber:IsAvailable()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 30"; end
  end
  -- ascendance,if=cooldown.lava_burst.charges_fractional<1.0
  if S.Ascendance:IsCastable() and (S.LavaBurst:ChargesFractional() < 1) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single_target 32"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&talent.fire_elemental.enabled
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and S.FireElemental:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 34"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.primordial_wave.up
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.PrimordialWaveBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 36"; end
  end
  -- earthquake,if=buff.master_of_the_elements.up&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|spell_targets.chain_lightning>1&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled)&(buff.fusion_of_elements_nature.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>9|!buff.ascendance.up)&talent.fire_elemental.enabled
  if S.Earthquake:IsReady() and (Player:MotEUp() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable()) and (Player:BuffUp(S.FusionofElementsNature) or VarMaelstrom > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 9 or Player:BuffDown(S.AscendanceBuff)) and S.FireElemental:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 38"; end
  end
  -- elemental_blast,if=buff.master_of_the_elements.up&(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>6|!buff.ascendance.up)&talent.fire_elemental.enabled
  if S.ElementalBlast:IsViable() and (Player:MotEUp() and (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire) or VarMaelstrom > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 6 or Player:BuffDown(S.AscendanceBuff)) and S.FireElemental:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 40"; end
  end
  -- earth_shock,if=buff.master_of_the_elements.up&(buff.fusion_of_elements_nature.up|maelstrom>variable.mael_cap-15|buff.ascendance.remains>9|!buff.ascendance.up)&talent.fire_elemental.enabled
  if S.EarthShock:IsReady() and (Player:MotEUp() and (Player:BuffUp(S.FusionofElementsNature) or VarMaelstrom > VarMaelCap - 15 or Player:BuffRemains(S.AscendanceBuff) > 9 or Player:BuffDown(S.AscendanceBuff)) and S.FireElemental:IsAvailable()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 42"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|spell_targets.chain_lightning>1&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled)&(buff.stormkeeper.up|cooldown.primordial_wave.remains<gcd&talent.surge_of_power.enabled&!talent.liquid_magma_totem.enabled)&talent.storm_elemental.enabled
  if S.Earthquake:IsReady() and ((Player:BuffUp(S.EchoesofGreatSunderingBuff) or Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable()) and (Player:StormkeeperUp() or S.PrimordialWave:CooldownRemains() < Player:GCD() and S.SurgeofPower:IsAvailable() and not S.LiquidMagmaTotem:IsAvailable()) and S.StormElemental:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 44"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=buff.stormkeeper.up&talent.storm_elemental.enabled
  if S.ElementalBlast:IsViable() and (Player:StormkeeperUp() and S.StormElemental:IsAvailable()) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 46"; end
  end
  -- earth_shock,if=((buff.master_of_the_elements.up|lightning_rod=0)&cooldown.stormkeeper.remains>10&(rolling_thunder.next_tick>5|!talent.rolling_thunder.enabled)|buff.stormkeeper.up)&talent.storm_elemental.enabled&spell_targets.chain_lightning=1
  if S.EarthShock:IsReady() and (((Player:MotEUp() or S.LightningRodDebuff:AuraActiveCount() == 0) and S.Stormkeeper:CooldownRemains() > 10 and (RollingThunderNextTick() > 5 or not S.RollingThunder:IsAvailable()) or Player:StormkeeperUp()) and S.StormElemental:IsAvailable() and Shaman.ClusterTargets == 1) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 48"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=(cooldown.primordial_wave.remains<gcd&talent.surge_of_power.enabled&!talent.liquid_magma_totem.enabled|buff.stormkeeper.up)&talent.storm_elemental.enabled&spell_targets.chain_lightning>1&talent.echoes_of_great_sundering.enabled&!buff.echoes_of_great_sundering_es.up
  if S.EarthShock:IsReady() and ((S.PrimordialWave:CooldownRemains() < Player:GCD() and S.SurgeofPower:IsAvailable() and not S.LiquidMagmaTotem:IsAvailable() or Player:StormkeeperUp()) and S.StormElemental:IsAvailable() and Shaman.ClusterTargets > 1 and S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff)) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 49"; end
  end
  -- icefury,if=!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)&buff.icefury.stack=2&(talent.fusion_of_elements.enabled|!buff.ascendance.up)
  if S.Icefury:IsViable() and (not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire)) and Player:BuffStack(S.IcefuryBuff) == 2 and (S.FusionofElements:IsAvailable() or Player:BuffDown(S.AscendanceBuff))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 50"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.ascendance.up
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.AscendanceBuff)) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 52"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.master_of_the_elements.enabled&!buff.master_of_the_elements.up&talent.fire_elemental.enabled
  if S.LavaBurst:IsViable() and (S.MasteroftheElements:IsAvailable() and not Player:MotEUp() and S.FireElemental:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 54"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=buff.stormkeeper.up&talent.elemental_reverb.enabled&talent.earth_shock.enabled&time<10
  if S.LavaBurst:IsViable() and (Player:StormkeeperUp() and S.ElementalReverb:IsAvailable() and S.EarthShock:IsAvailable() and HL.CombatTime() < 10) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 56"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|spell_targets.chain_lightning>1&!talent.echoes_of_great_sundering.enabled&!talent.elemental_blast.enabled)&(maelstrom>variable.mael_cap-35|fight_remains<5)
  if S.Earthquake:IsReady() and ((Player:BuffUp(S.EchoesofGreatSunderingBuff) or Shaman.ClusterTargets > 1 and not S.EchoesofGreatSundering:IsAvailable() and not S.ElementalBlast:IsAvailable()) and (VarMaelstrom > VarMaelCap - 35 or BossFightRemains < 5)) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 58"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=maelstrom>variable.mael_cap-15|fight_remains<5
  if S.ElementalBlast:IsViable() and (VarMaelstrom > VarMaelCap - 15 or BossFightRemains < 5) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 60"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=maelstrom>variable.mael_cap-15|fight_remains<5
  if S.EarthShock:IsReady() and (VarMaelstrom > VarMaelCap - 15 or BossFightRemains < 5) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "max", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 62"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 64"; end
  end
  -- icefury,if=!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)
  if S.Icefury:IsViable() and (not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 66"; end
  end
  -- frost_shock,if=buff.icefury_dmg.up&(spell_targets.chain_lightning=1|buff.stormkeeper.up&talent.surge_of_power.enabled)
  if S.FrostShock:IsCastable() and (Player:IcefuryUp() and (Shaman.ClusterTargets == 1 or Player:StormkeeperUp() and S.SurgeofPower:IsAvailable())) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 68"; end
  end
  -- chain_lightning,if=buff.power_of_the_maelstrom.up&spell_targets.chain_lightning>1&!buff.stormkeeper.up
  if S.ChainLightning:IsViable() and (Player:PotMUp() and Shaman.ClusterTargets > 1 and not Player:StormkeeperUp()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 70"; end
  end
  -- lightning_bolt,if=buff.power_of_the_maelstrom.up&!buff.stormkeeper.up
  if S.LightningBolt:IsViable() and (Player:PotMUp() and not Player:StormkeeperUp()) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 72"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=talent.deeply_rooted_elements.enabled
  if S.LavaBurst:IsViable() and (S.DeeplyRootedElements:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 74"; end
  end
  -- chain_lightning,if=spell_targets.chain_lightning>1&!buff.stormkeeper.up
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets > 1 and not Player:StormkeeperUp()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single_target 76"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsViable() then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 78"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsCastable() and (Player:IsMoving()) then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 80"; end
  end
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 82"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsCastable() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 84"; end
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

    -- Store our Maelstrom count into a variable
    VarMaelstrom = Player:MaelstromP()
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

  -- ThunderstrikeWard Handling
  local ShieldEnchantID = select(8, GetWeaponEnchantInfo())
  if S.ThunderstrikeWard:IsReady() and (not ShieldEnchantID or ShieldEnchantID ~= 7587) then
    if Cast(S.ThunderstrikeWard) then return "thunderstrike_ward"; end
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
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,slot=trinket1,if=!variable.spymaster_in_1st|(fight_remains<45|time<fight_remains&buff.spymasters_report.stack=40)&cooldown.stormkeeper.remains<5|fight_remains<22
      if Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarSpymasterIn1st or (BossFightRemains < 45 or HL.CombatTime() < FightRemains and Player:BuffStack(S.SpymastersWebBuff) == 40) and S.Stormkeeper:CooldownRemains() < 5 or BossFightRemains < 22) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 ("..Trinket1:Name()..") main 10"; end
      end
      -- use_item,slot=trinket2,if=!variable.spymaster_in_2nd|(fight_remains<45|time<fight_remains&buff.spymasters_report.stack=40)&cooldown.stormkeeper.remains<5|fight_remains<22
      if Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarSpymasterIn2nd or (BossFightRemains < 45 or HL.CombatTime() < FightRemains and Player:BuffStack(S.SpymastersWebBuff) == 40) and S.Stormkeeper:CooldownRemains() < 5 or BossFightRemains < 22) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 ("..Trinket2:Name()..") main 12"; end
      end
    end
    if Settings.Commons.Enabled.Items then
      -- use_item,slot=main_hand
      local MHToUse, _, MHRange = Player:GetUseableItems(OnUseExcludes, 16)
      if MHToUse then
        if Cast(MHToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MHRange)) then return "use_item main_hand ("..MHToUse:Name()..") main 14"; end
      end
    end
    -- lightning_shield,if=buff.lightning_shield.down
    -- Note: Handled above.
    -- natures_swiftness
    if S.NaturesSwiftness:IsCastable() and Player:BuffDown(S.NaturesSwiftness) then
      if Cast(S.NaturesSwiftness, Settings.CommonsOGCD.GCDasOffGCD.NaturesSwiftness) then return "natures_swiftness main 12"; end
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
  S.LightningRodDebuff:RegisterAuraTracking()

  HR.Print("Elemental Shaman rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(262, APL, Init)
