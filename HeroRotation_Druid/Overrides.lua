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
HL.AddCoreOverride ("Player.AstralPowerP",
  function ()
    local AP = Player:AstralPower()
    if not Player:IsCasting() then
      return AP
    else
      if Player:IsCasting(SpellBalance.Wrath) then
        return AP + 6
      elseif Player:IsCasting(SpellBalance.Starfire) then
        return AP + 8
      else
        return AP
      end
    end
  end
, 102)

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
    elseif self == SpellBalance.Wrath or self == SpellBalance.Starfire then
      return BaseCheck and not (Player:IsCasting(self) and self:Count() == 1)
    else
      return BaseCheck
    end
  end
, 102)

-- Feral, ID: 103

-- Guardian, ID: 104
