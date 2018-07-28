--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, HR = ...;
  -- HeroLib
  local HL = HeroLib;
  local HR = HeroRotation;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  -- Lua
  
  -- File Locals
  


--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======
  -- OnSpecChange
  local SpecTimer = 0;
  HL:RegisterForEvent(
    function (Event)
      -- Prevent the first event firing (when login)
      if not HL.PulseInitialized then return; end
      -- Timer to prevent bug due to the double/triple event firing.
      -- Since it takes 5s to change spec, we'll take 3seconds as timer.
      if HL.GetTime() > SpecTimer then
        -- Update the timer only on valid scan.
        if HR.PulseInit() ~= "Invalid SpecID" then
          SpecTimer = HL.GetTime() + 3;
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
  
  HL.ImmolationTable = {
      Destruction = {
        ImmolationDebuff = {},
      }
    };
    
  HL.GuardiansTable = {
      --{PetType,petID,dateEvent,UnitPetGUID,DE_Buffed}
      Pets = {
      },
      PetList={[55659]="Wild Imp",[99737]="Wild Imp",[98035]="Dreadstalker",[11859]="Doomguard",[89]="Infernal",[103673]="DarkGlare"}
    };
  
  
    --------------------------
    ----- Destruction --------
    --------------------------
    -- Immolate OnApply/OnRefresh Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        --- Record the Immolate
        if SpellID == 157736 then
          HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = 0;
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Immolate OnRemove Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Removes the Unit from Immolate Table
        if SpellID == 157736 then
          if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
               HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Immolate OnUnitDeath Listener
    HL:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);
        -- Removes the Unit from Immolate Table
        if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
          HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );
    -- Conflagrate Listener
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Add a stack to the table
        if SpellID == 17962 then
          if HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] then
               HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID] = HL.ImmolationTable.Destruction.ImmolationDebuff[DestGUID]+1;
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    
    
    --------------------------
    ----- Demonology ---------
    --------------------------
    --Guardians table
    HL:RegisterForSelfCombatEvent(
      function (...)
        dateEvent,_,_,_,_,_,_,UnitPetGUID=select(1,...)
       
        local t={} ; i=1
        for str in string.gmatch(UnitPetGUID, "([^-]+)") do
          t[i] = str
          i = i + 1
        end
        local PetType=HL.GuardiansTable.PetList[tonumber(t[6])]
        if PetType then
          table.insert(HL.GuardiansTable.Pets,{PetType,tonumber(t[6]),GetTime(),UnitPetGUID,false})
        end

      end
      , "SPELL_SUMMON"
    );
    
    --Buff all guardians
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);
        if SpellID == 193396 then
          for key, Value in pairs(HL.GuardiansTable.Pets) do
            HL.GuardiansTable.Pets[key][5]=true
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    
    --Implosion listener (kill all wild imps)
    HL:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);
        if SpellID == 196277 then
          for key, Value in pairs(HL.GuardiansTable.Pets) do
            if HL.GuardiansTable.Pets[key][1]=="Wild Imp" then
              HL.GuardiansTable.Pets[key]=nil
            end
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
