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
  if Settings.InterruptEnabled then
    if (not Settings.InterruptCycle or not AoEON() or Target:IsInterruptible()) and Target:IsInterruptible() then
      if Spell:IsCastable(true) and Target:IsSpellInRange(Spell) then
        if Cast(Spell, nil, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
      elseif Settings.InterruptWithStun and Target:CanBeStunned() then
        if StunSpells then
          for i = 1, #StunSpells do
            if (StunSpells[i][1]:IsKnown() or StunSpells[i][1]:IsKnown(true)) and StunSpells[i][1]:IsCastable() and Target:IsSpellInRange(StunSpells[i][1]) and StunSpells[i][3]() then
              if Cast(StunSpells[i][1], nil, Setting) then return StunSpells[i][2]; end
            end
          end
        end
      end
    elseif Settings.InterruptCycle and AoEON() then
      local SpellRange = (Spell.MaximumRange and Spell.MaximumRange > 0 and Spell.MaximumRange <= 100) and Spell.MaximumRange or 40
      local Enemies = Player:GetEnemiesInRange(SpellRange)
      local TargetGUID = Target:GUID()
      for _, CycleUnit in pairs(Enemies) do
        if CycleUnit:GUID() ~= TargetGUID and CycleUnit:IsInterruptible() then
          if Spell:IsCastable(true) and CycleUnit:IsSpellInRange(Spell) then
            CastLeftNameplate(CycleUnit, Spell)
            break
          elseif Settings.InterruptWithStun and CycleUnit:CanBeStunned() then
            if StunSpells then
              for i = 1, #StunSpells do
                if (StunSpells[i][1]:IsKnown() or StunSpells[i][1]:IsKnown(true)) and StunSpells[i][1]:IsCastable() and CycleUnit:IsSpellInRange(StunSpells[i][1]) and StunSpells[i][3]() then
                  CastLeftNameplate(CycleUnit, StunSpells[i][1])
                end
              end
            end
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
  local BotBBuffIDs = {
    [1] = 381758, -- Warrior
    [2] = 381752, -- Paladin
    [3] = 381749, -- Hunter (432655 Buff ID exists, but doesn't seem to be used)
    [4] = 381754, -- Rogue
    [5] = 381753, -- Priest
    [6] = 381732, -- Death Knight
    [7] = 381756, -- Shaman (432652? Unverified, but unlikely to be used, like the other extra Buff IDs)
    [8] = 381750, -- Mage
    [9] = 381757, -- Warlock
    [10] = 381751, -- Monk
    [11] = 381746, -- Druid (432658 Buff ID exists, but doesn't seem to be used)
    [12] = 381741, -- Demon Hunter
    [13] = 381748, -- Evoker (432658 Buff ID exists, but doesn't seem to be used)
  }
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
        local _, _, CharClass = Char:Class()
        if Char:BuffUp(Spell(BotBBuffIDs[CharClass]), true) then
          BuffedChars = BuffedChars + 1
        end
      elseif Char:BuffDown(spell, true) then
        return true
      end
    end
  end
  if spell:ID() == 381748 and BuffedChars < TotalChars then return true end
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
  -- TWW Potions
  local TemperedIDs = { 212265, 212264, 212263 }
  local UnwaveringFocusIDs = { 212259, 212258, 212257 }
  local FrontlineIDs = { 212262, 212261, 212260 }
  if PotionType == "Tempered" then
    for _, PotionID in ipairs(TemperedIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  elseif PotionType == "Unwavering Focus" then
    for _, PotionID in ipairs(UnwaveringFocusIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  elseif PotionType == "Frontline" then
    for _, PotionID in ipairs(FrontlineIDs) do
      if Item(PotionID):IsUsable() then
        return Item(PotionID)
      end
    end
  end
  -- DF Potions
  -- Deprecated. Will be removed when all profiles are updated.
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
