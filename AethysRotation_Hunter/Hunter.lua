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
  -- Exhilaration
  function Hunter.Exhilaration (Exhilaration)
    if Exhilaration:IsCastable() and Player:HealthPercentage() <= Settings.ExhilarationHP then
      if AR.Cast(Exhilaration, Settings.GCDasOffGCD.Exhilaration) then return "Cast Exhilaration (Defensives)"; end
    end
    return false;
  end
