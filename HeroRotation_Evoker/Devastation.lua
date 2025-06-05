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
local CastCycle     = HR.CastCycle
local CastPooling   = HR.CastPooling
local CastAnnotated = HR.CastAnnotated
local CastSuggested = HR.CastSuggested
local Evoker        = HR.Commons.Evoker
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- lua
local mathmax       = math.max
local mathmin       = math.min
-- WoW API
local Delay       = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Devastation
local I = Item.Evoker.Devastation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.SpymastersWeb:ID(),
  -- Older Items
  I.NeuralSynapseEnhancer:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  CommonsDS = HR.GUISettings.APL.Evoker.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Evoker.CommonsOGCD,
  Devastation = HR.GUISettings.APL.Evoker.Devastation
}

--- ===== Rotation Variables =====
local DeepBreathAbility = S.DeepBreathManeuverability:IsLearned() and S.DeepBreathManeuverability or S.DeepBreath
local MaxBurnoutStack = 2
local PlayerHaste = Player:SpellHaste()
local VarR1CastTime = PlayerHaste
local VarDRPrepTime = 6
local VarDRPrepTimeAoe = 4
local VarCanUseEmpower = true
local VarHasExternalPI = false
local VarCanExtendDR = false
local VarNextDragonrage
local VarDragonrageUp, VarDragonrageRemains
local VarPoolForID, VarPoolForCB
local Enemies25y, Enemies8ySplash, EnemiesCount8ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Level, VarTrinket2Level
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Buffs, VarTrinket2Buffs
local VarWeaponBuffs, VarWeaponSync, VarWeaponStatValue
local VarTrinket1Sync, VarTrinket2Sync
local VarTrinket1Manual, VarTrinket2Manual
local VarTrinket1OGCD, VarTrinket2OGCD = false, false
local VarTrinket1Exclude, VarTrinket2Exclude
local VarTrinketPriority, VarDamageTrinketPriority
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.Level == 0 or T2.Level == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
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

  VarTrinket1Level = T1.Level
  VarTrinket2Level = T2.Level

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

  -- Note: Hopefully nobody is using Mirror of Fractured Tomorrows in 11.1...
  VarTrinket1Buffs = Trinket1:HasUseBuff() or VarTrinket1ID == I.SignetofthePriory:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() or VarTrinket2ID == I.SignetofthePriory:ID()

  VarWeaponBuffs = I.BestinSlotsCaster:IsEquipped()
  VarWeaponSync = I.BestinSlotsCaster:IsEquipped() and 1 or 0.5
  VarWeaponStatValue = num(I.BestinSlotsCaster:IsEquipped()) * 5142 * 15

  VarTrinket1Sync = 0.5
  -- Note: If VarTrinket1CD is 0, set it to 1 instead to avoid division by zero errors.
  local T1CD = VarTrinket1CD > 0 and VarTrinket1CD or 1
  if VarTrinket1Buffs and (T1CD % 120 == 0 or 120 % T1CD == 0 or VarTrinket1ID == I.HouseofCards:ID()) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  -- Note: If VarTrinket2CD is 0, set it to 1 instead to avoid division by zero errors.
  local T2CD = VarTrinket2CD > 0 and VarTrinket2CD or 1
  if VarTrinket2Buffs and (T2CD % 120 == 0 or 120 % T2CD == 0 or VarTrinket2ID == I.HouseofCards:ID()) then
    VarTrinket2Sync = 1
  end

  -- Note: Hopefully nobody is using Belor'relos or Nymue's in 11.1...
  VarTrinket1Manual = VarTrinket1ID == I.SpymastersWeb:ID()
  VarTrinket2Manual = VarTrinket2ID == I.SpymastersWeb:ID()

  -- Note: Hopefully nobody is using Ruby Whelp Shell or Whispering Incarnate Icon in 11.1...
  VarTrinket1Exclude = false
  VarTrinket2Exclude = false

  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.proc.any_dps.duration)*(variable.trinket_2_sync)*trinket.2.proc.any_dps.default_value)>((trinket.1.proc.any_dps.duration)*(variable.trinket_1_sync)*trinket.1.proc.any_dps.default_value)
  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and (VarTrinket2Sync > VarTrinket1Sync) then
    VarTrinketPriority = 2
  end
  -- variable,name=trinket_priority,op=setif,if=variable.weapon_buffs,value=3,value_else=variable.trinket_priority,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs|variable.weapon_stat_value*variable.weapon_sync>(((trinket.2.proc.any_dps.duration)*(variable.trinket_2_sync)*trinket.2.proc.any_dps.default_value)<?((trinket.1.proc.any_dps.duration)*(variable.trinket_1_sync)*trinket.1.proc.any_dps.default_value))
  if VarWeaponBuffs then
    if not VarTrinket1Buffs and not VarTrinket2Buffs or VarWeaponStatValue * VarWeaponSync > mathmax(VarTrinket2Sync, VarTrinket1Sync) then
      VarTrinketPriority = 3
    end
  end

  -- variable,name=trinket_priority,op=set,value=trinket.1.is.signet_of_the_priory+2*trinket.2.is.signet_of_the_priory,if=equipped.signet_of_the_priory&variable.trinket_priority=3
  if I.SignetofthePriory:IsEquipped() and VarTrinketPriority == 3 then
    VarTrinketPriority = num(VarTrinket1ID == I.SignetofthePriory:ID()) + 2 * num(VarTrinket2ID == I.SignetofthePriory:ID())
  end

  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  VarDamageTrinketPriority = 1
  if not VarTrinket1Buffs and not VarTrinket2Buffs and VarTrinket2Level >= VarTrinket1Level then
    VarDamageTrinketPriority = 2
  end
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Engulf:RegisterInFlightEffect(443329)
  S.Engulf:RegisterInFlight()
  S.LivingFlame:RegisterInFlight()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.Engulf:RegisterInFlightEffect(443329)
S.Engulf:RegisterInFlight()
S.LivingFlame:RegisterInFlight()

-- Reset variables after fights
HL:RegisterForEvent(function()
  VarHasExternalPI = false
  BossFightRemains = 11111
  FightRemains = 11111
  for k in pairs(Evoker.FirestormTracker) do
    Evoker.FirestormTracker[k] = nil
  end
end, "PLAYER_REGEN_ENABLED")

--- ===== Helper Functions =====
-- Check if target is in Firestorm
local function InFirestorm()
  if S.Firestorm:TimeSinceLastCast() > 12 then return false end
  if Evoker.FirestormTracker[Target:GUID()] then
    if Evoker.FirestormTracker[Target:GUID()] > GetTime() - 2.5 then
      return true
    end
  end
  return false
end

local function LessThanMaxEssenceBurst()
  return (Player:EssenceBurst() < Player:MaxEssenceBurst())
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBombardments(TargetUnit)
  -- target_if=min:debuff.bombardments.remains
  return TargetUnit:DebuffRemains(S.BombardmentsDebuff)
end

local function EvaluateTargetIfFilterEngulfAoe(TargetUnit)
  -- target_if=max:(((dot.fire_breath_damage.remains-dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target-action.engulf_damage.travel_time)>0)*3+dot.living_flame_damage.ticking+dot.enkindle.ticking)
  -- Note: dbc.effect.1140380.base_value is 2, per command: simc spell_query=effect.id=1140380
  return (num((TargetUnit:DebuffRemains(S.FireBreathDebuff) - 2 * num(S.Engulf:InFlight()) - S.Engulf:TravelTime()) > 0) * 3 + num(TargetUnit:DebuffUp(S.LivingFlameDebuff)) + num(TargetUnit:DebuffUp(S.EnkindleDebuff)))
end

local function EvaluateTargetIfFilterEngulfST(TargetUnit)
  -- target_if=max:(dot.fire_breath_damage.remains-dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target)
  return TargetUnit:DebuffRemains(S.FireBreathDebuff) - 2 * num(S.Engulf:InFlight())
end

local function EvaluateTargetIfFilterHPPct(TargetUnit)
  -- target_if=max:target.health.pct
  return (TargetUnit:HealthPercentage())
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfDisintegrate(TargetUnit)
  -- if=buff.mass_disintegrate_stacks.up&talent.mass_disintegrate&(buff.charged_blast.stack<10|!talent.charged_blast)
  return TargetUnit:BuffUp(S.MassDisintegrateBuff)
end

local function EvaluateTargetIfEngulfAoe(TargetUnit)
  -- if=(dot.fire_breath_damage.remains>=action.engulf_damage.travel_time+dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target)&(variable.next_dragonrage>=cooldown*1.2|!talent.dragonrage)
  return (TargetUnit:DebuffRemains(S.FireBreathDebuff) >= S.Engulf:TravelTime() + 2 * num(S.Engulf:InFlight()))
end

local function EvaluateTargetIfEngulfST(TargetUnit)
  -- if=(dot.fire_breath_damage.remains>=action.engulf_damage.travel_time+dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target)&(!talent.enkindle|dot.enkindle.ticking)&(!talent.ruby_embers|dot.living_flame_damage.ticking)&(!talent.shattering_star&!talent.iridescence|debuff.shattering_star_debuff.up&(!talent.iridescence|full_recharge_time<=cooldown.fire_breath.remains+4|buff.dragonrage.up)|buff.iridescence_red.up&(debuff.shattering_star_debuff.up|!talent.shattering_star|full_recharge_time<=cooldown.shattering_star.remains)|talent.scorching_embers&dot.fire_breath_damage.duration<=10&dot.fire_breath_damage.remains<=5)&(variable.next_dragonrage>=cooldown*1.2|!talent.dragonrage|full_recharge_time<=variable.next_dragonrage)&(cooldown.tip_the_scales.remains>=4|cooldown.fire_breath.remains>=8|!talent.scorching_embers|!talent.tip_the_scales)&(!talent.iridescence|buff.iridescence_red.up&(debuff.shattering_star_debuff.remains>=travel_time|cooldown.shattering_star.remains+gcd.max>buff.iridescence_red.remains|essence<3&buff.iridescence_red.stack=1|full_recharge_time<cooldown.fire_breath.remains_expected&(debuff.shattering_star_debuff.remains>=travel_time)|!talent.shattering_star))|fight_remains<=10
  return (TargetUnit:DebuffRemains(S.FireBreathDebuff) >= S.Engulf:TravelTime() + 2 * num(S.Engulf:InFlight())) and (not S.Enkindle:IsAvailable() or TargetUnit:DebuffUp(S.EnkindleDebuff)) and (not S.RubyEmbers:IsAvailable() or Target:DebuffUp(S.LivingFlameDebuff)) and (not S.ShatteringStar:IsAvailable() and not S.Iridescence:IsAvailable() or TargetUnit:DebuffUp(S.ShatteringStarDebuff) and (not S.Iridescence:IsAvailable() or S.Engulf:FullRechargeTime() <= S.FireBreath:CooldownRemains() + 4 or VarDragonrageUp) or Player:BuffUp(S.IridescenceRedBuff) and (TargetUnit:DebuffUp(S.ShatteringStarDebuff) or not S.ShatteringStar:IsAvailable() or S.Engulf:FullRechargeTime() <= S.ShatteringStar:CooldownRemains()) or S.ScorchingEmbers:IsAvailable() and Evoker.LastFBFullDuration <= 10 and TargetUnit:DebuffRemains(S.FireBreathDebuff) <= 5) and (VarNextDragonrage >= S.Engulf:Cooldown() * 1.2 or not S.Dragonrage:IsAvailable() or S.Engulf:FullRechargeTime() <= VarNextDragonrage) and (S.TipTheScales:CooldownRemains() >= 4 or S.FireBreath:CooldownRemains() >= 8 or not S.ScorchingEmbers:IsAvailable() or not S.TipTheScales:IsAvailable()) and (not S.Iridescence:IsAvailable() or Player:BuffUp(S.IridescenceRedBuff) and (TargetUnit:DebuffRemains(S.ShatteringStarDebuff) >= S.Engulf:TravelTime() or S.ShatteringStar:CooldownRemains() + Player:GCD() > Player:BuffRemains(S.IridescenceRedBuff) or Player:Essence() < 3 and Player:BuffStack(S.IridescenceRedBuff) == 1 or S.Engulf:FullRechargeTime() < S.FireBreath:CooldownRemains() and (TargetUnit:DebuffRemains(S.ShatteringStarDebuff) >= S.Engulf:TravelTime()) or not S.ShatteringStar:IsAvailable())) or BossFightRemains <= 10
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.BlessingoftheBronze:IsCastable() and Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff) then
    if Cast(S.BlessingoftheBronze, Settings.CommonsOGCD.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat 2"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.signet_of_the_priory
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.signet_of_the_priory
  -- variable,name=weapon_buffs,value=equipped.bestinslots
  -- variable,name=weapon_sync,op=setif,value=1,value_else=0.5,condition=equipped.bestinslots
  -- variable,name=weapon_stat_value,value=equipped.bestinslots*5142*15
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.1.cooldown.duration=0|trinket.1.is.house_of_cards)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.2.cooldown.duration=0|trinket.2.is.house_of_cards)
  -- variable,name=trinket_1_manual,value=trinket.1.is.belorrelos_the_suncaller|trinket.1.is.nymues_unraveling_spindle|trinket.1.is.spymasters_web
  -- variable,name=trinket_2_manual,value=trinket.2.is.belorrelos_the_suncaller|trinket.2.is.nymues_unraveling_spindle|trinket.2.is.spymasters_web
  -- variable,name=trinket_1_ogcd_cast,value=0
  -- variable,name=trinket_2_ogcd_cast,value=0
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.proc.any_dps.duration)*(variable.trinket_2_sync)*trinket.2.proc.any_dps.default_value)>((trinket.1.proc.any_dps.duration)*(variable.trinket_1_sync)*trinket.1.proc.any_dps.default_value)
  -- variable,name=trinket_priority,op=setif,if=variable.weapon_buffs,value=3,value_else=variable.trinket_priority,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs|variable.weapon_stat_value*variable.weapon_sync>(((trinket.2.proc.any_dps.duration)*(variable.trinket_2_sync)*trinket.2.proc.any_dps.default_value)<?((trinket.1.proc.any_dps.duration)*(variable.trinket_1_sync)*trinket.1.proc.any_dps.default_value))
  -- variable,name=trinket_priority,op=set,value=trinket.1.is.signet_of_the_priory+2*trinket.2.is.signet_of_the_priory,if=equipped.signet_of_the_priory&variable.trinket_priority=3
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- variable,name=r1_cast_time,value=1.0*spell_haste
  VarR1CastTime = PlayerHaste
  -- variable,name=dr_prep_time,default=6,op=reset
  -- variable,name=dr_prep_time_aoe,default=4,op=reset
  -- variable,name=can_extend_dr,default=0,op=reset
  -- Note: Variables are never changed. Moving to variable declaration instead.
  -- variable,name=has_external_pi,value=cooldown.invoke_power_infusion_0.duration>0
  -- Note: Not handling external PI.
  -- variable,name=can_use_empower,value=1,default=1,if=!talent.animosity|!talent.dragonrage
  -- Note: Another tw variables that are never changed. Moved to variable declarations.
  -- verdant_embrace,if=talent.scarlet_adaptation
  if Settings.Devastation.UseGreen and S.VerdantEmbrace:IsCastable() and (S.ScarletAdaptation:IsAvailable()) then
    if Cast(S.VerdantEmbrace) then return "verdant_embrace precombat 4"; end
  end
  -- hover,if=talent.slipstream
  -- hover,if=talent.slipstream
  -- Note: Not handling hover. Also, duplicate line is from the APL.
  -- firestorm,if=talent.firestorm&(!talent.engulf|!talent.ruby_embers)
  if S.Firestorm:IsCastable() and (not S.Engulf:IsAvailable() or not S.RubyEmbers:IsAvailable()) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm precombat 6"; end
  end
  -- living_flame,if=!talent.firestorm|talent.engulf&talent.ruby_embers
  if S.LivingFlame:IsCastable() and (not S.Firestorm:IsAvailable() or S.Engulf:IsAvailable() and S.RubyEmbers:IsAvailable()) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame precombat 8"; end
  end
end

local function Defensives()
  if S.ObsidianScales:IsCastable() and Player:BuffDown(S.ObsidianScales) and (Player:HealthPercentage() < Settings.Devastation.ObsidianScalesThreshold) then
    if Cast(S.ObsidianScales, nil, Settings.CommonsDS.DisplayStyle.Defensives) then return "obsidian_scales defensives"; end
  end
end

local function ES()
  if S.EternitySurge:CooldownDown() then return nil end
  local ESEmpower = 0
  -- eternity_surge,empower_to=1,target_if=max:target.health.pct,if=active_enemies<=1+talent.eternitys_span|(variable.can_extend_dr&talent.animosity|talent.mass_disintegrate)&active_enemies>(3+talent.font_of_magic+4*talent.eternitys_span)|buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste&talent.animosity&variable.can_extend_dr
  if EnemiesCount8ySplash <= 1 + num(S.EternitysSpan:IsAvailable()) or (VarCanExtendDR and S.Animosity:IsAvailable() or S.MassDisintegrate:IsAvailable()) and EnemiesCount8ySplash > (3 + num(S.FontofMagic:IsAvailable()) + 4 * num(S.EternitysSpan:IsAvailable())) or VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= PlayerHaste and S.Animosity:IsAvailable() and VarCanExtendDR then
    ESEmpower = 1
  -- eternity_surge,empower_to=2,target_if=max:target.health.pct,if=active_enemies<=2+2*talent.eternitys_span|buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste&talent.animosity&variable.can_extend_dr
  elseif EnemiesCount8ySplash <= 2 + 2 * num(S.EternitysSpan:IsAvailable()) or VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste and S.Animosity:IsAvailable() and VarCanExtendDR then
    ESEmpower = 2
  -- eternity_surge,empower_to=3,target_if=max:target.health.pct,if=active_enemies<=3+3*talent.eternitys_span|!talent.font_of_magic&talent.mass_disintegrate|buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste&talent.animosity&variable.can_extend_dr
  elseif EnemiesCount8ySplash <= 3 + 3 * num(S.EternitysSpan:IsAvailable()) or not S.FontofMagic:IsAvailable() and S.MassDisintegrate:IsAvailable() or VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste and S.Animosity:IsAvailable() and VarCanExtendDR then
    ESEmpower = 3
  -- eternity_surge,empower_to=4,target_if=max:target.health.pct,if=talent.mass_disintegrate|active_enemies<=4+4*talent.eternitys_span
  elseif S.MassDisintegrate:IsAvailable() or EnemiesCount8ySplash <= 4 + 4 * num(S.EternitysSpan:IsAvailable()) then
    ESEmpower = 4
  end
  -- We should (usually, if not always) be hitting all targets anyway, so keeping CastAnnotated over CastTargetIf.
  if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) and (VarDragonrageUp and (not (Player:PowerInfusionUp() and Player:BloodlustUp()) or S.FireBreath:CooldownUp() or S.EternitySurge:CooldownUp())) then
    if CastAnnotated(S.EternitySurge, nil, ESEmpower.." CLIP", not Target:IsInRange(25), Settings.Commons.DisintegrateFontSize) then return "eternity_surge empower " .. ESEmpower .. " clip ES 2"; end
  else
    if CastAnnotated(S.EternitySurge, false, ESEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "eternity_surge empower " .. ESEmpower .. " ES 2"; end
  end
end

local function FB()
  if S.FireBreath:CooldownDown() then return nil end
  local FBEmpower = 0
  local FBRemains = Target:DebuffRemains(S.FireBreath)
  -- fire_breath,empower_to=2,target_if=max:target.health.pct,if=talent.scorching_embers&(cooldown.engulf.remains<=duration+0.5|cooldown.engulf.up)&talent.engulf&release.dot_duration<=target.time_to_die
  if S.ScorchingEmbers:IsAvailable() and (S.Engulf:CooldownRemains() <= 14.5 or S.Engulf:CooldownUp()) and S.Engulf:IsAvailable() and 14 <= Target:TimeToDie() then
    FBEmpower = 2
  -- fire_breath,empower_to=3,target_if=max:target.health.pct,if=talent.scorching_embers&(cooldown.engulf.remains<=duration+0.5|cooldown.engulf.up)&talent.engulf&(release.dot_duration<=target.time_to_die|!talent.font_of_magic)
  elseif S.ScorchingEmbers:IsAvailable() and (S.Engulf:CooldownRemains() <= 8.5 or S.Engulf:CooldownUp()) and S.Engulf:IsAvailable() and (8 <= Target:TimeToDie() or not S.FontofMagic:IsAvailable()) then
    FBEmpower = 3
  -- fire_breath,empower_to=4,target_if=max:target.health.pct,if=talent.scorching_embers&(cooldown.engulf.remains<=duration+0.5|cooldown.engulf.up)&talent.engulf&talent.font_of_magic
  elseif S.ScorchingEmbers:IsAvailable() and (S.Engulf:CooldownRemains() <= 4.5 or S.Engulf:CooldownUp()) and S.Engulf:IsAvailable() and S.FontofMagic:IsAvailable() then
    FBEmpower = 4
  -- fire_breath,empower_to=1,target_if=max:target.health.pct,if=((buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste)&talent.animosity&variable.can_extend_dr|active_enemies=1)&release.dot_duration<=target.time_to_die
  elseif ((VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= PlayerHaste) and S.Animosity:IsAvailable() and VarCanExtendDR or EnemiesCount8ySplash == 1) and 20 <= Target:TimeToDie() then
    FBEmpower = 1
  -- fire_breath,empower_to=2,target_if=max:target.health.pct,if=((buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste)&talent.animosity&variable.can_extend_dr|talent.scorching_embers|active_enemies>=2)&release.dot_duration<=target.time_to_die
  elseif ((VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste) and S.Animosity:IsAvailable() and VarCanExtendDR or S.ScorchingEmbers:IsAvailable() or EnemiesCount8ySplash >= 2) and 14 <= Target:TimeToDie() then
    FBEmpower = 2
  -- fire_breath,empower_to=3,target_if=max:target.health.pct,if=!talent.font_of_magic|((buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste)&talent.animosity&variable.can_extend_dr|talent.scorching_embers)&release.dot_duration<=target.time_to_die
  elseif not S.FontofMagic:IsAvailable() or ((VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste) and S.Animosity:IsAvailable() and VarCanExtendDR or S.ScorchingEmbers:IsAvailable()) and 8 <= Target:TimeToDie() then
    FBEmpower = 3
  -- fire_breath,empower_to=4,target_if=max:target.health.pct
  else
    FBEmpower = 4
  end
  -- We should (usually, if not always) be hitting all targets anyway, so keeping CastAnnotated over CastTargetIf.
  if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) and (VarDragonrageUp and (not (Player:PowerInfusionUp() and Player:BloodlustUp()) or S.FireBreath:CooldownUp() or S.EternitySurge:CooldownUp())) then
    if CastAnnotated(S.FireBreath, nil, FBEmpower.." CLIP", not Target:IsInRange(25), Settings.Commons.DisintegrateFontSize) then return "fire_breath empower " .. FBEmpower .. " clip FB 2"; end
  else
    if CastAnnotated(S.FireBreath, false, FBEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower " .. FBEmpower .. " FB 2"; end
  end
end

local function Green()
  -- emerald_blossom
  if S.EmeraldBlossom:IsCastable() then
    if Cast(S.EmeraldBlossom) then return "emerald_blossom green 2"; end
  end
  -- verdant_embrace
  -- Note: Added PrevGCDP check for emerald_blossom so we don't suggest VE while waiting for EB to pop.
  if S.VerdantEmbrace:IsCastable() and not Player:PrevGCDP(1, S.EmeraldBlossom) then
    if Cast(S.VerdantEmbrace) then return "verdant_embrace green 4"; end
  end
end

local function Aoe()
  -- shattering_star,target_if=max:target.health.pct,if=(cooldown.dragonrage.up&talent.arcane_vigor|talent.eternitys_span&active_enemies<=3)&!talent.engulf
  if S.ShatteringStar:IsCastable() and ((S.Dragonrage:CooldownUp() and S.ArcaneVigor:IsAvailable() or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash <= 3) and not S.Engulf:IsAvailable()) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 2"; end
  end
  -- hover,use_off_gcd=1,if=raid_event.movement.in<6&!buff.hover.up&gcd.remains>=0.5&(buff.mass_disintegrate_stacks.up&talent.mass_disintegrate|active_enemies<=4)
  -- Note: Not handling movement ability.
  -- firestorm,if=buff.snapfire.up&!talent.feed_the_flames
  if S.Firestorm:IsCastable() and (Player:BuffUp(S.SnapfireBuff) and not S.FeedtheFlames:IsAvailable()) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 4"; end
  end
  -- deep_breath,if=talent.maneuverability&talent.melt_armor&!cooldown.fire_breath.up&!cooldown.eternity_surge.up|talent.feed_the_flames&talent.engulf&talent.imminent_destruction
  if CDsON() and DeepBreathAbility:IsCastable() and (S.Maneuverability:IsAvailable() and S.MeltArmor:IsAvailable() and S.FireBreath:CooldownDown() and S.EternitySurge:CooldownDown() or S.FeedtheFlames:IsAvailable() and S.Engulf:IsAvailable() and S.ImminentDestruction:IsAvailable()) then
    if Cast(DeepBreathAbility, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath aoe 6"; end
  end
  -- firestorm,if=talent.feed_the_flames&(!talent.engulf|cooldown.engulf.remains>4|cooldown.engulf.charges=0|(variable.next_dragonrage<=cooldown*1.2|!talent.dragonrage))
  if S.Firestorm:IsCastable() and (S.FeedtheFlames:IsAvailable() and (not S.Engulf:IsAvailable() or S.Engulf:CooldownRemains() > 4 or S.Engulf:Charges() == 0 or (VarNextDragonrage <= 20 * 1.2 or not S.Dragonrage:IsAvailable()))) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 8"; end
  end
  -- call_action_list,name=fb,if=talent.dragonrage&cooldown.dragonrage.up&(talent.iridescence|talent.scorching_embers)&!talent.engulf
  if S.Dragonrage:IsAvailable() and S.Dragonrage:CooldownUp() and (S.Iridescence:IsAvailable() or S.ScorchingEmbers:IsAvailable()) and not S.Engulf:IsAvailable() then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- tip_the_scales,if=(!talent.dragonrage|buff.dragonrage.up)&(cooldown.fire_breath.remains<=cooldown.eternity_surge.remains|(cooldown.eternity_surge.remains<=cooldown.fire_breath.remains&talent.font_of_magic)&!talent.engulf)
  if CDsON() and S.TipTheScales:IsCastable() and ((not S.Dragonrage:IsAvailable() or VarDragonrageUp) and (S.FireBreath:CooldownRemains() <= S.EternitySurge:CooldownRemains() or (S.EternitySurge:CooldownRemains() <= S.FireBreath:CooldownRemains() and S.FontofMagic:IsAvailable()) and not S.Engulf:IsAvailable())) then
    if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales) then return "tip_the_scales aoe 10"; end
  end
  -- shattering_star,target_if=max:target.health.pct,if=(cooldown.dragonrage.up&talent.arcane_vigor|talent.eternitys_span&active_enemies<=3)&talent.engulf
  if S.ShatteringStar:IsCastable() and ((S.Dragonrage:CooldownUp() and S.ArcaneVigor:IsAvailable() or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash <= 3) and S.Engulf:IsAvailable()) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 12"; end
  end
  -- dragonrage,target_if=max:target.time_to_die,if=target.time_to_die>=32|active_enemies>=3&target.time_to_die>=15|fight_remains<30
  if CDsON() and S.Dragonrage:IsCastable() and (Target:TimeToDie() >= 32 or EnemiesCount8ySplash >= 3 and Target:TimeToDie() >= 15 or BossFightRemains < 30) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage aoe 14"; end
  end
  -- call_action_list,name=fb,if=(!talent.dragonrage|buff.dragonrage.up|cooldown.dragonrage.remains>variable.dr_prep_time_aoe|!talent.animosity|talent.flame_siphon)&(target.time_to_die>=8|talent.mass_disintegrate)
  if (not S.Dragonrage:IsAvailable() or VarDragonrageUp or S.Dragonrage:CooldownRemains() > VarDRPrepTimeAoe or not S.Animosity:IsAvailable() or S.FlameSiphon:IsAvailable()) and (Target:TimeToDie() >= 8 or S.MassDisintegrate:IsAvailable()) then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=es,if=(!talent.dragonrage|buff.dragonrage.up|cooldown.dragonrage.remains>variable.dr_prep_time_aoe|!talent.animosity)&(!buff.jackpot.up|!set_bonus.tww2_4pc|talent.mass_disintegrate)
  if (not S.Dragonrage:IsAvailable() or VarDragonrageUp or S.Dragonrage:CooldownRemains() > VarDRPrepTimeAoe or not S.Animosity:IsAvailable()) and (Player:BuffDown(S.JackpotBuff) or not Player:HasTier("TWW2", 4) or S.MassDisintegrate:IsAvailable()) then
    local ShouldReturn = ES(); if ShouldReturn then return ShouldReturn; end
  end
  -- deep_breath,if=!buff.dragonrage.up&essence.deficit>3
  if CDsON() and DeepBreathAbility:IsCastable() and (not VarDragonrageUp and Player:EssenceDeficit() > 3) then
    if Cast(DeepBreathAbility, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath aoe 16"; end
  end
  -- shattering_star,target_if=max:target.health.pct,if=(buff.essence_burst.stack<buff.essence_burst.max_stack&talent.arcane_vigor|talent.eternitys_span&active_enemies<=3|set_bonus.tww2_4pc&buff.jackpot.stack<2)&(!talent.engulf|cooldown.engulf.remains<4|cooldown.engulf.charges>0)
  if S.ShatteringStar:IsCastable() and ((LessThanMaxEssenceBurst() and S.ArcaneVigor:IsAvailable() or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash <= 3 or Player:HasTier("TWW2", 4) and Player:BuffStack(S.JackpotBuff) < 2) and (not S.Engulf:IsAvailable() or S.Engulf:CooldownRemains() < 4 or S.Engulf:Charges() > 0)) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 18"; end
  end
  -- engulf,target_if=max:(((dot.fire_breath_damage.remains-dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target-action.engulf_damage.travel_time)>0)*3+dot.living_flame_damage.ticking+dot.enkindle.ticking),if=(dot.fire_breath_damage.remains>=action.engulf_damage.travel_time+dbc.effect.1140380.base_value*action.engulf_damage.in_flight_to_target)&(variable.next_dragonrage>=cooldown*1.2|!talent.dragonrage)
  if S.Engulf:IsReady() and (VarNextDragonrage >= S.Engulf:Cooldown() * 1.2 or not S.Dragonrage:IsAvailable()) then
    if Everyone.CastTargetIf(S.Engulf, Enemies8ySplash, "max", EvaluateTargetIfFilterEngulfAoe, EvaluateTargetIfEngulfAoe, not Target:IsInRange(25)) then return "engulf aoe 20"; end
  end
  -- pyre,target_if=max:target.health.pct,if=buff.charged_blast.stack>=12&(cooldown.dragonrage.remains>gcd.max*4|!talent.dragonrage)
  if S.Pyre:IsReady() and (Player:BuffStack(S.ChargedBlastBuff) >= 12 and (S.Dragonrage:CooldownRemains() > Player:GCD() * 4 or not S.Dragonrage:IsAvailable())) then
    if Everyone.CastTargetIf(S.Pyre, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Pyre) then return "pyre aoe 22"; end
  end
  -- disintegrate,target_if=min:debuff.bombardments.remains,if=buff.mass_disintegrate_stacks.up&talent.mass_disintegrate&(!variable.pool_for_id|buff.mass_disintegrate_stacks.remains<=buff.mass_disintegrate_stacks.stack*(duration+0.1))
  if S.Disintegrate:IsReady() and (S.MassDisintegrate:IsAvailable() and Player:BuffUp(S.MassDisintegrateBuff) and (not VarPoolForID or Player:BuffRemains(S.MassDisintegrateBuff) <= Player:BuffStack(S.MassDisintegrateBuff) * (S.Disintegrate:BaseDuration() + 0.1))) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, EvaluateTargetIfDisintegrate, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate aoe 24"; end
  end
  -- deep_breath,if=talent.imminent_destruction&!buff.essence_burst.up
  if CDsON() and DeepBreathAbility:IsCastable() and (S.ImminentDestruction:IsAvailable() and Player:BuffDown(S.EssenceBurstBuff)) then
    if Cast(DeepBreathAbility, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath aoe 26"; end
  end
  -- pyre,target_if=max:target.health.pct,if=(active_enemies>=4-(buff.imminent_destruction.up)|talent.volatility|talent.scorching_embers&active_dot.fire_breath_damage>=active_enemies*0.75)&(cooldown.dragonrage.remains>gcd.max*4|!talent.dragonrage|!talent.charged_blast)&!variable.pool_for_id&(!buff.mass_disintegrate_stacks.up|buff.essence_burst.stack=2|buff.essence_burst.stack=1&essence>=(3-buff.imminent_destruction.up)|essence>=(5-buff.imminent_destruction.up*2))
  if S.Pyre:IsReady() and ((EnemiesCount8ySplash >= 4 - num(Player:BuffUp(S.ImminentDestructionBuff)) or S.Volatility:IsAvailable() or S.ScorchingEmbers:IsAvailable() and S.FireBreathDebuff:AuraActiveCount() >= EnemiesCount8ySplash * 0.75) and (S.Dragonrage:CooldownRemains() > Player:GCD() * 4 or not S.Dragonrage:IsAvailable() or not S.ChargedBlast:IsAvailable()) and not VarPoolForID and (Player:BuffDown(S.MassDisintegrateBuff) or Player:EssenceBurst() == 2 or Player:EssenceBurst() == 1 and Player:Essence() >= (3 - num(Player:BuffUp(S.ImminentDestructionBuff))) or Player:Essence() >= (5 - num(Player:BuffUp(S.ImminentDestructionBuff)) * 2))) then
    if Everyone.CastTargetIf(S.Pyre, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Pyre) then return "pyre aoe 28"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=(!talent.burnout|buff.burnout.up|cooldown.fire_breath.remains<=gcd.max*5|buff.scarlet_adaptation.up|buff.ancient_flame.up)&buff.leaping_flames.up&(!buff.essence_burst.up&essence.deficit>1|cooldown.fire_breath.remains<=gcd.max*3&buff.essence_burst.stack<buff.essence_burst.max_stack)
  if S.LivingFlame:IsReady() and ((not S.Burnout:IsAvailable() or Player:BuffUp(S.BurnoutBuff) or S.FireBreath:CooldownRemains() <= Player:GCD() * 5 or Player:BuffUp(S.ScarletAdaptationBuff) or Player:BuffUp(S.AncientFlameBuff)) and Player:BuffUp(S.LeapingFlamesBuff) and (Player:BuffDown(S.EssenceBurstBuff) and Player:EssenceDeficit() > 1 or S.FireBreath:CooldownRemains() <= Player:GCD() * 3 and Player:EssenceBurst() < Player:MaxEssenceBurst())) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.LivingFlame) then return "living_flame aoe 30"; end
  end
  -- disintegrate,target_if=max:target.health.pct,chain=1,early_chain_if=evoker.use_early_chaining&ticks>=2&(raid_event.movement.in>2|buff.hover.up),interrupt_if=evoker.use_clipping&buff.dragonrage.up&ticks>=2&(raid_event.movement.in>2|buff.hover.up),if=(raid_event.movement.in>2|buff.hover.up)&!variable.pool_for_id&(active_enemies<=4|buff.mass_disintegrate_stacks.up)
  if S.Disintegrate:IsReady() and (not VarPoolForID and (EnemiesCount8ySplash <= 4 or Player:BuffUp(S.MassDisintegrateBuff))) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate aoe 32"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=talent.snapfire&buff.burnout.up
  if S.LivingFlame:IsReady() and (S.Snapfire:IsAvailable() and Player:BuffUp(S.BurnoutBuff)) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.LivingFlame) then return "living_flame aoe 34"; end
  end
  -- firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 36"; end
  end
  -- living_flame,if=talent.snapfire&!talent.engulfing_blaze
  if S.LivingFlame:IsReady() and (S.Snapfire:IsAvailable() and not S.EngulfingBlaze:IsAvailable()) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame aoe 38"; end
  end
  -- azure_strike,target_if=max:target.health.pct
  -- Note: Since this is a filler, going to use both Cast and CastTargetIf.
  if S.AzureStrike:IsCastable() then
    if Everyone.CastTargetIf(S.AzureStrike, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike cti aoe 40"; end
  end
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike aoe 42"; end
  end
end

local function ST()
  -- dragonrage
  if CDsON() and S.Dragonrage:IsCastable() then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage st 2"; end
  end
  -- hover,use_off_gcd=1,if=raid_event.movement.in<6&!buff.hover.up&gcd.remains>=0.5|talent.slipstream&gcd.remains>=0.5
  -- Note: Not handling movement ability.
  -- tip_the_scales,use_off_gcd=1,if=buff.dragonrage.up&cooldown.fire_breath.remains<=cooldown.eternity_surge.remains
  if CDsON() and S.TipTheScales:IsCastable() and (VarDragonrageUp and S.FireBreath:CooldownRemains() <= S.EternitySurge:CooldownRemains()) then
    if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales) then return "tip_the_scales st 4"; end
  end
  -- shattering_star,if=(buff.essence_burst.stack<buff.essence_burst.max_stack|!talent.arcane_vigor)
  if S.ShatteringStar:IsCastable() and (LessThanMaxEssenceBurst() or not S.ArcaneVigor:IsAvailable()) then
    if Cast(S.ShatteringStar, nil, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star st 6"; end
  end
  -- Note: All fire_breath lines require VarCanUseEmpower to be true.
  if VarCanUseEmpower then
    -- Note: fire_breath will hit most/all targets, so ignoring target_if.
    -- fire_breath,target_if=max:target.health.pct,empower_to=4,if=(talent.scorching_embers&talent.engulf&action.engulf.usable_in<=duration+0.5)&variable.can_use_empower&cooldown.engulf.full_recharge_time<=cooldown.fire_breath.duration_expected+4
    local MaxEmpower = S.FontofMagic:IsAvailable() and 4 or 3
    if S.FireBreath:IsCastable() and ((S.ScorchingEmbers:IsAvailable() and S.Engulf:IsAvailable() and S.Engulf:CooldownRemains() <= Player:EmpowerCastTime(MaxEmpower) + 0.5) and S.Engulf:FullRechargeTime() <= 34) then
      if CastAnnotated(S.FireBreath, false, MaxEmpower, not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower " .. MaxEmpower .. " st 8"; end
    end
    -- fire_breath,target_if=max:target.health.pct,empower_to=1,if=talent.engulf&talent.fulminous_roar&variable.can_use_empower
    if S.FireBreath:IsCastable() and (S.Engulf:IsAvailable() and S.FulminousRoar:IsAvailable()) then
      if CastAnnotated(S.FireBreath, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower 1 st 10"; end
    end
    -- fire_breath,target_if=max:target.health.pct,empower_to=2,if=variable.can_use_empower&!buff.dragonrage.up
    if S.FireBreath:IsCastable() and (not VarDragonrageUp) then
      if CastAnnotated(S.FireBreath, false, "2", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower 2 st 12"; end
    end
    -- fire_breath,target_if=max:target.health.pct,empower_to=1,if=variable.can_use_empower
    if S.FireBreath:IsCastable() then
      if CastAnnotated(S.FireBreath, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "fire_breath empower 1 st 14"; end
    end
  end
  -- engulf,if=(dot.fire_breath_damage.remains>travel_time)&(dot.living_flame_damage.remains>travel_time|!talent.ruby_embers)&(dot.enkindle.remains>travel_time|!talent.enkindle)&(!talent.iridescence|buff.iridescence_red.up)&(!talent.scorching_embers|dot.fire_breath_damage.duration<=6|fight_remains<=30)&(debuff.shattering_star_debuff.remains>travel_time|full_recharge_time<action.shattering_star.usable_in|talent.scorching_embers)
  if S.Engulf:IsReady() and ((Target:DebuffRemains(S.FireBreathDebuff) > S.Engulf:TravelTime()) and (Target:DebuffRemains(S.LivingFlameDebuff) > S.Engulf:TravelTime() or not S.RubyEmbers:IsAvailable()) and (Target:DebuffRemains(S.EnkindleDebuff) > S.Engulf:TravelTime() or not S.Enkindle:IsAvailable()) and (not S.Iridescence:IsAvailable() or Player:BuffUp(S.IridescenceRedBuff)) and (not S.ScorchingEmbers:IsAvailable() or Target:DebuffRemains(S.FireBreathDebuff) <= 6 or BossFightRemains <= 30) and (Target:DebuffRemains(S.ShatteringStarDebuff) > S.Engulf:TravelTime() or S.Engulf:FullRechargeTime() < S.ShatteringStar:CooldownRemains() or S.ScorchingEmbers:IsAvailable())) then
    if Cast(S.Engulf, nil, nil, not Target:IsInRange(25)) then return "engulf st 16"; end
  end
  -- Note: All eternity_surge lines require VarCanUseEmpower to be true.
  if VarCanUseEmpower then
    -- Note: eternity_surge will hit multiple targets. Ignoring target_if, for now.
    -- eternity_surge,target_if=max:target.health.pct,empower_to=2,if=(!talent.power_swell|buff.power_swell.remains<=duration|!talent.mass_disintegrate)&active_enemies=2&!talent.eternitys_span&variable.can_use_empower
    if S.EternitySurge:IsCastable() and ((not S.PowerSwell:IsAvailable() or Player:BuffRemains(S.PowerSwellBuff) <= Player:EmpowerCastTime(2) or not S.MassDisintegrate:IsAvailable()) and EnemiesCount8ySplash == 2 and not S.EternitysSpan:IsAvailable()) then
      if CastAnnotated(S.EternitySurge, false, "2", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "eternity_surge empower 2 st 18"; end
    end
    -- eternity_surge,target_if=max:target.health.pct,empower_to=1,if=(!talent.power_swell|buff.power_swell.remains<=duration|!talent.mass_disintegrate)&variable.can_use_empower
    if S.EternitySurge:IsCastable() and ((not S.PowerSwell:IsAvailable() or Player:BuffRemains(S.PowerSwellBuff) <= Player:EmpowerCastTime(1) or not S.MassDisintegrate:IsAvailable())) then
      if CastAnnotated(S.EternitySurge, false, "1", not Target:IsInRange(25), Settings.Commons.EmpoweredFontSize) then return "eternity_surge empower 1 st 20"; end
    end
  end
  -- living_flame,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max&buff.burnout.up
  if S.LivingFlame:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (Player:MaxEssenceBurst() - Player:EssenceBurst()) * Player:GCD() and Player:BuffUp(S.BurnoutBuff)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame st 22"; end
  end
  -- azure_strike,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max
  if S.AzureStrike:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (Player:MaxEssenceBurst() - Player:EssenceBurst()) * Player:GCD()) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsInRange(25)) then return "azure_strike st 24"; end
  end
  -- firestorm,if=buff.snapfire.up|active_enemies>=2
  if S.Firestorm:IsCastable() and (Player:BuffUp(S.SnapfireBuff) or EnemiesCount8ySplash >= 2) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 26"; end
  end
  -- deep_breath,if=talent.imminent_destruction|talent.melt_armor|talent.maneuverability
  if CDsON() and DeepBreathAbility:IsCastable() and (S.ImminentDestruction:IsAvailable() or S.MeltArmor:IsAvailable() or S.Maneuverability:IsAvailable()) then
    if Cast(DeepBreathAbility, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath st 28"; end
  end
  -- disintegrate,target_if=min:debuff.bombardments.remains,early_chain_if=ticks_remain<=1&buff.mass_disintegrate_stacks.up,if=(raid_event.movement.in>2|buff.hover.up)&buff.mass_disintegrate_stacks.up&talent.mass_disintegrate&!variable.pool_for_id
  if S.Disintegrate:IsReady() and (Player:BuffUp(S.MassDisintegrateBuff) and S.MassDisintegrate:IsAvailable() and not VarPoolForID) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate st 30"; end
  end
  -- pyre,if=talent.snapfire&active_enemies>=2&talent.volatility.rank>=2&(!talent.azure_celerity|talent.feed_the_flames)
  if S.Pyre:IsReady() and (S.Snapfire:IsAvailable() and EnemiesCount8ySplash >= 2 and S.Volatility:TalentRank() >= 2 and (not S.AzureCelerity:IsAvailable() or S.FeedtheFlames:IsAvailable())) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(25)) then return "pyre st 32"; end
  end
  -- disintegrate,target_if=min:debuff.bombardments.remains,chain=1,if=(raid_event.movement.in>2|buff.hover.up)&!variable.pool_for_id
  if S.Disintegrate:IsReady() and (not VarPoolForID) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, nil, not Target:IsInRange(25), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate st 34"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&!buff.ancient_flame.up&!buff.shattering_star_debuff.up&talent.scarlet_adaptation&!buff.dragonrage.up&!buff.burnout.up&talent.engulfing_blaze
  if Settings.Devastation.UseGreen and (S.AncientFlame:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and Target:DebuffDown(S.ShatteringStarDebuff) and S.ScarletAdaptation:IsAvailable() and not VarDragonrageUp and Player:BuffDown(S.BurnoutBuff) and S.EngulfingBlaze:IsAvailable()) then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- living_flame,if=buff.burnout.up|buff.leaping_flames.up|buff.ancient_flame.up
  if S.LivingFlame:IsReady() and (Player:BuffUp(S.BurnoutBuff) or Player:BuffUp(S.LeapingFlamesBuff) or Player:BuffUp(S.AncientFlameBuff)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame st 36"; end
  end
  -- azure_strike,if=active_enemies>=2&!talent.snapfire
  if S.AzureStrike:IsCastable() and (EnemiesCount8ySplash >= 2 and not S.Snapfire:IsAvailable()) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike st 38"; end
  end
  -- living_flame
  if S.LivingFlame:IsReady() then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame st 40"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike st 42"; end
  end
end

local function Trinkets()
  -- use_item,name=spymasters_web,if=(buff.dragonrage.up|!talent.dragonrage&(talent.imminent_destruction&buff.imminent_destruction.up|!talent.imminent_destruction&!talent.melt_armor|talent.melt_armor&debuff.melt_armor.up))&(fight_remains<130|buff.bloodlust.react)&buff.spymasters_report.stack>=15|(fight_remains<=20|cooldown.engulf.up&talent.engulf&fight_remains<=40&cooldown.dragonrage.remains>=40)
  if Settings.Commons.Enabled.Items and I.SpymastersWeb:IsEquippedAndReady() and ((VarDragonrageUp or not S.Dragonrage:IsAvailable() and (S.ImminentDestruction:IsAvailable() and Player:BuffUp(S.ImminentDestructionBuff) or not S.ImminentDestruction:IsAvailable() and not S.MeltArmor:IsAvailable() or S.MeltArmor:IsAvailable() and Target:DebuffUp(S.MeltArmorDebuff))) and (FightRemains < 130 or Player:BloodlustUp()) and Player:BuffStack(S.SpymastersReportBuff) >= 15 or (BossFightRemains <= 20 or S.Engulf:CooldownUp() and S.Engulf:IsAvailable() and FightRemains <= 40 and S.Dragonrage:CooldownRemains() >= 40)) then
    if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web trinkets 2"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=neural_synapse_enhancer,if=buff.dragonrage.up|!talent.dragonrage|cooldown.dragonrage.remains>=5
    if I.NeuralSynapseEnhancer:IsEquippedAndReady() and (VarDragonrageUp or not S.Dragonrage:IsAvailable() or S.Dragonrage:CooldownRemains() >= 5) then
      if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "neural_synapse_enhancer main 4"; end
    end
    -- use_item,slot=trinket1,if=buff.dragonrage.up&((variable.trinket_2_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&trinket.2.cooldown.remains)|buff.tip_the_scales.up&(!cooldown.shattering_star.up|talent.engulf)&variable.trinket_priority=1|(!cooldown.fire_breath.up&!cooldown.shattering_star.up)|active_enemies>=3)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1|variable.trinket_2_exclude)&!variable.trinket_1_manual|trinket.1.proc.any_dps.duration>=fight_remains|trinket.1.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=1)&!variable.trinket_1_manual
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (VarDragonrageUp and ((VarTrinket2Buffs and S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown() and Trinket2:CooldownDown()) or Player:BuffUp(S.TipTheScalesBuff) and (S.ShatteringStar:CooldownDown() or S.Engulf:IsAvailable()) and VarTrinketPriority == 1 or (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown()) or EnemiesCount8ySplash >= 3) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1 or VarTrinket2Ex) and not VarTrinket1Manual or VarTrinket1CD <= 60 and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) and (not VarDragonrageUp or VarTrinketPriority == 1) and not VarTrinket1Manual) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 6"; end
    end
    -- use_item,slot=trinket2,if=buff.dragonrage.up&((variable.trinket_1_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&trinket.1.cooldown.remains)|buff.tip_the_scales.up&(!cooldown.shattering_star.up|talent.engulf)&variable.trinket_priority=2|(!cooldown.fire_breath.up&!cooldown.shattering_star.up)|active_enemies>=3)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2|variable.trinket_1_exclude)&!variable.trinket_2_manual|trinket.2.proc.any_dps.duration>=fight_remains|trinket.2.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=2)&!variable.trinket_2_manual
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (VarDragonrageUp and ((VarTrinket1Buffs and S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown() and Trinket1:CooldownDown()) or Player:BuffUp(S.TipTheScalesBuff) and (S.ShatteringStar:CooldownDown() or S.Engulf:IsAvailable()) and VarTrinketPriority == 2 or (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown()) or EnemiesCount8ySplash >= 3) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2 or VarTrinket1Ex) and not VarTrinket2Manual or VarTrinket2CD <= 60 and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) and (not VarDragonrageUp or VarTrinketPriority == 2) and not VarTrinket2Manual) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 8"; end
    end
  end
  -- use_item,slot=main_hand,if=variable.weapon_buffs&((variable.trinket_2_buffs&(trinket.2.cooldown.remains|trinket.2.cooldown.duration<=20)|!variable.trinket_2_buffs|variable.trinket_2_exclude|variable.trinket_priority=3)&(variable.trinket_1_buffs&(trinket.1.cooldown.remains|trinket.1.cooldown.duration<=20)|!variable.trinket_1_buffs|variable.trinket_1_exclude|variable.trinket_priority=3)&(!cooldown.fire_breath.up&!cooldown.shattering_star.up|buff.tip_the_scales.up&(!cooldown.shattering_star.up|talent.engulf)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up)|active_enemies>=3))&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=3|variable.trinket_priority=1&trinket.1.cooldown.remains|variable.trinket_priority=2&trinket.2.cooldown.remains)
  local MHToUse, _, MHRange = Player:GetUseableItems(OnUseExcludes, 16)
  if Settings.Commons.Enabled.Items and MHToUse and (VarWeaponBuffs and ((VarTrinket2Buffs and (Trinket2:CooldownDown() or VarTrinket2CD <= 20) or not VarTrinket2Buffs or VarTrinket2Ex or VarTrinketPriority == 3) and (VarTrinket1Buffs and (Trinket1:CooldownDown() or VarTrinket1CD <= 20) or not VarTrinket1Buffs or VarTrinket1Ex or VarTrinketPriority == 3) and (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown() or Player:BuffUp(S.TipTheScalesBuff) and (S.ShatteringStar:CooldownDown() or S.Engulf:IsAvailable()) or (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown()) or EnemiesCount8ySplash >= 3)) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) and (not VarDragonrageUp or VarTrinketPriority == 3 or VarTrinketPriority == 1 and Trinket1:CooldownDown() or VarTrinketPriority == 2 and Trinket2:CooldownDown())) then
    if Cast(MHToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MHRange)) then return "Generic use_item for main_hand " .. MHToUse:Name() .. "  trinkets 10"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web|trinket.2.cooldown.duration=0)&(gcd.remains>0.1&!prev_gcd.1.deep_breath)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_2_buffs|trinket.2.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2CD == 0) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket2Buffs or VarTrinket2ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 12"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web|trinket.1.cooldown.duration=0)&(gcd.remains>0.1&!prev_gcd.1.deep_breath)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_1_buffs|trinket.1.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1CD == 0) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket1Buffs or VarTrinket1ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 14"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web|trinket.2.cooldown.duration=0)&(!variable.trinket_1_ogcd_cast)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_2_buffs|trinket.2.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2CD == 0) and (not VarTrinket1OGCD) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket2Buffs or VarTrinket2ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 16"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web|trinket.1.cooldown.duration=0)&(!variable.trinket_2_ogcd_cast)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_1_buffs|trinket.1.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1CD == 0) and (not VarTrinket2OGCD) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket1Buffs or VarTrinket1ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 18"; end
    end
  end
end

--- ===== APL Main =====
local function APL()
  Enemies25y = Player:GetEnemiesInRange(25)
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if (AoEON()) then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies25y, false)
    end
  end

  -- Player haste value is used in multiple places
  PlayerHaste = Player:SpellHaste()

  -- Are we getting external PI?
  if Player:PowerInfusionUp() then
    VarHasExternalPI = true
  end

  -- Set Dragonrage Variables
  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    VarDragonrageUp = Player:BuffUp(S.Dragonrage)
    VarDragonrageRemains = VarDragonrageUp and Player:BuffRemains(S.Dragonrage) or 0
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() and not Player:IsCasting() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Defensives
    if Player:AffectingCombat() and Settings.Devastation.UseDefensives then
      local ShouldReturn = Defensives(); if ShouldReturn then return ShouldReturn; end
    end
    -- potion,if=(!talent.dragonrage|buff.dragonrage.up)&(!cooldown.shattering_star.up|debuff.shattering_star_debuff.up|active_enemies>=2)|fight_remains<35
    if Settings.Commons.Enabled.Potions and ((not S.Dragonrage:IsAvailable() or VarDragonrageUp) and (S.ShatteringStar:CooldownDown() or Target:DebuffUp(S.ShatteringStarDebuff) or EnemiesCount8ySplash >= 2) or FightRemains < 35) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- variable,name=next_dragonrage,value=cooldown.dragonrage.remains<?((cooldown.eternity_surge.remains-8)>?(cooldown.fire_breath.remains-8))
    VarNextDragonrage = mathmax(S.Dragonrage:CooldownRemains(), mathmin((S.EternitySurge:CooldownRemains() - 8), (S.FireBreath:CooldownRemains() - 8)))
    -- invoke_external_buff,name=power_infusion,if=buff.dragonrage.up&(!cooldown.shattering_star.up|debuff.shattering_star_debuff.up|active_enemies>=2)|fight_remains<35
    -- Note: Not handling external buffs.
    -- variable,name=pool_for_id,if=talent.imminent_destruction,default=0,op=set,value=cooldown.deep_breath.remains<7&essence.deficit>=1&!buff.essence_burst.up&(raid_event.adds.in>=action.deep_breath.cooldown*0.4|talent.melt_armor&talent.maneuverability|active_enemies>=3)
    VarPoolForID = false
    if S.ImminentDestruction:IsAvailable() then
      VarPoolForID = S.DeepBreath:CooldownRemains() < 7 and Player:EssenceDeficit() >= 1 and Player:BuffDown(S.EssenceBurstBuff)
    end
    -- variable,name=can_extend_dr,if=talent.animosity,op=set,value=buff.dragonrage.up&(buff.dragonrage.duration+dbc.effect.1160688.base_value%1000-buff.dragonrage.elapsed-buff.dragonrage.remains)>0
    -- Note: As of 11.1.5.61122, dbc.effect.1160688.base_value is 20000, found via the command: simc spell_query=effect.id=1160688
    VarCanExtendDR = VarDragonrageUp and (18 + 20 - S.Dragonrage:TimeSinceLastCast() - VarDragonrageRemains) > 0
    -- variable,name=can_use_empower,op=set,value=cooldown.dragonrage.remains>=gcd.max*variable.dr_prep_time,if=talent.animosity&talent.dragonrage
    VarCanUseEmpower = (S.Animosity:IsAvailable() and S.Dragonrage:IsAvailable()) and (S.Dragonrage:CooldownRemains() >= Player:GCD() * VarDRPrepTime) or false
    -- quell,use_off_gcd=1,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.Quell, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Unravel if enemy has an absorb shield
    if S.Unravel:IsReady() and Target:ActiveDamageAbsorb() then
      if Cast(S.Unravel, Settings.CommonsOGCD.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 4"; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=3
    if AoEON() and EnemiesCount8ySplash >= 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Aoe()"; end
    end
    -- run_action_list,name=st
    local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    -- Error condition. We should never get here.
    if CastAnnotated(S.Pool, false, "ERR") then return "Wait/Pool Error"; end
  end
end

local function Init()
  S.FireBreathDebuff:RegisterAuraTracking()

  HR.Print("Devastation Evoker rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(1467, APL, Init);
