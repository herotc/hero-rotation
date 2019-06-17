--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local HR = HeroRotation;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
local Hunter = HR.Commons.Hunter;
local RangeIndex = HL.Enum.ItemRange.Hostile.RangeIndex
local TriggerGCD = HL.Enum.TriggerGCD;
-- Lua
local pairs = pairs;
local select = select;
local wipe = wipe;
local GetTime = HL.GetTime;

-- MM Hunter GCD Management

Player.MMHunter = {
  GCDDisable = 0;
}
HL:RegisterForSelfCombatEvent(
  function (...)
    local CastSpell = Spell(select(12, ...))
    if CastSpell:CastTime() == 0 and TriggerGCD[CastSpell:ID()] then
      Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable + 1;
      --print("GCDDisable: " .. tostring(GCDDisable))
      C_Timer.After(0.1, 
      function ()
        Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable - 1;
        --print("GCDDisable: " .. tostring(GCDDisable))
      end
      );
    end
  end
  , "SPELL_CAST_SUCCESS"
);

HL:RegisterForSelfCombatEvent(
  function (...)
    local CastSpell = Spell(select(12, ...))
    if CastSpell:CastTime() > 0 and TriggerGCD[CastSpell:ID()] then
      Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable + 1;
      --print("GCDDisable: " .. tostring(GCDDisable))
      C_Timer.After(0.1, 
      function ()
        Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable - 1;
        --print("GCDDisable: " .. tostring(GCDDisable))
      end
      );
    end
  end
  , "SPELL_CAST_START"
);
