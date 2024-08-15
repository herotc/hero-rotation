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
local mathmax          = math.max
local select           = select
-- File Locals
HR.Commons.DemonHunter = {}
local DemonHunter      = HR.Commons.DemonHunter
local SpellVDH         = Spell.DemonHunter.Vengeance


--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======

--- ======= COMBATLOG =======

--- ======= Demonsurge Tracker =====
DemonHunter.Demonsurge = {}
local Surge = DemonHunter.Demonsurge
Surge.ConsumingFire = false
Surge.FelDesolation = false
Surge.SigilofDoom = false
Surge.SoulSunder = false
Surge.SpiritBurst = false

-- When we cast Meta, set Demonsurge buffs to active.
-- Then remove the buffs when we use them.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if Player:HeroTreeID() == 34 then
      if SpellID == SpellVDH.Metamorphosis:ID() then
        Surge.ConsumingFire = true
        Surge.FelDesolation = true
        Surge.SigilofDoom = true
      elseif SpellID == SpellVDH.ConsumingFire:ID() then
        Surge.ConsumingFire = false
      elseif SpellID == SpellVDH.FelDesolation:ID() then
        Surge.FelDesolation = false
      elseif SpellID == SpellVDH.SigilofDoom:ID() then
        Surge.SigilofDoom = false
      elseif SpellID == SpellVDH.SoulSunder:ID() then
        Surge.SoulSunder = false
      elseif SpellID == SpellVDH.SpiritBurst:ID() then
        Surge.SpiritBurst = false
      end
    end
  end
, "SPELL_CAST_SUCCESS")

-- Watch for the Meta aura.
-- SpiritBurst and SoulSunder are both buffed on hardcast Meta and Demonic Meta.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if Player:HeroTreeID() == 34 and SpellID == SpellVDH.MetamorphosisBuff:ID() then
      Surge.SpiritBurst = true
      Surge.SoulSunder = true
    end
  end
, "SPELL_AURA_APPLIED")

-- Remove Demonsurge buffs when Meta ends.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if Player:HeroTreeID() == 34 and SpellID == SpellVDH.MetamorphosisBuff:ID() then
      Surge.ConsumingFire = false
      Surge.FelDesolation = false
      Surge.SigilofDoom = false
      Surge.SoulSunder = false
      Surge.SpiritBurst = false
    end
  end
, "SPELL_AURA_REMOVED")

--- ===== Soul Fragment Tracker =====
DemonHunter.Souls = {}
local Soul = DemonHunter.Souls
Soul.AuraSouls = 0
Soul.IncomingSouls = 0

-- Casted abilities that generate delayed Soul Fragments.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    local IncAmt = 0
    if SpellID == SpellVDH.Fracture:ID() or SpellID == SpellVDH.Shear:ID() then
      IncAmt = 2
    elseif SpellID == SpellVDH.SoulCarver:ID() then
      IncAmt = 3
      C_Timer.After(1, function() Soul.IncomingSouls = Soul.IncomingSouls + 1; end)
      C_Timer.After(2, function() Soul.IncomingSouls = Soul.IncomingSouls + 1; end)
      C_Timer.After(3, function() Soul.IncomingSouls = Soul.IncomingSouls + 1; end)
    elseif SpellID == SpellVDH.SigilofSpite:ID() then
      IncAmt = (SpellVDH.SoulSigils:IsAvailable()) and 4 or 3
    elseif SpellVDH.SoulSigils:IsAvailable() and
      (SpellID == SpellVDH.SigilofFlame:ID() or SpellID == SpellVDH.SigilofMisery:ID() or SpellID == SpellVDH.SigilofChains:ID() or SpellID == SpellVDH.SigilofSilence:ID()) then
      IncAmt = 1
    else
      IncAmt = 0
    end
    if IncAmt > 0 then
      Soul.IncomingSouls = Soul.IncomingSouls + IncAmt
    end
  end
, "SPELL_CAST_SUCCESS")

-- T31 4pc "flare-up" Sigil damage, which spawns a delayed Soul Fragment.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if SpellID == 425672 then
      Soul.IncomingSouls = Soul.IncomingSouls + 1
    end
  end
, "SPELL_DAMAGE")

-- The initial application of the Soul Fragments buff.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID = select(12, ...)
    if SpellID == 203981 then
      Soul.AuraSouls = 1
      Soul.IncomingSouls = mathmax(0, Soul.IncomingSouls - 1)
    end
  end
, "SPELL_AURA_APPLIED")

-- Triggers every time we add stacks to the Soul Fragments buff.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID, _, _, _, Amount = select(12, ...)
    if SpellID == 203981 then
      Soul.AuraSouls = Amount
      Soul.IncomingSouls = mathmax(0, Soul.IncomingSouls - Amount)
    end
  end
, "SPELL_AURA_APPLIED_DOSE")

-- Triggers every time we remove stacks from the Soul Fragments buff.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID, _, _, _, Amount = select(12, ...)
    if SpellID == 203981 then
      Soul.AuraSouls = Amount
    end
  end
, "SPELL_AURA_REMOVED_DOSE")

-- Triggers when the soul Fragments buff is removed entirely.
HL:RegisterForSelfCombatEvent(
  function(...)
    local SpellID, _, _, _, Amount = select(12, ...)
    if SpellID == 203981 then
      Soul.AuraSouls = 0
    end
  end
, "SPELL_AURA_REMOVED")

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
