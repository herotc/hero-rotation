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
  AR.GUISettings.APL.Monk = {
    Commons = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities

      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = {true, false}
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
        InvokeNiuzaotheBlackOx = {true, false},
        BlackOxBrew            = {true, false},
        IronskinBrew           = {true, false},
        PurifyingBrew          = {true, false}
      }
    },
    Windwalker = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        TouchOfDeath = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials

        -- Abilities
        Serenity = {true, false}
      }
    }
  };
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  
  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Monk = CreateChildPanel(ARPanel, "Monk");
  local CP_Windwalker = CreateChildPanel(CP_Monk, "Windwalker");
  local CP_Brewmaster = CreateChildPanel(CP_Monk, "Brewmaster");
  -- Monk
  CreateARPanelOption("OffGCDasOffGCD", CP_Monk, "APL.Monk.Commons.OffGCDasOffGCD.Racials", "Racials");
  -- Windwalker
  CreateARPanelOption("GCDasOffGCD", CP_Windwalker, "APL.Monk.Windwalker.GCDasOffGCD.TouchOfDeath", "Touch of Death");
  CreateARPanelOption("OffGCDasOffGCD", CP_Windwalker, "APL.Monk.Windwalker.OffGCDasOffGCD.Serenity", "Storm, Earth and Fire / Serenity");
  -- Windwalker
  CreateARPanelOption("OffGCDasOffGCD", CP_Brewmaster, "APL.Monk.Brewmaster.OffGCDasOffGCD.InvokeNiuzaotheBlackOx", "Invoke Niuzao the Black Ox");
  CreateARPanelOption("OffGCDasOffGCD", CP_Brewmaster, "APL.Monk.Brewmaster.OffGCDasOffGCD.BlackOxBrew", "Black Ox Brew");
  CreateARPanelOption("OffGCDasOffGCD", CP_Brewmaster, "APL.Monk.Brewmaster.OffGCDasOffGCD.IronskinBrew", "Ironskin Brew");
  CreateARPanelOption("OffGCDasOffGCD", CP_Brewmaster, "APL.Monk.Brewmaster.OffGCDasOffGCD.PurifyingBrew", "Purifying Brew");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Enabled", "Purify", "Enable or disable Purify recommendations.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Low", "Purify: Low", "Enable or disable Purify recommendations when the stagger is low.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.Medium", "Purify: Medium", "Enable or disable Purify recommendations when the stagger is medium.");
  CreatePanelOption("CheckButton", CP_Brewmaster, "APL.Monk.Brewmaster.Purify.High", "Purify: High", "Enable or disable Purify recommendations when the stagger is high.");
