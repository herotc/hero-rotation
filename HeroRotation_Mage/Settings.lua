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
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
      Signature = "Suggested",
    },
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
      Counterspell = true,
    }
  },
  Frost = {
    MovingRotation = false,
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
      Freeze = false,
      FrozenOrb = true,
      IcyVeins = true,
      WaterJet = false,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
    }
  },
  Fire = {
    DisableCombustion = false,
    MirrorImagesBeforePull = false,
    MovingRotation = false,
    StayDistance = true,
    ShowFireBlastLeft = true,
    ShowPyroblastLeft = false,
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      DragonsBreath = true,
      Meteor = false,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      Combustion = true,
    }
  },
  Arcane = {
    MirrorImagesBeforePull = true,
    PotionType = {
      Selected = "Power",
    },
    Enabled={
      ManaGem = true,
    },
    StayDistance = false,
    MovingRotation = false,
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
      ManaGem = true,
      PresenceOfMind = true,
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Mage = CreateChildPanel(ARPanel, "Mage")
local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane")
local CP_Fire = CreateChildPanel(CP_Mage, "Fire")
local CP_Frost = CreateChildPanel(CP_Mage, "Frost")

-- Controls
-- Mage
CreateARPanelOptions(CP_Mage, "APL.Mage.Commons")
CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTemporalWarp", "Suggest Time Warp with Temporal Warp", "Show Time Warp when the Temporal Warp talent is selected.")

-- Arcane
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range or on the left icon.")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MovingRotation", "Disable cast abilities when moving", "While moving, don't show abilities where a cast time is needed (makes the rotation a bit clunky with small steps).")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MirrorImagesBeforePull", "Use Mirror Images Precombat", "Enable this option to show Mirror Images during Precombat.")
CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane")

-- Fire
CreateARPanelOptions(CP_Fire, "APL.Mage.Fire")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.StayDistance", "Stay at distance", "Only use Arcane Explosion/Dragon's Breath if in range or on the left icon.")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.ShowFireBlastLeft", "Show Fire Blast on left icon while casting", "Show Fire Blast on left icon while casting")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.ShowPyroblastLeft", "Show Free Pyroblast on left icon", "Show free Pyroblast casts on left icon while casting")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat.")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.MovingRotation", "Disable abilities with cast time when moving", "Don't show abilities with a cast time while moving (makes the rotation a bit clunky with small steps).")

-- Frost
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range. If out of range, display it on the left icon.")
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.MovingRotation", "Disable non-instant casts while moving", "Don't show abilities where a cast is needed (makes the rotation a bit clunky with small steps).")
CreateARPanelOptions(CP_Frost, "APL.Mage.Frost")
