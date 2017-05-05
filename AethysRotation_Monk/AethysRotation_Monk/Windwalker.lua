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
  


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Monk = AR.Commons.Monk;
  -- Spells
  if not Spell.Monk then Spell.Monk = {}; end
  Spell.Monk.Windwalker = {
  
    -- Racials
	
    ArcaneTorrent                 = Spell(25046),
    Berserking                    = Spell(26297),
    BloodFury                     = Spell(20572),
    GiftoftheNaaru                = Spell(59547),
    Shadowmeld                    = Spell(58984),  
	QuakingPalm					  = Spell(107079),
	
    -- Abilities
    
	TigerPalm					  = Spell(100780),
	RisingSunKick				  = Spell(107428),
	FistsOfFury					  = Spell(113656),
	SpinningCraneKick			  = Spell(101546),
	StormEarthAndFire			  = Spell(137639),
	FlyingSerpentKick			  = Spell(101545),
	FlyingSerpentKick2			  = Spell(115057),
	TouchOfDeath				  = Spell(115080),
	CracklingJadeLightning		  = Spell(117952),
	BlackoutKick				  = Spell(100784),
	
    -- Talents
    
	ChiWave						  = Spell(115098),
	InvokeXuentheWhiteTiger		  = Spell(123904),
	RushingJadeWind				  = Spell(116847),
	Serenity					  = Spell(152173),
	WhirlingDragonPunch			  = Spell(152175),
	ChiBurst					  = Spell(123986),
	
	
    -- Artifact
    
	StrikeOfTheWindlord			  = Spell(205320),
	
    -- Defensive
    
	TouchOfKarma				  = Spell(122470),
	DiffuseMagic				  = Spell(122783),  --Talent
	DampenHarm					  = Spell(122278),  --Talent
	
    -- Utility
    
	Detox						  = Spell(218164),
	Effuse						  = Spell(116694),
	EnergizingElixir			  = Spell(115288), --Talent
	TigersLust					  = Spell(116841), --Talent
	LegSweep					  = Spell(119381), --Talent
	Disable						  = Spell(116095),
	HealingElixir				  = Spell(122281), --Talent
	Paralysis					  = Spell(115078),
	
    -- Legendaries
    
    -- Misc
    
    -- Macros
    
  };
  local S = Spell.Monk.Windwalker;
  -- Items
  if not Item.Monk then Item.onk = {}; end
  Item.Monk.Windwalker = {
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
  


--- ======= MAIN =======
  local function APL ()
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
