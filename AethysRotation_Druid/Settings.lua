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
      BarkSkinHP = 10,
      ShowPoPP = false,
      Sephuz = {
        SolarBeam = false,
        Typhoon = false
        MightyBash = false,
        MassEntanglement = false,
        EntanglingRoots = false,
      }
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
 
  -- CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkSkinHP", {0, 100, 1}, "BarkSkin HP", "Set the BarkSkin HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_Balance, "APL.Druid.Balance.GCDasOffGCD.MoonkinForm", "Moonkin Form");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.BlessingofElune", "Blessing Of Elune");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.BlessingofAnshe", "Blessing Of Anshe");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.AstralCommunion", "Astral Communion");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.IncarnationChosenOfElune", "Incarnation Chosen Of Elune");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.CelestialAlignment", "Celestial Alignment");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.WarriorofElune", "Warrior Of Elune");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.SolarBeam", "Sephuz: Show Solar Beam", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.EntanglingRoots", "Sephuz: Show Entangling Roots", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MightyBash", "Sephuz: Show Mighty Bash", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MassEntanglement", "Sephuz: Show Mass Entanglement", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.Typhoon", "Sephuz: Show Typhoon", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");

