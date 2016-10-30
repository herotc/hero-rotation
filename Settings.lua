local addonName, ER = ...;

-- All settings here should be moved into the GUI someday
ER.GUISettings = {
	General = {
		-- Main Frame Strata
		MainFrameStrata = "HIGH",
		-- Recovery Timer
		Recovery = 950,
		-- Interrupt
		InterruptEnabled = false
	},
	NameplatesTTD = {
		XOffset = 5,
		YOffset = -11
	},
	APL = {
		DemonHunter = {
			Vengeance = {

			}
		},
		Paladin = {
			Retribution = {

			}
		},
		Rogue = {
			Outlaw = {
				-- Roll the Bones Logic, accepts "Default", "1+ Buff" and every "RtBName".
				-- Useful for Cenarius where you want to fish for Cenarius
				-- "Default", "1+ Buff", "Broadsides", "Buried Treasure", "Grand Melee", "Jolly Roger", "Shark Infested Waters", "True Bearing"
				RolltheBonesLogic = "Default";
				RolltheBonesLeechHP = 60; -- False or % HP, reroll for Grand Melee when HP <.
				-- Blade Flurry TimeOut
				BFOffset = 3;
			},
			Subtlety = {
				-- Shadow Dance
				ShD = {
					-- Eco Mode
					EcoCharge = 2,
					EcoCD = 20
				}
			}
		}
	}
};
