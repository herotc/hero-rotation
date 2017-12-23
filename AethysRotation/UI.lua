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
  


--- ============================ CONTENT ============================
--- ======= MAIN FRAME =======
  AR.MainIconFrame = CreateFrame("Frame", "AethysRotation_MainIconFrame", UIParent);
  AR.MainIconFrame.Part = {};
  AR.MainIconFrame.CooldownFrame = CreateFrame("Cooldown", "AethysRotation_MainIconCooldownFrame", AR.MainIconFrame, "AR_CooldownFrameTemplate");
  AR.SmallIconFrame = CreateFrame("Frame", "AethysRotation_SmallIconFrame", UIParent);
  AR.LeftIconFrame = CreateFrame("Frame", "AethysRotation_LeftIconFrame", UIParent);
  AR.NameplateIconFrame = CreateFrame("Frame", "AethysRotation_NameplateIconFrame", UIParent);
  AR.SuggestedIconFrame = CreateFrame("Frame", "AethysRotation_SuggestedIconFrame", UIParent);
  AR.ToggleIconFrame = CreateFrame("Frame", "AethysRotation_ToggleIconFrame", UIParent);

--- ======= MISC =======
  -- Reset Textures
  local IdleSpellTexture = AR.GetTexture(Spell(9999000000));
  function AR.ResetIcons ()
    -- Main Icon
    AR.MainIconFrame:Hide();
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

    -- Toggle icons
    if AR.GUISettings.General.HideToggleIcons then AR.ToggleIconFrame:Hide(); end
  end

  -- Create a Backdrop
  function AR:CreateBackdrop (Frame)
    if Frame.Backdrop or not AR.GUISettings.General.BlackBorderIcon then return; end

    local Backdrop = CreateFrame("Frame", nil, Frame);
    Frame.Backdrop = Backdrop;
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
    if Frame:GetFrameLevel() - 2 >= 0 then
      Backdrop:SetFrameLevel(Frame:GetFrameLevel() - 2);
    else
      Backdrop:SetFrameLevel(0);
    end
  end

--- ======= MAIN ICON =======
  -- Init
  function AR.MainIconFrame:Init ()
    -- Frame Init
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(64);
    self:SetHeight(64);
    self:SetPoint("BOTTOMRIGHT", AR.MainFrame, "BOTTOMRIGHT", 0, 0);
    -- Texture
    self.Texture = self:CreateTexture(nil, "ARTWORK");
    self.Texture:SetAllPoints(self);
    -- Cooldown
    self.CooldownFrame:SetAllPoints(self);
    -- Keybind
    local KeybindFrame = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    self.Keybind = KeybindFrame;
    KeybindFrame:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE");
    KeybindFrame:SetAllPoints(true);
    KeybindFrame:SetJustifyH("RIGHT");
    KeybindFrame:SetJustifyV("TOP");
    KeybindFrame:SetPoint("TOPRIGHT");
    KeybindFrame:SetTextColor(0.8,0.8,0.8,1);
    KeybindFrame:SetText("");
    -- Overlay Text
    local TextFrame = self:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    self.Text = TextFrame;
    TextFrame:SetAllPoints(true);
    TextFrame:SetJustifyH("CENTER");
    TextFrame:SetJustifyV("CENTER");
    TextFrame:SetPoint("CENTER");
    TextFrame:SetTextColor(1,1,1,1);
    TextFrame:SetText("");
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon then
      self.Texture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
    -- Parts
    self:InitParts();
    -- Display
    self:Show();
  end
  -- Change Icon
  function AR.MainIconFrame:ChangeIcon (Texture, Keybind)
    -- Texture
    self.Texture:SetTexture(Texture);
    self.Texture:SetAllPoints(self);
    -- Keybind
    if Keybind then
      self.Keybind:SetText(Keybind);
    else
      self.Keybind:SetText("");
    end
    -- Overlay Text
    self.Text:SetText("");
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then
      self.Backdrop:Show();
    end
    -- Display
    if not self:IsVisible() then
      self:Show();
    end
  end
  -- Set text on frame
  function AR.MainIconFrame:OverlayText(Text)
    self.Text:SetText(Text);
  end
  -- Set a Cooldown Frame
  function AR.MainIconFrame:SetCooldown (Start, Duration)
    self.CooldownFrame:SetCooldown(Start, Duration);
  end
  function AR.MainIconFrame:InitParts ()
    for i = 1, AR.MaxQueuedCasts do
      -- Frame Init
      local PartFrame = CreateFrame("Frame", "AethysRotation_MainIconPartFrame"..tostring(i), UIParent);
      self.Part[i] = PartFrame;
      PartFrame:SetFrameStrata(self:GetFrameStrata());
      PartFrame:SetFrameLevel(self:GetFrameLevel() + 1);
      PartFrame:SetWidth(64);
      PartFrame:SetHeight(64);
      PartFrame:SetPoint("Left", self, "Left", 0, 0);
      -- Texture
      PartFrame.Texture = PartFrame:CreateTexture(nil, "BACKGROUND");
      -- Keybind
      PartFrame.Keybind = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
      PartFrame.Keybind:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE");
      PartFrame.Keybind:SetAllPoints(true);
      PartFrame.Keybind:SetJustifyH("RIGHT");
      PartFrame.Keybind:SetJustifyV("TOP");
      PartFrame.Keybind:SetPoint("TOPRIGHT");
      PartFrame.Keybind:SetTextColor(0.8,0.8,0.8,1);
      PartFrame.Keybind:SetText("");
      -- Black Border Icon
      if AR.GUISettings.General.BlackBorderIcon then
        PartFrame.Texture:SetTexCoord(.08, .92, .08, .92);
        AR:CreateBackdrop(PartFrame);
      end
      -- Display
      PartFrame:Show();
    end
  end
  local QueuedCasts, FrameWidth;
  function AR.MainIconFrame:SetupParts (Textures, Keybinds)
    QueuedCasts = #Textures;
    FrameWidth = (64 / QueuedCasts) * (AethysRotationDB.GUISettings["General.ScaleUI"] or 1)
    for i = 1, QueuedCasts do
      local PartFrame = self.Part[i];
      -- Size & Position
      PartFrame:SetWidth(FrameWidth);
      PartFrame:SetPoint("Left", self, "Left", FrameWidth*(i-1), 0);
      -- Texture
      PartFrame.Texture:SetTexture(Textures[i]);
      PartFrame.Texture:SetAllPoints(PartFrame);
      PartFrame.Texture:SetTexCoord(i == 1 and (AR.GUISettings.General.BlackBorderIcon and 0.08 or 0) or (i-1)/QueuedCasts,
                                            i == AR.MaxQueuedCasts and (AR.GUISettings.General.BlackBorderIcon and 0.92 or 1) or i/QueuedCasts,
                                            AR.GUISettings.General.BlackBorderIcon and 0.08 or 0,
                                            AR.GUISettings.General.BlackBorderIcon and 0.92 or 1);
      PartFrame.Keybind:SetText(Keybinds[i]);
      -- Keybind
      if Keybind then
        PartFrame.Keybind:SetText(Keybinds[i]);
      else
        PartFrame.Keybind:SetText("");
      end
      -- Display
      if not PartFrame:IsVisible() then
        PartFrame:Show();
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
    -- Frame Container
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(64);
    self:SetHeight(32);
    self:SetPoint("BOTTOMLEFT", AR.MainIconFrame, "TOPLEFT", 0, AR.GUISettings.General.BlackBorderIcon and 1 or 0);

    -- Frames
    self.Icon = {};
    self:CreateIcons(1, "LEFT");
    self:CreateIcons(2, "RIGHT");

    -- Display
    self:Show();
  end
  -- Create Small Icons Frames
  function AR.SmallIconFrame:CreateIcons (Index, Align)
    -- Frame Init
    local IconFrame = CreateFrame("Frame", "AethysRotation_SmallIconFrame"..tostring(Index), UIParent);
    self.Icon[Index] = IconFrame;
    IconFrame:SetFrameStrata(self:GetFrameStrata());
    IconFrame:SetFrameLevel(self:GetFrameLevel() - 1);
    IconFrame:SetWidth(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    IconFrame:SetHeight(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    IconFrame:SetPoint(Align, self, Align, 0, 0);
    -- Texture
    IconFrame.Texture = IconFrame:CreateTexture(nil, "ARTWORK");
    -- Keybind
    local Keybind = IconFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    IconFrame.Keybind = Keybind;
    Keybind:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE");
    Keybind:SetAllPoints(true);
    Keybind:SetJustifyH("RIGHT");
    Keybind:SetJustifyV("TOP");
    Keybind:SetPoint("TOPRIGHT");
    Keybind:SetTextColor(0.8,0.8,0.8,1);
    Keybind:SetText("");
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon then
      IconFrame.Texture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(IconFrame);
    end
    -- Display
    IconFrame:Show();
  end
  -- Change Icon
  function AR.SmallIconFrame:ChangeIcon (FrameID, Texture, Keybind)
    local IconFrame = self.Icon[FrameID];
    -- Texture
    IconFrame.Texture:SetTexture(Texture);
    IconFrame.Texture:SetAllPoints(IconFrame);
    -- Keybind
    if Keybind then
      IconFrame.Keybind:SetText(Keybind);
    else
      IconFrame.Keybind:SetText("");
    end
    -- Display
    if not IconFrame:IsVisible() then
      IconFrame:Show();
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
    -- Frame Init
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(48);
    self:SetHeight(48);
    self:SetPoint("RIGHT", AR.MainIconFrame, "LEFT", AR.GUISettings.General.BlackBorderIcon and -1 or 0, 0);
    -- Texture
    self.Texture = self:CreateTexture(nil, "BACKGROUND");
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon then
      self.Texture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
    -- Display
    self:Show();
  end
  -- Change Icon
  function AR.LeftIconFrame:ChangeIcon (Texture)
    -- Texture
    self.Texture:SetTexture(Texture);
    self.Texture:SetAllPoints(self);
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then
      self.Backdrop:Show();
    end
    -- Display
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
    local Token = stringlower(ThisUnit.UnitID);
    local Nameplate = C_NamePlate.GetNamePlateForUnit(Token);
    if Nameplate then
      -- ElvUI compatibility
      local ElvUINameplates, ElvUINUF;
      if _G.ElvUI then
        local ElvUIEngine = ElvUI[1];
        ElvUINameplates = ElvUIEngine.NamePlates;
        ElvUINUF = Nameplate.unitFrame;
      end
      -- Locals
      local BlizzardNUF = Nameplate.UnitFrame;
      local IconFrame = AR.NameplateIconFrame;

      -- Init Frame if not already
      if not AR.Nameplate.Initialized then
        -- Frame
        IconFrame:SetFrameStrata(BlizzardNUF:GetFrameStrata());
        IconFrame:SetFrameLevel(BlizzardNUF:GetFrameLevel() + 50);
        IconFrame:SetWidth(BlizzardNUF:GetHeight());
        IconFrame:SetHeight(BlizzardNUF:GetHeight());
        -- Texture
        IconFrame.Texture = IconFrame:CreateTexture(nil, "BACKGROUND");

        if AR.GUISettings.General.BlackBorderIcon then
          IconFrame.Texture:SetTexCoord(.08, .92, .08, .92);
          AR:CreateBackdrop(IconFrame);
        end

        AR.Nameplate.Initialized = true;
      end

      -- Set the Texture
      IconFrame.Texture:SetTexture(AR.GetTexture(Object));
      IconFrame.Texture:SetAllPoints(IconFrame);
      if not IconFrame:IsVisible() then
        local HealthBar = ElvUINameplates and ElvUINUF.HealthBar or BlizzardNUF.healthBar;
        IconFrame:SetPoint("CENTER", HealthBar, "CENTER", 0, 0);
        IconFrame:Show();
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
    -- Frame Init
    self:SetFrameStrata(AR.MainFrame:GetFrameStrata());
    self:SetFrameLevel(AR.MainFrame:GetFrameLevel() - 1);
    self:SetWidth(32);
    self:SetHeight(32);
    self:SetPoint("BOTTOM", AR.MainIconFrame, "LEFT", -AR.LeftIconFrame:GetWidth()/2, AR.LeftIconFrame:GetHeight()/2+(AR.GUISettings.General.BlackBorderIcon and 3 or 4));
    -- Texture
    self.Texture = self:CreateTexture(nil, "BACKGROUND");
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon then
      self.Texture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
    -- Display
    self:Show();
  end
  -- Change Icon
  function AR.SuggestedIconFrame:ChangeIcon (Texture)
    -- Texture
    self.Texture:SetTexture(Texture);
    self.Texture:SetAllPoints(self);
    -- Black Border Icon
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then
      self.Backdrop:Show();
    end
    -- Display
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
    -- Frame Init
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
    local ButtonFrame = CreateFrame("Button", "$parentButton"..tostring(i), self);
    ButtonFrame:SetFrameStrata(self:GetFrameStrata());
    ButtonFrame:SetFrameLevel(self:GetFrameLevel() - 1);
    ButtonFrame:SetWidth(20);
    ButtonFrame:SetHeight(20);
    ButtonFrame:SetPoint("LEFT", self, "LEFT", 20*(i-1)+i, 0);

    -- Button Tooltip (Optional)
    if Tooltip then
      ButtonFrame:SetScript("OnEnter",
        function ()
          GameTooltip:SetOwner(AR.ToggleIconFrame, "ANCHOR_BOTTOM", 0, 0);
          GameTooltip:ClearLines();
          GameTooltip:SetBackdropColor(0, 0, 0, 1);
          GameTooltip:SetText(Tooltip, nil, nil, nil, 1, true);
          GameTooltip:Show();
        end
      );
      ButtonFrame:SetScript("OnLeave",
        function ()
          GameTooltip:Hide();
        end
      );
    end

    -- Button Text
    ButtonFrame:SetNormalFontObject("GameFontNormalSmall");
    ButtonFrame.text = Text;

    -- Button Texture
    local NormalTexture = ButtonFrame:CreateTexture();
    NormalTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Up");
    NormalTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    NormalTexture:SetAllPoints();
    ButtonFrame:SetNormalTexture(NormalTexture);
    local HighlightTexture = ButtonFrame:CreateTexture();
    HighlightTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Highlight");
    HighlightTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    HighlightTexture:SetAllPoints();
    ButtonFrame:SetHighlightTexture(HighlightTexture);
    local PushedTexture = ButtonFrame:CreateTexture();
    PushedTexture:SetTexture("Interface/Buttons/UI-Silver-Button-Down");
    PushedTexture:SetTexCoord(0, 0.625, 0, 0.7875);
    PushedTexture:SetAllPoints();
    ButtonFrame:SetPushedTexture(PushedTexture);

    -- Button Setting
    if type(AethysRotationCharDB) ~= "table" then
      AethysRotationCharDB = {};
    end
    if type(AethysRotationCharDB.Toggles) ~= "table" then
      AethysRotationCharDB.Toggles = {};
    end
    if type(AethysRotationCharDB.Toggles[i]) ~= "boolean" then
      AethysRotationCharDB.Toggles[i] = true;
    end

    -- OnClick Callback
    ButtonFrame:SetScript("OnMouseDown",
      function (self, Button)
        if Button == "LeftButton" then
          AR.CmdHandler(CmdArg);
        end
      end
    );

    self.Button[i] = ButtonFrame;

    AR.ToggleIconFrame:UpdateButtonText(i);

    ButtonFrame:Show();
  end
  -- Update a button text
  function AR.ToggleIconFrame:UpdateButtonText (i)
    if AethysRotationCharDB.Toggles[i] then
      self.Button[i]:SetFormattedText("|cff00ff00%s|r", self.Button[i].text);
    else
      self.Button[i]:SetFormattedText("|cffff0000%s|r", self.Button[i].text);
    end
  end


