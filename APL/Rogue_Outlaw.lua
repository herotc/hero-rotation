local addonName, ER = ...;

local function APL ()
	-- Saber Slash
	if UnitPower("player", SPELL_POWER_COMBO_POINTS) < 5 then
		ER.CastGCD(193315);
		return;
	-- Run Through
	else
		ER.CastGCD(2098);
		return;
	end
end

ER.SetAPL(260, APL);
