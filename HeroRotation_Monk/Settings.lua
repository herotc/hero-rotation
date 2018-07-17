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
  HR.GUISettings.APL.Monk = {
    Commons = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities

      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = true,
        -- Abilities

      }
    },
    Brewmaster = {
      -- Purify
      Purify = {
        Enabled = true,
        Low = false,
        Medium = true,
        High = true
      },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials

        -- Abilities
        InvokeNiuzaotheBlackOx = true,
        BlackOxBrew            = true,
        IronskinBrew           = true,
        PurifyingBrew          = true,
      }
    },
    Windwalker = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        TouchOfDeath = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials

        -- Abilities
        Serenity = true,
      }
    }
  };
  HR.GUI.LoadSettingsRecursively(HR.GUISettings);
  
  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Monk = CreateChildPanel(ARPanel, "Monk");
  local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker");
  local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster");
  -- Monk
  CreateARPanelOptions(CP_Monk, "APL.Monk.Commons");
  -- Windwalker
  CreateARPanelOptions(CP_Windwalker, "APL.Monk.Windwalker");
  -- Windwalker
  CreateARPanelOptions(CP_Brewmaster, "APL.Monk.Brewmaster");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Enabled", "Purify", "Enable or disable Purify recommendations.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Low", "Purify: Low", "Enable or disable Purify recommendations when the stagger is low.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Medium", "Purify: Medium", "Enable or disable Purify recommendations when the stagger is medium.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.High", "Purify: High", "Enable or disable Purify recommendations when the stagger is high.");
