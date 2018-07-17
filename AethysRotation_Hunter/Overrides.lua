--- ============================ HEADER ============================
  -- HeroLib
  local AC      = HeroLib;
  local Cache   = AethysCache;
  local Unit    = AC.Unit;
  local Player  = Unit.Player;
  local Pet     = Unit.Pet;
  local Target  = Unit.Target;
  local Spell   = AC.Spell;
  local Item    = AC.Item;
-- AethysRotation
  local AR      = AethysRotation;
-- Spells
  local SpellBM = Spell.Hunter.BeastMastery;
  local SpellMM = Spell.Hunter.Marksmanship;
  local SpellSV = Spell.Hunter.Survival;
-- Lua

--- ============================ CONTENT ============================
-- Beast Mastery, ID: 253

-- Marksmanship, ID: 254

-- Survival, ID: 255

-- Example (Arcane Mage)
-- AC.AddCoreOverride ("Spell.IsCastableP", 
-- function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
--   if Range then
--     local RangeUnit = ThisUnit or Target;
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeUnit:IsInRange( Range, AoESpell );
--   elseif self == SpellArcane.MarkofAluneth then
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and not Player:IsCasting(self);
--   else
--     return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0;
--   end;
-- end
-- , 62);
