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


--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Fire;
local I = Item.Mage.Fire;

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {

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
local var_disable_combustion
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
local var_time_to_combustion
local var_use_off_gcd
local var_use_while_casting
local var_phoenix_pooling
local var_fire_blast_pooling
local var_extended_combustion_remains
local var_needed_fire_blasts
local var_expected_fire_blasts
local var_sun_kings_blessing_max_stack = 12

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
S.PhoenixFlames:RegisterInFlightEffect(257542)
S.PhoenixFlames:RegisterInFlight()
S.Pyroblast:RegisterInFlight(S.CombustionBuff)
S.Fireball:RegisterInFlight(S.CombustionBuff)

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

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Player:BuffDown(S.ArcaneIntellectBuff, true) then
    if HR.Cast(S.ArcaneIntellect) then return "arcane_intellect"; end
  end
  if Everyone.TargetIsValid() then
    --use_item,name=soul_igniter
    --TODO manage soul_igniter
    --mirror_image
    if S.MirrorImage:IsCastable() and HR.CDsON() and Settings.Fire.MirrorImagesBeforePull then
      if HR.Cast(S.MirrorImage, Settings.Fire.GCDasOffGCD.MirrorImage) then return "mirror_image precombat"; end
    end
    --pyroblast
    if S.Pyroblast:IsCastable() then
      if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast precombat"; end
    end
    --fireball
    if S.Fireball:IsCastable() then
      if HR.Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball precombat"; end
    end
  end
end

local function VarInit()
  --variable,name=hot_streak_flamestrike,op=set,if=variable.hot_streak_flamestrike=0,value=2*talent.flame_patch+3*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_hot_streak_flamestrike = 2
  else
    var_hot_streak_flamestrike = 3
  end

  --variable,name=hard_cast_flamestrike,op=set,if=variable.hard_cast_flamestrike=0,value=2*talent.flame_patch+3*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_hard_cast_flamestrike = 2
  else
    var_hard_cast_flamestrike = 3
  end

  --variable,name=combustion_flamestrike,op=set,if=variable.combustion_flamestrike=0,value=3*talent.flame_patch+6*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_combustion_flamestrike = 3
  else
    var_combustion_flamestrike = 6
  end

  --variable,name=arcane_explosion,op=set,if=variable.arcane_explosion=0,value=99*talent.flame_patch+2*!talent.flame_patch
  if S.FlamePatch:IsAvailable() then
    var_arcane_explosion = 99
  else
    var_arcane_explosion = 2
  end

  --variable,name=arcane_explosion_mana,default=40,op=reset
  var_arcane_explosion_mana = 40

  --variable,name=kindling_reduction,default=0.4,op=reset
  var_kindling_reduction = 0.4

  --variable,name=skb_duration,op=set,value=dbc.effect.828420.base_value
  var_skb_duration = 5

  --variable,name=combustion_on_use,op=set,value=equipped.gladiators_badge|equipped.macabre_sheet_music|equipped.inscrutable_quantum_device|equipped.sunblood_amethyst|equipped.empyreal_ordnance
  --variable,name=empyreal_ordnance_delay,default=18,op=reset
  --variable,name=on_use_cutoff,op=set,value=20,if=variable.combustion_on_use
  --variable,name=on_use_cutoff,op=set,value=25,if=equipped.macabre_sheet_music
  --variable,name=on_use_cutoff,op=set,value=20+variable.empyreal_ordnance_delay,if=equipped.empyreal_ordnance
  --TODO : manage trinkets

  --variable,name=combustion_shifting_power,default=2,op=reset
  var_combustion_shifting_power = 2
  
  var_init = true
end

local function active_talents()
  --living_bomb,if=active_enemies>1&buff.combustion.down&(variable.time_to_combustion>cooldown.living_bomb.duration|variable.time_to_combustion<=0|variable.disable_combustion)
  if S.LivingBomb:IsCastable() and HR.AoEON() and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Combustion) and (var_time_to_combustion > S.LivingBomb:CooldownRemains() or var_time_to_combustion <= 0 or var_disable_combustion) then
    if HR.Cast(S.LivingBomb, nil, nil, not Target:IsInRange(S.LivingBomb)) then return "living_bomb active_talents 1"; end
  end
  --meteor,if=!variable.disable_combustion&variable.time_to_combustion<=0
  --|(cooldown.meteor.duration<variable.time_to_combustion&!talent.rune_of_power)
  --|talent.rune_of_power&buff.rune_of_power.up&variable.time_to_combustion>action.meteor.cooldown
  --|fight_remains<variable.time_to_combustion|variable.disable_combustion
  if S.Meteor:IsCastable() and ((not var_disable_combustion and var_time_to_combustion <= 0) 
  or (S.Meteor:CooldownRemains() < var_time_to_combustion and not S.RuneofPower:IsAvailable()) 
  or (S.RuneofPower:IsAvailable() and Player:BuffUp(S.RuneofPowerBuff) and var_time_to_combustion > 45) 
  or HL.BossFilteredFightRemains("<", var_time_to_combustion ) or var_disable_combustion) then
    if HR.Cast(S.Meteor, nil, nil, not Target:IsInRange(S.Meteor)) then return "meteor active_talents 2"; end
  end
  --dragons_breath,if=talent.alexstraszas_fury&(buff.combustion.down&!buff.hot_streak.react)
  if S.DragonsBreath:IsCastable() and S.AlexstraszasFury:IsAvailable() and (Player:BuffDown(S.Combustion) and Player:BuffDown(S.Combustion)) then
    if HR.Cast(S.DragonsBreath, nil, nil, not Target:IsInRange(12)) then return "dragons_breath active_talents 3"; end
  end
end

local function combustion_cooldowns()
  --potion
  if I.PotionofPhantomFire:IsReady() and Settings.Commons.Enabled.UsePotions then
    if HR.CastSuggested(I.PotionofPhantomFire, nil, Settings.Commons.DisplayStyle.Potions) then return "potion combustion_cooldowns 1"; end
  end
  --blood_fury
  if S.BloodFury:IsCastable() then
    if HR.Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury combustion_cooldowns 2"; end
  end
  --berserking
  if S.Berserking:IsCastable() then
    if HR.Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking combustion_cooldowns 3"; end
  end
  --fireblood
  if S.Fireblood:IsCastable() then
    if HR.Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood combustion_cooldowns 4"; end
  end
  --ancestral_call
  if S.AncestralCall:IsCastable() then
    if HR.Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call combustion_cooldowns 5"; end
  end
  --use_items
  if (true) then
    local TrinketToUse = Player:GetUseableTrinkets(OnUseExcludes)
    if TrinketToUse then
      if HR.Cast(TrinketToUse, nil, Settings.Commons.DisplayStyle.Trinkets) then return "Generic use_items for " .. TrinketToUse:Name(); end
    end
  end
  --use_item,use_off_gcd=1,effect_name=gladiators_badge,if=action.meteor.in_flight_remains<=0.5
  --TODO : manage use_off_gcd
  --time_warp,if=runeforge.temporal_warp&buff.exhaustion.up
  if S.TimeWarp:IsCastable() and Settings.Fire.UseTemporalWarp and TemporalWarpEquipped and Player:BloodlustExhaustUp() then
    if HR.Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp combustion_cooldowns 8"; end
  end
end

local function combustion_phase()
  local function hot_streak_spells_in_flight()
    local numSpells = 0
    if (Player:BuffUp(S.HeatingUpBuff)) then
      -- print("Heating Up")
      numSpells = numSpells + 1
    end
    if (S.Pyroblast:InFlight()) then
      -- print("Pyroblase")
      numSpells = numSpells + 1
    end
    if (S.Fireball:InFlight()) then
      -- print("Fireball")
      numSpells = numSpells + 1
    end
    if (S.PhoenixFlames:InFlight()) then
      -- print("Phoenix")
      numSpells = numSpells + 1
    end
    return numSpells
  end

  --lights_judgment,if=buff.combustion.down
  if S.LightsJudgment:IsCastable() and Player:BuffDown(S.Combustion) then
    if HR.Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment combustion_phase 1"; end
  end
  --variable,use_off_gcd=1,use_while_casting=1,name=extended_combustion_remains,op=set,value=buff.combustion.remains+buff.combustion.duration*(cooldown.combustion.remains<buff.combustion.remains),if=conduit.infernal_cascade
  if S.InfernalCascade:ConduitEnabled() then
    var_extended_combustion_remains = Player:BuffRemains(S.Combustion) + S.Combustion:BaseDuration() * num(S.Combustion:CooldownRemains() < Player:BuffRemains(S.Combustion))
  else
    var_extended_combustion_remains = 0
  end
  --variable,use_off_gcd=1,use_while_casting=1,name=extended_combustion_remains,op=add,value=variable.skb_duration,if=conduit.infernal_cascade&(buff.sun_kings_blessing_ready.up|variable.extended_combustion_remains>1.5*gcd.max*(buff.sun_kings_blessing.max_stack-buff.sun_kings_blessing.stack))
  if S.InfernalCascade:ConduitEnabled() and SunKingsBlessingEquipped and (Player:BuffUp(S.SunKingsBlessingBuff) or var_extended_combustion_remains > 1.5 * Player:GCD() * (var_sun_kings_blessing_max_stack - Player:BuffStack(S.SunKingsBlessingBuff))) then
    var_extended_combustion_remains = var_extended_combustion_remains + var_skb_duration
  else
    var_extended_combustion_remains = 0
  end
  --bag_of_tricks,if=buff.combustion.down
  if S.BagofTricks:IsCastable() and Player:BuffDown(S.Combustion) then
    if HR.Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks combustion_phase 4"; end
  end
  --living_bomb,if=active_enemies>1&buff.combustion.down
  if S.LivingBomb:IsCastable() and HR.AoEON() and EnemiesCount10ySplash > 1 and Player:BuffDown(S.Combustion) then
    if HR.Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 5"; end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=(active_enemies<=active_dot.ignite|!cooldown.phoenix_flames.ready)&!conduit.infernal_cascade&charges>=1
  --&buff.combustion.up&!buff.firestorm.react&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react<2
  if S.FireBlast:IsCastable() and (EnemiesCount8ySplash <= UnitsWithIgniteCount or not S.PhoenixFlames:IsCastable()) and not S.InfernalCascade:ConduitEnabled() and S.FireBlast:Charges() >= 1 
  and Player:BuffUp(S.Combustion) and Player:BuffDown(S.FirestormBuff) and Player:BuffDown(S.HotStreakBuff) and hot_streak_spells_in_flight() < 2 then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast combustion_phase 6 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast combustion_phase 6"; end
    end
  end
  --variable,use_off_gcd=1,use_while_casting=1,name=expected_fire_blasts,op=set,value=action.fire_blast.charges_fractional+(variable.extended_combustion_remains-buff.infernal_cascade.duration)%cooldown.fire_blast.duration,if=conduit.infernal_cascade
  --variable,use_off_gcd=1,use_while_casting=1,name=needed_fire_blasts,op=set,value=ceil(variable.extended_combustion_remains%(buff.infernal_cascade.duration-gcd.max)),if=conduit.infernal_cascade
  if S.InfernalCascade:ConduitEnabled() then
    var_expected_fire_blasts = S.FireBlast:ChargesFractional() + (var_extended_combustion_remains - S.InfernalCascadeBuff:BaseDuration()) / S.FireBlast:CooldownRemains()
    var_needed_fire_blasts = math.ceil(var_extended_combustion_remains / (S.InfernalCascadeBuff:BaseDuration() - Player:GCD()))
  else
    var_expected_fire_blasts = 0
    var_needed_fire_blasts = 0
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=(active_enemies<=active_dot.ignite|!cooldown.phoenix_flames.ready)&conduit.infernal_cascade&charges>=1
  --&(variable.expected_fire_blasts>=variable.needed_fire_blasts|variable.extended_combustion_remains<=buff.infernal_cascade.duration|buff.infernal_cascade.stack<2|buff.infernal_cascade.remains<gcd.max|cooldown.shifting_power.ready&active_enemies>=variable.combustion_shifting_power&covenant.night_fae)
  --&buff.combustion.up&(!buff.firestorm.react|buff.infernal_cascade.remains<0.5)&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react<2
  if S.FireBlast:IsCastable() and (EnemiesCount8ySplash <= UnitsWithIgniteCount or not S.PhoenixFlames:IsCastable()) and S.InfernalCascade:ConduitEnabled() and S.FireBlast:Charges() >= 1
  and (var_expected_fire_blasts >= var_needed_fire_blasts or var_extended_combustion_remains <= S.InfernalCascade:BaseDuration() or Player:BuffStack(S.InfernalCascadeBuff) or Player:BuffRemains(S.InfernalCascadeBuff) < Player:GCD() or (Player:Covenant() == "Night Fae" and S.ShiftingPower:CooldownRemains() and EnemiesCount18yMelee >= var_combustion_shifting_power))
  and Player:BuffUp(S.Combustion) and (Player:BuffDown(S.FirestormBuff) or Player:BuffRemains(S.InfernalCascadeBuff)) and Player:BuffDown(S.HotStreakBuff) and hot_streak_spells_in_flight() < 2 then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast combustion_phase 9 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast combustion_phase 9"; end
    end
  end
  --call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = active_talents(); if ShouldReturn then return ShouldReturn; end
  end
  --combustion,use_off_gcd=1,use_while_casting=1,if=buff.combustion.down
  --&(!runeforge.disciplinary_command|buff.disciplinary_command.up|buff.disciplinary_command_frost.up&talent.rune_of_power&cooldown.buff_disciplinary_command.ready)
  --&(!runeforge.grisly_icicle|debuff.grisly_icicle.up)
  --&(action.meteor.in_flight&action.meteor.in_flight_remains<=0.6|action.scorch.executing&action.scorch.execute_remains<0.6|action.fireball.executing&action.fireball.execute_remains<0.6|action.pyroblast.executing&action.pyroblast.execute_remains<0.6|action.flamestrike.executing&action.flamestrike.execute_remains<0.6)
  if S.Combustion:IsCastable() and (Player:IsCasting() and HL.CombatTime() > 0) and Player:BuffDown(S.Combustion) 
  and (not DisciplinaryCommandEquipped or Player:BuffUp(S.DisciplinaryCommandBuff) or (S.RuneofPower:IsAvailable() and S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer() > 30 and Player:BuffUp(S.DisciplinaryCommandFrostBuff)))
  and (not GrislyIcicleEquipped or Target:DebuffUp(S.GrislyIcicleBuff))
  and (S.Meteor:InFlight() or Player:IsCasting(S.Scorch) or Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast) or Player:IsCasting(S.Flamestrike)) then
    if HR.Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion combustion_phase 15"; end
  end
  --call_action_list,name=combustion_cooldowns,if=buff.combustion.last_expire<=action.combustion.last_used", "Other cooldowns that should be used with Combustion should only be used with an actual Combustion cast and not with a Sun King's Blessing proc.
  if HR.CDsON() then
    local ShouldReturn = combustion_cooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  --flamestrike,if=(buff.hot_streak.react|buff.firestorm.react)&active_enemies>=variable.combustion_flamestrike
  if S.Flamestrike:IsCastable() and HR.AoEON() and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.FirestormBuff)) and EnemiesCount16ySplash >= var_combustion_flamestrike then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike combustion_phase 17"; end
  end
  --pyroblast,if=buff.sun_kings_blessing_ready.up&buff.sun_kings_blessing_ready.remains>cast_time
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.SunKingsBlessingBuff) and Player:BuffRemains(S.SunKingsBlessingBuff) > S.Pyroblast:CastTime() then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 18"; end
  end
  --pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.FirestormBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 19"; end
  end
  --pyroblast,if=buff.pyroclasm.react&buff.pyroclasm.remains>cast_time&(buff.combustion.remains>cast_time|buff.combustion.down)&active_enemies<variable.combustion_flamestrike
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.PyroclasmBuff) and Player:BuffRemains(S.PyroclasmBuff) > S.Pyroblast:CastTime() and (Player:BuffRemains(S.Combustion) > S.Pyroblast:CastTime() or Player:BuffDown(S.Combustion)) and EnemiesCount16ySplash < var_combustion_flamestrike then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 20"; end
  end
  --pyroblast,if=buff.hot_streak.react&buff.combustion.up
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.HotStreakBuff) and Player:BuffUp(S.Combustion) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 21"; end
  end
  --pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies<variable.combustion_flamestrike
  if S.Pyroblast:IsCastable() and Player:IsCasting(S.Scorch) and Player:BuffUp(S.HeatingUpBuff) and EnemiesCount16ySplash < var_combustion_flamestrike then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 22"; end
  end
  --shifting_power,if=buff.combustion.up&!action.fire_blast.charges&active_enemies>=variable.combustion_shifting_power&action.phoenix_flames.full_recharge_time>full_reduction,interrupt_if=action.fire_blast.charges=action.fire_blast.max_charges
  --TODO : interrupt_if
  if S.ShiftingPower:IsCastable() and Player:BuffUp(S.Combustion) and S.FireBlast:Charges() == 0 and EnemiesCount18yMelee >= var_combustion_shifting_power and S.PhoenixFlames:FullRechargeTime() > S.ShiftingPower:FullReduction() then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant) then return "shifting_power combustion_phase 23"; end
  end
  --phoenix_flames,if=buff.combustion.up&((action.fire_blast.charges<1&talent.pyroclasm&active_enemies=1)|!talent.pyroclasm|active_enemies>1)
  --&buff.heating_up.react+hot_streak_spells_in_flight<2
  if S.PhoenixFlames:IsCastable() and Player:BuffUp(S.Combustion) and ((S.FireBlast:Charges() < 1 and S.Pyroclasm:IsAvailable() and EnemiesCount8ySplash == 1) or not S.Pyroclasm:IsAvailable() or EnemiesCount8ySplash > 1)
  and hot_streak_spells_in_flight() < 2 then
    if HR.Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 24"; end
  end
  --flamestrike,if=buff.combustion.down&cooldown.combustion.remains<cast_time&active_enemies>=variable.combustion_flamestrike
  if S.Flamestrike:IsCastable() and HR.AoEON() and Player:BuffDown(S.Combustion) and S.Combustion:CooldownRemains() < S.Flamestrike:CastTime() and EnemiesCount16ySplash >= var_combustion_flamestrike then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike combustion_phase 25"; end
  end
  --fireball,if=buff.combustion.down&cooldown.combustion.remains<cast_time&!conduit.flame_accretion
  if S.Fireball:IsCastable() and Player:BuffDown(S.Combustion) and S.Combustion:CooldownRemains() < S.Fireball:CastTime() and not S.FlameAccretion:ConduitEnabled() then
    if HR.Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 26"; end
  end
  --scorch,if=buff.combustion.remains>cast_time&buff.combustion.up|buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Scorch:IsCastable() and ((Player:BuffRemains(S.Combustion) > S.Scorch:CastTime() and Player:BuffUp(S.Combustion)) or (Player:BuffDown(S.Combustion) and S.Combustion:CooldownRemains() < S.Scorch:ExecCastTimeuteTime())) then
    if HR.Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 27"; end
  end
  --living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
  if S.LivingBomb:IsCastable() and Player:BuffRemains(S.Combustion) < Player:GCDRemains() and EnemiesCount10ySplash then
    if HR.Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 28"; end
  end
  --dragons_breath,if=buff.combustion.remains<gcd.max&buff.combustion.up
  if S.DragonsBreath:IsCastable() and Player:BuffRemains(S.Combustion) < Player:GCDRemains() and Player:BuffUp(S.Combustion) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if HR.CastLeft(S.DragonsBreath) then return "dragons_breath combustion_phase 29 left"; end
    else
      if HR.Cast(S.DragonsBreath) then return "dragons_breath combustion_phase 29"; end
    end
  end
  --scorch,if=target.health.pct<=30&talent.searing_touch
  if S.Scorch:IsCastable() and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 then
    if HR.Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 30"; end
  end
end

local function rop_phase()
  --flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.firestorm.react)
  if S.Flamestrike:IsCastable() and HR.AoEON() and EnemiesCount10ySplash >= var_hot_streak_flamestrike and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.FirestormBuff)) then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike rop_phase 1"; end
  end
  --pyroblast,if=buff.sun_kings_blessing_ready.up&buff.sun_kings_blessing_ready.remains>cast_time
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.SunKingsBlessingBuff) and Player:BuffRemains(S.SunKingsBlessingBuff) > S.Pyroblast:CastTime() then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 2"; end
  end
  --pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.FirestormBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 3"; end
  end
  --pyroblast,if=buff.hot_streak.react
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.HotStreakBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 4"; end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&buff.sun_kings_blessing_ready.down&active_enemies<variable.hard_cast_flamestrike&!firestarter.active
  --&(!buff.heating_up.react&!buff.hot_streak.react&!prev_off_gcd.fire_blast
  --&(action.fire_blast.charges>=2|(talent.alexstraszas_fury&cooldown.dragons_breath.ready)|(talent.searing_touch&target.health.pct<=30)))
  if S.FireBlast:IsCastable() and not var_fire_blast_pooling and Player:BuffDown(S.SunKingsBlessingBuff) and EnemiesCount16ySplash < var_hard_cast_flamestrike and not bool(S.Firestarter:ActiveStatus())
  and (Player:BuffDown(S.HeatingUpBuff) and Player:BuffDown(S.HotStreakBuff) and not Player:PrevGCD(1,S.FireBlast) 
  and (S.FireBlast:Charges() >= 2 or (S.AlexstraszasFury:IsAvailable() and S.DragonsBreath:IsCastable()) or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30))) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast rop_phase 5 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast rop_phase 5"; end
    end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&!firestarter.active
  --&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!runeforge.firestorm)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5|!runeforge.firestorm))&buff.heating_up.react)
  --|(talent.searing_touch&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  if S.FireBlast:IsCastable() and not bool(S.Firestarter:ActiveStatus()) and not var_fire_blast_pooling 
  and ((((Player:IsCasting(S.Fireball) and (Player:CastRemains() < 0.5 or not FirestormEquipped)) or (Player:IsCasting(S.Pyroblast) and (Player:CastRemains() < 0.5 or not FirestormEquipped))) or Player:BuffUp(S.HeatingUpBuff))
  or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and ((Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch)) or (Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not (S.Pyroblast:InFlight() or S.Fireball:InFlight() or S.PhoenixFlames:InFlight()))))) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast rop_phase 6 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast rop_phase 6"; end
    end
  end
  --call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = active_talents(); if ShouldReturn then return ShouldReturn; end
  end
  --pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains&cast_time<buff.rune_of_power.remains
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.RuneofPowerBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 8"; end
  end
  --pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&talent.searing_touch&target.health.pct<=30&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsCastable() and Player:IsCasting(S.Scorch) and Player:BuffUp(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and EnemiesCount16ySplash < var_hot_streak_flamestrike then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast rop_phase 9"; end
  end
  --phoenix_flames,if=!variable.phoenix_pooling&buff.heating_up.react&!buff.hot_streak.react&(active_dot.ignite<2|active_enemies>=variable.hard_cast_flamestrike|active_enemies>=variable.hot_streak_flamestrike)
  if S.PhoenixFlames:IsCastable() and not var_phoenix_pooling and Player:BuffUp(S.HeatingUpBuff) and not Player:BuffUp(S.HotStreakBuff) and (UnitsWithIgniteCount < 2 or EnemiesCount16ySplash >= var_hard_cast_flamestrike or EnemiesCount16ySplash >= var_hot_streak_flamestrike) then
    if HR.Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames rop_phase 10"; end
  end
  --scorch,if=target.health.pct<=30&talent.searing_touch
  if S.Scorch:IsCastable() and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 then
    if HR.Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch rop_phase 11"; end
  end
  --dragons_breath,if=active_enemies>2
  if S.DragonsBreath:IsCastable() and HR.AoEON() and EnemiesCount16ySplash > 2 then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if HR.CastLeft(S.DragonsBreath) then return "dragons_breath rop_phase 12 left"; end
    else
      if HR.Cast(S.DragonsBreath) then return "dragons_breath rop_phase 12"; end
    end
  end
  --arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if S.ArcaneExplosion:IsCastable() and HR.AoEON() and EnemiesCount10yMelee >= var_arcane_explosion and Player:ManaPercentageP() >= var_arcane_explosion_mana then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if HR.CastLeft(S.ArcaneExplosion) then return "arcane_explosion rop_phase 13 left"; end
    else
      if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion rop_phase 13"; end
    end
  end
  --flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if S.Flamestrike:IsCastable() and HR.AoEON() and EnemiesCount16ySplash >= var_hard_cast_flamestrike then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike rop_phase 14"; end
  end
  --fireball
  if S.Fireball:IsCastable() then
    if HR.Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball rop_phase 15"; end
  end
end

local function standard_rotation()
  --flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.firestorm.react)
  if S.Flamestrike:IsCastable() and HR.AoEON() and EnemiesCount10ySplash >= var_hot_streak_flamestrike and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.FirestormBuff)) then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike standard_rotation 1"; end
  end
  --pyroblast,if=buff.firestorm.react
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.FirestormBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 2"; end
  end
  --pyroblast,if=buff.hot_streak.react&buff.hot_streak.remains<action.fireball.execute_time
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.HotStreakBuff) and Player:BuffRemains(S.HotStreakBuff) < S.Fireball:ExecuteTime() then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 3"; end
  end
  --pyroblast,if=buff.hot_streak.react&(prev_gcd.1.fireball|firestarter.active|action.pyroblast.in_flight)
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.HotStreakBuff) and (Player:PrevGCD(1,S.Fireball) or bool(S.Firestarter:ActiveStatus()) or S.Pyroblast:InFlight()) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 4"; end
  end
  --pyroblast,if=buff.sun_kings_blessing_ready.up&(cooldown.rune_of_power.remains+action.rune_of_power.execute_time+cast_time>buff.sun_kings_blessing_ready.remains|!talent.rune_of_power)&variable.time_to_combustion+cast_time>buff.sun_kings_blessing_ready.remains
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.SunKingsBlessingBuff) and (S.RuneofPower:CooldownRemains() + S.RuneofPower:ExecuteTime() + S.Pyroblast:CastTime() > Player:BuffRemains(S.SunKingsBlessingBuff) or not S.RuneofPower:IsAvailable()) and var_time_to_combustion + S.Pyroblast:CastTime() > Player:BuffRemains(S.SunKingsBlessingBuff) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 5"; end
  end
  --pyroblast,if=buff.hot_streak.react&target.health.pct<=30&talent.searing_touch
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.HotStreakBuff) and Target:HealthPercentage() <= 30 and S.SearingTouch:IsAvailable() then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 6"; end
  end
  --pyroblast,if=buff.pyroclasm.react&cast_time<buff.pyroclasm.remains
  if S.Pyroblast:IsCastable() and Player:BuffUp(S.PyroclasmBuff) and S.Pyroblast:CastTime() < Player:BuffRemains(S.PyroclasmBuff) and not Player:IsCasting(S.Pyroblast) then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 7"; end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=!firestarter.active&!variable.fire_blast_pooling
  --&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!runeforge.firestorm)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5|!runeforge.firestorm))&buff.heating_up.react)
  --|(talent.searing_touch&target.health.pct<=30&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  if S.FireBlast:IsCastable() and not bool(S.Firestarter:ActiveStatus()) and not var_fire_blast_pooling 
  and ((((Player:IsCasting(S.Fireball) and (Player:CastRemains() < 0.5 or not FirestormEquipped)) or (Player:IsCasting(S.Pyroblast) and (Player:CastRemains() < 0.5 or not FirestormEquipped))) or Player:BuffUp(S.HeatingUpBuff))
  or (S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and ((Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch)) or (Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and not S.Pyroblast:InFlight())))) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast standard_rotation 8 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast standard_rotation 8"; end
    end
  end
  --pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&talent.searing_touch&target.health.pct<=30&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsCastable() and Player:IsCasting(S.Scorch) and Player:BuffUp(S.HeatingUpBuff) and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 and EnemiesCount16ySplash < var_hot_streak_flamestrike then
    if HR.Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 9"; end
  end
  --phoenix_flames,if=!variable.phoenix_pooling&(!talent.from_the_ashes|active_enemies>1)&(active_dot.ignite<2|active_enemies>=variable.hard_cast_flamestrike|active_enemies>=variable.hot_streak_flamestrike)
  if S.PhoenixFlames:IsCastable() and not var_phoenix_pooling and (not S.FromTheAshes:IsAvailable() or EnemiesCount8ySplash > 1) and (UnitsWithIgniteCount < 2 or EnemiesCount16ySplash >= var_hard_cast_flamestrike or EnemiesCount16ySplash >= var_hot_streak_flamestrike) then
    if HR.Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 10"; end
  end
  --call_action_list,name=active_talents
  if (true) then
    local ShouldReturn = active_talents(); if ShouldReturn then return ShouldReturn; end
  end
  --dragons_breath,if=active_enemies>1
  if S.DragonsBreath:IsCastable() and HR.AoEON() and EnemiesCount16ySplash > 1 then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if HR.CastLeft(S.DragonsBreath) then return "dragons_breath standard_rotation 12 left"; end
    else
      if HR.Cast(S.DragonsBreath) then return "dragons_breath standard_rotation 12"; end
    end
  end
  --scorch,if=target.health.pct<=30&talent.searing_touch
  if S.Scorch:IsCastable() and S.SearingTouch:IsAvailable() and Target:HealthPercentage() <= 30 then
    if HR.Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 13"; end
  end
  --arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if S.ArcaneExplosion:IsCastable() and HR.AoEON() and EnemiesCount10yMelee >= var_arcane_explosion and Player:ManaPercentageP() >= var_arcane_explosion_mana then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if HR.CastLeft(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 14 left"; end
    else
      if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 14"; end
    end
  end
  --flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if S.Flamestrike:IsCastable() and HR.AoEON() and EnemiesCount16ySplash >= var_hard_cast_flamestrike then
    if HR.Cast(S.Flamestrike, nil, nil, not Target:IsSpellInRange(S.Flamestrike)) then return "flamestrike standard_rotation 15"; end
  end
  --fireball
  if S.Fireball:IsCastable() then
    if HR.Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball standard_rotation 16"; end
  end
end

local function default()
  --counterspell,if=!runeforge.disciplinary_command
  -- TODO : manage for solo ?
  --[[ if S.Counterspell:IsCastable() and not DisciplinaryCommandEquipped then
    if HR.Cast(S.Counterspell) then return "counterspell default 1"; end
  end ]]
  --variable,name=time_to_combustion,op=set,value=talent.firestarter*firestarter.remains+(cooldown.combustion.remains*(1-variable.kindling_reduction*talent.kindling))*!cooldown.combustion.ready*buff.combustion.down
  --variable,name=time_to_combustion,op=max,value=variable.empyreal_ordnance_delay-(cooldown.empyreal_ordnance.duration-cooldown.empyreal_ordnance.remains)*!cooldown.empyreal_ordnance.ready,if=equipped.empyreal_ordnance
  --variable,name=time_to_combustion,op=max,value=cooldown.gladiators_badge.remains,if=equipped.gladiators_badge
  --variable,name=time_to_combustion,op=max,value=buff.rune_of_power.remains,if=talent.rune_of_power&buff.combustion.down
  --variable,name=time_to_combustion,op=max,value=cooldown.rune_of_power.remains+buff.rune_of_power.duration,if=talent.rune_of_power&buff.combustion.down&cooldown.rune_of_power.remains+5<variable.time_to_combustion
  --variable,name=time_to_combustion,op=max,value=cooldown.buff_disciplinary_command.remains,if=runeforge.disciplinary_command&buff.disciplinary_command.down
  --TODO manage trinkets
  var_time_to_combustion = S.Firestarter:ActiveRemains() + S.Combustion:CooldownRemains() * (1 - var_kindling_reduction * num(S.Kindling:IsAvailable())) * num(S.Combustion:CooldownRemains() > 0) * num(Player:BuffDown(S.Combustion))
  if S.RuneofPower:IsAvailable() and Player:BuffDown(S.Combustion) then
    var_time_to_combustion = math.max(var_time_to_combustion, Player:BuffRemains(S.RuneofPowerBuff))
    if S.RuneofPower:CooldownRemains() + 5 < var_time_to_combustion then
      var_time_to_combustion = math.max(var_time_to_combustion, S.RuneofPower:CooldownRemains() + S.RuneofPower:BaseDuration())
    end
  elseif DisciplinaryCommandEquipped and Player:BuffDown(S.DisciplinaryCommandBuff) then
    var_time_to_combustion = math.max(var_time_to_combustion, math.max(30, S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer()))
  end
  --shifting_power,if=buff.combustion.down&variable.time_to_combustion>full_reduction&(cooldown.rune_of_power.remains>full_reduction|!talent.rune_of_power)&!(buff.infernal_cascade.up&buff.hot_streak.react)
  --&(active_enemies<variable.combustion_shifting_power|active_enemies<variable.combustion_flamestrike|variable.time_to_combustion-full_reduction>cooldown)
  if S.ShiftingPower:IsCastable() and HR.CDsON() and Player:BuffDown(S.Combustion) and var_time_to_combustion > S.ShiftingPower:FullReduction() and (S.RuneofPower:CooldownRemains() > S.ShiftingPower:FullReduction() or not S.RuneofPower:IsAvailable()) and not(Player:BuffUp(S.InfernalCascadeBuff) and Player:BuffUp(S.HotStreakBuff)) 
  and (EnemiesCount18yMelee < var_combustion_shifting_power or EnemiesCount18yMelee < var_combustion_flamestrike or (var_time_to_combustion - S.ShiftingPower:FullReduction() > S.ShiftingPower:Cooldown())) then
    if HR.Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Covenant) then return "shifting_power default 8"; end
  end
  --radiant_spark,if=(buff.combustion.down&buff.rune_of_power.down&(variable.time_to_combustion<execute_time|variable.time_to_combustion>cooldown.radiant_spark.duration))|(buff.rune_of_power.up&variable.time_to_combustion>30)
  --TODO add cooldown.radiant_spark.duration condition
  if S.RadiantSpark:IsCastable() and HR.CDsON() and ((Player:BuffDown(S.Combustion) and Player:BuffDown(S.RuneofPowerBuff) and (var_time_to_combustion < S.RadiantSpark:ExecuteTime())) or (Player:BuffUp(S.RuneofPowerBuff) and var_time_to_combustion > 30)) then
    if HR.Cast(S.RadiantSpark, nil, Settings.Commons.DisplayStyle.Covenant) then return "radiant_spark default 9"; end
  end
  --deathborne,if=buff.combustion.down&buff.rune_of_power.down&variable.time_to_combustion<execute_time
  if S.Deathborne:IsCastable() and HR.CDsON() and Player:BuffDown(S.Combustion) and Player:BuffDown(S.RuneofPowerBuff) and var_time_to_combustion < S.Deathborne:ExecuteTime() then
    if HR.Cast(S.Deathborne, nil, Settings.Commons.DisplayStyle.Covenant) then return "deathborne default 10"; end
  end
  --mirrors_of_torment,if=variable.time_to_combustion<=3&buff.combustion.down
  if S.MirrorsofTorment:IsCastable() and HR.CDsON() and var_time_to_combustion <= 3 and Player:BuffDown(S.Combustion) then
    if HR.Cast(S.MirrorsofTorment, nil, Settings.Commons.DisplayStyle.Covenant) then return "mirrors_of_torment default 11"; end
  end
  --fire_blast,use_while_casting=1,if=action.mirrors_of_torment.executing&full_recharge_time-action.mirrors_of_torment.execute_remains<4&!hot_streak_spells_in_flight&!buff.hot_streak.react
  if S.FireBlast:IsCastable() and Player:IsCasting(S.MirrorsofTorment) and S.FireBlast:FullRechargeTime() - S.MirrorsofTorment:ExecuteTime() < 4 and not (S.Pyroblast:InFlight() or S.Fireball:InFlight() or S.PhoenixFlames:InFlight()) and Player:BuffDown(S.HotStreakBuff) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast default 12 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast default 12"; end
    end
  end
  --mirror_image,if=buff.combustion.down&debuff.radiant_spark_vulnerability.down
  if S.MirrorImage:IsCastable() and HR.CDsON() and Settings.Fire.MirrorImagesBeforePull and Player:BuffDown(S.Combustion) and Target:DebuffStack(S.RadiantSparkVulnerability) == 0 then
    if HR.Cast(S.MirrorImage, Settings.Fire.GCDasOffGCD.MirrorImage) then return "mirror_image default 13"; end
  end
  --use_item,effect_name=gladiators_badge,if=variable.time_to_combustion>cooldown-5
  --use_item,name=empyreal_ordnance,if=variable.time_to_combustion<=variable.empyreal_ordnance_delay
  --use_item,name=glyph_of_assimilation,if=variable.time_to_combustion>=variable.on_use_cutoff
  --use_item,name=macabre_sheet_music,if=variable.time_to_combustion<=5
  --use_item,name=dreadfire_vessel,if=variable.time_to_combustion>=variable.on_use_cutoff&(buff.infernal_cascade.stack=2|!conduit.infernal_cascade|variable.combustion_on_use|variable.time_to_combustion+5>fight_remains%%cooldown)
  --use_item,name=soul_igniter,if=variable.time_to_combustion>=variable.on_use_cutoff+15*(variable.on_use_cutoff>0)&(!equipped.dreadfire_vessel|cooldown.dreadfire_vessel_344732.remains>5)
  --cancel_buff,name=soul_ignition,if=!conduit.infernal_cascade&time<5|buff.infernal_cascade.stack=buff.infernal_cascade.max_stack
  --TODO : manage trinkets
  --counterspell,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down&!buff.disciplinary_command.up&variable.time_to_combustion>25
  if S.Counterspell:IsCastable() and DisciplinaryCommandEquipped and Player:BuffDown(S.DisciplinaryCommandBuff) and Player:BuffDown(S.DisciplinaryCommandArcaneBuff) and S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer() > 30 and var_time_to_combustion > 25 then
    if HR.Cast(S.Counterspell) then return "counterspell default 21"; end
  end
  --arcane_explosion,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_arcane.down&!buff.disciplinary_command.up&variable.time_to_combustion>25
  if S.ArcaneExplosion:IsCastable() and DisciplinaryCommandEquipped and Player:BuffDown(S.DisciplinaryCommandBuff) and Player:BuffDown(S.DisciplinaryCommandArcaneBuff) and S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer() > 30 and var_time_to_combustion > 25 then
    if HR.Cast(S.ArcaneExplosion) then return "arcane_explosion default 22"; end
  end
  --frostbolt,if=runeforge.disciplinary_command&cooldown.buff_disciplinary_command.ready&buff.disciplinary_command_frost.down&!buff.disciplinary_command.up&variable.time_to_combustion>25
  if S.Frostbolt:IsCastable() and DisciplinaryCommandEquipped and S.DisciplinaryCommandBuff:TimeSinceLastAppliedOnPlayer() > 30 and Player:BuffDown(S.DisciplinaryCommandFrostBuff) and var_time_to_combustion > 25 then
    if HR.Cast(S.Frostbolt, nil, nil, not Target:IsSpellInRange(S.Frostbolt)) then return "frostbolt default 23"; end
  end
  --call_action_list,name=combustion_phase,if=!variable.disable_combustion&variable.time_to_combustion<=0
  if not var_disable_combustion and var_time_to_combustion <= 0 then
    local ShouldReturn = combustion_phase(); if ShouldReturn then return ShouldReturn; end
  end
  --variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=!variable.disable_combustion&variable.time_to_combustion-3<action.fire_blast.full_recharge_time-action.shifting_power.full_reduction*(cooldown.shifting_power.remains<variable.time_to_combustion)&variable.time_to_combustion<fight_remains
  --|talent.rune_of_power&buff.rune_of_power.down&cooldown.rune_of_power.remains<action.fire_blast.full_recharge_time-action.shifting_power.full_reduction*(cooldown.shifting_power.remains<cooldown.rune_of_power.remains)&cooldown.rune_of_power.remains<fight_remains
  if not var_disable_combustion and ((var_time_to_combustion - 3) < (S.FireBlast:FullRechargeTime() - S.ShiftingPower:FullReduction() * num(S.ShiftingPower:CooldownRemains() < var_time_to_combustion))) and HL.BossFilteredFightRemains(">", var_time_to_combustion)
  or (S.RuneofPower:IsAvailable() and Player:BuffDown(S.RuneofPowerBuff) and S.RuneofPower:CooldownRemains() < (S.FireBlast:FullRechargeTime() - S.ShiftingPower:FullReduction() * num(S.ShiftingPower:CooldownRemains() < S.RuneofPower:CooldownRemains())) and HL.BossFilteredFightRemains(">", S.RuneofPower:CooldownRemains())) then
    var_fire_blast_pooling = true
  else
    var_fire_blast_pooling = false
  end
  --variable,name=phoenix_pooling,value=!variable.disable_combustion&variable.time_to_combustion<action.phoenix_flames.full_recharge_time-action.shifting_power.full_reduction*(cooldown.shifting_power.remains<variable.time_to_combustion)&variable.time_to_combustion<fight_remains|runeforge.sun_kings_blessing|time<5
  if (not var_disable_combustion and var_time_to_combustion < (S.PhoenixFlames:FullRechargeTime() - S.ShiftingPower:FullReduction() * num(S.ShiftingPower:CooldownRemains() < var_time_to_combustion)) and HL.BossFilteredFightRemains(">", var_time_to_combustion)) or SunKingsBlessingEquipped or HL.CombatTime() < 5 then
    var_phoenix_pooling = true
  else
    var_phoenix_pooling = false
  end
  --rune_of_power,if=buff.rune_of_power.down&!buff.firestorm.react&(variable.time_to_combustion>=buff.rune_of_power.duration&variable.time_to_combustion>action.fire_blast.full_recharge_time|variable.time_to_combustion>fight_remains|variable.disable_combustion)
  if S.RuneofPower:IsCastable() and HR.CDsON() and Player:BuffDown(S.RuneofPowerBuff) and Player:BuffDown(S.FirestormBuff) and ((var_time_to_combustion >= S.RuneofPower:BaseDuration() and var_time_to_combustion > S.FireBlast:FullRechargeTime()) or HL.BossFilteredFightRemains("<", var_time_to_combustion) or var_disable_combustion) then
    if HR.Cast(S.RuneofPower, Settings.Fire.GCDasOffGCD.RuneOfPower) then return "rune_of_power default 27"; end
  end
  --call_action_list,name=rop_phase,if=buff.rune_of_power.up&(variable.time_to_combustion>0|variable.disable_combustion)
  if Player:BuffUp(S.RuneofPowerBuff) and (var_time_to_combustion > 0 or var_disable_combustion) then
    local ShouldReturn = rop_phase(); if ShouldReturn then return ShouldReturn; end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&(variable.time_to_combustion>0|variable.disable_combustion)&active_enemies>=variable.hard_cast_flamestrike
  --&!firestarter.active&!buff.hot_streak.react&(buff.heating_up.react&action.flamestrike.execute_remains<0.5|charges_fractional>=2)
  if S.FireBlast:IsCastable() and not var_fire_blast_pooling and (var_time_to_combustion > 0 or var_disable_combustion) and EnemiesCount16ySplash >= var_hard_cast_flamestrike 
  and not S.Firestarter:ActiveStatus() and Player:BuffDown(S.HotStreakBuff) and ((Player:BuffUp(S.HeatingUpBuff) and (Player:IsCasting(S.Flamestrike) and Player:CastRemains() < 0.5)) or S.FireBlast:ChargesFractional() >= 2) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast default 29 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast default 29"; end
    end
  end
  --fire_blast,use_off_gcd=1,use_while_casting=1,if=firestarter.active&charges>=1&!variable.fire_blast_pooling
  --&(!action.fireball.executing&!action.pyroblast.in_flight&buff.heating_up.react|action.fireball.executing&!buff.hot_streak.react|action.pyroblast.in_flight&buff.heating_up.react&!buff.hot_streak.react)
  if S.FireBlast:IsCastable() and S.Firestarter:ActiveStatus() and S.FireBlast:Charges() and not var_fire_blast_pooling 
  and ((not Player:IsCasting(S.Fireball) and not S.Pyroblast:InFlight() and Player:BuffUp(S.HeatingUpBuff)) or (Player:IsCasting(S.Fireball) and Player:BuffDown(S.HotStreakBuff)) or (S.Pyroblast:InFlight() and Player:BuffUp(S.HeatingUpBuff) and Player:BuffDown(S.HotStreakBuff))) then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast default 30 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast default 30"; end
    end
  end
  --fire_blast,use_while_casting=1,if=action.shifting_power.executing&full_recharge_time<action.shifting_power.tick_reduction&buff.hot_streak.down&time>10
  if S.FireBlast:IsCastable() and Player:IsCasting(S.ShiftingPower) and S.FireBlast:FullRechargeTime() < S.ShiftingPower:TickReduction() and Player:BuffDown(S.HotStreakBuff) and HL.CombatTime() > 10 then
    if Settings.Fire.ShowFireBlastLeft then
      if HR.CastLeft(S.FireBlast) then return "fire_blast default 31 left"; end
    else
      if HR.Cast(S.FireBlast) then return "fire_blast default 31"; end
    end
  end
  --call_action_list,name=standard_rotation,if=(variable.time_to_combustion>0|variable.disable_combustion)&buff.rune_of_power.down
  if (var_time_to_combustion > 0 or var_disable_combustion) and Player:BuffDown(S.RuneofPowerBuff) then
    local ShouldReturn = standard_rotation(); if ShouldReturn then return ShouldReturn; end
  end
  --scorch
  if S.Scorch:IsCastable() then
    if HR.Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch default 33"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  EnemiesCount8ySplash = Target:GetEnemiesInSplashRangeCount(8)
  EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  EnemiesCount16ySplash = Target:GetEnemiesInSplashRangeCount(16)
  Enemies10yMelee = Player:GetEnemiesInMeleeRange(10)
  EnemiesCount10yMelee = #Enemies10yMelee
  Enemies18yMelee = Player:GetEnemiesInMeleeRange(18)
  EnemiesCount18yMelee = #Enemies18yMelee

  UnitsWithIgniteCount = UnitsWithIgnite(Enemies8ySplash)

  if not var_init then
    VarInit()
  end
  --variable,name=disable_combustion,op=reset
  var_disable_combustion = not HR.CDsON()

  -- call precombat
  if not Player:AffectingCombat() and not Player:IsCasting() then
    local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
  end
  if Everyone.TargetIsValid() then
    local ShouldReturn = default(); if ShouldReturn then return ShouldReturn; end
  end
end

local function Init()

end

HR.SetAPL(63, APL, Init)
