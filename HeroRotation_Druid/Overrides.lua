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
local SpellBalance = Spell.Druid.Balance
-- Lua

--- ============================ CONTENT ============================
-- Balance, ID: 102
local BalOldSpellIsCastable
BalOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local RangeOK = true
    if Range then
      local RangeUnit = ThisUnit or Target
      RangeOK = RangeUnit:IsInRange( Range, AoESpell )
    end
    local BaseCheck = BalOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellBalance.MoonkinForm then
      return BaseCheck and Player:BuffDown(self)
    elseif self == SpellBalance.StellarFlare then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 102)

-- Feral, ID: 103

-- Guardian, ID: 104
