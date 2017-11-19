--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;
  
  local AC = AethysCore;
  -- File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;

--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.DemonHunter = {
    Commons = {
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        Racials = {true, false},
        -- Abilities
        ConsumeMagic = {true, false}
      },
      UseTrinkets = true,
      UsePotions  = true
    },
    Vengeance = {
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        DemonSpikes = {true, false},
        InfernalStrike = {true, false}
      }
    },
    Havoc = {
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        ChaosBlades = {true, false},
        Metamorphosis = {true, false},
        Nemesis = {true, false},
      },
	 
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  local ARPanel = AR.GUI.Panel;
  local CP_DemonHunter = CreateChildPanel(ARPanel, "DemonHunter");
  local CP_Havoc = CreateChildPanel(CP_DemonHunter, "Havoc");
  local CP_Vengeance = CreateChildPanel(CP_DemonHunter, "Vengeance");
  
  CreateARPanelOption("OffGCDasOffGCD", CP_DemonHunter, "APL.DemonHunter.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("OffGCDasOffGCD", CP_DemonHunter, "APL.DemonHunter.Commons.OffGCDasOffGCD.ConsumeMagic", "Consume Magic");
  CreatePanelOption("CheckButton", CP_DemonHunter, "APL.DemonHunter.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation");
  CreatePanelOption("CheckButton", CP_DemonHunter, "APL.DemonHunter.Commons.UsePotions", "Use Potions", "Use Potions as part of the rotation");
  
  CreateARPanelOption("OffGCDasOffGCD", CP_Vengeance, "APL.DemonHunter.Vengeance.OffGCDasOffGCD.DemonSpikes", "Demon Spikes");
  CreateARPanelOption("OffGCDasOffGCD", CP_Vengeance, "APL.DemonHunter.Vengeance.OffGCDasOffGCD.InfernalStrike", "Infernal Strike");  
  
  CreateARPanelOption("OffGCDasOffGCD", CP_Havoc, "APL.DemonHunter.Havoc.OffGCDasOffGCD.ChaosBlades", "ChaosBlades");
  CreateARPanelOption("OffGCDasOffGCD", CP_Havoc, "APL.DemonHunter.Havoc.OffGCDasOffGCD.Metamorphosis", "Metamorphosis");  
  CreateARPanelOption("OffGCDasOffGCD", CP_Havoc, "APL.DemonHunter.Havoc.OffGCDasOffGCD.Nemesis", "Nemesis");  

