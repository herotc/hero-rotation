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
  AR.GUISettings.APL.Shaman = {
    Enhancement = {
	  -- Display GCD as OffGcd, ForceReturn
	  GCDasOffGCD = {
	    -- Abilities
	    FeralSpirit = {true, false}
	  },

	  -- Display OffGCD as OffGCD, ForceReturn
	  OffGCDasOffGCD = {
	    -- Abilities
	    DoomWinds = {true, false},
	    Ascendance = {true, false},

	    -- Interrupt
	    WindShear = {true, false},

	    -- Racial
	    Racials = {true, false}
      }
	},
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Shaman = CreateChildPanel(ARPanel, "Shaman");
  local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement");

  CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.GCDasOffGCD.FeralSpirit", "Feral Spirit as Off GCD", "Enable if you want Feral Spirit to be shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.DoomWinds", "Doom Winds as Off GCD", "Enable if you want Doom Winds to be shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.Ascendance", "Ascendance as Off GCD", "Enable if you want Ascendance to be shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.WindShear", "Wind Shear as Off GCD", "Enable if you want Wind Shear to be shown as Off GCD (top icons) instead of Main.");
  CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.Racials", "Racials as Off GCD", "Enable if you want Racials (Arcane Torrent, Berserking, ...) to be shown as Off GCD (top icons) instead of Main.");
