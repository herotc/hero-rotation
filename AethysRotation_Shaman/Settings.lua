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
      },
      OnUseTrinkets = false,
      ShowPoPP = false,
      HealingSurgeEnabled = false,
      HealingSurgeHPThreshold = 25
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
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.OnUseTrinkets", "Show on use trinkets", "Enable this if you want to show on use trinkets when they are ready.");
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.HealingSurgeEnabled", "Show Healing Surge", "Enable this if you want to show Healing Surge when you're low on health.");
  CreatePanelOption("Slider", CP_Shaman, "APL.Shaman.Commons.HealingSurgeHPThreshold", {0, 100, 1}, "Healing Surge HP threshold", "Healing Surge health threshold.");

  -- Elemental settings

  -- Enhancement settings
  CreateARPanelOption("GCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.GCDasOffGCD.FeralSpirit", "Feral Spirit");
  CreateARPanelOption("OffGCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.DoomWinds", "Doom Winds");
  CreateARPanelOption("OffGCDasOffGCD", CP_Enhancement, "APL.Shaman.Enhancement.OffGCDasOffGCD.Ascendance", "Ascendance");
