--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;
  -- AethysCore
  local AC = AethysCore;
  -- File Locals
  local GUI = AC.GUI;
  local CreatePanel = GUI.CreatePanel;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;


--- ============================ CONTENT ============================
  -- Default settings
  AR.GUISettings = {
    General = {
      -- Main Frame Strata
      MainFrameStrata = "BACKGROUND",
      -- Black Border Icon (Enable if you want clean black borders)
      BlackBorderIcon = false,
      HideKeyBinds = false,
      -- Interrupt
      InterruptEnabled = false,
      InterruptWithStun = false, -- EXPERIMENTAL
      -- SoloMode try to maximize survivability at the cost of dps
      SoloMode = false,
      -- Remove the toggle icon buttons.
      HideToggleIcons = false,
      ScaleUI = 1,
      ScaleButtons = 1
    },
    APL = {}
  };

  function AR.GUI.CorePanelSettingsInit ()
    -- GUI
    local ARPanel = CreatePanel(AR.GUI, "AethysRotation", "PanelFrame", AR.GUISettings, AethysRotationDB.GUISettings);
    -- Child Panel
    local CP_General = CreateChildPanel(ARPanel, "General");
    -- Controls
    CreatePanelOption("Dropdown", CP_General, "General.MainFrameStrata", {"HIGH", "MEDIUM", "LOW", "BACKGROUND"}, "Main Frame Strata", "Choose the frame strata to use for icons.", {ReloadRequired = true});
    CreatePanelOption("CheckButton", CP_General, "General.BlackBorderIcon", "Black Border Icon", "Enable if you want clean black borders icons.", {ReloadRequired = true});
    CreatePanelOption("CheckButton", CP_General, "General.HideKeyBinds", "Hide Keybinds", "Enable if you want to hide the keybind on the icons.");
    CreatePanelOption("CheckButton", CP_General, "General.InterruptEnabled", "Interrupt", "Enable if you want to interrupt.");
    CreatePanelOption("CheckButton", CP_General, "General.InterruptWithStun", "Interrupt With Stun", "EXPERIMENTAL: Enable if you want to interrupt with stuns.");
    CreatePanelOption("CheckButton", CP_General, "General.SoloMode", "Solo Mode", "Enable if you want to try to maximize survivability at the cost of dps.");
    CreatePanelOption("CheckButton", CP_General, "General.HideToggleIcons", "Hide toggle icons", "Enable if you want to hide the toggle buttons on the icon frame.", {ReloadRequired = true});
  end
