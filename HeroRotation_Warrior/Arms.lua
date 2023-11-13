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
local S = Spell.Warrior.Arms
local I = Item.Warrior.Arms

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Variables
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketPriority
local TargetInMeleeRange
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Enemies Variables
local Enemies8y
local EnemiesCount8y

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warrior.Commons,
  Arms = HR.GUISettings.APL.Warrior.Arms
}

-- Interrupts List
local StunInterrupts = {
  {S.StormBolt, "Cast Storm Bolt (Interrupt)", function () return true; end},
}

local function EvaluateCycleColossusSmash(TargetUnit)
  -- if=(target.health.pct<20|talent.massacre&target.health.pct<35)
  return (TargetUnit:HealthPercentage() > 20 or S.Massacre:IsAvailable() and TargetUnit:HealthPercentage() < 35)
end

local function EvaluateCycleMortalStrike(TargetUnit)
  -- if=debuff.executioners_precision.stack=2|dot.deep_wounds.remains<=gcd|talent.dreadnaught&talent.battlelord&active_enemies<=2
  return (TargetUnit:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 or TargetUnit:DebuffRemains(S.DeepWoundsDebuff) <= Player:GCD() or S.Dreadnaught:IsAvailable() and S.Battlelord:IsAvailable() and EnemiesCount8y <= 2)
end

local function EvaluateCycleExecute(TargetUnit)
  --if=buff.sudden_death.react|active_enemies<=2&(target.health.pct<20|talent.massacre&target.health.pct<35)|buff.sweeping_strikes.up
  return (Player:BuffUp(S.SuddenDeathBuff) or EnemiesCount8y <= 2 and (TargetUnit:HealthPercentage() < 20 or S.Massacre:IsAvailable() and TargetUnit:HealthPercentage() < 35) or Player:BuffUp(S.SweepingStrikes) )
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  VarTrinket1Exclude = (trinket1:ID() == 193757 or trinket1:ID() == 194301)
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  VarTrinket2Exclude = (trinket2:ID() == 193757 or trinket2:ID() == 194301)
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%cooldown.avatar.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%cooldown.avatar.duration=0)
  -- Note: Sync variables used in priority calculation. Since we've simplified that condition, we don't need the sync variables.
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_buff.strength|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit&!variable.trinket_1_exclude)
  VarTrinket1Buffs = trinket1:HasUseBuff()
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_buff.strength|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit&!variable.trinket_2_exclude)
  VarTrinket2Buffs = trinket2:HasUseBuff()
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- Note: Currently unable to handle the above trinket condition, so using a much simplified version.
  VarTrinketPriority = (not VarTrinket1Buffs and VarTrinket2Buffs) and 2 or 1 
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  VarTrinket1Manual = (trinket1:ID() == I.AlgetharPuzzleBox:ID())
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  VarTrinket2Manual = (trinket2:ID() == I.AlgetharPuzzleBox:ID())
  -- Manually added: Group buff check
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 4"; end
  end
  -- battle_stance,toggle=on
  if S.BattleStance:IsCastable() and Player:BuffDown(S.BattleStance, true) then
    if Cast(S.BattleStance) then return "battle_stance precombat 6"; end
  end
  -- Manually added: pre-pull
  if TargetInMeleeRange then
    if S.Skullsplitter:IsCastable() then
      if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter precombat 8"; end
    end
    if S.ColossusSmash:IsCastable() then
      if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash precombat 10"; end
    end
    if S.Warbreaker:IsCastable() then
      if Cast(S.Warbreaker, nil, nil, not Target:IsInMeleeRange(8)) then return "warbreaker precombat 12"; end
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
  -- sweeping_strikes,if=spell_targets.whirlwind>1
  if CDsON() and S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 2"; end
  end
  -- rend,if=remains<=gcd&!talent.bloodletting&(!talent.warbreaker&cooldown.colossus_smash.remains<4|talent.warbreaker&cooldown.warbreaker.remains<4)&target.time_to_die>12
  if S.Rend:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and not S.Bloodletting:IsAvailable() and (not S.Warbreaker:IsAvailable() and S.ColossusSmash:CooldownRemains() < 4 or S.Warbreaker:IsAvailable() and S.Warbreaker:CooldownRemains() < 4) and Target:TimeToDie() > 12) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend execute 4"; end
  end
  -- avatar,if=cooldown.colossus_smash.ready|debuff.colossus_smash.up|target.time_to_die<20
  if CDsON() and S.Avatar:IsCastable() and (S.ColossusSmash:CooldownUp() or Target:DebuffUp(S.ColossusSmashDebuff) or FightRemains < 20) then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar execute 6"; end
  end
  -- warbreaker
  if CDsON() and S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not TargetInMeleeRange) then return "warbreaker execute 8"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash execute 10"; end
  end
  -- execute,if=buff.sudden_death.react&dot.deep_wounds.remains
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) and Target:DebuffUp(S.DeepWoundsDebuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 12"; end
  end
  -- skullsplitter,if=(talent.test_of_might&rage.pct<=30)|(!talent.test_of_might&(debuff.colossus_smash.up|cooldown.colossus_smash.remains>5)&rage.pct<=30)
  if S.Skullsplitter:IsCastable() and ((S.TestofMight:IsAvailable() and Player:RagePercentage() <= 30) or (not S.TestofMight:IsAvailable() and (Target:DebuffUp(S.ColossusSmashDebuff) or S.ColossusSmash:CooldownRemains() > 5) and Player:RagePercentage() <= 30)) then
    if Cast(S.Skullsplitter, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 14"; end
  end
  -- thunderous_roar,if=(talent.test_of_might&rage<40)|(!talent.test_of_might&(buff.avatar.up|debuff.colossus_smash.up)&rage<70)
  if CDsON() and S.ThunderousRoar:IsCastable() and ((S.TestofMight:IsAvailable() and Player:Rage() < 40) or (not S.TestofMight:IsAvailable() and (Player:BuffUp(S.AvatarBuff) or Target:DebuffUp(S.ColossusSmashDebuff)) and Player:Rage() < 70)) then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar execute 16"; end
  end
  -- spear_of_bastion,if=debuff.colossus_smash.up|buff.test_of_might.up
  if CDsON() and S.SpearofBastion:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff)) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion execute 18"; end
  end
  -- cleave,if=spell_targets.whirlwind>2&dot.deep_wounds.remains<gcd
  if S.Cleave:IsReady() and (EnemiesCount8y > 2 and Target:DebuffRemains(S.DeepWoundsDebuff) < Player:GCD()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave execute 20"; end
  end
  -- mortal_strike,if=debuff.executioners_precision.stack=2&debuff.colossus_smash.remains<=gcd
  if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and Target:DebuffRemains(S.ColossusSmashDebuff) <= Player:GCD()) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike execute 22"; end
  end
  -- overpower,if=rage<40&buff.martial_prowess.stack<2
  if S.Overpower:IsCastable() and (Player:Rage() < 40 and Player:BuffStack(S.MartialProwessBuff) < 2) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower execute 24"; end
  end
  -- mortal_strike,if=debuff.executioners_precision.stack=2
  if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike execute 26"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute execute 28"; end
  end
  -- shockwave,if=talent.sonic_boom
  if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Arms.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave execute 30"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower execute 32"; end
  end
  -- bladestorm
  if CDsON() and S.Bladestorm:IsCastable() then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm execute 34"; end
  end
end

local function Hac()
  -- execute,if=buff.juggernaut.up&buff.juggernaut.remains<gcd
  if S.Execute:IsReady() and (Player:BuffUp(S.JuggernautBuff) and Player:BuffRemains(S.JuggernautBuff) < Player:GCD()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute hac 2"; end
  end
  -- thunder_clap,if=active_enemies>2&talent.thunder_clap&talent.blood_and_thunder&talent.rend&dot.rend.remains<=dot.rend.duration*0.3
  if S.ThunderClap:IsReady() and (EnemiesCount8y > 2 and S.BloodandThunder:IsAvailable() and S.Rend:IsAvailable() and Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap hac 4"; end
  end
  -- sweeping_strikes,if=active_enemies>=2&(cooldown.bladestorm.remains>15|!talent.bladestorm)
  if S.SweepingStrikes:IsCastable() and (EnemiesCount8y >= 2 and (S.Bladestorm:CooldownRemains() > 15 or not S.Bladestorm:IsAvailable())) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes hac 6"; end
  end
  -- rend,if=active_enemies=1&remains<=gcd&(target.health.pct>20|talent.massacre&target.health.pct>35)|talent.tide_of_blood&cooldown.skullsplitter.remains<=gcd&(cooldown.colossus_smash.remains<=gcd|debuff.colossus_smash.up)&dot.rend.remains<dot.rend.duration*0.85
  if S.Rend:IsReady() and (EnemiesCount8y == 1 and Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and (Target:HealthPercentage() > 20 or S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or S.TideofBlood:IsAvailable() and S.Skullsplitter:CooldownRemains() <= Player:GCD() and (S.ColossusSmash:CooldownRemains() < Player:GCD() or Target:DebuffUp(S.ColossusSmashDebuff)) and Target:DebuffRemains(S.RendDebuff) < 21 * 0.85) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend hac 8"; end
  end
  -- avatar,if=raid_event.adds.in>15|talent.blademasters_torment&active_enemies>1|target.time_to_die<20
  if CDsON() and S.Avatar:IsCastable() and ((S.BlademastersTorment:IsAvailable() and EnemiesCount8y > 1) or FightRemains < 20) then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar hac 10"; end
  end
  -- warbreaker,if=raid_event.adds.in>22|active_enemies>1
  if S.Warbreaker:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.Warbreaker, nil, nil, not TargetInMeleeRange) then return "warbreaker hac 12"; end
  end
  -- colossus_smash,cycle_targets=1,if=(target.health.pct<20|talent.massacre&target.health.pct<35)
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Everyone.CastCycle(S.ColossusSmash, Enemies8y, EvaluateCycleColossusSmash, not TargetInMeleeRange) then return "colossus_smash hac 14"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash hac 16"; end
  end
  -- thunderous_roar,if=(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)&raid_event.adds.in>15|active_enemies>1&dot.deep_wounds.remains
  if CDsON() and S.ThunderousRoar:IsCastable() and ((Player:BuffUp(S.TestofMightBuff) or not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff)) or EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) > 0) then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar hac 18"; end
  end
  -- spear_of_bastion,if=(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)&raid_event.adds.in>15
  if CDsON() and S.SpearofBastion:IsCastable() and (Player:BuffUp(S.TestofMightBuff) or not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion hac 20"; end
  end
  -- bladestorm,if=talent.unhinged&(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)
  if CDsON() and S.Bladestorm:IsCastable() and (S.Unhinged:IsAvailable() and (Player:BuffUp(S.TestofMightBuff) or not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff))) then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm hac 22"; end
  end
  -- bladestorm,if=active_enemies>1&(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)&raid_event.adds.in>30|active_enemies>1&dot.deep_wounds.remains
  if CDsON() and S.Bladestorm:IsCastable() and (EnemiesCount8y > 1 and (Player:BuffUp(S.TestofMightBuff) or not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff)) or EnemiesCount8y > 1 and Target:DebuffRemains(S.DeepWoundsDebuff) > 0) then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm hac 24"; end
  end
  -- cleave,if=active_enemies>2|!talent.battlelord&buff.merciless_bonegrinder.up&cooldown.mortal_strike.remains>gcd
  if S.Cleave:IsReady() and (EnemiesCount8y > 2 or not S.Battlelord:IsAvailable() and Player:BuffUp(S.MercilessBonegrinderBuff) and S.MortalStrike:CooldownRemains() > Player:GCD()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave hac 26"; end
  end
  -- whirlwind,if=active_enemies>2|talent.storm_of_swords&(buff.merciless_bonegrinder.up|buff.hurricane.up)
  if S.Whirlwind:IsReady() and (EnemiesCount8y > 2 or S.StormofSwords:IsAvailable() and (Player:BuffUp(S.MercilessBonegrinderBuff) or Player:BuffUp(S.HurricaneBuff))) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind hac 28"; end
  end
  -- skullsplitter,if=rage<40|talent.tide_of_blood&dot.rend.remains&(buff.sweeping_strikes.up&active_enemies>=2|debuff.colossus_smash.up|buff.test_of_might.up)
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 40 or S.TideofBlood:IsAvailable() and Target:DebuffRemains(S.RendDebuff) > 0 and (Player:BuffUp(S.SweepingStrikes) and EnemiesCount8y > 2 or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff))) then
    if Cast(S.Skullsplitter, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes execute 30"; end
  end
  -- mortal_strike,if=buff.sweeping_strikes.up&buff.crushing_advance.stack=3,if=set_bonus.tier30_4pc
  -- Note: crushing_advance is the tier30_4pc bonus, so don't need to check for tier.
  if S.MortalStrike:IsReady() and (Player:BuffUp(S.SweepingStrikes) and Player:BuffStack(S.CrushingAdvanceBuff) == 3) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike hac 32"; end
  end
  -- overpower,if=buff.sweeping_strikes.up&talent.dreadnaught
  if S.Overpower:IsCastable() and (Player:BuffUp(S.SweepingStrikes) and S.Dreadnaught:IsAvailable()) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower hac 34"; end
  end
  -- mortal_strike,cycle_targets=1,if=debuff.executioners_precision.stack=2|dot.deep_wounds.remains<=gcd|talent.dreadnaught&talent.battlelord&active_enemies<=2
  if S.MortalStrike:IsReady() then
    if Everyone.CastCycle(S.MortalStrike, Enemies8y, EvaluateCycleMortalStrike, not TargetInMeleeRange) then return "mortal_strike hac 36"; end
  end
  -- execute,cycle_targets=1,if=buff.sudden_death.react|active_enemies<=2&(target.health.pct<20|talent.massacre&target.health.pct<35)|buff.sweeping_strikes.up
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) or EnemiesCount8y <= 2 and (Target:HealthPercentage() < 20 or S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Player:BuffUp(S.SweepingStrikes)) then
    if Everyone.CastCycle(S.Execute, Enemies8y, EvaluateCycleExecute, not TargetInMeleeRange) then return "execute hac 38"; end
  end
  -- thunderous_roar,if=raid_event.adds.in>15
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar hac 40"; end
  end
  -- shockwave,if=active_enemies>2&talent.sonic_boom
  if S.Shockwave:IsCastable() and (EnemiesCount8y > 2 and S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Arms.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave hac 42"; end
  end
  -- overpower,if=active_enemies=1&(charges=2&!talent.battlelord&(debuff.colossus_smash.down|rage.pct<25)|talent.battlelord)
  if S.Overpower:IsCastable() and (EnemiesCount8y == 1 and (S.Overpower:Charges() == 2 and not S.Battlelord:IsAvailable() and (Target:Debuffdown(S.ColossusSmashDebuff) or Player:RagePercentage() < 25) or S.Battlelord:IsAvailable())) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower hac 44"; end
  end
  -- slam,if=active_enemies=1&!talent.battlelord&rage.pct>70
  if S.Slam:IsReady() and (EnemiesCount8y == 1 and not S.Battlelord:IsAvailable() and Player:RagePercentage() > 70) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam hac 46"; end
  end
  -- overpower,if=charges=2&(!talent.test_of_might|talent.test_of_might&debuff.colossus_smash.down|talent.battlelord)|rage<70
  if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2 and (not S.TestofMight:IsAvailable() or S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff) or S.Battlelord:IsAvailable()) or Player:Rage() < 70) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower hac 48"; end
  end
  -- thunder_clap,if=active_enemies>2
  if S.ThunderClap:IsReady() and (EnemiesCount8y > 2) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap hac 50"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike hac 52"; end
  end
  -- rend,if=active_enemies=1&dot.rend.remains<duration*0.3
  if S.Rend:IsReady() and (EnemiesCount8y == 1 and Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend hac 54"; end
  end
  -- whirlwind,if=talent.storm_of_swords|talent.fervor_of_battle&active_enemies>1
  if S.Whirlwind:IsReady() and (S.StormofSwords:IsAvailable() or (S.FervorofBattle:IsAvailable() and EnemiesCount8y > 1)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind hac 56"; end
  end
  -- cleave,if=!talent.crushing_force
  if S.Cleave:IsReady() and (not S.CrushingForce:IsAvailable()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave hac 58"; end
  end
  -- ignore_pain,if=talent.battlelord&talent.anger_management&rage>30&(target.health.pct>20|talent.massacre&target.health.pct>35)
  if S.IgnorePain:IsReady() and (S.Battlelord:IsAvailable() and S.AngerManagement:IsAvailable() and Player:Rage() > 30 and (Target:HealthPercentage() > 20 or S.Massacre:IsAvailable() and Target:HealthPercentage() > 35)) then
    if Cast(S.IgnorePain, Settings.Arms.GCDasOffGCD.IgnorePain) then return "ignore_pain hac 60"; end
  end
  -- slam,if=talent.crushing_force&rage>30&(talent.fervor_of_battle&active_enemies=1|!talent.fervor_of_battle)
  if S.Slam:IsReady() and (S.CrushingForce:IsAvailable() and Player:Rage() > 30 and (S.FervorofBattle:IsAvailable() and EnemiesCount8y == 1 or not S.FervorofBattle:IsAvailable())) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam hac 62"; end
  end
  -- shockwave,if=talent.sonic_boom
  if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Arms.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave hac 64"; end
  end
  -- bladestorm,if=raid_event.adds.in>30
  if CDsON() and S.Bladestorm:IsCastable() then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm hac 66"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw hac 68"; end
  end
end

local function SingleTarget()
  -- sweeping_strikes,if=spell_targets.whirlwind>1
  if CDsON() and S.SweepingStrikes:IsCastable() and (EnemiesCount8y > 1) then
    if Cast(S.SweepingStrikes, nil, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes single_target 2"; end
  end
  -- execute,if=buff.sudden_death.react
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute single_target 4"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike single_target 6"; end
  end
  -- thunder_clap,if=!dot.rend.remains
  if S.ThunderClap:IsReady() and (Target:DebuffDown(S.RendDebuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap single_target 8"; end
  end
  -- avatar,if=talent.warlords_torment&(cooldown.colossus_smash.ready|debuff.colossus_smash.up|buff.test_of_might.up)|!talent.warlords_torment&(cooldown.colossus_smash.ready|debuff.colossus_smash.up)
  if CDsON() and S.Avatar:IsCastable() and ((S.WarlordsTorment:IsAvailable() and (S.ColossusSmash:CooldownUp() or Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.TestofMightBuff))) or (not S.WarlordsTorment:IsAvailable() and (S.ColossusSmash:CooldownUp() or Target:DebuffUp(S.ColossusSmashDebuff)))) then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar single_target 10"; end
  end
  -- spear_of_bastion,if=cooldown.colossus_smash.remains<=gcd|cooldown.warbreaker.remains<=gcd
  if CDsON() and S.SpearofBastion:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD() or S.Warbreaker:CooldownRemains() <= Player:GCD()) then
    if Cast(S.SpearofBastion, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.SpearofBastion)) then return "spear_of_bastion single_target 12"; end
  end
  -- warbreaker
  if CDsON() and S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, nil, nil, not Target:IsInRange(8)) then return "warbreaker single_target 14"; end
  end
  -- colossus_smash
  if CDsON() and S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, nil, nil, not TargetInMeleeRange) then return "colossus_smash single_target 16"; end
  end
  -- skullsplitter,if=!talent.test_of_might&dot.deep_wounds.remains&(debuff.colossus_smash.up|cooldown.colossus_smash.remains>3)
  if S.Skullsplitter:IsCastable() and (not S.TestofMight:IsAvailable() and Target:DebuffUp(S.DeepWoundsDebuff) and (Target:DebuffUp(S.ColossusSmashDebuff) or S.ColossusSmash:CooldownRemains() > 3)) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter single_target 18"; end
  end
  -- skullsplitter,if=talent.test_of_might&dot.deep_wounds.remains
  if S.Skullsplitter:IsCastable() and (S.TestofMight:IsAvailable() and Target:DebuffUp(S.DeepWoundsDebuff)) then
    if Cast(S.Skullsplitter, nil, nil, not TargetInMeleeRange) then return "skullsplitter single_target 20"; end
  end
  -- thunderous_roar,if=buff.test_of_might.up|debuff.colossus_smash.up|debuff.colossus_smash.up|cooldown.colossus_smash.remains<3|buff.avatar.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (Player:BuffUp(S.TestofMightBuff) or Target:DebuffUp(S.ColossusSmashDebuff) or S.ColossusSmash:CooldownRemains() < 3 or Player:BuffUp(S.AvatarBuff)) then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar single_target 22"; end
  end
  -- whirlwind,if=talent.storm_of_swords&talent.test_of_might&rage.pct>80&debuff.colossus_smash.up
  if S.Whirlwind:IsReady() and (S.StormofSwords:IsAvailable() and S.TestofMight:IsAvailable() and Player:RagePercentage() > 80 and Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 24"; end
  end
  -- thunder_clap,if=dot.rend.remains<=gcd&!talent.tide_of_blood
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and not S.TideofBlood:IsAvailable()) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap single_target 26"; end
  end
  -- bladestorm,if=talent.hurricane&(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)|talent.unhinged&(buff.test_of_might.up|!talent.test_of_might&debuff.colossus_smash.up)
  if CDsON() and S.Bladestorm:IsCastable() and (S.Hurricane:IsAvailable() and (Player:BuffUp(S.TestofMightBuff) or (not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff))) or S.Unhinged:IsAvailable() and (Player:BuffUp(S.TestofMightBuff) or (not S.TestofMight:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff)))) then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm single_target 28"; end
  end
  -- shockwave,if=talent.sonic_boom.enabled
  if S.Shockwave:IsCastable() and (S.SonicBoom:IsAvailable()) then
    if Cast(S.Shockwave, Settings.Arms.GCDasOffGCD.Shockwave, nil, not Target:IsInMeleeRange(10)) then return "shockwave single_target 30"; end
  end
  -- whirlwind,if=talent.storm_of_swords&talent.test_of_might&cooldown.colossus_smash.remains>gcd*7
  if S.Whirlwind:IsReady() and (S.StormofSwords:IsAvailable() and S.TestofMight:IsAvailable() and Target:DebuffRemains(S.ColossusSmashDebuff) > Player:GCD() * 7) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 32"; end
  end
  -- overpower,if=charges=2&!talent.battlelord&(debuff.colossus_smash.down|rage.pct<25)|talent.battlelord
  if S.Overpower:IsCastable() and (S.Overpower:Charges() == 2 and not S.Battlelord:IsAvailable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:RagePercentage() < 25) or S.Battlelord:IsAvailable()) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 34"; end
  end
  -- slam,if=(talent.crushing_force&debuff.colossus_smash.up&rage>=60&talent.test_of_might|talent.improved_slam)&(!talent.fervor_of_battle|talent.fervor_of_battle&active_enemies=1)
  if S.Slam:IsReady() and ((S.CrushingForce:IsAvailable() and Target:DebuffUp(S.ColossusSmashDebuff) and Player:Rage() >= 60 and S.TestofMight:IsAvailable() or S.ImprovedSlam:IsAvailable()) and (not S.FervorofBattle:IsAvailable() or S.FervorofBattle:IsAvailable() and EnemiesCount8y == 1)) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 36"; end
  end
  -- whirlwind,if=talent.fervor_of_battle&active_enemies>1
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable() and EnemiesCount8y > 1) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInMeleeRange(8)) then return "whirlwind single_target 38"; end
  end
  -- slam,if=(talent.crushing_force|!talent.crushing_force&rage>=30)&(!talent.fervor_of_battle|talent.fervor_of_battle&active_enemies=1)
  if S.Slam:IsReady() and ((S.CrushingForce:IsAvailable() or not S.CrushingForce:IsAvailable() and Player:Rage() >= 30) and (not S.FervorofBattle:IsAvailable() or S.FervorofBattle:IsAvailable() and EnemiesCount8y == 1)) then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam single_target 40"; end
  end
  -- thunder_clap,if=talent.battlelord&talent.blood_and_thunder
  if S.ThunderClap:IsReady() and (S.Battlelord:IsAvailable() and S.BloodandThunder:IsAvailable()) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap single_target 42"; end
  end
  -- overpower,if=debuff.colossus_smash.down&rage.pct<50&!talent.battlelord|rage.pct<25
  if S.Overpower:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and Player:RagePercentage() < 50 and not S.Battlelord:IsAvailable() or Player:RagePercentage() < 25) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower single_target 44"; end
  end
  -- whirlwind,if=!talent.storm_of_swords
  if S.Whirlwind:IsReady() and (not S.StormofSwords:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not Target:IsInRange(8)) then return "whirlwind single_target 46"; end
  end
  -- cleave,if=set_bonus.tier29_2pc&!talent.crushing_force
  if S.Cleave:IsReady() and (Player:HasTier(29, 2) and not S.CrushingForce:IsAvailable()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 48"; end
  end
  -- bladestorm
  if CDsON() and S.Bladestorm:IsCastable() then
    if Cast(S.Bladestorm, Settings.Arms.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm single_target 50"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave single_target 52"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw single_target 54"; end
  end
  -- rend,if=!talent.crushing_force&remains<duration*0.3
  if S.Rend:IsReady() and (not S.CrushingForce:IsAvailable() and Target:DebuffRefreshable(S.RendDebuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend single_target 56"; end
  end
end

local function Trinkets()
  -- use_item,use_off_gcd=1,name=algethar_puzzle_box,if=cooldown.avatar.remains<=3
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Avatar:CooldownRemains() <= 3) then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 2"; end
  end
  local Trinket1Item, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
  local Trinket2Item, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
  local Trinket1Spell = Trinket1Item and Trinket1Item:OnUseSpell() or Spell(0)
  local Trinket2Spell = Trinket2Item and Trinket2Item:OnUseSpell() or Spell(0)
  -- use_item,use_off_gcd=1,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&buff.avatar.up&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
  if Trinket1Item and Trinket1Item:IsReady() and (VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffDown(S.AvatarBuff) and Trinket1Spell:CastTime() > 0 or Trinket1Spell:CastTime() == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket2Exclude or not trinket2:HasCooldown() or trinket2:CooldownDown() or VarTrinketPriority == 1) or FightRemains <= 30) then
    if Cast(Trinket1Item, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "use_item for "..Trinket1Item:Name().." trinkets 4"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&buff.avatar.up&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
  if Trinket2Item and Trinket2Item:IsReady() and (VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffDown(S.AvatarBuff) and Trinket2Spell:CastTime() > 0 or Trinket2Spell:CastTime() == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket1Exclude or not trinket1:HasCooldown() or trinket1:CooldownDown() or VarTrinketPriority == 2) or FightRemains <= 30) then
    if Cast(Trinket2Item, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "use_item for "..Trinket2Item:Name().." trinkets 6"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
  if Trinket1Item and Trinket1Item:IsReady() and (not VarTrinket1Buffs and not VarTrinket1Manual and (not VarTrinket1Buffs and (trinket2:CooldownDown() or not VarTrinket2Buffs) or (Trinket1Spell:CastTime() > 0 and Player:BuffDown(S.AvatarBuff) or Trinket1Spell:CastTime() == 0) or S.Avatar:CooldownRemains() > 20)) then
    if Cast(Trinket1Item, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "use_item for "..Trinket1Item:Name().." trinkets 8"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
  if Trinket2Item and Trinket2Item:IsReady() and (not VarTrinket2Buffs and not VarTrinket2Manual and (not VarTrinket2Buffs and (trinket1:CooldownDown() or not VarTrinket1Buffs) or (Trinket2Spell:CastTime() > 0 and Player:BuffDown(S.AvatarBuff) or Trinket2Spell:CastTime() == 0) or S.Avatar:CooldownRemains() > 20)) then
    if Cast(Trinket2Item, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "use_item for "..Trinket2Item:Name().." trinkets 10"; end
  end
  -- use_item,use_off_gcd=1,slot=main_hand,if=(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  local MainHandOnUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
  if MainHandOnUse and MainHandOnUse:IsReady() and ((not VarTrinket1Buffs or trinket1:CooldownDown()) and (not VarTrinket2Buffs or trinket2:CooldownDown())) then
    if Cast(MainHandOnUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(MainHandRange)) then return "use_item for "..MainHandOnUse:Name().." trinkets 12"; end
  end
  -- Note: Adding a generic use_items for non-trinkets/non-weapons
  if Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse and ItemSlot ~= 13 and ItemSlot ~= 14 and ItemSlot ~= 16 then
      if Cast(ItemToUse, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
    end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    EnemiesCount8y = #Enemies8y
  else
    EnemiesCount8y = 1
  end

  -- Range check
  TargetInMeleeRange = Target:IsInMeleeRange(5)

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10yd, false)
    end
  end

  if Everyone.TargetIsValid() then
    -- call Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: battle_shout during combat
    if S.BattleShout:IsCastable() and Settings.Commons.ShoutDuringCombat and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
      if Cast(S.BattleShout, Settings.Commons.GCDasOffGCD.BattleShout) then return "battle_shout main 2"; end
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
      if Cast(S.Charge, nil, Settings.Commons.DisplayStyle.Charge, not Target:IsSpellInRange(S.Charge)) then return "charge main 4"; end
    end
    -- auto_attack
    -- potion,if=gcd.remains=0&debuff.colossus_smash.remains>8|target.time_to_die<25
    if Settings.Commons.Enabled.Potions and (Target:DebuffRemains(S.ColossusSmashDebuff) > 8 or FightRemains < 25) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 6"; end
      end
    end
    -- pummel,if=target.debuff.casting.react (Interrupts)
    local ShouldReturn = Everyone.Interrupt(5, S.Pummel, Settings.Commons.OffGCDasOffGCD.Pummel, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if CDsON() then
      -- arcane_torrent,if=cooldown.mortal_strike.remains>1.5&rage<50
      if S.ArcaneTorrent:IsCastable() and (S.MortalStrike:CooldownRemains() > 1.5 and Player:Rage() < 50) then
        if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 8"; end
      end
      -- lights_judgment,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.LightsJudgment:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 10"; end
      end
      -- bag_of_tricks,if=debuff.colossus_smash.down&cooldown.mortal_strike.remains
      if S.BagofTricks:IsCastable() and (Target:DebuffDown(S.ColossusSmashDebuff) and not S.MortalStrike:CooldownUp()) then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks main 12"; end
      end
      -- berserking,if=target.time_to_die>180&buff.avatar.up|target.time_to_die<180&(target.health.pct<35&talent.massacre|target.health.pct<20)&buff.avatar.up|target.time_to_die<20
      if S.Berserking:IsCastable() and (Target:TimeToDie() > 180 and Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 180 and (Target:HealthPercentage() < 35 and S.Massacre:IsAvailable() or Target:HealthPercentage() < 20) and Player:BuffUp(S.AvatarBuff) or Target:TimeToDie() < 20) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 14"; end
      end
      -- blood_fury,if=debuff.colossus_smash.up
      if S.BloodFury:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 16"; end
      end
      -- fireblood,if=debuff.colossus_smash.up
      if S.Fireblood:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 18"; end
      end
      -- ancestral_call,if=debuff.colossus_smash.up
      if S.AncestralCall:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 20"; end
      end
    end
    -- run_action_list,name=hac,if=raid_event.adds.up&active_enemies>2|!raid_event.adds.up&active_enemies>2
    if AoEON() and EnemiesCount8y > 2 then
      local ShouldReturn = Hac(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Hac()"; end
    end
    -- call_action_list,name=execute,target_if=min:target.health.pct,if=(talent.massacre.enabled&target.health.pct<35)|target.health.pct<20
    if (S.Massacre:IsAvailable() and Target:HealthPercentage() < 35) or Target:HealthPercentage() < 20 then
      local ShouldReturn = Execute(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=single_target,if=!raid_event.adds.exists
    local ShouldReturn = SingleTarget(); if ShouldReturn then return ShouldReturn; end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("Arms Warrior rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(71, APL, Init)
