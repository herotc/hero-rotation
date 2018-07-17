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
  HR.Commons.Class = {};
  local Settings = HR.GUISettings.APL.Class.Commons;
  local Class = HR.Commons.Class;


--- ============================ CONTENT ============================
  
