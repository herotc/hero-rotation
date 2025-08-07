--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local HR = HeroRotation
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
local Mage = HR.Commons.Mage
-- Lua
local select = select
-- WoW API
local GetTime = GetTime
local C_Timer = C_Timer
local C_UnitAuras = C_UnitAuras
local UnitGUID = UnitGUID
-- Num/Bool Helper Functions
local num = HR.Commons.Everyone.num

-- Create shared table for cross-file variable access (used by Overrides.lua)
if not HR.Commons.Mage.EventInfo then HR.Commons.Mage.EventInfo = {} end
local EventInfo = HR.Commons.Mage.EventInfo

--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======


--- ======= COMBATLOG =======
  --- Combat Log Arguments
    ------- Base -------
      --     1        2         3           4           5           6              7             8         9        10           11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags

    ------- Prefixes -------
      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --    12        13          14
      -- SpellID, SpellName, SpellSchool

    ------- Suffixes -------
      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --     15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --    15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --    15       16
      -- AuraType, Charges

      --- _INTERRUPT
      --      15            16             17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --   15         16         17        18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --   15       16       17       18        19       20        21        22        23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --    15        16           17
      -- MissType, IsOffHand, AmountMissed

    ------- Special -------
      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments

--------------------------
-------- Arcane ----------
--------------------------

--- Arcane Harmony Stack Tracking
-- Tracks Arcane Harmony buff stacks for optimal Arcane Barrage timing
local ArcaneHarmonyLastStack = 0
EventInfo.ArcaneHarmonyLastStack = 0
local ArcaneHarmonyThresholdNotified = false

--- Arcane Surge Tracking
-- Tracks Arcane Surge state for optimal burst windows
local ArcaneSurgeStartTime = 0
EventInfo.ArcaneSurgeStartTime = 0
local ArcaneSurgeActive = false
EventInfo.ArcaneSurgeActive = false

--- Clearcasting Tracking
-- Tracks Clearcasting procs for optimal Arcane Missiles usage
local ClearcastingProcs = 0
EventInfo.ClearcastingProcs = 0
local LastClearcastingTime = 0
EventInfo.LastClearcastingTime = 0

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  local S = Spell.Mage.Arcane
  
  if spellID == S.ArcaneHarmonyBuff:ID() then
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(S.ArcaneHarmonyBuff:ID())
    if auraData then
      ArcaneHarmonyLastStack = auraData.applications or 1
      EventInfo.ArcaneHarmonyLastStack = ArcaneHarmonyLastStack
      local threshold = (18 - (6 * num(S.HighVoltage:IsAvailable())))
      if ArcaneHarmonyLastStack >= (threshold - 2) and not ArcaneHarmonyThresholdNotified then
        ArcaneHarmonyThresholdNotified = true
      elseif ArcaneHarmonyLastStack < (threshold - 2) then
        ArcaneHarmonyThresholdNotified = false
      end
    end
  end
  
  if event == "SPELL_AURA_REMOVED" and spellID == S.ArcaneHarmonyBuff:ID() then
    ArcaneHarmonyLastStack = 0
    EventInfo.ArcaneHarmonyLastStack = 0
    ArcaneHarmonyThresholdNotified = false
  end

  -- Track Arcane Surge state
  if spellID == S.ArcaneSurgeBuff:ID() then
    if event == "SPELL_AURA_APPLIED" then
      ArcaneSurgeStartTime = GetTime()
      EventInfo.ArcaneSurgeStartTime = ArcaneSurgeStartTime
      ArcaneSurgeActive = true
      EventInfo.ArcaneSurgeActive = true
    elseif event == "SPELL_AURA_REMOVED" then
      ArcaneSurgeActive = false
      EventInfo.ArcaneSurgeActive = false
    end
  end

  -- Track Clearcasting procs
  if spellID == S.ClearcastingBuff:ID() then
    if event == "SPELL_AURA_APPLIED" then
      ClearcastingProcs = ClearcastingProcs + 1
      EventInfo.ClearcastingProcs = ClearcastingProcs
      LastClearcastingTime = GetTime()
      EventInfo.LastClearcastingTime = LastClearcastingTime
    elseif event == "SPELL_AURA_REMOVED" then
      ClearcastingProcs = math.max(0, ClearcastingProcs - 1)
      EventInfo.ClearcastingProcs = ClearcastingProcs
    end
  end
end, "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

--- Combat Exit Handler
HL:RegisterForEvent(function()
  ArcaneHarmonyLastStack = 0
  EventInfo.ArcaneHarmonyLastStack = 0
  ArcaneHarmonyThresholdNotified = false
  ArcaneSurgeStartTime = 0
  EventInfo.ArcaneSurgeStartTime = 0
  ArcaneSurgeActive = false
  EventInfo.ArcaneSurgeActive = false
  ClearcastingProcs = 0
  EventInfo.ClearcastingProcs = 0
  LastClearcastingTime = 0
  EventInfo.LastClearcastingTime = 0
end, "PLAYER_REGEN_ENABLED")

--------------------------
--------- Fire -----------
--------------------------

-- Fire Black Tracker
Mage.FBTracker = {
  PrevOne = 0,
  PrevTwo = 0,
  PrevThree = 0
}

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  
  Mage.FBTracker.PrevThree = Mage.FBTracker.PrevTwo
  Mage.FBTracker.PrevTwo = Mage.FBTracker.PrevOne
  Mage.FBTracker.PrevOne = spellID

end, "SPELL_CAST_SUCCESS")

--------------------------
-------- Frost -----------
--------------------------

--- Frozen Orb Ground Effect Tracking (Currently Disabled)
-- This code tracks when Frozen Orb hits targets and calculates remaining time
-- Currently disabled as it's not being used in the rotation
-- Kept for potential future implementation if needed
--[[local FrozenOrbFirstHit = true
local FrozenOrbHitTime = 0

HL:RegisterForSelfCombatEvent(function(...)
  local spellID = select(12, ...)
  if spellID == 84721 and FrozenOrbFirstHit then
    FrozenOrbFirstHit = false
    FrozenOrbHitTime = GetTime()
    C_Timer.After(10, function()
      FrozenOrbFirstHit = true
      FrozenOrbHitTime = 0
    end)
  end
end, "SPELL_DAMAGE")

function Player:FrozenOrbGroundAoeRemains()
  return math.max((FrozenOrbHitTime - (GetTime() - 10) - HL.RecoveryTimer()), 0)
end]]
