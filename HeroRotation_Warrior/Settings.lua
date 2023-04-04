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
      Signature = "Suggested",
      Trinkets = "Suggested",
      Charge = "Suggested",
      HeroicLeap = "Suggested",
    },
    VictoryRushHP = 80,
    -- {Display OffGCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      BattleShout = true,
    },
    OffGCDasOffGCD = {
      Pummel = true,
      Racials = true,
    },
  },
  Arms = {
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Avatar = false,
      Bladestorm = false,
      IgnorePain = false,
      Shockwave = true,
      ThunderousRoar = false,
    },
    OffGCDasOffGCD = {
    },
  },
  Fury = {
    PotionType = {
      Selected = "Power",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      Avatar = false,
      Ravager = false,
      Recklessness = false,
      Shockwave = true,
      ThunderousRoar = false,
    }
  },
  Protection = {
    RageCapValue = 80,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Defensive = "Suggested"
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      Avatar = false,
      DemoralizingShout = false,
      Ravager = false,
      Shockwave = true,
      ThunderousRoar = false,
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

-- Protection Settings
CreatePanelOption("Slider", CP_Protection, "APL.Warrior.Protection.RageCapValue", {30, 100, 5}, "Rage Cap Value", "Set the highest amount of Rage we should allow to pool before dumping Rage with Ignore Pain. Setting this value to 30 will allow you to over-cap Rage.")
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection")
