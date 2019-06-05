--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
-- Lua

-- File Locals

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
------- Brewmaster -------
--------------------------
HL:RegisterForCombatEvent(
  function (...)
    dateEvent,_,_,_,_,_,_,DestGUID,_,_,_, SpellID = select(1,...);
    if DestGUID == Player:GUID() then -- Only worry about our events
      local timeLimit = 10 + (Spell(280515):IsAvailable() and 3 or 0)
      if GetSpellInfo((select(12, ...)))==(select(13, ...)) then -- Hit by spell
        local absorbedSpell = select(12, ...)
        if select(19, ...) == 115069 then
          BrMAddToPool(0.75 * (select(22, ...)), timeLimit)
        end
      else
        if select(16, ...) == 115069 then -- Melee swing
          BrMAddToPool((select(19, ...)), timeLimit)
        end
      end
    end
  end
  , "SPELL_ABSORBED"
);