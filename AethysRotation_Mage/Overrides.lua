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
    local SpellArcane = Spell.Mage.Arcane;
    local SpellFire   = Spell.Mage.Fire;
    local SpellFrost  = Spell.Mage.Frost;
  -- Lua

--- ============================ CONTENT ============================
  -- Arcane, ID: 62
    AC.AddCoreOverride ("Spell.CooldownRemainsP", 
    function (self, BypassRecovery, Offset)
      if self == SpellArcane.MarkofAluneth and Player:IsCasting(self) then
        return 60;
      else
        return self:CooldownRemains( BypassRecovery, Offset or "Auto" );
      end
    end
    , 62);
  -- Fire, ID: 63

  -- Frost, ID: 64

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
