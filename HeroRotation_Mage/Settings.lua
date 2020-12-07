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
HR.GUISettings.APL.Mage = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      TimeWarp = false,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Trinkets = "Suggested",
      Covenant = "Suggested",
    },
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Racials
      Racials = true,
      -- Abilities
      TimeWarp = true,
      Counterspell = true,
    }
  },
  Frost = {
    MirrorImagesBeforePull = false,
    MovingRotation = false,
    UseTemporalWarp = true,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
      IcyVeins = true,
      MirrorImage = true,
      FrozenOrb = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      IceFloes = true,
    }
  },
  Fire = {
    DisableCombustion = false,
    MirrorImagesBeforePull = false,
    MovingRotation = false,
    UseTemporalWarp = true,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      Combustion = true,
    }
  },
  Arcane = {
    Enabled={
      UseManaGem = true,
    },
    AMSpamRotation = false,
    StayDistance = false,
    UseTemporalWarp = true,
    MovingRotation = false,
    MirrorImagesBeforePull = false,
    -- {Display GCD as OffGCD}
    GCDasOffGCD = {
      -- Abilities
      RuneOfPower = true,
      ArcanePower = true,
      MirrorImage = true,
      TouchOfTheMagi = true,
      Evocation = true,
    },
    -- {Display OffGCD as OffGCD}
    OffGCDasOffGCD = {
      -- Abilities
      PresenceOfMind = true,
    }
  }
};

HR.GUI.LoadSettingsRecursively(HR.GUISettings);

-- Child Panels
local ARPanel = HR.GUI.Panel;
local CP_Mage = CreateChildPanel(ARPanel, "Mage");
local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane");
local CP_Fire = CreateChildPanel(CP_Mage, "Fire");
local CP_Frost = CreateChildPanel(CP_Mage, "Frost");

-- Controls
-- Mage
CreateARPanelOptions(CP_Mage, "APL.Mage.Commons");
-- Arcane
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.AMSpamRotation", "Use AM spam rotation", "Enable the use of the Arcane Missile Spam rotation.");
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat (very low dps).");
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.StayDistance", "Stay at distance", "Only use Arcane Explosion if in range or on the left icon.");
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.MovingRotation", "Disable cast abilities when moving", "Don't show abilities where a ca&st is needed (makes the rotation a bit clunky with small steps).");
CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.UseTemporalWarp", "Suggest Time Warp with Temporal Warp legendary", "Show time warp ability when using the Temporal Warp legendary");
CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane");
-- Fire
CreateARPanelOptions(CP_Fire, "APL.Mage.Fire");
-- Frost
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.MirrorImagesBeforePull", "Use Mirror Image before combat", "Enable the use of Mirror image before starting combat (very low dps).");
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.MovingRotation", "Disable cast abilities when moving", "Don't show abilities where a ca&st is needed (makes the rotation a bit clunky with small steps).");
CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Frost.UseTemporalWarp", "Suggest Time Warp with Temporal Warp legendary", "Show time warp ability when using the Temporal Warp legendary");
CreateARPanelOptions(CP_Frost, "APL.Mage.Frost");
