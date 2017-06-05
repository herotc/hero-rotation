--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.DeathKnight = {
    Commons = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities

      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
        -- Abilities
        
      }
    },
   Frost = {
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        PillarOfFrost = {true, false},
        HungeringRuneWeapon = {true, false},
        EmpowerRuneWeapon = {true, false},
        Obliteration = {true, false},
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        
        -- Abilities
        
      }
    }
  };
