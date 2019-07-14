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
  -- Default settings
  HR.GUISettings.APL.Rogue = {
    Commons = {
      -- SoloMode Settings
      CrimsonVialHP = 0,
      FeintHP = 0,
      StealthOOC = true,
      -- Trinkets
      UseTrinkets = true,
      TrinketDisplayStyle = "Suggested",
      -- Essences
      EssenceDisplayStyle = "Suggested",
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        Racials = true,
        CrimsonVial = true,
        Feint = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        Racials = true,
        -- Stealth CDs
        Vanish = true,
        -- Abilities
        Kick = true,
        MarkedforDeath = true,
        Sprint = true,
        Stealth = true
      }
    },
    Assassination = {
      -- Damage Offsets
      EnvenomDMGOffset = 3,
      MutilateDMGOffset = 3,
      -- Poison Refresh (in minutes)
      PoisonRefresh = 15,
      PoisonRefreshCombat = 3,
      -- Suggest Multi-DoT at FoK Range
      RangedMultiDoT = true,
      -- Suggest Garrote even when Vanish is up
      AlwaysSuggestGarrote = false,
      -- Use Priority Rotation
      UsePriorityRotation = "Never",
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        Vendetta = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
    Outlaw = {
      -- Roll the Bones Logic, accepts "SimC", "1+ Buff" and every "RtBName".
      -- "SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"
      RolltheBonesLogic = "SimC",
      -- SoloMode Settings
      RolltheBonesLeechHP = 60, -- % HP threshold to reroll for Grand Melee.
      UseDPSVanish = false, -- Use Vanish in the rotation for DPS
      PrecombatAR = true, -- Display Adrenaline Rush precombat
      KillingSpreeDisplayStyle = "Suggested",
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        AdrenalineRush = true,
        BladeFlurry = true,
        BladeRush = false,
        GhostlyStrike = false,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
    Subtlety = {
      -- Burn Shadow Dance charges when the target is about to die
      BurnShadowDance = "On Bosses not in Dungeons",
      -- Damage Offsets
      EviscerateDMGOffset = 3,
      -- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
      ShDEcoCharge = 2.55,
      -- Single Target MfD as DPS CD
      STMfDAsDPSCD = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        ShadowBlades = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        SymbolsofDeath = true,
        ShadowDance = true,
      },
      -- Stealth Macro Enable/Disable Options
      StealthMacro = {
        -- Abilities
        Vanish = true,
        Shadowmeld = true,
        ShadowDance = true
      },
      UsePriorityRotation = "Never"
    }
  };

  HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Rogue = CreateChildPanel(ARPanel, "Rogue");
  local CP_Assassination = CreateChildPanel(CP_Rogue, "Assassination");
  local CP_Outlaw = CreateChildPanel(CP_Rogue, "Outlaw");
  local CP_Subtlety = CreateChildPanel(CP_Rogue, "Subtlety");
  -- Controls
  -- Rogue
  CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.CrimsonVialHP", {0, 100, 1}, "Crimson Vial HP", "Set the Crimson Vial HP threshold.");
  CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.FeintHP", {0, 100, 1}, "Feint HP", "Set the Feint HP threshold.");
  CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.StealthOOC", "Stealth Reminder (OOC)", "Show Stealth Reminder when out of combat.");
  CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
  CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.");
  CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.EssenceDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Essence Display Style", "Define which icon display style to use for active Azerite Essences.");
  CreateARPanelOptions(CP_Rogue, "APL.Rogue.Commons");
  -- Assassination
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.EnvenomDMGOffset", {1, 5, 0.25}, "Envenom DMG Offset", "Set the Envenom DMG Offset.");
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.MutilateDMGOffset", {1, 5, 0.25}, "Mutilate DMG Offset", "Set the Mutilate DMG Offset.");
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.PoisonRefresh", {5, 55, 1}, "OOC Poison Refresh", "Set the timer for the Poison Refresh (OOC)");
  CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.PoisonRefreshCombat", {0, 55, 1}, "Combat Poison Refresh", "Set the timer for the Poison Refresh (In Combat)");
  CreatePanelOption("CheckButton", CP_Assassination, "APL.Rogue.Assassination.RangedMultiDoT", "Suggest Ranged Multi-DoT", "Suggest multi-DoT targets at Fan of Knives range (10 yards) instead of only melee range. Disabling will only suggest DoT targets within melee range.");
  CreatePanelOption("CheckButton", CP_Assassination, "APL.Rogue.Assassination.AlwaysSuggestGarrote", "Always Suggest Garrote", "Don't prevent Garrote suggestions when using Subterfuge and Vanish is ready. These should ideally be synced, but can be useful if holding Vanish for specific fights.");
  CreatePanelOption("Dropdown", CP_Assassination, "APL.Rogue.Assassination.UsePriorityRotation", {"Never", "On Bosses", "Always"}, "Use Priority Rotation", "Select when to show rotation for maximum priority damage (at the cost of overall AoE damage.)");
  CreateARPanelOptions(CP_Assassination, "APL.Rogue.Assassination");
  -- Outlaw
  CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLogic", {"SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"}, "Roll the Bones Logic", "Define the Roll the Bones logic to follow.\n(SimC highly recommended!)");
  CreatePanelOption("Slider", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLeechHP", {1, 100, 1}, "Roll the Bones Leech HP", "Set the HP threshold before re-rolling for the leech buff (working only if Solo Mode is enabled).");
  CreatePanelOption("CheckButton", CP_Outlaw, "APL.Rogue.Outlaw.UseDPSVanish", "Use Vanish for DPS", "Suggest Vanish -> Ambush for DPS.\nDisable to save Vanish for utility purposes.");
  CreatePanelOption("CheckButton", CP_Outlaw, "APL.Rogue.Outlaw.PrecombatAR", "Show Precombat Adrenaline Rush", "Display Adrenaline Rush when outside of combat with a valid target.");
  CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.KillingSpreeDisplayStyle", {"Main Icon", "Suggested", "Cooldown"}, "Killing Spree Display Style", "Define which icon display style to use for Killing Spree.");
  CreateARPanelOptions(CP_Outlaw, "APL.Rogue.Outlaw");
  -- Subtlety
  CreatePanelOption("Dropdown", CP_Subtlety, "APL.Rogue.Subtlety.BurnShadowDance", {"Always", "On Bosses", "On Bosses not in Dungeons"}, "Burn Shadow Dance before Death", "Use remaining Shadow Dance charges when the target is about to die.");
  CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.EviscerateDMGOffset", {1, 5, 0.25}, "Eviscerate DMG Offset", "Set the Eviscerate DMG Offset.");
  CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.ShDEcoCharge", {2, 3, 0.1}, "ShD Eco Charge", "Set the Shadow Dance Eco Charge threshold.");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.STMfDAsDPSCD", "ST Marked for Death as DPS CD", "Enable if you want to put Single Target Marked for Death shown as Off GCD (top icons) instead of Suggested.");
  CreateARPanelOptions(CP_Subtlety, "APL.Rogue.Subtlety");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Vanish", "Stealth Combo - Vanish", "Allow suggesting Vanish stealth ability combos (recommended)");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)");
  CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.ShadowDance", "Stealth Combo - Shadow Dance", "Allow suggesting Shadow Dance stealth ability combos (recommended)");
  CreatePanelOption("Dropdown", CP_Subtlety, "APL.Rogue.Subtlety.UsePriorityRotation", {"Never", "On Bosses", "Always"}, "Use Priority Rotation", "Select when to show rotation for maximum priority damage (at the cost of overall AoE damage.) Zul Mythic will use priority rotation automatically without setting this.");
