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
    },
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
      Covenant = "Suggested",
    },
    HidePetSummon = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      SpellLock = true,
    }
  },
  Destruction = {
    --UnendingResolveHP = 20,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      SummonPet = false,
      GrimoireOfSacrifice = true,
      SummonInfernal = true
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      DarkSoulInstability = true
    }
  },
  Demonology = {
    ImpsRequiredForImplosion = 6,
    SuppressLateTyrant = false,
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
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      UnendingResolve = true,
      AxeToss = true,
    }
  },
  Affliction = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      DarkSoul = true,
      SummonDarkglare = true,
      SummonPet = false,
      GrimoireOfSacrifice = true,
      PhantomSingularity = true,
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
--local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction")
local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology")
local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction")
local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction")

-- Warlock
CreateARPanelOptions(CP_Warlock, "APL.Warlock.Commons")
CreatePanelOption("CheckButton", CP_Warlock, "APL.Warlock.Commons.HidePetSummon", "Hide Pet Summon", "Enable this setting to hide suggestions for summoning your base pet. Rotational pets (Infernal, Darkglare, Tyrant, etc) will still be suggested.")

-- Destruction
--CreatePanelOption("Slider", CP_Destruction, "APL.Warlock.Destruction.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.")
--CreatePanelOption("Dropdown", CP_Destruction, "APL.Warlock.Destruction.SpellType", {"Auto","Orange","Green"}, "Spell icons", "Define what icons you want to appear.")
CreateARPanelOptions(CP_Destruction, "APL.Warlock.Destruction")

-- Demonology
CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.ImpsRequiredForImplosion", {3, 9, 1}, "Imps Required for Implosion", "Set the number of Imps required for Implosion.")
CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.")
CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.SuppressLateTyrant", "Suppress Late Tyrant Casts", "Enable this setting to suppress Demonic Tyrant cast suggestions due to the target dying soon. This could be useful for AoE scenarios or Mythic+ scenarios.")
CreateARPanelOptions(CP_Demonology, "APL.Warlock.Demonology")

-- Affliction
CreateARPanelOptions(CP_Affliction, "APL.Warlock.Affliction")
