--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, HR = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- Lua
  local pairs = pairs;
  -- File Locals
  HR.Commons = {};
  local Commons = {};
  HR.Commons.Everyone = Commons;
  local Settings = HR.GUISettings.General;


--- ============================ CONTENT ============================
  -- Is the current target valid ?
  function Commons.TargetIsValid ()
    return Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost();
  end

  -- Put EnemiesCount to 1 if we have AoEON or are targetting an AoE insensible unit
  local AoEInsensibleUnit = {
    --- Legion
      ----- Dungeons (7.0 Patch) -----
      --- Mythic+ Affixes
        -- Fel Explosives (7.2 Patch)
        [120651] = true
  }
  function Commons.AoEToggleEnemiesUpdate ()
    if not HR.AoEON() or AoEInsensibleUnit[Target:NPCID()] then
      for Key, Value in pairs(Cache.EnemiesCount) do
        Cache.EnemiesCount[Key] = math.min(1, Cache.EnemiesCount[Key]);
      end
    end
  end

  -- Is the current unit valid during cycle ?
  function Commons.UnitIsCycleValid (Unit, BestUnitTTD, TimeToDieOffset)
    return not Unit:IsFacingBlacklisted() and not Unit:IsUserCycleBlacklisted() and (not BestUnitTTD or Unit:FilteredTimeToDie(">", BestUnitTTD, TimeToDieOffset));
  end

  -- Is it worth to DoT the unit ?
  function Commons.CanDoTUnit (Unit, HealthThreshold)
    return Unit:Health() >= HealthThreshold or Unit:IsDummy();
  end

  -- Interrupt
  function Commons.Interrupt (Range, Spell, Setting, StunSpells)
    if Settings.InterruptEnabled and Target:IsInterruptible() and Target:IsInRange(Range) then
      if Spell:IsCastable() then
        if HR.Cast(Spell, Setting) then return "Cast " .. Spell:Name() .. " (Interrupt)"; end
      elseif Settings.InterruptWithStun and Target:CanBeStunned() then
        if StunSpells then
          for i = 1, #StunSpells do
            if StunSpells[i][1]:IsCastable() and StunSpells[i][3]() then
              if HR.Cast(StunSpells[i][1]) then return StunSpells[i][2]; end
            end
          end
        end
      end
    end
  end
