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
  AR.GUISettings.APL.Druid = {
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
          MoonkinForm = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
          BlessingofElune = {true, false},
          BlessingofAnshe = {true, false},
          AstralCommunion = {true, false},
          IncarnationChosenOfElune = {true, false},
          CelestialAlignment = {true, false},
          WarriorofElune = {true, false},
          BarkSkin = {true, false},
          Sephuz = {true, false}
      }
    },
    Feral = {
		RegrowthHP = 0,
		RenewalHP = 0,
		SurvivalInstinctsHP = 0,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
		CatForm = {true, false},
		RegrowthHeal = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
		--Abilities
		Renewal = {true, false},
		SurvivalInstincts = {true, false},
		Prowl = {true, false},
		ElunesGuidance = {true, false},
		WildCharge = {true, false},
		TigersFury = {true, false},
		Berserk = {true, false},
      },
	  StealthMacro = {
        -- Abilities
        Shadowmeld = true,
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

    AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Druid = CreateChildPanel(ARPanel, "Druid");
  local CP_Balance = CreateChildPanel(CP_Druid, "Balance");
  local CP_Feral = CreateChildPanel(CP_Druid, "Feral");
  -- local CP_Guardian = CreateChildPanel(CP_Druid, "Guardian");

  CreateARPanelOption("OffGCDasOffGCD", CP_Druid, "APL.Druid.Commons.OffGCDasOffGCD.Racials", "Racials");
  --Feral
  CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RegrowthHP", {0, 100, 1}, "Regrowth HP", "Set the Regrowth HP threshold.");
  CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.RenewalHP", {0, 100, 1}, "Renewal HP", "Set the Renewal HP threshold.");
  CreatePanelOption("Slider", CP_Feral, "APL.Druid.Feral.SurvivalInstinctsHP", {0, 100, 1}, "Survival Instincts HP", "Set the Survival Instincts HP threshold.");
  CreateARPanelOption("GCDasOffGCD", CP_Feral, "APL.Druid.Feral.GCDasOffGCD.CatForm", "Cat Form");
  CreateARPanelOption("GCDasOffGCD", CP_Feral, "APL.Druid.Feral.GCDasOffGCD.RegrowthHeal", "Defensive Regrowths");
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.Renewal", "Renewal")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.SurvivalInstincts", "Survival Instincts")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.Prowl", "Prowl")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.ElunesGuidance", "Elune's Guidance")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.WildCharge", "Wild Charge")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.TigersFury", "Tiger's Fury")
  CreateARPanelOption("OffGCDasOffGCD", CP_Feral, "APL.Druid.Feral.OffGCDasOffGCD.Berserk", "Berserk and Incarnation")
  CreatePanelOption("CheckButton", CP_Feral, "APL.Druid.Feral.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)");
  --Balance
  CreatePanelOption("Slider", CP_Balance, "APL.Druid.Balance.BarkSkinHP", {0, 100, 1}, "BarkSkin HP", "Set the BarkSkin HP threshold.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowMFOOP", "Show Moonkin Form Out of Combat", "Enable this if you want the addon to show you the Moonkin Form reminder out of combat.");
  CreateARPanelOption("GCDasOffGCD", CP_Balance, "APL.Druid.Balance.GCDasOffGCD.MoonkinForm", "Moonkin Form");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.BlessingofElune", "Blessing Of Elune");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.BlessingofAnshe", "Blessing Of Anshe");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.AstralCommunion", "Astral Communion");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.IncarnationChosenOfElune", "Incarnation Chosen Of Elune");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.CelestialAlignment", "Celestial Alignment");
  CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.WarriorofElune", "Warrior Of Elune");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want the addon to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.SolarBeam", "Sephuz: Show Solar Beam", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.EntanglingRoots", "Sephuz: Show Entangling Roots", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MightyBash", "Sephuz: Show Mighty Bash", "Enable this if you want it to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.MassEntanglement", "Sephuz: Show Mass Entanglement", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Balance, "APL.Druid.Balance.Sephuz.Typhoon", "Sephuz: Show Typhoon", "Enable this if you want the addon to show you when to use Solar Beam to proc Sephuz's Secret (only when equipped).");
  -- CreateARPanelOption("OffGCDasOffGCD", CP_Balance, "APL.Druid.Balance.OffGCDasOffGCD.Sephuz", "Skills to proc Sephuz");

