--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, HR = ...;
  -- HeroLib
  local HL = HeroLib;
  local Cache = HeroCache;
  local Unit = HL.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = HL.Spell;
  local Item = HL.Item;
  local GUI = HL.GUI;
  local CreatePanelOption = GUI.CreatePanelOption;

  -- Lua
  local mathmax = math.max;
  local mathmin = math.min;
  local pairs = pairs;
  local select = select;
  -- File Locals
  local Masque; -- , MasqueGroupLeft;
  local MasqueGroups = {};
  local UIFrames;
  local MasqueFrameList;
  local PrevResult, CurrResult;

  local function ModMasque(Frame, Disabled)
    if Disabled then
      Frame.__MSQ_Normal:Hide();
      Frame.Texture:SetAllPoints( Frame );
      if Frame.CooldownFrame then
        Frame.CooldownFrame:SetAllPoints( Frame );
      end
      if Frame.Backdrop then
        Frame.Backdrop:Show();
        Frame.Backdrop:SetFrameLevel(mathmin(Frame.Backdrop:GetFrameLevel(), 7));
      end
    else
      if Frame.Backdrop then
        Frame.Backdrop:Hide();
      end
    end
  end
  local function MasqueUpdate( Addon, Group, SkinID, Backdrop, Shadow, Gloss, Colors, Disabled )
    if Addon==HR and MasqueGroups and MasqueFrameList then
      local k = MasqueFrameList[Group];
      if k then
        if type(k.Icon) == "table" then
          for _, tblIcon in pairs(k.Icon) do
            ModMasque(tblIcon, Disabled)
          end
        else
          ModMasque(k, Disabled)
        end
      end
    end
  end


--- ============================ CONTENT ============================
--- ======= BINDINGS =======
  BINDING_HEADER_HEROROTATION = "HeroRotation";
  BINDING_NAME_HEROROTATION_CDS = "Toggle CDs";
  BINDING_NAME_HEROROTATION_AOE = "Toggle AoE";
  BINDING_NAME_HEROROTATION_TOGGLE = "Toggle On/Off";
  BINDING_NAME_HEROROTATION_UNLOCK = "Unlock the addon to move icons";
  BINDING_NAME_HEROROTATION_LOCK = "Lock the addon in place";

--- ======= MAIN FRAME =======
  HR.MainFrame = CreateFrame("Frame", "HeroRotation_MainFrame", UIParent);
  HR.MainFrame:SetFrameStrata(HR.GUISettings.General.MainFrameStrata);
  HR.MainFrame:SetFrameLevel(10);
  HR.MainFrame:SetWidth(112);
  HR.MainFrame:SetHeight(96);

  HR.MainFrame:SetClampedToScreen(true);
    -- Resize
    function HR.MainFrame:ResizeUI (Multiplier)
      local FramesToResize = {
        -- TODO: Put the Size in one Array in UI.lua and pull it out here
        {HR.MainFrame, 112, 96},
        {HR.MainIconFrame, 64, 64},
        {HR.SmallIconFrame, 64, 32},
        {HR.SmallIconFrame.Icon[1], HR.GUISettings.General.BlackBorderIcon and 30 or 32, HR.GUISettings.General.BlackBorderIcon and 30 or 32},
        {HR.SmallIconFrame.Icon[2], HR.GUISettings.General.BlackBorderIcon and 30 or 32, HR.GUISettings.General.BlackBorderIcon and 30 or 32},
        {HR.LeftIconFrame, 48, 48},
        {HR.SuggestedIconFrame, 32, 32},
		{HR.RightSuggestedIconFrame, 32, 32},
        {HR.MainIconPartOverlayFrame, 64, 64},
      };
      for _, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
      for i = 1, HR.MaxQueuedCasts do
        HR.MainIconFrame.Part[i]:SetWidth(64*Multiplier);
        HR.MainIconFrame.Part[i]:SetHeight(64*Multiplier);
      end
      HR.SuggestedIconFrame:SetPoint("BOTTOM", HR.MainIconFrame, "LEFT", -HR.LeftIconFrame:GetWidth()/2, HR.LeftIconFrame:GetHeight()/2+(HR.GUISettings.General.BlackBorderIcon and 3*Multiplier or 4*Multiplier));
	  HR.RightSuggestedIconFrame:SetPoint("BOTTOM", HR.MainIconFrame, "RIGHT", HR.LeftIconFrame:GetWidth()/2, HR.LeftIconFrame:GetHeight()/2 + (HR.GUISettings.General.BlackBorderIcon and 3*Multiplier or 4*Multiplier)); -- todo matt fix this location
      HeroRotationDB.GUISettings["Scaling.ScaleUI"] = Multiplier;
    end
    function HR.MainFrame:ResizeButtons (Multiplier)
      local FramesToResize = {
        -- TODO: Put the Size in one Array in UI.lua and pull it out here
        {HR.ToggleIconFrame, 64, 20},
        {HR.ToggleIconFrame.Button[1], 20, 20},
        {HR.ToggleIconFrame.Button[2], 20, 20},
        {HR.ToggleIconFrame.Button[3], 20, 20}
      };
      for Key, Value in pairs(FramesToResize) do
        Value[1]:SetWidth(Value[2]*Multiplier);
        Value[1]:SetHeight(Value[3]*Multiplier);
      end
      for i = 1, 3 do
        HR.ToggleIconFrame.Button[i]:SetPoint("LEFT", HR.ToggleIconFrame, "LEFT", HR.ToggleIconFrame.Button[i]:GetWidth()*(i-1)+i, 0);
      end
      HeroRotationDB.GUISettings["Scaling.ScaleButtons"] = Multiplier;
    end
    -- Lock/Unlock
    local LockSpell = Spell(18282);
    function HR.MainFrame:Unlock ()
      -- Grey Texture
      HR.ResetIcons();
      HR.Cast(LockSpell);           -- Main Icon
      HR.Cast(LockSpell, {true});   -- Small Icon 1
      HR.Cast(LockSpell, {true});   -- Small Icon 2
      HR.CastLeft(LockSpell);       -- Left Icon
      HR.CastSuggested(LockSpell);  -- Suggested Icon
	  HR.CastRightSuggested(LockSpell); -- Right Suggested Icon
      -- Unlock the UI
      for Key, Value in pairs(UIFrames) do
        Value:EnableMouse(true);
      end
      HR.MainFrame:SetMovable(true);
      HR.ToggleIconFrame:SetMovable(true);
      HeroRotationDB.Locked = false;
    end
    function HR.MainFrame:Lock ()
      for Key, Value in pairs(UIFrames) do
        Value:EnableMouse(false);
      end
      HR.MainFrame:SetMovable(false);
      HR.ToggleIconFrame:SetMovable(false);
      HeroRotationDB.Locked = true;
    end
    function HR.MainFrame:ToggleLock ()
      if HeroRotationDB.Locked then
        HR.MainFrame:Unlock ();
        HR.Print("HeroRotation UI is now |cff00ff00unlocked|r.");
      else
        HR.MainFrame:Lock ();
        HR.Print("HeroRotation UI is now |cffff0000locked|r.");
      end
    end
    -- Start Move
    local function StartMove (self)
      self:StartMoving();
    end
    HR.MainFrame:SetScript("OnMouseDown", StartMove);
    -- Stop Move
    local function StopMove (self)
      self:StopMovingOrSizing();
      if not HeroRotationDB then HeroRotationDB = {}; end
      local point, relativeTo, relativePoint, xOffset, yOffset, relativeToName;
      point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint();
      if not relativeTo then
        relativeToName = "UIParent";
      else
        relativeToName = relativeTo:GetName();
      end
      HeroRotationDB.IconFramePos = {
        point,
        relativeToName,
        relativePoint,
        xOffset,
        yOffset
      };
    end
    HR.MainFrame:SetScript("OnMouseUp", StopMove);
    HR.MainFrame:SetScript("OnHide", StopMove);
  -- AddonLoaded
  HR.MainFrame:RegisterEvent("ADDON_LOADED");
  HR.MainFrame:SetScript("OnEvent", function (self, Event, Arg1)
      if Event == "ADDON_LOADED" then
        if Arg1 == "HeroRotation" then
          MasqueFrameList = {
            ["Main Icon"] = HR.MainIconFrame,
            ["Top Icons"] = HR.SmallIconFrame,
            ["Left Icon"] = HR.LeftIconFrame,
            ["Suggested Icon"] = HR.SuggestedIconFrame,
            ["Right Suggested Icon"] = HR.RightSuggestedIconFrame,
            ["Part Overlay"] = HR.MainIconPartOverlayFrame,
          };
          if not Masque then
            Masque = LibStub( "Masque", true )
            if Masque then
                Masque:Register( "HeroRotation", MasqueUpdate, HR )
                for FrameName, Frame in pairs(MasqueFrameList) do
                  MasqueGroups[Frame] = Masque:Group( addonName, FrameName)
                end
            end
          end
          -- Panels
          if type(HeroRotationDB) ~= "table" then
            HeroRotationDB = {};
          end
          if type(HeroRotationCharDB) ~= "table" then
            HeroRotationCharDB = {};
          end
          if type(HeroRotationDB.GUISettings) ~= "table" then
            HeroRotationDB.GUISettings = {};
          end
          if type(HeroRotationCharDB.GUISettings) ~= "table" then
            HeroRotationCharDB.GUISettings = {};
          end
          HR.GUI.LoadSettingsRecursively(HR.GUISettings);
          HR.GUI.CorePanelSettingsInit();
          -- UI
          if HeroRotationDB and type(HeroRotationDB.IconFramePos) == "table" and #HeroRotationDB.IconFramePos == 5 then
            HR.MainFrame:SetPoint(HeroRotationDB.IconFramePos[1], _G[HeroRotationDB.IconFramePos[2]], HeroRotationDB.IconFramePos[3], HeroRotationDB.IconFramePos[4], HeroRotationDB.IconFramePos[5]);
          else
            HR.MainFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0);
          end
          HR.MainFrame:SetFrameStrata(HR.GUISettings.General.MainFrameStrata);
          HR.MainFrame:Show();
          HR.MainIconFrame:Init();
          HR.SmallIconFrame:Init();
          HR.LeftIconFrame:Init();
          HR.SuggestedIconFrame:Init();
          HR.RightSuggestedIconFrame:Init();
          HR.ToggleIconFrame:Init();
          if HeroRotationDB.GUISettings["Scaling.ScaleUI"] then
            HR.MainFrame:ResizeUI(HeroRotationDB.GUISettings["Scaling.ScaleUI"]);
          end
          if HeroRotationDB.GUISettings["Scaling.ScaleButtons"] then
            HR.MainFrame:ResizeButtons(HeroRotationDB.GUISettings["Scaling.ScaleButtons"]);
          end
          for k, v in pairs(MasqueFrameList) do
            if type(v.Icon) == "table" then
              for _, tblIcon in pairs(v.Icon) do
                tblIcon.GetNormalTexture = function(self) return nil end;
                tblIcon.SetNormalTexture = function(self, Texture) self.Texture = Texture end;
              end
            else
              v.GetNormalTexture = function(self) return nil end;
              v.SetNormalTexture = function(self, Texture) self.Texture = Texture end;
            end
          end
          if MasqueGroups then
            for k, v in pairs(MasqueGroups) do
              if type(k.Icon) == "table" then
                for _, tblIcon in pairs(k.Icon) do
                  if v then v:AddButton( tblIcon, { Icon = tblIcon.Texture, Cooldown = (tblIcon.CooldownFrame or nil) } ) end;
                end
              else
                if v then v:AddButton( k, { Icon = k.Texture, Cooldown = k.CooldownFrame } ) end;
              end
            end
            for k, v in pairs(MasqueGroups) do
              if v then v:ReSkin() end
            end
          end
          UIFrames = {
            HR.MainFrame,
            HR.MainIconFrame,
            HR.MainIconPartOverlayFrame,
            HR.MainIconFrame.Part[1],
            HR.MainIconFrame.Part[2],
            HR.MainIconFrame.Part[3],
            HR.SmallIconFrame,
            HR.SmallIconFrame.Icon[1],
            HR.SmallIconFrame.Icon[2],
            HR.LeftIconFrame,
            HR.SuggestedIconFrame,
			HR.RightSuggestedIconFrame,
            HR.ToggleIconFrame
          };

          -- Load additionnal settings
          local CP_General = GUI.GetPanelByName("General")
          if CP_General then
            CreatePanelOption("Slider", CP_General, "General.SetAlpha", {0, 1, 0.05}, "Addon Alpha", "Change the addon's alpha setting.");
            CreatePanelOption("Button", CP_General, "ButtonMove", "Lock/Unlock", "Enable the moving of the frames.", function() HR.MainFrame:ToggleLock(); end);
            CreatePanelOption("Button", CP_General, "ButtonReset", "Reset Buttons", "Resets the anchor of buttons.", function() HR.ToggleIconFrame:ResetAnchor(); end);
          end
          local CP_Scaling = GUI.GetPanelByName("Scaling")
          if CP_Scaling then
            CreatePanelOption("Slider", CP_Scaling, "Scaling.ScaleUI", {0.5, 5, 0.1}, "UI Scale", "Scale of the Icons.", function(value) HR.MainFrame:ResizeUI(value); end);
            CreatePanelOption("Slider", CP_Scaling, "Scaling.ScaleButtons", {0.5, 5, 0.1}, "Buttons Scale", "Scale of the Buttons.", function(value) HR.MainFrame:ResizeButtons(value); end);
            CreatePanelOption("Slider", CP_Scaling, "Scaling.ScaleHotkey", {0.5, 5, 0.1}, "Hotkey Scale", "Scale of the Hotkeys.");
          end

          -- Modules
          C_Timer.After(2, function ()
              HR.MainFrame:UnregisterEvent("ADDON_LOADED");
              HR.PulsePreInit();
              HR.PulseInit();
            end
          );
        end
      end
    end
  );

--- ======= MAIN =======
  function HR.PulsePreInit ()
    HR.MainFrame:Lock();
  end
  local EnabledRotation = {
    -- Death Knight
      [250]   = "HeroRotation_DeathKnight",   -- Blood
      [251]   = "HeroRotation_DeathKnight",   -- Frost
      [252]   = "HeroRotation_DeathKnight",   -- Unholy
    -- Demon Hunter
      [577]   = "HeroRotation_DemonHunter",   -- Havoc
      [581]   = "HeroRotation_DemonHunter",   -- Vengeance
    -- Druid
      [102]   = "HeroRotation_Druid",         -- Balance
      [103]   = "HeroRotation_Druid",         -- Feral
      [104]   = "HeroRotation_Druid",         -- Guardian
      --[105]   = "HeroRotation_Druid",         -- Restoration
    -- Evoker
      [1467]  = "HeroRotation_Evoker",        -- Devastation
      --[1468] = "HeroRotation_Evoker",         -- Preservation
    -- Hunter
      [253]   = "HeroRotation_Hunter",        -- Beast Mastery
      [254]   = "HeroRotation_Hunter",        -- Marksmanship
      [255]   = "HeroRotation_Hunter",        -- Survival
    -- Mage
      [62]    = "HeroRotation_Mage",          -- Arcane
      --[63]    = "HeroRotation_Mage",          -- Fire
      [64]    = "HeroRotation_Mage",          -- Frost
    -- Monk
      --[268]   = "HeroRotation_Monk",          -- Brewmaster
      [269]   = "HeroRotation_Monk",          -- Windwalker
      --[270]   = "HeroRotation_Monk",          -- Mistweaver
    -- Paladin
      --[65]    = "HeroRotation_Paladin",       -- Holy
      [66]    = "HeroRotation_Paladin",       -- Protection
      [70]    = "HeroRotation_Paladin",       -- Retribution
    -- Priest
      --[256]   = "HeroRotation_Priest",        -- Discipline
      --[257]   = "HeroRotation_Priest",        -- Holy
      [258]   = "HeroRotation_Priest",        -- Shadow
    -- Rogue
      [259]   = "HeroRotation_Rogue",         -- Assassination
      [260]   = "HeroRotation_Rogue",         -- Outlaw
      [261]   = "HeroRotation_Rogue",         -- Subtlety
    -- Shaman
      [262]   = "HeroRotation_Shaman",        -- Elemental
      [263]   = "HeroRotation_Shaman",        -- Enhancement
      --[264]   = "HeroRotation_Shaman",        -- Restoration
    -- Warlock
      [265]   = "HeroRotation_Warlock",       -- Affliction
      [266]   = "HeroRotation_Warlock",       -- Demonology
      [267]   = "HeroRotation_Warlock",       -- Destruction
    -- Warrior
      [71]    = "HeroRotation_Warrior",       -- Arms
      [72]    = "HeroRotation_Warrior",       -- Fury
      [73]    = "HeroRotation_Warrior"        -- Protection
  };
  local LatestSpecIDChecked = 0;
  function HR.PulseInit ()
    local Spec = GetSpecialization();
    -- Delay by 1 second until the WoW API returns a valid value.
    if Spec == nil then
      HL.PulseInitialized = false;
      C_Timer.After(1, function ()
          HR.PulseInit();
        end
      );
    else
      -- Force a refresh from the Core
      -- TODO: Make it a function instead of copy/paste from Core Events.lua
      Cache.Persistent.Player.Spec = {GetSpecializationInfo(Spec)};
      local SpecID = Cache.Persistent.Player.Spec[1];

      -- Delay by 1 second until the WoW API returns a valid value.
      if SpecID == nil then
        HL.PulseInitialized = false;
        C_Timer.After(1, function ()
            HR.PulseInit();
          end
        );
      else
        -- Load the Class Module if it's possible and not already loaded
        if EnabledRotation[SpecID] and not IsAddOnLoaded(EnabledRotation[SpecID]) then
          LoadAddOn(EnabledRotation[SpecID]);
          HL.LoadOverrides(SpecID)
        end

        -- Check if there is a Rotation for this Spec
        if LatestSpecIDChecked ~= SpecID then
          if EnabledRotation[SpecID] and HR.APLs[SpecID] then
            for Key, Value in pairs(UIFrames) do
              Value:Show();
            end
            HR.MainFrame:SetScript("OnUpdate", HR.Pulse);
            -- Spec Registers
            -- Spells
            Player:RegisterListenedSpells(SpecID);
            HL.UnregisterAuraTracking();
            -- Enums Filters
            Player:FilterTriggerGCD(SpecID);
            Spell:FilterProjectileSpeed(SpecID);
            -- Module Init Function
            if HR.APLInits[SpecID] then
              HR.APLInits[SpecID]();
            end
            -- Special Checks
            if GetCVar("nameplateShowEnemies") ~= "1" then
              HR.Print("It looks like enemy nameplates are disabled, you should enable them in order to get proper AoE rotation.");
            end
          else
            HR.Print("No Rotation found for this class/spec (SpecID: ".. SpecID .. "), addon disabled. This is likely due to the rotation being unsupported at this time. Please check supported rotations here: https://github.com/herotc/hero-rotation#supported-rotations");
            for Key, Value in pairs(UIFrames) do
              Value:Hide();
            end
            HR.MainFrame:SetScript("OnUpdate", nil);
          end
          LatestSpecIDChecked = SpecID;
        end
        if not HL.PulseInitialized then HL.PulseInitialized = true; end
      end
    end
  end

  HR.Timer = {
    Pulse = 0
  };
  function HR.Pulse ()
    if GetTime() > HR.Timer.Pulse and HR.Locked() then
      HR.Timer.Pulse = GetTime() + HL.Timer.PulseOffset;

      HR.ResetIcons();

      -- Check if the current spec is available (might not always be the case)
      -- Especially when switching from area (open world -> instance)
      local SpecID = Cache.Persistent.Player.Spec[1];
      if SpecID then
        -- Check if we are ready to cast something to save FPS.
        if HR.ON() and HR.Ready() then
          HL.CacheHasBeenReset = false;
          Cache.Reset();
          -- Rotational Debug Output
          if HR.GUISettings.General.RotationDebugOutput then
            CurrResult = HR.APLs[SpecID]();
            if CurrResult and CurrResult ~= PrevResult then
              HR.Print(CurrResult);
              PrevResult = CurrResult;
            end
          else
            HR.APLs[SpecID]();
          end
        end
        if MasqueGroups then
          for k, v in pairs(MasqueGroups) do
            if v then v:ReSkin() end
          end
        end
      end
    end
  end

  -- Is the player ready ?
  function HR.Ready ()
    local AreWeReady
    if HR.GUISettings.General.ShowWhileMounted then
      AreWeReady = not Player:IsDeadOrGhost() and not Player:IsInVehicle() and not C_PetBattles.IsInBattle();
    else
      AreWeReady = not Player:IsDeadOrGhost() and not Player:IsMounted() and not Player:IsInVehicle() and not C_PetBattles.IsInBattle();
    end
    return AreWeReady
  end

  -- Used to force a short/long pulse wait, it also resets the icons.
  function HR.ChangePulseTimer (Offset)
    HR.ResetIcons();
    HR.Timer.Pulse = GetTime() + Offset;
  end
