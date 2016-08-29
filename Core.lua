local addonName, ER = ...;

-- Defines the APL
ER.APLs = {};
function ER.SetAPL (Spec, APL)
	ER.APLs[Spec] = APL;
end

-- Get the texture (and cache it).
ER.SavedTextures = {};
function ER.GetTexture (SpellID)
	if not ER.SavedTextures[SpellID] then
		ER.SavedTextures[SpellID] = GetSpellTexture(SpellID);
	end
	return ER.SavedTextures[SpellID];
end

-- Display the Spell On GCD to cast
function ER.CastGCD (SpellID)
	ER.MainIconFrame:ChangeMainIcon(ER.GetTexture(SpellID));
end

-- Display the Spell Off GCD to cast
function ER.CastOffGCD (SpellID)
	ER.SmallIconFrame:ChangeSmallIcon(ER.GetTexture(SpellID));
end
