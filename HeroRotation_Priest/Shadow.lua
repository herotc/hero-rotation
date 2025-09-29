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
local Priest                = HR.Commons.Priest
-- Num/Bool Helper Functions
local num                   = HR.Commons.Everyone.num
local bool                  = HR.Commons.Everyone.bool
-- lua
local mathmax               = math.max
local mathmin               = math.min
-- WoW API
local Delay                 = C_Timer.After

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
  I.FlarendosPilotLight:ID(),
  I.GeargrindersSpareKeys:ID(),
  I.NeuralSynapseEnhancer:ID(),
  I.NexusKingsCommand:ID(),
  I.SpymastersWeb:ID(),
  -- TWW Other Items
  I.AstralGladiatorsBadge:ID(),
  I.HyperthreadWristwraps:ID(),
  I.PrizedGladiatorsBadge:ID(),
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
local VarDRForcePrio, VarMEForcePrio = true, true
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

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinket1Buffs, VarTrinket2Buffs
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

  Trinket1          = T1.Object
  Trinket2          = T2.Object

  VarTrinket1ID     = T1.ID
  VarTrinket2ID     = T2.ID

  VarTrinket1CD     = T1.Cooldown
  VarTrinket2CD     = T2.Cooldown
  VarTrinket1Range  = T1.Range
  VarTrinket2Range  = T2.Range
  VarTrinket1Ex     = T1.Excluded
  VarTrinket2Ex     = T2.Excluded

  VarTrinket1Buffs  = (Trinket1:HasUseBuff() or VarTrinket1ID == I.SignetofthePriory:ID()) and (VarTrinket1CD >= 20)
  VarTrinket2Buffs  = (Trinket2:HasUseBuff() or VarTrinket2ID == I.SignetofthePriory:ID()) and (VarTrinket2CD >= 20)
end
SetTrinketVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarDRForcePrio, VarMEForcePrio = true, true
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
  S.ShadowCrashTarget:RegisterInFlightEffect(465522)
  S.ShadowCrashTarget:RegisterInFlight()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.ShadowCrash:RegisterInFlightEffect(205386)
S.ShadowCrash:RegisterInFlight()
S.ShadowCrashTarget:RegisterInFlightEffect(465522)
S.ShadowCrashTarget:RegisterInFlight()

--- ===== Helper Functions =====
-- Currently unused, but could be useful in the future.
--[[local function DotsUp(tar, all)
  if all then
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff) and tar:DebuffUp(S.DevouringPlagueDebuff))
  else
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff))
  end
end]]

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

local function TWW3Archon4pcHelper()
  if Player:HeroTreeID() ~= 19 or Player:BuffDown(S.PowerSurgeBuff) then return 0 end
  return Priest.Archon4pcStacks
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

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfDPMain(TargetUnit)
  -- if=active_dot.devouring_plague<=1&dot.devouring_plague.remains<=gcd.max&(!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*3)|insanity.deficit<=35|buff.mind_devourer.up|buff.entropic_rift.up|buff.power_surge.up&buff.tww3_archon_4pc_helper.stack<4&buff.ascension.up
  return S.DevouringPlagueDebuff:AuraActiveCount() <= 1 and TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) <= GCDMax and (not S.VoidEruption:IsAvailable() or S.VoidEruption:CooldownRemains() >= GCDMax * 3) or Player:InsanityDeficit() <= 35 or Player:BuffUp(S.MindDevourerBuff) or EntropicRiftUp or Player:BuffUp(S.PowerSurgeBuff) and TWW3Archon4pcHelper() < 4 and Player:BuffUp(S.AscensionBuff)
end

local function EvaluateTargetIfVoidBlastMain(TargetUnit)
  -- if=(dot.devouring_plague.remains>=execute_time|buff.entropic_rift.remains<=gcd.max|action.void_torrent.channeling&talent.void_empowerment)&(insanity.deficit>=16|cooldown.mind_blast.full_recharge_time<=gcd.max)&(!talent.mind_devourer|!buff.mind_devourer.up|buff.entropic_rift.remains<=gcd.max)
  -- Note: 2nd and 3rd parts handled before CastTargetIf.
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= S.VoidBlast:ExecuteTime() or EntropicRiftRemains <= GCDMax or (Player:IsChanneling(S.VoidTorrent) or Player:PrevGCDP(1, S.VoidTorrent)) and S.VoidEmpowerment:IsAvailable()
end

local function EvaluateTargetIfVTMain(TargetUnit)
  -- if=!variable.holding_crash&(dot.devouring_plague.remains>=2.5&(cooldown.dark_ascension.remains>=12|!talent.dark_ascension|!talent.void_blast)|cooldown.void_eruption.remains<=3&talent.void_eruption)
  -- Note: variable.holding_crash handled before CastTargetIf.
  return TargetUnit:DebuffRemains(S.DevouringPlagueDebuff) >= 2.5 and (S.DarkAscension:CooldownRemains() >= 12 or not S.DarkAscension:IsAvailable() or not S.VoidBlast:IsAvailable()) or S.VoidEruption:CooldownRemains() <= 3 and S.VoidEruption:IsAvailable()
end

local function EvaluateTargetIfVTMain2(TargetUnit)
  -- if=refreshable&target.time_to_die>12&(dot.vampiric_touch.ticking|!variable.dots_up)&(variable.max_vts>0|active_enemies=1)&(action.shadow_crash.usable_in>=dot.vampiric_touch.remains|variable.holding_crash|!action.shadow_crash.enabled)&(!action.shadow_crash.in_flight)
  -- Note: Some parts handled before CastTargetIf.
  return TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() > 12 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarDotsUp) and (Crash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) or VarHoldingCrash or not Crash:IsAvailable())
end

-- CastCycle Functions
local function EvaluateCycleSWDMain(TargetUnit)
  -- target_if=target.health.pct<(20+15*talent.deathspeaker)
  return TargetUnit:HealthPercentage() < (20 + 15 * num(S.Deathspeaker:IsAvailable()))
end

local function EvaluateCycleSWDMain2(TargetUnit)
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
  -- snapshot_stats
  -- Manually added: Group buff check
  if S.PowerWordFortitude:IsCastable() and Everyone.GroupBuffMissing(S.PowerWordFortitudeBuff) then
    if Cast(S.PowerWordFortitude, Settings.CommonsOGCD.GCDasOffGCD.PowerWordFortitude) then return "power_word_fortitude precombat 2"; end
  end
  -- shadowform,if=!buff.shadowform.up
  if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
    if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform precombat 4"; end
  end
  -- variable,name=trinket_1_buffs,value=(trinket.1.has_buff.intellect|trinket.1.has_buff.mastery|trinket.1.has_buff.versatility|trinket.1.has_buff.haste|trinket.1.has_buff.crit|trinket.1.is.signet_of_the_priory)&(trinket.1.cooldown.duration>=20)
  -- variable,name=trinket_2_buffs,value=(trinket.2.has_buff.intellect|trinket.2.has_buff.mastery|trinket.2.has_buff.versatility|trinket.2.has_buff.haste|trinket.2.has_buff.crit|trinket.2.is.signet_of_the_priory)&(trinket.2.cooldown.duration>=20)
  -- variable,name=dr_force_prio,default=1,op=reset
  -- variable,name=me_force_prio,default=1,op=reset
  -- variable,name=max_vts,default=12,op=reset
  -- variable,name=is_vt_possible,default=0,op=reset
  -- variable,name=pooling_mindblasts,default=0,op=reset
  -- Note: Moved variables to the declaration and PLAYER_REGEN_ENABLED registration.
  -- use_item,name=ingenious_mana_battery
  if Settings.Commons.Enabled.Trinkets and I.IngeniousManaBattery:IsEquippedAndReady() then
    if Cast(I.IngeniousManaBattery, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "ingenious_mana_battery precombat 6"; end
  end
  -- arcane_torrent
  if S.ArcaneTorrent:IsCastable() and CDsON() then
    if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent precombat 8"; end
  end
  -- use_item,name=aberrant_spellforge
  if Settings.Commons.Enabled.Trinkets and I.AberrantSpellforge:IsEquippedAndReady() then
    if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge precombat 10"; end
  end
  local DungeonSlice = Player:IsInDungeonArea()
  -- halo,if=!fight_style.dungeonroute&!fight_style.dungeonslice&active_enemies<=4&(fight_remains>=120|active_enemies<=2)&!talent.power_surge
  -- Note: Can't do target counts or fight_remains in Precombat
  if S.Halo:IsReady() and (not DungeonSlice and not S.PowerSurge:IsAvailable()) then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo precombat 12"; end
  end
  -- shadow_crash,if=raid_event.adds.in>=25&spell_targets.shadow_crash<=12&!fight_style.dungeonslice
  -- Note: Can't do target counts in Precombat
  if Crash:IsCastable() and (not DungeonSlice) then
    if Cast(Crash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash precombat 14"; end
  end
  -- vampiric_touch,if=!action.shadow_crash.enabled|raid_event.adds.in<25|spell_targets.shadow_crash>8|fight_style.dungeonslice
  -- Note: Manually added VT suggestion if Shadow Crash is on CD and wasn't just used.
  if S.VampiricTouch:IsCastable() and (not Crash:IsAvailable() or (Crash:CooldownDown() and not Crash:InFlight()) or DungeonSlice) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch precombat 16"; end
  end
  -- Manually added: shadow_word_pain,if=!talent.misery.enabled
  if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain precombat 18"; end
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
  -- variable,name=dots_up,op=set,value=(active_dot.vampiric_touch+8*(action.shadow_crash.in_flight&action.shadow_crash.enabled))>=variable.max_vts|!variable.is_vt_possible
  VarDotsUp = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(Crash:InFlight() and Crash:IsAvailable())) >= VarMaxVTs or not VarIsVTPossible)
  -- variable,name=holding_crash,op=set,value=(variable.max_vts-active_dot.vampiric_touch)<4&raid_event.adds.in>15|raid_event.adds.in<10&raid_event.adds.count>(variable.max_vts-active_dot.vampiric_touch),if=variable.holding_crash&action.shadow_crash.enabled&raid_event.adds.exists
  -- Note: Skipping the check for VarHoldingCrash already being true, as it caused a double Crash at the start of an AoE fight.
  VarHoldingCrash = (VarMaxVTs - S.VampiricTouchDebuff:AuraActiveCount()) < 4
  -- variable,name=manual_vts_applied,op=set,value=(active_dot.vampiric_touch+8*!variable.holding_crash)>=variable.max_vts|!variable.is_vt_possible
  VarManualVTsApplied = ((S.VampiricTouchDebuff:AuraActiveCount() + 8 * num(not VarHoldingCrash)) >= VarMaxVTs or not VarIsVTPossible)
end

local function AoE()
  -- call_action_list,name=aoe_variables
  AoEVariables()
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.dots_up),if=(variable.max_vts>0&!variable.manual_vts_applied&!action.shadow_crash.in_flight)&!buff.entropic_rift.up
  if S.VampiricTouch:IsCastable() and ((VarMaxVTs > 0 and not VarManualVTsApplied and not Crash:InFlight()) and not EntropicRiftUp) then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVTAoE, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch aoe 2"; end
  end
  -- shadow_crash,if=!variable.holding_crash,target_if=dot.vampiric_touch.refreshable|dot.vampiric_touch.remains<=target.time_to_die&!buff.voidform.up&(raid_event.adds.in-dot.vampiric_touch.remains)<15
  if Crash:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastCycle(Crash, Enemies40y, EvaluateCycleShadowCrashAoE, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash aoe 4"; end
  end
end

local function Trinkets()
  -- use_item,use_off_gcd=1,name=hyperthread_wristwraps,if=talent.void_blast&hyperthread_wristwraps.void_blast.count>=2&!cooldown.mind_blast.up|!talent.void_blast&((hyperthread_wristwraps.void_bolt.count>=1|!talent.void_eruption)&hyperthread_wristwraps.void_torrent.count>=1)
  if Settings.Commons.Enabled.Items and I.HyperthreadWristwraps:IsEquippedAndReady() then
    local HTWWVBlastCount = 0
    local HTWWVBoltCount = 0
    local HTWWVTCount = 0
    for i=1, 3 do
      local Spell = Player:PrevGCD(i)
      if Spell == S.VoidBlast:ID() then
        HTWWVBlastCount = HTWWVBlastCount + 1
      elseif Spell == S.VoidBolt:ID() then
        HTWWVBoltCount = HTWWVBoltCount + 1
      elseif Spell == S.VoidTorrent:ID() then
        HTWWVTCount = HTWWVTCount + 1
      end
    end
    if S.VoidBlast:IsAvailable() and HTWWVBlastCount >= 2 and S.MindBlast:CooldownDown() or not S.VoidBlast:IsAvailable() and ((HTWWVBoltCount >= 1 or not S.VoidEruption:IsAvailable()) and HTWWVTCount >= 1) then
      if Cast(I.HyperthreadWristwraps, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "hyperthread_wristwraps trinkets 2"; end
    end
  end
  -- use_item,use_off_gcd=1,name=aberrant_spellforge,if=gcd.remains>0&buff.aberrant_spellforge.stack<=4
  if Settings.Commons.Enabled.Trinkets and I.AberrantSpellforge:IsEquippedAndReady() and (Player:BuffStack(S.AberrantSpellforgeBuff) <= 4) then
    if Cast(I.AberrantSpellforge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "aberrant_spellforge trinkets 4"; end
  end
  -- use_item,use_off_gcd=1,name=neural_synapse_enhancer,if=(buff.power_surge.up|buff.entropic_rift.up|variable.trinket_1_buffs|variable.trinket_2_buffs)&(buff.voidform.up|cooldown.void_eruption.remains>=40|buff.dark_ascension.up)
  if Settings.Commons.Enabled.Items and I.NeuralSynapseEnhancer:IsEquippedAndReady() and ((PowerSurgeUp or EntropicRiftUp or VarTrinket1Buffs or VarTrinket2Buffs) and (Player:BuffUp(S.VoidformBuff) or S.VoidEruption:CooldownRemains() >= 40 or Player:BuffUp(S.DarkAscensionBuff))) then
    if Cast(I.NeuralSynapseEnhancer, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "neural_synapse_enhancer trinkets 6"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,name=flarendos_pilot_light,if=gcd.remains>0&(buff.voidform.up|buff.power_infusion.remains>=10|buff.dark_ascension.up)|fight_remains<20
    if I.FlarendosPilotLight:IsEquippedAndReady() and ((Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionRemains() >= 10 or Player:BuffUp(S.DarkAscensionBuff)) or BossFightRemains < 20) then
      if Cast(I.FlarendosPilotLight, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "flarendos_pilot_light trinkets 8"; end
    end
    -- use_item,use_off_gcd=1,name=geargrinders_spare_keys,if=gcd.remains>0
    if I.GeargrindersSpareKeys:IsEquippedAndReady() then
      if Cast(I.GeargrindersSpareKeys, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "geargrinders_spare_keys trinkets 10"; end
    end
    -- use_item,name=spymasters_web,if=(buff.power_infusion.remains>=10&buff.spymasters_report.stack>=36&fight_remains>240)&(buff.voidform.up|buff.dark_ascension.up|!talent.dark_ascension&!talent.void_eruption)|((buff.power_infusion.remains>=10&buff.bloodlust.up&buff.spymasters_report.stack>=10)|buff.power_infusion.remains>=10&(fight_remains<120))&(buff.voidform.up|buff.dark_ascension.up|!talent.dark_ascension&!talent.void_eruption)|(fight_remains<=20|buff.dark_ascension.up&fight_remains<=60|buff.entropic_rift.up&talent.entropic_rift&fight_remains<=30)&!buff.spymasters_web.up
    if I.SpymastersWeb:IsEquippedAndReady() and ((Player:PowerInfusionRemains() >= 10 and Player:BuffStack(S.SpymastersReportBuff) >= 36 and FightRemains > 240) and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff) or not S.DarkAscension:IsAvailable() and not S.VoidEruption:IsAvailable()) or ((Player:PowerInfusionRemains() >= 10 and Player:BloodlustUp() and Player:BuffStack(S.SpymastersReportBuff) >= 10) or Player:PowerInfusionRemains() >= 10 and (BossFightRemains < 120)) and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff) or not S.DarkAscension:IsAvailable() and not S.VoidEruption:IsAvailable()) or (BossFightRemains <= 20 or Player:BuffUp(S.DarkAscensionBuff) and BossFightRemains <= 60 or EntropicRiftUp and S.EntropicRift:IsAvailable() and BossFightRemains <= 30) and Player:BuffDown(S.SpymastersWebBuff)) then
      if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web trinkets 12"; end
    end
    if (Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionRemains() >= 10 or Player:BuffUp(S.DarkAscensionBuff) or (S.VoidEruption:IsAvailable() and S.VoidEruption:CooldownRemains() > 10) or I.NeuralSynapseEnhancer:IsEquipped() and EntropicRiftUp) or BossFightRemains < 20 then
      -- use_item,name=prized_gladiators_badge_of_ferocity,if=(buff.voidform.up|buff.power_infusion.remains>=10|buff.dark_ascension.up|(talent.void_eruption&cooldown.void_eruption.remains>10)|equipped.neural_synapse_enhancer&buff.entropic_rift.up)|fight_remains<20
      if I.PrizedGladiatorsBadge:IsEquippedAndReady() then
        if Cast(I.PrizedGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "prized_gladiators_badge_of_ferocity trinkets 12"; end
      end
      -- use_item,name=astral_gladiators_badge_of_ferocity,if=(buff.voidform.up|buff.power_infusion.remains>=10|buff.dark_ascension.up|(talent.void_eruption&cooldown.void_eruption.remains>10)|equipped.neural_synapse_enhancer&buff.entropic_rift.up)|fight_remains<20
      if I.AstralGladiatorsBadge:IsEquippedAndReady() then
        if Cast(I.AstralGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "astral_gladiators_badge_of_ferocity trinkets 14"; end
      end
    end
    -- use_item,use_off_gcd=1,name=perfidious_projector,if=gcd.remains>0&(!talent.voidheart|buff.voidheart.up|fight_remains<20)
    if I.PerfidiousProjector:IsEquippedAndReady() and (not S.Voidheart:IsAvailable() or Player:BuffUp(S.VoidheartBuff) or BossFightRemains < 20) then
      if Cast(I.PerfidiousProjector, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "perfidious_projector trinkets 16"; end
    end
  end
  -- use_items,if=(buff.voidform.up|buff.power_infusion.remains>=10|buff.dark_ascension.up|equipped.neural_synapse_enhancer&buff.entropic_rift.up)|fight_remains<20
  local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
  if ItemToUse and ((Player:BuffUp(S.VoidformBuff) or Player:PowerInfusionRemains() >= 10 or Player:BuffUp(S.DarkAscensionBuff) or I.NeuralSynapseEnhancer:IsEquipped() and EntropicRiftUp) or BossFightRemains < 20) then
    local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
    if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
    if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
      if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 18"; end
    end
  end
end

local function CDs()
  -- potion,if=(buff.voidform.up&buff.power_infusion.up|buff.dark_ascension.up)&(fight_remains>=320|time_to_bloodlust>=320|buff.bloodlust.react)|fight_remains<=30
  if Settings.Commons.Enabled.Potions and (((Player:BuffUp(S.VoidformBuff) and Player:PowerInfusionUp()) or Player:BuffUp(S.DarkAscensionBuff)) and (FightRemains >= 320 or Player:BloodlustUp()) or BossFightRemains <= 30) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 2"; end
    end
  end
  if CDsON() then
    -- fireblood,if=buff.power_infusion.up&(buff.voidform.up|buff.dark_ascension.up)|fight_remains<=8
    if S.Fireblood:IsCastable() and (Player:PowerInfusionUp() and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff)) or BossFightRemains <= 8) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 4"; end
    end
    -- berserking,if=buff.power_infusion.up&(buff.voidform.up|buff.dark_ascension.up)|fight_remains<=12
    if S.Berserking:IsCastable() and (Player:PowerInfusionUp() and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff)) or BossFightRemains <= 12) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 6"; end
    end
    -- blood_fury,if=buff.power_infusion.up&(buff.voidform.up|buff.dark_ascension.up)|fight_remains<=15
    if S.BloodFury:IsCastable() and (Player:PowerInfusionUp() and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff)) or BossFightRemains <= 15) then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 8"; end
    end
    -- ancestral_call,if=buff.power_infusion.up&(buff.voidform.up|buff.dark_ascension.up)|fight_remains<=15
    if S.AncestralCall:IsCastable() and (Player:PowerInfusionUp() and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff)) or BossFightRemains <= 15) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 10"; end
    end
    -- cancel_buff,name=power_infusion,if=cooldown.invoke_power_infusion_0.up&cooldown.invoke_power_infusion_0.duration>0&set_bonus.tww2_4pc&buff.power_infusion.remains<=2
    -- TODO?
    -- invoke_external_buff,name=power_infusion,if=(buff.voidform.up|buff.dark_ascension.up|set_bonus.tww2_4pc)&!buff.power_infusion.up
    -- invoke_external_buff,name=bloodlust,if=buff.power_infusion.up&fight_remains<120|fight_remains<=40
    -- Note: Not handling external buffs
    -- power_infusion,if=(buff.voidform.up|buff.dark_ascension.up&(fight_remains<=80|fight_remains>=140)|active_allied_augmentations)&(!buff.power_infusion.up|set_bonus.tww2_4pc&buff.power_infusion.remains<=15)
    if S.PowerInfusion:IsCastable() and Settings.Shadow.SelfPI and ((Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscensionBuff) and (BossFightRemains <= 80 or BossFightRemains >= 140)) and (Player:PowerInfusionDown() or Player:HasTier("TWW2", 4) and Player:PowerInfusionRemains() <= 15)) then
      if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion cds 12"; end
    end
    -- flash_heal,if=equipped.nexuskings_command&buff.oathbound.up&(!buff.boon_of_the_oathsworn.up|buff.boon_of_the_oathsworn.remains<3)&((talent.void_eruption&(buff.voidform.up|cooldown.void_eruption.up))|(talent.dark_ascension&cooldown.dark_ascension.up)|(talent.power_surge&cooldown.halo.up)|(talent.entropic_rift&cooldown.void_torrent.up))
    if S.FlashHeal:IsReady() and (I.NexusKingsCommand:IsEquipped() and Player:BuffUp(S.OathboundBuff) and (Player:BuffDown(S.BoonOfTheOathswornBuff) or Player:BuffRemains(S.BoonOfTheOathswornBuff) < 3) and ((S.VoidEruption:IsAvailable() and (Player:BuffUp(S.VoidformBuff) or S.VoidEruption:CooldownUp())) or (S.DarkAscension:IsAvailable() and S.DarkAscension:CooldownUp()) or (S.PowerSurge:IsAvailable() and S.Halo:CooldownUp()) or (S.EntropicRift:IsAvailable() and S.VoidTorrent:CooldownUp()))) then
      if Cast(S.FlashHeal, Settings.Shadow.GCDasOffGCD.FlashHeal) then return "flash_heal cds 13"; end
    end
    -- halo,if=talent.power_surge&(pet.fiend.active&cooldown.fiend.remains>=4&talent.mindbender|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment|!talent.dark_ascension)&(cooldown.mind_blast.charges=0|!cooldown.void_torrent.up|!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*4|buff.mind_devourer.up&talent.mind_devourer)
    if S.Halo:IsReady() and (S.PowerSurge:IsAvailable() and (FiendUp and Fiend:CooldownRemains() >= 4 and S.Mindbender:IsAvailable() or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable() or not S.DarkAscension:IsAvailable()) and (S.MindBlast:Charges() == 0 or S.VoidTorrent:CooldownDown() or not S.VoidEruption:IsAvailable() or S.VoidEruption:CooldownRemains() >= GCDMax * 4 or Player:BuffUp(S.MindDevourerBuff) and S.MindDevourer:IsAvailable())) then
      if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo cds 14"; end
    end
    -- void_eruption,if=(pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment)&(cooldown.mind_blast.charges=0|time>15|buff.mind_devourer.up&talent.mind_devourer|buff.power_surge.up)
    if S.VoidEruption:IsCastable() and ((FiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) and (S.MindBlast:Charges() == 0 or HL.CombatTime() > 15 or Player:BuffUp(S.MindDevourerBuff) and S.MindDevourer:IsAvailable() or Player:BuffUp(S.PowerSurgeBuff))) then
      if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption cds 16"; end
    end
    -- dark_ascension,if=(pet.fiend.active&cooldown.fiend.remains>=4|!talent.mindbender&!cooldown.fiend.up|active_enemies>2&!talent.inescapable_torment)&(active_dot.devouring_plague>=1|insanity>=(20-(5*talent.minds_eye)+(5*talent.distorted_reality)-(pet.fiend.active*2)))
    if S.DarkAscension:IsCastable() and ((FiendUp and Fiend:CooldownRemains() >= 4 or not S.Mindbender:IsAvailable() and Fiend:CooldownDown() or EnemiesCount10ySplash > 2 and not S.InescapableTorment:IsAvailable()) and (S.DevouringPlagueDebuff:AuraActiveCount() >= 1 or Player:Insanity() >= (20 - (5 * num(S.MindsEye:IsAvailable())) + (5 * num(S.DistortedReality:IsAvailable())) - (num(FiendUp) * 2)))) then
      if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension cds 18"; end
    end
  end
  -- call_action_list,name=trinkets
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- desperate_prayer,if=health.pct<=75
  if CDsON() and S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer, Settings.Shadow.GCDasOffGCD.DesperatePrayer) then return "desperate_prayer cds 20"; end
  end
end

local function HealForToF()
  -- halo
  if S.Halo:IsReady() then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo heal_for_tof 2"; end
  end
  -- divine_star
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar) then return "divine_star heal_for_tof 4"; end
  end
  -- holy_nova,if=buff.rhapsody.stack=20&talent.rhapsody
  if S.HolyNova:IsReady() and (Player:BuffStack(S.RhapsodyBuff) == 20 and S.Rhapsody:IsAvailable()) then
    if Cast(S.HolyNova, Settings.Shadow.GCDasOffGCD.HolyNova) then return "holy_nova heal_for_tof 6"; end
  end
end

local function Main()
  -- variable,name=dots_up,op=set,value=active_dot.vampiric_touch=active_enemies|action.shadow_crash.in_flight,if=active_enemies<3
  if EnemiesCount10ySplash < 3 then
    VarDotsUp = S.VampiricTouchDebuff:AuraActiveCount() == EnemiesCount10ySplash or Crash:InFlight() or Player:IsCasting(S.VampiricTouch) and S.VampiricTouchDebuff:AuraActiveCount() == EnemiesCount10ySplash - 1
  end
  -- call_action_list,name=cds,if=fight_remains<30|target.time_to_die>15&(!variable.holding_crash|active_enemies>2)
  if BossFightRemains < 30 or Target:TimeToDie() > 15 and (not VarHoldingCrash or EnemiesCount10ySplash > 2) then
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
  end
  -- mindbender,if=(dot.shadow_word_pain.ticking&variable.dots_up|action.shadow_crash.in_flight)&(!cooldown.halo.up|!talent.power_surge.enabled)&(fight_remains<30|target.time_to_die>15)&(!talent.dark_ascension|cooldown.dark_ascension.remains<gcd.max|fight_remains<15)
  if CDsON() and Fiend:IsCastable() and ((Target:DebuffUp(S.ShadowWordPainDebuff) and VarDotsUp or Crash:InFlight()) and (S.Halo:CooldownDown() or not S.PowerSurge:IsAvailable()) and (BossFightRemains < 30 or Target:TimeToDie() > 15) and (not S.DarkAscension:IsAvailable() or S.DarkAscension:CooldownRemains() < GCDMax or BossFightRemains < 15)) then
    if Cast(Fiend, Settings.Shadow.GCDasOffGCD.Mindbender) then return "mindbender main 2"; end
  end
  -- shadow_word_death,target_if=max:(target.health.pct<=20)*100+dot.devouring_plague.ticking,if=priest.force_devour_matter&talent.devour_matter
  if S.ShadowWordDeath:IsReady() and (Settings.Shadow.ForceDevourMatter and S.DevourMatter:IsAvailable()) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusHP, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 4"; end
  end
  -- void_blast,target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die),if=(dot.devouring_plague.remains>=execute_time|buff.entropic_rift.remains<=gcd.max|action.void_torrent.channeling&talent.void_empowerment)&(insanity.deficit>=16|cooldown.mind_blast.full_recharge_time<=gcd.max|buff.entropic_rift.remains<=gcd.max)
  if S.VoidBlastAbility:IsReady() and ((Player:InsanityDeficit() >= 16 or S.MindBlast:FullRechargeTime() <= GCDMax or EntropicRiftRemains <= GCDMax)) then
    if Everyone.CastTargetIf(S.VoidBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusTTD, EvaluateTargetIfVoidBlastMain, not Target:IsSpellInRange(S.VoidBlastAbility)) then return "void_blast main 6"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(dot.devouring_plague.remains<=gcd.max|variable.dr_force_prio|!talent.distorted_reality&variable.me_force_prio),if=buff.voidform.up&talent.perfected_form&buff.voidform.remains<=gcd.max&talent.void_eruption
  if S.DevouringPlague:IsReady() and (Player:BuffUp(S.VoidformBuff) and S.PerfectedForm:IsAvailable() and Player:BuffRemains(S.VoidformBuff) <= GCDMax and S.VoidEruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies10ySplash, "max", EvaluateTargetIfFilterTTDTimesDP, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 8"; end
  end
  -- void_bolt,target_if=max:target.time_to_die,if=insanity.deficit>16&cooldown.void_bolt.remains%gcd.max<=0.1
  if S.VoidBolt:IsCastable() and (Player:InsanityDeficit() > 16 and S.VoidBolt:CooldownRemains() / GCDMax <= 0.1) then
    if Everyone.CastTargetIf(S.VoidBolt, Enemies10ySplash, "max", EvaluateTargetIfFilterTTD, nil, not Target:IsInRange(46)) then return "void_bolt main 10"; end
  end
  -- devouring_plague,target_if=max:target.time_to_die*(dot.devouring_plague.remains<=gcd.max|variable.dr_force_prio|!talent.distorted_reality&variable.me_force_prio),if=active_dot.devouring_plague<=1&dot.devouring_plague.remains<=gcd.max&(!talent.void_eruption|cooldown.void_eruption.remains>=gcd.max*3)|insanity.deficit<=35|buff.mind_devourer.up|buff.entropic_rift.up|buff.power_surge.up&buff.tww3_archon_4pc_helper.stack<4&buff.ascension.up
  if S.DevouringPlague:IsReady() then
    if Everyone.CastTargetIf(S.DevouringPlague, Enemies10ySplash, "max", EvaluateTargetIfFilterTTDTimesDP, EvaluateTargetIfDPMain, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 12"; end
  end
  -- void_torrent,target_if=max:(dot.devouring_plague.remains*1000+target.time_to_die),if=!variable.holding_crash&(dot.devouring_plague.remains>=2.5&(cooldown.dark_ascension.remains>=12|!talent.dark_ascension|!talent.void_blast)|cooldown.void_eruption.remains<=3&talent.void_eruption),interrupt_if=!talent.entropic_rift,interrupt_immediate=1
  if S.VoidTorrent:IsCastable() and (not VarHoldingCrash) then
    if Everyone.CastTargetIf(S.VoidTorrent, Enemies10ySplash, "max", EvaluateTargetIfFilterDPPlusTTD, EvaluateTargetIfVTMain, not Target:IsSpellInRange(S.VoidTorrent), Settings.Shadow.GCDasOffGCD.VoidTorrent) then return "void_torrent main 14"; end
  end
  -- void_volley,if=buff.void_volley.remains<=5|buff.entropic_rift.up&action.void_blast.usable_in>buff.entropic_rift.remains|target.time_to_die<=5
  if S.VoidVolley:IsCastable() and (Player:BuffRemains(S.VoidVolleyBuff) <= 5 or EntropicRiftUp and S.VoidBlastAbility:CooldownRemains() > EntropicRiftRemains or BossFightRemains <= 5) then
    if Cast(S.VoidVolley, Settings.Shadow.GCDasOffGCD.VoidTorrent, nil, not Target:IsSpellInRange(S.VoidVolley)) then return "void_volley main 16"; end
  end
  -- mind_flay_insanity,target_if=max:dot.devouring_plague.remains
  if S.MindFlayInsanity:IsReady() then
    if Everyone.CastTargetIf(S.MindFlayInsanity, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindFlayInsanity)) then return "mind_flay_insanity main 18"; end
  end
  -- shadow_crash,target_if=dot.vampiric_touch.refreshable,if=!variable.holding_crash&!action.shadow_crash.in_flight
  if Crash:IsCastable() and (not VarHoldingCrash and not Crash:InFlight()) then
    if Everyone.CastCycle(Crash, Enemies10ySplash, EvaluateCycleVTRefreshable, not Target:IsInRange(40), Settings.Shadow.GCDasOffGCD.ShadowCrash) then return "shadow_crash main 20"; end
  end
  -- vampiric_touch,target_if=max:(refreshable*10000+target.time_to_die)*(dot.vampiric_touch.ticking|!variable.dots_up),if=refreshable&target.time_to_die>12&(dot.vampiric_touch.ticking|!variable.dots_up)&(variable.max_vts>0|active_enemies=1)&(action.shadow_crash.usable_in>=dot.vampiric_touch.remains|variable.holding_crash|!action.shadow_crash.enabled)&(!action.shadow_crash.in_flight)
  if S.VampiricTouch:IsCastable() and ((VarMaxVTs > 0 or EnemiesCount10ySplash == 1) and (not Crash:InFlight())) then
    if Everyone.CastTargetIf(S.VampiricTouch, Enemies10ySplash, "max", EvaluateTargetIfFilterVTRefresh, EvaluateTargetIfVTMain2, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 22"; end
  end
  -- mind_blast,target_if=max:dot.devouring_plague.remains,if=(!buff.mind_devourer.react|!talent.mind_devourer|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsCastable() and (Player:BuffDown(S.MindDevourerBuff) or not S.MindDevourer:IsAvailable() or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.MindBlast, Enemies10ySplash, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 24"; end
  end
  -- void_volley
  if S.VoidVolley:IsCastable() then
    if Cast(S.VoidVolley, Settings.Shadow.GCDasOffGCD.VoidTorrent, nil, not Target:IsSpellInRange(S.VoidVolley)) then return "void_volley main 26"; end
  end
  -- devouring_plague,if=buff.voidform.up&talent.void_eruption|buff.power_surge.up|talent.distorted_reality
  if S.DevouringPlague:IsReady() and (Player:BuffUp(S.VoidformBuff) and S.VoidEruption:IsAvailable() or Player:BuffUp(S.PowerSurgeBuff) or S.DistortedReality:IsAvailable()) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 28"; end
  end
  -- halo,if=spell_targets>1
  if S.Halo:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.Halo, Settings.Shadow.GCDasOffGCD.Halo, nil, not Target:IsInRange(30)) then return "halo main 30"; end
  end
  -- call_action_list,name=heal_for_tof,if=!buff.twist_of_fate.up&buff.twist_of_fate_can_trigger_on_ally_heal.up&(talent.rhapsody|talent.divine_star|talent.halo)
  if Player:BuffDown(S.TwistofFateBuff) and CanToF() then
    local ShouldReturn = HealForToF(); if ShouldReturn then return ShouldReturn; end
  end
  -- shadow_crash,if=!variable.holding_crash&raid_event.adds.in>=30&talent.descending_darkness&raid_event.movement.in>=30
  if Crash:IsCastable() and (not VarHoldingCrash and S.DescendingDarkness:IsAvailable()) then
    if Cast(Crash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 32"; end
  end
  -- shadow_word_death,target_if=target.health.pct<(20+15*talent.deathspeaker)
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDMain, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death main 34"; end
  end
  -- shadow_word_death,target_if=min:target.time_to_die,if=talent.inescapable_torment&pet.fiend.active
  if S.ShadowWordDeath:IsReady() and (S.InescapableTorment:IsAvailable() and FiendUp) then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "min", EvaluateTargetIfFilterTTD, nil, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death main 36"; end
  end
  -- mind_flay,target_if=max:dot.devouring_plague.remains,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2,interrupt_global=1
  if S.MindFlay:IsReady() then
    if Everyone.CastTargetIf(S.MindFlay, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay main 38"; end
  end
  -- divine_star
  if S.DivineStar:IsReady() then
    if Cast(S.DivineStar, Settings.Shadow.GCDasOffGCD.DivineStar, nil, not Target:IsInRange(30)) then return "divine_star main 40"; end
  end
  -- shadow_crash,if=raid_event.adds.in>20
  if Crash:IsCastable() then
    if Cast(Crash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 42"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleSWDMain2, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death main 44"; end
  end
  -- shadow_word_death,target_if=max:dot.devouring_plague.remains
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastTargetIf(S.ShadowWordDeath, Enemies40y, "max", EvaluateTargetIfFilterDPRemains, nil, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death main 46"; end
  end
  -- shadow_word_pain,target_if=min:remains
  if S.ShadowWordPain:IsReady() then
    if Everyone.CastTargetIf(S.ShadowWordPain, Enemies40y, "min", EvaluateTargetIfFilterSWP, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain main 48"; end
  end
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
    if S.EntropicRift:IsAvailable() then
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
    local ShouldReturn = Everyone.Interrupt(S.Silence, Settings.CommonsDS.DisplayStyle.Interrupts); if ShouldReturn then return ShouldReturn; end
    -- variable,name=holding_crash,op=set,value=raid_event.adds.in<15
    -- Note: We have no way of knowing if adds are coming, so default to false.
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

  HR.Print("Shadow Priest rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(258, APL, Init)
