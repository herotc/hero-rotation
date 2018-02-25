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
  local CreateARPanelOptions = AR.GUI.CreateARPanelOptions;

--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Hunter = {
    Commons = {
      MultiShotInMain = "Never",
      CounterShot = false,
      -- SoloMode Settings
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        -- Abilities
      }
    },
    BeastMastery = {
      ExhilarationHP = 30,
      ShowPoPP = false,
      CounterShotSephuz = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        AMurderofCrows = false,
        Volley = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        AspectoftheWild = true,
        BestialWrath = true,
        Exhilaration = true,
        TitansThunder = true,
        -- Items
        PotionOfProlongedPower = true,
        -- Racials
        Racials = true,
      }
    },
    Marksmanship = {
      ExhilarationHP = 30,
      ShowPoPP = false,
      CounterShotSephuz = false,
      EnableMovementRotation = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        AMurderofCrows = false,
        Volley = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Exhilaration = true,
        TrueShot = true,
        -- Items
        PotionOfProlongedPower = true,
        -- Racials
        Racials = true,
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
        AspectoftheEagle = true,
        Butchery = true,
        Exhilaration = true,
        SnakeHunter = true,
        -- Items
        PotionOfProlongedPower = true,
        -- Racials
        Racials = true,
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
  CreatePanelOption("CheckButton", CP_Hunter, "APL.Hunter.Commons.CounterShot", "Counter Shot to Interrupt", "Enable this to show Counter Shot to interrupt enemies.");
  -- Beast Mastery
  CreatePanelOption("Slider", CP_BeastMastery, "APL.Hunter.BeastMastery.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
  CreateARPanelOptions(CP_BeastMastery, "APL.Hunter.BeastMastery");
  CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_BeastMastery, "APL.Hunter.BeastMastery.CounterShotSephuz", "Use Counter Shot for Sephuz", "Enable this if you want it to show you when to use Counter Shot to proc Sephuz's Secret (only when equipped). ");
  -- Marksmanship
  CreatePanelOption("Slider", CP_Marksmanship, "APL.Hunter.Marksmanship.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
  CreateARPanelOptions(CP_Marksmanship, "APL.Hunter.Marksmanship");
  CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.CounterShotSephuz", "Use Counter Shot for Sephuz", "Enable this if you want it to show you when to use Counter Shot to proc Sephuz's Secret (only when equipped). ");
  CreatePanelOption("CheckButton", CP_Marksmanship, "APL.Hunter.Marksmanship.EnableMovementRotation", "Enable Movement Rotation", "Enable this to show a special rotation while Moving. The optimal standing ability will be shown as a suggestion.");
  -- -- Survival
  CreatePanelOption("Slider", CP_Survival, "APL.Hunter.Survival.ExhilarationHP", {0, 100, 1}, "Exhilaration HP", "Set the Exhilaration HP threshold.");
  CreateARPanelOptions(CP_Survival, "APL.Hunter.Survival");
