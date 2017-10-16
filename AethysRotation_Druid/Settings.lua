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
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Druid = {
    Commons = {
      
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = {true, false}
        -- Abilities
        
      }
    },
    Balance = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
          MoonkinForm = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
          BlessingofElune = {true, false},
          BlessingofAnshe = {true, false},
          AstralCommunion = {true, false},
          IncarnationChosenOfElune = {true, false},
          CelestialAlignment = {true, false},
          WarriorofElune = {true, false},
      }
    },
    Feral = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
    Guardian = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
  };

    AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Druid = CreateChildPanel(ARPanel, "Druid");
  local CP_Balance = CreateChildPanel(CP_Druid, "Balance");
  -- local CP_Feral = CreateChildPanel(CP_Druid, "Feral");
  -- local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian");

  CreateARPanelOption("OffGCDasOffGCD", CP_Druid, "APL.Druid.Commons.OffGCDasOffGCD.Racials", "Racials");
