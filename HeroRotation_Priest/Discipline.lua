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


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Discipline
local I = Item.Priest.Discipline

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local EnemiesCount10ySplash

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Priest.Commons,
  Discipline = HR.GUISettings.APL.Priest.Discipline
}

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function Precombat()

  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- potion
    -- Manually added
    if S.MindBlast:IsCastable() and not Player:IsCasting(S.MindBlast) then
      if HR.Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast precombat 1"; end
    end
    if S.ShadowWordDeath:IsCastable() then
      if HR.Cast(S.ShadowWordDeath, nil, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death precombat 1"; end
    end
  end
end

local function Cds()
  -- mindbender,if=talent.mindbender.enabled
  if S.Mindbender:IsCastable() then
    if HR.Cast(S.Mindbender, Settings.Discipline.GCDasOffGCD.Mindbender) then return "mindbender cd 1"; end
  end
  -- shadowfiend,if=!talent.mindbender.enabled
  if S.Shadowfiend:IsCastable() then
    if HR.Cast(S.Shadowfiend, Settings.Discipline.GCDasOffGCD.Shadowfiend) then return "shadowfiend cd 2"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cd 3"; end
  end
  -- berserking
  if S.Berserking:IsCastable()  then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cd 4"; end
  end
  -- arcane_torrent
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent cd 5"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cd 6"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cd 7"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cd 8"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks cd 9"; end
  end
  -- shadow_covenant
  if S.ShadowCovenant:IsCastable() then
    if HR.Cast(S.ShadowCovenant, Settings.Discipline.GCDasOffGCD.ShadowCovenant) then return "shadow_covenant cd 10"; end
  end
  -- use_items
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Boon()
  -- ascended_blast,if=spell_targets.mind_sear<=3
  if S.AscendedBlast:IsReady() and (EnemiesCount10ySplash <= 3) then
    if HR.Cast(S.AscendedBlast, Settings.Commons.CovenantDisplayStyle, nil, not Target:IsSpellInRange(S.AscendedBlast)) then return "ascended_blast 1"; end
  end
  -- ascended_nova,if=(spell_targets.mind_sear>2&talent.searing_nightmare.enabled|(spell_targets.mind_sear>1&!talent.searing_nightmare.enabled))&spell_targets.ascended_nova>1
  if S.AscendedNova:IsReady() and EnemiesCount10ySplash > 1 then
    if HR.Cast(S.AscendedNova, Settings.Commons.CovenantDisplayStyle, nil, not Target:IsInRange(8)) then return "ascended_nova 2"; end
  end
end

local function Main()
  --purge_the_wicked,if=!ticking
  if S.PurgeTheWicked:IsCastable() and Target:DebuffDown(S.PurgeTheWickedDebuff) then
    if HR.Cast(S.PurgeTheWicked, nil, nil, not Target:IsSpellInRange(S.PurgeTheWicked)) then return "purge_the_wicked main 1"; end
  end
  --shadow_word_pain,if=!ticking&!talent.purge_the_wicked.enabled
  if S.ShadowWordPain:IsCastable() and Target:DebuffDown(S.ShadowWordPainDebuff) then
    if HR.Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain main 2"; end
  end
  --shadow_word_death
  if S.ShadowWordDeath:IsCastable() then
    if HR.Cast(S.ShadowWordDeath, nil, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 3"; end
  end
  --schism
  if S.Schism:IsCastable() and not Player:IsCasting(S.Schism) then
    if HR.Cast(S.Schism, nil, nil, not Target:IsSpellInRange(S.Schism)) then return "schism main 4"; end
  end
  --mind_blast
  if S.MindBlast:IsCastable() and not Player:IsCasting(S.MindBlast) then
    if HR.Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 5"; end
  end
  --penance
  if S.Penance:IsCastable() and not Player:BuffUp(S.ShadowCovenantBuff) then
    if HR.Cast(S.Penance, nil, nil, not Target:IsSpellInRange(S.Penance)) then return "penance main 6"; end
  end
  --purge_the_wicked,if=remains<(duration*0.3)
  if S.PurgeTheWicked:IsCastable() and Target:DebuffRemains(S.PurgeTheWickedDebuff) < S.PurgeTheWickedDebuff:BaseDuration() * 0.3 then
    if HR.Cast(S.PurgeTheWicked, nil, nil, not Target:IsSpellInRange(S.PurgeTheWicked)) then return "purge_the_wicked main 7"; end
  end
  --shadow_word_pain,if=remains<(duration*0.3)&!talent.purge_the_wicked.enabled
  if S.ShadowWordPain:IsCastable() and Target:DebuffRemains(S.ShadowWordPainDebuff) < S.ShadowWordPainDebuff:BaseDuration() * 0.3 then
    if HR.Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain main 8"; end
  end
  --power_word_solace
  if S.PowerWordSolace:IsCastable() and not Player:BuffUp(S.ShadowCovenantBuff) then
    if HR.Cast(S.PowerWordSolace, nil, nil, not Target:IsSpellInRange(S.PowerWordSolace)) then return "power_word_solace main 9"; end
  end
  --divine_star
  if S.DivineStar:IsCastable() and not Player:BuffUp(S.ShadowCovenantBuff) then
    if HR.Cast(S.DivineStar, nil, nil, not Target:IsSpellInRange(S.DivineStar)) then return "divine_star main 10"; end
  end
  --MA halo
  if S.Halo:IsCastable() and not Player:BuffUp(S.ShadowCovenantBuff) then
    if HR.Cast(S.Halo) then return "divine_star main 11"; end
  end
  --smite
  if S.Smite:IsCastable() and not Player:BuffUp(S.ShadowCovenantBuff) then
    if HR.Cast(S.Smite, nil, nil, not Target:IsSpellInRange(S.Smite)) then return "smite main 12"; end
  end
  --MA purge_the_wicked
  if S.PurgeTheWicked:IsCastable() then
    if HR.Cast(S.PurgeTheWicked, nil, nil, not Target:IsSpellInRange(S.PurgeTheWicked)) then return "purge_the_wicked main 13"; end
  end
  --shadow_word_pain
  if S.ShadowWordPain:IsCastable() then
    if HR.Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain main 14"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    if (Player:BuffUp(S.BoonoftheAscendedBuff)) then
      local ShouldReturn = Boon(); if ShouldReturn then return ShouldReturn; end
    end
    if (CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    if (true) then
      local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(256, APL, Init)
