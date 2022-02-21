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
-- lua
local mathmin       = math.min

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Shadow
local I = Item.Priest.Commons

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.EmpyrealOrdinance:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.MacabreSheetMusic:ID(),
  I.ShadowedOrbofTorment:ID(),
  I.SinfulGladiatorsBadgeofFerocity:ID(),
  I.SoullettingRuby:ID()
}

-- Rotation Var
local Enemies8yMelee, Enemies30y, Enemies40y, Enemies10ySplash
local EnemiesCount8ySplash, EnemiesCount10ySplash
local UnitsWithoutSWPain
local UnitsRefreshSWPain

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Priest.Commons,
  Shadow = HR.GUISettings.APL.Priest.Shadow
}

-- Variables
local CombatTime = 0
local FightRemains = 0
local RemainsPlusTime = 0
local VarDotsUp = false
local VarAllDotsUp = false
local VarMindSearCutoff = 1
local VarSearingNightmareCutoff = false
local VarCDManagement = false
local VarMaxVTs = false
local VarIsVTPossible = false
local VarVTsApplied = 0
local VarPoolForCDs = false
local DarkThoughtMaxStacks = 2
local SephuzEquipped = Player:HasLegendaryEquipped(202)
local TalbadarEquipped = Player:HasLegendaryEquipped(161)
local PainbreakerEquipped = Player:HasLegendaryEquipped(158)
local ShadowflamePrismEquipped = Player:HasLegendaryEquipped(159)
local SpheresHarmonyEquipped = Player:HasLegendaryEquipped(261)

HL:RegisterForEvent(function()
  VarDotsUp = false
  VarAllDotsUp = false
  VarMindSearCutoff = 1
  VarSearingNightmareCutoff = false
  VarPoolForCDs = false
end, "PLAYER_REGEN_ENABLED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  SephuzEquipped = Player:HasLegendaryEquipped(202)
  TalbadarEquipped = Player:HasLegendaryEquipped(161)
  PainbreakerEquipped = Player:HasLegendaryEquipped(158)
  ShadowflamePrismEquipped = Player:HasLegendaryEquipped(159)
  SpheresHarmonyEquipped = Player:HasLegendaryEquipped(261)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.ShadowCrash:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.ShadowCrash:RegisterInFlight()

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function DotsUp(tar, all)
  if all then
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff) and tar:DebuffUp(S.DevouringPlagueDebuff))
  else
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff))
  end
end

local function UnitsWithoutSWP(enemies)
  local WithoutSWPCount = 0
  for k in pairs(enemies) do
    local CycleUnit = enemies[k]
    if CycleUnit:DebuffDown(S.ShadowWordPainDebuff) then
      WithoutSWPCount = WithoutSWPCount + 1
    end
  end
  return WithoutSWPCount
end

local function UnitsRefreshSWP(enemies)
  local RefreshSWPCount = 0
  for k in pairs(enemies) do
    local CycleUnit = enemies[k]
    if CycleUnit:DebuffRefreshable(S.ShadowWordPainDebuff) then
      RefreshSWPCount = RefreshSWPCount + 1
    end
  end
  return RefreshSWPCount
end

local function EvaluateCycleDamnation200(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) or TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) or (Player:BuffDown(S.MindDevourerBuff) and Player:Insanity() < 50)) and (Player:BuffStack(S.DarkThoughtBuff) < DarkThoughtMaxStacks or not Player:HasTier(28, 2)))
end

local function EvaluateCycleShadowWordDeath204(TargetUnit)
  return ((TargetUnit:HealthPercentage() < 20 and EnemiesCount10ySplash < 4) or (S.Mindbender:TimeSinceLastCast() <= 15 and ShadowflamePrismEquipped and EnemiesCount10ySplash <= 7))
end

local function EvaluateCycleSurrenderToMadness206(TargetUnit)
  return (TargetUnit:TimeToDie() < 25 and Player:BuffDown(S.VoidformBuff))
end

local function EvaluateCycleVoidTorrent208(TargetUnit)
  return (DotsUp(TargetUnit, false) and (Player:BuffDown(S.VoidformBuff) or Player:BuffRemains(S.VoidformBuff) < S.VoidBolt:CooldownRemains() or Player:PrevGCD(1, S.VoidBolt) and Player:BloodlustDown() and EnemiesCount10ySplash < 3) and VarVTsApplied and EnemiesCount10ySplash < (5 + (6 * num(S.TwistofFate:IsAvailable()))))
end

local function EvaluateCycleVampiricTouch214(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarVTsApplied) and VarMaxVTs > 0 or (S.Misery:IsAvailable() and TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff)) or Player:BuffUp(S.UnfurlingDarknessBuff))
end

local function EvaluateCycleShadowWordPain220(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) and TargetUnit:TimeToDie() > 4 and not S.Misery:IsAvailable() and not (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff) and (not S.PsychicLink:IsAvailable() or (S.PsychicLink:IsAvailable() and EnemiesCount10ySplash <= 2)))
end

local function EvaluateCycleMindSear224(TargetUnit)
  return (S.SearingNightmare:IsAvailable() and TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) and EnemiesCount10ySplash > 2)
end

local function EvaluatecycleMindSear225(TargetUnit)
  return (TargetUnit:DebuffDown(S.ShadowWordPainDebuff))
end

local function EvaluateCycleMindgames226(TargetUnit)
  return (Player:Insanity() < 90 and ((DotsUp(TargetUnit, true) and (not S.VoidEruption:CooldownUp() or not S.HungeringVoid:IsAvailable())) or Player:BuffUp(S.VoidformBuff)) and (not S.HungeringVoid:IsAvailable() or Target:DebuffRemains(S.HungeringVoidDebuff) > S.Mindgames:CastTime() or Player:BuffDown(S.VoidformBuff)) and (not S.SearingNightmare:IsAvailable() or EnemiesCount10ySplash < 5))
end

local function EvaluateCycleSilence228(TargetUnit)
  return (TargetUnit:IsInterruptible())
end

local function EvaluateTargetIfFilterSoullettingRuby230(TargetUnit)
  return TargetUnit:HealthPercentage()
end

local function EvaluateTargetIfSoullettingRuby232(TargetUnit)
  return (Player:BuffUp(S.PowerInfusionBuff) or not Settings.Shadow.SelfPI or I.ShadowedOrbofTorment:IsEquipped())
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
    if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft 2"; end
    end
    -- shadowform,if=!buff.shadowform.up
    if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
      if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform 4"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent 6"; end
    end
    -- use_item,name=shadowed_orb_of_torment
    if Settings.Commons.Enabled.Trinkets and I.ShadowedOrbofTorment:IsEquippedAndReady() then
      if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment 8"; end
    end
    -- variable,name=mind_sear_cutoff,op=set,value=2
    VarMindSearCutoff = 2
    -- vampiric_touch,if=!talent.damnation.enabled
    if S.VampiricTouch:IsCastable() and (not S.Damnation:IsAvailable()) then
      if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 10"; end
    end
    -- mind_blast,if=talent.damnation.enabled
    if S.MindBlast:IsReady() and (S.Damnation:IsAvailable()) then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 11"; end
    end
    -- Manually added: mind_blast,if=talent.misery.enabled&(!runeforge.talbadars_stratagem.equipped|!talent.void_torrent.enabled)
    if S.MindBlast:IsCastable() and (S.Misery:IsAvailable() and (not TalbadarEquipped or not S.VoidTorrent:IsAvailable())) then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 12"; end
    end
    -- Manually added: void_torrent,if=talent.misery.enabled&runeforge.talbadars_stratagem.equipped
    if S.VoidTorrent:IsCastable() and (S.Misery:IsAvailable() and TalbadarEquipped) then
      if Cast(S.VoidTorrent, nil, nil, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent 14"; end
    end
    -- Manually added: mind_flay,if=talent.misery.enabled&runeforge.talbadars_stratagem.equipped&!talent.void_torrent.enabled
    if S.MindFlay:IsCastable() and (S.Misery:IsAvailable() and TalbadarEquipped and not S.VoidTorrent:IsAvailable()) then
      if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 15"; end
    end
    -- Manually added: shadow_word_pain,if=!talent.misery.enabled
    if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
      if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 16"; end
    end
  end
end

local function Trinkets()
  -- use_item,name=empyreal_ordnance,if=cooldown.void_eruption.remains<=12|cooldown.void_eruption.remains>27
  if I.EmpyrealOrdinance:IsEquippedAndReady() and (S.VoidEruption:CooldownRemains() <= 12 or S.VoidEruption:CooldownRemains() > 27) then
    if Cast(I.EmpyrealOrdinance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "empyreal_ordnance"; end
  end
  -- use_item,name=inscrutable_quantum_device,if=buff.voidform.up&buff.power_infusion.up|fight_remains<=20|buff.power_infusion.up&cooldown.void_eruption.remains+15>fight_remains|buff.voidform.up&cooldown.power_infusion.remains+15>fight_remains|(cooldown.power_infusion.remains>=10&cooldown.void_eruption.remains>=10)&fight_remains>=190
  if I.InscrutableQuantumDevice:IsEquippedAndReady() and (Player:BuffUp(S.VoidformBuff) and Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 20 or Player:BuffUp(S.PowerInfusionBuff) and FightRemains < S.VoidEruption:CooldownRemains() + 15 or Player:BuffUp(S.VoidformBuff) and FightRemains < S.PowerInfusion:CooldownRemains() + 15 or (S.PowerInfusion:CooldownRemains() >= 10 and S.VoidEruption:CooldownRemains() >= 10) and FightRemains >= 190) then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device"; end
  end
  -- use_item,name=macabre_sheet_music,if=cooldown.void_eruption.remains>10
  if I.MacabreSheetMusic:IsEquippedAndReady() and (S.VoidEruption:CooldownRemains() > 10) then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music"; end
  end
  -- use_item,name=soulletting_ruby,if=buff.power_infusion.up|!priest.self_power_infusion|equipped.shadowed_orb_of_torment,target_if=min:target.health.pct
  if I.SoullettingRuby:IsEquippedAndReady() then
    if Everyone.CastTargetIf(I.SoullettingRuby, Enemies40y, "min", EvaluateTargetIfFilterSoullettingRuby230, EvaluateTargetIfSoullettingRuby232) then return "soulletting_ruby"; end
  end
  -- use_item,name=sinful_gladiators_badge_of_ferocity,if=cooldown.void_eruption.remains>=10
  if I.SinfulGladiatorsBadgeofFerocity:IsEquippedAndReady() and (S.VoidEruption:CooldownRemains() >= 10) then
    if Cast(I.SinfulGladiatorsBadgeofFerocity, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sinful_gladiators_badge_of_ferocity"; end
  end
  -- use_item,name=shadowed_orb_of_torment,if=cooldown.power_infusion.remains<=10&cooldown.void_eruption.remains<=10&(covenant.necrolord|covenant.kyrian)|(covenant.venthyr|covenant.night_fae)&(!buff.voidform.up|prev_gcd.1.void_bolt)|fight_remains<=40
  if I.ShadowedOrbofTorment:IsEquippedAndReady() and (S.PowerInfusion:CooldownRemains() <= 10 and S.VoidEruption:CooldownRemains() <= 10 and (CovenantID == 4 or CovenantID == 1) or (CovenantID == 2 or CovenantID == 3) and (Player:BuffDown(S.VoidformBuff) or Player:PrevGCD(1, S.VoidBolt)) or FightRemains <= 40) then
    if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment"; end
  end
  -- use_items,if=buff.voidform.up|buff.power_infusion.up|cooldown.void_eruption.remains>10
  if (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or S.VoidEruption:CooldownRemains() > 10) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
end

local function Cds()
  -- power_infusion,if=priest.self_power_infusion&(buff.voidform.up|!covenant.kyrian&!covenant.necrolord&cooldown.void_eruption.remains>=10|fight_remains<cooldown.void_eruption.remains)&(fight_remains>=cooldown.void_eruption.remains+15&cooldown.void_eruption.remains<=gcd*4|fight_remains>cooldown.power_infusion.duration|fight_remains<cooldown.void_eruption.remains+15|covenant.kyrian|buff.bloodlust.up)
  if S.PowerInfusion:IsCastable() and (Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or CovenantID ~= 1 and S.VoidEruption:CooldownRemains() >= 10 or FightRemains < S.VoidEruption:CooldownRemains()) and (FightRemains >= S.VoidEruption:CooldownRemains() + 15 and S.VoidEruption:CooldownRemains() <= Player:GCD() * 4 or FightRemains > 120 or FightRemains < S.VoidEruption:CooldownRemains() + 15 or CovenantID == 1 or Player:BloodlustUp())) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion 50"; end
  end
  -- silence,target_if=runeforge.sephuzs_proclamation.equipped&(target.is_add|target.debuff.casting.react)
  if S.Silence:IsCastable() and SephuzEquipped then
    if Everyone.CastCycle(S.Silence, Enemies30y, EvaluateCycleSilence228, not Target:IsSpellInRange(S.Silence), Settings.Commons.OffGCDasOffGCD.Silence) then return "silence 51"; end
  end
  -- Covenant: fae_guardians,if=!buff.voidform.up&(!cooldown.void_torrent.up|!talent.void_torrent.enabled)&(variable.dots_up&spell_targets.vampiric_touch==1|variable.vts_applied&spell_targets.vampiric_touch>1)|buff.voidform.up&(soulbind.grove_invigoration.enabled|soulbind.field_of_blossoms.enabled)
  if S.FaeGuardians:IsReady() and (Player:BuffDown(S.VoidformBuff) and (not S.VoidTorrent:CooldownUp() or not S.VoidTorrent:IsAvailable()) and (VarDotsUp and EnemiesCount10ySplash == 1 or VarVTsApplied and EnemiesCount10ySplash > 1) or Player:BuffUp(S.VoidformBuff) and (S.GroveInvigoration:SoulbindEnabled() or S.FieldofBlossoms:SoulbindEnabled())) then
    if Cast(S.FaeGuardians, Settings.Commons.DisplayStyle.Covenant) then return "fae_guardians 52"; end
  end
  -- Covenant: mindgames,target_if=insanity<90&((variable.all_dots_up&(!cooldown.void_eruption.up|!talent.hungering_void.enabled))|buff.voidform.up)&(!talent.hungering_void.enabled|debuff.hungering_void.remains>cast_time|!buff.voidform.up)&(!talent.searing_nightmare.enabled|spell_targets.mind_sear<5)
  if S.Mindgames:IsReady() then
    if Cast(S.Mindgames, Enemies40y, EvaluateCycleMindgames226, not Target:IsSpellInRange(S.Mindgames)) then return "mindgames 54"; end
  end
  -- Covenant: unholy_nova,if=!talent.hungering_void.enabled&variable.dots_up|debuff.hungering_void.up&buff.voidform.up|(cooldown.void_eruption.remains>10|!variable.pool_for_cds)&!buff.voidform.up
  if S.UnholyNova:IsReady() and ((not S.HungeringVoid:IsAvailable()) and VarDotsUp or Target:DebuffUp(S.HungeringVoidDebuff) and Player:BuffUp(S.VoidformBuff) or (S.VoidEruption:CooldownRemains() > 10 or not VarPoolForCDs) and Player:BuffDown(S.VoidformBuff)) then
    if Cast(S.UnholyNova, Settings.Commons.DisplayStyle.Covenant, nil, not Target:IsSpellInRange(S.UnholyNova)) then return "unholy_nova 56"; end
  end
  -- Covenant: boon_of_the_ascended,if=!buff.voidform.up&!cooldown.void_eruption.up&spell_targets.mind_sear>1&!talent.searing_nightmare.enabled|(buff.voidform.up&spell_targets.mind_sear<2&!talent.searing_nightmare.enabled&(prev_gcd.1.void_bolt&(!equipped.empyreal_ordnance|!talent.hungering_void.enabled)|equipped.empyreal_ordnance&trinket.empyreal_ordnance.cooldown.remains<=162&debuff.hungering_void.up))|(buff.voidform.up&talent.searing_nightmare.enabled)
  if S.BoonoftheAscended:IsCastable() and (Player:BuffDown(S.VoidformBuff) and not S.VoidEruption:CooldownUp() and EnemiesCount10ySplash > 1 and not S.SearingNightmare:IsAvailable() or (Player:BuffUp(S.VoidformBuff) and EnemiesCount10ySplash < 2 and not S.SearingNightmare:IsAvailable() and (Player:PrevGCD(1, S.VoidBolt) and (not I.EmpyrealOrdinance:IsEquipped() or not S.HungeringVoid:IsAvailable()) or I.EmpyrealOrdinance:IsEquipped() and I.EmpyrealOrdinance:CooldownRemains() <= 162 and Target:DebuffUp(S.HungeringVoidDebuff))) or (Player:BuffUp(S.VoidformBuff) and S.SearingNightmare:IsAvailable())) then
    if Cast(S.BoonoftheAscended, Settings.Commons.DisplayStyle.Covenant) then return "boon_of_the_ascended 58"; end
  end
  -- call_action_list,name=trinkets
  if (Settings.Commons.Enabled.Trinkets) then
    local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
  end
  -- desperate_prayer,if=health.pct<=75
  if S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer) then return "desperate_prayer 60"; end
  end
end

local function Boon()
  -- ascended_blast,if=spell_targets.mind_sear<=3
  if S.AscendedBlast:IsReady() and (EnemiesCount10ySplash <= 3) then
    if Cast(S.AscendedBlast, Settings.Commons.DisplayStyle.Covenant, nil, not Target:IsSpellInRange(S.AscendedBlast)) then return "ascended_blast 70"; end
  end
  -- ascended_nova,if=spell_targets.ascended_nova>1&spell_targets.mind_sear>1&!talent.searing_nightmare.enabled
  if S.AscendedNova:IsReady() and (#Enemies8yMelee > 1 and EnemiesCount10ySplash > 1 and not S.SearingNightmare:IsAvailable()) then
    if Cast(S.AscendedNova, Settings.Commons.DisplayStyle.Covenant, nil, not Target:IsInRange(8)) then return "ascended_nova 72"; end
  end
end

local function Cwc()
  -- mind_blast,only_cwc=1,target_if=set_bonus.tier28_4pc&buff.dark_thought.up&pet.fiend.active&runeforge.shadowflame_prism.equipped&!buff.voidform.up&pet.your_shadow.remains<fight_remains|buff.dark_thought.up&pet.your_shadow.remains<gcd.max*(3+(!buff.voidform.up)*16)&pet.your_shadow.remains<fight_remains
  if S.MindBlast:IsReady() and (Player:HasTier(28, 4) and Player:BuffUp(S.DarkThoughtBuff) and S.Mindbender:TimeSinceLastCast() < 15 and ShadowflamePrismEquipped and Player:BuffDown(S.VoidformBuff) and Player:BuffRemains(S.LivingShadowBuff) < FightRemains or Player:BuffUp(S.DarkThoughtBuff) and Player:BuffRemains(S.LivingShadowBuff) < Player:GCD() * (3 + num(Player:BuffDown(S.VoidformBuff)) * 16) and Player:BuffRemains(S.LivingShadowBuff) < FightRemains) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 79"; end
  end
  -- searing_nightmare,use_while_casting=1,target_if=(variable.searing_nightmare_cutoff&!variable.pool_for_cds)|(dot.shadow_word_pain.refreshable&spell_targets.mind_sear>1)
  if S.SearingNightmare:IsReady() and Player:IsChanneling(S.MindSear) and ((VarSearingNightmareCutoff and not VarPoolForCDs) or (UnitsRefreshSWPain > 0 and EnemiesCount10ySplash > 1)) then
    if Cast(S.SearingNightmare, nil, nil, not Target:IsInRange(40)) then return "searing_nightmare 80"; end
  end
  -- searing_nightmare,use_while_casting=1,target_if=talent.searing_nightmare.enabled&dot.shadow_word_pain.refreshable&spell_targets.mind_sear>2
  if S.SearingNightmare:IsReady() and Player:IsChanneling(S.MindSear) and (UnitsRefreshSWPain > 0 and EnemiesCount10ySplash > 2) then
    if Cast(S.SearingNightmare, nil, nil, not Target:IsInRange(40)) then return "searing_nightmare 82"; end
  end
  -- mind_blast,only_cwc=1
  -- Manually added condition when MindBlast can be casted while channeling
  if S.MindBlast:IsCastable() and (Player:BuffUp(S.DarkThoughtBuff) and (Player:IsChanneling(S.MindFlay) or Player:IsChanneling(S.MindSear))) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 84"; end
  end
end

local function Main()
  -- call_action_list,name=boon,if=buff.boon_of_the_ascended.up
  if (Player:BuffUp(S.BoonoftheAscendedBuff)) then
    local ShouldReturn = Boon(); if ShouldReturn then return ShouldReturn; end
  end
  -- Manually added: void_bolt,if=buff.dissonant_echoes.up
  if S.VoidBolt:CooldownUp() and (Player:BuffUp(S.DissonantEchoesBuff)) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsInRange(40)) then return "void_bolt 90"; end
  end
  -- void_eruption,if=variable.pool_for_cds&(insanity>=25|pet.fiend.active&runeforge.shadowflame_prism.equipped&!cooldown.mind_blast.up&!cooldown.shadow_word_death.up)&(insanity<=85|talent.searing_nightmare.enabled&variable.searing_nightmare_cutoff)&!cooldown.fiend.up&(!soulbind.volatile_solvent|buff.volatile_solvent_humanoid.up)
  if S.VoidEruption:IsReady() and (VarPoolForCDs and (Player:Insanity() >= 25 or S.Mindbender:TimeSinceLastCast() <= 15 and ShadowflamePrismEquipped and not S.MindBlast:CooldownUp() and not S.ShadowWordDeath:CooldownUp()) and (Player:Insanity() <= 85 or S.SearingNightmare:IsAvailable() and VarSearingNightmareCutoff) and not S.Mindbender:CooldownUp() and ((not S.VolatileSolvent:SoulbindEnabled()) or Player:BuffUp(S.VolatileSolventHumanBuff))) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption, nil, not Target:IsSpellInRange(S.VoidEruption)) then return "void_eruption 92"; end
  end
  -- shadow_word_pain,if=buff.fae_guardians.up&!debuff.wrathful_faerie.up&spell_targets.mind_sear<4
  -- Manually change to VT if using Misery talent
  if S.ShadowWordPain:IsCastable() and (Player:BuffUp(S.FaeGuardiansBuff) and Target:DebuffDown(S.WrathfulFaerieDebuff) and EnemiesCount10ySplash < 4) then
    if S.Misery:IsAvailable() then
      if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 94"; end
    else
      if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 94"; end
    end
  end
  -- mind_sear,target_if=talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff&!dot.shadow_word_pain.ticking&!cooldown.fiend.up&spell_targets.mind_sear>=4
  if S.MindSear:IsReady() and (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff and S.Mindbender:CooldownDown() and EnemiesCount10ySplash >= 4) then
    if Everyone.CastCycle(S.MindSear, Enemies40y, EvaluateCycleMindSear225, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 95"; end
  end
  -- call_action_list,name=cds
  if (CDsON()) then
    local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
  end
  -- mind_sear,target_if=talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff&!dot.shadow_word_pain.ticking&!cooldown.fiend.up
  if S.MindSear:IsCastable() and (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff and UnitsWithoutSWPain > 0 and not S.Mindbender:CooldownUp()) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 97"; end
  end
  -- damnation,target_if=(dot.vampiric_touch.refreshable|dot.shadow_word_pain.refreshable|(!buff.mind_devourer.up&insanity<50))&(buff.dark_thought.stack<buff.dark_thought.max_stack|!set_bonus.tier28_2pc)
  if S.Damnation:IsCastable() then
    if Everyone.CastCycle(S.Damnation, Enemies40y, EvaluateCycleDamnation200, not Target:IsSpellInRange(S.Damnation)) then return "damnation 98"; end
  end
  -- shadow_word_death,if=pet.fiend.active&runeforge.shadowflame_prism.equipped&pet.fiend.remains<=gcd&spell_targets.mind_sear<=7
  if S.ShadowWordDeath:IsReady() and (S.Mindbender:TimeSinceLastCast() <= 15 and ShadowflamePrismEquipped and 15 - S.Mindbender:TimeSinceLastCast() <= Player:GCD() + 0.5 and EnemiesCount10ySplash <= 7) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 99"; end
  end
  -- mind_blast,if=(cooldown.mind_blast.charges>1&(debuff.hungering_void.up|!talent.hungering_void.enabled)|pet.fiend.remains<=cast_time+gcd)&pet.fiend.active&runeforge.shadowflame_prism.equipped&pet.fiend.remains>cast_time&spell_targets.mind_sear<=7|buff.dark_thought.up&buff.voidform.up&!cooldown.void_bolt.up&(!runeforge.shadowflame_prism.equipped|!pet.fiend.active)&set_bonus.tier28_4pc
  if S.MindBlast:IsCastable() and ((S.MindBlast:Charges() > 1 and (Target:DebuffUp(S.HungeringVoidDebuff) or not S.HungeringVoid:IsAvailable()) or (S.Mindbender:TimeSinceLastCast() <= 15 and 15 - S.Mindbender:TimeSinceLastCast() <= S.MindBlast:CastTime() + Player:GCD() + 0.5)) and S.Mindbender:TimeSinceLastCast() <= 15 and ShadowflamePrismEquipped and 15 - S.Mindbender:TimeSinceLastCast() > S.MindBlast:CastTime() and EnemiesCount10ySplash <= 7 or Player:BuffUp(S.DarkThoughtBuff) and Player:BuffUp(S.VoidformBuff) and (not S.VoidBolt:CooldownUp()) and ((not ShadowflamePrismEquipped) or S.Mindbender:TimeSinceLastCast() > 15) and Player:HasTier(28, 4)) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 100"; end
  end
  -- void_bolt,if=insanity<=85&talent.hungering_void.enabled&talent.searing_nightmare.enabled&spell_targets.mind_sear<=6|((talent.hungering_void.enabled&!talent.searing_nightmare.enabled)|spell_targets.mind_sear=1)
  if S.VoidBolt:IsCastable() and (Player:Insanity() <= 85 and S.HungeringVoid:IsAvailable() and S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash <= 6 or ((S.HungeringVoid:IsAvailable() and not S.SearingNightmare:IsAvailable()) or EnemiesCount10ySplash == 1)) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt 101"; end
  end
  -- devouring_plague,if=(set_bonus.tier28_4pc|talent.hungering_void.enabled)&talent.searing_nightmare.enabled&pet.fiend.active&runeforge.shadowflame_prism.equipped&buff.voidform.up&spell_targets.mind_sear<=6
  if S.DevouringPlague:IsReady() and ((Player:HasTier(28, 4) or S.HungeringVoid:IsAvailable()) and S.SearingNightmare:IsAvailable() and S.Mindbender:TimeSinceLastCast() < 15 and ShadowflamePrismEquipped and Player:BuffUp(S.VoidformBuff) and EnemiesCount10ySplash <= 6) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague 101.5"; end
  end
  -- devouring_plague,if=(refreshable|insanity>75|talent.void_torrent.enabled&cooldown.void_torrent.remains<=3*gcd)&(!variable.pool_for_cds|insanity>=85)&(!talent.searing_nightmare.enabled|(talent.searing_nightmare.enabled&!variable.searing_nightmare_cutoff))
  if S.DevouringPlague:IsReady() and ((Target:DebuffRefreshable(S.DevouringPlagueDebuff) or Player:Insanity() > 75 or S.VoidTorrent:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 3 * Player:GCD()) and (not VarPoolForCDs or Player:Insanity() >= 85) and ((not S.SearingNightmare:IsAvailable()) or (S.SearingNightmare:IsAvailable() and not VarSearingNightmareCutoff))) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague 102"; end
  end
  -- void_bolt,if=spell_targets.mind_sear<(4+conduit.dissonant_echoes.enabled)&insanity<=85&talent.searing_nightmare.enabled|!talent.searing_nightmare.enabled
  if S.VoidBolt:IsCastable() and (EnemiesCount10ySplash < (4 + num(S.DissonantEchoes:ConduitEnabled())) and Player:Insanity() <= 85 and S.SearingNightmare:IsAvailable() or not S.SearingNightmare:IsAvailable()) then
    if Cast(S.VoidBolt, nil, nil, Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt 103"; end
  end
  -- shadow_word_death,target_if=(target.health.pct<20&spell_targets.mind_sear<4)|(pet.fiend.active&runeforge.shadowflame_prism.equipped&spell_targets.mind_sear<=7)
  if S.ShadowWordDeath:IsReady() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleShadowWordDeath204, not Target:IsSpellInRange(S.ShadowWordDeath), Settings.Shadow.GCDasOffGCD.ShadowWordDeath) then return "shadow_word_death 104"; end
  end
  -- surrender_to_madness,target_if=target.time_to_die<25&buff.voidform.down
  if S.SurrenderToMadness:IsCastable() then
    if Everyone.CastCycle(S.SurrenderToMadness, Enemies40y, EvaluateCycleSurrenderToMadness206, not Target:IsSpellInRange(S.SurrenderToMadness), Settings.Shadow.OffGCDasOffGCD.SurrenderToMadness) then return "surrender_to_madness 106"; end
  end
  -- void_torrent,target_if=variable.dots_up&(buff.voidform.down|buff.voidform.remains<cooldown.void_bolt.remains|prev_gcd.1.void_bolt&!buff.bloodlust.react&spell_targets.mind_sear<3)&variable.vts_applied&spell_targets.mind_sear<(5+(6*talent.twist_of_fate.enabled))
  if S.VoidTorrent:IsCastable() then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVoidTorrent208, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent 107"; end
  end
  -- mindbender,if=if=(talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff|dot.shadow_word_pain.ticking)&variable.vts_applied
  if S.Mindbender:IsCastable() and CDsON() and ((S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff or Target:DebuffUp(S.ShadowWordPainDebuff)) and VarVTsApplied) then
    if Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender, nil, not Target:IsSpellInRange(S.Mindbender)) then return "shadowfiend/mindbender 108"; end
  end
  -- shadow_word_death,if=runeforge.painbreaker_psalm.equipped&variable.dots_up&target.time_to_pct_20>(cooldown.shadow_word_death.duration+gcd)
  if S.ShadowWordDeath:IsReady() and (PainbreakerEquipped and VarDotsUp and Target:TimeToX(20) > S.ShadowWordDeath:Cooldown() + Player:GCD()) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 112"; end
  end
  -- shadow_crash,if=raid_event.adds.in>10
  if S.ShadowCrash:IsCastable() then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash 114"; end
  end
  -- mind_sear,target_if=spell_targets.mind_sear>variable.mind_sear_cutoff&buff.dark_thought.up,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindSear:IsCastable() and (EnemiesCount10ySplash > VarMindSearCutoff and Player:BuffUp(S.DarkThoughtBuff)) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 118"; end
  end
  -- mind_flay,if=buff.dark_thought.up&variable.dots_up&!buff.voidform.up&!variable.pool_for_cds&cooldown.mind_blast.full_recharge_time>=gcd.max,chain=1,interrupt_immediate=1,interrupt_if=ticks>=4&!buff.dark_thought.up
  if S.MindFlay:IsCastable() and not Player:IsCasting(S.MindFlay) and (Player:BuffUp(S.DarkThoughtBuff) and VarDotsUp and Player:BuffDown(S.VoidformBuff) and (not VarPoolForCDs) and S.MindBlast:FullRechargeTime() >= Player:GCD() + 0.150) then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 120"; end
  end
  -- Manually added: devouring_plague,if=runeforge.talbadars_stratagem.equipped&variable.dots_up&!variable.all_dots_up
  if S.DevouringPlague:IsReady() and (TalbadarEquipped and VarDotsUp and not VarAllDotsUp) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague 121"; end
  end
  -- mind_blast,if=variable.dots_up&raid_event.movement.in>cast_time+0.5&spell_targets.mind_sear<(4+2*talent.misery.enabled+active_dot.vampiric_touch*talent.psychic_link.enabled+(spell_targets.mind_sear>?5)*(pet.fiend.active&runeforge.shadowflame_prism.equipped))&(!runeforge.shadowflame_prism.equipped|!cooldown.fiend.up&runeforge.shadowflame_prism.equipped|variable.vts_applied)
  if S.MindBlast:IsCastable() and (VarDotsUp and EnemiesCount10ySplash < (4 + 2 * num(S.Misery:IsAvailable()) + S.VampiricTouchDebuff:AuraActiveCount() * num(S.PsychicLink:IsAvailable()) + mathmin(5, EnemiesCount10ySplash) * num(S.Mindbender:TimeSinceLastCast() <= 15 and ShadowflamePrismEquipped)) and (not ShadowflamePrismEquipped or not S.Mindbender:CooldownUp() and ShadowflamePrismEquipped or VarVTsApplied)) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 122"; end
  end
  -- vampiric_touch,target_if=refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied)&variable.max_vts>0|(talent.misery.enabled&dot.shadow_word_pain.refreshable)|buff.unfurling_darkness.up
  if S.VampiricTouch:IsCastable() then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVampiricTouch214, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 124"; end
  end
  -- shadow_word_pain,if=refreshable&target.time_to_die>4&!talent.misery.enabled&talent.psychic_link.enabled&spell_targets.mind_sear>2
  if S.ShadowWordPain:IsCastable() and (Target:DebuffRefreshable(S.ShadowWordPainDebuff) and Target:TimeToDie() > 4 and not S.Misery:IsAvailable() and S.PsychicLink:IsAvailable() and EnemiesCount10ySplash > 2) then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 126"; end
  end
  -- shadow_word_pain,target_if=refreshable&target.time_to_die>4&!talent.misery.enabled&!(talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff)&(!talent.psychic_link.enabled|(talent.psychic_link.enabled&spell_targets.mind_sear<=2))
  if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
    if Everyone.CastCycle(S.ShadowWordPain, Enemies40y, EvaluateCycleShadowWordPain220, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 128"; end
  end
  -- fleshcraft,if=soulbind.volatile_solvent&!buff.voidform.up&!buff.power_infusion.up&buff.volatile_solvent_humanoid.remains<10,interrupt_immediate=1,interrupt_if=ticks>=1
  if S.Fleshcraft:IsCastable() and (S.VolatileSolvent:SoulbindEnabled() and Player:BuffDown(S.VoidformBuff) and Player:BuffDown(S.PowerInfusionBuff) and Player:BuffRemains(S.VolatileSolventHumanBuff) < 10) then
    if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft 60"; end
  end
  -- mind_sear,target_if=spell_targets.mind_sear>variable.mind_sear_cutoff,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindSear:IsCastable() and (EnemiesCount10ySplash > VarMindSearCutoff) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 130"; end
  end
  -- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(!buff.dark_thought.up|cooldown.void_bolt.up&(buff.voidform.up|!buff.dark_thought.up&buff.dissonant_echoes.up))
  if S.MindFlay:IsCastable() then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 132"; end
  end
  -- shadow_word_death
  if S.ShadowWordDeath:IsReady() then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 133"; end
  end
  -- shadow_word_pain
  if S.ShadowWordPain:IsCastable() then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 134"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8) -- Ascended Nova
  Enemies30y = Player:GetEnemiesInRange(30) -- Silence, for Sephuz
  Enemies40y = Player:GetEnemiesInRange(40) -- Multiple CastCycle Spells
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount8ySplash = 1
    EnemiesCount10ySplash = 1
  end

  -- Check units within range of target without SWP or with SWP in pandemic range
  UnitsWithoutSWPain = UnitsWithoutSWP(Enemies10ySplash)
  UnitsRefreshSWPain = UnitsRefreshSWP(Enemies10ySplash)

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Calculate fight_remains
    FightRemains = HL.FightRemains(Enemies10ySplash, false)
    -- Store HL.CombatTime into a variable (pool_for_cds variable checks it and fight_remains multiple times)
    CombatTime = HL.CombatTime()
    -- Store FightRemains + CombatTime for cd_management variable
    RemainsPlusTime = FightRemains + CombatTime
    -- Manually Added: Use Dispersion if dying
    if S.Dispersion:IsCastable() and Player:HealthPercentage() < Settings.Shadow.DispersionHP then
      if Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return "dispersion low_hp"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(30, S.Silence, Settings.Commons.OffGCDasOffGCD.Silence, false); if ShouldReturn then return ShouldReturn; end
    -- potion,if=buff.voidform.up|buff.power_infusion.up
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff)) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion_of_spectral_intellect 20"; end
    end
    -- variable,name=dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking
    VarDotsUp = DotsUp(Target, false)
    -- variable,name=all_dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking&dot.devouring_plague.ticking
    VarAllDotsUp = DotsUp(Target, true)
    -- variable,name=searing_nightmare_cutoff,op=set,value=spell_targets.mind_sear>2+buff.voidform.up
    VarSearingNightmareCutoff = (EnemiesCount10ySplash > (2 + num(Player:BuffUp(S.VoidformBuff))))
    -- variable,name=cd_management,op=set,value=(!runeforge.spheres_harmony.equipped&(!covenant.necrolord|((fight_remains+time)>=330&time<=200|(fight_remains+time)<=250&(fight_remains+time)>=200))|cooldown.power_infusion.remains<=gcd.max*3|buff.power_infusion.up|fight_remains<=25),default=0
    VarCDManagement = ((not SpheresHarmonyEquipped) and (CovenantID ~= 4 or (RemainsPlusTime >= 330 and CombatTime <= 200 or RemainsPlusTime <= 250 and RemainsPlusTime >= 200)) or S.PowerInfusion:CooldownRemains() < Player:GCD() * 3 or Player:BuffUp(S.PowerInfusionBuff) or FightRemains <= 25)
    -- variable,name=max_vts,op=set,default=1,value=spell_targets.vampiric_touch
    VarMaxVTs = EnemiesCount10ySplash
    -- variable,name=max_vts,op=set,value=5+2*(variable.cd_management&cooldown.void_eruption.remains<=10)&talent.hungering_void.enabled,if=talent.searing_nightmare.enabled&spell_targets.mind_sear=7
    if S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash == 7 then
      VarMaxVTs = 5 + 2 * num((VarCDManagement and S.VoidEruption:CooldownRemains() <= 10) and S.HungeringVoid:IsAvailable())
    end
    -- variable,name=max_vts,op=set,value=0,if=talent.searing_nightmare.enabled&spell_targets.mind_sear>7
    if S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > 7 then
      VarMaxVTs = 0
    end
    -- variable,name=max_vts,op=set,value=4,if=talent.searing_nightmare.enabled&spell_targets.mind_sear=8&!talent.shadow_crash.enabled
    if S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash == 8 and not S.ShadowCrash:IsAvailable() then
      VarMaxVTs = 4
    end
    -- variable,name=max_vts,op=set,value=(spell_targets.mind_sear<=5)*spell_targets.mind_sear,if=buff.voidform.up
    if Player:BuffUp(S.VoidformBuff) then
      VarMaxVTs = num(EnemiesCount10ySplash <= 5) * EnemiesCount10ySplash
    end
    -- variable,name=is_vt_possible,op=set,value=0,default=1
    VarIsVTPossible = 0
    -- variable,name=is_vt_possible,op=set,value=1,target_if=max:(target.time_to_die*dot.vampiric_touch.refreshable),if=target.time_to_die>=18
    if Target:TimeToDie() >= 18 then
      VarIsVTPossible = 1
    end
    -- variable,name=vts_applied,op=set,value=active_dot.vampiric_touch>=variable.max_vts|!variable.is_vt_possible
    VarVTsApplied = (S.VampiricTouchDebuff:AuraActiveCount() >= VarMaxVTs or not VarIsVTPossible)
    -- variable,name=pool_for_cds,op=set,value=cooldown.void_eruption.up&variable.cd_management
    VarPoolForCDs = (S.VoidEruption:CooldownUp() and VarCDManagement)
    if (CDsON()) then
      -- fireblood,if=buff.voidform.up
      if S.Fireblood:IsCastable() and (Player:BuffUp(S.VoidformBuff)) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 22"; end
      end
      -- berserking,if=buff.voidform.up
      if S.Berserking:IsCastable() and (Player:BuffUp(S.VoidformBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 24"; end
      end
      -- lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
      if S.LightsJudgment:IsCastable() and (EnemiesCount10ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 26"; end
      end
      -- ancestral_call,if=buff.voidform.up
      if S.AncestralCall:IsCastable() and (Player:BuffUp(S.VoidformBuff)) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 28"; end
      end
    end
    -- call_action_list,name=cwc
    if (Player:IsChanneling()) then
      local ShouldReturn = Cwc(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=main
    if (true) then
      local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
  S.VampiricTouchDebuff:RegisterAuraTracking()
  --HR.Print("Shadow Priest rotation is currently a work in progress, but has been updated for patch 9.1.5.")
end

HR.SetAPL(258, APL, Init)
