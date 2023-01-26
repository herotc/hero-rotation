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

-- Variables
local Enemies8ySplash, EnemiesCount8ySplash --Enemies arround target
local var_aoe_target_count
local var_conserve_mana
local var_opener
local var_opener_min_mana
local var_steroid_trinket_equipped
local var_aoe_spark_phase
local var_spark_phase
local var_rop_phase
local ArcaneSurge = (S.ArcanePower:IsAvailable()) and S.ArcanePower or S.ArcaneSurge

local ClearCastingMaxStack = 3 --buff.clearcasting.max_stack
local BossFightRemains = 11111
local FightRemains = 11111
local CastAE
local GCDMax

HL:RegisterForEvent(function()
  VarConserveMana = 0
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  ArcaneSurge = (S.ArcanePower:IsAvailable()) and S.ArcanePower or S.ArcaneSurge
end, "PLAYER_TALENT_UPDATE")

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_familiar
  if S.ArcaneFamiliar:IsCastable() and Player:BuffDown(S.ArcaneFamiliarBuff) then
    if Cast(S.ArcaneFamiliar) then return "arcane_familiar precombat 2"; end
  end  
  -- arcane_intellect
  -- Note: moved outside of precombat
  -- conjure_mana_gem
  -- TODO: Fix hotkey issue (spell and item use the same icon)
  if S.ConjureManaGem:IsCastable() then
    if Cast(S.ConjureManaGem) then return "conjure_mana_gem precombat 4"; end
  end
  -- variable,name=aoe_target_count,op=reset,default=3
  var_aoe_target_count = 3
  -- variable,name=conserve_mana,op=set,value=0
  var_conserve_mana = false
  -- variable,name=opener,op=set,value=1
  var_opener = true
  -- variable,name=opener_min_mana,default=-1,op=set,if=variable.opener_min_mana=-1,value=225000-(25000*!talent.arcane_harmony)
  var_opener_min_mana = 225000 - (25000 * num(not S.ArcaneHarmony:IsAvailable()))
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.irideus_fragment|equipped.erupting_spear_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor
  var_steroid_trinket_equipped = (I.GladiatorsBadgeofFerocity:IsEquipped() or I.IrideusFragment:IsEquipped() or I.EruptingSpearFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped())
  -- mirror_image
  if S.MirrorImage:IsCastable() and CDsON() and Settings.Arcane.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Arcane.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 6"; end
  end
  -- evocation,if=talent.siphon_storm
  -- Note: inversed to allow precast arcane blast
  if S.Evocation:IsReady() and (S.SiphonStorm:IsAvailable()) then
    if Cast(S.Evocation) then return "evocation precombat 8"; end
  end
  -- arcane_blast,if=!talent.siphon_storm
  -- Note: inversed to allow precast arcane blast
  if S.ArcaneBlast:IsReady() and not Player:IsCasting(S.ArcaneBlast) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast precombat 10"; end
  end

end

local function Calculations()
  --variable,name=aoe_spark_phase,op=set,value=1,if=active_enemies>=variable.aoe_target_count&(action.arcane_orb.charges>0|buff.arcane_charge.stack>=3)&(!talent.rune_of_power|cooldown.rune_of_power.ready)&cooldown.radiant_spark.ready&cooldown.touch_of_the_magi.remains<=(gcd.max*2)
  --variable,name=aoe_spark_phase,op=set,value=0,if=variable.aoe_spark_phase&debuff.radiant_spark_vulnerability.down&dot.radiant_spark.remains<5&cooldown.radiant_spark.remains
  if (EnemiesCount8ySplash >= var_aoe_target_count and (S.ArcaneOrb:Charges() > 0 or Player:ArcaneCharges() >= 3) and ((not S.RuneofPower:IsAvailable()) or S.RuneofPower:CooldownUp()) and S.RadiantSpark:CooldownUp() and S.TouchoftheMagi:CooldownRemains() <= GCDMax * 2) then
    var_aoe_spark_phase = true
  elseif (var_aoe_spark_phase and Target:DebuffDown(S.RadiantSparkVulnerability) and Target:DebuffRemains(S.RadiantSparkDebuff) < 5 and S.RadiantSpark:CooldownDown()) then
    var_aoe_spark_phase = false
  end
  --variable,name=spark_phase,op=set,value=1,if=buff.arcane_charge.stack>=3&active_enemies<variable.aoe_target_count&(!talent.rune_of_power|cooldown.rune_of_power.ready)&cooldown.radiant_spark.ready&cooldown.touch_of_the_magi.remains<=(gcd.max*7)
  --variable,name=spark_phase,op=set,value=0,if=variable.spark_phase&debuff.radiant_spark_vulnerability.down&dot.radiant_spark.remains<5&cooldown.radiant_spark.remains
  if (Player:ArcaneCharges() >= 3 and EnemiesCount8ySplash < var_aoe_target_count and ((not S.RuneofPower:IsAvailable()) or S.RuneofPower:CooldownUp()) and S.RadiantSpark:CooldownUp() and S.TouchoftheMagi:CooldownRemains() <= GCDMax * 7) then
    var_spark_phase = true
  elseif (var_spark_phase and Target:DebuffDown(S.RadiantSparkVulnerability) and Target:DebuffRemains(S.RadiantSparkDebuff) < 5 and S.RadiantSpark:CooldownDown()) then
    var_spark_phase = false
  end
  --variable,name=rop_phase,op=set,value=1,if=talent.rune_of_power&!talent.radiant_spark&buff.arcane_charge.stack>=3&cooldown.rune_of_power.ready&active_enemies<variable.aoe_target_count
  --variable,name=rop_phase,op=set,value=0,if=debuff.touch_of_the_magi.up|!talent.rune_of_power  
  if (S.RuneofPower:IsAvailable() and (not S.RadiantSpark:IsAvailable()) and Player:ArcaneCharges() >= 3 and S.RuneofPower:CooldownUp() and EnemiesCount8ySplash < var_aoe_target_count) then
    var_rop_phase = true
  elseif (Target:DebuffUp(S.TouchoftheMagiDebuff) or not S.RuneofPower:IsAvailable()) then
    var_rop_phase = false
  end
  -- variable,name=opener,op=set,if=debuff.touch_of_the_magi.up&variable.opener,value=0
  if (Target:DebuffUp(S.TouchoftheMagiDebuff) and var_opener) then
    var_opener = false
  end
end

local function AoeRotation()
  --arcane_orb,if=buff.arcane_charge.stack<2
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_rotation 2"; end
  end
  --shifting_power,if=(!talent.evocation|cooldown.evocation.remains>12)&(!talent.arcane_surge|cooldown.arcane_surge.remains>12)&(!talent.touch_of_the_magi|cooldown.touch_of_the_magi.remains>12)&buff.arcane_surge.down
  if S.ShiftingPower:IsReady() and (((not S.Evocation:IsAvailable()) or S.Evocation:CooldownRemains() > 12) and ((not S.ArcaneSurge:IsAvailable()) or ArcaneSurge:CooldownRemains() > 12) and ((not S.TouchoftheMagi:IsAvailable()) or S.TouchoftheMagi:CooldownRemains() > 12) and Player:BuffDown(S.ArcaneSurgeBuff)) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power aoe_rotation 4"; end
  end
  --ice_nova,if=buff.arcane_surge.down
  if S.IceNova:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff)) then
    if Cast(S.IceNova, nil, nil, not Target:IsInRange(40)) then return "ice_nova aoe_rotation 6"; end
  end
  --nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.arcane_surge.down
  if S.NetherTempest:IsReady() and (Target:DebuffRefreshable(S.NetherTempestDebuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffDown(S.ArcaneSurgeBuff)) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe_rotation 8"; end
  end
  --arcane_missiles,if=buff.clearcasting.react&talent.arcane_harmony&talent.rune_of_power&cooldown.rune_of_power.remains<(gcd.max*2)
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and S.ArcaneHarmony:IsAvailable() and S.RuneofPower:IsAvailable() and S.RuneofPower:CooldownRemains() < Player:GCD() * 2) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles aoe_rotation 10"; end
  end
  --arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack|mana.pct<10
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() or Player:ManaPercentage() < 10) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_rotation 12"; end
  end
  --arcane_explosion
  if S.ArcaneExplosion:IsReady() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion aoe_rotation 14"; end
  end
end

local function AoeSparkPhase()
  -- cancel_buff,name=presence_of_mind,if=prev_gcd.1.arcane_blast&cooldown.arcane_surge.remains>75
  -- TODO: figure out how to do that
  -- rune_of_power,if=cooldown.arcane_surge.remains<75&cooldown.arcane_surge.remains>30
  if S.RuneofPower:IsCastable() and (ArcaneSurge:CooldownRemains() < 75 and ArcaneSurge:CooldownRemains() > 30) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power aoe_spark_phase 2"; end
  end
  -- radiant_spark
  if S.RadiantSpark:IsReady() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark aoe_spark_phase 4"; end
  end
  -- use_item,name=timebreaching_talon,if=cooldown.arcane_surge.remains<=(gcd.max*2)
  if I.TimebreachingTalon:IsEquippedAndReady() and (S.ArcaneSurge:CooldownRemains() <= GCDMax * 2) then
    if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon aoe_spark_phase 6"; end
  end
  -- arcane_explosion,if=buff.arcane_charge.stack>=3&prev_gcd.1.radiant_spark
  if S.ArcaneExplosion:IsReady() and (Player:ArcaneCharges() >= 3 and Player:PrevGCDP(1, S.RadiantSpark)) then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion aoe_spark_phase 8"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<3,line_cd=15
  if S.ArcaneOrb:IsReady() and S.ArcaneOrb:TimeSinceLastCast() >= 15 and (Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_spark_phase 10"; end
  end
  -- nether_tempest,if=talent.arcane_echo,line_cd=15
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 15 and (S.ArcaneEcho:IsAvailable()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest aoe_spark_phase 12"; end
  end
  -- arcane_surge
  if S.ArcaneSurge:IsReady() then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge aoe_spark_phase 14"; end
  end
  -- wait,sec=0.05,if=cooldown.arcane_surge.remains>75&prev_gcd.1.arcane_blast&!talent.presence_of_mind,line_cd=15
  -- wait,sec=0.05,if=prev_gcd.1.arcane_surge,line_cd=15
  -- wait,sec=0.05,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=3&!talent.presence_of_mind,line_cd=15
  -- Note: see if we want to manage that...
  -- arcane_barrage,if=cooldown.arcane_surge.remains<75&debuff.radiant_spark_vulnerability.stack=4
  if S.ArcaneBarrage:IsCastable() and (ArcaneSurge:CooldownRemains() < 75 and Target:DebuffStack(S.RadiantSparkVulnerability) == 4) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 16"; end
  end
  -- arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=2&cooldown.arcane_surge.remains>75)|(debuff.radiant_spark_vulnerability.stack=1&cooldown.arcane_surge.remains<75)
  if S.ArcaneBarrage:IsCastable() and ((Target:DebuffStack(S.RadiantSparkVulnerability) == 2 and ArcaneSurge:CooldownRemains() > 75) or (Target:DebuffStack(S.RadiantSparkVulnerability) == 1 and ArcaneSurge:CooldownRemains() < 75)) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 18"; end
  end
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi aoe_spark_phase 20"; end
  end
  -- presence_of_mind
  if S.PresenceofMind:IsCastable() then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind aoe_spark_phase 22"; end
  end
  -- arcane_blast,if=debuff.radiant_spark_vulnerability.stack=2|debuff.radiant_spark_vulnerability.stack=3
  if S.ArcaneBlast:IsReady() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 2 or Target:DebuffStack(S.RadiantSparkVulnerability) == 3) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast aoe_spark_phase 24"; end
  end
  -- arcane_barrage,if=(debuff.radiant_spark_vulnerability.stack=4&buff.arcane_surge.up)|(debuff.radiant_spark_vulnerability.stack=3&buff.arcane_surge.down)
  if S.ArcaneBarrage:IsCastable() and ((Target:DebuffStack(S.RadiantSparkVulnerability) == 4 and Player:BuffUp(S.ArcaneSurgeBuff)) or (Target:DebuffStack(S.RadiantSparkVulnerability) == 3 and Player:BuffDown(S.ArcaneSurgeBuff))) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_spark_phase 26"; end
  end
end

local function AoeTouchPhase()
  -- variable,name=conserve_mana,op=set,if=debuff.touch_of_the_magi.remains>9,value=1-variable.conserve_mana
  if Target:DebuffRemains(S.TouchoftheMagiDebuff) > 9 then
    var_conserve_mana = bool(1 - num(var_conserve_mana))
  end
  -- meteor
  if S.Meteor:IsReady() then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor aoe_touch_phase 2"; end
  end
  -- arcane_barrage,if=talent.arcane_bombardment&target.health.pct<35&debuff.touch_of_the_magi.remains<=gcd.max
  if S.ArcaneBarrage:IsCastable() and (S.ArcaneBombardment:IsAvailable() and Target:HealthPercentage() < 35 and Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_touch_phase 4"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&active_enemies>=variable.aoe_target_count&cooldown.arcane_orb.remains<=execute_time
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and EnemiesCount8ySplash >= var_aoe_target_count and S.ArcaneOrb:CooldownRemains() <= Player:GCD()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_touch_phase 6"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&(talent.arcane_echo|talent.arcane_harmony),chain=1
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and (S.ArcaneEcho:IsAvailable() or S.ArcaneHarmony:IsAvailable())) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles aoe_touch_phase 8"; end
  end
  -- arcane_missiles,if=buff.clearcasting.stack>1&talent.conjure_mana_gem&cooldown.use_mana_gem.ready,chain=1
  if S.ArcaneMissiles:IsCastable() and (Player:BuffStack(S.ClearcastingBuff) > 1 and S.ConjureManaGem:IsAvailable() and I.ManaGem:CooldownUp()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles aoe_touch_phase 10"; end
  end
  -- arcane_orb,if=buff.arcane_charge.stack<2
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 2) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb aoe_touch_phase 12"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage aoe_touch_phase 14"; end
  end
  -- arcane_explosion
  if S.ArcaneExplosion:IsReady() then
    if CastAE(S.ArcaneExplosion) then return "arcane_explosion aoe_touch_phase 16"; end
  end
end

local function RopPhase()
  -- rune_of_power
  if S.RuneofPower:IsCastable() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power rop_phase 2"; end
  end
  -- arcane_blast,if=prev_gcd.1.rune_of_power
  if S.ArcaneBlast:IsReady() and (Player:PrevGCDP(1, S.RuneofPower)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rop_phase 4"; end
  end
  -- arcane_blast,if=prev_gcd.1.arcane_blast&prev_gcd.2.rune_of_power
  if S.ArcaneBlast:IsReady() and (Player:PrevGCDP(1, S.ArcaneBlast) and Player:PrevGCDP(2, S.RuneofPower)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rop_phase 6"; end
  end
  -- arcane_blast,if=prev_gcd.1.arcane_blast&prev_gcd.3.rune_of_power
  if S.ArcaneBlast:IsReady() and (Player:PrevGCDP(1, S.ArcaneBlast) and Player:PrevGCDP(3, S.RuneofPower)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rop_phase 8"; end
  end
  -- arcane_surge
  if S.ArcaneSurge:IsReady() then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge rop_phase 10"; end
  end
  -- arcane_blast,if=prev_gcd.1.arcane_blast&prev_gcd.4.rune_of_power
  if S.ArcaneBlast:IsReady() and (Player:PrevGCDP(1, S.ArcaneBlast) and Player:PrevGCDP(4, S.RuneofPower)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rop_phase 12"; end
  end
  -- nether_tempest,if=talent.arcane_echo,line_cd=15
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 15 and (S.ArcaneEcho:IsAvailable()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rop_phase 14"; end
  end
  -- meteor
  if S.Meteor:IsReady() then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor rop_phase 16"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rop_phase 18"; end
  end
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi rop_phase 20"; end
  end
end

local function Rotation()
  -- arcane_orb,if=buff.arcane_charge.stack<3&(buff.bloodlust.down|mana.pct>70|cooldown.touch_of_the_magi.remains>30)
  if S.ArcaneOrb:IsReady() and (Player:ArcaneCharges() < 3 and (Player:BloodlustDown() or Player:ManaPercentage() > 70 or S.TouchoftheMagi:CooldownRemains() > 30)) then
    if Cast(S.ArcaneOrb, nil, nil, not Target:IsInRange(40)) then return "arcane_orb rotation 2"; end
  end
  -- shifting_power,if=(!talent.evocation|cooldown.evocation.remains>12)&(!talent.arcane_surge|cooldown.arcane_surge.remains>12)&(!talent.touch_of_the_magi|cooldown.touch_of_the_magi.remains>12)&buff.arcane_surge.down&fight_remains>15
  if S.ShiftingPower:IsReady() and (((not S.Evocation:IsAvailable()) or S.Evocation:CooldownRemains() > 12) and ((not S.ArcaneSurge:IsAvailable()) or ArcaneSurge:CooldownRemains() > 12) and ((not S.TouchoftheMagi:IsAvailable()) or S.TouchoftheMagi:CooldownRemains() > 12) and Player:BuffDown(S.ArcaneSurgeBuff) and FightRemains > 15) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power rotation 4"; end
  end
  -- presence_of_mind,if=buff.arcane_charge.stack<3&target.health.pct<35&talent.arcane_bombardment
  if S.PresenceofMind:IsCastable() and (Player:ArcaneCharges() < 3 and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable()) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind rotation 6"; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up&target.health.pct<35&talent.arcane_bombardment&buff.arcane_charge.stack<3
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff) and Target:HealthPercentage() < 35 and S.ArcaneBombardment:IsAvailable() and Player:ArcaneCharges() < 3) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 8"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.clearcasting.stack=buff.clearcasting.max_stack
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) == ClearCastingMaxStack) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 10"; end
  end
  -- nether_tempest,if=(refreshable|!ticking)&buff.arcane_charge.stack=buff.arcane_charge.max_stack&(buff.temporal_warp.up|mana.pct<10|!talent.shifting_power)&buff.arcane_surge.down&fight_remains>=12
  if S.NetherTempest:IsReady() and (Target:DebuffRefreshable(S.NetherTempestDebuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax() and (Player:BuffUp(S.TemporalWarpBuff) or Player:ManaPercentage() < 10 or not S.ShiftingPower:IsAvailable()) and Player:BuffDown(S.ArcaneSurgeBuff) and FightRemains >= 12) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest rotation 12"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<50&!talent.evocation&fight_remains>20
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 50 and (not S.Evocation:IsAvailable()) and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 14"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<70&variable.conserve_mana&buff.bloodlust.up&cooldown.touch_of_the_magi.remains>5&fight_remains>20
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 70 and var_conserve_mana and Player:BloodlustUp() and S.TouchoftheMagi:CooldownRemains() > 5 and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 16"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.concentration.up&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffUp(S.ConcentrationBuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 18"; end
  end
  -- arcane_blast,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&buff.nether_precision.up
  if S.ArcaneBlast:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:BuffUp(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 20"; end
  end
  -- arcane_barrage,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack&mana.pct<60&variable.conserve_mana&(!talent.rune_of_power|cooldown.rune_of_power.remains>5)&cooldown.touch_of_the_magi.remains>10&cooldown.evocation.remains>40&fight_remains>20
  if S.ArcaneBarrage:IsCastable() and (Player:ArcaneCharges() == Player:ArcaneChargesMax() and Player:ManaPercentage() < 60 and var_conserve_mana and ((not S.RuneofPower:IsAvailable()) or S.RuneofPower:CooldownRemains() > 5) and S.TouchoftheMagi:CooldownRemains() > 10 and S.Evocation:CooldownRemains() > 40 and FightRemains > 20) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 22"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&buff.nether_precision.down
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and Player:BuffDown(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles rotation 24"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast rotation 26"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage rotation 28"; end
  end
end

local function SparkPhase()
  -- nether_tempest,if=!ticking&variable.opener&buff.bloodlust.up,line_cd=45
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 45 and (Target:DebuffDown(S.NetherTempestDebuff) and var_opener and Player:BloodlustUp()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest spark_phase 2"; end
  end
  -- rune_of_power
  if S.RuneofPower:IsCastable() then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power spark_phase 4"; end
  end
  -- arcane_blast,if=variable.opener&cooldown.arcane_surge.ready&buff.bloodlust.up&mana>=variable.opener_min_mana&buff.rune_of_power.remains>gcd.max*4
  if S.ArcaneBlast:IsReady() and (var_opener and S.ArcaneSurge:CooldownUp() and Player:BloodlustUp() and Player:Mana() >= var_opener_min_mana and Player:BuffRemains(S.RuneofPowerBuff) > GCDMax * 4) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 6"; end
  end
  -- arcane_missiles,if=variable.opener&buff.bloodlust.up&buff.clearcasting.react&buff.clearcasting.stack>=2&cooldown.radiant_spark.remains<5&buff.nether_precision.down,chain=1
  if S.ArcaneMissiles:IsCastable() and (var_opener and Player:BloodlustUp() and Player:BuffUp(S.ClearcastingBuff) and Player:BuffStack(S.ClearcastingBuff) >= 2 and S.RadiantSpark:CooldownRemains() < 5 and Player:BuffDown(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spark_phase 8"; end
  end
  -- arcane_missiles,if=talent.arcane_harmony&buff.arcane_harmony.stack<15&((variable.opener&buff.bloodlust.up)|buff.clearcasting.react&cooldown.radiant_spark.remains<5)&cooldown.arcane_surge.remains<30,chain=1
  if S.ArcaneMissiles:IsReady() and (S.ArcaneHarmony:IsAvailable() and Player:BuffStack(S.ArcaneHarmonyBuff) < 15 and ((var_opener and Player:BloodlustUp()) or Player:BuffUp(S.ClearcastingBuff) and S.RadiantSpark:CooldownRemains() < 5) and S.ArcaneSurge:CooldownRemains() < 30) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles spark_phase 10"; end
  end
  -- radiant_spark
  if S.RadiantSpark:IsReady() then
    if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsSpellInRange(S.RadiantSpark)) then return "radiant_spark spark_phase 12"; end
  end
  -- use_item,name=timebreaching_talon,if=cooldown.arcane_surge.remains<=(gcd.max*3)
  if I.TimebreachingTalon:IsEquippedAndReady() and (S.ArcaneSurge:CooldownRemains() <= GCDMax * 3) then
    if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon spark_phase 14"; end
  end
  -- invoke_external_buff,name=power_infusion,if=prev_gcd.1.radiant_spark&cooldown.arcane_surge.remains<=(gcd.max*3)
  -- Note: Not handling external buffs
  -- nether_tempest,if=(prev_gcd.4.radiant_spark&cooldown.arcane_surge.remains<=execute_time)|prev_gcd.5.radiant_spark,line_cd=15
  if S.NetherTempest:IsReady() and S.NetherTempest:TimeSinceLastCast() >= 15 and ((Player:PrevGCDP(4, S.RadiantSpark) and S.ArcaneSurge:CooldownRemains() <= S.NetherTempest:ExecuteTime()) or Player:PrevGCDP(5, S.RadiantSpark)) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest spark_phase 16"; end
  end
  -- arcane_surge,if=(!talent.nether_tempest&prev_gcd.4.radiant_spark)|prev_gcd.1.nether_tempest
  if S.ArcaneSurge:IsReady() and (((not S.NetherTempest:IsAvailable()) and Player:PrevGCDP(4, S.RadiantSpark)) or Player:PrevGCDP(1, S.NetherTempest)) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge spark_phase 18"; end
  end
  -- meteor,if=(talent.nether_tempest&prev_gcd.6.radiant_spark)|(!talent.nether_tempest&prev_gcd.5.radiant_spark)
  if S.Meteor:IsReady() and ((S.NetherTempest:IsAvailable() and Player:PrevGCDP(6, S.NetherTempest)) or ((not S.NetherTempest:IsAvailable()) and Player:PrevGCDP(5, S.RadiantSpark))) then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor spark_phase 20"; end
  end
  -- arcane_blast,if=cast_time>=gcd&execute_time<debuff.radiant_spark_vulnerability.remains&(!talent.arcane_bombardment|target.health.pct>=35)&(talent.nether_tempest&prev_gcd.6.radiant_spark|!talent.nether_tempest&prev_gcd.5.radiant_spark)&!talent.meteor
  if S.ArcaneBlast:IsReady() and (S.ArcaneBlast:CastTime() >= Player:GCD() and S.ArcaneBlast:ExecuteTime() < Target:DebuffRemains(S.RadiantSparkVulnerability) and ((not S.ArcaneBombardment:IsAvailable()) or Target:HealthPercentage() >= 35) and (S.NetherTempest:IsAvailable() and Player:PrevGCDP(6, S.RadiantSpark) or (not S.NetherTempest:IsAvailable()) and Player:PrevGCDP(5, S.RadiantSpark)) and not S.Meteor:IsAvailable()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 22"; end
  end
  -- wait,sec=0.05,if=!talent.meteor&(talent.nether_tempest&prev_gcd.6.radiant_spark)|(!talent.nether_tempest&prev_gcd.5.radiant_spark),line_cd=15
  -- arcane_barrage,if=debuff.radiant_spark_vulnerability.stack=4
  if S.ArcaneBarrage:IsCastable() and (Target:DebuffStack(S.RadiantSparkVulnerability) == 4) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spark_phase 24"; end
  end
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage&(action.arcane_barrage.in_flight_remains<=0.2|gcd.remains<=0.2)
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage) and (S.ArcaneBarrage:InFlight() and S.ArcaneBarrage:TravelTime() - S.ArcaneBarrage:TimeSinceLastCast() <= 0.2 or Player:GCDRemains() <= 0.2)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi spark_phase 26"; end
  end
  -- arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast spark_phase 28"; end
  end
  -- arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage spark_phase 30"; end
  end
end

local function StandardCooldowns()
  -- arcane_surge,if=buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneSurge:IsReady() and (Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneSurge, Settings.Arcane.GCDasOffGCD.ArcaneSurge) then return "arcane_surge standard_cooldowns 2"; end
  end
  -- nether_tempest,if=prev_gcd.1.arcane_surge&talent.arcane_echo
  if S.NetherTempest:IsReady() and (Player:PrevGCDP(1, S.ArcaneSurge) and S.ArcaneEcho:IsAvailable()) then
    if Cast(S.NetherTempest, nil, nil, not Target:IsSpellInRange(S.NetherTempest)) then return "nether_tempest standard_cooldowns 4"; end
  end
  -- meteor,if=buff.arcane_surge.up&cooldown.touch_of_the_magi.ready
  if S.Meteor:IsReady() and (Player:BuffUp(S.ArcaneSurgeBuff) and S.TouchoftheMagi:CooldownUp()) then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor standard_cooldowns 6"; end
  end
  -- arcane_barrage,if=buff.arcane_surge.up&cooldown.touch_of_the_magi.ready
  if S.ArcaneBarrage:IsCastable() and (Player:BuffUp(S.ArcaneSurgeBuff) and S.TouchoftheMagi:CooldownUp()) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage standard_cooldowns 8"; end
  end
  -- rune_of_power,if=cooldown.touch_of_the_magi.remains<=(gcd.max*2)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.RuneofPower:IsCastable() and (S.TouchoftheMagi:CooldownRemains() <= GCDMax * 2 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.RuneofPower, Settings.Arcane.GCDasOffGCD.RuneOfPower) then return "rune_of_power standard_cooldowns 10"; end
  end
  -- meteor,if=cooldown.touch_of_the_magi.remains<=(gcd.max*2)&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.Meteor:IsReady() and (S.TouchoftheMagi:CooldownRemains() <= GCDMax * 2 and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor standard_cooldowns 12"; end
  end
  -- touch_of_the_magi,use_off_gcd=1,if=prev_gcd.1.arcane_barrage
  if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
    if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi standard_cooldowns 14"; end
  end
end

local function TouchPhase()
  -- variable,name=conserve_mana,op=set,if=debuff.touch_of_the_magi.remains>9,value=1-variable.conserve_mana
  if Target:DebuffRemains(S.TouchoftheMagiDebuff) > 9 then
    var_conserve_mana = bool(1 - num(var_conserve_mana))
  end
  -- meteor
  if S.Meteor:IsReady() then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor touch_phase 2"; end
  end
  -- presence_of_mind,if=(!talent.arcane_bombardment|target.health.pct>35)&buff.arcane_surge.up&debuff.touch_of_the_magi.remains<=gcd.max
  if S.PresenceofMind:IsCastable() and (((not S.ArcaneBombardment:IsAvailable()) or Target:HealthPercentage() < 35) and Player:BuffUp(S.ArcaneSurgeBuff) and Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.PresenceofMind, Settings.Arcane.OffGCDasOffGCD.PresenceofMind) then return "presence_of_mind touch_phase 4"; end
  end
  -- arcane_blast,if=buff.presence_of_mind.up&buff.arcane_charge.stack=buff.arcane_charge.max_stack
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.PresenceofMindBuff) and Player:ArcaneCharges() == Player:ArcaneChargesMax()) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 6"; end
  end
  -- arcane_barrage,if=(buff.arcane_harmony.up|(talent.arcane_bombardment&target.health.pct<35))&debuff.touch_of_the_magi.remains<=gcd.max
  if S.ArcaneBarrage:IsCastable() and ((Player:BuffUp(S.ArcaneHarmonyBuff) or (S.ArcaneBombardment:IsAvailable() and Target:HealthPercentage() < 35)) and Target:DebuffRemains(S.TouchoftheMagiDebuff) <= GCDMax) then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage touch_phase 8"; end
  end
  -- arcane_missiles,if=buff.clearcasting.stack>1&talent.conjure_mana_gem&cooldown.use_mana_gem.ready,chain=1
  if S.ArcaneMissiles:IsCastable() and (Player:BuffStack(S.ClearcastingBuff) > 1 and S.ConjureManaGem:IsAvailable() and I.ManaGem:CooldownUp()) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles touch_phase 10"; end
  end
  -- arcane_blast,if=buff.nether_precision.up
  if S.ArcaneBlast:IsReady() and (Player:BuffUp(S.NetherPrecisionBuff)) then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 12"; end
  end
  -- arcane_missiles,if=buff.clearcasting.react&(debuff.touch_of_the_magi.remains>execute_time|!talent.presence_of_mind),chain=1
  if S.ArcaneMissiles:IsCastable() and (Player:BuffUp(S.ClearcastingBuff) and (Target:DebuffRemains(S.TouchoftheMagiDebuff) > S.ArcaneMissiles:CastTime() or not S.PresenceofMind:IsAvailable())) then
    if Cast(S.ArcaneMissiles, nil, nil, not Target:IsSpellInRange(S.ArcaneMissiles)) then return "arcane_missiles touch_phase 14"; end
  end
  --arcane_blast
  if S.ArcaneBlast:IsReady() then
    if Cast(S.ArcaneBlast, nil, nil, not Target:IsSpellInRange(S.ArcaneBlast)) then return "arcane_blast touch_phase 16"; end
  end
  --arcane_barrage
  if S.ArcaneBarrage:IsCastable() then
    if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage touch_phase 18"; end
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
    BossFightRemains = HL.BossFightRemains(nil, true)
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end
  end

  GCDMax = Player:GCD() + 0.25

  -- Set which cast function to use for ArcaneExplosion
  CastAE = (Settings.Arcane.StayDistance and not Target:IsInRange(10)) and CastLeft or Cast

  if Everyone.TargetIsValid() then
    -- arcane_intellect
    -- Note: moved outside of precombat
    if S.ArcaneIntellect:IsCastable() and (Player:BuffDown(S.ArcaneIntellect, true) or Everyone.GroupBuffMissing(S.ArcaneIntellect)) then
      if Cast(S.ArcaneIntellect, Settings.Commons.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect group_buff"; end
    end
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(40, S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- potion,if=cooldown.arcane_surge.ready
    if Settings.Commons.Enabled.Potions and (ArcaneSurge:CooldownUp()) then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 2"; end
      end
    end
    if CDsON() then
      -- time_warp,if=talent.temporal_warp&buff.exhaustion.up&(cooldown.arcane_surge.ready|fight_remains<=40|buff.arcane_surge.up&fight_remains<=80)
      if S.TimeWarp:IsReady() and (S.TemporalWarp:IsAvailable() and Player:BloodlustExhaustUp() and (ArcaneSurge:CooldownUp() or FightRemains <= 40 or ArcaneSurge:CooldownUp() and FightRemains <= 80)) then
        if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp main 4"; end
      end
      -- lights_judgment,if=buff.arcane_surge.down&buff.rune_of_power.down&debuff.touch_of_the_magi.down
      if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.ArcaneSurgeBuff) and Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff)) then
        if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment main 6"; end
      end
      -- berserking,if=(prev_gcd.1.arcane_surge&!(buff.temporal_warp.up&buff.bloodlust.up))|(buff.arcane_surge.up&debuff.touch_of_the_magi.up)
      if S.Berserking:IsCastable() and ((Player:PrevGCDP(1, S.ArcaneSurge) and (not (Player:BuffUp(S.TemporalWarpBuff) and Player:BloodlustUp()))) or Player:BuffUp(S.ArcaneSurgeBuff) and Target:DebuffUp(S.TouchoftheMagiDebuff)) then
        if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking main 8"; end
      end
      -- blood_fury,if=prev_gcd.1.arcane_surge
      if S.BloodFury:IsCastable() and (Player:PrevGCDP(1, S.ArcaneSurge)) then
        if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury main 10"; end
      end
      -- fireblood,if=prev_gcd.1.arcane_surge
      if S.Fireblood:IsCastable() and (Player:PrevGCDP(1, S.ArcaneSurge)) then
        if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood main 12"; end
      end
      -- ancestral_call,if=prev_gcd.1.arcane_surge
      if S.AncestralCall:IsCastable() and (Player:PrevGCDP(1, S.ArcaneSurge)) then
        if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call main 14"; end
      end
      -- invoke_external_buff,name=power_infusion,if=!talent.radiant_spark&prev_gcd.1.arcane_surge
      -- Note: Not handling external buffs
      if Settings.Commons.Enabled.Trinkets then
        -- use_items,if=prev_gcd.1.arcane_surge
        -- Note: Changed to checking if the buff is up. Otherwise, racials could cause trinkets to not be suggested.
        if Player:BuffUp(S.ArcaneSurgeBuff) then
          local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
          if TrinketToUse then
            if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
          end
        end
        -- use_item,name=tinker_breath_of_neltharion,if=cooldown.arcane_surge.remains&buff.rune_of_power.down&buff.arcane_surge.down&debuff.touch_of_the_magi.down
        -- TODO: Handle tinkers
        if (not var_steroid_trinket_equipped) or S.ArcaneSurge:CooldownRemains() > 20 then
          -- use_item,name=conjured_chillglobe,if=mana.pct>65&(!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20)
          if I.ConjuredChillglobe:IsEquippedAndReady() and (Player:ManaPercentage() > 65) then
            if Cast(I.ConjuredChillglobe, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "conjured_chillglobe main 18"; end
          end
          -- use_item,name=darkmoon_deck_rime,if=!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20
          if I.DMDRime:IsEquippedAndReady() then
            if Cast(I.DMDRime, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "darkmoon_deck_rime main 20"; end
          end
          if I.DMDRimeBox:IsEquippedAndReady() then
            if Cast(I.DMDRimeBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(30)) then return "darkmoon_deck_box_rime main 20"; end
          end
          -- use_item,name=darkmoon_deck_dance,if=!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20
          if I.DMDDance:IsEquippedAndReady() then
            if Cast(I.DMDDance, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(25)) then return "darkmoon_deck_dance main 22"; end
          end
          if I.DMDDanceBox:IsEquippedAndReady() then
            if Cast(I.DMDDanceBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(25)) then return "darkmoon_deck_box_dance main 22"; end
          end
          -- use_item,name=darkmoon_deck_inferno,if=!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20
          if I.DMDInferno:IsEquippedAndReady() then
            if Cast(I.DMDInferno, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "darkmoon_deck_inferno main 24"; end
          end
          if I.DMDInfernoBox:IsEquippedAndReady() then
            if Cast(I.DMDInfernoBox, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "darkmoon_deck_box_inferno main 24"; end
          end
          -- use_item,name=desperate_invokers_codex,if=!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20
          if I.DesperateInvokersCodex:IsEquippedAndReady() then
            if Cast(I.DesperateInvokersCodex, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "desperate_invokers_codex main 26"; end
          end
          -- use_item,name=iceblood_deathsnare,if=!variable.steroid_trinket_equipped|cooldown.arcane_surge.remains>20
          if I.IcebloodDeathsnare:IsEquippedAndReady() then
            if Cast(I.IcebloodDeathsnare, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "iceblood_deathsnare main 28"; end
          end
        end
      end
    end
    -- Var calculations
    local ShouldReturn = Calculations(); if ShouldReturn then return ShouldReturn; end
    -- Manually added: touch_of_the_magi,if=prev_gcd.1.arcane_barrage
    if S.TouchoftheMagi:IsReady() and (Player:PrevGCDP(1, S.ArcaneBarrage)) then
      if Cast(S.TouchoftheMagi, Settings.Arcane.GCDasOffGCD.TouchOfTheMagi) then return "touch_of_the_magi main 30"; end
    end
    -- cancel_action,if=action.evocation.channeling&mana.pct>=95&!talent.siphon_storm
    -- cancel_action,if=action.evocation.channeling&(mana.pct>fight_remains*4)&!(fight_remains>10&cooldown.arcane_surge.remains<1)
    -- TODO: see how we can manage that
    -- arcane_barrage,if=fight_remains<2
    if S.ArcaneBarrage:IsReady() and (FightRemains < 2) then
      if Cast(S.ArcaneBarrage, nil, nil, not Target:IsSpellInRange(S.ArcaneBarrage)) then return "arcane_barrage main 31"; end
    end
    -- evocation,if=buff.rune_of_power.down&buff.arcane_surge.down&debuff.touch_of_the_magi.down&((mana.pct<10&cooldown.touch_of_the_magi.remains<25)|cooldown.touch_of_the_magi.remains<20)&(mana.pct<fight_remains*4)
    -- Note: Manually added var_opener check, as we don't want to cast Evocation during the initial opener.
    if S.Evocation:IsCastable() and (not var_opener) and (Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(ArcaneSurge) and Target:DebuffDown(S.TouchoftheMagiDebuff) and ((Player:ManaPercentage() < 10 and S.TouchoftheMagi:CooldownRemains() < 25) or S.TouchoftheMagi:CooldownRemains() < 20) and (Player:ManaPercentage() < FightRemains * 4)) then
      if Cast(S.Evocation, Settings.Arcane.GCDasOffGCD.Evocation) then return "evocation main 32"; end
    end
    -- conjure_mana_gem,if=buff.rune_of_power.down&debuff.touch_of_the_magi.down&buff.arcane_surge.down&cooldown.arcane_surge.remains<fight_remains&!mana_gem_charges
    if S.ConjureManaGem:IsCastable() and (Player:BuffDown(S.RuneofPowerBuff) and Target:DebuffDown(S.TouchoftheMagiDebuff) and Player:BuffDown(S.ArcaneSurgeBuff) and ArcaneSurge:CooldownRemains() < FightRemains and I.ManaGem:Charges() == 0) then
      if Cast(S.ConjureManaGem) then return "conjure_mana_gem main 34"; end
    end
    -- use_mana_gem,if=talent.cascading_power&buff.clearcasting.stack<2&buff.arcane_surge.up
    -- TODO: Fix hotkey issue, as item and spell use the same icon
    if I.ManaGem:IsReady() and Settings.Arcane.Enabled.ManaGem and (S.CascadingPower:IsAvailable() and Player:BuffStack(S.ClearcastingBuff) < 2 and Player:BuffUp(S.ArcaneSurgeBuff)) then
      if Cast(I.ManaGem, Settings.Arcane.OffGCDasOffGCD.ManaGem) then return "mana_gem main 36"; end
    end
    -- use_mana_gem,if=!talent.cascading_power&prev_gcd.1.arcane_surge
    -- TODO: Fix hotkey issue, as item and spell use the same icon
    if I.ManaGem:IsReady() and Settings.Arcane.Enabled.ManaGem and ((not S.CascadingPower:IsAvailable()) and Player:PrevGCDP(1, S.ArcaneSurge)) then
      if Cast(I.ManaGem, Settings.Arcane.OffGCDasOffGCD.ManaGem) then return "mana_gem main 38"; end
    end
    -- call_action_list,name=aoe_spark_phase,if=talent.radiant_spark&variable.aoe_spark_phase
    if CDsON() and S.RadiantSpark:IsAvailable() and var_aoe_spark_phase then
      local ShouldReturn = AoeSparkPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=spark_phase,if=talent.radiant_spark&variable.spark_phase
    if CDsON() and S.RadiantSpark:IsAvailable() and var_spark_phase then
      local ShouldReturn = SparkPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe_touch_phase,if=debuff.touch_of_the_magi.up&active_enemies>=variable.aoe_target_count
    if CDsON() and Target:DebuffUp(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash >= var_aoe_target_count then
      local ShouldReturn = AoeTouchPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=touch_phase,if=debuff.touch_of_the_magi.up&active_enemies<variable.aoe_target_count
    if CDsON() and Target:DebuffUp(S.TouchoftheMagiDebuff) and EnemiesCount8ySplash < var_aoe_target_count then
      local ShouldReturn = TouchPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=rop_phase,if=variable.rop_phase
    if CDsON() and var_rop_phase then
      local ShouldReturn = RopPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=standard_cooldowns,if=!talent.radiant_spark&(!talent.rune_of_power|active_enemies>=variable.aoe_target_count)
    if CDsON() and (not S.RadiantSpark:IsAvailable()) and ((not S.RuneofPower:IsAvailable()) or EnemiesCount8ySplash >= var_aoe_target_count) then
      local ShouldReturn = StandardCooldowns(); if ShouldReturn then return ShouldReturn; end
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
  HR.Print("Arcane Mage rotation is currently a work in progress, but has been updated for patch 10.0.")
end

HR.SetAPL(62, APL, Init)
