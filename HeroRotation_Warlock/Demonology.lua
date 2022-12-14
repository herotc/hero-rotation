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
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Warlock    = HR.Commons.Warlock
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local GetTime    = GetTime


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Demonology
local I = Item.Warlock.Demonology

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Var
local BossFightRemains = 11111
local FightRemains = 11111
local EnemiesCount8ySplash
local VarTyrantPrepStart = 0

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Demonology = HR.GUISettings.APL.Warlock.Demonology
}

-- Stuns
local StunInterrupts = {
  {S.AxeToss, "Cast Axe Toss (Interrupt)", function () return true; end},
}

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.HandofGuldan:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.HandofGuldan:RegisterInFlight()

-- Function to check for imp count
local function WildImpsCount()
  return HL.GuardiansTable.ImpCount or 0
end

-- Function to check for remaining Dreadstalker duration
local function DreadStalkersTime()
  return HL.GuardiansTable.DreadstalkerDuration or 0
end

-- Function to check for remaining Grimoire Felguard duration
local function GrimoireFelguardTime()
  return HL.GuardiansTable.FelGuardDuration or 0
end

-- Function to check for remaining Vilefiend duration
local function VilefiendTime()
  return HL.GuardiansTable.VilefiendDuration or 0
end

-- Function to check for Demonic Tyrant duration
local function DemonicTyrantTime()
  return HL.GuardiansTable.DemonicTyrantDuration or 0
end

local function ImpsSpawnedDuring(SpellCastTime)
  if SpellCastTime == 0 then return 0; end
  local ImpSpawned = 0
  --local SpellCastTime = ( milliseconds / 1000 ) * Player:SpellHaste()

  if GetTime() <= HL.GuardiansTable.InnerDemonsNextCast and (GetTime() + SpellCastTime) >= HL.GuardiansTable.InnerDemonsNextCast then
    ImpSpawned = ImpSpawned + 1
  end

  if Player:IsCasting(S.HandofGuldan) then
    ImpSpawned = ImpSpawned + (Player:SoulShards() >= 3 and 3 or Player:SoulShards())
  end

  ImpSpawned = ImpSpawned +  HL.GuardiansTable.ImpsSpawnedFromHoG

  return ImpSpawned
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  -- Moved to APL()
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  -- Note: grimoire_of_sacrifice is not available to Demonology?
  -- snapshot_stats
  -- variable,name=tyrant_prep_start,op=set,value=12
  VarTyrantPrepStart = 12
  -- demonbolt
  if S.Demonbolt:IsCastable() then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 12"; end
  end
end

local function Tyrant()
  -- nether_portal
  if S.NetherPortal:IsReady() then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal tyrant 2"; end
  end
  -- grimoire_felguard
  if S.GrimoireFelguard:IsReady() then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant 4"; end
  end
  -- summon_vilefiend
  if S.SummonVilefiend:IsReady() then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend tyrant 6"; end
  end
  -- call_dreadstalkers
  if S.CallDreadstalkers:IsReady() then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant 8"; end
  end
  -- hand_of_guldan,if=buff.nether_portal.up|soul_shard>2
  if S.HandofGuldan:IsReady() and (Player:BuffUp(S.NetherPortalBuff) or Player:SoulShardsP() > 2) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 10"; end
  end
  -- summon_demonic_tyrant,if=buff.dreadstalkers.remains<3
  if S.SummonDemonicTyrant:IsCastable() and (DreadStalkersTime() < 3) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant 12"; end
  end
  -- demonbolt,if=buff.demonic_core.up
  if S.Demonbolt:IsCastable() and (Player:BuffUp(S.DemonicCoreBuff)) then 
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt tyrant 14"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 16"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Update Enemy Counts
  if AoEON() then
    Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    Enemies8ySplash = {}
    EnemiesCount8ySplash = 1
  end

  -- Update Demonology-specific Tables
  Warlock.UpdatePetTable()
  Warlock.UpdateSoulShards()

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  -- summon_pet
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Demonology.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Interrupts
    if S.SpellLock:IsAvailable() then
      local ShouldReturn = Everyone.Interrupt(40, S.SpellLock, Settings.Commons.OffGCDasOffGCD.SpellLock, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: unending_resolve
    if S.UnendingResolve:IsCastable() and (Player:HealthPercentage() < Settings.Demonology.UnendingResolveHP) then
      if Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return "unending_resolve defensive"; end
    end
    -- call_action_list,name=tyrant,if=time<15&talent.summon_demonic_tyrant&cooldown.summon_demonic_tyrant.up
    if (HL.CombatTime() < 15 and S.SummonDemonicTyrant:IsAvailable() and S.SummonDemonicTyrant:IsCastable()) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=tyrant,if=talent.summon_demonic_tyrant&cooldown.summon_demonic_tyrant.remains_expected<variable.tyrant_prep_start
    if (S.SummonDemonicTyrant:IsAvailable() and S.SummonDemonicTyrant:CooldownRemains() < VarTyrantPrepStart) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- nether_portal,if=!talent.summon_demonic_tyrant&soul_shard>2
    if S.NetherPortal:IsReady() and ((not S.SummonDemonicTyrant:IsAvailable()) and Player:SoulShardsP() > 2) then
      if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal main 2"; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains_expected>cooldown+variable.tyrant_prep_start
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 20 + VarTyrantPrepStart) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 4"; end
    end
    -- grimoire_felguard,if=!talent.summon_demonic_tyrant
    if S.GrimoireFelguard:IsReady() and (not S.SummonDemonicTyrant:IsAvailable()) then
      if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard main 6"; end
    end
    -- summon_vilefiend,if=!talent.summon_demonic_tyrant|cooldown.summon_demonic_tyrant.remains_expected>cooldown+variable.tyrant_prep_start
    if S.SummonVilefiend:IsReady() and ((not S.SummonDemonicTyrant:IsAvailable()) or S.SummonDemonicTyrant:CooldownRemains() > 45 + VarTyrantPrepStart) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 8"; end
    end
    -- use_items,if=!talent.summon_demonic_tyrant|buff.demonic_power.up
    if Settings.Commons.Enabled.Trinkets then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- guillotine
    if S.Guillotine:IsCastable() then
      if Cast(S.Guillotine, nil, nil, not Target:IsInRange(40)) then return "guillotine main 10"; end
    end
    -- demonic_strength
    -- Added check to make sure that we're not suggesting this during pet's Felstorm
    if S.DemonicStrength:IsCastable() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100)))) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 12"; end
    end
    -- power_siphon
    if S.PowerSiphon:IsReady() then
      if Cast(S.PowerSiphon) then return "power_siphon main 14"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 16"; end
    end
    -- hand_of_guldan,if=soul_shard>2
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >2) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 18"; end
    end
    -- doom,if=refreshable
    if S.Doom:IsCastable() and (Target:DebuffRefreshable(S.DoomDebuff)) then
      if Cast(S.Doom, nil, nil, not Target:IsSpellInRange(S.Doom)) then return "doom main 20"; end
    end
    -- soul_strike
    if S.SoulStrike:IsCastable() then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 22"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 24"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(266, APL, Init)
