--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroRotation
local HR = HeroRotation;
-- HeroLib
local HL = HeroLib;
--File Locals
local GUI = HL.GUI;
local CreateChildPanel = GUI.CreateChildPanel;
local CreatePanelOption = GUI.CreatePanelOption;
local CreateARPanelOption = HR.GUI.CreateARPanelOption;
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions;

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.DeathKnight = {
  Commons = {
    UseDeathStrikeHP = 60, -- % HP threshold to try to heal with Death Strike
    UseDarkSuccorHP = 80, -- % HP threshold to use Dark Succor's free Death Strike
    Enabled = {
      Potions = true,
      Trinkets = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Covenant = "Suggested",
      Trinkets = "Suggested",
      RaiseDead = "Suggested",
    },
    OffGCDasOffGCD = {
      Trinkets = true,
      Potions = true,
      Racials = true,
      MindFreeze = true,
      DeathAndDecay = false,
      SacrificialPact = true
    }
  },
  Blood = {
    DisplayStyle = {
      Consumption = "Suggested",
    },
    PoolDuringBlooddrinker = false,
    GCDasOffGCD = {
      DancingRuneWeapon = false,
      DeathStrike = false,
      IceboundFortitude = false,
      Tombstone = false,
      VampiricBlood = false,
    },
    OffGCDasOffGCD = {
      RuneTap = true,
    },
  },
  Frost = {
    DisableBoSPooling = false,
    DisplayStyle = {
      BoS = "Suggested",
    },
    GCDasOffGCD = {
      -- Abilities
      HornOfWinter = true,
      FrostwyrmsFury = true,
      PillarOfFrost = true,
      EmpowerRuneWeapon = true,
      HypothermicPresence = true,
      BreathofSindragosa = true
    }
  },
  Unholy = {
    RaiseDeadCastLeft = false,
    DisplayStyle = {
      ArmyoftheDead = "SuggestedRight",
    },
    GCDasOffGCD = {
      -- Abilities
      Apocalypse = false,
      DarkTransformation = true,
      Epidemic = false,
      SummonGargoyle = false,
      UnholyAssault = true,
    }
  },
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);
-- Panels
local ARPanel = HR.GUI.Panel;
local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight");
local CP_Unholy = CreateChildPanel(CP_Deathknight, "Unholy");
local CP_Frost = CreateChildPanel(CP_Deathknight, "Frost");
local CP_Blood = CreateChildPanel(CP_Deathknight, "Blood");

--DeathKnight Panels
CreatePanelOption("Slider", CP_Deathknight, "APL.DeathKnight.Commons.UseDeathStrikeHP", { 1, 100, 1 }, "Use Death Strike on Low HP", "Set the HP threshold to use Death Strike (working only if Solo Mode is enabled).");
CreatePanelOption("Slider", CP_Deathknight, "APL.DeathKnight.Commons.UseDarkSuccorHP", { 1, 100, 1 }, "Use Death Strike to Consume Dark Succor", "Set the HP threshold to use Death Strike to Consume Dark Succor (working only if Solo Mode is enabled).");
CreateARPanelOptions(CP_Deathknight, "APL.DeathKnight.Commons");

--Unholy Panels
CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.RaiseDeadCastLeft", "Raise Dead in CastLeft", "Enable this to ignore the Raise Dead DisplayStyle option and instead use CastLeft.");
CreateARPanelOptions(CP_Unholy, "APL.DeathKnight.Unholy");

--Frost Panels
CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Frost.DisableBoSPooling", "Disable BoS Pooling", "Enable this option to bypass the BoS Pooling function.");
CreateARPanelOptions(CP_Frost, "APL.DeathKnight.Frost");

--Blood Panels
CreatePanelOption("CheckButton", CP_Blood, "APL.DeathKnight.Blood.PoolDuringBlooddrinker", "Pool: Blooddrinker", "Display the 'Pool' icon whenever you're channeling Blooddrinker as long as you shouldn't interrupt it.");
CreateARPanelOptions(CP_Blood, "APL.DeathKnight.Blood");