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


-- Define S/I for spell and item arrays
local S = Spell.Paladin.Holy
local I = Item.Paladin.Holy

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Holy = HR.GUISettings.APL.Paladin.Holy
}

local function EvaluateCycleJudgment201(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.JudgmentDebuff)
end

local function Precombat()
  if S.DevotionAura:IsCastable() and (Player:BuffDown(S.DevotionAuraBuff)) then
    if HR.Cast(S.DevotionAura) then return "devotion aura"; end
  end
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(9) then
    if HR.Cast(S.Consecration) then return "pre-combat consecrate"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if HR.Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "pre-combat judgment"; end
  end
end

local function Defensives()
  if S.LayonHands:IsCastable() and Player:HealthPercentage() <= 10 then
    if HR.CastRightSuggested(S.LayonHands) then return "lay on hands"; end
  end
  if S.DivineProtection:IsCastable() and Player:HealthPercentage() <= 40 then
    if HR.CastRightSuggested(S.DivineProtection) then return "divine protection"; end
  end
  if S.WordofGlory:IsReady() and Player:HealthPercentage() <= 60 and not Player:HealingAbsorbed() then
    if HR.CastRightSuggested(S.WordofGlory) then return "WOG self"; end
  end
end

local function Cooldowns()
  -- seraphim
  if S.Seraphim:IsReady() then
    if HR.Cast(S.Seraphim, true) then return "seraphim 35"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if HR.Cast(S.AvengingWrath, true) then return "avenging_wrath 37"; end
  end
  -- holy_avenger,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains>61
  if S.HolyAvenger:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() > 61) then
    if HR.Cast(S.HolyAvenger, true) then return "holy_avenger 39"; end
  end
  -- use_items,if=buff.seraphim.up|!talent.seraphim.enabled
  if (Player:BuffUp(S.SeraphimBuff) or not S.Seraphim:IsAvailable()) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function ConsecrationTimeRemaining()
  for index=1,4 do
    local _, totemName, startTime, duration = GetTotemInfo(index)
    if totemName == S.Consecration:Name() then
      return (floor(startTime + duration - GetTime() + 0.5)) or 0
    end
  end
  return 0
end

local function EvaluateCycleGlimmer(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.GlimmerofLightDebuff)
end

local function Standard()
    if S.Consecration:IsCastable() and ConsecrationTimeRemaining() <= 0 and Target:IsInMeleeRange(9) then
        if HR.Cast(S.Consecration) then return "consecrate"; end
    end

    if Player:HolyPower() >= 3 or Player:BuffUp(S.DivinePurposeBuff) then
        if HR.CastRightSuggested(S.ShieldoftheRighteous) then return "dump"; end
    end

    -- todo: scan targets
    if S.HammerofWrath:IsCastable() and S.HammerofWrath:IsUsable() then
        if HR.Cast(S.HammerofWrath) then return "execute"; end
    end

    if S.Judgment:IsCastable() then
        if HR.Cast(S.Judgment) then return "judgment"; end
    end

    if S.HolyShock:IsCastable() then
        if Everyone.CastCycle(S.HolyShock, Enemies30y, EvaluateCycleGlimmer, not Target:IsSpellInRange(S.HolyShock)) then return "holy shock"; end
    end

    if S.CrusaderStrike:IsCastable() and (S.HolyShock:CooldownRemains() > 1.5 + Player:GCD() and S.CrusaderStrike:Charges() == 1 and S.CrusaderStrike:CooldownRemains() <= Player:GCD()) or (S.HolyShock:CooldownRemains() > 0 and S.CrusaderStrike:Charges() == 2) then
        if HR.Cast(S.CrusaderStrike) then return "crusader strike"; end
    end

    if S.Consecration:IsCastable() and ConsecrationTimeRemaining() <= 0 and S.HolyShock:CooldownRemains() > Player:GCD() and Target:IsInMeleeRange(9) then
        if HR.Cast(S.Consecration) then return "consecration application"; end
    end

    if S.CrusaderStrike:IsCastable() and S.HolyShock:CooldownRemains() > 1.5 + Player:GCD() then
        if HR.Cast(S.CrusaderStrike) then return "crusader strike"; end
    end

    if S.Consecration:IsCastable() and S.HolyShock:CooldownRemains() > Player:GCD() and Target:IsInMeleeRange(9) then
        if HR.Cast(S.Consecration) then return "filler consecrate refresh"; end
    end
end

-- APL Main
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  EnemiesCount8y = #Enemies8y
  EnemiesCount30y = #Enemies30y


  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(65, APL, Init)
