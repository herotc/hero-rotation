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
        Racials = {true, false}
      }
    },

    Arms = {
      OffGCDasOffGCD = {
        Avatar = {true, false},
        BattleCry = {true, false},
        FocusedRage = {true, false}
      },
      GCDasOffGCD = {
        Warbreaker = {true, false}
      },
      WarbreakerEnabled = true
    },

    Fury = {
      OffGCDasOffGCD = {
        Avatar = {true, false},
        BattleCry = {true, false}
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Warrior = CreateChildPanel(ARPanel, "Warrior");
  local CP_Arms = CreateChildPanel(CP_Warrior, "Arms");

  -- Shared Warrior settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.Pummel", "Pummel");
  CreateARPanelOption("OffGCDasOffGCD", CP_Warrior, "APL.Warrior.Commons.OffGCDasOffGCD.Racials", "Racials");

  -- Arms settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Arms, "APL.Warrior.Arms.OffGCDasOffGCD.Avatar", "Avatar");
  CreateARPanelOption("OffGCDasOffGCD", CP_Arms, "APL.Warrior.Arms.OffGCDasOffGCD.BattleCry", "Battle Cry");
  CreateARPanelOption("OffGCDasOffGCD", CP_Arms, "APL.Warrior.Arms.OffGCDasOffGCD.FocusedRage", "Focused Rage");
  CreatePanelOption("CheckButton", CP_Arms, "APL.Warrior.Arms.WarbreakerEnabled", "Enable Warbreaker", "Disable this if you want to omit Warbreaker from the rotation.");
  CreateARPanelOption("GCDasOffGCD", CP_Arms, "APL.Warrior.Arms.GCDasOffGCD.Warbreaker", "Warbreaker");

  -- Fury settings
