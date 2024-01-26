--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC                   = HeroDBC.DBC
-- HeroLib
local HL                    = HeroLib
local Cache                 = HeroCache
local Unit                  = HL.Unit
local Player                = Unit.Player
local Target                = Unit.Target
local Pet                   = Unit.Pet
local Spell                 = HL.Spell
local Item                  = HL.Item
-- HeroRotation
local HR                    = HeroRotation
local AoEON                 = HR.AoEON
local CDsON                 = HR.CDsON
local Cast                  = HR.Cast
local CastSuggested         = HR.CastSuggested
-- Num/Bool Helper Functions
local num                   = HR.Commons.Everyone.num
local bool                  = HR.Commons.Everyone.bool
-- lua
local mathmin               = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Shadow
local I = Item.Priest.Shadow

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.BeacontotheBeyond:ID(),
  I.BelorrelostheSuncaller:ID(),
  I.DesperateInvokersCodex:ID(),
  I.DMDDance:ID(),
  I.DMDDanceBox:ID(),
  I.DMDInferno:ID(),
  I.DMDInfernoBox:ID(),
  I.DMDRime:ID(),
  I.DMDRimeBox:ID(),
  I.EruptingSpearFragment:ID(),
  I.NymuesUnravelingSpindle:ID(),
  I.VoidmendersShadowgem:ID(),
}

-- Rotation Var
local Enemies40y, Enemies10ySplash
local EnemiesCount10ySplash

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Priest.Commons,
  Shadow = HR.GUISettings.APL.Priest.Shadow
}

-- Variables
local BossFightRemains = 11111
local FightRemains = 11111
local VarDotsUp = false
local VarAllDotsUp = false
local VarMaxVTs = 0
local VarIsVTPossible = false
local VarVTsApplied = false
local VarHoldingCrash = false
local VarManualVTsApplied = false
local VarPoolForCDs = false
local VarPreferVT = false
local Fiend = (S.Mindbender:IsAvailable()) and S.Mindbender or S.Shadowfiend
local VarFiendUp = false
local VarFiendRemains = 0
local VarOpened = false
local VarFirstTar = nil
local Flay
local GCDMax

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
  VarDotsUp = false
  VarAllDotsUp = false
  VarMindSearCutoff = 2
  VarPoolAmount = 60
  VarMaxVTs = 0
  VarIsVTPossible = false
  VarVTsApplied = false
  VarHoldingCrash = false
  VarManualVTsApplied = false
  VarPoolForCDs = false
  VarPreferVT = false
  VarFiendUp = false
  VarFiendRemains = 0
  VarOpened = false
  VarFirstTar = nil
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  Fiend = (S.Mindbender:IsAvailable()) and S.Mindbender or S.Shadowfiend
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

HL:RegisterForEvent(function()
  S.ShadowCrash:RegisterInFlightEffect(205386)
  S.ShadowCrash:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ShadowCrash:RegisterInFlightEffect(205386)
S.ShadowCrash:RegisterInFlight()

local function ComputeDPPmultiplier()
  local Value = 1
  if Player:BuffUp(S.DarkAscensionBuff) then Value = Value * 1.25 end
  if Player:BuffUp(S.DarkEvangelismBuff) then Value = Value * (1 + (0.01 * Player:BuffStack(S.DarkEvangelismBuff))) end
  if Player:BuffUp(S.DevouredFearBuff) or Player:BuffUp(S.DevouredPrideBuff) then Value = Value * 1.05 end
  if S.DistortedReality:IsAvailable() then Value = Value * 1.2 end
  if Player:BuffUp(S.MindDevourerBuff) then Value = Value * 1.2 end
  if S.Voidtouched:IsAvailable() then Value = Value * 1.06 end
  return Value
end
S.DevouringPlague:RegisterPMultiplier(S.DevouringPlagueDebuff, ComputeDPPmultiplier)

local function DotsUp(tar, all)
  if all then
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff) and tar:DebuffUp(S.DevouringPlagueDebuff))
  else
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff))
  end
end

local function HighestTTD(enemies, checkVT)
  if not enemies then return nil end
  local HighTTD = 0
  local HighTTDTar = nil
  for _, enemy in pairs(enemies) do
    local TTD = enemy:TimeToDie()
    if checkVT then
      if TTD * num(enemy:DebuffRefreshable(S.VampiricTouchDebuff)) > HighTTD then
        HighTTD = TTD
        HighTTDTar = enemy
      end
    else
      if TTD > HighTTD then
        HighTTD = TTD
        HighTTDTar = enemy
      end
    end
  end
  return HighTTDTar
end

-- CastTargetIf Filter Functions
local function EvaluateTargetIfFilterDPRemains(TargetUnit)
  -- target_if=max:dot.devouring_plague.remains
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff))
end

local function EvaluateTargetIfFilterDPTTD(TargetUnit)
  -- target_if=max:target.time_to_die*(!dot.devouring_plague.ticking)
  return (TargetUnit:DebuffDown(S.DevouringPlagueDebuff)) and TargetUnit:TimeToDie() or 0
end

local function EvaluateTargetIfFilterSWP(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.ShadowWordPainDebuff))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return (TargetUnit:TimeToDie())
end

local function EvaluateTargetIfFilterVTRemains(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.VampiricTouchDebuff))
end

-- CastTargetIf Condition Functions
local function EvaluateTargetIfMindBlastAoE(TargetUnit)
  -- if=(cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>cast_time&active_enemies<=7&!buff.mind_devourer.up&dot.devouring_plague.remains>execute_time
  -- Note: All but debuff check handled before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) > S.MindBlast:ExecuteTime())
end

local function EvaluateTargetIfMSIFiller(TargetUnit)
  -- if=dot.devouring_plague.remains>cast_time
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) > S.MindSpikeInsanity:CastTime())
end

local function EvaluateTargetIfVTMain(TargetUnit)
  -- target_if=min:remains,if=refreshable&target.time_to_die>=12&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight|variable.holding_crash|!talent.whispering_shadows)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 12 and (S.ShadowCrash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) and not S.ShadowCrash:InFlight() or VarHoldingCrash or not S.WhisperingShadows:IsAvailable()))
end

-- CastCycle Functions
local function EvaluateCycleDP(TargetUnit)
  -- target_if=!talent.distorted_reality|active_enemies=1|remains<=gcd.max,if=remains<=gcd.max|insanity.deficit<=16
  return (not S.DistortedReality:IsAvailable() or EnemiesCount10ySplash == 1 or TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) <= GCDMax or Player:InsanityDeficit() <= 16)
end

local function EvaluateCycleMindBlastMain(TargetUnit)
  -- target_if=dot.devouring_plague.remains>execute_time&(cooldown.mind_blast.full_recharge_time<=gcd.max+execute_time)|pet.fiend.remains<=execute_time+gcd.max
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) > S.MindBlast:ExecuteTime() and (S.MindBlast:FullRechargeTime() <= GCDMax + S.MindBlast:ExecuteTime()) or VarFiendRemains <= S.MindBlast:ExecuteTime() + GCDMax)
end

local function EvaluateCycleShadowCrashAoE(TargetUnit)
  -- target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) or TargetUnit:DebuffRemains(S.VampiricTouchDebuff) <= TargetUnit:TimeToDie() and Player:BuffDown(S.VoidformBuff))
end

local function EvaluateCycleSWDFiller(TargetUnit)
  -- target_if=target.health.pct<20|(buff.deathspeaker.up|set_bonus.tier31_2pc)&dot.devouring_plague.ticking
  return (TargetUnit:HealthPercentage() < 20 or (Player:BuffUp(S.DeathspeakerBuff) or Player:HasTier(31, 2)) and TargetUnit:DebuffUp(S.DevouringPlagueDebuff))
end

local function EvaluateCycleSWDFiller2(TargetUnit)
  -- if=target.health.pct<20
  return (TargetUnit:HealthPercentage() < 20)
end

local function EvaluateCycleSWDMain(TargetUnit)
  -- target_if=dot.devouring_plague.ticking&pet.fiend.remains<=2&pet.fiend.active&talent.inescapable_torment&active_enemies<=7
  return (TargetUnit:DebuffUp(S.DevouringPlagueDebuff) and VarFiendRemains <= 2 and VarFiendUp and S.InescapableTorment:IsAvailable() and EnemiesCount10ySplash <= 7)
end

local function EvaluateCycleVoidTorrentMain(TargetUnit)
  -- target_if=dot.devouring_plague.remains>=2.5
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= 2.5)
end

local function EvaluateCycleVTAoE(TargetUnit)
  -- target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp))
end

local function EvaluateCycleVTAoE2(TargetUnit)
  -- target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up),if=variable.max_vts>0&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash)&!action.shadow_crash.in_flight|!talent.whispering_shadows
  if VarMaxVTs > 0 and (S.ShadowCrash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) or VarHoldingCrash) and not S.ShadowCrash:InFlight() or not S.WhisperingShadows:IsAvailable() then
    return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp))
  else
    return false
  end
end

local function Precombat()
  VarFirstTar = Target:GUID()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.PowerWordFortitude:IsCastable() and Everyone.GroupBuffMissing(S.PowerWordFortitudeBuff) then
    if Cast(S.PowerWordFortitude, Settings.Commons.GCDasOffGCD.PowerWordFortitude) then return "power_word_fortitude precombat 2"; end
  end
  -- shadowform,if=!buff.shadowform.up
  if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
    if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform precombat 4"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent precombat 6"; end
  end
  -- shadow_crash,if=raid_event.adds.in>=25&spell_targets.shadow_crash<=8&!fight_style.dungeonslice&(!set_bonus.tier31_4pc|spell_targets.shadow_crash>1)
  -- Note: Can't do target counts in Precombat
  local DungeonSlice = Player:IsInParty() and Player:IsInDungeonArea() and not Player:IsInRaidArea()
  if S.ShadowCrash:IsCastable() and (not DungeonSlice) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash precombat 8"; end
  end
  -- vampiric_touch,if=!talent.shadow_crash.enabled|raid_event.adds.in<25|spell_targets.shadow_crash>8|fight_style.dungeonslice|set_bonus.tier31_4pc&spell_targets.shadow_crash=1
  -- Note: Manually added VT suggestion if Shadow Crash is on CD and wasn't just used.
  if S.VampiricTouch:IsCastable() and (not S.ShadowCrash:IsAvailable() or (S.ShadowCrash:CooldownDown() and not S.ShadowCrash:InFlight()) or DungeonSlice) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch precombat 10"; end
  end
  -- Manually added: shadow_word_pain,if=!talent.misery.enabled
  if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain precombat 12"; end
  end
end

local function AoEVariables()
  -- variable,name=max_vts,op=set,default=12,value=spell_targets.vampiric_touch>?12
  VarMaxVTs = mathmin(EnemiesCount10ySplash, 12)
  -- variable,name=is_vt_possible,op=set,value=0,default=1
  VarIsVTPossible = false
  -- variable,name=is_vt_possible,op=set,value=1,target_if=max:(target.time_to_die*dot.vampiric_touch.refreshable),if=target.time_to_die>=18
  local HighTTDTar = HighestTTD(Enemies10ySplash, true)
  if HighTTDTar and HighTTDTar:TimeToDie() >= 18 then
    VarIsVTPossible = true
  end
  -- variable,name=dots_up,op=set,value=(active_dot.vampiric_touch+8*(action.shadow_crash.in_flight&talent.whispering_shadows))>=variable.max_vts|!variable.is_vt_possible
  VarDotsUp = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable())) >= VarMaxVTs or not VarIsVTPossible)
  -- variable,name=holding_crash,op=set,value=(variable.max_vts-active_dot.vampiric_touch)<4|raid_event.adds.in<10&raid_event.adds.count>(variable.max_vts-active_dot.vampiric_touch),if=variable.holding_crash&talent.whispering_shadows
  if VarHoldingCrash and S.WhisperingShadows:IsAvailable() then
    VarHoldingCrash = (VarMaxVTs - S.VampiricTouchDebuff:AuraActiveCount()) < 4
  end
  -- variable,name=manual_vts_applied,op=set,value=(active_dot.vampiric_touch+8*!variable.holding_crash)>=variable.max_vts|!variable.is_vt_possible
  VarManualVTsApplied = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(not VarHoldingCrash)) >= VarMaxVTs or not VarIsVTPossible)
end

local function Trinkets()
  -- use_item,name=voidmenders_shadowgem,if=(buff.power_infusion.up|fight_remains<20)&equipped.voidmenders_shadowgem
  if Settings.Commons.Enabled.Trinkets and I.VoidmendersShadowgem:IsEquippedAndReady() and (Player:PowerInfusionUp() or FightRemains < 20) then
    if Cast(I.VoidmendersShadowgem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "voidmenders_shadowgem trinkets 2"; end
  end
  if Settings.Commons.Enabled.Items then
    -- use_item,name=iridal_the_earths_master,use_off_gcd=1,if=gcd.remains>0|fight_remains<20
    if I.Iridal:IsEquippedAndReady() then
      if Cast(I.Iridal, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(40)) then return "iridal_the_earths_master trinkets 4"; end
    end
    -- use_item,name=dreambinder_loom_of_the_great_cycle,use_off_gcd=1,if=gcd.remains>0|fight_remains<20
    if I.Dreambinder:IsEquippedAndReady() then
      if Cast(I.Dreambinder, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder trinkets 6"; end
    end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=darkmoon_deck_box_inferno,if=equipped.darkmoon_deck_box_inferno
    if I.DMDInferno:IsEquippedAndReady() then
      if Cast(I.DMDInferno, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_inferno trinkets 8"; end
    end
    if I.DMDInfernoBox:IsEquippedAndReady() then
      if Cast(I.DMDInfernoBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_inferno_box trinkets 10"; end
    end
    -- use_item,name=darkmoon_deck_box_rime,if=equipped.darkmoon_deck_box_rime
    if I.DMDRime:IsEquippedAndReady() then
      if Cast(I.DMDRime, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_rime trinkets 12"; end
    end
    if I.DMDRimeBox:IsEquippedAndReady() then
      if Cast(I.DMDRimeBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_rime_box trinkets 14"; end
    end
    -- use_item,name=darkmoon_deck_box_dance,if=equipped.darkmoon_deck_box_dance
    if I.DMDDance:IsEquippedAndReady() then
      if Cast(I.DMDDance, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_dance trinkets 16"; end
    end
    if I.DMDDanceBox:IsEquippedAndReady() then
      if Cast(I.DMDDanceBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_dance_box trinkets 18"; end
    end
    -- use_item,name=erupting_spear_fragment,if=(buff.power_infusion.up|raid_event.adds.up|fight_remains<20)&equipped.erupting_spear_fragment
    if I.EruptingSpearFragment:IsEquippedAndReady() and (Player:PowerInfusionUp() or FightRemains < 20) then
      if Cast(I.EruptingSpearFragment, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment trinkets 20"; end
    end
    -- use_item,name=beacon_to_the_beyond,if=(!raid_event.adds.exists|raid_event.adds.up|spell_targets.beacon_to_the_beyond>=5|fight_remains<20)&equipped.beacon_to_the_beyond
    if I.BeacontotheBeyond:IsEquippedAndReady() then
      if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond trinkets 22"; end
    end
  end
  -- use_items,if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|(cooldown.void_eruption.remains>10&trinket.cooldown.duration<=60)|fight_remains<20
  if (Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionUp() or Player:BuffUp(S.DarkAscensionBuff) or FightRemains < 20) then
    local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
    if ItemToUse then
      local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
      if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
      if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
        if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
      end
    end
  end
  -- use_item,name=desperate_invokers_codex,if=equipped.desperate_invokers_codex
  if Settings.Commons.Enabled.Trinkets and I.DesperateInvokersCodex:IsEquippedAndReady() then
    if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets) then return "desperate_invokers_codex trinkets 24"; end
  end
end

local function Opener()
  -- shadow_crash,if=!debuff.vampiric_touch.up
  if S.ShadowCrash:IsCastable() and not VarPreferVT and (Target:DebuffDown(S.VampiricTouchDebuff)) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash opener 2"; end
  end
  -- vampiric_touch,if=!debuff.vampiric_touch.up&(!cooldown.shadow_crash.ready|!talent.shadow_crash)
  if S.VampiricTouch:IsCastable() and (Target:DebuffDown(S.VampiricTouchDebuff) and (S.ShadowCrash:CooldownDown() or not S.ShadowCrash:IsAvailable() or S.ShadowCrash:InFlight())) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch opener 3"; end
  end
  -- mindbender
  if Fiend:IsCastable() then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender opener 4"; end
  end
  -- dark_ascension,if=talent.dark_ascension
  if S.DarkAscension:IsCastable() then
    if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension opener 6"; end
  end
  if S.VoidEruption:IsAvailable() then
    -- shadow_word_death,if=talent.inescapable_torment&talent.void_eruption&prev_gcd.mind_blast
    -- Note: 20+ seconds since last cast, since we only want one cast during the opener.
    if S.ShadowWordDeath:IsCastable() and S.InescapableTorment:IsAvailable() and Player:PrevGCDP(1, S.MindBlast) and S.ShadowWordDeath:TimeSinceLastCast() > 20 then
      if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death opener 8"; end
    end
    -- mind_blast,if=talent.void_eruption
    if S.MindBlast:IsCastable() then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast opener 10"; end
    end
    -- void_eruption,if=talent.void_eruption
    if S.VoidEruption:IsCastable() then
      if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption opener 12"; end
    end
  end
  -- power_infusion,if=buff.voidform.up|buff.dark_ascension.up
  if CDsON() and S.PowerInfusion:IsCastable() and Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscension)) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion opener 14"; end
  end
  -- use_items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- void_bolt,if=talent.void_eruption
  if S.VoidBolt:IsCastable() then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt opener 16"; end
  end
  -- devouring_plague
  if S.DevouringPlague:IsReady() then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague opener 18"; end
  end
  -- Note: Just in case there is not enough Insanity for devouring_plague...
  -- mind_blast
  if S.MindBlast:IsCastable() then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast opener 20"; end
  end
  -- mind_spike
  if S.MindSpike:IsCastable() then
    if Cast(S.MindSpike, nil, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_spike opener 22"; end
  end
  -- mind_flay
  if S.MindFlay:IsCastable() then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay opener 24"; end
  end
end

local function CDs()
  -- potion,if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up&(fight_remains<=cooldown.power_infusion.remains+15)|fight_remains<=30
  -- Note: The "fight_remains<=30" seems to be for dps sniping the end of a boss fight, so using BossFightRemains instead of FightRemains.
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionUp() or Player:BuffUp(S.DarkAscensionBuff) and (FightRemains <= S.PowerInfusion:CooldownRemains() + 15) or BossFightRemains <= 30) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 2"; end
    end
  end
  -- fireblood,if=buff.power_infusion.up|fight_remains<=8
  if S.Fireblood:IsCastable() and (Player:PowerInfusionUp() or FightRemains <= 8) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 4"; end
  end
  -- berserking,if=buff.power_infusion.up|fight_remains<=12
  if S.Berserking:IsCastable() and (Player:PowerInfusionUp() or FightRemains <= 12) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 6"; end
  end
  -- blood_fury,if=buff.power_infusion.up|fight_remains<=15
  if S.BloodFury:IsCastable() and (Player:PowerInfusionUp() or FightRemains <= 15) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
  end
  -- ancestral_call,if=buff.power_infusion.up|fight_remains<=15
  if S.AncestralCall:IsCastable() and (Player:PowerInfusionUp() or FightRemains <= 15) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=nymues_unraveling_spindle,if=variable.dots_up&(fight_remains<30|target.time_to_die>15)&(!talent.dark_ascension|cooldown.dark_ascension.remains<3+gcd.max|fight_remains<15)
    if I.NymuesUnravelingSpindle:IsEquippedAndReady() and (VarDotsUp and (FightRemains < 30 or Target:TimeToDie() > 15) and (not S.DarkAscension:IsAvailable() or S.DarkAscension:CooldownRemains() < 3 + GCDMax or FightRemains < 15)) then
      if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle cds 12"; end
    end
    -- use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=gcd.remains>0&(!raid_event.adds.exists&!prev_gcd.1.mindbender|raid_event.adds.up|spell_targets.belorrelos_the_suncaller>=5)|fight_remains<20
    if I.BelorrelostheSuncaller:IsEquippedAndReady() and ((EnemiesCount10ySplash == 1 and Player:PrevGCDP(1, S.Mindbender) or EnemiesCount10ySplash >= 1) or FightRemains < 20) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller cds 14"; end
    end
  end
  -- divine_star,if=(raid_event.adds.up|spell_targets.belorrelos_the_suncaller>=5)&equipped.belorrelos_the_suncaller&trinket.belorrelos_the_suncaller.cooldown.remains<=gcd.max
  if S.DivineStar:IsReady() and (EnemiesCount10ySplash > 1 and I.BelorrelostheSuncaller:IsEquipped() and I.BelorrelostheSuncaller:CooldownRemains() <= GCDMax) then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar, not Target:IsInRange(30)) then return "divine_star cds 16"; end
  end
  -- power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)
  if S.PowerInfusion:IsCastable() and Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscension)) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion cds 18"; end
  end
  -- invoke_external_buff,name=power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)&!buff.power_infusion.up
  -- Note: Not handling external buffs
  -- void_eruption,if=!cooldown.fiend.up&(pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender|active_enemies>2&!talent.inescapable_torment.rank)&(cooldown.mind_blast.charges=0|time>15)
  if S.VoidEruption:IsCastable() and (Fiend:CooldownDown() and (VarFiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) and (S.MindBlast:Charges() == 0 or HL.CombatTime() > 15)) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption cds 20"; end
  end
  -- dark_ascension,if=pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment
  if S.DarkAscension:IsCastable() and not Player:IsCasting(S.DarkAscension) and (VarFiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) then
    if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension cds 22"; end
  end
  -- call_action_list,name=trinkets
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- desperate_prayer,if=health.pct<=75
  if S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer) then return "desperate_prayer cds 24"; end
  end
end

local function Filler()
  -- vampiric_touch,target_if=min:remains,if=buff.unfurling_darkness.up
  if S.VampiricTouch:IsCastable() and (Player:BuffUp(S.UnfurlingDarknessBuff)) then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies40y, "min", EvaluateTargetIfFilterVTRemains, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch filler 2"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20|(buff.deathspeaker.up|set_bonus.tier31_2pc)&dot.devouring_plague.ticking
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDFiller, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 4"; end
  end
  -- mind_spike_insanity,target_if=max:dot.devouring_plague.remains,if=dot.devouring_plague.remains>cast_time
  if S.MindSpikeInsanity:IsReady() then
    if Everyone.CastTargetIf(S.MindSpikeInsanity, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, EvaluateTargetIfMSIFiller, not Target:IsSpellInRange(S.MindSpikeInsanity)) then return "mind_spike_insanity filler 6"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,if=buff.mind_flay_insanity.up
  if S.MindFlay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff)) then
    if Everyone.CastTargetIf(S.MindSpike, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_flay filler 8"; end
  end
  -- mindgames,target_if=max:dot.devouring_plague.remains
  if S.Mindgames:IsReady() then
    if Everyone.CastTargetIf(S.Mindgames, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Signature) then return "mindgames filler 10"; end
  end
  -- shadow_word_death,target_if=min:target.time_to_die,if=talent.inescapable_torment&pet.fiend.active
  if S.ShadowWordDeath:IsReady() and (S.InescapableTorment:IsAvailable() and VarFiendUp) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "min", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 12"; end
  end
  -- halo,if=spell_targets>1
  if S.Halo:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo filler 14"; end
  end
  -- mind_spike,target_if=max:dot.devouring_plague.remains
  if S.MindSpike:IsCastable() then
    if Everyone.CastTargetIf(S.MindSpike, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_spike filler 16"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if Flay:IsCastable() then
    if Everyone.CastTargetIf(Flay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay filler 18"; end
  end
  -- divine_star
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar, not Target:IsInRange(30)) then return "divine_star filler 20"; end
  end
  -- shadow_crash,if=raid_event.adds.in>20&!set_bonus.tier31_4pc
  if S.ShadowCrash:IsCastable() and (not Player:HasTier(31, 4)) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash filler 22"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDFiller2, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 24"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains
  -- Note: Per APL note, intent is to be used as a movement filler.
  if S.ShadowWordDeath:IsReady() and Player:IsMoving() then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death movement filler 26"; end
  end
  -- shadow_word_pain,target_if=max:dot.devouring_plague.remains,if=set_bonus.tier31_4pc
  -- Note: Per APL note, intent is to be used as a movement filler.
  if S.ShadowWordPain:IsReady() and Player:IsMoving() and (Player:HasTier(31, 4)) then
    if Everyone.CastTargetIf(S.ShadowWordPain, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain filler 30"; end
  end
  -- shadow_word_pain,target_if=min:remains,if=!set_bonus.tier31_4pc
  -- Note: Per APL note, intent is to be used as a movement filler.
  if S.ShadowWordPain:IsReady() and Player:IsMoving() and (not Player:HasTier(31, 4)) then
    if Everyone.CastTargetIf(S.ShadowWordPain, Enemies40y, "min", EvaluateTargetIfFilterSWP, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain filler 32"; end
  end
end

local function AoE()
  -- call_action_list,name=aoe_variables
  AoEVariables()
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up),if=variable.max_vts>0&!variable.manual_vts_applied&!action.shadow_crash.in_flight|!talent.whispering_shadows
  if S.VampiricTouch:IsCastable() and (VarMaxVTs > 0 and not VarManualVTsApplied and not S.ShadowCrash:InFlight() or not S.WhisperingShadows:IsAvailable()) then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 2"; end
  end
  -- shadow_crash,if=!variable.holding_crash,target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  if S.ShadowCrash:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(S.ShadowCrash, Enemies40y, EvaluateCycleShadowCrashAoE, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash aoe 4"; end
  end
  -- call_action_list,name=cds,if=fight_remains<30|target.time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if CDsON() and (FightRemains < 30 or Target:TimeToDie() > 15 and (not VarHoldingCrash or EnemiesCount10ySplash > 2)) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=(dot.shadow_word_pain.ticking&variable.dots_up|action.shadow_crash.in_flight&talent.whispering_shadows)&(fight_remains<30|target.time_to_die>15)&(!talent.dark_ascension|cooldown.dark_ascension.remains<gcd.max|fight_remains<15)
  if Fiend:IsCastable() and ((Target:DebuffUp(S.ShadowWordPainDebuff) and VarDotsUp or S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable()) and (FightRemains < 30 or Target:TimeToDie() > 15) and (not S.DarkAscension:IsAvailable() or S.DarkAscension:CooldownRemains() < GCDMax or FightRemains < 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender aoe 6"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(!dot.devouring_plague.ticking),if=talent.distorted_reality&(active_dot.devouring_plague=0|insanity.deficit<=20)
  if S.DevouringPlague:IsReady() and (S.DistortedReality:IsAvailable() and (S.DevouringPlagueDebuff:AuraActiveCount() == 0 or Player:InsanityDeficit() <= 20)) then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies40y, "max", EvaluateTargetIfFilterDPTTD, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague aoe 8"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains,if=(set_bonus.tier31_4pc|pet.fiend.active&talent.inescapable_torment&set_bonus.tier31_2pc)
  if S.ShadowWordDeath:IsReady() and (Player:HasTier(31, 4) or VarFiendUp and S.InescapableTorment:IsAvailable() and Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death aoe 10"; end
  end
  -- mind_blast,target_if=max:dot.devouring_plague.remains,if=(cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>cast_time&active_enemies<=7&!buff.mind_devourer.up&dot.devouring_plague.remains>execute_time
  if S.MindBlast:IsCastable() and ((S.MindBlast:FullRechargeTime() <= GCDMax + S.MindBlast:CastTime() or VarFiendRemains <= S.MindBlast:CastTime() + GCDMax) and VarFiendUp and S.InescapableTorment:IsAvailable() and VarFiendRemains > S.MindBlast:CastTime() and EnemiesCount10ySplash <= 7 and Player:BuffDown(S.MindDevourerBuff)) then
    if Everyone.CastTargetIf(S.MindBlast, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, EvaluateTargetIfMindBlastAoE, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast aoe 12"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains,if=pet.fiend.remains<=2&pet.fiend.active&talent.inescapable_torment&active_enemies<=7
  if S.ShadowWordDeath:IsReady() and (VarFiendRemains <= 2 and VarFiendUp and S.InescapableTorment:IsAvailable() and EnemiesCount10ySplash <= 7) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death aoe 14"; end
  end
  -- void_bolt,target_if=max:target.time_to_die
  if S.VoidBolt:IsCastable() then
    if Everyone.CastTargetIf(S.VoidBolt, Enemies40y, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(40)) then return "void_bolt aoe 16"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(!dot.devouring_plague.ticking),if=talent.distorted_reality
  if S.DevouringPlague:IsReady() and (S.DistortedReality:IsAvailable()) then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies40y, "max", EvaluateTargetIfFilterDPTTD, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague aoe 18"; end
  end
  -- devouring_plague,if=(remains<=gcd.max&!variable.pool_for_cds|insanity.deficit<=20|buff.voidform.up&cooldown.void_bolt.remains>buff.voidform.remains&cooldown.void_bolt.remains<=buff.voidform.remains+2)&!talent.distorted_reality
  if S.DevouringPlague:IsReady() and ((Target:DebuffRemains(S.DevouringPlagueDebuff) <= GCDMax and not VarPoolForCDs or Player:InsanityDeficit() <= 20 or Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownRemains() > Player:BuffRemains(S.VoidformBuff) and S.VoidBolt:CooldownRemains() <= Player:BuffRemains(S.VoidformBuff) + 2) and not S.DistortedReality:IsAvailable()) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague aoe 20"; end
  end
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up),if=variable.max_vts>0&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash)&!action.shadow_crash.in_flight|!talent.whispering_shadows
  if S.VampiricTouch:IsCastable() then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE2, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 22"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains,if=variable.dots_up&talent.inescapable_torment&pet.fiend.active&((!talent.insidious_ire&!talent.idol_of_yoggsaron)|buff.deathspeaker.up)&!set_bonus.tier31_2pc
  if S.ShadowWordDeath:IsReady() and (VarDotsUp and S.InescapableTorment:IsAvailable() and VarFiendUp and ((not S.InsidiousIre:IsAvailable() and not S.IdolOfYoggSaron) or Player:BuffUp(S.DeathspeakerBuff)) and not Player:HasTier(31, 2)) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death aoe 24"; end
  end
  -- mind_spike_insanity,target_if=max:dot.devouring_plague.remains,if=variable.dots_up&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if S.MindSpikeInsanity:IsReady() and (VarDotsUp and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Everyone.CastTargetIf(S.MindSpikeInsanity, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsInRange(40)) then return "mind_spike_insanity aoe 26"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,if=buff.mind_flay_insanity.up&variable.dots_up&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if Flay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff) and VarDotsUp and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Everyone.CastTargetIf(Flay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay aoe 28"; end
  end
  -- mind_blast,target_if=max:dot.devouring_plague.remains,if=variable.dots_up&(!buff.mind_devourer.up|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsCastable() and (VarDotsUp and (Player:BuffDown(S.MindDevourerBuff) or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable())) then
    if Everyone.CastTargetIf(S.MindBlast, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast aoe 30"; end
  end
  -- void_torrent,target_if=max:dot.devouring_plague.remains,if=(!variable.holding_crash|raid_event.adds.count%(active_dot.vampiric_touch+raid_event.adds.count)<1.5)&(dot.devouring_plague.remains>=2.5|buff.voidform.up)
  if S.VoidTorrent:IsCastable() then
    if Everyone.CastTargetIf(S.VoidTorrent, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, EvaluateTargetIfVoidTorrentAoE, not Target:IsSpellInRange(S.VoidTorrent), Settings.Shadow.GCDasOffGCD.VoidTorrent) then return "void_torrent aoe 32"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,if=buff.mind_flay_insanity.up&talent.idol_of_cthun,interrupt_if=ticks>=2,interrupt_immediate=1
  if Flay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff) and S.IdolOfCthun:IsAvailable()) then
    if Everyone.CastTargetIf(Flay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay aoe 34"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function Main()
  -- Reset variable.holding_crash to false for ST, in case it was set to true during AoE.
  VarHoldingCrash = false
  -- variable,name=dots_up,op=set,value=active_dot.vampiric_touch=active_enemies|action.shadow_crash.in_flight&talent.whispering_shadows
  VarDotsUp = S.VampiricTouchDebuff:AuraActiveCount() == EnemiesCount10ySplash or S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable()
  -- call_action_list,name=cds,if=fight_remains<30|target.time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if CDsON() and (FightRemains < 30 or Target:TimeToDie() > 15 and (not VarHoldingCrash or EnemiesCount10ySplash > 2)) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=variable.dots_up&(fight_remains<30|target.time_to_die>15)&(!talent.dark_ascension|cooldown.dark_ascension.remains<gcd.max|fight_remains<15)
  if Fiend:IsCastable() and (VarDotsUp and (FightRemains < 30 or Target:TimeToDie() > 15) and (not S.DarkAscension:IsAvailable() or S.DarkAscension:CooldownRemains() < GCDMax or FightRemains < 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender main 2"; end
  end
  -- devouring_plague,target_if=!talent.distorted_reality|active_enemies=1|remains<=gcd.max,if=remains<=gcd.max|insanity.deficit<=16
  if S.DevouringPlague:IsReady() then
    if Everyone.CastCycle(S.DevouringPlague, Enemies40y, EvaluateCycleDP, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 4"; end
  end
  -- shadow_word_death,if=(set_bonus.tier31_4pc|pet.fiend.active&talent.inescapable_torment&set_bonus.tier31_2pc)&dot.devouring_plague.ticking
  if S.ShadowWordDeath:IsReady() and ((Player:HasTier(31, 4) or VarFiendUp and S.InescapableTorment:IsAvailable() and Player:HasTier(31, 2)) and Target:DebuffUp(S.DevouringPlagueDebuff)) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 6"; end
  end
  -- mind_blast,target_if=dot.devouring_plague.remains>execute_time&(cooldown.mind_blast.full_recharge_time<=gcd.max+execute_time)|pet.fiend.remains<=execute_time+gcd.max,if=pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>execute_time&active_enemies<=7
  if S.MindBlast:IsCastable() and (VarFiendUp and S.InescapableTorment:IsAvailable() and VarFiendRemains > S.MindBlast:ExecuteTime() and EnemiesCount10ySplash <= 7) then
    if Everyone.CastCycle(S.MindBlast, Enemies40y, EvaluateCycleMindBlastMain, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 8"; end
  end
  -- shadow_word_death,target_if=dot.devouring_plague.ticking&pet.fiend.remains<=2&pet.fiend.active&talent.inescapable_torment&active_enemies<=7
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDMain, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 10"; end
  end
  -- void_bolt,if=variable.dots_up
  if S.VoidBolt:IsCastable() and (VarDotsUp) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt main 12"; end
  end
  -- devouring_plague,if=fight_remains<=duration+4
  if S.DevouringPlague:IsReady() and (FightRemains <= S.DevouringPlagueDebuff:BaseDuration() + 4) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 14"; end
  end
  -- devouring_plague,target_if=!talent.distorted_reality|active_enemies=1|remains<=gcd.max,if=(remains<=gcd.max|remains<3&cooldown.void_torrent.up)|insanity.deficit<=20|buff.voidform.up&cooldown.void_bolt.remains>buff.voidform.remains&cooldown.void_bolt.remains<=buff.voidform.remains+2|buff.mind_devourer.up&pmultiplier<1.2
  if S.DevouringPlague:IsReady() and (Player:InsanityDeficit() <= 20 or Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownRemains() > Player:BuffRemains(S.VoidformBuff) and S.VoidBolt:CooldownRemains() <= Player:BuffRemains(S.VoidformBuff) + 2 or Player:BuffUp(S.MindDevourerBuff) and Player:PMultiplier(S.DevouringPlague) < 1.2) then
    if Everyone.CastCycle(S.DevouringPlague, Enemies40y, EvaluateCycleDP, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 16"; end
  end
  -- shadow_word_death,if=set_bonus.tier31_2pc
  if S.ShadowWordDeath:IsReady() and (Player:HasTier(31, 2)) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 18"; end
  end
  -- shadow_crash,if=!variable.holding_crash&(dot.vampiric_touch.refreshable|buff.deaths_torment.stack>9&set_bonus.tier31_4pc)
  if S.ShadowCrash:IsCastable() and not VarPreferVT and (not VarHoldingCrash and (Target:DebuffRefreshable(S.VampiricTouchDebuff) or Player:BuffStack(S.DeathsTormentBuff) > 9 and Player:HasTier(31, 4))) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 20"; end
  end
  -- shadow_word_pain,if=buff.deaths_torment.stack>9&set_bonus.tier31_4pc&(!variable.holding_crash|!talent.shadow_crash)
  if S.ShadowWordPain:IsReady() and (Player:BuffStack(S.DeathsTormentBuff) > 9 and Player:HasTier(31, 4) and (not VarHoldingCrash or not S.ShadowCrash:IsAvailable())) then
    if Cast(S.ShadowWordPain, Settings.Shadow.GCDasOffGCD.ShadowWordPain, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_pain main 22"; end
  end
  -- shadow_word_death,if=variable.dots_up&talent.inescapable_torment&pet.fiend.active&((!talent.insidious_ire&!talent.idol_of_yoggsaron)|buff.deathspeaker.up)&!set_bonus.tier31_2pc
  if S.ShadowWordDeath:IsReady() and (VarDotsUp and S.InescapableTorment:IsAvailable() and VarFiendUp and ((not S.InsidiousIre:IsAvailable() and not S.IdolOfYoggSaron:IsAvailable()) or Player:BuffUp(S.DeathspeakerBuff)) and not Player:HasTier(31, 2)) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 24"; end
  end
  -- vampiric_touch,target_if=min:remains,if=refreshable&target.time_to_die>=12&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight|variable.holding_crash|!talent.whispering_shadows)
  if S.VampiricTouch:IsCastable() then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies40y, "min", EvaluateTargetIfFilterVTRemains, EvaluateTargetIfVTMain, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 26"; end
  end
  -- mind_blast,if=(!buff.mind_devourer.up|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsCastable() and (Player:BuffDown(S.MindDevourerBuff) or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable()) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 28"; end
  end
  -- void_torrent,if=!variable.holding_crash,target_if=dot.devouring_plague.remains>=2.5,interrupt_if=cooldown.shadow_word_death.ready&pet.fiend.active&set_bonus.tier31_2pc
  if S.VoidTorrent:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVoidTorrentMain, not Target:IsSpellInRange(S.VoidTorrent), Settings.Shadow.GCDasOffGCD.VoidTorrent) then return "void_torrent main 30"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies40y = Player:GetEnemiesInRange(40) -- Multiple CastCycle Spells
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

    -- Check our fiend status
    VarFiendUp = Fiend:TimeSinceLastCast() <= 15
    VarFiendRemains = 15 - Fiend:TimeSinceLastCast()
    if VarFiendRemains < 0 then VarFiendRemains = 0 end

    -- If MF:Insanity buff is up, change which flay we use
    Flay = (Player:BuffUp(S.MindFlayInsanityBuff)) and S.MindFlayInsanity or S.MindFlay

    -- Calculate GCDMax for gcd.max
    GCDMax = Player:GCD() + 0.25
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Manually Added: Use Dispersion if dying
    if S.Dispersion:IsCastable() and Player:HealthPercentage() < Settings.Shadow.DispersionHP then
      if Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return "dispersion low_hp"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.Silence, Settings.Commons.OffGCDasOffGCD.Silence, false);
    if ShouldReturn then return ShouldReturn; end
    -- variable,name=holding_crash,op=set,value=raid_event.adds.in<15
    -- Note: We have no way of knowing if adds are coming, so don't ever purposely hold crash
    VarHoldingCrash = false
    VarPreferVT = Settings.Shadow.PreferVTWhenSTinDungeon and EnemiesCount10ySplash == 1 and Player:IsInDungeonArea() and Player:IsInParty() and not Player:IsInRaidArea()
    -- variable,name=pool_for_cds,op=set,value=(cooldown.void_eruption.remains<=gcd.max*3&talent.void_eruption|cooldown.dark_ascension.up&talent.dark_ascension)|talent.void_torrent&talent.psychic_link&cooldown.void_torrent.remains<=4&(!raid_event.adds.exists&spell_targets.vampiric_touch>1|raid_event.adds.in<=5|raid_event.adds.remains>=6&!variable.holding_crash)&!buff.voidform.up
    VarPoolForCDs = ((S.VoidEruption:CooldownRemains() <= Player:GCD() * 3 and S.VoidEruption:IsAvailable() or S.DarkAscension:CooldownUp() and S.DarkAscension:IsAvailable()) or S.VoidTorrent:IsAvailable() and S.PsychicLink:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 4 and Player:BuffDown(S.VoidformBuff))
    -- Manually added: Attempt at an opener
    if VarFirstTar == nil then VarFirstTar = Target:GUID() end
    if VarOpened == false and Settings.Shadow.UseOpener and Target:GUID() == VarFirstTar and not DotsUp(Target, true) then
      local ShouldReturn = Opener(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Opener()"; end
    else
      VarOpened = true
    end
    -- run_action_list,name=aoe,if=active_enemies>2
    if EnemiesCount10ySplash > 2 then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for AoE()"; end
    end
    -- run_action_list,name=main
    local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Main()"; end
  end
end

local function Init()
  S.DevouringPlagueDebuff:RegisterAuraTracking()
  S.VampiricTouchDebuff:RegisterAuraTracking()

  HR.Print("Shadow Priest rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(258, APL, Init)
