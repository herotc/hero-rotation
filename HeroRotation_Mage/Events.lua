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
local Mage = HR.Commons.Mage;
local RangeIndex = HL.Enum.ItemRange.Hostile.RangeIndex;

-- Lua
local pairs = pairs;
local select = select;
local wipe = wipe;
local GetTime = HL.GetTime;

-- File Locals
do
  HL.RangeTracker = {
    AbilityTimeout = 1,
    NucleusAbilities = {
      [1449]  = {
        -- Arcane Explosion
        Range = 10,
        LastDamageTime = 0,
        LastDamaged = {},
        Timeout = 6
      },
      [44425] = {
        -- Arcane Barrage
        Range = 10,
        LastDamageTime = 0,
        LastDamaged = {},
        Timeout = 6
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

function Mage.UpdateSplashCount(UpdateUnit, SplashRange)
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
  if SplashRange == 10 then MinRange = 0 end

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

function Mage.GetSplashCount(UpdateUnit, SplashRange)
  if not UpdateUnit:Exists() then return 0 end

  local SplashableUnit = RT.SplashableCount[UpdateUnit:GUID()];
  if SplashableUnit and SplashableUnit[SplashRange] then
    return math.max(1, SplashableUnit[SplashRange])
  end

  return 1;
end

function Mage.ValidateSplashCache()
  for _, Ability in pairs(RT.NucleusAbilities) do
    if Ability.LastDamageTime+Ability.Timeout > GetTime() then return true; end
  end
  return false;
end


--- ============================ CONTENT ============================
--- ======= NON-COMBATLOG =======


--- ======= COMBATLOG =======
  --- Combat Log Arguments
    ------- Base -------
      --     1        2         3           4           5           6              7             8         9        10           11
      -- TimeStamp, Event, HideCaster, SourceGUID, SourceName, SourceFlags, SourceRaidFlags, DestGUID, DestName, DestFlags, DestRaidFlags

    ------- Prefixes -------
      --- SWING
      -- N/A

      --- SPELL & SPELL_PACIODIC
      --    12        13          14
      -- SpellID, SpellName, SpellSchool

    ------- Suffixes -------
      --- _CAST_START & _CAST_SUCCESS & _SUMMON & _RESURRECT
      -- N/A

      --- _CAST_FAILED
      --     15
      -- FailedType

      --- _AURA_APPLIED & _AURA_REMOVED & _AURA_REFRESH
      --    15
      -- AuraType

      --- _AURA_APPLIED_DOSE
      --    15       16
      -- AuraType, Charges

      --- _INTERRUPT
      --      15            16             17
      -- ExtraSpellID, ExtraSpellName, ExtraSchool

      --- _HEAL
      --   15         16         17        18
      -- Amount, Overhealing, Absorbed, Critical

      --- _DAMAGE
      --   15       16       17       18        19       20        21        22        23
      -- Amount, Overkill, School, Resisted, Blocked, Absorbed, Critical, Glancing, Crushing

      --- _MISSED
      --    15        16           17
      -- MissType, IsOffHand, AmountMissed

    ------- Special -------
      --- UNIT_DIED, UNIT_DESTROYED
      -- N/A

  --- End Combat Log Arguments

  -- Arguments Variables
  HL.RoPTime = 0

  --------------------------
  -------- Arcane ----------
  --------------------------

  HL:RegisterForSelfCombatEvent(
    function (...)
      dateEvent,_,_,_,_,_,_,DestGUID,_,_,_, SpellID = select(1,...);
      if SpellID == 116014 and Player:GUID() == DestGUID then --void RuneofPower
        HL.RoPTime = HL.GetTime()
      end

    end
    , "SPELL_AURA_APPLIED"
  );

  HL:RegisterForSelfCombatEvent(
    function (...)
      dateEvent,_,_,_,_,_,_,DestGUID,_,_,_, SpellID = select(1,...);
      if SpellID == 116014 and Player:GUID() == DestGUID then --void erruption
        HL.RoPTime = 0
      end
    end
    , "SPELL_AURA_REMOVED"
  );

  --------------------------
  -------- Frost -----------
  --------------------------

  local FrozenOrbFirstHit = true
  local FrozenOrbHitTime = 0

  HL:RegisterForSelfCombatEvent(function(...)
    local spellID = select(12, ...)
    if spellID == 84721 and FrozenOrbFirstHit then
      FrozenOrbFirstHit = false
      FrozenOrbHitTime = HL.GetTime()
      C_Timer.After(10, function()
        FrozenOrbFirstHit = true
        FrozenOrbHitTime = 0
      end)
    end
  end, "SPELL_DAMAGE")

  function Player:FrozenOrbGroundAoeRemains()
    return math.max(HL.OffsetRemains(FrozenOrbHitTime - (HL.GetTime() - 10), "Auto"), 0)
  end

  local brain_freeze_active = false

  HL:RegisterForSelfCombatEvent(function(...)
    local spellID = select(12, ...)
    if spellID == Spell.Mage.Frost.Flurry:ID() then
      brain_freeze_active =     Player:Buff(Spell.Mage.Frost.BrainFreezeBuff)
                            or  Spell.Mage.Frost.BrainFreezeBuff:TimeSinceLastRemovedOnPlayer() < 0.1
    end
  end, "SPELL_CAST_SUCCESS")

  function Player:BrainFreezeActive()
    if self:IsCasting(Spell.Mage.Frost.Flurry) then
      return false
    else
      return brain_freeze_active
    end
  end
