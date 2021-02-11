--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warlock.Destruction
local I = Item.Warlock.Destruction

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local Enemies40y, Enemies40yCount, EnemiesCount10ySplash;
local InfernalActive, InfernalRemains;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Destruction = HR.GUISettings.APL.Warlock.Destruction
};

-- Variables
local VarPoolSoulShards = 0;

HL:RegisterForEvent(function()
  VarPoolSoulShards = 0
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.ChaosBolt:RegisterInFlight();
end, "LEARNED_SPELL_IN_TAB")
S.ChaosBolt:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EnemyHasHavoc(Enemies)
  for _, Enemy in pairs(Enemies) do
    if Enemy:DebuffUp(S.Havoc) then
      return Enemy:DebuffRemains(S.Havoc)
    end
  end
  return 0
end

local function EvaluateCycleImmolate46(TargetUnit)
  return TargetUnit:DebuffRemains(S.ImmolateDebuff) < 5 and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff))
end

local function EvaluateCycleHavoc71(TargetUnit)
  return not (TargetUnit == Target) and Enemies40yCount < 4
end

local function EvaluateCycleHavoc90(TargetUnit)
  return not (TargetUnit == Target)
end

local function EvaluateCycleSoufFire330(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (Player:SoulShardsP() <= 4) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff))
end

local function EvaluateCycleImmolate337(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.ImmolateDebuff) and (not S.Cataclysm:IsAvailable() or S.Cataclysm:CooldownRemains() > TargetUnit:DebuffRemains(S.ImmolateDebuff))
end

local function EvaluateCycleHavoc402(TargetUnit)
  return not (TargetUnit == Target) and (TargetUnit:DebuffRemains(S.ImmolateDebuff) > S.ImmolateDebuff:BaseDuration() * 0.5 or not S.InternalCombustion:IsAvailable())
end

local function Precombat()
  -- flask (spectral_flask_of_power)
  -- food (feast_of_gluttonous_hedonism)
  -- augmentation (veiled)
  -- summon_pet
  if S.SummonPet:IsCastable() then
    if HR.Cast(S.SummonPet) then return "summon_pet 3"; end
  end
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() and Player:BuffDown(S.GrimoireofSacrificeBuff) then
    if HR.Cast(S.GrimoireofSacrifice) then return "grimoire_of_sacrifice 5"; end
  end
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- soul_fire
    if S.SoulFire:IsCastable() then
      if HR.Cast(S.SoulFire, nil, nil, 40) then return "soul_fire 12"; end
    end
    -- incinerate,if=!talent.soul_fire.enabled
    if S.Incinerate:IsReady() and (not S.SoulFire:IsAvailable()) then
      if HR.Cast(S.Incinerate, nil, nil, 40) then return "incinerate 14"; end
    end
  end
end

local function Cds()
  -- summon_infernal
  if S.SummonInfernal:IsReady() then
    if HR.Cast(S.SummonInfernal, nil, nil, 30) then return "summon_infernal 167"; end
  end
  -- dark_soul_instability
  if S.DarkSoulInstability:IsCastable() then
    if HR.Cast(S.DarkSoulInstability) then return "dark_soul_instability 223"; end
  end
  -- potion,if=pet.infernal.active
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.UsePotions and (InfernalActive) then
    if HR.Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.TrinketDisplayStyle) then return "potion_of_spectral_intellect 233"; end
  end
  -- berserking,if=pet.infernal.active
  if S.Berserking:IsCastable() and (InfernalActive) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 235"; end
  end
  -- blood_fury,if=pet.infernal.active
  if S.BloodFury:IsCastable() and (InfernalActive) then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 241"; end
  end
  -- fireblood,if=pet.infernal.active
  if S.Fireblood:IsCastable() and (InfernalActive) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 243"; end
  end
  -- use_items,if=pet.infernal.active&pet.infernal.remains<=20|target.time_to_die<=20
  if (InfernalActive and InfernalRemains <= 20 or Target:TimeToDie() <= 20) then
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
  end
end

local function Aoe()
  -- rain_of_fire,if=pet.infernal.active&(!cooldown.havoc.ready|active_enemies>3)
  if S.RainofFire:IsReady() and (InfernalActive and (not S.Havoc:CooldownUp() or Enemies40yCount > 3)) then
    if HR.Cast(S.RainofFire, nil, nil, 40) then return "rain_of_fire 18"; end
  end
  -- soul_rot
  if S.SoulRot:IsReady() then
    if HR.Cast(S.SoulRot, nil, nil, 40) then return "soul_rot 25"; end
  end
  -- channel_demonfire,if=dot.immolate.remains>cast_time
  if S.ChannelDemonfire:IsCastable() and (Target:DebuffRemains(S.ImmolateDebuff) > S.ChannelDemonfire:CastTime()) then
    if HR.Cast(S.ChannelDemonfire, nil, nil, 40) then return "channel_demonfire 34"; end
  end
  -- immolate,cycle_targets=1,if=remains<5&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>remains)
  if S.Immolate:IsReady() then
    if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolate46, not Target:IsSpellInRange(S.Immolate)) then return "immolate 64" end
  end
  -- call_action_list,name=cds
  if (HR.CDsON()) then
    local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=essences (BFA essences, not a real thing to cast/use)
  -- havoc,cycle_targets=1,if=!(target=self.target)&active_enemies<4
  if S.Havoc:IsReady() then
    if Everyone.CastCycle(S.Havoc, Enemies40y, EvaluateCycleHavoc71, not Target:IsSpellInRange(S.Havoc)) then return "havoc 71" end
  end
  -- rain_of_fire
  if S.RainofFire:IsReady() then
    if HR.Cast(S.RainofFire, nil, nil, 40) then return "rain_of_fire 85"; end
  end
  -- havoc,cycle_targets=1,if=!(self.target=target)
  if S.Havoc:IsReady() then
    if Everyone.CastCycle(S.Havoc, Enemies40y, EvaluateCycleHavoc90, not Target:IsSpellInRange(S.Havoc)) then return "havoc 90" end
  end
  -- FIXME decimating_bolt,if=(soulbind.lead_by_example.enabled|!talent.fire_and_brimstone.enabled)
  -- incinerate,if=talent.fire_and_brimstone.enabled&buff.backdraft.up&soul_shard<5-0.2*active_enemies
  if S.Incinerate:IsReady() and (S.FireandBrimstone:IsAvailable() and Player:BuffUp(S.BackdraftBuff) and Player:SoulShardsP() < 5 - 0.2 * Enemies40yCount) then
    if HR.Cast(S.Incinerate, nil, nil, 40) then return "incinerate 121"; end
  end
  -- soul_fire
  if S.SoulFire:IsCastable() then
    if HR.Cast(S.SoulFire, nil, nil, 40) then return "soul_fire 133"; end
  end
  -- conflagrate,if=buff.backdraft.down
  if S.Conflagrate:IsReady() and (Player:BuffDown(S.BackdraftBuff)) then
    if HR.Cast(S.Conflagrate, nil, nil, 40) then return "conflagrate 135"; end
  end
  -- shadowburn,if=target.health.pct<20
  if S.Shadowburn:IsCastable() and (Target:HealthPercentage() < 20) then
    if HR.Cast(S.Shadowburn, nil, nil, 40) then return "shadowburn 139"; end
  end
  -- FIXME scouring_tithe,if=!(talent.fire_and_brimstone.enabled|talent.inferno.enabled)
  -- FIXME impending_catastrophe,if=!(talent.fire_and_brimstone.enabled|talent.inferno.enabled)
  -- incinerate
  if S.Incinerate:IsReady() then
    if HR.Cast(S.Incinerate, nil, nil, 40) then return "incinerate 157"; end
  end
end

local function Havoc()
  -- conflagrate,if=buff.backdraft.down&soul_shard>=1&soul_shard<=4
  if S.Conflagrate:IsReady() and (Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1 and Player:SoulShardsP() <= 4) then
    if HR.Cast(S.Conflagrate, nil, nil, 40) then return "conflagrate 254"; end
  end
  -- soul_fire,if=cast_time<havoc_remains
  if S.SoulFire:IsCastable() and (S.ChaosBolt:CastTime() < EnemyHasHavoc(Enemies40y)) then
    if HR.Cast(S.SoulFire, nil, nil, 40) then return "soul_fire 256"; end
  end
  -- FIXME decimating_bolt,if=cast_time<havoc_remains&soulbind.lead_by_example.enabled
  -- scouring_tithe,if=cast_time<havoc_remains
  if S.ScouringTithe:IsReady() and (S.ScouringTithe:CastTime() < EnemyHasHavoc(Enemies40y)) then
    if HR.Cast(S.ScouringTithe, nil, nil, 40) then return "scouring_tithe 257"; end
  end
  -- immolate,if=talent.internal_combustion.enabled&remains<duration*0.5|!talent.internal_combustion.enabled&refreshable
  if S.Immolate:IsReady() and (S.InternalCombustion:IsAvailable() and Target:DebuffRemains(S.ImmolateDebuff) < S.ImmolateDebuff:BaseDuration() * 0.5 or not S.InternalCombustion:IsAvailable() and Target:DebuffRefreshable(S.ImmolateDebuff)) then
    if HR.Cast(S.Immolate, nil, nil, 40) then return "immolate 258"; end
  end
  -- chaos_bolt,if=cast_time<havoc_remains
  if S.ChaosBolt:IsReady() and (S.ChaosBolt:CastTime() < EnemyHasHavoc(Enemies40y)) then
    if HR.Cast(S.ChaosBolt, nil, nil, 40) then return "chaos_bolt 289"; end
  end
  -- shadowburn
  if S.Shadowburn:IsCastable() then
    if HR.Cast(S.Shadowburn, nil, nil, 40) then return "shadowburn 295"; end
  end
  -- incinerate,if=cast_time<havoc_remains
  if S.Incinerate:IsReady() and (S.Incinerate:CastTime() < EnemyHasHavoc(Enemies40y)) then
    if HR.Cast(S.Incinerate, nil, nil, 40) then return "incinerate 302"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies40y = Player:GetEnemiesInRange(40)
  if HR.AoEON() then
    Enemies40yCount = #Enemies40y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    Enemies40yCount = 1
    EnemiesCount10ySplash = 1
  end

  InfernalActive = (S.SummonInfernal:CooldownRemains() > 150) and true or false
  InfernalRemains = InfernalActive and (30 - (180 - S.SummonInfernal:CooldownRemains())) or 0

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- call_action_list,name=havoc,if=havoc_active&active_enemies>1&active_enemies<5-talent.inferno.enabled+(talent.inferno.enabled&talent.internal_combustion.enabled)
    if (bool(EnemyHasHavoc(Enemies40y)) and Enemies40yCount > 1 and Enemies40yCount < 5 - num(S.Inferno:IsAvailable()) + num((S.Inferno:IsAvailable() and S.InternalCombustion:IsAvailable()))) then
      local ShouldReturn = Havoc(); if ShouldReturn then return ShouldReturn; end
    end
    -- conflagrate,if=talent.roaring_blaze.enabled&debuff.roaring_blaze.remains<1.5
    if S.Conflagrate:IsReady() and (S.RoaringBlaze:IsAvailable() and Target:DebuffRemains(S.RoaringBlazeDebuff) < 1.5) then
      if HR.Cast(S.Conflagrate, nil, nil, 40) then return "conflagrate 320"; end
    end
    -- cataclysm,if=!(pet.infernal.active&dot.immolate.remains+1>pet.infernal.remains)|spell_targets.cataclysm>1
    if S.Cataclysm:IsReady() and (not (InfernalActive and Target:DebuffRemains(S.ImmolateDebuff) + 1 > InfernalRemains) or EnemiesCount10ySplash > 1) then
      if HR.Cast(S.Cataclysm, nil, nil, 40) then return "cataclysm 323"; end
    end
    -- call_action_list,name=aoe,if=active_enemies>2
    if (EnemiesCount10ySplash > 2) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- soul_fire,cycle_targets=1,if=refreshable&soul_shard<=4&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>remains)
    if S.SoulFire:IsCastable() then
      if Everyone.CastCycle(S.SoulFire, Enemies40y, EvaluateCycleSoufFire330, not Target:IsSpellInRange(S.SoulFire)) then return "soul_fire 330" end
    end
    -- immolate,cycle_targets=1,if=refreshable&(!talent.cataclysm.enabled|cooldown.cataclysm.remains>remains)
    if S.Immolate:IsReady() then
      if Everyone.CastCycle(S.Immolate, Enemies40y, EvaluateCycleImmolate337, not Target:IsSpellInRange(S.Immolate)) then return "immolate 337" end
    end
    -- immolate,if=talent.internal_combustion.enabled&action.chaos_bolt.in_flight&remains<duration*0.5
    if S.Immolate:IsReady() and (S.InternalCombustion:IsAvailable() and S.ChaosBolt:InFlight() and Target:DebuffRemains(S.ImmolateDebuff) < S.ImmolateDebuff:BaseDuration() * 0.5) then
      if HR.Cast(S.Immolate, nil, nil, 40) then return "immolate 356"; end
    end
    -- call_action_list,name=cds
    if (HR.CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=essences (BFA essences, not a real thing to cast/use)
    -- channel_demonfire
    if S.ChannelDemonfire:IsReady() then
      if HR.Cast(S.ChannelDemonfire, nil, nil, 40) then return "channel_demonfire 396"; end
    end
    -- scouring_tithe
    if S.ScouringTithe:IsReady() then
      if HR.Cast(S.ScouringTithe, nil, nil, 40) then return "scouring_tithe 398"; end
    end
    -- decimating_bolt
    if S.DecimatingBolt:IsReady() then
      if HR.Cast(S.DecimatingBolt, nil, nil, 40) then return "decimating_bolt 400"; end
    end
    -- havoc,cycle_targets=1,if=!(target=self.target)&(dot.immolate.remains>dot.immolate.duration*0.5|!talent.internal_combustion.enabled)
    if S.Havoc:IsReady() then
      if Everyone.CastCycle(S.Havoc, Enemies40y, EvaluateCycleHavoc402, not Target:IsSpellInRange(S.Havoc)) then return "havoc 402" end
    end
    -- impending_catastrophe
    if S.ImpendingCatastrophe:IsReady() then
      if HR.Cast(S.ImpendingCatastrophe, nil, nil, 40) then return "impending_catastrophe 410"; end
    end
    -- soul_rot
    if S.SoulRot:IsReady() then
      if HR.Cast(S.SoulRot, nil, nil, 40) then return "soul_rot 415"; end
    end
    -- FIXME havoc,if=runeforge.odr_shawl_of_the_ymirjar.equipped
    -- variable,name=pool_soul_shards,value=active_enemies>1&cooldown.havoc.remains<=10|cooldown.summon_infernal.remains<=15&talent.dark_soul_instability.enabled&cooldown.dark_soul_instability.remains<=15|talent.dark_soul_instability.enabled&cooldown.dark_soul_instability.remains<=15&(cooldown.summon_infernal.remains>target.time_to_die|cooldown.summon_infernal.remains+cooldown.summon_infernal.duration>target.time_to_die)
    if (true) then
      VarPoolSoulShards = num(Enemies40yCount > 1 and S.Havoc:CooldownRemains() <= 10 or S.SummonInfernal:CooldownRemains() <= 15 and (S.DarkSoulInstability:IsAvailable() and S.DarkSoulInstability:CooldownRemains() <= 15) or S.DarkSoulInstability:IsAvailable() and S.DarkSoulInstability:CooldownRemains() <= 15 and (S.SummonInfernal:CooldownRemains() > Target:TimeToDie() or S.SummonInfernal:CooldownRemains() + 180 > Target:TimeToDie()))
    end
    -- conflagrate,if=buff.backdraft.down&soul_shard>=1.5-0.3*talent.flashover.enabled&!variable.pool_soul_shards
    if S.Conflagrate:IsReady() and (Player:BuffDown(S.BackdraftBuff) and Player:SoulShardsP() >= 1.5 - 0.3 * num(S.Flashover:IsAvailable()) and not bool(VarPoolSoulShards)) then
      if HR.Cast(S.Conflagrate, nil, nil, 40) then return "conflagrate 425"; end
    end
    -- chaos_bolt,if=buff.dark_soul_instability.up
    if S.ChaosBolt:IsReady() and (S.DarkSoulInstability:IsAvailable() and Player:BuffUp(S.DarkSoulInstabilityBuff)) then
      if HR.Cast(S.ChaosBolt, nil, nil, 40) then return "chaos_bolt 450"; end
    end
    -- chaos_bolt,if=buff.backdraft.up&!variable.pool_soul_shards&!talent.eradication.enabled
    if S.ChaosBolt:IsReady() and (Player:BuffDown(S.BackdraftBuff) and (not bool(VarPoolSoulShards) and not S.Eradication:IsAvailable())) then
      if HR.Cast(S.ChaosBolt, nil, nil, 40) then return "chaos_bolt 487"; end
    end
    -- chaos_bolt,if=!variable.pool_soul_shards&talent.eradication.enabled&(debuff.eradication.remains<cast_time|buff.backdraft.up)
    if S.ChaosBolt:IsReady() and not bool(VarPoolSoulShards) and S.Eradication:IsAvailable() and (Target:DebuffRemains(S.EradicationDebuff) < S.ChaosBolt:CastTime() or Player:BuffUp(S.BackdraftBuff)) then
      if HR.Cast(S.ChaosBolt, nil, nil, 40) then return "chaos_bolt 493"; end
    end
    -- shadowburn,if=!variable.pool_soul_shards|soul_shard>=4.5
    if S.Shadowburn:IsReady() and (not bool(VarPoolSoulShards) or (Player:SoulShardsP() >= 4.5)) then
      if HR.Cast(S.Shadowburn, nil, nil, 40) then return "shadowburn 500"; end
    end
    -- chaos_bolt,if=(soul_shard>=4.5-0.2*active_enemies)
    if S.ChaosBolt:IsReady() and ((Player:SoulShardsP() >= 4.5 - 0.2 * Enemies40yCount)) then
      if HR.Cast(S.ChaosBolt, nil, nil, 40) then return "chaos_bolt 507"; end
    end
    -- conflagrate,if=charges>1
    if S.Conflagrate:IsReady() and (S.Conflagrate:Charges() > 1) then
      if HR.Cast(S.Conflagrate, nil, nil, 40) then return "conflagrate 515"; end
    end
    -- incinerate
    if S.Incinerate:IsReady() then
      if HR.Cast(S.Incinerate, nil, nil, 40) then return "incinerate 521"; end
    end
  end
end

local function Init()
end

HR.SetAPL(267, APL, Init)
