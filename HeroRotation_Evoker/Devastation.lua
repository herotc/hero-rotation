--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastAnnotated = HR.CastAnnotated
local CastSuggested = HR.CastSuggested

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Devastation
local I = Item.Evoker.Devastation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  Devastation = HR.GUISettings.APL.Evoker.Devastation
}

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Rotation Var
local Enemies25y
local Enemies8ySplash
local EnemiesCount8ySplash
local MaxEssenceBurstStack = (S.EssenceAttunement:IsAvailable()) and 2 or 1

-- Stun Interrupts
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN", "PLAYER_EQUIPMENT_CHANGED")

-- Talent change registrations
HL:RegisterForEvent(function()
  MaxEssenceBurstStack = (S.EssenceAttunement:IsAvailable()) and 2 or 1
end, "PLAYER_TALENT_UPDATE")

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- Manually added: precast living_flame
  if S.LivingFlame:IsCastable() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame precombat"; end
  end
end

local function Defensives()
  
end

-- APL Main
local function APL()
  Enemies25y = Player:GetEnemiesInRange(25)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if (AoEON()) then
    EnemiesCount8ySplash = #Enemies8ySplash
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Interrupts
    local ShouldReturn = Everyone.Interrupt(10, S.Quell, Settings.Commons.OffGCDasOffGCD.Quell, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- potion
    if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
    end
    -- disintegrate,if=cooldown.dragonrage.remains<=3*gcd.max
    if S.Disintegrate:IsReady() and EnemiesCount8ySplash < 3 and (S.Dragonrage:IsAvailable() and S.Dragonrage:CooldownRemains() <= 3 * Player:GCD()) then
      if Cast(S.Disintegrate, nil, nil, not Target:IsInRange(25)) then return "disintegrate main 4"; end
    end
    -- dragonrage
    if S.Dragonrage:IsCastable() then
      if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage main 6"; end
    end
    -- Manually added: firestorm
    if S.Firestorm:IsCastable() then
      if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm main 8"; end
    end
    -- shattering_star
    if S.ShatteringStar:IsCastable() then
      if Cast(S.ShatteringStar, nil, nil, not Target:IsInRange(25)) then return "shattering_star main 10"; end
    end
    -- eternity_surge,empower_to=1
    -- Manually added: All empower levels. Is this optimal?
    if S.EternitySurge:IsReady() then
      if S.EternitysSpan:IsAvailable() then
        if EnemiesCount8ySplash <= 2 then
          if CastAnnotated(S.EternitySurge, false, "1") then return "eternity_surge empower 1 main 12"; end
        elseif EnemiesCount8ySplash > 2 and EnemiesCount8ySplash <= 4 then
          if CastAnnotated(S.EternitySurge, false, "2") then return "eternity_surge empower 2 main 14"; end
        elseif EnemiesCount8ySplash > 4 then
          if CastAnnotated(S.EternitySurge, false, "3") then return "eternity_surge empower 3 main 16"; end
        end
      else
        if EnemiesCount8ySplash == 1 then
          if CastAnnotated(S.EternitySurge, false, "1") then return "eternity_surge empower 1 main 18"; end
        elseif EnemiesCount8ySplash == 2 then
          if CastAnnotated(S.EternitySurge, false, "2") then return "eternity_surge empower 2 main 20"; end
        elseif EnemiesCount8ySplash > 2 then
          if CastAnnotated(S.EternitySurge, false, "3") then return "eternity_surge empower 3 main 22"; end
        end
      end
    end
    -- tip_the_scales,if=buff.dragonrage.up
    if S.TipTheScales:IsCastable() and (Player:BuffUp(S.Dragonrage)) then
      if Cast(S.TipTheScales, Settings.Devastation.GCDasOffGCD.TipTheScales) then return "tip_the_scales main 24"; end
    end
    -- fire_breath
    -- Assuming we always max empower
    if S.FireBreath:IsCastable() then
      if CastAnnotated(S.FireBreath, false, "3") then return "fire_breath empower 3 main 26"; end
    end
    -- pyre,if=spell_targets.pyre>2
    if S.Pyre:IsReady() and (EnemiesCount8ySplash > 2) then
      if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre main 28"; end
    end
    -- living_flame,if=buff.burnout.up&buff.essence_burst.stack<buff.essence_burst.max_stack
    if S.LivingFlame:IsCastable() and (not Player:IsCasting(S.LivingFlame)) and (Player:BuffUp(S.BurnoutBuff) and Player:BuffStack(S.EssenceBurstBuff) < MaxEssenceBurstStack) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame main 30"; end
    end
    -- disintegrate
    if S.Disintegrate:IsReady() and EnemiesCount8ySplash < 3 then
      if Cast(S.Disintegrate, nil, nil, not Target:IsInRange(25)) then return "disintegrate main 32"; end
    end
    -- azure_strike,if=spell_targets.azure_strike>2
    if S.AzureStrike:IsCastable() and (EnemiesCount8ySplash > 2) then
      if Cast(S.AzureStrike, nil, nil, not Target:IsInRange(25)) then return "azure_strike main 34"; end
    end
    -- living_flame
    if S.LivingFlame:IsCastable() then
      if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame main 36"; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  --HR.Print("Devastation Evoker rotation is currently a work in progress, but has been updated for patch 10.0.2.")
end

HR.SetAPL(1467, APL, Init);
