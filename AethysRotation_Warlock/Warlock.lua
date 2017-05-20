--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
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


--- ============================ CONTENT ============================
  
