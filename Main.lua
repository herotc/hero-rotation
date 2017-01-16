local addonName, ER = ...;

--- Localize Vars
-- ER
local Unit = ER.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = ER.Spell;
local Item = ER.Item;
-- Lua
local mathmin = math.min;
local select = select;

-- Create the MainFrame
ER.MainFrame = CreateFrame("Frame", "EasyRaid_MainFrame", UIParent);
ER.MainFrame:SetFrameStrata(ER.GUISettings.General.MainFrameStrata);
ER.MainFrame:SetWidth(112);
ER.MainFrame:SetHeight(116);
ER.MainFrame:SetClampedToScreen(true);
ER.MainFrame:EnableMouse(true);
ER.MainFrame:SetMovable(true);
  -- Start Move
  ER.MainFrame:SetScript("OnMouseDown",
    function (self)
      if IsShiftKeyDown() then
        self:StartMoving();
      end
    end
  );
  -- Stop Move
  ER.MainFrame:SetScript("OnMouseUp",
    function (self)
      if IsShiftKeyDown() then
        self:StopMovingOrSizing();
        if not ERSettings then
          ERSettings = {};
        end
        ERSettings.IconFramePos = {self:GetPoint()};
      end
    end
  );
-- AddonLoaded
ER.MainFrame:RegisterEvent("ADDON_LOADED");
ER.MainFrame:SetScript("OnEvent", function (self, Event, Arg1)
    if Event == "ADDON_LOADED" then
      if Arg1 == "EasyRaid" then
        if ERSettings and ERSettings.IconFramePos then
          ER.MainFrame:SetPoint(ERSettings.IconFramePos[1], UIParent, ERSettings.IconFramePos[3], ERSettings.IconFramePos[4], ERSettings.IconFramePos[5]);
        else
          ER.MainFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0);
        end
        ER.MainFrame:Show();
        ER.MainIconFrame:Init();
        ER.LeftIconFrame:Init();
        ER.SmallIconFrame:Init();
        ER.ToggleIconFrame:Init();
        C_Timer.After(2, function ()
            ER.MainFrame:UnregisterEvent("ADDON_LOADED");
            ER.MainFrame:SetScript("OnUpdate", ER.Pulse);
          end
        );
      end
    end
  end
);

-- Main
local Timer = {
  Pulse = 0,
  TTD = 0
};
function ER.Pulse ()
  if ER.GetTime(true) > Timer.Pulse then
    Timer.Pulse = ER.GetTime() + mathmin(select(4, GetNetStats()), 30)/1000; -- Put a 30ms max limiter to save FPS (less if latency is low).
    ER.CacheHasBeenReset = false;

    if ER.GetTime() > Timer.TTD then
      Timer.Pulse = ER.GetTime() + ER.TTD.Settings.Refresh;
      ER.CacheReset();
      ER.TTDRefresh();
      ER.Nameplate.AddTTD();
    end

    ER.ResetIcons();
    if ER.ON() and ER.Ready() then -- Check if we are ready to cast something to save FPS.
      ER.CacheReset();
      if ER.APLs[ER.PersistentCache.Player.Spec[1]] then
        ER.APLs[ER.PersistentCache.Player.Spec[1]]();
      end
    end
  end
end

-- Is the player ready ?
-- TODO : IsCasting() and IsChanneling() may gives issues for Casters because I assume some may have to interrupt their casts/channels
--   to cast something else. Will also need tweak to handle the bosses that interrupts casts.
function ER.Ready ()
  return not Player:IsDeadOrGhost() and not Player:IsMounted() and not Player:IsCasting() and not Player:IsChanneling();
end

-- Used to force a short/long pulse wait, it also resets the icons.
function ER.ChangePulseTimer (Offset)
  ER.ResetIcons();
  PulseTimer = ER.GetTime() + Offset;
end