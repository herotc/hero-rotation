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
HR.GUISettings.APL.DemonHunter = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Signature = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
      FelRush = "Suggested",
      Metamorphosis = "Suggested",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      SigilOfFlame = false,
    },
    OffGCDasOffGCD = {
      Disrupt = true,
      Racials = true,
    },
  },
  Vengeance = {
    MetamorphosisHealthThreshold = 50,
    FieryBrandHealthThreshold = 40,
    DemonSpikesHealthThreshold = 65,
    FelDevHealthThreshold = 30,
    ConserveInfernalStrike = true,
    UseFieryBrandOffensively = false,
    UseMetaOffensively = false,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Defensives = "SuggestedRight",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      InfernalStrike = false,
    },
    GCDasOffGCD = {
      BulkExtraction = false,
      FelDevastation = false,
      FieryBrand = false,
    }
  },
  Havoc = {
    BlurHealthThreshold = 65,
    ConserveFelRush = false,
    PotionType = {
      Selected = "Power",
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      Blur = true,
      VengefulRetreat = true,
    },
    GCDasOffGCD = {
      -- Abilities
      EyeBeam = false,
      GlaiveTempest = false,
      ImmolationAura = false,
      ThrowGlaive = false,
    },
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
local ARPanel = HR.GUI.Panel
local CP_DemonHunter = CreateChildPanel(ARPanel, "DemonHunter")
local CP_Havoc = CreateChildPanel(CP_DemonHunter, "Havoc")
local CP_Vengeance = CreateChildPanel(CP_DemonHunter, "Vengeance")

-- Commons
CreateARPanelOptions(CP_DemonHunter, "APL.DemonHunter.Commons")

-- Vengeance
CreatePanelOption("Slider", CP_Vengeance, "APL.DemonHunter.Vengeance.MetamorphosisHealthThreshold", {0, 100, 5}, "Metamorphosis Health Threshold", "Suggest Metamorphosis when below this health percentage.")
CreatePanelOption("Slider", CP_Vengeance, "APL.DemonHunter.Vengeance.FieryBrandHealthThreshold", {0, 100, 5}, "Fiery Brand Health Threshold", "Suggest Fiery Brand when below this health percentage.")
CreatePanelOption("Slider", CP_Vengeance, "APL.DemonHunter.Vengeance.DemonSpikesHealthThreshold", {0, 100, 5}, "Demon Spikes Health Threshold", "Suggest Demon Spikes when below this health percentage.")
CreatePanelOption("Slider", CP_Vengeance, "APL.DemonHunter.Vengeance.FelDevHealthThreshold", {0, 100, 5}, "Fel Devastation Health Threshold", "Suggest Fel Devastation during Blind Faith when below this health percentage.")
CreatePanelOption("CheckButton", CP_Vengeance, "APL.DemonHunter.Vengeance.ConserveInfernalStrike", "Conserve Infernal Strike", "Save at least 1 Infernal Strike charge for mobility.")
CreatePanelOption("CheckButton", CP_Vengeance, "APL.DemonHunter.Vengeance.UseFieryBrandOffensively", "Use Fiery Brand Offensively", "Check this to recommend offensive Fiery Brand usage. Otherwise, it will be saved as a defensive.")
CreatePanelOption("CheckButton", CP_Vengeance, "APL.DemonHunter.Vengeance.UseMetaOffensively", "Use Metamorphosis Offensively", "Check this to recommend offensive Metamorphosis usage. Otherwise, it will be saved as a defensive.")
CreateARPanelOptions(CP_Vengeance, "APL.DemonHunter.Vengeance")

-- Havoc
CreatePanelOption("CheckButton", CP_Havoc, "APL.DemonHunter.Havoc.ConserveFelRush", "Conserve Fel Rush", "Save at least 1 Fel Rush charge for mobility.")
CreatePanelOption("Slider", CP_Havoc, "APL.DemonHunter.Havoc.BlurHealthThreshold", {5, 100, 5}, "Blur Health Threshold", "Suggest Blur when below this health percentage.")
CreateARPanelOptions(CP_Havoc, "APL.DemonHunter.Havoc")