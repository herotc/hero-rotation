local addonName, ER = ...;

-- All settings here should be moved into the GUI someday
ER.GUISettings = {
  General = {
    -- Main Frame Strata
    MainFrameStrata = "BACKGROUND",
    -- Black Border Icon (Disable if you use custom icons)
    BlackBorderIcon = true,
    -- Recovery Timer
    RecoveryMode = "GCD"; -- "GCD" to always display the next ability, "Custom" for Custom RecoveryTimer
    RecoveryTimer = 950;
    -- Interrupt
    InterruptEnabled = false,
    InterruptWithStun = false, -- EXPERIMENTAL
    -- SoloMode try to maximize survivability at the cost of dps
    SoloMode = false,
    -- Blacklist Settings
    Blacklist = {
      -- During how many times the GCD time you want to blacklist an unit from Cycling
      -- when you got an error when trying to cast on it
      NotFacingExpireMultiplier = 3,
      -- Custom List (User Defined), must be a valid Lua Boolean or Function as Value and have the NPCID as Key
      UserDefined = {
        -- Example with fake NPCID:
        -- [123456] = true;
        -- [123456] = function (self) return self:HealthPercentage() <= 80 and true or false; end
        -- Tito Pet Cows
        [71444] = true;
      },
      -- Custom Cycle List (User Defined), must be a valid Lua Boolean or Function as Value and have the NPCID as Key
      CycleUserDefined = {
        -- Example with fake NPCID:
        -- [123456] = true;
        -- [123456] = function (self) return self:HealthPercentage() <= 80 and true or false; end
      }
    }
  },
  NameplatesTTD = {
    XOffset = 5,
    YOffset = -11
  },
  APL = {
    DemonHunter = {
      Vengeance = {
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
          -- Spec
          ConsumeMagic = {true, false},
          DemonSpikes = {true, false},
          InfernalStrike = {true, false}
        }
      }
    },
    Druid = {
      Feral = {
        -- {Display GCD as OffGCD, ForceReturn}
        GCDasOffGCD = {
        },
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
        }
      }
    },
    Paladin = {
      Retribution = {
        -- SoloMode Settings
        SoloJusticarDP = 80, -- % HP threshold to use Justicar's Vengeance with Divine Purpose proc.
        SoloJusticar5HP = 60, -- % HP threshold to use Justicar's Vengeance with 5 Holy Power.
        -- {Display GCD as OffGCD, ForceReturn}
        GCDasOffGCD = {
          HolyWrath = {true, false}
        },
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
          -- Racials
          ArcaneTorrent = {true, false},
          -- Spec
          AvengingWrath = {true, false},
          Crusade = {true, false}
        }
      }
    },
    Rogue = {
      Commons = {
        -- SoloMode Settings
        CrimsonVialHP = 30,
        FeintHP = 10,
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
          MarkedforDeath = {false, false},
          Sprint = {true, false},
          Stealth = {true, false}
        }
      },
      Assassination = {
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
        BFOffset = 3,
        -- SoloMode Settings
        RolltheBonesLeechHP = 60, -- % HP threshold to reroll for Grand Melee.
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
        -- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
        ShDEcoCharge = 2.45,
        -- Eviscerate Damage Offset
        EviscerateDMGOffset = 3,
        -- Shadowstrike Max Range
        ShadowstrikeMaxRange = true,
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
    },
    Shaman = {
      Enhancement = {
        --{Display GCD as OffGcd, ForceReturn}
        GCDasOffGCD = {
          -- Abilities
          FeralSpirit = {true, false}
        },
        --{Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
          -- Abilities 
          DoomWinds = {true, false},
          -- Legendaries
          StormTempests = {true, false},
          EmalonChargedCore = {true, false},
          -- Kick
          WindShear = {true, false},
          -- Racial
          Berserking = {true, false}
        }
      }
    },
    Warrior = {
      Arms = {
        -- {Display GCD as OffGCD, ForceReturn}
        GCDasOffGCD = {
        },
        -- {Display OffGCD as OffGCD, ForceReturn}
        OffGCDasOffGCD = {
        }
      }
    }
  }
};
