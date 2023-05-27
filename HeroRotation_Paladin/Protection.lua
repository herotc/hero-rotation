--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CastMainNameplate = HR.CastMainNameplate
local CastMainNameplateSuggested = HR.CastMainNameplateSuggested
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool

-- WoW API
local mathfloor  = math.floor
local GetTotemInfo = GetTotemInfo
local GetTime      = GetTime

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Paladin.Protection
local I = Item.Paladin.Protection

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Interrupts List
local StunInterrupts = {
  {S.HammerofJustice, "Cast Hammer of Justice (Interrupt)", function () return true; end},
}

local GCDMax
local Enemies8y, Enemies30y
local EnemiesCount8y, EnemiesCount30y
local InterruptibleEnemyUnits
local WrathableEnemyUnits
local HighestHPEnemyUnit
local PartyHealCandidates
local PartyDispelCandidates

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Paladin.Commons,
  Protection = HR.GUISettings.APL.Paladin.Protection
}

local function ConsecrationTimeRemaining()
  for index=1,4 do
    local _, totemName, startTime, duration = GetTotemInfo(index)
    if totemName == S.Consecration:Name() then
      return (mathfloor(startTime + duration - GetTime() + 0.5)) or 0
    end
  end
  return 0
end

local function MissingAura()
  return (Player:BuffDown(S.RetributionAura) and Player:BuffDown(S.DevotionAura) and Player:BuffDown(S.ConcentrationAura) and Player:BuffDown(S.CrusaderAura))
end

local function ScanBattlefield()
  InterruptibleEnemyUnits = {}
  WrathableEnemyUnits = {}
  HighestHPEnemyUnit = nil
  local highest_health = 0
  for _, CycleUnit in pairs(Enemies30y) do
    if not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() then
      if CycleUnit:IsInterruptible() then
        table.insert(InterruptibleEnemyUnits, {CycleUnit, CycleUnit:Health()})
      end
      if CycleUnit:HealthPercentage() <= 20 or Player:BuffUp(S.AvengingWrathBuff) then
        table.insert(WrathableEnemyUnits, {CycleUnit, CycleUnit:Health()})
      end
      -- TODO: cycle judgment debuffs around rather than hit highest HP?
      if CycleUnit:Health() >= highest_health then
        highest_health = CycleUnit:Health()
        HighestHPEnemyUnit = CycleUnit
      end
    end
  end

  PartyHealCandidates = {}
  PartyDispelCandidates = {} -- TODO: add some whitelist code for dispellable debuffs on players (consider cleanse, freedom, bop, spellwarding)
  if Player:IsInParty() and not Player:IsInRaid() then
    for _, Char in pairs(Unit.Party) do
      if Char ~= nil and Char:Exists() and Char:IsInRange(40) and Char:HealthPercentage() < Settings.Protection.FriendlyWordofGloryHP then
        table.insert(PartyHealCandidates, {Char, Char:HealthPercentage()})
      end
    end
  end

  table.sort(InterruptibleEnemyUnits, function (a, b) return a[2] > b[2] end)
  table.sort(WrathableEnemyUnits, function (a, b) return a[2] > b[2] end)
  table.sort(PartyHealCandidates, function (a, b) return a[2] < b[2] end)
end

-- Returns `true` if it's safe to dump SOTR or healing without incurring the ICD bug, `false` if you should wait a bit
local function RPSafe()
  return not S.RighteousProtector:IsAvailable() or (S.ShieldoftheRighteous:TimeSinceLastCast() > 1 and S.WordofGlory:TimeSinceLastCast() > 1)
end

local function Precombat()
  if S.DevotionAura:IsCastable() and (MissingAura()) then
    if Cast(S.DevotionAura) then return "devotion_aura precombat"; end
  end
  if S.HammerofWrath:IsReady() then
    if CastMainNameplate(Target, S.HammerofWrath) then return "hammer of wrath precombat"; end
  end
  if S.Judgment:FullRechargeTime() < GCDMax and S.Judgment:IsReady() then
    if CastMainNameplate(Target, S.Judgment) then return "max charges judgment precombat"; end
  end
  if S.AvengersShield:IsCastable() then
    if CastMainNameplate(Target, S.AvengersShield) then return "avengers_shield precombat"; end
  end
  if S.Judgment:IsReady() then
    if CastMainNameplate(Target, S.Judgment) then return "judgment precombat"; end
  end
  if S.Consecration:IsCastable() and Target:IsInMeleeRange(8) then
    if CastMainNameplate(Target, S.Consecration) then return "consecration precombat 8"; end
  end
end

local function Defensives()
  if Player:HealthPercentage() <= Settings.Protection.BubbleHP and S.DivineShield:IsCastable() then
    if Cast(S.DivineShield, nil, Settings.Protection.DisplayStyle.Defensives) then return "bubble defensive"; end
  end
  if Player:HealthPercentage() <= Settings.Protection.LoHHP and S.LayonHands:IsCastable() then
    if HR.CastAnnotated(S.LayonHands, nil, "SELF") then return "lay_on_hands self defensive"; end
  end
  if Player:HealthPercentage() < Settings.Protection.PrioSelfWordofGloryHP and Player:BuffUp(S.ShiningLightFreeBuff) then
    if HR.CastAnnotated(S.WordofGlory, nil, "SELF") then return "free WOG self defensive"; end
  end
  if S.GuardianofAncientKings:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.GoAKHP and Player:BuffDown(S.ArdentDefenderBuff)) then
    if Cast(S.GuardianofAncientKings, nil, Settings.Protection.DisplayStyle.Defensives) then return "guardian_of_ancient_kings defensive"; end
  end
  if S.ArdentDefender:IsCastable() and (Player:HealthPercentage() <= Settings.Protection.ArdentDefenderHP and Player:BuffDown(S.GuardianofAncientKingsBuff)) then
    if Cast(S.ArdentDefender, nil, Settings.Protection.DisplayStyle.Defensives) then return "ardent_defender defensive"; end
  end
  if S.ShieldoftheRighteous:IsReady() and Player:BuffRefreshable(S.ShieldoftheRighteousBuff) and RPSafe() then
    -- TODO: figure out how to do this on nameplates too?
    if CastMainNameplateSuggested(Target, S.ShieldoftheRighteous) then return "shield_of_the_righteous refresh defensive"; end
  end
end

local function Cooldowns()
  if S.LightsJudgment:IsCastable() then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cooldowns"; end
  end
  if S.AvengingWrath:IsCastable() then
    if Cast(S.AvengingWrath, Settings.Protection.OffGCDasOffGCD.AvengingWrath) then return "avenging_wrath cooldowns"; end
  end
  if S.Sentinel:IsCastable() then
    if Cast(S.Sentinel, Settings.Protection.OffGCDasOffGCD.Sentinel) then return "sentinel cooldowns"; end
  end
  if S.DivineToll:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff) or not S.AvengingWrath:IsAvailable()) and (Player:BuffUp(S.MomentofGloryBuff) or not S.MomentofGlory:IsAvailable()) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll standard"; end
  end
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AvengingWrathBuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldowns"; end
    end
  end
  if S.MomentofGlory:IsCastable() and (Player:BuffRemains(S.AvengingWrathBuff) < 15 or (HL.CombatTime() > 10 or (S.AvengingWrath:CooldownRemains() > 15)) and (S.AvengersShield:CooldownDown() and S.Judgment:CooldownDown() and S.HammerofWrath:CooldownDown())) then
    if Cast(S.MomentofGlory, Settings.Protection.OffGCDasOffGCD.MomentOfGlory) then return "moment_of_glory cooldowns"; end
  end
  if S.DivineToll:IsReady() and (EnemiesCount8y >= 3) then
    if Cast(S.DivineToll, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "divine_toll cooldowns"; end
  end
  if S.BastionofLight:IsCastable() and (Player:BuffUp(S.AvengingWrathBuff)) then
    if Cast(S.BastionofLight, Settings.Protection.OffGCDasOffGCD.BastionOfLight) then return "bastion_of_light cooldowns"; end
  end
end

local function Trinkets()
  if ((Player:BuffUp(S.MomentofGloryBuff) or (not S.MomentofGlory:IsAvailable()) and Player:BuffUp(S.AvengingWrathBuff)) or (S.MomentofGlory:CooldownRemains() > 20 or (not S.MomentofGlory:IsAvailable()) and S.AvengingWrath:CooldownRemains() > 20)) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

-- Return a (unit, spell) pair that generates at least one holy power; or (nil, nil) if no holy power generating spell is ready.
-- uses Rebuke (the kick) as a last ditch priority, assuming you have punishment
local function ForceGenerateHolyPowerGlobal()
  if S.AvengersShield:IsReady() and #InterruptibleEnemyUnits > 0 then
    return InterruptibleEnemyUnits[1][1], S.AvengersShield
  end
  if S.HammerofWrath:IsReady() and #WrathableEnemyUnits > 0 then
    return WrathableEnemyUnits[1][1], S.HammerofWrath
  end
  if S.Judgment:IsReady() then
    return Target, S.Judgment
  end
  if S.BlessedHammer:IsReady() then
    return Target, S.BlessedHammer
  end
  return nil, nil
end

-- Returns the appropriate {target, global, generated_hpower} based on our priorities.
-- if we have avengers_shield + hammer of wrath on CD and judgment + blessed_hammer recharging appropriately, we return {nil, nil} to indicate that we can do a low priority global here.
local function PrioGlobal()
  if Player:HealthPercentage() < Settings.Protection.PrioSelfWordofGloryHP and (Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.ShiningLightFreeBuff) or not Player:BuffRefreshable(S.ShieldoftheRighteousBuff)) then
    return Player, S.WordofGlory, 0
  end
  if S.AvengersShield:IsReady() and #InterruptibleEnemyUnits > 0 then
    return InterruptibleEnemyUnits[1][1], S.AvengersShield, 1
  end
  if S.AvengersShield:IsReady() and (Player:BuffUp(S.MomentofGloryBuff) or (Player:HasTier(29, 2) and (Player:BuffDown(S.AllyoftheLightBuff) or Player:BuffRemains(S.AllyoftheLightBuff) < Player:GCD()))) then
    return Target, S.AvengersShield, 0
  end
  if S.AvengersShield:IsReady() and EnemiesCount8y >= 4 then
    return Target, S.AvengersShield, 0
  end
  if S.HammerofWrath:IsReady() and #WrathableEnemyUnits > 0 then
    return WrathableEnemyUnits[1][1], S.HammerofWrath, 1
  end

  -- not sure which order on these is better
  if S.Judgment:IsReady() and S.Judgment:FullRechargeTime() < GCDMax then
    return HighestHPEnemyUnit, S.Judgment, 1 + num(Player:BuffUp(S.AvengingWrathBuff))
  end
  if S.AvengersShield:IsReady() and EnemiesCount8y >= 2 then
    return Target, S.AvengersShield, 0
  end

  if S.AvengersShield:IsReady() then
    return Target, S.AvengersShield, 0 -- single target
  end

  -- use OPPORTUNISTIC threshold for healing here - cast the heal on us or a party member if it (probably) won't overheal
  if Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.ShiningLightFreeBuff) then
    if Player:HealthPercentage() < Settings.Protection.OpportunisticSelfWordofGloryHP then
      return Player, S.WordofGlory, 0
    end
    if #PartyHealCandidates > 0 then
      return PartyHealCandidates[1][1], S.WordofGlory, 0
    end
  end

  if S.EyeofTyr:IsReady() then
    return Target, S.EyeofTyr, 0
  end
  if S.Judgment:IsReady() then
    return Target, S.Judgment, 1 + num(Player:BuffUp(S.AvengingWrathBuff))
  end
  if S.BlessedHammer:FullRechargeTime() < GCDMax then
    return Target, S.BlessedHammer, 1
  end

  return nil, nil, nil
end

local function LowPrioGlobal()
  if S.Consecration:IsCastable() and not Player:IsMoving() and ConsecrationTimeRemaining() <= 3 then
    return Target, S.Consecration
  end
  if S.BlessedHammer:IsReady() then
    return Target, S.BlessedHammer
  end
  if S.Consecration:IsCastable() and not Player:IsMoving() then
    return Target, S.Consecration
  end
  if Player:BuffUp(S.ShiningLightFreeBuff) then
    return Player, S.WordofGlory
  end
  return nil, nil
end


local function Core()
  -- Save allies from death with Lay on Hands where possible, when we're probably not going to die.
  if Player:HealthPercentage() > 40 and #PartyHealCandidates > 0 then
    local BestCandidate = PartyHealCandidates[1]
    local Friend = BestCandidate[1]
    local FriendHP = BestCandidate[2]
    if FriendHP <= 15 then -- TODO: handle forbearance here
      if HR.CastAnnotated(S.LayonHands, false, Friend:Name()) then return "lay_on_hands party_member core"; end
    end
  end
  ----------------------------------------------------------------------
  -- Guarantee defensive SOTR uptime > Consecration uptime > then other stuff
  -- TODO: consider adding a condition for being "non-scared" if Player:CooldownRemains(S.DivineToll) < Player:BuffRemains(S.ShieldoftheRighteousBuff)
  if not (Player:BuffUp(S.DivinePurposeBuff) or Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.AvengingWrathBuff)) then
    local target = nil
    local spell = nil
    -- You drop SOTR in (one/two/three) globals, but you're short holy power, so you *MUST* generate holy power this turn.
    if (1.0*Player:HolyPower() + Player:BuffRemains(S.ShieldoftheRighteousBuff) <= 3) then
      target, spell = ForceGenerateHolyPowerGlobal()
    end
    if target ~= nil and spell ~= nil then
      if CastMainNameplate(target, spell) then return "force_generated_holy_power_global standard"; end
    end
    -- This is a bad case, it means there was no holy power generator available when we really needed one.
  end

  -- Dump HOLY POWER into SOTR. We want to do this if our next global is a builder and we're capped on holy power already.
  local prio_target, prio_global, prio_hpower = PrioGlobal()
  if prio_global ~= nil and S.ShieldoftheRighteous:IsReady() and ((prio_hpower + Player:HolyPower() > 4) or Player:BuffUp(S.BastionofLightBuff) or Player:BuffUp(S.DivinePurposeBuff)) then
    if CastMainNameplateSuggested(prio_target, S.ShieldoftheRighteous) then return "shield_of_the_righteous holy power dump standard"; end
  end

  if S.Consecration:IsCastable() and ConsecrationTimeRemaining() < 2 and not Player:IsMoving() then
    if CastMainNameplate(Target, S.Consecration) then return "defensive_consecration standard"; end
  end

   -------------------------------------------------------------------

  if prio_global ~= nil then
    if prio_global == S.WordofGlory then
      if HR.CastAnnotated(S.WordofGlory, false, prio_target:Name()) then return "prio_global heal standard"; end
    else
      if CastMainNameplate(prio_target, prio_global) then return "prio_global standard"; end
    end
  end
  -------------------------------------------------------------------
  local low_prio_target, low_prio_global = LowPrioGlobal()
  if low_prio_global ~= nil then
    if low_prio_global == S.WordofGlory then
      if HR.CastAnnotated(S.WordofGlory, false, low_prio_target:Name()) then return "low_prio heal standard"; end
    else
      if CastMainNameplate(low_prio_target, low_prio_global) then return "low_prio standard"; end
    end
  end
end

-- APL Main
local function APL()
  Enemies8y = Player:GetEnemiesInMeleeRange(8)
  Enemies30y = Player:GetEnemiesInRange(30)
  EnemiesCount8y = #Enemies8y
  EnemiesCount30y = #Enemies30y

  -- constant term to account for human reaction time; tunable a bit.
  GCDMax = Player:GCD() + 0.050

  -- Get information on targets
  ScanBattlefield()

  -- Even if you're not in combat and don't have a target, press blessed hammer if you're capped on charges and at less than max holy power
  if not Player:AffectingCombat() and S.BlessedHammer:FullRechargeTime() < GCDMax and Player:HolyPower() < 5 then
    if Cast(S.BlessedHammer) then return "out of combat blessed hammer"; end
  end

  if Everyone.TargetIsValid() then
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end

    local ShouldReturn = Everyone.Interrupt(5, S.Rebuke, Settings.Commons.OffGCDasOffGCD.Rebuke, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Cooldowns(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = Core(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  HR.Print("This is a Work In Progress APL optimized for M+ tanking, by Synecd0che")
end

HR.SetAPL(66, APL, Init)
