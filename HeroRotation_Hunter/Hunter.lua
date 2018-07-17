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
  local AR = HeroRotation;
  -- Lua
  
  -- Commons
  AR.Commons.Hunter = {};
  -- GUI Settings
  local Settings = AR.GUISettings.APL.Hunter.Commons;
  local Hunter = AR.Commons.Hunter;

  --- Commons Functions
  
  function Hunter.MultishotInMain()
	  if Settings.MultiShotInMain == "Always" then return true; end
	  if Settings.MultiShotInMain == "Never" then return false; end 
	
	  return Hunter.ValidateSplashCache()
  end


