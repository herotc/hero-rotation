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
local mathmax    = math.max
local mathmin    = math.min
local strmatch   = string.match

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.ElementiumPocketAnvil:ID(),
  I.ManicGrieftorch:ID(),
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
local VarMinTalentedCDRemains = 1000
local VarTargetNatureMod, VarExpectedLBFunnel, VarExpectedCLFunnel
local EnemiesMelee, EnemiesMeleeCount, Enemies40yCount
local MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
local TIAction = S.LightningBolt
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1IsWeird, VarTrinket2IsWeird
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

  -- If we don't have trinket items, try again in 2 seconds.
  if VarTrinketFailures < 5 and (T1.ID == 0 or T2.ID == 0) then
    VarTrinketFailures = VarTrinketFailures + 1
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  VarTrinket1IsWeird = T1.ID == I.AlgetharPuzzleBox:ID() or T1.ID == I.ManicGrieftorch:ID() or T1.ID == I.ElementiumPocketAnvil:ID() or T1.ID == I.BeacontotheBeyond:ID()
  VarTrinket2IsWeird = T2.ID == I.AlgetharPuzzleBox:ID() or T2.ID == I.ManicGrieftorch:ID() or T2.ID == I.ElementiumPocketAnvil:ID() or T2.ID == I.BeacontotheBeyond:ID()
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
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

local function TotemFinder(Totem)
  for i = 1, 6, 1 do
    local _, TotemName = Player:GetTotemInfo(i)
    if Totem:Name() == TotemName then
      return true
    end
  end
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

local function EvaluateTargetIfFilterLavaLash(TargetUnit)
  return TargetUnit:DebuffRemains(S.LashingFlamesDebuff)
end

--- ===== CastCycle Functions =====
local function EvaluateCycleFlameShock(TargetUnit)
  return TargetUnit:DebuffRefreshable(S.FlameShockDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- windfury_weapon
  -- flametongue_weapon
  -- lightning_shield
  -- Note: Moved shields and weapon buffs to APL().
  -- windfury_totem
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem precombat 2"; end
  end
  -- variable,name=trinket1_is_weird,value=trinket.1.is.algethar_puzzle_box|trinket.1.is.manic_grieftorch|trinket.1.is.elementium_pocket_anvil|trinket.1.is.beacon_to_the_beyond
  -- variable,name=trinket2_is_weird,value=trinket.2.is.algethar_puzzle_box|trinket.2.is.manic_grieftorch|trinket.2.is.elementium_pocket_anvil|trinket.2.is.beacon_to_the_beyond
  -- Note: Handled in trinket definitions.
  -- variable,name=min_talented_cd_remains,value=((cooldown.feral_spirit.remains%(4*talent.witch_doctors_ancestry.enabled))+1000*!talent.feral_spirit.enabled)>?(cooldown.doom_winds.remains+1000*!talent.doom_winds.enabled)>?(cooldown.ascendance.remains+1000*!talent.ascendance.enabled)
  -- variable,name=target_nature_mod,value=(1+debuff.chaos_brand.up*0.03)*(1+(debuff.hunters_mark.up*target.health.pct>=80)*0.05)
  -- variable,name=expected_lb_funnel,value=action.lightning_bolt.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(1+buff.primordial_wave.up*active_dot.flame_shock*buff.primordial_wave.value)*debuff.lightning_rod.value)
  -- variable,name=expected_cl_funnel,value=action.chain_lightning.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(active_enemies>?(3+2*talent.crashing_storms.enabled))*debuff.lightning_rod.value)
  -- Note: Moved to APL(), as we probably should be checking this during the fight.
  -- snapshot_stats
  -- Manually added openers:
  -- primordial_wave
  if S.PrimordialWave:IsReady() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave precombat 4"; end
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

local function Single()
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>1&ti_lightning_bolt&!talent.elemental_spirits.enabled
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 1 and TIAction == S.LightningBolt and not S.ElementalSpirits:IsAvailable()) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 2"; end
  end
  -- feral_spirit
  if S.FeralSpirit:IsCastable() then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit single 4"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack|(buff.maelstrom_weapon.stack>=5&(tempest_mael_count>30|buff.awakening_storms.stack=2))
  if S.TempestAbility:IsReady() and (MaelstromStacks == MaxMaelstromStacks or (MaelstromStacks >= 5 and (Shaman.TempestMaelstrom > 30 or Player:BuffStack(S.AwakeningStormsBuff) == 2))) then
    if Cast(S.TempestAbility, nil, nil, not Target:IsInRange(40)) then return "tempest single 6"; end
  end
  -- doom_winds,if=raid_event.adds.in>=action.doom_winds.cooldown
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds single 8"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>1&ti_lightning_bolt
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 1 and TIAction == S.LightningBolt) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 10"; end
  end
  -- sundering,if=buff.ascendance.up&pet.surging_totem.active&talent.earthsurge.enabled
  if S.Sundering:IsReady() and (Player:BuffUp(S.AscendanceBuff) and TotemFinder(S.SurgingTotem) and S.Earthsurge:IsAvailable()) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single 4"; end
  end
  -- primordial_wave,if=!dot.flame_shock.ticking&talent.lashing_flames.enabled&(raid_event.adds.in>(action.primordial_wave.cooldown%(1+set_bonus.tier31_4pc))|raid_event.adds.in<6)
  if S.PrimordialWave:IsReady() and CDsON() and (Target:DebuffUp(S.FlameShockDebuff) and S.LashingFlames:IsAvailable()) then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single 6"; end
  end
  -- flame_shock,if=!ticking&talent.lashing_flames.enabled
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff) and S.LashingFlames:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 8"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&talent.elemental_spirits.enabled&feral_spirit.active>=4
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalSpirits:IsAvailable() and Shaman.FeralSpiritCount >= 4) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 10"; end
  end
  -- lightning_bolt,if=talent.supercharge.enabled&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.LightningBolt:IsCastable() and (S.Supercharge:IsAvailable() and MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 12"; end
  end
  -- sundering,if=set_bonus.tier30_2pc&raid_event.adds.in>=action.sundering.cooldown
  if S.Sundering:IsReady() and (Player:HasTier(30, 2)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single 14"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.down&buff.ascendance.up&ti_chain_lightning&(buff.ascendance.remains>(cooldown.strike.remains+gcd))
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.CracklingThunderBuff) and Player:BuffUp(S.AscendanceBuff) and TIAction == S.ChainLightning and (Player:BuffRemains(S.AscendanceBuff) > (S.Windstrike:CooldownRemains() + Player:GCD()))) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 16"; end
  end
  -- stormstrike,if=!talent.elemental_spirits.enabled&(buff.doom_winds.up|talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up))
  if S.Stormstrike:IsReady() and (not S.ElementalSpirits:IsAvailable() and (Player:BuffUp(S.DoomWindsBuff) or S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)))) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 18"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsReady() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 20"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&charges=max_charges
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 22"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack>=8
  if S.TempestAbility:IsReady() and (MaelstromStacks >= 8) then
    if Cast(S.TempestAbility, nil, nil, not Target:IsInRange(40)) then return "tempest single 24"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=8&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains&(!buff.splintered_elements.up|fight_remains<=12)
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 8 and Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 26"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=8&buff.crackling_thunder.up&talent.elemental_spirits.enabled
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 8 and Player:BuffUp(S.CracklingThunderBuff) and S.ElementalSpirits:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single 28"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=8&(feral_spirit.active>=2|!talent.elemental_spirits.enabled)
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 8 and (Shaman.FeralSpiritCount >= 2 or not S.ElementalSpirits:IsAvailable())) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 30"; end
  end
  -- lava_burst,if=!talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=5
  if S.LavaBurst:IsReady() and (not S.ThorimsInvocation:IsAvailable() and MaelstromStacks >= 5) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 32"; end
  end
  -- lightning_bolt,if=((buff.maelstrom_weapon.stack>=8)|(talent.static_accumulation.enabled&buff.maelstrom_weapon.stack>=5))&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (((MaelstromStacks >= 8) or (S.StaticAccumulation:IsAvailable() and MaelstromStacks >= 5)) and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 34"; end
  end
  -- crash_lightning,if=talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0
  if S.CrashLightning:IsReady() and (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 36"; end
  end
  -- primordial_wave,if=raid_event.adds.in>(action.primordial_wave.cooldown%(1+set_bonus.tier31_4pc))|raid_event.adds.in<6
  if S.PrimordialWave:IsReady() and CDsON() then
    if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave single 38"; end
  end
  -- stormstrike,if=talent.elemental_spirits.enabled&(buff.doom_winds.up|talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up))
  if S.Stormstrike:IsReady() and (S.ElementalSpirits:IsAvailable() and (Player:BuffUp(S.DoomWindsBuff) or S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)))) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 40"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 42"; end
  end
  -- windstrike,if=(talent.totemic_rebound.enabled&(time-(action.stormstrike.last_used<?action.windstrike.last_used))>=3.5)|(talent.awakening_storms.enabled&(time-(action.stormstrike.last_used<?action.windstrike.last_used<?action.lightning_bolt.last_used<?action.tempest.last_used<?action.chain_lightning.last_used))>=3.5)
  -- stormstrike,if=(talent.totemic_rebound.enabled&(time-(action.stormstrike.last_used<?action.windstrike.last_used))>=3.5)|(talent.awakening_storms.enabled&(time-(action.stormstrike.last_used<?action.windstrike.last_used<?action.lightning_bolt.last_used<?action.tempest.last_used<?action.chain_lightning.last_used))>=3.5)
  -- Note: These two lines have the same if condition.
  if (S.TotemicRebound:IsAvailable() and mathmin(S.Stormstrike:TimeSinceLastCast(), S.Windstrike:TimeSinceLastCast()) >= 3.5) or (S.AwakeningStorms:IsAvailable() and mathmin(S.Stormstrike:TimeSinceLastCast(), S.Windstrike:TimeSinceLastCast(), S.LightningBolt:TimeSinceLastCast(), S.TempestAbility:TimeSinceLastCast(), S.ChainLightning:TimeSinceLastCast()) >= 3.5) then
    if S.Windstrike:IsCastable() then
      if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 44"; end
    end
    if S.Stormstrike:IsReady() then
      if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 46"; end
    end
  end
  -- lava_lash,if=talent.lively_totems.enabled&(time-action.lava_lash.last_used>=3.5)
  if S.LavaLash:IsCastable() and (S.LivelyTotems:IsAvailable() and S.LavaLash:TimeSinceLastCast() >= 3.5) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 48"; end
  end
  -- ice_strike,if=talent.elemental_assault.enabled&talent.swirling_maelstrom.enabled
  if S.IceStrike:IsReady() and (S.ElementalAssault:IsAvailable() and S.SwirlingMaelstrom:IsAvailable()) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 50"; end
  end
  -- lava_lash,if=talent.lashing_flames.enabled
  if S.LavaLash:IsCastable() and (S.LashingFlames:IsAvailable()) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 52"; end
  end
  -- ice_strike,if=!buff.ice_strike.up
  if S.IceStrike:IsReady() and (Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 54"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 56"; end
  end
  -- crash_lightning,if=talent.converging_storms.enabled
  if S.CrashLightning:IsReady() and (S.ConvergingStorms:IsAvailable()) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 58"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 60"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike single 62"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike single 64"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 66"; end
  end
  -- sundering,if=raid_event.adds.in>=action.sundering.cooldown
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering single 68"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack>=5
  if S.TempestAbility:IsReady() and (MaelstromStacks >= 5) then
    if Cast(S.TempestAbility, nil, nil, not Target:IsInRange(40)) then return "tempest single 72"; end
  end
  -- lightning_bolt,if=talent.hailstorm.enabled&buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (S.Hailstorm:IsAvailable() and MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 74"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 76"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning single 78"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single 80"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.CommonsOGCD.GCDasOffGCD.EarthElemental) then return "earth_elemental single 82"; end
  end
  -- flame_shock
  if S.FlameShock:IsReady() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 84"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.up&talent.elemental_spirits.enabled
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5 and Player:BuffUp(S.CracklingThunderBuff) and S.ElementalSpirits:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single 86"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 88"; end
  end
end

local function Aoe()
  -- tempest,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack|(buff.maelstrom_weapon.stack>=5&(tempest_mael_count>30|buff.awakening_storms.stack=2))
  if S.TempestAbility:IsReady() and (MaelstromStacks == MaxMaelstromStacks or (MaelstromStacks >= 5 and (Shaman.TempestMaelstrom > 30 or Player:BuffStack(S.AwakeningStormsBuff) == 2))) then
    if Everyone.CastTargetIf(S.TempestAbility, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(40)) then return "tempest aoe 2"; end
  end
  -- windstrike,target_if=min:debuff.lightning_rod.remains,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>1&ti_chain_lightning
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 1 and TIAction == S.ChainLightning) then
    if Everyone.CastTargetIf(S.Windstrike, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsInRange(30)) then return "windstrike aoe 4"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&((talent.unruly_winds.enabled&active_enemies>=10)|active_enemies>=15)
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and ((S.UnrulyWinds:IsAvailable() and EnemiesMeleeCount >= 10) or EnemiesMeleeCount >= 15)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 6"; end
  end
  -- lightning_bolt,target_if=min:debuff.lightning_rod.remains,if=(!talent.tempest.enabled|(tempest_mael_count<=10&buff.awakening_storms.stack<=1))&((active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd))
  if S.LightningBolt:IsCastable() and ((not S.Tempest:IsAvailable() or (Shaman.TempestMaelstrom <= 10 and Player:BuffStack(S.AwakeningStormsBuff) <= 1)) and ((S.FlameShockDebuff:AuraActiveCount() == EnemiesMeleeCount or S.FlameShockDebuff:AuraActiveCount() >= 6) and Player:BuffUp(S.PrimordialWaveBuff) and MaelstromStacks == MaxMaelstromStacks and (Player:BuffDown(S.SplinteredElementsBuff) or BossFightRemains <= 12))) then
    if Everyone.CastTargetIf(S.LightningBolt, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 8"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&(talent.primordial_wave.enabled|talent.fire_nova.enabled)&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and (S.PrimordialWave:IsAvailable() or S.FireNova:IsAvailable()) and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < EnemiesMeleeCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 10"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and CDsON() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, EnemiesMelee, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, nil, not Target:IsSpellInRange(S.PrimordialWave), Settings.CommonsDS.DisplayStyle.Signature) then return "primordial_wave aoe 12"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.arc_discharge.up&buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (Player:BuffUp(S.ArcDischargeBuff) and MaelstromStacks >= 5) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 14"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|feral_spirit.active>=2)))&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Shaman.FeralSpiritCount >= 2))) and MaelstromStacks == MaxMaelstromStacks and (not S.CrashingStorms:IsAvailable() or EnemiesMeleeCount <= 3)) then
    if Everyone.CastTargetIf(S.ElementalBlast, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 16"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ChainLightning:IsReady() and (MaelstromStacks == MaxMaelstromStacks) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 18"; end
  end
  -- feral_spirit
  if S.FeralSpirit:IsCastable() then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit aoe 20"; end
  end
  -- doom_winds
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds aoe 22"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 24"; end
  end
  -- sundering,if=buff.doom_winds.up|set_bonus.tier30_2pc|talent.earthsurge.enabled
  if S.Sundering:IsReady() and CDsON() and (Player:BuffUp(S.DoomWindsBuff) or Player:HasTier(30, 2) or S.Earthsurge:IsAvailable()) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe 26"; end
  end
  -- fire_nova,if=active_dot.flame_shock=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() == 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= EnemiesMeleeCount)) then
    if Cast(S.FireNova) then return "fire_nova aoe 28"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, EnemiesMelee, "min", EvaluateTargetIfFilterLavaLash, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 30"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&dot.flame_shock.ticking
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 32"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe 34"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 36"; end
  end
  -- sundering
  if S.Sundering:IsReady() and CDsON() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering aoe 38"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 40"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() < EnemiesMeleeCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastCycle(S.FlameShock, EnemiesMelee, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 42"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova aoe 44"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&(talent.deeply_rooted_elements.enabled|buff.converging_storms.stack=buff.converging_storms.max_stack)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and (S.DeeplyRootedElements:IsAvailable() or Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 46"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up&active_enemies>=4
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff) and EnemiesMeleeCount >= 4) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 48"; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike aoe 50"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 52"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike aoe 54"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 56"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning aoe 58"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova aoe 60"; end
  end
  -- elemental_blast,target_if=min:debuff.lightning_rod.remains,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|feral_spirit.active>=2)))&buff.maelstrom_weapon.stack>=5&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Shaman.FeralSpiritCount >= 2))) and MaelstromStacks >= 5 and (not S.CrashingStorms:IsAvailable() or EnemiesMeleeCount <= 3)) then
    if Everyone.CastTargetIf(S.ElementalBlast, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 62"; end
  end
  -- chain_lightning,target_if=min:debuff.lightning_rod.remains,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5) then
    if Everyone.CastTargetIf(S.ChainLightning, EnemiesMelee, "min", EvaluateTargetIfFilterLightningRodRemains, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 64"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 66"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 68"; end
  end
end

local function Funnel()
  -- ascendance
  if S.Ascendance:IsCastable() and CDsON() then
    if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance funnel 2"; end
  end
  -- windstrike,if=(talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>1)|buff.converging_storms.stack=buff.converging_storms.max_stack
  if S.Windstrike:IsCastable() and ((S.ThorimsInvocation:IsAvailable() and MaelstromStacks > 1) or Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks) then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike funnel 4"; end
  end
  -- tempest,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack|(buff.maelstrom_weapon.stack>=5&(tempest_mael_count>30|buff.awakening_storms.stack=2))
  if S.TempestAbility:IsReady() and (MaelstromStacks == MaxMaelstromStacks or (MaelstromStacks >= 5 and (Shaman.TempestMaelstrom > 30 or Player:BuffStack(S.AwakeningStormsBuff) == 2))) then
    if Cast(S.TempestAbility, nil, nil, not Target:IsInRange(40)) then return "tempest funnel 6"; end
  end
  -- lightning_bolt,if=(active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
  if S.LightningBolt:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() >= EnemiesMeleeCount or S.FlameShockDebuff:AuraActiveCount() >= 6) and Player:BuffUp(S.PrimordialWaveBuff) and MaelstromStacks == MaxMaelstromStacks and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 8"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&talent.elemental_spirits.enabled&feral_spirit.active>=4
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalSpirits:IsAvailable() and Shaman.FeralSpiritCount >= 4) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 10"; end
  end
  -- lightning_bolt,if=talent.supercharge.enabled&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (S.Supercharge:IsAvailable() and MaelstromStacks == MaxMaelstromStacks and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 12"; end
  end
  -- chain_lightning,if=(talent.supercharge.enabled&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack)|buff.arc_discharge.up&buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsCastable() and ((S.Supercharge:IsAvailable() and MaelstromStacks == MaxMaelstromStacks) or Player:BuffUp(S.ArcDischargeBuff) and MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 14"; end
  end
  -- lava_lash,if=(talent.molten_assault.enabled&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6)|(talent.ashen_catalyst.enabled&buff.ashen_catalyst.stack=buff.ashen_catalyst.max_stack)
  if S.LavaLash:IsReady() and ((S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < EnemiesMeleeCount) and S.FlameShockDebuff:AuraActiveCount() < 6) or (S.AshenCatalyst:IsAvailable() and Player:BuffStack(S.AshenCatalystBuff) == MaxAshenCatalystStacks)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash funnel 16"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and CDsON() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, EnemiesMelee, "min", EvaluateTargetIfFilterPrimordialWave, nil, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.CommonsDS.DisplayStyle.PrimordialWave) then return "primordial_wave funnel 18"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 20"; end
  end
  -- feral_spirit
  if S.FeralSpirit:IsCastable() then
    if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit funnel 22"; end
  end
  -- doom_winds
  if S.DoomWinds:IsCastable() then
    if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds funnel 24"; end
  end
  -- stormstrike,if=buff.converging_storms.stack=buff.converging_storms.max_stack
  if S.Stormstrike:IsReady() and (Player:BuffStack(S.ConvergingStormsBuff) == MaxConvergingStormsStacks) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 26"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&buff.crackling_thunder.up
  if S.ChainLightning:IsReady() and (MaelstromStacks == MaxMaelstromStacks and Player:BuffUp(S.CracklingThunderBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 28"; end
  end
  -- lava_burst,if=(buff.molten_weapon.stack+buff.volcanic_strength.up>buff.crackling_surge.stack)&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.LavaBurst:IsReady() and ((Player:BuffStack(S.MoltenWeaponBuff) + num(Player:BuffUp(S.VolcanicStrengthBuff)) > Player:BuffStack(S.CracklingSurgeBuff)) and MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst funnel 30"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (MaelstromStacks == MaxMaelstromStacks and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 32"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ChainLightning:IsCastable() and (MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 34"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)|(talent.converging_storms.enabled&buff.converging_storms.stack<buff.converging_storms.max_stack)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0) or (S.ConvergingStorms:IsAvailable() and Player:BuffStack(S.ConvergingStormsBuff) < MaxConvergingStormsStacks)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 36"; end
  end
  -- sundering,if=buff.doom_winds.up|set_bonus.tier30_2pc|talent.earthsurge.enabled
  if S.Sundering:IsReady() and CDsON() and (Player:BuffUp(S.DoomWindsBuff) or Player:HasTier(30, 2) or S.Earthsurge:IsAvailable()) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering funnel 38"; end
  end
  -- fire_nova,if=active_dot.flame_shock=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= EnemiesMeleeCount)) then
    if Cast(S.FireNova) then return "fire_nova funnel 40"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike funnel 42"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock funnel 44"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInMeleeRange(11)) then return "sundering funnel 46"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 48"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() < EnemiesMeleeCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 50"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova funnel 52"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&talent.deeply_rooted_elements.enabled
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and S.DeeplyRootedElements:IsAvailable()) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 54"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up&active_enemies>=4
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff) and EnemiesMeleeCount >= 4) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 56"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsInRange(30)) then return "windstrike funnel 58"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike funnel 60"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsSpellInRange(S.IceStrike)) then return "ice_strike funnel 62"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash funnel 64"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInMeleeRange(8)) then return "crash_lightning funnel 66"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova funnel 68"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5
  if S.ElementalBlast:IsReady() and ((not S.ElementalSpirits:IsAvailable() or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges() or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks >= 5) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast funnel 70"; end
  end
  -- lava_burst,if=(buff.molten_weapon.stack+buff.volcanic_strength.up>buff.crackling_surge.stack)&buff.maelstrom_weapon.stack>=5
  if S.LavaBurst:IsReady() and ((Player:BuffStack(S.MoltenWeaponBuff) + num(Player:BuffUp(S.VolcanicStrengthBuff)) > Player:BuffStack(S.CracklingSurgeBuff)) and MaelstromStacks >= 5) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst funnel 72"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&(variable.expected_lb_funnel>variable.expected_cl_funnel)
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and (VarExpectedLBFunnel > VarExpectedCLFunnel)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt funnel 74"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning funnel 76"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock funnel 78"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock funnel 80"; end
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

    -- Variables from Precombat
    -- variable,name=min_talented_cd_remains,value=((cooldown.feral_spirit.remains%(4*talent.witch_doctors_ancestry.enabled))+1000*!talent.feral_spirit.enabled)>?(cooldown.doom_winds.remains+1000*!talent.doom_winds.enabled)>?(cooldown.ascendance.remains+1000*!talent.ascendance.enabled)
    VarMinTalentedCDRemains = mathmin(((S.FeralSpirit:CooldownRemains() / (4 * num(S.WitchDoctorsAncestry:IsAvailable()))) + 1000 * num(not S.FeralSpirit:IsAvailable())), (S.DoomWinds:CooldownRemains() + 1000 * num(not S.DoomWinds:IsAvailable())), (S.Ascendance:CooldownRemains() + 1000 * num(not S.Ascendance:IsAvailable())))
    -- variable,name=target_nature_mod,value=(1+debuff.chaos_brand.up*debuff.chaos_brand.value)*(1+(debuff.hunters_mark.up*target.health.pct>=80)*debuff.hunters_mark.value)
    VarTargetNatureMod = (1 + num(Target:DebuffUp(S.ChaosBrandDebuff)) * 0.05) * (1 + num(Target:DebuffUp(S.HuntersMarkDebuff) and Target:HealthPercentage() >= 80) * 0.05)
    -- variable,name=expected_lb_funnel,value=action.lightning_bolt.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(1+buff.primordial_wave.up*active_dot.flame_shock*buff.primordial_wave.value)*debuff.lightning_rod.value)
    local PWValue = 1.75 * S.LightningBolt:Damage()
    local LRValue = 0.2 * S.LightningBolt:Damage() * (Target:DebuffUp(S.LightningRodDebuff) and 1.75 or 1)
    VarExpectedLBFunnel = S.LightningBolt:Damage() * (1 + num(Target:DebuffUp(S.LightningRodDebuff)) * VarTargetNatureMod * (1 + num(Player:BuffUp(S.PrimordialWaveBuff)) * S.FlameShockDebuff:AuraActiveCount() * PWValue) * LRValue)
    -- variable,name=expected_cl_funnel,value=action.chain_lightning.damage*(1+debuff.lightning_rod.up*variable.target_nature_mod*(active_enemies>?(3+2*talent.crashing_storms.enabled))*debuff.lightning_rod.value)
    VarExpectedCLFunnel = S.ChainLightning:Damage() * (1 + num(Target:DebuffUp(S.LightningRodDebuff)) * VarTargetNatureMod * mathmin(EnemiesMeleeCount, 3 + 2 * num(S.CrashingStorms:IsAvailable())) * LRValue)
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
    if (S.ElementalOrbit:IsAvailable() or Settings.Commons.PreferEarthShield) and S.EarthShield:IsReady() and (Player:BuffDown(EarthShieldBuff) or (not Player:AffectingCombat() and Player:BuffStack(EarthShieldBuff) < 5)) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield main 2"; end
    elseif (S.ElementalOrbit:IsAvailable() or not Settings.Commons.PreferEarthShield) and S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield main 3"; end
    end
  end

  -- Weapon Buff Handling
  if Everyone.TargetIsValid() or Player:AffectingCombat() or Settings.Commons.WeaponBuffsOOC then
    -- Check weapon enchants
    HasMainHandEnchant, MHEnchantTimeRemains, _, MHEnchantID, HasOffHandEnchant, OHEnchantTimeRemains, _, OHEnchantID = GetWeaponEnchantInfo()
    -- windfury_weapon
    if (not HasMainHandEnchant or MHEnchantTimeRemains < 600000 or MHEnchantID ~= 5401) and S.WindfuryWeapon:IsCastable() then
      if Cast(S.WindfuryWeapon) then return "windfury_weapon enchant"; end
    end
    -- flametongue_weapon
    if (not HasOffHandEnchant or OHEnchantTimeRemains < 600000 or OHEnchantID ~= 5400) and S.FlametongueWeapon:IsCastable() then
      if Cast(S.FlametongueWeapon) then return "flametongue_weapon enchant"; end
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
    -- bloodlust,line_cd=600
    -- Not adding this, as when to use Bloodlust will vary fight to fight
    -- potion,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%300<=30)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    if Settings.Commons.Enabled.Potions and CDsON() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or (FightRemains % 300 <= 30) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable())) then
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
      if I.ElementiumPocketAnvil:IsEquippedAndReady() then
        if Cast(I.ElementiumPocketAnvil, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(8)) then return "elementium_pocket_anvil main 4"; end
      end
      -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(talent.ascendance.enabled&(cooldown.ascendance.remains<2*action.stormstrike.gcd))|(fight_remains%%180<=30)
      if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (S.Ascendance:IsAvailable() and (S.Ascendance:CooldownRemains() < 2 * S.Stormstrike:ExecuteTime())) or (FightRemains % 180 <= 30)) then
        if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box main 6"; end
      end
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&trinket.1.has_use_buff&(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%trinket.1.cooldown.duration<=trinket.1.buff.any.duration)|(variable.min_talented_cd_remains>=trinket.1.cooldown.duration)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1IsWeird and Trinket1:HasUseBuff() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % VarTrinket1CD <= Trinket1:BuffDuration()) or (VarMinTalentedCDRemains >= VarTrinket1CD) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable()))) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 main 8"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&trinket.2.has_use_buff&(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%trinket.2.cooldown.duration<=trinket.2.buff.any.duration)|(variable.min_talented_cd_remains>=trinket.2.cooldown.duration)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2IsWeird and Trinket2:HasUseBuff() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % VarTrinket2CD <= Trinket2:BuffDuration()) or (VarMinTalentedCDRemains >= VarTrinket2CD) or (not S.Ascendance:IsAvailable() and not S.FeralSpirit:IsAvailable() and not S.DoomWinds:IsAvailable()))) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 main 10"; end
      end
      -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%150<=5)
      if I.BeacontotheBeyond:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (FightRemains % 150 <= 5)) then
        if Cast(I.BeacontotheBeyond, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond main 12"; end
      end
      -- use_item,name=manic_grieftorch,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%120<=5)
      if I.ManicGrieftorch:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (FightRemains % 120 <= 5)) then
        if Cast(I.ManicGrieftorch, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "manic_grieftorch main 14"; end
      end
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&!trinket.1.has_use_buff
      if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1IsWeird and not Trinket1:HasUseBuff()) then
        if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 main 16"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&!trinket.2.has_use_buff
      if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2IsWeird and not Trinket2:HasUseBuff()) then
        if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 main 18"; end
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
    -- invoke_external_buff,name=power_infusion,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%120<=20)|(variable.min_talented_cd_remains>=120)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    -- Note: Not handling external PI.
    -- primordial_wave,if=set_bonus.tier31_2pc&(raid_event.adds.in>(action.primordial_wave.cooldown%(1+set_bonus.tier31_4pc))|raid_event.adds.in<6)
    if S.PrimordialWave:IsReady() and CDsON() and (Player:HasTier(31, 2)) then
      if Cast(S.PrimordialWave, nil, Settings.CommonsDS.DisplayStyle.PrimordialWave, not Target:IsSpellInRange(S.PrimordialWave)) then return "primordial_wave main 22"; end
    end
    -- feral_spirit,if=talent.elemental_spirits.enabled|(talent.alpha_wolf.enabled&active_enemies>1)
    if S.FeralSpirit:IsCastable() and CDsON() and (S.ElementalSpirits:IsAvailable() or (S.AlphaWolf:IsAvailable() and EnemiesMeleeCount > 1)) then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit main 24"; end
    end
    -- surging_totem
    if S.SurgingTotem:IsReady() then
      if Cast(S.SurgingTotem) then return "surging_totem main 26"; end
    end
    -- ascendance,if=dot.flame_shock.ticking&((ti_lightning_bolt&active_enemies=1&raid_event.adds.in>=action.ascendance.cooldown%2)|(ti_chain_lightning&active_enemies>1))
    if S.Ascendance:IsCastable() and CDsON() and (Target:DebuffUp(S.FlameShockDebuff) and (TIAction == S.LightningBolt and EnemiesMeleeCount == 1 or TIAction == S.ChainLightning and EnemiesMeleeCount > 1)) then
      if Cast(S.Ascendance, Settings.CommonsOGCD.GCDasOffGCD.Ascendance) then return "ascendance main 28"; end
    end
    -- call_action_list,name=single,if=active_enemies=1
    if EnemiesMeleeCount == 1 or Enemies40yCount == 1 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1&(rotation.standard|rotation.simple)
    -- call_action_list,name=funnel,if=active_enemies>1&rotation.funnel
    if AoEON() and EnemiesMeleeCount > 1 then
      if Settings.Enhancement.Rotation == "Standard" then
        local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
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

  HR.Print("Enhancement Shaman rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(263, APL, Init)
