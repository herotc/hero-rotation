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

local FirstTarGUID

-- Stuns

-- Rotation Variables

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCycleAgonyRemains(TargetUnit)
  --dot.agony.remains<4
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 4 and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyRefreshTicking(TargetUnit)
  --refreshable&dot.agony.ticking
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff) and TargetUnit:DebuffTicksRemain(S.AgonyDebuff) > 0 and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLifeNotTicking(TargetUnit)
  --!dot.siphon_life.ticking
  return (TargetUnit:DebuffDown(S.SiphonLifeDebuff) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleAgonyNotTicking(TargetUnit)
  --!dot.agony.ticking
  return (TargetUnit:DebuffDown(S.AgonyDebuff)and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy()))
end

local function EvaluateCycleSiphonLifeRemains(TargetUnit)
  --dot.siphon_life.remains<4
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 4) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleSiphonLifeRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.SiphonLifeDebuff)) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruptionRemains(TargetUnit)
  --dot.corruption.remains<2
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 2) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleCorruptionRefresh(TargetUnit)
  --refreshable
  return (TargetUnit:DebuffRefreshable(S.CorruptionDebuff)) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleUnstableAfflictionRemains(TargetUnit)
  --dot.unstable_affliction.remains<4
  return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRemains(S.UnstableAfflictionDebuff) < 4) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

local function EvaluateCycleUnstableAfflictionRefresh(TargetUnit)
  --refreshable
  return ((TargetUnit:GUID() == EnemiesWithUnstableAfflictionDebuff and TargetUnit:DebuffRefreshable(S.UnstableAfflictionDebuff)) or EnemiesWithUnstableAfflictionDebuff == 0) and (TargetUnit:AffectingCombat() or TargetUnit:IsDummy())
end

-- Counter for Debuff on other enemies
local function calcEnemiesDotCount(Object, Enemies)
  local debuffs = 0

  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffTicksRemain(Object) > 0 then
      debuffs = debuffs + 1
    end
  end

  return debuffs
end

local function returnEnemiesWithDot(Object, Enemies)
  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffTicksRemain(Object) > 0 then
      if Object == S.UnstableAfflictionDebuff then
        return CycleUnit:GUID()
      end
    end
  end
  return 0
end

local function Precombat()
  FirstTarGUID = Target:GUID()
  -- flask
  -- food
  -- augmentation
  -- summon_pet - Moved to APL()
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() and Player:BuffDown(S.GrimoireofSacrificeBuff) then
    if Cast(S.GrimoireofSacrifice,Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "GrimoureOfSacrifice precombat"; end
  end
  -- snapshot_stats
  -- potion
  if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion precombat"; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt precombat"; end
  end
  -- Manually added: unstable_affliction
  if S.UnstableAffliction:IsReady() then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction precombat"; end
  end
  -- Manually added: agony
  if S.Agony:IsReady() then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony precombat"; end
  end
end

local function Opener()
  -- haunt,if=!dot.haunt.ticking
  if S.Haunt:IsReady() and (Target:DebuffDown(S.HauntDebuff)) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt opener"; end
  end
  -- unstable_affliction,if=!dot.unstable_affliction.ticking
  if S.UnstableAffliction:IsReady() and (Target:DebuffDown(S.UnstableAfflictionDebuff)) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction opener"; end
  end
  -- agony,if=!dot.agony.ticking
  if S.Agony:IsReady() and (Target:DebuffDown(S.AgonyDebuff)) then
    if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony opener"; end
  end
  -- corruption=!dot.corruption.ticking
  if S.Corruption:IsReady() and (Target:DebuffDown(S.CorruptionDebuff)) then
    if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption opener"; end
  end
  -- siphon_life=!dot.siphon_life.ticking
  if S.SiphonLife:IsReady() and (Target:DebuffDown(S.SiphonLifeDebuff)) then
    if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life opener"; end
  end
end

local function Covenant()
  -- impending_catastrophe,if=cooldown.summon_darkglare.remains<10|cooldown.summon_darkglare.remains>50
  if S.ImpendingCatastrophe:IsReady() and (S.SummonDarkglare:CooldownRemains() < 10 or S.SummonDarkglare:CooldownRemains() > 50) then
    if HR.Cast(S.ImpendingCatastrophe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ImpendingCatastrophe)) then return "impending_catastrophe covenant"; end
  end

  -- decimating_bolt,if=cooldown.summon_darkglare.remains>5&(debuff.haunt.remains>4|!talent.haunt.enabled)
  if S.DecimatingBolt:IsReady() and (S.SummonDarkglare:CooldownRemains() > 5 and (not S.Haunt:IsAvailable() or Target:DebuffRemains(S.Haunt) > 4)) then
    if HR.Cast(S.DecimatingBolt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.DecimatingBolt)) then return "decimating_bolt covenant"; end
  end

  -- soul_rot,if=cooldown.summon_darkglare.remains<5|cooldown.summon_darkglare.remains>50
  if S.SoulRot:IsReady() and (S.SummonDarkglare:CooldownRemains() < 5 or S.SummonDarkglare:CooldownRemains() > 50) then
    if HR.Cast(S.SoulRot, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot covenant"; end
  end

  -- scouring_tithe
  if S.ScouringTithe:IsReady() then
    if HR.Cast(S.ScouringTithe, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.ScouringTithe)) then return "scouring_tithe covenant"; end
  end
end

local function Darkglare_prep()
  -- vile_taint
  if S.VileTaint:IsReady() then
    if Cast(S.VileTaint) then return "VileTaint Darkglare_prep"; end
  end
  -- dark_soul
  if S.DarkSoulMisery:IsReady() then
    if Cast(S.DarkSoulMisery,Settings.Affliction.GCDasOffGCD.DarkSoul) then return "DarkSoulMisery Darkglare_prep"; end
  end
  -- potion
  if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion Darkglare_prep"; end
  end
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
  -- call_action_list,name=covenant,if=!covenant.necrolord&cooldown.summon_darkglare.remains<2
  if (Player:Covenant() ~= "Necrolord" and S.SummonDarkglare:CooldownRemains() < 2) then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
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
  -- drain_soul,interrupt_if=debuff.shadow_embrace.stack>=3
  if S.DrainSoul:IsReady() and (Target:DebuffStack(S.ShadowEmbraceDebuff) >= 3) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "DrainSoul Se"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "ShadowBolt Se"; end
  end
end

local function Aoe()
  -- phantom_singularity
  if S.PhantomSingularity:IsReady() then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity Aoe"; end
  end
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt Aoe"; end
  end
  if CDsON() then
    -- call_action_list,name=darkglare_prep,if=covenant.venthyr&dot.impending_catastrophe_dot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if (Player:Covenant() == "Venthyr" and Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0 and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=covenant.night_fae&dot.soul_rot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if (Player:Covenant() == "Night Fae" and Target:DebuffTicksRemain(S.SoulRot) > 0 and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&dot.phantom_singularity.ticking&dot.phantom_singularity.remains<2
    if (Player:Covenant() ~= "Venthyr" and Player:Covenant() ~= "Night Fae" and Target:DebuffUp(S.PhantomSingularityDebuff) and Target:DebuffRemains(S.PhantomSingularityDebuff) < 2) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds.enabled&can_seed
  if S.SeedofCorruption:IsReady() and (S.SowtheSeeds:IsAvailable() and (EnemiesSeedofCorruptionCount <= (EnemiesCount10ySplash < 3 and EnemiesCount10ySplash or 3))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 1"; end
  end
  -- seed_of_corruption,if=!talent.sow_the_seeds.enabled&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.refreshable
  if S.SeedofCorruption:IsReady() and (not S.SowtheSeeds:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight() and Target:DebuffRefreshable(S.CorruptionDebuff)) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption Aoe 2"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony<4,target_if=!dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount < 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyNotTicking, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 2"; end
  end
  -- agony,cycle_targets=1,if=active_dot.agony>=4,target_if=refreshable&dot.agony.ticking
  if S.Agony:IsReady() and (EnemiesAgonyCount >= 4) then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefreshTicking, not Target:IsSpellInRange(S.Agony)) then return "Agony Aoe 1"; end
  end
  -- unstable_affliction,if=dot.unstable_affliction.refreshable
  if S.UnstableAffliction:IsReady() then
    if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRefresh, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction Aoe"; end
  end
  -- vile_taint,if=soul_shard>1
  if S.VileTaint:IsReady() and (Player:SoulShardsP() > 1) then
    if Cast(S.VileTaint) then return "VileTaint Aoe"; end
  end
  -- call_action_list,name=covenant,if=!covenant.necrolord
  if (Player:Covenant() ~= "Necrolord") then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
  end
  if CDsON() then
    -- call_action_list,name=darkglare_prep,if=covenant.venthyr&(cooldown.impending_catastrophe.ready|dot.impending_catastrophe_dot.ticking)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if (Player:Covenant() == "Venthyr" and (S.ImpendingCatastrophe:IsReady() or Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if (Player:Covenant() ~= "Venthyr" and Player:Covenant() ~= "Night Fae" and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=darkglare_prep,if=covenant.night_fae&(cooldown.soul_rot.ready|dot.soul_rot.ticking)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
    if (Player:Covenant() == "Night Fae" and (S.SoulRot:IsReady() or Target:DebuffTicksRemain(S.SoulRot) > 0) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
      local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
    end
    -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
    if S.DarkSoulMisery:IsReady() and (S.SummonDarkglare:CooldownRemains() > Target:TimeToDie()) then
      if Cast(S.DarkSoulMisery,Settings.Affliction.GCDasOffGCD.DarkSoul) then return "DarkSoulMisery Aoe"; end
    end
  end
  -- call_action_list,name=item
  if (true) then
    local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
  end
  -- malefic_rapture,if=dot.vile_taint.ticking
  if S.MaleficRapture:IsReady() and (EnemiesVileTaintCount >= 1) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 1"; end
  end
  -- malefic_rapture,if=dot.soul_rot.ticking&!talent.sow_the_seeds.enabled
  if S.MaleficRapture:IsReady() and (Target:DebuffDown(S.SoulRot) and not S.SowtheSeeds:IsAvailable()) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 2"; end
  end
  -- malefic_rapture,if=!talent.vile_taint.enabled
  if S.MaleficRapture:IsReady() and (not S.VileTaint:IsAvailable()) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 3"; end
  end
  -- malefic_rapture,if=soul_shard>4
  if S.MaleficRapture:IsReady() and (Player:SoulShardsP() > 4) then
    if Cast(S.MaleficRapture) then return "MaleficRapture Aoe 4"; end
  end
  -- siphon_life,cycle_targets=1,if=active_dot.siphon_life<=3,target_if=!dot.siphon_life.ticking
  if S.SiphonLife:IsReady() and (EnemiesSiphonLifeCount <= 3) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeNotTicking, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife Aoe"; end
  end
  -- call_action_list,name=covenant
  if (true) then
    local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>=50|buff.inevitable_demise.up&time_to_die<5|buff.inevitable_demise.stack>=35&dot.soul_rot.ticking
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InvetiableDemiseBuff) >= 50 or Player:BuffUp(S.InvetiableDemiseBuff) and Target:TimeToDie() < 5 or Player:BuffStack(S.InvetiableDemiseBuff) >= 35 and Target:DebuffTicksRemain(S.SoulRot) > 0) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife Aoe"; end
  end
  -- drain_soul,interrupt=1
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

  -- summon_pet - Added here to show even when out of combat and while having no target
  if S.SummonPet:IsReady() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  -- +In Combat
  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>3
    if (EnemiesCount10ySplash > 3) then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Opener function to ensure that all DoTs are applied before anything else
    -- Added this because sometimes the rotation tries to go into Darkglare_prep before applying all DoTs on single target
    -- 12 seconds chosen arbitrarily, as it's enough time to get all DoTs up and not have any wear off
    if HL.CombatTime() < 12 and Target:GUID() == FirstTarGUID then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- phantom_singularity,if=time>30
    if S.PhantomSingularity:IsReady() and (HL.CombatTime() > 30) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity InCombat 1"; end
    end
    if CDsON() then
      -- call_action_list,name=darkglare_prep,if=covenant.venthyr&dot.impending_catastrophe_dot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
      if (Player:Covenant() == "Venthyr" and Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0 and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=covenant.night_fae&dot.soul_rot.ticking&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
      if (Player:Covenant() == "Night Fae" and Target:DebuffTicksRemain(S.SoulRot) > 0 and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&dot.phantom_singularity.ticking&dot.phantom_singularity.remains<2
      if (Player:Covenant() ~= "Venthyr" and Player:Covenant() ~= "Night Fae" and Target:DebuffTicksRemain(S.PhantomSingularityDebuff) > 0 and Target:DebuffRemains(S.PhantomSingularityDebuff) < 2) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- agony,if=dot.agony.remains<4
    if S.Agony:IsReady() and (Target:DebuffRemains(S.AgonyDebuff) < 4) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat 1"; end
    end
    -- agony,cycle_targets=1,if=active_enemies>1,target_if=dot.agony.remains<4
    if S.Agony:IsReady() and (Enemies40yCount > 1) then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRemains, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat 2"; end
    end
    -- haunt
    if S.Haunt:IsReady() then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "Haunt InCombat"; end
    end
    if CDsON() then
      -- call_action_list,name=darkglare_prep,if=active_enemies>2&covenant.venthyr&(cooldown.impending_catastrophe.ready|dot.impending_catastrophe_dot.ticking)&(dot.phantom_singularity.ticking|!talent.phantom_singularity.enabled)
      if (Enemies40yCount > 2 and Player:Covenant() == "Venthyr" and (S.ImpendingCatastrophe:IsReady() or Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0) and (Target:DebuffTicksRemain(S.PhantomSingularityDebuff) > 0 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=active_enemies>2&(covenant.necrolord|covenant.kyrian|covenant.none)&(dot.phantom_singularity.ticking|!talent.phantom_singularity.enabled)
      if (Enemies40yCount > 2 and Player:Covenant() ~= "Venthyr" and Player:Covenant() ~= "Night Fae" and (Target:DebuffTicksRemain(S.PhantomSingularityDebuff) > 0 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=active_enemies>2&covenant.night_fae&(cooldown.soul_rot.ready|dot.soul_rot.ticking)&(dot.phantom_singularity.ticking|!talent.phantom_singularity.enabled)
      if (Enemies40yCount > 2 and Player:Covenant() == "Night Fae" and (S.SoulRot:IsReady() or Target:DebuffTicksRemain(S.SoulRot) > 0) and (Target:DebuffTicksRemain(S.PhantomSingularityDebuff) > 0 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- seed_of_corruption,if=active_enemies>2&talent.sow_the_seeds.enabled&!dot.seed_of_corruption.ticking&!in_flight
    if S.SeedofCorruption:IsReady() and (EnemiesCount10ySplash > 2 and S.SowtheSeeds:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight()) then
      if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption InCombat 1"; end
    end
    -- seed_of_corruption,if=active_enemies>2&talent.siphon_life.enabled&!dot.seed_of_corruption.ticking&!in_flight&dot.corruption.remains<4
    if S.SeedofCorruption:IsReady() and (EnemiesCount10ySplash > 2 and S.SiphonLife:IsAvailable() and Target:DebuffDown(S.SeedofCorruptionDebuff) and not S.SeedofCorruption:InFlight() and Target:DebuffRemains(S.CorruptionDebuff) < 4) then
      if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "SeedofCorruption InCombat 2"; end
    end
    -- vile_taint,if=(soul_shard>1|active_enemies>2)&cooldown.summon_darkglare.remains>12
    if S.VileTaint:IsReady() and ((Player:SoulShardsP() > 1 or EnemiesCount10ySplash > 2) and S.SummonDarkglare:CooldownRemains() > 12) then
      if Cast(S.VileTaint) then return "VileTaint InCombat"; end
    end
    -- unstable_affliction,if=dot.unstable_affliction.remains<4
    if S.UnstableAffliction:IsReady() then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRemains, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction InCombat 1"; end
    end
    -- siphon_life,if=dot.siphon_life.remains<4
    if S.SiphonLife:IsReady() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 4) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat 1"; end
    end
    -- siphon_life,cycle_targets=1,if=active_enemies>1,target_if=dot.siphon_life.remains<4
    if S.SiphonLife:IsReady() and (Enemies40yCount > 1) then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeRemains, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat 2"; end
    end
    -- call_action_list,name=covenant,if=!covenant.necrolord
    if (Player:Covenant() ~= "Necrolord") then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- corruption,if=active_enemies<4-(talent.sow_the_seeds.enabled|talent.siphon_life.enabled)&dot.corruption.remains<2
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable()) and Target:DebuffRemains(S.CorruptionDebuff) < 2) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 1"; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<4-(talent.sow_the_seeds.enabled|talent.siphon_life.enabled),target_if=dot.corruption.remains<2
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable())) then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRemains, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 2"; end
    end
    -- phantom_singularity,if=covenant.necrolord|covenant.night_fae|covenant.kyrian|covenant.none
    if S.PhantomSingularity:IsReady() and (Player:Covenant() ~= "Venthyr") then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "PhantomSingularity InCombat 2"; end
    end
    -- malefic_rapture,if=soul_shard>4
    if S.MaleficRapture:IsReady() and (Player:SoulShardsP() > 4) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 1"; end
    end
    if CDsON() then
      -- call_action_list,name=darkglare_prep,if=covenant.venthyr&(cooldown.impending_catastrophe.ready|dot.impending_catastrophe_dot.ticking)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
      if (Player:Covenant() == "Venthyr" and (S.ImpendingCatastrophe:IsReady() or Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=(covenant.necrolord|covenant.kyrian|covenant.none)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
      if (Player:Covenant() ~= "Venthyr" and Player:Covenant() ~= "Night Fae" and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=darkglare_prep,if=covenant.night_fae&(cooldown.soul_rot.ready|dot.soul_rot.ticking)&cooldown.summon_darkglare.remains<2&(dot.phantom_singularity.remains>2|!talent.phantom_singularity.enabled)
      if (Player:Covenant() == "Night Fae" and (S.SoulRot:IsReady() or Target:DebuffTicksRemain(S.SoulRot) > 0) and S.SummonDarkglare:CooldownRemains() < 2 and (Target:DebuffRemains(S.PhantomSingularityDebuff) > 2 or not S.PhantomSingularity:IsAvailable())) then
        local ShouldReturn = Darkglare_prep(); if ShouldReturn then return ShouldReturn; end
      end
      -- dark_soul,if=cooldown.summon_darkglare.remains>time_to_die
      if S.DarkSoulMisery:IsReady() and (S.SummonDarkglare:CooldownRemains() > Target:TimeToDie()) then
        if Cast(S.DarkSoulMisery,Settings.Affliction.GCDasOffGCD.DarkSoul) then return "DarkSoulMisery InCombat"; end
      end
    end
    -- call_action_list,name=item
    if (true) then
      local ShouldReturn = ItemFunc(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=se,if=debuff.shadow_embrace.stack<(2-action.shadow_bolt.in_flight)|debuff.shadow_embrace.remains<3
    if S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < (2 - num(S.ShadowBolt:InFlight())) or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3) then
      local ShouldReturn = Se(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=dot.vile_taint.ticking
    if S.MaleficRapture:IsReady() and (Target:DebuffTicksRemain(S.VileTaintDebuff) > 0) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 2"; end
    end
    -- malefic_rapture,if=dot.impending_catastrophe_dot.ticking
    if S.MaleficRapture:IsReady() and (Target:DebuffTicksRemain(S.ImpendingCatastrophe) > 0) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 3"; end
    end
    -- malefic_rapture,if=dot.soul_rot.ticking
    if S.MaleficRapture:IsReady() and (Target:DebuffTicksRemain(S.SoulRot) > 0) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 4"; end
    end
    -- malefic_rapture,if=talent.phantom_singularity.enabled&(dot.phantom_singularity.ticking|soul_shard>3|time_to_die<cooldown.phantom_singularity.remains)
    if S.MaleficRapture:IsReady() and (S.PhantomSingularity:IsAvailable() and (Target:DebuffTicksRemain(S.PhantomSingularityDebuff) > 0 or Player:SoulShardsP() > 3 or Target:TimeToDie() < S.PhantomSingularity:CooldownRemains())) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 5"; end
    end
    -- malefic_rapture,if=talent.sow_the_seeds.enabled
    if S.MaleficRapture:IsReady() and (S.SowtheSeeds:IsAvailable()) then
      if Cast(S.MaleficRapture) then return "MaleficRapture InCombat 6"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>40|buff.inevitable_demise.up&time_to_die<4
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InvetiableDemiseBuff) > 40 or Player:BuffUp(S.InvetiableDemiseBuff) and Target:TimeToDie() < 4) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "DrainLife InCombat 1"; end
    end
    -- call_action_list,name=covenant
    if (true) then
      local ShouldReturn = Covenant(); if ShouldReturn then return ShouldReturn; end
    end
    -- agony,if=refreshable
    if S.Agony:IsReady() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat 3"; end
    end
    -- agony,cycle_targets=1,if=active_enemies>1,target_if=refreshable
    if S.Agony:IsReady() and (Enemies40yCount > 1) then
      if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefresh, not Target:IsSpellInRange(S.Agony)) then return "Agony InCombat 4"; end
    end
    -- corruption,if=refreshable&active_enemies<4-(talent.sow_the_seeds.enabled|talent.siphon_life.enabled)
    if S.Corruption:IsReady() and (Target:DebuffRefreshable(S.CorruptionDebuff) and EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable())) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 3"; end
    end
    -- unstable_affliction,if=refreshable
    if S.UnstableAffliction:IsReady() then
      if Everyone.CastCycle(S.UnstableAffliction, Enemies40y, EvaluateCycleUnstableAfflictionRefresh, not Target:IsSpellInRange(S.UnstableAffliction)) then return "UnstableAffliction InCombat 2"; end
    end
    -- siphon_life,if=refreshable
    if S.SiphonLife:IsReady() and (Target:DebuffRefreshable(S.SiphonLifeDebuff)) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat 3"; end
    end
    -- siphon_life,cycle_targets=1,if=active_enemies>1,target_if=refreshable
    if S.SiphonLife:IsReady() and (Enemies40yCount > 1) then
      if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLifeRefresh, not Target:IsSpellInRange(S.SiphonLife)) then return "SiphonLife InCombat 4"; end
    end
    -- corruption,cycle_targets=1,if=active_enemies<4-(talent.sow_the_seeds.enabled|talent.siphon_life.enabled),target_if=refreshable
    if S.Corruption:IsReady() and (EnemiesCount10ySplash < 4 - num(S.SowtheSeeds:IsAvailable() or S.SiphonLife:IsAvailable())) then
      if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRefresh, not Target:IsSpellInRange(S.Corruption)) then return "Corruption InCombat 4"; end
    end
    -- drain_soul,interrupt=1
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