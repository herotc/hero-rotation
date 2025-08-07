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

HL.AddCoreOverride("Player.BuffStackP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffStack(Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneHarmonyBuff then
      return HR.Commons.Mage.EventInfo.ArcaneHarmonyLastStack
    elseif Spell == SpellArcane.ClearcastingBuff then
      return HR.Commons.Mage.EventInfo.ClearcastingProcs
    else
      return BaseCheck
    end
  end
, 62)

HL.AddCoreOverride("Player.BuffRemainsP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffRemains(Spell, AnyCaster, Offset)
    if Spell == SpellArcane.ArcaneSurgeBuff and HR.Commons.Mage.EventInfo.ArcaneSurgeActive then
      return math.max(0, BaseCheck - (GetTime() - HR.Commons.Mage.EventInfo.ArcaneSurgeStartTime))
    else
      return BaseCheck
    end
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
    elseif Spell == SpellArcane.NetherPrecisionBuff then
      if Player:BuffInfo(Spell) == 1 and Player:IsCasting(SpellArcane.ArcaneBlast) then
        return true
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 62)

-- Fire, ID: 63
local function IsSKBCastSafe(spell)
  if not spell then return false end
  local auraData = C_UnitAuras.GetPlayerAuraBySpellID(SpellFire.FuryoftheSunKingBuff:ID())
  if auraData and auraData.expirationTime then
    local currentTime = GetTimePreciseSec()
    local remainingTime = auraData.expirationTime - currentTime
    local castTime = spell:CastTime()
    return remainingTime > (castTime * (auraData.timeMod or 1) + 0.2)
  end
  return false
end

local FirePlayerBuffUp
FirePlayerBuffUp = HL.AddCoreOverride("Player.BuffUp",
  function (self, Spell, AnyCaster, Offset)
    if not Spell then return false end
    local BaseCheck = FirePlayerBuffUp(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.HeatingUpBuff then
      return BaseCheck or (Player:IsCasting(SpellFire.Pyroblast) and IsSKBCastSafe(SpellFire.Pyroblast))
    elseif Spell == SpellFire.FuryoftheSunKingBuff then
      local auraData = C_UnitAuras.GetPlayerAuraBySpellID(Spell:ID())
      if Player:IsCasting(SpellFire.Pyroblast) or Player:IsCasting(SpellFire.Flamestrike) then
        return IsSKBCastSafe(Player:IsCasting(SpellFire.Pyroblast) and SpellFire.Pyroblast or SpellFire.Flamestrike)
      end
      return (auraData and auraData.expirationTime ~= nil) or BaseCheck
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
      local auraData = C_UnitAuras.GetPlayerAuraBySpellID(Spell:ID())
      if Player:IsCasting(SpellFire.Pyroblast) or Player:IsCasting(SpellFire.Flamestrike) then
        return not IsSKBCastSafe(Player:IsCasting(SpellFire.Pyroblast) and SpellFire.Pyroblast or SpellFire.Flamestrike)
      end
      return auraData == nil and BaseCheck
    else
      return BaseCheck
    end
  end
, 63)

HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = self:IsCastable() and self:IsUsableP()

    if Settings.Commons.MovingRotation and self:CastTime() > 0 and Player:IsMoving() then
      if self == SpellFire.Scorch or
         (self == SpellFire.Pyroblast and Player:BuffUp(SpellFire.HotStreakBuff)) or
         (self == SpellFire.Flamestrike and Player:BuffUp(SpellFire.HotStreakBuff)) then
        return true
      end
      return false
    end

    if self == SpellFire.FireBlast then
      return BaseCheck and self:Charges() >= 1
    elseif self == SpellFire.Pyroblast or self == SpellFire.Flamestrike then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 63)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if Settings.Commons.MovingRotation and self:CastTime() > 0 and Player:IsMoving() then
      return false
    end

    local BaseCheck = self:IsLearned() and self:CooldownUp(BypassRecovery)
    if self == SpellFire.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 63)

local FireOldPlayerAffectingCombat
FireOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
  function (self)
    return FireOldPlayerAffectingCombat(self)
      or Player:IsCasting(SpellFire.Pyroblast)
      or Player:IsCasting(SpellFire.Fireball)
  end
, 63)

HL.AddCoreOverride("Spell.InFlightRemains",
  function(self)
    return self:TravelTime() - self:TimeSinceLastCast()
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
