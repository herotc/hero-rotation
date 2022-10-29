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
-- lua
local mathfloor  = math.floor
-- WoW API
local GetTotemInfo = GetTotemInfo
local GetTime      = GetTime


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

local function HandleNightFaeBlessings()
  local Seasons = {S.BlessingofSpring, S.BlessingofSummer, S.BlessingofAutumn, S.BlessingofWinter}
  for _, i in pairs(Seasons) do
    if i:IsCastable() then
      if Cast(i, nil, Settings.Commons.DisplayStyle.Covenant) then return "blessing_of_the_seasons"; end
    end
  end
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  -- Manually removed, as potion is not needed in precombat any longer
  -- Manually added:
  if S.DevotionAura:IsCastable() and (Player:BuffDown(S.DevotionAuraBuff)) then
    if Cast(S.DevotionAura) then return "devotion_aura precombat 2"; end
  end
  -- Manually added: consecration if in melee
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(9) then
    if Cast(S.Consecration) then return "consecrate precombat 4"; end
  end
  -- Manually added: judgment if at range
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 6"; end
  end
end

local function Defensives()
  if S.LayonHands:IsCastable() and Player:HealthPercentage() <= Settings.Holy.LoHHP then
    if HR.CastRightSuggested(S.LayonHands) then return "lay on hands"; end
  end
  if S.DivineProtection:IsCastable() and Player:HealthPercentage() <= Settings.Holy.DPHP then
    if HR.CastRightSuggested(S.DivineProtection) then return "divine protection"; end
  end
  if S.WordofGlory:IsReady() and Player:HealthPercentage() <= Settings.Holy.WoGHP and not Player:HealingAbsorbed() then
    if HR.CastRightSuggested(S.WordofGlory) then return "WOG self"; end
  end
end

local function Cooldowns()
  -- ashen_hallow
  if S.AshenHallow:IsCastable() then
    if Cast(S.AshenHallow, nil, Settings.Commons.DisplayStyle.Covenant) then return "ashen_hallow cooldowns 2"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Holy.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 4"; end
  end
  -- blessing_of_the_seasons
  local ShouldReturn = HandleNightFaeBlessings(); if ShouldReturn then return ShouldReturn; end
  -- vanquishers_hammer
  if S.VanquishersHammer:IsCastable() then
    if Cast(S.VanquishersHammer, nil, Settings.Commons.DisplayStyle.Covenant) then return "vanquishers_hammer cooldowns 6"; end
  end
  -- divine_toll
  if S.DivineToll:IsCastable() then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Covenant) then return "divine_toll cooldowns 8"; end
  end
  if (Player:BuffUp(S.AvengingWrathBuff)) then
    -- potion,if=buff.avenging_wrath.up
    if Settings.Commons.Enabled.Potions and I.PotionofSpectralIntellect:IsReady() then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 10"; end
    end
    if CDsON() then
      -- blood_fury,if=buff.avenging_wrath.up
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cooldowns 12"; end
      end
      -- berserking,if=buff.avenging_wrath.up
      if S.Berserking:IsCastable() then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cooldowns 14"; end
      end
    end
    -- holy_avenger,if=buff.avenging_wrath.up
    if S.HolyAvenger:IsCastable() then
      if Cast(S.HolyAvenger, Settings.Holy.OffGCDasOffGCD.HolyAvenger) then return "holy_avenger cooldowns 16"; end
    end
    -- use_items,if=buff.avenging_wrath.up
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- seraphim
  if S.Seraphim:IsReady() then
    if Cast(S.Seraphim, Settings.Holy.GCDasOffGCD.Seraphim) then return "seraphim cooldowns 18"; end
  end
end

local function ConsecrationTimeRemaining()
  for index=1,4 do
    local _, totemName, startTime, duration = GetTotemInfo(index)
    if totemName == S.Consecration:Name() then
      return (mathfloor(startTime + duration - GetTime() + 0.5)) or 0
    end
  end
  return 0
end

local function EvaluateCycleGlimmer(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.GlimmerofLightDebuff)
end

local function Priority()
  -- shield_of_the_righteous,if=buff.avenging_wrath.up|buff.holy_avenger.up|!talent.awakening.enabled
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffUp(S.AvengingWrathBuff) or Player:BuffUp(S.HolyAvenger) or not S.Awakening:IsAvailable()) then
    if Cast(S.ShieldoftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_of_the_righteous priority 2"; end
  end
  -- hammer_of_wrath,if=holy_power<5&spell_targets.consecration=2
  if S.HammerofWrath:IsReady() and (Player:HolyPower() < 5 and EnemiesCount8y == 2) then
    if Cast(S.HammerofWrath, Settings.Holy.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath priority 4"; end
  end
  -- lights_hammer,if=spell_targets.lights_hammer>=2
  if S.LightsHammer:IsCastable() and (EnemiesCount8y >= 2) then
    if Cast(S.LightsHammer, nil, nil, not Target:IsSpellInRange(S.LightsHammer)) then return "lights_hammer priority 6"; end
  end
  -- consecration,if=spell_targets.consecration>=2&!consecration.up
  if S.Consecration:IsCastable() and (EnemiesCount8y >= 2 and ConsecrationTimeRemaining() <= 0) then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration priority 8"; end
  end
  -- light_of_dawn,if=talent.awakening.enabled&spell_targets.consecration<=5&(holy_power>=5|(buff.holy_avenger.up&holy_power>=3))
  if S.LightofDawn:IsReady() and (S.Awakening:IsAvailable() and EnemiesCount8y <= 5 and (Player:HolyPower() >= 5 or (Player:BuffUp(S.HolyAvenger) and Player:HolyPower() >= 3))) then
    if Cast(S.LightofDawn, Settings.Holy.GCDasOffGCD.LightOfDawn, nil, not Target:IsSpellInRange(S.LightofDawn)) then return "light_of_dawn priority 10"; end
  end
  -- shield_of_the_righteous,if=spell_targets.consecration>5
  if S.ShieldoftheRighteous:IsReady() and (EnemiesCount8y > 5) then
    if Cast(S.ShieldoftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "shield_of_the_righteous priority 12"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Cast(S.HammerofWrath, Settings.Holy.GCDasOffGCD.HammerOfWrath, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath priority 14"; end
  end
  -- judgment
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment priority 16"; end
  end
  -- lights_hammer
  if S.LightsHammer:IsCastable() then
    if Cast(S.LightsHammer, nil, nil, not Target:IsSpellInRange(S.LightsHammer)) then return "lights_hammer priority 18"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (ConsecrationTimeRemaining() <= 0) then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration priority 20"; end
  end
  -- holy_shock,damage=1
  if S.HolyShock:IsReady() then
    if Cast(S.HolyShock, nil, nil, not Target:IsSpellInRange(S.HolyShock)) then return "holy_shock priority 22"; end
  end
  -- crusader_strike,if=cooldown.crusader_strike.charges=2
  if S.CrusaderStrike:IsReady() and (S.CrusaderStrike:Charges() == 2) then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike priority 24"; end
  end
  -- holy_prism,target=self,if=active_enemies>=2
  if S.HolyPrism:IsReady() and (EnemiesCount8y >= 2) then
    if HR.CastAnnotated(S.HolyPrism, false, "SELF") then return "holy_prism on self priority 26"; end
  end
  -- holy_prism
  if S.HolyPrism:IsReady() then
    if Cast(S.HolyPrism, nil, nil, not Target:IsSpellInRange(S.HolyPrism)) then return "holy_prism priority 28"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials) then return "arcane_torrent priority 30"; end
  end
  -- light_of_dawn,if=talent.awakening.enabled&spell_targets.consecration<=5
  if S.LightofDawn:IsReady() and (S.Awakening:IsAvailable() and EnemiesCount8y <= 5) then
    if Cast(S.LightofDawn, Settings.Holy.GCDasOffGCD.LightOfDawn, nil, not Target:IsSpellInRange(S.LightofDawn)) then return "light_of_dawn priority 32"; end
  end
  -- crusader_strike
  if S.CrusaderStrike:IsReady() then
    if Cast(S.CrusaderStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "crusader_strike priority 34"; end
  end
  -- consecration
  if S.Consecration:IsReady() then
    if Cast(S.Consecration, nil, nil, not Target:IsInMeleeRange(8)) then return "consecration priority 36"; end
  end
end

-- APL Main
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  if AoEON() then
    EnemiesCount8y = #Enemies8y
    EnemiesCount30y = #Enemies30y
  else
    EnemiesCount8y = 1
    EnemiesCount30y = 1
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Manually added: Defensives
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldowns
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=priority
    local ShouldReturn = Priority(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Pool
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Holy Paladin rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(65, APL, Init)
