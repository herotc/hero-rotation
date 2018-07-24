--- Localize Vars
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
  
  -- Commons
  HR.Commons.Hunter = {};
  -- GUI Settings
  local Settings = HR.GUISettings.APL.Hunter.Commons;
  local Hunter = HR.Commons.Hunter;

  --- Commons Functions
  
  function Hunter.MultishotInMain()
	  if Settings.MultiShotInMain == "Always" then return true; end
	  if Settings.MultiShotInMain == "Never" then return false; end 
	
	  return Hunter.ValidateSplashCache()
  end


