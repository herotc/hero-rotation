--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroRotation
  local HR = HeroRotation;
  -- HeroLib
  local HL = HeroLib;
  -- File Locals
  local GUI = HL.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = HR.GUI.CreateARPanelOption;
  local CreateARPanelOptions = HR.GUI.CreateARPanelOptions;

--- ============================ CONTENT ============================
  -- Default settings
  HR.GUISettings.APL.Shaman = {
    Commons = {
      OffGCDasOffGCD = {
	    WindShear = true,
	    Racials = true,
      },
      OnUseTrinkets = false,

      ShowBPoA = false,
      ShowBSAR = false,
      ConsumableMinHPThreshHold = 2500,

      ShowHSHP = false,
      HealingSurgeEnabled = false,
      HealingHPThreshold = 25
    },

    -- Elemental = {
    --   OffGCDasOffGCD = {
    --   },
	--   GCDasOffGCD = {
	--   }
    -- },

    -- Enhancement = {
    --   OffGCDasOffGCD = {
    --   },
	--   GCDasOffGCD = {
	--   }
	-- },
  };

  HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Shaman = CreateChildPanel(ARPanel, "Shaman");
  -- local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental");
  -- local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement");

  -- Shared Shaman settings
  CreateARPanelOptions(CP_Shaman, "APL.Shaman.Commons");
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.OnUseTrinkets", "Show on use trinkets", "Enable this if you want to show supported on use trinkets when they are ready.");

  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.ShowBPoA", "Show BPoA", "Enable this if you want it to show you when to use Battle Potion of Agility.");
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.ShowBSAR", "Show BSAR", "Enable this if you want it to show you when to use Battle-Scarred Augment Rune.");
  CreatePanelOption("Slider", CP_Shaman, "APL.Shaman.Commons.ConsumableMinHPThreshHold", {0, 5000, 25}, "Consumable hp threshold (k)", "Minimum amount of health (times x1000) the target needs to have to show consumables.");

  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.ShowHSHP", "Show healthstones & health potions", "Enable this if you want to show Healthstones and health potions when you're low on health.");
  CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.HealingSurgeEnabled", "Show healing surge", "Enable this if you want to show Healing Surge when you're low on health.");
  CreatePanelOption("Slider", CP_Shaman, "APL.Shaman.Commons.HealingHPThreshold", {0, 100, 1}, "Healing surge and/or health pot hp threshold", "Healing Surge and/or health pot threshold.");

  -- Elemental settings
  -- CreateARPanelOptions(CP_Elemental, "APL.Shaman.Elemental");

  -- Enhancement settings
  -- CreateARPanelOptions(CP_Enhancement, "APL.Shaman.Enhancement");
