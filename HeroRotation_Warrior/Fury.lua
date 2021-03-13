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
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
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

-- Variables
local VarExecutePhase

-- Enemies Variables
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20
local TargetInMeleeRange

-- Legendaries
local SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
local WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)

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

-- Event Registrations
HL:RegisterForEvent(function()
  SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
  WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)
end, "PLAYER_EQUIPMENT_CHANGED")

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
    -- Manually added: battle_shout,if=buff.battle_shout.remains<60
    if S.BattleShout:IsCastable() and (Player:BuffRemains(S.BattleShoutBuff, true) < 60) then
      if Cast(S.BattleShout, Settings.Fury.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
    end
    -- recklessness,if=!runeforge.signet_of_tormented_kings.equipped
    if S.Recklessness:IsCastable() and CDsON() and (not SignetofTormentedKingsEquipped) then
      if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 4"; end
    end
    -- Manually Added: Charge if not in melee. Bloodthirst if in melee
    if S.Charge:IsCastable() and S.Charge:Charges() >= 1 and not TargetInMeleeRange then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge precombat 6"; end
    end
    if S.Bloodthirst:IsCastable() then
      if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 8"; end
    end
  end
end

local function SingleTarget()
  -- raging_blow,if=runeforge.will_of_the_berserker.equipped&buff.will_of_the_berserker.remains<gcd
  if S.RagingBlow:IsCastable() and (WilloftheBerserkerEquipped and Player:BuffRemains(S.WilloftheBerserkerBuff) < Player:GCD()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 2"; end
  end
  -- crushing_blow,if=runeforge.will_of_the_berserker.equipped&buff.will_of_the_berserker.remains<gcd
  if S.CrushingBlow:IsCastable() and (WilloftheBerserkerEquipped and Player:BuffRemains(S.WilloftheBerserkerBuff) < Player:GCD()) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 4"; end
  end
  -- cancel_buff,name=bladestorm,if=spell_targets.whirlwind=1&gcd.remains=0&(talent.massacre.enabled|covenant.venthyr.enabled)&variable.execute_phase&(rage>90|!cooldown.condemn.remains)
  -- bladestorm,if=buff.enrage.remains>gcd*2.5&spell_targets.whirlwind>1
  if S.Bladestorm:IsCastable() and CDsON() and (Player:BuffRemains(S.EnrageBuff) > Player:GCD() * 2.5 and EnemiesCount8 > 1) then
    if Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm single_target 6"; end
  end
  -- condemn,if=buff.enrage.up&variable.execute_phase
  if S.Condemn:IsCastable() and (Player:BuffUp(S.EnrageBuff) and VarExecutePhase) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 8"; end
  end
  -- siegebreaker,if=spell_targets.whirlwind>1|raid_event.adds.in>15
  if S.Siegebreaker:IsCastable() and (EnemiesCount8 > 1) then
    if Cast(S.Siegebreaker, nil, nil, not TargetInMeleeRange) then return "siegebreaker single_target 10"; end
  end
  -- rampage,if=buff.recklessness.up|(buff.enrage.remains<gcd|rage>90)|buff.frenzy.remains<1.5
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 90) or Player:BuffRemains(S.FrenzyBuff) < 1.5) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 12"; end
  end
  -- condemn
  if S.Condemn:IsCastable() and S.Condemn:IsUsable() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 14"; end
  end
  if CDsON() then
    -- ancient_aftershock,if=buff.enrage.up&cooldown.recklessness.remains>5&(target.time_to_die>95|buff.recklessness.up|target.time_to_die<20)&(spell_targets.whirlwind>1|raid_event.adds.in>75)
    if S.AncientAftershock:IsCastable() and (Player:BuffUp(S.EnrageBuff) and S.Recklessness:CooldownRemains() > 5 and (Target:TimeToDie() > 95 or Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20) and EnemiesCount8 > 1) then
      if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(12)) then return "ancient_aftershock single_target 16"; end
    end
    -- spear_of_bastion,if=buff.enrage.up&cooldown.recklessness.remains>5&(target.time_to_die>65|buff.recklessness.up|target.time_to_die<20)&(spell_targets.whirlwind>1|raid_event.adds.in>75)
    if S.SpearofBastion:IsCastable() and (Player:BuffUp(S.EnrageBuff) and S.Recklessness:CooldownRemains() > 5 and (Target:TimeToDie() > 65 or Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20) and EnemiesCount8 > 1) then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion single_target 18"; end
    end
  end
  -- execute
  if S.Execute:IsCastable() and S.Execute:IsUsable() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 20"; end
  end
  -- bladestorm,if=buff.enrage.up&(!buff.recklessness.remains|rage<50)&spell_targets.whirlwind=1&raid_event.adds.in>45
  if S.Bladestorm:IsCastable() and CDsON() and (Player:BuffUp(S.EnrageBuff) and (Player:BuffDown(S.RecklessnessBuff) or Player:Rage() < 50) and EnemiesCount8 == 1) then
    if Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm single_target 22"; end
  end
  -- bloodthirst,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35&!talent.cruelty.enabled
  if S.Bloodthirst:IsCastable() and (Player:BuffDown(S.EnrageBuff) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35 and not S.Cruelty:IsAvailable()) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 24"; end
  end
  -- bloodbath,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35&!talent.cruelty.enabled
  if S.Bloodbath:IsCastable() and (Player:BuffDown(S.EnrageBuff) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35 and not S.Cruelty:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 26"; end
  end
  -- dragon_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if S.DragonRoar:IsCastable() and (Player:BuffUp(S.EnrageBuff) and EnemiesCount8 > 1) then
    if Cast(S.DragonRoar, nil, nil, not Target:IsInRange(12)) then return "dragon_roar single_target 28"; end
  end
  -- whirlwind,if=buff.merciless_bonegrinder.up&spell_targets.whirlwind>3
  if S.Whirlwind:IsCastable() and (Player:BuffUp(S.MercilessBonegrinderBuff) and EnemiesCount8 > 3) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 30"; end
  end
  -- onslaught
  if S.Onslaught:IsCastable() and S.Onslaught:IsUsable() then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught single_target 32"; end
  end
  -- raging_blow,if=charges=2|buff.recklessness.up&variable.execute_phase&talent.massacre.enabled
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() == 2 or Player:BuffUp(S.RecklessnessBuff) and VarExecutePhase and S.Massacre:IsAvailable()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 34"; end
  end
  -- crushing_blow,if=charges=2
  if S.CrushingBlow:IsCastable() and (S.CrushingBlow:Charges() == 2) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 36"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 38"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 40"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 42"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 44"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 46"; end
  end
end

local function Movement()
  -- heroic_leap
  if S.HeroicLeap:IsCastable() and not Target:IsInMeleeRange(8) then
    if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap 152"; end
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

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

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
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsCastable() and S.VictoryRush:IsUsable() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() and S.VictoryRush:IsUsable() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    -- variable,name=execute_phase,value=talent.massacre&target.health.pct<35|target.health.pct<20|target.health.pct>80&covenant.venthyr
    VarExecutePhase = (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35 or Target:HealthPercentage() < 20 or Target:HealthPercentage() > 80 and Player:Covenant() == "Venthyr")
    -- run_action_list,name=movement,if=movement.distance>5
    if (not TargetInMeleeRange) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap main 4"; end
    end
    -- sequence,if=active_enemies=1&covenant.venthyr.enabled&runeforge.signet_of_tormented_kings.equipped,name=BT&Reck:bloodthirst:recklessness
    if (S.Bloodthirst:IsCastable() and S.Recklessness:IsCastable()) and (EnemiesCount8 == 1 and Player:Covenant() == "Venthyr" and SignetofTormentedKingsEquipped) then
      if HR.CastQueue(S.Bloodthirst, S.Recklessness) then return "BT&Reck sequence"; end
    end
    -- sequence,if=active_enemies=1&!covenant.venthyr.enabled&runeforge.signet_of_tormented_kings.equipped,name=BT&Charge:bloodthirst:heroic_charge
    --if (S.Bloodthirst:IsCastable() and S.HeroicLeap:IsCastable()) and (EnemiesCount8 == 1 and Player:Covenant() ~= "Venthyr" and SignetofTormentedKingsEquipped) then
      --if HR.CastQueue(S.Bloodthirst, S.HeroicLeap) then return "BT&Charge sequence"; end
    --end
    -- potion
    if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions then
      if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
    end
    -- conquerors_banner,if=rage>74
    if S.ConquerorsBanner:IsCastable() and CDsON() and (Player:Rage() > 74) then
      if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 8"; end
    end
    -- rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
    if S.Rampage:IsReady() and (S.Recklessness:CooldownRemains() < 3 and S.RecklessAbandon:IsAvailable()) then
      if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage main 10"; end
    end
    if CDsON() then
      -- recklessness,if=!runeforge.signet_of_tormented_kings.equipped&gcd.remains=0&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|variable.execute_phase|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
      if S.Recklessness:IsCastable() and (not SignetofTormentedKingsEquipped and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable()) or Target:TimeToDie() > 100 or VarExecutePhase) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 12"; end
      end
      -- recklessness,use_off_gcd=1,if=runeforge.signet_of_tormented_kings.equipped&gcd.remains&prev_gcd.1.rampage&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|variable.execute_phase|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
      if S.Recklessness:IsCastable() and (SignetofTormentedKingsEquipped and Player:PrevGCDP(1, S.Rampage) and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable()) or Target:TimeToDie() > 100 or VarExecutePhase) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 14"; end
      end
    end
    -- whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up|raid_event.adds.in<gcd&!buff.meat_cleaver.up
    -- Manually added PrevGCDP and buff stack check to smooth out Whirlwind usage
    if S.Whirlwind:IsCastable("Melee") and (EnemiesCount8 > 1 and (Player:BuffDown(S.MeatCleaverBuff) or Player:PrevGCDP(3, S.Whirlwind) and Player:BuffStack(S.MeatCleaverBuff) == 1)) then
      if Cast(S.Whirlwind) then return "whirlwind 60"; end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if CDsON() then
      -- arcane_torrent,if=rage<40&!buff.recklessness.up
      -- lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff)) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
      end
      -- bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
      if S.BagofTricks:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff) and Player:BuffUp(S.EnrageBuff)) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() and (Player:BuffUp(S.RecklessnessBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking"; end
      end
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call"; end
      end
    end
    -- run_action_list,name=single_target
    if (true) then
      local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(72, APL, Init)
