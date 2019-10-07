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
    UseDeathStrikeHP = 60, -- % HP threshold to try to heal with Deathstrikes
    UsePotions = true,
    UseTrinkets = true,
    TrinketDisplayStyle = "Suggested",
    EssenceDisplayStyle = "Suggested",
    OffGCDasOffGCD = {
      Trinkets = true,
      Potions = true,
      Racials = true,
      MindFreeze = true,
    }
  },
  Frost = {
    DisableBoSPooling = false,
    BoSDisplayStyle = "Suggested",
    GCDasOffGCD = {
      -- Abilities
      HornofWinter = true,
      FrostwyrmsFury = true,
      PillarofFrost = true,
      EmpowerRuneWeapon = true,
      BreathofSindragosa = true,
    },
  },
  Unholy = {
    AotDOff = true,
    GCDasOffGCD = {
      -- Abilities
      DarkTransformation = true,
      ArmyoftheDead = true,
      DeathandDecay = false,
      UnholyFrenzy = true,
    }
  },
  Blood = {
    ConsumptionDisplayStyle = "Suggested",
    PoolDuringBlooddrinker = false,
    GCDasOffGCD = {
      -- Abilities
      Blooddrinker = true,
      Bonestorm = true,
      Tombstone = true
    },
    OffGCDasOffGCD = {
      DancingRuneWeapon = true
    }
  }
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);
-- Panels
local ARPanel = HR.GUI.Panel;
local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight");
local CP_Unholy = CreateChildPanel(CP_Deathknight, "Unholy");
local CP_Frost = CreateChildPanel(CP_Deathknight, "Frost");
local CP_Blood = CreateChildPanel(CP_Deathknight, "Blood");

--DeathKnight Panels
CreatePanelOption("Slider", CP_Deathknight, "APL.DeathKnight.Commons.UseDeathStrikeHP", { 1, 100, 1 }, "Use Deathstrike on low HP", "Set the HP threshold to use DeathStrike (working only if Solo Mode is enabled).");
CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UsePotions", "Use Potions", "Use Potions as part of the rotation");
CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Deathknight, "APL.DeathKnight.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Deathknight, "APL.DeathKnight.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");
CreateARPanelOptions(CP_Deathknight, "APL.DeathKnight.Commons");

--Unholy Panels
CreatePanelOption("CheckButton", CP_Unholy, "APL.DeathKnight.Unholy.AotDOff", "Disable AotD Checks", "Enable this option to remove ability checks against Army of the Dead. This can help smooth out the rotation if not using Army on cooldown.");
CreateARPanelOptions(CP_Unholy, "APL.DeathKnight.Unholy");

--Frost Panels
CreatePanelOption("CheckButton", CP_Frost, "APL.DeathKnight.Frost.DisableBoSPooling", "Disable BoS Pooling", "Enable this option to bypass the BoS Pooling function.");
CreatePanelOption("Dropdown", CP_Frost, "APL.DeathKnight.Frost.BoSDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Breath of Sindragosa Display Style", "Define which icon display style to use for active Breath of Sindragosa.");
CreateARPanelOptions(CP_Frost, "APL.DeathKnight.Frost");

--Blood Panels
CreatePanelOption("Dropdown", CP_Blood, "APL.DeathKnight.Blood.ConsumptionDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Consumption Display Style", "Define which icon display style to use for Consumption.");
CreatePanelOption("CheckButton", CP_Blood, "APL.DeathKnight.Blood.PoolDuringBlooddrinker", "Pool: Blooddrinker", "Display the 'Pool' icon whenever you're channeling Blooddrinker as long as you shouldn't interrupt it (supports Quaking).");
CreateARPanelOptions(CP_Blood, "APL.DeathKnight.Blood");
