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
    Enabled = {
      Potions = true,
      Trinkets = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Covenant = "Suggested",
    },
    UseBloodlust = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      EarthElemental = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      WindShear = true
    }
  },
  Enhancement = {
    PreferEarthShield = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Ascendance = true,
      CrashLightning = false,
      FeralSpirit = true,
      Shield = false
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials

      -- Abilities

    },
  },
  Elemental = {
    PreferEarthShield = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Ascendance = true,
      FireElemental = true,
      Shield = false,
      StormElemental = true,
      Stormkeeper = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Shaman = CreateChildPanel(ARPanel, "Shaman")
local CP_Enhancement = CreateChildPanel(CP_Shaman, "Enhancement")
local CP_Elemental = CreateChildPanel(CP_Shaman, "Elemental")

-- Commons
CreateARPanelOptions(CP_Shaman, "APL.Shaman.Commons")

-- Enhancement
CreateARPanelOptions(CP_Enhancement, "APL.Shaman.Enhancement")
CreatePanelOption("CheckButton", CP_Enhancement, "APL.Shaman.Enhancement.PreferEarthShield", "Prefer Earth Shield", "Prefer using Earth Shield over Lightning Shield, when it's available.")

-- Elemental
CreateARPanelOptions(CP_Elemental, "APL.Shaman.Elemental")
CreatePanelOption("CheckButton", CP_Elemental, "APL.Shaman.Elemental.PreferEarthShield", "Prefer Earth Shield", "Prefer using Earth Shield over Lightning Shield, when it's available.")
