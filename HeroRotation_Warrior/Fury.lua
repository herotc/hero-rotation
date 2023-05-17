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
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Fury
local I = Item.Warrior.Fury

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.CrimsonGladiatorsBadgeofFerocity:ID(),
  I.IrideusFragment:ID(),
  I.ManicGrieftorch:ID(),
  I.VialofAnimatedBlood:ID(),
}

-- Variables
local EnrageUp

-- Enemies Variables
local Enemies8y, EnemiesCount8y
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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- berserker_stance,toggle=on
  if S.BerserkerStance:IsCastable() and Player:BuffDown(S.BerserkerStance, true) then
    if Cast(S.BerserkerStance) then return "berserker_stance precombat 2"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 4"; end
  end
  -- avatar,if=!talent.titans_torment
  if S.Avatar:IsCastable() and (not S.TitansTorment:IsAvailable()) then
    if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar precombat 6"; end
  end
  -- recklessness,if=!talent.reckless_abandon
  if S.Recklessness:IsCastable() and (not S.RecklessAbandon:IsAvailable()) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness precombat 8"; end
  end
  -- Manually Added: Charge if not in melee range. Bloodthirst if in melee range
  if S.Bloodthirst:IsCastable() and TargetInMeleeRange then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst precombat 10"; end
  end
  if S.Charge:IsReady() and not TargetInMeleeRange then
    if Cast(S.Charge) then return "charge precombat 12"; end
  end
end

local function SingleTarget()
  -- whirlwind,if=spell_targets.whirlwind>1&talent.improved_whirlwind&!buff.meat_cleaver.up|raid_event.adds.in<2&talent.improved_whirlwind&!buff.meat_cleaver.up
  if S.Whirlwind:IsCastable() and EnemiesCount8y > 1 and S.ImprovedWhilwind:IsAvailable() and Player:BuffDown(S.MeatCleaverBuff) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 2"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd
  if S.Execute:IsReady() and Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 4"; end
  end
  -- thunderous_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if CDsON() and S.ThunderousRoar:IsCastable() and EnrageUp then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 6"; end
  end
  -- odyns_fury,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)&(talent.dancing_blades&buff.dancing_blades.remains<5|!talent.dancing_blades)
  if CDsON() and S.OdynsFury:IsCastable() and EnrageUp and (S.DancingBlades:IsAvailable() and Player:BuffRemains(S.DancingBladesBuff) < 5 or not S.DancingBlades:IsAvailable()) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury single_target 8"; end
  end
  -- rampage,if=talent.anger_management&(buff.recklessness.up|buff.enrage.remains<gcd|rage.pct>85)
  if S.Rampage:IsReady() and S.AngerManagement:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:RagePercentage() > 85) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 10"; end
  end
  local BTCritChance = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.MercilessAssaultBuff) * 10 + Player:BuffStack(S.BloodcrazeBuff) * 15
  if (BTCritChance >= 95 or (not S.ColdSteelHotBlood:IsAvailable()) and Player:HasTier(30, 4)) then
    -- bloodbath,if=action.bloodbath.crit_pct_current>=95|!talent.cold_steel_hot_blood&set_bonus.tier30_4pc
    if S.Bloodbath:IsCastable() then
      if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 12"; end
    end
    -- bloodthirst,if=action.bloodthirst.crit_pct_current>=95|!talent.cold_steel_hot_blood&set_bonus.tier30_4pc
    if S.Bloodthirst:IsCastable() then
      if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 14"; end
    end
  end
  -- execute,if=buff.enrage.up
  if S.Execute:IsReady() and EnrageUp then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 16"; end
  end
  -- onslaught,if=buff.enrage.up|talent.tenderize
  if S.Onslaught:IsReady() and (EnrageUp or S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught single_target 18"; end
  end
  -- crushing_blow,if=talent.wrath_and_fury&buff.enrage.up
  if S.CrushingBlow:IsCastable() and S.WrathandFury:IsAvailable() and EnrageUp then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 20"; end
  end
  -- rampage,if=talent.reckless_abandon&(buff.recklessness.up|buff.enrage.remains<gcd|rage.pct>85)
  if S.Rampage:IsReady() and S.RecklessAbandon:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or Player:RagePercentage() > 85) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 22"; end
  end
  -- rampage,if=talent.anger_management
  if S.Rampage:IsReady() and S.AngerManagement:IsAvailable() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 24"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 26"; end
  end
  -- bloodbath,if=buff.enrage.up&talent.reckless_abandon&!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and EnrageUp and S.RecklessAbandon:IsAvailable() and not S.WrathandFury:IsAvailable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 28"; end
  end
  -- bloodthirst,if=buff.enrage.down|(talent.annihilator&!buff.recklessness.up)
  if S.Bloodthirst:IsCastable() and ((not EnrageUp) or (S.Annihilator:IsAvailable() and Player:BuffDown(S.RecklessnessBuff))) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 30"; end
  end
  -- raging_blow,if=charges>1&talent.wrath_and_fury
  if S.RagingBlow:IsCastable() and S.RagingBlow:Charges() > 1 and S.WrathandFury:IsAvailable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 32"; end
  end
  -- crushing_blow,if=charges>1&talent.wrath_and_fury
  if S.CrushingBlow:IsCastable() and S.CrushingBlow:Charges() > 1 and S.WrathandFury:IsAvailable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 34"; end
  end
  -- bloodbath,if=buff.enrage.down|!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and ((not EnrageUp) or not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 36"; end
  end
  -- crushing_blow,if=buff.enrage.up&talent.reckless_abandon
  if S.CrushingBlow:IsCastable() and EnrageUp and S.RecklessAbandon:IsAvailable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 38"; end
  end
  -- bloodthirst,if=!talent.wrath_and_fury
  if S.Bloodthirst:IsCastable() and not S.WrathandFury:IsAvailable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 40"; end
  end
  -- raging_blow,if=charges>1
  if S.RagingBlow:IsCastable() and S.RagingBlow:Charges() > 1 then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 42"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage single_target 44"; end
  end
  -- slam,if=talent.annihilator
  if S.Slam:IsReady() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 46"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath single_target 48"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow single_target 50"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow single_target 52"; end
  end
  -- bloodthirst
  if S.Bloodthirst:IsCastable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst single_target 54"; end
  end
  -- whirlwind
  if AoEON() and S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 56"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw single_target 58"; end
  end
  -- storm_bolt
  if S.StormBolt:IsCastable() then
    if Cast(S.StormBolt, nil, nil, not TargetInMeleeRange) then return "storm_bolt single_target 60"; end
  end
end

local function MultiTarget()
  -- recklessness,if=raid_event.adds.in>15|active_enemies>1|target.time_to_die<12
  if CDsON() and S.Recklessness:IsCastable() and (EnemiesCount8y > 1 or HL.FightRemains() < 12) then
    if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness multi_target 2"; end
  end
  -- odyns_fury,if=active_enemies>1&talent.titanic_rage&(!buff.meat_cleaver.up|buff.avatar.up|buff.recklessness.up)
  if CDsON() and S.OdynsFury:IsCastable() and EnemiesCount8y > 1 and S.TitanicRage:IsAvailable() and (Player:BuffDown(S.MeatCleaverBuff) or Player:BuffUp(S.AvatarBuff) or Player:BuffUp(S.RecklessnessBuff)) then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 4"; end
  end
  -- whirlwind,if=spell_targets.whirlwind>1&talent.improved_whirlwind&!buff.meat_cleaver.up|raid_event.adds.in<2&talent.improved_whirlwind&!buff.meat_cleaver.up
  if S.Whirlwind:IsCastable() and EnemiesCount8y > 1 and S.ImprovedWhilwind:IsAvailable() and Player:BuffDown(S.MeatCleaverBuff) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind multi_target 6"; end
  end
  -- execute,if=buff.ashen_juggernaut.up&buff.ashen_juggernaut.remains<gcd
  if S.Execute:IsReady() and Player:BuffUp(S.AshenJuggernautBuff) and Player:BuffRemains(S.AshenJuggernautBuff) < Player:GCD() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 8"; end
  end
  -- thunderous_roar,if=buff.enrage.up&(spell_targets.whirlwind>1|raid_event.adds.in>15)
  if CDsON() and S.ThunderousRoar:IsCastable() and EnrageUp then
    if Cast(S.ThunderousRoar, Settings.Fury.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar multi_target 10"; end
  end
  -- odyns_fury,if=active_enemies>1&buff.enrage.up&raid_event.adds.in>15
  if CDsON() and S.OdynsFury:IsCastable() and EnemiesCount8y > 1 and EnrageUp then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 12"; end
  end
  local BTCritChance = Player:CritChancePct() + num(Player:BuffUp(S.RecklessnessBuff)) * 20 + Player:BuffStack(S.MercilessAssaultBuff) * 10 + Player:BuffStack(S.BloodcrazeBuff) * 15
  if (BTCritChance >= 95 or (not S.ColdSteelHotBlood:IsAvailable()) and Player:HasTier(30, 4)) then
    -- bloodbath,if=action.bloodbath.crit_pct_current>=95|!talent.cold_steel_hot_blood&set_bonus.tier30_4pc
    if S.Bloodbath:IsCastable() then
      if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 14"; end
    end
    -- bloodthirst,if=action.bloodthirst.crit_pct_current>=95|!talent.cold_steel_hot_blood&set_bonus.tier30_4pc
    if S.Bloodthirst:IsCastable() then
      if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 16"; end
    end
  end
  -- crushing_blow,if=talent.wrath_and_fury&buff.enrage.up
  if S.CrushingBlow:IsCastable() and S.WrathandFury:IsAvailable() and EnrageUp then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 18"; end
  end
  -- execute,if=buff.enrage.up
  if S.Execute:IsReady() and EnrageUp then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 20"; end
  end
  -- odyns_fury,if=buff.enrage.up&raid_event.adds.in>15
  if CDsON() and S.OdynsFury:IsCastable() and EnrageUp then
    if Cast(S.OdynsFury, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInMeleeRange(12)) then return "odyns_fury multi_target 22"; end
  end
  -- rampage,if=buff.recklessness.up|buff.enrage.remains<gcd|(rage>110&talent.overwhelming_rage)|(rage>80&!talent.overwhelming_rage)
  if S.Rampage:IsReady() and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffRemains(S.EnrageBuff) < Player:GCD() or (Player:Rage() > 110 and S.OverwhelmingRage:IsAvailable()) or (Player:Rage() > 80 and not S.OverwhelmingRage:IsAvailable())) then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage multi_target 24"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute multi_target 26"; end
  end
  -- bloodbath,if=buff.enrage.up&talent.reckless_abandon&!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and EnrageUp and S.RecklessAbandon:IsAvailable() and not S.WrathandFury:IsAvailable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 28"; end
  end
  -- bloodthirst,if=buff.enrage.down|(talent.annihilator&!buff.recklessness.up)
  if S.Bloodthirst:IsCastable() and ((not EnrageUp) or (S.Annihilator:IsAvailable() and Player:BuffDown(S.RecklessnessBuff))) then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 30"; end
  end
  -- onslaught,if=!talent.annihilator&buff.enrage.up|talent.tenderize
  if S.Onslaught:IsReady() and ((not S.Annihilator:IsAvailable()) and EnrageUp or S.Tenderize:IsAvailable()) then
    if Cast(S.Onslaught, nil, nil, not TargetInMeleeRange) then return "onslaught multi_target 32"; end
  end
  -- raging_blow,if=charges>1&talent.wrath_and_fury
  if S.RagingBlow:IsCastable() and S.RagingBlow:Charges() > 1 and S.WrathandFury:IsAvailable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 34"; end
  end
  -- crushing_blow,if=charges>1&talent.wrath_and_fury
  if S.CrushingBlow:IsCastable() and S.CrushingBlow:Charges() > 1 and S.WrathandFury:IsAvailable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 36"; end
  end
  -- bloodbath,if=buff.enrage.down|!talent.wrath_and_fury
  if S.Bloodbath:IsCastable() and ((not EnrageUp) or not S.WrathandFury:IsAvailable()) then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 38"; end
  end
  -- crushing_blow,if=buff.enrage.up&talent.reckless_abandon
  if S.CrushingBlow:IsCastable() and EnrageUp and S.RecklessAbandon:IsAvailable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 40"; end
  end
  -- bloodthirst,if=!talent.wrath_and_fury
  if S.Bloodthirst:IsCastable() and not S.WrathandFury:IsAvailable() then
    if Cast(S.Bloodthirst, nil, nil, not TargetInMeleeRange) then return "bloodthirst multi_target 42"; end
  end
  -- raging_blow,if=charges>=1
  if S.RagingBlow:IsCastable() and S.RagingBlow:Charges() > 1 then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 44"; end
  end
  -- rampage
  if S.Rampage:IsReady() then
    if Cast(S.Rampage, nil, nil, not TargetInMeleeRange) then return "rampage multi_target 46"; end
  end
  -- slam,if=talent.annihilator
  if S.Slam:IsReady() and (S.Annihilator:IsAvailable()) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam multi_target 48"; end
  end
  -- bloodbath
  if S.Bloodbath:IsCastable() then
    if Cast(S.Bloodbath, nil, nil, not TargetInMeleeRange) then return "bloodbath multi_target 50"; end
  end
  -- raging_blow
  if S.RagingBlow:IsCastable() then
    if Cast(S.RagingBlow, nil, nil, not TargetInMeleeRange) then return "raging_blow multi_target 52"; end
  end
  -- crushing_blow
  if S.CrushingBlow:IsCastable() then
    if Cast(S.CrushingBlow, nil, nil, not TargetInMeleeRange) then return "crushing_blow multi_target 54"; end
  end
  -- whirlwind
  if S.Whirlwind:IsCastable() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind multi_target 56"; end
  end
end
--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8)
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  -- Enrage check
  EnrageUp = Player:BuffUp(S.EnrageBuff)

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

  if Everyone.TargetIsValid() then
    -- Manually added: Group buff check
    if S.BattleShout:IsCastable() and (Player:BuffDown(S.BattleShoutBuff, true) or Everyone.GroupBuffMissing(S.BattleShoutBuff)) then
      if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout precombat"; end
    end
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- In Combat
    -- auto_attack
    -- charge,if=time<=0.5|movement.distance>5
    if S.Charge:IsCastable() then
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 2"; end
    end
    -- heroic_leap,if=(raid_event.movement.distance>25&raid_event.movement.in>45)
    if S.HeroicLeap:IsCastable() and (not Target:IsInRange(25)) then
      if Cast(S.HeroicLeap, nil, Settings.Commons.DisplayStyle.HeroicLeap) then return "heroic_leap main 4"; end
    end
    -- potion
    if CDsON() and Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, nil, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, nil, not TargetInMeleeRange) then return "impending_victory heal"; end
      end
    end
    if CDsON() then
      if Settings.Commons.Enabled.Trinkets then
        -- use_item,name=algethar_puzzle_box,if=cooldown.recklessness.remains<3|(talent.anger_management&cooldown.avatar.remains<3)
        if I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() < 3 or (S.AngerManagement:IsAvailable() and S.Avatar:CooldownRemains() < 3)) then
          if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box main 8"; end
        end
        -- use_item,name=vial_of_animated_blood,if=buff.avatar.up
        if I.VialofAnimatedBlood:IsEquippedAndReady() and (Player:BuffUp(S.AvatarBuff)) then
          if Cast(I.VialofAnimatedBlood, nil, Settings.Commons.DisplayStyle.Trinkets) then return "vial_of_animated_blood main 10"; end
        end
        -- use_item,name=irideus_fragment,if=buff.avatar.up
        if I.IrideusFragment:IsEquippedAndReady() and (Player:BuffUp(S.AvatarBuff)) then
          if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment main 12"; end
        end
        -- use_item,name=manic_grieftorch,if=buff.avatar.down
        if I.ManicGrieftorch:IsEquippedAndReady() and (Player:BuffDown(S.Avatar)) then
          if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "manic_grieftorch main 14"; end
        end
        -- use_item,name=gladiators_badge,if=cooldown.recklessness.remains>10&(buff.recklessness.up|target.time_to_die<11|target.time_to_die>65)
        if I.CrimsonGladiatorsBadgeofFerocity:IsEquippedAndReady() and (S.Recklessness:CooldownRemains() > 10 and (Player:BuffUp(S.RecklessnessBuff) or FightRemains < 11 or FightRemains > 65)) then
          if Cast(I.CrimsonGladiatorsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge main 16"; end
        end
      end
      if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
        -- Manually added: use_items generic
        local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
        if ItemToUse then
          local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
          if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
          if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
            if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
          end
        end
      end
      -- ravager,if=cooldown.recklessness.remains<3|buff.recklessness.up
      -- Note: manually added end of fight
      if S.Ravager:IsCastable() and (S.Avatar:CooldownRemains() < 3 or Player:BuffUp(S.RecklessnessBuff) or HL.FightRemains() < 10) then
        if Cast(S.Ravager, Settings.Fury.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager main 18"; end
      end
      -- blood_fury
      if S.BloodFury:IsCastable() then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 20"; end
      end
      -- berserking,if=buff.recklessness.up
      if S.Berserking:IsCastable() and Player:BuffUp(S.RecklessnessBuff) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 22"; end
      end
      -- lights_judgment,if=buff.recklessness.down
      if S.LightsJudgment:IsCastable() and Player:BuffDown(S.RecklessnessBuff) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 24"; end
      end
      -- fireblood
      if S.Fireblood:IsCastable() then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 26"; end
      end
      -- ancestral_call
      if S.AncestralCall:IsCastable() then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 28"; end
      end
      -- bag_of_tricks,if=buff.recklessness.down&buff.enrage.up
      -- if S.BagofTricks:IsCastable() and Player:BuffDown(S.RecklessnessBuff) and EnrageUp then
      --   if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 30"; end
      -- end
      -- avatar,if=talent.titans_torment&buff.enrage.up&raid_event.adds.in>15|!talent.titans_torment&(buff.recklessness.up|target.time_to_die<20)
      if S.Avatar:IsCastable() and (S.TitansTorment:IsAvailable() and EnrageUp or not S.TitansTorment:IsAvailable() and (Player:BuffUp(S.RecklessnessBuff) or HL.FightRemains() < 20)) then
        if Cast(S.Avatar, Settings.Fury.GCDasOffGCD.Avatar) then return "avatar main 32"; end
      end
      -- recklessness,if=!raid_event.adds.exists&(talent.annihilator&cooldown.avatar.remains<1|cooldown.avatar.remains>40|!talent.avatar|target.time_to_die<12)
      if S.Recklessness:IsCastable() and (S.Annihilator:IsAvailable() and S.Avatar:CooldownRemains() < 1 or S.Avatar:CooldownRemains() > 40 or (not S.Avatar:IsAvailable()) or HL.FightRemains() < 12) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 34"; end
      end
      -- recklessness,if=!raid_event.adds.exists&!talent.annihilator|target.time_to_die<12
      if S.Recklessness:IsCastable() and (not S.Annihilator:IsAvailable() or HL.FightRemains() < 12) then
        if Cast(S.Recklessness, Settings.Fury.GCDasOffGCD.Recklessness) then return "recklessness main 36"; end
      end
      -- spear_of_bastion,if=buff.enrage.up&(buff.recklessness.up|buff.avatar.up|target.time_to_die<20|active_enemies>1)&raid_event.adds.in>15
      if S.SpearofBastion:IsCastable() and (EnrageUp and (Player:BuffUp(S.RecklessnessBuff) or Player:BuffUp(S.AvatarBuff) or HL.FightRemains() < 20 or EnemiesCount8y > 1)) then
        if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(25)) then return "spear_of_bastion main 38"; end
      end
    end
    -- call_action_list,name=multi_target,if=raid_event.adds.exists|active_enemies>2
    if AoEON() and EnemiesCount8y > 2 then
      local ShouldReturn = MultiTarget(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single_target,if=!raid_event.adds.exists
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Fury Warrior rotation is currently a work in progress, but has been updated for patch 10.1.0.")
end

HR.SetAPL(72, APL, Init)
