--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;
  -- AethysCore
  local AC = AethysCore;
  -- File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;

--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Hunter = {
    Commons = {
	  MultiShotInMain = "Never",
      -- SoloMode Settings
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        -- Abilities
        CounterShot = {true, false}
      }
    },
    BeastMastery = {
      ExhilarationHP = 30,
      ShowPoPP = false,
      UseSilence = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        AMurderofCrows = {false, false},
        Volley = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        AspectoftheWild = {true, false},
        BestialWrath = {true, false},
        Exhilaration = {true, false},
        TitansThunder = {true, false},
        -- Items
        PotionOfProlongedPower = {true, false},
        -- Racials
        Racials = {true, false},
      }
    },
    Marksmanship = {
      ExhilarationHP = 30,
      ShowPoPP = false,
      UseSilence = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        AMurderofCrows = {false, false},
        Volley = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Exhilaration = {true, false},
        TrueShot = {true, false},
        -- Items
        PotionOfProlongedPower = {true, false},
        -- Racials
        Racials = {true, false},
      }
    },
    Survival = {
      ExhilarationHP = 30,
      ShowPoPP = false,
      UseSilence = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        AspectoftheEagle = {true, false},
        Butchery = {true, false},
        Exhilaration = {true, false},
        SnakeHunter = {true, false},
        -- Items
        PotionOfProlongedPower = {true, false},
        -- Racials
        Racials = {true, false},
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Hunter = CreateChildPanel(ARPanel, "Hunter");
  local CP_BeastMastery = CreateChildPanel(CP_Hunter, "BeastMastery");
  local CP_Marksmanship = CreateChildPanel(CP_Hunter, "Marksmanship");
  local CP_Survival = CreateChildPanel(CP_Hunter, "Survival");
  -- Hunter
  CreatePanelOption("Dropdown", CP_Hunter, "APL.Hunter.Commons.MultiShotInMain", {"Never", "Only with Splash Data", "Always"}, "Multishot in the Main Icon", "When to show Multishot in the main icon or as a suggestion");
  -- Beast Mastery
  CreatePanelOption("Slider", CP_BeastMastery, "APL.Hunter.BeastMastery.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.GCDasOffGCD.AMurderofCrows", "AMurderofCrows");
  CreateARPanelOption("GCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.GCDasOffGCD.Volley", "Volley");
  CreateARPanelOption("OffGCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.OffGCDasOffGCD.AspectoftheWild", "Aspect of the Wild");
  CreateARPanelOption("OffGCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.OffGCDasOffGCD.BestialWrath", "Bestial Wrath");
  CreateARPanelOption("OffGCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.OffGCDasOffGCD.Exhilaration", "Exhilaration");
  CreateARPanelOption("OffGCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_BeastMastery, "APL.Hunter.BeastMastery.OffGCDasOffGCD.TitansThunder", "Titans Thunder");
  CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.UseCounterShot", "Use Counter Shot for Sephuz", "Enable this if you want it to show you when to use Counter Shot to proc Sephuz's Secret (only when equipped). ");
  -- Marksmanship
  CreatePanelOption("Slider", CP_Marksmanship, "APL.Hunter.Marksmanship.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_Marksmanship, "APL.Hunter.Marksmanship.GCDasOffGCD.AMurderofCrows", "AMurderofCrows");
  CreateARPanelOption("GCDasOffGCD", CP_Marksmanship, "APL.Hunter.Marksmanship.GCDasOffGCD.Volley", "Volley");
  CreateARPanelOption("OffGCDasOffGCD", CP_Marksmanship, "APL.Hunter.Marksmanship.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_Marksmanship, "APL.Hunter.Marksmanship.OffGCDasOffGCD.TrueShot", "TrueShot");
  CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.UseCounterShot", "Use Counter Shot for Sephuz", "Enable this if you want it to show you when to use Counter Shot to proc Sephuz's Secret (only when equipped). ");
  -- -- Survival
  CreatePanelOption("Slider", CP_Survival, "APL.Hunter.Survival.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
