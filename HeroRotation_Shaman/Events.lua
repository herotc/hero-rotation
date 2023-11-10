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
-- File Locals
HR.Commons.Shaman = {}
local Shaman = HR.Commons.Shaman
Shaman.LastSKCast = 0
Shaman.LastSKBuff = 0
Shaman.LastT302pcBuff = 0
Shaman.FeralSpiritCount = 0

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
      C_Timer.After(0.1, function()
        if Shaman.LastSKBuff ~= Shaman.LastSKCast then
          Shaman.LastT302pcBuff = Shaman.LastSKBuff
        end
      end)
    end
  end
  , "SPELL_AURA_APPLIED"
)

HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == 228562 then
      Shaman.FeralSpiritCount = Shaman.FeralSpiritCount + 1
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForSelfCombatEvent(
  function (...)
    local SpellID = select(12, ...)
    if SpellID == 333957 then
      Shaman.FeralSpiritCount = 0
    end
  end
  , "SPELL_AURA_REMOVED"
)
