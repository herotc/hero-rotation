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
local GetTime = GetTime
local C_Timer = C_Timer
local select = select
-- WoW Locals
local Delay = C_Timer.After
-- File Locals
HR.Commons.Shaman = {}
local Shaman = HR.Commons.Shaman
Shaman.LastSKCast = 0
Shaman.LastSKBuff = 0
Shaman.LastRollingThunderTick = 0
Shaman.FeralSpiritCount = 0
Shaman.CracklingSurgeStacks = 0
Shaman.IcyEdgeStacks = 0
Shaman.MoltenWeaponStacks = 0
Shaman.TempestMaelstrom = 0
Shaman.SearingTotemActive = false
Shaman.SearingTotemGUID = 0

--- ============================ CONTENT ============================
HL:RegisterForSelfCombatEvent(
  function (...)
    local SourceGUID, _, _, _, _, _, _, _, SpellID = select(4, ...)
    if SourceGUID == Player:GUID() and SpellID == 191634 then
      Shaman.LastSKCast = GetTime()
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForSelfCombatEvent(
  function (...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    if DestGUID == Player:GUID() and SpellID == 191634 then
      Shaman.LastSKBuff = GetTime()
      Delay(0.1, function()
        if Shaman.LastSKBuff ~= Shaman.LastSKCast then
          Shaman.LastRollingThunderTick = Shaman.LastSKBuff
        end
      end)
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE"
)

--- ===== Wolf and Wolf Buffs Tracker =====
HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == 262627 or SpellID == 426516 then
      -- Note: 262627 is the spell ID for Feral Spirit
      -- Note: 426516 is the spell ID for the extra wolf from Rolling Thunder or TWW S1 4pc
      Shaman.FeralSpiritCount = Shaman.FeralSpiritCount + 1
      Delay(15, function()
        Shaman.FeralSpiritCount = Shaman.FeralSpiritCount - 1
      end)
    end
    if SpellID == 469332 then
      -- Note: 469332 is the spell ID for wolf summoned by Flowing Spirits
      Shaman.FeralSpiritCount = Shaman.FeralSpiritCount + 1
      Delay(8, function()
        Shaman.FeralSpiritCount = Shaman.FeralSpiritCount - 1
      end)
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForCombatEvent(
  function (...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    if DestGUID == Player:GUID() then
      if SpellID == 224125 then -- Molten Weapon Buff
        Shaman.MoltenWeaponStacks = Shaman.MoltenWeaponStacks + 1
      elseif SpellID == 224126 then -- Icy Edge Buff
        Shaman.IcyEdgeStacks = Shaman.IcyEdgeStacks + 1
      elseif SpellID == 224127 then -- Crackling Surge Buff
        Shaman.CracklingSurgeStacks = Shaman.CracklingSurgeStacks + 1
      end
    end
  end
  , "SPELL_AURA_APPLIED"
)

HL:RegisterForCombatEvent(
  function (...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    if DestGUID == Player:GUID() then
      if SpellID == 224125 then -- Molten Weapon Buff
        Shaman.MoltenWeaponStacks = Shaman.MoltenWeaponStacks - 1
      elseif SpellID == 224126 then -- Icy Edge Buff
        Shaman.IcyEdgeStacks = Shaman.IcyEdgeStacks - 1
      elseif SpellID == 224127 then -- Crackling Surge Buff
        Shaman.CracklingSurgeStacks = Shaman.CracklingSurgeStacks - 1
      end
    end
  end
  , "SPELL_AURA_REMOVED"
)

--- ===== Fire Elemental Tracker =====
Shaman.FireElemental = {
  GreaterActive = false,
  LesserActive = false
}
Shaman.StormElemental = {
  GreaterActive = false,
  LesserActive = false
}

HL:RegisterForSelfCombatEvent(
  function (...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    -- Fire Elemental. SpellIDs are without and with Primal Elementalist
    if SpellID == 188592 or SpellID == 118291 then
      Shaman.FireElemental.GreaterActive = true
      Delay(24, function()
        Shaman.FireElemental.GreaterActive = false
      end)
    elseif SpellID == 462992 or SpellID == 462991 then
      Shaman.FireElemental.LesserActive = true
      Delay(12, function()
        Shaman.FireElemental.LesserActive = false
      end)
    -- Storm Elemental. SpellIDs are without and with Primal Elementalist
    elseif SpellID == 157299 or SpellID == 157319 then
      Shaman.StormElemental.GreaterActive = true
      Delay(24, function()
        Shaman.StormElemental.GreaterActive = false
      end)
    elseif SpellID == 462993 or SpellID == 462990 then
      Shaman.StormElemental.LesserActive = true
      Delay(12, function()
        Shaman.StormElemental.LesserActive = false
      end)
    end
  end
  , "SPELL_SUMMON"
)

--- ===== Tempest Maelstrom Counter =====
HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == 344179 then
      Shaman.TempestMaelstrom = Shaman.TempestMaelstrom + 1
      if Shaman.TempestMaelstrom >= 40 then
        Shaman.TempestMaelstrom = Shaman.TempestMaelstrom - 40
      end
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE"
)

-- ===== Searing Totem Tracker =====
HL:RegisterForSelfCombatEvent(
  function (...)
    local DestGUID, DestName, _, _, SpellID = select(8, ...)
    if SpellID == 458101 and DestName == "Searing Totem" then
      Shaman.SearingTotemActive = true
      Shaman.SearingTotemGUID = DestGUID
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForCombatEvent(
  function (...)
    local DestGUID = select(8, ...)
    if DestGUID == Shaman.SearingTotemGUID then
      Shaman.SearingTotemActive = false
      Shaman.SearingTotemGUID = 0
    end
  end
  , "UNIT_DIED"
)
