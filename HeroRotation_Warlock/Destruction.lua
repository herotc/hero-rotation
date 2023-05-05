--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Utils         = HL.Utils
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua
local max           = math.max

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Destruction = HR.GUISettings.APL.Warlock.Destruction
}

-- Spells
local S = Spell.Warlock.Destruction

-- Items
local I = Item.Warlock.Destruction
local TrinketsOnUseExcludes = {
  I.ConjuredChillglobe:ID(),
  I.DesperateInvokersCodex:ID(),
  I.EruptingSpearFragment:ID(),
  I.IcebloodDeathsnare:ID(),
}

-- Enemies
local Enemies40y, EnemiesCount8ySplash

-- Rotation Variables
local GCDMax = Player:GCD()
local VarPoolSoulShards = false
local VarCleaveAPL = false
local VarHavocActive = false
local VarHavocRemains = 0
local VarHavocImmoTime = 0
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  GCDMax = Player:GCD()
  VarPoolSoulShards = false
  VarCleaveAPL = false
  VarHavocActive = false
  VarHavocRemains = 0
  VarHavocImmoTime = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

S.SummonInfernal:RegisterInFlight()
S.ChaosBolt:RegisterInFlight()
S.Incinerate:RegisterInFlight()

local function UnitWithHavoc(enemies)
  for k in pairs(enemies) do
    local CycleUnit = enemies[k]
    if CycleUnit:DebuffUp(S.Havoc) then
      return true, CycleUnit:DebuffRemains(S.HavocDebuff), CycleUnit:DebuffRemains(S.ImmolateDebuff)
    end
  end
  return false, 0, 0
end

local function InfernalTime()
  return HL.GuardiansTable.InfernalDuration or (S.SummonInfernal:InFlight() and 30) or 0
end

local function BlasphemyTime()
  return HL.GuardiansTable.BlasphemyDuration or 0
end

-- CastTargetIf/CastCycle functions
local function EvaluateTargetIfFilterHavoc(TargetUnit)
  -- target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target)
  return (max(TargetUnit:TimeToDie() * -1, -15) + TargetUnit:DebuffRemains(S.ImmolateDebuff) + 99 * num(TargetUnit:GUID() == Target:GUID()))
end

local function EvaluateTargetIfHavoc(TargetUnit)
  -- if=(!cooldown.summon_infernal.up|!talent.summon_infernal)&target.time_to_die>8
  -- if=(!cooldown.summon_infernal.up|!talent.summon_infernal|(talent.inferno&active_enemies>4))&target.time_to_die>8
  -- Note: For both lines, all but time_to_die is handled before CastTargetIf
  return (TargetUnit:TimeToDie() > 8)
end

local function EvaluateTargetIfFilterImmolate(TargetUnit)
  -- target_if=min:dot.immolate.remains+99*debuff.havoc.remains
  return (TargetUnit:DebuffRemains(S.ImmolateDebuff) + 99 * TargetUnit:DebuffRemains(S.HavocDebuff))
end

local function EvaluateTargetIfImmolateAoE(TargetUnit)
  -- if=dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains)&active_dot.immolate<=4&target.time_to_die>18
  -- Note: active_dot.immolate handled before CastCycle
  return (TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and (not S.RagingDemonfire:IsAvailable() or S.ChannelDemonfire:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and TargetUnit:TimeToDie() > 18)
end

local function EvaluateTargetIfImmolateAoE2(TargetUnit)
  -- if=((dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains))|active_enemies>active_dot.immolate)&target.time_to_die>10&!havoc_active
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff))) or EnemiesCount8ySplash > S.ImmolateDebuff:AuraActiveCount()) and TargetUnit:TimeToDie() > 10 and not VarHavocActive)
end

local function EvaluateTargetIfImmolateAoE3(TargetUnit)
  -- if=((dot.immolate.refreshable&variable.havoc_immo_time<5.4)|(dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|(variable.havoc_immo_time<2)*havoc_active)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&target.time_to_die>11
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and VarHavocImmoTime < 5.4) or (TargetUnit:DebuffRemains(S.ImmolateDebuff) < 2 and TargetUnit:DebuffRemains(S.ImmolateDebuff) < VarHavocRemains) or TargetUnit:DebuffDown(S.ImmolateDebuff) or bool(num(VarHavocImmoTime < 2) * num(VarHavocActive))) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and TargetUnit:TimeToDie() > 11)
end

local function EvaluateTargetIfImmolateCleave(TargetUnit)
  -- if=(dot.immolate.refreshable&(dot.immolate.remains<cooldown.havoc.remains|!dot.immolate.ticking))&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains+(!talent.mayhem*action.soul_fire.cast_time)>dot.immolate.remains)&target.time_to_die>15
  return ((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (TargetUnit:DebuffRemains(S.ImmolateDebuff) < S.Havoc:CooldownRemains() or TargetUnit:DebuffDown(S.ImmolateDebuff))) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and ((not S.SoulFire:IsAvailable()) or S.SoulFire:CooldownRemains() + (num(not S.Mayhem:IsAvailable()) * S.SoulFire:CastTime()) > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and TargetUnit:TimeToDie() > 15)
end

local function EvaluateTargetIfImmolateHavoc(TargetUnit)
  -- if=(((dot.immolate.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  -- Note: Soul Shard check handled before CastTargetIf call.
  return (((TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and VarHavocImmoTime < 5.4) and TargetUnit:TimeToDie() > 5) or ((TargetUnit:DebuffRemains(S.ImmolateDebuff) < 2 and TargetUnit:DebuffRemains(S.ImmolateDebuff) < VarHavocRemains) or TargetUnit:DebuffDown(S.ImmolateDebuff) or VarHavocImmoTime < 2) and TargetUnit:TimeToDie() > 11)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  -- Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  VarCleaveAPL = false
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsReady() then
    if Cast(S.GrimoireofSacrifice, Settings.Destruction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- soul_fire
  if S.SoulFire:IsReady() and (not Player:IsCasting(S.SoulFire)) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire precombat 4"; end
  end
  -- cataclysm,if=raid_event.adds.in>15
  if S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm precombat 6"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() and (not Player:IsCasting(S.Incinerate)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate precombat 8"; end
  end
end

local function Items()
  -- use_items,if=pet.infernal.active|!talent.summon_infernal|time_to_die<21
  if (InfernalTime() > 0 or (not S.SummonInfernal:IsAvailable()) or FightRemains < 21) then
    local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  --TODO manage trinkets
  --use_item,slot=trinket1,if=pet.infernal.active|!talent.summon_infernal|fight_remains<21|trinket.1.cooldown.duration<cooldown.summon_infernal.remains+5
  --use_item,slot=trinket2,if=pet.infernal.active|!talent.summon_infernal|fight_remains<21|trinket.2.cooldown.duration<cooldown.summon_infernal.remains+5
  --use_item,slot=trinket1,if=(!talent.rain_of_chaos&fight_remains<cooldown.summon_infernal.remains+trinket.1.cooldown.duration&fight_remains>trinket.1.cooldown.duration)|fight_remains<cooldown.summon_infernal.remains|(trinket.2.cooldown.remains>0&trinket.2.cooldown.remains<cooldown.summon_infernal.remains)
  --use_item,slot=trinket2,if=(!talent.rain_of_chaos&fight_remains<cooldown.summon_infernal.remains+trinket.2.cooldown.duration&fight_remains>trinket.2.cooldown.duration)|fight_remains<cooldown.summon_infernal.remains|(trinket.1.cooldown.remains>0&trinket.1.cooldown.remains<cooldown.summon_infernal.remains)
  --use_item,name=erupting_spear_fragment,if=(!talent.rain_of_chaos&fight_remains<cooldown.summon_infernal.remains+trinket.erupting_spear_fragment.cooldown.duration&fight_remains>trinket.erupting_spear_fragment.cooldown.duration)|fight_remains<cooldown.summon_infernal.remains|trinket.erupting_spear_fragment.cooldown.duration<cooldown.summon_infernal.remains+5
  if I.EruptingSpearFragment:IsEquippedAndReady() and (((not S.RainofChaos:IsAvailable()) and FightRemains < S.SummonInfernal:CooldownRemains() + 90 and FightRemains > 90) or FightRemains < S.SummonInfernal:CooldownRemains() or 90 < S.SummonInfernal:CooldownRemains() + 5) then
    if Cast(I.EruptingSpearFragment, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment items 2"; end
  end
  --use_item,name=desperate_invokers_codex
  if I.DesperateInvokersCodex:IsEquippedAndReady() then
    if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "desperate_invokers_codex items 4"; end
  end
  --use_item,name=iceblood_deathsnare
  if I.IcebloodDeathsnare:IsEquippedAndReady() then
    if Cast(I.IcebloodDeathsnare, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "iceblood_deathsnare items 6"; end
  end
  --use_item,name=conjured_chillglobe
  if I.ConjuredChillglobe:IsEquippedAndReady() then
    if Cast(I.ConjuredChillglobe, nil, Settings.Commons.DisplayStyle.Trinkets) then return "conjured_chillglobe items 8"; end
  end
end

local function oGCD()
  if InfernalTime() > 0 or not S.SummonInfernal:IsAvailable() then
    -- potion,if=pet.infernal.active|!talent.summon_infernal
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 2"; end
      end
    end
    -- berserking,if=pet.infernal.active|!talent.summon_infernal|(fight_remains<(cooldown.summon_infernal.remains+cooldown.berserking.duration)&(fight_remains>cooldown.berserking.duration))|fight_remains<cooldown.summon_infernal.remains
    if S.Berserking:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 12) and (FightRemains > 12) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 4"; end
    end
    -- blood_fury,if=pet.infernal.active|!talent.summon_infernal|(fight_remains<cooldown.summon_infernal.remains+10+cooldown.blood_fury.duration&fight_remains>cooldown.blood_fury.duration)|fight_remains<cooldown.summon_infernal.remains
    if S.BloodFury:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 15) and (FightRemains > 15) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 6"; end
    end
    -- fireblood,if=pet.infernal.active|!talent.summon_infernal|(fight_remains<cooldown.summon_infernal.remains+10+cooldown.fireblood.duration&fight_remains>cooldown.fireblood.duration)|fight_remains<cooldown.summon_infernal.remains
    if S.Fireblood:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 8) and (FightRemains > 8) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
    end
  end
end

local function Havoc()
  -- conflagrate,if=talent.backdraft&buff.backdraft.down&soul_shard>=1&soul_shard<=4
  if S.Conflagrate:IsCastable() and (S.Backdraft:IsAvailable() and Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1 and Player:SoulShardsP() <= 4) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 2"; end
  end
  -- soul_fire,if=cast_time<havoc_remains&soul_shard<2.5
  if S.SoulFire:IsCastable() and (S.SoulFire:CastTime() < VarHavocRemains and Player:SoulShardsP() < 2.5) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire havoc 4"; end
  end
  -- channel_demonfire,if=soul_shard<4.5&talent.raging_demonfire.rank=2&active_enemies>2
  if S.ChannelDemonfire:IsCastable() and (Player:SoulShardsP() < 4.5 and S.RagingDemonfire:TalentRank() == 2 and EnemiesCount8ySplash > 2) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire havoc 6"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+100*debuff.havoc.remains,if=(((dot.immolate.refreshable&variable.havoc_immo_time<5.4)&target.time_to_die>5)|((dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|variable.havoc_immo_time<2)&target.time_to_die>11)&soul_shard<4.5
  if S.Immolate:IsCastable() and (Player:SoulShardsP() < 4.5) then
    if Everyone.CastTargetIf(S.Immolate, Enemies40y, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateHavoc, not Target:IsSpellInRange(S.Immolate)) then return "immolate havoc 8"; end
  end
  -- chaos_bolt,if=((talent.cry_havoc&!talent.inferno)|!talent.rain_of_fire)&cast_time<havoc_remains
  if S.ChaosBolt:IsReady() and (((S.CryHavoc:IsAvailable() and (not S.Inferno:IsAvailable())) or not S.RainofFire:IsAvailable()) and S.ChaosBolt:CastTime() < VarHavocRemains) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt havoc 10"; end
  end
  -- chaos_bolt,if=cast_time<havoc_remains&(active_enemies<=3-talent.inferno+(talent.madness_of_the_azjaqir&!talent.inferno))
  if S.ChaosBolt:IsReady() and (S.ChaosBolt:CastTime() < VarHavocRemains and (EnemiesCount8ySplash <= 3 - num(S.Inferno:IsAvailable()) + num(S.MadnessoftheAzjAqir:IsAvailable() and not S.Inferno:IsAvailable()))) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt havoc 12"; end
  end
  -- rain_of_fire,if=active_enemies>=3&talent.inferno
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash >= 3 and S.Inferno:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 14"; end
  end
  -- rain_of_fire,if=(active_enemies>=4-talent.inferno+talent.madness_of_the_azjaqir)
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash >= 4 - num(S.Inferno:IsAvailable()) + num(S.MadnessoftheAzjAqir:IsAvailable())) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 16"; end
  end
  -- rain_of_fire,if=active_enemies>2&(talent.avatar_of_destruction|(talent.rain_of_chaos&buff.rain_of_chaos.up))&talent.inferno.enabled
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash > 2 and (S.AvatarofDestruction:IsAvailable() or (S.RainofChaos:IsAvailable() and Player:BuffUp(S.RainofChaosBuff))) and S.Inferno:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 18"; end
  end
  -- conflagrate,if=!talent.backdraft
  if S.Conflagrate:IsCastable() and not S.Backdraft:IsAvailable() then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 20"; end
  end
  -- incinerate,if=cast_time<havoc_remains
  if S.Incinerate:IsCastable() and (S.Incinerate:CastTime() < VarHavocRemains) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate havoc 22"; end
  end
end

local function Cleave()
  -- call_action_list,name=items
  if CDsON() and Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd.max
  if (VarHavocActive and VarHavocRemains > GCDMax) then
    local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
  end
  -- variable,name=pool_soul_shards,value=cooldown.havoc.remains<=10|talent.mayhem
  VarPoolSoulShards = (S.Havoc:CooldownRemains() <= 10 or S.Mayhem:IsAvailable())
  -- conflagrate,if=(talent.roaring_blaze.enabled&debuff.conflagrate.remains<1.5)|charges=max_charges
  if S.Conflagrate:IsCastable() and ((S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.RoaringBlazeDebuff) < 1.5) or S.Conflagrate:Charges() == S.Conflagrate:MaxCharges()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 2"; end
  end
  -- dimensional_rift,if=soul_shard<4.7&(charges>2|time_to_die<cooldown.dimensional_rift.duration)
  if CDsON() and S.DimensionalRift:IsCastable() and (Player:SoulShardsP() < 4.7 and (S.DimensionalRift:Charges() > 2 or FightRemains < S.DimensionalRift:Cooldown())) then
    if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift cleave 4"; end
  end
  -- cataclysm,if=raid_event.adds.in>15
  if CDsON() and S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsSpellInRange(S.Cataclysm)) then return "cataclysm cleave 6"; end
  end
  -- channel_demonfire,if=talent.raging_demonfire
  if S.ChannelDemonfire:IsCastable() and (S.RagingDemonfire:IsAvailable()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 8"; end
  end
  -- soul_fire,if=soul_shard<=3.5&(debuff.conflagrate.remains>cast_time+travel_time|!talent.roaring_blaze&buff.backdraft.up)&!variable.pool_soul_shards
  if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 3.5 and (Target:DebuffRemains(S.RoaringBlazeDebuff) > S.SoulFire:CastTime() + S.SoulFire:TravelTime() or (not S.RoaringBlaze:IsAvailable()) and Player:BuffUp(S.BackdraftBuff)) and not VarPoolSoulShards) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 10"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=(dot.immolate.refreshable&(dot.immolate.remains<cooldown.havoc.remains|!dot.immolate.ticking))&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains+(!talent.mayhem*action.soul_fire.cast_time)>dot.immolate.remains)&target.time_to_die>15
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies40y, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateCleave, not Target:IsSpellInRange(S.Immolate)) then return "immolate cleave 12"; end
  end
  -- havoc,target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target),if=(!cooldown.summon_infernal.up|!talent.summon_infernal)&target.time_to_die>8
  if S.Havoc:IsCastable() and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable()) then
    --if Everyone.CastTargetIf(S.Havoc, Enemies40y, "min", EvaluateTargetIfFilterHavoc, EvaluateTargetIfHavoc, not Target:IsSpellInRange(S.Havoc)) then return "havoc cleave 14"; end
    local BestUnit, BestConditionValue, CUCV = nil, nil
    for _, CycleUnit in pairs(Enemies40y) do
      if CycleUnit:GUID() ~= Target:GUID() then
        if BestConditionValue then
          CUCV = EvaluateTargetIfFilterHavoc(CycleUnit)
        end
        if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
          and ((not BestConditionValue) or Utils.CompareThis("min", CUCV, BestConditionValue)) then
          BestUnit, BestConditionValue = CycleUnit, CUCV
        end
      end
    end
    if BestUnit and EvaluateTargetIfHavoc(BestUnit) then
      HR.CastLeftNameplate(BestUnit, S.Havoc)
    end
  end
  -- chaos_bolt,if=pet.infernal.active|pet.blasphemy.active|soul_shard>=4
  if S.ChaosBolt:IsReady() and (InfernalTime() > 0 or BlasphemyTime() > 0 or Player:SoulShardsP() >= 4) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 16"; end
  end
  -- summon_infernal
  if CDsON() and S.SummonInfernal:IsCastable() then
    if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal cleave 18"; end
  end
  -- channel_demonfire,if=talent.ruin.rank>1&!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))
  if S.ChannelDemonfire:IsCastable() and (S.Ruin:TalentRank() > 1 and (not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable())))) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 20"; end
  end
  -- conflagrate,if=buff.backdraft.down&soul_shard>=1.5&!variable.pool_soul_shards
  if S.Conflagrate:IsCastable() and (Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1.5 and not VarPoolSoulShards) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 22"; end
  end
  -- incinerate,if=cast_time+action.chaos_bolt.cast_time<buff.madness_cb.remains
  if S.Incinerate:IsCastable() and (S.Incinerate:CastTime() + S.ChaosBolt:CastTime() < Player:BuffRemains(S.MadnessCBBuff)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 24"; end
  end
  -- chaos_bolt,if=buff.rain_of_chaos.remains>cast_time
  if S.ChaosBolt:IsReady() and (Player:BuffRemains(S.RainofChaosBuff) > S.ChaosBolt:CastTime()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 26"; end
  end
  -- chaos_bolt,if=buff.backdraft.up&!variable.pool_soul_shards
  if S.ChaosBolt:IsReady() and (Player:BuffUp(S.BackdraftBuff) and not VarPoolSoulShards) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 28"; end
  end
  -- chaos_bolt,if=talent.eradication&!variable.pool_soul_shards&debuff.eradication.remains<cast_time&!action.chaos_bolt.in_flight
  if S.ChaosBolt:IsReady() and (S.Eradication:IsAvailable() and (not VarPoolSoulShards) and Target:DebuffRemains(S.EradicationDebuff) < S.ChaosBolt:CastTime() and not S.ChaosBolt:InFlight()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 30"; end
  end
  -- chaos_bolt,if=buff.madness_cb.up&(!variable.pool_soul_shards|(talent.burn_to_ashes&buff.burn_to_ashes.stack=0)|talent.soul_fire)
  if S.ChaosBolt:IsReady() and (Player:BuffUp(S.MadnessCBBuff) and ((not VarPoolSoulShards) or (S.BurntoAshes:IsAvailable() and Player:BuffStack(S.BurntoAshesBuff) == 0) or S.SoulFire:IsAvailable())) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 32"; end
  end
  -- soul_fire,if=soul_shard<=4&talent.mayhem
  if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 4 and S.Mayhem:IsAvailable()) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 34"; end
  end
  -- channel_demonfire,if=!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))
  if S.ChannelDemonfire:IsCastable() and (not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable()))) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 36"; end
  end
  -- dimensional_rift
  if CDsON() and S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift cleave 38"; end
  end
  -- chaos_bolt,if=soul_shard>3.5&!variable.pool_soul_shards
  if S.ChaosBolt:IsReady() and (Player:SoulShardsP() > 3.5 and not VarPoolSoulShards) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 40"; end
  end
  -- chaos_bolt,if=!variable.pool_soul_shards&(talent.soul_conduit&!talent.madness_of_the_azjaqir|!talent.backdraft)
  if S.ChaosBolt:IsReady() and ((not VarPoolSoulShards) and (S.SoulConduit:IsAvailable() and (not S.MadnessoftheAzjAqir:IsAvailable()) or not S.Backdraft:IsAvailable())) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 42"; end
  end
  -- chaos_bolt,if=fight_remains<5&time_to_die>cast_time+travel_time
  -- Note: Added a buffer of 0.25s
  if S.ChaosBolt:IsReady() and (FightRemains < 5.25 and Target:TimeToDie() > S.ChaosBolt:CastTime() + S.ChaosBolt:TravelTime() + 0.25) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 44"; end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10|buff.tormented_soul.stack>3&fight_remains<10
  if S.SummonSoulkeeper:IsCastable() and (S.SummonSoulkeeper:Count() == 10 or S.SummonSoulkeeper:Count() > 3 and FightRemains < 10) then
    if Cast(S.SummonSoulkeeper, Settings.Destruction.GCDasOffGCD.SummonSoulkeeper) then return "summon_soulkeeper cleave 46"; end
  end
  -- conflagrate,if=charges>(max_charges-1)|time_to_die<gcd.max*charges
  if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < GCDMax * S.Conflagrate:Charges()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 48"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 50"; end
  end
end

local function Aoe()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if CDsON() and Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd.max&active_enemies<5+(talent.cry_havoc&!talent.inferno)&(!cooldown.summon_infernal.up|!talent.summon_infernal)
  if (VarHavocActive and VarHavocRemains > GCDMax and EnemiesCount8ySplash < 5 + num(S.CryHavoc:IsAvailable() and not S.Inferno:IsAvailable()) and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable())) then
    local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
  end
  -- rain_of_fire,if=pet.infernal.active|pet.blasphemy.active
  if S.RainofFire:IsReady() and (InfernalTime() > 0 or BlasphemyTime() > 0) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 2"; end
  end
  -- rain_of_fire,if=fight_remains<12
  if S.RainofFire:IsReady() and (FightRemains < 12) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 4"; end
  end
  -- rain_of_fire,if=gcd.max>buff.madness_rof.remains&buff.madness_rof.up
  if S.RainofFire:IsReady() and (GCDMax > Player:BuffRemains(S.MadnessRoFBuff) and Player:BuffUp(S.MadnessRoFBuff)) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 6"; end
  end
  -- rain_of_fire,if=soul_shard>=(4.5-0.1*active_dot.immolate)&time>5
  if S.RainofFire:IsReady() and (Player:SoulShardsP() >= (4.5 - 0.1 * S.ImmolateDebuff:AuraActiveCount()) and HL.CombatTime() > 5) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 8"; end
  end
  -- chaos_bolt,if=soul_shard>3.5-(0.1*active_enemies)&!talent.rain_of_fire
  if S.ChaosBolt:IsReady() and (Player:SoulShardsP() > 3.5 - (0.1 * EnemiesCount8ySplash) and not S.RainofFire:IsAvailable()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt aoe 10"; end
  end
  -- cataclysm,if=raid_event.adds.in>15
  if CDsON() and S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsSpellInRange(S.Cataclysm)) then return "cataclysm aoe 12"; end
  end
  -- channel_demonfire,if=dot.immolate.remains>cast_time&talent.raging_demonfire
  if S.ChannelDemonfire:IsCastable() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime() and S.RagingDemonfire:IsAvailable()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire aoe 14"; end
  end
  -- havoc,target_if=min:((-target.time_to_die)<?-15)+dot.immolate.remains+99*(self.target=target),if=(!cooldown.summon_infernal.up|!talent.summon_infernal|(talent.inferno&active_enemies>4))&target.time_to_die>8
  if S.Havoc:IsReady() and (S.SummonInfernal:CooldownDown() or (not S.SummonInfernal:IsAvailable()) or (S.Inferno:IsAvailable() and EnemiesCount8ySplash > 4)) then
    if Everyone.CastTargetIf(S.Havoc, Enemies40y, "min", EvaluateTargetIfFilterHavoc, EvaluateTargetIfHavoc, not Target:IsSpellInRange(S.Havoc)) then return "havoc aoe 15"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains)&active_dot.immolate<=4&target.time_to_die>18
  if S.Immolate:IsCastable() and (S.ImmolateDebuff:AuraActiveCount() <= 4) then
    if Everyone.CastTargetIf(S.Immolate, Enemies40y, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 16"; end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10|buff.tormented_soul.stack>3&fight_remains<10
  if S.SummonSoulkeeper:IsCastable() and (S.SummonSoulkeeper:Count() == 10 or S.SummonSoulkeeper:Count() > 3 and FightRemains < 10) then
    if Cast(S.SummonSoulkeeper, Settings.Destruction.GCDasOffGCD.SummonSoulkeeper) then return "summon_soulkeeper aoe 18"; end
  end
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- summon_infernal
  if CDsON() and S.SummonInfernal:IsCastable() then
    if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal aoe 20"; end
  end
  -- rain_of_fire,if=debuff.pyrogenics.down&active_enemies<=4
  if S.RainofFire:IsReady() and (Target:DebuffDown(S.PyrogenicsDebuff) and EnemiesCount8ySplash <= 4) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 22"; end
  end
  -- channel_demonfire,if=dot.immolate.remains>cast_time
  if S.ChannelDemonfire:IsReady() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsSpellInRange(S.ChannelDemonfire)) then return "channel_demonfire aoe 24"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=((dot.immolate.refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains))|active_enemies>active_dot.immolate)&target.time_to_die>10&!havoc_active
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies40y, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE2, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 26"; end
  end
  -- immolate,target_if=min:dot.immolate.remains+99*debuff.havoc.remains,if=((dot.immolate.refreshable&variable.havoc_immo_time<5.4)|(dot.immolate.remains<2&dot.immolate.remains<havoc_remains)|!dot.immolate.ticking|(variable.havoc_immo_time<2)*havoc_active)&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&target.time_to_die>11
  if S.Immolate:IsCastable() then
    if Everyone.CastTargetIf(S.Immolate, Enemies40y, "min", EvaluateTargetIfFilterImmolate, EvaluateTargetIfImmolateAoE3, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 28"; end
  end
  -- soul_fire,if=buff.backdraft.up
  if S.SoulFire:IsCastable() and (Player:BuffUp(S.BackdraftBuff)) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire aoe 30"; end
  end
  -- incinerate,if=talent.fire_and_brimstone.enabled&buff.backdraft.up
  if S.Incinerate:IsCastable() and (S.FireandBrimstone:IsAvailable() and Player:BuffUp(S.BackdraftBuff)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 32"; end
  end
  -- conflagrate,if=buff.backdraft.stack<2|!talent.backdraft
  if S.Conflagrate:IsCastable() and (Player:BuffStack(S.BackdraftBuff) < 2 or not S.Backdraft:IsAvailable()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate aoe 34"; end
  end
  -- dimensional_rift
  if CDsON() and S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift aoe 36"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 38"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(12)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(12)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Define gcd.max (0.25 seconds to allow for latency and player reaction time)
    GCDMax = Player:GCD() + 0.25

    -- Check Havoc Status
    VarHavocActive, VarHavocRemains, VarHavocImmoTime = UnitWithHavoc(Enemies40y)

    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  -- Summon Pet
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Destruction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,name=havoc_immo_time,op=reset
    -- cycling_variable,name=havoc_immo_time,op=add,value=dot.immolate.remains*debuff.havoc.up
    -- Note: Above lines are to check how long Immolate remains on our Havoc target. This is included in UnitWithHavoc() now.
    -- call_action_list,name=aoe,if=(active_enemies>=3-(talent.inferno&!talent.madness_of_the_azjaqir))&!(!talent.inferno&talent.madness_of_the_azjaqir&talent.chaos_incarnate&active_enemies<4)&!variable.cleave_apl
    if ((EnemiesCount8ySplash >= 3 - (num(S.Inferno:IsAvailable() and not S.MadnessoftheAzjAqir:IsAvailable()))) and (not ((not S.Inferno:IsAvailable()) and S.MadnessoftheAzjAqir:IsAvailable() and S.ChaosIncarnate:IsAvailable()) and EnemiesCount8ySplash < 4) and not VarCleaveAPL) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies!=1|variable.cleave_apl
    if (EnemiesCount8ySplash > 1 or VarCleaveAPL) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if CDsON() and Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- conflagrate,if=(talent.roaring_blaze&debuff.conflagrate.remains<1.5)|charges=max_charges
    if S.Conflagrate:IsReady() and ((S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.RoaringBlazeDebuff) < 1.5) or S.Conflagrate:Charges() == S.Conflagrate:MaxCharges()) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 2"; end
    end
    -- dimensional_rift,if=soul_shard<4.7&(charges>2|time_to_die<cooldown.dimensional_rift.duration)
    if CDsON() and S.DimensionalRift:IsCastable() and (Player:SoulShardsP() < 4.7 and (S.DimensionalRift:Charges() > 2 or FightRemains < S.DimensionalRift:Cooldown())) then
      if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift main 4"; end
    end
    -- cataclysm,if=raid_event.adds.in>15
    if CDsON() and S.Cataclysm:IsReady() then
      if Cast(S.Cataclysm, Settings.Destruction.GCDasOffGCD.Cataclysm, nil, not Target:IsInRange(40)) then return "cataclysm main 6"; end
    end
    -- channel_demonfire,if=talent.raging_demonfire&(dot.immolate.remains-5*(action.chaos_bolt.in_flight&talent.internal_combustion))>cast_time&(debuff.conflagrate.remains>execute_time|!talent.roaring_blaze)
    if S.ChannelDemonfire:IsReady() and (S.RagingDemonfire:IsAvailable() and (Target:DebuffRemains(S.ImmolateDebuff) - 5 * num(S.ChaosBolt:InFlight() and S.InternalCombustion:IsAvailable())) > S.ChannelDemonfire:CastTime() and (Target:DebuffRemains(S.Conflagrate) > S.ChannelDemonfire:ExecuteTime() or not S.RoaringBlaze:IsAvailable())) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 8"; end
    end
    -- soul_fire,if=soul_shard<=3.5&(debuff.conflagrate.remains>cast_time+travel_time|!talent.roaring_blaze&buff.backdraft.up)
    if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 3.5 and (Target:DebuffRemains(S.RoaringBlazeDebuff) > S.SoulFire:CastTime() + S.SoulFire:TravelTime() or (not S.RoaringBlaze:IsAvailable()) and Player:BuffUp(S.BackdraftBuff))) then
      if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire main 10"; end
    end
    -- immolate,if=(((dot.immolate.remains-5*(action.chaos_bolt.in_flight&talent.internal_combustion))<dot.immolate.duration*0.3)|dot.immolate.remains<3|(dot.immolate.remains-action.chaos_bolt.execute_time)<5&talent.infernal_combustion&action.chaos_bolt.usable)&(!talent.cataclysm|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.soul_fire|cooldown.soul_fire.remains+action.soul_fire.cast_time>(dot.immolate.remains-5*talent.internal_combustion))&target.time_to_die>8
    if S.Immolate:IsCastable() and ((((Target:DebuffRemains(S.ImmolateDebuff) - 5 * num(S.ChaosBolt:InFlight() and S.InternalCombustion:IsAvailable())) < S.ImmolateDebuff:PandemicThreshold()) or Target:DebuffRemains(S.ImmolateDebuff) < 3 or (Target:DebuffRemains(S.ImmolateDebuff) - S.ChaosBolt:ExecuteTime()) < 5 and S.InternalCombustion:IsAvailable() and S.ChaosBolt:IsReady()) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > Target:DebuffRemains(S.ImmolateDebuff)) and ((not S.SoulFire:IsAvailable()) or S.SoulFire:CooldownRemains() + S.SoulFire:CastTime() > (Target:DebuffRemains(S.ImmolateDebuff) - 5 * num(S.InternalCombustion:IsAvailable()))) and Target:TimeToDie() > 8) then
      if Cast(S.Immolate, nil, nil, not Target:IsSpellInRange(S.Immolate)) then return "immolate main 12"; end
    end
    -- havoc,if=talent.cry_havoc&((buff.ritual_of_ruin.up&pet.infernal.active&talent.burn_to_ashes)|((buff.ritual_of_ruin.up|pet.infernal.active)&!talent.burn_to_ashes))
    if S.Havoc:IsCastable() and (not Settings.Destruction.IgnoreSTHavoc) and (S.CryHavoc:IsAvailable() and ((Player:BuffUp(S.RitualofRuinBuff) or InfernalTime() > 0 and S.BurntoAshes:IsAvailable()) or ((Player:BuffUp(S.RitualofRuinBuff) or InfernalTime() > 0) and not S.BurntoAshes:IsAvailable()))) then
      if Cast(S.Havoc, nil, nil, not Target:IsSpellInRange(S.Havoc)) then return "havoc (st) main 14"; end
    end
    -- channel_demonfire,if=dot.immolate.remains>cast_time&set_bonus.tier30_4pc
    if S.ChannelDemonfire:IsCastable() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime() and Player:HasTier(30, 4)) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 16"; end
    end
    -- chaos_bolt,if=pet.infernal.active|pet.blasphemy.active|soul_shard>=4
    if S.ChaosBolt:IsReady() and (InfernalTime() > 0 or BlasphemyTime() > 0 or Player:SoulShardsP() >= 4) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 18"; end
    end
    -- summon_infernal
    if CDsON() and S.SummonInfernal:IsCastable() then
      if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal main 20"; end
    end
    -- channel_demonfire,if=talent.ruin.rank>1&!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))&dot.immolate.remains>cast_time
    if S.ChannelDemonfire:IsCastable() and (S.Ruin:TalentRank() > 1 and not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable())) and Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 22"; end
    end
    -- conflagrate,if=buff.backdraft.down&soul_shard>=1.5&!talent.roaring_blaze
    if S.Conflagrate:IsCastable() and (Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1.5 and not S.RoaringBlaze:IsAvailable()) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 24"; end
    end
    -- incinerate,if=cast_time+action.chaos_bolt.cast_time<buff.madness_cb.remains
    if S.Incinerate:IsCastable() and (S.Incinerate:CastTime() + S.ChaosBolt:CastTime() < Player:BuffRemains(S.MadnessCBBuff)) then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate main 26"; end
    end
    -- chaos_bolt,if=buff.rain_of_chaos.remains>cast_time
    if S.ChaosBolt:IsReady() and (Player:BuffRemains(S.RainofChaosBuff) > S.ChaosBolt:CastTime()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 28"; end
    end
    -- chaos_bolt,if=buff.backdraft.up&!talent.eradication&!talent.madness_of_the_azjaqir
    if S.ChaosBolt:IsReady() and (Player:BuffUp(S.BackdraftBuff) and (not S.Eradication:IsAvailable()) and not S.MadnessoftheAzjAqir:IsAvailable()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 30"; end
    end
    -- chaos_bolt,if=buff.madness_cb.up
    if S.ChaosBolt:IsReady() and (Player:BuffUp(S.MadnessCBBuff)) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 32"; end
    end
    -- channel_demonfire,if=!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))&dot.immolate.remains>cast_time
    if S.ChannelDemonfire:IsCastable() and (not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable())) and Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 34"; end
    end
    -- dimensional_rift
    if CDsON() and S.DimensionalRift:IsCastable() then
      if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift main 36"; end
    end
    -- chaos_bolt,if=soul_shard>3.5
    if S.ChaosBolt:IsReady() and (Player:SoulShardsP() >= 3.5) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 38"; end
    end
    -- chaos_bolt,if=talent.soul_conduit&!talent.madness_of_the_azjaqir|!talent.backdraft
    if S.ChaosBolt:IsReady() and (S.SoulConduit:IsAvailable() and (not S.MadnessoftheAzjAqir:IsAvailable()) or not S.Backdraft:IsAvailable()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 40"; end
    end
    -- chaos_bolt,if=fight_remains<5&fight_remains>cast_time+travel_time
    -- Note: Added a buffer of 0.5s
    if S.ChaosBolt:IsReady() and (FightRemains < 5.5 and FightRemains > S.ChaosBolt:CastTime() + S.ChaosBolt:TravelTime() + 0.5) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 42"; end
    end
    -- conflagrate,if=charges>(max_charges-1)|time_to_die<gcd.max*charges
    if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < GCDMax * S.Conflagrate:Charges()) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 44"; end
    end
    -- incinerate
    if S.Incinerate:IsCastable() then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate main 46"; end
    end
  end
end

local function OnInit()
  S.ImmolateDebuff:RegisterAuraTracking()

  HR.Print("Destruction Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(267, APL, OnInit)