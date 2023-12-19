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
    ShowCancelStarlord = false,
    ShowMoonkinFormOOC = false,
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
      WildMushroom = false,
    },
    OffGCDasOffGCD = {
      Barkskin = true,
      NaturesVigil = true,
      Renewal = true,
    }
  },
  Feral = {
    ShowCatFormOOC = false,
    ShowHealSpells = false,
    UseEasySwipe = false,
    UseZerkBiteweave = false,
    Align2Min = false,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      BsInc = true,
      HeartOfTheWild = true,
      Regrowth = true,
      Renewal = true,
    },
    OffGCDasOffGCD = {
      NaturesVigil = true,
      SkullBash = true,
      TigersFury = true,
    }
  },
  Guardian = {
    UseIronfurOffensively = true,
    UseRageDefensively = true,
    DoCRegrowthNoPoPHP = 30,
    DoCRegrowthWithPoPHP = 45,
    RenewalHP = 60,
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
      HeartOfTheWild = true,
    },
    OffGCDasOffGCD = {
      Berserk = true,
      Incarnation = true,
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
CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMoonkinFormOOC", "Show Moonkin Form Out of Combat", "Enable this option if you want the addon to show you the Moonkin Form reminder out of combat.")
CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowCancelStarlord", "Show Starlord Cancel Suggestions", "Enable this option if you want to see suggestions to cancel Starlord. Note: This is a very minor dps gain if done correctly, but can be a dps loss if done incorrectly.")
CreateARPanelOptions(CP_Balance, "APL.Druid.Balance")

-- Feral
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.ShowCatFormOOC", "Show Cat Form Out of Combat", "Enable this if you want the addon to show you the Cat Form reminder out of combat.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.ShowHealSpells", "Show Healing Abilities", "Enable this if you want the addon to show you healing abilities (as suggested by the APL) during your rotation. THIS IS A DPS LOSS WITHOUT TOXIC THORN.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.UseEasySwipe", "Use Feral's 'Easy Swipe' Rotation", "Enable this option to enable a slightly inferior, but simpler AoE rotation, where Shred is not suggested, instead opting to proc BT via Swipe, Rake, or Thrash. THIS IS A DPS LOSS.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.UseZerkBiteweave", "Use 'Zerk Biteweave'", "Enable this option to suggest Ferocious Bite during Incarnation/Berserk in AoE situations.")
CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.Align2Min", "Always align Berserk with Convoke", "Enable this option to force the addon to align Berserk usage with Convoke.")
CreateARPanelOptions(CP_Feral, "APL.Druid.Feral")

-- Guardian
CreateARPanelOptions(CP_Guardian, "APL.Druid.Guardian")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseIronfurOffensively", "Use Ironfur Offensively", "Enable this if you want offensive Ironfur suggestions (e.g. with Thorns of Iron).")
CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseRageDefensively", "Use Rage Defensively", "Enable this if you want to save rage for defensive use, disabling Maul suggestions.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the HP percentage threshold of when you want the addon to suggest defensive usgae of Renewal, if talented. (Set to 0 to disable)")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.DoCRegrowthWithPoPHP", {0, 100, 1}, "DoC Regrowth With PoP HP", "Set the HP percentage threshold of when you want the addon to suggest defensive usage of a Dream of Cenarius buffed Regrowth with the Protector of the Pack buff active. (Set to 0 to disable)")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.DoCRegrowthNoPoPHP", {0, 100, 1}, "DoC Regrowth Without PoP HP", "Set the HP precentage threshold of when you want the addon to suggest defensive usage of a Dream of Cenarius buffed Regrowth without the Protector of the Pack buff active. (Set to 0 to disable)")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BarkskinHP", {0, 100, 1}, "Barkskin Threshold", "Set the HP percentage threshold of when to use Barkskin.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.FrenziedRegenHP", {0, 100, 1}, "Frenzied Regen Threshold", "Set the HP percentage threshold of when to use Frenzied Regeneration.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts Threshold", "Set the HP percentage threshold of when to use Survival Instincts.")
CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BristlingFurRage", {0, 100, 1}, "Bristling Fur Threshold", "Set the Rage threshold of when to use Bristling Fur.")

-- Restoration
CreateARPanelOptions(CP_Restoration, "APL.Druid.Restoration")
