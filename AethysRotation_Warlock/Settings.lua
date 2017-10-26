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
        LifeTap = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        Racials = {true, false}
        -- Abilities
        
      }
    },
    Destruction = {
      UnendingResolveHP = 20,
      ShowPoPP = false,
      SpellType="Auto",--Green fire override {"Auto","Orange","Green"}
      Sephuz = {
        ShadowFury = false,
        MortalCoil = false,
        Fear = false,
        SingeMagic = false,
        SpellLock = false
      },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        DemonicPower = {true, false},
        GrimoireOfSacrifice = {true, false},
        DimensionalRift = {true, false},
        SummonImp = {true, false},
        GrimoireImp = {true, false},
        Sephuz = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        UnendingResolve = {true, false},
        -- Abilities
        SoulHarvest = {true, false}
      }
    },
    Demonology = {
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        SummonFelguard = {true, false},
        GrimoireFelguard = {true, false},
        DemonicEmpowerment = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        SoulHarvest = {true, false}
      }
    },
    Affliction = {
      ShowPoPP = false,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        SummonFelhunter = {true, false},
        GrimoireFelhunter = {true, false},
        GrimoireOfSacrifice = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        SoulHarvest = {true, false}
      }
    }
  };
  
  AR.GUI.LoadSettingsRecursively(AR.GUISettings);

  -- Child Panels
  local ARPanel = AR.GUI.Panel;
  local CP_Warlock = CreateChildPanel(ARPanel, "Warlock");
  local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction");
  local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology");
  local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction");
  

  
  CreateARPanelOption("OffGCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.OffGCDasOffGCD.Racials", "Racials");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.SummonDoomGuard", "Summon DoomGuard");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.SummonInfernal", "Summon Infernal");
  CreateARPanelOption("GCDasOffGCD", CP_Warlock, "APL.Warlock.Commons.GCDasOffGCD.LifeTap", "Life Tap");
 
  CreatePanelOption("Slider", CP_Destruction, "APL.Warlock.Destruction.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.");
  CreatePanelOption("Dropdown", CP_Destruction, "APL.Warlock.Destruction.SpellType", {"Auto","Orange","Green"}, "Spell icons", "Define what icons you want to appear.");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.DemonicPower", "Demonic Power");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.GrimoireOfSacrifice", "Grimoire Of Sacrifice");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.DimensionalRift", "Dimensional Rift");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.SummonImp", "Summon Imp");
  CreateARPanelOption("GCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.GCDasOffGCD.GrimoireImp", "Grimoire Imp");
  CreateARPanelOption("OffGCDasOffGCD", CP_Destruction, "APL.Warlock.Destruction.OffGCDasOffGCD.SoulHarvest", "Soul Harvest");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.ShadowFury", "Sephuz: Show Shadow Fury", "Enable this if you want it to show you when to use Shadow Fury to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.MortalCoil", "Sephuz: Show Mortal Coil", "Enable this if you want it to show you when to use Mortal Coil to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.Fear", "Sephuz: Show Fear", "Enable this if you want it to show you when to use Fear to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.SingeMagic", "Sephuz: Show Singe Magic", "Enable this if you want it to show you when to use Singe Magic (Imp spell) to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.SpellLock", "Sephuz: Show Spell Lock", "Enable this if you want it to show you when to use Spell Lock (Felhunter spell) to proc Sephuz's Secret (only when equipped).");

 
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.SummonFelguard", "Summon Felguard");
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.GrimoireFelguard", "Grimoire Felguard");
  CreateARPanelOption("GCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.GCDasOffGCD.DemonicEmpowerment", "Demonic Empowerment");
  CreateARPanelOption("OffGCDasOffGCD", CP_Demonology, "APL.Warlock.Demonology.OffGCDasOffGCD.SoulHarvest", "Soul Harvest");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");


  CreateARPanelOption("GCDasOffGCD", CP_Affliction, "APL.Warlock.Affliction.GCDasOffGCD.SummonFelhunter", "Summon Felhunter");
  CreateARPanelOption("GCDasOffGCD", CP_Affliction, "APL.Warlock.Affliction.GCDasOffGCD.GrimoireFelhunter", "Grimoire Felhunter");
  CreateARPanelOption("GCDasOffGCD", CP_Affliction, "APL.Warlock.Affliction.GCDasOffGCD.GrimoireOfSacrifice", "Grimoire Of Sacrifice");
  CreateARPanelOption("OffGCDasOffGCD", CP_Affliction, "APL.Warlock.Affliction.OffGCDasOffGCD.SoulHarvest", "Soul Harvest");
  CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");

