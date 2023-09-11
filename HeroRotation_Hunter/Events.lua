--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC    = HeroDBC.DBC
-- HeroLib
local HL     = HeroLib
local Cache  = HeroCache
local HR     = HeroRotation
local Unit   = HL.Unit
local Player = Unit.Player
local Target = Unit.Target
local Pet    = Unit.Pet
local Spell  = HL.Spell
local Item   = HL.Item
-- Lua
-- File Locals
HR.Commons.Hunter = {}
local Hunter = HR.Commons.Hunter

Hunter.Pet = {}

-- Pet Statuses are 0 (dismissed), 1 (alive), or 2 (dead)
Hunter.Pet.Status = (Pet:Exists()) and 1 or 0
Hunter.Pet.GUID = (Pet:Exists()) and Pet:GUID() or 0
-- SummonSpells are Call Pet 1-5 and Revive Pet
Hunter.Pet.SummonSpells = { 883, 83242, 83243, 83244, 83245, 982 }

HL:RegisterForSelfCombatEvent(
  function(...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    for _, Spell in pairs(Hunter.Pet.SummonSpells) do
      if SpellID == Spell then
        Hunter.Pet.Status = 1
        Hunter.Pet.GUID = DestGUID
      end
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if SpellID == 2641 then
      Hunter.Pet.Status = 0
      Hunter.Pet.GUID = 0
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForCombatEvent(
  function(...)
    local DestGUID = select(8, ...)
    if DestGUID == Hunter.Pet.GUID then
      Hunter.Pet.Status = 2
      Hunter.Pet.GUID = 0
    end
  end
  , "UNIT_DIED"
)
