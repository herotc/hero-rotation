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
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    OffGCDasOffGCD = {
      WindShear = true,
      Racials = true
    },
  },
  Enhancement = {
    GCDasOffGCD = {
      -- Abilities
      FeralSpirit = false,
      Sundering = false,
      Ascendance = false,
    },
    EnableFS = true
  },
  Elemental = {
    UseSplashData = true,
    ChainInMain = "Never",
    GCDasOffGCD = {
      -- Abilities
      Stormkeeper = true,
      StormElemental = true,
      EarthElemental = true,
      FireElemental = true,
      Ascendance = true,
    },
    EnableEE = true,
    EnableFE = true,
    EnableSE = true
  },
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Shaman = CreateChildPanel(ARPanel, "Shaman");
local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement");
local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental");

-- Shared Shaman settings
CreateARPanelOptions(CP_Shaman, "APL.Shaman.Commons");
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.UsePotions", "Show potions", "Enable this if you want it to show you when to use potions");
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Shaman, "APL.Shaman.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Shaman, "APL.Shaman.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");

-- Enhancement settings
CreateARPanelOptions(CP_Enhancement, "APL.Shaman.Enhancement");
CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.EnableFS", "Show Feral Spirit in rotation", "Uncheck this if you don't want to see Feral Spirit in the rotation.");

-- Elemental settings
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Elemental.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_Elemental, "APL.Shaman.Elemental");
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Enhancement.EnableEE", "Show Earth Elemental in rotation", "Uncheck this if you don't want to see Earth Elemental in the rotation.");
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Enhancement.EnableFE", "Show Fire Elemental in rotation", "Uncheck this if you don't want to see Fire Elemental in the rotation.");
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Enhancement.EnableSE", "Show Storm Elemental in rotation", "Uncheck this if you don't want to see Storm Elemental in the rotation.");
CreatePanelOption("Dropdown", CP_Elemental, "APL.Shaman.Elemental.ChainInMain", {"Never", "Only with Splash Data", "Always"}, "Chain Lightning in the Main Icon", "When to show Chain Lightning in the main icon or as a suggestion");