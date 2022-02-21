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
local SpellFury             = Spell.Warrior.Fury
local SpellArms             = Spell.Warrior.Arms
local SpellProt             = Spell.Warrior.Protection
-- Lua

--- ============================ CONTENT ============================
-- Arms, ID: 71
local ArmsOldSpellIsCastable
ArmsOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = ArmsOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellArms.Charge then
      return BaseCheck and self:Charges() >= 1 and (not Target:IsInRange(8) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 71)

-- Fury, ID: 72
local FuryOldSpellIsCastable
FuryOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = FuryOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellFury.Charge then
      return BaseCheck and (self:Charges() >= 1 and (not Target:IsInRange(8)) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 72)

-- Protection, ID: 73
local ProtOldSpellIsCastable
ProtOldSpellIsCastable = HL.AddCoreOverride ("Spell.IsCastable",
  function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    local BaseCheck = ProtOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
    if self == SpellProt.Charge then
      return BaseCheck and (self:Charges() >= 1 and (not Target:IsInRange(8)) and Target:IsInRange(25))
    else
      return BaseCheck
    end
  end
, 73)

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