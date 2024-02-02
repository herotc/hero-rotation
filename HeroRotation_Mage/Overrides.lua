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
    return SpellArcane.ArcaneBlast:InFlight() or ArcaneOldPlayerAffectingCombat(self)
  end
, 62)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Arcane.MovingRotation then
      return false
    end

    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0 and RangeOK and Player:Mana() >= self:Cost()
    if self == SpellArcane.PresenceofMind then
      return BaseCheck and Player:BuffDown(SpellArcane.PresenceofMind)
    elseif self == SpellArcane.RadiantSpark then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.ShiftingPower then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.TouchoftheMagi then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellArcane.ConjureManaGem then
      local ManaGem = Item.Mage.Arcane.ManaGem
      local GemCD = ManaGem:CooldownRemains()
      return BaseCheck and (not Player:IsCasting(self)) and not (ManaGem:IsReady() or GemCD > 0)
    elseif self == SpellArcane.ArcaneSurge then
      return self:IsLearned() and self:CooldownUp() and RangeOK
    else
      return BaseCheck
    end
  end
, 62)

-- Fire, ID: 63
local FireOldPlayerBuffStack
FireOldPlayerBuffStack = HL.AddCoreOverride("Player.BuffStack",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FireOldPlayerBuffStack(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
      return 0
    else
      return BaseCheck
    end
  end
, 63)

local FirePlayerBuffRemains
FirePlayerBuffRemains = HL.AddCoreOverride("Player.BuffRemains",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = FirePlayerBuffRemains(self, Spell, AnyCaster, Offset)
    if Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
      return 0
    end
    return BaseCheck
  end
, 63)

HL.AddCoreOverride("Spell.IsReady",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = self:IsCastable() and self:IsUsableP()
    local MovingOK = true
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Fire.MovingRotation then
      if self == SpellFire.Scorch or (self == SpellFire.Pyroblast and Player:BuffUp(SpellFire.HotStreakBuff)) or (self == SpellFire.Flamestrike and Player:BuffUp(SpellFire.HotStreakBuff)) then
        MovingOK = true
      else
        return false
      end
    else
      return BaseCheck
    end
  end
, 63)

HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Fire.MovingRotation then
      return false
    end

    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end

    local BaseCheck = self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0 and RangeOK
    if self == SpellFire.RadiantSpark then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellFire.ShiftingPower then
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
    local MovingOK = true
    if self:CastTime() > 0 and Player:IsMoving() and Settings.Frost.MovingRotation then
      if self == SpellFrost.Blizzard and Player:BuffUp(SpellFrost.FreezingRain) then
        MovingOK = true
      else
        return false
      end
    end

    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    if self == SpellFrost.GlacialSpike then
      return self:IsLearned() and RangeOK and MovingOK and not Player:IsCasting(self) and (Player:BuffUp(SpellFrost.GlacialSpikeBuff) or (Player:BuffStack(SpellFrost.IciclesBuff) == 5))
    else
      local BaseCheck = FrostOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
      if self == SpellFrost.MirrorsofTorment then
        return BaseCheck and not Player:IsCasting(self)
      elseif self == SpellFrost.RadiantSpark then
        return BaseCheck and not Player:IsCasting(self)    
      elseif self == SpellFrost.ShiftingPower then
        return BaseCheck and not Player:IsCasting(self)    
      elseif self == SpellFrost.Deathborne then
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

local FrostOldPlayerBuffStack
FrostOldPlayerBuffStack = HL.AddCoreOverride("Player.BuffStackP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffStack(Spell)
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

local FrostOldPlayerBuffUp
FrostOldPlayerBuffUp = HL.AddCoreOverride("Player.BuffUpP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffUp(Spell)
    if Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        return Player:BuffStack(Spell) >= 1
      else
        return BaseCheck
      end
    else
      return BaseCheck
    end
  end
, 64)

local FrostOldPlayerBuffDown
FrostOldPlayerBuffDown = HL.AddCoreOverride("Player.BuffDownP",
  function (self, Spell, AnyCaster, Offset)
    local BaseCheck = Player:BuffDown(Spell)
    if Spell == SpellFrost.FingersofFrostBuff then
      if SpellFrost.IceLance:InFlight() then
        return Player:BuffStack(Spell) == 0
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
