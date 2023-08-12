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
local mathmax    = math.max


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Demonology
local I = Item.Warlock.Demonology

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BeacontotheBeyond:ID(),
  I.EruptingSpearFragment:ID(),
  I.Iridal:ID(),
  I.IrideusFragment:ID(),
  I.RotcrustedVoodooDoll:ID(),
  I.SpoilsofNeltharus:ID(),
  I.TimebreachingTalon:ID(),
  I.VoidmendersShadowgem:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()

-- Rotation Var
local BossFightRemains = 11111
local FightRemains = 11111
local VarNextTyrant = 0
local VarPetExpire = 0
local VarNP = false
local VarShadowTimings = 0
local VarTyrantCD = 120
local VarTyrantPrepStart = 0
local CombatTime = 0
local GCDMax = 0

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

-- Function to check two_cast_imps or last_cast_imps
local function CheckImpCasts(count)
  local ImpCount = 0
  for _, Pet in pairs(HL.GuardiansTable.Pets) do
    if Pet.ImpCasts <= count then
      ImpCount = ImpCount + 1
    end
  end
  return ImpCount
end

-- Function to check for Grimoire Felguard
local function GrimoireFelguardTime()
  return HL.GuardiansTable.FelGuardDuration or 0
end

local function GrimoireFelguardActive()
  return GrimoireFelguardTime() > 0
end

-- Function to check for Demonic Tyrant
local function DemonicTyrantTime()
  return HL.GuardiansTable.DemonicTyrantDuration or 0
end

local function DemonicTyrantActive()
  return DemonicTyrantTime() > 0
end

-- Function to check for Dreadstalkers
local function DreadstalkerTime()
  return HL.GuardiansTable.DreadstalkerDuration or 0
end

local function DreadstalkerActive()
  return DreadstalkerTime() > 0
end

-- Function to check for Vilefiend
local function VilefiendTime()
  return HL.GuardiansTable.VilefiendDuration or 0
end

local function VilefiendActive()
  return VilefiendTime() > 0
end

-- Function to check for Pit Lord
local function PitLordTime()
  return HL.GuardiansTable.PitLordDuration or 0
end

local function PitLordActive()
  return PitLordTime() > 0
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
  -- variable,name=tyrant_prep_start,op=set,value=12
  VarTyrantPrepStart = 12
  -- variable,name=next_tyrant,op=set,value=14+talent.grimoire_felguard+talent.summon_vilefiend
  VarNextTyrant = 14 + num(S.GrimoireFelguard:IsAvailable()) + num(S.SummonVilefiend:IsAvailable())
  -- variable,name=shadow_timings,default=0,op=reset
  VarShadowTimings = 0
  -- variable,name=shadow_timings,op=set,value=0,if=cooldown.invoke_power_infusion_0.duration!=120
  if Settings.Demonology.PISource == "Shadow" then
    VarShadowTimings = 1
  end
  -- power_siphon
  if S.PowerSiphon:IsReady() then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon precombat 2"; end
  end
  -- demonbolt,if=!buff.power_siphon.up
  if S.Demonbolt:IsReady() and Player:BuffDown(S.DemonicCoreBuff) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt precombat 4"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 6"; end
  end
end

local function Variables()
  -- variable,name=tyrant_cd,op=setif,value=cooldown.invoke_power_infusion_0.remains,value_else=cooldown.summon_demonic_tyrant.remains,condition=((((fight_remains+time)%%120<=85&(fight_remains+time)%%120>=25)|time>=210)&variable.shadow_timings)&cooldown.invoke_power_infusion_0.duration>0&!talent.grand_warlocks_design
  VarTyrantCD = S.SummonDemonicTyrant:CooldownRemains()
  if bool(VarShadowTimings) then
    local VarPICD = 120 - (GetTime() - Warlock.LastPI)
    -- Note: Moved VarPICD check to the front to avoid unnecessary calculations.
    if VarPICD > 0 and ((((FightRemains + CombatTime) % 120 <= 85 and (FightRemains + CombatTime) % 120 >= 25) or CombatTime >= 210) and VarShadowTimings) and not S.GrandWarlocksDesign:IsAvailable() then
      VarTyrantCD = VarPICD
    end
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains>?buff.vilefiend.remains)-gcd*0.5,if=buff.vilefiend.up&buff.dreadstalkers.up
  if VilefiendActive() and DreadstalkerActive() then
    VarPetExpire = mathmax(VilefiendTime(), DreadstalkerTime()) - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains>?buff.grimoire_felguard.remains)-gcd*0.5,if=!talent.summon_vilefiend&talent.grimoire_felguard&buff.dreadstalkers.up
  if (not S.SummonVilefiend:IsAvailable()) and S.GrimoireFelguard:IsAvailable() and DreadstalkerActive() then
    VarPetExpire = mathmax(DreadstalkerTime(), GrimoireFelguardTime()) - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains)-gcd*0.5,if=!talent.summon_vilefiend&(!talent.grimoire_felguard|!set_bonus.tier30_2pc)&buff.dreadstalkers.up
  if (not S.SummonVilefiend:IsAvailable()) and ((not S.GrimoireFelguard:IsAvailable()) or not Player:HasTier(30, 2)) and DreadstalkerActive() then
    VarPetExpire = DreadstalkerTime() - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=0,if=!buff.vilefiend.up&talent.summon_vilefiend|!buff.dreadstalkers.up
  if (not VilefiendActive()) and S.SummonVilefiend:IsAvailable() or not DreadstalkerActive() then
    VarPetExpire = 0
  end
  -- variable,name=np,op=set,value=(!talent.nether_portal|cooldown.nether_portal.remains>30|buff.nether_portal.up)
  VarNP = ((not S.NetherPortal:IsAvailable()) or S.NetherPortal:CooldownRemains() > 30 or Player:BuffUp(S.NetherPortalBuff))
end

local function Tyrant()
  -- invoke_external_buff,name=power_infusion,if=variable.shadow_timings&variable.pet_expire>0&variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max
  -- Note: Not handling external buffs
  -- hand_of_guldan,if=variable.pet_expire>gcd.max+action.summon_demonic_tyrant.cast_time&variable.pet_expire<gcd.max*4
  if S.HandofGuldan:IsReady() and (VarPetExpire > GCDMax + S.SummonDemonicTyrant:CastTime() and VarPetExpire < GCDMax * 4) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 2"; end
  end
  -- summon_demonic_tyrant,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max
  if S.SummonDemonicTyrant:IsCastable() and (VarPetExpire > 0 and VarPetExpire < S.SummonDemonicTyrant:ExecuteTime() + (num(Player:BuffDown(S.DemonicCoreBuff)) * S.ShadowBolt:ExecuteTime() + num(Player:BuffUp(S.DemonicCoreBuff)) * GCDMax) + GCDMax) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant 4"; end
  end
  -- shadow_bolt,if=buff.fel_covenant.remains<15&(!buff.vilefiend.up|!talent.summon_vilefiend&(!buff.dreadstalkers.up))&time>30,line_cd=40
  if S.ShadowBoltLineCD:IsReady() and S.ShadowBoltLineCD:TimeSinceLastCast() >= 40 and (Player:BuffRemains(S.FelCovenantBuff) < 15 and ((not VilefiendActive()) or (not S.SummonVilefiend:IsAvailable()) and (not DreadstalkerActive())) and CombatTime > 30) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 6"; end
  end
  -- shadow_bolt,if=prev_gcd.1.grimoire_felguard&time>30&buff.nether_portal.down&buff.demonic_core.down|time<10&buff.fel_covenant.stack<2&talent.fel_covenant&fight_remains%%90>40
  if S.ShadowBolt:IsReady() and (Player:PrevGCDP(1, S.GrimoireFelguard) and CombatTime > 30 and Player:BuffDown(S.NetherPortalBuff) and Player:BuffDown(S.DemonicCoreBuff) or CombatTime < 10 and Player:BuffStack(S.FelCovenantBuff) < 2 and S.FelCovenant:IsAvailable() and FightRemains % 90 > 40) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 8"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<2&soul_shard=5&(!buff.vilefiend.up|!talent.summon_vilefiend&(!buff.dreadstalkers.up))&(buff.nether_portal.down)
  if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 2 and Player:SoulShardsP() == 5 and ((not VilefiendActive()) or (not S.SummonVilefiend:IsAvailable()) and DreadstalkerTime()) and Player:BuffDown(S.NetherPortalBuff)) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 10"; end
  end
  -- shadow_bolt,if=buff.vilefiend.down&buff.nether_portal.down&buff.dreadstalkers.down&soul_shard<5-buff.demonic_core.stack
  if S.ShadowBolt:IsReady() and ((not VilefiendActive()) and Player:BuffDown(S.NetherPortalBuff) and (not DreadstalkerActive()) and Player:SoulShardsP() < 5 - Player:BuffStack(S.DemonicCoreBuff)) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 12"; end
  end
  -- nether_portal,if=soul_shard=5
  if S.NetherPortal:IsReady() and (Player:SoulShardsP() == 5) then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal tyrant 14"; end
  end
  -- soulburn,if=buff.nether_portal.up&cooldown.call_dreadstalkers.remains>10&soul_shard>1
  if S.Soulburn:IsReady() and (Player:BuffUp(S.NetherPortalBuff) and S.CallDreadstalkers:CooldownRemains() > 10 and Player:SoulShardsP() > 1) then
    if Cast(S.Soulburn) then return "soulburn tyrant 16"; end
  end
  -- summon_vilefiend,if=(soul_shard=5|buff.nether_portal.up)&cooldown.summon_demonic_tyrant.remains<13&variable.np
  if S.SummonVilefiend:IsReady() and ((Player:SoulShardsP() == 5 or Player:BuffUp(S.NetherPortalBuff)) and S.SummonDemonicTyrant:CooldownRemains() < 13 and VarNP) then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend tyrant 18"; end
  end
  -- call_dreadstalkers,if=(buff.vilefiend.up|!talent.summon_vilefiend&(!talent.nether_portal|buff.nether_portal.up|cooldown.nether_portal.remains>30)&(buff.nether_portal.up|buff.grimoire_felguard.up|soul_shard=5))&cooldown.summon_demonic_tyrant.remains<11&variable.np
  if S.CallDreadstalkers:IsReady() and ((VilefiendActive() or (not S.SummonVilefiend:IsAvailable()) and ((not S.NetherPortal:IsAvailable()) or Player:BuffUp(S.NetherPortalBuff) or S.NetherPortal:CooldownRemains() > 30) and (Player:BuffUp(S.NetherPortalBuff) or GrimoireFelguardActive() or Player:SoulShardsP() == 5)) and S.SummonDemonicTyrant:CooldownRemains() < 11 and VarNP) then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant 20"; end
  end
  -- grimoire_felguard,if=buff.vilefiend.up|!talent.summon_vilefiend&(!talent.nether_portal|buff.nether_portal.up|cooldown.nether_portal.remains>30)&(buff.nether_portal.up|buff.dreadstalkers.up|soul_shard=5)&variable.np&(!raid_event.adds.in<15-raid_event.add.duration)
  if S.GrimoireFelguard:IsReady() and (VilefiendActive() or (not S.SummonVilefiend:IsAvailable()) and ((not S.NetherPortal:IsAvailable()) or Player:BuffUp(S.NetherPortalBuff) or S.NetherPortal:CooldownRemains() > 30) and (Player:BuffUp(S.NetherPortalBuff) or DreadstalkerActive() or Player:SoulShardsP() == 5) and VarNP) then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant 22"; end
  end
  -- hand_of_guldan,if=soul_shard>2&(buff.vilefiend.up|!talent.summon_vilefiend&buff.dreadstalkers.up)&(soul_shard>2|buff.vilefiend.remains<gcd.max*2+2%spell_haste)|buff.nether_portal.up
  if S.HandofGuldan:IsReady() and (Player:SoulShardsP() > 2 and (VilefiendActive() or (not S.SummonVilefiend:IsAvailable()) and DreadstalkerActive()) and (Player:SoulShardsP() > 2 or VilefiendTime() < GCDMax * 2 + 2 / Player:SpellHaste()) or Player:BuffUp(S.NetherPortalBuff)) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 24"; end
  end
  -- power_siphon,if=buff.demonic_core.down
  if S.PowerSiphon:IsReady() and (Player:BuffDown(S.DemonicCoreBuff)) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 26"; end
  end
  -- demonbolt,if=soul_shard<4&buff.demonic_core.up&(buff.vilefiend.up|!talent.summon_vilefiend&buff.dreadstalkers.up)
  if S.Demonbolt:IsReady() and (Player:SoulShardsP() < 4 and Player:BuffUp(S.DemonicCoreBuff) and (VilefiendActive() or (not S.SummonVilefiend:IsAvailable()) and DreadstalkerActive())) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt tyrant 28"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<3&variable.pet_expire>action.summon_demonic_tyrant.execute_time+gcd.max*3|variable.pet_expire=0
  if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 3 and VarPetExpire > S.SummonDemonicTyrant:ExecuteTime() + GCDMax * 3 or VarPetExpire == 0) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 30"; end
  end
  -- soul_strike
  if S.SoulStrike:IsReady() then
    if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike tyrant 32"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 34"; end
  end
end

local function FightEnd()
  if FightRemains < 20 then
    -- grimoire_felguard,if=fight_remains<20
    if S.GrimoireFelguard:IsReady() then
      if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard) then return "grimoire_felguard fight_end 2"; end
    end
    -- call_dreadstalkers,if=fight_remains<20
    if S.CallDreadstalkers:IsReady() then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers fight_end 4"; end
    end
    -- summon_vilefiend,if=fight_remains<20
    if S.SummonVilefiend:IsReady() then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend fight_end 6"; end
    end
  end
  -- nether_portal,if=fight_remains<30
  if S.NetherPortal:IsReady() and (FightRemains < 30) then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal fight_end 8"; end
  end
  -- summon_demonic_tyrant,if=fight_remains<20
  if S.SummonDemonicTyrant:IsCastable() and (FightRemains < 20) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant fight_end 10"; end
  end
  -- demonic_strength,if=fight_remains<10
  if S.DemonicStrength:IsCastable() and (FightRemains < 10) then
    if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength fight_end 12"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<3&fight_remains<20
  if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 3 and FightRemains < 20) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon fight_end 14"; end
  end
  -- implosion,if=fight_remains<2*gcd.max
  if S.Implosion:IsReady() and (FightRemains < 2 * GCDMax) then
    if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion fight_end 16"; end
  end
end

local function Racials()
  -- berserking,use_off_gcd=1
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racials 2"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racials 4"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racials 6"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racials 8"; end
  end
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    if DemonicTyrantActive() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax * 2 or not S.NetherPortal:IsAvailable()) or FightRemains < 22 then
      -- use_item,name=irideus_fragment,if=pet.demonic_tyrant.active&(buff.nether_portal.remains<gcd.max*2|!talent.nether_portal)|fight_remains<22
      if I.IrideusFragment:IsEquippedAndReady() then
        if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment items 2"; end
      end
      -- use_item,name=timebreaching_talon,if=pet.demonic_tyrant.active&(buff.nether_portal.remains<gcd.max*2|!talent.nether_portal)|fight_remains<22
      if I.TimebreachingTalon:IsEquippedAndReady() then
        if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon items 4"; end
      end
      -- use_item,name=spoils_of_neltharus,if=pet.demonic_tyrant.active&(buff.nether_portal.remains<gcd.max*2|!talent.nether_portal)|fight_remains<22
      if I.SpoilsofNeltharus:IsEquippedAndReady() then
        if Cast(I.SpoilsofNeltharus, nil, Settings.Commons.DisplayStyle.Trinkets) then return "spoils_of_neltharus items 6"; end
      end
    end
    -- use_item,name=voidmenders_shadowgem,if=!variable.shadow_timings|(variable.shadow_timings&(buff.demonic_power.up|!talent.summon_demonic_tyrant&(buff.nether_portal.up|!talent.nether_portal)))
    if I.VoidmendersShadowgem:IsEquippedAndReady() and ((not VarShadowTimings) or (VarShadowTimings and (Player:BuffUp(S.DemonicPowerBuff) or (not S.SummonDemonicTyrant:IsAvailable()) and (Player:BuffUp(S.NetherPortalBuff) or not S.NetherPortal:IsAvailable())))) then
      if Cast(I.VoidmendersShadowgem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "voidmenders_shadowgem items 8"; end
    end
    -- use_item,name=erupting_spear_fragment,,if=pet.demonic_tyrant.active&(buff.nether_portal.remains<gcd.max*2|!talent.nether_portal)|fight_remains<12
    if I.EruptingSpearFragment:IsEquippedAndReady() and (DemonicTyrantActive() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax * 2 or not S.NetherPortal:IsAvailable()) or FightRemains < 12) then
      if Cast(I.EruptingSpearFragment, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment items 10"; end
    end
  end
  -- use_items,if=(buff.demonic_power.up|!talent.summon_demonic_tyrant&(buff.nether_portal.up|!talent.nether_portal))&(!equipped.irideus_fragment&!equipped.timebreaching_talon&!equipped.spoils_of_neltharus&!equipped.erupting_spear_fragment&!equipped.voidmenders_shadowgem)
  -- Note: Excluded trinkets are excluded via OnUseExcludes, so ignoring that portion of the condition.
  if (Player:BuffUp(S.DemonicPowerBuff) or (not S.SummonDemonicTyrant:IsAvailable()) and (Player:BuffUp(S.NetherPortalBuff) or not S.NetherPortal:IsAvailable())) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=rotcrusted_voodoo_doll
    if I.RotcrustedVoodooDoll:IsEquippedAndReady() then
      if Cast(I.RotcrustedVoodooDoll, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "rotcrusted_voodoo_doll items 12"; end
    end
    -- use_item,name=beacon_to_the_beyond
    if I.BeacontotheBeyond:IsEquippedAndReady() then
      if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond items 14"; end
    end
  end
  -- use_item,name=iridal_the_earths_master,if=buff.demonic_power.down&cooldown.summon_demonic_tyrant.remains>30
  if Settings.Commons.Enabled.Items and I.Iridal:IsEquippedAndReady() and (Player:BuffDown(S.DemonicPowerBuff) and S.SummonDemonicTyrant:CooldownRemains() > 30) then
    if Cast(I.Iridal, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(40)) then return "iridal_the_earths_master items 16"; end
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

    -- Update CombatTime, which is used in many spell suggestions
    CombatTime = HL.CombatTime()

    -- Set GCDMax
    GCDMax = Player:GCD() + 0.25
  end

  -- summon_pet
  if S.SummonPet:IsCastable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if Cast(S.SummonPet, Settings.Demonology.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
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
    if S.UnendingResolve:IsReady() and (Player:HealthPercentage() < Settings.Demonology.UnendingResolveHP) then
      if Cast(S.UnendingResolve, Settings.Demonology.OffGCDasOffGCD.UnendingResolve) then return "unending_resolve defensive"; end
    end
    -- call_action_list,name=variables
    Variables()
    -- invoke_external_buff,name=power_infusion,if=(buff.nether_portal.up&buff.nether_portal.remains<8&talent.nether_portal)|fight_remains<20|pet.demonic_tyrant.active&fight_remains<100|fight_remains<25|!talent.nether_portal&(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant&buff.dreadstalkers.up)
    -- Note: Not handling external buffs
    -- call_action_list,name=fight_end,if=fight_remains<30
    if FightRemains < 30 then
      local ShouldReturn = FightEnd(); if ShouldReturn then return ShouldReturn; end
    end
    -- hand_of_guldan,if=time<0.5&(fight_remains%%95>40|fight_remains%%95<15)
    if S.HandofGuldan:IsReady() and (CombatTime < 0.5 and (FightRemains % 95 > 40 or FightRemains % 95 < 15)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 2"; end
    end
    -- call_action_list,name=tyrant,if=cooldown.summon_demonic_tyrant.remains<15&cooldown.summon_vilefiend.remains<gcd.max*5&cooldown.call_dreadstalkers.remains<gcd.max*5&(cooldown.grimoire_felguard.remains<10|!set_bonus.tier30_2pc)&(!variable.shadow_timings|variable.tyrant_cd<15|fight_remains<40|buff.power_infusion.up)
    if (S.SummonDemonicTyrant:CooldownRemains() < 15 and S.SummonVilefiend:CooldownRemains() < GCDMax * 5 and S.CallDreadstalkers:CooldownRemains() < GCDMax * 5 and (S.GrimoireFelguard:CooldownRemains() < 10 or not Player:HasTier(30, 2)) and ((not VarShadowTimings) or VarTyrantCD < 15 or FightRemains < 40 or Player:BuffUp(S.PowerInfusionBuff))) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=tyrant,if=cooldown.summon_demonic_tyrant.remains<15&(buff.vilefiend.up|!talent.summon_vilefiend&(buff.grimoire_felguard.up|cooldown.grimoire_felguard.up|!set_bonus.tier30_2pc))&(!variable.shadow_timings|variable.tyrant_cd<15|fight_remains<40|buff.power_infusion.up)
    if (S.SummonDemonicTyrant:CooldownRemains() < 15 and (VilefiendActive() or (not S.SummonVilefiend:IsAvailable()) and (GrimoireFelguardActive() or S.GrimoireFelguard:CooldownUp() or not Player:HasTier(30, 2))) and ((not VarShadowTimings) or VarTyrantCD < 15 or FightRemains < 40 or Player:BuffUp(S.PowerInfusionBuff))) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- summon_demonic_tyrant,if=buff.vilefiend.up|buff.grimoire_felguard.up|cooldown.grimoire_felguard.remains>90
    if S.SummonDemonicTyrant:IsCastable() and (VilefiendActive() or GrimoireFelguardActive() or S.GrimoireFelguard:CooldownRemains() > 90) then
      if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant main 4"; end
    end
    -- call_action_list,name=racials,if=pet.demonic_tyrant.active&(buff.nether_portal.remains<=2)|fight_remains<22
    if DemonicTyrantActive() and Player:BuffRemains(S.NetherPortalBuff) <= 2 or FightRemains < 22 then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- potion,if=pet.demonic_tyrant.active
    if Settings.Commons.Enabled.Potions and DemonicTyrantActive() then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- call_action_list,name=items,use_off_gcd=1
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    -- shadow_bolt,if=talent.fel_covenant&buff.fel_covenant.remains<5&!prev_gcd.1.shadow_bolt&soul_shard<5
    if S.ShadowBolt:IsReady() and (S.FelCovenant:IsAvailable() and Player:BuffRemains(S.FelCovenantBuff) < 5 and (not Player:PrevGCDP(1, S.ShadowBolt)) and Player:SoulShardsP() < 5) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 8"; end
    end
    -- hand_of_guldan,if=buff.nether_portal.remains>cast_time
    if S.HandofGuldan:IsReady() and (Player:BuffRemains(S.NetherPortalBuff) > S.HandofGuldan:CastTime()) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 10"; end
    end
    -- demonic_strength,if=buff.nether_portal.remains<gcd.max&(fight_remains>63&!(fight_remains>cooldown.summon_demonic_tyrant.remains+69)|cooldown.summon_demonic_tyrant.remains>30|variable.shadow_timings|buff.rite_of_ruvaraad.up|!talent.summon_demonic_tyrant|!talent.grimoire_felguard|!set_bonus.tier30_2pc)
    if S.DemonicStrength:IsCastable() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax and (FightRemains > 63 and (not (FightRemains > S.SummonDemonicTyrant:CooldownRemains() + 69)) or S.SummonDemonicTyrant:CooldownRemains() > 30 or VarShadowTimings or Player:BuffUp(S.RiteofRuvaraadBuff) or (not S.SummonDemonicTyrant:IsAvailable()) or (not S.GrimoireFelguard:IsAvailable()) or not Player:HasTier(30, 2))) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 12"; end
    end
    -- guillotine,if=buff.nether_portal.remains<gcd.max&(cooldown.demonic_strength.remains|!talent.demonic_strength)
    if S.Guillotine:IsCastable() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax and (S.DemonicStrength:CooldownDown() or not S.DemonicStrength:IsAvailable())) then
      if Cast(S.Guillotine, nil, nil, not Target:IsInRange(40)) then return "guillotine main 14"; end
    end
    -- bilescourge_bombers,if=!pet.demonic_tyrant.active
    if S.BilescourgeBombers:IsReady() and (not DemonicTyrantActive()) then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 16"; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains>25|variable.tyrant_cd>25|buff.nether_portal.up
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 25 or VarTyrantCD > 25 or Player:BuffUp(S.NetherPortalBuff)) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 18"; end
    end
    -- implosion,if=two_cast_imps>0&buff.tyrant.down&active_enemies>1+(talent.sacrificed_souls.enabled)&!prev_gcd.1.implosion
    if S.Implosion:IsReady() and (CheckImpCasts(2) > 0 and (not DemonicTyrantActive()) and EnemiesCount8ySplash > 1 + num(S.SacrificedSouls:IsAvailable()) and not Player:PrevGCDP(1, S.Implosion)) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 20"; end
    end
    -- implosion,if=buff.wild_imps.stack>9&buff.tyrant.up&active_enemies>2+(1*talent.sacrificed_souls.enabled)&cooldown.call_dreadstalkers.remains>17&talent.the_expendables&!prev_gcd.1.implosion
    if S.Implosion:IsReady() and (WildImpsCount() > 9 and DemonicTyrantActive() and EnemiesCount8ySplash > 2 + num(S.SacrificedSouls:IsAvailable()) and S.CallDreadstalkers:CooldownRemains() > 17 and S.TheExpendables:IsAvailable() and not Player:PrevGCDP(1, S.Implosion)) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 22"; end
    end
    -- soul_strike,if=soul_shard<5&active_enemies>1
    if S.SoulStrike:IsReady() and (Player:SoulShardsP() < 5 and EnemiesCount8ySplash > 1) then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 24"; end
    end
    -- summon_soulkeeper,if=buff.tormented_soul.stack=10&active_enemies>1
    if S.SummonSoulkeeper:IsReady() and (S.SummonSoulkeeper:Count() == 10 and EnemiesCount8ySplash > 1) then
      if Cast(S.SummonSoulkeeper) then return "soul_strike main 26"; end
    end
    -- power_siphon,if=buff.demonic_core.stack<2&cooldown.summon_demonic_tyrant.remains>38&(buff.dreadstalkers.down|buff.dreadstalkers.remains>gcd.max*5)
    if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 2 and S.SummonDemonicTyrant:CooldownRemains() > 38 and ((not DreadstalkerActive()) or DreadstalkerTime() > GCDMax * 5)) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 28"; end
    end
    -- hand_of_guldan,if=soul_shard>2
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() > 2) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 30"; end
    end
    -- demonbolt,if=buff.demonic_core.up&soul_shard<4
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and Player:SoulShardsP() < 4) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 32"; end
    end
    -- demonbolt,if=fight_remains<buff.demonic_core.stack*gcd.max
    if S.Demonbolt:IsReady() and (FightRemains < Player:BuffStack(S.DemonicCoreBuff) * GCDMax) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 34"; end
    end
    -- power_siphon,if=buff.demonic_core.stack<2&(cooldown.summon_demonic_tyrant.remains>38|variable.tyrant_cd>38)&(buff.dreadstalkers.down|buff.dreadstalkers.remains>gcd.max*5)
    if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 2 and (S.SummonDemonicTyrant:CooldownRemains() > 38 or VarTyrantCD > 38) and ((not DreadstalkerActive()) or DreadstalkerTime() > GCDMax * 5)) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 36"; end
    end
    -- demonic_strength,if=(fight_remains>63&!(fight_remains>cooldown.summon_demonic_tyrant.remains+69)|cooldown.summon_demonic_tyrant.remains>30|buff.rite_of_ruvaraad.up|variable.shadow_timings|!talent.summon_demonic_tyrant|!talent.grimoire_felguard|!set_bonus.tier30_2pc)
    if S.DemonicStrength:IsCastable() and (FightRemains > 63 and (not (FightRemains > S.SummonDemonicTyrant:CooldownRemains() + 69)) or S.SummonDemonicTyrant:CooldownRemains() > 30 or Player:BuffUp(S.RiteofRuvaraadBuff) or VarShadowTimings or (not S.SummonDemonicTyrant:IsAvailable()) or (not S.GrimoireFelguard:IsAvailable()) or not Player:HasTier(30, 2)) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 38"; end
    end
    -- summon_vilefiend,if=fight_remains<cooldown.summon_demonic_tyrant.remains+5
    if S.SummonVilefiend:IsReady() and (FightRemains < S.SummonDemonicTyrant:CooldownRemains() + 5) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 40"; end
    end
    -- hand_of_guldan,if=soul_shard>2&cooldown.summon_demonic_tyrant.remains>15|soul_shard=5
    if S.HandofGuldan:IsReady() and (Player:SoulShardsP() > 2 and S.SummonDemonicTyrant:CooldownRemains() > 15 or Player:SoulShardsP() == 5) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 42"; end
    end
    -- doom,target_if=refreshable
    if S.Doom:IsReady() then
      if Everyone.CastCycle(S.Doom, Enemies40y, EvaluateDoom, not Target:IsSpellInRange(S.Doom)) then return "doom main 44"; end
    end
    -- soul_strike,if=soul_shard<5
    if S.SoulStrike:IsReady() and (Player:SoulShardsP() < 5) then
      if Cast(S.SoulStrike, nil, nil, not Target:IsSpellInRange(S.SoulStrike)) then return "soul_strike main 46"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 48"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation is currently a work in progress, but has been updated for patch 10.1.5.")
end

HR.SetAPL(266, APL, Init)
