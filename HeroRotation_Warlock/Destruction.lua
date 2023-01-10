--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
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
  --  I.TrinketName:ID(),
}

-- Enemies
local Enemies40y, EnemiesCount8ySplash

-- Rotation Variables
local VarPoolSoulShards = false
local VarCleaveAPL = false
local VarHavocActive = false
local VarHavocRemains = 0
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  VarPoolSoulShards = false
  VarCleaveAPL = false
  VarHavocActive = false
  VarHavocRemains = 0
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
      return true,CycleUnit:DebuffRemains(S.Havoc)
    end
  end
  return false, 0
end

local function InfernalTime()
  return HL.GuardiansTable.InfernalDuration or (S.SummonInfernal:InFlight() and 30) or 0
end

local function BlasphemyTime()
  return HL.GuardiansTable.BlasphemyDuration or 0
end

-- CastTargetIf/CastCycle functions
local function EvaluateCycleImmolateHavoc(TargetUnit)
  -- if=dot.immolate.refreshable&dot.immolate.remains<havoc_remains&soul_shard<4.5&(debuff.havoc.down|!dot.immolate.ticking)
  return (TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and TargetUnit:DebuffRemains(S.ImmolateDebuff) < VarHavocRemains and Player:SoulShardsP() < 4.5 and (TargetUnit:DebuffDown(S.HavocDebuff) or TargetUnit:DebuffDown(S.ImmolateDebuff)))
end

local function EvaluateCycleImmolateCleave(TargetUnit)
  -- if=((talent.internal_combustion&dot.immolate.refreshable)|dot.immolate.remains<3)&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains>remains)
  return (((S.InternalCombustion:IsAvailable() and TargetUnit:DebuffRefreshable(S.ImmolateDebuff)) or TargetUnit:DebuffRemains(S.ImmolateDebuff) < 3) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and ((not S.SoulFire:IsAvailable()) or S.SoulFire:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)))
end

local function EvaluateCycleImmolateAoE(TargetUnit)
  -- if=dot.immolate.remains<5&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains)&active_dot.immolate<=6
  -- Note: active_dot.immolate handled before CastCycle
  return (TargetUnit:DebuffRemains(S.ImmolateDebuff) < 5 and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)) and (not S.RagingDemonfire:IsAvailable() or S.ChannelDemonfire:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff)))
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
  -- cataclysm
  if S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, nil, nil, not Target:IsInRange(40)) then return "cataclysm precombat 6"; end
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
  --use_item,slot=trinket1,if=pet.infernal.active|!talent.summon_infernal|time_to_die<21|trinket.1.cooldown.duration<cooldown.summon_infernal.remains
  --use_item,slot=trinket2,if=pet.infernal.active|!talent.summon_infernal|time_to_die<21|trinket.2.cooldown.duration<cooldown.summon_infernal.remains
  --use_item,slot=trinket1,if=(!talent.rain_of_chaos&time_to_die<cooldown.summon_infernal.remains+trinket.1.cooldown.duration&time_to_die>trinket.1.cooldown.duration)|time_to_die<cooldown.summon_infernal.remains|(trinket.2.cooldown.remains>0&trinket.2.cooldown.remains<cooldown.summon_infernal.remains)
  --use_item,slot=trinket2,if=(!talent.rain_of_chaos&time_to_die<cooldown.summon_infernal.remains+trinket.2.cooldown.duration&time_to_die>trinket.2.cooldown.duration)|time_to_die<cooldown.summon_infernal.remains|(trinket.1.cooldown.remains>0&trinket.1.cooldown.remains<cooldown.summon_infernal.remains)
  --use_item,name=erupting_spear_fragment,if=(!talent.rain_of_chaos&time_to_die<cooldown.summon_infernal.remains+trinket.erupting_spear_fragment.cooldown.duration&time_to_die>trinket.erupting_spear_fragment.cooldown.duration)|time_to_die<cooldown.summon_infernal.remains|trinket.erupting_spear_fragment.cooldown.duration<cooldown.summon_infernal.remains+5
  --use_item,name=desperate_invokers_codex
  --use_item,name=iceblood_deathsnare
  --use_item,name=conjured_chillglobe
end

local function oGCD()
  if InfernalTime() > 0 or not S.SummonInfernal:IsAvailable() then
    -- potion,if=pet.infernal.active|!talent.summon_infernal
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 8"; end
      end
    end
    -- berserking,if=pet.infernal.active|!talent.summon_infernal|(time_to_die<(cooldown.summon_infernal.remains+cooldown.berserking.duration)&(time_to_die>cooldown.berserking.duration))|time_to_die<cooldown.summon_infernal.remains
    if S.Berserking:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 12) and (FightRemains > 12) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.Berserking, Settings.Commons.GCDasOffGCD.Racials) then return "berserking cds 10"; end
    end
    -- blood_fury,if=pet.infernal.active|!talent.summon_infernal|(time_to_die<cooldown.summon_infernal.remains+10+cooldown.blood_fury.duration&time_to_die>cooldown.blood_fury.duration)|time_to_die<cooldown.summon_infernal.remains
    if S.BloodFury:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 15) and (FightRemains > 15) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.BloodFury, Settings.Commons.GCDasOffGCD.Racials) then return "blood_fury cds 12"; end
    end
    -- fireblood,if=pet.infernal.active|!talent.summon_infernal|(time_to_die<cooldown.summon_infernal.remains+10+cooldown.fireblood.duration&time_to_die>cooldown.fireblood.duration)|time_to_die<cooldown.summon_infernal.remains
    if S.Fireblood:IsCastable() and (FightRemains < (S.SummonInfernal:CooldownRemains() + 10 + 8) and (FightRemains > 8) or FightRemains < S.SummonInfernal:CooldownRemains()) then
      if Cast(S.Fireblood, Settings.Commons.GCDasOffGCD.Racials) then return "fireblood cds 14"; end
    end
  end
end

local function Havoc()
  -- conflagrate,if=talent.backdraft&buff.backdraft.down&soul_shard>=1&soul_shard<=4
  if S.Conflagrate:IsCastable() and (S.Backdraft:IsAvailable() and Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1 and Player:SoulShardsP() <= 4) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 2"; end
  end
  -- soul_fire,if=cast_time<havoc_remains&soul_shard<3
  if S.SoulFire:IsCastable() and (S.SoulFire:CastTime() < VarHavocRemains and Player:SoulShardsP() < 3) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire havoc 4"; end
  end
  -- channel_demonfire,if=soul_shard<4.5&talent.raging_demonfire.rank=2&active_enemies>2
  if S.ChannelDemonfire:IsCastable() and (Player:SoulShardsP() < 4.5 and S.RagingDemonfire:TalentRank() == 2 and EnemiesCount8ySplash > 2) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire havoc 6"; end
  end
  -- immolate,cycle_targets=1,if=dot.immolate.refreshable&dot.immolate.remains<havoc_remains&soul_shard<4.5&(debuff.havoc.down|!dot.immolate.ticking)
  if S.Immolate:IsCastable() then
    if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolateHavoc, not Target:IsSpellInRange(S.Immolate)) then return "immolate havoc 8"; end
  end
  -- chaos_bolt,if=talent.cry_havoc&!talent.inferno&cast_time<havoc_remains
  if S.ChaosBolt:IsReady() and (S.CryHavoc:IsAvailable() and (not S.Inferno:IsAvailable()) and S.ChaosBolt:CastTime() < VarHavocRemains) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt havoc 9"; end
  end
  -- chaos_bolt,if=cast_time<havoc_remains&(active_enemies<4-talent.inferno+talent.madness_of_the_azjaqir-(talent.inferno&(talent.rain_of_chaos|talent.avatar_of_destruction)&buff.rain_of_chaos.up))
  if S.ChaosBolt:IsReady() and (S.ChaosBolt:CastTime() < VarHavocRemains and (EnemiesCount8ySplash < 4 - num(S.Inferno:IsAvailable()) + num(S.MadnessoftheAzjAqir:IsAvailable()) - num(S.Inferno:IsAvailable() and (S.RainofChaos:IsAvailable() or S.AvatarofDestruction:IsAvailable()) and Player:BuffUp(S.RainofChaosBuff)))) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt havoc 10"; end
  end
  -- rain_of_fire,if=(active_enemies>=4-talent.inferno+talent.madness_of_the_azjaqir)
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash >= 4 - num(S.Inferno:IsAvailable()) + num(S.MadnessoftheAzjAqir:IsAvailable())) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 12"; end
  end
  -- rain_of_fire,if=active_enemies>1&(talent.avatar_of_destruction|(talent.rain_of_chaos&buff.rain_of_chaos.up))&talent.inferno.enabled
  if S.RainofFire:IsReady() and (EnemiesCount8ySplash > 1 and (S.AvatarofDestruction:IsAvailable() or (S.RainofChaos:IsAvailable() and Player:BuffUp(S.RainofChaosBuff))) and S.Inferno:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire havoc 13"; end
  end
  -- conflagrate,if=!talent.backdraft
  if S.Conflagrate:IsCastable() and not S.Backdraft:IsAvailable() then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate havoc 14"; end
  end
  -- incinerate,if=cast_time<havoc_remains
  if S.Incinerate:IsCastable() and (S.Incinerate:CastTime() < VarHavocRemains) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate havoc 16"; end
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
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd
  if (VarHavocActive and VarHavocRemains > Player:GCD()) then
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
  -- cataclysm
  if CDsON() and S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, nil, nil, not Target:IsSpellInRange(S.Cataclysm)) then return "cataclysm cleave 6"; end
  end
  -- channel_demonfire,if=talent.raging_demonfire
  if S.ChannelDemonfire:IsCastable() and (S.RagingDemonfire:IsAvailable()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 8"; end
  end
  -- soul_fire,if=soul_shard<=4&!variable.pool_soul_shards
  if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 4 and not VarPoolSoulShards) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 10"; end
  end
  -- immolate,cycle_targets=1,if=((talent.internal_combustion&dot.immolate.refreshable)|dot.immolate.remains<3)&(!talent.cataclysm|cooldown.cataclysm.remains>remains)&(!talent.soul_fire|cooldown.soul_fire.remains>remains)
  if S.Immolate:IsCastable() then
    if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolateCleave, not Target:IsSpellInRange(S.Immolate)) then return "immolate cleave 12"; end
  end
  -- havoc,cycle_targets=1,if=!(target=self.target)&(!cooldown.summon_infernal.up|!talent.summon_infernal)
  if S.Havoc:IsCastable() and (S.SummonInfernal:CooldownDown() or not S.SummonInfernal:IsAvailable()) then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(Enemies40y) do
      if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() then
        HR.CastLeftNameplate(CycleUnit, S.Havoc)
        break
      end
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
  --incinerate,if=buff.burn_to_ashes.up&cast_time+action.chaos_bolt.cast_time<buff.madness_cb.remains
  if S.Incinerate:IsCastable() and (Player:BuffUp(S.BurntoAshesBuff) and S.Incinerate:CastTime() + S.ChaosBolt:CastTime() < Player:BuffRemains(S.MadnessCBBuff)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 23"; end
  end
  -- chaos_bolt,if=buff.rain_of_chaos.remains>cast_time
  if S.ChaosBolt:IsReady() and (Player:BuffRemains(S.RainofChaosBuff) > S.ChaosBolt:CastTime()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 24"; end
  end
  -- chaos_bolt,if=buff.backdraft.up&!variable.pool_soul_shards
  if S.ChaosBolt:IsReady() and (Player:BuffUp(S.BackdraftBuff) and not VarPoolSoulShards) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 26"; end
  end
  -- chaos_bolt,if=talent.eradication&!variable.pool_soul_shards&debuff.eradication.remains<cast_time&!action.chaos_bolt.in_flight
  if S.ChaosBolt:IsReady() and (S.Eradication:IsAvailable() and (not VarPoolSoulShards) and Target:DebuffRemains(S.EradicationDebuff) < S.ChaosBolt:CastTime() and not S.ChaosBolt:InFlight()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 28"; end
  end
  -- chaos_bolt,if=buff.madness_cb.up
  if S.ChaosBolt:IsReady() and (Player:BuffUp(S.MadnessCBBuff)) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 30"; end
  end
  -- soul_fire,if=soul_shard<=4&talent.mayhem
  if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 4 and S.Mayhem:IsAvailable()) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire cleave 32"; end
  end
  -- channel_demonfire,if=!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))
  if S.ChannelDemonfire:IsCastable() and (not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable()))) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 34"; end
  end
  -- dimensional_rift
  if CDsON() and S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift cleave 36"; end
  end
  -- chaos_bolt,if=soul_shard>3.5
  if S.ChaosBolt:IsReady() and (Player:SoulShardsP() > 3.5) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 38"; end
  end
  -- chaos_bolt,if=!variable.pool_soul_shards&(talent.soul_conduit&!talent.madness_of_the_azjaqir|!talent.backdraft)
  if S.ChaosBolt:IsReady() and ((not VarPoolSoulShards) and (S.SoulConduit:IsAvailable() and (not S.MadnessoftheAzjAqir:IsAvailable()) or not S.Backdraft:IsAvailable())) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 40"; end
  end
  -- chaos_bolt,if=time_to_die<5&time_to_die>cast_time+travel_time
  -- Note: Added a buffer of 0.5s
  if S.ChaosBolt:IsReady() and (FightRemains < 5.5 and FightRemains > S.ChaosBolt:CastTime() + S.ChaosBolt:TravelTime() + 0.5) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 42"; end
  end
  -- conflagrate,if=charges>(max_charges-1)|time_to_die<gcd*charges
  if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < Player:GCD() * S.Conflagrate:Charges()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate cleave 44"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate cleave 46"; end
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
  -- call_action_list,name=havoc,if=havoc_active&havoc_remains>gcd&active_enemies<5+(talent.cry_havoc&!talent.inferno)
  if (VarHavocActive and VarHavocRemains > Player:GCD() and EnemiesCount8ySplash < 5 + num(S.CryHavoc:IsAvailable() and not S.Inferno:IsAvailable())) then
    local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
  end
  -- rain_of_fire,if=pet.infernal.active
  if S.RainofFire:IsReady() and (InfernalTime() > 0) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 2"; end
  end
  -- rain_of_fire,if=talent.avatar_of_destruction
  if S.RainofFire:IsReady() and (S.AvatarofDestruction:IsAvailable()) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 4"; end
  end
  -- rain_of_fire,if=soul_shard=5
  if S.RainofFire:IsReady() and (Player:SoulShardsP() == 5) then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 6"; end
  end
  -- chaos_bolt,if=soul_shard>3.5-(0.1*active_enemies)&!talent.rain_of_fire
  if S.ChaosBolt:IsReady() and (Player:SoulShardsP() > 3.5 - (0.1 * EnemiesCount8ySplash) and not S.RainofFire:IsAvailable()) then
    if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt aoe 8"; end
  end
  -- cataclysm
  if CDsON() and S.Cataclysm:IsCastable() then
    if Cast(S.Cataclysm, nil, nil, not Target:IsSpellInRange(S.Cataclysm)) then return "cataclysm aoe 10"; end
  end
  -- channel_demonfire,if=dot.immolate.remains>cast_time&talent.raging_demonfire
  if S.ChannelDemonfire:IsCastable() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime() and S.RagingDemonfire:IsAvailable()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire aoe 12"; end
  end
  -- immolate,cycle_targets=1,if=dot.immolate.remains<5&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.raging_demonfire|cooldown.channel_demonfire.remains>remains)&active_dot.immolate<=6
  if S.Immolate:IsCastable() and (S.ImmolateDebuff:AuraActiveCount() <= 6) then
    if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolateAoE, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 10"; end
  end
  -- havoc,cycle_targets=1,if=!(self.target=target)&!talent.rain_of_fire
  if S.Havoc:IsCastable() and (not S.RainofFire:IsAvailable()) then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(Enemies40y) do
      if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() then
        HR.CastLeftNameplate(CycleUnit, S.Havoc)
        break
      end
    end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10
  if S.SummonSoulkeeper:IsCastable() and (Player:BuffStack(S.TormentedSoulBuff) == 10) then
    if Cast(S.SummonSoulkeeper, Settings.Destruction.GCDasOffGCD.SummonSoulkeeper) then return "summon_soulkeeper aoe 12"; end
  end
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- summon_infernal
  if CDsON() and S.SummonInfernal:IsCastable() then
    if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal aoe 14"; end
  end
  -- rain_of_fire
  if S.RainofFire:IsReady() then
    if Cast(S.RainofFire, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "rain_of_fire aoe 16"; end
  end
  -- havoc,cycle_targets=1,if=!(self.target=target)
  if S.Havoc:IsCastable() then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(Enemies40y) do
      if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() then
        HR.CastLeftNameplate(CycleUnit, S.Havoc)
        break
      end
    end
  end
  -- channel_demonfire,if=dot.immolate.remains>cast_time
  if S.ChannelDemonfire:IsReady() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
    if Cast(S.ChannelDemonfire, nil, nil, not Target:IsSpellInRange(S.ChannelDemonfire)) then return "channel_demonfire aoe 17"; end
  end
  -- immolate,cycle_targets=1,if=dot.immolate.remains<5&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>dot.immolate.remains)
  if S.Immolate:IsCastable() then
    if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolateAoE, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 18"; end
  end
  -- soul_fire,if=buff.backdraft.up
  if S.SoulFire:IsCastable() and (Player:BuffUp(S.BackdraftBuff)) then
    if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire aoe 20"; end
  end
  -- incinerate,if=talent.fire_and_brimstone.enabled&buff.backdraft.up
  if S.Incinerate:IsCastable() and (S.FireandBrimstone:IsAvailable() and Player:BuffUp(S.Backdraft)) then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 22"; end
  end
  -- conflagrate,if=buff.backdraft.down|!talent.backdraft
  if S.Conflagrate:IsCastable() and (Player:BuffDown(S.Backdraft) or not S.Backdraft:IsAvailable()) then
    if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate aoe 24"; end
  end
  -- dimensional_rift
  if CDsON() and S.DimensionalRift:IsCastable() then
    if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift aoe 26"; end
  end
  -- immolate,if=dot.immolate.refreshable
  if S.Immolate:IsCastable() and (Target:DebuffRefreshable(S.ImmolateDebuff)) then
    if Cast(S.Immolate, nil, nil, not Target:IsSpellInRange(S.Immolate)) then return "immolate aoe 28"; end
  end
  -- incinerate
  if S.Incinerate:IsCastable() then
    if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 30"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(12)
  if AoEON() then
    EnemiesCount8ySplash = #Enemies8ySplash
  else
    EnemiesCount8ySplash = 1
  end

  -- Check Havoc Status
  VarHavocActive, VarHavocRemains = UnitWithHavoc(Enemies40y)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
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
  -- inquisitors_gaze
  if S.InquisitorsGaze:IsCastable() and not Player:BuffUp(S.InquisitorsGazeBuff) then
    if Cast(S.InquisitorsGaze, Settings.Destruction.GCDasOffGCD.InquisitorsGaze) then return "inquisitors_gaze ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies!=1&active_enemies<=2+(!talent.inferno&talent.madness_of_the_azjaqir&talent.ashen_remains)|variable.cleave_apl
    if (EnemiesCount8ySplash > 1 and EnemiesCount8ySplash <= 2 + num((not S.Inferno:IsAvailable()) and S.MadnessoftheAzjAqir:IsAvailable() and S.AshenRemains:IsAvailable()) or VarCleaveAPL) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>=3
    if (EnemiesCount8ySplash >= 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
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
    -- cataclysm
    if CDsON() and S.Cataclysm:IsReady() then
      if Cast(S.Cataclysm, nil, nil, not Target:IsInRange(40)) then return "cataclysm main 6"; end
    end
    -- channel_demonfire,if=talent.raging_demonfire
    if S.ChannelDemonfire:IsReady() and S.RagingDemonfire:IsAvailable() then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 7"; end
    end
    -- soul_fire,if=soul_shard<=4
    if S.SoulFire:IsCastable() and (Player:SoulShardsP() <= 4) then
      if Cast(S.SoulFire, nil, nil, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire main 8"; end
    end
    -- immolate,if=((dot.immolate.refreshable&talent.internal_combustion)|dot.immolate.remains<3)&(!talent.cataclysm|cooldown.cataclysm.remains>dot.immolate.remains)&(!talent.soul_fire|cooldown.soul_fire.remains>dot.immolate.remains)
    if S.Immolate:IsCastable() and (((Target:DebuffRefreshable(S.ImmolateDebuff) and S.InternalCombustion:IsAvailable()) or Target:DebuffRemains(S.ImmolateDebuff) < 3) and ((not S.Cataclysm:IsAvailable()) or S.Cataclysm:CooldownRemains() > Target:DebuffRemains(S.ImmolateDebuff)) and ((not S.SoulFire:IsAvailable()) or S.SoulFire:CooldownRemains() > Target:DebuffRemains(S.ImmolateDebuff))) then
      if Cast(S.Immolate, nil, nil, not Target:IsSpellInRange(S.Immolate)) then return "immolate main 10"; end
    end
    -- havoc,if=talent.cry_havoc&(buff.ritual_of_ruin.up|pet.infernal.active)
    -- Should be a cycle_targets, like other Havoc casts?
    if S.Havoc:IsCastable() and (S.CryHavoc:IsAvailable() and (Player:BuffUp(S.RitualofRuinBuff) or InfernalTime() > 0)) then
      local TargetGUID = Target:GUID()
      for _, CycleUnit in pairs(Enemies40y) do
        if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() then
          HR.CastLeftNameplate(CycleUnit, S.Havoc)
          break
        end
      end
    end
    -- chaos_bolt,if=pet.infernal.active|pet.blasphemy.active|soul_shard>=4
    if S.ChaosBolt:IsReady() and (InfernalTime() > 0 or BlasphemyTime() > 0 or Player:SoulShardsP() >= 4) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 12"; end
    end
    -- summon_infernal
    if CDsON() and S.SummonInfernal:IsCastable() then
      if Cast(S.SummonInfernal, Settings.Destruction.GCDasOffGCD.SummonInfernal) then return "summon_infernal main 14"; end
    end
    -- channel_demonfire,if=talent.ruin.rank>1&!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))&dot.immolate.remains>cast_time
    if S.ChannelDemonfire:IsCastable() and (S.Ruin:TalentRank() > 1 and not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable())) and Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire main 16"; end
    end
    -- conflagrate,if=buff.backdraft.down&soul_shard>=1.5&!talent.roaring_blaze
    if S.Conflagrate:IsCastable() and (Player:BuffDown(S.Backdraft) and Player:SoulShardsP() >= 1.5 and not S.RoaringBlaze:IsAvailable()) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 28"; end
    end
    --incinerate,if=buff.burn_to_ashes.up&cast_time+action.chaos_bolt.cast_time<buff.madness_cb.remains
    if S.Incinerate:IsCastable() and (Player:BuffUp(S.BurntoAshesBuff) and S.Incinerate:CastTime() + S.ChaosBolt:CastTime() < Player:BuffRemains(S.MadnessCBBuff)) then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate aoe 29"; end
    end
    -- chaos_bolt,if=buff.rain_of_chaos.remains>cast_time
    if S.ChaosBolt:IsReady() and (Player:BuffRemains(S.RainofChaosBuff) > S.ChaosBolt:CastTime()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 30"; end
    end
    -- chaos_bolt,if=buff.backdraft.up&!talent.eradication&!talent.madness_of_the_azjaqir
    if S.ChaosBolt:IsReady() and (Player:BuffUp(S.Backdraft) and (not S.Eradication:IsAvailable()) and not S.MadnessoftheAzjAqir:IsAvailable()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 32"; end
    end
    -- chaos_bolt,if=buff.madness_cb.up
    if S.ChaosBolt:IsReady() and (Player:BuffUp(S.MadnessCBBuff)) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt cleave 36"; end
    end
    -- channel_demonfire,if=!(talent.diabolic_embers&talent.avatar_of_destruction&(talent.burn_to_ashes|talent.chaos_incarnate))&dot.immolate.remains>cast_time
    if S.ChannelDemonfire:IsCastable() and (not (S.DiabolicEmbers:IsAvailable() and S.AvatarofDestruction:IsAvailable() and (S.BurntoAshes:IsAvailable() or S.ChaosIncarnate:IsAvailable())) and Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
      if Cast(S.ChannelDemonfire, nil, nil, not Target:IsInRange(40)) then return "channel_demonfire cleave 38"; end
    end
    -- dimensional_rift
    if CDsON() and S.DimensionalRift:IsCastable() then
      if Cast(S.DimensionalRift, nil, nil, not Target:IsSpellInRange(S.DimensionalRift)) then return "dimensional_rift cleave 40"; end
    end
    -- chaos_bolt,if=soul_shard>3.5
    if S.ChaosBolt:IsReady() and (Player:SoulShardsP() >= 3.5) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 42"; end
    end
    -- chaos_bolt,if=talent.soul_conduit&!talent.madness_of_the_azjaqir|!talent.backdraft
    if S.ChaosBolt:IsReady() and (S.SoulConduit:IsAvailable() and (not S.MadnessoftheAzjAqir:IsAvailable()) or not S.Backdraft:IsAvailable()) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 44"; end
    end
    -- chaos_bolt,if=time_to_die<5&time_to_die>cast_time+travel_time
    -- Note: Added a buffer of 0.5s
    if S.ChaosBolt:IsReady() and (FightRemains < 5.5 and FightRemains > S.ChaosBolt:CastTime() + S.ChaosBolt:TravelTime() + 0.5) then
      if Cast(S.ChaosBolt, nil, nil, not Target:IsSpellInRange(S.ChaosBolt)) then return "chaos_bolt main 46"; end
    end
    -- conflagrate,if=charges>(max_charges-1)|time_to_die<gcd*charges
    -- Note: Added time_to_die buffer of 0.5s
    if S.Conflagrate:IsCastable() and (S.Conflagrate:Charges() > (S.Conflagrate:MaxCharges() - 1) or FightRemains < Player:GCD() + 0.5) then
      if Cast(S.Conflagrate, nil, nil, not Target:IsSpellInRange(S.Conflagrate)) then return "conflagrate main 48"; end
    end
    -- incinerate
    if S.Incinerate:IsCastable() then
      if Cast(S.Incinerate, nil, nil, not Target:IsSpellInRange(S.Incinerate)) then return "incinerate main 50"; end
    end
  end
end

local function OnInit()
  S.ImmolateDebuff:RegisterAuraTracking()

  HR.Print("Destruction Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(267, APL, OnInit)