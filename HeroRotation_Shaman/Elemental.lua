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
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarSpecialItems
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

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

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

  VarSpecialItems = VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.SpymastersWeb:ID() or (VarTrinket1ID == I.HouseofCards:ID() and not Trinket2:HasUseBuff() or VarTrinket2ID == I.HouseofCards:ID() and not Trinket1:HasUseBuff()) and S.FirstAscendant:IsAvailable()
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

local function EvaluateTargetIfFlameShockAoe(TargetUnit)
  -- if=cooldown.primordial_wave.remains<gcd&!dot.flame_shock.ticking&(talent.primordial_wave|spell_targets.chain_lightning<=3)&cooldown.ascendance.remains>10
  -- Note: All but !dot.flame_shock.ticking checked before CastTargetIf.
  return TargetUnit:DebuffDown(S.FlameShockDebuff)
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
  -- snapshot_stats
  -- flametongue_weapon,if=talent.improved_flametongue_weapon.enabled
  -- lightning_shield
  -- thunderstrike_ward
  -- Note: Moved above 3 lines to APL()
  -- variable,name=mael_cap,value=100+50*talent.swelling_maelstrom.enabled+25*talent.primordial_capacity.enabled
  -- variable,name=special_items,value=trinket.1.is.spymasters_web|trinket.2.is.spymasters_web|(trinket.1.is.house_of_cards&!trinket.2.has_use_buff|trinket.2.is.house_of_cards&!trinket.1.has_use_buff)&talent.first_ascendant
  -- Note: Moved above to variable declarations.
  -- stormkeeper
  if S.Stormkeeper:IsViable() and (not Player:StormkeeperUp()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper precombat 2"; end
  end
  -- Manually added: Opener abilities
  if S.StormElemental:IsViable() and (not Shaman.StormElemental.GreaterActive) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental precombat 4"; end
  end
  if S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 6"; end
  end
  if S.AncestralSwiftness:IsViable() then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness precombat 8"; end
  end
  if S.LavaBurst:IsViable() then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lavaburst precombat 10"; end
  end
end

local function Aoe()
  -- fire_elemental
  if S.FireElemental:IsViable() then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental aoe 2"; end
  end
  -- storm_elemental,if=!buff.storm_elemental.up|!talent.echo_of_the_elementals
  if S.StormElemental:IsViable() and ((not Shaman.StormElemental.GreaterActive and not Shaman.StormElemental.LesserActive) or not S.EchooftheElementals:IsAvailable()) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental aoe 4"; end
  end
  -- stormkeeper
  if S.Stormkeeper:IsViable() then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper aoe 6"; end
  end
  -- liquid_magma_totem,if=(cooldown.primordial_wave.remains<5*gcd|!talent.primordial_wave)&(active_dot.flame_shock<=active_enemies-3|active_dot.flame_shock<(active_enemies>?3))&cooldown.ascendance.remains>10
  if S.LiquidMagmaTotem:IsViable() and ((S.PrimordialWave:CooldownRemains() < 5 * Player:GCD() or not S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() <= Shaman.ClusterTargets - 3 or S.FlameShockDebuff:AuraActiveCount() < mathmin(Shaman.ClusterTargets, 3)) and S.Ascendance:CooldownRemains() > 10) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem aoe 8"; end
  end
  -- flame_shock,target_if=min:debuff.lightning_rod.remains,if=cooldown.primordial_wave.remains<gcd&!dot.flame_shock.ticking&(talent.primordial_wave|spell_targets.chain_lightning<=3)&cooldown.ascendance.remains>10
  if S.FlameShock:IsViable() and (S.PrimordialWave:CooldownRemains() < Player:GCD() and (S.PrimordialWave:IsAvailable() or Shaman.ClusterTargets <= 3) and S.Ascendance:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, EvaluateTargetIfFlameShockAoe, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 10"; end
  end
  -- primordial_wave,if=active_dot.flame_shock=active_enemies>?6|cooldown.liquid_magma_totem.remains>15|!talent.liquid_magma_totem
  if S.PrimordialWave:IsViable() and (S.FlameShockDebuff:AuraActiveCount() == mathmin(Shaman.ClusterTargets, 6) or S.LiquidMagmaTotem:CooldownRemains() > 15 or not S.LiquidMagmaTotem:IsAvailable()) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave aoe 12"; end
  end
  -- ancestral_swiftness
  if S.AncestralSwiftness:IsViable() then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness aoe 14"; end
  end
  -- ascendance,if=(talent.first_ascendant|fight_remains>200|fight_remains<90&buff.stormkeeper.stack>=2|buff.spymasters_web.up|!(trinket.1.is.spymasters_web|trinket.2.is.spymasters_web))&(buff.fury_of_storms.up|!talent.fury_of_the_storms)
  -- Note: JUST DO IT! https://i.kym-cdn.com/entries/icons/mobile/000/018/147/Shia_LaBeouf__Just_Do_It__Motivational_Speech_(Original_Video_by_LaBeouf__R%C3%B6nkk%C3%B6___Turner)_0-4_screenshot.jpg
  if CDsON() and S.Ascendance:IsCastable() and ((S.FirstAscendant:IsAvailable() or FightRemains > 200 or FightRemains < 90 and Player:BuffStack(S.StormkeeperBuff) >= 2 or Player:BuffUp(S.SpymastersWebBuff) or not (VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket2ID == I.SpymastersWeb:ID())) and (Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable())) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe 16"; end
  end
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=buff.arc_discharge.stack<2&(buff.surge_of_power.up|!talent.surge_of_power)
  if S.TempestAbility:IsViable() and (Player:BuffStack(S.ArcDischargeBuff) < 2 and (Player:BuffUp(S.SurgeofPowerBuff) or not S.SurgeofPower:IsAvailable())) then
    if Everyone.CastTargetIf(S.TempestAbility, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Tempest) then return "tempest aoe 18"; end
  end
  -- lightning_bolt,if=buff.stormkeeper.up&buff.surge_of_power.up&spell_targets.chain_lightning=2
  if S.LightningBolt:IsViable() and (Player:StormkeeperUp() and Player:BuffUp(S.SurgeofPowerBuff) and Shaman.ClusterTargets == 2) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 20"; end
  end
  -- chain_lightning,if=active_enemies>=6&buff.surge_of_power.up
  if S.ChainLightning:IsViable() and (Shaman.ClusterTargets >= 6 and Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 22"; end
  end
  -- chain_lightning,if=buff.storm_frenzy.stack=2&!talent.surge_of_power&maelstrom<variable.mael_cap-(15+buff.stormkeeper.up*spell_targets.chain_lightning*spell_targets.chain_lightning)
  if S.ChainLightning:IsViable() and (Player:BuffStack(S.StormFrenzyBuff) == 2 and not S.SurgeofPower:IsAvailable() and VarMaelstrom < VarMaelCap - (15 + num(Player:StormkeeperUp()) * Shaman.ClusterTargets * Shaman.ClusterTargets)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 22"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&buff.fusion_of_elements_fire.up&!buff.master_of_the_elements.up&(maelstrom>52-5*talent.eye_of_the_storm&(buff.echoes_of_great_sundering_es.up|!talent.echoes_of_great_sundering))
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and Player:BuffUp(S.FusionofElementsFire) and not Player:MotEUp() and (VarMaelstrom > 52 - 5 * num(S.EyeoftheStorm:IsAvailable() and Player:BuffUp(S.EchoesofGreatSunderingBuff)))) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 24"; end
  end
  -- earthquake,if=(maelstrom>variable.mael_cap-10*(spell_targets.chain_lightning+1)|buff.master_of_the_elements.up|buff.ascendance.up&buff.ascendance.remains<3|fight_remains<5)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering&(!talent.elemental_blast|active_enemies>1+talent.tempest))
  if S.Earthquake:IsViable() and ((VarMaelstrom > VarMaelCap - 10 * (Shaman.ClusterTargets + 1) or Player:MotEUp() or Player:BuffUp(S.AscendanceBuff) and Player:BuffRemains(S.AscendanceBuff) < 3 or BossFightRemains < 5) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable() and (not S.ElementalBlast:IsAvailable() or Shaman.ClusterTargets > 1 + num(S.Tempest:IsAvailable())))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 26"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=(maelstrom>variable.mael_cap-10*(spell_targets.chain_lightning+1)|buff.master_of_the_elements.up|buff.ascendance.up&buff.ascendance.remains<3|fight_remains<5)&(active_enemies<=1+talent.tempest|talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_eb.up)
  if S.ElementalBlast:IsViable() and ((VarMaelstrom > VarMaelCap - 10 * (Shaman.ClusterTargets + 1) or Player:MotEUp() or Player:BuffUp(S.AscendanceBuff) and Player:BuffRemains(S.AscendanceBuff) < 3 or BossFightRemains < 5) and (Shaman.ClusterTargets <= 1 + num(S.Tempest:IsAvailable()) or S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff))) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 28"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=(maelstrom>variable.mael_cap-10*(spell_targets.chain_lightning+1)|buff.master_of_the_elements.up|buff.ascendance.up&buff.ascendance.remains<3|fight_remains<5)&talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_es.up
  if S.EarthShock:IsViable() and ((VarMaelstrom > VarMaelCap - 10 * (Shaman.ClusterTargets + 1) or Player:MotEUp() or Player:BuffUp(S.AscendanceBuff) and Player:BuffRemains(S.AscendanceBuff) < 3 or BossFightRemains < 5) and S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff)) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 30"; end
  end
  -- earthquake,if=talent.lightning_rod&lightning_rod<active_enemies&(buff.stormkeeper.up|buff.tempest.up|!talent.surge_of_power)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering&(!talent.elemental_blast|active_enemies>1+talent.tempest))
  if S.Earthquake:IsViable() and (S.LightningRod:IsAvailable() and S.LightningRodDebuff:AuraActiveCount() < Shaman.ClusterTargets and (Player:StormkeeperUp() or Player:BuffUp(S.TempestBuff) or not S.SurgeofPower:IsAvailable()) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable() and (not S.ElementalBlast:IsAvailable() or Shaman.ClusterTargets > 1 + num(S.Tempest:IsAvailable())))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 32"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=talent.lightning_rod&lightning_rod<active_enemies&(buff.stormkeeper.up|buff.tempest.up|!talent.surge_of_power)&(active_enemies<=1+talent.tempest|talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_eb.up)
  if S.ElementalBlast:IsViable() and (S.LightningRod:IsAvailable() and S.LightningRodDebuff:AuraActiveCount() < Shaman.ClusterTargets and (Player:StormkeeperUp() or Player:BuffUp(S.TempestBuff) or not S.SurgeofPower:IsAvailable()) and (Shaman.ClusterTargets <= 1 + num(S.Tempest:IsAvailable()) or S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff))) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 34"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=talent.lightning_rod&lightning_rod<active_enemies&(buff.stormkeeper.up|buff.tempest.up|!talent.surge_of_power)&talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_es.up
  if S.EarthShock:IsViable() and (S.LightningRod:IsAvailable() and S.LightningRodDebuff:AuraActiveCount() < Shaman.ClusterTargets and (Player:StormkeeperUp() or Player:BuffUp(S.TempestBuff) or not S.SurgeofPower:IsAvailable()) and S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff)) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 36"; end
  end
  -- icefury,if=talent.fusion_of_elements&!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)&(active_enemies<=4|!talent.elemental_blast|!talent.echoes_of_great_sundering)
  if S.Icefury:IsViable() and (S.FusionofElements:IsAvailable() and not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire)) and (Shaman.ClusterTargets <= 4 or not S.ElementalBlast:IsAvailable() or not S.EchoesofGreatSundering:IsAvailable())) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury aoe 38"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains,if=cooldown_react&buff.lava_surge.up&!buff.master_of_the_elements.up&talent.master_of_the_elements&active_enemies<=3
  if S.LavaBurst:IsViable() and (Player:BuffUp(S.LavaSurgeBuff) and not Player:MotEUp() and S.MasteroftheElements:IsAvailable() and Shaman.ClusterTargets <= 3) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 40"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=!buff.master_of_the_elements.up&talent.master_of_the_elements&(buff.stormkeeper.up|buff.tempest.up|maelstrom>82-10*talent.eye_of_the_storm|maelstrom>52-5*talent.eye_of_the_storm&(buff.echoes_of_great_sundering_eb.up|!talent.elemental_blast))&active_enemies<=3&!talent.lightning_rod&talent.call_of_the_ancestors
  if S.LavaBurst:IsViable() and (not Player:MotEUp() and S.MasteroftheElements:IsAvailable() and (Player:StormkeeperUp() or Player:BuffUp(S.TempestBuff) or VarMaelstrom > 82 - 10 * num(S.EyeoftheStorm:IsAvailable()) or VarMaelstrom > 52 - 5 * num(S.EyeoftheStorm:IsAvailable()) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.ElementalBlast:IsAvailable())) and Shaman.ClusterTargets <= 3 and not S.LightningRod:IsAvailable() and S.CalloftheAncestors:IsAvailable()) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 42"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>2,if=!buff.master_of_the_elements.up&active_enemies=2
  if S.LavaBurst:IsViable() and (not Player:MotEUp() and Shaman.ClusterTargets == 2) then
    if Everyone.CastCycle(S.LavaBurst, Enemies10ySplash, EvaluateCycleFlameShockRemains2, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst aoe 44"; end
  end
  -- flame_shock,target_if=min:debuff.lightning_rod.remains,if=active_dot.flame_shock=0&buff.fusion_of_elements_fire.up&(!talent.elemental_blast|!talent.echoes_of_great_sundering&active_enemies>1+talent.tempest)
  if S.FlameShock:IsViable() and (S.FlameShockDebuff:AuraActiveCount() == 0 and Player:BuffUp(S.FusionofElementsFire) and (not S.ElementalBlast:IsAvailable() or not S.EchoesofGreatSundering:IsAvailable() and Shaman.ClusterTargets > 1 + num(S.Tempest:IsAvailable()))) then
    if Everyone.CastTargetIf(S.FlameShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, EvaluateTargetIfFlameShockAoe, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 46"; end
  end
  -- earthquake,if=((buff.stormkeeper.up&spell_targets.chain_lightning>=6|buff.tempest.up)&talent.surge_of_power)&(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up|!talent.echoes_of_great_sundering&(!talent.elemental_blast|active_enemies>1+talent.tempest))
  if S.Earthquake:IsViable() and (((Player:StormkeeperUp() and Shaman.ClusterTargets >= 6 or Player:BuffUp(S.TempestBuff)) and S.SurgeofPower:IsAvailable()) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.EchoesofGreatSundering:IsAvailable() and (not S.ElementalBlast:IsAvailable() or Shaman.ClusterTargets > 1 + num(S.Tempest:IsAvailable())))) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake aoe 48"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=((buff.stormkeeper.up&active_enemies>=6|buff.tempest.up)&talent.surge_of_power)&(active_enemies<=1+talent.tempest|talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_eb.up)
  if S.ElementalBlast:IsViable() and (((Player:StormkeeperUp() and Shaman.ClusterTargets >= 6 or Player:BuffUp(S.TempestBuff)) and S.SurgeofPower:IsAvailable()) and (Shaman.ClusterTargets <= 1 + num(S.Tempest:IsAvailable()) or S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff))) then
    if Everyone.CastTargetIf(S.ElementalBlast, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 50"; end
  end
  -- earth_shock,target_if=min:debuff.lightning_rod.remains,if=((buff.stormkeeper.up&active_enemies>=6|buff.tempest.up)&talent.surge_of_power)&talent.echoes_of_great_sundering&!buff.echoes_of_great_sundering_es.up
  if S.EarthShock:IsViable() and (((Player:StormkeeperUp() and Shaman.ClusterTargets >= 6 or Player:BuffUp(S.TempestBuff)) and S.SurgeofPower:IsAvailable()) and S.EchoesofGreatSundering:IsAvailable() and Player:BuffDown(S.EchoesofGreatSunderingBuff)) then
    if Everyone.CastTargetIf(S.EarthShock, Enemies10ySplash, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock aoe 52"; end
  end
  -- frost_shock,if=buff.icefury_dmg.up&!buff.ascendance.up&!buff.stormkeeper.up&talent.call_of_the_ancestors
  if S.FrostShock:IsViable() and (Player:IcefuryUp() and Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperUp() and S.CalloftheAncestors:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 54"; end
  end
  -- chain_lightning
  if S.ChainLightning:IsViable() then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 56"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  if S.FlameShock:IsViable() and Player:IsMoving() then
    if Everyone.CastCycle(S.FlameShock, Enemies10ySplash, EvaluateCycleFlameShockRefreshable, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock moving aoe 58"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsViable() and Player:IsMoving() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving aoe 60"; end
  end
end

local function SingleTarget()
  -- fire_elemental
  if S.FireElemental:IsViable() then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "fire_elemental single_target 2"; end
  end
  -- storm_elemental,if=!buff.storm_elemental.up|!talent.echo_of_the_elementals
  if S.StormElemental:IsViable() and ((not Shaman.StormElemental.GreaterActive and not Shaman.StormElemental.LesserActive) or not S.EchooftheElementals:IsAvailable()) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "storm_elemental single_target 4"; end
  end
  -- stormkeeper,if=!talent.fury_of_the_storms|cooldown.primordial_wave.remains<gcd|!talent.primordial_wave
  if S.Stormkeeper:IsViable() and (not S.FuryoftheStorms:IsAvailable() or S.PrimordialWave:CooldownRemains() < Player:GCD() or not S.PrimordialWave:IsAvailable()) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "stormkeeper single_target 6"; end
  end
  -- liquid_magma_totem,if=!dot.flame_shock.ticking&!buff.surge_of_power.up&!buff.master_of_the_elements.up
  if S.LiquidMagmaTotem:IsViable() and (Target:DebuffDown(S.FlameShockDebuff) and Player:BuffDown(S.SurgeofPowerBuff) and not Player:MotEUp()) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 8"; end
  end
  -- flame_shock,if=!dot.flame_shock.ticking&!buff.surge_of_power.up&!buff.master_of_the_elements.up
  if S.FlameShock:IsViable() and (Target:DebuffDown(S.FlameShockDebuff) and Player:BuffDown(S.SurgeofPowerBuff) and not Player:MotEUp()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 10"; end
  end
  -- primordial_wave
  if S.PrimordialWave:IsViable() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single_target 12"; end
  end
  -- ancestral_swiftness
  if S.AncestralSwiftness:IsViable() then
    if Cast(S.AncestralSwiftness, Settings.CommonsOGCD.GCDasOffGCD.AncestralSwiftness) then return "ancestral_swiftness single_target 14"; end
  end
  -- ascendance,if=(talent.first_ascendant|fight_remains>200|fight_remains<80|buff.spymasters_web.up|(trinket.1.has_use_buff&trinket.1.ready_cooldown|trinket.2.has_use_buff&trinket.2.ready_cooldown)&!variable.special_items)&(buff.fury_of_storms.up|!talent.fury_of_the_storms)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave)
  if CDsON() and S.Ascendance:IsCastable() and ((S.FirstAscendant:IsAvailable() or FightRemains > 200 or FightRemains < 80 or Player:BuffUp(S.SpymastersWebBuff) or (Trinket1:HasUseBuff() and Trinket1:CooldownUp() or Trinket2:HasUseBuff() and Trinket2:CooldownUp()) and not VarSpecialItems) and (Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable()) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable())) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single_target 16"; end
  end
  -- tempest,if=buff.surge_of_power.up
  if S.TempestAbility:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single_target 18"; end
  end
  -- lightning_bolt,if=buff.surge_of_power.up
  if S.LightningBolt:IsViable() and (Player:BuffUp(S.SurgeofPowerBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 20"; end
  end
  -- tempest,if=buff.storm_frenzy.stack=2&!talent.surge_of_power.enabled
  if S.TempestAbility:IsViable() and (Player:BuffStack(S.StormFrenzyBuff) == 2 and not S.SurgeofPower:IsAvailable()) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single_target 22"; end
  end
  -- liquid_magma_totem,if=dot.flame_shock.refreshable&!buff.master_of_the_elements.up
  if S.LiquidMagmaTotem:IsViable() and (Target:DebuffRefreshable(S.FlameShockDebuff) and not Player:MotEUp()) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem, nil, not Target:IsInRange(40)) then return "liquid_magma_totem single_target 24"; end
  end
  -- flame_shock,if=dot.flame_shock.refreshable&!buff.surge_of_power.up&!buff.master_of_the_elements.up&talent.erupting_lava
  if S.FlameShock:IsViable() and (Target:DebuffRefreshable(S.FlameShockDebuff) and Player:BuffDown(S.SurgeofPowerBuff) and not Player:MotEUp() and S.EruptingLava:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 26"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(maelstrom>variable.mael_cap-15|buff.master_of_the_elements.up)
  if S.Earthquake:IsViable() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and (VarMaelstrom > VarMaelCap - 15 or Player:MotEUp())) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 28"; end
  end
  -- elemental_blast,if=maelstrom>variable.mael_cap-15|buff.master_of_the_elements.up
  if S.ElementalBlast:IsViable() and (VarMaelstrom > VarMaelCap - 15 or Player:MotEUp()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 30"; end
  end
  -- earth_shock,if=maelstrom>variable.mael_cap-15|buff.master_of_the_elements.up
  if S.EarthShock:IsViable() and (VarMaelstrom > VarMaelCap - 15 or Player:MotEUp()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 32"; end
  end
  -- icefury,if=!(buff.fusion_of_elements_nature.up|buff.fusion_of_elements_fire.up)
  if S.Icefury:IsViable() and (not (Player:BuffUp(S.FusionofElementsNature) or Player:BuffUp(S.FusionofElementsFire))) then
    if Cast(S.Icefury, nil, nil, not Target:IsSpellInRange(S.Icefury)) then return "icefury single_target 34"; end
  end
  -- lava_burst,target_if=dot.flame_shock.remains>=2,if=!buff.master_of_the_elements.up&(!talent.master_of_the_elements|buff.lava_surge.up|buff.tempest.up|buff.stormkeeper.up|cooldown.lava_burst.charges_fractional>1.8|maelstrom>82-10*talent.eye_of_the_storm|maelstrom>52-5*talent.eye_of_the_storm&(buff.echoes_of_great_sundering_eb.up|!talent.elemental_blast))
  if S.LavaBurst:IsViable() and (Target:DebuffRemains(S.FlameShockDebuff) >= 2 and not Player:MotEUp() and (not S.MasteroftheElements:IsAvailable() or Player:BuffUp(S.LavaSurgeBuff) or Player:BuffUp(S.TempestBuff) or Player:StormkeeperUp() or S.LavaBurst:ChargesFractional() > 1.8 or VarMaelstrom > 82 - 10 * num(S.EyeoftheStorm:IsAvailable()) or VarMaelstrom > 52 - 5 * num(S.EyeoftheStorm:IsAvailable()) and (Player:BuffUp(S.EchoesofGreatSunderingBuff) or not S.ElementalBlast:IsAvailable()))) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_target 36"; end
  end
  -- earthquake,if=(buff.echoes_of_great_sundering_es.up|buff.echoes_of_great_sundering_eb.up)&(buff.tempest.up|buff.stormkeeper.up)&talent.surge_of_power&!talent.master_of_the_elements
  if S.Earthquake:IsViable() and (Player:BuffUp(S.EchoesofGreatSunderingBuff) and (Player:BuffUp(S.TempestBuff) or Player:StormkeeperUp()) and S.SurgeofPower:IsAvailable() and not S.MasteroftheElements:IsAvailable()) then
    if Cast(S.Earthquake, nil, nil, not Target:IsInRange(40)) then return "earthquake single_target 38"; end
  end
  -- elemental_blast,if=(buff.tempest.up|buff.stormkeeper.up)&talent.surge_of_power&!talent.master_of_the_elements
  if S.ElementalBlast:IsViable() and ((Player:BuffUp(S.TempestBuff) or Player:StormkeeperUp()) and S.SurgeofPower:IsAvailable() and not S.MasteroftheElements:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_target 40"; end
  end
  -- earth_shock,if=(buff.tempest.up|buff.stormkeeper.up)&talent.surge_of_power&!talent.master_of_the_elements
  if S.EarthShock:IsViable() and ((Player:BuffUp(S.TempestBuff) or Player:StormkeeperUp()) and S.SurgeofPower:IsAvailable() and not S.MasteroftheElements:IsAvailable()) then
    if Cast(S.EarthShock, nil, nil, not Target:IsSpellInRange(S.EarthShock)) then return "earth_shock single_target 42"; end
  end
  -- tempest
  if S.TempestAbility:IsViable() then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single_target 44"; end
  end
  -- lightning_bolt,if=buff.storm_elemental.up&buff.wind_gust.stack<4
  if S.LightningBolt:IsViable() and ((Shaman.StormElemental.GreaterActive or Shaman.StormElemental.LesserActive) and Player:BuffStack(S.WindGustBuff) < 4) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 46"; end
  end
  -- frost_shock,if=buff.icefury_dmg.up&!buff.ascendance.up&!buff.stormkeeper.up&talent.call_of_the_ancestors
  if S.FrostShock:IsViable() and (Player:IcefuryUp() and Player:BuffDown(S.AscendanceBuff) and not Player:StormkeeperUp() and S.CalloftheAncestors:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock moving single_target 48"; end
  end
  -- lightning_bolt
  if S.LightningBolt:IsViable() then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_target 50"; end
  end
  -- flame_shock,moving=1,target_if=refreshable
  -- Note: Since SingleTarget() now doesn't cover 2 target cleave, the below line covers this one as well.
  -- flame_shock,moving=1,if=movement.distance>6
  if S.FlameShock:IsViable() and Player:IsMoving() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_target 52"; end
  end
  -- frost_shock,moving=1
  if S.FrostShock:IsViable() and Player:IsMoving() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_target 54"; end
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
    if not Settings.Commons.IgnoreEarthShield and ((S.ElementalOrbit:IsAvailable() or Settings.Commons.PreferEarthShield) and S.EarthShield:IsReady() and (Player:BuffDown(EarthShieldBuff) or (not Player:AffectingCombat() and Player:BuffStack(EarthShieldBuff) < 5))) then
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
  if S.ThunderstrikeWard:IsViable() and (not ShieldEnchantID or ShieldEnchantID ~= 7587) then
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
      -- use_item,slot=trinket1,if=trinket.1.is.spymasters_web&((fight_remains>180&buff.spymasters_report.stack>25|buff.spymasters_report.stack>35|fight_remains<80)&cooldown.ascendance.ready&(buff.fury_of_storms.up|!talent.fury_of_the_storms)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave|spell_targets.chain_lightning>=2)|fight_remains<21)
      if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1ID == I.SpymastersWeb:ID() and ((FightRemains > 180 and Player:BuffStack(S.SpymastersReportBuff) > 35 or FightRemains < 80) and S.Ascendance:CooldownUp() and (Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable()) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable() or Shaman.ClusterTargets >= 2) or BossFightRemains < 21)) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 ("..Trinket1:Name()..") main 10"; end
      end
      -- use_item,slot=trinket2,if=trinket.2.is.spymasters_web&((fight_remains>180&buff.spymasters_report.stack>25|buff.spymasters_report.stack>35|fight_remains<80)&cooldown.ascendance.ready&(buff.fury_of_storms.up|!talent.fury_of_the_storms)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave|spell_targets.chain_lightning>=2)|fight_remains<21)
      if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2ID == I.SpymastersWeb:ID() and ((FightRemains > 180 and Player:BuffStack(S.SpymastersReportBuff) > 35 or FightRemains < 80) and S.Ascendance:CooldownUp() and (Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable()) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable() or Shaman.ClusterTargets >= 2) or BossFightRemains < 21)) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 ("..Trinket2:Name()..") main 12"; end
      end
    end
    -- use_item,name=neural_synapse_enhancer,use_off_gcd=1,if=buff.ascendance.remains>12|cooldown.ascendance.remains>10
    if Settings.Commons.Enabled.Items and I.NeuralSynapseEnhancer:IsEquippedAndReady() and (Player:BuffRemains(S.AscendanceBuff) > 12 or S.Ascendance:CooldownRemains() > 10) then
      if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Items) then return "use_item neural_synapse_enhancer main 14"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=house_of_cards,use_off_gcd=1,if=variable.special_items&(buff.ascendance.remains>12|cooldown.ascendance.remains>90)|fight_remains<21
      if I.HouseofCards:IsEquippedAndReady() and (VarSpecialItems and (Player:BuffRemains(S.AscendanceBuff) > 12 or S.Ascendance:CooldownRemains() > 90) or BossFightRemains < 21) then
        if Cast(I.HouseofCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "use_item house_of_cards main 16"; end
      end
      -- use_item,slot=trinket1,use_off_gcd=1,if=!trinket.1.has_use_buff|!variable.special_items&((buff.fury_of_storms.up|!talent.fury_of_the_storms|cooldown.stormkeeper.remains>10)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave|spell_targets.chain_lightning>=2)&cooldown.ascendance.remains>15|fight_remains<21|buff.ascendance.remains>12)
      if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not Trinket1:HasUseBuff() or not VarSpecialItems and ((Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable() or S.Stormkeeper:CooldownRemains() > 10) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable() or Shaman.ClusterTargets >= 2) and S.Ascendance:CooldownRemains() > 15 or BossFightRemains < 21 or Player:BuffRemains(S.AscendanceBuff) > 12)) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item trinket1 ("..Trinket1:Name()..") main 18"; end
      end
      -- use_item,slot=trinket2,use_off_gcd=1,if=!trinket.2.has_use_buff|!variable.special_items&((buff.fury_of_storms.up|!talent.fury_of_the_storms|cooldown.stormkeeper.remains>10)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave|spell_targets.chain_lightning>=2)&cooldown.ascendance.remains>15|fight_remains<21|buff.ascendance.remains>12)
      if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not Trinket2:HasUseBuff() or not VarSpecialItems and ((Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable() or S.Stormkeeper:CooldownRemains() > 10) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable() or Shaman.ClusterTargets >= 2) and S.Ascendance:CooldownRemains() > 15 or BossFightRemains < 21 or Player:BuffRemains(S.AscendanceBuff) > 12)) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item trinket2 ("..Trinket2:Name()..") main 20"; end
      end
    end
    if Settings.Commons.Enabled.Items then
      -- use_item,slot=main_hand,use_off_gcd=1,if=(buff.fury_of_storms.up|!talent.fury_of_the_storms|cooldown.stormkeeper.remains>10)&(cooldown.primordial_wave.remains>25|!talent.primordial_wave)&cooldown.ascendance.remains>15|buff.ascendance.remains>12
      -- Note: Expanding to all non-trinket items
      local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
      if ItemToUse and ((Player:BuffUp(S.FuryofStormsBuff) or not S.FuryoftheStorms:IsAvailable() or S.Stormkeeper:CooldownRemains() > 10) and (S.PrimordialWave:CooldownRemains() > 25 or not S.PrimordialWave:IsAvailable()) and S.Ascendance:CooldownRemains() > 15 or Player:BuffRemains(S.AscendanceBuff) > 12) then
        if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "use_item non-trinket ("..ItemToUse:Name()..") main 22"; end
      end
    end
    -- lightning_shield,if=buff.lightning_shield.down
    -- Note: Handled above.
    -- natures_swiftness
    if CDsON() and S.NaturesSwiftness:IsCastable() and Player:BuffDown(S.NaturesSwiftness) then
      if Cast(S.NaturesSwiftness, Settings.CommonsOGCD.GCDasOffGCD.NaturesSwiftness) then return "natures_swiftness main 24"; end
    end
    -- invoke_external_buff,name=power_infusion,if=buff.ascendance.up|cooldown.ascendance.remains>30
    -- Note: Not handling external buffs.
    -- potion,if=buff.bloodlust.up|buff.spymasters_web.up|buff.ascendance.remains>12|fight_remains<31
    if Settings.Commons.Enabled.Potions and (Player:BloodlustUp() or Player:BuffUp(S.SpymastersWebBuff) or Player:BuffRemains(S.AscendanceBuff) > 12 or BossFightRemains < 31) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 26"; end
      end
    end
    -- run_action_list,name=aoe,if=spell_targets.chain_lightning>=2
    if AoEON() and (Shaman.ClusterTargets >= 2) then
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

  HR.Print("Elemental Shaman rotation has been updated for patch 11.1.0.")
end

HR.SetAPL(262, APL, Init)
