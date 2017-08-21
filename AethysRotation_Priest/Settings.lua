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
  AR.GUISettings.APL.Priest = {
    Commons = {
    },
    Shadow = {
      DispersionHP = 10,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Shadowfiend = {true, false},
        Mindbender = {true, false},
        Shadowform = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        PowerInfusion = {true, false},
        Dispersion = {true, false},
        -- Racials
        Racials = {true, false},
        -- Items
        PotionOfProlongedPower = {true, false},
      }
    },
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Priest = CreateChildPanel(ARPanel, "Priest");
  local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow");
 
  CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", {0, 100, 1}, "Dispersion HP", "Set the Dispersion HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Shadowfiend", "Shadowfiend");
  CreateARPanelOption("GCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Mindbender", "Mindbender");
  CreateARPanelOption("GCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Shadowform", "Shadowform");
  CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.PowerInfusion", "Power Infusion");
  CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.Dispersion", "Dispersion");
  CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.PotionOfProlongedPower", "Potion Of Prolonged Power");
