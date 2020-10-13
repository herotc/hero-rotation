--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local HR = HeroRotation;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
HR.Commons.Hunter = {};
local Hunter = HR.Commons.Hunter;
-- Lua
local pairs = pairs;
local select = select;
local wipe = wipe;
local GetTime = HL.GetTime;
-- Spells
local SpellBM = Spell.Hunter.BeastMastery;

-- Animal Companion Listener
do
  Hunter.PetTable = {
    LastPetSpellID = 0,
    LastPetSpellCount = 0
  }

  local DestGUID, SpellID;
  local PetGUIDs = {};

  HL:RegisterForSelfCombatEvent(
    function (...)
      if SpellBM.AnimalCompanion:IsAvailable() then
        DestGUID, _, _, _, SpellID = select(8, ...);
        if (SpellID == SpellBM.BeastCleaveBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.Multishot:ID())
        or (SpellID == SpellBM.FrenzyBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.BarbedShot:ID())
        or (SpellID == SpellBM.BestialWrathPetBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.BestialWrath:ID()) then
          if not PetGUIDs[DestGUID] then
            PetGUIDs[DestGUID] = true
            Hunter.PetTable.LastPetSpellCount = Hunter.PetTable.LastPetSpellCount + 1
          end
        end
      end
    end
    , "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_APPLIED_DOSE"
  );

  HL:RegisterForSelfCombatEvent(
    function (...)
      if SpellBM.AnimalCompanion:IsAvailable() then
        SpellID = select(12, ...)
        if SpellID == SpellBM.Multishot:ID() or SpellID == SpellBM.BarbedShot:ID() or SpellID == SpellBM.BestialWrath:ID() then
          PetGUIDs = {}
          Hunter.PetTable.LastPetSpellID = SpellID
          Hunter.PetTable.LastPetSpellCount = 0
        end
      end
    end
    , "SPELL_CAST_SUCCESS"
  );
end
