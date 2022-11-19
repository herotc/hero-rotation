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
  I.ArchitectsIngenuityCore:ID(),
  I.MacabreSheetMusic:ID(),
  I.SoullettingRuby:ID(),
  I.ScarsofFraternalStrife:ID()
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
local CombatTime = 0
local BossFightRemains = 11111
local FightRemains = 11111
local RemainsPlusTime = 0
local VarDotsUp = false
local VarAllDotsUp = false
local VarMindSearCutoff = 1
local VarMaxVTs = 0
local VarIsVTPossible = false
local VarVTsApplied = false
local VarPoolForCDs = false
local VarSFP = false
local DarkThoughtMaxStacks = 2
local TalbadarEquipped = Player:HasLegendaryEquipped(161)
local ShadowflamePrismEquipped = Player:HasLegendaryEquipped(159)

HL:RegisterForEvent(function()
  VarDotsUp = false
  VarAllDotsUp = false
  VarMindSearCutoff = 1
  VarSearingNightmareCutoff = false
  VarPoolForCDs = false
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

-- Player Covenant
-- 0: none, 1: Kyrian, 2: Venthyr, 3: Night Fae, 4: Necrolord
local CovenantID = Player:CovenantID()

-- Update CovenantID if we change Covenants
HL:RegisterForEvent(function()
  CovenantID = Player:CovenantID()
end, "COVENANT_CHOSEN")

HL:RegisterForEvent(function()
  TalbadarEquipped = Player:HasLegendaryEquipped(161)
  ShadowflamePrismEquipped = Player:HasLegendaryEquipped(159)
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
    return (
        tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff) and
            tar:DebuffUp(S.DevouringPlagueDebuff))
  else
    return (tar:DebuffUp(S.ShadowWordPainDebuff) and tar:DebuffUp(S.VampiricTouchDebuff))
  end
end

local function EvaluateCycleDamnation71(TargetUnit)
  --target_if=dot.vampiric_touch.refreshable&variable.is_vt_possible|dot.shadow_word_pain.refreshable
  return (
      TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and VarIsVTPossible or
          TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff))
end

local function EvaluateCycleVoidTorrent84(TargetUnit)
  --target_if=variable.dots_up
  return DotsUp(TargetUnit, false)
end

local function EvaluateCycleVampiricTouch77(TargetUnit)
  --target_if=(refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied)&variable.max_vts>0|(talent.misery.enabled&dot.shadow_word_pain.refreshable))  &cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight
  return (
      TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() >= 18 and
          (TargetUnit:DebuffUp(S.VampiricTouchDebuff) or not VarVTsApplied) and VarMaxVTs > 0 or
          (S.Misery:IsAvailable() and TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff)) and
          S.ShadowCrash:CooldownRemains() >= TargetUnit:DebuffRemains(S.VampiricTouchDebuff) and
          S.ShadowCrash:TimeSinceLastCast() <= 5)
end

local function EvaluateCycleShadowWordPain78(TargetUnit)
  --shadow_word_pain,target_if=refreshable&target.time_to_die>=18&!talent.misery.enabled
  return (TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) and TargetUnit:TimeToDie() >= 18)
end

local function EvaluateCycleMindSear225(TargetUnit)
  return (TargetUnit:DebuffDown(S.ShadowWordPainDebuff))
end

local function EvaluateTargetIfFilterSoullettingRuby230(TargetUnit)
  return TargetUnit:HealthPercentage()
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- fleshcraft,if=soulbind.pustule_eruption|soulbind.volatile_solvent
    if S.Fleshcraft:IsCastable() and (S.PustuleEruption:SoulbindEnabled() or S.VolatileSolvent:SoulbindEnabled()) then
      if Cast(S.Fleshcraft, nil, Settings.Commons.DisplayStyle.Covenant) then return "fleshcraft 10"; end
    end
    -- shadowform,if=!buff.shadowform.up
    if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
      if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform 20"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent 30"; end
    end
    -- use_item,name=shadowed_orb_of_torment
    if Settings.Commons.Enabled.Trinkets and I.ShadowedOrbofTorment:IsEquippedAndReady() then
      if Cast(I.ShadowedOrbofTorment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "shadowed_orb_of_torment 40"; end
    end
    -- variable,name=mind_sear_cutoff,op=set,value=2
    VarMindSearCutoff = 2
    --shadow_crash,if=talent.shadow_crash.enabled
    if S.ShadowCrash:IsCastable() then
      if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash 50"; end
    end
    -- mind_blast,if=talent.damnation.enabled&!talent.shadow_crash.enabled
    if S.MindBlast:IsReady() and (S.Damnation:IsAvailable() and not S.ShadowCrash:IsAvailable()) then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 60"; end
    end
    -- vampiric_touch,if=!talent.damnation.enabled&!talent.shadow_crash.enabled
    if S.VampiricTouch:IsCastable() and (not S.Damnation:IsAvailable() and not S.ShadowCrash:IsAvailable()) then
      if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 70"; end
    end
    -- Manually added: mind_blast,if=talent.misery.enabled&(!runeforge.talbadars_stratagem.equipped|!talent.void_torrent.enabled)
    if S.MindBlast:IsCastable() and
        (S.Misery:IsAvailable() and (not TalbadarEquipped or not S.VoidTorrent:IsAvailable())) then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 80"; end
    end
    -- Manually added: void_torrent,if=talent.misery.enabled&runeforge.talbadars_stratagem.equipped
    if S.VoidTorrent:IsCastable() and (S.Misery:IsAvailable() and TalbadarEquipped) then
      if Cast(S.VoidTorrent, nil, nil, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent 90"; end
    end
    -- Manually added: mind_flay,if=talent.misery.enabled&runeforge.talbadars_stratagem.equipped&!talent.void_torrent.enabled
    if S.MindFlay:IsCastable() and (S.Misery:IsAvailable() and TalbadarEquipped and not S.VoidTorrent:IsAvailable()) then
      if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 100"; end
    end
    -- Manually added: shadow_word_pain,if=!talent.misery.enabled
    if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
      if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 110"; end
    end
  end
end

local function Trinkets()
  -- use_item,name=scars_of_fraternal_strife,if=(!buff.scars_of_fraternal_strife_4.up&time>1)|(buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|cooldown.void_eruption.remains>10)
  if I.ScarsofFraternalStrife:IsEquippedAndReady() and
      (
      not Player:BuffUp(S.ScarsofFraternalStrifeBuff4) or
          (
          Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or (not Settings.Shadow.SelfPI) or
              Player:BuffUp(S.DarkAscension) or S.VoidTorrent:CooldownRemains() > 10)) then
    if Cast(I.ScarsofFraternalStrife, nil, Settings.Commons.DisplayStyle.Trinkets) then return "scars_of_fraternal_strife trinkets 10"; end
  end
  -- use_item,name=macabre_sheet_music,if=cooldown.void_eruption.remains>10|cooldown.dark_ascension.remains>10
  if I.MacabreSheetMusic:IsEquippedAndReady() and
      (S.VoidEruption:CooldownRemains() > 10 or S.DarkAscension:CooldownRemains() > 10) then
    if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music trinkets 20"; end
  end
  -- use_item,name=soulletting_ruby,if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|cooldown.void_eruption.remains>10,target_if=min:target.health.pct
  if I.SoullettingRuby:IsEquippedAndReady() and
      (
      Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or (not Settings.Shadow.SelfPI) or
          Player:BuffUp(S.DarkAscension) or S.VoidTorrent:CooldownRemains() > 10) then
    if Everyone.CastTargetIf(I.SoullettingRuby, Enemies40y, "min", EvaluateTargetIfFilterSoullettingRuby230, nil,
      not Target:IsInRange(40), nil, Settings.Commons.DisplayStyle.Trinkets) then return "soulletting_ruby trinkets 30"; end
  end
  -- use_item,name=architects_ingenuity_core
  if I.ArchitectsIngenuityCore:IsEquippedAndReady() then
    if Cast(I.ArchitectsIngenuityCore, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "architects_ingenuity_core trinkets 40"; end
  end
  -- if=buff.voidform.up|buff.power_infusion.up|buff.dark_ascension.up|cooldown.void_eruption.remains>10
  if (
      Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.PowerInfusionBuff) or Player:BuffUp(S.DarkAscension) or
          S.VoidEruption:CooldownRemains() > 10) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " ..
            TrinketToUse:Name();
      end
    end
  end
end

local function Cds()
  -- power_infusion,if=(buff.voidform.up|buff.dark_ascension.up)
  if S.PowerInfusion:IsCastable() and
      (Settings.Shadow.SelfPI and (Player:BuffUp(S.VoidformBuff) or Player:BuffUp(S.DarkAscension))) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion cds 10"; end
  end
  -- void_eruption,if=!cooldown.fiend.up&(pet.fiend.active|!talent.mindbender|covenant.night_fae)&(cooldown.mind_blast.charges=0|time>15|buff.shadowy_insight.up&cooldown.mind_blast.charges=buff.shadowy_insight.stack)
  if S.VoidEruption:IsCastable() and
      (
      S.Mindbender:CooldownDown() and
          (S.Mindbender:TimeSinceLastCast() <= 15 or not S.Mindbender:IsAvailable() or CovenantID == 3) and
          (
          S.MindBlast:Charges() == 0 or CombatTime > 15 or
              Player:BuffUp(S.ShadowyInsight) and S.MindBlast:Charges() == Player:BuffStack(S.ShadowyInsight))) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption) then return "void_eruption cds 20"; end
  end
  -- dark_ascension,if=pet.fiend.active&cooldown.mind_blast.charges<2|!talent.mindbender&!cooldown.fiend.up|covenant.night_fae&cooldown.fiend.remains>=15&cooldown.fae_guardians.remains>=4*gcd.max
  if S.DarkAscension:IsCastable() and not Player:IsCasting(S.DarkAscension) and
      (
      S.Mindbender:TimeSinceLastCast() <= 15 and S.MindBlast:Charges() < 2 or
          not S.Mindbender:IsAvailable() and S.ShadowFiend:CooldownDown() or
          CovenantID == 3 and S.Mindbender:CooldownRemains() >= 15 and
          S.FaeGuardians:CooldownRemains() >= 4 * Player:GCD()) then
    if Cast(S.DarkAscension, Settings.Shadow.GCDasOffGCD.DarkAscension) then return "dark_ascension cds 30"; end
  end
  -- call_action_list,name=trinkets
  if (Settings.Commons.Enabled.Trinkets) then
    local ShouldReturn = Trinkets();
    if ShouldReturn then return ShouldReturn; end
  end
  -- unholy_nova,if=dot.shadow_word_pain.ticking&variable.vts_applied|action.shadow_crash.in_flight
  if S.UnholyNova:IsReady() and
      (Target:DebuffUp(S.ShadowWordPainDebuff) and VarVTsApplied or S.ShadowCrash:TimeSinceLastCast() <= 5) then
    if Cast(S.UnholyNova, Settings.Commons.DisplayStyle.Covenant, nil, not Target:IsSpellInRange(S.UnholyNova)) then return "unholy_nova cds 50"; end
  end
  --fae_guardians,if=(dot.shadow_word_pain.ticking&variable.vts_applied|action.shadow_crash.in_flight)&(!talent.void_eruption|buff.voidform.up&!cooldown.void_bolt.up&cooldown.mind_blast.full_recharge_time>gcd.max|!cooldown.void_eruption.up)
  if S.FaeGuardians:IsReady() and
      (Target:DebuffUp(S.ShadowWordPainDebuff) and VarVTsApplied or S.ShadowCrash:TimeSinceLastCast() <= 5) and
      (
      not S.VoidEruption:IsAvailable() or
          Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownUp() and S.MindBlast:FullRechargeTime() > Player:GCD() or
          not S.VoidEruption:CooldownUp()) then
    if Cast(S.FaeGuardians, Settings.Commons.DisplayStyle.Covenant) then return "fae_guardians cds 60"; end
  end
  -- mindbender,if=(dot.shadow_word_pain.ticking&variable.vts_applied|action.shadow_crash.in_flight)
  if S.Mindbender:IsCastable() and
      (Target:DebuffUp(S.ShadowWordPainDebuff) and VarVTsApplied or S.ShadowCrash:TimeSinceLastCast() <= 5) then
    if Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender, nil, not Target:IsSpellInRange(S.Mindbender)) then return "shadowfiend/mindbender cds 70"; end
  end
  -- desperate_prayer,if=health.pct<=75
  if S.DesperatePrayer:IsCastable() and (Player:HealthPercentage() <= Settings.Shadow.DesperatePrayerHP) then
    if Cast(S.DesperatePrayer) then return "desperate_prayer cds 80"; end
  end
end

local function Main()
  -- call_action_list,name=cds
  if (CDsON()) then
    local ShouldReturn = Cds();
    if ShouldReturn then return ShouldReturn; end
  end
  -- shadow_word_death,if=pet.fiend.active&variable.sfp&(pet.fiend.remains<=gcd|target.health.pct<20)&spell_targets.mind_sear<=7
  if S.ShadowWordDeath:IsCastable() and
      (
      S.Mindbender:TimeSinceLastCast() <= 15 and VarSFP and
          (15 - S.Mindbender:TimeSinceLastCast() > Player:GCD() or Target:HealthPercentage() < 20) and
          EnemiesCount10ySplash <= 7) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil,
      not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 10"; end
  end
  -- mind_blast,if=(cooldown.mind_blast.full_recharge_time<=gcd.max|pet.fiend.remains<=cast_time+gcd.max)&pet.fiend.active&variable.sfp&pet.fiend.remains>cast_time&spell_targets.mind_sear<=7
  if S.MindBlast:IsCastable() and
      (
      (
          S.MindBlast:FullRechargeTime() <= Player:GCD() or
              15 - S.Mindbender:TimeSinceLastCast() <= S.MindBlast:CastTime() + Player:GCD() + 0.5) and
          S.Mindbender:TimeSinceLastCast() <= 15 and VarSFP and
          15 - S.Mindbender:TimeSinceLastCast() > S.MindBlast:CastTime() and EnemiesCount10ySplash <= 7) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 20"; end
  end
  -- damnation,target_if=dot.vampiric_touch.refreshable&variable.is_vt_possible|dot.shadow_word_pain.refreshable
  if S.Damnation:IsCastable() then
    if Everyone.CastCycle(S.Damnation, Enemies40y, EvaluateCycleDamnation71, not Target:IsSpellInRange(S.Damnation)) then return "damnation main 30"; end
  end
  -- void_bolt,if=variable.dots_up&insanity<=85
  if S.VoidBolt:IsCastable() and VarDotsUp and Player:Insanity() <= 85 then
    if Cast(S.VoidBolt, nil, nil, not Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt main 40"; end
  end
  -- mind_sear,target_if=(spell_targets.mind_sear>1|buff.voidform.up)&buff.mind_devourer.up
  if S.MindSear:IsReady() and (EnemiesCount10ySplash > 1 or Player:BuffUp(S.VoidformBuff)) and
      Player:BuffUp(S.MindDevourerBuff) then
    if Everyone.CastCycle(S.MindSear, Enemies40y, EvaluateCycleMindSear225, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear main 50"; end
  end
  -- mind_sear,target_if=spell_targets.mind_sear>variable.mind_sear_cutoff,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindSear:IsReady() and (EnemiesCount10ySplash > VarMindSearCutoff) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear main 60"; end
  end
  -- devouring_plague,if=(refreshable&!variable.pool_for_cds|insanity>75|talent.void_torrent&cooldown.void_torrent.remains<=3*gcd|buff.mind_devourer.up&cooldown.mind_blast.full_recharge_time<=2*gcd.max&!cooldown.void_eruption.up&talent.void_eruption)
  if S.DevouringPlague:IsReady() and
      (
      (
          Target:DebuffRefreshable(S.DevouringPlagueDebuff) and not VarPoolForCDs or Player:Insanity() > 75 or
              S.VoidTorrent:IsAvailable() and S.VoidTorrent:CooldownRemains() <= 3 * Player:GCD() or
              Player:BuffUp(S.MindDevourerBuff) and S.MindBlast:FullRechargeTime() <= 2 * Player:GCD() and
              not S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable())) then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 70"; end
  end
  -- shadow_word_death,target_if=(target.health.pct<20&spell_targets.mind_sear<4)&(!variable.sfp|cooldown.fiend.remains>=10)|(pet.fiend.active&variable.sfp&spell_targets.mind_sear<=7)|buff.deathspeaker.up&(cooldown.fiend.remains+gcd.max)>buff.deathspeaker.remains
  if S.ShadowWordDeath:IsCastable() and
      (
      (Target:HealthPercentage() < 20 and EnemiesCount10ySplash < 4) and
          (not VarSFP or S.Mindbender:CooldownRemains() >= 10) or
          (S.Mindbender:TimeSinceLastCast() <= 15 and VarSFP and EnemiesCount10ySplash <= 7) and
          Player:BuffUp(S.DeathSpeakerBuff) and
          (S.Mindbender:CooldownRemains() + Player:GCD()) > Player:BuffRemains(S.DeathSpeakerBuff)) then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil,
      not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death main 80"; end
  end
  -- vampiric_touch,target_if=(refreshable&target.time_to_die>=18&(dot.vampiric_touch.ticking|!variable.vts_applied)&variable.max_vts>0|(talent.misery.enabled&dot.shadow_word_pain.refreshable))&cooldown.shadow_crash.remains>=dot.vampiric_touch.remains&!action.shadow_crash.in_flight
  if S.VampiricTouch:IsCastable() then
    if Everyone.CastCycle(S.VampiricTouch, Enemies40y, EvaluateCycleVampiricTouch77,
      not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 90"; end
  end
  -- shadow_word_pain,target_if=refreshable&target.time_to_die>=18&!talent.misery.enabled
  if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
    if Everyone.CastCycle(S.ShadowWordPain, Enemies40y, EvaluateCycleShadowWordPain78,
      not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain main 100"; end
  end
  -- mind_blast,if=variable.vts_applied&(!buff.mind_devourer.up|cooldown.void_eruption.up&talent.void_eruption)
  if S.MindBlast:IsCastable() and
      (
      VarVTsApplied and
          (not Player:BuffUp(S.MindDevourerBuff) or S.VoidEruption:CooldownUp() and S.VoidEruption:IsAvailable())) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast main 110"; end
  end
  -- mindgames,if=spell_targets.mind_sear<5&variable.all_dots_up
  if (
      S.Mindgames:IsAvailable() and S.Mindgames:IsReady() and not Player:IsCasting(S.Mindgames) or
          CovenantID == 2 and
          (S.MindgamesCov:IsReady() and not S.Mindgames:IsAvailable() and S.Mindgames:CooldownDown()
          )) and
      (EnemiesCount10ySplash < 5 and VarAllDotsUp) then
    if Cast(S.Mindgames, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsSpellInRange(S.Mindgames)) then return "mindgames main 120"; end
  end
  --shadow_crash,if=raid_event.adds.in>10
  if S.ShadowCrash:IsCastable() then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 130"; end
  end
  -- dark_void,if=raid_event.adds.in>20
  if S.DarkVoid:IsCastable() then
    if Cast(S.DarkVoid, Settings.Shadow.GCDasOffGCD.DarkVoid, nil, not Target:IsInRange(40)) then return "dark_void main 140"; end
  end
  -- devouring_plague,if=buff.voidform.up&variable.dots_up
  if S.DevouringPlague:IsReady() and Player:BuffUp(S.VoidformBuff) and VarDotsUp then
    if Cast(S.DevouringPlague, nil, nil, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague main 150"; end
  end
  -- void_torrent,if=insanity<=35,target_if=variable.dots_up
  if S.VoidTorrent:IsCastable() and Player:Insanity() <= 35 then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVoidTorrent84, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent 160"; end
  end
  -- vampiric_touch,if=buff.unfurling_darkness.up
  if S.VampiricTouch:IsCastable() and Player:BuffUp(S.UnfurlingDarknessBuff) then
    if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch main 170"; end
  end
  -- mind_flay,if=buff.mind_flay_insanity.up&variable.dots_up&(!buff.surge_of_darkness.up|talent.screams_of_the_void)
  if S.MinFlayInsanity:IsCastable() and
      (
      Player:BuffUp(S.MinFlayInsanityBuff) and VarDotsUp and
          (not Player:BuffUp(S.SurgeOfDarknessBuff) or S.ScreamsOfTheVoid:IsAvailable())) then
    if Cast(S.MinFlayInsanity, nil, nil, not Target:IsSpellInRange(S.MinFlayInsanity)) then return "mind_flay_insanity main 180"; end
  end
  -- halo,if=raid_event.adds.in>20&(spell_targets.halo>1|variable.all_dots_up)
  if S.Halo:IsCastable() and (EnemiesCount30y > 1 or VarAllDotsUp) then
    if Cast(S.Halo, nil, nil, not Target:IsInRange(40)) then return "halo main 190"; end
  end
  -- divine_star,if=spell_targets.divine_star>1
  if S.DivineStar:IsCastable() and EnemiesCount30y > 1 then
    if Cast(S.DivineStar, nil, nil, not Target:IsInRange(40)) then return "divine_star main 200"; end
  end
  -- mind_spike,if=buff.surge_of_darkness.up|!conduit.dissonant_echoes&(!talent.mental_decay|dot.vampiric_touch.remains>=(cooldown.shadow_crash.remains+action.shadow_crash.travel_time))&(talent.mind_melt|!talent.idol_of_cthun)
  --TODO : shadow crash travel time
  if S.MinFlayInsanity:IsCastable() and
      (
      Player:BuffUp(S.MinFlayInsanityBuff) and VarDotsUp and
          (not Player:BuffUp(S.SurgeOfDarknessBuff) or S.ScreamsOfTheVoid:IsAvailable())) then
    if Cast(S.MinFlayInsanity, nil, nil, not Target:IsSpellInRange(S.MinFlayInsanity)) then return "mind_flay_insanity main 180"; end
  end
  -- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindFlay:IsCastable() then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay main 190"; end
  end
  -- shadow_crash,if=raid_event.adds.in>30
  if S.ShadowCrash:IsCastable() then
    if Cast(S.ShadowCrash, Settings.Shadow.GCDasOffGCD.ShadowCrash, nil, not Target:IsInRange(40)) then return "shadow_crash main 200"; end
  end
  -- shadow_word_death,target_if=target.health.pct<20
  if S.ShadowWordDeath:IsCastable() and Target:HealthPercentage() < 20 then
    if Cast(S.DivinShadowWordDeatheStar, nil, nil, not Target:IsInRange(40)) then return "shadow_word_death main 210"; end
  end
  -- divine_star
  if S.DivineStar:IsCastable() then
    if Cast(S.DivineStar, nil, nil, not Target:IsInRange(40)) then return "divine_star main 220"; end
  end
  -- shadow_word_death
  if S.ShadowWordDeath:IsCastable() then
    if Cast(S.ShadowWordDeath, Settings.Shadow.GCDasOffGCD.ShadowWordDeath, nil,
      not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 230"; end
  end
  -- shadow_word_pain
  if S.ShadowWordPain:IsCastable() then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 240"; end
  end
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
  end

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat();
    if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- Store HL.CombatTime into a variable (pool_for_cds variable checks it and fight_remains multiple times)
    CombatTime = HL.CombatTime()
    -- Store FightRemains + CombatTime for cd_management variable
    RemainsPlusTime = FightRemains + CombatTime
    -- Manually Added: Use Dispersion if dying
    if S.Dispersion:IsCastable() and Player:HealthPercentage() < Settings.Shadow.DispersionHP then
      if Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return "dispersion low_hp"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(30, S.Silence, Settings.Commons.OffGCDasOffGCD.Silence, false);
    if ShouldReturn then return ShouldReturn; end
    -- potion,if=buff.power_infusion.up&(buff.bloodlust.up|(time+fight_remains)>=320)
    if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.Potions and
        (Player:BuffUp(S.PowerInfusionBuff) and (Player:BloodlustUp() or RemainsPlusTime >= 320)) then
      if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion_of_spectral_intellect 20"; end
    end
    -- variable,name=dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking
    VarDotsUp = DotsUp(Target, false)
    -- variable,name=all_dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking&dot.devouring_plague.ticking
    VarAllDotsUp = DotsUp(Target, true)
    -- variable,name=max_vts,op=set,default=1,value=spell_targets.vampiric_touch
    VarMaxVTs = EnemiesCount10ySplash
    -- variable,name=max_vts,op=set,value=(spell_targets.mind_sear<=5)*spell_targets.mind_sear,if=buff.voidform.up
    if Player:BuffUp(S.VoidformBuff) then
      VarMaxVTs = num(EnemiesCount10ySplash <= 5) * EnemiesCount10ySplash
    end
    -- variable,name=is_vt_possible,op=set,value=0,default=1
    VarIsVTPossible = false
    -- variable,name=is_vt_possible,op=set,value=1,target_if=max:(target.time_to_die*dot.vampiric_touch.refreshable),if=target.time_to_die>=18
    if Target:TimeToDie() >= 18 then
      VarIsVTPossible = true
    end
    -- variable,name=vts_applied,op=set,value=active_dot.vampiric_touch>=variable.max_vts|!variable.is_vt_possible
    VarVTsApplied = (S.VampiricTouchDebuff:AuraActiveCount() >= VarMaxVTs or not VarIsVTPossible)
    --variable,name=sfp,op=set,value=runeforge.shadowflame_prism.equipped|talent.inescapable_torment
    VarSFP = ShadowflamePrismEquipped or S.InescapableTorment:IsAvailable();
    -- variable,name=pool_for_cds,op=set,value=(cooldown.void_eruption.remains<=gcd.max*3&talent.void_eruption|cooldown.dark_ascension.up&talent.dark_ascension)
    VarPoolForCDs = (
        S.VoidEruption:CooldownRemains() <= Player:GCD() * 3 and S.VoidEruption:IsAvailable() or
            S.DarkAscension:CooldownUp() and S.DarkAscension:IsAvailable())
    -- variable,name=pool_amount,op=set,value=60
    VarPoolAmount = 60
    if (CDsON()) then
      -- blood_fury,if=buff.power_infusion.up
      if S.BloodFury:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff)) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury 21"; end
      end
      -- fireblood,if=buff.power_infusion.up
      if S.Fireblood:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff)) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood 22"; end
      end
      -- berserking,if=buff.power_infusion.up
      if S.Berserking:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking 24"; end
      end
      -- lights_judgment,if=spell_targets.lights_judgment>=2|(!raid_event.adds.exists|raid_event.adds.in>75)
      if S.LightsJudgment:IsCastable() and (EnemiesCount10ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil,
          not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment 26"; end
      end
      -- ancestral_call,if=buff.power_infusion.up
      if S.AncestralCall:IsCastable() and (Player:BuffUp(S.PowerInfusionBuff)) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call 28"; end
      end
    end
    -- use_item,name=hyperthread_wristwraps,if=0
    -- Intention is to disable use of these entirely, so we'll ignore it.
    -- use_item,name=ring_of_collapsing_futures,if=(buff.temptation.stack<1&target.time_to_die>60)|target.time_to_die<60
    if I.RingofCollapsingFutures:IsEquippedAndReady() and
        ((Player:BuffDown(S.TemptationBuff) and FightRemains > 60) or FightRemains < 60) then
      if Cast(I.RingofCollapsingFutures, nil, Settings.Commons.DisplayStyle.Items) then return "ring_of_collapsing_futures 30"; end
    end
    -- run_action_list,name=main
    if (true) then
      local ShouldReturn = Main();
      if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()
  S.VampiricTouchDebuff:RegisterAuraTracking()

  HR.Print("Shadow Priest rotation has not been updated for pre-patch 10.0. It may not function properly or may cause errors in-game.")
end

HR.SetAPL(258, APL, Init)
