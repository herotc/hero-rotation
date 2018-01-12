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
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;

--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.DeathKnight = {
    Commons = {
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        
      },
      UseTrinkets = false,
      UsePotions  = false
    },
   Frost = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        HornOfWinter = {true, false},
        Obliteration = {true, false},
        SindragosasFury = {true, false},
        BreathofSindragosa = {true, false}
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
        
      }
    },
    Unholy = {
    -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        ArmyOfDead = {true, false},
        SummonGargoyle = {true, false},
        DarkArbiter = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
        -- Abilities
        BlightedRuneWeapon = {true, false},
       }
     },

     Blood = {
     --Choose the rotation to follow (Default: Icy Veins)
      RotationToFollow = "Icy Veins",
     -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        BloodDrinker = {true, false},
	      BoneStorm = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        DancingRuneWeapon = {true, false},
        ArcaneTorrent = {true, false},
       }
   },  
  
  };
  
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  -- Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight");
  local CP_Unholy = CreateChildPanel(CP_Deathknight, "Unholy");
  local CP_Frost = CreateChildPanel(CP_Deathknight, "Frost");
  local CP_Blood = CreateChildPanel(CP_Deathknight, "Blood");
  
  --DeathKnight Panels
  CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UseTrinkets", "Show on use trinkets", "Fel Oiled Machine Supported.");
  CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UsePotions", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  --Unholy Panels
  CreateARPanelOption("GCDasOffGCD", CP_Unholy, "APL.DeathKnight.Unholy.GCDasOffGCD.ArmyOfDead", "Army", "Enable if you want to put Army shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Unholy, "APL.DeathKnight.Unholy.GCDasOffGCD.SummonGargoyle", "Gargoyle", "Enable if you want to put Gargoyle shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Unholy, "APL.DeathKnight.Unholy.GCDasOffGCD.DarkArbiter", "Dark Arbiter", "Enable if you want to put Dark Arbiter shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.BlightedRuneWeapon", "Blighted Rune Weapon", "Enable if you want to put Blighted Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Unholy, "APL.DeathKnight.Unholy.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent", "Enable if you want to put ArcaneTorrent shown as Off GCD (top icons) instead of Main.");
  --Frost Panels
  CreateARPanelOption("GCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.GCDasOffGCD.BreathofSindragosa", "Breath of Sindragosa", "Enable if you want to put BoS shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.GCDasOffGCD.Obliteration", "Obliteration", "Enable if you want to put Obliteration shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.GCDasOffGCD.SindragosasFury", "Sindragosa's Fury", "Enable if you want to put Sindragosa's Fury shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.GCDasOffGCD.HornOfWinter", "Horn of Winter", "Enable if you want to put Horn of Winter shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.OffGCDasOffGCD.PillarOfFrost", "Pillar", "Enable if you want to put Pillar of Frost shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.OffGCDasOffGCD.HungeringRuneWeapon", "Hungering Rune Weapon", "Enable if you want to put Hungering Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.OffGCDasOffGCD.EmpowerRuneWeapon", "Empower Rune Weapon", "Enable if you want to put Empower Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.DeathKnight.Frost.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent", "Enable if you want to put ArcaneTorrent shown as Off GCD (top icons) instead of Main.");
  --Blood Panels
  CreatePanelOption("Dropdown", CP_Blood, "APL.DeathKnight.Blood.RotationToFollow", {"Icy Veins","SimC"}, "Rotation:", "Define the rotation to follow.(Simc module needs development)");
  CreateARPanelOption("GCDasOffGCD", CP_Blood, "APL.DeathKnight.Blood.GCDasOffGCD.BloodDrinker", "Blooddrinker", "Enable if you want to put Blooddrinker shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("GCDasOffGCD", CP_Blood, "APL.DeathKnight.Blood.GCDasOffGCD.BoneStorm", "Bonestorm", "Enable if you want to put Bonestorm shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Blood, "APL.DeathKnight.Blood.OffGCDasOffGCD.DancingRuneWeapon", "Dancing Rune Weapon", "Enable if you want to put Dancing Rune Weapon shown as Off GCD (top icons) instead of Main.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Blood, "APL.DeathKnight.Blood.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent", "Enable if you want to put Arcane Torrent shown as Off GCD (top icons) instead of Main.");
