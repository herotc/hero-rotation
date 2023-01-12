--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
--File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.DeathKnight = {
  Commons = {
    UseDeathStrikeHP = 60, -- % HP threshold to try to heal with Death Strike
    UseDarkSuccorHP = 80, -- % HP threshold to use Dark Succor's free Death Strike
    UseAMSAMZOffensively = false,
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Signature = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
      RaiseDead = "Suggested",
    },
  },
  Commons2 = {
    GCDasOffGCD = {
      AbominationLimb = false,
      AntiMagicShell = true,
      AntiMagicZone = true,
      DeathAndDecay = false,
      EmpowerRuneWeapon = true,
      SacrificialPact = true
    },
    OffGCDasOffGCD = {
      MindFreeze = true,
      Racials = true,
    }
  },
  Blood = {
    RuneTapThreshold = 40,
    IceboundFortitudeThreshold = 50,
    VampiricBloodThreshold = 65,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Consumption = "Suggested",
    },
    PoolDuringBlooddrinker = false,
    GCDasOffGCD = {
      Bonestorm = false,
      ChainsOfIce = false,
      DancingRuneWeapon = false,
      DeathStrike = false,
      IceboundFortitude = false,
      Tombstone = false,
      VampiricBlood = false,
    },
    OffGCDasOffGCD = {
      BloodTap = true,
      RuneTap = true,
    },
  },
  Frost = {
    DisableBoSPooling = false,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      BoS = "Suggested",
    },
    GCDasOffGCD = {
      -- Abilities
      BreathOfSindragosa = true,
      FrostStrike = false,
      FrostwyrmsFury = true,
      HornOfWinter = true,
      HypothermicPresence = true,
      PillarOfFrost = true,
    }
  },
  Unholy = {
    DisableAotD = false,
    RaiseDeadCastLeft = false,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      ArmyOfTheDead = "SuggestedRight",
    },
    GCDasOffGCD = {
      -- Abilities
      Apocalypse = false,
      DarkTransformation = true,
      Epidemic = false,
      SummonGargoyle = false,
      UnholyAssault = true,
      UnholyBlight = false,
      VileContagion = false,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)
-- Panels
local ARPanel = HR.GUI.Panel
local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight")
local CP_Deathknight2 = CreateChildPanel(CP_Deathknight, "DeathKnight 2")
local CP_Blood = CreateChildPanel(CP_Deathknight, "Blood")
local CP_Frost = CreateChildPanel(CP_Deathknight, "Frost")
local CP_Unholy = CreateChildPanel(CP_Deathknight, "Unholy")

--DeathKnight Panels
CreatePanelOption("Slider", CP_Deathknight, "APL.DeathKnight.Commons.UseDeathStrikeHP", { 1, 100, 1 }, "Use Death Strike on Low HP", "Set the HP threshold to use Death Strike (working only if Solo Mode is enabled).")
CreatePanelOption("Slider", CP_Deathknight, "APL.DeathKnight.Commons.UseDarkSuccorHP", { 1, 100, 1 }, "Use Death Strike to Consume Dark Succor", "Set the HP threshold to use Death Strike to Consume Dark Succor (working only if Solo Mode is enabled).")
CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UseAMSAMZOffensively", "Use AMS/AMZ Offensively", "Enable this option to allow AMS/AMZ to be suggested for Runic Power generation purposes.")
CreateARPanelOptions(CP_Deathknight, "APL.DeathKnight.Commons")

--DeathKnight2 Panel
CreateARPanelOptions(CP_Deathknight2, "APL.DeathKnight.Commons2")

--Blood Panels
CreatePanelOption("CheckButton", CP_Blood, "APL.DeathKnight.Blood.PoolDuringBlooddrinker", "Show Pool During Blooddrinker", "Display the 'Pool' icon whenever you're channeling Blooddrinker as long as you shouldn't interrupt it.")
CreatePanelOption("Slider", CP_Blood, "APL.DeathKnight.Blood.RuneTapThreshold", {5, 100, 5}, "Rune Tap Health Threshold", "Suggest Rune Tap when below this health percentage.")
CreatePanelOption("Slider", CP_Blood, "APL.DeathKnight.Blood.IceboundFortitudeThreshold", {5, 100, 5}, "Icebound Fortitude Health Threshold", "Suggest Icebound Fortitude when below this health percentage.")
CreatePanelOption("Slider", CP_Blood, "APL.DeathKnight.Blood.VampiricBloodThreshold", {5, 100, 5}, "Vampiric Blood Health Threshold", "Suggest Vampiric Blood when below this health percentage.")
CreateARPanelOptions(CP_Blood, "APL.DeathKnight.Blood")

--Frost Panels
CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Frost.DisableBoSPooling", "Disable BoS Pooling", "Enable this option to bypass the BoS Pooling function.")
CreateARPanelOptions(CP_Frost, "APL.DeathKnight.Frost")

--Unholy Panels
CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.DisableAotD", "Disable AotD", "Disable Army of the Dead suggestions.")
CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.RaiseDeadCastLeft", "Raise Dead in CastLeft", "Enable this to ignore the Raise Dead DisplayStyle option and instead use CastLeft.")
CreateARPanelOptions(CP_Unholy, "APL.DeathKnight.Unholy")
