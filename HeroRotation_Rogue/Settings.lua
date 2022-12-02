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
    PoisonRefresh = 15,
    PoisonRefreshCombat = 3,
    RangedMultiDoT = true, -- Suggest Multi-DoT at 10y Range
    UsePriorityRotation = "Never", -- Only for Assassination / Subtlety
    UseTrinkets = true,
    TrinketDisplayStyle = "Suggested",
    CovenantDisplayStyle = "Suggested",
    SerratedBoneSpikeDumpDisplayStyle = "Suggested",
    ShowPooling = false,
    STMfDAsDPSCD = false, -- Single Target MfD as DPS CD
    GCDasOffGCD = {
      Racials = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
      Vanish = true,
      ShadowDance = true,
      ThistleTea = true,
      ColdBlood = true,
      MarkedforDeath = true,
    }
  },
  Commons2 = {
    CrimsonVialHP = 20,
    FeintHP = 10,
    StealthOOC = true,
    GCDasOffGCD = {
      CrimsonVial = true,
      Feint = true,
    },
    OffGCDasOffGCD = {
      Kick = true,
      Stealth = true,
    }
  },
  Assassination = {
    EnvenomDMGOffset = 3,
    MutilateDMGOffset = 3,
    AlwaysSuggestGarrote = false, -- Suggest Garrote even when Vanish is up
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
    Enabled = {
    },
    -- Roll the Bones Logic, accepts "SimC", "1+ Buff" and every "RtBName".
    -- "SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"
    RolltheBonesLogic = "SimC",
    -- SoloMode Settings
    RolltheBonesLeechKeepHP = 60, -- % HP threshold to keep Grand Melee while solo.
    RolltheBonesLeechRerollHP = 40, -- % HP threshold to reroll for Grand Melee while solo.
    UseDPSVanish = false, -- Use Vanish in the rotation for DPS
    KillingSpreeDisplayStyle = "Suggested",
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      BladeFlurry = false,
      BladeRush = false,
      GhostlyStrike = false,
      Dreadblades = false,
      KeepItRolling = false,
    },
    OffGCDasOffGCD = {
      AdrenalineRush = true,
    }
  },
  Subtlety = {
    EviscerateDMGOffset = 3, -- Used to compute the rupture threshold
    ShDEcoCharge = 1.75, -- Shadow Dance Eco Mode (Min Fractional Charges before using it while CDs are disabled)
    BurnShadowDance = "On Bosses not in Dungeons", -- Burn Shadow Dance charges when the target is about to die
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
CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.PoisonRefresh", {5, 55, 1}, "OOC Poison Refresh", "Set the timer for the Poison Refresh (OOC)")
CreatePanelOption("Slider", CP_Rogue, "APL.Rogue.Commons.PoisonRefreshCombat", {0, 55, 1}, "Combat Poison Refresh", "Set the timer for the Poison Refresh (In Combat)")
CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.RangedMultiDoT", "Suggest Ranged Multi-DoT", "Suggest multi-DoT targets at Fan of Knives range (10 yards) instead of only melee range. Disabling will only suggest DoT targets within melee range.")
CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.UsePriorityRotation", {"Never", "On Bosses", "Always", "Auto"}, "Use Priority Rotation", "Select when to show rotation for maximum priority damage (at the cost of overall AoE damage.)\nAuto will function as Never except on specific encounters where AoE is not recommended.")
CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.UseTrinkets", "Use Trinkets", "Use Trinkets as part of the rotation")
CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.TrinketDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Trinket Display Style", "Define which icon display style to use for Trinkets.")
CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.CovenantDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Covenant Display Style", "Define which icon display style to use for Covenants.")
CreatePanelOption("Dropdown", CP_Rogue, "APL.Rogue.Commons.SerratedBoneSpikeDumpDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Serrated Bone Spike Burn Display Style", "Define which icon display style to use for Serrated Bone Spike charge burning.")
CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.ShowPooling", "Show Pooling", "Show pooling icon instead of pooling prediction.")
CreatePanelOption("CheckButton", CP_Rogue, "APL.Rogue.Commons.STMfDAsDPSCD", "ST Marked for Death as DPS CD", "Enable if you want to put Single Target Marked for Death shown as Off GCD (top icons) instead of Suggested.")
CreateARPanelOptions(CP_Rogue, "APL.Rogue.Commons")
-- Rogue 2
CreatePanelOption("Slider", CP_Rogue2, "APL.Rogue.Commons2.CrimsonVialHP", {0, 100, 1}, "Crimson Vial HP", "Set the Crimson Vial HP threshold.")
CreatePanelOption("Slider", CP_Rogue2, "APL.Rogue.Commons2.FeintHP", {0, 100, 1}, "Feint HP", "Set the Feint HP threshold.")
CreatePanelOption("CheckButton", CP_Rogue2, "APL.Rogue.Commons2.StealthOOC", "Stealth Reminder (OOC)", "Show Stealth Reminder when out of combat.")
CreateARPanelOptions(CP_Rogue2, "APL.Rogue.Commons2")
-- Assassination
CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.EnvenomDMGOffset", {1, 5, 0.25}, "Envenom DMG Offset", "Set the Envenom DMG Offset.")
CreatePanelOption("Slider", CP_Assassination, "APL.Rogue.Assassination.MutilateDMGOffset", {1, 5, 0.25}, "Mutilate DMG Offset", "Set the Mutilate DMG Offset.")
CreatePanelOption("CheckButton", CP_Assassination, "APL.Rogue.Assassination.AlwaysSuggestGarrote", "Always Suggest Garrote", "Don't prevent Garrote suggestions when using Subterfuge and Vanish is ready. These should ideally be synced, but can be useful if holding Vanish for specific fights.")
CreateARPanelOptions(CP_Assassination, "APL.Rogue.Assassination")
-- Outlaw
CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLogic", {"SimC", "1+ Buff", "Broadside", "Buried Treasure", "Grand Melee", "Skull and Crossbones", "Ruthless Precision", "True Bearing"}, "Roll the Bones Logic", "Define the Roll the Bones logic to follow.\n(SimC highly recommended!)")
CreatePanelOption("Slider", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLeechKeepHP", {1, 100, 1}, "Keep Leech HP Threshold", "Set the HP threshold for keeping the leech buff instead of rerolling normally (working only if Solo Mode is enabled and does not work in dungeons.)")
CreatePanelOption("Slider", CP_Outlaw, "APL.Rogue.Outlaw.RolltheBonesLeechRerollHP", {1, 100, 1}, "Reroll For Leech HP Threshold", "Set the HP threshold to actively re-roll for the leech buff (working only if Solo Mode is enabled and does not work in dungeons.)")
CreatePanelOption("CheckButton", CP_Outlaw, "APL.Rogue.Outlaw.UseDPSVanish", "Use Vanish for DPS", "Suggest Vanish -> Ambush for DPS.\nDisable to save Vanish for utility purposes.")
CreatePanelOption("CheckButton", CP_Outlaw, "APL.Rogue.Outlaw.DumpSpikes", "Dump bonespike charges at end of boss fight", "Useful in raid, perhaps less so in dungeons.")
CreatePanelOption("Dropdown", CP_Outlaw, "APL.Rogue.Outlaw.KillingSpreeDisplayStyle", {"Main Icon", "Suggested", "SuggestedRight", "Cooldown"}, "Killing Spree Display Style", "Define which icon display style to use for Killing Spree.")
CreateARPanelOptions(CP_Outlaw, "APL.Rogue.Outlaw")
-- Subtlety
CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.EviscerateDMGOffset", {1, 5, 0.25}, "Eviscerate Damage Offset", "Set the Eviscerate Damage Offset, used to compute the rupture threshold.")
CreatePanelOption("Slider", CP_Subtlety, "APL.Rogue.Subtlety.ShDEcoCharge", {1, 2, 0.1}, "ShD Eco Charge", "Set the Shadow Dance Eco Charge threshold.")
CreatePanelOption("Dropdown", CP_Subtlety, "APL.Rogue.Subtlety.BurnShadowDance", {"Always", "On Bosses", "On Bosses not in Dungeons"}, "Burn Shadow Dance before Death", "Use remaining Shadow Dance charges when the target is about to die.")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Vanish", "Stealth Combo - Vanish", "Allow suggesting Vanish stealth ability combos (recommended)")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.Shadowmeld", "Stealth Combo - Shadowmeld", "Allow suggesting Shadowmeld stealth ability combos (recommended)")
CreatePanelOption("CheckButton", CP_Subtlety, "APL.Rogue.Subtlety.StealthMacro.ShadowDance", "Stealth Combo - Shadow Dance", "Allow suggesting Shadow Dance stealth ability combos (recommended)")
CreateARPanelOptions(CP_Subtlety, "APL.Rogue.Subtlety")
