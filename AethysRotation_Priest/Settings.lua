--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Priest = {
    Commons = {
    },
    Shadow = {
      DispersionHP = 10,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        Shadowfiend = {true, false},
        Shadowform = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        PowerInfusion = {true, false},
        Dispersion = {true, false},
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
      }
    },
  };
