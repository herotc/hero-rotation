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
  HR.GUISettings.APL.Druid = {
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
    Balance = {
      BarkSkinHP = 10,
      ShowPoPP = false,
      ShowMFOOP = true,
      Sephuz = {
        SolarBeam = false,
        Typhoon = false,
        MightyBash = false,
        MassEntanglement = false,
        EntanglingRoots = false,
      },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        MoonkinForm = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        BlessingofElune = true,
        BlessingofAnshe = true,
        AstralCommunion = true,
        IncarnationChosenOfElune = true,
        CelestialAlignment = true,
        WarriorofElune = true,
        ForceofNature = true,
        BarkSkin = true,
        Sephuz = true,
      }
    },
    Feral = {
      RegrowthHP = 0,
      RenewalHP = 0,
      SurvivalInstinctsHP = 0,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        CatForm = true,
        -- RegrowthHeal = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        --Abilities
        -- Renewal = true,
        -- SurvivalInstincts = true,
        Prowl = true,
        -- ElunesGuidance = true,
        WildCharge = true,
        TigersFury = true,
        Berserk = true,
        Incarnation = true,
      },
      StealthMacro = {
        -- Abilities
        -- Shadowmeld = true,
        -- JungleStalker = true,
      }
    },
    Guardian = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
  };

    HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Druid = CreateChildPanel(ARPanel, "Druid");
  local CP_Balance = CreateChildPanel(CP_Druid, "Balance");
  local CP_Feral = CreateChildPanel(CP_Druid, "Feral");
  -- local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian");

  CreateARPanelOptions(CP_Druid, "APL.Druid.Commons");
  --Feral
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RegrowthHP", {0, 100, 1}, "Regrowth HP", "Set the Regrowth HP threshold.");
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.");
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts HP", "Set the Survival Instincts HP threshold.");
  CreateARPanelOptions(CP_Feral, "APL.Druid.Feral");
  -- CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)");
  -- CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.StealthMacro.JungleStalker", "Stealth Combo - Jungle Stalker", "Allow suggesting Jungle Stalker stealth ability combos (recommended)");
  --Balance
  CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkSkinHP", {0, 100, 1}, "BarkSkin HP", "Set the BarkSkin HP threshold.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMFOOP", "Show Moonkin Form Out of Combat", "Enable this if you want the addon to show you the Moonkin Form reminder out of combat.");
  CreateARPanelOptions(CP_Balance, "APL.Druid.Balance");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want the addon to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.SolarBeam", "Sephuz: Show Solar Beam", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.EntanglingRoots", "Sephuz: Show Entangling Roots", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MightyBash", "Sephuz: Show Mighty Bash", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MassEntanglement", "Sephuz: Show Mass Entanglement", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.Typhoon", "Sephuz: Show Typhoon", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.Sephuz", "Skills to proc Sephuz");

