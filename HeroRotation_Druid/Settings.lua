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
HR.GUISettings.APL.Druid = {
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
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
    }
  },
  Balance = {
    BarkskinHP = 50,
    RenewalHP = 40,
    ShowMoonkinFormOOC = false,
    UseBarkskinDefensively = false,
    GCDasOffGCD = {
      MoonkinForm = false,
      CaInc = true,
      WarriorofElune = true,
      ForceofNature = true,
      FuryofElune = true,
      Starfall = false,
    },
    OffGCDasOffGCD = {
      Renewal = true,
      Barkskin = true,
    }
  },
  Guardian = {
    UseRageDefensively = true,
    BarkskinHP = 50,
    FrenziedRegenHP = 70,
    SurvivalInstinctsHP = 30,
    BristlingFurRage = 50,
    DisplayStyle = {
      Defensives = "Suggested"
    },
    GCDasOffGCD = {
      FrenziedRegeneration = true,
    },
    OffGCDasOffGCD = {
      Berserk = true,
      Incarnation = true,
      SkullBash = true,
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Druid = CreateChildPanel(ARPanel, "Druid")
local CP_Balance = CreateChildPanel(CP_Druid, "Balance")
local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian")

-- Druid
CreateARPanelOptions(CP_Druid, "APL.Druid.Commons")

-- Balance
CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkskinHP", {0, 100, 1}, "Barkskin HP", "Set the Barkskin HP threshold.")
CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.")
CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMoonkinFormOOC", "Show Moonkin Form Out of Combat", "Enable this if you want the addon to show you the Moonkin Form reminder out of combat.")
CreateARPanelOptions(CP_Balance, "APL.Druid.Balance")

-- Guardian
CreateARPanelOptions(CP_Guardian, "APL.Druid.Guardian")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseRageDefensively", "Use Rage Defensively", "Enable this if you want to save rage for defensive use, disabling Maul suggestions.")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseBarkskinDefensively", "Use Barkskin Defensively", "Enable this if you want to save Barkskin for defensive use, disabling offensive Barkskin with Brambles.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BarkskinHP", {0, 100, 1}, "Barkskin Threshold", "Set the HP percentage threshold of when to use Barkskin.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.FrenziedRegenHP", {0, 100, 1}, "Frenzied Regen Threshold", "Set the HP percentage threshold of when to use Frenzied Regeneration.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts Threshold", "Set the HP percentage threshold of when to use Survival Instincts.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BristlingFurRage", {0, 100, 1}, "Bristling Fur Threshold", "Set the Rage threshold of when to use Bristling Fur.")
