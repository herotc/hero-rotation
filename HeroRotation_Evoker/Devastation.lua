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

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Evoker.Devastation
local I = Item.Evoker.Devastation

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BelorrelostheSuncaller:ID(),
  I.Dreambinder:ID(),
  I.Iridal:ID(),
  I.NymuesUnravelingSpindle:ID(),
  I.ShadowedOrbofTorment:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Evoker.Commons,
  Devastation = HR.GUISettings.APL.Evoker.Devastation
}

-- Trinket Item Objects
local equip = Player:GetEquipment()
local trinket1 = equip[13] and Item(equip[13]) or Item(0)
local trinket2 = equip[14] and Item(equip[14]) or Item(0)

-- Rotation Var
local Enemies25y
local Enemies8ySplash
local EnemiesCount8ySplash
local MaxEssenceBurstStack = (S.EssenceAttunement:IsAvailable()) and 2 or 1
local MaxBurnoutStack = 2
local VarTrinket1Sync, VarTrinket2Sync, TrinketPriority
local VarNextDragonrage
local VarDragonrageUp, VarDragonrageRemains
local VarDRPrepTimeAoe = 4
local VarDRPrepTimeST = 13
local PlayerHaste = Player:SpellHaste()
local VarR1CastTime = 1.0 * PlayerHaste
local VarHasExternalPI = false
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

-- Stun Interrupts
local StunInterrupts = {
  {S.TailSwipe, "Cast Tail Swipe (Interrupt)", function() return true; end},
  {S.WingBuffet, "Cast Wing Buffet (Interrupt)", function() return true; end},
}

-- Update Equipment
HL:RegisterForEvent(function()
  equip = Player:GetEquipment()
  trinket1 = equip[13] and Item(equip[13]) or Item(0)
  trinket2 = equip[14] and Item(equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

-- Talent change registrations
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

-- CastTargetIf/CastCycle Functions
local function EvaluateTargetIfFilterHPPct(TargetUnit)
  -- target_if=max:target.health.pct
  return (TargetUnit:HealthPercentage())
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.BlessingoftheBronze:IsCastable() and Everyone.GroupBuffMissing(S.BlessingoftheBronzeBuff) then
    if Cast(S.BlessingoftheBronze, Settings.Commons.GCDasOffGCD.BlessingOfTheBronze) then return "blessing_of_the_bronze precombat"; end
  end
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.mirror_of_fractured_tomorrows
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.dragonrage.duration=0|cooldown.dragonrage.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.belorrelos_the_suncaller|trinket.1.is.nymues_unraveling_spindle
  -- variable,name=trinket_2_manual,value=trinket.2.is.belorrelos_the_suncaller|trinket.2.is.nymues_unraveling_spindle
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%trinket.2.proc.any_dps.duration)*(1.5+trinket.2.has_buff.intellect)*(variable.trinket_2_sync))>((trinket.1.cooldown.duration%trinket.1.proc.any_dps.duration)*(1.5+trinket.1.has_buff.intellect)*(variable.trinket_1_sync))
  -- TODO: Can't yet handle all of these trinket conditions
  -- variable,name=r1_cast_time,value=1.0*spell_haste
  VarR1CastTime = 1.0 * PlayerHaste
  -- variable,name=dr_prep_time_aoe,default=4,op=reset
  -- variable,name=dr_prep_time_st,default=13,op=reset
  -- Note: Variables are never changed. Moving to variable declaration instead.
  -- variable,name=has_external_pi,value=cooldown.invoke_power_infusion_0.duration>0
  -- Note: Not handling external PI.
  -- use_item,name=shadowed_orb_of_torment
  if Settings.Commons.Enabled.Trinkets and I.ShadowedOrbofTorment:IsEquippedAndReady() then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment precombat 2"; end
  end
  -- verdant_embrace,if=talent.scarlet_adaptation
  if Settings.Devastation.UseGreen and S.VerdantEmbrace:IsCastable() and (S.ScarletAdaptation:IsAvailable()) then
    if Cast(S.VerdantEmbrace) then return "verdant_embrace precombat 4"; end
  end
  -- firestorm,if=talent.firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm precombat 6"; end
  end
  -- living_flame,if=!talent.firestorm
  if S.LivingFlame:IsCastable() and (not S.Firestorm:IsAvailable()) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsInRange(25)) then return "living_flame precombat 8"; end
  end
end

local function Defensives()
  if S.ObsidianScales:IsCastable() and Player:BuffDown(S.ObsidianScales) and (Player:HealthPercentage() < Settings.Devastation.ObsidianScalesThreshold) then
    if Cast(S.ObsidianScales, nil, Settings.Commons.DisplayStyle.Defensives) then return "obsidian_scales defensives"; end
  end
end

local function Trinkets()
  -- Note: Leaving this open for future additions. item_cd_1141 has been used for multiple expansions and multiple items.
  local ItemCD1141Ready = false
  if I.DragonfireBombDispenser:IsEquippedAndReady() then
    ItemCD1141Ready = true
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,name=dreambinder_loom_of_the_great_cycle,use_off_gcd=1,if=gcd.remains>0.5
    if I.Dreambinder:IsEquippedAndReady() then
      if Cast(I.Dreambinder, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "dreambinder_loom_of_the_great_cycle trinkets 2"; end
    end
    -- use_item,target_if=min:target.health.pct,name=iridal_the_earths_master,use_off_gcd=1,if=gcd.remains>0.5
    if I.Iridal:IsEquippedAndReady() then
      if Everyone.CastTargetIf(I.Iridal, Enemies25y, "min", EvaluateTargetIfFilterHPPct, nil, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Items) then return "iridal_the_earths_master trinkets 4"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=nymues_unraveling_spindle,if=((buff.emerald_trance_stacking.stack>=2&(variable.has_external_pi))|(cooldown.dragonrage.remains<=3&cooldown.fire_breath.remains<7&cooldown.eternity_surge.remains<13&target.time_to_die>=35&((!variable.has_external_pi&active_enemies<=2)|!set_bonus.tier31_2pc))|(cooldown.dragonrage.remains<=3&active_enemies>=3))|fight_remains<=20
    if I.NymuesUnravelingSpindle:IsEquippedAndReady() and (((Player:BuffStack(S.EmeraldTranceBuff) >= 2 and VarHasExternalPI) or (S.Dragonrage:CooldownRemains() <= 3 and S.FireBreath:CooldownRemains() < 7 and S.EternitySurge:CooldownRemains() < 13 and Target:TimeToDie() >= 35 and ((not VarHasExternalPI and EnemiesCount8ySplash <= 2) or not Player:HasTier(31, 2))) or (S.Dragonrage:CooldownRemains() <= 3 and EnemiesCount8ySplash >= 3)) or FightRemains <- 20) then
      if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle trinkets 6"; end
    end
    -- use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=(gcd.remains>0.5&((trinket.2.cooldown.remains|!variable.trinket_2_buffs)&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|active_enemies<=2)&(trinket.nymues_unraveling_spindle.cooldown.remains|!equipped.nymues_unraveling_spindle))|fight_remains<=20
    -- Note: Slightly modified, as we can't fully handle variable.trinket_x_buffs.
    if I.BelorrelostheSuncaller:IsEquippedAndReady() and (((trinket2:CooldownDown() or not trinket2:HasUseBuff()) and (trinket1:CooldownDown() or not trinket1:HasUseBuff()) or EnemiesCount8ySplash <= 2) and (I.NymuesUnravelingSpindle:CooldownDown() or not I.NymuesUnravelingSpindle:IsEquipped()) or FightRemains <= 20) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller trinkets 8"; end
    end
  end
  -- living_flame,if=buff.burnout.up&((trinket.2.cooldown.remains|!variable.trinket_2_buffs)&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|active_enemies<=2)&equipped.belorrelos_the_suncaller&trinket.belorrelos_the_suncaller.cooldown.remains<=gcd.max&cooldown.item_cd_1141.ready&(trinket.nymues_unraveling_spindle.cooldown.remains|!equipped.nymues_unraveling_spindle)
  if S.LivingFlame:IsReady() and (Player:BuffUp(S.BurnoutBuff) and ((trinket2:CooldownDown() or not trinket2:HasUseBuff()) and (trinket1:CooldownDown() or not trinket1:HasUseBuff()) or EnemiesCount8ySplash <= 2) and I.BelorrelostheSuncaller:IsEquipped() and I.BelorrelostheSuncaller:CooldownRemains() <= GCDMax and ItemCD1141Ready and (I.NymuesUnravelingSpindle:CooldownDown() or not I.NymuesUnravelingSpindle:IsEquipped())) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame trinkets 10"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&((trinket.2.cooldown.remains|!variable.trinket_2_buffs)&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|active_enemies<=2)&equipped.belorrelos_the_suncaller&trinket.belorrelos_the_suncaller.cooldown.remains<=gcd.max&cooldown.item_cd_1141.ready&(trinket.nymues_unraveling_spindle.cooldown.remains|!equipped.nymues_unraveling_spindle)
  if Settings.Devastation.UseGreen and (S.AncientFlame:IsAvailable() and ((trinket2:CooldownDown() or not trinket2:HasUseBuff()) and (trinket1:CooldownDown() or not trinket1:HasUseBuff()) or EnemiesCount8ySplash <= 2) and I.BelorrelostheSuncaller:IsEquipped() and I.BelorrelostheSuncaller:CooldownRemains() <= GCDMax and ItemCD1141Ready and (I.NymuesUnravelingSpindle:CooldownDown() or not I.NymuesUnravelingSpindle:IsEquipped())) then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- azure_strike,if=equipped.belorrelos_the_suncaller&((trinket.2.cooldown.remains|!variable.trinket_2_buffs)&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|active_enemies<=2)&trinket.belorrelos_the_suncaller.cooldown.remains<=gcd.max&cooldown.item_cd_1141.ready&(trinket.nymues_unraveling_spindle.cooldown.remains|!equipped.nymues_unraveling_spindle)
  if S.AzureStrike:IsReady() and (I.BelorrelostheSuncaller:IsEquipped() and ((trinket2:CooldownDown() or not trinket2:HasUseBuff()) and (trinket1:CooldownDown() or not trinket1:HasUseBuff()) or EnemiesCount8ySplash <= 2) and I.BelorrelostheSuncaller:CooldownRemains() <= GCDMax and ItemCD1141Ready and (I.NymuesUnravelingSpindle:CooldownDown() or not I.NymuesUnravelingSpindle:IsEquipped())) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike trinkets 12"; end
  end
  -- use_item,slot=trinket1,if=buff.dragonrage.up&((buff.emerald_trance_stacking.stack>=4&set_bonus.tier31_2pc)|(variable.trinket_2_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&!equipped.nymues_unraveling_spindle&trinket.2.cooldown.remains)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up&!set_bonus.tier31_2pc)|active_enemies>=3)&(!trinket.2.has_cooldown|trinket.2.cooldown.remains|variable.trinket_priority=1|variable.trinket_2_exclude)&!variable.trinket_1_manual|trinket.1.proc.any_dps.duration>=fight_remains|trinket.1.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=1)
  -- use_item,slot=trinket2,if=buff.dragonrage.up&((buff.emerald_trance_stacking.stack>=4&set_bonus.tier31_2pc)|(variable.trinket_1_buffs&!cooldown.fire_breath.up&!cooldown.shattering_star.up&!equipped.nymues_unraveling_spindle&trinket.1.cooldown.remains)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up&!set_bonus.tier31_2pc)|active_enemies>=3)&(!trinket.1.has_cooldown|trinket.1.cooldown.remains|variable.trinket_priority=2|variable.trinket_1_exclude)&!variable.trinket_2_manual|trinket.2.proc.any_dps.duration>=fight_remains|trinket.2.cooldown.duration<=60&(variable.next_dragonrage>20|!talent.dragonrage)&(!buff.dragonrage.up|variable.trinket_priority=2)
  -- use_item,slot=trinket1,if=!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)&(variable.next_dragonrage>20|!talent.dragonrage)&!variable.trinket_1_manual
  -- use_item,slot=trinket2,if=!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)&(variable.next_dragonrage>20|!talent.dragonrage)&!variable.trinket_2_manual
  -- Note: Can't handle above trinket tracking, so let's use a generic fallback. When we can do above tracking, the below can be removed.
  -- use_items,if=buff.dragonrage.up|variable.next_dragonrage>20|!talent.dragonrage
  if (VarDragonrageUp or VarNextDragonrage > 20 or not S.Dragonrage:IsAvailable()) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
end

local function ES()
  if S.EternitySurge:CooldownDown() then return nil end
  local ESEmpower = 0
  -- eternity_surge,empower_to=1,target_if=max:target.health.pct,if=active_enemies<=1+talent.eternitys_span|buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste|buff.dragonrage.up&(active_enemies==5|!talent.eternitys_span&active_enemies>=6|talent.eternitys_span&active_enemies>=8)
  if (EnemiesCount8ySplash <= 1 + num(S.EternitysSpan:IsAvailable()) or VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= 1 * PlayerHaste or VarDragonrageUp and (EnemiesCount8ySplash == 5 or not S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash >= 6 or S.EternitysSpan:IsAvailable() and EnemiesCount8ySplash >= 8)) then
    ESEmpower = 1
  -- eternity_surge,empower_to=2,target_if=max:target.health.pct,if=active_enemies<=2+2*talent.eternitys_span|buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste
  elseif (EnemiesCount8ySplash <= 2 + 2 * num(S.EternitysSpan:IsAvailable()) or VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste) then
    ESEmpower = 2
  -- eternity_surge,empower_to=3,target_if=max:target.health.pct,if=active_enemies<=3+3*talent.eternitys_span|!talent.font_of_magic|buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste
  elseif (EnemiesCount8ySplash <= 3 + 3 * num(S.EternitysSpan:IsAvailable()) or not S.FontofMagic:IsAvailable() or VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste) then
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
  -- fire_breath,empower_to=1,target_if=max:target.health.pct,if=(buff.dragonrage.up&active_enemies<=2)|(active_enemies=1&!talent.everburning_flame)|(buff.dragonrage.remains<1.75*spell_haste&buff.dragonrage.remains>=1*spell_haste)
  if ((VarDragonrageUp and EnemiesCount8ySplash <= 2) or (EnemiesCount8ySplash == 1 and not S.EverburningFlame:IsAvailable()) or (VarDragonrageRemains < 1.75 * PlayerHaste and VarDragonrageRemains >= 1 * PlayerHaste)) then
    FBEmpower = 1
  -- fire_breath,empower_to=2,target_if=max:target.health.pct,if=(!debuff.in_firestorm.up&talent.everburning_flame&active_enemies<=3)|(active_enemies=2&!talent.everburning_flame)|(buff.dragonrage.remains<2.5*spell_haste&buff.dragonrage.remains>=1.75*spell_haste)
  elseif ((not InFirestorm() and S.EverburningFlame:IsAvailable() and EnemiesCount8ySplash <= 3) or (EnemiesCount8ySplash == 2 and not S.EverburningFlame:IsAvailable()) or (VarDragonrageRemains < 2.5 * PlayerHaste and VarDragonrageRemains >= 1.75 * PlayerHaste)) then
    FBEmpower = 2
  -- fire_breath,empower_to=3,target_if=max:target.health.pct,if=(talent.everburning_flame&buff.dragonrage.up&active_enemies>=5)|!talent.font_of_magic|(debuff.in_firestorm.up&talent.everburning_flame&active_enemies<=3)|(buff.dragonrage.remains<=3.25*spell_haste&buff.dragonrage.remains>=2.5*spell_haste)
  elseif ((S.EverburningFlame:IsAvailable() and VarDragonrageUp and EnemiesCount8ySplash >= 5) or not S.FontofMagic:IsAvailable() or (InFirestorm() and S.EverburningFlame:IsAvailable() and EnemiesCount8ySplash <= 3) or (VarDragonrageRemains <= 3.25 * PlayerHaste and VarDragonrageRemains >= 2.5 * PlayerHaste)) then
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
  -- shattering_star,target_if=max:target.health.pct,if=cooldown.dragonrage.up
  if S.ShatteringStar:IsCastable() and (S.Dragonrage:CooldownUp()) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 2"; end
  end
  -- dragonrage,if=target.time_to_die>=32|fight_remains<30
  if S.Dragonrage:IsCastable() and CDsON() and (Target:TimeToDie() >= 32 or FightRemains < 30) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage aoe 4"; end
  end
  -- tip_the_scales,if=buff.dragonrage.up&(active_enemies<=3+3*talent.eternitys_span|!cooldown.fire_breath.up)
  if S.TipTheScales:IsCastable() and CDsON() and (VarDragonrageUp and (EnemiesCount8ySplash <= 3 + 3 * num(S.EternitysSpan:IsAvailable()) or S.FireBreath:CooldownDown())) then
    if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales aoe 6"; end
  end
  -- call_action_list,name=fb,if=(!talent.dragonrage|variable.next_dragonrage>variable.dr_prep_time_aoe|!talent.animosity)&((buff.power_swell.remains<variable.r1_cast_time|(!talent.volatility&active_enemies=3))&buff.blazing_shards.remains<variable.r1_cast_time|buff.dragonrage.up)&(target.time_to_die>=8|fight_remains<30)
  if ((not S.Dragonrage:IsAvailable() or VarNextDragonrage > VarDRPrepTimeAoe or not S.Animosity:IsAvailable()) and ((Player:BuffRemains(S.PowerSwellBuff) < VarR1CastTime or (not S.Volatility:IsAvailable() and EnemiesCount8ySplash == 3)) and Player:BuffRemains(S.BlazingShardsBuff) < VarR1CastTime or VarDragonrageUp) and (Target:TimeToDie() >= 8 or FightRemains < 30)) then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=es,if=buff.dragonrage.up|!talent.dragonrage|(cooldown.dragonrage.remains>variable.dr_prep_time_aoe&(buff.power_swell.remains<variable.r1_cast_time|(!talent.volatility&active_enemies=3))&buff.blazing_shards.remains<variable.r1_cast_time)&(target.time_to_die>=8|fight_remains<30)
  if (VarDragonrageUp or not S.Dragonrage:IsAvailable() or (S.Dragonrage:CooldownRemains() > VarDRPrepTimeAoe and (Player:BuffRemains(S.PowerSwellBuff) < VarR1CastTime or (not S.Volatility:IsAvailable() and EnemiesCount8ySplash == 3)) and Player:BuffRemains(S.BlazingShardsBuff) < VarR1CastTime) and (Target:TimeToDie() >= 8 or FightRemains < 30)) then
    local ShouldReturn = ES(); if ShouldReturn then return ShouldReturn; end
  end
  -- deep_breath,if=!buff.dragonrage.up&essence.deficit>3
  if S.DeepBreath:IsCastable() and CDsON() and (not VarDragonrageUp and Player:EssenceDeficit() > 3) then
    if Cast(S.DeepBreath, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath aoe 8"; end
  end
  -- shattering_star,target_if=max:target.health.pct,if=buff.essence_burst.stack<buff.essence_burst.max_stack|!talent.arcane_vigor
  if S.ShatteringStar:IsCastable() and (Player:BuffStack(S.EssenceBurstBuff) < MaxEssenceBurstStack or not S.ArcaneVigor:IsAvailable()) then
    if Everyone.CastTargetIf(S.ShatteringStar, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star aoe 10"; end
  end
  -- firestorm
  if S.Firestorm:IsCastable() then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm aoe 12"; end
  end
  if S.Pyre:IsReady() and (
    -- pyre,target_if=max:target.health.pct,if=active_enemies>=4
    (EnemiesCount8ySplash >= 4) or
    -- pyre,target_if=max:target.health.pct,if=active_enemies>=3&talent.volatility
    (EnemiesCount8ySplash >= 3 and S.Volatility:IsAvailable()) or
    -- pyre,target_if=max:target.health.pct,if=buff.charged_blast.stack>=15
    (Player:BuffStack(S.ChargedBlastBuff) >= 15)
  ) then
    -- Note: Using Cast instead of CastTargetIf, since we hit all targets anyway.
    if Cast(S.Pyre, nil, nil, not Target:IsSpellInRange(S.Pyre)) then return "pyre aoe 14"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=(!talent.burnout|buff.burnout.up|active_enemies>=4|buff.scarlet_adaptation.up)&buff.leaping_flames.up&!buff.essence_burst.up&essence<essence.max-1
  if S.LivingFlame:IsCastable() and ((not S.Burnout:IsAvailable() or Player:BuffUp(S.BurnoutBuff) or EnemiesCount8ySplash >= 4 or Player:BuffUp(S.ScarletAdaptationBuff)) and Player:BuffUp(S.LeapingFlamesBuff) and Player:BuffDown(S.EssenceBurstBuff) and Player:Essence() < Player:EssenceMax() - 1) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame aoe 18"; end
  end
  -- disintegrate,target_if=max:target.health.pct,chain=1,early_chain_if=evoker.use_early_chaining&ticks>=2&essence.deficit<2&(raid_event.movement.in>2|buff.hover.up),interrupt_if=evoker.use_clipping&buff.dragonrage.up&ticks>=2&(!(buff.power_infusion.up&buff.bloodlust.up)|cooldown.fire_breath.up|cooldown.eternity_surge.up)&(raid_event.movement.in>2|buff.hover.up),if=raid_event.movement.in>2|buff.hover.up
  if S.Disintegrate:IsReady() then
    if Everyone.CastTargetIf(S.Disintegrate, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate aoe 22"; end
  end
  -- living_flame,target_if=max:target.health.pct,if=talent.snapfire&buff.burnout.up
  if S.LivingFlame:IsCastable() and (S.Snapfire:IsAvailable() and Player:BuffUp(S.BurnoutBuff)) then
    if Everyone.CastTargetIf(S.LivingFlame, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame aoe 24"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&!buff.ancient_flame.up&!buff.dragonrage.up
  if Settings.Devastation.UseGreen and S.AncientFlame:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and not VarDragonrageUp then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- azure_strike,target_if=max:target.health.pct
  -- Note: Since this is a filler, going to use both Cast and CastTargetIf.
  if S.AzureStrike:IsCastable() then
    if Everyone.CastTargetIf(S.AzureStrike, Enemies8ySplash, "max", EvaluateTargetIfFilterHPPct, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike cti aoe 26"; end
  end
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike aoe 28"; end
  end
end

local function ST()
  -- use_item,name=kharnalex_the_first_light,if=!buff.dragonrage.up&debuff.shattering_star_debuff.down&raid_event.movement.in>6
  if Settings.Commons.Enabled.Items and I.KharnalexTheFirstLight:IsEquippedAndReady() and (not VarDragonrageUp and Target:DebuffDown(S.ShatteringStar)) then
    if Cast(I.KharnalexTheFirstLight, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(25)) then return "kharnalex_the_first_light st 2"; end
  end
  -- hover,use_off_gcd=1,if=raid_event.movement.in<2&!buff.hover.up
  -- Note: Not handling movement ability.
  -- firestorm,if=buff.snapfire.up
  if S.Firestorm:IsCastable() and (Player:BuffUp(S.SnapfireBuff)) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 4"; end
  end
  -- dragonrage,if=cooldown.fire_breath.remains<4&cooldown.eternity_surge.remains<10&target.time_to_die>=32|fight_remains<30
  if S.Dragonrage:IsCastable() and CDsON() and (S.FireBreath:CooldownRemains() < GCDMax and S.EternitySurge:CooldownRemains() < 2 * GCDMax or FightRemains < 30) then
    if Cast(S.Dragonrage, Settings.Devastation.GCDasOffGCD.Dragonrage) then return "dragonrage st 6"; end
  end
  -- tip_the_scales,if=buff.dragonrage.up&(((!talent.font_of_magic|talent.everburning_flame)&cooldown.fire_breath.up&!cooldown.eternity_surge.up&buff.dragonrage.remains<14)|(cooldown.eternity_surge.up&!cooldown.fire_breath.up&!talent.everburning_flame&talent.font_of_magic))
  if S.TipTheScales:IsCastable() and CDsON() and (VarDragonrageUp and (((not S.FontofMagic:IsAvailable() or S.EverburningFlame:IsAvailable()) and S.FireBreath:CooldownUp() and S.EternitySurge:CooldownDown() and VarDragonrageRemains < 14) or (S.EternitySurge:CooldownUp() and S.FireBreath:CooldownDown() and not S.EverburningFlame and S.FontofMagic:IsAvailable()))) then
    if Cast(S.TipTheScales, Settings.Commons.GCDasOffGCD.TipTheScales) then return "tip_the_scales st 8"; end
  end
  -- call_action_list,name=fb,if=(!talent.dragonrage|variable.next_dragonrage>variable.dr_prep_time_st|!talent.animosity)&((buff.power_swell.remains<variable.r1_cast_time|buff.bloodlust.up|buff.power_infusion.up|buff.dragonrage.up)&(buff.blazing_shards.remains<variable.r1_cast_time|buff.dragonrage.up))&(!cooldown.eternity_surge.up|!talent.event_horizon|!buff.dragonrage.up)&(target.time_to_die>=8|fight_remains<30)
  if (not S.Dragonrage:IsAvailable() or VarNextDragonrage > VarDRPrepTimeST or not S.Animosity:IsAvailable()) and ((Player:BuffRemains(S.PowerSwellBuff) < VarR1CastTime or Player:BloodlustUp() or Player:PowerInfusionUp() or VarDragonrageUp) and (Player:BuffRemains(S.BlazingShardsBuff) < VarR1CastTime or VarDragonrageUp)) and (S.EternitySurge:CooldownDown() or not S.EventHorizon:IsAvailable() or not VarDragonrageUp) and (Target:TimeToDie() >= 8 or FightRemains < 30) then
    local ShouldReturn = FB(); if ShouldReturn then return ShouldReturn; end
  end
  -- disintegrate,if=buff.dragonrage.remains>19&cooldown.fire_breath.remains>28&talent.eye_of_infinity&set_bonus.tier30_2pc
  if S.Disintegrate:IsReady() and (VarDragonrageRemains > 19 and S.FireBreath:CooldownRemains() > 28 and S.EyeofInfinity:IsAvailable() and Player:HasTier(30, 2)) then
    if Cast(S.Disintegrate, nil, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate st 9"; end
  end
  -- shattering_star,if=(buff.essence_burst.stack<buff.essence_burst.max_stack|!talent.arcane_vigor)&(!cooldown.fire_breath.up|!talent.event_horizon)
  if S.ShatteringStar:IsCastable() and ((Player:BuffStack(S.EssenceBurstBuff) < MaxEssenceBurstStack or not S.ArcaneVigor:IsAvailable()) and (S.FireBreath:CooldownDown() or not S.EventHorizon:IsAvailable())) then
    if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) and (VarDragonrageUp and (not (Player:PowerInfusionUp() and Player:BloodlustUp()) or S.FireBreath:CooldownUp() or S.EternitySurge:CooldownUp())) then
      if CastAnnotated(S.ShatteringStar, nil, "CLIP", not Target:IsSpellInRange(S.ShatteringStar), Settings.Commons.DisintegrateFontSize) then return "shattering_star clip st 10"; end
    else
      if Cast(S.ShatteringStar, nil, nil, not Target:IsSpellInRange(S.ShatteringStar)) then return "shattering_star st 10"; end
    end
  end
  -- call_action_list,name=es,if=(!talent.dragonrage|variable.next_dragonrage>variable.dr_prep_time_st|!talent.animosity)&((buff.power_swell.remains<variable.r1_cast_time|buff.bloodlust.up|buff.power_infusion.up)&(buff.blazing_shards.remains<variable.r1_cast_time|buff.dragonrage.up))&(target.time_to_die>=8|fight_remains<30)
  if (not S.Dragonrage:IsAvailable() or VarNextDragonrage > VarDRPrepTimeST or not S.Animosity:IsAvailable()) and ((Player:BuffRemains(S.PowerSwellBuff) < VarR1CastTime or Player:BloodlustUp() or Player:PowerInfusionUp()) and (Player:BuffRemains(S.BlazingShardsBuff) < VarR1CastTime or VarDragonrageUp)) and (Target:TimeToDie() >= 8 or FightRemains < 30) then
    local ShouldReturn = ES(); if ShouldReturn then return ShouldReturn; end
  end
  -- wait,sec=cooldown.fire_breath.remains,if=talent.animosity&buff.dragonrage.up&buff.dragonrage.remains<gcd.max+variable.r1_cast_time*buff.tip_the_scales.down&buff.dragonrage.remains-cooldown.fire_breath.remains>=variable.r1_cast_time*buff.tip_the_scales.down
  if (S.Animosity:IsAvailable() and VarDragonrageUp and VarDragonrageRemains < GCDMax + VarR1CastTime * num(Player:BuffDown(S.TipTheScales)) and VarDragonrageRemains - S.FireBreath:CooldownRemains() >= VarR1CastTime * num(Player:BuffDown(S.TipTheScales))) then
    if CastPooling(S.Pool, S.FireBreath:CooldownRemains(), "WAIT") then return "Wait for FB st 12"; end
  end
  -- wait,sec=cooldown.eternity_surge.remains,if=talent.animosity&buff.dragonrage.up&buff.dragonrage.remains<gcd.max+variable.r1_cast_time&buff.dragonrage.remains-cooldown.eternity_surge.remains>variable.r1_cast_time*buff.tip_the_scales.down
  if (S.Animosity:IsAvailable() and VarDragonrageUp and VarDragonrageRemains < GCDMax + VarR1CastTime and VarDragonrageRemains - S.EternitySurge:CooldownRemains() > VarR1CastTime * num(Player:BuffDown(S.TipTheScales))) then
    if CastPooling(S.Pool, S.EternitySurge:CooldownRemains(), "WAIT") then return "Wait for ES st 14"; end
  end
  -- living_flame,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max&buff.burnout.up
  if S.LivingFlame:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (MaxEssenceBurstStack - Player:BuffStack(S.EssenceBurstBuff)) * GCDMax and Player:BuffUp(S.BurnoutBuff)) then
    if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) and (VarDragonrageUp and (not (Player:PowerInfusionUp() and Player:BloodlustUp()) or S.FireBreath:CooldownUp() or S.EternitySurge:CooldownUp())) then
      if CastAnnotated(S.LivingFlame, nil, "CLIP", not Target:IsSpellInRange(S.LivingFlame), Settings.Commons.DisintegrateFontSize) then return "living_flame clip st 16"; end
    else
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame st 16"; end
    end
  end
  -- azure_strike,if=buff.dragonrage.up&buff.dragonrage.remains<(buff.essence_burst.max_stack-buff.essence_burst.stack)*gcd.max
  if S.AzureStrike:IsCastable() and (VarDragonrageUp and VarDragonrageRemains < (MaxEssenceBurstStack - Player:BuffStack(S.EssenceBurstBuff)) * GCDMax) then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike st 18"; end
  end
  -- living_flame,if=buff.burnout.up&(buff.leaping_flames.up&!buff.essence_burst.up|!buff.leaping_flames.up&buff.essence_burst.stack<buff.essence_burst.max_stack)&essence.deficit>=2
  if S.LivingFlame:IsCastable() and (Player:BuffUp(S.BurnoutBuff) and (Player:BuffUp(S.LeapingFlamesBuff) and Player:BuffDown(S.EssenceBurstBuff) or Player:BuffDown(S.LeapingFlamesBuff) and Player:BuffStack(S.EssenceBurstBuff) < MaxEssenceBurstStack) and Player:EssenceDeficit() >= 2) then
    if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) and (VarDragonrageUp and (not (Player:PowerInfusionUp() and Player:BloodlustUp()) or S.FireBreath:CooldownUp() or S.EternitySurge:CooldownUp())) then
      if CastAnnotated(S.LivingFlame, nil, "CLIP", not Target:IsSpellInRange(S.LivingFlame), Settings.Commons.DisintegrateFontSize) then return "living_flame clip st 20"; end
    else
      if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame st 20"; end
    end
  end
  -- pyre,if=debuff.in_firestorm.up&talent.raging_inferno&buff.charged_blast.stack==20&active_enemies>=2
  if S.Pyre:IsReady() and (InFirestorm() and S.RagingInferno:IsAvailable() and Player:BuffStack(S.ChargedBlastBuff) == 20 and EnemiesCount8ySplash >= 2) then
    if Cast(S.Pyre, nil, nil, not Target:IsSpellInRange(S.Pyre)) then return "pyre st 22"; end
  end
  -- disintegrate,chain=1,early_chain_if=evoker.use_early_chaining&ticks>=2&essence.deficit<2&(raid_event.movement.in>2|buff.hover.up),interrupt_if=evoker.use_clipping&buff.dragonrage.up&ticks>=2&(!(buff.power_infusion.up&buff.bloodlust.up)|cooldown.fire_breath.up|cooldown.eternity_surge.up)&(raid_event.movement.in>2|buff.hover.up),if=raid_event.movement.in>2|buff.hover.up
  if S.Disintegrate:IsReady() then
    if Settings.Devastation.ShowChainClip and Player:IsChanneling(S.Disintegrate) then
      local DisNote = "NO CHAIN"
      if Player:EssenceDeficit() < 2 then
        DisNote = "CHAIN"
      end
      if CastAnnotated(S.Disintegrate, nil, DisNote, not Target:IsSpellInRange(S.Disintegrate), Settings.Commons.DisintegrateFontSize) then return "disintegrate st 24"; end
    else
      if Cast(S.Disintegrate, nil, nil, not Target:IsSpellInRange(S.Disintegrate)) then return "disintegrate st 25"; end
    end
  end
  -- firestorm,if=!buff.dragonrage.up&debuff.shattering_star_debuff.down
  if S.Firestorm:IsCastable() and (not VarDragonrageUp and Target:DebuffDown(S.ShatteringStar)) then
    if Cast(S.Firestorm, nil, nil, not Target:IsInRange(25)) then return "firestorm st 26"; end
  end
  -- deep_breath,if=!buff.dragonrage.up&active_enemies>=2&((raid_event.adds.in>=120&!talent.onyx_legacy)|(raid_event.adds.in>=60&talent.onyx_legacy))
  -- Note: We have no way to track when adds will spawn, so ignoring that portion.
  if S.DeepBreath:IsCastable() and CDsON() and (not VarDragonrageUp and EnemiesCount8ySplash >= 2) then
    if Cast(S.DeepBreath, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath st 28"; end
  end
  -- deep_breath,if=!buff.dragonrage.up&talent.imminent_destruction&!debuff.shattering_star_debuff.up
  if S.DeepBreath:IsCastable() and CDsON() and (not VarDragonrageUp and S.ImminentDestruction:IsAvailable() and Target:DebuffDown(S.ShatteringStar)) then
    if Cast(S.DeepBreath, Settings.Devastation.GCDasOffGCD.DeepBreath, nil, not Target:IsInRange(50)) then return "deep_breath st 30"; end
  end
  -- call_action_list,name=green,if=talent.ancient_flame&!buff.ancient_flame.up&!buff.shattering_star_debuff.up&talent.scarlet_adaptation&!buff.dragonrage.up
  if Settings.Devastation.UseGreen and (S.AncientFlame:IsAvailable() and Player:BuffDown(S.AncientFlameBuff) and Target:DebuffDown(S.ShatteringStar) and S.ScarletAdaptation:IsAvailable() and not VarDragonrageUp) then
    local ShouldReturn = Green(); if ShouldReturn then return ShouldReturn; end
  end
  -- living_flame,if=!buff.dragonrage.up|(buff.iridescence_red.remains>execute_time|buff.iridescence_blue.up)&active_enemies==1
  -- Note: Added moving check to allow fallthru to azure_strike.
  if S.LivingFlame:IsCastable() and not Player:IsMoving() and (not VarDragonrageUp or (Player:BuffRemains(S.IridescenceRedBuff) > S.LivingFlame:ExecuteTime() or Player:BuffUp(S.IridescenceBlueBuff)) and EnemiesCount8ySplash == 1) then
    if Cast(S.LivingFlame, nil, nil, not Target:IsSpellInRange(S.LivingFlame)) then return "living_flame st 32"; end
  end
  -- azure_strike
  if S.AzureStrike:IsCastable() then
    if Cast(S.AzureStrike, nil, nil, not Target:IsSpellInRange(S.AzureStrike)) then return "azure_strike st 34"; end
  end
end

-- APL Main
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

  -- Set GCDMax (add 0.25 seconds for latency/player reaction)
  GCDMax = Player:GCD() + 0.25

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
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    -- variable,name=next_dragonrage,value=cooldown.dragonrage.remains<?(cooldown.eternity_surge.remains-2*gcd.max)<?(cooldown.fire_breath.remains-gcd.max)
    VarNextDragonrage = mathmax(S.Dragonrage:CooldownRemains(), (S.EternitySurge:CooldownRemains() - 2 * GCDMax), (S.FireBreath:CooldownRemains() - GCDMax))
    -- invoke_external_buff,name=power_infusion,if=buff.dragonrage.up&((buff.emerald_trance_stacking.stack>=3&set_bonus.tier31_2pc)|(!cooldown.fire_breath.up&!cooldown.shattering_star.up&!set_bonus.tier31_2pc))
    -- Note: Not handling external buffs.
    -- quell,use_off_gcd=1,if=target.debuff.casting.react
    local ShouldReturn = Everyone.Interrupt(S.Quell, Settings.Commons.OffGCDasOffGCD.Quell, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Unravel if enemy has an absorb shield
    if S.Unravel:IsReady() and Target:EnemyAbsorb() then
      if Cast(S.Unravel, Settings.Commons.GCDasOffGCD.Unravel, nil, not Target:IsSpellInRange(S.Unravel)) then return "unravel main 4"; end
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
  HR.Print("Devastation Evoker rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(1467, APL, Init);
