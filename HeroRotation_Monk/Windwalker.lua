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
local pairs         = pairs
local tinsert       = table.insert
-- WoW API
local Delay         = C_Timer.After
-- File locals
local Monk = HR.Commons.Monk

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker
local I = Item.Monk.Windwalker

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- DF Trinkets
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.DragonfireBombDispenser:ID(),
  I.EruptingSpearFragment:ID(),
  I.ManicGrieftorch:ID(),
  -- DF Other Items
  I.Djaruun:ID(),
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
local Enemies5y, Enemies8y, EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Item Objects =====
local Trinket1, Trinket2
local VarTrinketFailures = 0
local function SetTrinketVariables()
  Trinket1, Trinket2 = Player:GetTrinketItems()
  if VarTrinketFailures < 5 and (Trinket1:ID() == 0 or Trinket2:ID() == 0) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
  end
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

local function MotCCounter()
  local Count = 0
  for _, CycleUnit in pairs(Enemies8y) do
    if CycleUnit:DebuffUp(S.MarkoftheCraneDebuff) then
      Count = Count + 1
    end
  end
  return Count
end

local function SCKMax()
  local Count = MotCCounter()
  if (EnemiesCount8y == Count or Count >= 5) then return true end
  return false
end

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

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfInvokeXuenCDs(TargetUnit)
  return (TargetUnit:TimeToDie() > 14 and not Player:IsInDungeonArea() or TargetUnit:TimeToDie() > 22) and (EnemiesCount8y > 2 or TargetUnit:DebuffUp(S.AcclamationDebuff))
end

local function EvaluateTargetIfTigerPalmCDs(TargetUnit)
  return TargetUnit:TimeToDie() > 14 and not Player:IsInDungeonArea() or TargetUnit:TimeToDie() > 22
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: openers
  -- tiger_palm,if=!prev.tiger_palm
  if S.TigerPalm:IsReady() and (not Player:PrevGCD(1, S.TigerPalm)) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm precombat 2"; end
  end
  -- rising_sun_kick
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick precombat 4"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- algethar_puzzle_box,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&!buff.storm_earth_and_fire.up|fight_remains<25
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((Monk.Xuen.Active or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffDown(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box trinkets 2"; end
    end
    -- erupting_spear_fragment,if=buff.storm_earth_and_fire.up
    if I.EruptingSpearFragment:IsEquippedAndReady() and (Player:BuffUp(S.StormEarthAndFireBuff)) then
      if Cast(I.EruptingSpearFragment, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment trinkets 4"; end
    end
    -- use_item,manic_grieftorch,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.storm_earth_and_fire.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<5
    if I.ManicGrieftorch:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.StormEarthAndFireBuff) and not Monk.Xuen.Active or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or BossFightRemains < 5) then
      if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "manic_grieftorch trinkets 6"; end
    end
    -- beacon_to_the_beyond,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.storm_earth_and_fire.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<10
    if I.BeacontotheBeyond:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.StormEarthAndFireBuff) and not Monk.Xuen.Active or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or BossFightRemains < 10) then
      if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond trinkets 8"; end
    end
  end
  -- djaruun_pillar_of_the_elder_flame,if=cooldown.fists_of_fury.remains<2&cooldown.invoke_xuen_the_white_tiger.remains>10|fight_remains<12
  if Settings.Commons.Enabled.Items and I.Djaruun:IsEquippedAndReady() and (S.FistsofFury:CooldownRemains() < 2 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or BossFightRemains < 12) then
    if Cast(I.Djaruun, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame trinkets 10"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- dragonfire_bomb_dispenser,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>10|fight_remains<10
    if I.DragonfireBombDispenser:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or BossFightRemains < 10) then
      if Cast(I.DragonfireBombDispenser, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser trinkets 12"; end
    end
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    -- ITEM_STAT_BUFF,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&buff.storm_earth_and_fire.up|fight_remains<25
    if Trinket1ToUse and Trinket1ToUse:HasUseBuff() and ((Monk.Xuen.Active or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
      if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (trinkets stat_buff trinket1)"; end
    end
    if Trinket2ToUse and Trinket2ToUse:HasUseBuff() and ((Monk.Xuen.Active or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
      if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (trinkets stat_buff trinket2)"; end
    end
    -- ITEM_DMG_BUFF,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30
    if Trinket1ToUse and (not Trinket1ToUse:HasUseBuff() or Trinket1ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
      if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (trinkets dmg_buff trinket1)"; end
    end
    if Trinket2ToUse and (not Trinket2ToUse:HasUseBuff() or Trinket2ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
      if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (trinkets dmg_buff trinket2)"; end
    end
  end
end

local function Cooldowns()
  -- invoke_external_buff,name=power_infusion,if=pet.xuen_the_white_tiger.active&(!buff.bloodlust.up|buff.bloodlust.up&cooldown.strike_of_the_windlord.remains)
  -- Note: Not handling external buffs.
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&!cooldown.invoke_xuen_the_white_tiger.remains&(chi<5&!talent.ordered_elements|chi<3)&(combo_strike|!talent.hit_combo)
  if S.TigerPalm:IsReady() and (S.InvokeXuenTheWhiteTiger:CooldownUp() and (Player:Chi() < 5 and not S.OrderedElements:IsAvailable() or Player:Chi() < 3) and (ComboStrike(S.TigerPalm) or not S.HitCombo:IsAvailable())) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, EvaluateTargetIfTigerPalmCDs, not Target:IsInMeleeRange(5)) then return "tiger_palm cooldowns 2"; end
  end
  -- invoke_xuen_the_white_tiger,target_if=max:target.time_to_die,if=cooldown.storm_earth_and_fire.ready&(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&(active_enemies>2|debuff.acclamation.up)&(chi>2&talent.ordered_elements|chi>5|chi>3&energy<50|energy<50&active_enemies=1)|fight_remains<30
  if S.InvokeXuenTheWhiteTiger:IsCastable() and (S.StormEarthAndFire:CooldownUp() and (Player:Chi() > 2 and S.OrderedElements:IsAvailable() or Player:Chi() > 5 or Player:Chi() > 3 and Player:Energy() < 50 or Player:Energy() < 50 and EnemiesCount8y == 1) or BossFightRemains < 30) then
    if Everyone.CastTargetIf(S.InvokeXuenTheWhiteTiger, Enemies8y, "max", EvaluateTargetIfFilterTTD, EvaluateTargetIfInvokeXuenCDs, not Target:IsInRange(40), Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger) then return "invoke_xuen_the_white_tiger cooldowns 4"; end
  end
  -- storm_earth_and_fire,if=(target.time_to_die>14&!fight_style.dungeonroute|target.time_to_die>22)&(active_enemies>2|cooldown.rising_sun_kick.remains|!talent.ordered_elements)&((buff.invokers_delight.up&!buff.bloodlust.up|buff.bloodlust.up&cooldown.storm_earth_and_fire.full_recharge_time<1)|cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains&!buff.bloodlust.up&(active_enemies>1|cooldown.strike_of_the_windlord.remains<2&(talent.flurry_strikes|buff.heart_of_the_jade_serpent.up))&(chi>3|chi>1&talent.ordered_elements)|cooldown.storm_earth_and_fire.full_recharge_time<10&(chi>3|chi>1&talent.ordered_elements))|fight_remains<30|prev.invoke_xuen_the_white_tiger
  if S.StormEarthAndFire:IsCastable() and ((Target:TimeToDie() > 14 and not Player:IsInDungeonArea() or Target:TimeToDie() > 22) and (EnemiesCount8y > 2 or S.RisingSunKick:CooldownDown() or not S.OrderedElements:IsAvailable()) and ((Player:BuffUp(S.InvokersDelightBuff) and Player:BloodlustDown() and S.StormEarthAndFire:FullRechargeTime() < 1) or S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains() and Player:BloodlustDown() and (EnemiesCount8y > 1 or S.StrikeoftheWindlord:CooldownRemains() < 2 and (S.FlurryStrikes:IsAvailable() or Player:BuffUp(S.HeartoftheJadeSerpentBuff))) and (Player:Chi() > 3 or Player:Chi() > 1 and S.OrderedElements:IsAvailable()) or S.StormEarthAndFire:FullRechargeTime() < 10 and (Player:Chi() > 3 or Player:Chi() > 1 and S.OrderedElements:IsAvailable())) or BossFightRemains < 30 or Player:PrevGCD(1, S.InvokeXuenTheWhiteTiger)) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cooldowns 6"; end
  end
  -- touch_of_karma
  if S.TouchofKarma:IsCastable() and not Settings.Windwalker.IgnoreToK then
    if Cast(S.TouchofKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cooldowns 8"; end
  end
  if S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or BossFightRemains < 20 then
    -- ancestral_call,if=cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<20
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cooldowns 10"; end
    end
    -- blood_fury,if=cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<20
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cooldowns 12"; end
    end
  end
  -- fireblood,if=cooldown.invoke_xuen_the_white_tiger.remains>30|fight_remains<10
  if S.Fireblood:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or BossFightRemains < 10) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cooldowns 14"; end
  end
  -- berserking,if=cooldown.invoke_xuen_the_white_tiger.remains>60|fight_remains<15
  if S.Berserking:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 60 or BossFightRemains < 15) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cooldowns 16"; end
  end
  if Player:BuffDown(S.StormEarthAndFireBuff) then
    -- bag_of_tricks,if=buff.storm_earth_and_fire.down
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cooldowns 18"; end
    end
    -- lights_judgment,if=buff.storm_earth_and_fire.down
    if S.LightsJudgment:IsCastable() then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "lights_judgment cooldowns 20"; end
    end
    -- haymaker,if=buff.storm_earth_and_fire.down
    if S.Haymaker:IsCastable() then
      if Cast(S.Haymaker, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "haymaker cooldowns 22"; end
    end
    -- rocket_barrage,if=buff.storm_earth_and_fire.down
    if S.RocketBarrage:IsCastable() then
      if Cast(S.RocketBarrage, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "rocket_barrage cooldowns 24"; end
    end
    -- azerite_surge,if=buff.storm_earth_and_fire.down
    if S.AzeriteSurge:IsCastable() then
      if Cast(S.AzeriteSurge, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "azerite_surge cooldowns 26"; end
    end
  end
end

local function AoEOpener()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi<6
  if S.TigerPalm:IsReady() and (Player:Chi() < 6) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm aoe_opener 2"; end
  end
end

local function NormalOpener()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=chi<6&combo_strike
  if S.TigerPalm:IsReady() and (Player:Chi() < 6 and ComboStrike(S.TigerPalm)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies8y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm normal_opener 2"; end
  end
  -- rising_sun_kick,target_if=max:debuff.acclamation.stack
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick normal_opener 4"; end
  end
end

local function DefaultAoE()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up)&!buff.ordered_elements.up&(!set_bonus.tier30_2pc|set_bonus.tier30_2pc&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&talent.energy_burst)|(talent.energy_burst&!buff.bok_proc.up)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|cooldown.strike_of_the_windlord.remains)&cooldown.celestial_conduit.remains<2&buff.ordered_elements.up&chi<5&combo_strike
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutReinforcementBuff)) and Player:BuffDown(S.OrderedElementsBuff) and (not Player:HasTier(30, 2) or Player:HasTier(30, 2) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and S.EnergyBurst:IsAvailable()) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff)) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or S.StrikeoftheWindlord:CooldownDown()) and S.CelestialConduit:CooldownRemains() < 2 and Player:BuffUp(S.OrderedElementsBuff) and Player:Chi() < 5 and ComboStrike(S.TigerPalm)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 2"; end
  end
  -- touch_of_death
  if S.TouchofDeath:CooldownUp() then
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
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.chi_energy.stack>29&cooldown.fists_of_fury.remains<5
  -- Note: Combining both lines and using Cast instead of CastTargetIf, since SCK hits all targets in range anyway.
  if S.SpinningCraneKick:IsReady() and ((Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) or (ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.ChiEnergyBuff) > 29 and S.FistsofFury:CooldownRemains() < 5)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 8"; end
  end
  -- celestial_conduit,target_if=max:debuff.acclamation.stack,if=buff.storm_earth_and_fire.up&cooldown.strike_of_the_windlord.remains&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and S.StrikeoftheWindlord:CooldownDown() and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_aoe 10"; end
  end
  -- rising_sun_kick,,target_if=max:target.time_to_die,if=!talent.xuens_battlegear&!cooldown.whirling_dragon_punch.remains&cooldown.fists_of_fury.remains>1&(!talent.revolving_whirl|talent.revolving_whirl&buff.dance_of_chiji.stack<2&active_enemies>2)
  if S.RisingSunKick:IsReady() and (not S.XuensBattlegear:IsAvailable() and S.WhirlingDragonPunch:CooldownUp() and S.FistsofFury:CooldownRemains() > 1 and (not S.RevolvingWhirl:IsAvailable() or S.RevolvingWhirl:IsAvailable() and Player:BuffStack(S.DanceofChijiBuff) < 2 and EnemiesCount8y > 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 12"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=!talent.revolving_whirl|talent.revolving_whirl&buff.dance_of_chiji.stack<2&active_enemies>2
  if S.WhirlingDragonPunch:IsReady() and (not S.RevolvingWhirl:IsAvailable() or S.RevolvingWhirl:IsAvailable() and Player:BuffStack(S.DanceofChijiBuff) < 2 and EnemiesCount8y > 2) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 14"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.bok_proc.up&chi<2&talent.energy_burst&energy<55
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutKickBuff) and Player:Chi() < 2 and S.EnergyBurst:IsAvailable() and Player:Energy() < 55) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 16"; end
  end
  -- strike_of_the_windlord,target_if=max:target.time_to_die,if=time>5&(cooldown.invoke_xuen_the_white_tiger.remains>15|talent.flurry_strikes)
  if S.StrikeoftheWindlord:IsReady() and (HL.CombatTime() > 5 and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or S.FlurryStrikes:IsAvailable())) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_aoe 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=8&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 8 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 20"; end
  end
  -- crackling_jade_lightning,target_if=max:target.time_to_die,if=buff.the_emperors_capacitor.stack>19&combo_strike&talent.power_of_the_thunder_king
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and ComboStrike(S.CracklingJadeLightning) and S.PoweroftheThunderKing:IsAvailable()) then
    if Everyone.CastTargetIf(S.CracklingJadeLightning, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_aoe 22"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die
  if S.FistsofFury:IsReady() then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_aoe 24"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.wisdom_of_the_wall_flurry.up&chi<6
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.WisdomoftheWallFlurryBuff) and Player:Chi() < 6) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 26"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&chi>5
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&buff.chi_energy.stack>29&cooldown.fists_of_fury.remains<5
  -- Note: Combining both lines and using Cast instead of CastTargetIf, since SCK hits all targets in range anyway.
  if S.SpinningCraneKick:IsReady() and ((ComboStrike(S.SpinningCraneKick) and Player:Chi() > 5) or (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffStack(S.ChiEnergyBuff) > 29 and S.FistsofFury:CooldownRemains() < 5)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 28"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.pressure_point.up&cooldown.fists_of_fury.remains>2
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&spinning_crane_kick.max
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.crane_vortex&active_enemies>2&spinning_crane_kick.max
  -- Note: Combining both lines and using Cast instead of CastTargetIf, since SCK hits all targets in range anyway.
  if S.SpinningCraneKick:IsReady() and ((ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and SCKMax()) or (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 3 and SCKMax())) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 32"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.ordered_elements.up
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.deficit>=2&(!buff.ordered_elements.up|energy.time_to_max<=gcd.max*3)
  -- Note: Combining both lines.
  if S.TigerPalm:IsReady() and ((ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.OrderedElementsBuff)) or (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDown(S.OrderedElementsBuff) or Player:EnergyTimeToMax() <= Player:GCD() * 3))) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 34"; end
  end
  -- jadefire_stomp,target_if=max:target.time_to_die,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsCastable() and (S.SingularlyFocusedJade:IsAvailable() or S.JadefireHarmony:IsAvailable()) then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 36"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&!buff.ordered_elements.up&talent.crane_vortex&active_enemies>2&chi>4&spinning_crane_kick.max
  -- Note: Using Cast instead of CastTargetIf, since SCK hits all targets in range anyway.
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2 and Player:Chi() > 4 and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 38"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(buff.teachings_of_the_monastery.stack>3|buff.ordered_elements.up)&(talent.shadowboxing_treads|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 or Player:BuffUp(S.OrderedElementsBuff)) and (S.ShadowboxingTreads:IsAvailable() or Player:BuffUp(S.BlackoutKickBuff))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 40"; end
  end
  -- spinning_crane_kick,if=combo_strike&(chi>3|energy>55)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (Player:Chi() > 3 or Player:Energy() > 55)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  -- Note: Combining both lines.
  if S.BlackoutKick:IsReady() and ((ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable()) and S.FistsofFury:CooldownDown()) or (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff)))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 44"; end
  end
  -- jadefire_stomp,target_if=max:debuff.acclamation.stack
  if S.JadefireStomp:IsCastable() then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_aoe 46"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 48"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 50"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 52"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.ordered_elements.up&talent.hit_combo&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable() and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 56"; end
  end
  -- tiger_palm,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 58"; end
  end
  -- Manually added: tiger_palm,if=chi=0 (avoids a potential profile stall)
  if S.TigerPalm:IsReady() and (Player:Chi() == 0) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_aoe 60"; end
  end
end

local function DefaultCleave()
  -- rising_sun_kick,target_if=max:target.time_to_die,if=buff.pressure_point.up&active_enemies<4&cooldown.fists_of_fury.remains>4
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and EnemiesCount8y < 4 and S.FistsofFury:CooldownRemains() > 4) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.stack=2&active_enemies>3
  -- Note: Using Cast instead of the CastTargetIf, since SCK hits all targets anyway.
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.DanceofChijiBuff) == 2 and EnemiesCount8y > 3) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 4"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up|(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|cooldown.strike_of_the_windlord.remains)&cooldown.celestial_conduit.remains<2&buff.ordered_elements.up&chi<5&combo_strike|(!buff.heart_of_the_jade_serpent_cdr.up|!buff.heart_of_the_jade_serpent_cdr_celestial.up)&combo_strike&chi.deficit>=2&!buff.ordered_elements.up
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or S.StrikeoftheWindlord:CooldownDown()) and S.CelestialConduit:CooldownRemains() < 2 and Player:BuffUp(S.OrderedElementsBuff) and Player:Chi() < 5 and ComboStrike(S.TigerPalm) or (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.OrderedElementsBuff)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 6"; end
  end
  -- touch_of_death
  if S.TouchofDeath:CooldownUp() then
    local ToDTar = ToDTarget()
    if ToDTar then
      if ToDTar:GUID() == Target:GUID() then
        if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death default_cleave 8"; end
      else
        if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death default_cleave 10"; end
      end
    end
  end
  -- celestial_conduit,target_if=max:debuff.acclamation.stack,if=buff.storm_earth_and_fire.up&cooldown.strike_of_the_windlord.remains&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and S.StrikeoftheWindlord:CooldownDown() and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_cleave 12"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=!pet.xuen_the_white_tiger.active&prev.tiger_palm&time<5|buff.heart_of_the_jade_serpent_cdr_celestial.up&buff.pressure_point.up
  if S.RisingSunKick:IsReady() and (not Monk.Xuen.Active and Player:PrevGCD(1, S.TigerPalm) and HL.CombatTime() < 5 or Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff) and Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 14"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die,if=buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_cleave 16"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=buff.heart_of_the_jade_serpent_cdr_celestial.up
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffUp(S.HeartoftheJadeSerpentCDRCelestialBuff)) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_cleave 18"; end
  end
  -- strike_of_the_windlord,target_if=max:target.time_to_die,if=talent.gale_force&buff.invokers_delight.up&(buff.bloodlust.up|cooldown.celestial_conduit.remains&!buff.heart_of_the_jade_serpent_cdr_celestial.up)
  if S.StrikeoftheWindlord:IsReady() and (S.GaleForce:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff) and (Player:BloodlustUp() or S.CelestialConduit:CooldownDown() and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff))) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_cleave 20"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die,if=buff.power_infusion.up&buff.bloodlust.up
  if S.FistsofFury:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_cleave 22"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=buff.power_infusion.up&buff.bloodlust.up&active_enemies<3
  if S.RisingSunKick:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp() and EnemiesCount8y < 3) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 24"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=8&(active_enemies<3|talent.shadowboxing_treads)
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 8 and (EnemiesCount8y < 3 or S.ShadowboxingTreads:IsAvailable())) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 26"; end
  end
  -- whirling_dragon_punch,target_if=max:target.time_to_die,if=!talent.revolving_whirl|talent.revolving_whirl&buff.dance_of_chiji.stack<2&active_enemies>2|active_enemies<3
  if S.WhirlingDragonPunch:IsReady() and (not S.RevolvingWhirl:IsAvailable() or S.RevolvingWhirl:IsAvailable() and Player:BuffStack(S.DanceofChijiBuff) < 2 and EnemiesCount8y > 2 or EnemiesCount8y < 3) then
    if Everyone.CastTargetIf(S.WhirlingDragonPunch, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_cleave 28"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.acclamation.stack,if=time>5&(cooldown.invoke_xuen_the_white_tiger.remains>15|talent.flurry_strikes)
  if S.StrikeoftheWindlord:IsReady() and (HL.CombatTime() > 5 and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or S.FlurryStrikes:IsAvailable())) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_cleave 30"; end
  end
  -- crackling_jade_lightning,target_if=max:target.time_to_die,if=buff.the_emperors_capacitor.stack>19&combo_strike&talent.power_of_the_thunder_king
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and ComboStrike(S.CracklingJadeLightning) and S.PoweroftheThunderKing:IsAvailable()) then
    if Everyone.CastTargetIf(S.CracklingJadeLightning, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_cleave 32"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&set_bonus.tier30_2pc&!buff.blackout_reinforcement.up
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.stack=2
  -- Note: Combining both lines and using Cast instead of CastTargetIf, since SCK hits all viable targets.
  if S.SpinningCraneKick:IsReady() and ((ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:HasTier(30, 2) and Player:BuffDown(S.BlackoutReinforcementBuff)) or (ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.DanceofChijiBuff) == 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 34"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&active_enemies<5&buff.wisdom_of_the_wall_flurry.up&active_enemies<4
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and EnemiesCount8y < 5 and Player:BuffUp(S.WisdomoftheWallFlurryBuff) and EnemiesCount8y < 4) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 36"; end
  end
  -- fists_of_fury,target_if=max:target.time_to_die,if=buff.ordered_elements.remains>execute_time|!buff.ordered_elements.up|buff.ordered_elements.remains<=gcd.max|active_enemies>2
  if S.FistsofFury:IsReady() and (Player:BuffRemains(S.OrderedElementsBuff) > S.FistsofFury:ExecuteTime() or Player:BuffDown(S.OrderedElementsBuff) or Player:BuffRemains(S.OrderedElementsBuff) <= Player:GCD() or EnemiesCount8y > 2) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_cleave 38"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&active_enemies<5&buff.wisdom_of_the_wall_flurry.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and EnemiesCount8y < 5 and Player:BuffUp(S.WisdomoftheWallFlurryBuff)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up&buff.chi_energy.stack>29
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffStack(S.ChiEnergyBuff) > 29) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 42"; end
  end
  -- rising_sun_kick,target_if=max:target.time_to_die,if=chi>4&(active_enemies<3|talent.glory_of_the_dawn)|chi>2&energy>50&(active_enemies<3|talent.glory_of_the_dawn)|cooldown.fists_of_fury.remains>2&(active_enemies<3|talent.glory_of_the_dawn)
  if S.RisingSunKick:IsReady() and (Player:Chi() > 4 and (EnemiesCount8y < 3 or S.GloryoftheDawn:IsAvailable()) or Player:Chi() > 2 and Player:Energy() > 50 and (EnemiesCount8y < 3 or S.GloryoftheDawn:IsAvailable()) or S.FistsofFury:CooldownRemains() > 2 and (EnemiesCount8y < 3 or S.GloryoftheDawn:IsAvailable())) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_cleave 44"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=4&!talent.knowledge_of_the_broken_temple&talent.shadowboxing_treads&active_enemies<3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 4 and not S.KnowledgeoftheBrokenTemple:IsAvailable() and S.ShadowboxingTreads:IsAvailable() and EnemiesCount8y < 3) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 46"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.dance_of_chiji.up
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&buff.ordered_elements.up&talent.crane_vortex&active_enemies>2
  -- Note: Combining both lines and using Cast instead of CastTargetIf, since SCK hits all viable targets.
  if S.SpinningCraneKick:IsReady() and ((ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) or (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 48"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&active_enemies<5
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.deficit>=2&(!buff.ordered_elements.up|energy.time_to_max<=gcd.max*3)
  -- Note: Combining both lines.
  if S.TigerPalm:IsReady() and ((ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and EnemiesCount8y < 5) or (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and (Player:BuffDown(S.OrderedElementsBuff) or Player:EnergyTimeToMax() <= Player:GCD() * 3))) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 50"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&buff.teachings_of_the_monastery.stack>3&cooldown.rising_sun_kick.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 and S.RisingSunKick:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 52"; end
  end
  -- jadefire_stomp,target_if=max:debuff.acclamation.stack,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsReady() and (S.SingularlyFocusedJade:IsAvailable() or S.JadefireHarmony:IsAvailable()) then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_cleave 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(buff.teachings_of_the_monastery.stack>3|buff.ordered_elements.up)&(talent.shadowboxing_treads|buff.bok_proc.up|buff.ordered_elements.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 or Player:BuffUp(S.OrderedElementsBuff)) and (S.ShadowboxingTreads:IsAvailable() or Player:BuffUp(S.BlackoutKickBuff) or Player:BuffUp(S.OrderedElementsBuff))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 56"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=combo_strike&!buff.ordered_elements.up&talent.crane_vortex&active_enemies>2&chi>4
  -- Note: Using Cast instead of CastTargetIf, since SCK hits all targets in range anyway.
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff) and S.CraneVortex:IsAvailable() and EnemiesCount8y > 2 and Player:Chi() > 4) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 58"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_cleave 60"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  -- Note: Combining both lines.
  if S.BlackoutKick:IsReady() and ((ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable()) and S.FistsofFury:CooldownDown()) or (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff)))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 62"; end
  end
  -- jadefire_stomp,target_if=max:debuff.acclamation.stack
  if S.JadefireStomp:IsCastable() then
    if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_cleave 64"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 66"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_cleave 68"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.ordered_elements.up&talent.hit_combo
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_cleave 70"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_cleave 72"; end
  end
  -- tiger_palm,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_cleave 74"; end
  end
end

local function DefaultST()
  -- rising_sun_kick,if=buff.pressure_point.up|buff.ordered_elements.remains<=gcd.max*3&buff.storm_earth_and_fire.up
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) or Player:BuffRemains(S.OrderedElementsBuff) <= Player:GCD() * 3 and Player:BuffUp(S.StormEarthAndFireBuff)) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 2"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=(energy>55&talent.inner_peace|energy>60&!talent.inner_peace)&combo_strike&chi.max-chi>=2&buff.teachings_of_the_monastery.stack<buff.teachings_of_the_monastery.max_stack&(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up|(talent.energy_burst&!buff.bok_proc.up|!talent.energy_burst)&!buff.ordered_elements.up&!cooldown.fists_of_fury.remains&chi<3|(prev.strike_of_the_windlord|cooldown.strike_of_the_windlord.remains)&cooldown.celestial_conduit.remains<2&buff.ordered_elements.up&chi<5&combo_strike|(!buff.heart_of_the_jade_serpent_cdr.up|!buff.heart_of_the_jade_serpent_cdr_celestial.up)&combo_strike&chi.deficit>=2&!buff.ordered_elements.up
  if S.TigerPalm:IsReady() and ((Player:Energy() > 55 and S.InnerPeace:IsAvailable() or Player:Energy() > 60 and not S.InnerPeace:IsAvailable()) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < VarTotMMaxStacks and (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) or (S.EnergyBurst:IsAvailable() and Player:BuffDown(S.BlackoutKickBuff) or not S.EnergyBurst:IsAvailable()) and Player:BuffDown(S.OrderedElementsBuff) and S.FistsofFury:CooldownUp() and Player:Chi() < 3 or (Player:PrevGCD(1, S.StrikeoftheWindlord) or S.StrikeoftheWindlord:CooldownDown()) and S.CelestialConduit:CooldownRemains() < 2 and Player:BuffUp(S.OrderedElementsBuff) and Player:Chi() < 5 and ComboStrike(S.TigerPalm) or (Player:BuffDown(S.HeartoftheJadeSerpentCDRBuff) or Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff)) and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffDown(S.OrderedElementsBuff)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 4"; end
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
        if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death default_st 6"; end
      else
        if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death default_st 8"; end
      end
    end
  end
  -- celestial_conduit,if=buff.storm_earth_and_fire.up&buff.ordered_elements.up&cooldown.strike_of_the_windlord.remains&(talent.xuens_bond|!talent.xuens_bond&buff.invokers_delight.up)|fight_remains<15
  if S.CelestialConduit:IsReady() and (Player:BuffUp(S.StormEarthAndFireBuff) and Player:BuffUp(S.OrderedElementsBuff) and S.StrikeoftheWindlord:CooldownDown() and (S.XuensBond:IsAvailable() or not S.XuensBond:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff)) or BossFightRemains < 15) then
    if Cast(S.CelestialConduit, nil, nil, not Target:IsInMeleeRange(15)) then return "celestial_conduit default_st 10"; end
  end
  -- rising_sun_kick,target_if=max:debuff.acclamation.stack,if=!pet.xuen_the_white_tiger.active&prev.tiger_palm&time<5|buff.storm_earth_and_fire.up&talent.ordered_elements
  if S.RisingSunKick:IsReady() and (not Monk.Xuen.Active and Player:PrevGCD(1, S.TigerPalm) and HL.CombatTime() < 5 or Player:BuffUp(S.StormEarthAndFireBuff) and S.OrderedElements:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 12"; end
  end
  -- strike_of_the_windlord,if=talent.gale_force&buff.invokers_delight.up&(buff.bloodlust.up|cooldown.celestial_conduit.remains&!buff.heart_of_the_jade_serpent_cdr_celestial.up)
  if S.StrikeoftheWindlord:IsReady() and (S.GaleForce:IsAvailable() and Player:BuffUp(S.InvokersDelightBuff) and (Player:BloodlustUp() or S.CelestialConduit:CooldownDown() and Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff))) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_st 14"; end
  end
  -- rising_sun_kick,target_if=max:debuff.acclamation.stack,if=buff.power_infusion.up&buff.bloodlust.up
  if S.RisingSunKick:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 16"; end
  end
  -- fists_of_fury,target_if=max:debuff.acclamation.stack,if=buff.power_infusion.up&buff.bloodlust.up
  if S.FistsofFury:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack>3&buff.ordered_elements.up&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 3 and Player:BuffUp(S.OrderedElementsBuff) and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 20"; end
  end
  -- spinning_crane_kick,if=buff.dance_of_chiji.stack=2&combo_strike&buff.power_infusion.up&buff.bloodlust.up
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick) and Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 22"; end
  end
  -- whirling_dragon_punch,if=buff.power_infusion.up&buff.bloodlust.up
  if S.WhirlingDragonPunch:IsReady() and (Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 24"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.power_infusion.up&buff.bloodlust.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:PowerInfusionUp() and Player:BloodlustUp()) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 26"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack>4&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 4 and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 28"; end
  end
  -- whirling_dragon_punch,if=!buff.heart_of_the_jade_serpent_cdr_celestial.up&!buff.dance_of_chiji.stack=2|buff.ordered_elements.up|talent.knowledge_of_the_broken_temple
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffDown(S.HeartoftheJadeSerpentCDRCelestialBuff) and Player:BuffStack(S.DanceofChijiBuff) ~= 2 or Player:BuffUp(S.OrderedElementsBuff) or S.KnowledgeoftheBrokenTemple:IsAvailable()) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 30"; end
  end
  -- strike_of_the_windlord,if=time>5&(cooldown.invoke_xuen_the_white_tiger.remains>15|talent.flurry_strikes)
  if S.StrikeoftheWindlord:IsReady() and (HL.CombatTime() > 5 and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 15 or S.FlurryStrikes:IsAvailable())) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_st 32"; end
  end
  -- rising_sun_kick,target_if=max:debuff.acclamation.stack,if=chi>4|chi>2&energy>50|cooldown.fists_of_fury.remains>2
  if S.RisingSunKick:IsReady() and (Player:Chi() > 4 or Player:Chi() > 2 and Player:Energy() > 50 or S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterAcclamation, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 34"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes&buff.wisdom_of_the_wall_flurry.up
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&chi.deficit>=2&energy.time_to_max<=gcd.max*3
  -- Note: Combining both lines.
  if S.TigerPalm:IsReady() and ((ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable() and Player:BuffUp(S.WisdomoftheWallFlurryBuff)) or (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:EnergyTimeToMax() <= Player:GCD() * 3)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack>7&talent.memory_of_the_monastery&!buff.memory_of_the_monastery.up&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) > 7 and S.MemoryoftheMonastery:IsAvailable() and Player:BuffDown(S.MemoryoftheMonasteryBuff) and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 38"; end
  end
  -- fists_of_fury,if=buff.ordered_elements.remains>execute_time|!buff.ordered_elements.up|buff.ordered_elements.remains<=gcd.max
  if S.FistsofFury:IsReady() and (Player:BuffRemains(S.OrderedElementsBuff) > S.FistsofFury:ExecuteTime() or Player:BuffDown(S.OrderedElementsBuff) or Player:BuffRemains(S.OrderedElementsBuff) <= Player:GCD()) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 40"; end
  end
  -- spinning_crane_kick,if=(buff.dance_of_chiji.stack=2|buff.dance_of_chiji.remains<2&buff.dance_of_chiji.up)&combo_strike&!buff.ordered_elements.up
  if S.SpinningCraneKick:IsReady() and ((Player:BuffStack(S.DanceofChijiBuff) == 2 or Player:BuffRemains(S.DanceofChijiBuff) < 2 and Player:BuffUp(S.DanceofChijiBuff)) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 42"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 44"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.teachings_of_the_monastery.stack=4&!talent.knowledge_of_the_broken_temple&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 4 and not S.KnowledgeoftheBrokenTemple:IsAvailable() and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 46"; end
  end
  -- spinning_crane_kick,if=buff.dance_of_chiji.stack=2&combo_strike
  if S.SpinningCraneKick:IsReady() and (Player:BuffStack(S.DanceofChijiBuff) == 2 and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 48"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&cooldown.rising_sun_kick.remains>1&cooldown.fists_of_fury.remains>2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.OrderedElementsBuff) and S.RisingSunKick:CooldownRemains() > 1 and S.FistsofFury:CooldownRemains() > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 50"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:EnergyTimeToMax() <= Player:GCD() * 3 and S.FlurryStrikes:IsAvailable()) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 52"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&(buff.ordered_elements.up|energy.time_to_max>=gcd.max*3&talent.sequenced_strikes&talent.energy_burst|!talent.sequenced_strikes|!talent.energy_burst|buff.dance_of_chiji.remains<=gcd.max*3)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and (Player:BuffUp(S.OrderedElementsBuff) or Player:EnergyTimeToMax() >= Player:GCD() * 3 and S.SequencedStrikes:IsAvailable() and S.EnergyBurst:IsAvailable() or not S.SequencedStrikes:IsAvailable() or not S.EnergyBurst:IsAvailable() or Player:BuffRemains(S.DanceofChijiBuff) <= Player:GCD() * 3)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 54"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&energy.time_to_max<=gcd.max*3&talent.flurry_strikes
  -- Note: Duplicate from 2 lines above. Skipping...
  -- jadefire_stomp,if=talent.Singularly_Focused_Jade|talent.jadefire_harmony
  if S.JadefireStomp:IsCastable() and (S.SingularlyFocusedJade:IsAvailable() and S.JadefireHarmony:IsAvailable()) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_st 56"; end
  end
  -- chi_burst,if=!buff.ordered_elements.up
  if S.ChiBurst:IsCastable() and (Player:BuffDown(S.OrderedElementsBuff)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 58"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&(buff.ordered_elements.up|buff.bok_proc.up&chi.deficit>=1&talent.energy_burst)&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and (Player:BuffUp(S.OrderedElementsBuff) or Player:BuffUp(S.BlackoutKickBuff) and Player:ChiDeficit() >= 1 and S.EnergyBurst:IsAvailable()) and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 60"; end
  end
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&!buff.ordered_elements.up&combo_strike
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and Player:BuffDown(S.OrderedElementsBuff) and ComboStrike(S.CracklingJadeLightning)) then
    if Cast(S.CracklingJadeLightning, Settings.Windwalker.GCDasOffGCD.CracklingJadeLightning, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning default_st 62"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&cooldown.fists_of_fury.remains&(chi>2|energy>60|buff.bok_proc.up)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown() and (Player:Chi() > 2 or Player:Energy() > 60 or Player:BuffUp(S.BlackoutKickBuff))) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 64"; end
  end
  -- jadefire_stomp
  if S.JadefireStomp:IsCastable() then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_st 66"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.ordered_elements.up&chi.deficit>=1
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:BuffUp(S.OrderedElementsBuff) and Player:ChiDeficit() >= 1) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 68"; end
  end
  -- chi_burst
  if S.ChiBurst:IsCastable() then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 70"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.ordered_elements.up&talent.hit_combo
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.OrderedElementsBuff) and S.HitCombo:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 72"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=buff.ordered_elements.up&!talent.hit_combo&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.OrderedElementsBuff) and not S.HitCombo:IsAvailable() and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 74"; end
  end
  -- tiger_palm,if=prev.tiger_palm&chi<3&!cooldown.fists_of_fury.remains
  if S.TigerPalm:IsReady() and (Player:PrevGCD(1, S.TigerPalm) and Player:Chi() < 3 and S.FistsofFury:CooldownUp()) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 76"; end
  end
  -- Manually added: tiger_palm,if=chi=0 (avoids a potential profile stall)
  if S.TigerPalm:IsReady() and (Player:Chi() == 0) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 78"; end
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
    if S.StormEarthAndFire:IsAvailable() then
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
  HR.Print("Windwalker Monk rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(269, APL, Init)
