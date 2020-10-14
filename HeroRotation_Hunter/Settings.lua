--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroRotation
local HR = HeroRotation;
-- HeroLib
local HL = HeroLib;
-- File Locals
local GUI = HL.GUI;
local CreateChildPanel = GUI.CreateChildPanel;
local CreatePanelOption = GUI.CreatePanelOption;
local CreateARPanelOption = HR.GUI.CreateARPanelOption;
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions;

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Hunter = {
  Commons = {
    CounterShot = false,
    UseTrinkets = true,
    UsePotions = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    ExhilarationHP = 30,
    SummonPetSlot = 1,
    -- SoloMode Settings
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Exhilaration = true,
      WildSpirits = false,
      TarTrap = false,
      Flare = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      CounterShot = true,
    }
  },
  BeastMastery = {
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      AMurderofCrows = false,
      AspectoftheWild = false,
      BestialWrath = false,
      SummonPet = false,
      SpittingCobra = false,
      Stampede = false,
      Bloodshed = false,
      RevivePet = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
      -- Racials
    }
  },
  Marksmanship = {
    UseLoneWolf = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      SummonPet = false,
      AMurderofCrows = false,
      Trueshot = false,
      HuntersMark = false,
      Volley = false,
      DoubleTap = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
      -- Racials
    }
  },
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Hunter = CreateChildPanel(ARPanel, "Hunter");
local CP_BeastMastery = CreateChildPanel(CP_Hunter, "BeastMastery");
local CP_Marksmanship = CreateChildPanel(CP_Hunter, "Marksmanship");

-- Hunter
CreatePanelOption("Dropdown", CP_Hunter, "APL.Hunter.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Hunter, "APL.Hunter.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Covenant Display Style (WIP)", "Define which icon display style to use for active Covenant Abilities.");
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.CounterShot", "Counter Shot to Interrupt", "Enable this to show Counter Shot to interrupt enemies.");
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.SummonPetSlot", {1, 5, 1}, "Summon Pet Slot", "Which pet stable slot to suggest when summoning a pet. Visual only.");
CreateARPanelOptions(CP_Hunter, "APL.Hunter.Commons");

-- Beast Mastery
CreateARPanelOptions(CP_BeastMastery, "APL.Hunter.BeastMastery");

-- Marksmanship
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.UseLoneWolf", "Use Lone Wolf", "Enable this if you want to use Lone Wolf and not be notified to summon a pet.");
CreateARPanelOptions(CP_Marksmanship, "APL.Hunter.Marksmanship");
