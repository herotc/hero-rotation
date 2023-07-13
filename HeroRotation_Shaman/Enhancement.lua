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
local mathmax        = math.max
local mathmin        = math.min
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

-- Rotation Var
local HasMainHandEnchant, HasOffHandEnchant
local MHEnchantTimeRemains, OHEnchantTimeRemains
local MaelstromStacks
local MaxMaelstromStacks = 10
local MaxAshenCatalystStacks = 8
local VarMinTalentedCDRemains = 1000
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

local function AlphaWolfMinRemains()
  if (not S.AlphaWolf:IsAvailable()) or Player:BuffDown(S.FeralSpiritBuff) then return 0 end
  local AWStart = mathmin(S.CrashLightning:TimeSinceLastCast(), S.ChainLightning:TimeSinceLastCast())
  if AWStart > 8 or AWStart > S.FeralSpirit:TimeSinceLastCast() then return 0 end
  return 8 - AWStart
end

local function EvaluateCycleFlameShock(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.FlameShockDebuff))
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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- Check weapon enchants
  HasMainHandEnchant, MHEnchantTimeRemains, _, _, HasOffHandEnchant, OHEnchantTimeRemains = GetWeaponEnchantInfo()
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
  -- variable,name=trinket1_is_weird,value=trinket.1.is.algethar_puzzle_box|trinket.1.is.manic_grieftorch|trinket.1.is.elementium_pocket_anvil|trinket.1.is.beacon_to_the_beyond
  -- variable,name=trinket2_is_weird,value=trinket.2.is.algethar_puzzle_box|trinket.2.is.manic_grieftorch|trinket.2.is.elementium_pocket_anvil|trinket.2.is.beacon_to_the_beyond
  -- Note: These variables just exclude these three trinkets from the generic use_items. We'll just use HR's OnUseExcludes instead.
  -- variable,name=min_talented_cd_remains,value=((cooldown.feral_spirit.remains%(1+1.5*talent.witch_doctors_ancestry.rank))+1000*!talent.feral_spirit.enabled)<?(cooldown.doom_winds.remains+1000*!talent.doom_winds.enabled)<?(cooldown.ascendance.remains+1000*!talent.ascendance.enabled)
  -- Note: Moved to APL(), as we probably should be checking this during the fight.
  -- snapshot_stats
end

local function Single()
  -- primordial_wave,if=!dot.flame_shock.ticking&talent.lashing_flames.enabled&(raid_event.adds.in>42|raid_event.adds.in<6)
  if S.PrimordialWave:IsReady() and CDsON() and (Target:DebuffUp(S.FlameShockDebuff) and S.LashingFlames:IsAvailable()) then
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
  if S.Sundering:IsReady() and CDsON() and (Player:HasTier(30, 2)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering single 8"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.down&buff.ascendance.up&ti_chain_lightning&(buff.ascendance.remains>(cooldown.strike.remains+gcd))
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.CracklingThunderBuff) and Player:BuffUp(S.AscendanceBuff) and TIAction == S.ChainLightning and (Player:BuffRemains(S.AscendanceBuff) > (S.Windstrike:CooldownRemains() + Player:GCD()))) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 10"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&buff.maelstrom_weapon.stack>=1&(talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up)|(talent.elemental_assault.enabled&talent.stormflurry.enabled)|ti_lightning_bolt)
  if S.Windstrike:IsCastable() and (S.ThorimsInvocation:IsAvailable() and MaelstromStacks >= 1 and (S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) or (S.ElementalAssault:IsAvailable() and S.Stormflurry:IsAvailable()) or TIAction == S.LightningBolt)) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike single 12"; end
  end
  -- stormstrike,if=buff.doom_winds.up|talent.deeply_rooted_elements.enabled|(talent.stormblast.enabled&buff.stormbringer.up)|((talent.elemental_assault.enabled&talent.stormflurry.enabled)&buff.maelstrom_weapon.stack<buff.maelstrom_weapon.max_stack)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or S.DeeplyRootedElements:IsAvailable() or (S.Stormblast:IsAvailable() and Player:BuffUp(S.StormbringerBuff)) or ((S.ElementalAssault:IsAvailable() and S.Stormflurry:IsAvailable()) and MaelstromStacks < MaxMaelstromStacks)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 14"; end
  end
  -- lava_lash,if=buff.hot_hand.up
  if S.LavaLash:IsReady() and (Player:BuffUp(S.HotHandBuff)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash single 16"; end
  end
  -- windfury_totem,if=!buff.windfury_totem.up
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true)) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 18"; end
  end
  -- elemental_blast,if=buff.maelstrom_weapon.stack>=5&charges=max_charges
  if S.ElementalBlast:IsReady() and (MaelstromStacks >= 5 and S.ElementalBlast:Charges() == S.ElementalBlast:MaxCharges()) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast single 20"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.up&raid_event.adds.in>buff.primordial_wave.remains&(!buff.splintered_elements.up|fight_remains<=12)
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffUp(S.PrimordialWaveBuff) and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 22"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5&buff.crackling_thunder.up&talent.elemental_spirits.enabled
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5 and Player:BuffUp(S.CracklingThunderBuff) and S.ElementalSpirits:IsAvailable()) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning single 24"; end
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
    if S.Sundering:IsReady() and CDsON() then
      if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering single 34"; end
    end
  end
  -- crash_lightning,if=buff.doom_winds.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0)) then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 36"; end
  end
  -- primordial_wave,if=raid_event.adds.in>42|raid_event.adds.in<6
  if S.PrimordialWave:IsReady() and CDsON() then
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
  -- ice_strike,if=!buff.ice_strike.up
  if S.IceStrike:IsReady() and (Player:BuffDown(S.IceStrikeBuff)) then
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
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike single 50"; end
  end
  -- windstrike
  if S.Windstrike:IsCastable() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike single 52"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike single 54"; end
  end
  -- sundering,if=raid_event.adds.in>=40
  if S.Sundering:IsReady() and CDsON() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering single 56"; end
  end
  -- bag_of_tricks
  if S.BagofTricks:IsCastable() and CDsON() then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks single 58"; end
  end
  -- fire_nova,if=talent.swirling_maelstrom.enabled&active_dot.flame_shock&buff.maelstrom_weapon.stack<buff.maelstrom_weapon.max_stack
  if S.FireNova:IsReady() and (S.SwirlingMaelstrom:IsAvailable() and S.FlameShockDebuff:AuraActiveCount() > 0 and MaelstromStacks < MaxMaelstromStacks) then
    if Cast(S.FireNova) then return "fire_nova single 60"; end
  end
  -- lightning_bolt,if=talent.hailstorm.enabled&buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (S.Hailstorm:IsAvailable() and MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 62"; end
  end
  -- frost_shock
  if S.FrostShock:IsReady() then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock single 64"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning single 66"; end
  end
  -- fire_nova,if=active_dot.flame_shock
  if S.FireNova:IsReady() and (Target:DebuffUp(S.FlameShockDebuff)) then
    if Cast(S.FireNova) then return "fire_nova single 68"; end
  end
  -- earth_elemental
  if S.EarthElemental:IsCastable() then
    if Cast(S.EarthElemental, Settings.Commons.GCDasOffGCD.EarthElemental) then return "earth_elemental single 70"; end
  end
  -- flame_shock
  if S.FlameShock:IsCastable() then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock single 72"; end
  end
  -- lightning_bolt,if=buff.maelstrom_weapon.stack>=5&buff.primordial_wave.down
  if S.LightningBolt:IsCastable() and (MaelstromStacks >= 5 and Player:BuffDown(S.PrimordialWaveBuff)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt single 74"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem single 76"; end
  end
end

local function Aoe()
  -- crash_lightning,if=talent.crashing_storms.enabled&((talent.unruly_winds.enabled&active_enemies>=10)|active_enemies>=15)
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and ((S.UnrulyWinds:IsAvailable() and Enemies10yCount >= 10) or Enemies10yCount >= 15)) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 2"; end
  end
  -- lightning_bolt,if=(active_dot.flame_shock=active_enemies|active_dot.flame_shock=6)&buff.primordial_wave.up&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!buff.splintered_elements.up|fight_remains<=12|raid_event.adds.remains<=gcd)
  if S.LightningBolt:IsCastable() and ((S.FlameShockDebuff:AuraActiveCount() == Enemies10yCount or S.FlameShockDebuff:AuraActiveCount() >= 6) and Player:BuffUp(S.PrimordialWaveBuff) and MaelstromStacks == MaxMaelstromStacks and (Player:BuffDown(S.SplinteredElementsBuff) or FightRemains <= 12)) then
    if Cast(S.LightningBolt, nil, nil, not Target:IsSpellInRange(S.LightningBolt)) then return "lightning_bolt aoe 4"; end
  end
  -- lava_lash,if=talent.molten_assault.enabled&(talent.primordial_wave.enabled|talent.fire_nova.enabled)&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.LavaLash:IsReady() and (S.MoltenAssault:IsAvailable() and (S.PrimordialWave:IsAvailable() or S.FireNova:IsAvailable()) and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 6"; end
  end
  -- primordial_wave,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=!buff.primordial_wave.up
  if S.PrimordialWave:IsReady() and CDsON() and (Player:BuffDown(S.PrimordialWaveBuff)) then
    if Everyone.CastTargetIf(S.PrimordialWave, Enemies10y, "min", EvaluateTargetIfFilterPrimordialWave, EvaluateTargetIfPrimordialWave, not Target:IsSpellInRange(S.PrimordialWave), nil, Settings.Commons.DisplayStyle.Signature) then return "primordial_wave aoe 8"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and (((not S.ElementalSpirits:IsAvailable()) or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks == MaxMaelstromStacks and ((not S.CrashingStorms) or Enemies10yCount <= 3)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 10"; end
  end
  -- windstrike,if=talent.thorims_invocation.enabled&ti_chain_lightning&buff.maelstrom_weapon.stack>1
  if S.Windstrike:IsReady() and (S.ThorimsInvocation:IsAvailable() and TIAction == S.ChainLightning and MaelstromStacks > 1) then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 12"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack=buff.maelstrom_weapon.max_stack
  if S.ChainLightning:IsReady() and (MaelstromStacks == MaxMaelstromStacks) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 14"; end
  end
  -- crash_lightning,if=buff.doom_winds.up|!buff.crash_lightning.up|(talent.alpha_wolf.enabled&feral_spirit.active&alpha_wolf_min_remains=0)
  if S.CrashLightning:IsReady() and (Player:BuffUp(S.DoomWindsBuff) or Player:BuffDown(S.CrashLightningBuff) or (S.AlphaWolf:IsAvailable() and Player:BuffUp(S.FeralSpiritBuff) and AlphaWolfMinRemains() == 0)) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 16"; end
  end
  -- sundering,if=buff.doom_winds.up|set_bonus.tier30_2pc
  if S.Sundering:IsReady() and CDsON() and (Player:BuffUp(S.DoomWindsBuff) or Player:HasTier(30, 2)) then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering aoe 18"; end
  end
  -- fire_nova,if=active_dot.flame_shock=6|(active_dot.flame_shock>=4&active_dot.flame_shock=active_enemies)
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() == 6 or (S.FlameShockDebuff:AuraActiveCount() >= 4 and S.FlameShockDebuff:AuraActiveCount() >= Enemies10yCount)) then
    if Cast(S.FireNova) then return "fire_nova aoe 20"; end
  end
  -- lava_lash,target_if=min:debuff.lashing_flames.remains,cycle_targets=1,if=talent.lashing_flames.enabled
  if S.LavaLash:IsReady() and (S.LashingFlames:IsAvailable()) then
    if Everyone.CastTargetIf(S.LavaLash, Enemies10y, "min", EvaluateTargetIfFilterLavaLash, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 22"; end
  end
  -- lava_lash,if=(talent.molten_assault.enabled&dot.flame_shock.ticking&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6)|(talent.ashen_catalyst.enabled&buff.ashen_catalyst.stack=buff.ashen_catalyst.max_stack)
  if S.LavaLash:IsReady() and ((S.MoltenAssault:IsAvailable() and Target:DebuffUp(S.FlameShockDebuff) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) or (S.AshenCatalyst:IsAvailable() and Player:BuffStack(S.AshenCatalystBuff) == MaxAshenCatalystStacks)) then
    if Cast(S.LavaLash, nil, nil, not Target:IsSpellInRange(S.LavaLash)) then return "lava_lash aoe 24"; end
  end
  -- ice_strike,if=talent.hailstorm.enabled&!buff.ice_strike.up
  if S.IceStrike:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffDown(S.IceStrikeBuff)) then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike aoe 26"; end
  end
  -- frost_shock,if=talent.hailstorm.enabled&buff.hailstorm.up
  if S.FrostShock:IsReady() and (S.Hailstorm:IsAvailable() and Player:BuffUp(S.HailstormBuff)) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 28"; end
  end
  -- sundering
  if S.Sundering:IsReady() and CDsON() then
    if Cast(S.Sundering, Settings.Enhancement.GCDasOffGCD.Sundering, nil, not Target:IsInRange(11)) then return "sundering aoe 30"; end
  end
  -- flame_shock,if=talent.molten_assault.enabled&!ticking
  if S.FlameShock:IsReady() and (S.MoltenAssault:IsAvailable() and Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 32"; end
  end
  -- flame_shock,target_if=min:dot.flame_shock.remains,cycle_targets=1,if=(talent.fire_nova.enabled|talent.primordial_wave.enabled)&(active_dot.flame_shock<active_enemies)&active_dot.flame_shock<6
  if S.FlameShock:IsReady() and ((S.FireNova:IsAvailable() or S.PrimordialWave:IsAvailable()) and (S.FlameShockDebuff:AuraActiveCount() < Enemies10yCount) and S.FlameShockDebuff:AuraActiveCount() < 6) then
    if Everyone.CastCycle(S.FlameShock, Enemies10y, EvaluateCycleFlameShock, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 34"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=3
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 3) then
    if Cast(S.FireNova) then return "fire_nova aoe 36"; end
  end
  -- stormstrike,if=buff.crash_lightning.up&(talent.deeply_rooted_elements.enabled|buff.converging_storms.stack=6)
  if S.Stormstrike:IsReady() and (Player:BuffUp(S.CrashLightningBuff) and (S.DeeplyRootedElements:IsAvailable() or Player:BuffStack(S.ConvergingStormsBuff) == 6)) then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 38"; end
  end
  -- crash_lightning,if=talent.crashing_storms.enabled&buff.cl_crash_lightning.up&active_enemies>=4
  if S.CrashLightning:IsReady() and (S.CrashingStorms:IsAvailable() and Player:BuffUp(S.CLCrashLightningBuff) and Enemies10yCount >= 4) then
    if Cast(S.CrashLightning, nil, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 40"; end
  end
  -- windstrike
  if S.Windstrike:IsReady() then
    if Cast(S.Windstrike, nil, nil, not Target:IsSpellInRange(S.Windstrike)) then return "windstrike aoe 42"; end
  end
  -- stormstrike
  if S.Stormstrike:IsReady() then
    if Cast(S.Stormstrike, nil, nil, not Target:IsSpellInRange(S.Stormstrike)) then return "stormstrike aoe 44"; end
  end
  -- ice_strike
  if S.IceStrike:IsReady() then
    if Cast(S.IceStrike, nil, nil, not Target:IsInMeleeRange(5)) then return "ice_strike aoe 46"; end
  end
  -- lava_lash
  if S.LavaLash:IsReady() then
    if Cast(S.LavaLash, nil, nil, not Target:IsInMeleeRange(5)) then return "lava_lash aoe 48"; end
  end
  -- crash_lightning
  if S.CrashLightning:IsReady() then
    if Cast(S.CrashLightning, Settings.Enhancement.GCDasOffGCD.CrashLightning, nil, not Target:IsInRange(8)) then return "crash_lightning aoe 50"; end
  end
  -- fire_nova,if=active_dot.flame_shock>=2
  if S.FireNova:IsReady() and (S.FlameShockDebuff:AuraActiveCount() >= 2) then
    if Cast(S.FireNova) then return "fire_nova aoe 52"; end
  end
  -- elemental_blast,if=(!talent.elemental_spirits.enabled|(talent.elemental_spirits.enabled&(charges=max_charges|buff.feral_spirit.up)))&buff.maelstrom_weapon.stack>=5&(!talent.crashing_storms.enabled|active_enemies<=3)
  if S.ElementalBlast:IsReady() and (((not S.ElementalSpirits:IsAvailable()) or (S.ElementalSpirits:IsAvailable() and (S.ElementalBlast:Charges() == MaxEBCharges or Player:BuffUp(S.FeralSpiritBuff)))) and MaelstromStacks >= 5 and ((not S.CrashingStorms:IsAvailable()) or Enemies10yCount <= 3)) then
    if Cast(S.ElementalBlast, nil, nil, not Target:IsSpellInRange(S.ElementalBlast)) then return "elemental_blast aoe 54"; end
  end
  -- chain_lightning,if=buff.maelstrom_weapon.stack>=5
  if S.ChainLightning:IsReady() and (MaelstromStacks >= 5) then
    if Cast(S.ChainLightning, nil, nil, not Target:IsSpellInRange(S.ChainLightning)) then return "chain_lightning aoe 56"; end
  end
  -- windfury_totem,if=buff.windfury_totem.remains<30
  if S.WindfuryTotem:IsReady() and (Player:BuffDown(S.WindfuryTotemBuff, true) or S.WindfuryTotem:TimeSinceLastCast() > 90) then
    if Cast(S.WindfuryTotem, Settings.Enhancement.GCDasOffGCD.WindfuryTotem) then return "windfury_totem aoe 58"; end
  end
  -- flame_shock,if=!ticking
  if S.FlameShock:IsReady() and (Target:DebuffDown(S.FlameShockDebuff)) then
    if Cast(S.FlameShock, nil, nil, not Target:IsSpellInRange(S.FlameShock)) then return "flame_shock aoe 60"; end
  end
  -- frost_shock,if=!talent.hailstorm.enabled
  if S.FrostShock:IsReady() and (not S.Hailstorm:IsAvailable()) then
    if Cast(S.FrostShock, nil, nil, not Target:IsSpellInRange(S.FrostShock)) then return "frost_shock aoe 62"; end
  end
end

--- ======= MAIN =======
local function APL()
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

    -- Check min_talented_cd_remains
    VarMinTalentedCDRemains = mathmin(((S.FeralSpirit:CooldownRemains() / (1 + 1.5 * S.WitchDoctorsAncestry:TalentRank())) + 1000 * num(not S.FeralSpirit:IsAvailable())), (S.DoomWinds:CooldownRemains() + 1000 * num(not S.DoomWinds:IsAvailable())), (S.Ascendance:CooldownRemains() + 1000 * num(not S.Ascendance:IsAvailable())))
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
    -- potion,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%300<=30)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    if Settings.Commons.Enabled.Potions and CDsON() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or (FightRemains % 300 <= 30) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and (not S.DoomWinds:IsAvailable()))) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    -- wind_shear
    local ShouldReturn = Everyone.Interrupt(30, S.WindShear, Settings.Commons.OffGCDasOffGCD.WindShear, false); if ShouldReturn then return ShouldReturn; end
    -- auto_attack
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
      if I.ElementiumPocketAnvil:IsEquippedAndReady() then
        if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(8)) then return "elementium_pocket_anvil main 6"; end
      end
      -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(talent.ascendance.enabled&(cooldown.ascendance.remains<2*action.stormstrike.gcd))|(fight_remains%%180<=30)
      if I.AlgetharPuzzleBox:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (S.Ascendance:IsAvailable() and (S.Ascendance:CooldownRemains() < 2 * S.Stormstrike:ExecuteTime())) or (FightRemains % 180 <= 30)) then
        if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box main 8"; end
      end
      local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
      local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&trinket.1.has_use_buff&(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%trinket.1.cooldown.duration<=trinket.1.buff.any.duration)|(variable.min_talented_cd_remains>=trinket.1.cooldown.duration)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if Trinket1ToUse and (Trinket1ToUse:HasUseBuff() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % Trinket1ToUse:Cooldown() <= Trinket1ToUse:BuffDuration()) or (VarMinTalentedCDRemains >= Trinket1ToUse:Cooldown()) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable()))) then
        if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 main 10"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&trinket.2.has_use_buff&(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%trinket.2.cooldown.duration<=trinket.2.buff.any.duration)|(variable.min_talented_cd_remains>=trinket.2.cooldown.duration)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if Trinket2ToUse and (Trinket2ToUse:HasUseBuff() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % Trinket2ToUse:Cooldown() <= Trinket2ToUse:BuffDuration()) or (VarMinTalentedCDRemains >= Trinket2ToUse:Cooldown()) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable()))) then
        if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 main 12"; end
      end
      -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%150<=5)
      if I.BeacontotheBeyond:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (FightRemains % 150 <= 5)) then
        if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond main 14"; end
      end
      -- use_item,name=manic_grieftorch,use_off_gcd=1,if=(!buff.ascendance.up&!buff.feral_spirit.up&!buff.doom_winds.up)|(fight_remains%%120<=5)
      if I.ManicGrieftorch:IsEquippedAndReady() and ((Player:BuffDown(S.AscendanceBuff) and Player:BuffDown(S.FeralSpiritBuff) and Player:BuffDown(S.DoomWindsBuff)) or (FightRemains % 120 <= 5)) then
        if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "manic_grieftorch main 16"; end
      end
      -- use_item,slot=trinket1,if=!variable.trinket1_is_weird&!trinket.1.has_use_buff
      if Trinket1ToUse and (not Trinket1ToUse:HasUseBuff()) then
        if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 main 18"; end
      end
      -- use_item,slot=trinket2,if=!variable.trinket2_is_weird&!trinket.2.has_use_buff
      if Trinket2ToUse and (not Trinket2ToUse:HasUseBuff()) then
        if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 main 20"; end
      end
    end
    if (CDsON()) then
      -- blood_fury,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.blood_fury.cooldown<=action.blood_fury.duration)|(variable.min_talented_cd_remains>=action.blood_fury.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.BloodFury:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 15) or (VarMinTalentedCDRemains >= 120) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable())) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury racial"; end
      end
      -- berserking,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.berserking.cooldown<=action.berserking.duration)|(variable.min_talented_cd_remains>=action.berserking.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.Berserking:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 180 <= 12) or (VarMinTalentedCDRemains >= 180) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable())) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking racial"; end
      end
      -- fireblood,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.fireblood.cooldown<=action.fireblood.duration)|(variable.min_talented_cd_remains>=action.fireblood.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.Fireblood:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 8) or (VarMinTalentedCDRemains >= 120) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable())) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood racial"; end
      end
      -- ancestral_call,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%action.ancestral_call.cooldown<=action.ancestral_call.duration)|(variable.min_talented_cd_remains>=action.ancestral_call.cooldown)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
      if S.AncestralCall:IsCastable() and (Player:BuffUp(S.AscendanceBuff) or Player:BuffUp(S.FeralSpiritBuff) or Player:BuffUp(S.DoomWindsBuff) or (FightRemains % 120 <= 15) or (VarMinTalentedCDRemains >= 120) or ((not S.Ascendance:IsAvailable()) and (not S.FeralSpirit:IsAvailable()) and not S.DoomWinds:IsAvailable())) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call racial"; end
      end
    end
    -- invoke_external_buff,name=power_infusion,if=(buff.ascendance.up|buff.feral_spirit.up|buff.doom_winds.up|(fight_remains%%120<=20)|(variable.min_talented_cd_remains>=120)|(!talent.ascendance.enabled&!talent.feral_spirit.enabled&!talent.doom_winds.enabled))
    -- Note: Not handling external PI.
    -- feral_spirit
    if S.FeralSpirit:IsCastable() and CDsON() then
      if Cast(S.FeralSpirit, Settings.Enhancement.GCDasOffGCD.FeralSpirit) then return "feral_spirit main 22"; end
    end
    -- ascendance,if=dot.flame_shock.ticking&((ti_lightning_bolt&active_enemies=1&raid_event.adds.in>=90)|(ti_chain_lightning&active_enemies>1))
    if S.Ascendance:IsCastable() and CDsON() and (Target:DebuffUp(S.FlameShockDebuff) and (TIAction == S.LightningBolt and Enemies10yCount == 1 or TIAction == S.ChainLightning and Enemies10yCount > 1)) then
      if Cast(S.Ascendance, Settings.Commons.GCDasOffGCD.Ascendance) then return "ascendance main 24"; end
    end
    -- doom_winds,if=raid_event.adds.in>=90|active_enemies>1
    if S.DoomWinds:IsCastable() and CDsON() then
      if Cast(S.DoomWinds, Settings.Enhancement.GCDasOffGCD.DoomWinds, nil, not Target:IsInMeleeRange(5)) then return "doom_winds main 26"; end
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

  HR.Print("Enhancement Shaman rotation is currently a work in progress, but has been updated for patch 10.1.5.")
end

HR.SetAPL(263, APL, Init)
