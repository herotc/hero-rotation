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
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Class = AR.Commons.Class;

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


--- ======= ACTION LISTS =======
-- Put here acti lists only if they are called multiple times in the APL
-- If it's only put one time, it's doing a closure call for nothing.
  


--- ======= MAIN =======
  local function APL ()
    -- Local Update
    

    -- Unit Update
    
    Everyone.AoEToggleEnemiesUpdate();

    -- Defensives
    

    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Flask
      -- Food
      -- Rune
      -- PrePot w/ Bossmod Countdown
      -- Opener
      if Everyone.TargetIsValid() then
        
      end
      return;
    end

    -- In Combat
    if Everyone.TargetIsValid() then
      
      return;
    end
  end

  AR.SetAPL(000, APL);


--- ======= SIMC =======
--- Last Update: 12/31/2999

-- APL goes here
