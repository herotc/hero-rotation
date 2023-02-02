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
      Items = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Signature = "Suggested",
      Items = "Suggested",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      MarkOfTheWild = true,
      WildCharge = true,
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
    DelayBerserking = false,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      AstralCommunion = true,
      CaInc = true,
      ForceOfNature = true,
      FuryOfElune = true,
      MoonkinForm = false,
      Starfall = false,
      WarriorOfElune = true,
    },
    OffGCDasOffGCD = {
      Barkskin = true,
      Renewal = true,
    }
  },
  Feral = {
    FillerSpell = "Rake Non-Snapshot",
    ShowCatFormOOC = false,
    UseOwlweave = false,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      BsInc = true,
    },
    OffGCDasOffGCD = {
      SkullBash = true,
      TigersFury = true,
    }
  },
  Guardian = {
    UseIronfurOffensively = true,
    UseRageDefensively = true,
    BarkskinHP = 50,
    FrenziedRegenHP = 70,
    SurvivalInstinctsHP = 30,
    BristlingFurRage = 50,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Defensives = "Suggested"
    },
    GCDasOffGCD = {
      FrenziedRegeneration = true,
      HeartOfTheWild = true,
    },
    OffGCDasOffGCD = {
      Berserk = true,
      Incarnation = true,
      Ironfur = true,
      SkullBash = true,
    }
  },
  Restoration = {
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      HeartOfTheWild = true,
    },
    OffGCDasOffGCD = {
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Druid = CreateChildPanel(ARPanel, "Druid")
local CP_Balance = CreateChildPanel(CP_Druid, "Balance")
local CP_Feral = CreateChildPanel(CP_Druid, "Feral")
local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian")
local CP_Restoration = CreateChildPanel(CP_Druid, "Restoration")

-- Druid
CreateARPanelOptions(CP_Druid, "APL.Druid.Commons")

-- Balance
CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkskinHP", {0, 100, 1}, "Barkskin HP", "Set the Barkskin HP threshold.")
CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.")
CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMoonkinFormOOC", "Show Moonkin Form Out of Combat", "Enable this if you want the addon to show you the Moonkin Form reminder out of combat.")
CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.DelayBerserking", "Delay Berserking", "Delay Berserking usage by 0.3 seconds, which aligns timing with the timing used in early patch 9.2.")
CreateARPanelOptions(CP_Balance, "APL.Druid.Balance")

-- Feral
CreatePanelOption("Dropdown", CP_Feral, "APL.Druid.Feral.FillerSpell", {"Shred", "Rake Non-Snapshot", "Rake Snapshot", "Moonfire", "Swipe"}, "Preferred Filler Spell", "Select which spell to use as your filler spell. The SimC APL default is Rake Non-Snapshot.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.ShowCatFormOOC", "Show Cat Form Out of Combat", "Enable this if you want the addon to show you the Cat Form reminder out of combat.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.UseOwlweave", "Utilize Owleaving", "Enable this if you want Owlweaving spell suggestions when talented into Balance Affinity.")
CreateARPanelOptions(CP_Feral, "APL.Druid.Feral")

-- Guardian
CreateARPanelOptions(CP_Guardian, "APL.Druid.Guardian")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseIronfurOffensively", "Use Ironfur Offensively", "Enable this if you want offensive Ironfur suggestions (e.g. with Thorns of Iron).")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseRageDefensively", "Use Rage Defensively", "Enable this if you want to save rage for defensive use, disabling Maul suggestions.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BarkskinHP", {0, 100, 1}, "Barkskin Threshold", "Set the HP percentage threshold of when to use Barkskin.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.FrenziedRegenHP", {0, 100, 1}, "Frenzied Regen Threshold", "Set the HP percentage threshold of when to use Frenzied Regeneration.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts Threshold", "Set the HP percentage threshold of when to use Survival Instincts.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BristlingFurRage", {0, 100, 1}, "Bristling Fur Threshold", "Set the Rage threshold of when to use Bristling Fur.")

-- Restoration
CreateARPanelOptions(CP_Restoration, "APL.Druid.Restoration")
