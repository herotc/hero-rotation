--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local HR = HeroRotation
local Cache = HeroCache
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
-- Lua
-- File Locals
HR.Commons.Priest = {}
local Priest = HR.Commons.Priest
Priest.Archon4pcStacks = 0
local SpellShadow = Spell.Priest.Shadow

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

  -- Arguments Variables

--------------------------
--------- Shadow ---------
--------------------------

-- Archon 4pc Helper
HL:RegisterForSelfCombatEvent(
  function(...)
    if Player:HeroTreeID() == 19 then
      local Event, _, SourceGUID, _, _, _, DestGUID, _, _, _, SpellID = select(2, ...)
      if Event == "SPELL_AURA_REMOVED" and SpellID == SpellShadow.PowerSurgeBuff:ID() then
        -- Power Surge removed, reset variable
        Priest.Archon4pcStacks = 0
      elseif Event == "SPELL_CAST_SUCCESS" and SpellID == SpellShadow.DevouringPlague:ID() then
        -- Each cast of Devouring Plague increases the stacks by 1
        Priest.Archon4pcStacks = Priest.Archon4pcStacks + 1
      end
    end
  end
  , "SPELL_AURA_REMOVED"
  , "SPELL_CAST_SUCCESS"
)
