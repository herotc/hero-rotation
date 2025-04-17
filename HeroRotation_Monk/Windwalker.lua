-- ----- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Utils         = HL.Utils
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local MultiSpell    = HL.MultiSpell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastAnnotated = HR.CastAnnotated
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua
local mathmin       = math.min
local pairs         = pairs
local tinsert       = table.insert
-- WoW API
local Delay         = C_Timer.After
-- File locals
local Monk          = HR.Commons.Monk

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker
local I = Item.Monk.Windwalker

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.ImperfectAscendancySerum:ID(),
  I.JunkmaestrosMegaMagnet:ID(),
  I.MadQueensMandate:ID(),
  I.SignetofthePriory:ID(),
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General     = HR.GUISettings.General,
  Commons     = HR.GUISettings.APL.Monk.Commons,
  CommonsDS   = HR.GUISettings.APL.Monk.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Monk.CommonsOGCD,
  Windwalker  = HR.GUISettings.APL.Monk.Windwalker
}

--- ===== Rotation Variables =====
local VarTotMMaxStacks = 4
local MotCCount, MotCMinTime
local Enemies5y, Enemies8y, EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Item Objects =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

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
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local Stuns = {}
if S.LegSweep:IsAvailable() then tinsert(Stuns, { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end }) end
if S.RingofPeace:IsAvailable() then tinsert(Stuns, { S.RingofPeace, "Cast Ring Of Peace (Stun)", function () return true end }) end
if S.Paralysis:IsAvailable() then tinsert(Stuns, { S.Paralysis, "Cast Paralysis (Stun)", function () return true end }) end

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarFoPPreChan = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  for i = 0, #Stuns do Stuns[i] = nil end
  if S.LegSweep:IsAvailable() then tinsert(Stuns, { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end }) end
  if S.RingofPeace:IsAvailable() then tinsert(Stuns, { S.RingofPeace, "Cast Ring Of Peace (Stun)", function () return true end }) end
  if S.Paralysis:IsAvailable() then tinsert(Stuns, { S.Paralysis, "Cast Paralysis (Stun)", function () return true end }) end
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

--- ===== Helper Functions =====
local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

local function MotCMinTimeCheck()
  local MinTime = 999
  for _, CycleUnit in pairs(Enemies8y) do
    local UnitTime = CycleUnit:DebuffRemains(S.MarkoftheCraneDebuff)
    if CycleUnit:DebuffUp(S.MarkoftheCraneDebuff) and UnitTime < MinTime then
      MinTime = UnitTime
    end
  end
  if MinTime == 999 then return 0 end
  return MinTime
end

local function MotCCastSwitcher(SpellToCast, Enemies, Mode, ETIF, ETI, Range)
  if MotCCount < mathmin(Settings.Windwalker.MotCCountThreshold, EnemiesCount8y) or MotCMinTime < Settings.Windwalker.MotCMinTimeThreshold then
    return Everyone.CastTargetIf(SpellToCast, Enemies, Mode, ETIF, ETI, not Target:IsInMeleeRange(Range))
  else
    return Cast(SpellToCast, nil, nil, not Target:IsInMeleeRange(Range))
  end
end

-- LEGACY CODE: This function is not currently used in the rotation.
-- Originally checked if all enemies have Mark of the Crane or if there are 5+ targets with it.
-- local function SCKMax()
--   local Count = MotCCount
--   if (EnemiesCount8y == Count or Count >= 5) then return true end
--   return false
-- end

local function ToDTarget()
  if not (S.TouchofDeath:CooldownUp() or Player:BuffUp(S.HiddenMastersForbiddenTouchBuff)) then return nil end
  local BestUnit, BestConditionValue = nil, nil
  for _, CycleUnit in pairs(Enemies5y) do
    if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy()) and (S.ImpTouchofDeath:IsAvailable() and CycleUnit:HealthPercentage() <= 15 or CycleUnit:Health() < Player:Health()) and (not BestConditionValue or Utils.CompareThis("max", CycleUnit:Health(), BestConditionValue)) then
      BestUnit, BestConditionValue = CycleUnit, CycleUnit:Health()
    end
  end
  if BestUnit and BestUnit == Target then
    if not S.TouchofDeath:IsReady() then return nil; end
  end
  return BestUnit
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterAcclamation(TargetUnit)
  return TargetUnit:DebuffRemains(S.AcclamationDebuff)
end

local function EvaluateTargetIfFilterMarkoftheCrane(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  return TargetUnit:TimeToDie()
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- use_item,name=imperfect_ascendancy_serum
  if I.ImperfectAscendancySerum:IsEquippedAndReady() then
    if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum precombat 2"; end
  end
  -- Manually added: openers
  -- tiger_palm,if=!prev.tiger_palm
  if S.TigerPalm:IsReady() and (not Player:PrevGCD(1, S.TigerPalm)) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm precombat 4"; end
  end
  -- rising_sun_kick
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick precombat 6"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=imperfect_ascendancy_serum,use_off_gcd=1,if=pet.xuen_the_white_tiger.active
    if I.ImperfectAscendancySerum:IsEquippedAndReady() and (Monk.Xuen.Active) then
      if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum trinkets 2"; end
    end
    -- use_item,name=mad_queens_mandate,target_if=min:time_to_die,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30
    if I.MadQueensMandate:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
      if Everyone.CastTargetIf(I.MadQueensMandate, Enemies8y, "min", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(50)) then return "mad_queens_mandate trinkets 4"; end
    end
    -- use_item,name=treacherous_transmitter,if=!fight_style.dungeonslice&(cooldown.invoke_xuen_the_white_tiger.remains<4|talent.xuens_bond&pet.xuen_the_white_tiger.active)|fight_style.dungeonslice&((fight_style.DungeonSlice&active_enemies=1&(time<10|talent.xuens_bond&talent.celestial_conduit)|!fight_style.dungeonslice|active_enemies>1)&cooldown.storm_earth_and_fire.ready&(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&(active_enemies>2|debuff.acclamation.up|!talent.ordered_elements&time<5)&(chi>2&talent.ordered_elements|chi>5|chi>3&energy<50|energy<50&active_enemies=1|prev.tiger_palm&!talent.ordered_elements&time<5)|fight_remains<30)|buff.invokers_delight.up
    local DungeonSlice = Player:IsInDungeonArea()
    if I.TreacherousTransmitter:IsEquippedAndReady() and (not DungeonSlice and (S.InvokeXuenTheWhiteTiger:CooldownRemains() < 4 or S.XuensBond:IsAvailable() and Monk.Xuen.Active) or DungeonSlice and ((DungeonSlice and EnemiesCount8y == 1 and (HL.CombatTime() < 10 or S.XuensBond:IsAvailable() and S.CelestialConduit:IsAvailable()) or not DungeonSlice or EnemiesCount8y > 1) and S.StormEarthAndFire:CooldownUp() and (Target:TimeToDie() > 14 and not DungeonSlice or Target:TimeToDie() > 22) and (EnemiesCount8y > 2 or Target:DebuffUp(S.AcclamationDebuff) or not S.OrderedElements:IsAvailable() and HL.CombatTime() < 5) and (Player:Chi() > 2 and S.OrderedElements:IsAvailable() or Player:Chi() > 5 or Player:Chi() > 3 and Player:Energy() < 50 or Player:Energy() < 50 and EnemiesCount8y == 1 or Player:PrevGCD(1, S.TigerPalm) and not S.OrderedElements:IsAvailable() and HL.CombatTime() < 5) or BossFightRemains < 30) or Player:BuffUp(S.InvokersDelightBuff)) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter trinkets 6"; end
    end
    -- use_item,name=junkmaestros_mega_magnet,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<5
    if I.JunkmaestrosMegaMagnet:IsEquippedAndReady() and Player:BuffUp(S.JunkmaestrosBuff) and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or BossFightRemains < 5) then
      if Cast(I.JunkmaestrosMegaMagnet, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "junkmaestros_mega_magnet trinkets 8"; end
    end
    -- signet_of_the_priory,if=pet.xuen_the_white_tiger.active|fight_remains<20
    if I.SignetofthePriory:IsEquippedAndReady() and (Monk.Xuen.Active or BossFightRemains < 20) then
      if Cast(I.SignetofthePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory trinkets 10"; end
    end
    -- use_item,slot=trinket1,if=pet.xuen_the_white_tiger.active
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and Trinket1:HasUseBuff() and (Monk.Xuen.Active) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_items for " .. Trinket1:Name() .. " (trinkets stat_buff trinket1)"; end
    end
    -- use_item,slot=trinket2,if=pet.xuen_the_white_tiger.active
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and Trinket2:HasUseBuff() and (Monk.Xuen.Active) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_items for " .. Trinket2:Name() .. " (trinkets stat_buff trinket2)"; end
    end
    -- use_item,slot=trinket1,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_items for " .. Trinket1:Name() .. " (trinkets dmg_buff trinket1)"; end
    end
    -- use_item,slot=trinket2,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_items for " .. Trinket2:Name() .. " (trinkets dmg_buff trinket2)"; end
    end
  end
  -- do_treacherous_transmitter_task,if=pet.xuen_the_white_tiger.active|fight_remains<20
end

local function Cooldowns()
  local DungeonSlice = Player:IsInDungeonArea()
  -- variable,name=sef_condition,value=target.time_to_die>6&(cooldown.rising_sun_kick.remains|active_enemies>2|!talent.ordered_elements)&(prev.invoke_xuen_the_white_tiger|(talent.celestial_conduit|!talent.last_emperors_capacitor)&buff.bloodlust.up&(cooldown.strike_of_the_windlord.remains<5|!talent.strike_of_the_windlord)&talent.sequenced_strikes|buff.invokers_delight.remains>15|(cooldown.strike_of_the_windlord.remains<5|!talent.strike_of_the_windlord)&cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains&cooldown.fists_of_fury.remains<5&(!talent.last_emperors_capacitor|talent.celestial_conduit)|talent.last_emperors_capacitor&buff.the_emperors_capacitor.stack>17&cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time)|fight_remains<30|buff.invokers_delight.remains>15&(cooldown.rising_sun_kick.remains|active_enemies>2|!talent.ordered_elements)|fight_style.patchwerk&buff.bloodlust.up&(cooldown.rising_sun_kick.remains|active_enemies>2|!talent.ordered_elements)&talent.celestial_conduit&time>10
  local VarSefCondition = Target:TimeToDie() > 6 and
    (S.RisingSunKick:CooldownDown() or EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable()) and
    (Player:PrevGCD(1, S.InvokeXuenTheWhiteTiger) or
    (S.CelestialConduit:IsAvailable() or not S.LastEmperorsCapacitor:IsAvailable()) and
    Player:BloodlustUp() and (S.StrikeoftheWindlord:CooldownRemains() < 5 or not S.StrikeoftheWindlord:IsAvailable()) and
    S.SequencedStrikes:IsAvailable() or Player:BuffRemains(S.InvokersDelightBuff) > 15 or
    (S.StrikeoftheWindlord:CooldownRemains() < 5 or not S.StrikeoftheWindlord:IsAvailable()) and
    S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains() and
    S.FistsofFury:CooldownRemains() < 5 and (not S.LastEmperorsCapacitor:IsAvailable() or S.CelestialConduit:IsAvailable()) or
    S.LastEmperorsCapacitor:IsAvailable() and Player:BuffStack(S.TheEmperorsCapacitorBuff) > 17 and
    S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime()) or
    BossFightRemains < 30 or Player:BuffRemains(S.InvokersDelightBuff) > 15 and
    (S.RisingSunKick:CooldownDown() or EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable()) or 
    (not Player:IsInDungeonArea() and Player:BloodlustUp() and (S.RisingSunKick:CooldownDown() or EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable()) and 
    S.CelestialConduit:IsAvailable() and HL.CombatTime() > 10)
  
  -- variable,name=xuen_dungeonslice_condition,value=active_enemies=1&(time<10|talent.xuens_bond&talent.celestial_conduit&target.time_to_die>14)|active_enemies>1&cooldown.storm_earth_and_fire.ready&target.time_to_die>14&(active_enemies>2|debuff.acclamation.up|!talent.ordered_elements&time<5)&((chi>2&!talent.ordered_elements|talent.ordered_elements|!talent.ordered_elements&energy<50)|talent.sequenced_strikes&talent.energy_burst&talent.revolving_whirl)|fight_remains<30|active_enemies>3&target.time_to_die>5|fight_style.dungeonslice&time>50&target.time_to_die>1&talent.xuens_bond
  local VarXuenDungeonsliceCondition = EnemiesCount8y == 1 and
    (HL.CombatTime() < 10 or S.XuensBond:IsAvailable() and S.CelestialConduit:IsAvailable() and Target:TimeToDie() > 14) or
    EnemiesCount8y > 1 and S.StormEarthAndFire:CooldownUp() and Target:TimeToDie() > 14 and
    (EnemiesCount8y > 2 or Target:DebuffUp(S.AcclamationDebuff) or not S.OrderedElements:IsAvailable() and HL.CombatTime() < 5) and
    ((Player:Chi() > 2 and not S.OrderedElements:IsAvailable() or S.OrderedElements:IsAvailable() or
    not S.OrderedElements:IsAvailable() and Player:Energy() < 50) or S.SequencedStrikes:IsAvailable() and
    S.EnergyBurst:IsAvailable() and S.RevolvingWhirl:IsAvailable()) or BossFightRemains < 30 or
    EnemiesCount8y > 3 and Target:TimeToDie() > 5 or DungeonSlice and HL.CombatTime() > 50 and Target:TimeToDie() > 1 and S.XuensBond:IsAvailable()
  
  -- variable,name=xuen_condition,value=(fight_style.DungeonSlice&active_enemies=1&(time<10|talent.xuens_bond&talent.celestial_conduit)|!fight_style.dungeonslice|active_enemies>1)&cooldown.storm_earth_and_fire.ready&(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&(active_enemies>2|debuff.acclamation.up|!talent.ordered_elements&time<5)&(chi>2&talent.ordered_elements|chi>5|chi>3&energy<50|energy<50&active_enemies=1|prev.tiger_palm&!talent.ordered_elements&time<5)|fight_remains<30|fight_style.dungeonroute&talent.celestial_conduit&target.time_to_die>14
  local VarXuenCondition = ((DungeonSlice and EnemiesCount8y == 1 and (HL.CombatTime() < 10 or S.XuensBond:IsAvailable() and S.CelestialConduit:IsAvailable()) or 
    not DungeonSlice or EnemiesCount8y > 1) and S.StormEarthAndFire:CooldownUp() and (Target:TimeToDie() > 14 and not Player:IsInDungeonArea() or Target:TimeToDie() > 22) and
    (EnemiesCount8y > 2 or Target:DebuffUp(S.AcclamationDebuff) or not S.OrderedElements:IsAvailable() and HL.CombatTime() < 5) and
    (Player:Chi() > 2 and S.OrderedElements:IsAvailable() or Player:Chi() > 5 or Player:Chi() > 3 and Player:Energy() < 50 or
    Player:Energy() < 50 and EnemiesCount8y == 1 or Player:PrevGCD(1, S.TigerPalm) and not S.OrderedElements:IsAvailable() and
    HL.CombatTime() < 5)) or BossFightRemains < 30 or Player:IsInDungeonArea() and S.CelestialConduit:IsAvailable() and Target:TimeToDie() > 14
  
  -- variable,name=xuen_dungeonroute_condition,value=cooldown.storm_earth_and_fire.ready&(active_enemies>1&cooldown.storm_earth_and_fire.ready&target.time_to_die>22&(active_enemies>2|debuff.acclamation.up|!talent.ordered_elements&time<5)&((chi>2&!talent.ordered_elements|talent.ordered_elements|!talent.ordered_elements&energy<50)|talent.sequenced_strikes&talent.energy_burst&talent.revolving_whirl)|fight_remains<30|active_enemies>3&target.time_to_die>15|time>50&(target.time_to_die>10&talent.xuens_bond|target.time_to_die>20))|buff.storm_earth_and_fire.remains>5
  local VarXuenDungeonrouteCondition = S.StormEarthAndFire:CooldownUp() and
    (EnemiesCount8y > 1 and S.StormEarthAndFire:CooldownUp() and Target:TimeToDie() > 22 and
    (EnemiesCount8y > 2 or Target:DebuffUp(S.AcclamationDebuff) or not S.OrderedElements:IsAvailable() and HL.CombatTime() < 5) and
    ((Player:Chi() > 2 and not S.OrderedElements:IsAvailable() or S.OrderedElements:IsAvailable() or
    not S.OrderedElements:IsAvailable() and Player:Energy() < 50) or S.SequencedStrikes:IsAvailable() and
    S.EnergyBurst:IsAvailable() and S.RevolvingWhirl:IsAvailable()) or BossFightRemains < 30 or
    EnemiesCount8y > 3 and Target:TimeToDie() > 15 or HL.CombatTime() > 50 and
    (Target:TimeToDie() > 10 and S.XuensBond:IsAvailable() or Target:TimeToDie() > 20)) or
    Player:BuffRemains(S.StormEarthAndFireBuff) > 5
  
  -- variable,name=sef_dungeonroute_condition,value=time<50&target.time_to_die>10&(buff.bloodlust.up|active_enemies>2|cooldown.strike_of_the_windlord.remains<2|talent.last_emperors_capacitor&buff.the_emperors_capacitor.stack>17)|target.time_to_die>10&(cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains|cooldown.invoke_xuen_the_white_tiger.remains<30&(cooldown.storm_earth_and_fire.full_recharge_time<30|cooldown.storm_earth_and_fire.full_recharge_time<40&talent.flurry_strikes))&(talent.sequenced_strikes&talent.energy_burst&talent.revolving_whirl|talent.flurry_strikes|chi>3|energy<50)&(active_enemies>2|!talent.ordered_elements|cooldown.rising_sun_kick.remains)&!talent.flurry_strikes|target.time_to_die>10&talent.flurry_strikes&(active_enemies>2|!talent.ordered_elements|cooldown.rising_sun_kick.remains)&(talent.last_emperors_capacitor&buff.the_emperors_capacitor.stack>17&cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains&cooldown.invoke_xuen_the_white_tiger.remains>15|!talent.last_emperors_capacitor&cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains&cooldown.invoke_xuen_the_white_tiger.remains>15)
  local VarSefDungeonrouteCondition = HL.CombatTime() < 50 and Target:TimeToDie() > 10 and
    (Player:BloodlustUp() or EnemiesCount8y > 2 or S.StrikeoftheWindlord:CooldownRemains() < 2 or
    S.LastEmperorsCapacitor:IsAvailable() and Player:BuffStack(S.TheEmperorsCapacitorBuff) > 17) or
    Target:TimeToDie() > 10 and (S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains() or
    S.InvokeXuenTheWhiteTiger:CooldownRemains() < 30 and (S.StormEarthAndFire:FullRechargeTime() < 30 or
    S.StormEarthAndFire:FullRechargeTime() < 40 and S.FlurryStrikes:IsAvailable())) and
    (S.SequencedStrikes:IsAvailable() and S.EnergyBurst:IsAvailable() and
    S.RevolvingWhirl:IsAvailable() or S.FlurryStrikes:IsAvailable() or Player:Chi() > 3 or Player:Energy() < 50) and
    (EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable() or S.RisingSunKick:CooldownDown()) and
    not S.FlurryStrikes:IsAvailable() or Target:TimeToDie() > 10 and S.FlurryStrikes:IsAvailable() and
    (EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable() or S.RisingSunKick:CooldownDown()) and
    (S.LastEmperorsCapacitor:IsAvailable() and Player:BuffStack(S.TheEmperorsCapacitorBuff) > 17 and
    S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains() and
    S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or not S.LastEmperorsCapacitor:IsAvailable() and
    S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15)
  -- invoke_external_buff,name=power_infusion,if=pet.xuen_the_white_tiger.active&(!buff.bloodlust.up|buff.bloodlust.up&cooldown.strike_of_the_windlord.remains)
  -- Not implemented - external buff coordination
  -- storm_earth_and_fire,target_if=max:target.time_to_die,if=fight_style.dungeonroute&buff.invokers_delight.remains>15&(active_enemies>2|!talent.ordered_elements|cooldown.rising_sun_kick.remains)
  if S.StormEarthAndFire:IsCastable() and (Player:IsInDungeonArea() and Player:BuffRemains(S.InvokersDelightBuff) > 15 and (EnemiesCount8y > 2 or not S.OrderedElements:IsAvailable() or S.RisingSunKick:CooldownDown())) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cooldowns dungeonroute 2"; end
  end
  -- tiger_palm,if=(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&!cooldown.invoke_xuen_the_white_tiger.remains&(chi<5&!talent.ordered_elements|chi<3)&(combo_strike|!talent.hit_combo)
  if S.TigerPalm:IsReady() and ((Target:TimeToDie() > 14 and not Player:IsInDungeonArea() or Target:TimeToDie() > 22) and S.InvokeXuenTheWhiteTiger:CooldownUp() and (Player:Chi() < 5 and not S.OrderedElements:IsAvailable() or Player:Chi() < 3) and (ComboStrike(S.TigerPalm) or not S.HitCombo:IsAvailable())) then
     if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm cooldowns 6"; end
  end
  -- invoke_xuen_the_white_tiger,target_if=max:target.time_to_die,if=variable.xuen_condition&!fight_style.dungeonslice&!fight_style.dungeonroute|variable.xuen_dungeonslice_condition&fight_style.Dungeonslice|variable.xuen_dungeonroute_condition&fight_style.dungeonroute
  if S.InvokeXuenTheWhiteTiger:IsCastable() and
    ((VarXuenCondition and not DungeonSlice and not Player:IsInDungeonArea()) or
     (VarXuenDungeonsliceCondition and DungeonSlice) or
     (VarXuenDungeonrouteCondition and Player:IsInDungeonArea())) then
    if Everyone.CastTargetIf(S.InvokeXuenTheWhiteTiger, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(40), Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger) then return "invoke_xuen_the_white_tiger cooldowns 8"; end
  end
  -- storm_earth_and_fire,target_if=max:target.time_to_die,if=variable.sef_condition&!fight_style.dungeonroute|variable.sef_dungeonroute_condition&fight_style.dungeonroute
  if S.StormEarthAndFire:IsCastable() and ((VarSefCondition and not Player:IsInDungeonArea()) or (VarSefDungeonrouteCondition and Player:IsInDungeonArea())) then
    if Everyone.CastTargetIf(S.StormEarthAndFire, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, nil, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cooldowns 10"; end
  end
  -- touch_of_karma
  if S.TouchofKarma:IsCastable() and not Settings.Windwalker.IgnoreToK then
    if Cast(S.TouchofKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cooldowns 12"; end
  end
  -- ancestral_call,if=buff.invoke_xuen_the_white_tiger.remains>15|!talent.invoke_xuen_the_white_tiger&(!talent.storm_earth_and_fire&(cooldown.strike_of_the_windlord.ready|!talent.strike_of_the_windlord&cooldown.fists_of_fury.ready)|buff.storm_earth_and_fire.remains>10)|fight_remains<20
  if S.AncestralCall:IsCastable() and ((Monk.Xuen.Active and Monk.Xuen.SummonTime + 15 > GetTime()) or not S.InvokeXuenTheWhiteTiger:IsAvailable() and (not S.StormEarthAndFire:IsAvailable() and (S.StrikeoftheWindlord:CooldownUp() or not S.StrikeoftheWindlord:IsAvailable() and S.FistsofFury:CooldownUp()) or Player:BuffRemains(S.StormEarthAndFireBuff) > 10) or BossFightRemains < 20) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cooldowns 14"; end
  end
  -- blood_fury,if=buff.invoke_xuen_the_white_tiger.remains>15|!talent.invoke_xuen_the_white_tiger&(!talent.storm_earth_and_fire&(cooldown.strike_of_the_windlord.ready|!talent.strike_of_the_windlord&cooldown.fists_of_fury.ready)|buff.storm_earth_and_fire.remains>10)|fight_remains<20
  if S.BloodFury:IsCastable() and ((Monk.Xuen.Active and Monk.Xuen.SummonTime + 15 > GetTime()) or not S.InvokeXuenTheWhiteTiger:IsAvailable() and (not S.StormEarthAndFire:IsAvailable() and (S.StrikeoftheWindlord:CooldownUp() or not S.StrikeoftheWindlord:IsAvailable() and S.FistsofFury:CooldownUp()) or Player:BuffRemains(S.StormEarthAndFireBuff) > 10) or BossFightRemains < 20) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cooldowns 16"; end
  end
  -- fireblood,if=buff.invoke_xuen_the_white_tiger.remains>15|!talent.invoke_xuen_the_white_tiger&(!talent.storm_earth_and_fire&(cooldown.strike_of_the_windlord.ready|!talent.strike_of_the_windlord&cooldown.fists_of_fury.ready)|buff.storm_earth_and_fire.remains>10)|fight_remains<20
  if S.Fireblood:IsCastable() and ((Monk.Xuen.Active and Monk.Xuen.SummonTime + 15 > GetTime()) or not S.InvokeXuenTheWhiteTiger:IsAvailable() and (not S.StormEarthAndFire:IsAvailable() and (S.StrikeoftheWindlord:CooldownUp() or not S.StrikeoftheWindlord:IsAvailable() and S.FistsofFury:CooldownUp()) or Player:BuffRemains(S.StormEarthAndFireBuff) > 10) or BossFightRemains < 20) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 18"; end
  end
  -- berserking,if=buff.invoke_xuen_the_white_tiger.remains>15|!talent.invoke_xuen_the_white_tiger&(!talent.storm_earth_and_fire&(cooldown.strike_of_the_windlord.ready|!talent.strike_of_the_windlord&cooldown.fists_of_fury.ready)|buff.storm_earth_and_fire.remains>10)|fight_remains<20
  if S.Berserking:IsCastable() and ((Monk.Xuen.Active and Monk.Xuen.SummonTime + 15 > GetTime()) or not S.InvokeXuenTheWhiteTiger:IsAvailable() and (not S.StormEarthAndFire:IsAvailable() and (S.StrikeoftheWindlord:CooldownUp() or not S.StrikeoftheWindlord:IsAvailable() and S.FistsofFury:CooldownUp()) or Player:BuffRemains(S.StormEarthAndFireBuff) > 10) or BossFightRemains < 20) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cooldowns 20"; end
  end
  if Player:BuffDown(S.StormEarthAndFireBuff) then
    -- bag_of_tricks,if=buff.storm_earth_and_fire.down
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cooldowns 22"; end
    end
    -- lights_judgment,if=buff.storm_earth_and_fire.down
    if S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "lights_judgment cooldowns 24"; end
    end
    -- haymaker,if=buff.storm_earth_and_fire.down
    if S.Haymaker:IsCastable() then
      if Cast(S.Haymaker, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "haymaker cooldowns 26"; end
    end
    -- rocket_barrage,if=buff.storm_earth_and_fire.down
    if S.RocketBarrage:IsCastable() then
      if Cast(S.RocketBarrage, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "rocket_barrage cooldowns 28"; end
    end
    -- azerite_surge,if=buff.storm_earth_and_fire.down
    if S.AzeriteSurge:IsCastable() then
      if Cast(S.AzeriteSurge, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "azerite_surge cooldowns 30"; end
    end
    -- arcane_pulse,if=buff.storm_earth_and_fire.down
    if S.ArcanePulse:IsCastable() then
      if Cast(S.ArcanePulse, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_pulse cooldowns 32"; end
    end
  end
end

local function AoEOpener()
  -- slicing_winds
  if S.SlicingWinds:IsReady() then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds aoe_opener 2"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi<6
  if S.TigerPalm:IsReady() and (Player:Chi() < 6) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm aoe_opener 4"; end
  end
end

local function NormalOpener()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi<6&combo_strike
  if S.TigerPalm:IsReady() and (Player:Chi() < 6 and ComboStrike(S.TigerPalm)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm normal_opener 2"; end
  end
  -- rising_sun_kick,target_if=max:debuff.acclamation.stack,if=talent.ordered_elements
  if S.RisingSunKick:IsReady() and (S.OrderedElements:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick normal_opener 4"; end
  end
end

local function DefaultAoE()
  -- tiger_palm,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up)&!buff.ordered_elements.up|(talent.energy_burst&!buff.bok_proc.up)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|cooldown.strike_of_the_windlord.remains)&cooldown.celestial_conduit.remains<2&buff.ordered_elements.up&chi<5&combo_strike
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff)) and Player:BuffDown(S.OrderedElementsBuff) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff)) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or S.StrikeoftheWindlord:CooldownDown()) and S.CelestialConduit:CooldownRemains() < 2 and Player:BuffUp(S.OrderedElementsBuff) and Player:Chi() < 5 and ComboStrike(S.TigerPalm)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 2"; end
  end
  -- touch_of_death,if=!buff.heart_of_the_jade_serpent_cdr.up&!buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.TouchofDeath:CooldownUp() and (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    local ToDTar = ToDTarget()
    if ToDTar then
      if ToDTar:GUID() == Target:GUID() then
        if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death default_aoe 4"; end
      else
        if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death default_aoe 6"; end
      end
    end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=buff.dance_of_chiji.stack=2&combo_strike
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 8"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.chi_energy.stack>29&cooldown.fists_of_fury.remains<5
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.ChiEnergyBuff) > 29 and S.FistsofFury:CooldownRemains() < 5) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 10"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=buff.heart_of_the_jade_serpent_cdr.up&buff.dance_of_chiji.stack<2
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=buff.dance_of_chiji.stack<2
  if S.WhirlingDragonPunch:IsReady() and ((Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffStack(S.DanceofChijiBuff) < 2) or (Player:BuffStack(S.DanceofChijiBuff) < 2)) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 11"; end
  end
  -- slicing_winds,if=buff.heart_of_the_jade_serpent_cdr.up|buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.SlicingWinds:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_aoe 12"; end
  end
  -- celestial_conduit,if=buff.storm_earth_and_fire.up&cooldown.strike_of_the_windlord.remains&(!buff.heart_of_the_jade_serpent_cdr.up|debuff.gale_force.remains<5)&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15|fight_style.dungeonroute&buff.invokers_delight.up&cooldown.strike_of_the_windlord.remains&buff.storm_earth_and_fire.remains<8
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and S.StrikeoftheWindlord:CooldownDown() and (not Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Target:DebuffRemains(S.GaleForceDebuff) < 5) and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15 or Player:IsInDungeonArea() and Player:BuffUp(S.InvokersDelightBuff) and S.StrikeoftheWindlord:CooldownDown() and Player:BuffRemains(S.StormEarthAndFireBuff) < 8) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_aoe 13"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=cooldown.whirling_dragon_punch.remains<2&cooldown.fists_of_fury.remains>1&buff.dance_of_chiji.stack<2|!buff.storm_earth_and_fire.up&buff.pressure_point.up
  if S.RisingSunKick:IsReady() and ((S.WhirlingDragonPunch:CooldownRemains() < 2 and S.FistsofFury:CooldownRemains() > 1 and Player:BuffStack(S.DanceofChijiBuff) < 2) or (Player:BuffDown(S.StormEarthAndFireBuff) and Player:BuffUp(S.PressurePointBuff))) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 14"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=!talent.revolving_whirl|talent.revolving_whirl&buff.dance_of_chiji.stack<2&active_enemies>2
  if S.WhirlingDragonPunch:IsReady() and (not S.RevolvingWhirl:IsAvailable() or (S.RevolvingWhirl:IsAvailable() and Player:BuffStack(S.DanceofChijiBuff) < 2 and EnemiesCount8y > 2)) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 16"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.bok_proc.up&chi<2&talent.energy_burst&energy<55
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutKickBuff) and Player:Chi() < 2 and S.EnergyBurst:IsAvailable() and Player:Energy() < 55) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 18"; end
  end
  -- strike_of_the_windlord,target_if=max:target.time_to_die,if=(time>5|buff.invokers_delight.up&buff.storm_earth_and_fire.up)&(cooldown.invoke_xuen_the_white_tiger.remains>15|talent.flurry_strikes)
  if S.StrikeoftheWindlord:IsReady() and ((HL.CombatTime() > 5 or Player:BuffUp(S.InvokersDelightBuff) and Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or S.FlurryStrikes:IsAvailable())) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.StrikeoftheWindlord)) then return "strike_of_the_windlord default_aoe 20"; end
  end
  -- slicing_winds
  if S.SlicingWinds:IsReady() then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_aoe 22"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=8&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 8 and S.ShadowboxingTreads:IsAvailable()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 24"; end
  end
  -- crackling_jade_lightning,target_if=max:target.time_to_die,if=buff.the_emperors_capacitor.stack>19&combo_strike&talent.power_of_the_thunder_king&cooldown.invoke_xuen_the_white_tiger.remains>10
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and ComboStrike(S.CracklingJadeLightning) and S.PoweroftheThunderKing:IsAvailable() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(S.CracklingJadeLightning, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_aoe 26"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die,if=(talent.flurry_strikes|talent.xuens_battlegear&(cooldown.invoke_xuen_the_white_tiger.remains>5&fight_style.patchwerk|cooldown.invoke_xuen_the_white_tiger.remains>9)|cooldown.invoke_xuen_the_white_tiger.remains>10)
  if S.FistsofFury:IsReady() and (S.FlurryStrikes:IsAvailable() or S.XuensBattlegear:IsAvailable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 5 and not Player:IsInDungeonArea() or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 9) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_aoe 28"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.wisdom_of_the_wall_flurry.up&chi<6
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.WisdomoftheWallFlurryBuff) and Player:Chi() < 6) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&chi>5
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:Chi() > 5) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 32"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&buff.chi_energy.stack>29&cooldown.fists_of_fury.remains<5
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffStack(S.ChiEnergyBuff) > 29 and S.FistsofFury:CooldownRemains() < 5) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 34"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.pressure_point.up&cooldown.fists_of_fury.remains>2
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and S.FistsofFury:CooldownRemains() > 2) then
    if MotCCastSwitcher(S.RisingSunKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "rising_sun_kick default_aoe 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.shadowboxing_treads&talent.courageous_impulse&combo_strike&buff.bok_proc.stack=2
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and S.CourageousImpulse:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffStack(S.BlackoutKickBuff) == 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 38"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.crane_vortex&active_enemies>2
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 42"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.ordered_elements.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.OrderedElementsBuff)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 44"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.deficit>=2&(!buff.ordered_elements.up|energy.time_to_max<=gcd.max*3)
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDown(S.OrderedElementsBuff) or Player:EnergyTimeToMax() <= Player:GCD() * 3)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 46"; end
  end
  -- jadefire_stomp,target_if=max:target.time_to_die,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsCastable() and (S.SingularlyFocusedJade:IsAvailable() or S.JadefireHarmony:IsAvailable()) then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 48"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&!buff.ordered_elements.up&talent.crane_vortex&active_enemies>2&chi>4
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2 and Player:Chi() > 4) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 50"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(buff.teachings_of_the_monastery.stack>3|buff.ordered_elements.up)&(talent.shadowboxing_treads|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 or Player:BuffUp(S.OrderedElementsBuff)) and (S.ShadowboxingTreads:IsAvailable() or Player:BuffUp(S.BlackoutKickBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 52"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&!cooldown.fists_of_fury.remains&chi<3
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownUp() and Player:Chi() < 3) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.shadowboxing_treads&talent.courageous_impulse&combo_strike&buff.bok_proc.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and S.CourageousImpulse:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutKickBuff)) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 56"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&(chi>3|energy>55)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (Player:Chi() > 3 or Player:Energy() > 55)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 58"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or (Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable())) and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 60"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 62"; end
  end
  -- jadefire_stomp,target_if=max:debuff.acclamation.stack
  if S.JadefireStomp:IsCastable() then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 64"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 66"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 68"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 70"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.hit_combo
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 72"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 74"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 76"; end
  end
  -- Manually added: tiger_palm,if=chi=0 (avoids a potential profile stall)
  if S.TigerPalm:IsReady() and (Player:Chi() == 0) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 78"; end
  end
end

local function DefaultCleave()
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=buff.dance_of_chiji.stack=2&combo_strike
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 2"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=buff.pressure_point.up&active_enemies<4&cooldown.fists_of_fury.remains>4
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and EnemiesCount8y < 4 and S.FistsofFury:CooldownRemains() > 4) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 4"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=cooldown.whirling_dragon_punch.remains<2&cooldown.fists_of_fury.remains>1&buff.dance_of_chiji.stack<2
  if S.RisingSunKick:IsReady() and (S.WhirlingDragonPunch:CooldownRemains() < 2 and S.FistsofFury:CooldownRemains() > 1 and Player:BuffStack(S.DanceofChijiBuff) < 2) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.stack=2&active_enemies>3
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.DanceofChijiBuff) == 2 and EnemiesCount8y > 3) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 8"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up|(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|cooldown.strike_of_the_windlord.remains)&cooldown.celestial_conduit.remains<2&buff.ordered_elements.up&chi<5&combo_strike|(!buff.heart_of_the_jade_serpent_cdr.up|!buff.heart_of_the_jade_serpent_cdr_celestial.up)&combo_strike&chi.deficit>=2&!buff.ordered_elements.up
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or S.StrikeoftheWindlord:CooldownDown()) and S.CelestialConduit:CooldownRemains() < 2 and Player:BuffUp(S.OrderedElementsBuff) and Player:Chi() < 5 and ComboStrike(S.TigerPalm) or (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.OrderedElementsBuff)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_cleave 10"; end
  end
  -- touch_of_death,if=!buff.heart_of_the_jade_serpent_cdr.up&!buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.TouchofDeath:CooldownUp() and (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    local ToDTar = ToDTarget()
    if ToDTar then
      if ToDTar:GUID() == Target:GUID() then
        if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death default_cleave 12"; end
      else
        if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death default_cleave 14"; end
      end
    end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=buff.heart_of_the_jade_serpent_cdr.up&buff.dance_of_chiji.stack<2
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=buff.dance_of_chiji.stack<2
  if S.WhirlingDragonPunch:IsReady() and ((Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffStack(S.DanceofChijiBuff) < 2) or (Player:BuffStack(S.DanceofChijiBuff) < 2)) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 11"; end
  end
  -- slicing_winds,if=buff.heart_of_the_jade_serpent_cdr.up|buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.SlicingWinds:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_aoe 12"; end
  end
  -- celestial_conduit,if=buff.storm_earth_and_fire.up&cooldown.strike_of_the_windlord.remains&(!buff.heart_of_the_jade_serpent_cdr.up|debuff.gale_force.remains<5)&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15|fight_style.dungeonroute&buff.invokers_delight.up&cooldown.strike_of_the_windlord.remains&buff.storm_earth_and_fire.remains<8
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and S.StrikeoftheWindlord:CooldownDown() and (not Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Target:DebuffRemains(S.GaleForceDebuff) < 5) and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15 or Player:IsInDungeonArea() and Player:BuffUp(S.InvokersDelightBuff) and S.StrikeoftheWindlord:CooldownDown() and Player:BuffRemains(S.StormEarthAndFireBuff) < 8) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_aoe 13"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=cooldown.whirling_dragon_punch.remains<2&cooldown.fists_of_fury.remains>1&buff.dance_of_chiji.stack<2|!buff.storm_earth_and_fire.up&buff.pressure_point.up
  if S.RisingSunKick:IsReady() and ((S.WhirlingDragonPunch:CooldownRemains() < 2 and S.FistsofFury:CooldownRemains() > 1 and Player:BuffStack(S.DanceofChijiBuff) < 2) or (Player:BuffDown(S.StormEarthAndFireBuff) and Player:BuffUp(S.PressurePointBuff))) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 14"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=!talent.revolving_whirl|talent.revolving_whirl&buff.dance_of_chiji.stack<2&active_enemies>2
  if S.WhirlingDragonPunch:IsReady() and (not S.RevolvingWhirl:IsAvailable() or (S.RevolvingWhirl:IsAvailable() and Player:BuffStack(S.DanceofChijiBuff) < 2 and EnemiesCount8y > 2)) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 16"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.bok_proc.up&chi<2&talent.energy_burst&energy<55
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutKickBuff) and Player:Chi() < 2 and S.EnergyBurst:IsAvailable() and Player:Energy() < 55) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 18"; end
  end
  -- strike_of_the_windlord,target_if=max:target.time_to_die,if=(time>5|buff.invokers_delight.up&buff.storm_earth_and_fire.up)&(cooldown.invoke_xuen_the_white_tiger.remains>15|talent.flurry_strikes)
  if S.StrikeoftheWindlord:IsReady() and ((HL.CombatTime() > 5 or Player:BuffUp(S.InvokersDelightBuff) and Player:BuffUp(S.StormEarthAndFireBuff)) and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or S.FlurryStrikes:IsAvailable())) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.StrikeoftheWindlord)) then return "strike_of_the_windlord default_aoe 20"; end
  end
  -- slicing_winds
  if S.SlicingWinds:IsReady() then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_aoe 22"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=8&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 8 and S.ShadowboxingTreads:IsAvailable()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 24"; end
  end
  -- crackling_jade_lightning,target_if=max:target.time_to_die,if=buff.the_emperors_capacitor.stack>19&combo_strike&talent.power_of_the_thunder_king&cooldown.invoke_xuen_the_white_tiger.remains>10
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and ComboStrike(S.CracklingJadeLightning) and S.PoweroftheThunderKing:IsAvailable() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(S.CracklingJadeLightning, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_aoe 26"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die,if=(talent.flurry_strikes|talent.xuens_battlegear&(cooldown.invoke_xuen_the_white_tiger.remains>5&fight_style.patchwerk|cooldown.invoke_xuen_the_white_tiger.remains>9)|cooldown.invoke_xuen_the_white_tiger.remains>10)
  if S.FistsofFury:IsReady() and (S.FlurryStrikes:IsAvailable() or S.XuensBattlegear:IsAvailable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 5 and not Player:IsInDungeonArea() or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 9) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_aoe 28"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.wisdom_of_the_wall_flurry.up&chi<6
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.WisdomoftheWallFlurryBuff) and Player:Chi() < 6) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&chi>5
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:Chi() > 5) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 32"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&buff.chi_energy.stack>29&cooldown.fists_of_fury.remains<5
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffStack(S.ChiEnergyBuff) > 29 and S.FistsofFury:CooldownRemains() < 5) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 34"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.pressure_point.up&cooldown.fists_of_fury.remains>2
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and S.FistsofFury:CooldownRemains() > 2) then
    if MotCCastSwitcher(S.RisingSunKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "rising_sun_kick default_aoe 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.shadowboxing_treads&talent.courageous_impulse&combo_strike&buff.bok_proc.stack=2
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and S.CourageousImpulse:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffStack(S.BlackoutKickBuff) == 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 38"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.crane_vortex&active_enemies>2
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 42"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.ordered_elements.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.OrderedElementsBuff)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 44"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.deficit>=2&(!buff.ordered_elements.up|energy.time_to_max<=gcd.max*3)
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDown(S.OrderedElementsBuff) or Player:EnergyTimeToMax() <= Player:GCD() * 3)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 46"; end
  end
  -- jadefire_stomp,target_if=max:target.time_to_die,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsCastable() and (S.SingularlyFocusedJade:IsAvailable() or S.JadefireHarmony:IsAvailable()) then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 48"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&!buff.ordered_elements.up&talent.crane_vortex&active_enemies>2&chi>4
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2 and Player:Chi() > 4) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 50"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(buff.teachings_of_the_monastery.stack>3|buff.ordered_elements.up)&(talent.shadowboxing_treads|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 or Player:BuffUp(S.OrderedElementsBuff)) and (S.ShadowboxingTreads:IsAvailable() or Player:BuffUp(S.BlackoutKickBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 52"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&!cooldown.fists_of_fury.remains&chi<3
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownUp() and Player:Chi() < 3) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.shadowboxing_treads&talent.courageous_impulse&combo_strike&buff.bok_proc.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and S.CourageousImpulse:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutKickBuff)) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 56"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&(chi>3|energy>55)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (Player:Chi() > 3 or Player:Energy() > 55)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 58"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or (Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable())) and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 60"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 62"; end
  end
  -- jadefire_stomp,target_if=max:debuff.acclamation.stack
  if S.JadefireStomp:IsCastable() then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 64"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 66"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 68"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 70"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.hit_combo
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 72"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_aoe 74"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_aoe 76"; end
  end
  -- Manually added: tiger_palm,if=chi=0 (avoids a potential profile stall)
  if S.TigerPalm:IsReady() and (Player:Chi() == 0) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 78"; end
  end
end

local function DefaultST()
  -- fists_of_fury,if=buff.heart_of_the_jade_serpent_cdr_celestial.up|buff.heart_of_the_jade_serpent_cdr.up
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff)) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 2"; end
  end
  -- rising_sun_kick,if=buff.pressure_point.up&!buff.heart_of_the_jade_serpent_cdr.up&buff.heart_of_the_jade_serpent_cdr_celestial.up|buff.invokers_delight.up|buff.bloodlust.up|buff.pressure_point.up&cooldown.fists_of_fury.remains|buff.power_infusion.up
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff) or Player:BuffUp(S.InvokersDelightBuff) or Player:BloodlustUp() or Player:BuffUp(S.PressurePointBuff) and S.FistsofFury:CooldownDown() or Player:PowerInfusionUp()) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 4"; end
  end
  -- whirling_dragon_punch,if=!buff.heart_of_the_jade_serpent_cdr_celestial.up&!buff.dance_of_chiji.stack=2
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and Player:BuffStack(S.DanceofChijiBuff) ~= 2) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 6"; end
  end
  -- slicing_winds,if=buff.heart_of_the_jade_serpent_cdr.up|buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.SlicingWinds:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_st 8"; end
  end
  -- celestial_conduit,if=buff.storm_earth_and_fire.up&(!buff.heart_of_the_jade_serpent_cdr.up|debuff.gale_force.remains<5)&cooldown.strike_of_the_windlord.remains&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15|fight_style.dungeonroute&buff.invokers_delight.up&cooldown.strike_of_the_windlord.remains&buff.storm_earth_and_fire.remains<8|fight_remains<10
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) or Target:DebuffRemains(S.GaleForceDebuff) < 5) and S.StrikeoftheWindlord:CooldownDown() and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15 or Player:IsInDungeonArea() and Player:BuffUp(S.InvokersDelightBuff) and S.StrikeoftheWindlord:CooldownDown() and Player:BuffRemains(S.StormEarthAndFireBuff) < 8 or BossFightRemains < 10) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_st 10"; end
  end
  -- spinning_crane_kick,if=buff.dance_of_chiji.stack=2&combo_strike
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 12"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up|(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|!buff.heart_of_the_jade_serpent_cdr_celestial.up)&combo_strike&chi.deficit>=2&!buff.ordered_elements.up
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.OrderedElementsBuff)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 14"; end
  end
  -- touch_of_death
  if S.TouchofDeath:CooldownUp() then
    local ToDTar = nil
    if AoEON() then
      ToDTar = ToDTarget()
    else
      if S.TouchofDeath:IsReady() then
        ToDTar = Target
      end
    end
    if ToDTar then
      if ToDTar:GUID() == Target:GUID() then
        if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death default_st 16"; end
      else
        if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death default_st 18"; end
      end
    end
  end
  -- rising_sun_kick,if=!pet.xuen_the_white_tiger.active&prev.tiger_palm&time<5|buff.storm_earth_and_fire.up&talent.ordered_elements
  if S.RisingSunKick:IsReady() and (not Monk.Xuen.Active and Player:PrevGCD(1, S.TigerPalm) and HL.CombatTime() < 5 or Player:BuffUp(S.StormEarthAndFireBuff) and S.OrderedElements:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 20"; end
  end
  -- strike_of_the_windlord,if=talent.celestial_conduit&!buff.invokers_delight.up&!buff.heart_of_the_jade_serpent_cdr_celestial.up&cooldown.fists_of_fury.remains<5&cooldown.invoke_xuen_the_white_tiger.remains>15|fight_remains<12
  if S.StrikeoftheWindlord:IsReady() and (S.CelestialConduit:IsAvailable() and Player:BuffDown(S.InvokersDelightBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and S.FistsofFury:CooldownRemains() < 5 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or BossFightRemains < 12) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsSpellInRange(S.StrikeoftheWindlord)) then return "strike_of_the_windlord default_st 22"; end
  end
  -- strike_of_the_windlord,if=talent.gale_force&buff.invokers_delight.up&(buff.bloodlust.up|!buff.heart_of_the_jade_serpent_cdr_celestial.up)
  if S.StrikeoftheWindlord:IsReady() and (S.GaleForce:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff) and (Player:BloodlustUp() or Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff))) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsSpellInRange(S.StrikeoftheWindlord)) then return "strike_of_the_windlord default_st 24"; end
  end
  -- strike_of_the_windlord,if=time>5&talent.flurry_strikes
  if S.StrikeoftheWindlord:IsReady() and (HL.CombatTime() > 5 and S.FlurryStrikes:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsSpellInRange(S.StrikeoftheWindlord)) then return "strike_of_the_windlord default_st 26"; end
  end
  -- fists_of_fury,if=buff.power_infusion.up&buff.bloodlust.up&time>5
  if S.FistsofFury:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp() and HL.CombatTime() > 5) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 28"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack>3&buff.ordered_elements.up&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 and Player:BuffUp(S.OrderedElementsBuff) and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 30"; end
  end
  -- tiger_palm,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.power_infusion.up&buff.bloodlust.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 32"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack>4&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 4 and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 34"; end
  end
  -- whirling_dragon_punch,if=!buff.heart_of_the_jade_serpent_cdr_celestial.up&!buff.dance_of_chiji.stack=2|buff.ordered_elements.up|talent.knowledge_of_the_broken_temple
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and Player:BuffStack(S.DanceofChijiBuff) ~= 2 or Player:BuffUp(S.OrderedElementsBuff) or S.KnowledgeoftheBrokenTemple:IsAvailable()) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 36"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&!buff.heart_of_the_jade_serpent_cdr.up&!buff.heart_of_the_jade_serpent_cdr_celestial.up&combo_strike&(!fight_style.dungeonslice|target.time_to_die>20)&cooldown.invoke_xuen_the_white_tiger.remains>10|buff.the_emperors_capacitor.stack>15&!buff.heart_of_the_jade_serpent_cdr.up&!buff.heart_of_the_jade_serpent_cdr_celestial.up&combo_strike&(!fight_style.dungeonslice|target.time_to_die>20)&cooldown.invoke_xuen_the_white_tiger.remains<10&cooldown.invoke_xuen_the_white_tiger.remains>2
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and ComboStrike(S.CracklingJadeLightning) and (not Player:IsInDungeonArea() or Target:TimeToDie() > 20) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or Player:BuffStack(S.TheEmperorsCapacitorBuff) > 15 and Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and ComboStrike(S.CracklingJadeLightning) and (not Player:IsInDungeonArea() or Target:TimeToDie() > 20) and S.InvokeXuenTheWhiteTiger:CooldownRemains() < 10 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 2) then
    if Cast(S.CracklingJadeLightning, Settings.Windwalker.GCDasOffGCD.CracklingJadeLightning, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_st 38"; end
  end
  -- slicing_winds,if=target.time_to_die>10
  if S.SlicingWinds:IsReady() and (Target:TimeToDie() > 10) then
    if Cast(S.SlicingWinds, nil, nil, not Target:IsInRange(40)) then return "slicing_winds default_st 40"; end
  end
  -- fists_of_fury,if=(talent.xuens_battlegear|!talent.xuens_battlegear&(cooldown.strike_of_the_windlord.remains>1|buff.heart_of_the_jade_serpent_cdr.up|buff.heart_of_the_jade_serpent_cdr_celestial.up))&(talent.xuens_battlegear&cooldown.invoke_xuen_the_white_tiger.remains>5|cooldown.invoke_xuen_the_white_tiger.remains>10)&(!buff.invokers_delight.up|buff.invokers_delight.up&cooldown.strike_of_the_windlord.remains>4&cooldown.celestial_conduit.remains)|fight_remains<5|talent.flurry_strikes
  if S.FistsofFury:IsReady() and ((S.XuensBattlegear:IsAvailable() or not S.XuensBattlegear:IsAvailable() and (S.StrikeoftheWindlord:CooldownRemains() > 1 or Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff))) and (S.XuensBattlegear:IsAvailable() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 5 or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10) and (Player:BuffDown(S.InvokersDelightBuff) or Player:BuffUp(S.InvokersDelightBuff) and S.StrikeoftheWindlord:CooldownRemains() > 4 and S.CelestialConduit:CooldownDown()) or BossFightRemains < 5 or S.FlurryStrikes:IsAvailable()) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 42"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=chi>4|chi>2&energy>50|cooldown.fists_of_fury.remains>2
  if S.RisingSunKick:IsReady() and (Player:Chi() > 4 or Player:Chi() > 2 and Player:Energy() > 50 or S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 44"; end
  end
  -- blackout_kick,if=combo_strike&talent.energy_burst&buff.bok_proc.up&chi<5&(buff.heart_of_the_jade_serpent_cdr.up|buff.heart_of_the_jade_serpent_cdr_celestial.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.EnergyBurst:IsAvailable() and Player:BuffUp(S.BlackoutKickBuff) and Player:Chi() < 5 and (Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 46"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.bloodlust.up&buff.heart_of_the_jade_serpent_cdr.up&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BloodlustUp() and Player:BuffUp(S.HeartoftheJadeSerpentCDRBuff) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 48"; end
  end
  -- tiger_palm,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.wisdom_of_the_wall_flurry.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.WisdomoftheWallFlurryBuff)) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 50"; end
  end
  -- tiger_palm,if=combo_strike&chi.deficit>=2&energy.time_to_max<=gcd.max*3
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:EnergyTimeToMax() <= Player:GCD() * 3) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 52"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack>7&talent.memory_of_the_monastery&!buff.memory_of_the_monastery.up&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 7 and S.MemoryoftheMonastery:IsAvailable() and Player:BuffDown(S.MemoryoftheMonasteryBuff) and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 54"; end
  end
  -- spinning_crane_kick,if=(buff.dance_of_chiji.stack=2|buff.dance_of_chiji.remains<2&buff.dance_of_chiji.up)&combo_strike&!buff.ordered_elements.up
  if S.SpinningCraneKick:IsReady() and ((Player:BuffStack(S.DanceofChijiBuff) == 2 or Player:BuffRemains(S.DanceofChijiBuff) < 2 and Player:BuffUp(S.DanceofChijiBuff)) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 56"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 58"; end
  end
  -- spinning_crane_kick,if=buff.dance_of_chiji.stack=2&combo_strike
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 60"; end
  end
  -- blackout_kick,if=talent.courageous_impulse&combo_strike&buff.bok_proc.stack=2
  if S.BlackoutKick:IsReady() and (S.CourageousImpulse:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffStack(S.BlackoutKickBuff) == 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 62"; end
  end
  -- blackout_kick,if=combo_strike&buff.ordered_elements.up&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.OrderedElementsBuff) and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 64"; end
  end
  -- tiger_palm,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable()) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 66"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&(buff.ordered_elements.up|energy.time_to_max>=gcd.max*3&talent.sequenced_strikes&talent.energy_burst|!talent.sequenced_strikes|!talent.energy_burst|buff.dance_of_chiji.remains<=gcd.max*3)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and (Player:BuffUp(S.OrderedElementsBuff) or Player:EnergyTimeToMax() >= Player:GCD() * 3 and S.SequencedStrikes:IsAvailable() and S.EnergyBurst:IsAvailable() or not S.SequencedStrikes:IsAvailable() or not S.EnergyBurst:IsAvailable() or Player:BuffRemains(S.DanceofChijiBuff) <= Player:GCD() * 3)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 68"; end
  end
  -- jadefire_stomp,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsCastable() and (S.SingularlyFocusedJade:IsAvailable() or S.JadefireHarmony:IsAvailable()) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_st 70"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 72"; end
  end
  -- blackout_kick,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable()) and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 74"; end
  end
  -- blackout_kick,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff))) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 76"; end
  end
  -- jadefire_stomp
  if S.JadefireStomp:IsCastable() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_st 78"; end
  end
  -- tiger_palm,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 80"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 82"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.ordered_elements.up&talent.hit_combo
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 84"; end
  end
  -- blackout_kick,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if MotCCastSwitcher(S.BlackoutKick, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "blackout_kick default_st 86"; end
  end
  -- tiger_palm,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if MotCCastSwitcher(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, 5) then return "tiger_palm default_st 88"; end
  end
  -- Manually added: tiger_palm,if=chi=0 (avoids a potential profile stall)
  if S.TigerPalm:IsReady() and (Player:Chi() == 0) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 90"; end
  end
end

--- ===== APL Main =====
local function APL()
Enemies5y = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
if AoEON() then
  EnemiesCount8y = #Enemies8y
else
  EnemiesCount8y = 1
end

if Everyone.TargetIsValid() or Player:AffectingCombat() then
  -- Calculate fight_remains
  BossFightRemains = HL.BossFightRemains()
  FightRemains = BossFightRemains
  if FightRemains == 11111 then
    FightRemains = HL.FightRemains(Enemies8y, false)
  end

  -- Check MotC Status
  MotCCount = S.MarkoftheCraneDebuff:AuraActiveCount()
  MotCMinTime = MotCMinTimeCheck()
end

if Everyone.TargetIsValid() then
  -- Precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  -- auto_attack
  -- roll,if=movement.distance>5
  -- chi_torpedo,if=movement.distance>5
  -- flying_serpent_kick,if=movement.distance>5
  -- Note: Not handling movement abilities
  -- Manually added: Force landing from FSK
  --if not Settings.Windwalker.IgnoreFSK and Player:PrevGCD(1, S.FlyingSerpentKick) then
    --if Cast(S.FlyingSerpentKickLand) then return "flying_serpent_kick land"; end
  --end
  -- spear_hand_strike,if=target.debuff.casting.react
  local ShouldReturn = Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsDS.DisplayStyle.Interrupts, Stuns); if ShouldReturn then return ShouldReturn; end
  -- Manually added: fortifying_brew
  if S.FortifyingBrew:IsReady() and Settings.Windwalker.ShowFortifyingBrewCD and Player:HealthPercentage() <= Settings.Windwalker.FortifyingBrewHP then
    if Cast(S.FortifyingBrew, Settings.Windwalker.GCDasOffGCD.FortifyingBrew, nil, not Target:IsSpellInRange(S.FortifyingBrew)) then return "fortifying_brew main 2"; end
  end
  -- potion handling
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if S.InvokeXuenTheWhiteTiger:IsAvailable() then
        -- potion,if=buff.storm_earth_and_fire.up&pet.xuen_the_white_tiger.active|fight_remains<=30
        if Player:BuffUp(S.StormEarthAndFireBuff) and Monk.Xuen.Active or BossFightRemains <= 30 then
          if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion with xuen main 4"; end
        end
      else
        -- potion,if=buff.storm_earth_and_fire.up|fight_remains<=30
        if Player:BuffUp(S.StormEarthAndFireBuff) or BossFightRemains <= 30 then
          if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion without xuen main 6"; end
        end
      end
    end
  end
  -- variable,name=has_external_pi,value=cooldown.invoke_power_infusion_0.duration>0
  -- Note: Not handling external buffs.
  -- call_action_list,name=trinkets
  if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=aoe_opener,if=time<3&active_enemies>2
  if HL.CombatTime() < 3 and EnemiesCount8y > 2 then
    local ShouldReturn = AoEOpener(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=normal_opener,if=time<4&active_enemies<3
  if HL.CombatTime() < 4 and EnemiesCount8y < 3 then
    local ShouldReturn = NormalOpener(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=cooldowns,if=talent.storm_earth_and_fire
  if S.StormEarthAndFire:IsAvailable() and CDsON() then
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=default_aoe,if=active_enemies>=5
  if AoEON() and EnemiesCount8y >= 5 then
    local ShouldReturn = DefaultAoE(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=default_cleave,if=active_enemies>1&(time>7|!talent.celestial_conduit)&active_enemies<5
  if AoEON() and EnemiesCount8y > 1 and (HL.CombatTime() > 7 or not S.CelestialConduit:IsAvailable()) and EnemiesCount8y < 5 then
    local ShouldReturn = DefaultCleave(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=default_st,if=active_enemies<2
  if not AoEON() or EnemiesCount8y < 2 then
    local ShouldReturn = DefaultST(); if ShouldReturn then return ShouldReturn; end
  end
  -- Manually added Pool filler
  if Cast(S.PoolEnergy) then return "Pool Energy"; end
end
end

local function Init()
S.MarkoftheCraneDebuff:RegisterAuraTracking()

HR.Print("Windwalker Monk rotation has been updated for patch 11.1.0")
end

HR.SetAPL(269, APL, Init)