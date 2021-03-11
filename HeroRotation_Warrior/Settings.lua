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
    CovenantDisplayStyle = "Suggested",
    BattleShoutDisplayStyle = "Main",
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
      Bladestorm = false,
      Ravager = false,
      Avatar = false,
    },
    OffGCDasOffGCD = {
      -- Abilities
      DeadlyCalm = true,
    },
    ChargeDisplayStyle = "Main Icon",
    HeroicLeapDisplayStyle = "Main Icon",
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
    },
    ChargeDisplayStyle = "Main Icon",
    HeroicLeapDisplayStyle = "Main Icon",
  },
  Protection = {
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    },
    GCDasOffGCD = {
      DemoralizingShout = false,
      DragonRoar = false,
      Avatar = false,
    },
    ChargeDisplayStyle = "Main Icon",
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
local ARPanel = HR.GUI.Panel
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior")
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms")
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury")
local CP_Protection = CreateChildPanel(CP_Warrior, "Protection")

CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for Covenant abilities.")
CreatePanelOption("Dropdown", CP_Warrior, "APL.Warrior.Commons.BattleShoutDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Battle Shout Display Style", "Define which icon display style to use for Battle Shout.")

-- Arms Settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms")
CreatePanelOption("Dropdown", CP_Arms, "APL.Warrior.Arms.ChargeDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Charge Display Style", "Define which icon display style to use for Charge.")
CreatePanelOption("Dropdown", CP_Arms, "APL.Warrior.Arms.HeroicLeapDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Heroic Leap Display Style", "Define which icon display style to use for Heroic Leap.")

-- Fury Settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury")
CreatePanelOption("Dropdown", CP_Fury, "APL.Warrior.Fury.ChargeDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Charge Display Style", "Define which icon display style to use for Charge.")
CreatePanelOption("Dropdown", CP_Fury, "APL.Warrior.Fury.HeroicLeapDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Heroic Leap Display Style", "Define which icon display style to use for Heroic Leap.")

-- Protection Settings
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection")
CreatePanelOption("Dropdown", CP_Protection, "APL.Warrior.Protection.ChargeDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Charge Display Style", "Define which icon display style to use for Charge.")
