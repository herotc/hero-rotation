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
-- GhoulTable
HL.GhoulTable = {
  SummonedGhoul = nil,
  SummonExpiration = nil,
  SummonedGargoyle = nil,
  GargoyleExpiration = nil,
  ApocMagusExpiration = 0,
  ArmyMagusExpiration = 0,
}

--- ============================ CONTENT ============================
--- Ghoul Tracking
HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, destGUID, _, _, _, spellId)
  if spellId == 46585 then
    HL.GhoulTable.SummonedGhoul = destGUID
    -- Unsure if there's any items that could extend the ghouls time past 60 seconds
    HL.GhoulTable.SummonExpiration = GetTime() + 60
  end
  if spellId == 49206 or spellId == 207349 then
    HL.GhoulTable.SummonedGargoyle = destGUID
    HL.GhoulTable.GargoyleExpiration = GetTime() + 25
  end
end, "SPELL_SUMMON")

HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, _, _, _, _, spellId)
  if spellId == 327574 then
    HL.GhoulTable.SummonedGhoul = nil
    HL.GhoulTable.SummonExpiration = nil
  end
  if Player:HasTier(31, 4) and (HL.GhoulTable.ApocMagusExpiration > 0 or HL.GhoulTable.ArmyMagusExpiration > 0) then
    if spellId == 85948 then
      if HL.GhoulTable:ApocMagusActive() then HL.GhoulTable.ApocMagusExpiration = HL.GhoulTable.ApocMagusExpiration + 1 end
      if HL.GhoulTable:ArmyMagusActive() then HL.GhoulTable.ArmyMagusExpiration = HL.GhoulTable.ArmyMagusExpiration + 1 end
    end
    for _, spell in pairs(OneRuneSpenders) do
      if spell == spellId then
        if HL.GhoulTable:ApocMagusActive() then HL.GhoulTable.ApocMagusExpiration = HL.GhoulTable.ApocMagusExpiration + 0.5 end
        if HL.GhoulTable:ArmyMagusActive() then HL.GhoulTable.ArmyMagusExpiration = HL.GhoulTable.ArmyMagusExpiration + 0.5 end
      end
    end
  end
  if Player:HasTier(31, 2) and spellId == 275699 then
    HL.GhoulTable.ApocMagusExpiration = GetTime() + 20
  end
  if Player:HasTier(31, 2) and spellId == 42650 then
    HL.GhoulTable.ArmyMagusExpiration = GetTime() + 30
  end
end, "SPELL_CAST_SUCCESS")

HL:RegisterForCombatEvent(function(_, _, _, _, _, _, _, destGUID)
  if destGUID == HL.GhoulTable.SummonedGhoul then
    HL.GhoulTable.SummonedGhoul = nil
    HL.GhoulTable.SummonExpiration = nil
  end
  if destGUID == HL.GhoulTable.SummonedGargoyle then
    HL.GhoulTable.SummonedGargoyle = nil
    HL.GhoulTable.GargoyleExpiration = nil
  end
end, "UNIT_DESTROYED")

-- Tracker Functions
function HL.GhoulTable:GhoulRemains()
  if HL.GhoulTable.SummonExpiration == nil then return 0 end
  return HL.GhoulTable.SummonExpiration - GetTime()
end

function HL.GhoulTable:GhoulActive()
  return HL.GhoulTable.SummonedGhoul ~= nil and HL.GhoulTable:GhoulRemains() > 0
end

function HL.GhoulTable:GargRemains()
  if HL.GhoulTable.GargoyleExpiration == nil then return 0 end
  return HL.GhoulTable.GargoyleExpiration - GetTime()
end

function HL.GhoulTable:GargActive()
  return HL.GhoulTable.SummonedGargoyle ~= nil and HL.GhoulTable:GargRemains() > 0
end

function HL.GhoulTable:ArmyMagusRemains()
  return HL.GhoulTable.ArmyMagusExpiration - GetTime()
end

function HL.GhoulTable:ArmyMagusActive()
  return HL.GhoulTable:ArmyMagusRemains() > 0
end

function HL.GhoulTable:ApocMagusRemains()
  return HL.GhoulTable.ApocMagusExpiration - GetTime()
end

function HL.GhoulTable:ApocMagusActive()
  return HL.GhoulTable.ApocMagusRemains() > 0
end

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
