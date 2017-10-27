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
  
  AC.SpellToTrack = {
      [8092]="MindBlast",
      [15407]="MindFlay",
      [205448]="VoidBolt"
    };
  
  
    --------------------------
    ----- Shadow --------
    --------------------------
    -- Tracker
    -- AC:RegisterForSelfCombatEvent(
      -- function (...)
        -- DestGUID, _, _, _, SpellID = select(8, ...);

        -- if AC.SpellToTrack[SpellID] then
          -- print("SPELL_CAST_SUCCESS:",AC.SpellToTrack[SpellID])
        -- end
      -- end
      -- , "SPELL_CAST_SUCCESS"
    -- );
    -- AC:RegisterForSelfCombatEvent(
      -- function (...)
        -- DestGUID, _, _, _, SpellID = select(8, ...);

        -- if AC.SpellToTrack[SpellID] then
          -- print("SPELL_CAST_START:",AC.SpellToTrack[SpellID])
        -- end
      -- end
      -- , "SPELL_CAST_START"
    -- );
    -- AC:RegisterForSelfCombatEvent(
      -- function (...)
        -- DestGUID, _, _, _, SpellID = select(8, ...);

        -- if AC.SpellToTrack[SpellID] then
          -- print("SPELL_AURA_APPLIED:",AC.SpellToTrack[SpellID])
        -- end
      -- end
      -- , "SPELL_AURA_APPLIED"
    -- );
    -- AC:RegisterForSelfCombatEvent(
      -- function (...)
        -- DestGUID, _, _, _, SpellID = select(8, ...);

        -- if AC.SpellToTrack[SpellID] then
          -- print("SPELL_AURA_APPLIED:",AC.SpellToTrack[SpellID])
        -- end
      -- end
      -- , "SPELL_AURA_REMOVED"
    -- );
    
    
