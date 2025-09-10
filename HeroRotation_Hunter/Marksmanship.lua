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
-- Lua
local mathfloor  = math.floor
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
local VarBufferDeathblow = false
local VarSyncActive = false
local VarSyncReady = false
local VarSyncRemains = 0
local TWW3_2pc = Player:HasTier("TWW3", 2)
local TWW3_4pc = Player:HasTier("TWW3", 4)
local TrueshotCD = 120 - num(S.CallingtheShots:IsAvailable()) * 30 - num(TWW3_2pc) * 30
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
  TWW3_2pc = Player:HasTier("TWW3", 2)
  TWW3_4pc = Player:HasTier("TWW3", 4)
  VarTrinketFailures = 0
  TrueshotCD = 120 - num(S.CallingtheShots:IsAvailable()) * 30 - num(TWW3_2pc) * 30
  SetTrinketVariables()
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.AimedShot:RegisterInFlight()
  TWW3_2pc = Player:HasTier("TWW3", 2)
  TWW3_4pc = Player:HasTier("TWW3", 4)
  TrueshotCD = 120 - num(S.CallingtheShots:IsAvailable()) * 30 - num(TWW3_2pc) * 30
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
  -- target_if=max:debuff.spotters_mark.up|max_prio_damage
  return TargetUnit:DebuffUp(S.SpottersMarkDebuff) or Settings.Marksmanship.MaxPrioDamage
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

local function EvaluateCycleSpotter(TargetUnit)
  -- target_if=max:debuff.spotters_mark.up
  return TargetUnit:DebuffUp(S.SpottersMarkDebuff)
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
    local T1Check = Trinket1 and Trinket1:IsReady() and not VarTrinket1Ex and not Player:IsItemBlacklisted(Trinket1)
    local T2Check = Trinket2 and Trinket2:IsReady() and not VarTrinket2Ex and not Player:IsItemBlacklisted(Trinket2)
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.unyielding_netherprism&this_trinket.has_use_buff&this_trinket.cooldown.duration%%cooldown.trueshot.duration=0&buff.trueshot.remains>14
    if T1Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket1:HasUseBuff() and VarTrinket1CD % TrueshotCD == 0 and Player:BuffRemains(S.TrueshotBuff) > 14) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 2"; end
    end
    if T2Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket2:HasUseBuff() and VarTrinket2CD % TrueshotCD == 0 and Player:BuffRemains(S.TrueshotBuff) > 14) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 4"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!equipped.unyielding_netherprism&this_trinket.has_use_buff&other_trinket.cooldown.duration%%cooldown.trueshot.duration=0&(buff.trueshot.remains>14&other_trinket.cooldown.remains|cooldown.trueshot.remains>20&other_trinket.cooldown.remains<=cooldown.trueshot.remains)
    if T1Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket1:HasUseBuff() and VarTrinket2CD % TrueshotCD == 0 and (Player:BuffRemains(S.TrueshotBuff) > 14 and Trinket2:CooldownDown() or S.Trueshot:CooldownRemains() > 20 and Trinket2:CooldownRemains() <= S.Trueshot:CooldownRemains())) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 6"; end
    end
    if T2Check and (not I.UnyieldingNetherprism:IsEquipped() and Trinket2:HasUseBuff() and VarTrinket1CD % TrueshotCD == 0 and (Player:BuffRemains(S.TrueshotBuff) > 14 and Trinket1:CooldownDown() or S.Trueshot:CooldownRemains() > 20 and Trinket1:CooldownRemains() <= S.Trueshot:CooldownRemains())) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 8"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=this_trinket.is.unyielding_netherprism&(buff.trueshot.remains>14&(buff.latent_energy.stack>(19-cooldown.trueshot.duration%10)|fight_remains<(cooldown.trueshot.duration+20))|fight_remains<22&(buff.latent_energy.stack>8|!other_trinket.has_use_buff|other_trinket.cooldown.remains))
    local OtherTrinket = Trinket2
    if VarTrinket2ID == I.UnyieldingNetherprism:ID() then OtherTrinket = Trinket1 end
    if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffRemains(S.TrueshotBuff) > 14 and (Player:BuffStack(S.LatentEnergyBuff) > (19 - TrueshotCD / 10) or BossFightRemains < (TrueshotCD + 20)) or BossFightRemains < 22 and (Player:BuffStack(S.LatentEnergyBuff) > 8 or OtherTrinket:HasUseBuff() or OtherTrinket:CooldownDown())) then
      if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "unyielding_netherprism trinket 10"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=!this_trinket.is.unyielding_netherprism&this_trinket.has_use_buff&(other_trinket.is.unyielding_netherprism&fight_remains<cooldown.trueshot.remains+cooldown.trueshot.duration+10&cooldown.trueshot.remains>20|buff.trueshot.remains>14|buff.trueshot.up&fight_remains<cooldown.trueshot.remains+15|fight_remains<21)
    if I.UnyieldingNetherprism:IsReady() and (BossFightRemains < S.Trueshot:CooldownRemains() + TrueshotCD + 10 and S.Trueshot:CooldownRemains() > 20 or Player:BuffRemains(S.TrueshotBuff) > 14 or Player:BuffUp(S.TrueshotBuff) and BossFightRemains < S.Trueshot:CooldownRemains() + 15 or BossFightRemains < 21) then
      if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 12"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=this_trinket.is.unyielding_netherprism&buff.trueshot.remains>14&buff.latent_energy.stack>3&(buff.latent_energy.stack+floor((fight_remains-20)%cooldown.trueshot.duration)*(cooldown.trueshot.duration%10))>17
    if I.UnyieldingNetherprism:IsEquippedAndReady() and (Player:BuffRemains(S.TrueshotBuff) > 14 and Player:BuffStack(S.LatentEnergyBuff) > 3 and (Player:BuffStack(S.LatentEnergyBuff) + mathfloor((BossFightRemains - 20) / TrueshotCD) * (TrueshotCD / 10)) > 17) then
      if Cast(I.UnyieldingNetherprism, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "unyielding_netherprism (" .. Trinket1:Name() .. ") trinkets 14"; end
    end
    -- use_items,check_existing=0,slots=trinket1:trinket2,if=this_trinket.has_use_damage&cooldown.trueshot.remains>20
    if T1Check and (Trinket1:HasUseDamage() and S.Trueshot:CooldownRemains() > 20) then
      if Cast(Trinket1, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") trinkets 16"; end
    end
    if T2Check and (Trinket2:HasUseDamage() and S.Trueshot:CooldownRemains() > 20) then
      if Cast(Trinket2, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(VarTrinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") trinkets 18"; end
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
  -- explosive_shot,if=talent.precision_detonation&buff.lock_and_load.down&cooldown.aimed_shot.charges_fractional<=1.1&buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:ChargesFractional() <= 1.1 and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_st 2"; end
  end
  -- volley,if=buff.double_tap.down&(!raid_event.adds.exists|raid_event.adds.in>cooldown)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley dr_st 4"; end
  end
  -- steady_shot,if=variable.buffer_deathblow&buff.trueshot.down&cooldown.trueshot.remains
  if S.SteadyShot:IsCastable() and (VarBufferDeathblow and Player:BuffDown(S.TrueshotBuff) and S.Trueshot:CooldownDown()) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_st 6"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down&!action.black_arrow.ready&(!talent.bulletstorm|buff.bulletstorm.up)
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff) and not S.BlackArrow:IsReady() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff))) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot dr_st 8"; end
  end
  -- black_arrow,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot
  if S.BlackArrow:IsReady() and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown or not S.Headshot:IsAvailable()) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow dr_st 10"; end
  end
  -- aimed_shot,if=(buff.trueshot.up|action.black_arrow.ready)&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up
  if S.AimedShot:IsReady() and ((Player:BuffUp(S.TrueshotBuff) or S.BlackArrow:IsReady()) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_st 12"; end
  end
  -- rapid_fire,if=!action.black_arrow.ready
  if S.RapidFire:IsCastable() and (not S.BlackArrow:IsReady()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_st 14"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot dr_st 16"; end
  end
  -- aimed_shot,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_st 18"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)&(cooldown.black_arrow.remains>action.steady_shot.execute_time|target.health.pct<80&target.health.pct>20)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown and (S.BlackArrow:CooldownRemains() > S.SteadyShot:ExecuteTime() or Target:HealthPercentage() < 80 and Target:HealthPercentage() > 20)) then
    if Cast(S.ArcaneShot, Settings.Marksmanship.GCDasOffGCD.ArcaneShot, nil, not TargetInRange40y) then return "arcane_shot dr_st 20"; end
  end
  -- explosive_shot,if=talent.shrapnel_shot&buff.lock_and_load.down
  if S.ExplosiveShot:IsReady() and (S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.LockandLoadBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_st 22"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_st 24"; end
  end
end

local function SentST()
  -- explosive_shot,if=talent.shrapnel_shot&buff.lock_and_load.down&cooldown.aimed_shot.charges_fractional<=1.1&buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:ChargesFractional() <= 1.1 and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_st 2"; end
  end
  -- volley,if=buff.double_tap.down&(!raid_event.adds.exists|raid_event.adds.in>cooldown)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley sent_st 4"; end
  end
  -- rapid_fire,if=talent.lunar_storm&buff.lunar_storm_cooldown.down
  if S.RapidFire:IsCastable() and (S.LunarStorm:IsAvailable() and Player:BuffDown(S.LunarStormCDBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_st 6"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down&(!talent.bulletstorm|buff.bulletstorm.up)
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff) and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff))) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot sent_st 8"; end
  end
  -- kill_shot,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  if S.KillShot:IsReady() and (S.Headshot:IsAvailable() and Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown or not S.Headshot:IsAvailable() and Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot sent_st 10"; end
  end
  -- aimed_shot,if=buff.trueshot.up&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffUp(S.TrueshotBuff) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot sent_st 12"; end
  end
  -- rapid_fire,if=!talent.no_scope|buff.precise_shots.down
  if S.RapidFire:IsCastable() and (not S.NoScope:IsAvailable() or Player:BuffDown(S.PreciseShotsBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_st 14"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown) then
    if Cast(S.ArcaneShot, Settings.Marksmanship.GCDasOffGCD.ArcaneShot, nil, not TargetInRange40y) then return "arcane_shot sent_st 16"; end
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

local function DRCleave()
  -- wait,sec=0.05,if=talent.aspect_of_the_hydra&talent.shrapnel_shot&time=0&action.aimed_shot.in_flight
  -- Note: Between the short wait time and "time=0", we're skipping this.
  -- explosive_shot,if=buff.trueshot.down&talent.precision_detonation&(!talent.shrapnel_shot|buff.lock_and_load.down&cooldown.aimed_shot.charges_fractional<=1.1)
  if S.ExplosiveShot:IsReady() and (Player:BuffDown(S.TrueshotBuff) and S.PrecisionDetonation:IsAvailable() and (not S.ShrapnelShot:IsAvailable() or Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:ChargesFractional() <= 1.1)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_cleave 2"; end
  end
  -- black_arrow,if=buff.precise_shots.up|!talent.headshot
  if S.BlackArrow:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or not S.Headshot:IsAvailable()) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow dr_cleave 4"; end
  end
  -- rapid_fire,if=talent.bulletstorm&buff.bulletstorm.down&(talent.aspect_of_the_hydra|!talent.volley|cooldown.volley.remains)
  if S.RapidFire:IsCastable() and (S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff) and (S.AspectoftheHydra:IsAvailable() or not S.Volley:IsAvailable() or S.Volley:CooldownDown())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_cleave 6"; end
  end
  -- volley,if=buff.double_tap.down&(!talent.double_tap|buff.precise_shots.down)&(!talent.shrapnel_shot|!talent.salvo|buff.lock_and_load.down)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff) and (not S.DoubleTap:IsAvailable() or Player:BuffDown(S.PreciseShotsBuff)) and (not S.ShrapnelShot:IsAvailable() or not S.Salvo:IsAvailable() or Player:BuffDown(S.LockandLoadBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley dr_cleave 8"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down&(!talent.volley|cooldown.volley.remains)
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff) and (not S.Volley:IsAvailable() or S.Volley:CooldownDown())) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot dr_cleave 10"; end
  end
  -- steady_shot,if=variable.buffer_deathblow&buff.trueshot.down
  if S.SteadyShot:IsCastable() and (VarBufferDeathblow and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_cleave 12"; end
  end
  -- aimed_shot,if=buff.trueshot.up&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffUp(S.TrueshotBuff) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_cleave 14"; end
  end
  -- rapid_fire,if=buff.double_tap.down
  if S.RapidFire:IsCastable() and (Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_cleave 16"; end
  end
  -- arcane_shot,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and VarSpotterOrMovingDown) then
    if Cast(S.ArcaneShot, Settings.Marksmanship.GCDasOffGCD.ArcaneShot, nil, not TargetInRange40y) then return "arcane_shot dr_cleave 18"; end
  end
  -- aimed_shot,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_cleave 20"; end
  end
  -- explosive_shot,if=!talent.shrapnel_shot|buff.lock_and_load.down
  if S.ExplosiveShot:IsReady() and (not S.ShrapnelShot:IsAvailable() or Player:BuffDown(S.LockandLoadBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_cleave 22"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_cleave 24"; end
  end
end

local function SentCleave()
  -- explosive_shot,if=talent.precision_detonation&action.aimed_shot.in_flight&(buff.trueshot.down|!talent.windrunner_quiver)
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and S.AimedShot:InFlight() and (Player:BuffDown(S.TrueshotBuff) or not S.WindrunnerQuiver:IsAvailable())) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_cleave 2"; end
  end
  -- volley,if=(talent.double_tap&buff.double_tap.down|!talent.aspect_of_the_hydra)&(buff.precise_shots.down|buff.moving_target.up)
  if S.Volley:IsReady() and ((S.DoubleTap:IsAvailable() and Player:BuffDown(S.DoubleTapBuff) or not S.AspectoftheHydra:IsAvailable()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley sent_cleave 4"; end
  end
  -- rapid_fire,if=talent.bulletstorm&buff.bulletstorm.down&(!talent.double_tap|buff.double_tap.up|!talent.aspect_of_the_hydra&buff.trick_shots.remains>execute_time)&(buff.precise_shots.down|buff.moving_target.up|!talent.volley)
  if S.RapidFire:IsCastable() and (S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff) and (not S.DoubleTap:IsAvailable() or Player:BuffUp(S.DoubleTapBuff) or not S.AspectoftheHydra:IsAvailable() and Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or not S.Volley:IsAvailable())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_cleave 6"; end
  end
  -- volley,if=!talent.double_tap&(buff.precise_shots.down|buff.moving_target.up)
  if S.Volley:IsReady() and (not S.DoubleTap:IsAvailable() and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley sent_cleave 8"; end
  end
  -- trueshot,if=variable.trueshot_ready&(buff.double_tap.down|!talent.volley)&(buff.lunar_storm_ready.down|!talent.double_tap|!talent.volley)&(buff.precise_shots.down|buff.moving_target.up|!talent.volley)
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and (Player:BuffDown(S.DoubleTapBuff) or not S.Volley:IsAvailable()) and (Player:BuffDown(S.LunarStormReadyBuff) or not S.DoubleTap:IsAvailable() or not S.Volley:IsAvailable()) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or not S.Volley:IsAvailable())) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot sent_cleave 10"; end
  end
  -- rapid_fire,if=talent.lunar_storm&buff.lunar_storm_cooldown.down&(buff.precise_shots.down|buff.moving_target.up|cooldown.volley.remains&cooldown.trueshot.remains|!talent.volley)
  if S.RapidFire:IsCastable() and (S.LunarStorm:IsAvailable() and Player:BuffDown(S.LunarStormCDBuff) and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.MovingTargetBuff) or S.Volley:CooldownDown() and S.Trueshot:CooldownDown() or not S.Volley:IsAvailable())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_cleave 12"; end
  end
  -- kill_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=talent.headshot&buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)|!talent.headshot&buff.razor_fragments.up
  if S.KillShot:IsReady() then
    if Everyone.CastCycle(S.KillShot, Enemies10ySplash, EvaluateCycleKillShotCleave, not TargetInRange40y) then return "kill_shot sent_cleave 14"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)&!talent.aspect_of_the_hydra
  if S.MultiShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) and not S.AspectoftheHydra:IsAvailable()) then
    if Everyone.CastCycle(S.MultiShot, Enemies10ySplash, EvaluateCycleMultiShotCleave, not TargetInRange40y) then return "multishot sent_cleave 16"; end
  end
  -- arcane_shot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target|max_prio_damage,if=buff.precise_shots.up&(debuff.spotters_mark.down|buff.moving_target.down)
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff)) then
    if Everyone.CastCycle(S.ArcaneShot, Enemies10ySplash, EvaluateCycleArcaneShotCleave, not TargetInRange40y) then return "arcane_shot sent_cleave 18"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up,if=(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)&full_recharge_time<action.rapid_fire.execute_time+cast_time&(!talent.bulletstorm|buff.bulletstorm.up)&talent.windrunner_quiver
  if S.AimedShot:IsReady() and (S.AimedShot:FullRechargeTime() < S.RapidFire:ExecuteTime() + S.AimedShot:CastTime() and (not S.Bulletstorm:IsAvailable() or Player:BuffUp(S.BulletstormBuff)) and S.WindrunnerQuiver:IsAvailable()) then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleSpotter, not TargetInRange40y) then return "aimed_shot sent_cleave 20"; end
  end
  -- rapid_fire,if=!talent.bulletstorm|buff.bulletstorm.stack<=10|talent.aspect_of_the_hydra
  if S.RapidFire:IsCastable() and (not S.Bulletstorm:IsAvailable() or Player:BuffStack(S.BulletstormBuff) <= 10 or S.AspectoftheHydra:IsAvailable()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_cleave 22"; end
  end
  -- aimed_shot,target_if=max:debuff.spotters_mark.up|max_prio_damage,if=buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up
  if S.AimedShot:IsReady() then
    if Everyone.CastCycle(S.AimedShot, Enemies10ySplash, EvaluateCycleAimedShotCleave, not TargetInRange40y) then return "aimed_shot sent_cleave 24"; end
  end
  -- rapid_fire
  if S.RapidFire:IsCastable() then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_cleave 26"; end
  end
  -- explosive_shot,if=talent.precision_detonation|buff.trueshot.down
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() or Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_cleave 28"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot sent_cleave 30"; end
  end
end

local function DRTrickshots()
  -- explosive_shot,if=talent.precision_detonation&buff.trueshot.down&(!talent.shrapnel_shot|buff.lock_and_load.down&(cooldown.aimed_shot.charges_fractional<=1.1|talent.focused_aim))
  if S.ExplosiveShot:IsReady() and (S.PrecisionDetonation:IsAvailable() and Player:BuffDown(S.TrueshotBuff) and (not S.ShrapnelShot:IsAvailable() or Player:BuffDown(S.LockandLoadBuff) and (S.AimedShot:ChargesFractional() <= 1.1 or S.FocusedAim:IsAvailable()))) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_trickshots 2"; end
  end
  -- volley,if=buff.double_tap.down&(!talent.shrapnel_shot|!talent.salvo|buff.lock_and_load.down)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff) and (not S.ShrapnelShot:IsAvailable() or not S.Salvo:IsAvailable() or Player:BuffDown(S.LockandLoadBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley dr_trickshots 4"; end
  end
  -- black_arrow,if=buff.trick_shots.down|!talent.headshot|buff.precise_shots.up
  if S.BlackArrow:IsReady() and (Player:BuffDown(S.TrickShotsBuff) or not S.Headshot:IsAvailable() or Player:BuffUp(S.PreciseShotsBuff)) then
    if Cast(S.BlackArrow, nil, nil, not TargetInRange40y) then return "black_arrow dr_trickshots 6"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time&talent.bulletstorm&buff.bulletstorm.down
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime() and S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff)) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_trickshots 8"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot dr_trickshots 10"; end
  end
  -- steady_shot,if=variable.buffer_deathblow&buff.trueshot.down
  if S.SteadyShot:IsCastable() and (VarBufferDeathblow and Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_cleave 12"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target,if=buff.trick_shots.down|buff.precise_shots.up&(buff.moving_target.down|debuff.spotters_mark.down)
  -- Note: Modifying conditions slightly.
  if S.MultiShot:IsReady() and (Player:BuffDown(S.TrickShotsBuff) or Player:BuffUp(S.PreciseShotsBuff) and (Player:BuffDown(S.MovingTargetBuff) or S.SpottersMarkDebuff:AuraActiveCount() < EnemiesCount10ySplash)) then
    if Everyone.CastCycle(S.MultiShot, Enemies10ySplash, EvaluateCycleMultiShotTS, not TargetInRange40y) then return "multishot dr_trickshots 14"; end
  end
  -- aimed_shot,if=buff.trick_shots.remains>cast_time&(buff.trueshot.up&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up)
  if S.AimedShot:IsReady() and (Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:CastTime() and (Player:BuffUp(S.TrueshotBuff) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_trickshots 16"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time&(talent.no_scope|talent.bulletstorm&buff.bulletstorm.down)
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime() and (S.NoScope:IsAvailable() or S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff))) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire dr_trickshots 18"; end
  end
  -- aimed_shot,if=buff.trick_shots.remains>cast_time&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)
  if S.AimedShot:IsReady() and (Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:CastTime() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot dr_trickshots 20"; end
  end
  -- explosive_shot,if=talent.shrapnel_shot&buff.lock_and_load.down&cooldown.aimed_shot.charges_fractional<=1.1
  if S.ExplosiveShot:IsReady() and (S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:ChargesFractional() <= 1.1) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot dr_trickshots 22"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot dr_trickshots 24"; end
  end
end

local function SentTrickshots()
  -- explosive_shot,if=talent.shrapnel_shot&buff.trueshot.down&buff.lock_and_load.down&cooldown.aimed_shot.charges_fractional<=1.1
  if S.ExplosiveShot:IsReady() and (S.ShrapnelShot:IsAvailable() and Player:BuffDown(S.TrueshotBuff) and Player:BuffDown(S.LockandLoadBuff) and S.AimedShot:ChargesFractional() <= 1.1) then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_trickshots 2"; end
  end
  -- volley,if=buff.double_tap.down&(!talent.shrapnel_shot|!talent.salvo|buff.lock_and_load.down)
  if S.Volley:IsReady() and (Player:BuffDown(S.DoubleTapBuff) and (not S.ShrapnelShot:IsAvailable() or not S.Salvo:IsAvailable() or Player:BuffDown(S.LockandLoadBuff))) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley sent_trickshots 4"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time&(talent.bulletstorm&buff.bulletstorm.down|buff.lunar_storm_cooldown.down)
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime() and (S.Bulletstorm:IsAvailable() and Player:BuffDown(S.BulletstormBuff) or Player:BuffDown(S.LunarStormCDBuff))) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_trickshots 6"; end
  end
  -- kill_shot,if=talent.headshot&buff.trick_shots.up&buff.razor_fragments.up&buff.precise_shots.up
  if S.KillShot:IsReady() and (S.Headshot:IsAvailable() and Player:BuffUp(S.TrickShotsBuff) and Player:BuffUp(S.RazorFragmentsBuff) and Player:BuffUp(S.PreciseShotsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot sent_trickshots 8"; end
  end
  -- multishot,target_if=max:debuff.spotters_mark.down|action.aimed_shot.in_flight_to_target,if=buff.trick_shots.down|buff.precise_shots.up&(buff.moving_target.down|debuff.spotters_mark.down)
  -- Note: Modifying conditions slightly.
  if S.MultiShot:IsReady() and (Player:BuffDown(S.TrickShotsBuff) or Player:BuffUp(S.PreciseShotsBuff) and (Player:BuffDown(S.MovingTargetBuff) or S.SpottersMarkDebuff:AuraActiveCount() < EnemiesCount10ySplash)) then
    if Everyone.CastCycle(S.MultiShot, Enemies10ySplash, EvaluateCycleMultiShotTS, not TargetInRange40y) then return "multishot sent_trickshots 10"; end
  end
  -- trueshot,if=variable.trueshot_ready&buff.double_tap.down
  if CDsON() and S.Trueshot:IsReady() and (VarTrueshotReady and Player:BuffDown(S.DoubleTapBuff)) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot sent_trickshots 12"; end
  end
  -- aimed_shot,if=buff.trick_shots.remains>cast_time&(buff.trueshot.up&buff.precise_shots.down|buff.lock_and_load.up&buff.moving_target.up)
  if S.AimedShot:IsReady() and (Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:CastTime() and (Player:BuffUp(S.TrueshotBuff) and Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.LockandLoadBuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot sent_trickshots 14"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>execute_time
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) > S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire sent_trickshots 16"; end
  end
  -- aimed_shot,if=buff.trick_shots.remains>cast_time&(buff.precise_shots.down|debuff.spotters_mark.up&buff.moving_target.up)
  if S.AimedShot:IsReady() and (Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:CastTime() and (Player:BuffDown(S.PreciseShotsBuff) or Target:DebuffUp(S.SpottersMarkDebuff) and Player:BuffUp(S.MovingTargetBuff))) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot sent_trickshots 18"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot sent_trickshots 20"; end
  end
  -- steady_shot,if=focus+cast_regen<focus.max
  if S.SteadyShot:IsCastable() and (CheckFocusCap(S.SteadyShot:CastTime())) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot sent_trickshots 22"; end
  end
  -- multishot
  if S.MultiShot:IsReady() then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot sent_trickshots 24"; end
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
    -- variable,name=trueshot_ready,value=!talent.bullseye|fight_remains>cooldown.trueshot.duration+10|buff.bullseye.stack=buff.bullseye.max_stack|fight_remains<25
    VarTrueshotReady = not S.Bullseye:IsAvailable() or FightRemains > TrueshotCD + 10 or Player:BuffStack(S.BullseyeBuff) == 30 or BossFightRemains < 25
    -- variable,name=trueshot_ready,op=setif,condition=fight_style.dungeonroute,value_else=variable.trueshot_ready,value=raid_event.pull.remains>30|raid_event.pull.in>60
    if Player:IsInDungeonArea() then
      VarTrueshotReady = true
    end
    -- variable,name=buffer_deathblow,value=hero_tree.dark_ranger&action.aimed_shot.in_flight&!action.black_arrow.ready
    VarBufferDeathblow = Player:HeroTreeID() == 44 and S.AimedShot:InFlight() and not S.BlackArrow:IsReady()
    -- auto_shot
    -- call_action_list,name=cds
    local ShouldReturn = CDs(); if ShouldReturn then return ShouldReturn; end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    if EnemiesCount10ySplash > 2 and S.TrickShots:IsAvailable() then
      -- call_action_list,name=drtrickshots,if=active_enemies>2&talent.trick_shots&hero_tree.dark_ranger
      if Player:HeroTreeID() == 44 then
        local ShouldReturn = DRTrickshots(); if ShouldReturn then return ShouldReturn; end
      end
      -- call_action_list,name=senttrickshots,if=active_enemies>2&talent.trick_shots&hero_tree.sentinel
      -- Note: Added level check to force this function for below level 70.
      if Player:HeroTreeID() == 42 or Player:Level() < 71 then
        local ShouldReturn = SentTrickshots(); if ShouldReturn then return ShouldReturn; end
      end
    end
    -- call_action_list,name=drcleave,if=active_enemies>1&hero_tree.dark_ranger
    if EnemiesCount10ySplash > 1 and Player:HeroTreeID() == 44 then
      local ShouldReturn = DRCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentcleave,if=active_enemies>1&hero_tree.sentinel
    if EnemiesCount10ySplash > 1 and (Player:HeroTreeID() == 42 or Player:Level() < 71) then
      local ShouldReturn = SentCleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=drst,if=hero_tree.dark_ranger
    if Player:HeroTreeID() == 44 then
      local ShouldReturn = DRST(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=sentst,if=!talent.black_arrow
    -- Note: Added level check to force this function for below level 70.
    if Player:HeroTreeID() == 42 or Player:Level() < 71 then
      local ShouldReturn = SentST(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool Focus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function Init()
  S.SpottersMarkDebuff:RegisterAuraTracking()

  HR.Print("Marksmanship Hunter rotation has been updated for patch 11.2.0.")
end

HR.SetAPL(254, APL, Init)
