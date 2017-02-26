--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
  local pairs = pairs;
  local stringlower = string.lower;
  local tostring = tostring;
  -- File Locals
  local FrameID, Nameplate;       -- AR.Nameplate.AddIcon
  local Token;                    -- AR.Nameplate.AddIcon


--- ============================ CONTENT ============================
--- ======= MAIN FRAME =======
  AR.MainIconFrame = CreateFrame("Frame", "AethysRotation_MainIconFrame", UIParent);
  AR.MainIconFrame.CooldownFrame = CreateFrame("Cooldown", "AethysRotation_MainIconCooldownFrame", AR.MainIconFrame, "CooldownFrameTemplate");
  AR.MainIconFrame.TempTexture = AR.MainIconFrame:CreateTexture(nil, "BACKGROUND");
  AR.SmallIconFrame = CreateFrame("Frame", "AethysRotation_SmallIconFrame", UIParent);
  AR.LeftIconFrame = CreateFrame("Frame", "AethysRotation_LeftIconFrame", UIParent);
  AR.NameplateIconFrame = CreateFrame("Frame", "AethysRotation_NameplateIconFrame", UIParent);
  AR.SuggestedIconFrame = CreateFrame("Frame", "AethysRotation_SuggestedIconFrame", UIParent);
  AR.ToggleIconFrame = CreateFrame("Frame", "AethysRotation_ToggleIconFrame", UIParent);

--- ======= MISC =======
  -- Reset Textures
  local IdleSpell = Spell(9999000000);
  function AR.ResetIcons ()
    -- Main Icon
    AR.MainIconFrame:ChangeIcon(AR.GetTexture(IdleSpell)); 
    if AR.GUISettings.General.BlackBorderIcon then AR.MainIconFrame.Backdrop:Hide(); end

    -- Small Icons
    AR.SmallIconFrame:HideIcons();
    AR.CastOffGCDOffset = 1;

    -- Left/Nameplate Icons
    AR.Nameplate.HideIcons();
    AR.CastLeftOffset = 1;

    -- Suggested Icon
    AR.SuggestedIconFrame:HideIcon();
    AR.CastSuggestedOffset = 1;
  end

  -- Create a Backdrop
  function AR:CreateBackdrop (Frame)
    if Frame.Backdrop or not AR.GUISettings.General.BlackBorderIcon then return; end

    local Backdrop = CreateFrame("Frame", nil, Frame);
    Backdrop:ClearAllPoints();
    Backdrop:SetPoint("TOPLEFT", Frame, "TOPLEFT", -1, 1);
    Backdrop:SetPoint("BOTTOMRIGHT", Frame, "BOTTOMRIGHT", 1, -1);

    Backdrop:SetBackdrop({
      bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
      edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
      tile = false,
      tileSize = 0,
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    });

    Backdrop:SetBackdropBorderColor(0, 0, 0);
    Backdrop:SetBackdropColor(0, 0, 0, 1);

    Backdrop:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    if Frame:GetFrameLevel() - 1 >= 0 then
      Backdrop:SetFrameLevel(Frame:GetFrameLevel() - 1);
    else
      Backdrop:SetFrameLevel(0);
    end

    Frame.Backdrop = Backdrop;
  end

--- ======= MAIN ICON =======
  -- Init
  function AR.MainIconFrame:Init ()
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(64);
    self:SetHeight(64);
    self:SetPoint("BOTTOMRIGHT", AR.MainFrame, "BOTTOMRIGHT", 0, 0);
    self.CooldownFrame:SetAllPoints(self);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    if AR.GUISettings.General.BlackBorderIcon then
      self.TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.MainIconFrame:ChangeIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then self.Backdrop:Show(); end
  end
  -- Set a Cooldown Frame
  function AR.MainIconFrame:SetCooldown (Start, Duration)
    self.CooldownFrame:SetCooldown(Start, Duration);
  end

--- ======= SMALL ICONS =======
  -- Init
  function AR.SmallIconFrame:Init ()
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(64);
    self:SetHeight(32);
    self:SetPoint("BOTTOMLEFT", AR.MainIconFrame, "TOPLEFT", 0, AR.GUISettings.General.BlackBorderIcon and 1 or 0);
    self:Show();

    self.Icon = {};
    self:CreateIcons(1, "LEFT");
    self:CreateIcons(2, "RIGHT");
  end
  -- Create Small Icons Frames
  function AR.SmallIconFrame:CreateIcons (Index, Align)
    self.Icon[Index] = CreateFrame("Frame", "AethysRotation_SmallIconFrame"..tostring(Index), UIParent);
    self.Icon[Index]:SetFrameStrata(self:GetFrameStrata());
    self.Icon[Index]:SetFrameLevel(self:GetFrameLevel() - 1);
    self.Icon[Index]:SetWidth(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[Index]:SetHeight(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[Index]:SetPoint(Align, self, Align, 0, 0);
    self.Icon[Index].TempTexture = self.Icon[Index]:CreateTexture(nil, "BACKGROUND");
    if AR.GUISettings.General.BlackBorderIcon then
      self.Icon[Index].TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self.Icon[Index]);
    end
    self.Icon[Index]:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.SmallIconFrame:ChangeIcon (FrameID, Texture)
    self.Icon[FrameID].TempTexture:SetTexture(Texture);
    self.Icon[FrameID].TempTexture:SetAllPoints(self.Icon[FrameID]);
    self.Icon[FrameID].texture = self.Icon[FrameID].TempTexture;
    if not self.Icon[FrameID]:IsVisible() then
      self.Icon[FrameID]:Show();
    end
  end
  -- Hide Small Icons
  function AR.SmallIconFrame:HideIcons ()
    for i = 1, #self.Icon do
      self.Icon[i]:Hide();
    end
  end

--- ======= LEFT ICON =======
  -- Init LeftIcon
  function AR.LeftIconFrame:Init ()
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(48);
    self:SetHeight(48);
    self:SetPoint("RIGHT", AR.MainIconFrame, "LEFT", 0, 0);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.LeftIconFrame:ChangeIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if not self:IsVisible() then
      self:Show();
    end
  end

--- ======= NAMEPLATES =======
  AR.Nameplate = {
    Initialized = false
  };
  -- Add the Icon on Nameplates
  function AR.Nameplate.AddIcon (ThisUnit, Object)
    Token = stringlower(ThisUnit.UnitID);
    Nameplate = C_NamePlate.GetNamePlateForUnit(Token);
    if Nameplate then
      -- Init Frame if not already
      if not AR.Nameplate.Initialized then
        -- Frame
        AR.NameplateIconFrame:SetFrameStrata(Nameplate.UnitFrame:GetFrameStrata());
        AR.NameplateIconFrame:SetFrameLevel(Nameplate.UnitFrame:GetFrameLevel() + 50);
        AR.NameplateIconFrame:SetWidth(Nameplate.UnitFrame:GetHeight()*0.8);
        AR.NameplateIconFrame:SetHeight(Nameplate.UnitFrame:GetHeight()*0.8);
        -- Texture
        AR.NameplateIconFrame.TempTexture = AR.NameplateIconFrame:CreateTexture(nil, "BACKGROUND");

        AR.Nameplate.Initialized = true;
      end

      -- Set the Texture
      AR.NameplateIconFrame.TempTexture:SetTexture(AR.GetTexture(Object));
      AR.NameplateIconFrame.TempTexture:SetAllPoints(AR.NameplateIconFrame);
      AR.NameplateIconFrame.texture = AR.NameplateIconFrame.TempTexture;
      if not AR.NameplateIconFrame:IsVisible() then
        AR.NameplateIconFrame:SetPoint("CENTER", Nameplate.UnitFrame.healthBar, "CENTER", 0, 0);
        AR.NameplateIconFrame:Show();
      end

      -- Register the Unit for Error Checks (see Not Facing Unit Blacklist in Events.lua)
      AR.LastUnitCycled = ThisUnit;
      AR.LastUnitCycledTime = AC.GetTime();

      return true;
    end
    return false;
  end
  -- Remove Icons
  function AR.Nameplate.HideIcons ()
    -- Nameplate Icon
    AR.NameplateIconFrame:Hide();
    -- Left Icon
    AR.LeftIconFrame:Hide();
  end

--- ======= SUGGESTED ICON =======
  -- Init
  function AR.SuggestedIconFrame:Init ()
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(32);
    self:SetHeight(32);
    self:SetPoint("BOTTOM", AR.MainIconFrame, "LEFT", -AR.LeftIconFrame:GetWidth()/2, AR.LeftIconFrame:GetHeight()/2+(AR.GUISettings.General.BlackBorderIcon and 3 or 4));
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.SuggestedIconFrame:ChangeIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if not self:IsVisible() then
      self:Show();
    end
  end
  -- Hide Icon
  function AR.SuggestedIconFrame:HideIcon ()
    AR.SuggestedIconFrame:Hide();
  end

--- ======= TOGGLES =======
  -- Init
  function AR.ToggleIconFrame:Init ()
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(64);
    self:SetHeight(20);

    -- Reset the Anchor if saved data are not valid (i.e. data saved before 7.1.5843)
    -- TODO: Remove this part later.
    if AethysRotationDB and AethysRotationDB.ButtonsFramePos and type(AethysRotationDB.ButtonsFramePos[2]) ~= "string" then
      self:ResetAnchor();
    end

    -- Anchor based on Settings
    if AethysRotationDB and AethysRotationDB.ButtonsFramePos then
      self:SetPoint(AethysRotationDB.ButtonsFramePos[1], _G[AethysRotationDB.ButtonsFramePos[2]], AethysRotationDB.ButtonsFramePos[3], AethysRotationDB.ButtonsFramePos[4], AethysRotationDB.ButtonsFramePos[5]);
    else
      self:SetPoint("TOPLEFT", AR.MainIconFrame, "BOTTOMLEFT", 0, AR.GUISettings.General.BlackBorderIcon and -3 or 0);
    end

    -- Start Move
    local function StartMove (self)
      self:StartMoving();
    end
    self:SetScript("OnMouseDown", StartMove);
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
      AethysRotationDB.ButtonsFramePos = {
        point,
        relativeToName,
        relativePoint,
        xOffset,
        yOffset
      };
    end
    self:SetScript("OnMouseUp", StopMove);
    self:SetScript("OnHide", StopMove);

    self:Show();
    self:AddButton("C", 1, "CDs");
    self:AddButton("A", 2, "AoE");
    self:AddButton("O", 3, "On/Off");
  end
  -- Reset Anchor
  function AR.ToggleIconFrame:ResetAnchor ()
    self:SetPoint("TOPLEFT", AR.MainIconFrame, "BOTTOMLEFT", 0, AR.GUISettings.General.BlackBorderIcon and -3 or 0);
    AethysRotationDB.ButtonsFramePos = false;
  end
  -- Buttons
  AR.Button = {};
  function AR.ToggleIconFrame:AddButton (Text, i, Tooltip)
    AR.Button[i] = CreateFrame("Button", "$parentButton"..tostring(i), self);
    AR.Button[i]:SetFrameStrata(self:GetFrameStrata());
    AR.Button[i]:SetFrameLevel(self:GetFrameLevel() - 1);
    AR.Button[i]:SetWidth(20);
    AR.Button[i]:SetHeight(20);
    AR.Button[i]:SetPoint("LEFT", self, "LEFT", 20*(i-1)+i, 0);
    AR.Button[i].TimeSinceLastUpdate = 0;
    AR.Button[i].UpdateInterval = 0.25;
    AR.Button[i]:SetScript("OnUpdate",
      function (self, elapsed)
        self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
        if self.TimeSinceLastUpdate > self.UpdateInterval then
          if AethysRotationDB.Toggles[i] then
            AR.Button[i]:SetFormattedText("|cff00ff00%s|r", Text);
          else
            AR.Button[i]:SetFormattedText("|cffff0000%s|r", Text);
          end
          self.TimeSinceLastUpdate = 0;
        end
      end
    );
    if Tooltip then
      AR.Button[i]:SetScript("OnEnter",
        function (self)
          GameTooltip:SetOwner(AR.ToggleIconFrame, "ANCHOR_BOTTOM", 0, 0);
          GameTooltip:ClearLines();
          GameTooltip:SetBackdropColor(0, 0, 0, 1);
          GameTooltip:SetText(Tooltip, nil, nil, nil, 1, true);
          GameTooltip:Show();
        end
      );
      AR.Button[i]:SetScript("OnLeave",
        function (self)
          GameTooltip:Hide();
        end
      );
    end
    AR.Button[i]:SetNormalFontObject("GameFontNormalSmall");
    local ntex = AR.Button[i]:CreateTexture();
    ntex:SetTexture("Interface/Buttons/UI-Silver-Button-Up");
    ntex:SetTexCoord(0, 0.625, 0, 0.7875);
    ntex:SetAllPoints();
    AR.Button[i]:SetNormalTexture(ntex);
    local htex = AR.Button[i]:CreateTexture();
    htex:SetTexture("Interface/Buttons/UI-Silver-Button-Highlight");
    htex:SetTexCoord(0, 0.625, 0, 0.7875);
    htex:SetAllPoints();
    AR.Button[i]:SetHighlightTexture(htex);
    local ptex = AR.Button[i]:CreateTexture();
    ptex:SetTexture("Interface/Buttons/UI-Silver-Button-Down");
    ptex:SetTexCoord(0, 0.625, 0, 0.7875);
    ptex:SetAllPoints();
    AR.Button[i]:SetPushedTexture(ptex);
    if not AethysRotationDB then
      AethysRotationDB = {};
    end
    if not AethysRotationDB.Toggles then
      AethysRotationDB.Toggles = {};
    end
    AethysRotationDB.Toggles[i] = true;
    local Argument = i == 1 and "cds" or i == 2 and "aoe" or i == 3 and "toggle";
    AR.Button[i]:SetScript("OnMouseDown",
      function (self, Button)
        if Button == "LeftButton" then
          AR.CmdHandler(Argument);
        end
      end
    );
    AR.Button[i]:Show();
  end
