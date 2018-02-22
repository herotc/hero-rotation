--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;
  -- AethysCore
  local AC = AethysCore;
  --File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;
  local CreateARPanelOption = AR.GUI.CreateARPanelOption;
  local CreateARPanelOptions = AR.GUI.CreateARPanelOptions;

--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.DeathKnight = {
    Commons = {
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        
      },
      UseTrinkets = false,
      UsePotions  = false
    },
   Frost = {
      GCDasOffGCD = {
        -- Abilities
        HornOfWinter       = true,
        Obliteration       = true,
        SindragosasFury    = true,
        BreathofSindragosa = true
      },
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent       = true,
        Berserking          = true,
        BloodFury           = true,
        -- Abilities
        PillarOfFrost       = true,
        HungeringRuneWeapon = true,
        EmpowerRuneWeapon   = true
      }
    },
    Unholy = {
      GCDasOffGCD2 = {
        -- Abilities
        ArmyOfDead     = true,
        SummonGargoyle = true,
        DarkArbiter    = true
      },
      OffGCDasOffGCD2 = {
        -- Racials
        ArcaneTorrent      = true,
        Berserking         = true,
        BloodFury          = true,
        -- Abilities
        BlightedRuneWeapon = true
       }
     },
    Blood = {
      RotationToFollow = "Icy Veins", -- Choose the rotation to follow (Default: Icy Veins)
      Enabled = {
        -- Racials
        ArcaneTorrent     = true,
        -- Abilities
        Consumption       = true,
        DancingRuneWeapon = true
      },
      GCDasOffGCD2 = {
        -- Abilities
        BloodDrinker = true,
        Bonestorm    = true
      },
      OffGCDasOffGCD2 = {
        DancingRuneWeapon = true,
        ArcaneTorrent     = true
      }
    }
  };

  AR.GUI.LoadSettingsRecursively(AR.GUISettings);
  -- Panels
  local ARPanel        = AR.GUI.Panel;
  local CP_Deathknight = CreateChildPanel(ARPanel, "DeathKnight");
  local CP_Unholy      = CreateChildPanel(CP_Deathknight, "Unholy");
  local CP_Frost       = CreateChildPanel(CP_Deathknight, "Frost");
  local CP_Blood       = CreateChildPanel(CP_Deathknight, "Blood");
  
  --DeathKnight Panels
  CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UseTrinkets", "Show on use trinkets", "Fel Oiled Machine Supported.");
  CreatePanelOption("CheckButton", CP_Deathknight, "APL.DeathKnight.Commons.UsePotions", "Show Potion of Prolonged Power", "Enable this if you want it to show you when to use Potion of Prolonged Power.");
  --Unholy Panels
  CreateARPanelOptions(CP_Unholy, "APL.DeathKnight.Unholy");
  --Frost Panels
  CreateARPanelOptions(CP_Frost, "APL.DeathKnight.Frost");
  --Blood Panels
  CreatePanelOption("Dropdown", CP_Blood, "APL.DeathKnight.Blood.RotationToFollow", {"Icy Veins","SimC"}, "Rotation:", "Define the rotation to follow.(Simc module needs development)");
  CreateARPanelOptions(CP_Blood, "APL.DeathKnight.Blood");
