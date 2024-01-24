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
  I.WitherbarksBranch:ID(),
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- Enemies Variables
local EnemiesMelee, Enemies8y, Enemies12y, Enemies20y
local EnemiesMeleeCount, Enemies8yCount, Enemies12yCount, Enemies20yCount

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
local VarTrinketSyncSlot = 0
local VarFelBarrage = false
local VarGeneratorUp = false
local VarFuryGen = 0
local VarGCDDrain = 0
local GCDMax = Player:GCD() + 0.25
local CombatTime = 0
local BossFightRemains = 11111
local FightRemains = 11111

HL:RegisterForEvent(function()
  CombatTime = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
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

-- This is effectively a CastCycle that ignores the current target.
local function RetargetAutoAttack(Spell, Enemies, Condition, OutofRange)
  -- Do nothing if we're targeting a boss or AoE is disabled.
  if Target:IsInBossList() or not AoEON() then return false end
  local TargetGUID = Target:GUID()
  for _, CycleUnit in pairs(Enemies) do
    if CycleUnit:GUID() ~= TargetGUID and not CycleUnit:IsFacingBlacklisted() and not CycleUnit:IsUserCycleBlacklisted() and Condition(CycleUnit) then
      HR.CastLeftNameplate(CycleUnit, Spell)
      break
    end
  end
end

local function UseFelRush()
  return (Settings.Havoc.ConserveFelRush and S.FelRush:Charges() == 2) or not Settings.Havoc.ConserveFelRush
end

local function ETIFBurningWound(TargetUnit)
  -- target_if=min:debuff.burning_wound.remains
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff)
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- variable,name=3min_trinket,value=trinket.1.cooldown.duration=180|trinket.2.cooldown.duration=180
  Var3MinTrinket = (Trinket1:Cooldown() == 180 or Trinket2:Cooldown() == 180)
  -- variable,name=trinket_sync_slot,value=1,if=trinket.1.has_stat.any_dps&(!trinket.2.has_stat.any_dps|trinket.1.cooldown.duration>=trinket.2.cooldown.duration)
  VarTrinketSyncSlot = 0
  if (Trinket1:HasStatAnyDps() and (not Trinket2:HasStatAnyDps() or Trinket1:Cooldown() >= Trinket2:Cooldown())) then
    VarTrinketSyncSlot = 1
  end
  -- variable,name=trinket_sync_slot,value=2,if=trinket.2.has_stat.any_dps&(!trinket.1.has_stat.any_dps|trinket.2.cooldown.duration>trinket.1.cooldown.duration)
  if (Trinket2:HasStatAnyDps() and (not Trinket1:HasStatAnyDps() or Trinket2:Cooldown() >= Trinket1:Cooldown())) then
    VarTrinketSyncSlot = 2
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent precombat 2"; end
  end
  -- immolation_aura
  if S.ImmolationAura:IsCastable() then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura precombat 6"; end
  end
  -- Manually added: Felblade if out of range
  if not Target:IsInMeleeRange(5) and S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade precombat 9"; end
  end
  -- Manually added: Fel Rush if out of range
  if not Target:IsInMeleeRange(5) and S.FelRush:IsCastable() and (not S.Felblade:IsAvailable() or S.Felblade:CooldownDown() and not Player:PrevGCDP(1, S.Felblade)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush, not Target:IsInRange(15)) then return "fel_rush precombat 10"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if Target:IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not Target:IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 12"; end
  end
end

local function Meta()
  -- death_sweep,if=buff.metamorphosis.remains<gcd.max
  if S.DeathSweep:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < GCDMax) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta 2"; end
  end
  -- annihilation,if=buff.metamorphosis.remains<gcd.max
  if S.Annihilation:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < GCDMax) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 4"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up&talent.inertia
  -- fel_rush,if=talent.momentum&buff.momentum.remains<gcd.max*2
  if S.FelRush:IsCastable() and UseFelRush() and (
    (Player:BuffUp(S.UnboundChaosBuff) and S.Inertia:IsAvailable()) or
    (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) < GCDMax * 2)
  ) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush meta 6"; end
  end
  -- annihilation,if=buff.inner_demon.up&(cooldown.eye_beam.remains<gcd.max*3&cooldown.blade_dance.remains|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and (S.EyeBeam:CooldownRemains() < GCDMax * 3 and S.BladeDance:CooldownUp() or S.Metamorphosis:CooldownRemains() < GCDMax * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 8"; end
  end
  -- essence_break,if=fury>20&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2)&(buff.unbound_chaos.down|buff.inertia.up|!talent.inertia)|fight_remains<10
  if S.EssenceBreak:IsCastable() and (Player:Fury() > 20 and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < GCDMax * 2) and (Player:BuffDown(S.UnboundChaosBuff) or Player:BuffUp(S.InertiaBuff) or not S.Inertia:IsAvailable()) or FightRemains < 10) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break meta 10"; end
  end
  -- immolation_aura,if=debuff.essence_break.down&cooldown.blade_dance.remains>gcd.max+0.5&buff.unbound_chaos.down&talent.inertia&buff.inertia.down&full_recharge_time+3<cooldown.eye_beam.remains&buff.metamorphosis.remains>5
  if S.ImmolationAura:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownRemains() > GCDMax + 0.5 and Player:BuffDown(S.UnboundChaosBuff) and S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and S.ImmolationAura:FullRechargeTime() + 3 < S.EyeBeam:CooldownRemains() and Player:BuffRemains(S.MetamorphosisBuff) > 5) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 12"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta 14"; end
  end
  -- eye_beam,if=debuff.essence_break.down&buff.inner_demon.down
  if S.EyeBeam:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff)) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam meta 16"; end
  end
  -- glaive_tempest,if=debuff.essence_break.down&(cooldown.blade_dance.remains>gcd.max*2|fury>60)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.BladeDance:CooldownRemains() > GCDMax * 2 or Player:Fury() > 60)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest meta 18"; end
  end
  -- sigil_of_flame,if=active_enemies>2
  if S.SigilofFlame:IsCastable() and (Enemies8yCount > 2) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 20"; end
  end
  -- annihilation,if=cooldown.blade_dance.remains>gcd.max*2|fury>60|buff.metamorphosis.remains<5&cooldown.felblade.up
  if S.Annihilation:IsReady() and (S.BladeDance:CooldownRemains() > GCDMax * 2 or Player:Fury() > 60 or Player:BuffRemains(S.MetamorphosisBuff) < 5 and S.Felblade:CooldownUp()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 22"; end
  end
  -- sigil_of_flame,if=buff.metamorphosis.remains>5
  if S.SigilofFlame:IsCastable() and (Player:BuffRemains(S.MetamorphosisBuff) > 5) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 24"; end
  end
  -- felblade
  if S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade meta 26"; end
  end
  -- sigil_of_flame,if=debuff.essence_break.down
  if S.SigilofFlame:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 28"; end
  end
  -- immolation_aura,if=buff.out_of_range.down&recharge_time<(cooldown.eye_beam.remains<?buff.metamorphosis.remains)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
  if S.ImmolationAura:IsCastable() and (IsInMeleeRange(8) and S.ImmolationAura:Recharge() < (mathmax(S.EyeBeam:CooldownRemains(), Player:BuffRemains(S.MetamorphosisBuff)))) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 30"; end
  end
  -- fel_rush,if=talent.momentum
  if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable()) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush meta 32"; end
  end
  -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and S.FelRush:Recharge() < S.EyeBeam:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01) and IsInMeleeRange(15)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush meta 34"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite meta 36"; end
  end
end

local function Cooldown()
  -- metamorphosis,if=(!talent.initiative|cooldown.vengeful_retreat.remains)&((!talent.demonic|prev_gcd.1.death_sweep|prev_gcd.2.death_sweep|prev_gcd.3.death_sweep)&cooldown.eye_beam.remains&(!talent.essence_break|debuff.essence_break.up)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)
  if CDsON() and S.Metamorphosis:IsCastable() and ((not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownDown()) and ((not S.Demonic:IsAvailable() or Player:PrevGCDP(1, S.DeathSweep) or Player:PrevGCDP(2, S.DeathSweep) or Player:PrevGCDP(3, S.DeathSweep)) and S.EyeBeam:CooldownDown() and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff)) and Player:BuffDown(S.FelBarrage) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30)) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 2"; end
  end
  -- potion,if=fight_remains<35|buff.metamorphosis.up
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 35 or Player:BuffUp(S.MetamorphosisBuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cooldown 4"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    -- use_item,slot=trinket1,use_off_gcd=1,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.1.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.1.has_buff.any|fight_remains<25)&(!equipped.witherbarks_branch|trinket.2.cooldown.remains>20)&time>0
    if Trinket1ToUse and (((S.EyeBeam:CooldownRemains() < GCDMax and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket1:HasUseBuff() or BossFightRemains < 25) and (not I.WitherbarksBranch:IsEquipped() or Trinket2:CooldownRemains() > 20)) then
      if Cast(Trinket1ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 cooldown 6"; end
    end
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    -- use_item,slot=trinket2,use_off_gcd=1,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.2.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.2.has_buff.any|fight_remains<25)&(!equipped.witherbarks_branch|trinket.1.cooldown.remains>20)&time>0
    if Trinket2ToUse and (((S.EyeBeam:CooldownRemains() < GCDMax and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket2:HasUseBuff() or BossFightRemains < 25) and (not I.WitherbarksBranch:IsEquipped() or Trinket1:CooldownRemains() > 20)) then
      if Cast(Trinket2ToUse, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 cooldown 8"; end
    end
    -- use_item,name=witherbarks_branch,if=(talent.essence_break&cooldown.essence_break.remains<gcd.max|!talent.essence_break)&(active_enemies+3>=desired_targets+raid_event.adds.count|raid_event.adds.in>105)|fight_remains<25
    if I.WitherbarksBranch:IsEquippedAndReady() and ((S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownRemains() < GCDMax or not S.EssenceBreak:IsAvailable()) or BossFightRemains < 25) then
      if Cast(I.WitherbarksBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "witherbarks_branch cooldown 10"; end
    end
  end
  if CDsON() then
    -- the_hunt,if=debuff.essence_break.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>(1+!set_bonus.tier31_2pc)*45)&time>5
    if S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and CombatTime > 5) then
      if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt cooldown 12"; end
    end
    -- elysian_decree,if=debuff.essence_break.down
    if S.ElysianDecree:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ElysianDecree, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(30)) then return "elysian_decree cooldown 14"; end
    end
  end
end

local function Opener()
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " opener 2"; end
        end
      end
    end
  -- vengeful_retreat,if=prev_gcd.1.death_sweep
  if S.VengefulRetreat:IsCastable() and (Player:PrevGCDP(1, S.DeathSweep)) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat opener 4"; end
  end
  -- metamorphosis,if=prev_gcd.1.death_sweep|(!talent.chaotic_transformation)&(!talent.initiative|cooldown.vengeful_retreat.remains>2)|!talent.demonic
  if CDsON() and S.Metamorphosis:IsCastable() and (Player:PrevGCDP(1, S.DeathSweep) or (not S.ChaoticTransformation:IsAvailable()) and (not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownRemains() > 2) or not S.Demonic:IsAvailable()) then
    if Cast(S.Metamorphosis, nil, Settings.Commons.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis opener 6"; end
  end
  -- felblade,if=debuff.essence_break.down,line_cd=60
  if S.Felblade:IsCastable() and S.Felblade:TimeSinceLastCast() >= 60 and (Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade opener 8"; end
  end
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion opener 10"; end
    end
  end
  -- immolation_aura,if=charges=2&buff.unbound_chaos.down&(buff.inertia.down|active_enemies>2)
  if S.ImmolationAura:IsCastable() and (S.ImmolationAura:Charges() == 2 and Player:BuffDown(S.UnboundChaosBuff) and (Player:BuffDown(S.InertiaBuff) or Enemies8yCount > 2)) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura opener 12"; end
  end
  -- annihilation,if=buff.inner_demon.up&(!talent.chaotic_transformation|cooldown.metamorphosis.up)
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and (not S.ChaoticTransformation:IsAvailable() or S.Metamorphosis:CooldownUp())) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation opener 14"; end
  end
  -- eye_beam,if=debuff.essence_break.down&buff.inner_demon.down&(!buff.metamorphosis.up|cooldown.blade_dance.remains)
  if S.EyeBeam:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and (Player:BuffDown(S.MetamorphosisBuff) or S.BladeDance:CooldownDown())) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam opener 16"; end
  end
  -- fel_rush,if=talent.inertia&(buff.inertia.down|active_enemies>2)&buff.unbound_chaos.up
  if S.FelRush:IsCastable() and (S.Inertia:IsAvailable() and (Player:BuffDown(S.InertiaBuff) or Enemies12yCount > 2) and Player:BuffUp(S.UnboundChaosBuff)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush opener 18"; end
  end
  -- the_hunt,if=active_enemies>desired_targets|raid_event.adds.in>40+50*!set_bonus.tier31_2pc
  if CDsON() and S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt opener 20"; end
  end
  -- essence_break
  if S.EssenceBreak:IsCastable() then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break opener 22"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep opener 24"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation opener 26"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite opener 28"; end
  end
end

local function FelBarrageFunc()
  -- variable,name=generator_up,op=set,value=cooldown.felblade.remains<gcd.max|cooldown.sigil_of_flame.remains<gcd.max
  VarGeneratorUp = S.Felblade:CooldownRemains() < GCDMax or S.SigilofFlame:CooldownRemains() < GCDMax
  -- variable,name=fury_gen,op=set,value=1%(2.6*attack_haste)*12+buff.immolation_aura.stack*6+buff.tactical_retreat.up*10
  VarFuryGen = 1 / (2.6 * Player:SpellHaste()) * 12 + Player:BuffStack(S.ImmolationAura) * 6 + num(Player:BuffUp(S.TacticalRetreatBuff)) * 10
  -- variable,name=gcd_drain,op=set,value=gcd.max*32
  VarGCDDrain = GCDMax * 32
  -- annihilation,if=buff.inner_demon.up
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fel_barrage 2"; end
  end
  -- eye_beam,if=buff.fel_barrage.down&(active_enemies>1&raid_event.adds.up|raid_event.adds.in>40)
  if S.EyeBeam:IsReady() and (Player:BuffDown(S.FelBarrage)) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam fel_barrage 4"; end
  end
  -- essence_break,if=buff.fel_barrage.down&buff.metamorphosis.up
  if S.EssenceBreak:IsCastable() and (Player:BuffDown(S.FelBarrage) and Player:BuffUp(S.MetamorphosisBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break fel_barrage 6"; end
  end
  -- death_sweep,if=buff.fel_barrage.down
  if S.DeathSweep:IsReady() and (Player:BuffDown(S.FelBarrage)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fel_barrage 8"; end
  end
  -- immolation_aura,if=buff.unbound_chaos.down&(active_enemies>2|buff.fel_barrage.up)
  if S.ImmolationAura:IsCastable() and (Player:BuffDown(S.UnboundChaosBuff) and (Enemies8yCount > 2 or Player:BuffUp(S.FelBarrage))) then
    if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fel_barrage 10"; end
  end
  -- glaive_tempest,if=buff.fel_barrage.down&active_enemies>1
  if S.GlaiveTempest:IsReady() and (Player:BuffDown(S.FelBarrage) and Enemies8yCount > 1) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fel_barrage 12"; end
  end
  -- blade_dance,if=buff.fel_barrage.down
  if S.BladeDance:IsReady() and (Player:BuffDown(S.FelBarrage)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fel_barrage 14"; end
  end
  -- fel_barrage,if=fury>100&(raid_event.adds.in>90|raid_event.adds.in<gcd.max|raid_event.adds.remains>4&active_enemies>2)
  if S.FelBarrage:IsReady() and (Player:Fury() > 100) then
    if Cast(S.FelBarrage, Settings.Havoc.GCDasOffGCD.FelBarrage, nil, not IsInMeleeRange(8)) then return "fel_barrage fel_barrage 16"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up&fury>20&buff.fel_barrage.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Player:Fury() > 20 and Player:BuffUp(S.FelBarrage)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush fel_barrage 18"; end
  end
  -- sigil_of_flame,if=fury.deficit>40&buff.fel_barrage.up
  if S.SigilofFlame:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrage)) then
    if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fel_barrage 20"; end
  end
  -- felblade,if=buff.fel_barrage.up&fury.deficit>40
  if S.Felblade:IsCastable() and (Player:BuffUp(S.FelBarrage) and Player:FuryDeficit() > 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_barrage 22"; end
  end
  -- death_sweep,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.DeathSweep:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrage) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fel_barrage 24"; end
  end
  -- glaive_tempest,if=fury-variable.gcd_drain-30>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.GlaiveTempest:IsReady() and (Player:Fury() - VarGCDDrain - 30 > 0 and (Player:BuffRemains(S.FelBarrage) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fel_barrage 26"; end
  end
  -- blade_dance,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.BladeDance:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrage) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fel_barrage 28"; end
  end
  -- arcane_torrent,if=fury.deficit>40&buff.fel_barrage.up
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrage)) then
    if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent fel_barrage 30"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff)) then
    if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush fel_barrage 32"; end
  end
  -- the_hunt,if=fury>40&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>(1+set_bonus.tier31_2pc)*40)
  if CDsON() and S.TheHunt:IsCastable() and (Player:Fury() > 40) then
    if Cast(S.TheHunt, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt fel_barrage 34"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite fel_barrage 36"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  EnemiesMelee = Player:GetEnemiesInMeleeRange(5) -- Multiple Abilities
  Enemies8y = Player:GetEnemiesInMeleeRange(8) -- Sigil of Flame/Immolation Aura
  Enemies12y = Player:GetEnemiesInMeleeRange(12) -- Fel Barrage
  Enemies20y = Target:GetEnemiesInSplashRange(20) -- Eye Beam
  if AoEON() then
    EnemiesMeleeCount = #EnemiesMelee
    Enemies8yCount = #Enemies8y
    Enemies12yCount = #Enemies12y
    Enemies20yCount = #Enemies20y
  else
    EnemiesMeleeCount = 1
    Enemies8yCount = 1
    Enemies12yCount = 1
    Enemies20yCount = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(EnemiesMelee, false)
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
    -- auto_attack,if=!buff.out_of_range.up
    -- retarget_auto_attack,line_cd=1,target_if=min:debuff.burning_wound.remains,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound<(spell_targets>?3)
    -- retarget_auto_attack,line_cd=1,target_if=min:!target.is_boss,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound=(spell_targets>?3)
    if S.BurningWound:IsAvailable() and S.DemonBlades:IsAvailable() and S.BurningWoundDebuff:AuraActiveCount() < mathmin(EnemiesMeleeCount, 3) then
      if RetargetAutoAttack(S.DemonBlades, EnemiesMelee, ETIFBurningWound, not IsInMeleeRange(5)) then return "retarget_auto_attack main 2"; end
    end
    -- variable,name=fel_barrage,op=set,value=talent.fel_barrage&(cooldown.fel_barrage.remains<gcd.max*7&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in<gcd.max*7|raid_event.adds.in>90)&(cooldown.metamorphosis.remains|active_enemies>2)|buff.fel_barrage.up)&!(active_enemies=1&!raid_event.adds.exists)
    VarFelBarrage = S.FelBarrage:IsAvailable() and (S.FelBarrage:CooldownRemains() < GCDMax * 7 and (S.Metamorphosis:CooldownDown() or Enemies12yCount > 2) or Player:BuffUp(S.FelBarrage))
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(S.Disrupt, Settings.Commons.OffGCDasOffGCD.Disrupt, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=cooldown
    -- Note: CDsON check is within Cooldown(), as the function also includes trinkets and potions
    local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    -- fel_rush,if=buff.unbound_chaos.up&buff.unbound_chaos.remains<gcd.max*2
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Player:BuffRemains(S.UnboundChaosBuff) < GCDMax * 2) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 4"; end
    end
    -- pick_up_fragment,mode=nearest,type=lesser,if=fury.deficit>=45&(!cooldown.eye_beam.ready|fury<30)
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?
    -- run_action_list,name=opener,if=(cooldown.eye_beam.up|cooldown.metamorphosis.up)&time<15&(raid_event.adds.in>40)
    if (S.EyeBeam:CooldownUp() and S.Metamorphosis:CooldownUp()) and CombatTime < 15 then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Opener()"; end
    end
    -- run_action_list,name=fel_barrage,if=variable.fel_barrage&raid_event.adds.up
    if VarFelBarrage then
      local ShouldReturn = FelBarrageFunc(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FelBarrageFunc()"; end
    end
    -- immolation_aura,if=active_enemies>2&talent.ragefire&buff.unbound_chaos.down&(!talent.fel_barrage|cooldown.fel_barrage.remains>recharge_time)&debuff.essence_break.down
    if S.ImmolationAura:IsCastable() and (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > S.ImmolationAura:Recharge()) and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 6"; end
    end
    -- immolation_aura,if=active_enemies>2&talent.ragefire&raid_event.adds.up&raid_event.adds.remains<15&raid_event.adds.remains>5&debuff.essence_break.down
    if S.ImmolationAura:IsCastable() and (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff)) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 8"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&active_enemies>2&(!talent.inertia|cooldown.eye_beam.remains+2>buff.unbound_chaos.remains)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Enemies8yCount > 2 and (not S.Inertia:IsAvailable() or S.EyeBeam:CooldownRemains() + 2 > Player:BuffRemains(S.UnboundChaosBuff))) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 10"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&(cooldown.eye_beam.remains>15&gcd.remains<0.3|gcd.remains<0.1&cooldown.eye_beam.remains<=gcd.remains&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2))&time>4
    -- Note: Skipping gcd.remains checks to avoid twitchy suggestions. Forcing into OffGCD icon instead.
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (S.EyeBeam:CooldownRemains() > 15 or S.EyeBeam:CooldownRemains() <= Player:GCDRemains() and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < GCDMax * 2)) and CombatTime > 4) then
      if Cast(S.VengefulRetreat, true) then return "vengeful_retreat main 12"; end
    end
    -- run_action_list,name=fel_barrage,if=variable.fel_barrage|!talent.demon_blades&talent.fel_barrage&(buff.fel_barrage.up|cooldown.fel_barrage.up)&buff.metamorphosis.down
    if VarFelBarrage or not S.DemonBlades:IsAvailable() and S.FelBarrage:IsAvailable() and (Player:BuffUp(S.FelBarrage) or S.FelBarrage:CooldownUp()) and Player:BuffDown(S.MetamorphosisBuff) then
      local ShouldReturn = FelBarrageFunc(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FelBarrageFunc()"; end
    end
    -- run_action_list,name=meta,if=buff.metamorphosis.up
    if Player:BuffUp(S.MetamorphosisBuff) then
      local ShouldReturn = Meta(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Meta()"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&talent.inertia&buff.inertia.down&cooldown.blade_dance.remains<4&cooldown.eye_beam.remains>5&(action.immolation_aura.charges>0|action.immolation_aura.recharge_time+2<cooldown.eye_beam.remains|cooldown.eye_beam.remains>buff.unbound_chaos.remains-2)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and S.BladeDance:CooldownRemains() < 4 and S.EyeBeam:CooldownRemains() > 5 and (S.ImmolationAura:Charges() > 0 or S.ImmolationAura:Recharge() + 2 < S.EyeBeam:CooldownRemains() or S.EyeBeam:CooldownRemains() > Player:BuffRemains(S.UnboundChaosBuff) - 2)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 14"; end
    end
    -- fel_rush,if=talent.momentum&cooldown.eye_beam.remains<gcd.max*2
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and S.EyeBeam:CooldownRemains() < GCDMax * 2) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 16"; end
    end
    -- immolation_aura,if=buff.unbound_chaos.down&full_recharge_time<gcd.max*2&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets)
    -- immolation_aura,if=immolation_aura,if=active_enemies>desired_targets&buff.unbound_chaos.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
    -- immolation_aura,if=talent.inertia&buff.unbound_chaos.down&cooldown.eye_beam.remains<5&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
    -- immolation_aura,if=talent.inertia&buff.inertia.down&buff.unbound_chaos.down&recharge_time+5<cooldown.eye_beam.remains&cooldown.blade_dance.remains&cooldown.blade_dance.remains<4&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)&charges_fractional>1.00
    -- immolation_aura,if=fight_remains<15&cooldown.blade_dance.remains
    if S.ImmolationAura:IsCastable() and (
      (Player:BuffDown(S.UnboundChaosBuff) and S.ImmolationAura:FullRechargeTime() < GCDMax * 2) or
      (Enemies8yCount > 1 and Player:BuffDown(S.UnboundChaosBuff)) or
      (S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and S.EyeBeam:CooldownRemains() < 5) or
      (S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and Player:BuffDown(S.UnboundChaosBuff) and S.ImmolationAura:Recharge() + 5 < S.EyeBeam:CooldownRemains() and S.BladeDance:CooldownDown() and S.BladeDance:CooldownRemains() < 4 and S.ImmolationAura:ChargesFractional() > 1.00)
    ) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 18"; end
    end
    -- eye_beam,if=!talent.essence_break&(!talent.chaotic_transformation|cooldown.metamorphosis.remains<5+3*talent.shattered_destiny|cooldown.metamorphosis.remains>15)&(active_enemies>desired_targets*2|raid_event.adds.in>30-talent.cycle_of_hatred.rank*13)
    if S.EyeBeam:IsReady() and (not S.EssenceBreak:IsAvailable() and (not S.ChaoticTransformation:IsAvailable() or S.Metamorphosis:CooldownRemains() < 5 + 3 * num(S.ShatteredDestiny:IsAvailable()) or S.Metamorphosis:CooldownRemains() > 15)) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 20"; end
    end
    -- eye_beam,if=talent.essence_break&(cooldown.essence_break.remains<gcd.max*2+5*talent.shattered_destiny|talent.shattered_destiny&cooldown.essence_break.remains>10)&(cooldown.blade_dance.remains<7|raid_event.adds.up)&(!talent.initiative|cooldown.vengeful_retreat.remains>10|raid_event.adds.up)&(active_enemies+3>=desired_targets+raid_event.adds.count|raid_event.adds.in>30-talent.cycle_of_hatred.rank*6)&(!talent.inertia|buff.unbound_chaos.up|action.immolation_aura.charges=0&action.immolation_aura.recharge_time>5)&(!raid_event.adds.up|raid_event.adds.remains>8)|fight_remains<10
    if S.EyeBeam:IsReady() and (S.EssenceBreak:IsAvailable() and (S.EssenceBreak:CooldownRemains() < GCDMax * 2 + 5 * num(S.ShatteredDestiny:IsAvailable()) or S.ShatteredDestiny:IsAvailable() and S.EssenceBreak:CooldownRemains() > 10) and (S.BladeDance:CooldownRemains() < 7 or Enemies20yCount > 1) and (not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownRemains() > 10 or Enemies20yCount > 1) and (not S.Inertia:IsAvailable() or Player:BuffUp(S.UnboundChaosBuff) or S.ImmolationAura:Charges() == 0 and S.ImmolationAura:Recharge() > 5) or FightRemains < 10) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 22"; end
    end
    -- blade_dance,if=cooldown.eye_beam.remains>gcd.max|cooldown.eye_beam.up
    if S.BladeDance:IsReady() and (S.EyeBeam:CooldownRemains() > GCDMax or S.EyeBeam:CooldownUp()) then
      if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance main 24"; end
    end
    -- glaive_tempest,if=active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10
    if S.GlaiveTempest:IsReady() then
      if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest main 26"; end
    end
    -- sigil_of_flame,if=active_enemies>3
    if S.SigilofFlame:IsCastable() and (Enemies8yCount > 3) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 28"; end
    end
    -- chaos_strike,if=debuff.essence_break.up
    if S.ChaosStrike:IsReady() and (Target:DebuffUp(S.EssenceBreakDebuff)) then
      if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike main 30"; end
    end
    -- felblade
    if S.Felblade:IsCastable() then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 32"; end
    end
    -- throw_glaive,if=full_recharge_time<=cooldown.blade_dance.remains&cooldown.metamorphosis.remains>5&talent.soulscar&set_bonus.tier31_2pc
    if S.ThrowGlaive:IsReady() and (S.ThrowGlaive:FullRechargeTime() <= S.BladeDance:CooldownRemains() and S.Metamorphosis:CooldownRemains() > 5 and S.Soulscar:IsAvailable() and Player:HasTier(31, 2)) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 34"; end
    end
    -- throw_glaive,if=!set_bonus.tier31_2pc&(active_enemies>1|talent.soulscar)
    if S.ThrowGlaive:IsReady() and (not Player:HasTier(31, 2) and (Enemies20yCount > 1 or S.Soulscar:IsAvailable())) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 36"; end
    end
    -- chaos_strike,if=cooldown.eye_beam.remains>gcd.max*2|fury>80
    if S.ChaosStrike:IsReady() and (S.EyeBeam:CooldownRemains() > GCDMax * 2 or Player:Fury() > 80) then
      if Cast(S.ChaosStrike, nil, nil, not Target:IsSpellInRange(S.ChaosStrike)) then return "chaos_strike main 38"; end
    end
    -- immolation_aura,if=!talent.inertia&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets&active_enemies>2)
    if S.ImmolationAura:IsCastable() and (not S.Inertia:IsAvailable()) then
      if Cast(S.ImmolationAura, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 40"; end
    end
    -- sigil_of_flame,if=buff.out_of_range.down&debuff.essence_break.down&(!talent.fel_barrage|cooldown.fel_barrage.remains>25|(active_enemies=1&!raid_event.adds.exists))
    if S.SigilofFlame:IsCastable() and (IsInMeleeRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > 25 or Enemies8yCount == 1)) then
      if Cast(S.SigilofFlame, nil, Settings.Commons.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 42"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastable() then
      if Cast(S.DemonsBite, nil, nil, not Target:IsSpellInRange(S.DemonsBite)) then return "demons_bite main 44"; end
    end
    -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and S.FelRush:Recharge() < S.EyeBeam:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01)) then
      if Cast(S.FelRush, nil, Settings.Commons.DisplayStyle.FelRush) then return "fel_rush main 46"; end
    end
    -- arcane_torrent,if=buff.out_of_range.down&debuff.essence_break.down&fury<100
    if S.ArcaneTorrent:IsCastable() and (IsInMeleeRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:Fury() < 100) then
      if Cast(S.ArcaneTorrent, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 48"; end
    end
    -- Show pooling if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.BurningWoundDebuff:RegisterAuraTracking()

  HR.Print("Havoc Demon Hunter rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(577, APL, Init)
