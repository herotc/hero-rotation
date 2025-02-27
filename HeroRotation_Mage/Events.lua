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
-- Initialize Mage table if it doesn't exist
HR.Commons.Mage = HR.Commons.Mage or {}
local Mage = HR.Commons.Mage
local FireState = {
  -- Heating Up tracking
  LastCritTime = 0,
  LastCritSpell = 0,
  PendingCrits = 0,
  -- Hot Streak tracking
  HotStreakPending = false,
  LastHotStreakTime = 0,
  -- Spell tracking
  LastFireBlastTime = 0,
  LastPhoenixFlamesTime = 0,
  LastPyroblastTime = 0,
  LastFlamestrikeTime = 0,
  LastFireballTime = 0,
  LastScorchTime = 0,
  -- Combustion phase tracking
  CombustionActive = false,
  CombustionEndTime = 0,
  -- Enhanced mechanics tracking
  InfernalCascadeStacks = 0,
  LastInfernalCascadeTime = 0,
  SearingTouchActive = false,
  ExecutePhaseActive = false,
  -- Spell travel tracking
  InFlightFireballs = 0,
  InFlightPyroblasts = 0,
  LastSpellImpactTime = 0,
}

-- Expose Fire Mage functions to the Mage namespace
function Mage.IsCombustionActive()
  return FireState and FireState.CombustionActive or false
end

--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======

--------------------------
-------- Fire ------------
--------------------------

-- Register Fire Mage combat events
HL:RegisterForSelfCombatEvent(function(...)
  local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = ...
  -- Only process player events
  if sourceGUID ~= Player:GUID() then return end

  local now = GetTime()

  -- Track critical strikes for Heating Up and Hot Streak
  if subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
    local _, _, _, _, _, _, isCrit = select(15, ...)
    if isCrit then
      -- Update crit tracking
      FireState.LastCritTime = now
      FireState.LastCritSpell = spellID
      FireState.PendingCrits = FireState.PendingCrits + 1
      FireState.LastSpellImpactTime = now

      -- Check for Hot Streak conditions
      if FireState.PendingCrits >= 2 then
        FireState.HotStreakPending = true
        FireState.LastHotStreakTime = now
        FireState.PendingCrits = 0
      end

      -- Reset after 10 seconds if no follow-up crit
      C_Timer.After(10, function()
        if GetTime() - FireState.LastCritTime >= 10 then
          FireState.PendingCrits = 0
        end
      end)
    end
  end

  -- Track spell casts and update in-flight trackers
  if subEvent == "SPELL_CAST_SUCCESS" then
    if spellID == 108853 then -- Fire Blast
      FireState.LastFireBlastTime = now
    elseif spellID == 257541 then -- Phoenix Flames
      FireState.LastPhoenixFlamesTime = now
    elseif spellID == 11366 then -- Pyroblast
      FireState.LastPyroblastTime = now
      FireState.InFlightPyroblasts = FireState.InFlightPyroblasts + 1
      -- Reset after travel time
      C_Timer.After(1.5, function()
        FireState.InFlightPyroblasts = max(0, FireState.InFlightPyroblasts - 1)
      end)
    elseif spellID == 2120 then -- Flamestrike
      FireState.LastFlamestrikeTime = now
    elseif spellID == 133 then -- Fireball
      FireState.LastFireballTime = now
      FireState.InFlightFireballs = FireState.InFlightFireballs + 1
      -- Reset after travel time
      C_Timer.After(1, function()
        FireState.InFlightFireballs = max(0, FireState.InFlightFireballs - 1)
      end)
    elseif spellID == 2948 then -- Scorch
      FireState.LastScorchTime = now
    end
  end

  -- Track spell impacts
  if subEvent == "SPELL_DAMAGE" then
    if spellID == 133 or spellID == 11366 then -- Fireball or Pyroblast
      FireState.LastSpellImpactTime = now
    end
  end

  -- Track Combustion and related mechanics
  if spellID == 190319 then -- Combustion
    if subEvent == "SPELL_AURA_APPLIED" then
      FireState.CombustionActive = true
      FireState.CombustionEndTime = now + 10 -- 10 seconds duration
      FireState.InfernalCascadeStacks = 0
    elseif subEvent == "SPELL_AURA_REMOVED" then
      FireState.CombustionActive = false
      FireState.CombustionEndTime = 0
      FireState.InfernalCascadeStacks = 0
    end
  end

  -- Track Infernal Cascade (if talented)
  if spellID == 336832 then -- Infernal Cascade
    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
      FireState.InfernalCascadeStacks = min((FireState.InfernalCascadeStacks or 0) + 1, 3)
      FireState.LastInfernalCascadeTime = now
    elseif subEvent == "SPELL_AURA_REMOVED" then
      FireState.InfernalCascadeStacks = 0
    end
  end

  -- Track execute phase for Searing Touch
  local targetHealthPct = destGUID and UnitHealth(destGUID) and UnitHealthMax(destGUID) and (UnitHealth(destGUID) / UnitHealthMax(destGUID) * 100) or 100
  FireState.SearingTouchActive = targetHealthPct <= 30
  FireState.ExecutePhaseActive = targetHealthPct <= 30
end, "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE", "SPELL_CAST_SUCCESS", "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED")

-- Fire Mage helper functions
-- Crit tracking
function Player:GetPendingCrits()
  return FireState.PendingCrits
end

function Player:TimeSinceLastCrit()
  return GetTime() - FireState.LastCritTime
end

-- Hot Streak tracking
function Player:IsHotStreakPending()
  return FireState.HotStreakPending
end

function Player:TimeSinceLastHotStreak()
  return GetTime() - FireState.LastHotStreakTime
end

-- Combustion tracking
function Player:CombustionRemains()
  if not FireState.CombustionActive then return 0 end
  return max(0, FireState.CombustionEndTime - GetTime())
end

-- Spell timing tracking
function Player:TimeSinceLastFireBlast()
  return GetTime() - FireState.LastFireBlastTime
end

function Player:TimeSinceLastPhoenixFlames()
  return GetTime() - FireState.LastPhoenixFlamesTime
end

function Player:TimeSinceLastPyroblast()
  return GetTime() - FireState.LastPyroblastTime
end

-- In-flight spell tracking
function Player:GetInFlightFireballs()
  return FireState.InFlightFireballs
end

function Player:GetInFlightPyroblasts()
  return FireState.InFlightPyroblasts
end

function Player:TimeSinceLastSpellImpact()
  return GetTime() - FireState.LastSpellImpactTime
end

-- Enhanced mechanics tracking
function Player:GetInfernalCascadeStacks()
  return FireState.InfernalCascadeStacks
end

function Player:IsSearingTouchActive()
  return FireState.SearingTouchActive
end

function Player:IsExecutePhaseActive()
  return FireState.ExecutePhaseActive
end

-- Additional spell timings
function Player:TimeSinceLastFireball()
  return GetTime() - FireState.LastFireballTime
end

function Player:TimeSinceLastScorch()
  return GetTime() - FireState.LastScorchTime
end

--------------------------
-------- Frost -----------
--------------------------

-- Frozen Orb tracking
local FrozenOrbFirstHit = true
local FrozenOrbHitTime = 0
local FrozenOrbActive = false

-- Register event handler for Frozen Orb damage
HL:RegisterForSelfCombatEvent(function(...)
  local spellID = select(12, ...)
  -- 84721 is Frozen Orb damage
  if spellID == 84721 then
    if FrozenOrbFirstHit then
      FrozenOrbFirstHit = false
      FrozenOrbHitTime = GetTime()
      FrozenOrbActive = true
      -- Reset after 10 seconds (duration of Frozen Orb)
      C_Timer.After(10, function()
        FrozenOrbFirstHit = true
        FrozenOrbHitTime = 0
        FrozenOrbActive = false
      end)
    end
  end
end, "SPELL_DAMAGE")

-- Returns the remaining time of Frozen Orb's ground effect
-- @return number Remaining time in seconds
function Player:FrozenOrbGroundAoeRemains()
  if not FrozenOrbActive then return 0 end
  return max((FrozenOrbHitTime + 10 - GetTime() - HL.RecoveryTimer()), 0)
end

-- Returns whether Frozen Orb is currently active
-- @return boolean
function Player:IsFrozenOrbActive()
  return FrozenOrbActive
end

--------------------------
-------- Arcane ----------
--------------------------

-- Arcane section for future implementation
