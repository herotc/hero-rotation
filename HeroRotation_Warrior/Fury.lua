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
  I.AshvanesRazorCoral:ID(),
  I.AzsharasFontofPower:ID(),
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
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions then
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
  -- siegebreaker
  if S.Siegebreaker:IsCastable() then
    if HR.Cast(S.Siegebreaker, Settings.Fury.GCDasOffGCD.Siegebreaker, nil, not Target:IsSpellInRange(S.Siegebreaker)) then return "siegebreaker 102"; end
  end
  -- rampage,if=(buff.recklessness.up|buff.memory_of_lucid_dreams.up)|(buff.enrage.remains<gcd|rage>90)
  if S.Rampage:IsReady() and ((Player:BuffUp(S.RecklessnessBuff) or Player:BuffUp(S.MemoryofLucidDreams)) or (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90)) then
   if HR.Cast(S.Rampage, nil, nil, not Target:IsSpellInRange(S.Rampage)) then return "rampage 104"; end
  end
  -- execute
  if S.Execute:IsCastable() and (Player:BuffUp(S.SuddenDeathBuff) or Target:HealthPercentage() < 20) then
    if HR.Cast(S.Execute, nil, nil, not Target:IsSpellInRange(S.Execute)) then return "execute 106"; end
  end
  -- bladestorm,if=prev_gcd.1.rampage
  if S.Bladestorm:IsCastable() and HR.CDsON() and (Player:PrevGCD(1, S.Rampage)) then
    if HR.Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm 108"; end
  end
  if Player:BuffDown(S.EnrageBuff) then
    -- bloodthirst,if=buff.enrage.down
    if S.Bloodthirst:IsCastable() then
      if HR.Cast(S.Bloodthirst, nil, nil, not Target:IsSpellInRange(S.Bloodthirst)) then return "bloodthirst 110"; end
    end
    -- bloodbath,if=buff.enrage.down
    if S.Bloodbath:IsCastable() then
      if HR.Cast(S.Bloodbath, nil, nil, not Target:IsSpellInRange(S.Bloodbath)) then return "bloodbath 112"; end
    end
  end
  -- onslaught
  if S.Onslaught:IsCastable() and (Player:BuffUp(S.EnrageBuff)) then
    if HR.Cast(S.Onslaught, nil, nil, not Target:IsSpellInRange(S.Onslaught)) then return "onslaught 114"; end
  end
  -- dragon_roar,if=buff.enrage.up
  if S.DragonRoar:IsCastable() and HR.CDsON() and (Player:BuffUp(S.EnrageBuff)) then
    if HR.Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar, nil, not Target:IsInRange(12)) then return "dragon_roar 116"; end
  end
  -- raging_blow,if=charges=2
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() == 2) then
    if HR.Cast(S.RagingBlow, nil, nil, not Target:IsSpellInRange(S.RagingBlow)) then return "raging_blow 118"; end
  end
  -- crushing_blow,if=charges=2
  if S.CrushingBlow:IsCastable() and (S.CrushingBlow:Charges() == 2) then
    if HR.Cast(S.CrushingBlow, nil, nil, not Target:IsSpellInRange(S.CrushingBlow)) then return "crushing_blow 120"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if HR.Cast(S.Bloodthirst, nil, nil, not Target:IsSpellInRange(S.Bloodthirst)) then return "bloodthirst 122"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if HR.Cast(S.Bloodbath, nil, nil, not Target:IsSpellInRange(S.Bloodbath)) then return "bloodbath 124"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if HR.Cast(S.RagingBlow, nil, nil, not Target:IsSpellInRange(S.RagingBlow)) then return "raging_blow 126"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if HR.Cast(S.CrushingBlow, nil, nil, not Target:IsSpellInRange(S.CrushingBlow)) then return "crushing_blow 128"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if HR.Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind 130"; end
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
    if I.PotionofUnbridledFury:IsReady() and Settings.Commons.UsePotions and Target:TimeToDie() < 60 then
      if HR.CastSuggested(I.PotionofUnbridledFury) then return "potion 36"; end
    end
    -- rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
    if S.Rampage:IsReady() and (S.Recklessness:CooldownRemains() < 3 and S.RecklessAbandon:IsAvailable()) then
      if HR.Cast(S.Rampage, nil, nil, not Target:IsSpellInRange(S.Rampage)) then return "rampage 38"; end
    end
    -- recklessness
    if S.Recklessness:IsCastable() and HR.CDsON() then
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
    if (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff)) then
      -- lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
      if S.LightsJudgment:IsCastable() then
        if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 70"; end
      end
      -- bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
      if S.BagofTricks:IsCastable() and (Player:BuffUp(S.EnrageBuff)) then
        if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks 72"; end
      end
    end
    if (Player:BuffUp(S.RecklessnessBuff)) then
      -- bloodfury,if=buff.recklessness.up
      if S.BloodFury:IsCastable() then
        if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "bloodfury 74"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() then
        if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 76"; end
      end
      -- fireblood,if=buff.recklessness.up
      if S.Fireblood:IsCastable() then
        if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 78"; end
      end
      -- ancestral_call,if=buff.recklessness.up
      if S.AncestralCall:IsCastable() then
        if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 80"; end
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
