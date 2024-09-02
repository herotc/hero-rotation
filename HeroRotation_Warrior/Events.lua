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
-- WoW API
local GetTime = GetTime
local Delay = C_Timer.After
-- File Locals
HR.Commons.Warrior = {}
local Warrior = HR.Commons.Warrior

--- ============================ CONTENT ============================
--- ===== Ravager Tracker =====
Warrior.Ravager = {}

HL:RegisterForSelfCombatEvent(
  function(...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    -- Ravager damage dealt
    if SpellID == 156287 then
      -- If this is the first tick, remove the entry 15 seconds later.
      if not Warrior.Ravager[DestGUID] then
        Delay(15, function()
            Warrior.Ravager[DestGUID] = nil
          end
        )
      end
      -- Record the tick time.
      Warrior.Ravager[DestGUID] = GetTime()
    end
  end
  , "SPELL_DAMAGE"
)

-- Remove the table entry upon unit death, if it still exists.
HL:RegisterForCombatEvent(
  function(...)
    local DestGUID = select(8, ...)
    if Warrior.Ravager[DestGUID] then
      Warrior.Ravager[DestGUID] = nil
    end
  end
  , "UNIT_DIED", "UNIT_DESTROYED"
)

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