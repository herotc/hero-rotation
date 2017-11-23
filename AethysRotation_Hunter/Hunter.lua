--- Localize Vars
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


