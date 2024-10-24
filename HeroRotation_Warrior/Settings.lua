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
    ShoutDuringCombat = true,
    VictoryRushHP = 80,
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
  },
  CommonsDS = {
    DisplayStyle = {
      -- Common
      Interrupts = "Cooldown",
      Items = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
      ChampionsSpear = "Suggested",
      Charge = "Suggested",
      HeroicLeap = "Suggested",
      OdynsFury = "Suggested",
    },
  },
  CommonsOGCD = {
    -- {Display OffGCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      BattleShout = true,
      Bladestorm = false,
      Ravager = false,
    },
    OffGCDasOffGCD = {
      Racials = true,
    },
  },
  Arms = {
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Avatar = false,
      ColossusSmash = false,
      IgnorePain = false,
      Shockwave = true,
      ThunderousRoar = false,
      Warbreaker = false,
    },
    OffGCDasOffGCD = {
    },
  },
  Fury = {
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      Avatar = false,
      Recklessness = false,
      Shockwave = true,
      ThunderousRoar = false,
    }
  },
  Protection = {
    AllowIPOvercap = false,
    LastStandHP = 60,
    RageCapValue = 80,
    UseLastStandOffensively = true,
    PotionType = {
      Selected = "Tempered",
    },
    DisplayStyle = {
      IgnorePain = "Suggested",
      LastStand = "Suggested",
      ShieldBlock = "Suggested",
      ShieldWall = "Suggested",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      Avatar = false,
      Demolish = false,
      DemoralizingShout = false,
      Shockwave = true,
      ThunderousRoar = false,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
local ARPanel = HR.GUI.Panel
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior")
local CP_WarriorDS = CreateChildPanel(CP_Warrior, "Class DisplayStyles")
local CP_WarriorOGCD = CreateChildPanel(CP_Warrior, "Class OffGCDs")
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms")
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury")
local CP_Protection = CreateChildPanel(CP_Warrior, "Protection")

-- Commons
CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.ShoutDuringCombat", "Battle Shout during combat", "Enable this option to allow Battle Shout to be suggested during combat (for re-buffing fallen allies or when the buff expires during combat).")
CreatePanelOption("Slider", CP_Warrior, "APL.Warrior.Commons.VictoryRushHP", {0, 100, 1}, "Victory Rush HP", "Set the Victory Rush/Impending Victory HP threshold. Set to 0 to disable.")
CreateARPanelOptions(CP_WarriorDS, "APL.Warrior.CommonsDS")
CreateARPanelOptions(CP_WarriorOGCD, "APL.Warrior.CommonsOGCD")

-- Arms Settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms")

-- Fury Settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury")

-- Protection Settings
CreatePanelOption("Slider", CP_Protection, "APL.Warrior.Protection.RageCapValue", {30, 100, 5}, "Rage Cap Value", "Set the highest amount of Rage we should allow to pool before dumping Rage with Ignore Pain. Setting this value to 30 will allow you to over-cap Rage.")
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.AllowIPOvercap", "Allow Ignore Pain Overcap", "Enable this option to allow Ignore Pain to be suggested, even when it would push the absorb over its maximum absorb value.")
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseLastStandOffensively", "Use Last Stand Offensively", "Enable this option to allow Last Stand to be suggested offensively, as suggested by the Simulationcraft APL.")
CreatePanelOption("Slider", CP_Protection, "APL.Warrior.Protection.LastStandHP", {0, 100, 1}, "Last Stand HP", "If 'Use Last Stand Offensively' is disabled, suggest Last Stand only when below this health percentage. This setting does nothing if 'Use Last Stand Offensively' is enabled.")
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection")
