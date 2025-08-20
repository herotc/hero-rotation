--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- WoW API
local Delay      = C_Timer.After

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Marksmanship
local I = Item.Hunter.Marksmanship

-- Define array of summon_pet spells
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  I.UnyieldingNetherprism:ID(),
}

--- ===== GUI Settings =====
local Everyone = HR.Commons.Everyone
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  CommonsDS = HR.GUISettings.APL.Hunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Hunter.CommonsOGCD,
  Marksmanship = HR.GUISettings.APL.Hunter.Marksmanship
}

--- ===== Rotation Variables =====
local VarSpotterOrMovingDown = true
local VarCAExecute = Target:HealthPercentage() > 70 and S.CarefulAim:IsAvailable()
local VarTrueshotReady = false
local VarSyncActive = false
local VarSyncReady = false
local VarSyncRemains = 0
local Enemies10ySplash, EnemiesCount10ySplash
local TargetInRange40y
local BossFightRemains = 11111
local FightRemains = 11111

--- ===== Trinket Variables =====
local Trinket1, Trinket2
local VarTrinket1ID, VarTrinket2ID
local VarTrinket1Spell, VarTrinket2Spell
local VarTrinket1Range, VarTrinket2Range
local VarTrinket1CastTime, VarTrinket2CastTime
local VarTrinket1CD, VarTrinket2CD
local VarTrinket1Ex, VarTrinket2Ex
local VarTrinketFailures = 0
local function SetTrinketVariables()
  local T1, T2 = Player:GetTrinketData(OnUseExcludes)

  -- If we don't have trinket items, try again in 5 seconds.
  if VarTrinketFailures < 5 and ((T1.ID == 0 or T2.ID == 0) or (T1.SpellID > 0 and not T1.Usable or T2.SpellID > 0 and not T2.Usable)) then
    Delay(5, function()
        SetTrinketVariables()
      end
    )
    return
  end

  Trinket1 = T1.Object
  Trinket2 = T2.Object

  VarTrinket1ID = T1.ID
  VarTrinket2ID = T2.ID

  VarTrinket1Spell = T1.Spell
  VarTrinket1Range = T1.Range
  VarTrinket1CastTime = T1.CastTime
  VarTrinket2Spell = T2.Spell
  VarTrinket2Range = T2.Range
  VarTrinket2CastTime = T2.CastTime

  VarTrinket1CD = T1.Cooldown
  VarTrinket2CD = T2.Cooldown

  VarTrinket1Ex = T1.Excluded
  VarTrinket2Ex = T2.Excluded
end
SetTrinketVariables()

--- ===== Stun Interrupts List =====
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
}

--- ===== Event Registrations =====
HL:RegisterForEvent(function()
  VarTrinketFailures = 0
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AimedShot:RegisterInFlight()
end, "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB")
S.AimedShot:RegisterInFlight()

--- ===== Helper Functions =====
local function CheckFocusCap(Time)
  -- Shortcut for 'focus+cast_regen<focus.max'
  -- Note: The FocusP override accounts for Focus granted by the current cast.
  if not Bonus then Bonus = 0 end
  return Player:FocusP() + Player:FocusCastRegen(Time) < Player:FocusMax()
end

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBlackArrow(TargetUnit)
  -- target_if=min:dot.black_arrow_dot.ticking|max_prio_damage
  return TargetUnit:DebuffRemains(S.BlackArrowDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfBlackArrowCleave(TargetUnit)
  -- if=talent.black_arrow&(talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up)
  return S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)
end

--- ===== CastCycle Functions =====
local function EvaluateCycleAimedShotCleave(TargetUnit)
  -- target_if=max:debuff.spotters_mark.up,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  -- Note: Some checks done before CastCycle.
  return TargetUnit:DebuffUp(S.SpottersMarkDebuff) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff))
end

local function EvaluateCycleArcaneShotCleave(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  -- Note: Some checks done before CastCycle.
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight()) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff))
end

local function EvaluateCycleKillShotCleave(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=!talent.black_arrow&(talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up)
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight()) and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff))
end

local function EvaluateCycleMultiShotCleave(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)&!talent.aspect_of_the_hydra&(talent.symphonic_arsenal|talent.small_game_hunter)
  -- Note: Some checks done before CastCycle.
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight()) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff))
end

local function EvaluateCycleMultiShotTS(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight())
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- summon_pet,if=talent.unbreakable_bond
  -- Note: Moved to APL()
  -- Manually added: hunters_mark,if=debuff.hunters_mark.down
  if S.HuntersMark:IsCastable() and (Target:DebuffDown(S.HuntersMarkDebuff, true)) then
    if Cast(S.HuntersMark, Settings.CommonsOGCD.GCDasOffGCD.HuntersMark) then return "hunters_mark precombat 2"; end
  end
  -- aimed_shot,if=active_enemies<3|talent.black_arrow&talent.headshot
  -- Note: We can't actually get target counts before combat begins.
  if S.AimedShot:IsReady() and not Player:IsCasting(S.AimedShot) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot precombat 4"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() and not Player:IsCasting(S.AimedShot) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot precombat 6"; end
  end
end

local function CDs()
  -- invoke_external_buff,name=power_infusion,if=buff.trueshot.remains>12|fight_remains<13
  -- Note: Not handling external buffs.
  if CDsON() then
    -- berserking,if=buff.trueshot.up|fight_remains<13
    if S.Berserking:IsCastable() and (Player:BuffUp(S.TrueshotBuff) or FightRemains < 13) then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
    end
    -- blood_fury,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
    if S.BloodFury:IsCastable() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 4"; end
    end
    -- ancestral_call,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
    if S.AncestralCall:IsCastable() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
    end
    -- fireblood,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<9
    if S.Fireblood:IsCastable() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 9) then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
    end
    -- lights_judgment,if=buff.trueshot.down
    if S.LightsJudgment:IsCastable() and (Player:BuffDown(S.TrueshotBuff)) then
      if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
    end
  end
  -- potion,if=buff.trueshot.up&(buff.bloodlust.up|target.health.pct<20)|fight_remains<31
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.TrueshotBuff) and (Player:BloodlustUp() or Target:HealthPercentage() < 20) or FightRemains < 31) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 12"; end
    end
  end
end

local function Trinkets()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,name=unyielding_netherprism,if=buff.latent_energy.stack>7&(buff.trueshot.remains>13|buff.latent_energy.stack=18|fight_remains<25)
    if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffStack(S.LatentEnergyBuff) > 7 and (Player:BuffRemains(S.TrueshotBuff) > 13 or Player:BuffStack(S.LatentEnergyBuff) == 18 or BossFightRemains < 25)) then
      if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism trinket 2"; end
    end
    -- use_items,slots=trinket1:trinket2,if=!this_trinket.is.unyielding_prism&(!this_trinket.has_use_buff|buff.trueshot.up|cooldown.trueshot.remains>30)
    -- Note: Unyielding Netherprism is excluded via VarTrinket1Ex.
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (not Trinket1:HasUseBuff() or Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 4"; end
    end
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (not Trinket2:HasUseBuff() or Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 6"; end
    end
  end
  if Settings.Commons.Enabled.Items then
    -- Manually added: use_item for non-trinkets
    local ItemToUse, _, ItemRange = Player:GetUseableItems(OnUseExcludes, nil, true)
    if ItemToUse then
      if Cast(ItemToUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(ItemRange)) then return "Generic use_items for " .. ItemToUse:Name() .. " trinkets 6"; end
    end
  end
end

local function DRST()
  -- explosive_shot,if=talent.precision_detonation&buff.lock_and_load.down&cooldown.aimed_shot.charges<1&buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:Charges() < 1 and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_st 2"; end
  end
  -- volley,if=buff.double_tap.down&(!raid_event.adds.exists|raid_event.adds.in>cooldown)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley dr_st 4"; end
  end
  -- steady_shot,if=focus+cast_regen<focus.max&action.aimed_shot.in_flight&!action.black_arrow.cooldown_react&buff.trueshot.down&cooldown.trueshot.remains
  if S.SteadyShot:IsCastable() and (CheckFocusCap(S.SteadyShot:CastTime()) and S.AimedShot:InFlight() and not S.BlackArrow:IsReady() and Player:BuffDown(S.TrueshotBuff) and S.Trueshot:CooldownDown()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_st 6"; end
  end
  -- black_arrow,if=!talent.headshot|talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.BlackArrow:IsReady() and (not S.Headshot:IsAvailable() or S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "bl;ack_arrow dr_st 8"; end
  end
  -- aimed_shot,if=buff.trueshot.up&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffUp(S.TrueshotBuff) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_st 10"; end
  end
  -- rapid_fire,if=!buff.deathblow.react
  if S.RapidFire:IsCastable() and (Player:BuffDown(S.DeathblowBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_st 12"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down&!buff.deathblow.react&cooldown.aimed_shot.charges>0
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff) and Player:BuffDown(S.DeathblowBuff) and S.AimedShot:Charges() > 0) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot dr_st 14"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown) then
    if Cast(S.ArcaneShot, Settings.Marksmanship.GCDasOffGCD.ArcaneShot, nil, not TargetInRange40y) then return "arcane_shot dr_st 16"; end
  end
  -- aimed_shot,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_st 18"; end
  end
  -- explosive_shot,if=talent.shrapnel_shot&buff.lock_and_load.down
  if S.ExplosiveShot:IsReady() and (S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.LockandLoadBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_st 20"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_st 22"; end
  end
end

local function SentST()
  -- explosive_shot,if=talent.precision_detonation&action.aimed_shot.in_flight&buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and S.AimedShot:InFlight() and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_st 2"; end
  end
  -- volley,if=buff.double_tap.down&(!raid_event.adds.exists|raid_event.adds.in>cooldown)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley sent_st 4"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot sent_st 6"; end
  end
  -- steady_shot,if=(talent.black_arrow|bugs)&focus+cast_regen<focus.max&action.aimed_shot.in_flight&!buff.deathblow.react&buff.trueshot.down&cooldown.trueshot.remains
  if S.SteadyShot:IsCastable() and (CheckFocusCap(S.SteadyShot:CastTime()) and S.AimedShot:InFlight() and Player:BuffDown(S.DeathblowBuff) and Player:BuffDown(S.TrueshotBuff) and S.Trueshot:CooldownDown()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot sent_st 8"; end
  end
  -- rapid_fire,if=talent.lunar_storm&buff.lunar_storm_cooldown.down
  if S.RapidFire:IsCastable() and (S.LunarStorm:IsAvailable() and Player:BuffDown(S.LunarStormCDBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_st 10"; end
  end
  -- kill_shot,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  if S.KillShot:IsReady() and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot sent_st 12"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown) then
    if Cast(S.ArcaneShot, Settings.Marksmanship.GCDasOffGCD.ArcaneShot, nil, not TargetInRange40y) then return "arcane_shot sent_st 14"; end
  end
  -- aimed_shot,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  if S.AimedShot:IsReady() and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and S.AimedShot:FullRechargeTime() < S.RapidFire:ExecuteTime() + S.AimedShot:CastTime() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff)) and S.WindrunnerQuiver:IsAvailable()) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot sent_st 16"; end
  end
  -- rapid_fire
  if S.RapidFire:IsCastable() then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_st 18"; end
  end
  -- aimed_shot,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot sent_st 20"; end
  end
  -- explosive_shot,if=talent.precision_detonation|buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() or Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_st 22"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot sent_st 24"; end
  end
end

local function Cleave()
  -- explosive_shot,if=talent.precision_detonation&action.aimed_shot.in_flight&(buff.trueshot.down|!talent.windrunner_quiver)
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and S.AimedShot:InFlight() and (Player:BuffDown(S.TrueshotBuff) or not S.WindrunnerQuiver:IsAvailable())) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot cleave 2"; end
  end
  -- black_arrow,if=buff.precise_shots.up&buff.moving_target.down&variable.trueshot_ready
  if S.BlackArrow:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and Player:BuffDown(S.MovingTargetBuff) and VarTrueshotReady) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow cleave 4"; end
  end
  -- volley,if=(talent.double_tap&buff.double_tap.down|!talent.aspect_of_the_hydra)&(buff.precise_shots.down|buff.moving_target.up)
  if S.Volley:IsReady() and ((S.DoubleTap:IsAvailable() and Player:BuffDown(S.DoubleTapBuff) or not S.AspectoftheHydra:IsAvailable()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley cleave 6"; end
  end
  -- rapid_fire,if=talent.bulletstorm&buff.bulletstorm.down&(!talent.double_tap|buff.double_tap.up|!talent.aspect_of_the_hydra&buff.trick_shots.remains>execute_time)&(buff.precise_shots.down|buff.moving_target.up|!talent.volley)
  if S.RapidFire:IsCastable() and (S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff) and (not S.DoubleTap:IsAvailable() or Player:BuffUp(S.DoubleTapBuff) or not S.AspectoftheHydra:IsAvailable() and Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or not S.Volley:IsAvailable())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire cleave 8"; end
  end
  -- volley,if=!talent.double_tap&(buff.precise_shots.down|buff.moving_target.up)
  if S.Volley:IsReady() and (not S.DoubleTap:IsAvailable() and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley cleave 10"; end
  end
  -- trueshot,if=variable.trueshot_ready&(buff.double_tap.down|!talent.volley)&(buff.lunar_storm_ready.down|!talent.double_tap|!talent.volley)&(buff.precise_shots.down|buff.moving_target.up|!talent.volley)
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and (Player:BuffDown(S.DoubleTapBuff) or not S.Volley:IsAvailable()) and (Player:BuffDown(S.LunarStormReadyBuff) or not S.DoubleTap:IsAvailable() or not S.Volley:IsAvailable()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or not S.Volley:IsAvailable())) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot cleave 12"; end
  end
  -- steady_shot,if=(talent.black_arrow|bugs)&focus+cast_regen<focus.max&action.aimed_shot.in_flight&!buff.deathblow.react&buff.trueshot.down&cooldown.trueshot.remains
  if S.SteadyShot:IsCastable() and (S.BlackArrow:IsAvailable() and CheckFocusCap(S.SteadyShot:CastTime()) and S.AimedShot:InFlight() and Player:BuffDown(S.DeathblowBuff) and Player:BuffDown(S.TrueshotBuff) and S.Trueshot:CooldownDown()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot cleave 14"; end
  end
  -- rapid_fire,if=talent.lunar_storm&buff.lunar_storm_cooldown.down&(buff.precise_shots.down|buff.moving_target.up|cooldown.volley.remains&cooldown.trueshot.remains|!talent.volley)
  if S.RapidFire:IsCastable() and (S.LunarStorm:IsAvailable() and Player:BuffDown(S.LunarStormCDBuff) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or S.Volley:CooldownDown() and S.Trueshot:CooldownDown() or not S.Volley:IsAvailable())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire cleave 14"; end
  end
  -- kill_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  if S.KillShot:IsReady() then
    if Everyone.CastCycle(S.KillShot, Enemies10ySplash, EvaluateCycleKillShotCleave, not TargetInRange40y) then return "kill_shot cleave 16"; end
  end
  -- black_arrow,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  if S.BlackArrow:IsReady() and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow cleave 20"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)&!talent.aspect_of_the_hydra&(talent.symphonic_arsenal|talent.small_game_hunter)
  if S.MultiShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and not S.AspectoftheHydra:IsAvailable() and (S.SymphonicArsenal:IsAvailable() or S.SmallGameHunter:IsAvailable())) then
    if Everyone.CastCycle(S.MultiShot, Enemies10ySplash, EvaluateCycleMultiShotCleave, not TargetInRange40y) then return "multishot cleave 22"; end
  end
  -- arcane_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff)) then
    if Everyone.CastCycle(S.ArcaneShot, Enemies10ySplash, EvaluateCycleArcaneShotCleave, not TargetInRange40y) then return "arcane_shot cleave 24"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  if S.AimedShot:IsReady() and (S.AimedShot:FullRechargeTime() < S.RapidFire:ExecuteTime() + S.AimedShot:CastTime() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff)) and S.WindrunnerQuiver:IsAvailable()) then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleAimedShotCleave, not TargetInRange40y) then return "aimed_shot cleave 26"; end
  end
  -- rapid_fire,if=!talent.bulletstorm|buff.bulletstorm.stack<=10|talent.aspect_of_the_hydra
  if S.RapidFire:IsCastable() and (not S.Bulletstorm:IsAvailable() or Player:BuffStack(S.BulletstormBuff) <= 10 or S.AspectoftheHydra:IsAvailable()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire cleave 28"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up|max_prio_damage,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleAimedShotCleave, not TargetInRange40y) then return "aimed_shot cleave 30"; end
  end
  -- rapid_fire
  if S.RapidFire:IsCastable() then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire cleave 32"; end
  end
  -- explosive_shot,if=talent.precision_detonation|buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() or Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot cleave 34"; end
  end
  -- black_arrow,if=!talent.headshot
  if S.BlackArrow:IsReady() and (not S.Headshot:IsAvailable()) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow cleave 36"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot cleave 38"; end
  end
end

local function Trickshots()
  -- explosive_shot,if=talent.precision_detonation&action.aimed_shot.in_flight&buff.trueshot.down&(!talent.shrapnel_shot|buff.lock_and_load.down)
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and S.AimedShot:InFlight() and Player:BuffDown(S.TrueshotBuff) and (not S.ShrapnelShot:IsAvailable() or Player:BuffDown(S.LockandLoadBuff))) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 2"; end
  end
  -- volley,if=buff.double_tap.down&(!talent.shrapnel_shot|buff.lock_and_load.down)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff) and (not S.ShrapnelShot:IsAvailable() or Player:BuffDown(S.LockandLoadBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley trickshots 4"; end
  end
  -- rapid_fire,if=talent.bulletstorm&buff.bulletstorm.down&buff.trick_shots.remains>execute_time
  if S.RapidFire:IsCastable() and (S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff) and Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 6"; end
  end
  -- rapid_fire,if=hero_tree.sentinel&buff.lunar_storm_cooldown.down&buff.trick_shots.remains>execute_time
  if S.RapidFire:IsCastable() and (Player:HeroTreeID() == 42 and Player:BuffDown(S.LunarStormCDBuff) and Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 8"; end
  end
  -- steady_shot,if=talent.black_arrow&focus+cast_regen<focus.max&action.aimed_shot.in_flight&!buff.deathblow.react&buff.trueshot.down&cooldown.trueshot.remains
  if S.SteadyShot:IsCastable() and (S.BlackArrow:IsAvailable() and Player:Focus() + Player:FocusCastRegen(S.SteadyShot:CastTime()) < Player:FocusMax() and S.AimedShot:InFlight() and Player:BuffDown(S.DeathblowBuff) and Player:BuffDown(S.TrueshotBuff) and S.Trueshot:CooldownDown()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 10"; end
  end
  -- black_arrow,if=!talent.headshot|buff.precise_shots.up|buff.trick_shots.down
  if S.BlackArrow:IsReady() and (not S.Headshot:IsAvailable() or Player:BuffUp(S.PreciseShotsBuff) or Player:BuffDown(S.TrickShotsBuff)) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow trickshots 12"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target,if=buff.precise_shots.up&buff.moving_target.down|buff.trick_shots.down
  if S.MultiShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and Player:BuffDown(S.MovingTargetBuff) or Player:BuffDown(S.TrickShotsBuff)) then
    if Everyone.CastCycle(S.MultiShot, Enemies10ySplash, EvaluateCycleMultiShotTS, not TargetInRange40y) then return "multishot trickshots 14"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot trickshots 16"; end
  end
  -- volley,if=buff.double_tap.down&(!talent.salvo|!talent.precision_detonation|(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up))
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff) and (not S.Salvo:IsAvailable() or not S.PrecisionDetonation:IsAvailable() or (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley trickshots 18"; end
  end
  -- aimed_shot,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.trick_shots.up&buff.bulletstorm.up&full_recharge_time<gcd
  if S.AimedShot:IsReady() and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.TrickShotsBuff) and Player:BuffUp(S.BulletstormBuff) and S.AimedShot:FullRechargeTime() < Player:GCD()) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot trickshots 20"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time&(!talent.black_arrow|buff.deathblow.down)&(!talent.no_scope|debuff.spotters_mark.down)&(talent.no_scope|buff.bulletstorm.down)
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime() and (not S.BlackArrow:IsAvailable() or Player:BuffDown(S.DeathblowBuff)) and (not S.NoScope:IsAvailable() or Target:DebuffDown(S.SpottersMarkDebuff)) and (S.NoScope:IsAvailable() or Player:BuffDown(S.BulletstormBuff))) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 22"; end
  end
  -- explosive_shot,if=talent.precision_detonation&talent.shrapnel_shot&buff.lock_and_load.down&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.LockandLoadBuff) and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 24"; end
  end
  -- aimed_shot,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.trick_shots.up
  if S.AimedShot:IsReady() and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.TrickShotsBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot trickshots 26"; end
  end
  -- explosive_shot,if=talent.precision_detonation&!talent.shrapnel_shot
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and not S.ShrapnelShot:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 28"; end
  end
  -- ssteady_shot,if=(talent.lunar_storm&focus+cast_regen<focus.max)|talent.black_arrow
  if S.SteadyShot:IsCastable() and ((S.LunarStorm:IsAvailable() and Player:Focus() + Player:FocusCastRegen(S.SteadyShot:CastTime()) < Player:FocusMax()) or S.BlackArrow:IsAvailable()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 30"; end
  end
  -- multishot,if=!talent.black_arrow
  if S.MultiShot:IsReady() and (not S.BlackArrow:IsAvailable()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 24"; end
  end
end

--- ===== APL Main =====
local function APL()
  TargetInRange40y = Target:IsSpellInRange(S.AimedShot) -- Ranged abilities; Distance varies by Mastery
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

    -- (debuff.spotters_mark.down|buff.moving_target.down)
    -- This is used throughout the APL, so let's just check it once.
    VarSpotterOrMovingDown = Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)
  end

  -- Pet Management
  if S.UnbreakableBond:IsAvailable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if S.SummonPet:IsCastable() then
      if Cast(SummonPetSpells[Settings.Commons.SummonPetSlot], Settings.CommonsOGCD.GCDasOffGCD.SummonPet) then return "Summon Pet"; end
    end
  end

  if Everyone.TargetIsValid() then
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Self heal, if below setting value
    if S.Exhilaration:IsReady() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.CommonsOGCD.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.CounterShot, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- variable,name=trueshot_ready,value=!talent.bullseye|fight_remains>cooldown.trueshot.duration+buff.trueshot.duration|buff.bullseye.stack=buff.bullseye.max_stack|fight_remains<25
    local TrueshotCD = 120 - num(S.CallingtheShots:IsAvailable()) * 30 - num(Player:HasTier("TWW3", 2)) * 30
    VarTrueshotReady = not S.Bullseye:IsAvailable() or FightRemains > TrueshotCD + 15 or Player:BuffStack(S.BullseyeBuff) == 30 or BossFightRemains < 25
    -- auto_shot
    -- call_action_list,name=cds
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trickshots,if=active_enemies>2&talent.trick_shots
    if EnemiesCount10ySplash > 2 and S.TrickShots:IsAvailable() then
      local ShouldReturn = Trickshots(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=cleave,if=active_enemies>1
    if EnemiesCount10ySplash > 1 then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=drst,if=active_enemies=1&talent.black_arrow
    if EnemiesCount10ySplash == 1 and S.BlackArrow:IsAvailable() then
      local ShouldReturn = DRST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentst,if=active_enemies=1&!talent.black_arrow
    if EnemiesCount10ySplash == 1 and not S.BlackArrow:IsAvailable() then
      local ShouldReturn = SentST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool Focus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function Init()
  HR.Print("Marksmanship Hunter rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(254, APL, Init)
