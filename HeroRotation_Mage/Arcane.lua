--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Mage       = HR.Commons.Mage
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- WoW API
local GetItemCount = GetItemCount

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Arcane;
local I = Item.Mage.Arcane;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.ConjuredChillglobe:ID(),
  I.DesperateInvokersCodex:ID(),
  I.DMDDance:ID(),
  I.DMDDanceBox:ID(),
  I.DMDInferno:ID(),
  I.DMDInfernoBox:ID(),
  I.DMDRime:ID(),
  I.DMDRimeBox:ID(),
  I.IcebloodDeathsnare:ID(),
  I.TimebreachingTalon:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Arcane = HR.GUISettings.APL.Mage.Arcane
};

S.ArcaneBlast:RegisterInFlight()
S.ArcaneBarrage:RegisterInFlight()

-- Variables
local Enemies8ySplash, EnemiesCount8ySplash --Enemies arround target
local var_aoe_target_count = 3
local var_conserve_mana = false
local var_aoe_spark_phase = false
local var_spark_phase = false
local var_opener = true
local var_surge_last_spark_stack = false
local var_totm_on_last_spark_stack = Player:HasTier(29, 4)
local var_opener_min_mana = 225000 - (25000 * num(not S.ArcaneHarmony:IsAvailable()) + 200000 * num(not var_totm_on_last_spark_stack))
local var_steroid_trinket_equipped = (I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.IrideusFragment:IsEquipped() or I.EruptingSpearFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.BalefireBranch:IsEquipped() or I.TimeThiefsGambit:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped())
local var_mirror_double_on_use = I.MirrorofFracturedTomorrows:IsEquipped() and (I.AshesoftheEmbersoul:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped())
local var_balefire_double_on_use = I.BalefireBranch:IsEquipped() and (I.AshesoftheEmbersoul:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped())
local var_ashes_double_on_use = I.AshesoftheEmbersoul:IsEquipped() and I.NymuesUnravelingSpindle:IsEquipped()
local var_nymues_double_on_use = I.NymuesUnravelingSpindle:IsEquipped() and I.SeaStar:IsEquipped()
local var_badgebalefire_double_on_use = I.BalefireBranch:IsEquipped() and I.ObsidianGladiatorsBadge:IsEquipped()
local var_irideus_double_on_use = I.IrideusFragment:IsEquipped() and I.TimebreachingTalon:IsEquipped()

local ClearCastingMaxStack = 3 --buff.clearcasting.max_stack
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE
local GCDMax

HL:RegisterForEvent(function()
  var_conserve_mana = false
  var_opener = true
  var_opener_min_mana = 225000 - (25000 * num(not S.ArcaneHarmony:IsAvailable()) + 200000 * num(not var_totm_on_last_spark_stack))
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  var_totm_on_last_spark_stack = Player:HasTier(29, 4)
  var_steroid_trinket_equipped = (I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.IrideusFragment:IsEquipped() or I.EruptingSpearFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.BalefireBranch:IsEquipped() or I.TimeThiefsGambit:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped())
  var_mirror_double_on_use = I.MirrorofFracturedTomorrows:IsEquipped() and (I.AshesoftheEmbersoul:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped())
  var_balefire_double_on_use = I.BalefireBranch:IsEquipped() and (I.AshesoftheEmbersoul:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped())
  var_ashes_double_on_use = I.AshesoftheEmbersoul:IsEquipped() and I.NymuesUnravelingSpindle:IsEquipped()
  var_nymues_double_on_use = I.NymuesUnravelingSpindle:IsEquipped() and I.SeaStar:IsEquipped()
  var_badgebalefire_double_on_use = I.BalefireBranch:IsEquipped() and I.ObsidianGladiatorsBadge:IsEquipped()
  var_irideus_double_on_use = I.IrideusFragment:IsEquipped() and I.TimebreachingTalon:IsEquipped()
end, "PLAYER_EQUIPMENT_CHANGED")

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  -- Note: Moved to top of APL()
  -- arcane_familiar
  if S.ArcaneFamiliar:IsCastable() and Player:BuffDown(S.ArcaneFamiliarBuff) then
    if Cast(S.ArcaneFamiliar) then return "arcane_familiar precombat 2"; end
  end
  -- conjure_mana_gem
  -- TODO: Fix hotkey issue (spell and item use the same icon)
  if S.ConjureManaGem:IsCastable() then
    if Cast(S.ConjureManaGem) then return "conjure_mana_gem precombat 4"; end
  end
  -- variable,name=aoe_target_count,op=reset,default=3
  -- variable,name=conserve_mana,op=set,value=0
  -- variable,name=opener,op=set,value=1
  -- variable,name=opener_min_mana,default=-1,op=set,if=variable.opener_min_mana=-1,value=225000-(25000*!talent.arcane_harmony+200000*!variable.totm_on_last_spark_stack)
  -- variable,name=totm_on_last_spark_stack,default=0,op=set,if=variable.totm_on_last_spark_stack=-1,value=set_bonus.tier29_4pc
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.irideus_fragment|equipped.erupting_spear_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor|equipped.mirror_of_fractured_tomorrows|equipped.ashes_of_the_embersoul|equipped.balefire_branch|equipped.time_theifs_gambit|equipped.nymues_unraveling_spindle
  -- variable,name=mirror_double_on_use,op=set,value=((equipped.ashes_of_the_embersoul&equipped.mirror_of_fractured_tomorrows)|(equipped.nymues_unraveling_spindle&equipped.mirror_of_fractured_tomorrows))
  -- variable,name=balefire_double_on_use,op=set,value=((equipped.ashes_of_the_embersoul&equipped.balefire_branch)|(equipped.nymues_unraveling_spindle&equipped.balefire_branch)|(equipped.mirror_of_fractured_tomorrows&equipped.balefire_branch))
  -- variable,name=ashes_double_on_use,op=set,value=(equipped.nymues_unraveling_spindle&equipped.ashes_of_the_embersoul)
  -- variable,name=nymues_double_on_use,op=set,value=0+(equipped.sea_star&equipped.nymues_unraveling_spindle)
  -- variable,name=badgebalefire_double_on_use,op=set,value=(equipped.balefire_branch&equipped.obsidian_gladiators_badge_of_ferocity)
  -- variable,name=irideus_double_on_use,op=set,value=(equipped.timebreaching_talon&equipped.irideus_fragment)
  -- Note: Moved to variable declarations and event registrations to avoid potential issue from entering combat before targeting an enemy.
  -- snapshot_stats
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 6"; end
  end
  -- arcane_blast,if=!talent.siphon_storm
  if S.ArcaneBlast:IsReady() and (not S.SiphonStorm:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 8"; end
  end
  -- evocation,if=talent.siphon_storm
  if S.Evocation:IsReady() and (S.SiphonStorm:IsAvailable()) then
    if Cast(S.Evocation) then return "evocation precombat 10"; end
  end
end

local function Calculations()
  -- variable,name=aoe_spark_phase,op=set,value=1,if=active_enemies>=variable.aoe_target_count&(action.arcane_orb.charges>0|buff.arcane_charge.stack>=3)&cooldown.radiant_spark.ready&cooldown.touch_of_the_magi.remains<=(gcd.max*2)
  -- variable,name=aoe_spark_phase,op=set,value=0,if=variable.aoe_spark_phase&debuff.radiant_spark_vulnerability.down&dot.radiant_spark.remains<7&cooldown.radiant_spark.remains
  if (EnemiesCount8ySplash >= var_aoe_target_count and (S.ArcaneOrb:Charges() > 0 or Player:ArcaneCharges() >= 3) and S.RadiantSpark:CooldownUp() and S.TouchoftheMagi:CooldownRemains() <= GCDMax * 2) then
    var_aoe_spark_phase = true
  elseif (var_aoe_spark_phase and Target:DebuffDown(S.RadiantSparkVulnerability) and Target:DebuffRemains(S.RadiantSparkDebuff) < 7 and S.RadiantSpark:CooldownDown()) then
    var_aoe_spark_phase = false
  end
  -- variable,name=spark_phase,op=set,value=1,if=buff.arcane_charge.stack>3&active_enemies<variable.aoe_target_count&cooldown.radiant_spark.ready&cooldown.touch_of_the_magi.remains<=(gcd.max*(7-(3*equipped.balefire_branch)))&(cooldown.arcane_surge.remains<=(gcd.max*5)|cooldown.arcane_surge.remains>40)
  -- variable,name=spark_phase,op=set,value=0,if=variable.spark_phase&debuff.radiant_spark_vulnerability.down&dot.radiant_spark.remains<7&cooldown.radiant_spark.remains
  if (Player:ArcaneCharges() > 3 and EnemiesCount8ySplash < var_aoe_target_count and S.RadiantSpark:CooldownUp() and S.TouchoftheMagi:CooldownRemains() <= GCDMax * (7 - (3 * num(I.BalefireBranch:IsEquipped()))) and (S.ArcaneSurge:CooldownRemains() <= (GCDMax * 5) or S.ArcaneSurge:CooldownRemains() > 40)) then
    var_spark_phase = true
  elseif (var_spark_phase and Target:DebuffDown(S.RadiantSparkVulnerability) and Target:DebuffRemains(S.RadiantSparkDebuff) < 7 and S.RadiantSpark:CooldownDown()) then
    var_spark_phase = false
  end
  -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
  if (Target:DebuffUp(S.TouchoftheMagiDebuff) and var_opener) then
    var_opener = false
  end
  -- variable,name=surge_last_spark_stack,op=set,value=action.arcane_blast.cast_time<gcd.max
  var_surge_last_spark_stack = S.ArcaneBlast:CastTime() < GCDMax
end

local function CooldownPhase()
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi cooldown_phase 2"; end
  end
  -- variable,name=conserve_mana,op=set,if=cooldown.radiant_spark.ready,value=(cooldown.arcane_surge.remains<10)
  if S.RadiantSpark:CooldownUp() then
    var_conserve_mana = S.ArcaneSurge:CooldownRemains() < 10
  end
  -- shifting_power,if=buff.arcane_surge.down&!talent.radiant_spark
  if S.ShiftingPower:IsReady() and (Player:BuffDown(S.ArcaneSurgeBuff) and not S.RadiantSpark:IsAvailable()) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power cooldown_phase 4"; end
  end
  -- arcane_orb,if=cooldown.radiant_spark.ready&buff.arcane_charge.stack<buff.arcane_charge.max_stack
  if S.ArcaneOrb:IsReady() and (S.RadiantSpark:CooldownUp() and Player:ArcaneCharges() < Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb cooldown_phase 6"; end
  end
  -- arcane_blast,if=cooldown.radiant_spark.ready&(buff.arcane_charge.stack<2|(buff.arcane_charge.stack<buff.arcane_charge.max_stack&cooldown.arcane_orb.remains>=gcd.max))
  if S.ArcaneBlast:IsReady() and (S.RadiantSpark:CooldownUp() and (Player:ArcaneCharges() < 2 or (Player:ArcaneCharges() < Player:ArcaneChargesMax() and S.ArcaneOrb:CooldownRemains() >= GCDMax))) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cooldown_phase 8"; end
  end
  -- arcane_missiles,if=variable.opener&buff.bloodlust.up&buff.clearcasting.react&buff.clearcasting.stack>0&cooldown.radiant_spark.remains<5&buff.nether_precision.down&(!buff.arcane_artillery.up|buff.arcane_artillery.remains<=(gcd.max*6))&set_bonus.tier31_4pc,chain=1,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  if Player:IsChanneling(S.ArcaneMissiles) and Player:GCDRemains() == 0 and Player:ManaPercentage() > 30 and Player:BuffUp(S.NetherPrecisionBuff) and Player:BuffDown(S.ArcaneArtilleryBuff) then
    if HR.CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt cooldown_phase 10"; end
  end
  if S.ArcaneMissiles:IsReady() and (var_opener and Player:BloodlustUp() and Player:BuffUp(S.ClearcastingBuff) and S.RadiantSpark:CooldownRemains() < 5 and Player:BuffDown(S.NetherPrecisionBuff) and (Player:BuffDown(S.ArcaneArtilleryBuff) or Player:BuffRemains(S.ArcaneArtilleryBuff) <= (GCDMax * 6)) and Player:HasTier(31, 4)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cooldown_phase 12"; end
  end
  -- arcane_blast,if=variable.opener&cooldown.arcane_surge.ready&buff.bloodlust.up&mana>=variable.opener_min_mana&buff.siphon_storm.remains>17&!set_bonus.tier30_4pc
  if S.ArcaneBlast:IsReady() and (var_opener and S.ArcaneSurge:CooldownUp() and Player:BloodlustUp() and Player:Mana() >= var_opener_min_mana and Player:BuffRemains(S.SiphonStormBuff) > 17 and not Player:HasTier(30, 4)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cooldown_phase 14"; end
  end
  -- arcane_missiles,if=variable.opener&buff.bloodlust.up&buff.clearcasting.react&buff.clearcasting.stack>=2&cooldown.radiant_spark.remains<5&buff.nether_precision.down&(!buff.arcane_artillery.up|buff.arcane_artillery.remains<=(gcd.max*6))&!set_bonus.tier30_4pc,chain=1,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsReady() and (var_opener and Player:BloodlustUp() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) >= 2 and S.RadiantSpark:CooldownRemains() < 5 and Player:BuffDown(S.NetherPrecisionBuff) and (Player:BuffDown(S.ArcaneArtilleryBuff) or Player:BuffRemains(S.ArcaneArtilleryBuff) <= (GCDMax * 6)) and not Player:HasTier(30, 4)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cooldown_phase 16"; end
  end
  -- arcane_missiles,if=talent.arcane_harmony&buff.arcane_harmony.stack<15&((variable.opener&buff.bloodlust.up)|buff.clearcasting.react&cooldown.radiant_spark.remains<5)&cooldown.arcane_surge.remains<30,chain=1,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsReady() and (S.ArcaneHarmony:IsAvailable() and Player:BuffStack(S.ArcaneHarmonyBuff) < 15 and ((var_opener and Player:BloodlustUp()) or Player:BuffUp(S.ClearcastingBuff) and S.RadiantSpark:CooldownRemains() < 5) and S.ArcaneSurge:CooldownRemains() < 30) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cooldown_phase 18"; end
  end
  -- arcane_missiles,if=cooldown.radiant_spark.ready&buff.clearcasting.react&(talent.nether_precision&(buff.nether_precision.down|buff.nether_precision.remains<gcd.max))&set_bonus.tier30_4pc,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsReady() and (S.RadiantSpark:CooldownUp() and Player:BuffUp(S.ClearcastingBuff) and (S.NetherPrecision:IsAvailable() and (Player:BuffDown(S.NetherPrecisionBuff) or Player:BuffRemains(S.NetherPrecisionBuff) < GCDMax)) and Player:HasTier(30, 4)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cooldown_phase 20"; end
  end
  -- radiant_spark
  if S.RadiantSpark:IsReady() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark cooldown_phase 22"; end
  end
  -- nether_tempest,if=talent.arcane_echo,line_cd=30
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 30 and (S.ArcaneEcho:IsAvailable()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest cooldown_phase 24"; end
  end
  -- arcane_surge
  if S.ArcaneSurge:IsReady() then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge cooldown_phase 26"; end
  end
  -- wait,sec=0.05,if=prev_gcd.1.arcane_surge,line_cd=15
  -- arcane_barrage,if=prev_gcd.1.arcane_surge|prev_gcd.1.nether_tempest|prev_gcd.1.radiant_spark
  if S.ArcaneBarrage:IsReady() and (Player:PrevGCDP(1, S.ArcaneSurge) or Player:PrevGCDP(1, S.NetherTempest) or Player:PrevGCDP(1, S.RadiantSpark)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage cooldown_phase 28"; end
  end
  -- arcane_blast,if=debuff.radiant_spark_vulnerability.stack>0&debuff.radiant_spark_vulnerability.stack<4
  if S.ArcaneBlast:IsReady() and (Target:DebuffUp(S.RadiantSparkVulnerability) and Target:DebuffStack(S.RadiantSparkVulnerability) < 4) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cooldown_phase 30"; end
  end
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind cooldown_phase 32"; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cooldown_phase 34"; end
  end
  -- arcane_missiles,if=buff.nether_precision.down&buff.clearcasting.react&(debuff.radiant_spark_vulnerability.down|(debuff.radiant_spark_vulnerability.stack=4&prev_gcd.1.arcane_blast)),interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&mana.pct>30&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsReady() and (Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffUp(S.ClearcastingBuff) and (Target:DebuffDown(S.RadiantSparkVulnerability) or (Target:DebuffStack(S.RadiantSparkVulnerability) == 4 and Player:PrevGCDP(1, S.ArcaneBlast)))) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles cooldown_phase 36"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast cooldown_phase 38"; end
  end
end

local function SparkPhase()
  -- nether_tempest,if=!ticking&variable.opener&buff.bloodlust.up,line_cd=45
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 45 and (Target:DebuffDown(S.NetherTempestDebuff) and var_opener and Player:BloodlustUp()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest spark_phase 2"; end
  end
  -- arcane_missiles,if=variable.opener&buff.bloodlust.up&buff.clearcasting.react&buff.clearcasting.stack>0&cooldown.radiant_spark.remains<5&buff.nether_precision.down&(!buff.arcane_artillery.up|buff.arcane_artillery.remains<=(gcd.max*6))&set_bonus.tier31_4pc,chain=1,interrupt_if=variable.opener&action.arcane_missiles.channeling&gcd.remains=0&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  if var_opener and Player:IsChanneling(S.ArcaneMissiles) and Player:GCDRemains() == 0 and Player:BuffUp(S.NetherPrecisionBuff) and Player:BuffDown(S.ArcaneArtilleryBuff) then
    if HR.CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt spark_phase 4"; end
  end
  if S.ArcaneMissiles:IsCastable() and (var_opener and Player:BloodlustUp() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ClearcastingBuff) and S.RadiantSpark:CooldownRemains() < 5 and Player:BuffDown(S.NetherPrecisionBuff) and (Player:BuffDown(S.ArcaneArtilleryBuff) or Player:BuffRemains(S.ArcaneArtilleryBuff) <= (GCDMax * 6)) and Player:HasTier(31, 4)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spark_phase 6"; end
  end
  -- arcane_blast,if=variable.opener&cooldown.arcane_surge.ready&buff.bloodlust.up&mana>=variable.opener_min_mana&buff.siphon_storm.remains>15
  if S.ArcaneBlast:IsReady() and (var_opener and S.ArcaneSurge:CooldownUp() and Player:BloodlustUp() and Player:Mana() >= var_opener_min_mana and Player:BuffRemains(S.SiphonStormBuff) > 15) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 8"; end
  end
  -- arcane_missiles,if=variable.opener&buff.bloodlust.up&buff.clearcasting.react&buff.clearcasting.stack>=2&cooldown.radiant_spark.remains<5&buff.nether_precision.down&(!buff.arcane_artillery.up|buff.arcane_artillery.remains<=(gcd.max*6)),chain=1,interrupt_if=variable.opener&action.arcane_missiles.channeling&gcd.remains=0&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsCastable() and (var_opener and Player:BloodlustUp() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) >= 2 and S.RadiantSpark:CooldownRemains() < 5 and Player:BuffDown(S.NetherPrecisionBuff) and Player:BuffRemains(S.ArcaneArtilleryBuff) <= GCDMax * 6) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spark_phase 10"; end
  end
  -- arcane_missiles,if=talent.arcane_harmony&buff.arcane_harmony.stack<15&((variable.opener&buff.bloodlust.up)|buff.clearcasting.react&cooldown.radiant_spark.remains<5)&cooldown.arcane_surge.remains<30,chain=1,interrupt_if=variable.opener&action.arcane_missiles.channeling&gcd.remains=0&buff.nether_precision.up&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsReady() and (S.ArcaneHarmony:IsAvailable() and Player:BuffStack(S.ArcaneHarmonyBuff) < 15 and ((var_opener and Player:BloodlustUp()) or Player:BuffUp(S.ClearcastingBuff) and S.RadiantSpark:CooldownRemains() < 5) and S.ArcaneSurge:CooldownRemains() < 30) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spark_phase 12"; end
  end
  -- radiant_spark
  if S.RadiantSpark:IsReady() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark spark_phase 14"; end
  end
  -- nether_tempest,if=(!variable.surge_last_spark_stack&prev_gcd.4.radiant_spark&cooldown.arcane_surge.remains<=execute_time)|prev_gcd.5.radiant_spark,line_cd=15
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 15 and ((not var_surge_last_spark_stack and Player:PrevGCDP(4, S.RadiantSpark) and S.ArcaneSurge:CooldownRemains() <= S.NetherTempest:ExecuteTime()) or Player:PrevGCDP(5, S.RadiantSpark)) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest spark_phase 16"; end
  end
  -- arcane_surge,if=(!talent.nether_tempest&((prev_gcd.4.radiant_spark&!variable.surge_last_spark_stack)|prev_gcd.5.radiant_spark))|prev_gcd.1.nether_tempest
  if S.ArcaneSurge:IsReady() and ((not S.NetherTempest:IsAvailable() and ((Player:PrevGCDP(4, S.RadiantSpark) and not var_surge_last_spark_stack) or Player:PrevGCDP(5, S.RadiantSpark))) or Player:PrevGCDP(1, S.NetherTempest)) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge spark_phase 18"; end
  end
  -- arcane_blast,if=cast_time>=gcd&execute_time<debuff.radiant_spark_vulnerability.remains&(!talent.arcane_bombardment|target.health.pct>=35)&(talent.nether_tempest&prev_gcd.6.radiant_spark|!talent.nether_tempest&prev_gcd.5.radiant_spark)&!(action.arcane_surge.executing&action.arcane_surge.execute_remains<0.5&!variable.surge_last_spark_stack)
  if S.ArcaneBlast:IsReady() and (S.ArcaneBlast:CastTime() >= Player:GCD() and S.ArcaneBlast:ExecuteTime() < Target:DebuffRemains(S.RadiantSparkVulnerability) and (not S.ArcaneBombardment:IsAvailable() or Target:HealthPercentage() >= 35) and (S.NetherTempest:IsAvailable() and Player:PrevGCDP(6, S.RadiantSpark) or not S.NetherTempest:IsAvailable() and Player:PrevGCDP(5, S.RadiantSpark)) and not (Player:IsCasting(S.ArcaneSurge) and Player:CastRemains() < 0.5 and not var_surge_last_spark_stack)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 20"; end
  end
  -- wait,sec=0.05,if=action.arcane_blast.execute_remains<gcd.remains&(talent.nether_tempest&prev_gcd.6.radiant_spark)|(!talent.nether_tempest&prev_gcd.5.radiant_spark),line_cd=15
  -- arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=4
  if S.ArcaneBarrage:IsReady() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 4) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spark_phase 22"; end
  end
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage&(action.arcane_barrage.in_flight_remains<=0.2|gcd.remains<=0.2)
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage) and (S.ArcaneBarrage:InFlight() and S.ArcaneBarrage:TravelTime() - S.ArcaneBarrage:TimeSinceLastCast() <= 0.2 or Player:GCDRemains() <= 0.2)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi spark_phase 24"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 26"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsReady() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spark_phase 28"; end
  end
end

local function AoeSparkPhase()
  -- cancel_buff,name=presence_of_mind,if=prev_gcd.1.arcane_blast&cooldown.arcane_surge.remains>75
  -- TODO: Add handling for buff removal
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi aoe_spark_phase 2"; end
  end
  -- radiant_spark
  if S.RadiantSpark:IsReady() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe_spark_phase 4"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<3,line_cd=15
  if S.ArcaneOrb:IsReady() and S.ArcaneOrb:TimeSinceLastCast() >= 15 and (Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_spark_phase 6"; end
  end
  -- nether_tempest,if=talent.arcane_echo,line_cd=15
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 15 and (S.ArcaneEcho:IsAvailable()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe_spark_phase 8"; end
  end
  -- arcane_surge
  if S.ArcaneSurge:IsReady() then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge aoe_spark_phase 10"; end
  end
  -- wait,sec=0.05,if=cooldown.arcane_surge.remains>75&prev_gcd.1.arcane_blast&!talent.presence_of_mind,line_cd=15
  -- wait,sec=0.05,if=prev_gcd.1.arcane_surge,line_cd=15
  -- wait,sec=0.05,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=3&!talent.presence_of_mind,line_cd=15
  -- arcane_barrage,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=4&!talent.orb_barrage
  if S.ArcaneBarrage:IsReady() and (S.ArcaneSurge:CooldownRemains() < 75 and Target:DebuffStack(S.RadiantSparkVulnerability) == 4 and not S.OrbBarrage:IsAvailable()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 12"; end
  end
  -- arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=2&cooldown.arcane_surge.remains>75)|(debuff.radiant_spark_vulnerability.stack=1&cooldown.arcane_surge.remains<75)&!talent.orb_barrage
  if S.ArcaneBarrage:IsReady() and ((Target:DebuffStack(S.RadiantSparkVulnerability) == 2 and S.ArcaneSurge:CooldownRemains() > 75) or (Target:DebuffStack(S.RadiantSparkVulnerability) == 1 and S.ArcaneSurge:CooldownRemains() < 75) and not S.OrbBarrage:IsAvailable()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 14"; end
  end
  -- arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=1|debuff.radiant_spark_vulnerability.stack=2|(debuff.radiant_spark_vulnerability.stack=3&active_enemies>5)|debuff.radiant_spark_vulnerability.stack=4)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&talent.orb_barrage
  if S.ArcaneBarrage:IsReady() and ((Target:DebuffStack(S.RadiantSparkVulnerability) == 1 or Target:DebuffStack(S.RadiantSparkVulnerability) == 2 or (Target:DebuffStack(S.RadiantSparkVulnerability) == 3 and EnemiesCount8ySplash > 5) or Target:DebuffStack(S.RadiantSparkVulnerability) == 4) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and S.OrbBarrage:IsAvailable()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 16"; end
  end
  -- presence_of_mind
  if S.PresenceofMind:IsCastable() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind aoe_spark_phase 18"; end
  end
  -- arcane_blast,if=((debuff.radiant_spark_vulnerability.stack=2|debuff.radiant_spark_vulnerability.stack=3)&!talent.orb_barrage)|(debuff.radiant_spark_vulnerability.remains&talent.orb_barrage)
  if S.ArcaneBlast:IsReady() and (((Target:DebuffStack(S.RadiantSparkVulnerability) == 2 or Target:DebuffStack(S.RadiantSparkVulnerability) == 3) and not S.OrbBarrage:IsAvailable()) or (Target:DebuffUp(S.RadiantSparkVulnerability) and S.OrbBarrage:IsAvailable())) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast aoe_spark_phase 20"; end
  end
  -- arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=4&buff.arcane_surge.up)|(debuff.radiant_spark_vulnerability.stack=3&buff.arcane_surge.down)&!talent.orb_barrage
  if S.ArcaneBarrage:IsReady() and ((Target:DebuffStack(S.RadiantSparkVulnerability) == 4 and Player:BuffUp(S.ArcaneSurgeBuff)) or (Target:DebuffStack(S.RadiantSparkVulnerability) == 3 and Player:BuffDown(S.ArcaneSurgeBuff)) and not S.OrbBarrage:IsAvailable()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 22"; end
  end
end

local function TouchPhase()
  -- variable,name=conserve_mana,op=set,if=debuff.touch_of_the_magi.remains>9,value=1-variable.conserve_mana
  if Target:DebuffRemains(S.TouchoftheMagiDebuff) > 9 then
    var_conserve_mana = not var_conserve_mana
  end
  -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=4&mana.pct<30&spell_haste<0.667&buff.arcane_surge.down
  if S.NetherTempest:IsReady() and ((Target:DebuffRefreshable(S.NetherTempestDebuff) or Target:DebuffDown(S.NetherTempestDebuff)) and Player:ArcaneCharges() == 4 and Player:ManaPercentage() < 30 and Player:SpellHaste() < 0.667 and Player:BuffDown(S.ArcaneSurgeBuff)) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest touch_phase 2"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2&mana.pct<30&spell_haste<0.667&buff.arcane_surge.down
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2 and Player:ManaPercentage() < 30 and Player:SpellHaste() < 0.667 and Player:BuffDown(S.ArcaneSurgeBuff)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb touch_phase 4"; end
  end
  -- presence_of_mind,if=debuff.touch_of_the_magi.remains<=gcd.max
  if S.PresenceofMind:IsCastable() and (Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind touch_phase 6"; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 8"; end
  end
  -- arcane_barrage,if=(buff.arcane_harmony.up|(talent.arcane_bombardment&target.health.pct<35))&debuff.touch_of_the_magi.remains<=gcd.max
  if S.ArcaneBarrage:IsReady() and ((Player:BuffUp(S.ArcaneHarmonyBuff) or (S.ArcaneBombardment:IsAvailable() and Target:HealthPercentage() < 35)) and Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage touch_phase 10"; end
  end
  -- arcane_missiles,if=buff.clearcasting.stack>1&talent.conjure_mana_gem&cooldown.use_mana_gem.ready,chain=1,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&buff.nether_precision.up&(mana.pct>30&cooldown.touch_of_the_magi.remains>30|mana.pct>70)&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  if Player:IsChanneling(S.ArcaneMissiles) and Player:GCDRemains() == 0 and Player:BuffUp(S.NetherPrecisionBuff) and (Player:ManaPercentage() > 30 and S.TouchoftheMagi:CooldownRemains() > 30 or Player:ManaPercentage() > 70) and Player:BuffDown(S.ArcaneArtilleryBuff) then
    if HR.CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt touch_phase 12"; end
  end
  if S.ArcaneMissiles:IsCastable() and (Player:BuffStack(S.ClearcastingBuff) > 1 and S.ConjureManaGem:IsAvailable() and I.ManaGem:CooldownUp()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles touch_phase 14"; end
  end
  -- arcane_blast,if=buff.nether_precision.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 16"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&(debuff.touch_of_the_magi.remains>execute_time|!talent.presence_of_mind),chain=1,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&buff.nether_precision.up&(mana.pct>30&cooldown.touch_of_the_magi.remains>30|mana.pct>70)&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and (Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneMissiles:CastTime() or not S.PresenceofMind:IsAvailable())) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles touch_phase 18"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 20"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsReady() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage touch_phase 22"; end
  end
end

local function AoeTouchPhase()
  -- variable,name=conserve_mana,op=set,if=debuff.touch_of_the_magi.remains>9,value=1-variable.conserve_mana
  if Target:DebuffRemains(S.TouchoftheMagiDebuff) > 9 then
    var_conserve_mana = not var_conserve_mana
  end
  -- arcane_missiles,if=buff.arcane_artillery.up&buff.clearcasting.up
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ArcaneArtilleryBuff) and Player:BuffUp(S.ClearcastingBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles aoe_touch_phase 2"; end
  end
  -- arcane_barrage,if=(active_enemies<=4&buff.arcane_charge.stack=3)|buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsReady() and ((EnemiesCount8ySplash <= 4 and Player:ArcaneCharges() == 3) or Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_touch_phase 4"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_touch_phase 6"; end
  end
  -- arcane_explosion
  if S.ArcaneExplosion:IsReady() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion aoe_touch_phase 8"; end
  end
end

local function Rotation()
  -- arcane_orb,if=buff.arcane_charge.stack<3&(buff.bloodlust.down|mana.pct>70|(variable.totm_on_last_spark_stack&cooldown.touch_of_the_magi.remains>30))
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 3 and (Player:BloodlustDown() or Player:ManaPercentage() > 70 or (var_totm_on_last_spark_stack and S.TouchoftheMagi:CooldownRemains() > 30))) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb rotation 2"; end
  end
  -- variable,name=conserve_mana,op=set,if=cooldown.arcane_surge.remains>30,value=(cooldown.touch_of_the_magi.remains>10)
  -- variable,name=conserve_mana,op=set,if=cooldown.arcane_surge.remains<30,value=0
  var_conserve_mana = (S.ArcaneSurge:CooldownRemains() > 30) and S.TouchoftheMagi:CooldownRemains() > 10 or false
  -- nether_tempest,if=equipped.belorrelos_the_suncaller&cooldown.belorrelos_the_suncaller.ready&buff.siphon_storm.down&buff.arcane_surge.down&equipped.nymues_unraveling_spindle,line_cd=120
  if S.NetherTempest:IsReady() and (I.BelorrelostheSuncaller:IsEquippedAndReady() and Player:BuffDown(S.SiphonStormBuff) and Player:BuffDown(S.ArcaneSurgeBuff) and I.NymuesUnravelingSpindle:IsEquipped()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 4"; end
  end
  -- shifting_power,if=variable.totm_on_last_spark_stack&(!talent.evocation|cooldown.evocation.remains>12)&(!talent.arcane_surge|cooldown.arcane_surge.remains>12)&(!talent.touch_of_the_magi|cooldown.touch_of_the_magi.remains>12)&fight_remains>15
  if S.ShiftingPower:IsReady() and (var_totm_on_last_spark_stack and (not S.Evocation:IsAvailable() or S.Evocation:CooldownRemains() > 12) and (not S.ArcaneSurge:IsAvailable() or S.ArcaneSurge:CooldownRemains() > 12) and (not S.TouchoftheMagi:IsAvailable() or S.TouchoftheMagi:CooldownRemains() > 12) and FightRemains > 15) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power rotation 6"; end
  end
  -- shifting_power,if=!variable.totm_on_last_spark_stack&buff.arcane_surge.down&cooldown.arcane_surge.remains>45&fight_remains>15
  if S.ShiftingPower:IsReady() and (not var_totm_on_last_spark_stack and Player:BuffDown(S.ArcaneSurgeBuff) and S.ArcaneSurge:CooldownRemains() > 45 and FightRemains > 15) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power rotation 8"; end
  end
  -- nether_tempest,if=equipped.belorrelos_the_suncaller&cooldown.belorrelos_the_suncaller.ready&buff.siphon_storm.down&buff.arcane_surge.down&!equipped.nymues_unraveling_spindle,line_cd=120
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 120 and (I.BelorrelostheSuncaller:IsEquippedAndReady() and Player:BuffDown(S.SiphonStormBuff) and Player:BuffDown(S.ArcaneSurgeBuff) and not I.NymuesUnravelingSpindle:IsEquipped()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 10"; end
  end
  -- nether_tempest,if=(refreshable|!ticking)&equipped.neltharions_call_to_chaos&fight_remains>=12
  if S.NetherTempest:IsReady() and (Target:DebuffRefreshable(S.NetherTempestDebuff) and I.NeltharionsCalltoChaos:IsEquipped() and FightRemains >= 12) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 12"; end
  end
  -- presence_of_mind,if=buff.arcane_charge.stack<3&target.health.pct<35&talent.arcane_bombardment
  if S.PresenceofMind:IsCastable() and (Player:ArcaneCharges() < 3 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable()) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceOfMind) then return "presence_of_mind rotation 14"; end
  end
  -- arcane_blast,if=talent.time_anomaly&buff.arcane_surge.up&buff.arcane_surge.remains<=6
  if S.ArcaneBlast:IsReady() and (S.TimeAnomaly:IsAvailable() and Player:BuffUp(S.ArcaneSurgeBuff) and Player:BuffRemains(S.ArcaneSurgeBuff) <= 6) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 16"; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up&target.health.pct<35&talent.arcane_bombardment&buff.arcane_charge.stack<3
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff) and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 18"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&&buff.nether_precision.up&(mana.pct>30&cooldown.touch_of_the_magi.remains>30|mana.pct>70)&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  if Player:IsChanneling(S.ArcaneMissiles) and Player:GCDRemains() == 0 and Player:BuffUp(S.NetherPrecisionBuff) and (Player:ManaPercentage() > 30 and S.TouchoftheMagi:CooldownRemains() > 30 or Player:ManaPercentage() > 70) and Player:BuffDown(S.ArcaneArtilleryBuff) then
    if HR.CastAnnotated(S.StopAM, false, "STOP AM") then return "arcane_missiles interrupt rotation 20"; end
  end
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 22"; end
  end
  -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(buff.temporal_warp.up|mana.pct<10|!talent.shifting_power)&buff.arcane_surge.down&fight_remains>=12
  if S.NetherTempest:IsReady() and (Target:DebuffRefreshable(S.NetherTempestDebuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (Player:BuffUp(S.TemporalWarpBuff) or Player:ManaPercentage() < 10 or not S.ShiftingPower:IsAvailable()) and Player:BuffDown(S.ArcaneSurgeBuff) and FightRemains >= 12) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 24"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<50&!talent.evocation&fight_remains>20
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 50 and not S.Evocation:IsAvailable() and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 26"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<70&variable.conserve_mana&buff.bloodlust.up&cooldown.touch_of_the_magi.remains>5&fight_remains>20
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 70 and var_conserve_mana and Player:BloodlustUp() and S.TouchoftheMagi:CooldownRemains() > 5 and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 28"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.concentration.up&buff.arcane_charge.stack=buff.arcane_charge.max_stack,interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&&buff.nether_precision.up&(mana.pct>30&cooldown.touch_of_the_magi.remains>30|mana.pct>70)&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ConcentrationBuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 30"; end
  end
  -- arcane_blast,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.nether_precision.up
  if S.ArcaneBlast:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffUp(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 32"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<60&variable.conserve_mana&cooldown.touch_of_the_magi.remains>10&cooldown.evocation.remains>40&fight_remains>20
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 60 and var_conserve_mana and S.TouchoftheMagi:CooldownRemains() > 10 and S.Evocation:CooldownRemains() > 40 and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 34"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.nether_precision.down&(!variable.totm_on_last_spark_stack|!variable.opener),interrupt_if=action.arcane_missiles.channeling&gcd.remains=0&&buff.nether_precision.up&(mana.pct>30&cooldown.touch_of_the_magi.remains>30|mana.pct>70)&!buff.arcane_artillery.up,interrupt_immediate=1,interrupt_global=1
  -- Note: Interrupt handled in an above AM line.
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff) and (not var_totm_on_last_spark_stack or not var_opener)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 36"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 38"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsReady() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 40"; end
  end
end

local function AoeRotation()
  -- shifting_power,if=(!talent.evocation|cooldown.evocation.remains>12)&(!talent.arcane_surge|cooldown.arcane_surge.remains>12)&(!talent.touch_of_the_magi|cooldown.touch_of_the_magi.remains>12)&buff.arcane_surge.down&((!talent.charged_orb&cooldown.arcane_orb.remains>12)|(action.arcane_orb.charges=0|cooldown.arcane_orb.remains>12))
  if S.ShiftingPower:IsReady() and ((not S.Evocation:IsAvailable() or S.Evocation:CooldownRemains() > 12) and (not S.ArcaneSurge:IsAvailable() or S.ArcaneSurge:CooldownRemains() > 12) and (not S.TouchoftheMagi:IsAvailable() or S.TouchoftheMagi:CooldownRemains() > 12) and Player:BuffDown(S.ArcaneSurgeBuff) and ((not S.ChargedOrb:IsAvailable() and S.ArcaneOrb:CooldownRemains() > 12) or (S.ArcaneOrb:Charges() == 0 or S.ArcaneOrb:CooldownRemains() > 12))) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power aoe_rotation 2"; end
  end
  -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_surge.down&(active_enemies>6|!talent.orb_barrage)
  if S.NetherTempest:IsReady() and (Target:DebuffRefreshable(S.NetherTempestDebuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcaneSurgeBuff) and (EnemiesCount8ySplash > 6 or not S.OrbBarrage:IsAvailable())) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe_rotation 4"; end
  end
  -- arcane_missiles,if=buff.arcane_artillery.up&buff.clearcasting.up&cooldown.touch_of_the_magi.remains>(buff.arcane_artillery.remains+5)
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ArcaneArtilleryBuff) and Player:BuffUp(S.ClearcastingBuff) and S.TouchoftheMagi:CooldownRemains() > Player:BuffRemains(S.ArcaneArtilleryBuff) + 5) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles aoe_rotation 6"; end
  end
  -- arcane_barrage,if=(active_enemies<=4|buff.clearcasting.up)&buff.arcane_charge.stack=3
  if S.ArcaneBarrage:IsReady() and ((EnemiesCount8ySplash <= 4 or Player:BuffUp(S.ClearcastingBuff)) and Player:ArcaneCharges() == 3) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_rotation 8"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack=0&cooldown.touch_of_the_magi.remains>18
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() == 0 and S.TouchoftheMagi:CooldownRemains() > 18) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_rotation 10"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack|mana.pct<10
  if S.ArcaneBarrage:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or Player:ManaPercentage() < 10) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_rotation 12"; end
  end
  -- arcane_explosion
  if S.ArcaneExplosion:IsReady() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion aoe_rotation 14"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  else
    EnemiesCount8ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  GCDMax = Player:GCD() + 0.25

  -- Set which cast function to use for ArcaneExplosion
  CastAE = (Settings.Arcane.AEMainIcon) and Cast or CastLeft

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: moved outside of precombat
    if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
      if Cast(S.ArcaneIntellect, Settings.Commons.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- potion,if=cooldown.arcane_surge.ready
    if Settings.Commons.Enabled.Potions and (S.ArcaneSurge:CooldownUp()) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- time_warp,if=talent.temporal_warp&buff.exhaustion.up&(cooldown.arcane_surge.ready|fight_remains<=40|(buff.arcane_surge.up&fight_remains<=(cooldown.arcane_surge.remains+14)))
      if S.TimeWarp:IsReady() and Settings.Commons.UseTemporalWarp and (S.TemporalWarp:IsAvailable() and Player:BloodlustExhaustUp() and (S.ArcaneSurge:CooldownUp() or FightRemains <= 40 or (Player:BuffUp(S.ArcaneSurgeBuff) and FightRemains <= (S.ArcaneSurge:CooldownRemains() + 14)))) then
        if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp main 4"; end
      end
      -- lights_judgment,if=buff.arcane_surge.down&debuff.touch_of_the_magi.down&active_enemies>=2
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= 2) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 6"; end
      end
      -- berserking,if=(prev_gcd.1.arcane_surge&!(buff.temporal_warp.up&buff.bloodlust.up))|(buff.arcane_surge.up&debuff.touch_of_the_magi.up)
      if S.Berserking:IsCastable() and ((Player:PrevGCDP(1, S.ArcaneSurge) and not (Player:BuffUp(S.TemporalWarpBuff) and Player:BloodlustUp())) or Player:BuffUp(S.ArcaneSurgeBuff) and Target:DebuffUp(S.TouchoftheMagiDebuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 8"; end
      end
      if Player:PrevGCDP(1, S.ArcaneSurge) then
        -- blood_fury,if=prev_gcd.1.arcane_surge
        if S.BloodFury:IsCastable() then
          if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 10"; end
        end
        -- fireblood,if=prev_gcd.1.arcane_surge
        if S.Fireblood:IsCastable() then
          if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 12"; end
        end
        -- ancestral_call,if=prev_gcd.1.arcane_surge
        if S.AncestralCall:IsCastable() then
          if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 14"; end
        end
      end
      -- invoke_external_buff,name=power_infusion,if=((!talent.radiant_spark&prev_gcd.1.arcane_surge)|(talent.radiant_spark&prev_gcd.1.radiant_spark&cooldown.arcane_surge.remains<=(gcd.max*3)))
      -- invoke_external_buff,name=blessing_of_summer,if=(!talent.radiant_spark&prev_gcd.1.arcane_surge)|(talent.radiant_spark&prev_gcd.1.radiant_spark&cooldown.arcane_surge.remains<=(gcd.max*3))
      -- invoke_external_buff,name=blessing_of_autumn,if=cooldown.touch_of_the_magi.remains>5
      -- Note: Not handling external buffs
      if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
        -- use_items,if=(((prev_gcd.1.arcane_surge&!set_bonus.tier30_4pc)|(prev_gcd.2.arcane_surge&debuff.touch_of_the_magi.up&set_bonus.tier30_4pc))|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest))|fight_remains<=15
        if (((Player:PrevGCDP(1, S.ArcaneSurge) and not Player:HasTier(30, 4)) or (Player:PrevGCDP(2, S.ArcaneSurge) and Target:DebuffUp(S.TouchoftheMagiDebuff) and Player:HasTier(30, 4))) or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) or FightRemains <= 15 then
          local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
          if ItemToUse then
            local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
            if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
            if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~= 13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
              if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
            end
          end
        end
        if Settings.Commons.Enabled.Trinkets then
          -- use_item,name=voidmenders_shadowgem,if=(buff.siphon_storm.up&buff.siphon_storm.remains<19&(cooldown.arcane_surge.remains<12|buff.arcane_surge.up)&(debuff.touch_of_the_magi.remains>8|cooldown.touch_of_the_magi.remains<8))|fight_remains<=15|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
          if I.VoidmendersShadowgem:IsEquippedAndReady() and ((Player:BuffUp(S.SiphonStormBuff) and Player:BuffRemains(S.SiphonStormBuff) < 19 and (S.ArcaneSurge:CooldownRemains() < 12 or Player:BuffUp(S.ArcaneSurgeBuff)) and (Target:DebuffRemains(S.TouchoftheMagiDebuff) > 8 or S.TouchoftheMagi:CooldownRemains() < 8)) or FightRemains <= 15 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) then
            if Cast(I.VoidmendersShadowgem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "voidmenders_shadowgem main 16"; end
          end
          -- use_item,name=timebreaching_talon,if=(((!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.remains)|(set_bonus.tier30_4pc&prev_gcd.1.arcane_surge))&(!variable.irideus_double_on_use|!buff.bloodlust.up))|fight_remains<=20|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
          if I.TimebreachingTalon:IsEquippedAndReady() and ((((not Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) and S.RadiantSpark:CooldownDown()) or (Player:HasTier(30, 4) and Player:PrevGCDP(1, S.ArcaneSurge))) and (not var_irideus_double_on_use or Player:BloodlustDown())) or FightRemains <= 20 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) then
            if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon main 18"; end
          end
          -- use_item,name=obsidian_gladiators_badge_of_ferocity,if=((variable.badgebalefire_double_on_use&(debuff.touch_of_the_magi.up|buff.arcane_surge.up|(buff.siphon_storm.up&variable.opener)))|(!variable.badgebalefire_double_on_use&prev_gcd.1.arcane_surge))||fight_remains<=15|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
          if I.ObsidianGladiatorsBadge:IsEquippedAndReady() and (((var_badgebalefire_double_on_use and (Target:DebuffUp(S.TouchoftheMagiDebuff) or Player:BuffUp(S.ArcaneSurgeBuff) or (Player:BuffUp(S.SiphonStormBuff) and var_opener))) or (not var_badgebalefire_double_on_use and Player:PrevGCDP(1, S.ArcaneSurge))) or FightRemains <= 15 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) then
            if Cast(I.ObsidianGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "obsidian_gladiators_badge_of_ferocity main 20"; end
          end
          -- use_item,name=mirror_of_fractured_tomorrows,if=(((!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.remains>0)|(set_bonus.tier30_4pc&prev_gcd.1.arcane_surge))&(!variable.balefire_double_on_use|!buff.bloodlust.up))|fight_remains<=20|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
          if I.MirrorofFracturedTomorrows:IsEquippedAndReady() and ((((not Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) and S.RadiantSpark:CooldownDown()) or (Player:HasTier(30, 4) and Player:PrevGCDP(1, S.ArcaneSurge))) and (not var_balefire_double_on_use or Player:BloodlustDown())) or FightRemains <= 20 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) then
            if Cast(I.MirrorofFracturedTomorrows, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows main 22"; end
          end
          -- use_item,name=balefire_branch,if=(buff.siphon_storm.up&((buff.siphon_storm.remains<15&(variable.mirror_double_on_use|variable.balefire_double_on_use))|(buff.siphon_storm.remains<20&!variable.mirror_double_on_use&!variable.balefire_double_on_use)|set_bonus.tier30_4pc)&(cooldown.arcane_surge.remains<10|buff.arcane_surge.up)&(debuff.touch_of_the_magi.remains>8|cooldown.touch_of_the_magi.remains<8|equipped.belorrelos_the_suncaller&set_bonus.tier30_4pc))|variable.badgebalefire_double_on_use&(debuff.touch_of_the_magi.up|buff.arcane_surge.up|(buff.siphon_storm.up&variable.opener))|fight_remains<=15|((active_enemies>=variable.aoe_target_count)&((cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|buff.siphon_storm.remains>15))
          if I.BalefireBranch:IsEquippedAndReady() and ((Player:BuffUp(S.SiphonStormBuff) and ((Player:BuffRemains(S.SiphonStormBuff) < 15 and (var_mirror_double_on_use or var_balefire_double_on_use)) or (Player:BuffRemains(S.SiphonStormBuff) < 20 and not var_mirror_double_on_use and not var_balefire_double_on_use) or Player:HasTier(30, 4)) and (S.ArcaneSurge:CooldownRemains() < 10 or Player:BuffUp(S.ArcaneSurgeBuff)) and (Target:DebuffRemains(S.TouchoftheMagiDebuff) > 8 or S.TouchoftheMagi:CooldownRemains() < 8 or I.BelorrelostheSuncaller:IsEquipped() and Player:HasTier(30, 4))) or var_badgebalefire_double_on_use and (Target:DebuffUp(S.TouchoftheMagiDebuff) or Player:BuffUp(S.ArcaneSurgeBuff) or (Player:BuffUp(S.SiphonStormBuff) and var_opener)) or FightRemains <= 15 or ((EnemiesCount8ySplash >= var_aoe_target_count) and ((S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest)) or Player:BuffRemains(S.SiphonStormBuff) > 15))) then
            if Cast(I.BalefireBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "balefire_branch main 24"; end
          end
          -- use_item,name=ashes_of_the_embersoul,if=(((!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.remains>0)|(set_bonus.tier30_4pc&prev_gcd.1.arcane_surge))&(!variable.mirror_double_on_use|!buff.bloodlust.up)&(!variable.balefire_double_on_use|!buff.bloodlust.up))|fight_remains<=20|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|(equipped.belorrelos_the_suncaller&buff.arcane_surge.remains>12)
          if I.AshesoftheEmbersoul:IsEquippedAndReady() and ((((not Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) and S.RadiantSpark:CooldownDown()) or (Player:HasTier(30, 4) and Player:PrevGCDP(1, S.ArcaneSurge))) and (not var_mirror_double_on_use or Player:BloodlustDown()) and (not var_balefire_double_on_use or Player:BloodlustDown())) or FightRemains <= 20 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest)) or (I.BelorrelostheSuncaller:IsEquipped() and Player:BuffRemains(S.ArcaneSurgeBuff) > 12)) then
            if Cast(I.AshesoftheEmbersoul, nil, Settings.Commons.DisplayStyle.Trinkets) then return "ashes_of_the_embersoul main 26"; end
          end
          -- use_item,name=nymues_unraveling_spindle,if=(((!variable.opener&!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*7)&cooldown.radiant_spark.ready)|(set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.ready)|(variable.opener&!set_bonus.tier30_4pc&buff.bloodlust.up&mana<=200000))&(!variable.mirror_double_on_use|!buff.bloodlust.up)&(!variable.balefire_double_on_use|!buff.bloodlust.up)&(!variable.ashes_double_on_use|!buff.bloodlust.up))|fight_remains<=24|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)|(equipped.belorrelos_the_suncaller&buff.arcane_surge.remains>12)
          if I.NymuesUnravelingSpindle:IsEquippedAndReady() and ((((not var_opener and not Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 7) and S.RadiantSpark:CooldownUp()) or (Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) and S.RadiantSpark:CooldownUp()) or (var_opener and not Player:HasTier(30, 4) and Player:BloodlustUp() and Player:Mana() <= 200000)) and (not var_mirror_double_on_use or Player:BloodlustDown()) and (not var_balefire_double_on_use or Player:BloodlustDown()) and (not var_ashes_double_on_use or Player:BloodlustDown())) or FightRemains <= 24 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest)) or (I.BelorrelostheSuncaller:IsEquipped() and Player:BuffRemains(S.ArcaneSurgeBuff) > 12)) then
            if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle main 28"; end
          end
          -- use_item,name=sea_star,if=(((!set_bonus.tier30_4pc&cooldown.arcane_surge.remains<=(gcd.max*4)&cooldown.radiant_spark.remains>0)|(set_bonus.tier30_4pc&prev_gcd.1.arcane_surge))&(!variable.mirror_double_on_use|!buff.bloodlust.up)&(!variable.balefire_double_on_use|!buff.bloodlust.up)&(!variable.ashes_double_on_use|!buff.bloodlust.up))|fight_remains<=20|((active_enemies>=variable.aoe_target_count)&cooldown.arcane_surge.ready&prev_gcd.1.nether_tempest)
          if I.SeaStar:IsEquippedAndReady() and ((((not Player:HasTier(30, 4) and S.ArcaneSurge:CooldownRemains() <= (GCDMax * 4) and S.RadiantSpark:CooldownDown()) or (Player:HasTier(30, 4) and Player:PrevGCDP(1, S.ArcaneSurge))) and (not var_mirror_double_on_use or Player:BloodlustDown()) and (not var_balefire_double_on_use or Player:BloodlustDown()) and (not var_ashes_double_on_use or Player:BloodlustDown())) or FightRemains <= 20 or ((EnemiesCount8ySplash >= var_aoe_target_count) and S.ArcaneSurge:CooldownUp() and Player:PrevGCDP(1, S.NetherTempest))) then
            if Cast(I.SeaStar, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sea_star main 30"; end
          end
          -- use_item,name=tinker_breath_of_neltharion,if=cooldown.arcane_surge.remains&buff.arcane_surge.down&debuff.touch_of_the_magi.down
          -- TODO: Handle tinkers
          -- use_item,name=conjured_chillglobe,if=mana.pct>65&(!variable.steroid_trinket_equipped|buff.siphon_storm.down)
          if I.ConjuredChillglobe:IsEquippedAndReady() and (Player:ManaPercentage() > 65 and (not var_steroid_trinket_equipped or Player:BuffDown(S.SiphonStormBuff))) then
            if Cast(I.ConjuredChillglobe, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "conjured_chillglobe main 32"; end
          end
          -- use_item,name=beacon_to_the_beyond,if=!variable.steroid_trinket_equipped|(buff.siphon_storm.down&buff.arcane_surge.remains<10)
          if I.BeacontotheBeyond:IsEquippedAndReady() and (not var_steroid_trinket_equipped or (Player:BuffDown(S.SiphonStormBuff) and Player:BuffRemains(S.ArcaneSurgeBuff) < 10)) then
            if Cast(I.BeacontotheBeyond, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "beacon_to_the_beyond main 34"; end
          end
          if (not var_steroid_trinket_equipped or Player:BuffDown(S.SiphonStormBuff)) then
            -- use_item,name=darkmoon_deck_rime,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
            if I.DMDRime:IsEquippedAndReady() then
              if Cast(I.DMDRime, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "darkmoon_deck_rime main 36"; end
            end
            if I.DMDRimeBox:IsEquippedAndReady() then
              if Cast(I.DMDRimeBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "darkmoon_deck_box_rime main 38"; end
            end
            -- use_item,name=darkmoon_deck_dance,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
            if I.DMDDance:IsEquippedAndReady() then
              if Cast(I.DMDDance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(25)) then return "darkmoon_deck_dance main 40"; end
            end
            if I.DMDDanceBox:IsEquippedAndReady() then
              if Cast(I.DMDDanceBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(25)) then return "darkmoon_deck_box_dance main 42"; end
            end
            -- use_item,name=darkmoon_deck_inferno,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
            if I.DMDInferno:IsEquippedAndReady() then
              if Cast(I.DMDInferno, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "darkmoon_deck_inferno main 44"; end
            end
            if I.DMDInfernoBox:IsEquippedAndReady() then
              if Cast(I.DMDInfernoBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "darkmoon_deck_box_inferno main 46"; end
            end
            -- use_item,name=desperate_invokers_codex,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
            if I.DesperateInvokersCodex:IsEquippedAndReady() then
              if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "desperate_invokers_codex main 48"; end
            end
            -- use_item,name=iceblood_deathsnare,if=!variable.steroid_trinket_equipped|buff.siphon_storm.down
            if I.IcebloodDeathsnare:IsEquippedAndReady() then
              if Cast(I.IcebloodDeathsnare, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "iceblood_deathsnare main 50"; end
            end
          end
          -- use_item,name=belorrelos_the_suncaller,use_off_gcd=1,if=gcd.remains&!dot.radiant_spark.remains&(!variable.steroid_trinket_equipped|buff.siphon_storm.down)
          if I.BelorrelostheSuncaller:IsEquippedAndReady() and (Target:DebuffDown(S.RadiantSparkDebuff) and (not var_steroid_trinket_equipped or Player:BuffDown(S.SiphonStormBuff))) then
            if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller main 51"; end
          end
        end
        if Settings.Commons.Enabled.Items then
          -- use_item,name=dreambinder_loom_of_the_great_cycle
          if I.Dreambinder:IsEquippedAndReady() then
            if Cast(I.Dreambinder, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder_loom_of_the_great_cycle main 52"; end
          end
          -- use_item,name=iridal_the_earths_master,use_off_gcd=1,if=gcd.remains
          if I.IridaltheEarthsMaster:IsEquippedAndReady() then
            if Cast(I.IridaltheEarthsMaster, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(40)) then return "iridal_the_earths_master main 53"; end
          end
        end
      end
    end
    -- Var calculations
    local ShouldReturn = Calculations(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: touch_of_the_magi,if=prev_gcd.1.arcane_barrage
    if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi main 54"; end
    end
    -- cancel_action,if=action.evocation.channeling&mana.pct>=95&!talent.siphon_storm
    -- cancel_action,if=action.evocation.channeling&(mana.pct>fight_remains*4)&!(fight_remains>10&cooldown.arcane_surge.remains<1)
    if Player:IsChanneling(S.Evocation) and ((Player:ManaPercentage() >= 95 and not S.SiphonStorm:IsAvailable()) or ((Player:ManaPercentage() > FightRemains * 4) and not (FightRemains > 10 and S.ArcaneSurge:CooldownRemains() < 1))) then
      if HR.CastAnnotated(S.StopAM, false, "STOP EVOC") then return "cancel_action evocation main 56"; end
    end
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 58"; end
    end
    -- evocation,if=buff.arcane_surge.down&debuff.touch_of_the_magi.down&((mana.pct<10&cooldown.touch_of_the_magi.remains<20)|cooldown.touch_of_the_magi.remains<(15-(5*(equipped.balefire_branch&variable.totm_on_last_spark_stack&(spell_haste>0.667|buff.bloodlust.up)))))&(mana.pct<fight_remains*4)
    -- Note: Manually added var_opener check, as we don't want to cast Evocation during the initial opener.
    if S.Evocation:IsCastable() and not var_opener and (Player:BuffDown(S.ArcaneSurgeBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and ((Player:ManaPercentage() < 10 and S.TouchoftheMagi:CooldownRemains() < 20) or S.TouchoftheMagi:CooldownRemains() < (15 - (5 * num(I.BalefireBranch:IsEquipped() and var_totm_on_last_spark_stack and (Player:SpellHaste() > 0.667 or Player:BloodlustUp()))))) and (Player:ManaPercentage() < FightRemains * 4)) then
      if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation main 60"; end
    end
    -- conjure_mana_gem,if=debuff.touch_of_the_magi.down&buff.arcane_surge.down&cooldown.arcane_surge.remains<30&cooldown.arcane_surge.remains<fight_remains&!mana_gem_charges
    if S.ConjureManaGem:IsCastable() and (Target:DebuffDown(S.TouchoftheMagiDebuff) and Player:BuffDown(S.ArcaneSurgeBuff) and S.ArcaneSurge:CooldownRemains() < 30 and S.ArcaneSurge:CooldownRemains() < FightRemains and not I.ManaGem:Exists()) then
      if Cast(S.ConjureManaGem) then return "conjure_mana_gem main 62"; end
    end
    -- use_mana_gem,if=talent.cascading_power&buff.clearcasting.stack<2&buff.arcane_surge.up
    -- TODO: Fix hotkey issue, as item and spell use the same icon
    if I.ManaGem:IsReady() and Settings.Arcane.Enabled.ManaGem and (S.CascadingPower:IsAvailable() and Player:BuffStack(S.ClearcastingBuff) < 2 and Player:BuffUp(S.ArcaneSurgeBuff)) then
      if Cast(I.ManaGem, Settings.Arcane.OffGCDasOffGCD.ManaGem) then return "mana_gem main 64"; end
    end
    -- use_mana_gem,if=!talent.cascading_power&(prev_gcd.1.arcane_surge&!variable.surge_last_spark_stack|variable.surge_last_spark_stack&prev_gcd.2.arcane_surge)
    -- TODO: Fix hotkey issue, as item and spell use the same icon
    if I.ManaGem:IsReady() and Settings.Arcane.Enabled.ManaGem and (not S.CascadingPower:IsAvailable() and (Player:PrevGCDP(1, S.ArcaneSurge) and not var_surge_last_spark_stack or var_surge_last_spark_stack and Player:PrevGCDP(2, S.ArcaneSurge))) then
      if Cast(I.ManaGem, Settings.Arcane.OffGCDasOffGCD.ManaGem) then return "mana_gem main 66"; end
    end
    -- call_action_list,name=cooldown_phase,if=!variable.totm_on_last_spark_stack&(cooldown.arcane_surge.remains<=(gcd.max*(1+(talent.nether_tempest&talent.arcane_echo)))|(buff.arcane_surge.remains>(3*(set_bonus.tier30_2pc&!set_bonus.tier30_4pc)))|buff.arcane_overload.up)&cooldown.evocation.remains>45&((cooldown.touch_of_the_magi.remains<gcd.max*4)|cooldown.touch_of_the_magi.remains>20)&active_enemies<variable.aoe_target_count
    if (not var_totm_on_last_spark_stack and (S.ArcaneSurge:CooldownRemains() <= (GCDMax * (1 + num(S.NetherTempest:IsAvailable() and S.ArcaneEcho:IsAvailable()))) or (Player:BuffRemains(S.ArcaneSurgeBuff) > (3 * num(Player:HasTier(30, 2) and not Player:HasTier(30, 4)))) or Player:BuffUp(S.ArcaneOverloadBuff)) and S.Evocation:CooldownRemains() > 45 and ((S.TouchoftheMagi:CooldownRemains() < GCDMax * 4) or S.TouchoftheMagi:CooldownRemains() > 20) and EnemiesCount8ySplash < var_aoe_target_count) then
      local ShouldReturn = CooldownPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cooldown_phase,if=!variable.totm_on_last_spark_stack&cooldown.arcane_surge.remains>30&(cooldown.radiant_spark.ready|dot.radiant_spark.remains|debuff.radiant_spark_vulnerability.up)&(cooldown.touch_of_the_magi.remains<=(gcd.max*3)|debuff.touch_of_the_magi.up)&active_enemies<variable.aoe_target_count
    if (not var_totm_on_last_spark_stack and S.ArcaneSurge:CooldownRemains() > 30 and (S.RadiantSpark:CooldownUp() or Target:DebuffUp(S.RadiantSparkDebuff) or Target:DebuffUp(S.RadiantSparkVulnerability)) and (S.TouchoftheMagi:CooldownRemains() <= GCDMax * 3 or Target:DebuffUp(S.TouchoftheMagiDebuff)) and EnemiesCount8ySplash < var_aoe_target_count) then
      local ShouldReturn = CooldownPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_spark_phase,if=talent.radiant_spark&variable.aoe_spark_phase
    if CDsON() and S.RadiantSpark:IsAvailable() and var_aoe_spark_phase then
      local ShouldReturn = AoeSparkPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=spark_phase,if=variable.totm_on_last_spark_stack&talent.radiant_spark&variable.spark_phase
    if CDsON() and var_totm_on_last_spark_stack and S.RadiantSpark:IsAvailable() and var_spark_phase then
      local ShouldReturn = SparkPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_touch_phase,if=debuff.touch_of_the_magi.up&active_enemies>=variable.aoe_target_count
    if CDsON() and Target:DebuffUp(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= var_aoe_target_count then
      local ShouldReturn = AoeTouchPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=touch_phase,if=variable.totm_on_last_spark_stack&debuff.touch_of_the_magi.up&active_enemies<variable.aoe_target_count
    if CDsON() and var_totm_on_last_spark_stack and Target:DebuffUp(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash < var_aoe_target_count then
      local ShouldReturn = TouchPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_rotation,if=active_enemies>=variable.aoe_target_count
    if EnemiesCount8ySplash >= var_aoe_target_count then
      local ShouldReturn = AoeRotation(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rotation
    local ShouldReturn = Rotation(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Init()
  HR.Print("Arcane Mage rotation has been updated for patch 10.2.0.")
end

HR.SetAPL(62, APL, Init)
