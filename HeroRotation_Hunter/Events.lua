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
Hunter.Pet.FeignGUID = 0
-- SummonSpells are Call Pet 1-5 and Revive Pet
Hunter.Pet.SummonSpells = { 883, 83242, 83243, 83244, 83245, 982 }

HL:RegisterForSelfCombatEvent(
  function(...)
    local _, _, _, _, _, _, _, DestGUID, _, _, _, SpellID = ...
    for _, Spell in pairs(Hunter.Pet.SummonSpells) do
      if SpellID == Spell then
        Hunter.Pet.Status = 1
        Hunter.Pet.GUID = DestGUID
        Hunter.Pet.FeignGUID = 0
      end
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForSelfCombatEvent(
  function(...)
    local _, _, _, _, _, _, _, _, _, _, _, SpellID = ...
    if SpellID == 2641 then
      Hunter.Pet.Status = 0
      Hunter.Pet.GUID = 0
      Hunter.Pet.FeignGUID = 0
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForCombatEvent(
  function(...)
    local _, _, _, _, _, _, _, DestGUID = ...
    if DestGUID == Hunter.Pet.GUID then
      Hunter.Pet.Status = 2
      Hunter.Pet.GUID = 0
    end
  end
  , "UNIT_DIED"
)

HL:RegisterForEvent(
  function(...)
    local _, CasterUnit, _, SpellID = ...
    if CasterUnit ~= "player" then return end
    if SpellID == 209997 then
      Hunter.Pet.FeignGUID = Hunter.Pet.GUID
    end
    if SpellID == 210000 and Hunter.Pet.FeignGUID ~= 0 then
      Hunter.Pet.GUID = Hunter.Pet.FeignGUID
      Hunter.Pet.FeignGUID = 0
      Hunter.Pet.Status = 1
    end
  end
  , "UNIT_SPELLCAST_SUCCEEDED"
)
