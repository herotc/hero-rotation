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
      GCDasOffGCD = {
        -- Abilities
        ArmyOfDead     = true,
        SummonGargoyle = true,
        DarkArbiter    = true
      },
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent      = true,
        Berserking         = true,
        BloodFury          = true,
        -- Abilities
        BlightedRuneWeapon = true
       }
     },
    Blood = {
      ConsumptionSuggested = true,
      PoolDuringBlooddrinker = false,
      UmbilicusEternus = 0,
      Enabled = {
        -- Racials
        ArcaneTorrent     = true,
        -- Abilities
        Consumption       = true,
        DancingRuneWeapon = true
      },
      GCDasOffGCD = {
        -- Abilities
        Blooddrinker = true,
        Bonestorm    = true
      },
      OffGCDasOffGCD = {
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
  CreatePanelOption("CheckButton", CP_Blood, "APL.DeathKnight.Blood.ConsumptionSuggested", "Suggested: Consumption", "Suggest (Left Top icon) Consumption if Consumption is not enabled.");
  CreatePanelOption("CheckButton", CP_Blood, "APL.DeathKnight.Blood.PoolDuringBlooddrinker", "Pool: Blooddrinker", "Display the 'Pool' icon whenever you're channeling Blooddrinker as long as you shouldn't interrupt it (supports Quaking).");
  CreatePanelOption("Slider", CP_Blood, "APL.DeathKnight.Blood.UmbilicusEternus", {0, 2, 0.1}, "Cancel: Umbilicus Eternus Remains", "Set the duration you want to start to show the Umbilicus Eternus cancel. Set to 0 to disable it.");
  CreateARPanelOptions(CP_Blood, "APL.DeathKnight.Blood");
