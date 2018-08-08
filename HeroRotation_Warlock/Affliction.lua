--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- HeroRotation
local HR     = HeroRotation

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.Warlock then Spell.Warlock = {} end
Spell.Warlock.Affliction = {
  SummonPet                             = Spell(691),
  GrimoireofSacrificeBuff               = Spell(196099),
  GrimoireofSacrifice                   = Spell(108503),
  SeedofCorruption                      = Spell(27243),
  HauntDebuff                           = Spell(48181),
  Haunt                                 = Spell(48181),
  ShadowBolt                            = Spell(232670),
  SummonDarkglare                       = Spell(205180),
  UnstableAffliction                    = Spell(30108),
  UnstableAfflictionDebuff              = Spell(30108),
  Agony                                 = Spell(980),
  Deathbolt                             = Spell(264106),
  SiphonLife                            = Spell(63106),
  AgonyDebuff                           = Spell(980),
  Fireblood                             = Spell(265221),
  BloodFury                             = Spell(20572),
  DrainSoul                             = Spell(198590),
  UnstableAffliction1Debuff             = Spell(233490),
  UnstableAffliction2Debuff             = Spell(233496),
  UnstableAffliction3Debuff             = Spell(233497),
  UnstableAffliction4Debuff             = Spell(233498),
  UnstableAffliction5Debuff             = Spell(233499),
  CorruptionDebuff                      = Spell(146739),
  DarkSoul                              = Spell(113860),
  SiphonLifeDebuff                      = Spell(63106),
  Corruption                            = Spell(172),
  PhantomSingularity                    = Spell(205179),
  VileTaint                             = Spell(278350),
  Berserking                            = Spell(26297),
  SowtheSeeds                           = Spell(196226)
};
local S = Spell.Warlock.Affliction;

-- Items
if not Item.Warlock then Item.Warlock = {} end
Item.Warlock.Affliction = {
  ProlongedPower                   = Item(142117)
};
local I = Item.Warlock.Affliction;

-- Rotation Var
local ShouldReturn; -- Used to get the return string

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
};

-- Variables

local EnemyRanges = {5, 40}
local function UpdateRanges()
  for _, i in ipairs(EnemyRanges) do
    HL.GetEnemies(i);
  end
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

HL.UnstableAfflictionDebuffsPrev = {
    [S.UnstableAffliction2Debuff] = S.UnstableAffliction1Debuff,
    [S.UnstableAffliction3Debuff] = S.UnstableAffliction2Debuff,
    [S.UnstableAffliction4Debuff] = S.UnstableAffliction3Debuff,
    [S.UnstableAffliction5Debuff] = S.UnstableAffliction4Debuff
  };

local function NbAffected (SpellAffected)
    local nbaff = 0
    for Key, Value in pairs(Cache.Enemies[EnemyRanges[2]]) do
      if Value:DebuffRemainsP(SpellAffected) > 0 then nbaff = nbaff + 1; end
    end
    return nbaff;
end

local function TimeToShard()
    local agony_count = NbAffected(S.Agony)
    if agony_count == 0 then
        return 10000 
    end
    return 1 / (0.16 / math.sqrt(agony_count) * (agony_count == 1 and 1.15 or 1) * agony_count / S.Agony:TickTime())
end
--- ======= ACTION LISTS =======
local function APL()
  local Precombat, Aoe, DgSoon, Fillers, Regular, Single
  UpdateRanges()
  Everyone.AoEToggleEnemiesUpdate()
  time_to_shard = TimeToShard()
  Precombat = function()
    -- flask
    -- food
    -- augmentation
    -- summon_pet
    if S.SummonPet:IsCastableP() and (true) then
      if HR.Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return ""; end
    end
    -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
    if S.GrimoireofSacrifice:IsCastableP() and Player:BuffDownP(S.GrimoireofSacrificeBuff) and (S.GrimoireofSacrifice:IsAvailable()) then
      if HR.Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireofSacrifice) then return ""; end
    end
    -- snapshot_stats
    -- potion
    if I.ProlongedPower:IsReady() and Settings.Commons.UsePotions and (true) then
      if HR.CastSuggested(I.ProlongedPower) then return ""; end
    end
    -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>=3
    if S.SeedofCorruption:IsCastableP() and (Cache.EnemiesCount[5] >= 3) then
      if HR.Cast(S.SeedofCorruption) then return ""; end
    end
    -- haunt
    if S.Haunt:IsCastableP() and Player:DebuffDownP(S.HauntDebuff) and (true) then
      if HR.Cast(S.Haunt) then return ""; end
    end
    -- shadow_bolt,if=!talent.haunt.enabled&spell_targets.seed_of_corruption_aoe<3
    if S.ShadowBolt:IsCastableP() and (not S.Haunt:IsAvailable() and Cache.EnemiesCount[5] < 3) then
      if HR.Cast(S.ShadowBolt) then return ""; end
    end
  end
  Aoe = function()
    -- call_action_list,name=dg_soon,if=(cooldown.summon_darkglare.remains<time_to_shard*(5-soul_shard)|cooldown.summon_darkglare.up)&time_to_die>cooldown.summon_darkglare.remains
    if ((S.SummonDarkglare:CooldownRemainsP() < time_to_shard * (5 - Player:SoulShardsP()) or S.SummonDarkglare:CooldownUpP()) and Target:TimeToDie() > S.SummonDarkglare:CooldownRemainsP()) then
      local ShouldReturn = DgSoon(); if ShouldReturn then return ShouldReturn; end
    end
    -- seed_of_corruption
    if S.SeedofCorruption:IsCastableP() and (true) then
      if HR.Cast(S.SeedofCorruption) then return ""; end
    end
    -- call_action_list,name=fillers
    if (true) then
      local ShouldReturn = Fillers(); if ShouldReturn then return ShouldReturn; end
    end
  end
  DgSoon = function()
    -- unstable_affliction,if=(cooldown.summon_darkglare.remains<=soul_shard*cast_time)
    if S.UnstableAffliction:IsReadyP() and ((S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.UnstableAffliction:CastTime())) then
      if HR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- agony,line_cd=30,if=talent.deathbolt.enabled&(!talent.siphon_life.enabled)&dot.agony.ticks_remain<=10&cooldown.deathbolt.remains<=gcd
    if S.Agony:IsCastableP() and (S.Deathbolt:IsAvailable() and (not S.SiphonLife:IsAvailable()) and Target:DebuffTicksRemainP(S.AgonyDebuff) <= 10 and S.Deathbolt:CooldownRemainsP() <= Player:GCD()) then
      if HR.Cast(S.Agony) then return ""; end
    end
    -- summon_darkglare
    if S.SummonDarkglare:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return ""; end
    end
    -- call_action_list,name=fillers
    if (true) then
      local ShouldReturn = Fillers(); if ShouldReturn then return ShouldReturn; end
    end
  end
  Fillers = function()
    -- fireblood
    if S.Fireblood:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- blood_fury
    if S.BloodFury:IsCastableP() and HR.CDsON() and (true) then
      if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
    end
    -- use_items
    -- deathbolt
    if S.Deathbolt:IsCastableP() and (true) then
      if HR.Cast(S.Deathbolt) then return ""; end
    end
    -- drain_soul,interrupt_global=1,chain=1,cycle_targets=1,if=target.time_to_die<=gcd
    if S.DrainSoul:IsCastableP() and (Target:TimeToDie() <= Player:GCD()) then
      if HR.Cast(S.DrainSoul) then return ""; end
    end
    -- drain_soul,interrupt_global=1,chain=1
    if S.DrainSoul:IsCastableP() and (true) then
      if HR.Cast(S.DrainSoul) then return ""; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastableP() and (true) then
      if HR.Cast(S.ShadowBolt) then return ""; end
    end
  end
  Regular = function()
    -- unstable_affliction,cycle_targets=1,if=((dot.unstable_affliction_1.remains+dot.unstable_affliction_2.remains+dot.unstable_affliction_3.remains+dot.unstable_affliction_4.remains+dot.unstable_affliction_5.remains)<=cast_time|soul_shard>=2)&target.time_to_die>4+cast_time
    if S.UnstableAffliction:IsReadyP() and (((Target:DebuffRemainsP(S.UnstableAffliction1Debuff) + Target:DebuffRemainsP(S.UnstableAffliction2Debuff) + Target:DebuffRemainsP(S.UnstableAffliction3Debuff) + Target:DebuffRemainsP(S.UnstableAffliction4Debuff) + Target:DebuffRemainsP(S.UnstableAffliction5Debuff)) <= S.UnstableAffliction:CastTime() or Player:SoulShardsP() >= 2) and Target:TimeToDie() > 4 + S.UnstableAffliction:CastTime()) then
      if HR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- agony,line_cd=30,if=talent.deathbolt.enabled&(!talent.siphon_life.enabled)&dot.agony.ticks_remain<=10&cooldown.deathbolt.remains<=gcd
    if S.Agony:IsCastableP() and (S.Deathbolt:IsAvailable() and (not S.SiphonLife:IsAvailable()) and Target:DebuffTicksRemainP(S.AgonyDebuff) <= 10 and S.Deathbolt:CooldownRemainsP() <= Player:GCD()) then
      if HR.Cast(S.Agony) then return ""; end
    end
    -- call_action_list,name=fillers
    if (true) then
      local ShouldReturn = Fillers(); if ShouldReturn then return ShouldReturn; end
    end
  end
  Single = function()
    -- unstable_affliction,if=soul_shard=5
    if S.UnstableAffliction:IsReadyP() and (Player:SoulShardsP() == 5) then
      if HR.Cast(S.UnstableAffliction) then return ""; end
    end
    -- call_action_list,name=dg_soon,if=(cooldown.summon_darkglare.remains<time_to_shard*(5-soul_shard)|cooldown.summon_darkglare.up)&time_to_die>cooldown.summon_darkglare.remains
    if ((S.SummonDarkglare:CooldownRemainsP() < time_to_shard * (5 - Player:SoulShardsP()) or S.SummonDarkglare:CooldownUpP()) and Target:TimeToDie() > S.SummonDarkglare:CooldownRemainsP()) then
      local ShouldReturn = DgSoon(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=regular,if=!((cooldown.summon_darkglare.remains<time_to_shard*(5-soul_shard)|time_to_die>cooldown.summon_darkglare.remains)&cooldown.summon_darkglare.up)
    if (not ((S.SummonDarkglare:CooldownRemainsP() < time_to_shard * (5 - Player:SoulShardsP()) or Target:TimeToDie() > S.SummonDarkglare:CooldownRemainsP()) and S.SummonDarkglare:CooldownUpP())) then
      local ShouldReturn = Regular(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- haunt
  if S.Haunt:IsCastableP() and (true) then
    if HR.Cast(S.Haunt) then return ""; end
  end
  -- summon_darkglare,if=dot.agony.ticking&dot.corruption.ticking&dot.unstable_affliction_1.ticking&dot.unstable_affliction_2.ticking&dot.unstable_affliction_3.ticking&((dot.unstable_affliction_4.ticking&dot.unstable_affliction_5.ticking)|soul_shard=0)
  if S.SummonDarkglare:IsCastableP() and HR.CDsON() and (Target:DebuffP(S.AgonyDebuff) and Target:DebuffP(S.CorruptionDebuff) and Target:DebuffP(S.UnstableAffliction1Debuff) and Target:DebuffP(S.UnstableAffliction2Debuff) and Target:DebuffP(S.UnstableAffliction3Debuff) and ((Target:DebuffP(S.UnstableAffliction4Debuff) and Target:DebuffP(S.UnstableAffliction5Debuff)) or Player:SoulShardsP() == 0)) then
    if HR.Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return ""; end
  end
  -- agony,cycle_targets=1,max_cycle_targets=5,if=remains<=gcd&active_enemies<=7
  if S.Agony:IsCastableP() and (Target:DebuffRemainsP(S.AgonyDebuff) <= Player:GCD() and Cache.EnemiesCount[40] <= 7) then
    if HR.Cast(S.Agony) then return ""; end
  end
  -- agony,cycle_targets=1,max_cycle_targets=5,if=refreshable&target.time_to_die>10&(!(cooldown.summon_darkglare.remains<=soul_shard*cast_time)|active_enemies<2)&active_enemies<=7
  if S.Agony:IsCastableP() and (Target:DebuffRefreshableCP(S.AgonyDebuff) and Target:TimeToDie() > 10 and (not (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.Agony:CastTime()) or Cache.EnemiesCount[40] < 2) and Cache.EnemiesCount[40] <= 7) then
    if HR.Cast(S.Agony) then return ""; end
  end
  -- agony,cycle_targets=1,max_cycle_targets=4,if=remains<=gcd&active_enemies>7
  if S.Agony:IsCastableP() and (Target:DebuffRemainsP(S.AgonyDebuff) <= Player:GCD() and Cache.EnemiesCount[40] > 7) then
    if HR.Cast(S.Agony) then return ""; end
  end
  -- agony,cycle_targets=1,max_cycle_targets=4,if=refreshable&target.time_to_die>10&(!(cooldown.summon_darkglare.remains<=soul_shard*cast_time)|active_enemies<2)&active_enemies>7
  if S.Agony:IsCastableP() and (Target:DebuffRefreshableCP(S.AgonyDebuff) and Target:TimeToDie() > 10 and (not (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.Agony:CastTime()) or Cache.EnemiesCount[40] < 2) and Cache.EnemiesCount[40] > 7) then
    if HR.Cast(S.Agony) then return ""; end
  end
  -- dark_soul
  if S.DarkSoul:IsCastableP() and HR.CDsON() and (true) then
    if HR.Cast(S.DarkSoul, Settings.Affliction.GCDasOffGCD.DarkSoul) then return ""; end
  end
  -- siphon_life,cycle_targets=1,max_cycle_targets=1,if=refreshable&target.time_to_die>10&((!(cooldown.summon_darkglare.remains<=soul_shard*cast_time)&active_enemies>4)|active_enemies<2)
  if S.SiphonLife:IsCastableP() and (Target:DebuffRefreshableCP(S.SiphonLifeDebuff) and Target:TimeToDie() > 10 and ((not (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.SiphonLife:CastTime()) and Cache.EnemiesCount[40] > 4) or Cache.EnemiesCount[40] < 2)) then
    if HR.Cast(S.SiphonLife) then return ""; end
  end
  -- siphon_life,cycle_targets=1,max_cycle_targets=2,if=refreshable&target.time_to_die>10&!(cooldown.summon_darkglare.remains<=soul_shard*cast_time)&active_enemies=2
  if S.SiphonLife:IsCastableP() and (Target:DebuffRefreshableCP(S.SiphonLifeDebuff) and Target:TimeToDie() > 10 and not (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.SiphonLife:CastTime()) and Cache.EnemiesCount[40] == 2) then
    if HR.Cast(S.SiphonLife) then return ""; end
  end
  -- siphon_life,cycle_targets=1,max_cycle_targets=3,if=refreshable&target.time_to_die>10&!(cooldown.summon_darkglare.remains<=soul_shard*cast_time)&active_enemies=3
  if S.SiphonLife:IsCastableP() and (Target:DebuffRefreshableCP(S.SiphonLifeDebuff) and Target:TimeToDie() > 10 and not (S.SummonDarkglare:CooldownRemainsP() <= Player:SoulShardsP() * S.SiphonLife:CastTime()) and Cache.EnemiesCount[40] == 3) then
    if HR.Cast(S.SiphonLife) then return ""; end
  end
  -- corruption,cycle_targets=1,if=active_enemies<3&refreshable&target.time_to_die>10
  if S.Corruption:IsCastableP() and (Cache.EnemiesCount[40] < 3 and Target:DebuffRefreshableCP(S.CorruptionDebuff) and Target:TimeToDie() > 10) then
    if HR.Cast(S.Corruption) then return ""; end
  end
  -- seed_of_corruption,line_cd=10,if=dot.corruption.ticks_remain<=2&spell_targets.seed_of_corruption_aoe>=3
  if S.SeedofCorruption:IsCastableP() and (Target:DebuffTicksRemainP(S.CorruptionDebuff) <= 2 and Cache.EnemiesCount[5] >= 3) then
    if HR.Cast(S.SeedofCorruption) then return ""; end
  end
  -- phantom_singularity
  if S.PhantomSingularity:IsCastableP() and (true) then
    if HR.Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity) then return ""; end
  end
  -- vile_taint
  if S.VileTaint:IsCastableP() and (true) then
    if HR.Cast(S.VileTaint) then return ""; end
  end
  -- berserking
  if S.Berserking:IsCastableP() and HR.CDsON() and (true) then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return ""; end
  end
  -- call_action_list,name=aoe,if=talent.sow_the_seeds.enabled&spell_targets.seed_of_corruption_aoe>=3
  if (S.SowtheSeeds:IsAvailable() and Cache.EnemiesCount[5] >= 3) then
    local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=single
  if (true) then
    local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
  end
end

HR.SetAPL(265, APL)
