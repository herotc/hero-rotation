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
local SpellEnh = Spell.Shaman.Enhancement
-- Lua
local GetTime = GetTime
local C_Timer = C_Timer
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
Shaman.LastMaelstromWeaponStacks = 0
Shaman.SearingTotemActive = false
Shaman.SearingTotemGUID = 0
Shaman.TWW3ProcsToAsc = 8

--- ============================ CONTENT ============================
HL:RegisterForSelfCombatEvent(
  function (_, _, _, SourceGUID, _, _, _, _, _, _, _, SpellID)
    if SourceGUID == Player:GUID() and SpellID == 191634 then
      Shaman.LastSKCast = GetTime()
    end
  end
  , "SPELL_CAST_SUCCESS"
)

HL:RegisterForSelfCombatEvent(
  function (_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
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
  function (_, _, _, _, _, _, _, _, _, _, _, SpellID)
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
  function (_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
    if DestGUID ~= Player:GUID() then return end
    if SpellID == SpellEnh.MoltenWeaponBuff:ID() then
      local AuraData = Player:BuffInfo(SpellEnh.MoltenWeaponBuff, nil, true)
      Shaman.MoltenWeaponStacks = AuraData and (AuraData.applications or 1) or 0
    elseif SpellID == SpellEnh.IcyEdgeBuff:ID() then
      local AuraData = Player:BuffInfo(SpellEnh.IcyEdgeBuff, nil, true)
      Shaman.IcyEdgeStacks = AuraData and (AuraData.applications or 1) or 0
    elseif SpellID == SpellEnh.CracklingSurgeBuff:ID() then
      local AuraData = Player:BuffInfo(SpellEnh.CracklingSurgeBuff, nil, true)
      Shaman.CracklingSurgeStacks = AuraData and (AuraData.applications or 1) or 0
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED", "SPELL_AURA_REMOVED_DOSE"
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
  function (_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
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
  function (_, SubEvent, _, _, _, _, _, _, _, _, _, SpellID, _, _, _, StackAmount)
    if SpellID == SpellEnh.MaelstromWeaponBuff:ID() then
      local CurrentStacks
      if SubEvent == "SPELL_AURA_REMOVED" then
        CurrentStacks = 0
      else
        if StackAmount == nil then
          CurrentStacks = Player:BuffStack(SpellEnh.MaelstromWeaponBuff)
        else
          CurrentStacks = StackAmount
        end
      end
      CurrentStacks = CurrentStacks or 0
      if CurrentStacks > Shaman.LastMaelstromWeaponStacks then
        Shaman.TempestMaelstrom = Shaman.TempestMaelstrom + (CurrentStacks - Shaman.LastMaelstromWeaponStacks)
        if Shaman.TempestMaelstrom >= 40 then
          Shaman.TempestMaelstrom = Shaman.TempestMaelstrom % 40
        end
      end
      Shaman.LastMaelstromWeaponStacks = CurrentStacks
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED", "SPELL_AURA_REMOVED_DOSE"
)

-- ===== Searing Totem Tracker =====
HL:RegisterForSelfCombatEvent(
  function (_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
    if SpellID == 458101 then
      Shaman.SearingTotemActive = true
      Shaman.SearingTotemGUID = DestGUID
    end
  end
  , "SPELL_SUMMON"
)

HL:RegisterForCombatEvent(
  function (_, _, _, _, _, _, _, DestGUID)
    if DestGUID == Shaman.SearingTotemGUID then
      Shaman.SearingTotemActive = false
      Shaman.SearingTotemGUID = 0
    end
  end
  , "UNIT_DIED"
)

--- ===== TWW S3 2pc Proc Tracker =====
HL:RegisterForSelfCombatEvent(
  function (_, _, _, _, _, _, _, _, _, _, _, SpellID, _, _, _, StackCount)
    if Player:HasTier("TWW3", 2) and SpellID == 455130 then
      Shaman.TWW3ProcsToAsc = 8 - StackCount
    end
  end
  , "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE"
)

HL:RegisterForSelfCombatEvent(
  function (_, _, _, _, _, _, _, _, _, _, _, SpellID)
    if SpellID == 455130 then
      Shaman.TWW3ProcsToAsc = 0
    end
  end
  , "SPELL_AURA_REMOVED"
)