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
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

-- Rotation Var
local ActiveMitigationNeeded
local IsTanking
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

local function EvaluateCycleJudgment200(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.JudgmentDebuff)
end

local function EvaluateCycleHammerofWrath(TargetUnit)
  return TargetUnit:HealthPercentage() < 20 or Player:BuffUp(S.AvengingWrathBuff)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- devotion_aura
  if S.DevotionAura:IsCastable() and (Player:BuffDown(S.DevotionAuraBuff)) then
    if HR.Cast(S.DevotionAura) then return "devotion_aura"; end
  end
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
    if HR.Cast(S.LightsJudgment, nil, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 6"; end
  end
  -- Manually added: avengers_shield
  if S.AvengersShield:IsCastable() then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 8"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if HR.Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment 10"; end
  end
end

local function Defensives()
  if Player:HealthPercentage() <= 10 and S.LayonHands:IsCastable() then
    if HR.CastSuggested(S.Layonhands) then return "LOH"; end
  end
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if HR.CastSuggested(S.GuardianofAncientKings) then return "guardian_of_ancient_kings defensive"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if HR.CastSuggested(S.ArdentDefender) then return "ardent_defender defensive"; end
  end
  -- todo: logic right here to check if you have enough SOTR buff up - you might have to choose between dropping buff and healing self
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.WordofGloryHP and not Player:HealingAbsorbed()) then
    if HR.Cast(S.WordofGlory) then return "word_of_glory defensive"; end
  end
  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.ShieldoftheRighteousHP)) then
    if HR.CastRightSuggested(S.ShieldoftheRighteous) then return "shield_of_the_righteous defensive"; end
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
  -- ashen_hallow
  if S.AshenHallow:IsReady() then
    if HR.Cast(S.AshenHallow, nil, Settings.Commons.CovenantDisplayStyle) then return "ashen_hallow 84"; end
  end
  -- divine_toll
  if S.DivineToll:IsReady() and Player:HolyPower() <= 1 then
    if HR.Cast(S.DivineToll, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.DivineToll)) then return "divine_toll 80"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and (Player:BuffUp(S.AvengingWrathBuff)) then
    if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 40"; end
  end
  -- use_items,if=buff.seraphim.up|!talent.seraphim.enabled
  if (Player:BuffUp(S.SeraphimBuff) or not S.Seraphim:IsAvailable()) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- moment_of_glory,if=prev_gcd.1.avengers_shield&cooldown.avengers_shield.remains
  if S.MomentofGlory:IsCastable() and (Player:PrevGCD(1, S.AvengersShield) and not S.AvengersShield:CooldownUp()) then
    if HR.Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then return "moment_of_glory 42"; end
  end
end

local function Standard()
  -- shield_of_the_righteous,if=debuff.judgment.up&(debuff.vengeful_shock.up|!conduit.vengeful_shock.enabled)
  if S.ShieldoftheRighteous:IsReady() and (Target:DebuffUp(S.JudgmentDebuff) and (Target:DebuffUp(S.VengefulShockDebuff) or not S.VengefulShock:ConduitEnabled())) then
    if HR.CastRightSuggested(S.ShieldoftheRighteous) then return "shield_of_the_righteous 62"; end
  end

  -- shield_of_the_righteous,if=holy_power=5|buff.holy_avenger.up|holy_power=4&talent.sanctified_wrath.enabled&buff.avenging_wrath.up
  if S.ShieldoftheRighteous:IsReady() and (Player:HolyPower() == 5 or Player:BuffUp(S.HolyAvengerBuff) or Player:HolyPower() == 4 and S.SanctifiedWrath:IsAvailable() and Player:BuffUp(S.AvengingWrathBuff)) then
    if HR.CastRightSuggested(S.ShieldoftheRighteous) then return "shield_of_the_righteous 64"; end
  end

  -- NOTE(MRDMND) - added an AOE prio on this over judgment
  if S.AvengersShield:IsCastable() and #Player:GetEnemiesInMeleeRange(8) >= 3 then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 68"; end
  end

  -- judgment,target_if=min:debuff.judgment.remains,if=charges=2|!talent.crusaders_judgment.enabled
  if S.Judgment:IsReady() and (S.Judgment:Charges() == 2 or not S.CrusadersJudgment:IsAvailable()) then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment 66"; end
  end
  -- avengers_shield,if=debuff.vengeful_shock.down&conduit.vengeful_shock.enabled
  if S.AvengersShield:IsCastable() and (Target:DebuffDown(S.VengefulShockDebuff) and S.VengefulShock:ConduitEnabled()) then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 68"; end
  end
  -- hammer_of_wrath
  -- Note: Added IsUsable check. IsReady checks IsCastable and IsUsableP, which always returns true when not on CD
  if S.HammerofWrath:IsReady() and S.HammerofWrath:IsUsable() then
    if Everyone.CastCycle(S.HammerofWrath, Enemies30y, EvaluateCycleHammerofWrath, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer of wrath"; end
  end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if HR.Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield 72"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment 74"; end
  end
  -- consecration,if=!consecration.up k
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if HR.Cast(S.Consecration) then return "consecration 78"; end
  end
  -- vanquishers_hammer
  if S.VanquishersHammer:IsReady() then
    if HR.Cast(S.VanquishersHammer, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.VanquishersHammer)) then return "vanquishers_hammer 76"; end
  end
    -- blessed_hammer,strikes=2.4,if=charges=3
  if S.BlessedHammer:IsCastable() and (S.BlessedHammer:Charges() == 3) then
    if HR.Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer 82"; end
  end
  
  -- hammer_of_the_righteous,if=charges=2
  if S.HammeroftheRighteous:IsCastable() and (S.HammeroftheRighteous:Charges() == 2) then
    if HR.Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous 86"; end
  end
  -- word_of_glory,if=buff.vanquishers_hammer.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.VanquishersHammerBuff)) then
    if HR.Cast(S.WordofGlory) then return "word_of_glory 88"; end
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
    if HR.Cast(S.ArcaneTorrent) then return "arcane_torrent 96"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if HR.Cast(S.Consecration) then return "consecration 98"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up&!covenant.necrolord
  -- TODO: this should not fire if everyone in your party is full HP, but we DO want to heal teammates if we're topped at this point
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff) and not S.VanquishersHammer:IsAvailable()) then
    if HR.Cast(S.WordofGlory) then return "word_of_glory 100"; end
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
  HR.Print("Protection Paladin rotation is currently a work in progress.")
end

HR.SetAPL(66, APL, Init)
