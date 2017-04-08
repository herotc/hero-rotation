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
      -- Black Border Icon (Disable if you use custom icons)
      BlackBorderIcon = true,
      -- Interrupt
      InterruptEnabled = false,
      InterruptWithStun = false, -- EXPERIMENTAL
      -- SoloMode try to maximize survivability at the cost of dps
      SoloMode = false,
    },
    APL = {
      DemonHunter = {
        Vengeance = {
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
            -- Abilities
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
      },
      Hunter = {
          Commons = {
          -- SoloMode Settings
          ExhilarationHP = 30,
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
            -- Abilities
            Exhilaration = {true, false}
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
            -- Racials
            ArcaneTorrent = {true, false},
            Berserking = {true, false},
            BloodFury = {true, false},
            -- Abilities
            CounterShot = {true, false}
          }
        },
        BeastMastery = {
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
            -- Abilities
            Volley = {true, false}
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
            -- Abilities
            AspectoftheWild = {true, false},
            BeastialWrath = {true, false},
            TitansThunder = {true, false}
          }
        },
        Marksmanship = {
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
            -- Abilities
            Volley = {true, false}
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
          }
        },
        Survival = {
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
            -- Abilities
            AspectoftheEagle = {true, false},
            Butchery = {true, false},
            SnakeHunter = {true, false},
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
      },
      Priest = {
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
        Commons = {
          -- SoloMode Settings
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
            Pummel = {true, false}
          }
        },
        Arms = {
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
          }
        },
        Fury = {
          -- {Display GCD as OffGCD, ForceReturn}
          GCDasOffGCD = {
          },
          -- {Display OffGCD as OffGCD, ForceReturn}
          OffGCDasOffGCD = {
            -- Abilities
            Avatar = {true, false},
            BattleCry = {true, false}
          }
        }
      }
    }
  };
