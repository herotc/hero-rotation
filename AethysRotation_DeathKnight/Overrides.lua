--- ============================ HEADER ============================
  -- HeroLib
  local AC      = HeroLib;
  local Cache   = HeroCache;
  local Unit    = AC.Unit;
  local Player  = Unit.Player;
  local Pet     = Unit.Pet;
  local Target  = Unit.Target;
  local Spell   = AC.Spell;
  local Item    = AC.Item;
-- AethysRotation
  local AR      = AethysRotation;
-- Spells
  local SpellBlood   = Spell.DeathKnight.Blood;
  local SpellFrost   = Spell.DeathKnight.Frost;
  local SpellUnholy  = Spell.DeathKnight.Unholy;
-- Lua

--- ============================ CONTENT ============================
-- Blood, ID: 250

-- Frost, ID: 251

-- Unholy, ID: 252

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
