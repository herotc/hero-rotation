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
  AR.GUISettings.APL.Warlock = {
    Commons = {
      
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        SummonDoomGuard = {true, false},
        SummonInfernal = {true, false},
        SummonImp = {true, false},
        GrimoireImp = {true, false},
        LifeTap = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = {true, false},
        -- Abilities
        
      }
    },
    Destruction = {
      SpellType="Auto",--Green fire override {"Auto","Orange","Green"}
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        DemonicPower = {true, false},
        GrimoireOfSacrifice = {true, false},
        DimensionalRift = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        SoulHarvest = {true, false},
      }
    },
    Demonology = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        SummonFelguard = {true, false},
        GrimoireFelguard = {true, false},
        DemonicEmpowerment = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        SoulHarvest = {true, false},
      }
    },
    Affliction = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        GrimoireOfSacrifice = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        SoulHarvest = {true, false},
      }
    }
  };
  
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Warlock = CreateChildPanel(ARPanel, "Warlock");
  -- local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction");
  local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology");
  local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction");
  
  CreateARPanelOption("OffGCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.SummonDoomGuard", "Summon DoomGuard");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.SummonInfernal", "Summon Infernal");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.SummonImp", "Summon Imp");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.GrimoireImp", "Grimoire Imp");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.LifeTap", "Life Tap");
  
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.SummonFelguard", "Summon Felguard");
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.GrimoireFelguard", "Grimoire Felguard");
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.DemonicEmpowerment", "Demonic Empowerment");
  CreateARPanelOption("OffGCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.OffGCDasOffGCD.SoulHarvest", "Soul Harvest");
  
  CreatePanelOption("Dropdown", CP_Destruction, "APL.Warlock.Destruction.SpellType", {"Auto","Orange","Green"}, "Spell icons", "Define what icons you want to appear.");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.DemonicPower", "Demonic Power");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.GrimoireOfSacrifice", "Grimoire Of Sacrifice");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.DimensionalRift", "Dimensional Rift");
  CreateARPanelOption("OffGCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.OffGCDasOffGCD.SoulHarvest", "Soul Harvest");
