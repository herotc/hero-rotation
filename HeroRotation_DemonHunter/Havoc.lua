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
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.DemonHunter.Havoc
local I = Item.DemonHunter.Havoc

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.MadQueensMandate:ID(),
  I.SkardynsGrace:ID(),
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local DemonHunter = HR.Commons.DemonHunter
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.DemonHunter.Commons,
  CommonsDS = HR.GUISettings.APL.DemonHunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.DemonHunter.CommonsOGCD,
  Havoc = HR.GUISettings.APL.DemonHunter.Havoc
}

--- ===== Rotation Variables =====
local VarRGDS = 0
local CombatTime = 0
local BossFightRemains = 11111
local FightRemains = 11111
local ImmoAbility
local EnemiesMelee, Enemies8y, Enemies12y, Enemies20y
local EnemiesMeleeCount, Enemies8yCount, Enemies12yCount, Enemies20yCount

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket1Range, VarTrinket1CastTime
local VarTrinket2Spell, VarTrinket2Range, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Steroids, VarTrinket2Steroids
local VarSpecialTrinket
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData()

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

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  VarTrinket1Steroids = Trinket1:HasStatAnyDps()
  VarTrinket2Steroids = Trinket2:HasStatAnyDps()
end
SetTrinketVariables()


--- ===== Sun Interrupts List =====
local StunInterrupts = {
  {S.ChaosNova, "Cast Chaos Nova (Interrupt)", function () return true; end},
  {S.FelEruption, "Cast Fel Eruption (Interrupt)", function () return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarRGDS = 0
  CombatTime = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  VarImmoMaxStacks = (S.AFireInside:IsAvailable()) and 5 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

--- ===== Helper Functions =====
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
    if CycleUnit:GUID() ~= TargetGUID and CycleUnit:DebuffDown(S.BurningWoundDebuff) then
      HR.CastLeftNameplate(CycleUnit, Spell)
      break
    end
  end
end

local function UseFelRush()
  return (Settings.Havoc.ConserveFelRush and S.FelRush:Charges() == 2) or not Settings.Havoc.ConserveFelRush
end

--- ===== CastTargetIfFilterFunctions =====
local function ETIFBurningWound(TargetUnit)
  -- target_if=min:debuff.burning_wound.remains
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- snapshot_stats
  -- variable,name=trinket1_steroids,value=trinket.1.has_stat.any_dps
  -- variable,name=trinket2_steroids,value=trinket.2.has_stat.any_dps
  -- variable,name=rg_ds,default=0,op=reset
  -- sigil_of_flame
  if S.SigilofFlame:IsCastable() then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame precombat 2"; end
  end
  -- immolation_aura
  if ImmoAbility:IsCastable() then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura precombat 4"; end
  end
  -- Manually added: Felblade if out of range
  if not IsInMeleeRange(5) and S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade precombat 6"; end
  end
  -- Manually added: Fel Rush if out of range
  if not IsInMeleeRange(5) and S.FelRush:IsCastable() and (not S.Felblade:IsAvailable() or S.Felblade:CooldownDown() and not Player:PrevGCDP(1, S.Felblade)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush, not Target:IsInRange(15)) then return "fel_rush precombat 8"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 10"; end
  end
end

local function Cooldown()
  -- metamorphosis,if=((!talent.initiative|cooldown.vengeful_retreat.remains)&(cooldown.eye_beam.remains>=20&(!talent.essence_break|debuff.essence_break.up)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&buff.inner_demon.down&(!talent.restless_hunter&cooldown.blade_dance.remains>gcd.max*3|prev_gcd.1.death_sweep))&!talent.inertia&!talent.essence_break&(hero_tree.aldrachi_reaver|buff.demonsurge_death_sweep.down)&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and (((not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownDown()) and (S.EyeBeam:CooldownRemains() >= 20 and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff)) and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and Player:BuffDown(S.InnerDemonBuff) and (not S.RestlessHunter:IsAvailable() and S.BladeDance:CooldownRemains() > Player:GCD() * 3 or Player:PrevGCD(1, S.DeathSweep))) and not S.Inertia:IsAvailable() and not S.EssenceBreak:IsAvailable() and (Player:HeroTreeID() == 35 or not Player:Demonsurge("DeathSweep")) and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 2"; end
  end
  -- metamorphosis,if=((!talent.initiative|cooldown.vengeful_retreat.remains)&cooldown.blade_dance.remains&((prev_gcd.1.death_sweep|prev_gcd.2.death_sweep|prev_gcd.3.death_sweep|buff.metamorphosis.up&buff.metamorphosis.remains<gcd.max)&cooldown.eye_beam.remains&(!talent.essence_break|debuff.essence_break.up|talent.shattered_destiny|hero_tree.felscarred)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&(buff.inner_demon.down&(buff.rending_strike.down|!talent.restless_hunter|prev_gcd.1.death_sweep)))&(talent.inertia|talent.essence_break)&(hero_tree.aldrachi_reaver|(buff.demonsurge_death_sweep.down|buff.metamorphosis.remains<gcd.max)&(buff.demonsurge_annihilation.down))&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and (((not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownDown()) and S.BladeDance:CooldownDown() and ((Player:PrevGCD(1, S.DeathSweep) or Player:PrevGCD(2, S.DeathSweep) or Player:PrevGCD(3, S.DeathSweep) or Player:BuffUp(S.MetamorphosisBuff) and Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD()) and S.EyeBeam:CooldownDown() and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff) or S.ShatteredDestiny:IsAvailable() or Player:HeroTreeID() == 34) and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and (Player:BuffDown(S.InnerDemonBuff) and (Player:BuffDown(S.RendingStrikeBuff) or not S.RestlessHunter:IsAvailable() or Player:PrevGCD(1, S.DeathSweep)))) and (S.Inertia:IsAvailable() or S.EssenceBreak:IsAvailable()) and (Player:HeroTreeID() == 35 or (not Player:Demonsurge("DeathSweep") or Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD()) and (not Player:Demonsurge("Annihilation"))) and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis cooldown 4"; end
  end
  -- potion,if=fight_remains<35|buff.metamorphosis.up|debuff.essence_break.up
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 35 or Player:BuffUp(S.MetamorphosisBuff) or Target:DebuffUp(S.EssenceBreakDebuff)) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cooldown 6"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.metamorphosis.up|fight_remains<=20
  -- Note: Not handling external buffs.
  -- variable,name=special_trinket,op=set,value=equipped.mad_queens_mandate|equipped.treacherous_transmitter|equipped.skardyns_grace
  VarSpecialTrinket = I.MadQueensMandate:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.SkardynsGrace:IsEquipped()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=mad_queens_mandate,if=((!talent.initiative|buff.initiative.up|time>5)&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(trinket.1.is.mad_queens_mandate&(trinket.2.cooldown.duration<10|trinket.2.cooldown.remains>10|!trinket.2.has_buff.any)|trinket.2.is.mad_queens_mandate&(trinket.1.cooldown.duration<10|trinket.1.cooldown.remains>10|!trinket.1.has_buff.any))&fight_remains>120|fight_remains<10&fight_remains<buff.metamorphosis.remains)&debuff.essence_break.down|fight_remains<5
    if I.MadQueensMandate:IsEquippedAndReady() and (((not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5) and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (VarTrinket1ID == I.MadQueensMandate:ID() and (VarTrinket2CD < 10 or Trinket2:CooldownRemains() > 10 or not Trinket2:HasUseBuff()) or VarTrinket2ID == I.MadQueensMandate:ID() and (VarTrinket1CD < 10 or Trinket1:CooldownRemains() > 10 or not Trinket1:HasUseBuff())) and FightRemains > 120 or BossFightRemains < 10 and BossFightRemains < Player:BuffRemains(S.MetamorphosisBuff)) and Target:DebuffDown(S.EssenceBreakDebuff) or BossFightRemains < 5) then
      if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mad_queens_mandate cooldown 8"; end
    end
    -- use_item,name=treacherous_transmitter,if=!equipped.mad_queens_mandate|equipped.mad_queens_mandate&(trinket.1.is.mad_queens_mandate&trinket.1.cooldown.remains>fight_remains|trinket.2.is.mad_queens_mandate&trinket.2.cooldown.remains>fight_remains)|fight_remains>25
    if I.TreacherousTransmitter:IsEquippedAndReady() and (not I.MadQueensMandate:IsEquipped() or I.MadQueensMandate:IsEquipped() and (VarTrinket1ID == I.MadQueensMandate:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket2ID == I.MadQueensMandate:ID() and Trinket2:CooldownRemains() > FightRemains) or FightRemains > 25) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter cooldown 10"; end
    end
    -- use_item,name=skardyns_grace,if=(!equipped.mad_queens_mandate|fight_remains>25|trinket.2.is.skardyns_grace&trinket.1.cooldown.remains>fight_remains|trinket.1.is.skardyns_grace&trinket.2.cooldown.remains>fight_remains|trinket.1.cooldown.duration<10|trinket.2.cooldown.duration<10)&buff.metamorphosis.up
    if I.SkardynsGrace:IsEquippedAndReady() and ((not I.MadQueensMandate:IsEquipped() or FightRemains > 25 or VarTrinket2ID == I.SkardynsGrace:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket1ID == I.SkardynsGrace:ID() and Trinket2:CooldownRemains() > FightRemains or VarTrinket1CD < 10 or VarTrinket2CD < 10) and Player:BuffUp(S.MetamorphosisBuff)) then
      if Cast(I.SkardynsGrace, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "skardyns_grace cooldown 12"; end
    end
    -- do_treacherous_transmitter_task,if=cooldown.eye_beam.remains>15|cooldown.eye_beam.remains<5|fight_remains<20
    -- TODO
    -- use_item,slot=trinket1,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.1.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.1.has_buff.any|fight_remains<25)&!trinket.1.is.skardyns_grace&!trinket.1.is.mad_queens_mandate&!trinket.1.is.treacherous_transmitter&(!variable.special_trinket|trinket.2.cooldown.remains>20)
    if Trinket1:IsReady() and not VarTrinket1BL and (((S.EyeBeam:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket1:HasUseBuff() or BossFightRemains < 25) and not VarTrinket1ID == I.SkardynsGrace:ID() and not VarTrinket1ID == I.MadQueensMandate:ID() and not VarTrinket1ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket2:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "treacherous_transmitter cooldown 14"; end
    end
    -- use_item,slot=trinket2,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.2.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.2.has_buff.any|fight_remains<25)&!trinket.2.is.skardyns_grace&!trinket.2.is.mad_queens_mandate&!trinket.2.is.treacherous_transmitter&(!variable.special_trinket|trinket.1.cooldown.remains>20)
    if Trinket2:IsReady() and not VarTrinket2BL and (((S.EyeBeam:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket2:HasUseBuff() or BossFightRemains < 25) and not VarTrinket2ID == I.SkardynsGrace:ID() and not VarTrinket2ID == I.MadQueensMandate:ID() and not VarTrinket2ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket1:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "treacherous_transmitter cooldown 16"; end
    end
  end
  -- the_hunt,if=debuff.essence_break.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>90)&(debuff.reavers_mark.up|!hero_tree.aldrachi_reaver)&buff.reavers_glaive.down&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(!talent.initiative|buff.initiative.up|time>5)
  if S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and (Target:DebuffUp(S.ReaversMarkDebuff) or Player:HeroTreeID() ~= 35) and Player:BuffDown(S.ReaversGlaiveBuff) and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5)) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt cooldown 18"; end
  end
  -- sigil_of_spite,if=debuff.essence_break.down&(debuff.reavers_mark.remains>=2-talent.quickened_sigils|!hero_tree.aldrachi_reaver)&cooldown.blade_dance.remains&time>15
  if S.SigilofSpite:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (Target:DebuffRemains(S.ReaversMarkDebuff) >= 2 - num(S.QuickenedSigils:IsAvailable()) or Player:HeroTreeID() ~= 35) and S.BladeDance:CooldownDown() and CombatTime> 15) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite cooldown 20"; end
  end
end

local function FelBarrageFunc()
  -- variable,name=generator_up,op=set,value=cooldown.felblade.remains<gcd.max|cooldown.sigil_of_flame.remains<gcd.max
  VarGeneratorUp = S.Felblade:CooldownRemains() < Player:GCD() or S.SigilofFlame:CooldownRemains() < Player:GCD()
  -- variable,name=fury_gen,op=set,value=talent.demon_blades*(1%(2.6*attack_haste)*12*((hero_tree.felscarred&buff.metamorphosis.up)*0.33+1))+buff.immolation_aura.stack*6+buff.tactical_retreat.up*10
  VarFuryGen = num(S.DemonBlades:IsAvailable()) * (1 / (2.6 * Player:HastePct()) * 12 * (num(Player:HeroTreeID() == 34 and Player:BuffUp(S.MetamorphosisBuff)) * 0.33 + 1)) + Player:BuffStack(ImmoAbility) * 6 + num(Player:BuffUp(S.TacticalRetreatBuff)) * 10
  -- variable,name=gcd_drain,op=set,value=gcd.max*32
  VarGCDDrain = Player:GCD() * 32
  -- annihilation,if=buff.inner_demon.up
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fel_barrage 2"; end
  end
  -- eye_beam,if=buff.fel_barrage.down&(active_enemies>1&raid_event.adds.up|raid_event.adds.in>40)
  if S.EyeBeam:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam fel_barrage 4"; end
  end
  -- abyssal_gaze,if=buff.fel_barrage.down&(active_enemies>1&raid_event.adds.up|raid_event.adds.in>40)&buff.demonsurge_abyssal_gaze.up
  if S.AbyssalGaze:IsReady() and (Player:BuffDown(S.FelBarrageBuff) and Player:Demonsurge("AbyssalGaze")) then
    if Cast(S.AbyssalGaze, Settings.Havoc.GCDasOffGCD.AbyssalGaze, nil, not IsInMeleeRange(20)) then return "abyssal_gaze fel_barrage 6"; end
  end
  -- essence_break,if=buff.fel_barrage.down&buff.metamorphosis.up
  if S.EssenceBreak:IsCastable() and (Player:BuffDown(S.FelBarrageBuff) and Player:BuffUp(S.MetamorphosisBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break fel_barrage 8"; end
  end
  -- death_sweep,if=buff.fel_barrage.down
  if S.DeathSweep:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fel_barrage 10"; end
  end
  -- immolation_aura,if=buff.unbound_chaos.down&(active_enemies>2|buff.fel_barrage.up)&(!talent.inertia|cooldown.eye_beam.remains>recharge_time+3)
  if ImmoAbility:IsCastable() and (Player:BuffDown(S.UnboundChaosBuff) and (Enemies8yCount > 2 or Player:BuffUp(S.FelBarrageBuff)) and (not S.Inertia:IsAvailable() or S.EyeBeam:CooldownRemains() > ImmoAbility:Recharge() + 3)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fel_barrage 12"; end
  end
  -- glaive_tempest,if=buff.fel_barrage.down&active_enemies>1
  if S.GlaiveTempest:IsReady() and (Player:BuffDown(S.FelBarrageBuff) and Enemies8yCount > 1) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fel_barrage 14"; end
  end
  -- blade_dance,if=buff.fel_barrage.down
  if S.BladeDance:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fel_barrage 16"; end
  end
  -- fel_barrage,if=fury>100&(raid_event.adds.in>90|raid_event.adds.in<gcd.max|raid_event.adds.remains>4&active_enemies>2)
  if S.FelBarrage:IsReady() and (Player:Fury() > 100) then
    if Cast(S.FelBarrage, Settings.Havoc.GCDasOffGCD.FelBarrage, nil, not IsInMeleeRange(8)) then return "fel_barrage fel_barrage 18"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up&fury>20&buff.fel_barrage.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Player:Fury() > 20 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fel_barrage 20"; end
  end
  -- sigil_of_flame,if=fury.deficit>40&buff.fel_barrage.up&(!talent.student_of_suffering|cooldown.eye_beam.remains>30)
  if S.SigilofFlame:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff) and (not S.StudentofSuffering:IsAvailable() or S.EyeBeam:CooldownRemains() > 30)) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame fel_barrage 22"; end
  end
  -- sigil_of_doom,if=fury.deficit>40&buff.fel_barrage.up
  if S.SigilofDoom:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom fel_barrage 24"; end
  end
  -- felblade,if=buff.fel_barrage.up&fury.deficit>40&action.felblade.cooldown_react
  if S.Felblade:IsCastable() and (Player:BuffUp(S.FelBarrageBuff) and Player:FuryDeficit() > 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_barrage 26"; end
  end
  -- death_sweep,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.DeathSweep:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fel_barrage 28"; end
  end
  -- glaive_tempest,if=fury-variable.gcd_drain-30>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.GlaiveTempest:IsReady() and (Player:Fury() - VarGCDDrain - 30 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fel_barrage 30"; end
  end
  -- blade_dance,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.BladeDance:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fel_barrage 32"; end
  end
  -- arcane_torrent,if=fury.deficit>40&buff.fel_barrage.up
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent fel_barrage 34"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fel_barrage 36"; end
  end
  -- the_hunt,if=fury>40&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>80)
  if CDsON() and S.TheHunt:IsCastable() and (Player:Fury() > 40) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt fel_barrage 38"; end
  end
  -- annihilation,if=fury-variable.gcd_drain-40>20&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.Annihilation:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fel_barrage 40"; end
  end
  -- chaos_strike,if=fury-variable.gcd_drain-40>20&(cooldown.fel_barrage.remains&cooldown.fel_barrage.remains<10&fury>100|buff.fel_barrage.up&(buff.fel_barrage.remains*variable.fury_gen-buff.fel_barrage.remains*32)>0)
  if S.ChaosStrike:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (S.FelBarrage:CooldownDown() and S.FelBarrage:CooldownRemains() < 10 and Player:Fury() > 100 or Player:BuffUp(S.FelBarrageBuff) and (Player:BuffRemains(S.FelBarrageBuff) * VarFuryGen - Player:BuffRemains(S.FelBarrageBuff) * 32) > 0)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike fel_barrage 42"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite fel_barrage 44"; end
  end
end

local function Meta()
  -- death_sweep,if=buff.metamorphosis.remains<gcd.max|(hero_tree.felscarred&talent.chaos_theory&talent.essence_break&((cooldown.metamorphosis.up&(!buff.unbound_chaos.up|!talent.inertia))|prev_gcd.1.metamorphosis)&buff.demonsurge.stack=0)
  if S.DeathSweep:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() or (Player:HeroTreeID() == 34 and S.ChaosTheory:IsAvailable() and S.EssenceBreak:IsAvailable() and ((S.Metamorphosis:CooldownUp() and (not Player:BuffUp(S.UnboundChaosBuff) or not S.Inertia:IsAvailable())) or Player:PrevGCD(1, S.Metamorphosis)) and Player:BuffDown(S.DemonsurgeBuff))) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta 2"; end
  end
  -- annihilation,if=buff.metamorphosis.remains<gcd.max|debuff.essence_break.remains&debuff.essence_break.remains<0.5
  -- Note: Adding 0.5s extra to the debuff check to account for player latency.
  if S.Annihilation:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() or Target:DebuffUp(S.EssenceBreakDebuff) and Target:DebuffRemains(S.EssenceBreakDebuff) < 1) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 4"; end
  end
  -- annihilation,if=(hero_tree.felscarred&buff.demonsurge_annihilation.up&(talent.restless_hunter|!talent.chaos_theory|buff.chaos_theory.up))&(cooldown.eye_beam.remains<gcd.max*3&cooldown.blade_dance.remains|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and ((Player:HeroTreeID() == 34 and Player:Demonsurge("Annihilation") and (S.RestlessHunter:IsAvailable() or not S.ChaosTheory:IsAvailable() or Player:BuffUp(S.ChaosTheoryBuff))) and (S.EyeBeam:CooldownRemains() < Player:GCD() * 3 and S.BladeDance:CooldownDown() or S.Metamorphosis:CooldownRemains() < Player:GCD() * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 6"; end
  end
  if S.FelRush:IsCastable() and UseFelRush() and (
    -- fel_rush,if=buff.inertia_trigger.up&talent.inertia&cooldown.metamorphosis.up&(!hero_tree.felscarred|cooldown.eye_beam.remains)
    (Player:BuffUp(S.InertiaBuff) and S.Inertia:IsAvailable() and S.Metamorphosis:CooldownUp() and (Player:HeroTreeID() ~= 34 or S.EyeBeam:CooldownDown())) or
    -- fel_rush,if=buff.inertia_trigger.up&talent.inertia&cooldown.blade_dance.remains<gcd.max*3&(!hero_tree.felscarred|cooldown.eye_beam.remains)
    (Player:BuffUp(S.InertiaBuff) and S.Inertia:IsAvailable() and S.BladeDance:CooldownRemains() < Player:GCD() * 3 and (Player:HeroTreeID() ~= 34 or S.EyeBeam:CooldownDown())) or
    -- fel_rush,if=talent.momentum&buff.momentum.remains<gcd.max*2
    (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) < Player:GCD() * 2)
  ) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush meta 8"; end
  end
  -- immolation_aura,if=charges=2&active_enemies>1&debuff.essence_break.down
  if ImmoAbility:IsCastable() and (ImmoAbility:Charges() == 2 and Enemies8yCount > 1 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 10"; end
  end
  -- annihilation,if=(buff.inner_demon.up)&(cooldown.eye_beam.remains<gcd.max*3&cooldown.blade_dance.remains|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and (S.EyeBeam:CooldownRemains() < Player:GCD() * 3 and S.BladeDance:CooldownDown() or S.Metamorphosis:CooldownRemains() < Player:GCD() * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 12"; end
  end
  -- essence_break,if=time<20&buff.thrill_of_the_fight_damage.remains>gcd.max*4&buff.metamorphosis.remains>=gcd.max*2&cooldown.metamorphosis.up&cooldown.death_sweep.remains<=gcd.max&buff.inertia.up
  if S.EssenceBreak:IsCastable() and (CombatTime < 20 and Player:BuffRemains(S.ThrilloftheFightDmgBuff) > Player:GCD() * 4 and Player:BuffRemains(S.MetamorphosisBuff) >= Player:GCD() * 2 and S.Metamorphosis:CooldownUp() and S.DeathSweep:CooldownRemains() <= Player:GCD() and Player:BuffUp(S.InertiaBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break meta 14"; end
  end
  -- essence_break,if=fury>20&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2)&(buff.unbound_chaos.down|buff.inertia.up|!talent.inertia)&buff.out_of_range.remains<gcd.max&(!talent.shattered_destiny|cooldown.eye_beam.remains>4)&(!hero_tree.felscarred|active_enemies>1|cooldown.metamorphosis.remains>5&cooldown.eye_beam.remains)|fight_remains<10
  if S.EssenceBreak:IsCastable() and (Player:Fury() > 20 and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 2) and (Player:BuffDown(S.UnboundChaosBuff) or Player:BuffUp(S.InertiaBuff) or not S.Inertia:IsAvailable()) and (not S.ShatteredDestiny:IsAvailable() or S.EyeBeam:CooldownRemains() > 4) and (Player:HeroTreeID() ~= 34 or Enemies8yCount > 1 or S.Metamorphosis:CooldownRemains() > 5 and S.EyeBeam:CooldownDown()) or BossFightRemains < 10) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break meta 16"; end
  end
  -- immolation_aura,if=cooldown.blade_dance.remains&talent.inertia&buff.metamorphosis.remains>10&hero_tree.felscarred&full_recharge_time<gcd.max*2&buff.unbound_chaos.down&debuff.essence_break.down
  if ImmoAbility:IsCastable() and (S.BladeDance:CooldownDown() and S.Inertia:IsAvailable() and Player:BuffRemains(S.MetamorphosisBuff) > 10 and Player:HeroTreeID() == 34 and ImmoAbility:FullRechargeTime() < Player:GCD() * 2 and Player:BuffDown(S.UnboundChaosBuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 18"; end
  end
  -- sigil_of_doom,if=cooldown.blade_dance.remains&debuff.essence_break.down
  if S.SigilofDoom:IsCastable() and (S.BladeDance:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom meta 20"; end
  end
  -- immolation_aura,if=buff.demonsurge.up&buff.demonsurge.remains<gcd.max*3&buff.demonsurge_consuming_fire.up
  if ImmoAbility:IsCastable() and (Player:BuffUp(S.DemonsurgeBuff) and Player:BuffRemains(S.DemonsurgeBuff) < Player:GCD() * 3 and Player:Demonsurge("ConsumingFire")) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 22"; end
  end
  -- immolation_aura,if=debuff.essence_break.down&cooldown.blade_dance.remains>gcd.max+0.5&buff.unbound_chaos.down&talent.inertia&buff.inertia.down&full_recharge_time+3<cooldown.eye_beam.remains&buff.metamorphosis.remains>5
  if ImmoAbility:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownRemains() > Player:GCD() + 0.5 and Player:BuffDown(S.UnboundChaosBuff) and S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and ImmoAbility:FullRechargeTime() + 3 < S.EyeBeam:CooldownRemains() and Player:BuffRemains(S.MetamorphosisBuff) > 5) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 24"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep meta 26"; end
  end
  -- eye_beam,if=debuff.essence_break.down&buff.inner_demon.down
  if S.EyeBeam:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff)) then
    if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam meta 28"; end
  end
  -- abyssal_gaze,if=debuff.essence_break.down&buff.inner_demon.down&buff.demonsurge_abyssal_gaze.up
  if S.AbyssalGaze:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and Player:Demonsurge("AbyssalGaze")) then
    if Cast(S.AbyssalGaze, Settings.Havoc.GCDasOffGCD.AbyssalGaze, nil, not IsInMeleeRange(20)) then return "abyssal_gaze meta 30"; end
  end
  -- glaive_tempest,if=debuff.essence_break.down&(cooldown.blade_dance.remains>gcd.max*2|fury>60)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.BladeDance:CooldownRemains() > Player:GCD() * 2 or Player:Fury() > 60)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest meta 32"; end
  end
  -- sigil_of_flame,if=active_enemies>2&debuff.essence_break.down
  if S.SigilofFlame:IsCastable() and (Enemies8yCount > 2 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 34"; end
  end
  -- throw_glaive,if=talent.soulscar&talent.furious_throws&active_enemies>1&debuff.essence_break.down
  if S.ThrowGlaive:IsCastable() and (S.Soulscar:IsAvailable() and S.FuriousThrows:IsAvailable() and Enemies8yCount > 1 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive meta 36"; end
  end
  -- annihilation,if=cooldown.blade_dance.remains|fury>60|soul_fragments.total>0|buff.metamorphosis.remains<5&cooldown.felblade.up
  local TotalSoulFragments = DemonHunter.Souls.AuraSouls + DemonHunter.Souls.IncomingSouls
  if S.Annihilation:IsReady() and (S.BladeDance:CooldownDown() or Player:Fury() > 60 or TotalSoulFragments > 0 or Player:BuffRemains(S.MetamorphosisBuff) < 5 and S.Felblade:CooldownUp()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 38"; end
  end
  -- sigil_of_flame,if=buff.metamorphosis.remains>5&buff.out_of_range.down
  if S.SigilofFlame:IsCastable() and (Player:BuffRemains(S.MetamorphosisBuff) > 5 and Target:IsInRange(30)) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 40"; end
  end
  -- felblade,if=(buff.out_of_range.down|fury.deficit>40)&action.felblade.cooldown_react
  if S.Felblade:IsCastable() and (Target:IsInRange(8) or Player:FuryDeficit() > 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 42"; end
  end
  -- sigil_of_flame,if=debuff.essence_break.down&buff.out_of_range.down
  if S.SigilofFlame:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and Target:IsInRange(30)) then
    if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame meta 44"; end
  end
  -- immolation_aura,if=buff.out_of_range.down&recharge_time<(cooldown.eye_beam.remains<?buff.metamorphosis.remains)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
  if ImmoAbility:IsCastable() and (IsInMeleeRange(8) and ImmoAbility:Recharge() < (mathmax(S.EyeBeam:CooldownRemains(), Player:BuffRemains(S.MetamorphosisBuff)))) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura meta 46"; end
  end
  -- fel_rush,if=talent.momentum
  if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable()) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush meta 48"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation meta 50"; end
  end
  -- throw_glaive,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.ThrowGlaive:IsReady() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < S.EyeBeam:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Target:IsInRange(8) and Enemies8yCount > 1) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 58"; end
  end
  -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and S.FelRush:Recharge() < S.EyeBeam:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01) and IsInMeleeRange(15) and Enemies8yCount > 1) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush meta 60"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite meta 36"; end
  end
end

local function Opener()
  -- Manually added: metamorphosis,if=prev_gcd.1.vengeful_retreat
  -- Note: Timing is super tight for the natural opener Meta, so we'll put it here.
  if CDsON() and S.Metamorphosis:IsCastable() and Player:PrevOffGCDP(1, S.VengefulRetreat) then
    if Cast(S.Metamorphosis, nil, nil, not IsInMeleeRange(40)) then return "metamorphosis opener 1"; end
  end
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion opener 2"; end
    end
  end
  -- vengeful_retreat,use_off_gcd=1,if=(prev_gcd.1.death_sweep&buff.initiative.remains<2&buff.inner_demon.down|buff.initiative.remains<0.5&debuff.initiative_tracker.up&(!talent.inertia|buff.unbound_chaos.down))&((!talent.essence_break&talent.shattered_destiny)|(talent.essence_break&!talent.shattered_destiny)|(!talent.shattered_destiny&!talent.essence_break))|prev_gcd.2.death_sweep&prev_gcd.1.annihilation
  -- Note: Added 0.5s to Initiative buff check to account for player latency.
  -- TODO: Handle debuff.initiative_tracker.up.
  if S.VengefulRetreat:IsCastable() and ((Player:PrevGCD(1, S.DeathSweep) and Player:BuffRemains(S.InitiativeBuff) < 2 and Player:BuffDown(S.InnerDemonBuff) or Player:BuffRemains(S.InitiativeBuff) < 1 and (not S.Inertia:IsAvailable() or Player:BuffDown(S.UnboundChaosBuff))) and ((not S.EssenceBreak:IsAvailable() and S.ShatteredDestiny:IsAvailable()) or (S.EssenceBreak:IsAvailable() and not S.ShatteredDestiny:IsAvailable()) or (not S.ShatteredDestiny:IsAvailable() and not S.EssenceBreak:IsAvailable())) or Player:PrevGCD(2, S.DeathSweep) and Player:PrevGCD(1, S.Annihilation)) then
    if S.Metamorphosis:IsCastable() then
      if HR.CastQueue(S.VengefulRetreat, S.Metamorphosis) then return "vengeful_retreat and metamorphosis opener 4"; end
    else
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat opener 4"; end
    end
  end
  -- vengeful_retreat,use_off_gcd=1,if=buff.metamorphosis.up&cooldown.metamorphosis.remains&cooldown.essence_break.up&cooldown.eye_beam.remains&talent.shattered_destiny&talent.essence_break&(cooldown.sigil_of_spite.remains|!hero_tree.aldrachi_reaver)
  if S.VengefulRetreat:IsCastable() and (Player:BuffUp(S.MetamorphosisBuff) and S.Metamorphosis:CooldownDown() and S.EssenceBreak:CooldownUp() and S.EyeBeam:CooldownDown() and S.ShatteredDestiny:IsAvailable() and S.EssenceBreak:IsAvailable() and (S.SigilofSpite:CooldownDown() or Player:HeroTreeID() ~= 35)) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat opener 6"; end
  end
  -- annihilation,if=hero_tree.felscarred&buff.demonsurge_annihilation.up&talent.restless_hunter,line_cd=10
  -- TODO: Handle line_cd. May not matter, due to Demonsurge check.
  if S.Annihilation:IsCastable() and (Player:HeroTreeID() == 34 and Player:Demonsurge("Annihilation") and S.RestlessHunter:IsAvailable()) then
    if Cast(S.Annihilation, nil, nil, not Target:IsInRange(30)) then return "annihilation opener 8"; end
  end
  -- sigil_of_doom,if=talent.essence_break&prev_gcd.1.metamorphosis
  if S.SigilofDoom:IsCastable() and (S.EssenceBreak:IsAvailable() and Player:PrevGCD(1, S.Metamorphosis)) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_doom opener 10"; end
  end
  -- annihilation,if=!hero_tree.felscarred&buff.inner_demon.up&!talent.shattered_destiny,line_cd=10
  if S.Annihilation:IsCastable() and S.Annihilation:TimeSinceLastCast() >= 10 and (Player:HeroTreeID() ~= 34 and Player:BuffUp(S.InnerDemonBuff) and not S.ShatteredDestiny:IsAvailable()) then
    if Cast(S.Annihilation, nil, nil, not Target:IsInRange(30)) then return "annihilation opener 12"; end
  end
  if S.FelRush:IsCastable() and UseFelRush() and (
    -- fel_rush,if=talent.momentum&buff.momentum.remains<6
    (S.Momentum:IsAvailable() and Player:BuffRemains(S.MomentumBuff) < 6) or
    -- fel_rush,if=talent.inertia&buff.unbound_chaos.up&talent.a_fire_inside&(buff.inertia.down&buff.metamorphosis.up&!hero_tree.felscarred|hero_tree.felscarred&(buff.metamorphosis.down&charges>1|prev_gcd.1.eye_beam|buff.demonsurge.stack>=5|charges=2&buff.unbound_chaos.down))&debuff.essence_break.down
    (S.Inertia:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and S.AFireInside:IsAvailable() and (Player:BuffDown(S.InertiaBuff) and Player:BuffUp(S.MetamorphosisBuff) and Player:HeroTreeID() ~= 34 or Player:HeroTreeID() == 34 and (Player:BuffDown(S.MetamorphosisBuff) and S.FelRush:Charges() > 1 or Player:PrevGCD(1, S.EyeBeam) or Player:BuffStack(S.DemonsurgeBuff) >= 5 or S.FelRush:Charges() == 2 and Player:BuffDown(S.UnboundChaosBuff))) and Target:DebuffDown(S.EssenceBreakDebuff)) or
    -- fel_rush,if=talent.inertia&buff.unbound_chaos.up&!talent.a_fire_inside&buff.metamorphosis.up&(cooldown.metamorphosis.up|cooldown.eye_beam.remains|talent.essence_break&cooldown.essence_break.remains)&(hero_tree.felscarred|buff.inner_demon.down)
    (S.Inertia:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and not S.AFireInside:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff) and (S.Metamorphosis:CooldownUp() or S.EyeBeam:CooldownDown() or S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownDown()) and (Player:HeroTreeID() == 34 or Player:BuffDown(S.InnerDemonBuff))) or
    -- fel_rush,if=talent.inertia&buff.unbound_chaos.up&prev_gcd.1.sigil_of_doom&active_enemies>1
    (S.Inertia:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and Player:PrevGCD(1, S.SigilofDoom) and Enemies8yCount > 1)
  ) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush opener 14"; end
  end
  -- the_hunt,if=(buff.metamorphosis.up|!talent.shattered_destiny)&(!talent.initiative|buff.initiative.up|time>5)
  if S.TheHunt:IsCastable() and ((Player:BuffUp(S.MetamorphosisBuff) or not S.ShatteredDestiny:IsAvailable()) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5)) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt opener 16"; end
  end
  -- death_sweep,if=hero_tree.felscarred&talent.chaos_theory&buff.metamorphosis.up&buff.demonsurge.stack=0&!talent.restless_hunter
  if S.DeathSweep:IsCastable() and (Player:HeroTreeID() == 34 and S.ChaosTheory:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff) and Player:BuffDown(S.DemonsurgeBuff) and not S.RestlessHunter:IsAvailable()) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep opener 18"; end
  end
  -- annihilation,if=hero_tree.felscarred&buff.demonsurge_annihilation.up&!talent.essence_break,line_cd=10
  -- TODO: Handle line_cd. May not matter, due to Demonsurge check.
  if S.Annihilation:IsCastable() and (Player:HeroTreeID() == 34 and Player:Demonsurge("Annihilation") and not S.EssenceBreak:IsAvailable()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation opener 20"; end
  end
  -- felblade,if=(buff.metamorphosis.down|fury<40)&(!talent.a_fire_inside|hero_tree.aldrachi_reaver)&action.felblade.cooldown_react
  if S.Felblade:IsCastable() and ((Player:BuffDown(S.MetamorphosisBuff) or Player:Fury() < 40) and (not S.AFireInside:IsAvailable() or Player:HeroTreeID() == 35)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade opener 22"; end
  end
  -- reavers_glaive,if=debuff.reavers_mark.down&debuff.essence_break.down
  if S.ReaversGlaive:IsCastable() and (Target:DebuffDown(S.ReaversMarkDebuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.ReaversGlaive, nil, nil, not Target:IsInRange(50)) then return "reavers_glaive opener 24"; end
  end
  -- immolation_aura,if=talent.a_fire_inside&(talent.inertia|talent.ragefire|talent.burning_wound)&buff.metamorphosis.down&(buff.unbound_chaos.down|hero_tree.felscarred)
  if ImmoAbility:IsCastable() and (S.AFireInside:IsAvailable() and (S.Inertia:IsAvailable() or S.Ragefire:IsAvailable() or S.BurningWound:IsAvailable()) and Player:BuffDown(S.MetamorphosisBuff) and (Player:BuffDown(S.UnboundChaosBuff) or Player:HeroTreeID() == 34)) then
    if Cast(ImmoAbility, nil, nil, not IsInMeleeRange(8)) then return "immolation_aura opener 26"; end
  end
  -- immolation_aura,if=talent.inertia&buff.unbound_chaos.down&buff.metamorphosis.up&debuff.essence_break.down&cooldown.blade_dance.remains&(buff.inner_demon.down|hero_tree.felscarred&buff.demonsurge_annihilation.down)&buff.demonsurge.stack<5
  if ImmoAbility:IsCastable() and (S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and Player:BuffUp(S.MetamorphosisBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown() and (Player:BuffDown(S.InnerDemonBuff) or Player:HeroTreeID() == 34 and not Player:Demonsurge("Annihilation")) and Player:BuffDown(S.DemonsurgeBuff) and Player:BuffStack(S.DemonsurgeBuff) < 5) then
    if Cast(ImmoAbility, nil, nil, not IsInMeleeRange(8)) then return "immolation_aura opener 28"; end
  end
  -- blade_dance,if=buff.glaive_flurry.up&!talent.shattered_destiny
  if S.BladeDance:IsCastable() and (Player:BuffUp(S.GlaiveFlurryBuff) and not S.ShatteredDestiny:IsAvailable()) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance opener 30"; end
  end
  -- chaos_strike,if=buff.rending_strike.up&!talent.shattered_destiny
  if S.ChaosStrike:IsCastable() and (Player:BuffUp(S.RendingStrikeBuff) and not S.ShatteredDestiny:IsAvailable()) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike opener 32"; end
  end
  -- metamorphosis,if=buff.metamorphosis.up&cooldown.blade_dance.remains>gcd.max*2&buff.inner_demon.down&(!hero_tree.felscarred&(!talent.restless_hunter|prev_gcd.1.death_sweep)|buff.demonsurge.stack=2)&(cooldown.essence_break.remains|hero_tree.felscarred|talent.shattered_destiny|!talent.essence_break)
  if CDsON() and S.Metamorphosis:IsCastable() and (Player:BuffUp(S.MetamorphosisBuff) and S.BladeDance:CooldownRemains() > Player:GCD() * 2 and Player:BuffDown(S.InnerDemonBuff) and (Player:HeroTreeID() ~= 34 and (not S.RestlessHunter:IsAvailable() or Player:PrevGCD(1, S.DeathSweep)) or Player:BuffStack(S.DemonsurgeBuff) == 2) and (S.EssenceBreak:CooldownDown() or Player:HeroTreeID() == 34 or S.ShatteredDestiny:IsAvailable() or not S.EssenceBreak:IsAvailable())) then
    if Cast(S.Metamorphosis, nil, nil, not IsInMeleeRange(40)) then return "metamorphosis opener 34"; end
  end
  -- sigil_of_spite,if=hero_tree.felscarred|debuff.reavers_mark.up&(!talent.cycle_of_hatred|cooldown.eye_beam.remains&cooldown.metamorphosis.remains)
  if S.SigilofSpite:IsCastable() and (Player:HeroTreeID() == 34 or Target:DebuffUp(S.ReaversMarkDebuff) and (not S.CycleofHatred:IsAvailable() or S.EyeBeam:CooldownDown() and S.Metamorphosis:CooldownDown())) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not IsInMeleeRange(30)) then return "sigil_of_spite opener 36"; end
  end
  -- sigil_of_doom,if=buff.inner_demon.down&debuff.essence_break.down&cooldown.blade_dance.remains
  if S.SigilofDoom:IsCastable() and (Player:BuffDown(S.InnerDemonBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown()) then
    if Cast(S.SigilofDoom, nil, Settings.CommonsDS.DisplayStyle.Sigils, not IsInMeleeRange(30)) then return "sigil_of_doom opener 38"; end
  end
  -- eye_beam,if=buff.metamorphosis.down|debuff.essence_break.down&buff.inner_demon.down&(cooldown.blade_dance.remains|talent.essence_break&cooldown.essence_break.up)
  if S.EyeBeam:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff) or Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and (S.BladeDance:CooldownDown() or S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownUp())) then
    if Cast(S.EyeBeam, nil, nil, not IsInMeleeRange(20)) then return "eye_beam opener 40"; end
  end
  -- abyssal_gaze,if=debuff.essence_break.down&cooldown.blade_dance.remains&buff.inner_demon.down&buff.demonsurge_abyssal_gaze.up
  if S.AbyssalGaze:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown() and Player:BuffDown(S.InnerDemonBuff) and Player:Demonsurge("AbyssalGaze")) then
    if Cast(S.AbyssalGaze, nil, nil, not IsInMeleeRange(20)) then return "abyssal_gaze opener 42"; end
  end
  -- essence_break,if=(cooldown.blade_dance.remains<gcd.max&!hero_tree.felscarred&!talent.shattered_destiny&buff.metamorphosis.up|cooldown.eye_beam.remains&cooldown.metamorphosis.remains)&(!hero_tree.felscarred|buff.demonsurge_annihilation.down)
  if S.EssenceBreak:IsCastable() and ((S.BladeDance:CooldownRemains() < Player:GCD() and Player:HeroTreeID() ~= 34 and not S.ShatteredDestiny:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff) or S.EyeBeam:CooldownDown() and S.Metamorphosis:CooldownDown()) and (Player:HeroTreeID() ~= 34 or not Player:Demonsurge("Annihilation"))) then
    if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break opener 44"; end
  end
  -- essence_break,if=talent.restless_hunter&buff.metamorphosis.up&buff.inner_demon.down&(!hero_tree.felscarred|buff.demonsurge_annihilation.down)
  if S.EssenceBreak:IsCastable() and (S.RestlessHunter:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff) and Player:BuffDown(S.InnerDemonBuff) and (Player:HeroTreeID() ~= 34 or not Player:Demonsurge("Annihilation"))) then
    if Cast(S.EssenceBreak, nil, nil, not IsInMeleeRange(10)) then return "essence_break opener 46"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep opener 48"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation opener 50"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite opener 52"; end
  end
end

--- ===== APL Main =====
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

    -- Calculate CombatTime
    CombatTime = HL.CombatTime()

    -- ImmolationAura or ConsumingFire?
    ImmoAbility = S.ConsumingFire:IsLearned() and S.ConsumingFire or S.ImmolationAura
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
    -- variable,name=rg_inc,op=set,value=buff.rending_strike.down&buff.glaive_flurry.up&cooldown.blade_dance.up&gcd.remains=0|variable.rg_inc&prev_gcd.1.death_sweep
    VarRGInc = Player:BuffDown(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff) and S.BladeDance:CooldownUp() or VarRGInc and Player:PrevGCD(1, S.DeathSweep)
    -- pick_up_fragment,use_off_gcd=1
    -- variable,name=fel_barrage,op=set,value=talent.fel_barrage&(cooldown.fel_barrage.remains<gcd.max*7&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in<gcd.max*7|raid_event.adds.in>90)&(cooldown.metamorphosis.remains|active_enemies>2)|buff.fel_barrage.up)&!(active_enemies=1&!raid_event.adds.exists)
    VarFelBarrage = S.FelBarrage:IsAvailable() and (S.FelBarrage:CooldownRemains() < Player:GCD() * 7 and (S.Metamorphosis:CooldownDown() or Enemies12yCount > 2) or Player:BuffUp(S.FelBarrage))
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(S.Disrupt, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- fel_rush,if=buff.unbound_chaos.up&buff.unbound_chaos.remains<gcd.max*2&(action.immolation_aura.charges>0|action.immolation_aura.recharge_time<5)&cooldown.metamorphosis.remains>10
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Player:BuffRemains(S.UnboundChaosBuff) < Player:GCD() * 2 and (ImmoAbility:Charges() > 0 or ImmoAbility:Recharge() < 5) and S.Metamorphosis:CooldownRemains() > 10) then
      if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush main 4"; end
    end
    -- chaos_strike,if=buff.rending_strike.up&buff.glaive_flurry.up&(variable.rg_ds=2|active_enemies>2)
    -- annihilation,if=buff.rending_strike.up&buff.glaive_flurry.up&(variable.rg_ds=2|active_enemies>2)
    if Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff) and (VarRGDS == 2 or Enemies8yCount > 2) then
      if S.ChaosStrike:IsReady() then
        if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike main 6"; end
      end
      if S.Annihilation:IsReady() then
        if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation main 8"; end
      end
    end
    -- reavers_glaive,if=buff.glaive_flurry.down&buff.rending_strike.down&buff.thrill_of_the_fight_damage.remains<gcd.max*4+(variable.rg_ds=2)+(cooldown.the_hunt.remains<gcd.max*3)*3+(cooldown.eye_beam.remains<gcd.max*3&talent.shattered_destiny)*3&(variable.rg_ds=0|variable.rg_ds=1&cooldown.blade_dance.up|variable.rg_ds=2&cooldown.blade_dance.remains)&(buff.thrill_of_the_fight_damage.up|!prev_gcd.1.death_sweep|!variable.rg_inc)&active_enemies<3&!action.reavers_glaive.last_used<5&debuff.essence_break.down|fight_remains<10
    if S.ReaversGlaive:IsReady() and (Player:BuffDown(S.GlaiveFlurryBuff) and Player:BuffDown(S.RendingStrikeBuff) and Player:BuffRemains(S.ThrilloftheFightDmgBuff) < Player:GCD() * 4 + num(VarRGDS == 2) + num(S.TheHunt:CooldownRemains() < Player:GCD() * 3) * 3 + num(S.EyeBeam:CooldownRemains() < Player:GCD() * 3 and S.ShatteredDestiny:IsAvailable()) * 3 and (VarRGDS == 0 or VarRGDS == 1 and S.BladeDance:CooldownUp() or VarRGDS == 2 and S.BladeDance:CooldownDown()) and (Player:BuffUp(S.ThrilloftheFightDmgBuff) or not Player:PrevGCD(1, S.DeathSweep) or not VarRGInc) and Enemies8yCount < 3 and S.ReaversGlaive:TimeSinceLastCast() >= 5 and Target:DebuffDown(S.EssenceBreakDebuff) or BossFightRemains < 10) then
      if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsInRange(50)) then return "reavers_glaive main 10"; end
    end
    -- reavers_glaive,if=buff.glaive_flurry.down&buff.rending_strike.down&buff.thrill_of_the_fight_damage.remains<4&(buff.thrill_of_the_fight_damage.up|!prev_gcd.1.death_sweep|!variable.rg_inc)&active_enemies>2|fight_remains<10
    if S.ReaversGlaive:IsReady() and (Player:BuffDown(S.GlaiveFlurryBuff) and Player:BuffDown(S.RendingStrikeBuff) and Player:BuffRemains(S.ThrilloftheFightDmgBuff) < 4 and (Player:BuffUp(S.ThrilloftheFightDmgBuff) or not Player:PrevGCD(1, S.DeathSweep) or not VarRGInc) and Enemies8yCount > 2 or BossFightRemains < 10) then
      if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsInRange(50)) then return "reavers_glaive main 12"; end
    end
    -- call_action_list,name=cooldown
    -- Note: CDsON check is within Cooldown(), as the function also includes trinkets and potions
    local ShouldReturn = Cooldown(); if ShouldReturn then return ShouldReturn; end
    -- run_action_list,name=opener,if=(cooldown.eye_beam.up|cooldown.metamorphosis.up|cooldown.essence_break.up)&time<15&(raid_event.adds.in>40)&buff.demonsurge.stack<5
    if (S.EyeBeam:CooldownUp() or S.Metamorphosis:CooldownUp() or S.EssenceBreak:CooldownUp()) and CombatTime < 15 and Player:BuffStack(S.DemonsurgeBuff) < 5 then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Opener()"; end
    end
    -- sigil_of_spite,if=debuff.essence_break.down&debuff.reavers_mark.remains>=2-talent.quickened_sigils
    if S.SigilofSpite:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Target:DebuffRemains(S.ReaversMarkDebuff) >= 2 - num(S.QuickenedSigils:IsAvailable())) then
      if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "elysian_decree main 14"; end
    end
    -- run_action_list,name=fel_barrage,if=variable.fel_barrage&raid_event.adds.up
    if VarFelBarrage then
      local ShouldReturn = FelBarrageFunc(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FelBarrageFunc()"; end
    end
    if ImmoAbility:IsReady() and (
      -- immolation_aura,if=active_enemies>2&talent.ragefire&buff.unbound_chaos.down&(!talent.fel_barrage|cooldown.fel_barrage.remains>recharge_time)&debuff.essence_break.down&cooldown.eye_beam.remains>recharge_time+5&(buff.metamorphosis.down|buff.metamorphosis.remains>5)
      (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > ImmoAbility:Recharge()) and Target:DebuffDown(S.EssenceBreakDebuff) and S.EyeBeam:CooldownRemains() > ImmoAbility:Recharge() + 5 and (Player:BuffDown(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff))) or
      -- immolation_aura,if=hero_tree.felscarred&cooldown.metamorphosis.remains<10&cooldown.eye_beam.remains<10&(buff.unbound_chaos.down|action.fel_rush.charges=0|(cooldown.eye_beam.remains<?cooldown.metamorphosis.remains)<5)&talent.a_fire_inside
      (Player:HeroTreeID() == 34 and S.Metamorphosis:CooldownRemains() < 10 and S.EyeBeam:CooldownRemains() < 10 and (Player:BuffDown(S.UnboundChaosBuff) or S.FelRush:Charges() == 0 or mathmax(S.EyeBeam:CooldownRemains(), S.Metamorphosis:CooldownRemains()) < 5) and S.AFireInside:IsAvailable()) or
      -- immolation_aura,if=cooldown.eye_beam.remains>24&buff.metamorphosis.down&debuff.essence_break.down
      (S.EyeBeam:CooldownRemains() > 24 and Player:BuffDown(S.MetamorphosisBuff) and Target:DebuffDown(S.EssenceBreakDebuff)) or
      -- immolation_aura,if=cooldown.eye_beam.remains<8&cooldown.blade_dance.remains&debuff.essence_break.down&buff.student_of_suffering.down
      (S.EyeBeam:CooldownRemains() < 8 and S.BladeDance:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.StudentofSufferingBuff)) or
      -- immolation_aura,if=active_enemies>2&talent.ragefire&raid_event.adds.up&raid_event.adds.remains<15&raid_event.adds.remains>5&debuff.essence_break.down
      (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff))
    ) then
      if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 16"; end
    end
    -- fel_rush,if=buff.unbound_chaos.up&active_enemies>2&(!talent.inertia|cooldown.eye_beam.remains+2>buff.unbound_chaos.remains)
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Enemies8yCount > 2 and (not S.Inertia:IsAvailable() or S.EyeBeam:CooldownRemains() + 2 > Player:BuffRemains(S.UnboundChaosBuff))) then
      if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush main 18"; end
    end
    -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&(cooldown.eye_beam.remains>15&gcd.remains<0.3|gcd.remains<0.2&cooldown.eye_beam.remains<=gcd.remains&(buff.unbound_chaos.up|action.immolation_aura.recharge_time>6|!talent.inertia|talent.momentum)&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2&(talent.inertia|talent.momentum|buff.metamorphosis.up)))&(!talent.student_of_suffering|cooldown.sigil_of_flame.remains)&time>10&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.cooldown.remains<gcd.max*3|trinket.1.cooldown.remains>20)|variable.trinket2_steroids&(trinket.2.cooldown.remains<gcd.max*3|trinket.2.cooldown.remains>20|talent.shattered_destiny))
    if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (S.EyeBeam:CooldownRemains() > 15 or S.EyeBeam:CooldownRemains() <= Player:GCDRemains() and (Player:BuffUp(S.UnboundChaosBuff) or ImmoAbility:Recharge() > 6 or not S.Inertia:IsAvailable() or S.Momentum:IsAvailable()) and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 2 and (S.Inertia:IsAvailable() or S.Momentum:IsAvailable() or Player:BuffUp(S.MetamorphosisBuff)))) and (not S.StudentofSuffering:IsAvailable() or S.SigilofFlame:CooldownDown()) and CombatTime > 10 and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids and (Trinket1:CooldownRemains() < Player:GCD() * 3 or Trinket1:CooldownRemains() > 20) or VarTrinket2Steroids and (Trinket2:CooldownRemains() < Player:GCD() * 3 or Trinket1:CooldownRemains() > 20 or S.ShatteredDestiny:IsAvailable()))) then
      if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat main 20"; end
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
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and S.BladeDance:CooldownRemains() < 4 and S.EyeBeam:CooldownRemains() > 5 and (ImmoAbility:Charges() > 0 or ImmoAbility:Recharge() + 2 < S.EyeBeam:CooldownRemains() or S.EyeBeam:CooldownRemains() > Player:BuffRemains(S.UnboundChaosBuff) - 2)) then
      if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush main 22"; end
    end
    -- fel_rush,if=talent.momentum&cooldown.eye_beam.remains<gcd.max*2
    if S.FelRush:IsCastable() and UseFelRush() and (S.Momentum:IsAvailable() and S.EyeBeam:CooldownRemains() < Player:GCD() * 2) then
      if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush main 24"; end
    end
    if ImmoAbility:IsCastable() and (
      -- immolation_aura,if=talent.a_fire_inside&(talent.unbound_chaos|talent.burning_wound)&buff.unbound_chaos.down&full_recharge_time<gcd.max*2&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets)
      (S.AFireInside:IsAvailable() and (S.UnboundChaos:IsAvailable() or S.BurningWound:IsAvailable()) and Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:FullRechargeTime() < Player:GCD() * 2) or
      -- immolation_aura,if=active_enemies>desired_targets&buff.unbound_chaos.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
      (Enemies8yCount > 1 and Player:BuffDown(S.UnboundChaosBuff)) or
      -- immolation_aura,if=talent.inertia&buff.unbound_chaos.down&cooldown.eye_beam.remains<5&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time&(!talent.essence_break|cooldown.essence_break.remains<5))&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.cooldown.remains<gcd.max*3|trinket.1.cooldown.remains>20)|variable.trinket2_steroids&(trinket.2.cooldown.remains<gcd.max*3|trinket.2.cooldown.remains>20))
      (S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) and S.EyeBeam:CooldownRemains() < 5 and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids and (Trinket1:CooldownRemains() < Player:GCD() * 3 or Trinket1:CooldownRemains() > 20) or VarTrinket2Steroids and (Trinket2:CooldownRemains() < Player:GCD() * 3 or Trinket2:CooldownRemains() > 20))) or
      -- immolation_aura,if=talent.inertia&buff.inertia.down&buff.unbound_chaos.down&recharge_time+5<cooldown.eye_beam.remains&cooldown.blade_dance.remains&cooldown.blade_dance.remains<4&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)&charges_fractional>1.00
      (S.Inertia:IsAvailable() and Player:BuffDown(S.InertiaBuff) and Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() + 5 < S.EyeBeam:CooldownRemains() and S.BladeDance:CooldownDown() and S.BladeDance:CooldownRemains() < 4 and ImmoAbility:ChargesFractional() > 1) or
      -- immolation_aura,if=fight_remains<15&cooldown.blade_dance.remains&(talent.inertia|talent.ragefire)
      (BossFightRemains < 15 and S.BladeDance:CooldownDown() and (S.Inertia:IsAvailable() or S.Ragefire:IsAvailable()))
    ) then
      if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 26"; end
    end
    -- sigil_of_flame,if=talent.student_of_suffering&cooldown.eye_beam.remains<gcd.max&(!talent.inertia|buff.inertia_trigger.up)&(cooldown.essence_break.remains<gcd.max*4|!talent.essence_break)&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*3)&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.cooldown.remains<gcd.max*3|trinket.1.cooldown.remains>20)|variable.trinket2_steroids&(trinket.2.cooldown.remains<gcd.max*3|trinket.2.cooldown.remains>20))
    -- Note: Removed Inertia check for usability.
    if S.SigilofFlame:IsCastable() and (S.StudentofSuffering:IsAvailable() and S.EyeBeam:CooldownRemains() < Player:GCD() and (S.EssenceBreak:CooldownRemains() < Player:GCD() * 4 or not S.EssenceBreak:IsAvailable()) and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 3) and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids and (Trinket1:CooldownRemains() < Player:GCD() * 3 or Trinket1:CooldownRemains() > 20) or VarTrinket2Steroids and (Trinket2:CooldownRemains() < Player:GCD() * 3 or Trinket2:CooldownRemains() > 20))) then
      if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 28"; end
    end
    -- eye_beam,if=!talent.essence_break&(!talent.chaotic_transformation|cooldown.metamorphosis.remains<5+3*talent.shattered_destiny|cooldown.metamorphosis.remains>10)&(active_enemies>desired_targets*2|raid_event.adds.in>30-talent.cycle_of_hatred.rank*13)&(!talent.initiative|cooldown.vengeful_retreat.remains>5|cooldown.vengeful_retreat.up|talent.shattered_destiny)&(!talent.student_of_suffering|cooldown.sigil_of_flame.remains)
    if S.EyeBeam:IsReady() and (not S.EssenceBreak:IsAvailable() and (not S.ChaoticTransformation:IsAvailable() or S.Metamorphosis:CooldownRemains() < 5 + 3 * num(S.ShatteredDestiny:IsAvailable()) or S.Metamorphosis:CooldownRemains() > 10) and (Enemies8yCount > 2) and (not S.Initiative:IsAvailable() or S.VengefulRetreat:CooldownRemains() > 5 or S.VengefulRetreat:CooldownUp() or S.ShatteredDestiny:IsAvailable()) and (not S.StudentofSuffering:IsAvailable() or S.SigilofFlame:CooldownDown())) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 30"; end
    end
    -- eye_beam,if=talent.essence_break&(cooldown.essence_break.remains<gcd.max*2+5*talent.shattered_destiny|talent.shattered_destiny&cooldown.essence_break.remains>10)&(cooldown.blade_dance.remains<7|raid_event.adds.up)&(!talent.initiative|cooldown.vengeful_retreat.remains>10|!talent.inertia&!talent.momentum|raid_event.adds.up)&(active_enemies+3>=desired_targets+raid_event.adds.count|raid_event.adds.in>30-talent.cycle_of_hatred.rank*6)&(!talent.inertia|buff.inertia_trigger.up|action.immolation_aura.charges=0&action.immolation_aura.recharge_time>5)&(!raid_event.adds.up|raid_event.adds.remains>8)&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.cooldown.remains<gcd.max*3|trinket.1.cooldown.remains>20)|variable.trinket2_steroids&(trinket.2.cooldown.remains<gcd.max*3|trinket.2.cooldown.remains>20))|fight_remains<10
    -- Note: Removing VR check to try to make the profile usable in HR.
    if S.EyeBeam:IsReady() and (S.EssenceBreak:IsAvailable() and (S.EssenceBreak:CooldownRemains() < Player:GCD() * 2 + 5 * num(S.ShatteredDestiny:IsAvailable()) or S.ShatteredDestiny:IsAvailable() and S.EssenceBreak:CooldownRemains() > 10) and (S.BladeDance:CooldownRemains() < 7 or Enemies20yCount > 1) and (not S.Inertia:IsAvailable() or Player:BuffUp(S.InertiaBuff) or ImmoAbility:Charges() == 0 and ImmoAbility:Recharge() > 5) and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids and (Trinket1:CooldownRemains() < Player:GCD() * 3 or Trinket1:CooldownRemains() > 20) or VarTrinket2Steroids and (Trinket2:CooldownRemains() < Player:GCD() * 3 or Trinket2:CooldownRemains() > 20)) or BossFightRemains < 10) then
      if Cast(S.EyeBeam, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "eye_beam main 32"; end
    end
    -- blade_dance,if=cooldown.eye_beam.remains>gcd.max*2&buff.rending_strike.down
    if S.BladeDance:IsReady() and (S.EyeBeam:CooldownRemains() > Player:GCD() * 2 and Player:BuffDown(S.RendingStrikeBuff)) then
      if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance main 34"; end
    end
    -- chaos_strike,if=buff.rending_strike.up
    if S.ChaosStrike:IsReady() and (Player:BuffUp(S.RendingStrikeBuff)) then
      if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike main 36"; end
    end
    -- felblade,if=buff.metamorphosis.down&fury.deficit>40&action.felblade.cooldown_react
    if S.Felblade:IsCastable() and (Player:BuffDown(S.MetamorphosisBuff) and Player:FuryDeficit() > 40) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 38"; end
    end
    -- glaive_tempest,if=active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10
    if S.GlaiveTempest:IsReady() then
      if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest main 40"; end
    end
    -- sigil_of_flame,if=active_enemies>3&!talent.student_of_suffering|buff.out_of_range.down&talent.art_of_the_glaive
    if S.SigilofFlame:IsCastable() and (Enemies8yCount > 3 and not S.StudentofSuffering:IsAvailable() or Target:IsInRange(30) and S.ArtoftheGlaive:IsAvailable()) then
      if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 42"; end
    end
    -- chaos_strike,if=debuff.essence_break.up
    if S.ChaosStrike:IsReady() and (Target:DebuffUp(S.EssenceBreakDebuff)) then
      if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike main 44"; end
    end
    -- felblade,if=(buff.out_of_range.down|fury.deficit>40)&action.felblade.cooldown_react
    if S.Felblade:IsCastable() and (Target:IsInRange(8) or Player:FuryDeficit() > 40) then
      if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade main 46"; end
    end
    -- throw_glaive,if=active_enemies>1&talent.furious_throws
    if S.ThrowGlaive:IsReady() and (Enemies8yCount > 1 and S.FuriousThrows:IsAvailable()) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive main 48"; end
    end
    -- chaos_strike,if=cooldown.eye_beam.remains>gcd.max*2|fury>80|talent.cycle_of_hatred
    if S.ChaosStrike:IsReady() and (S.EyeBeam:CooldownRemains() > Player:GCD() * 2 or Player:Fury() > 80 or S.CycleofHatred:IsAvailable()) then
      if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike main 50"; end
    end
    -- immolation_aura,if=!talent.inertia&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets&active_enemies>2)
    if ImmoAbility:IsCastable() and (not S.Inertia:IsAvailable()) then
      if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura main 52"; end
    end
    -- sigil_of_flame,if=buff.out_of_range.down&debuff.essence_break.down&!talent.student_of_suffering&(!talent.fel_barrage|cooldown.fel_barrage.remains>25|(active_enemies=1&!raid_event.adds.exists))
    if S.SigilofFlame:IsCastable() and (Target:IsInRange(30) and Target:DebuffDown(S.EssenceBreakDebuff) and not S.StudentofSuffering:IsAvailable() and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > 25 or Enemies8yCount == 1)) then
      if Cast(S.SigilofFlame, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_flame main 54"; end
    end
    -- demons_bite
    if S.DemonsBite:IsCastable() then
      if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite main 56"; end
    end
    -- throw_glaive,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
    if S.ThrowGlaive:IsReady() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < S.EyeBeam:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Target:IsInRange(8) and Enemies8yCount > 1) then
      if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not IsInMeleeRange(5)) then return "throw_glaive main 58"; end
    end
    -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&active_enemies>1
    if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < S.EyeBeam:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (S.EyeBeam:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Enemies8yCount > 1) then
      if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush main 60"; end
    end
    -- arcane_torrent,if=buff.out_of_range.down&debuff.essence_break.down&fury<100
    if CDsON() and S.ArcaneTorrent:IsCastable() and (Target:IsInRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:Fury() < 100) then
      if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent main 62"; end
    end
    -- Show pooling if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.BurningWoundDebuff:RegisterAuraTracking()

  HR.Print("Havoc Demon Hunter rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(577, APL, Init)
