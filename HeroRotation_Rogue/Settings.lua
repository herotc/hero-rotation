--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
  -- HeroLib
local HL = HeroLib
-- HeroRotation
local HR = HeroRotation
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions


--- ============================ CONTENT ============================
-- Default settings
HR.GUISettings.APL.Rogue = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
    DisplayStyle = {
      Potions = "Suggested",
      Signature = "Suggested",
      Trinkets = "Suggested",
      Items = "Suggested",
      Stealth = "Main Icon",
    },
    GCDasOffGCD = {
      EchoingReprimand = true,
      CrimsonVial = true,
      Feint = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
      Vanish = true,
      ShadowDance = true,
      ThistleTea = true,
      ColdBlood = true,
    }
  },
  Commons2 = {
    ShowStealthOOC = true,
    ShowPoisonOOC = true,
    CrimsonVialHP = 30,
    RangedMultiDoT = true, -- Suggest Multi-DoT at 10y Range
    UseSoloVanish = false, -- don't vanish while solo
    UseDPSVanish = true, -- allow the use of vanish for dps (checking for if you're solo)
    ShowPooling = true,
  },
  Assassination = {
    EnvenomDMGOffset = 3,
    MutilateDMGOffset = 3,
    UsePriorityRotation = "Never", -- Only for Assassination / Subtlety
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      Exsanguinate = false,
      Kingsbane = false,
      Shiv = false,
    },
    OffGCDasOffGCD = {
      Deathmark = true,
      IndiscriminateCarnage = true,
    }
  },
  Outlaw = {
    -- Roll the Bones Logic, accepts "SimC", "1+ Buff" and every "RtBName".
    -- "SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"
    RolltheBonesLogic = "SimC",
    KillingSpreeDisplayStyle = "Suggested",
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      BladeFlurry = false,
      BladeRush = false,
      KeepItRolling = false,
      RollTheBones = false,
      Sepsis = false,
    },
    OffGCDasOffGCD = {
      GhostlyStrike = false,
      AdrenalineRush = true,
    }
  },
  Subtlety = {
    EviscerateDMGOffset = 3, -- Used to compute the rupture threshold
    BurnShadowDance = "On Bosses not in Dungeons", -- Burn Shadow Dance charges when the target is about to die
    UsePriorityRotation = "Never", -- Only for Assassination / Subtlety
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      ShurikenTornado = false,
    },
    OffGCDasOffGCD = {
      SymbolsofDeath = true,
      ShadowDance = true,
      ShadowBlades = true,
    },
    StealthMacro = {
      Vanish = true,
      Shadowmeld = true,
      ShadowDance = true
    }
  }
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Rogue = CreateChildPanel(ARPanel, "Rogue")
local CP_Rogue2 = CreateChildPanel(ARPanel, "Rogue 2")
local CP_Assassination = CreateChildPanel(ARPanel, "Assassination")
local CP_Outlaw = CreateChildPanel(ARPanel, "Outlaw")
local CP_Subtlety = CreateChildPanel(ARPanel, "Subtlety")
-- Controls
-- Rogue
CreateARPanelOptions(CP_Rogue, "APL.Rogue.Commons")
-- Rogue 2
CreatePanelOption("Slider", CP_Rogue2, "APL.Rogue.Commons2.CrimsonVialHP", {0, 100, 1}, "Crimson Vial HP", "Set the Crimson Vial HP threshold.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.ShowStealthOOC", "Stealth While OOC", "Suggest Stealth while out of combat.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.ShowPoisonOOC", "Poisons While OOC", "Suggest Poisons while out of combat.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.RangedMultiDoT", "Suggest Ranged Multi-DoT", "Suggest multi-DoT targets at Fan of Knives range (10 yards) instead of only melee range. Disabling will only suggest DoT targets within melee range.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.UseDPSVanish", "Use Vanish for DPS", "Suggest Vanish for DPS.\nDisable to save Vanish for utility purposes.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.UseSoloVanish", "Use Vanish while Solo", "Suggest Vanish while Solo.\nDisable to save prevent mobs resetting.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.ShowPooling", "Show Pooling Icon", "Show pooling icon instead of pooling prediction.")
CreateARPanelOptions(CP_Rogue2, "APL.Rogue.Commons2")
-- Assassination
CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.EnvenomDMGOffset", {1, 5, 0.25}, "Envenom DMG Offset", "Set the Envenom DMG Offset.")
CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.MutilateDMGOffset", {1, 5, 0.25}, "Mutilate DMG Offset", "Set the Mutilate DMG Offset.")
CreatePanelOption("Dropdown", CP_Assassination, "APL.Rogue.Assassination.UsePriorityRotation", {"Never", "On Bosses", "Always", "Auto"}, "Use Priority Rotation", "Select when to show rotation for maximum priority damage (at the cost of overall AoE damage.)\nAuto will function as Never except on specific encounters where AoE is not recommended.")
CreateARPanelOptions(CP_Assassination, "APL.Rogue.Assassination")
-- Outlaw
CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLogic", {"SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"}, "Roll the Bones Logic", "Define the Roll the Bones logic to follow.\n(SimC highly recommended!)")
CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.KillingSpreeDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Killing Spree Display Style", "Define which icon display style to use for Killing Spree.")
CreateARPanelOptions(CP_Outlaw, "APL.Rogue.Outlaw")
-- Subtlety
CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.EviscerateDMGOffset", {1, 5, 0.25}, "Eviscerate Damage Offset", "Set the Eviscerate Damage Offset, used to compute the rupture threshold.")
CreatePanelOption("Dropdown", CP_Subtlety, "APL.Rogue.Subtlety.UsePriorityRotation", {"Never", "On Bosses", "Always", "Auto"}, "Use Priority Rotation", "Select when to show rotation for maximum priority damage (at the cost of overall AoE damage.)\nAuto will function as Never except on specific encounters where AoE is not recommended.")
CreatePanelOption("Dropdown", CP_Subtlety, "APL.Rogue.Subtlety.BurnShadowDance", {"Always", "On Bosses", "On Bosses not in Dungeons"}, "Burn Shadow Dance before Death", "Use remaining Shadow Dance charges when the target is about to die.")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Vanish", "Stealth Combo - Vanish", "Allow suggesting Vanish stealth ability combos (recommended)")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.ShadowDance", "Stealth Combo - Shadow Dance", "Allow suggesting Shadow Dance stealth ability combos (recommended)")
CreateARPanelOptions(CP_Subtlety, "APL.Rogue.Subtlety")
