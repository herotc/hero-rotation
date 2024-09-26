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
HR.GUISettings.APL.Evoker = {
  Commons = {
    EmpoweredFontSize = 36,
    DisintegrateFontSize = 22,
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
      Trinkets = "Suggested",
      -- Class Specific
      Defensives = "Suggested",
    },
  },
  CommonsOGCD = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      BlessingOfTheBronze = true,
      TipTheScales = true,
      Unravel = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      Quell = true,
    }
  },
  Augmentation = {
    MinOpenerDelay = 0,
    ShowBlisteringScales = true,
    ShowPrescience = true,
    DisplayStyle = {
      AugBuffs = "SuggestedRight",
    },
    PotionType = {
      Selected = "Tempered",
    },
    GCDasOffGCD = {
      BreathOfEons = true,
      DeepBreath = true,
      EbonMight = false,
      EmeraldBlossom = false,
      TimeSkip = true,
      VerdantEmbrace = false,
    },
  },
  Devastation = {
    ObsidianScalesThreshold = 60,
    ShowChainClip = true,
    UseDefensives = true,
    UseGreen = true,
    PotionType = {
      Selected = "Tempered",
    },
    GCDasOffGCD = {
      DeepBreath = true,
      Dragonrage = true,
    },
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Evoker = CreateChildPanel(ARPanel, "Evoker")
local CP_EvokerDS = CreateChildPanel(CP_Evoker, "Class DisplayStyles")
local CP_EvokerOGCD = CreateChildPanel(CP_Evoker, "Class OffGCDs")
local CP_Augmentation = CreateChildPanel(CP_Evoker, "Augmentation")
local CP_Devastation = CreateChildPanel(CP_Evoker, "Devastation")

-- Evoker
CreateARPanelOptions(CP_Evoker, "APL.Evoker.Commons")
CreatePanelOption("Slider", CP_Evoker, "APL.Evoker.Commons.EmpoweredFontSize", {1, 100, 1}, "Empowered Spell Font Size", "Select the font size to use for the overlay on your empowered spell casts (Fire Breath/Eternity Surge). This value scales with the addon's 'UI' scale.")
CreatePanelOption("Slider", CP_Evoker, "APL.Evoker.Commons.DisintegrateFontSize", {1, 100, 1}, "Other Annotated Spell Font Size", "Select the font size to use for the overlay on your spell casts that show 'CLIP', 'CHAIN', or 'NO CHAIN'. This value scales with the addon's 'UI' scale.")
CreateARPanelOptions(CP_EvokerDS, "APL.Evoker.CommonsDS")
CreateARPanelOptions(CP_EvokerOGCD, "APL.Evoker.CommonsOGCD")

-- Augmentation
CreateARPanelOptions(CP_Augmentation, "APL.Evoker.Augmentation")
CreatePanelOption("Slider", CP_Augmentation, "APL.Evoker.Augmentation.MinOpenerDelay", {0, 5, 1}, "Minimum Opener Delay", "Set this to the minimum number of seconds to delay during the opener. (Note: This will result in filler Living Flame or Azure Strike casts before continuing the rotation. Default: 0.)")
CreatePanelOption("CheckButton", CP_Augmentation, "APL.Evoker.Augmentation.ShowBlisteringScales", "Show Blistering Scales", "Enable this option to allow Blistering Scales suggestions. NOTE: This will only suggest Blistering Scales for the party/raid tank.")
CreatePanelOption("CheckButton", CP_Augmentation, "APL.Evoker.Augmentation.ShowPrescience", "Show Prescience", "Enable this option to show Prescience suggestions.")

-- Devastation
CreatePanelOption("CheckButton", CP_Devastation, "APL.Evoker.Devastation.UseDefensives", "Suggest Defensives", "Enable this option to have the addon suggest defensive spells.")
CreatePanelOption("CheckButton", CP_Devastation, "APL.Evoker.Devastation.UseGreen", "Suggest Green Spells", "Enable this option to have the addon suggest Green Evoker spells, as per the APL. Disable if you want to decide for yourself when to use them.")
CreatePanelOption("CheckButton", CP_Devastation, "APL.Evoker.Devastation.ShowChainClip", "Show Chain/Clip Suggestions", "Enable this option to have the addon overlay 'CLIP' and 'CHAIN' onto casts when Disintegrate should be clipped or chained. (Note: This is currently only for single target rotations.)")
CreatePanelOption("Slider", CP_Devastation, "APL.Evoker.Devastation.ObsidianScalesThreshold", {5, 100, 5}, "Obsidian Scales Threshold", "Suggest Obsidian Scales when below this health percentage.")
CreateARPanelOptions(CP_Devastation, "APL.Evoker.Devastation")
