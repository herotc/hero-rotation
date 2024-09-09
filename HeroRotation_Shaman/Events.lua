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
-- File Locals
HR.Commons.Shaman = {}
local Shaman = HR.Commons.Shaman
Shaman.LastSKCast = 0
Shaman.LastSKBuff = 0
Shaman.LastRollingThunderTick = 0
Shaman.FeralSpiritCount = 0
Shaman.TempestMaelstrom = 0

--- ============================ CONTENT ============================
HL:RegisterForSelfCombatEvent(
  function (...)
    local SourceGUID, _, _, _, _, _, _, _, SpellID = select(4, ...)
    if SourceGUID == Player:GUID() and SpellID == 191634 then
      Shaman.LastSKCast = GetTime()
    end
    if Player:HasTier(31, 2) and SourceGUID == Player:GUID() and SpellID == 375982 then
      Shaman.FeralSpiritCount = Shaman.FeralSpiritCount + 1
      C_Timer.After(15, function()
        Shaman.FeralSpiritCount = Shaman.FeralSpiritCount - 1
      end)
    end
    if SourceGUID == Player:GUID() and SpellID == 51533 then
      Shaman.FeralSpiritCount = Shaman.FeralSpiritCount + 2
      C_Timer.After(15, function()
        Shaman.FeralSpiritCount = Shaman.FeralSpiritCount - 2
      end)
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForSelfCombatEvent(
  function (...)
    local DestGUID, _, _, _, SpellID = select(8, ...)
    if DestGUID == Player:GUID() and SpellID == 191634 then
      Shaman.LastSKBuff = GetTime()
      C_Timer.After(0.1, function()
        if Shaman.LastSKBuff ~= Shaman.LastSKCast then
          Shaman.LastRollingThunderTick = Shaman.LastSKBuff
        end
      end)
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE"
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
      C_Timer.After(30, function()
        Shaman.FireElemental.GreaterActive = false
      end)
    elseif SpellID == 462992 or SpellID == 462991 then
      Shaman.FireElemental.LesserActive = true
      C_Timer.After(15, function()
        Shaman.FireElemental.LesserActive = false
      end)
    -- Storm Elemental. SpellIDs are without and with Primal Elementalist
    elseif SpellID == 157299 or SpellID == 157319 then
      Shaman.StormElemental.GreaterActive = true
      C_Timer.After(30, function()
        Shaman.StormElemental.GreaterActive = false
      end)
    elseif SpellID == 462993 or SpellID == 462990 then
      Shaman.StormElemental.LesserActive = true
      C_Timer.After(15, function()
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
