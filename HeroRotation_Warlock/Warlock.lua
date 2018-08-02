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
  -- HeroRotation
  local HR = HeroRotation;
  -- Lua
  
  -- File Locals
  HR.Commons.Warlock = {};
  local Settings = HR.GUISettings.APL.Warlock.Commons;
  local Warlock = HR.Commons.Warlock;

  local GrimoireOfSupremacy 	= Spell(152107);
--- ============================ CONTENT ============================
  function Warlock.PetReminder()
    if GrimoireOfSupremacy:IsAvailable() then
      return Settings.PetReminder == "Always"
    else
      return Settings.PetReminder == "Always" or Settings.PetReminder == "Not with Grimoire of Supremacy"
    end
  end
