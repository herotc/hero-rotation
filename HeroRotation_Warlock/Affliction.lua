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
  S.ConcentratedFlame:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ConcentratedFlame:RegisterInFlight()
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
  --refreshable&dot.agony.ticking
  return (TargetUnit:DebuffRefreshable(S.Agony) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgony1(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.Agony) and TargetUnit:DebuffUp(S.Agony) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLife1(TargetUnit)
  -- !dot.siphon_life.ticking
  return (not TargetUnit:DebuffUp(S.SiphonLife) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgony2(TargetUnit)
  --refreshable&dot.agony.ticking
  return (not TargetUnit:DebuffUp(S.Agony) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLife(TargetUnit)
  --dot.siphon_life.remains<3
  return (TargetUnit:DebuffRemains(S.SiphonLife) < 3) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruption(TargetUnit)
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 3) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleSeedofCorruption(TargetUnit)
  return (not TargetUnit:DebuffUp(S.SeedofCorruption) and not S.SeedofCorruption:InFlight()) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleUnstableAffliction(TargetUnit)
  return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRefreshable(S.UnstableAffliction)) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
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
      if Object == S.UnstableAffliction then
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
  if S.SummonPet:IsCastable() then
    if HR.Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet precombat"; end
  end
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() and Player:BuffDown(S.GrimoireofSacrificeBuff) then
    if HR.Cast(S.GrimoireofSacrifice) then return "GrimoureOfSacrifice precombat"; end
  end
  -- snapshot_stats
  -- use_item,name=azsharas_font_of_power
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>=3&!equipped.169314
  if S.SeedofCorruption:IsCastable() and (EnemiesCount10ySplash >= 3 or Enemies40yCount >= 3) and Player:SoulShardsP() > 0 then
    if HR.Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption precombat"; end
  end
  -- haunt
  if S.Haunt:IsCastable() and not Player:IsCasting(S.Haunt) and S.Haunt:IsAvailable() then
    if HR.Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt precombat"; end
  end
  -- shadow_bolt,if=!talent.haunt.enabled&spell_targets.seed_of_corruption_aoe<3&!equipped.169314 TODO
  if S.ShadowBolt:IsCastable() and not S.Haunt:IsAvailable() and EnemiesCount10ySplash < 3 then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt precombat"; end
  end
  -- Custom precombat Agony with talents 3,3,1,1,1,1,3
  if S.Agony:IsCastable() then
    if HR.Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony precombat"; end
  end
end

local function Darkglare_prep()
  --actions.darkglare_prep=vile_taint
  if S.VileTaint:IsCastable() and S.VileTaint:IsAvailable() then
    if HR.Cast(S.VileTaint) then return "VileTaint Darkglare_prep"; end
  end
  --actions.darkglare_prep+=/dark_soul
  if S.DarkSoulMisery:IsCastable() and S.DarkSoulMisery:IsAvailable() then
    if HR.Cast(S.DarkSoulMisery) then return "DarkSoulMisery Darkglare_prep"; end
  end
  --actions.darkglare_prep+=/potion TODO
  --actions.darkglare_prep+=/fireblood
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood) then return "Fireblood Darkglare_prep"; end
  end
  --actions.darkglare_prep+=/blood_fury
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury) then return "BloodFury Darkglare_prep"; end
  end
  --actions.darkglare_prep+=/berserking
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking) then return "Berserking Darkglare_prep"; end
  end
  --actions.darkglare_prep+=/summon_darkglare
  if S.SummonDarkglare:IsCastable() then
    if HR.Cast(S.SummonDarkglare) then return "SummonDarkglare Darkglare_prep"; end
  end
end

local function Cooldowns()

  if CDsON() then
    --actions.cooldowns=worldvein_resonance
    if S.WorldveinResonance:IsCastable() then
      if HR.Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance"; end
    end
    --actions.cooldowns+=/memory_of_lucid_dreams
    if S.MemoryofLucidDreams:IsCastable() then
      if HR.Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams"; end
    end
    --actions.cooldowns+=/blood_of_the_enemy
    if S.BloodoftheEnemy:IsCastable() then
      if HR.Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle) then return "blood_of_the_enemy"; end
    end
    --actions.cooldowns+=/guardian_of_azeroth
    if S.GuardianofAzeroth:IsCastable() then
      if HR.Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth"; end
    end
    --actions.cooldowns+=/ripple_in_space
    if S.RippleInSpace:IsCastable() then
      if HR.Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space"; end
    end
    --actions.cooldowns+=/focused_azerite_beam
    if S.FocusedAzeriteBeam:IsCastable() then
      if HR.Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam"; end
    end
    --actions.cooldowns+=/purifying_blast
    if S.PurifyingBlast:IsCastable() then
      if HR.Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle) then return "purifying_blast"; end
    end
    --actions.cooldowns+=/reaping_flames
    if S.ReapingFlames:IsCastable() then
      local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
    end
    --actions.cooldowns+=/concentrated_flame
    if S.ConcentratedFlame:IsCastable() then
      if HR.Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle) then return "concentrated_flame"; end
    end
    --actions.cooldowns+=/the_unbound_force,if=buff.reckless_force.remains
    if S.TheUnboundForce:IsCastable() and (Player:BuffUp(S.RecklessForceBuff)) then
      if HR.Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force"; end
    end
  end
end

local function Se()
  --actions.se=haunt
  if S.Haunt:IsCastable() and not Player:IsCasting(S.Haunt) and S.Haunt:IsAvailable() then
    if HR.Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt Se"; end
  end
  --actions.se+=/drain_soul,interrupt_if=debuff.shadow_embrace.stack>=3 TODO
  --actions.se+=/shadow_bolt
  if S.ShadowBolt:IsCastable() and S.ShadowBolt:IsAvailable() then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt Se"; end
  end
end

local function Aoe()
  --actions.aoe=phantom_singularity
  if S.PhantomSingularity:IsCastable() and S.PhantomSingularity:IsAvailable() then
    if HR.Cast(S.PhantomSingularity, nil, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity Aoe"; end
  end
  --actions.aoe+=/haunt
  if S.Haunt:IsCastable() and not Player:IsCasting(S.Haunt) and S.Haunt:IsAvailable() then
    if HR.Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt Aoe"; end
  end
  --actions.aoe+=/seed_of_corruption,if=talent.sow_the_seeds.enabled&can_seed TODO
  if S.SeedofCorruption:IsCastable() and S.SowTheSeeds:IsAvailable() and Player:SoulShardsP() > 0 and (EnemiesSeedofCorruptionCount <= EnemiesCount10ySplash) then
    if HR.Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 1"; end
  end
  --actions.aoe+=/seed_of_corruption,if=!talent.sow_the_seeds.enabled&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
  if S.SeedofCorruption:IsCastable() and EnemiesSeedofCorruptionCount < 1 and (not S.SowTheSeeds:IsAvailable() and not Target:DebuffUp(S.SeedofCorruption) and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff)) and Player:SoulShardsP() > 0 then
    if HR.Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 2"; end
  end
  --actions.aoe+=/agony,cycle_targets=1,if=active_dot.agony>=4,target_if=refreshable&dot.agony.ticking
  if S.Agony:IsCastable() and EnemiesAgonyCount >= 4 then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony1, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 1"; end
  end
  --actions.aoe+=/agony,cycle_targets=1,if=active_dot.agony<4,target_if=!dot.agony.ticking
  if S.Agony:IsCastable() and EnemiesAgonyCount < 4 then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony2, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 2"; end
  end
  --actions.aoe+=/unstable_affliction,if=dot.unstable_affliction.refreshable
  if S.UnstableAffliction:IsCastable()  then
    if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAffliction, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction Aoe"; end
  end
  --actions.aoe+=/vile_taint,if=soul_shard>1
  if S.VileTaint:IsCastable() and S.VileTaint:IsAvailable() and Player:SoulShardsP() > 1 then
    if HR.Cast(S.VileTaint) then return "VileTaint Aoe"; end
  end
  --actions.aoe+=/call_action_list,name=darkglare_prep,if=cooldown.summon_darkglare.ready&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
  if S.SummonDarkglare:IsReady() and CDsON() and (Target:DebuffRemains(S.PhantomSingularity) > 2 or not S.PhantomSingularity:IsAvailable()) then
    local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
  end
  --actions.aoe+=/dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
  if S.DarkSoulMisery:IsCastable() and CDsON() and S.DarkSoulMisery:IsAvailable() and S.SummonDarkglare:CooldownRemains() > Target:TimeToDie() then
    if HR.Cast(S.DarkSoulMisery) then return "DarkSoulMisery Aoe"; end
  end
  --actions.aoe+=/call_action_list,name=cooldowns
  local cooldowns = Cooldowns(); if cooldowns then return cooldowns; end
  --actions.aoe+=/call_action_list,name=item
  --actions.aoe+=/malefic_rapture,if=dot.vile_taint.ticking
  if S.MaleficRapture:IsCastable() and S.VileTaint:IsAvailable() and EnemiesVileTaintCount >= 1 and Player:SoulShardsP() > 0 then
    if HR.Cast(S.MaleficRapture) then return "MaleficRapture Aoe 1"; end
  end
  --actions.aoe+=/malefic_rapture,if=!talent.vile_taint.enabled
  if S.MaleficRapture:IsCastable() and not S.VileTaint:IsAvailable() and Player:SoulShardsP() > 0 then
    if HR.Cast(S.MaleficRapture) then return "MaleficRapture Aoe 1"; end
  end
  --actions.aoe+=/siphon_life,cycle_targets=1,if=active_dot.siphon_life<=3,target_if=!dot.siphon_life.ticking
  if S.SiphonLife:IsCastable() and S.SiphonLife:IsAvailable() and EnemiesSiphonLifeCount <= 3 then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife1, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife Aoe"; end
  end
  --actions.aoe+=/drain_life,if=buff.inevitable_demise.stack>=50|buff.inevitable_demise.up&time_to_die<5
  if S.DrainLife:IsCastable() and (Player:BuffStack(S.InvetiableDemiseBuff) >= 50 or Player:BuffUp(S.InvetiableDemiseBuff)) and Target:TimeToDie() < 5 then
    if HR.Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife Aoe"; end
  end
  --actions.aoe+=/drain_soul
  if S.DrainSoul:IsCastable() and S.DrainSoul:IsAvailable() then
    if HR.Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "DrainSoul Aoe"; end
  end
  --actions.aoe+=/shadow_bolt
  if S.ShadowBolt:IsCastable() and S.ShadowBolt:IsAvailable() then
    if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt Aoe"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  if AoEON() then
    Enemies40yCount = #Enemies40y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

    EnemiesAgonyCount = calcEnemiesDotCount(S.Agony, Enemies40y)
    EnemiesSeedofCorruptionCount = calcEnemiesDotCount(S.SeedofCorruption, Enemies40y)
    EnemiesSiphonLifeCount = calcEnemiesDotCount(S.SiphonLife, Enemies40y)
    EnemiesVileTaintCount = calcEnemiesDotCount(S.VileTaint, Enemies40y)
  else
    Enemies40yCount = 1
    EnemiesCount10ySplash = 1

  end
  EnemiesWithUnstableAfflictionDebuff = returnEnemiesWithDot(S.UnstableAffliction, Enemies40y)

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
      if HR.Cast(S.PhantomSingularity, nil, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity InCombat"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsReady() and (Target:DebuffRefreshable(S.Agony)) then
      if HR.Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat"; end
    end
    -- agony,cycle_targets=1,if=active_enemies>1,target_if=refreshable
    if S.Agony:IsCastable() and Enemies40yCount > 1 then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgony, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat"; end
    end
    -- call_action_list,name=darkglare_prep,if=active_enemies>2&cooldown.summon_darkglare.ready&(dot.phantom_singularity.ticking|!talent.phantom_singularity.enabled)
    if S.SummonDarkglare:IsReady() and CDsON() and Enemies40yCount > 2 and (Target:DebuffUp(S.PhantomSingularity) or not S.PhantomSingularity:IsAvailable()) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- seed_of_corruption,if=active_enemies>2&!talent.vile_taint.enabled&(!talent.writhe_in_agony.enabled|talent.sow_the_seeds.enabled)&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
    if S.SeedofCorruption:IsCastable() and not Player:IsCasting(S.SeedofCorruption) and Enemies40yCount > 2 and not S.VileTaint:IsAvailable() and (not S.WritheInAgony:IsAvailable() or S.SowTheSeeds:IsAvailable()) and EnemiesSeedofCorruptionCount < 1 and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff) and Player:SoulShardsP() > 0 then
      if HR.Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption InCombat"; end
    end
    -- vile_taint,if=(soul_shard>1|active_enemies>2)&cooldown.summon_darkglare.remains>12
    if S.VileTaint:IsCastable() and S.VileTaint:IsAvailable() and (Player:SoulShardsP() > 1 or Enemies40yCount > 2) and S.SummonDarkglare:CooldownRemains() > 12 then
      if HR.Cast(S.VileTaint) then return "VileTaint InCombat"; end
    end
    -- siphon_life,if=refreshable
    if S.SiphonLife:IsCastable() and S.SiphonLife:IsAvailable() and Target:DebuffRefreshable(S.SiphonLife) then
      if HR.Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat"; end
    end
    -- unstable_affliction,if=refreshable
    if S.UnstableAffliction:IsCastable() and not Player:IsCasting(S.UnstableAffliction) then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAffliction, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction InCombat 1"; end
    end
    -- unstable_affliction,if=azerite.cascading_calamity.enabled&buff.cascading_calamity.remains<3 TODO
    if S.UnstableAffliction:IsCastable() and Player:BuffUp(S.CascadingCalamityBuff) and Player:BuffRemains(S.CascadingCalamityBuff) < 3 then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAffliction, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction InCombat 2"; end
    end
    -- corruption,if=(active_enemies<3|talent.vile_taint.enabled|talent.writhe_in_agony.enabled&!talent.sow_the_seeds.enabled)&refreshable
    if S.Corruption:IsCastable() and (Target:AffectingCombat() or Target:IsDummy()) and (Enemies40yCount < 3 or S.VileTaint:IsAvailable() or S.WritheInAgony:IsAvailable() and not S.SowTheSeeds:IsAvailable()) and Target:DebuffRefreshable(S.CorruptionDebuff) then
      if HR.Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 1"; end
    end
    -- haunt
    if S.Haunt:IsCastable() and not Player:IsCasting(S.Haunt) and S.Haunt:IsAvailable() then
      if HR.Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt InCombat"; end
    end
    -- malefic_rapture,if=soul_shard>4
    if S.MaleficRapture:IsCastable() and Player:SoulShardsP() > 4 then
      if HR.Cast(S.MaleficRapture) then return "MaleficRapture InCombat 1"; end
    end
    -- siphon_life,cycle_targets=1,if=active_enemies>1,target_if=dot.siphon_life.remains<3
    if S.SiphonLife:IsCastable() and S.SiphonLife:IsAvailable() then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat"; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<3|talent.vile_taint.enabled|talent.writhe_in_agony.enabled&!talent.sow_the_seeds.enabled,target_if=dot.corruption.remains<3
    if S.Corruption:IsCastable() and Enemies40yCount < 3 or S.VileTaint:IsAvailable() or S.WritheInAgony:IsAvailable() and not S.SowTheSeeds:IsAvailable() then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruption, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 2"; end
    end
    -- call_action_list,name=darkglare_prep,if=cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if S.SummonDarkglare:CooldownRemains() < 2 and CDsON() and (Target:DebuffRemains(S.PhantomSingularity) or not S.PhantomSingularity:IsAvailable()) then
      local darkglare_prep = Darkglare_prep(); if darkglare_prep then return darkglare_prep; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
    if S.DarkSoulMisery:IsCastable() and CDsON() and S.DarkSoulMisery:IsAvailable() and S.SummonDarkglare:CooldownRemains() > Target:TimeToDie() then
      if HR.Cast(S.DarkSoulMisery) then return "DarkSoulMisery InCombat"; end
    end
    -- call_action_list,name=cooldowns
    local cooldowns = Cooldowns(); if cooldowns then return cooldowns; end
    -- call_action_list,name=item TODO
    -- call_action_list,name=se,if=debuff.shadow_embrace.stack<(3-action.shadow_bolt.in_flight)|debuff.shadow_embrace.remains<3
    if S.ShadowEmbrace:IsAvailable() and Target:DebuffStack(S.ShadowEmbrace) < (3 - num(S.ShadowBolt:InFlight()) or Target:DebuffRemains(S.ShadowEmbrace) < 3) then
      local se = Se(); if se then return se; end
    end
    -- malefic_rapture,if=dot.vile_taint.ticking
    if S.MaleficRapture:IsCastable() and S.VileTaint:IsAvailable() and Target:DebuffUp(S.VileTaint) and Player:SoulShardsP() > 0 then
      if HR.Cast(S.MaleficRapture) then return "MaleficRapture InCombat 2"; end
    end
    -- malefic_rapture,if=talent.phantom_singularity.enabled&(dot.phantom_singularity.ticking||cooldown.phantom_singularity.remains>12||soul_shard>3)
    if S.MaleficRapture:IsCastable() and S.PhantomSingularity:IsAvailable() and (Target:DebuffUp(S.PhantomSingularity) or S.PhantomSingularity:CooldownRemains() > 12 or Player:SoulShardsP() > 3) and Player:SoulShardsP() > 0 then
      if HR.Cast(S.MaleficRapture) then return "MaleficRapture InCombat 3"; end
    end
    -- malefic_rapture,if=talent.sow_the_seeds.enabled
    if S.MaleficRapture:IsCastable() and S.SowTheSeeds:IsAvailable() and Player:SoulShardsP() > 0 then
      if HR.Cast(S.MaleficRapture) then return "MaleficRapture InCombat 4"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>30|buff.inevitable_demise.up&time_to_die<5
    if S.DrainLife:IsCastable() and Player:BuffStack(S.InvetiableDemiseBuff) > 30 or Player:BuffUp(S.InvetiableDemiseBuff) and Target:TimeToDie() < 5 then
      if HR.Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife InCombat"; end
    end
    -- drain_life,if=buff.inevitable_demise_az.stack>30 TODO
    -- drain_soul
    if S.DrainSoul:IsCastable() and S.DrainSoul:IsAvailable() then
      if HR.Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "DrainSoul InCombat"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsCastable() and S.ShadowBolt:IsAvailable() then
      if HR.Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt InCombat"; end
    end

    return
  end
end

local function OnInit()

end

HR.SetAPL(265, APL, OnInit)
