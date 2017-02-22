--- Localize Vars
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCore_Cache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- APL Local Vars
  -- Spells
  if not Spell.Class then Spell.Class = {}; end
  Spell.Class.Spec = {
    -- Racials
    
    -- Abilities
    
    -- Talents
    
    -- Artifact
    
    -- Defensive
    
    -- Utility
    
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Class.Spec;
  -- Items
  if not Item.Class then Item.Class = {}; end
  Item.Class.Spec = {
    -- Legendaries
    
  };
  local I = Item.Class.Spec;
  -- Rotation Var
  
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Class.Commons,
    Spec = AR.GUISettings.APL.Class.Spec
  };


--- APL Action Lists (and Variables)
  


--- APL Main
  local function APL ()
    -- Unit Update
    
    -- Defensives
    
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      
      -- Opener
      
      return;
    end
    -- In Combat
    if AR.Commons.TargetIsValid() then
      
      return;
    end
  end

  AR.SetAPL(000, APL);


--- Last Update: 12/31/2999

-- APL goes here
