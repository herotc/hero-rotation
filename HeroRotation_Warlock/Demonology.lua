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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Warlock    = HR.Commons.Warlock
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

-- Rotation Var
local ShouldReturn -- Used to get the return string
local GCDRemain
local EnemiesCount8ySplash
local VarTyrantReady = false
local BalespidersEquipped = Player:HasLegendaryEquipped(173)

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
  BalespidersEquipped = Player:HasLegendaryEquipped(173)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarTyrantReady = false
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.HandofGuldan:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.HandofGuldan:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

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

-- Function to check for Demonic Tyrant duration
local function DemonicTyrantTime()
  return HL.GuardiansTable.DemonicTyrantDuration or 0
end

local function EvaluateCycleDoom198(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.DoomDebuff)
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
  if S.SummonPet:IsCastable() then
    if HR.Cast(S.SummonPet, Settings.Demonology.GCDasOffGCD.SummonPet) then return "summon_pet 2"; end
  end
  -- inner_demons,if=talent.inner_demons.enabled
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- potion
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.Enabled.Potions then
      if HR.Cast(I.PotionofUnbridledFury, nil, Settings.Commons.DisplayStyle.Potions) then return "battle_potion_of_intellect 4"; end
    end
    -- demonbolt
    if S.Demonbolt:IsCastable() then
      if HR.Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt 6"; end
    end
    -- variable,name=tyrant_ready,value=0
    VarTyrantReady = false
  end
end

local function TyrantPrep()
  -- doom,line_cd=30
  if S.Doom:IsCastable() and (S.Doom:TimeSinceLastCast() > 30) then
    if HR.Cast(S.Doom, nil, nil, not Target:IsSpellInRange(S.Doom)) then return "doom 62"; end
  end
  -- demonic_strength,if=!talent.demonic_consumption.enabled
  -- Added check to make sure that we're not suggesting this during pet's Felstorm
  if S.DemonicStrength:IsCastable() and (not S.DemonicConsumption:IsAvailable() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100))))) then
    if HR.Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength 64"; end
  end
  -- nether_portal
  if S.NetherPortal:IsReady() then
    if HR.Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal, nil, not Target:IsSpellInRange(S.NetherPortal)) then return "nether_portal 66"; end
  end
  -- grimoire_felguard
  if S.GrimoireFelguard:IsReady() then
    if HR.Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard 68"; end
  end
  -- summon_vilefiend
  if S.SummonVilefiend:IsReady() then
    if HR.Cast(S.SummonVilefiend) then return "summon_vilefiend 70"; end
  end
  -- call_dreadstalkers
  if S.CallDreadstalkers:IsReady() then
    if HR.Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers 72"; end
  end
  -- demonbolt,if=buff.demonic_core.up&soul_shard<4&(talent.demonic_consumption.enabled|buff.nether_portal.down)
  if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4 and (S.DemonicConsumption:IsAvailable() or Player:BuffDown(S.NetherPortalBuff))) then
    if HR.Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt 74"; end
  end
  -- shadow_bolt,if=soul_shard<5-4*buff.nether_portal.up
  if S.ShadowBolt:IsCastable() and (Player:SoulShardsP() < (5 - 4 * num(Player:BuffUp(S.NetherPortalBuff)))) then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt 76"; end
  end
  -- variable,name=tyrant_ready,value=1
  if (true) then
    VarTyrantReady = true
  end
  -- hand_of_guldan
  if S.HandofGuldan:IsReady() then
    if HR.Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan 78"; end
  end
end

local function SummonTyrant()
  -- Moved from lower in the function so we abort this function right after using Demonic Tyrant
  if (not S.SummonDemonicTyrant:CooldownUp()) then
    VarTyrantReady = false
  end
  -- hand_of_guldan,if=soul_shard=5,line_cd=20
  if S.HandofGuldan:IsReady() and (S.HandofGuldan:TimeSinceLastCast() > 20 and Player:SoulShardsP() == 5) then
    if HR.Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan 92"; end
  end
  -- demonbolt,if=buff.demonic_core.up&(talent.demonic_consumption.enabled|buff.nether_portal.down),line_cd=20
  if S.Demonbolt:IsCastable() and (S.Demonbolt:TimeSinceLastCast() > 20 and Player:BuffUp(S.DemonicCoreBuff) and (S.DemonicConsumption:IsAvailable() or Player:BuffDown(S.NetherPortalBuff))) then
    if HR.Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt 94"; end
  end
  -- shadow_bolt,if=buff.wild_imps.stack+incoming_imps<4&(talent.demonic_consumption.enabled|buff.nether_portal.down),line_cd=20
  if S.ShadowBolt:IsCastable() and (S.ShadowBolt:TimeSinceLastCast() > 20 and WildImpsCount() + ImpsSpawnedDuring(Spell(Player:PrevGCD(1)):CastTime()) < 4 and (S.DemonicConsumption:IsAvailable() or Player:BuffDown(S.NetherPortalBuff))) then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt 96"; end
  end
  -- call_dreadstalkers
  if S.CallDreadstalkers:IsReady() then
    if HR.Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers 98"; end
  end
  -- hand_of_guldan
  if S.HandofGuldan:IsReady() then
    if HR.Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan 100"; end
  end
  -- demonbolt,if=buff.demonic_core.up&buff.nether_portal.up&((buff.vilefiend.remains>5|!talent.summon_vilefiend.enabled)&(buff.grimoire_felguard.remains>5|buff.grimoire_felguard.down))
  if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:BuffUp(S.NetherPortalBuff) and ((S.SummonVilefiend:CooldownRemains() > 35 or not S.SummonVilefiend:IsAvailable()) and (S.GrimoireFelguard:CooldownRemains() > 108 or S.GrimoireFelguard:CooldownRemains() < 103))) then
    if HR.Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt 102"; end
  end
  -- shadow_bolt,if=buff.nether_portal.up&((buff.vilefiend.remains>5|!talent.summon_vilefiend.enabled)&(buff.grimoire_felguard.remains>5|buff.grimoire_felguard.down))
  if S.ShadowBolt:IsCastable() and (Player:BuffUp(S.NetherPortalBuff) and ((S.SummonVilefiend:CooldownRemains() > 35 or not S.SummonVilefiend:IsAvailable()) and (S.GrimoireFelguard:CooldownRemains() > 108 or S.GrimoireFelguard:CooldownRemains() < 103))) then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt 104"; end
  end
  -- summon_demonic_tyrant
  if S.SummonDemonicTyrant:IsCastable() and not Player:IsCasting(S.SummonDemonicTyrant) then
    if HR.Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant, nil, not Target:IsInRange(40)) then return "summon_demonic_tyrant 106"; end
  end
  -- variable,name=tyrant_ready,value=!cooldown.summon_demonic_tyrant.ready
  -- Moved to top of function for better flow
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt 108"; end
  end
end

local function OffGCD()
  -- berserking,if=pet.demonic_tyrant.active
  if S.Berserking:IsCastable() and (DemonicTyrantTime() > 0) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 122"; end
  end
  -- potion,if=buff.berserking.up|pet.demonic_tyrant.active&!race.troll
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.Berserking) or DemonicTyrantTime() > 0 and Player:Race() ~= "Troll") then
    if HR.Cast(I.PotionofUnbridledFury, nil, Settings.Commons.DisplayStyle.Potions) then return "potion 124"; end
  end
  -- blood_fury,if=pet.demonic_tyrant.active
  if S.BloodFury:IsCastable() and (DemonicTyrantTime() > 0) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 126"; end
  end
  -- fireblood,if=pet.demonic_tyrant.active
  if S.Fireblood:IsCastable() and (DemonicTyrantTime() > 0) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 128"; end
  end
end

local function Covenant()
  -- impending_catastrophe,if=!talent.sacrificed_souls.enabled|active_enemies>1
  if S.ImpendingCatastrophe:IsReady() and (not S.SacrificedSouls:IsAvailable() or EnemiesCount8ySplash > 1) then
    if HR.Cast(S.ImpendingCatastrophe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ImpendingCatastrophe)) then return "impending_catastrophe 142"; end
  end
  -- scouring_tithe,if=talent.sacrificed_souls.enabled&active_enemies=1
  -- scouring_tithe,if=!talent.sacrificed_souls.enabled&active_enemies<4
  -- Note: Combined the lines
  if S.ScouringTithe:IsReady() and not Player:IsCasting(S.ScouringTithe) and ((S.SacrificedSouls:IsAvailable() and EnemiesCount8ySplash == 1) or (not S.SacrificedSouls:IsAvailable() and EnemiesCount8ySplash < 4)) then
    if HR.Cast(S.ScouringTithe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ScouringTithe)) then return "scouring_tithe 144"; end
  end
  -- soul_rot
  if S.SoulRot:IsReady() then
    if HR.Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot 146"; end
  end
  -- decimating_bolt
  if S.DecimatingBolt:IsReady() then
    if HR.Cast(S.DecimatingBolt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DecimatingBolt)) then return "decimating_bolt 148"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Update Enemy Counts
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)

  -- Update Demonology-specific Tables
  Warlock.UpdatePetTable()
  Warlock.UpdateSoulShards()

  GCDRemain = Player:GCDRemains()

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(40, S.SpellLock, Settings.Commons.OffGCDasOffGCD.SpellLock, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: unending_resolve
    if S.UnendingResolve:IsCastable() and (Player:HealthPercentage() < Settings.Demonology.UnendingResolveHP) then
      if HR.Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return "unending_resolve defensive"; end
    end
    -- Manually added: ShadowBolt to keep Balespider's buff up
    -- shadow_bolt,if=buff.balespiders_burning_core.up&buff.balespiders_burning_core.remains<(execute_time+gcd.remains+1)&(buff.decimating_bolt.down|buff.decimating_bolt.remains>(execute_time+gcd.remains+1+(demonbolt.execute_time*buff.decimating_bolt.stack)))
    if S.ShadowBolt:IsReady() and (Player:BuffUp(S.BalespidersBuff) and Player:BuffRemains(S.BalespidersBuff) < (S.ShadowBolt:ExecuteTime() + GCDRemain + 1) and (Player:BuffDown(S.DecimatingBoltBuff) or Player:BuffRemains(S.DecimatingBoltBuff) > (S.ShadowBolt:ExecuteTime() + GCDRemain + 1 + (S.Demonbolt:ExecuteTime() * Player:BuffStack(S.DecimatingBoltBuff))))) then
      if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt balespiders"; end
    end
    -- call_action_list,name=off_gcd
    if CDsON() then
      local ShouldReturn = OffGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=tyrant_prep,if=cooldown.summon_demonic_tyrant.remains<4&!variable.tyrant_ready
    if CDsON() and S.SummonDemonicTyrant:CooldownRemains() < 4 and not VarTyrantReady then
      local ShouldReturn = TyrantPrep(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=summon_tyrant,if=variable.tyrant_ready
    if CDsON() and VarTyrantReady then
      local ShouldReturn = SummonTyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- summon_vilefiend,if=cooldown.summon_demonic_tyrant.remains>40|time_to_die<cooldown.summon_demonic_tyrant.remains+25
    if S.SummonVilefiend:IsReady() and ((S.SummonDemonicTyrant:CooldownRemains() > 40 or Target:TimeToDie() < S.SummonDemonicTyrant:CooldownRemains() + 25) or not CDsON()) then
      if HR.Cast(S.SummonVilefiend) then return "summon_vilefiend 22"; end
    end
    -- call_dreadstalkers
    if S.CallDreadstalkers:IsReady() then
      if HR.Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers 24"; end
    end
    -- doom,if=refreshable
    if S.Doom:IsCastable() and (Target:DebuffRefreshable(S.DoomDebuff)) then
      if HR.Cast(S.Doom, nil, nil, not Target:IsSpellInRange(S.Doom)) then return "doom 26"; end
    end
    -- demonic_strength
    -- Added check to make sure that we're not suggesting this during pet's Felstorm
    if S.DemonicStrength:IsCastable() and (S.Felstorm:CooldownRemains() < 30 - (5 * (1 - (Player:HastePct() / 100)))) then
      if HR.Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength 28"; end
    end
    -- bilescourge_bombers
    if S.BilescourgeBombers:IsReady() then
      if HR.Cast(S.BilescourgeBombers, nil, nil, not Target:IsSpellInRange(S.BilescourgeBombers)) then return "bilescourge_bombers 30"; end
    end
    -- implosion,if=active_enemies>1&!talent.sacrificed_souls.enabled&buff.wild_imps.stack>=8&buff.tyrant.down&cooldown.summon_demonic_tyrant.remains>5
    if S.Implosion:IsReady() and (EnemiesCount8ySplash > 1 and not S.SacrificedSouls:IsAvailable() and WildImpsCount() >= Settings.Demonology.ImpsRequiredForImplosion and DemonicTyrantTime() == 0 and S.SummonDemonicTyrant:CooldownRemains() > 5) then
      if HR.Cast(S.Implosion, nil, nil, not Target:IsInRange(40)) then return "implosion 31"; end
    end
    -- implosion,if=active_enemies>2&buff.wild_imps.stack>=8&buff.tyrant.down
    if S.Implosion:IsReady() and (EnemiesCount8ySplash > 2 and WildImpsCount() >= Settings.Demonology.ImpsRequiredForImplosion and DemonicTyrantTime() == 0) then
      if HR.Cast(S.Implosion, nil, nil, not Target:IsInRange(40)) then return "implosion 32"; end
    end
    -- hand_of_guldan,if=soul_shard=5|buff.nether_portal.up
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() == 5 or Player:BuffUp(S.NetherPortalBuff)) then
      if HR.Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan 33"; end
    end
    -- hand_of_guldan,if=soul_shard>=3&cooldown.summon_demonic_tyrant.remains>20&(cooldown.summon_vilefiend.remains>5|!talent.summon_vilefiend.enabled)&cooldown.call_dreadstalkers.remains>2
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() >= 3 and S.SummonDemonicTyrant:CooldownRemains() > 20 and (S.SummonVilefiend:CooldownRemains() > 5 or not S.SummonVilefiend:IsAvailable()) and S.CallDreadstalkers:CooldownRemains() > 2) then
      if HR.Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan 34"; end
    end
    -- call_action_list,name=covenant,if=(covenant.necrolord|covenant.night_fae)&!talent.nether_portal.enabled
    if ((Player:Covenant() == "Necrolord" or Player:Covenant() == "Night Fae") and not S.NetherPortal:IsAvailable()) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- demonbolt,if=buff.demonic_core.react&soul_shard<4
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4) then
      if HR.Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt 36"; end
    end
    -- grimoire_felguard,if=cooldown.summon_demonic_tyrant.remains+cooldown.summon_demonic_tyrant.duration>time_to_die|time_to_die<cooldown.summon_demonic_tyrant.remains+15
    if CDsON() and S.GrimoireFelguard:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() + 90 > Target:TimeToDie() or Target:TimeToDie() < S.SummonDemonicTyrant:CooldownRemains() + 15) then
      if HR.Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard 38"; end
    end
    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- power_siphon,if=buff.wild_imps.stack>1&buff.demonic_core.stack<3
    if S.PowerSiphon:IsCastable() and (WildImpsCount() > 1 and Player:BuffStack(S.DemonicCoreBuff) < 3) then
      if HR.Cast(S.PowerSiphon) then return "power_siphon 40"; end
    end
    -- soul_strike
    if S.SoulStrike:IsCastable() then
      if HR.Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike 42"; end
    end
    -- call_action_list,name=covenant
    if (true) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt 44"; end
    end
  end
end

local function Init()

end

HR.SetAPL(266, APL, Init)
