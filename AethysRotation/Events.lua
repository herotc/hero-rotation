--- Localize Vars
-- Addon
local addonName, AR = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- Lua


--- OnSpecChange
  local SpecTimer = 0;
  AC:RegisterForEvent(
    function (Event)
      -- Added a timer to prevent bug due to the double/triple event firing.
      if AC.GetTime() > SpecTimer then
        AR.PulseInit();
        SpecTimer = AC.GetTime() + 4;
      end
    end
    , "PLAYER_SPECIALIZATION_CHANGED"
  );