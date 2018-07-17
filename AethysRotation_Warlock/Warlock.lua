--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroLib
  local AC = HeroLib;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  
  -- File Locals
  AR.Commons.Warlock = {};
  local Settings = AR.GUISettings.APL.Warlock.Commons;
  local Warlock = AR.Commons.Warlock;

  local GrimoireOfSupremacy 	= Spell(152107);
--- ============================ CONTENT ============================
  function Warlock.PetReminder()
    if GrimoireOfSupremacy:IsAvailable() then
      return Settings.PetReminder == "Always"
    else
      return Settings.PetReminder == "Always" or Settings.PetReminder == "Not with Grimoire of Supremacy"
    end
  end
