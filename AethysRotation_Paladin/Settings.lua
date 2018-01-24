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
  AR.GUISettings.APL.Paladin = {
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
        ArcaneTorrent = {true, false},
        -- Abilities
        AvengingWrath = {true, false},
        HandoftheProtector = {true, false},
        LightoftheProtector = {true, false},
        ShieldoftheRighteous = {true, false}
      }
    },
    Retribution = {
      -- SoloMode Settings
      SoloJusticarDP = 80, -- % HP threshold to use Justicar's Vengeance with Divine Purpose proc.
      SoloJusticar5HP = 60, -- % HP threshold to use Justicar's Vengeance with 5 Holy Power.
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        HolyWrath = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        -- Abilities
        AvengingWrath = {true, false},
        Crusade = {true, false}
      }
    }
  };
  -- GUI
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Paladin = CreateChildPanel(ARPanel, "Paladin");
  local CP_Protection = CreateChildPanel(CP_Paladin, "Protection");
  local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution");
  -- Protection
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.EyeofTyrHP", {0, 100, 1}, "Eye of Tyr HP", "Set the Eye of Tyr HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.HandoftheProtectorHP", {0, 100, 1}, "Hand of the Protector HP", "Set the Hand of the Protector HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.LightoftheProtectorHP", {0, 100, 1}, "Light of the Protector HP", "Set the Light of the Protector HP threshold.");
  CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ShieldoftheRighteousHP", {0, 100, 1}, "Shield of the Righteous HP", "Set the Shield of the Righteous HP threshold.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Protection, "APL.Paladin.Protection.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent");
  CreateARPanelOption("OffGCDasOffGCD", CP_Protection, "APL.Paladin.Protection.OffGCDasOffGCD.AvengingWrath", "Avenging Wrath");
  CreateARPanelOption("OffGCDasOffGCD", CP_Protection, "APL.Paladin.Protection.OffGCDasOffGCD.HandoftheProtector", "Hand of the Protector");
  CreateARPanelOption("OffGCDasOffGCD", CP_Protection, "APL.Paladin.Protection.OffGCDasOffGCD.LightoftheProtector", "Light of the Protector");
  CreateARPanelOption("OffGCDasOffGCD", CP_Protection, "APL.Paladin.Protection.OffGCDasOffGCD.ShieldoftheRighteous", "Shield of the Righteous");
  -- Retribution
  CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticarDP", {0, 100, 1}, "Solo Justicar's Vengeance with Divine Purpose proc HP", "Set the solo Justicar's Vengeance with Divine Purpose proc HP threshold.");
  CreatePanelOption("Slider", CP_Retribution, "APL.Paladin.Retribution.SoloJusticar5HP", {0, 100, 1}, "Solo Justicar's Vengeance with 5 Holy Power HP", "Set the solo Justicar's Vengeance with 5 Holy Power HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_Retribution, "APL.Paladin.Retribution.GCDasOffGCD.HolyWrath", "Holy Wrath");
  CreateARPanelOption("OffGCDasOffGCD", CP_Retribution, "APL.Paladin.Retribution.OffGCDasOffGCD.ArcaneTorrent", "Arcane Torrent");
  CreateARPanelOption("OffGCDasOffGCD", CP_Retribution, "APL.Paladin.Retribution.OffGCDasOffGCD.AvengingWrath", "Avenging Wrath");
  CreateARPanelOption("OffGCDasOffGCD", CP_Retribution, "APL.Paladin.Retribution.OffGCDasOffGCD.Crusade", "Crusade");
