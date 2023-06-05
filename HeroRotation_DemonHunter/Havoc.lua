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
  I.DragonfireBombDispenser:ID(),
  I.ElementiumPocketAnvil:ID(),
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
  if (trinket1:HasStatAnyDps() and ((not trinket2:HasStatAnyDps()) or trinket1:Cooldown() >= trinket2:Cooldown())) then
    VarTrinketSyncSlot = 1
  end
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  if (trinket2:HasStatAnyDps() and ((not trinket1:HasStatAnyDps()) or trinket2:Cooldown() >= trinket1:Cooldown())) then
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
  -- sigil_of_flame,if=!equipped.algethar_puzzle_box
  if S.SigilofFlame:IsCastable() and (not I.AlgetharPuzzleBox:IsEquipped()) then
    if Cast(S.SigilofFlame, Settings.Havoc.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame precombat 6"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura precombat 8"; end
  end
  -- Manually added: Fel Rush if out of range
  if (not Target:IsInMeleeRange(5)) and S.FelRush:IsCastable() then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush, not Target:IsInRange(15)) then return "fel_rush precombat 10"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if Target:IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not Target:IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 12"; end
  end
end

local function MetaEnd()
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta_end 2"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta_end 4"; end
  end
end

local function Cooldown()
  if CDsON() then
    -- metamorphosis,if=!talent.demonic&((!talent.chaotic_transformation|cooldown.eye_beam.remains>20)&active_enemies>desired_targets|raid_event.adds.in>60|fight_remains<25)
    if S.Metamorphosis:IsCastable() and (not S.Demonic:IsAvailable()) then
      if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 2"; end
    end
    -- metamorphosis,if=talent.demonic&(!talent.chaotic_transformation|cooldown.eye_beam.remains>20&(!variable.blade_dance|cooldown.blade_dance.remains>gcd.max)|fight_remains<25+talent.shattered_destiny*70&cooldown.eye_beam.remains&cooldown.blade_dance.remains)
    if S.Metamorphosis:IsCastable() and (S.Demonic:IsAvailable() and ((not S.ChaoticTransformation:IsAvailable()) or S.EyeBeam:CooldownRemains() > 20 and ((not VarBladeDance) or S.BladeDance:CooldownRemains() > GCDMax) or FightRemains < 25 + num(S.ShatteredDestiny:IsAvailable()) * 70 and S.EyeBeam:CooldownDown() and S.BladeDance:CooldownDown())) then
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
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=manic_grieftorch,use_off_gcd=1,if=buff.vengeful_retreat_movement.down&((buff.initiative.remains>2&debuff.essence_break.down&cooldown.essence_break.remains>gcd.max&time>14|time_to_die<10|time<1&!equipped.algethar_puzzle_box|fight_remains%%120<5)&!prev_gcd.1.essence_break)
    if I.ManicGrieftorch:IsEquippedAndReady() and ((Player:BuffRemains(S.InitiativeBuff) > 2 and Target:DebuffDown(S.EssenceBreakDebuff) and S.EssenceBreak:CooldownRemains() > GCDMax and CombatTime > 14 or Target:TimeToDie() < 10 or CombatTime < 1 and (not I.AlgetharPuzzleBox:IsEquipped()) or FightRemains % 120 < 5) and not Player:PrevGCDP(1, S.EssenceBreak)) then
      if Cast(I.ManicGrieftorch, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "manic_grieftorch cooldown 8"; end
    end
    -- use_item,name=algethar_puzzle_box,use_off_gcd=1,if=cooldown.metamorphosis.remains<=gcd.max*5|fight_remains%%180>10&fight_remains%%180<22|fight_remains<25
    if I.AlgetharPuzzleBox:IsEquippedAndReady() and (S.Metamorphosis:CooldownRemains() <= GCDMax * 5 or FightRemains % 180 > 10 and FightRemains % 180 < 22 or FightRemains < 25) then
      if Cast(I.AlgetharPuzzleBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "algethar_puzzle_box cooldown 10"; end
    end
    -- use_item,name=dragonfire_bomb_dispenser,use_off_gcd=1,if=fight_remains<20|charges=3|cooldown.vengeful_retreat.remains<5
    local DBDSpell = I.DragonfireBombDispenser:OnUseSpell()
    local DBDCharges = DBDSpell and DBDSpell:Charges() or 0
    if I.DragonfireBombDispenser:IsEquippedAndReady() and (FightRemains < 20 or DBDCharges == 3 or S.VengefulRetreat:CooldownRemains() < 5) then
      if Cast(I.DragonfireBombDispenser, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(46)) then return "dragonfire_bomb_dispenser cooldown 12"; end
    end
    -- use_item,name=elementium_pocket_anvil,use_off_gcd=1
    if I.ElementiumPocketAnvil:IsEquippedAndReady() then
      if Cast(I.ElementiumPocketAnvil, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(100)) then return "elementium_pocket_anvil cooldown 14"; end
    end
  end
  -- elysian_decree,if=(active_enemies>desired_targets|raid_event.adds.in>30)
  if CDsON() and S.ElysianDecree:IsCastable() then
    if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree cooldown 16"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    -- use_items,slots=trinket1,if=(variable.trinket_sync_slot=1&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.1.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=2&!trinket.2.cooldown.ready)|!variable.trinket_sync_slot)&(!talent.initiative|buff.initiative.up)
    if Trinket1ToUse and ((VarTrinketSyncSlot == 1 and (Player:BuffUp(S.MetamorphosisBuff) or ((not S.Demonic:IsAvailable()) and S.Metamorphosis:CooldownRemains() > (mathmin(FightRemains, Trinket1ToUse:Cooldown()))) or FightRemains <= 20) or (VarTrinketSyncSlot == 2 and not Trinket2ToUse) or VarTrinketSyncSlot == 0) and ((not S.Initiative:IsAvailable()) or Player:BuffUp(S.InitiativeBuff))) then
      if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 cooldown 18"; end
    end
    -- use_items,slots=trinket2,if=(variable.trinket_sync_slot=2&(buff.metamorphosis.up|(!talent.demonic.enabled&cooldown.metamorphosis.remains>(fight_remains>?trinket.2.cooldown.duration%2))|fight_remains<=20)|(variable.trinket_sync_slot=1&!trinket.1.cooldown.ready)|!variable.trinket_sync_slot)&(!talent.initiative|buff.initiative.up)
    if Trinket2ToUse and ((VarTrinketSyncSlot == 2 and (Player:BuffUp(S.MetamorphosisBuff) or ((not S.Demonic:IsAvailable()) and S.Metamorphosis:CooldownRemains() > (mathmin(FightRemains, Trinket2ToUse:Cooldown()))) or FightRemains <= 20) or (VarTrinketSyncSlot == 1 and not Trinket1ToUse) or VarTrinketSyncSlot == 0) and ((not S.Initiative:IsAvailable()) or Player:BuffUp(S.InitiativeBuff))) then
      if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 cooldown 20"; end
    end
    -- use_item,name=stormeaters_boon,use_off_gcd=1,if=cooldown.metamorphosis.remains&(!talent.momentum|buff.momentum.remains>5)&(active_enemies>1|raid_event.adds.in>140)
    if I.StormEatersBoon:IsEquippedAndReady() and (S.Metamorphosis:CooldownDown() and ((not S.Momentum:IsAvailable()) or Player:BuffRemains(S.MomentumBuff) > 5)) then
      if Cast(I.StormEatersBoon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "stormeaters_boon cooldown 22"; end
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
    BossFightRemains = HL.BossFightRemains(nil, true)
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
    -- variable,name=pooling_for_eye_beam,value=talent.demonic&!talent.blind_fury&cooldown.eye_beam.remains<(gcd.max*2)&fury.deficit>20
    VarPoolingForEyeBeam = S.Demonic:IsAvailable() and (not S.BlindFury:IsAvailable()) and S.EyeBeam:CooldownRemains() < (GCDMax * 2) and Player:FuryDeficit() > 20
    -- variable,name=waiting_for_momentum,value=talent.momentum&!buff.momentum.up
    VarWaitingForMomentum = S.Momentum:IsAvailable() and Player:BuffDown(S.MomentumBuff)
    -- variable,name=holding_meta,value=(talent.demonic&talent.essence_break)&variable.3min_trinket&fight_remains>cooldown.metamorphosis.remains+30+talent.shattered_destiny*60&cooldown.metamorphosis.remains<20&cooldown.metamorphosis.remains>action.eye_beam.execute_time+gcd.max*(talent.inner_demon+2)
    local EyeBeamExecuteTime = mathmax(S.EyeBeam:BaseDuration(), Player:GCD())
    VarHoldingMeta = (S.Demonic:IsAvailable() and S.EssenceBreak:IsAvailable()) and Var3MinTrinket and FightRemains > S.Metamorphosis:CooldownRemains() + 30 + num(S.ShatteredDestiny:IsAvailable()) * 60 and S.Metamorphosis:CooldownRemains() < 20 and S.Metamorphosis:CooldownRemains() > EyeBeamExecuteTime + GCDMax * (num(S.InnerDemon:IsAvailable()) + 2)
    -- invoke_external_buff,name=power_infusion,if=time>170&!variable.holding_meta
    -- Note: Not handling external buffs
    -- immolation_aura,if=talent.ragefire&active_enemies>=3&(cooldown.blade_dance.remains|debuff.essence_break.down)
    if S.ImmolationAura:IsCastable() and (S.Ragefire:IsAvailable() and EnemiesCount8 >= 3 and (S.BladeDance:CooldownDown() or Target:DebuffDown(S.EssenceBreakDebuff))) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 2"; end
    end
    -- throw_glaive,if=talent.soulrend&talent.furious_throws&active_enemies>=3&time<1
    -- Note: Moved time check to the front
    if CombatTime < 1 and S.ThrowGlaive:IsCastable() and (S.Soulrend:IsAvailable() and S.FuriousThrows:IsAvailable() and EnemiesCount8 >= 3) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 4"; end
    end
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(10, S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- fel_rush,if=buff.unbound_chaos.up&(buff.unbound_chaos.remains<gcd.max*2|target.time_to_die<gcd.max*2)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and (Player:BuffRemains(S.UnboundChaosBuff) < GCDMax * 2 or Target:TimeToDie() < GCDMax * 2)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 6"; end
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
    -- pick_up_fragment,mode=nearest,if=talent.demonic_appetite&fury.deficit>=35&(!cooldown.eye_beam.ready|fury<30)
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?
    -- annihilation,if=buff.inner_demon.up&cooldown.metamorphosis.remains<=gcd*3
    if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and S.Metamorphosis:CooldownRemains() <= Player:GCD() * 3) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 8"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&talent.essence_break&time>1&(cooldown.essence_break.remains>15|cooldown.essence_break.remains<gcd.max&(!talent.demonic|buff.metamorphosis.up|cooldown.eye_beam.remains>15+(10*talent.cycle_of_hatred)))&(time<30|gcd.remains-1<0)&!talent.any_means_necessary
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and S.EssenceBreak:IsAvailable() and CombatTime > 1 and (S.EssenceBreak:CooldownRemains() > 15 or S.EssenceBreak:CooldownRemains() < Player:GCD() + 0.5 and ((not S.Demonic:IsAvailable()) or Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownRemains() > 15 + (10 * num(S.CycleofHatred:IsAvailable())))) and (CombatTime < 30 or Player:GCDRemains() - 1 < 0) and not S.AnyMeansNecessary:IsAvailable()) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 10"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&talent.essence_break&time>1&(cooldown.essence_break.remains>15|cooldown.essence_break.remains<gcd.max*2&(buff.initiative.remains<gcd.max&!variable.holding_meta&cooldown.eye_beam.remains=gcd.remains&(raid_event.adds.in>(40-talent.cycle_of_hatred*15))&fury>30|!talent.demonic|buff.metamorphosis.up|cooldown.eye_beam.remains>15+(10*talent.cycle_of_hatred)))&talent.any_means_necessary
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and S.EssenceBreak:IsAvailable() and CombatTime > 1 and (S.EssenceBreak:CooldownRemains() > 15 or S.EssenceBreak:CooldownRemains() < GCDMax * 2 and (Player:BuffRemains(S.InitiativeBuff) < GCDMax and (not VarHoldingMeta) and S.EyeBeam:CooldownRemains() <= Player:GCDRemains() and Player:Fury() > 30 or (not S.Demonic:IsAvailable()) or Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownRemains() > 15 + (10 * num(S.CycleofHatred:IsAvailable())))) and S.AnyMeansNecessary:IsAvailable()) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 12"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&!talent.essence_break&time>1&!buff.momentum.up
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (not S.EssenceBreak:IsAvailable()) and CombatTime > 1 and Player:BuffDown(S.MomentumBuff)) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 14"; end
    end
    -- wait,sec=buff.out_of_range.remains,if=buff.out_of_range.up&buff.out_of_range.remains<gcd.max
    -- fel_rush,if=talent.momentum.enabled&buff.momentum.remains<gcd.max*2&(charges_fractional>1.8|cooldown.eye_beam.remains<3)&debuff.essence_break.down
    if S.FelRush:IsCastable() and (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) < GCDMax * 2 and (S.FelRush:ChargesFractional() > 1.8 or S.EyeBeam:CooldownRemains() < 3) and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 16"; end
    end
    -- essence_break,if=(active_enemies>desired_targets|raid_event.adds.in>40)&!variable.waiting_for_momentum&(buff.metamorphosis.up)&(!talent.tactical_retreat|buff.tactical_retreat.up)|fight_remains<6
    if S.EssenceBreak:IsCastable() and ((not VarWaitingForMomentum) and Player:BuffUp(S.MetamorphosisBuff) and ((not S.TacticalRetreat:IsAvailable()) or Player:BuffUp(S.TacticalRetreatBuff)) or FightRemains < 6) then
      if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break main 18"; end
    end
    -- death_sweep,if=variable.blade_dance&(!talent.essence_break|cooldown.essence_break.remains>(cooldown.death_sweep.duration-4))
    if S.DeathSweep:IsReady() and (VarBladeDance and ((not S.EssenceBreak:IsAvailable()) or S.EssenceBreak:CooldownRemains() > ((9 * Player:SpellHaste()) - 4))) then
      if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep main 20"; end
    end
    -- fel_barrage,if=active_enemies>desired_targets|raid_event.adds.in>30
    if S.FelBarrage:IsCastable() then
      if Cast(S.FelBarrage, nil, nil, not IsInMeleeRange(8)) then return "fel_barrage main 22"; end
    end
    -- glaive_tempest,if=(active_enemies>desired_targets|raid_event.adds.in>10)&(debuff.essence_break.down|active_enemies>1)
    if S.GlaiveTempest:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) or EnemiesCount8 > 1) then
      if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest main 24"; end
    end
    -- annihilation,if=buff.inner_demon.up&cooldown.eye_beam.remains<=gcd
    if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and S.EyeBeam:CooldownRemains() <= Player:GCD()) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 26"; end
    end
    -- fel_rush,if=talent.momentum.enabled&cooldown.eye_beam.remains<gcd.max*3&buff.momentum.remains<5&buff.metamorphosis.down
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and S.EyeBeam:CooldownRemains() < GCDMax * 3 and Player:BuffRemains(S.MomentumBuff) < 5 and Player:BuffDown(S.MetamorphosisBuff)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 28"; end
    end
    -- the_hunt,if=debuff.essence_break.down&(time<10|cooldown.metamorphosis.remains>10|!equipped.algethar_puzzle_box)&(raid_event.adds.in>90|active_enemies>3|time_to_die<10)&(time>8&debuff.essence_break.down|!set_bonus.tier30_2pc)
    if S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and (CombatTime < 10 or S.Metamorphosis:CooldownRemains() > 10 or not I.AlgetharPuzzleBox:IsEquipped()) and (EnemiesCount8 == 1 or EnemiesCount8 > 3 or FightRemains < 10) and (CombatTime > 8 and Target:DebuffDown(S.EssenceBreakDebuff) or not Player:HasTier(30, 2))) then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt main 30"; end
    end
    -- throw_glaive,if=talent.serrated_glaive&cooldown.eye_beam.remains<6&!debuff.serrated_glaive.up&!debuff.essence_break.up&cooldown.blade_dance.remains
    if S.ThrowGlaive:IsCastable() and (S.SerratedGlaive:IsAvailable() and S.EyeBeam:CooldownRemains() < 6 and Target:DebuffDown(S.SerratedGlaiveDebuff) and Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown()) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 32"; end
    end
    -- eye_beam,if=active_enemies>desired_targets|raid_event.adds.in>(40-talent.cycle_of_hatred*15)&!debuff.essence_break.up&(cooldown.metamorphosis.remains>40-talent.cycle_of_hatred*15|!variable.holding_meta)&(buff.metamorphosis.down|buff.metamorphosis.remains>gcd.max|!talent.restless_hunter)&(buff.metamorphosis.down|cooldown.blade_dance.remains>gcd.max)|fight_remains<15
    if S.EyeBeam:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.Metamorphosis:CooldownRemains() > 40 - num(S.CycleofHatred:IsAvailable()) * 15 or not VarHoldingMeta) and (Player:BuffDown(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff) > GCDMax or not S.RestlessHunter:IsAvailable()) and (Player:BuffDown(S.MetamorphosisBuff) or S.BladeDance:CooldownRemains() > GCDMax) or FightRemains < 15) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 34"; end
    end
    -- blade_dance,if=variable.blade_dance&(cooldown.eye_beam.remains>5|equipped.algethar_puzzle_box&cooldown.metamorphosis.remains>(cooldown.blade_dance.duration)|!talent.demonic|(raid_event.adds.in>cooldown&raid_event.adds.in<25))
    if S.BladeDance:IsReady() and (VarBladeDance and (S.EyeBeam:CooldownRemains() > 5 or I.AlgetharPuzzleBox:IsEquipped() and S.Metamorphosis:CooldownRemains() > 10 * Player:SpellHaste() or (not S.Demonic:IsAvailable()))) then
      if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance main 36"; end
    end
    -- sigil_of_flame,if=talent.any_means_necessary&debuff.essence_break.down&active_enemies>=4
    if S.SigilofFlame:IsCastable() and (S.AnyMeansNecessary:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff) and EnemiesCount8 >= 4) then
      if Cast(S.SigilofFlame, Settings.Havoc.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 38"; end
    end
    -- throw_glaive,if=talent.soulrend&(active_enemies>desired_targets|raid_event.adds.in>full_recharge_time+9)&spell_targets>=(2-talent.furious_throws)&!debuff.essence_break.up&(full_recharge_time<gcd.max*3|active_enemies>1)
    if S.ThrowGlaive:IsCastable() and (S.Soulrend:IsAvailable() and EnemiesCount8 >= (2 - num(S.FuriousThrows:IsAvailable())) and Target:DebuffDown(S.EssenceBreakDebuff) and (S.ThrowGlaive:FullRechargeTime() < GCDMax * 3 or EnemiesCount8 > 1)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 40"; end
    end
    -- immolation_aura,if=fury<70&debuff.essence_break.down&time_to_die>3
    if S.ImmolationAura:IsCastable() and (Player:Fury() < 70 and Target:DebuffDown(S.EssenceBreakDebuff) and FightRemains > 3) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 42"; end
    end
    -- sigil_of_flame,if=talent.any_means_necessary&debuff.essence_break.down
    if S.SigilofFlame:IsCastable() and (S.AnyMeansNecessary:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.SigilofFlame, Settings.Havoc.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 44"; end
    end
    -- annihilation,if=!variable.pooling_for_blade_dance
    if S.Annihilation:IsReady() and (not VarPoolingForBladeDance) then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 46"; end
    end
    -- throw_glaive,if=talent.soulrend&(active_enemies>desired_targets|raid_event.adds.in>full_recharge_time+9)&spell_targets>=(2-talent.furious_throws)&!debuff.essence_break.up
    if S.ThrowGlaive:IsReady() and (S.Soulrend:IsAvailable() and EnemiesCount8 >= (2 - num(S.FuriousThrows)) and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 48"; end
    end
    -- immolation_aura,if=!buff.immolation_aura.up&(!talent.ragefire|active_enemies>desired_targets|raid_event.adds.in>15)
    if S.ImmolationAura:IsCastable() and (Player:BuffDown(S.ImmolationAuraBuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 50"; end
    end
    -- fel_rush,if=talent.isolated_prey&active_enemies=1&fury.deficit>=35
    if S.FelRush:IsCastable() and UseFelRush() and (S.IsolatedPrey:IsAvailable() and EnemiesCount8 == 1 and Player:FuryDeficit() >= 35) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 52"; end
    end
    -- chaos_strike,if=!variable.pooling_for_blade_dance&!variable.pooling_for_eye_beam
    if S.ChaosStrike:IsReady() and ((not VarPoolingForBladeDance) and not VarPoolingForEyeBeam) then
      if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike main 54"; end
    end
    -- sigil_of_flame,if=raid_event.adds.in>15&fury.deficit>=30
    if S.SigilofFlame:IsCastable() and (EnemiesCount8 == 1 and Player:FuryDeficit() >= 30) then
      if Cast(S.SigilofFlame, Settings.Havoc.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 56"; end
    end
    -- felblade,if=fury.deficit>=40
    if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 58"; end
    end
    -- fel_rush,if=!talent.momentum&talent.demon_blades&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable() and ((not S.Momentum:IsAvailable()) and S.DemonBlades:IsAvailable() and S.EyeBeam:CooldownDown() and UseFelRush()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 60"; end
    end
    -- demons_bite,target_if=min:debuff.burning_wound.remains,if=talent.burning_wound&debuff.burning_wound.remains<4&active_dot.burning_wound<(spell_targets>?3)
    if S.DemonsBite:IsCastable() then
      if Everyone.CastTargetIf(S.DemonsBite, Enemies8y, "min", EvalutateTargetIfFilterDemonsBite, EvaluateTargetIfDemonsBite, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite main 62"; end
    end
    -- fel_rush,if=!talent.momentum&!talent.demon_blades&spell_targets>1&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
    if S.FelRush:IsCastable() and ((not S.Momentum:IsAvailable()) and (not S.DemonBlades:IsAvailable()) and EnemiesCount8 > 1 and UseFelRush()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 64"; end
    end
    -- sigil_of_flame,if=raid_event.adds.in>15&fury.deficit>=30
    if S.SigilofFlame:IsCastable() and (Player:FuryDeficit() >= 30) then
      if Cast(S.SigilofFlame, Settings.Havoc.GCDasOffGCD.SigilOfFlame, nil, not Target:IsInRange(30)) then return "sigil_of_flame main 66"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastable() then
      if Cast(S.DemonsBite, nil, nil, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite main 68"; end
    end
    -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum)
    if S.FelRush:IsCastable() and ((not IsInMeleeRange()) and (not S.Momentum:IsAvailable()) and UseFelRush()) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 70"; end
    end
    -- vengeful_retreat,if=!talent.initiative&movement.distance>15
    if S.VengefulRetreat:IsCastable() and ((not S.Initiative:IsAvailable()) and (not IsInMeleeRange())) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 72"; end
    end
    -- throw_glaive,if=(talent.demon_blades.enabled|buff.out_of_range.up)&!debuff.essence_break.up
    if S.ThrowGlaive:IsReady() and ((S.DemonBlades:IsAvailable() or not Target:IsInRange(12)) and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 74"; end
    end
    -- Show pool icon if nothing else to do (should only happen when Demon Blades is used)
    if (S.DemonBlades:IsAvailable()) then
      if Cast(S.Pool) then return "pool demon_blades"; end
    end
  end
end

local function Init()
  S.BurningWoundDebuff:RegisterAuraTracking()

  HR.Print("Havoc DH rotation is currently a work in progress, but has been updated for patch 10.1.0.")
end

HR.SetAPL(577, APL, Init)
