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
local match      = string.match

-- Azerite Essence Setup
local AE         = DBC.AzeriteEssences
local AESpellIDs = DBC.AzeriteEssenceSpellIDs

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Priest.Shadow
local I = Item.Priest.Shadow

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.AzsharasFontofPower:ID(),
  I.SinfulGladiatorsBadgeofFerocity:ID()
}

-- Rotation Var
local ShouldReturn -- Used to get the return string
local Enemies8yMelee, Enemies15yMelee, Enemies30y, Enemies40y, Enemies10ySplash
local EnemiesCount8ySplash, EnemiesCount10ySplash
local PetActiveCD
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
local VarDotsUp = false
local VarAllDotsUp = false
local VarMindSearCutoff = 1
local VarSearingNightmareCutoff = false
local VarPoolForCDs = false
local SephuzEquipped = HL.LegendaryEnabled(202)
local PainbreakerEquipped = HL.LegendaryEnabled(158)
local ShadowflamePrismEquipped = HL.LegendaryEnabled(159)

HL:RegisterForEvent(function()
  VarDotsUp = false
  VarAllDotsUp = false
  VarMindSearCutoff = 1
  VarSearingNightmareCutoff = false
  VarPoolForCDs = false
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  SephuzEquipped = HL.LegendaryEnabled(202)
  PainbreakerEquipped = HL.LegendaryEnabled(158)
  ShadowflamePrismEquipped = HL.LegendaryEnabled(159)
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
  return (not DotsUp(TargetUnit, true))
end

local function EvaluateCycleDevouringPlage202(TargetUnit)
  return ((TargetUnit:DebuffRefreshable(S.DevouringPlagueDebuff) or Player:Insanity() > 75) and (not VarPoolForCDs or Player:Insanity() >= 85) and (not S.SearingNightmare:IsAvailable() or (S.SearingNightmare:IsAvailable() and not VarSearingNightmareCutoff)))
end

local function EvaluateCycleShadowWordDeath204(TargetUnit)
  return ((TargetUnit:HealthPercentage() < 20 and EnemiesCount10ySplash < 4) or (S.Mindbender:CooldownRemains() > PetActiveCD and ShadowflamePrismEquipped))
end

local function EvaluateCycleSurrenderToMadness206(TargetUnit)
  return (TargetUnit:TimeToDie() < 25 and Player:BuffDown(S.VoidformBuff))
end

local function EvaluateCycleVoidTorrent208(TargetUnit)
  return (DotsUp(TargetUnit, false) and TargetUnit:TimeToDie() > 3 and Player:BuffDown(S.VoidformBuff) and EnemiesCount10ySplash < (5 + (6 * num(S.TwistofFate:IsAvailable()))))
end

local function EvaluateCycleVampiricTouch214(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.VampiricTouchDebuff) and TargetUnit:TimeToDie() > 6 or (S.Misery:IsAvailable() and TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff)) or Player:BuffUp(S.UnfurlingDarknessBuff))
end

local function EvaluateCycleShadowWordPain220(TargetUnit)
  return (TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) and Target:TimeToDie() > 4 and not S.Misery:IsAvailable() and not (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff) and (not S.PsychicLink:IsAvailable() or (S.PsychicLink:IsAvailable() and EnemiesCount10ySplash <= 2)))
end

local function EvaluateCycleMindSear224(TargetUnit)
  return (S.SearingNightmare:IsAvailable() and TargetUnit:DebuffRefreshable(S.ShadowWordPainDebuff) and EnemiesCount10ySplash > 2)
end

local function EvaluateCycleMindgames226(TargetUnit)
  return (Player:Insanity() < 90 and (DotsUp(TargetUnit, true) or Player:BuffUp(S.VoidformBuff)))
end

local function EvaluateCycleSilence228(TargetUnit)
  return (TargetUnit:IsInterruptible())
end

local function Precombat()
  -- Update point at which the Mindbender drops; this is in Precombat, as it can't change once in combat
  if S.Mindbender:ID() == 34433 then
    PetActiveCD = 170
  else
    PetActiveCD = 45
  end
  -- flask
  -- food
  -- augmentation
  -- snapshot_stats
  if Everyone.TargetIsValid() then
    -- potion
    if I.PotionofDeathlyFixation:IsReady() and Settings.Commons.UsePotions then
      if CastSuggested(I.PotionofDeathlyFixation) then return "potion_of_spectral_intellect 2"; end
    end
    -- shadowform,if=!buff.shadowform.up
    if S.Shadowform:IsCastable() and (Player:BuffDown(S.ShadowformBuff)) then
      if Cast(S.Shadowform, Settings.Shadow.GCDasOffGCD.Shadowform) then return "shadowform 4"; end
    end
    -- arcane_torrent
    if S.ArcaneTorrent:IsCastable() and CDsON() then
      if Cast(S.ArcaneTorrent, nil, nil, not Target:IsSpellInRange(S.ArcaneTorrent)) then return "arcane_torrent 6"; end
    end
    -- use_item,name=azsharas_font_of_power
    if I.AzsharasFontofPower:IsEquipped() and I.AzsharasFontofPower:IsReady() and Settings.Commons.UseTrinkets then
      if Cast(I.AzsharasFontofPower, nil, Settings.Commons.TrinketDisplayStyle) then return "azsharas_font_of_power 8"; end
    end
    -- variable,name=mind_sear_cutoff,op=set,value=2
    VarMindSearCutoff = 2
    -- vampiric_touch
    if S.VampiricTouch:IsCastable() then
      if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 10"; end
    end
    -- Manually added: mind_blast,if=talent.misery.enabled and shadow_word_pain,if=!talent.misery.enabled
    -- This is to avoid VT being suggested while being casted precombat
    if S.MindBlast:IsCastable() and (S.Misery:IsAvailable()) then
      if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 12"; end
    end
    if S.ShadowWordPain:IsCastable() and (not S.Misery:IsAvailable()) then
      if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 14"; end
    end
  end
end

local function Essences()
  -- memory_of_lucid_dreams
  if S.MemoryofLucidDreams:IsCastable() then
    if Cast(S.MemoryofLucidDreams, nil, Settings.Commons.EssenceDisplayStyle) then return "memory_of_lucid_dreams essences"; end
  end
  -- blood_of_the_enemy
  if S.BloodoftheEnemy:IsCastable() then
    if Cast(S.BloodoftheEnemy, nil, Settings.Commons.EssenceDisplayStyle, nil, nil, not Target:IsSpellInRange(S.BloodoftheEnemy)) then return "blood_of_the_enemy essences"; end
  end
  -- guardian_of_azeroth
  if S.GuardianofAzeroth:IsCastable() then
    if Cast(S.GuardianofAzeroth, nil, Settings.Commons.EssenceDisplayStyle) then return "guardian_of_azeroth essences"; end
  end
  -- focused_azerite_beam,if=spell_targets.mind_sear>=2|raid_event.adds.in>60
  if S.FocusedAzeriteBeam:IsCastable() and (EnemiesCount10ySplash >= 2 or Settings.Shadow.UseFABST) then
    if Cast(S.FocusedAzeriteBeam, nil, Settings.Commons.EssenceDisplayStyle) then return "focused_azerite_beam essences"; end
  end
  -- purifying_blast,if=spell_targets.mind_sear>=2|raid_event.adds.in>60
  if S.PurifyingBlast:IsCastable() and (EnemiesCount10ySplash >= 2) then
    if Cast(S.PurifyingBlast, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsInRange(40)) then return "purifying_blast essences"; end
  end
  -- concentrated_flame,line_cd=6,if=time<=10|full_recharge_time<gcd|target.time_to_die<5
  if S.ConcentratedFlame:IsCastable() and (HL.CombatTime() <= 10 or S.ConcentratedFlame:FullRechargeTime() < Player:GCD() or Target:TimeToDie() < 5) then
    if Cast(S.ConcentratedFlame, nil, Settings.Commons.EssenceDisplayStyle, not Target:IsSpellInRange(S.ConcentratedFlame)) then return "concentrated_flame essences"; end
  end
  -- ripple_in_space
  if S.RippleInSpace:IsCastable() then
    if Cast(S.RippleInSpace, nil, Settings.Commons.EssenceDisplayStyle) then return "ripple_in_space essences"; end
  end
  -- reaping_flames
  if (true) then
    local ShouldReturn = Everyone.ReapingFlamesCast(Settings.Commons.EssenceDisplayStyle); if ShouldReturn then return ShouldReturn; end
  end
  -- worldvein_resonance
  if S.WorldveinResonance:IsCastable() then
    if Cast(S.WorldveinResonance, nil, Settings.Commons.EssenceDisplayStyle) then return "worldvein_resonance essences"; end
  end
  -- the_unbound_force
  if S.TheUnboundForce:IsCastable() then
    if Cast(S.TheUnboundForce, nil, Settings.Commons.EssenceDisplayStyle) then return "the_unbound_force essences"; end
  end
end

local function Cds()
  -- power_infusion,if=buff.voidform.up|!soulbind.combat_meditation.enabled&cooldown.void_eruption.remains>=10|fight_remains<cooldown.void_eruption.remains
  if S.PowerInfusion:IsCastable() and (Player:BuffUp(S.VoidformBuff) or not S.CombatMeditation:IsAvailable() and S.VoidEruption:CooldownRemains() >= 10 or HL.BossFilteredFightRemains("<", S.VoidEruption:CooldownRemains())) then
    if Cast(S.PowerInfusion, Settings.Shadow.OffGCDasOffGCD.PowerInfusion) then return "power_infusion 50"; end
  end
  -- silence,target_if=runeforge.sephuzs_proclamation.equipped&(target.is_add|target.debuff.casting.react)
  if S.Silence:IsCastable() and SephuzEquipped then
    if Everyone.CastCycle(S.Silence, Enemies30y, EvaluateCycleSilence228, not Target:IsSpellInRange(S.Silence)) then return "silence 51"; end
  end
  -- Covenant: fae_guardians,if=!buff.voidform.up&(!cooldown.void_torrent.up|!talent.void_torrent.enabled)|buff.voidform.up&(soulbind.grove_invigoration.enabled|soulbind.field_of_blossoms.enabled)
  if S.FaeGuardians:IsReady() and (Player:BuffDown(S.VoidformBuff) and (not S.VoidTorrent:CooldownUp() or not s.VoidTorrent:IsAvailable()) or Player:BuffUp(S.VoidformBuff) and (S.GroveInvigoration:IsAvailable() or S.FieldofBlossoms:IsAvailable())) then
    if Cast(S.FaeGuardians, Settings.Commons.CovenantDisplayStyle) then return "fae_guardians 52"; end
  end
  -- Covenant: mindgames,target_if=insanity<90&(variable.all_dots_up|buff.voidform.up)
  if S.Mindgames:IsReady() then
    if Cast(S.Mindgames, Enemies40y, EvaluateCycleMindgames226, not Target:IsSpellInRange(S.Mindgames)) then return "mindgames 54"; end
  end
  -- Covenant: unholy_nova,if=((!raid_event.adds.up&raid_event.adds.in>20)|raid_event.adds.remains>=15|raid_event.adds.duration<15)&(buff.power_infusion.up|cooldown.power_infusion.remains>=10)
  -- Manually added check for targets within 15 yards of player, as this novas, rather than being target-based
  if S.UnholyNova:IsReady() and #Enemies15yMelee > 0 and (Player:BuffUp(S.PowerInfusionBuff) or S.PowerInfusion:CooldownRemains() >= 10) then
    if Cast(S.UnholyNova, Settings.Commons.CovenantDisplayStyle, nil, not Target:IsInRange(15)) then return "unholy_nova 56"; end
  end
  -- Covenant: boon_of_the_ascended,if=!buff.voidform.up&!cooldown.void_eruption.up&spell_targets.mind_sear>1&!talent.searing_nightmare.enabled|(buff.voidform.up&spell_targets.mind_sear<2&!talent.searing_nightmare.enabled&prev_gcd.1.void_bolt)|(buff.voidform.up&talent.searing_nightmare.enabled)
  if S.BoonoftheAscended:IsCastable() and (Player:BuffDown(S.VoidformBuff) and not S.VoidEruption:CooldownUp() and EnemiesCount10ySplash > 1 and not S.SearingNightmare:IsAvailable() or (Player:BuffUp(S.VoidformBuff) and EnemiesCount10ySplash < 2 and not S.SearingNightmare:IsAvailable() and Player:PrevGCD(1, S.VoidBolt)) or (Player:BuffUp(S.VoidformBuff) and S.SearingNightmare:IsAvailable())) then
    if Cast(S.BoonoftheAscended, Settings.Commons.CovenantDisplayStyle) then return "boon_of_the_ascended 58"; end
  end
  -- use_item,name=sinful_gladiators_badge_of_ferocity,if=buff.voidform.up|time>10&(!covenant.night_fae)
  if I.SinfulGladiatorsBadgeofFerocity:IsEquipped() and I.SinfulGladiatorsBadgeofFerocity:IsReady() and (Player:BuffUp(S.VoidformBuff) or HL.CombatTime() > 10 and not Player:Covenant() == "Night Fae") then
    if Cast(I.SinfulGladiatorsBadgeofFerocity) then return "sinful_gladiators_badge_of_ferocity 60"; end
  end
  -- call_action_list,name=essences
  if (true) then
    local ShouldReturn = Essences(); if ShouldReturn then return ShouldReturn; end
  end
  -- use_items
  local TrinketToUse = HL.UseTrinkets(OnUseExcludes)
  if TrinketToUse then
    if Cast(TrinketToUse, nil, Settings.Commons.TrinketDisplayStyle) then return "Generic use_items for " .. TrinketToUse:Name(); end
  end
end

local function Boon()
  -- ascended_blast,if=spell_targets.mind_sear<=3
  if S.AscendedBlast:IsReady() and (EnemiesCount10ySplash <= 3) then
    if Cast(S.AscendedBlast, Settings.Commons.CovenantDisplayStyle, nil, not Target:IsSpellInRange(S.AscendedBlast)) then return "ascended_blast 70"; end
  end
  -- ascended_nova,if=spell_targets.ascended_nova>1&spell_targets.mind_sear>1+talent.searing_nightmare.enabled
  if S.AscendedNova:IsReady() and (#Enemies8yMelee > 1 and EnemiesCount10ySplash > (1 + num(S.SearingNightmare:IsAvailable()))) then
    if Cast(S.AscendedNova, Settings.Commons.CovenantDisplayStyle, nil, not Target:IsInRange(8)) then return "ascended_nova 72"; end
  end
end

local function Cwc()
  -- searing_nightmare,use_while_casting=1,target_if=(variable.searing_nightmare_cutoff&!variable.pool_for_cds)|(dot.shadow_word_pain.refreshable&spell_targets.mind_sear>1)
  if S.SearingNightmare:IsReady() and Player:IsChanneling(S.MindSear) and ((VarSearingNightmareCutoff and not VarPoolForCDs) or (UnitsRefreshSWPain > 0 and EnemiesCount10ySplash > 1)) then
    if Cast(S.SearingNightmare, nil, nil, not Target:IsSpellInRange(S.SearingNightmare)) then return "searing_nightmare 80"; end
  end
  -- searing_nightmare,use_while_casting=1,target_if=talent.searing_nightmare.enabled&dot.shadow_word_pain.refreshable&spell_targets.mind_sear>2
  if S.SearingNightmare:IsReady() and Player:IsChanneling(S.MindSear) and (UnitsRefreshSWPain > 0 and EnemiesCount10ySplash > 2) then
    if Cast(S.SearingNightmare, nil, nil, not Target:IsSpellInRange(S.SearingNightmare)) then return "searing_nightmare 82"; end
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
  -- Manually added: Cast free Void Bolt
  if S.VoidBolt:CooldownUp() and (Player:BuffUp(S.DissonantEchoesBuff)) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt 90"; end
  end
  -- void_eruption,if=variable.pool_for_cds&insanity>=40&(insanity<=85|talent.searing_nightmare.enabled&variable.searing_nightmare_cutoff)&pet.fiend.down
  if S.VoidEruption:IsReady() and (VarPoolForCDs and Player:Insanity() >= 40 and (Player:Insanity() <= 85 or S.SearingNightmare:IsAvailable() and VarSearingNightmareCutoff) and S.Mindbender:CooldownRemains() < PetActiveCD) then
    if Cast(S.VoidEruption, Settings.Shadow.GCDasOffGCD.VoidEruption, nil, not Target:IsSpellInRange(S.VoidEruption)) then return "void_eruption 92"; end
  end
  -- shadow_word_pain,if=buff.fae_guardians.up&!debuff.wrathful_faerie.up
  -- Manually change to VT if using Misery talent
  if S.ShadowWordPain:IsCastable() and (Player:BuffUp(S.FaeGuardiansBuff) and Target:DebuffDown(S.WrathfulFaerieDebuff)) then
    if S.Misery:IsAvailable() then
      if Cast(S.VampiricTouch, nil, nil, not Target:IsSpellInRange(S.VampiricTouch)) then return "vampiric_touch 94"; end
    else
      if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 94"; end
    end
  end
  -- call_action_list,name=cds
  if (CDsON()) then
    local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
  end
  -- mind_sear,target_if=talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff&!dot.shadow_word_pain.ticking&pet.fiend.down
  if S.MindSear:IsCastable() and (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff and UnitsWithoutSWPain > 0 and S.Mindbender:CooldownRemains() < PetActiveCD) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 97"; end
  end
  -- damnation,target_if=!variable.all_dots_up
  if S.Damnation:IsCastable() then
    if Everyone.CastCycle(S.Damnation, Enemies40y, EvaluateCycleDamnation200, not Target:IsSpellInRange(S.Damnation)) then return "damnation 98"; end
  end
  -- void_bolt,if=insanity<=85&talent.hungering_void.enabled&talent.searing_nightmare.enabled&spell_targets.mind_sear<=6|((talent.hungering_void.enabled&!talent.searing_nightmare.enabled)|spell_targets.mind_sear=1)
  if S.VoidBolt:IsCastable() and (Player:Insanity() <= 85 and S.HungeringVoid:IsAvailable() and S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash <= 6 or ((S.HungeringVoid:IsAvailable() and not S.SearingNightmare:IsAvailable()) or EnemiesCount10ySplash == 1)) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt 100"; end
  end
  -- devouring_plague,target_if=(refreshable|insanity>75)&(!variable.pool_for_cds|insanity>=85)&(!talent.searing_nightmare.enabled|(talent.searing_nightmare.enabled&!variable.searing_nightmare_cutoff))
  if S.DevouringPlague:IsReady() then
    if Everyone.CastCycle(S.DevouringPlague, Enemies40y, EvaluateCycleDevouringPlage202, not Target:IsSpellInRange(S.DevouringPlague)) then return "devouring_plague 102"; end
  end
  -- void_bolt,if=spell_targets.mind_sear<(4+conduit.dissonant_echoes.enabled)&insanity<=85&talent.searing_nightmare.enabled|!talent.searing_nightmare.enabled
  if S.VoidBolt:IsCastable() and (EnemiesCount10ySplash < (4 + num(S.DissonantEchoes:IsAvailable())) and Player:Insanity() <= 85 and S.SearingNightmare:IsAvailable() or not S.SearingNightmare:IsAvailable()) then
    if Cast(S.VoidBolt, nil, nil, not Target:IsSpellInRange(S.VoidBolt)) then return "void_bolt 103"; end
  end
  -- shadow_word_death,target_if=(target.health.pct<20&spell_targets.mind_sear<4)|(pet.fiend.active&runeforge.shadowflame_prism.equipped)
  if S.ShadowWordDeath:IsCastable() then
    if Everyone.CastCycle(S.ShadowWordDeath, Enemies40y, EvaluateCycleShadowWordDeath204, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 104"; end
  end
  -- surrender_to_madness,target_if=target.time_to_die<25&buff.voidform.down
  if S.SurrenderToMadness:IsCastable() then
    if Everyone.CastCycle(S.SurrenderToMadness, Enemies40y, EvaluateCycleSurrenderToMadness206, not Target:IsSpellInRange(S.SurrenderToMadness)) then return "surrender_to_madness 106"; end
  end
  -- void_torrent,target_if=variable.dots_up&target.time_to_die>3&buff.voidform.down&active_dot.vampiric_touch==spell_targets.vampiric_touch&spell_targets.mind_sear<(5+(6*talent.twist_of_fate.enabled))
  if S.VoidTorrent:IsCastable() then
    if Everyone.CastCycle(S.VoidTorrent, Enemies40y, EvaluateCycleVoidTorrent208, not Target:IsSpellInRange(S.VoidTorrent)) then return "void_torrent 107"; end
  end
  -- mindbender,if=dot.vampiric_touch.ticking&(talent.searing_nightmare.enabled&spell_targets.mind_sear>variable.mind_sear_cutoff|dot.shadow_word_pain.ticking)
  if S.Mindbender:IsCastable() and CDsON() and (Target:DebuffUp(S.VampiricTouchDebuff) and (S.SearingNightmare:IsAvailable() and EnemiesCount10ySplash > VarMindSearCutoff or Target:DebuffUp(S.ShadowWordPainDebuff))) then
    if Cast(S.Mindbender, Settings.Shadow.GCDasOffGCD.Mindbender, nil, not Target:IsSpellInRange(S.Mindbender)) then return "shadowfiend/mindbender 108"; end
  end
  -- shadow_word_death,if=runeforge.painbreaker_psalm.equipped&variable.dots_up&target.time_to_pct_20>(cooldown.shadow_word_death.duration+gcd)
  if S.ShadowWordDeath:IsReady() and (PainbreakerEquipped and VarDotsUp and Target:TimeToX(20) > S.ShadowWordDeath:Cooldown() + Player:GCD()) then
    if Cast(S.ShadowWordDeath, nil, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 112"; end
  end
  -- shadow_crash,if=raid_event.adds.in>10
  if S.ShadowCrash:IsCastable() then
    if Cast(S.ShadowCrash, nil, nil, not Target:IsInRange(40)) then return "shadow_crash 114"; end
  end
  -- mind_sear,target_if=spell_targets.mind_sear>variable.mind_sear_cutoff&buff.dark_thought.up,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindSear:IsCastable() and (EnemiesCount10ySplash > VarMindSearCutoff and Player:BuffUp(S.DarkThoughtBuff)) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 118"; end
  end
  -- mind_flay,if=buff.dark_thought.up&!(buff.voidform.up&cooldown.voidbolt.remains<=gcd)&variable.dots_up,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&cooldown.void_bolt.up
  if S.MindFlay:IsCastable() and not Player:IsCasting(S.MindFlay) and (Player:BuffUp(S.DarkThoughtBuff) and not (Player:BuffUp(S.VoidformBuff) and S.VoidBolt:CooldownRemains() <= Player:GCD()) and VarDotsUp) then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 120"; end
  end
  -- mind_blast,if=variable.dots_up&raid_event.movement.in>cast_time+0.5&(spell_targets.mind_sear<4&!talent.misery.enabled|spell_targets.mind_sear<6&talent.misery.enabled)
  if S.MindBlast:IsCastable() and (VarDotsUp and (EnemiesCount10ySplash < 4 and not S.Misery:IsAvailable() or EnemiesCount10ySplash < 6 and S.Misery:IsAvailable())) then
    if Cast(S.MindBlast, nil, nil, not Target:IsSpellInRange(S.MindBlast)) then return "mind_blast 122"; end
  end
  -- vampiric_touch,target_if=refreshable&target.time_to_die>6|(talent.misery.enabled&dot.shadow_word_pain.refreshable)|buff.unfurling_darkness.up
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
  -- mind_sear,target_if=spell_targets.mind_sear>variable.mind_sear_cutoff,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2
  if S.MindSear:IsCastable() and (EnemiesCount10ySplash > VarMindSearCutoff) then
    if Cast(S.MindSear, nil, nil, not Target:IsSpellInRange(S.MindSear)) then return "mind_sear 130"; end
  end
  -- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(cooldown.void_bolt.up|cooldown.mind_blast.up)
  if S.MindFlay:IsCastable() then
    if Cast(S.MindFlay, nil, nil, not Target:IsSpellInRange(S.MindFlay)) then return "mind_flay 132"; end
  end
  -- shadow_word_death
  if S.ShadowWordDeath:IsCastable() then
    if Cast(S.ShadowWordDeath, nil, nil, not Target:IsSpellInRange(S.ShadowWordDeath)) then return "shadow_word_death 133"; end
  end
  -- shadow_word_pain
  if S.ShadowWordPain:IsCastable() then
    if Cast(S.ShadowWordPain, nil, nil, not Target:IsSpellInRange(S.ShadowWordPain)) then return "shadow_word_pain 134"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8yMelee = Player:GetEnemiesInMeleeRange(8) -- Ascended Nova
  Enemies15yMelee = Player:GetEnemiesInMeleeRange(15) -- Unholy Nova
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
    -- Manually Added: Use Dispersion if dying
    if S.Dispersion:IsCastable() and Player:HealthPercentage() < Settings.Shadow.DispersionHP then
      if Cast(S.Dispersion, Settings.Shadow.OffGCDasOffGCD.Dispersion) then return "dispersion low_hp"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(30, S.Silence, Settings.Commons.OffGCDasOffGCD.Silence, false); if ShouldReturn then return ShouldReturn; end
    -- potion,if=buff.bloodlust.react|target.time_to_die<=80|target.health.pct<35
    if I.PotionofDeathlyFixation:IsReady() and Settings.Commons.UsePotions and (Player:BloodlustUp() or Target:TimeToDie() <= 80 or Target:HealthPercentage() < 35) then
      if CastSuggested(I.PotionofDeathlyFixation) then return "potion_of_spectral_intellect 20"; end
    end
    -- variable,name=dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking
    VarDotsUp = DotsUp(Target, false)
    -- variable,name=all_dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking&dot.devouring_plague.ticking
    VarAllDotsUp = DotsUp(Target, true)
    -- variable,name=searing_nightmare_cutoff,op=set,value=spell_targets.mind_sear>2+buff.voidform.up
    VarSearingNightmareCutoff = (EnemiesCount10ySplash > (2 + num(Player:BuffUp(S.VoidformBuff))))
    -- variable,name=pool_for_cds,op=set,value=cooldown.void_eruption.up&(!raid_event.adds.up|raid_event.adds.duration<=10|raid_event.adds.remains>=10+5*(talent.hungering_void.enabled|covenant.kyrian))&((raid_event.adds.in>20|spell_targets.void_eruption>=5)|talent.hungering_void.enabled|covenant.kyrian)
    VarPoolForCDs = S.VoidEruption:CooldownUp() and (EnemiesCount10ySplash == 1 or EnemiesCount10ySplash >= 5) and (S.HungeringVoid:IsAvailable() or Player:Covenant() == "Kyrian")
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
      -- bag_of_tricks
      if S.BagofTricks:IsCastable() then
        if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks 30"; end
      end
    end
    -- call_action_list,name=cwc
    if (true) then
      local ShouldReturn = Cwc(); if ShouldReturn then return ShouldReturn; end
    end
    -- run_action_list,name=main
    if (true) then
      local ShouldReturn = Main(); if ShouldReturn then return ShouldReturn; end
    end
  end
end

local function Init()

end

HR.SetAPL(258, APL, Init)
