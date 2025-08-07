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
  -- I.ItemName:ID(),
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
local VarStrongerTrinketSlot
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

  VarStrongerTrinketSlot = 2
  if VarTrinket2ID ~= I.HouseofCards:ID() and (VarTrinket1ID == I.HouseofCards:ID() or not Trinket2:HasCooldown() or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (VarTrinket2CD < VarTrinket1CD or VarTrinket2CastTime < VarTrinket1CastTime or VarTrinket2CastTime == VarTrinket1CastTime and VarTrinket2CD == VarTrinket1CD))) then
    VarStrongerTrinketSlot = 1
  end
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

--- ===== CastTargetIf Filter Functions =====
local function EvaluateTargetIfFilterBlackArrow(TargetUnit)
  -- target_if=min:dot.black_arrow_dot.ticking|max_prio_damage
  return TargetUnit:DebuffRemains(S.BlackArrowDebuff)
end

--- ===== CastTargetIf Condition Functions =====
local function EvaluateTargetIfBlackArrowST(TargetUnit)
  -- if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  return S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)
end

local function EvaluateCycleKillShotST(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight()) and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff))
end

--- ===== CastCycle Functions =====
local function EvaluateCycleAimedShotST(TargetUnit)
  -- target_if=max:debuff.spotters_mark.up,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  return TargetUnit:DebuffUp(S.SpottersMarkDebuff) and ((Player:BuffDown(S.PreciseShotsBuff) or TargetUnit:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and S.AimedShot:FullRechargeTime() < S.RapidFire:ExecuteTime() + S.AimedShot:CastTime() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff)) and S.WindrunnerQuiver:IsAvailable())
end

local function EvaluateCycleAimedShotST2(TargetUnit)
  -- target_if=max:debuff.spotters_mark.up|max_prio_damage,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  return TargetUnit:DebuffUp(S.SpottersMarkDebuff) and (Player:BuffDown(S.PreciseShotsBuff) or TargetUnit:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff))
end

local function EvaluateCycleArcaneShotST(TargetUnit)
  -- target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  return (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or S.AimedShot:InFlight()) and (Player:BuffUp(S.PreciseShotsBuff) and (TargetUnit:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)))
end

--- ===== Rotation Functions =====
local function Precombat()
  -- snapshot_stats
  -- variable,name=stronger_trinket_slot,op=setif,value=1,value_else=2,condition=!trinket.2.is.house_of_cards&(trinket.1.is.house_of_cards|!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration)))
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- summon_pet,if=talent.unbreakable_bond
  -- Note: Moved to APL()
  -- aimed_shot,if=active_enemies=1|active_enemies=2&!talent.volley
  -- Note: We can't actually get target counts before combat begins.
  if S.AimedShot:IsReady() and not Player:IsCasting(S.AimedShot) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot precombat 2"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() and not Player:IsCasting(S.AimedShot) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot precombat 4"; end
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

local function ST()
  -- volley,if=!talent.double_tap&(talent.aspect_of_the_hydra|active_enemies=1|buff.precise_shots.down&(cooldown.rapid_fire.remains+action.rapid_fire.execute_time<6|!talent.bulletstorm))&(!raid_event.adds.exists|raid_event.adds.in>cooldown|active_enemies>1)
  if S.Volley:IsReady() and (not S.DoubleTap:IsAvailable() and (S.AspectoftheHydra:IsAvailable() or EnemiesCount10ySplash == 1 or Player:BuffDown(S.PreciseShotsBuff) and (S.RapidFire:CooldownRemains() + S.RapidFire:ExecuteTime() < 6 or not S.Bulletstorm:IsAvailable()))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 2"; end
  end
  -- rapid_fire,if=hero_tree.sentinel&buff.lunar_storm_cooldown.down|!talent.aspect_of_the_hydra&talent.bulletstorm&active_enemies>1&buff.trick_shots.up&(buff.precise_shots.down|!talent.no_scope)
  if S.RapidFire:IsCastable() and (Player:HeroTreeID() == 42 and Player:BuffUp(S.LunarStormReadyBuff) or not S.AspectoftheHydra:IsAvailable() and S.Bulletstorm:IsAvailable() and EnemiesCount10ySplash > 1 and Player:BuffUp(S.TrickShotsBuff) and (Player:BuffDown(S.PreciseShotsBuff) or not S.NoScope:IsAvailable())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire st 4"; end
  end
  -- trueshot,if=variable.trueshot_ready
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot st 6"; end
  end
  -- explosive_shot,if=talent.precision_detonation&set_bonus.thewarwithin_season_2_4pc&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.lock_and_load.up
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and Player:HasTier("TWW2", 4) and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.LockandLoadBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 8"; end
  end
  -- aimed_shot,if=talent.precision_detonation&set_bonus.thewarwithin_season_2_4pc&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.lock_and_load.up
  if S.AimedShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and Player:HasTier("TWW2", 4) and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.LockandLoadBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot st 10"; end
  end
  -- volley,if=talent.double_tap&buff.double_tap.down
  if S.Volley:IsReady() and (S.DoubleTap:IsAvailable() and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 12"; end
  end
  -- kill_shot,target_if=min:dot.black_arrow_dot.ticking|max_prio_damage,if=talent.black_arrow&(talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up)
  if S.BlackArrow:IsReady() and Settings.Marksmanship.MaxPrioDamage and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow st 14"; end
  end
  if S.BlackArrow:IsReady() and not Settings.Marksmanship.MaxPrioDamage then
    if Everyone.CastTargetIf(S.BlackArrow, Enemies10ySplash, "min", EvaluateTargetIfFilterBlackArrow, EvaluateTargetIfBlackArrowST, not TargetInRange40y) then return "black_arrow st 16"; end
  end
  -- kill_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=!talent.black_arrow&(talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up)
  if S.KillShot:IsReady() and Settings.Marksmanship.MaxPrioDamage and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 18"; end
  end
  if S.KillShot:IsReady() and not Settings.Marksmanship.MaxPrioDamage then
    if Everyone.CastCycle(S.KillShot, Enemies10ySplash, EvaluateCycleKillShotST, not TargetInRange40y) then return "kill_shot st 20"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)&active_enemies>1&!talent.aspect_of_the_hydra&(talent.symphonic_arsenal|talent.small_game_hunter)
  -- Note: Skipping target_if, since MultiShot should hit all targets in Enemies10ySplash anyway.
  if S.MultiShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) and EnemiesCount10ySplash > 1 and not S.AspectoftheHydra:IsAvailable() and (S.SymphonicArsenal:IsAvailable() or S.SmallGameHunter:IsAvailable())) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot st 22"; end
  end
  -- arcane_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and Settings.Marksmanship.MaxPrioDamage and (Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff))) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 24"; end
  end
  if S.ArcaneShot:IsReady() and not Settings.Marksmanship.MaxPrioDamage then
    if Everyone.CastCycle(S.ArcaneShot, Enemies10ySplash, EvaluateCycleArcaneShotST, not TargetInRange40y) then return "arcane_shot st 26"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  if S.AimedShot:IsReady() and Settings.Marksmanship.MaxPrioDamage and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and S.AimedShot:FullRechargeTime() < S.RapidFire:ExecuteTime() + S.AimedShot:CastTime() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff)) and S.WindrunnerQuiver:IsAvailable()) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot st 28"; end
  end
  if S.AimedShot:IsReady() and not Settings.Marksmanship.MaxPrioDamage then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleAimedShotST, not TargetInRange40y) then return "aimed_shot st 30"; end
  end
  -- rapid_fire,if=(!hero_tree.sentinel|buff.lunar_storm_cooldown.remains>cooldown%3)&(!talent.bulletstorm|buff.bulletstorm.stack<=10|talent.aspect_of_the_hydra&active_enemies>1)
  if S.RapidFire:IsCastable() and ((Player:HeroTreeID() ~= 42 or Player:BuffRemains(S.LunarStormCDBuff) > 20 / 3) and (not S.Bulletstorm:IsAvailable() or Player:BuffStack(S.BulletstormBuff) <= 10 or S.AspectoftheHydra:IsAvailable() and EnemiesCount10ySplash > 1)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire st 32"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up|max_prio_damage,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() and Settings.Marksmanship.MaxPrioDamage and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot st 34"; end
  end
  if S.AimedShot:IsReady() and not Settings.Marksmanship.MaxPrioDamage then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleAimedShotST2, not TargetInRange40y) then return "aimed_shot st 36"; end
  end
  -- explosive_shot,if=!set_bonus.thewarwithin_season_2_4pc|!talent.precision_detonation
  if S.ExplosiveShot:IsReady() and (not Player:HasTier("TWW2", 4) or not S.PrecisionDetonation:IsAvailable()) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 38"; end
  end
  -- kill_shot,if=talent.black_arrow&!talent.headshot
  if S.BlackArrow:IsReady() and (not S.Headshot:IsAvailable()) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow st 40"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 42"; end
  end
end

local function Trickshots()
  -- volley,if=!talent.double_tap
  if S.Volley:IsReady() and (not S.DoubleTap:IsAvailable()) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley trickshots 2"; end
  end
  -- trueshot,if=variable.trueshot_ready
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot trickshots 4"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|buff.trick_shots.down
  -- Note: Skipping target_if, since MultiShot should hit all targets in Enemies10ySplash anyway.
  if S.MultiShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and (Target:DebuffDown(S.SpottersMarkDebuff) or Player:BuffDown(S.MovingTargetBuff)) or Player:BuffDown(S.TrickShotsBuff)) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 6"; end
  end
  -- volley,if=talent.double_tap&buff.double_tap.down
  if S.Volley:IsReady() and (S.DoubleTap:IsAvailable() and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley trickshots 8"; end
  end
  -- kill_shot,if=talent.black_arrow&buff.trick_shots.up
  if S.BlackArrow:IsReady() and (Player:BuffUp(S.TrickShotsBuff)) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow trickshots 10"; end
  end
  -- aimed_shot,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.trick_shots.up&buff.bulletstorm.up&full_recharge_time<gcd
  if S.AimedShot:IsReady() and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.TrickShotsBuff) and Player:BuffUp(S.BulletstormBuff) and S.AimedShot:FullRechargeTime() < Player:GCD()) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot trickshots 12"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time&(!hero_tree.sentinel|buff.lunar_storm_cooldown.remains>cooldown%3|buff.lunar_storm_cooldown.down)
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime() and (Player:HeroTreeID() ~= 42 or Player:BuffRemains(S.LunarStormCDBuff) > 20 / 3 or Player:BuffUp(S.LunarStormReadyBuff))) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 14"; end
  end
  -- explosive_shot,if=talent.precision_detonation&(buff.lock_and_load.up|!set_bonus.thewarwithin_season_2_4pc)&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and (Player:BuffUp(S.LockandLoadBuff) or not Player:HasTier("TWW2", 4)) and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 16"; end
  end
  -- aimed_shot,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&buff.trick_shots.up
  if S.AimedShot:IsReady() and ((Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) and Player:BuffUp(S.TrickShotsBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot trickshots 18"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 20"; end
  end
  -- steady_shot,if=focus+cast_regen<focus.max
  if S.SteadyShot:IsCastable() and (Player:Focus() + Player:FocusCastRegen(S.SteadyShot:CastTime()) < Player:FocusMax()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 22"; end
  end
  -- multishot
  if S.MultiShot:IsReady() then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 24"; end
  end
end

local function Trinkets()
  -- variable,name=buff_sync_ready,value=cooldown.trueshot.ready
  local VarBuffSyncReady = S.Trueshot:CooldownUp()
  -- variable,name=buff_sync_remains,value=cooldown.trueshot.remains
  local VarBuffSyncRemains = S.Trueshot:CooldownRemains()
  -- variable,name=buff_sync_active,value=buff.trueshot.up
  local VarBuffSyncActive = Player:BuffUp(S.TrueshotBuff)
  -- variable,name=damage_sync_active,value=buff.trueshot.up
  local VarDamageSyncActive = Player:BuffUp(S.TrueshotBuff)
  -- variable,name=damage_sync_remains,value=cooldown.trueshot.remains
  local VarDamageSyncRemains = S.Trueshot:CooldownRemains()
  if Settings.Commons.Enabled.Trinkets then
    -- use_items,slots=trinket1:trinket2,if=this_trinket.has_use_buff&(variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)|!variable.buff_sync_ready&(variable.stronger_trinket_slot=this_trinket_slot&(variable.buff_sync_remains>this_trinket.cooldown.duration%3&fight_remains>this_trinket.cooldown.duration+20|other_trinket.has_use_buff&other_trinket.cooldown.remains>variable.buff_sync_remains-15&other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains+45>fight_remains)|variable.stronger_trinket_slot!=this_trinket_slot&(other_trinket.cooldown.remains&(other_trinket.cooldown.remains-5<variable.buff_sync_remains&variable.buff_sync_remains>=20|other_trinket.cooldown.remains-5>=variable.buff_sync_remains&(variable.buff_sync_remains>this_trinket.cooldown.duration%3|this_trinket.cooldown.duration<fight_remains&(variable.buff_sync_remains+this_trinket.cooldown.duration>fight_remains)))|other_trinket.cooldown.ready&variable.buff_sync_remains>20&variable.buff_sync_remains<other_trinket.cooldown.duration%3)))|!this_trinket.has_use_buff&(this_trinket.cast_time=0|!variable.buff_sync_active)&(!this_trinket.is.junkmaestros_mega_magnet|buff.junkmaestros_mega_magnet.stack>10)&(!other_trinket.has_cooldown&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)|other_trinket.has_cooldown&(!other_trinket.has_use_buff&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|variable.damage_sync_remains>this_trinket.cooldown.duration%3&!this_trinket.is.junkmaestros_mega_magnet|other_trinket.cooldown.remains-5<variable.damage_sync_remains&variable.damage_sync_remains>=20)|other_trinket.has_use_buff&(variable.damage_sync_active|this_trinket.is.junkmaestros_mega_magnet&buff.junkmaestros_mega_magnet.stack>25|!this_trinket.is.junkmaestros_mega_magnet&variable.damage_sync_remains>this_trinket.cooldown.duration%3)&(other_trinket.cooldown.remains>=20|other_trinket.cooldown.remains-5>variable.buff_sync_remains)))|fight_remains<25&(variable.stronger_trinket_slot=this_trinket_slot|other_trinket.cooldown.remains)
    if Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1) and (Trinket1:HasUseBuff() and (VarBuffSyncReady and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) or not VarBuffSyncReady and (VarStrongerTrinketSlot == 1 and (VarBuffSyncRemains > VarTrinket1CD / 3 and BossFightRemains > VarTrinket1CD + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarBuffSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains + 45 > BossFightRemains) or VarStrongerTrinketSlot ~= 1 and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarBuffSyncRemains and (VarBuffSyncRemains > VarTrinket1CD / 3 or VarTrinket1CD < BossFightRemains and (VarBuffSyncRemains + VarTrinket1CD > BossFightRemains))) or Trinket2:CooldownUp() and VarBuffSyncRemains > 20 and VarBuffSyncRemains < VarTrinket2CD / 3))) or not Trinket1:HasUseBuff() and (VarTrinket1CastTime == 0 or not VarBuffSyncActive) and (Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Player:BuffStack(S.JunkmaestrosBuff) > 10) and (not Trinket2:HasCooldown() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket1CD / 3) or Trinket2:HasCooldown() and (not Trinket2:HasUseBuff() and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown()) and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or VarDamageSyncRemains > VarTrinket1CD / 3 and Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Trinket2:CooldownRemains() - 5 < VarDamageSyncRemains and VarDamageSyncRemains >= 20) or Trinket2:HasUseBuff() and (VarDamageSyncActive or Trinket1:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket1:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket1CD / 3) and (Trinket2:CooldownRemains() >= 20 or Trinket2:CooldownRemains() - 5 > VarBuffSyncRemains))) or BossFightRemains < 25 and (VarStrongerTrinketSlot == 1 or Trinket2:CooldownDown())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 2"; end
    end
    if Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2) and (Trinket2:HasUseBuff() and (VarBuffSyncReady and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown()) or not VarBuffSyncReady and (VarStrongerTrinketSlot == 2 and (VarBuffSyncRemains > VarTrinket2CD / 3 and BossFightRemains > VarTrinket2CD + 20 or Trinket1:HasUseBuff() and Trinket1:CooldownRemains() > VarBuffSyncRemains - 15 and Trinket1:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains + 45 > BossFightRemains) or VarStrongerTrinketSlot ~= 2 and (Trinket1:CooldownDown() and (Trinket1:CooldownRemains() - 5 < VarBuffSyncRemains and VarBuffSyncRemains >= 20 or Trinket1:CooldownRemains() - 5 >= VarBuffSyncRemains and (VarBuffSyncRemains > VarTrinket2CD / 3 or VarTrinket2CD < BossFightRemains and (VarBuffSyncRemains + VarTrinket2CD > BossFightRemains))) or Trinket1:CooldownUp() and VarBuffSyncRemains > 20 and VarBuffSyncRemains < VarTrinket1CD / 3))) or not Trinket2:HasUseBuff() and (VarTrinket2CastTime == 0 or not VarBuffSyncActive) and (Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Player:BuffStack(S.JunkmaestrosBuff) > 10) and (not Trinket1:HasCooldown() and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket2CD / 3) or Trinket1:HasCooldown() and (not Trinket1:HasUseBuff() and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown()) and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or VarDamageSyncRemains > VarTrinket2CD / 3 and Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() or Trinket1:CooldownRemains() - 5 < VarDamageSyncRemains and VarDamageSyncRemains >= 20) or Trinket1:HasUseBuff() and (VarDamageSyncActive or Trinket2:ID() == I.JunkmaestrosMegaMagnet:ID() and Player:BuffStack(S.JunkmaestrosBuff) > 25 or Trinket2:ID() ~= I.JunkmaestrosMegaMagnet:ID() and VarDamageSyncRemains > VarTrinket2CD / 3) and (Trinket1:CooldownRemains() >= 20 or Trinket1:CooldownRemains() - 5 > VarBuffSyncRemains))) or BossFightRemains < 25 and (VarStrongerTrinketSlot == 2 or Trinket1:CooldownDown())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 4"; end
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
    -- variable,name=trueshot_ready,value=cooldown.trueshot.ready&((!raid_event.adds.exists|raid_event.adds.count=1)&(!talent.bullseye|fight_remains>cooldown.trueshot.duration_guess+buff.trueshot.duration%2|buff.bullseye.stack=buff.bullseye.max_stack)&(!trinket.1.has_use_buff|trinket.1.cooldown.remains>5|trinket.1.cooldown.ready|trinket.2.has_use_buff&trinket.2.cooldown.ready)&(!trinket.2.has_use_buff|trinket.2.cooldown.remains>5|trinket.2.cooldown.ready|trinket.1.has_use_buff&trinket.1.cooldown.ready)|raid_event.adds.exists&(!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<25|raid_event.adds.in>60)|raid_event.adds.up&raid_event.adds.remains>10)|fight_remains<25)
    -- Note: Can't handle the raid_event conditions.
    -- TODO: Simplify the above condition for HR.
    VarTrueshotReady = S.Trueshot:CooldownUp()
    -- auto_shot
    -- call_action_list,name=cds
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3|!talent.trick_shots
    if EnemiesCount10ySplash < 3 or not S.TrickShots:IsAvailable() then
      local ShouldReturn = ST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trickshots,if=active_enemies>2
    if EnemiesCount10ySplash > 2 then
      local ShouldReturn = Trickshots(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool Focus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function Init()
  HR.Print("Marksmanship Hunter rotation has been updated for patch 11.1.5.")
end

HR.SetAPL(254, APL, Init)
