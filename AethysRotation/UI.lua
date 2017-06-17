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
  local pairs = pairs;
  local stringlower = string.lower;
  local tostring = tostring;
  -- File Locals
  local FrameID, Nameplate;       -- AR.Nameplate.AddIcon
  local Token;                    -- AR.Nameplate.AddIcon


--- ============================ CONTENT ============================
--- ======= MAIN FRAME =======
  AR.MainIconFrame = CreateFrame("Frame", "AethysRotation_MainIconFrame", UIParent);
  AR.MainIconFrame.CooldownFrame = CreateFrame("Cooldown", "AethysRotation_MainIconCooldownFrame", AR.MainIconFrame, "AR_CooldownFrameTemplate");
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
    AR.MainIconFrame:HideParts();

    -- Small Icons
    AR.SmallIconFrame:HideIcons();
    AR.CastOffGCDOffset = 1;

    -- Left/Nameplate Icons
    AR.Nameplate.HideIcons();
    AR.CastLeftOffset = 1;

    -- Suggested Icon
    AR.SuggestedIconFrame:HideIcon();
    if AR.GUISettings.General.BlackBorderIcon then AR.SuggestedIconFrame.Backdrop:Hide(); end
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
    self:InitParts();
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
  function AR.MainIconFrame:InitParts ()
    self.Part = {};
    for i = 1, AR.MaxQueuedCasts do
      self.Part[i] = CreateFrame("Frame", "AethysRotation_MainIconPartFrame"..tostring(i), UIParent);
      self.Part[i]:SetFrameStrata(self:GetFrameStrata());
      self.Part[i]:SetFrameLevel(self:GetFrameLevel() + 1);
      self.Part[i]:SetWidth(64);
      self.Part[i]:SetHeight(64);
      self.Part[i]:SetPoint("Left", self, "Left", 0, 0);
      self.Part[i].TempTexture = self.Part[i]:CreateTexture(nil, "BACKGROUND");
      if AR.GUISettings.General.BlackBorderIcon then
        self.Part[i].TempTexture:SetTexCoord(.08, .92, .08, .92);
        AR:CreateBackdrop(self.Part[i]);
      end
      self.Part[i]:Show();
    end
  end
  local QueuedCasts;
  function AR.MainIconFrame:SetupParts (Textures)
    QueuedCasts = #Textures;
    for i = 1, QueuedCasts do
      self.Part[i]:SetWidth(64/QueuedCasts);
      self.Part[i]:SetPoint("Left", self, "Left", 64/QueuedCasts*(i-1), 0);
      self.Part[i].TempTexture:SetTexture(Textures[i]);
      self.Part[i].TempTexture:SetAllPoints(self.Part[i]);
      self.Part[i].TempTexture:SetTexCoord(i == 1 and (AR.GUISettings.General.BlackBorderIcon and 0.08 or 0) or (i-1)/QueuedCasts,
                                            i == AR.MaxQueuedCasts and (AR.GUISettings.General.BlackBorderIcon and 0.92 or 1) or i/QueuedCasts,
                                            AR.GUISettings.General.BlackBorderIcon and 0.08 or 0,
                                            AR.GUISettings.General.BlackBorderIcon and 0.92 or 1);
      self.Part[i].texture = self.Part[i].TempTexture;
      if not self.Part[i]:IsVisible() then
        self.Part[i]:Show();
      end
    end
  end
  function AR.MainIconFrame:HideParts ()
    for i = 1, #self.Part do
      self.Part[i]:Hide();
    end
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
    -- Icon
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
      -- Icon
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
    self:SetPoint("RIGHT", AR.MainIconFrame, "LEFT", AR.GUISettings.General.BlackBorderIcon and -1 or 0, 0);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    if AR.GUISettings.General.BlackBorderIcon then
      self.TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
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
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then self.Backdrop:Show(); end
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
        AR.NameplateIconFrame:SetWidth(Nameplate.UnitFrame:GetHeight());
        AR.NameplateIconFrame:SetHeight(Nameplate.UnitFrame:GetHeight());
        -- Texture
        AR.NameplateIconFrame.TempTexture = AR.NameplateIconFrame:CreateTexture(nil, "BACKGROUND");

        if AR.GUISettings.General.BlackBorderIcon then
          AR.NameplateIconFrame.TempTexture:SetTexCoord(.08, .92, .08, .92);
          AR:CreateBackdrop(AR.NameplateIconFrame);
        end

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
    if AR.GUISettings.General.BlackBorderIcon then
      self.TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
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
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then self.Backdrop:Show(); end
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

    -- Button Creation
    self.Button = {};
    self:AddButton("C", 1, "CDs", "cds");
    self:AddButton("A", 2, "AoE", "aoe");
    self:AddButton("O", 3, "On/Off", "toggle");
  end
  -- Reset Anchor
  function AR.ToggleIconFrame:ResetAnchor ()
    self:SetPoint("TOPLEFT", AR.MainIconFrame, "BOTTOMLEFT", 0, AR.GUISettings.General.BlackBorderIcon and -3 or 0);
    AethysRotationDB.ButtonsFramePos = false;
  end
  -- Add a button
  function AR.ToggleIconFrame:AddButton (Text, i, Tooltip, CmdArg)
    self.Button[i] = CreateFrame("Button", "$parentButton"..tostring(i), self);
    self.Button[i]:SetFrameStrata(self:GetFrameStrata());
    self.Button[i]:SetFrameLevel(self:GetFrameLevel() - 1);
    self.Button[i]:SetWidth(20);
    self.Button[i]:SetHeight(20);
    self.Button[i]:SetPoint("LEFT", self, "LEFT", 20*(i-1)+i, 0);

    -- Button Tooltip (Optional)
    if Tooltip then
      self.Button[i]:SetScript("OnEnter",
        function (self)
          GameTooltip:SetOwner(AR.ToggleIconFrame, "ANCHOR_BOTTOM", 0, 0);
          GameTooltip:ClearLines();
          GameTooltip:SetBackdropColor(0, 0, 0, 1);
          GameTooltip:SetText(Tooltip, nil, nil, nil, 1, true);
          GameTooltip:Show();
        end
      );
      self.Button[i]:SetScript("OnLeave",
        function (self)
          GameTooltip:Hide();
        end
      );
    end

    -- Button Text
    self.Button[i]:SetNormalFontObject("GameFontNormalSmall");
    self.Button[i].text = Text;

    -- Button Texture
    local normalTexture = self.Button[i]:CreateTexture();
    normalTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Up");
    normalTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    normalTexture:SetAllPoints();
    self.Button[i]:SetNormalTexture(normalTexture);
    local highlightTexture = self.Button[i]:CreateTexture();
    highlightTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Highlight");
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    highlightTexture:SetAllPoints();
    self.Button[i]:SetHighlightTexture(highlightTexture);
    local pushedTexture = self.Button[i]:CreateTexture();
    pushedTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Down");
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    pushedTexture:SetAllPoints();
    self.Button[i]:SetPushedTexture(pushedTexture);

    -- Button Setting
    if type(AethysRotationDB) ~= "table" then
      AethysRotationDB = {};
    end
    if type(AethysRotationDB.Toggles) ~= "table" then
      AethysRotationDB.Toggles = {};
    end
    if type(AethysRotationDB.Toggles[i]) ~= "boolean" then
      AethysRotationDB.Toggles[i] = true;
    end

    -- OnClick Callback
    self.Button[i]:SetScript("OnMouseDown",
      function (self, Button)
        if Button == "LeftButton" then
          AR.CmdHandler(CmdArg);
        end
      end
    );

    AR.ToggleIconFrame:UpdateButtonText(i);
    self.Button[i]:Show();
  end
  -- Update a button text
  function AR.ToggleIconFrame:UpdateButtonText (i)
    if AethysRotationDB.Toggles[i] then
      self.Button[i]:SetFormattedText("|cff00ff00%s|r", self.Button[i].text);
    else
      self.Button[i]:SetFormattedText("|cffff0000%s|r", self.Button[i].text);
    end
  end
