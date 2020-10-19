--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation

local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Warrior = {
  Commons = {
    UsePotions  = true,
    UseTrinkets = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Racials = true,
      -- Abilities
      Pummel = true,
      Avatar = true,
      BattleCry = true
    },
  },
  Arms = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      ColossusSmash = false,
      Warbreaker = false,
      Bladestorm = false,
      Ravager = false,
      HeroicLeap = false,
      Charge = false,
      Avatar = false,
    },
    OffGCDasOffGCD = {
      -- Abilities
      DeadlyCalm = true,
    },
  },
  Fury = {
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      Bladestorm = false,
      DragonRoar = false,
      Recklessness = false,
      Siegebreaker = false,
      HeroicLeap = false,
      Charge = false,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
local ARPanel = HR.GUI.Panel
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior")
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms")
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury")

CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.")

-- Arms Settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms")

-- Fury Settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury")