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
      }
    },
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Priest = CreateChildPanel(ARPanel, "Priest");
  local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow");

  CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", {0, 100, 1}, "Dispersion HP", "Set the Dispersion HP threshold.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Shadowfiend", "Shadowfiend as Off GCD", "Enable if you want to put Shadowfiend shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Mindbender", "Mindbender as Off GCD", "Enable if you want to put Mindbender shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.GCDasOffGCD.Shadowform", "Shadowform as Off GCD", "Enable if you want to put Shadowform shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.PowerInfusion", "Power Infusion as Off GCD", "Enable if you want to put Power Infusion shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.Dispersion", "Dispersion as Off GCD", "Enable if you want to put Dispersion shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.Racials", "Racials as Off GCD", "Enable if you want to put Racials (Arcane Torrent, Berserking, ...) shown as Off GCD (top icons) instead of Main.");
