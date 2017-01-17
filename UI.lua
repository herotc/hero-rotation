local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local pairs = pairs;
local stringlower = string.lower;
local tostring = tostring;
-- UI Locals
local FrameID, Nameplate, ThisUnit, Count; -- ER.Nameplate.AddTTD (& AddIcon for Nameplate)
local Token; -- ER.Nameplate.AddIcon


ER.MainIconFrame = CreateFrame("Frame", "EasyRaid_MainIconFrame", UIParent);
ER.MainIconFrame.TempTexture = ER.MainIconFrame:CreateTexture(nil, "BACKGROUND");
ER.LeftIconFrame = CreateFrame("Frame", "EasyRaid_LeftIconFrame", UIParent);
ER.SmallIconFrame = CreateFrame("Frame", "EasyRaid_SmallIconFrame", UIParent);
ER.ToggleIconFrame = CreateFrame("Frame", "EasyRaid_ToggleIconFrame", UIParent);
ER.NameplateIconFrame = CreateFrame("Frame", "EasyRaid_NameplateIconFrame", UIParent);


--- Reset Textures
local IdleSpell = Spell(134400);
function ER.ResetIcons ()
  ER.MainIconFrame:ChangeMainIcon(ER.GetTexture(IdleSpell)); -- "No Icon"
  ER.SmallIconFrame:HideIcons();
  ER.CastOffGCDOffset = 1;
  if ER.Nameplate.IconAdded then
    ER.Nameplate.RemoveIcon();
  end
end

--- Main Icon (On GCD)
  -- Init
  function ER.MainIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(64);
    self:SetPoint("BOTTOMRIGHT", ER.MainFrame, "BOTTOMRIGHT", 0, 20);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function ER.MainIconFrame:ChangeMainIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
  end


--- Small Icons (Off GCD), Only 2 atm.
  -- Init
  function ER.SmallIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(32);
    self:SetPoint("BOTTOMLEFT", ER.MainIconFrame, "TOPLEFT", 0, 0);
    self:Show();
    self.Icon = {};
    self.Icon[1] = CreateFrame("Frame", "EasyRaid_SmallIconFrame1", UIParent);
    self.Icon[1]:SetWidth(32);
    self.Icon[1]:SetHeight(32);
    self.Icon[1]:SetPoint("LEFT", self, "LEFT", 0, 0);
    self.Icon[1].TempTexture = self.Icon[1]:CreateTexture(nil, "BACKGROUND");
    self.Icon[1]:Show();
    self.Icon[2] = CreateFrame("Frame", "EasyRaid_SmallIconFrame2", UIParent);
    self.Icon[2]:SetWidth(32);
    self.Icon[2]:SetHeight(32);
    self.Icon[2]:SetPoint("RIGHT", self, "RIGHT", 0, 0);
    self.Icon[2].TempTexture = self.Icon[2]:CreateTexture(nil, "BACKGROUND");
    self.Icon[2]:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function ER.SmallIconFrame:ChangeSmallIcon (FrameID, Texture)
    self.Icon[FrameID].TempTexture:SetTexture(Texture);
    self.Icon[FrameID].TempTexture:SetAllPoints(self.Icon[FrameID]);
    self.Icon[FrameID].texture = self.Icon[FrameID].TempTexture;
    if not self.Icon[FrameID]:IsVisible() then
      self.Icon[FrameID]:Show();
    end
  end
  -- Hide Small Icons
  function ER.SmallIconFrame:HideIcons ()
    for i = 1, #self.Icon do
      self.Icon[i]:Hide();
    end
  end

--- Left Icon (MO)
  -- Init LeftIcon
  function ER.LeftIconFrame:Init ()
    self:SetWidth(48);
    self:SetHeight(48);
    self:SetPoint("RIGHT", ER.MainIconFrame, "LEFT", 0, 0);
    self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
    self:Show();
  end
  -- Change Texture (1 Arg for Texture, 3 Args for Color)
  function ER.LeftIconFrame:ChangeLeftIcon (Texture)
    self.TempTexture:SetTexture(Texture);
    self.TempTexture:SetAllPoints(self);
    self.texture = self.TempTexture;
    if not self:IsVisible() then
      self:Show();
    end
  end

--- Toggle Icons

  -- Init
  function ER.ToggleIconFrame:Init ()
    self:SetWidth(64);
    self:SetHeight(20);
    self:SetPoint("TOPLEFT", ER.MainIconFrame, "BOTTOMLEFT", 0, 0);
    self:SetFrameStrata(ER.GUISettings.General.MainFrameStrata);
    self:SetFrameLevel(ER.MainIconFrame:GetFrameLevel() + 1);
    self:EnableMouse(true);
    self:AddButton("C", 1, "CDs");
    self:AddButton("A", 2, "AoE");
    self:AddButton("O", 3, "On/Off");
    self:Show();
  end

  -- Button
  ER.Button = {};
  function ER.ToggleIconFrame:AddButton (Text, i, Tooltip)
    ER.Button[i] = CreateFrame("Button", "$parentButton"..tostring(i), self);
    ER.Button[i]:SetPoint("LEFT", self, "LEFT", 20*(i-1)+i, 0);
    ER.Button[i]:SetWidth(20);
    ER.Button[i]:SetHeight(20);
    ER.Button[i].TimeSinceLastUpdate = 0;
    ER.Button[i].UpdateInterval = 0.25;
    ER.Button[i]:SetScript("OnUpdate",
      function (self, elapsed)
        self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
        if self.TimeSinceLastUpdate > self.UpdateInterval then
          if ERSettings.Toggles[i] then
            ER.Button[i]:SetFormattedText("|cff00ff00%s|r", Text);
          else
            ER.Button[i]:SetFormattedText("|cffff0000%s|r", Text);
          end
          self.TimeSinceLastUpdate = 0;
        end
      end
    );
    if Tooltip then
      ER.Button[i]:SetScript("OnEnter",
        function (self)
          GameTooltip:SetOwner(ER.ToggleIconFrame, "ANCHOR_BOTTOM", 0, 0);
          GameTooltip:ClearLines();
          GameTooltip:SetBackdropColor(0, 0, 0, 1);
          GameTooltip:SetText(Tooltip, nil, nil, nil, 1, true);
          GameTooltip:Show();
        end
      );
      ER.Button[i]:SetScript("OnLeave",
        function (self)
          GameTooltip:Hide();
        end
      );
    end
    ER.Button[i]:SetNormalFontObject("GameFontNormalSmall");
    local ntex = ER.Button[i]:CreateTexture();
    ntex:SetTexture("Interface/Buttons/UI-Silver-Button-Up");
    ntex:SetTexCoord(0, 0.625, 0, 0.7875);
    ntex:SetAllPoints();
    ER.Button[i]:SetNormalTexture(ntex);
    local htex = ER.Button[i]:CreateTexture();
    htex:SetTexture("Interface/Buttons/UI-Silver-Button-Highlight");
    htex:SetTexCoord(0, 0.625, 0, 0.7875);
    htex:SetAllPoints();
    ER.Button[i]:SetHighlightTexture(htex);
    local ptex = ER.Button[i]:CreateTexture();
    ptex:SetTexture("Interface/Buttons/UI-Silver-Button-Down");
    ptex:SetTexCoord(0, 0.625, 0, 0.7875);
    ptex:SetAllPoints();
    ER.Button[i]:SetPushedTexture(ptex);
    if not ERSettings then
      ERSettings = {};
    end
    if not ERSettings.Toggles then
      ERSettings.Toggles = {};
    end
    ERSettings.Toggles[i] = true;
    local Argument = i == 1 and "cds" or i == 2 and "aoe" or i == 3 and "toggle";
    ER.Button[i]:SetScript("OnMouseDown",
      function (self, Button)
        if Button == "LeftButton" then
          ER.CmdHandler(Argument);
        end
      end
    );
    ER.Button[i]:Show();
  end


--- Nameplates

  ER.Nameplate = {
    IconInit = false,
    IconAdded = false,
    TTD = {},
    MPP = false
  };

  -- Add TTD Infos to Nameplates
  function ER.Nameplate.AddTTD ()
    ER.Nameplate.HideTTD();
    for i = 1, 40 do
      Count = tostring(i);

      Nameplate = C_NamePlate.GetNamePlateForUnit("nameplate"..Count);
      if Nameplate then
        -- Update TTD
        if Nameplate.UnitFrame.unitExists then
          FrameID = Nameplate:GetName();
          -- Init Frame if not already
          if not ER.Nameplate.TTD[FrameID] then
            ER.Nameplate.TTD[FrameID] = Nameplate:CreateFontString("NamePlate"..Count.."ER-TTD", UIParent, "GameFontHighlightSmallOutline")
            ER.Nameplate.TTD[FrameID]:SetJustifyH("CENTER");
            ER.Nameplate.TTD[FrameID]:SetJustifyV("CENTER");
            ER.Nameplate.TTD[FrameID]:SetText("");
          end
          ThisUnit = Unit["Nameplate"..Count];
          ER.Nameplate.TTD[FrameID]:SetText(ThisUnit:TimeToDie() < 6666 and tostring(ThisUnit:TimeToDie()) or "");
          if not ER.Nameplate.TTD[FrameID]:IsVisible() then
            ER.Nameplate.TTD[FrameID]:SetPoint("LEFT", Nameplate.UnitFrame.name, "CENTER", (Nameplate.UnitFrame.healthBar:GetWidth()/2)+ER.GUISettings.NameplatesTTD.XOffset, ER.GUISettings.NameplatesTTD.YOffset)
            ER.Nameplate.TTD[FrameID]:Show();
          end
        end

      end
    end
  end

  -- Hide the TTD Text
  function ER.Nameplate.HideTTD ()
    for Key, Value in pairs(ER.Nameplate.TTD) do
      -- Hide the FontString if it is visible
      if Value:IsVisible() then
        Value:Hide();
      end
    end
  end

  -- Add the Icon on Nameplates (and on Left Icon frame)
  function ER.Nameplate.AddIcon (ThisUnit, SpellID)
    Token = stringlower(ThisUnit.UnitID);
    Nameplate = C_NamePlate.GetNamePlateForUnit(Token);
    if Nameplate then
      -- Init Frame if not already
      if not ER.Nameplate.IconInit then
        -- Frame
        ER.NameplateIconFrame:SetFrameLevel(Nameplate.UnitFrame:GetFrameLevel() + 50);
        ER.NameplateIconFrame:SetWidth(Nameplate.UnitFrame:GetHeight()*0.8);
        ER.NameplateIconFrame:SetHeight(Nameplate.UnitFrame:GetHeight()*0.8);

        -- Texture
        ER.NameplateIconFrame.TempTexture = ER.NameplateIconFrame:CreateTexture(nil, "BACKGROUND");

        ER.Nameplate.Init = true;
      end

      -- Set the Texture
      ER.NameplateIconFrame.TempTexture:SetTexture(ER.GetTexture(SpellID));
      ER.NameplateIconFrame.TempTexture:SetAllPoints(ER.NameplateIconFrame);
      ER.NameplateIconFrame.texture = ER.NameplateIconFrame.TempTexture;
      if not ER.NameplateIconFrame:IsVisible() then
        ER.NameplateIconFrame:SetPoint("CENTER", Nameplate.UnitFrame.healthBar, "CENTER", 0, 0);
        ER.NameplateIconFrame:Show();
      end

      -- Display the left icon
      ER.LeftIconFrame:ChangeLeftIcon(ER.GetTexture(SpellID));

      -- Register the Unit for Error Checks (see Not Facing Unit Blacklist in Events.lua)
      ER.LastUnitCycled = ThisUnit;
      ER.LastUnitCycledTime = ER.GetTime();

      ER.Nameplate.IconAdded = true;
    end
  end

  -- Remove Icons
  function ER.Nameplate.RemoveIcon () -- TODO: Improve performance
    -- Nameplate Icon
    if ER.NameplateIconFrame:IsVisible() then
      ER.NameplateIconFrame:Hide();
    end
    -- Left Icon
    if ER.LeftIconFrame:IsVisible() then
      ER.LeftIconFrame:Hide();
    end
    ER.Nameplate.IconAdded = false;
  end
