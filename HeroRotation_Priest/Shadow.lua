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
local mathmax               = math.max
local mathmin               = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Shadow
local I = Item.Priest.Shadow

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- TWW Trinkets
  I.AberrantSpellforge:ID(),
  I.SpymastersWeb:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Priest.Commons,
  CommonsDS = HR.GUISettings.APL.Priest.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Priest.CommonsOGCD,
  Shadow = HR.GUISettings.APL.Priest.Shadow
}

--- ===== Rotation Variables =====
local VarDRForcePrio, VarMEForcePrio = false, true
local VarMaxVTs, VarIsVTPossible = 12, false
local VarPoolingMindblasts, VarPoolForCDs = false, false
local VarHoldingCrash = false
local VarDotsUp = false
local VarManualVTsApplied = false
local PreferVT = false
local Crash = S.ShadowCrashTarget:IsAvailable() and S.ShadowCrashTarget or S.ShadowCrash
local Fiend = (S.Mindbender:IsAvailable() and S.Mindbender) or (S.VoidWraith:IsAvailable() and S.VoidWraithAbility) or S.Shadowfiend
local FiendUp, FiendRemains = false, 0
local EntropicRiftUp, EntropicRiftRemains = false, 0
local PowerSurgeUp, PowerSurgeRemains = false, 0
local Flay
local GCDMax
local Enemies40y, Enemies10ySplash
local EnemiesCount10ySplash
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarDRForcePrio, VarMEForcePrio = false, true
  VarMaxVTs, VarIsVTPossible = 12, false
  VarPoolingMindblasts, VarPoolForCDs = false, false
  VarHoldingCrash = false
  VarDotsUp = false
  VarManualVTsApplied = false
  PreferVT = false
  FiendUp, FiendRemains = false, 0
  EntropicRiftUp, EntropicRiftRemains = false, 0
  PowerSurgeUp, PowerSurgeRemains = false, 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  Crash = S.ShadowCrashTarget:IsAvailable() and S.ShadowCrashTarget or S.ShadowCrash
  Fiend = (S.Mindbender:IsAvailable() and S.Mindbender) or (S.VoidWraith:IsAvailable() and S.VoidWraithAbility) or S.Shadowfiend
  S.ShadowCrash:RegisterInFlightEffect(205386)
  S.ShadowCrash:RegisterInFlight()
  S.ShadowCrashTarget:RegisterInFlightEffect(205386)
  S.ShadowCrashTarget:RegisterInFlight()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.ShadowCrash:RegisterInFlightEffect(205386)
S.ShadowCrash:RegisterInFlight()
S.ShadowCrashTarget:RegisterInFlightEffect(205386)
S.ShadowCrashTarget:RegisterInFlight()

--- ===== Helper Functions =====
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

local function CanToF()
  -- buff.twist_of_fate_can_trigger_on_ally_heal.up&(talent.rhapsody|talent.divine_star|talent.halo)
  if not S.Rhapsody:IsAvailable() and not S.DivineStar:IsAvailable() and not S.Halo:IsAvailable() then return false end
  -- Are we in a party or raid?
  local Group
  if UnitInRaid("player") then
    Group = Unit.Raid
  elseif UnitInParty("player") then
    Group = Unit.Party
  else
    return false
  end
  -- Check group HP levels for sub-35%
  local Range = (S.DivineStar:IsAvailable() or S.Halo:IsAvailable()) and 30 or 12
  for _, Char in pairs(Group) do
    if Char:Exists() and not Char:IsDeadOrGhost() and Char:IsInRange(Range) and Char:HealthPercentage() < 35 then
      return true
    end
  end
  return false
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterDPPlusHP(TargetUnit)
  -- target_if=max:(target.health.pct<=20)*100+dot.devouring_plague.ticking
  return num(TargetUnit:HealthPercentage() <= 20) * 100 + num(TargetUnit:DebuffUp(S.DevouringPlagueDebuff))
end

local function EvaluateTargetIfFilterDPPlusTTD(TargetUnit)
  -- target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die)
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) * 1000 + TargetUnit:TimeToDie()
end

local function EvaluateTargetIfFilterDPRemains(TargetUnit)
  -- target_if=max:dot.devouring_plague.remains
  return (TargetUnit:DebuffRemains(S.DevouringPlagueDebuff))
end

local function EvaluateTargetIfFilterSWP(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.ShadowWordPainDebuff))
end

local function EvaluateTargetIfFilterTTD(TargetUnit)
  -- target_if=min:target.time_to_die
  return (TargetUnit:TimeToDie())
end

local function EvaluateTargetIfFilterTTDTimesDP(TargetUnit)
  -- target_if=max:target.time_to_die*(dot.devouring_plague.remains<=gcd.max|variable.dr_force_prio|!talent.distorted_reality&variable.me_force_prio)
  return TargetUnit:TimeToDie() * num(TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) <= GCDMax or VarDRForcePrio or not S.DistortedReality:IsAvailable() and VarMEForcePrio)
end

local function EvaluateTargetIfFilterVTRefresh(TargetUnit)
  -- target_if=max:(refreshable*10000+target.time_to_die)*(dot.vampiric_touch.ticking|!variable.dots_up)
  return (num(TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff)) * 10000 + TargetUnit:TimeToDie()) * num(TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp)
end

local function EvaluateTargetIfFilterVTRemains(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.VampiricTouchDebuff))
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfDPMain(TargetUnit)
  -- if=active_dot.devouring_plague<=1&dot.devouring_plague.remains<=gcd.max&(!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*3)|insanity.deficit<=16
  return S.DevouringPlagueDebuff:AuraActiveCount() <= 1 and Target:DebuffRemains(S.DevouringPlagueDebuff) <= GCDMax and (not S.VoidEruption:IsAvailable() or S.VoidEruption:CooldownRemains() >= GCDMax * 3) or Player:InsanityDeficit() <= 16
end

local function EvaluateTargetIfDPMain2(TargetUnit)
  -- if=dot.devouring_plague.remains>=2.5
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= 2.5
end

local function EvaluateTargetIfMindBlastMain(TargetUnit)
  -- if=(cooldown.mind_blast.full_recharge_time<=gcd.max+execute_time|pet.fiend.remains<=execute_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>=execute_time&active_enemies<=7&(!buff.mind_devourer.up|!talent.mind_devourer)&dot.devouring_plague.remains>execute_time&!variable.pooling_mindblasts
  -- Note: All but DP debuff timing handled before CastTargetIf.
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) > S.MindBlast:ExecuteTime()
end

local function EvaluateTargetIfSWD(TargetUnit)
  -- if=talent.depth_of_shadows&(target.health.pct<=20|buff.deathspeaker.up&talent.deathspeaker)
  -- Note: Talent checked before CastTargetIf.
  return TargetUnit:HealthPercentage() <= 20 or Player:BuffUp(S.DeathspeakerBuff) and S.Deathspeaker:IsAvailable()
end

local function EvaluateTargetIfVoidBlastMain(TargetUnit)
  -- if=(dot.devouring_plague.remains>=execute_time|buff.entropic_rift.remains<=gcd.max|action.void_torrent.channeling&talent.void_empowerment)&(insanity.deficit>=16|cooldown.mind_blast.full_recharge_time<=gcd.max)&(!talent.mind_devourer|!buff.mind_devourer.up|buff.entropic_rift.remains<=gcd.max)
  -- Note: 2nd and 3rd parts handled before CastTargetIf.
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= S.VoidBlast:ExecuteTime() or EntropicRiftRemains <= GCDMax or Player:IsChanneling(S.VoidTorrent) and S.VoidEmpowerment:IsAvailable()
end

local function EvaluateTargetIfVTMain(TargetUnit)
  -- if=(dot.devouring_plague.ticking|talent.void_eruption&cooldown.void_eruption.up)&talent.entropic_rift&!variable.holding_crash
  -- Note: 2nd and 3rd parts handled before CastTargetIf.
  return TargetUnit:DebuffUp(S.DevouringPlagueDebuff) or S.VoidEruption:IsAvailable() and S.VoidEruption:CooldownUp()
end

local function EvaluateTargetIfVTMain2(TargetUnit)
  -- if=refreshable&target.time_to_die>12&(dot.vampiric_touch.ticking|!variable.dots_up)&(variable.max_vts>0|active_enemies=1)&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash|!talent.whispering_shadows)&(!action.shadow_crash.in_flight|!talent.whispering_shadows)
  -- Note: Some parts handled before CastTargetIf.
  return TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() > 12 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp) and (Crash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) or VarHoldingCrash or not S.WhisperingShadows:IsAvailable())
end

-- CastCycle Functions
local function EvaluateCycleSWDFiller(TargetUnit)
  -- target_if=target.health.pct<20|(buff.deathspeaker.up|set_bonus.tier31_2pc)&dot.devouring_plague.ticking
  return TargetUnit:HealthPercentage() < 20 or (Player:BuffUp(S.DeathspeakerBuff) or Player:HasTier(31, 2)) and TargetUnit:DebuffUp(S.DevouringPlagueDebuff)
end

local function EvaluateCycleSWDFiller2(TargetUnit)
  -- if=target.health.pct<20
  return (TargetUnit:HealthPercentage() < 20)
end

local function EvaluateCycleShadowCrashAoE(TargetUnit)
  -- target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) or TargetUnit:DebuffRemains(S.VampiricTouchDebuff) <= TargetUnit:TimeToDie() and Player:BuffDown(S.VoidformBuff))
end

local function EvaluateCycleVTAoE(TargetUnit)
  -- target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up)
  -- Note: Manually added variable check to avoid cycling on low hp adds.
  return TargetUnit:MaxHealth() > Settings.Shadow.VTMinHP * 1000000 and (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp))
end

local function EvaluateCycleVTRefreshable(TargetUnit)
  -- target_if=dot.vampiric_touch.refreshable
  return TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff)
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.PowerWordFortitude:IsCastable() and Everyone.GroupBuffMissing(S.PowerWordFortitudeBuff) then
    if Cast(S.PowerWordFortitude, Settings.CommonsOGCD.GCDasOffGCD.PowerWordFortitude) then return "power_word_fortitude precombat 2"; end
  end
  -- shadowform,if=!buff.shadowform.up
  if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
    if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform precombat 4"; end
  end
  -- variable,name=dr_force_prio,default=0,op=reset
  -- variable,name=me_force_prio,default=1,op=reset
  -- variable,name=max_vts,default=0,op=reset
  -- variable,name=is_vt_possible,default=0,op=reset
  -- variable,name=pooling_mindblasts,default=0,op=reset
  -- Note: Moved variables to the declaration and PLAYER_REGEN_ENABLED registration.
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent precombat 6"; end
  end
  -- use_item,name=aberrant_spellforge
  if Settings.Commons.Enabled.Trinkets and I.AberrantSpellforge:IsEquippedAndReady() then
    if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge precombat 8"; end
  end
  -- shadow_crash,if=raid_event.adds.in>=25&spell_targets.shadow_crash<=8&!fight_style.dungeonslice&(!set_bonus.tier31_4pc|spell_targets.shadow_crash>1)
  -- Note: Can't do target counts in Precombat
  local DungeonSlice = Player:IsInParty() and Player:IsInDungeonArea() and not Player:IsInRaidArea()
  if Crash:IsCastable() and (not DungeonSlice) then
    if Cast(Crash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash precombat 8"; end
  end
  -- vampiric_touch,if=!talent.shadow_crash.enabled|raid_event.adds.in<25|spell_targets.shadow_crash>8|fight_style.dungeonslice|set_bonus.tier31_4pc&spell_targets.shadow_crash=1
  -- Note: Manually added VT suggestion if Shadow Crash is on CD and wasn't just used.
  if S.VampiricTouch:IsCastable() and (not Crash:IsAvailable() or (Crash:CooldownDown() and not Crash:InFlight()) or DungeonSlice) then
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
  VarDotsUp = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(Crash:InFlight() and S.WhisperingShadows:IsAvailable())) >= VarMaxVTs or not VarIsVTPossible)
  -- variable,name=holding_crash,op=set,value=(variable.max_vts-active_dot.vampiric_touch)<4&raid_event.adds.in>15|raid_event.adds.in<10&raid_event.adds.count>(variable.max_vts-active_dot.vampiric_touch),if=variable.holding_crash&talent.whispering_shadows&raid_event.adds.exists
  if VarHoldingCrash and S.WhisperingShadows:IsAvailable() then
    VarHoldingCrash = (VarMaxVTs - S.VampiricTouchDebuff:AuraActiveCount()) < 4
  end
  -- variable,name=manual_vts_applied,op=set,value=(active_dot.vampiric_touch+8*!variable.holding_crash)>=variable.max_vts|!variable.is_vt_possible
  VarManualVTsApplied = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(not VarHoldingCrash)) >= VarMaxVTs or not VarIsVTPossible)
end

local function AoE()
  -- call_action_list,name=aoe_variables
  AoEVariables()
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up),if=(variable.max_vts>0&!variable.manual_vts_applied&!action.shadow_crash.in_flight|!talent.whispering_shadows)&!buff.entropic_rift.up
  if S.VampiricTouch:IsCastable() and ((VarMaxVTs > 0 and not VarManualVTsApplied and not Crash:InFlight() or not S.WhisperingShadows:IsAvailable()) and not EntropicRiftUp) then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 2"; end
  end
  -- shadow_crash,if=!variable.holding_crash,target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  if Crash:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(Crash, Enemies40y, EvaluateCycleShadowCrashAoE, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash aoe 4"; end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,name=aberrant_spellforge,if=gcd.remains>0&buff.aberrant_spellforge.stack<=4
    if I.AberrantSpellforge:IsEquippedAndReady() and (Player:BuffStack(S.AberrantSpellforgeBuff) <= 4) then
      if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge trinkets 26"; end
    end
    -- use_item,name=spymasters_web,if=buff.spymasters_report.stack=1&buff.power_infusion.up&!buff.spymasters_web.up|buff.power_infusion.up&(fight_remains<120)|(fight_remains<=20|buff.dark_ascension.up&fight_remains<=60|buff.entropic_rift.up&talent.entropic_rift&fight_remains<=30)&!buff.spymasters_web.up
    if I.SpymastersWeb:IsEquippedAndReady() and (Player:BuffStack(S.SpymastersReportBuff) == 1 and Player:PowerInfusionUp() and Player:BuffDown(S.SpymastersWebBuff) or Player:PowerInfusionUp() and (BossFightRemains < 120) or (BossFightRemains <= 20 or Player:BuffUp(S.DarkAscensionBuff) and BossFightRemains <= 60 or EntropicRiftUp and S.EntropicRift:IsAvailable() and BossFightRemains <= 30) and Player:BuffDown(S.SpymastersWebBuff)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web trinkets 28"; end
    end
  end
  -- use_items,if=(buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|(cooldown.void_eruption.remains>10&trinket.cooldown.duration<=60))|fight_remains<20
  local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
  if ItemToUse and ((Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionUp() or Player:BuffUp(S.DarkAscensionBuff) or (S.VoidEruption:CooldownRemains() > 10 and (ItemToUse:Cooldown() <= 60 or ItemSlot ~= 13 and ItemSlot ~= 14))) or BossFightRemains < 20) then
    local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
    if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
    if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
      if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 30"; end
    end
  end
end

local function CDs()
  -- potion,if=(buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up&(fight_remains<=cooldown.power_infusion.remains+15))&(fight_remains>=320|time_to_bloodlust>=320|buff.bloodlust.react)|fight_remains<=30
  if Settings.Commons.Enabled.Potions and ((Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionUp() or Player:BuffUp(S.DarkAscensionBuff) and (BossFightRemains <= S.PowerInfusion:CooldownRemains() + 15)) and (BossFightRemains >= 320 or Player:BloodlustUp()) or BossFightRemains <= 30) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 2"; end
    end
  end
  -- fireblood,if=buff.power_infusion.up|fight_remains<=8
  if S.Fireblood:IsCastable() and (Player:PowerInfusionUp() or BossFightRemains <= 8) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 4"; end
  end
  -- berserking,if=buff.power_infusion.up|fight_remains<=12
  if S.Berserking:IsCastable() and (Player:PowerInfusionUp() or BossFightRemains <= 12) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 6"; end
  end
  -- blood_fury,if=buff.power_infusion.up|fight_remains<=15
  if S.BloodFury:IsCastable() and (Player:PowerInfusionUp() or BossFightRemains <= 15) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
  end
  -- ancestral_call,if=buff.power_infusion.up|fight_remains<=15
  if S.AncestralCall:IsCastable() and (Player:PowerInfusionUp() or BossFightRemains <= 15) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
  end
  -- power_infusion,if=(buff.voidform.up|buff.dark_ascension.up&(fight_remains<=80|fight_remains>=140)|active_allied_augmentations)
  if S.PowerInfusion:IsCastable() and Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscension) and (BossFightRemains <= 80 or BossFightRemains >= 140)) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion cds 18"; end
  end
  -- invoke_external_buff,name=power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)&!buff.power_infusion.up
  -- invoke_external_buff,name=bloodlust,if=buff.power_infusion.up&fight_remains<120|fight_remains<=40
  -- Note: Not handling external buffs
  -- halo,if=talent.power_surge&(pet.fiend.active&cooldown.fiend.remains>=4&talent.mindbender|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment|!talent.dark_ascension)&(cooldown.mind_blast.charges=0|!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*4)
  if S.Halo:IsReady() and (Player:HeroTreeID() == 19 and (FiendUp and Fiend:CooldownRemains() >= 4 and S.Mindbender:IsAvailable() or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable() or not S.DarkAscension:IsAvailable()) and (S.MindBlast:Charges() == 0 or not S.VoidEruption:IsAvailable() or S.VoidEruption:CooldownRemains() >= GCDMax * 4)) then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo) then return "halo cds 20"; end
  end
  -- void_eruption,if=!cooldown.fiend.up&(pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender|active_enemies>2&!talent.inescapable_torment.rank)&(cooldown.mind_blast.charges=0|time>15)
  if S.VoidEruption:IsCastable() and (Fiend:CooldownDown() and (FiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) and (S.MindBlast:Charges() == 0 or S.MindBlast:Charges() == 1 and Player:IsCasting(S.MindBlast) or HL.CombatTime() > 15)) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption cds 22"; end
  end
  -- dark_ascension,if=pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment
  if S.DarkAscension:IsCastable() and not Player:IsCasting(S.DarkAscension) and (FiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) then
    if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension cds 24"; end
  end
  -- call_action_list,name=trinkets
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- desperate_prayer,if=health.pct<=75
  if S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer, Settings.Shadow.GCDasOffGCD.DesperatePrayer) then return "desperate_prayer cds 24"; end
  end
end

local function HealForToF()
  -- halo
  if S.Halo:IsReady() then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo) then return "halo heal_for_tof 2"; end
  end
  -- divine_star
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar) then return "divine_star heal_for_tof 4"; end
  end
  -- holy_nova,if=buff.rhapsody.stack=20&talent.rhapsody
  if S.HolyNova:IsReady() then
    if Cast(S.HolyNova, Settings.Shadow.GCDasOffGCD.HolyNova) then return "holy_nova heal_for_tof 6"; end
  end
end

local function EmpoweredFiller()
  -- mind_spike_insanity,target_if=max:dot.devouring_plague.remains
  if S.MindSpikeInsanity:IsReady() then
    if Everyone.CastTargetIf(S.MindSpikeInsanity, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindSpikeInsanity)) then return "mind_spike_insanity empowered_filler 2"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,if=buff.mind_flay_insanity.up
  if S.MindFlay:IsCastable() and (Player:BuffUp(S.MindFlayInsanityBuff)) then
    if Everyone.CastTargetIf(S.MindFlay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay empowered_filler 4"; end
  end
end

local function Filler()
  -- vampiric_touch,target_if=min:remains,if=buff.unfurling_darkness.up
  if S.VampiricTouch:IsCastable() and (Player:BuffUp(S.UnfurlingDarknessBuff)) then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies40y, "min", EvaluateTargetIfFilterVTRemains, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch filler 2"; end
  end
  -- call_action_list,name=heal_for_tof,if=!buff.twist_of_fate.up&buff.twist_of_fate_can_trigger_on_ally_heal.up&(talent.rhapsody|talent.divine_star|talent.halo)
  if S.TwistofFate:IsAvailable() and Player:BuffDown(S.TwistofFateBuff) and CanToF() then
    local ShouldReturn = HealForToF(); if ShouldReturn then return ShouldReturn; end
  end
  -- power_word_shield,if=!buff.twist_of_fate.up&buff.twist_of_fate_can_trigger_on_ally_heal.up&talent.crystalline_reflection
  -- Note: Not handling PW:S.
  -- call_action_list,name=empowered_filler,if=dot.devouring_plague.remains>action.mind_spike.cast_time|!talent.mind_spike
  if Target:DebuffRemains(S.DevouringPlagueDebuff) > S.MindSpike:CastTime() or not S.MindSpike:IsAvailable() then
    local ShouldReturn = EmpoweredFiller(); if ShouldReturn then return ShouldReturn; end
  end
  -- shadow_word_death,target_if=target.health.pct<20|(buff.deathspeaker.up|set_bonus.tier31_2pc)&dot.devouring_plague.ticking
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDFiller, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 4"; end
  end
  -- shadow_word_death,target_if=min:target.time_to_die,if=talent.inescapable_torment&pet.fiend.active
  if S.ShadowWordDeath:IsReady() and (S.InescapableTorment:IsAvailable() and FiendUp) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "min", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death filler 12"; end
  end
  -- devouring_plague,if=buff.voidform.up|cooldown.dark_ascension.up|buff.mind_devourer.up
  if S.DevouringPlague:IsReady() and (Player:BuffUp(S.VoidformBuff) or S.DarkAscension:CooldownUp() or Player:BuffUp(S.MindDevourerBuff)) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague filler "; end
  end
  -- halo,if=spell_targets>1
  if S.Halo:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo filler 14"; end
  end
  -- power_word_life,if=!buff.twist_of_fate.up&buff.twist_of_fate_can_trigger_on_ally_heal.up
  -- Note: Not handling PW:L.
  -- call_action_list,name=empowered_filler
  local ShouldReturn = EmpoweredFiller(); if ShouldReturn then return ShouldReturn; end
  -- call_action_list,name=heal_for_tof,if=equipped.rashoks_molten_heart&(active_allies-(10-buff.molten_radiance.value))>=10&buff.molten_radiance.up,line_cd=5
  -- TODO: Handle MoltenRadianceBuff.
  -- mind_spike,target_if=max:dot.devouring_plague.remains
  if S.MindSpike:IsCastable() then
    if Everyone.CastTargetIf(S.MindSpike, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindSpike)) then return "mind_spike filler 16"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if Flay:IsCastable() then
    if Everyone.CastTargetIf(Flay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsInRange(46)) then return "mind_flay filler 18"; end
  end
  -- divine_star
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar, not Target:IsInRange(30)) then return "divine_star filler 20"; end
  end
  -- shadow_crash,if=raid_event.adds.in>20&!set_bonus.tier31_4pc
  if Crash:IsCastable() and (not Player:HasTier(31, 4)) then
    if Cast(Crash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash filler 22"; end
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

local function Main()
  -- Reset variable.holding_crash to false for ST, in case it was set to true during AoE.
  VarHoldingCrash = false
  -- variable,name=dots_up,op=set,value=active_dot.vampiric_touch=active_enemies|action.shadow_crash.in_flight&talent.whispering_shadows,if=active_enemies<3
  if EnemiesCount10ySplash < 3 then
    VarDotsUp = S.VampiricTouchDebuff:AuraActiveCount() == EnemiesCount10ySplash or Crash:InFlight() and S.WhisperingShadows:IsAvailable() or Player:IsCasting(S.VampiricTouch) and S.Misery:IsAvailable()
  end
  -- variable,name=pooling_mindblasts,op=setif,value=1,value_else=0,condition=(cooldown.void_torrent.remains<?(variable.holding_crash*raid_event.adds.in))<=gcd.max*(1+talent.mind_melt*3),if=talent.void_blast
  VarPoolingMindblasts = false
  if S.VoidBlast:IsAvailable() then
    VarPoolingMindblasts = S.VoidTorrent:CooldownRemains() <= GCDMax * (1 + num(S.MindMelt:IsAvailable()) * 3)
  end
  -- call_action_list,name=cds,if=fight_remains<30|target.time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if CDsON() and (FightRemains < 30 or Target:TimeToDie() > 15 and (not VarHoldingCrash or EnemiesCount10ySplash > 2)) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=(dot.shadow_word_pain.ticking&variable.dots_up|action.shadow_crash.in_flight&talent.whispering_shadows)&(fight_remains<30|target.time_to_die>15)&(!talent.dark_ascension|cooldown.dark_ascension.remains<gcd.max|fight_remains<15)
  if CDsON() and Fiend:IsCastable() and ((Target:DebuffUp(S.ShadowWordPainDebuff) and VarDotsUp or Crash:InFlight() and S.WhisperingShadows:IsAvailable()) and (BossFightRemains < 30 or Target:TimeToDie() > 15) and (not S.DarkAscension:IsAvailable() or S.DarkAscension:CooldownRemains() < GCDMax or BossFightRemains < 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender main 2"; end
  end
  -- void_blast,target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die),if=(dot.devouring_plague.remains>=execute_time|buff.entropic_rift.remains<=gcd.max|action.void_torrent.channeling&talent.void_empowerment)&(insanity.deficit>=16|cooldown.mind_blast.full_recharge_time<=gcd.max)&(!talent.mind_devourer|!buff.mind_devourer.up|buff.entropic_rift.remains<=gcd.max)
  if S.VoidBlast:IsReady() and ((Player:InsanityDeficit() >= 16 or S.MindBlast:FullRechargeTime() <= GCDMax) and (not S.MindDevourer:IsAvailable() or Player:BuffDown(S.MindDevourerBuff) or EntropicRiftRemains <= GCDMax)) then
    if Everyone.CastTargetIf(S.VoidBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusTTD, EvaluateTargetIfVoidBlastMain, not Target:IsSpellInRange(S.VoidBlast)) then return "void_blast main 4"; end
  end
  -- wait,sec=cooldown.mind_blast.recharge_time,if=cooldown.mind_blast.recharge_time<buff.entropic_rift.remains&buff.entropic_rift.up&buff.entropic_rift.remains<gcd.max&cooldown.mind_blast.charges<1
  if S.MindBlast:Recharge() < EntropicRiftRemains and EntropicRiftUp and EntropicRiftRemains < GCDMax and S.MindBlast:Charges() < 1 then
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Wait for Mind Blast"; end
  end
  -- mind_blast,if=buff.voidform.up&full_recharge_time<=gcd.max&(!talent.insidious_ire|dot.devouring_plague.remains>=execute_time)&(cooldown.void_bolt.remains%gcd.max-cooldown.void_bolt.remains%%gcd.max)*gcd.max<=0.25&(cooldown.void_bolt.remains%gcd.max-cooldown.void_bolt.remains%%gcd.max)>=0.01
  if S.MindBlast:IsCastable() and (Player:BuffUp(S.VoidformBuff) and S.MindBlast:FullRechargeTime() <= GCDMax and (not S.InsidiousIre:IsAvailable() or Target:DebuffRemains(S.DevouringPlagueDebuff) >= S.MindBlast:ExecuteTime()) and (S.VoidBolt:CooldownRemains() / GCDMax - S.VoidBolt:CooldownRemains() % GCDMax) * GCDMax <= 0.25 and (S.VoidBolt:CooldownRemains() / GCDMax - S.VoidBolt:CooldownRemains() % GCDMax) >= 0.01) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 6"; end
  end
  -- void_bolt,target_if=max:target.time_to_die,if=insanity.deficit>16&cooldown.void_bolt.remains<=0.1
  if S.VoidBolt:IsCastable() and (Player:InsanityDeficit() > 16 and S.VoidBolt:CooldownRemains() <= 0.1) then
    if Everyone.CastTargetIf(S.VoidBolt, Enemies10ySplash, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(46)) then return "void_bolt main 8"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(dot.devouring_plague.remains<=gcd.max|variable.dr_force_prio|!talent.distorted_reality&variable.me_force_prio),if=active_dot.devouring_plague<=1&dot.devouring_plague.remains<=gcd.max&(!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*3)|insanity.deficit<=16
  if S.DevouringPlague:IsReady() then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies10ySplash, "max", EvaluateTargetIfFilterTTDTimesDP, EvaluateTargetIfDPMain, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 10"; end
  end
  -- void_torrent,target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die),if=(dot.devouring_plague.ticking|talent.void_eruption&cooldown.void_eruption.up)&talent.entropic_rift&!variable.holding_crash
  if S.VoidTorrent:IsReady() and (Player:HeroTreeID() == 18 and not VarHoldingCrash) then
    if Everyone.CastTargetIf(S.VoidTorrent, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusTTD, EvaluateTargetIfVTMain, not Target:IsSpellInRange(S.VoidTorrent), Settings.Shadow.GCDasOffGCD.VoidTorrent) then return "void_torrent main 12"; end
  end
  -- shadow_word_death,target_if=max:(target.health.pct<=20)*100+dot.devouring_plague.ticking,if=talent.depth_of_shadows&(target.health.pct<=20|buff.deathspeaker.up&talent.deathspeaker)
  if S.ShadowWordDeath:IsReady() and (S.DepthofShadows:IsAvailable()) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusHP, EvaluateTargetIfSWD, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 14"; end
  end
  -- mind_blast,target_if=max:dot.devouring_plague.remains,if=(cooldown.mind_blast.full_recharge_time<=gcd.max+execute_time|pet.fiend.remains<=execute_time+gcd.max)&pet.fiend.active&talent.inescapable_torment&pet.fiend.remains>=execute_time&active_enemies<=7&(!buff.mind_devourer.up|!talent.mind_devourer)&dot.devouring_plague.remains>execute_time&!variable.pooling_mindblasts&variable.dots_up
  if S.MindBlast:IsCastable() and ((S.MindBlast:FullRechargeTime() <= GCDMax + S.MindBlast:ExecuteTime() or FiendRemains <= S.MindBlast:ExecuteTime() + GCDMax) and FiendUp and S.InescapableTorment:IsAvailable() and FiendRemains >= S.MindBlast:ExecuteTime() and EnemiesCount10ySplash <= 7 and (Player:BuffDown(S.MindDevourerBuff) or not S.MindDevourer:IsAvailable()) and not VarPoolingMindblasts and VarDotsUp) then
    if Everyone.CastTargetIf(S.MindBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterDPRemains, EvaluateTargetIfMindBlastMain, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 16"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains,if=pet.fiend.remains<=(gcd.max+1)&pet.fiend.active&talent.inescapable_torment&active_enemies<=7
  if S.ShadowWordDeath:IsReady() and (FiendRemains <= (GCDMax + 1) and FiendUp and S.InescapableTorment:IsAvailable() and EnemiesCount10ySplash <= 7) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies10ySplash, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 18"; end
  end
  -- void_bolt,target_if=max:target.time_to_die,if=cooldown.void_bolt.remains<=0.1
  if S.VoidBolt:IsCastable() and (S.VoidBolt:CooldownRemains() <= 0.1) then
    if Everyone.CastTargetIf(S.VoidBolt, Enemies10ySplash, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(46)) then return "void_bolt main 20"; end
  end
  -- call_action_list,name=empowered_filler,if=(buff.mind_spike_insanity.stack>2&talent.mind_spike|buff.mind_flay_insanity.stack>2&!talent.mind_spike)&talent.empowered_surges&!cooldown.void_eruption.up
  if (Player:BuffStack(S.MindSpikeInsanityBuff) > 2 and S.MindSpike:IsAvailable() or Player:BuffStack(S.MindFlayInsanityBuff) > 2 and not S.MindSpike:IsAvailable()) and S.EmpoweredSurges:IsAvailable() and S.VoidEruption:CooldownDown() then
    local ShouldReturn = EmpoweredFiller(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=heal_for_tof,if=!buff.twist_of_fate.up&buff.twist_of_fate_can_trigger_on_ally_heal.up&(talent.rhapsody|talent.divine_star|talent.halo)
  if Player:BuffDown(S.TwistofFateBuff) and CanToF() then
    local ShouldReturn = HealForToF(); if ShouldReturn then return ShouldReturn; end
  end
  -- devouring_plague,if=fight_remains<=duration+4
  if S.DevouringPlague:IsReady() and (FightRemains <= S.DevouringPlagueDebuff:BaseDuration() + 4) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 22"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(dot.devouring_plague.remains<=gcd.max|variable.dr_force_prio|!talent.distorted_reality&variable.me_force_prio),if=insanity.deficit<=35&talent.distorted_reality|buff.dark_ascension.up|buff.mind_devourer.up&cooldown.mind_blast.up&(cooldown.void_eruption.remains>=3*gcd.max|!talent.void_eruption)|buff.entropic_rift.up
  if S.DevouringPlague:IsReady() and (Player:InsanityDeficit() <= 35 and S.DistortedReality:IsAvailable() or Player:BuffUp(S.DarkAscensionBuff) or Player:BuffUp(S.MindDevourerBuff) and S.MindBlast:CooldownUp() and (S.VoidEruption:CooldownRemains() >= 3 * GCDMax or not S.VoidEruption:IsAvailable()) or EntropicRiftUp) then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies10ySplash, "max", EvaluateTargetIfFilterTTDTimesDP, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 24"; end
  end
  -- void_torrent,target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die),if=!variable.holding_crash&!talent.entropic_rift,target_if=dot.devouring_plague.remains>=2.5
  if S.VoidTorrent:IsCastable() then
    if Target:DebuffRemains(S.DevouringPlagueDebuff) >= 2.5 then
      if Cast(S.VoidTorrent, Settings.Shadow.GCDasOffGCD.VoidTorrent, nil, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent main 26 (primary target)"; end
    else
      if Everyone.CastTargetIf(S.VoidTorrent, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusTTD, EvaluateTargetIfDPMain2, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent main 26 (off-target)"; end
    end
  end
  -- shadow_crash,target_if=dot.vampiric_touch.refreshable,if=!variable.holding_crash
  if Crash:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(Crash, Enemies10ySplash, EvaluateCycleVTRefreshable, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash main 28"; end
  end
  -- vampiric_touch,target_if=max:(refreshable*10000+target.time_to_die)*(dot.vampiric_touch.ticking|!variable.dots_up),if=refreshable&target.time_to_die>12&(dot.vampiric_touch.ticking|!variable.dots_up)&(variable.max_vts>0|active_enemies=1)&(cooldown.shadow_crash.remains>=dot.vampiric_touch.remains|variable.holding_crash|!talent.whispering_shadows)&(!action.shadow_crash.in_flight|!talent.whispering_shadows)
  if S.VampiricTouch:IsCastable() and ((VarMaxVTs > 0 or EnemiesCount10ySplash == 1) and (not Crash:InFlight() or not S.WhisperingShadows:IsAvailable())) then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies10ySplash, "max", EvaluateTargetIfFilterVTRefresh, EvaluateTargetIfVTMain2, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 30"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains,if=variable.dots_up&buff.deathspeaker.up
  if S.ShadowWordDeath:IsReady() and (VarDotsUp and Player:BuffUp(S.DeathspeakerBuff)) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies10ySplash, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 32"; end
  end
  -- mind_blast,target_if=max:dot.devouring_plague.remains,if=(!buff.mind_devourer.up|!talent.mind_devourer|cooldown.void_eruption.up&talent.void_eruption)&!variable.pooling_mindblasts
  if S.MindBlast:IsCastable() and ((Player:BuffDown(S.MindDevourerBuff) or not S.MindDevourer:IsAvailable() or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable()) and not VarPoolingMindblasts) then
    if Everyone.CastTargetIf(S.MindBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 34"; end
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
    FiendUp = Fiend:TimeSinceLastCast() <= 15
    FiendRemains = mathmax(15 - Fiend:TimeSinceLastCast(), 0)

    -- Check out Entropic Rift status
    if Player:HeroTreeID() == 18 then
      EntropicRiftUp = S.VoidTorrent:TimeSinceLastCast() <= 8
      EntropicRiftRemains = mathmax(8 - S.VoidTorrent:TimeSinceLastCast(), 0)
      PowerSurgeUp = false
      PowerSurgeRemains = 0
    else
      EntropicRiftUp = false
      EntropicRiftRemains = 0
      PowerSurgeUp = S.Halo:TimeSinceLastCast() <= 10
      PowerSurgeRemains = mathmax(10 - S.Halo:TimeSinceLastCast(), 0)
    end

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
    local ShouldReturn = Everyone.Interrupt(S.Silence, Settings.CommonsDS.DisplayStyle.Interrupts);
    if ShouldReturn then return ShouldReturn; end
    -- variable,name=holding_crash,op=set,value=raid_event.adds.in<15
    -- Note: We have no way of knowing if adds are coming, so don't ever purposely hold crash
    VarHoldingCrash = false
    PreferVT = Settings.Shadow.PreferVTWhenSTinDungeon and EnemiesCount10ySplash == 1 and Player:IsInDungeonArea() and Player:IsInParty() and not Player:IsInRaidArea()
    -- variable,name=pool_for_cds,op=set,value=(cooldown.void_eruption.remains<=gcd.max*3&talent.void_eruption|cooldown.dark_ascension.up&talent.dark_ascension)|talent.void_torrent&talent.psychic_link&cooldown.void_torrent.remains<=4&(!raid_event.adds.exists&spell_targets.vampiric_touch>1|raid_event.adds.in<=5|raid_event.adds.remains>=6&!variable.holding_crash)&!buff.voidform.up
    VarPoolForCDs = ((S.VoidEruption:CooldownRemains() <= Player:GCD() * 3 and S.VoidEruption:IsAvailable() or S.DarkAscension:CooldownUp() and S.DarkAscension:IsAvailable()) or S.VoidTorrent:IsAvailable() and S.PsychicLink:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 4 and Player:BuffDown(S.VoidformBuff))
    -- call_action_list,name=aoe,if=active_enemies>2
    if EnemiesCount10ySplash > 2 then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=main
    local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
    if HR.CastAnnotated(S.Pool, false, "WAIT") then return "Pool for Main()"; end
  end
end

local function Init()
  S.DevouringPlagueDebuff:RegisterAuraTracking()
  S.VampiricTouchDebuff:RegisterAuraTracking()

  HR.Print("Shadow Priest rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(258, APL, Init)
