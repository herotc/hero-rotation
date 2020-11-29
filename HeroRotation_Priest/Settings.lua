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
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
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
    DispersionHP = 10,
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
      Shadowfiend = true,
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
CreatePanelOption("CheckButton", CP_Priest, "APL.Priest.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use potions.")
CreatePanelOption("CheckButton", CP_Priest, "APL.Priest.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Priest, "APL.Priest.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Priest, "APL.Priest.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for active Shadowlands Covenant Abilities.")

--Shadow
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", {0, 100, 1}, "Dispersion HP", "Set the Dispersion HP threshold.")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.SelfPI", "Assume Self-Power Infusion", "Assume the player will be using Power Infusion on themselves.")
CreateARPanelOptions(CP_Shadow, "APL.Priest.Shadow")

--Discipline
CreateARPanelOptions(CP_Discipline, "APL.Priest.Discipline")
