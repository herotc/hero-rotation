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
HR.GUISettings.APL.Warlock = {
  Commons = {
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
    HidePetSummon = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Racials = true,
      SpellLock = true,
    }
  },
  Destruction = {
    IgnoreSTHavoc = false,
    PotionType = {
      Selected = "Power",
    },
    --UnendingResolveHP = 20,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Cataclysm = false,
      GrimoireOfSacrifice = true,
      InquisitorsGaze = false,
      SummonInfernal = true,
      SummonPet = false,
      SummonSoulkeeper = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    }
  },
  Demonology = {
    PotionType = {
      Selected = "Power",
    },
    UnendingResolveHP = 20,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      SummonPet = false,
      GrimoireFelguard = false,
      SummonDemonicTyrant = false,
      DemonicStrength = false,
      NetherPortal = true,
      Implosion = false,
      InquisitorsGaze = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      UnendingResolve = true,
      AxeToss = true,
    }
  },
  Affliction = {
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      GrimoireOfSacrifice = true,
      PhantomSingularity = true,
      SoulTap = true,
      SummonDarkglare = true,
      SummonPet = false,
      InquisitorsGaze = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Warlock = CreateChildPanel(ARPanel, "Warlock")
local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology")
local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction")
local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction")

-- Warlock
CreateARPanelOptions(CP_Warlock, "APL.Warlock.Commons")

-- Destruction
CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.IgnoreSTHavoc", "Ignore Havoc in Single Target", "Enable this option to not receive suggestions to use Havoc while in single target combat.")
CreateARPanelOptions(CP_Destruction, "APL.Warlock.Destruction")

-- Demonology
CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.")
CreateARPanelOptions(CP_Demonology, "APL.Warlock.Demonology")

-- Affliction
CreateARPanelOptions(CP_Affliction, "APL.Warlock.Affliction")
