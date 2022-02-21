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
  I.FlameofBattle:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.InstructorsDivineBell:ID(),
  I.MacabreSheetMusic:ID(),
  I.OverwhelmingPowerCrystal:ID(),
  I.WakenersFrond:ID(),
  I.SinfulGladiatorsBadge:ID(),
  I.UnchainedGladiatorsBadge:ID(),
}

-- Variables
local EnrageUp
local VarExecutePhase
local VarUniqueLegendaries

-- Enemies Variables
local Enemies8y, EnemiesCount8
local TargetInMeleeRange

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

-- Legendaries
local SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
local WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)
local ElysianMightEquipped = Player:HasLegendaryEquipped(263)
local SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)

-- Event Registrations
HL:RegisterForEvent(function()
  SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
  WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)
  ElysianMightEquipped = Player:HasLegendaryEquipped(263)
  SinfulSurgeEquipped = Player:HasLegendaryEquipped(215)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

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
  -- Manually added: battle_shout,if=buff.battle_shout.remains<60
  if S.BattleShout:IsCastable() and (Player:BuffRemains(S.BattleShoutBuff, true) < 60) then
    if Cast(S.BattleShout, Settings.Fury.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- recklessness,if=!runeforge.signet_of_tormented_kings.equipped
  if S.Recklessness:IsCastable() and CDsON() and (not SignetofTormentedKingsEquipped) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 4"; end
  end
  -- conquerors_banner
  if S.ConquerorsBanner:IsCastable() then
    if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner precombat 6"; end
  end
  -- Manually Added: Charge if not in melee. Bloodthirst if in melee
  if S.Charge:IsCastable() then
    if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge precombat 8"; end
  end
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 10"; end
  end
end

local function AOE()
  -- cancel_buff,name=bladestorm,if=spell_targets.whirlwind>1&gcd.remains=0&soulbind.first_strike&buff.first_strike.remains&buff.enrage.remains<gcd
  -- ancient_aftershock,if=buff.enrage.up&cooldown.recklessness.remains>5&spell_targets.whirlwind>1
  if CDsON() and S.AncientAftershock:IsCastable() and (EnrageUp and S.Recklessness:CooldownRemains() > 5 and EnemiesCount8 > 1) then
    if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInMeleeRange(12)) then return "ancient_aftershock aoe 2"; end
  end
  -- spear_of_bastion,if=buff.enrage.up&rage<40&spell_targets.whirlwind>1
  if S.SpearofBastion:IsCastable() and (EnrageUp and Player:Rage() < 40 and EnemiesCount8 > 1) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "spear_of_bastion aoe 4"; end
  end
  -- bladestorm,if=buff.enrage.up&spell_targets.whirlwind>2
  if CDsON() and S.Bladestorm:IsCastable() and (EnrageUp and EnemiesCount8 > 2) then
    if Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm aoe 6"; end
  end
  -- condemn,if=spell_targets.whirlwind>1&(buff.enrage.up|buff.recklessness.up&runeforge.sinful_surge)&variable.execute_phase
  if S.Condemn:IsCastable() and (EnemiesCount8 > 1 and (EnrageUp or Player:BuffUp(S.RecklessnessBuff) and SinfulSurgeEquipped) and VarExecutePhase) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn aoe 8"; end
  end
  -- siegebreaker,if=spell_targets.whirlwind>1
  if S.Siegebreaker:IsCastable() and (EnemiesCount8 > 1) then
    if Cast(S.Siegebreaker, nil, nil, not TargetInMeleeRange) then return "siegebreaker aoe 10"; end
  end
  -- rampage,if=spell_targets.whirlwind>1
  if S.Rampage:IsReady() and (EnemiesCount8 > 1) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage aoe 12"; end
  end
  -- spear_of_bastion,if=buff.enrage.up&cooldown.recklessness.remains>5&spell_targets.whirlwind>1
  if S.SpearofBastion:IsCastable() and (EnrageUp and S.Recklessness:CooldownRemains() > 5 and EnemiesCount8 > 1) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "spear_of_bastion aoe 14"; end
  end
  -- bladestorm,if=buff.enrage.remains>gcd*2.5&spell_targets.whirlwind>1
  if CDsON() and S.Bladestorm:IsCastable() and (Player:BuffRemains(S.EnrageBuff) > Player:GCD() * 2.5 and EnemiesCount8 > 1) then
    if Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm aoe 16"; end
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
  -- condemn,if=(buff.enrage.up|buff.recklessness.up&runeforge.sinful_surge)&variable.execute_phase
  if S.Condemn:IsCastable() and ((EnrageUp or Player:BuffUp(S.RecklessnessBuff) and SinfulSurgeEquipped) and VarExecutePhase) then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 8"; end
  end
  -- siegebreaker,if=spell_targets.whirlwind>1|raid_event.adds.in>15
  if S.Siegebreaker:IsCastable() then
    if Cast(S.Siegebreaker, nil, nil, not TargetInMeleeRange) then return "siegebreaker single_target 10"; end
  end
  -- rampage,if=buff.recklessness.up|(buff.enrage.remains<gcd|rage>80)|buff.frenzy.remains<1.5
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or (Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:Rage() > 80) or Player:BuffRemains(S.FrenzyBuff) < 1.5) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 12"; end
  end
  -- condemn
  if S.Condemn:IsReady() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 14"; end
  end
  -- ancient_aftershock,if=buff.enrage.up&cooldown.recklessness.remains>5&(target.time_to_die>95|buff.recklessness.up|target.time_to_die<20)&raid_event.adds.in>75
  if CDsON() and S.AncientAftershock:IsCastable() and (EnrageUp and S.Recklessness:CooldownRemains() > 5 and (Target:TimeToDie() > 95 or Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20)) then
    if Cast(S.AncientAftershock, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(12)) then return "ancient_aftershock single_target 16"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 18"; end
  end
  if CDsON() then
    -- spear_of_bastion,if=runeforge.elysian_might&buff.enrage.up&cooldown.recklessness.remains>5&(buff.recklessness.up|target.time_to_die<20|debuff.siegebreaker.up|!talent.siegebreaker&target.time_to_die>68)&raid_event.adds.in>55
    if S.SpearofBastion:IsCastable() and (ElysianMightEquipped and EnrageUp and S.Recklessness:CooldownRemains() > 5 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20 or Target:DebuffUp(S.SiegebreakerDebuff) or not S.Siegebreaker:IsAvailable() and Target:TimeToDie() > 68)) then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "spear_of_bastion single_target 20"; end
    end
    -- bladestorm,if=buff.enrage.up&(!buff.recklessness.remains|rage<50)&(spell_targets.whirlwind=1&raid_event.adds.in>45|spell_targets.whirlwind=2)
    if S.Bladestorm:IsCastable() and (EnrageUp and (Player:BuffDown(S.RecklessnessBuff) or Player:Rage() < 50) and (EnemiesCount8 == 1 or EnemiesCount8 == 2)) then
      if Cast(S.Bladestorm, Settings.Fury.GCDasOffGCD.Bladestorm, nil, not Target:IsInRange(8)) then return "bladestorm single_target 22"; end
    end
    -- spear_of_bastion,if=buff.enrage.up&cooldown.recklessness.remains>5&(buff.recklessness.up|target.time_to_die<20|debuff.siegebreaker.up|!talent.siegebreaker&target.time_to_die>68)&raid_event.adds.in>55
    if S.SpearofBastion:IsCastable() and (EnrageUp and S.Recklessness:CooldownRemains() > 5 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20 or Target:DebuffUp(S.SiegebreakerDebuff) or not S.Siegebreaker:IsAvailable() and Target:TimeToDie() > 68)) then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "spear_of_bastion single_target 23"; end
    end
  end
  -- bloodthirst,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35
  if S.Bloodthirst:IsCastable() and ((not EnrageUp) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 24"; end
  end
  -- bloodbath,if=buff.enrage.down|conduit.vicious_contempt.rank>5&target.health.pct<35&!talent.cruelty.enabled
  if S.Bloodbath:IsCastable() and ((not EnrageUp) or S.ViciousContempt:ConduitRank() > 5 and Target:HealthPercentage() < 35 and not S.Cruelty:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 26"; end
  end
  -- dragon_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if S.DragonRoar:IsCastable() and (EnrageUp) then
    if Cast(S.DragonRoar, Settings.Fury.GCDasOffGCD.DragonRoar, nil, not Target:IsInRange(12)) then return "dragon_roar single_target 28"; end
  end
  -- whirlwind,if=buff.merciless_bonegrinder.up&spell_targets.whirlwind>3
  if S.Whirlwind:IsCastable() and (Player:BuffUp(S.MercilessBonegrinderBuff) and EnemiesCount8 > 3) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 32"; end
  end
  -- raging_blow,if=set_bonus.tier28_2pc|charges=2|buff.recklessness.up&variable.execute_phase&talent.massacre.enabled
  if S.RagingBlow:IsCastable() and (Player:HasTier(28, 2) or S.RagingBlow:Charges() == 2 or Player:BuffUp(S.RecklessnessBuff) and VarExecutePhase and S.Massacre:IsAvailable()) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 34"; end
  end
  -- crushing_blow,if=set_bonus.tier28_2pc|charges=2|buff.recklessness.up&variable.execute_phase&talent.massacre.enabled
  if S.CrushingBlow:IsCastable() and (Player:HasTier(28, 2) or S.CrushingBlow:Charges() == 2 or Player:BuffUp(S.RecklessnessBuff) and VarExecutePhase and S.Massacre:IsAvailable()) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 36"; end
  end
  -- onslaught,if=buff.enrage.up
  if S.Onslaught:IsReady() and (EnrageUp) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught single_target 30"; end
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
    if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap movement 2"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8)
    EnemiesCount8 = #Enemies8y
  else
    EnemiesCount8 = 1
  end

  -- Enrage check
  EnrageUp = Player:BuffUp(S.EnrageBuff)

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- In Combat
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    -- charge
    if S.Charge:IsCastable() then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    -- variable,name=execute_phase,value=talent.massacre&target.health.pct<35|target.health.pct<20|target.health.pct>80&covenant.venthyr
    VarExecutePhase = (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35 or Target:HealthPercentage() < 20 or Target:HealthPercentage() > 80 and CovenantID == 2)
    -- variable,name=unique_legendaries,value=runeforge.signet_of_tormented_kings|runeforge.sinful_surge|runeforge.elysian_might
    VarUniqueLegendaries = (SignetofTormentedKingsEquipped or SinfulSurgeEquipped or ElysianMightEquipped)
    -- run_action_list,name=movement,if=movement.distance>5
    if (not TargetInMeleeRange) then
      local ShouldReturn = Movement(); if ShouldReturn then return ShouldReturn; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap main 4"; end
    end
    if (not Settings.Fury.HideCastQueue) then
      -- sequence,if=active_enemies=1&covenant.venthyr.enabled&runeforge.signet_of_tormented_kings.equipped,name=BT&Reck:bloodthirst:recklessness
      if (S.Bloodthirst:IsCastable() and S.Recklessness:IsCastable()) and (EnemiesCount8 == 1 and CovenantID == 2 and SignetofTormentedKingsEquipped) then
        if HR.CastQueue(S.Bloodthirst, S.Recklessness) then return "BT&Reck sequence"; end
      end
      -- sequence,if=active_enemies=1&!covenant.venthyr.enabled&runeforge.signet_of_tormented_kings.equipped,name=BT&Charge:bloodthirst:heroic_charge
      --if (S.Bloodthirst:IsCastable() and S.HeroicLeap:IsCastable()) and (EnemiesCount8 == 1 and CovenantID ~= 2 and SignetofTormentedKingsEquipped) then
        --if HR.CastQueue(S.Bloodthirst, S.HeroicLeap) then return "BT&Charge sequence"; end
      --end
    end
    -- potion
    if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions then
      if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
    end
    -- conquerors_banner,if=rage>70
    if S.ConquerorsBanner:IsCastable() and CDsON() and (Player:Rage() > 70) then
      if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 8"; end
    end
    -- spear_of_bastion,if=buff.enrage.up&rage<70
    if S.SpearofBastion:IsCastable() and (EnrageUp and Player:Rage() < 70) then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "spear_of_bastion main 9"; end
    end
    -- rampage,if=cooldown.recklessness.remains<3&talent.reckless_abandon.enabled
    if S.Rampage:IsReady() and (S.Recklessness:CooldownRemains() < 3 and S.RecklessAbandon:IsAvailable()) then
      if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage main 10"; end
    end
    if CDsON() then
      -- recklessness,if=runeforge.sinful_surge&gcd.remains=0&(variable.execute_phase|(target.time_to_pct_35>40&talent.anger_management|target.time_to_pct_35>70&!talent.anger_management))&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
      if S.Recklessness:IsCastable() and (SinfulSurgeEquipped and (VarExecutePhase or (Target:TimeToX(35) > 40 and S.AngerManagement:IsAvailable() or Target:TimeToX(35) > 70 and not S.AngerManagement:IsAvailable())) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 11"; end
      end
      -- recklessness,if=runeforge.elysian_might&gcd.remains=0&(cooldown.spear_of_bastion.remains<5|cooldown.spear_of_bastion.remains>20)&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|variable.execute_phase|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
      if S.Recklessness:IsCastable() and (ElysianMightEquipped and (S.SpearofBastion:CooldownRemains() < 5 or S.SpearofBastion:CooldownRemains() > 20) and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable() or EnemiesCount8 == 1) or Target:TimeToDie() > 100 or VarExecutePhase or Target:TimeToDie() < 15) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 12"; end
      end
      -- recklessness,if=!variable.unique_legendaries&gcd.remains=0&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|variable.execute_phase|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)&cooldown.conquerors_banner.remains>20
      if S.Recklessness:IsCastable() and (not VarUniqueLegendaries and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable() or EnemiesCount8 == 1) or Target:TimeToDie() > 100 or VarExecutePhase or Target:TimeToDie() < 15) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff)) and S.ConquerorsBanner:CooldownRemains() > 20) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 13"; end
      end
      -- recklessness,use_off_gcd=1,if=runeforge.signet_of_tormented_kings.equipped&gcd.remains&prev_gcd.1.rampage&((buff.bloodlust.up|talent.anger_management.enabled|raid_event.adds.in>10)|target.time_to_die>100|variable.execute_phase|target.time_to_die<15&raid_event.adds.in>10)&(spell_targets.whirlwind=1|buff.meat_cleaver.up)
      if S.Recklessness:IsCastable() and (SignetofTormentedKingsEquipped and Player:PrevGCDP(1, S.Rampage) and ((Player:BloodlustUp() or S.AngerManagement:IsAvailable()) or Target:TimeToDie() > 100 or VarExecutePhase) and (EnemiesCount8 == 1 or Player:BuffUp(S.MeatCleaverBuff))) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 14"; end
      end
    end
    -- whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up|raid_event.adds.in<gcd&!buff.meat_cleaver.up
    if S.Whirlwind:IsCastable() and (EnemiesCount8 > 1 and Player:BuffDown(S.MeatCleaverBuff)) then
      if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind main 16"; end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=inscrutable_quantum_device,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<21|target.time_to_die>190|buff.bloodlust.up)
      if I.InscrutableQuantumDevice:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 21 or Target:TimeToDie() > 190 or Player:BloodlustUp())) then
        if Cast(I.InscrutableQuantumDevice) then return "inscrutable_quantum_device trinkets main"; end
      end
      -- use_item,name=wakeners_frond,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<13|target.time_to_die>130)
      if I.WakenersFrond:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 13 or Target:TimeToDie() > 130)) then
        if Cast(I.WakenersFrond) then return "wakeners_frond trinkets main"; end
      end
      -- use_item,name=macabre_sheet_music,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<25|target.time_to_die>110)
      if I.MacabreSheetMusic:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 25 or Target:TimeToDie() > 110)) then
        if Cast(I.MacabreSheetMusic) then return "macabre_sheet_music trinkets main"; end
      end
      -- use_item,name=overwhelming_power_crystal,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<16|target.time_to_die>100)
      if I.OverwhelmingPowerCrystal:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 16 or Target:TimeToDie() > 100)) then
        if Cast(I.OverwhelmingPowerCrystal) then return "overwhelming_power_crystal trinkets main"; end
      end
      -- use_item,name=instructors_divine_bell,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<10|target.time_to_die>95)
      if I.InstructorsDivineBell:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 10 or Target:TimeToDie() > 95)) then
        if Cast(I.InstructorsDivineBell) then return "instructors_divine_bell trinkets main"; end
      end
      -- use_item,name=flame_of_battle,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<11|target.time_to_die>100)
      if I.FlameofBattle:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 100)) then
        if Cast(I.FlameofBattle) then return "flame_of_battle trinkets main"; end
      end
      -- use_item,name=gladiators_badge,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<11|target.time_to_die>65)
      if I.SinfulGladiatorsBadge:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 65)) then
        if Cast(I.SinfulGladiatorsBadge) then return "gladiators_badge 1 trinkets main"; end
      end
      if I.UnchainedGladiatorsBadge:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 65)) then
        if Cast(I.UnchainedGladiatorsBadge) then return "gladiators_badge 2 trinkets main"; end
      end
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if CDsON() then
      -- arcane_torrent,if=rage<40&!buff.recklessness.up
      if S.ArcaneTorrent:IsCastable() and (Player:Rage() < 40 and Player:BuffDown(S.RecklessnessBuff)) then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent"; end
      end
      -- lights_judgment,if=buff.recklessness.down&debuff.siegebreaker.down
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff)) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment"; end
      end
      -- bag_of_tricks,if=buff.recklessness.down&debuff.siegebreaker.down&buff.enrage.up
      if S.BagofTricks:IsCastable() and (Player:BuffDown(S.RecklessnessBuff) and Target:DebuffDown(S.SiegebreakerDebuff) and EnrageUp) then
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
    -- call_action_list,name=aoe
    local ShouldReturn = AOE(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=single_target
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Init()
  --HR.Print("Fury Warrior rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(72, APL, Init)
