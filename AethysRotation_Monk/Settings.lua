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
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials

        -- Abilities
        BlackOxBrew            = {true, false},
        InvokeNiuzaotheBlackOx = {true, false},
        IronskinBrew           = {true, false},
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
  -- Monk
  CreateARPanelOption("OffGCDasOffGCD", CP_Monk, "APL.Monk.Commons.OffGCDasOffGCD.Racials", "Racials");
  -- Windwalker
  CreateARPanelOption("GCDasOffGCD", CP_Windwalker, "APL.Monk.Windwalker.GCDasOffGCD.TouchOfDeath", "Touch of Death");
  CreateARPanelOption("OffGCDasOffGCD", CP_Windwalker, "APL.Monk.Windwalker.OffGCDasOffGCD.Serenity", "Storm, Earth and Fire / Serenity");
