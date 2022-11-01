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

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

-- Legendaries
local SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
local WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)
local ElysianMightEquipped = Player:HasLegendaryEquipped(263)
local SinfulSurgeEquipped = Player:HasLegendaryEquipped(215) or (CovenantID == 2 and Player:HasUnity())

-- Event Registrations
HL:RegisterForEvent(function()
  SignetofTormentedKingsEquipped = Player:HasLegendaryEquipped(181)
  WilloftheBerserkerEquipped = Player:HasLegendaryEquipped(189)
  ElysianMightEquipped = Player:HasLegendaryEquipped(263)
  SinfulSurgeEquipped = Player:HasLegendaryEquipped(215) or (CovenantID == 2 and Player:HasUnity())
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
  -- Manually added: battle_shout,if=buff.battle_shout.remains<60
  if S.BattleShout:IsCastable() and (Player:BuffRemains(S.BattleShoutBuff, true) < 60) then
    if Cast(S.BattleShout, Settings.Fury.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- recklessness,if=!runeforge.signet_of_tormented_kings.equipped
  if S.Recklessness:IsCastable() and CDsON() and (not SignetofTormentedKingsEquipped) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 4"; end
  end
  -- Manually Added: Charge if not in melee. Bloodthirst if in melee
  if S.Charge:IsCastable() then
    if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge precombat 6"; end
  end
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 8"; end
  end
end

local function SingleTarget()
  -- rampage,if=buff.recklessness.up|buff.enrage.remains<gcd|(rage>110&talent.overwhelming_rage)|(rage>80&!talent.overwhelming_rage)|buff.frenzy.remains<1.5
  if S.RagingBlow:IsCastable() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or (Player:Rage() > 110 and S.OverwhelmingRage:IsAvailable()) or (Player:Rage() > 80 and not S.OverwhelmingRage:IsAvailable()) or Player:BuffRemains(S.FrenzyBuff) < 1.5) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 2"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 4"; end
  end
  -- condemn
  if S.Condemn:IsReady() then
    if Cast(S.Condemn, nil, Settings.Commons.DisplayStyle.Covenant, not TargetInMeleeRange) then return "condemn single_target 6"; end
  end
  -- bloodthirst,if=buff.enrage.down|(talent.annihilator&!buff.recklessness.up)
  if S.Bloodthirst:IsCastable() and ((not EnrageUp) or (S.Annihilator:IsAvailable() and Player:BuffDown(S.RecklessnessBuff))) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if S.ThunderousRoar:IsCastable() and (EnrageUp) then
    if Cast(S.ThunderousRoar, Settings.Commons.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 10"; end
  end
  -- odyns_fury,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if S.OdynsFury:IsCastable() and (EnrageUp) then
    if Cast(S.OdynsFury, nil, nil, not Target:IsInMeleeRange(12)) then return "odyns_fury single_target 12"; end
  end
  -- onslaught,if=!talent.annihilator&buff.enrage.up|talent.tenderize
  if S.Onslaught:IsReady() and ((not S.Annihilator:IsAvailable()) and EnrageUp or S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught single_target 14"; end
  end
  -- raging_blow,if=charges>1
  if S.RagingBlow:IsCastable() and (S.RagingBlow:Charges() > 1) then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 16"; end
  end
  -- crushing_blow,if=charges>1
  if S.CrushingBlow:IsCastable() and (S.CrushingBlow:Charges() > 1) then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 18"; end
  end
  -- bloodbath,if=buff.enrage.down|talent.annihilator
  if S.Bloodbath:IsCastable() and ((not EnrageUp) or S.Annihilator:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 20"; end
  end
  -- bloodthirst,if=talent.annihilator
  if S.Bloodthirst:IsCastable() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 22"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 24"; end
  end
  -- slam,if=talent.annihilator
  if S.Slam:IsReady() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 26"; end
  end
  -- bloodthirst,if=!talent.annihilator
  if S.Bloodthirst:IsCastable() and (not S.Annihilator:IsAvailable()) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 28"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 30"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 32"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 34"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 36"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw single_target 38"; end
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
    -- charge,if=time<=0.5|movement.distance>5
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
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap main 4"; end
    end
    -- potion
    if I.PotionofSpectralStrength:IsReady() and Settings.Commons.Enabled.Potions then
      if Cast(I.PotionofSpectralStrength, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
    end
    -- conquerors_banner
    if S.ConquerorsBanner:IsCastable() and CDsON() then
      if Cast(S.ConquerorsBanner, nil, Settings.Commons.DisplayStyle.Covenant) then return "conquerors_banner main 8"; end
    end
    -- ravager,if=cooldown.avatar.remains<3
    if S.Ravager:IsCastable() and (S.Avatar:CooldownRemains() < 3) then
      if Cast(S.Ravager, nil, nil, not Target:IsInRange(40)) then return "ravager main 10"; end
    end
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=inscrutable_quantum_device,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<21|target.time_to_die>190|buff.bloodlust.up)
      if I.InscrutableQuantumDevice:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 21 or Target:TimeToDie() > 190 or Player:BloodlustUp())) then
        if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device trinkets main"; end
      end
      -- use_item,name=wakeners_frond,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<13|target.time_to_die>130)
      if I.WakenersFrond:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 13 or Target:TimeToDie() > 130)) then
        if Cast(I.WakenersFrond, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wakeners_frond trinkets main"; end
      end
      -- use_item,name=macabre_sheet_music,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<25|target.time_to_die>110)
      if I.MacabreSheetMusic:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 25 or Target:TimeToDie() > 110)) then
        if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music trinkets main"; end
      end
      -- use_item,name=overwhelming_power_crystal,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<16|target.time_to_die>100)
      if I.OverwhelmingPowerCrystal:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 16 or Target:TimeToDie() > 100)) then
        if Cast(I.OverwhelmingPowerCrystal, nil, Settings.Commons.DisplayStyle.Trinkets) then return "overwhelming_power_crystal trinkets main"; end
      end
      -- use_item,name=instructors_divine_bell,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<10|target.time_to_die>95)
      if I.InstructorsDivineBell:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 10 or Target:TimeToDie() > 95)) then
        if Cast(I.InstructorsDivineBell, nil, Settings.Commons.DisplayStyle.Trinkets) then return "instructors_divine_bell trinkets main"; end
      end
      -- use_item,name=flame_of_battle,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<11|target.time_to_die>100)
      if I.FlameofBattle:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 100)) then
        if Cast(I.FlameofBattle, nil, Settings.Commons.DisplayStyle.Trinkets) then return "flame_of_battle trinkets main"; end
      end
      -- use_item,name=gladiators_badge,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<11|target.time_to_die>65)
      if I.SinfulGladiatorsBadge:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 65)) then
        if Cast(I.SinfulGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge 1 trinkets main"; end
      end
      if I.UnchainedGladiatorsBadge:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 11 or Target:TimeToDie() > 65)) then
        if Cast(I.UnchainedGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge 2 trinkets main"; end
      end
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if CDsON() then
      -- arcane_torrent,if=rage<40&!buff.recklessness.up
      --[[if S.ArcaneTorrent:IsCastable() and (Player:Rage() < 40 and Player:BuffDown(S.RecklessnessBuff)) then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent"; end
      end]]
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
    -- avatar,if=talent.titans_torment&buff.enrage.up&(buff.elysian_might.up|!covenant.kyrian)
    if S.Avatar:IsCastable() and (S.TitansTorment:IsAvailable() and EnrageUp and (Player:BuffUp(S.ElysianMightBuff) or CovenantID ~= 1)) then
      if Cast(S.Avatar, Settings.Commons.GCDasOffGCD.Avatar) then return "avatar main 12"; end
    end
    -- avatar,if=!talent.titans_torment&(buff.recklessness.up|target.time_to_die<20)
    if S.Avatar:IsCastable() and ((not S.TitansTorment:IsAvailable()) and (Player:BuffUp(S.RecklessnessBuff) or Target:TimeToDie() < 20)) then
      if Cast(S.Avatar, Settings.Commons.GCDasOffGCD.Avatar) then return "avatar main 14"; end
    end
    -- recklessness,if=talent.annihilator&cooldown.avatar.remains<1|cooldown.avatar.remains>40|!talent.avatar|target.time_to_die<20
    if S.Recklessness:IsCastable() and (S.Annihilator:IsAvailable() and S.Avatar:CooldownRemains() < 1 or S.Avatar:CooldownRemains() > 40 or (not S.Avatar:IsAvailable()) or Target:TimeToDie() < 20) then
      if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 16"; end
    end
    -- recklessness,if=!talent.annihilator
    if S.Recklessness:IsCastable() and (not S.Annihilator:IsAvailable()) then
      if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 18"; end
    end
    -- kyrian_spear,if=buff.enrage.up&(buff.recklessness.up|buff.avatar.up|target.time_to_die<20)
    if S.SpearofBastionCov:IsCastable() and (EnrageUp and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 20)) then
      if Cast(S.SpearofBastionCov, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "kyrian_spear main 20"; end
    end
    -- spear_of_bastion,if=buff.enrage.up&(buff.recklessness.up|buff.avatar.up|target.time_to_die<20)
    if S.SpearofBastion:IsCastable() and (EnrageUp and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 20)) then
      if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(25)) then return "kyrian_spear main 22"; end
    end
    -- whirlwind,if=spell_targets.whirlwind>1&!buff.meat_cleaver.up|raid_event.adds.in<2&!buff.meat_cleaver.up
    if S.Whirlwind:IsCastable() and (EnemiesCount8 > 1 and Player:BuffDown(S.MeatCleaverBuff)) then
      if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind main 24"; end
    end
    -- call_action_list,name=single_target
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Fury Warrior rotation is currently a work in progress, but has been updated for patch 10.0.0.")
end

HR.SetAPL(72, APL, Init)
