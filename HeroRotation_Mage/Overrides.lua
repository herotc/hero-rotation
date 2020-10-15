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

  -- Util
  local function num(val)
    if val then return 1 else return 0 end
  end

  local function bool(val)
    return val ~= 0
  end

--- ============================ CONTENT ============================
  -- Mage
    local RopDuration = SpellArcane.RuneofPower:BaseDuration()

    local function ROPRemains(ROP)
      return math.max(RopDuration - ROP:TimeSinceLastAppliedOnPlayer() - HL.RecoveryTimer())
    end

  -- Arcane, ID: 62
    local ArcaneOldPlayerAffectingCombat
    ArcaneOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
      function (self)
        return SpellArcane.Frostbolt:InFlight() or ArcaneOldPlayerAffectingCombat(self)
      end
    , 64);

    local ArcaneOldSpellCooldownRemains
    ArcaneOldSpellCooldownRemains = HL.AddCoreOverride("Spell.CooldownRemains",
    function (self, BypassRecovery, Offset)
      if self == SpellArcane.RuneofPower and Player:IsCasting(self) then
        return RopDuration
      else
        return ArcaneOldSpellCooldownRemains(self, BypassRecovery, Offset)
      end
    end
    , 62);

    local ArcanePlayerBuffRemains
    ArcanePlayerBuffRemains = HL.AddCoreOverride("Player.BuffRemains",
    function (self, Spell, AnyCaster, Offset)
      if Spell == SpellArcane.RuneofPowerBuff then
        return self:IsCasting(SpellArcane.RuneofPower) and RopDuration or ROPRemains(Spell)
      else
        return ArcanePlayerBuffRemains(self, Spell, AnyCaster, Offset)
      end
    end
    , 62);

    local ArcanePlayerBuff
    ArcanePlayerBuff = HL.AddCoreOverride("Player.BuffUp",
    function (self, Spell, AnyCaster, Offset)
      local BaseCheck = ArcanePlayerBuff(self, Spell, AnyCaster, Offset)
      if Spell == SpellArcane.RuneofPowerBuff then
        return self:IsCasting(SpellArcane.RuneofPower) or (ROPRemains(Spell) > 0)
      elseif Spell == SpellArcane.RuleofThreesBuff then
        if self:IsCasting(SpellArcane.ArcaneBlast) then
          return self:ArcaneCharges() == 2
        else
          return BaseCheck
        end
      else
        return BaseCheck
      end
    end
    , 62);

  -- Fire, ID: 63
    local function HeatLevelPredicted ()
      if Player:BuffUp(SpellFire.HotStreakBuff) then
        return 2;
      end
      return math.min(
          num(Player:BuffUp(SpellFire.HeatingUpBuff))
        + num(Player:BuffUp(SpellFire.CombustionBuff) and (Player:IsCasting(SpellFire.Fireball) or Player:IsCasting(SpellFire.Scorch) or Player:IsCasting(SpellFire.Pyroblast)))
        + num((Player:IsCasting(SpellFire.Scorch) and (Target:HealthPercentage() <= 30 and SpellFire.SearingTouch:IsAvailable())))
        + num(bool(SpellFire.Firestarter:ActiveStatus()) and (Player:IsCasting(SpellFire.Fireball) or Player:IsCasting(SpellFire.Pyroblast)))
        + num(SpellFire.PhoenixFlames:InFlight())
        + num(SpellFire.Pyroblast:InFlight(SpellFire.CombustionBuff))
        + num(SpellFire.Fireball:InFlight(SpellFire.CombustionBuff))
        ,2);
    end

    HL.AddCoreOverride("Player.BuffStack",
      function (self, Spell, AnyCaster, Offset)
        if Spell == SpellFire.HotStreakBuff then
          return ( HeatLevelPredicted() == 2 ) and 1 or 0
        elseif Spell == SpellFire.HeatingUpBuff then
          return ( HeatLevelPredicted() == 1 ) and 1 or 0
        elseif Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
          return 0
        elseif self:BuffRemains(Spell, AnyCaster, Offset) then
          return self:BuffStack(Spell, AnyCaster)
        else
          return 0
        end
      end
    , 63);

    local FirePlayerBuffRemains
    FirePlayerBuffRemains = HL.AddCoreOverride("Player.BuffRemains",
    function (self, Spell, AnyCaster, Offset)
      local BaseCheck = FirePlayerBuffRemains(self, Spell, AnyCaster, Offset)
      if Spell == SpellFire.HotStreakBuff and BaseCheck == 0 then
        return ( HeatLevelPredicted() == 2 ) and 15 or 0
      elseif Spell == SpellFire.RuneofPowerBuff then
        return ROPRemains(SpellFire.RuneofPowerBuff)
      elseif Spell == SpellFire.PyroclasmBuff and self:IsCasting(SpellFire.Pyroblast) then
        return 0
      end
      return self:BuffRemains(Spell, AnyCaster, Offset or "Auto")
    end
    , 63);

    HL.AddCoreOverride("Player.BuffUp",
    function (self, Spell, AnyCaster, Offset)
      if Spell == SpellFire.RuneofPowerBuff then
        return (SpellFire.RuneofPowerBuff:TimeSinceLastAppliedOnPlayer() - HL.RecoveryTimer()) <= RopDuration
      end
      return self:BuffRemains(Spell, AnyCaster, Offset or "Auto") > 0
    end
    , 63);

    HL.AddCoreOverride("Spell.IsCastable",
    function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
      local RangeOK = true;
      if Range then
        local RangeUnit = ThisUnit or Target;
        RangeOK = RangeUnit:IsInRange( Range, AoESpell );
      end

      local BaseCheck = self:IsLearned() and self:CooldownRemains( BypassRecovery, Offset or "Auto") == 0 and RangeOK
      if self == SpellFire.RuneofPower then
        return BaseCheck and not Player:IsCasting(SpellFire.RuneofPower)
      elseif self == SpellFire.DragonsBreath then
        return BaseCheck
      else
        return BaseCheck
      end
    end
    , 63);

    local FireOldPlayerAffectingCombat
    FireOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
    function (self)
      return  FireOldPlayerAffectingCombat(self)
           or SpellFire.Pyroblast:InFlight()
           or SpellFire.Fireball:InFlight()
           or SpellFire.PhoenixFlames:InFlight()
    end
    , 63);

  -- Frost, ID: 64
    local FrostOldSpellIsCastable
    FrostOldSpellIsCastable = HL.AddCoreOverride("Spell.IsCastable",
      function (self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
        local RangeOK = true;
        if Range then
          local RangeUnit = ThisUnit or Target;
          RangeOK = RangeUnit:IsInRange( Range, AoESpell );
        end
        if self == SpellFrost.GlacialSpike then
          return self:IsLearned() and RangeOK and (Player:BuffUp(SpellFrost.GlacialSpikeBuff) or (Player:BuffStack(SpellFrost.IciclesBuff) == 5));
        else
          local BaseCheck = FrostOldSpellIsCastable(self, Range, AoESpell, ThisUnit, BypassRecovery, Offset)
          if self == SpellFrost.SummonWaterElemental then
            return BaseCheck and not Pet:IsActive()
          else
            return BaseCheck
          end
        end
      end
    , 64);

    local FrostOldSpellCooldownRemains
    FrostOldSpellCooldownRemains = HL.AddCoreOverride("Spell.CooldownRemains",
      function (self, BypassRecovery, Offset)
        if self == SpellFrost.Blizzard and Player:IsCasting(self) then
          return 8;
        elseif self == SpellFrost.Ebonbolt and Player:IsCasting(self) then
          return 45;
        else
          return FrostOldSpellCooldownRemains(self, BypassRecovery, Offset)
        end
      end
    , 64);

    local FrostOldPlayerBuffStack
    FrostOldPlayerBuffStack = HL.AddCoreOverride("Player.BuffStack",
      function (self, Spell, AnyCaster, Offset)
        local BaseCheck = FrostOldPlayerBuffStack(self, Spell, AnyCaster, Offset)
        if Spell == SpellFrost.IciclesBuff then
          return self:IsCasting(SpellFrost.GlacialSpike) and 0 or math.min(BaseCheck + (self:IsCasting(SpellFrost.Frostbolt) and 1 or 0), 5)
        elseif Spell == SpellFrost.GlacialSpikeBuff then
          return self:IsCasting(SpellFrost.GlacialSpike) and 0 or BaseCheck
        elseif Spell == SpellFrost.WintersReachBuff then
          return self:IsCasting(SpellFrost.Flurry) and 0 or BaseCheck
        elseif Spell == SpellFrost.FingersofFrostBuff then
          if SpellFrost.IceLance:InFlight() then
            if BaseCheck == 0 then
              return 0
            else
              return BaseCheck - 1
            end
          else
            return BaseCheck
          end
        else
          return BaseCheck
        end
      end
    , 64);

    local FrostOldTargetDebuffStack
    FrostOldTargetDebuffStack = HL.AddCoreOverride("Target.DebuffStack",
      function (self, Spell, AnyCaster, Offset)
        local BaseCheck = FrostOldTargetDebuffStack(self, Spell, AnyCaster, Offset)
        if Spell == SpellFrost.WintersChillDebuff then
          if SpellFrost.Flurry:InFlight() then
            return 2
          elseif SpellFrost.IceLance:InFlight() then
            if BaseCheck == 0 then
              return 0
            else
              return BaseCheck - 1
            end
          else
            return BaseCheck
          end
        else
          return BaseCheck
        end
      end
    , 64);

    local FrostOldTargetDebuffRemains
    FrostOldTargetDebuffRemains = HL.AddCoreOverride("Target.DebuffRemains",
      function (self, Spell, AnyCaster, Offset)
        local BaseCheck = FrostOldTargetDebuffRemains(self, Spell, AnyCaster, Offset)
        if Spell == SpellFrost.WintersChillDebuff then
          return SpellFrost.Flurry:InFlight() and 6 or BaseCheck
        else
          return BaseCheck
        end
      end
    , 64);

    local FrostOldPlayerAffectingCombat
    FrostOldPlayerAffectingCombat = HL.AddCoreOverride("Player.AffectingCombat",
      function (self)
        return SpellFrost.Frostbolt:InFlight() or FrostOldPlayerAffectingCombat(self)
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
