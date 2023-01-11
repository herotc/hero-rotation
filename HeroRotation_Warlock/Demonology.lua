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

-- Rotation Var
local BossFightRemains = 11111
local FightRemains = 11111
local VarTyrantPrepStart = 0
local VarNextTyrant = 0

-- Enemy Variables
local Enemies40y
local Enemies8ySplash, EnemiesCount8ySplash

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
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.HandofGuldan:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.HandofGuldan:RegisterInFlight()

-- Function to check for imp count
local function WildImpsCount()
  return HL.GuardiansTable.ImpCount or 0
end

-- Function to check for remaining Grimoire Felguard duration
local function GrimoireFelguardTime()
  return HL.GuardiansTable.FelGuardDuration or 0
end

-- Function to check for Demonic Tyrant duration
local function DemonicTyrantTime()
  return HL.GuardiansTable.DemonicTyrantDuration or 0
end

local function EvaluateDoom(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.Doom))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  -- Moved to APL()
  -- snapshot_stats
  -- inquisitors_gaze
  -- Moved to APL()
  -- variable,name=tyrant_prep_start,op=set,value=12
  VarTyrantPrepStart = 12
  -- variable,name=next_tyrant,op=set,value=14+talent.grimoire_felguard+talent.summon_vilefiend
  VarNextTyrant = 14 + num(S.GrimoireFelguard:IsAvailable()) + num(S.SummonVilefiend:IsAvailable())
  -- power_siphon
  if CDsON() and S.PowerSiphon:IsCastable() then
    if Cast(S.PowerSiphon) then return "power_siphon precombat 32"; end
  end
  -- demonbolt,if=!buff.power_siphon.up
  if S.Demonbolt:IsCastable() and Player:BuffDown(S.DemonicCoreBuff) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 33"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 34"; end
  end
end

local function Tyrant()
  -- variable,name=next_tyrant,op=set,value=time+14+cooldown.grimoire_felguard.ready+cooldown.summon_vilefiend.ready,if=variable.next_tyrant<=time
  if (VarNextTyrant <= HL.CombatTime()) then
    VarNextTyrant = HL.CombatTime() + 14 + num(S.GrimoireFelguard:CooldownUp()) + num(S.SummonVilefiend:CooldownUp())
  end
  -- shadow_bolt,if=time<2&soul_shard<5
  if S.ShadowBolt:IsCastable() and HL.CombatTime() < 2 and Player:SoulShardsP() < 5 then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 71"; end
  end
  -- nether_portal
  if CDsON() and S.NetherPortal:IsReady() then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal tyrant 72"; end
  end
  -- grimoire_felguard
  if CDsON() and S.GrimoireFelguard:IsReady() then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant 73"; end
  end
  -- summon_vilefiend
  if CDsON() and S.SummonVilefiend:IsReady() then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend tyrant 74"; end
  end
  -- call_dreadstalkers
  if S.CallDreadstalkers:IsReady() then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant 75"; end
  end
  -- soulburn,if=buff.nether_portal.up&soul_shard>=2,line_cd=40
  --Not a dps spell
  --if S.Soulburn:IsReady() and Player:BuffUp(S.NetherPortalBuff) and Player:SoulShardsP() > 2 then
  --  if Cast(S.Soulburn) then return "soulburn tyrant 75"; end
  --end
  -- hand_of_guldan,if=variable.next_tyrant-time>2&(buff.nether_portal.up|soul_shard>2&variable.next_tyrant-time<12|soul_shard=5)
  if S.HandofGuldan:IsReady() and VarNextTyrant > 2 and (Player:BuffUp(S.NetherPortalBuff) or Player:SoulShardsP() > 2 and VarNextTyrant - HL.CombatTime() < 12 or Player:SoulShardsP() == 5) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 77"; end
  end
  --hand_of_guldan,if=talent.soulbound_tyrant&variable.next_tyrant-time<4&variable.next_tyrant-time>action.summon_demonic_tyrant.cast_time
  if S.HandofGuldan:IsReady() and S.SoulboundTyrant:IsAvailable() and VarNextTyrant - HL.CombatTime() < 4 and VarNextTyrant - HL.CombatTime() > S.SummonDemonicTyrant:CastTime() then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 78"; end
  end
  -- summon_demonic_tyrant,if=variable.next_tyrant-time<cast_time*2
  if CDsON() and S.SummonDemonicTyrant:IsCastable() and VarNextTyrant - HL.CombatTime() < S.SummonDemonicTyrant:CastTime() * 2 then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant 79"; end
  end
  -- demonbolt,if=buff.demonic_core.up
  if S.Demonbolt:IsCastable() and (Player:BuffUp(S.DemonicCoreBuff)) then 
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt tyrant 80"; end
  end
  -- power_siphon,if=buff.wild_imps.stack>1&!buff.nether_portal.up
  if CDsON() and S.PowerSiphon:IsCastable() and WildImpsCount() > 1 and not Player:BuffUp(S.NetherPortalBuff) then
    if Cast(S.PowerSiphon) then return "power_siphon tyrant 81"; end
  end
  -- soul_strike
  if S.SoulStrike:IsReady() then
    if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike tyrant 82"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 83"; end
  end
end

local function Items()
  --use_item,name=timebreaching_talon,if=buff.demonic_power.up|!talent.summon_demonic_tyrant&(buff.nether_portal.up|!talent.nether_portal)
  if I.TimebreachingTalon:IsEquippedAndReady() and (Player:BuffUp(S.DemonicPowerBuff) or not S.SummonDemonicTyrant:IsAvailable() and (Player:BuffUp(S.NetherPortalBuff) or not S.NetherPortal:IsAvailable())) then
    if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon items 62"; end
  end
  -- use_items,if=!talent.summon_demonic_tyrant|buff.demonic_power.up
  if not S.SummonDemonicTyrant:IsAvailable() or Player:BuffUp(S.DemonicPowerBuff) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Ogcd()
  --potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion ogcd 65"; end
    end
  end
  --berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.GCDasOffGCD.Racials) then return "berserking ogcd 66"; end
  end
  --blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.GCDasOffGCD.Racials) then return "blood_fury ogcd 67"; end
  end
  --fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.GCDasOffGCD.Racials) then return "fireblood ogcd 68"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Update Enemy Counts
  if AoEON() then
    Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    Enemies40y = Player:GetEnemiesInRange(40)
  else
    Enemies8ySplash = {}
    EnemiesCount8ySplash = 1
    Enemies40y = {}
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
  -- inquisitors_gaze
  if S.InquisitorsGaze:IsCastable() and Player:BuffDown(S.InquisitorsGazeBuff) then
    if Cast(S.InquisitorsGaze, Settings.Demonology.GCDasOffGCD.InquisitorsGaze) then return "inquisitors_gaze ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() and not Player:IsCasting(S.Demonbolt) then
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
    -- call_action_list,name=tyrant,if=talent.summon_demonic_tyrant&(time-variable.next_tyrant)<=(variable.tyrant_prep_start+2)&cooldown.summon_demonic_tyrant.up
    if S.SummonDemonicTyrant:IsAvailable() and (HL.CombatTime() - VarNextTyrant) <= (VarTyrantPrepStart + 2) and S.SummonDemonicTyrant:CooldownUp() then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=tyrant,if=talent.summon_demonic_tyrant&cooldown.summon_demonic_tyrant.remains_expected<variable.tyrant_prep_start
    if S.SummonDemonicTyrant:IsAvailable() and S.SummonDemonicTyrant:CooldownRemains() < VarTyrantPrepStart then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- implosion,if=time_to_die<2*gcd
    if S.Implosion:IsAvailable() and S.Implosion:IsCastable() and HL.FightRemains() < 2 * Player:GCD() then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsSpellInRange(S.Implosion)) then return "implosion main 39"; end
    end
    -- nether_portal,if=!talent.summon_demonic_tyrant&soul_shard>2|time_to_die<30
    if CDsON() and S.NetherPortal:IsReady() and ((not S.SummonDemonicTyrant:IsAvailable()) and (Player:SoulShardsP() > 2) or HL.FightRemains() < 30) then
      if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal main 40"; end
    end
    -- hand_of_guldan,if=buff.nether_portal.up
    if S.HandofGuldan:IsReady() and Player:BuffUp(S.NetherPortalBuff) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 41"; end
    end
    -- call_action_list,name=items
    if CDsON() and Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd,if=buff.demonic_power.up|!talent.summon_demonic_tyrant&(buff.nether_portal.up|!talent.nether_portal)
    if CDsON() and (Player:BuffUp(S.DemonicPowerBuff) or not S.SummonDemonicTyrant:IsAvailable() and (Player:BuffUp(S.NetherPortalBuff) or not S.NetherPortal:IsAvailable())) then
      local ShouldReturn = Ogcd(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains_expected>cooldown
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 20) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 44"; end
    end
    -- call_dreadstalkers,if=!talent.summon_demonic_tyrant|time_to_die<14
    if S.CallDreadstalkers:IsReady() and (not S.SummonDemonicTyrant:IsAvailable() or HL.FightRemains() < 14) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 45"; end
    end
    -- grimoire_felguard,if=!talent.summon_demonic_tyrant|time_to_die<cooldown.summon_demonic_tyrant.remains_expected
    if CDsON() and S.GrimoireFelguard:IsReady() and (not S.SummonDemonicTyrant:IsAvailable() or HL.FightRemains() < S.SummonDemonicTyrant:CooldownRemains()) then
      if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard main 46"; end
    end
    -- summon_vilefiend,if=!talent.summon_demonic_tyrant|cooldown.summon_demonic_tyrant.remains_expected>cooldown+variable.tyrant_prep_start|time_to_die<cooldown.summon_demonic_tyrant.remains_expected
    if CDsON() and S.SummonVilefiend:IsReady() and ((not S.SummonDemonicTyrant:IsAvailable()) or S.SummonDemonicTyrant:CooldownRemains() > 45 + VarTyrantPrepStart or HL.FightRemains() < S.SummonDemonicTyrant:CooldownRemains()) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 47"; end
    end
    -- guillotine,if=cooldown.demonic_strength.remains
    -- Added check to make sure that we're not suggesting this during pet's Felstorm or demonic strength
    if CDsON() and S.Guillotine:IsReady() and S.DemonicStrength:CooldownDown() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100)))) and S.DemonicStrength:TimeSinceLastCast() >= 4 then
      if Cast(S.Guillotine, nil, nil, not Target:IsInRange(40)) then return "guillotine main 48"; end
    end
    -- demonic_strength
    -- Added check to make sure that we're not suggesting this during pet's Felstorm or Guillotine
    if CDsON() and S.DemonicStrength:IsReady() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100)))) and S.Guillotine:TimeSinceLastCast() >= 8 then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 49"; end
    end
    -- bilescourge_bombers,if=!pet.demonic_tyrant.active
    if CDsON() and S.BilescourgeBombers:IsReady() and DemonicTyrantTime() == 0 then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 50"; end
    end
    -- shadow_bolt,if=soul_shard<5&talent.fel_covenant&buff.fel_covenant.remains<5
    if S.ShadowBolt:IsReady() and Player:SoulShardsP() < 5 and S.FelCovenant:IsAvailable() and Player:BuffRemains(S.FelCovenantBuff) < 5 then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 51"; end
    end
    -- implosion,if=active_enemies>2&buff.wild_imps.stack>=6
    if S.Implosion:IsReady() and EnemiesCount8ySplash > 2 and WildImpsCount() >= 6 then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsSpellInRange(S.Implosion)) then return "implosion main 52"; end
    end
    -- soul_strike,if=soul_shard<5&active_enemies>1
    if S.SoulStrike:IsReady() and Player:SoulShardsP() < 5 and EnemiesCount8ySplash > 1 then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 53"; end
    end
    -- summon_soulkeeper,if=active_enemies>1&buff.tormented_soul.stack=10
    if S.SummonSoulkeeper:IsReady() and EnemiesCount8ySplash > 1 and S.SummonSoulkeeper:Count() == 10 then
      if Cast(S.SummonSoulkeeper) then return "soul_strike main 54"; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4
    if S.Demonbolt:IsReady() and Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 55"; end
    end
    -- power_siphon,if=buff.demonic_core.stack<1&(buff.dreadstalkers.remains>3|buff.dreadstalkers.down)
    if CDsON() and S.PowerSiphon:IsReady() and Player:BuffDown(S.DemonicCoreBuff) and (GrimoireFelguardTime() > 3 or GrimoireFelguardTime() == 0) then
      if Cast(S.PowerSiphon) then return "power_siphon main 56"; end
    end
    -- hand_of_guldan,if=soul_shard>2&(!talent.summon_demonic_tyrant|cooldown.summon_demonic_tyrant.remains_expected>variable.tyrant_prep_start+2)
    if S.HandofGuldan:IsReady() and Player:SoulShardsP() > 2 and (not S.SummonDemonicTyrant:IsAvailable() or S.SummonDemonicTyrant:CooldownRemains() > VarTyrantPrepStart + 2) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 57"; end
    end
    -- doom,target_if=refreshable
    if S.Doom:IsReady() then
      if Everyone.CastCycle(S.Doom, Enemies40y, EvaluateDoom, not Target:IsSpellInRange(S.Doom)) then return "doom main 58"; end
    end
    -- soul_strike,if=soul_shard<5
    if S.SoulStrike:IsReady() and Player:SoulShardsP() < 5 then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 59"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 60"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(266, APL, Init)
