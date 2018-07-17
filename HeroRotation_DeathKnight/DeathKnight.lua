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
  HR.Commons.DeathKnight = {};
  local Settings = HR.GUISettings.APL.DeathKnight.Commons;
  local DeathKnight = HR.Commons.DeathKnight;


--- ============================ CONTENT ============================
  
