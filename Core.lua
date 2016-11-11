local addonName, ER = ...;

--- Localize Vars
-- Lua
local error = error;
local mathfloor = math.floor;
local mathmin = math.min;
local pairs = pairs;
local print = print;
local select = select;
local stringlower = string.lower;
local setmetatable = setmetatable;
local tableinsert = table.insert;
local tableremove = table.remove;
local tonumber = tonumber;
local tostring = tostring;
local unpack = unpack;
local wipe = table.wipe;
-- Core Locals
local _T = { -- Temporary Vars
	Argument, -- CmdHandler
	Parts, -- NPCID
	ThisUnit, -- GetEnemies / TTDRefresh
	DistanceValues, -- GetEnemies
	Start, End, -- CastPercentage
	Infos, -- GetBuffs / GetDebuffs
	ExpirationTime -- BuffRemains / DebuffRemains
};
-- Max # Buffs and Max # Nameplates.
ER.MAXIMUM = 40; 
-- Defines our cached tables.
ER.PersistentCache = {
	Equipment = {},
	SpellLearned = {Pet = {}, Player = {}},
	Texture = {Spell = {}, Item = {}}
};
ER.Cache = {
	APLVar = {},
	Enemies = {},
	EnemiesCount = {},
	GUIDInfo = {},
	MiscInfo = {},
	SpellInfo = {},
	ItemInfo = {},
	UnitInfo = {}
};
function ER.CacheReset ()
	for Key, Value in pairs(ER.Cache) do
		wipe(ER.Cache[Key]);
	end
end

-- Get the GetTime and cache it.
function ER.GetTime (Reset)
	if not ER.Cache.MiscInfo then ER.Cache.MiscInfo = {}; end
	if not ER.Cache.MiscInfo.GetTime or Reset then
		ER.Cache.MiscInfo.GetTime = GetTime();
	end
	return ER.Cache.MiscInfo.GetTime;
end

-- Print with ER Prefix
function ER.Print (...)
	print("[|cFFFF6600Easy Raid|r]", ...);
end

-- Defines the APL
ER.APLs = {};
function ER.SetAPL (Spec, APL)
	ER.APLs[Spec] = APL;
end

-- Get the texture (and cache it until next reload).
function ER.GetTexture (Object)
	if Object.SpellID then
		if not ER.PersistentCache.Texture.Spell[Object.SpellID] then
			ER.PersistentCache.Texture.Spell[Object.SpellID] = GetSpellTexture(Object.SpellID);
		end
		return ER.PersistentCache.Texture.Spell[Object.SpellID];
	elseif Object.ItemID then
		if not ER.PersistentCache.Texture.Item[Object.ItemID] then
			ER.PersistentCache.Texture.Item[Object.ItemID] = ({GetItemInfo(Object.ItemID)})[10];
		end
		return ER.PersistentCache.Texture.Item[Object.ItemID];
	end
end

-- Display the Spell to cast.
ER.CastOffGCDOffset = 1;
function ER.Cast (Object, OffGCD)
	if OffGCD and OffGCD[1] then
		if ER.CastOffGCDOffset <= 2 then
			ER.SmallIconFrame:ChangeSmallIcon(ER.CastOffGCDOffset, ER.GetTexture(Object));
			ER.CastOffGCDOffset = ER.CastOffGCDOffset + 1;
			Object.LastDisplayTime = ER.GetTime();
			return OffGCD[2] and "Should Return" or false;
		end
	else
		ER.MainIconFrame:ChangeMainIcon(ER.GetTexture(Object));
		Object.LastDisplayTime = ER.GetTime();
		return "Should Return";
	end
	return false;
end


function ER.CmdHandler (Message)
	_T.Argument = stringlower(Message);
	if _T.Argument == "cds" then
		ERSettings.Toggles[1] = not ERSettings.Toggles[1];
		ER.Print("CDs are now "..(ERSettings.Toggles[1] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
	elseif _T.Argument == "aoe" then
		ERSettings.Toggles[2] = not ERSettings.Toggles[2];
		ER.Print("AoE is now "..(ERSettings.Toggles[2] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
	elseif _T.Argument == "toggle" then
		ERSettings.Toggles[3] = not ERSettings.Toggles[3];
		ER.Print("EasyRaid is now "..(ERSettings.Toggles[3] and "|cff00ff00enabled|r." or "|cffff0000disabled|r."));
	elseif _T.Argument == "help" then
		ER.Print("CDs : /eraid cds | AoE : /eraid cds | Toggle : /eraid toggle");
	end
end
SLASH_EASYRAID1 = "/eraid"
SlashCmdList["EASYRAID"] = ER.CmdHandler;

-- Get if the CDs are enabled.
function ER.CDsON ()
	return ERSettings.Toggles[1];
end

-- Get if the AoE is enabled.
function ER.AoEON ()
	return ERSettings.Toggles[2];
end

-- Get if the main toggle is on.
function ER.ON ()
	return ERSettings.Toggles[3];
end

--- ============== CLASS FUNCTIONS ==============
	-- Class
	local function Class ()
		local Table, MetaTable = {}, {};
		Table.__index = Table;
		MetaTable.__call = function (self, ...)
			local Object = {};
			setmetatable(Object, self);
			if Object.Constructor then Object:Constructor(...); end
			return Object;
		end;
		setmetatable(Table, MetaTable);
		return Table;
	end

	-- Defines the Unit Class.
	ER.Unit = Class();
	local Unit = ER.Unit;
	-- Unit Constructor
	function Unit:Constructor (UnitID)
		self.UnitID = UnitID;
	end
	-- Defines Unit Objects.
	Unit.Player = Unit("Player");
	Unit.Target = Unit("Target");
	for i = 1, ER.MAXIMUM do
		Unit["Nameplate"..tostring(i)] = Unit("Nameplate"..tostring(i));
	end
	-- Locals
	local Player = Unit.Player;
	local Target = Unit.Target;

	-- Defines the Spell Class.
	ER.Spell = Class();
	local Spell = ER.Spell;
	-- Spell Constructor
	function Spell:Constructor (ID, Type, DmgFormula)
		self.SpellID = ID;
		self.SpellType = Type or "Player"; -- For Pet, put "Pet". Default is "Player".
		self.DmgFormula = DmgFormula or false;
		self.LastCastTime = 0;
		self.LastDisplayTime = 0;
	end

	-- Defines the Item Class.
	ER.Item = Class();
	local Item = ER.Item;
	-- Item Constructor
	function Item:Constructor (ID)
		self.ItemID = ID;
		self.LastCastTime = 0;
	end


--- ============== UNIT CLASS ==============

	-- Get the unit GUID.
	function Unit:GUID ()
		if not ER.Cache.GUIDInfo[self.UnitID] then
			ER.Cache.GUIDInfo[self.UnitID] = UnitGUID(self.UnitID);
		end
		return ER.Cache.GUIDInfo[self.UnitID];
	end

	-- Get if the unit Exists and is visible.
	function Unit:Exists ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if ER.Cache.UnitInfo[self:GUID()].Exists == nil then
				ER.Cache.UnitInfo[self:GUID()].Exists = UnitExists(self.UnitID) and UnitIsVisible(self.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].Exists;
		end
		return nil;
	end

	-- Get the unit NPC ID.
	function Unit:NPCID ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].NPCID then
				_T.Parts = {};
				for Part in string.gmatch(self:GUID(), "([^-]+)") do
					tableinsert(_T.Parts, Part);
				end
				if _T.Parts[1] == "Creature" or _T.Parts[1] == "Pet" or _T.Parts[1] == "Vehicle" then
					ER.Cache.UnitInfo[self:GUID()].NPCID = tonumber(_T.Parts[6]);
				else
					ER.Cache.UnitInfo[self:GUID()].NPCID = -2;
				end
			end
			return ER.Cache.UnitInfo[self:GUID()].NPCID;
		end
		return -1;
	end

	-- Get if the unit CanAttack the other one.
	function Unit:CanAttack (Other)
		if self:GUID() and Other:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].CanAttack then ER.Cache.UnitInfo[self:GUID()].CanAttack = {}; end
			if ER.Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()] == nil then
				ER.Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()] = UnitCanAttack(self.UnitID, Other.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()];
		end
		return nil;
	end

	local DummyUnits = {
		[31146] = true
	};
	function Unit:IsDummy ()
		return self:NPCID() >= 0 and DummyUnits[self:NPCID()] == true;
	end

	-- Get the unit Health.
	function Unit:Health ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].Health then
				ER.Cache.UnitInfo[self:GUID()].Health = UnitHealth(self.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].Health;
		end
		return -1;
	end

	-- Get the unit MaxHealth.
	function Unit:MaxHealth ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].MaxHealth then
				ER.Cache.UnitInfo[self:GUID()].MaxHealth = UnitHealthMax(self.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].MaxHealth;
		end
		return -1;
	end

	-- Get the unit Health Percentage
	function Unit:HealthPercentage ()
		return self:Health() ~= -1 and self:MaxHealth() ~= -1 and self:Health()/self:MaxHealth()*100;
	end

	-- Get if the unit Is Dead Or Ghost.
	function Unit:IsDeadOrGhost ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if ER.Cache.UnitInfo[self:GUID()].IsDeadOrGhost == nil then
				ER.Cache.UnitInfo[self:GUID()].IsDeadOrGhost = UnitIsDeadOrGhost(self.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].IsDeadOrGhost;
		end
		return nil;
	end

	-- Get if the unit Affecting Combat.
	function Unit:AffectingCombat ()
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if ER.Cache.UnitInfo[self:GUID()].AffectingCombat == nil then
				ER.Cache.UnitInfo[self:GUID()].AffectingCombat = UnitAffectingCombat(self.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].AffectingCombat;
		end
		return nil;
	end

	-- Get if two unit are the same.
	function Unit:IsUnit (Other)
		if self:GUID() and Other:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].IsUnit then ER.Cache.UnitInfo[self:GUID()].IsUnit = {}; end
			if ER.Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()] == nil then
				ER.Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()] = UnitIsUnit(self.UnitID, Other.UnitID);
			end
			return ER.Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()];
		end
		return nil;
	end

	-- Get if we are in range of the unit.
	ER.IsInRangeItemTable = {
		[5]		=	37727,	-- Ruby Acorn
		[6]		=	63427,	-- Worgsaw
		[8]		=	34368,	-- Attuned Crystal Cores
		[10]	=	32321,	-- Sparrowhawk Net
		[15]	=	33069,	-- Sturdy Rope
		[20]	=	10645,	-- Gnomish Death Ray
		[25]	=	41509,	-- Frostweave Net
		[30]	=	34191,	-- Handful of Snowflakes
		[35]	=	18904,	-- Zorbin's Ultra-Shrinker
		[40]	=	28767,	-- The Decapitator
		[45]	=	23836,	-- Goblin Rocket Launcher
		[50]	=	116139,	-- Haunting Memento
		[60]	=	32825,	-- Soul Cannon
		[70]	=	41265,	-- Eyesore Blaster
		[80]	=	35278,	-- Reinforced Net
		[100]	=	33119	-- Malister's Frost Wand
	};
	function Unit:IsInRange (Distance)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if not ER.Cache.UnitInfo[self:GUID()].IsInRange then ER.Cache.UnitInfo[self:GUID()].IsInRange = {}; end
			if ER.Cache.UnitInfo[self:GUID()].IsInRange[Distance] == nil then
				ER.Cache.UnitInfo[self:GUID()].IsInRange[Distance] = IsItemInRange(ER.IsInRangeItemTable[Distance], self.UnitID) or false;
			end
			return ER.Cache.UnitInfo[self:GUID()].IsInRange[Distance];
		end
		return nil;
	end

	-- Get if we are Tanking or not the Unit.
	-- TODO: Use both GUID like CanAttack / IsUnit for better management.
	function Unit:IsTanking (Other)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
			if ER.Cache.UnitInfo[self:GUID()].Tanked == nil then
				ER.Cache.UnitInfo[self:GUID()].Tanked = UnitThreatSituation(self.UnitID, Other.UnitID) and UnitThreatSituation(self.UnitID, Other.UnitID) >= 2 and true or false;
			end
			return ER.Cache.UnitInfo[self:GUID()].Tanked;
		end
		return nil;
	end

	--- Get all the casting infos from an unit and put it into the Cache.
	function Unit:GetCastingInfo ()
		if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
		ER.Cache.UnitInfo[self:GUID()].Casting = {UnitCastingInfo(self.UnitID)};
	end

	-- Get the Casting Infos from the Cache.
	function Unit:CastingInfo (Index)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] or not ER.Cache.UnitInfo[self:GUID()].Casting then
				self:GetCastingInfo();
			end
			if Index then
				return ER.Cache.UnitInfo[self:GUID()].Casting[Index];
			else
				return unpack(ER.Cache.UnitInfo[self:GUID()].Casting);
			end
		end
		return nil;
	end

	-- Get if the unit is casting or not.
	function Unit:IsCasting ()
		return self:CastingInfo(1) and true or false;
	end

	-- Get the unit cast's name if there is any.
	function Unit:CastName ()
		return self:IsCasting() and self:CastingInfo(1) or "";
	end

	--- Get all the Channeling Infos from an unit and put it into the Cache.
	function Unit:GetChannelingInfo ()
		if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
		ER.Cache.UnitInfo[self:GUID()].Channeling = {UnitChannelInfo(self.UnitID)};
	end

	-- Get the Channeling Infos from the Cache.
	function Unit:ChannelingInfo (Index)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] or not ER.Cache.UnitInfo[self:GUID()].Channeling then
				self:GetChannelingInfo();
			end
			if Index then
				return ER.Cache.UnitInfo[self:GUID()].Channeling[Index];
			else
				return unpack(ER.Cache.UnitInfo[self:GUID()].Channeling);
			end
		end
		return nil;
	end

	-- Get if the unit is xhanneling or not.
	function Unit:IsChanneling ()
		return self:ChannelingInfo(1) and true or false;
	end

	-- Get the unit channel's name if there is any.
	function Unit:ChannelName ()
		return self:IsChanneling() and self:ChannelingInfo(1) or "";
	end

	-- Get if the unit cast is interruptible if there is any.
	function Unit:IsInterruptible ()
		return (self:CastingInfo(9) == false or self:ChannelingInfo(8) == false) and true or false;
	end

	-- Get the progression of the cast in percentage if there is any.
	function Unit:CastPercentage ()
		if self:IsCasting() then
			_T.Start, _T.End = select(5, self:CastingInfo());
			return (ER.GetTime()*1000 - _T.Start)/(_T.End - _T.Start)*100;
		end
		if self:IsChanneling() then
			_T.Start, _T.End = select(5, self:ChannelingInfo());
			return (ER.GetTime()*1000 - _T.Start)/(_T.End - _T.Start)*100;
		end
		return -1;
	end

	--- Get all the buffs from an unit and put it into the Cache.
	function Unit:GetBuffs ()
		if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
		ER.Cache.UnitInfo[self:GUID()].Buffs = {};
		for i = 1, ER.MAXIMUM do
			_T.Infos = {UnitBuff(self.UnitID, i)};
			if not _T.Infos[11] then break; end
			tableinsert(ER.Cache.UnitInfo[self:GUID()].Buffs, _T.Infos);
		end
	end

	-- buff.foo.up (does return the buff table and not only true/false)
	function Unit:Buff (Spell, Index, AnyCaster)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] or not ER.Cache.UnitInfo[self:GUID()].Buffs then
				self:GetBuffs();
			end
			for i = 1, #ER.Cache.UnitInfo[self:GUID()].Buffs do
				if Spell:ID() == ER.Cache.UnitInfo[self:GUID()].Buffs[i][11] then
					if AnyCaster or (ER.Cache.UnitInfo[self:GUID()].Buffs[i][8] and Player:IsUnit(Unit(ER.Cache.UnitInfo[self:GUID()].Buffs[i][8]))) then
						if Index then
							return ER.Cache.UnitInfo[self:GUID()].Buffs[i][Index];
						else
							return unpack(ER.Cache.UnitInfo[self:GUID()].Buffs[i]);
						end
					end
				end
			end
		end
		return nil;
	end

	-- buff.foo.remains
	function Unit:BuffRemains (Spell, AnyCaster)
		_T.ExpirationTime = self:Buff(Spell, 7, AnyCaster);
		return _T.ExpirationTime and _T.ExpirationTime - ER.GetTime() or 0;
	end

	-- buff.foo.duration
	function Unit:BuffDuration (Spell, AnyCaster)
		return self:Buff(Spell, 6, AnyCaster) or 0;
	end

	-- buff.foo.stack
	function Unit:BuffStack (Spell, AnyCaster)
		return self:Buff(Spell, 4, AnyCaster) or 0;
	end

	-- buff.foo.refreshable (doesn't exists on SimC atm tho)
	function Unit:BuffRefreshable (Spell, PandemicThreshold, AnyCaster)
		if not self:Buff(Spell, nil, AnyCaster) then return true; end
		return PandemicThreshold and self:BuffRemains(Spell, AnyCaster) <= PandemicThreshold;
	end

	--- Get all the debuffs from an unit and put it into the Cache.
	function Unit:GetDebuffs ()
		if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
		ER.Cache.UnitInfo[self:GUID()].Debuffs = {};
		for i = 1, ER.MAXIMUM do
			_T.Infos = {UnitDebuff(self.UnitID, i)};
			if not _T.Infos[11] then break; end
			tableinsert(ER.Cache.UnitInfo[self:GUID()].Debuffs, _T.Infos);
		end
	end

	-- debuff.foo.up or dot.foo.up (does return the debuff table and not only true/false)
	function Unit:Debuff (Spell, Index, AnyCaster)
		if self:GUID() then
			if not ER.Cache.UnitInfo[self:GUID()] or not ER.Cache.UnitInfo[self:GUID()].Debuffs then
				self:GetDebuffs();
			end
			for i = 1, #ER.Cache.UnitInfo[self:GUID()].Debuffs do
				if Spell:ID() == ER.Cache.UnitInfo[self:GUID()].Debuffs[i][11] then
					if AnyCaster or (ER.Cache.UnitInfo[self:GUID()].Debuffs[i][8] and Player:IsUnit(Unit(ER.Cache.UnitInfo[self:GUID()].Debuffs[i][8]))) then
						if Index then
							return ER.Cache.UnitInfo[self:GUID()].Debuffs[i][Index];
						else
							return unpack(ER.Cache.UnitInfo[self:GUID()].Debuffs[i]);
						end
					end
				end
			end
		end
		return nil;
	end

	-- debuff.foo.remains or dot.foo.remains
	function Unit:DebuffRemains (Spell, AnyCaster)
		_T.ExpirationTime = self:Debuff(Spell, 7, AnyCaster);
		return _T.ExpirationTime and _T.ExpirationTime - ER.GetTime() or 0;
	end

	-- debuff.foo.duration or dot.foo.duration
	function Unit:DebuffDuration (Spell, AnyCaster)
		return self:Debuff(Spell, 6, AnyCaster) or 0;
	end

	-- debuff.foo.stack or dot.foo.stack
	function Unit:DebuffStack (Spell, AnyCaster)
		return self:Debuff(Spell, 4, AnyCaster) or 0;
	end

	-- debuff.foo.refreshable or dot.foo.refreshable
	function Unit:DebuffRefreshable (Spell, PandemicThreshold, AnyCaster)
		if not self:Debuff(Spell, nil, AnyCaster) then return true; end
		return PandemicThreshold and self:DebuffRemains(Spell, AnyCaster) <= PandemicThreshold;
	end

	--- Check if the unit is coded as blacklisted for Marked for Death (Rogue) or not.
	-- Most of the time if the unit doesn't really die and isn't the last unit of an instance.
	local IsMfdBlacklisted_NPCID;
	function Unit:IsMfdBlacklisted ()
		IsMfdBlacklisted_NPCID = self:NPCID();
		--- Legion
			----- Dungeons (7.0 Patch) -----
			--- Halls of Valor
			-- Hymdall leaves the fight at 10%.
			if IsMfdBlacklisted_NPCID == 94960 then return true; end
			-- Solsten and Olmyr doesn't "really" die
			if IsMfdBlacklisted_NPCID == 102558 or IsMfdBlacklisted_NPCID == 97202 then return true; end

		--- Warlord of Draenor (WoD)
			----- HellFire Citadel (T18 - 6.2 Patch) -----
			--- Hellfire Assault
			-- Mar'Tak doesn't die and leave fight at 50% (blocked at 1hp anyway).
			if IsMfdBlacklisted_NPCID == 93023 then return true; end

			----- Dungeons (6.0 Patch) -----
			--- Shadowmoon Burial Grounds
			-- Carrion Worm : They doesn't die but leave the area at 10%.
			if IsMfdBlacklisted_NPCID == 88769 or IsMfdBlacklisted_NPCID == 76057 then return true; end
		return false;
	end

	--- TimeToDie
		ER.TTD = {
			Settings = {
				Refresh = 0.1, -- Refresh time (seconds) : min=0.1, max=2, default = 0.2, Aethys = 0.1
				HistoryTime = 10+0.4, -- History time (seconds) : min=5, max=120, default = 20, Aethys = 10
				HistoryCount = 100 -- Max history count : min=20, max=500, default = 120, Aethys = 100
			},
			_T = {
				-- Both
				Values,
				-- TTDRefresh
				UnitFound,
				Time,
				-- TimeToX
				Seconds,
				MaxHealth, StartingTime,
				UnitTable,
				MinSamples, -- In TimeToDie aswell
				a, b,
				n,
				x, y,
				Ex2, Ex, Exy, Ey,
				Invariant
			},
			Units = {},
			Throttle = 0
		};
		local TTD = ER.TTD;
		function ER.TTDRefresh ()
			for Key, Value in pairs(TTD.Units) do -- TODO: Need to be optimized
				TTD._T.UnitFound = false;
				for i = 1, ER.MAXIMUM do
					_T.ThisUnit = Unit["Nameplate"..tostring(i)];
					if Key == _T.ThisUnit:GUID() and _T.ThisUnit:Exists() then
						TTD._T.UnitFound = true;
					end
				end
				if not TTD._T.UnitFound then
					TTD.Units[Key] = nil;
				end
			end
			for i = 1, ER.MAXIMUM do
				_T.ThisUnit = Unit["Nameplate"..tostring(i)];
				if _T.ThisUnit:Exists() and Player:CanAttack(_T.ThisUnit) and _T.ThisUnit:Health() < _T.ThisUnit:MaxHealth() then
					if not TTD.Units[_T.ThisUnit:GUID()] or _T.ThisUnit:Health() > TTD.Units[_T.ThisUnit:GUID()][1][1][2] then
						TTD.Units[_T.ThisUnit:GUID()] = {{}, _T.ThisUnit:MaxHealth(), ER.GetTime(), -1};
					end
					TTD._T.Values = TTD.Units[_T.ThisUnit:GUID()][1];
					TTD._T.Time = ER.GetTime() - TTD.Units[_T.ThisUnit:GUID()][3];
					if _T.ThisUnit:Health() ~= TTD.Units[_T.ThisUnit:GUID()][4] then
						tableinsert(TTD._T.Values, 1, {TTD._T.Time, _T.ThisUnit:Health()});
						while (#TTD._T.Values > TTD.Settings.HistoryCount) or (TTD._T.Time - TTD._T.Values[#TTD._T.Values][1] > TTD.Settings.HistoryTime) do
							tableremove(TTD._T.Values);
						end
						TTD.Units[_T.ThisUnit:GUID()][4] = _T.ThisUnit:Health();
					end
				end
			end
			C_Timer.After(TTD.Settings.Refresh, ER.TTDRefresh);
		end

		-- Get the estimated time to reach a Percentage
		-- TODO : Cache the result, not done yet since we mostly use TimeToDie that cache for TimeToX 0%.
		-- Returns Codes :
		--	11111 : No GUID		9999 : Negative TTD		8888 : Not Enough Samples or No Health Change		7777 : No DPS		6666 : Dummy
		function Unit:TimeToX (Percentage, MinSamples) -- TODO : See with Skasch how accuracy & prediction can be improved.
			if self:IsDummy() then return 6666; end
			TTD._T.Seconds = 8888;
			TTD._T.UnitTable = TTD.Units[self:GUID()];
			TTD._T.MinSamples = MinSamples or 3;
			TTD._T.a, TTD._T.b = 0, 0;
			-- Simple linear regression
			-- ( E(x^2)   E(x) )  ( a )   ( E(xy) )
			-- ( E(x)       n  )  ( b ) = ( E(y)  )
			-- Format of the above: ( 2x2 Matrix ) * ( 2x1 Vector ) = ( 2x1 Vector )
			-- Solve to find a and b, satisfying y = a + bx
			-- Matrix arithmetic has been expanded and solved to make the following operation as fast as possible
			if TTD._T.UnitTable then
				TTD._T.Values = TTD._T.UnitTable[1];
				TTD._T.n = #TTD._T.Values;
				if TTD._T.n > MinSamples then
					TTD._T.MaxHealth = TTD._T.UnitTable[2];
					TTD._T.StartingTime = TTD._T.UnitTable[3];
					TTD._T.x, TTD._T.y = 0, 0;
					TTD._T.Ex2, TTD._T.Ex, TTD._T.Exy, TTD._T.Ey = 0, 0, 0, 0;
					
					for _, Value in pairs(TTD._T.Values) do
						TTD._T.x, TTD._T.y = unpack(Value);

						TTD._T.Ex2 = TTD._T.Ex2 + TTD._T.x * TTD._T.x;
						TTD._T.Ex = TTD._T.Ex + TTD._T.x;
						TTD._T.Exy = TTD._T.Exy + TTD._T.x * TTD._T.y;
						TTD._T.Ey = TTD._T.Ey + TTD._T.y;
					end
					-- Invariant to find matrix inverse
					TTD._T.Invariant = TTD._T.Ex2*TTD._T.n - TTD._T.Ex*TTD._T.Ex;
					-- Solve for a and b
					TTD._T.a = (-TTD._T.Ex * TTD._T.Exy / TTD._T.Invariant) + (TTD._T.Ex2 * TTD._T.Ey / TTD._T.Invariant);
					TTD._T.b = (TTD._T.n * TTD._T.Exy / TTD._T.Invariant) - (TTD._T.Ex * TTD._T.Ey / TTD._T.Invariant);
				end
			end
			if TTD._T.b ~= 0 then
				-- Use best fit line to calculate estimated time to reach target health
				TTD._T.Seconds = (Percentage * 0.01 * TTD._T.MaxHealth - TTD._T.a) / TTD._T.b;
				-- Subtract current time to obtain "time remaining"
				TTD._T.Seconds = mathmin(7777, TTD._T.Seconds - (ER.GetTime() - TTD._T.StartingTime));
				if TTD._T.Seconds < 0 then TTD._T.Seconds = 9999; end
			end
			return mathfloor(TTD._T.Seconds);
		end

		-- Get the unit TimeToDie
		function Unit:TimeToDie (MinSamples)
			if self:GUID() then
				TTD._T.MinSamples = MinSamples or 3;
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].TTD then ER.Cache.UnitInfo[self:GUID()].TTD = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] then
					-- TODO : Make a Table with a loop to avoid endless if
					-- Odyn (Halls of Valor)
					if self:NPCID() == 96589 then
						ER.Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] = self:TimeToX(80, TTD._T.MinSamples);
					-- Helya (Maw of Souls)
					elseif self:NPCID() == 96759 then
						ER.Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] = self:TimeToX(70, TTD._T.MinSamples);
					else
						ER.Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] = self:TimeToX(0, TTD._T.MinSamples);
					end
				end
				return ER.Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples];
			end
			return 11111;
		end

	--- PLAYER SPECIFIC

		-- gcd
		-- TODO : Improve perfs
		function Unit:GCD ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].GCD then
					local SpecID = GetSpecializationInfo(GetSpecialization());
					-- Rogue, Feral, Brewmaster, Windwalker got 1S.
					if ({UnitClass("player")})[2] == "ROGUE" or SpecID == 103 or SpecID == 268 or SpecID == 269 then
						ER.Cache.UnitInfo[self:GUID()].GCD = 1;
					else
						local GCD = 1.5/(1+self:HastePct()/100);
						ER.Cache.UnitInfo[self:GUID()].GCD = GCD > 0.75 and GCD or 0.75;
					end
				end
				return ER.Cache.UnitInfo[self:GUID()].GCD;
			end
		end

		-- attack_power
		-- TODO : Use Cache
		function Unit:AttackPower ()
			return UnitAttackPower(self.UnitID);
		end

		-- crit_chance
		-- TODO : Use Cache
		function Unit:CritChancePct ()
			return GetCritChance();
		end

		-- haste
		-- TODO : Use Cache
		function Unit:HastePct ()
			return GetHaste();
		end

		-- mastery
		-- TODO : Use Cache
		function Unit:MasteryPct ()
			return GetMasteryEffect();
		end

		-- versatility
		-- TODO : Use Cache
		function Unit:VersatilityDmgPct ()
			return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE);
		end

		----------------------------
		--- 3 | Energy Functions ---
		----------------------------
		-- energy.max
		function Unit:EnergyMax ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].EnergyMax then
					ER.Cache.UnitInfo[self:GUID()].EnergyMax = UnitPowerMax(self.UnitID, SPELL_POWER_ENERGY);
				end
				return ER.Cache.UnitInfo[self:GUID()].EnergyMax;
			end
		end
		-- energy
		function Unit:Energy ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].Energy then
					ER.Cache.UnitInfo[self:GUID()].Energy = UnitPower(self.UnitID, SPELL_POWER_ENERGY);
				end
				return ER.Cache.UnitInfo[self:GUID()].Energy;
			end
		end
		-- energy.regen
		function Unit:EnergyRegen ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].EnergyRegen then
					ER.Cache.UnitInfo[self:GUID()].EnergyRegen = select(2, GetPowerRegen(self.UnitID));
				end
				return ER.Cache.UnitInfo[self:GUID()].EnergyRegen;
			end
		end
		-- energy.pct
		function Unit:EnergyPercentage ()
			return (self:Energy() / self:EnergyMax()) * 100;
		end
		-- energy.deficit
		function Unit:EnergyDeficit ()
			return self:EnergyMax() - self:Energy();
		end
		-- "energy.deficit.pct"
		function Unit:EnergyDeficitPercentage ()
			return (self:EnergyDeficit() / self:EnergyMax()) * 100;
		end
		-- "energy.regen.pct"
		function Unit:EnergyRegenPercentage ()
			return (self:EnergyRegen() / self:EnergyMax()) * 100;
		end
		-- energy.time_to_max
		function Unit:EnergyTimeToMax ()
			if self:EnergyRegen() == 0 then return -1; end
			return self:EnergyDeficit() * (1 / self:EnergyRegen());
		end
		-- "energy.time_to_x"
		function Unit:EnergyTimeToX (Amount)
			if self:EnergyRegen() == 0 then return -1; end
			return Amount > self:Energy() and (Amount - self:Energy()) * (1 / self:EnergyRegen()) or 0;
		end
		-- "energy.time_to_x.pct"
		function Unit:EnergyTimeToXPercentage (Amount)
			if self:EnergyRegen() == 0 then return -1; end
			return Amount > self:EnergyPercentage() and (Amount - self:EnergyPercentage()) * (1 / self:EnergyRegenPercentage()) or 0;
		end

		----------------------------------
		--- 4 | Combo Points Functions ---
		----------------------------------
		-- combo_points.max
		function Unit:ComboPointsMax ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].ComboPointsMax then
					ER.Cache.UnitInfo[self:GUID()].ComboPointsMax = UnitPowerMax(self.UnitID, SPELL_POWER_COMBO_POINTS);
				end
				return ER.Cache.UnitInfo[self:GUID()].ComboPointsMax;
			end
		end
		-- combo_points
		function Unit:ComboPoints ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].ComboPoints then
					ER.Cache.UnitInfo[self:GUID()].ComboPoints = UnitPower(self.UnitID, SPELL_POWER_COMBO_POINTS);
				end
				return ER.Cache.UnitInfo[self:GUID()].ComboPoints;
			end
		end
		-- combo_points.deficit
		function Unit:ComboPointsDeficit ()
			return self:ComboPointsMax() - self:ComboPoints();
		end

		--------------------------------
		--- 9 | Holy Power Functions ---
		--------------------------------
		-- holy_power.max
		function Unit:HolyPowerMax ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].HolyPowerMax then
					ER.Cache.UnitInfo[self:GUID()].HolyPowerMax = UnitPowerMax(self.UnitID, SPELL_POWER_HOLY_POWER);
				end
				return ER.Cache.UnitInfo[self:GUID()].HolyPowerMax;
			end
		end
		-- holy_power
		function Unit:HolyPower ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].HolyPower then
					ER.Cache.UnitInfo[self:GUID()].HolyPower = UnitPower(self.UnitID, SPELL_POWER_HOLY_POWER);
				end
				return ER.Cache.UnitInfo[self:GUID()].HolyPower;
			end
		end
		-- holy_power.pct
		function Unit:HolyPowerPercentage ()
			return (self:HolyPower() / self:HolyPowerMax()) * 100;
		end
		-- holy_power.deficit
		function Unit:HolyPowerDeficit ()
			return self:HolyPowerMax() - self:HolyPower();
		end
		-- "holy_power.deficit.pct"
		function Unit:HolyPowerDeficitPercentage ()
			return (self:HolyPowerDeficit() / self:HolyPowerMax()) * 100;
		end

		---------------------------
		--- 17 | Fury Functions ---
		---------------------------
		-- fury.max
		function Unit:FuryMax ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].FuryMax then
					ER.Cache.UnitInfo[self:GUID()].FuryMax = UnitPowerMax(self.UnitID, SPELL_POWER_FURY);
				end
				return ER.Cache.UnitInfo[self:GUID()].FuryMax;
			end
		end
		-- fury
		function Unit:Fury ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].Fury then
					ER.Cache.UnitInfo[self:GUID()].Fury = UnitPower(self.UnitID, SPELL_POWER_FURY);
				end
				return ER.Cache.UnitInfo[self:GUID()].Fury;
			end
		end
		-- fury.pct
		function Unit:FuryPercentage ()
			return (self:Fury() / self:FuryMax()) * 100;
		end
		-- fury.deficit
		function Unit:FuryDeficit ()
			return self:FuryMax() - self:Fury();
		end
		-- "fury.deficit.pct"
		function Unit:FuryDeficitPercentage ()
			return (self:FuryDeficit() / self:FuryMax()) * 100;
		end

		---------------------------
		--- 18 | Pain Functions ---
		---------------------------
		-- pain.max
		function Unit:PainMax ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].PainMax then
					ER.Cache.UnitInfo[self:GUID()].PainMax = UnitPowerMax(self.UnitID, SPELL_POWER_PAIN);
				end
				return ER.Cache.UnitInfo[self:GUID()].PainMax;
			end
		end
		-- pain
		function Unit:Pain ()
			if self:GUID() then
				if not ER.Cache.UnitInfo[self:GUID()] then ER.Cache.UnitInfo[self:GUID()] = {}; end
				if not ER.Cache.UnitInfo[self:GUID()].PainMax then
					ER.Cache.UnitInfo[self:GUID()].PainMax = UnitPower(self.UnitID, SPELL_POWER_PAIN);
				end
				return ER.Cache.UnitInfo[self:GUID()].PainMax;
			end
		end
		-- pain.pct
		function Unit:PainPercentage ()
			return (self:Pain() / self:PainMax()) * 100;
		end
		-- pain.deficit
		function Unit:PainDeficit ()
			return self:PainMax() - self:Pain();
		end
		-- "pain.deficit.pct"
		function Unit:PainDeficitPercentage ()
			return (self:PainDeficit() / self:PainMax()) * 100;
		end

		-- Get if the player is stealthed or not
		local IsStealthedBuff = {
			-- Normal Stealth
			{
				-- Rogue
				Spell(1784), -- Stealth
				Spell(115191), -- Stealth w/ Subterfuge Talent
			},
			-- Combat Stealth
			{
				-- Rogue
				Spell(11327), -- Vanish
				Spell(115193), -- Vanish w/ Subterfuge Talent
				Spell(115192), -- Subterfuge Buff
				Spell(185422), -- Stealth from Shadow Dance
			},
			-- Special Stealth
			{
				-- Night Elf
				Spell(58984) -- Shadowmeld
			}
		};
		function Unit:IterateStealthBuffs (Abilities, Special)
			-- TODO: Add Assassination Spells when it'll be done and improve code
			-- TODO: Add Feral if we do supports it some day
			if Spell.Rogue.Outlaw.Shadowmeld:TimeSinceLastCast() < 0.3 
				or Spell.Rogue.Outlaw.Vanish:TimeSinceLastCast() < 0.3 
				or Spell.Rogue.Subtlety.ShadowDance:TimeSinceLastCast() < 0.3 
				or Spell.Rogue.Subtlety.Shadowmeld:TimeSinceLastCast() < 0.3 
				or Spell.Rogue.Subtlety.Vanish:TimeSinceLastCast() < 0.3 then
				return true;
			end
			-- Normal Stealth
			for i = 1, #IsStealthedBuff[1] do
				if self:Buff(IsStealthedBuff[1][i]) then
					return true;
				end
			end
			-- Combat Stealth
			if Abilities then
				for i = 1, #IsStealthedBuff[2] do
					if self:Buff(IsStealthedBuff[2][i]) then
						return true;
					end
				end
			end
			-- Special Stealth
			if Special then
				for i = 1, #IsStealthedBuff[3] do
					if self:Buff(IsStealthedBuff[3][i]) then
						return true;
					end
				end
			end
		end
		local IsStealthedKey;
		function Unit:IsStealthed (Abilities, Special)
			IsStealthedKey = tostring(Abilites).."-"..tostring(Special);
			if not ER.Cache.MiscInfo then ER.Cache.MiscInfo = {}; end
			if not ER.Cache.MiscInfo.IsStealthed then ER.Cache.MiscInfo.IsStealthed = {}; end
			if ER.Cache.MiscInfo.IsStealthed[IsStealthedKey] == nil then
				ER.Cache.MiscInfo.IsStealthed[IsStealthedKey] = self:IterateStealthBuffs(Abilities, Special);
			end
			return ER.Cache.MiscInfo.IsStealthed[IsStealthedKey];
		end

		-- Save the current player's equipment.
		ER.Equipment = {};
		function ER.GetEquipment ()
			local Item;
			for i = 1, 19 do
				Item = select(1, GetInventoryItemID("Player", i));
				-- If there is an item in that slot
				if Item ~= nil then
					ER.Equipment[i] = Item;
				end
			end
		end

		-- Check player set bonuses (call ER.GetEquipment before to refresh the current gear)
		local HasTierSlots = {
			1, -- INVSLOT_HEAD
			3, -- INVSLOT_SHOULDER
			5, -- INVSLOT_CHEST
			7, -- INVSLOT_LEGS
			10, -- INVSLOT_HAND
			15 -- INVSLOT_BACK
		};
		local HasTierSets = {
			["T18"] = {
				-- Warrior
				[1]		=	{[5] = 124319, [10] = 124329, [1] = 124334, [7] = 124340, [3] = 124346, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Paladin
				[2]		=	{[5] = 124318, [10] = 124328, [1] = 124333, [7] = 124339, [3] = 124345, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Hunter
				[3]		=	{[5] = 124284, [10] = 124292, [1] = 124296, [7] = 124301, [3] = 124307, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Rogue
				[4]		=	{[5] = 124248, [10] = 124257, [1] = 124263, [7] = 124269, [3] = 124274, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Priest
				[5]		=	{[5] = 124172, [10] = 124155, [1] = 124161, [7] = 124166, [3] = 124178, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- DeathKnight
				[6]		=	{[5] = 124317, [10] = 124327, [1] = 124332, [7] = 124338, [3] = 124344, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Shaman
				[7]		=	{[5] = 124303, [10] = 124293, [1] = 124297, [7] = 124302, [3] = 124308, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Mage
				[8]		=	{[5] = 124171, [10] = 124154, [1] = 124160, [7] = 124165, [3] = 124177, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Warlock
				[9]		=	{[5] = 124173, [10] = 124156, [1] = 124162, [7] = 124167, [3] = 124179, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Monk
				[10]	=	{[5] = 124247, [10] = 124256, [1] = 124262, [7] = 124268, [3] = 124273, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Druid
				[11]	=	{[5] = 124246, [10] = 124255, [1] = 124261, [7] = 124267, [3] = 124272, [15] = 999999},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Demon Hunter
				[12]	=	{[5] = 999999, [10] = 999999, [1] = 999999, [7] = 999999, [3] = 999999, [15] = 999999}		-- Chest, Hands, Head, Legs, Shoulder, Back
			},
			["T19"] = {
				-- Warrior
				[1]		=	{[5] = 138351, [10] = 138354, [1] = 138357, [7] = 138360, [3] = 138363, [15] = 138374},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Paladin
				[2]		=	{[5] = 138350, [10] = 138353, [1] = 138356, [7] = 138359, [3] = 138362, [15] = 138369},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Hunter
				[3]		=	{[5] = 138339, [10] = 138340, [1] = 138342, [7] = 138344, [3] = 138347, [15] = 138368},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Rogue
				[4]		=	{[5] = 138326, [10] = 138329, [1] = 138332, [7] = 138335, [3] = 138338, [15] = 138371},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Priest
				[5]		=	{[5] = 138319, [10] = 138310, [1] = 138313, [7] = 138316, [3] = 138322, [15] = 138370},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- DeathKnight
				[6]		=	{[5] = 138349, [10] = 138352, [1] = 138355, [7] = 138358, [3] = 138361, [15] = 138364},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Shaman
				[7]		=	{[5] = 138346, [10] = 138341, [1] = 138343, [7] = 138345, [3] = 138348, [15] = 138372},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Mage
				[8]		=	{[5] = 138318, [10] = 138309, [1] = 138312, [7] = 138315, [3] = 138321, [15] = 138365},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Warlock
				[9]		=	{[5] = 138320, [10] = 138311, [1] = 138314, [7] = 138317, [3] = 138323, [15] = 138373},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Monk
				[10]	=	{[5] = 138325, [10] = 138328, [1] = 138331, [7] = 138334, [3] = 138337, [15] = 138367},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Druid
				[11]	=	{[5] = 138324, [10] = 138327, [1] = 138330, [7] = 138333, [3] = 138336, [15] = 138366},		-- Chest, Hands, Head, Legs, Shoulder, Back
				-- Demon Hunter
				[12]	=	{[5] = 138376, [10] = 138377, [1] = 138378, [7] = 138379, [3] = 138380, [15] = 138375} 		-- Chest, Hands, Head, Legs, Shoulder, Back
			}
		};
		function ER.HasTier (Tier)
			-- Set Bonuses are disabled in Challenge Mode (Diff = 8) and in Proving Grounds (Map = 1148).
			local DifficultyID, _, _, _, _, MapID = select(3, GetInstanceInfo());
			if DifficultyID == 8 or MapID == 1148 then return 0; end
			-- Check gear
			local Count = 0;
			local Item, Slot;
			for i = 1, #HasTierSlots do
				Slot = HasTierSlots[i];
				Item = ER.Equipment[Slot];
				if Item and Item == HasTierSets[Tier][({UnitClass("player")})[3]][Slot] then
					Count = Count + 1;
				end
			end
			return Count > 1, Count > 3;
		end

		-- Check player class trinket (call ER.GetEquipment before to refresh the current gear)
		local HasClassTrinketsTable = {
			[1]		=	124523,	-- Warrior : Worldbreaker's Resolve
			[2]		=	124518,	-- Paladin : Libram of Vindication
			[3]		=	124515,	-- Hunter : Talisman of the Master Tracker
			[4]		=	124520,	-- Rogue : Bleeding Hollow Toxin Vessel
			[5]		=	124519,	-- Priest : Repudiation of War
			[6]		=	124513,	-- Death Knight : Reaper's Harvest
			[7]		=	124521,	-- Shaman : Core of the Primal Elements
			[8]		=	124516,	-- Mage : Tome of Shifting Words
			[9]		=	124522,	-- Warlock : Fragment of the Dark Star
			[10]	=	124517,	-- Monk : Sacred Draenic Incense
			[11]	=	124514,	-- Druid : Seed of Creation
			[12]	=	139630	-- Demon Hunter : Etching of Sargeras
		};
		function ER.HasClassTrinket ()
			local Item, Slot;
			for i = 13, 14 do
				Item = ER.Equipment[i];
				if Item and Item == HasClassTrinketsTable[({UnitClass("player")})[3]] then
					return true;
				end
			end
			return false;
		end

		-- Mythic Dungeon Abilites
		local MDA = {
			{Spell(200904), "Sapped Soul"},
			{Spell(200291), "Blade Dance Cast"},
			{Spell(200291), "Blade Dance Buff"}
		};
		function ER.MythicDungeon (Type)
			for i = 1, #MDA do
				if Player:Buff(MDA[i][1], nil, true) or Player:Debuff(MDA[i][1], nil, true) then
					return MDA[i][2];
				end
			end
			return "";
		end

---- UNIT MISC

-- Fill the Enemies Cache table.
function ER.GetEnemies (Distance)
	-- Prevent building the same table if it's already cached.
	if ER.Cache.Enemies[Distance] then return; end
	-- Init the Variables used to build the table.
	ER.Cache.Enemies[Distance] = {};
	-- Check if there is another Enemies table with a greater Distance to filter from it.
	if #ER.Cache.Enemies >= 1 then
		_T.DistanceValues = {};
		for Key, Value in pairs(ER.Cache.Enemies) do
			if Key > Distance then
				tableinsert(_T.DistanceValues, Key);
			end
		end
		-- Check if we have caught a table that we can use.
		if #_T.DistanceValues >= 1 then
			if #_T.DistanceValues >= 2 then
				table.sort(_T.DistanceValues, function(a, b) return a < b; end);
			end
			for Key, Value in pairs(ER.Cache.Enemies[_T.DistanceValues[1]]) do
				if Value:IsInRange(Distance) then
					tableinsert(ER.Cache.Enemies[Distance], Value);
				end
			end
			return;
		end
	end
	-- Else build from all the nameplates.
	for i = 1, ER.MAXIMUM do
		_T.ThisUnit = Unit["Nameplate"..tostring(i)];
		if _T.ThisUnit:Exists() and not _T.ThisUnit:IsDeadOrGhost() and Player:CanAttack(_T.ThisUnit) and _T.ThisUnit:IsInRange(Distance) then
			tableinsert(ER.Cache.Enemies[Distance], _T.ThisUnit);
		end
	end
	-- Cache the count of enemies
	ER.Cache.EnemiesCount[Distance] = #ER.Cache.Enemies[Distance];
end

--- ============== SPELL CLASS ==============

	-- Get the spell ID.
	function Spell:ID ()
		return self.SpellID;
	end

	-- Get the spell Type.
	function Spell:Type ()
		return self.SpellType;
	end

	-- Get the Time since Last spell Cast.
	function Spell:TimeSinceLastCast ()
		return ER.GetTime() - self.LastCastTime;
	end

	-- Get the Time since Last spell Display.
	function Spell:TimeSinceLastDisplay ()
		return ER.GetTime() - self.LastDisplayTime;
	end

	--- WoW Specific Function
		-- Get the spell Info.
		function Spell:Info (Type, Index)
			local Identifier;
			if Type == "ID" then
				Identifier = self:ID();
			elseif Type == "Name" then
				Identifier = self:Name();
			else
				error("Spell Info Type Missing.");
			end
			if Identifier then
				if not ER.Cache.SpellInfo[Identifier] then ER.Cache.SpellInfo[Identifier] = {}; end
				if not ER.Cache.SpellInfo[Identifier].Info then
					ER.Cache.SpellInfo[Identifier].Info = {GetSpellInfo(Identifier)};
				end
				if Index then
					return ER.Cache.SpellInfo[Identifier].Info[Index];
				else
					return unpack(ER.Cache.SpellInfo[Identifier].Info);
				end
			else
				error("Identifier Not Found.");
			end
		end

		-- Get the spell Info from the spell ID.
		function Spell:InfoID (Index)
			return self:Info("ID", Index);
		end

		-- Get the spell Info from the spell Name.
		function Spell:InfoName (Index)
			return self:Info("Name", Index);
		end

		-- Get the spell Name.
		function Spell:Name ()
			return self:Info("ID", 1);
		end

		-- Get the spell BookIndex along with BookType.
		function Spell:BookIndex ()
			local CurrentSpellID;
			-- Pet Book
			local NumPetSpells = HasPetSpells();
			if NumPetSpells then
				for i = 1, NumPetSpells do
					CurrentSpellID = select(7, GetSpellInfo(i, BOOKTYPE_PET));
					if CurrentSpellID and CurrentSpellID == self:ID() then
						return i, BOOKTYPE_PET;
					end
				end
			end
			-- Player Book
			local Offset, NumSpells, OffSpec;
			for i = 1, GetNumSpellTabs() do
				Offset, NumSpells, _, OffSpec = select(3, GetSpellTabInfo(i));
				-- GetSpellTabInfo has been updated, it now returns the OffSpec ID.
				-- If the OffSpec ID is set to 0, then it's the Main Spec.
				if OffSpec == 0 then
					for j = 1, (Offset + NumSpells) do
						CurrentSpellID = select(7, GetSpellInfo(j, BOOKTYPE_SPELL));
						if CurrentSpellID and CurrentSpellID == self:ID() then
							return j, BOOKTYPE_SPELL;
						end
					end
				end
			end
		end

		-- Check if the spell Is Available or not.
		function Spell:IsAvailable ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if ER.Cache.SpellInfo[self.SpellID].IsAvailable == nil then
				ER.Cache.SpellInfo[self.SpellID].IsAvailable = IsPlayerSpell(self.SpellID);
			end
			return ER.Cache.SpellInfo[self.SpellID].IsAvailable;
		end

		-- Check if the spell Is Known or not.
		function Spell:IsKnown (CheckPet)
			return IsSpellKnown(self.SpellID, CheckPet and CheckPet or false); 
		end

		-- Check if the spell Is Known (including Pet) or not.
		function Spell:IsPetKnown ()
			return self:IsKnown(true);
		end

		-- Check if the spell Is Usable or not.
		function Spell:IsUsable ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if ER.Cache.SpellInfo[self.SpellID].IsUsable == nil then
				ER.Cache.SpellInfo[self.SpellID].IsUsable = IsUsableSpell(self.SpellID);
			end
			return ER.Cache.SpellInfo[self.SpellID].IsUsable;
		end

		-- Get the spell Minimum Range.
		function Spell:MinimumRange ()
			return self:InfoID(5);
		end

		-- Get the spell Maximum Range.
		function Spell:MaximumRange ()
			return self:InfoID(6);
		end

		-- Check if the spell Is Melee or not.
		function Spell:IsMelee ()
			return self:MinimumRange() == 0 and self:MaximumRange() == 0;
		end

		-- Scan the Book to cache every Spell Learned.
		function Spell:BookScan ()
			local CurrentSpellID, CurrentSpell;
			-- Pet Book
			local NumPetSpells = HasPetSpells();
			if NumPetSpells then
				for i = 1, NumPetSpells do
					CurrentSpellID = select(7, GetSpellInfo(i, BOOKTYPE_PET))
					if CurrentSpellID then
						CurrentSpell = Spell(CurrentSpellID);
						if CurrentSpell:IsAvailable() and (CurrentSpell:IsKnown() or IsTalentSpell(i, BOOKTYPE_PET)) then
							ER.PersistentCache.SpellLearned.Pet[CurrentSpell:ID()] = true;
						end
					end
				end
			end
			-- Player Book (except Flyout Spells)
			local Offset, NumSpells, OffSpec;
			for i = 1, GetNumSpellTabs() do
				Offset, NumSpells, _, OffSpec = select(3, GetSpellTabInfo(i));
				-- GetSpellTabInfo has been updated, it now returns the OffSpec ID.
				-- If the OffSpec ID is set to 0, then it's the Main Spec.
				if OffSpec == 0 then
					for j = 1, (Offset + NumSpells) do
						CurrentSpellID = select(7, GetSpellInfo(j, BOOKTYPE_SPELL))
						if CurrentSpellID and GetSpellBookItemInfo(j, BOOKTYPE_SPELL) == "SPELL" then
							--[[ Debug Code
							CurrentSpell = Spell(CurrentSpellID);
							print(
								tostring(CurrentSpell:ID()) .. " | " .. 
								tostring(CurrentSpell:Name()) .. " | " .. 
								tostring(CurrentSpell:IsAvailable()) .. " | " .. 
								tostring(CurrentSpell:IsKnown()) .. " | " .. 
								tostring(IsTalentSpell(j, BOOKTYPE_SPELL)) .. " | " .. 
								tostring(GetSpellBookItemInfo(j, BOOKTYPE_SPELL)) .. " | " .. 
								tostring(GetSpellLevelLearned(CurrentSpell:ID()))
							);
							]]
							ER.PersistentCache.SpellLearned.Player[CurrentSpellID] = true;
						end
					end
				end
			end
			-- Flyout Spells
			local FlyoutID, NumSlots, IsKnown, IsKnownSpell;
			for i = 1, GetNumFlyouts() do
				FlyoutID = GetFlyoutID(i);
				NumSlots, IsKnown = select(3, GetFlyoutInfo(FlyoutID));
				if IsKnown and NumSlots > 0 then
					for j = 1, NumSlots do
						CurrentSpellID, _, IsKnownSpell = GetFlyoutSlotInfo(FlyoutID, j);
						if CurrentSpellID and IsKnownSpell then
							ER.PersistentCache.SpellLearned.Player[CurrentSpellID] = true;
						end
					end
				end
			end
		end

		-- Check if the spell is in the Spell Learned Cache.
		function Spell:IsLearned ()
			return ER.PersistentCache.SpellLearned[self:Type()][self:ID()] or false;
		end

		-- Check if the spell Is Castable or not.
		function Spell:IsCastable ()
			return self:IsLearned() and not self:IsOnCooldown();
		end

		--- Artifact Traits Scan
		-- Fills the PowerTable with every traits informations.
		local AUI, PowerTable = C_ArtifactUI, {};
		--- PowerTable Schema :
		--    1      2         3          4         5       6  7      8          9         10         11
		-- SpellID, Cost, CurrentRank, MaxRank, BonusRanks, x, y, PreReqsMet, IsStart, IsGoldMedal, IsFinal
		function Spell:ArtifactScan ()
			-- Prevent Scan if the Artifact Frame is opened.
			if _G.ArtifactFrame and _G.ArtifactFrame:IsShown() then return; end
			-- Does the scan only if the Artifact is Equipped.
			if HasArtifactEquipped() then
				-- Unregister the events to prevent unwanted call.
				UIParent:UnregisterEvent("ARTIFACT_UPDATE");
				SocketInventoryItem(INVSLOT_MAINHAND);
				local Powers = AUI.GetPowers();
				if Powers then
					PowerTable = {};
					for Index, Power in pairs(Powers) do
						tableinsert(PowerTable, {AUI.GetPowerInfo(Power)});
					end
				end
				AUI.Clear();
				-- Register back the event.
				UIParent:RegisterEvent("ARTIFACT_UPDATE");
			end
		end

	--- Simulationcraft Aliases
		-- action.foo.cast_time
		function Spell:CastTime ()
			if not self:InfoID(4) then 
				return 0;
			else
				return self:InfoID(4)/1000;
			end
		end

		-- action.foo.charges or cooldown.foo.charges
		function Spell:Charges ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if not ER.Cache.SpellInfo[self.SpellID].Charges then
				ER.Cache.SpellInfo[self.SpellID].Charges = {GetSpellCharges(self.SpellID)};
			end
			return unpack(ER.Cache.SpellInfo[self.SpellID].Charges);
		end

		-- action.foo.recharge_time or cooldown.foo.recharge_time
		function Spell:Recharge ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if not ER.Cache.SpellInfo[self.SpellID].Recharge then
				-- Get Spell Recharge Infos
				local Charges, MaxCharges, CDTime, CDValue = self:Charges();
				-- Return 0 if the Spell isn't in CD.
				if Charges == MaxCharges then
					return 0;
				end
				-- Compute the CD.
				local CD = CDTime + CDValue - ER.GetTime() - ER.RecoveryOffset();
				-- Return the Spell CD
				ER.Cache.SpellInfo[self.SpellID].Recharge = CD > 0 and CD or 0;
			end
			return ER.Cache.SpellInfo[self.SpellID].Recharge;
		end

		-- action.foo.charges_fractional or cooldown.foo.charges_fractional
		-- TODO : Changes function to avoid using the cache directly
		function Spell:ChargesFractional ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if not ER.Cache.SpellInfo[self.SpellID].ChargesFractional then
				self:Charges(); -- Cache the charges infos to use the cache directly after. 
				if ER.Cache.SpellInfo[self.SpellID].Charges[1] == ER.Cache.SpellInfo[self.SpellID].Charges[2] then
					ER.Cache.SpellInfo[self.SpellID].ChargesFractional = ER.Cache.SpellInfo[self.SpellID].Charges[1];
				else
					ER.Cache.SpellInfo[self.SpellID].ChargesFractional = ER.Cache.SpellInfo[self.SpellID].Charges[1] + (ER.Cache.SpellInfo[self.SpellID].Charges[4]-self:Recharge())/ER.Cache.SpellInfo[self.SpellID].Charges[4];
				end
			end
			return ER.Cache.SpellInfo[self.SpellID].ChargesFractional;
		end

		-- cooldown.foo.remains
		function Spell:Cooldown ()
			if not ER.Cache.SpellInfo[self.SpellID] then ER.Cache.SpellInfo[self.SpellID] = {}; end
			if not ER.Cache.SpellInfo[self.SpellID].Cooldown then
				-- Get Spell Cooldown Infos
				local CDTime, CDValue = GetSpellCooldown(self.SpellID);
				-- Return 0 if the Spell isn't in CD.
				if CDTime == 0 then
					return 0;
				end
				-- Compute the CD.
				local CD = CDTime + CDValue - ER.GetTime() - ER.RecoveryOffset();
				-- Return the Spell CD
				ER.Cache.SpellInfo[self.SpellID].Cooldown = CD > 0 and CD or 0;
			end
			return ER.Cache.SpellInfo[self.SpellID].Cooldown;
		end

		-- !cooldown.foo.up
		function Spell:IsOnCooldown ()
			return self:Cooldown() ~= 0;
		end

		-- artifact.foo.rank
		function Spell:ArtifactRank ()
			if #PowerTable > 0 then
				for Index, Table in pairs(PowerTable) do
					if self.SpellID == Table[1] and Table[3] > 0 then
						return Table[3];
					end
				end
			end
			return 0;
		end

		-- artifact.foo.enabled
		function Spell:ArtifactEnabled ()
			return self:ArtifactRank() > 0;
		end

--- ============== ITEM CLASS ==============

	-- Inventory slots
	-- INVSLOT_HEAD       = 1;
	-- INVSLOT_NECK       = 2;
	-- INVSLOT_SHOULDER   = 3;
	-- INVSLOT_BODY       = 4;
	-- INVSLOT_CHEST      = 5;
	-- INVSLOT_WAIST      = 6;
	-- INVSLOT_LEGS       = 7;
	-- INVSLOT_FEET       = 8;
	-- INVSLOT_WRIST      = 9;
	-- INVSLOT_HAND       = 10;
	-- INVSLOT_FINGER1    = 11;
	-- INVSLOT_FINGER2    = 12;
	-- INVSLOT_TRINKET1   = 13;
	-- INVSLOT_TRINKET2   = 14;
	-- INVSLOT_BACK       = 15;
	-- INVSLOT_MAINHAND   = 16;
	-- INVSLOT_OFFHAND    = 17;
	-- INVSLOT_RANGED     = 18;
	-- INVSLOT_TABARD     = 19;
	-- Check if a given item is currently equipped in the given slot.
	function Item:IsEquipped (Slot)
		if not ER.Cache.ItemInfo[self.ItemID] then ER.Cache.ItemInfo[self.ItemID] = {}; end
		if ER.Cache.ItemInfo[self.ItemID].IsEquipped == nil then
			ER.Cache.ItemInfo[self.ItemID].IsEquipped = Item and Item == self.ItemID and true or false;
		end
		return ER.Cache.ItemInfo[self.ItemID].IsEquipped;	
	end

	-- Get the item Last Cast Time.
	function Item:LastCastTime ()
		return self.LastCastTime;
	end

--- ============== MISC FUNCTIONS ==============

-- Get the Latency (it's updated every 30s).
-- TODO: Cache it in Persistent Cache and update it only when it changes
function ER.Latency ()
	return select(4, GetNetStats());
end

-- Retrieve the Recovery Timer based on Settings.
-- TODO: Optimize, to see how we'll implement it in the GUI.
function ER.RecoveryTimer ()
	return ER.GUISettings.General.RecoveryMode == "GCD" and Player:GCD()*1000 or ER.GUISettings.General.RecoveryTimer;
end

-- Compute the Recovery Offset with Lag Compensation.
function ER.RecoveryOffset ()
	return (ER.Latency() + ER.RecoveryTimer())/1000;
end

-- Get the time since combat has started.
function ER.CombatTime ()
	return ER.CombatStarted ~= 0 and ER.GetTime()-ER.CombatStarted or 0;
end

-- Get the time since combat has ended.
function ER.OutOfCombatTime ()
	return ER.CombatEnded ~= 0 and ER.GetTime()-ER.CombatEnded or 0;
end

-- Get the Boss Mod Pull Timer.
function ER.BMPullTime ()
	if not ER.BossModTime or ER.BossModTime == 0 or ER.BossModEndTime-ER.GetTime() < 0 then
		return 60;
	else
		return ER.BossModEndTime-ER.GetTime();
	end
end