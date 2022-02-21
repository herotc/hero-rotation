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

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

local function EvaluateCycleJudgment200(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.JudgmentDebuff)
end

local function EvaluateCycleHammerofWrath(TargetUnit)
  return TargetUnit:HealthPercentage() < 20 or Player:BuffUp(S.AvengingWrathBuff)
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
  -- devotion_aura
  if S.DevotionAura:IsCastable() and (Player:BuffDown(S.DevotionAuraBuff)) then
    if Cast(S.DevotionAura) then return "devotion_aura precombat 2"; end
  end
  -- snapshot_stats
  -- potion
  -- Manually removed, as this is no longer needed in Precombat
  -- consecration
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if Cast(S.Consecration) then return "consecration precombat 4"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, nil, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment precombat 6"; end
  end
  -- ashen_hallow
  if S.AshenHallow:IsCastable() and Target:IsInRange(30) then
    if Cast(S.AshenHallow, nil, Settings.Commons.DisplayStyle.Covenant) then return "ashen_hallow precombat 8"; end
  end
  -- Manually added: avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield precombat 10"; end
  end
  -- Manually added: judgment
  if S.Judgment:IsReady() then
    if Cast(S.Judgment, nil, nil, not Target:IsSpellInRange(S.Judgment)) then return "judgment precombat 12"; end
  end
end

local function Defensives()
  if Player:HealthPercentage() <= Settings.Protection.LoHHP and S.LayonHands:IsCastable() then
    if Cast(S.LayonHands, nil, Settings.Protection.DisplayStyle.Defensives) then return "lay_on_hands defensive 2"; end
  end
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if Cast(S.GuardianofAncientKings, nil, Settings.Protection.DisplayStyle.Defensives) then return "guardian_of_ancient_kings defensive 4"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if Cast(S.ArdentDefender, nil, Settings.Protection.DisplayStyle.Defensives) then return "ardent_defender defensive 6"; end
  end
  -- cast word of glory on us if it's a) free or b) probably not going to drop sotr
  if S.WordofGlory:IsReady() and (Player:HealthPercentage() <= Settings.Protection.WordofGloryHP and not Player:HealingAbsorbed()) then
    if (Player:BuffRemains(S.ShieldoftheRighteousBuff) >= 5 
       or Player:BuffUp(S.DivinePurposeBuff) 
       or Player:BuffUp(S.ShiningLightFreeBuff)) then
      if Cast(S.WordofGlory) then return "word_of_glory defensive 8"; end
    else
      -- cast it anyway but run the fuck away
      if HR.CastAnnotated(S.WordofGlory, false, "KITE") then return "word_of_glory defensive 10"; end
    end
  end

  if S.ShieldoftheRighteous:IsReady() and (Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and (ActiveMitigationNeeded or Player:HealthPercentage() <= Settings.Protection.ShieldoftheRighteousHP)) then
    if Cast(S.ShieldoftheRighteous, nil, Settings.Protection.DisplayStyle.Defensives) then return "shield_of_the_righteous defensive 12"; end
  end
end

local function Cooldowns()
  -- fireblood,if=buff.avenging_wrath.up
  if S.Fireblood:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 2"; end
  end
  -- seraphim
  if S.Seraphim:IsReady() then
    if Cast(S.Seraphim, Settings.Protection.GCDasOffGCD.Seraphim) then return "seraphim cooldowns 4"; end
  end
  -- avenging_wrath
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Protection.GCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns 6"; end
  end
  -- holy_avenger,if=buff.avenging_wrath.up|cooldown.avenging_wrath.remains>60
  if S.HolyAvenger:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or S.AvengingWrath:CooldownRemains() > 60) then
    if Cast(S.HolyAvenger) then return "holy_avenger cooldowns 8"; end
  end
  -- potion,if=buff.avenging_wrath.up
  if I.PotionofPhantomFire:IsReady() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns 10"; end
  end
  -- use_items,if=buff.seraphim.up|!talent.seraphim.enabled
  if (Player:BuffUp(S.SeraphimBuff) or not S.Seraphim:IsAvailable()) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- moment_of_glory,if=prev_gcd.1.avengers_shield&cooldown.avengers_shield.remains
  if S.MomentofGlory:IsCastable() and (Player:PrevGCD(1, S.AvengersShield) and not S.AvengersShield:CooldownUp()) then
    if Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then return "moment_of_glory cooldowns 12"; end
  end
end

local function Standard()
  -- shield_of_the_righteous,if=debuff.judgment.up
  if S.ShieldoftheRighteous:IsReady() and (Target:DebuffUp(S.JudgmentDebuff)) then
    if Cast(S.ShieldoftheRighteous) then return "shield_of_the_righteous standard 2"; end
  end
  -- shield_of_the_righteous,if=holy_power=5|buff.holy_avenger.up|holy_power=4&talent.sanctified_wrath.enabled&buff.avenging_wrath.up
  if S.ShieldoftheRighteous:IsReady() and (Player:HolyPower() == 5 or Player:BuffUp(S.HolyAvengerBuff) or Player:HolyPower() == 4 and S.SanctifiedWrath:IsAvailable() and Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(S.ShieldoftheRighteous) then return "shield_of_the_righteous standard 4"; end
  end
  -- NOTE(MRDMND) - added an AOE prio on this over judgment
  if S.AvengersShield:IsCastable() and (EnemiesCount8y >= 3) then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 6"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains,if=charges=2|!talent.crusaders_judgment.enabled
  if S.Judgment:IsReady() and (S.Judgment:Charges() == 2 or not S.CrusadersJudgment:IsAvailable()) then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 8"; end
  end
  -- hammer_of_wrath
  if S.HammerofWrath:IsReady() then
    if Everyone.CastCycle(S.HammerofWrath, Enemies30y, EvaluateCycleHammerofWrath, not Target:IsSpellInRange(S.HammerofWrath)) then return "hammer_of_wrath standard 10"; end
  end
  -- blessing_of_the_seasons
  local ShouldReturn = HandleNightFaeBlessings(); if ShouldReturn then return ShouldReturn; end
  -- avengers_shield
  if S.AvengersShield:IsCastable() then
    if Cast(S.AvengersShield, nil, nil, not Target:IsSpellInRange(S.AvengersShield)) then return "avengers_shield standard 12"; end
  end
  -- judgment,target_if=min:debuff.judgment.remains
  if S.Judgment:IsReady() then
    if Everyone.CastCycle(S.Judgment, Enemies30y, EvaluateCycleJudgment200, not Target:IsSpellInRange(S.Judgment)) then return "judgment standard 14"; end
  end
  -- consecration,if=!consecration.up
  if S.Consecration:IsCastable() and (Player:BuffDown(S.ConsecrationBuff)) then
    if Cast(S.Consecration) then return "consecration standard 16"; end
  end
  -- vanquishers_hammer
  if S.VanquishersHammer:IsReady() then
    if Cast(S.VanquishersHammer, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.VanquishersHammer)) then return "vanquishers_hammer standard 18"; end
  end
  -- blessed_hammer,strikes=2.4,if=charges=3
  if S.BlessedHammer:IsCastable() and (S.BlessedHammer:Charges() == 3) then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 20"; end
  end
  -- ashen_hallow
  if S.AshenHallow:IsCastable() then
    if Cast(S.AshenHallow, nil, Settings.Commons.DisplayStyle.Covenant) then return "ashen_hallow standard 22"; end
  end
  -- hammer_of_the_righteous,if=charges=2
  if S.HammeroftheRighteous:IsCastable() and (S.HammeroftheRighteous:Charges() == 2) then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 24"; end
  end
  -- word_of_glory,if=buff.vanquishers_hammer.up
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.VanquishersHammerBuff)) then
    if Cast(S.WordofGlory) then return "word_of_glory standard 26"; end
  end
  -- blessed_hammer,strikes=2.4
  if S.BlessedHammer:IsCastable() then
    if Cast(S.BlessedHammer, nil, nil, not Target:IsInMeleeRange(5)) then return "blessed_hammer standard 28"; end
  end
  -- hammer_of_the_righteous
  if S.HammeroftheRighteous:IsCastable() then
    if Cast(S.HammeroftheRighteous, nil, nil, not Target:IsInMeleeRange(5)) then return "hammer_of_the_righteous standard 30"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment standard 32"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() then
    if Cast(S.ArcaneTorrent) then return "arcane_torrent standard 34"; end
  end
  -- consecration
  if S.Consecration:IsCastable() then
    if Cast(S.Consecration) then return "consecration standard 36"; end
  end
  -- word_of_glory,if=buff.shining_light_free.up&!covenant.necrolord
  -- TODO: this should not fire if everyone in your party is full HP, but we DO want to heal teammates if we're topped at this point
  if S.WordofGlory:IsReady() and (Player:BuffUp(S.ShiningLightFreeBuff) and CovenantID ~= 4) then
    if HR.CastAnnotated(S.WordofGlory, false, "OTHER") then return "word_of_glory standard 38"; end
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
  --HR.Print("Protection Paladin rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(66, APL, Init)
