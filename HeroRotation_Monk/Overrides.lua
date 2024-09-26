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
  local SpellBM = Spell.Monk.Brewmaster
  local SpellWW = Spell.Monk.Windwalker
-- Lua

--- ============================ CONTENT ============================
-- Brewmaster, ID: 268
local BMOldSpellIsCastable
BMOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = BMOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellBM.TouchofDeath then
      return BaseCheck and self:IsUsable()
    elseif self == SpellBM.ChiBurst then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 268)

-- Windwalker, ID: 269
local WWOldSpellIsCastable
WWOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    local BaseCheck = WWOldSpellIsCastable(self, BypassRecovery, Range, AoESpell, ThisUnit, Offset)
    if self == SpellWW.ChiBurst then
      return BaseCheck and not Player:IsCasting(self)
    else
      return BaseCheck
    end
  end
, 269)
