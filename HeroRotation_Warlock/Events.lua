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
local find = string.find
local GetTime = GetTime
-- WoW API
local UnitGUID = UnitGUID
-- File Locals
HR.Commons.Warlock = {}
local Warlock = HR.Commons.Warlock

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

HL.ImmolationTable = {
  Destruction = {
    ImmolationDebuff = {},
  }
}

HL.GuardiansTable = {
  --{ID, name, spawnTime, ImpCasts, Duration, despawnTime}
  Pets = {
  },
  ImpCount = 0,
  FelguardDuration = 0,
  DreadstalkerDuration = 0,
  DemonicTyrantDuration = 0,
  VilefiendDuration = 0,
  PitLordDuration = 0,
  Infernal = 0,
  Blasphemy = 0,
  DarkglareDuration = 0,

  -- Used for Wild Imps spawn prediction
  InnerDemonsNextCast = 0,
  ImpsSpawnedFromHoG = 0
}

local PetsData = {
  [98035] = {
    name = "Dreadstalker",
    duration = 12.25
  },
  [55659] = {
    name = "Wild Imp",
    duration = 20
  },
  [143622] = {
    name = "Wild Imp",
    duration = 20
  },
  [17252] = {
    name = "Felguard",
    duration = 17
  },
  [135002] = {
    name = "Demonic Tyrant",
    duration = 15
  },
  [135816] = {
    name = "Vilefiend",
    duration = 15
  },
  [196111] = {
    name = "Pit Lord",
    duration = 10
  },
  [89] = {
    name = "Infernal",
    duration = 30
  },
  [185584] = {
    name = "Blasphemy",
    duration = 8
  },
  [103673] = {
    name = "Darkglare",
    duration = 25
  },
}

--------------------------
----- Destruction --------
--------------------------
-- Immolate OnApply/OnRefresh Listener
HL:RegisterForSelfCombatEvent(
  function (...)
    DestGUID, _, _, _, SpellID = select(8, ...)

    --- Record the Immolate
    if SpellID == 157736 then
      HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = 0
    end
  end
  , "SPELL_AURA_APPLIED"
  , "SPELL_AURA_REFRESH"
)
-- Immolate OnRemove Listener
HL:RegisterForSelfCombatEvent(
  function (...)
    DestGUID, _, _, _, SpellID = select(8, ...)

    -- Removes the Unit from Immolate Table
    if SpellID == 157736 then
      if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
        HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil
      end
    end
  end
  , "SPELL_AURA_REMOVED"
)
-- Immolate OnUnitDeath Listener
HL:RegisterForCombatEvent(
  function (...)
    DestGUID = select(8, ...)
    -- Removes the Unit from Immolate Table
    if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
      HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil
    end
  end
  , "UNIT_DIED"
  , "UNIT_DESTROYED"
)
-- Conflagrate Listener
HL:RegisterForSelfCombatEvent(
  function (...)
    DestGUID, _, _, _, SpellID = select(8, ...)

    -- Add a stack to the table
    if SpellID == 17962 then
      if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
        HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID]+1
      end
    end
  end
  , "SPELL_CAST_SUCCESS"
)

--------------------------
----- Demonology ---------
--------------------------
-- Update the GuardiansTable
function Warlock.UpdatePetTable()
  for key, petTable in pairs(HL.GuardiansTable.Pets) do
    if petTable then
      -- Remove expired pets
      if GetTime() >= petTable.despawnTime then
        if petTable.name == "Wild Imp" then
          HL.GuardiansTable.ImpCount = HL.GuardiansTable.ImpCount - 1
        end
        if petTable.name == "Felguard"  then
          HL.GuardiansTable.FelguardDuration = 0
        elseif petTable.name == "Dreadstalker" then
          HL.GuardiansTable.DreadstalkerDuration = 0
        elseif petTable.name == "Demonic Tyrant" then
          HL.GuardiansTable.DemonicTyrantDuration = 0
        elseif petTable.name == "Vilefiend" then
          HL.GuardiansTable.VilefiendDuration = 0
        elseif petTable.name == "Pit Lord" then
          HL.GuardiansTable.PitLordDuration = 0
        elseif petTable.name == "Infernal" then
          HL.GuardiansTable.InfernalDuration = 0
        elseif petTable.name == "Blasphemy" then
          HL.GuardiansTable.BlasphemyDuration = 0
        elseif petTable.name == "Darkglare" then
          HL.GuardiansTable.DarkglareDuration = 0
        end
        HL.GuardiansTable.Pets[key] = nil
      end
    end
    -- Remove any imp that has casted all of its bolts
    if petTable.ImpCasts <= 0 then
      HL.GuardiansTable.ImpCount = HL.GuardiansTable.ImpCount - 1
      HL.GuardiansTable.Pets[key] = nil
    end
    -- Update Durations
    if GetTime() <= petTable.despawnTime then
      petTable.Duration = petTable.despawnTime - GetTime()
      if petTable.name == "Felguard" then
        HL.GuardiansTable.FelguardDuration = petTable.Duration
      elseif petTable.name == "Dreadstalker" then
        HL.GuardiansTable.DreadstalkerDuration = petTable.Duration
      elseif petTable.name == "Demonic Tyrant" then
        HL.GuardiansTable.DemonicTyrantDuration = petTable.Duration
      elseif petTable.name == "Vilefiend" then
        HL.GuardiansTable.VilefiendDuration = petTable.Duration
      elseif petTable.name == "Pit Lord" then
        HL.GuardiansTable.PitLordDuration = petTable.Duration
      elseif petTable.name == "Infernal" then
        HL.GuardiansTable.InfernalDuration = petTable.Duration
      elseif petTable.name == "Blasphy" then
        HL.GuardiansTable.BlasphemyDuration = petTable.Duration
      elseif petTable.name == "Darkglare" then
        HL.GuardiansTable.DarkglareDuration = petTable.Duration
      end
    end
  end
end

-- Add demon to table
HL:RegisterForSelfCombatEvent(
  function (...)
    local timestamp,Event,_,SourceGUID,_,_,_,UnitPetGUID,_,_,_,SpellID=select(1,...)
    local _, _, _, _, _, _, _, UnitPetID = find(UnitPetGUID, "(%S+)-(%d+)-(%d+)-(%d+)-(%d+)-(%d+)-(%S+)")
    UnitPetID = tonumber(UnitPetID)

    -- Add pet
    if (UnitPetGUID ~= UnitGUID("pet") and Event == "SPELL_SUMMON" and PetsData[UnitPetID]) then
      local summonedPet = PetsData[UnitPetID]
      local petDuration
      if summonedPet.name == "Wild Imp" then
        HL.GuardiansTable.ImpCount = HL.GuardiansTable.ImpCount + 1
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Felguard" then
        HL.GuardiansTable.FelguardDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Dreadstalker" then
        HL.GuardiansTable.DreadstalkerDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Demonic Tyrant" then
        if (SpellID == 265187) then
          HL.GuardiansTable.DemonicTyrantDuration = summonedPet.duration
          petDuration = summonedPet.duration
        end
      elseif summonedPet.name == "Vilefiend" then
        HL.GuardiansTable.VilefiendDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Pit Lord" then
        HL.GuardiansTable.PitLordDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Infernal" then
        HL.GuardiansTable.InfernalDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Blasphemy" then
        HL.GuardiansTable.BlasphemyDuration = summonedPet.duration
        petDuration = summonedPet.duration
      elseif summonedPet.name == "Darkglare" then
        HL.GuardiansTable.DarkglareDuration = summonedPet.duration
        petDuration = summonedPet.duration
      end
      local petTable = {
        ID = UnitPetGUID,
        name = summonedPet.name,
        spawnTime = GetTime(),
        ImpCasts = 5,
        Duration = petDuration,
        despawnTime = GetTime() + tonumber(petDuration)
      }
      table.insert(HL.GuardiansTable.Pets,petTable)
    end

    -- Add 15 seconds and 7 casts to all pets when Tyrant is cast
    if PetsData[UnitPetID] and PetsData[UnitPetID].name == "Demonic Tyrant" then
      for key, petTable in pairs(HL.GuardiansTable.Pets) do
        if (petTable and petTable.name ~= "Demonic Tyrant" and petTable.name ~= "Pit Lord") then
          petTable.despawnTime = petTable.despawnTime + 15
          petTable.ImpCasts = petTable.ImpCasts + 7
        end
      end
    end

    -- Update when next Wild Imp will spawn from Inner Demons talent
    if UnitPetID == 143622 then
      HL.GuardiansTable.InnerDemonsNextCast = GetTime() + 12
    end

    -- Updates how many Wild Imps have yet to spawn from HoG cast
    if UnitPetID == 55659 and HL.GuardiansTable.ImpsSpawnedFromHoG > 0 then
      HL.GuardiansTable.ImpsSpawnedFromHoG = HL.GuardiansTable.ImpsSpawnedFromHoG - 1
    end

    -- Update the pet table
    Warlock.UpdatePetTable()
  end
  , "SPELL_SUMMON"
  , "SPELL_CAST_SUCCESS"
)

-- Decrement ImpCasts and Implosion Listener
HL:RegisterForCombatEvent(
  function (...)
    local SourceGUID,_,_,_,UnitPetGUID,_,_,_,SpellID = select(4, ...)

    -- Check for imp bolt casts
    if SpellID == 104318 then
      for key, petTable in pairs(HL.GuardiansTable.Pets) do
        if SourceGUID == petTable.ID then
          petTable.ImpCasts = petTable.ImpCasts - 1
        end
      end
    end

    -- Clear the imp table upon Implosion cast
    if SourceGUID == Player:GUID() and SpellID == 196277 then
      for key, petTable in pairs(HL.GuardiansTable.Pets) do
        if petTable.name == "Wild Imp" then
          HL.GuardiansTable.Pets[key] = nil
        end
      end
      HL.GuardiansTable.ImpCount = 0
    end

    -- Update the imp table
    Warlock.UpdatePetTable()
  end
  , "SPELL_CAST_SUCCESS"
)

-- Track when we last received PI
Warlock.LastPI = 0
HL:RegisterForCombatEvent(
  function (...)
    DestGUID, _, _, _, SpellID = select(8, ...)

    --- Record the Immolate
    if SpellID == 10060 and DestGUID == Player:GUID() then
      Warlock.LastPI = GetTime()
    end
  end
  , "SPELL_AURA_APPLIED"
  , "SPELL_AURA_REFRESH"
)

-- Keep track how many Soul Shards we have
Warlock.SoulShards = 0
function Warlock.UpdateSoulShards()
  Warlock.SoulShards = Player:SoulShards()
end

-- On Successful HoG cast add how many Imps will spawn
HL:RegisterForSelfCombatEvent(
  function(_, event, _, _, _, _, _, _, _, _, _, SpellID)
    if SpellID == 105174 then
      HL.GuardiansTable.ImpsSpawnedFromHoG = HL.GuardiansTable.ImpsSpawnedFromHoG + (Warlock.SoulShards >= 3 and 3 or Warlock.SoulShards)
    end
  end
  , "SPELL_CAST_SUCCESS"
)
