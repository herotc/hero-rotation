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
      UseTimeWarp = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = {true, false},
        -- Abilities
        TimeWarp = {true, false}
      }
    },
    Frost = {
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        RuneofPower = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        IcyVeins = {true, false},
        MirrorImage = {true, false},
        IceFloes = {true, false}
      }
    },
    Fire = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Combustion = {true, false}
      }
    },
    Arcane = {
      ShowPoDG = false,
      Sephuz = {
        Counterspell = false,
        SpellSteal = false,
        Polymorph = false
      },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        ArcanePower = {true, false},
        PresenceofMind = {true, false},
        RuneofPower = {true, false}
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Mage = CreateChildPanel(ARPanel, "Mage");
  local CP_Arcane = CreateChildPanel(CP_Mage, "Arcane");
  local CP_Fire = CreateChildPanel(CP_Mage, "Fire");
  local CP_Frost = CreateChildPanel(CP_Mage, "Frost");
  
  -- Controls
  -- Mage
  CreateARPanelOption("OffGCDasOffGCD", CP_Mage, "APL.Mage.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTimeWarp", "Use Time Warp", "Enable this if you want the addon to show you when to use Time Warp.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Mage, "APL.Mage.Commons.OffGCDasOffGCD.TimeWarp", "Time Warp");
  -- Arcane
  CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.ShowPoDG", "Show Potion of Deadly Grace", "Enable this if you want the addon to show you when to use Potion of Deadly Grace");
  CreateARPanelOption("OffGCDasOffGCD", CP_Arcane, "APL.Mage.Arcane.OffGCDasOffGCD.ArcanePower", "Arcane Power");
  CreateARPanelOption("OffGCDasOffGCD", CP_Arcane, "APL.Mage.Arcane.OffGCDasOffGCD.PresenceofMind", "Presence of Mind");
  CreateARPanelOption("OffGCDasOffGCD", CP_Arcane, "APL.Mage.Arcane.OffGCDasOffGCD.RuneofPower", "Rune of Power");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.Counterspell", "Sephuz: Show Counterspell", "Enable this if you want the addon to show you when to use Counterspell to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.SpellSteal", "Sephuz: Show Spell Steal", "Enable this if you want the addon to show you when to use Spell Steal to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.Polymorph", "Sephuz: Show Polymorph", "Enable this if you want it to show you when to use Polymorph to proc Sephuz's Secret (only when equipped).");
  -- Fire
  CreateARPanelOption("OffGCDasOffGCD", CP_Fire, "APL.Mage.Fire.OffGCDasOffGCD.Combustion", "Combustion");
  -- Frost
    CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Arcane.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want the addon to show you when to use Potion of Prolonged Power");

  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.Mage.Frost.OffGCDasOffGCD.IcyVeins", "Icy Veins");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.Mage.Frost.GCDasOffGCD.RuneofPower", "Rune of Power");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.Mage.Frost.OffGCDasOffGCD.MirrorImage", "Mirror Image");
  CreateARPanelOption("OffGCDasOffGCD", CP_Frost, "APL.Mage.Frost.OffGCDasOffGCD.IceFloes", "Ice Floes");
