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
  -- Default settings
  AR.GUISettings.APL.Rogue = {
    Commons = {
      -- SoloMode Settings
      CrimsonVialHP = 0,
      FeintHP = 0,
      -- Evisc/Env Mantle Damage Offset Multiplier
      EDMGMantleOffset = 2,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        CrimsonVial = {true, false},
        Feint = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        Racials = {true, false},
        -- Stealth CDs
        Vanish = {true, false},
        -- Abilities
        Kick = {true, false},
        MarkedforDeath = {true, false},
        Sprint = {true, false},
        Stealth = {true, false}
      }
    },
    Assassination = {
      -- Damage Offsets
      EnvenomDMGOffset = 3,
      MutilateDMGOffset = 3,
      -- Poison Refresh (in seconds)
      PoisonRefresh = 15,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Vendetta = {true, false}
      }
    },
    Outlaw = {
      -- Roll the Bones Logic, accepts "SimC", "1+ Buff" and every "RtBName".
      -- "SimC", "1+ Buff", "Broadsides", "Buried Treasure", "Grand Melee", "Jolly Roger", "Shark Infested Waters", "True Bearing"
      RolltheBonesLogic = "SimC",
      -- SoloMode Settings
      RolltheBonesLeechHP = 60, -- % HP threshold to reroll for Grand Melee.
      -- Blade Flurry TimeOut
      BFOffset = 2,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        AdrenalineRush = {true, false},
        CurseoftheDreadblades = {true, false},
        BladeFlurry = {true, false},
      }
    },
    Subtlety = {
      -- Damage Offsets
      EviscerateDMGOffset = 3,
      -- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
      ShDEcoCharge = 2.55,
      -- Single Target MfD as DPS CD
      STMfDAsDPSCD = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        ShadowBlades = {true, false},
        SymbolsofDeath = {true, false},
        ShadowDance = {true, false}
      },
      -- Stealth Macro Enable/Disable Options
      StealthMacro = {
        -- Abilities
        Vanish = true,
        Shadowmeld = true,
        ShadowDance = true
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Rogue = CreateChildPanel(ARPanel, "Rogue");
  local CP_Assassination = CreateChildPanel(CP_Rogue, "Assassination");
  local CP_Outlaw = CreateChildPanel(CP_Rogue, "Outlaw");
  local CP_Subtlety = CreateChildPanel(CP_Rogue, "Subtlety");
  -- Controls
  -- Rogue
  CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.CrimsonVialHP", {0, 100, 1}, "Crimson Vial HP", "Set the Crimson Vial HP threshold.");
  CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.FeintHP", {0, 100, 1}, "Feint HP", "Set the Feint HP threshold.");
  CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.EDMGMantleOffset", {1, 5, 0.25}, "Mantle Damage Offset", "Set the Evisc/Env Mantle Damage Offset.");
  CreateARPanelOption("GCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.GCDasOffGCD.CrimsonVial", "Crimson Vial");
  CreateARPanelOption("GCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.GCDasOffGCD.Feint", "Feint");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.Vanish", "Vanish");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.Kick", "Kick");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.MarkedforDeath", "Marked for Death");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.Sprint", "Sprint");
  CreateARPanelOption("OffGCDasOffGCD", CP_Rogue, "APL.Rogue.Commons.OffGCDasOffGCD.Stealth", "Stealth");
  -- Assassination
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.EnvenomDMGOffset", {1, 5, 0.25}, "Envenom DMG Offset", "Set the Envenom DMG Offset.");
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.MutilateDMGOffset", {1, 5, 0.25}, "Mutilate DMG Offset", "Set the Mutilate DMG Offset.");
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.PoisonRefresh", {5, 55, 1}, "Poison Refresh", "Set the timer for the Poison Refresh.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Assassination, "APL.Rogue.Assassination.OffGCDasOffGCD.Vendetta", "Vendetta");
  -- Outlaw
  CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLogic", {"SimC", "1+ Buff", "Broadsides", "Buried Treasure", "Grand Melee", "Jolly Roger", "Shark Infested Waters", "True Bearing"}, "Roll the Bones Logic", "Define the Roll the Bones logic to follow.");
  CreatePanelOption("Slider", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLeechHP", {1, 100, 1}, "Roll the Bones Leech HP", "Set the HP threshold before re-rolling for the leech buff (working only if Solo Mode is enabled).");
  CreatePanelOption("Slider", CP_Outlaw, "APL.Rogue.Outlaw.BFOffset", {1, 5, 1}, "Blade Flurry Offset", "Set the Blade Flurry timer before suggesting to disable it (to compensate fast movement).");
  CreateARPanelOption("OffGCDasOffGCD", CP_Outlaw, "APL.Rogue.Outlaw.OffGCDasOffGCD.AdrenalineRush", "Adrenaline Rush");
  CreateARPanelOption("OffGCDasOffGCD", CP_Outlaw, "APL.Rogue.Outlaw.OffGCDasOffGCD.CurseoftheDreadblades", "Curse of the Dreadblades");
  CreateARPanelOption("OffGCDasOffGCD", CP_Outlaw, "APL.Rogue.Outlaw.OffGCDasOffGCD.BladeFlurry", "Blade Flurry");
  -- Subtlety
  CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.EviscerateDMGOffset", {1, 5, 0.25}, "Eviscerate DMG Offset", "Set the Eviscerate DMG Offset.");
  CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.ShDEcoCharge", {2, 3, 0.1}, "ShD Eco Charge", "Set the Shadow Dance Eco Charge threshold.");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.STMfDAsDPSCD", "ST Marked for Death as DPS CD", "Enable if you want to put Single Target Marked for Death shown as Off GCD (top icons) instead of Suggested.");
  CreateARPanelOption("OffGCDasOffGCD", CP_Subtlety, "APL.Rogue.Subtlety.OffGCDasOffGCD.ShadowBlades", "Shadow Blades");
  CreateARPanelOption("OffGCDasOffGCD", CP_Subtlety, "APL.Rogue.Subtlety.OffGCDasOffGCD.SymbolsofDeath", "Symbols of Death");
  CreateARPanelOption("OffGCDasOffGCD", CP_Subtlety, "APL.Rogue.Subtlety.OffGCDasOffGCD.ShadowDance", "Shadow Dance");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Vanish", "Stealth Combo - Vanish", "Allow suggesting Vanish stealth ability combos (recommended)");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.ShadowDance", "Stealth Combo - Shadow Dance", "Allow suggesting Shadow Dance stealth ability combos (recommended)");
