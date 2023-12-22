--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Pet        = Unit.Pet
local Target     = Unit.Target
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local AoEON      = HR.AoEON
local CDsON      = HR.CDsON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- Lua
local mathmin    = math.min

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Restoration
local I = Item.Shaman.Restoration

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}


-- GUI Settings
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Elemental = HR.GUISettings.APL.Shaman.Restoration
}


HL:RegisterForEvent(function()
  S.LavaBurst:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.LavaBurst:RegisterInFlight()

-- These variables are rotational modifiers parameters.
local NumEnemiesInCombat
local NumEnemiesInLargestCluster
local ActiveFlameshocks
local RefreshableFlameshocks
local FightTimeRemaining
local CoreUnitInLargestCluster
local BestFlameshockUnit
local SplashedEnemiesTable

-- We keep track of total enemies in combat, as well as a bunch of parameters around the encounter.
-- We also care about the state of our friendly units in the raid!
local function BattlefieldSnapshot()
  -- Parameters for damage automation
  NumEnemiesInCombat = 0
  NumEnemiesInLargestCluster = 0
  ActiveFlameshocks = 0
  RefreshableFlameshocks = 0
  FightTimeRemaining = 0
  SplashedEnemiesTable = {}
  CoreUnitInLargestCluster = nil
  BestFlameshockUnit = nil
  -- Parameters for healing automation 
  InjuredFriends = 0
  LowestHealthFriendPercentage = 1.0


  local min_flameshock_duration = 999
  local max_hp = 0
  if AoEON() then
    for _, Enemy in pairs(Player:GetEnemiesInRange(40)) do
      -- NOTE: the IsDummy() check will assume that you ARE IN COMBAT with all dummies on screen, so zoom in camera to "work around" for testing.
      if Enemy:AffectingCombat() or Enemy:IsDummy() then
        -- Update enemies-in-combat count.
        NumEnemiesInCombat = NumEnemiesInCombat + 1

        -- Update flameshock data on your targets. 
        -- Select as "best flameshock unit" the enemy with minimum fs duration remaining, breaking ties by highest remaining health.
        local fs_duration = Enemy:DebuffRemains(S.FlameShockDebuff)
        if fs_duration > 0 then
          ActiveFlameshocks = ActiveFlameshocks + 1
        end
        if fs_duration < 5 then
          RefreshableFlameshocks = RefreshableFlameshocks + 1
        end
        if fs_duration < min_flameshock_duration then
          min_flameshock_duration = fs_duration
          BestFlameshockUnit = Enemy
        end
        if fs_duration == 0 and Enemy:Health() > max_hp then
          max_hp = Enemy:Health()
          BestFlameshockUnit = Enemy
        end

        -- Update splashed enemy data. This actually assigns to each unit a GROUP of splashed units, called a splash_cluster.
        -- We can use this to choose when to chain lightning; specifically, we want to CL when any one of these
        -- groups has two or more units in it.
        -- TODO: sometimes we don't want to CL because the second or third targets are immune or irrelevant, for example third boss halls adds
        -- double TODO: figure out the spell value of CL's maelstrom gen versus CL's maelstrom gen + damage (squad leader pulls in spires?)
        -- We can't currently figure out which target is the "center" of the group.
        -- BUG: If you just call Enemy:GetEnemiesInSplashRange(), chain lightning and earthquake seem to double count?!
        -- We do a stupid O(N^2) deduplication. This is probably dumb but works okay for small N.
        local potentially_duplicated_splashes = Enemy:GetEnemiesInSplashRange(10)
        local splash_cluster = {}
        for _, potential_dupe in pairs(potentially_duplicated_splashes) do
          local dupe_found = false
          for _, unique_guy in pairs(splash_cluster) do
            if potential_dupe:GUID() == unique_guy:GUID() then
              dupe_found = true
              break
            end
          end
          if not dupe_found then table.insert(splash_cluster, potential_dupe) end
        end
        SplashedEnemiesTable[Enemy] = splash_cluster
        if #splash_cluster > NumEnemiesInLargestCluster then
          NumEnemiesInLargestCluster = #splash_cluster
          CoreUnitInLargestCluster = Enemy
        end

        -- Update FightTimeRemaining
        if not Enemy:TimeToDieIsNotValid() and not Enemy:IsUserCycleBlacklisted() then
          FightTimeRemaining = math.max(FightTimeRemaining, Enemy:TimeToDie())
        end
      end
    end
  else
    -- AoEON is disabled, so only care about the primary target
    NumEnemiesInCombat = 1

    -- Update flameshock data
    local fs_duration = Target:DebuffRemains(S.FlameShockDebuff)
    if fs_duration > 0 then
      ActiveFlameshocks = 1
    end
    if fs_duration < 5 then
      RefreshableFlameshocks = 1
    end
    BestFlameshockUnit = Target

    -- Update "splash data"
    NumEnemiesInLargestCluster = 1
    CoreUnitInLargestCluster = Target

    -- Update FightTimeRemaining
    if not Target:TimeToDieIsNotValid() and not Target:IsUserCycleBlacklisted() then
      FightTimeRemaining = Target:TimeToDie()
    end
  end
end

-- Some spells aren't castable while moving or if you're currently casting them, so we handle that behavior here.
-- Additionally, lavaburst isn't castable without a charge or a proc.
local function IsViable(spell)
  if spell == nil then
    return nil
  end
  local BaseCheck = spell:IsCastable() and spell:IsReady()
  local MovementPredicate = (Player:BuffUp(S.SpiritwalkersGraceBuff) or not Player:IsMoving())
  if spell == S.LightningBolt or 
     spell == S.ChainLightning or 
     spell == S.HealingRain or
     spell == S.HealingWave or 
     spell == S.HealingSurge or 
     spell == S.Wellspring then
    return BaseCheck and MovementPredicate
  elseif spell == S.LavaBurst then
    local a = Player:BuffUp(S.LavaSurgeBuff)
    local b = (not Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() >= 1)
    local c = (Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() == 2)
    return BaseCheck and (MovementPredicate or Player:BuffUp(S.LavaSurgeBuff)) and (a or b or c)
  else
    return BaseCheck
  end
end


local function Precombat()
  if IsViable(S.Fleshcraft) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "Precombat Fleshcraft" end
  end
  if NumEnemiesInLargestCluster >= 3 and IsViable(S.ChainLightning) and not Player:IsCasting(S.ChainLightning) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "Precombat Chain Lightning" end
  end
  if IsViable(S.LavaBurst) and not Player:IsCasting(S.LavaBurst) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "Precombat Lavaburst" end
  end
  if Player:IsCasting(S.LavaBurst) and S.FlameShock:CooldownRemains() == 0 then 
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "Precombat Flameshock" end
  end
end

local function Cooldowns()
  local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Trinket CD" end
  end
  if Player:IsMoving() and S.SpiritwalkersGrace:IsCastable() then
    if Cast(S.SpiritwalkersGrace, nil, Settings.Commons.DisplayStyle.SpiritwalkersGrace) then return "Suggest SWG" end
  end
  if IsViable(S.ChainHarvest) then
    if Cast(S.ChainHarvest, nil, Settings.Commons.DisplayStyle.Covenant) then return "Chain Harvest CD" end
  end
  if IsViable(S.FaeTransfusion) then
    if Cast(S.FaeTransfusion, nil, Settings.Commons.DisplayStyle.Covenant) then return "Fae Transfusion CD" end
  end
  if IsViable(S.VesperTotem) then
    if Cast(S.VesperTotem, nil, Settings.Commons.DisplayStyle.Covenant) then return "Vesper Totem CD" end
  end
end

local function NumFlameShocksToMaintain()
  -- On AOE, don't maintain flame shock.
  if NumEnemiesInLargestCluster >= 3 then return 0 end
  -- On ST or 2T, return 1 or 2.
  return NumEnemiesInLargestCluster
end

local function ApplyFlameShock()
  if S.FlameShock:CooldownRemains() > 0 or BestFlameshockUnit == nil then return nil end
  if BestFlameshockUnit:GUID() == Target:GUID() then
    if Cast(S.FlameShock, nil, nil, not Target:IsInRange(40)) then return "main-target flameshock"; end
  else
    if HR.CastLeftNameplate(BestFlameshockUnit, S.FlameShock) then return "off-target flameshock"; end
  end
  return nil
end

local function SingleTargetAndSpreadCleaveBuilder()
  if IsViable(S.LavaBurst) then
    return S.LavaBurst, false
  elseif IsViable(S.LightningBolt) then
    return S.LightningBolt, true
  end
  -- End up here when there are no castable builders for a st/spread cleave situation (on the move, no LB charges)
  return nil, false
end

local function AOEBuilder()
  if IsViable(S.ChainLightning) then
    return S.ChainLightning, true
  elseif IsViable(S.LavaBurst) then 
    return S.LavaBurst, true
  end
  -- End up here when there are no castable builders for a stacked cleave situation (on the move, no LB charges)
  return nil, false
end

local function CoreRotation()
  local DebugMessage

  -- Keep minimum number of flameshocks up
  if ActiveFlameshocks < NumFlameShocksToMaintain() then
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return DebugMessage end;
  end

  local builder, prefer_fs_refresh = nil, false
  if NumEnemiesInLargestCluster < 3 then 
    builder, prefer_fs_refresh = SingleTargetAndSpreadCleaveBuilder() 
  else
    builder, prefer_fs_refresh = AOEBuilder() 
  end

  -- Refresh flameshocks when the builder is low priority.
  if prefer_fs_refresh and RefreshableFlameshocks > 0 and ActiveFlameshocks <= NumFlameShocksToMaintain() then
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return DebugMessage end;
  end
  
  -- If you have a non-nil + viable builder, then you should cast it!
  if builder ~= nil and IsViable(builder) then
    if Cast(builder) then return "Building Maelstrom with optimal Builder (AOE)" end
  end
  if builder == nil then
    -- Try to refresh flameshocks
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return "Refreshing Flame Shock because we cannot build or spend" end
    if Cast(S.FrostShock) then return "Casting Frost Shock because we cannot build or spend or refresh flame shock" end
  end

  return nil
end

--- ======= MAIN =======
local function APL()
  -- Generalized Data Updates (per frame)
  BattlefieldSnapshot()

  local DebugMessage
  if Everyone.TargetIsValid() then
    if not Player:AffectingCombat() then
      DebugMessage = Precombat();
      if DebugMessage then return DebugMessage end;
    end
    Everyone.Interrupt(S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false);

    DebugMessage = Cooldowns()
    if DebugMessage then return DebugMessage end;

    DebugMessage = CoreRotation()
    if DebugMessage then return DebugMessage end;

    -- This is actually an "error" state, we should always be able to frost shock.
    HR.CastAnnotated(S.FrostShock, false, "ERR");
  end
end

local function Init()
  HR.Print("Restoration Shaman rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(264, APL, Init)
