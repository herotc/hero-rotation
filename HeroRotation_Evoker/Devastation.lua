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
  -- DF Items
  I.KharnalexTheFirstLight:ID(),
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
local MaxEssenceBurstStack = (S.EssenceAttunement:IsAvailable()) and 2 or 1
local MaxBurnoutStack = 2
local PlayerHaste = Player:SpellHaste()
local VarR1CastTime = PlayerHaste
local VarDRPrepTimeAoe, VarDRPrepTimeST = 4, 8
local VarHasExternalPI = false
local VarNextDragonrage
local VarDragonrageUp, VarDragonrageRemains
local VarPoolForID
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
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Buffs, VarTrinket2Buffs
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

  VarTrinket1BL = T1.Blacklisted
  VarTrinket2BL = T2.Blacklisted

  VarTrinket1Buffs = Trinket1:HasUseBuff() or VarTrinket1ID == I.MirrorofFracturedTomorrows:ID()
  VarTrinket2Buffs = Trinket2:HasUseBuff() or VarTrinket2ID == I.MirrorofFracturedTomorrows:ID()

  VarTrinket1Sync = 0.5
  -- Note: If VarTrinket1CD is 0, set it to 1 instead to avoid division by zero errors.
  local T1CD = VarTrinket1CD > 0 and VarTrinket1CD or 1
  if VarTrinket1Buffs and (T1CD % 120 == 0 or 120 % T1CD == 0) then
    VarTrinket1Sync = 1
  end
  VarTrinket2Sync = 0.5
  -- Note: If VarTrinket2CD is 0, set it to 1 instead to avoid division by zero errors.
  local T2CD = VarTrinket2CD > 0 and VarTrinket2CD or 1
  if VarTrinket2Buffs and (T2CD % 120 == 0 or 120 % T2CD == 0) then
    VarTrinket2Sync = 1
  end

  VarTrinket1Manual = VarTrinket1ID == I.BelorrelostheSuncaller:ID() or VarTrinket1ID == I.NymuesUnravelingSpindle:ID() or VarTrinket1ID == I.SpymastersWeb:ID()
  VarTrinket2Manual = VarTrinket2ID == I.BelorrelostheSuncaller:ID() or VarTrinket2ID == I.NymuesUnravelingSpindle:ID() or VarTrinket2ID == I.SpymastersWeb:ID()

  VarTrinket1Exclude = VarTrinket1ID == I.RubyWhelpShell:ID() or VarTrinket1ID == I.WhisperingIncarnateIcon:ID()
  VarTrinket2Exclude = VarTrinket2ID == I.RubyWhelpShell:ID() or VarTrinket2ID == I.WhisperingIncarnateIcon:ID()

  VarTrinketPriority = 1
  if not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((VarTrinket2CD / Trinket2:BuffDuration()) * (VarTrinket2Sync)) > ((VarTrinket1CD / Trinket1:BuffDuration()) * (VarTrinket1Sync)) then
    VarTrinketPriority = 2
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
  MaxEssenceBurstStack = (S.EssenceAttunement:IsAvailable()) and 2 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

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
  return (Player:BuffStack(S.EssenceBurstBuff) < MaxEssenceBurstStack)
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBombardments(TargetUnit)
  -- target_if=min:debuff.bombardments.remains
  return TargetUnit:DebuffRemains(S.BombardmentsDebuff)
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

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.BlessingoftheBronze:IsCastable() and Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff) then
    if Cast(S.BlessingoftheBronze, Settings.CommonsOGCD.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat 2"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.belorrelos_the_suncaller|trinket.1.is.nymues_unraveling_spindle|trinket.1.is.spymasters_web
  -- variable,name=trinket_2_manual,value=trinket.2.is.belorrelos_the_suncaller|trinket.2.is.nymues_unraveling_spindle|trinket.2.is.spymasters_web
  -- variable,name=trinket_1_ogcd_cast,value=0
  -- variable,name=trinket_2_ogcd_cast,value=0
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.intellect)*(variable.trinket_1_sync))
  -- variable,name=damage_trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&!variable.trinket_2_buffs&trinket.2.ilvl>=trinket.1.ilvl
  -- variable,name=r1_cast_time,value=1.0*spell_haste
  VarR1CastTime = PlayerHaste
  -- variable,name=dr_prep_time_aoe,default=4,op=reset
  -- variable,name=dr_prep_time_st,default=8,op=reset
  -- Note: Variables are never changed. Moving to variable declaration instead.
  -- variable,name=has_external_pi,value=cooldown.invoke_power_infusion_0.duration>0
  -- Note: Not handling external PI.
  -- verdant_embrace,if=talent.scarlet_adaptation
  if Settings.Devastation.UseGreen and S.VerdantEmbrace:IsCastable() and (S.ScarletAdaptation:IsAvailable()) then
    if Cast(S.VerdantEmbrace) then return "verdant_embrace precombat 4"; end
  end
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
  -- eternity_surge,empower_to=1,target_if=max:target.health.pct,if=active_enemies<=1+talent.eternitys_span|buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste|buff.dragonrage.up&(active_enemies>(3+talent.font_of_magic)*(1+talent.eternitys_span))|active_enemies>=6&!talent.eternitys_span
  if EnemiesCount8ySplash <= 1 + num(S.EternitysSpan:IsAvailable()) or VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= PlayerHaste or VarDragonrageUp and (EnemiesCount8ySplash > (3 + num(S.FontofMagic:IsAvailable())) * (1 + num(S.EternitysSpan:IsAvailable()))) or EnemiesCount8ySplash >= 6 and not S.EternitysSpan:IsAvailable() then
    ESEmpower = 1
  -- eternity_surge,empower_to=2,target_if=max:target.health.pct,if=active_enemies<=2+2*talent.eternitys_span|buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste
  elseif EnemiesCount8ySplash <= 2 + 2 * num(S.EternitysSpan:IsAvailable()) or VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste then
    ESEmpower = 2
  -- eternity_surge,empower_to=3,target_if=max:target.health.pct,if=active_enemies<=3+3*talent.eternitys_span|!talent.font_of_magic|buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste
  elseif EnemiesCount8ySplash <= 3 + 3 * num(S.EternitysSpan:IsAvailable()) or not S.FontofMagic:IsAvailable() or VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste then
    ESEmpower = 3
  -- eternity_surge,empower_to=4,target_if=max:target.health.pct
  else
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
  -- fire_breath,empower_to=1,target_if=max:target.health.pct,if=(buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste)|active_enemies=1|talent.scorching_embers&!dot.fire_breath_damage.ticking
  if (VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= PlayerHaste) or EnemiesCount8ySplash == 1 or S.ScorchingEmbers:IsAvailable() and not Target:DebuffUp(S.FireBreathDebuff) then
    FBEmpower = 1
  -- fire_breath,empower_to=2,target_if=max:target.health.pct,if=active_enemies=2|(buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste)|talent.scorching_embers
  elseif EnemiesCount8ySplash == 2 or (VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste) or S.ScorchingEmbers:IsAvailable() then
    FBEmpower = 2
  -- fire_breath,empower_to=3,target_if=max:target.health.pct,if=!talent.font_of_magic|(buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste)|talent.scorching_embers
  elseif not S.FontofMagic:IsAvailable() or (VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste) or S.ScorchingEmbers:IsAvailable() then
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
  -- shattering_star,target_if=max:target.health.pct,if=cooldown.dragonrage.up&talent.arcane_vigor|talent.eternitys_span&active_enemies<=3
  if S.ShatteringStar:IsCastable() and (S.Dragonrage:CooldownUp() and S.ArcaneVigor:IsAvailable() or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash <= 3) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 2"; end
  end
  -- hover,use_off_gcd=1,if=raid_event.movement.in<6&!buff.hover.up&gcd.remains>=0.5&(buff.mass_disintegrate_stacks.up&talent.mass_disintegrate|active_enemies<=4)
  -- Note: Not handling movement ability.
  -- firestorm,if=buff.snapfire.up
  if S.Firestorm:IsCastable() and (Player:BuffUp(S.SnapfireBuff)) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 4"; end
  end
  -- firestorm,if=talent.feed_the_flames
  if S.Firestorm:IsCastable() and (S.FeedtheFlames:IsAvailable()) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 6"; end
  end
  -- call_action_list,name=fb,if=talent.dragonrage&cooldown.dragonrage.up&talent.iridescence
  if S.Dragonrage:IsAvailable() and S.Dragonrage:CooldownUp() and S.Iridescence:IsAvailable() then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- deep_breath,if=talent.maneuverability&talent.melt_armor
  if CDsON() and DeepBreathAbility:IsCastable() and (S.Maneuverability:IsAvailable() and S.MeltArmor:IsAvailable()) then
    if Cast(DeepBreathAbility, nil, nil, not Target:IsInRange(50)) then return "deep_breath aoe 8"; end
  end
  -- dragonrage,if=target.time_to_die>=32|fight_remains<30
  if CDsON() and S.Dragonrage:IsCastable() and (Target:TimeToDie() >= 32 or BossFightRemains < 30) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage aoe 10"; end
  end
  -- tip_the_scales,if=buff.dragonrage.up&((active_enemies<=3+3*talent.eternitys_span&!talent.engulf)|!cooldown.fire_breath.up)
  if CDsON() and S.TipTheScales:IsCastable() and (VarDragonrageUp and ((EnemiesCount8ySplash <= 3 + 3 * num(S.EternitysSpan:IsAvailable()) and not S.Engulf:IsAvailable()) or S.FireBreath:CooldownDown())) then
    if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales) then return "tip_the_scales aoe 12"; end
  end
  -- call_action_list,name=fb,if=(!talent.dragonrage|buff.dragonrage.up|cooldown.dragonrage.remains>variable.dr_prep_time_aoe|!talent.animosity)&(target.time_to_die>=8|fight_remains<30)
  -- call_action_list,name=es,if=(!talent.dragonrage|buff.dragonrage.up|cooldown.dragonrage.remains>variable.dr_prep_time_aoe|!talent.animosity)&(target.time_to_die>=8|fight_remains<30)
  if (not S.Dragonrage:IsAvailable() or VarDragonrageUp or S.Dragonrage:CooldownRemains() > VarDRPrepTimeAoe or not S.Animosity:IsAvailable()) and (Target:TimeToDie() >= 8 or BossFightRemains < 30) then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
    local ShouldReturn = ES(); if ShouldReturn then return ShouldReturn; end
  end
  -- deep_breath,if=!buff.dragonrage.up&essence.deficit>3
  if CDsON() and DeepBreathAbility:IsCastable() and (not VarDragonrageUp and Player:EssenceDeficit() > 3) then
    if Cast(DeepBreathAbility, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath aoe 14"; end
  end
  -- shattering_star,target_if=max:target.health.pct,if=buff.essence_burst.stack<buff.essence_burst.max_stack&talent.arcane_vigor|talent.eternitys_span&active_enemies<=3
  if S.ShatteringStar:IsCastable() and (LessThanMaxEssenceBurst() and S.ArcaneVigor:IsAvailable() or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash <= 3) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 16"; end
  end
  -- engulf,if=dot.fire_breath_damage.ticking&(!talent.shattering_star|debuff.shattering_star_debuff.up)&cooldown.dragonrage.remains>=27
  if S.Engulf:IsReady() and (Target:DebuffUp(S.FireBreathDebuff) and (not S.ShatteringStar:IsAvailable() or Target:DebuffUp(S.ShatteringStarDebuff)) and S.Dragonrage:CooldownRemains() >= 27) then
    if Cast(S.Engulf, nil, nil, not Target:IsInRange(25)) then return "engulf aoe 18"; end
  end
  -- disintegrate,target_if=min:debuff.bombardments.remains,if=buff.mass_disintegrate_stacks.up&talent.mass_disintegrate&(buff.charged_blast.stack<10|!talent.charged_blast)
  if S.Disintegrate:IsReady() and (S.MassDisintegrate:IsAvailable() and (Player:BuffStack(S.ChargedBlastBuff) < 10 or not S.ChargedBlast:IsAvailable())) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, EvaluateTargetIfDisintegrate, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate aoe 20"; end
  end
  -- pyre,target_if=max:target.health.pct,if=(active_enemies>=4|talent.volatility)&(cooldown.dragonrage.remains>gcd.max*4|!talent.charged_blast|talent.engulf&(!talent.arcane_intensity|!talent.eternitys_span))&!variable.pool_for_id
  if S.Pyre:IsReady() and ((EnemiesCount8ySplash >= 4 or S.Volatility:IsAvailable()) and (S.Dragonrage:CooldownRemains() > Player:GCD() * 4 or not S.ChargedBlast:IsAvailable() or S.Engulf:IsAvailable() and (not S.ArcaneIntensity:IsAvailable() or not S.EternitysSpan:IsAvailable())) and not VarPoolForID) then
    if Everyone.CastTargetIf(S.Pyre, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Pyre) then return "pyre aoe 22"; end
  end
  -- pyre,target_if=max:target.health.pct,if=buff.charged_blast.stack>=12&cooldown.dragonrage.remains>gcd.max*4
  if S.Pyre:IsReady() and (Player:BuffStack(S.ChargedBlastBuff) >= 12 and S.Dragonrage:CooldownRemains() > Player:GCD() * 4) then
    if Everyone.CastTargetIf(S.Pyre, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Pyre) then return "pyre aoe 24"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=(!talent.burnout|buff.burnout.up|cooldown.fire_breath.remains<=gcd.max*5|buff.scarlet_adaptation.up|buff.ancient_flame.up)&buff.leaping_flames.up&!buff.essence_burst.up&essence.deficit>1
  if S.LivingFlame:IsReady() and ((not S.Burnout:IsAvailable() or Player:BuffUp(S.BurnoutBuff) or S.FireBreath:CooldownRemains() <= Player:GCD() * 5 or Player:BuffUp(S.ScarletAdaptationBuff) or Player:BuffUp(S.AncientFlameBuff)) and Player:BuffUp(S.LeapingFlamesBuff) and Player:BuffDown(S.EssenceBurstBuff) and Player:EssenceDeficit() > 1) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.LivingFlame) then return "living_flame aoe 26"; end
  end
  -- disintegrate,target_if=max:target.health.pct,chain=1,early_chain_if=evoker.use_early_chaining&ticks>=2&(raid_event.movement.in>2|buff.hover.up),interrupt_if=evoker.use_clipping&buff.dragonrage.up&ticks>=2&(raid_event.movement.in>2|buff.hover.up),if=(raid_event.movement.in>2|buff.hover.up)&&!variable.pool_for_id
  if S.Disintegrate:IsReady() and (not VarPoolForID) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate aoe 28"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=talent.snapfire&buff.burnout.up
  if S.LivingFlame:IsReady() and (S.Snapfire:IsAvailable() and Player:BuffUp(S.BurnoutBuff)) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.LivingFlame) then return "living_flame aoe 30"; end
  end
  -- firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 32"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&!buff.ancient_flame.up&!buff.dragonrage.up
  if Settings.Devastation.UseGreen and S.AncientFlame:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and not VarDragonrageUp then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- azure_strike,target_if=max:target.health.pct
  -- Note: Since this is a filler, going to use both Cast and CastTargetIf.
  if S.AzureStrike:IsCastable() then
    if Everyone.CastTargetIf(S.AzureStrike, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike cti aoe 34"; end
  end
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike aoe 36"; end
  end
end

local function ST()
  -- use_item,name=kharnalex_the_first_light,if=!buff.dragonrage.up&debuff.shattering_star_debuff.down&raid_event.movement.in>6
  if Settings.Commons.Enabled.Items and I.KharnalexTheFirstLight:IsEquippedAndReady() and (not VarDragonrageUp and Target:DebuffDown(S.ShatteringStar)) then
    if Cast(I.KharnalexTheFirstLight, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(25)) then return "kharnalex_the_first_light st 2"; end
  end
  -- hover,use_off_gcd=1,if=raid_event.movement.in<6&!buff.hover.up&gcd.remains>=0.5
  -- Note: Not handling movement ability.
  -- deep_breath,if=talent.maneuverability&talent.melt_armor
  if CDsON() and DeepBreathAbility:IsCastable() and (S.Maneuverability:IsAvailable() and S.MeltArmor:IsAvailable()) then
    if Cast(DeepBreathAbility, nil, nil, not Target:IsInRange(50)) then return "deep_breath st 4"; end
  end
  -- dragonrage,if=(cooldown.fire_breath.remains<4|cooldown.eternity_surge.remains<4&(!set_bonus.tww1_4pc|!talent.mass_disintegrate))&(cooldown.fire_breath.remains<8&(cooldown.eternity_surge.remains<8|set_bonus.tww1_4pc&talent.mass_disintegrate))&target.time_to_die>=32|fight_remains<32
  if CDsON() and S.Dragonrage:IsCastable() and ((S.FireBreath:CooldownRemains() < 4 or S.EternitySurge:CooldownRemains() < 4 and (not Player:HasTier("TWW1", 4) or not S.MassDisintegrate:IsAvailable())) or (S.FireBreath:CooldownRemains() < 8 and (S.EternitySurge:CooldownRemains() < 8 or Player:HasTier("TWW1", 4) and S.MassDisintegrate:IsAvailable())) and Target:TimeToDie() >= 32 or BossFightRemains < 32) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage st 6"; end
  end
  -- tip_the_scales,if=(!talent.dragonrage|buff.dragonrage.up)&(cooldown.fire_breath.remains<cooldown.eternity_surge.remains|(cooldown.eternity_surge.remains<cooldown.fire_breath.remains&talent.font_of_magic))
  if CDsON() and S.TipTheScales:IsCastable() and ((not S.Dragonrage:IsAvailable() or VarDragonrageUp) and (S.FireBreath:CooldownRemains() < S.EternitySurge:CooldownRemains() or (S.EternitySurge:CooldownRemains() < S.FireBreath:CooldownRemains() and S.FontofMagic:IsAvailable()))) then
    if Cast(S.TipTheScales, Settings.CommonsOGCD.GCDasOffGCD.TipTheScales) then return "tip_the_scales st 8"; end
  end
  -- shattering_star,if=(buff.essence_burst.stack<buff.essence_burst.max_stack|!talent.arcane_vigor)&(!cooldown.eternity_surge.up|!buff.dragonrage.up|talent.mass_disintegrate|!talent.event_horizon&(!talent.traveling_flame|!cooldown.engulf.up))&(cooldown.dragonrage.remains>=15|cooldown.fire_breath.remains>=8|buff.dragonrage.up&(cooldown.fire_breath.remains<=gcd&buff.tip_the_scales.up|cooldown.tip_the_scales.remains>=15&!buff.tip_the_scales.up)|!talent.traveling_flame)&(!cooldown.fire_breath.up|buff.tip_the_scales.up)
  if S.ShatteringStar:IsCastable() and ((LessThanMaxEssenceBurst() or not S.ArcaneVigor:IsAvailable()) and (S.EternitySurge:CooldownDown() or not VarDragonrageUp or S.MassDisintegrate:IsAvailable() or not S.EventHorizon:IsAvailable() and (not S.TravelingFlame:IsAvailable() or S.Engulf:CooldownDown())) and (S.Dragonrage:CooldownRemains() >= 15 or S.FireBreath:CooldownRemains() >= 8 or VarDragonrageUp and (S.FireBreath:CooldownRemains() <= Player:GCD() and Player:BuffUp(S.TipTheScalesBuff) or S.TipTheScales:CooldownRemains() >= 15 and Player:BuffDown(S.TipTheScalesBuff)) or not S.TravelingFlame:IsAvailable()) and (S.FireBreath:CooldownDown() or Player:BuffUp(S.TipTheScalesBuff))) then
    if Cast(S.ShatteringStar, nil, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star st 10"; end
  end
  -- call_action_list,name=fb,if=(!talent.dragonrage|variable.next_dragonrage>variable.dr_prep_time_st|!talent.animosity)&(!cooldown.eternity_surge.up|!talent.event_horizon&!talent.traveling_flame|talent.mass_disintegrate|!buff.dragonrage.up)&(target.time_to_die>=8|fight_remains<30)
  if (not S.Dragonrage:IsAvailable() or VarNextDragonrage > VarDRPrepTimeST or not S.Animosity:IsAvailable()) and (S.EternitySurge:CooldownDown() or not S.EventHorizon:IsAvailable() and not S.TravelingFlame:IsAvailable() or S.MassDisintegrate:IsAvailable() or not VarDragonrageUp) and (Target:TimeToDie() >= 8 or BossFightRemains < 30) then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=es,if=(!talent.dragonrage|variable.next_dragonrage>variable.dr_prep_time_st|!talent.animosity|set_bonus.tww1_4pc&talent.mass_disintegrate)&(target.time_to_die>=8|fight_remains<30)
  if (not S.Dragonrage:IsAvailable() or VarNextDragonrage > VarDRPrepTimeST or not S.Animosity:IsAvailable() or Player:HasTier("TWW1", 4) and S.MassDisintegrate:IsAvailable()) and (Target:TimeToDie() >= 8 or BossFightRemains < 30) then
    local ShouldReturn = ES(); if ShouldReturn then return ShouldReturn; end
  end
  -- wait,sec=cooldown.fire_breath.remains,if=talent.animosity&buff.dragonrage.up&buff.dragonrage.remains<gcd.max+variable.r1_cast_time*buff.tip_the_scales.down&buff.dragonrage.remains-cooldown.fire_breath.remains>=variable.r1_cast_time*buff.tip_the_scales.down
  if S.FireBreath:CooldownDown() and (S.Animosity:IsAvailable() and VarDragonrageUp and VarDragonrageRemains < Player:GCD() + VarR1CastTime * num(Player:BuffDown(S.TipTheScalesBuff)) and VarDragonrageRemains - S.FireBreath:CooldownRemains() >= VarR1CastTime * num(Player:BuffDown(S.TipTheScalesBuff))) then
    if CastPooling(S.Pool, S.FireBreath:CooldownRemains()) then return "Wait for FB()"; end
  end
  -- wait,sec=cooldown.eternity_surge.remains,if=talent.animosity&buff.dragonrage.up&buff.dragonrage.remains<gcd.max+variable.r1_cast_time&buff.dragonrage.remains-cooldown.eternity_surge.remains>variable.r1_cast_time*buff.tip_the_scales.down
  if S.EternitySurge:CooldownDown() and (S.Animosity:IsAvailable() and VarDragonrageUp and VarDragonrageRemains < Player:GCD() + VarR1CastTime and VarDragonrageRemains - S.EternitySurge:CooldownRemains() > VarR1CastTime * num(Player:BuffDown(S.TipTheScalesBuff))) then
    if CastPooling(S.Pool, S.EternitySurge:CooldownRemains()) then return "Wait for ES()"; end
  end
  -- living_flame,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max&buff.burnout.up
  if S.LivingFlame:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (MaxEssenceBurstStack - Player:BuffStack(S.EssenceBurstBuff)) * Player:GCD() and Player:BuffUp(S.BurnoutBuff)) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(40)) then return "living_flame st 12"; end
  end
  -- azure_strike,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max
  if S.AzureStrike:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (MaxEssenceBurstStack - Player:BuffStack(S.EssenceBurstBuff)) * Player:GCD()) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsInRange(40)) then return "azure_strike st 14"; end
  end
  -- engulf,if=dot.fire_breath_damage.ticking&(!talent.enkindle|dot.enkindle.ticking&(prev_gcd.1.disintegrate|prev_gcd.1.engulf|prev_gcd.2.disintegrate|!talent.fan_the_flames|active_enemies>1))&(!talent.ruby_embers|dot.living_flame_damage.ticking)&(!talent.shattering_star|debuff.shattering_star_debuff.up)&cooldown.dragonrage.remains>=27
  if S.Engulf:IsReady() and (Target:DebuffUp(S.FireBreathDebuff) and (not S.Enkindle:IsAvailable() or Player:BuffUp(S.EnkindleBuff) and (S.PrevGCDP(1, S.Disintegrate) or S.PrevGCDP(1, S.Engulf) or S.PrevGCDP(2, S.Disintegrate) or not S.FanTheFlames:IsAvailable() or EnemiesCount8ySplash > 1)) and (not S.RubyEmbers:IsAvailable() or Target:DebuffUp(S.LivingFlameDebuff)) and (not S.ShatteringStar:IsAvailable() or Target:DebuffUp(S.ShatteringStarDebuff)) and S.Dragonrage:CooldownRemains() >= 27) then
    if Cast(S.Engulf, nil, nil, not Target:IsInRange(25)) then return "engulf st 16"; end
  end
  -- living_flame,if=buff.burnout.up&buff.leaping_flames.up&!buff.essence_burst.up&buff.dragonrage.up
  if S.LivingFlame:IsReady() and (Player:BuffUp(S.BurnoutBuff) and Player:BuffUp(S.LeapingFlamesBuff) and Player:BuffDown(S.EssenceBurstBuff) and VarDragonrageUp) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(40)) then return "living_flame st 18"; end
  end
  -- firestorm,if=!buff.dragonrage.up&debuff.shattering_star_debuff.down&talent.feed_the_flames&((!talent.dragonrage|cooldown.dragonrage.remains>=10)&(essence>=3|buff.essence_burst.up|talent.shattering_star&cooldown.shattering_star.remains<=6)|talent.dragonrage&cooldown.dragonrage.remains<=cast_time&cooldown.fire_breath.remains<6&cooldown.eternity_surge.remains<12)&!debuff.in_firestorm.up
  if S.Firestorm:IsReady() and (not VarDragonrageUp and Target:DebuffDown(S.ShatteringStarDebuff) and S.FeedtheFlames:IsAvailable() and ((not S.Dragonrage:IsAvailable() or S.Dragonrage:CooldownRemains() >= 10) and (Player:Essence() >= 3 or Player:BuffUp(S.EssenceBurstBuff) or S.ShatteringStar:IsAvailable() and S.ShatteringStar:CooldownRemains() <= 6) or S.Dragonrage:IsAvailable() and S.Dragonrage:CooldownRemains() <= S.Firestorm:CastTime() and S.FireBreath:CooldownRemains() < 6 and S.EternitySurge:CooldownRemains() < 12) and not InFirestorm()) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 20"; end
  end
  -- deep_breath,if=!buff.dragonrage.up&(talent.imminent_destruction&!debuff.shattering_star_debuff.up|talent.melt_armor&talent.maneuverability)
  if CDsON() and DeepBreathAbility:IsCastable() and (not VarDragonrageUp and (S.ImminentDestruction:IsAvailable() and Target:DebuffDown(S.ShatteringStarDebuff)) or S.MeltArmor:IsAvailable() and S.Maneuverability:IsAvailable()) then
    if Cast(DeepBreathAbility, nil, nil, not Target:IsInRange(50)) then return "deep_breath st 22"; end
  end
  -- pyre,if=debuff.in_firestorm.up&talent.feed_the_flames&buff.charged_blast.stack==20&active_enemies>=2
  if S.Pyre:IsReady() and (InFirestorm() and S.FeedtheFlames:IsAvailable() and Player:BuffStack(S.ChargedBlastBuff) == 20 and EnemiesCount8ySplash >= 2) then
    if Cast(S.Pyre, nil, nil, not Target:IsInRange(40)) then return "pyre st 24"; end
  end
  -- disintegrate,target_if=min:buff.bombardments.remains,early_chain_if=ticks_remain<=1&buff.mass_disintegrate_stacks.up,if=(raid_event.movement.in>2|buff.hover.up)&buff.mass_disintegrate_stacks.up&talent.mass_disintegrate
  if S.Disintegrate:IsReady() and (Player:BuffUp(S.MassDisintegrateBuff) and S.MassDisintegrate:IsAvailable()) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate st 26"; end
  end
  -- disintegrate,target_if=min:buff.bombardments.remains,chain=1,early_chain_if=evoker.use_early_chaining&ticks>=2&(raid_event.movement.in>2|buff.hover.up),interrupt_if=evoker.use_clipping&ticks>=2&(raid_event.movement.in>2|buff.hover.up),if=(raid_event.movement.in>2|buff.hover.up)&!variable.pool_for_id
  if S.Disintegrate:IsReady() and (not VarPoolForID) then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "min", EvaluateTargetIfFilterBombardments, nil, not Target:IsInRange(40), nil, Settings.CommonsDS.DisplayStyle.Disintegrate) then return "disintegrate st 28"; end
  end
  -- firestorm,if=buff.snapfire.up|!debuff.in_firestorm.up&talent.feed_the_flames
  if S.Firestorm:IsReady() and (Player:BuffUp(S.SnapfireBuff) or not InFirestorm() and S.FeedtheFlames:IsAvailable()) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 30"; end
  end
  -- deep_breath,if=!buff.dragonrage.up&active_enemies>=2&((raid_event.adds.in>=120&!talent.onyx_legacy)|(raid_event.adds.in>=60&talent.onyx_legacy))
  if CDsON() and DeepBreathAbility:IsCastable() and (not VarDragonrageUp and EnemiesCount8ySplash >= 2) then
    if Cast(DeepBreathAbility, nil, nil, not Target:IsInRange(50)) then return "deep_breath st 32"; end
  end
  -- deep_breath,if=!buff.dragonrage.up&(talent.imminent_destruction&!debuff.shattering_star_debuff.up|talent.melt_armor|talent.maneuverability)
  if CDsON() and DeepBreathAbility:IsCastable() and (not VarDragonrageUp and (S.ImminentDestruction:IsAvailable() and Target:DebuffDown(S.ShatteringStarDebuff) or S.MeltArmor:IsAvailable() or S.Maneuverability:IsAvailable())) then
    if Cast(DeepBreathAbility, nil, nil, not Target:IsInRange(50)) then return "deep_breath st 34"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&!buff.ancient_flame.up&!buff.shattering_star_debuff.up&talent.scarlet_adaptation&!buff.dragonrage.up&!buff.burnout.up
  if Settings.Devastation.UseGreen and (S.AncientFlame:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and Target:DebuffDown(S.ShatteringStarDebuff) and S.ScarletAdaptation:IsAvailable() and not VarDragonrageUp and Player:BuffDown(S.BurnoutBuff)) then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- living_flame,if=!buff.dragonrage.up|(buff.iridescence_red.remains>execute_time|!talent.engulfing_blaze|buff.iridescence_blue.up|buff.burnout.up|buff.leaping_flames.up&cooldown.fire_breath.remains<=5)&active_enemies==1
  if S.LivingFlame:IsReady() and (not VarDragonrageUp or (Player:BuffRemains(S.IridescenceRedBuff) > S.LivingFlame:ExecuteTime() and not S.EngulfingBlaze:IsAvailable() or Player:BuffUp(S.IridescenceBlueBuff) or Player:BuffUp(S.BurnoutBuff) or Player:BuffUp(S.LeapingFlamesBuff) and S.FireBreath:CooldownRemains() <= 5) and EnemiesCount8ySplash == 1) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(40)) then return "living_flame st 36"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike st 34"; end
  end
end

local function Trinkets()
  -- use_item,name=spymasters_web,if=buff.dragonrage.up&(fight_remains<130)&buff.spymasters_report.stack>=15|(fight_remains<=20|cooldown.engulf.up&talent.engulf&fight_remains<=40&cooldown.dragonrage.remains>=40)
  if Settings.Commons.Enabled.Items and I.SpymastersWeb:IsEquippedAndReady() and (VarDragonrageUp and (FightRemains < 130) and Player:BuffStack(S.SpymastersReportBuff) >= 15 or (BossFightRemains <= 20 or S.Engulf:CooldownUp() and S.Engulf:IsAvailable() and FightRemains <= 40 and S.Dragonrage:CooldownRemains() >= 40)) then
    if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web trinkets 2"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,slot=trinket1,if=buff.dragonrage.up&((variable.trinket_2_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&trinket.2.cooldown.remains)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up)|active_enemies>=3)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1|variable.trinket_2_exclude)&!variable.trinket_1_manual|trinket.1.proc.any_dps.duration>=fight_remains|trinket.1.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=1)&!variable.trinket_1_manual
    if Trinket1:IsReady() and not VarTrinket1BL and (VarDragonrageUp and ((VarTrinket2Buffs and S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown() and Trinket2:CooldownDown()) or (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown()) or EnemiesCount8ySplash >= 3) and (not Trinket2:HasCooldown() or Trinket2:CooldownDown() or VarTrinketPriority == 1 or VarTrinket2Exclude) and not VarTrinket1Manual or Trinket1:BuffDuration() >= FightRemains or VarTrinket1CD <= 60 and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) and (not VarDragonrageUp or VarTrinketPriority == 1) and not VarTrinket1Manual) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 4"; end
    end
    -- use_item,slot=trinket2,if=buff.dragonrage.up&((variable.trinket_1_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&trinket.1.cooldown.remains)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up)|active_enemies>=3)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2|variable.trinket_1_exclude)&!variable.trinket_2_manual|trinket.2.proc.any_dps.duration>=fight_remains|trinket.2.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=2)&!variable.trinket_2_manual
    if Trinket2:IsReady() and not VarTrinket2BL and (VarDragonrageUp and ((VarTrinket1Buffs and S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown() and Trinket1:CooldownDown()) or (S.FireBreath:CooldownDown() and S.ShatteringStar:CooldownDown()) or EnemiesCount8ySplash >= 3) and (not Trinket1:HasCooldown() or Trinket1:CooldownDown() or VarTrinketPriority == 2 or VarTrinket1Exclude) and not VarTrinket2Manual or Trinket2:BuffDuration() >= FightRemains or VarTrinket2CD <= 60 and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) and (not VarDragonrageUp or VarTrinketPriority == 2) and not VarTrinket2Manual) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 6"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web|trinket.2.cooldown.duration=0)&(gcd.remains>0.1&!prev_gcd.1.deep_breath)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_2_buffs|trinket.2.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2CD == 0) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket2Buffs or VarTrinket2ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web|trinket.1.cooldown.duration=0)&(gcd.remains>0.1&!prev_gcd.1.deep_breath)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_1_buffs|trinket.1.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1CD == 0) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket1Buffs or VarTrinket1ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 10"; end
    end
    -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(variable.damage_trinket_priority=1|trinket.2.cooldown.remains|trinket.2.is.spymasters_web|trinket.2.cooldown.duration=0)&(!variable.trinket_1_ogcd_cast)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_2_buffs|trinket.2.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket1:IsReady() and not VarTrinket1BL and (not VarTrinket1Buffs and not VarTrinket1Manual and (VarDamageTrinketPriority == 1 or Trinket2:CooldownDown() or VarTrinket2ID == I.SpymastersWeb:ID() or VarTrinket2CD == 0) and (not VarTrinket1OGCD) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket2Buffs or VarTrinket2ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "Generic use_item for " .. Trinket1:Name() .. " trinkets 12"; end
    end
    -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(variable.damage_trinket_priority=2|trinket.1.cooldown.remains|trinket.1.is.spymasters_web|trinket.1.cooldown.duration=0)&(!variable.trinket_2_ogcd_cast)&(variable.next_dragonrage>20|!talent.dragonrage|!variable.trinket_1_buffs|trinket.1.is.spymasters_web&(buff.spymasters_report.stack<5|fight_remains>=130+variable.next_dragonrage))
    if Trinket2:IsReady() and not VarTrinket2BL and (not VarTrinket2Buffs and not VarTrinket2Manual and (VarDamageTrinketPriority == 2 or Trinket1:CooldownDown() or VarTrinket1ID == I.SpymastersWeb:ID() or VarTrinket1CD == 0) and (not VarTrinket2OGCD) and (VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable() or not VarTrinket1Buffs or VarTrinket1ID == I.SpymastersWeb:ID() and (Player:BuffStack(S.SpymastersReportBuff) < 5 or FightRemains >= 130 + VarNextDragonrage))) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "Generic use_item for " .. Trinket2:Name() .. " trinkets 14"; end
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
    -- potion,if=buff.dragonrage.up&(!cooldown.shattering_star.up|active_enemies>=2)|fight_remains<35
    if Settings.Commons.Enabled.Potions and (VarDragonrageUp and (S.ShatteringStar:CooldownDown() or EnemiesCount8ySplash >= 2) or FightRemains < 35) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- variable,name=next_dragonrage,value=cooldown.dragonrage.remains<?((cooldown.eternity_surge.remains-8)>?(cooldown.fire_breath.remains-8))
    VarNextDragonrage = mathmax(S.Dragonrage:CooldownRemains(), mathmin((S.EternitySurge:CooldownRemains() - 8), (S.FireBreath:CooldownRemains() - 8)))
    -- invoke_external_buff,name=power_infusion,if=buff.dragonrage.up&!cooldown.fire_breath.up&!cooldown.shattering_star.up
    -- Note: Not handling external buffs.
    -- quell,use_off_gcd=1,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.Quell, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Unravel if enemy has an absorb shield
    if S.Unravel:IsReady() and Target:EnemyAbsorb() then
      if Cast(S.Unravel, Settings.CommonsOGCD.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 4"; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=aoe,if=active_enemies>=3
    if EnemiesCount8ySplash >= 3 then
      local ShouldReturn = Aoe(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Aoe()"; end
    end
    -- run_action_list,name=st
    if true then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
      if CastAnnotated(S.Pool, false, "WAIT") then return "Pool for ST()"; end
    end
    -- Error condition. We should never get here.
    if CastAnnotated(S.Pool, false, "ERR") then return "Wait/Pool Error"; end
  end
end

local function Init()
  HR.Print("Devastation Evoker rotation has been updated for patch 11.0.2.")
end

HR.SetAPL(1467, APL, Init);
