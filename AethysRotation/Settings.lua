--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;
  -- AethysCore
  local AC = AethysCore;
  -- File Locals
  local GUI = AC.GUI;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreateCheckButton = GUI.CreateCheckButton;
  local CreateDropdown = GUI.CreateDropdown;


--- ============================ CONTENT ============================
  -- Default settings
  AR.GUISettings = {
    General = {
      -- Main Frame Strata
      MainFrameStrata = "BACKGROUND",
      -- Black Border Icon (Enable if you want clean black borders)
      BlackBorderIcon = false,
      -- Interrupt
      InterruptEnabled = false,
      InterruptWithStun = false, -- EXPERIMENTAL
      -- SoloMode try to maximize survivability at the cost of dps
      SoloMode = false
    },
    APL = {}
  };

  function AR.GUI.CorePanelSettingsInit ()
    -- GUI
    local ARPanel = GUI.CreatePanel(AR.GUI, "AethysRotation", "PanelFrame", AR.GUISettings, AethysRotationDB.GUISettings);
    -- Child Panel
    local CP_General = CreateChildPanel(ARPanel, "General");
    -- Controls
    CreateDropdown(CP_General, "General.MainFrameStrata", {"HIGH", "MEDIUM", "LOW", "BACKGROUND"}, "Main Frame Strata", "Test tooltip");
    CreateCheckButton(CP_General, "General.BlackBorderIcon", "Black Border Icon", "Enable if you want clean black borders.");
    CreateCheckButton(CP_General, "General.InterruptEnabled", "Interrupt", "Enable if you want to interrupt.");
    CreateCheckButton(CP_General, "General.InterruptWithStun", "Interrupt With Stun", "EXPERIMENTAL: Enable if you want to interrupt with stuns.");
    CreateCheckButton(CP_General, "General.SoloMode", "Solo Mode", "Enable if you want to try to maximize survivability at the cost of dps.");
  end
