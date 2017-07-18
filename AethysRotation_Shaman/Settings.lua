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
  AR.GUISettings.APL.Shaman = {
    Commons = {
      OffGCDasOffGCD = {
	    WindShear = {true, false},
	    Racials = {true, false}
      }
    },

    Elemental = {
    },

    Enhancement = {
      OffGCDasOffGCD = {
	    DoomWinds = {true, false},
	    Ascendance = {true, false}
      },
	  GCDasOffGCD = {
	    FeralSpirit = {false, true}
	  }
	}
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Shaman = CreateChildPanel(ARPanel, "Shaman");
  local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental");
  local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement");

  -- Shared Shaman settings
  CreateARPanelOption("OffGCDasOffGCD", CP_Shaman, "APL.Shaman.Commons.OffGCDasOffGCD.WindShear", "Wind Shear");
  CreateARPanelOption("OffGCDasOffGCD", CP_Shaman, "APL.Shaman.Commons.OffGCDasOffGCD.Racials", "Racials");

  -- Elemental settings

  -- Enhancement settings
  CreateARPanelOption("GCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.GCDasOffGCD.FeralSpirit", "Feral Spirit");
  CreateARPanelOption("OffGCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.DoomWinds", "Doom Winds");
  CreateARPanelOption("OffGCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.Ascendance", "Ascendance");
