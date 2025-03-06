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
-- Tracks Arcane Harmony buff stacks and provides notifications when approaching optimal stack count
-- Optimal stack count varies based on talents (High Voltage reduces required stacks)
-- Used to help players maximize DPS by using Arcane Barrage at the right stack count
local ArcaneHarmonyLastStack = 0
local ArcaneHarmonyThresholdNotified = false

--- Touch of the Magi Tracking
-- Tracks application and removal of Touch of the Magi debuff
-- Provides timing notifications to help maximize damage during the TotM window
-- Only tracks debuff on current target or focus target to avoid misleading notifications
local TotMDebuffApplied = nil

--- Hyperthermia Buff Tracking
-- Tracks application and removal of Hyperthermia buff
-- This buff allows the next Pyroblast to be instant cast regardless of Hot Streak
-- Used in the Fire rotation to determine when to use Pyroblast
local HyperthermiaApplied = nil

--- Hyperthread Wristwraps Tracking
-- Tracks charges of Fire Blast stored in Hyperthread Wristwraps
-- Uses combat log and spell cast events to estimate stored charges
-- Used in Fire rotation to optimize wristwraps usage
local HyperthreadFireBlastCharges = 0

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  local S = Spell.Mage.Arcane
  
  if spellID == S.ArcaneHarmonyBuff:ID() then
    -- Retrieve current stack count from player auras
    -- Uses C_UnitAuras API for reliable stack tracking in patch 11.1.0
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(S.ArcaneHarmonyBuff:ID())
    if auraData then
      ArcaneHarmonyLastStack = auraData.applications or 1
      
      -- Dynamic threshold calculation based on talent selection
      -- High Voltage talent reduces optimal stack count from 18 to 12
      -- Formula: 18 - (6 * talent presence as 0/1)
      local threshold = (18 - (6 * num(S.HighVoltage:IsAvailable())))
      
      -- Notification logic when approaching optimal stack threshold
      -- Notifies player when within 2 stacks of optimal count
      -- Only notifies once per threshold to prevent chat spam
      if ArcaneHarmonyLastStack >= (threshold - 2) and not ArcaneHarmonyThresholdNotified then
        HR.Print("Approaching optimal Arcane Harmony stacks: " .. ArcaneHarmonyLastStack .. "/" .. threshold)
        ArcaneHarmonyThresholdNotified = true
      elseif ArcaneHarmonyLastStack < (threshold - 2) then
        ArcaneHarmonyThresholdNotified = false
      end
    end
  end
  
  -- Reset tracking variables when Arcane Harmony buff expires
  -- Ensures clean state for next buff application
  if event == "SPELL_AURA_REMOVED" and spellID == S.ArcaneHarmonyBuff:ID() then
    ArcaneHarmonyLastStack = 0
    ArcaneHarmonyThresholdNotified = false
  end
end, "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

--- Combat Exit Handler
-- Resets all tracking variables when player leaves combat
-- Ensures clean state for the next combat encounter
-- Prevents stale data from affecting future combat sessions
HL:RegisterForEvent(function()
  ArcaneHarmonyLastStack = 0
  ArcaneHarmonyThresholdNotified = false
  TotMDebuffApplied = nil
  HyperthermiaApplied = nil
  HyperthreadFireBlastCharges = 0
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForCombatEvent(function(...)
  local _, event, _, _, _, _, _, destGUID, _, _, _, spellID = ...
  local S = Spell.Mage.Arcane
  
  if spellID == S.TouchoftheMagiDebuff:ID() then
    local now = GetTime()
    -- Only track debuff on target or focus to avoid misleading notifications
    -- This prevents tracking TotM on random units that aren't the player's focus
    local targetIsTrackedUnit = destGUID == UnitGUID("target") or destGUID == UnitGUID("focus")
    
    if event == "SPELL_AURA_APPLIED" and targetIsTrackedUnit then
      -- Store application timestamp and notify player of burst window opening
      -- This helps players time their burst cooldowns and spells
      TotMDebuffApplied = now
      HR.Print("Touch of the Magi applied, window open!")
    elseif event == "SPELL_AURA_REMOVED" and targetIsTrackedUnit then
      -- Calculate actual duration and notify player of window closure
      -- Formatted to one decimal place for readability
      -- Helps players learn timing for future applications
      if TotMDebuffApplied then
        local duration = now - TotMDebuffApplied
        HR.Print("Touch of the Magi window closed. Duration: " .. string.format("%.1f", duration) .. "s")
      end
      TotMDebuffApplied = nil
    end
  end
end, "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  local S = Spell.Mage.Fire
  
  if spellID == S.HyperthermiaBuff:ID() then
    local now = GetTime()
    
    if event == "SPELL_AURA_APPLIED" then
      HyperthermiaApplied = now
      HR.Print("Hyperthermia applied - Use Pyroblast!")
    elseif event == "SPELL_AURA_REMOVED" then
      HyperthermiaApplied = nil
    end
  end
end, "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

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

--------------------------
-------- Fire -----------
--------------------------

--- Frostfire Empowerment Tracking
-- Tracks application and removal of Frostfire Empowerment buff
-- This buff empowers the next Fireball to deal increased damage
-- Used in the Fire rotation to determine when to use Fireball

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  local S = Spell.Mage.Fire
  
  if spellID == S.FrostfireEmpowermentBuff:ID() then
    local now = GetTime()
    
    if event == "SPELL_AURA_APPLIED" then
      -- Just notify the player, don't store the timestamp
      HR.Print("Frostfire Empowerment active - Cast Fireball!")
    end
  end
end, "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

-- Register for spell cast events to track Fire Blast usage
HL:RegisterForEvent(function(...)
  local spellID = select(12, ...)
  local S = Spell.Mage.Fire
  local I = Item.Mage.Fire
  
  -- If player has Hyperthread Wristwraps equipped, it might store a charge
  if I.HyperthreadWristwraps:IsEquipped() and spellID == S.FireBlast:ID() then
    -- Increment charges stored in wristwraps (max 3 charges can be stored)
    HyperthreadFireBlastCharges = math.min(HyperthreadFireBlastCharges + 1, 3)
    HR.Print("Hyperthread Wristwraps: " .. HyperthreadFireBlastCharges .. " Fire Blast charge(s) stored")
  end
end, "UNIT_SPELLCAST_SUCCEEDED")

-- Reset charges when Hyperthread Wristwraps is used
HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  -- Hyperthread Wristwraps activates spell 300142
  if spellID == 300142 then
    HyperthreadFireBlastCharges = 0
    HR.Print("Hyperthread Wristwraps: Fire Blast charges used")
  end
end, "SPELL_CAST_SUCCESS")

-- Function to get number of Fire Blast charges stored
function Player:GetHyperthreadFireBlastCharges()
  local I = Item.Mage.Fire
  if not I.HyperthreadWristwraps:IsEquipped() then return 0 end
  return HyperthreadFireBlastCharges
end
