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
-- WoW API
local Delay      = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Warrior.Arms
local I = Item.Warrior.Arms

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.Fyralath:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  CommonsDS = HR.GUISettings.APL.Warrior.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warrior.CommonsOGCD,
  Arms = HR.GUISettings.APL.Warrior.Arms
}

-- ===== Rotation Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketPriority
local VarAddsRemain, VarSTPlanning, VarExecutePhase
local TargetInMeleeRange
local Enemies8y, EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables (from Precombat) =====
local function SetTrinketVariables()
  Trinket1, Trinket2 = Player:GetTrinketItems()
  VarTrinket1ID = Trinket1:ID()
  VarTrinket2ID = Trinket2:ID()

  -- If we don't have trinket items, try again in 2 seconds.
  if VarTrinket1ID == 0 or VarTrinket2ID == 0 then
    Delay(2, function()
        Trinket1, Trinket2 = Player:GetTrinketItems()
        VarTrinket1ID = Trinket1:ID()
        VarTrinket2ID = Trinket2:ID()
      end
    )
  end

  VarTrinket1Spell = Trinket1:OnUseSpell()
  VarTrinket1Range = (VarTrinket1Spell and VarTrinket1Spell.MaximumRange > 0 and VarTrinket1Spell.MaximumRange <= 100) and VarTrinket1Spell.MaximumRange or 100
  VarTrinket1CastTime = VarTrinket1Spell and VarTrinket1Spell:CastTime() or 0
  VarTrinket2Spell = Trinket2:OnUseSpell()
  VarTrinket2Range = (VarTrinket2Spell and VarTrinket2Spell.MaximumRange > 0 and VarTrinket2Spell.MaximumRange <= 100) and VarTrinket2Spell.MaximumRange or 100
  VarTrinket2CastTime = VarTrinket2Spell and VarTrinket2Spell:CastTime() or 0

  VarTrinket1CD = Trinket1:Cooldown()
  VarTrinket2CD = Trinket2:Cooldown()

  VarTrinket1BL =  Player:IsItemBlacklisted(Trinket1)
  VarTrinket2BL =  Player:IsItemBlacklisted(Trinket2)

  VarTrinket1Exclude = (VarTrinket1ID == 193757 or VarTrinket1ID == 194301)
  VarTrinket2Exclude = (VarTrinket2ID == 193757 or VarTrinket2ID == 194301)

  VarTrinket1Sync = 0.5
  if Trinket1:HasUseBuff() and VarTrinket1CD % 90 == 0 then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if Trinket2:HasUseBuff() and VarTrinket2CD % 90 == 0 then
    VarTrinket2Sync = 1
  end

  VarTrinket1Buffs = Trinket1:HasUseBuff()
  VarTrinket2Buffs = Trinket2:HasUseBuff()

  -- Note: Using the below buff durations to avoid potential divide by zero errors.
  local T1BuffDuration = (Trinket1:BuffDuration() > 0) and Trinket1:BuffDuration() or 1
  local T2BuffDuration = (Trinket2:BuffDuration() > 0) and Trinket2:BuffDuration() or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDuration) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDuration) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end

  VarTrinket1Manual = VarTrinket1ID == I.AlgetharPuzzleBox:ID()
  VarTrinket2Manual = VarTrinket2ID == I.AlgetharPuzzleBox:ID()
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterLowestHP(TargetUnit)
  return TargetUnit:HealthPercentage()
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%cooldown.avatar.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%cooldown.avatar.duration=0)
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit&!variable.trinket_1_exclude)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit&!variable.trinket_2_exclude)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  -- Note: Moved the above variables to declarations and PLAYER_EQUIPMENT_CHANGED.
  -- Manually added: Group buff check
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 4"; end
  end
  -- battle_stance,toggle=on
  if S.BattleStance:IsCastable() and Player:BuffDown(S.BattleStance) then
    if Cast(S.BattleStance) then return "battle_stance precombat 6"; end
  end
  -- Manually added: pre-pull
  if TargetInMeleeRange then
    if S.Skullsplitter:IsCastable() then
      if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter precombat 8"; end
    end
    if S.ColossusSmash:IsCastable() then
      if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash precombat 10"; end
    end
    if S.Warbreaker:IsCastable() then
      if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInMeleeRange(8)) then return "warbreaker precombat 12"; end
    end
    if S.Overpower:IsCastable() then
      if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower precombat 14"; end
    end
  end
  if S.Charge:IsCastable() then
    if Cast(S.Charge, nil, nil, not Target:IsSpellInRange(S.Charge)) then return "charge precombat 16"; end
  end
end

local function Execute()
  -- sweeping_strikes,if=active_enemies>1
  if CDsON() and S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Everyone.CastTargetIf(S.SweepingStrikes, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 2"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Everyone.CastTargetIf(S.ThunderousRoar, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(12), Settings.Arms.GCDasOffGCD.ThunderousRoar) then return "thunderous_roar execute 4"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Everyone.CastTargetIf(S.ChampionsSpear, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsSpellInRange(S.ChampionsSpear), nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear) then return "champions_spear execute 6"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Everyone.CastTargetIf(S.Skullsplitter, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 8"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    if Everyone.CastTargetIf(S.Ravager, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(40), Settings.CommonsOGCD.GCDasOffGCD.Ravager) then return "ravager execute 10"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Everyone.CastTargetIf(S.Avatar, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, false, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar execute 12"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Everyone.CastTargetIf(S.ColossusSmash, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.Arms.GCDasOffGCD.ColossusSmash) then return "colossus_smash execute 14"; end
  end
  -- warbreaker,if=raid_event.adds.in>22
  if CDsON() and S.Warbreaker:IsCastable() then
    if Everyone.CastTargetIf(S.Warbreaker, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker execute 16"; end
  end
  -- mortal_strike,if=debuff.executioners_precision.stack=2
  if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2) then
    if Everyone.CastTargetIf(S.MortalStrike, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "mortal_strike execute 18"; end
  end
  -- overpower,if=rage<60
  if S.Overpower:IsCastable() and (Player:Rage() < 60) then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower execute 20"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute execute 22"; end
  end
  -- bladestorm
  if CDsON() and S.Bladestorm:IsCastable() then
    if Everyone.CastTargetIf(S.Bladestorm, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm) then return "bladestorm execute 24"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower execute 26"; end
  end
end

local function AoE()
  -- cleave,if=buff.strike_vulnerabilities.down|buff.collateral_damage.up&buff.merciless_bonegrinder.up
  if S.Cleave:IsReady() and (Player:BuffDown(S.StrikeVulnerabilitiesBuff) or Player:BuffUp(S.CollateralDamageBuff) and Player:BuffUp(S.MercilessBonegrinderBuff)) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave aoe 2"; end
  end
  -- thunder_clap,if=dot.rend.duration<3&active_enemies>=3
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 3 and EnemiesCount8y >= 3) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap aoe 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar aoe 6"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar aoe 8"; end
  end
  -- ravager,if=cooldown.sweeping_strikes.remains<=1|buff.sweeping_strikes.up
  if S.Ravager:IsCastable() and (S.SweepingStrikes:CooldownRemains() <= 1 or Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager aoe 10"; end
  end
  -- sweeping_strikes
  if S.SweepingStrikes:IsCastable() then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes aoe 12"; end
  end
  -- skullsplitter,if=buff.sweeping_strikes.up
  if S.Skullsplitter:IsCastable() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter aoe 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not TargetInMeleeRange) then return "warbreaker aoe 16"; end
  end
  -- bladestorm,if=talent.unhinged|talent.merciless_bonegrinder
  if S.Bladestorm:IsReady() and (S.Unhinged:IsAvailable() or S.MercilessBonegrinder:IsAvailable()) then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm aoe 18"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear aoe 20"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash aoe 22"; end
  end
  -- overpower,if=buff.sweeping_strikes.up&charges=2
  if S.Overpower:IsCastable() and (Player:BuffUp(S.SweepingStrikes) and S.Overpower:Charges() == 2) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower aoe 24"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave aoe 26"; end
  end
  -- mortal_strike,if=buff.sweeping_strikes.up
  if S.MortalStrike:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike aoe 28"; end
  end
  -- overpower,if=buff.sweeping_strikes.up
  if S.Overpower:IsCastable() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower aoe 30"; end
  end
  -- execute,if=buff.sweeping_strikes.up
  if S.Execute:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute aoe 32"; end
  end
  -- bladestorm
  if CDsON() and S.Bladestorm:IsCastable() then
    if Cast(S.Bladestorm, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm aoe 34"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower aoe 36"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsReady() then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap aoe 38"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike aoe 40"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute aoe 42"; end
  end
  -- whirlwind
  if S.Whirlwind:IsReady() then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind aoe 44"; end
  end
end

local function SingleTarget()
  -- thunder_clap,if=dot.rend.remains<=gcd&active_enemies>=2&buff.sweeping_strikes.down
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and EnemiesCount8y >= 2 and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap single_target 2"; end
  end
  -- sweeping_strikes,if=active_enemies>1
  if CDsON() and S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes single_target 4"; end
  end
  -- rend,if=dot.rend.remains<=gcd
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 6"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 8"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear single_target 10"; end
  end
  -- ravager
  if S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager single_target 12"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar single_target 14"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash single_target 16"; end
  end
  -- warbreaker
  if CDsON() and S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker single_target 18"; end
  end
  -- cleave,if=active_enemies>=3
  if S.Cleave:IsReady() and (EnemiesCount8y >= 3) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 20"; end
  end
  -- overpower,if=active_enemies>1&(buff.sweeping_strikes.up|talent.dreadnaught)&charges=2
  if S.Overpower:IsCastable() and (EnemiesCount8y > 1 and (Player:BuffUp(S.SweepingStrikesBuff) or S.Dreadnaught:IsAvailable()) and S.Overpower:Charges() == 2) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 22"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 24"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter single_target 26"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 28"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 30"; end
  end
  -- rend,if=dot.rend.remains<=8
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= 8) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 32"; end
  end
  -- cleave,if=active_enemies>=2&talent.fervor_of_battle
  if S.Cleave:IsReady() and (EnemiesCount8y >= 2 and S.FervorofBattle:IsAvailable()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 34"; end
  end
  -- slam
  if S.Slam:IsReady() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 36"; end
  end
end

local function Trinkets()
  -- use_item,name=fyralath_the_dreamrender,,if=dot.mark_of_fyralath.ticking&!talent.blademasters_torment|dot.mark_of_fyralath.ticking&cooldown.avatar.remains>3&cooldown.bladestorm.remains>3&!debuff.colossus_smash.up
  if Settings.Commons.Enabled.Items and I.Fyralath:IsEquippedAndReady() and (S.MarkofFyralathDebuff:AuraActiveCount() > 0 and not S.BlademastersTorment:IsAvailable() or S.MarkofFyralathDebuff:AuraActiveCount() > 0 and S.Avatar:CooldownRemains() > 3 and S.Bladestorm:CooldownRemains() > 3 and Target:DebuffDown(S.ColossusSmashDebuff)) then
    if Cast(I.Fyralath, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsItemInRange(I.Fyralath)) then return "fyralath_the_dreamrender trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,name=algethar_puzzle_box,if=cooldown.avatar.remains<=3
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Avatar:CooldownRemains() <= 3) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 4"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&buff.avatar.up&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  if Trinket1:IsReady() and not VarTrinket1BL and (VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket1CastTime > 0 or VarTrinket1CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or VarTrinket2CD or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= FightRemains) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 6"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&buff.avatar.up&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  if Trinket2:IsReady() and not VarTrinket2BL and (VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket2CastTime > 0 or VarTrinket2CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or VarTrinket1CD or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= FightRemains) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 8"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
  if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (not VarTrinket1Buffs and (VarTrinket2CD or not VarTrinket2Buffs) or (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
    if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 10"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
  if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (not VarTrinket2Buffs and (VarTrinket1CD or not VarTrinket1Buffs) or (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
    if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 12"; end
  end
  -- use_item,use_off_gcd=1,slot=main_hand,if=!equipped.fyralath_the_dreamrender&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  if Settings.Commons.Enabled.Items then
    local MainHandOnUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandOnUse and MainHandOnUse:IsReady() and (not I.Fyralath:IsEquipped() and (not VarTrinket1Buffs or VarTrinket1CD) and (not VarTrinket2Buffs or VarTrinket2CD)) then
      if Cast(MainHandOnUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "use_item for "..MainHandOnUse:Name().." trinkets 14"; end
    end
    -- Note: Adding a generic use_items for non-trinkets/non-weapons
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse and ItemSlot ~= 13 and ItemSlot ~= 14 and ItemSlot ~= 16 then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
    end
  end
end

local function Variables()
  -- variable,name=st_planning,value=active_enemies=1&(raid_event.adds.in>15|!raid_event.adds.exists)
  VarSTPlanning = (EnemiesCount8y == 1)
  -- variable,name=adds_remain,value=active_enemies>=2&(!raid_event.adds.exists|raid_event.adds.exists&raid_event.adds.remains>5)
  VarAddsRemain = (EnemiesCount8y >= 2)
  -- variable,name=execute_phase,value=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
  VarExecutePhase = (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20
end

--- ===== APL Main =====
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
  if AoEON() then
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Range check
    TargetInMeleeRange = Target:IsSpellInRange(S.MortalStrike)

    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: battle_shout during combat
    if S.BattleShout:IsCastable() and Settings.Commons.ShoutDuringCombat and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
      if Cast(S.BattleShout, Settings.CommonsOGCD.GCDasOffGCD.BattleShout) then return "battle_shout main 2"; end
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
    -- charge,if=time<=0.5|movement.distance>5
    if S.Charge:IsCastable() and (not TargetInMeleeRange) then
      if Cast(S.Charge, nil, Settings.CommonsDS.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 4"; end
    end
    -- auto_attack
    -- potion,if=gcd.remains=0&debuff.colossus_smash.remains>8|target.time_to_die<25
    if Settings.Commons.Enabled.Potions and (Target:DebuffRemains(S.ColossusSmashDebuff) > 8 or BossFightRemains < 25) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- pummel,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.Pummel, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if CDsON() then
      -- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&rage<50
      if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:Rage() < 50) then
        if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 8"; end
      end
      -- lights_judgment,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.LightsJudgment:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 10"; end
      end
      -- bag_of_tricks,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.BagofTricks:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 12"; end
      end
      -- berserking,if=target.time_to_die>180&buff.avatar.up|target.time_to_die<180&variable.execute_phase&buff.avatar.up|target.time_to_die<20
      if S.Berserking:IsCastable() and (Target:TimeToDie() > 180 and Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 180 and VarExecutePhase and Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 20) then
        if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking main 14"; end
      end
      -- blood_fury,if=debuff.colossus_smash.up
      if S.BloodFury:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury main 16"; end
      end
      -- fireblood,if=debuff.colossus_smash.up
      if S.Fireblood:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood main 18"; end
      end
      -- ancestral_call,if=debuff.colossus_smash.up
      if S.AncestralCall:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call main 20"; end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=debuff.colossus_smash.up&fight_remains>=135|variable.execute_phase&buff.avatar.up|fight_remains<=25
    -- Note: Not handling external buffs.
    -- run_action_list,name=aoe,if=active_enemies>2|talent.fervor_of_battle.enabled&variable.execute_phase&!raid_event.adds.up&active_enemies>1
    if AoEON() and (EnemiesCount8y > 2 or S.FervorofBattle:IsAvailable() and VarExecutePhase and EnemiesCount8y > 1) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoE()"; end
    end
    -- run_action_list,name=execute,target_if=min:target.health.pct,if=variable.execute_phase
    if VarExecutePhase then
      local ShouldReturn = Execute(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Execute()"; end
    end
    -- run_action_list,name=single_target
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Arms Warrior rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(71, APL, Init)
