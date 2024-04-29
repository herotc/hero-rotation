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
    },
  },
  CommonsOGCD = {
    GCDasOffGCD = {
      PowerWordFortitude = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
    }
  },
  Shadow = {
    DesperatePrayerHP = 75,
    DispersionHP = 30,
    PreferVTWhenSTinDungeon = false,
    SelfPI = true,
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      DarkAscension = true,
      DivineStar = true,
      Halo = false,
      HolyNova = true,
      Mindbender = true,
      ShadowCrash = false,
      Shadowform = true,
      ShadowWordDeath = false,
      ShadowWordPain = false,
      VoidEruption = true,
      VoidTorrent = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Dispersion = true,
      PowerInfusion = false,
    }
  },
  Discipline = {
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      Mindbender = true,
      PowerInfusion = true,
      ShadowCovenant = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
    }
  },
  Holy = {
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      Apotheosis = true,
      DivineStar = true,
      Halo = true,
    },
    OffGCDasOffGCD = {
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Priest = CreateChildPanel(ARPanel, "Priest")
local CP_PriestDS = CreateChildPanel(CP_Priest, "Class DisplayStyles")
local CP_PriestOGCD = CreateChildPanel(CP_Priest, "Class OffGCDs")
local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow")
--local CP_Discipline = CreateChildPanel(CP_Priest, "Discipline")
--local CP_Holy = CreateChildPanel(CP_Priest, "Holy")

-- Commons
CreateARPanelOptions(CP_Priest, "APL.Priest.Commons")
CreateARPanelOptions(CP_PriestDS, "APL.Priest.CommonsDS")
CreateARPanelOptions(CP_PriestOGCD, "APL.Priest.CommonsOGCD")

--Shadow
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DesperatePrayerHP", { 0, 100, 1 }, "Desperate Prayer HP",
  "Set the Desperate Prayer HP threshold.")
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", { 0, 100, 1 }, "Dispersion HP",
  "Set the Dispersion HP threshold.")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.SelfPI", "Assume Self-Power Infusion",
  "Assume the player will be using Power Infusion on themselves.")
CreateARPanelOptions(CP_Shadow, "APL.Priest.Shadow")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.PreferVTWhenSTinDungeon", "Prefer VT for dungeon ST",
  "Prefer to use Vampiric Touch while in single target combat in dungeon content. (Note: This does not apply to raid content.)")

--Discipline
--CreateARPanelOptions(CP_Discipline, "APL.Priest.Discipline")

--Holy
--CreateARPanelOptions(CP_Holy, "APL.Priest.Holy")
