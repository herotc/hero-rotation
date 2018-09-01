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
    local SpellArcane = Spell.Mage.Arcane;
    local SpellFire   = Spell.Mage.Fire;
    local SpellFrost  = Spell.Mage.Frost;

    local Settings = {
      General = HR.GUISettings.General,
      Commons = HR.GUISettings.APL.Mage.Commons,
      Frost = HR.GUISettings.APL.Mage.Frost,
      Fire = HR.GUISettings.APL.Mage.Fire,
      Arcane = HR.GUISettings.APL.Mage.Arcane,
    };

  -- Lua

  local function num(val)
    if val then return 1 else return 0 end
  end

  local function bool(val)
    return val ~= 0
  end
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
    local function HeatLevelPredicted ()
      if Player:BuffP(SpellFire.HotStreakBuff) then
        return 2;
      end
      return math.min(
          num(Player:BuffP(SpellFire.HeatingUpBuff))
        + num(Player:BuffP(SpellFire.CombustionBuff) and (Player:IsCasting(SpellFire.Fireball) or Player:IsCasting(SpellFire.Scorch) or Player:IsCasting(SpellFire.Pyroblast)))
        + num((Player:IsCasting(SpellFire.Scorch) and (Target:HealthPercentage() <= 30 and (Item.Mage.Fire.Item132454:IsEquipped() or SpellFire.SearingTouch:IsAvailable()))))
        + num(bool(SpellFire.Firestarter:ActiveStatus()) and (Player:IsCasting(SpellFire.Fireball) or Player:IsCasting(SpellFire.Pyroblast)))
        + num(SpellFire.PhoenixFlames:InFlight())
        + num(SpellFire.Pyroblast:InFlight(SpellFire.CombustionBuff))
        + num(SpellFire.Fireball:InFlight(SpellFire.CombustionBuff))
        ,2);
    end

    HL.AddCoreOverride ("Player.BuffStackP",
      function (self, Spell, AnyCaster, Offset)
        if Spell == SpellFire.HotStreakBuff then
          return ( HeatLevelPredicted() == 2 ) and 1 or 0
        elseif Spell == SpellFire.HeatingUpBuff then
          return ( HeatLevelPredicted() == 1 ) and 1 or 0
        elseif Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
          return 0
        elseif self:BuffRemainsP(Spell, AnyCaster, Offset) then
          return self:BuffStack(Spell, AnyCaster)
        else
          return 0
        end
      end
    , 63);

    HL.AddCoreOverride ("Player.BuffRemainsP",
    function (self, Spell, AnyCaster, Offset)
      if Spell == SpellFire.HotStreakBuff and Player:BuffDownP(SpellFire.HotStreakBuff) then
        return ( HeatLevelPredicted() == 2 ) and 15 or 0
      elseif Spell == SpellFire.RuneofPowerBuff then
        local ROPtime = HL.OffsetRemains(SpellFire.RuneofPowerBuff:TimeSinceLastAppliedOnPlayer(), "Auto")
        return math.max(10-ROPtime, 0)
      elseif Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
        return 0
      end
      return self:BuffRemains(Spell, AnyCaster, Offset or "Auto")
    end
    , 63);

    HL.AddCoreOverride ("Player.BuffP",
    function (self, Spell, AnyCaster, Offset)
      if Spell == SpellFire.RuneofPowerBuff then
        return HL.OffsetRemains(SpellFire.RuneofPowerBuff:TimeSinceLastAppliedOnPlayer(), "Auto") <= 10
      end
      return self:BuffRemains(Spell, AnyCaster, Offset or "Auto") > 0
    end
    , 63);

    HL.AddCoreOverride ("Spell.IsCastableP",
    function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
      local RangeOK = true;
      if Range then
        local RangeUnit = ThisUnit or Target;
        RangeOK = RangeUnit:IsInRange( Range, AoESpell );
      end

      local BaseCheck = self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeOK
      if self == SpellFire.RuneofPower then
        return BaseCheck and not Player:IsCasting(SpellFire.RuneofPower)
      else
        return BaseCheck
      end
    end
    , 63);

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
          local BaseCheck = self:IsLearned() and self:CooldownRemainsP( BypassRecovery, Offset or "Auto") == 0 and RangeOK
          if self == SpellFrost.WaterElemental then
            return BaseCheck and not Pet:IsActive()
          else
            return BaseCheck
          end
        end
      end
    , 64);

    HL.AddCoreOverride ("Spell.CooldownRemainsP",
      function (self, BypassRecovery, Offset)
        if self == SpellFrost.Blizzard and Player:IsCasting(self) then
          return 8;
        elseif self == SpellFrost.Ebonbolt and Player:IsCasting(self) then
          return 45;
        else
          return self:CooldownRemains( BypassRecovery, Offset or "Auto" );
        end
      end
    , 64);

    HL.AddCoreOverride ("Player.BuffStackP",
      function (self, Spell, AnyCaster, Offset)
        if Spell == SpellFrost.BrainFreezeBuff and self:IsCasting(SpellFrost.Ebonbolt) then
          return 1
        elseif self:BuffRemainsP(Spell, AnyCaster, Offset) then
          return self:BuffStack(Spell, AnyCaster)
        else
          return 0
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
