--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysRotation
  local AR = AethysRotation;


--- ============================ CONTENT ============================
  -- All settings here should be moved into the GUI someday.
  AR.GUISettings.APL.Rogue = {
    Commons = {
      -- SoloMode Settings
      CrimsonVialHP = 0,
      FeintHP = 0,
      -- Evisc/Env Mantle Damage Offset Multiplier
      EDMGMantleOffset = 2,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
        CrimsonVial = {true, false},
        Feint = {true, false}
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Racials
        ArcaneTorrent = {true, false},
        Berserking = {true, false},
        BloodFury = {true, false},
        -- Stealth CDs
        Shadowmeld = {true, false},
        Vanish = {true, false},
        -- Abilities
        Kick = {true, false},
        MarkedforDeath = {true, false},
        Sprint = {true, false},
        Stealth = {true, false}
      }
    },
    Assassination = {
      -- Damage Offsets
      EnvenomDMGOffset = 3,
      MutilateDMGOffset = 3,
      -- Poison Refresh (in seconds)
      PoisonRefresh = 15 * 60, -- *60 to convert it to seconds
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        Vendetta = {true, false}
      }
    },
    Outlaw = {
      -- Roll the Bones Logic, accepts "Default", "1+ Buff" and every "RtBName".
      -- "Default", "1+ Buff", "Broadsides", "Buried Treasure", "Grand Melee", "Jolly Roger", "Shark Infested Waters", "True Bearing"
      RolltheBonesLogic = "Default",
      -- Blade Flurry TimeOut
      BFOffset = 2,
      -- SoloMode Settings
      RolltheBonesLeechHP = 60, -- % HP threshold to reroll for Grand Melee.
      -- Pistol Shot icon for Blunderbuss
      BlunderbussAsPistolShot = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        AdrenalineRush = {true, false},
        CurseoftheDreadblades = {true, false},
        BladeFlurry = {true, false},
      }
    },
    Subtlety = {
      -- Damage Offsets
      EviscerateDMGOffset = 3,
      -- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
      ShDEcoCharge = 2.45,
      -- Sprint as DPS CD
      SprintAsDPSCD = true,
      -- {Display GCD as OffGCD, ForceReturn}
      GCDasOffGCD = {
      },
      -- {Display OffGCD as OffGCD, ForceReturn}
      OffGCDasOffGCD = {
        -- Abilities
        ShadowBlades = {true, false},
        SymbolsofDeath = {true, false}
      }
    }
  };
