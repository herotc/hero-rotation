--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CastLeft   = HR.CastLeft
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
local FBCast
-- lua
local max        = math.max
local ceil       = math.ceil
-- Commons
local Mage       = HR.Commons.Mage

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Fire;
local I = Item.Mage.Fire;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.DreadfireVessel:ID(),
  I.EmpyrealOrdnance:ID(),
  I.FlameofBattle:ID(),
  I.GlyphofAssimilation:ID(),
  I.InscrutableQuantumDevice:ID(),
  I.InstructorsDivineBell:ID(),
  I.MacabreSheetMusic:ID(),
  I.SinfulAspirantsBadge:ID(),
  I.SinfulGladiatorsBadge:ID(),
  I.SoulIgniter:ID(),
  I.SunbloodAmethyst:ID(),
  I.WakenersFrond:ID()
}

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local EnemiesCount;

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
};

-- Variables
local var_init
local var_searing_touch_active
local var_disable_combustion
local var_firestarter_combustion = -1
local var_hot_streak_flamestrike
local var_hard_cast_flamestrike
local var_combustion_flamestrike
local var_arcane_explosion
local var_arcane_explosion_mana
local var_kindling_reduction
local var_skb_duration
local var_combustion_on_use
local var_empyreal_ordnance_delay
local var_on_use_cutoff
local var_combustion_shifting_power
local var_combustion_cast_remains
local var_overpool_fire_blasts
local var_combustion_ready_time
local var_combustion_precast_time
local var_combustion_time
local var_time_to_combustion
local var_shifting_power_before_combustion
local var_use_off_gcd
local var_use_while_casting
local var_phoenix_pooling
local var_fire_blast_pooling = false
local var_extended_combustion_remains
local var_needed_fire_blasts
local var_expected_fire_blasts
local var_sun_kings_blessing_max_stack = 12

local fightRemains
local var_disciplinary_command_cd_remains
local var_disciplinary_command_last_applied

local EnemiesCount8ySplash,EnemiesCount10ySplash,EnemiesCount16ySplash
local EnemiesCount10yMelee,EnemiesCount18yMelee
local Enemies8ySplash
local UnitsWithIgniteCount

local ExpandedPotentialEquipped = Player:HasLegendaryEquipped(6)
local DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
local GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
local TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
local FeveredIncantationEquipped = Player:HasLegendaryEquipped(10)
local FirestormEquipped = Player:HasLegendaryEquipped(11)
local MoltenSkyfallEquipped = Player:HasLegendaryEquipped(12)
local SunKingsBlessingEquipped = Player:HasLegendaryEquipped(13)

HL:RegisterForEvent(function()
  ExpandedPotentialEquipped = Player:HasLegendaryEquipped(6)
  DisciplinaryCommandEquipped = Player:HasLegendaryEquipped(7)
  GrislyIcicleEquipped = Player:HasLegendaryEquipped(8)
  TemporalWarpEquipped = Player:HasLegendaryEquipped(9)
  FeveredIncantationEquipped = Player:HasLegendaryEquipped(10)
  FirestormEquipped = Player:HasLegendaryEquipped(11)
  MoltenSkyfallEquipped = Player:HasLegendaryEquipped(12)
  SunKingsBlessingEquipped = Player:HasLegendaryEquipped(13)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Pyroblast:RegisterInFlight();
  S.Fireball:RegisterInFlight();
  S.Meteor:RegisterInFlight();
  S.PhoenixFlames:RegisterInFlight();
  S.Pyroblast:RegisterInFlight(S.CombustionBuff);
  S.Fireball:RegisterInFlight(S.CombustionBuff);
end, "LEARNED_SPELL_IN_TAB")
S.Pyroblast:RegisterInFlight()
S.Fireball:RegisterInFlight()
S.Meteor:RegisterInFlight()
S.PhoenixFlames:RegisterInFlight()
S.Pyroblast:RegisterInFlight(S.CombustionBuff)
S.Fireball:RegisterInFlight(S.CombustionBuff)

HL:RegisterForEvent(function()
  var_init = false
  var_firestarter_combustion = -1
end, "PLAYER_REGEN_ENABLED")

function S.Firestarter:ActiveStatus()
    return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90)) and 1 or 0
end

function S.Firestarter:ActiveRemains()
    return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90) or 0) or 0
end

function S.ShiftingPower:TickReduction()
  --TODO : add Discipline of the grove
  return 2.5
end

function S.ShiftingPower:FullReduction()
  return S.ShiftingPower:TickReduction() * S.ShiftingPower:BaseDuration() / S.ShiftingPower:BaseTickTime()
end

local function UnitsWithIgnite(enemies)
  local WithIgnite = 0
  for k in pairs(enemies) do
    local CycleUnit = enemies[k]
    if CycleUnit:DebuffUp(S.Ignite) then
      WithIgnite = WithIgnite + 1
    end
  end
  return WithIgnite
end

local function num(val)
  if val then return 1 else return 0 end
end

local function bool(val)
  return val ~= 0
end

local function VarInit()
  -- variable,name=firestarter_combustion,default=-1,value=1*!talent.pyroclasm,if=variable.firestarter_combustion<0
  if var_firestarter_combustion < 0 then
    var_firestarter_combustion = 1 * num(S.Pyroclasm:IsAvailable())
  end

  -- variable,name=hot_streak_flamestrike,if=variable.hot_streak_flamestrike=0,value=2*talent.flame_patch+3*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_hot_streak_flamestrike = 2
  else
    var_hot_streak_flamestrike = 3
  end

  -- variable,name=hard_cast_flamestrike,if=variable.hard_cast_flamestrike=0,value=2*talent.flame_patch+3*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_hard_cast_flamestrike = 2
  else
    var_hard_cast_flamestrike = 3
  end

  -- variable,name=combustion_flamestrike,if=variable.combustion_flamestrike=0,value=3*talent.flame_patch+6*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_combustion_flamestrike = 3
  else
    var_combustion_flamestrike = 6
  end

  -- variable,name=arcane_explosion,if=variable.arcane_explosion=0,value=99*talent.flame_patch+2*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_arcane_explosion = 99
  else
    var_arcane_explosion = 2
  end

  -- variable,name=arcane_explosion_mana,default=40,op=reset
  var_arcane_explosion_mana = 40

  -- variable,name=combustion_shifting_power,default=2,op=reset
  var_combustion_shifting_power = 2

  -- variable,name=combustion_cast_remains,default=0.7,op=reset
  var_combustion_cast_remains = 0.7

  -- variable,name=overpool_fire_blasts,default=0,op=reset
  var_overpool_fire_blasts = 0

  -- variable,name=empyreal_ordnance_delay,default=18,op=reset
  var_empyreal_ordnance_delay = 18

  -- variable,name=time_to_combustion,value=fight_remains+100,if=variable.disable_combustion
  if var_disable_combustion then
    var_time_to_combustion = 99999
  end

  -- variable,name=skb_duration,op=set,value=dbc.effect.828420.base_value
  var_skb_duration = 6

  -- variable,name=combustion_on_use,op=set,value=equipped.gladiators_badge|equipped.macabre_sheet_music|equipped.inscrutable_quantum_device|equipped.sunblood_amethyst|equipped.empyreal_ordnance|equipped.flame_of_battle|equipped.wakeners_frond|equipped.instructors_divine_bell
  var_combustion_on_use = (I.SinfulGladiatorsBadge:IsEquipped() or I.SinfulAspirantsBadge:IsEquipped() or I.MacabreSheetMusic:IsEquipped() or I.InscrutableQuantumDevice:IsEquipped() or I.SunbloodAmethyst:IsEquipped() or I.EmpyrealOrdnance:IsEquipped() or I.FlameofBattle:IsEquipped() or I.WakenersFrond:IsEquipped() or I.InstructorsDivineBell:IsEquipped())

  -- Manually added: variable,name=on_use_cutoff,value=0
  var_on_use_cutoff = 0

  -- variable,name=on_use_cutoff,value=20,if=variable.combustion_on_use
  if var_combustion_on_use then
    var_on_use_cutoff = 20
  end

  -- variable,name=on_use_cutoff,value=25,if=equipped.macabre_sheet_music
  if I.MacabreSheetMusic:IsEquipped() then
    var_on_use_cutoff = 25
  end

  --variable,name=on_use_cutoff,value=20+variable.empyreal_ordnance_delay,if=equipped.empyreal_ordnance
  if I.EmpyrealOrdnance:IsEquipped() then
    var_on_use_cutoff = 20 + var_empyreal_ordnance_delay
  end

  --variable,name=kindling_reduction,default=0.4,op=reset
  var_kindling_reduction = 0.4

  var_init = true
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellectBuff, true) then
    if Cast(S.ArcaneIntellect) then return "arcane_intellect"; end
  end
  if Everyone.TargetIsValid() then
    -- Initialize variables
    if not var_init then
      VarInit()
    end
    -- snapshot_stats
    -- use_item,name=soul_igniter
    if I.SoulIgniter:IsEquippedAndReady() then
      if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter precombat"; end
    end
    -- mirror_image
    if S.MirrorImage:IsCastable() and CDsON() and Settings.Fire.MirrorImagesBeforePull then
      if Cast(S.MirrorImage, Settings.Fire.GCDasOffGCD.MirrorImage) then return "mirror_image precombat"; end
    end
    -- pyroblast
    if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) then
      if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast precombat"; end
    end
    -- Manually added: fireball
    if S.Fireball:IsReady() then
      if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball precombat"; end
    end
  end
end

local function CombustionTiming()
  -- variable,name=combustion_ready_time,value=cooldown.combustion.remains*expected_kindling_reduction
  var_combustion_ready_time = S.Combustion:CooldownRemains() * var_kindling_reduction
  -- variable,name=combustion_precast_time,value=(action.fireball.cast_time*!conduit.flame_accretion+action.scorch.cast_time+conduit.flame_accretion)*(active_enemies<variable.combustion_flamestrike)+action.flamestrike.cast_time*(active_enemies>=variable.combustion_flamestrike)-variable.combustion_cast_remains
  var_combustion_precast_time = (S.Fireball:CastTime() * num(not S.FlameAccretion:ConduitEnabled()) + S.Scorch:CastTime() + num(S.FlameAccretion:ConduitEnabled())) * num(EnemiesCount8ySplash < var_combustion_flamestrike) + S.Flamestrike:CastTime() * num(EnemiesCount8ySplash >= var_combustion_flamestrike) - var_combustion_cast_remains
  -- variable,name=combustion_time,value=variable.combustion_ready_time
  var_combustion_time = var_combustion_ready_time
  -- variable,name=combustion_time,op=max,value=firestarter.remains,if=talent.firestarter&!variable.firestarter_combustion
  if S.Firestarter:IsAvailable() and not var_firestarter_combustion then
    var_combustion_time = max(S.Firestarter:ActiveRemains(), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=cooldown.radiant_spark.remains,if=covenant.kyrian&cooldown.radiant_spark.remains-10<variable.combustion_time
  if Player:Covenant() == "Kyrian" and S.RadiantSpark:CooldownRemains() - 10 < var_combustion_time then
    var_combustion_time = max(S.RadiantSpark:CooldownRemains(), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=cooldown.deathborne.remains,if=covenant.necrolord&cooldown.deathborne.remains-10<variable.combustion_time
  if Player:Covenant() == "Necrolord" and S.Deathborne:CooldownRemains() - 10 < var_combustion_time then
    var_combustion_time = max(S.Deathborne:CooldownRemains(), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=variable.empyreal_ordnance_delay-(cooldown.empyreal_ordnance.duration-cooldown.empyreal_ordnance.remains)*!cooldown.empyreal_ordnance.ready,if=equipped.empyreal_ordnance
  if I.EmpyrealOrdnance:IsEquipped() then
    var_combustion_time = max(var_empyreal_ordnance_delay - (180 - I.EmpyrealOrdnance:CooldownRemains()) * num(not I.EmpyrealOrdnance:CooldownUp()), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=cooldown.gladiators_badge_345228.remains,if=equipped.gladiators_badge&cooldown.gladiators_badge_345228.remains-20<variable.combustion_time
  if I.SinfulAspirantsBadge:IsEquipped() and I.SinfulAspirantsBadge:CooldownRemains() - 20 < var_combustion_time then
    var_combustion_time = max(I.SinfulAspirantsBadge:CooldownRemains(), var_combustion_time)
  end
  if I.SinfulGladiatorsBadge:IsEquipped() and I.SinfulGladiatorsBadge:CooldownRemains() - 20 < var_combustion_time then
    var_combustion_time = max(I.SinfulGladiatorsBadge:CooldownRemains(), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=buff.rune_of_power.remains,if=talent.rune_of_power&buff.combustion.down
  if S.RuneofPower:IsAvailable() and Player:BuffDown(S.CombustionBuff) then
    var_combustion_time = max(Player:BuffRemains(S.RuneofPowerBuff), var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=cooldown.rune_of_power.remains+buff.rune_of_power.duration,if=talent.rune_of_power&buff.combustion.down&cooldown.rune_of_power.remains+5<variable.combustion_time
  if S.RuneofPower:IsAvailable() and Player:BuffDown(S.CombustionBuff) and S.RuneofPower:CooldownRemains() + 5 < var_combustion_time then
    var_combustion_time = max(S.RuneofPower:CooldownRemains() + 12, var_combustion_time)
  end
  -- variable,name=combustion_time,op=max,value=cooldown.buff_disciplinary_command.remains,if=runeforge.disciplinary_command&buff.disciplinary_command.down
  if DisciplinaryCommandEquipped and Player:BuffDown(S.DisciplinaryCommandBuff) then
    var_combustion_time = max(S.DisciplinaryCommandBuff:CooldownRemains(), var_combustion_time)
    -- TODO: Verify S.DisciplinaryCommandBuff:CooldownRemains() works as expected_fire_blasts
  end
  -- variable,name=combustion_time,op=max,value=raid_event.adds.in,if=raid_event.adds.exists&raid_event.adds.count>=3&raid_event.adds.duration>15
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,name=combustion_time,value=raid_event.vulnerable.in*!raid_event.vulnerable.up,if=raid_event.vulnerable.exists&variable.combustion_ready_time<raid_event.vulnerable.in
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,name=combustion_time,value=variable.combustion_ready_time,if=variable.combustion_ready_time+cooldown.combustion.duration*(1-(0.6+0.2*talent.firestarter)*talent.kindling)<=variable.combustion_time|variable.combustion_time>fight_remains-20
  if var_combustion_ready_time + 120 * (1 - (0.6 + 0.2 * num(S.Firestarter:IsAvailable())) * num(S.Kindling:IsAvailable())) <= var_combustion_time or var_combustion_time > fightRemains - 20 then
    var_combustion_time = var_combustion_ready_time
  end
  -- variable,name=combustion_time,op=add,value=time
  var_combustion_time = var_combustion_time + HL.CombatTime()
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=(variable.combustion_time-time)*buff.combustion.down
  if not var_disable_combustion then
    var_time_to_combustion = (var_combustion_time - HL.CombatTime()) * num(Player:BuffDown(S.CombustionBuff))
  end
end

local function ActiveTalents()
  -- living_bomb,if=active_enemies>1&buff.combustion.down&(variable.time_to_combustion>cooldown.living_bomb.duration|variable.time_to_combustion<=0)
  if S.LivingBomb:IsReady() and (EnemiesCount10ySplash > 1 and Player:BuffDown(S.CombustionBuff) and (var_time_to_combustion > S.LivingBomb:CooldownRemains() or var_time_to_combustion <= 0)) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsInRange(S.LivingBomb)) then return "living_bomb active_talents 1"; end
  end
  -- meteor,if=variable.time_to_combustion<=0|(cooldown.meteor.duration<variable.time_to_combustion&!talent.rune_of_power)|talent.rune_of_power&buff.rune_of_power.up&variable.time_to_combustion>action.meteor.cooldown|fight_remains<variable.time_to_combustion
  if S.Meteor:IsReady() and (var_time_to_combustion <= 0 or (45 < var_time_to_combustion and not S.RuneofPower:IsAvailable()) or S.RuneofPower:IsAvailable() and Player:BuffUp(S.RuneofPowerBuff) and var_time_to_combustion > 45 or fightRemains < var_time_to_combustion) then
    if Cast(S.Meteor, nil, nil, not Target:IsInRange(40)) then return "meteor active_talents 2"; end
  end
  -- dragons_breath,if=talent.alexstraszas_fury&(buff.combustion.down&!buff.hot_streak.react)
  if S.DragonsBreath:IsReady() and (S.AlexstraszasFury:IsAvailable() and (Player:BuffDown(S.CombustionBuff) and Player:BuffDown(S.HotStreakBuff))) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath active_talents 3 left"; end
    else
      if Cast(S.DragonsBreath) then return "dragons_breath active_talents 3"; end
    end
  end
end

local function CombustionCooldowns()
  -- potion
  if I.PotionofSpectralIntellect:IsReady() and Settings.Commons.Enabled.UsePotions then
    if Cast(I.PotionofSpectralIntellect, nil, Settings.Commons.DisplayStyle.Potions) then return "potion combustion_cooldowns 1"; end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury combustion_cooldowns 2"; end
  end
  -- berserking,if=buff.combustion.up
  if S.Berserking:IsCastable() and (Player:BuffUp(S.CombustionBuff)) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking combustion_cooldowns 3"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood combustion_cooldowns 4"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call combustion_cooldowns 5"; end
  end
  -- time_warp,if=runeforge.temporal_warp&buff.exhaustion.up
  if S.TimeWarp:IsReady() and Settings.Fire.UseTemporalWarp and (TemporalWarpEquipped and Player:BloodlustExhaustUp()) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp combustion_cooldowns 6"; end
  end
  -- use_item,effect_name=gladiators_badge
  if I.SinfulAspirantsBadge:IsEquippedAndReady() then
    if Cast(I.SinfulAspirantsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge aspirant combustion_cooldowns 7"; end
  end
  if I.SinfulGladiatorsBadge:IsEquippedAndReady() then
    if Cast(I.SinfulGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge gladiator combustion_cooldowns 8"; end
  end
  -- use_item,name=inscrutable_quantum_device
  if I.InscrutableQuantumDevice:IsEquippedAndReady() then
    if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device combustion_cooldowns 9"; end
  end
  -- use_item,name=flame_of_battle
  if I.FlameofBattle:IsEquippedAndReady() then
    if Cast(I.FlameofBattle, nil, Settings.Commons.DisplayStyle.Trinkets) then return "flame_of_battle combustion_cooldowns 10"; end
  end
  -- use_item,name=wakeners_frond
  if I.WakenersFrond:IsEquippedAndReady() then
    if Cast(I.WakenersFrond, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wakeners_frond combustion_cooldowns 11"; end
  end
  -- use_item,name=instructors_divine_bell
  if I.InstructorsDivineBell:IsEquippedAndReady() then
    if Cast(I.InstructorsDivineBell, nil, Settings.Commons.DisplayStyle.Trinkets) then return "instructors_divine_bell combustion_cooldowns 12"; end
  end
  -- use_item,name=sunblood_amethyst
  if I.SunbloodAmethyst:IsEquippedAndReady() then
    if Cast(I.SunbloodAmethyst, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sunblood_amethyst combustion_cooldowns 13"; end
  end
end

local function CombustionPhase()
  -- lights_judgment,if=buff.combustion.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.CombustionBuff) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment combustion_phase 1"; end
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=extended_combustion_remains,value=buff.combustion.remains+buff.combustion.duration*(cooldown.combustion.remains<buff.combustion.remains),if=conduit.infernal_cascade
  if S.InfernalCascade:ConduitEnabled() then
    var_extended_combustion_remains = Player:BuffRemains(S.CombustionBuff) + S.Combustion:BaseDuration() * num(S.Combustion:CooldownRemains() < Player:BuffRemains(S.Combustion))
  else
    var_extended_combustion_remains = 0
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=extended_combustion_remains,op=add,value=variable.skb_duration,if=conduit.infernal_cascade&(buff.sun_kings_blessing_ready.up|variable.extended_combustion_remains>1.5*gcd.max*(buff.sun_kings_blessing.max_stack-buff.sun_kings_blessing.stack))
  if S.InfernalCascade:ConduitEnabled() and SunKingsBlessingEquipped and (Player:BuffUp(S.SunKingsBlessingBuff) or var_extended_combustion_remains > 1.5 * Player:GCD() * (var_sun_kings_blessing_max_stack - Player:BuffStack(S.SunKingsBlessingBuff))) then
    var_extended_combustion_remains = var_extended_combustion_remains + var_skb_duration
  else
    var_extended_combustion_remains = 0
  end
  -- bag_of_tricks,if=buff.combustion.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.Combustion) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks combustion_phase 4"; end
  end
  -- living_bomb,if=active_enemies>1&buff.combustion.down
  if S.LivingBomb:IsReady() and AoEON() and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Combustion) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 5"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!conduit.infernal_cascade&charges>=1&buff.combustion.up&!buff.firestorm.react&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react<2
  if S.FireBlast:IsReady() and (not S.InfernalCascade:ConduitEnabled() and S.FireBlast:Charges() >= 1 and Player:BuffUp(S.CombustionBuff) and Player:BuffDown(S.FirestormBuff) and Player:BuffDown(S.HotStreakBuff) and num(S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()) + num(Player:BuffUp(S.HeatingUpBuff)) < 2) then
    if FBCast(S.FireBlast) then return "fire_blast combustion_phase 6"; end
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=expected_fire_blasts,value=action.fire_blast.charges_fractional+(variable.extended_combustion_remains-buff.infernal_cascade.duration)%cooldown.fire_blast.duration,if=conduit.infernal_cascade
  -- variable,use_off_gcd=1,use_while_casting=1,name=needed_fire_blasts,value=ceil(variable.extended_combustion_remains%(buff.infernal_cascade.duration-gcd.max)),if=conduit.infernal_cascade
  if S.InfernalCascade:ConduitEnabled() then
    var_expected_fire_blasts = S.FireBlast:ChargesFractional() + (var_extended_combustion_remains - S.InfernalCascadeBuff:BaseDuration()) % S.FireBlast:Cooldown()
    var_needed_fire_blasts = ceil(var_extended_combustion_remains % (S.InfernalCascadeBuff:BaseDuration() - Player:GCD()))
  else
    var_expected_fire_blasts = 0
    var_needed_fire_blasts = 0
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=conduit.infernal_cascade&charges>=1&(variable.expected_fire_blasts>=variable.needed_fire_blasts|variable.extended_combustion_remains<=buff.infernal_cascade.duration|buff.infernal_cascade.stack<2|buff.infernal_cascade.remains<gcd.max|cooldown.shifting_power.ready&active_enemies>=variable.combustion_shifting_power&covenant.night_fae)&buff.combustion.up&(!buff.firestorm.react|buff.infernal_cascade.remains<0.5)&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react<2
  if S.FireBlast:IsReady() and (S.InfernalCascade:ConduitEnabled() and S.FireBlast:Charges() >= 1 and (var_expected_fire_blasts >= var_needed_fire_blasts or var_extended_combustion_remains <= S.InfernalCascadeBuff:BaseDuration() or Player:BuffStack(S.InfernalCascadeBuff) < 2 or Player:BuffRemains(S.InfernalCascadeBuff) < Player:GCD() + 0.5 or S.ShiftingPower:CooldownUp() and EnemiesCount18yMelee >= var_combustion_shifting_power and Player:Covenant() == "Night Fae") and Player:BuffUp(S.CombustionBuff) and (Player:BuffDown(S.FirestormBuff) or Player:BuffRemains(S.InfernalCascadeBuff) < 0.5) and Player:BuffDown(S.HotStreakBuff) and num(S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()) + num(Player:BuffUp(S.HeatingUpBuff)) < 2) then
    if FBCast(S.FireBlast) then return "fire_blast combustion_phase 9"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=buff.combustion.down&variable.time_to_combustion<=0&(!runeforge.disciplinary_command|buff.disciplinary_command.up|buff.disciplinary_command_frost.up&talent.rune_of_power&cooldown.buff_disciplinary_command.ready)&(!runeforge.grisly_icicle|debuff.grisly_icicle.up)&(!covenant.necrolord|cooldown.deathborne.remains|buff.deathborne.up)&(action.meteor.in_flight&action.meteor.in_flight_remains<=variable.combustion_cast_remains|action.scorch.executing&action.scorch.execute_remains<variable.combustion_cast_remains|action.fireball.executing&action.fireball.execute_remains<variable.combustion_cast_remains|action.pyroblast.executing&action.pyroblast.execute_remains<variable.combustion_cast_remains|action.flamestrike.executing&action.flamestrike.execute_remains<variable.combustion_cast_remains)
  if S.Combustion:IsReady() and (Player:BuffDown(S.CombustionBuff) and var_time_to_combustion <= 0 and (not DisciplinaryCommandEquipped or Player:BuffUp(S.DisciplinaryCommandBuff) or Mage.DC.Frost == 1 and S.RuneofPower:IsAvailable() and var_disciplinary_command_cd_remains <= 0) and (not GrislyIcicleEquipped or Target:DebuffUp(S.GrislyIcicleDebuff)) and (Player:Covenant() ~= "Necrolord" or not S.Deathborne:CooldownUp() or Player:BuffUp(S.DeathborneBuff)) and (S.Meteor:InFlight() or Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Fireball) and S.Fireball:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Pyroblast) and S.Pyroblast:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Flamestrike) and S.Flamestrike:ExecuteRemains() < var_combustion_cast_remains)) then
    if Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion combustion_phase 15"; end
  end
  -- call_action_list,name=combustion_cooldowns,if=buff.combustion.remains>8|cooldown.combustion.remains<5
  if CDsON() and (Player:BuffRemains(S.CombustionBuff) > 8 or S.Combustion:CooldownRemains() < 5) then
    local ShouldReturn = CombustionCooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  -- flamestrike,if=(buff.hot_streak.react&active_enemies>=variable.combustion_flamestrike)|(buff.firestorm.react&active_enemies>=variable.combustion_flamestrike-runeforge.firestorm)
  if S.Flamestrike:IsReady() and AoEON() and ((Player:BuffUp(S.HotStreakBuff) and EnemiesCount8ySplash >= var_combustion_flamestrike) or (Player:BuffUp(S.FirestormBuff) and EnemiesCount8ySplash >= var_combustion_flamestrike - num(FirestormEquipped))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 16"; end
  end
  -- pyroblast,if=buff.sun_kings_blessing_ready.up&buff.sun_kings_blessing_ready.remains>cast_time
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.SunKingsBlessingBuff) and Player:BuffRemains(S.SunKingsBlessingBuff) > S.Pyroblast:CastTime()) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 18"; end
  end
  -- pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.FirestormBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 19"; end
  end
  -- pyroblast,if=buff.pyroclasm.react&buff.pyroclasm.remains>cast_time&(buff.combustion.remains>cast_time|buff.combustion.down)&active_enemies<variable.combustion_flamestrike
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.PyroclasmBuff) and Player:BuffRemains(S.PyroclasmBuff) > S.Pyroblast:CastTime() and (Player:BuffRemains(S.CombustionBuff) > S.Pyroblast:CastTime() or Player:BuffDown(S.CombustionBuff)) and EnemiesCount8ySplash < var_combustion_flamestrike) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 20"; end
  end
  -- pyroblast,if=buff.hot_streak.react&buff.combustion.up
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and Player:BuffUp(S.CombustionBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 21"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies<variable.combustion_flamestrike&buff.combustion.up
  if S.Pyroblast:IsReady() and ((Player:IsCasting(S.Scorch) or Player:PrevGCD(1, S.Scorch)) and Player:BuffUp(S.HeatingUpBuff) and EnemiesCount8ySplash < var_combustion_flamestrike and Player:BuffUp(S.CombustionBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 22"; end
  end
  -- shifting_power,if=buff.combustion.up&!action.fire_blast.charges&active_enemies>=variable.combustion_shifting_power&action.phoenix_flames.full_recharge_time>full_reduction,interrupt_if=action.fire_blast.charges=action.fire_blast.max_charges
  --TODO : interrupt_if
  if S.ShiftingPower:IsReady() and AoEON() and (Player:BuffUp(S.CombustionBuff) and S.FireBlast:Charges() == 0 and EnemiesCount18yMelee >= var_combustion_shifting_power and S.PhoenixFlames:FullRechargeTime() > S.ShiftingPower:FullReduction()) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power combustion_phase 23"; end
  end
  -- phoenix_flames,if=buff.combustion.up&travel_time<buff.combustion.remains&((action.fire_blast.charges<1&talent.pyroclasm&active_enemies=1)|!talent.pyroclasm|active_enemies>1)&buff.heating_up.react+hot_streak_spells_in_flight<2
  if S.PhoenixFlames:IsCastable() and (Player:BuffUp(S.CombustionBuff) and S.PhoenixFlames:TravelTime() < Player:BuffRemains(S.CombustionBuff) and ((S.FireBlast:Charges() < 1 and S.Pyroclasm:IsAvailable() and EnemiesCount8ySplash == 1) or not S.Pyroclasm:IsAvailable() or EnemiesCount8ySplash > 1) and num(S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()) + num(Player:BuffUp(S.HeatingUpBuff)) < 2) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 24"; end
  end
  -- flamestrike,if=buff.combustion.down&cooldown.combustion.remains<cast_time&active_enemies>=variable.combustion_flamestrike
  if S.Flamestrike:IsReady() and AoEON() and (Player:BuffDown(S.CombustionBuff) and S.Combustion:CooldownRemains() < S.Flamestrike:CastTime() and EnemiesCount8ySplash >= var_combustion_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 25"; end
  end
  -- Manually added: scorch,if=target.health.pct<=30&talent.searing_touch
  if S.Scorch:IsReady() and (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 26"; end
  end
  -- fireball,if=buff.combustion.down&cooldown.combustion.remains<cast_time&!conduit.flame_accretion
  if S.Fireball:IsReady() and (Player:BuffDown(S.CombustionBuff) and S.Combustion:CooldownRemains() < S.Fireball:CastTime() and not S.FlameAccretion:ConduitEnabled()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 27"; end
  end
  -- scorch,if=buff.combustion.remains>cast_time&buff.combustion.up|buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Scorch:IsReady() and (Player:BuffRemains(S.CombustionBuff) > S.Scorch:CastTime() and Player:BuffUp(S.CombustionBuff) or (Player:BuffDown(S.CombustionBuff) and S.Combustion:CooldownRemains() < S.Scorch:CastTime())) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 28"; end
  end
  --living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
  if S.LivingBomb:IsReady() and AoEON() and (Player:BuffRemains(S.CombustionBuff) < Player:GCD() + 0.5 and EnemiesCount10ySplash > 1) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 29"; end
  end
  --dragons_breath,if=buff.combustion.remains<gcd.max&buff.combustion.up
  if S.DragonsBreath:IsReady() and (Player:BuffRemains(S.CombustionBuff) < Player:GCD() + 0.5 and Player:BuffUp(S.CombustionBuff)) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath combustion_phase 30 left"; end
    else
      if Cast(S.DragonsBreath) then return "dragons_breath combustion_phase 30"; end
    end
  end
end

local function RoPPhase()
  -- flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.firestorm.react)
  if S.Flamestrike:IsReady() and AoEON() and (EnemiesCount8ySplash >= var_hot_streak_flamestrike and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.FirestormBuff))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike rop_phase 1"; end
  end
  -- pyroblast,if=buff.sun_kings_blessing_ready.up&buff.sun_kings_blessing_ready.remains>cast_time
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.SunKingsBlessingBuff) and Player:BuffRemains(S.SunKingsBlessingBuff) > S.Pyroblast:CastTime()) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 2"; end
  end
  -- pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.FirestormBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 3"; end
  end
  -- pyroblast,if=buff.hot_streak.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 4"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&buff.sun_kings_blessing_ready.down&active_enemies<variable.hard_cast_flamestrike&!firestarter.active&(!buff.heating_up.react&!buff.hot_streak.react&!prev_off_gcd.fire_blast&(action.fire_blast.charges>=2|(talent.alexstraszas_fury&cooldown.dragons_breath.ready)|searing_touch.active))
  if S.FireBlast:IsReady() and (not var_fire_blast_pooling and Player:BuffDown(S.SunKingsBlessingBuff) and EnemiesCount8ySplash < var_hard_cast_flamestrike and not bool(S.Firestarter:ActiveStatus()) and (Player:BuffDown(S.HeatingUpBuff) and Player:BuffDown(S.HotStreakBuff) and not Player:PrevOffGCDP(1,S.FireBlast) and (S.FireBlast:Charges() >= 2 or (S.AlexstraszasFury:IsAvailable() and S.DragonsBreath:CooldownUp()) or var_searing_touch_active))) then
    if FBCast(S.FireBlast) then return "fire_blast rop_phase 5"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&!firestarter.active&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!runeforge.firestorm)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5|!runeforge.firestorm))&buff.heating_up.react)|(searing_touch.active&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  if S.FireBlast:IsReady() and (not var_fire_blast_pooling and not bool(S.Firestarter:ActiveStatus()) and (((Player:IsCasting(S.Fireball) and (S.Fireball:ExecuteRemains() < 0.5 or not FirestormEquipped) or Player:IsCasting(S.Pyroblast) and (S.Pyroblast:ExecuteRemains() < 0.5 or not FirestormEquipped)) and Player:BuffUp(S.HeatingUpBuff)) or (var_searing_touch_active and (Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not (S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()))))) then
    if FBCast(S.FireBlast) then return "fire_blast rop_phase 6"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains&cast_time<buff.rune_of_power.remains
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.RuneofPowerBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 8"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&searing_touch.active&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsReady() and ((Player:IsCasting(S.Scorch) or Player:PrevGCD(1, S.Scorch)) and Player:BuffUp(S.HeatingUpBuff) and var_searing_touch_active and EnemiesCount8ySplash < var_hot_streak_flamestrike) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 9"; end
  end
  -- phoenix_flames,if=!variable.phoenix_pooling&buff.heating_up.react&!buff.hot_streak.react&(active_dot.ignite<2|active_enemies>=variable.hard_cast_flamestrike|active_enemies>=variable.hot_streak_flamestrike)
  if S.PhoenixFlames:IsCastable() and (not var_phoenix_pooling and Player:BuffUp(S.HeatingUpBuff) and Player:BuffDown(S.HotStreakBuff) and (UnitsWithIgniteCount < 2 or EnemiesCount8ySplash >= var_hard_cast_flamestrike or EnemiesCount8ySplash >= var_hot_streak_flamestrike)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames rop_phase 10"; end
  end
  -- scorch,if=searing_touch.active
  if S.Scorch:IsReady() and (var_searing_touch_active) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch rop_phase 11"; end
  end
  -- dragons_breath,if=active_enemies>2
  if S.DragonsBreath:IsReady() and AoEON() and (EnemiesCount16ySplash > 2) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath rop_phase 12 left"; end
    else
      if Cast(S.DragonsBreath) then return "dragons_breath rop_phase 12"; end
    end
  end
  -- arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if S.ArcaneExplosion:IsReady() and AoEON() and (EnemiesCount10yMelee >= var_arcane_explosion and Player:ManaPercentageP() >= var_arcane_explosion_mana) then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion rop_phase 13 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion rop_phase 13"; end
    end
  end
  -- flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if S.Flamestrike:IsReady() and AoEON() and (EnemiesCount8ySplash >= var_hard_cast_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike rop_phase 14"; end
  end
  -- fireball
  if S.Fireball:IsReady() then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball rop_phase 15"; end
  end
end

local function StandardRotation()
  -- flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.firestorm.react)
  if S.Flamestrike:IsReady() and AoEON() and (EnemiesCount8ySplash >= var_hot_streak_flamestrike and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.FirestormBuff))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 1"; end
  end
  -- pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.FirestormBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 2"; end
  end
  -- pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and Player:BuffRemains(S.HotStreakBuff) < S.Fireball:ExecuteTime()) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 3"; end
  end
  -- pyroblast,if=buff.hot_streak.react&(prev_gcd.1.fireball|firestarter.active|action.pyroblast.in_flight)
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and (Player:PrevGCD(1,S.Fireball) or bool(S.Firestarter:ActiveStatus()) or S.Pyroblast:InFlight())) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 4"; end
  end
  -- pyroblast,if=buff.sun_kings_blessing_ready.up&(cooldown.rune_of_power.remains+action.rune_of_power.execute_time+cast_time>buff.sun_kings_blessing_ready.remains|!talent.rune_of_power)&variable.time_to_combustion+cast_time>buff.sun_kings_blessing_ready.remains
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.SunKingsBlessingBuff) and (S.RuneofPower:CooldownRemains() + S.RuneofPower:ExecuteTime() + S.Pyroblast:CastTime() > Player:BuffRemains(S.SunKingsBlessingBuff) or not S.RuneofPower:IsAvailable()) and var_time_to_combustion + S.Pyroblast:CastTime() > Player:BuffRemains(S.SunKingsBlessingBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 5"; end
  end
  -- pyroblast,if=buff.hot_streak.react&searing_touch.active
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and var_searing_touch_active) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 6"; end
  end
  -- pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.PyroclasmBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 7"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!firestarter.active&!variable.fire_blast_pooling&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!runeforge.firestorm)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5|!runeforge.firestorm))&buff.heating_up.react)|(searing_touch.active&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  if S.FireBlast:IsReady() and (not bool(S.Firestarter:ActiveStatus()) and not var_fire_blast_pooling and (((Player:IsCasting(S.Fireball) and (S.Fireball:ExecuteRemains() < 0.5 or not FirestormEquipped) or Player:IsCasting(S.Pyroblast) and (S.Pyroblast:ExecuteRemains() < 0.5 or not FirestormEquipped)) and Player:BuffUp(S.HeatingUpBuff)) or (var_searing_touch_active and (Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not (S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()))))) then
    if FBCast(S.FireBlast) then return "fire_blast standard_rotation 8"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&searing_touch.active&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsReady() and ((Player:IsCasting(S.Scorch) or Player:PrevGCDP(1, S.Scorch)) and Player:BuffUp(S.HeatingUpBuff) and var_searing_touch_active and EnemiesCount8ySplash < var_hot_streak_flamestrike) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 9"; end
  end
  -- phoenix_flames,if=!variable.phoenix_pooling&(!talent.from_the_ashes|active_enemies>1)&(active_dot.ignite<2|active_enemies>=variable.hard_cast_flamestrike|active_enemies>=variable.hot_streak_flamestrike)
  if S.PhoenixFlames:IsCastable() and (not var_phoenix_pooling and (not S.FromTheAshes:IsAvailable() or EnemiesCount8ySplash > 1) and (UnitsWithIgniteCount < 2 or EnemiesCount8ySplash >= var_hard_cast_flamestrike or EnemiesCount8ySplash >= var_hot_streak_flamestrike)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 10"; end
  end
  -- call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  end
  -- dragons_breath,if=active_enemies>1
  if S.DragonsBreath:IsReady() and AoEON() and (EnemiesCount16ySplash > 1) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath standard_rotation 12 left"; end
    else
      if Cast(S.DragonsBreath) then return "dragons_breath standard_rotation 12"; end
    end
  end
  -- scorch,if=searing_touch.active
  if S.Scorch:IsReady() and (var_searing_touch_active) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 13"; end
  end
  -- arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if S.ArcaneExplosion:IsReady() and AoEON() and (EnemiesCount10yMelee >= var_arcane_explosion and Player:ManaPercentageP() >= var_arcane_explosion_mana) then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 14 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 14"; end
    end
  end
  -- flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if S.Flamestrike:IsReady() and AoEON() and (EnemiesCount8ySplash >= var_hard_cast_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 15"; end
  end
  -- fireball
  if S.Fireball:IsReady() then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball standard_rotation 16"; end
  end
end

local function default()
  
end

--- ======= ACTION LISTS =======
local function APL()
  -- Check which cast style we should use for Fire Blast
  if Settings.Fire.ShowFireBlastLeft then
    FBCast = CastLeft
  else
    FBCast = Cast
  end

  -- Update our enemy tables
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  Enemies10yMelee = Player:GetEnemiesInMeleeRange(10)
  Enemies18yMelee = Player:GetEnemiesInMeleeRange(18)
  if AoEON() then
    EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
    EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
    EnemiesCount10yMelee = #Enemies10yMelee
    EnemiesCount18yMelee = #Enemies18yMelee
  else
    EnemiesCount8ySplash = 1
    EnemiesCount10ySplash = 1
    EnemiesCount16ySplash = 1
    EnemiesCount10yMelee = 1
    EnemiesCount18yMelee = 1
  end

  -- Check how many units have ignite
  UnitsWithIgniteCount = UnitsWithIgnite(Enemies8ySplash)

  -- How long is left in the fight?
  fightRemains = max(HL.FightRemains(Enemies8ySplash, false), HL.BossFightRemains())

  -- Check when the Disciplinary Command buff was last applied and its internal CD
  var_disciplinary_command_last_applied = S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()
  var_disciplinary_command_cd_remains = 30 - var_disciplinary_command_last_applied
  if var_disciplinary_command_cd_remains < 0 then var_disciplinary_command_cd_remains = 0 end

  -- Disciplinary Command Check
  Mage.DCCheck()

  -- Is Searing Touch active?
  var_searing_touch_active = S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30

  --variable,name=disable_combustion,op=reset
  var_disable_combustion = not CDsON()

  -- call precombat
  if not Player:AffectingCombat() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    -- counterspell,if=!runeforge.disciplinary_command
    -- TODO : manage for solo ?
    --[[ if S.Counterspell:IsCastable() and not DisciplinaryCommandEquipped then
      if Cast(S.Counterspell) then return "counterspell default 1"; end
    end ]]
    -- call_action_list,name=combustion_timing,if=!variable.disable_combustion
    if not var_disable_combustion then
      CombustionTiming()
    end
    -- variable,name=shifting_power_before_combustion,value=(active_enemies<variable.combustion_shifting_power|active_enemies<variable.combustion_flamestrike|variable.time_to_combustion-action.shifting_power.full_reduction>cooldown.shifting_power.duration)&variable.time_to_combustion-cooldown.shifting_power.remains>action.shifting_power.full_reduction&(cooldown.rune_of_power.remains-cooldown.shifting_power.remains>5|!talent.rune_of_power)
    if (EnemiesCount8ySplash < var_combustion_shifting_power or EnemiesCount8ySplash < var_combustion_flamestrike or var_time_to_combustion - S.ShiftingPower:FullReduction() > 60) and var_time_to_combustion - S.ShiftingPower:CooldownRemains() > S.ShiftingPower:FullReduction() and (S.RuneofPower:CooldownRemains() - S.ShiftingPower:CooldownRemains() > 5 or not S.RuneofPower:IsAvailable()) then
      var_shifting_power_before_combustion = true
    else
      var_shifting_power_before_combustion = false
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=action.fire_blast.charges_fractional+(variable.time_to_combustion+action.shifting_power.full_reduction*variable.shifting_power_before_combustion)%cooldown.fire_blast.duration-1<cooldown.fire_blast.max_charges+variable.overpool_fire_blasts%cooldown.fire_blast.duration-(buff.combustion.duration%cooldown.fire_blast.duration)%%1&variable.time_to_combustion<fight_remains
    -- Note: Manually moved here from lower in the APL
    if (not var_disable_combustion) and (S.FireBlast:ChargesFractional() + (var_time_to_combustion + S.ShiftingPower:FullReduction() * num(var_shifting_power_before_combustion)) % S.FireBlast:Cooldown() - 1 < S.FireBlast:FullRechargeTime() + var_overpool_fire_blasts % S.FireBlast:Cooldown() - (10 % S.FireBlast:Cooldown()) % 1 and var_time_to_combustion < fightRemains) then
      var_fire_blast_pooling = true
    else
      var_fire_blast_pooling = false
    end
    -- shifting_power,if=buff.combustion.down&action.fire_blast.charges<=1&!(buff.infernal_cascade.up&buff.hot_streak.react)&variable.shifting_power_before_combustion
    if S.ShiftingPower:IsReady() and (Player:BuffDown(S.CombustionBuff) and S.FireBlast:Charges() <= 1 and not (Player:BuffUp(S.InfernalCascadeBuff) and Player:BuffUp(S.HotStreakBuff)) and var_shifting_power_before_combustion) then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(18)) then return "shifting_power default 8"; end
    end
    -- radiant_spark,if=buff.combustion.down&(variable.time_to_combustion<variable.combustion_precast_time+execute_time|variable.time_to_combustion>cooldown-10)
    if S.RadiantSpark:IsReady() and (Player:BuffDown(S.CombustionBuff) and (var_time_to_combustion < var_combustion_precast_time + S.RadiantSpark:ExecuteTime() or var_time_to_combustion > 20)) then
      if Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant, not Target:IsInRange(40)) then return "radiant_spark default 9"; end
    end
    -- deathborne,if=buff.combustion.down&buff.rune_of_power.down&variable.time_to_combustion<variable.combustion_precast_time+execute_time
    if S.Deathborne:IsCastable() and CDsON() and (Player:BuffDown(S.CombustionBuff) and Player:BuffDown(S.RuneofPowerBuff) and var_time_to_combustion < var_combustion_precast_time + S.Deathborne:ExecuteTime()) then
      if Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne default 10"; end
    end
    -- mirrors_of_torment,if=variable.time_to_combustion<variable.combustion_precast_time+execute_time&buff.combustion.down
    if S.MirrorsofTorment:IsCastable() and CDsON() and (var_time_to_combustion < var_combustion_precast_time + S.MirrorsofTorment:ExecuteTime() and Player:BuffDown(S.CombustionBuff)) then
      if Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment default 11"; end
    end
    -- fire_blast,use_while_casting=1,if=action.mirrors_of_torment.executing&full_recharge_time-action.mirrors_of_torment.execute_remains<4&!hot_streak_spells_in_flight&!buff.hot_streak.react
    if S.FireBlast:IsReady() and Player:IsCasting(S.MirrorsofTorment) and S.FireBlast:FullRechargeTime() - S.MirrorsofTorment:ExecuteTime() < 4 and not (S.Fireball:InFlight() or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Scorch) or S.PhoenixFlames:InFlight()) and Player:BuffDown(S.HotStreakBuff) then
      if FBCast(S.FireBlast) then return "fire_blast default 12"; end
    end
    if Settings.Commons.Enabled.Trinkets then
      -- use_item,effect_name=gladiators_badge,if=variable.time_to_combustion>cooldown-5
      if I.SinfulAspirantsBadge:IsEquippedAndReady() and (var_time_to_combustion > 55) then
        if Cast(I.SinfulAspirantsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge aspirant default 13"; end
      end
      if I.SinfulGladiatorsBadge:IsEquippedAndReady() and (var_time_to_combustion > 55) then
        if Cast(I.SinfulGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge gladiator default 14"; end
      end
      -- use_item,name=empyreal_ordnance,if=variable.time_to_combustion<=variable.empyreal_ordnance_delay&variable.time_to_combustion>variable.empyreal_ordnance_delay-5
      if I.EmpyrealOrdnance:IsEquippedAndReady() and (var_time_to_combustion <= var_empyreal_ordnance_delay and var_time_to_combustion > var_empyreal_ordnance_delay - 5) then
        if Cast(I.EmpyrealOrdnance, nil, Settings.Commons.DisplayStyle.Trinkets) then return "empyreal_ordnance default 15"; end
      end
      -- use_item,name=glyph_of_assimilation,if=variable.time_to_combustion>=variable.on_use_cutoff
      if I.GlyphofAssimilation:IsEquippedAndReady() and (var_time_to_combustion >= var_on_use_cutoff) then
        if Cast(I.GlyphofAssimilation, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "glyph_of_assimilation default 16"; end
      end
      -- use_item,name=macabre_sheet_music,if=variable.time_to_combustion<=5
      if I.MacabreSheetMusic:IsEquippedAndReady() and (var_time_to_combustion <= 5) then
        if Cast(I.MacabreSheetMusic, nil, Settings.Commons.DisplayStyle.Trinkets) then return "macabre_sheet_music default 17"; end
      end
      -- use_item,name=dreadfire_vessel,if=variable.time_to_combustion>=variable.on_use_cutoff&(buff.infernal_cascade.stack=buff.infernal_cascade.max_stack|!conduit.infernal_cascade|variable.combustion_on_use|variable.time_to_combustion>interpolated_fight_remains%%(cooldown+10))
      if I.DreadfireVessel:IsEquippedAndReady() and (var_time_to_combustion >= var_on_use_cutoff and (Player:BuffStack(S.InfernalCascadeBuff) == 2 or not S.InfernalCascade:ConduitEnabled() or var_combustion_on_use or var_time_to_combustion > fightRemains % 100)) then
        if Cast(I.DreadfireVessel, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(50)) then return "dreadfire_vessel default 18"; end
      end
      -- use_item,name=soul_igniter,if=(variable.time_to_combustion>=30*(variable.on_use_cutoff>0)|cooldown.item_cd_1141.remains)&(!equipped.dreadfire_vessel|cooldown.dreadfire_vessel_349857.remains>5)
      -- TODO: Check cooldown.item_cd_1141.remains
      if I.SoulIgniter:IsEquippedAndReady() and (var_time_to_combustion >= 30 * num(var_on_use_cutoff > 0) and (not I.DreadfireVessel:IsEquipped() or I.DreadfireVessel:CooldownRemains() > 5)) then
        if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "soul_igniter default 19"; end
      end
      -- cancel_buff,name=soul_ignition,if=!conduit.infernal_cascade&time<5|buff.infernal_cascade.stack=buff.infernal_cascade.max_stack
      if Player:BuffUp(S.SoulIgnitionBuff) and (not S.InfernalCascade:ConduitEnabled() and HL.CombatTime() < 5 or Player:BuffStack(S.InfernalCascadeBuff) == 2) then
        if Cast(I.SoulIgniter, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(40)) then return "cancel soul_igniter default 20"; end
      end
      if ((I.SinfulAspirantsBadge:IsEquipped() or I.SinfulGladiatorsBadge:IsEquipped()) and var_time_to_combustion >= var_on_use_cutoff) then
        -- use_item,name=inscrutable_quantum_device,if=equipped.gladiators_badge&variable.time_to_combustion>=variable.on_use_cutoff
        if I.InscrutableQuantumDevice:IsEquippedAndReady() then
          if Cast(I.InscrutableQuantumDevice, nil, Settings.Commons.DisplayStyle.Trinkets) then return "inscrutable_quantum_device default 21"; end
        end
        -- use_item,name=flame_of_battle,if=equipped.gladiators_badge&variable.time_to_combustion>=variable.on_use_cutoff
        if I.FlameofBattle:IsEquippedAndReady() then
          if Cast(I.FlameofBattle, nil, Settings.Commons.DisplayStyle.Trinkets) then return "flame_of_battle default 22"; end
        end
        -- use_item,name=wakeners_frond,if=equipped.gladiators_badge&variable.time_to_combustion>=variable.on_use_cutoff
        if I.WakenersFrond:IsEquippedAndReady() then
          if Cast(I.WakenersFrond, nil, Settings.Commons.DisplayStyle.Trinkets) then return "wakeners_frond default 23"; end
        end
        -- use_item,name=instructors_divine_bell,if=equipped.gladiators_badge&variable.time_to_combustion>=variable.on_use_cutoff
        if I.InstructorsDivineBell:IsEquippedAndReady() then
          if Cast(I.InstructorsDivineBell, nil, Settings.Commons.DisplayStyle.Trinkets) then return "instructors_divine_bell default 24"; end
        end
        -- use_item,name=sunblood_amethyst,if=equipped.gladiators_badge&variable.time_to_combustion>=variable.on_use_cutoff
        if I.SunbloodAmethyst:IsEquippedAndReady() then
          if Cast(I.SunbloodAmethyst, nil, Settings.Commons.DisplayStyle.Trinkets) then return "sunblood_amethyst default 25"; end
        end
      end
      -- use_items,if=variable.time_to_combustion>=variable.on_use_cutoff
      if var_time_to_combustion >= var_on_use_cutoff then
        local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
        if TrinketToUse then
          if Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
        end
      end
    end
    -- frost_nova,if=runeforge.grisly_icicle&buff.combustion.down&(variable.time_to_combustion>cooldown|variable.time_to_combustion<variable.combustion_precast_time+execute_time)
    if S.FrostNova:IsReady() and (GrislyIcicleEquipped and Player:BuffDown(S.CombustionBuff) and (var_time_to_combustion > 30 or var_time_to_combustion < var_combustion_precast_time + S.FrostNova:ExecuteTime())) then
      if Settings.Fire.StayDistance and not Target:IsInRange(12) then
        if CastLeft(S.FrostNova) then return "frost_nova default 26 left"; end
      else
        if Cast(S.FrostNova) then return "frost_nova default 26"; end
      end
    end
    -- counterspell,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.remains<action.frostbolt.cast_time&buff.disciplinary_command_arcane.down&!buff.disciplinary_command.up&(variable.time_to_combustion+action.frostbolt.cast_time>cooldown.buff_disciplinary_command.duration|variable.time_to_combustion<5)
    if S.Counterspell:IsReady() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains < S.Frostbolt:CastTime() and Mage.DC.Arcane == 0 and Player:BuffDown(S.DisciplinaryCommandBuff) and (var_time_to_combustion + S.Frostbolt:CastTime() > 30 or var_time_to_combustion < 5)) then
      if Cast(S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, nil, not Target:IsSpellInRange(S.Counterspell)) then return "counterspell default 27"; end
    end
    -- arcane_explosion,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.remains<execute_time+action.frostbolt.cast_time&buff.disciplinary_command_arcane.down&!buff.disciplinary_command.up&(variable.time_to_combustion+execute_time+action.frostbolt.cast_time>cooldown.buff_disciplinary_command.duration|variable.time_to_combustion<5&!talent.rune_of_power)
    if S.ArcaneExplosion:IsReady() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains < S.ArcaneExplosion:ExecuteTime() + S.Frostbolt:CastTime() and Mage.DC.Arcane == 0 and Player:BuffDown(S.DisciplinaryCommandBuff) and (var_time_to_combustion + S.ArcaneExplosion:ExecuteTime() + S.Frostbolt:CastTime() > 30 or var_time_to_combustion < 5 and not S.RuneofPower:IsAvailable())) then
      if Settings.Fire.StayDistance and not Target:IsInRange(10) then
        if CastLeft(S.ArcaneExplosion) then return "arcane_explosion default 28 left"; end
      else
        if Cast(S.ArcaneExplosion) then return "arcane_explosion default 28"; end
      end
    end
    -- frostbolt,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.remains<cast_time&buff.disciplinary_command_frost.down&!buff.disciplinary_command.up&(variable.time_to_combustion+cast_time>cooldown.buff_disciplinary_command.duration|variable.time_to_combustion<5)
    if S.Frostbolt:IsReady() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains < S.Frostbolt:CastTime() and Mage.DC.Frost == 0 and Player:BuffDown(S.DisciplinaryCommandBuff) and (var_time_to_combustion + S.Frostbolt:CastTime() > 30 or var_time_to_combustion < 5)) then
      if Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt default 29"; end
    end
    -- frost_nova,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&!buff.disciplinary_command.up&(variable.time_to_combustion>cooldown.buff_disciplinary_command.duration|variable.time_to_combustion<5)
    if S.FrostNova:IsReady() and (DisciplinaryCommandEquipped and var_disciplinary_command_cd_remains <= 0 and Mage.DC.Frost == 0 and Player:BuffDown(S.DisciplinaryCommandBuff) and (var_time_to_combustion > 30 or var_time_to_combustion < 5)) then
      if Settings.Fire.StayDistance and not Target:IsInRange(12) then
        if CastLeft(S.FrostNova) then return "frost_nova default 30 left"; end
      else
        if Cast(S.FrostNova) then return "frost_nova default 30"; end
      end
    end
    -- call_action_list,name=combustion_phase,if=variable.time_to_combustion<=0|variable.time_to_combustion<variable.combustion_precast_time&cooldown.combustion.remains<variable.combustion_precast_time
    if not var_disable_combustion and (var_time_to_combustion <= 0 or var_time_to_combustion < var_combustion_precast_time and S.Combustion:CooldownRemains() < var_combustion_precast_time) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- rune_of_power,if=buff.rune_of_power.down&!buff.firestorm.react&(variable.time_to_combustion>=buff.rune_of_power.duration&variable.time_to_combustion>action.fire_blast.full_recharge_time|variable.time_to_combustion>fight_remains)
    if S.RuneofPower:IsReady() and (Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.FirestormBuff) and (var_time_to_combustion >= 12 and var_time_to_combustion > S.FireBlast:FullRechargeTime() or var_time_to_combustion > fightRemains)) then
      if Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneOfPower) then return "rune_of_power default 31"; end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=action.fire_blast.charges_fractional+(variable.time_to_combustion+action.shifting_power.full_reduction*variable.shifting_power_before_combustion)%cooldown.fire_blast.duration-1<cooldown.fire_blast.max_charges+variable.overpool_fire_blasts%cooldown.fire_blast.duration-(buff.combustion.duration%cooldown.fire_blast.duration)%%1&variable.time_to_combustion<fight_remains
    -- Note: Moved higher in APL to ensure it's getting set properly
    -- variable,name=phoenix_pooling,if=active_enemies<variable.combustion_flamestrike,value=variable.time_to_combustion+buff.combustion.duration-5<action.phoenix_flames.full_recharge_time+cooldown.phoenix_flames.duration-action.shifting_power.full_reduction*variable.shifting_power_before_combustion&variable.time_to_combustion<fight_remains|runeforge.sun_kings_blessing|time<5
    var_phoenix_pooling = false
    if not var_disable_combustion and (EnemiesCount8ySplash < var_combustion_flamestrike) then
      var_phoenix_pooling = var_time_to_combustion + 10 - 5 < S.PhoenixFlames:FullRechargeTime() + S.PhoenixFlames:Cooldown() - S.ShiftingPower:FullReduction() * num(var_shifting_power_before_combustion) and var_time_to_combustion < fightRemains or SunKingsBlessingEquipped or HL.CombatTime() < 5
    end
    -- variable,name=phoenix_pooling,if=active_enemies>=variable.combustion_flamestrike,value=variable.time_to_combustion<action.phoenix_flames.full_recharge_time-action.shifting_power.full_reduction*variable.shifting_power_before_combustion&variable.time_to_combustion<fight_remains|runeforge.sun_kings_blessing|time<5
    if not var_disable_combustion and (EnemiesCount8ySplash >= var_combustion_flamestrike) then
      var_phoenix_pooling = var_time_to_combustion < S.PhoenixFlames:FullRechargeTime() - S.ShiftingPower:FullReduction() * var_shifting_power_before_combustion and var_time_to_combustion < fightRemains or SunKingsBlessingEquipped or HL.CombatTime() < 5
    end
    -- call_action_list,name=rop_phase,if=buff.rune_of_power.up&variable.time_to_combustion>0
    if (Player:BuffUp(S.RuneofPowerBuff) and var_time_to_combustion > 0) then
      local ShouldReturn = RoPPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=cooldown.rune_of_power.remains<action.fire_blast.full_recharge_time-action.shifting_power.full_reduction*(variable.shifting_power_before_combustion&cooldown.shifting_power.remains<cooldown.rune_of_power.remains)&cooldown.rune_of_power.remains<fight_remains,if=!variable.fire_blast_pooling&talent.rune_of_power&buff.rune_of_power.down
    if (not var_fire_blast_pooling and S.RuneofPower:IsAvailable() and Player:BuffDown(S.RuneofPowerBuff)) then
      var_fire_blast_pooling = S.RuneofPower:CooldownRemains() < S.FireBlast:FullRechargeTime() - S.ShiftingPower:FullReduction() * num(var_shifting_power_before_combustion and S.ShiftingPower:CooldownRemains() < S.RuneofPower:CooldownRemains()) and S.RuneofPower:CooldownRemains() < fightRemains
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&variable.time_to_combustion>0&active_enemies>=variable.hard_cast_flamestrike&!firestarter.active&!buff.hot_streak.react&(buff.heating_up.react&action.flamestrike.execute_remains<0.5|charges_fractional>=2)
    local var_flamestrike_execute_remains
    if Player:IsCasting(S.Flamestrike) then
      var_flamestrike_execute_remains = Player:CastRemains() + Player:GCD()
    else
      var_flamestrike_execute_remains = 0
    end
    if S.FireBlast:IsReady() and (not var_fire_blast_pooling and var_time_to_combustion > 0 and EnemiesCount8ySplash >= var_hard_cast_flamestrike and not bool(S.Firestarter:ActiveStatus()) and Player:BuffDown(S.HotStreakBuff) and (Player:BuffUp(S.HeatingUpBuff) and var_flamestrike_execute_remains < 0.5 or S.FireBlast:ChargesFractional() >= 2)) then
      if FBCast(S.FireBlast) then return "fire_blast default 32"; end
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=firestarter.active&charges>=1&!variable.fire_blast_pooling&(!action.fireball.executing&!action.pyroblast.in_flight&buff.heating_up.react|action.fireball.executing&!buff.hot_streak.react|action.pyroblast.in_flight&buff.heating_up.react&!buff.hot_streak.react)
    if S.FireBlast:IsReady() and (bool(S.Firestarter:ActiveStatus()) and S.FireBlast:Charges() >= 1 and not var_fire_blast_pooling and (not Player:IsCasting(S.Fireball) and not S.Pyroblast:InFlight() and Player:BuffUp(S.HeatingUpBuff) or Player:IsCasting(S.Fireball) and Player:BuffDown(S.HotStreakBuff) or S.Pyroblast:InFlight() and Player:BuffUp(S.HeatingUpBuff) and Player:BuffDown(S.HotStreakBuff))) then
      if FBCast(S.FireBlast) then return "fire_blast default 33"; end
    end
    -- fire_blast,use_while_casting=1,if=action.shifting_power.executing&full_recharge_time<action.shifting_power.tick_reduction&buff.hot_streak.down&time>10
    if S.FireBlast:IsReady() and (Player:IsCasting(S.ShiftingPower) and S.FireBlast:FullRechargeTime() < S.ShiftingPower:TickReduction() and Player:BuffDown(S.HotStreakBuff) and HL.CombatTime() > 10) then
      if FBCast(S.FireBlast) then return "fire_blast default 34"; end
    end
    --call_action_list,name=standard_rotation,if=variable.time_to_combustion>0&buff.rune_of_power.down
    if (var_time_to_combustion > 0 and Player:BuffDown(S.RuneofPowerBuff)) then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
    --scorch
    if S.Scorch:IsReady() then
      if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch default 35"; end
    end
  end
end

local function Init()
  HR.Print("Fire Mage APL is currently a work in progress.")
end

HR.SetAPL(63, APL, Init)
