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
        MoonkinForm = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        BlessingofElune = {true, false},
        AstralCommunion = {true, false}
      }
    }
  };
