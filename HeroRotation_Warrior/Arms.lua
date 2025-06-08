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
  -- Trinkets
  I.TreacherousTransmitter:ID(),
  -- Items
  I.BestinSlots:ID(),
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
local VarAddsRemain, VarSTPlanning, VarExecutePhase
local BladestormAbility = S.UnrelentingOnslaught:IsAvailable() and S.SlayerBladestorm or S.Bladestorm
local TargetInMeleeRange
local Enemies8y, EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Buffs, VarTrinket2Buffs
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarTrinket1Exclude = T1.ID == I.TreacherousTransmitter:ID()
  VarTrinket2Exclude = T2.ID == I.TreacherousTransmitter:ID()

  VarTrinket1Sync = 0.5
  if Trinket1:HasUseBuff() and VarTrinket1CD % 90 == 0 then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  if Trinket2:HasUseBuff() and VarTrinket2CD % 90 == 0 then
    VarTrinket2Sync = 1
  end

  VarTrinket1Buffs = Trinket1:HasUseBuff() or (Trinket1:HasStatAnyDps() and not VarTrinket1Exclude)
  VarTrinket2Buffs = Trinket2:HasUseBuff() or (Trinket2:HasStatAnyDps() and not VarTrinket2Exclude)

  -- Note: Using the below buff durations to avoid potential divide by zero errors.
  local T1BuffDuration = (Trinket1:BuffDuration() > 0) and Trinket1:BuffDuration() or 1
  local T2BuffDuration = (Trinket2:BuffDuration() > 0) and Trinket2:BuffDuration() or 1
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / T2BuffDuration) * (VarTrinket2Sync)) > ((VarTrinket1CD / T1BuffDuration) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
  end
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
  BladestormAbility = S.UnrelentingOnslaught:IsAvailable() and S.SlayerBladestorm or S.Bladestorm
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterLowestHP(TargetUnit)
  return TargetUnit:HealthPercentage()
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- variable,name=trinket_1_exclude,value=trinket.1.is.treacherous_transmitter
  -- variable,name=trinket_2_exclude,value=trinket.2.is.treacherous_transmitter
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=trinket.1.has_use_buff&(trinket.1.cooldown.duration%%cooldown.avatar.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=trinket.2.has_use_buff&(trinket.2.cooldown.duration%%cooldown.avatar.duration=0)
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff|(trinket.1.has_stat.any_dps&!variable.trinket_1_exclude)
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff|(trinket.2.has_stat.any_dps&!variable.trinket_2_exclude)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.strength)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.strength)*(variable.trinket_1_sync))
  -- variable,name=trinket_1_manual,value=trinket.1.is.algethar_puzzle_box
  -- variable,name=trinket_2_manual,value=trinket.2.is.algethar_puzzle_box
  -- Note: Moved the above variables to declarations and PLAYER_EQUIPMENT_CHANGED.
  -- Note: Ignoring trinket_x_manual variables. Nobody's using algethar_puzzle_box in 11.1.
  -- Manually added: Group buff check
  if S.BattleShout:IsCastable() and Everyone.GroupBuffMissing(S.BattleShoutBuff) then
    if Cast(S.BattleShout, nil, Settings.CommonsDS.DisplayStyle.BattleShout) then return "battle_shout precombat 2"; end
  end
  -- battle_stance,toggle=on
  if S.BattleStance:IsCastable() and Player:BuffDown(S.BattleStance) then
    if Cast(S.BattleStance) then return "battle_stance precombat 6"; end
  end
  -- Manually added: pre-pull
  if TargetInMeleeRange then
    if S.Skullsplitter:IsCastable() then
      if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not TargetInMeleeRange) then return "skullsplitter precombat 8"; end
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

local function ColossusAoE()
  -- cleave,if=!dot.deep_wounds.remains
  if S.Cleave:IsReady() and (Target:DebuffDown(S.DeepWoundsDebuff)) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave colossus_aoe 2"; end
  end
  -- thunder_clap,if=!dot.rend.remains
  if S.ThunderClap:IsReady() and (Target:DebuffDown(S.RendDebuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap colossus_aoe 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar colossus_aoe 6"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar colossus_aoe 8"; end
  end
  -- sweeping_strikes
  if CDsON() and S.SweepingStrikes:IsCastable() then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes colossus_aoe 10"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker colossus_aoe 12"; end
  end
  -- ravager
  if CDsON() and S.Ravager:IsCastable() then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager colossus_aoe 14"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear colossus_aoe 16"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash colossus_aoe 18"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave colossus_aoe 20"; end
  end
  -- bladestorm,if=talent.unhinged|talent.merciless_bonegrinder
  if CDsON() and BladestormAbility:IsCastable() and (S.Unhinged:IsAvailable() or S.MercilessBonegrinder:IsAvailable()) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm colossus_aoe 22"; end
  end
  -- thunder_clap,if=dot.rend.remains<5
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 5) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap colossus_aoe 24"; end
  end
  -- demolish,if=buff.colossal_might.stack=10&(debuff.colossus_smash.remains>=2|cooldown.colossus_smash.remains>=7)
  if S.Demolish:IsCastable() and (Player:BuffStack(S.ColossalMightBuff) == 10 and (Target:DebuffRemains(S.ColossusSmashDebuff) >= 2 or S.ColossusSmash:CooldownRemains() >= 7)) then
    if Cast(S.Demolish, nil, Settings.CommonsDS.DisplayStyle.Demolish, not TargetInMeleeRange) then return "demolish colossus_aoe 26"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike colossus_aoe 28"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower colossus_aoe 30"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsReady() then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap colossus_aoe 32"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter colossus_aoe 34"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute colossus_aoe 36"; end
  end
  -- bladestorm
  if CDsON() and BladestormAbility:IsCastable() then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm colossus_aoe 38"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw colossus_aoe 40"; end
  end
  -- whirlwind
  if S.Whirlwind:IsReady() then
    if Cast(S.Whirlwind, nil, nil, not TargetInMeleeRange) then return "whirlwind colossus_aoe 42"; end
  end
end

local function ColossusExecute()
  -- sweeping_strikes,if=active_enemies=2
  if S.SweepingStrikes:IsCastable() and (EnemiesCount8y == 2) then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes) then return "sweeping_strikes colossus_execute 2"; end
  end
  -- rend,if=dot.rend.remains<=gcd&!talent.bloodletting
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and not S.Bloodletting:IsAvailable()) then
    if Everyone.CastTargetIf(S.Rend, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "rend colossus_execute 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Everyone.CastTargetIf(S.ThunderousRoar, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(12), Settings.Arms.GCDasOffGCD.ThunderousRoar) then return "thunderous_roar colossus_execute 6"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Everyone.CastTargetIf(S.ChampionsSpear, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsSpellInRange(S.ChampionsSpear), nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear) then return "champions_spear colossus_execute 8"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<=gcd
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD()) then
    if Everyone.CastTargetIf(S.Ravager, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(40), Settings.CommonsOGCD.GCDasOffGCD.Ravager) then return "ravager colossus_execute 10"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Everyone.CastTargetIf(S.Avatar, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, false, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar colossus_execute 12"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Everyone.CastTargetIf(S.ColossusSmash, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.Arms.GCDasOffGCD.ColossusSmash) then return "colossus_smash colossus_execute 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Everyone.CastTargetIf(S.Warbreaker, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(8), Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker colossus_execute 16"; end
  end
  -- execute,if=buff.juggernaut.remains<=gcd&talent.juggernaut
  if S.Execute:IsReady() and (Player:BuffRemains(S.JuggernautBuff) <= Player:GCD() and S.Juggernaut:IsAvailable()) then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute colossus_execute 18"; end
  end
  -- skullsplitter,if=rage<40
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 40) then
    if Everyone.CastTargetIf(S.Skullsplitter, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(8), Settings.Arms.GCDasOffGCD.Skullsplitter) then return "skullsplitter colossus_execute 20"; end
  end
  -- demolish,if=debuff.colossus_smash.up
  if S.Demolish:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Everyone.CastTargetIf(S.Demolish, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, nil, Settings.CommonsDS.DisplayStyle.Demolish) then return "demolish colossus_execute 22"; end
  end
  -- mortal_strike,if=debuff.executioners_precision.stack=2&!buff.ravager.up|!talent.executioners_precision|talent.battlelord&debuff.executioners_precision.stack>0
  if S.MortalStrike:IsReady() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and Target:DebuffDown(S.RavagerDebuff) or not S.ExecutionersPrecision:IsAvailable() or S.Battlelord:IsAvailable() and Target:DebuffUp(S.ExecutionersPrecisionDebuff)) then
    if Everyone.CastTargetIf(S.MortalStrike, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "mortal_strike colossus_execute 24"; end
  end
  -- overpower,if=rage<90
  if S.Overpower:IsReady() and (Player:Rage() < 90) then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower colossus_execute 26"; end
  end
  -- execute,if=rage>=40&talent.executioners_precision
  if S.Execute:IsReady() and (Player:Rage() >= 40 and S.ExecutionersPrecision:IsAvailable()) then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute colossus_execute 28"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower colossus_execute 30"; end
  end
  -- bladestorm
  if CDsON() and BladestormAbility:IsCastable() then
    if Everyone.CastTargetIf(BladestormAbility, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm) then return "bladestorm colossus_execute 32"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Everyone.CastTargetIf(S.WreckingThrow, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(30)) then return "wrecking_throw colossus_execute 34"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute colossus_execute 36"; end
  end
end

local function ColossusST()
  -- rend,if=dot.rend.remains<=gcd
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend colossus_st 2"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar colossus_st 4"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<=gcd
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD()) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager colossus_st 6"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear colossus_st 8"; end
  end
  -- avatar,if=raid_event.adds.in>15
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar colossus_st 10"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash colossus_st 12"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker colossus_st 14"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike colossus_st 16"; end
  end
  -- demolish
  if S.Demolish:IsCastable() then
    if Cast(S.Demolish, nil, Settings.CommonsDS.DisplayStyle.Demolish, not TargetInMeleeRange) then return "demolish colossus_st 18"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter colossus_st 20"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute colossus_st 22"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower colossus_st 24"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw colossus_st 26"; end
  end
  -- rend,if=dot.rend.remains<=gcd*5
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() * 5) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend colossus_st 28"; end
  end
  -- slam
  if S.Slam:IsCastable() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam colossus_st 30"; end
  end
end

local function ColossusSweep()
  -- thunder_clap,if=!dot.rend.remains&!buff.sweeping_strikes.up
  if S.ThunderClap:IsReady() and (Target:DebuffDown(S.RendDebuff) and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap colossus_sweep 2"; end
  end
  -- rend,if=dot.rend.remains<=gcd&buff.sweeping_strikes.up
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend colossus_sweep 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar colossus_sweep 6"; end
  end
  -- sweeping_strikes
  if CDsON() and S.SweepingStrikes:IsCastable() then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes, nil, not Target:IsInMeleeRange(8)) then return "sweeping_strikes colossus_sweep 8"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear colossus_sweep 10"; end
  end
  -- ravager,if=cooldown.colossus_smash.ready
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownUp()) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager colossus_sweep 12"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar colossus_sweep 14"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash colossus_sweep 16"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker colossus_sweep 18"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike colossus_sweep 20"; end
  end
  -- demolish,if=debuff.colossus_smash.up
  if S.Demolish:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.Demolish, nil, Settings.CommonsDS.DisplayStyle.Demolish, not TargetInMeleeRange) then return "demolish colossus_sweep 22"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower colossus_sweep 24"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute colossus_sweep 26"; end
  end
  -- whirlwind,if=talent.fervor_of_battle
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not TargetInMeleeRange) then return "whirlwind colossus_sweep 28"; end
  end
  -- cleave,if=talent.fervor_of_battle
  if S.Cleave:IsReady() and (S.FervorofBattle:IsAvailable()) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave colossus_sweep 30"; end
  end
  -- thunder_clap,if=dot.rend.remains<=8&buff.sweeping_strikes.down
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 8 and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap colossus_sweep 32"; end
  end
  -- wrecking_throw,if=!buff.sweeping_strikes.up
  if S.WreckingThrow:IsCastable() and (Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw colossus_sweep 34"; end
  end
  -- rend,if=dot.rend.remains<=5
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= 5) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend colossus_sweep 36"; end
  end
  -- slam
  if S.Slam:IsReady() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam colossus_sweep 38"; end
  end
end

local function SlayerAoE()
  -- From below: Force StormBolt to the top while Bladestorm is up, as it's the only spell able to be cast.
  if S.StormBolt:IsReady() and (Player:BuffUp(BladestormAbility)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_aoe 2"; end
  end
  -- thunder_clap,if=!dot.rend.remains
  if S.ThunderClap:IsReady() and (Target:DebuffDown(S.RendDebuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap slayer_aoe 4"; end
  end
  -- sweeping_strikes
  if S.SweepingStrikes:IsCastable() then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes) then return "sweeping_strikes slayer_aoe 6"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_aoe 8"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar slayer_aoe 10"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear slayer_aoe 12"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<=gcd
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD()) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager slayer_aoe 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker slayer_aoe 16"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash slayer_aoe 18"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave slayer_aoe 20"; end
  end
  -- execute,if=buff.sudden_death.up&buff.imminent_demise.stack<3|buff.juggernaut.remains<3&talent.juggernaut
  if S.Execute:IsReady() and (Player:BuffUp(S.SuddenDeathBuff) and Player:BuffStack(S.ImminentDemiseBuff) < 3 or Player:BuffRemains(S.JuggernautBuff) < 3 and S.Juggernaut:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_aoe 22"; end
  end
  -- bladestorm
  if CDsON() and BladestormAbility:IsCastable() then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_aoe 24"; end
  end
  -- overpower,if=buff.sweeping_strikes.up&(buff.opportunist.up|talent.dreadnaught&!talent.juggernaut)
  if S.Overpower:IsCastable() and (Player:BuffUp(S.SweepingStrikesBuff) and (Player:BuffUp(S.OpportunistBuff) or S.Dreadnaught:IsAvailable() and not S.Juggernaut:IsAvailable())) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_aoe 26"; end
  end
  -- mortal_strike,if=buff.sweeping_strikes.up
  if S.MortalStrike:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike slayer_aoe 28"; end
  end
  -- execute,if=buff.sweeping_strikes.up&debuff.executioners_precision.stack<2&talent.executioners_precision|debuff.marked_for_execution.up
  if S.Execute:IsReady() and (Player:BuffUp(S.SweepingStrikesBuff) and Target:DebuffStack(S.ExecutionersPrecisionDebuff) < 2 and S.ExecutionersPrecision:IsAvailable() or Target:DebuffUp(S.MarkedforExecutionDebuff)) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_aoe 30"; end
  end
  -- skullsplitter,if=buff.sweeping_strikes.up
  if S.Skullsplitter:IsCastable() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter slayer_aoe 32"; end
  end
  -- overpower,if=buff.opportunist.up|talent.dreadnaught
  if S.Overpower:IsCastable() and (Player:BuffUp(S.OpportunistBuff) or S.Dreadnaught:IsAvailable()) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_aoe 34"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike slayer_aoe 36"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_aoe 38"; end
  end
  -- thunder_clap
  if S.ThunderClap:IsReady() then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap slayer_aoe 40"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_aoe 42"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw slayer_aoe 44"; end
  end
  -- whirlwind
  if S.Whirlwind:IsReady() then
    if Cast(S.Whirlwind, nil, nil, not TargetInMeleeRange) then return "whirlwind slayer_aoe 46"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter slayer_aoe 48"; end
  end
  -- slam
  if S.Slam:IsReady() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer_aoe 50"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  -- Note: Moved to the top of this function.
end

local function SlayerExecute()
  -- From below: Force StormBolt to the top while Bladestorm is up, as it's the only spell able to be cast.
  if S.StormBolt:IsReady() and (Player:BuffUp(BladestormAbility)) then
    if Everyone.CastTargetIf(S.StormBolt, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_execute 2"; end
  end
  -- sweeping_strikes,if=active_enemies=2
  if S.SweepingStrikes:IsCastable() and (EnemiesCount8y == 2) then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes) then return "sweeping_strikes slayer_execute 4"; end
  end
  -- rend,if=dot.rend.remains<=gcd&!talent.bloodletting
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD() and not S.Bloodletting:IsAvailable()) then
    if Everyone.CastTargetIf(S.Rend, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "rend slayer_execute 6"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_execute 8"; end
  end
  -- avatar,if=cooldown.colossus_smash.remains<=5|debuff.colossus_smash.up
  if CDsON() and S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() <= 5 or Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar slayer_execute 10"; end
  end
  -- champions_spear,if=debuff.colossus_smash.up|buff.avatar.up
  if CDsON() and S.ChampionsSpear:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.AvatarBuff)) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear slayer_execute 12"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<=gcd
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD()) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager slayer_execute 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Everyone.CastTargetIf(S.Warbreaker, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(8), Settings.Arms.GCDasOffGCD.Warbreaker) then return "warbreaker slayer_execute 16"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Everyone.CastTargetIf(S.ColossusSmash, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange, Settings.Arms.GCDasOffGCD.ColossusSmash) then return "colossus_smash slayer_execute 18"; end
  end
  -- execute,if=buff.juggernaut.remains<=gcd*2&talent.juggernaut
  if S.Execute:IsReady() and (Player:BuffRemains(S.JuggernautBuff) <= Player:GCD() * 2 and S.Juggernaut:IsAvailable()) then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute slayer_execute 20"; end
  end
  -- bladestorm,if=(debuff.executioners_precision.stack=2&(debuff.colossus_smash.remains>4|cooldown.colossus_smash.remains>15))|!talent.executioners_precision
  if CDsON() and BladestormAbility:IsCastable() and (Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and Target:DebuffRemains(S.ColossusSmashDebuff) > 4 or Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and S.ColossusSmash:CooldownRemains() > 15 or not S.ExecutionersPrecision:IsAvailable()) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_execute 22"; end
  end
  -- skullsplitter,if=rage<40
  if S.Skullsplitter:IsCastable() and (Player:Rage() < 40) then
    if Everyone.CastTargetIf(S.Skullsplitter, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInMeleeRange(8), Settings.Arms.GCDasOffGCD.Skullsplitter) then return "skullsplitter slayer_execute 24"; end
  end
  -- overpower,if=buff.overpower.stack<2&buff.opportunist.up&talent.opportunist&(talent.bladestorm|talent.ravager&rage<85)
  if S.Overpower:IsCastable() and (Player:BuffStack(S.OverpowerBuff) < 2 and Player:BuffUp(S.OpportunistBuff) and S.Opportunist:IsAvailable() and (BladestormAbility:IsLearned() or S.Ravager:IsAvailable() and Player:Rage() < 85)) then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower slayer_execute 26"; end
  end
  -- mortal_strike,if=dot.rend.remains<2|debuff.executioners_precision.stack=2&!buff.ravager.up
  if S.MortalStrike:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 2 or Target:DebuffStack(S.ExecutionersPrecisionDebuff) == 2 and Target:DebuffDown(S.RavagerDebuff)) then
    if Everyone.CastTargetIf(S.MortalStrike, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "mortal_strike slayer_execute 28"; end
  end
  -- overpower,if=rage<=40&buff.overpower.stack<2&talent.fierce_followthrough
  if S.Overpower:IsCastable() and (Player:Rage() <= 40 and Player:BuffStack(S.OverpowerBuff) < 2 and S.FierceFollowthrough:IsAvailable()) then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower slayer_execute 30"; end
  end
  -- execute
  if S.Execute:IsReady() then
    if Everyone.CastTargetIf(S.Execute, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "execute slayer_execute 32"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Everyone.CastTargetIf(S.Overpower, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not TargetInMeleeRange) then return "overpower slayer_execute 34"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Everyone.CastTargetIf(S.WreckingThrow, Enemies8y, "min", EvaluateTargetIfFilterLowestHP, nil, not Target:IsInRange(30)) then return "wrecking_throw slayer_execute 36"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  -- Note: Moved to the top of this function.
end

local function SlayerST()
  -- From below: Force StormBolt to the top while Bladestorm is up, as it's the only spell able to be cast.
  if S.StormBolt:IsReady() and (Player:BuffUp(BladestormAbility)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_st 2"; end
  end
  -- rend,if=dot.rend.remains<=gcd
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend slayer_st 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_st 6"; end
  end
  -- avatar,if=cooldown.colossus_smash.remains<=5|debuff.colossus_smash.up
  if CDsON() and S.Avatar:IsCastable() and (S.ColossusSmash:CooldownRemains() <= 5 or Target:DebuffUp(S.ColossusSmashDebuff)) then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar slayer_st 8"; end
  end
  -- champions_spear,if=debuff.colossus_smash.up|buff.avatar.up
  if CDsON() and S.ChampionsSpear:IsCastable() and (Target:DebuffUp(S.ColossusSmashDebuff) or Player:BuffUp(S.AvatarBuff)) then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear slayer_st 10"; end
  end
  -- ravager,if=cooldown.colossus_smash.remains<=gcd
  if CDsON() and S.Ravager:IsCastable() and (S.ColossusSmash:CooldownRemains() <= Player:GCD()) then
    if Cast(S.Ravager, Settings.CommonsOGCD.GCDasOffGCD.Ravager, nil, not Target:IsInRange(40)) then return "ravager slayer_st 12"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash slayer_st 14"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker slayer_st 16"; end
  end
  -- execute,if=buff.juggernaut.remains<=gcd*2&talent.juggernaut|buff.sudden_death.stack=2|buff.sudden_death.remains<=gcd*3|debuff.marked_for_execution.stack=3
  if S.Execute:IsReady() and (Player:BuffRemains(S.JuggernautBuff) <= Player:GCD() * 2 and S.Juggernaut:IsAvailable() or Player:BuffStack(S.SuddenDeathBuff) == 2 or Player:BuffRemains(S.SuddenDeathBuff) <= Player:GCD() * 3 or Target:DebuffStack(S.MarkedforExecutionDebuff) == 3) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_st 18"; end
  end
  -- overpower,if=buff.opportunist.up
  if S.Overpower:IsCastable() and (Player:BuffUp(S.OpportunistBuff)) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_st 20"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike slayer_st 22"; end
  end
  -- bladestorm,if=(cooldown.colossus_smash.remains>=gcd*4|cooldown.warbreaker.remains>=gcd*4)|debuff.colossus_smash.remains>=gcd*4
  if CDsON() and BladestormAbility:IsCastable() and ((S.ColossusSmash:CooldownRemains() >= Player:GCD() * 4 or S.Warbreaker:CooldownRemains() >= Player:GCD() * 4) or Target:DebuffRemains(S.ColossusSmashDebuff) >= Player:GCD() * 4) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_st 24"; end
  end
  -- skullsplitter
  if S.Skullsplitter:IsCastable() then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter slayer_st 26"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_st 28"; end
  end
  -- rend,if=dot.rend.remains<=8
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= 8) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend slayer_st 30"; end
  end
  -- execute,if=!talent.juggernaut
  if S.Execute:IsReady() and (not S.Juggernaut:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_st 32"; end
  end
  -- wrecking_throw
  if S.WreckingThrow:IsCastable() then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw slayer_st 34"; end
  end
  -- cleave
  if S.Cleave:IsReady() then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave slayer_st 36"; end
  end
  -- slam
  if S.Slam:IsReady() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer_st 38"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  -- Note: Moved to the top of this function.
end

local function SlayerSweep()
  -- From below: Force StormBolt to the top while Bladestorm is up, as it's the only spell able to be cast.
  if S.StormBolt:IsReady() and (Player:BuffUp(BladestormAbility)) then
    if Cast(S.StormBolt, nil, nil, not Target:IsInRange(20)) then return "storm_bolt slayer_sweep 2"; end
  end
  -- thunder_clap,if=!dot.rend.remains&!buff.sweeping_strikes.up
  if CDsON() and S.ThunderousRoar:IsCastable() and (Target:DebuffDown(S.RendDebuff) and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_sweep 4"; end
  end
  -- thunderous_roar
  if CDsON() and S.ThunderousRoar:IsCastable() then
    if Cast(S.ThunderousRoar, Settings.Arms.GCDasOffGCD.ThunderousRoar, nil, not Target:IsInMeleeRange(12)) then return "thunderous_roar slayer_sweep 6"; end
  end
  -- sweeping_strikes
  if S.SweepingStrikes:IsCastable() then
    if Cast(S.SweepingStrikes, Settings.Arms.GCDasOffGCD.SweepingStrikes) then return "sweeping_strikes slayer_sweep 8"; end
  end
  -- rend,if=dot.rend.remains<=gcd
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= Player:GCD()) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend slayer_sweep 10"; end
  end
  -- champions_spear
  if CDsON() and S.ChampionsSpear:IsCastable() then
    if Cast(S.ChampionsSpear, nil, Settings.CommonsDS.DisplayStyle.ChampionsSpear, not Target:IsSpellInRange(S.ChampionsSpear)) then return "champions_spear slayer_sweep 12"; end
  end
  -- avatar
  if CDsON() and S.Avatar:IsCastable() then
    if Cast(S.Avatar, Settings.Arms.GCDasOffGCD.Avatar) then return "avatar slayer_sweep 14"; end
  end
  -- colossus_smash
  if S.ColossusSmash:IsCastable() then
    if Cast(S.ColossusSmash, Settings.Arms.GCDasOffGCD.ColossusSmash, nil, not TargetInMeleeRange) then return "colossus_smash slayer_sweep 16"; end
  end
  -- warbreaker
  if S.Warbreaker:IsCastable() then
    if Cast(S.Warbreaker, Settings.Arms.GCDasOffGCD.Warbreaker, nil, not Target:IsInRange(8)) then return "warbreaker slayer_sweep 18"; end
  end
  -- skullsplitter,if=buff.sweeping_strikes.up
  if S.Skullsplitter:IsCastable() and (Player:BuffUp(S.SweepingStrikesBuff)) then
    if Cast(S.Skullsplitter, Settings.Arms.GCDasOffGCD.Skullsplitter, nil, not Target:IsInMeleeRange(8)) then return "skullsplitter slayer_sweep 20"; end
  end
  -- execute,if=buff.juggernaut.remains<=gcd*2|debuff.marked_for_execution.stack=3|buff.sudden_death.stack=2|buff.sudden_death.remains<=gcd*3
  if S.Execute:IsReady() and (Player:BuffRemains(S.JuggernautBuff) <= Player:GCD() * 2 or Target:DebuffStack(S.MarkedforExecutionDebuff) == 3 or Player:BuffStack(S.SuddenDeathBuff) == 2 or Player:BuffRemains(S.SuddenDeathBuff) <= Player:GCD() * 3) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_sweep 22"; end
  end
  -- bladestorm,if=(cooldown.colossus_smash.remains>=gcd*4|cooldown.warbreaker.remains>=gcd*4)|debuff.colossus_smash.remains>=gcd*4
  if CDsON() and BladestormAbility:IsCastable() and ((S.ColossusSmash:CooldownRemains() >= Player:GCD() * 4 or S.Warbreaker:CooldownRemains() >= Player:GCD() * 4) or Target:DebuffRemains(S.ColossusSmashDebuff) >= Player:GCD() * 4) then
    if Cast(BladestormAbility, Settings.CommonsOGCD.GCDasOffGCD.Bladestorm, nil, not TargetInMeleeRange) then return "bladestorm slayer_sweep 24"; end
  end
  -- overpower,if=buff.opportunist.up
  if S.Overpower:IsCastable() and (Player:BuffUp(S.OpportunistBuff)) then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_sweep 26"; end
  end
  -- mortal_strike
  if S.MortalStrike:IsReady() then
    if Cast(S.MortalStrike, nil, nil, not TargetInMeleeRange) then return "mortal_strike slayer_sweep 28"; end
  end
  -- overpower
  if S.Overpower:IsCastable() then
    if Cast(S.Overpower, nil, nil, not TargetInMeleeRange) then return "overpower slayer_sweep 30"; end
  end
  -- thunder_clap,if=dot.rend.remains<=8&buff.sweeping_strikes.down
  if S.ThunderClap:IsReady() and (Target:DebuffRemains(S.RendDebuff) < 8 and Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.ThunderClap, nil, nil, not TargetInMeleeRange) then return "thunder_clap slayer_sweep 32"; end
  end
  -- rend,if=dot.rend.remains<=5
  if S.Rend:IsCastable() and (Target:DebuffRemains(S.RendDebuff) <= 5) then
    if Cast(S.Rend, nil, nil, not TargetInMeleeRange) then return "rend slayer_sweep 34"; end
  end
  -- cleave,if=talent.fervor_of_battle&!buff.overpower.up
  if S.Cleave:IsReady() and (S.FervorofBattle:IsAvailable() and Player:BuffDown(S.OverpowerBuff)) then
    if Cast(S.Cleave, nil, nil, not TargetInMeleeRange) then return "cleave slayer_sweep 36"; end
  end
  -- whirlwind,if=talent.fervor_of_battle
  if S.Whirlwind:IsReady() and (S.FervorofBattle:IsAvailable()) then
    if Cast(S.Whirlwind, nil, nil, not TargetInMeleeRange) then return "whirlwind slayer_sweep 38"; end
  end
  -- execute,if=!talent.juggernaut
  if S.Execute:IsReady() and (not S.Juggernaut:IsAvailable()) then
    if Cast(S.Execute, nil, nil, not TargetInMeleeRange) then return "execute slayer_sweep 40"; end
  end
  -- wrecking_throw,if=!buff.sweeping_strikes.up
  if S.WreckingThrow:IsCastable() and (Player:BuffDown(S.SweepingStrikesBuff)) then
    if Cast(S.WreckingThrow, nil, nil, not Target:IsInRange(30)) then return "wrecking_throw slayer_sweep 42"; end
  end
  -- slam
  if S.Slam:IsReady() then
    if Cast(S.Slam, nil, nil, not TargetInMeleeRange) then return "slam slayer_sweep 44"; end
  end
  -- storm_bolt,if=buff.bladestorm.up
  -- Note: Moved to the top of this function.
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- do_treacherous_transmitter_task
    -- use_item,name=treacherous_transmitter,if=(variable.adds_remain|variable.st_planning)&cooldown.avatar.remains<3
    if I.TreacherousTransmitter:IsEquippedAndReady() and ((VarAddsRemain or VarSTPlanning) and S.Avatar:CooldownRemains() < 3) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 2"; end
    end
    -- use_item,slot=trinket1,if=variable.trinket_1_buffs&!variable.trinket_1_manual&(!buff.avatar.up&trinket.1.cast_time>0|!trinket.1.cast_time>0)&buff.avatar.up&(variable.trinket_2_exclude|!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1)|trinket.1.proc.any_dps.duration>=fight_remains
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarTrinket1Buffs and not VarTrinket1Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket1CastTime > 0 or VarTrinket1CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket2Exclude or not Trinket2:HasCooldown() or VarTrinket2CD or VarTrinketPriority == 1) or Trinket1:BuffDuration() >= FightRemains) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=variable.trinket_2_buffs&!variable.trinket_2_manual&(!buff.avatar.up&trinket.2.cast_time>0|!trinket.2.cast_time>0)&buff.avatar.up&(variable.trinket_1_exclude|!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2)|trinket.2.proc.any_dps.duration>=fight_remains
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarTrinket2Buffs and not VarTrinket2Manual and (Player:BuffDown(S.AvatarBuff) and VarTrinket2CastTime > 0 or VarTrinket2CastTime == 0) and Player:BuffUp(S.AvatarBuff) and (VarTrinket1Exclude or not Trinket1:HasCooldown() or VarTrinket1CD or VarTrinketPriority == 2) or Trinket2:BuffDuration() >= FightRemains) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 6"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|(trinket.1.cast_time>0&!buff.avatar.up|!trinket.1.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) and not VarTrinket1Manual and (not VarTrinket1Buffs and (VarTrinket2CD or not VarTrinket2Buffs) or (VarTrinket1CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket1CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "use_item for "..Trinket1:Name().." trinkets 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|(trinket.2.cast_time>0&!buff.avatar.up|!trinket.2.cast_time>0)|cooldown.avatar.remains_expected>20)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) and not VarTrinket2Manual and (not VarTrinket2Buffs and (VarTrinket1CD or not VarTrinket1Buffs) or (VarTrinket2CastTime > 0 and Player:BuffDown(S.AvatarBuff) or VarTrinket2CastTime == 0) or S.Avatar:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "use_item for "..Trinket2:Name().." trinkets 10"; end
    end
  end
  -- use_item,slot=main_hand,if=!equipped.fyralath_the_dreamrender&!equipped.bestinslots&(!variable.trinket_1_buffs|trinket.1.cooldown.remains)&(!variable.trinket_2_buffs|trinket.2.cooldown.remains)
  if Settings.Commons.Enabled.Items then
    -- Note: Adding a generic use_items for non-trinkets/non-weapons
    if not I.BestinSlots:IsEquipped() then
      local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
      if ItemToUse then
        if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 12"; end
      end
    end
    -- use_item,name=bestinslots,if=cooldown.avatar.remains>20|(buff.avatar.up&(!trinket.1.has_cooldown&!trinket.2.has_cooldown))
    if I.BestinSlots:IsEquippedAndReady() and (S.Avatar:CooldownRemains() > 20 or (Player:BuffUp(S.AvatarBuff) and (not Trinket1:HasCooldown() and not Trinket2:HasCooldown()))) then
      if Cast(I.BestinSlots, nil, Settings.CommonsDS.DisplayStyle.Items) then return "BestinSlots use_item 14"; end
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
      if Cast(S.BattleShout, nil, Settings.CommonsDS.DisplayStyle.BattleShout) then return "battle_shout main 2"; end
    end
    -- Manually added: VR/IV
    if Player:HealthPercentage() < Settings.Commons.VictoryRushHP then
      if S.VictoryRush:IsReady() then
        if Cast(S.VictoryRush, nil, Settings.CommonsDS.DisplayStyle.VictoryRush, not TargetInMeleeRange) then return "victory_rush heal"; end
      end
      if S.ImpendingVictory:IsReady() then
        if Cast(S.ImpendingVictory, nil, Settings.CommonsDS.DisplayStyle.VictoryRush, not TargetInMeleeRange) then return "impending_victory heal"; end
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
    -- run_action_list,name=colossus_aoe,if=talent.demolish&active_enemies>2
    if S.Demolish:IsAvailable() and AoEON() and EnemiesCount8y > 2 then
      local ShouldReturn = ColossusAoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ColossusAoE()"; end
    end
    -- run_action_list,name=colossus_execute,target_if=min:target.health.pct,if=talent.demolish&variable.execute_phase
    if S.Demolish:IsAvailable() and VarExecutePhase then
      local ShouldReturn = ColossusExecute(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ColossusExecute()"; end
    end
    -- run_action_list,name=colossus_sweep,if=talent.demolish&active_enemies=2&!variable.execute_phase
    if S.Demolish:IsAvailable() and AoEON() and EnemiesCount8y == 2 and not VarExecutePhase then
      local ShouldReturn = ColossusSweep(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ColossusSweep()"; end
    end
    -- run_action_list,name=colossus_st,if=talent.demolish
    if S.Demolish:IsAvailable() then
      local ShouldReturn = ColossusST(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ColossusST()"; end
    end
    -- run_action_list,name=slayer_aoe,if=talent.slayers_dominance&active_enemies>2
    if (S.SlayersDominance:IsAvailable() or Player:Level() < 71) and AoEON() and EnemiesCount8y > 2 then
      local ShouldReturn = SlayerAoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerAoE()"; end
    end
    -- run_action_list,name=slayer_execute,target_if=min:target.health.pct,if=talent.slayers_dominance&variable.execute_phase
    if (S.SlayersDominance:IsAvailable() or Player:Level() < 71) and VarExecutePhase then
      local ShouldReturn = SlayerExecute(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerExecute()"; end
    end
    -- run_action_list,name=slayer_sweep,if=talent.slayers_dominance&active_enemies=2&!variable.execute_phase
    if (S.SlayersDominance:IsAvailable() or Player:Level() < 71) and AoEON() and EnemiesCount8y == 2 and not VarExecutePhase then
      local ShouldReturn = SlayerSweep(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerSweep()"; end
    end
    -- run_action_list,name=slayer_st,if=talent.slayers_dominance
    if S.SlayersDominance:IsAvailable() or Player:Level() < 71 then
      local ShouldReturn = SlayerST(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for SlayerST()"; end
    end
    -- Pool if nothing else to suggest
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.MarkofFyralathDebuff:RegisterAuraTracking()

  HR.Print("Arms Warrior rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(71, APL, Init)
