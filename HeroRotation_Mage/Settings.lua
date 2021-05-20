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
    Enabled = {
      Potions = true,
      Trinkets = true,
      TimeWarp = false,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Covenant = "Suggested",
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
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
    UseTemporalWarp = true,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
      IcyVeins = true,
      FrozenOrb = true,
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
    UseTemporalWarp = true,
    StayDistance = true,
    ShowFireBlastLeft = true,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      Combustion = true,
    }
  },
  Arcane = {
    Enabled={
      UseManaGem = true,
    },
    AMSpamRotation = false,
    StayDistance = false,
    UseTemporalWarp = true,
    MovingRotation = false,
    MirrorImagesBeforePull = false,
    UseFishingOpener = false,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
      ArcanePower = true,
      MirrorImage = true,
      TouchOfTheMagi = true,
      Evocation = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
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

-- Arcane
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.AMSpamRotation", "Use AM spam rotation", "Enable the use of the Arcane Missile Spam rotation.")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.UseFishingOpener", "Use Fishing Opener", "The fishing opener begins with RoP and fishes for CC procs to use during TotM/AP.")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat (very low dps).")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range or on the left icon.")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MovingRotation", "Disable cast abilities when moving", "Don't show abilities where a ca&st is needed (makes the rotation a bit clunky with small steps).")
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.UseTemporalWarp", "Suggest Time Warp with Temporal Warp legendary", "Show time warp ability when using the Temporal Warp legendary")
CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane")

-- Fire
CreateARPanelOptions(CP_Fire, "APL.Mage.Fire")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.StayDistance", "Stay at distance", "Only use Arcane Explosion/Dragon's Breath if in range or on the left icon.")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.ShowFireBlastLeft", "Show Fire Blast on left icon while casting", "Show Fire Blast on left icon while casting")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat (very low dps).")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.MovingRotation", "Disable cast abilities when moving", "Don't show abilities where a ca&st is needed (makes the rotation a bit clunky with small steps).")
CreatePanelOption("CheckButton", CP_Fire, "APL.Mage.Fire.UseTemporalWarp", "Suggest Time Warp with Temporal Warp legendary", "Show time warp ability when using the Temporal Warp legendary")

-- Frost
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range. If out of range, display it on the left icon.")
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.UseTemporalWarp", "Suggest Time Warp with Temporal Warp legendary", "Show time warp ability when using the Temporal Warp legendary")
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.MovingRotation", "Disable non-instant casts while moving", "Don't show abilities where a cast is needed (makes the rotation a bit clunky with small steps).")
CreateARPanelOptions(CP_Frost, "APL.Mage.Frost")
