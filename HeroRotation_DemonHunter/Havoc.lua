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
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua
local mathmin       = math.min
local mathmax       = math.max

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Havoc
local I = Item.DemonHunter.Havoc

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AlgetharPuzzleBox:ID(),
  I.BeacontotheBeyond:ID(),
  I.DragonfireBombDispenser:ID(),
  I.ElementiumPocketAnvil:ID(),
  I.IrideusFragment:ID(),
  I.ManicGrieftorch:ID(),
  I.StormEatersBoon:ID(),
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Var
local Enemies8y, Enemies20y
local EnemiesCount8, EnemiesCount20

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
local Var3MinTrinket = false
local VarBladeDance = false
local VarPoolingForBladeDance = false
local VarPoolingForEyeBeam = false
local VarWaitingForEssenceBreak = false
local VarWaitingForMomentum = false
local VarHoldingMeta = false
local VarImmoMaxStacks = (S.AFireInside:IsAvailable()) and 5 or 1
local GCDMax = Player:GCD() + 0.25
local CombatTime = 0
local VarTrinketSyncSlot = 0
local VarUseEyeBeamFuryCondition = false
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  VarBladeDance = false
  VarPoolingForBladeDance = false
  VarPoolingForEyeBeam = false
  VarWaitingForEssenceBreak = false
  VarWaitingForMomentum = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarImmoMaxStacks = (S.AFireInside:IsAvailable()) and 5 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

-- Functions
local function IsInMeleeRange(range)
  if S.Felblade:TimeSinceLastCast() <= Player:GCD() then
    return true
  elseif S.VengefulRetreat:TimeSinceLastCast() < 1.0 then
    return false
  end
  return range and Target:IsInMeleeRange(range) or Target:IsInMeleeRange(5)
end

local function UseFelRush()
  return (Settings.Havoc.ConserveFelRush and S.FelRush:Charges() == 2) or not Settings.Havoc.ConserveFelRush
end

local function EvalutateTargetIfFilterDemonsBite(TargetUnit)
  -- target_if=min:debuff.burning_wound.remains
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff) or TargetUnit:DebuffRemains(S.BurningWoundLegDebuff)
end

local function EvaluateTargetIfDemonsBite(TargetUnit)
  -- if=talent.burning_wound&debuff.burning_wound.remains<4&active_dot.burning_wound<(spell_targets>?3)
  return S.BurningWound:IsAvailable() and TargetUnit:DebuffRemains(S.BurningWoundDebuff) < 4 and S.BurningWoundDebuff:AuraActiveCount() < mathmin(EnemiesCount8, 3)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- variable,name=3min_trinket,value=trinket.1.cooldown.duration=180|trinket.2.cooldown.duration=180
  Var3MinTrinket = (trinket1:Cooldown() == 180 or trinket2:Cooldown() == 180)
  -- variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  VarTrinketSyncSlot = 0
  if (trinket1:HasStatAnyDps() and (not trinket2:HasStatAnyDps() or trinket1:Cooldown() >= trinket2:Cooldown())) then
    VarTrinketSyncSlot = 1
  end
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  if (trinket2:HasStatAnyDps() and (not trinket1:HasStatAnyDps() or trinket2:Cooldown() >= trinket1:Cooldown())) then
    VarTrinketSyncSlot = 2
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 2"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 4"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura precombat 6"; end
  end
  -- sigil_of_flame,if=!equipped.algethar_puzzle_box
  if S.SigilofFlame:IsCastable() and (not I.AlgetharPuzzleBox:IsEquipped()) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame precombat 8"; end
  end
  -- Manually added: Fel Rush if out of range
  if not Target:IsInMeleeRange(5) and S.FelRush:IsCastable() then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush, not Target:IsInRange(15)) then return "fel_rush precombat 10"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if Target:IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not Target:IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 12"; end
  end
end

local function MetaEnd()
  if Player:BuffDown(S.FelBarrage) then
    -- death_sweep,if=buff.fel_barrage.down
    if S.DeathSweep:IsReady() then
      if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta_end 2"; end
    end
    -- annihilation,if=buff.fel_barrage.down
    if S.Annihilation:IsReady() then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta_end 4"; end
    end
  end
end

local function Cooldown()
  if CDsON() then
    -- metamorphosis,if=!talent.demonic&((!talent.chaotic_transformation|cooldown.eye_beam.remains>20)&active_enemies>desired_targets|raid_event.adds.in>60|fight_remains<25)
    if S.Metamorphosis:IsCastable() and (not S.Demonic:IsAvailable()) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 2"; end
    end
    -- metamorphosis,if=talent.demonic&(!talent.chaotic_transformation&cooldown.eye_beam.remains|cooldown.eye_beam.remains>20&(!variable.blade_dance|prev_gcd.1.death_sweep|prev_gcd.2.death_sweep)|fight_remains<25+talent.shattered_destiny*70&cooldown.eye_beam.remains&cooldown.blade_dance.remains)&buff.inner_demon.down
    if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and (not S.ChaoticTransformation:IsAvailable() and S.EyeBeam:CooldownDown() or S.EyeBeam:CooldownRemains() > 20 and (not VarBladeDance or Player:PrevGCDP(1, S.DeathSweep) or Player:PrevGCDP(2, S.DeathSweep)) or FightRemains < 25 + num(S.ShatteredDestiny:IsAvailable()) * 70 and S.EyeBeam:CooldownDown() and S.BladeDance:CooldownDown()) and Player:BuffDown(S.InnerDemonBuff)) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 4"; end
    end
  end
  -- potion,if=buff.metamorphosis.remains>25|buff.metamorphosis.up&cooldown.metamorphosis.ready|fight_remains<60|time>0.1&time<10
  if Settings.Commons.Enabled.Potions and (Player:BuffRemains(S.MetamorphosisBuff) > 25 or Player:BuffUp(S.MetamorphosisBuff) and S.Metamorphosis:CooldownUp() or FightRemains < 60 or CombatTime > 0.1 and CombatTime < 10) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 6"; end
    end
  end
  -- elysian_decree,if=(active_enemies>desired_targets|raid_event.adds.in>30)&debuff.essence_break.down
  if CDsON() and S.ElysianDecree:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree cooldown 8"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=manic_grieftorch,use_off_gcd=1,if=buff.vengeful_retreat_movement.down&((buff.initiative.remains>2&debuff.essence_break.down&cooldown.essence_break.remains>gcd.max&time>14|time_to_die<10|time<1&!equipped.algethar_puzzle_box|fight_remains%%120<5)&!prev_gcd.1.essence_break)
    if I.ManicGrieftorch:IsEquippedAndReady() and ((Player:BuffRemains(S.InitiativeBuff) > 2 and Target:DebuffDown(S.EssenceBreakDebuff) and S.EssenceBreak:CooldownRemains() > GCDMax and CombatTime > 14 or Target:TimeToDie() < 10 or CombatTime < 1 and not I.AlgetharPuzzleBox:IsEquipped() or FightRemains % 120 < 5) and not Player:PrevGCDP(1, S.EssenceBreak)) then
      if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "manic_grieftorch cooldown 10"; end
    end
    -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=cooldown.metamorphosis.remains<=gcd.max*5|fight_remains%%180>10&fight_remains%%180<22|fight_remains<25
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Metamorphosis:CooldownRemains() <= GCDMax * 5 or FightRemains % 180 > 10 and FightRemains % 180 < 22 or FightRemains < 25) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 12"; end
    end
    -- use_item,name=irideus_fragment,use_off_gcd=1,if=cooldown.metamorphosis.remains<=gcd.max&time>2|fight_remains%%180>10&fight_remains%%180<22|fight_remains<22
    if I.IrideusFragment:IsEquippedAndReady() and (S.Metamorphosis:CooldownRemains() <= GCDMax and CombatTime > 2 or FightRemains % 180 > 10 and FightRemains % 180 < 22 or FightRemains < 22) then
      if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment cooldown 14"; end
    end
    -- use_item,name=stormeaters_boon,use_off_gcd=1,if=cooldown.metamorphosis.remains&(!talent.momentum|buff.momentum.remains>5)&(active_enemies>1|raid_event.adds.in>140)
    if I.StormEatersBoon:IsEquippedAndReady() and (S.Metamorphosis:CooldownDown() and (not S.Momentum:IsAvailable() or Player:BuffRemains(S.MomentumBuff) > 5)) then
      if Cast(I.StormEatersBoon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "stormeaters_boon cooldown 16"; end
    end
    -- use_item,name=beacon_to_the_beyond,use_off_gcd=1,if=buff.vengeful_retreat_movement.down&debuff.essence_break.down&!prev_gcd.1.essence_break&(!equipped.irideus_fragment|trinket.1.cooldown.remains>20|trinket.2.cooldown.remains>20)
    if I.BeacontotheBeyond:IsEquippedAndReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and not Player:PrevGCDP(1, S.EssenceBreak) and (not I.IrideusFragment:IsEquipped() or trinket1:CooldownRemains() > 20 or trinket2:CooldownRemains() > 20)) then
      if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond cooldown 18"; end
    end
    -- use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=(time_to_die<30|cooldown.vengeful_retreat.remains<5|equipped.beacon_to_the_beyond|equipped.irideus_fragment)&(trinket.1.cooldown.remains>10|trinket.2.cooldown.remains>10|trinket.1.cooldown.duration=0|trinket.2.cooldown.duration=0|equipped.elementium_pocket_anvil|equipped.screaming_black_dragonscale|equipped.mark_of_dargrul)|(trinket.1.cooldown.duration>0|trinket.2.cooldown.duration>0)&(trinket.1.cooldown.remains|trinket.2.cooldown.remains)&!equipped.elementium_pocket_anvil&time<25
    if I.DragonfireBombDispenser:IsEquippedAndReady() then
      -- Note: Keeping the two below variables in case a later APL change wants DBDCharges
      -- local DBDSpell = I.DragonfireBombDispenser:OnUseSpell()
      -- local DBDCharges = DBDSpell and DBDSpell:Charges() or 0
      if (Target:TimeToDie() < 30 or S.VengefulRetreat:CooldownRemains() < 5 or I.BeacontotheBeyond:IsEquipped() or I.IrideusFragment:IsEquipped()) and (trinket1:CooldownRemains() > 10 or trinket2:CooldownRemains() > 10 or trinket1:Cooldown() == 0 or trinket2:Cooldown() == 0 or I.ElementiumPocketAnvil:IsEquipped() or I.ScreamingBlackDragonscale:IsEquipped() or I.MarkofDargrul:IsEquipped()) or (trinket1:Cooldown() > 0 or trinket2:Cooldown() > 0) and (trinket1:CooldownDown() or trinket2:CooldownDown()) and not I.ElementiumPocketAnvil:IsEquipped() and CombatTime < 25 then
        if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser cooldown 20"; end
      end
    end
    -- use_item,name=elementium_pocket_anvil,use_off_gcd=1,if=!prev_gcd.1.fel_rush&gcd.remains
    if I.ElementiumPocketAnvil:IsEquippedAndReady() and (not Player:PrevGCDP(1, S.FelRush)) then
      if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(8)) then return "elementium_pocket_anvil cooldown 22"; end
    end
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    -- use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.1.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=2&!trinket.2.cooldown.ready)|!variable.trinket_sync_slot)&(!talent.initiative|buff.initiative.up)
    if Trinket1ToUse and ((VarTrinketSyncSlot == 1 and (Player:BuffUp(S.MetamorphosisBuff) or (not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemains() > (mathmin(FightRemains, Trinket1ToUse:Cooldown()))) or FightRemains <= 20) or (VarTrinketSyncSlot == 2 and not Trinket2ToUse) or VarTrinketSyncSlot == 0) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff))) then
      if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 cooldown 24"; end
    end
    -- use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.2.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=1&!trinket.1.cooldown.ready)|!variable.trinket_sync_slot)&(!talent.initiative|buff.initiative.up)
    if Trinket2ToUse and ((VarTrinketSyncSlot == 2 and (Player:BuffUp(S.MetamorphosisBuff) or (not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemains() > (mathmin(FightRemains, Trinket2ToUse:Cooldown()))) or FightRemains <= 20) or (VarTrinketSyncSlot == 1 and not Trinket1ToUse) or VarTrinketSyncSlot == 0) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff))) then
      if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 cooldown 26"; end
    end
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

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8y, false)
    end

    -- Calculate gcd.max
    GCDMax = Player:GCD() + 0.25

    -- Calculate CombatTime
    CombatTime = HL.CombatTime()
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually added: Defensive Blur
    if S.Blur:IsCastable() and Player:HealthPercentage() <= Settings.Havoc.BlurHealthThreshold then
      if Cast(S.Blur, Settings.Havoc.OffGCDasOffGCD.Blur) then return "blur defensive"; end
    end
    -- auto_attack
    -- retarget_auto_attack,line_cd=1,target_if=min:debuff.burning_wound.remains,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound<(spell_targets>?3)
    -- retarget_auto_attack,line_cd=1,target_if=min:!target.is_boss,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound=(spell_targets>?3)
    -- variable,name=blade_dance,value=talent.first_blood|talent.trail_of_ruin|talent.chaos_theory&buff.chaos_theory.down|spell_targets.blade_dance1>1
    VarBladeDance = (S.FirstBlood:IsAvailable() or S.TrailofRuin:IsAvailable() or S.ChaosTheory:IsAvailable() and Player:BuffDown(S.ChaosTheoryBuff) or EnemiesCount8 > 1)
    -- variable,name=pooling_for_blade_dance,value=variable.blade_dance&fury<(75-talent.demon_blades*20)&cooldown.blade_dance.remains<gcd.max
    VarPoolingForBladeDance = (VarBladeDance and Player:Fury() < (75 - num(S.DemonBlades:IsAvailable()) * 20) and S.BladeDance:CooldownRemains() < GCDMax)
    -- variable,name=pooling_for_eye_beam,value=talent.demonic&!talent.blind_fury&cooldown.eye_beam.remains<(gcd.max*3)&fury.deficit>30
    VarPoolingForEyeBeam = S.Demonic:IsAvailable() and not S.BlindFury:IsAvailable() and S.EyeBeam:CooldownRemains() < (GCDMax * 2) and Player:FuryDeficit() > 30
    -- variable,name=waiting_for_momentum,value=talent.momentum&!buff.momentum.up|talent.inertia&!buff.inertia.up
    -- variable,name=waiting_for_momentum,value=talent.momentum&!buff.momentum.up
    VarWaitingForMomentum = S.Momentum:IsAvailable() and Player:BuffDown(S.MomentumBuff) or S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff)
    -- variable,name=holding_meta,value=(talent.demonic&talent.essence_break)&variable.3min_trinket&fight_remains>cooldown.metamorphosis.remains+30+talent.shattered_destiny*60&cooldown.metamorphosis.remains<20&cooldown.metamorphosis.remains>action.eye_beam.execute_time+gcd.max*(talent.inner_demon+2)
    local EyeBeamExecuteTime = mathmax(S.EyeBeam:BaseDuration(), Player:GCD())
    VarHoldingMeta = (S.Demonic:IsAvailable() and S.EssenceBreak:IsAvailable()) and Var3MinTrinket and FightRemains > S.Metamorphosis:CooldownRemains() + 30 + num(S.ShatteredDestiny:IsAvailable()) * 60 and S.Metamorphosis:CooldownRemains() < 20 and S.Metamorphosis:CooldownRemains() > EyeBeamExecuteTime + GCDMax * (num(S.InnerDemon:IsAvailable()) + 2)
    -- invoke_external_buff,name=power_infusion,if=buff.metamorphosis.up
    -- Note: Not handling external buffs
    -- immolation_aura,if=talent.ragefire&active_enemies>=3&(cooldown.blade_dance.remains|debuff.essence_break.down)
    if S.ImmolationAura:IsCastable() and (S.Ragefire:IsAvailable() and EnemiesCount8 >= 3 and (S.BladeDance:CooldownDown() or Target:DebuffDown(S.EssenceBreakDebuff))) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 2"; end
    end
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- immolation_aura,if=talent.a_fire_inside&talent.inertia&buff.unbound_chaos.down&full_recharge_time<gcd.max*2&debuff.essence_break.down
    if S.ImmolationAura:IsCastable() and (S.AFireInside:IsAvailable() and S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and S.ImmolationAura:FullRechargeTime() < GCDMax * 2 and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 4"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&(action.immolation_aura.charges=2&debuff.essence_break.down|prev_gcd.1.eye_beam&buff.inertia.up&buff.inertia.remains<3)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and (S.ImmolationAura:Charges() == 2 and Target:DebuffDown(S.EssenceBreakDebuff) or Player:PrevGCDP(1, S.EyeBeam) and Player:BuffUp(S.InertiaBuff) and Player:BuffRemains(S.InertiaBuff) < 3)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 6"; end
    end
    -- the_hunt,if=time<10&buff.potion.up&(!talent.inertia|buff.metamorphosis.up&debuff.essence_break.down)
    local PotionSelected = Everyone.PotionSelected()
    if S.TheHunt:IsCastable() and (CombatTime < 10 and (not PotionSelected or PotionSelected:TimeSinceLastCast() < 30) and (not S.Inertia:IsAvailable() or Player:BuffUp(S.MetamorphosisBuff) and Target:DebuffDown(S.EssenceBreakDebuff))) then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt main 8"; end
    end
    -- immolation_aura,if=talent.inertia&(cooldown.eye_beam.remains<gcd.max*2|buff.metamorphosis.up)&cooldown.essence_break.remains<gcd.max*3&buff.unbound_chaos.down&buff.inertia.down&debuff.essence_break.down
    if S.ImmolationAura:IsCastable() and (S.Inertia:IsAvailable() and (S.EyeBeam:CooldownRemains() < GCDMax * 2 or Player:BuffUp(S.MetamorphosisBuff)) and S.EssenceBreak:CooldownRemains() < GCDMax * 3 and Player:BuffDown(S.UnboundChaosBuff) and Player:BuffDown(S.InertiaBuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 10"; end
    end
    -- immolation_aura,if=talent.inertia&buff.unbound_chaos.down&(full_recharge_time<cooldown.essence_break.remains|!talent.essence_break)&debuff.essence_break.down&(buff.metamorphosis.down|buff.metamorphosis.remains>6)&cooldown.blade_dance.remains&(fury<75|cooldown.blade_dance.remains<gcd.max*2)
    if S.ImmolationAura:IsCastable() and (S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and (S.ImmolationAura:FullRechargeTime() < S.EssenceBreak:CooldownRemains() or not S.EssenceBreak:IsAvailable()) and Target:DebuffDown(S.EssenceBreakDebuff) and (Player:BuffDown(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff) > 6) and S.BladeDance:CooldownDown() and (Player:Fury() < 75 or S.BladeDance:CooldownRemains() < GCDMax * 2)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 12"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&(buff.unbound_chaos.remains<gcd.max*2|target.time_to_die<gcd.max*2)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and (Player:BuffRemains(S.UnboundChaosBuff) < GCDMax * 2 or Target:TimeToDie() < GCDMax * 2)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 14"; end
    end
    -- fel_rush,if=talent.inertia&buff.inertia.down&buff.unbound_chaos.up&cooldown.eye_beam.remains+3>buff.unbound_chaos.remains&(cooldown.blade_dance.remains|cooldown.essence_break.up)
    if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and Player:BuffUp(S.UnboundChaosBuff) and S.EyeBeam:CooldownRemains() + 3 > Player:BuffRemains(S.UnboundChaosBuff) and (S.BladeDance:CooldownDown() or S.EssenceBreak:CooldownUp())) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 16"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&talent.inertia&buff.inertia.down&(buff.metamorphosis.up|cooldown.essence_break.remains>10)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and (Player:BuffUp(S.MetamorphosisBuff) or S.EssenceBreak:CooldownRemains() > 10)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 18"; end
    end
    -- call_action_list,name=cooldown
    -- Note: CDsON check is within Cooldown(), as the function also includes trinkets and potions
    if (true) then
      local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=meta_end,if=buff.metamorphosis.up&buff.metamorphosis.remains<gcd.max&active_enemies<3
    if Player:BuffUp(S.MetamorphosisBuff) and Player:BuffRemains(S.MetamorphosisBuff) < GCDMax and EnemiesCount8 < 3 then
      local ShouldReturn = MetaEnd(); if ShouldReturn then return ShouldReturn; end
    end
    -- pick_up_fragment,type=demon,if=demon_soul_fragments>0&(cooldown.eye_beam.remains<6|buff.metamorphosis.remains>5)&buff.empowered_demon_soul.remains<3|fight_remains<17
    -- pick_up_fragment,mode=nearest,type=lesser,if=fury.deficit>=45&(!cooldown.eye_beam.ready|fury<30)
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?
    -- annihilation,if=buff.inner_demon.up&cooldown.metamorphosis.remains<=gcd*3
    if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and S.Metamorphosis:CooldownRemains() <= Player:GCD() * 3) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 20"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=cooldown.eye_beam.remains<0.3&cooldown.essence_break.remains<gcd.max*2&time>5&fury>=30&gcd.remains<0.1&talent.inertia
    if S.VengefulRetreat:IsCastable() and (S.EyeBeam:CooldownRemains() < 0.3 and S.EssenceBreak:CooldownRemains() < GCDMax * 2 and CombatTime > 5 and Player:Fury() >= 30 and S.Inertia:IsAvailable()) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 22"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&talent.essence_break&time>1&(cooldown.essence_break.remains>15|cooldown.essence_break.remains<gcd.max&(!talent.demonic|buff.metamorphosis.up|cooldown.eye_beam.remains>15+(10*talent.cycle_of_hatred)))&(time<30|gcd.remains-1<0)&(!talent.initiative|buff.initiative.remains<gcd.max|time>4)
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and S.EssenceBreak:IsAvailable() and CombatTime > 1 and (S.EssenceBreak:CooldownRemains() > 15 or S.EssenceBreak:CooldownRemains() < GCDMax and (not S.Demonic:IsAvailable() or Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownRemains() > 15 + (10 * num(S.CycleofHatred:IsAvailable())))) and (CombatTime < 30 or Player:GCDRemains() - 1 < 0) and (not S.Initiative:IsAvailable() or Player:BuffRemains(S.InitiativeBuff) < GCDMax or CombatTime > 4)) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 24"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&talent.essence_break&time>1&(cooldown.essence_break.remains>15|cooldown.essence_break.remains<gcd.max*2&(buff.initiative.remains<gcd.max&!variable.holding_meta&cooldown.eye_beam.remains<=gcd.remains&(raid_event.adds.in>(40-talent.cycle_of_hatred*15))&fury>30|!talent.demonic|buff.metamorphosis.up|cooldown.eye_beam.remains>15+(10*talent.cycle_of_hatred)))&(buff.unbound_chaos.down|buff.inertia.up)
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and S.EssenceBreak:IsAvailable() and CombatTime > 1 and (S.EssenceBreak:CooldownRemains() > 15 or S.EssenceBreak:CooldownRemains() < GCDMax * 2 and (Player:BuffRemains(S.InitiativeBuff) < GCDMax and not VarHoldingMeta and S.EyeBeam:CooldownRemains() <= Player:GCDRemains() and Player:Fury() > 30 or not S.Demonic:IsAvailable() or Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownRemains() > 15 + (10 * num(S.CycleofHatred:IsAvailable())))) and (Player:BuffDown(S.UnboundChaosBuff) or Player:BuffUp(S.InertiaBuff))) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 24"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&!talent.essence_break&time>1&((!buff.initiative.up|prev_gcd.1.death_sweep&cooldown.metamorphosis.up&talent.chaotic_transformation)&talent.initiative)
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and not S.EssenceBreak:IsAvailable() and CombatTime > 1 and ((Player:BuffDown(S.InitiativeBuff) or Player:PrevGCDP(1, S.DeathSweep) and S.Metamorphosis:CooldownUp() and S.ChaoticTransformation:IsAvailable()) and S.Initiative:IsAvailable())) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 26"; end
    end
    -- fel_rush,if=talent.momentum.enabled&buff.momentum.remains<gcd.max*2&cooldown.eye_beam.remains<=gcd.max&debuff.essence_break.down&cooldown.blade_dance.remains
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) < GCDMax * 2 and S.EyeBeam:CooldownRemains() <= GCDMax and Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 28"; end
    end
    -- fel_rush,if=talent.inertia.enabled&!buff.inertia.up&buff.unbound_chaos.up&(buff.metamorphosis.up|cooldown.eye_beam.remains>action.immolation_aura.recharge_time&cooldown.eye_beam.remains>4)&debuff.essence_break.down&cooldown.blade_dance.remains
    if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and Player:BuffUp(S.UnboundChaosBuff) and (Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownRemains() > S.ImmolationAura:Recharge() and S.EyeBeam:CooldownRemains() > 4) and Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 30"; end
    end
    -- essence_break,if=(active_enemies>desired_targets|raid_event.adds.in>40)&(buff.metamorphosis.remains>gcd.max*3|cooldown.eye_beam.remains>10)&(!talent.tactical_retreat|buff.tactical_retreat.up|time<10)&(buff.vengeful_retreat_movement.remains<gcd.max*0.5|time>0)&cooldown.blade_dance.remains<=3.1*gcd.max|fight_remains<6
    -- TODO: Handle vengeful_retreat_movement
    if S.EssenceBreak:IsCastable() and ((Player:BuffRemains(S.MetamorphosisBuff) > GCDMax * 3 or S.EyeBeam:CooldownRemains() > 10) and (not S.TacticalRetreat:IsAvailable() or Player:BuffUp(S.TacticalRetreatBuff) or CombatTime < 10) and S.BladeDance:CooldownRemains() <= 3.1 * GCDMax or FightRemains < 6) then
      if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break main 32"; end
    end
    -- death_sweep,if=variable.blade_dance&(!talent.essence_break|cooldown.essence_break.remains>gcd.max*2)&buff.fel_barrage.down
    if S.DeathSweep:IsReady() and (VarBladeDance and (not S.EssenceBreak:IsAvailable() or S.EssenceBreak:CooldownRemains() > GCDMax * 2) and Player:BuffDown(S.FelBarrage)) then
      if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep main 34"; end
    end
    -- the_hunt,if=debuff.essence_break.down&(time<10|cooldown.metamorphosis.remains>10|!equipped.algethar_puzzle_box)&(raid_event.adds.in>90|active_enemies>3|time_to_die<10)&(debuff.essence_break.down&(!talent.furious_gaze|buff.furious_gaze.up|set_bonus.tier31_4pc)|!set_bonus.tier30_2pc)&time>10
    if S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and (CombatTime < 10 or S.Metamorphosis:CooldownRemains() > 10 or not I.AlgetharPuzzleBox:IsEquipped()) and (EnemiesCount8 == 1 or EnemiesCount8 > 3 or FightRemains < 10) and (Target:DebuffDown(S.EssenceBreakDebuff) and (not S.FuriousGaze:IsAvailable() or Player:BuffUp(S.FuriousGazeBuff) or Player:HasTier(31, 4)) or not Player:HasTier(30, 2)) and CombatTime > 10) then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt main 36"; end
    end
    -- fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30&fury.deficit<20&buff.metamorphosis.down
    if S.FelBarrage:IsCastable() and (EnemiesCount8 > 1 or EnemiesCount8 == 1 and Player:FuryDeficit() < 20 and Player:BuffDown(S.MetamorphosisBuff)) then
      if Cast(S.FelBarrage, nil, nil, not IsInMeleeRange(8)) then return "fel_barrage main 38"; end
    end
    -- glaive_tempest,if=(active_enemies>desired_targets|raid_event.adds.in>10)&(debuff.essence_break.down|active_enemies>1)&buff.fel_barrage.down
    if S.GlaiveTempest:IsReady() and ((Target:DebuffDown(S.EssenceBreakDebuff) or EnemiesCount8 > 1) and Player:BuffDown(S.FelBarrage)) then
      if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest main 40"; end
    end
    -- annihilation,if=buff.inner_demon.up&cooldown.eye_beam.remains<=gcd&buff.fel_barrage.down
    if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and S.EyeBeam:CooldownRemains() <= Player:GCD() and Player:BuffDown(S.FelBarrage)) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 42"; end
    end
    -- fel_rush,if=talent.momentum.enabled&cooldown.eye_beam.remains<=gcd.max&buff.momentum.remains<5&buff.metamorphosis.down
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and S.EyeBeam:CooldownRemains() <= GCDMax and Player:BuffRemains(S.MomentumBuff) < 5 and Player:BuffDown(S.MetamorphosisBuff)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 44"; end
    end
    -- eye_beam,if=active_enemies>desired_targets|raid_event.adds.in>(40-talent.cycle_of_hatred*15)&!debuff.essence_break.up&(cooldown.metamorphosis.remains>30-talent.cycle_of_hatred*15|cooldown.metamorphosis.remains<gcd.max*2&(!talent.essence_break|cooldown.essence_break.remains<gcd.max*1.5))&(buff.metamorphosis.down|buff.metamorphosis.remains>gcd.max|!talent.restless_hunter)&(talent.cycle_of_hatred|!talent.initiative|cooldown.vengeful_retreat.remains>5|time<10)&buff.inner_demon.down|fight_remains<15
    if S.EyeBeam:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.Metamorphosis:CooldownRemains() > 30 - num(S.CycleofHatred:IsAvailable()) * 15 or S.Metamorphosis:CooldownRemains() < GCDMax * 2 and (not S.EssenceBreak:IsAvailable() or S.EssenceBreak:CooldownRemains() < GCDMax * 1.5)) and (Player:BuffDown(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff) > GCDMax or not S.RestlessHunter:IsAvailable()) and (S.CycleofHatred:IsAvailable() or not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownRemains() > 5 or CombatTime < 10) and Player:BuffDown(S.InnerDemonBuff) or FightRemains < 15) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 46"; end
    end
    -- blade_dance,if=variable.blade_dance&(cooldown.eye_beam.remains>5|equipped.algethar_puzzle_box&cooldown.metamorphosis.remains>(cooldown.blade_dance.duration)|!talent.demonic|(raid_event.adds.in>cooldown&raid_event.adds.in<25))&buff.fel_barrage.down|set_bonus.tier31_2pc
    -- sigil_of_flame,if=talent.any_means_necessary&debuff.essence_break.down&active_enemies>=4
    if S.SigilofFlame:IsCastable() and (S.AnyMeansNecessary:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff) and EnemiesCount8 >= 4) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 48"; end
    end
    -- throw_glaive,if=talent.soulscar&(active_enemies>desired_targets|raid_event.adds.in>full_recharge_time+9)&spell_targets>=(2-talent.furious_throws)&!debuff.essence_break.up&(full_recharge_time<gcd.max*3|active_enemies>1)&!set_bonus.tier31_2pc
    -- immolation_aura,if=active_enemies>=2&fury<70&debuff.essence_break.down
    if S.ImmolationAura:IsCastable() and (EnemiesCount8 >= 2 and Player:Fury() < 70 and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 50"; end
    end
    -- annihilation,if=!variable.pooling_for_blade_dance&(cooldown.essence_break.remains|!talent.essence_break)&buff.fel_barrage.down|set_bonus.tier30_2pc
    if S.Annihilation:IsReady() and (not VarPoolingForBladeDance and (S.EssenceBreak:CooldownDown() or not S.EssenceBreak:IsAvailable()) and Player:BuffDown(S.FelBarrage) or Player:HasTier(30, 2)) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 52"; end
    end
    -- felblade,if=fury.deficit>=40&talent.any_means_necessary&debuff.essence_break.down|talent.any_means_necessary&debuff.essence_break.down
    if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40 and S.AnyMeansNecessary:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff) or S.AnyMeansNecessary:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 54"; end
    end
    -- sigil_of_flame,if=fury.deficit>=40&talent.any_means_necessary
    if S.SigilofFlame:IsCastable() and (Player:FuryDeficit() >= 40 and S.AnyMeansNecessary:IsAvailable()) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 56"; end
    end
    -- throw_glaive,if=talent.soulscar&(active_enemies>desired_targets|raid_event.adds.in>full_recharge_time+9)&spell_targets>=(2-talent.furious_throws)&!debuff.essence_break.up&!set_bonus.tier31_2pc
    if S.ThrowGlaive:IsReady() and (S.Soulscar:IsAvailable() and EnemiesCount20 >= (2 - num(S.FuriousThrows:IsAvailable())) and Target:DebuffDown(S.EssenceBreakDebuff) and not Player:HasTier(31, 2)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 58"; end
    end
    -- immolation_aura,if=buff.immolation_aura.stack<buff.immolation_aura.max_stack&(!talent.ragefire|active_enemies>desired_targets|raid_event.adds.in>15)&buff.out_of_range.down&(!buff.unbound_chaos.up|!talent.unbound_chaos)&(recharge_time<cooldown.essence_break.remains|!talent.essence_break&cooldown.eye_beam.remains>recharge_time)
    if S.ImmolationAura:IsCastable() and (Player:BuffStack(S.ImmolationAuraBuff) < VarImmoMaxStacks and Target:IsInRange(8) and (Player:BuffDown(S.UnboundChaosBuff) or not S.UnboundChaos:IsAvailable()) and (S.ImmolationAura:Recharge() < S.EssenceBreak:CooldownRemains() or not S.EssenceBreak:IsAvailable() and S.EyeBeam:CooldownRemains() > S.ImmolationAura:Recharge())) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 60"; end
    end
    -- throw_glaive,if=talent.soulscar&cooldown.throw_glaive.full_recharge_time<cooldown.blade_dance.remains&set_bonus.tier31_2pc&buff.fel_barrage.down&!variable.pooling_for_eye_beam
    if S.ThrowGlaive:IsReady() and (S.Soulscar:IsAvailable() and S.ThrowGlaive:FullRechargeTime() < S.BladeDance:CooldownRemains() and Player:HasTier(31, 2) and Player:BuffDown(S.FelBarrage) and not VarPoolingForEyeBeam) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 62"; end
    end
    -- chaos_strike,if=!variable.pooling_for_blade_dance&!variable.pooling_for_eye_beam&buff.fel_barrage.down
    if S.ChaosStrike:IsReady() and (not VarPoolingForBladeDance and not VarPoolingForEyeBeam and Player:BuffDown(S.FelBarrage)) then
      if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike main 64"; end
    end
    -- sigil_of_flame,if=raid_event.adds.in>15&fury.deficit>=30&buff.out_of_range.down
    if S.SigilofFlame:IsCastable() and (EnemiesCount8 == 1 and Player:FuryDeficit() >= 30 and Target:IsInRange(30)) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 66"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 68"; end
    end
    -- fel_rush,if=!talent.momentum&talent.demon_blades&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))&(buff.unbound_chaos.down)&(recharge_time<cooldown.essence_break.remains|!talent.essence_break)
    if S.FelRush:IsCastable() and UseFelRush() and (not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() and S.EyeBeam:CooldownDown() and Player:BuffDown(S.UnboundChaosBuff) and (S.FelRush:Recharge() < S.EssenceBreak:CooldownRemains() or not S.EssenceBreak:IsAvailable())) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 70"; end
    end
    -- demons_bite,target_if=min:debuff.burning_wound.remains,if=talent.burning_wound&debuff.burning_wound.remains<4&active_dot.burning_wound<(spell_targets>?3)
    if S.DemonsBite:IsCastable() then
      if Everyone.CastTargetIf(S.DemonsBite, Enemies8y, "min", EvalutateTargetIfFilterDemonsBite, EvaluateTargetIfDemonsBite, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite main 72"; end
    end
    -- fel_rush,if=!talent.momentum&!talent.demon_blades&spell_targets>1&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))&(buff.unbound_chaos.down)
    if S.FelRush:IsCastable() and UseFelRush() and (not S.Momentum:IsAvailable() and not S.DemonBlades:IsAvailable() and Enemies8y > 1 and Player:BuffDown(S.UnboundChaosBuff)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 74"; end
    end
    -- sigil_of_flame,if=raid_event.adds.in>15&fury.deficit>=30&buff.out_of_range.down
    if S.SigilofFlame:IsCastable() and (Player:FuryDeficit() >= 30 and Target:IsInRange(30)) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 76"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastable() then
      if Cast(S.DemonsBite, nil, nil, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite main 78"; end
    end
    -- fel_rush,if=talent.momentum&buff.momentum.remains<=20
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) <= 20) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 80"; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum)
    if S.FelRush:IsCastable() and (not IsInMeleeRange() and not S.Momentum:IsAvailable() and UseFelRush()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 82"; end
    end
    -- vengeful_retreat,if=!talent.initiative&movement.distance>15
    if S.VengefulRetreat:IsCastable() and (not S.Initiative:IsAvailable() and not IsInMeleeRange()) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 84"; end
    end
    -- throw_glaive,if=(talent.demon_blades|buff.out_of_range.up)&!debuff.essence_break.up&buff.out_of_range.down&!set_bonus.tier31_2pc
    if S.ThrowGlaive:IsReady() and ((S.DemonBlades:IsAvailable() or not Target:IsInRange(12)) and Target:DebuffDown(S.EssenceBreakDebuff) and Target:IsSpellInRange(S.ThrowGlaive) and not Player:HasTier(31, 2)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 86"; end
    end
    -- Show pooling if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.BurningWoundDebuff:RegisterAuraTracking()

  HR.Print("Havoc Demon Hunter rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(577, APL, Init)
