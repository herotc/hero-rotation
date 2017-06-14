--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Shaman = {
    Enhancement = {
      --{Display GCD as OffGcd, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
		FeralSpirit = {true, false},
		Ascendance = {true, false}
      },
      --{Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
		-- Abilities
		DoomWinds = {true, false},
		-- Interrupt
		WindShear = {true, false},
        -- Racial
        Berserking = {true, false};
        BloodFury = {true, false}
      }
    }
  }
