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
local PrescienceTargets = {}
local MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
local FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
local BossFightRemains = 11111
local FightRemains = 11111

-- Stun Interrupts
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

-- Reset variables after fights
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  MaxEmpower = (S.FontofMagic:IsAvailable()) and 4 or 3
  FoMEmpowerMod = (S.FontofMagic:IsAvailable()) and 0.8 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

local function PrescienceCheck()
end

local function BlisteringScalesCheck()
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    Group = Player
  end

  if Group == Player then
    return Player:BuffStack(S.BlisteringScalesBuff)
  else
    for unitID, Char in pairs(Group) do
      if Char:Exists() and (Char:IsTankingAoE(8) or Char:IsTanking(Target)) and UnitGroupRolesAssigned(unitID) == "TANK" then
        return Char:BuffStack(S.BlisteringScalesBuff)
      end
    end
  end

  return 0
end

local function Precombat()
  -- Group buff check
  if S.BlessingoftheBronze:IsCastable() and (Player:BuffDown(S.BlessingoftheBronzeBuff) or Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff)) then
    if Cast(S.BlessingoftheBronze, Settings.Commons.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat"; end
  end
  -- blistering_scales,if=buff.blistering_scales.stack<10&active_dot.blistering_scales=0
  if S.BlisteringScales:IsCastable() and (BlisteringScalesCheck() < 10) then
    if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales precombat 2"; end
  end
  -- prescience
  if S.Prescience:IsCastable() then
    if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience precombat 4"; end
  end
  -- tip_the_scales
  if CDsON() and S.TipTheScales:IsCastable() then
    if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales precombat 6"; end
  end
  -- ebon_might
  if S.EbonMight:IsReady() then
    if Cast(S.EbonMight, Settings.Augmentation.GCDasOffGCD.EbonMight) then return "ebon_might precombat 8"; end
  end
  -- living_flame
  if S.LivingFlame:IsCastable() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame precombat 10"; end
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
    -- unravel
    if S.Unravel:IsReady() and Target:EnemyAbsorb() then
      if Cast(S.Unravel, Settings.Commons.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 2"; end
    end
    -- living_flame,if=time<cast_time*2
    if S.LivingFlame:IsReady() and (HL.CombatTime() < S.LivingFlame:CastTime() * 2) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 4"; end
    end
    -- prescience
    if S.Prescience:IsCastable() then
      if Cast(S.Prescience, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "prescience main 6"; end
    end
    -- ebon_might,if=buff.ebon_might.refreshable
    if S.EbonMight:IsReady() and Player:BuffRefreshable(S.EbonMightSelfBuff, 4) then
      if Cast(S.EbonMight, Settings.Augmentation.GCDasOffGCD.EbonMight) then return "ebon_might main 8"; end
    end
    -- breath_of_eons,if=buff.ebon_might.up|cooldown.ebon_might.remains<4
    if CDsON() and S.BreathofEons:IsCastable() and (Player:BuffUp(S.EbonMightSelfBuff) or S.EbonMight:CooldownRemains() < 4) then
      if Cast(S.BreathofEons, Settings.Augmentation.GCDasOffGCD.BreathOfEons, nil, not Target:IsInRange(50)) then return "breath_of_eons main 10"; end
    end
    -- use_items,if=active_dot.temporal_wound>0|cooldown.breath_of_eons.remains>30|fight_remains<30
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and (S.TemporalWoundDebuff:AuraActiveCount() > 0 or S.BreathofEons:CooldownRemains() > 30 or FightRemains < 30) then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- potion,if=active_dot.temporal_wound>0|cooldown.breath_of_eons.remains>30|fight_remains<30
    if Settings.Commons.Enabled.Potions and (S.TemporalWoundDebuff:AuraActiveCount() > 0 or S.BreathofEons:CooldownRemains() > 30 or FightRemains < 30) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 12"; end
      end
    end
    -- living_flame,if=buff.leaping_flames.up&cooldown.fire_breath.remains<cast_time
    if S.LivingFlame:IsReady() and (Player:BuffUp(S.LeapingFlamesBuff) and S.FireBreath:CooldownRemains() < S.LivingFlame:CastTime()) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 14"; end
    end
    -- time_skip,if=cooldown.breath_of_eons.true_remains>15&cooldown.fire_breath.true_remains>15&cooldown.upheaval.true_remains>15
    if CDsON() and S.TimeSkip:IsCastable() and (S.BreathofEons:CooldownRemains() > 15 and S.FireBreath:CooldownRemains() > 15 and S.Upheaval:CooldownRemains() > 15) then
      if Cast(S.TimeSkip, Settings.Augmentation.GCDasOffGCD.TimeSkip) then return "time_skip main 16"; end
    end
    -- tip_the_scales,if=cooldown.fire_breath.remains<gcd|cooldown.upheaval.remains<gcd
    if CDsON() and S.TipTheScales:IsCastable() and (S.FireBreath:CooldownRemains() < Player:GCD() or S.Upheaval:CooldownRemains() < Player:GCD()) then
      if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales main 18"; end
    end
    -- fire_breath,empower_to=max,if=empowering.fire_breath|buff.ebon_might.remains>cast_time
    if S.FireBreath:IsCastable() and (Player:BuffRemains(S.EbonMightSelfBuff) > (3.25 * Player:SpellHaste() * FoMEmpowerMod)) then
      if CastAnnotated(S.FireBreath, false, MaxEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower " .. MaxEmpower .. " main 20"; end
    end
    -- upheaval,empower_to=1,if=active_enemies<2&(empowering.upheaval|buff.ebon_might.remains>cast_time)
    -- upheaval,empower_to=2,if=active_enemies<4&(empowering.upheaval|buff.ebon_might.remains>cast_time)
    -- upheaval,empower_to=3,if=active_enemies<6&(empowering.upheaval|buff.ebon_might.remains>cast_time)
    -- upheaval,empower_to=max,if=active_enemies>5&(empowering.upheaval|buff.ebon_might.remains>cast_time)
    if S.Upheaval:IsCastable() and (Player:BuffRemains(S.EbonMightSelfBuff) > (3.25 * Player:SpellHaste() * FoMEmpowerMod)) then
      local UpheavalEmpower = 1
      if EnemiesCount8ySplash > 1 and EnemiesCount8ySplash < 4 then
        UpheavalEmpower = 2
      elseif EnemiesCount8ySplash > 3 and EnemiesCount8ySplash < 6 then
        UpheavalEmpower = 3
      elseif EnemiesCount8ySplash > 5 then
        UpheavalEmpower = MaxEmpower
      end
      if CastAnnotated(S.Upheaval, false, UpheavalEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "upheaval empower " .. UpheavalEmpower .. " main 22"; end
    end
    -- blistering_scales,if=buff.blistering_scales.down&active_dot.blistering_scales=0
    if S.BlisteringScales:IsCastable() and (BlisteringScalesCheck() == 0) then
      if Cast(S.BlisteringScales, nil, Settings.Augmentation.DisplayStyle.AugBuffs) then return "blistering_scales main 24"; end
    end
    -- eruption,if=buff.ebon_might.remains>cast_time|essence.time_to_max<cast_time|buff.essence_burst.up
    if S.Eruption:IsReady() and (Player:BuffRemains(S.EbonMightSelfBuff) > S.Eruption:CastTime() or Player:EssenceTimeToMax() < S.Eruption:CastTime() or Player:BuffUp(S.EssenceBurstBuff)) then
      if Cast(S.Eruption, nil, nil, not Target:IsInRange(25)) then return "eruption main 26"; end
    end
    -- verdant_embrace,if=talent.scarlet_adaptation&buff.ebon_might.down&buff.ancient_flame.down
    if S.VerdantEmbrace:IsReady() and (S.ScarletAdaptation:IsAvailable() and Player:BuffDown(S.EbonMightSelfBuff) and Player:BuffDown(S.AncientFlameBuff)) then
      if Cast(S.VerdantEmbrace) then return "verdant_embrace main 28"; end
    end
    -- living_flame,if=!moving|buff.hover.up|talent.pupil_of_alexstrasza
    if S.LivingFlame:IsCastable() and ((not Player:IsMoving()) or S.PupilofAlexstrasza:IsAvailable()) then
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame main 30"; end
    end
    -- azure_strike,if=!talent.pupil_of_alexstrasza&cooldown.hover.remains>0
    if S.AzureStrike:IsCastable() and (not S.PupilofAlexstrasza:IsAvailable()) then
      if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike main 20"; end
    end
    -- pool if nothing else to do
    if CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool"; end
  end
end

local function Init()
  S.TemporalWoundDebuff:RegisterAuraTracking()

  HR.Print("Augmentation Evoker rotation is very much a work-in-progress. It will improve once a Simulationcraft APL exists.")
end

HR.SetAPL(1473, APL, Init);
