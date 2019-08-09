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
HR.GUISettings.APL.Warrior = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    OffGCDasOffGCD = {
      Pummel = true,
      Racials = true,
      Avatar = true,
      BattleCry = true,
    }
  },
  Arms = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Warbreaker = false,
      Bladestorm = false,
      Ravager = false,
      DeadlyCalm = false,
      HeroicLeap = false,
      Charge = false,
      Avatar = true,
    },
    OffGCDasOffGCD = {
      -- Abilities
      DeadlyCalm = true,
      -- Items
    },
  },
  Fury = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Bladestorm = false,
      DragonRoar = false,
      Recklessness = false,
      Siegebreaker = false,
      HeroicLeap = false,
      Charge = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
    }
  },
  Protection = {
    UseLastStandToFillShieldBlockDownTime = true,
    UseShieldBlockDefensively = true,
    UseRageDefensively = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      Avatar            = true,
      DemoralizingShout = true,
      LastStand         = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      IgnorePain        = true,
      ShieldBlock       = true
    }
  },
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior");
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms");
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury");
local CP_Protection = CreateChildPanel(CP_Warrior, "Protection");

-- Shared Warrior settings
CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons");
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");

-- Arms settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms");

-- Fury settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury");
CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoOW", "Show Potion of the Old War", "Enable this if you want it to show you when to use Potion of the Old War.");
CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");

-- Protection settings
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection");
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseLastStandToFillShieldBlockDownTime", "Use Last Stand to fill Shield Block down time", "Enable this if you want to fill Shield Block down time with Last Stand.");
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseShieldBlockDefensively", "Use Shield Block purely defensively", "Enable this if you only want to use Shield Block in a defensive manner.");
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseRageDefensively", "Use Rage defensively", "Enable this to prioritize defensive use of Rage.");