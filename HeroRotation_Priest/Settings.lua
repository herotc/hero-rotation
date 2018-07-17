--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- HeroRotation
  local AR = HeroRotation;
  -- HeroLib
  local HL = HeroLib;
  -- File Locals
  local GUI = HL.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;
  local CreateARPanelOptions = AR.GUI.CreateARPanelOptions;

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
      MindbenderUsage = 0,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Shadowfiend = true,
        Mindbender = true,
        Shadowform = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        PowerInfusion = true,
        Dispersion = true,
        SurrenderToMadness = true,
        -- Racials
        Racials = true,
        -- Items
        PotionOfProlongedPower = true,
      }
    },
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Priest = CreateChildPanel(ARPanel, "Priest");
  local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow");
 
  CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", {0, 100, 1}, "Dispersion HP", "Set the Dispersion HP threshold.");
  CreateARPanelOptions(CP_Shadow, "APL.Priest.Shadow");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.UseSilence", "Use Silence for Sephuz", "Enable this if you want it to show you when to use Silence to proc Sephuz's Secret (only when equipped). ");
  -- CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.UseMindBomb", "Use Mind Bomb for Sephuz", "Enable this if you want it to show you when to use Mind Bomb to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.MindbenderUsage", {0, 30, 1}, "Shadowfiend/Mindbender usage Offset", "Number of vf stacks MB/SF will be delayed that you can push");

  -- CreateARPanelOption("OffGCDasOffGCD", CP_Shadow, "APL.Priest.Shadow.OffGCDasOffGCD.PotionOfProlongedPower", "Potion Of Prolonged Power");
