--- Localize Vars
-- Addon
local addonName, AR = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCore_Cache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;
-- Lua
local mathmax = math.max;
local mathmin = math.min;
local pairs = pairs;
local select = select;

-- Create the MainFrame
AR.MainFrame = CreateFrame("Frame", "AethysRotation_MainFrame", UIParent);
AR.MainFrame:SetFrameStrata(AR.GUISettings.General.MainFrameStrata);
AR.MainFrame:SetWidth(112);
AR.MainFrame:SetHeight(116);
AR.MainFrame:SetClampedToScreen(true);
AR.MainFrame:EnableMouse(true);
AR.MainFrame:SetMovable(true);
  -- Start Move
  AR.MainFrame:SetScript("OnMouseDown",
    function (self)
      if IsShiftKeyDown() then
        self:StartMoving();
      end
    end
  );
  -- Stop Move
  AR.MainFrame:SetScript("OnMouseUp",
    function (self)
      if IsShiftKeyDown() then
        self:StopMovingOrSizing();
        if not AethysRotationDB then
          AethysRotationDB = {};
        end
        AethysRotationDB.IconFramePos = {self:GetPoint()};
      end
    end
  );
-- AddonLoaded
AR.MainFrame:RegisterEvent("ADDON_LOADED");
AR.MainFrame:SetScript("OnEvent", function (self, Event, Arg1)
    if Event == "ADDON_LOADED" then
      if Arg1 == "AethysRotation" then
        if AethysRotationDB and AethysRotationDB.IconFramePos then
          AR.MainFrame:SetPoint(AethysRotationDB.IconFramePos[1], UIParent, AethysRotationDB.IconFramePos[3], AethysRotationDB.IconFramePos[4], AethysRotationDB.IconFramePos[5]);
        else
          AR.MainFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0);
        end
        AR.MainFrame:Show();
        AR.MainIconFrame:Init();
        AR.SmallIconFrame:Init();
        AR.LeftIconFrame:Init();
        AR.ToggleIconFrame:Init();
        C_Timer.After(2, function ()
            AR.MainFrame:UnregisterEvent("ADDON_LOADED");
            AR.PulsePreInit();
            AR.MainFrame:SetScript("OnUpdate", AR.PulseInit);
          end
        );
      end
    end
  end
);

--- Main
  local FrameToModify;
  function AR.PulsePreInit ()
    FrameToModify = {
      AR.MainFrame;
      AR.MainIconFrame;
      AR.SmallIconFrame;
      AR.SmallIconFrame.Icon[1];
      AR.SmallIconFrame.Icon[2];
      AR.LeftIconFrame;
      AR.ToggleIconFrame;
    };
  end
  local EnabledRotation = {
    -- Death Knight
      [250]   = false,                          -- Blood
      [251]   = false,                          -- Frost
      [252]   = false,                          -- Unholy
    -- Demon Hunter
      [577]   = false,                          -- Havoc
      [581]   = "AethysRotation_DemonHunter",   -- Vengeance
    -- Druid
      [102]   = false,                          -- Balance
      [103]   = false,                          -- Feral
      [104]   = false,                          -- Guardian
      [105]   = false,                          -- Restoration
    -- Hunter
      [253]   = false,                          -- Beast Mastery
      [254]   = false,                          -- Marksmanship
      [255]   = false,                          -- Survival
    -- Mage
      [62]    = false,                          -- Arcane
      [63]    = false,                          -- Fire
      [64]    = false,                          -- Frost
    -- Monk
      [268]   = false,                          -- Brewmaster
      [269]   = false,                          -- Windwalker
      [270]   = false,                          -- Mistweaver
    -- Paladin
      [65]    = false,                          -- Holy
      [66]    = false,                          -- Protection
      [70]    = "AethysRotation_Paladin",       -- Retribution
    -- Priest
      [256]   = false,                          -- Discipline
      [257]   = false,                          -- Holy
      [258]   = false,                          -- Shadow
    -- Rogue
      [259]   = false,                          -- Assassination
      [260]   = "AethysRotation_Rogue",         -- Outlaw
      [261]   = "AethysRotation_Rogue",         -- Subtlety
    -- Shaman
      [262]   = false,                          -- Elemental
      [263]   = "AethysRotation_Shaman",        -- Enhancement
      [264]   = false,                          -- Restoration
    -- Warlock
      [265]   = false,                          -- Affliction
      [266]   = false,                          -- Demonology
      [267]   = false,                          -- Destruction
    -- Warrior
      [71]    = false,                          -- Arms
      [72]    = false,                          -- Fury
      [73]    = false                           -- Protection
  };
  local AddonIsLoaded = {};
  function AR.PulseInit ()
    -- Force a refresh from the Core
    -- TODO: Make it a function instead of copy/paste from Core Events.lua
    Cache.Persistent.Player.Class = {UnitClass("player")};
    Cache.Persistent.Player.Spec = {GetSpecializationInfo(GetSpecialization())};

    -- Load the Class Module if it's possible and not already loaded
    if EnabledRotation[Cache.Persistent.Player.Spec[1]] and not AddonIsLoaded[EnabledRotation[Cache.Persistent.Player.Spec[1]]] then
      LoadAddOn(EnabledRotation[Cache.Persistent.Player.Spec[1]]);
      AddonIsLoaded[EnabledRotation[Cache.Persistent.Player.Spec[1]]] = true;
    end

    -- Check if there is a Rotation for this Spec
    if EnabledRotation[Cache.Persistent.Player.Spec[1]] and AR.APLs[Cache.Persistent.Player.Spec[1]] then
      for Key, Value in pairs(FrameToModify) do
        Value:Show();
      end
      AR.MainFrame:SetScript("OnUpdate", AR.Pulse);
    else
      AR.Print("No Rotation found for this class/spec, addon disabled.");
      for Key, Value in pairs(FrameToModify) do
        Value:Hide();
      end
      AR.MainFrame:SetScript("OnUpdate", nil);
    end
  end

  AR.Timer = {
    Pulse = 0
  };
  function AR.Pulse ()
    if AC.GetTime() > AR.Timer.Pulse then
      AR.Timer.Pulse = AC.GetTime() + AC.Timer.PulseOffset; 

      AR.ResetIcons();

      -- Check if we are ready to cast something to save FPS.
      if AR.ON() and AR.Ready() then
        AC.CacheHasBeenReset = false;
        AC.CacheReset();
        AR.APLs[Cache.Persistent.Player.Spec[1]]();
      end
    end
  end

-- Is the player ready ?
-- TODO : IsCasting() and IsChanneling() may gives issues for Casters because I assume some may have to interrupt their casts/channels
--   to cast something else. Will also need tweak to handle the bosses that interrupts casts.
function AR.Ready ()
  return not Player:IsDeadOrGhost() and not Player:IsMounted() and not Player:IsCasting() and not Player:IsChanneling();
end

-- Used to force a short/long pulse wait, it also resets the icons.
function AR.ChangePulseTimer (Offset)
  AR.ResetIcons();
  AR.Timer.Pulse = AC.GetTime() + Offset;
end