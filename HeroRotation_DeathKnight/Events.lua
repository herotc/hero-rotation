--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
-- Lua
-- WoW API
local GetTime = GetTime
-- File Locals
local OneRuneSpenders = { 42650, 55090, 207311, 43265, 152280, 77575, 115989, 45524, 3714, 343294, 111673 }
-- Commons
local HR = HeroRotation
HR.Commons.DeathKnight = {}
local DeathKnight = HR.Commons.DeathKnight
-- GhoulTable
DeathKnight.GhoulTable = {
  AbominationExpiration = 0,
  ApocMagusExpiration = 0,
  ArmyMagusExpiration = 0,
  GargoyleExpiration = 0,
  SummonExpiration = 0,
  SummonedAbomination = nil,
  SummonedGargoyle = nil,
  SummonedGhoul = nil,
}
-- DnDTable
DeathKnight.DnDTable = {}
-- BonestormTable
DeathKnight.BonestormTable = {}

--- ============================ CONTENT ============================
--- ===== Ghoul Tracking =====
HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, destGUID, _, _, _, spellId)
  if spellId == 46585 then
    DeathKnight.GhoulTable.SummonedGhoul = destGUID
    -- Unsure if there's any items that could extend the ghouls time past 60 seconds
    DeathKnight.GhoulTable.SummonExpiration = GetTime() + 60
  end
  if spellId == 49206 or spellId == 207349 then
    DeathKnight.GhoulTable.SummonedGargoyle = destGUID
    DeathKnight.GhoulTable.GargoyleExpiration = GetTime() + 25
  end
  if spellId == 455395 then
    DeathKnight.GhoulTable.SummonedAbomination = destGUID
    DeathKnight.GhoulTable.AbominationExpiration = GetTime() + 30
  end
end, "SPELL_SUMMON")

HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, _, _, _, _, spellId)
  if spellId == 327574 then
    DeathKnight.GhoulTable.SummonedGhoul = nil
    DeathKnight.GhoulTable.SummonExpiration = 0
  end
  if Player:HasTier(31, 4) and (DeathKnight.GhoulTable.ApocMagusExpiration > 0 or DeathKnight.GhoulTable.ArmyMagusExpiration > 0) then
    if spellId == 85948 then
      if DeathKnight.GhoulTable:ApocMagusActive() then DeathKnight.GhoulTable.ApocMagusExpiration = DeathKnight.GhoulTable.ApocMagusExpiration + 1 end
      if DeathKnight.GhoulTable:ArmyMagusActive() then DeathKnight.GhoulTable.ArmyMagusExpiration = DeathKnight.GhoulTable.ArmyMagusExpiration + 1 end
    end
    for _, spell in pairs(OneRuneSpenders) do
      if spell == spellId then
        if DeathKnight.GhoulTable:ApocMagusActive() then DeathKnight.GhoulTable.ApocMagusExpiration = DeathKnight.GhoulTable.ApocMagusExpiration + 0.5 end
        if DeathKnight.GhoulTable:ArmyMagusActive() then DeathKnight.GhoulTable.ArmyMagusExpiration = DeathKnight.GhoulTable.ArmyMagusExpiration + 0.5 end
      end
    end
  end
  if Player:HasTier(31, 2) and spellId == 275699 then
    DeathKnight.GhoulTable.ApocMagusExpiration = GetTime() + 20
  end
  if Player:HasTier(31, 2) and spellId == 42650 then
    DeathKnight.GhoulTable.ArmyMagusExpiration = GetTime() + 30
  end
end, "SPELL_CAST_SUCCESS")

HL:RegisterForCombatEvent(function(_, _, _, _, _, _, _, destGUID)
  if destGUID == DeathKnight.GhoulTable.SummonedGhoul then
    DeathKnight.GhoulTable.SummonedGhoul = nil
    DeathKnight.GhoulTable.SummonExpiration = 0
  end
  if destGUID == DeathKnight.GhoulTable.SummonedGargoyle then
    DeathKnight.GhoulTable.SummonedGargoyle = nil
    DeathKnight.GhoulTable.GargoyleExpiration = 0
  end
  if destGUID == DeathKnight.GhoulTable.SummonedAbomination then
    DeathKnight.GhoulTable.SummonedAbomination = nil
    DeathKnight.GhoulTable.AbominationExpiration = 0
  end
end, "UNIT_DESTROYED")

--- ===== Ghoul Tracker Functions =====
function DeathKnight.GhoulTable:AbomRemains()
  if DeathKnight.GhoulTable.AbominationExpiration == 0 then return 0 end
  return DeathKnight.GhoulTable.AbominationExpiration - GetTime()
end

function DeathKnight.GhoulTable:AbomActive()
  return DeathKnight.GhoulTable.SummonedAbomination ~= nil and DeathKnight.GhoulTable:AbomRemains() > 0
end

function DeathKnight.GhoulTable:ApocMagusRemains()
  return DeathKnight.GhoulTable.ApocMagusExpiration - GetTime()
end

function DeathKnight.GhoulTable:ApocMagusActive()
  return DeathKnight.GhoulTable.ApocMagusRemains() > 0
end

function DeathKnight.GhoulTable:ArmyMagusRemains()
  return DeathKnight.GhoulTable.ArmyMagusExpiration - GetTime()
end

function DeathKnight.GhoulTable:ArmyMagusActive()
  return DeathKnight.GhoulTable:ArmyMagusRemains() > 0
end

function DeathKnight.GhoulTable:GargRemains()
  if DeathKnight.GhoulTable.GargoyleExpiration == 0 then return 0 end
  return DeathKnight.GhoulTable.GargoyleExpiration - GetTime()
end

function DeathKnight.GhoulTable:GargActive()
  return DeathKnight.GhoulTable.SummonedGargoyle ~= nil and DeathKnight.GhoulTable:GargRemains() > 0
end

function DeathKnight.GhoulTable:GhoulRemains()
  if DeathKnight.GhoulTable.SummonExpiration == 0 then return 0 end
  return DeathKnight.GhoulTable.SummonExpiration - GetTime()
end

function DeathKnight.GhoulTable:GhoulActive()
  return DeathKnight.GhoulTable.SummonedGhoul ~= nil and DeathKnight.GhoulTable:GhoulRemains() > 0
end

--- ===== Death and Decay/Bonestorm Tracking =====
HL:RegisterForCombatEvent(function(_, _, _, srcGUID, _, _, _, destGUID, _, _, _, spellId)
  if srcGUID == Player:GUID() then
    -- Death and Decay
    if spellId == 52212 then
      DeathKnight.DnDTable[destGUID] = GetTime()
    -- Defile
    elseif spellId == 156000 then
      DeathKnight.DnDTable[destGUID] = GetTime()
    -- Bonestorm
    elseif spellId == 196528 then
      DeathKnight.BonestormTable[destGUID] = GetTime()
    end
  end
end, "SPELL_DAMAGE")

HL:RegisterForCombatEvent(function(_, _, _, _, _, _, _, destGUID)
  if DeathKnight.DnDTable[destGUID] then
    DeathKnight.DnDTable[destGUID] = nil
  end
end, "UNIT_DIED", "UNIT_DESTROYED")  

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
