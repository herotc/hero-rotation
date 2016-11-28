local addonName, ER = ...;

-- All settings here should be moved into the GUI someday
ER.GUISettings = {
	General = {
		-- Main Frame Strata
		MainFrameStrata = "HIGH",
		-- Recovery Timer
		RecoveryMode = "GCD"; -- "GCD" to always display the next ability, "Custom" for Custom Timer.
		RecoveryTimer = 950;
		-- Interrupt
		InterruptEnabled = false,
		-- Blacklist Settings
		Blacklist = {
			-- During how many times the GCD time you want to blacklist an unit from Cycling
			-- when you got an error when trying to cast on it.
			NotFacingExpireMultiplier = 3
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
		Paladin = {
			Retribution = {
				-- SoloMode try to maximize survivability when not near full life
				SoloMode = true,
				SoloJusticarDP = 80,
				SoloJusticar5HP = 60,
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
			Assassination = {
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
					Vanish = {true, false},
					-- Spec
					Kick = {true, false},
					MarkedforDeath = {false, false},
					Stealth = {true, false},
					Vendetta = {true, false}
				}
			},
			Outlaw = {
				-- Roll the Bones Logic, accepts "Default", "1+ Buff" and every "RtBName".
				-- Useful for Cenarius where you want to fish for Cenarius
				-- "Default", "1+ Buff", "Broadsides", "Buried Treasure", "Grand Melee", "Jolly Roger", "Shark Infested Waters", "True Bearing"
				RolltheBonesLogic = "Default",
				RolltheBonesLeechHP = 60, -- False or % HP, reroll for Grand Melee when HP <.
				-- Blade Flurry TimeOut
				BFOffset = 3,
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
					-- Spec
					AdrenalineRush = {true, false},
					CurseoftheDreadblades = {true, false},
					BladeFlurry = {true, false},
					Kick = {true, false},
					MarkedforDeath = {false, false},
					Sprint = {true, false},
					Stealth = {true, false},
					SymbolsofDeath = {true, false}
				}
			},
			Subtlety = {
				-- T18 Prepull
				T18Prepull = {
					Enabled = true,
					-- SprintStart, SprintEnd, SwitchFallback
					PullTime = {5, 4, 1},
					EquipmentSetID = 2
				},
				-- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
				ShDEcoCharge = 2.8,
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
					ShadowDance = {true, false},
					Shadowmeld = {true, false},
					Vanish = {true, false},
					-- Spec
					Kick = {true, false},
					MarkedforDeath = {false, false},
					ShadowBlades = {true, false},
					Stealth = {true, false},
					SymbolsofDeath = {true, false}
				}
			}
		}
	}
};
