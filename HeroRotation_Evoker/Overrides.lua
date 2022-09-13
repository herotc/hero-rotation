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
local SpellDeva = Spell.Evoker.Devastation
-- Lua

--- ============================ CONTENT ============================
-- Devastation, ID: 1467
local DevOldIsCastable
DevOldIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = DevOldIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellDeva.Firestorm then
      return BaseCheck and not Player:IsCasting(self)
    elseif self == SpellDeva.TipTheScales then
      return BaseCheck and not Player:BuffUp(self)
    else
      return BaseCheck
    end
  end
, 1467)

-- Preservation, ID: ????
