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
local BossFightRemains = 11111
local FightRemains = 11111
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

-- Reset vars after combat
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- Manually added: precast firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm precombat"; end
  end
  -- Manually added: precast living_flame
  if S.LivingFlame:IsCastable() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame precombat"; end
  end
end

local function Defensives()
  
end

local function DRAoE()
  -- tip_the_scales
  if S.TipTheScales:IsCastable() then
    if Cast(S.TipTheScales, Settings.Devastation.GCDasOffGCD.TipTheScales) then return "tip_the_scales dr_aoe 2"; end
  end
  -- fire_breath,if=buff.tip_the_scales.up
  if S.FireBreath:IsCastable() and (Player:BuffUp(S.TipTheScales)) then
    if Cast(S.FireBreath, nil, nil, not Target:IsInRange(25)) then return "fire_breath dr_aoe 4"; end
  end
  -- fire_breath,if=debuff.fire_breath.down
  if S.FireBreath:IsReady() then
    local FBEmpower = 1
    if FightRemains < 20 and FightRemains >= 15 then
      FBEmpower = 2
    elseif FightRemains < 15 and ((not S.FontofMagic:IsAvailable()) or (S.FontofMagic:IsAvailable() and FightRemains >= 9)) then
      FBEmpower = 3
    elseif S.FontofMagic:IsAvailable() and FightRemains < 9 then
      FBEmpower = 4
    end
    if CastAnnotated(S.FireBreath, false, FBEmpower) then return "fire_breath dr_aoe 6"; end
  end
  -- eternity_surge
  if S.EternitySurge:IsCastable() then
    local ESEmpower = 1
    if S.EternitysSpan:IsAvailable() then
      if EnemiesCount8ySplash > 6 and S.FontofMagic:IsAvailable() then
        ESEmpower = 4
      elseif EnemiesCount8ySplash > 4 then
        ESEmpower = 3
      elseif EnemiesCount8ySplash > 2 and EnemiesCount8ySplash <= 4 then
        ESEmpower = 2
      end
    else
      if EnemiesCount8ySplash > 3 and S.FontofMagic:IsAvailable() then
        ESEmpower = 4
      elseif EnemiesCount8ySplash > 2 then
        ESEmpower = 3
      elseif EnemiesCount8ySplash == 2 then
        ESEmpower = 2
      end
    end
    if CastAnnotated(S.EternitySurge, false, ESEmpower) then return "eternity_surge dr_aoe 8"; end
  end
  -- pyre,if=buff.essence_burst.up
  if S.Pyre:IsReady() and (Player:BuffUp(S.EssenceBurstBuff)) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre dr_aoe 10"; end
  end
  -- firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm dr_aoe 12"; end
  end
  -- living_flame,if=buff.leaping_flames.up
  if S.LivingFlame:IsReady() and (not Player:IsCasting(S.LivingFlame)) and (Player:BuffUp(S.LeapingFlamesBuff) or Player:IsCasting(S.FireBreath)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame dr_aoe 14"; end
  end
  -- pyre,if=spell_targets.azure_strike>4&(prev_gcd.1.azure_strike|prev_gcd.1.disintegrate)
  if S.Pyre:IsReady() and (EnemiesCount8ySplash > 4 and (Player:PrevGCD(1, S.AzureStrike) or Player:PrevGCD(1, S.Disintegrate))) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre dr_aoe 16"; end
  end
  -- azure_strike,if=spell_targets.azure_strike>4
  if S.AzureStrike:IsCastable() and (EnemiesCount8ySplash > 4) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike dr_aoe 18"; end
  end
  -- disintegrate,if=spell_targets.azure_strike<5
  if S.Disintegrate:IsReady() and (EnemiesCount8ySplash < 5) then
    if Cast(S.Disintegrate, nil, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate dr_aoe 20"; end
  end
end

local function AOE()
  -- dragonrage,if=buff.charged_blast.stacks=20
  if S.Dragonrage:IsCastable() and (Player:BuffStack(S.ChargedBlastBuff) == 20) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage aoe 2"; end
  end
  -- fire_breath,if=debuff.fire_breath.down
  if S.FireBreath:IsReady() then
    local FBEmpower = 1
    if FightRemains < 20 and FightRemains >= 15 then
      FBEmpower = 2
    elseif FightRemains < 15 and ((not S.FontofMagic:IsAvailable()) or (S.FontofMagic:IsAvailable() and FightRemains >= 9)) then
      FBEmpower = 3
    elseif S.FontofMagic:IsAvailable() and FightRemains < 9 then
      FBEmpower = 4
    end
    if CastAnnotated(S.FireBreath, false, FBEmpower) then return "fire_breath aoe 4"; end
  end
  -- firestorm
  if S.Firestorm:IsReady() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 6"; end
  end
  -- living_flame,if=buff.leaping_flames.up
  if S.LivingFlame:IsReady() and (not Player:IsCasting(S.LivingFlame)) and (Player:BuffUp(S.LeapingFlamesBuff) or Player:IsCasting(S.FireBreath)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame aoe 8"; end
  end
  -- pyre,if=buff.essence_burst.up
  if S.Pyre:IsReady() and (Player:BuffUp(S.EssenceBurstBuff)) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre aoe 10"; end
  end
  -- eternity_surge
  if S.EternitySurge:IsReady() then
    local ESEmpower = 1
    if S.EternitysSpan:IsAvailable() then
      if EnemiesCount8ySplash > 6 and S.FontofMagic:IsAvailable() then
        ESEmpower = 4
      elseif EnemiesCount8ySplash > 4 then
        ESEmpower = 3
      elseif EnemiesCount8ySplash > 2 and EnemiesCount8ySplash <= 4 then
        ESEmpower = 2
      end
    else
      if EnemiesCount8ySplash > 3 and S.FontofMagic:IsAvailable() then
        ESEmpower = 4
      elseif EnemiesCount8ySplash > 2 then
        ESEmpower = 3
      end
    end
    if CastAnnotated(S.EternitySurge, false, ESEmpower) then return "eternity_surge aoe 12"; end
  end
  -- pyre,if=spell_targets.azure_strike>4
  if S.Pyre:IsReady() and (Enemies8ySplash > 4) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre aoe 14"; end
  end
  -- disintegrate,if=spell_targets.azure_strike<5
  if S.Disintegrate:IsReady() and (Enemies8ySplash < 5) then
    if Cast(S.Disintegrate, nil, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate aoe 16"; end
  end
  -- deep_breath,if=talent.tyranny
  if S.DeepBreath:IsReady() and (S.Tyranny:IsAvailable()) then
    if Cast(S.DeepBreath, Settings.Devastation.GCDasOffGCD.DeepBreath) then return "deep_breath aoe 18"; end
  end
  -- azure_strike
  if S.AzureStrike:IsReady() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike aoe 20"; end
  end
end

local function ST()
  -- dragonrage,if=!talent.animosity|cooldown.fire_breath.up&(!talent.eternity_surge|cooldown.eternity_surge.up)
  if S.Dragonrage:IsCastable() and ((not S.Animosity:IsAvailable()) or S.FireBreath:IsCastable() and ((not S.EternitySurge:IsAvailable()) or S.EternitySurge:IsCastable())) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage st 2"; end
  end
  -- tip_the_scales,if=cooldown.fire_breath.up&(debuff.fire_breath.down&cooldown.dragonrage.remains>24|buff.dragonrage.up)
  if S.TipTheScales:IsCastable() and (S.FireBreath:IsReady() and (Target:DebuffDown(S.FireBreathDebuff) and S.Dragonrage:CooldownRemains() > 24 or Player:BuffUp(S.Dragonrage))) then
    if Cast(S.TipTheScales, Settings.Devastation.GCDasOffGCD.TipTheScales) then return "tip_the_scales st 4"; end
  end
  -- fire_breath,if=debuff.fire_breath.down&cooldown.dragonrage.remains>24|buff.dragonrage.up
  if S.FireBreath:IsReady() and (Target:DebuffDown(S.FireBreathDebuff) and S.Dragonrage:CooldownRemains() > 24 or Player:BuffUp(S.Dragonrage)) then
    if Cast(S.FireBreath, nil, nil, not Target:IsInRange(25)) then return "fire_breath st 6"; end
  end
  -- eternity_surge,empower_to=1,if=cooldown.dragonrage.remains>24
  if S.EternitySurge:IsCastable() and (S.Dragonrage:CooldownRemains() > 24) then
    if Cast(S.EternitySurge, nil, nil, not Target:IsSpellInRange(S.EternitySurge)) then return "eternity_surge st 8"; end
  end
  -- shattering_star,if=buff.essence_burst.up
  if S.ShatteringStar:IsCastable() and (Player:BuffUp(S.EssenceBurstBuff)) then
    if Cast(S.ShatteringStar, nil, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star st 12"; end
  end
  -- firestorm,if=debuff.fire_breath.remains>cast_time|buff.snapfire.up
  if S.Firestorm:IsReady() and (Target:DebuffRemains(S.FireBreathDebuff) > S.Firestorm:CastTime() or Player:BuffUp(S.SnapfireBuff)) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 8"; end
  end
  -- living_flame,if=buff.leaping_flames.up
  if S.LivingFlame:IsReady() and (not Player:IsCasting(S.LivingFlame)) and (Player:BuffUp(S.LeapingFlamesBuff) or Player:IsCasting(S.FireBreath)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame st 10"; end
  end
  -- disintegrate,if=buff.essence_burst.down|cooldown.shattering_star.remains>3
  if S.Disintegrate:IsReady() and (Player:BuffDown(S.EssenceBurstBuff) or S.ShatteringStar:CooldownRemains() > 3) then
    if Cast(S.Disintegrate, nil, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate st 16"; end
  end
  -- living_flame
  if S.LivingFlame:IsReady() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame st 18"; end
  end
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

  -- Calculate fight_remains
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
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
    -- Manually added: Interrupts
    local ShouldReturn = Everyone.Interrupt(10, S.Quell, Settings.Commons.OffGCDasOffGCD.Quell, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- potion
    if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
    end
    -- call_action_list,name=dr_aoe,if=buff.dragonrage.up&spell_targets.azure_strike>2
    if Player:BuffUp(S.Dragonrage) and EnemiesCount8ySplash > 2 then
      local ShouldReturn = DRAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=spell_targets.azure_strike>2
    if EnemiesCount8ySplash > 2 then
      local ShouldReturn = AOE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=spell_targets.azure_strike<3
    if EnemiesCount8ySplash < 3 then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  --HR.Print("Devastation Evoker rotation is currently a work in progress, but has been updated for patch 10.0.2.")
end

HR.SetAPL(1467, APL, Init);
