--- ============================ HEADER ============================
-- HeroLib
local HL      = HeroLib
local Cache   = HeroCache
local Unit    = HL.Unit
local Player  = Unit.Player
local Pet     = Unit.Pet
local Target  = Unit.Target
local Spell   = HL.Spell
local Item    = HL.Item
-- HeroRotation
local HR      = HeroRotation
-- Spells
local SpellArcane = Spell.Mage.Arcane
local SpellFire   = Spell.Mage.Fire
local SpellFrost  = Spell.Mage.Frost
-- lua
local mathmin     = math.min

local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Frost = HR.GUISettings.APL.Mage.Frost,
  Fire = HR.GUISettings.APL.Mage.Fire,
  Arcane = HR.GUISettings.APL.Mage.Arcane,
}

-- Util
local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

--- ============================ CONTENT ============================
-- Mage

-- Arcane, ID: 62
local ArcaneOldPlayerAffectingCombat
ArcaneOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return Player:IsCasting(SpellArcane.ArcaneBlast) or ArcaneOldPlayerAffectingCombat(self)
  end
, 62)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0 and RangeOK and Player:Mana() >= self:Cost()
    if self == SpellArcane.PresenceofMind then
      return BaseCheck and Player:BuffDown(SpellArcane.PresenceofMind)
    elseif self == SpellArcane.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.TouchoftheMagi then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.ArcaneSurge then
      return self:IsLearned() and self:CooldownUp() and RangeOK and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 62)

local ArcaneChargesPowerType = Enum.PowerType.ArcaneCharges
local ArcaneOldPlayerArcaneCharges
ArcaneOldPlayerArcaneCharges = HL.AddCoreOverride("Player.ArcaneCharges",
  function (self)
    local BaseCharges = UnitPower("player", ArcaneChargesPowerType)
    if Player:IsCasting(SpellArcane.ArcaneBlast) then
      return mathmin(BaseCharges + 1, 4)
    else
      return BaseCharges
    end
  end
, 62)

local ArcanePlayerBuffUp
ArcanePlayerBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = ArcanePlayerBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneSurgeBuff then
      return BaseCheck or Player:IsCasting(SpellArcane.ArcaneSurge)
    else
      return BaseCheck
    end
  end
, 62)

local ArcanePlayerBuffDown
ArcanePlayerBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = ArcanePlayerBuffDown(self, Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneSurgeBuff then
      return BaseCheck and not Player:IsCasting(SpellArcane.ArcaneSurge)
    else
      return BaseCheck
    end
  end
, 62)

-- Fire, ID: 63
-- Buff tracking overrides
local FirePlayerBuffUp
FirePlayerBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FirePlayerBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.HeatingUpBuff then
      -- Enhanced Heating Up prediction
      return BaseCheck
        -- SKB Pyroblast prediction
        or (Player:IsCasting(SpellFire.Pyroblast) and Player:BuffRemains(SpellFire.FuryoftheSunKingBuff) > 0)
        -- Phoenix Flames prediction
        or (SpellFire.PhoenixFlames:InFlight() and Player:TimeSinceLastPhoenixFlames() < 0.5)
        -- Fire Blast prediction during Combustion
        or (Mage.IsCombustionActive() and SpellFire.FireBlast:InFlight() and Player:TimeSinceLastFireBlast() < 0.5)
        -- Single crit tracking
        or (Player:GetPendingCrits() == 1 and Player:TimeSinceLastCrit() < 10)
        -- In-flight spell predictions
        or (Player:GetInFlightFireballs() > 0 and Mage.IsCombustionActive())
        or (Player:GetInFlightPyroblasts() > 0 and Mage.IsCombustionActive())
    elseif Spell == SpellFire.HotStreakBuff then
      -- Enhanced Hot Streak prediction
      return BaseCheck
        -- Pending Hot Streak from crits
        or Player:IsHotStreakPending()
        -- Combustion predictions
        or (Mage.IsCombustionActive() and Player:BuffUp(SpellFire.HeatingUpBuff) and
            (SpellFire.FireBlast:InFlight() or SpellFire.PhoenixFlames:InFlight()))
        -- Double Fire Blast during Combustion
        or (Mage.IsCombustionActive() and SpellFire.FireBlast:InFlight() and Player:TimeSinceLastFireBlast() < 0.5)
        -- Infernal Cascade interaction
        or (Player:GetInfernalCascadeStacks() > 0 and Player:BuffUp(SpellFire.HeatingUpBuff))
    elseif Spell == SpellFire.CombustionBuff then
      return BaseCheck or Mage.IsCombustionActive()
    else
      return BaseCheck
    end
  end
, 63)

local FirePlayerBuffDown
FirePlayerBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FirePlayerBuffDown(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.FuryoftheSunKingBuff then
      return BaseCheck or Player:IsCasting(SpellFire.Pyroblast)
    elseif Spell == SpellFire.HeatingUpBuff then
      -- Inverse of enhanced Heating Up prediction
      return not FirePlayerBuffUp(self, Spell, AnyCaster, Offset)
    elseif Spell == SpellFire.HotStreakBuff then
      -- Inverse of enhanced Hot Streak prediction
      return not FirePlayerBuffUp(self, Spell, AnyCaster, Offset)
    elseif Spell == SpellFire.CombustionBuff then
      return not Mage.IsCombustionActive()
    else
      return BaseCheck
    end
  end
, 63)

-- Spell casting and readiness overrides
HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = self:IsCastable() and self:IsUsableP()

    -- Movement handling
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Commons.MovingRotation then
      -- Allow instant casts during movement
      if self == SpellFire.Scorch then
        return BaseCheck
      -- Allow Hot Streak instant casts
      elseif (self == SpellFire.Pyroblast or self == SpellFire.Flamestrike) and
             (Player:BuffUp(SpellFire.HotStreakBuff) or Player:IsHotStreakPending()) then
        return BaseCheck
      -- Block other casts while moving
      else
        return false
      end
    end

    -- Combustion phase special handling
    if Mage.IsCombustionActive() then
      -- Prioritize certain spells during Combustion
      if self == SpellFire.FireBlast or self == SpellFire.PhoenixFlames then
        return BaseCheck and Player:BuffDown(SpellFire.HotStreakBuff)
      end
    end

    -- Execute phase handling
    if self == SpellFire.Scorch and Player:IsSearingTouchActive() then
      return BaseCheck
    end

    -- Infernal Cascade optimization
    if Player:GetInfernalCascadeStacks() > 0 and Mage.IsCombustionActive() then
      if self == SpellFire.FireBlast then
        -- Hold Fire Blast for better Infernal Cascade timing
        return BaseCheck and Player:TimeSinceLastSpellImpact() >= 0.3
      end
    end

    return BaseCheck
  end
, 63)

-- Basic castability check
HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    -- Block casts while moving (unless allowed by IsReady)
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Commons.MovingRotation then
      return false
    end

    -- Range check
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange(Range, AoESpell)
    end

    -- Base castability check
    local BaseCheck = self:IsLearned() and self:CooldownRemains(BypassRecovery, Offset or "Auto") == 0 and RangeOK

    -- Special handling for Shifting Power
    if self == SpellFire.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    end

    return BaseCheck
  end
, 63)

-- Combat state tracking
local FireOldPlayerAffectingCombat
FireOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return FireOldPlayerAffectingCombat(self)
      or Player:IsCasting(SpellFire.Pyroblast)
      or Player:IsCasting(SpellFire.Fireball)
  end
, 63)

-- Spell travel time and in-flight tracking
HL.AddCoreOverride("Spell.InFlightRemains",
  function(self)
    return self:TravelTime() - self:TimeSinceLastCast()
  end
, 63)

-- Add buff stack prediction for Fire
HL.AddCoreOverride("Player.BuffStack",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffStack(Spell, AnyCaster, Offset)
    if Spell == SpellFire.HeatingUpBuff then
      return BaseCheck + Player:GetPendingCrits()
    else
      return BaseCheck
    end
  end
, 63)

-- Enhanced spell travel time tracking
HL.AddCoreOverride("Spell.TravelTime",
  function (self)
    if self == SpellFire.Fireball then
      return Player:GetInFlightFireballs() > 0 and (1 - Player:TimeSinceLastFireball()) or 1
    elseif self == SpellFire.Pyroblast then
      return Player:GetInFlightPyroblasts() > 0 and (1.5 - Player:TimeSinceLastPyroblast()) or 1.5
    else
      return 0
    end
  end
, 63)

-- Frost, ID: 64
local FrostOldSpellIsCastable
FrostOldSpellIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    if self == SpellFrost.GlacialSpike then
      return self:IsLearned() and RangeOK and not Player:IsCasting(self) and (Player:BuffUp(SpellFrost.GlacialSpikeBuff) or (Player:BuffStack(SpellFrost.IciclesBuff) == 5))
    else
      local BaseCheck = FrostOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
      if self == SpellFrost.ShiftingPower then
        return BaseCheck and not Player:IsCasting(self)
      else
        return BaseCheck
      end
    end
  end
, 64)

local FrostOldSpellCooldownRemains
FrostOldSpellCooldownRemains = HL.AddCoreOverride("Spell.CooldownRemains",
  function (self, BypassRecovery, Offset)
    if self == SpellFrost.Blizzard and Player:IsCasting(self) then
      return 8
    else
      return FrostOldSpellCooldownRemains(self, BypassRecovery, Offset)
    end
  end
, 64)

HL.AddCoreOverride("Player.BuffStackP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffStack(Spell, AnyCaster, Offset)
    if Spell == SpellFrost.IciclesBuff then
      local Icicles = BaseCheck
      if self:IsCasting(SpellFrost.GlacialSpike) then return 0 end
      if (not SpellFrost.GlacialSpike:IsAvailable()) and SpellFrost.IceLance:TimeSinceLastCast() < 2 * Player:SpellHaste() then Icicles = 0 end
      return mathmin(Icicles + (self:IsCasting(SpellFrost.Frostbolt) and 1 or 0), 5)
    elseif Spell == SpellFrost.GlacialSpikeBuff then
      return self:IsCasting(SpellFrost.GlacialSpike) and 0 or BaseCheck
    elseif Spell == SpellFrost.WintersReachBuff then
      return self:IsCasting(SpellFrost.Flurry) and 0 or BaseCheck
    elseif Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        if BaseCheck == 0 then
          return 0
        else
          return BaseCheck - 1
        end
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldBuffUp
FrostOldBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        -- Note: BypassRecovery to avoid infinite looping from BuffStack to BuffDown.
        return Player:BuffStackP(Spell, false, true) >= 1
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldBuffDown
FrostOldBuffDown = HL.AddCoreOverride("Player.BuffDown",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldBuffDown(self, Spell, AnyCaster, Offset)
    if Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        -- Note: BypassRecovery to avoid infinite looping from BuffStack to BuffDown.
        return Player:BuffStackP(Spell, false, true) <= 0
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldTargetDebuffStack
FrostOldTargetDebuffStack = HL.AddCoreOverride("Target.DebuffStack",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldTargetDebuffStack(self, Spell, AnyCaster, Offset)
    if Spell == SpellFrost.WintersChillDebuff then
      if SpellFrost.Flurry:InFlight() then
        return 2
      elseif SpellFrost.IceLance:InFlight() or Player:IsCasting(SpellFrost.GlacialSpike) or SpellFrost.GlacialSpike:InFlight() then
        if BaseCheck == 0 then
          return 0
        else
          return BaseCheck - 1
        end
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldTargetDebuffRemains
FrostOldTargetDebuffRemains = HL.AddCoreOverride("Target.DebuffRemains",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FrostOldTargetDebuffRemains(self, Spell, AnyCaster, Offset)
    if Spell == SpellFrost.WintersChillDebuff then
      return SpellFrost.Flurry:InFlight() and 6 or BaseCheck
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldPlayerAffectingCombat
FrostOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return SpellFrost.Frostbolt:InFlight() or FrostOldPlayerAffectingCombat(self)
  end
, 64)
