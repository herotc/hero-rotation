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

  -- Arguments Variables
  -- I referenced the warlock events file, not sure if this is correct
  HL.GhoulTable = {
    SummonedGhoul = nil,
    SummonExpiration = nil,
    SummonedGargoyle = nil,
    GargoyleExpiration = nil,
  }

  function HL.GhoulTable:remains()
    if HL.GhoulTable.SummonExpiration == nil then return 0 end
    return HL.GhoulTable.SummonExpiration - GetTime()
  end

  function HL.GhoulTable:active()
    return HL.GhoulTable.SummonedGhoul ~= nil and HL.GhoulTable:remains() > 0
  end

  function HL.GhoulTable:gargremains()
    if HL.GhoulTable.GargoyleExpiration == nil then return 0 end
    return HL.GhoulTable.GargoyleExpiration - GetTime()
  end

  function HL.GhoulTable:gargactive()
    return HL.GhoulTable.SummonedGargoyle ~= nil and HL.GhoulTable:gargremains() > 0
  end
