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
local SpellDisc    = Spell.Priest.Discipline
local SpellShadow  = Spell.Priest.Shadow
-- Lua
-- WoW API
local UnitPower         = UnitPower
local InsanityPowerType = Enum.PowerType.Insanity

--- ============================ CONTENT ============================
-- Discipline, ID: 256
local OldDiscIsCastable
OldDiscIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = OldDiscIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellDisc.MindBlast or self == SpellDisc.Schism then
      return BaseCheck and (not Player:IsCasting(self))
    elseif self == SpellDisc.Smite or self == SpellDisc.DivineStar or self == SpellDisc.Halo or self == SpellDisc.Penance or self == SpellDisc.PowerWordSolace then
      return BaseCheck and (not Player:BuffUp(SpellDisc.ShadowCovenantBuff))
    else
      return BaseCheck
    end
  end
, 256)

-- Holy, ID: 257

-- Shadow, ID: 258
HL.AddCoreOverride ("Player.Insanity",
  function ()
    local Insanity = UnitPower("Player", InsanityPowerType)
    if not Player:IsCasting() then
      return Insanity
    else
      if Player:IsCasting(SpellShadow.MindBlast) then
        return Insanity + 6
      elseif Player:IsCasting(SpellShadow.VampiricTouch) or Player:IsCasting(SpellShadow.MindSpike) then
        return Insanity + 4
      elseif Player:IsCasting(SpellShadow.MindFlay) then
        return Insanity + (12 / SpellShadow.MindFlay:BaseDuration())
      elseif Player:IsCasting(SpellShadow.DarkVoid) then
        return Insanity + 15
      elseif Player:IsCasting(SpellShadow.DarkAscension) then
        return Insanity + 30
      elseif Player:IsCasting(SpellShadow.VoidTorrent) then
        return Insanity + (60 / SpellShadow.VoidTorrent:BaseDuration())
      else
        return Insanity
      end
    end 
  end
, 258)

local OldShadowIsCastable
OldShadowIsCastable = HL.AddCoreOverride("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = OldShadowIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellShadow.VampiricTouch then
      return BaseCheck and (not SpellShadow.ShadowCrash:InFlight()) and (SpellShadow.UnfurlingDarkness:IsAvailable() or not Player:IsCasting(self))
    elseif self == SpellShadow.MindBlast then
      return BaseCheck and (self:Charges() >= 2 or not Player:IsCasting(self))
    elseif self == SpellShadow.VoidEruption then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellShadow.VoidBolt then
      return BaseCheck or Player:IsCasting(SpellShadow.VoidEruption)
    else
      return BaseCheck
    end
  end
, 258)

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP", 
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell )
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self)
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0
--   end
-- end
-- , 62)
