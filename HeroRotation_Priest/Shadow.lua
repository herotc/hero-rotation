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
  I.DesperateInvokersCodex:ID(),
  I.DMDDance:ID(),
  I.DMDDanceBox:ID(),
  I.DMDInferno:ID(),
  I.DMDInfernoBox:ID(),
  I.DMDRime:ID(),
  I.DMDRimeBox:ID(),
  I.EruptingSpearFragment:ID(),
  I.VoidmendersShadowgem:ID(),
}

-- Rotation Var
local Enemies30y, Enemies40y, Enemies10ySplash
local EnemiesCount30y, EnemiesCount10ySplash

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
local Fiend = (S.Mindbender:IsAvailable()) and S.Mindbender or S.Shadowfiend
local VarFiendUp
local VarFiendRemains
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

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return (TargetUnit:TimeToDie())
end

local function EvaluateTargetIfFilterVTRemains(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.VampiricTouchDebuff))
end

local function EvaluateTargetIfSWDFiller(TargetUnit)
  -- if=target.health.pct<20&active_enemies<4|talent.inescapable_torment&pet.fiend.active
  return (TargetUnit:HealthPercentage() < 20 and EnemiesCount10ySplash < 4 or S.InescapableTorment:IsAvailable() and VarFiendUp)
end

local function EvaluateTargetIfSWDFiller2(TargetUnit)
  -- if=target.health.pct<20
  return (TargetUnit:HealthPercentage() < 20)
end

local function EvaluateTargetIfVTMain(TargetUnit)
  -- target_if=min:remains,if=refreshable&target.time_to_die>=12&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight|variable.holding_crash|!talent.whispering_shadows)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 12 and (S.ShadowCrash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) and (not S.ShadowCrash:InFlight()) or VarHoldingCrash or not S.WhisperingShadows:IsAvailable()))
end

local function EvaluateCycleDP(TargetUnit)
  -- target_if=refreshable|!talent.distorted_reality
  return (TargetUnit:DebuffRefreshable(S.DevouringPlagueDebuff) or not S.DistortedReality:IsAvailable())
end

local function EvaluateCycleMindBlastMain(TargetUnit)
  -- target_if=(dot.devouring_plague.ticking&(cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time)|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>cast_time&active_enemies<=7
  return ((TargetUnit:DebuffUp(S.DevouringPlagueDebuff) and (S.MindBlast:FullRechargeTime() <= GCDMax + S.MindBlast:CastTime()) or VarFiendRemains <= S.MindBlast:CastTime() + GCDMax) and VarFiendUp and S.InescapableTorment:IsAvailable() and VarFiendRemains > S.MindBlast:CastTime() and EnemiesCount10ySplash <= 7)
end

local function EvaluateCycleMindGamesMain(TargetUnit)
  -- target_if=variable.all_dots_up&dot.devouring_plague.remains>=cast_time
  return (DotsUp(TargetUnit, true) and TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= S.MindGames:CastTime())
end

local function EvaluateCycleShadowCrashAoE(TargetUnit)
  -- target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) or TargetUnit:DebuffRemains(S.VampiricTouchDebuff) <= TargetUnit:TimeToDie() and Player:BuffDown(S.VoidformBuff))
end

local function EvaluateCycleSWD(TargetUnit)
  -- target_if=target.health.pct<20&(cooldown.fiend.remains>=10|!talent.inescapable_torment)|pet.fiend.active>1&talent.inescapable_torment|buff.deathspeaker.up
  return (TargetUnit:HealthPercentage() < 20 and (Fiend:CooldownRemains() >= 10 or not S.InescapableTorment:IsAvailable()) or VarFiendUp and S.InescapableTorment:IsAvailable() or Player:BuffUp(S.DeathspeakerBuff))
end

local function EvaluateCycleSWPFiller(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.ShadowWordPainDebuff))
end

local function EvaluateCycleVoidTorrentMain(TargetUnit)
  -- target_if=variable.all_dots_up&dot.devouring_plague.remains>=2
  return (DotsUp(TargetUnit, true) and TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= 2)
end

local function EvaluateCycleVTAoE(TargetUnit)
  -- target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarVTsApplied))
end

local function EvaluateCycleVTAoE2(TargetUnit)
  -- target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied)
  -- if=variable.max_vts>0&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash)&!action.shadow_crash.in_flight
  if S.ShadowCrash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) or VarHoldingCrash then
    return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarVTsApplied))
  end
  return nil
end

local function EvaluateCycleVTAoE3(TargetUnit)
  -- target_if=variable.dots_up
  return (DotsUp(TargetUnit, false))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.PowerWordFortitude:IsCastable() and (Player:BuffDown(S.PowerWordFortitudeBuff, true) or Everyone.GroupBuffMissing(S.PowerWordFortitudeBuff)) then
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
  -- shadow_crash,if=raid_event.adds.in>=25&spell_targets.shadow_crash<=8&!fight_style.dungeonslice&(spell_targets.shadow_crash>1|talent.mental_decay)
  -- Note: Can't do target counts in Precombat
  local DungeonSlice = Player:IsInParty() and not Player:IsInRaid()
  if S.ShadowCrash:IsCastable() and (not DungeonSlice) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash precombat 8"; end
  end
  -- vampiric_touch,if=!talent.shadow_crash.enabled|raid_event.adds.in<25|spell_targets.shadow_crash>8|spell_targets.shadow_crash=1&!talent.mental_decay|fight_style.dungeonslice
  -- Note: Manually added VT suggestion if Shadow Crash is on CD and wasn't just used.
  if S.VampiricTouch:IsCastable() and ((not S.ShadowCrash:IsAvailable()) or (S.ShadowCrash:CooldownDown() and not S.ShadowCrash:InFlight()) or DungeonSlice) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch precombat 14"; end
  end
  -- Manually added: shadow_word_pain,if=!talent.misery.enabled
  if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain precombat 16"; end
  end
end

local function MainVariables()
  -- variable,name=dots_up,op=set,value=(dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking)|action.shadow_crash.in_flight&talent.whispering_shadows
  VarDotsUp = DotsUp(Target, false) or S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable()
  -- variable,name=all_dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking&dot.devouring_plague.ticking
  VarAllDotsUp = DotsUp(Target, true)
  -- variable,name=pool_for_cds,op=set,value=(cooldown.void_eruption.remains<=gcd.max*3&talent.void_eruption|cooldown.dark_ascension.up&talent.dark_ascension)|talent.void_torrent&talent.psychic_link&cooldown.void_torrent.remains<=4&(!raid_event.adds.exists&spell_targets.vampiric_touch>1|raid_event.adds.in<=5|raid_event.adds.remains>=6&!variable.holding_crash)&!buff.voidform.up
  VarPoolForCDs = ((S.VoidEruption:CooldownRemains() <= Player:GCD() * 3 and S.VoidEruption:IsAvailable() or S.DarkAscension:CooldownUp() and S.DarkAscension:IsAvailable()) or S.VoidTorrent:IsAvailable() and S.PsychicLink:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 4 and Player:BuffDown(S.VoidformBuff))
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
  -- variable,name=vts_applied,op=set,value=(active_dot.vampiric_touch+8*action.shadow_crash.in_flight)>=variable.max_vts|!variable.is_vt_possible
  VarVTsApplied = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable())) >= VarMaxVTs or not VarIsVTPossible)
  -- variable,name=holding_crash,op=set,value=(variable.max_vts-active_dot.vampiric_touch)<4|raid_event.adds.in<10&raid_event.adds.count>(variable.max_vts-active_dot.vampiric_touch),if=variable.holding_crash&talent.whispering_shadows
  if VarHoldingCrash and S.WhisperingShadows:IsAvailable() then
    VarHoldingCrash = (VarMaxVTs - S.VampiricTouchDebuff:AuraActiveCount()) < 4
  end
  -- variable,name=manual_vts_applied,op=set,value=(active_dot.vampiric_touch+8*!variable.holding_crash)>=variable.max_vts|!variable.is_vt_possible
  VarManualVTsApplied = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(not VarHoldingCrash)) >= VarMaxVTs or not VarIsVTPossible)
end

local function Trinkets()
  -- use_item,name=voidmenders_shadowgem,if=buff.power_infusion.up|fight_remains<20
  if I.VoidmendersShadowgem:IsEquippedAndReady() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains < 20) then
    if Cast(I.VoidmendersShadowgem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "voidmenders_shadowgem trinkets 2"; end
  end
  -- use_item,name=darkmoon_deck_box_inferno
  if I.DMDInferno:IsEquippedAndReady() then
    if Cast(I.DMDInferno, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_inferno trinkets 4"; end
  end
  if I.DMDInfernoBox:IsEquippedAndReady() then
    if Cast(I.DMDInfernoBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_inferno_box trinkets 6"; end
  end
  -- use_item,name=darkmoon_deck_box_rime
  if I.DMDRime:IsEquippedAndReady() then
    if Cast(I.DMDRime, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_rime trinkets 8"; end
  end
  if I.DMDRimeBox:IsEquippedAndReady() then
    if Cast(I.DMDRimeBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_rime_box trinkets 10"; end
  end
  -- use_item,name=darkmoon_deck_box_dance
  if I.DMDDance:IsEquippedAndReady() then
    if Cast(I.DMDDance, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_dance trinkets 12"; end
  end
  if I.DMDDanceBox:IsEquippedAndReady() then
    if Cast(I.DMDDanceBox, nil, Settings.Commons.DisplayStyle.Trinkets) then return "dmd_dance_box trinkets 14"; end
  end
  -- use_item,name=erupting_spear_fragment,if=buff.power_infusion.up|raid_event.adds.up|fight_remains<20
  if I.EruptingSpearFragment:IsEquippedAndReady() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains < 20) then
    if Cast(I.EruptingSpearFragment, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "erupting_spear_fragment trinkets 16"; end
  end
  -- use_item,name=beacon_to_the_beyond,if=!raid_event.adds.exists|raid_event.adds.up|spell_targets.beacon_to_the_beyond>=5|fight_remains<20
  if I.BeacontotheBeyond:IsEquippedAndReady() then
    if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond trinkets 18"; end
  end
  -- use_items,if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|(cooldown.void_eruption.remains>10&trinket.cooldown.duration<=60)|fight_remains<20
  if (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or Player:BuffUp(S.DarkAscensionBuff) or FightRemains < 20) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  -- use_item,name=desperate_invokers_codex
  if I.DesperateInvokersCodex:IsEquippedAndReady() then
    if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets) then return "desperate_invokers_codex trinkets 20"; end
  end
end

local function Filler()
  -- vampiric_touch,target_if=min:remains,if=buff.unfurling_darkness.up
  if S.VampiricTouch:IsCastable() and (Player:BuffUp(S.UnfurlingDarknessBuff)) then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies40y, "min", EvaluateTargetIfFilterVTRemains, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch filler 2"; end
  end
  -- mind_spike_insanity
  if S.MindSpikeInsanity:IsReady() then
    if Cast(S.MindSpikeInsanity, nil, nil, not Target:IsSpellInRange(S.MindSpikeInsanity)) then return "mind_spike_insanity filler 4"; end
  end
  -- mind_flay,if=buff.mind_flay_insanity.up
  if S.MindFlay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff)) then
    if Cast(S.MindSpike, nil, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_flay filler 6"; end
  end
  -- halo,if=raid_event.adds.in>20
  if S.Halo:IsReady() then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo filler 10"; end
  end
  -- shadow_word_death,target_if=min:target.time_to_die,if=target.health.pct<20&active_enemies<4|talent.inescapable_torment&pet.fiend.active
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "min", EvaluateTargetIfFilterTTD, EvaluateTargetIfSWDFiller, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 12"; end
  end
  -- divine_star,if=raid_event.adds.in>10
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar, nil, not Target:IsInRange(30)) then return "divine_star filler 14"; end
  end
  -- devouring_plague,if=buff.voidform.up&variable.dots_up
  if S.DevouringPlague:IsReady() and (Player:BuffUp(S.VoidformBuff) and VarDotsUp) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague filler 16"; end
  end
  -- mind_spike
  if S.MindSpike:IsCastable() then
    if Cast(S.MindSpike, nil, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_spike filler 18"; end
  end
  -- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if Flay:IsCastable() then
    if Cast(Flay, nil, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay filler 20"; end
  end
  -- shadow_crash,if=raid_event.adds.in>20
  if S.ShadowCrash:IsCastable() then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash filler 22"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateTargetIfSWDFiller2, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 22"; end
  end
  -- divine_star
  -- Note: Handled in above divine_star line, as we're not checking raid_event.adds.in
  -- shadow_word_death
  -- Note: APL comments reference using this while moving
  if S.ShadowWordDeath:IsReady() and Player:IsMoving() then
    if Cast(S.ShadowWordDeath, nil, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death movement filler 24"; end
  end
  -- shadow_word_pain,target_if=min:remains
  if S.ShadowWordPain:IsReady() then
    if Everyone.CastCycle(S.ShadowWordPain, Enemies40y, EvaluateCycleSWPFiller, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain filler 26"; end
  end
end

local function CDs()
  -- potion,if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up&(fight_remains<=cooldown.power_infusion.remains+15)|fight_remains<=30
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or Player:BuffUp(S.DarkAscensionBuff) and (FightRemains <= S.PowerInfusion:CooldownRemains() + 15) or FightRemains <= 30) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion cds 2"; end
    end
  end
  -- fireblood,if=buff.power_infusion.up|fight_remains<=8
  if S.Fireblood:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 8) then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood cds 4"; end
  end
  -- berserking,if=buff.power_infusion.up|fight_remains<=12
  if S.Berserking:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 12) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking cds 6"; end
  end
  -- blood_fury,if=buff.power_infusion.up|fight_remains<=15
  if S.BloodFury:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 15) then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
  end
  -- ancestral_call,if=buff.power_infusion.up|fight_remains<=15
  if S.AncestralCall:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 15) then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
  end
  -- power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)
  if S.PowerInfusion:IsCastable() and Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscension)) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion cds 12"; end
  end
  -- invoke_external_buff,name=power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)&!buff.power_infusion.up
  -- Note: Not handling external buffs
  -- void_eruption,if=!cooldown.fiend.up&(pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender|active_enemies>2&talent.inescapable_torment.rank<2)&(cooldown.mind_blast.charges=0|time>15|buff.shadowy_insight.up&cooldown.mind_blast.charges=buff.shadowy_insight.stack)
  if S.VoidEruption:IsCastable() and (Fiend:CooldownDown() and (VarFiendUp and Fiend:CooldownRemains() >= 4 or (not S.Mindbender:IsAvailable()) or EnemiesCount10ySplash > 2 and S.InescapableTorment:TalentRank() < 2) and (S.MindBlast:Charges() == 0 or HL.CombatTime() > 15 or Player:BuffUp(S.ShadowyInsightBuff) and S.MindBlast:Charges() == Player:BuffStack(S.ShadowyInsightBuff))) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption cds 14"; end
  end
  -- dark_ascension,if=pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&talent.inescapable_torment.rank<2
  if S.DarkAscension:IsCastable() and (not Player:IsCasting(S.DarkAscension)) and (VarFiendUp and Fiend:CooldownRemains() >= 4 or (not S.Mindbender:IsAvailable()) and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and S.InescapableTorment:TalentRank() < 2) then
    if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension cds 16"; end
  end
  -- call_action_list,name=trinkets
  if Settings.Commons.Enabled.Trinkets then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- desperate_prayer,if=health.pct<=75
  if S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer) then return "desperate_prayer cds 80"; end
  end
end

local function Main()
  -- call_action_list,name=main_variables
  MainVariables()
  -- call_action_list,name=cds,if=fight_remains<30|time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if CDsON() and (FightRemains < 30 or Target:TimeToDie() > 15 and ((not VarHoldingCrash) or EnemiesCount10ySplash > 2)) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=variable.dots_up&(fight_remains<30|time_to_die>15)
  if Fiend:IsCastable() and (VarDotsUp and (FightRemains < 30 or Target:TimeToDie() > 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender main 2"; end
  end
  -- mind_blast,target_if=(dot.devouring_plague.ticking&(cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time)|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>cast_time&active_enemies<=7
  if S.MindBlast:IsCastable() then
    if Everyone.CastCycle(S.MindBlast, Enemies40y, EvaluateCycleMindBlastMain, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 4"; end
  end
  -- void_bolt,if=variable.dots_up
  if S.VoidBolt:IsCastable() and (VarDotsUp) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt main 6"; end
  end
  -- devouring_plague,target_if=refreshable|!talent.distorted_reality,if=refreshable&!variable.pool_for_cds|insanity.deficit<=20|buff.voidform.up&cooldown.void_bolt.remains>buff.voidform.remains&cooldown.void_bolt.remains<(buff.voidform.remains+2)
  if S.DevouringPlague:IsReady() and ((not VarPoolForCDs) or Player:InsanityDeficit() <= 20 or Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownRemains() > Player:BuffRemains(S.VoidformBuff) and S.VoidBolt:CooldownRemains() < Player:BuffRemains(S.VoidformBuff) + 2) then
    if Everyone.CastCycle(S.DevouringPlague, Enemies40y, EvaluateCycleDP, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 8"; end
  end
  -- shadow_crash,if=!variable.holding_crash&dot.vampiric_touch.refreshable
  if S.ShadowCrash:IsCastable() and ((not VarHoldingCrash) and Target:DebuffRefreshable(S.VampiricTouchDebuff)) then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 10"; end
  end
  -- vampiric_touch,target_if=min:remains,if=refreshable&target.time_to_die>=12&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight|variable.holding_crash|!talent.whispering_shadows)
  if S.VampiricTouch:IsCastable() then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies40y, "min", EvaluateTargetIfFilterVTRemains, EvaluateTargetIfVTMain, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 12"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20&(cooldown.fiend.remains>=10|!talent.inescapable_torment)|pet.fiend.active>1&talent.inescapable_torment|buff.deathspeaker.up
  if S.ShadowWordDeath:IsCastable() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWD, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death main 20"; end
  end
  -- mind_spike_insanity,if=variable.dots_up&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if S.MindSpikeInsanity:IsReady() and (VarDotsUp and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Cast(S.MindSpikeInsanity, nil, nil, not Target:IsInRange(40)) then return "mind_spike_insanity main 22"; end
  end
  -- mind_flay,if=buff.mind_flay_insanity.up&variable.dots_up&(!pet.fiend.active)&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if Flay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff) and VarDotsUp and (not VarFiendUp) and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Cast(Flay, nil, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay main 24"; end
  end
  -- mind_blast,if=variable.dots_up&(!buff.mind_devourer.up|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsCastable() and (VarDotsUp and (Player:BuffDown(S.MindDevourerBuff) or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable())) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 26"; end
  end
  -- void_torrent,if=!variable.holding_crash,target_if=variable.all_dots_up&dot.devouring_plague.remains>=2
  if S.VoidTorrent:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVoidTorrentMain, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent main 28"; end
  end
  -- mindgames,target_if=variable.all_dots_up&dot.devouring_plague.remains>=cast_time
  if S.Mindgames:IsReady() then
    if Everyone.CastCycle(S.Mindgames, Enemies40y, EvaluateCycleMindGamesMain, not Target:IsSpellInRange(S.Mindgames), nil, Settings.Commons.DisplayStyle.Signature) then return "mindgames main 30"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

local function PLTorrent()
  -- void_bolt
  if S.VoidBolt:IsCastable() then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt pl_torrent 2"; end
  end
  -- vampiric_touch,if=remains<=6&cooldown.void_torrent.remains<gcd*2
  if S.VampiricTouch:IsCastable() and (Target:DebuffRemains(S.VampiricTouchDebuff) <= 6 and S.VoidTorrent:CooldownRemains() < Player:GCD() * 2) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch pl_torrent 4"; end
  end
  -- devouring_plague,if=remains<=4&cooldown.void_torrent.remains<gcd*2
  if S.DevouringPlague:IsReady() and (Target:DebuffRemains(S.DevouringPlagueDebuff) <= 4 and S.VoidTorrent:CooldownRemains() < Player:GCD() * 2) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague pl_torrent 6"; end
  end
  -- mind_blast,if=!talent.mindgames|cooldown.mindgames.remains>=3&!prev_gcd.1.mind_blast
  if S.MindBlast:IsReady() and ((not S.Mindgames:IsAvailable()) or S.Mindgames:CooldownRemains() >= 3 and not Player:PrevGCD(1, S.MindBlast)) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast pl_torrent 8"; end
  end
  -- void_torrent,if=dot.vampiric_touch.ticking&dot.shadow_word_pain.ticking|buff.voidform.up
  if S.VoidTorrent:IsCastable() and (DotsUp(Target, false) or Player:BuffUp(S.VoidformBuff)) then
    if Cast(S.VoidTorrent, Settings.Shadow.GCDasOffGCD.VoidTorrent, nil, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent pl_torrent 10"; end
  end
  -- mindgames,target_if=variable.all_dots_up|buff.voidform.up
  if S.Mindgames:IsReady() then
    if Everyone.CastCycle(S.Mindgames, Enemies40y, EvaluateCycleMindGamesPLT, not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Signature) then return "mindgames pl_torrent 12"; end
  end
end

local function AoE()
  -- call_action_list,name=aoe_variables
  AoEVariables()
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied),if=variable.max_vts>0&!variable.manual_vts_applied&!action.shadow_crash.in_flight|!talent.whispering_shadows
  if S.VampiricTouch:IsCastable() and (VarMaxVTs > 0 and (not VarManualVTsApplied) and (not S.ShadowCrash:InFlight()) or not S.WhisperingShadows:IsAvailable()) then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 2"; end
  end
  -- shadow_crash,if=!variable.holding_crash,target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  if S.ShadowCrash:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(S.ShadowCrash, Enemies40y, EvaluateCycleShadowCrashAoE, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash aoe 4"; end
  end
  -- call_action_list,name=cds,if=fight_remains<30|time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if CDsON() and (FightRemains < 30 or Target:TimeToDie() > 15 and ((not VarHoldingCrash) or EnemiesCount10ySplash > 2)) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=(dot.shadow_word_pain.ticking&variable.vts_applied|action.shadow_crash.in_flight&talent.whispering_shadows)&(fight_remains<30|time_to_die>15)
  if Fiend:IsCastable() and ((Target:DebuffUp(S.ShadowWordPainDebuff) and VarVTsApplied or S.ShadowCrash:InFlight() and S.WhisperingShadows:IsAvailable()) and (FightRemains < 30 or Target:TimeToDie() > 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender aoe 6"; end
  end
  -- mind_blast,if=(cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>cast_time&active_enemies<=7&!buff.mind_devourer.up
  -- mind_blast,if=cooldown.mind_blast.full_recharge_time<=gcd.max+cast_time&talent.mind_devourer.rank=2&spell_targets.mind_sear>=3&!buff.mind_devourer.up&spell_targets.mind_sear<=7
  if S.MindBlast:IsReady() and ((S.MindBlast:FullRechargeTime() <= GCDMax + S.MindBlast:CastTime() or VarFiendRemains <= S.MindBlast:CastTime() + GCDMax) and VarFiendUp and S.InescapableTorment:IsAvailable() and VarFiendRemains > S.MindBlast:CastTime() and EnemiesCount10ySplash <= 7 and Player:BuffDown(S.MindDevourerBuff)) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast aoe 8"; end
  end
  -- void_bolt
  if S.VoidBolt:IsCastable() then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt aoe 10"; end
  end
  -- devouring_plague,target_if=refreshable|!talent.distorted_reality,if=refreshable&!variable.pool_for_cds|insanity.deficit<=20|buff.voidform.up&cooldown.void_bolt.remains>buff.voidform.remains&cooldown.void_bolt.remains<(buff.voidform.remains+2)
  if S.DevouringPlague:IsReady() and ((not VarPoolForCDs) or Player:InsanityDeficit() <= 20 or Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownRemains() > Player:BuffRemains(S.VoidformBuff) and S.VoidBolt:CooldownRemains() < Player:BuffRemains(S.VoidformBuff) + 2) then
    if Everyone.CastCycle(S.DevouringPlague, Enemies40y, EvaluateCycleDP, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague aoe 12"; end
  end
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied),if=variable.max_vts>0&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash)&!action.shadow_crash.in_flight|!talent.whispering_shadows
  if S.VampiricTouch:IsCastable() and (VarMaxVTs > 0 and (not S.ShadowCrash:InFlight()) or not S.WhisperingShadows:IsAvailable()) then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE2, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 14"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20&(cooldown.fiend.remains>=10|!talent.inescapable_torment)|pet.fiend.active>1&talent.inescapable_torment|buff.deathspeaker.up
  if S.ShadowWordDeath:IsCastable() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWD, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death aoe 16"; end
  end
  -- mind_spike_insanity,if=variable.dots_up&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if S.MindSpikeInsanity:IsReady() and (VarDotsUp and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Cast(S.MindSpikeInsanity, nil, nil, not Target:IsInRange(40)) then return "mind_spike_insanity aoe 18"; end
  end
  -- mind_flay,if=buff.mind_flay_insanity.up&variable.dots_up&(!pet.fiend.active)&cooldown.mind_blast.full_recharge_time>=gcd*3&talent.idol_of_cthun&(!cooldown.void_torrent.up|!talent.void_torrent)
  if Flay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff) and VarDotsUp and (not VarFiendUp) and S.MindBlast:FullRechargeTime() >= Player:GCD() * 3 and S.IdolOfCthun:IsAvailable() and (S.VoidTorrent:CooldownDown() or not S.VoidTorrent:IsAvailable())) then
    if Cast(Flay, nil, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay aoe 20"; end
  end
  -- mind_blast,if=variable.vts_applied&(!buff.mind_devourer.up|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsReady() and (VarVTsApplied and (Player:BuffDown(S.MindDevourerBuff) or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable())) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast aoe 22"; end
  end
  -- call_action_list,name=pl_torrent,target_if=talent.void_torrent&talent.psychic_link&cooldown.void_torrent.remains<=3&(!variable.holding_crash|raid_event.adds.count%(active_dot.vampiric_touch+raid_event.adds.count)<1.5)&((insanity>=50|dot.devouring_plague.ticking|buff.dark_reveries.up)|buff.voidform.up|buff.dark_ascension.up)
  if S.VoidTorrent:IsAvailable() and S.PsychicLink:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 3 and ((not VarHoldingCrash) or EnemiesCount10ySplash / (S.VampiricTouchDebuff:AuraActiveCount() + EnemiesCount10ySplash) < 1.5) and ((Player:Insanity() >= 50 or Target:DebuffUp(S.DevouringPlagueDebuff) or Player:BuffUp(S.DarkReveriesBuff)) or Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff)) then
    local ShouldReturn = PLTorrent(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindgames,if=active_enemies<5&dot.devouring_plague.ticking|talent.psychic_link
  if S.Mindgames:IsReady() and (EnemiesCount10ySplash < 5 and Target:DebuffUp(S.DevouringPlagueDebuff) or S.PsychicLink:IsAvailable()) then
    if Cast(S.Mindgames, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.Mindgames)) then return "mindgames aoe 24"; end
  end
  -- void_torrent,if=!talent.psychic_link,target_if=variable.dots_up
  if S.VoidTorrent:IsCastable() and (not S.PsychicLink:IsAvailable()) then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVTAoE3, not Target:IsSpellInRange(S.VoidTorrent), Settings.Shadow.GCDasOffGCD.VoidTorrent) then return "void_torrent aoe 26"; end
  end
  -- mind_flay,if=buff.mind_flay_insanity.up&talent.idol_of_cthun,interrupt_if=ticks>=2,interrupt_immediate=1
  if Flay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff) and S.IdolOfCthun:IsAvailable()) then
    if Cast(Flay, nil, nil, not Target:IsSpellInRange(Flay)) then return "mind_flay aoe 28"; end
  end
  -- call_action_list,name=filler
  local ShouldReturn = Filler(); if ShouldReturn then return ShouldReturn; end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies30y = Player:GetEnemiesInRange(30) -- Silence, for Sephuz
  Enemies40y = Player:GetEnemiesInRange(40) -- Multiple CastCycle Spells
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount30y = #Enemies30y
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount30y = 1
    EnemiesCount10ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end

    -- Check our fiend status
    VarFiendUp = Fiend:TimeSinceLastCast() <= 15
    VarFiendRemains = 15 - Fiend:TimeSinceLastCast()
    if VarFiendRemains < 0 then VarFiendRemains = 0 end

    -- If MF:Insanity buff is up, change which flay we use_item
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
    local ShouldReturn = Everyone.Interrupt(30, S.Silence, Settings.Commons.OffGCDasOffGCD.Silence, false);
    if ShouldReturn then return ShouldReturn; end
    -- variable,name=holding_crash,op=set,value=raid_event.adds.in<15
    -- Note: We have no way of knowing if adds are coming, so don't ever purposely hold crash
    VarHoldingCrash = false
    -- variable,name=pool_for_cds,op=set,value=(cooldown.void_eruption.remains<=gcd.max*3&talent.void_eruption|cooldown.dark_ascension.up&talent.dark_ascension)|talent.void_torrent&talent.psychic_link&cooldown.void_torrent.remains<=4&(!raid_event.adds.exists&spell_targets.vampiric_touch>1|raid_event.adds.in<=5|raid_event.adds.remains>=6&!variable.holding_crash)&!buff.voidform.up
    VarPoolForCDs = ((S.VoidEruption:CooldownRemains() <= Player:GCD() * 3 and S.VoidEruption:IsAvailable() or S.DarkAscension:CooldownUp() and S.DarkAscension:IsAvailable()) or S.VoidTorrent:IsAvailable() and S.PsychicLink:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 4 and Player:BuffDown(S.VoidformBuff))
    -- run_action_list,name=aoe,if=active_enemies>2|spell_targets.vampiric_touch>3
    if (EnemiesCount10ySplash > 2 or EnemiesCount30y > 3) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for AoE()"; end
    end
    -- run_action_list,name=main
    if (true) then
      local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
      if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Main()"; end
    end
  end
end

local function Init()
  S.VampiricTouchDebuff:RegisterAuraTracking()

  HR.Print("Shadow Priest rotation is currently a work in progress, but has been updated for patch 10.1.0.")
end

HR.SetAPL(258, APL, Init)
