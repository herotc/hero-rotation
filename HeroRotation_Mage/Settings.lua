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
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Mage = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    UseTimeWarp = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      TimeWarp = true,
      Counterspell = true,
    }
  },
  Frost = {
    UseSplashData = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      RuneofPower = true,
      IcyVeins = true,
      MirrorImage = true,
      FrozenOrb = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      IceFloes = true,
    }
  },
  Fire = {
    UseSplashData = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      RuneofPower = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      Combustion = true,
    }
  },
  Arcane = {
    UseSplashData = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      RuneofPower = true,
      ArcanePower = true,
      ChargedUp = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      PresenceofMind = true,
    }
  }
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Mage = CreateChildPanel(ARPanel, "Mage");
local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane");
local CP_Fire = CreateChildPanel(CP_Mage, "Fire");
local CP_Frost = CreateChildPanel(CP_Mage, "Frost");

-- Controls
-- Mage
CreateARPanelOptions(CP_Mage, "APL.Mage.Commons");
CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTimeWarp", "Use Time Warp", "Enable this if you want the addon to show you when to use Time Warp.");
CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Mage, "APL.Mage.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Mage, "APL.Mage.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");
-- Arcane
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane");
-- Fire
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_Fire, "APL.Mage.Fire");
-- Frost
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_Frost, "APL.Mage.Frost");