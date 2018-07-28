--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...;
-- HeroLib
local HL = HeroLib;
local Cache = HeroCache;
local HR = HeroRotation;
local Unit = HL.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = HL.Spell;
local Item = HL.Item;
local Hunter = HR.Commons.Hunter;
local RangeIndex = HL.Enum.ItemRange.Hostile.RangeIndex
local TriggerGCD = HL.Enum.TriggerGCD;
-- Lua
local pairs = pairs;
local select = select;
local wipe = wipe;
local GetTime = HL.GetTime;

-- File Locals

HL.RangeTracker = {
	AbilityTimeout = 1,
	NucleusAbilities = {
		[2643]   = {
			Range=8, 
			--Spell = Spell.Hunter.Marksmanship and Spell.Hunter.Marksmanship.MultiShot or Spell.Hunter.BeastMastery.Multishot, 
			LastDamageTime=0,
			LastDamaged={},
			Timeout=4
		},
		[194392] = {
			Range=8, 
			--Spell = Spell.Hunter.Marksmanship and Spell.Hunter.Marksmanship.Volley or Spell.Hunter.BeastMastery.Volley, 
			LastDamageTime=0,
			LastDamaged={},
			Timeout=4
		}
	},
	NonSplashableCount = {}
}

local RT = HL.RangeTracker;

HL:RegisterForSelfCombatEvent(
function (...)
  _,_,_,SourceGUID,_,_,_,DestGUID,_,_,_,SpellID = ...;
  
  local Ability = RT.NucleusAbilities[SpellID];
  
  if Ability then
		
    if Ability.LastDamageTime+RT.AbilityTimeout < GetTime() then
      wipe(Ability.LastDamaged);
    end
		
    Ability.LastDamaged[DestGUID] = true;
    Ability.LastDamageTime = GetTime();
  end	
  
end 	
, "SPELL_DAMAGE"
);  

HL:RegisterForEvent(
function(...)
  local GUID = Target:GUID()
  
  for SpellID, Ability in pairs(RT.NucleusAbilities) do
    if Ability.LastDamaged[GUID] then
      --If the new Target is already known we just retain the proximity map
    else
      --Otherwise we Reset
      wipe(Ability.LastDamaged);
      Ability.LastDamageTime = 0;
    end
  end	  
  
end
, "PLAYER_TARGET_CHANGED"
)

HL:RegisterForCombatEvent(
function (...)
  DestGUID = select(8, ...);
  for SpellID, Ability in pairs(RT.NucleusAbilities) do
    Ability.LastDamaged[DestGUID] = nil;
  end		 
end
, "UNIT_DIED"
, "UNIT_DESTROYED"
); 




local function NumericRange(range)
  return range == "Melee" and 5 or range;
end   

local function EffectiveRangeSanitizer(EffectiveRange)
  --The Enemies Cache only works for specific Ranges
  
  for i=2,#RangeIndex do
    if RangeIndex[i] >= EffectiveRange then			
      return RangeIndex[i]
    end
  end
  return -1
end

local function RecentlyDamagedIn(GUID,SplashRange)
  local ValidAbility = false
  for SpellID, Ability in pairs(RT.NucleusAbilities) do
    --The Ability needs to have splash radius thats smaller or equal to over
    if SplashRange >= Ability.Range and Ability.LastDamageTime+Ability.Timeout > GetTime() then
      ValidAbility = true
      if Ability.LastDamaged[GUID] then return true end
    end
    
  end  
  --If we didnt find a valid ability we return true
  return not ValidAbility;
end

function Hunter.UpdateSplashCount(Unit, SplashRange)
  
  if not Unit:Exists() then return end
  
  local Distance = NumericRange(Unit:MaxDistanceToPlayer());
  
  local MaxRange = EffectiveRangeSanitizer(Distance+SplashRange);
  local MinRange = EffectiveRangeSanitizer(Distance-SplashRange);
  
  --Prevent calling Get Enemies twice
  if not Cache.EnemiesCount[MaxRange] then
    HL.GetEnemies(MaxRange);
  end
  
  local CurrentCount = 0
  local Enemies = Cache.Enemies[MaxRange]
  
  for i, Enemy in pairs(Enemies) do
    --Units that are outside of the parameters or havent been seen lately get removed			
    if NumericRange(Enemy:MaxDistanceToPlayer()) < MinRange or NumericRange(Enemy:MinDistanceToPlayer()) > MaxRange or not RecentlyDamagedIn(Enemy:GUID(),SplashRange) then
      CurrentCount = CurrentCount+1
    end
  end
	
  RT.NonSplashableCount[MaxRange] = CurrentCount
  
end

function Hunter.GetSplashCount(Unit,SplashRange)
  
  local Distance = NumericRange(Unit:MaxDistanceToPlayer())
  
  local EffectiveRange = EffectiveRangeSanitizer(Distance+SplashRange)
  
  local CacheCount = Cache.EnemiesCount[EffectiveRange]
  
  
  --We subtract all the impossible units 
  local Count = math.max(CacheCount and (CacheCount-RT.NonSplashableCount[EffectiveRange]) or 1,1)
  
  --print(Count,Hunter.ValidateSplashCache())
  
  return Count
end

function Hunter.ValidateSplashCache()
  for SpellID, Ability in pairs(RT.NucleusAbilities) do
    if Ability.LastDamageTime+Ability.Timeout > GetTime() then return true; end
  end			
  
  return false;
end 

-- MM Hunter GCD Management

Player.MMHunter = {
  GCDDisable = 0;
}
HL:RegisterForSelfCombatEvent(
  function (...)
    local CastSpell = Spell(select(12, ...))
    if CastSpell:CastTime() == 0 and TriggerGCD[CastSpell:ID()] then
      Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable + 1;
      --print("GCDDisable: " .. tostring(GCDDisable))
      C_Timer.After(0.1, 
      function ()
        Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable - 1;
        --print("GCDDisable: " .. tostring(GCDDisable))
      end
      );
    end
  end
  , "SPELL_CAST_SUCCESS"
);
HL:RegisterForSelfCombatEvent(
  function (...)
    local CastSpell = Spell(select(12, ...))
    if CastSpell:CastTime() > 0 and TriggerGCD[CastSpell:ID()] then
      Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable + 1;
      --print("GCDDisable: " .. tostring(GCDDisable))
      C_Timer.After(0.1, 
      function ()
        Player.MMHunter.GCDDisable = Player.MMHunter.GCDDisable - 1;
        --print("GCDDisable: " .. tostring(GCDDisable))
      end
      );
    end
  end
  , "SPELL_CAST_START"
);  
