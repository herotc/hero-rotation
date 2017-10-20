--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AR = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
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
  -- File Locals
  local UIFrames;


--- ============================ CONTENT ============================
--- ======= BINDINGS =======
  BINDING_HEADER_AETHYSROTATION = "AethysRotation";
  BINDING_NAME_AETHYSROTATION_CDS = "Toggle CDs";
  BINDING_NAME_AETHYSROTATION_AOE = "Toggle AoE";
  BINDING_NAME_AETHYSROTATION_TOGGLE = "Toggle On/Off";

--- ======= MAIN FRAME =======
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
        {AR.LeftIconFrame, 48, 48},
        {AR.SuggestedIconFrame, 32, 32},
      };
      for Key, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
	  for i = 1, AR.MaxQueuedCasts do
		AR.MainIconFrame.Part[i]:SetWidth(64*Multiplier);
		AR.MainIconFrame.Part[i]:SetHeight(64*Multiplier);
	  end
      AR.SuggestedIconFrame:SetPoint("BOTTOM", AR.MainIconFrame, "LEFT", -AR.LeftIconFrame:GetWidth()/2, AR.LeftIconFrame:GetHeight()/2+(AR.GUISettings.General.BlackBorderIcon and 3*Multiplier or 4*Multiplier));
      AethysRotationDB.ScaleUI = Multiplier;
    end
    function AR.MainFrame:ResizeButtons (Multiplier)
      local FramesToResize = {
        -- TODO: Put the Size in one Array in UI.lua and pull it out here
        {AR.ToggleIconFrame, 64, 20},
        {AR.ToggleIconFrame.Button[1], 20, 20},
        {AR.ToggleIconFrame.Button[2], 20, 20},
        {AR.ToggleIconFrame.Button[3], 20, 20}
      };
      for Key, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
      for i = 1, 3 do
        AR.ToggleIconFrame.Button[i]:SetPoint("LEFT", AR.ToggleIconFrame, "LEFT", AR.ToggleIconFrame.Button[i]:GetWidth()*(i-1)+i, 0);
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
      AR.CastLeft(LockSpell);       -- Left Icon
      AR.CastSuggested(LockSpell);  -- Suggested Icon
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
      local point, relativeTo, relativePoint, xOffset, yOffset, relativeToName;
      point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint();
      if not relativeTo then
        relativeToName = "UIParent";
      else
        relativeToName = relativeTo:GetName();
      end
      AethysRotationDB.IconFramePos = {
        point,
        relativeToName,
        relativePoint,
        xOffset,
        yOffset
      };
    end
    AR.MainFrame:SetScript("OnMouseUp", StopMove);
    AR.MainFrame:SetScript("OnHide", StopMove);
  -- AddonLoaded
  AR.MainFrame:RegisterEvent("ADDON_LOADED");
  AR.MainFrame:SetScript("OnEvent", function (self, Event, Arg1)
      if Event == "ADDON_LOADED" then
        if Arg1 == "AethysRotation" then
          -- Panels
          if type(AethysRotationDB) ~= "table" then
            AethysRotationDB = {};
          end
          if type(AethysRotationDB.GUISettings) ~= "table" then
            AethysRotationDB.GUISettings = {};
          end
          AR.GUI.LoadSettingsRecursively(AR.GUISettings);
          AR.GUI.CorePanelSettingsInit();
          -- UI
          if AethysRotationDB and AethysRotationDB.IconFramePos then
            AR.MainFrame:SetPoint(AethysRotationDB.IconFramePos[1], _G[AethysRotationDB.IconFramePos[2]], AethysRotationDB.IconFramePos[3], AethysRotationDB.IconFramePos[4], AethysRotationDB.IconFramePos[5]);
          else
            AR.MainFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0);
          end
          AR.MainFrame:Show();
          AR.MainIconFrame:Init();
          AR.SmallIconFrame:Init();
          AR.LeftIconFrame:Init();
          AR.SuggestedIconFrame:Init();
          AR.ToggleIconFrame:Init();
          if AethysRotationDB.ScaleUI then
            AR.MainFrame:ResizeUI(AethysRotationDB.ScaleUI);
          end
          if AethysRotationDB.ScaleButtons then
            AR.MainFrame:ResizeButtons(AethysRotationDB.ScaleButtons);
          end
          UIFrames = {
            AR.MainFrame,
            AR.MainIconFrame,
            AR.MainIconFrame.Part[1],
            AR.MainIconFrame.Part[2],
            AR.MainIconFrame.Part[3],
            AR.SmallIconFrame,
            AR.SmallIconFrame.Icon[1],
            AR.SmallIconFrame.Icon[2],
            AR.LeftIconFrame,
            AR.SuggestedIconFrame,
            AR.ToggleIconFrame
          };
          -- Modules
          C_Timer.After(2, function ()
              AR.MainFrame:UnregisterEvent("ADDON_LOADED");
              AR.PulsePreInit();
              AR.PulseInit();
            end
          );
        end
      end
    end
  );

--- ======= MAIN =======
  function AR.PulsePreInit ()
    AR.MainFrame:Lock();
  end
  local EnabledRotation = {
    -- Death Knight
      [250]   = "AethysRotation_DeathKnight",   -- Blood
      [251]   = "AethysRotation_DeathKnight",   -- Frost
      [252]   = "AethysRotation_DeathKnight",   -- Unholy
    -- Demon Hunter
      [577]   = false,                          -- Havoc
      [581]   = "AethysRotation_DemonHunter",   -- Vengeance
    -- Druid
      [102]   = "AethysRotation_Druid",         -- Balance
      [103]   = false,                          -- Feral
      [104]   = "AethysRotation_Druid",         -- Guardian
      [105]   = false,                          -- Restoration
    -- Hunter
      [253]   = "AethysRotation_Hunter",        -- Beast Mastery
      [254]   = "AethysRotation_Hunter",        -- Marksmanship
      [255]   = "AethysRotation_Hunter",        -- Survival
    -- Mage
      [62]    = false,                          -- Arcane
      [63]    = false,                          -- Fire
      [64]    = "AethysRotation_Mage",          -- Frost
    -- Monk
      [268]   = false,                          -- Brewmaster
      [269]   = "AethysRotation_Monk",          -- Windwalker
      [270]   = false,                          -- Mistweaver
    -- Paladin
      [65]    = false,                          -- Holy
      [66]    = "AethysRotation_Paladin",       -- Protection
      [70]    = "AethysRotation_Paladin",       -- Retribution
    -- Priest
      [256]   = false,                          -- Discipline
      [257]   = false,                          -- Holy
      [258]   = "AethysRotation_Priest",        -- Shadow
    -- Rogue
      [259]   = "AethysRotation_Rogue",         -- Assassination
      [260]   = "AethysRotation_Rogue",         -- Outlaw
      [261]   = "AethysRotation_Rogue",         -- Subtlety
    -- Shaman
      [262]   = "AethysRotation_Shaman",        -- Elemental
      [263]   = "AethysRotation_Shaman",        -- Enhancement
      [264]   = false,                          -- Restoration
    -- Warlock
      [265]   = "AethysRotation_Warlock",       -- Affliction
      [266]   = "AethysRotation_Warlock",       -- Demonology
      [267]   = "AethysRotation_Warlock",       -- Destruction
    -- Warrior
      [71]    = "AethysRotation_Warrior",       -- Arms
      [72]    = "AethysRotation_Warrior",       -- Fury
      [73]    = false                           -- Protection
  };
  local LatestSpecIDChecked = 0;
  function AR.PulseInit ()
    local Spec = GetSpecialization();
    -- Delay by 1 second until the WoW API returns a valid value.
    if Spec == nil then
      C_Timer.After(1, function ()
          AR.PulseInit();
        end
      );
    else
      -- Force a refresh from the Core
      -- TODO: Make it a function instead of copy/paste from Core Events.lua
      Cache.Persistent.Player.Spec = {GetSpecializationInfo(Spec)};
      local SpecID = Cache.Persistent.Player.Spec[1];

      -- Load the Class Module if it's possible and not already loaded
      if EnabledRotation[SpecID] and not IsAddOnLoaded(EnabledRotation[SpecID]) then
        LoadAddOn(EnabledRotation[SpecID]);
      end

      -- Check if there is a Rotation for this Spec
      if LatestSpecIDChecked ~= SpecID then
        if EnabledRotation[SpecID] and AR.APLs[SpecID] then
          for Key, Value in pairs(UIFrames) do
            Value:Show();
          end
          AR.MainFrame:SetScript("OnUpdate", AR.Pulse);
          -- Spec Registers
            -- Spells
            Player:RegisterListenedSpells(SpecID);
            -- Enums Filters
            Player:FilterTriggerGCD(SpecID);
            Spell:FilterProjectileSpeed(SpecID);
          -- Special Checks
          if GetCVar("nameplateShowEnemies") ~= "1" then
            AR.Print("It looks like enemies nameplates are disabled, you should enable them in order to get proper AoE rotation.");
          end
        else
          AR.Print("No Rotation found for this class/spec (SpecID: ".. SpecID .. "), addon disabled.");
          for Key, Value in pairs(UIFrames) do
            Value:Hide();
          end
          AR.MainFrame:SetScript("OnUpdate", nil);
        end
        LatestSpecIDChecked = SpecID;
      end
      if not AC.PulseInitialized then AC.PulseInitialized = true; end
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
        Cache.Reset();
        AR.APLs[Cache.Persistent.Player.Spec[1]]();
      end
    end
  end

  -- Is the player ready ?
  function AR.Ready ()
    return not Player:IsDeadOrGhost() and not Player:IsMounted() and not Player:IsInVehicle() and not C_PetBattles.IsInBattle();
  end

  -- Used to force a short/long pulse wait, it also resets the icons.
  function AR.ChangePulseTimer (Offset)
    AR.ResetIcons();
    AR.Timer.Pulse = AC.GetTime() + Offset;
  end
