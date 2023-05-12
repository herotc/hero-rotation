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
HR.GUISettings.APL.Hunter = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    DisplayStyle = {
      Signature = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
    },
    GCDasOffGCD = {
    },
    OffGCDasOffGCD = {
      Racials = false,
    }
  },
  Commons2 = {
    SummonPetSlot = 1,
    ExhilarationHP = 20,
    MendPetHighHP = 40,
    MendPetLowHP = 80,
    GCDasOffGCD = {
      Exhilaration = true,
      ExplosiveShot = false,
      Flare = false,
      FreezingTrap = false,
      MendPet = false,
      RevivePet = false,
      Stampede = false,
      SteelTrap = false,
      SummonPet = false,
      TarTrap = false,
    },
    OffGCDasOffGCD = {
      CounterShot = true,
    }
  },
  BeastMastery = {
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      AMurderOfCrows = false,
      BestialWrath = false,
      Bloodshed = false,
      CallOfTheWild = false,
      DireBeast = false,
      WailingArrow = false,
    },
    OffGCDasOffGCD = {
      AspectOfTheWild = true,
    }
  },
  Marksmanship = {
    HideAimedWhileMoving = false,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      DoubleTap = false,
      Volley = false,
      WailingArrow = false,
    },
    OffGCDasOffGCD = {
      Salvo = true,
      Trueshot = true,
    }
  },
  Survival = {
    AspectOfTheEagle = true,
    CAKSMacro = false,
    PotionType = {
      Selected = "Power",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Butchery = false,
      CoordinatedAssault = true,
      Harpoon = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      AspectOfTheEagle = true,
      Muzzle = true,
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Hunter = CreateChildPanel(ARPanel, "Hunter")
local CP_Hunter2 = CreateChildPanel(ARPanel, "Hunter 2")
local CP_BeastMastery = CreateChildPanel(ARPanel, "BeastMastery")
local CP_Marksmanship = CreateChildPanel(ARPanel, "Marksmanship")
local CP_Survival = CreateChildPanel(ARPanel, "Survival")

-- Hunter
CreateARPanelOptions(CP_Hunter, "APL.Hunter.Commons")

-- Hunter 2
CreatePanelOption("Slider", CP_Hunter2, "APL.Hunter.Commons2.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold. Set to 0 to disable.")
CreatePanelOption("Slider", CP_Hunter2, "APL.Hunter.Commons2.MendPetHighHP", {0, 100, 1}, "Mend Pet High HP", "Set the Mend Pet HP High Priority (ASAP) threshold. Set to 0 to disable.")
CreatePanelOption("Slider", CP_Hunter2, "APL.Hunter.Commons2.MendPetLowHP", {0, 100, 1}, "Mend Pet Low HP", "Set the Mend Pet HP Low Priority (Pooling) threshold. Set to 0 to disable.")
CreatePanelOption("Slider", CP_Hunter2, "APL.Hunter.Commons2.SummonPetSlot", {1, 5, 1}, "Summon Pet Slot", "Which pet stable slot to suggest when summoning a pet.")
CreateARPanelOptions(CP_Hunter2, "APL.Hunter.Commons2")

-- Beast Mastery
CreateARPanelOptions(CP_BeastMastery, "APL.Hunter.BeastMastery")

-- Marksmanship
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.HideAimedWhileMoving", "Hide Moving Aimed Shot", "Enable this option to hide Aimed Shot while your character is moving.")
CreateARPanelOptions(CP_Marksmanship, "APL.Hunter.Marksmanship")

-- Survival
CreatePanelOption("CheckButton", CP_Survival, "APL.Hunter.Survival.AspectoftheEagle", "Show Aspect of the Eagle", "Show Aspect of the Eagle when out of Melee Range.")
CreatePanelOption("CheckButton", CP_Survival, "APL.Hunter.Survival.CAKSMacro", "Using Coordinated Assault Macro", "Enable this option to fix Kill Shot recommendations when you are using a Coordinated Assault/Kill Shot macro.")
CreateARPanelOptions(CP_Survival, "APL.Hunter.Survival")