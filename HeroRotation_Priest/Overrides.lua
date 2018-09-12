--- ============================ HEADER ============================
  -- HeroLib
  local HL      = HeroLib;
  local Cache   = HeroCache;
  local Unit    = HL.Unit;
  local Player  = Unit.Player;
  local Pet     = Unit.Pet;
  local Target  = Unit.Target;
  local Spell   = HL.Spell;
  local Item    = HL.Item;
-- HeroRotation
  local HR      = HeroRotation;
-- Spells
  local SpellShadow  = Spell.Priest.Shadow;
-- Lua

--- ============================ CONTENT ============================
-- Discipline, ID: 256

-- Holy, ID: 257

-- Shadow, ID: 258

-- Example (Arcane Mage)
-- HL.AddCoreOverride ("Spell.IsCastableP", 
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
HL.AddCoreOverride ("Player.Insanity",
    function ()
      local Insanity = UnitPower("Player", InsanityPowerType)
      if not Player:IsCasting() then
        return Insanity
      else
        if Player:IsCasting(SpellShadow.MindBlast) then
          return Insanity + (12 * (SpellShadow.FortressOfTheMind:IsAvailable() and 1.2 or 1.0) * (Player:BuffP(SpellShadow.SurrenderToMadness) and 2.0 or 1.0))
        elseif Player:IsCasting(SpellShadow.ShadowWordVoid) then
          return Insanity + (15 * (Player:BuffP(SpellShadow.SurrenderToMadness) and 2.0 or 1.0))
        elseif Player:IsCasting(SpellShadow.DarkVoid) then
          return Insanity + (30 * (Player:BuffP(SpellShadow.SurrenderToMadness) and 2.0 or 1.0))
        elseif Player:IsCasting(SpellShadow.VampiricTouch) then
          return Insanity + (6 * (Player:BuffP(SpellShadow.SurrenderToMadness) and 2.0 or 1.0))
        else
          return Insanity
        end
      end 
    end
    ,258);
