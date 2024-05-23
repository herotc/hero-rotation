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


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Monk.Windwalker
local I = Item.Monk.Windwalker

-- Create table to exclude above trinkets from On Use function
local OnUseExcludesSerenity = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.Djaruun:ID(),
  I.DragonfireBombDispenser:ID(),
  I.EruptingSpearFragment:ID(),
  I.IrideusFragment:ID(),
  I.ManicGrieftorch:ID(),
}
local OnUseExcludesSEF = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.Djaruun:ID(),
  I.DragonfireBombDispenser:ID(),
  I.EruptingSpearFragment:ID(),
  I.ManicGrieftorch:ID(),
}

-- Rotation Var
local Enemies5y
local Enemies8y
local EnemiesCount8y
local BossFightRemains = 11111
local FightRemains = 11111
local XuenActive
local VarXuenOnUse = false
local VarHoldXuen = false
local VarHoldTPRSK = false
local VarHoldTPBDB = false
local VarHoldSEF = false
local VarSerenityBurst = false
local VarBoKNeeded = false
local VarTrinketType = (S.Serenity:IsAvailable()) and 1 or 2
local VarDungeonRoute = Player:IsInDungeonArea()
local VarSyncSerenity = (I.NeltharionsCalltoDominance:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.WitherbarksBranch:IsEquipped() or I.IrideusFragment:IsEquipped()) and not VarDungeonRoute or I.NeltharionsCalltoDominance:IsEquipped() and I.AshesoftheEmbersoul:IsEquipped()
local Stuns = {}
if S.LegSweep:IsAvailable() then tinsert(Stuns, { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end }) end
if S.RingofPeace:IsAvailable() then tinsert(Stuns, { S.RingofPeace, "Cast Ring Of Peace (Stun)", function () return true end }) end
if S.Paralysis:IsAvailable() then tinsert(Stuns, { S.Paralysis, "Cast Paralysis (Stun)", function () return true end }) end

local VarHoldTod = false
local VarFoPPreChan = 0

-- Trinkets
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Monk = HR.Commons.Monk
local Settings = {
  General     = HR.GUISettings.General,
  Commons     = HR.GUISettings.APL.Monk.Commons,
  CommonsDS   = HR.GUISettings.APL.Monk.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Monk.CommonsOGCD,
  Windwalker  = HR.GUISettings.APL.Monk.Windwalker
}

HL:RegisterForEvent(function()
  VarFoPPreChan = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  VarTrinketType = (S.Serenity:IsAvailable()) and 1 or 2
  for i = 0, #Stuns do Stuns[i] = nil end
  if S.LegSweep:IsAvailable() then tinsert(Stuns, { S.LegSweep, "Cast Leg Sweep (Stun)", function () return true end }) end
  if S.RingofPeace:IsAvailable() then tinsert(Stuns, { S.RingofPeace, "Cast Ring Of Peace (Stun)", function () return true end }) end
  if S.Paralysis:IsAvailable() then tinsert(Stuns, { S.Paralysis, "Cast Paralysis (Stun)", function () return true end }) end
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  VarDungeonRoute = Player:IsInDungeonArea()
  VarSyncSerenity = (I.NeltharionsCalltoDominance:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.WitherbarksBranch:IsEquipped() or I.IrideusFragment:IsEquipped()) and not VarDungeonRoute or I.NeltharionsCalltoDominance:IsEquipped() and I.AshesoftheEmbersoul:IsEquipped()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarDungeonRoute = Player:IsInDungeonArea()
  VarSyncSerenity = (I.NeltharionsCalltoDominance:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.WitherbarksBranch:IsEquipped()) and not VarDungeonRoute
end, "ZONE_CHANGED_NEW_AREA")

local function EnergyTimeToMaxRounded()
  -- Round to the nearesth 10th to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyTimeToMaxPredicted() * 10 + 0.5) / 10
end

local function EnergyPredictedRounded()
  -- Round to the nearesth int to reduce prediction instability on very high regen rates
  return math.floor(Player:EnergyPredicted() + 0.5)
end

local function ComboStrike(SpellObject)
  return (not Player:PrevGCD(1, SpellObject))
end

local function MotCCounter()
  if not S.MarkoftheCrane:IsAvailable() then return 0; end
  local Count = 0
  for _, CycleUnit in pairs(Enemies8y) do
    if CycleUnit:DebuffUp(S.MarkoftheCraneDebuff) then
      Count = Count + 1
    end
  end
  return Count
end

local function SCKModifier()
  if not S.MarkoftheCrane:IsAvailable() then return 0; end
  local Count = MotCCounter()
  local Mod = 1
  -- Below variable is derived from Mark of the Crane, but called cyclone_strikes in simc
  local CycloneStrikesPct = 0.18
  if Count > 0 then
    Mod = Mod * (1 + (Count * CycloneStrikesPct))
  end
  Mod = Mod * (1 + (0.1 * S.CraneVortex:TalentRank()))
  Mod = Mod * (1 + (0.3 * num(Player:BuffUp(S.KicksofFlowingMomentumBuff))))
  Mod = Mod * (1 + (0.05 * S.FastFeet:TalentRank()))
  return Mod
end

local function SCKMax()
  if not S.MarkoftheCrane:IsAvailable() then return true; end
  local Count = MotCCounter()
  if (EnemiesCount8y == Count or Count >= 5) then return true; end
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

local function FoFTarget()
  local BestUnit, BestConditionValue = nil, nil
  for _, CycleUnit in pairs(Enemies8y) do
    if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy()) and (not BestConditionValue or Utils.CompareThis("max", CycleUnit:TimeToDie(), BestConditionValue)) then
      BestUnit, BestConditionValue = CycleUnit, CycleUnit:TimeToDie()
    end
  end
  return BestUnit
end

local function EvaluateTargetIfFilterMarkoftheCrane100(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff)
end

local function EvaluateTargetIfFilterMarkoftheCrane101(TargetUnit)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff) + (num(TargetUnit:DebuffUp(S.SkyreachExhaustionDebuff)) * 20)
end

local function EvaluateTargetIfFilterMarkoftheCrane102(TargetUnit)
  -- target_if=min:debuff.mark_of_the_crane.remains+debuff.skyreach_exhaustion.up*20
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff) + (num(Target:DebuffDown(S.SkyreachExhaustionDebuff)) * 20)
end

local function EvaluateTargetIfFilterMarkoftheCrane103(TargetUnit)
  -- target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20)
  return TargetUnit:DebuffRemains(S.MarkoftheCraneDebuff) - num(SCKMax()) * (TargetUnit:TimeToDie() + TargetUnit:DebuffRemains(S.SkyreachCritDebuff) * 20)
end

local function EvaluateTargetIfFilterFaeExposure(TargetUnit)
  -- target_if=min:debuff.jadefire_brand_damage.remains
  return TargetUnit:DebuffRemains(S.JadefireBrandDebuff)
end

local function EvaluateTargetIfFilterHP(TargetUnit)
  -- target_if=max:target.time_to_die
  return TargetUnit:TimeToDie()
end

local function EvaluateTargetIfFilterSkyreach(TargetUnit)
  -- target_if=max:debuff.keefers_skyreach.remains
  return TargetUnit:DebuffRemains(S.SkyreachCritDebuff)
end

local function EvaluateTargetIfJadefireStomp(TargetUnit)
  -- if=combo_strike&talent.jadefire_harmony&debuff.jadefire_brand_damage.remains<1
  -- Note: combo_strike&talent.jadefire_harmony handled prior to this function
  return TargetUnit:DebuffRemains(S.JadefireBrandDebuff) < 1
end

local function EvaluateTargetIfRSK(TargetUnit)
  -- if=buff.pressure_point.up|debuff.skyreach_exhaustion.remains>55
  return Player:BuffUp(S.PressurePointBuff) or TargetUnit:DebuffRemains(S.SkyreachExhaustionDebuff) > 55
end

local function EvaluateTargetIfRSK2(TargetUnit)
  -- if=buff.kicks_of_flowing_momentum.up|buff.pressure_point.up|debuff.skyreach_exhaustion.remains>55
  return Player:BuffUp(S.KicksofFlowingMomentumBuff) or Player:BuffUp(S.PressurePointBuff) or TargetUnit:DebuffRemains(S.SkyreachExhaustionDebuff) > 55
end

local function EvaluateTargetIfSotWL(TargetUnit)
  -- if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains&active_enemies<10
  -- Note: Other checks handled before CastTargetIf call.
  return TargetUnit:DebuffRemains(S.SkyreachExhaustionDebuff) > Player:BuffRemains(S.CalltoDominanceBuff)
end

local function EvaluateTargetIfSotWL2(TargetUnit)
  -- if=talent.thunderfist&debuff.skyreach_exhaustion.remains>55
  -- Note: Thunderfist check handled before CastTargetIf call.
  return TargetUnit:DebuffRemains(S.SkyreachExhaustionDebuff) > 55
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- variable,name=sync_serenity,default=0,value=1,if=(equipped.neltharions_call_to_dominance|equipped.ashes_of_the_embersoul|equipped.mirror_of_fractured_tomorrows|equipped.witherbarks_branch|equipped.irideus_fragment)&!(fight_style.dungeonslice|fight_style.dungeonroute)|equipped.neltharions_call_to_dominance&equipped.ashes_of_the_embersoul
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- summon_white_tiger_statue
  if S.SummonWhiteTigerStatue:IsCastable() and CDsON() then
    if Cast(S.SummonWhiteTigerStatue, Settings.CommonsOGCD.GCDasOffGCD.SummonWhiteTigerStatue, nil, not Target:IsInRange(40)) then return "summon_white_tiger_statue precombat 2"; end
  end
  -- expel_harm,if=chi<chi.max
  if S.ExpelHarm:IsReady() and (Player:Chi() < Player:ChiMax()) then
    if Cast(S.ExpelHarm) then return "expel_harm precombat 4"; end
  end
  -- chi_burst,if=!talent.jadefire_stomp
  if S.ChiBurst:IsCastable() and (not S.JadefireStomp:IsAvailable()) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst precombat 6"; end
  end
  -- chi_wave
  if S.ChiWave:IsReady() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave precombat 8"; end
  end
end

local function Trinkets()
  -- use_item,name=manic_grieftorch,if=(trinket.1.is.manic_grieftorch&!trinket.2.has_use_buff|trinket.2.is.manic_grieftorch&!trinket.1.has_use_buff)
  if Settings.Commons.Enabled.Trinkets and I.ManicGrieftorch:IsEquippedAndReady() and (Trinket1:ID() == I.ManicGrieftorch:ID() and not Trinket2:HasUseBuff() or Trinket2:ID() == I.ManicGrieftorch:ID() and not Trinket1:HasUseBuff()) then
    if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "manic_grieftorch trinkets 2"; end
  end
  if VarTrinketType == 1 then
    if Settings.Commons.Enabled.Trinkets then
      -- algethar_puzzle_box,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&!buff.serenity.up|fight_remains<25
      if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffDown(S.SerenityBuff) or BossFightRemains < 25) then
        if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box serenity_trinkets 4"; end
      end
      -- erupting_spear_fragment,if=buff.serenity.up|(buff.invokers_delight.up&!talent.serenity)
      -- Note: Removed (buff.invokers_delight.up&!talent.serenity), as this section is only called if Serenity is available
      if I.EruptingSpearFragment:IsEquippedAndReady() and (Player:BuffUp(S.SerenityBuff)) then
        if Cast(I.EruptingSpearFragment, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment serenity_trinkets 6"; end
      end
      -- manic_grieftorch,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.serenity.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30&cooldown.serenity.remains|fight_remains<5
      if I.ManicGrieftorch:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.SerenityBuff) and not XuenActive or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and S.Serenity:CooldownDown() or BossFightRemains < 5) then
        if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "manic_grieftorch serenity_trinkets 8"; end
      end
      -- beacon_to_the_beyond,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.serenity.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30&cooldown.serenity.remains|fight_remains<10
      if I.BeacontotheBeyond:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.SerenityBuff) and not XuenActive or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and S.Serenity:CooldownDown() or BossFightRemains < 10) then
        if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond trinkets 10"; end
      end
    end
    -- djaruun_pillar_of_the_elder_flame,if=cooldown.fists_of_fury.remains<2&cooldown.invoke_xuen_the_white_tiger.remains>10|fight_remains<12
    if Settings.Commons.Enabled.Items and I.Djaruun:IsEquippedAndReady() and (S.FistsofFury:CooldownRemains() < 2 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or BossFightRemains < 12) then
      if Cast(I.Djaruun, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame serenity_trinkets 12"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- dragonfire_bomb_dispenser,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>10&cooldown.serenity.remains|fight_remains<10
      if I.DragonfireBombDispenser:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 and S.Serenity:CooldownDown() or BossFightRemains < 10) then
        if Cast(I.DragonfireBombDispenser, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser trinkets 14"; end
      end
      -- irideus_fragment,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&(buff.invokers_delight.up|cooldown.invoke_xuen_the_white_tiger.remains>45&fight_remains>180)&buff.serenity.up|fight_remains<20
      if I.IrideusFragment:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and (Player:BuffUp(S.InvokersDelightBuff) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 45 and FightRemains > 180) and Player:BuffUp(S.SerenityBuff) or BossFightRemains < 20) then
        if Cast(I.IrideusFragment, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "irideus_fragment trinkets 15"; end
      end
      local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludesSerenity, 13)
      local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludesSerenity, 14)
      -- ITEM_STAT_BUFF,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&buff.serenity.up|fight_remains<25
      if Trinket1ToUse and Trinket1ToUse:HasUseBuff() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.SerenityBuff) or BossFightRemains < 25) then
        if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (serenity_trinkets stat_buff trinket1)"; end
      end
      if Trinket2ToUse and Trinket2ToUse:HasUseBuff() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.SerenityBuff) or BossFightRemains < 25) then
        if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (serenity_trinkets stat_buff trinket2)"; end
      end
      -- ITEM_DMG_BUFF,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30&cooldown.serenity.remains
      if Trinket1ToUse and (not Trinket1ToUse:HasUseBuff() or Trinket1ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and S.Serenity:CooldownDown()) then
        if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (serenity_trinkets dmg_buff trinket1)"; end
      end
      if Trinket2ToUse and (not Trinket2ToUse:HasUseBuff() or Trinket2ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and S.Serenity:CooldownDown()) then
        if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (serenity_trinkets dmg_buff trinket2)"; end
      end
    end
  else
    if Settings.Commons.Enabled.Trinkets then
      -- algethar_puzzle_box,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&!buff.storm_earth_and_fire.up|fight_remains<25
      if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffDown(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
        if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box sef_trinkets 16"; end
      end
      -- erupting_spear_fragment,if=buff.serenity.up|(buff.invokers_delight.up&!talent.serenity)
      -- Note: Removed Serenity checks, as this section is only called if Serenity is not available
      if I.EruptingSpearFragment:IsEquippedAndReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
        if Cast(I.EruptingSpearFragment, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment sef_trinkets 18"; end
      end
      -- manic_grieftorch,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.storm_earth_and_fire.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30&!pet.xuen_the_white_tiger.active|fight_remains<5
      if I.ManicGrieftorch:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.StormEarthAndFireBuff) and not XuenActive or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and not XuenActive or BossFightRemains < 5) then
        if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "manic_grieftorch sef_trinkets 20"; end
      end
      -- beacon_to_the_beyond,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff&!buff.storm_earth_and_fire.up&!pet.xuen_the_white_tiger.active|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30&!pet.xuen_the_white_tiger.active|fight_remains<10
      if I.BeacontotheBeyond:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() and Player:BuffDown(S.StormEarthAndFireBuff) and not XuenActive or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 and not XuenActive or BossFightRemains < 10) then
        if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond sef_trinkets 22"; end
      end
    end
    -- djaruun_pillar_of_the_elder_flame,if=cooldown.fists_of_fury.remains<2&cooldown.invoke_xuen_the_white_tiger.remains>10|fight_remains<12
    if Settings.Commons.Enabled.Items and I.Djaruun:IsEquippedAndReady() and (S.FistsofFury:CooldownRemains() < 2 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or BossFightRemains < 12) then
      if Cast(I.Djaruun, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(100)) then return "djaruun_pillar_of_the_elder_flame sef_trinkets 24"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- dragonfire_bomb_dispenser,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>10|fight_remains<10
      if I.DragonfireBombDispenser:IsEquippedAndReady() and (not Trinket1:HasUseBuff() and not Trinket2:HasUseBuff() or (Trinket1:HasUseBuff() or Trinket2:HasUseBuff()) and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or BossFightRemains < 10) then
        if Cast(I.DragonfireBombDispenser, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser sef_trinkets 26"; end
      end
      local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludesSEF, 13)
      local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludesSEF, 14)
      -- ITEM_STAT_BUFF,if=(pet.xuen_the_white_tiger.active|!talent.invoke_xuen_the_white_tiger)&buff.storm_earth_and_fire.up|fight_remains<25
      if Trinket1ToUse and Trinket1ToUse:HasUseBuff() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
        if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (sef_trinkets stat_buff trinket1)"; end
      end
      if Trinket2ToUse and Trinket2ToUse:HasUseBuff() and ((XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable()) and Player:BuffUp(S.StormEarthAndFireBuff) or BossFightRemains < 25) then
        if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (sef_trinkets stat_buff trinket2)"; end
      end
      -- ITEM_DMG_BUFF,if=!trinket.1.has_use_buff&!trinket.2.has_use_buff|(trinket.1.has_use_buff|trinket.2.has_use_buff)&cooldown.invoke_xuen_the_white_tiger.remains>30
      if Trinket1ToUse and (not Trinket1ToUse:HasUseBuff() or Trinket1ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
        if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "Generic use_items for " .. Trinket1ToUse:Name() .. " (sef_trinkets dmg_buff trinket1)"; end
      end
      if Trinket2ToUse and (not Trinket2ToUse:HasUseBuff() or Trinket2ToUse:HasUseBuff() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30) then
        if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "Generic use_items for " .. Trinket2ToUse:Name() .. " (sef_trinkets dmg_buff trinket2)"; end
      end
    end
  end
end

local function Opener()
  -- summon_white_tiger_statue
  if S.SummonWhiteTigerStatue:IsCastable() and CDsON() then
    if Cast(S.SummonWhiteTigerStatue, Settings.CommonsOGCD.GCDasOffGCD.SummonWhiteTigerStatue, nil, not Target:IsInRange(40)) then return "summon_white_tiger_statue opener 2"; end
  end
  -- expel_harm,if=talent.chi_burst.enabled&chi.max-chi>=3
  if S.ExpelHarm:IsReady() and (S.ChiBurst:IsAvailable() and Player:ChiDeficit() >= 3) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm opener 4"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2&!debuff.skyreach_exhaustion.remains<2&!debuff.skyreach_exhaustion.remains
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2 and Target:DebuffDown(S.SkyreachExhaustionDebuff)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm opener 6"; end
  end
  -- expel_harm,if=talent.chi_burst.enabled&chi=3
  if S.ExpelHarm:IsReady() and (S.ChiBurst:IsAvailable() and Player:Chi() == 3) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm opener 8"; end
  end
  -- chi_wave,if=chi.max-chi=2
  if S.ChiWave:IsReady() and (Player:ChiDeficit() >= 2) then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave opener 10"; end
  end
  -- expel_harm
  if S.ExpelHarm:IsReady() then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm opener 12"; end
  end
  -- chi_burst,if=chi>1&chi.max-chi>=2
  if S.ChiBurst:IsCastable() and (Player:Chi() > 1 and Player:ChiDeficit() >= 2) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst opener 14"; end
  end
end

local function BDBSetup()
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&active_enemies>3
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and EnemiesCount8y > 3) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord bdb_setup 2"; end
  end
  -- bonedust_brew,if=spinning_crane_kick.max&chi>=4
  if S.BonedustBrew:IsCastable() and (SCKMax() and Player:Chi() >= 4) then
    if Cast(S.BonedustBrew, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew bdb_setup 4"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi.max-chi>=2&buff.storm_earth_and_fire.up
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= 2 and Player:BuffUp(S.StormEarthAndFireBuff)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm bdb_setup 6"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&!talent.whirling_dragon_punch&!spinning_crane_kick.max
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and not S.WhirlingDragonPunch:IsAvailable() and not SCKMax()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick bdb_setup 8"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&chi>=5&talent.whirling_dragon_punch
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick) and Player:Chi() >= 5 and S.WhirlingDragonPunch:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick bdb_setup 10"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&active_enemies>=2&talent.whirling_dragon_punch
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick) and EnemiesCount8y >= 2 and S.WhirlingDragonPunch:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick bdb_setup 12"; end
  end
end

local function CDSEF()
  -- invoke_external_buff,name=power_infusion,if=pet.xuen_the_white_tiger.active
  -- Note: Not handling external buffs.
  -- invoke_xuen_the_white_tiger,target_if=max:target.health,if=(target.time_to_die>35&fight_style.dungeonroute|target.time_to_die>14&!fight_style.dungeonroute)&fight_remains>120&(!trinket.1.is.ashes_of_the_embersoul&!trinket.1.is.witherbarks_branch&!trinket.2.is.ashes_of_the_embersoul&!trinket.2.is.witherbarks_branch|(trinket.1.is.ashes_of_the_embersoul|trinket.1.is.witherbarks_branch)&!trinket.1.cooldown.remains|(trinket.2.is.ashes_of_the_embersoul|trinket.2.is.witherbarks_branch)&!trinket.2.cooldown.remains)
  -- Note: Ignoring target_if condition.
  if S.InvokeXuenTheWhiteTiger:IsCastable() and ((Target:TimeToDie() > 35 and VarDungeonRoute or Target:TimeToDie() > 14 and not VarDungeonRoute) and FightRemains > 120 and (Trinket1:ID() ~= I.AshesoftheEmbersoul:ID() and Trinket1:ID() ~= I.WitherbarksBranch:ID() and Trinket2:ID() ~= I.AshesoftheEmbersoul:ID() and Trinket2:ID() ~= I.WitherbarksBranch:ID() or (Trinket1:ID() == I.AshesoftheEmbersoul:ID() or Trinket1:ID() == I.WitherbarksBranch:ID()) and not (Trinket1:CooldownRemains() > 0) or (Trinket2:ID() == I.AshesoftheEmbersoul:ID() or Trinket2:ID() == I.WitherbarksBranch:ID()) and not (Trinket2:CooldownRemains() > 0))) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_sef 2"; end
  end
  -- invoke_xuen_the_white_tiger,if=fight_remains<60&(debuff.skyreach_exhaustion.remains<2|debuff.skyreach_exhaustion.remains>55)&!cooldown.serenity.remains&active_enemies<3|fight_remains<25
  -- Note: Ignoring Serenity check, as player can't have SEF and Serenity simultaneously.
  if S.InvokeXuenTheWhiteTiger:IsCastable() and (FightRemains < 60 and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 2 or Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55) and EnemiesCount8y < 3 or BossFightRemains < 25) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_sef 4"; end
  end
  -- storm_earth_and_fire,if=(pet.xuen_the_white_tiger.active|target.time_to_die>15&cooldown.storm_earth_and_fire.full_recharge_time<cooldown.invoke_xuen_the_white_tiger.remains)
  if S.StormEarthAndFire:IsCastable() and (XuenActive or Target:TimeToDie() > 15 and S.StormEarthAndFire:FullRechargeTime() < S.InvokeXuenTheWhiteTiger:CooldownRemains()) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cd_sef 6"; end
  end
  -- bonedust_brew,if=cooldown.invoke_xuen_the_white_tiger.remains>45&(!buff.bonedust_brew.up&buff.storm_earth_and_fire.up&buff.storm_earth_and_fire.remains<11&spinning_crane_kick.max)|(!buff.bonedust_brew.up&fight_remains<30&fight_remains>10&spinning_crane_kick.max&chi>=4)|fight_remains<10|(!debuff.skyreach_exhaustion.up&active_enemies>=4&spinning_crane_kick.modifier>=2)|(pet.xuen_the_white_tiger.active&spinning_crane_kick.max&active_enemies>=4|fight_remains<15|cooldown.invoke_xuen_the_white_tiger.remains>45&(debuff.skyreach_exhaustion.remains>55|debuff.skyreach_exhaustion.remains<2)|cooldown.invoke_xuen_the_white_tiger.remains>45&target.time_to_die>10)
  if S.BonedustBrew:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 45 and (Player:BuffDown(S.BonedustBrewBuff) and Player:BuffUp(S.StormEarthAndFireBuff) and Player:BuffRemains(S.StormEarthAndFireBuff) < 11 and SCKMax()) or (Player:BuffDown(S.BonedustBrewBuff) and FightRemains < 30 and FightRemains > 10 and SCKMax() and Player:Chi() >= 4) or BossFightRemains < 10 or (Target:DebuffDown(S.SkyreachExhaustionDebuff) and EnemiesCount8y >= 4 and SCKModifier() >= 2) or (XuenActive and SCKMax() and EnemiesCount8y >= 4 or BossFightRemains < 15 or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 45 and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55 or Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 2) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 45 and Target:TimeToDie() > 10)) then
    if Cast(S.BonedustBrew, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew cd_sef 8"; end
  end
  -- call_action_list,name=bdb_setup,if=!buff.bonedust_brew.up&talent.bonedust_brew&cooldown.bonedust_brew.remains<=2&(fight_remains>60&(cooldown.storm_earth_and_fire.charges>0|cooldown.storm_earth_and_fire.remains>10)&(pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>10|variable.hold_xuen)|((pet.xuen_the_white_tiger.active|cooldown.invoke_xuen_the_white_tiger.remains>13)&(cooldown.storm_earth_and_fire.charges>0|cooldown.storm_earth_and_fire.remains>13|buff.storm_earth_and_fire.up)))
  if (Player:BuffDown(S.BonedustBrewBuff) and S.BonedustBrew:IsAvailable() and S.BonedustBrew:CooldownRemains() <= 2 and (FightRemains > 60 and (S.StormEarthAndFire:Charges() > 0 or S.StormEarthAndFire:CooldownRemains() > 10) and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 10 or VarHoldXuen) or ((XuenActive or S.InvokeXuenTheWhiteTiger:CooldownRemains() > 13) and (S.StormEarthAndFire:Charges() > 0 or S.StormEarthAndFire:CooldownRemains() > 13 or Player:BuffUp(S.StormEarthAndFireBuff))))) then
    local ShouldReturn = BDBSetup(); if ShouldReturn then return ShouldReturn; end
  end
  -- storm_earth_and_fire,if=fight_remains<20|(cooldown.storm_earth_and_fire.charges=2&cooldown.invoke_xuen_the_white_tiger.remains>cooldown.storm_earth_and_fire.full_recharge_time)&cooldown.fists_of_fury.remains<=9&chi>=2&cooldown.whirling_dragon_punch.remains<=12
  if S.StormEarthAndFire:IsCastable() and (BossFightRemains < 20 or (S.StormEarthAndFire:Charges() == 2 and S.InvokeXuenTheWhiteTiger:CooldownRemains() > S.StormEarthAndFire:FullRechargeTime()) and S.FistsofFury:CooldownRemains() <= 9 and Player:Chi() >= 2 and S.WhirlingDragonPunch:CooldownRemains() <= 12) then
    if Cast(S.StormEarthAndFire, Settings.Windwalker.OffGCDasOffGCD.StormEarthAndFire) then return "storm_earth_and_fire cd_sef 10"; end
  end
  -- Touch of Death handling
  if S.TouchofDeath:CooldownUp() then
    local ToDTar = nil
    if AoEON() then
      -- ToDTarget() checks all targets within Enemies5y to see which are valid targets for ToD and returns the one with the highest HP.
      ToDTar = ToDTarget()
    else
      if S.TouchofDeath:IsReady() then
        ToDTar = Target
      end
    end
    if ToDTar then
      -- touch_of_death,target_if=max:target.health,if=fight_style.dungeonroute&!buff.serenity.up&(combo_strike&target.health<health)|(buff.hidden_masters_forbidden_touch.remains<2)|(buff.hidden_masters_forbidden_touch.remains>target.time_to_die)
      if VarDungeonRoute and Player:BuffDown(S.SerenityBuff) and ComboStrike(S.TouchofDeath) and ToDTar:Health() < Player:Health() or Player:BuffRemains(S.HiddenMastersForbiddenTouchBuff) < 2 or Player:BuffRemains(S.HiddenMastersForbiddenTouchBuff) > ToDTar:TimeToDie() then
        if ToDTar:GUID() == Target:GUID() then
          if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 12"; end
        else
          if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 12"; end
        end
      end
    end
    if ToDTar and ComboStrike(S.TouchofDeath) then
      if VarDungeonRoute then
        -- touch_of_death,cycle_targets=1,if=fight_style.dungeonroute&combo_strike&(target.time_to_die>60|debuff.bonedust_brew_debuff.up|fight_remains<10)
        if ToDTar:TimeToDie() > 60 or ToDTar:DebuffUp(S.BonedustBrewDebuff) or BossFightRemains < 10 then
          if ToDTar:GUID() == Target:GUID() then
            if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 14"; end
          else
            if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 14"; end
          end
        end
      else
        -- touch_of_death,cycle_targets=1,if=!fight_style.dungeonroute&combo_strike
        if ToDTar:GUID() == Target:GUID() then
          if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 16"; end
        else
          if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 16"; end
        end
      end
    end
  end
  -- With Xuen: touch_of_karma,target_if=max:target.time_to_die,if=fight_remains>90|pet.xuen_the_white_tiger.active|variable.hold_xuen|fight_remains<16
  -- Without Xuen: touch_of_karma,if=fight_remains>159|variable.hold_xuen
  if S.TouchofKarma:IsCastable() and not Settings.Windwalker.IgnoreToK and ((S.InvokeXuenTheWhiteTiger:IsAvailable() and (FightRemains > 90 or XuenActive or VarHoldXuen or BossFightRemains < 16)) or (not S.InvokeXuenTheWhiteTiger:IsAvailable() and (FightRemains > 159 or VarHoldXuen))) then
    if Cast(S.TouchofKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma, nil, not Target:IsInRange(20)) then return "touch_of_karma cd_sef 18"; end
  end
  -- ancestral_call,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.AncestralCall:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarHoldXuen or BossFightRemains < 20) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cd_sef 20"; end
  end
  -- blood_fury,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<20
  if S.BloodFury:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarHoldXuen or BossFightRemains < 20) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cd_sef 22"; end
  end
  -- fireblood,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<10
  if S.Fireblood:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarHoldXuen or BossFightRemains < 10) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cd_sef 24"; end
  end
  -- berserking,if=cooldown.invoke_xuen_the_white_tiger.remains>30|variable.hold_xuen|fight_remains<15
  if S.Berserking:IsCastable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 30 or VarHoldXuen or BossFightRemains < 15) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cd_sef 26"; end
  end
  -- bag_of_tricks,if=buff.storm_earth_and_fire.down
  if S.BagofTricks:IsCastable() and (Player:BuffDown(S.StormEarthAndFireBuff)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cd_sef 28"; end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "lights_judgment cd_sef 30"; end
  end
end

local function CDSerenity()
  -- invoke_external_buff,name=power_infusion,if=pet.xuen_the_white_tiger.active
  -- Note: Not handling external buffs.
  -- invoke_xuen_the_white_tiger,if=buff.bloodlust.up|fight_remains<25
  if S.InvokeXuenTheWhiteTiger:IsCastable() and (Player:BloodlustUp() or BossFightRemains < 25) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_serenity 2"; end
  end
  -- invoke_xuen_the_white_tiger,if=(target.time_to_die>16|(fight_style.dungeonslice|fight_style.dungeonroute)&cooldown.serenity.remains<2)&fight_remains>120&(!trinket.1.is.ashes_of_the_embersoul&!trinket.1.is.witherbarks_branch&!trinket.2.is.ashes_of_the_embersoul&!trinket.2.is.witherbarks_branch|(trinket.1.is.ashes_of_the_embersoul|trinket.1.is.witherbarks_branch)&!trinket.1.cooldown.remains|(trinket.2.is.ashes_of_the_embersoul|trinket.2.is.witherbarks_branch)&!trinket.2.cooldown.remains)&target.time_to_die>14
  if S.InvokeXuenTheWhiteTiger:IsCastable() and ((Target:TimeToDie() > 16 or VarDungeonRoute and S.Serenity:CooldownRemains() < 2) and FightRemains > 120 and (Trinket1:ID() ~= I.AshesoftheEmbersoul:ID() and Trinket1:ID() ~= I.WitherbarksBranch:ID() and Trinket2:ID() ~= I.AshesoftheEmbersoul:ID() and Trinket2:ID() ~= I.WitherbarksBranch:ID() or (Trinket1:ID() == I.AshesoftheEmbersoul:ID() or Trinket1:ID() == I.WitherbarksBranch:ID()) and not (Trinket1:CooldownRemains() > 0) or (Trinket2:ID() == I.AshesoftheEmbersoul:ID() or Trinket2:ID() == I.WitherbarksBranch:ID()) and not (Trinket2:CooldownRemains() > 0)) and Target:TimeToDie() > 14) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_serenity 4"; end
  end
  -- invoke_xuen_the_white_tiger,if=target.time_to_die>16&fight_remains<60&(debuff.skyreach_exhaustion.remains<2|debuff.skyreach_exhaustion.remains>55)&!cooldown.serenity.remains&active_enemies<3
  if S.InvokeXuenTheWhiteTiger:IsCastable() and (Target:TimeToDie() > 16 and FightRemains < 60 and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 2 or Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55) and S.Serenity:CooldownUp() and EnemiesCount8y < 3) then
    if Cast(S.InvokeXuenTheWhiteTiger, Settings.Windwalker.GCDasOffGCD.InvokeXuenTheWhiteTiger, nil, not Target:IsInRange(40)) then return "invoke_xuen_the_white_tiger cd_serenity 6"; end
  end
  -- bonedust_brew,if=buff.invokers_delight.up|!buff.bonedust_brew.up&cooldown.xuen_the_white_tiger.remains&!pet.xuen_the_white_tiger.active|cooldown.serenity.remains>15|fight_remains<30&fight_remains>10|fight_remains<10
  if S.BonedustBrew:IsCastable() and (Player:BuffUp(S.InvokersDelightBuff) or Player:BuffDown(S.BonedustBrewBuff) and S.InvokeXuenTheWhiteTiger:CooldownDown() and not XuenActive or S.Serenity:CooldownRemains() > 15 or FightRemains < 30 and FightRemains > 10 or BossFightRemains < 10) then
    if Cast(S.BonedustBrew, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew cd_serenity 10"; end
  end
  -- serenity,if=variable.sync_serenity&(buff.invokers_delight.up|variable.hold_xuen&(talent.drinking_horn_cover&fight_remains>110|!talent.drinking_horn_cover&fight_remains>105))|!talent.invoke_xuen_the_white_tiger|fight_remains<15
  if S.Serenity:IsCastable() and (VarSyncSerenity and (Player:BuffUp(S.InvokersDelightBuff) or VarHoldXuen and (S.DrinkingHornCover:IsAvailable() and FightRemains > 110 or not S.DrinkingHornCover:IsAvailable() and FightRemains > 105)) or not S.InvokeXuenTheWhiteTiger:IsAvailable() or BossFightRemains < 15) then
    if Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "serenity cd_serenity 12"; end
  end
  -- serenity,if=!variable.sync_serenity&(buff.invokers_delight.up|cooldown.invoke_xuen_the_white_tiger.remains>fight_remains|fight_remains>(cooldown.invoke_xuen_the_white_tiger.remains+10)&fight_remains>90)
  if S.Serenity:IsCastable() and (not VarSyncSerenity and (Player:BuffUp(S.InvokersDelightBuff) or S.InvokeXuenTheWhiteTiger:CooldownRemains() > FightRemains or FightRemains > (S.InvokeXuenTheWhiteTiger:CooldownRemains() + 10) and FightRemains > 90)) then
    if Cast(S.Serenity, Settings.Windwalker.OffGCDasOffGCD.Serenity) then return "serenity cd_serenity 14"; end
  end
  -- Touch of Death handling
  if S.TouchofDeath:CooldownUp() then
    local ToDTar = nil
    if AoEON() then
      -- ToDTarget() checks all targets within Enemies5y to see which are valid targets for ToD and returns the one with the highest HP.
      ToDTar = ToDTarget()
    else
      if S.TouchofDeath:IsReady() then
        ToDTar = Target
      end
    end
    if ToDTar then
      -- touch_of_death,target_if=max:target.health,if=fight_style.dungeonroute&!buff.serenity.up&(combo_strike&target.health<health)|(buff.hidden_masters_forbidden_touch.remains<2)|(buff.hidden_masters_forbidden_touch.remains>target.time_to_die)
      if VarDungeonRoute and Player:BuffDown(S.SerenityBuff) and ComboStrike(S.TouchofDeath) and ToDTar:Health() < Player:Health() or Player:BuffRemains(S.HiddenMastersForbiddenTouchBuff) < 2 or Player:BuffRemains(S.HiddenMastersForbiddenTouchBuff) > ToDTar:TimeToDie() then
        if ToDTar:GUID() == Target:GUID() then
          if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 16"; end
        else
          if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 16"; end
        end
      end
    end
    if ToDTar and ComboStrike(S.TouchofDeath) then
      if VarDungeonRoute then
        -- touch_of_death,cycle_targets=1,if=fight_style.dungeonroute&combo_strike&(target.time_to_die>60|debuff.bonedust_brew_debuff.up|fight_remains<10)&!buff.serenity.up
        if (ToDTar:TimeToDie() > 60 or ToDTar:DebuffUp(S.BonedustBrewDebuff) or BossFightRemains < 10) and Player:BuffDown(S.SerenityBuff) then
          if ToDTar:GUID() == Target:GUID() then
            if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 18"; end
          else
            if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 18"; end
          end
        end
      else
        -- touch_of_death,cycle_targets=1,if=!fight_style.dungeonroute&combo_strike&!buff.serenity.up
        if Player:BuffDown(S.SerenityBuff) then
          if ToDTar:GUID() == Target:GUID() then
            if Cast(S.TouchofDeath, Settings.Windwalker.GCDasOffGCD.TouchOfDeath, nil, not Target:IsInMeleeRange(5)) then return "touch_of_death cd_sef main-target 20"; end
          else
            if HR.CastLeftNameplate(ToDTar, S.TouchofDeath) then return "touch_of_death cd_sef off-target 20"; end
          end
        end
      end
    end
  end
  -- touch_of_karma,if=fight_remains>90|fight_remains<10
  if not Settings.Windwalker.IgnoreToK and S.TouchofKarma:IsCastable() and (FightRemains > 90 or BossFightRemains < 10) then
    if Cast(S.TouchofKarma, Settings.Windwalker.GCDasOffGCD.TouchOfKarma) then return "touch_of_karma cd_serenity 22"; end
  end
  if (Player:BuffUp(S.SerenityBuff) or BossFightRemains < 20) then
    -- ancestral_call,if=buff.serenity.up|fight_remains<20
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cd_serenity 24"; end
    end
    -- blood_fury,if=buff.serenity.up|fight_remains<20
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cd_serenity 26"; end
    end
    -- fireblood,if=buff.serenity.up|fight_remains<20
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cd_serenity 28"; end
    end
    -- berserking,if=buff.serenity.up|fight_remains<20
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cd_serenity 30"; end
    end
    -- bag_of_tricks,if=buff.serenity.up|fight_remains<20
    if S.BagofTricks:IsCastable() then
      if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "bag_of_tricks cd_serenity 32"; end
    end
  end
  -- lights_judgment
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "lights_judgment cd_serenity 34"; end
  end
end

local function SerenityAoELust()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<1
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 1) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_aoelust 2"; end
  end
  -- strike_of_the_windlord,if=set_bonus.tier31_4pc&talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (Player:HasTier(31, 4) and S.Thunderfist:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoelust 4"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 6"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=talent.jade_ignition,interrupt_if=buff.chi_energy.stack=30
  if Player:IsChanneling(S.FistsofFury) and Player:BuffStack(S.ChiEnergyBuff) == 30 then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_aoelust 8"; end
  end
  if S.FistsofFury:IsReady() and (S.JadeIgnition:IsAvailable()) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoelust 10"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc&buff.bonedust_brew.up&active_enemies>4
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and Player:BuffUp(S.BonedustBrewBuff) and EnemiesCount8y > 4) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 12"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&!buff.blackout_reinforcement.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 14"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up&set_bonus.tier31_2pc&(active_enemies>5&buff.transfer_the_power.stack>5|active_enemies>6|active_enemies>4&!talent.crane_vortex&buff.transfer_the_power.stack>5),interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff) and Player:HasTier(31, 2) and (EnemiesCount8y > 5 and Player:BuffStack(S.TransferthePowerBuff) > 5 or EnemiesCount8y > 6 or EnemiesCount8y > 4 and not S.CraneVortex:IsAvailable() and Player:BuffStack(S.TransferthePowerBuff) > 5)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoelust 16"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=!set_bonus.tier30_2pc&!buff.invokers_delight.up&set_bonus.tier31_2pc&(!buff.bonedust_brew.up|active_enemies>10)&(buff.transfer_the_power.stack=10&!talent.crane_vortex|active_enemies>5&talent.crane_vortex&buff.transfer_the_power.stack=10|active_enemies>14|active_enemies>12&!talent.crane_vortex),interrupt=1
  if S.FistsofFury:IsReady() and (not Player:HasTier(30, 2) and Player:BuffDown(S.InvokersDelightBuff) and Player:HasTier(31, 2) and (Player:BuffDown(S.BonedustBrewBuff) or EnemiesCount8y > 10) and (Player:BuffStack(S.TransferthePowerBuff) == 10 and not S.CraneVortex:IsAvailable() or EnemiesCount8y > 5 and S.CraneVortex:IsAvailable() and Player:BuffStack(S.TransferthePowerBuff) == 10 or EnemiesCount8y > 14 or EnemiesCount8y > 12 and not S.CraneVortex:IsAvailable())) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoelust 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&!spinning_crane_kick.max&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and not SCKMax() and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 20"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 22"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 24"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up&prev.blackout_kick&buff.dance_of_chiji.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.BlackoutKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 26"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (Player:HasTier(31, 2) and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 28"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&!buff.blackout_reinforcement.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 30"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=active_enemies<6&combo_strike&set_bonus.tier31_2pc
  if S.BlackoutKick:IsReady() and (EnemiesCount8y < 6 and ComboStrike(S.BlackoutKick) and Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 32"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  -- Note: Ignoring the first line, as the second covers it...
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_aoelust 34"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains&active_enemies<10
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff) and EnemiesCount8y < 10) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL, not Target:IsInMeleeRange(8)) then return "strike_of_the_windlord serenity_aoelust 36"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_aoelust 38"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "strike_of_the_windlord serenity_aoelust 40"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoelust 42"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains
  if Player:IsChanneling(S.FistsofFury) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_aoelust 44"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 46"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=active_enemies<6&combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (EnemiesCount8y < 6 and ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 48"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 50"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!debuff.skyreach_exhaustion.up*20&combo_strike&active_enemies=5
  -- Note: I believe the '!debuff.skyreach_exhaustion.up*20' is supposed to be part of the target_if clause, as it makes no sense in the if clause.
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and EnemiesCount8y == 5) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane102, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_aoelust 52"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity_aoelust 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&active_enemies>=3&combo_strike
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and EnemiesCount8y >= 3 and ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 56"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoelust 58"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoelust 60"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_aoelust 62"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity_aoelust 64"; end
  end
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoelust 66"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_aoelust 68"; end
  end
end

local function SerenityLust()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<1
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 1) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_lust 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.serenity.remains<1.5&combo_strike&!buff.blackout_reinforcement.remains&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffRemains(S.SerenityBuff) < 1.5 and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 4"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_lust 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc&active_enemies>2
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and EnemiesCount8y > 2) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 8"; end
  end
  -- rising_sun_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike&buff.kicks_of_flowing_momentum.up&active_enemies=1
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick) and Player:BuffUp(S.KicksofFlowingMomentumBuff) and EnemiesCount8y == 1) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_lust 9"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=debuff.skyreach_exhaustion.remains>55&set_bonus.tier29_4pc&active_enemies=1,interrupt=1
  if S.FistsofFury:IsReady() and (Player:HasTier(29, 4) and EnemiesCount8y == 1) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL2, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_lust 10"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_lust 11"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.blackout_reinforcement.up&active_enemies>2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and EnemiesCount8y > 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_lust 12"; end
  end
  -- rising_sun_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike&(active_enemies<3|!set_bonus.tier31_2pc)
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick) and (EnemiesCount8y < 3 or not Player:HasTier(31, 2))) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_lust 14"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.blackout_reinforcement.up&prev.fists_of_fury&talent.shadowboxing_treads&set_bonus.tier31_2pc&!talent.dance_of_chiji
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.FistsofFury) and S.ShadowboxingTreads:IsAvailable() and Player:HasTier(31, 2) and not S.DanceofChiji:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_lust 16"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&prev.fists_of_fury&debuff.skyreach_exhaustion.remains>55&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.FistsofFury) and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55 and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 18"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up&(active_enemies<3|!set_bonus.tier31_2pc),interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff) and (EnemiesCount8y < 3 or not Player:HasTier(31, 2))) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_lust 20"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max&!buff.blackout_reinforcement.up&active_enemies>2&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff) and EnemiesCount8y > 2 and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 22"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max&buff.blackout_reinforcement.up&active_enemies>2&prev.blackout_kick&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax() and Player:BuffUp(S.BlackoutReinforcementBuff) and EnemiesCount8y > 2 and Player:PrevGCD(1, S.BlackoutKick) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 24"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max&buff.bonedust_brew.up&active_enemies>2&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax() and Player:BuffUp(S.BonedustBrewBuff) and EnemiesCount8y > 2 and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 26"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains,if=active_enemies<3|!set_bonus.tier31_2pc
  if Player:IsChanneling(S.FistsofFury) and (EnemiesCount8y < 3 or not Player:HasTier(31, 2)) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_lust 28"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&buff.bonedust_brew.up&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:BuffUp(S.BonedustBrewBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 32"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_lust 34"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_lust 36"; end
  end
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_lust 38"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_lust 40"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_lust 42"; end
  end
end

local function SerenityAoE()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<1
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 1) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_aoe 2"; end
  end
  -- strike_of_the_windlord,if=set_bonus.tier31_4pc&talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (Player:HasTier(31, 4) and S.Thunderfist:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoe 4"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&set_bonus.tier31_2pc
  -- Note: Skipping target_if condition.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc&buff.bonedust_brew.up&active_enemies>4
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and Player:BuffUp(S.BonedustBrewBuff) and EnemiesCount8y > 4) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 8"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=talent.jade_ignition,interrupt_if=buff.chi_energy.stack=30
  if Player:IsChanneling(S.FistsofFury) and Player:BuffStack(S.ChiEnergyBuff) == 30 then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_aoe 10"; end
  end
  if S.FistsofFury:IsReady() and (S.JadeIgnition:IsAvailable()) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoe 12"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 14"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up&set_bonus.tier31_2pc&(!buff.bonedust_brew.up|active_enemies>10)&(buff.transfer_the_power.stack=10&!talent.crane_vortex|active_enemies>5&talent.crane_vortex&buff.transfer_the_power.stack=10|active_enemies>14|active_enemies>12&!talent.crane_vortex),interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff) and Player:HasTier(31, 2) and (Player:BuffDown(S.BonedustBrewBuff) or EnemiesCount8y > 10) and (Player:BuffStack(S.TransferthePowerBuff) == 10 and not S.CraneVortex:IsAvailable() or EnemiesCount8y > 5 and S.CraneVortex:IsAvailable() and Player:BuffStack(S.TransferthePowerBuff) == 10 or EnemiesCount8y > 14 or EnemiesCount8y > 12 and not S.CraneVortex:IsAvailable())) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoe 16"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains,if=!set_bonus.tier30_2pc&set_bonus.tier31_2pc&(!buff.bonedust_brew.up|active_enemies>10)&(buff.transfer_the_power.stack=10&!talent.crane_vortex|active_enemies>5&talent.crane_vortex&buff.transfer_the_power.stack=10|active_enemies>14|active_enemies>12&!talent.crane_vortex)&!buff.bonedust_brew.up|buff.fury_of_xuen_stacks.stack>90
  if not Player:HasTier(30, 2) and Player:HasTier(31, 2) and (Player:BuffDown(S.BonedustBrewBuff) or EnemiesCount8y > 10) and (Player:BuffStack(S.TransferthePowerBuff) == 10 and not S.CraneVortex:IsAvailable() or EnemiesCount8y > 5 and S.CraneVortex:IsAvailable() and Player:BuffStack(S.TransferthePowerBuff) == 10 or EnemiesCount8y > 14 or EnemiesCount8y > 12 and not S.CraneVortex:IsAvailable()) and Player:BuffDown(S.BonedustBrewBuff) or Player:BuffStack(S.FuryofXuenBuff) > 90 then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_aoe 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&!spinning_crane_kick.max&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and not SCKMax() and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 20"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 22"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&ombo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 24"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up&prev.blackout_kick&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.BlackoutKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 26"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (Player:HasTier(31, 2) and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 28"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up&prev.blackout_kick
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.BlackoutKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 30"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_aoe 32"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_aoe 34"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains&active_enemies<10
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff) and EnemiesCount8y < 10) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoe 36"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_aoe 38"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_aoe 40"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains
  if Player:IsChanneling(S.FistsofFury) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_aoe 42"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoe 44"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 46"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=active_enemies<6&combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (EnemiesCount8y < 6 and ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 48"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 50"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!debuff.skyreach_exhaustion.up*20&combo_strike&active_enemies=5
  -- Note: I believe the '!debuff.skyreach_exhaustion.up*20' is supposed to be part of the target_if clause, as it makes no sense in the if clause.
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and EnemiesCount8y == 5) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane102, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_aoe 52"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity_aoe 54"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&active_enemies>=3&combo_strike
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and EnemiesCount8y >= 3 and ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 56"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_aoe 58"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_aoe 60"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_aoe 62"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  -- Note: Already covered 5 lines higher. No need to add it again.
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_aoe 64"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_aoe 66"; end
  end
end

local function Serenity4T()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<1
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 1) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_4t 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.serenity.remains<1.5&combo_strike&!buff.blackout_reinforcement.remains&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffRemains(S.SerenityBuff) < 1.5 and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 4"; end
  end
  -- strike_of_the_windlord,if=set_bonus.tier31_4pc&talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (Player:HasTier(31, 4) and S.Thunderfist:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_4t 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 8"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains,if=!set_bonus.tier30_2pc&buff.fury_of_xuen_stacks.stack>90
  if Player:IsChanneling(S.FistsofFury) and (not Player:HasTier(30, 2) and Player:BuffStack(S.FuryofXuenBuff) > 90) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_4t 10"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&set_bonus.tier31_2pc&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:HasTier(31, 2) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 12"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_4t 14"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (Player:HasTier(31, 2) and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_4t 16"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&!buff.blackout_reinforcement.up&talent.crane_vortex
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and S.CraneVortex:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 18"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&!talent.bonedust_brew
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and not S.BonedustBrew:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_4t 20"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up&set_bonus.tier31_2pc&buff.transfer_the_power.stack>5&!talent.crane_vortex&buff.bloodlust.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff) and Player:HasTier(31, 2) and Player:BuffStack(S.TransferthePowerBuff) > 5 and not S.CraneVortex:IsAvailable() and Player:BloodlustUp()) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_4t 22"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_4t 24"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_4t 26"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&set_bonus.tier31_2pc&combo_strike&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:HasTier(31, 2) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 28"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_4t 30"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_4t 32"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_4t 34"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains
  if Player:IsChanneling(S.FistsofFury) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_4t 36"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_4t 38"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 40"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_4t 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_4t 44"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 46"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_4t 48"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_4t 50"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_4t 52"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_4t 54"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity_4t 56"; end
  end
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_4t 58"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_4t 60"; end
  end
end

local function Serenity3T()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<1
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 1) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_3t 2"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier31_2pc&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (Player:HasTier(31, 2) and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 4"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!debuff.skyreach_exhaustion.up*20&combo_strike
  -- Note: I believe the '!debuff.skyreach_exhaustion.up*20' is supposed to be part of the target_if clause, as it makes no sense in the if clause.
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane102, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_3t 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&spinning_crane_kick.max&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 8"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_3t 10"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&debuff.skyreach_exhaustion.remains>55
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL2, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_3t 12"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 14"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up&!set_bonus.tier31_2pc,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff) and not Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_3t 16"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains,if=!set_bonus.tier31_2pc|buff.fury_of_xuen_stacks.stack>90
  if Player:IsChanneling(S.FistsofFury) and (not Player:HasTier(31, 2) or Player:BuffStack(S.FuryofXuenBuff) > 90) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_3t 18"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc&talent.crane_vortex
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and S.CraneVortex:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 20"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&spinning_crane_kick.max&buff.blackout_reinforcement.up&set_bonus.tier31_2pc&prev.blackout_kick&talent.crane_vortex
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and SCKMax() and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and Player:PrevGCD(1, S.BlackoutKick) and S.CraneVortex:IsAvailable()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 22"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&!buff.pressure_point.up
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffDown(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 24"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_3t 26"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_3t 28"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_3t 30"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_3t 32"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_3t 34"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&spinning_crane_kick.max&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 38"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 40"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 44"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_3t 46"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_3t 47"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_3t 48"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity_3t 50"; end
  end
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_3t 52"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_3t 54"; end
  end
end

local function Serenity2T()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2&!debuff.skyreach_exhaustion.remains<2&!debuff.skyreach_exhaustion.remains
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2 and not (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 2) and Target:DebuffDown(S.SkyreachExhaustionDebuff)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_2t 2"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=!debuff.skyreach_exhaustion.up*20&combo_strike
  -- Note: I believe the '!debuff.skyreach_exhaustion.up*20' is supposed to be part of the target_if clause, as it makes no sense in the if clause.
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm)) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane102, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_2t 4"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&prev.fists_of_fury&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.FistsofFury) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_2t 8"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up|debuff.skyreach_exhaustion.remains>55
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, EvaluateTargetIfRSK, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_2t 10"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_2t 12"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_2t 14"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_2t 16"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&debuff.skyreach_exhaustion.remains>55
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, EvaluateTargetIfSotWL2, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_2t 18"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 20"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_2t 22"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=buff.invokers_delight.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_2t 24"; end
  end
  -- fists_of_fury_cancel,target_if=max:debuff.keefers_skyreach.remains
  if Player:IsChanneling(S.FistsofFury) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_2t 26"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_2t 28"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_2t 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_2t 32"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 34"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.teachings_of_the_monastery.stack=2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 36"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=cooldown.fists_of_fury.remains>5&talent.shadowboxing_treads&buff.teachings_of_the_monastery.stack=1&combo_strike
  -- Note: Moved combo_strike to front of checks.
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownRemains() > 5 and S.ShadowboxingTreads:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 38"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_2t 40"; end
  end
  -- blackout_kick,target_if=max:debuff.keefers_skyreach.remains,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_2t 42"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_2t 44"; end
  end
end

local function SerenityST()
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2&!debuff.skyreach_exhaustion.remains
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2 and Target:DebuffDown(S.SkyreachExhaustionDebuff)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_st 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.serenity.remains<1.5&combo_strike&!buff.blackout_reinforcement.remains&set_bonus.tier31_4pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffRemains(S.SerenityBuff) < 1.5 and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 4)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 4"; end
  end
  -- tiger_palm,if=!debuff.skyreach_exhaustion.up*20&combo_strike
  if S.TigerPalm:IsReady() and (Target:DebuffDown(S.SkyreachExhaustionDebuff) and ComboStrike(S.TigerPalm)) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_st 6"; end
  end
  -- blackout_kick,if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_st 8"; end
  end
  -- strike_of_the_windlord,if=talent.thunderfist&set_bonus.tier31_4pc
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:HasTier(31, 4)) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_st 10"; end
  end
  -- rising_sun_kick,if=combo_strike
  if S.RisingSunKick:IsReady() and (ComboStrike(S.RisingSunKick)) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity_st 12"; end
  end
  -- jadefire_stomp,if=debuff.jadefire_brand_damage.remains<2
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.JadefireBrandDebuff) < 2) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp serenity_st 14"; end
  end
  -- strike_of_the_windlord,if=talent.thunderfist&buff.call_to_dominance.up&debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:BuffUp(S.CalltoDominanceBuff) and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > Player:BuffRemains(S.CalltoDominanceBuff)) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_st 16"; end
  end
  -- strike_of_the_windlord,if=talent.thunderfist&debuff.skyreach_exhaustion.remains>55
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_st 18"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&prev.rising_sun_kick&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.RisingSunKick) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 20"; end
  end
  -- blackout_kick,if=combo_strike&set_bonus.tier31_2pc&buff.blackout_reinforcement.up&prev.rising_sun_kick
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(31, 2) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.RisingSunKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_st 22"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&prev.fists_of_fury&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.FistsofFury) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 24"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&buff.blackout_reinforcement.up&prev.fists_of_fury&set_bonus.tier31_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff) and Player:PrevGCD(1, S.FistsofFury) and Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_st 26"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc&prev.fists_of_fury
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2) and Player:PrevGCD(1, S.FistsofFury)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 27"; end
  end
  -- fists_of_fury,if=buff.invokers_delight.up,interrupt=1
  if S.FistsofFury:IsReady() and (Player:BuffUp(S.InvokersDelightBuff)) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity_st 28"; end
  end
  -- fists_of_fury_cancel
  if Player:IsChanneling(S.FistsofFury) then
    if CastAnnotated(S.StopFoF, false, "STOP") then return "fists_of_fury_cancel serenity_st 30"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 32"; end
  end
  -- strike_of_the_windlord,if=debuff.skyreach_exhaustion.remains>buff.call_to_dominance.remains
  if S.StrikeoftheWindlord:IsReady() and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) > Player:BuffRemains(S.CalltoDominanceBuff)) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity_st 34"; end
  end
  -- blackout_kick,if=combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_st 36"; end
  end
  -- blackout_kick,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity_st 38"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity_st 40"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity_st 42"; end
  end
  -- tiger_palm,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity_st 44"; end
  end
end

local function DefaultAoE()
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&!talent.hit_combo&spinning_crane_kick.max&buff.bonedust_brew.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and not S.HitCombo:IsAvailable() and SCKMax() and Player:BuffUp(S.BonedustBrewBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 4"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_aoe 6"; end
  end
  -- whirling_dragon_punch,if=active_enemies>8
  if S.WhirlingDragonPunch:IsReady() and (EnemiesCount8y > 8) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 8"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.bonedust_brew.up&combo_strike&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffUp(S.BonedustBrewBuff) and ComboStrike(S.SpinningCraneKick) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 10"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains
  if S.FistsofFury:IsReady() then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_aoe 12"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.bonedust_brew.up&buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.BonedustBrewBuff) and Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 14"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 16"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 18"; end
  end
  -- whirling_dragon_punch,if=active_enemies>=5
  if S.WhirlingDragonPunch:IsReady() and (EnemiesCount8y >= 5) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_aoe 20"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.up&set_bonus.tier30_2pc
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.whirling_dragon_punch&cooldown.whirling_dragon_punch.remains<3&cooldown.fists_of_fury.remains>3&!buff.kicks_of_flowing_momentum.up
  -- Note: Combining all three lines. Removing the first line, as the second covers that condition.
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2) or S.WhirlingDragonPunch:IsAvailable() and S.WhirlingDragonPunch:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:BuffDown(S.KicksofFlowingMomentumBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_aoe 22"; end
  end
  -- expel_harm,if=chi=1&(!cooldown.rising_sun_kick.remains|!cooldown.strike_of_the_windlord.remains)|chi=2&!cooldown.fists_of_fury.remains
  if S.ExpelHarm:IsReady() and (Player:Chi() == 1 and (S.RisingSunKick:CooldownUp() or S.StrikeoftheWindlord:CooldownUp()) or Player:Chi() == 2 and S.FistsofFury:CooldownUp()) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm default_aoe 24"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&cooldown.fists_of_fury.remains<5&buff.chi_energy.stack>10
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and S.FistsofFury:CooldownRemains() < 5 and Player:BuffStack(S.ChiEnergyBuff) > 10) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 26"; end
  end
  -- chi_burst,if=buff.bloodlust.up&chi<5
  -- chi_burst,if=chi<5&energy<50
  -- Note: Combining both lines.
  if S.ChiBurst:IsCastable() and (Player:Chi() < 5 and (Player:BloodlustUp() or Player:Energy() < 50)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 28"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&(cooldown.fists_of_fury.remains>3|chi>2)&spinning_crane_kick.max&buff.bloodlust.up&!buff.blackout_reinforcement.up
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&(cooldown.fists_of_fury.remains>3|chi>2)&spinning_crane_kick.max&buff.invokers_delight.up&!buff.blackout_reinforcement.up
  -- Note: Combining both lines.
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() > 2) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff) and (Player:BloodlustUp() or Player:BuffUp(S.InvokersDelightBuff))) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 30"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&set_bonus.tier30_2pc&!buff.bonedust_brew.up&active_enemies<15&!talent.crane_vortex
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&set_bonus.tier30_2pc&!buff.bonedust_brew.up&active_enemies<8
  -- Note: Combining both lines.
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2) and Player:BuffDown(S.BonedustBrewBuff) and (EnemiesCount8y < 15 and not S.CraneVortex:IsAvailable() or EnemiesCount8y < 8)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 32"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&(cooldown.fists_of_fury.remains>3|chi>4)&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() > 4) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_aoe 34"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 38"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_aoe 40"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&!spinning_crane_kick.max
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and not SCKMax()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_aoe 42"; end
  end
  -- chi_burst,if=chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2
  if S.ChiBurst:IsCastable() and (Player:ChiDeficit() >= 1 and EnemiesCount8y == 1 or Player:ChiDeficit() >= 2) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_aoe 44"; end
  end
end

local function Default4T()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi<2&(cooldown.fists_of_fury.remains<1|cooldown.strike_of_the_windlord.remains<1)&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:Chi() < 2 and (S.FistsofFury:CooldownRemains() < 1 or S.StrikeoftheWindlord:CooldownRemains() < 1) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_4t 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&spinning_crane_kick.max&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and SCKMax() and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_4t 4"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_4t 6"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains
  if S.FistsofFury:IsReady() then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_4t 8"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.bonedust_brew.up&buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.BonedustBrewBuff) and Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_4t 10"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_4t 12"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.bonedust_brew.up&combo_strike&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffUp(S.BonedustBrewBuff) and ComboStrike(S.SpinningCraneKick) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_4t 14"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_4t 16"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=!buff.bonedust_brew.up&buff.pressure_point.up&cooldown.fists_of_fury.remains>5
  if S.RisingSunKick:IsReady() and (Player:BuffDown(S.BonedustBrewBuff) and Player:BuffUp(S.PressurePointBuff) and S.FistsofFury:CooldownRemains() > 5) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_4t 18"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind default_4t 20"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_4t 22"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_4t 24"; end
  end
  -- expel_harm,if=chi=1&(!cooldown.rising_sun_kick.remains|!cooldown.strike_of_the_windlord.remains)|chi=2&!cooldown.fists_of_fury.remains
  if S.ExpelHarm:IsReady() and (Player:Chi() == 1 and (S.RisingSunKick:CooldownUp() or S.StrikeoftheWindlord:CooldownUp()) or Player:Chi() == 2 and S.FistsofFury:CooldownUp()) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm default_4t 26"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&cooldown.fists_of_fury.remains>3&buff.chi_energy.stack>10
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and S.FistsofFury:CooldownRemains() > 3 and Player:BuffStack(S.ChiEnergyBuff) > 10) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_4t 28"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_4t 30"; end
  end
  -- chi_burst,if=buff.bloodlust.up&chi<5
  -- chi_burst,if=chi<5&energy<50
  -- Note: Combining both lines.
  if S.ChiBurst:IsCastable() and (Player:Chi() < 5 and (Player:BloodlustUp() or Player:Energy() < 50)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_4t 32"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&(cooldown.fists_of_fury.remains>3|chi>4)&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() > 4) and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_4t 34"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_4t 36"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_4t 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&(cooldown.fists_of_fury.remains>3|chi>4)
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and (S.FistsofFury:CooldownRemains() > 3 or Player:Chi() > 4)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_4t 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_4t 44"; end
  end
end

local function Default3T()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi<2&(cooldown.rising_sun_kick.remains<1|cooldown.fists_of_fury.remains<1|cooldown.strike_of_the_windlord.remains<1)&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:Chi() < 2 and (S.RisingSunKick:CooldownRemains() < 1 or S.FistsofFury:CooldownRemains() < 1 or S.StrikeoftheWindlord:CooldownRemains() < 1) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_3t 2"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_3t 4"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&set_bonus.tier31_4pc
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:HasTier(31, 4)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_3t 6"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&(cooldown.invoke_xuen_the_white_tiger.remains>20|fight_remains<5)
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 20 or BossFightRemains < 5)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_3t 8"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 10"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 12"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains
  if S.FistsofFury:IsReady() then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_3t 14"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.bonedust_brew.up&buff.pressure_point.up&set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.BonedustBrewBuff) and Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_3t 16"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.bonedust_brew.up&combo_strike
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffUp(S.BonedustBrewBuff) and ComboStrike(S.SpinningCraneKick)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_3t 18"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=!buff.bonedust_brew.up&buff.pressure_point.up
  if S.RisingSunKick:IsReady() and (Player:BuffDown(S.BonedustBrewBuff) and Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_3t 20"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_3t 22"; end
  end
  -- expel_harm,if=chi=1&(!cooldown.rising_sun_kick.remains|!cooldown.strike_of_the_windlord.remains)|chi=2&!cooldown.fists_of_fury.remains
  if S.ExpelHarm:IsReady() and (Player:Chi() == 1 and (S.RisingSunKick:CooldownUp() or S.StrikeoftheWindlord:CooldownUp()) or Player:Chi() == 2 and S.FistsofFury:CooldownUp()) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm default_3t 24"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 26"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_3t 28"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.up&(talent.shadowboxing_treads|cooldown.rising_sun_kick.remains>1)
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.TeachingsoftheMonasteryBuff) and (S.ShadowboxingTreads:IsAvailable() or S.RisingSunKick:CooldownRemains() > 1)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 30"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_3t 32"; end
  end
  -- chi_burst,if=buff.bloodlust.up&chi<5
  -- chi_burst,if=chi<5&energy<50
  -- Note: Combining both lines.
  if S.ChiBurst:IsCastable() and (Player:Chi() < 5 and (Player:BloodlustUp() or Player:Energy() < 50)) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_3t 34"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 36"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&cooldown.fists_of_fury.remains<3&buff.chi_energy.stack>15
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and S.FistsofFury:CooldownRemains() < 3 and Player:BuffStack(S.ChiEnergyBuff) > 15) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_3t 38"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=cooldown.fists_of_fury.remains>4&chi>3
  if S.RisingSunKick:IsReady() and (S.FistsofFury:CooldownRemains() > 4 and Player:Chi() > 3) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_3t 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&chi>4&((talent.storm_earth_and_fire&!talent.bonedust_brew)|(talent.serenity))
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and S.RisingSunKick:CooldownDown() and S.FistsofFury:CooldownDown() and Player:Chi() > 4 and ((S.StormEarthAndFire:IsAvailable() and not S.BonedustBrew:IsAvailable()) or S.Serenity:IsAvailable())) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_3t 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&cooldown.fists_of_fury.remains
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.FistsofFury:CooldownDown()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 44"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind default_3t 46"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&talent.shadowboxing_treads&!spinning_crane_kick.max
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.ShadowboxingTreads:IsAvailable() and not SCKMax()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_3t 48"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&(combo_strike&chi>5&talent.storm_earth_and_fire|combo_strike&chi>4&talent.serenity)
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and (ComboStrike(S.SpinningCraneKick) and (Player:Chi() > 5 and S.StormEarthAndFire:IsAvailable() or Player:Chi() > 4 and S.Serenity:IsAvailable()))) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_3t 50"; end
  end
end

local function Default2T()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi<2&(cooldown.rising_sun_kick.remains<1|cooldown.fists_of_fury.remains<1|cooldown.strike_of_the_windlord.remains<1)&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:Chi() < 2 and (S.RisingSunKick:CooldownRemains() < 1 or S.FistsofFury:CooldownRemains() < 1 or S.StrikeoftheWindlord:CooldownRemains() < 1) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_2t 2"; end
  end
  -- expel_harm,if=chi=1&(!cooldown.rising_sun_kick.remains|!cooldown.strike_of_the_windlord.remains)|chi=2&!cooldown.fists_of_fury.remains
  if S.ExpelHarm:IsReady() and (Player:Chi() == 1 and (S.RisingSunKick:CooldownUp() or S.StrikeoftheWindlord:CooldownUp()) or Player:Chi() == 2 and S.FistsofFury:CooldownUp()) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm default_2t 4"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3&talent.shadowboxing_treads
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 6"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&set_bonus.tier31_4pc
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and Player:HasTier(31, 4)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_2t 8"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains,if=talent.thunderfist&(cooldown.invoke_xuen_the_white_tiger.remains>20|fight_remains<5)
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable() and (S.InvokeXuenTheWhiteTiger:CooldownRemains() > 20 or BossFightRemains < 5)) then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_2t 10"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up&set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff) and Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_2t 12"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=talent.shadowboxing_treads&combo_strike&buff.blackout_reinforcement.up
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.BlackoutReinforcementBuff)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 13"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains,if=!set_bonus.tier30_2pc
  if S.FistsofFury:IsReady() and (not Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies8y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_2t 14"; end
  end
  -- fists_of_fury,target_if=max:debuff.keefers_skyreach.remains
  if S.FistsofFury:IsReady() then
    if Everyone.CastTargetIf(S.FistsofFury, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_2t 16"; end
  end
  -- rising_sun_kick,if=!cooldown.fists_of_fury.remains
  if S.RisingSunKick:IsReady() and (S.FistsofFury:CooldownUp()) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_2t 18"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=set_bonus.tier30_2pc
  if S.RisingSunKick:IsReady() and (Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_2t 20"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.kicks_of_flowing_momentum.up|buff.pressure_point.up|debuff.skyreach_exhaustion.remains>55
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.KicksofFlowingMomentumBuff) or Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, EvaluateTargetIfRSK2, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_2t 22"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_2t 24"; end
  end
  -- chi_burst,if=buff.bloodlust.up&chi<5
  if S.ChiBurst:IsCastable() and (Player:BloodlustUp() and Player:Chi() < 5) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_2t 26"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=2
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 28"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.pressure_point.remains&chi>2&prev.rising_sun_kick
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:Chi() > 2 and Player:PrevGCD(1, S.RisingSunKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 30"; end
  end
  -- chi_burst,if=chi<5&energy<50
  if S.ChiBurst:IsCastable() and (Player:Chi() < 5 and Player:Energy() < 50) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_2t 32"; end
  end
  -- strike_of_the_windlord,target_if=max:debuff.keefers_skyreach.remains
  if S.StrikeoftheWindlord:IsReady() then
    if Everyone.CastTargetIf(S.StrikeoftheWindlord, Enemies5y, "max", EvaluateTargetIfFilterSkyreach, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_2t 34"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.up&(talent.shadowboxing_treads|cooldown.rising_sun_kick.remains>1)
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.TeachingsoftheMonasteryBuff) and (S.ShadowboxingTreads:IsAvailable() or S.RisingSunKick:CooldownRemains() > 1)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 36"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_2t 38"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=buff.teachings_of_the_monastery.stack=3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 40"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=!talent.shadowboxing_treads&cooldown.fists_of_fury.remains>4&talent.xuens_battlegear
  if S.RisingSunKick:IsReady() and (not S.ShadowboxingTreads:IsAvailable() and S.FistsofFury:CooldownRemains() > 4 and S.XuensBattlegear:IsAvailable()) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_2t 42"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&cooldown.rising_sun_kick.remains&cooldown.fists_of_fury.remains&(!buff.bonedust_brew.up|spinning_crane_kick.modifier<1.5)
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and S.RisingSunKick:CooldownDown() and S.FistsofFury:CooldownDown() and (Player:BuffDown(S.BonedustBrewBuff) or SCKModifier() < 1.5)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 44"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind default_2t 46"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.bonedust_brew.up&combo_strike&spinning_crane_kick.modifier>=2.7
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffUp(S.BonedustBrewBuff) and ComboStrike(S.SpinningCraneKick) and SCKModifier() >= 2.7) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_2t 48"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_2t 50"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_2t 52"; end
  end
  -- jadefire_stomp,if=combo_strike
  if S.JadefireStomp:IsCastable() and (ComboStrike(S.JadefireStomp)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_2t 54"; end
  end
end

local function DefaultST()
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi<2&(cooldown.rising_sun_kick.remains<1|cooldown.fists_of_fury.remains<1|cooldown.strike_of_the_windlord.remains<1)&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:Chi() < 2 and (S.RisingSunKick:CooldownRemains() < 1 or S.FistsofFury:CooldownRemains() < 1 or S.StrikeoftheWindlord:CooldownRemains() < 1) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm default_st 2"; end
  end
  -- expel_harm,if=chi=1&(!cooldown.rising_sun_kick.remains|!cooldown.strike_of_the_windlord.remains)|chi=2&!cooldown.fists_of_fury.remains&cooldown.rising_sun_kick.remains
  if S.ExpelHarm:IsReady() and (Player:Chi() == 1 and (S.RisingSunKick:CooldownUp() or S.StrikeoftheWindlord:CooldownUp()) or Player:Chi() == 2 and S.FistsofFury:CooldownUp() and S.RisingSunKick:CooldownDown()) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(20)) then return "expel_harm default_st 4"; end
  end
  -- strike_of_the_windlord,if=buff.domineering_arrogance.up&talent.thunderfist&talent.serenity&cooldown.invoke_xuen_the_white_tiger.remains>20|fight_remains<5|talent.thunderfist&debuff.skyreach_exhaustion.remains>10&!buff.domineering_arrogance.up|talent.thunderfist&debuff.skyreach_exhaustion.remains>35&!talent.serenity
  if S.StrikeoftheWindlord:IsReady() and (Player:BuffUp(S.DomineeringArroganceBuff) and S.Thunderfist:IsAvailable() and S.Serenity:IsAvailable() and S.InvokeXuenTheWhiteTiger:CooldownRemains() > 20 or BossFightRemains < 5 or S.Thunderfist:IsAvailable() and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 10 and Player:BuffDown(S.DomineeringArroganceBuff) or S.Thunderfist:IsAvailable() and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 35 and not S.Serenity:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_st 6"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&set_bonus.tier31_2pc&!buff.blackout_reinforcement.up
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and Player:HasTier(31, 2) and Player:BuffDown(S.BlackoutReinforcementBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 10"; end
  end
  -- rising_sun_kick,if=!cooldown.fists_of_fury.remains
  if S.RisingSunKick:IsReady() and (S.FistsofFury:CooldownUp()) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 12"; end
  end
  -- fists_of_fury,if=!buff.pressure_point.up&debuff.skyreach_exhaustion.remains<55&(debuff.jadefire_brand_damage.remains>2|cooldown.jadefire_stomp.remains)
  if S.FistsofFury:IsReady() and (Player:BuffDown(S.PressurePointBuff) and Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 55 and (Target:DebuffRemains(S.JadefireBrandDebuff) > 2 or S.JadefireStomp:CooldownDown())) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 14"; end
  end
  -- jadefire_stomp,if=debuff.skyreach_exhaustion.remains<1&debuff.jadefire_brand_damage.remains<3
  if S.JadefireStomp:IsCastable() and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 1 and Target:DebuffRemains(S.JadefireBrandDebuff) < 3) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp default_st 16"; end
  end
  -- rising_sun_kick,if=buff.pressure_point.up|debuff.skyreach_exhaustion.remains>55
  if S.RisingSunKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) or Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 55) then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 18"; end
  end
  -- blackout_kick,if=buff.pressure_point.remains&chi>2&prev.rising_sun_kick
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.PressurePointBuff) and Player:Chi() > 2 and Player:PrevGCD(1, S.RisingSunKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 20"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack=3
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 22"; end
  end
  -- blackout_kick,if=buff.blackout_reinforcement.up&cooldown.rising_sun_kick.remains&combo_strike&buff.dance_of_chiji.up
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.BlackoutReinforcementBuff) and S.RisingSunKick:CooldownDown() and ComboStrike(S.BlackoutKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 24"; end
  end
  -- rising_sun_kick
  if S.RisingSunKick:IsReady() then
    if Cast(S.RisingSunKick, nil, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick default_st 26"; end
  end
  -- blackout_kick,if=buff.blackout_reinforcement.up&combo_strike
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.BlackoutReinforcementBuff) and ComboStrike(S.BlackoutKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 28"; end
  end
  -- fists_of_fury
  if S.FistsofFury:IsReady() then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury default_st 30"; end
  end
  -- whirling_dragon_punch,if=!buff.pressure_point.up
  if S.WhirlingDragonPunch:IsReady() and (Player:BuffDown(S.PressurePointBuff)) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 32"; end
  end
  -- chi_burst,if=buff.bloodlust.up&chi<5
  if S.ChiBurst:IsCastable() and (Player:BloodlustUp() and Player:Chi() < 5) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 34"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.stack=2&debuff.skyreach_exhaustion.remains>1
  if S.BlackoutKick:IsReady() and (Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2 and Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 1) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 36"; end
  end
  -- chi_burst,if=chi<5&energy<50
  if S.ChiBurst:IsCastable() and (Player:Chi() < 5 and Player:Energy() < 50) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst default_st 38"; end
  end
  -- strike_of_the_windlord,if=debuff.skyreach_exhaustion.remains>30|fight_remains<5
  if S.StrikeoftheWindlord:IsReady() and (Target:DebuffRemains(S.SkyreachExhaustionDebuff) > 30 or BossFightRemains < 5) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord default_st 40"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.dance_of_chiji.up&!set_bonus.tier31_2pc
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and not Player:HasTier(31, 2)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 42"; end
  end
  -- blackout_kick,if=buff.teachings_of_the_monastery.up&cooldown.rising_sun_kick.remains>1
  if S.BlackoutKick:IsReady() and (Player:BuffUp(S.TeachingsoftheMonasteryBuff) and S.RisingSunKick:CooldownRemains() > 1) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 44"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&buff.bonedust_brew.up&combo_strike&spinning_crane_kick.modifier>=2.7
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and Player:BuffUp(S.BonedustBrewBuff) and ComboStrike(S.SpinningCraneKick) and SCKModifier() >= 2.7) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick default_st 46"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch default_st 48"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff)) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind default_st 50"; end
  end
  -- blackout_kick,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick default_st 52"; end
  end
end

local function Fallthru()
  -- crackling_jade_lightning,if=buff.the_emperors_capacitor.stack>19&energy.time_to_max>execute_time-1&cooldown.rising_sun_kick.remains>execute_time|buff.the_emperors_capacitor.stack>14&(cooldown.serenity.remains<5&talent.serenity|fight_remains<5)
  if S.CracklingJadeLightning:IsReady() and (Player:BuffStack(S.TheEmperorsCapacitorBuff) > 19 and EnergyTimeToMaxRounded() > S.CracklingJadeLightning:ExecuteTime() - 1 and S.RisingSunKick:CooldownRemains() > S.CracklingJadeLightning:ExecuteTime() or Player:BuffStack(S.TheEmperorsCapacitorBuff) > 14 and (S.Serenity:CooldownRemains() < 5 and S.Serenity:IsAvailable() or BossFightRemains < 5)) then
    if Cast(S.CracklingJadeLightning, nil, nil, not Target:IsSpellInRange(S.CracklingJadeLightning)) then return "crackling_jade_lightning fallthru 2"; end
  end
  -- jadefire_stomp,if=combo_strike
  if S.JadefireStomp:IsCastable() and (ComboStrike(S.JadefireStomp)) then
    if Cast(S.JadefireStomp, nil, nil, not Target:IsInRange(30)) then return "jadefire_stomp fallthru 4"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=combo_strike&chi.max-chi>=(2+buff.power_strikes.up)
  if S.TigerPalm:IsReady() and (ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= (2 + num(Player:BuffUp(S.PowerStrikesBuff)))) then
    if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm fallthru 6"; end
  end
  -- expel_harm,if=chi.max-chi>=1&active_enemies>2
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1 and EnemiesCount8y > 2) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm fallthru 8"; end
  end
  -- chi_burst,if=chi.max-chi>=1&active_enemies=1&raid_event.adds.in>20|chi.max-chi>=2&active_enemies>=2
  if S.ChiBurst:IsCastable() and (Player:ChiDeficit() >= 1 and EnemiesCount8y == 1 or Player:ChiDeficit() >= 2 and EnemiesCount8y >= 2) then
    if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst fallthru 10"; end
  end
  -- chi_wave
  if S.ChiWave:IsCastable() then
    if Cast(S.ChiWave, nil, nil, not Target:IsInRange(40)) then return "chi_wave fallthru 12"; end
  end
  -- expel_harm,if=chi.max-chi>=1
  if S.ExpelHarm:IsReady() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ExpelHarm, nil, nil, not Target:IsInMeleeRange(8)) then return "expel_harm fallthru 14"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains-spinning_crane_kick.max*(target.time_to_die+debuff.keefers_skyreach.remains*20),if=combo_strike&active_enemies>=5
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and EnemiesCount8y >= 5) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane103, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick fallthru 16"; end
  end
  -- spinning_crane_kick,target_if=max:target.time_to_die,if=target.time_to_die>duration&combo_strike&buff.chi_energy.stack>30-5*active_enemies&buff.storm_earth_and_fire.down&(cooldown.rising_sun_kick.remains>2&cooldown.fists_of_fury.remains>2|cooldown.rising_sun_kick.remains<3&cooldown.fists_of_fury.remains>3&chi>3|cooldown.rising_sun_kick.remains>3&cooldown.fists_of_fury.remains<3&chi>4|chi.max-chi<=1&energy.time_to_max<2)|buff.chi_energy.stack>10&fight_remains<7
  if S.SpinningCraneKick:IsReady() and (FightRemains > (Player:SpellHaste() * 1.5) and ComboStrike(S.SpinningCraneKick) and Player:BuffStack(S.ChiEnergyBuff) > 30 - 5 * EnemiesCount8y and Player:BuffDown(S.StormEarthAndFireBuff) and (S.RisingSunKick:CooldownRemains() > 2 and S.FistsofFury:CooldownRemains() > 2 or S.RisingSunKick:CooldownRemains() < 3 and S.FistsofFury:CooldownRemains() > 3 and Player:Chi() > 3 or S.RisingSunKick:CooldownRemains() > 3 and S.FistsofFury:CooldownRemains() < 3 and Player:Chi() > 4 or Player:ChiDeficit() <= 1 and EnergyTimeToMaxRounded() < 2) or Player:BuffStack(S.ChiEnergyBuff) > 10 and BossFightRemains < 7) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick fallthru 18"; end
  end
  -- arcane_torrent,if=chi.max-chi>=1
  if S.ArcaneTorrent:IsCastable() and (Player:ChiDeficit() >= 1) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "arcane_torrent fallthru 20"; end
  end
  -- flying_serpent_kick,interrupt=1
  if S.FlyingSerpentKick:IsCastable() and not Settings.Windwalker.IgnoreFSK then
    if Cast(S.FlyingSerpentKick, nil, nil, not Target:IsInRange(30)) then return "flying_serpent_kick fallthru 22"; end
  end
  -- tiger_palm
  if S.TigerPalm:IsReady() then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm fallthru 24"; end
  end
end

local function Serenity()
  -- fists_of_fury,if=buff.serenity.remains<1
  if S.FistsofFury:IsReady() and (Player:BuffRemains(S.SerenityBuff) < 1) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity 2"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&!spinning_crane_kick.max&active_enemies>4&talent.shdaowboxing_treads
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and not SCKMax() and EnemiesCount8y > 4 and S.ShadowboxingTreads:IsAvailable()) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 4"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&buff.teachings_of_the_monastery.stack=3&buff.teachings_of_the_monastery.remains<1
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 3 and Player:BuffRemains(S.TeachingsoftheMonasteryBuff) < 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 6"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies=4&buff.pressure_point.up&!talent.bonedust_brew
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies=1
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies<=3&buff.pressure_point.up
  -- rising_sun_kick,if=min:debuff.mark_of_the_crane.remains,if=buff.pressure_point.up&set_bonus.tier30_2pc
  -- Note: Combining all into one line.
  if S.RisingSunKick:IsReady() and ((EnemiesCount8y == 4 and Player:BuffUp(S.PressurePointBuff) and not S.BonedustBrew:IsAvailable()) or EnemiesCount8y == 1 or (EnemiesCount8y <= 3 and Player:BuffUp(S.PressurePointBuff)) or (Player:BuffUp(S.PressurePointBuff) and Player:HasTier(30, 2))) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity 8"; end
  end
  -- fists_of_fury,if=buff.invokers_delight.up&active_enemies<3&talent.Jade_Ignition,interrupt=1
  -- fists_of_fury,if=buff.invokers_delight.up&active_enemies>4,interrupt=1
  -- fists_of_fury,if=buff.bloodlust.up,interrupt=1
  -- fists_of_fury,if=active_enemies=2
  -- Note: Combining all into one line.
  if S.FistsofFury:IsReady() and ((Player:BuffUp(S.InvokersDelightBuff) and (EnemiesCount8y < 3 and S.JadeIgnition:IsAvailable() or EnemiesCount8y > 4)) or Player:BloodlustUp() or EnemiesCount8y == 2) then
    if Cast(S.FistsofFury, nil, nil, not Target:IsInMeleeRange(8)) then return "fists_of_fury serenity 10"; end
  end
  -- fists_of_fury_cancel,target_if=max:target.time_to_die
  if S.FistsofFury:IsReady() then
    local FoFTar = FoFTarget()
    if FoFTar then
      if FoFTar:GUID() == Target:GUID() then
        if HR.CastQueue(S.FistsofFury, S.StopFoF) then return "fists_of_fury one_gcd serenity 14"; end
      else
        if HR.CastLeftNameplate(FoFTar, S.FistsofFury) then return "fists_of_fury one_gcd off-target serenity 14"; end
      end
    end
  end
  -- strike_of_the_windlord,if=talent.thunderfist
  if S.StrikeoftheWindlord:IsReady() and (S.Thunderfist:IsAvailable()) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity 2"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up&active_enemies>=2
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff) and EnemiesCount8y >= 2) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 14"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies=4&buff.pressure_point.up
  if S.RisingSunKick:IsReady() and (EnemiesCount8y == 4 and Player:BuffUp(S.PressurePointBuff)) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity 16"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies=3&combo_strike&set_bonus.tier30_2pc
  if S.BlackoutKick:IsReady() and (EnemiesCount8y == 3 and ComboStrike(S.BlackoutKick) and Player:HasTier(30, 2)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity "; end
  end
  -- spinning_crane_kick,if=combo_strike&active_enemies>=3&spinning_crane_kick.max
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and EnemiesCount8y >= 3 and SCKMax()) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 20"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=combo_strike&active_enemies>1&active_enemies<4&buff.teachings_of_the_monastery.stack=2
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and EnemiesCount8y > 1 and EnemiesCount8y < 4 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 2) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 18"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up&active_enemies>=5
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and EnemiesCount8y >= 5) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity 22"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=talent.shadowboxing_treads&active_enemies>=3&combo_strike
  if S.BlackoutKick:IsReady() and (S.ShadowboxingTreads:IsAvailable() and EnemiesCount8y >= 3 and ComboStrike(S.BlackoutKick)) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 24"; end
  end
  -- spinning_crane_kick,if=combo_strike&(active_enemies>3|active_enemies>2&spinning_crane_kick.modifier>=2.3)
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and (EnemiesCount8y > 3 or EnemiesCount8y > 2 and SCKModifier() >= 2.3)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 26"; end
  end
  -- strike_of_the_windlord,if=active_enemies>=3
  if S.StrikeoftheWindlord:IsReady() and (EnemiesCount8y >= 3) then
    if Cast(S.StrikeoftheWindlord, nil, nil, not Target:IsInMeleeRange(9)) then return "strike_of_the_windlord serenity 28"; end
  end
  -- rising_sun_kick,if=min:debuff.mark_of_the_crane.remains,if=active_enemies=2&cooldown.fists_of_fury.remains>5
  if S.RisingSunKick:IsReady() and (EnemiesCount8y == 2 and S.FistsofFury:CooldownRemains() > 5) then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity 30"; end
  end
  -- blackout_kick,target_if=min:debuff.mark_of_the_crane.remains,if=active_enemies=2&cooldown.fists_of_fury.remains>5&talent.shadowboxing_treads&buff.teachings_of_the_monastery.stack=1&combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick) and EnemiesCount8y == 2 and S.FistsofFury:CooldownRemains() > 5 and S.ShadowboxingTreads:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) == 1) then
    if Everyone.CastTargetIf(S.BlackoutKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 32"; end
  end
  -- spinning_crane_kick,if=combo_strike&active_enemies>1
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and EnemiesCount8y > 1) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 34"; end
  end
  -- whirling_dragon_punch,if=active_enemies>1
  if S.WhirlingDragonPunch:IsReady() and (EnemiesCount8y > 1) then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity 36"; end
  end
  -- rushing_jade_wind,if=!buff.rushing_jade_wind.up&active_enemies>=3
  if S.RushingJadeWind:IsReady() and (Player:BuffDown(S.RushingJadeWindBuff) and EnemiesCount8y >= 3) then
    if Cast(S.RushingJadeWind, nil, nil, not Target:IsInMeleeRange(8)) then return "rushing_jade_wind serenity 38"; end
  end
  -- rising_sun_kick,target_if=min:debuff.mark_of_the_crane.remains
  if S.RisingSunKick:IsReady() then
    if Everyone.CastTargetIf(S.RisingSunKick, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane100, nil, not Target:IsInMeleeRange(5)) then return "rising_sun_kick serenity 40"; end
  end
  -- spinning_crane_kick,if=combo_strike&buff.dance_of_chiji.up
  if S.SpinningCraneKick:IsReady() and (ComboStrike(S.SpinningCraneKick) and Player:BuffUp(S.DanceofChijiBuff)) then
    if Cast(S.SpinningCraneKick, nil, nil, not Target:IsInMeleeRange(8)) then return "spinning_crane_kick serenity 42"; end
  end
  -- blackout_kick,if=combo_strike
  if S.BlackoutKick:IsReady() and (ComboStrike(S.BlackoutKick)) then
    if Cast(S.BlackoutKick, nil, nil, not Target:IsInMeleeRange(5)) then return "blackout_kick serenity 44"; end
  end
  -- whirling_dragon_punch
  if S.WhirlingDragonPunch:IsReady() then
    if Cast(S.WhirlingDragonPunch, nil, nil, not Target:IsInMeleeRange(5)) then return "whirling_dragon_punch serenity 46"; end
  end
  -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains,if=talent.teachings_of_the_monastery&buff.teachings_of_the_monastery.stack<3
  if S.TigerPalm:IsReady() and (S.TeachingsoftheMonastery:IsAvailable() and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3) then
    if Cast(S.TigerPalm, nil, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm serenity 48"; end
  end
end

-- APL Main
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

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    XuenActive = S.InvokeXuenTheWhiteTiger:TimeSinceLastCast() <= 24
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
    if not Settings.Windwalker.IgnoreFSK and Player:PrevGCD(1, S.FlyingSerpentKick) then
      if Cast(S.FlyingSerpentKickLand) then return "flying_serpent_kick land"; end
    end
    -- spear_hand_strike,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.SpearHandStrike, Settings.CommonsDS.DisplayStyle.Interrupts, Stuns); if ShouldReturn then return ShouldReturn; end
    -- Manually added: fortifying_brew
    if S.FortifyingBrew:IsReady() and Settings.Windwalker.ShowFortifyingBrewCD and Player:HealthPercentage() <= Settings.Windwalker.FortifyingBrewHP then
      if Cast(S.FortifyingBrew, Settings.Windwalker.GCDasOffGCD.FortifyingBrew, nil, not Target:IsSpellInRange(S.FortifyingBrew)) then return "fortifying_brew main 2"; end
    end
    -- variable,name=hold_xuen,op=set,value=!talent.invoke_xuen_the_white_tiger|cooldown.invoke_xuen_the_white_tiger.duration>fight_remains
    VarHoldXuen = not S.InvokeXuenTheWhiteTiger:IsAvailable() or 120 > FightRemains
    -- variable,name=hold_tp_rsk,op=set,value=!debuff.skyreach_exhaustion.remains<1&cooldown.rising_sun_kick.remains<1&(set_bonus.tier30_2pc|active_enemies<5)
    VarHoldTPRSK = not (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 1) and S.RisingSunKick:CooldownRemains() < 1 and (Player:HasTier(30, 2) or EnemiesCount8y < 5)
    -- variable,name=hold_tp_bdb,op=set,value=!debuff.skyreach_exhaustion.remains<1&cooldown.bonedust_brew.remains<1&active_enemies=1
    VarHoldTPBDB = not (Target:DebuffRemains(S.SkyreachExhaustionDebuff) < 1) and S.BonedustBrew:CooldownRemains() < 1 and EnemiesCount8y == 1
    -- potion handling
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if S.InvokeXuenTheWhiteTiger:IsAvailable() then
          -- potion,if=buff.serenity.up|buff.storm_earth_and_fire.up&pet.xuen_the_white_tiger.active|fight_remains<=30
          if Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff) and XuenActive or BossFightRemains <= 30 then
            if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion with xuen main 4"; end
          end
        else
          -- potion,if=(buff.serenity.up|buff.storm_earth_and_fire.up)&fight_remains<=30
          if (Player:BuffUp(S.SerenityBuff) or Player:BuffUp(S.StormEarthAndFireBuff)) or BossFightRemains <= 30 then
            if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion without xuen main 6"; end
          end
        end
      end
    end
    -- With Xuen: call_action_list,name=opener,if=time<4&chi<5&!pet.xuen_the_white_tiger.active&!talent.serenity
    -- Without Xuen: call_action_list,name=opener,if=time<4&chi<5&!talent.serenity
    if (HL.CombatTime() < 4 and Player:Chi() < 5 and not S.Serenity:IsAvailable() and (not XuenActive or not S.InvokeXuenTheWhiteTiger:IsAvailable())) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- jadefire_stomp,target_if=min:debuff.jadefire_brand_damage.remains,if=combo_strike&talent.jadefire_harmony&debuff.jadefire_brand_damage.remains<1
    if S.JadefireStomp:IsCastable() and (ComboStrike(S.JadefireStomp) and S.JadefireHarmony:IsAvailable()) then
      if Everyone.CastTargetIf(S.JadefireStomp, Enemies8y, "min", EvaluateTargetIfFilterFaeExposure, EvaluateTargetIfJadefireStomp, not Target:IsInRange(30)) then return "jadefire_stomp main 8"; end
    end
    -- bonedust_brew,if=active_enemies=1&!debuff.skyreach_exhaustion.remains&(pet.xuen_the_white_tiger.active|cooldown.xuen_the_white_tiger.remains)
    if S.BonedustBrew:IsCastable() and (EnemiesCount8y == 1 and Target:DebuffDown(S.SkyreachExhaustionDebuff) and (XuenActive or S.InvokeXuenTheWhiteTiger:CooldownDown())) then
      if Cast(S.BonedustBrew, nil, Settings.CommonsDS.DisplayStyle.Signature, not Target:IsInRange(40)) then return "bonedust_brew main 9"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=!buff.serenity.up&energy>50&buff.teachings_of_the_monastery.stack<3&combo_strike&chi.max-chi>=(2+buff.power_strikes.up)&(!talent.invoke_xuen_the_white_tiger&!talent.serenity|((!talent.skyreach&!talent.skytouch)|time>5|pet.xuen_the_white_tiger.active))&!variable.hold_tp_rsk&(active_enemies>1|!talent.bonedust_brew|talent.bonedust_brew&active_enemies=1&cooldown.bonedust_brew.remains)
    if S.TigerPalm:IsReady() and (Player:BuffDown(S.SerenityBuff) and Player:Energy() > 50 and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3 and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= (2 + num(Player:BuffUp(S.PowerStrikesBuff))) and (not S.InvokeXuenTheWhiteTiger:IsAvailable() and not S.Serenity:IsAvailable() or ((not S.Skyreach:IsAvailable() and not S.Skytouch:IsAvailable()) or HL.CombatTime() > 5 or XuenActive)) and not VarHoldTPRSK and (EnemiesCount8y > 1 or not S.BonedustBrew:IsAvailable() or S.BonedustBrew:IsAvailable() and EnemiesCount8y == 1 and S.BonedustBrew:CooldownDown())) then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 10"; end
    end
    -- tiger_palm,target_if=min:debuff.mark_of_the_crane.remains+(debuff.skyreach_exhaustion.up*20),if=!buff.serenity.up&buff.teachings_of_the_monastery.stack<3&combo_strike&chi.max-chi>=(2+buff.power_strikes.up)&(!talent.invoke_xuen_the_white_tiger&!talent.serenity|((!talent.skyreach&!talent.skytouch)|time>5|pet.xuen_the_white_tiger.active))&!variable.hold_tp_rsk&(active_enemies>1|!talent.bonedust_brew|talent.bonedust_brew&active_enemies=1&cooldown.bonedust_brew.remains)
    if S.TigerPalm:IsReady() and (Player:BuffDown(S.SerenityBuff) and Player:BuffStack(S.TeachingsoftheMonasteryBuff) < 3 and ComboStrike(S.TigerPalm) and Player:ChiDeficit() >= (2 + num(Player:BuffUp(S.PowerStrikesBuff))) and (not S.InvokeXuenTheWhiteTiger:IsAvailable() and not S.Serenity:IsAvailable() or ((not S.Skyreach:IsAvailable() and not S.Skytouch:IsAvailable()) or HL.CombatTime() > 5 or XuenActive)) and not VarHoldTPRSK and (EnemiesCount8y > 1 or not S.BonedustBrew:IsAvailable() or S.BonedustBrew:IsAvailable() and EnemiesCount8y == 1 and S.BonedustBrew:CooldownDown())) then
      if Everyone.CastTargetIf(S.TigerPalm, Enemies5y, "min", EvaluateTargetIfFilterMarkoftheCrane101, nil, not Target:IsInMeleeRange(5)) then return "tiger_palm main 12"; end
    end
    -- chi_burst,if=talent.jadefire_stomp&cooldown.jadefire_stomp.remains&(chi.max-chi>=1&active_enemies=1|chi.max-chi>=2&active_enemies>=2)&!talent.jadefire_harmony
    if S.ChiBurst:IsCastable() and (S.JadefireStomp:IsAvailable() and S.JadefireStomp:CooldownDown() and (Player:ChiDeficit() >= 1 and EnemiesCount8y == 1 or Player:ChiDeficit() >= 2 and EnemiesCount8y >= 2) and not S.JadefireHarmony:IsAvailable()) then
      if Cast(S.ChiBurst, nil, nil, not Target:IsInRange(40)) then return "chi_burst main 14"; end
    end
    -- call_action_list,name=cd_sef,if=!talent.serenity
    if (CDsON() and not S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSEF(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cd_serenity,if=talent.serenity
    if (CDsON() and S.Serenity:IsAvailable()) then
      local ShouldReturn = CDSerenity(); if ShouldReturn then return ShouldReturn; end
    end
    if Player:BuffUp(S.SerenityBuff) then
      -- call_action_list,name=serenity_aoelust,if=buff.serenity.up&((buff.bloodlust.up&(buff.invokers_delight.up|buff.power_infusion.up))|buff.invokers_delight.up&buff.power_infusion.up)&active_enemies>4
      -- Note: Changed > to >= because otherwise 4 targets is covered by neither condition.
      if Player:BuffUp(S.SerenityBuff) and ((Player:BloodlustUp() and (Player:BuffUp(S.InvokersDelightBuff) or Player:PowerInfusionUp())) or Player:BuffUp(S.InvokersDelightBuff) and Player:PowerInfusionUp()) and EnemiesCount8y >= 4 then
        local ShouldReturn = SerenityAoELust(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_lust,if=buff.serenity.up&((buff.bloodlust.up&(buff.invokers_delight.up|buff.power_infusion.up))|buff.invokers_delight.up&buff.power_infusion.up)&active_enemies<4
      if Player:BuffUp(S.SerenityBuff) and ((Player:BloodlustUp() and (Player:BuffUp(S.InvokersDelightBuff) or Player:PowerInfusionUp())) or Player:BuffUp(S.InvokersDelightBuff) and Player:PowerInfusionUp()) and EnemiesCount8y < 4 then
        local ShouldReturn = SerenityLust(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_aoe,if=buff.serenity.up&active_enemies>4
      if EnemiesCount8y > 4 then
        local ShouldReturn = SerenityAoE(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_4t,if=buff.serenity.up&active_enemies=4
      if EnemiesCount8y == 4 then
        local ShouldReturn = Serenity4T(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_3t,if=buff.serenity.up&active_enemies=3
      if EnemiesCount8y == 3 then
        local ShouldReturn = Serenity3T(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_2t,if=buff.serenity.up&active_enemies=2
      if EnemiesCount8y == 2 then
        local ShouldReturn = Serenity2T(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=serenity_st,if=buff.serenity.up&active_enemies=1
      if EnemiesCount8y == 1 then
        local ShouldReturn = SerenityST(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=default_aoe,if=active_enemies>4
    if EnemiesCount8y > 4 then
      local ShouldReturn = DefaultAoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=default_4t,if=active_enemies=4
    if EnemiesCount8y == 4 then
      local ShouldReturn = Default4T(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=default_3t,if=active_enemies=3
    if EnemiesCount8y == 3 then
      local ShouldReturn = Default3T(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=default_2t,if=active_enemies=2
    if EnemiesCount8y == 2 then
      local ShouldReturn = Default2T(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=default_st,if=active_enemies=1
    if EnemiesCount8y == 1 then
      local ShouldReturn = DefaultST(); if ShouldReturn then return ShouldReturn; end
    end
    -- summon_white_tiger_statue
    if S.SummonWhiteTigerStatue:IsCastable() then
      if Cast(S.SummonWhiteTigerStatue, Settings.CommonsOGCD.GCDasOffGCD.SummonWhiteTigerStatue, nil, not Target:IsInRange(40)) then return "summon_white_tiger_statue main 16"; end
    end
    -- call_action_list,name=fallthru
    local ShouldReturn = Fallthru(); if ShouldReturn then return ShouldReturn; end
    -- Manually added Pool filler
    if Cast(S.PoolEnergy) then return "Pool Energy"; end
  end
end

local function Init()
  HR.Print("Windwalker Monk rotation has been updated for patch 10.2.7.")
end

HR.SetAPL(269, APL, Init)
