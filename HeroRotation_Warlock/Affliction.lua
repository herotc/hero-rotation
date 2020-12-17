--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Pet = Unit.Pet
local Target = Unit.Target
local Spell = HL.Spell
local MultiSpell = HL.MultiSpell
local Item = HL.Item
-- HeroRotation
local HR = HeroRotation
local AoEON = HR.AoEON
local CDsON = HR.CDsON
local Cast  = HR.Cast
-- Lua


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Warlock = HR.Commons.Warlock

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

-- Spells
local S = Spell.Warlock.Affliction

-- Items
local I = Item.Warlock.Affliction
local TrinketsOnUseExcludes = {--  I.TrinketName:ID(),
}

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()



-- Enemies
local Enemies40y, Enemies40yCount, EnemiesCount10ySplash, EnemiesCount

local EnemiesAgonyCount, EnemiesSeedofCorruptionCount, EnemiesSiphonLifeCount, EnemiesVileTaintCount = 0, 0, 0, 0
local EnemiesWithUnstableAfflictionDebuff

-- Stuns

-- Rotation Variables

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCycleAgony(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgony1(TargetUnit)
  --refreshable&dot.agony.ticking
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and TargetUnit:DebuffUp(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLife1(TargetUnit)
  -- !dot.siphon_life.ticking
  return (not TargetUnit:DebuffUp(S.SiphonLifeDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgony2(TargetUnit)
  --refreshable&dot.agony.ticking
  return (not TargetUnit:DebuffUp(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLife(TargetUnit)
  --dot.siphon_life.remains<3
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 3) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruption(TargetUnit)
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 3) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleSeedofCorruption(TargetUnit)
  return (not TargetUnit:DebuffUp(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight()) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleUnstableAffliction(TargetUnit)
  return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRefreshable(S.UnstableAfflictionDebuff)) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

-- Counter for Debuff on other enemies
local function calcEnemiesDotCount(Object, Enemies)
  local debuffs = 0

  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffUp(Object) then
      debuffs = debuffs + 1
    end
  end

  return debuffs
end

local function returnEnemiesWithDot(Object, Enemies)
  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffUp(Object) then
      if Object == S.UnstableAfflictionDebuff then
        return CycleUnit:GUID()
      end
    end
  end
  return 0
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet
  if S.SummonPet:IsReady() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet precombat"; end
  end
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() and Player:BuffDown(S.GrimoireofSacrificeBuff) then
    if Cast(S.GrimoireofSacrifice) then return "GrimoureOfSacrifice precombat"; end
  end
  -- snapshot_stats
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>=3
  if S.SeedofCorruption:IsReady() and (EnemiesCount10ySplash >= 3 or Enemies40yCount >= 3) and Player:SoulShardsP() > 0 then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption precombat"; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt precombat"; end
  end
  -- shadow_bolt,if=!talent.haunt.enabled&spell_targets.seed_of_corruption_aoe<3
  if S.ShadowBolt:IsReady() and not S.Haunt:IsAvailable() and EnemiesCount10ySplash < 3 then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt precombat"; end
  end
  -- Custom precombat Agony with talents 3,3,1,1,1,1,3
  if S.Agony:IsReady() then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony precombat"; end
  end
end

local function Darkglare_prep()
  -- vile_taint
  if S.VileTaint:IsReady() then
    if Cast(S.VileTaint) then return "VileTaint Darkglare_prep"; end
  end
  -- dark_soul
  if S.DarkSoulMisery:IsReady() then
    if Cast(S.DarkSoulMisery) then return "DarkSoulMisery Darkglare_prep"; end
  end
  -- potion TODO
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood) then return "Fireblood Darkglare_prep"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury) then return "BloodFury Darkglare_prep"; end
  end
  -- berserking
  if S.Berserking:IsCastable() then
    if Cast(S.Berserking) then return "Berserking Darkglare_prep"; end
  end
  -- summon_darkglare
  if S.SummonDarkglare:IsReady() then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "SummonDarkglare Darkglare_prep"; end
  end
end

local function ItemFunc()
  -- use_items
  if (Settings.Commons.Enabled.Trinkets) then
    local TrinketToUse = Player:GetUseableTrinkets(TrinketsOnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Se()
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt Se"; end
  end
  -- drain_soul,interrupt_if=debuff.shadow_embrace.stack>=3 TODO
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt Se"; end
  end
end

local function Aoe()
  -- phantom_singularity
  if S.PhantomSingularity:IsReady() then
    if Cast(S.PhantomSingularity, nil, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity Aoe"; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt Aoe"; end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds.enabled&can_seed
  if S.SeedofCorruption:IsReady() and (S.SowtheSeeds:IsAvailable() and (EnemiesSeedofCorruptionCount <= (EnemiesCount10ySplash < 3 and EnemiesCount10ySplash or 3))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 1"; end
  end
  -- seed_of_corruption,if=!talent.sow_the_seeds.enabled&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
  if S.SeedofCorruption:IsReady() and (not S.SowtheSeeds:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff)) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 2"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony>=4,target_if=refreshable&dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount >= 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony1, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 1"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony<4,target_if=!dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount < 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony2, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 2"; end
  end
  -- unstable_affliction,if=dot.unstable_affliction.refreshable
  if S.UnstableAffliction:IsReady()  then
    if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAffliction, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction Aoe"; end
  end
  -- vile_taint,if=soul_shard>1
  if S.VileTaint:IsReady() and (Player:SoulShardsP() > 1) then
    if Cast(S.VileTaint) then return "VileTaint Aoe"; end
  end
  -- call_action_list,name=darkglare_prep,if=cooldown.summon_darkglare.ready&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
  if S.SummonDarkglare:IsReady() and CDsON() and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable()) then
    local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
  end
  -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
  if S.DarkSoulMisery:IsReady() and CDsON() and (S.SummonDarkglare:CooldownRemains() > Target:TimeToDie()) then
    if Cast(S.DarkSoulMisery) then return "DarkSoulMisery Aoe"; end
  end
  -- call_action_list,name=cooldowns
  --local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
  -- call_action_list,name=item
  local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
  -- malefic_rapture,if=dot.vile_taint.ticking
  if S.MaleficRapture:IsReady() and (EnemiesVileTaintCount >= 1) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 1"; end
  end
  -- malefic_rapture,if=!talent.vile_taint.enabled
  if S.MaleficRapture:IsReady() and (not S.VileTaint:IsAvailable()) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 1"; end
  end
  -- siphon_life,cycle_targets=1,if=active_dot.siphon_life<=3,target_if=!dot.siphon_life.ticking
  if S.SiphonLife:IsReady() and (EnemiesSiphonLifeCount <= 3) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife1, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife Aoe"; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>=50|buff.inevitable_demise.up&time_to_die<5
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InvetiableDemiseBuff) >= 50 or Player:BuffUp(S.InvetiableDemiseBuff) and Target:TimeToDie() < 5) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife Aoe"; end
  end
  -- drain_soul
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "DrainSoul Aoe"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt Aoe"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  if AoEON() then
    Enemies40yCount = #Enemies40y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

    EnemiesAgonyCount = calcEnemiesDotCount(S.AgonyDebuff, Enemies40y)
    EnemiesSeedofCorruptionCount = calcEnemiesDotCount(S.SeedofCorruptionDebuff, Enemies40y)
    EnemiesSiphonLifeCount = calcEnemiesDotCount(S.SiphonLifeDebuff, Enemies40y)
    EnemiesVileTaintCount = calcEnemiesDotCount(S.VileTaintDebuff, Enemies40y)
  else
    Enemies40yCount = 1
    EnemiesCount10ySplash = 1

  end
  EnemiesWithUnstableAfflictionDebuff = returnEnemiesWithDot(S.UnstableAfflictionDebuff, Enemies40y)

  -- +In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>3
    if EnemiesCount10ySplash > 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- phantom_singularity
    if S.PhantomSingularity:IsReady() then
      if Cast(S.PhantomSingularity, nil, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity InCombat"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsReady() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat"; end
    end
    -- agony,cycle_targets=1,if=active_enemies>1,target_if=refreshable
    if S.Agony:IsReady() and Enemies40yCount > 1 then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat"; end
    end
    -- call_action_list,name=darkglare_prep,if=active_enemies>2&cooldown.summon_darkglare.ready&(dot.phantom_singularity.ticking|!talent.phantom_singularity.enabled)
    if S.SummonDarkglare:IsReady() and CDsON() and (Enemies40yCount > 2 and (Target:DebuffUp(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- seed_of_corruption,if=active_enemies>2&!talent.vile_taint.enabled&(!talent.writhe_in_agony.enabled|talent.sow_the_seeds.enabled)&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
    if S.SeedofCorruption:IsReady() and (Enemies40yCount > 2 and not S.VileTaint:IsAvailable() and (not S.WritheinAgony:IsAvailable() or S.SowtheSeeds:IsAvailable()) and EnemiesSeedofCorruptionCount < 1 and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption InCombat"; end
    end
    -- vile_taint,if=(soul_shard>1|active_enemies>2)&cooldown.summon_darkglare.remains>12
    if S.VileTaint:IsReady() and ((Player:SoulShardsP() > 1 or Enemies40yCount > 2) and S.SummonDarkglare:CooldownRemains() > 12) then
      if Cast(S.VileTaint) then return "VileTaint InCombat"; end
    end
    -- siphon_life,if=refreshable
    if S.SiphonLife:IsReady() and (Target:DebuffRefreshable(S.SiphonLifeDebuff)) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat"; end
    end
    -- unstable_affliction,if=refreshable
    if S.UnstableAffliction:IsReady() and not Player:IsCasting(S.UnstableAffliction) then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAffliction, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction InCombat 1"; end
    end
    -- corruption,if=(active_enemies<3|talent.vile_taint.enabled|talent.writhe_in_agony.enabled&!talent.sow_the_seeds.enabled)&refreshable
    if S.Corruption:IsReady() and ((EnemiesCount10ySplash < 3 or S.VileTaint:IsAvailable() or S.WritheinAgony:IsAvailable() and not S.SowtheSeeds:IsAvailable()) and Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 1"; end
    end
    -- haunt
    if S.Haunt:IsReady() then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt InCombat"; end
    end
    -- malefic_rapture,if=soul_shard>4
    if S.MaleficRapture:IsReady() and (Player:SoulShardsP() > 4) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 1"; end
    end
    -- siphon_life,cycle_targets=1,if=active_enemies>1,target_if=dot.siphon_life.remains<3
    if S.SiphonLife:IsReady() then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat"; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<3|talent.vile_taint.enabled|talent.writhe_in_agony.enabled&!talent.sow_the_seeds.enabled,target_if=dot.corruption.remains<3
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 3 or S.VileTaint:IsAvailable() or S.WritheinAgony:IsAvailable() and not S.SowtheSeeds:IsAvailable()) then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruption, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 2"; end
    end
    -- call_action_list,name=darkglare_prep,if=cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if CDsON() and (S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
    if S.DarkSoulMisery:IsReady() and CDsON() and (S.SummonDarkglare:CooldownRemains() > Target:TimeToDie()) then
      if Cast(S.DarkSoulMisery) then return "DarkSoulMisery InCombat"; end
    end
    -- call_action_list,name=item TODO
    local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=se,if=debuff.shadow_embrace.stack<(3-action.shadow_bolt.in_flight)|debuff.shadow_embrace.remains<3
    if S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < (3 - num(S.ShadowBolt:InFlight())) or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3) then
      local ShouldReturn = Se(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=dot.vile_taint.ticking
    if S.MaleficRapture:IsReady() and (Target:DebuffUp(S.VileTaintDebuff)) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 2"; end
    end
    -- malefic_rapture,if=talent.phantom_singularity.enabled&(dot.phantom_singularity.ticking||cooldown.phantom_singularity.remains>12||soul_shard>3)
    if S.MaleficRapture:IsReady() and (S.PhantomSingularity:IsAvailable() and (Target:DebuffUp(S.PhantomSingularityDebuff) or S.PhantomSingularity:CooldownRemains() > 12 or Player:SoulShardsP() > 3)) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 3"; end
    end
    -- malefic_rapture,if=talent.sow_the_seeds.enabled
    if S.MaleficRapture:IsReady() and (S.SowtheSeeds:IsAvailable()) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 4"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>30|buff.inevitable_demise.up&time_to_die<5
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InvetiableDemiseBuff) > 30 or Player:BuffUp(S.InvetiableDemiseBuff) and Target:TimeToDie() < 5) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife InCombat"; end
    end
    -- drain_life,if=buff.inevitable_demise_az.stack>30 TODO
    -- drain_soul
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "DrainSoul InCombat"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt InCombat"; end
    end

    return
  end
end

local function OnInit()

end

HR.SetAPL(265, APL, OnInit)
