--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL = HeroLib
local Cache = HeroCache
local HR = HeroRotation
local Unit = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Spell = HL.Spell
local Item = HL.Item
HR.Commons.Hunter = {}
local Hunter = HR.Commons.Hunter
-- Lua
local pairs = pairs
local select = select
local wipe = wipe
local GetTime = HL.GetTime
-- Spells
local SpellBM = Spell.Hunter.BeastMastery
local SpellMM = Spell.Hunter.Marksmanship
-- MM Spell Cost Table
HR.Commons.Hunter.MMCost = {}
local MMCost = HR.Commons.Hunter.MMCost
for spell in pairs(SpellMM) do
  if spell ~= "PoolFocus" then
    if SpellMM[spell]:Cost() > 0 then
      local SpellID = SpellMM[spell]:ID()
      MMCost[SpellID] = SpellMM[spell]:Cost()
    end
  end
end

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
        if (SpellID == SpellBM.BeastCleavePetBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.MultiShot:ID())
        or (SpellID == SpellBM.FrenzyPetBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.BarbedShot:ID())
        or (SpellID == SpellBM.BestialWrathPetBuff:ID() and Hunter.PetTable.LastPetSpellID == SpellBM.BestialWrath:ID()) then
          if not PetGUIDs[DestGUID] then
            PetGUIDs[DestGUID] = true
            Hunter.PetTable.LastPetSpellCount = Hunter.PetTable.LastPetSpellCount + 1
          end
        end
      end
    end
    , "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH", "SPELL_AURA_APPLIED_DOSE"
  )

  HL:RegisterForSelfCombatEvent(
    function (...)
      if SpellBM.AnimalCompanion:IsAvailable() then
        SpellID = select(12, ...)
        if SpellID == SpellBM.MultiShot:ID() or SpellID == SpellBM.BarbedShot:ID() or SpellID == SpellBM.BestialWrath:ID() then
          PetGUIDs = {}
          Hunter.PetTable.LastPetSpellID = SpellID
          Hunter.PetTable.LastPetSpellCount = 0
        end
      end
    end
    , "SPELL_CAST_SUCCESS"
  )
end

-- Focused Trickery Counter (Tier 28 4pc bonus)
Hunter.FTCount = 0

-- Set counter to zero when Trick Shots buff is removed
HL:RegisterForSelfCombatEvent(function(...)
  local SpellID = select(12, ...)
  if SpellID == SpellMM.TrickShotsBuff:ID() then
    Hunter.FTCount = 0
  end
end, "SPELL_AURA_REMOVED")

-- Count Focus spent since last Trick Shots
HL:RegisterForSelfCombatEvent(function(...)
  local SpellID = select(12, ...)
  if MMCost[SpellID] ~= nil then
    Hunter.FTCount = Hunter.FTCount + MMCost[SpellID]
  end
end, "SPELL_CAST_SUCCESS")
