--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Priest = {
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
    GCDasOffGCD = {
      -- Abilities
    },
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      Silence = true,
    }
  },
  Shadow = {
    DispersionHP = 30,
    SelfPI = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Mindbender = true,
      Shadowform = true,
      VoidEruption = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      Dispersion = true,
      PowerInfusion = false,
      SurrenderToMadness = true,
      -- Items
    }
  },
  Discipline = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Mindbender = true,
      PowerInfusion = true,
      ShadowCovenant = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Priest = CreateChildPanel(ARPanel, "Priest")
local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow")
local CP_Discipline = CreateChildPanel(CP_Priest, "Discipline")

CreateARPanelOptions(CP_Priest, "APL.Priest.Commons")

--Shadow
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", {0, 100, 1}, "Dispersion HP", "Set the Dispersion HP threshold.")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.SelfPI", "Assume Self-Power Infusion", "Assume the player will be using Power Infusion on themselves.")
CreateARPanelOptions(CP_Shadow, "APL.Priest.Shadow")

--Discipline
CreateARPanelOptions(CP_Discipline, "APL.Priest.Discipline")
