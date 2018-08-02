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
      UseTimeWarp = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = true,
        -- Abilities
        TimeWarp = true,
      }
    },
    Frost = {
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        RuneofPower = true,
        IcyVeins = true,
        MirrorImage = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        IceFloes = true,
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
        Combustion = true,
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
        ArcanePower = true,
        PresenceofMind = true,
        RuneofPower = true,
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
  CreatePanelOption("CheckButton", CP_Mage, "APL.Mage.Commons.UseTimeWarp", "Use Time Warp", "Enable this if you want the addon to show you when to use Time Warp.");
  -- Arcane
  CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.ShowPoDG", "Show Potion of Deadly Grace", "Enable this if you want the addon to show you when to use Potion of Deadly Grace");
  CreateARPanelOptions(CP_Arcane, "APL.Mage.Arcane");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.Counterspell", "Sephuz: Show Counterspell", "Enable this if you want the addon to show you when to use Counterspell to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.SpellSteal", "Sephuz: Show Spell Steal", "Enable this if you want the addon to show you when to use Spell Steal to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Arcane, "APL.Mage.Arcane.Sephuz.Polymorph", "Sephuz: Show Polymorph", "Enable this if you want it to show you when to use Polymorph to proc Sephuz's Secret (only when equipped).");
  -- Fire
  CreateARPanelOptions(CP_Fire, "APL.Mage.Fire");
  -- Frost
  CreatePanelOption("CheckButton", CP_Frost, "APL.Mage.Arcane.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want the addon to show you when to use Potion of Prolonged Power");
  CreateARPanelOptions(CP_Frost, "APL.Mage.Frost");
