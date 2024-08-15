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
local C_TimerAfter = C_Timer.After
local GetTime      = GetTime
local select       = select
-- File Locals
HR.Commons.Hunter  = {}
local Hunter       = HR.Commons.Hunter

--- ===== Pet Tracker =====
Hunter.Pet = {}

-- Pet Statuses are 0 (dismissed), 1 (alive), 2 (dead/feigned), or 3 (player died)
Hunter.Pet.Status = (Pet:IsActive()) and 1 or 0
Hunter.Pet.GUID = (Pet:IsActive()) and Pet:GUID() or 0
Hunter.Pet.FeignGUID = 0
-- SummonSpells are Call Pet 1-5 and Revive Pet
Hunter.Pet.SummonSpells = { 883, 83242, 83243, 83244, 83245, 982 }
local P = Hunter.Pet

HL:RegisterForSelfCombatEvent(
  function(...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    for _, Spell in pairs(P.SummonSpells) do
      if SpellID == Spell then
        P.Status = 1
        P.GUID = DestGUID
        P.FeignGUID = 0
      end
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForEvent(
  function()
    if P.Status == 0 and Pet:IsActive() then
      P.Status = 1
      P.GUID = Pet:GUID()
      P.FeignGUID = 0
    end
  end
  , "SPELLS_CHANGED"
)

HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if SpellID == 2641 then
      -- Delay for 1s, as SPELL_CAST_SUCCESS fires before SPELLS_CHANGED when casting Dismiss Pet.
      C_TimerAfter(1, function()
        P.Status = 0
        P.GUID = 0
        P.FeignGUID = 0
      end)
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForCombatEvent(
  function(...)
    local DestGUID = select(8, ...)
    if DestGUID == P.GUID then
      P.Status = 2
      P.GUID = 0
    elseif DestGUID == Player:GUID() and P.Status == 1 then
      P.Status = 3
      P.GUID = 0
    end
  end
  , "UNIT_DIED"
)

HL:RegisterForEvent(
  function(...)
    local _, CasterUnit, _, SpellID = ...
    if CasterUnit ~= "player" then return end
    if SpellID == 209997 then
      P.FeignGUID = P.GUID
    end
    if SpellID == 210000 and P.FeignGUID ~= 0 then
      P.GUID = P.FeignGUID
      P.FeignGUID = 0
      P.Status = 1
    end
  end
  , "UNIT_SPELLCAST_SUCCEEDED"
)

HL:RegisterForEvent(
  function()
    -- CHALLENGE_MODE_START is called at the start of a Mythic+ dungeon, which despawns the pet
    P.GUID = 0
    P.FeignGUID = 0
    P.Status = 0
  end
  , "CHALLENGE_MODE_START"
)

--- ===== Steady Focus Tracker =====
Hunter.SteadyFocus = {}
Hunter.SteadyFocus.Count = 0
Hunter.SteadyFocus.LastCast = 0
local SF = Hunter.SteadyFocus

HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if SpellID == 56641 then
      SF.Count = SF.Count + 1
      SF.LastCast = GetTime()
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    -- If Steady Focus buff is applied, reset the tracker
    if SpellID == 193534 then
      SF.Count = 0
      SF.LastCast = 0
    end
  end
  , "SPELL_AURA_APPLIED"
)
