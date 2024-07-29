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
HR.GUISettings.APL.Mage = {
  Commons = {
    UseTemporalWarp = true,
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
      ShiftingPower = "Suggested",
    },
  },
  CommonsOGCD = {
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      ArcaneIntellect = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      TimeWarp = true,
    }
  },
  Arcane = {
    AEMainIcon = false,
    MirrorImagesBeforePull = true,
    PotionType = {
      Selected = "Power",
    },
    Enabled = {
      ArcaneMissilesInterrupts = true,
      ShiftingPowerInterrupts = true,
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      ArcaneSurge = true,
      MirrorImage = true,
      TouchOfTheMagi = true,
      Evocation = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      PresenceOfMind = true,
    }
  },
  Fire = {
    MirrorImagesBeforePull = false,
    ShowFireBlastLeft = false,
    ShowPyroblastLeft = false,
    StayDistance = true,
    UseScorchSniping = false,
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      DragonsBreath = true,
      LivingBomb = false,
      Meteor = false,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      Combustion = true,
    }
  },
  Frost = {
    StayDistance = true,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Movement = "Suggested",
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      Blizzard = false,
      CometStorm = false,
      Flurry = false,
      Freeze = false,
      FrozenOrb = true,
      IcyVeins = true,
      RayOfFrost = false,
      WaterJet = false,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Mage = CreateChildPanel(ARPanel, "Mage")
local CP_MageDS = CreateChildPanel(CP_Mage, "Class DisplayStyles")
local CP_MageOGCD = CreateChildPanel(CP_Mage, "Class OffGCDs")
local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane")
local CP_Fire = CreateChildPanel(CP_Mage, "Fire")
local CP_Frost = CreateChildPanel(CP_Mage, "Frost")

-- Controls
-- Mage
CreateARPanelOptions(CP_Mage, "APL.Mage.Commons")
CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTemporalWarp", "Suggest Time Warp with Temporal Warp", "Show Time Warp when the Temporal Warp talent is selected.")
CreateARPanelOptions(CP_MageDS, "APL.Mage.CommonsDS")
CreateARPanelOptions(CP_MageOGCD, "APL.Mage.CommonsOGCD")

-- Arcane
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.AEMainIcon", "Show Arcane Explosion in Main Icon", "Enable this to show Arcane Explosion in the main icon. When not enabled, Arcane Explosion will be shown in the left icon.")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MirrorImagesBeforePull", "Use Mirror Images Precombat", "Enable this option to show Mirror Images during Precombat.")
CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane")

-- Fire
CreateARPanelOptions(CP_Fire, "APL.Mage.Fire")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.StayDistance", "Stay at distance", "Only use Arcane Explosion/Dragon's Breath if in range or on the left icon.")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.ShowFireBlastLeft", "Show Fire Blast on left icon while casting", "Show Fire Blast on left icon while casting")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.ShowPyroblastLeft", "Show Free Pyroblast on left icon", "Show free Pyroblast casts on left icon while casting")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat.")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.UseScorchSniping", "Enable Scorch sniping", "Enable this option to show a Scorch suggestion in the CastLeft area when Searing Touch is talented and one of your non-primary targets is under 30% health.")

-- Frost
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range. If out of range, display it on the left icon.")
CreateARPanelOptions(CP_Frost, "APL.Mage.Frost")
