--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
  -- HeroLib
local HL = HeroLib
-- HeroRotation
local HR = HeroRotation
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Shaman = {
  Commons = {
    PreferEarthShield = false,
    ShieldsOOC = false,
    WeaponBuffsOOC = false,
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
      Signature = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
      SpiritwalkersGrace = "SuggestedRight",
    },
  },
  CommonsOGCD = {
    GCDasOffGCD = {
      AncestralSwiftness = true,
      Ascendance = true,
      EarthElemental = true,
      NaturesSwiftness = true,
      TotemicRecall = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
    }
  },
  Elemental = {
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
    },
    GCDasOffGCD = {
      -- Abilities
      EchoingShock = true,
      FireElemental = true,
      LiquidMagmaTotem = true,
      Shield = false,
      StormElemental = true,
      Stormkeeper = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
    }
  },
  Enhancement = {
    Rotation = "Standard",
    HealWith5Maelstrom = 50,
    HealWithout5Maelstrom = 30,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      -- Abilities
      CrashLightning = false,
      DoomWinds = false,
      FeralSpirit = true,
      HealingSurge = false,
      Shield = false,
      Sundering = false,
      WindfuryTotem = false,
    },
    OffGCDasOffGCD = {
    },
  },
  Restoration = {
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
    },
    OffGCDasOffGCD = {
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Shaman = CreateChildPanel(ARPanel, "Shaman")
local CP_ShamanDS = CreateChildPanel(CP_Shaman, "Class DisplayStyles")
local CP_ShamanOGCD = CreateChildPanel(CP_Shaman, "Class OffGCDs")
local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement")
local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental")
local CP_Restoration = CreateChildPanel(CP_Shaman, "Restoration")

-- Commons
CreateARPanelOptions(CP_Shaman, "APL.Shaman.Commons")
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.PreferEarthShield", "Prefer Earth Shield", "Prefer using Earth Shield over Lightning Shield, when it's available.")
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.ShieldsOOC", "Show Shields OOC", "Enable to show elemental shields while out of combat.")
CreatePanelOption("CheckButton", CP_Shaman, "APL.Shaman.Commons.WeaponBuffsOOC", "Show Weapon Buffs OOC", "Enable to show weapon buffs while out of combat.")
CreateARPanelOptions(CP_ShamanDS, "APL.Shaman.CommonsDS")
CreateARPanelOptions(CP_ShamanOGCD, "APL.Shaman.CommonsOGCD")

-- Elemental
CreateARPanelOptions(CP_Elemental, "APL.Shaman.Elemental")

-- Enhancement
CreateARPanelOptions(CP_Enhancement, "APL.Shaman.Enhancement")
CreatePanelOption("Dropdown", CP_Enhancement, "APL.Shaman.Enhancement.Rotation", {"Standard", "Funnel"}, "Rotation Type", "Select to choose between the Standard or Funnel rotations.")
CreatePanelOption("Slider", CP_Enhancement, "APL.Shaman.Enhancement.HealWith5Maelstrom", {0, 100, 1}, "Heal Pct with 5 Maelstrom", "Sets the health percentage under which Healing Surge should be suggested with 5 Maelstrom. Set this to 0 to disable healing suggestions.")
CreatePanelOption("Slider", CP_Enhancement, "APL.Shaman.Enhancement.HealWithout5Maelstrom", {0, 100, 1}, "Heal Pct without 5 Maelstrom", "Sets the health percentage under which Healing Surge should be suggested when below 5 Maelstrom. Set this to 0 to disable healing suggestions.")

-- Restoration
--CreateARPanelOptions(CP_Restoration, "APL.Shaman.Restoration")
