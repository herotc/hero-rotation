--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
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
