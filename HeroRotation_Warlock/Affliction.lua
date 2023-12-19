--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Warlock  = HR.Commons.Warlock

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

-- Spells
local S = Spell.Warlock.Affliction

-- Items
local I = Item.Warlock.Affliction
local OnUseExcludes = {
  I.BelorrelostheSuncaller:ID(),
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- Rotation Variables
local Enemies40y, Enemies10ySplash, EnemiesCount10ySplash
local VarPSUp, VarVTUp, VarVTPSUp, VarSRUp, VarCDDoTsUp, VarHasCDs, VarCDsActive
local VarMinAgony
local SoulRotBuffLength = (Player:HasTier(31, 2)) and 12 or 8
local SoulShards = 0
local BossFightRemains = 11111
local FightRemains = 11111

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  SoulRotBuffLength = (Player:HasTier(31, 2)) and 12 or 8
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function CalcMinAgony(Enemies)
  -- value=dot.agony.remains+(99*!dot.agony.ticking)
  local LowestAgony
  for _, CycleUnit in pairs(Enemies) do
    local UnitAgony = CycleUnit:DebuffRemains(S.AgonyDebuff) + (99 * num(CycleUnit:DebuffDown(S.AgonyDebuff)))
    if LowestAgony == nil or UnitAgony < LowestAgony then
      LowestAgony = UnitAgony
    end
  end
  return LowestAgony or 0
end

local function CanSeed(Enemies)
  if not Enemies or #Enemies == 0 then return false end
  if S.SeedofCorruption:InFlight() or Player:PrevGCDP(1, S.SeedofCorruption) then return false end
  local TotalTargets = 0
  local SeededTargets = 0
  for _, CycleUnit in pairs(Enemies) do
    TotalTargets = TotalTargets + 1
    if CycleUnit:DebuffUp(S.SeedofCorruptionDebuff) then
      SeededTargets = SeededTargets + 1
    end
  end
  return (TotalTargets == SeededTargets)
end

-- CastTargetIf Functions
local function EvaluateTargetIfFilterAgony(TargetUnit)
  -- target_if=remains
  return (TargetUnit:DebuffRemains(S.AgonyDebuff))
end

local function EvaluateTargetIfFilterCorruption(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff))
end

local function EvaluateTargetIfFilterSiphonLife(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff))
end

local function EvaluateTargetIfFilterSoulRot(TargetUnit)
  -- target_if=min:dot.soul_rot.remains
  return (TargetUnit:DebuffRemains(S.SoulRotDebuff))
end

local function EvaluateTargetIfAgony(TargetUnit)
  -- if=active_dot.agony<8&remains<cooldown.vile_taint.remains+action.vile_taint.cast_time&remains<5
  -- Note: active_dot.agony<8 handled before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < TargetUnit:DebuffRemains(S.VileTaintDebuff) + S.VileTaint:CastTime() and TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateTargetIfAgony2(TargetUnit)
  -- if=remains<5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateTargetIfCorruption(TargetUnit)
  -- if=remains<5
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5)
end

local function EvaluateTargetIfSiphonLife(TargetUnit)
  -- if=refreshable
  return (TargetUnit:DebuffRefreshable(S.SiphonLifeDebuff))
end

-- CastCycle Functions
local function EvaluateCycleAgony(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateCycleAgonyRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff))
end

local function EvaluateCycleCorruption(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5)
end

local function EvaluateCycleCorruptionRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.CorruptionDebuff))
end

local function EvaluateCycleDrainSoul(TargetUnit)
  -- if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  -- Note: Non-debuff checks done before CastCycle.
  return (TargetUnit:DebuffStack(S.ShadowEmbraceDebuff) < 3 or TargetUnit:DebuffRemains(S.ShadowEmbraceDebuff) < 3)
end

local function EvaluateCycleSiphonLife(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 5)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet - Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  -- Note: Not adding an option to force the Cleave function yet. Possible future addition?
  -- variable,name=trinket_1_buffs,value=trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.spoils_of_neltharus|trinket.1.is.nymues_unraveling_spindle
  -- variable,name=trinket_2_buffs,value=trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.spoils_of_neltharus|trinket.2.is.nymues_unraveling_spindle
  -- variable,name=trinket_1_buffs_print,op=print,value=variable.trinket_1_buffs
  -- variable,name=trinket_2_buffs_print,op=print,value=variable.trinket_2_buffs
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.belorrelos_the_suncaller|trinket.1.is.timethiefs_gambit
  -- variable,name=trinket_2_manual,value=trinket.2.is.belorrelos_the_suncaller|trinket.2.is.timethiefs_gambit
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.mirror_of_fractured_tomorrows*20)+(trinket.1.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.mirror_of_fractured_tomorrows*20)+(trinket.2.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1+0.5*trinket.2.has_buff.intellect)*(variable.trinket_2_sync)*(1-0.5*(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.ashes_of_the_embersoul)))>((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1+0.5*trinket.1.has_buff.intellect)*(variable.trinket_1_sync)*(1-0.5*(trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.ashes_of_the_embersoul)))
  -- Note: Can't handle some of the above trinket conditions.
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>2
  -- NYI precombat multi target
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt precombat 6"; end
  end
  -- unstable_affliction,if=!talent.soul_swap
  if S.UnstableAffliction:IsReady() and (not S.SoulSwap:IsAvailable()) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 8"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 10"; end
  end
end

local function Variables()
  -- variable,name=ps_up,op=set,value=dot.phantom_singularity.ticking|!talent.phantom_singularity
  VarPSUp = (Target:DebuffUp(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable())
  -- variable,name=vt_up,op=set,value=dot.vile_taint_dot.ticking|!talent.vile_taint
  VarVTUp = (Target:DebuffUp(S.VileTaintDebuff) or not S.VileTaint:IsAvailable())
  -- variable,name=vt_ps_up,op=set,value=dot.vile_taint_dot.ticking|dot.phantom_singularity.ticking|(!talent.vile_taint&!talent.phantom_singularity)
  VarVTPSUp = (Target:DebuffUp(S.VileTaintDebuff) or Target:DebuffUp(S.PhantomSingularityDebuff) or (not S.VileTaint:IsAvailable() and not S.PhantomSingularity:IsAvailable()))
  -- variable,name=sr_up,op=set,value=dot.soul_rot.ticking|!talent.soul_rot
  VarSRUp = (Target:DebuffUp(S.SoulRotDebuff) or not S.SoulRot:IsAvailable())
  -- variable,name=cd_dots_up,op=set,value=variable.ps_up&variable.vt_up&variable.sr_up
  VarCDDoTsUp = (VarPSUp and VarVTUp and VarSRUp)
  -- variable,name=has_cds,op=set,value=talent.phantom_singularity|talent.vile_taint|talent.soul_rot|talent.summon_darkglare
  VarHasCDs = (S.PhantomSingularity:IsAvailable() or S.VileTaint:IsAvailable() or S.SoulRot:IsAvailable() or S.SummonDarkglare:IsAvailable())
  -- variable,name=cds_active,op=set,value=!variable.has_cds|(pet.darkglare.active|(variable.cd_dots_up&cooldown.summon_darkglare.remains>20)|buff.power_infusion.react)
  VarCDsActive = (not VarHasCDs or (HL.GuardiansTable.DarkglareDuration > 0 or (VarCDDoTsUp and S.SummonDarkglare:CooldownRemains() > 20) or Player:PowerInfusionUp()))
end

local function Items()
  -- use_item,use_off_gcd=1,name=belorrelos_the_suncaller,if=((time>20&cooldown.summon_darkglare.remains>20)|(trinket.1.is.belorrelos_the_suncaller&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|trinket.1.is.time_thiefs_gambit))|(trinket.2.is.belorrelos_the_suncaller&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|trinket.2.is.time_thiefs_gambit)))&(!raid_event.adds.exists|raid_event.adds.up|spell_targets.belorrelos_the_suncaller>=5)|fight_remains<20
  if Settings.Commons.Enabled.Trinkets and I.BelorrelostheSuncaller:IsEquippedAndReady() and (((HL.CombatTime() > 20 and S.SummonDarkglare:CooldownRemains() > 20) or (Trinket1:ID() == I.BelorrelostheSuncaller:ID() and (Trinket2:CooldownDown() or Trinket2:Cooldown() == 0 or Trinket1:ID() == I.TimeThiefsGambit:ID())) or (Trinket2:ID() == I.BelorrelostheSuncaller:ID() and (Trinket1:CooldownDown() or Trinket1:Cooldown() == 0 or Trinket2:ID() == I.TimeThiefsGambit:ID()))) or FightRemains < 20) then
    if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller items 2"; end
  end
  -- use_item,slot=trinket1,if=(variable.cds_active)&(variable.trinket_priority=1|variable.trinket_2_exclude|!trinket.2.has_cooldown|(trinket.2.cooldown.remains|variable.trinket_priority=2&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.2.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_1_buffs&!variable.trinket_1_manual|(variable.trinket_1_buff_duration+1>=fight_remains)", "We want to use trinkets with Darkglare. The trinket with highest estimated value, will be used first.
  -- use_item,slot=trinket2,if=(variable.cds_active)&(variable.trinket_priority=2|variable.trinket_1_exclude|!trinket.1.has_cooldown|(trinket.1.cooldown.remains|variable.trinket_priority=1&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.1.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_2_buffs&!variable.trinket_2_manual|(variable.trinket_2_buff_duration+1>=fight_remains)
  -- use_item,name=time_thiefs_gambit,if=variable.cds_active|fight_remains<15|((trinket.1.cooldown.duration<cooldown.summon_darkglare.remains_expected+5)&active_enemies=1)|(active_enemies>1&havoc_active)
  -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)", "If only one on use trinket provied a buff, use the other on cooldown, Or if neither trinket provied a buff, use both on cooldown.
  -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)
  -- use_item,use_off_gcd=1,slot=main_hand
  if Settings.Commons.Enabled.Items then
    local MainHandOnUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandOnUse and MainHandOnUse:IsReady() then
      if Cast(MainHandOnUse, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "Generic use_item for MH " .. MainHandOnUse:Name(); end
    end
  end
  -- Note: Unable to handle some of the new trinket conditions, so using the old generic use_items
  -- use_items,if=variable.cds_active
  if (VarCDsActive) then
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

local function oGCD()
  if VarCDsActive then
    -- potion,if=variable.cds_active
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion ogcd 2"; end
      end
    end
    -- berserking,if=variable.cds_active
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking ogcd 4"; end
    end
    -- blood_fury,if=variable.cds_active
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 6"; end
    end
    -- invoke_external_buff,name=power_infusion,if=variable.cds_active
    -- Note: Not handling external buffs
    -- fireblood,if=variable.cds_active
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood ogcd 8"; end
    end
    -- ancestral_call,if=variable.cds_active
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call ogcd 10"; end
    end
  end
end

local function AoE()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- cycling_variable,name=min_agony,op=min,value=dot.agony.remains+(99*!dot.agony.ticking)
  VarMinAgony = CalcMinAgony(Enemies10ySplash)
  -- haunt,if=debuff.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt aoe 2"; end
  end
  -- vile_taint,if=(talent.souleaters_gluttony.rank=2&(variable.min_agony<1.5|cooldown.soul_rot.remains<=execute_time))|((talent.souleaters_gluttony.rank=1&cooldown.soul_rot.remains<=execute_time))|(talent.souleaters_gluttony.rank=0&(cooldown.soul_rot.remains<=execute_time|cooldown.vile_taint.remains>25))
  if S.VileTaint:IsReady() and ((S.SouleatersGluttony:TalentRank() == 2 and (VarMinAgony < 1.5 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime())) or (S.SouleatersGluttony:TalentRank() == 1 and S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime()) or (not S.SouleatersGluttony:IsAvailable() and (S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or S.VileTaint:CooldownRemains() > 25))) then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint aoe 4"; end
  end
  -- phantom_singularity
  if S.PhantomSingularity:IsCastable() then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity aoe 6"; end
  end
  -- unstable_affliction,if=remains<5
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction aoe 8"; end
  end
  -- siphon_life,target_if=remains<5,if=active_dot.siphon_life<6&cooldown.summon_darkglare.up
  if S.SiphonLife:IsReady() and (S.SiphonLifeDebuff:AuraActiveCount() < 6 and S.SummonDarkglare:CooldownUp()) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 10"; end
  end
  -- soul_rot,if=variable.vt_up&variable.ps_up
  if S.SoulRot:IsReady() and (VarVTUp and VarPSUp) then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot aoe 12"; end
  end
  -- seed_of_corruption,if=dot.corruption.remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)
  if S.SeedofCorruption:IsReady() and (Target:DebuffRemains(S.CorruptionDebuff) < 5 and not (S.SeedofCorruption:InFlight() or Target:DebuffUp(S.SeedofCorruptionDebuff))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 14"; end
  end
  -- corruption,target_if=min:remains,if=remains<5&!talent.seed_of_corruption
  if S.Corruption:IsReady() and (not S.SeedofCorruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption aoe 15"; end
  end
  -- agony,target_if=min:remains,if=active_dot.agony<8&remains<cooldown.vile_taint.remains+action.vile_taint.cast_time&remains<5
  if S.Agony:IsReady() and (S.AgonyDebuff:AuraActiveCount() < 8) then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 16"; end
  end
  -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  -- Note: Not handling Power Infusion
  if CDsON() and S.SummonDarkglare:IsCastable() and (VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare aoe 18"; end
  end
  -- drain_life,target_if=min:dot.soul_rot.remains,if=buff.inevitable_demise.stack>10&buff.soul_rot.up&buff.soul_rot.remains<=gcd.max&!talent.siphon_life
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 10 and Player:BuffUp(S.SoulRot) and Player:BuffRemains(S.SoulRot) <= Player:GCD() + 0.25 and not S.SiphonLife:IsAvailable()) then
    if Everyone.CastTargetIf(S.DrainLife, Enemies40y, "min", EvaluateTargetIfFilterSoulRot, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 19"; end
  end
  -- malefic_rapture,if=buff.umbrafire_kindling.up&(pet.darkglare.active|!talent.doom_blossom)
  if S.MaleficRapture:IsReady() and (Player:BuffUp(S.UmbrafireKindlingBuff) and (HL.GuardiansTable.DarkglareDuration > 0 or not S.DoomBlossom:IsAvailable())) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 20"; end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds
  if S.SeedofCorruption:IsReady() and S.SowTheSeeds:IsAvailable() then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 22"; end
  end
  -- malefic_rapture,if=((cooldown.summon_darkglare.remains>15|soul_shard>3)&!talent.sow_the_seeds)|buff.tormented_crescendo.up
  if S.MaleficRapture:IsReady() and (((S.SummonDarkglare:CooldownRemains() > 15 or SoulShards > 3) and not S.SowTheSeeds:IsAvailable()) or Player:BuffUp(S.TormentedCrescendoBuff)) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 24"; end
  end
  -- drain_life,target_if=min:dot.soul_rot.remains,if=(buff.soul_rot.up|!talent.soul_rot)&buff.inevitable_demise.stack>10
  if S.DrainLife:IsReady() and (Player:BuffUp(S.SoulRot) or not S.SoulRot:IsAvailable()) and Player:BuffStack(S.InevitableDemiseBuff) > 10 then
    if Everyone.CastTargetIf(S.DrainLife, Enemies40y, "min", EvaluateTargetIfFilterSoulRot, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 26"; end
  end
  -- drain_soul,cycle_targets=1,if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff) and S.ShadowEmbrace:IsAvailable()) then
    if Everyone.CastCycle(S.DrainSoul, Enemies40y, EvaluateCycleDrainSoul, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 28"; end
  end
  -- drain_soul,if=buff.nightfall.react
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 30"; end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10|buff.tormented_soul.stack>3&fight_remains<10
  if S.SummonSoulkeeper:IsReady() and (S.SummonSoulkeeper:Count() == 10 or S.SummonSoulkeeper:Count() > 3 and FightRemains < 10) then
    if Cast(S.SummonSoulkeeper) then return "soul_strike aoe 32"; end
  end
  -- siphon_life,target_if=remains<5,if=active_dot.siphon_life<5
  if S.SiphonLife:IsReady() and (S.SiphonLifeDebuff:AuraActiveCount() < 5) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 34"; end
  end
  -- drain_soul,interrupt_global=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 36"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt aoe 38"; end
  end
end

local function Cleave()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  -- Note: Can't handle Power Infusion.
  if CDsON() and S.SummonDarkglare:IsCastable() and (VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare cleave 2"; end
  end
  -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<2&(dot.agony.ticking&dot.corruption.ticking&(!talent.siphon_life|dot.siphon_life.ticking))&(!talent.phantom_singularity|!cooldown.phantom_singularity.ready)&(!talent.vile_taint|!cooldown.vile_taint.ready)&(!talent.soul_rot|!cooldown.soul_rot.ready)|soul_shard>4|buff.umbrafire_kindling.up
  if S.MaleficRapture:IsReady() and (S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < 2 and (Target:DebuffUp(S.AgonyDebuff) and Target:DebuffUp(S.CorruptionDebuff) and (not S.SiphonLife:IsAvailable() or Target:DebuffUp(S.SiphonLifeDebuff))) and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownDown()) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownDown()) or SoulShards > 4 or Player:BuffUp(S.UmbrafireKindlingBuff)) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 4"; end
  end
  -- agony,target_if=min:remains,if=remains<5
  if S.Agony:IsReady() then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony2, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 6"; end
  end
  -- soul_rot,if=(variable.vt_up&variable.ps_up)
  if S.SoulRot:IsReady() and (VarVTUp and VarPSUp) then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot cleave 8"; end
  end
  -- vile_taint,if=(active_dot.agony=2&active_dot.corruption=2&(!talent.siphon_life|active_dot.siphon_life=2))&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&cooldown.soul_rot.remains>=12)
  if S.VileTaint:IsReady() and ((S.AgonyDebuff:AuraActiveCount() == 2 and S.CorruptionDebuff:AuraActiveCount() == 2 and (not S.SiphonLife:IsAvailable() or S.SiphonLifeDebuff:AuraActiveCount() == 2)) and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and S.SoulRot:CooldownRemains() >= 12)) then
    if Cast(S.VileTaint, nil, nil, not Target:IsSpellInRange(S.VileTaint)) then return "vile_taint cleave 10"; end
  end
  -- phantom_singularity,if=(active_dot.agony=2&active_dot.corruption=2&(!talent.siphon_life|active_dot.siphon_life=2))&(talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25)
  if S.PhantomSingularity:IsReady() and ((S.AgonyDebuff:AuraActiveCount() == 2 and S.CorruptionDebuff:AuraActiveCount() == 2 and (not S.SiphonLife:IsAvailable() or S.SiphonLifeDebuff:AuraActiveCount() == 2)) and (S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity cleave 12"; end
  end
  -- unstable_affliction,if=remains<5
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction cleave 14"; end
  end
  -- seed_of_corruption,if=!talent.absolute_corruption&dot.corruption.remains<5&talent.sow_the_seeds&can_seed
  if S.SeedofCorruption:IsReady() and (not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.CorruptionDebuff) < 5 and S.SowTheSeeds:IsAvailable() and CanSeed(Enemies40y)) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption cleave 16"; end
  end
  -- corruption,target_if=min:remains,if=remains<5
  if S.Corruption:IsReady() then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 18"; end
  end
  -- siphon_life,target_if=min:remains,if=refreshable
  if S.SiphonLife:IsReady() then
    if Everyone.CastTargetIf(S.SiphonLife, Enemies40y, "min", EvaluateTargetIfFilterSiphonLife, EvaluateTargetIfSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life cleave 20"; end
  end
  -- haunt,if=debuff.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt cleave 22"; end
  end
  -- phantom_singularity,if=cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25)
  if S.PhantomSingularity:IsReady() and (S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity cleave 24"; end
  end
  -- soul_rot
  if S.SoulRot:IsReady() then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot cleave 26"; end
  end
  -- malefic_rapture,if=soul_shard>4|(talent.tormented_crescendo&buff.tormented_crescendo.stack=1&soul_shard>3)
  if S.MaleficRapture:IsReady() and (SoulShards > 4 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 3)) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 28"; end
  end
  -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<gcd
  if S.MaleficRapture:IsReady() and S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < Player:GCD() then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 30"; end
  end
  -- malefic_rapture,if=!talent.dread_touch&buff.tormented_crescendo.up
  if S.MaleficRapture:IsReady() and not S.DreadTouch:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 32"; end
  end
  -- malefic_rapture,if=variable.cd_dots_up|variable.vt_ps_up
  if S.MaleficRapture:IsReady() and (VarCDDoTsUp or VarVTPSUp) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 34"; end
  end
  -- drain_soul,cycle_targets=1,if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff) and S.ShadowEmbrace:IsAvailable()) then
    if Everyone.CastCycle(S.DrainSoul, Enemies40y, EvaluatecycleDrainSoul, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 36"; end
  end
  -- drain_soul,if=buff.nightfall.react
  if S.DrainSoul:IsReady() and Player:BuffUp(S.NightfallBuff) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 38"; end
  end
  -- shadow_bolt,if=buff.nightfall.react
  if S.ShadowBolt:IsReady() and Player:BuffUp(S.NightfallBuff) then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave 40"; end
  end
  -- malefic_rapture,if=soul_shard>3
  if S.MaleficRapture:IsReady() and (SoulShards > 3) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 42"; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&fight_remains<4
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 44"; end
  end
  -- drain_life,if=buff.soul_rot.up&buff.inevitable_demise.stack>30
  if S.DrainLife:IsReady() and (Player:BuffUp(S.SoulRot) and Player:BuffStack(S.InevitableDemiseBuff) > 30) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 46"; end
  end
  -- agony,target_if=refreshable
  if S.Agony:IsReady() then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefreshable, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 48"; end
  end
  -- corruption,target_if=refreshable
  if S.Corruption:IsCastable() then
    if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRefreshable, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 50"; end
  end
  -- malefic_rapture,if=soul_shard>1
  if S.MaleficRapture:IsReady() and (SoulShards > 1) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 52"; end
  end
  -- drain_soul,interrupt_global=1
  if S.DrainSoul:IsReady() then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 54"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt cleave 56"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount10ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end

    -- SoulShards variable
    SoulShards = Player:SoulShardsP()
  end

  -- summon_pet 
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=cleave,if=active_enemies!=1&active_enemies<3|variable.cleave_apl
    -- Note: Not using variable.cleave_apl to force Cleave for now.
    if (EnemiesCount10ySplash > 1 and EnemiesCount10ySplash < 3) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>2
    if (EnemiesCount10ySplash > 2) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<2&(dot.agony.ticking&dot.corruption.ticking&(!talent.siphon_life|dot.siphon_life.ticking))&(!talent.phantom_singularity|!cooldown.phantom_singularity.ready)&(!talent.vile_taint|!cooldown.vile_taint.ready)&(!talent.soul_rot|!cooldown.soul_rot.ready)
    if S.MaleficRapture:IsReady() and (S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < 2 and (Target:DebuffUp(S.AgonyDebuff) and Target:DebuffUp(S.CorruptionDebuff) and (not S.SiphonLife:IsAvailable() or Target:DebuffUp(S.SiphonLifeDebuff))) and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownDown()) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownDown())) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 2"; end
    end
    -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
    -- Note: Can't predict Power Infusion.
    if S.SummonDarkglare:IsReady() and (VarPSUp and VarVTUp and VarSRUp) then
      if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare main 4"; end
    end
    -- agony,if=remains<5
    if S.Agony:IsCastable() and (Target:DebuffRemains(S.AgonyDebuff) < 5) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 6"; end
    end
    -- unstable_affliction,if=remains<5
    if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 8"; end
    end
    -- corruption,if=refreshable
    if S.Corruption:IsCastable() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 10"; end
    end
    -- siphon_life,if=refreshable
    if S.SiphonLife:IsCastable() and (Target:DebuffRefreshable(S.SiphonLifeDebuff)) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 12"; end
    end
    -- haunt,if=debuff.haunt.remains<3
    if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 14"; end
    end
    -- drain_soul,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 16"; end
    end
    -- shadow_bolt,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.ShadowBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 18"; end
    end
    -- phantom_singularity,if=cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25)
    if S.PhantomSingularity:IsCastable() and (S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 20"; end
    end
    -- vile_taint,if=!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&cooldown.soul_rot.remains>=12
    if S.VileTaint:IsReady() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and S.SoulRot:CooldownRemains() >= 12) then
      if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint main 22"; end
    end
    -- soul_rot,if=(variable.vt_up&(variable.ps_up|talent.souleaters_gluttony.rank!=1))
    if S.SoulRot:IsReady() and (VarVTUp and (VarPSUp or S.SouleatersGluttony:TalentRank() ~= 1)) then
      if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot main 24"; end
    end
    if S.MaleficRapture:IsReady() and (
      -- malefic_rapture,if=soul_shard>4|(talent.tormented_crescendo&buff.tormented_crescendo.stack=1&soul_shard>3)
      (SoulShards > 4 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 3)) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react&!debuff.dread_touch.react
      (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Target:DebuffDown(S.DreadTouchDebuff)) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.stack=2
      (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 2) or
      -- malefic_rapture,if=variable.cd_dots_up|variable.vt_ps_up&soul_shard>1
      (VarCDDoTsUp or VarVTPSUp and SoulShards > 1) or
      -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react
      (S.TormentedCrescendo:IsAvailable() and S.Nightfall:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff))
    ) then
        if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 26"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&fight_remains<4
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life main 28"; end
    end
    -- drain_soul,if=buff.nightfall.react
    if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 30"; end
    end
    -- shadow_bolt,if=buff.nightfall.react
    if S.ShadowBolt:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 32"; end
    end
    -- agony,if=refreshable
    if S.Agony:IsCastable() and (Target:DebuffRefreshable(S.AgonyDebuff)) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 34"; end
    end
    -- corruption,if=refreshable
    if S.Corruption:IsCastable() and (Target:DebuffRefreshable(S.CorruptionDebuff)) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 36"; end
    end
    -- drain_soul,interrupt=1
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 40"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 42"; end
    end
  end
end

local function OnInit()
  S.AgonyDebuff:RegisterAuraTracking()
  S.CorruptionDebuff:RegisterAuraTracking()
  S.SiphonLifeDebuff:RegisterAuraTracking()
  S.UnstableAfflictionDebuff:RegisterAuraTracking()

  HR.Print("Affliction Warlock rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(265, APL, OnInit)