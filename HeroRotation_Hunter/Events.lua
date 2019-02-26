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
do
  local ChimaeraShot = {
    -- Chimaera Shot
    Range=8,
    LastDamageTime=0,
    LastDamaged={},
    Timeout=4
  }

  HL.RangeTracker = {
    AbilityTimeout = 1,
    NucleusAbilities = {
      [2643]   = {
        -- Multi-Shot (Beast Mastery)
        Range=8,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=4
      },
      [257620]   = {
        -- Multi-Shot (Marksmanship)
        Range=10,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=6
      },
      [194392] = {
        -- Volley
        Range=8,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=4
      },
      [171454] = ChimaeraShot,
      [171457] = ChimaeraShot,
      [118459] = {
        -- Beast Cleave
        Range=10,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=4
      },
      [201754] = {
        -- Stomp
        Range=10,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=4
      },
      [271686] = {
        -- Heed My Call
        Range=3,
        LastDamageTime=0,
        LastDamaged={},
        Timeout=4
      }
    },
    SplashableCount = {}
  }
end

local RT = HL.RangeTracker;

do
  local UpdateAbilityCache = function (...)
    local _,_,_,_,_,_,_,DestGUID,_,_,_,SpellID = ...;
    local Ability = RT.NucleusAbilities[SpellID];
    if Ability then
      if Ability.LastDamageTime+RT.AbilityTimeout < GetTime() then
        wipe(Ability.LastDamaged);
      end

      Ability.LastDamaged[DestGUID] = true;
      Ability.LastDamageTime = GetTime();
    end
  end

  HL:RegisterForSelfCombatEvent(UpdateAbilityCache, "SPELL_DAMAGE");
  HL:RegisterForPetCombatEvent(UpdateAbilityCache, "SPELL_DAMAGE");
end

HL:RegisterForEvent(
  function()
    local GUID = Target:GUID()
    for _, Ability in pairs(RT.NucleusAbilities) do
      if Ability.LastDamaged[GUID] then
        --If the new Target is already known we just retain the proximity map
      else
        --Otherwise we Reset
        wipe(Ability.LastDamaged);
        Ability.LastDamageTime = 0;
      end
    end
  end
, "PLAYER_TARGET_CHANGED");

HL:RegisterForCombatEvent(
  function (...)
    local DestGUID = select(8, ...);
    for _, Ability in pairs(RT.NucleusAbilities) do
      Ability.LastDamaged[DestGUID] = nil;
    end
  end
, "UNIT_DIED", "UNIT_DESTROYED");

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

local function RecentlyDamagedIn(GUID, SplashRange)
  local ValidAbility = false
  for _, Ability in pairs(RT.NucleusAbilities) do
    --The Ability needs to have splash radius thats smaller or equal to over
    if SplashRange >= Ability.Range then
      ValidAbility = true
      if Ability.LastDamageTime+Ability.Timeout > GetTime() then
        if Ability.LastDamaged[GUID] and Ability.LastDamaged then return true end
      end
    end
  end
  --If we didnt find a valid ability we return true
  return not ValidAbility;
end

function Hunter.UpdateSplashCount(UpdateUnit, SplashRange)
  if not UpdateUnit:Exists() then return end

  -- Purge abilities that don't contain our current target
  -- Mostly for cases where our pet AoE damaged enemies after we target swapped
  local TargetGUID = Target:GUID()
  for _, Ability in pairs(RT.NucleusAbilities) do
    if not Ability.LastDamaged[TargetGUID] then
      wipe(Ability.LastDamaged);
      Ability.LastDamageTime = 0;
    end
  end

  local Distance = NumericRange(UpdateUnit:MaxDistanceToPlayer());
  local MaxRange = EffectiveRangeSanitizer(Distance+SplashRange);
  local MinRange = EffectiveRangeSanitizer(Distance-SplashRange);

  --Prevent calling Get Enemies twice
  if not Cache.EnemiesCount[MaxRange] then
    HL.GetEnemies(MaxRange);
  end

  -- Use the Enemies Cache as the starting point
  local Enemies = Cache.Enemies[MaxRange]
  local CurrentCount = 0
  for _, Enemy in pairs(Enemies) do
    --Units that are outside of the parameters or havent been seen lately get removed
    if NumericRange(Enemy:MaxDistanceToPlayer()) > MinRange
    and NumericRange(Enemy:MinDistanceToPlayer()) < MaxRange
    and RecentlyDamagedIn(Enemy:GUID(), SplashRange) then
      CurrentCount = CurrentCount + 1
    end
  end

  if not RT.SplashableCount[UpdateUnit:GUID()] then
    RT.SplashableCount[UpdateUnit:GUID()] = {}
  end
  RT.SplashableCount[UpdateUnit:GUID()][SplashRange] = CurrentCount
end

function Hunter.GetSplashCount(UpdateUnit, SplashRange)
  if not UpdateUnit:Exists() then return 0 end

  local SplashableUnit = RT.SplashableCount[UpdateUnit:GUID()];
  if SplashableUnit and SplashableUnit[SplashRange] then
    return math.max(1, SplashableUnit[SplashRange])
  end

  return 1;
end

function Hunter.ValidateSplashCache()
  for _, Ability in pairs(RT.NucleusAbilities) do
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
