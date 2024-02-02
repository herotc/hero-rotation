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
local FBCast, PBCast
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local max        = math.max
local ceil       = math.ceil
-- Commons
local Mage       = HR.Commons.Mage

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Mage.Fire
local I = Item.Mage.Fire

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- GladiatorsBadge
  I.CrimsonGladiatorsBadge:ID(),
  I.ObsidianGladiatorsBadge:ID(),
  I.VerdantGladiatorsBadge:ID(),
  -- Other Trinkets/Items
  I.AshesoftheEmbersoul:ID(),
  I.BalefireBranch:ID(),
  I.BelorrelostheSuncaller:ID(),
  I.Dreambinder:ID(),
  I.HornofValor:ID(),
  I.IridaltheEarthsMaster:ID(),
  I.IrideusFragment:ID(),
  I.MirrorofFracturedTomorrows:ID(),
  I.NymuesUnravelingSpindle:ID(),
  I.SpoilsofNeltharus:ID(),
  I.TimeThiefsGambit:ID(),
  I.TimebreachingTalon:ID(),
  I.TomeofUnstablePower:ID(),
  I.VoidmendersShadowgem:ID(),
}

-- GUI Settings
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  Fire = HR.GUISettings.APL.Mage.Fire
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- Variables from Precombat
-- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.irideus_fragment|equipped.erupting_spear_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor|equipped.mirror_of_fractured_tomorrows|equipped.ashes_of_the_embersoul|equipped.balefire_branch|equipped.time_theifs_gambit|equipped.nymues_unraveling_spindle
local var_steroid_trinket_equipped = I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.VerdantGladiatorsBadge:IsEquipped() or I.IrideusFragment:IsEquipped() or I.EruptingSpearFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.BalefireBranch:IsEquipped() or I.TimeThiefsGambit:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped()
-- variable,name=disable_combustion,op=reset
local var_disable_combustion = not CDsON()
-- variable,name=firestarter_combustion,default=-1,value=talent.sun_kings_blessing,if=variable.firestarter_combustion<0
local var_firestarter_combustion = S.SunKingsBlessing:IsAvailable()
-- variable,name=hot_streak_flamestrike,if=variable.hot_streak_flamestrike=0,value=4*talent.flame_patch+999*!talent.flame_patch
local var_hot_streak_flamestrike = (S.FlamePatch:IsAvailable()) and 4 or 999
-- variable,name=hard_cast_flamestrike,if=variable.hard_cast_flamestrike=0,value=999
local var_hard_cast_flamestrike = 999
-- variable,name=combustion_flamestrike,if=variable.combustion_flamestrike=0,value=4*talent.flame_patch+999*!talent.flame_patch
local var_combustion_flamestrike = var_hot_streak_flamestrike
-- variable,name=skb_flamestrike,if=variable.skb_flamestrike=0,value=3*talent.fuel_the_fire+999*!talent.fuel_the_fire
local var_skb_flamestrike = 3 * num(S.FueltheFire:IsAvailable()) + 999 * num(not S.FueltheFire:IsAvailable())
-- variable,name=arcane_explosion,if=variable.arcane_explosion=0,value=999
local var_arcane_explosion = 999
-- variable,name=arcane_explosion_mana,default=40,op=reset
local var_arcane_explosion_mana = 40
-- variable,name=combustion_shifting_power,if=variable.combustion_shifting_power=0,value=999
local var_combustion_shifting_power = 999
-- variable,name=combustion_cast_remains,default=0.3,op=reset
-- Note: Increased to 0.6 to give more player reaction time.
local var_combustion_cast_remains = 0.6
-- variable,name=overpool_fire_blasts,default=0,op=reset
local var_overpool_fire_blasts = 0
-- variable,name=skb_duration,value=dbc.effect.1016075.base_value
-- Note: This is the duration of Sun King's Blessing's free Combustion
local var_skb_duration = 6
-- variable,name=combustion_on_use,value=equipped.gladiators_badge|equipped.moonlit_prism|equipped.irideus_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor
local var_combustion_on_use = I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.MoonlitPrism:IsEquipped() or I.IrideusFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped()
-- variable,name=on_use_cutoff,value=20,if=variable.combustion_on_use
local var_on_use_cutoff = (var_combustion_on_use) and 20 or 0

-- Variables that need to be set later
-- variable,name=time_to_combustion,value=fight_remains+100,if=variable.disable_combustion
local var_time_to_combustion

-- Other variables used in the rotation
local var_kindling_reduction = (S.Kindling:IsAvailable()) and 0.4 or 1
local var_shifting_power_before_combustion = false
local var_item_cutoff_active = false
local var_phoenix_pooling = false
local var_fire_blast_pooling = false
local var_combustion_ready_time = 0
local var_combustion_precast_time = 0
local var_sun_kings_blessing_max_stack = 8
local var_improved_scorch_max_stack = 3
local CombustionUp
local CombustionDown
local CombustionRemains
local ShiftingPowerTickReduction = 3
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

-- Enemy variables
local EnemiesCount8ySplash,EnemiesCount10ySplash,EnemiesCount16ySplash
local EnemiesCount10yMelee,EnemiesCount18yMelee
local Enemies8ySplash,Enemies10yMelee,Enemies18yMelee
local UnitsWithIgniteCount

HL:RegisterForEvent(function()
  var_steroid_trinket_equipped = I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.VerdantGladiatorsBadge:IsEquipped() or I.IrideusFragment:IsEquipped() or I.EruptingSpearFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped() or I.MirrorofFracturedTomorrows:IsEquipped() or I.AshesoftheEmbersoul:IsEquipped() or I.BalefireBranch:IsEquipped() or I.TimeThiefsGambit:IsEquipped() or I.NymuesUnravelingSpindle:IsEquipped()
  var_combustion_on_use = I.CrimsonGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.MoonlitPrism:IsEquipped() or I.IrideusFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TomeofUnstablePower:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped()
  var_on_use_cutoff = (var_combustion_on_use) and 20 or 0
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  S.Pyroblast:RegisterInFlight()
  S.Fireball:RegisterInFlight()
  S.Meteor:RegisterInFlightEffect(351140)
  S.Meteor:RegisterInFlight()
  S.PhoenixFlames:RegisterInFlightEffect(257542)
  S.PhoenixFlames:RegisterInFlight()
  S.Pyroblast:RegisterInFlight(S.CombustionBuff)
  S.Fireball:RegisterInFlight(S.CombustionBuff)
end, "LEARNED_SPELL_IN_TAB")
S.Pyroblast:RegisterInFlight()
S.Fireball:RegisterInFlight()
S.Meteor:RegisterInFlightEffect(351140)
S.Meteor:RegisterInFlight()
S.PhoenixFlames:RegisterInFlightEffect(257542)
S.PhoenixFlames:RegisterInFlight()
S.Pyroblast:RegisterInFlight(S.CombustionBuff)
S.Fireball:RegisterInFlight(S.CombustionBuff)

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  var_firestarter_combustion = S.SunKingsBlessing:IsAvailable()
  var_hot_streak_flamestrike = (S.FlamePatch:IsAvailable()) and 3 or 999
  var_combustion_flamestrike = var_hot_streak_flamestrike
  var_kindling_reduction = (S.Kindling:IsAvailable()) and 0.4 or 1
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")

local function FirestarterActive()
  return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90))
end

local function FirestarterRemains()
  return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90) or 0) or 0
end

local function SearingTouchActive()
  return S.SearingTouch:IsAvailable() and Target:HealthPercentage() < 30
end

local function ImprovedScorchActive()
  return S.ImprovedScorch:IsAvailable() and Target:HealthPercentage() < 30
end

local function ShiftingPowerFullReduction()
  return ShiftingPowerTickReduction * S.ShiftingPower:BaseDuration() / S.ShiftingPower:BaseTickTime()
end

local function FreeCastAvailable()
  local FSInFlight = FirestarterActive() and (num(S.Pyroblast:InFlight()) + num(S.Fireball:InFlight())) or 0
  FSInFlight = FSInFlight + num(S.PhoenixFlames:InFlight() or Player:PrevGCDP(1, S.PhoenixFlames))
  return Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.HyperthermiaBuff) or (Player:BuffUp(S.HeatingUpBuff) and (ImprovedScorchActive() and Player:IsCasting(S.Scorch) or FirestarterActive() and (Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast) or FSInFlight > 0)))
end

local function UnitsWithIgnite(enemies)
  local WithIgnite = 0
  for _, CycleUnit in pairs(enemies) do
    if CycleUnit:DebuffUp(S.IgniteDebuff) then
      WithIgnite = WithIgnite + 1
    end
  end
  return WithIgnite
end

local function HotStreakInFlight()
  local total = 0
  if S.Fireball:InFlight() or S.PhoenixFlames:InFlight() then
    total = total + 1
  end
  return total
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
    if Cast(S.ArcaneIntellect, Settings.Commons.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- variable,name=steroid_trinket_equipped,op=set,value=equipped.gladiators_badge|equipped.irideus_fragment|equipped.erupting_spear_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor|equipped.mirror_of_fractured_tomorrows|equipped.ashes_of_the_embersoul|equipped.balefire_branch|equipped.time_theifs_gambit|equipped.nymues_unraveling_spindle
  -- variable,name=disable_combustion,op=reset
  -- Note: Moved to APL(), since the users may enable or disable CDsON at any time.
  -- variable,name=firestarter_combustion,default=-1,value=talent.sun_kings_blessing,if=variable.firestarter_combustion<0
  -- variable,name=hot_streak_flamestrike,if=variable.hot_streak_flamestrike=0,value=4*talent.flame_patch+999*!talent.flame_patch
  -- variable,name=hard_cast_flamestrike,if=variable.hard_cast_flamestrike=0,value=999
  -- variable,name=combustion_flamestrike,if=variable.combustion_flamestrike=0,value=4*talent.flame_patch+999*!talent.flame_patch
  -- variable,name=skb_flamestrike,if=variable.skb_flamestrike=0,value=3*talent.fuel_the_fire+999*!talent.fuel_the_fire
  -- variable,name=arcane_explosion,if=variable.arcane_explosion=0,value=999
  -- variable,name=arcane_explosion_mana,default=40,op=reset
  -- variable,name=combustion_shifting_power,if=variable.combustion_shifting_power=0,value=999
  -- variable,name=combustion_cast_remains,default=0.3,op=reset
  -- variable,name=overpool_fire_blasts,default=0,op=reset
  -- Note: Moved to initial declarations and SPELLS_CHANGED/LEARNED_SPELL_IN_TAB
  -- variable,name=time_to_combustion,value=fight_remains+100,if=variable.disable_combustion
  -- Note: Moved to APL(), since the users may enable or disable CDsON at any time.
  -- variable,name=skb_duration,value=dbc.effect.1016075.base_value
  -- Note: Moved to initial declarations and SPELLS_CHANGED/LEARNED_SPELL_IN_TAB
  -- variable,name=combustion_on_use,value=equipped.gladiators_badge|equipped.moonlit_prism|equipped.irideus_fragment|equipped.spoils_of_neltharus|equipped.tome_of_unstable_power|equipped.timebreaching_talon|equipped.horn_of_valor
  -- variable,name=on_use_cutoff,value=20,if=variable.combustion_on_use
  -- Note: Moved to initial declarations and PLAYER_EQUIPMENT_CHANGED
  -- snapshot_stats
  -- mirror_image
  if CDsON() and S.MirrorImage:IsCastable() and Settings.Fire.MirrorImagesBeforePull then
    if Cast(S.MirrorImage, Settings.Fire.GCDasOffGCD.MirrorImage) then return "mirror_image precombat 2"; end
  end
  -- flamestrike,if=active_enemies>=variable.hot_streak_flamestrike
  -- Note: Can't calculate enemies in Precombat
  -- pyroblast
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast precombat 4"; end
  end
  -- Manually added: fireball
  if S.Fireball:IsReady() then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball precombat 6"; end
  end
end

local function ActiveTalents()
  -- living_bomb,if=active_enemies>1&buff.combustion.down&(variable.time_to_combustion>cooldown.living_bomb.duration|variable.time_to_combustion<=0)
  if S.LivingBomb:IsReady() and (EnemiesCount10ySplash > 1 and CombustionDown and (var_time_to_combustion > S.LivingBomb:CooldownRemains() or var_time_to_combustion <= 0)) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb active_talents 2"; end
  end
  -- meteor,if=variable.time_to_combustion<=0|buff.combustion.remains>travel_time|!talent.sun_kings_blessing&(cooldown.meteor.duration<variable.time_to_combustion|fight_remains<variable.time_to_combustion)
  if S.Meteor:IsReady() and (var_time_to_combustion <= 0 or CombustionRemains > S.Meteor:TravelTime() or not S.SunKingsBlessing:IsAvailable() and (45 < var_time_to_combustion or FightRemains < var_time_to_combustion)) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor active_talents 4"; end
  end
  -- dragons_breath,if=talent.alexstraszas_fury&(buff.combustion.down&!buff.hot_streak.react)&(buff.feel_the_burn.up|time>15)&(!improved_scorch.active)&!firestarter.remains&!talent.tempered_flames
  if S.DragonsBreath:IsReady() and (S.AlexstraszasFury:IsAvailable() and (CombustionDown and Player:BuffDown(S.HotStreakBuff)) and (Player:BuffUp(S.FeeltheBurnBuff) or HL.CombatTime() > 15) and not ImprovedScorchActive() and FirestarterRemains() == 0 and not S.TemperedFlames:IsAvailable()) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath active_talents 6 left"; end
    else
      if Cast(S.DragonsBreath, Settings.Fire.GCDasOffGCD.DragonsBreath) then return "dragons_breath active_talents 6"; end
    end
  end
  -- dragons_breath,if=talent.alexstraszas_fury&(buff.combustion.down&!buff.hot_streak.react)&(buff.feel_the_burn.up|time>15)&(!improved_scorch.active)&talent.tempered_flames
  if S.DragonsBreath:IsReady() and (S.AlexstraszasFury:IsAvailable() and (CombustionDown and Player:BuffDown(S.HotStreakBuff)) and (Player:BuffUp(S.FeeltheBurnBuff) or HL.CombatTime() > 15) and not ImprovedScorchActive() and S.TemperedFlames:IsAvailable()) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath active_talents 8 left"; end
    else
      if Cast(S.DragonsBreath, Settings.Fire.GCDasOffGCD.DragonsBreath) then return "dragons_breath active_talents 8"; end
    end
  end
end

local function CombustionCooldowns()
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion combustion_cooldowns 2"; end
    end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.Commons.OffGCDasOffGCD.Racials) then return "blood_fury combustion_cooldowns 4"; end
  end
  -- berserking,if=buff.combustion.up
  if S.Berserking:IsCastable() and (CombustionUp) then
    if Cast(S.Berserking, Settings.Commons.OffGCDasOffGCD.Racials) then return "berserking combustion_cooldowns 6"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.Commons.OffGCDasOffGCD.Racials) then return "fireblood combustion_cooldowns 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.Commons.OffGCDasOffGCD.Racials) then return "ancestral_call combustion_cooldowns 10"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs
  -- time_warp,if=talent.temporal_warp&buff.exhaustion.up
  if S.TimeWarp:IsReady() and Settings.Commons.UseTemporalWarp and (S.TemporalWarp:IsAvailable() and Player:BloodlustExhaustUp()) then
    if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp combustion_cooldowns 12"; end
  end
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,effect_name=gladiators_badge
    if I.CrimsonGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.CrimsonGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (crimson) combustion_cooldowns 14"; end
    end
    if I.ObsidianGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.ObsidianGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (obsidian) combustion_cooldowns 16"; end
    end
    if I.VerdantGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.VerdantGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (verdant) combustion_cooldowns 18"; end
    end
    -- use_item,name=irideus_fragment
    if I.IrideusFragment:IsEquippedAndReady() then
      if Cast(I.IrideusFragment, nil, Settings.Commons.DisplayStyle.Trinkets) then return "irideus_fragment combustion_cooldowns 20"; end
    end
    -- use_item,name=spoils_of_neltharus
    if I.SpoilsofNeltharus:IsEquippedAndReady() then
      if Cast(I.SpoilsofNeltharus, nil, Settings.Commons.DisplayStyle.Trinkets) then return "spoils_of_neltharus combustion_cooldowns 22"; end
    end
    -- use_item,name=tome_of_unstable_power
    if I.TomeofUnstablePower:IsEquippedAndReady() then
      if Cast(I.TomeofUnstablePower, nil, Settings.Commons.DisplayStyle.Trinkets) then return "tome_of_unstable_power combustion_cooldowns 24"; end
    end
    -- use_item,name=timebreaching_talon
    if I.TimebreachingTalon:IsEquippedAndReady() then
      if Cast(I.TimebreachingTalon, nil, Settings.Commons.DisplayStyle.Trinkets) then return "timebreaching_talon combustion_cooldowns 26"; end
    end
    -- use_item,name=voidmenders_shadowgem
    if I.VoidmendersShadowgem:IsEquippedAndReady() then
      if Cast(I.VoidmendersShadowgem, nil, Settings.Commons.DisplayStyle.Trinkets) then return "voidmenders_shadowgem combustion_cooldowns 28"; end
    end
    -- use_item,name=horn_of_valor
    if I.HornofValor:IsEquippedAndReady() then
      if Cast(I.HornofValor, nil, Settings.Commons.DisplayStyle.Trinkets) then return "horn_of_valor combustion_cooldowns 30"; end
    end
    -- use_item,name=timethiefs_gambit
    if I.TimeThiefsGambit:IsEquippedAndReady() then
      if Cast(I.TimeThiefsGambit, nil, Settings.Commons.DisplayStyle.Trinkets) then return "time_theifs_gambit combustion_cooldowns 32"; end
    end
    -- use_item,name=balefire_branch
    if I.BalefireBranch:IsEquippedAndReady() then
      if Cast(I.BalefireBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "balefire_branch combustion_cooldowns 34"; end
    end
    -- use_item,name=ashes_of_the_embersoul
    if I.AshesoftheEmbersoul:IsEquippedAndReady() then
      if Cast(I.AshesoftheEmbersoul, nil, Settings.Commons.DisplayStyle.Trinkets) then return "ashes_of_the_embersoul combustion_cooldowns 36"; end
    end
    -- use_item,name=mirror_of_fractured_tomorrows
    if I.MirrorofFracturedTomorrows:IsEquippedAndReady() then
      if Cast(I.MirrorofFracturedTomorrows, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows combustion_cooldowns 38"; end
    end
  end
end

local function CombustionPhase()
  -- lights_judgment,if=buff.combustion.down
  if CDsON() and S.LightsJudgment:IsCastable() and (CombustionDown) then
    if Cast(S.LightsJudgment, Settings.Commons.OffGCDasOffGCD.Racials) then return "lights_judgment combustion_phase 2"; end
  end
  -- bag_of_tricks,if=buff.combustion.down
  if CDsON() and S.BagofTricks:IsCastable() and (CombustionDown) then
    if Cast(S.BagofTricks, Settings.Commons.OffGCDasOffGCD.Racials) then return "bag_of_tricks combustion_phase 4"; end
  end
  -- living_bomb,if=active_enemies>1&buff.combustion.down
  if S.LivingBomb:IsReady() and AoEON() and (EnemiesCount10ySplash > 1 and CombustionDown) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 6"; end
  end
  -- call_action_list,name=combustion_cooldowns,if=buff.combustion.remains>variable.skb_duration|fight_remains<20
  if CombustionRemains > var_skb_duration or FightRemains < 20 then
    local ShouldReturn = CombustionCooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  -- use_item,name=hyperthread_wristwraps,if=hyperthread_wristwraps.fire_blast>=2&action.fire_blast.charges=0
  -- use_item,name=neural_synapse_enhancer,if=variable.time_to_combustion>60
  -- Note: Not handling items from Mechagon...
  -- phoenix_flames,if=buff.combustion.down&set_bonus.tier30_2pc&!action.phoenix_flames.in_flight&debuff.charring_embers.remains<4*gcd.max&!buff.hot_streak.react
  if S.PhoenixFlames:IsCastable() and (Player:BuffDown(S.CombustionBuff) and Player:HasTier(30, 2) and not S.PhoenixFlames:InFlight() and Target:DebuffRemains(S.CharringEmbersDebuff) < 4 * GCDMax and Player:BuffDown(S.HotStreakBuff)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 8"; end
  end
  -- call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  -- combustion from below
  if S.Combustion:IsReady() and (HotStreakInFlight() == 0 and CombustionDown and var_time_to_combustion <= 0 and (Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Fireball) and S.Fireball:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Pyroblast) and S.Pyroblast:ExecuteRemains() < var_combustion_cast_remains or Player:IsCasting(S.Flamestrike) and S.Flamestrike:ExecuteRemains() < var_combustion_cast_remains or S.Meteor:InFlight() and S.Meteor:InFlightRemains() < var_combustion_cast_remains)) then
    if Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion combustion_phase 10"; end
  end
  -- flamestrike,if=buff.combustion.down&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&buff.fury_of_the_sun_king.expiration_delay_remains=0&cooldown.combustion.remains<cast_time&active_enemies>=variable.skb_flamestrike
  -- TODO: Handle expiration_delay_remains
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (CombustionDown and Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Flamestrike:CastTime() and S.Combustion:CooldownRemains() < S.Flamestrike:CastTime() and EnemiesCount8ySplash >= var_skb_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 12"; end
  end
  -- pyroblast,if=buff.combustion.down&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (CombustionDown and Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Pyroblast:CastTime()) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 14"; end
  end
  -- fireball,if=buff.combustion.down&cooldown.combustion.remains<cast_time&active_enemies<2&!improved_scorch.active
  if S.Fireball:IsReady() and (CombustionDown and S.Combustion:CooldownRemains() < S.Fireball:CastTime() and EnemiesCount8ySplash < 2 and not ImprovedScorchActive()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 16"; end
  end
  -- scorch,if=buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Scorch:IsReady() and (CombustionDown and S.Combustion:CooldownRemains() < S.Scorch:CastTime()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 18"; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=hot_streak_spells_in_flight=0&buff.combustion.down&variable.time_to_combustion<=0&(action.scorch.executing&action.scorch.execute_remains<variable.combustion_cast_remains|action.fireball.executing&action.fireball.execute_remains<variable.combustion_cast_remains|action.pyroblast.executing&action.pyroblast.execute_remains<variable.combustion_cast_remains|action.flamestrike.executing&action.flamestrike.execute_remains<variable.combustion_cast_remains|action.meteor.in_flight&action.meteor.in_flight_remains<variable.combustion_cast_remains)
  -- Note: Moved above the previous four lines, due to use_while_casting.
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&(!improved_scorch.active|action.scorch.executing|debuff.improved_scorch.remains>4*gcd.max)&(buff.fury_of_the_sun_king.down|action.pyroblast.executing)&buff.combustion.up&!buff.hyperthermia.react&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react*(gcd.remains>0)<2
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not var_fire_blast_pooling and (not ImprovedScorchActive() or Player:IsCasting(S.Scorch) or Target:DebuffRemains(S.ImprovedScorchDebuff) > 4 * GCDMax) and (Player:BuffDown(S.FuryoftheSunKingBuff) or Player:IsCasting(S.Pyroblast)) and CombustionUp and Player:BuffDown(S.HyperthermiaBuff) and Player:BuffDown(S.HotStreakBuff) and HotStreakInFlight() + num(Player:BuffUp(S.HeatingUpBuff)) * num(Player:GCDRemains() > 0) < 2) then
    if FBCast(S.FireBlast) then return "fire_blast combustion_phase 20"; end
  end
  -- flamestrike,if=(buff.hot_streak.react&active_enemies>=variable.combustion_flamestrike)|(buff.hyperthermia.react&active_enemies>=variable.combustion_flamestrike-talent.hyperthermia)
  if AoEON() and S.Flamestrike:IsReady() and ((Player:BuffUp(S.HotStreakBuff) and EnemiesCount8ySplash >= var_combustion_flamestrike) or (Player:BuffUp(S.HyperthermiaBuff) and EnemiesCount8ySplash >= var_combustion_flamestrike - num(S.Hyperthermia:IsAvailable()))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 22"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HyperthermiaBuff)) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 24"; end
  end
  -- pyroblast,if=buff.hot_streak.react&buff.combustion.up
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and CombustionUp) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 26"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies<variable.combustion_flamestrike&buff.combustion.up
  if S.Pyroblast:IsReady() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffUp(S.HeatingUpBuff) and EnemiesCount8ySplash < var_combustion_flamestrike and CombustionUp) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 28"; end
  end
  -- shifting_power,if=buff.combustion.up&!action.fire_blast.charges&(action.phoenix_flames.charges<action.phoenix_flames.max_charges|talent.alexstraszas_fury)&variable.combustion_shifting_power<=active_enemies
  if S.ShiftingPower:IsReady() and (CombustionUp and S.FireBlast:Charges() == 0 and (S.PhoenixFlames:Charges() < S.PhoenixFlames:MaxCharges() or S.AlexstraszasFury:IsAvailable()) and var_combustion_shifting_power <= EnemiesCount8ySplash) then
    if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power combustion_phase 30"; end
  end
  -- flamestrike,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&active_enemies>=variable.skb_flamestrike&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Flamestrike:CastTime() and EnemiesCount8ySplash >= var_skb_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 32"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Pyroblast:CastTime()) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 34"; end
  end
  -- scorch,if=improved_scorch.active&(debuff.improved_scorch.remains<4*gcd.max)&active_enemies<variable.combustion_flamestrike
  if S.Scorch:IsReady() and (ImprovedScorchActive() and (Target:DebuffRemains(S.ImprovedScorchDebuff) < 4 * GCDMax) and EnemiesCount16ySplash < var_combustion_flamestrike) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 36"; end
  end
  -- phoenix_flames,if=set_bonus.tier30_2pc&travel_time<buff.combustion.remains&buff.heating_up.react+hot_streak_spells_in_flight<2&(debuff.charring_embers.remains<4*gcd.max|buff.flames_fury.stack>1|buff.flames_fury.up)
  if S.PhoenixFlames:IsCastable() and (Player:HasTier(30, 2) and S.PhoenixFlames:TravelTime() < CombustionRemains and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() < 2 and (Target:DebuffRemains(S.CharringEmbersDebuff) < 4 * GCDMax or Player:BuffStack(S.FlamesFuryBuff) > 1 or Player:BuffUp(S.FlamesFuryBuff))) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 38"; end
  end
  -- fireball,if=buff.combustion.remains>cast_time&buff.flame_accelerant.react
  if S.Fireball:IsReady() and (CombustionRemains > S.Fireball:CastTime() and Player:BuffUp(S.FlameAccelerantBuff)) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 40"; end
  end
  -- phoenix_flames,if=!set_bonus.tier30_2pc&!talent.alexstraszas_fury&travel_time<buff.combustion.remains&buff.heating_up.react+hot_streak_spells_in_flight<2
  if S.PhoenixFlames:IsCastable() and (not Player:HasTier(30, 2) and not S.AlexstraszasFury:IsAvailable() and S.PhoenixFlames:TravelTime() < CombustionRemains and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() < 2) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 42"; end
  end
  -- scorch,if=buff.combustion.remains>cast_time&cast_time>=gcd.max
  if S.Scorch:IsReady() and (CombustionRemains > S.Scorch:CastTime() and S.Scorch:CastTime() >= GCDMax) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 44"; end
  end
  -- fireball,if=buff.combustion.remains>cast_time
  if S.Fireball:IsReady() and (CombustionRemains > S.Fireball:CastTime()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 46"; end
  end
  -- living_bomb,if=buff.combustion.remains<gcd.max&active_enemies>1
  if S.LivingBomb:IsReady() and (CombustionRemains < GCDMax and EnemiesCount10ySplash > 1) then
    if Cast(S.LivingBomb, nil, nil, not Target:IsSpellInRange(S.LivingBomb)) then return "living_bomb combustion_phase 48"; end
  end
end

local function CombustionTiming()
  -- variable,use_off_gcd=1,use_while_casting=1,name=combustion_ready_time,value=cooldown.combustion.remains*expected_kindling_reduction
  var_combustion_ready_time = S.Combustion:CooldownRemains() * var_kindling_reduction
  -- variable,use_off_gcd=1,use_while_casting=1,name=combustion_precast_time,value=action.fireball.cast_time*(active_enemies<variable.combustion_flamestrike)+action.flamestrike.cast_time*(active_enemies>=variable.combustion_flamestrike)-variable.combustion_cast_remains
  var_combustion_precast_time = S.Fireball:CastTime() * num(EnemiesCount8ySplash < var_combustion_flamestrike) + S.Flamestrike:CastTime() * num(EnemiesCount8ySplash >= var_combustion_flamestrike) - var_combustion_cast_remains
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=variable.combustion_ready_time
  var_time_to_combustion = var_combustion_ready_time
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=firestarter.remains,if=talent.firestarter&!variable.firestarter_combustion
  if S.Firestarter:IsAvailable() and not var_firestarter_combustion then
    var_time_to_combustion = max(FirestarterRemains(), var_time_to_combustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=(buff.sun_kings_blessing.max_stack-buff.sun_kings_blessing.stack)*(3*gcd.max),if=talent.sun_kings_blessing&firestarter.active&buff.fury_of_the_sun_king.down
  if S.SunKingsBlessing:IsAvailable() and FirestarterActive() and Player:BuffDown(S.FuryoftheSunKingBuff) then
    var_time_to_combustion = max(((var_sun_kings_blessing_max_stack - Player:BuffStack(S.SunKingsBlessingBuff)) * (3 * GCDMax)), var_time_to_combustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=cooldown.gladiators_badge_345228.remains,if=equipped.gladiators_badge&cooldown.gladiators_badge_345228.remains-20<variable.time_to_combustion
  if I.CrimsonGladiatorsBadge:IsEquipped() and I.CrimsonGladiatorsBadge:CooldownRemains() - 20 < var_time_to_combustion then
    var_time_to_combustion = max(I.CrimsonGladiatorsBadge:CooldownRemains(), var_time_to_combustion)
  end
  if I.ObsidianGladiatorsBadge:IsEquipped() and I.ObsidianGladiatorsBadge:CooldownRemains() - 20 < var_time_to_combustion then
    var_time_to_combustion = max(I.ObsidianGladiatorsBadge:CooldownRemains(), var_time_to_combustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=buff.combustion.remains
  var_time_to_combustion = max(CombustionRemains, var_time_to_combustion)
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=raid_event.adds.in,if=raid_event.adds.exists&raid_event.adds.count>=3&raid_event.adds.duration>15
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=raid_event.vulnerable.in*!raid_event.vulnerable.up,if=raid_event.vulnerable.exists&variable.combustion_ready_time<raid_event.vulnerable.in
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=variable.combustion_ready_time,if=variable.combustion_ready_time+cooldown.combustion.duration*(1-(0.4+0.2*talent.firestarter)*talent.kindling)<=variable.time_to_combustion|variable.time_to_combustion>fight_remains-20
  if var_combustion_ready_time + 120 * (1 - (0.4 + 0.2 * num(S.Firestarter:IsAvailable())) * num(S.Kindling:IsAvailable())) <= var_time_to_combustion or var_time_to_combustion > FightRemains - 20 then
    var_time_to_combustion = var_combustion_ready_time
  end
end

local function FirestarterFireBlasts()
  -- fire_blast,use_while_casting=1,if=!variable.fire_blast_pooling&!buff.hot_streak.react&(action.fireball.execute_remains>gcd.remains|action.pyroblast.executing)&buff.heating_up.react+hot_streak_spells_in_flight=1&(cooldown.shifting_power.ready|charges>1|buff.feel_the_burn.remains<2*gcd.max)
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not var_fire_blast_pooling and Player:BuffDown(S.HotStreakBuff) and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() == 1 and (S.ShiftingPower:CooldownUp() or S.FireBlast:Charges() > 1 or Player:BuffRemains(S.FeeltheBurnBuff) < 2 * GCDMax)) then
    if FBCast(S.FireBlast) then return "fire_blast firestarter_fire_blasts 2"; end
  end
  -- fire_blast,use_off_gcd=1,if=!variable.fire_blast_pooling&buff.heating_up.react+hot_streak_spells_in_flight=1&(talent.feel_the_burn&buff.feel_the_burn.remains<gcd.remains|cooldown.shifting_power.ready&(!set_bonus.tier30_2pc|debuff.charring_embers.remains>2*gcd.max))
  -- Note: Added check to not cast Fire Blast when HotStreakBuff is active.
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not var_fire_blast_pooling and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() == 1 and (S.ShiftingPower:CooldownUp() and (not Player:HasTier(30, 2) or Target:DebuffRemains(S.CharringEmbersDebuff) > 2 * GCDMax))) then
    if FBCast(S.FireBlast) then return "fire_blast firestarter_fire_blasts 4"; end
  end
end

local function StandardRotation()
  -- flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.hyperthermia.react)
  if AoEON() and S.Flamestrike:IsReady() and (EnemiesCount8ySplash >= var_hot_streak_flamestrike and FreeCastAvailable()) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 2"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  -- pyroblast,if=buff.hot_streak.react&(buff.hot_streak.remains<action.fireball.execute_time)
  -- pyroblast,if=buff.hot_streak.react&(hot_streak_spells_in_flight|firestarter.active|talent.alexstraszas_fury&action.phoenix_flames.charges)
  -- pyroblast,if=buff.hot_streak.react&searing_touch.active
  -- Note: Combining free Pyroblast lines
  if S.Pyroblast:IsReady() and (FreeCastAvailable()) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 4"; end
  end
  -- flamestrike,if=active_enemies>=variable.skb_flamestrike&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.expiration_delay_remains=0"
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (EnemiesCount8ySplash >= var_skb_flamestrike and Player:BuffUp(S.FuryoftheSunKingBuff)) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 12"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.remains<action.pyroblast.cast_time+5*gcd.max&buff.fury_of_the_sun_king.up&!action.scorch.in_flight
  -- Note: Using IsCasting check for !action.scorch.in_flight, since Scorch is an instant hit ability with no travel time.
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffRemains(S.ImprovedScorchDebuff) < S.Pyroblast:CastTime() + 5 * GCDMax and Player:BuffUp(S.FuryoftheSunKingBuff) and not Player:IsCasting(S.Scorch)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 13"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (Player:BuffUp(S.FuryoftheSunKingBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 14"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!firestarter.active&!variable.fire_blast_pooling&buff.fury_of_the_sun_king.down&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!talent.hyperthermia)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5|!talent.hyperthermia))&buff.heating_up.react)|(searing_touch.active&(!improved_scorch.active|debuff.improved_scorch.stack=debuff.improved_scorch.max_stack|full_recharge_time<3)&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not FirestarterActive() and not var_fire_blast_pooling and Player:BuffDown(S.FuryoftheSunKingBuff) and (((Player:IsCasting(S.Fireball) and (S.Fireball:ExecuteRemains() < 0.5 or not S.Hyperthermia:IsAvailable()) or Player:IsCasting(S.Pyroblast) and (S.Pyroblast:ExecuteRemains() < 0.5 or not S.Hyperthermia:IsAvailable())) and Player:BuffUp(S.HeatingUpBuff)) or (SearingTouchActive() and (not ImprovedScorchActive() or Target:DebuffStack(S.ImprovedScorchDebuff) == var_improved_scorch_max_stack or S.FireBlast:FullRechargeTime() < 3) and (Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and HotStreakInFlight() == 0)))) then
    if FBCast(S.FireBlast) then return "fire_blast standard_rotation 16"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&searing_touch.active&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsReady() and ((Player:IsCasting(S.Scorch) or Player:PrevGCDP(1, S.Scorch)) and Player:BuffUp(S.HeatingUpBuff) and SearingTouchActive() and EnemiesCount8ySplash < var_hot_streak_flamestrike) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 18"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.remains<4*gcd.max
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffRemains(S.ImprovedScorchDebuff) < 4 * GCDMax) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 19"; end
  end
  -- phoenix_flames,if=talent.alexstraszas_fury&(!talent.feel_the_burn|buff.feel_the_burn.remains<2*gcd.max)
  if S.PhoenixFlames:IsCastable() and (S.AlexstraszasFury:IsAvailable() and (not S.FeeltheBurn:IsAvailable() or Player:BuffRemains(S.FeeltheBurnBuff) < 2 * GCDMax)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 20"; end
  end
  -- phoenix_flames,if=set_bonus.tier30_2pc&debuff.charring_embers.remains<2*gcd.max&!buff.hot_streak.react
  if S.PhoenixFlames:IsCastable() and (Player:HasTier(30, 2) and Target:DebuffRemains(S.CharringEmbersDebuff) < 2 * GCDMax and Player:BuffDown(S.HotStreakBuff)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 21"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.stack<debuff.improved_scorch.max_stack
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffStack(S.ImprovedScorchDebuff) < var_improved_scorch_max_stack) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 22"; end
  end
  -- phoenix_flames,if=!talent.alexstraszas_fury&!buff.hot_streak.react&!variable.phoenix_pooling&buff.flames_fury.up
  if S.PhoenixFlames:IsCastable() and (not S.AlexstraszasFury:IsAvailable() and Player:BuffDown(S.HotStreakBuff) and not var_phoenix_pooling and Player:BuffUp(S.FlamesFuryBuff)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 24"; end
  end
  -- phoenix_flames,if=talent.alexstraszas_fury&!buff.hot_streak.react&hot_streak_spells_in_flight=0&(!variable.phoenix_pooling&buff.flames_fury.up|charges_fractional>2.5|charges_fractional>1.5&(!talent.feel_the_burn|buff.feel_the_burn.remains<3*gcd.max))
  if S.PhoenixFlames:IsCastable() and (S.AlexstraszasFury:IsAvailable() and Player:BuffDown(S.HotStreakBuff) and HotStreakInFlight() == 0 and (not var_phoenix_pooling and Player:BuffUp(S.FlamesFuryBuff) or S.PhoenixFlames:ChargesFractional() > 2.5 or S.PhoenixFlames:ChargesFractional() > 1.5 and (not S.FeeltheBurn:IsAvailable() or Player:BuffRemains(S.FeeltheBurnBuff) < 3 * GCDMax))) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 26"; end
  end
  -- call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  -- dragons_breath,if=active_enemies>1&talent.alexstraszas_fury
  if AoEON() and S.DragonsBreath:IsReady() and (EnemiesCount16ySplash > 1 and S.AlexstraszasFury:IsAvailable()) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath standard_rotation 28 left"; end
    else
      if Cast(S.DragonsBreath, Settings.Fire.GCDasOffGCD.DragonsBreath) then return "dragons_breath standard_rotation 28"; end
    end
  end
  -- scorch,if=searing_touch.active
  if S.Scorch:IsReady() and (SearingTouchActive()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 30"; end
  end
  -- arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if AoEON() and S.ArcaneExplosion:IsReady() and (EnemiesCount10yMelee >= var_arcane_explosion and Player:ManaPercentageP() >= var_arcane_explosion_mana) then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 32 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 32"; end
    end
  end
  -- flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if AoEON() and S.Flamestrike:IsReady() and (EnemiesCount8ySplash >= var_hard_cast_flamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 34"; end
  end
  -- pyroblast,if=talent.tempered_flames&!buff.flame_accelerant.react
  if S.Pyroblast:IsReady() and (S.TemperedFlames:IsAvailable() and Player:BuffDown(S.FlameAccelerantBuff)) then
    if Cast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 35"; end
  end
  -- fireball
  if S.Fireball:IsReady() and (not FreeCastAvailable()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball standard_rotation 36"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  -- Check which cast style we should use for Fire Blast/Pyroblast
  if Settings.Fire.ShowFireBlastLeft then
    FBCast = CastLeft
  else
    FBCast = Cast
  end
  if Settings.Fire.ShowPyroblastLeft then
    PBCast = CastLeft
  else
    PBCast = Cast
  end

  -- Update our enemy tables
  Enemies8ySplash = Target:GetEnemiesInSplashRange(8)
  Enemies16ySplash = Target:GetEnemiesInSplashRange(16)
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

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies8ySplash, false)
    end

    -- Check how many units have ignite
    UnitsWithIgniteCount = UnitsWithIgnite(Enemies8ySplash)

    --  variable,name=disable_combustion,op=reset (from Precombat)
    var_disable_combustion = not CDsON()

    -- variable,name=time_to_combustion,value=fight_remains+100,if=variable.disable_combustion (from Precombat)
    if var_disable_combustion then
      var_time_to_combustion = 99999
    end

    -- Define gcd.max
    GCDMax = Player:GCD() + 0.25

    -- Get our Combustion status
    CombustionUp = Player:BuffUp(S.CombustionBuff)
    CombustionDown = not CombustionUp
    CombustionRemains = (CombustionUp) and Player:BuffRemains(S.CombustionBuff) or 0
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.Commons.OffGCDasOffGCD.Counterspell, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Scorch sniping
    if Settings.Fire.UseScorchSniping and S.SearingTouch:IsAvailable() and AoEON() and Target:HealthPercentage() > 30 then
      for _, CycleUnit in pairs(Enemies16ySplash) do
        if CycleUnit:Exists() and CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsDeadOrGhost() and CycleUnit:HealthPercentage() < 30 and CycleUnit:IsSpellInRange(S.Scorch) then
          if HR.CastLeftNameplate(CycleUnit, S.Scorch) then return "Scorch Sniping on "..CycleUnit:Name(); end
        end
      end
    end
    -- call_action_list,name=combustion_timing,if=!variable.disable_combustion
    if not var_disable_combustion then
      CombustionTiming()
    end
    -- time_warp,if=buff.exhaustion.up&talent.temporal_warp&(firestarter.active|interpolated_fight_remains<buff.bloodlust.duration)
    if CDsON() and S.TimeWarp:IsReady() and Settings.Commons.UseTemporalWarp and (Player:BloodlustExhaustUp() and S.TemporalWarp:IsAvailable() and (FirestarterActive() or FightRemains < 40)) then
      if Cast(S.TimeWarp, Settings.Commons.OffGCDasOffGCD.TimeWarp) then return "time_warp main 2"; end
    end
    -- potion,if=buff.potion.duration>variable.time_to_combustion+buff.combustion.duration
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() and (PotionSelected:BuffDuration() > var_time_to_combustion + 12) then
        if Cast(PotionSelected, nil, Settings.Commons.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    -- variable,name=shifting_power_before_combustion,value=variable.time_to_combustion>cooldown.shifting_power.remains
    var_shifting_power_before_combustion = var_time_to_combustion > S.ShiftingPower:CooldownRemains()
    if Settings.Commons.Enabled.Trinkets then
      -- variable,name=item_cutoff_active,value=(variable.time_to_combustion<variable.on_use_cutoff|buff.combustion.remains>variable.skb_duration&!cooldown.item_cd_1141.remains)&((trinket.1.has_cooldown&trinket.1.cooldown.remains<variable.on_use_cutoff)+(trinket.2.has_cooldown&trinket.2.cooldown.remains<variable.on_use_cutoff)>1)
      var_item_cutoff_active = (var_time_to_combustion < var_on_use_cutoff or CombustionRemains > var_skb_duration and (I.DragonfireBombDispenser:CooldownUp() or not I.DragonfireBombDispenser:IsEquipped())) and (num(Trinket1:Cooldown() > 0 and Trinket1:CooldownRemains() < var_on_use_cutoff) + num(Trinket2:Cooldown() and Trinket2:CooldownRemains() < var_on_use_cutoff) > 1)
      -- use_item,effect_name=gladiators_badge,if=variable.time_to_combustion>cooldown-5
      if I.CrimsonGladiatorsBadge:IsEquippedAndReady() and (var_time_to_combustion > I.CrimsonGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.CrimsonGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (crimson) main 6"; end
      end
      if I.ObsidianGladiatorsBadge:IsEquippedAndReady() and (var_time_to_combustion > I.ObsidianGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.ObsidianGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (obsidian) main 8"; end
      end
      if I.VerdantGladiatorsBadge:IsEquippedAndReady() and (var_time_to_combustion > I.VerdantGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.VerdantGladiatorsBadge, nil, Settings.Commons.DisplayStyle.Trinkets) then return "gladiators_badge (verdant) main 10"; end
      end
      -- use_item,name=mirror_of_fractured_tomorrows,if=buff.combustion.up&buff.combustion.remains>11
      if I.MirrorofFracturedTomorrows:IsEquippedAndReady() and (CombustionUp and CombustionRemains > 11) then
        if Cast(I.MirrorofFracturedTomorrows, nil, Settings.Commons.DisplayStyle.Trinkets) then return "mirror_of_fractured_tomorrows main 12"; end
      end
      -- use_item,name=timethiefs_gambit,if=buff.combustion.up
      if I.TimeThiefsGambit:IsEquippedAndReady() and (CombustionUp) then
        if Cast(I.TimeThiefsGambit, nil, Settings.Commons.DisplayStyle.Trinkets) then return "time_theifs_gambit main 14"; end
      end
      -- use_item,name=balefire_branch,if=(variable.time_to_combustion<=3&buff.fury_of_the_sun_king.up)|(buff.combustion.up&buff.combustion.remains>11)
      if I.BalefireBranch:IsEquippedAndReady() and ((var_time_to_combustion <= 3 and Player:BuffUp(S.FuryoftheSunKingBuff)) or (CombustionUp and CombustionRemains > 11)) then
        if Cast(I.BalefireBranch, nil, Settings.Commons.DisplayStyle.Trinkets) then return "balefire_branch main 16"; end
      end
      -- use_item,name=ashes_of_the_embersoul,if=(variable.time_to_combustion<=3&buff.fury_of_the_sun_king.up)|(buff.combustion.up&buff.combustion.remains>11)
      if I.AshesoftheEmbersoul:IsEquippedAndReady() and ((var_time_to_combustion <= 3 and Player:BuffUp(S.FuryoftheSunKingBuff)) or (CombustionUp and CombustionRemains > 11)) then
        if Cast(I.AshesoftheEmbersoul, nil, Settings.Commons.DisplayStyle.Trinkets) then return "ashes_of_the_embersoul main 18"; end
      end
      -- use_item,name=nymues_unraveling_spindle,if=variable.time_to_combustion<=9
      if I.NymuesUnravelingSpindle:IsEquippedAndReady() and (var_time_to_combustion <= 9) then
        if Cast(I.NymuesUnravelingSpindle, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(45)) then return "nymues_unraveling_spindle main 20"; end
      end
    end
    -- use_item,name=dreambinder_loom_of_the_great_cycle
    if Settings.Commons.Enabled.Items and I.Dreambinder:IsEquippedAndReady() then
      if Cast(I.Dreambinder, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(45)) then return "dreambinder main 22"; end
    end
    -- use_item,name=iridal_the_earths_master,use_off_gcd=1,slot=main_hand,if=gcd.remains>=0.6*gcd.max
    if Settings.Commons.Enabled.Items and I.IridaltheEarthsMaster:IsEquippedAndReady() then
      if Cast(I.IridaltheEarthsMaster, nil, Settings.Commons.DisplayStyle.Items, not Target:IsInRange(40)) then return "iridal_the_earths_master main 23"; end
    end
    -- use_item,name=belorrelos_the_suncaller,if=(!variable.steroid_trinket_equipped&buff.combustion.down)|(variable.steroid_trinket_equipped&trinket.1.has_cooldown&trinket.1.cooldown.remains>20&buff.combustion.down)|(variable.steroid_trinket_equipped&trinket.2.has_cooldown&trinket.2.cooldown.remains>20&buff.combustion.down)
    if Settings.Commons.Enabled.Trinkets and I.BelorrelostheSuncaller:IsEquippedAndReady() and ((not var_steroid_trinket_equipped and CombustionDown) or (var_steroid_trinket_equipped and Trinket1:HasCooldown() and Trinket1:CooldownRemains() > 20 and CombustionDown) or (var_steroid_trinket_equipped and Trinket2:HasCooldown() and Trinket2:CooldownRemains() > 20 and CombustionDown)) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.Commons.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller main 24"; end
    end
    -- use_items,if=!variable.item_cutoff_active
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and not var_item_cutoff_active then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.Commons.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.Commons.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~=13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name(); end
        end
      end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=buff.combustion.down&action.fire_blast.charges_fractional+(variable.time_to_combustion+action.shifting_power.full_reduction*variable.shifting_power_before_combustion)%cooldown.fire_blast.duration-1<cooldown.fire_blast.max_charges+variable.overpool_fire_blasts%cooldown.fire_blast.duration-(buff.combustion.duration%cooldown.fire_blast.duration)%%1&variable.time_to_combustion<fight_remains
    var_fire_blast_pooling = CombustionDown and S.FireBlast:ChargesFractional() + (var_time_to_combustion + ShiftingPowerFullReduction() * num(var_shifting_power_before_combustion)) / S.FireBlast:Cooldown() - 1 < S.FireBlast:MaxCharges() + var_overpool_fire_blasts / S.FireBlast:Cooldown() - (12 / S.FireBlast:Cooldown()) % 1 and var_time_to_combustion < FightRemains
    -- call_action_list,name=combustion_phase,if=variable.time_to_combustion<=0|buff.combustion.up|variable.time_to_combustion<variable.combustion_precast_time&cooldown.combustion.remains<variable.combustion_precast_time
    if not var_disable_combustion and (var_time_to_combustion <= 0 or CombustionUp or var_time_to_combustion < var_combustion_precast_time and S.Combustion:CooldownRemains() < var_combustion_precast_time) then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=searing_touch.active&action.fire_blast.full_recharge_time>3*gcd.max,if=!variable.fire_blast_pooling&talent.sun_kings_blessing
    if not var_fire_blast_pooling and S.SunKingsBlessing:IsAvailable() then
      var_fire_blast_pooling = SearingTouchActive() and S.FireBlast:FullRechargeTime() > 3 * GCDMax
    end
    -- shifting_power,if=buff.combustion.down&(action.fire_blast.charges=0|variable.fire_blast_pooling)&(!improved_scorch.active|debuff.improved_scorch.remains>cast_time+action.scorch.cast_time&!buff.fury_of_the_sun_king.up)&!buff.hot_streak.react&variable.shifting_power_before_combustion
    if S.ShiftingPower:IsReady() and (CombustionDown and (S.FireBlast:Charges() == 0 or var_fire_blast_pooling) and (not ImprovedScorchActive() or Target:DebuffRemains(S.ImprovedScorchDebuff) > S.ShiftingPower:CastTime() + S.Scorch:CastTime() and Player:BuffDown(S.FuryoftheSunKingBuff)) and Player:BuffDown(S.HotStreakBuff) and var_shifting_power_before_combustion) then
      if Cast(S.ShiftingPower, nil, Settings.Commons.DisplayStyle.Signature, not Target:IsInRange(18)) then return "shifting_power main 26"; end
    end
    -- variable,name=phoenix_pooling,if=active_enemies<variable.combustion_flamestrike,value=(variable.time_to_combustion+buff.combustion.duration-5<action.phoenix_flames.full_recharge_time+cooldown.phoenix_flames.duration-action.shifting_power.full_reduction*variable.shifting_power_before_combustion&variable.time_to_combustion<fight_remains|talent.sun_kings_blessing)&!talent.alexstraszas_fury
    -- Note: Swapped SunKingsBlessing check to the front so we can avoid lots of math if it's talented.
    if EnemiesCount8ySplash < var_combustion_flamestrike then
      var_phoenix_pooling = (S.SunKingsBlessing:IsAvailable() or var_time_to_combustion + 7 < S.PhoenixFlames:FullRechargeTime() + S.PhoenixFlames:Cooldown() - ShiftingPowerFullReduction() * num(var_shifting_power_before_combustion) and var_time_to_combustion < FightRemains) and not S.AlexstraszasFury:IsAvailable()
    end
    -- variable,name=phoenix_pooling,if=active_enemies>=variable.combustion_flamestrike,value=(variable.time_to_combustion<action.phoenix_flames.full_recharge_time-action.shifting_power.full_reduction*variable.shifting_power_before_combustion&variable.time_to_combustion<fight_remains|talent.sun_kings_blessing)&!talent.alexstraszas_fury
    -- Note: Swapped SunKingsBlessing check to the front so we can avoid lots of math if it's talented.
    if EnemiesCount8ySplash >= var_combustion_flamestrike then
      var_phoenix_pooling = (S.SunKingsBlessing:IsAvailable() or var_time_to_combustion < S.PhoenixFlames:FullRechargeTime() - ShiftingPowerFullReduction() * num(var_shifting_power_before_combustion) and var_time_to_combustion < FightRemains) and not S.AlexstraszasFury:IsAvailable()
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&variable.time_to_combustion>0&active_enemies>=variable.hard_cast_flamestrike&!firestarter.active&!buff.hot_streak.react&(buff.heating_up.react&action.flamestrike.execute_remains<0.5|charges_fractional>=2)
    if S.FireBlast:IsReady() and not FreeCastAvailable() and (not var_fire_blast_pooling and var_time_to_combustion > 0 and EnemiesCount8ySplash >= var_hard_cast_flamestrike and not FirestarterActive() and Player:BuffDown(S.HotStreakBuff) and (Player:BuffUp(S.HeatingUpBuff) and S.Flamestrike:ExecuteRemains() < 0.5 or S.FireBlast:ChargesFractional() >= 2)) then
      if FBCast(S.FireBlast) then return "fire_blast main 28"; end
    end
    -- call_action_list,name=firestarter_fire_blasts,if=buff.combustion.down&firestarter.active&variable.time_to_combustion>0
    if CombustionDown and FirestarterActive() and var_time_to_combustion > 0 then
      local ShouldReturn = FirestarterFireBlasts(); if ShouldReturn then return ShouldReturn; end
    end
    -- fire_blast,use_while_casting=1,if=action.shifting_power.executing&full_recharge_time<action.shifting_power.tick_reduction
    if S.FireBlast:IsReady() and not FreeCastAvailable() and (Player:IsCasting(S.ShiftingPower) and S.FireBlast:FullRechargeTime() < ShiftingPowerTickReduction) then
      if FBCast(S.FireBlast) then return "fire_blast main 30"; end
    end
    -- call_action_list,name=standard_rotation,if=variable.time_to_combustion>0&buff.combustion.down
    if var_time_to_combustion > 0 and CombustionDown then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
    -- ice_nova,if=!searing_touch.active
    if S.IceNova:IsCastable() and (not SearingTouchActive()) then
      if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova main 32"; end
    end
    -- scorch
    if S.Scorch:IsReady() then
      if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch main 34"; end
    end
  end
end

local function Init()
  HR.Print("Fire Mage rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(63, APL, Init)
