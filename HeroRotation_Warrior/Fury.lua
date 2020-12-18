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
local S = Spell.Warrior.Fury
local I = Item.Warrior.Fury

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Fury = HR.GUISettings.APL.Warrior.Fury
}

-- Interrupts List
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
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
    -- recklessness
    if S.Recklessness:IsCastable() then
      if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness 10"; end
    end
    -- potion
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 12"; end
    end
    -- Manually Added: Charge if not in melee. Bloodthirst if in melee
    if S.Charge:IsCastable() and S.Charge:Charges() >= 1 and not Target:IsSpellInRange(S.Bloodthirst) then
      if HR.Cast(S.Charge, nil, nil, not Target:IsSpellInRange(S.Charge)) then return "charge 14"; end
    end
    if S.Bloodthirst:IsCastable() and Target:IsSpellInRange(S.Bloodthirst) then
      if HR.Cast(S.Bloodthirst) then return "bloodthirst 16"; end
    end
  end
end

local function SingleTarget()
  -- raging_blow,if=runeforge.will_of_the_berserker.equipped&buff.will_of_the_berserker.remains<gcd
  if S.RagingBlow:IsCastable() and (S.WilloftheBerserker:IsAvailable() and Player:BuffRemains(S.WilloftheBerserker) < Player:GCD()) then
    if HR.Cast(S.RagingBlow, nil, nil, not Target:IsSpellInRange(S.RagingBlow)) then return "raging_blow"; end
  end
  -- siegebreaker
  if S.Siegebreaker:IsCastable() then
    if HR.Cast(S.Siegebreaker, nil, nil, not Target:IsSpellInRange(S.Siegebreaker)) then return "siegebreaker"; end
  end
  -- rampage,if=buff.recklessness.up|(buff.enrage.remains<gcd|rage>90)|buff.frenzy.remains<1.5
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90) or Player:BuffRemains(S.FrenzyBuff) < 1.5) then
    if HR.Cast(S.Rampage, nil, nil, not Target:IsSpellInRange(S.Rampage)) then return "rampage"; end
  end
  -- condemn
  if S.Condemn:IsCastable() and S.Condemn:IsUsable() then
    if HR.Cast(S.Condemn, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsSpellInRange(S.Condemn)) then return "condemn"; end
  end
  -- execute
  if S.Execute:IsCastable() and S.Execute:IsUsable() then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute"; end
  end
  -- bladestorm,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>45)
  if S.Bladestorm:IsCastable() and (Player:BuffUp(S.EnrageBuff) and EnemiesCount8 > 1) then
    if HR.Cast(S.Bladestorm, nil, nil, not Target:IsInRange(8)) then return "bladestorm"; end
  end
  -- bloodthirst,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35&!talent.cruelty.enabled
  if S.Bloodthirst:IsCastable() and (Player:BuffDown(S.EnrageBuff) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35 and not S.Cruelty:IsAvailable()) then
    if HR.Cast(S.Bloodthirst, nil, nil, not Target:IsSpellInRange(S.Bloodthirst)) then return "bloodthirst"; end
  end
  -- bloodbath,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35&!talent.cruelty.enabled
  if S.Bloodbath:IsCastable() and (Player:BuffDown(S.EnrageBuff) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35 and not S.Cruelty:IsAvailable()) then
    if HR.Cast(S.Bloodbath, nil, nil, not Target:IsSpellInRange(S.Bloodbath)) then return "bloodbath"; end
  end
  -- dragon_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if S.DragonRoar:IsCastable() and (Player:BuffUp(S.EnrageBuff) and EnemiesCount8 > 1) then
    if HR.Cast(S.DragonRoar, nil, nil, not Target:IsInRange(12)) then return "dragon_roar"; end
  end
  -- Ancient Aftershock while enraged
  if S.AncientAftershock:IsCastable() and (Player:BuffUp(S.EnrageBuff) and Player:Covenant() == "Night Fae") then
    if HR.Cast(S.AncientAftershock, nil, Settings.Commons.CovenantDisplayStyle, not Target:IsInRange(8)) then return "AncientAftershock"; end
  end
  -- onslaught
  if S.Onslaught:IsCastable() then
    if HR.Cast(S.Onslaught, nil, nil, not Target:IsSpellInRange(S.Onslaught)) then return "onslaught"; end
  end
  -- raging_blow,if=charges=2
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() == 2) then
    if HR.Cast(S.RagingBlow, nil, nil, not Target:IsSpellInRange(S.RagingBlow)) then return "raging_blow"; end
  end
  -- crushing_blow,if=charges=2
  if S.CrushingBlow:IsCastable() and (S.RagingBlow:Charges() == 2) then
    if HR.Cast(S.CrushingBlow, nil, nil, not Target:IsSpellInRange(CrushingBlow)) then return "CrushingBlow"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if HR.Cast(S.Bloodthirst, nil, nil, not Target:IsSpellInRange(S.Bloodthirst)) then return "bloodthirst"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if HR.Cast(S.Bloodbath, nil, nil, not Target:IsSpellInRange(S.Bloodbath)) then return "bloodbath"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if HR.Cast(S.RagingBlow, nil, nil, not Target:IsSpellInRange(S.RagingBlow)) then return "raging_blow"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if HR.Cast(S.CrushingBlow, nil, nil, not Target:IsSpellInRange(CrushingBlow)) then return "CrushingBlow"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind"; end
  end
end

local function Movement()
  -- heroic_leap
  if S.HeroicLeap:IsCastable() and not Target:IsInMeleeRange(8) then
    if HR.Cast(S.HeroicLeap, Settings.Fury.GCDasOffGCD.HeroicLeap) then return "heroic_leap 152"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    Enemies12y = Player:GetEnemiesInMeleeRange(12) -- Dragon Roar
    EnemiesCount8 = #Enemies8y
    EnemiesCount12 = #Enemies12y
  else
    EnemiesCount8 = 1
    EnemiesCount12 = 1
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- charge
    if S.Charge:IsCastable() and S.Charge:Charges() >= 1 and (not Target:IsInMeleeRange(5)) then
      if HR.Cast(S.Charge, Settings.Fury.GCDasOffGCD.Charge, nil, not Target:IsSpellInRange(S.Charge)) then return "charge 32"; end
    end
    -- run_action_list,name=movement,if=movement.distance>5
    if (not Target:IsInMeleeRange(5)) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and (not Target:IsInRange(25)) then
      if HR.Cast(S.HeroicLeap, Settings.Fury.GCDasOffGCD.HeroicLeap) then return "heroic_leap 34"; end
    end
    -- potion,if=target.time_to_die<60
    if I.PotionofPhantomFire:IsReady() and Settings.Commons.UsePotions and Target:TimeToDie() < 60 then
      if HR.CastSuggested(I.PotionofPhantomFire) then return "potion 36"; end
    end
    -- rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
    if S.Rampage:IsReady() and (S.Recklessness:CooldownRemains() < 3 and S.RecklessAbandon:IsAvailable()) then
      if HR.Cast(S.Rampage, nil, nil, not Target:IsSpellInRange(S.Rampage)) then return "rampage 38"; end
    end
    -- recklessness,if=gcd.remains=0&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
    if S.Recklessness:IsCastable() and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable()) or Target:TimeToDie() > 100 or (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20 or Target:TimeToDie() < 15 and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
      if HR.Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness 58"; end
    end
    -- whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up
    if S.Whirlwind:IsCastable("Melee") and (EnemiesCount8 > 1 and Player:BuffDown(S.MeatCleaverBuff)) then
      if HR.Cast(S.Whirlwind) then return "whirlwind 60"; end
    end
    if (Settings.Commons.UseTrinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if HR.Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if CDsON() then
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() and (Player:BuffUp(S.RecklessnessBuff)) then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
      end
      -- lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff)) then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
      end
      -- bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
      if S.BagofTricks:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff) and Player:BuffUp(S.EnrageBuff)) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks"; end
      end
    end
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(72, APL, Init)
