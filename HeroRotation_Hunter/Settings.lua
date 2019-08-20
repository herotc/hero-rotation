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
    EssenceDisplayStyle = "Suggested",
    ExhilarationHP = 30,
    -- SoloMode Settings
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Exhilaration = true,
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
    UseSplashData = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      AMurderofCrows = false,
      AspectoftheWild = false,
      BestialWrath = false,
      SummonPet = false,
      SpittingCobra = false,
      Stampede = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
      -- Racials
    }
  },
  Marksmanship = {
    UseSplashData = true,
    UseLoneWolf = false,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      SummonPet = false,
      AMurderofCrows = false,
      Trueshot = false,
      HuntersMark = false,
      DoubleTap = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      -- Items
      -- Racials
    }
  },
  Survival = {
    AspectoftheEagle = true,
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      -- Abilities
      Butchery = false,
      SummonPet = false,
      CoordinatedAssault = true,
      Harpoon = true,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      -- Abilities
      AspectoftheEagle = true,
      Muzzle = true,
      -- Items
      -- Racials
    }
  }
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Hunter = CreateChildPanel(ARPanel, "Hunter");
local CP_BeastMastery = CreateChildPanel(CP_Hunter, "BeastMastery");
local CP_Marksmanship = CreateChildPanel(CP_Hunter, "Marksmanship");
local CP_Survival = CreateChildPanel(CP_Hunter, "Survival");

-- Hunter
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.CounterShot", "Counter Shot to Interrupt", "Enable this to show Counter Shot to interrupt enemies.");
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use Potions.");
CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
CreatePanelOption("Dropdown", CP_Hunter, "APL.Hunter.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
CreatePanelOption("Dropdown", CP_Hunter, "APL.Hunter.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");
CreatePanelOption("Slider", CP_Hunter, "APL.Hunter.Commons.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");

-- Beast Mastery
CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_BeastMastery, "APL.Hunter.BeastMastery");
CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.CounterShotSephuz", "Use Counter Shot for Sephuz", "Enable this if you want it to show you when to use Counter Shot to proc Sephuz's Secret (only when equipped). ");
CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.IntimidationShotSephuz", "Use Intimidation for Sephuz", "Enable this if you want it to show you when to use Intimidation to proc Sephuz's Secret (only when equipped). ");

-- Marksmanship
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities.");
CreateARPanelOptions(CP_Marksmanship, "APL.Hunter.Marksmanship");
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.UseLoneWolf", "Use Lone Wolf", "Enable this if you want to use Lone Wolf and not be notified to summon a pet.");
CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.EnableMovementRotation", "Enable Movement Rotation", "Enable this to show a special rotation while Moving. The optimal standing ability will be shown as a suggestion.");

-- -- Survival
CreatePanelOption("CheckButton", CP_Survival, "APL.Hunter.Survival.AspectoftheEagle", "Show Aspect of the Eagle", "Show Aspect of the Eagle when out of Melee Range.")
CreateARPanelOptions(CP_Survival, "APL.Hunter.Survival");