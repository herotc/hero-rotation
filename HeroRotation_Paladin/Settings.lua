--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
HR.GUISettings.APL.Paladin = {
  Commons = {
    Enabled = {
      Trinkets = true,
      Potions = true,
      Items = true,
    },
    DisplayStyle = {
      Trinkets = "Suggested",
      Signature = "Suggested",
      Potions = "Suggested",
      Items = "Suggested",
    },
    GCDasOffGCD = {
      HammerOfWrath = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
      Rebuke = true,
    }
  },
  Protection = {
    -- CDs HP %
    ArdentDefenderHP = 60,
    GoAKHP = 40,
    LoHHP = 15,
    PrioSelfWordofGloryHP = 40,
    SotRHP = 70,
    PotionType = {
      Selected = "Power",
    },
    DisplayStyle = {
      Defensives = "SuggestedRight",
      ShieldOfTheRighteous = "SuggestedRight",
    },
    GCDasOffGCD = {
      EyeOfTyr = false,
      Seraphim = true,
      WordOfGlory = true,
    },
    OffGCDasOffGCD = {
      AvengingWrath = true,
      BastionOfLight = true,
      HolyAvenger = true,
      MomentOfGlory = true,
      Sentinel = true,
    }
  },
  Retribution = {
    DisableCrusadeAWCDCheck = false,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      ExecutionSentence = false,
      FinalReckoning = false,
      Seraphim = false,
      ShieldOfVengeance = true,
      WakeOfAshes = false,
    },
    OffGCDasOffGCD = {
      AvengingWrath = true,
    },
  },
  Holy = {
    LoHHP = 10,
    DPHP = 40,
    WoGHP = 60,
    PotionType = {
      Selected = "Power",
    },
    GCDasOffGCD = {
      HammerOfWrath = false,
      LightOfDawn = true,
      Seraphim = true,
    },
    OffGCDasOffGCD = {
      AvengingWrath = true,
      HolyAvenger = true,
    },
  },
}
-- GUI
HR.GUI.LoadSettingsRecursively(HR.GUISettings)
-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Paladin = CreateChildPanel(ARPanel, "Paladin")
local CP_Protection = CreateChildPanel(CP_Paladin, "Protection")
local CP_Protection2 = CreateChildPanel(CP_Paladin, "Protection2")
local CP_Retribution = CreateChildPanel(CP_Paladin, "Retribution")
local CP_Holy = CreateChildPanel(CP_Paladin, "Holy")

-- Shared Paladin settings
CreateARPanelOptions(CP_Paladin, "APL.Paladin.Commons")

-- Protection
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.LoHHP", {0, 100, 1}, "Lay on Hands HP", "Set the Lay on Hands HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.GoAKHP", {0, 100, 1}, "GoAK HP", "Set the Guardian of Ancient Kings HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.SotRHP", {0, 100, 1}, "SotR HP", "Set the Shield of the Righteous HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.ArdentDefenderHP", {0, 100, 1}, "Ardent Defender HP", "Set the Ardent Defender HP threshold.")
CreatePanelOption("Slider", CP_Protection, "APL.Paladin.Protection.PrioSelfWordofGloryHP", {0, 100, 1}, "Prio Self Word of Glory HP", "Set the Word of Glory HP threshold for casting on ourself: if we drop below this HP, we'll prio WOG over economy globals.")
CreateARPanelOptions(CP_Protection2, "APL.Paladin.Protection")

-- Retribution
CreateARPanelOptions(CP_Retribution, "APL.Paladin.Retribution")
CreatePanelOption("CheckButton", CP_Retribution, "APL.Paladin.Retribution.DisableCrusadeAWCDCheck", "Disable Crusade/AW CD Checks for Finishers and Cooldowns", "Enable this option to ignore the status of Crusade and Avenging Wrath when deciding whether to suggest finishers or other 'cooldown' abilities. NOTE: This causes the addon to stray from the APL, which will result in a DPS LOSS, but allows for smoother gameplay suggestions when you need to hold Crusade for any reason.")

-- Holy
CreateARPanelOptions(CP_Holy, "APL.Paladin.Holy")
CreatePanelOption("Slider", CP_Holy, "APL.Paladin.Holy.LoHHP", {0, 100, 1}, "Lay on Hands HP", "Set the Lay on Hands HP threshold.")
CreatePanelOption("Slider", CP_Holy, "APL.Paladin.Holy.DPHP", {0, 100, 1}, "Divine Protection HP", "Set the Divine Protection HP threshold.")
CreatePanelOption("Slider", CP_Holy, "APL.Paladin.Holy.WoGHP", {0, 100, 1}, "Word of Glory HP", "Set the Word of Glory HP threshold.")
