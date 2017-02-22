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
  -- Main Variables
  local UIFrames;

--- MainFrame
  AR.MainFrame = CreateFrame("Frame", "AethysRotation_MainFrame", UIParent);
  AR.MainFrame:SetFrameStrata(AR.GUISettings.General.MainFrameStrata);
  AR.MainFrame:SetFrameLevel(10);
  AR.MainFrame:SetWidth(112);
  AR.MainFrame:SetHeight(96);

  AR.MainFrame:SetClampedToScreen(true);
    -- Resize
    function AR.MainFrame:ResizeUI (Multiplier)
      local FramesToResize = {
        -- TODO: Put the Size in one Array in UI.lua and pull it out here
        {AR.MainFrame, 112, 96},
        {AR.MainIconFrame, 64, 64},
        {AR.SmallIconFrame, 64, 32},
        {AR.SmallIconFrame.Icon[1], AR.GUISettings.General.BlackBorderIcon and 30 or 32, AR.GUISettings.General.BlackBorderIcon and 30 or 32},
        {AR.SmallIconFrame.Icon[2], AR.GUISettings.General.BlackBorderIcon and 30 or 32, AR.GUISettings.General.BlackBorderIcon and 30 or 32},
        {AR.LeftIconFrame, 48, 48}
      };
      for Key, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
      AethysRotationDB.ScaleUI = Multiplier;
    end
    function AR.MainFrame:ResizeButtons (Multiplier)
      local FramesToResize = {
        -- TODO: Put the Size in one Array in UI.lua and pull it out here
        {AR.ToggleIconFrame, 64, 20},
        {AR.Button[1], 20, 20},
        {AR.Button[2], 20, 20},
        {AR.Button[3], 20, 20}
      };
      for Key, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
      for i = 1, 3 do
        AR.Button[i]:SetPoint("LEFT", AR.ToggleIconFrame, "LEFT", AR.Button[i]:GetWidth()*(i-1)+i, 0);
      end
      AethysRotationDB.ScaleButtons = Multiplier;
    end
    -- Lock/Unlock
    local LockSpell = Spell(9999000001);
    function AR.MainFrame:Unlock ()
      -- Grey Texture
      AR.ResetIcons();
      AR.Cast(LockSpell, {false});  -- Main Icon
      AR.Cast(LockSpell, {true});   -- Small Icon 1
      AR.Cast(LockSpell, {true});   -- Small Icon 2
      AR.LeftIconFrame:ChangeIcon(AR.GetTexture(LockSpell));
      -- Unlock the UI
      for Key, Value in pairs(UIFrames) do
        Value:EnableMouse(true);
      end
      AR.MainFrame:SetMovable(true);
      AR.ToggleIconFrame:SetMovable(true);
      AethysRotationDB.Locked = false;
    end
    function AR.MainFrame:Lock ()
      for Key, Value in pairs(UIFrames) do
        Value:EnableMouse(false);
      end
      AR.MainFrame:SetMovable(false);
      AR.ToggleIconFrame:SetMovable(false);
      AethysRotationDB.Locked = true;
    end
    -- Start Move
    local function StartMove (self)
      self:StartMoving();
    end
    AR.MainFrame:SetScript("OnMouseDown", StartMove);
    -- Stop Move
    local function StopMove (self)
      self:StopMovingOrSizing();
      if not AethysRotationDB then AethysRotationDB = {}; end
      AethysRotationDB.IconFramePos = {self:GetPoint()};
    end
    AR.MainFrame:SetScript("OnMouseUp", StopMove);
    AR.MainFrame:SetScript("OnHide", StopMove);
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
          if AethysRotationDB.ScaleUI then
            AR.MainFrame:ResizeUI(AethysRotationDB.ScaleUI);
          end
          if AethysRotationDB.ScaleButtons then
            AR.MainFrame:ResizeButtons(AethysRotationDB.ScaleButtons);
          end
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
  function AR.PulsePreInit ()
    UIFrames = {
      AR.MainFrame;
      AR.MainIconFrame;
      AR.SmallIconFrame;
      AR.SmallIconFrame.Icon[1];
      AR.SmallIconFrame.Icon[2];
      AR.LeftIconFrame;
      AR.ToggleIconFrame;
    };
    AR.MainFrame:Lock();
  end
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
      for Key, Value in pairs(UIFrames) do
        Value:Show();
      end
      AR.MainFrame:SetScript("OnUpdate", AR.Pulse);
    else
      AR.Print("No Rotation found for this class/spec, addon disabled.");
      for Key, Value in pairs(UIFrames) do
        Value:Hide();
      end
      AR.MainFrame:SetScript("OnUpdate", nil);
    end
  end

  AR.Timer = {
    Pulse = 0
  };
  function AR.Pulse ()
    if AC.GetTime() > AR.Timer.Pulse and AR.Locked() then
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