--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Target        = Unit.Target
local Pet           = Unit.Pet
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
local CastSuggested = HR.CastSuggested
-- lua
local match      = string.match

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Havoc
local I = Item.DemonHunter.Havoc

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = Item(0)
local trinket2 = Item(0)
if equip[13] then
  trinket1 = Item(equip[13])
end
if equip[14] then
  trinket2 = Item(equip[14])
end

-- Rotation Var
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20
local DarkglareEquipped = Player:HasLegendaryEquipped(20)
local ChaosTheoryEquipped = Player:HasLegendaryEquipped(23)
local BurningWoundEquipped = Player:HasLegendaryEquipped(25)
local AgonyGazeEquipped = Player:HasLegendaryEquipped(236)

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  Havoc = HR.GUISettings.APL.DemonHunter.Havoc
}

-- Interrupts List
local StunInterrupts = {
  {S.FelEruption, "Cast Fel Eruption (Interrupt)", function () return true; end},
  {S.ChaosNova, "Cast Chaos Nova (Interrupt)", function () return true; end},
}

-- Variables
local VarPoolingForMeta = false
local VarBladeDance = false
local VarPoolingForBladeDance = false
local VarPoolingForEyeBeam = false
local VarWaitingForEssenceBreak = false
local VarWaitingForMomentum = false
local VarWaitingForAgonyGaze = false
local VarTrinketSyncSlot = 0
local VarUseEyeBeamFuryCondition = false

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  VarPoolingForMeta = false
  VarBladeDance = false
  VarPoolingForBladeDance = false
  VarPoolingForEyeBeam = false
  VarWaitingForEssenceBreak = false
  VarWaitingForMomentum = false
  VarWaitingForAgonyGaze = false
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = Item(0)
  trinket2 = Item(0)
  if equip[13] then
    trinket1 = Item(equip[13])
  end
  if equip[14] then
    trinket2 = Item(equip[14])
  end
  DarkglareEquipped = Player:HasLegendaryEquipped(20)
  ChaosTheoryEquipped = Player:HasLegendaryEquipped(23)
  BurningWoundEquipped = Player:HasLegendaryEquipped(25)
  AgonyGazeEquipped = Player:HasLegendaryEquipped(236)
end, "PLAYER_EQUIPMENT_CHANGED")

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function IsInMeleeRange(range)
  if S.Felblade:TimeSinceLastCast() <= Player:GCD() then
    return true
  elseif S.VengefulRetreat:TimeSinceLastCast() < 1.0 then
    return false
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

local function ConserveFelRush()
  return not Settings.Havoc.ConserveFelRush or S.FelRush:Charges() == 2
end

local function EvalutateTargetIfFilterDemonsBite202(TargetUnit)
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff)
end

local function EvaluateTargetIfDemonsBite204(TargetUnit)
  return (BurningWoundEquipped and TargetUnit:DebuffRemains(S.BurningWoundDebuff) < 4)
end

local function EvalutateTargetIfFilterDemonsBite206(TargetUnit)
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff)
end

local function EvaluateTargetIfDemonsBite208(TargetUnit)
  return (BurningWoundEquipped and TargetUnit:DebuffRemains(S.BurningWoundDebuff) < 4)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  -- TODO: Find a way to get trinket.x.cooldown.duration
  if (trinket1:TrinketHasStatAnyDps() and not trinket2:TrinketHasStatAnyDps()) then
    VarTrinketSyncSlot = 1
  end
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  -- TODO: Find a way to get trinket.x.cooldown.duration
  if (trinket2:TrinketHasStatAnyDps() and not trinket1:TrinketHasStatAnyDps()) then
    VarTrinketSyncSlot = 2
  end
  -- Manually added: Set VarTrinketSyncSlot to 0 if both or neither trinket have stat buffs
  if ((trinket1:TrinketHasStatAnyDps() and trinket2:TrinketHasStatAnyDps()) or not (trinket1:TrinketHasStatAnyDps() and trinket2:TrinketHasStatAnyDps())) then
    VarTrinketSyncSlot = 0
  end
  -- variable,name=use_eye_beam_fury_condition,value=talent.blind_fury.enabled&(runeforge.darkglare_medallion|talent.demon_blades.enabled&!runeforge.agony_gaze)
  VarUseEyeBeamFuryCondition = (S.BlindFury:IsAvailable() and (DarkglareEquipped or S.DemonBlades:IsAvailable() and not AgonyGazeEquipped))
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 1"; end
  end
  -- Manually added: Fel Rush if out of range
  if not Target:IsInMeleeRange(5) and S.FelRush:IsCastable() then
    if Cast(S.FelRush, nil, nil, not Target:IsInRange(15)) then return "fel_rush precombat 2"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if Target:IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not Target:IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 4"; end
  end
end

local function Cooldown()
  -- metamorphosis,landing_distance=10,if=!talent.demonic.enabled&covenant.venthyr.enabled&runeforge.agony_gaze&dot.sinful_brand.remains>8&spell_targets.metamorphosis_impact<2&(cooldown.eye_beam.remains>20|fight_remains<25)
  -- APL Note: If Venthyr and Sinful Brand duration is over 8 seconds with 1T, purposfully whiff Metamorphosis impact to not refresh with a lower duration DoT
  if S.Metamorphosis:IsCastable() and (not S.Demonic:IsAvailable() and CovenantID == 2 and AgonyGazeEquipped and Target:DebuffRemains(S.SinfulBrandDebuff) > 8 and EnemiesCount8 < 2 and (S.EyeBeam:CooldownRemains() > 20 or HL.BossFilteredFightRemains("<", 25))) then
    if HR.CastAnnotated(S.Metamorphosis, nil, "AWAY") then return "metamorphosis whiff cooldown 0"; end
  end
  -- metamorphosis,landing_distance=10,if=talent.demonic.enabled&covenant.venthyr.enabled&runeforge.agony_gaze&dot.sinful_brand.remains>8&spell_targets.metamorphosis_impact<2&(cooldown.eye_beam.remains>20&!variable.blade_dance|cooldown.blade_dance.remains>gcd.max|fight_remains<25)
  if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and CovenantID == 2 and AgonyGazeEquipped and Target:DebuffRemains(S.SinfulBrandDebuff) > 8 and EnemiesCount8 < 2 and (S.EyeBeam:CooldownRemains() > 20 and (not VarBladeDance) or S.BladeDance:CooldownRemains() > Player:GCD() or HL.BossFilteredFightRemains("<", 25))) then
    if HR.CastAnnotated(S.Metamorphosis, nil, "AWAY") then return "metamorphosis whiff cooldown 1"; end
  end
  -- metamorphosis,if=!talent.demonic.enabled&(cooldown.eye_beam.remains>20&(!covenant.venthyr.enabled|dot.sinful_brand.remains<=8|spell_targets.metamorphosis_impact>1)|fight_remains<25)
  if S.Metamorphosis:IsCastable() and (not S.Demonic:IsAvailable() and (S.EyeBeam:CooldownRemains() > 20 and (CovenantID ~= 2 or Target:DebuffRemains(S.SinfulBrandDebuff) <= 8 or EnemiesCount8 > 1) or HL.BossFilteredFightRemains("<", 25))) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 2"; end
  end
  -- metamorphosis,if=talent.demonic.enabled&(cooldown.eye_beam.remains>20&(!variable.blade_dance|cooldown.blade_dance.remains>gcd.max)&(!covenant.venthyr.enabled|dot.sinful_brand.remains<=8|spell_targets.metamorphosis_impact>1)|fight_remains<25)
  if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and (S.EyeBeam:CooldownRemains() > 20 and ((not VarBladeDance) or S.BladeDance:CooldownRemains() > Player:GCD()) and (CovenantID ~= 2 or Target:DebuffRemains(S.SinfulBrandDebuff) <= 8 or EnemiesCount8 > 1) or HL.BossFilteredFightRemains("<", 25))) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 4"; end
  end
  -- potion,if=buff.metamorphosis.remains>25|fight_remains<60
  if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffRemains(S.MetamorphosisBuff) > 25 or HL.BossFilteredFightRemains("<", 60)) then
    if Cast(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 6"; end
  end
  -- use_items,slots=trinket1,if=variable.trinket_sync_slot=1&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.1.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=2&!trinket.2.cooldown.ready)|!variable.trinket_sync_slot
  -- TODO: Find a way to get trinket.x.cooldown.duration
  if trinket1:IsReady() and (VarTrinketSyncSlot == 1 and (Player:BuffUp(S.MetamorphosisBuff) or (not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemains() > HL.FightRemains(Enemies20y)) or HL.BossFilteredFightRemains("<=", 20)) or (VarTrinketSyncSlot == 2 and not trinket2:IsReady()) or VarTrinketSyncSlot == 0) then
    if Cast(trinket1, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket1 cooldown 8"; end
  end
  -- use_items,slots=trinket2,if=variable.trinket_sync_slot=2&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.2.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=1&!trinket.1.cooldown.ready)|!variable.trinket_sync_slot
  -- TODO: Find a way to get trinket.x.cooldown.duration
  if trinket2:IsReady() and (VarTrinketSyncSlot == 2 and (Player:BuffUp(S.MetamorphosisBuff) or (not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemains() > HL.FightRemains(Enemies20y)) or HL.BossFilteredFightRemains("<=", 20)) or (VarTrinketSyncSlot == 1 and not trinket1:IsReady()) or VarTrinketSyncSlot == 0) then
    if Cast(trinket2, nil, Settings.Commons.DisplayStyle.Trinkets) then return "trinket2 cooldown 10"; end
  end
  -- sinful_brand,if=!dot.sinful_brand.ticking&(!runeforge.agony_gaze|(cooldown.eye_beam.remains<=gcd&fury>=30))&(!cooldown.metamorphosis.up|active_enemies=1)
  if S.SinfulBrand:IsCastable() and (Target:DebuffDown(S.SinfulBrandDebuff) and ((not AgonyGazeEquipped) or (S.EyeBeam:CooldownRemains() <= Player:GCD() and Player:Fury() >= 30)) and (S.Metamorphosis:CooldownDown() or EnemiesCount8 == 1)) then
    if Cast(S.SinfulBrand, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.SinfulBrand)) then return "sinful_brand cooldown 12"; end
  end
  -- the_hunt,if=!talent.demonic.enabled&!variable.waiting_for_momentum&!variable.pooling_for_meta|buff.furious_gaze.up
  if S.TheHunt:IsCastable() and (not S.Demonic:IsAvailable() and not VarWaitingForMomentum and not VarPoolingForMeta or Player:BuffUp(S.FuriousGazeBuff)) then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt cooldown 14"; end
  end
  -- elysian_decree,if=(active_enemies>desired_targets|raid_event.adds.in>30)
  if S.ElysianDecree:IsCastable() and (EnemiesCount8 > 0) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(30)) then return "elysian_decree cooldown 16"; end
  end
end

local function Demonic()
  -- eye_beam,if=runeforge.agony_gaze&(active_enemies>desired_targets|raid_event.adds.in>25-talent.cycle_of_hatred*10)&dot.sinful_brand.ticking&dot.sinful_brand.remains<=gcd
  if S.EyeBeam:IsReady() and (AgonyGazeEquipped and EnemiesCount8 > 1 and Target:DebuffUp(S.SinfulBrandDebuff) and Target:DebuffRemains(S.SinfulBrandDebuff) <= Player:GCD()) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not Target:IsInRange(20)) then return "eye_beam demonic 1"; end
  end
  -- fel_rush,if=talent.unbound_chaos.enabled&buff.unbound_chaos.up&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastable() and (S.UnboundChaos:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and S.FelRush:Charges() == 2) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush demonic 2"; end
  end
  -- death_sweep,if=variable.blade_dance
  if S.DeathSweep:IsReady() and (VarBladeDance) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep demonic 4"; end
  end
  -- glaive_tempest,if=active_enemies>desired_targets|raid_event.adds.in>10
  if S.GlaiveTempest:IsReady() and (EnemiesCount8 > 0) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest, nil, not Target:IsInMeleeRange(8)) then return "glaive_tempest demonic 6"; end
  end
  -- throw_glaive,if=conduit.serrated_glaive.enabled&cooldown.eye_beam.remains<6&!buff.metamorphosis.up&!debuff.exposed_wound.up
  if S.ThrowGlaive:IsCastable() and (S.SerratedGlaive:ConduitEnabled() and S.EyeBeam:CooldownRemains() < 6 and Player:BuffDown(S.MetamorphosisBuff) and Target:DebuffDown(S.ExposedWoundDebuff)) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive demonic 8"; end
  end
  -- eye_beam,if=active_enemies>desired_targets|raid_event.adds.in>25-talent.cycle_of_hatred*10&(!variable.use_eye_beam_fury_condition|spell_targets>1|fury<70)&!variable.waiting_for_agony_gaze
  if S.EyeBeam:IsReady() and (EnemiesCount8 > 0 and (not VarUseEyeBeamFuryCondition or EnemiesCount8 > 1 or Player:Fury() < 70) and not VarWaitingForAgonyGaze) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not Target:IsInRange(20)) then return "eye_beam demonic 10"; end
  end
  -- blade_dance,if=variable.blade_dance&!cooldown.metamorphosis.ready&(cooldown.eye_beam.remains>5|(raid_event.adds.in>cooldown&raid_event.adds.in<25))
  if S.BladeDance:IsReady() and (VarBladeDance and not S.Metamorphosis:CooldownUp() and S.EyeBeam:CooldownRemains() > 5) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance demonic 12"; end
  end
  -- immolation_aura,if=!buff.immolation_aura.up
  if S.ImmolationAura:IsCastable() and (Player:BuffDown(S.ImmolationAuraBuff)) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura demonic 14"; end
  end
  -- annihilation,if=!variable.pooling_for_blade_dance
  if S.Annihilation:IsReady() and (not VarPoolingForBladeDance) then
    if Cast(S.Annihilation, nil, nil, not Target:IsSpellInRange(S.Annihilation)) then return "annihilation demonic 16"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade demonic 18"; end
  end
  -- essence_break
  if S.EssenceBreak:IsCastable() then
    if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break demonic 20"; end
  end
  -- chaos_strike,if=!variable.pooling_for_blade_dance&!variable.pooling_for_eye_beam
  if S.ChaosStrike:IsReady() and ((not VarPoolingForBladeDance) and (not VarPoolingForEyeBeam)) then
    if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike demonic 22"; end
  end
  -- fel_rush,if=talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastable() and (S.DemonBlades:IsAvailable() and not S.EyeBeam:CooldownUp() and ConserveFelRush()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush demonic 24"; end
  end
  -- demons_bite,target_if=min:debuff.burning_wound.remains,if=runeforge.burning_wound&debuff.burning_wound.remains<4
  if S.DemonsBite:IsCastable() then
    if Everyone.CastTargetIf(S.DemonsBite, Enemies8y, "min", EvalutateTargetIfFilterDemonsBite206, EvaluateTargetIfDemonsBite208, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite demonic 26"; end
  end
  -- fel_rush,if=!talent.demon_blades.enabled&spell_targets>1&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastable() and (not S.DemonBlades:IsAvailable() and EnemiesCount8 > 1 and (S.FelRush:Charges() == 2)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush demonic 28"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite demonic 30"; end
  end
  -- throw_glaive,if=buff.out_of_range.up
  if S.ThrowGlaive:IsCastable() and (not IsInMeleeRange()) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive demonic 32"; end
  end
  -- fel_rush,if=movement.distance>15|buff.out_of_range.up
  if S.FelRush:IsCastable() and (not IsInMeleeRange() and ConserveFelRush()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush demonic 34"; end
  end
  -- vengeful_retreat,if=movement.distance>15
  if S.VengefulRetreat:IsCastable() and (not IsInMeleeRange()) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat demonic 36"; end
  end
  -- throw_glaive,if=talent.demon_blades.enabled
  if S.ThrowGlaive:IsCastable() and (S.DemonBlades:IsAvailable()) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive demonic 38"; end
  end
end

local function Normal()
  -- eye_beam,if=runeforge.agony_gaze&(active_enemies>desired_targets|raid_event.adds.in>15)&dot.sinful_brand.ticking&dot.sinful_brand.remains<=gcd
  if S.EyeBeam:IsReady() and (AgonyGazeEquipped and EnemiesCount8 > 1 and Target:DebuffUp(S.SinfulBrandDebuff) and Target:DebuffRemains(S.SinfulBrandDebuff) <= Player:GCD()) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not Target:IsInRange(20)) then return "eye_beam normal 1"; end
  end
  -- vengeful_retreat,if=talent.momentum.enabled&buff.prepared.down&time>1
  if S.VengefulRetreat:IsCastable() and (S.Momentum:IsAvailable() and Player:BuffDown(S.PreparedBuff) and HL.CombatTime() > 1) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat normal 2"; end
  end
  -- fel_rush,if=(buff.unbound_chaos.up|variable.waiting_for_momentum&(!talent.unbound_chaos.enabled|!cooldown.immolation_aura.ready))&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
  if S.FelRush:IsCastable() and ((Player:BuffUp(S.UnboundChaosBuff) or VarWaitingForMomentum and (not S.UnboundChaos:IsAvailable() or not S.ImmolationAura:CooldownUp())) and ConserveFelRush()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush normal 4"; end
  end
  -- fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30
  if S.FelBarrage:IsCastable() and (EnemiesCount8 > 1) then
    if Cast(S.FelBarrage, nil, nil, not IsInMeleeRange(8)) then return "fel_barrage normal 6"; end
  end
  -- death_sweep,if=variable.blade_dance
  if S.DeathSweep:IsReady() and (VarBladeDance) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep normal 8"; end
  end
  -- immolation_aura,if=!buff.immolation_aura.up
  if S.ImmolationAura:IsCastable() and (Player:BuffDown(S.ImmolationAuraBuff)) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura normal 10"; end
  end
  -- glaive_tempest,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReady() and (not VarWaitingForMomentum and EnemiesCount8 > 0) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest normal 12"; end
  end
  -- throw_glaive,if=conduit.serrated_glaive.enabled&cooldown.eye_beam.remains<6&!buff.metamorphosis.up&!debuff.exposed_wound.up
  if S.ThrowGlaive:IsCastable() and (S.SerratedGlaive:ConduitEnabled() and S.EyeBeam:CooldownRemains() < 6 and Player:BuffDown(S.MetamorphosisBuff) and Target:DebuffDown(S.ExposedWoundDebuff)) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive normal 14"; end
  end
  -- eye_beam,if=!variable.waiting_for_momentum&(active_enemies>desired_targets|raid_event.adds.in>15&(!variable.use_eye_beam_fury_condition|spell_targets>1|fury<70)&!variable.waiting_for_agony_gaze)
  if S.EyeBeam:IsReady() and (not VarWaitingForMomentum and (EnemiesCount20 > 0 and (not VarUseEyeBeamFuryCondition or EnemiesCount8 > 1 or Player:Fury() < 70) and not VarWaitingForAgonyGaze)) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam normal 16"; end
  end
  -- blade_dance,if=variable.blade_dance
  if S.BladeDance:IsReady() and (VarBladeDance) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance normal 18"; end
  end
  -- felblade,if=fury.deficit>=40
  if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade normal 20"; end
  end
  -- essence_break
  if S.EssenceBreak:IsCastable() then
    if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break normal 22"; end
  end
  -- annihilation,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
  if S.Annihilation:IsReady() and ((S.DemonBlades:IsAvailable() or not VarWaitingForMomentum or Player:FuryDeficit() < 30 or Player:BuffRemains(S.MetamorphosisBuff) < 5) and not VarPoolingForBladeDance) then
    if Cast(S.Annihilation, nil, nil, not Target:IsSpellInRange(S.Annihilation)) then return "annihilation normal 24"; end
  end
  -- chaos_strike,if=(talent.demon_blades.enabled|!variable.waiting_for_momentum|fury.deficit<30)&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
  if S.ChaosStrike:IsReady() and ((S.DemonBlades:IsAvailable() or not VarWaitingForMomentum or Player:FuryDeficit() < 30) and not VarPoolingForMeta and not VarPoolingForBladeDance) then
    if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike normal 26"; end
  end
  -- eye_beam,if=talent.blind_fury.enabled&raid_event.adds.in>cooldown&!variable.waiting_for_agony_gaze
  if S.EyeBeam:IsReady() and (S.BlindFury:IsAvailable() and not VarWaitingForAgonyGaze) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not Target:IsInRange(20)) then return "eye_beam normal 28"; end
  end
  -- demons_bite,target_if=min:debuff.burning_wound.remains,if=runeforge.burning_wound&debuff.burning_wound.remains<4
  if S.DemonsBite:IsCastable() then
    if Everyone.CastTargetIf(S.DemonsBite, Enemies8y, "min", EvalutateTargetIfFilterDemonsBite202, EvaluateTargetIfDemonsBite204, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite normal 28"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite normal 30"; end
  end
  -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
  if S.FelRush:IsCastable() and (not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() and ConserveFelRush()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush normal 32"; end
  end
  -- felblade,if=movement.distance>15|buff.out_of_range.up
  if S.Felblade:IsCastable() and (not IsInMeleeRange()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade normal 34"; end
  end
  -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
  if S.FelRush:IsCastable() and (not IsInMeleeRange() and not S.Momentum:IsAvailable() and ConserveFelRush()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush normal 36"; end
  end
  -- vengeful_retreat,if=movement.distance>15
  if S.VengefulRetreat:IsCastable() and (not IsInMeleeRange()) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat normal 38"; end
  end
  -- throw_glaive,if=talent.demon_blades.enabled
  if S.ThrowGlaive:IsCastable() and (S.DemonBlades:IsAvailable()) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive normal 40"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  if AoEON() then
    Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Multiple Abilities
    Enemies20y = Player:GetEnemiesInMeleeRange(20) -- Eye Beam
    EnemiesCount8 = #Enemies8y
    EnemiesCount20 = #Enemies20y
  else
    EnemiesCount8 = 1
    EnemiesCount20 = 1
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- auto_attack
    -- variable,name=blade_dance,if=!runeforge.chaos_theory&!runeforge.darkglare_medallion,value=talent.first_blood.enabled|spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)
    if (not ChaosTheoryEquipped and not DarkglareEquipped) then
      VarBladeDance = (S.FirstBlood:IsAvailable() or EnemiesCount8 >= (3 - num(S.TrailofRuin:IsAvailable())))
    end
    -- variable,name=blade_dance,if=runeforge.chaos_theory,value=buff.chaos_theory.down|talent.first_blood.enabled&spell_targets.blade_dance1>=(2-talent.trail_of_ruin.enabled)|!talent.cycle_of_hatred.enabled&spell_targets.blade_dance1>=(4-talent.trail_of_ruin.enabled)
    if (ChaosTheoryEquipped) then
      VarBladeDance = (Player:BuffDown(S.ChaosTheoryBuff) or S.FirstBlood:IsAvailable() and EnemiesCount8 >= (2 - num(S.TrailofRuin:IsAvailable())) or not S.CycleofHatred:IsAvailable() and EnemiesCount8 >= (4 - num(S.TrailofRuin:IsAvailable())))
    end
    -- variable,name=blade_dance,if=runeforge.darkglare_medallion,value=talent.first_blood.enabled|(buff.metamorphosis.up|talent.trail_of_ruin.enabled|debuff.essence_break.up)&spell_targets.blade_dance1>=(3-talent.trail_of_ruin.enabled)|!talent.demonic.enabled&spell_targets.blade_dance1>=4
    if (DarkglareEquipped) then
      VarBladeDance = (S.FirstBlood:IsAvailable() or (Player:BuffUp(S.MetamorphosisBuff) or S.TrailofRuin:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff)) and EnemiesCount8 >= (3 - num(S.TrailofRuin:IsAvailable())) or not S.Demonic:IsAvailable() and EnemiesCount8 >= 4)
    end
    -- variable,name=blade_dance,op=reset,if=talent.essence_break.enabled&cooldown.essence_break.ready
    if (S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownUp()) then
      VarBladeDance = false
    end
    -- variable,name=blade_dance,if=runeforge.agony_gaze&talent.cycle_of_hatred,value=variable.blade_dance&active_dot.sinful_brand<2
    if (AgonyGazeEquipped and S.CycleofHatred:IsAvailable()) then
      VarBladeDance = VarBladeDance and S.SinfulBrandDebuff:AuraActiveCount() < 2
    end
    -- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30
    VarPoolingForMeta = not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemains() < 6 and Player:FuryDeficit() > 30
    -- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
    VarPoolingForBladeDance = VarBladeDance and Player:Fury() < 75 - num(S.FirstBlood:IsAvailable()) * 20
    -- variable,name=pooling_for_eye_beam,value=talent.demonic.enabled&!talent.blind_fury.enabled&cooldown.eye_beam.remains<(gcd.max*2)&fury.deficit>20
    VarPoolingForEyeBeam = S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and S.EyeBeam:CooldownRemains() < (Player:GCD() * 2) and Player:FuryDeficit() > 20
    -- variable,name=waiting_for_momentum,value=talent.momentum.enabled&!buff.momentum.up
    VarWaitingForMomentum = S.Momentum:IsAvailable() and Player:BuffDown(S.MomentumBuff)
    -- variable,name=waiting_for_agony_gaze,if=runeforge.agony_gaze,value=!dot.sinful_brand.ticking&cooldown.sinful_brand.remains<gcd.max*4&(!cooldown.metamorphosis.up|active_enemies=1)&spell_targets.eye_beam<=3
    if (AgonyGazeEquipped) then
      VarWaitingForAgonyGaze = Target:DebuffDown(S.SinfulBrandDebuff) and S.SinfulBrand:CooldownRemains() < Player:GCD() * 4 and (S.Metamorphosis:CooldownDown() or EnemiesCount8 == 1) and EnemiesCount20 <= 3
    end
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldown,if=gcd.remains=0
    if CDsON() then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Defensive Blur
    if S.Blur:IsCastable() and Player:HealthPercentage() <= Settings.Havoc.BlurHealthThreshold then
      if Cast(S.Blur, Settings.Havoc.OffGCDasOffGCD.Blur) then return "Blur defensives (Danger)"; end
    end
    -- pick_up_fragment,type=demon,if=demon_soul_fragments>0
    -- pick_up_fragment,mode=nearest,if=(talent.demonic_appetite.enabled&fury.deficit>=35|runeforge.blind_faith&buff.blind_faith.up)&(!cooldown.eye_beam.ready|fury<30)
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?
    -- throw_glaive,if=buff.fel_bombardment.stack=5&(buff.immolation_aura.up|!buff.metamorphosis.up)
    if S.ThrowGlaive:IsCastable() and (Player:BuffStack(S.FelBombardmentBuff) == 5 and (Player:BuffUp(S.ImmolationAuraBuff) or Player:BuffDown(S.MetamorphosisBuff))) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fel_bombardment"; end
    end
    -- run_action_list,name=demonic,if=talent.demonic.enabled
    if (S.Demonic:IsAvailable()) then
      local ShouldReturn = Demonic(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=normal
    if (true) then
      local ShouldReturn = Normal(); if ShouldReturn then return ShouldReturn; end
    end
    -- Show pool icon if nothing else to do (should only happen when Demon Blades is used)
    if (S.DemonBlades:IsAvailable()) then
      if Cast(S.Pool) then return "pool demon_blades"; end
    end
  end
end

local function Init()
  S.SinfulBrandDebuff:RegisterAuraTracking()
  --HR.Print("Havoc DH rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(577, APL, Init)
