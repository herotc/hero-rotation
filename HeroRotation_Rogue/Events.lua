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
-- HeroRotation
local HR = HeroRotation
local Rogue = HR.Commons.Rogue
-- Lua
local C_Timer = C_Timer
local mathmax = math.max
local mathmin = math.min
local mathabs = math.abs
local pairs = pairs
local tableinsert = table.insert
local UnitAttackSpeed = UnitAttackSpeed
local GetTime = GetTime
-- File Locals



--- ============================ CONTENT ============================

--- Roll the Bones Tracking
--- As buff is "hidden" from the client but we get apply/refresh events for it
do
  local RtBExpiryTime = GetTime()
  function Rogue.RtBRemains()
    local Remains = RtBExpiryTime - GetTime() - HL.RecoveryOffset()
    return Remains >= 0 and Remains or 0
  end

  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      if SpellID == 315508 then
        RtBExpiryTime = GetTime() + 30
      end
    end,
    "SPELL_AURA_APPLIED"
  )
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      if SpellID == 315508 then
        RtBExpiryTime = GetTime() + mathmin(40, 30 + Rogue.RtBRemains())
      end
    end,
    "SPELL_AURA_REFRESH"
  )
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      if SpellID == 315508 then
        RtBExpiryTime = GetTime()
      end
    end,
    "SPELL_AURA_REMOVED"
  )
end

--- Exsanguinated Tracking
do
  -- Variables
  -- { [SpellName] = { [GUID] = boolean } }
  local ExsanguinatedByBleed = {
    CrimsonTempest = {},
    Garrote = {},
    Rupture = {},
  }
  local VendettaGUID = {}
  local VendettaSpell = Spell.Rogue.Assassination.Vendetta

  local Tier284pcEquipped = Player:HasTier(28, 4)
  HL:RegisterForEvent(function()
    Tier284pcEquipped = Player:HasTier(28, 4)
  end, "PLAYER_EQUIPMENT_CHANGED")

  -- Exsanguinated Expression
  function Rogue.Exsanguinated(ThisUnit, ThisSpell)
    local GUID = ThisUnit:GUID()
    if not GUID then return false end

    local SpellID = ThisSpell:ID()
    if SpellID == 121411 then
      -- Crimson Tempest
      return ExsanguinatedByBleed.CrimsonTempest[GUID] or false
    elseif SpellID == 703 then
      -- Garrote
      return ExsanguinatedByBleed.Garrote[GUID] or false
    elseif SpellID == 1943 then
      -- Rupture
      return ExsanguinatedByBleed.Rupture[GUID] or false
    end

    return false
  end

  function Rogue.WillLoseExsanguinate(ThisUnit, ThisSpell)
    -- TODO: Check rate comparison for Exsang + Vendetta
    if Tier284pcEquipped and ThisUnit:DebuffUp(VendettaSpell) then
      return false
    end
    
    if Rogue.Exsanguinated(ThisUnit, ThisSpell) then
      return true
    end

    return false
  end

  function Rogue.ExsanguinatedRate(ThisUnit, ThisSpell)
    -- TODO: Check rate comparison for Exsang + Vendetta
    if Rogue.Exsanguinated(ThisUnit, ThisSpell) then
      return 2.0
    end

    return 1.0
  end

  -- Exsanguinate OnCast Listener
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
      -- Exsanguinate
      if SpellID == 200806 then
        for _, ExsanguinatedByGUID in pairs(ExsanguinatedByBleed) do
          for GUID, _ in pairs(ExsanguinatedByGUID) do
            if GUID == DestGUID then
              ExsanguinatedByGUID[GUID] = true
            end
          end
        end
      -- Vendetta
      elseif Tier284pcEquipped and SpellID == 79140 then
        for _, ExsanguinatedByGUID in pairs(ExsanguinatedByBleed) do
          for GUID, _ in pairs(ExsanguinatedByGUID) do
            if GUID == DestGUID then
              ExsanguinatedByGUID[GUID] = true
            end
          end
        end
      end
    end,
    "SPELL_CAST_SUCCESS"
  )
  -- Bleed OnApply/OnRefresh Listener
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
      if Tier284pcEquipped and SpellID == 79140 then
        -- Vendetta
        VendettaGUID[DestGUID] = true
      end

      -- Debuff are additionally Exsanguinated on cast when Vendetta is up 
      local Exsanguinated = Tier284pcEquipped and VendettaGUID[DestGUID]
      if SpellID == 121411 then
        -- Crimson Tempest
        ExsanguinatedByBleed.CrimsonTempest[DestGUID] = Exsanguinated
      elseif SpellID == 703 then
        -- Garrote
        ExsanguinatedByBleed.Garrote[DestGUID] = Exsanguinated
      elseif SpellID == 1943 then
        -- Rupture
        ExsanguinatedByBleed.Rupture[DestGUID] = Exsanguinated
      end
    end,
    "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH"
  )
  -- Bleed OnRemove Listener
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
      if Tier284pcEquipped and SpellID == 79140 then
        -- Vendetta
        if VendettaGUID[DestGUID] ~= nil then
          VendettaGUID[DestGUID] = nil
        end
      elseif SpellID == 121411 then
        -- Crimson Tempest
        if ExsanguinatedByBleed.CrimsonTempest[DestGUID] ~= nil then
          ExsanguinatedByBleed.CrimsonTempest[DestGUID] = nil
        end
      elseif SpellID == 703 then
        -- Garrote
        if ExsanguinatedByBleed.Garrote[DestGUID] ~= nil then
          ExsanguinatedByBleed.Garrote[DestGUID] = nil
        end
      elseif SpellID == 1943 then
        -- Rupture
        if ExsanguinatedByBleed.Rupture[DestGUID] ~= nil then
          ExsanguinatedByBleed.Rupture[DestGUID] = nil
        end
      end
    end,
    "SPELL_AURA_REMOVED"
  )
  -- Bleed OnUnitDeath Listener
  HL:RegisterForCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID)
      -- Vendetta
      if VendettaGUID[DestGUID] ~= nil then
        VendettaGUID[DestGUID] = nil
      end
      -- Crimson Tempest
      if ExsanguinatedByBleed.CrimsonTempest[DestGUID] ~= nil then
        ExsanguinatedByBleed.CrimsonTempest[DestGUID] = nil
      end
      -- Garrote
      if ExsanguinatedByBleed.Garrote[DestGUID] ~= nil then
        ExsanguinatedByBleed.Garrote[DestGUID] = nil
      end
      -- Rupture
      if ExsanguinatedByBleed.Rupture[DestGUID] ~= nil then
        ExsanguinatedByBleed.Rupture[DestGUID] = nil
      end
    end,
    "UNIT_DIED", "UNIT_DESTROYED"
  )
end

--- Relentless Strikes Energy Prediction
do
  -- Variables
  local RelentlessStrikes = {
    Offset = 0,
    FinishDestGUID = nil,
    FinishCount = 0,
  }
  -- Return RS adjusted Energy Predicted
  function Rogue.EnergyPredictedWithRS()
      return Player:EnergyPredicted() + RelentlessStrikes.Offset
  end
  -- Return RS adjusted Energy Deficit Predicted
  function Rogue.EnergyDeficitPredictedWithRS()
      return Player:EnergyDeficitPredicted() - RelentlessStrikes.Offset
  end
  -- Zero RSOffset after receiving relentless strikes energize
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      -- Relentless Strikes
      if SpellID == 98440 then
        RelentlessStrikes.Offset = 0
      end
    end,
    "SPELL_ENERGIZE"
  )
  -- Running Combo Point tally to access after casting finisher
  HL:RegisterForEvent(
    function(_, _, PowerType)
      if PowerType == "COMBO_POINTS"and Player:ComboPoints() > 0 then
        RelentlessStrikes.Offsetvote = Player:ComboPoints() * 6
      end
    end,
    "UNIT_POWER_UPDATE"
  )
  -- Set RSOffset when casting a finisher
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID, _, _, _, SpellID)
      -- Eviscerate & Rupture & Shadow Vault SpellIDs
      if SpellID == 196819 or SpellID == 1943 or SpellID == 319175 then
        RelentlessStrikes.FinishDestGUID = DestGUID
        RelentlessStrikes.FinishCount = RelentlessStrikes.FinishCount + 1
        RelentlessStrikes.Offset = RelentlessStrikes.Offsetvote
        -- Backup clear
        C_Timer.After(2, function ()
            if RelentlessStrikes.FinishCount == 1 then
              RelentlessStrikes.Offset = 0
            end
            RelentlessStrikes.FinishCount = RelentlessStrikes.FinishCount - 1
          end
        )
      end
    end,
    "SPELL_CAST_SUCCESS"
  )
  -- Prevent RSOffset getting stuck when target dies mid-finisher (mostly DfA)
  HL:RegisterForCombatEvent(
    function(_, _, _, _, _, _, _, DestGUID)
      if RelentlessStrikes.FinishDestGUID == DestGUID then
        RelentlessStrikes.Offset = 0
      end
    end,
    "UNIT_DIED", "UNIT_DESTROYED"
  )
end

--- Shuriken Tornado Tracking
do
  local LastEnergizeTime, LastCastTime = 0, 0
  local ShurikenTornadoBuff = Spell(277925)
  function Rogue.TimeToNextTornado()
    if not Player:BuffUp(ShurikenTornadoBuff, nil, true) then
      return 0
    end
    local TimeToNextTick = Player:BuffRemains(ShurikenTornadoBuff, nil, true) % 1
    -- Tick happened in the same tick, we may not have the CP gain yet
    if GetTime() == LastEnergizeTime then
      return 0
    -- Tick happened very recently, slightly before the predicted buff tick
    elseif (GetTime() - LastEnergizeTime) < 0.1 and TimeToNextTick < 0.25 then
      return 1
    -- Tick hasn't happened yet but the predicted buff tick has passed
    elseif (TimeToNextTick > 0.9 or TimeToNextTick == 0) and (GetTime() - LastEnergizeTime) > 0.75 then
      return 0.1
    end
    return TimeToNextTick
  end

  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      -- Shuriken Storm Energize
      if SpellID == 212743 then
        LastEnergizeTime = GetTime()
      -- Actual Shuriken Storm Cast
      elseif SpellID == 197835 then
        LastCastTime = GetTime()
      end
      -- If the player casts an actual Shuriken Storm, this value is no longer reliable
      if LastCastTime == LastEnergizeTime then
        LastEnergizeTime = 0
      end
    end,
    "SPELL_CAST_SUCCESS"
  )
end


--- Shadow Techniques Tracking
do
  -- Variables
  local ShadowTechniques = {
    Counter = 0,
    LastMH = 0,
    LastOH = 0,
  }
  -- Return Time to x-th auto attack since last proc
  function Rogue.TimeToSht(Hit)
    if ShadowTechniques.Counter >= Hit then
      return 0
    end

    local MHSpeed, OHSpeed = UnitAttackSpeed("player")
    -- Generate the base time to use, if we are out of range this is set to the current time
    local LastMH = mathmax(ShadowTechniques.LastMH + MHSpeed, GetTime())
    local LastOH = mathmax(ShadowTechniques.LastOH + OHSpeed, GetTime())

    local AATable = {}
    for i = 0, 2 do
      tableinsert(AATable, LastMH + i * MHSpeed)
      tableinsert(AATable, LastOH + i * OHSpeed)
    end
    table.sort(AATable)

    local HitInTable = mathmin(5, mathmax(1, Hit - ShadowTechniques.Counter))

    return AATable[HitInTable] - GetTime()
  end
  -- Reset on entering world
  HL:RegisterForSelfCombatEvent(
    function ()
      ShadowTechniques.Counter = 0
      ShadowTechniques.LastMH = GetTime()
      ShadowTechniques.LastOH = GetTime()
    end,
    "PLAYER_ENTERING_WORLD"
  )
  -- Reset counter on energize
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, SpellID)
      -- Shadow Techniques
      if SpellID == 196911 then
        ShadowTechniques.Counter = 0
      end
    end,
    "SPELL_ENERGIZE"
  )
  -- Increment counter on successful swings
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, IsOffHand)
      ShadowTechniques.Counter = ShadowTechniques.Counter + 1
      if IsOffHand then
        ShadowTechniques.LastOH = GetTime()
      else
        ShadowTechniques.LastMH = GetTime()
      end
    end,
    "SWING_DAMAGE"
  )
  -- Remember timers on swing misses
  HL:RegisterForSelfCombatEvent(
    function(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, IsOffHand)
      if IsOffHand then
        ShadowTechniques.LastOH = GetTime()
      else
        ShadowTechniques.LastMH = GetTime()
      end
    end,
    "SWING_MISSED"
  )
end

-- Base Crit Tracker (mainly for Outlaw)
do
  local BaseCritChance = Player:CritChancePct()
  local BaseCritChecksPending = 0
  local function UpdateBaseCrit()
    if not Player:AffectingCombat() then
      BaseCritChance = Player:CritChancePct()
      HL.Debug("Base Crit Set to: " .. BaseCritChance)
    end
    if BaseCritChecksPending == nil or BaseCritChecksPending < 0 then
      BaseCritChecksPending = 0
    else
      BaseCritChecksPending = BaseCritChecksPending - 1
    end
    if BaseCritChecksPending > 0 then
      C_Timer.After(3, UpdateBaseCrit)
    end
  end
  HL:RegisterForEvent(
    function ()
      if BaseCritChecksPending == 0 then
        C_Timer.After(3, UpdateBaseCrit)
        BaseCritChecksPending = 2
      end
    end,
    "PLAYER_EQUIPMENT_CHANGED"
  )

  function Rogue.BaseAttackCrit()
    return BaseCritChance
  end
end
