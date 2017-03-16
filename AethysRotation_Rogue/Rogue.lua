--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  local pairs = pairs;
  -- File Locals
  AR.Commons.Rogue = {};
  local Settings = AR.GUISettings.APL.Rogue.Commons;


--- ============================ CONTENT ============================
  -- Stealth
  function AR.Commons.Rogue.Stealth (Stealth, Setting)
    if Stealth:IsCastable() and not Player:IsStealthed() then
      if AR.Cast(Stealth, Settings.OffGCDasOffGCD.Stealth) then return "Cast Stealth (OOC)"; end
    end
    return false;
  end

  -- Crimson Vial
  function AR.Commons.Rogue.CrimsonVial (CrimsonVial)
    if CrimsonVial:IsCastable() and Player:HealthPercentage() <= Settings.CrimsonVialHP then
      if AR.Cast(CrimsonVial, Settings.GCDasOffGCD.CrimsonVial) then return "Cast Crimson Vial (Defensives)"; end
    end
    return false;
  end

  -- Feint
  function AR.Commons.Rogue.Feint (Feint)
    if Feint:IsCastable() and not Player:Buff(Feint) and Player:HealthPercentage() <= Settings.FeintHP then
      if AR.Cast(Feint, Settings.GCDasOffGCD.Feint) then return "Cast Feint (Defensives)"; end
    end
  end

  -- Marked for Death Sniping
  local BestUnit, BestUnitTTD;
  function AR.Commons.Rogue.MfDSniping (MarkedforDeath)
    if MarkedforDeath:IsCastable() then
      -- Get Units up to 30y for MfD.
      AC.GetEnemies(30);

      BestUnit, BestUnitTTD = nil, 60;
      for _, Unit in pairs(Cache.Enemies[30]) do
        -- I increased the SimC condition by 50% since we are slower.
        if not Unit:IsMfdBlacklisted() and Unit:TimeToDie() < Player:ComboPointsDeficit()*1.5 and Unit:TimeToDie() < BestUnitTTD then
          BestUnit, BestUnitTTD = Unit, Unit:TimeToDie();
        end
      end
      if BestUnit then
        AR.CastLeftNameplate(BestUnit, MarkedforDeath);
      end
    end
  end

--- ======= SIMC CUSTOM EXPRESSION =======
  -- cp_max_spend
  function AR.Commons.Rogue.CPMaxSpend ()
    -- Should work for all 3 specs since they have same Deeper Stratagem Spell ID.
    return Spell.Rogue.Subtlety.DeeperStratagem:IsAvailable() and 6 or 5;
  end

  -- mantle_duration
  --[[ Original SimC Code
    if ( buffs.mantle_of_the_master_assassin_aura -> check() )
    {
      timespan_t nominal_master_assassin_duration = timespan_t::from_seconds( spell.master_assassins_initiative -> effectN( 1 ).base_value() );
      if ( buffs.vanish -> check() )
        return buffs.vanish -> remains() + nominal_master_assassin_duration;
      // Hardcoded 1.0 since we consider that stealth will break on next gcd.
      else
        return timespan_t::from_seconds( 1.0 ) + nominal_master_assassin_duration;
    }
    else if ( buffs.mantle_of_the_master_assassin -> check() )
      return buffs.mantle_of_the_master_assassin -> remains();
    else
      return timespan_t::from_seconds( 0.0 );
  ]]
  local MasterAssassinsInitiative, NominalDuration = Spell(235027), 6;
  function AR.Commons.Rogue.MantleDuration ()
    if Player:BuffRemains(MasterAssassinsInitiative) < 0 then
      -- Should work for all 3 specs since they have same Vanish Buff Spell ID.
      if Player:Buff(Spell.Rogue.Subtlety.VanishBuff) then
        return Player:BuffRemains(Spell.Rogue.Subtlety.VanishBuff) + NominalDuration;
      else
        return 1 + NominalDuration;
      end
    else
      return Player:BuffRemains(MasterAssassinsInitiative);
    end
  end
