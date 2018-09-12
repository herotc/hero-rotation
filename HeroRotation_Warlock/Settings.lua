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
  HR.GUISettings.APL.Warlock = {
    Commons = {
      PetReminder = "Always",
      ForcePet = "No",
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
        DemonicPower = true,
        GrimoireOfSacrifice = true,
        DimensionalRift = true,
        SummonImp = true,
        GrimoireImp = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        UnendingResolve = true,
        SoulHarvest = true,
      }
    },
    Demonology = {
      UnendingResolveHP = 20,
      ShowPoPP = false,
      Sephuz = {
        ShadowFury = false,
        MortalCoil = false,
        Fear = false,
        AxeToss = false
      },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        SummonFelguard = true,
        GrimoireFelguard = true,
        DemonicEmpowerment = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        UnendingResolve = true,
        SoulHarvest = true,
      }
    },
    Affliction = {
      -- UnendingResolveHP = 20,
      ShowPoPP = false,
      -- Sephuz = {
      --   HowlOfTerror = false,
      --   MortalCoil = false,
      --   Fear = false,
      --   SingeMagic = false,
      --   SpellLock = false
      -- },
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        DarkSoul = true,
        SummonDarkglare = true,
        SummonPet = true,
        GrimoireOfSacrifice = true,
        PhantomSingularity = true,
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
      }
    }
  };

  HR.GUI.LoadSettingsRecursively(HR.GUISettings);

  -- Child Panels
  local ARPanel = HR.GUI.Panel;
  local CP_Warlock = CreateChildPanel(ARPanel, "Warlock");
  local CP_Destruction = CreateChildPanel(CP_Warlock, "Destruction");
  local CP_Demonology = CreateChildPanel(CP_Warlock, "Demonology");
  local CP_Affliction = CreateChildPanel(CP_Warlock, "Affliction");
  -- Warlock
  CreateARPanelOptions(CP_Warlock, "APL.Warlock.Commons");
  CreatePanelOption("Dropdown", CP_Warlock, "APL.Warlock.Commons.PetReminder", {"Always", "Not with Grimoire of Supremacy", "Never"}, "Pet Summon Reminder", "Whether to show a Pet Summoning Reminder for a more optimal pet if you already have an active one.");
  -- CreatePanelOption("Dropdown", CP_Warlock, "APL.Warlock.Commons.ForcePet", {"No", "Infernal", "DoomGuard"}, "Force a specific pet", "Force the addon to show you a specific pet instead of the one the rotation propose.");
  CreatePanelOption("CheckButton", CP_Warlock, "APL.Warlock.Commons.UsePotions", "Show Potions", "Enable this if you want it to show you to use Potions.");
  -- Destruction
  CreatePanelOption("Slider", CP_Destruction, "APL.Warlock.Destruction.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.");
  CreatePanelOption("Dropdown", CP_Destruction, "APL.Warlock.Destruction.SpellType", {"Auto","Orange","Green"}, "Spell icons", "Define what icons you want to appear.");
  CreateARPanelOptions(CP_Destruction, "APL.Warlock.Destruction");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.ShadowFury", "Sephuz: Show Shadow Fury", "Enable this if you want it to show you when to use Shadow Fury to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.MortalCoil", "Sephuz: Show Mortal Coil", "Enable this if you want it to show you when to use Mortal Coil to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.Fear", "Sephuz: Show Fear", "Enable this if you want it to show you when to use Fear to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.SingeMagic", "Sephuz: Show Singe Magic", "Enable this if you want it to show you when to use Singe Magic (Imp spell) to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Destruction, "APL.Warlock.Destruction.Sephuz.SpellLock", "Sephuz: Show Spell Lock", "Enable this if you want it to show you when to use Spell Lock (Felhunter spell) to proc Sephuz's Secret (only when equipped).");
  -- Demonology
  CreatePanelOption("Slider", CP_Demonology, "APL.Warlock.Demonology.UnendingResolveHP", {0, 100, 1}, "Unending Resolve HP", "Set the Unending Resolve HP threshold.");
  CreateARPanelOptions(CP_Demonology, "APL.Warlock.Demonology");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.ShowPoPP", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.Sephuz.ShadowFury", "Sephuz: Show Shadow Fury", "Enable this if you want it to show you when to use Shadow Fury to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.Sephuz.MortalCoil", "Sephuz: Show Mortal Coil", "Enable this if you want it to show you when to use Mortal Coil to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.Sephuz.Fear", "Sephuz: Show Fear", "Enable this if you want it to show you when to use Fear to proc Sephuz's Secret (only when equipped).");
  CreatePanelOption("CheckButton", CP_Demonology, "APL.Warlock.Demonology.Sephuz.AxeToss", "Sephuz: Show Axe Toss", "Enable this if you want it to show you when to use Axe Toss (Felguard spell) to proc Sephuz's Secret (only when equipped).");
  -- Affliction
  CreateARPanelOptions(CP_Affliction, "APL.Warlock.Affliction");
  -- CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.Sephuz.HowlOfTerror", "Sephuz: Show Howl Of Terror", "Enable this if you want it to show you when to use Howl Of Terror to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.Sephuz.MortalCoil", "Sephuz: Show Mortal Coil", "Enable this if you want it to show you when to use Mortal Coil to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.Sephuz.SingeMagic", "Sephuz: Show Singe Magic", "Enable this if you want it to show you when to use Singe Magic (Imp spell) to proc Sephuz's Secret (only when equipped).");
  -- CreatePanelOption("CheckButton", CP_Affliction, "APL.Warlock.Affliction.Sephuz.SpellLock", "Sephuz: Show Spell Lock", "Enable this if you want it to show you when to use Spell Lock (Felhunter spell) to proc Sephuz's Secret (only when equipped).");

