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
      ShowPoPP = false,
      UseSilence = false,
      UseMindBomb = false,
      ForceMindbender = false,
      MindbenderUsage = 25,
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
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.UseSilence", "Use Silence for Sephuz", "Enable this if you want it to show you when to use Silence to proc Sephuz's Secret (only when equipped). ");
  -- CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.UseMindBomb", "Use Mind Bomb for Sephuz", "Enable this if you want it to show you when to use Mind Bomb to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.ForceMindbender", "Force Shadowfiend/Mindbender usage", "Enable this if you want it to manually set when to use Shadowfiend/Mindbender.");
  CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.MindbenderUsage", {0, 60, 1}, "Shadowfiend/Mindbender prefered usage", "Only if Force enabled.\nSet at how much vf stacks mindbender is used.");

  -- CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.PotionOfProlongedPower", "Potion Of Prolonged Power");
