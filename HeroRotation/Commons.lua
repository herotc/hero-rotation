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
function Commons.CastCycle(Object, Enemies, Condition, OutofRange, OffGCD)
  if Condition(Target) then
    return HR.Cast(Object, OffGCD, nil, OutofRange)
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
function Commons.CastTargetIf(Object, Enemies, TargetIfMode, TargetIfCondition, Condition, OutofRange, OffGCD)
  local TargetCondition = (not Condition or (Condition and Condition(Target)))
  if not HR.AoEON() and TargetCondition then
    return HR.Cast(Object, OffGCD, nil, OutofRange)
  end
  if HR.AoEON() then
    local BestUnit, BestConditionValue = nil, nil
    for _, CycleUnit in pairs(Enemies) do
      if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
        and ((Condition and Condition(CycleUnit)) or not Condition)
        and (not BestConditionValue or Utils.CompareThis(TargetIfMode, TargetIfCondition(CycleUnit), BestConditionValue)) then
        BestUnit, BestConditionValue = CycleUnit, TargetIfCondition(CycleUnit)
      end
    end
    if BestUnit then
      if (BestUnit:GUID() == Target:GUID()) or (TargetCondition and (BestConditionValue == TargetIfCondition(Target))) then
        return HR.Cast(Object, OffGCD, nil, OutofRange)
      else
        HR.CastLeftNameplate(BestUnit, Object)
      end
    end
  end
end
