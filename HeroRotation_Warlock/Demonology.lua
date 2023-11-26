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
  I.NymuesUnravelingSpindle:ID(),
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- Rotation Var
local BossFightRemains = 11111
local FightRemains = 11111
local VarNextTyrant = 0
local VarPetExpire = 0
local VarNP = false
local VarImpl = false
local VarPoolCoresForTyrant = false
local VarShadowTimings = 0
local VarTyrantTimings = 0
local VarTyrantSync = 0
local VarTyrantCD = 120
local VarTyrantPrepStart = 0
local SoulShards = 0
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
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
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

-- CastTargetIf/CastCycle Functions
local function EvaluateCycleDemonbolt(TargetUnit)
  -- target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3)
  return (TargetUnit:DebuffDown(S.DoomBrandDebuff) or S.HandofGuldan:InFlight() and Target:DebuffRemains(S.DoomBrandDebuff) <= 3)
end

local function EvaluateCycleDemonbolt2(TargetUnit)
  -- target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3)|active_enemies<4
  return ((TargetUnit:DebuffDown(S.DoomBrandDebuff) or S.HandofGuldan:InFlight() and TargetUnit:DebuffRemains(S.DoomBrandDebuff) <= 3) or EnemiesCount8ySplash < 4)
end

local function EvaluateCycleDoom(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.Doom))
end

local function EvaluateTargetIfDemonbolt(TargetUnit)
  -- if=set_bonus.tier31_2pc&(debuff.doom_brand.remains>10&buff.demonic_core.up&soul_shard<4)&!variable.pool_cores_for_tyrant
  -- Note: All but debuff.doom_brand.remains handled prior to CastTargetIf.
  return (TargetUnit:DebuffRemains(S.DoomBrandDebuff) > 10)
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
  -- variable,name=tyrant_timings,value=0
  VarTyrantTimings = 0
  -- variable,name=shadow_timings,op=set,value=0,if=cooldown.invoke_power_infusion_0.duration!=120
  if Settings.Demonology.PISource == "Shadow" then
    VarShadowTimings = 1
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.spoils_of_neltharus
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.spoils_of_neltharus
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon|trinket.1.is.timethiefs_gambit
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon|trinket.2.is.timethiefs_gambit
  -- variable,name=trinket_1_manual,value=trinket.1.is.nymues_unraveling_spindle
  -- variable,name=trinket_2_manual,value=trinket.2.is.nymues_unraveling_spindle
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.mirror_of_fractured_tomorrows*20)+(trinket.1.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.mirror_of_fractured_tomorrows*20)+(trinket.2.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.summon_demonic_tyrant.duration=0|cooldown.summon_demonic_tyrant.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.summon_demonic_tyrant.duration=0|cooldown.summon_demonic_tyrant.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>trinket.1.ilvl
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1.5+trinket.2.has_buff.intellect)*(variable.trinket_2_sync)*(1-0.5*trinket.2.is.mirror_of_fractured_tomorrows))>(((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1.5+trinket.1.has_buff.intellect)*(variable.trinket_1_sync)*(1-0.5*trinket.1.is.mirror_of_fractured_tomorrows))*(1+((trinket.1.ilvl-trinket.2.ilvl)%100)))
  -- Note: Currently can't handle the variables above.
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
  -- variable,name=tyrant_timings,op=set,value=120+time,if=((buff.nether_portal.up&buff.nether_portal.remains<3&talent.nether_portal)|fight_remains<20|pet.demonic_tyrant.active&fight_remains<100|fight_remains<25|(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant&buff.dreadstalkers.up))&variable.tyrant_sync<=0
  if ((Player:BuffUp(S.NetherPortalBuff) and Player:BuffRemains(S.NetherPortalBuff) < 3 and S.NetherPortal:IsAvailable()) or FightRemains < 20 or DemonicTyrantActive() and FightRemains < 100 or FightRemains < 25 or (DemonicTyrantActive() or not S.SummonDemonicTyrant:IsAvailable() and DreadstalkerActive())) and VarTyrantSync <= 0 then
    VarTyrantTimings = 120 + CombatTime
  end
  -- variable,name=tyrant_sync,value=(variable.tyrant_timings-time)
  VarTyrantSync = VarTyrantTimings - CombatTime
  -- variable,name=tyrant_cd,op=setif,value=variable.tyrant_sync,value_else=cooldown.summon_demonic_tyrant.remains,condition=((((fight_remains+time)%%120<=85&(fight_remains+time)%%120>=25)|time>=210))&variable.tyrant_sync>0&!talent.grand_warlocks_design
  if (((FightRemains + CombatTime) % 120 <= 85 and (FightRemains + CombatTime) % 120 >= 25) or CombatTime >= 210) and VarTyrantSync > 0 and not S.GrandWarlocksDesign:IsAvailable() then
    VarTyrantCD = VarTyrantSync
  else
    VarTyrantCD = S.SummonDemonicTyrant:CooldownRemains()
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains>?buff.vilefiend.remains)-gcd*0.5,if=buff.vilefiend.up&buff.dreadstalkers.up
  if VilefiendActive() and DreadstalkerActive() then
    VarPetExpire = mathmax(VilefiendTime(), DreadstalkerTime()) - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains>?buff.grimoire_felguard.remains)-gcd*0.5,if=!talent.summon_vilefiend&talent.grimoire_felguard&buff.dreadstalkers.up
  if not S.SummonVilefiend:IsAvailable() and S.GrimoireFelguard:IsAvailable() and DreadstalkerActive() then
    VarPetExpire = mathmax(DreadstalkerTime(), GrimoireFelguardTime()) - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=(buff.dreadstalkers.remains)-gcd*0.5,if=!talent.summon_vilefiend&(!talent.grimoire_felguard|!set_bonus.tier30_2pc)&buff.dreadstalkers.up
  if not S.SummonVilefiend:IsAvailable() and (not S.GrimoireFelguard:IsAvailable() or not Player:HasTier(30, 2)) and DreadstalkerActive() then
    VarPetExpire = DreadstalkerTime() - Player:GCD() * 0.5
  end
  -- variable,name=pet_expire,op=set,value=0,if=!buff.vilefiend.up&talent.summon_vilefiend|!buff.dreadstalkers.up
  if not VilefiendActive() and S.SummonVilefiend:IsAvailable() or not DreadstalkerActive() then
    VarPetExpire = 0
  end
  -- variable,name=np,op=set,value=(!talent.nether_portal|cooldown.nether_portal.remains>30|buff.nether_portal.up)
  VarNP = (not S.NetherPortal:IsAvailable() or S.NetherPortal:CooldownRemains() > 30 or Player:BuffUp(S.NetherPortalBuff))
  local SacSoulsValue = num(S.SacrificedSouls:IsAvailable())
  -- variable,name=impl,op=set,value=buff.tyrant.down,if=active_enemies>1+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 1 + SacSoulsValue then
    VarImpl = not DemonicTyrantActive()
  end
  -- variable,name=impl,op=set,value=buff.tyrant.remains<6,if=active_enemies>2+(talent.sacrificed_souls.enabled)&active_enemies<5+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 2 + SacSoulsValue and EnemiesCount8ySplash < 5 + SacSoulsValue then
    VarImpl = DemonicTyrantTime() < 6
  end
  -- variable,name=impl,op=set,value=buff.tyrant.remains<8,if=active_enemies>4+(talent.sacrificed_souls.enabled)
  if EnemiesCount8ySplash > 4 + SacSoulsValue then
    VarImpl = DemonicTyrantTime() < 8
  end
  -- variable,name=pool_cores_for_tyrant,op=set,value=cooldown.summon_demonic_tyrant.remains<20&variable.tyrant_cd<20&(buff.demonic_core.stack<=2|!buff.demonic_core.up)&cooldown.summon_vilefiend.remains<gcd.max*5&cooldown.call_dreadstalkers.remains<gcd.max*5
  VarPoolCoresForTyrant = S.SummonDemonicTyrant:CooldownRemains() < 20 and VarTyrantCD < 20 and (Player:BuffStack(S.DemonicCoreBuff) <= 2 or Player:BuffDown(S.DemonicCoreBuff)) and S.SummonVilefiend:CooldownRemains() < GCDMax * 5 and S.CallDreadstalkers:CooldownRemains() < GCDMax * 5
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
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!pet.demonic_tyrant.active&trinket.1.cast_time>0|!trinket.1.cast_time>0)&(pet.demonic_tyrant.active)&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1&!variable.trinket_2_manual)|variable.trinket_1_buff_duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!pet.demonic_tyrant.active&trinket.2.cast_time>0|!trinket.2.cast_time>0)&(pet.demonic_tyrant.active)&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2&!variable.trinket_1_manual)|variable.trinket_2_buff_duration>=fight_remains
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&((variable.damage_trinket_priority=1|trinket.2.cooldown.remains)&(trinket.1.cast_time>0&!pet.demonic_tyrant.active|!trinket.1.cast_time>0)|(time<20&variable.trinket_2_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&((variable.damage_trinket_priority=2|trinket.1.cooldown.remains)&(trinket.2.cast_time>0&!pet.demonic_tyrant.active|!trinket.2.cast_time>0)|(time<20&variable.trinket_1_buffs)|cooldown.summon_demonic_tyrant.remains_expected>20)
  -- use_item,use_off_gcd=1,slot=main_hand,if=(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  -- use_item,name=nymues_unraveling_spindle,if=trinket.1.is.nymues_unraveling_spindle&((pet.demonic_tyrant.active&!cooldown.demonic_strength.ready&!variable.trinket_2_buffs)|(variable.trinket_2_buffs))|trinket.2.is.nymues_unraveling_spindle&((pet.demonic_tyrant.active&!cooldown.demonic_strength.ready&!variable.trinket_1_buffs)|(variable.trinket_1_buffs))|fight_remains<22
  -- use_item,name=timethiefs_gambit,if=pet.demonic_tyrant.active
  -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains)
  -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains)
  -- Note: Can't handle some of the above conditions, so using a generic use_items to cover trinkets and other items.
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if (ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets or (ItemSlot ~= 13 and ItemSlot ~= 14) and Settings.Commons.Enabled.Items then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for "..ItemToUse:Name(); end
      end
    end
  end
end

local function Tyrant()
  -- invoke_external_buff,name=power_infusion,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max
  -- Note: Not handling external buffs
  -- variable,name=tyrant_timings,op=set,value=120+time,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max&variable.tyrant_timings<=0
  if VarPetExpire > 0 and VarPetExpire < S.SummonDemonicTyrant:ExecuteTime() + (num(Player:BuffDown(S.DemonicCoreBuff)) * S.ShadowBolt:ExecuteTime() + num(Player:BuffUp(S.DemonicCoreBuff)) * GCDMax) + GCDMax and VarTyrantTimings <= 0 then
    VarTyrantTimings = 120 + CombatTime
  end
  -- variable,name=dummyvar,value=variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max
  -- Note: Not used in the profile, so not declaring it...
  -- hand_of_guldan,if=variable.pet_expire>gcd.max+action.summon_demonic_tyrant.cast_time&variable.pet_expire<gcd.max*4
  if S.HandofGuldan:IsReady() and SoulShards > 0 and (VarPetExpire > GCDMax + S.SummonDemonicTyrant:CastTime() and VarPetExpire < GCDMax * 4) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 2"; end
  end
  if VarPetExpire > 0 and VarPetExpire < S.SummonDemonicTyrant:ExecuteTime() + (num(Player:BuffDown(S.DemonicCoreBuff)) * S.ShadowBolt:ExecuteTime() + num(Player:BuffUp(S.DemonicCoreBuff)) * GCDMax) + GCDMax then
    -- call_action_list,name=items,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max,use_off_gcd=1
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=racials,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max,use_off_gcd=1
    local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    -- potion,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max,use_off_gcd=1
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion tyrant 4"; end
      end
    end
  end
  -- summon_demonic_tyrant,if=variable.pet_expire>0&variable.pet_expire<action.summon_demonic_tyrant.execute_time+(buff.demonic_core.down*action.shadow_bolt.execute_time+buff.demonic_core.up*gcd.max)+gcd.max
  if S.SummonDemonicTyrant:IsCastable() and (VarPetExpire > 0 and VarPetExpire < S.SummonDemonicTyrant:ExecuteTime() + (num(Player:BuffDown(S.DemonicCoreBuff)) * S.ShadowBolt:ExecuteTime() + num(Player:BuffUp(S.DemonicCoreBuff)) * GCDMax) + GCDMax) then
    if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant tyrant 6"; end
  end
  -- implosion,if=pet_count>2&(buff.dreadstalkers.down&buff.grimoire_felguard.down&buff.vilefiend.down)&(active_enemies>3|active_enemies>2&talent.grand_warlocks_design)&!prev_gcd.1.implosion
  if S.Implosion:IsReady() and (WildImpsCount() > 2 and (not DreadstalkerActive() and not GrimoireFelguardActive() and not VilefiendActive()) and (EnemiesCount8ySplash > 3 or EnemiesCount8ySplash > 2 and S.GrandWarlocksDesign:IsAvailable()) and not Player:PrevGCDP(1, S.Implosion)) then
    if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion tyrant 8"; end
  end
  -- shadow_bolt,if=prev_gcd.1.grimoire_felguard&time>30&buff.nether_portal.down&buff.demonic_core.down
  if S.ShadowBolt:IsReady() and (Player:PrevGCDP(1, S.GrimoireFelguard) and CombatTime > 30 and Player:BuffDown(S.NetherPortalBuff) and Player:BuffDown(S.DemonicCoreBuff)) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 10"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<4&(!buff.vilefiend.up|!talent.summon_vilefiend&(!buff.dreadstalkers.up))&(buff.nether_portal.down)
  if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 4 and (not VilefiendActive() or not S.SummonVilefiend:IsAvailable() and DreadstalkerTime()) and Player:BuffDown(S.NetherPortalBuff)) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 12"; end
  end
  -- shadow_bolt,if=buff.vilefiend.down&buff.nether_portal.down&buff.dreadstalkers.down&soul_shard<5-buff.demonic_core.stack
  if S.ShadowBolt:IsReady() and (not VilefiendActive() and Player:BuffDown(S.NetherPortalBuff) and not DreadstalkerActive() and SoulShards < 5 - Player:BuffStack(S.DemonicCoreBuff)) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 14"; end
  end
  -- nether_portal,if=soul_shard=5
  if S.NetherPortal:IsReady() and (SoulShards == 5) then
    if Cast(S.NetherPortal, Settings.Demonology.GCDasOffGCD.NetherPortal) then return "nether_portal tyrant 16"; end
  end
  -- summon_vilefiend,if=(soul_shard=5|buff.nether_portal.up)&cooldown.summon_demonic_tyrant.remains<13&variable.np
  if S.SummonVilefiend:IsReady() and ((SoulShards == 5 or Player:BuffUp(S.NetherPortalBuff)) and S.SummonDemonicTyrant:CooldownRemains() < 13 and VarNP) then
    if Cast(S.SummonVilefiend) then return "summon_vilefiend tyrant 18"; end
  end
  -- call_dreadstalkers,if=(buff.vilefiend.up|!talent.summon_vilefiend&(!talent.nether_portal|buff.nether_portal.up|cooldown.nether_portal.remains>30)&(buff.nether_portal.up|buff.grimoire_felguard.up|soul_shard=5))&cooldown.summon_demonic_tyrant.remains<11&variable.np
  if S.CallDreadstalkers:IsReady() and ((VilefiendActive() or not S.SummonVilefiend:IsAvailable() and (not S.NetherPortal:IsAvailable() or Player:BuffUp(S.NetherPortalBuff) or S.NetherPortal:CooldownRemains() > 30) and (Player:BuffUp(S.NetherPortalBuff) or GrimoireFelguardActive() or SoulShards == 5)) and S.SummonDemonicTyrant:CooldownRemains() < 11 and VarNP) then
    if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers tyrant 20"; end
  end
  -- grimoire_felguard,if=buff.vilefiend.up|!talent.summon_vilefiend&(!talent.nether_portal|buff.nether_portal.up|cooldown.nether_portal.remains>30)&(buff.nether_portal.up|buff.dreadstalkers.up|soul_shard=5)&variable.np
  if S.GrimoireFelguard:IsReady() and (VilefiendActive() or not S.SummonVilefiend:IsAvailable() and (not S.NetherPortal:IsAvailable() or Player:BuffUp(S.NetherPortalBuff) or S.NetherPortal:CooldownRemains() > 30) and (Player:BuffUp(S.NetherPortalBuff) or DreadstalkerActive() or SoulShards == 5) and VarNP) then
    if Cast(S.GrimoireFelguard, Settings.Demonology.GCDasOffGCD.GrimoireFelguard, nil, not Target:IsSpellInRange(S.GrimoireFelguard)) then return "grimoire_felguard tyrant 22"; end
  end
  -- hand_of_guldan,if=soul_shard>2&(buff.vilefiend.up|!talent.summon_vilefiend&buff.dreadstalkers.up)&(soul_shard>2|buff.vilefiend.remains<gcd.max*2+2%spell_haste)
  if S.HandofGuldan:IsReady() and (SoulShards > 2 and (VilefiendActive() or not S.SummonVilefiend:IsAvailable() and DreadstalkerActive()) and (SoulShards > 2 or VilefiendTime() < GCDMax * 2 + 2 / Player:SpellHaste())) then
    if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan tyrant 24"; end
  end
  -- demonbolt,cycle_targets=1,if=soul_shard<4&(buff.demonic_core.stack>1)&(buff.vilefiend.up|!talent.summon_vilefiend&buff.dreadstalkers.up)
  if S.Demonbolt:IsReady() and (SoulShards < 4 and (Player:BuffStack(S.DemonicCoreBuff) > 1) and (VilefiendActive() or not S.SummonVilefiend:IsAvailable() and DreadstalkerActive())) then
    if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt tyrant 26"; end
  end
  -- power_siphon,if=buff.demonic_core.stack<3&variable.pet_expire>action.summon_demonic_tyrant.execute_time+gcd.max*3|variable.pet_expire=0
  if S.PowerSiphon:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) < 3 and VarPetExpire > S.SummonDemonicTyrant:ExecuteTime() + GCDMax * 3 or VarPetExpire == 0) then
    if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon tyrant 28"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsCastable() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt tyrant 30"; end
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

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Update Demonology-specific Tables
    Warlock.UpdatePetTable()
    Warlock.UpdateSoulShards()

    -- Update CombatTime, which is used in many spell suggestions
    CombatTime = HL.CombatTime()

    -- Calculate Soul Shards
    SoulShards = Player:SoulShardsP()

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
    -- call_action_list,name=racials,if=pet.demonic_tyrant.active|fight_remains<22,use_off_gcd=1
    if DemonicTyrantActive() or FightRemains < 22 then
      local ShouldReturn = Racials(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items,use_off_gcd=1
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- invoke_external_buff,name=power_infusion,if=(buff.nether_portal.up&buff.nether_portal.remains<3&talent.nether_portal)|fight_remains<20|pet.demonic_tyrant.active&fight_remains<100|fight_remains<25|(pet.demonic_tyrant.active|!talent.summon_demonic_tyrant&buff.dreadstalkers.up)
    -- Note: Not handling external buffs
    -- call_action_list,name=fight_end,if=fight_remains<30
    if FightRemains < 30 then
      local ShouldReturn = FightEnd(); if ShouldReturn then return ShouldReturn; end
    end
    -- hand_of_guldan,if=time<0.5&(fight_remains%%95>40|fight_remains%%95<15)&(talent.reign_of_tyranny|active_enemies>2)
    if S.HandofGuldan:IsReady() and (CombatTime < 0.5 and (FightRemains % 95 > 40 or FightRemains % 95 < 15) and (S.ReignofTyranny:IsAvailable() or EnemiesCount8ySplash > 2)) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 2"; end
    end
    -- call_action_list,name=tyrant,if=cooldown.summon_demonic_tyrant.remains<15&cooldown.summon_vilefiend.remains<gcd.max*5&cooldown.call_dreadstalkers.remains<gcd.max*5&(cooldown.grimoire_felguard.remains<10|!set_bonus.tier30_2pc)&(variable.tyrant_cd<15|fight_remains<40|buff.power_infusion.up)&(!raid_event.adds.in<15-raid_event.add.duration)|talent.summon_vilefiend.enabled&cooldown.summon_demonic_tyrant.remains<15&cooldown.summon_vilefiend.remains<gcd.max*5&cooldown.call_dreadstalkers.remains<gcd.max*5&(cooldown.grimoire_felguard.remains<10|!set_bonus.tier30_2pc)&(!variable.shadow_timings|variable.tyrant_cd<15|fight_remains<40|buff.power_infusion.up)
    if (S.SummonDemonicTyrant:CooldownRemains() < 15 and S.SummonVilefiend:CooldownRemains() < GCDMax * 5 and S.CallDreadstalkers:CooldownRemains() < GCDMax * 5 and (S.GrimoireFelguard:CooldownRemains() < 10 or not Player:HasTier(30, 2)) and (VarTyrantCD < 15 or FightRemains < 40 or Player:PowerInfusionUp()) or S.SummonVilefiend:IsAvailable() and S.SummonDemonicTyrant:CooldownRemains() < 15 and S.SummonVilefiend:CooldownRemains() < GCDMax * 5 and S.CallDreadstalkers:CooldownRemains() < GCDMax * 5 and (S.GrimoireFelguard:CooldownRemains() < 10 or not Player:HasTier(30, 2)) and (not VarShadowTimings or VarTyrantCD < 15 or FightRemains < 40 or Player:PowerInfusionUp())) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=tyrant,if=cooldown.summon_demonic_tyrant.remains<15&(buff.vilefiend.up|!talent.summon_vilefiend&(buff.grimoire_felguard.up|cooldown.grimoire_felguard.up|!set_bonus.tier30_2pc))&(variable.tyrant_cd<15|buff.grimoire_felguard.up|fight_remains<40|buff.power_infusion.up)
    if (S.SummonDemonicTyrant:CooldownRemains() < 15 and (VilefiendActive() or not S.SummonVilefiend:IsAvailable() and (GrimoireFelguardActive() or S.GrimoireFelguard:CooldownUp() or not Player:HasTier(30, 2))) and (VarTyrantCD < 15 or GrimoireFelguardActive() or FightRemains < 40 or Player:PowerInfusionUp())) then
      local ShouldReturn = Tyrant(); if ShouldReturn then return ShouldReturn; end
    end
    -- summon_demonic_tyrant,if=buff.vilefiend.up|buff.grimoire_felguard.up|cooldown.grimoire_felguard.remains>90
    if S.SummonDemonicTyrant:IsCastable() and (VilefiendActive() or GrimoireFelguardActive() or S.GrimoireFelguard:CooldownRemains() > 90) then
      if Cast(S.SummonDemonicTyrant, Settings.Demonology.GCDasOffGCD.SummonDemonicTyrant) then return "summon_demonic_tyrant main 4"; end
    end
    -- summon_vilefiend,if=cooldown.summon_demonic_tyrant.remains>45
    if S.SummonVilefiend:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 45) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 6"; end
    end
    -- demonbolt,target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3),if=buff.demonic_core.up&(((!talent.soul_strike|cooldown.soul_strike.remains>gcd.max*2)&soul_shard<4)|soul_shard<(4-(active_enemies>2)))&!prev_gcd.1.demonbolt&set_bonus.tier31_2pc
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and (((not S.SoulStrike:IsAvailable() or S.SoulStrike:CooldownRemains() > GCDMax * 2) and SoulShards < 4) or SoulShards < (4 - (num(EnemiesCount8ySplash > 2)))) and not Player:PrevGCDP(1, S.Demonbolt) and Player:HasTier(31, 2)) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 8"; end
    end
    -- power_siphon,if=!buff.demonic_core.up&(!debuff.doom_brand.up|(!action.hand_of_guldan.in_flight&debuff.doom_brand.remains<gcd.max+action.demonbolt.travel_time)|(action.hand_of_guldan.in_flight&debuff.doom_brand.remains<gcd.max+action.demonbolt.travel_time+3))&set_bonus.tier31_2pc
    if S.PowerSiphon:IsReady() and (Player:BuffDown(S.DemonicCoreBuff) and (Target:DebuffDown(S.DoomBrandDebuff) or (not S.HandofGuldan:InFlight() and Target:DebuffRemains(S.DoomBrandDebuff) < GCDMax + S.Demonbolt:TravelTime()) or (S.HandofGuldan:InFlight() and Target:DebuffRemains(S.DoomBrandDebuff) < GCDMax + S.Demonbolt:TravelTime() + 3)) and Player:HasTier(31, 2)) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 10"; end
    end
    -- demonic_strength,if=buff.nether_portal.remains<gcd.max&(fight_remains>63&!(fight_remains>cooldown.summon_demonic_tyrant.remains+69)|cooldown.summon_demonic_tyrant.remains>30|1|buff.rite_of_ruvaraad.up|!talent.summon_demonic_tyrant|!talent.grimoire_felguard|!set_bonus.tier30_2pc)
    if S.DemonicStrength:IsCastable() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax and (FightRemains > 63 and not (FightRemains > S.SummonDemonicTyrant:CooldownRemains() + 69) or S.SummonDemonicTyrant:CooldownRemains() > 30 or Player:BuffUp(S.RiteofRuvaraadBuff) or not S.SummonDemonicTyrant:IsAvailable() or not S.GrimoireFelguard:IsAvailable() or not Player:HasTier(30, 2))) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 12"; end
    end
    -- bilescourge_bombers
    if S.BilescourgeBombers:IsReady() then
      if Cast(S.BilescourgeBombers, nil, nil, not Target:IsInRange(40)) then return "bilescourge_bombers main 14"; end
    end
    -- guillotine,if=buff.nether_portal.remains<gcd.max&(cooldown.demonic_strength.remains|!talent.demonic_strength)
    if S.Guillotine:IsCastable() and (Player:BuffRemains(S.NetherPortalBuff) < GCDMax and (S.DemonicStrength:CooldownDown() or not S.DemonicStrength:IsAvailable())) then
      if Cast(S.Guillotine, nil, nil, not Target:IsInRange(40)) then return "guillotine main 16"; end
    end
    -- call_dreadstalkers,if=cooldown.summon_demonic_tyrant.remains>25|variable.tyrant_cd>25|buff.nether_portal.up
    if S.CallDreadstalkers:IsReady() and (S.SummonDemonicTyrant:CooldownRemains() > 25 or VarTyrantCD > 25 or Player:BuffUp(S.NetherPortalBuff)) then
      if Cast(S.CallDreadstalkers, nil, nil, not Target:IsSpellInRange(S.CallDreadstalkers)) then return "call_dreadstalkers main 18"; end
    end
    -- implosion,if=two_cast_imps>0&variable.impl&!prev_gcd.1.implosion
    if S.Implosion:IsReady() and (CheckImpCasts(2) > 0 and VarImpl and not Player:PrevGCDP(1, S.Implosion)) then
      if Cast(S.Implosion, Settings.Demonology.GCDasOffGCD.Implosion, nil, not Target:IsInRange(40)) then return "implosion main 20"; end
    end
    -- summon_soulkeeper,if=buff.tormented_soul.stack=10&active_enemies>1
    if S.SummonSoulkeeper:IsReady() and (S.SummonSoulkeeper:Count() == 10 and EnemiesCount8ySplash > 1) then
      if Cast(S.SummonSoulkeeper) then return "soul_strike main 22"; end
    end
    -- demonic_strength,if=(fight_remains>63&!(fight_remains>cooldown.summon_demonic_tyrant.remains+69)|cooldown.summon_demonic_tyrant.remains>30|buff.rite_of_ruvaraad.up|1|!talent.summon_demonic_tyrant|!talent.grimoire_felguard|!set_bonus.tier30_2pc)
    if S.DemonicStrength:IsCastable() and (FightRemains > 63 and not (FightRemains > S.SummonDemonicTyrant:CooldownRemains() + 69) or S.SummonDemonicTyrant:CooldownRemains() > 30 or Player:BuffUp(S.RiteofRuvaraadBuff) or not S.SummonDemonicTyrant:IsAvailable() or not S.GrimoireFelguard:IsAvailable() or not Player:HasTier(30, 2)) then
      if Cast(S.DemonicStrength, Settings.Demonology.GCDasOffGCD.DemonicStrength) then return "demonic_strength main 24"; end
    end
    -- hand_of_guldan,if=((soul_shard>2&cooldown.call_dreadstalkers.remains>gcd.max*4&cooldown.summon_demonic_tyrant.remains>17)|soul_shard=5|soul_shard=4&talent.soul_strike&cooldown.soul_strike.remains<gcd.max*2)&(active_enemies=1&talent.grand_warlocks_design)
    if S.HandofGuldan:IsReady() and (((SoulShards > 2 and S.CallDreadstalkers:CooldownRemains() > GCDMax * 4 and S.SummonDemonicTyrant:CooldownRemains() > 17) or SoulShards == 5 or SoulShards == 4 and S.SoulStrike:IsAvailable() and S.SoulStrike:CooldownRemains() < GCDMax * 2) and (EnemiesCount8ySplash == 1 and S.GrandWarlocksDesign:IsAvailable())) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 26"; end
    end
    -- hand_of_guldan,if=soul_shard>2&!(active_enemies=1&talent.grand_warlocks_design)
    if S.HandofGuldan:IsReady() and (SoulShards > 2 and not (EnemiesCount8ySplash == 1 and S.GrandWarlocksDesign:IsAvailable())) then
      if Cast(S.HandofGuldan, nil, nil, not Target:IsSpellInRange(S.HandofGuldan)) then return "hand_of_guldan main 28"; end
    end
    -- demonbolt,target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3)|active_enemies<4,if=buff.demonic_core.stack>1&((soul_shard<4&!talent.soul_strike|cooldown.soul_strike.remains>gcd.max*2)|soul_shard<3)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (Player:BuffStack(S.DemonicCoreBuff) > 1 and ((SoulShards < 4 and not S.SoulStrike:IsAvailable() or S.SoulStrike:CooldownRemains() > GCDMax * 2) or SoulShards < 2) and not VarPoolCoresForTyrant) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt2, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 30"; end
    end
    -- demonbolt,target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3)|active_enemies<4,if=set_bonus.tier31_2pc&(debuff.doom_brand.remains>10&buff.demonic_core.up&soul_shard<4)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (Player:HasTier(31, 2) and Player:BuffUp(S.DemonicCoreBuff) and SoulShards < 4 and not VarPoolCoresForTyrant) then
      if Everyone.CastTargetIf(S.Demonbolt, Enemies8ySplash, "==", EvaluateCycleDemonbolt2, EvaluateTargetIfDemonbolt, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 32"; end
    end
    -- demonbolt,if=fight_remains<buff.demonic_core.stack*gcd.max
    if S.Demonbolt:IsReady() and (FightRemains < Player:BuffStack(S.DemonicCoreBuff) * GCDMax) then
      if Cast(S.Demonbolt, nil, nil, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 34"; end
    end
    -- demonbolt,target_if=(!debuff.doom_brand.up|action.hand_of_guldan.in_flight&debuff.doom_brand.remains<=3)|active_enemies<4,if=buff.demonic_core.up&(cooldown.power_siphon.remains<4)&(soul_shard<4)&!variable.pool_cores_for_tyrant
    if S.Demonbolt:IsReady() and (Player:BuffUp(S.DemonicCoreBuff) and S.PowerSiphon:CooldownRemains() < 4 and SoulShards < 4 and not VarPoolCoresForTyrant) then
      if Everyone.CastCycle(S.Demonbolt, Enemies8ySplash, EvaluateCycleDemonbolt2, not Target:IsSpellInRange(S.Demonbolt)) then return "demonbolt main 36"; end
    end
    -- power_siphon,if=!buff.demonic_core.up
    if S.PowerSiphon:IsReady() and (Player:BuffDown(S.DemonicCoreBuff)) then
      if Cast(S.PowerSiphon, Settings.Demonology.GCDasOffGCD.PowerSiphon) then return "power_siphon main 38"; end
    end
    -- summon_vilefiend,if=fight_remains<cooldown.summon_demonic_tyrant.remains+5
    if S.SummonVilefiend:IsReady() and (FightRemains < S.SummonDemonicTyrant:CooldownRemains() + 5) then
      if Cast(S.SummonVilefiend) then return "summon_vilefiend main 40"; end
    end
    -- doom,target_if=refreshable
    if S.Doom:IsReady() then
      if Everyone.CastCycle(S.Doom, Enemies40y, EvaluateCycleDoom, not Target:IsSpellInRange(S.Doom)) then return "doom main 42"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 44"; end
    end
  end
end

local function Init()
  HR.Print("Demonology Warlock rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(266, APL, Init)
