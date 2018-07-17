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
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- Lua
  local pairs = pairs;
  local select = select;
  -- File Locals



--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======


--- ======= COMBATLOG =======
  --- Combat Log Arguments
    ------- Base -------
      --     1        2         3           4           5           6              7             8         9        10           11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags

    ------- Prefixes -------
      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --    12        13          14
      -- SpellID, SpellName, SpellSchool

    ------- Suffixes -------
      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --     15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --    15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --    15       16
      -- AuraType, Charges

      --- _INTERRUPT
      --      15            16             17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --   15         16         17        18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --   15       16       17       18        19       20        21        22        23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --    15        16           17
      -- MissType, IsOffHand, AmountMissed

    ------- Special -------
      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments

  -- Arguments Variables
  local DestGUID, SpellID;

  -- TODO: Register/Unregister Events on SpecChange
  HL.BleedTable = {
    Assassination = {
      Garrote = {},
      Rupture = {}
    },
    Subtlety = {
      Nightblade = {},
    }
  };
  local BleedGUID;
  --- Exsanguinated Handler
    -- Exsanguinate Expression
    local BleedDuration, BleedExpires;
    function HL.Exsanguinated (Unit, SpellName)
      BleedGUID = Unit:GUID();
      if BleedGUID then
        if SpellName == "Garrote" then
          if HL.BleedTable.Assassination.Garrote[BleedGUID] then
              return HL.BleedTable.Assassination.Garrote[BleedGUID][3];
          end
        elseif SpellName == "Rupture" then
          if HL.BleedTable.Assassination.Rupture[BleedGUID] then
              return HL.BleedTable.Assassination.Rupture[BleedGUID][3];
          end
        end
      end
      return false;
    end
    -- Exsanguinate OnCast Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Exsanguinate
        if SpellID == 200806 then
          for Key, _ in pairs(HL.BleedTable.Assassination) do
            for Key2, _ in pairs(HL.BleedTable.Assassination[Key]) do
              if Key2 == DestGUID then
                  -- Change the Exsanguinate info to true
                  HL.BleedTable.Assassination[Key][Key2][3] = true;
              end
            end
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    -- Bleed infos
    local function GetBleedInfos (GUID, SpellID)
      -- Core API is not used since we don't want cached informations
      for i = 1, HL.MAXIMUM do
        local auraInfo = {UnitAura(GUID, i, "HARMFUL|PLAYER")};
        if auraInfo[10] == SpellID then
          return auraInfo[5];
        end
      end
      return nil
    end
    -- Bleed OnApply/OnRefresh Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        --- Record the Bleed Target and its Infos
        -- Garrote
        if SpellID == 703 then
          BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
          HL.BleedTable.Assassination.Garrote[DestGUID] = {BleedDuration, BleedExpires, false};
        -- Rupture
        elseif SpellID == 1943 then
          BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
          HL.BleedTable.Assassination.Rupture[DestGUID] = {BleedDuration, BleedExpires, false};
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Bleed OnRemove Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Removes the Unit from Garrote Table
        if SpellID == 703 then
          if HL.BleedTable.Assassination.Garrote[DestGUID] then
              HL.BleedTable.Assassination.Garrote[DestGUID] = nil;
          end
        -- Removes the Unit from Rupture Table
        elseif SpellID == 1943 then
          if HL.BleedTable.Assassination.Rupture[DestGUID] then
              HL.BleedTable.Assassination.Rupture[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Bleed OnUnitDeath Listener
    HL:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);

        -- Removes the Unit from Garrote Table
        if HL.BleedTable.Assassination.Garrote[DestGUID] then
          HL.BleedTable.Assassination.Garrote[DestGUID] = nil;
        end
        -- Removes the Unit from Rupture Table
        if HL.BleedTable.Assassination.Rupture[DestGUID] then
          HL.BleedTable.Assassination.Rupture[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );

  --- Finality Nightblade Handler
    function HL.Finality (Unit)
      BleedGUID = Unit:GUID();
      if BleedGUID then
        if HL.BleedTable.Subtlety.Nightblade[BleedGUID] then
          return HL.BleedTable.Subtlety.Nightblade[BleedGUID];
        end
      end
      return false;
    end
    -- Nightblade OnApply/OnRefresh Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        if SpellID == 195452 then
          HL.BleedTable.Subtlety.Nightblade[DestGUID] = true;
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Nightblade OnRemove Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        if SpellID == 195452 then
          if HL.BleedTable.Subtlety.Nightblade[DestGUID] then
            HL.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Nightblade OnUnitDeath Listener
    HL:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);

        if HL.BleedTable.Subtlety.Nightblade[DestGUID] then
          HL.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );
  --- Relentless Strikes Energy Prediction
    -- Variables
    Player.RSOffset = {
      Offset = 0;
      FinishDestGUID = nil;
      FinishCount = 0;
    };
    -- Return RS adjusted Energy Predicted
    function Player:EnergyPredictedWithRS()
        return Player:EnergyPredicted() + Player.RSOffset.Offset;
    end
    -- Return RS adjusted Energy Deficit Predicted
    function Player:EnergyDeficitPredictedWithRS()
        return Player:EnergyDeficitPredicted() - Player.RSOffset.Offset;
    end
    -- Zero RSOffset after receiving relentless strikes energize
    HL:RegisterForSelfCombatEvent(
      function (...)
        local rsspellid = select(12, ...)
        if (rsspellid == 98440) then
          Player.RSOffset.Offset = 0;
        end
      end
      , "SPELL_ENERGIZE"
    );
    -- Running Combo Point tally to access after casting finisher
    HL:RegisterForEvent(
      function (...)
        local type = select(3, ...)
        if (type == "COMBO_POINTS") and (Player:ComboPoints() > 0) then
          Player.RSOffset.Offsetvote = Player:ComboPoints()*6.0;
        end
      end
      , "UNIT_POWER_UPDATE"
    );
    -- Set RSOffset when casting a finisher
    HL:RegisterForSelfCombatEvent(
      function (...)
        local spellID = select(12, ...)
        -- Evis & Nightblade & DfA spellIDs
        if (spellID == 196819 or spellID == 195452 or spellID == 152150) then
          Player.RSOffset.FinishDestGUID = select(8, ...);
          Player.RSOffset.FinishCount = Player.RSOffset.FinishCount + 1;
          Player.RSOffset.Offset = Player.RSOffset.Offsetvote;
          -- Backup clear
          C_Timer.After(2, function ()
              if Player.RSOffset.FinishCount == 1 then
                Player.RSOffset.Offset = 0;
              end
              Player.RSOffset.FinishCount = Player.RSOffset.FinishCount - 1;
            end
          );
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    -- Prevent RSOffset getting stuck when target dies mid-finisher (mostly DfA)
    HL:RegisterForCombatEvent(
      function (...)
        local DestGUID = select(8, ...);
        if Player.RSOffset.FinishDestGUID == DestGUID then
          Player.RSOffset.Offset = 0;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );
  --- Shadow Techniques Tracking
    -- Variables
    Player.ShadowTechniques = {
      Counter = 0;
      LastMH = 0;
      LastOH = 0;
    };
    -- Return Time to x-th auto attack since last proc
    function Player:TimeToSht(hit)
      local mhSpeed, ohSpeed = UnitAttackSpeed("player");
      local aaTable = {};
      for i=1,5 do
        table.insert(aaTable, Player.ShadowTechniques.LastMH + i * mhSpeed);
        table.insert(aaTable, Player.ShadowTechniques.LastOH + i * ohSpeed);
      end
      table.sort(aaTable);
      local hitInTable = min(5,max(1, hit - Player.ShadowTechniques.Counter));
      return aaTable[hitInTable] - GetTime()
    end
    -- Reset on entering world
    HL:RegisterForSelfCombatEvent(
      function (...)
        Player.ShadowTechniques.Counter = 0;
        Player.ShadowTechniques.LastMH = GetTime();
        Player.ShadowTechniques.LastOH = GetTime();
      end
      , "PLAYER_ENTERING_WORLD"
    );
    -- Reset counter on energize
    HL:RegisterForSelfCombatEvent(
      function (...)
        SpellID = select(12, ...);
        if SpellID == 196911 then
          Player.ShadowTechniques.Counter = 0;
        end
      end
      , "SPELL_ENERGIZE"
    );
    -- Increment counter on cast succcess for Shadow Blades
    HL:RegisterForSelfCombatEvent(
      function (...)
        SpellID = select(12, ...);
        -- Shadow Blade: MH 121473, OH 121474
        if SpellID == 121473 then
          Player.ShadowTechniques.LastMH = GetTime();
          Player.ShadowTechniques.Counter = Player.ShadowTechniques.Counter + 1;
        elseif SpellID == 121474 then
          Player.ShadowTechniques.LastOH = GetTime();
          Player.ShadowTechniques.Counter = Player.ShadowTechniques.Counter + 1;
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    -- Increment counter on successful swings
    HL:RegisterForSelfCombatEvent(
      function (...)
        Player.ShadowTechniques.Counter = Player.ShadowTechniques.Counter + 1;
        local IsOffHand = select(24, ...);
        if IsOffHand then
          Player.ShadowTechniques.LastOH = GetTime();
        else
          Player.ShadowTechniques.LastMH = GetTime();
        end
      end
      , "SWING_DAMAGE"
    );
    -- Remember timers on Shadow Blade fails
    HL:RegisterForSelfCombatEvent(
      function (...)
        SpellID = select(12, ...);
        -- Shadow Blade: MH 121473, OH 121474
        if SpellID == 121473 then
          Player.ShadowTechniques.LastMH = GetTime();
        elseif SpellID == 121474 then
          Player.ShadowTechniques.LastOH = GetTime();
        end
      end
      , "SPELL_CAST_FAILED"
    );
    -- Remember timers on swing misses
    HL:RegisterForSelfCombatEvent(
      function (...)
        local IsOffHand = select(16, ...);
        if IsOffHand then
          Player.ShadowTechniques.LastOH = GetTime();
        else
          Player.ShadowTechniques.LastMH = GetTime();
        end
      end
      , "SWING_MISSED"
    );
