--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local MouseOver = Unit.MouseOver;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- HeroRotation
  local HR = HeroRotation;
  -- Lua
  local mathmin = math.min;
  local pairs = pairs;
  -- File Locals
  local Commons = {};
  HR.Commons.Rogue = Commons;
  local Settings = HR.GUISettings.APL.Rogue.Commons;
  local Everyone = HR.Commons.Everyone;

--- ============================ CONTENT ============================
  -- Stealth
  function Commons.Stealth (Stealth, Setting)
    if Settings.StealthOOC and Stealth:IsCastable() and not Player:IsStealthed() then
      if HR.Cast(Stealth, Settings.OffGCDasOffGCD.Stealth) then return "Cast Stealth (OOC)"; end
    end
    return false;
  end

  -- Crimson Vial
  function Commons.CrimsonVial (CrimsonVial)
    if CrimsonVial:IsCastable() and Player:HealthPercentage() <= Settings.CrimsonVialHP then
      if HR.Cast(CrimsonVial, Settings.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial (Defensives)"; end
    end
    return false;
  end

  -- Feint
  function Commons.Feint (Feint)
    if Feint:IsCastable() and not Player:Buff(Feint) and Player:HealthPercentage() <= Settings.FeintHP then
      if HR.Cast(Feint, Settings.GCDasOffGCD.Feint) then return "Cast Feint (Defensives)"; end
    end
  end

  -- Marked for Death Sniping
  local BestUnit, BestUnitTTD;
  function Commons.MfDSniping (MarkedforDeath)
    if MarkedforDeath:IsCastable() then
      -- Get Units up to 30y for MfD.
      HL.GetEnemies(30);

      BestUnit, BestUnitTTD = nil, 60;
      local MOTTD = MouseOver:IsInRange(30) and MouseOver:TimeToDie() or 11111;
      local TTD;
      for _, Unit in pairs(Cache.Enemies[30]) do
        TTD = Unit:TimeToDie();
        -- Note: Increased the SimC condition by 50% since we are slower.
        if not Unit:IsMfdBlacklisted() and TTD < Player:ComboPointsDeficit()*1.5 and TTD < BestUnitTTD then
          if MOTTD - TTD > 1 then
            BestUnit, BestUnitTTD = Unit, TTD;
          else
            BestUnit, BestUnitTTD = MouseOver, MOTTD;
          end
        end
      end
      if BestUnit then
        HR.CastLeftNameplate(BestUnit, MarkedforDeath);
      end
    end
  end

  -- Everyone CanDotUnit override, originally used for Mantle legendary
  -- Is it worth to DoT the unit ?
  function Commons.CanDoTUnit (Unit, HealthThreshold)
    return Everyone.CanDoTUnit(Unit, HealthThreshold);
  end
--- ======= SIMC CUSTOM FUNCTION / EXPRESSION =======
  -- cp_max_spend
  function Commons.CPMaxSpend ()
    -- Should work for all 3 specs since they have same Deeper Stratagem Spell ID.
    return Spell.Rogue.Subtlety.DeeperStratagem:IsAvailable() and 6 or 5;
  end

  -- "cp_spend"
  function Commons.CPSpend ()
    return mathmin(Player:ComboPoints(), Commons.CPMaxSpend());
  end

  -- poisoned
  --[[ Original SimC Code
    return dots.deadly_poison -> is_ticking() ||
            debuffs.wound_poison -> check();
  ]]
  function Commons.Poisoned (Unit)
    return (Unit:Debuff(Spell.Rogue.Assassination.DeadlyPoisonDebuff) or Unit:Debuff(Spell.Rogue.Assassination.WoundPoisonDebuff)) and true or false;
  end

  -- poison_remains
  --[[ Original SimC Code
    if ( dots.deadly_poison -> is_ticking() ) {
      return dots.deadly_poison -> remains();
    } else if ( debuffs.wound_poison -> check() ) {
      return debuffs.wound_poison -> remains();
    } else {
      return timespan_t::from_seconds( 0.0 );
    }
  ]]
  function Commons.PoisonRemains (Unit)
    return (Unit:Debuff(Spell.Rogue.Assassination.DeadlyPoisonDebuff) and Unit:DebuffRemainsP(Spell.Rogue.Assassination.DeadlyPoisonDebuff))
      or (Unit:Debuff(Spell.Rogue.Assassination.WoundPoisonDebuff) and Unit:DebuffRemainsP(Spell.Rogue.Assassination.WoundPoisonDebuff))
      or 0;
  end

  -- bleeds
  --[[ Original SimC Code
    rogue_td_t* tdata = get_target_data( target );
    return tdata -> dots.garrote -> is_ticking() +
           tdata -> dots.internal_bleeding -> is_ticking() +
           tdata -> dots.rupture -> is_ticking();
  ]]
  function Commons.Bleeds ()
    return (Target:Debuff(Spell.Rogue.Assassination.Garrote) and 1 or 0) + (Target:Debuff(Spell.Rogue.Assassination.Rupture) and 1 or 0)
    + (Target:Debuff(Spell.Rogue.Assassination.CrimsonTempest) and 1 or 0) + (Target:Debuff(Spell.Rogue.Assassination.InternalBleeding) and 1 or 0);
  end

  -- poisoned_bleeds
  --[[ Original SimC Code
    int poisoned_bleeds = 0;
    for ( size_t i = 0, actors = sim -> target_non_sleeping_list.size(); i < actors; i++ )
    {
      player_t* t = sim -> target_non_sleeping_list[i];
      rogue_td_t* tdata = get_target_data( t );
      if ( tdata -> lethal_poisoned() ) {
        poisoned_bleeds += tdata -> dots.garrote -> is_ticking() +
                            tdata -> dots.internal_bleeding -> is_ticking() +
                            tdata -> dots.rupture -> is_ticking();
      }
    }
    return poisoned_bleeds;
  ]]
  local PoisonedBleedsCount = 0;
  function Commons.PoisonedBleeds ()
    PoisonedBleedsCount = 0;
    for _, Unit in pairs(Cache.Enemies[50]) do
      if Commons.Poisoned(Unit) then
        -- TODO: For loop for this ? Not sure it's worth considering we would have to make 2 times spell object (Assa is init after Commons)
        if Unit:Debuff(Spell.Rogue.Assassination.Garrote) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1;
        end
        if Unit:Debuff(Spell.Rogue.Assassination.InternalBleeding) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1;
        end
        if Unit:Debuff(Spell.Rogue.Assassination.Rupture) then
          PoisonedBleedsCount = PoisonedBleedsCount + 1;
        end
      end
    end
    return PoisonedBleedsCount;
  end
