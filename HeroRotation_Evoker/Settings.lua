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
HR.GUISettings.APL.Evoker = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    DisplayStyle = {
      Defensives = "Suggested",
      Potions = "Suggested",
      Signature = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      BlessingOfTheBronze = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      Quell = true,
    }
  },
  Devastation = {
    UseDefensives = true,
    ObsidianScalesThreshold = 60,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      DeepBreath = true,
      Dragonrage = true,
      TipTheScales = true,
      Unravel = true,
    },
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Evoker = CreateChildPanel(ARPanel, "Evoker")
local CP_Devastation = CreateChildPanel(CP_Evoker, "Devastation")

-- Evoker
CreateARPanelOptions(CP_Evoker, "APL.Evoker.Commons")

-- Devastation
CreatePanelOption("CheckButton", CP_Devastation, "APL.Evoker.Devastation.UseDefensives", "Suggest Defensives", "Enable this option to have the addon suggest defensive spells.")
CreatePanelOption("Slider", CP_Devastation, "APL.Evoker.Devastation.ObsidianScalesThreshold", {5, 100, 5}, "Obsidian Scales Threshold", "Suggest Obsidian Scales when below this health percentage.")
CreateARPanelOptions(CP_Devastation, "APL.Evoker.Devastation")
