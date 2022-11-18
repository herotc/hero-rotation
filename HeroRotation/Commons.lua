--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, HR = ...;
-- HeroLib
local HL = HeroLib;
local Cache, Utils = HeroCache, HL.Utils;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- Lua
local pairs = pairs;
local gsub = string.gsub;
-- File Locals
HR.Commons = {};
local Commons = {};
HR.Commons.Everyone = Commons;
local Settings = HR.GUISettings.General;
local AbilitySettings = HR.GUISettings.Abilities;

--- ============================ CONTENT ============================
-- Is the current target valid?
function Commons.TargetIsValid()
  return Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost();
end

-- Is the current unit valid during cycle?
function Commons.UnitIsCycleValid(Unit, BestUnitTTD, TimeToDieOffset)
  return not Unit:IsFacingBlacklisted() and not Unit:IsUserCycleBlacklisted() and (not BestUnitTTD or Unit:FilteredTimeToDie(">", BestUnitTTD, TimeToDieOffset));
end

-- Is it worth to DoT the unit?
function Commons.CanDoTUnit(Unit, HealthThreshold)
  return Unit:Health() >= HealthThreshold or Unit:IsDummy();
end

-- Interrupt
function Commons.Interrupt(Range, Spell, Setting, StunSpells)
  if Settings.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(Range) then
    if Spell:IsCastable() then
      if HR.Cast(Spell, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
    elseif Settings.InterruptWithStun and Target:CanBeStunned() then
      if StunSpells then
        for i = 1, #StunSpells do
          if StunSpells[i][1]:IsCastable() and StunSpells[i][3]() then
            if HR.Cast(StunSpells[i][1]) then return StunSpells[i][2]; end
          end
        end
      end
    end
  end
end

-- Is in Solo Mode?
function Commons.IsSoloMode()
  return Settings.SoloMode and not Player:IsInRaidArea() and not Player:IsInDungeonArea();
end

-- Cycle Unit Helper
function Commons.CastCycle(Object, Enemies, Condition, OutofRange, OffGCD, DisplayStyle)
  if Condition(Target) then
    return HR.Cast(Object, OffGCD, DisplayStyle, OutofRange)
  end
  if HR.AoEON() then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(Enemies) do
      if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and Condition(CycleUnit) then
        HR.CastLeftNameplate(CycleUnit, Object)
        break
      end
    end
  end
end

  -- Target If Helper
function Commons.CastTargetIf(Object, Enemies, TargetIfMode, TargetIfCondition, Condition, OutofRange, OffGCD, DisplayStyle)
  local TargetCondition = (not Condition or (Condition and Condition(Target)))
  if not HR.AoEON() and TargetCondition then
    return HR.Cast(Object, OffGCD, DisplayStyle, OutofRange)
  end
  if HR.AoEON() then
    local BestUnit, BestConditionValue = nil, nil
    for _, CycleUnit in pairs(Enemies) do
      if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
        and (not BestConditionValue or Utils.CompareThis(TargetIfMode, TargetIfCondition(CycleUnit), BestConditionValue)) then
        BestUnit, BestConditionValue = CycleUnit, TargetIfCondition(CycleUnit)
      end
    end
    if BestUnit then
      if TargetCondition and (BestUnit:GUID() == Target:GUID() or BestConditionValue == TargetIfCondition(Target)) then
        return HR.Cast(Object, OffGCD, DisplayStyle, OutofRange)
      elseif ((Condition and Condition(BestUnit)) or not Condition) then
        HR.CastLeftNameplate(BestUnit, Object)
      end
    end
  end
end

function Commons.GetCurrentEmpowerData(stage)
  local CurrentStage = 0
  local StagesData = {}
  _, _, _, StartTimeMS, EndTimeMS, _, _, _, _, StageTotal = UnitChannelInfo("player")

  if StageTotal and StageTotal > 0 then
    local LastFinish = 0
    for i = 1, StageTotal do
      StagesData[i] = {
        Start = LastFinish,
        Finish = LastFinish + GetUnitEmpowerStageDuration("player", i - 1) / 1000
      }
      HR.Print(" Start"..i..": "..StagesData[i].Start)
      HR.Print("Finish"..i..": "..StagesData[i].Finish)
      LastFinish = StagesData[i].Finish
      if StartTimeMS / 1000 + LastFinish <= GetTime() then
        CurrentStage = i
      end
    end
  end

  if stage then
    return CurrentStage
  else
    return StagesData
  end
end

-- Check if player's selected potion type is ready
function Commons.PotionSelected()
  local Class = Cache.Persistent.Player.Class[1]
  Class = gsub(Class, "%s+", "")
  local Spec = Cache.Persistent.Player.Spec[2]
  local PotionType = HR.GUISettings.APL[Class][Spec].PotionType.Selected
  local PowerPotionIDs = {
    -- Fleeting Ultimate Power
    191914, 191913, 191912,
    -- Fleeting Power
    191907, 191906, 191905,
    -- Ultimate Power
    191383, 191382, 191381,
    -- Power
    191389, 191388, 191387
  }
  local FrozenFocusIDs = { 191365, 191364, 191363 }
  local ChilledClarityIDs = { 191368, 191367, 191366 }
  local ShockingDisclosureIDs = { 191401, 191400, 191399 }
  if PotionType == "Power" then
    for _, PotionID in ipairs(PowerPotionIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  elseif PotionType == "Frozen Focus" then
    for _, PotionID in ipairs(FrozenFocusIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  elseif PotionType == "Chilled Clarity" then
    for _, PotionID in ipairs(ChilledClarityIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  elseif PotionType == "Shocking Disclosure" then
    for _, PotionID in ipairs(ShockingDisclosureIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  else
    return nil
  end
end
