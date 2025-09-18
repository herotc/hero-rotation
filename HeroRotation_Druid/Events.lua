--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroLib
local HL               = HeroLib
local HR               = HeroRotation
local Cache            = HeroCache
local Unit             = HL.Unit
local Player           = Unit.Player
local Target           = Unit.Target
local Spell            = HL.Spell
local Item             = HL.Item
-- Lua
local GetTime          = GetTime
-- File Locals
local SpellBalance = Spell.Druid.Balance
HR.Commons.Druid = {}
local Druid = HR.Commons.Druid
Druid.FullMoonLastCast = nil
Druid.OrbitBreakerStacks = 0
Druid.LastDryadSummon = 0
Druid.TreantsTable = {}

--- ============================ CONTENT ============================
--- ===== Orbit Breaker Tracking =====
HL:RegisterForSelfCombatEvent(function(dmgTime, _, _, _, _, _, _, _, _, _, _, spellID)
  if spellID == 202497 then
    Druid.OrbitBreakerStacks = Druid.OrbitBreakerStacks + 1
  end
  if spellID == 274283 then
    if (not SpellBalance.NewMoon:IsAvailable()) or (SpellBalance.NewMoon:IsAvailable() and (Druid.FullMoonLastCast == nil or dmgTime - Druid.FullMoonLastCast > 1.5)) then
      Druid.OrbitBreakerStacks = 0
    end
  end
end, "SPELL_DAMAGE")

HL:RegisterForSelfCombatEvent(function(castTime, _, _, _, _, _, _, _, _, _, _, spellID)
  if spellID == 274283 then
    Druid.FullMoonLastCast = castTime
  end
end, "SPELL_CAST_SUCCESS")

--- ===== Dryad Tracking =====
local DryadSpells = {
  [390414] = true, -- Incarnation (Variante 1)
  [102560] = true, -- Incarnation (Variante 2)
  [383410] = true, -- Celestial Alignment (Variante 1)
  [194223] = true, -- Celestial Alignment (Variante 2)
}
local DryadBuffs = {
  [102560] = true, -- Buff-ID von Incarnation (Variante 1)
  [390414] = true, -- Buff-ID von Incarnation (Variante 2)
  [194223] = true, -- Buff-ID von Celestial Alignment (Variante 1)
  [383410] = true, -- Buff-ID von Celestial Alignment (Variante 2)
}

HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, _, _, _, _, spellID)
  if DryadSpells[spellID] then
    Druid.LastDryadSummon = GetTime()
  end
end, "SPELL_CAST_SUCCESS")

HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, _, _, _, _, spellID)
  if DryadBuffs[spellID] then
    Druid.LastDryadSummon = GetTime()
  end
end, "SPELL_AURA_APPLIED")

--- ===== Treant Tracking =====
HL:RegisterForSelfCombatEvent(function(_, _, _, _, _, _, _, DestGUID, _, _, _, spellID)
  if spellID == 248280 then
    Druid.TreantsTable[DestGUID] = true
  end
end, "SPELL_SUMMON")

HL:RegisterForCombatEvent(function(_, _, _, SourceGUID, _, _, _, DestGUID, _, _, _, spellID)
  if spellID == 205644 and Druid.TreantsTable[DestGUID] then
    Druid.TreantsTable[DestGUID] = nil
  end
end, "SPELL_AURA_REMOVED")

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
