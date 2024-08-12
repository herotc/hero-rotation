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
  -- TWW GladiatorsBadge
  I.ForgedGladiatorsBadge:ID(),
  -- DF GladiatorsBadge
  I.CrimsonGladiatorsBadge:ID(),
  I.DraconicGladiatorsBadge:ID(),
  I.ObsidianGladiatorsBadge:ID(),
  I.VerdantGladiatorsBadge:ID(),
  -- Other TWW Trinkets
  I.ImperfectAscendancySerum:ID(),
  I.SpymastersWeb:ID(),
  I.TreacherousTransmitter:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Mage.Commons,
  CommonsDS = HR.GUISettings.APL.Mage.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Mage.CommonsOGCD,
  Fire = HR.GUISettings.APL.Mage.Fire
}

--- ===== Rotation Variables =====
local VarKindlingReduction = (S.Kindling:IsAvailable()) and 0.4 or 1
local VarSKBMaxStack = 10
local VarImprovedScorchMaxStack = 2
local VarFirestarterCombusion = false
local VarHotStreakFlamestrike = 0
local VarHardCastFlamestrike = 0
local VarSKBFlamestrike = 0
local VarArcaneExplosion = 0
local VarArcaneExplosionMana = 40
local VarCombustionShiftingPower = 0
local VarCombustionCastRemains = 0.3
local VarOverpoolFireBlasts = 0
local VarSKBDuration = 6
local VarOnUseCutoff = 20
local VarCombustionOnUse = false
local VarShiftingPowerBeforeCombustion = false
local VarItemCutoffActive = false
local VarFireBlastPooling, VarPhoenixPooling = false, false
local VarCombustionReadyTime, VarCombustionPrecastTime = 0, 0
local VarTimeToCombustion = 0
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1BL, VarTrinket2BL
local VarTrinket1Range, VarTrinket2Range
local CombustionUp
local CombustionDown
local CombustionRemains
local ShiftingPowerTickReduction = 3
local EnemiesCount8ySplash,EnemiesCount10ySplash,EnemiesCount16ySplash
local EnemiesCount10yMelee,EnemiesCount18yMelee
local Enemies8ySplash,Enemies10yMelee,Enemies18yMelee
local UnitsWithIgniteCount
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

--- ===== Trinket Variables =====
local function SetTrinketVariables()
  Trinket1, Trinket2 = Player:GetTrinketItems()
  VarTrinket1ID = Trinket1:ID()
  VarTrinket2ID = Trinket2:ID()

  -- If we don't have trinket items, try again in 2 seconds.
  if VarTrinket1ID == 0 or VarTrinket2ID == 0 then
    Delay(2, function()
        Trinket1, Trinket2 = Player:GetTrinketItems()
        VarTrinket1ID = Trinket1:ID()
        VarTrinket2ID = Trinket2:ID()
      end
    )
  end

  local Trinket1Spell = Trinket1:OnUseSpell()
  VarTrinket1Range = (Trinket1Spell and Trinket1Spell.MaximumRange > 0 and Trinket1Spell.MaximumRange <= 100) and Trinket1Spell.MaximumRange or 100
  local Trinket2Spell = Trinket2:OnUseSpell()
  VarTrinket2Range = (Trinket2Spell and Trinket2Spell.MaximumRange > 0 and Trinket2Spell.MaximumRange <= 100) and Trinket2Spell.MaximumRange or 100

  VarTrinket1CD = Trinket1:Cooldown()
  VarTrinket2CD = Trinket2:Cooldown()

  VarTrinket1BL = Player:IsItemBlacklisted(Trinket1)
  VarTrinket2BL = Player:IsItemBlacklisted(Trinket2)

  VarCombustionOnUse = I.ForgedGladiatorsBadge:IsEquipped() or I.CrimsonGladiatorsBadge:IsEquipped() or I.DraconicGladiatorsBadge:IsEquipped() or I.ObsidianGladiatorsBadge:IsEquipped() or I.VerdantGladiatorsBadge:IsEquipped() or I.MoonlitPrism:IsEquipped() or I.IrideusFragment:IsEquipped() or I.SpoilsofNeltharus:IsEquipped() or I.TimebreachingTalon:IsEquipped() or I.HornofValor:IsEquipped()
end
SetTrinketVariables()

--- ===== Precombat Variables =====
local function SetPrecombatVariables()
  VarFirestarterCombusion = S.SunKingsBlessing:IsAvailable()
  VarHotStreakFlamestrike = 4 * num(S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable()) + 999 * num(not S.FlamePatch:IsAvailable() and not S.Quickflame:IsAvailable())
  VarHardCastFlamestrike = 999
  VarCombustionFlamestrike = 4 * num(S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable()) + 999 * num(not S.FlamePatch:IsAvailable() and not S.Quickflame:IsAvailable())
  VarSKBFlamestrike = 3 * num(S.Quickflame:IsAvailable() or S.FlamePatch:IsAvailable()) + 999 * num(not S.FlamePatch:IsAvailable() and not S.Quickflame:IsAvailable())
  VarArcaneExplosion = 999
  VarArcaneExplosionMana = 40
  VarCombustionShiftingPower = 999
  VarCombustionCastRemains = 0.3
  VarOverpoolFireBlasts = 0
  VarSKBDuration = 6
  VarOnUseCutoff = VarCombustionOnUse and 20 or VarOnUseCutoff
end
SetPrecombatVariables()

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  SetTrinketVariables()
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
  SetPrecombatVariables()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
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

--- ===== Helper Functions =====
local function ScorchExecuteActive()
  if not S.Scorch:IsAvailable() then return false end
  if Player:BuffUp(S.HeatShimmerBuff) then return true end
  return Target:HealthPercentage() <= 30 + 5 * num(S.SunfuryExecution:IsAvailable())
end

local function FirestarterActive()
  return (S.Firestarter:IsAvailable() and (Target:HealthPercentage() > 90))
end

local function FirestarterRemains()
  return S.Firestarter:IsAvailable() and ((Target:HealthPercentage() > 90) and Target:TimeToX(90) or 0) or 0
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
  return Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.HyperthermiaBuff) or (Player:BuffUp(S.HeatingUpBuff) and (ImprovedScorchActive() and Player:IsCasting(S.Scorch) or FirestarterActive() and (Player:IsCasting(S.Fireball) or FSInFlight > 0)))
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

--- ===== Rotation Functions =====
local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- arcane_intellect
  if S.ArcaneIntellect:IsCastable() and Everyone.GroupBuffMissing(S.ArcaneIntellect) then
    if Cast(S.ArcaneIntellect, Settings.CommonsOGCD.GCDasOffGCD.ArcaneIntellect) then return "arcane_intellect precombat 2"; end
  end
  -- variable,name=firestarter_combustion,default=-1,value=talent.sun_kings_blessing,if=variable.firestarter_combustion<0
  -- variable,name=hot_streak_flamestrike,if=variable.hot_streak_flamestrike=0,value=4*(talent.quickflame|talent.flame_patch)+999*(!talent.flame_patch&!talent.quickflame)
  -- variable,name=hard_cast_flamestrike,if=variable.hard_cast_flamestrike=0,value=999
  -- variable,name=combustion_flamestrike,if=variable.combustion_flamestrike=0,value=4*(talent.quickflame|talent.flame_patch)+999*(!talent.flame_patch&!talent.quickflame)
  -- variable,name=skb_flamestrike,if=variable.skb_flamestrike=0,value=3*(talent.quickflame|talent.flame_patch)+999*(!talent.flame_patch&!talent.quickflame)
  -- variable,name=arcane_explosion,if=variable.arcane_explosion=0,value=999
  -- variable,name=arcane_explosion_mana,default=40,op=reset
  -- variable,name=combustion_shifting_power,if=variable.combustion_shifting_power=0,value=999
  -- variable,name=combustion_cast_remains,default=0.3,op=reset
  -- variable,name=overpool_fire_blasts,default=0,op=reset
  -- variable,name=skb_duration,value=dbc.effect.1016075.base_value
  -- variable,name=combustion_on_use,value=equipped.gladiators_badge|equipped.moonlit_prism|equipped.irideus_fragment|equipped.spoils_of_neltharus|equipped.timebreaching_talon|equipped.horn_of_valor
  -- variable,name=on_use_cutoff,value=20,if=variable.combustion_on_use
  -- Note: Moved to initial declarations and Event Registrations.
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
  -- meteor,if=buff.combustion.up|(buff.sun_kings_blessing.max_stack-buff.sun_kings_blessing.stack>4|variable.time_to_combustion<=0|buff.combustion.remains>travel_time|!talent.sun_kings_blessing&(cooldown.meteor.duration<variable.time_to_combustion|fight_remains<variable.time_to_combustion))
  if S.Meteor:IsReady() and (CombustionUp or (VarSKBMaxStack - Player:BuffStack(S.SunKingsBlessingBuff) > 4 or VarTimeToCombustion <= 0 or CombustionRemains > S.Meteor:TravelTime() or not S.SunKingsBlessing:IsAvailable() and (45 < VarTimeToCombustion or BossFightRemains < VarTimeToCombustion))) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor active_talents 2"; end
  end
  -- dragons_breath,if=talent.alexstraszas_fury&(buff.combustion.down&!buff.hot_streak.react)&(buff.feel_the_burn.up|time>15)&(!improved_scorch.active)
  if S.DragonsBreath:IsReady() and (S.AlexstraszasFury:IsAvailable() and (CombustionDown and Player:BuffDown(S.HotStreakBuff)) and (Player:BuffUp(S.FeeltheBurnBuff) or HL.CombatTime() > 15) and not ImprovedScorchActive()) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath active_talents 4 left"; end
    else
      if Cast(S.DragonsBreath, Settings.Fire.GCDasOffGCD.DragonsBreath) then return "dragons_breath active_talents 4"; end
    end
  end
end

local function CombustionCooldowns()
  -- potion
  if Settings.Commons.Enabled.Potions then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion combustion_cooldowns 2"; end
    end
  end
  -- blood_fury
  if S.BloodFury:IsCastable() then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury combustion_cooldowns 4"; end
  end
  -- berserking,if=buff.combustion.up
  if S.Berserking:IsCastable() and (CombustionUp) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking combustion_cooldowns 6"; end
  end
  -- fireblood
  if S.Fireblood:IsCastable() then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood combustion_cooldowns 8"; end
  end
  -- ancestral_call
  if S.AncestralCall:IsCastable() then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call combustion_cooldowns 10"; end
  end
  -- invoke_external_buff,name=power_infusion,if=buff.power_infusion.down
  -- invoke_external_buff,name=blessing_of_summer,if=buff.blessing_of_summer.down
  -- Note: Not handling external buffs
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,effect_name=gladiators_badge
    if I.ForgedGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.ForgedGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (forged) combustion_cooldowns 14"; end
    end
    if I.CrimsonGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.CrimsonGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (crimson) combustion_cooldowns 14"; end
    end
    if I.DraconicGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.DraconicGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (draconic) combustion_cooldowns 14"; end
    end
    if I.ObsidianGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.ObsidianGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (obsidian) combustion_cooldowns 14"; end
    end
    if I.VerdantGladiatorsBadge:IsEquippedAndReady() then
      if Cast(I.VerdantGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (verdant) combustion_cooldowns 14"; end
    end
  end
end

local function CombustionPhase()
  -- call_action_list,name=combustion_cooldowns,if=buff.combustion.remains>variable.skb_duration|fight_remains<20
  if CombustionRemains > VarSKBDuration or BossFightRemains < 20 then
    local ShouldReturn = CombustionCooldowns(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  -- combustion from below
  if S.Combustion:IsReady() and (HotStreakInFlight() == 0 and CombustionDown and VarTimeToCombustion <= 0 and (Player:IsCasting(S.Scorch) and S.Scorch:ExecuteRemains() < VarCombustionCastRemains or Player:IsCasting(S.Fireball) and S.Fireball:ExecuteRemains() < VarCombustionCastRemains or Player:IsCasting(S.Pyroblast) and S.Pyroblast:ExecuteRemains() < VarCombustionCastRemains or Player:IsCasting(S.Flamestrike) and S.Flamestrike:ExecuteRemains() < VarCombustionCastRemains or S.Meteor:InFlight() and S.Meteor:InFlightRemains() < VarCombustionCastRemains)) then
    if Cast(S.Combustion, Settings.Fire.OffGCDasOffGCD.Combustion) then return "combustion combustion_phase 2"; end
  end
  -- fire_blast from below
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&(!improved_scorch.active|action.scorch.executing|debuff.improved_scorch.remains>4*gcd.max)&(buff.fury_of_the_sun_king.down|action.pyroblast.executing)&buff.combustion.up&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react*(gcd.remains>0)<2
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not VarFireBlastPooling and (not ImprovedScorchActive() or Player:IsCasting(S.Scorch) or Target:DebuffRemains(S.ImprovedScorchDebuff) > 4 * GCDMax) and (Player:BuffDown(S.FuryoftheSunKingBuff) or Player:IsCasting(S.Pyroblast)) and CombustionUp and Player:BuffDown(S.HotStreakBuff) and HotStreakInFlight() + num(Player:BuffUp(S.HeatingUpBuff)) * num(Player:GCDRemains() > 0) < 2) then
    if CastLeft(S.FireBlast) then return "fire_blast combustion_phase 4"; end
  end
  -- flamestrike,if=buff.combustion.down&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&buff.fury_of_the_sun_king.expiration_delay_remains=0&cooldown.combustion.remains<cast_time&active_enemies>=variable.skb_flamestrike
  -- TODO: Handle expiration_delay_remains
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (CombustionDown and Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Flamestrike:CastTime() and S.Combustion:CooldownRemains() < S.Flamestrike:CastTime() and EnemiesCount8ySplash >= VarSKBFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 6"; end
  end
  -- pyroblast,if=buff.combustion.down&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&(buff.fury_of_the_sun_king.expiration_delay_remains=0|buff.flame_accelerant.up)
  -- TODO: Handle expiration_delay_remains
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (CombustionDown and Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Pyroblast:CastTime() and Player:BuffUp(S.FlameAccelerantBuff)) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 8"; end
  end
  -- meteor,if=talent.isothermic_core&buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Meteor:IsReady() and (S.IsothermicCore:IsAvailable() and CombustionDown and S.Combustion:CooldownRemains() < S.Meteor:CastTime()) then
    if Cast(S.Meteor, Settings.Fire.GCDasOffGCD.Meteor, nil, not Target:IsInRange(40)) then return "meteor combustion_phase 10"; end
  end
  -- fireball,if=buff.combustion.down&cooldown.combustion.remains<cast_time&active_enemies<2&!improved_scorch.active&!(talent.sun_kings_blessing&talent.flame_accelerant)
  if S.Fireball:IsReady() and (CombustionDown and CombustionRemains < S.Fireball:CastTime() and EnemiesCount16ySplash < 2 and not ImprovedScorchActive() and not (S.SunKingsBlessing:IsAvailable() and S.FlameAccelerant:IsAvailable())) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 12"; end
  end
  -- scorch,if=buff.combustion.down&cooldown.combustion.remains<cast_time
  if S.Scorch:IsReady() and (CombustionDown and S.Combustion:CooldownRemains() < S.Scorch:CastTime()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 14"; end
  end
  -- combustion,use_off_gcd=1,use_while_casting=1,if=hot_streak_spells_in_flight=0&buff.combustion.down&variable.time_to_combustion<=0&(action.scorch.executing&action.scorch.execute_remains<variable.combustion_cast_remains|action.fireball.executing&action.fireball.execute_remains<variable.combustion_cast_remains|action.pyroblast.executing&action.pyroblast.execute_remains<variable.combustion_cast_remains|action.flamestrike.executing&action.flamestrike.execute_remains<variable.combustion_cast_remains|action.meteor.in_flight&action.meteor.in_flight_remains<variable.combustion_cast_remains)
  -- Note: Moved above the previous five lines, due to use_while_casting.
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&(!improved_scorch.active|action.scorch.executing|debuff.improved_scorch.remains>4*gcd.max)&(buff.fury_of_the_sun_king.down|action.pyroblast.executing)&buff.combustion.up&!buff.hot_streak.react&hot_streak_spells_in_flight+buff.heating_up.react*(gcd.remains>0)<2
  -- Note: Moved above with combustion, due to use_while_casting
  -- cancel_buff,name=hyperthermia,if=buff.fury_of_the_sun_king.react
  -- flamestrike,if=(buff.hot_streak.react&active_enemies>=variable.combustion_flamestrike)|(buff.hyperthermia.react&active_enemies>=variable.combustion_flamestrike-talent.hyperthermia)
  if AoEON() and S.Flamestrike:IsReady() and ((Player:BuffUp(S.HotStreakBuff) and EnemiesCount8ySplash >= VarCombustionFlamestrike) or (Player:BuffUp(S.HyperthermiaBuff) and EnemiesCount8ySplash >= VarCombustionFlamestrike - num(S.Hyperthermia:IsAvailable()))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 16"; end
  end
  -- pyroblast,if=buff.hyperthermia.react
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HyperthermiaBuff)) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 18"; end
  end
  -- pyroblast,if=buff.hot_streak.react&buff.combustion.up
  if S.Pyroblast:IsReady() and (Player:BuffUp(S.HotStreakBuff) and CombustionUp) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 20"; end
  end
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&active_enemies<variable.combustion_flamestrike&buff.combustion.up
  if S.Pyroblast:IsReady() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffUp(S.HeatingUpBuff) and EnemiesCount8ySplash < VarCombustionFlamestrike and CombustionUp) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 22"; end
  end
  -- flamestrike,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&active_enemies>=variable.skb_flamestrike&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Flamestrike:CastTime() and EnemiesCount8ySplash >= VarSKBFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike combustion_phase 24"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.remains>cast_time&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (Player:BuffUp(S.FuryoftheSunKingBuff) and Player:BuffRemains(S.FuryoftheSunKingBuff) > S.Pyroblast:CastTime()) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast combustion_phase 26"; end
  end
  -- phoenix_flames,if=talent.phoenix_reborn&buff.heating_up.react+hot_streak_spells_in_flight<2&buff.flames_fury.up
  if S.PhoenixFlames:IsCastable() and (S.PhoenixReborn:IsAvailable() and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() < 2 and Player:BuffUp(S.FlamesFuryBuff)) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 28"; end
  end
  -- fireball,if=buff.frostfire_empowerment.up&!buff.hot_streak.react&!buff.excess_frost.up
  if S.Fireball:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.ExcessFrostBuff)) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 30"; end
  end
  -- scorch,if=improved_scorch.active&(debuff.improved_scorch.remains<4*gcd.max)&active_enemies<variable.combustion_flamestrike
  if S.Scorch:IsReady() and (ImprovedScorchActive() and (Target:DebuffRemains(S.ImprovedScorchDebuff) < 4 * GCDMax) and EnemiesCount16ySplash < VarCombustionFlamestrike) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 32"; end
  end
  -- scorch,if=buff.heat_shimmer.react&(talent.scald|talent.improved_scorch)&active_enemies<variable.combustion_flamestrike
  if S.Scorch:IsReady() and (Player:BuffUp(S.HeatShimmerBuff) and (S.Scald:IsAvailable() or S.ImprovedScorch:IsAvailable()) and EnemiesCount16ySplash < VarCombustionFlamestrike) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 34"; end
  end
  -- phoenix_flames,if=(!talent.call_of_the_sun_king&travel_time<buff.combustion.remains|(talent.call_of_the_sun_king&buff.combustion.remains<4|buff.sun_kings_blessing.stack<8))&buff.heating_up.react+hot_streak_spells_in_flight<2
  if S.PhoenixFlames:IsCastable() and ((not S.CalloftheSunKing:IsAvailable() and S.PhoenixFlames:TravelTime() < CombustionRemains or (S.CalloftheSunKing:IsAvailable() and CombustionRemains < 4 or Player:BuffStack(S.SunKingsBlessingBuff) < 8)) and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() < 2) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames combustion_phase 36"; end
  end
  -- fireball,if=buff.frostfire_empowerment.up&!buff.hot_streak.react
  if S.Fireball:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.HotStreakBuff)) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 38"; end
  end
  -- scorch,if=buff.combustion.remains>cast_time&cast_time>=gcd.max
  -- Note: Using Player:GCD() here to avoid this line being skipped from the extra 0.25s added to GCDMax.
  if S.Scorch:IsReady() and (CombustionRemains > S.Scorch:CastTime() and S.Scorch:CastTime() >= Player:GCD()) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch combustion_phase 44"; end
  end
  -- fireball,if=buff.combustion.remains>cast_time
  if S.Fireball:IsReady() and (CombustionRemains > S.Fireball:CastTime()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball combustion_phase 46"; end
  end
end

local function CombustionTiming()
  -- variable,use_off_gcd=1,use_while_casting=1,name=combustion_ready_time,value=cooldown.combustion.remains*expected_kindling_reduction
  VarCombustionReadyTime = S.Combustion:CooldownRemains() * VarKindlingReduction
  -- variable,use_off_gcd=1,use_while_casting=1,name=combustion_precast_time,value=action.fireball.cast_time*(active_enemies<variable.combustion_flamestrike)+action.flamestrike.cast_time*(active_enemies>=variable.combustion_flamestrike)-variable.combustion_cast_remains
  VarCombustionPrecastTime = S.Fireball:CastTime() * num(EnemiesCount8ySplash < VarCombustionFlamestrike) + S.Flamestrike:CastTime() * num(EnemiesCount8ySplash >= VarCombustionFlamestrike) - VarCombustionCastRemains
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=variable.combustion_ready_time
  VarTimeToCombustion = VarCombustionReadyTime
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=firestarter.remains,if=talent.firestarter&!variable.firestarter_combustion
  if S.Firestarter:IsAvailable() and not VarFirestarterCombusion then
    VarTimeToCombustion = max(FirestarterRemains(), VarTimeToCombustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=(buff.sun_kings_blessing.max_stack-buff.sun_kings_blessing.stack)*(3*gcd.max),if=talent.sun_kings_blessing&firestarter.active&buff.fury_of_the_sun_king.down
  if S.SunKingsBlessing:IsAvailable() and FirestarterActive() and Player:BuffDown(S.FuryoftheSunKingBuff) then
    VarTimeToCombustion = max(((VarSKBMaxStack - Player:BuffStack(S.SunKingsBlessingBuff)) * (3 * GCDMax)), VarTimeToCombustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=cooldown.gladiators_badge_345228.remains,if=equipped.gladiators_badge&cooldown.gladiators_badge_345228.remains-20<variable.time_to_combustion
  if I.ForgedGladiatorsBadge:IsEquipped() and I.ForgedGladiatorsBadge:CooldownRemains() - 20 < VarTimeToCombustion then
    VarTimeToCombustion = max(I.ForgedGladiatorsBadge:CooldownRemains(), VarTimeToCombustion)
  end
  if I.CrimsonGladiatorsBadge:IsEquipped() and I.CrimsonGladiatorsBadge:CooldownRemains() - 20 < VarTimeToCombustion then
    VarTimeToCombustion = max(I.CrimsonGladiatorsBadge:CooldownRemains(), VarTimeToCombustion)
  end
  if I.DraconicGladiatorsBadge:IsEquipped() and I.DraconicGladiatorsBadge:CooldownRemains() - 20 < VarTimeToCombustion then
    VarTimeToCombustion = max(I.DraconicGladiatorsBadge:CooldownRemains(), VarTimeToCombustion)
  end
  if I.ObsidianGladiatorsBadge:IsEquipped() and I.ObsidianGladiatorsBadge:CooldownRemains() - 20 < VarTimeToCombustion then
    VarTimeToCombustion = max(I.ObsidianGladiatorsBadge:CooldownRemains(), VarTimeToCombustion)
  end
  if I.VerdantGladiatorsBadge:IsEquipped() and I.VerdantGladiatorsBadge:CooldownRemains() - 20 < VarTimeToCombustion then
    VarTimeToCombustion = max(I.VerdantGladiatorsBadge:CooldownRemains(), VarTimeToCombustion)
  end
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=buff.combustion.remains
  VarTimeToCombustion = max(CombustionRemains, VarTimeToCombustion)
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,op=max,value=raid_event.adds.in,if=raid_event.adds.exists&raid_event.adds.count>=3&raid_event.adds.duration>15
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=raid_event.vulnerable.in*!raid_event.vulnerable.up,if=raid_event.vulnerable.exists&variable.combustion_ready_time<raid_event.vulnerable.in
  -- Note: Skipping this, as we don't handle SimC's raid_event
  -- variable,use_off_gcd=1,use_while_casting=1,name=time_to_combustion,value=variable.combustion_ready_time,if=variable.combustion_ready_time+cooldown.combustion.duration*(1-(0.4+0.2*talent.firestarter)*talent.kindling)<=variable.time_to_combustion|variable.time_to_combustion>fight_remains-20
  if VarCombustionReadyTime + 120 * (1 - (0.4 + 0.2 * num(S.Firestarter:IsAvailable())) * num(S.Kindling:IsAvailable())) <= VarTimeToCombustion or VarTimeToCombustion > FightRemains - 20 then
    VarTimeToCombustion = VarCombustionReadyTime
  end
end

local function FirestarterFireBlasts()
  -- fire_blast,use_while_casting=1,if=!variable.fire_blast_pooling&!buff.hot_streak.react&(action.fireball.execute_remains>gcd.remains|action.pyroblast.executing)&buff.heating_up.react+hot_streak_spells_in_flight=1&(cooldown.shifting_power.ready|charges>1|buff.feel_the_burn.remains<2*gcd.max)
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not VarFireBlastPooling and Player:BuffDown(S.HotStreakBuff) and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() == 1 and (S.ShiftingPower:CooldownUp() or S.FireBlast:Charges() > 1 or Player:BuffRemains(S.FeeltheBurnBuff) < 2 * GCDMax)) then
    if FBCast(S.FireBlast) then return "fire_blast firestarter_fire_blasts 2"; end
  end
  -- fire_blast,use_off_gcd=1,if=!variable.fire_blast_pooling&buff.heating_up.react+hot_streak_spells_in_flight=1&(talent.feel_the_burn&buff.feel_the_burn.remains<gcd.remains|cooldown.shifting_power.ready)&time>0
  -- Note: Skipping time>0, as we can't ever hit time at 0.
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not VarFireBlastPooling and num(Player:BuffUp(S.HeatingUpBuff)) + HotStreakInFlight() == 1 and (S.FeeltheBurn:IsAvailable() and Player:BuffRemains(S.FeeltheBurnBuff) < Player:GCDRemains() or S.ShiftingPower:CooldownUp())) then
    if CastLeft(S.FireBlast) then return "fire_blast firestarter_fire_blasts 4"; end
  end
end

local function StandardRotation()
  -- flamestrike,if=active_enemies>=variable.hot_streak_flamestrike&(buff.hot_streak.react|buff.hyperthermia.react)
  if AoEON() and S.Flamestrike:IsReady() and (EnemiesCount8ySplash >= VarHotStreakFlamestrike and (Player:BuffUp(S.HotStreakBuff) or Player:BuffUp(S.HyperthermiaBuff))) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 2"; end
  end
  -- pyroblast,if=(buff.hyperthermia.react|buff.hot_streak.react&(buff.hot_streak.remains<action.fireball.execute_time)|buff.hot_streak.react&(hot_streak_spells_in_flight|firestarter.active|talent.call_of_the_sun_king&action.phoenix_flames.charges)|buff.hot_streak.react&scorch_execute.active)
  -- Note: Simplifying this line, as there were instances where instant Pyroblast wasn't being suggested.
  if S.Pyroblast:IsReady() and FreeCastAvailable() then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 4"; end
  end
  --if S.Pyroblast:IsReady() and (Player:BuffUp(S.HyperthermiaBuff) or Player:BuffUp(S.HotStreakBuff) and (Player:BuffRemains(S.HotStreakBuff) < S.Fireball:ExecuteRemains()) or Player:BuffUp(S.HotStreakBuff) and (HotStreakInFlight() > 0 or FirestarterActive() or S.CalloftheSunKing:IsAvailable() and S.PhoenixFlames:Charges() > 0) or Player:BuffUp(S.HotStreakBuff) and ScorchExecuteActive()) then
    --if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 4"; end
  --end
  -- Note: fire_blast moved from below.
  -- Note: Removed Hyperthermia timings, as it caused Fire Blast to only quickly appear in the last 0.5s of a Fireball/Pyroblast cast.
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (not FirestarterActive() and (not VarFireBlastPooling or S.SpontaneousCombustion:IsAvailable()) and Player:BuffDown(S.FuryoftheSunKingBuff) and (((Player:IsCasting(S.Fireball) or Player:IsCasting(S.Pyroblast)) and Player:BuffUp(S.HeatingUpBuff)) or (ScorchExecuteActive() and (not ImprovedScorchActive() or Target:DebuffStack(S.ImprovedScorchDebuff) == VarImprovedScorchMaxStack or S.FireBlast:FullRechargeTime() < 3) and (Player:BuffUp(S.HeatingUpBuff) and not Player:IsCasting(S.Scorch) or Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HeatingUpBuff) and Player:IsCasting(S.Scorch) and HotStreakInFlight() == 0)))) then
    if CastLeft(S.FireBlast) then return "fire_blast standard_rotation 6"; end
  end
  -- Note: Other fire_blast moved from below.
  if S.FireBlast:IsReady() and not FreeCastAvailable() and (Player:BuffUp(S.HyperthermiaBuff) and S.FireBlast:Charges() > 0 and Player:BuffUp(S.HeatingUpBuff)) then
    if CastLeft(S.FireBlast) then return "fire_blast standard_rotation 8"; end
  end
  -- flamestrike,if=active_enemies>=variable.skb_flamestrike&buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if AoEON() and S.Flamestrike:IsReady() and not Player:IsCasting(S.Flamestrike) and (EnemiesCount8ySplash >= VarSKBFlamestrike and Player:BuffUp(S.FuryoftheSunKingBuff)) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 10"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.remains<action.pyroblast.cast_time+5*gcd.max&buff.fury_of_the_sun_king.up&!action.scorch.in_flight
  -- Note: Using IsCasting check for !action.scorch.in_flight, since Scorch is an instant hit ability with no travel time.
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffRemains(S.ImprovedScorchDebuff) < S.Pyroblast:CastTime() + 5 * GCDMax and Player:BuffUp(S.FuryoftheSunKingBuff) and not Player:IsCasting(S.Scorch)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 12"; end
  end
  -- pyroblast,if=buff.fury_of_the_sun_king.up&buff.fury_of_the_sun_king.expiration_delay_remains=0
  if S.Pyroblast:IsReady() and not Player:IsCasting(S.Pyroblast) and (Player:BuffUp(S.FuryoftheSunKingBuff)) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 14"; end
  end
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!firestarter.active&(!variable.fire_blast_pooling|talent.spontaneous_combustion)&buff.fury_of_the_sun_king.down&(((action.fireball.executing&(action.fireball.execute_remains<0.5|!talent.hyperthermia)|action.pyroblast.executing&(action.pyroblast.execute_remains<0.5))&buff.heating_up.react)|(scorch_execute.active&(!improved_scorch.active|debuff.improved_scorch.stack=debuff.improved_scorch.max_stack|full_recharge_time<3)&(buff.heating_up.react&!action.scorch.executing|!buff.hot_streak.react&!buff.heating_up.react&action.scorch.executing&!hot_streak_spells_in_flight)))
  -- fire_blast,use_off_gcd=1,use_while_casting=1,if=buff.hyperthermia.up&charges>0&buff.heating_up.react
  -- Note: Moved both fire_blast uses above previous 3 lines, due to use_while_casting.
  -- pyroblast,if=prev_gcd.1.scorch&buff.heating_up.react&scorch_execute.active&active_enemies<variable.hot_streak_flamestrike
  if S.Pyroblast:IsReady() and (Player:PrevGCDP(1, S.Scorch) and Player:BuffUp(S.HotStreakBuff) and ScorchExecuteActive() and EnemiesCount16ySplash < VarHotStreakFlamestrike) then
    if PBCast(S.Pyroblast, nil, nil, not Target:IsSpellInRange(S.Pyroblast)) then return "pyroblast standard_rotation 16"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.remains<4*gcd.max
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffRemains(S.ImprovedScorchDebuff) < 4 * GCDMax) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 18"; end
  end
  -- fireball,if=buff.frostfire_empowerment.up&!buff.hot_streak.react&!buff.excess_frost.up
  if S.Fireball:IsReady() and (Player:BuffUp(S.FrostfireEmpowermentBuff) and Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.ExcessFrostBuff)) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball standard_rotation 20"; end
  end
  -- scorch,if=improved_scorch.active&debuff.improved_scorch.stack<debuff.improved_scorch.max_stack
  if S.Scorch:IsReady() and (ImprovedScorchActive() and Target:DebuffStack(S.ImprovedScorchDebuff) < VarImprovedScorchMaxStack) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 22"; end
  end
  -- scorch,if=buff.heat_shimmer.react&(talent.scald|talent.improved_scorch)&active_enemies<variable.combustion_flamestrike
  if S.Scorch:IsReady() and (Player:BuffUp(S.HeatShimmerBuff) and (S.Scald:IsAvailable() or S.ImprovedScorch:IsAvailable()) and EnemiesCount16ySplash < VarCombustionFlamestrike) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 24"; end
  end
  -- phoenix_flames,if=talent.sun_kings_blessing&talent.call_of_the_sun_king&!buff.hot_streak.react&hot_streak_spells_in_flight<2
  if S.PhoenixFlames:IsCastable() and (S.SunKingsBlessing:IsAvailable() and S.CalloftheSunKing:IsAvailable() and Player:BuffDown(S.HotStreakBuff) and HotStreakInFlight() < 2) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 26"; end
  end
  -- phoenix_flames,if=!talent.sun_kings_blessing&talent.call_of_the_sun_king&!buff.hot_streak.react&hot_streak_spells_in_flight<2&(!variable.phoenix_pooling&buff.flames_fury.up|charges_fractional>2.5|charges_fractional>1.5|buff.flames_fury.react)&(!talent.feel_the_burn|buff.feel_the_burn.remains<3*gcd.max|buff.flames_fury.react)
  -- Note: Removed charges_fractional>2.5, as the following charges_fractional>1.5 covers it.
  if S.PhoenixFlames:IsCastable() and (not S.SunKingsBlessing:IsAvailable() and S.CalloftheSunKing:IsAvailable() and Player:BuffDown(S.HotStreakBuff) and HotStreakInFlight() < 2 and (not VarPhoenixPooling and Player:BuffUp(S.FlamesFuryBuff) or S.PhoenixFlames:ChargesFractional() > 1.5 or Player:BuffUp(S.FlamesFuryBuff)) and (not S.FeeltheBurn:IsAvailable() or Player:BuffRemains(S.FeeltheBurnBuff) < 3 * GCDMax or Player:BuffUp(S.FlamesFuryBuff))) then
    if Cast(S.PhoenixFlames, nil, nil, not Target:IsSpellInRange(S.PhoenixFlames)) then return "phoenix_flames standard_rotation 28"; end
  end
  -- call_action_list,name=active_talents
  local ShouldReturn = ActiveTalents(); if ShouldReturn then return ShouldReturn; end
  -- dragons_breath,if=active_enemies>1&talent.alexstraszas_fury
  if AoEON() and S.DragonsBreath:IsReady() and (EnemiesCount16ySplash > 1 and S.AlexstraszasFury:IsAvailable()) then
    if Settings.Fire.StayDistance and not Target:IsInRange(12) then
      if CastLeft(S.DragonsBreath) then return "dragons_breath standard_rotation 30 left"; end
    else
      if Cast(S.DragonsBreath, Settings.Fire.GCDasOffGCD.DragonsBreath) then return "dragons_breath standard_rotation 30"; end
    end
  end
  -- scorch,if=(scorch_execute.active|buff.heat_shimmer.react)
  if S.Scorch:IsReady() and (ScorchExecuteActive() or Player:BuffUp(S.HeatShimmerBuff)) then
    if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch standard_rotation 32"; end
  end
  -- arcane_explosion,if=active_enemies>=variable.arcane_explosion&mana.pct>=variable.arcane_explosion_mana
  if AoEON() and S.ArcaneExplosion:IsReady() and (EnemiesCount16ySplash >= VarArcaneExplosion and Player:ManaPercentageP() >= VarArcaneExplosionMana) then
    if Settings.Fire.StayDistance and not Target:IsInRange(10) then
      if CastLeft(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 34 left"; end
    else
      if Cast(S.ArcaneExplosion) then return "arcane_explosion standard_rotation 34"; end
    end
  end
  -- flamestrike,if=active_enemies>=variable.hard_cast_flamestrike
  if AoEON() and S.Flamestrike:IsReady() and (EnemiesCount8ySplash >= VarHardCastFlamestrike) then
    if Cast(S.Flamestrike, nil, nil, not Target:IsInRange(40)) then return "flamestrike standard_rotation 36"; end
  end
  -- fireball
  if S.Fireball:IsReady() and (not FreeCastAvailable()) then
    if Cast(S.Fireball, nil, nil, not Target:IsSpellInRange(S.Fireball)) then return "fireball standard_rotation 38"; end
  end
end

--- ===== APL Main =====
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
    -- Note: Currently unused. Leaving in as a comment in case we need it later.
    --UnitsWithIgniteCount = UnitsWithIgnite(Enemies8ySplash)

    -- Define gcd.max
    GCDMax = Player:GCD() + 0.25

    -- Get our Combustion status
    CombustionUp = Player:BuffUp(S.CombustionBuff)
    CombustionDown = not CombustionUp
    CombustionRemains = CombustionUp and Player:BuffRemains(S.CombustionBuff) or 0
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- counterspell
    local ShouldReturn = Everyone.Interrupt(S.Counterspell, Settings.CommonsDS.DisplayStyle.Interrupts, false); if ShouldReturn then return ShouldReturn; end
    -- Manually added: Scorch sniping
    if Settings.Fire.UseScorchSniping and S.SearingTouch:IsAvailable() and AoEON() and Target:HealthPercentage() > 30 then
      for _, CycleUnit in pairs(Enemies16ySplash) do
        if CycleUnit:Exists() and CycleUnit:GUID() ~= Target:GUID() and not CycleUnit:IsDeadOrGhost() and CycleUnit:HealthPercentage() < 30 and CycleUnit:IsSpellInRange(S.Scorch) then
          if HR.CastLeftNameplate(CycleUnit, S.Scorch) then return "Scorch Sniping on "..CycleUnit:Name().." main 2"; end
        end
      end
    end
    -- call_action_list,name=combustion_timing
    CombustionTiming()
    -- potion,if=buff.potion.duration>variable.time_to_combustion+buff.combustion.duration
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() and (PotionSelected:BuffDuration() > VarTimeToCombustion + 12) then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion main 4"; end
      end
    end
    -- variable,name=shifting_power_before_combustion,value=variable.time_to_combustion>cooldown.shifting_power.remains
    VarShiftingPowerBeforeCombustion = VarTimeToCombustion > S.ShiftingPower:CooldownRemains()
    if Settings.Commons.Enabled.Trinkets then
      -- variable,name=item_cutoff_active,value=(variable.time_to_combustion<variable.on_use_cutoff|buff.combustion.remains>variable.skb_duration&!cooldown.item_cd_1141.remains)&((trinket.1.has_cooldown&trinket.1.cooldown.remains<variable.on_use_cutoff)+(trinket.2.has_cooldown&trinket.2.cooldown.remains<variable.on_use_cutoff)>1)
      VarItemCutoffActive = (VarTimeToCombustion < VarOnUseCutoff or CombustionRemains > VarSKBDuration and (I.DragonfireBombDispenser:CooldownUp() or not I.DragonfireBombDispenser:IsEquipped())) and (num(Trinket1:Cooldown() > 0 and Trinket1:CooldownRemains() < VarOnUseCutoff) + num(Trinket2:Cooldown() and Trinket2:CooldownRemains() < VarOnUseCutoff) > 1)
      -- use_item,effect_name=treacherous_transmitter,if=buff.combustion.remains>10|fight_remains<25
      if I.TreacherousTransmitter:IsEquippedAndReady() and (CombustionRemains > 10 or BossFightRemains < 25) then
        if Cast(I.TreacherousTransmitter, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "treacherous_transmitter main 6"; end
      end
      -- use_item,name=imperfect_ascendancy_serum,if=variable.time_to_combustion<3
      if I.ImperfectAscendancySerum:IsEquippedAndReady() and (VarTimeToCombustion < 3) then
        if Cast(I.ImperfectAscendancySerum, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "imperfect_ascendancy_serum main 8"; end
      end
      -- use_item,effect_name=spymasters_web,if=(buff.combustion.remains>10&fight_remains<60)|fight_remains<25
      if I.SpymastersWeb:IsEquippedAndReady() and ((CombustionRemains > 10 and FightRemains < 60) or BossFightRemains < 25) then
        if Cast(I.SpymastersWeb, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "spymasters_web main 10"; end
      end
      -- use_item,effect_name=gladiators_badge,if=variable.time_to_combustion>cooldown-5
      if I.ForgedGladiatorsBadge:IsEquippedAndReady() and (VarTimeToCombustion > I.ForgedGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.ForgedGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (forged) main 12"; end
      end
      if I.CrimsonGladiatorsBadge:IsEquippedAndReady() and (VarTimeToCombustion > I.CrimsonGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.CrimsonGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (crimson) main 12"; end
      end
      if I.DraconicGladiatorsBadge:IsEquippedAndReady() and (VarTimeToCombustion > I.DraconicGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.DraconicGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (draconic) main 12"; end
      end
      if I.ObsidianGladiatorsBadge:IsEquippedAndReady() and (VarTimeToCombustion > I.ObsidianGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.ObsidianGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (obsidian) main 12"; end
      end
      if I.VerdantGladiatorsBadge:IsEquippedAndReady() and (VarTimeToCombustion > I.VerdantGladiatorsBadge:Cooldown() - 5) then
        if Cast(I.VerdantGladiatorsBadge, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "gladiators_badge (verdant) main 12"; end
      end
    end
    -- use_items,if=!variable.item_cutoff_active
    if (Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items) and not VarItemCutoffActive then
      local ItemToUse, ItemSlot, ItemRange = Player:GetUseableItems(OnUseExcludes)
      if ItemToUse then
        local DisplayStyle = Settings.CommonsDS.DisplayStyle.Trinkets
        if ItemSlot ~= 13 and ItemSlot ~= 14 then DisplayStyle = Settings.CommonsDS.DisplayStyle.Items end
        if ((ItemSlot == 13 or ItemSlot == 14) and Settings.Commons.Enabled.Trinkets) or (ItemSlot ~=13 and ItemSlot ~= 14 and Settings.Commons.Enabled.Items) then
          if Cast(ItemToUse, nil, DisplayStyle, not Target:IsInRange(ItemRange)) then return "Generic use_items for "..ItemToUse:Name().." main 14"; end
        end
      end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=buff.combustion.down&action.fire_blast.charges_fractional+(variable.time_to_combustion+action.shifting_power.full_reduction*variable.shifting_power_before_combustion)%cooldown.fire_blast.duration-1<cooldown.fire_blast.max_charges+variable.overpool_fire_blasts%cooldown.fire_blast.duration-(buff.combustion.duration%cooldown.fire_blast.duration)%%1&variable.time_to_combustion<fight_remains
    VarFireBlastPooling = CombustionDown and S.FireBlast:ChargesFractional() + (VarTimeToCombustion + ShiftingPowerFullReduction() * num(VarShiftingPowerBeforeCombustion)) / S.FireBlast:Cooldown() - 1 < S.FireBlast:MaxCharges() + VarOverpoolFireBlasts / S.FireBlast:Cooldown() - (12 / S.FireBlast:Cooldown()) % 1 and VarTimeToCombustion < FightRemains
    -- call_action_list,name=combustion_phase,if=variable.time_to_combustion<=0|buff.combustion.up|variable.time_to_combustion<variable.combustion_precast_time&cooldown.combustion.remains<variable.combustion_precast_time
    if VarTimeToCombustion <= 0 or CombustionUp or VarTimeToCombustion < VarCombustionPrecastTime and S.Combustion:CooldownRemains() < VarCombustionPrecastTime then
      local ShouldReturn = CombustionPhase(); if ShouldReturn then return ShouldReturn; end
    end
    -- variable,use_off_gcd=1,use_while_casting=1,name=fire_blast_pooling,value=scorch_execute.active&action.fire_blast.full_recharge_time>3*gcd.max,if=!variable.fire_blast_pooling&talent.sun_kings_blessing
    if not VarFireBlastPooling and S.SunKingsBlessing:IsAvailable() then
      VarFireBlastPooling = ScorchExecuteActive() and S.FireBlast:FullRechargeTime() > 3 * GCDMax
    end
    -- Note: fire_blast from below. Moved above shifting_power, as it's intended to be used during it's cast.
    if S.FireBlast:IsReady() and not FreeCastAvailable() and (Player:IsChanneling(S.ShiftingPower) and (S.FireBlast:FullRechargeTime() < ShiftingPowerTickReduction or S.SunKingsBlessing:IsAvailable() and Player:BuffUp(S.HeatingUpBuff))) then
      if FBCast(S.FireBlast) then return "fire_blast main 16"; end
    end
    -- shifting_power,if=buff.combustion.down&(!improved_scorch.active|debuff.improved_scorch.remains>cast_time+action.scorch.cast_time&!buff.fury_of_the_sun_king.up)&!buff.hot_streak.react&buff.hyperthermia.down&(talent.sun_kings_blessing&cooldown.phoenix_flames.charges<=1|!talent.sun_kings_blessing)
    if S.ShiftingPower:IsReady() and (CombustionDown and (not ImprovedScorchActive() or Target:DebuffRemains(S.ImprovedScorchDebuff) > S.ShiftingPower:CastTime() + S.Scorch:CastTime() and Player:BuffDown(S.FuryoftheSunKingBuff)) and Player:BuffDown(S.HotStreakBuff) and Player:BuffDown(S.HyperthermiaBuff) and (S.SunKingsBlessing:IsAvailable() and S.PhoenixFlames:Charges() <= 1 or not S.SunKingsBlessing:IsAvailable())) then
      if Cast(S.ShiftingPower, nil, Settings.CommonsDS.DisplayStyle.ShiftingPower, not Target:IsInRange(18)) then return "shifting_power main 18"; end
    end
    -- variable,name=phoenix_pooling,if=!talent.sun_kings_blessing,value=(variable.time_to_combustion+buff.combustion.duration-5<action.phoenix_flames.full_recharge_time+cooldown.phoenix_flames.duration-action.shifting_power.full_reduction*variable.shifting_power_before_combustion&variable.time_to_combustion<fight_remains|talent.sun_kings_blessing)&!talent.alexstraszas_fury
    if not S.SunKingsBlessing:IsAvailable() then
      VarPhoenixPooling = (VarTimeToCombustion + 5 < S.PhoenixFlames:FullRechargeTime() + S.PhoenixFlames:Cooldown() - ShiftingPowerFullReduction() * num(VarShiftingPowerBeforeCombustion) and VarTimeToCombustion < FightRemains or S.SunKingsBlessing:IsAvailable()) and not S.AlexstraszasFury:IsAvailable()
    end
    -- fire_blast,use_off_gcd=1,use_while_casting=1,if=!variable.fire_blast_pooling&variable.time_to_combustion>0&active_enemies>=variable.hard_cast_flamestrike&!firestarter.active&!buff.hot_streak.react&(buff.heating_up.react&action.flamestrike.execute_remains<0.5|charges_fractional>=2)
    if S.FireBlast:IsReady() and not FreeCastAvailable() and (not VarFireBlastPooling and VarTimeToCombustion > 0 and EnemiesCount8ySplash >= VarHardCastFlamestrike and not FirestarterActive() and Player:BuffDown(S.HotStreakBuff) and (Player:BuffUp(S.HeatingUpBuff) and S.Flamestrike:ExecuteRemains() < 0.5 or S.FireBlast:ChargesFractional() >= 2)) then
      if CastLeft(S.FireBlast) then return "fire_blast main 20"; end
    end
    -- call_action_list,name=firestarter_fire_blasts,if=buff.combustion.down&firestarter.active&variable.time_to_combustion>0
    if CombustionDown and FirestarterActive() and VarTimeToCombustion > 0 then
      local ShouldReturn = FirestarterFireBlasts(); if ShouldReturn then return ShouldReturn; end
    end
    -- fire_blast,use_while_casting=1,if=action.shifting_power.executing&(full_recharge_time<action.shifting_power.tick_reduction|talent.sun_kings_blessing&buff.heating_up.react)
    -- Note: Moved above shifting_power, as this is intended to be used during its cast.
    -- call_action_list,name=standard_rotation,if=variable.time_to_combustion>0&buff.combustion.down
    if VarTimeToCombustion > 0 and CombustionDown then
      local ShouldReturn = StandardRotation(); if ShouldReturn then return ShouldReturn; end
    end
    -- ice_nova,if=!scorch_execute.active
    if S.IceNova:IsCastable() and (not ScorchExecuteActive()) then
      if Cast(S.IceNova, nil, nil, not Target:IsSpellInRange(S.IceNova)) then return "ice_nova main 22"; end
    end
    -- scorch
    if S.Scorch:IsReady() then
      if Cast(S.Scorch, nil, nil, not Target:IsSpellInRange(S.Scorch)) then return "scorch main 24"; end
    end
  end
end

local function Init()
  HR.Print("Fire Mage rotation has been updated for patch 11.0.0.")
end

HR.SetAPL(63, APL, Init)
