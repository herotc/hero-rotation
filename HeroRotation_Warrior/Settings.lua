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
-- Global settings table for Warrior specializations
HR.GUISettings.APL.Warrior = {
  Commons = {
    -- Allow Battle Shout suggestions during combat for rebuffing
    ShoutDuringCombat = true,
    -- Health threshold for Victory Rush/Impending Victory usage
    VictoryRushHP = 80,
    -- Global toggles for item usage
    Enabled = {
      Potions = true,    -- Enable/disable potion usage
      Trinkets = true,   -- Enable/disable trinket usage
      Items = true,      -- Enable/disable other item usage
    },
  },
  -- Display style settings for various abilities
  CommonsDS = {
    DisplayStyle = {
      -- Common display styles
      Interrupts = "Cooldown",    -- Show interrupts as cooldown icons
      Items = "Suggested",        -- Show items as suggestions
      Potions = "Suggested",      -- Show potions as suggestions
      Trinkets = "Suggested",     -- Show trinkets as suggestions
      -- Class specific display styles
      ChampionsSpear = "Suggested",
      Charge = "Suggested",
      Demolish = "Suggested",
      HeroicLeap = "Suggested",
      OdynsFury = "Suggested",
    },
  },
  -- Off-GCD ability settings
  CommonsOGCD = {
    -- Abilities to show as off-GCD even though they trigger GCD
    GCDasOffGCD = {
      BattleShout = true,     -- Show Battle Shout as off-GCD
      Bladestorm = false,     -- Show Bladestorm normally
      Ravager = false,        -- Show Ravager normally
    },
    -- True off-GCD abilities
    OffGCDasOffGCD = {
      Racials = true,         -- Show racial abilities as off-GCD
    },
  },
  -- Arms Warrior specific settings
  Arms = {
    PotionType = {
      Selected = "Tempered",  -- Default potion selection
    },
    -- Ability display settings
    GCDasOffGCD = {
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
  -- Fury Warrior specific settings
  Fury = {
    PotionType = {
      Selected = "Tempered",  -- Default potion selection
    },
    -- Enhanced cooldown synchronization toggle
    -- When enabled, provides smarter CD alignment for improved burst windows
    -- Can provide 2-4% DPS increase through optimized CD usage
    UseCDSync = false,        -- Default to off to maintain original behavior
    -- Ability display settings
    OffGCDasOffGCD = {
    },
    GCDasOffGCD = {
      Avatar = false,         -- Show Avatar normally
      Recklessness = false,   -- Show Recklessness normally
      Shockwave = true,       -- Show Shockwave as off-GCD
      ThunderousRoar = false, -- Show Thunderous Roar normally
    }
  },
  -- Protection Warrior specific settings
  Protection = {
    -- Allow Ignore Pain to exceed maximum absorb value
    AllowIPOvercap = false,
    -- Health threshold for defensive Last Stand usage
    LastStandHP = 60,
    -- Maximum Rage to pool before suggesting spenders
    RageCapValue = 80,
    -- Allow offensive usage of Last Stand with certain talents
    UseLastStandOffensively = true,
    PotionType = {
      Selected = "Tempered",  -- Default potion selection
    },
    -- Display style settings for defensive abilities
    DisplayStyle = {
      IgnorePain = "Suggested",
      LastStand = "Suggested",
      ShieldBlock = "Suggested",
      ShieldWall = "Suggested",
    },
    -- Ability display settings
    OffGCDasOffGCD = {
    },
    GCDasOffGCD = {
      Avatar = false,
      DemoralizingShout = false,
      Shockwave = true,
      ThunderousRoar = false,
    }
  },
}

-- Load settings recursively
HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Create main panel and sub-panels
local ARPanel = HR.GUI.Panel
local CP_Warrior = CreateChildPanel(ARPanel, "Warrior")
local CP_WarriorDS = CreateChildPanel(CP_Warrior, "Class DisplayStyles")
local CP_WarriorOGCD = CreateChildPanel(CP_Warrior, "Class OffGCDs")
local CP_Arms = CreateChildPanel(CP_Warrior, "Arms")
local CP_Fury = CreateChildPanel(CP_Warrior, "Fury")
local CP_Protection = CreateChildPanel(CP_Warrior, "Protection")

-- Create common settings
CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons")
CreatePanelOption("CheckButton", CP_Warrior, "APL.Warrior.Commons.ShoutDuringCombat", 
  "Battle Shout during combat", 
  "Enable this option to allow Battle Shout to be suggested during combat (for re-buffing fallen allies or when the buff expires during combat)."
)
CreatePanelOption("Slider", CP_Warrior, "APL.Warrior.Commons.VictoryRushHP", 
  {0, 100, 1}, 
  "Victory Rush HP", 
  "Set the Victory Rush/Impending Victory HP threshold. Set to 0 to disable."
)
CreateARPanelOptions(CP_WarriorDS, "APL.Warrior.CommonsDS")
CreateARPanelOptions(CP_WarriorOGCD, "APL.Warrior.CommonsOGCD")

-- Create specialization-specific settings
CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms")

-- Fury Warrior settings
CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury")
CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.UseCDSync", 
  "Enhanced CD Sync", 
  "Enable enhanced cooldown synchronization logic for better CD alignment with trinkets and other abilities. " ..
  "This can improve DPS by 2-4% through optimized burst windows, but may briefly hold CDs for better timing. " ..
  "Especially powerful with Titan's Torment talent."
)

-- Protection Warrior settings
CreatePanelOption("Slider", CP_Protection, "APL.Warrior.Protection.RageCapValue", 
  {30, 100, 5}, 
  "Rage Cap Value", 
  "Set the highest amount of Rage we should allow to pool before dumping Rage with Ignore Pain. Setting this value to 30 will allow you to over-cap Rage."
)
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.AllowIPOvercap", 
  "Allow Ignore Pain Overcap", 
  "Enable this option to allow Ignore Pain to be suggested, even when it would push the absorb over its maximum absorb value."
)
CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseLastStandOffensively", 
  "Use Last Stand Offensively", 
  "Enable this option to allow Last Stand to be suggested offensively, as suggested by the Simulationcraft APL."
)
CreatePanelOption("Slider", CP_Protection, "APL.Warrior.Protection.LastStandHP", 
  {0, 100, 1}, 
  "Last Stand HP", 
  "If 'Use Last Stand Offensively' is disabled, suggest Last Stand only when below this health percentage. This setting does nothing if 'Use Last Stand Offensively' is enabled."
)
CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection")
