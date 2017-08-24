--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;
  -- AethysCore
  local AC = AethysCore;
  --File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.DeathKnight = {
    Commons = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities

      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        
      }
    },
   Frost = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
        -- Abilities
        PillarOfFrost = {true, false},
        HungeringRuneWeapon = {true, false},
        EmpowerRuneWeapon = {true, false},
        Obliteration = {true, false},
        
      }
    },
   Unholy = {
	  -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
		  
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
        -- Abilities
        BlightedRuneWeapon = {true, false},
		    ArmyOfDead = {true, false},
		    SummonGargoyle = {true, false},
		    DarkArbiter = {true, false},
       }
     }	 
	
  };
  
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  -- Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight");
  local CP_Unholy = CreateChildPanel(CP_Deathknight, "Unholy");
  local CP_Frost = CreateChildPanel(CP_Deathknight, "Frost");
  --Unholy Panels
  CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.ArmyOfDead", "Army as Off GCD", "Enable if you want to put Army shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.SummonGargoyle", "Gargoyle as Off GCD", "Enable if you want to put Gargoyle shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.DarkArbiter", "Dark Arbiter as Off GCD", "Enable if you want to put Dark Arbiter shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.BlightedRuneWeapon", "Blighted Rune Weapon as Off GCD", "Enable if you want to put Blighted Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent as Off GCD", "Enable if you want to put ArcaneTorrent shown as Off GCD (top icons) instead of Main.");
  --Frost Panels
  CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost", "Pillar as OffGCD", "Enable if you want to put Pillar of Frost shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Unholy.OffGCDasOffGCD.HungeringRuneWeapon", "Hungering Rune Weapon as Off GCD", "Enable if you want to put Hungering Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Unholy.OffGCDasOffGCD.EmpowerRuneWeapon", "Empower Rune Weapon as Off GCD", "Enable if you want to put Empower Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Unholy.OffGCDasOffGCD.Obliteration", "Obliteration as Off GCD", "Enable if you want to put Obliteration shown as Off GCD (top icons) instead of Main.");

