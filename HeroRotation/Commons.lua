--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, HR     = ...
local AoEON             = HR.AoEON
local Cast              = HR.Cast
local CastLeftNameplate = HR.CastLeftNameplate
-- HeroLib
local HL                = HeroLib
local Cache, Utils      = HeroCache, HL.Utils
local Unit              = HL.Unit
local Player            = Unit.Player
local Target            = Unit.Target
local Spell             = HL.Spell
local Item              = HL.Item
-- Lua
local pairs             = pairs
local gsub              = string.gsub
-- API
local UnitInParty       = UnitInParty
local UnitInRaid        = UnitInRaid
-- File Locals
HR.Commons              = {}
local Commons           = {}
HR.Commons.Everyone     = Commons
local Settings          = HR.GUISettings.General
local AbilitySettings   = HR.GUISettings.Abilities

--- ============================ CONTENT ============================
-- Num/Bool helper functions
function Commons.num(val)
  if val then return 1 else return 0 end
end

function Commons.bool(val)
  return val ~= 0
end

-- Is the current target valid?
function Commons.TargetIsValid()
  return Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() or HR.GUISettings.General.ForceReadyStatus
end

-- Is the current unit valid during cycle?
function Commons.UnitIsCycleValid(Unit, BestUnitTTD, TimeToDieOffset)
  return not Unit:IsFacingBlacklisted() and not Unit:IsUserCycleBlacklisted() and (not BestUnitTTD or Unit:FilteredTimeToDie(">", BestUnitTTD, TimeToDieOffset))
end

-- Is it worth to DoT the unit?
function Commons.CanDoTUnit(Unit, HealthThreshold)
  return Unit:Health() >= HealthThreshold or Unit:IsDummy()
end

-- Interrupt
function Commons.Interrupt(Spell, Setting, StunSpells)
  if Settings.InterruptEnabled and Target:IsInterruptible() then
    if Spell:IsCastable(true) and Target:IsSpellInRange(Spell) then
      if Cast(Spell, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
    elseif Settings.InterruptWithStun and Target:CanBeStunned() then
      if StunSpells then
        for i = 1, #StunSpells do
          if StunSpells[i][1]:IsCastable() and Target:IsSpellInRange(StunSpells[i][1]) and StunSpells[i][3]() then
            if Cast(StunSpells[i][1]) then return StunSpells[i][2]; end
          end
        end
      end
    end
  end
end

-- Is in Solo Mode?
function Commons.IsSoloMode()
  return Settings.SoloMode and not Player:IsInRaidArea() and not Player:IsInDungeonArea()
end

-- Cycle Unit Helper
function Commons.CastCycle(Object, Enemies, Condition, OutofRange, OffGCD, DisplayStyle)
  if Condition(Target) then
    return Cast(Object, OffGCD, DisplayStyle, OutofRange)
  end
  if AoEON() then
    local TargetGUID = Target:GUID()
    for _, CycleUnit in pairs(Enemies) do
      if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and (not CycleUnit:IsUserCycleBlacklisted()) and Condition(CycleUnit) then
        CastLeftNameplate(CycleUnit, Object)
        break
      end
    end
  end
end

  -- Target If Helper
function Commons.CastTargetIf(Object, Enemies, TargetIfMode, TargetIfCondition, Condition, OutofRange, OffGCD, DisplayStyle)
  local TargetCondition = (not Condition or (Condition and Condition(Target)))
  if not AoEON() and TargetCondition then
    return Cast(Object, OffGCD, DisplayStyle, OutofRange)
  end
  if AoEON() then
    local BestUnit, BestConditionValue = nil, nil
    for _, CycleUnit in pairs(Enemies) do
      if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and (CycleUnit:AffectingCombat() or CycleUnit:IsDummy())
        and (not BestConditionValue or Utils.CompareThis(TargetIfMode, TargetIfCondition(CycleUnit), BestConditionValue)) then
        BestUnit, BestConditionValue = CycleUnit, TargetIfCondition(CycleUnit)
      end
    end
    if BestUnit then
      if TargetCondition and (BestUnit:GUID() == Target:GUID() or BestConditionValue == TargetIfCondition(Target)) then
        return Cast(Object, OffGCD, DisplayStyle, OutofRange)
      elseif ((Condition and Condition(BestUnit)) or not Condition) then
        CastLeftNameplate(BestUnit, Object)
      end
    end
  end
end

function Commons.GroupBuffMissing(spell)
  local range = 40
  local BotBBuffIDs = { 381732, 381741, 381746, 381748, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758, 432652, 432655, 432658, 432674 }
  if spell:ID() == 6673 then range = 100 end
  if Player:BuffDown(spell, true) then return true end
  -- Are we in a party or raid?
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return false
  end
  -- Check for the buff amongst group members.
  local TotalChars = 0
  local BuffedChars = 0
  for _, Char in pairs(Group) do
    if Char:Exists() and not Char:IsDeadOrGhost() and Char:IsInRange(range) then
      TotalChars = TotalChars + 1
      if spell:ID() == 381748 then -- Blessing of the Bronze
        for _, v in pairs(BotBBuffIDs) do
          if Char:BuffUp(Spell(v), true) then
            BuffedChars = BuffedChars + 1
          end
        end
      elseif Char:BuffDown(spell, true) then
        return true
      end
    end
  end
  if BuffedChars < TotalChars then return true end
  return false
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
  local Classes = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "DeathKnight", "Shaman", "Mage", "Warlock", "Monk", "Druid", "DemonHunter", "Evoker" }
  local ClassNum = Cache.Persistent.Player.Class[3]
  local Class = Classes[ClassNum]

  local Specs = {
    -- DeathKnight
    [250] = "Blood", [251] = "Frost", [252] = "Unholy",
    -- DemonHunter
    [577] = "Havoc", [581] = "Vengeance",
    -- Druid
    [102] = "Balance", [103] = "Feral", [104] = "Guardian", [105] = "Restoration", 
    -- Evoker
    [1467] = "Devastation", [1468] = "Preservation", [1473] = "Augmentation",
    -- Hunter
    [253] = "BeastMastery", [254] = "Marksmanship", [255] = "Survival",
    -- Mage
    [62] = "Arcane", [63] = "Fire", [64] = "Frost",
    -- Monk
    [268] = "Brewmaster", [269] = "Windwalker", [270] = "Mistweaver",
    -- Paladin
    [65] = "Holy", [66] = "Protection", [70] = "Retribution",
    --Priest
    [256] = "Discipline", [257] = "Holy", [258] = "Shadow",
    -- Rogue
    [259] = "Assassination", [260] = "Outlaw", [261] = "Subtlety",
    -- Shaman
    [262] = "Elemental", [263] = "Enhancement", [264] = "Restoration",
    -- Warlock
    [265] = "Affliction", [266] = "Demonology", [267] = "Destruction",
    -- Warrior
    [71] = "Arms", [72] = "Fury", [73] = "Protection",
  }
  local SpecNum = Cache.Persistent.Player.Spec[1]
  local Spec = Specs[SpecNum]

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
