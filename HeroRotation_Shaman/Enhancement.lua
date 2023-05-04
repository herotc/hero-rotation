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
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local max        = math.max
local strmatch   = string.match

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Shaman.Enhancement
local I = Item.Shaman.Enhancement

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.CacheofAcquiredTreasures:ID(),
  I.ScarsofFraternalStrife:ID(),
  I.TheFirstSigil:ID(),
}

-- Rotation Var
local HasMainHandEnchant, HasOffHandEnchant
local MHEnchantTimeRemains, OHEnchantTimeRemains
local MaelstromStacks
local MaxMaelstromStacks = 10
local Enemies10y, Enemies10yCount
local MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
local TIAction = S.LightningBolt
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  MaxEBCharges = S.LavaBurst:IsAvailable() and 2 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  TIAction = S.LightningBolt
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Shaman.Commons,
  Enhancement = HR.GUISettings.APL.Shaman.Enhancement
}

local function TotemFinder()
  for i = 1, 6, 1 do
    if strmatch(Player:TotemName(i), 'Totem') then
      return i
    end
  end
end

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
end

local function EvaluateCycleLavaLash(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.LashingFlamesDebuff))
end

local function EvaluateTargetIfFilterPrimordialWave(TargetUnit)
  return (TargetUnit:DebuffRemains(S.FlameShockDebuff))
end

local function EvaluateTargetIfPrimordialWave(TargetUnit)
  return (Player:BuffDown(S.PrimordialWaveBuff))
end

local function EvaluateTargetIfFilterLavaLash(TargetUnit)
  return (Target:DebuffRemains(S.LashingFlamesDebuff))
end

local function EvaluateTargetIfLavaLash(TargetUnit)
  return (S.LashingFlames:IsAvailable())
end

local function EvaluateTargetIfLavaLash2(TargetUnit)
  return (TargetUnit:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount and S.FlameShockDebuff:AuraActiveCount() < 6))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- windfury_weapon
  if ((not HasMainHandEnchant) or MHEnchantTimeRemains < 600000) and S.WindfuryWeapon:IsCastable() then
    if Cast(S.WindfuryWeapon) then return "windfury_weapon enchant"; end
  end
  -- flametongue_weapon
  if ((not HasOffHandEnchant) or OHEnchantTimeRemains < 600000) and S.FlamentongueWeapon:IsCastable() then
    if Cast(S.FlamentongueWeapon) then return "flametongue_weapon enchant"; end
  end
  -- lightning_shield
  -- Note: Moved to top of APL()
  -- windfury_totem
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem precombat 4"; end
  end
  -- variable,name=trinket1_is_weird,value=trinket.1.is.the_first_sigil|trinket.1.is.scars_of_fraternal_strife|trinket.1.is.cache_of_acquired_treasures
  -- variable,name=trinket2_is_weird,value=trinket.2.is.the_first_sigil|trinket.2.is.scars_of_fraternal_strife|trinket.2.is.cache_of_acquired_treasures
  -- Note: These variables just exclude these three trinkets from the generic use_items. We'll just use HR's OnUseExcludes instead.
  -- snapshot_stats
end

local function Single()
  -- primordial_wave,if=!dot.flame_shock.ticking&talent.lashing_flames.enabled&(raid_event.adds.in>42|raid_event.adds.in<6)
  if S.PrimordialWave:IsReady() and (Target:DebuffUp(S.FlameShockDebuff) and S.LashingFlames:IsAvailable()) then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "primordial_wave single 2"; end
  end
  -- flame_shock,if=!ticking&talent.lashing_flames.enabled
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff) and S.LashingFlames:IsAvailable()) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 4"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&talent.elemental_spirits.enabled&feral_spirit.active>=4
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalSpirits:IsAvailable()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 6"; end
  end
  -- sundering,if=set_bonus.tier30_2pc&raid_event.adds.in>=40
  if S.Sundering:IsReady() and (Player:HasTier(30, 2)) then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 8"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=1&(talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up)|(talent.elemental_assault.enabled&buff.maelstrom_weapon.stack<buff.maelstrom_weapon.max_stack)|ti_lightning_bolt)
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks >= 1 and (S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) or (S.ElementalAssault:IsAvailable() and MaelstromStacks < MaxMaelstromStacks) or TIAction == S.LightningBolt)) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike single 10"; end
  end
  -- stormstrike,if=buff.doom_winds.up|talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up)|(talent.elemental_assault.enabled&buff.maelstrom_weapon.stack<buff.maelstrom_weapon.max_stack)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) or (S.ElementalAssault:IsAvailable() and MaelstromStacks < MaxMaelstromStacks)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 12"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsReady() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 14"; end
  end
  -- windfury_totem,if=!buff.windfury_totem.up
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true)) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 16"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&charges=max_charges
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 18"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains&(!buff.splintered_elements.up|fight_remains<=12)
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 20"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.up
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5 and Player:BuffUp(S.CracklingThunderBuff)) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single 22"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.down&buff.ascendance.up&ti_chain_lightning
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.CracklingThunderBuff) and Player:BuffUp(S.AscendanceBuff) and TIAction == S.ChainLightning) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 24"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&(buff.feral_spirit.up|!talent.elemental_spirits.enabled)
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and (Player:BuffUp(S.FeralSpiritBuff) or not S.ElementalSpirits:IsAvailable())) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 26"; end
  end
  -- lava_burst,if=!talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=5
  if S.LavaBurst:IsReady() and ((not S.ThorimsInvocation:IsAvailable()) and MaelstromStacks >= 5) then
    if Cast(S.LavaBurst, nil, nil, not Target:IsSpellInRange(S.LavaBurst)) then return "lava_burst single 28"; end
  end
  -- lightning_bolt,if=((buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack)|(talent.static_accumulation.enabled&buff.maelstrom_weapon.stack>=5))&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (((MaelstromStacks == MaxMaelstromStacks) or (S.StaticAccumulation:IsAvailable() and MaelstromStacks >= 5)) and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 30"; end
  end
  if Player:BuffUp(S.DoomWindsBuff) then
    -- ice_strike,if=buff.doom_winds.up
    if S.IceStrike:IsReady() then
      if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 32"; end
    end
    -- sundering,if=buff.doom_winds.up&raid_event.adds.in>=40
    if S.Sundering:IsReady() then
      if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 34"; end
    end
    -- crash_lightning,if=buff.doom_winds.up
    if S.CrashLightning:IsReady() then
      if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 36"; end
    end
  end
  -- primordial_wave,if=raid_event.adds.in>42|raid_event.adds.in<6
  if S.PrimordialWave:IsReady() then
    if Cast(S.PrimordialWave, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(40)) then return "primordial_wave single 38"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 40"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&dot.flame_shock.refreshable
  if S.LavaLash:IsCastable() and (S.MoltenAssault:IsAvailable() and Target:DebuffRefreshable(S.FlameShockDebuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 42"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 44"; end
  end
  -- frost_shock,if=buff.hailstorm.up
  if S.FrostShock:IsReady() and (Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 46"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 48"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike single 50"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 52"; end
  end
  -- sundering,if=raid_event.adds.in>=40
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering single 54"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() and CDsON() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks single 56"; end
  end
  -- fire_nova,if=talent.swirling_maelstrom.enabled&active_dot.flame_shock&buff.maelstrom_weapon.stack<buff.maelstrom_weapon.max_stack
  if S.FireNova:IsReady() and (S.SwirlingMaelstrom:IsAvailable() and S.FlameShockDebuff:AuraActiveCount() > 0 and MaelstromStacks < MaxMaelstromStacks) then
    if Cast(S.FireNova) then return "fire_nova single 58"; end
  end
  -- lightning_bolt,if=talent.hailstorm.enabled&buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (S.Hailstorm:IsAvailable() and MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 60"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 62"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 64"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single 66"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 68"; end
  end
  -- flame_shock
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 70"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 72"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 74"; end
  end
end

local function Aoe()
  -- lightning_bolt,if=(active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack>=(5+5*talent.overflowing_maelstrom.enabled)&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
  if S.LightningBolt:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() == Enemies10yCount or S.FlameShockDebuff:AuraActiveCount() >= 6) and Player:BuffUp(S.PrimordialWaveBuff) and MaelstromStacks >= (5 + 5 * num(S.OverflowingMaelstrom:IsAvailable())) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 4"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&(talent.primordial_wave.enabled|talent.fire_nova.enabled)&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and (S.PrimordialWave:IsAvailable() or S.FireNova:IsAvailable()) and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe "; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10y, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 12"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=10&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and (((not S.ElementalSpirits:IsAvailable()) or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks == 10 and ((not S.CrashingStorms) or Enemies10yCount <= 3)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 36"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=10
  if S.ChainLightning:IsReady() and (MaelstromStacks == 10) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 38"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff)) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 2"; end
  end
  -- sundering,if=buff.doom_winds.up|set_bonus.tier30_2pc
  if S.Sundering:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:HasTier(30, 2)) then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 8"; end
  end
  -- fire_nova,if=active_dot.flame_shock=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() == 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= Enemies10yCount)) then
    if Cast(S.FireNova) then return "fire_nova aoe 10"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&ti_chain_lightning&buff.maelstrom_weapon.stack>1
  if S.Windstrike:IsReady() and (S.ThorimsInvocation:IsAvailable() and TIAction == S.ChainLightning and MaelstromStacks > 1) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 14"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable()) then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike aoe 22"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, Enemies10y, "min", EvaluateTargetIfFilterLavaLash, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 16"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 24"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 17"; end
  end
  -- sundering
  if S.Sundering:IsReady() then
    if Cast(S.Sundering, nil, nil, not Target:IsInRange(11)) then return "sundering aoe 26"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 18"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastCycle(S.FlameShock, Enemies10y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 20"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=4
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 4) then
    if Cast(S.FireNova) then return "fire_nova aoe 28"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&(talent.deeply_rooted_elements.enabled|buff.converging_storms.stack=6)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and (S.DeeplyRootedElements:IsAvailable() or Player:BuffStack(S.ConvergingStormsBuff) == 6)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 8"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up&active_enemies>=4
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff) and Enemies10yCount >= 4) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsSpellInRange(S.CrashLightning)) then return "crash_lightning aoe "; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 60"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 66"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike aoe 64"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsInMeleeRange(5)) then return "lava_lash aoe 48"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 58"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova aoe 56"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and (((not S.ElementalSpirits:IsAvailable()) or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks >= 5 and ((not S.CrashingStorms:IsAvailable()) or Enemies10yCount <= 3)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 54"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 72"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem aoe 76"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 18"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 70"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Check weapon enchants
  HasMainHandEnchant, MHEnchantTimeRemains, _, _, HasOffHandEnchant, OHEnchantTimeRemains = GetWeaponEnchantInfo()

  -- Unit Update
  if AoEON() then
    Enemies10y = Player:GetEnemiesInMeleeRange(10)
    Enemies10yCount = #Enemies10y
  else
    Enemies10y = {}
    Enemies10yCount = 1
  end

  -- Calculate fight_remains
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10y, false)
    end

    -- Check our Maelstrom Weapon buff stacks
    MaelstromStacks = Player:BuffStack(S.MaelstromWeaponBuff)
  end

  -- Update Thorim's Invocation
  if Player:AffectingCombat() and Player:BuffUp(S.AscendanceBuff) then
    if Player:PrevGCD(1, S.ChainLightning) then
      TIAction = S.ChainLightning
    elseif Player:PrevGCD(1, S.LightningBolt) then
      TIAction = S.LightningBolt
    end
  end

  if Everyone.TargetIsValid() then
    -- Moved from Precombat: lightning_shield
    -- Manually added: earth_shield if available and PreferEarthShield setting is true
    if Settings.Enhancement.PreferEarthShield and S.EarthShield:IsReady() and (Player:BuffDown(S.EarthShield) or (not Player:AffectingCombat() and Player:BuffStack(S.EarthShield) < 5)) then
      if Cast(S.EarthShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "earth_shield main 2"; end
    elseif S.LightningShield:IsReady() and Player:BuffDown(S.LightningShield) and (Settings.Enhancement.PreferEarthShield and Player:BuffDown(S.EarthShield) or not Settings.Enhancement.PreferEarthShield) then
      if Cast(S.LightningShield, Settings.Enhancement.GCDasOffGCD.Shield) then return "lightning_shield main 2"; end
    end
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
    -- potion,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.doom_winds.enabled&buff.doom_winds.up)|(!talent.doom_winds.enabled&!talent.ascendance.enabled&talent.feral_spirit.enabled&buff.feral_spirit.up)|(!talent.doom_winds.enabled&!talent.ascendance.enabled&!talent.feral_spirit.enabled)|active_enemies>1|fight_remains<30
    if Settings.Commons.Enabled.Potions and ((S.Ascendance:IsAvailable() and Enemies10yCount == 1 and S.Ascendance:CooldownRemains() < 10) or (S.DoomWinds:IsAvailable() and Player:BuffUp(S.DoomWindsBuff)) or ((not S.DoomWinds:IsAvailable()) and (not S.Ascendance:IsAvailable()) and S.FeralSpirit:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff)) or ((not S.DoomWinds:IsAvailable()) and (not S.Ascendance:IsAvailable()) and not S.FeralSpirit:IsAvailable()) or Enemies10yCount > 1 or FightRemains < 30) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    if (Settings.Commons.Enabled.Trinkets) then
      -- use_item,name=the_first_sigil,if=(talent.ascendance.enabled&raid_event.adds.in>=90&cooldown.ascendance.remains<10)|(talent.hot_hand.enabled&buff.molten_weapon.up)|buff.icy_edge.up|(talent.stormflurry.enabled&buff.crackling_surge.up)|active_enemies>1|fight_remains<30
      if I.TheFirstSigil:IsEquippedAndReady() and ((S.Ascendance:IsAvailable() and S.Ascendance:CooldownRemains() < 10) or (S.HotHand:IsAvailable() and Player:BuffUp(S.MoltenWeaponBuff)) or Player:BuffUp(S.IcyEdgeBuff) or (S.Stormflurry:IsAvailable() and Player:BuffUp(S.CracklingSurgeBuff)) or Enemies10yCount > 1 or FightRemains < 30) then
        if Cast(I.TheFirstSigil, nil, Settings.Commons.DisplayStyle.Trinkets) then return "the_first_sigil main 6"; end
      end
      -- use_item,name=cache_of_acquired_treasures,if=buff.acquired_sword.up|fight_remains<25
      if I.CacheofAcquiredTreasures:IsEquippedAndReady() and (Player:BuffUp(S.AcquiredSwordBuff) or FightRemains < 25) then
        if Cast(I.CacheofAcquiredTreasures, nil, Settings.Commons.DisplayStyle.Trinkets) then return "cache_of_acquired_treasures main 8"; end
      end
      -- use_item,name=scars_of_fraternal_strife,if=!buff.scars_of_fraternal_strife_4.up|fight_remains<31|raid_event.adds.in<16|active_enemies>1
      if I.ScarsofFraternalStrife:IsEquippedAndReady() and (Player:BuffDown(S.ScarsofFraternalStrifeBuff4) or FightRemains < 31 or Enemies10yCount > 1) then
        if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife main 10"; end
      end
      -- use_items,slots=trinket1,if=!variable.trinket1_is_weird
      -- use_items,slots=trinket2,if=!variable.trinket2_is_weird
      -- Note: These variables just exclude the above three trinkets from the generic use_items. We'll just use HR's OnUseExcludes instead.
      -- use_items
      local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
      if TrinketToUse then
        if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
      end
    end
    if (CDsON()) then
      -- blood_fury,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.BloodFury:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=!talent.ascendance.enabled|buff.ascendance.up
      if S.Berserking:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- fireblood,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.Fireblood:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call,if=!talent.ascendance.enabled|buff.ascendance.up|cooldown.ascendance.remains>50
      if S.AncestralCall:IsCastable() and (not S.Ascendance:IsAvailable() or Player:BuffUp(S.AscendanceBuff) or S.Ascendance:CooldownRemains() > 50) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=(talent.ascendance.enabled&talent.thorims_invocation.enabled&buff.ascendance.up)|(!talent.thorims_invocation.enabled&talent.feral_spirit.enabled&buff.feral_spirit.up)|(!talent.thorims_invocation.enabled&!talent.feral_spirit.enabled)|fight_remains<=20
    -- Note: Not handling external PI.
    -- feral_spirit
    if S.FeralSpirit:IsCastable() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit main 12"; end
    end
    -- ascendance,if=dot.flame_shock.ticking&((ti_lightning_bolt&active_enemies=1&raid_event.adds.in>=90)|(ti_chain_lightning&active_enemies>1))
    if S.Ascendance:IsCastable() and CDsON() and (Target:DebuffUp(S.FlameShockDebuff) and (TIAction == S.LightningBolt and Enemies10yCount == 1 or TIAction == S.ChainLightning and Enemies10yCount > 1)) then
      if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance main 14"; end
    end
    -- doom_winds,if=raid_event.adds.in>=90|active_enemies>1
    if S.DoomWinds:IsCastable() and CDsON() then
      if Cast(S.DoomWinds, nil, nil, not Target:IsInMeleeRange(5)) then return "doom_winds main 16"; end
    end
    -- call_action_list,name=single,if=active_enemies=1
    if Enemies10yCount == 1 then
      local ShouldReturn = Single(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>1
    if AoEON() and Enemies10yCount > 1 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
    end
    -- If nothing else to do, show the Pool icon
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.FlameShockDebuff:RegisterAuraTracking()

  HR.Print("Enhancement Shaman rotation is currently a work in progress, but has been updated for patch 10.1.0.")
end

HR.SetAPL(263, APL, Init)
