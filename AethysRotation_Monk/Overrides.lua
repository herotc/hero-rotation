--- ============================ HEADER ============================
  -- AethysCore
  local AC      = AethysCore;
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
  local SpellBrewmaster = Spell.Monk.Brewmaster;
  local SpellWindwalker = Spell.Monk.Windwalker;
-- Lua

--- ============================ CONTENT ============================
-- Brewmaster, ID: 268

-- Windwalker, ID: 269

-- Mistweaver, ID: 270

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
