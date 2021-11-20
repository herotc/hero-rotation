--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL = HeroLib
local Cache, Utils = HeroCache, HL.Utils
local Unit = HL.Unit
local Player, Pet, Target = Unit.Player, Unit.Pet, Unit.Target
local Focus, MouseOver = Unit.Focus, Unit.MouseOver
local Arena, Boss, Nameplate = Unit.Arena, Unit.Boss, Unit.Nameplate
local Party, Raid = Unit.Party, Unit.Raid
local Spell = HL.Spell
local Item = HL.Item
-- Lua
local C_Timer = C_Timer
local tableremove = table.remove
local tableinsert = table.insert
-- WoW API
local GetTime = GetTime
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
local StaggerSpellID = 115069
local StaggerDoTID = 124255
local BobandWeave = Spell(280515)
local StaggerFull = 0
local StaggerDamage = {}
local IncomingDamage = {}

local function RegisterStaggerFullAbsorb(Amount)
  local StaggerDuration = 10 + (BobandWeave:IsAvailable() and 3 or 0)
  StaggerFull = StaggerFull + Amount
  C_Timer.After(StaggerDuration, function() StaggerFull = StaggerFull - Amount; end)
end

local function RegisterStaggerDamageTaken(Amount)
  if #StaggerDamage == 10 then
    tableremove(StaggerDamage, 10)
  end
  tableinsert(StaggerDamage, 1, Amount)
end

local function RegisterIncomingDamageTaken(Amount)
  while #IncomingDamage > 0 and IncomingDamage[#IncomingDamage][1] < GetTime() - 6 do
    tableremove(IncomingDamage, #IncomingDamage)
  end
  tableinsert(IncomingDamage, 1, {GetTime(), Amount})
end

function Player:StaggerFull()
  return StaggerFull
end

function Player:StaggerLastTickDamage(Count)
  local TickDamage = 0
  if Count > #StaggerDamage then
    Count = #StaggerDamage
  end
  for i=1, Count do
    TickDamage = TickDamage + StaggerDamage[i]
  end
  return TickDamage
end

function Player:IncomingDamageTaken(Milliseconds)
  local DamageTaken = 0
  local TimeOffset = Milliseconds / 1000
  for i=1, #IncomingDamage do
    if IncomingDamage[i][1] > GetTime() - TimeOffset then
      DamageTaken = DamageTaken + IncomingDamage[i][2]
    end
  end
  return DamageTaken
end

HL:RegisterForCombatEvent(
  function (...)
    local args = {...}
    -- Absorb is coming from a spell damage
    if #args == 23 then
      local _, _, _, _, _, _, _, DestGUID, _, _, _, _, _, _, _, _, _, _, SpellID, _, _, Amount = ...
      if DestGUID == Player:GUID() and SpellID == StaggerSpellID then
        RegisterStaggerFullAbsorb(Amount)
      end
    else
      local _, _, _, _, _, _, _, DestGUID, _, _, _, _, _, _, _, SpellID, _, _, Amount = ...
      if DestGUID == Player:GUID() and SpellID == StaggerSpellID then
        RegisterStaggerFullAbsorb(Amount)
      end
    end
  end
  , "SPELL_ABSORBED"
)

HL:RegisterForCombatEvent(
  function(...)
    local _, _, _, _, _, _, _, DestGUID, _, _, _, SpellID, _, _, Amount = ...
    if DestGUID == Player:GUID() and SpellID == StaggerDoTID and Amount > 0 then
      RegisterStaggerDamageTaken(Amount)
    end
  end
  , "SPELL_PERIODIC_DAMAGE"
)

HL:RegisterForCombatEvent(
  function(...)
    local _, _, _, _, _, _, _, DestGUID, _, _, _, _, _, _, Amount = ...
    if Cache.Persistent.Player.Spec[1] == 268 and DestGUID == Player:GUID() and Amount ~= nil and Amount > 0 then
      RegisterIncomingDamageTaken(Amount)
    end
  end
  , "SWING_DAMAGE"
  , "SPELL_DAMAGE"
  , "SPELL_PERIODIC_DAMAGE"
)

HL:RegisterForEvent(
  function()
    if #StaggerDamage > 0 then
      for i=0, #StaggerDamage do
        StaggerDamage[i]=nil
      end
    end
    if #IncomingDamage > 0 then
      for i=0, #IncomingDamage do
        IncomingDamage[i]=nil
      end
    end
  end
  , "PLAYER_REGEN_ENABLED"
)
