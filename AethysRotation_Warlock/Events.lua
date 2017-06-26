--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;
  -- AethysCore
  local AC = AethysCore;
  local AR = AethysRotation;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- Lua
  
  -- File Locals
  


--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======
  -- OnSpecChange
  local SpecTimer = 0;
  AC:RegisterForEvent(
    function (Event)
      -- Prevent the first event firing (when login)
      if not AC.PulseInitialized then return; end
      -- Timer to prevent bug due to the double/triple event firing.
      -- Since it takes 5s to change spec, we'll take 3seconds as timer.
      if AC.GetTime() > SpecTimer then
        -- Update the timer only on valid scan.
        if AR.PulseInit() ~= "Invalid SpecID" then
          SpecTimer = AC.GetTime() + 3;
        end
      end
    end
    , "PLAYER_SPECIALIZATION_CHANGED"
  );

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
  
  AC.ImmolationTable = {
      Destruction = {
        ImmolationDebuff = {},
      }
    };
    
  AC.GuardiansTable = {
      --{PetType,petID,dateEvent,UnitPetGUID,DE_Buffed}
      Pets = {
      },
      PetList={[55659]="Wild Imp",[99737]="Wild Imp",[98035]="Dreadstalker",[11859]="Doomguard",[89]="Infernal"}
    };
  
  
    --------------------------
    ----- Destruction --------
    --------------------------
    -- Immolate OnApply/OnRefresh Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        --- Record the Immolate
        if SpellID == 157736 then
          AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = 0;
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Immolate OnRemove Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Removes the Unit from Immolate Table
        if SpellID == 157736 then
          if AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
               AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Immolate OnUnitDeath Listener
    AC:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);
        -- Removes the Unit from Immolate Table
        if AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
          AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );
    -- Conflagrate Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Add a stack to the table
        if SpellID == 17962 then
          if AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
               AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = AC.ImmolationTable.Destruction.ImmolationDebuff[DestGUID]+1;
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    
    
    --------------------------
    ----- Demonology ---------
    --------------------------
    --Guardians table
    AC:RegisterForSelfCombatEvent(
      function (...)
        dateEvent,_,_,_,_,_,_,UnitPetGUID=select(1,...)
       
        local t={} ; i=1
        for str in string.gmatch(UnitPetGUID, "([^-]+)") do
          t[i] = str
          i = i + 1
        end
        local PetType=AC.GuardiansTable.PetList[tonumber(t[6])]
        if PetType then
          table.insert(AC.GuardiansTable.Pets,{PetType,tonumber(t[6]),GetTime(),UnitPetGUID,false})
        end

      end
      , "SPELL_SUMMON"
    );
    
    --Buff all guardians
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);
        if SpellID == 193396 then
          for key, Value in pairs(AC.GuardiansTable.Pets) do
            AC.GuardiansTable.Pets[key][5]=true
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
