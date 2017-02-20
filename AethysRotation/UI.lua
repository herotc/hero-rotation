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
local pairs = pairs;
local stringlower = string.lower;
local tostring = tostring;
-- UI Locals
local FrameID, Nameplate; -- AR.Nameplate.AddTTD (& AddIcon for Nameplate)
local Token; -- AR.Nameplate.AddIcon


--- Create Frames
AR.MainIconFrame = CreateFrame("Frame", "AethysRotation_MainIconFrame", UIParent);
AR.MainIconFrame.CooldownFrame = CreateFrame("Cooldown", "AethysRotation_MainIconCooldownFrame", AR.MainIconFrame, "CooldownFrameTemplate");
AR.MainIconFrame.TempTexture = AR.MainIconFrame:CreateTexture(nil, "BACKGROUND");
AR.SmallIconFrame = CreateFrame("Frame", "AethysRotation_SmallIconFrame", UIParent);
AR.LeftIconFrame = CreateFrame("Frame", "AethysRotation_LeftIconFrame", UIParent);
AR.NameplateIconFrame = CreateFrame("Frame", "AethysRotation_NameplateIconFrame", UIParent);
AR.ToggleIconFrame = CreateFrame("Frame", "AethysRotation_ToggleIconFrame", UIParent);


--- Reset Textures
local IdleSpell = Spell(9999000000);
function AR.ResetIcons ()
  AR.MainIconFrame:ChangeMainIcon(AR.GetTexture(IdleSpell)); -- "No Icon"
  if AR.GUISettings.General.BlackBorderIcon then AR.MainIconFrame.Backdrop:Hide(); end
  AR.SmallIconFrame:HideIcons();
  AR.CastOffGCDOffset = 1;
  if AR.Nameplate.IconAdded then
    AR.Nameplate.RemoveIcon();
  end
end

--- Create a Backdrop
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

  if Frame:GetFrameLevel() - 1 >= 0 then
    Backdrop:SetFrameLevel(Frame:GetFrameLevel() - 1);
  else
    Backdrop:SetFrameLevel(0);
  end

  Frame.Backdrop = Backdrop;
end

--- Main Icon (On GCD)
  -- Init
  function AR.MainIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(64);
    self:SetPoint("BOTTOMRIGHT", AR.MainFrame, "BOTTOMRIGHT", 0, 20);
    self.CooldownFrame:SetAllPoints(self);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    if AR.GUISettings.General.BlackBorderIcon then
      self.TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self);
    end
    self:Show();
  end

  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.MainIconFrame:ChangeMainIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if AR.GUISettings.General.BlackBorderIcon and not self.Backdrop:IsVisible() then self.Backdrop:Show(); end
  end

  -- Set a Cooldown Frame
  function AR.MainIconFrame:SetCooldown (Start, Duration)
    self.CooldownFrame:SetCooldown(Start, Duration);
  end

--- Small Icons (Off GCD), Only 2 atm.
  -- Init
  function AR.SmallIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(32);
    self:SetPoint("BOTTOMLEFT", AR.MainIconFrame, "TOPLEFT", 0, AR.GUISettings.General.BlackBorderIcon and 1 or 0);
    self:Show();
    self.Icon = {};

    self.Icon[1] = CreateFrame("Frame", "AethysRotation_SmallIconFrame1", UIParent);
    self.Icon[1]:SetWidth(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[1]:SetHeight(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[1]:SetPoint("LEFT", self, "LEFT", 0, 0);
    self.Icon[1].TempTexture = self.Icon[1]:CreateTexture(nil, "BACKGROUND");

    self.Icon[2] = CreateFrame("Frame", "AethysRotation_SmallIconFrame2", UIParent);
    self.Icon[2]:SetWidth(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[2]:SetHeight(AR.GUISettings.General.BlackBorderIcon and 30 or 32);
    self.Icon[2]:SetPoint("RIGHT", self, "RIGHT", 0, 0);
    self.Icon[2].TempTexture = self.Icon[2]:CreateTexture(nil, "BACKGROUND");

    if AR.GUISettings.General.BlackBorderIcon then
      self.Icon[1].TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self.Icon[1]);
      self.Icon[2].TempTexture:SetTexCoord(.08, .92, .08, .92);
      AR:CreateBackdrop(self.Icon[2]);
    end

    self.Icon[1]:Show();
    self.Icon[2]:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.SmallIconFrame:ChangeSmallIcon (FrameID, Texture)
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

--- Left Icon (MO)
  -- Init LeftIcon
  function AR.LeftIconFrame:Init ()
    self:SetWidth(48);
    self:SetHeight(48);
    self:SetPoint("RIGHT", AR.MainIconFrame, "LEFT", 0, 0);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function AR.LeftIconFrame:ChangeLeftIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if not self:IsVisible() then
      self:Show();
    end
  end

--- Nameplates

  AR.Nameplate = {
    IconInit = false,
    IconAdded = false
  };

  -- Add the Icon on Nameplates (and on Left Icon frame)
  function AR.Nameplate.AddIcon (ThisUnit, SpellID)
    Token = stringlower(ThisUnit.UnitID);
    Nameplate = C_NamePlate.GetNamePlateForUnit(Token);
    if Nameplate then
      -- Init Frame if not already
      if not AR.Nameplate.IconInit then
        -- Frame
        AR.NameplateIconFrame:SetFrameLevel(Nameplate.UnitFrame:GetFrameLevel() + 50);
        AR.NameplateIconFrame:SetWidth(Nameplate.UnitFrame:GetHeight()*0.8);
        AR.NameplateIconFrame:SetHeight(Nameplate.UnitFrame:GetHeight()*0.8);

        -- Texture
        AR.NameplateIconFrame.TempTexture = AR.NameplateIconFrame:CreateTexture(nil, "BACKGROUND");

        AR.Nameplate.Init = true;
      end

      -- Set the Texture
      AR.NameplateIconFrame.TempTexture:SetTexture(AR.GetTexture(SpellID));
      AR.NameplateIconFrame.TempTexture:SetAllPoints(AR.NameplateIconFrame);
      AR.NameplateIconFrame.texture = AR.NameplateIconFrame.TempTexture;
      if not AR.NameplateIconFrame:IsVisible() then
        AR.NameplateIconFrame:SetPoint("CENTER", Nameplate.UnitFrame.healthBar, "CENTER", 0, 0);
        AR.NameplateIconFrame:Show();
      end

      -- Display the left icon
      AR.LeftIconFrame:ChangeLeftIcon(AR.GetTexture(SpellID));

      -- Register the Unit for Error Checks (see Not Facing Unit Blacklist in Events.lua)
      AR.LastUnitCycled = ThisUnit;
      AR.LastUnitCycledTime = AC.GetTime();

      AR.Nameplate.IconAdded = true;
    end
  end

  -- Remove Icons
  function AR.Nameplate.RemoveIcon () -- TODO: Improve performance
    -- Nameplate Icon
    if AR.NameplateIconFrame:IsVisible() then AR.NameplateIconFrame:Hide(); end
    -- Left Icon
    if AR.LeftIconFrame:IsVisible() then AR.LeftIconFrame:Hide(); end

    AR.Nameplate.IconAdded = false;
  end

--- Toggle Icons

  -- Init
  function AR.ToggleIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(20);
    self:SetPoint("TOPLEFT", AR.MainIconFrame, "BOTTOMLEFT", 0, AR.GUISettings.General.BlackBorderIcon and -3 or 0);
    self:SetFrameStrata(AR.GUISettings.General.MainFrameStrata);
    self:SetFrameLevel(AR.MainIconFrame:GetFrameLevel() + 1);
    self:AddButton("C", 1, "CDs");
    self:AddButton("A", 2, "AoE");
    self:AddButton("O", 3, "On/Off");
    self:Show();
  end

  -- Button
  AR.Button = {};
  function AR.ToggleIconFrame:AddButton (Text, i, Tooltip)
    AR.Button[i] = CreateFrame("Button", "$parentButton"..tostring(i), self);
    AR.Button[i]:SetPoint("LEFT", self, "LEFT", 20*(i-1)+i, 0);
    AR.Button[i]:SetWidth(20);
    AR.Button[i]:SetHeight(20);
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
