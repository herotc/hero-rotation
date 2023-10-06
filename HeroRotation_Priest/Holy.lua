--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
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
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
local Cast       = HR.Cast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Holy
local I = Item.Priest.Holy

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local Enemies8yMelee, EnemiesCount8yMelee
local Enemies12yMelee, EnemiesCount12yMelee
local Enemies30y, EnemiesCount30y
local EnemiesCount8ySplash

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Priest.Commons,
  Holy = HR.GUISettings.APL.Priest.Holy
}

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- Manually added: Group buff check
    if S.PowerWordFortitude:IsCastable() and Everyone.GroupBuffMissing(S.PowerWordFortitudeBuff) then
      if Cast(S.PowerWordFortitude, Settings.Commons.GCDasOffGCD.PowerWordFortitude) then return "power_word_fortitude precombat"; end
    end
    -- smite
    if S.Smite:IsReady() then
      if Cast(S.Smite, nil, nil, not Target:IsSpellInRange(S.Smite)) then return "smite precombat 2"; end
    end
  end
end

local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8)
  Enemies12yMelee = Player:GetEnemiesInMeleeRange(12)
  Enemies30y = Player:GetEnemiesInRange(30)
  if AoEON() then
    EnemiesCount8yMelee = #Enemies8yMelee
    EnemiesCount12yMelee = #Enemies12yMelee
    EnemiesCount30y = #Enemies30y
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8yMelee = 1
    EnemiesCount12yMelee = 1
    EnemiesCount30y = 1
    EnemiesCount8ySplash = 1
  end
  
  -- Precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- use_items
    if (Settings.Commons.Enabled.Trinkets) then
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    -- potion,if=buff.bloodlust.react|(raid_event.adds.up&(raid_event.adds.remains>20|raid_event.adds.duration<20))|target.time_to_die<=30
    if I.PotionofSpectralIntellect:IsReady() and (Player:BloodlustUp() or Target:TimeToDie() <= 30) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
    end
    -- holy_fire,if=dot.holy_fire.ticking&(dot.holy_fire.remains<=gcd|dot.holy_fire.stack<2)&spell_targets.holy_nova<7
    if S.HolyFire:IsReady() and (Target:DebuffUp(S.HolyFireDebuff) and (Target:DebuffRemains(S.HolyFireDebuff) <= Player:GCD() or Target:DebuffStack(S.HolyFireDebuff) < 2) and EnemiesCount12yMelee < 7) then
      if Cast(S.HolyFire, nil, nil, not Target:IsSpellInRange(S.HolyFire)) then return "holy_fire main 4"; end
    end
    -- holy_word_chastise,if=spell_targets.holy_nova<5
    if S.HolyWordChastise:IsReady() and (EnemiesCount12yMelee < 5) then
      if Cast(S.HolyWordChastise, nil, nil, not Target:IsSpellInRange(S.HolyWordChastise)) then return "holy_word_chastise main 6"; end
    end
    -- holy_fire,if=dot.holy_fire.ticking&(dot.holy_fire.refreshable|dot.holy_fire.stack<2)&spell_targets.holy_nova<7
    if S.HolyFire:IsReady() and (Target:DebuffUp(S.HolyFireDebuff) and (Target:DebuffRefreshable(S.HolyFireDebuff) or Target:DebuffStack(S.HolyFireDebuff) < 2) and EnemiesCount12yMelee < 7) then
      if Cast(S.HolyFire, nil, nil, not Target:IsSpellInRange(S.HolyFire)) then return "holy_fire main 8"; end
    end
    if (CDsON()) then
      -- berserking,if=raid_event.adds.in>30|raid_event.adds.remains>8|raid_event.adds.duration<8
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 10"; end
      end
      -- fireblood,if=raid_event.adds.in>20|raid_event.adds.remains>6|raid_event.adds.duration<6
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 12"; end
      end
      -- ancestral_call,if=raid_event.adds.in>20|raid_event.adds.remains>10|raid_event.adds.duration<10
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 14"; end
      end
    end
    -- divine_star,if=(raid_event.adds.in>5|raid_event.adds.remains>2|raid_event.adds.duration<2)&spell_targets.divine_star>1
    if S.DivineStar:IsReady() and (Target:IsInRange(24) and EnemiesCount8ySplash > 1) then
      if Cast(S.DivineStar, Settings.Holy.GCDasOffGCD.DivineStar) then return "divine_star main 16"; end
    end
    -- halo,if=(raid_event.adds.in>14|raid_event.adds.remains>2|raid_event.adds.duration<2)&spell_targets.halo>0
    if S.Halo:IsReady() and (EnemiesCount30y > 0) then
      if Cast(S.Halo, Settings.Holy.GCDasOffGCD.Halo) then return "halo main 18"; end
    end
    if (CDsON()) then
      -- lights_judgment,if=raid_event.adds.in>50|raid_event.adds.remains>4|raid_event.adds.duration<4
      if S.LightsJudgment:IsCastable() then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 20"; end
      end
      -- arcane_pulse,if=(raid_event.adds.in>40|raid_event.adds.remains>2|raid_event.adds.duration<2)&spell_targets.arcane_pulse>2
      if S.ArcanePulse:IsCastable() and (EnemiesCount8yMelee > 2) then
        if Cast(S.ArcanePulse, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_pulse main 22"; end
      end
    end
    -- holy_fire,if=!dot.holy_fire.ticking&spell_targets.holy_nova<7
    if S.HolyFire:IsReady() and (Target:DebuffDown(S.HolyFireDebuff) and EnemiesCount12yMelee < 7) then
      if Cast(S.HolyFire, nil, nil, not Target:IsSpellInRange(S.HolyFire)) then return "holy_fire main 24"; end
    end
    -- holy_nova,if=spell_targets.holy_nova>3
    if S.HolyNova:IsReady() and (EnemiesCount12yMelee > 3) then
      if Cast(S.HolyNova) then return "holy_nova main 26"; end
    end
    -- apotheosis,if=active_enemies<5&(raid_event.adds.in>15|raid_event.adds.in>raid_event.adds.cooldown-5)
    if S.Apotheosis:IsCastable() and (EnemiesCount8ySplash < 5) then
      if Cast(S.Apotheosis, Settings.Holy.GCDasOffGCD.Apotheosis) then return "apotheosis main 28"; end
    end
    -- smite
    if S.Smite:IsReady() then
      if Cast(S.Smite, nil, nil, not Target:IsSpellInRange(S.Smite)) then return "smite main 30"; end
    end
    -- holy_fire
    if S.HolyFire:IsReady() then
      if Cast(S.HolyFire, nil, nil, not Target:IsSpellInRange(S.HolyFire)) then return "holy_fire main 32"; end
    end
    -- divine_star,if=(raid_event.adds.in>5|raid_event.adds.remains>2|raid_event.adds.duration<2)&spell_targets.divine_star>0
    if S.DivineStar:IsReady() and (Target:IsInRange(24)) then
      if Cast(S.DivineStar, Settings.Holy.GCDasOffGCD.DivineStar) then return "divine_star main 34"; end
    end
    -- holy_nova,if=raid_event.movement.remains>gcd*0.3&spell_targets.holy_nova>0
    if S.HolyNova:IsReady() and (Player:IsMoving() and EnemiesCount12yMelee > 0) then
      if Cast(S.HolyNova) then return "holy_nova main moving filler"; end
    end
  end
end

local function Init()
  HR.Print("Holy Priest rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(257, APL, Init)
