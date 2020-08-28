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
HR.GUISettings.APL.Paladin = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    OffGCDasOffGCD = {
      Racials = true,
      Rebuke = true,
    }
  },
  Protection = {
    -- CDs HP %
    WordofGloryHP = 80,
    ShieldoftheRighteousHP = 60,
    UseSotROffensively = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      AvengingWrath = true,
      HammerofWrath = true,
      WordofGlory = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      ArcaneTorrent = true,
      -- Abilities
      ShieldoftheRighteous = true,
    }
  },
  Retribution = {
    ShieldofVengeance = true,
    UseFABST = false,
    AllowDelayedAW = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      AvengingWrath = true,
      Crusade = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
    }
  },
  Holy = {
    GCDasOffGCD = {
      -- Abilities
      AvengingWrath = true,
      HolyAvenger = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
    }
  }
};
-- GUI
HR.GUI.LoadSettingsRecursively(HR.GUISettings);
-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Paladin = CreateChildPanel(ARPanel, "Paladin");
local CP_Protection = CreateChildPanel(CP_Paladin, "Protection");
local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution");
local CP_Holy = CreateChildPanel(CP_Paladin, "Holy");

-- Shared Paladin settings
CreateARPanelOptions(CP_Paladin, "APL.Paladin.Commons");
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");

-- Protection
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.WordofGloryHP", {0, 100, 1}, "Word of Glory HP", "Set the Word of Glory HP threshold.");
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ShieldoftheRighteousHP", {0, 100, 1}, "Shield of the Righteous HP", "Set the Shield of the Righteous HP threshold.");
CreatePanelOption("CheckButton", CP_Protection, "APL.Paladin.Protection.UseSotROffensively", "Use SotR Offensively", "Enable this setting if you want the addon to suggest Shield of the Righteous as an offensive ability.");
CreateARPanelOptions(CP_Protection, "APL.Paladin.Protection");

-- Retribution
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.ShieldofVengeance", "Shield of Vengeance", "Enable this to show Shield of Vengeance in your DPS rotation.");
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.UseFABST", "Use Focused Azerite Beam ST", "Suggest Focused Azerite Beam usage during single target combat.");
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.AllowDelayedAW", "Allow Delayed Avenging Wrath", "Enable this to allow Templar's Verdict to be suggested while delaying use of Avenging Wrath/Crusade/Execution Sentence.");
CreateARPanelOptions(CP_Retribution, "APL.Paladin.Retribution");

-- Holy
--CreateARPanelOptions("CheckButton", CP_Holy, "APL.Paladin.Holy.DemoButtonHere", "TODO: DEVS - Experimental", "Devs should enable this.");
CreateARPanelOptions(CP_Holy, "APL.Paladin.Holy");