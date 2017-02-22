--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCore_Cache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- Lua
  local pairs = pairs;
  local select = select;


--- ============== NON-COMBATLOG ==============


--- ============== COMBATLOG ==============

  --- Combat Log Arguments


    ------- Base -------
      --    1      2      3        4        5        6          7        8      9      10        11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags


    ------- Prefixes -------

      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --   12      13      14
      -- SpellID, SpellName, SpellSchool


    ------- Suffixes -------

      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --    15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --   15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --   15      16
      -- AuraType, Charges

      --- _INTACRUPT
      --    15        16          17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --  15      16       17      18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --  15     16     17     18     19      20      21      22      23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --   15      16        17
      -- MissType, IsOffHand, AmountMissed


    ------- Special -------

      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments

  -- Arguments Variables
  local DestGUID, SpellID;

  -- TODO: Register/Unregister Events on SpecChange
  AC.BleedTable = {
    Assassination = {
      Garrote = {},
      Rupture = {}
    },
    Subtlety = {
      Nightblade = {},
      FinalityNightblade = false,
      FinalityNightbladeTime = 0
    }
  };
  local BleedGUID;
  --- Exsanguinated Handler
    -- Exsanguinate Expression
    local BleedDuration, BleedExpires;
    function AC.Exsanguinated (Unit, SpellName)
      BleedGUID = Unit:GUID();
      if BleedGUID then
        if SpellName == "Garrote" then
          if AC.BleedTable.Assassination.Garrote[BleedGUID] then
              return AC.BleedTable.Assassination.Garrote[BleedGUID][3];
          end
        elseif SpellName == "Rupture" then
          if AC.BleedTable.Assassination.Rupture[BleedGUID] then
              return AC.BleedTable.Assassination.Rupture[BleedGUID][3];
          end
        end
      end
      return false;
    end
    -- Exsanguinate OnCast Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Exsanguinate
        if SpellID == 200806 then
          for Key, _ in pairs(AC.BleedTable.Assassination) do
            for Key2, _ in pairs(AC.BleedTable.Assassination[Key]) do
              if Key2 == DestGUID then
                  -- Change the Exsanguinate info to true
                  AC.BleedTable.Assassination[Key][Key2][3] = true;
              end
            end
          end
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    -- Bleed infos
    local function GetBleedInfos (GUID, Spell)
      -- Core API is not used since we don't want cached informations
      return select(6, UnitAura(GUID, ({GetSpellInfo(Spell)})[1], nil, "HARMFUL|PLAYER"));
    end
    -- Bleed OnApply/OnRefresh Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        --- Record the Bleed Target and its Infos
        -- Garrote
        if SpellID == 703 then
          BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
          AC.BleedTable.Assassination.Garrote[DestGUID] = {BleedDuration, BleedExpires, false};
        -- Rupture
        elseif SpellID == 1943 then
          BleedDuration, BleedExpires = GetBleedInfos(DestGUID, SpellID);
          AC.BleedTable.Assassination.Rupture[DestGUID] = {BleedDuration, BleedExpires, false};
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Bleed OnRemove Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        -- Removes the Unit from Garrote Table
        if SpellID == 703 then
          if AC.BleedTable.Assassination.Garrote[DestGUID] then
              AC.BleedTable.Assassination.Garrote[DestGUID] = nil;
          end
        -- Removes the Unit from Rupture Table
        elseif SpellID == 1943 then
          if AC.BleedTable.Assassination.Rupture[DestGUID] then
              AC.BleedTable.Assassination.Rupture[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Bleed OnUnitDeath Listener
    AC:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);

        -- Removes the Unit from Garrote Table
        if AC.BleedTable.Assassination.Garrote[DestGUID] then
          AC.BleedTable.Assassination.Garrote[DestGUID] = nil;
        end
        -- Removes the Unit from Rupture Table
        if AC.BleedTable.Assassination.Rupture[DestGUID] then
          AC.BleedTable.Assassination.Rupture[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );

  --- Finality Nightblade Handler
    function AC.Finality (Unit)
      BleedGUID = Unit:GUID();
      if BleedGUID then
        if AC.BleedTable.Subtlety.Nightblade[BleedGUID] then
          return AC.BleedTable.Subtlety.Nightblade[BleedGUID];
        end
      end
      return false;
    end
    -- Nighblade OnCast Listener
    -- Check the Finality buff on cast (because it disappears after) but don't record it until application (because it can miss)
    AC:RegisterForSelfCombatEvent(
      function (...)
        SpellID = select(12, ...);

        -- Nightblade
        if SpellID == 195452 then
          AC.BleedTable.Subtlety.FinalityNightblade = Player:Buff(Spell.Rogue.Subtlety.FinalityNightblade) and true or false;
          AC.BleedTable.Subtlety.FinalityNightbladeTime = AC.GetTime() + 0.3;
        end
      end
      , "SPELL_CAST_SUCCESS"
    );
    -- Nightblade OnApply/OnRefresh Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        if SpellID == 195452 then
          AC.BleedTable.Subtlety.Nightblade[DestGUID] = AC.GetTime() < AC.BleedTable.Subtlety.FinalityNightbladeTime and AC.BleedTable.Subtlety.FinalityNightblade;
        end
      end
      , "SPELL_AURA_APPLIED"
      , "SPELL_AURA_REFRESH"
    );
    -- Nightblade OnRemove Listener
    AC:RegisterForSelfCombatEvent(
      function (...)
        DestGUID, _, _, _, SpellID = select(8, ...);

        if SpellID == 195452 then
          if AC.BleedTable.Subtlety.Nightblade[DestGUID] then
            AC.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
          end
        end
      end
      , "SPELL_AURA_REMOVED"
    );
    -- Nightblade OnUnitDeath Listener
    AC:RegisterForCombatEvent(
      function (...)
        DestGUID = select(8, ...);

        if AC.BleedTable.Subtlety.Nightblade[DestGUID] then
          AC.BleedTable.Subtlety.Nightblade[DestGUID] = nil;
        end
      end
      , "UNIT_DIED"
      , "UNIT_DESTROYED"
    );

  --- Just Stealthed
    -- TODO: Add Assassination Spells when it'll be done
    -- TODO: Make a for loop with a table, more easy to maintain
    AC:RegisterForSelfCombatEvent(
      function (...)
          SpellID = select(12, ...);

          -- Shadow Dance
          if SpellID == Spell.Rogue.Subtlety.ShadowDance:ID() then
            Spell.Rogue.Subtlety.ShadowDance.LastCastTime = AC.GetTime();
          -- Shadowmeld
          elseif SpellID == Spell.Rogue.Subtlety.Shadowmeld:ID() then
            Spell.Rogue.Outlaw.Shadowmeld.LastCastTime = AC.GetTime();
            Spell.Rogue.Subtlety.Shadowmeld.LastCastTime = AC.GetTime();
          -- Vanish
          elseif SpellID == Spell.Rogue.Subtlety.Vanish:ID() then
            Spell.Rogue.Outlaw.Vanish.LastCastTime = AC.GetTime();
            Spell.Rogue.Subtlety.Vanish.LastCastTime = AC.GetTime();
          end
      end
      , "SPELL_CAST_SUCCESS"
    );
