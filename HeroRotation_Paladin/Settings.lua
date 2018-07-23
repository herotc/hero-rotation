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
  HR.GUISettings.APL.Paladin = {
    Protection = {
      -- CDs HP %
      EyeofTyrHP = 60,
      HandoftheProtectorHP = 80,
      LightoftheProtectorHP = 80,
      ShieldoftheRighteousHP = 60,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = true,
        -- Abilities
        AvengingWrath = true,
        HandoftheProtector = true,
        LightoftheProtector = true,
        ShieldoftheRighteous = true,
      }
    },
    Retribution = {
      -- SoloMode Settings
      SoloJusticarDP = 80, -- % HP threshold to use Justicar's Vengeance with Divine Purpose proc.
      SoloJusticar5HP = 60, -- % HP threshold to use Justicar's Vengeance with 5 Holy Power.
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        HolyWrath = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = true,
        -- Abilities
        AvengingWrath = true,
        Crusade = true,
      }
    }
  };
  -- GUI
  HR.GUI.LoadSettingsRecursively(HR.GUISettings);
  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Paladin = CreateChildPanel(ARPanel, "Paladin");
  local CP_Protection = CreateChildPanel(CP_Paladin, "Protection");
  local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution");
  -- Protection
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.EyeofTyrHP", {0, 100, 1}, "Eye of Tyr HP", "Set the Eye of Tyr HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.HandoftheProtectorHP", {0, 100, 1}, "Hand of the Protector HP", "Set the Hand of the Protector HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.LightoftheProtectorHP", {0, 100, 1}, "Light of the Protector HP", "Set the Light of the Protector HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ShieldoftheRighteousHP", {0, 100, 1}, "Shield of the Righteous HP", "Set the Shield of the Righteous HP threshold.");
  CreateARPanelOptions(CP_Protection, "APL.Paladin.Protection");
  -- Retribution
  CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticarDP", {0, 100, 1}, "Solo Justicar's Vengeance with Divine Purpose proc HP", "Set the solo Justicar's Vengeance with Divine Purpose proc HP threshold.");
  CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticar5HP", {0, 100, 1}, "Solo Justicar's Vengeance with 5 Holy Power HP", "Set the solo Justicar's Vengeance with 5 Holy Power HP threshold.");
  CreateARPanelOptions(CP_Retribution, "APL.Paladin.Retribution");
