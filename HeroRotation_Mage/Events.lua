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
--- ======= COMBATLOG HANDLERS =======
-- Combat Log Arguments (for reference)
-- 1: TimeStamp, 2: Event, 3: HideCaster, 4: SourceGUID, 5: SourceName
-- 6: SourceFlags, 7: SourceRaidFlags, 8: DestGUID, 9: DestName
-- 10: DestFlags, 11: DestRaidFlags, 12: SpellID, 13: SpellName
-- 14: SpellSchool, 15: AuraType/Amount/FailedType/ExtraSpellID etc.

--------------------------
-------- Arcane ----------
--------------------------

-- Arcane Harmony Tracker
local ArcaneHarmonyLastStack = 0
local ArcaneHarmonyThresholdNotified = false

-- Touch of the Magi Tracker
local TotMDebuffApplied = nil

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  if not Spell.Mage or not Spell.Mage.Arcane then return end

  local S = Spell.Mage.Arcane

  if spellID and spellID == S.ArcaneHarmonyBuff:ID() then
    local auraData = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID(S.ArcaneHarmonyBuff:ID())
    if auraData then
      ArcaneHarmonyLastStack = auraData.applications or 1

      local threshold = (18 - (6 * num(S.HighVoltage:IsAvailable())))

      if ArcaneHarmonyLastStack >= (threshold - 2) and not ArcaneHarmonyThresholdNotified then
        HR.Print("Approaching optimal Arcane Harmony stacks: " .. ArcaneHarmonyLastStack .. "/" .. threshold)
        ArcaneHarmonyThresholdNotified = true
      elseif ArcaneHarmonyLastStack < (threshold - 2) then
        ArcaneHarmonyThresholdNotified = false
      end
    end
  end

  if event == "SPELL_AURA_REMOVED" and spellID and spellID == S.ArcaneHarmonyBuff:ID() then
    ArcaneHarmonyLastStack = 0
    ArcaneHarmonyThresholdNotified = false
  end
end, "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

HL:RegisterForEvent(function()
  ArcaneHarmonyLastStack = 0
  ArcaneHarmonyThresholdNotified = false
  TotMDebuffApplied = nil
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForCombatEvent(function(...)
  local _, event, _, _, _, _, _, destGUID, _, _, _, spellID = ...
  if not Spell.Mage or not Spell.Mage.Arcane then return end

  local S = Spell.Mage.Arcane

  if spellID and spellID == S.TouchoftheMagiDebuff:ID() then
    local now = GetTime()
    local targetIsTrackedUnit = destGUID and (destGUID == UnitGUID("target") or destGUID == UnitGUID("focus"))

    if event == "SPELL_AURA_APPLIED" and targetIsTrackedUnit then
      TotMDebuffApplied = now
      HR.Print("Touch of the Magi applied, window open!")
    elseif event == "SPELL_AURA_REMOVED" and targetIsTrackedUnit then
      if TotMDebuffApplied then
        local duration = now - TotMDebuffApplied
        HR.Print("Touch of the Magi window closed. Duration: " .. string.format("%.1f", duration) .. "s")
      end
      TotMDebuffApplied = nil
    end
  end
end, "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED")

--------------------------
-------- Frost -----------
--------------------------

-- Frozen Orb Ground Effect Tracking (Disabled)
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

-- TWW Season 2 - Tier Set Tracking
Mage.HasFireTier4PC = false
Mage.HasFireTier2PC = false
Mage.CombustionDamageBonus = false
Mage.RollinHotActive = false
Mage.CombustionCooldown = 120
Mage.CombustionDuration = 10
Mage.JackpotCDRProcs = 0

local function UpdateFireTierStatus()
  if not Spell.Mage or not Spell.Mage.Fire then
    HR.Print("Warning: Spell.Mage.Fire not accessible for tier set detection")
    return
  end

  local S = Spell.Mage.Fire

  Mage.HasFireTier4PC = S.TWW_S2_4pcBuff:IsAvailable()
  Mage.HasFireTier2PC = S.TWW_S2_2pcBuff:IsAvailable()

  if Mage.HasFireTier2PC then
    Mage.CombustionCooldown = 114
    HR.Print("Fire Mage 2pc tier set detected. Combustion cooldown reduced to 114 seconds. Random Jackpot procs may further reduce it.")
  else
    Mage.CombustionCooldown = 120
    Mage.JackpotCDRProcs = 0
  end

  Mage.CombustionDuration = 10

  if Mage.HasFireTier4PC then
    HR.Print("Fire Mage 4pc tier set detected. Combustion grants 15% increased damage for 14 seconds.")

    HL:RegisterForSelfCombatEvent("SPELL_AURA_APPLIED", 383951, 383952)
    HL:RegisterForSelfCombatEvent("SPELL_AURA_REMOVED", 383951, 383952)
  end
end

HL:RegisterForEvent(function()
  UpdateFireTierStatus()
end, "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED")

HL:RegisterForSelfCombatEvent(function(...)
  local _, event, _, _, _, _, _, _, _, _, _, spellID = ...
  if not Spell.Mage or not Spell.Mage.Fire then return end

  local S = Spell.Mage.Fire

  if spellID and spellID == S.CombustionBuff:ID() then
    if event == "SPELL_AURA_APPLIED" then
      if Mage.HasFireTier4PC then
        Mage.CombustionDamageBonus = true
        HR.Print("Combustion active with 15% damage bonus for 14 seconds")
      end
    elseif event == "SPELL_AURA_REMOVED" then
      Mage.CombustionDamageBonus = false
    end
  end

  if spellID and spellID == S.RollinHotBuff:ID() then
    if event == "SPELL_AURA_APPLIED" then
      Mage.RollinHotActive = true
      HR.Print("Jackpot! Rollin' Hot proc - 15% increased damage for 7 seconds")
    elseif event == "SPELL_AURA_REMOVED" then
      Mage.RollinHotActive = false
    end
  end

  if Mage.HasFireTier2PC and event == "SPELL_CAST_SUCCESS" and
     (spellID == S.Fireball:ID() or spellID == S.FireBlast:ID() or
      spellID == S.Pyroblast:ID() or spellID == S.PhoenixFlames:ID()) then

    C_Timer.After(0.1, function()
      if S.Combustion:CooldownRemains() > 0 then
        local currentCD = S.Combustion:CooldownRemains()
        local expectedCD = S.Combustion:CooldownRemains() + 2

        if currentCD < expectedCD - 1.5 and currentCD > expectedCD - 2.5 then
          Mage.JackpotCDRProcs = Mage.JackpotCDRProcs + 1
          HR.Print("Jackpot! Combustion cooldown reduced by 2 seconds. Total procs: " .. Mage.JackpotCDRProcs)
        end
      end
    end)
  end
end, "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED", "SPELL_CAST_SUCCESS")

HL:RegisterForEvent(function()
  Mage.CombustionDamageBonus = false
  Mage.RollinHotActive = false
  Mage.JackpotCDRProcs = 0
  Mage.CombustionDuration = 10
end, "PLAYER_REGEN_ENABLED")

