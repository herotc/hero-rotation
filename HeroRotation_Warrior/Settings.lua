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
  -- Default settings
  HR.GUISettings.APL.Warrior = {
    Commons = {
      OffGCDasOffGCD = {
        Pummel = true,
        Racials = true,
        Avatar = true,
        BattleCry = true,
      }
    },

    Arms = {
      ShowPoPP = false,
      WarbreakerEnabled = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Warbreaker = false,
        Bladestorm = false,
        Ravager = false,
      },
      OffGCDasOffGCD = {
        -- Abilities
        FocusedRage = true,
        -- Items
      },
    },

    Fury = {
      ShowPoOW = false,
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Bladestorm = false,
        DragonRoar = false,
        Recklessness = false,
        Siegebreaker = false,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        -- Items
        PotionoftheOldWar = true,
        PotionOfProlongedPower = true,
        UmbralMoonglaives = true,
      }
    },

    Protection = {
      UseLastStandToFillShieldBlockDownTime = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        Avatar            = true,
        DemoralizingShout = true,
        IgnorePain        = true,
        LastStand         = true
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        ShieldBlock       = true,
      }
    },

  };

  HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Warrior = CreateChildPanel(ARPanel, "Warrior");
  local CP_Arms = CreateChildPanel(CP_Warrior, "Arms");
  local CP_Fury = CreateChildPanel(CP_Warrior, "Fury");
  local CP_Protection = CreateChildPanel(CP_Warrior, "Protection");

  -- Shared Warrior settings
  CreateARPanelOptions(CP_Warrior, "APL.Warrior.Commons");

  -- Arms settings
  CreateARPanelOptions(CP_Arms, "APL.Warrior.Arms");
  CreatePanelOption("CheckButton", CP_Arms, "APL.Warrior.Arms.WarbreakerEnabled", "Enable Warbreaker", "Disable this if you want to omit Warbreaker from the rotation.");
  CreatePanelOption("CheckButton", CP_Arms, "APL.Warrior.Arms.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");

  -- Fury settings
  CreateARPanelOptions(CP_Fury, "APL.Warrior.Fury");
  CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoOW", "Show Potion of the Old War", "Enable this if you want it to show you when to use Potion of the Old War.");
  CreatePanelOption("CheckButton", CP_Fury, "APL.Warrior.Fury.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");

  -- Protection settings
  CreateARPanelOptions(CP_Protection, "APL.Warrior.Protection");
  CreatePanelOption("CheckButton", CP_Protection, "APL.Warrior.Protection.UseLastStandToFillShieldBlockDownTime", "Use Last Stand to fill Shield Block down time", "Enable this if you want to fill Shield Block down time with Last Stand.");
