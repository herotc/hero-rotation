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
local CastPooling   = HR.CastPooling
local CastAnnotated = HR.CastAnnotated
local CastSuggested = HR.CastSuggested
local Evoker        = HR.Commons.Evoker
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Augmentation
local I = Item.Evoker.Augmentation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  Augmentation = HR.GUISettings.APL.Evoker.Augmentation
}

-- Rotation Variables
local VarOpenerDone = false
local BossFightRemains = 11111
local FightRemains = 11111

-- Stun Interrupts
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

-- Reset variables after fights
HL:RegisterForEvent(function()
  VarOpenerDone = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function Precombat()
  -- prescience
  if S.Prescience:IsCastable() then
    if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience precombat 2"; end
  end
  -- blistering_scales
  if S.BlisteringScales:IsCastable() then
    if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales precombat 4"; end
  end
  -- tip_the_scales
  if CDsON() and S.TipTheScales:IsCastable() then
    if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales precombat 6"; end
  end
  -- ebon_might
  if S.EbonMight:IsReady() then
    if Cast(S.EbonMight) then return "ebon_might precombat 8"; end
  end
  -- living_flame
  if S.LivingFlame:IsCastable() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame precombat 10"; end
  end
end

local function Cooldowns()
  -- time_skip,if=prev_gcd.1.breath_of_eons
  if CDsON() and S.TimeSkip:IsCastable() and (Player:PrevGCDP(1, S.BreathofEons)) then
    if Cast(S.TimeSkip, Settings.Augmentation.GCDasOffGCD.TimeSkip) then return "time_skip cooldowns 2"; end
  end
  -- breath_of_eons
  if CDsON() and S.BreathofEons:IsCastable() then
    if Cast(S.BreathofEons, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "breath_of_eons cooldowns 4"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 6"; end
    end
  end
end

local function Opener()
  -- fire_breath,if=buff.tip_the_scales.up
  if S.FireBreath:IsCastable() and (Player:BuffUp(S.TipTheScales)) then
    if CastAnnotated(S.FireBreath, false, "TTS", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath opener 2"; end
  end
  -- upheaval,empower_to=1
  -- Note: 15s TimeSinceLastCast to avoid sticking on this line
  if S.Upheaval:IsCastable() and S.Upheaval:TimeSinceLastCast() >= 15 then
    if CastAnnotated(S.Upheaval, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval opener 4"; end
  end
  -- call_action_list,name=cooldowns
  local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
  -- prescience
  if S.Prescience:IsCastable() then
    if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience opener 8"; end
  end
  -- living_flame,if=buff.leaping_flames.up
  if S.LivingFlame:IsReady() and (Player:BuffUp(S.LeapingFlamesBuff)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame opener 10"; end
  end
  -- fire_breath,empower_to=4,if=talent.font_of_magic
  -- fire_breath,empower_to=3,if=!talent.font_of_magic
  local FBEmpower = 3
  if S.FontofMagic:IsAvailable() then
    FBEmpower = 4
  end
  if S.FireBreath:IsCastable() then
    if CastAnnotated(S.FireBreath, false, FBEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower " .. FBEmpower .. " opener 12"; end
  end
  -- living_flame,if=prev_gcd.1.eruption
  if S.LivingFlame:IsReady() and (Player:PrevGCDP(1, S.Eruption)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame opener 12"; end
  end
  -- eruption
  if S.Eruption:IsReady() then
    if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption opener 14"; end
  end
end

-- APL Main
local function APL()
  Enemies25y = Player:GetEnemiesInRange(25)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if (AoEON()) then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies25y, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- interrupts
    local ShouldReturn = Everyone.Interrupt(25, S.Quell, Settings.Commons.OffGCDasOffGCD.Quell, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=opener
    if Player:PrevGCDP(1, S.Eruption) then VarOpenerDone = true end
    if not VarOpenerDone then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Opener()"; end
    end
    if HL.CombatTime() < 30 then
      -- living_flame,if=(prev_gcd.1.eruption|essence<2)&time<30
      if S.LivingFlame:IsReady() and (Player:PrevGCDP(1, S.Eruption) or Player:Essence() < 2) then
        if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame main 2"; end
      end
      -- eruption,if=time<30
      if S.Eruption:IsReady() then
        if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption main 4"; end
      end
    end
    -- call_action_list,name=cooldowns
    if CDsON() then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- prescience
    if S.Prescience:IsCastable() then
      if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience main 6"; end
    end
    -- blistering_scales
    if S.BlisteringScales:IsCastable() then
      if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales main 8"; end
    end
    -- ebon_might
    if S.EbonMight:IsReady() then
      if Cast(S.EbonMight) then return "ebon_might main 10"; end
    end
    -- fire_breath,empower_to=active_enemies-1
    if S.FireBreath:IsCastable() then
      local FBEmpower = 1
      if EnemiesCount8ySplash > 2 then FBEmpower = EnemiesCount8ySplash - 1 end
      if CastAnnotated(S.FireBreath, false, FBEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower " .. FBEmpower .. " main 12"; end
    end
    -- upheaval,empower_to=1
    if S.Upheaval:IsCastable() then
      if CastAnnotated(S.Upheaval, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval main 14"; end
    end
    -- eruption
    if S.Eruption:IsReady() then
      if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption main 16"; end
    end
    -- living_flame
    if S.LivingFlame:IsReady() and not Player:IsMoving() then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 18"; end
    end
    -- azure_strike
    -- Using azure_strike as a fallthru for movement
    if S.AzureStrike:IsCastable() then
      if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike main 20"; end
    end
  end
end

local function Init()
  HR.Print("Augmentation Evoker rotation is very much a work-in-progress. It will improve once a Simulationcraft APL exists.")
end

HR.SetAPL(1473, APL, Init);
