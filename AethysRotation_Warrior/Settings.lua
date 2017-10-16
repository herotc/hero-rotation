--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;
  -- AethysCore
  local AC = AethysCore;
  -- File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;


--- ============================ CONTENT ============================
  -- Default settings
  AR.GUISettings.APL.Warrior = {
    Commons = {
      OffGCDasOffGCD = {
        Pummel = {true, false},
        Racials = {true, false},
        Avatar = {true, false},
        BattleCry = {true, false},
      }
    },

    Arms = {
      WarbreakerEnabled = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Warbreaker = {false, false},
      },
      OffGCDasOffGCD = {
        -- Abilities
        FocusedRage = {true, false},
        -- Items
      },
    },

    Fury = {
      ShowPoOW = false,
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        DragonRoar = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Bloodbath = {true, false},
        -- Items
        PotionoftheOldWar = {true, false},
        PotionOfProlongedPower = {true, false},
        UmbralMoonglaives = {true, false},
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Warrior = CreateChildPanel(ARPanel, "Warrior");
  local CP_Arms = CreateChildPanel(CP_Warrior, "Arms");
  local CP_Fury = CreateChildPanel(CP_Warrior, "Fury");

  -- Shared Warrior settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.Pummel", "Pummel");
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.Avatar", "Avatar");
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.BattleCry", "Battle Cry");

  -- Arms settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Arms, "APL.Warrior.Arms.OffGCDasOffGCD.FocusedRage", "Focused Rage");
  CreatePanelOption("CheckButton", CP_Arms, "APL.Warrior.Arms.WarbreakerEnabled", "Enable Warbreaker", "Disable this if you want to omit Warbreaker from the rotation.");
  CreateARPanelOption("GCDasOffGCD", CP_Arms, "APL.Warrior.Arms.GCDasOffGCD.Warbreaker", "Warbreaker");

  -- Fury settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Fury, "APL.Warrior.Fury.OffGCDasOffGCD.Bloodbath", "Bloodbath");
  CreateARPanelOption("OffGCDasOffGCD", CP_Fury, "APL.Warrior.Fury.OffGCDasOffGCD.UmbralMoonglaives", "Umbral Moonglaives");
  CreateARPanelOption("GCDasOffGCD", CP_Fury, "APL.Warrior.Fury.GCDasOffGCD.DragonRoar", "Dragon Roar");
  CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoOW", "Show Potion of the Old War", "Enable this if you want it to show you when to use Potion of the Old War.");
  CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
