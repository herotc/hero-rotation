--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Paladin = {
    Protection = {
      -- CDs HP %
      EyeofTyrHP = 60,
      HandoftheProtectorHP = 80,
      LightoftheProtectorHP = 80,
      ShieldoftheRighteousHP = 70,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        -- Abilities
        AvengingWrath = {true, false},
        HandoftheProtector = {true, false},
        LightoftheProtector = {true, false},
        ShieldoftheRighteous = {true, false}
      }
    },
    Retribution = {
      -- SoloMode Settings
      SoloJusticarDP = 80, -- % HP threshold to use Justicar's Vengeance with Divine Purpose proc.
      SoloJusticar5HP = 60, -- % HP threshold to use Justicar's Vengeance with 5 Holy Power.
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        -- Abilities
        HolyWrath = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        -- Abilities
        AvengingWrath = {true, false},
        Crusade = {true, false}
      }
    }
  };
