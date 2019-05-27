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
      UsePotions = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = true,
        -- Abilities
        SkullBash = true,
      }
    },
    Balance = {
      BarkskinHP = 50,
      RenewalHP = 40,
      ShowMoonkinFormOOC = true,
      ShowPotion = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        Barkskin = true,
        Renewal = true,
        MoonkinForm = true,
        CelestialAlignment = true, -- also does Incarnation!
        WarriorOfElune = true,
        ForceOfNature = true,
        FuryOfElune = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        SolarBeam = true
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
      BarkskinHP = 50,
      LunarBeamHP = 50,
      SurvivalInstinctsHP = 30,
      FrenziedRegenHP = 70,
      BristlingFurRage = 50,
      UseSplashData = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        FrenziedRegen = true,
        LunarBeam = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        Ironfur = true,
        Barkskin = true,
        SurvivalInstincts = true,
      }
    },
  };

    HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Druid = CreateChildPanel(ARPanel, "Druid");
  local CP_Balance = CreateChildPanel(CP_Druid, "Balance");
  local CP_Feral = CreateChildPanel(CP_Druid, "Feral");
  local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian");

  CreateARPanelOptions(CP_Druid, "APL.Druid.Commons");
  CreatePanelOption("CheckButton", CP_Druid, "APL.Druid.Commons.UsePotions", "Show Potions", "Enable this if you want the addon to show you when to use potions.");
  --Feral
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RegrowthHP", {0, 100, 1}, "Regrowth HP", "Set the Regrowth HP threshold.");
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.");
  -- CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts HP", "Set the Survival Instincts HP threshold.");
  CreateARPanelOptions(CP_Feral, "APL.Druid.Feral");
  -- CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)");
  -- CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.StealthMacro.JungleStalker", "Stealth Combo - Jungle Stalker", "Allow suggesting Jungle Stalker stealth ability combos (recommended)");
  --Balance
  CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkskinHP", {0, 100, 1}, "Barkskin HP", "Set the Barkskin HP threshold.");
  CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMoonkinFormOOC", "Show Moonkin Form Out of Combat", "Enable this if you want the addon to show you the Moonkin Form reminder out of combat.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowPotion", "Show Potion", "Enable this if you want the addon to show you when to use a potion.");
  CreateARPanelOptions(CP_Balance, "APL.Druid.Balance");
  --Guardian
  CreatePanelOption("CheckButton", CP_Guardian, "APL.Druid.Guardian.UseSplashData", "Use Splash Data for AoE", "Only count AoE enemies that are already hit by AoE abilities such as Swipe or Thrash.");
  CreateARPanelOptions(CP_Guardian, "APL.Druid.Guardian");
  CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BarkskinHP", {0, 100, 1}, "Barkskin HP", "Set the Barkskin HP threshold.");
  CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.LunarBeamHP", {0, 100, 1}, "Lunar Beam HP", "Set the Lunar Beam HP threshold.");
  CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.FrenziedRegenHP", {0, 100, 1}, "Frenzied Regeneration HP", "Set the Frenzied Regeneration HP threshold.");
  CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts HP", "Set the Survival Instincts HP threshold.");
  CreatePanelOption("Slider", CP_Guardian, "APL.Druid.Guardian.BristlingFurRage", {0, 100, 1}, "Bristling Fur Rage", "Set the Bristling Fur Rage threshold.");