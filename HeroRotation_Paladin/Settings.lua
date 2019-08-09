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
      Rebuke = true,
      Racials = true,
    }
  },
  Protection = {
    -- CDs HP %
    EyeofTyrHP = 60,
    HandoftheProtectorHP = 80,
    LightoftheProtectorHP = 80,
    ShieldoftheRighteousHP = 60,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      AvengingWrath = true,
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
    -- SoloMode Settings
    -- SoloJusticarDP = 80, -- % HP threshold to use Justicar's Vengeance with Divine Purpose proc.
    -- SoloJusticar5HP = 60, -- % HP threshold to use Justicar's Vengeance with 5 Holy Power.
    ShieldofVengeance = true,
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
  }
};
-- GUI
HR.GUI.LoadSettingsRecursively(HR.GUISettings);
-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Paladin = CreateChildPanel(ARPanel, "Paladin");
local CP_Protection = CreateChildPanel(CP_Paladin, "Protection");
local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution");

-- Shared Paladin settings
CreateARPanelOptions(CP_Paladin, "APL.Paladin.Commons");
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Paladin, "APL.Paladin.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Paladin, "APL.Paladin.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");

-- Protection
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.EyeofTyrHP", {0, 100, 1}, "Eye of Tyr HP", "Set the Eye of Tyr HP threshold.");
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.HandoftheProtectorHP", {0, 100, 1}, "Hand of the Protector HP", "Set the Hand of the Protector HP threshold.");
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.LightoftheProtectorHP", {0, 100, 1}, "Light of the Protector HP", "Set the Light of the Protector HP threshold.");
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ShieldoftheRighteousHP", {0, 100, 1}, "Shield of the Righteous HP", "Set the Shield of the Righteous HP threshold.");
CreateARPanelOptions(CP_Protection, "APL.Paladin.Protection");
-- Retribution
-- CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticarDP", {0, 100, 1}, "Solo Justicar's Vengeance with Divine Purpose proc HP", "Set the solo Justicar's Vengeance with Divine Purpose proc HP threshold.");
-- CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticar5HP", {0, 100, 1}, "Solo Justicar's Vengeance with 5 Holy Power HP", "Set the solo Justicar's Vengeance with 5 Holy Power HP threshold.");
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.ShieldofVengeance", "Shield of Vengeance", "Enable this to show Shield of Vengeance in your DPS rotation.");
CreateARPanelOptions(CP_Retribution, "APL.Paladin.Retribution");