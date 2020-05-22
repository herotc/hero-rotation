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

-- Stagger Tracker
local StaggerSpellID = 115069;
local BobandWeave = Spell(280515);
local StaggerFull = 0;

local function RegisterStaggerFullAbsorb (Amount)
  local StaggerDuration = 10 + (BobandWeave:IsAvailable() and 3 or 0);
  StaggerFull = StaggerFull + Amount;
  C_Timer.After(StaggerDuration, function() StaggerFull = StaggerFull - Amount; end)
end

function Player:StaggerFull ()
  return StaggerFull;
end

HL:RegisterForCombatEvent(
  function (...)
    local args = {...}

    -- Absorb is coming from a spell damage
    if #args == 23 then
      -- 1          2      3           4           5           6            7                8         9         10         11             12             13               14                 15                16                17                 18                     19       20         21           22
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags, AbsorbSpellId, AbsorbSpellName, AbsorbSpellSchool, AbsorbSourceGUID, AbsorbSourceName, AbsorbSourceFlags, AbsorbSourceRaidFlags, SpellID, SpellName, SpellSchool, Amount
      local _, _, _, _, _, _, _, DestGUID, _, _, _, _, _, _, _, _, _, _, SpellID, _, _, Amount = ...

      if DestGUID == Player:GUID() and SpellID == StaggerSpellID then
        RegisterStaggerFullAbsorb(Amount)
      end
    else
      -- 1          2      3           4           5           6            7                8         9         10         11             12                13                14                 15                     16       17         18           19
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags, AbsorbSourceGUID, AbsorbSourceName, AbsorbSourceFlags, AbsorbSourceRaidFlags, SpellID, SpellName, SpellSchool, Amount
      local _, _, _, _, _, _, _, DestGUID, _, _, _, _, _, _, _, SpellID, _, _, Amount = ...

      if DestGUID == Player:GUID() and SpellID == StaggerSpellID then
        RegisterStaggerFullAbsorb(Amount)
      end
    end
  end
  , "SPELL_ABSORBED"
);
