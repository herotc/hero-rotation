local addonName, ER = ...;

ER.MainIconFrame = CreateFrame("Frame", "EasyRogueIconFrame", UIParent);
ER.SmallIconFrame = CreateFrame("Frame", "EasyRogueIconFrame", UIParent);

--- Main Icon (On GCD)
-- Init
function ER.MainIconFrame:Init ()
	self:SetFrameStrata("BACKGROUND");
	self:SetWidth(64);
	self:SetHeight(64);
	if ERSettings and ERSettings.IconFramePos then
		self:SetPoint("CENTER", ERSettings.IconFramePos[4], ERSettings.IconFramePos[5]);
	else
		self:SetPoint("CENTER", 0, 0);
	end
	self:SetClampedToScreen(true);
	self:EnableMouse(true);
	self:SetMovable(true);
	self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
	self:Show();
end
-- Start Move
ER.MainIconFrame:SetScript("OnMouseDown",
	function (self)
		self:StartMoving();
	end
);
-- Stop Move
ER.MainIconFrame:SetScript("OnMouseUp",
	function (self)
		self:StopMovingOrSizing();
		if not ERSettings then
			ERSettings = {};
		end
		ERSettings.IconFramePos = {self:GetPoint()};
	end
);
-- Change Texture
function ER.MainIconFrame:ChangeMainIcon (TextureID)
	self.TempTexture:SetTexture(TextureID);
	self.TempTexture:SetAllPoints(self);
	self.texture = self.TempTexture;
end


--- Small Icons (Off GCD), Only 1 atm
-- Init
function ER.SmallIconFrame:Init ()
	self:SetFrameStrata("BACKGROUND");
	self:SetWidth(32);
	self:SetHeight(32);
	self:SetPoint("BOTTOMLEFT", ER.MainIconFrame, "TOPLEFT", 0, 0);
	self.TempTexture = self:CreateTexture(nil, "BACKGROUND");
	self:Show();
end
-- Change Texture
function ER.SmallIconFrame:ChangeSmallIcon (TextureID)
	self.TempTexture:SetTexture(TextureID);
	self.TempTexture:SetAllPoints(self);
	self.texture = self.TempTexture;
end
