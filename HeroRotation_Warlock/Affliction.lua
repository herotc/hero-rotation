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
local OnUseExcludes = {
  --  I.TrinketName:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Enemies
local Enemies40y, Enemies40yCount, Enemies10ySplash, EnemiesCount10ySplash
local EnemiesAgonyCount, EnemiesSeedofCorruptionCount, EnemiesSiphonLifeCount, EnemiesVileTaintCount = 0, 0, 0, 0
local EnemiesWithUnstableAfflictionDebuff
local FirstTarGUID
local BossFightRemains = 11111
local FightRemains = 11111

-- Legendaries

-- Stuns

-- Rotation Variables

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- Counter for Debuff on other enemies
local function CalcEnemiesDotCount(Object, Enemies)
  local debuffs = 0

  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    if CycleUnit:DebuffUp(Object) then
      debuffs = debuffs + 1
    end
  end

  return debuffs
end

local function ReturnEnemiesWithDot(Object, Enemies)
  for _, CycleUnit in pairs(Enemies) do
    --if CycleUnit:DebuffUp(Object, nil, 0) then
    --if CycleUnit:DebuffTicksRemain(Object) > 0 then
    if CycleUnit:DebuffUp(Object) then
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
  if S.GrimoireofSacrifice:IsCastable() then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- unstable_affliction,if=!talent.soul_swap
  if S.UnstableAffliction:IsReady() and (not S.SoulSwap:IsAvailable()) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 4"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 6"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    Enemies40yCount = #Enemies40y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

    EnemiesAgonyCount = CalcEnemiesDotCount(S.AgonyDebuff, Enemies40y)
    EnemiesSeedofCorruptionCount = CalcEnemiesDotCount(S.SeedofCorruptionDebuff, Enemies40y)
    EnemiesSiphonLifeCount = CalcEnemiesDotCount(S.SiphonLifeDebuff, Enemies40y)
    EnemiesVileTaintCount = CalcEnemiesDotCount(S.VileTaintDebuff, Enemies40y)
  else
    Enemies40yCount = 1
    EnemiesCount10ySplash = 1
  end

  EnemiesWithUnstableAfflictionDebuff = ReturnEnemiesWithDot(S.UnstableAfflictionDebuff, Enemies40y)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end
  end

  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if (not Player:AffectingCombat()) then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=soul_shard=5
    if S.MaleficRapture:IsReady() and (Player:SoulShardsP() == 5) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 2"; end
    end
    -- haunt
    if S.Haunt:IsReady() then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 4"; end
    end
    -- soul_swap,if=dot.unstable_affliction.remains<5
    if S.SoulSwap:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
      if Cast(S.SoulSwap, nil, nil, not Target:IsSpellInRange(S.SoulSwap)) then return "soul_swap main 6"; end
    end
    -- unstable_affliction,if=remains<5
    if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 8"; end
    end
    -- agony,if=remains<5
    if S.Agony:IsCastable() and (Target:DebuffRemains(S.AgonyDebuff) < 5) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 10"; end
    end
    -- siphon_life,if=remains<5
    if S.SiphonLife:IsCastable() and (Target:DebuffRemains(S.SiphonLifeDebuff) < 5) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 12"; end
    end
    -- corruption,if=dot.corruption_dot.remains<5
    if S.Corruption:IsCastable() and (Target:DebuffRemains(S.CorruptionDebuff) < 5) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 14"; end
    end
    -- soul_tap,line_cd=30
    if S.SoulTap:IsCastable() and (S.SoulTap:TimeSinceLastCast() >= 30) then
      if Cast(S.SoulTap, Settings.Affliction.GCDasOffGCD.SoulTap) then return "soul_tap main 16"; end
    end
    -- phantom_singularity
    if S.PhantomSingularity:IsCastable() then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 18"; end
    end
    -- vile_taint
    if S.VileTaint:IsReady() then
      if Cast(S.VileTaint, nil, nil, not Target:IsSpellInRange(S.VileTaint)) then return "vile_taint main 20"; end
    end
    -- soul_rot
    if S.SoulRot:IsReady() then
      if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot main 22"; end
    end
    -- use_items
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
    -- summon_darkglare
    if S.SummonDarkglare:IsCastable() then
      if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare main 24"; end
    end
    -- malefic_rapture
    if S.MaleficRapture:IsReady() then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 26"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsCastable() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 28"; end
    end
    -- corruption,if=dot.corruption_dot.refreshable
    if S.Corruption:IsCastable() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 30"; end
    end
    -- drain_soul,interrupt=1
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 32"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 34"; end
    end

    return
  end
end

local function OnInit()
  HR.Print("Affliction Warlock rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(265, APL, OnInit)