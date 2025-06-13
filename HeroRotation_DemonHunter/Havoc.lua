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
  I.GeargrindersSpareKeys:ID(),
  I.GrimCodex:ID(),
  I.HouseofCards:ID(),
  I.JunkmaestrosMegaMagnet:ID(),
  I.MadQueensMandate:ID(),
  I.RavenousHoneyBuzzer:ID(),
  I.SignetofthePriory:ID(),
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
local VarFuryGen
local VarTrinketPacemakerProc
local VarT334P, VarT334PMagnet
local VarHeroTree = Player:HeroTreeID()
local CombatTime = 0
local BossFightRemains = 11111
local FightRemains = 11111
local ImmoAbility
local SigilAbility
local BeamAbility
local EnemiesMelee, Enemies8y, Enemies12y, Enemies20y
local EnemiesMeleeCount, Enemies8yCount, Enemies12yCount, Enemies20yCount

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket1Range, VarTrinket1CastTime
local VarTrinket2Spell, VarTrinket2Range, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Steroids, VarTrinket2Steroids
local VarTrinket1Crit, VarTrinket2Crit
local VarSpecialTrinket
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

  VarTrinket1Steroids = VarTrinket1CD > 0 and Trinket1:HasStatAnyDps() and VarTrinket1ID ~= I.ImprovisedSeaforiumPacemaker:ID()
  VarTrinket2Steroids = VarTrinket2CD > 0 and Trinket2:HasStatAnyDps() and VarTrinket2ID ~= I.ImprovisedSeaforiumPacemaker:ID()

  VarTrinket1Crit = VarTrinket1ID == I.MadQueensMandate:ID() or VarTrinket1ID == I.JunkmaestrosMegaMagnet:ID() or VarTrinket1ID == I.GeargrindersSpareKeys:ID() or VarTrinket1ID == I.RavenousHoneyBuzzer:ID() or VarTrinket1ID == I.GrimCodex:ID() or VarTrinekt1ID == I.RatfangToxin:ID() or VarTrinket1ID == I.Blastmaster3000:ID()
  VarTrinket2Crit = VarTrinket2ID == I.MadQueensMandate:ID() or VarTrinket2ID == I.JunkmaestrosMegaMagnet:ID() or VarTrinket2ID == I.GeargrindersSpareKeys:ID() or VarTrinket2ID == I.RavenousHoneyBuzzer:ID() or VarTrinket2ID == I.GrimCodex:ID() or VarTrinket2ID == I.RatfangToxin:ID() or VarTrinekt2ID == I.Blastmaster3000:ID()
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
  VarHeroTree = Player:HeroTreeID()
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

local function InertiaTrigger()
  -- Return the conditions necessary to allow Fel Rush to trigger Inertia
  return Player:BuffUp(S.UnboundChaosBuff) and S.FelRush:Charges() >= 1 and UseFelRush()
end

--- ===== CastTargetIfFilterFunctions =====
local function ETIFBurningWound(TargetUnit)
  -- target_if=min:debuff.burning_wound.remains
  return TargetUnit:DebuffRemains(S.BurningWoundDebuff)
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- variable,name=trinket1_steroids,value=trinket.1.has_cooldown&trinket.1.has_stat.any_dps&!trinket.1.is.improvised_seaforium_pacemaker
  -- variable,name=trinket2_steroids,value=trinket.2.has_cooldown&trinket.2.has_stat.any_dps&!trinket.2.is.improvised_seaforium_pacemaker
  -- variable,name=trinket1_crit,value=trinket.1.is.mad_queens_mandate|trinket.1.is.junkmaestros_mega_magnet|trinket.1.is.geargrinders_spare_keys|trinket.1.is.ravenous_honey_buzzer|trinket.1.is.grim_codex|trinket.1.is.ratfang_toxin|trinket.1.is.blastmaster3000
  -- variable,name=trinket2_crit,value=trinket.2.is.mad_queens_mandate|trinket.2.is.junkmaestros_mega_magnet|trinket.2.is.geargrinders_spare_keys|trinket.2.is.ravenous_honey_buzzer|trinket.2.is.grim_codex|trinket.2.is.ratfang_toxin|trinket.2.is.blastmaster3000
  -- variable,name=rg_ds,default=0,op=reset
  -- sigil_of_flame
  if SigilAbility:IsCastable() then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability precombat 2"; end
  end
  -- immolation_aura
  if ImmoAbility:IsCastable() then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura precombat 4"; end
  end
  -- Manually added: The Hunt
  if S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(15)) then return "the_hunt precombat 6"; end
  end
  -- Manually added: Felblade if out of range
  if not IsInMeleeRange(5) and S.Felblade:IsCastable() then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade precombat 8"; end
  end
  -- Manually added: Fel Rush if out of range
  if not IsInMeleeRange(5) and S.FelRush:IsCastable() and (not S.Felblade:IsAvailable() or S.Felblade:CooldownDown() and not Player:PrevGCDP(1, S.Felblade)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush, not Target:IsInRange(15)) then return "fel_rush precombat 10"; end
  end
  -- Manually added: Demon's Bite/Demon Blades if in melee range
  if IsInMeleeRange(5) and (S.DemonsBite:IsCastable() or S.DemonBlades:IsAvailable()) then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite or demon_blades precombat 12"; end
  end
end

local function FSCooldown()
  -- metamorphosis,if=((cooldown.eye_beam.remains>=20&(!talent.essence_break|debuff.essence_break.up)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&buff.inner_demon.down&(!talent.restless_hunter&cooldown.blade_dance.remains>gcd.max*3|prev_gcd.1.death_sweep))&!talent.inertia&!talent.essence_break&buff.demonsurge_death_sweep.down&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and (((BeamAbility:CooldownRemains() >= 20 and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff)) and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and Player:BuffDown(S.InnerDemonBuff) and (not S.RestlessHunter:IsAvailable() and S.BladeDance:CooldownRemains() > Player:GCD() * 3 or Player:PrevGCD(1, S.DeathSweep))) and not S.Inertia:IsAvailable() and not S.EssenceBreak:IsAvailable() and not Player:Demonsurge("DeathSweep") and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis fs_cooldown 2"; end
  end
  -- metamorphosis,if=(cooldown.blade_dance.remains&(buff.metamorphosis.up&cooldown.eye_beam.remains&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&(buff.inner_demon.down&(!talent.restless_hunter|prev_gcd.1.death_sweep)))&((buff.demonsurge_death_sweep.down&buff.metamorphosis.up|buff.metamorphosis.remains<gcd.max)&buff.demonsurge_annihilation.down)&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and ((S.BladeDance:CooldownDown() and (Player:BuffUp(S.MetamorphosisBuff) and BeamAbility:CooldownDown() and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and (Player:BuffDown(S.InnerDemonBuff) and (not S.RestlessHunter:IsAvailable() or Player:PrevGCD(1, S.DeathSweep)))) and ((not Player:Demonsurge("DeathSweep") and Player:BuffUp(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD()) and not Player:Demonsurge("Annihilation")) and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis fs_cooldown 4"; end
  end
  -- potion,if=fight_remains<35|(buff.metamorphosis.up|debuff.essence_break.up)&time>10
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 35 or (Player:BuffUp(S.MetamorphosisBuff) or Target:DebuffUp(S.EssenceBreakDebuff)) and CombatTime > 10) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion fs_cooldown 6"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.metamorphosis.up|fight_remains<=20
  -- Note: Not handling external buffs.
  -- variable,name=special_trinket,op=set,value=equipped.mad_queens_mandate|equipped.treacherous_transmitter|equipped.skardyns_grace|equipped.signet_of_the_priory
  VarSpecialTrinket = I.MadQueensMandate:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.SkardynsGrace:IsEquipped() or I.SignetofthePriory:IsEquipped()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=mad_queens_mandate,if=((!talent.initiative|buff.initiative.up|time>5)&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(trinket.1.is.mad_queens_mandate&(trinket.2.cooldown.duration<10|trinket.2.cooldown.remains>10|!trinket.2.has_buff.any)|trinket.2.is.mad_queens_mandate&(trinket.1.cooldown.duration<10|trinket.1.cooldown.remains>10|!trinket.1.has_buff.any))&fight_remains>120|fight_remains<10&fight_remains<buff.metamorphosis.remains)&debuff.essence_break.down|fight_remains<5
    if I.MadQueensMandate:IsEquippedAndReady() and (((not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5) and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (VarTrinket1ID == I.MadQueensMandate:ID() and (VarTrinket2CD < 10 or Trinket2:CooldownRemains() > 10 or not Trinket2:HasUseBuff()) or VarTrinket2ID == I.MadQueensMandate:ID() and (VarTrinket1CD < 10 or Trinket1:CooldownRemains() > 10 or not Trinket1:HasUseBuff())) and FightRemains > 120 or BossFightRemains < 10 and BossFightRemains < Player:BuffRemains(S.MetamorphosisBuff)) and Target:DebuffDown(S.EssenceBreakDebuff) or BossFightRemains < 5) then
      if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mad_queens_mandate fs_cooldown 8"; end
    end
    -- use_item,name=treacherous_transmitter,if=!equipped.mad_queens_mandate|equipped.mad_queens_mandate&(trinket.1.is.mad_queens_mandate&trinket.1.cooldown.remains>fight_remains|trinket.2.is.mad_queens_mandate&trinket.2.cooldown.remains>fight_remains)|fight_remains>25
    if I.TreacherousTransmitter:IsEquippedAndReady() and (not I.MadQueensMandate:IsEquipped() or I.MadQueensMandate:IsEquipped() and (VarTrinket1ID == I.MadQueensMandate:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket2ID == I.MadQueensMandate:ID() and Trinket2:CooldownRemains() > FightRemains) or FightRemains > 25) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter fs_cooldown 10"; end
    end
    -- use_item,name=skardyns_grace,if=(!equipped.mad_queens_mandate|fight_remains>25|trinket.2.is.skardyns_grace&trinket.1.cooldown.remains>fight_remains|trinket.1.is.skardyns_grace&trinket.2.cooldown.remains>fight_remains|trinket.1.cooldown.duration<10|trinket.2.cooldown.duration<10)&buff.metamorphosis.up
    if I.SkardynsGrace:IsEquippedAndReady() and ((not I.MadQueensMandate:IsEquipped() or FightRemains > 25 or VarTrinket2ID == I.SkardynsGrace:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket1ID == I.SkardynsGrace:ID() and Trinket2:CooldownRemains() > FightRemains or VarTrinket1CD < 10 or VarTrinket2CD < 10) and Player:BuffUp(S.MetamorphosisBuff)) then
      if Cast(I.SkardynsGrace, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "skardyns_grace fs_cooldown 12"; end
    end
    -- use_item,name=house_of_cards,if=(cooldown.eye_beam.up|buff.metamorphosis.up)|fight_remains<20
    if I.HouseofCards:IsEquippedAndReady() and (BeamAbility:CooldownUp() or Player:BuffUp(S.MetamorphosisBuff) or BossFightRemains < 20) then
      if Cast(I.HouseofCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards fs_cooldown 14"; end
    end
    -- use_item,name=signet_of_the_priory,if=time<20&(!talent.inertia|buff.inertia.up)|buff.metamorphosis.up&time>20|fight_remains<20
    if I.SignetofthePriory:IsEquippedAndReady() and (CombatTime < 20 and (not S.Inertia:IsAvailable() or Player:BuffUp(S.InertiaBuff)) or Player:BuffUp(S.MetamorphosisBuff) or BossFightRemains < 20) then
      if Cast(I.SignetofthePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory fs_cooldown 16"; end
    end
    -- use_item,name=ratfang_toxin,if=variable.tier33_4piece&variable.double_on_use|fight_remains<5
    if I.RatfangToxin:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 5) then
      if Cast(I.RatfangToxin, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "ratfang_toxin fs_cooldown 18"; end
    end
    -- use_item,name=geargrinders_spare_keys,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.GeargrindersSpareKeys:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.GeargrindersSpareKeys, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "geargrinders_spare_keys fs_cooldown 20"; end
    end
    -- use_item,name=grim_codex,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.GrimCodex:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.GrimCodex, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "grim_codex fs_cooldown 22"; end
    end
    -- use_item,name=ravenous_honey_buzzer,if=(variable.tier33_4piece&(buff.inertia.down&(cooldown.essence_break.remains&debuff.essence_break.down|!talent.essence_break))&(trinket.1.is.ravenous_honey_buzzer&(trinket.2.cooldown.duration<10|trinket.2.cooldown.remains>10|!trinket.2.has_buff.any)|trinket.2.is.ravenous_honey_buzzer&(trinket.1.cooldown.duration<10|trinket.1.cooldown.remains>10|!trinket.1.has_buff.any))&fight_remains>120|fight_remains<10&fight_remains<buff.metamorphosis.remains)|fight_remains<5
    if I.RavenousHoneyBuzzer:IsEquippedAndReady() and ((VarT334P and (Player:BuffDown(S.InertiaBuff) and (S.EssenceBreak:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff) or not S.EssenceBreak:IsAvailable())) and (VarTrinket1ID == I.RavenousHoneyBuzzer:ID() and (VarTrinket2CD < 10 or Trinket2:CooldownRemains() > 10 or not Trinket2:HasUseBuff()) or VarTrinket2ID == I.RavenousHoneyBuzzer:ID() and (VarTrinket1CD < 10 or Trinket1:CooldownRemains() > 10 or not Trinket1:HasUseBuff())) and FightRemains > 120 or BossFightRemains < 10 and BossFightRemains < Player:BuffRemains(S.MetamorphosisBuff)) or BossFightRemains < 5) then
      if Cast(I.RavenousHoneyBuzzer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ravenous_honey_buzzer fs_cooldown 24"; end
    end
    -- use_item,name=blastmaster3000,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.Blastmaster3000:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.Blastmaster3000, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "blastmaster3000 fs_cooldown 26"; end
    end
    -- use_item,name=junkmaestros_mega_magnet,if=variable.tier33_4piece_magnet&variable.double_on_use&time>10|fight_remains<5
    if I.JunkmaestrosMegaMagnet:IsEquippedAndReady() and Player:BuffUp(S.JunkmaestrosBuff) and (VarT334PMagnet and VarDoubleOnUse and CombatTime > 10 or BossFightRemains < 5) then
      if Cast(I.JunkmaestrosMegaMagnet, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "junkmaestros_mega_magnet fs_cooldown 28"; end
    end
    -- do_treacherous_transmitter_task,if=cooldown.eye_beam.remains>15|cooldown.eye_beam.remains<5|fight_remains<20|buff.metamorphosis.up
    -- TODO
    -- use_item,slot=trinket1,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.1.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.1.has_buff.any|fight_remains<25)&!trinket.1.is.mister_locknstalk&!variable.trinket1_crit&!trinket.1.is.skardyns_grace&!trinket.1.is.treacherous_transmitter&(!variable.special_trinket|trinket.2.cooldown.remains>20)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and not VarTrinket1Exclude and (((BeamAbility:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket1:HasUseBuff() or BossFightRemains < 25) and not VarTrinket1ID == I.MisterLockNStalk:ID() and not VarTrinket1Crit and not VarTrinket1ID == I.SkardynsGrace:ID() and not VarTrinket1ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket2:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "treacherous_transmitter fs_cooldown 30"; end
    end
    -- use_item,slot=trinket2,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.2.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.2.has_buff.any|fight_remains<25)&!trinket.2.is.mister_locknstalk&!variable.trinket2_crit&!trinket.2.is.skardyns_grace&!trinket.2.is.treacherous_transmitter&(!variable.special_trinket|trinket.1.cooldown.remains>20)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and not VarTrinket2Exclude and (((BeamAbility:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket2:HasUseBuff() or BossFightRemains < 25) and not VarTrinket2ID == I.MisterLockNStalk:ID() and not VarTrinket2Crit and not VarTrinket2ID == I.SkardynsGrace:ID() and not VarTrinket2ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket1:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "treacherous_transmitter fs_cooldown 32"; end
    end
  end
  -- the_hunt,if=debuff.essence_break.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>90)&(debuff.reavers_mark.up|!hero_tree.aldrachi_reaver)&buff.reavers_glaive.down&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(!talent.initiative|buff.initiative.up|time>5)&time>5&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down)&(hero_tree.aldrachi_reaver|buff.metamorphosis.down)|fight_remains<=30
  if CDsON() and S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and (Target:DebuffUp(S.ReaversMarkDebuff) or VarHeroTree ~= 35) and not S.ReaversGlaive:IsLearned() and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5) and CombatTime > 5 and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger()) and (VarHeroTree == 35 or Player:BuffDown(S.MetamorphosisBuff)) or BossFightRemains <= 30) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs_cooldown 34"; end
  end
  -- sigil_of_spite,if=debuff.essence_break.down&cooldown.blade_dance.remains&time>15
  if S.SigilofSpite:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown() and CombatTime > 15) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite fs_cooldown 36"; end
  end
end

local function FSFelBarrage()
  -- variable,name=generator_up,op=set,value=cooldown.felblade.remains<gcd.max|cooldown.sigil_of_flame.remains<gcd.max
  local VarGeneratorUp = S.Felblade:CooldownRemains() < Player:GCD() or SigilAbility:CooldownRemains() < Player:GCD()
  -- variable,name=gcd_drain,op=set,value=gcd.max*32
  local VarGCDDrain = Player:GCD() * 32
  -- annihilation,if=buff.inner_demon.up
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_fel_barrage 2"; end
  end
  -- eye_beam,if=buff.fel_barrage.down&(active_enemies>1&raid_event.adds.up|raid_event.adds.in>40)
  if BeamAbility:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs_fel_barrage 4"; end
  end
  -- essence_break,if=buff.fel_barrage.down&buff.metamorphosis.up
  if S.EssenceBreak:IsCastable() and (Player:BuffDown(S.FelBarrageBuff) and Player:BuffUp(S.MetamorphosisBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break fs_fel_barrage 8"; end
  end
  -- death_sweep,if=buff.fel_barrage.down
  if S.DeathSweep:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_fel_barrage 10"; end
  end
  -- immolation_aura,if=(active_enemies>2|buff.fel_barrage.up)&(cooldown.eye_beam.remains>recharge_time+3)
  if ImmoAbility:IsReady() and ((Enemies8yCount > 2 or Player:BuffUp(S.FelBarrageBuff)) and (BeamAbility:CooldownRemains() > ImmoAbility:Recharge() + 3)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs_fel_barrage 12"; end
  end
  -- glaive_tempest,if=buff.fel_barrage.down&active_enemies>1
  if S.GlaiveTempest:IsReady() and (Player:BuffDown(S.FelBarrageBuff) and Enemies8yCount > 1) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fs_fel_barrage 14"; end
  end
  -- blade_dance,if=buff.fel_barrage.down
  if S.BladeDance:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fs_fel_barrage 16"; end
  end
  -- fel_barrage,if=fury>100&(raid_event.adds.in>90|raid_event.adds.in<gcd.max|raid_event.adds.remains>4&active_enemies>2)
  if S.FelBarrage:IsReady() and (Player:Fury() > 100) then
    if Cast(S.FelBarrage, Settings.Havoc.GCDasOffGCD.FelBarrage, nil, not IsInMeleeRange(8)) then return "fel_barrage fs_fel_barrage 18"; end
  end
  -- felblade,if=buff.inertia_trigger.up&buff.fel_barrage.up
  if S.Felblade:IsCastable() and (InertiaTrigger() and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_fel_barrage 20"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up&fury>20&buff.fel_barrage.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff) and Player:Fury() > 20 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs_fel_barrage 22"; end
  end
  -- sigil_of_flame,if=fury.deficit>40&buff.fel_barrage.up&(!talent.student_of_suffering|cooldown.eye_beam.remains>30)
  --[[if SigilAbility:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff) and (not S.StudentofSuffering:IsAvailable() or BeamAbility:CooldownRemains() > 30)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_fel_barrage 24"; end
  end]]
  -- sigil_of_flame,if=fury.deficit>40&buff.fel_barrage.up
  -- Note: This line also covers the line above.
  if SigilAbility:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_fel_barrage 26"; end
  end
  -- felblade,if=buff.fel_barrage.up&fury.deficit>40&action.felblade.cooldown_react
  if S.Felblade:IsCastable() and (Player:BuffUp(S.FelBarrageBuff) and Player:FuryDeficit() > 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_fel_barrage 28"; end
  end
  -- death_sweep,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.DeathSweep:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_fel_barrage 30"; end
  end
  -- glaive_tempest,if=fury-variable.gcd_drain-30>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.GlaiveTempest:IsReady() and (Player:Fury() - VarGCDDrain - 30 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fs_fel_barrage 32"; end
  end
  -- blade_dance,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.BladeDance:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fs_fel_barrage 34"; end
  end
  -- arcane_torrent,if=fury.deficit>40&buff.fel_barrage.up
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent fs_fel_barrage 36"; end
  end
  -- fel_rush,if=buff.unbound_chaos.up
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffUp(S.UnboundChaosBuff)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs_fel_barrage 38"; end
  end
  -- the_hunt,if=fury>40&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>80)
  if CDsON() and S.TheHunt:IsCastable() and (Player:Fury() > 40) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt fs_fel_barrage 40"; end
  end
  -- annihilation,if=fury-variable.gcd_drain-40>20&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.Annihilation:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_fel_barrage 42"; end
  end
  -- chaos_strike,if=fury-variable.gcd_drain-40>20&(cooldown.fel_barrage.remains&cooldown.fel_barrage.remains<10&fury>100|buff.fel_barrage.up&(buff.fel_barrage.remains*variable.fury_gen-buff.fel_barrage.remains*32)>0)
  if S.ChaosStrike:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (S.FelBarrage:CooldownDown() and S.FelBarrage:CooldownRemains() < 10 and Player:Fury() > 100 or Player:BuffUp(S.FelBarrageBuff) and (Player:BuffRemains(S.FelBarrageBuff) * VarFuryGen - Player:BuffRemains(S.FelBarrageBuff) * 32) > 0)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike fs_fel_barrage 44"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite fs_fel_barrage 46"; end
  end
end

local function FSMeta()
  -- death_sweep,if=buff.metamorphosis.remains<gcd.max|debuff.essence_break.up|prev_gcd.1.metamorphosis
  if S.DeathSweep:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() or Target:DebuffUp(S.EssenceBreakDebuff) or Player:PrevGCD(1, S.Metamorphosis)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_meta 2"; end
  end
  -- sigil_of_flame,if=talent.student_of_suffering&buff.demonsurge_sigil_of_doom.down&debuff.essence_break.down&(talent.student_of_suffering&((talent.essence_break&cooldown.essence_break.remains>30-gcd.max|cooldown.essence_break.remains<=gcd.max+talent.inertia&(cooldown.vengeful_retreat.remains<=gcd|buff.initiative.up)+gcd.max*(cooldown.eye_beam.remains<=gcd.max))|(!talent.essence_break&(cooldown.eye_beam.remains>=10|cooldown.eye_beam.remains<=gcd.max))))
  if SigilAbility:IsCastable() and (S.StudentofSuffering:IsAvailable() and Player:Demonsurge("SigilofDoom") and Target:DebuffDown(S.EssenceBreakDebuff) and (S.StudentofSuffering:IsAvailable() and ((S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownRemains() > 30 - Player:GCD() or S.EssenceBreak:CooldownRemains() <= Player:GCD() + num(S.Inertia:IsAvailable() and (S.VengefulRetreat:CooldownRemains() <= Player:GCD() or Player:BuffUp(S.InitiativeBuff))) + Player:GCD() * num(BeamAbility:CooldownRemains() <= Player:GCD())) or (not S.EssenceBreak:IsAvailable() and (BeamAbility:CooldownRemains() >= 10 or BeamAbility:CooldownRemains() <= Player:GCD()))))) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_meta 4"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&(gcd.remains<0.3|talent.inertia&cooldown.eye_beam.remains>gcd.remains&(buff.cycle_of_hatred.stack=2|buff.cycle_of_hatred.stack=3))&(cooldown.metamorphosis.remains&(buff.demonsurge_annihilation.down&buff.demonsurge_death_sweep.down)|talent.restless_hunter&(!hero_tree.felscarred|buff.demonsurge_annihilation.down))&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down)&(!talent.essence_break|cooldown.essence_break.remains>18|cooldown.essence_break.remains<=gcd.remains+talent.inertia*1.5&(!talent.student_of_suffering|(buff.student_of_suffering.up|cooldown.sigil_of_flame.remains>5)))&(cooldown.eye_beam.remains>5|cooldown.eye_beam.remains<=gcd.remains|cooldown.eye_beam.up)
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (Player:GCDRemains() < 0.3 or S.Inertia:IsAvailable() and BeamAbility:CooldownRemains() > Player:GCDRemains() and (Player:BuffStack(S.CycleofHatredBuff) == 2 or Player:BuffStack(S.CycleofHatredBuff) == 3)) and (S.Metamorphosis:CooldownDown() and (not Player:Demonsurge("Annihilation") and not Player:Demonsurge("DeathSweep")) or S.RestlessHunter:IsAvailable() and (VarHeroTree ~= 34 or not Player:Demonsurge("Annihilation"))) and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger()) and (not S.EssenceBreak:IsAvailable() or S.EssenceBreak:CooldownRemains() > 18 or S.EssenceBreak:CooldownRemains() <= Player:GCDRemains() + num(S.Inertia:IsAvailable()) * 1.5 and (not S.StudentofSuffering:IsAvailable() or (Player:BuffUp(S.StudentofSufferingBuff) or SigilAbility:CooldownRemains() > 5))) and (BeamAbility:CooldownRemains() > 5 or BeamAbility:CooldownRemains() <= Player:GCDRemains() or BeamAbility:CooldownUp())) then
    if Cast(S.VengefulRetreat, Settings.Vengeance.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat fs_meta 6"; end
  end
  -- death_sweep,if=hero_tree.felscarred&talent.essence_break&buff.demonsurge_death_sweep.up&(buff.inertia.up&(cooldown.essence_break.remains>buff.inertia.remains|!talent.essence_break)|cooldown.metamorphosis.remains<=5&buff.inertia_trigger.down|buff.inertia.up&buff.demonsurge_abyssal_gaze.up)|talent.inertia&buff.inertia_trigger.down&cooldown.vengeful_retreat.remains>=gcd.max&buff.inertia.down
  if S.DeathSweep:IsReady() and (VarHeroTree == 34 and S.EssenceBreak:IsAvailable() and Player:Demonsurge("DeathSweep") and (Player:BuffUp(S.InertiaBuff) and (S.EssenceBreak:CooldownRemains() > Player:BuffRemains(S.InertiaBuff) or not S.EssenceBreak:IsAvailable()) or S.Metamorphosis:CooldownRemains() <= 5 and not InertiaTrigger() or Player:BuffUp(S.InertiaBuff) and Player:Demonsurge("AbyssalGaze")) or S.Inertia:IsAvailable() and not InertiaTrigger() and S.VengefulRetreat:CooldownRemains() >= Player:GCD() and Player:BuffDown(S.InertiaBuff)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_meta 8"; end
  end
  -- annihilation,if=buff.metamorphosis.remains<gcd.max&cooldown.blade_dance.remains<buff.metamorphosis.remains|debuff.essence_break.remains&debuff.essence_break.remains<0.5|talent.restless_hunter&(buff.demonsurge_annihilation.up|hero_tree.aldrachi_reaver&buff.inner_demon.up)&cooldown.essence_break.up&cooldown.metamorphosis.up
  if S.Annihilation:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() and S.BladeDance:CooldownRemains() < Player:BuffRemains(S.MetamorphosisBuff) or Target:DebuffUp(S.EssenceBreakDebuff) and Target:DebuffRemains(S.EssenceBreakDebuff) < 1 or S.RestlessHunter:IsAvailable() and (Player:Demonsurge("Annihilation") or VarHeroTree == 35 and Player:BuffUp(S.InnerDemonBuff)) and S.EssenceBreak:CooldownUp() and S.Metamorphosis:CooldownUp()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_meta 10"; end
  end
  -- annihilation,if=(hero_tree.felscarred&buff.demonsurge_annihilation.up&talent.restless_hunter)&(cooldown.eye_beam.remains<gcd.max*3&cooldown.blade_dance.remains|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and ((VarHeroTree == 34 and Player:Demonsurge("Annihilation") and S.RestlessHunter:IsAvailable()) and (BeamAbility:CooldownRemains() < Player:GCD() * 3 and S.BladeDance:CooldownDown() or S.Metamorphosis:CooldownRemains() < Player:GCD() * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_meta 12"; end
  end
  -- felblade,if=buff.inertia_trigger.up&talent.inertia&debuff.essence_break.down&cooldown.metamorphosis.remains&(!hero_tree.felscarred|cooldown.eye_beam.remains)&(cooldown.blade_dance.remains<=5.5&(talent.essence_break&cooldown.essence_break.remains<=0.5|!talent.essence_break|cooldown.essence_break.remains>=buff.inertia_trigger.remains&cooldown.blade_dance.remains<=4.5&(cooldown.blade_dance.remains|cooldown.blade_dance.remains<=0.5))|buff.metamorphosis.remains<=5.5+talent.shattered_destiny*2)
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and Target:DebuffDown(S.EssenceBreakDebuff) and S.Metamorphosis:CooldownDown() and (VarHeroTree ~= 34 or BeamAbility:CooldownDown()) and (S.BladeDance:CooldownRemains() <= 5.5 and (S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownRemains() <= 1 or not S.EssenceBreak:IsAvailable() or S.EssenceBreak:CooldownRemains() >= Player:BuffRemains(S.UnboundChaosBuff) and S.BladeDance:CooldownRemains() <= 4.5 and (S.BladeDance:CooldownDown() or S.BladeDance:CooldownRemains() <= 1)) or Player:BuffRemains(S.MetamorphosisBuff) <= 5.5 + num(S.ShatteredDestiny:IsAvailable()) * 2)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_meta 14"; end
  end
  -- fel_rush,if=buff.inertia_trigger.up&talent.inertia&debuff.essence_break.down&cooldown.metamorphosis.remains&(!hero_tree.felscarred|cooldown.eye_beam.remains)&(active_enemies>2|hero_tree.felscarred)&(cooldown.felblade.remains&cooldown.essence_break.remains<=0.6)
  if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and InertiaTrigger() and Target:DebuffDown(S.EssenceBreakDebuff) and S.Metamorphosis:CooldownDown() and (VarHeroTree ~= 34 or BeamAbility:CooldownDown()) and (Enemies8yCount > 2 or VarHeroTree == 34) and (S.Felblade:CooldownDown() and S.EssenceBreak:CooldownRemains() <= 1.1)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs_meta 16"; end
  end
  -- immolation_aura,if=charges=2&(active_enemies>1|talent.a_fire_inside&talent.isolated_prey)&debuff.essence_break.down
  if ImmoAbility:IsCastable() and (ImmoAbility:Charges() == 2 and (Enemies8yCount > 1 or S.AFireInside:IsAvailable() and S.IsolatedPrey:IsAvailable()) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs_meta 18"; end
  end
  -- annihilation,if=buff.inner_demon.up&cooldown.blade_dance.remains&(cooldown.eye_beam.remains<gcd.max*3|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and S.BladeDance:CooldownDown() and (BeamAbility:CooldownRemains() < Player:GCD() * 3 or S.Metamorphosis:CooldownRemains() < Player:GCD() * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_meta 20"; end
  end
  -- essence_break,if=fury>20&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2)&(buff.inertia_trigger.down|buff.inertia.up&buff.inertia.remains>=gcd.max*3|!talent.inertia)&buff.out_of_range.remains<gcd.max&(!talent.shattered_destiny|cooldown.eye_beam.remains>4)&(!hero_tree.felscarred|active_enemies>1|cooldown.metamorphosis.remains>5&cooldown.eye_beam.remains)&(!buff.cycle_of_hatred.stack=3|buff.initiative.up|!talent.initiative|!talent.cycle_of_hatred)|fight_remains<5
  if S.EssenceBreak:IsCastable() and (Player:Fury() > 20 and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 2) and (not InertiaTrigger() or Player:BuffUp(S.InertiaBuff) and Player:BuffRemains(S.InertiaBuff) >= Player:GCD() * 3 or not S.Inertia:IsAvailable()) and (not S.ShatteredDestiny:IsAvailable() or BeamAbility:CooldownRemains() > 4) and (VarHeroTree ~= 34 or Enemies8yCount > 1 or S.Metamorphosis:CooldownRemains() > 5 and BeamAbility:CooldownDown()) and (Player:BuffStack(S.CycleofHatredBuff) ~= 3 or Player:BuffUp(S.InitiativeBuff) or not S.Initiative:IsAvailable() or not S.CycleofHatred:IsAvailable()) or BossFightRemains < 5) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not Target:IsInRange(10)) then return "essence_break fs_meta 22"; end
  end
  -- sigil_of_flame,if=cooldown.blade_dance.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>=20|cooldown.eye_beam.remains<=gcd.max)&(!talent.student_of_suffering|buff.demonsurge_sigil_of_doom.up)
  if SigilAbility:IsCastable() and (S.BladeDance:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() >= 20 or BeamAbility:CooldownRemains() <= Player:GCD()) and (not S.StudentofSuffering:IsAvailable() or Player:Demonsurge("SigilofDoom"))) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_meta 24"; end
  end
  -- immolation_aura,if=buff.demonsurge.up&debuff.essence_break.down&buff.demonsurge_consuming_fire.up&cooldown.blade_dance.remains>=gcd.max&cooldown.eye_beam.remains>=gcd.max&fury.deficit>10+variable.fury_gen
  if ImmoAbility:IsReady() and (Player:BuffUp(S.DemonsurgeBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:Demonsurge("ConsumingFire") and S.BladeDance:CooldownRemains() >= Player:GCD() and BeamAbility:CooldownRemains() >= Player:GCD() and Player:FuryDeficit() > 10 + VarFuryGen) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs_meta 26"; end
  end
  -- eye_beam,if=buff.metamorphosis.down&debuff.essence_break.down&buff.inner_demon.down
  if BeamAbility:IsReady() and (Player:BuffDown(S.MetamorphosisBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs_meta 28"; end
  end
  -- eye_beam,if=buff.metamorphosis.up&debuff.essence_break.down&buff.inner_demon.down&(buff.cycle_of_hatred.stack<4|cooldown.essence_break.remains>=20-gcd.max*talent.student_of_suffering|cooldown.sigil_of_flame.remains&talent.student_of_suffering|cooldown.essence_break.remains<=gcd.max)
  if BeamAbility:IsReady() and (Player:BuffUp(S.MetamorphosisBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and (Player:BuffStack(S.CycleofHatredBuff) < 4 or S.EssenceBreak:CooldownRemains() >= 20 - Player:GCD() * num(S.StudentofSuffering:IsAvailable()) or SigilAbility:CooldownDown() and S.StudentofSuffering:IsAvailable() or S.EssenceBreak:CooldownRemains() <= Player:GCD())) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs_meta 30"; end
  end
  -- death_sweep,if=cooldown.essence_break.remains>=gcd.max*2+talent.student_of_suffering*gcd.max|debuff.essence_break.up|!talent.essence_break
  if S.DeathSweep:IsReady() and (S.EssenceBreak:CooldownRemains() >= Player:GCD() * 2 + num(S.StudentofSuffering:IsAvailable()) * Player:GCD() or Target:DebuffUp(S.EssenceBreakDebuff) or not S.EssenceBreak:IsAvailable()) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_meta 32"; end
  end
  -- glaive_tempest,if=debuff.essence_break.down&(cooldown.blade_dance.remains>gcd.max*2|fury>60)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.BladeDance:CooldownRemains() > Player:GCD() * 2 or Player:Fury() > 60)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fs_meta 34"; end
  end
  -- sigil_of_flame,if=active_enemies>2&debuff.essence_break.down
  if SigilAbility:IsCastable() and (Enemies8yCount > 2 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_meta 36"; end
  end
  -- annihilation,if=cooldown.blade_dance.remains|fury>60|soul_fragments.total>0|buff.metamorphosis.remains<5
  local TotalSoulFragments = DemonHunter.Souls.AuraSouls + DemonHunter.Souls.IncomingSouls
  if S.Annihilation:IsReady() and (S.BladeDance:CooldownDown() or Player:Fury() > 60 or TotalSoulFragments > 0 or Player:BuffRemains(S.MetamorphosisBuff) < 5) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_meta 38"; end
  end
  -- sigil_of_flame,if=buff.metamorphosis.remains>5&buff.out_of_range.down&!talent.student_of_suffering
  if SigilAbility:IsCastable() and (Player:BuffRemains(S.MetamorphosisBuff) > 5 and Target:IsInRange(30) and not S.StudentofSuffering:IsAvailable()) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_meta 40"; end
  end
  -- immolation_aura,if=buff.out_of_range.down&recharge_time<(cooldown.eye_beam.remains<?buff.metamorphosis.remains)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
  if ImmoAbility:IsReady() and (Target:IsInRange(8) and ImmoAbility:Recharge() < mathmax(BeamAbility:CooldownRemains(), Player:BuffRemains(S.MetamorphosisBuff))) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs_meta 42"; end
  end
  -- felblade,if=(buff.out_of_range.down|fury.deficit>40+variable.fury_gen*(0.5%gcd.max))&!buff.inertia_trigger.up
  if S.Felblade:IsCastable() and ((Target:IsInRange(8) or Player:FuryDeficit() > 40 + VarFuryGen * (0.5 / Player:GCD())) and not InertiaTrigger()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_meta 44"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_meta 46"; end
  end
  -- throw_glaive,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.ThrowGlaive:IsReady() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Target:IsInRange(8) and Enemies8yCount > 1) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not IsInMeleeRange(5)) then return "throw_glaive fs_meta 48"; end
  end
  -- fel_rush,if=recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.FelRush:IsCastable() and UseFelRush() and (S.FelRush:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01) and IsInMeleeRange(15) and Enemies8yCount > 1) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs_meta 50"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite fs_meta 52"; end
  end
end

local function FSOpener()
  -- potion,if=buff.initiative.up|!talent.initiative
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.InitiativeBuff) or not S.Initiative:IsAvailable()) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion fs_opener 2"; end
    end
  end
  -- felblade,if=cooldown.the_hunt.up&!talent.a_fire_inside&fury<40
  if S.Felblade:IsCastable() and (S.TheHunt:CooldownUp() and not S.AFireInside:IsAvailable() and Player:Fury() < 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_opener 4"; end
  end
  -- the_hunt,if=talent.inertia|buff.initiative.up|!talent.initiative
  if CDsON() and S.TheHunt:IsCastable() and (S.Inertia:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or not S.Initiative:IsAvailable()) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt fs_opener 6"; end
  end
  -- felblade,if=talent.inertia&buff.inertia_trigger.up&active_enemies=1&buff.metamorphosis.up&cooldown.metamorphosis.up&cooldown.essence_break.up&buff.inner_demon.down&buff.demonsurge_annihilation.down
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and Enemies8yCount == 1 and Player:BuffUp(S.MetamorphosisBuff) and S.Metamorphosis:CooldownUp() and S.EssenceBreak:CooldownUp() and Player:BuffDown(S.InnerDemonBuff) and not Player:Demonsurge("Annihilation")) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_opener 8"; end
  end
  -- fel_rush,if=talent.inertia&buff.inertia_trigger.up&(cooldown.felblade.remains|active_enemies>1)&buff.metamorphosis.up&cooldown.metamorphosis.up&cooldown.essence_break.up&buff.inner_demon.down&buff.demonsurge_annihilation.down
  if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and InertiaTrigger() and (S.Felblade:CooldownDown() or Enemies8yCount > 1) and Player:BuffUp(S.MetamorphosisBuff) and S.Metamorphosis:CooldownUp() and S.EssenceBreak:CooldownUp() and Player:BuffDown(S.InnerDemonBuff) and not Player:Demonsurge("Annihilation")) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs_opener 10"; end
  end
  -- essence_break,if=buff.metamorphosis.up&(!talent.inertia|buff.inertia.up)&buff.inner_demon.down&buff.demonsurge_annihilation.down
  if S.EssenceBreak:IsCastable() and (Player:BuffUp(S.MetamorphosisBuff) and (not S.Inertia:IsAvailable() or Player:BuffUp(S.InertiaBuff)) and Player:BuffDown(S.InnerDemonBuff) and not Player:Demonsurge("Annihilation")) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break fs_opener 12"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&time>4&buff.metamorphosis.up&(!talent.inertia|buff.inertia_trigger.down)&talent.essence_break&buff.inner_demon.down&(buff.initiative.down|gcd.remains<0.1)&cooldown.blade_dance.remains
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and CombatTime > 4 and Player:BuffUp(S.MetamorphosisBuff) and (not S.Inertia:IsAvailable() or not InertiaTrigger()) and S.EssenceBreak:IsAvailable() and Player:BuffDown(S.InnerDemonBuff) and S.BladeDance:CooldownDown()) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat fs_opener 14"; end
  end
  -- felblade,if=talent.inertia&buff.inertia_trigger.up&hero_tree.felscarred&debuff.essence_break.down&talent.essence_break&cooldown.metamorphosis.remains&active_enemies<=2&cooldown.sigil_of_flame.remains
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and VarHeroTree == 34 and Target:DebuffDown(S.EssenceBreakDebuff) and S.EssenceBreak:IsAvailable() and S.Metamorphosis:CooldownDown() and Enemies8yCount <= 2 and SigilAbility:CooldownDown()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_opener 16"; end
  end
  -- sigil_of_flame,if=(buff.inner_demon.down|buff.out_of_range.up)&debuff.essence_break.down
  if SigilAbility:IsCastable() and ((Player:BuffDown(S.InnerDemonBuff) or not Target:IsInRange(8)) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs_opener 18"; end
  end
  -- annihilation,if=(buff.inner_demon.up|buff.demonsurge_annihilation.up)&(cooldown.metamorphosis.up|!talent.essence_break&cooldown.blade_dance.remains)
  if S.Annihilation:IsReady() and ((Player:BuffUp(S.InnerDemonBuff) or Player:Demonsurge("Annihilation")) and (S.Metamorphosis:CooldownUp() or not S.EssenceBreak:IsAvailable() and S.BladeDance:CooldownDown())) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_opener 20"; end
  end
  -- death_sweep,if=hero_tree.felscarred&buff.demonsurge_death_sweep.up&!talent.restless_hunter
  if S.DeathSweep:IsReady() and (VarHeroTree == 34 and Player:Demonsurge("DeathSweep") and not S.RestlessHunter:IsAvailable()) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_opener 22"; end
  end
  -- annihilation,if=hero_tree.felscarred&buff.demonsurge_annihilation.up&(!talent.essence_break|buff.inner_demon.up)
  if S.Annihilation:IsReady() and (VarHeroTree == 34 and Player:Demonsurge("Annihilation") and (not S.EssenceBreak:IsAvailable() or Player:BuffUp(S.InnerDemonBuff))) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_opener 24"; end
  end
  -- immolation_aura,if=talent.a_fire_inside&talent.burning_wound&buff.metamorphosis.down
  if ImmoAbility:IsCastable() and (S.AFireInside:IsAvailable() and S.BurningWound:IsAvailable() and Player:BuffDown(S.MetamorphosisBuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs_opener 26"; end
  end
  -- felblade,if=fury<40&debuff.essence_break.down&buff.inertia_trigger.down&cooldown.metamorphosis.up
  if S.Felblade:IsCastable() and (Player:Fury() < 40 and Target:DebuffDown(S.EssenceBreakDebuff) and not InertiaTrigger() and S.Metamorphosis:CooldownUp()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs_opener 28"; end
  end
  -- metamorphosis,if=buff.metamorphosis.up&buff.inner_demon.down&buff.demonsurge_annihilation.down&cooldown.blade_dance.remains
  if CDsON() and S.Metamorphosis:IsCastable() and (Player:BuffUp(S.MetamorphosisBuff) and Player:BuffDown(S.InnerDemonBuff) and not Player:Demonsurge("Annihilation") and S.BladeDance:CooldownDown()) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis fs_opener 30"; end
  end
  -- eye_beam,if=buff.metamorphosis.down|debuff.essence_break.down&buff.inner_demon.down&(cooldown.blade_dance.remains|talent.essence_break&cooldown.essence_break.up)&(!talent.a_fire_inside|action.immolation_aura.charges=0)
  if BeamAbility:IsReady() and (Player:BuffDown(S.MetamorphosisBuff) or Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and (S.BladeDance:CooldownDown() or S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownUp()) and (not S.AFireInside:IsAvailable() or ImmoAbility:Charges() == 0)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs_opener 32"; end
  end
  -- eye_beam,if=buff.metamorphosis.up&debuff.essence_break.down&buff.inner_demon.down
  if BeamAbility:IsReady() and (Player:BuffUp(S.MetamorphosisBuff) or Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs_opener 34"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep fs_opener 36"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation fs_opener 38"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite fs_opener 40"; end
  end
end

local function FS()
  -- pick_up_fragment,use_off_gcd=1
  -- variable,name=fel_barrage,op=set,value=talent.fel_barrage&(cooldown.fel_barrage.remains<gcd.max*7&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in<gcd.max*7|raid_event.adds.in>90)&(cooldown.metamorphosis.remains|active_enemies>2)|buff.fel_barrage.up)&!(active_enemies=1&!raid_event.adds.exists)
  VarFelBarrage = S.FelBarrage:IsAvailable() and (S.FelBarrage:CooldownRemains() < Player:GCD() * 7 and (S.Metamorphosis:CooldownDown() or Enemies12yCount > 2 or Player:BuffUp(S.FelBarrageBuff)))
  -- call_action_list,name=fs_cooldown
  local ShouldReturn = FSCooldown(); if ShouldReturn then return ShouldReturn; end
  -- run_action_list,name=fs_opener,if=(cooldown.eye_beam.up|cooldown.metamorphosis.up|cooldown.essence_break.up|buff.demonsurge.stack<3+talent.student_of_suffering+talent.a_fire_inside)&time<15&raid_event.adds.in>40
  if (BeamAbility:CooldownUp() or S.Metamorphosis:CooldownUp() or S.EssenceBreak:CooldownUp() or Player:BuffStack(S.DemonsurgeBuff) < 3 + num(S.StudentofSuffering:IsAvailable()) + num(S.AFireInside:IsAvailable()) and CombatTime < 15) then
    local ShouldReturn = FSOpener(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FSOpener()"; end
  end
  -- run_action_list,name=fs_fel_barrage,if=variable.fel_barrage&raid_event.adds.up
  if VarFelBarrage and Enemies12yCount > 1 then
    local ShouldReturn = FSFelBarrage(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FSFelBarrage()"; end
  end
  -- immolation_aura,if=active_enemies>2&talent.ragefire&(!talent.fel_barrage|cooldown.fel_barrage.remains>recharge_time)&debuff.essence_break.down&(buff.metamorphosis.down|buff.metamorphosis.remains>5)
  -- immolation_aura,if=active_enemies>2&talent.ragefire&raid_event.adds.up&raid_event.adds.remains<15&raid_event.adds.remains>5&debuff.essence_break.down
  -- Note: We can't check raid_event conditions, so simply checking for active_enemies>2 will make this line supercede the previous line.
  if ImmoAbility:IsReady() and (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs 2"; end
  end
  -- felblade,if=talent.unbound_chaos&buff.unbound_chaos.up&!talent.inertia&active_enemies<=2&(talent.student_of_suffering&cooldown.eye_beam.remains-gcd.max*2<=buff.unbound_chaos.remains|hero_tree.aldrachi_reaver)
  if S.Felblade:IsCastable() and (S.UnboundChaos:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and not S.Inertia:IsAvailable() and Enemies8yCount <= 2 and (S.StudentofSuffering:IsAvailable() and BeamAbility:CooldownRemains() - Player:GCD() * 2 <= Player:BuffRemains(S.UnboundChaosBuff) or VarHeroTree == 35)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 4"; end
  end
  -- fel_rush,if=talent.unbound_chaos&buff.unbound_chaos.up&!talent.inertia&active_enemies>3&(talent.student_of_suffering&cooldown.eye_beam.remains-gcd.max*2<=buff.unbound_chaos.remains)
  if S.FelRush:IsCastable() and UseFelRush() and (S.UnboundChaos:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and not S.Inertia:IsAvailable() and Enemies8yCount > 3 and (S.StudentofSuffering:IsAvailable() and BeamAbility:CooldownRemains() - Player:GCD() * 2 <= Player:BuffRemains(S.UnboundChaosBuff))) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs 6"; end
  end
  -- run_action_list,name=fs_meta,if=buff.metamorphosis.up
  if Player:BuffUp(S.MetamorphosisBuff) then
    local ShouldReturn = FSMeta(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for FSMeta()"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&(cooldown.eye_beam.remains>15&gcd.remains<0.3|gcd.remains<0.2&cooldown.eye_beam.remains<=gcd.remains&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*3))&(!talent.student_of_suffering|cooldown.sigil_of_flame.remains)&(cooldown.essence_break.remains<=gcd.max*2&talent.student_of_suffering&cooldown.sigil_of_flame.remains|cooldown.essence_break.remains>=18|!talent.student_of_suffering)&(cooldown.metamorphosis.remains>10|hero_tree.aldrachi_reaver)&time>20
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (BeamAbility:CooldownRemains() > 15 or BeamAbility:CooldownRemains() <= Player:GCDRemains() and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 3)) and (not S.StudentofSuffering:IsAvailable() or SigilAbility:CooldownDown()) and (S.EssenceBreak:CooldownRemains() <= Player:GCD() * 2 and S.StudentofSuffering:IsAvailable() and SigilAbility:CooldownDown() or S.EssenceBreak:CooldownRemains() >= 18 or not S.StudentofSuffering:IsAvailable()) and (S.Metamorphosis:CooldownRemains() > 10 or VarHeroTree == 35) and CombatTime > 20) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat fs 8"; end
  end
  -- run_action_list,name=fs_fel_barrage,if=variable.fel_barrage|!talent.demon_blades&talent.fel_barrage&(buff.fel_barrage.up|cooldown.fel_barrage.up)&buff.metamorphosis.down
  if VarFelBarrage or not S.DemonBlades:IsAvailable() and S.FelBarrage:IsAvailable() and (Player:BuffUp(S.FelBarrage) or S.FelBarrage:CooldownUp()) and Player:BuffDown(S.MetamorphosisBuff) then
    local ShouldReturn = FSFelBarrage(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FSFelBarrage()"; end
  end
  if ImmoAbility:IsReady() and (
    -- immolation_aura,if=talent.a_fire_inside&talent.burning_wound&full_recharge_time<gcd.max*2&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets)
    -- Note: This line is handled by the following line.
    --(S.AFireInside:IsAvailable() and S.BurningWound:IsAvailable() and ImmoAbility:FullRechargeTime() < Player:GCD() * 2 and Enemies8yCount > 1) or
    -- immolation_aura,if=active_enemies>desired_targets&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
    (Enemies8yCount > 1) or
    -- immolation_aura,if=fight_remains<15&cooldown.blade_dance.remains&talent.ragefire
    (BossFightRemains < 15 and S.BladeDance:CooldownDown() and S.Ragefire:IsAvailable())
  ) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs 10"; end
  end
  -- sigil_of_flame,if=talent.student_of_suffering&cooldown.eye_beam.remains<=gcd.max&(cooldown.essence_break.remains<gcd.max*3|!talent.essence_break)&(cooldown.metamorphosis.remains>10|cooldown.blade_dance.remains<gcd.max*2)
  if SigilAbility:IsCastable() and (S.StudentofSuffering:IsAvailable() and BeamAbility:CooldownRemains() <= Player:GCD() and (S.EssenceBreak:CooldownRemains() < Player:GCD() * 3 or not S.EssenceBreak:IsAvailable()) and (S.Metamorphosis:CooldownRemains() > 10 or S.BladeDance:CooldownRemains() < Player:GCD() * 2)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs 12"; end
  end
  -- eye_beam,if=(!talent.initiative|buff.initiative.up|cooldown.vengeful_retreat.remains>=10|cooldown.metamorphosis.up|talent.initiative&!talent.tactical_retreat)&(cooldown.blade_dance.remains<7|raid_event.adds.up)|fight_remains<10
  if BeamAbility:IsReady() and ((not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or S.VengefulRetreat:CooldownRemains() >= 10 or S.Metamorphosis:CooldownUp() or S.Initiative:IsAvailable() and not S.TacticalRetreat:IsAvailable()) and (S.BladeDance:CooldownRemains() < 7 or Enemies20yCount > 1) or BossFightRemains < 10) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze fs 14"; end
  end
  -- blade_dance,if=cooldown.eye_beam.remains>=gcd.max*4|debuff.essence_break.up
  if S.BladeDance:IsReady() and (BeamAbility:CooldownRemains() >= Player:GCD() * 4 or Target:DebuffUp(S.EssenceBreakDebuff)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance fs 16"; end
  end
  -- glaive_tempest,if=active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10
  if S.GlaiveTempest:IsReady() then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest fs 18"; end
  end
  -- sigil_of_flame,if=active_enemies>3&!talent.student_of_suffering
  if SigilAbility:IsCastable() and (Enemies8yCount > 3 and not S.StudentofSuffering:IsAvailable()) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs 20"; end
  end
  -- chaos_strike,if=debuff.essence_break.up
  if S.ChaosStrike:IsReady() and (Target:DebuffUp(S.EssenceBreakDebuff)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike fs 22"; end
  end
  -- immolation_aura,if=talent.a_fire_inside&talent.isolated_prey&talent.flamebound&active_enemies=1&cooldown.eye_beam.remains>=gcd.max
  if ImmoAbility:IsReady() and (S.AFireInside:IsAvailable() and S.IsolatedPrey:IsAvailable() and S.Flamebound:IsAvailable() and Enemies8yCount == 1 and BeamAbility:CooldownRemains() >= Player:GCD()) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs 24"; end
  end
  -- felblade,if=fury.deficit>40+variable.fury_gen*(0.5%gcd.max)&(cooldown.vengeful_retreat.remains>=action.felblade.cooldown+0.5&talent.inertia&active_enemies=1|!talent.inertia|hero_tree.aldrachi_reaver|cooldown.essence_break.remains)&cooldown.metamorphosis.remains&cooldown.eye_beam.remains>=0.5+gcd.max*(talent.student_of_suffering&cooldown.sigil_of_flame.remains<=gcd.max)
  if S.Felblade:IsCastable() and (Player:FuryDeficit() > 40 + VarFuryGen * (0.5 / Player:GCD()) and (S.VengefulRetreat:CooldownRemains() >= 15.5 and S.Inertia:IsAvailable() and Enemies8yCount == 1 or not S.Inertia:IsAvailable() or VarHeroTree == 35 or S.EssenceBreak:CooldownDown()) and S.Metamorphosis:CooldownDown() and BeamAbility:CooldownRemains() >= 0.5 + Player:GCD() * num(S.StudentofSuffering:IsAvailable() and SigilAbility:CooldownRemains() <= Player:GCD())) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 26"; end
  end
  -- chaos_strike,if=cooldown.eye_beam.remains>=gcd.max*4|(fury>=70-30*(talent.student_of_suffering&(cooldown.sigil_of_flame.remains<=gcd.max|cooldown.sigil_of_flame.up))-buff.chaos_theory.up*20-variable.fury_gen)
  if S.ChaosStrike:IsReady() and (BeamAbility:CooldownRemains() >= Player:GCD() * 4 or (Player:Fury() >= 70 - 30 * num(S.StudentofSuffering:IsAvailable() and (SigilAbility:CooldownRemains() <= Player:GCD() or SigilAbility:CooldownUp())) - num(Player:BuffUp(S.ChaosTheoryBuff)) * 20 - VarFuryGen)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike fs 28"; end
  end
  -- immolation_aura,if=raid_event.adds.in>full_recharge_time&cooldown.eye_beam.remains>=gcd.max*(1+talent.student_of_suffering&(cooldown.sigil_of_flame.remains<=gcd.max|cooldown.sigil_of_flame.up))|active_enemies>desired_targets&active_enemies>2
  if ImmoAbility:IsReady() and (BeamAbility:CooldownRemains() >= Player:GCD() * (1 + num(S.StudentofSuffering:IsAvailable() and (SigilAbility:CooldownRemains() <= Player:GCD() or SigilAbility:CooldownUp()))) or Enemies8yCount > 2) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura fs 30"; end
  end
  -- felblade,if=buff.out_of_range.down&buff.inertia_trigger.down&cooldown.eye_beam.remains>=gcd.max*(1+talent.student_of_suffering&(cooldown.sigil_of_flame.remains<=gcd.max|cooldown.sigil_of_flame.up))
  if S.Felblade:IsCastable() and (Target:IsInRange(8) and InertiaTrigger() and BeamAbility:CooldownRemains() >= Player:GCD() * (1 + num(S.StudentofSuffering:IsAvailable() and (SigilAbility:CooldownRemains() <= Player:GCD() or SigilAbility:CooldownUp())))) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fs 32"; end
  end
  -- sigil_of_flame,if=buff.out_of_range.down&debuff.essence_break.down&!talent.student_of_suffering&(!talent.fel_barrage|cooldown.fel_barrage.remains>25|(active_enemies=1&!raid_event.adds.exists))
  if SigilAbility:IsCastable() and (Target:IsInRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and not S.StudentofSuffering:IsAvailable() and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > 25 or Enemies8yCount == 1)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability fs 34"; end
  end
  -- throw_glaive,if=recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.ThrowGlaive:IsReady() and (S.ThrowGlaive:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or S.ThrowGlaive:ChargesFractional() > 1.01) and Target:IsInRange(8) and Enemies8yCount > 1) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive fs 36"; end
  end
  -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&active_enemies>1
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and S.FelRush:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01) and Enemies8yCount > 1) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush fs 38"; end
  end
  -- arcane_torrent,if=buff.out_of_range.down&debuff.essence_break.down&fury<100
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Target:IsInRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:Fury() < 100) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent fs 40"; end
  end
end

local function ARCooldown()
  -- metamorphosis,if=(((cooldown.eye_beam.remains>=20|talent.cycle_of_hatred&cooldown.eye_beam.remains>=13)&(!talent.essence_break|debuff.essence_break.up)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&buff.inner_demon.down&(!talent.restless_hunter&cooldown.blade_dance.remains>gcd.max*3|prev_gcd.1.death_sweep))&!talent.inertia&!talent.essence_break&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and ((((BeamAbility:CooldownRemains() >= 20 or S.CycleofHatred:IsAvailable() and BeamAbility:CooldownRemains() >= 13) and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff)) and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and Player:BuffDown(S.InnerDemonBuff) and (not S.RestlessHunter:IsAvailable() and S.BladeDance:CooldownRemains() > Player:GCD() * 3 or Player:PrevGCD(1, S.DeathSweep))) and not S.Inertia:IsAvailable() and not S.EssenceBreak:IsAvailable() and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis ar_cooldown 2"; end
  end
  -- metamorphosis,if=(cooldown.blade_dance.remains&((prev_gcd.1.death_sweep|prev_gcd.2.death_sweep|prev_gcd.3.death_sweep|buff.metamorphosis.up&buff.metamorphosis.remains<gcd.max)&cooldown.eye_beam.remains&(!talent.essence_break|debuff.essence_break.up|talent.shattered_destiny)&buff.fel_barrage.down&(raid_event.adds.in>40|(raid_event.adds.remains>8|!talent.fel_barrage)&active_enemies>2)|!talent.chaotic_transformation|fight_remains<30)&(buff.inner_demon.down&(buff.rending_strike.down|!talent.restless_hunter|prev_gcd.1.death_sweep)))&(talent.inertia|talent.essence_break)&time>15
  if CDsON() and S.Metamorphosis:IsCastable() and ((S.BladeDance:CooldownDown() and ((Player:PrevGCD(1, S.DeathSweep) or Player:PrevGCD(2, S.DeathSweep) or Player:PrevGCD(3, S.DeathSweep) or Player:BuffUp(S.MetamorphosisBuff) and Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD()) and BeamAbility:CooldownDown() and (not S.EssenceBreak:IsAvailable() or Target:DebuffUp(S.EssenceBreakDebuff) or S.ShatteredDestiny:IsAvailable()) and Player:BuffDown(S.FelBarrageBuff) or not S.ChaoticTransformation:IsAvailable() or BossFightRemains < 30) and (Player:BuffDown(S.InnerDemonBuff) and (Player:BuffDown(S.RendingStrikeBuff) or not S.RestlessHunter:IsAvailable() or Player:PrevGCD(1, S.DeathSweep)))) and (S.Inertia:IsAvailable() or S.EssenceBreak:IsAvailable()) and CombatTime > 15) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis ar_cooldown 4"; end
  end
  -- potion,if=fight_remains<35|(buff.metamorphosis.up|debuff.essence_break.up)&time>10
  if Settings.Commons.Enabled.Potions and (BossFightRemains < 35 or (Player:BuffUp(S.MetamorphosisBuff) or Target:DebuffUp(S.EssenceBreakDebuff)) and CombatTime > 10) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ar_cooldown 6"; end
    end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.metamorphosis.up|fight_remains<=20
  -- Note: Not handling external buffs.
  -- variable,name=special_trinket,op=set,value=equipped.mad_queens_mandate|equipped.treacherous_transmitter|equipped.skardyns_grace|equipped.signet_of_the_priory
  VarSpecialTrinket = I.MadQueensMandate:IsEquipped() or I.TreacherousTransmitter:IsEquipped() or I.SkardynsGrace:IsEquipped() or I.SignetofthePriory:IsEquipped()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=mad_queens_mandate,if=((!talent.initiative|buff.initiative.up|time>5)&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(trinket.1.is.mad_queens_mandate&(trinket.2.cooldown.duration<10|trinket.2.cooldown.remains>10|!trinket.2.has_buff.any)|trinket.2.is.mad_queens_mandate&(trinket.1.cooldown.duration<10|trinket.1.cooldown.remains>10|!trinket.1.has_buff.any))&fight_remains>120|fight_remains<10&fight_remains<buff.metamorphosis.remains)&debuff.essence_break.down|fight_remains<5
    if I.MadQueensMandate:IsEquippedAndReady() and (((not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5) and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (VarTrinket1ID == I.MadQueensMandate:ID() and (VarTrinket2CD < 10 or Trinket2:CooldownRemains() > 10 or not Trinket2:HasUseBuff()) or VarTrinket2ID == I.MadQueensMandate:ID() and (VarTrinket1CD < 10 or Trinket1:CooldownRemains() > 10 or not Trinket1:HasUseBuff())) and FightRemains > 120 or BossFightRemains < 10 and BossFightRemains < Player:BuffRemains(S.MetamorphosisBuff)) and Target:DebuffDown(S.EssenceBreakDebuff) or BossFightRemains < 5) then
      if Cast(I.MadQueensMandate, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "mad_queens_mandate ar_cooldown 8"; end
    end
    -- use_item,name=treacherous_transmitter,if=!equipped.mad_queens_mandate|equipped.mad_queens_mandate&(trinket.1.is.mad_queens_mandate&trinket.1.cooldown.remains>fight_remains|trinket.2.is.mad_queens_mandate&trinket.2.cooldown.remains>fight_remains)|fight_remains>25
    if I.TreacherousTransmitter:IsEquippedAndReady() and (not I.MadQueensMandate:IsEquipped() or I.MadQueensMandate:IsEquipped() and (VarTrinket1ID == I.MadQueensMandate:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket2ID == I.MadQueensMandate:ID() and Trinket2:CooldownRemains() > FightRemains) or FightRemains > 25) then
      if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter ar_cooldown 10"; end
    end
    -- use_item,name=skardyns_grace,if=(!equipped.mad_queens_mandate|fight_remains>25|trinket.2.is.skardyns_grace&trinket.1.cooldown.remains>fight_remains|trinket.1.is.skardyns_grace&trinket.2.cooldown.remains>fight_remains|trinket.1.cooldown.duration<10|trinket.2.cooldown.duration<10)&buff.metamorphosis.up
    if I.SkardynsGrace:IsEquippedAndReady() and ((not I.MadQueensMandate:IsEquipped() or FightRemains > 25 or VarTrinket2ID == I.SkardynsGrace:ID() and Trinket1:CooldownRemains() > FightRemains or VarTrinket1ID == I.SkardynsGrace:ID() and Trinket2:CooldownRemains() > FightRemains or VarTrinket1CD < 10 or VarTrinket2CD < 10) and Player:BuffUp(S.MetamorphosisBuff)) then
      if Cast(I.SkardynsGrace, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "skardyns_grace ar_cooldown 12"; end
    end
    -- use_item,name=house_of_cards,if=(cooldown.eye_beam.up|buff.metamorphosis.up)|fight_remains<20
    if I.HouseofCards:IsEquippedAndReady() and (BeamAbility:CooldownUp() or Player:BuffUp(S.MetamorphosisBuff) or BossFightRemains < 20) then
      if Cast(I.HouseofCards, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "house_of_cards ar_cooldown 14"; end
    end
    -- use_item,name=signet_of_the_priory,if=time<20&(!talent.inertia|buff.inertia.up)|buff.metamorphosis.up&time>20|fight_remains<20
    if I.SignetofthePriory:IsEquippedAndReady() and (CombatTime < 20 and (not S.Inertia:IsAvailable() or Player:BuffUp(S.InertiaBuff)) or Player:BuffUp(S.MetamorphosisBuff) or BossFightRemains < 20) then
      if Cast(I.SignetofthePriory, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "signet_of_the_priory ar_cooldown 16"; end
    end
    -- use_item,name=ratfang_toxin,if=variable.tier33_4piece&variable.double_on_use|fight_remains<5
    if I.RatfangToxin:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 5) then
      if Cast(I.RatfangToxin, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "ratfang_toxin ar_cooldown 18"; end
    end
    -- use_item,name=geargrinders_spare_keys,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.GeargrindersSpareKeys:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.GeargrindersSpareKeys, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "geargrinders_spare_keys ar_cooldown 20"; end
    end
    -- use_item,name=grim_codex,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.GrimCodex:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.GrimCodex, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "grim_codex ar_cooldown 22"; end
    end
    -- use_item,name=ravenous_honey_buzzer,if=(variable.tier33_4piece&(buff.inertia.down&(cooldown.essence_break.remains&debuff.essence_break.down|!talent.essence_break))&(trinket.1.is.ravenous_honey_buzzer&(trinket.2.cooldown.duration<10|trinket.2.cooldown.remains>10|!trinket.2.has_buff.any)|trinket.2.is.ravenous_honey_buzzer&(trinket.1.cooldown.duration<10|trinket.1.cooldown.remains>10|!trinket.1.has_buff.any))&fight_remains>120|fight_remains<10&fight_remains<buff.metamorphosis.remains)|fight_remains<5
    if I.RavenousHoneyBuzzer:IsEquippedAndReady() and ((VarT334P and (Player:BuffDown(S.InertiaBuff) and (S.EssenceBreak:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff) or not S.EssenceBreak:IsAvailable())) and (VarTrinket1ID == I.RavenousHoneyBuzzer:ID() and (VarTrinket2CD < 10 or Trinket2:CooldownRemains() > 10 or not Trinket2:HasUseBuff()) or VarTrinket2ID == I.RavenousHoneyBuzzer:ID() and (VarTrinket1CD < 10 or Trinket1:CooldownRemains() > 10 or not Trinket1:HasUseBuff())) and FightRemains > 120 or BossFightRemains < 10 and BossFightRemains < Player:BuffRemains(S.MetamorphosisBuff)) or BossFightRemains < 5) then
      if Cast(I.RavenousHoneyBuzzer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ravenous_honey_buzzer ar_cooldown 24"; end
    end
    -- use_item,name=blastmaster3000,if=variable.tier33_4piece&variable.double_on_use|fight_remains<10
    if I.Blastmaster3000:IsEquippedAndReady() and (VarT334P and VarDoubleOnUse or BossFightRemains < 10) then
      if Cast(I.Blastmaster3000, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "blastmaster3000 ar_cooldown 26"; end
    end
    -- use_item,name=junkmaestros_mega_magnet,if=variable.tier33_4piece_magnet&variable.double_on_use&time>10|fight_remains<5
    if I.JunkmaestrosMegaMagnet:IsEquippedAndReady() and Player:BuffUp(S.JunkmaestrosBuff) and (VarT334PMagnet and VarDoubleOnUse and CombatTime > 10 or BossFightRemains < 5) then
      if Cast(I.JunkmaestrosMegaMagnet, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "junkmaestros_mega_magnet ar_cooldown 28"; end
    end
    -- do_treacherous_transmitter_task,if=cooldown.eye_beam.remains>15|cooldown.eye_beam.remains<5|fight_remains<20|buff.metamorphosis.up
    -- use_item,slot=trinket1,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.1.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.1.has_buff.any|fight_remains<25)&!trinket.1.is.mister_locknstalk&!variable.trinket1_crit&!trinket.1.is.skardyns_grace&!trinket.1.is.treacherous_transmitter&(!variable.special_trinket|trinket.2.cooldown.remains>20)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and not VarTrinket1Exclude and (((BeamAbility:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket1:HasUseBuff() or BossFightRemains < 25) and not VarTrinket1ID == I.MisterLockNStalk:ID() and not VarTrinket1Crit and not VarTrinket1ID == I.SkardynsGrace:ID() and not VarTrinket1ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket2:CooldownRemains() > 20)) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "treacherous_transmitter ar_cooldown 30"; end
    end
    -- use_item,slot=trinket2,if=((cooldown.eye_beam.remains<gcd.max&active_enemies>1|buff.metamorphosis.up)&(raid_event.adds.in>trinket.2.cooldown.duration-15|raid_event.adds.remains>8)|!trinket.2.has_buff.any|fight_remains<25)&!trinket.2.is.mister_locknstalk&!variable.trinket2_crit&!trinket.2.is.skardyns_grace&!trinket.2.is.treacherous_transmitter&(!variable.special_trinket|trinket.1.cooldown.remains>20)
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and not VarTrinket2Exclude and (((BeamAbility:CooldownRemains() < Player:GCD() and Enemies8yCount > 1 or Player:BuffUp(S.MetamorphosisBuff)) or not Trinket2:HasUseBuff() or BossFightRemains < 25) and not VarTrinket2ID == I.MisterLockNStalk:ID() and not VarTrinket2Crit and not VarTrinket2ID == I.SkardynsGrace:ID() and not VarTrinket2ID == I.TreacherousTransmitter:ID() and (not VarSpecialTrinket or Trinket1:CooldownRemains() > 20)) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "treacherous_transmitter ar_cooldown 32"; end
    end
  end
  -- the_hunt,if=debuff.essence_break.down&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>90)&(debuff.reavers_mark.up|!hero_tree.aldrachi_reaver)&buff.reavers_glaive.down&(buff.metamorphosis.remains>5|buff.metamorphosis.down)&(!talent.initiative|buff.initiative.up|time>5)&time>5&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down)
  if CDsON() and S.TheHunt:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and (Target:DebuffUp(S.ReaversMarkDebuff) or VarHeroTree ~= 35) and not S.ReaversGlaive:IsLearned() and (Player:BuffRemains(S.MetamorphosisBuff) > 5 or Player:BuffDown(S.MetamorphosisBuff)) and (not S.Initiative:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5) and CombatTime > 5 and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger())) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar_cooldown 34"; end
  end
  -- sigil_of_spite,if=debuff.essence_break.down&(debuff.reavers_mark.remains>=2-talent.quickened_sigils)&cooldown.blade_dance.remains&time>15
  if CDsON() and S.SigilofSpite:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (Target:DebuffRemains(S.ReaversMarkDebuff) >= 2 - num(S.QuickenedSigils:IsAvailable())) and S.BladeDance:CooldownDown() and CombatTime> 15) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_of_spite ar_cooldown 36"; end
  end
end

local function ARFelBarrage()
  -- variable,name=generator_up,op=set,value=cooldown.felblade.remains<gcd.max|cooldown.sigil_of_flame.remains<gcd.max
  local VarGeneratorUp = S.Felblade:CooldownRemains() < Player:GCD() or SigilAbility:CooldownRemains() < Player:GCD()
  -- variable,name=gcd_drain,op=set,value=gcd.max*32
  local VarGCDDrain = Player:GCD() * 32
  -- annihilation,if=buff.inner_demon.up
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_fel_barrage 2"; end
  end
  -- eye_beam,if=buff.fel_barrage.down&(active_enemies>1&raid_event.adds.up|raid_event.adds.in>40)
  if BeamAbility:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze ar_fel_barrage 4"; end
  end
  -- essence_break,if=buff.fel_barrage.down&buff.metamorphosis.up
  if S.EssenceBreak:IsCastable() and (Player:BuffDown(S.FelBarrageBuff) and Player:BuffUp(S.MetamorphosisBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_fel_barrage 6"; end
  end
  -- death_sweep,if=buff.fel_barrage.down
  if S.DeathSweep:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep ar_fel_barrage 8"; end
  end
  -- immolation_aura,if=(active_enemies>2|buff.fel_barrage.up)&(cooldown.eye_beam.remains>recharge_time+3)
  if ImmoAbility:IsReady() and ((Enemies8yCount > 2 or Player:BuffUp(S.FelBarrageBuff)) and (BeamAbility:CooldownRemains() > ImmoAbility:Recharge() + 3)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar_fel_barrage 10"; end
  end
  -- glaive_tempest,if=buff.fel_barrage.down&active_enemies>1
  if S.GlaiveTempest:IsReady() and (Player:BuffDown(S.FelBarrageBuff) and Enemies8yCount > 1) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest ar_fel_barrage 12"; end
  end
  -- blade_dance,if=buff.fel_barrage.down
  if S.BladeDance:IsReady() and (Player:BuffDown(S.FelBarrageBuff)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance ar_fel_barrage 14"; end
  end
  -- fel_barrage,if=fury>100&(raid_event.adds.in>90|raid_event.adds.in<gcd.max|raid_event.adds.remains>4&active_enemies>2)
  if S.FelBarrage:IsReady() and (Player:Fury() > 100) then
    if Cast(S.FelBarrage, Settings.Havoc.GCDasOffGCD.FelBarrage, nil, not IsInMeleeRange(8)) then return "fel_barrage ar_fel_barrage 16"; end
  end
  -- felblade,if=buff.inertia_trigger.up&buff.fel_barrage.up
  if S.Felblade:IsCastable() and (InertiaTrigger() and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_fel_barrage 18"; end
  end
  -- sigil_of_flame,if=fury.deficit>40&buff.fel_barrage.up
  if SigilAbility:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar_fel_barrage 20"; end
  end
  -- felblade,if=buff.fel_barrage.up&fury.deficit>40
  if S.Felblade:IsCastable() and (Player:BuffUp(S.FelBarrageBuff) and Player:FuryDeficit() > 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade fel_barrage 22"; end
  end
  -- death_sweep,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.DeathSweep:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep ar_fel_barrage 24"; end
  end
  -- glaive_tempest,if=fury-variable.gcd_drain-30>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.GlaiveTempest:IsReady() and (Player:Fury() - VarGCDDrain - 30 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest ar_fel_barrage 26"; end
  end
  -- blade_dance,if=fury-variable.gcd_drain-35>0&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.BladeDance:IsReady() and (Player:Fury() - VarGCDDrain - 35 > 0 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance ar_fel_barrage 28"; end
  end
  -- arcane_torrent,if=fury.deficit>40&buff.fel_barrage.up
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Player:FuryDeficit() > 40 and Player:BuffUp(S.FelBarrageBuff)) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent ar_fel_barrage 30"; end
  end
  -- the_hunt,if=fury>40&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>80)
  if CDsON() and S.TheHunt:IsCastable() and (Player:Fury() > 40) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsSpellInRange(S.TheHunt)) then return "the_hunt ar_fel_barrage 32"; end
  end
  -- annihilation,if=fury-variable.gcd_drain-40>20&(buff.fel_barrage.remains<3|variable.generator_up|fury>80|variable.fury_gen>18)
  if S.Annihilation:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (Player:BuffRemains(S.FelBarrageBuff) < 3 or VarGeneratorUp or Player:Fury() > 80 or VarFuryGen > 18)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_fel_barrage 34"; end
  end
  -- chaos_strike,if=fury-variable.gcd_drain-40>20&(cooldown.fel_barrage.remains&cooldown.fel_barrage.remains<10&fury>100|buff.fel_barrage.up&(buff.fel_barrage.remains*variable.fury_gen-buff.fel_barrage.remains*32)>0)
  if S.ChaosStrike:IsReady() and (Player:Fury() - VarGCDDrain - 40 > 20 and (S.FelBarrage:CooldownDown() and S.FelBarrage:CooldownRemains() < 10 and Player:Fury() > 100 or Player:BuffUp(S.FelBarrageBuff) and (Player:BuffRemains(S.FelBarrageBuff) * VarFuryGen - Player:BuffRemains(S.FelBarrageBuff) * 32) > 0)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar_fel_barrage 36"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite ar_fel_barrage 38"; end
  end
end

local function ARMeta()
  -- death_sweep,if=buff.metamorphosis.remains<gcd.max|debuff.essence_break.up|cooldown.metamorphosis.up&!talent.restless_hunter
  if S.DeathSweep:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() or Target:DebuffUp(S.EssenceBreakDebuff) or S.Metamorphosis:CooldownUp() and not S.RestlessHunter:IsAvailable()) then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep ar_meta 2"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&(cooldown.metamorphosis.remains&(cooldown.essence_break.remains<=0.6|cooldown.essence_break.remains>10|!talent.essence_break)|talent.restless_hunter)&cooldown.eye_beam.remains&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down)
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and (S.Metamorphosis:CooldownDown() and (S.EssenceBreak:CooldownRemains() <= 0.6 or S.EssenceBreak:CooldownRemains() > 10 or not S.EssenceBreak:IsAvailable()) or S.RestlessHunter:IsAvailable()) and BeamAbility:CooldownDown() and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger())) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat ar_meta 4"; end
  end
  -- felblade,if=talent.inertia&buff.inertia_trigger.up&cooldown.essence_break.remains<=1&cooldown.blade_dance.remains<=gcd.max*2&cooldown.metamorphosis.remains<=gcd.max*3
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and S.EssenceBreak:CooldownRemains() <= 1 and S.BladeDance:CooldownRemains() <= Player:GCD() * 2 and S.Metamorphosis:CooldownRemains() <= Player:GCD() * 3) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_meta 6"; end
  end
  -- essence_break,if=fury>=30&talent.restless_hunter&cooldown.metamorphosis.up&(talent.inertia&buff.inertia.up|!talent.inertia)&cooldown.blade_dance.remains<=gcd.max
  if S.EssenceBreak:IsCastable() and (Player:Fury() >= 30 and S.RestlessHunter:IsAvailable() and S.Metamorphosis:CooldownUp() and (S.Inertia:IsAvailable() and Player:BuffUp(S.InertiaBuff) or not S.Inertia:IsAvailable()) and S.BladeDance:CooldownRemains() <= Player:GCD()) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_meta 8"; end
  end
  -- annihilation,if=buff.metamorphosis.remains<gcd.max|debuff.essence_break.remains&debuff.essence_break.remains<0.5&cooldown.blade_dance.remains|buff.inner_demon.up&cooldown.essence_break.up&cooldown.metamorphosis.up
  -- Note: Adding 0.5s extra to the debuff check to account for player latency.
  if S.Annihilation:IsReady() and (Player:BuffRemains(S.MetamorphosisBuff) < Player:GCD() or Target:DebuffUp(S.EssenceBreakDebuff) and Target:DebuffRemains(S.EssenceBreakDebuff) < 1 and S.BladeDance:CooldownDown() or Player:BuffUp(S.InnerDemonBuff) and S.EssenceBreak:CooldownUp() and S.Metamorphosis:CooldownUp()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_meta 10"; end
  end
  -- felblade,if=buff.inertia_trigger.up&talent.inertia&cooldown.metamorphosis.remains&(cooldown.eye_beam.remains<=0.5|cooldown.essence_break.remains<=0.5|cooldown.blade_dance.remains<=5.5|buff.initiative.remains<gcd.remains)
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and S.Metamorphosis:CooldownDown() and (BeamAbility:CooldownRemains() <= 0.5 or S.EssenceBreak:CooldownRemains() <= 0.5 or S.BladeDance:CooldownRemains() <= 5.5 or Player:BuffRemains(S.InitiativeBuff) < Player:GCDRemains())) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_meta 12"; end
  end
  -- Note: Inertia check is used for both lines.
  if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and InertiaTrigger()) and (
    -- fel_rush,if=buff.inertia_trigger.up&talent.inertia&cooldown.metamorphosis.remains&active_enemies>2
    (S.Metamorphosis:CooldownDown() and Enemies8yCount > 2) or
    -- fel_rush,if=buff.inertia_trigger.up&talent.inertia&cooldown.blade_dance.remains<gcd.max*3&cooldown.metamorphosis.remains&active_enemies>2
    (S.BladeDance:CooldownRemains() < Player:GCD() * 3 and S.Metamorphosis:CooldownDown() and Enemies8yCount > 2)
  ) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush ar_meta 14"; end
  end
  -- immolation_aura,if=charges=2&active_enemies>1&debuff.essence_break.down
  if ImmoAbility:IsCastable() and (ImmoAbility:Charges() == 2 and Enemies8yCount > 1 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar_meta 16"; end
  end
  -- annihilation,if=buff.inner_demon.up&(cooldown.eye_beam.remains<gcd.max*3&cooldown.blade_dance.remains|cooldown.metamorphosis.remains<gcd.max*3)
  if S.Annihilation:IsReady() and (Player:BuffUp(S.InnerDemonBuff) and (BeamAbility:CooldownRemains() < Player:GCD() * 3 and S.BladeDance:CooldownDown() or S.Metamorphosis:CooldownRemains() < Player:GCD() * 3)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_meta 18"; end
  end
  -- essence_break,if=time<20&buff.thrill_of_the_fight_damage.remains>gcd.max*4&buff.metamorphosis.remains>=gcd.max*2&cooldown.metamorphosis.up&cooldown.death_sweep.remains<=gcd.max&buff.inertia.up
  if S.EssenceBreak:IsCastable() and (CombatTime < 20 and Player:BuffRemains(S.ThrilloftheFightHavocDmgBuff) > Player:GCD() * 4 and Player:BuffRemains(S.MetamorphosisBuff) >= Player:GCD() * 2 and S.Metamorphosis:CooldownUp() and S.DeathSweep:CooldownRemains() <= Player:GCD() and Player:BuffUp(S.InertiaBuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_meta 20"; end
  end
  -- essence_break,if=fury>20&(cooldown.blade_dance.remains<gcd.max*3|cooldown.blade_dance.up)&(buff.unbound_chaos.down&!talent.inertia|buff.inertia.up)&buff.out_of_range.remains<gcd.max&(!talent.shattered_destiny|cooldown.eye_beam.remains>4)|fight_remains<10
  -- Note: Simplifying blade_dance check, as 0 (cooldown up) is less than gcd.max*3.
  if S.EssenceBreak:IsCastable() and (Player:Fury() > 20 and S.BladeDance:CooldownRemains() < Player:GCD() * 3 and (Player:BuffDown(S.UnboundChaosBuff) and not S.Inertia:IsAvailable() or Player:BuffUp(S.InertiaBuff)) and (not S.ShatteredDestiny:IsAvailable() or BeamAbility:CooldownRemains() > 4) or BossFightRemains < 10) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_meta 22"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep ar_meta 24"; end
  end
  -- eye_beam,if=debuff.essence_break.down&buff.inner_demon.down
  if BeamAbility:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff)) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze ar_meta 26"; end
  end
  -- glaive_tempest,if=debuff.essence_break.down&(cooldown.blade_dance.remains>gcd.max*2|fury>60)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10)
  if S.GlaiveTempest:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and (S.BladeDance:CooldownRemains() > Player:GCD() * 2 or Player:Fury() > 60)) then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest ar_meta 28"; end
  end
  -- sigil_of_flame,if=active_enemies>2&debuff.essence_break.down
  if SigilAbility:IsCastable() and (Enemies8yCount > 2 and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar_meta 30"; end
  end
  -- throw_glaive,if=talent.soulscar&talent.furious_throws&active_enemies>1&debuff.essence_break.down&(charges=2|full_recharge_time<cooldown.blade_dance.remains)
  if S.ThrowGlaive:IsCastable() and (S.Soulscar:IsAvailable() and S.FuriousThrows:IsAvailable() and Enemies8yCount > 1 and Target:DebuffDown(S.EssenceBreakDebuff) and (S.ThrowGlaive:Charges() == 2 or S.ThrowGlaive:FullRechargeTime() < S.BladeDance:CooldownRemains())) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive ar_meta 32"; end
  end
  -- annihilation,if=cooldown.blade_dance.remains|fury>60|soul_fragments.total>0|buff.metamorphosis.remains<5&cooldown.felblade.up
  local TotalSoulFragments = DemonHunter.Souls.AuraSouls + DemonHunter.Souls.IncomingSouls
  if S.Annihilation:IsReady() and (S.BladeDance:CooldownDown() or Player:Fury() > 60 or TotalSoulFragments > 0 or Player:BuffRemains(S.MetamorphosisBuff) < 5 and S.Felblade:CooldownUp()) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_meta 34"; end
  end
  -- sigil_of_flame,if=buff.metamorphosis.remains>5&buff.out_of_range.down
  if SigilAbility:IsCastable() and (Player:BuffRemains(S.MetamorphosisBuff) > 5 and Target:IsInRange(30)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar_meta 36"; end
  end
  -- felblade,if=fury.deficit>40&!buff.inertia_trigger.up
  if S.Felblade:IsCastable() and (Player:FuryDeficit() > 40 and not InertiaTrigger()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_meta 38"; end
  end
  -- sigil_of_flame,if=debuff.essence_break.down&buff.out_of_range.down
  if SigilAbility:IsCastable() and (Target:DebuffDown(S.EssenceBreakDebuff) and Target:IsInRange(30)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar_meta 40"; end
  end
  -- immolation_aura,if=buff.out_of_range.down&recharge_time<(cooldown.eye_beam.remains<?buff.metamorphosis.remains)&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
  if ImmoAbility:IsCastable() and (IsInMeleeRange(8) and ImmoAbility:Recharge() < (mathmax(BeamAbility:CooldownRemains(), Player:BuffRemains(S.MetamorphosisBuff)))) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar_meta 42"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_meta 44"; end
  end
  -- fel_rush,if=recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.FelRush:IsCastable() and UseFelRush() and (S.FelRush:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or S.FelRush:ChargesFractional() > 1.01) and IsInMeleeRange(15) and Enemies8yCount > 1) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush ar_meta 46"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite ar_meta 48"; end
  end
end

local function AROpener()
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ar_opener 2"; end
    end
  end
  -- the_hunt
  if CDsON() and S.TheHunt:IsCastable() then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar_opener 4"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&time>4&buff.metamorphosis.up&(!talent.inertia|buff.inertia_trigger.down)&buff.inner_demon.down&cooldown.blade_dance.remains&gcd.remains<0.1
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and CombatTime > 4 and Player:BuffUp(S.MetamorphosisBuff) and (not S.Inertia:IsAvailable() or Player:BuffDown(S.InertiaBuff)) and Player:BuffDown(S.InnerDemonBuff) and S.BladeDance:CooldownDown()) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat ar_opener 6"; end
  end
  -- annihilation,if=buff.rending_strike.up&buff.thrill_of_the_fight_damage.down
  if S.Annihilation:IsReady() and (Player:BuffUp(S.RendingStrikeBuff) and Player:BuffDown(S.ThrilloftheFightHavocDmgBuff)) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_opener 8"; end
  end
  -- felblade,if=!talent.inertia&talent.unbound_chaos&buff.unbound_chaos.up&buff.initiative.up&debuff.essence_break.down&active_enemies<=2
  -- Note: Moved active_enemies check to the beginning of the line.
  if S.Felblade:IsCastable() and (Enemies8yCount <= 2 and not S.Inertia:IsAvailable() and S.UnboundChaos:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and Player:BuffUp(S.InitiativeBuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_opener 10"; end
  end
  -- fel_rush,if=!talent.inertia&talent.unbound_chaos&buff.unbound_chaos.up&buff.initiative.up&debuff.essence_break.down&active_enemies>2
  if S.FelRush:IsCastable() and UseFelRush() and (Enemies8yCount > 2 and not S.Inertia:IsAvailable() and S.UnboundChaos:IsAvailable() and Player:BuffUp(S.UnboundChaosBuff) and Player:BuffUp(S.InitiativeBuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush ar_opener 12"; end
  end
  -- annihilation,if=talent.inner_demon&buff.inner_demon.up&(!talent.essence_break|cooldown.essence_break.up)
  if S.Annihilation:IsReady() and (S.InnerDemon:IsAvailable() and Player:BuffUp(S.InnerDemonBuff) and (not S.EssenceBreak:IsAvailable() or S.EssenceBreak:CooldownUp())) then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_opener 14"; end
  end
  -- essence_break,if=(buff.inertia.up|!talent.inertia)&buff.metamorphosis.up&cooldown.blade_dance.remains<=gcd.max&debuff.reavers_mark.up
  if S.EssenceBreak:IsCastable() and ((Player:BuffUp(S.InertiaBuff) or not S.Inertia:IsAvailable()) and Player:BuffUp(S.MetamorphosisBuff) and S.BladeDance:CooldownRemains() <= Player:GCD() and Target:DebuffUp(S.ReaversMarkDebuff)) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_opener 16"; end
  end
  -- felblade,if=buff.inertia_trigger.up&talent.inertia&talent.restless_hunter&cooldown.essence_break.up&cooldown.metamorphosis.up&buff.metamorphosis.up&cooldown.blade_dance.remains<=gcd.max
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and S.RestlessHunter:IsAvailable() and S.EssenceBreak:CooldownUp() and S.Metamorphosis:CooldownUp() and Player:BuffUp(S.MetamorphosisBuff) and S.BladeDance:CooldownRemains() <= Player:GCD()) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_opener 18"; end
  end
  -- felblade,if=talent.inertia&buff.inertia_trigger.up&(buff.inertia.down&buff.metamorphosis.up)&debuff.essence_break.down&active_enemies<=2
  -- Note: Moved active_enemies check to the beginning of the line.
  if S.Felblade:IsCastable() and (Enemies8yCount <= 2 and S.Inertia:IsAvailable() and InertiaTrigger() and (Player:BuffDown(S.InertiaBuff) and Player:BuffUp(S.MetamorphosisBuff)) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_opener 20"; end
  end
  -- fel_rush,if=talent.inertia&buff.inertia_trigger.up&(buff.inertia.down&buff.metamorphosis.up)&debuff.essence_break.down&(cooldown.felblade.remains|active_enemies>2)
  if S.FelRush:IsCastable() and UseFelRush() and (S.Inertia:IsAvailable() and InertiaTrigger() and (Player:BuffDown(S.InertiaBuff) and Player:BuffUp(S.MetamorphosisBuff)) and Target:DebuffDown(S.EssenceBreakDebuff) and (S.Felblade:CooldownDown() or Enemies8yCount > 2)) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush ar_opener 22"; end
  end
  -- felblade,if=talent.inertia&buff.inertia_trigger.up&buff.metamorphosis.up&cooldown.metamorphosis.remains&debuff.essence_break.down
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and Player:BuffUp(S.MetamorphosisBuff) and S.Metamorphosis:CooldownDown() and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_opener 24"; end
  end
  -- the_hunt,if=(buff.metamorphosis.up&hero_tree.aldrachi_reaver&talent.shattered_destiny|!talent.shattered_destiny&hero_tree.aldrachi_reaver|hero_tree.felscarred)&(!talent.initiative|talent.inertia|buff.initiative.up|time>5)
  if CDsON() and S.TheHunt:IsCastable() and ((Player:BuffUp(S.MetamorphosisBuff) and VarHeroTree == 35 and S.ShatteredDestiny:IsAvailable() or not S.ShatteredDestiny:IsAvailable() and VarHeroTree == 35 or VarHeroTree == 34) and (not S.Initiative:IsAvailable() or S.Inertia:IsAvailable() or Player:BuffUp(S.InitiativeBuff) or CombatTime > 5)) then
    if Cast(S.TheHunt, nil, Settings.CommonsDS.DisplayStyle.TheHunt, not Target:IsInRange(50)) then return "the_hunt ar_opener 26"; end
  end
  -- felblade,if=fury<40&buff.inertia_trigger.down&debuff.essence_break.down
  if S.Felblade:IsCastable() and (Player:Fury() < 40 and InertiaTrigger() and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar_opener 28"; end
  end
  -- reavers_glaive,if=debuff.reavers_mark.down&debuff.essence_break.down
  if S.ReaversGlaive:IsCastable() and (Target:DebuffDown(S.ReaversMarkDebuff) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.ReaversGlaive, nil, nil, not Target:IsInRange(50)) then return "reavers_glaive ar_opener 30"; end
  end
  -- chaos_strike,if=buff.rending_strike.up&active_enemies>2
  if S.ChaosStrike:IsReady() and (Player:BuffUp(S.RendingStrikeBuff) and Enemies8yCount > 2) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar_opener 32"; end
  end
  -- blade_dance,if=buff.glaive_flurry.up&active_enemies>2
  if S.BladeDance:IsReady() and (Player:BuffUp(S.GlaiveFlurryBuff) and Enemies8yCount > 2) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance ar_opener 34"; end
  end
  -- immolation_aura,if=talent.a_fire_inside&talent.burning_wound&buff.metamorphosis.down
  if ImmoAbility:IsCastable() and (S.AFireInside:IsAvailable() and S.BurningWound:IsAvailable() and Player:BuffDown(S.MetamorphosisBuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar_opener 36"; end
  end
  -- metamorphosis,if=buff.metamorphosis.up&cooldown.blade_dance.remains>gcd.max*2&buff.inner_demon.down&(!talent.restless_hunter|prev_gcd.1.death_sweep)&(cooldown.essence_break.remains|!talent.essence_break)
  if CDsON() and S.Metamorphosis:IsCastable() and (Player:BuffUp(S.MetamorphosisBuff) and S.BladeDance:CooldownRemains() > Player:GCD() * 2 and Player:BuffDown(S.InnerDemonBuff) and (not S.RestlessHunter:IsAvailable() or Player:PrevGCD(1, S.DeathSweep)) and (S.EssenceBreak:CooldownDown() or not S.EssenceBreak:IsAvailable())) then
    if Cast(S.Metamorphosis, nil, Settings.CommonsDS.DisplayStyle.Metamorphosis, not Target:IsInRange(40)) then return "metamorphosis ar_opener 38"; end
  end
  -- sigil_of_spite,if=debuff.reavers_mark.up&(cooldown.eye_beam.remains&cooldown.metamorphosis.remains)&debuff.essence_break.down
  if S.SigilofSpite:IsCastable() and (Target:DebuffUp(S.ReaversMarkDebuff) and (BeamAbility:CooldownDown() and S.Metamorphosis:CooldownDown()) and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not IsInMeleeRange(30)) then return "sigil_of_spite ar_opener 40"; end
  end
  -- eye_beam,if=buff.metamorphosis.down|debuff.essence_break.down&buff.inner_demon.down&(cooldown.blade_dance.remains|talent.essence_break&cooldown.essence_break.up)
  if BeamAbility:IsReady() and (Player:BuffDown(S.MetamorphosisBuff) or Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.InnerDemonBuff) and (S.BladeDance:CooldownDown() or S.EssenceBreak:IsAvailable() and S.EssenceBreak:CooldownUp())) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze ar_opener 42"; end
  end
  -- essence_break,if=cooldown.blade_dance.remains<gcd.max&!hero_tree.felscarred&!talent.shattered_destiny&buff.metamorphosis.up|cooldown.eye_beam.remains&cooldown.metamorphosis.remains
  if S.EssenceBreak:IsCastable() and (S.BladeDance:CooldownRemains() < Player:GCD() and VarHeroTree ~= 34 and not S.ShatteredDestiny:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff) or BeamAbility:CooldownDown() and S.Metamorphosis:CooldownDown()) then
    if Cast(S.EssenceBreak, Settings.Havoc.GCDasOffGCD.EssenceBreak, nil, not IsInMeleeRange(10)) then return "essence_break ar_opener 44"; end
  end
  -- death_sweep
  if S.DeathSweep:IsReady() then
    if Cast(S.DeathSweep, nil, nil, not IsInMeleeRange(8)) then return "death_sweep ar_opener 46"; end
  end
  -- annihilation
  if S.Annihilation:IsReady() then
    if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar_opener 48"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite ar_opener 50"; end
  end
end

local function AR()
  -- variable,name=rg_inc,op=set,value=buff.rending_strike.down&buff.glaive_flurry.up&cooldown.blade_dance.up&gcd.remains=0|variable.rg_inc&prev_gcd.1.death_sweep
  local VarRGInc = Player:BuffDown(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff) and S.BladeDance:CooldownUp() or VarRGInc and Player:PrevGCD(1, S.DeathSweep)
  -- pick_up_fragment,use_off_gcd=1,if=fury<=90
  -- variable,name=fel_barrage,op=set,value=talent.fel_barrage&(cooldown.fel_barrage.remains<gcd.max*7&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in<gcd.max*7|raid_event.adds.in>90)&(cooldown.metamorphosis.remains|active_enemies>2)|buff.fel_barrage.up)&!(active_enemies=1&!raid_event.adds.exists)
  local VarFelBarrage = S.FelBarrage:IsAvailable() and (S.FelBarrage:CooldownRemains() < Player:GCD() * 7 and (S.Metamorphosis:CooldownDown() or Enemies12yCount > 2) or Player:BuffUp(S.FelBarrage))
  -- chaos_strike,if=buff.rending_strike.up&buff.glaive_flurry.up&(variable.rg_ds=2|active_enemies>2)&time>10
  -- annihilation,if=buff.rending_strike.up&buff.glaive_flurry.up&(variable.rg_ds=2|active_enemies>2)
  if Player:BuffUp(S.RendingStrikeBuff) and Player:BuffUp(S.GlaiveFlurryBuff) and (VarRGDS == 2 or Enemies8yCount > 2) then
    if S.ChaosStrike:IsReady() and CombatTime > 10 then
      if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar 2"; end
    end
    if S.Annihilation:IsReady() then
      if Cast(S.Annihilation, nil, nil, not IsInMeleeRange(5)) then return "annihilation ar 4"; end
    end
  end
  -- reavers_glaive,if=buff.glaive_flurry.down&buff.rending_strike.down&buff.thrill_of_the_fight_damage.remains<gcd.max*4+(variable.rg_ds=2)+(cooldown.the_hunt.remains<gcd.max*3)*3+(cooldown.eye_beam.remains<gcd.max*3&talent.shattered_destiny)*3&(variable.rg_ds=0|variable.rg_ds=1&cooldown.blade_dance.up|variable.rg_ds=2&cooldown.blade_dance.remains)&(buff.thrill_of_the_fight_damage.up|!prev_gcd.1.death_sweep|!variable.rg_inc)&active_enemies<3&!action.reavers_glaive.last_used<5&debuff.essence_break.down&(buff.metamorphosis.remains>2|cooldown.eye_beam.remains<10|fight_remains<10)
  if S.ReaversGlaive:IsReady() and (Player:BuffDown(S.GlaiveFlurryBuff) and Player:BuffDown(S.RendingStrikeBuff) and Player:BuffRemains(S.ThrilloftheFightHavocDmgBuff) < Player:GCD() * 4 + num(VarRGDS == 2) + num(S.TheHunt:CooldownRemains() < Player:GCD() * 3) * 3 + num(BeamAbility:CooldownRemains() < Player:GCD() * 3 and S.ShatteredDestiny:IsAvailable()) * 3 and (VarRGDS == 0 or VarRGDS == 1 and S.BladeDance:CooldownUp() or VarRGDS == 2 and S.BladeDance:CooldownDown()) and (Player:BuffUp(S.ThrilloftheFightHavocDmgBuff) or not Player:PrevGCD(1, S.DeathSweep) or not VarRGInc) and Enemies8yCount < 3 and S.ReaversGlaive:TimeSinceLastCast() >= 5 and Target:DebuffDown(S.EssenceBreakDebuff) and (Player:BuffRemains(S.MetamorphosisBuff) > 2 or BeamAbility:CooldownRemains() < 10 or BossFightRemains < 10)) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsInRange(50)) then return "reavers_glaive ar 6"; end
  end
  -- reavers_glaive,if=buff.glaive_flurry.down&buff.rending_strike.down&buff.thrill_of_the_fight_damage.remains<4&(buff.thrill_of_the_fight_damage.up|!prev_gcd.1.death_sweep|!variable.rg_inc)&active_enemies>2|fight_remains<10
  if S.ReaversGlaive:IsReady() and (Player:BuffDown(S.GlaiveFlurryBuff) and Player:BuffDown(S.RendingStrikeBuff) and Player:BuffRemains(S.ThrilloftheFightHavocDmgBuff) < 4 and (Player:BuffUp(S.ThrilloftheFightHavocDmgBuff) or not Player:PrevGCD(1, S.DeathSweep) or not VarRGInc) and Enemies8yCount > 2 or BossFightRemains < 10) then
    if Cast(S.ReaversGlaive, Settings.CommonsOGCD.OffGCDasOffGCD.ReaversGlaive, nil, not Target:IsInRange(50)) then return "reavers_glaive ar 8"; end
  end
  -- call_action_list,name=ar_cooldown
  local ShouldReturn = ARCooldown(); if ShouldReturn then return ShouldReturn; end
  -- run_action_list,name=ar_opener,if=(cooldown.eye_beam.up|cooldown.metamorphosis.up|cooldown.essence_break.up)&time<15&(raid_event.adds.in>20)
  if (BeamAbility:CooldownUp() or S.Metamorphosis:CooldownUp() or S.EssenceBreak:CooldownUp()) and CombatTime < 15 and Player:BuffStack(S.DemonsurgeBuff) < 5 then
    local ShouldReturn = AROpener(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for AROpener()"; end
  end
  -- sigil_of_spite,if=debuff.essence_break.down&cooldown.blade_dance.remains&debuff.reavers_mark.remains>=2-talent.quickened_sigils&(buff.necessary_sacrifice.remains>=2-talent.quickened_sigils|!set_bonus.thewarwithin_season_2_4pc|cooldown.eye_beam.remains>8)&(buff.metamorphosis.down|buff.metamorphosis.remains+talent.shattered_destiny>=buff.necessary_sacrifice.remains+2-talent.quickened_sigils)|fight_remains<20
  if S.SigilofSpite:IsReady() and (Target:DebuffDown(S.EssenceBreakDebuff) and S.BladeDance:CooldownDown() and Target:DebuffRemains(S.ReaversMarkDebuff) >= 2 - num(S.QuickenedSigils:IsAvailable()) and (Player:BuffRemains(S.NecessarySacrificeBuff) >= 2 - num(S.QuickenedSigils:IsAvailable()) or not Player:HasTier("TWW2", 4) or BeamAbility:CooldownRemains() > 8) and (Player:BuffDown(S.MetamorphosisBuff) or Player:BuffRemains(S.MetamorphosisBuff) + num(S.ShatteredDestiny:IsAvailable()) >= Player:BuffRemains(S.NecessarySacrificeBuff) + 2 - num(S.QuickenedSigils:IsAvailable())) or BossFightRemains < 20) then
    if Cast(S.SigilofSpite, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "elysian_decree ar 10"; end
  end
  -- run_action_list,name=ar_fel_barrage,if=variable.fel_barrage&raid_event.adds.up
  if VarFelBarrage then
    local ShouldReturn = ARFelBarrage(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for ARFelBarrage()"; end
  end
  -- immolation_aura,if=active_enemies>2&talent.ragefire&(!talent.fel_barrage|cooldown.fel_barrage.remains>recharge_time)&debuff.essence_break.down&(buff.metamorphosis.down|buff.metamorphosis.remains>5)
  -- immolation_aura,if=active_enemies>2&talent.ragefire&raid_event.adds.up&raid_event.adds.remains<15&raid_event.adds.remains>5&debuff.essence_break.down
  -- Note: We can't check raid_event conditions, so simply checking for active_enemies>2 will make this line supercede the previous line.
  if ImmoAbility:IsReady() and (Enemies8yCount > 2 and S.Ragefire:IsAvailable() and Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar 12"; end
  end
  -- vengeful_retreat,if=talent.initiative&talent.tactical_retreat&time>20&(cooldown.eye_beam.up&(talent.restless_hunter|cooldown.metamorphosis.remains>10))&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down&buff.metamorphosis.down)
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and S.TacticalRetreat:IsAvailable() and CombatTime > 20 and (BeamAbility:CooldownUp() and (S.RestlessHunter:IsAvailable() or S.Metamorphosis:CooldownRemains() > 10)) and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger() and Player:BuffDown(S.MetamorphosisBuff))) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat ar 14"; end
  end
  -- vengeful_retreat,use_off_gcd=1,if=talent.initiative&!talent.tactical_retreat&(cooldown.eye_beam.remains>15&gcd.remains<0.3|gcd.remains<0.2&cooldown.eye_beam.remains<=gcd.remains&cooldown.metamorphosis.remains>10)&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.stat.any.cooldown_remains<gcd.max*3|trinket.1.stat.any.cooldown_remains>30)|variable.trinket2_steroids&(trinket.2.stat.any.cooldown_remains<gcd.max*3|trinket.2.stat.any.cooldown_remains>30))&time>20&(!talent.inertia&buff.unbound_chaos.down|buff.inertia_trigger.down&buff.metamorphosis.down
  -- Note: Can't check trinket.x.stat.any.cooldown_remains
  if S.VengefulRetreat:IsCastable() and (S.Initiative:IsAvailable() and not S.TacticalRetreat:IsAvailable() and (BeamAbility:CooldownRemains() > 15 and Player:GCDRemains() < 1 or Player:GCDRemains() < 1 and BeamAbility:CooldownRemains() <= Player:GCDRemains() and S.Metamorphosis:CooldownRemains() > 10) and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids or VarTrinket2Steroids) and CombatTime > 20 and (not S.Inertia:IsAvailable() and Player:BuffDown(S.UnboundChaosBuff) or not InertiaTrigger() and Player:BuffDown(S.MetamorphosisBuff))) then
    if Cast(S.VengefulRetreat, Settings.Havoc.OffGCDasOffGCD.VengefulRetreat) then return "vengeful_retreat ar 16"; end
  end
  -- run_action_list,name=ar_fel_barrage,if=variable.fel_barrage|!talent.demon_blades&talent.fel_barrage&(buff.fel_barrage.up|cooldown.fel_barrage.up)&buff.metamorphosis.down
  if VarFelBarrage or not S.DemonBlades:IsAvailable() and S.FelBarrage:IsAvailable() and (Player:BuffUp(S.FelBarrage) or S.FelBarrage:CooldownUp()) and Player:BuffDown(S.MetamorphosisBuff) then
    local ShouldReturn = ARFelBarrage(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for ARFelBarrage()"; end
  end
  if S.Felblade:IsCastable() and (
    -- felblade,if=!talent.inertia&active_enemies=1&buff.unbound_chaos.up&buff.initiative.up&debuff.essence_break.down&buff.metamorphosis.down
    (not S.Inertia:IsAvailable() and Enemies8yCount == 1 and Player:BuffUp(S.UnboundChaosBuff) and Player:BuffUp(S.InitiativeBuff) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:BuffDown(S.MetamorphosisBuff)) or
    -- felblade,if=buff.inertia_trigger.up&talent.inertia&cooldown.eye_beam.remains<=0.5&(cooldown.metamorphosis.remains&talent.looks_can_kill|active_enemies>1)
    -- Note: Reversing the first two conditions so we don't check InertiaTrigger() if we don't have Inertia.
    (S.Inertia:IsAvailable() and InertiaTrigger() and BeamAbility:CooldownRemains() <= 0.5 and (S.Metamorphosis:CooldownDown() and S.LooksCanKill:IsAvailable() or Enemies8yCount > 1))
  ) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 18"; end
  end
  -- run_action_list,name=ar_meta,if=buff.metamorphosis.up
  if Player:BuffUp(S.MetamorphosisBuff) then
    local ShouldReturn = ARMeta(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for ARMeta()"; end
  end
  -- felblade,if=buff.inertia_trigger.up&talent.inertia&buff.inertia.down&cooldown.blade_dance.remains<4&(cooldown.eye_beam.remains>5&cooldown.eye_beam.remains>buff.unbound_chaos.remains|cooldown.eye_beam.remains<=gcd.max&cooldown.vengeful_retreat.remains<=gcd.max+1)
  if S.Felblade:IsCastable() and (S.Inertia:IsAvailable() and InertiaTrigger() and Player:BuffDown(S.InertiaBuff) and S.BladeDance:CooldownRemains() < 4 and (BeamAbility:CooldownRemains() > 5 and BeamAbility:CooldownRemains() > Player:BuffRemains(S.UnboundChaosBuff) or BeamAbility:CooldownRemains() <= Player:GCD() and S.VengefulRetreat:CooldownRemains() <= Player:GCD() + 1)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 20"; end
  end
  if ImmoAbility:IsReady() and (
    -- immolation_aura,if=talent.a_fire_inside&talent.burning_wound&full_recharge_time<gcd.max*2&(raid_event.adds.in>full_recharge_time|active_enemies>desired_targets)
    -- Note: This line is handled by the following line.
    --(S.AFireInside:IsAvailable() and S.BurningWound:IsAvailable() and ImmoAbility:FullRechargeTime() < Player:GCD() * 2 and Enemies8yCount > 1) or
    -- immolation_aura,if=active_enemies>desired_targets&(active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>full_recharge_time)
    (Enemies8yCount > 1) or
    -- immolation_aura,if=fight_remains<15&cooldown.blade_dance.remains&talent.ragefire
    (BossFightRemains < 15 and S.BladeDance:CooldownDown() and S.Ragefire:IsAvailable())
  ) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar 22"; end
  end
  -- eye_beam,if=(cooldown.blade_dance.remains<7|raid_event.adds.up)&(!variable.trinket1_steroids&!variable.trinket2_steroids|variable.trinket1_steroids&(trinket.1.stat.any.cooldown_remains<gcd.max*3|trinket.1.stat.any.cooldown_remains>30)|variable.trinket2_steroids&(trinket.2.stat.any.cooldown_remains<gcd.max*3|trinket.2.stat.any.cooldown_remains>30))|fight_remains<10
  if BeamAbility:IsReady() and ((S.BladeDance:CooldownRemains() < 7 or Enemies20yCount > 1) and (not VarTrinket1Steroids and not VarTrinket2Steroids or VarTrinket1Steroids or VarTrinket2Steroids) or BossFightRemains < 10) then
    if Cast(BeamAbility, Settings.Havoc.GCDasOffGCD.EyeBeam, nil, not IsInMeleeRange(20)) then return "beam_gaze ar 24"; end
  end
  -- blade_dance,if=cooldown.eye_beam.remains>=gcd.max*2&buff.rending_strike.down
  if S.BladeDance:IsReady() and (BeamAbility:CooldownRemains() >= Player:GCD() * 2 and Player:BuffDown(S.RendingStrikeBuff)) then
    if Cast(S.BladeDance, nil, nil, not IsInMeleeRange(8)) then return "blade_dance ar 26"; end
  end
  -- chaos_strike,if=buff.rending_strike.up
  if S.ChaosStrike:IsReady() and (Player:BuffUp(S.RendingStrikeBuff)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar 28"; end
  end
  -- sigil_of_flame,if=active_enemies>3|debuff.essence_break.down
  if SigilAbility:IsReady() and (Enemies8yCount > 3 or Target:DebuffDown(S.EssenceBreakDebuff)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar 30"; end
  end
  -- felblade,if=fury.deficit>=40+variable.fury_gen*0.5&!buff.inertia_trigger.up&(!talent.blind_fury|cooldown.eye_beam.remains>5)
  -- felblade,if=fury.deficit>=40+variable.fury_gen*0.5&!buff.inertia_trigger.up
  if S.Felblade:IsCastable() and (Player:FuryDeficit() >= 40 + VarFuryGen * 0.5 and not InertiaTrigger() and (not S.BlindFury:IsAvailable() or BeamAbility:CooldownRemains() > 5)) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 32"; end
  end
  -- glaive_tempest,if=active_enemies>=desired_targets+raid_event.adds.count|raid_event.adds.in>10
  if S.GlaiveTempest:IsReady() then
    if Cast(S.GlaiveTempest, Settings.Havoc.GCDasOffGCD.GlaiveTempest) then return "glaive_tempest ar 34"; end
  end
  -- chaos_strike,if=debuff.essence_break.up
  if S.ChaosStrike:IsReady() and (Target:DebuffUp(S.EssenceBreakDebuff)) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar 36"; end
  end
  -- throw_glaive,if=active_enemies>1&talent.furious_throws&(!talent.screaming_brutality|charges=2|full_recharge_time<cooldown.blade_dance.remains)
  if S.ThrowGlaive:IsReady() and (Enemies8yCount > 1 and S.FuriousThrows:IsAvailable() and (not S.ScreamingBrutality:IsAvailable() or S.ThrowGlaive:Charges() == 2 or S.ThrowGlaive:FullRechargeTime() < S.BladeDance:CooldownRemains())) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not Target:IsSpellInRange(S.ThrowGlaive)) then return "throw_glaive ar 38"; end
  end
  -- chaos_strike,if=cooldown.eye_beam.remains>gcd.max*2|fury>=80-20*talent.blind_fury.rank
  if S.ChaosStrike:IsReady() and (BeamAbility:CooldownRemains() > Player:GCD() * 2 or Player:Fury() >= 80 - 20 * S.BlindFury:TalentRank()) then
    if Cast(S.ChaosStrike, nil, nil, not IsInMeleeRange(5)) then return "chaos_strike ar 40"; end
  end
  -- felblade,if=!talent.a_fire_inside&fury<40
  if S.Felblade:IsCastable() and (not S.AFireInside:IsAvailable() and Player:Fury() < 40) then
    if Cast(S.Felblade, nil, nil, not Target:IsSpellInRange(S.Felblade)) then return "felblade ar 42"; end
  end
  -- immolation_aura,if=raid_event.adds.in>full_recharge_time|active_enemies>desired_targets&active_enemies>2
  if ImmoAbility:IsReady() and (Enemies8yCount > 2) then
    if Cast(ImmoAbility, Settings.Havoc.GCDasOffGCD.ImmolationAura, nil, not IsInMeleeRange(8)) then return "immolation_aura ar 44"; end
  end
  -- sigil_of_flame,if=buff.out_of_range.down&debuff.essence_break.down&(!talent.fel_barrage|cooldown.fel_barrage.remains>25|active_enemies=1&!raid_event.adds.exists)
  if SigilAbility:IsCastable() and (Target:IsInRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and (not S.FelBarrage:IsAvailable() or S.FelBarrage:CooldownRemains() > 25 or Enemies8yCount == 1)) then
    if Cast(SigilAbility, nil, Settings.CommonsDS.DisplayStyle.Sigils, not Target:IsInRange(30)) then return "sigil_ability ar 46"; end
  end
  -- demons_bite
  if S.DemonsBite:IsCastable() then
    if Cast(S.DemonsBite, nil, nil, not IsInMeleeRange(5)) then return "demons_bite ar 48"; end
  end
  -- throw_glaive,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&buff.out_of_range.down&active_enemies>1
  if S.ThrowGlaive:IsReady() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Target:IsInRange(8) and Enemies8yCount > 1) then
    if Cast(S.ThrowGlaive, Settings.Havoc.GCDasOffGCD.ThrowGlaive, nil, not IsInMeleeRange(5)) then return "throw_glaive ar 50"; end
  end
  -- fel_rush,if=buff.unbound_chaos.down&recharge_time<cooldown.eye_beam.remains&debuff.essence_break.down&(cooldown.eye_beam.remains>8|charges_fractional>1.01)&active_enemies>1
  if S.FelRush:IsCastable() and UseFelRush() and (Player:BuffDown(S.UnboundChaosBuff) and ImmoAbility:Recharge() < BeamAbility:CooldownRemains() and Target:DebuffDown(S.EssenceBreakDebuff) and (BeamAbility:CooldownRemains() > 8 or ImmoAbility:ChargesFractional() > 1.01) and Enemies8yCount > 1) then
    if Cast(S.FelRush, nil, Settings.CommonsDS.DisplayStyle.FelRush) then return "fel_rush ar 52"; end
  end
  -- arcane_torrent,if=buff.out_of_range.down&debuff.essence_break.down&fury<100
  if CDsON() and S.ArcaneTorrent:IsCastable() and (Target:IsInRange(8) and Target:DebuffDown(S.EssenceBreakDebuff) and Player:Fury() < 100) then
    if Cast(S.ArcaneTorrent, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsInRange(8)) then return "arcane_torrent ar 54"; end
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

    -- Ability Switchers
    BeamAbility = S.AbyssalGaze:IsReady() and S.AbyssalGaze or S.EyeBeam
    ImmoAbility = S.ConsumingFire:IsLearned() and S.ConsumingFire or S.ImmolationAura
    SigilAbility = S.SigilofDoom:IsCastable() and S.SigilofDoom or S.SigilofFlame
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
    -- disrupt (and stun interrupts)
    local ShouldReturn = Everyone.Interrupt(S.Disrupt, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- retarget_auto_attack,line_cd=1,target_if=min:debuff.burning_wound.remains,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound<(spell_targets>?3)
    -- retarget_auto_attack,line_cd=1,target_if=min:!target.is_boss,if=talent.burning_wound&talent.demon_blades&active_dot.burning_wound=(spell_targets>?3)
    if S.BurningWound:IsAvailable() and S.DemonBlades:IsAvailable() and S.BurningWoundDebuff:AuraActiveCount() < mathmin(EnemiesMeleeCount, 3) then
      if RetargetAutoAttack(S.DemonBlades, EnemiesMelee, ETIFBurningWound, not IsInMeleeRange(5)) then return "retarget_auto_attack main 2"; end
    end
    -- variable,name=fury_gen,op=set,value=talent.demon_blades*(1%(2.6*attack_haste)*((talent.demonsurge&buff.metamorphosis.up)*3+12))+buff.immolation_aura.stack*6+buff.tactical_retreat.up*10
    VarFuryGen = num(S.DemonBlades:IsAvailable()) * (1 / (2.6 * Player:HastePct()) * (num(S.Demonsurge:IsAvailable() and Player:BuffUp(S.MetamorphosisBuff)) * 3 + 12)) + Player:BuffStack(S.ImmolationAuraBuff) * 6 + num(Player:BuffUp(S.TacticalRetreatBuff)) * 10
    -- variable,name=trinket_pacemaker_proc,value=trinket.1.is.improvised_seaforium_pacemaker&trinket.1.stat.crit.up|trinket.2.is.improvised_seaforium_pacemaker&trinket.2.stat.crit.up|!equipped.improvised_seaforium_pacemaker
    VarTrinketPacemakerProc = I.ImprovisedSeaforiumPacemaker:IsEquipped() and Player:BuffUp(S.ExplosiveAdrenalineBuff) or not I.ImprovisedSeaforiumPacemaker:IsEquipped()
    -- variable,name=tier33_4piece,value=(buff.initiative.up|!talent.initiative|buff.necessary_sacrifice.stack>=5&buff.necessary_sacrifice.remains<0.5+cooldown.vengeful_retreat.remains)&(buff.necessary_sacrifice.up|!set_bonus.thewarwithin_season_2_4pc|cooldown.eye_beam.remains+2>buff.initiative.remains)
    VarT334P = (Player:BuffUp(S.InitiativeBuff) or not S.Initiative:IsAvailable() or Player:BuffStack(S.NecessarySacrificeBuff) >= 5 and Player:BuffRemains(S.NecessarySacrificeBuff) < 0.5 + S.VengefulRetreat:CooldownRemains()) and (Player:BuffUp(S.NecessarySacrificeBuff) or not Player:HasTier("TWW2", 4) or BeamAbility:CooldownRemains() + 2 > Player:BuffRemains(S.InitiativeBuff))
    -- variable,name=tier33_4piece_magnet,value=(buff.initiative.up|!talent.initiative)&(buff.necessary_sacrifice.up|!set_bonus.thewarwithin_season_2_4pc)&variable.trinket_pacemaker_proc&(trinket.1.is.junkmaestros_mega_magnet&(!trinket.2.has_cooldown|trinket.2.cooldown.remains>20))|(trinket.2.is.junkmaestros_mega_magnet&(!trinket.1.has_cooldown|trinket.1.cooldown.remains>20))
    VarT334PMagnet = (Player:BuffUp(S.InitiativeBuff) or not S.Initiative:IsAvailable()) and (Player:BuffUp(S.NecessarySacrificeBuff) or not Player:HasTier("TWW2", 4)) and VarTrinketPacemakerProc and (VarTrinket1ID == I.JunkmaestrosMegaMagnet:ID() and (VarTrinket2CD == 0 or Trinket2:CooldownRemains() > 20)) or (VarTrinket2ID == I.JunkmaestrosMegaMagnet:ID() and (VarTrinket1CD == 0 or Trinket1:CooldownRemains() > 20))
    -- variable,name=double_on_use,value=!equipped.signet_of_the_priory&!equipped.house_of_cards|(trinket.1.is.house_of_cards|trinket.1.is.signet_of_the_priory)&trinket.1.cooldown.remains>20|(trinket.2.is.house_of_cards|trinket.2.is.signet_of_the_priory)&trinket.2.cooldown.remains>20
    VarDoubleOnUse = not I.SignetofthePriory:IsEquipped() and not I.HouseofCards:IsEquipped() or (VarTrinket1ID == I.HouseofCards:ID() or VarTrinket1ID == I.SignetofthePriory:ID()) and Trinket1:CooldownRemains() > 20 or (VarTrinket2ID == I.HouseofCards:ID() or VarTrinket2ID == I.SignetofthePriory:ID()) and Trinket2:CooldownRemains() > 20
    -- run_action_list,name=ar,if=hero_tree.aldrachi_reaver
    -- Note: Also running AR() if player is below level 71.
    if VarHeroTree == 35 or Player:Level() < 71 then
      local ShouldReturn = AR(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for AR()"; end
    end
    -- run_action_list,name=fs,if=hero_tree.felscarred
    if VarHeroTree == 34 then
      local ShouldReturn = FS(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for FS()"; end
    end
    -- Show pooling if nothing else to do
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait/Pool Resources"; end
  end
end

local function Init()
  S.BurningWoundDebuff:RegisterAuraTracking()

  HR.Print("Havoc Demon Hunter rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(577, APL, Init)
