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

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs
local AEMajor    = HL.Spell:MajorEssence()

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection
if AEMajor ~= nil then
  S.HeartEssence                          = Spell(AESpellIDs[AEMajor.ID])
end

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local ActiveMitigationNeeded
local IsTanking
local PassiveEssence
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

HL:RegisterForEvent(function()
  AEMajor        = HL.Spell:MajorEssence()
  S.HeartEssence = Spell(AESpellIDs[AEMajor.ID])
end, "AZERITE_ESSENCE_ACTIVATED", "AZERITE_ESSENCE_CHANGED")

HL:RegisterForEvent(function()
  S.ConcentratedFlame:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ConcentratedFlame:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function EvaluateCycleJudgment200(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.JudgmentDebuff)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- potion
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 2"; end
  end
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if HR.Cast(S.Consecration) then return "consecration 4"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment) then return "lights_judgment 6"; end
  end
  -- Manually added: avengers_shield
  if S.AvengersShield:IsCastable() then
    if HR.Cast(S.AvengersShield) then return "avengers_shield 8"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if HR.Cast(S.Judgment) then return "judgment 10"; end
  end
end

local function Defensives()
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if HR.Cast(S.GuardianofAncientKings) then return "guardian_of_ancient_kings defensive"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if HR.Cast(S.ArdentDefender) then return "ardent_defender defensive"; end
  end
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.WordofGloryHP and not Player:HealingAbsorbed()) then
    if HR.Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordofGlory) then return "word_of_glory defensive"; end
  end
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.ShieldoftheRighteousHP)) then
    if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous) then return "shield_of_the_righteous defensive"; end
  end
end

local function Cooldowns()
  -- fireblood,if=buff.avenging_wrath.up
  if S.Fireblood:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 32"; end
  end
  -- seraphim
  if S.Seraphim:IsReady() then
    if HR.Cast(S.Seraphim, Settings.Protection.GCDasOffGCD.Seraphim) then return "seraphim 34"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if HR.Cast(S.AvengingWrath, Settings.Protection.GCDasOffGCD.AvengingWrath) then return "avenging_wrath 36"; end
  end
  -- holy_avenger,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains>60
  if S.HolyAvenger:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() > 60) then
    if HR.Cast(S.HolyAvenger) then return "holy_avenger 38"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.AvengingWrathBuff)) then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 40"; end
  end
  -- use_items,if=buff.seraphim.up|!talent.seraphim.enabled
  if (Player:BuffUp(S.SeraphimBuff) or not S.Seraphim:IsAvailable()) then
    local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- moment_of_glory,if=prev_gcd.1.avengers_shield&cooldown.avengers_shield.remains
  if S.MomentofGlory:IsCastable() and (Player:PrevGCD(1, S.AvengersShield) and not S.AvengersShield:CooldownUp()) then
    if HR.Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentofGlory) then return "moment_of_glory 42"; end
  end
  -- heart_essence
  if S.HeartEssence ~= nil and not PassiveEssence and S.HeartEssence:IsCastable() then
    if HR.Cast(S.HeartEssence, nil, Settings.Commons.EssenceDisplayStyle) then return "heart_essence 44"; end
  end
end

local function Standard()
  -- shield_of_the_righteous,if=debuff.judgment.up&(debuff.vengeful_shock.up|!conduit.vengeful_shock.enabled)
  if S.ShieldoftheRighteous:IsReady() and (Target:DebuffUp(S.JudgmentDebuff) and (Target:DebuffUp(S.VengefulShockDebuff) or not S.VengefulShock:IsAvailable())) then
    if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous, nil, not Target:IsSpellInRange(S.ShieldoftheRighteous)) then return "shield_of_the_righteous 62"; end
  end
  -- shield_of_the_righteous,if=holy_power=5|buff.holy_avenger.up|holy_power=4&talent.sanctified_wrath.enabled&buff.avenging_wrath.up
  if S.ShieldoftheRighteous:IsReady() and (Player:HolyPower() == 5 or Player:BuffUp(S.HolyAvengerBuff) or Player:HolyPower() == 4 and S.SanctifiedWrath:IsAvailable() and Player:BuffUp(S.AvengingWrathBuff)) then
    if HR.Cast(S.ShieldoftheRighteous, Settings.Protection.OffGCDasOffGCD.ShieldoftheRighteous, nil, not Target:IsSpellInRange(S.ShieldoftheRighteous)) then return "shield_of_the_righteous 64"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=charges=2|!talent.crusaders_judgment.enabled
  if S.Judgment:IsReady() and (S.Judgment:Charges() == 2 or not S.CrusadersJudgment:IsAvailable()) then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment 66"; end
  end
  -- avengers_shield,if=debuff.vengeful_shock.down&conduit.vengeful_shock.enabled
  if S.AvengersShield:IsCastable() and (Target:DebuffDown(S.VengefulShockDebuff) and S.VengefulShock:IsAvailable()) then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 68"; end
  end
  -- hammer_of_wrath
  -- Note: Added IsUsable check. IsReady checks IsCastable and IsUsableP, which always returns true when not on CD
  if S.HammerofWrath:IsReady() and S.HammerofWrath:IsUsable() then
    if HR.Cast(S.HammerofWrath, nil, nil, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath 70"; end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 72"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment 74"; end
  end
  -- vanquishers_hammer
  if S.VanquishersHammer:IsReady() then
    if HR.Cast(S.VanquishersHammer, nil, nil, not Target:IsSpellInRange(S.VanquishersHammer)) then return "vanquishers_hammer 76"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if HR.Cast(S.Consecration) then return "consecration 78"; end
  end
  -- divine_toll
  if S.DivineToll:IsReady() then
    if HR.Cast(S.DivineToll, nil, nil, not Target:IsSpellInRange(S.DivineToll)) then return "divine_toll 80"; end
  end
  -- blessed_hammer,strikes=2.4,if=charges=3
  if S.BlessedHammer:IsCastable() and (S.BlessedHammer:Charges() == 3) then
    if HR.Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer 82"; end
  end
  -- ashen_hallow
  if S.AshenHallow:IsReady() then
    if HR.Cast(S.AshenHallow) then return "ashen_hallow 84"; end
  end
  -- hammer_of_the_righteous,if=charges=2
  if S.HammeroftheRighteous:IsCastable() and (S.HammeroftheRighteous:Charges() == 2) then
    if HR.Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous 86"; end
  end
  -- word_of_glory,if=buff.vanquishers_hammer.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.VanquishersHammerBuff)) then
    if HR.Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordofGlory) then return "word_of_glory 88"; end
  end
  -- blessed_hammer,strikes=2.4
  if S.BlessedHammer:IsCastable() then
    if HR.Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer 90"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if HR.Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous 92"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 94"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if HR.Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent 96"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if HR.Cast(S.Consecration) then return "consecration 98"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up&!covenant.necrolord
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff) and not S.VanquishersHammer:IsAvailable()) then
    if HR.Cast(S.WordofGlory, Settings.Protection.GCDasOffGCD.WordofGlory) then return "word_of_glory 100"; end
  end
end

-- APL Main
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  if (AoEON()) then
    EnemiesCount8y = #Enemies8y
    EnemiesCount30y = #Enemies30y
  else
    EnemiesCount8y = 1
    EnemiesCount30y = 1
  end
  
  ActiveMitigationNeeded = Player:ActiveMitigationNeeded()
  IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target)
  PassiveEssence = (Spell:MajorEssenceEnabled(AE.VisionofPerfection) or Spell:MajorEssenceEnabled(AE.ConflictandStrife) or Spell:MajorEssenceEnabled(AE.TheFormlessVoid) or Spell:MajorEssenceEnabled(AE.TouchoftheEverlasting))
  
  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Defensives!
    if (IsTanking) then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldowns
    if (CDsON()) then
      local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard
    if (true) then
      local ShouldReturn = Standard(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Pool, if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()

end

HR.SetAPL(66, APL, Init)
