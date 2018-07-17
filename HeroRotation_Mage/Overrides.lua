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
    local AR      = HeroRotation;
  -- Spells
    local SpellArcane = Spell.Mage.Arcane;
    local SpellFire   = Spell.Mage.Fire;
    local SpellFrost  = Spell.Mage.Frost;

    SpellFrost.GlacialSpikeBuff   = Spell(199844);
  -- Lua


--- ============================ CONTENT ============================
  -- Arcane, ID: 62
    HL.AddCoreOverride ("Spell.CooldownRemainsP",
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
  HL.AddCoreOverride ("Spell.IsCastableP",
    function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
      local RangeOK = true;
      if Range then
        local RangeUnit = ThisUnit or Target;
        RangeOK = RangeUnit:IsInRange( Range, AoESpell );
      end

      if self == SpellFrost.GlacialSpike then
        return self:IsLearned() and RangeOK and (Player:BuffP(SpellFrost.GlacialSpikeBuff) or (Player:BuffStackP(SpellFrost.IciclesBuff) == 4 and Player:IsCasting(SpellFrost.Frostbolt))) and not Player:IsCasting(SpellFrost.GlacialSpike);
      else
        return self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeOK;
      end
    end
    , 64);

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
