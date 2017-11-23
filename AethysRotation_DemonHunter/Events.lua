--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- Lua
  local pairs = pairs;
  local select = select;
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

--- Chaos Strike Refund Energy Prediction
-- Variables
Player.CSPrediction = {
  CritCount = 0;
};

local ChaosStrikeMHDamageID = 222031;
local AnnihilationMHDamageID = 227518;
local ChaosStrikeEnergizeId = 193840;

-- Return CS adjusted Fury Predicted
function Player:FuryWithCSRefund()
    return math.min(Player:Fury() + Player.CSPrediction.CritCount * 20, Player:FuryMax());
end

-- Return CS adjusted Fury Deficit Predicted
function Player:FuryDeficitWithCSRefund()
    return math.max(Player:FuryDeficit() - Player.CSPrediction.CritCount * 20, 0);
end

-- Zero CSPrediction after receiving any Chaos Strike energize
AC:RegisterForSelfCombatEvent(
  function (...)
    local rsspellid = select(12, ...)
    if (rsspellid == ChaosStrikeEnergizeId) then
      Player.CSPrediction.CritCount = 0;
      --AC.Print("Refund!");
    end
  end
  , "SPELL_ENERGIZE"
);

-- Set CSPrediction on the MH impact from Chaos Strike or Annihilation
AC:RegisterForSelfCombatEvent(
  function (...)
    local spellID = select(12, ...)
    local spellCrit = select(21, ...)
    if (spellCrit and (spellID == ChaosStrikeMHDamageID or spellID == AnnihilationMHDamageID)) then
      Player.CSPrediction.CritCount = Player.CSPrediction.CritCount + 1;
      --AC.Print("Crit!");
    end
  end
  , "SPELL_DAMAGE"
);
