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
    Enabled = {
      Potions = true,
      Trinkets = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Covenant = "Suggested",
      Trinkets = "Suggested",
      Charge = "Suggested",
      HeroicLeap = "Suggested",
    },
    VictoryRushHP = 80,
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
      BattleShout = false,
      Bladestorm = false,
      Ravager = false,
      Avatar = false,
    },
    OffGCDasOffGCD = {
      -- Abilities
      DeadlyCalm = true,
    },
  },
  Fury = {
    HideCastQueue = false,
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      BattleShout = false,
      Bladestorm = false,
      DragonRoar = false,
      Recklessness = false,
      Siegebreaker = false,
    }
  },
  Protection = {
    DisableHeroicCharge = false,
    DisplayStyle = {
      Defensive = "Suggested"
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      DemoralizingShout = false,
      DragonRoar = false,
      Avatar = false,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
local ARPanel = HR.GUI.Panel
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior")
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms")
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury")
local CP_Protection = CreateChildPanel(CP_Warrior, "Protection")

CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons")
CreatePanelOption("Slider", CP_Warrior, "APL.Warrior.Commons.VictoryRushHP", {0, 100, 1}, "Victory Rush HP", "Set the Victory Rush/Impending Victory HP threshold. Set to 0 to disable.")

-- Arms Settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms")

-- Fury Settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury")
CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.HideCastQueue", "Hide CastQueue Suggestions", "Enable this setting to hide CastQueue suggestions (half-and-half styled icon). NOTE: This will cause HeroRotation to deviate from the Simulationcraft APL.")

-- Protection Settings
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection")
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.DisableHeroicCharge", "Disable Heroic Charge", "Enable this setting to no longer receive the CastQueue 'Heroic Charge' suggestion (Heroic Leap, followed by Charge).")
