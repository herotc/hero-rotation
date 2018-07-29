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
  local SpellBalance   = Spell.Druid.Balance;
  local SpellFeral     = Spell.Druid.Feral;
  local SpellGuardian  = Spell.Druid.Guardian;
-- Lua

--- ============================ CONTENT ============================
-- Balance, ID: 102

-- Feral, ID: 103
    HL.AddCoreOverride ("Unit.BuffP",
    function ( self, Spell, AnyCaster, Offset )
      if Spell == SpellFeral.CatForm or Spell == SpellFeral.CatFormBuff or Spell == SpellFeral.Prowl or Spell == SpellFeral.ProwlBuff then
        return self:Buff(Spell);
      else
        return self:BuffRemains( Spell, AnyCaster, Offset or "Auto" ) > 0;
      end
    end
    , 103);

    HL.AddCoreOverride ("Unit.BuffDownP",
    function ( self, Spell, AnyCaster, Offset )
      if Spell == SpellFeral.CatForm or Spell == SpellFeral.CatFormBuff or Spell == SpellFeral.Prowl or Spell == SpellFeral.ProwlBuff then
        return self:BuffDown(Spell);
      else
        return self:BuffRemains( Spell, AnyCaster, Offset or "Auto" ) == 0;
      end
    end
    , 103);

    HL.AddCoreOverride ("Spell.IsCastableP",
    function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
      local RangeOK = true;
      if Range then
        local RangeUnit = ThisUnit or Target;
        RangeOK = RangeUnit:IsInRange( Range, AoESpell );
      end

      local BaseCheck = self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeOK

      if self == SpellFeral.Regrowth and BaseCheck and SpellFeral.Bloodtalons:IsAvailable() and (not Player:AffectingCombat()) then
        return Player:BuffDownP(SpellFeral.BloodtalonsBuff)
      end

      return BaseCheck
    end
    , 103);

-- Guardian, ID: 104

-- Restoration, ID: 105

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
