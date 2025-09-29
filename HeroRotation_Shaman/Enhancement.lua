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
local GetSpellBonusDamage  = GetSpellBonusDamage
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetTime    = GetTime
local mathmax    = math.max
local mathmin    = math.min
local strmatch   = string.match
-- WoW API
local Delay      = C_Timer.After

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.UnyieldingNetherprism:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Shaman = HR.Commons.Shaman
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  CommonsDS = HR.GUISettings.APL.Shaman.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Shaman.CommonsOGCD,
  Enhancement = HR.GUISettings.APL.Shaman.Enhancement
}

--- ===== Rotation Variables =====
local HasMainHandEnchant, HasOffHandEnchant
local MHEnchantTimeRemains, OHEnchantTimeRemains
local MHEnchantID, OHEnchantID
local MaelstromStacks
local MaxMaelstromStacks = S.RagingMaelstrom:IsAvailable() and 10 or 5
local MaxAshenCatalystStacks = 8
local MaxConvergingStormsStacks = 6
local MaxTempestStacks = 2
local VarMinTalentedCDRemains = 1000
local VarTargetNatureMod, VarExpectedLBFunnel, VarExpectedCLFunnel
local VarFlameShockSaturated
local EnemiesMelee, EnemiesMeleeCount, Enemies40yCount
local MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
local TIAction = S.LightningBolt
local TWW2_2pc = Player:HasTier("TWW2", 2)
local TWW2_4pc = Player:HasTier("TWW2", 4)
local TWW3_2pc = Player:HasTier("TWW3", 2)
local TWW3_4pc = Player:HasTier("TWW3", 4)
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1IsWeird, VarTrinket2IsWeird
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded

  VarTrinket1IsWeird = VarTrinket1ID == I.AlgetharPuzzleBox:ID() or VarTrinket1ID == I.ManicGrieftorch:ID() or VarTrinket1ID == I.ElementiumPocketAnvil:ID() or VarTrinket1ID == I.BeaconToTheBeyond:ID() or VarTrinket1ID == I.UnyieldingNetherprism:ID()
  VarTrinket2IsWeird = VarTrinket2ID == I.AlgetharPuzzleBox:ID() or VarTrinket2ID == I.ManicGrieftorch:ID() or VarTrinket2ID == I.ElementiumPocketAnvil:ID() or VarTrinket2ID == I.BeaconToTheBeyond:ID() or VarTrinket2ID == I.UnyieldingNetherprism:ID()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  TWW2_2pc = Player:HasTier("TWW2", 2)
  TWW2_4pc = Player:HasTier("TWW2", 4)
  TWW3_2pc = Player:HasTier("TWW3", 2)
  TWW3_4pc = Player:HasTier("TWW3", 4)
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  TIAction = S.LightningBolt
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
local function RangedTargetCount(range)
  local EnemiesTable = Player:GetEnemiesInRange(range)
  local TarCount = 1
  for _, Enemy in pairs(EnemiesTable) do
    if Enemy:GUID() ~= Target:GUID() and (Enemy:AffectingCombat() or Enemy:IsDummy()) then
      TarCount = TarCount + 1
    end
  end
  return TarCount
end

local function TotemFinder(Totem, ReturnTime)
  for i = 1, 6, 1 do
    local TotemActive, TotemName, StartTime, Duration = Player:GetTotemInfo(i)
    if Totem:Name() == TotemName then
      if ReturnTime then
        return mathmax(Duration - (GetTime() - StartTime), 0)
      else
        return true
      end
    end
  end
  -- If totem not found, return appropriate default value.
  return ReturnTime and 0 or false
end

local function AlphaWolfMinRemains()
  if not S.AlphaWolf:IsAvailable() or Player:BuffDown(S.FeralSpiritBuff) then return 0 end
  local AWStart = mathmin(S.CrashLightning:TimeSinceLastCast(), S.ChainLightning:TimeSinceLastCast())
  if AWStart > 8 or AWStart > S.FeralSpirit:TimeSinceLastCast() then return 0 end
  return 8 - AWStart
end

--- ===== Register Damage Formulas =====
S.LightningBolt:RegisterDamageFormula(
  function()
    return
      -- Spell Power
      GetSpellBonusDamage(4) *
      -- 131.1% modifier
      1.311 *
      -- Mastery bonus
      (1 + Player:MasteryPct() / 100) *
      -- 3% bonus from Amplification Core if Surging Totem is active
      ((S.AmplificationCore:IsAvailable() and TotemFinder(S.SurgingTotem)) and 1.03 or 1)
  end
)

S.ChainLightning:RegisterDamageFormula(
  function()
    local MaxTargets = S.CrashingStorms:IsAvailable() and 5 or 3
    return
      -- Spell Power
      GetSpellBonusDamage(4) *
      -- 73.025% modifier
      0.73025 *
      -- Mastery bonus
      (1 + Player:MasteryPct() / 100) *
      -- Crashing Storms bonus
      (S.CrashingStorms:IsAvailable() and 1.4 or 1) *
      -- 3% bonus from Amplification Core if Surging Totem is active
      ((S.AmplificationCore:IsAvailable() and TotemFinder(S.SurgingTotem)) and 1.03 or 1) *
      -- Targets
      mathmin(EnemiesMeleeCount, MaxTargets)
  end
)

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterFlameShock(TargetUnit)
  return TargetUnit:DebuffRemains(S.FlameShockDebuff)
end

local function EvaluateTargetIfFilterLavaLash(TargetUnit)
  return TargetUnit:DebuffRemains(S.LashingFlamesDebuff)
end

local function EvaluateTargetIfFilterLightningRodRemains(TargetUnit)
  -- target_if=min:debuff.lightning_rod.remains
  return TargetUnit:DebuffRemains(S.LightningRodDebuff)
end

local function EvaluateTargetIfFilterPrimordialWave(TargetUnit)
  return TargetUnit:DebuffRemains(S.FlameShockDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfPrimordialWave(TargetUnit)
  return Player:BuffDown(S.PrimordialWaveBuff)
end

--- ===== CastCycle Functions =====
local function EvaluateCycleFlameShock(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.FlameShockDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- windfury_weapon
  -- flametongue_weapon
  -- lightning_shield
  -- Note: Moved shields and weapon buffs to APL().
  -- variable,name=trinket1_is_weird,value=trinket.1.is.algethar_puzzle_box|trinket.1.is.manic_grieftorch|trinket.1.is.elementium_pocket_anvil|trinket.1.is.beacon_to_the_beyond|trinket.1.is.unyielding_netherprism
  -- variable,name=trinket2_is_weird,value=trinket.2.is.algethar_puzzle_box|trinket.2.is.manic_grieftorch|trinket.2.is.elementium_pocket_anvil|trinket.2.is.beacon_to_the_beyond|trinket.2.is.unyielding_netherprism
  -- Note: Handled in trinket definitions.
  -- snapshot_stats
  -- Manually added openers:
  -- primordial_wave
  if S.PrimordialWave:IsReady() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave precombat 4"; end
  end
  -- feral_spirit
  if S.FeralSpirit:IsCastable() then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit precombat 6"; end
  end
  -- flame_shock
  if S.FlameShock:IsReady() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock precombat 8"; end
  end
end

local function SingleOpen()
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_open 2"; end
  end
  -- voltaic_blaze,if=active_dot.flame_shock<3&!buff.ascendance.up
  if S.VoltaicBlazeAbility:IsReady() and (S.FlameShockDebuff:AuraActiveCount() < 3 and Player:BuffDown(S.AscendanceBuff)) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single_open 4"; end
  end
  -- primordial_wave,if=(buff.maelstrom_weapon.stack>=4)&dot.flame_shock.ticking
  if S.PrimordialWave:IsReady() and (MaelstromStacks >= 4 and Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave single_open 6"; end
  end
  if Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable() then
    -- feral_spirit,if=buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled
    if S.FeralSpirit:IsCastable() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit single_open 8"; end
    end
    -- doom_winds,if=buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled
    if S.DoomWinds:IsReady() then
      if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single_open 10"; end
    end
  end
  -- ascendance,if=(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)&(buff.maelstrom_weapon.stack>=6|!set_bonus.tww3_4pc)
  if CDsON() and S.Ascendance:IsCastable() and ((Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable()) and (MaelstromStacks >= 6 or not TWW3_4pc)) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single_open 12"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable())) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm single_open 14"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single_open 16"; end
  end
  if ((MaelstromStacks >= 5 and not S.DeeplyRootedElements:IsAvailable()) or (S.DeeplyRootedElements:IsAvailable() and MaelstromStacks >= 7)) and (Player:BuffDown(S.LegacyoftheFrostWitchBuff) or Player:BuffUp(S.AscendanceBuff) or S.DeeplyRootedElements:IsAvailable()) then
    -- elemental_blast,if=((buff.maelstrom_weapon.stack>=5&!talent.deeply_rooted_elements.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=7))&(!buff.legacy_of_the_frost_witch.up|buff.ascendance.up|talent.deeply_rooted_elements.enabled)
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_open 18"; end
    end
    -- tempest,if=((buff.maelstrom_weapon.stack>=5&!talent.deeply_rooted_elements.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=7))&(!buff.legacy_of_the_frost_witch.up|buff.ascendance.up|talent.deeply_rooted_elements.enabled)
    if S.TempestAbility:IsReady() then
      if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single_open 20"; end
    end
    -- lightning_bolt,if=((buff.maelstrom_weapon.stack>=5&!talent.deeply_rooted_elements.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=7))&(!buff.legacy_of_the_frost_witch.up|buff.ascendance.up|talent.deeply_rooted_elements.enabled)
    if S.LightningBolt:IsCastable() then
      if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_open 22"; end
    end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single_open 24"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_open 26"; end
  end
  -- crash_lightning,if=set_bonus.tww2_4pc
  if S.CrashLightning:IsReady() and (TWW2_4pc) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_open 28"; end
  end
  -- voltatic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single_open 30"; end
  end
  -- lava_lash
  if S.LavaLash:IsCastable() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_open 32"; end
  end
end

local function Single()
  -- run_action_list,name=single_open,if=time<15
  if HL.CombatTime() < 15 then
    local ShouldReturn = SingleOpen(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleOpen()"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10|buff.primordial_storm.remains<=4&buff.maelstrom_weapon.stack>=5)
  if S.PrimordialStormAbility:IsCastable() and (MaelstromStacks >= 10 or Player:BuffRemains(S.PrimordialStormBuff) <= 4 and MaelstromStacks >= 5) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm single 2"; end
  end
  -- feral_spirit,if=(cooldown.doom_winds.remains>25|cooldown.doom_winds.remains<=5)
  if S.FeralSpirit:IsCastable() and (S.DoomWinds:CooldownRemains() > 25 or S.DoomWinds:CooldownRemains() <= 5) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit single 4"; end
  end
  -- doom_winds,if=(!buff.ascendance.up|(buff.tempest.up&buff.ascendance.remains>1*gcd&buff.maelstrom_weapon.stack<=9))&set_bonus.tww3_4pc
  if S.DoomWinds:IsCastable() and ((Player:BuffDown(S.AscendanceBuff) or (Player:BuffUp(S.TempestBuff) and Player:BuffRemains(S.AscendanceBuff) > Player:GCD() and MaelstromStacks <= 9)) and TWW3_4pc) then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single 6"; end
  end
  -- ice_strike,if=buff.tempest.up&buff.ascendance.remains>5*gcd&buff.maelstrom_weapon.stack<=1
  if S.IceStrike:IsCastable() and (Player:BuffUp(S.TempestBuff) and Player:BuffRemains(S.AscendanceBuff) > 5 * Player:GCD() and MaelstromStacks <= 1) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 8"; end
  end
  -- lava_lash,if=(buff.hot_hand.up&buff.ashen_catalyst.stack=buff.ashen_catalyst.max_stack)&(buff.tempest.up&buff.ascendance.remains>5*gcd&buff.maelstrom_weapon.stack<=1)
  if S.LavaLash:IsCastable() and ((Player:BuffUp(S.HotHandBuff) and Player:BuffStack(S.AshenCatalystBuff) == MaxAshenCatalystStacks) and (Player:BuffUp(S.TempestBuff) and Player:BuffRemains(S.AscendanceBuff) > 5 * Player:GCD() and MaelstromStacks <= 1)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 10"; end
  end
  -- flame_shock,if=!ticking&(talent.ashen_catalyst.enabled|talent.primordial_wave.enabled|talent.lashing_flames.enabled)&!buff.ascendance.up&!talent.voltaic_blaze.enabled
  if S.FlameShock:IsCastable() and (Target:DebuffDown(S.FlameShockDebuff) and (S.AshenCatalyst:IsAvailable() or S.PrimordialWave:IsAvailable() or S.LashingFlames:IsAvailable()) and Player:BuffDown(S.AscendanceBuff) and not S.VoltaicBlaze:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 12"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>0&ti_lightning_bolt
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 0 and TIAction == S.LightningBolt) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 14"; end
  end
  -- doom_winds
  if S.DoomWinds:IsReady() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single 16"; end
  end
  -- primordial_wave,if=dot.flame_shock.ticking&(raid_event.adds.in>action.primordial_wave.cooldown|raid_event.adds.in<6)
  if S.PrimordialWave:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave single 18"; end
  end
  -- ice_strike,if=buff.tempest.up&tww3_procs_to_asc=1&buff.maelstrom_weapon.stack<=8
  if S.IceStrike:IsCastable() and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1 and MaelstromStacks <= 8) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 20"; end
  end
  -- voltaic_blaze,if=buff.tempest.up&tww3_procs_to_asc=1&buff.maelstrom_weapon.stack<=6
  if S.VoltaicBlazeAbility:IsCastable() and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1 and MaelstromStacks <= 6) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single 22"; end
  end
  -- frost_shock,if=buff.tempest.up&tww3_procs_to_asc=1&buff.maelstrom_weapon.stack<=6&buff.hailstorm.stack=10&buff.ice_strike.up&talent.swirling_maelstrom.enabled
  if S.FrostShock:IsCastable() and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1 and MaelstromStacks <= 6 and Player:BuffStack(S.HailstormBuff) == 10 and Player:BuffUp(S.IceStrikeBuff) and S.SwirlingMaelstrom:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 24"; end
  end
  -- natures_swiftness,if=buff.tempest.up&tww3_procs_to_asc=1&buff.maelstrom_weapon.stack<=4
  if S.NaturesSwiftness:IsCastable() and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1 and MaelstromStacks <= 4) then
    if Cast(S.NaturesSwiftness, Settings.CommonsOGCD.GCDasOffGCD.NaturesSwiftness, nil, not Target:IsSpellInRange(S.NaturesSwiftness)) then return "natures_swiftness single 26"; end
  end
  -- tempest,if=(buff.maelstrom_weapon.stack>=5|buff.natures_swiftness.up)&(buff.tempest.up&tww3_procs_to_asc=1|buff.tempest.max_stack&cooldown.ascendance.remains<=2&talent.ascendance.enabled)&set_bonus.tww3_4pc
  if S.TempestAbility:IsCastable() and ((MaelstromStacks >= 5 or Player:BuffUp(S.NaturesSwiftness)) and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1 or Player:BuffStack(S.TempestBuff) == MaxTempestStacks and S.Ascendance:CooldownRemains() <= 2 and S.Ascendance:IsAvailable()) and TWW3_4pc) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single 28"; end
  end
  -- ascendance,if=(dot.flame_shock.ticking|!talent.primordial_wave.enabled|!talent.ashen_catalyst.enabled)
  if CDsON() and S.Ascendance:IsCastable() and (Target:DebuffUp(S.FlameShockDebuff) or not S.PrimordialWave:IsAvailable() or not S.AshenCatalyst:IsAvailable()) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single 30"; end
  end
  -- tempest,if=((buff.maelstrom_weapon.stack>=5)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=5))&(buff.tempest.stack=buff.tempest.max_stack&(tempest_mael_count>30|buff.awakening_storms.stack=3))
  -- Note: First maelstrom_weapon stack check covers the second condition as well...
  if S.TempestAbility:IsCastable() and (MaelstromStacks >= 5 and (Player:BuffStack(S.TempestBuff) == MaxTempestStacks and (Shaman.TempestMaelstrom > 30 or Player:BuffStack(S.AwakeningStormsBuff) == 3))) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single 32"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&tww3_procs_to_asc=1&((tempest_mael_count+buff.maelstrom_weapon.stack)>=40)&!buff.tempest.up
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and Shaman.TWW3ProcsToAsc == 1 and (Shaman.TempestMaelstrom + MaelstromStacks >= 40) and Player:BuffDown(S.TempestBuff)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 34"; end
  end
  -- elemental_blast,if=((!talent.overflowing_maelstrom.enabled&buff.maelstrom_weapon.stack>=5)|(buff.maelstrom_weapon.stack>=9&talent.ascendance.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=8))&(charges_fractional>=1.6|set_bonus.tww2_4pc)
  if S.ElementalBlast:IsReady() and (((not S.OverflowingMaelstrom:IsAvailable() and MaelstromStacks >= 5) or (MaelstromStacks >= 9 and S.Ascendance:IsAvailable()) or (S.DeeplyRootedElements:IsAvailable() and MaelstromStacks >= 8)) and (S.ElementalBlast:ChargesFractional() >= 1.6 or TWW2_4pc)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 36"; end
  end
  -- stormstrike,if=charges_fractional>=2&(buff.maelstrom_weapon.stack<=6)&!buff.tempest.up&tww3_procs_to_asc=1
  if S.Stormstrike:IsReady() and (S.Stormstrike:ChargesFractional() >= 2 and MaelstromStacks <= 6 and Player:BuffDown(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 38"; end
  end
  -- tempest,if=(buff.maelstrom_weapon.stack>=9&talent.ascendance.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=8)
  if S.TempestAbility:IsReady() and ((MaelstromStacks >= 9 and S.Ascendance:IsAvailable()) or (S.DeeplyRootedElements:IsAvailable() and MaelstromStacks >= 8)) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest single 40"; end
  end
  -- elemental_blast,if=((!talent.overflowing_maelstrom.enabled&buff.maelstrom_weapon.stack>=5)|(buff.maelstrom_weapon.stack>=9&talent.ascendance.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=8))&!buff.arc_discharge.up
  if S.ElementalBlast:IsReady() and (((not S.OverflowingMaelstrom:IsAvailable() and MaelstromStacks >= 5) or (MaelstromStacks >= 9 and S.Ascendance:IsAvailable()) or (S.DeeplyRootedElements:IsAvailable() and MaelstromStacks >= 8)) and Player:BuffDown(S.ArcDischargeBuff)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 42"; end
  end
  -- lightning_bolt,if=(buff.maelstrom_weapon.stack>=9&talent.ascendance.enabled)|(talent.deeply_rooted_elements.enabled&buff.maelstrom_weapon.stack>=8)
  if S.LightningBolt:IsCastable() and ((MaelstromStacks >= 9 and S.Ascendance:IsAvailable()) or (S.DeeplyRootedElements:IsAvailable() and MaelstromStacks >= 8)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 44"; end
  end
  -- windstrike,if=!talent.thorims_invocation.enabled
  if S.Windstrike:IsCastable() and (not S.ThorimsInvocation:IsAvailable()) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 46"; end
  end
  -- stormstrike,if=!buff.tempest.up&tww3_procs_to_asc=1
  if S.Stormstrike:IsReady() and (Player:BuffDown(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 48"; end
  end
  -- crash_lightning,if=(buff.doom_winds.up&buff.electrostatic_wager.stack>1)|buff.electrostatic_wager.stack>8
  if S.CrashLightning:IsReady() and ((Player:BuffUp(S.DoomWindsBuff) and Player:BuffStack(S.ElectrostaticWagerBuff) > 1) or Player:BuffStack(S.ElectrostaticWagerBuff) > 8) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 50"; end
  end
  -- ice_strike,if=(buff.tempest.up|(tempest_mael_count>=30&buff.tempest.up))&tww3_procs_to_asc=1
  -- Note: Simplified, as buff.tempest.up and (tempest_mael_count>=30&buff.tempest.up) are effectively the same.
  if S.IceStrike:IsReady() and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc == 1) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 52"; end
  end
  -- voltaic_blaze,if=tempest_mael_count>=30&tww3_procs_to_asc=1
  if S.VoltaicBlazeAbility:IsCastable() and (Shaman.TempestMaelstrom >= 30 and Shaman.TWW3ProcsToAsc == 1) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single 54"; end
  end
  -- stormstrike,if=buff.doom_winds.up|buff.stormblast.stack>0
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.StormblastBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 56"; end
  end
  -- crash_lightning,if=(talent.unrelenting_storms.enabled&talent.alpha_wolf.enabled&alpha_wolf_min_remains=0)|set_bonus.tww2_4pc
  if S.CrashLightning:IsReady() and ((S.UnrelentingStorms:IsAvailable() and S.AlphaWolf:IsAvailable() and AlphaWolfMinRemains() == 0) or TWW2_4pc) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 58"; end
  end
  -- voltaic_blaze,if=dot.flame_shock.remains<=4
  if S.VoltaicBlazeAbility:IsReady() and (Target:DebuffRemains(S.FlameShockDebuff) <= 4) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single 60"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 62"; end
  end
  -- stormstrike,if=charges_fractional>=1.8
  if S.Stormstrike:IsReady() and (S.Stormstrike:ChargesFractional() >= 1.8) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 64"; end
  end
  -- lava_lash,if=(talent.lashing_flames.enabled&(debuff.lashing_flames.remains<2))
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable() and Target:DebuffRemains(S.LashingFlamesDebuff) < 2) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 66"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single 68"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 70"; end
  end
  -- crash_lightning,if=talent.unrelenting_storms.enabled
  if S.CrashLightning:IsReady() and (S.UnrelentingStorms:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 72"; end
  end
  if MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialStormBuff) then
    -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 74"; end
    end
    -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up
    if S.LightningBolt:IsCastable() then
      if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 76"; end
    end
  end
  -- lava_lash,if=talent.elemental_assault.enabled&talent.molten_assault.enabled&dot.flame_shock.ticking
  if S.LavaLash:IsCastable() and (S.ElementalAssault:IsAvailable() and S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 78"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single 80"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 82"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 84"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 86"; end
  end
  -- sundering,if=raid_event.adds.in>=action.sundering.cooldown
  -- Note: We should never reach this line, due to the sundering line 4 lines above.
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 90"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 92"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single 94"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.CommonsOGCD.GCDasOffGCD.EarthElemental) then return "earth_elemental single 96"; end
  end
  -- flame_shock
  if S.FlameShock:IsReady() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 98"; end
  end
end

local function SingleTotemicOpen()
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_totemic_open 2"; end
  end
  -- lava_lash,if=!pet.surging_totem.active&talent.lashing_flames.enabled&debuff.lashing_flames.down
  if S.LavaLash:IsCastable() and (not TotemFinder(S.SurgingTotem) and S.LashingFlames:IsAvailable() and Target:DebuffDown(S.LashingFlamesDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic_open 4"; end
  end
  -- surging_totem,if=!buff.whirling_air.up&!buff.whirling_fire.up&!buff.whirling_earth.up
  if S.SurgingTotem:IsReady() and (Player:BuffDown(S.WhirlingAirBuff) and Player:BuffDown(S.WhirlingFireBuff) and Player:BuffDown(S.WhirlingEarthBuff)) then
    if Cast(S.SurgingTotem, nil, Settings.CommonsDS.DisplayStyle.SurgingTotem) then return "surging_totem single_totemic_open 6"; end
  end
  -- totemic_recall
  if S.TotemicRecall:IsReady() then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_totemic_open 8"; end
  end
  -- primordial_wave
  if S.PrimordialWave:IsReady() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave single_totemic_open 10"; end
  end
  -- feral_spirit,if=buff.legacy_of_the_frost_witch.up
  if S.FeralSpirit:IsCastable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit single_totemic_open 12"; end
  end
  -- lava_lash,if=buff.hot_hand.up|(buff.whirling_fire.up&cooldown.surging_totem.up&!buff.doom_winds.remains<=2)
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.HotHandBuff) or (Player:BuffUp(S.WhirlingFireBuff) and S.SurgingTotem:CooldownUp() and Player:BuffRemains(S.DoomWindsBuff) > 2)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic_open 14"; end
  end
  -- primordial_storm,if=buff.doom_winds.up&buff.maelstrom_weapon.max_stack&buff.legacy_of_the_frost_witch.up|(buff.primordial_storm.remains<=3&buff.maelstrom_weapon.max_stack)
  if S.PrimordialStormAbility:IsCastable() and (Player:BuffUp(S.DoomWindsBuff) and MaelstromStacks == MaxMaelstromStacks and Player:BuffUp(S.LegacyoftheFrostWitchBuff) or (Player:BuffRemains(S.PrimordialStormBuff) <= 3 and MaelstromStacks == MaxMaelstromStacks)) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm single_totemic_open 16"; end
  end
  -- doom_winds,if=buff.legacy_of_the_frost_witch.up
  if S.DoomWinds:IsReady() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single_totemic_open 18"; end
  end
  -- stormstrike,if=buff.doom_winds.up&buff.legacy_of_the_frost_witch.up
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) and Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_totemic_open 20"; end
  end
  -- sundering,if=buff.legacy_of_the_frost_witch.up
  if S.Sundering:IsReady() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single_totemic_open 22"; end
  end
  if MaelstromStacks == 10 then
    -- elemental_blast,if=buff.maelstrom_weapon.stack=10
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_totemic_open 24"; end
    end
    -- lightning_bolt,if=buff.maelstrom_weapon.stack=10
    if S.LightningBolt:IsCastable() then
      if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_totemic_open 26"; end
    end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_totemic_open 28"; end
  end
  -- lava_lash
  if S.LavaLash:IsCastable() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic_open 30"; end
  end
end

local function SingleTotemic()
  -- run_action_list,name=single_totemic_open,if=time<20
  if HL.CombatTime() < 20 then
    local ShouldReturn = SingleTotemicOpen(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for SingleTotemicOpen()"; end
  end
  -- surging_totem
  if S.SurgingTotem:IsReady() then
    if Cast(S.SurgingTotem, nil, Settings.CommonsDS.DisplayStyle.SurgingTotem) then return "surging_totem single_totemic 2"; end
  end
  -- ascendance,if=ti_lightning_bolt&pet.surging_totem.remains>4&(buff.totemic_rebound.stack>=3|buff.maelstrom_weapon.stack>0)
  if CDsON() and S.Ascendance:IsCastable() and (TIAction == S.LightningBolt and TotemFinder(S.SurgingTotem, true) > 4 and (Player:BuffStack(S.TotemicReboundBuff) >= 3 or MaelstromStacks > 0)) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance single_totemic 4"; end
  end
  -- flame_shock,if=!ticking&(talent.ashen_catalyst.enabled|talent.primordial_wave.enabled)
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff) and (S.AshenCatalyst:IsAvailable() or S.PrimordialWave:IsAvailable())) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_totemic 6"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic 8"; end
  end
  -- totemic_recall,if=(!buff.whirling_air.up&!buff.whirling_fire.up&!buff.whirling_earth.up)&pet.surging_totem.remains>=10
  if S.TotemicRecall:IsReady() and (Player:BuffDown(S.WhirlingAirBuff) and Player:BuffDown(S.WhirlingFireBuff) and Player:BuffDown(S.WhirlingEarthBuff)) and TotemFinder(S.SurgingTotem, true) >= 10 then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall single_totemic 10"; end
  end
  -- feral_spirit,if=((cooldown.doom_winds.remains>23|cooldown.doom_winds.remains<7)&(cooldown.primordial_wave.remains<20|buff.primordial_storm.up|!talent.primordial_storm.enabled))
  if S.FeralSpirit:IsCastable() and ((S.DoomWinds:CooldownRemains() > 23 or S.DoomWinds:CooldownRemains() < 7) and (S.PrimordialWave:CooldownRemains() < 20 or Player:BuffUp(S.PrimordialStormBuff) or not S.PrimordialStorm:IsAvailable())) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit single_totemic 12"; end
  end
  -- primordial_wave,if=dot.flame_shock.ticking&(raid_event.adds.in>action.primordial_wave.cooldown)|raid_event.adds.in<6
  if S.PrimordialWave:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave single_totemic 14"; end
  end
  -- doom_winds,if=buff.legacy_of_the_frost_witch.up
  if S.DoomWinds:IsReady() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single_totemic 16"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&((cooldown.doom_winds.remains>=buff.primordial_storm.remains)|buff.doom_winds.up|!talent.doom_winds.enabled|(buff.primordial_storm.remains<2*gcd))
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and ((S.DoomWinds:CooldownRemains() >= Player:BuffRemains(S.PrimordialStormBuff)) or Player:BuffUp(S.DoomWindsBuff) or not S.DoomWinds:IsAvailable() or (Player:BuffRemains(S.PrimordialStormBuff) < 2 * Player:GCD()))) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm single_totemic 18"; end
  end
  -- sundering,if=buff.ascendance.up&pet.surging_totem.active&talent.earthsurge.enabled&buff.legacy_of_the_frost_witch.up&buff.totemic_rebound.stack>=5&buff.earthen_weapon.stack>=2
  if S.Sundering:IsReady() and (Player:BuffUp(S.AscendanceBuff) and TotemFinder(S.SurgingTotem) and S.Earthsurge:IsAvailable() and Player:BuffUp(S.LegacyoftheFrostWitchBuff) and Player:BuffStack(S.TotemicReboundBuff) >= 5 and Player:BuffStack(S.EarthenWeaponBuff) >= 2) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single_totemic 20"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>0&ti_lightning_bolt
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 0 and TIAction == S.LightningBolt) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single_totemic 22"; end
  end
  -- sundering,if=buff.legacy_of_the_frost_witch.up&((cooldown.ascendance.remains>=10&talent.ascendance.enabled)|!talent.ascendance.enabled)&pet.surging_totem.active&buff.totemic_rebound.stack>=3&!buff.ascendance.up
  if S.Sundering:IsReady() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) and ((S.Ascendance:CooldownRemains() >= 10 and S.Ascendance:IsAvailable()) or not S.Ascendance:IsAvailable()) and TotemFinder(S.SurgingTotem) and Player:BuffStack(S.TotemicReboundBuff) >= 3 and Player:BuffDown(S.AscendanceBuff)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single_totemic 24"; end
  end
  -- crash_lightning,if=talent.unrelenting_storms.enabled&talent.alpha_wolf.enabled&alpha_wolf_min_remains=0
  if S.CrashLightning:IsReady() and (S.UnrelentingStorms:IsAvailable() and S.AlphaWolf:IsAvailable() and AlphaWolfMinRemains() == 0) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_totemic 26"; end
  end
  -- lava_burst,if=!talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=10&buff.whirling_air.down
  if S.LavaBurst:IsReady() and (not S.ThorimsInvocation:IsAvailable() and MaelstromStacks >= 10 and Player:BuffDown(S.WhirlingAirBuff)) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single_totemic 28"; end
  end
  -- elemental_blast,if=(buff.maelstrom_weapon.stack>=10)&(buff.primordial_storm.down|buff.primordial_storm.remains>4)
  if S.ElementalBlast:IsReady() and ((MaelstromStacks >= 10) and (Player:BuffDown(S.PrimordialStormBuff) or Player:BuffRemains(S.PrimordialStormBuff) > 4)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single_totemic 30"; end
  end
  -- stormstrike,if=buff.doom_winds.up&buff.legacy_of_the_frost_witch.up
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) and Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_totemic 32"; end
  end
  -- lightning_bolt,if=(buff.maelstrom_weapon.stack>=10)&(buff.primordial_storm.down|buff.primordial_storm.remains>4)
  if S.LightningBolt:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffDown(S.PrimordialStormBuff) or Player:BuffRemains(S.PrimordialStormBuff) > 4)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single_totemic 34"; end
  end
  -- crash_lightning,if=buff.electrostatic_wager.stack>4
  if S.CrashLightning:IsReady() and (Player:BuffStack(S.ElectrostaticWagerBuff) > 4) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_totemic 36"; end
  end
  -- stormstrike,if=buff.doom_winds.up|buff.stormblast.stack>1
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffStack(S.StormblastBuff) > 1) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_totemic 38"; end
  end
  -- lava_lash,if=buff.whirling_fire.up|buff.ashen_catalyst.stack>=8
  if S.LavaLash:IsReady() and (Player:BuffUp(S.WhirlingFireBuff) or Player:BuffStack(S.AshenCatalystBuff) >= 8) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic 40"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single_totemic 42"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single_totemic 44"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single_totemic 46"; end
  end
  -- crash_lightning,if=set_bonus.tww2_4pc
  if S.CrashLightning:IsReady() and (TWW2_4pc) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_totemic 48"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze single_totemic 50"; end
  end
  -- crash_lightning,if=talent.unrelenting_storms.enabled
  if S.CrashLightning:IsReady() and (S.UnrelentingStorms:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_totemic 52"; end
  end
  -- ice_strike,if=!buff.ice_strike.up
  if S.IceStrike:IsReady() and (Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single_totemic 54"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single_totemic 56"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single_totemic 58"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single_totemic 60"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.CommonsOGCD.GCDasOffGCD.EarthElemental) then return "earth_elemental single_totemic 62"; end
  end
  -- flame_shock,if=!talent.voltaic_blaze.enabled
  if S.FlameShock:IsReady() and (not S.VoltaicBlaze:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single_totemic 64"; end
  end
end

local function AoeOpen()
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_open 2"; end
  end
  -- crash_lightning,if=(buff.electrostatic_wager.stack>9&buff.doom_winds.up)|!buff.crash_lightning.up
  if S.CrashLightning:IsReady() and ((Player:BuffStack(S.ElectrostaticWagerBuff) > 9 and Player:BuffUp(S.DoomWindsBuff)) or Player:BuffDown(S.CrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_open 4"; end
  end
  -- voltaic_blaze,if=active_dot.flame_shock<3
  if S.VoltaicBlazeAbility:IsReady() and (S.FlameShockDebuff:AuraActiveCount() < 3) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe_open 6"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&(talent.primordial_wave.enabled|talent.fire_nova.enabled)&dot.flame_shock.ticking&!variable.flame_shock_saturated&active_dot.flame_shock<3
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and (S.PrimordialWave:IsAvailable() or S.FireNova:IsAvailable()) and S.FlameShockDebuff:AuraActiveCount() > 0 and not VarFlameShockSaturated and S.FlameShockDebuff:AuraActiveCount() < 3) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_open 8"; end
  end
  -- primordial_wave,if=(buff.maelstrom_weapon.stack>=4)&dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.PrimordialWave:IsReady() and ((MaelstromStacks >= 4) and Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave aoe_open 10"; end
  end
  -- feral_spirit,if=buff.maelstrom_weapon.stack>=9
  if S.FeralSpirit:IsCastable() and (MaelstromStacks >= 9) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit aoe_open 12"; end
  end
  -- doom_winds,if=buff.legacy_of_the_frost_witch.up
  if S.DoomWinds:IsCastable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds aoe_open 14"; end
  end
  -- ascendance,if=(dot.flame_shock.ticking|!talent.molten_assault.enabled)&ti_chain_lightning&(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)
  if CDsON() and S.Ascendance:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() > 0 or not S.MoltenAssault:IsAvailable()) and TIAction == S.ChainLightning and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable())) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe_open 16"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable())) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm aoe_open 18"; end
  end
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=9&!buff.ascendance.up
  if S.TempestAbility:IsReady() and (MaelstromStacks >= 9 and Player:BuffDown(S.AscendanceBuff)) then
    if Settings.Enhancement.TempestOnMTOnly then
      if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsSpellInRange(S.TempestAbility)) then return "tempest aoe_open 20 (forced MT)"; end
    else
      if Everyone.CastTargetIf(S.TempestAbility, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Tempest) then return "tempest aoe_open 20"; end
    end
  end
  -- crash_lightning,if=(buff.electrostatic_wager.stack>4)|!buff.crash_lightning.up|(buff.maelstrom_weapon.stack<2&buff.ascendance.up&buff.tempest.up)
  if S.CrashLightning:IsReady() and (Player:BuffStack(S.ElectrostaticWagerBuff) > 4 or Player:BuffDown(S.CrashLightningBuff) or (MaelstromStacks < 2 and Player:BuffUp(S.AscendanceBuff) and Player:BuffUp(S.TempestBuff))) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_open 22"; end
  end
  -- voltaic_blaze,if=(buff.maelstrom_weapon.stack<6&buff.ascendance.up&(buff.ascendance.remains>=gcd*2)&buff.tempest.up)
  if S.VoltaicBlazeAbility:IsReady() and (MaelstromStacks < 6 and Player:BuffUp(S.AscendanceBuff) and Player:BuffRemains(S.AscendanceBuff) >= Player:GCD() * 2 and Player:BuffUp(S.TempestBuff)) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe_open 24"; end
  end
  -- windstrike,target_if=min:debuff.lightning_rod.remains,if=talent.thorims_invocation.enabled&ti_chain_lightning
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and TIAction == S.ChainLightning) then
    if Everyone.CastTargetIf(S.Windstrike, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(30)) then return "windstrike aoe_open 26"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=5&(!buff.primordial_storm.up|!buff.legacy_of_the_frost_witch.up)&buff.doom_winds.up
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=9&(!buff.primordial_storm.up|!buff.legacy_of_the_frost_witch.up)
  -- Note: Combining both lines.
  if S.ChainLightning:IsReady() and (Player:BuffDown(S.PrimordialStormBuff) or not S.LegacyoftheFrostWitch:IsAvailable()) and (
    (MaelstromStacks >= 5 and Player:BuffUp(S.DoomWindsBuff)) or
    (MaelstromStacks >= 9)
  ) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_open 28"; end
  end
  -- stormstrike,if=buff.converging_storms.stack=6&buff.stormblast.stack>1
  if S.Stormstrike:IsReady() and (Player:BuffStack(S.ConvergingStormsBuff) == 6 and Player:BuffStack(S.StormblastBuff) > 1) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe_open 30"; end
  end
  -- fire_nova,if=variable.flame_shock_saturated&active_enemies>=4
  if S.FireNova:IsReady() and (VarFlameShockSaturated and EnemiesMeleeCount >= 4) then
    if Cast(S.FireNova) then return "fire_nova aoe_open 32"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_open 34"; end
  end
  -- sundering,if=buff.doom_winds.up
  if S.Sundering:IsReady() and (Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe_open 36"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe_open 38"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe_open 40"; end
  end
end

local function Aoe()
  -- feral_spirit,if=talent.elemental_spirits.enabled|talent.alpha_wolf.enabled
  if S.FeralSpirit:IsCastable() and (S.ElementalSpirits:IsAvailable() or S.AlphaWolf:IsAvailable()) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit aoe 2"; end
  end
  -- run_action_list,name=aoe_open,if=time<15
  if HL.CombatTime() < 15 then
    local ShouldReturn = AoeOpen(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoeOpen()"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 4"; end
  end
  -- primordial_wave,if=dot.flame_shock.ticking&variable.flame_shock_saturated&(buff.tempest.up|tempest_mael_count<=35)
  if S.PrimordialWave:IsReady() and (S.FlameShockDebuff:AuraActiveCount() > 0 and VarFlameShockSaturated and (Player:BuffUp(S.TempestBuff) or Shaman.TempestMaelstrom <= 35)) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave aoe 6"; end
  end
  -- ascendance,if=(dot.flame_shock.ticking|!talent.molten_assault.enabled)&ti_chain_lightning
  if CDsON() and S.Ascendance:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() > 0 or not S.MoltenAssault:IsAvailable()) and TIAction == S.ChainLightning) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe 8"; end
  end
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=9&!buff.ascendance.up&(cooldown.primordial_wave.remains>15|buff.tempest.max_stack)
  if S.TempestAbility:IsReady() and (MaelstromStacks >= 9 and Player:BuffDown(S.AscendanceBuff) and (S.PrimordialWave:CooldownRemains() > 15 or Player:BuffStack(S.TempestBuff) == MaxTempestStacks)) then
    if Settings.Enhancement.TempestOnMTOnly then
      if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsSpellInRange(S.TempestAbility)) then return "tempest aoe 10 (forced MT)"; end
    else
      if Everyone.CastTargetIf(S.TempestAbility, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Tempest) then return "tempest aoe 12"; end
    end
  end
  -- windstrike,target_if=min:debuff.lightning_rod.remains,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=10&ti_chain_lightning&buff.tempest.up
  if S.Windstrike:IsReady() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks >= 10 and TIAction == S.ChainLightning and Player:BuffUp(S.TempestBuff)) then
    if Everyone.CastTargetIf(S.Windstrike, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(30), nil, Settings.CommonsDS.DisplayStyle.Windstrike) then return "windstrike aoe 14"; end
  end
  -- feral_spirit,if=(cooldown.doom_winds.remains>30|cooldown.doom_winds.remains<7)
  if S.FeralSpirit:IsCastable() and (S.DoomWinds:CooldownRemains() > 30 or S.DoomWinds:CooldownRemains() < 7) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit aoe 16"; end
  end
  -- doom_winds
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds aoe 18"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&(buff.doom_winds.up|!talent.doom_winds.enabled|(cooldown.doom_winds.remains>buff.primordial_storm.remains)|(buff.primordial_storm.remains<2*gcd))
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffUp(S.DoomWindsBuff) or not S.DoomWinds:IsAvailable() or (S.DoomWinds:CooldownRemains() > Player:BuffRemains(S.PrimordialStormBuff)) or (Player:BuffRemains(S.PrimordialStormBuff) < 2 * Player:GCD()))) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm aoe 20"; end
  end
  -- crash_lightning,if=talent.converging_storms.enabled&buff.electrostatic_wager.stack>6|!buff.crash_lightning.up|(buff.maelstrom_weapon.stack<2&buff.ascendance.up&buff.tempest.up)
  if S.CrashLightning:IsReady() and (S.ConvergingStorms:IsAvailable() and Player:BuffStack(S.ElectrostaticWagerBuff) > 6 or Player:BuffDown(S.CrashLightningBuff) or (MaelstromStacks < 2 and Player:BuffUp(S.AscendanceBuff) and Player:BuffUp(S.TempestBuff))) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 22"; end
  end
  if MaelstromStacks < 6 and Player:BuffUp(S.AscendanceBuff) and Player:BuffRemains(S.AscendanceBuff) >= Player:GCD() * 2 and Player:BuffUp(S.TempestBuff) then
    -- voltaic_blaze,if=(buff.maelstrom_weapon.stack<6&buff.ascendance.up&(buff.ascendance.remains>=gcd*2)&buff.tempest.up)
    if S.VoltaicBlazeAbility:IsReady() then
      if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe 24"; end
    end
    -- sundering,if=(buff.maelstrom_weapon.stack<6&buff.ascendance.up&(buff.ascendance.remains>=gcd*2)&buff.tempest.up)
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering aoe 26"; end
    end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=10&buff.ascendance.up&!buff.tempest.up
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 10 and Player:BuffUp(S.AscendanceBuff) and Player:BuffDown(S.TempestBuff)) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 28"; end
  end
  -- windstrike,target_if=min:debuff.lightning_rod.remains,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>0&ti_chain_lightning
  if S.Windstrike:IsReady() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 0 and TIAction == S.ChainLightning) then
    if Everyone.CastTargetIf(S.Windstrike, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(30), nil, Settings.CommonsDS.DisplayStyle.Windstrike) then return "windstrike aoe 30"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack>=5&((buff.tempest.up&tww3_procs_to_asc<=1)|(buff.tempest.max_stack&cooldown.ascendance.remains<=2&talent.ascendance.enabled))
  if S.TempestAbility:IsReady() and (MaelstromStacks >= 5 and (Player:BuffUp(S.TempestBuff) and Shaman.TWW3ProcsToAsc <= 1) or (Player:BuffStack(S.TempestBuff) == MaxTempestStacks and S.Ascendance:CooldownRemains() <= 2 and S.Ascendance:IsAvailable())) then
    if Settings.Enhancement.TempestOnMTOnly then
      if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsSpellInRange(S.TempestAbility)) then return "tempest aoe 32 (forced MT)"; end
    else
      if Everyone.CastTargetIf(S.TempestAbility, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Tempest) then return "tempest aoe 34"; end
    end
  end
  -- crash_lightning,if=talent.converging_storms.enabled&talent.alpha_wolf.enabled
  if S.CrashLightning:IsReady() and (S.ConvergingStorms:IsAvailable() and S.AlphaWolf:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 36"; end
  end
  -- stormstrike,if=buff.converging_storms.stack=6&buff.stormblast.stack>0&buff.legacy_of_the_frost_witch.up&buff.maelstrom_weapon.stack<=8
  if S.Stormstrike:IsReady() and (Player:BuffStack(S.ConvergingStormsBuff) == 6 and Player:BuffUp(S.StormblastBuff) and Player:BuffUp(S.LegacyoftheFrostWitchBuff) and MaelstromStacks <= 8) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 38"; end
  end
  -- crash_lightning,if=buff.maelstrom_weapon.stack<=8
  if S.CrashLightning:IsReady() and (MaelstromStacks <= 8) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 40"; end
  end
  -- voltaic_blaze,if=buff.maelstrom_weapon.stack<=8
  if S.VoltaicBlazeAbility:IsReady() and (MaelstromStacks <= 8) then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe 42"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=7&!buff.primordial_storm.up
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 7 and Player:BuffDown(S.PrimordialStormBuff)) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 44"; end
  end
  -- fire_nova,if=variable.flame_shock_saturated&active_enemies>=4
  if S.FireNova:IsReady() and (VarFlameShockSaturated and EnemiesMeleeCount >= 4) then
    if Cast(S.FireNova) then return "fire_nova aoe 46"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe 48"; end
  end
  -- stormstrike,if=talent.stormblast.enabled&talent.stormflurry.enabled
  if S.Stormstrike:IsReady() and (S.Stormblast:IsAvailable() and S.Stormflurry:IsAvailable()) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 50"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe 52"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,if=talent.lashing_flames.enabled|talent.molten_assault.enabled&dot.flame_shock.ticking
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable() or S.MoltenAssault:IsAvailable() and S.FlameShockDebuff:AuraActiveCount() > 0) then
    if Everyone.CastTargetIf(S.LavaLash, EnemiesMelee, "min", EvaluateTargetIfFilterLavaLash, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 54"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe 56"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 58"; end
  end
  -- sundering
  -- Note: Handled 6 lines above.
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  -- Note: Duplicate of flame_shock aoe 4.
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&!variable.flame_shock_saturated
  if S.FlameShock:IsReady() and (S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable() and not VarFlameShockSaturated) then
    if Everyone.CastTargetIf(S.FlameShock, EnemiesMelee, "min", EvaluateTargetIfFilterFlameShock, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 60"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova aoe 62"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&(talent.deeply_rooted_elements.enabled|buff.converging_storms.stack=buff.converging_storms.max_stack)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and (S.DeeplyRootedElements:IsAvailable() or Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 64"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 66"; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike aoe 68"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 70"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe 72"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 74"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 76"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova aoe 78"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialStormBuff)) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 80"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 82"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 84"; end
  end
end

local function AoeTotemicOpen()
  -- flame_shock,if=!ticking&!variable.flame_shock_saturated
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff) and not VarFlameShockSaturated) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_totemic_open 2"; end
  end
  -- lava_lash,if=!pet.surging_totem.active&!variable.flame_shock_saturated
  if S.LavaLash:IsReady() and (not TotemFinder(S.SurgingTotem) and not VarFlameShockSaturated) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic_open 4"; end
  end
  -- surging_totem,if=!buff.whirling_air.up&!buff.whirling_fire.up&!buff.whirling_earth.up
  if S.SurgingTotem:IsReady() and (Player:BuffDown(S.WhirlingAirBuff) and Player:BuffDown(S.WhirlingFireBuff) and Player:BuffDown(S.WhirlingEarthBuff)) then
    if Cast(S.SurgingTotem, nil, Settings.CommonsDS.DisplayStyle.SurgingTotem) then return "surging_totem aoe_totemic_open 6"; end
  end
  -- totemic_recall
  if S.TotemicRecall:IsReady() then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall aoe_totemic_open 8"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_totemic_open 10"; end
  end
  -- fire_nova,if=talent.swirling_maelstrom.enabled&dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.FireNova:IsReady() and (S.SwirlingMaelstrom:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic_open 12"; end
  end
  -- primordial_wave,if=dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.PrimordialWave:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave aoe_totemic_open 14"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=10&!buff.legacy_of_the_frost_witch.up&cooldown.doom_winds.remains=0
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 10 and Player:BuffDown(S.LegacyoftheFrostWitchBuff) and S.DoomWinds:CooldownUp()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe_totemic_open 16"; end
  end
  -- doom_winds,if=buff.legacy_of_the_frost_witch.up
  if S.DoomWinds:IsCastable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds aoe_totemic_open 18"; end
  end
  -- crash_lightning,if=(buff.electrostatic_wager.stack>9&buff.doom_winds.up)|!buff.crash_lightning.up
  if S.CrashLightning:IsReady() and ((Player:BuffStack(S.ElectrostaticWagerBuff) > 9 and Player:BuffUp(S.DoomWindsBuff)) or Player:BuffDown(S.CrashLightningBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic_open 20"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&(buff.doom_winds.remains<=gcd.max|!buff.doom_winds.up&cooldown.doom_winds.remains>buff.primordial_storm.remains)
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffRemains(S.DoomWindsBuff) <= Player:GCD() or Player:BuffDown(S.DoomWindsBuff) and S.DoomWinds:CooldownRemains() > Player:BuffRemains(S.PrimordialStormBuff))) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm aoe_totemic_open 22"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic_open 24"; end
  end
  -- sundering,if=buff.legacy_of_the_frost_witch.up|(buff.earthen_weapon.stack>=2&buff.primordial_storm.up)
  if S.Sundering:IsCastable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) or (Player:BuffStack(S.EarthenWeaponBuff) >= 2 and Player:BuffUp(S.PrimordialStormBuff))) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe_totemic_open 26"; end
  end
  -- lava_lash,if=(buff.legacy_of_the_frost_witch.up&buff.whirling_fire.up)
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) and Player:BuffUp(S.WhirlingFireBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic_open 28"; end
  end
  -- crash_lightning,if=(buff.earthen_weapon.stack>=2&buff.primordial_storm.up&buff.doom_winds.up)
  if S.CrashLightning:IsCastable() and (Player:BuffStack(S.EarthenWeaponBuff) >= 2 and Player:BuffUp(S.PrimordialStormBuff) and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic_open 30"; end
  end
  if MaelstromStacks >= 10 then
    -- elemental_blast,if=buff.maelstrom_weapon.stack>=10
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe_totemic_open 32"; end
    end
    -- chain_lightning,if=buff.maelstrom_weapon.stack>=10
    if S.ChainLightning:IsReady() then
      if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_totemic_open 34"; end
    end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up&pet.searing_totem.active
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff) and Shaman.SearingTotemActive) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe_totemic_open 36"; end
  end
  -- fire_nova,if=pet.searing_totem.active&dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.FireNova:IsReady() and (Shaman.SearingTotemActive and Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic_open 38"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe_totemic_open 40"; end
  end
  -- stormstrike,if=buff.maelstrom_weapon.stack<10&!buff.legacy_of_the_frost_witch.up
  if S.Stormstrike:IsReady() and (MaelstromStacks < 10 and Player:BuffDown(S.LegacyoftheFrostWitchBuff)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe_totemic_open 42"; end
  end
  -- lava_lash
  if S.LavaLash:IsCastable() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic_open 44"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up&pet.searing_totem.active
  -- Note: Duplicate of frost_shock aoe_totemic_open 36.
  -- crash_lightning,if=talent.crashing_storms.enabled
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic_open 46"; end
  end
  -- fire_nova,if=dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic_open 48"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe_totemic_open 50"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic_open 52"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe_totemic_open 54"; end
  end
  if MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialStormBuff) then
    -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe_totemic_open 56"; end
    end
    -- chain_lightning,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up
    if S.ChainLightning:IsReady() then
      if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_totemic_open 58"; end
    end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe_totemic_open 60"; end
  end
end

local function AoeTotemic()
  -- run_action_list,name=aoe_totemic_open,if=(time<=16)
  if HL.CombatTime() <= 16 then
    local ShouldReturn = AoeTotemicOpen(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AoeTotemicOpen()"; end
  end
  -- surging_totem
  if S.SurgingTotem:IsReady() then
    if Cast(S.SurgingTotem, nil, Settings.CommonsDS.DisplayStyle.SurgingTotem) then return "surging_totem aoe_totemic 2"; end
  end
  -- ascendance,if=ti_chain_lightning
  if CDsON() and S.Ascendance:IsCastable() and (TIAction == S.ChainLightning) then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance aoe_totemic 4"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&(active_enemies>=15-5*talent.unruly_winds.enabled)
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and (EnemiesMeleeCount >= 15 - 5 * num(S.UnrulyWinds:IsAvailable()))) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 6"; end
  end
  -- feral_spirit,if=(cooldown.doom_winds.remains>15|cooldown.doom_winds.remains<=7)|buff.earthen_weapon.stack>=2
  if S.FeralSpirit:IsCastable() and ((S.DoomWinds:CooldownRemains() > 15 or S.DoomWinds:CooldownRemains() < 7) or Player:BuffStack(S.EarthenWeaponBuff) >= 2) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit aoe_totemic 8"; end
  end
  -- primordial_storm,if=(buff.maelstrom_weapon.stack>=10)&(buff.doom_winds.remains<=gcd*3|!buff.doom_winds.up&cooldown.doom_winds.remains>buff.primordial_storm.remains|buff.earthen_weapon.stack>=4|buff.earthen_weapon.remains<=gcd*3)
  if S.PrimordialStormAbility:IsCastable() and ((MaelstromStacks >= 10) and (Player:BuffRemains(S.DoomWindsBuff) <= Player:GCD() * 3 or Player:BuffDown(S.DoomWindsBuff) and S.DoomWinds:CooldownRemains() > Player:BuffRemains(S.PrimordialStormBuff) or Player:BuffStack(S.EarthenWeaponBuff) >= 4 or Player:BuffRemains(S.EarthenWeaponBuff) <= Player:GCD() * 3)) then
    if Cast(S.PrimordialStormAbility, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_storm aoe_totemic 10"; end
  end
  -- flame_shock,if=!ticking&(talent.ashen_catalyst.enabled|talent.primordial_wave.enabled)&!variable.flame_shock_saturated
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff) and (S.AshenCatalyst:IsAvailable() or S.PrimordialWave:IsAvailable()) and not VarFlameShockSaturated) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_totemic 12"; end
  end
  -- doom_winds
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds aoe_totemic 14"; end
  end
  -- primordial_wave,if=dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.PrimordialWave:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsInRange(45)) then return "primordial_wave aoe_totemic 16"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike aoe_totemic 18"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsCastable() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic 20"; end
  end
  -- totemic_recall,if=(!buff.whirling_air.up&!buff.whirling_fire.up&!buff.whirling_earth.up)&pet.surging_totem.remains>=10
  if S.TotemicRecall:IsReady() and (Player:BuffDown(S.WhirlingAirBuff) and Player:BuffDown(S.WhirlingFireBuff) and Player:BuffDown(S.WhirlingEarthBuff) and TotemFinder(S.SurgingTotem, true) >= 10) then
    if Cast(S.TotemicRecall, Settings.CommonsOGCD.GCDasOffGCD.TotemicRecall) then return "totemic_recall aoe_totemic 22"; end
  end
  -- crash_lightning,if=buff.electrostatic_wager.stack>8
  if S.CrashLightning:IsReady() and (Player:BuffStack(S.ElectrostaticWagerBuff) > 8) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 24"; end
  end
  -- sundering,if=buff.doom_winds.up|talent.earthsurge.enabled&(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)&pet.surging_totem.active
  if S.Sundering:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or S.Earthsurge:IsAvailable() and (Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable()) and TotemFinder(S.SurgingTotem)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe_totemic 26"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=10&buff.electrostatic_wager.stack>4&!buff.cl_crash_lightning.up&buff.doom_winds.up
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 10 and Player:BuffStack(S.ElectrostaticWagerBuff) > 4 and Player:BuffDown(S.CLCrashLightningBuff) and Player:BuffUp(S.DoomWindsBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_totemic 28"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=10
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 10) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe_totemic 30"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=10&((buff.doom_winds.remains>=gcd*3&buff.primordial_storm.up)|!buff.primordial_storm.up)
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 10 and ((Player:BuffRemains(S.DoomWindsBuff) >= Player:GCD() * 3 and Player:BuffUp(S.PrimordialStormBuff)) or Player:BuffDown(S.PrimordialStormBuff))) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_totemic 32"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 34"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe_totemic 36"; end
  end
  -- fire_nova,if=(dot.flame_shock.ticking&variable.flame_shock_saturated)&pet.searing_totem.active
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated and Shaman.SearingTotemActive) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic 38"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&dot.flame_shock.ticking
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic 40"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up&pet.searing_totem.active
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff) and Shaman.SearingTotemActive) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe_totemic 42"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 44"; end
  end
  -- fire_nova,if=dot.flame_shock.ticking&variable.flame_shock_saturated
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and VarFlameShockSaturated) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic 46"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe_totemic 48"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 50"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe_totemic 52"; end
  end
  if MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialStormBuff) and ((Player:BuffRemains(S.DoomWindsBuff) >= Player:GCD() * 3 and Player:BuffUp(S.PrimordialStormBuff)) or Player:BuffDown(S.PrimordialStormBuff)) then
    -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up&((buff.doom_winds.remains>=gcd*3&buff.primordial_storm.up)|!buff.primordial_storm.up)
    if S.ElementalBlast:IsReady() then
      if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe_totemic 54"; end
    end
    -- chain_lightning,if=buff.maelstrom_weapon.stack>=5&!buff.primordial_storm.up&((buff.doom_winds.remains>=gcd*3&buff.primordial_storm.up)|!buff.primordial_storm.up)
    if S.ChainLightning:IsReady() then
      if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe_totemic 56"; end
    end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe_totemic 58"; end
  end
  -- sundering,if=buff.doom_winds.up|talent.earthsurge.enabled&(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)&pet.surging_totem.active
  -- Note: Duplicate of sundering aoe_totemic 26.
  -- fire_nova,if=variable.flame_shock_saturated&active_enemies>=4
  if S.FireNova:IsReady() and (VarFlameShockSaturated and EnemiesMeleeCount >= 4) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic 60"; end
  end
  -- voltaic_blaze
  if S.VoltaicBlazeAbility:IsReady() then
    if Cast(S.VoltaicBlazeAbility, nil, nil, not Target:IsSpellInRange(S.VoltaicBlazeAbility)) then return "voltaic_blaze aoe_totemic 62"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe_totemic 64"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe_totemic 66"; end
  end
  -- sundering,if=(buff.legacy_of_the_frost_witch.up|!talent.legacy_of_the_frost_witch.enabled)&pet.surging_totem.active
  if S.Sundering:IsReady() and ((Player:BuffUp(S.LegacyoftheFrostWitchBuff) or not S.LegacyoftheFrostWitch:IsAvailable()) and TotemFinder(S.SurgingTotem)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe_totemic 68"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_totemic 70"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova aoe_totemic 72"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe_totemic 74"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe_totemic 76"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe_totemic 78"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe_totemic 80"; end
  end
end

local function Funnel()
  -- feral_spirit,if=talent.elemental_spirits.enabled
  if S.FeralSpirit:IsCastable() and (S.ElementalSpirits:IsAvailable()) then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit funnel 2"; end
  end
  -- surging_totem
  if S.SurgingTotem:IsReady() then
    if Cast(S.SurgingTotem, nil, Settings.CommonsDS.DisplayStyle.SurgingTotem) then return "surging_totem funnel 4"; end
  end
  -- ascendance
  if CDsON() and S.Ascendance:IsCastable() then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance funnel 6"; end
  end
  -- windstrike,if=(talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>0)|buff.converging_storms.stack=buff.converging_storms.max_stack
  if S.Windstrike:IsCastable() and ((S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 0) or Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike funnel 8"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack|(buff.maelstrom_weapon.stack>=5&(tempest_mael_count>30|buff.awakening_storms.stack=2))
  if S.TempestAbility:IsReady() and (MaelstromStacks == MaxMaelstromStacks or (MaelstromStacks >= 5 and (Shaman.TempestMaelstrom > 30 or Player:BuffStack(S.AwakeningStormsBuff) == 2))) then
    if Cast(S.TempestAbility, nil, Settings.CommonsDS.DisplayStyle.Tempest, not Target:IsInRange(40)) then return "tempest funnel 10"; end
  end
  -- lightning_bolt,if=variable.flame_shock_saturated&buff.primordial_wave.up&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
  if S.LightningBolt:IsCastable() and (VarFlameShockSaturated and Player:BuffUp(S.PrimordialWaveBuff) and MaelstromStacks == MaxMaelstromStacks and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 12"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&talent.elemental_spirits.enabled&feral_spirit.active>=4
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalSpirits:IsAvailable() and Shaman.FeralSpiritCount >= 4) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 14"; end
  end
  -- lightning_bolt,if=talent.supercharge.enabled&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (S.Supercharge:IsAvailable() and MaelstromStacks == MaxMaelstromStacks and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 16"; end
  end
  -- chain_lightning,if=(talent.supercharge.enabled&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack)|buff.arc_discharge.up&buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsCastable() and ((S.Supercharge:IsAvailable() and MaelstromStacks == MaxMaelstromStacks) or Player:BuffUp(S.ArcDischargeBuff) and MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 18"; end
  end
  -- lava_lash,if=(talent.molten_assault.enabled&dot.flame_shock.ticking&!variable.flame_shock_saturated)|(talent.ashen_catalyst.enabled&buff.ashen_catalyst.stack=buff.ashen_catalyst.max_stack)
  if S.LavaLash:IsReady() and ((S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) and not VarFlameShockSaturated) or (S.AshenCatalyst:IsAvailable() and Player:BuffStack(S.AshenCatalystBuff) == MaxAshenCatalystStacks)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash funnel 20"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, EnemiesMelee, "min", EvaluateTargetIfFilterPrimordialWave, nil, not Target:IsInRange(45), nil, Settings.CommonsDS.DisplayStyle.PrimordialWave) then return "primordial_wave funnel 22"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 24"; end
  end
  -- feral_spirit
  if S.FeralSpirit:IsCastable() then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit funnel 26"; end
  end
  -- doom_winds
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds funnel 28"; end
  end
  -- stormstrike,if=buff.converging_storms.stack=buff.converging_storms.max_stack
  if S.Stormstrike:IsReady() and (Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 30"; end
  end
  -- lava_burst,if=(buff.molten_weapon.stack>buff.crackling_surge.stack)&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.LavaBurst:IsReady() and ((Shaman.MoltenWeaponStacks > Shaman.CracklingSurgeStacks) and MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst funnel 32"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (MaelstromStacks == MaxMaelstromStacks and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 34"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ChainLightning:IsCastable() and (MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 36"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)|(talent.converging_storms.enabled&buff.converging_storms.stack<buff.converging_storms.max_stack)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0) or (S.ConvergingStorms:IsAvailable() and Player:BuffStack(S.ConvergingStormsBuff) < MaxConvergingStormsStacks)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 38"; end
  end
  -- sundering,if=buff.doom_winds.up|talent.earthsurge.enabled
  if S.Sundering:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or S.Earthsurge:IsAvailable()) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering funnel 40"; end
  end
  -- fire_nova,if=variable.flame_shock_saturated&active_enemies>=4
  if S.FireNova:IsReady() and (VarFlameShockSaturated and EnemiesMeleeCount >= 4) then
    if Cast(S.FireNova) then return "fire_nova funnel 42"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike funnel 44"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock funnel 46"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering funnel 48"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 50"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() < EnemiesMeleeCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastTargetIf(S.FlameShock, EnemiesMelee, "min", EvaluateTargetIfFilterFlameShock, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 52"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova funnel 54"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&talent.deeply_rooted_elements.enabled
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and S.DeeplyRootedElements:IsAvailable()) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 56"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up&active_enemies>=4
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff) and EnemiesMeleeCount >= 4) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 58"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike funnel 60"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 62"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike funnel 64"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash funnel 66"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 68"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova funnel 70"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 72"; end
  end
  -- lava_burst,if=(buff.molten_weapon.stack>buff.crackling_surge.stack)&buff.maelstrom_weapon.stack>=5
  if S.LavaBurst:IsReady() and ((Shaman.MoltenWeaponStacks > Shaman.CracklingSurgeStacks) and MaelstromStacks >= 5) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst funnel 74"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 76"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 78"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 80"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock funnel 82"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  EnemiesMelee = Player:GetEnemiesInMeleeRange(10)
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
    Enemies40yCount = RangedTargetCount(40)
  else
    EnemiesMeleeCount = 1
    Enemies40yCount = 1
  end

  -- Calculate fight_remains
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
    end

    -- Check our Maelstrom Weapon buff stacks
    MaelstromStacks = Player:BuffStack(S.MaelstromWeaponBuff)

    -- Update Searing Totem state
    local _, totemName, _, _, _, _, spellID = GetTotemInfo(1) -- Fire slot
    Shaman.SearingTotemActive = (spellID == 458101 and totemName ~= "")
  end

  -- Update Thorim's Invocation
  if Player:AffectingCombat() then
    if Player:PrevGCD(1, S.ChainLightning) then
      TIAction = S.ChainLightning
    elseif Player:PrevGCD(1, S.LightningBolt) then
      TIAction = S.LightningBolt
    end
  end

 -- Shield Handling
  if Everyone.TargetIsValid() or Player:AffectingCombat() or Settings.Commons.ShieldsOOC then
    local EarthShieldBuff = (S.ElementalOrbit:IsAvailable()) and S.EarthShieldSelfBuff or S.EarthShieldOtherBuff
    if not Settings.Commons.IgnoreEarthShield and ((S.ElementalOrbit:IsAvailable() or Settings.Commons.PreferEarthShield) and S.EarthShield:IsReady() and (Player:BuffDown(EarthShieldBuff) or (not Player:AffectingCombat() and Player:BuffStack(EarthShieldBuff) < 5))) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield shields 2"; end
    elseif (S.ElementalOrbit:IsAvailable() or not Settings.Commons.PreferEarthShield) and S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield shields 4"; end
    end
  end

  -- Weapon Buff Handling
  if Everyone.TargetIsValid() or Player:AffectingCombat() or Settings.Commons.WeaponBuffsOOC then
    -- Check weapon enchants
    HasMainHandEnchant, MHEnchantTimeRemains, _, MHEnchantID, HasOffHandEnchant, OHEnchantTimeRemains, _, OHEnchantID = GetWeaponEnchantInfo()
    -- windfury_weapon
    if (not HasMainHandEnchant or MHEnchantTimeRemains < 600000 or MHEnchantID ~= 5401) and S.WindfuryWeapon:IsCastable() then
      if Cast(S.WindfuryWeapon) then return "windfury_weapon enchants 2"; end
    end
    -- flametongue_weapon
    if (not HasOffHandEnchant or OHEnchantTimeRemains < 600000 or OHEnchantID ~= 5400) and S.FlametongueWeapon:IsCastable() then
      if Cast(S.FlametongueWeapon) then return "flametongue_weapon enchants 4"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Heal based on user setting values. If *EITHER* setting is set to 0, healing suggestions will be disabled.
    if S.HealingSurge:IsReady() and (Settings.Enhancement.HealWith5Maelstrom > 0 and Settings.Enhancement.HealWithout5Maelstrom > 0) and (MaelstromStacks == 5 and Player:HealthPercentage() < Settings.Enhancement.HealWith5Maelstrom or Player:HealthPercentage() < Settings.Enhancement.HealWithout5Maelstrom) then
      if Cast(S.HealingSurge, Settings.Enhancement.GCDasOffGCD.HealingSurge) then return "self healing required"; end
    end
    -- variable,name=min_talented_cd_remains,value=((cooldown.feral_spirit.remains%(4*talent.witch_doctors_ancestry.enabled))+1000*!talent.feral_spirit.enabled)>?(cooldown.doom_winds.remains+1000*!talent.doom_winds.enabled)>?(cooldown.ascendance.remains+1000*!talent.ascendance.enabled)
    VarMinTalentedCDRemains = mathmin(((S.FeralSpirit:CooldownRemains() % (4 * num(S.WitchDoctorsAncestry:IsAvailable()))) + 1000 * num(not S.FeralSpirit:IsAvailable())), (S.DoomWinds:CooldownRemains() + 1000 * num(not S.DoomWinds:IsAvailable())), (S.Ascendance:CooldownRemains() + 1000 * num(not S.Ascendance:IsAvailable())))
    -- variable,name=target_nature_mod,value=(1+debuff.chaos_brand.up*debuff.chaos_brand.value)*(1+(debuff.hunters_mark.up*target.health.pct>=80)*debuff.hunters_mark.value)
    VarTargetNatureMod = (1 + num(Target:DebuffUp(S.ChaosBrandDebuff)) * 0.05) * (1 + num(Target:DebuffUp(S.HuntersMarkDebuff) and Target:HealthPercentage() >= 80) * 0.05)
    -- variable,name=expected_lb_funnel,value=action.lightning_bolt.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(1+buff.primordial_wave.up*active_dot.flame_shock*buff.primordial_wave.value)*debuff.lightning_rod.value)
    VarExpectedLBFunnel = S.LightningBolt:Damage() * (1 + num(Target:DebuffUp(S.LightningRodDebuff)) * VarTargetNatureMod * (1 + num(Player:BuffUp(S.PrimordialWaveBuff)) * S.FlameShockDebuff:AuraActiveCount() * 1.5) * 0.1)
    -- variable,name=expected_cl_funnel,value=action.chain_lightning.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(active_enemies>?(3+2*talent.crashing_storms.enabled))*debuff.lightning_rod.value)
    VarExpectedCLFunnel = S.ChainLightning:Damage() * (1 + num(Target:DebuffUp(S.LightningRodDebuff)) * VarTargetNatureMod * mathmin(EnemiesMeleeCount, 3 + 2 * num(S.CrashingStorms:IsAvailable())) * 0.1)
    -- variable,name=flame_shock_saturated,value=((active_dot.flame_shock=active_enemies)|(active_dot.flame_shock=6))
    VarFlameShockSaturated = S.FlameShockDebuff:AuraActiveCount() == EnemiesMeleeCount or S.FlameShockDebuff:AuraActiveCount() == 6
    -- bloodlust,line_cd=600
    -- Not adding this, as when to use Bloodlust will vary fight to fight
    -- potion,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%300<=30)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or (FightRemains % 300 <= 30) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(S.WindShear, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
      -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(talent.ascendance.enabled&(cooldown.ascendance.remains<2*action.stormstrike.gcd))|(fight_remains%%180<=30)
      -- Note: Skipping these trinkets. They're old DF trinkets that nobody would be using in TWW.
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&((talent.ascendance.enabled&(buff.ascendance.remains>12.5|cooldown.ascendance.remains>fight_remains))|(talent.deeply_rooted_elements.enabled&(buff.ascendance.up|trinket.1.has_use_buff&fight_remains=20)))
      -- Note: Changed 'fight_remains=20' to 'fight_remains<=20', otherwise that condition will only be suggested for one second.
      if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1IsWeird and ((S.Ascendance:IsAvailable() and (Player:BuffRemains(S.AscendanceBuff) > 12.5 or S.Ascendance:CooldownRemains() > FightRemains)) or (S.DeeplyRootedElements:IsAvailable() and (Player:BuffUp(S.AscendanceBuff) or Trinket1:HasUseBuff() and BossFightRemains <= 20)))) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 main 4"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&((talent.ascendance.enabled&(buff.ascendance.remains>12.5|cooldown.ascendance.remains>fight_remains))|(talent.deeply_rooted_elements.enabled&(buff.ascendance.up|trinket.2.has_use_buff&fight_remains=20)))
      -- Note: Changed 'fight_remains=20' to 'fight_remains<=20', otherwise that condition will only be suggested for one second.
      if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2IsWeird and ((S.Ascendance:IsAvailable() and (Player:BuffRemains(S.AscendanceBuff) > 12.5 or S.Ascendance:CooldownRemains() > FightRemains)) or (S.DeeplyRootedElements:IsAvailable() and (Player:BuffUp(S.AscendanceBuff) or Trinket2:HasUseBuff() and BossFightRemains <= 20)))) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 main 6"; end
      end
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&(!talent.ascendance.enabled&!talent.deeply_rooted_elements.enabled)&((trinket.1.has_use_buff&fight_remains<=20)|(buff.splintered_elements.up|buff.doom_winds.up|buff.feral_spirit.up|(!talent.splintered_elements.enabled&!talent.doom_winds.enabled&!talent.feral_spirit.enabled))|(variable.min_talented_cd_remains>=trinket.1.cooldown.duration))
      if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1IsWeird and (not S.Ascendance:IsAvailable() and not S.DeeplyRootedElements:IsAvailable()) and ((Trinket1:HasUseBuff() and BossFightRemains <= 20) or (Player:BuffUp(S.SplinteredElementsBuff) or Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.FeralSpiritBuff) or (not S.SplinteredElements:IsAvailable() and not S.DoomWinds:IsAvailable() and not S.FeralSpirit:IsAvailable())) or (VarMinTalentedCDRemains >= VarTrinket1CD))) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 main 8"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&(!talent.ascendance.enabled&!talent.deeply_rooted_elements.enabled)&((trinket.2.has_use_buff&fight_remains<=20)|(buff.splintered_elements.up|buff.doom_winds.up|buff.feral_spirit.up|(!talent.splintered_elements.enabled&!talent.doom_winds.enabled&!talent.feral_spirit.enabled))|(variable.min_talented_cd_remains>=trinket.2.cooldown.duration))
      if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2IsWeird and (not S.Ascendance:IsAvailable() and not S.DeeplyRootedElements:IsAvailable()) and ((Trinket2:HasUseBuff() and BossFightRemains <= 20) or (Player:BuffUp(S.SplinteredElementsBuff) or Player:BuffUp(S.DoomWindsBuff) or Player:BuffUp(S.FeralSpiritBuff) or (not S.SplinteredElements:IsAvailable() and not S.DoomWinds:IsAvailable() and not S.FeralSpirit:IsAvailable())) or (VarMinTalentedCDRemains >= VarTrinket2CD))) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 main 10"; end
      end
      -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%150<=5)
      -- use_item,name=manic_grieftorch,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%120<=5)
      -- Note: More old DF trinkets.
      -- use_item,name=unyielding_netherprism,use_off_gcd=1,if=(buff.ascendance.remains>7.5)|(fight_remains<=20)
      if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffRemains(S.AscendanceBuff) > 7.5 or BossFightRemains <= 20) then
        if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism main 12"; end
      end
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&!trinket.1.has_use_buff
      if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1IsWeird and not Trinket1:HasUseBuff()) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 main 14"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&!trinket.2.has_use_buff
      if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2IsWeird and not Trinket2:HasUseBuff()) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 main 16"; end
      end
    end
    if (CDsON()) then
      -- blood_fury,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.blood_fury.cooldown<=action.blood_fury.duration)|(variable.min_talented_cd_remains>=action.blood_fury.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.BloodFury:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 15) or (VarMinTalentedCDRemains >= 120) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
        if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.berserking.cooldown<=action.berserking.duration)|(variable.min_talented_cd_remains>=action.berserking.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.Berserking:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 180 <= 12) or (VarMinTalentedCDRemains >= 180) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
        if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- fireblood,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.fireblood.cooldown<=action.fireblood.duration)|(variable.min_talented_cd_remains>=action.fireblood.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.Fireblood:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 8) or (VarMinTalentedCDRemains >= 120) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
        if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.ancestral_call.cooldown<=action.ancestral_call.duration)|(variable.min_talented_cd_remains>=action.ancestral_call.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.AncestralCall:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 15) or (VarMinTalentedCDRemains >= 120) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
        if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=((talent.deeply_rooted_elements.enabled&buff.ascendance.remains>7.5)|(!talent.deeply_rooted_elements.enabled&(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up))|(fight_remains%%120<=20)|(variable.min_talented_cd_remains>=120)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    -- Note: Not handling external PI.
    -- call_action_list,name=single,if=active_enemies=1&!talent.surging_totem.enabled
    if EnemiesMeleeCount < 2 and not S.SurgingTotem:IsAvailable() then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=single_totemic,if=active_enemies=1&talent.surging_totem.enabled
    if EnemiesMeleeCount < 2 and S.SurgingTotem:IsAvailable() then
      local ShouldReturn = SingleTotemic(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1&(rotation.standard|rotation.simple)&!talent.surging_totem.enabled
    -- call_action_list,name=aoe_totemic,if=active_enemies>1&(rotation.standard|rotation.simple)&talent.surging_totem.enabled
    -- call_action_list,name=funnel,if=active_enemies>1&rotation.funnel
    if AoEON() and EnemiesMeleeCount > 1 then
      if Settings.Enhancement.Rotation == "Standard" then
        if not S.SurgingTotem:IsAvailable() then
          local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
        else
          local ShouldReturn = AoeTotemic(); if ShouldReturn then return ShouldReturn; end
        end
      else
        local ShouldReturn = Funnel(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FlameShockDebuff:RegisterAuraTracking()

  HR.Print("Enhancement Shaman rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(263, APL, Init)
