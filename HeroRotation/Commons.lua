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
  local AbilitySettings = HR.GUISettings.Abilities;

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

  function Commons.IsSoloMode()
    return Settings.SoloMode and not Player:IsInRaid() and not Player:IsInDungeon();
  end

  function Commons.PSCDEquipped ()
    return (HL.Equipment[13] == 167555 or HL.Equipment[14] == 167555)
  end

  function Commons.PSCDEquipReady ()
    return (Commons.PSCDEquipped() and HL.Item(167555):IsReady())
  end

  function Commons.CyclotronicBlastReady ()
    local PSCDString = ""
    if HL.Equipment[13] == 167555 then
      PSCDString = GetInventoryItemLink("player", 13)
    elseif HL.Equipment[14] == 167555 then
      PSCDString = GetInventoryItemLink("player", 14)
    else
      return false
    end
    return (Commons.PSCDEquipReady() and string.match(PSCDString, "167672"))
  end

  do
    local S = {
      ReapingFlames     = Spell(310690),
      ReapingFlamesBuff = Spell(311202)
    }

    S.ReapingFlames:RegisterDamage(
      function ()
        -- Damage formula is based on ilevel scaling of the neck
        -- 134.6154 coefficient * PLAYER_SPECIAL_SCALE8 damage_replace_stat * Versatility
        local Damage = 134.6154 * Spell:EssenceScaling() * (1 + Player:VersatilityDmgPct() / 100)
        if Player:BuffP(S.ReapingFlamesBuff) then
          Damage = Damage * 2
        end
        return Damage
      end
    )

    function Commons.ReapingFlamesCast (EssenceDisplayStyle)
      if not S.ReapingFlames:IsCastableP() then
        return nil
      end

      -- Reaping Flames Death Sniping
      local BestUnit = nil
      local LowestUnitTTD = 9999
      if AbilitySettings.ReapingFlamesSniping then
        local BestUnitTTD, BestUnitHealth = 0, 0
        local DamageThreshold = S.ReapingFlames:Damage()

        HL.GetEnemies(AbilitySettings.ReapingFlamesSnipingRange)
        for _, CycleUnit in pairs(Cache.Enemies[AbilitySettings.ReapingFlamesSnipingRange]) do
          if CycleUnit:AffectingCombat() and not CycleUnit:IsUserCycleBlacklisted() then
            local CycleHealth = CycleUnit:Health()
            local CycleTTD = HL.OffsetRemains(CycleUnit:TimeToDie(), "Auto")

            -- Prioritize HP-based sniping over duration sniping to maximize damage
            if CycleHealth < DamageThreshold then
              if CycleHealth > BestUnitHealth then
                BestUnit = CycleUnit
                BestUnitTTD = 9999
                BestUnitHealth = CycleHealth
              end
            else
              -- If a target isn't in one-shot range, check if it's within the timer threshold
              -- Select the longest-living target that is below 3 seconds
              if CycleTTD < 2.5 and CycleTTD > BestUnitTTD then
                BestUnit = CycleUnit
                BestUnitTTD = CycleTTD
                BestUnitHealth = CycleHealth
              end
            end

            -- Store lowest add TTD for main target logic below
            if CycleTTD < LowestUnitTTD and CycleUnit:GUID() ~= Target:GUID() then
              LowestUnitTTD = CycleTTD
            end
          end
        end

        if BestUnit then
          if BestUnit:GUID() == Target:GUID() then
            if HR.Cast(S.ReapingFlames, nil, EssenceDisplayStyle) then return "Cast Reaping Flames Execute"; end
          else
            HR.CastLeftNameplate(BestUnit, S.ReapingFlames);
          end
        end
      end

      -- Primary Reaping Flames Logic
      -- Don't use 45 second cooldowns if there is any potential sniping target from above
      -- reaping_flames,target_if=target.time_to_die<1.5|((target.health.pct>80|target.health.pct<=20)&(active_enemies=1|variable.reaping_delay>29))|(target.time_to_pct_20>30&(active_enemies=1|variable.reaping_delay>44))
      if ((Target:HealthPercentage() > 80 or Target:HealthPercentage() <= 20) and LowestUnitTTD > 16) or (Target:TimeToX(20) > 30 and LowestUnitTTD > 44) then
        if HR.Cast(S.ReapingFlames, nil, EssenceDisplayStyle) then return "Cast Reaping Flames"; end
      end
    end
  end
