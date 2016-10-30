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
ER.MainFrame:RegisterEvent("ADDON_LOADED");

-- AddonLoaded
local function AfterLoaded ()
	ER.MainFrame:UnregisterEvent("ADDON_LOADED");
	ER.MainFrame:SetScript("OnUpdate", ER.Pulse);
	ER.TTDRefresh();
end
local function AddonLoaded (self, Event, Arg1)
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
			C_Timer.After(2, AfterLoaded);
		end
	end
end
ER.MainFrame:SetScript("OnEvent", AddonLoaded);

-- Main
local PulseTimer = 0;
local Spec;
function ER.Pulse ()
	if ER.GetTime(true) > PulseTimer then
		PulseTimer = ER.GetTime() + mathmin(select(4, GetNetStats()), 30)/1000; -- Put a 30ms max limiter to save FPS (less if latency is low).

		ER.CacheReset();
		ER.ResetIcons();
		ER.Nameplate.AddTTD();

		if ER.ON() and ER.Ready() then -- Check if we are ready to cast something to save FPS.
			Spec = GetSpecializationInfo(GetSpecialization()); -- To optimize, bad to call this OnUpdate (likely make event based on spec / change spec, TODO)
			if ER.APLs[Spec] then
				ER.APLs[Spec]();
			end
		end
	end
end

-- Is the player ready ?
-- TODO : IsCasting() and IsChanneling() may gives issues for Casters because I assume some may have to interrupt their casts/channels
-- 	to cast something else. Will also need tweak to handle the bosses that interrupts casts.
function ER.Ready ()
	return not Player:IsDeadOrGhost() and not IsMounted() and not Player:IsCasting() and not Player:IsChanneling();
end

-- Used to force a short/long pulse wait, it also resets the icons.
function ER.ChangePulseTimer (Offset)
	ER.ResetIcons();
	PulseTimer = ER.GetTime() + Offset;
end