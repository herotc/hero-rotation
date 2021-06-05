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
-- Lua


--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Elemental
local I = Item.Shaman.Elemental

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}


-- TODOS
-- Aim lavashocks at currently flameshock'd targets
-- Do better flameshock target selection - don't flameshock things that are going to die in less than the flameshock cooldown or so.
-- Revisit icefury priority (it feels like it's gonna dump charges all the time). In fact, all of our icefury stuff feels really bad.
-- Make sure to consume Sk stack if it is about to fall
-- Chain lightning at best target in center of cluster. This isn't hard, but not sure it's worth doing.
-- TODO stuff: handle pvp talents

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Elemental = HR.GUISettings.APL.Shaman.Elemental
}

local DeeptremorStoneEquipped = Player:HasLegendaryEquipped(131)
local SkybreakersEquipped = Player:HasLegendaryEquipped(134)
local ElementalEquilibriumEquipped = Player:HasLegendaryEquipped(135)
local EchoesofGreatSunderingEquipped = Player:HasLegendaryEquipped(136)
local CallOfFlameEquipped = S.CallOfFlame:ConduitEnabled()

HL:RegisterForEvent(function()
  DeeptremorStoneEquipped = Player:HasLegendaryEquipped(131)
  SkybreakersEquipped = Player:HasLegendaryEquipped(134)
  ElementalEquilibriumEquipped = Player:HasLegendaryEquipped(135)
  EchoesofGreatSunderingEquipped = Player:HasLegendaryEquipped(136)
  CallOfFlameEquipped = S.CallOfFlame:ConduitEnabled()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.PrimordialWave:RegisterInFlightEffect(327162)
  S.PrimordialWave:RegisterInFlight()
  S.LavaBurst:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.PrimordialWave:RegisterInFlightEffect(327162)
S.PrimordialWave:RegisterInFlight()
S.LavaBurst:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

-- These variables are rotational modifiers parameters.
local NumEnemiesInCombat
local NumEnemiesInLargestCluster
local ActiveFlameshocks
local RefreshableFlameshocks
local FightTimeRemaining
local CoreUnitInLargestCluster
local BestFlameshockUnit
local SplashedEnemiesTable
local StormElementalRemains
local FireElementalRemains

-- We keep track of total enemies in combat, as well as a bunch of parameters around the encounter.
local function BattlefieldSnapshot()
  NumEnemiesInCombat = 0
  NumEnemiesInLargestCluster = 0
  ActiveFlameshocks = 0
  RefreshableFlameshocks = 0
  FightTimeRemaining = 0
  SplashedEnemiesTable = {}
  CoreUnitInLargestCluster = nil
  BestFlameshockUnit = nil

  local min_flameshock_duration = 999
  local max_hp = 0
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
end

-- Keep track of pet data stuff.
local function PetUpdates()
  local call_of_flame_effect = 0.0
  StormElementalRemains = 0
  FireElementalRemains = 0
  if S.CallOfFlame:ConduitEnabled() then call_of_flame_effect = 0.35 + 0.01*(S.CallOfFlame:ConduitRank() - 1) end
  local elemental_duration = 30*(1.0 + call_of_flame_effect)
  -- TODO: if you earth ele during storm ele or fire ele, we don't correctly get these set right.
  -- the right thing to do is probably also have a S.EarthElemental:TimeSinceLastCast() check somewhere in these conditions.
  if S.StormElemental:IsAvailable() and S.StormElemental:TimeSinceLastCast() < elemental_duration then
    StormElementalRemains = elemental_duration - S.StormElemental:TimeSinceLastCast()
  end
  if not S.StormElemental:IsAvailable() and S.FireElemental:TimeSinceLastCast() < elemental_duration then
    FireElementalRemains = elemental_duration - S.FireElemental:TimeSinceLastCast()
  end
end

-- Some spells aren't castable while moving or if you're currently casting them, so we handle that behavior here.
-- Additionally, lavaburst isn't castable without a charge or a proc.
local function IsViable(spell)
  if spell == nil then
    return nil
  end
  local BaseCheck = spell:IsCastable() and spell:IsReady()
  if spell == S.Stormkeeper or spell == S.ElementalBlast or spell == S.Icefury then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.SpiritwalkersGraceBuff))
    return BaseCheck and MovementPredicate and not Player:IsCasting(spell)
  elseif spell == S.LightningBolt or spell == S.ChainLightning then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.StormkeeperBuff) or Player:BuffUp(S.SpiritwalkersGraceBuff))
    return BaseCheck and MovementPredicate
  elseif spell == S.LavaBurst then
    local MovementPredicate = (not Player:IsMoving() or Player:BuffUp(S.LavaSurgeBuff) or Player:BuffUp(S.SpiritwalkersGraceBuff))
    local a = Player:BuffUp(S.LavaSurgeBuff)
    local b = (not Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() >= 1)
    local c = (Player:IsCasting(S.LavaBurst) and S.LavaBurst:Charges() == 2)
    -- d) TODO: you are casting something else, but you will have >= 1 charge at the end of the cast of the spell
    --    Implementing d) will require something like LavaBurstChargesFractionalP(); this is not hard but I haven't done it.
    return BaseCheck and MovementPredicate and (a or b or c)
  else
    return BaseCheck
  end
end

-- Compute how much maelstrom you are guaranteed to have when you finish your current cast, assuming you are casting. 
local function MaelstromP()
  local Maelstrom = UnitPower("player", Enum.PowerType.Maelstrom)
  if not Player:IsCasting() then
    return Maelstrom
  else
    if Player:IsCasting(S.ElementalBlast) then
      return Maelstrom + 30
    elseif Player:IsCasting(S.Icefury) then
      return Maelstrom + 25
    elseif Player:IsCasting(S.LightningBolt) then
      return Maelstrom + 8
    elseif Player:IsCasting(S.LavaBurst) then
      return Maelstrom + 10*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
    elseif Player:IsCasting(S.ChainLightning) then
      --TODO: figure out the *actual* maelstrom you'll get from hitting your current target...
      --return Maelstrom + (4 * #SplashedEnemiesTable[Target])
      -- If you're hitting the best target with CL , this is 4*NumEnemiesInLargestCluster
      return Maelstrom + (4 * NumEnemiesInLargestCluster)
    else
      return Maelstrom
    end
  end
end

-- Handle what your MOTE buff status will be post-cast (i.e. does your cast consume the buff? does it generate a new one?)
local function MasterOfTheElementsP()
  if not S.MasterOfTheElements:IsAvailable() then return false end
  local MOTEUp = Player:BuffUp(S.MasterOfTheElementsBuff)
  if not Player:IsCasting() then
    return MOTEUp
  else
    if Player:IsCasting(S.LavaBurst) then
      return true
    elseif Player:IsCasting(S.ElementalBlast) then 
      return false
    elseif Player:IsCasting(S.Icefury) then
      return false
    elseif Player:IsCasting(S.LightningBolt) then
      return false
    elseif Player:IsCasting(S.ChainLightning) then
      return false
    else
      return MOTEUp
    end
  end
end

-- Handle what your Stormkeeper buff status will be post-cast.
local function StormkeeperBuffP()
  if not S.Stormkeeper:IsAvailable() then return false end
  local StormkeeperUp = Player:BuffUp(S.StormkeeperBuff)
  if not Player:IsCasting() then
    return StormkeeperUp
  else
    if Player:IsCasting(S.Stormkeeper) then
      return true
    else
      return StormkeeperUp
    end
  end
end

-- Handle what your Icefury buff status will be post-cast.
-- TODO(mrdmnd) - icefury still not handled very well.
local function IcefuryBuffP()
  if not S.Icefury:IsAvailable() then return false end
  local IcefuryUp = Player:BuffUp(S.IcefuryBuff)
  if not Player:IsCasting() then
    return IcefuryUp
  else
    if Player:IsCasting(S.Icefury) then
      return true
    else
      return IcefuryUp
    end
  end
end

local function SelectSpender()
  if Player:BuffUp(S.EchoesofGreatSunderingBuff) then
    return S.Earthquake
  elseif EchoesofGreatSunderingEquipped and not Player:BuffUp(S.EchoesofGreatSunderingBuff) then
    return S.EarthShock
  elseif NumEnemiesInLargestCluster > 1 then
    return S.Earthquake
  else
    return S.EarthShock
  end
end

local function Precombat()
  if IsViable(S.Fleshcraft) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "Precombat Fleshcraft" end
  end
  if IsViable(S.Stormkeeper) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "Precombat Stormkeeper" end
  end
  if IsViable(S.ElementalBlast) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "Precombat Elemental Blast" end
  end
  if Player:IsCasting(S.ElementalBlast) and IsViable(S.PrimordialWave) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.PrimordialWave)) then return "Precombat Primwave" end
  end
  if Player:IsCasting(S.ElementalBlast) and not IsViable(S.PrimordialWave) and S.FlameShock:CooldownRemains() == 0 then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "Precombat Flameshock" end
  end
  if IsViable(S.LavaBurst) and not Player:IsCasting(S.LavaBurst) and (not S.ElementalBlast:IsAvailable() or (S.ElementalBlast:IsAvailable() and not IsViable(S.ElementalBlast))) then
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
  if IsViable(S.Stormkeeper) then
    if Cast(S.Stormkeeper, Settings.Elemental.GCDasOffGCD.Stormkeeper) then return "Stormkeeper CD" end
  end
  if IsViable(S.EchoingShock) then
    if Cast(S.EchoingShock, Settings.Elemental.GCDasOffGCD.EchoingShock) then return "Echoing Shock CD" end
  end
  if IsViable(S.LiquidMagmaTotem) then
    if Cast(S.LiquidMagmaTotem, Settings.Elemental.GCDasOffGCD.LiquidMagmaTotem) then return "Liquid Magma Totem CD" end
  end
  if IsViable(S.FireElemental) then
    if Cast(S.FireElemental, Settings.Elemental.GCDasOffGCD.FireElemental) then return "Fire Elemental CD" end
  end
  if IsViable(S.StormElemental) then
    if Cast(S.StormElemental, Settings.Elemental.GCDasOffGCD.StormElemental) then return "Storm Elemental CD" end
  end
  if FireElementalRemains > 0 and S.PrimalElementalist:IsAvailable() and S.Meteor:CooldownRemains() == 0 then
    if Cast(S.Meteor, nil, Settings.Elemental.DisplayStyle.Meteor) then return "Meteor CD" end
  end
  if StormElementalRemains > 0 and S.PrimalElementalist:IsAvailable() and Pet:BuffUp(S.CallLightningBuff) and not Pet:IsChanneling(S.EyeOfTheStorm) and S.EyeOfTheStorm:CooldownRemains() == 0 then
    if Cast(S.EyeOfTheStorm, nil, Settings.Elemental.DisplayStyle.EyeOfTheStorm) then return "Eye of the Storm CD" end
  end
end

local function NumFlameShocksToMaintain()
  if SkybreakersEquipped then return math.min(4, NumEnemiesInCombat) end -- Skybreakers (always be flame shockin')
  if NumEnemiesInLargestCluster == 1 then return math.min(3, NumEnemiesInCombat) end -- Single Target, Spread Cleave (maintain one FS)
  if (NumEnemiesInCombat == 2 or NumEnemiesInCombat == 3) and (NumEnemiesInLargestCluster == 2 or NumEnemiesInLargestCluster == 3) then return math.min(3, NumEnemiesInCombat) end -- Stacked Cleave
  if NumEnemiesInLargestCluster >= 4 then return 1 end -- AOE
  return 1 -- fallthrough when no combat?
end

local function ApplyFlameShock()
  local SpellObject = nil;
  if IsViable(S.PrimordialWave) then
    SpellObject = S.PrimordialWave
  elseif S.FlameShock:CooldownRemains() == 0 then
    SpellObject = S.FlameShock
  end
  if SpellObject == nil or BestFlameshockUnit == nil then return nil end
  if BestFlameshockUnit:GUID() == Target:GUID() then
    if Cast(SpellObject, nil, nil, not Target:IsInRange(40)) then return "main-target " .. SpellObject.SpellName; end
  else
    if HR.CastLeftNameplate(BestFlameshockUnit, SpellObject) then return "off-target " .. SpellObject.SpellName; end
  end
  return nil
end

local function MoteEmpowerment()
  local n = math.min(NumEnemiesInLargestCluster, 20)
  if Player:BuffUp(S.EchoesofGreatSunderingBuff) and MaelstromP() >= 60 then
    if Cast(S.Earthquake) then return "MOTE EOGS" end
  end 
  local spender = SelectSpender()
  -- Special case handling
  if n >= 4 and MaelstromP() >= 90 then
    if Cast(spender) then return "Spending Maelstrom despite MOTE because Builder will overcap (AOE)" end
  end

  if n >= 8 and MaelstromP() >= 60 and spender == S.Earthquake then
    if Cast(S.Earthquake) then return "MOTE 8t+ EQ" end
  elseif n >= 5 and StormkeeperBuffP() then
    if Cast(S.ChainLightning) then return "MOTE 5t+ SK CL" end
  elseif n >= 5 and MaelstromP() >= 60 and spender == S.Earthquake then
    if Cast(S.Earthquake) then return "MOTE 5-7t EQ" end
  elseif n >= 4 and StormkeeperBuffP() then
    if Cast(S.ChainLightning) then return "MOTE 4t SK CL" end
  elseif n >= 3 and MaelstromP() >= 60 and spender == S.Earthquake then
    if Cast(S.Earthquake) then return "MOTE 3-4t EQ" end
  elseif n >= 3 and StormkeeperBuffP() then
    if Cast(S.ChainLightning) then return "MOTE 3t SK CL" end
  elseif n >= 2 and MaelstromP() >= 60 and spender == S.Earthquake then
    if Cast(S.Earthquake) then return "MOTE 2t EQ" end
  elseif n >= 5 then
    if Cast(S.ChainLightning) then return "MOTE 5t CL" end
  elseif n >= 1 and StormkeeperBuffP() then
    if Cast(S.LightningBolt) then return "MOTE 1t SK LB" end
  elseif n >= 2 and StormkeeperBuffP() then
    if Cast(S.ChainLightning) then return "MOTE 2t SK CL" end
  elseif n >= 4 then
    if Cast(S.ChainLightning) then return "MOTE 4t CL" end
  elseif n >= 1 and MaelstromP() >= 60 and spender == S.EarthShock then
    if Cast(S.EarthShock) then return "MOTE ES" end
  elseif n >= 3 then
    if Cast(S.ChainLightning) then return "MOTE 3t CL" end
  elseif IcefuryBuffP() then
    if Cast(S.FrostShock) then return "MOTE Frost Shock" end
  elseif IsViable(S.ElementalBlast) then
    if Cast(S.ElementalBlast) then return "MOTE EleBlast" end
  elseif IsViable(S.Icefury) then
    if Cast(S.Icefury) then return "MOTE Icefury" end
  elseif RefreshableFlameshocks > 0 then
    local DebugMessage = ApplyFlameShock()
    if DebugMessage then return "Even with MOTE up, correct move is probably to refresh flameshocks." end;
  elseif n >= 2 then
    if Cast(S.ChainLightning) then return "MOTE 2t CL" end
  elseif IsViable(S.LightningBolt) then
    if Cast(S.LightningBolt) then return "MOTE LB" end
  end

  return nil
end

local function SingleTargetAndSpreadCleaveBuilder()
  local lavaburst_ms_lb = 10*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  local lavaburst_ms_ub = 14*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  
  -- In this top case, we set lavaburst_ms_ub = 8 because we don't actually care that much about overcapping MS to MOTE empower a spender.
  if MaelstromP() + lavaburst_ms_lb >= 60 and Player:BuffUp(S.LavaSurgeBuff) and S.MasterOfTheElements:IsAvailable() and not MasterOfTheElementsP() then
    return S.LavaBurst, false, 8
  elseif Player:BuffUp(S.LavaSurgeBuff) and S.LavaBurst:ChargesFractional() >= 1.25 then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif IsViable(S.ElementalBlast) then
    return S.ElementalBlast, false, 45
  elseif Player:BuffUp(S.LavaSurgeBuff) then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif Player:BuffStack(S.WindGustBuff) > 2 then
    return S.LightningBolt, false, 11
  elseif IsViable(S.Icefury) then
    return S.Icefury, false, 37
  elseif IsViable(S.LavaBurst) then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif IcefuryBuffP() then 
    return S.FrostShock, false, 8
  elseif IsViable(S.LightningBolt) then
    return S.LightningBolt, true, 11
  end
  -- End up here when there are no castable builders for a stacked cleave situation (on the move, no LB charges)
  return nil, false, 0
end

local function StackedCleaveBuilder()
  local lavaburst_ms_lb = 10*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  local lavaburst_ms_ub = 14*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  local n = NumEnemiesInLargestCluster
  local chainlightning_ms = 4*n + 3*n*n

  -- In this top case, we set lavaburst_ms_ub = 0 because we don't actually care about overcapping MS to MOTE empower a quake.
  if MaelstromP() + lavaburst_ms_lb >= 60 and Player:BuffUp(S.LavaSurgeBuff) and SelectSpender() == S.Earthquake and S.MasterOfTheElements:IsAvailable() and not MasterOfTheElementsP() then
    return S.LavaBurst, false, 0
  elseif Player:BuffUp(S.LavaSurgeBuff) and S.LavaBurst:ChargesFractional() >= 1.5 then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif IsViable(S.ElementalBlast) then
    return S.ElementalBlast, false, 45
  elseif Player:BuffUp(S.LavaSurgeBuff) then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif Player:BuffStack(S.WindGustBuff) > 18 then
    return S.ChainLightning, false, chainlightning_ms
  elseif IsViable(S.LavaBurst) then
    return S.LavaBurst, false, lavaburst_ms_ub
  elseif IcefuryBuffP() then 
    return S.FrostShock, false, 8
  elseif IsViable(S.Icefury) then
    return S.Icefury, false, 37
  elseif IsViable(S.ChainLightning) then
    return S.ChainLightning, true, chainlightning_ms
  end
  -- End up here when there are no castable builders for a stacked cleave situation (on the move, no LB charges)
  return nil, false, 0

end

local function AOEBuilder()
  local lavaburst_ms_lb = 10*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  local lavaburst_ms_ub = 14*(1 + num(Player:BuffUp(S.PrimordialWaveBuff))*ActiveFlameshocks)
  local n = NumEnemiesInLargestCluster
  local chainlightning_ms = 4*n + 3*n*n

  -- In this top case, we set lavaburst_ms_ub = 0 because we don't actually care about overcapping MS to MOTE empower a quake.
  if MaelstromP() + lavaburst_ms_lb >= 60 and Player:BuffUp(S.LavaSurgeBuff) and SelectSpender() == S.Earthquake and S.MasterOfTheElements:IsAvailable() and not MasterOfTheElementsP() then
    return S.LavaBurst, false, 0
  elseif IsViable(S.ChainLightning) then
    return S.ChainLightning, false, chainlightning_ms
  elseif IsViable(S.LavaBurst) then
    return S.LavaBurst, true, lavaburst_ms_ub
  end
  -- End up here when there are no castable builders for an AOE situation (on the move, no LB charges)
  return nil, false, 0
end

local function CoreRotation()
  local DebugMessage

  -- Keep minimum number of flameshocks up
  if ActiveFlameshocks < NumFlameShocksToMaintain() then
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return DebugMessage end;
  end

  -- Use MOTE empowerments appropriately. This function handles all cases (ST/Cleave/AOE).
  if MasterOfTheElementsP() then
    DebugMessage = MoteEmpowerment()
    if DebugMessage then return DebugMessage end
  end

  -- Select the right rotation (1t/SpreadCleave, StackedCleave, AOE) and find the best builder.
  -- Also set the "prefer flameshock refresh" variable if the builder is lower priority than just refreshing flameshock in a pandemic window.
  -- Also set the "maelstrom generation upperbound" variable for the builder.
  local builder, prefer_fs_refresh, ms_gen_ub = nil, false, 0

  if NumEnemiesInLargestCluster == 1 then 
    builder, prefer_fs_refresh, ms_gen_ub = SingleTargetAndSpreadCleaveBuilder() 
  end
  if (NumEnemiesInCombat == 2 or NumEnemiesInCombat == 3) and (NumEnemiesInLargestCluster == 2 or NumEnemiesInLargestCluster == 3) then 
    builder, prefer_fs_refresh, ms_gen_ub = StackedCleaveBuilder() 
  end
  if NumEnemiesInCombat >= 4 and NumEnemiesInLargestCluster >= 2 then
    builder, prefer_fs_refresh, ms_gen_ub = AOEBuilder() 
  end

  -- Refresh flameshocks when the builder is low priority.
  local flame_shock_condition_a = (prefer_fs_refresh and RefreshableFlameshocks > 0 and ActiveFlameshocks <= NumFlameShocksToMaintain())
  local flame_shock_condition_b = (NumEnemiesInLargestCluster == 1 and S.PrimordialWave:IsAvailable() and IsViable(S.PrimordialWave))
  if flame_shock_condition_a or flame_shock_condition_b then
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return DebugMessage end;
  end
  
  local spender = SelectSpender()

  -- If the maelstrom you'll have at the end of this cast plus the maelstrom from the next suggested spell could overcap you, spend.
  if MaelstromP() + ms_gen_ub > 100 and MaelstromP() >= 60 then
    if Cast(spender) then return "Spending Maelstrom because the best builder would overcap." end
  end

  -- If you have a non-nil + viable builder, then you should cast it!
  if builder ~= nil and IsViable(builder) then
    if Cast(builder) then return "Building Maelstrom with optimal Builder (AOE)" end
  end

  -- If you can't do a good builder, then you should try to first spend resources, then refresh flame shocks, then frost shock.
  if builder == nil then
    -- Try to spend resources
    if MaelstromP() >= 60 then
      if Cast(spender) then return "Spending Maelstrom because we cannot build" end
    end
    -- Try to refresh flameshocks
    DebugMessage = ApplyFlameShock()
    if DebugMessage then return "Refreshing Flame Shock because we cannot build or spend" end
    -- Try to frost shock
    if Cast(S.FrostShock) then return "Casting Frost Shock because we cannot build or spend or refresh flame shock" end
    -- Who the fuck knows, maybe a healing stream totem?
  end

  return nil
end

--- ======= MAIN =======
local function APL()
  -- Generalized Data Updates (per frame)
  BattlefieldSnapshot()
  PetUpdates()

  local DebugMessage
  if Everyone.TargetIsValid() then
    -- Refresh shields.
    if Settings.Elemental.PreferEarthShield and S.EarthShield:IsCastable() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Earth Shield Refresh"; end
    elseif S.LightningShield:IsCastable() and Player:BuffDown(S.LightningShield) and (Settings.Elemental.PreferEarthShield and Player:BuffDown(S.EarthShield) or not Settings.Elemental.PreferEarthShield) then
      if Cast(S.LightningShield, Settings.Elemental.GCDasOffGCD.Shield) then return "Lightning Shield Refresh" end
    end
    if not Player:AffectingCombat() then
      DebugMessage = Precombat();
      if DebugMessage then return DebugMessage end;
    end
    Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false);

    DebugMessage = Cooldowns()
    if DebugMessage then return DebugMessage end;

    DebugMessage = CoreRotation()
    if DebugMessage then return DebugMessage end;

    -- This is actually an "error" state, we should always be able to frost shock.
    HR.CastAnnotated(S.Pool, false, "ERR");
  end
end

local function Init()
  HR.Print("Elemental Shaman rotation is currently a work in progress.")
end

HR.SetAPL(262, APL, Init)
