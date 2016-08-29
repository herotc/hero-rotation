local addonName, ER = ...;

ER.MainFrame = CreateFrame("Frame", "EasyRogueEventFrame", UIParent);
ER.MainFrame:RegisterEvent("ADDON_LOADED");

-- AddonLoaded
local function AddonLoaded (self, Event, Arg1)
	if Event == "ADDON_LOADED" and Arg1 == "EasyRogue" then
		ER.MainIconFrame:Init();
		ER.MainIconFrame:ChangeMainIcon(134400); -- Default Main Icon
		ER.SmallIconFrame:Init();
		ER.SmallIconFrame:ChangeSmallIcon(134400); -- Default Small Icon
		ER.MainFrame:SetScript("OnUpdate", ER.Pulse);
	end
end
ER.MainFrame:SetScript("OnEvent", AddonLoaded);

-- Main
local PulseTimer = 0;
function ER.Pulse ()
	if GetTime() > PulseTimer then
		local Spec = GetSpecializationInfo(GetSpecialization()); -- To optimize, bad to call this OnUpdate (likely make event based on spec / change spec, TODO)
		if ER.APLs[Spec] then
			ER.APLs[Spec]();
		end
		PulseTimer = GetTime() + 0.050; -- Put a 50ms limiter. TODO : Improve
	end
end
