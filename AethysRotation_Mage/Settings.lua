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
  AR.GUISettings.APL.Mage = {
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
    Frost = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities

      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        IcyVeins = {true, false},
        -- Abilities

      }
    },
    Fire = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        -- Abilities
        Combustion = {true, false},
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Mage = CreateChildPanel(ARPanel, "Mage");
  --local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane");
  local CP_Fire = CreateChildPanel(CP_Mage, "Fire");
  local CP_Frost = CreateChildPanel(CP_Mage, "Frost");
  -- Controls
  -- Mage
  CreateARPanelOption("OffGCDasOffGCD", CP_Mage, "APL.Mage.Commons.OffGCDasOffGCD.Racials", "Racials");
  -- Arcane
  -- Fire
  CreateARPanelOption("OffGCDasOffGCD", CP_Fire, "APL.Mage.Fire.OffGCDasOffGCD.Combustion", "Combustion");
  -- Frost
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.Mage.Frost.OffGCDasOffGCD.IcyVeins", "Icy Veins");
