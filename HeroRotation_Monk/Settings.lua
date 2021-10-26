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
HR.GUISettings.APL.Monk = {
  Commons = {
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      LegSweep = true,
      RingOfPeace = true,
      Paralysis = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      SpearHandStrike = true,
    }
  },
  Brewmaster = {
    -- Do not pool, this option only exists because people keep nagging me about it
    NoBrewmasterPooling = false,
    -- Show Celestial Brew as a cooldown
    ShowCelestialBrewCD = true,
    -- Show Dampen Harm as a cooldown
    ShowDampenHarmCD = true,
    -- Purify
    Purify = {
      Enabled = true,
      Low = true,
      Medium = true,
      High = true
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      CelestialBrew          = true,
      DampenHarm             = true,
      FortifyingBrew         = true,
      InvokeNiuzaoTheBlackOx = true,
      TouchOfDeath           = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      BlackOxBrew            = true,
      PurifyingBrew          = true,
    }
  },
  Windwalker = {
  -- Do not pool, this option only exists because people keep nagging me about it
    ShowFortifyingBrewCD = false,
    NoWindwalkerPooling = false,
    IgnoreToK = false,
    IgnoreFSK = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      InvokeXuenTheWhiteTiger = true,
      TouchOfDeath            = true,
      TouchOfKarma            = true,
      FortifyingBrew          = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      EnergizingElixir        = true,
      Serenity                = true,
      StormEarthAndFire       = true,
    }
  },
  Mistweaver = {
  -- Do not pool, this option only exists because people keep nagging me about it
    ShowFortifyingBrewCD = false,
    NoMistweaverPooling = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      InvokeYulonTheJadeSerpent = true,
      InvokeChiJiTheRedCrane    = true,
      SummonJadeSerpentStatue   = true,
      RenewingMist              = true,
      TouchOfDeath              = true,
      FortifyingBrew            = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      -- Abilities
      ThunderFocusTea         = true,
    }
  }
};
HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Monk = CreateChildPanel(ARPanel, "Monk")
local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker")
local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster")
local CP_Mistweaver = CreateChildPanel(CP_Monk, "Mistweaver")
-- Monk
CreateARPanelOptions(CP_Monk, "APL.Monk.Commons")
CreatePanelOption("CheckButton", CP_Monk, "APL.Monk.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.")
CreatePanelOption("CheckButton", CP_Monk, "APL.Monk.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Monk, "APL.Monk.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Monk, "APL.Monk.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for active Shadowlands Covenant Abilities.")

-- Windwalker
CreateARPanelOptions(CP_Windwalker, "APL.Monk.Windwalker")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.ShowFortifyingBrewCD", "Fortifying Brew", "Enable or disable Fortifying Brew recommendations.")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreToK", "Ignore Touch of Karma", "Enable this setting to allow you to ignore Touch of Karma without stalling the rotation. (NOTE: Touch of Karma will never be suggested if this is enabled)")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.IgnoreFSK", "Ignore Flying Serpent Kick", "Enable this setting to allow you to ignore Flying Serpent Kick without stalling the rotation. (NOTE: Flying Serpent Kick will never be suggested if this is enabled)")
CreatePanelOption("CheckButton", CP_Windwalker, "APL.Monk.Windwalker.NoWindwalkerPooling", "No Pooling", "If you want to ignore energy pooling.")

-- Brewmaster
CreateARPanelOptions(CP_Brewmaster, "APL.Monk.Brewmaster")
CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.NoBrewmasterPooling", "No Pooling", "If you want to ignore energy pooling.")
CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.ShowCelestialBrewCD", "Celestial Brew", "Enable or disable Celestial Brew recommendations.")
CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.ShowDampenHarmCD", "Dampen Harm", "Enable or disable Dampen Harmrecommendations.")
CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Enabled", "Purify", "Enable or disable Purify recommendations.")
--CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Low", "Purify: Low", "Enable or disable Purify recommendations when the stagger is low.")
--CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Medium", "Purify: Medium", "Enable or disable Purify recommendations when the stagger is medium.")
--CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.High", "Purify: High", "Enable or disable Purify recommendations when the stagger is high.")

-- Mistweaver
CreateARPanelOptions(CP_Mistweaver, "APL.Monk.Mistweaver")
