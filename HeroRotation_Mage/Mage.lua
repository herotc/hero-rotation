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
  local AR = HeroRotation;
  -- Lua
  
  -- File Locals
  AR.Commons.Mage = {};
  local Settings = AR.GUISettings.APL.Mage.Commons;
  local Mage = AR.Commons.Mage;


--- ============================ CONTENT ============================
  
