--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Druid = {
    Feral = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
      }
    },
    Balance = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
		-- Abilities
        MoonkinForm = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
		-- Abilities
        BlessingofElune = {true, false},
        AstralCommunion = {true, false},
        IncarnationChosenOfElune = {true, false},
        CelestialAlignment = {true, false},
		
		
		--Racials
		ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
      }
    }
  };
